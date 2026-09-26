import bpy, math
from mathutils import Vector

sc = bpy.context.scene
cam = bpy.data.objects['PreviewCam']
sc.camera = cam

# character stands at the origin in the room
target = Vector((0.0, 0.25, 1.05))

# balanced room lighting
for name, energy in [('CeilL', 150), ('CeilR', 150), ('WinLight', 300),
                     ('DoorFill', 110), ('Bounce', 45)]:
    o = bpy.data.objects.get(name)
    if o:
        o.data.energy = energy
        o.hide_render = False

# hide the studio lights for the room shots
for name in ('Key', 'Fill', 'RimL', 'RimR', 'Front'):
    o = bpy.data.objects.get(name)
    if o:
        o.hide_render = True

bg = sc.world.node_tree.nodes.get('Background')
bg.inputs[0].default_value = (0.055, 0.062, 0.078, 1)
bg.inputs[1].default_value = 0.60

sc.render.engine = 'BLENDER_EEVEE'
sc.eevee.taa_render_samples = 128
sc.view_settings.view_transform = 'Standard'
sc.view_settings.exposure = 0.10
sc.render.resolution_x = 1280
sc.render.resolution_y = 760

shots = {
    'final_hero':   (Vector((1.90, -2.30, 1.72)), 40, target),
    'final_wide':   (Vector((-2.70, -2.90, 2.25)), 30, Vector((0.0, 0.5, 1.00))),
    'final_corner': (Vector(( 2.95,  2.75, 2.25)), 34, Vector((0.0, -0.2, 1.00))),
    'final_close':  (Vector((-1.30, -1.85, 1.55)), 46, Vector((-0.15, 0.05, 1.25))),
}
for tag, (loc, lens, tgt) in shots.items():
    cam.location = loc
    cam.data.lens = lens
    cam.rotation_euler = (tgt - loc).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = 'C:/Users/zhangshuai/WorkBuddy AI/3D_shooter/%s.png' % tag
    bpy.ops.render.render(write_still=True)
    print('rendered', tag)

bpy.ops.wm.save_mainfile()
print('SAVED')
