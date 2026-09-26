import bpy
from mathutils import Vector

sc = bpy.context.scene
cam = bpy.data.objects['PreviewCam']
target = Vector((0, 0.15, 1.05))

sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x = 660
sc.render.resolution_y = 880
sc.eevee.taa_render_samples = 64
sc.view_settings.view_transform = 'Standard'
sc.view_settings.exposure = 1.15
for n, e in [('Key', 70), ('Fill', 26), ('RimL', 50), ('RimR', 38), ('Front', 20)]:
    o = bpy.data.objects.get(n)
    if o:
        o.data.energy = e

for tag, loc in {'front': Vector((0.20, 3.00, 1.45)),
                 'side':  Vector((3.00, 0.25, 1.30)),
                 'q34':   Vector((2.00, 2.30, 1.60))}.items():
    cam.location = loc
    cam.rotation_euler = (target - loc).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = 'C:/Users/zhangshuai/WorkBuddy AI/3D_shooter/pose_%s.png' % tag
    bpy.ops.render.render(write_still=True)
    print('rendered', tag)
