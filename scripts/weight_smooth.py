import bpy, math
from mathutils import Vector

ob = bpy.data.objects['SWAT_Operator']
arm = bpy.data.objects['SWAT_Rig']

ob.vertex_groups.clear()
for m in list(ob.modifiers):
    ob.modifiers.remove(m)
ob.parent = None

BN = ['hip', 'spine', 'chest', 'neck', 'head',
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

# Smooth inverse-distance^4 weighting over ALL bones, top-4 influences.
# No hard region gate -> no discontinuity at the shoulder, so no blades.
POW = 4.0
EPS = 0.012
MAXINF = 4

for v in ob.data.vertices:
    p = v.co
    ws = []
    for n in BN:
        d = d2s(p, *SEG[n])
        ws.append((1.0 / ((d + EPS) ** POW), n))
    ws.sort(reverse=True)
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
print('verts with NO weight:', no_w)
print('avg influences per vert: %.2f' % (
    sum(len([g for g in v.groups if g.weight > 0.004]) for v in ob.data.vertices) / len(ob.data.vertices)))

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
