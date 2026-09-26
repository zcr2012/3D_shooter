import bpy
from mathutils import Vector
arm=bpy.data.objects['SWAT_Rig']; sc=bpy.context.scene
for clip,f in [('IdleArmed',0),('ReloadArmed',40)]:
    arm.animation_data.action=bpy.data.actions[clip]; sc.frame_set(f); bpy.context.view_layer.update()
    for n in ['weapon_root','weapon_mag']:
        b=arm.pose.bones[n]
        print(clip,n,'matrix',list(b.matrix.translation),'head',list(b.head),'tail',list(b.tail),'scale',list(b.scale))
    for n in ['AR_AssaultRifle','AR_Magazine']:
        o=bpy.data.objects[n]
        print(clip,n,'world',list(o.matrix_world.translation),'basis',list(o.matrix_basis.translation),'parent_inverse',list(o.matrix_parent_inverse.translation))
        print('bounds',[(min((o.matrix_world @ Vector(v))[i] for v in o.bound_box),max((o.matrix_world @ Vector(v))[i] for v in o.bound_box)) for i in range(3)])
