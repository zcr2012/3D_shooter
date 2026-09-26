import bpy, math
from mathutils import Euler, Vector

arm = bpy.data.objects['SWAT_Rig']
rifle = bpy.data.objects['AR_AssaultRifle']
D = math.radians

bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
pb = arm.pose.bones
for b in pb:
    b.rotation_mode = 'XYZ'
    b.rotation_euler = (0, 0, 0)
    b.location = (0, 0, 0)

# ---------------- firing stance ----------------
pb['thigh.L'].rotation_euler = Euler((D(14), D(2),  D(-3)), 'XYZ')
pb['shin.L'].rotation_euler  = Euler((D(-26), 0,     0), 'XYZ')
pb['foot.L'].rotation_euler  = Euler((D(13), 0,      0), 'XYZ')
pb['thigh.R'].rotation_euler = Euler((D(-13), D(-2), D(3)), 'XYZ')
pb['shin.R'].rotation_euler  = Euler((D(-22), 0,     0), 'XYZ')
pb['foot.R'].rotation_euler  = Euler((D(16), 0,      0), 'XYZ')

pb['hip'].rotation_euler   = Euler((D(6),  0, D(-4)), 'XYZ')
pb['spine'].rotation_euler = Euler((D(11), 0, D(3)),  'XYZ')
pb['chest'].rotation_euler = Euler((D(7),  0, D(6)),  'XYZ')
pb['neck'].rotation_euler  = Euler((D(9),  0, D(-3)), 'XYZ')
pb['head'].rotation_euler  = Euler((D(-7), 0, D(-4)), 'XYZ')

pb['shoulder.L'].rotation_euler = Euler((D(8),  0, D(-5)), 'XYZ')
pb['upperarm.L'].rotation_euler = Euler((D(48), 0, D(35)), 'XYZ')
pb['forearm.L'].rotation_euler  = Euler((D(20), 0, D(16)), 'XYZ')

pb['shoulder.R'].rotation_euler = Euler((D(6),  0, D(5)), 'XYZ')
pb['upperarm.R'].rotation_euler = Euler((D(-5), 0, D(-40)), 'XYZ')
pb['forearm.R'].rotation_euler  = Euler((D(82), 0, D(-20)), 'XYZ')

bpy.context.view_layer.update()

Rpos = arm.matrix_world @ pb['hand.R'].tail
Lpos = arm.matrix_world @ pb['hand.L'].tail
print('handR=(%.3f, %.3f, %.3f)' % (Rpos.x, Rpos.y, Rpos.z))
print('handL=(%.3f, %.3f, %.3f)' % (Lpos.x, Lpos.y, Lpos.z))

# ---------------- mount the rifle into the hands ----------------
# rifle local: +Y = muzzle. grip and handguard positions in rifle space:
SC = 0.86 / 0.612          # the scale applied when the rifle was built
grip_local = Vector((0.0, -0.038 * SC, -0.070 * SC))
hg_local   = Vector((0.0,  0.170 * SC,  0.006 * SC))

A = (hg_local - grip_local).normalized()
B = (Lpos - Rpos).normalized()
q = A.rotation_difference(B)

rifle.rotation_mode = 'QUATERNION'
rifle.rotation_quaternion = q
rifle.location = Rpos - (q @ grip_local)
bpy.context.view_layer.update()

# verify the muzzle direction is pointing forward/up like the aim
muz = rifle.matrix_world @ Vector((0, 0.45, 0.01))
print('muzzle world=(%.3f, %.3f, %.3f)' % (muz.x, muz.y, muz.z))
print('rifle loc=(%.3f, %.3f, %.3f)' % tuple(rifle.location))

# parent to the trigger hand so it stays attached when the pose changes
world = rifle.matrix_world.copy()
rifle.parent = arm
rifle.parent_type = 'BONE'
rifle.parent_bone = 'hand.R'
bpy.context.view_layer.update()
rifle.matrix_world = world
bpy.context.view_layer.update()
print('parented to bone: %s' % rifle.parent_bone)

bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_mainfile()
print('SAVED')
