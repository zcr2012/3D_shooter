import bpy, math
from mathutils import Vector, Euler

arm = bpy.data.objects['SWAT_Rig']
rifle = bpy.data.objects['AR_AssaultRifle']
pb = arm.pose.bones
bpy.context.view_layer.update()

# ---------- unparent, keeping world transform ----------
w = rifle.matrix_world.copy()
rifle.parent = None
rifle.matrix_world = w
bpy.context.view_layer.update()

Rpos = arm.matrix_world @ pb['hand.R'].tail
Lpos = arm.matrix_world @ pb['hand.L'].tail
print('handR=(%.3f, %.3f, %.3f)  handL=(%.3f, %.3f, %.3f)' % (
    Rpos.x, Rpos.y, Rpos.z, Lpos.x, Lpos.y, Lpos.z))

SC = 0.86 / 0.612
grip_local = Vector((0.0, -0.038 * SC, -0.070 * SC))

# ---------- aim the rifle forward along +Y, slight up-tilt ----------
rifle.rotation_mode = 'XYZ'
rifle.rotation_euler = Euler((math.radians(-6), 0.0, math.radians(-4)), 'XYZ')
rot = rifle.rotation_euler.to_matrix()
rifle.location = Rpos - (rot @ grip_local)
bpy.context.view_layer.update()

muz = rifle.matrix_world @ Vector((0, 0.45, 0.01))
hg  = rifle.matrix_world @ Vector((0, 0.2389, 0.0084))
print('muzzle=(%.3f, %.3f, %.3f)' % (muz.x, muz.y, muz.z))
print('handguard=(%.3f, %.3f, %.3f)' % (hg.x, hg.y, hg.z))
print('support hand -> handguard gap: %.3f m' % (hg - Lpos).length)

# ---------- attach to the trigger hand ----------
world = rifle.matrix_world.copy()
rifle.parent = arm
rifle.parent_type = 'BONE'
rifle.parent_bone = 'hand.R'
bpy.context.view_layer.update()
rifle.matrix_world = world
bpy.context.view_layer.update()
print('attached to', rifle.parent_bone)

bpy.ops.wm.save_mainfile()
print('SAVED')
