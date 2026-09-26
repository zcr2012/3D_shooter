import bpy, math
from mathutils import Vector

sc = bpy.context.scene
arm = bpy.data.objects['SWAT_Rig']

# face the doorway at (1.95, -3.5) so we see the operator from the front
arm.rotation_euler = (0, 0, math.radians(-133))
bpy.context.view_layer.update()

# brighten the room a little
for n, e in [('CeilL', 220), ('CeilR', 220), ('WinLight', 420),
             ('DoorFill', 170), ('Bounce', 55)]:
    o = bpy.data.objects.get(n)
    if o:
        o.data.energy = e

bg = sc.world.node_tree.nodes.get('Background')
bg.inputs[0].default_value = (0.075, 0.085, 0.105, 1)
bg.inputs[1].default_value = 0.85

sc.view_settings.exposure = 0.55

cam = bpy.data.objects['PreviewCam']
sc.camera = cam
cam.data.lens = 30
sc.render.resolution_x = 1280
sc.render.resolution_y = 780
sc.eevee.taa_render_samples = 110

shots = {
    'final_wide':   (Vector((-3.2, -2.6, 2.15)), Vector(( 0.4,  0.4, 1.00))),
    'final_hero':   (Vector(( 1.4, -2.4, 1.55)), Vector((-1.3, -0.7, 1.15))),
    'final_action': (Vector(( 2.6,  2.4, 2.05)), Vector((-1.2, -0.9, 1.05))),
}
for tag, (loc, tgt) in shots.items():
    cam.location = loc
    cam.rotation_euler = (tgt - loc).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = 'C:/Users/zhangshuai/WorkBuddy AI/3D_shooter/%s.png' % tag
    bpy.ops.render.render(write_still=True)
    print('rendered', tag)

bpy.ops.wm.save_mainfile()
print('SAVED')
