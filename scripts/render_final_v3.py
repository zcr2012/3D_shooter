import bpy, math
from mathutils import Vector

sc = bpy.context.scene
cam = bpy.data.objects['PreviewCam']
sc.camera = cam

# balanced lighting: brighter than the studio but not blown out
for name, energy in [('CeilL', 150), ('CeilR', 150), ('WinLight', 300),
                     ('DoorFill', 110), ('Bounce', 45)]:
    o = bpy.data.objects.get(name)
    if o:
        o.data.energy = energy

bg = sc.world.node_tree.nodes.get('Background')
bg.inputs[0].default_value = (0.055, 0.062, 0.078, 1)
bg.inputs[1].default_value = 0.60

sc.render.engine = 'BLENDER_EEVEE'
sc.eevee.taa_render_samples = 128
sc.view_settings.view_transform = 'Standard'
sc.view_settings.exposure = 0.05
sc.render.resolution_x = 1280
sc.render.resolution_y = 760

shots = {
    'final_wide':   (Vector((-2.60, -2.90, 2.25)), Vector((-0.50,  0.60, 1.00))),
    'final_hero':   (Vector(( 1.30, -2.70, 1.75)), Vector((-1.05, -0.35, 1.15))),
    'final_corner': (Vector(( 2.90,  2.70, 2.25)), Vector((-1.00, -0.60, 1.00))),
    'final_close':  (Vector((-2.20, -2.05, 1.55)), Vector((-1.25, -0.55, 1.22))),
}
for tag, (loc, tgt) in shots.items():
    cam.location = loc
    cam.data.lens = 30 if tag == 'final_wide' else 42
    cam.rotation_euler = (tgt - loc).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = 'C:/Users/zhangshuai/WorkBuddy AI/3D_shooter/%s.png' % tag
    bpy.ops.render.render(write_still=True)
    print('rendered', tag)

bpy.ops.wm.save_mainfile()
print('SAVED')
