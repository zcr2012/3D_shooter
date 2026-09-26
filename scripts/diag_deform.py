import bpy
from mathutils import Vector

ob = bpy.data.objects['SWAT_Operator']
arm = bpy.data.objects['SWAT_Rig']

def deformed_bounds():
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = ev.to_mesh()
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    r = (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs))
    ev.to_mesh_clear()
    return r

print('POSED  bounds X %.3f..%.3f  Y %.3f..%.3f  Z %.3f..%.3f' % deformed_bounds())

# check weight coverage: how many verts have any weight?
no_w = 0
for v in ob.data.vertices:
    if sum(g.weight for g in v.groups) < 0.001:
        no_w += 1
print('verts with NO weight:', no_w, 'of', len(ob.data.vertices))

# which groups do the arm-region verts belong to?
sample = [v for v in ob.data.vertices if v.co.x > 0.25 and 0.9 < v.co.z < 1.4]
print('arm-region verts:', len(sample))
gnames = {g.index: g.name for g in ob.vertex_groups}
for v in sample[:5]:
    ws = sorted(((g.weight, gnames[g.group]) for g in v.groups if g.weight > 0.01), reverse=True)
    print('   vert', v.index, [(round(w, 2), n) for w, n in ws[:3]])
