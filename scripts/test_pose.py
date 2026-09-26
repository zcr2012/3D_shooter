import bpy, math
from mathutils import Vector, Euler

arm = bpy.data.objects['SWAT_Rig']
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
pb = arm.pose.bones
for b in pb:
    b.rotation_mode = 'XYZ'
    b.rotation_euler = (0, 0, 0)

D = math.radians
for side in ('L', 'R'):
    pb['upperarm.' + side].rotation_euler = Euler((D(78), 0, 0), 'XYZ')
    pb['forearm.' + side].rotation_euler  = Euler((D(52), 0, 0), 'XYZ')
    pb['thigh.' + side].rotation_euler    = Euler((D(38), 0, 0), 'XYZ')
    pb['shin.' + side].rotation_euler     = Euler((D(-72), 0, 0), 'XYZ')
pb['spine'].rotation_euler = Euler((D(14), 0, 0), 'XYZ')
bpy.ops.object.mode_set(mode='OBJECT')

sc = bpy.context.scene
cam = bpy.data.objects['PreviewCam']
target = Vector((0, 0.10, 0.92))
sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x = 640
sc.render.resolution_y = 840
sc.eevee.taa_render_samples = 48
sc.view_settings.view_transform = 'Standard'
sc.view_settings.exposure = 1.15
for n, e in [('Key', 70), ('Fill', 26), ('RimL', 50), ('RimR', 38), ('Front', 20)]:
    o = bpy.data.objects.get(n)
    if o:
        o.data.energy = e

cam.location = Vector((2.1, 2.2, 1.55))
cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
sc.render.filepath = 'C:/Users/zhangshuai/WorkBuddy AI/3D_shooter/autotest.png'
bpy.ops.render.render(write_still=True)
print('rendered')
