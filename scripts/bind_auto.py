import bpy

ob = bpy.data.objects['SWAT_Operator']
arm = bpy.data.objects['SWAT_Rig']

# clear my manual weights
ob.vertex_groups.clear()
for m in list(ob.modifiers):
    ob.modifiers.remove(m)
ob.parent = None

# reset pose to rest
bpy.context.view_layer.objects.active = arm
if arm.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')

# bind with bone-heat automatic weights (works now that mesh is continuous)
bpy.ops.object.select_all(action='DESELECT')
ob.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type='ARMATURE_AUTO')

print('VGROUPS:', len(ob.vertex_groups))
print('MODS:', [(m.name, m.type) for m in ob.modifiers])
bpy.ops.wm.save_mainfile()
print('SAVED')
