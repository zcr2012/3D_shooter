import bpy, math
from mathutils import Vector, Euler

ob = bpy.data.objects['SWAT_Operator']

# ---------- remove any old rig ----------
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

# ============================================================
#  ARMATURE - aligned to the skin skeleton joints
# ============================================================
arm_data = bpy.data.armatures.new('SWAT_Rig')
arm = bpy.data.objects.new('SWAT_Rig', arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm

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
        ('forearm.' + side,  (0.226 * sx, 0.004, 1.100), (0.256 * sx, 0.008, 0.872), 'upperarm.' + side, True),
        ('hand.' + side,     (0.256 * sx, 0.008, 0.872), (0.262 * sx, 0.034, 0.822), 'forearm.' + side, True),
        ('thigh.' + side,    (0.100 * sx, 0.002, 0.930), (0.110 * sx, 0.002, 0.500), 'hip', False),
        ('shin.' + side,     (0.110 * sx, 0.002, 0.500), (0.110 * sx, 0.000, 0.100), 'thigh.' + side, True),
        ('foot.' + side,     (0.110 * sx, 0.000, 0.100), (0.110 * sx, 0.170, 0.035), 'shin.' + side, True),
    ]

# ---------- build bones in edit mode (needs a proper context) ----------
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
eb = arm_data.edit_bones
made = {}
for name, h, t, par, conn in BONES:
    b = eb.new(name)
    b.head = Vector(h)
    b.tail = Vector(t)
    b.roll = 0.0
    made[name] = b
for name, h, t, par, conn in BONES:
    if par:
        made[name].parent = made[par]
        made[name].use_connect = conn
bpy.ops.object.mode_set(mode='OBJECT')
print('BONES:', len(arm_data.bones))

# ============================================================
#  WEIGHTS - distance to bone segment, blended
# ============================================================
BN = [n for n, *_ in BONES]
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

# region gate so a hand vertex can't be pulled by a thigh bone
def allowed(p):
    x, y, z = p.x, p.y, p.z
    if abs(x) > 0.145 and z > 0.78:
        s = 'L' if x > 0 else 'R'
        r = ['shoulder.' + s, 'upperarm.' + s, 'forearm.' + s, 'hand.' + s]
        if z > 1.32:
            r += ['chest']
        return r
    if z < 0.92:
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

BLEND = 0.070
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
print('WEIGHTS:', {n: cnt[n] for n in BN if cnt[n]})

# ============================================================
#  EXTREME TEST POSE  - validates skin deformation
# ============================================================
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
pb = arm.pose.bones
for b in pb:
    b.rotation_mode = 'XYZ'
    b.rotation_euler = (0, 0, 0)
D = math.radians
for side in ('L', 'R'):
    pb['upperarm.' + side].rotation_euler = Euler((D(78), 0, 0), 'XYZ')
    pb['forearm.' + side].rotation_euler  = Euler((D(52), 0, 0), 'XYZ')
    pb['thigh.' + side].rotation_euler    = Euler((D(38), 0, 0), 'XYZ')
    pb['shin.' + side].rotation_euler     = Euler((D(-72), 0, 0), 'XYZ')
pb['spine'].rotation_euler = Euler((D(14), 0, 0), 'XYZ')
bpy.ops.object.mode_set(mode='OBJECT')

# ---------- render ----------
sc = bpy.context.scene
cam = bpy.data.objects['PreviewCam']
target = Vector((0, 0.10, 0.92))
sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x = 640
sc.render.resolution_y = 840
sc.eevee.taa_render_samples = 48
sc.view_settings.view_transform = 'Standard'
sc.view_settings.exposure = 1.15
for n, e in [('Key', 70), ('Fill', 26), ('RimL', 50), ('RimR', 38), ('Front', 20)]:
    o = bpy.data.objects.get(n)
    if o:
        o.data.energy = e
for tag, loc in {'q34': Vector((2.1, 2.2, 1.55)),
                 'side': Vector((2.9, 0.20, 1.35))}.items():
    cam.location = loc
    cam.rotation_euler = (target - loc).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = 'C:/Users/zhangshuai/WorkBuddy AI/3D_shooter/rigcheck_%s.png' % tag
    bpy.ops.render.render(write_still=True)
    print('rendered', tag)

bpy.ops.wm.save_mainfile()
print('SAVED')
