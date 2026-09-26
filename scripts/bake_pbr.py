"""Bake base colour + roughness, then rebuild export-ready materials."""
import bpy

sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = 4
sc.render.bake.target = 'IMAGE_TEXTURES'
sc.render.bake.use_selected_to_active = False
sc.render.bake.margin = 8

def stats(img):
    px = list(img.pixels[:]); n = len(px) // 4
    nb = sum(1 for i in range(n) if px[i*4] + px[i*4+1] + px[i*4+2] > 0.01)
    return 'avg=%.3f nonblack=%.1f%%' % (sum(px[0::4])/n, 100.0*nb/n)

def bake_pass(ob, img, btype, res=1024):
    """btype: 'DIFFUSE' or 'ROUGHNESS'"""
    added = []
    for mat in ob.data.materials:
        if not mat or not mat.use_nodes:
            continue
        nt = mat.node_tree
        n = nt.nodes.new('ShaderNodeTexImage')
        n.image = img
        n.location = (-1600, 500)
        n.select = True
        nt.nodes.active = n
        added.append((mat, n))

    bpy.ops.object.select_all(action='DESELECT')
    ob.hide_set(False); ob.hide_viewport = False
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob

    if btype == 'DIFFUSE':
        sc.render.bake.use_pass_direct = False
        sc.render.bake.use_pass_indirect = False
        sc.render.bake.use_pass_color = True
        bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, use_clear=True)
    else:
        bpy.ops.object.bake(type='ROUGHNESS', use_clear=True)

    for mat, n in added:
        mat.node_tree.nodes.remove(n)

def build_material(name, img, rough_img, rough_val, metal_val):
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
    b.location = (300, 0)
    nt.links.new(b.outputs['BSDF'], out.inputs['Surface'])
    b.inputs['Metallic'].default_value = metal_val

    tex = nt.nodes.new('ShaderNodeTexImage'); tex.location = (-200, 200)
    tex.image = img
    nt.links.new(tex.outputs['Color'], b.inputs['Base Color'])

    if rough_img:
        rt = nt.nodes.new('ShaderNodeTexImage'); rt.location = (-200, -220)
        rt.image = rough_img
        rt.image.colorspace_settings.name = 'Non-Color'
        nt.links.new(rt.outputs['Color'], b.inputs['Roughness'])
    else:
        b.inputs['Roughness'].default_value = rough_val
    return m

JOBS = [
    ('SWAT_Operator', 0.78, 0.0),
    ('AR_AssaultRifle', 0.45, 0.25),
]
for name, rough_val, metal_val in JOBS:
    ob = bpy.data.objects.get(name)
    if not ob:
        print('MISSING', name)
        continue

    cimg = bpy.data.images.new(name + '_BaseColor', 1024, 1024, alpha=False)
    cimg.colorspace_settings.name = 'sRGB'
    bake_pass(ob, cimg, 'DIFFUSE')
    print('%s color: %s' % (name, stats(cimg)))

    rimg = bpy.data.images.new(name + '_Roughness', 1024, 1024, alpha=False)
    bake_pass(ob, rimg, 'ROUGHNESS')
    print('%s rough: %s' % (name, stats(rimg)))

    mat = build_material(name + '_PBR', cimg, rimg, rough_val, metal_val)
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    print('%s -> baked PBR material' % name)

bpy.ops.wm.save_mainfile()
print('SAVED')
