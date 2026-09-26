"""SWAT character rebuild via Skin Modifier -> continuous topology.
Runs in Blender background mode:  blender -b file.blend -P this.py
"""
import bpy, bmesh, math
from mathutils import Vector

SCENE = "C:/Users/zhangshuai/WorkBuddy AI/3D_shooter/swat_operator.blend"

# ---------- clean any prior character ----------
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
#  SKELETON  (vertex + edge wire the Skin Modifier will wrap)
#  Z-up, faces +Y, 1.78 m tall, ground Z=0
# ============================================================
names, coords, radii, edges = [], [], [], []

def add(name, x, y, z, r):
    names.append(name); coords.append((x, y, z)); radii.append(r)
    return len(names) - 1

i_pelvis = add('pelvis',  0.000, 0.000, 0.950, 0.112)
i_s1     = add('spine1',  0.000, 0.000, 1.055, 0.104)
i_s2     = add('spine2',  0.000, 0.002, 1.165, 0.116)
i_chest  = add('chest',   0.000, 0.004, 1.275, 0.138)
i_uc     = add('uchest',  0.000, 0.004, 1.375, 0.120)
i_neck   = add('neck',    0.000, 0.006, 1.455, 0.052)
i_head   = add('head',    0.000, 0.008, 1.560, 0.080)
i_htop   = add('headtop', 0.000, 0.006, 1.680, 0.062)
edges += [(i_pelvis, i_s1), (i_s1, i_s2), (i_s2, i_chest), (i_chest, i_uc),
          (i_uc, i_neck), (i_neck, i_head), (i_head, i_htop)]

for side, sx in (('L', 1), ('R', -1)):
    a  = add('shoulder' + side, 0.155 * sx, 0.004, 1.392, 0.066)
    b  = add('uarm' + side,     0.200 * sx, 0.004, 1.300, 0.050)
    c  = add('elbow' + side,    0.226 * sx, 0.004, 1.100, 0.044)
    d  = add('farm' + side,     0.246 * sx, 0.006, 0.950, 0.039)
    e  = add('wrist' + side,    0.256 * sx, 0.008, 0.872, 0.034)
    f  = add('hand' + side,     0.262 * sx, 0.034, 0.822, 0.036)
    edges += [(i_uc, a), (a, b), (b, c), (c, d), (d, e), (e, f)]

    h  = add('hip' + side,   0.100 * sx, 0.002, 0.930, 0.084)
    j  = add('thigh' + side, 0.105 * sx, 0.002, 0.720, 0.074)
    k  = add('knee' + side,  0.110 * sx, 0.002, 0.500, 0.060)
    l  = add('shin' + side,  0.110 * sx, 0.000, 0.300, 0.056)
    m  = add('ankle' + side, 0.110 * sx, 0.000, 0.100, 0.048)
    n  = add('foot' + side,  0.110 * sx, 0.100, 0.045, 0.050)
    o2 = add('toe' + side,   0.110 * sx, 0.170, 0.035, 0.038)
    edges += [(i_pelvis, h), (h, j), (j, k), (k, l), (l, m), (m, n), (n, o2)]

me = bpy.data.meshes.new('SWAT_mesh')
me.from_pydata(coords, edges, [])
me.update()
ob = bpy.data.objects.new('SWAT_Operator', me)
bpy.context.scene.collection.objects.link(ob)
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
print('SKELETON: %d verts, %d edges' % (len(me.vertices), len(me.edges)))

# ---------- Skin modifier ----------
skin = ob.modifiers.new('Skin', 'SKIN')
skin.use_smooth_shade = False
sv = me.skin_vertices[0].data
for i, r in enumerate(radii):
    sv[i].radius = (r, r)
sv[i_pelvis].use_root = True

# ---------- apply modifiers via depsgraph (robust in background) ----------
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
print('AFTER SKIN: verts=%d faces=%d' % (len(ob.data.vertices), len(ob.data.polygons)))

# ---------- light subdivision for a rounded low-poly look ----------
sub = ob.modifiers.new('Subsurf', 'SUBSURF')
sub.levels = 1
sub.render_levels = 1
apply_all(ob)
print('AFTER SUBSURF: verts=%d faces=%d' % (len(ob.data.vertices), len(ob.data.polygons)))

# ---------- integrity check ----------
bm = bmesh.new(); bm.from_mesh(ob.data)
bnd = [e for e in bm.edges if len(e.link_faces) == 1]
nm  = [e for e in bm.edges if len(e.link_faces) > 2]
unvis = set(bm.verts); shells = 0
while unvis:
    s = unvis.pop(); st = [s]
    while st:
        v = st.pop()
        for e in v.link_edges:
            oo = e.other_vert(v)
            if oo in unvis:
                unvis.discard(oo); st.append(oo)
    shells += 1
zs = [v.co.z for v in bm.verts]
xs = [v.co.x for v in bm.verts]
ys = [v.co.y for v in bm.verts]
print('INTEGRITY: boundary=%d nonmanifold=%d shells=%d' % (len(bnd), len(nm), shells))
print('BOUNDS: X %.3f..%.3f  Y %.3f..%.3f  Z %.3f..%.3f' % (
    min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
print('HEIGHT: %.3f m' % (max(zs) - min(zs)))
bm.free()

bpy.ops.wm.save_mainfile()
print('SAVED')
