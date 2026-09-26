import bpy, math
from mathutils import Vector

ob = bpy.data.objects['SWAT_Operator']
arm = bpy.data.objects['SWAT_Rig']

# ---------- reset bind ----------
ob.vertex_groups.clear()
for m in list(ob.modifiers):
    ob.modifiers.remove(m)
ob.parent = None

BN = ['root', 'hip', 'spine', 'chest', 'neck', 'head',
      'shoulder.L', 'upperarm.L', 'forearm.L', 'hand.L',
      'shoulder.R', 'upperarm.R', 'forearm.R', 'hand.R',
      'thigh.L', 'shin.L', 'foot.L', 'thigh.R', 'shin.R', 'foot.R']
vg = {n: ob.vertex_groups.new(name=n) for n in BN}

SEG = {}
for n in BN:
    b = arm.data.bones[n]
    SEG[n] = (Vector(b.head_local), Vector(b.tail_local))

def d2s(p, a, b):
    ab = b - a
    l2 = ab.length_squared
    if l2 == 0:
        return (p - a).length
    t = max(0.0, min(1.0, (p - a).dot(ab) / l2))
    return (p - (a + ab * t)).length

def allowed(p):
    x, y, z = p.x, p.y, p.z
    if abs(x) > 0.145 and z > 0.80:
        s = 'L' if x > 0 else 'R'
        r = ['shoulder.' + s, 'upperarm.' + s, 'forearm.' + s, 'hand.' + s]
        if z > 1.32:
            r += ['chest']
        return r
    if z < 0.93:
        s = 'L' if x > 0 else 'R'
        return ['thigh.' + s, 'shin.' + s, 'foot.' + s, 'hip']
    if z < 1.06:
        return ['hip', 'spine']
    if z < 1.17:
        return ['spine', 'chest']
    if z < 1.38:
        return ['chest', 'spine', 'shoulder.L', 'shoulder.R']
    if z < 1.46:
        return ['neck', 'chest']
    return ['head', 'neck']

BLEND = 0.075
cnt = {n: 0 for n in BN}
for v in ob.data.vertices:
    p = v.co
    cands = allowed(p)
    ds = sorted(((d2s(p, *SEG[n]), n) for n in cands), key=lambda t: t[0])
    d0, n0 = ds[0]
    if len(ds) > 1:
        d1, n1 = ds[1]
    else:
        d1, n1 = 1e9, None
    if n1 and (d1 - d0) < BLEND:
        w0 = 1.0 / (d0 + 1e-4)
        w1 = 1.0 / (d1 + 1e-4)
        s = w0 + w1
        vg[n0].add([v.index], w0 / s, 'REPLACE')
        vg[n1].add([v.index], w1 / s, 'REPLACE')
        cnt[n0] += 1; cnt[n1] += 1
    else:
        vg[n0].add([v.index], 1.0, 'REPLACE')
        cnt[n0] += 1

ob.parent = arm
ob.matrix_parent_inverse = arm.matrix_world.inverted()
mod = ob.modifiers.new('Armature', 'ARMATURE')
mod.object = arm
print('WEIGHTED:', {n: cnt[n] for n in BN if cnt[n]})

# ---------- verify every vertex got a weight ----------
no_w = sum(1 for v in ob.data.vertices if sum(g.weight for g in v.groups) < 0.001)
print('verts with NO weight:', no_w)

# ---------- verify deformation actually moves the mesh ----------
def bounds():
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = ev.to_mesh()
    r = (min(v.co.x for v in me.vertices), max(v.co.x for v in me.vertices),
         min(v.co.y for v in me.vertices), max(v.co.y for v in me.vertices),
         min(v.co.z for v in me.vertices), max(v.co.z for v in me.vertices))
    ev.to_mesh_clear()
    return r
print('DEFORMED bounds X %.3f..%.3f Y %.3f..%.3f Z %.3f..%.3f' % bounds())

bpy.ops.wm.save_mainfile()
print('SAVED')
