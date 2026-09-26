"""Dense-skeleton rebuild: more edge loops at joints -> clean deformation.
Run: blender -b file.blend -P rebuild_dense.py
"""
import bpy, bmesh, math
from mathutils import Vector

# ---------- remove the previous character, keep the rifle ----------
for n in ('SWAT_Operator', 'SWAT_Rig'):
    o = bpy.data.objects.get(n)
    if o:
        bpy.data.objects.remove(o, do_unlink=True)
for a in list(bpy.data.armatures):
    if a.users == 0:
        bpy.data.armatures.remove(a)
for m_ in list(bpy.data.meshes):
    if m_.users == 0:
        bpy.data.meshes.remove(m_)

# ============================================================
#  DENSE SKELETON  -  extra sample points along every limb so the
#  Skin Modifier generates enough edge loops to bend cleanly.
#  Z-up, faces +Y, ~1.78 m, ground Z=0
# ============================================================
coords, radii, edges = [], [], []

def add(x, y, z, r):
    coords.append((x, y, z)); radii.append(r)
    return len(coords) - 1

# ---- spine ----
i_pelvis = add(0.000, 0.000, 0.950, 0.112)
i_s1     = add(0.000, 0.000, 1.055, 0.104)
i_s2     = add(0.000, 0.002, 1.165, 0.116)
i_chest  = add(0.000, 0.004, 1.275, 0.138)
i_uc     = add(0.000, 0.004, 1.375, 0.120)
i_neck   = add(0.000, 0.006, 1.455, 0.052)
i_head   = add(0.000, 0.008, 1.560, 0.080)
i_htop   = add(0.000, 0.006, 1.680, 0.062)
edges += [(i_pelvis, i_s1), (i_s1, i_s2), (i_s2, i_chest), (i_chest, i_uc),
          (i_uc, i_neck), (i_neck, i_head), (i_head, i_htop)]

for side, sx in (('L', 1), ('R', -1)):
    # ---- arm: 10 points (was 6) ----
    a = []
    for x, z, r in [(0.155, 1.392, 0.066), (0.185, 1.340, 0.056),
                    (0.205, 1.240, 0.050), (0.218, 1.160, 0.046),
                    (0.226, 1.100, 0.044), (0.236, 1.030, 0.041),
                    (0.246, 0.960, 0.038), (0.252, 0.905, 0.035),
                    (0.256, 0.872, 0.034), (0.262, 0.822, 0.036)]:
        a.append(add(x * sx, 0.004 + (0.030 if z < 0.85 else 0.0), z, r))
    edges.append((i_uc, a[0]))
    for k in range(len(a) - 1):
        edges.append((a[k], a[k + 1]))

    # ---- leg: 11 points (was 7) ----
    g = []
    for x, y, z, r in [(0.100, 0.002, 0.930, 0.084), (0.103, 0.002, 0.820, 0.080),
                       (0.106, 0.002, 0.700, 0.076), (0.108, 0.002, 0.590, 0.068),
                       (0.110, 0.002, 0.500, 0.060), (0.110, 0.001, 0.400, 0.062),
                       (0.110, 0.000, 0.300, 0.058), (0.110, 0.000, 0.200, 0.054),
                       (0.110, 0.000, 0.100, 0.048), (0.110, 0.100, 0.045, 0.050),
                       (0.110, 0.170, 0.035, 0.038)]:
        g.append(add(x * sx, y, z, r))
    edges.append((i_pelvis, g[0]))
    for k in range(len(g) - 1):
        edges.append((g[k], g[k + 1]))

me = bpy.data.meshes.new('SWAT_mesh')
me.from_pydata(coords, edges, [])
me.update()
ob = bpy.data.objects.new('SWAT_Operator', me)
bpy.context.scene.collection.objects.link(ob)
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
print('DENSE SKELETON: %d verts, %d edges' % (len(me.vertices), len(me.edges)))

skin = ob.modifiers.new('Skin', 'SKIN')
skin.use_smooth_shade = False
sv = me.skin_vertices[0].data
for i, r in enumerate(radii):
    sv[i].radius = (r, r)
sv[i_pelvis].use_root = True

def apply_all(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    new_me = bpy.data.meshes.new_from_object(ev)
    obj.modifiers.clear()
    old = obj.data
    obj.data = new_me
    if old.users == 0:
        bpy.data.meshes.remove(old)

apply_all(ob)
print('AFTER SKIN: %d verts / %d faces' % (len(ob.data.vertices), len(ob.data.polygons)))

sub = ob.modifiers.new('Subsurf', 'SUBSURF')
sub.levels = 2
sub.render_levels = 2
apply_all(ob)
print('AFTER SUBSURF: %d verts / %d faces' % (len(ob.data.vertices), len(ob.data.polygons)))

# ---------- strip stray loose vertices ----------
bm = bmesh.new(); bm.from_mesh(ob.data)
loose = [v for v in bm.verts if len(v.link_edges) == 0]
if loose:
    bmesh.ops.delete(bm, geom=loose, context='VERTS')
bm.to_mesh(ob.data); bm.free(); ob.data.update()
print('removed %d loose verts' % len(loose))

# ---------- integrity ----------
bm = bmesh.new(); bm.from_mesh(ob.data)
bnd = [e for e in bm.edges if len(e.link_faces) == 1]
nm  = [e for e in bm.edges if len(e.link_faces) > 2]
unvis = set(bm.verts); shells = 0; sizes = []
while unvis:
    s = unvis.pop(); st = [s]; c = 1
    while st:
        v = st.pop()
        for e in v.link_edges:
            o2 = e.other_vert(v)
            if o2 in unvis:
                unvis.discard(o2); st.append(o2); c += 1
    shells += 1; sizes.append(c)
print('INTEGRITY: boundary=%d nonmanifold=%d shells=%d' % (len(bnd), len(nm), shells))
print('shell sizes:', sorted(sizes, reverse=True)[:6])
bm.free()

bpy.ops.wm.save_mainfile()
print('SAVED')
