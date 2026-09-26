import bpy, math
from mathutils import Vector, Euler

arm = bpy.data.objects['SWAT_Rig']
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
pb = arm.pose.bones
for b in pb:
    b.rotation_mode = 'XYZ'
    b.rotation_euler = (0, 0, 0)
    b.location = (0, 0, 0)

D = math.radians

# lower body: bladed stance, knees bent, weight forward
pb['thigh.L'].rotation_euler = Euler((D(14), D(3),  D(-4)), 'XYZ')
pb['shin.L'].rotation_euler  = Euler((D(-26), 0,    0), 'XYZ')
pb['foot.L'].rotation_euler  = Euler((D(13), 0,     0), 'XYZ')

pb['thigh.R'].rotation_euler = Euler((D(-13), D(-3), D(4)), 'XYZ')
pb['shin.R'].rotation_euler  = Euler((D(-22), 0,     0), 'XYZ')
pb['foot.R'].rotation_euler  = Euler((D(16), 0,      0), 'XYZ')

# torso: crouch and lean into the weapon
pb['hip'].rotation_euler   = Euler((D(6),  0, D(-4)), 'XYZ')
pb['spine'].rotation_euler = Euler((D(11), 0, D(3)),  'XYZ')
pb['chest'].rotation_euler = Euler((D(7),  0, D(6)),  'XYZ')
pb['neck'].rotation_euler  = Euler((D(9),  0, D(-3)), 'XYZ')
pb['head'].rotation_euler  = Euler((D(-7), 0, D(-5)), 'XYZ')

# RIGHT arm - trigger hand, elbow high
pb['shoulder.R'].rotation_euler = Euler((D(6),  0, D(5)), 'XYZ')
pb['upperarm.R'].rotation_euler = Euler((D(46), 0, D(24)), 'XYZ')
pb['forearm.R'].rotation_euler  = Euler((D(58), 0, D(-20)), 'XYZ')

# LEFT arm - support hand forward on the handguard
pb['shoulder.L'].rotation_euler = Euler((D(8),  0, D(-5)), 'XYZ')
pb['upperarm.L'].rotation_euler = Euler((D(58), 0, D(-22)), 'XYZ')
pb['forearm.L'].rotation_euler  = Euler((D(24), 0, D(16)), 'XYZ')

bpy.context.view_layer.update()

for h in ('hand.L', 'hand.R'):
    p = arm.matrix_world @ pb[h].tail
    q = arm.matrix_world @ pb[h].head
    print('%s head=(%.3f, %.3f, %.3f) tail=(%.3f, %.3f, %.3f)' % (
        h, q.x, q.y, q.z, p.x, p.y, p.z))

bpy.ops.object.mode_set(mode='OBJECT')

sc = bpy.context.scene
cam = bpy.data.objects['PreviewCam']
target = Vector((0, 0.20, 1.10))
sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x = 660
sc.render.resolution_y = 860
sc.eevee.taa_render_samples = 48
sc.view_settings.view_transform = 'Standard'
sc.view_settings.exposure = 1.15
for n, e in [('Key', 70), ('Fill', 26), ('RimL', 50), ('RimR', 38), ('Front', 20)]:
    o = bpy.data.objects.get(n)
    if o:
        o.data.energy = e

for tag, loc in {'q34': Vector((2.0, 2.3, 1.65)),
                 'side': Vector((2.9, 0.30, 1.35))}.items():
    cam.location = loc
    cam.rotation_euler = (target - loc).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = 'C:/Users/zhangshuai/WorkBuddy AI/3D_shooter/stance3_%s.png' % tag
    bpy.ops.render.render(write_still=True)
    print('rendered', tag)

bpy.ops.wm.save_mainfile()
print('SAVED')
