import bpy, math
from mathutils import Vector, Euler

ob = bpy.data.objects['SWAT_Operator']

# ---------- clean any previous rig ----------
old = bpy.data.objects.get('SWAT_Rig')
if old:
    bpy.data.objects.remove(old, do_unlink=True)
for a in list(bpy.data.armatures):
    if a.users == 0:
        bpy.data.armatures.remove(a)
ob.vertex_groups.clear()
for m in list(ob.modifiers):
    ob.modifiers.remove(m)
ob.parent = None

# ---------- armature ----------
arm_data = bpy.data.armatures.new('SWAT_Rig')
arm = bpy.data.objects.new('SWAT_Rig', arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)

BONES = [
    ('root',  (0, 0, 0.000), (0, 0, 0.200), None,    False),
    ('hip',   (0, 0, 0.950), (0, 0, 1.055), 'root',  False),
    ('spine', (0, 0, 1.055), (0, 0, 1.165), 'hip',   True),
    ('chest', (0, 0, 1.165), (0, 0, 1.375), 'spine', True),
    ('neck',  (0, 0, 1.375), (0, 0, 1.455), 'chest', True),
    ('head',  (0, 0, 1.455), (0, 0, 1.680), 'neck',  True),
]
for side, sx in (('L', 1), ('R', -1)):
    BONES += [
        ('shoulder.' + side, (0.050 * sx, 0.004, 1.390), (0.155 * sx, 0.004, 1.392), 'chest', False),
        ('upperarm.' + side, (0.155 * sx, 0.004, 1.392), (0.226 * sx, 0.004, 1.100), 'shoulder.' + side, True),
        ('forearm.' + side,  (0.226 * sx, 0.004, 1.100), (0.256 * sx, 0.004, 0.872), 'upperarm.' + side, True),
        ('hand.' + side,     (0.256 * sx, 0.004, 0.872), (0.262 * sx, 0.034, 0.822), 'forearm.' + side, True),
        ('thigh.' + side,    (0.100 * sx, 0.002, 0.930), (0.110 * sx, 0.002, 0.500), 'hip', False),
        ('shin.' + side,     (0.110 * sx, 0.002, 0.500), (0.110 * sx, 0.000, 0.100), 'thigh.' + side, True),
        ('foot.' + side,     (0.110 * sx, 0.000, 0.100), (0.110 * sx, 0.170, 0.035), 'shin.' + side, True),
    ]

bpy.ops.object.mode_set(mode='EDIT')
eb = arm_data.edit_bones
made = {}
for n, h, t, p, c in BONES:
    b = eb.new(n); b.head = Vector(h); b.tail = Vector(t); b.roll = 0.0
    made[n] = b
for n, h, t, p, c in BONES:
    if p:
        made[n].parent = made[p]
        made[n].use_connect = c
bpy.ops.object.mode_set(mode='OBJECT')
print('BONES:', len(arm_data.bones))

# ---------- smooth inverse-distance weights ----------
BN = ['hip', 'spine', 'chest', 'neck', 'head',
      'shoulder.L', 'upperarm.L', 'forearm.L', 'hand.L',
      'shoulder.R', 'upperarm.R', 'forearm.R', 'hand.R',
      'thigh.L', 'shin.L', 'foot.L', 'thigh.R', 'shin.R', 'foot.R']
vg = {n: ob.vertex_groups.new(name=n) for n in BN}
SEG = {}
for n in BN:
    b = arm_data.bones[n]
    SEG[n] = (Vector(b.head_local), Vector(b.tail_local))

def d2s(p, a, b):
    ab = b - a
    l2 = ab.length_squared
    if l2 == 0:
        return (p - a).length
    t = max(0.0, min(1.0, (p - a).dot(ab) / l2))
    return (p - (a + ab * t)).length

POW, EPS, MAXINF = 4.0, 0.012, 4
for v in ob.data.vertices:
    p = v.co
    ws = sorted(((1.0 / ((d2s(p, *SEG[n]) + EPS) ** POW), n) for n in BN), reverse=True)
    top = ws[:MAXINF]
    tot = sum(w for w, _ in top)
    for w, n in top:
        ww = w / tot
        if ww > 0.004:
            vg[n].add([v.index], ww, 'REPLACE')

ob.parent = arm
ob.matrix_parent_inverse = arm.matrix_world.inverted()
mod = ob.modifiers.new('Armature', 'ARMATURE')
mod.object = arm

no_w = sum(1 for v in ob.data.vertices if sum(g.weight for g in v.groups) < 0.001)
print('verts with NO weight:', no_w, '(must be 0)')
print('avg influences: %.2f' % (
    sum(len([g for g in v.groups if g.weight > 0.004]) for v in ob.data.vertices) / len(ob.data.vertices)))

bpy.ops.wm.save_mainfile()
print('SAVED')
