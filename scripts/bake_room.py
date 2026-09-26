"""Bake the room's procedural materials (one bake per unique material) so the
scene keeps its concrete/tile/wood texture detail in Godot.
"""
import bpy, math

sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = 4
sc.render.bake.target = 'IMAGE_TEXTURES'
sc.render.bake.use_selected_to_active = False
sc.render.bake.margin = 6
sc.render.bake.use_pass_direct = False
sc.render.bake.use_pass_indirect = False
sc.render.bake.use_pass_color = True

scene_col = bpy.data.collections.get('SceneRoom')
room = [o for o in scene_col.objects if o.type == 'MESH']

# ---------- UV unwrap every room object ----------
for ob in room:
    if not ob.data.uv_layers:
        bpy.ops.object.select_all(action='DESELECT')
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
        bpy.ops.object.mode_set(mode='OBJECT')
print('UV unwrapped %d room objects' % len(room))

# ---------- group objects by material ----------
by_mat = {}
for ob in room:
    for m in ob.data.materials:
        if m:
            by_mat.setdefault(m.name, []).append(ob)

print('unique room materials:', len(by_mat))

def stats(img):
    px = list(img.pixels[:]); n = len(px)//4
    if n == 0:
        return 'EMPTY'
    nb = sum(1 for i in range(n) if px[i*4]+px[i*4+1]+px[i*4+2] > 0.01)
    return 'avg=%.3f nonblack=%.1f%%' % (sum(px[0::4])/n, 100.0*nb/n)

new_mats = {}
for mname, objs in by_mat.items():
    rep = objs[0]                      # representative object
    mat = bpy.data.materials.get(mname)
    if not mat or not mat.use_nodes:
        continue

    cimg = bpy.data.images.new(mname + '_BC', 512, 512, alpha=False)
    cimg.colorspace_settings.name = 'sRGB'
    rimg = bpy.data.images.new(mname + '_RG', 512, 512, alpha=False)
    rimg.colorspace_settings.name = 'Non-Color'

    for img, btype in ((cimg, 'DIFFUSE'), (rimg, 'ROUGHNESS')):
        nt = mat.node_tree
        n = nt.nodes.new('ShaderNodeTexImage')
        n.image = img
        n.select = True
        nt.nodes.active = n

        bpy.ops.object.select_all(action='DESELECT')
        rep.hide_set(False); rep.hide_viewport = False
        rep.select_set(True)
        bpy.context.view_layer.objects.active = rep

        if btype == 'DIFFUSE':
            bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, use_clear=True)
        else:
            bpy.ops.object.bake(type='ROUGHNESS', use_clear=True)
        nt.nodes.remove(n)

    cimg.pack(); rimg.pack()

    # build the baked material
    nm = bpy.data.materials.new(mname + '_Baked')
    nm.use_nodes = True
    nt = nm.node_tree
    for n in list(nt.nodes):
        if n.type != 'OUTPUT_MATERIAL':
            nt.nodes.remove(n)
    out = nt.nodes['Material Output']
    b = nt.nodes.new('ShaderNodeBsdfPrincipled'); b.location = (300, 0)
    nt.links.new(b.outputs['BSDF'], out.inputs['Surface'])
    # carry over metallic from the original
    orig_b = mat.node_tree.nodes.get('Principled BSDF')
    if orig_b:
        b.inputs['Metallic'].default_value = orig_b.inputs['Metallic'].default_value
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.location = (-200, 200)
    tex.image = cimg
    nt.links.new(tex.outputs['Color'], b.inputs['Base Color'])
    rt = nt.nodes.new('ShaderNodeTexImage'); rt.location = (-200, -220)
    rt.image = rimg
    nt.links.new(rt.outputs['Color'], b.inputs['Roughness'])

    new_mats[mname] = nm
    print('  %-14s -> baked  %s' % (mname, stats(cimg)))

# ---------- swap in the baked materials ----------
for ob in room:
    slots = [new_mats.get(m.name, m) for m in ob.data.materials]
    ob.data.materials.clear()
    for s in slots:
        ob.data.materials.append(s)
print('swapped %d objects to baked materials' % len(room))

bpy.ops.wm.save_mainfile()
print('SAVED')
