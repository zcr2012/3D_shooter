import bpy, bmesh
from mathutils import Vector

ob = bpy.data.objects['SWAT_Operator']
bm = bmesh.new(); bm.from_mesh(ob.data)

unvis = set(bm.verts)
shells = []
while unvis:
    s = unvis.pop(); st = [s]; comp = [s]
    while st:
        v = st.pop()
        for e in v.link_edges:
            o = e.other_vert(v)
            if o in unvis:
                unvis.discard(o); st.append(o); comp.append(o)
    shells.append(comp)

print('SHELLS:', len(shells))
for i, c in enumerate(shells):
    xs = [v.co.x for v in c]; ys = [v.co.y for v in c]; zs = [v.co.z for v in c]
    print('  shell %d: %4d verts  X %+.2f..%+.2f  Y %+.2f..%+.2f  Z %.2f..%.2f' % (
        i, len(c), min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
bm.free()
