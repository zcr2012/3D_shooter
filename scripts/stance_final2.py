import bpy, math
from mathutils import Vector, Euler

arm = bpy.data.objects['SWAT_Rig']
rifle = bpy.data.objects['AR_AssaultRifle']
D = math.radians

w = rifle.matrix_world.copy()
rifle.parent = None
rifle.matrix_world = w

bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
pb = arm.pose.bones
for b in pb:
    b.rotation_mode = 'XYZ'
    b.rotation_euler = (0, 0, 0)
    b.location = (0, 0, 0)

pb['thigh.L'].rotation_euler = Euler((D(14), D(2),  D(-3)), 'XYZ')
pb['shin.L'].rotation_euler  = Euler((D(-26), 0,     0), 'XYZ')
pb['foot.L'].rotation_euler  = Euler((D(13), 0,      0), 'XYZ')
pb['thigh.R'].rotation_euler = Euler((D(-13), D(-2), D(3)), 'XYZ')
pb['shin.R'].rotation_euler  = Euler((D(-22), 0,     0), 'XYZ')
pb['foot.R'].rotation_euler  = Euler((D(16), 0,      0), 'XYZ')

pb['hip'].rotation_euler   = Euler((D(6),  0, D(-4)), 'XYZ')
pb['spine'].rotation_euler = Euler((D(11), 0, D(3)),  'XYZ')
pb['chest'].rotation_euler = Euler((D(7),  0, D(6)),  'XYZ')
pb['neck'].rotation_euler  = Euler((D(7),  0, D(-3)), 'XYZ')
pb['head'].rotation_euler  = Euler((D(-5), 0, D(-4)), 'XYZ')

# support arm: lower, reaching in to the handguard
pb['shoulder.L'].rotation_euler = Euler((0, 0, 0), 'XYZ')
pb['upperarm.L'].rotation_euler = Euler((D(48), 0, D(35)), 'XYZ')
pb['forearm.L'].rotation_euler  = Euler((D(20), 0, D(16)), 'XYZ')

pb['shoulder.R'].rotation_euler = Euler((D(6),  0, D(5)), 'XYZ')
pb['upperarm.R'].rotation_euler = Euler((D(20), 0, D(-40)), 'XYZ')
pb['forearm.R'].rotation_euler  = Euler((D(62), 0, D(-20)), 'XYZ')

bpy.context.view_layer.update()
Rpos = arm.matrix_world @ pb['hand.R'].tail
Lpos = arm.matrix_world @ pb['hand.L'].tail
print('handR=(%.3f, %.3f, %.3f)  handL=(%.3f, %.3f, %.3f)' % (
    Rpos.x, Rpos.y, Rpos.z, Lpos.x, Lpos.y, Lpos.z))

SC = 0.86 / 0.612
grip_local = Vector((0.0, -0.038 * SC, -0.070 * SC))
rifle.rotation_mode = 'XYZ'
rifle.rotation_euler = Euler((D(-6), 0.0, D(-4)), 'XYZ')
rot = rifle.rotation_euler.to_matrix()
rifle.location = Rpos - (rot @ grip_local)
bpy.context.view_layer.update()

hg = rifle.matrix_world @ Vector((0, 0.2389, 0.0084))
print('handguard=(%.3f, %.3f, %.3f)  gap=%.3f m' % (hg.x, hg.y, hg.z, (hg - Lpos).length))

world = rifle.matrix_world.copy()
rifle.parent = arm
rifle.parent_type = 'BONE'
rifle.parent_bone = 'hand.R'
bpy.context.view_layer.update()
rifle.matrix_world = world
bpy.context.view_layer.update()

bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_mainfile()
print('SAVED')
