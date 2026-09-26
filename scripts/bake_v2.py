"""Bake with diagnostics. Run: blender -b file.blend -P bake_v2.py"""
import bpy, math

sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = 4
sc.render.bake.target = 'IMAGE_TEXTURES'
sc.render.bake.use_selected_to_active = False
sc.render.bake.use_clear = True
sc.render.bake.margin = 8
sc.render.bake.use_pass_direct = False
sc.render.bake.use_pass_indirect = False
sc.render.bake.use_pass_color = True

print('engine=%s target=%s' % (sc.render.engine, sc.render.bake.target))

def img_stats(img):
    px = list(img.pixels[:])
    n = len(px) // 4
    if n == 0:
        return 'empty'
    mx = max(px[0::4]) if n else 0
    avg = sum(px[0::4]) / n
    nb = sum(1 for i in range(n) if px[i*4] + px[i*4+1] + px[i*4+2] > 0.01)
    return 'R avg=%.4f max=%.4f nonblack=%.1f%%' % (avg, mx, 100.0*nb/n)

def bake(ob, res=1024):
    me = ob.data
    print('=== %s: %d mats, %d uv layers ===' % (ob.name, len(me.materials), len(me.uv_layers)))

    img = bpy.data.images.new(ob.name + '_BAKE', res, res, alpha=False)
    img.colorspace_settings.name = 'sRGB'

    added = []
    for mat in me.materials:
        if not mat or not mat.use_nodes:
            continue
        nt = mat.node_tree
        n = nt.nodes.new('ShaderNodeTexImage')
        n.image = img
        n.location = (-1600, 500)
        n.select = True
        nt.nodes.active = n          # bake target = active node
        added.append((mat, n))
    print('  image nodes added: %d' % len(added))

    # make sure the object is the active + only selected object
    bpy.ops.object.select_all(action='DESELECT')
    ob.hide_set(False)
    ob.hide_viewport = False
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    print('  active=%s selected=%d' % (bpy.context.view_layer.objects.active.name,
                                       len(bpy.context.selected_objects)))

    try:
        bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, use_clear=True)
        print('  bake op returned OK')
    except Exception as e:
        print('  BAKE FAILED:', type(e).__name__, e)
        return None

    print('  image after bake: %s' % img_stats(img))

    for mat, n in added:
        mat.node_tree.nodes.remove(n)
    return img

for name in ('SWAT_Operator', 'AR_AssaultRifle'):
    ob = bpy.data.objects.get(name)
    if ob:
        bake(ob)

bpy.ops.wm.save_mainfile()
print('SAVED')
