"""Armed walk cycle for the SWAT operator.
Keyframes the legs through a standard 4-pose cycle while keeping the upper
body locked on the weapon.

Run: blender -b file.blend -P anim_walk.py
"""
import bpy, math
from mathutils import Euler, Vector

D = math.radians
arm = bpy.data.objects['SWAT_Rig']
rifle = bpy.data.objects['AR_AssaultRifle']

sc = bpy.context.scene
sc.render.fps = 24

# ---------- make sure the rig is in pose mode ----------
bpy.context.view_layer.objects.active = arm
if arm.mode != 'POSE':
    bpy.ops.object.mode_set(mode='POSE')
pb = arm.pose.bones

# ---------- clear existing animation ----------
arm.animation_data_clear()
for b in pb:
    b.rotation_mode = 'XYZ'
    b.rotation_euler = (0, 0, 0)
    b.location = (0, 0, 0)

# ---------- helper: verify leg axis directions once ----------
def probe():
    def reset():
        for b in pb:
            b.rotation_euler = (0, 0, 0)
            b.location = (0, 0, 0)
    reset()
    pb['thigh.L'].rotation_euler = Euler((D(30), 0, 0), 'XYZ')
    bpy.context.view_layer.update()
    fwd = arm.matrix_world @ pb['foot.L'].tail
    reset()
    pb['thigh.L'].rotation_euler = Euler((D(-30), 0, 0), 'XYZ')
    bpy.context.view_layer.update()
    back = arm.matrix_world @ pb['foot.L'].tail
    reset()
    pb['shin.L'].rotation_euler = Euler((D(-40), 0, 0), 'XYZ')
    bpy.context.view_layer.update()
    knee = arm.matrix_world @ pb['foot.L'].tail
    print('PROBE thigh +30 -> foot y=%.3f | thigh -30 -> y=%.3f | shin -40 -> y=%.3f z=%.3f'
          % (fwd.y, back.y, knee.y, knee.z))

probe()

# ============================================================
#  WALK CYCLE
#  48 frames = 2 steps. Right foot leads at frame 0.
#  Angles: thigh +X = leg forward, shin -X = knee bends
# ============================================================
FPS = 24
CYCLE = 48

# (frame, thigh_R, shin_R, foot_R, thigh_L, shin_L, foot_L, hip_bob, hip_twist)
# hip_bob in metres (local Y on the hip bone = world up)
POSES = [
    (0,   26,  -6,   6,  -22, -14, -10,  -0.012,  -4),   # contact: R fwd
    (6,   14, -14,   0,  -12, -32,  -6,  -0.028,  -2),   # down on R
    (12,   0,  -8,  -4,    6, -46,   4,   0.006,   0),   # passing
    (18, -14,  -6,  -8,   20, -30,   8,   0.016,   2),   # up
    (24, -22, -14, -10,   26,  -6,   6,  -0.012,   4),   # contact: L fwd (mirror)
    (30, -12, -32,  -6,   14, -14,   0,  -0.028,   2),   # down on L
    (36,   6, -46,   4,    0,  -8,  -4,   0.006,   0),   # passing
    (42,  20, -30,   8,  -14,  -6,  -8,   0.016,  -2),   # up
    (48,  26,  -6,   6,  -22, -14, -10,  -0.012,  -4),   # loop back to F0
]

# ---------- upper body: armed carry, locked on the weapon ----------
UPPER = {
    'hip':   (4, 0, -4),
    'spine': (-12, 0, 3),
    'chest': (-8, 0, 6),
    'neck':  (-4, 0, -3),
    'head':  (10, 0, -4),
    'shoulder.L': (0, 0, 0),
    'upperarm.L': (72, 0, 35),
    'forearm.L':  (26, 0, 16),
    'shoulder.R': (6, 0, 5),
    'upperarm.R': (46, 0, -40),
    'forearm.R':  (70, 0, -20),
}

# ---------- build the action ----------
action = bpy.data.actions.new('WalkArmed')
arm.animation_data_create()
arm.animation_data.action = action

for (f, tR, sR, ftR, tL, sL, ftL, bob, twist) in POSES:
    sc.frame_set(f)
    # legs
    pb['thigh.R'].rotation_euler = Euler((D(tR), 0, 0), 'XYZ')
    pb['shin.R'].rotation_euler  = Euler((D(sR), 0, 0), 'XYZ')
    pb['foot.R'].rotation_euler  = Euler((D(ftR), 0, 0), 'XYZ')
    pb['thigh.L'].rotation_euler = Euler((D(tL), 0, 0), 'XYZ')
    pb['shin.L'].rotation_euler  = Euler((D(sL), 0, 0), 'XYZ')
    pb['foot.L'].rotation_euler  = Euler((D(ftL), 0, 0), 'XYZ')
    # vertical bob on the hip (local Y runs along the bone = world up)
    pb['hip'].location = (0.0, bob, 0.0)
    # pelvis twist about the vertical, plus the static lean
    hx, hy, hz = UPPER['hip']
    pb['hip'].rotation_euler = Euler((D(hx), D(twist), D(hz)), 'XYZ')
    # keyframe the legs + hip
    for n in ('thigh.R', 'shin.R', 'foot.R', 'thigh.L', 'shin.L', 'foot.L'):
        pb[n].keyframe_insert('rotation_euler', frame=f)
    pb['hip'].keyframe_insert('rotation_euler', frame=f)
    pb['hip'].keyframe_insert('location', frame=f)

# ---------- upper body: keyframe once at the ends so it stays put ----------
for f in (0, CYCLE):
    sc.frame_set(f)
    for n, (rx, ry, rz) in UPPER.items():
        if n == 'hip':
            continue
        pb[n].rotation_euler = Euler((D(rx), D(ry), D(rz)), 'XYZ')
        pb[n].keyframe_insert('rotation_euler', frame=f)

# ---------- make interpolation smooth and cyclic ----------
def get_fcurves(act):
    """Blender 4.4+ moved fcurves into layers/slots; support both APIs."""
    try:
        return list(act.fcurves)
    except AttributeError:
        out = []
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    out.extend(cb.fcurves)
        return out

fcs = get_fcurves(action)
for fc in fcs:
    for kp in fc.keyframe_points:
        kp.interpolation = 'BEZIER'
        kp.handle_left_type = 'AUTO_CLAMPED'
        kp.handle_right_type = 'AUTO_CLAMPED'

sc.frame_start = 0
sc.frame_end = CYCLE

print('ACTION: %s  fcurves=%d  frames=%d' % (action.name, len(fcs), CYCLE))

# ---------- render a few frames to inspect ----------
sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x = 520
sc.render.resolution_y = 700
sc.eevee.taa_render_samples = 24
sc.view_settings.view_transform = 'Standard'
sc.view_settings.exposure = 1.05
cam = bpy.data.objects['PreviewCam']
sc.camera = cam
for name, e in [('Key', 90), ('Fill', 34), ('RimL', 70), ('RimR', 52), ('Front', 26)]:
    o = bpy.data.objects.get(name)
    if o:
        o.data.energy = e
        o.hide_render = False

target = Vector((0.0, 0.18, 1.00))
loc = Vector((2.95, 0.30, 1.30))
cam.location = loc
cam.data.lens = 45
cam.rotation_euler = (target - loc).to_track_quat('-Z', 'Y').to_euler()

for f in (0, 6, 12, 18):
    sc.frame_set(f)
    sc.render.filepath = 'C:/Users/zhangshuai/WorkBuddy AI/3D_shooter/walk_f%02d.png' % f
    bpy.ops.render.render(write_still=True)
    print('rendered frame', f)

sc.frame_set(0)
bpy.ops.wm.save_mainfile()
print('SAVED')
