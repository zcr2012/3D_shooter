"""Bake PBR maps, PACK them into the .blend, and build export-ready materials.
Key fix: generated images must be packed or their pixel data is lost on reload.
"""
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
    if n == 0:
        return 'EMPTY'
    nb = sum(1 for i in range(n) if px[i*4] + px[i*4+1] + px[i*4+2] > 0.01)
    return 'avg=%.3f max=%.3f nonblack=%.1f%%' % (
        sum(px[0::4])/n, max(px[0::4]), 100.0*nb/n)

def bake_pass(ob, img, btype):
    added = []
    for mat in ob.data.materials:
        if not mat or not mat.use_nodes:
            continue
        nt = mat.node_tree
        n = nt.nodes.new('ShaderNodeTexImage')
        n.image = img
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

def build_material(name, img, rimg, metal_val):
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

    rt = nt.nodes.new('ShaderNodeTexImage'); rt.location = (-200, -220)
    rt.image = rimg
    nt.links.new(rt.outputs['Color'], b.inputs['Roughness'])
    return m

for name, metal_val in (('SWAT_Operator', 0.0), ('AR_AssaultRifle', 0.25)):
    ob = bpy.data.objects.get(name)
    if not ob:
        print('MISSING', name)
        continue

    # base colour (sRGB image) - bake then PACK
    cimg = bpy.data.images.new(name + '_BaseColor', 1024, 1024, alpha=False)
    cimg.colorspace_settings.name = 'sRGB'
    bake_pass(ob, cimg, 'DIFFUSE')
    print('%s color: %s' % (name, stats(cimg)))

    # roughness (non-colour data)
    rimg = bpy.data.images.new(name + '_Roughness', 1024, 1024, alpha=False)
    rimg.colorspace_settings.name = 'Non-Color'
    bake_pass(ob, rimg, 'ROUGHNESS')
    print('%s rough: %s' % (name, stats(rimg)))

    # CRITICAL: pack so the pixel data survives save/reload
    cimg.pack()
    rimg.pack()
    print('  packed: color=%s rough=%s' % (bool(cimg.packed_file), bool(rimg.packed_file)))

    mat = build_material(name + '_PBR', cimg, rimg, metal_val)
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    print('%s -> PBR material' % name)

bpy.ops.wm.save_mainfile()
print('SAVED')
