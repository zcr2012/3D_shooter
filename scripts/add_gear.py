import bpy, math

ob = bpy.data.objects['SWAT_Operator']
arm = bpy.data.objects['SWAT_Rig']

# clear weights so we can rebind after adding gear
ob.vertex_groups.clear()
for m in list(ob.modifiers):
    ob.modifiers.remove(m)
ob.parent = None
if arm.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')

def box(name, cx, cy, cz, sx, sy, sz, tt=1.0, tb=1.0):
    bhx, bhy = sx * tb, sy * tb
    thx, thy = sx * tt, sy * tt
    v = [(cx-bhx, cy-bhy, cz-sz), (cx+bhx, cy-bhy, cz-sz),
         (cx+bhx, cy+bhy, cz-sz), (cx-bhx, cy+bhy, cz-sz),
         (cx-thx, cy-thy, cz+sz), (cx+thx, cy-thy, cz+sz),
         (cx+thx, cy+thy, cz+sz), (cx-thx, cy+thy, cz+sz)]
    f = [(0,1,2,3), (4,7,6,5), (0,4,5,1), (1,5,6,2), (2,6,7,3), (3,7,4,0)]
    me = bpy.data.meshes.new(name)
    me.from_pydata(v, [], f)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o

G = []
# helmet + face
G.append(box('g_helmet', 0, 0.010, 1.600, 0.092, 0.098, 0.062, 0.72, 0.98))
G.append(box('g_brim',   0, 0.118, 1.585, 0.070, 0.028, 0.014, 0.90))
G.append(box('g_rear',   0, -0.094, 1.572, 0.080, 0.022, 0.045, 0.95))
for sx in (1, -1):
    G.append(box('g_rail%d' % sx, 0.094 * sx, 0.010, 1.596, 0.010, 0.060, 0.014))
G.append(box('g_mask',   0, 0.062, 1.482, 0.072, 0.058, 0.038, 0.92, 0.88))
G.append(box('g_goggle', 0, 0.100, 1.536, 0.074, 0.018, 0.030, 0.95))

# vest / plate carrier
G.append(box('g_vestf', 0, 0.120, 1.265, 0.168, 0.038, 0.105, 0.95))
G.append(box('g_vestb', 0, -0.116, 1.265, 0.166, 0.036, 0.105, 0.95))
for sx in (1, -1):
    G.append(box('g_vside%d' % sx, 0.152 * sx, 0.002, 1.190, 0.022, 0.098, 0.062))
    G.append(box('g_spad%d'  % sx, 0.170 * sx, 0.004, 1.400, 0.058, 0.092, 0.030, 0.85))
G.append(box('g_mag0', -0.054, 0.164, 1.225, 0.044, 0.026, 0.042))
G.append(box('g_mag1',  0.054, 0.164, 1.225, 0.044, 0.026, 0.042))
G.append(box('g_radio', -0.130, 0.128, 1.330, 0.026, 0.022, 0.040))

# belt / holster / pouch
G.append(box('g_belt',   0, 0, 0.985, 0.148, 0.104, 0.028, 1.0, 0.98))
G.append(box('g_buckle', 0, 0.114, 0.985, 0.030, 0.012, 0.022))
G.append(box('g_holster', -0.152, 0.055, 0.660, 0.030, 0.052, 0.078))
G.append(box('g_pouch',    0.154, 0.048, 0.940, 0.026, 0.050, 0.052))

# kneepads + boots
for sx in (1, -1):
    G.append(box('g_knee%d' % sx, 0.110 * sx, 0.070, 0.500, 0.070, 0.030, 0.058, 0.92, 0.92))
    G.append(box('g_boot%d' % sx, 0.110 * sx, 0.032, 0.055, 0.060, 0.105, 0.052))

print('GEAR BOXES:', len(G))

bpy.ops.object.select_all(action='DESELECT')
for g in G:
    g.select_set(True)
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.object.join()
print('JOINED: verts=%d faces=%d' % (len(ob.data.vertices), len(ob.data.polygons)))

# rebind with automatic weights
bpy.ops.object.select_all(action='DESELECT')
ob.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
print('VGROUPS:', len(ob.vertex_groups))

bpy.ops.wm.save_mainfile()
print('SAVED')
