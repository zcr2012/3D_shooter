import bpy, math
from mathutils import Vector

sc = bpy.context.scene
cam = bpy.data.objects['PreviewCam']
sc.camera = cam

# ---------- brighten the room lighting ----------
for name, energy in [('CeilL', 300), ('CeilR', 300), ('WinLight', 520),
                     ('DoorFill', 200), ('Bounce', 90)]:
    o = bpy.data.objects.get(name)
    if o:
        o.data.energy = energy

bg = sc.world.node_tree.nodes.get('Background')
bg.inputs[0].default_value = (0.070, 0.078, 0.095, 1)
bg.inputs[1].default_value = 0.85

sc.render.engine = 'BLENDER_EEVEE'
sc.eevee.taa_render_samples = 128
sc.view_settings.view_transform = 'Standard'
sc.view_settings.exposure = 0.55
sc.render.resolution_x = 1280
sc.render.resolution_y = 760

# ---------- cameras INSIDE the room (X -4..4, Y -3.5..3.5) ----------
shots = {
    'scene_wide':   (Vector((-2.60, -2.90, 2.25)), Vector((-0.50,  0.60, 1.00))),
    'scene_hero':   (Vector(( 1.30, -2.70, 1.75)), Vector((-1.05, -0.35, 1.15))),
    'scene_corner': (Vector(( 2.90,  2.70, 2.25)), Vector((-1.00, -0.60, 1.00))),
    'scene_close':  (Vector((-2.10, -1.90, 1.45)), Vector((-1.20, -0.55, 1.20))),
}
for tag, (loc, tgt) in shots.items():
    cam.location = loc
    cam.data.lens = 30 if tag == 'scene_wide' else 40
    cam.rotation_euler = (tgt - loc).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = 'C:/Users/zhangshuai/WorkBuddy AI/3D_shooter/%s.png' % tag
    bpy.ops.render.render(write_still=True)
    print('rendered', tag)

bpy.ops.wm.save_mainfile()
print('SAVED')
