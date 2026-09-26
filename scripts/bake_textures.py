"""Bake procedural materials to image textures so glTF export keeps the detail.
Run: blender -b file.blend -P bake_textures.py
"""
import bpy, math

TARGETS = ['SWAT_Operator', 'AR_AssaultRifle']
RES = 1024

sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = 8                 # colour bake needs very few samples
sc.render.bake.use_pass_direct = False
sc.render.bake.use_pass_indirect = False
sc.render.bake.use_pass_color = True
sc.render.bake.margin = 8

def uv_unwrap(ob):
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.012)
    bpy.ops.object.mode_set(mode='OBJECT')

def bake_color(ob, name):
    me = ob.data
    if not me.uv_layers:
        uv_unwrap(ob)

    img = bpy.data.images.new(name, RES, RES, alpha=False)
    img.colorspace_settings.name = 'sRGB'

    # add an active image node to every material on this mesh
    nodes_added = []
    for mat in me.materials:
        if not mat or not mat.use_nodes:
            continue
        nt = mat.node_tree
        n = nt.nodes.new('ShaderNodeTexImage')
        n.image = img
        n.location = (-1400, 400)
        nt.nodes.active = n
        nodes_added.append((mat, n))

    if not nodes_added:
        print('  no bakeable materials on', ob.name)
        return None

    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    sc.cycles.bake_type = 'DIFFUSE'
    bpy.ops.object.bake(type='DIFFUSE')

    # clean up the temporary bake nodes
    for mat, n in nodes_added:
        mat.node_tree.nodes.remove(n)

    print('  baked %s -> %dx%d' % (name, RES, RES))
    return img

def make_simple_material(name, img, rough=0.75, metal=0.0):
    m = bpy.data.materials.get(name)
    if m:
        bpy.data.materials.remove(m)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type != 'OUTPUT_MATERIAL':
            nt.nodes.remove(n)
    out = nt.nodes['Material Output']
    b = nt.nodes.new('ShaderNodeBsdfPrincipled')
    b.location = (200, 0)
    nt.links.new(b.outputs['BSDF'], out.inputs['Surface'])
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.location = (-200, 0)
    tex.image = img
    nt.links.new(tex.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    return m

for name in TARGETS:
    ob = bpy.data.objects.get(name)
    if not ob:
        print('MISSING:', name)
        continue
    print('--- %s (%d mats, %d verts) ---' % (name, len(ob.data.materials), len(ob.data.vertices)))
    img = bake_color(ob, name + '_BAKE')
    if img:
        # rough/metal heuristics by asset type
        if name == 'AR_AssaultRifle':
            m = make_simple_material(name + '_Mat', img, rough=0.45, metal=0.55)
        else:
            m = make_simple_material(name + '_Mat', img, rough=0.78, metal=0.0)
        ob.data.materials.clear()
        ob.data.materials.append(m)
        print('  replaced with baked material')

bpy.ops.wm.save_mainfile()
print('SAVED')
