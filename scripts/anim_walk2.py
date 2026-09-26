"""Refined armed walk cycle.
Adds the secondary motion that makes a walk read as human:
  - lateral weight shift over the support leg
  - pelvic tilt and twist, shoulders counter-rotating
  - heel-strike / toe-off foot roll
  - subtle weapon bob and head stabilisation

Run: blender -b file.blend -P anim_walk2.py
"""
import bpy, math
from mathutils import Euler, Vector

D = math.radians
TAU = math.pi * 2.0

arm = bpy.data.objects['SWAT_Rig']
sc = bpy.context.scene
sc.render.fps = 24
CYCLE = 48

bpy.context.view_layer.objects.active = arm
if arm.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
arm.animation_data_clear()
for a in list(bpy.data.actions):
    if a.name.startswith('Walk'):
        bpy.data.actions.remove(a)

bpy.ops.object.mode_set(mode='POSE')
pb = arm.pose.bones
for b in pb:
    b.rotation_mode = 'XYZ'
    b.rotation_euler = (0, 0, 0)
    b.location = (0, 0, 0)

# ============================================================
#  LEG KEYS  -  8 phases per cycle (every 6 frames)
#  thigh +X = leg forward | shin -X = knee bends
#  foot +X = toe up (heel strike), -X = toe down (push off)
# ============================================================
# (phase, thigh_R, shin_R, foot_R, thigh_L, shin_L, foot_L)
LEG_KEYS = [
    (0.000,  28,  -4,  14,  -24, -12, -22),   # R heel strike / L toe off
    (0.125,  18, -18,   2,  -16, -30, -18),   # R foot flat, weight accepting
    (0.250,   2, -10,  -4,   -2, -48,   2),   # passing
    (0.375, -12,  -8, -16,   16, -34,  10),   # R heel off / push
    (0.500, -24, -12, -22,   28,  -4,  14),   # L heel strike (mirror of 0)
    (0.625, -16, -30, -18,   18, -18,   2),
    (0.750,  -2, -48,   2,    2, -10,  -4),
    (0.875,  16, -34,  10,  -12,  -8, -16),
    (1.000,  28,  -4,  14,  -24, -12, -22),   # loop
]

# ---------- vertical bob: two dips per cycle (one per step) ----------
def bob_at(t):
    # lowest just after each heel strike, highest at push-off
    return -0.026 * math.sin(TAU * t - 0.5) * 0.5 - 0.004

# ---------- lateral weight shift: hip rides over the support leg ----------
SWAY = 0.024
def sway_at(t):
    return -SWAY * math.sin(TAU * t)

# ---------- pelvic tilt (drop on the swing side) ----------
TILT = 3.2
def tilt_at(t):
    return TILT * math.sin(TAU * t)

# ---------- pelvic twist & shoulder counter-rotation ----------
TWIST_PELVIS = 5.0
TWIST_CHEST = -2.2          # small: upper body stays locked on the weapon

UPPER_BASE = {
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

action = bpy.data.actions.new('WalkArmed')
arm.animation_data_create()
arm.animation_data.action = action

def key(bone, frame, what='rotation_euler'):
    pb[bone].keyframe_insert(what, frame=frame)

# ---------- 1) legs: key at the 8 phases, Bezier smooths between ----------
for (t, tR, sR, ftR, tL, sL, ftL) in LEG_KEYS:
    f = int(round(t * CYCLE))
    sc.frame_set(f)
    pb['thigh.R'].rotation_euler = Euler((D(tR), 0, 0), 'XYZ')
    pb['shin.R'].rotation_euler  = Euler((D(sR), 0, 0), 'XYZ')
    pb['foot.R'].rotation_euler  = Euler((D(ftR), 0, 0), 'XYZ')
    pb['thigh.L'].rotation_euler = Euler((D(tL), 0, 0), 'XYZ')
    pb['shin.L'].rotation_euler  = Euler((D(sL), 0, 0), 'XYZ')
    pb['foot.L'].rotation_euler  = Euler((D(ftL), 0, 0), 'XYZ')
    for n in ('thigh.R', 'shin.R', 'foot.R', 'thigh.L', 'shin.L', 'foot.L'):
        key(n, f)

# ---------- 2) hips + upper body: dense sampling for smooth secondary motion ----------
for f in range(0, CYCLE + 1, 2):
    t = (f % CYCLE) / float(CYCLE)
    sc.frame_set(f)

    # hip: bob + sway + tilt + twist (all driven by phase)
    pb['hip'].location = (sway_at(t), bob_at(t), 0.0)
    pb['hip'].rotation_euler = Euler((
        D(4.0),                                # constant forward lean
        D(TWIST_PELVIS * math.sin(TAU * t)),   # twist about the vertical
        D(-4.0 + tilt_at(t)),                  # base tilt + pelvic drop
    ), 'XYZ')
    key('hip', f, 'location')
    key('hip', f, 'rotation_euler')

    # torso: counter-rotate against the pelvis, keep the weapon steady
    sx, sy, sz = UPPER_BASE['spine']
    pb['spine'].rotation_euler = Euler((D(sx), D(TWIST_CHEST * 0.5 * math.sin(TAU * t)), D(sz)), 'XYZ')
    key('spine', f)

    cx, cy, cz = UPPER_BASE['chest']
    pb['chest'].rotation_euler = Euler((D(cx), D(TWIST_CHEST * math.sin(TAU * t)), D(cz)), 'XYZ')
    key('chest', f)

    # head: stabilise against the bob so the sight line stays level
    nx, ny, nz = UPPER_BASE['neck']
    bob = bob_at(t)
    pb['neck'].rotation_euler = Euler((D(nx + bob * 120.0), 0, D(nz)), 'XYZ')
    key('neck', f)

    hx, hy, hz = UPPER_BASE['head']
    pb['head'].rotation_euler = Euler((D(hx - bob * 90.0), 0, D(hz)), 'XYZ')
    key('head', f)

    # arms: tiny bob so the weapon breathes with the stride
    for side, base in (('L', UPPER_BASE['upperarm.L']), ('R', UPPER_BASE['upperarm.R'])):
        ax, ay, az = base
        pb['upperarm.' + side].rotation_euler = Euler(
            (D(ax + bob * 260.0), D(ay), D(az)), 'XYZ')
        key('upperarm.' + side, f)

    for side, base in (('L', UPPER_BASE['forearm.L']), ('R', UPPER_BASE['forearm.R'])):
        fx, fy, fz = base
        pb['forearm.' + side].rotation_euler = Euler(
            (D(fx - bob * 150.0), D(fy), D(fz)), 'XYZ')
        key('forearm.' + side, f)

    for side in ('L', 'R'):
        sx2, sy2, sz2 = UPPER_BASE['shoulder.' + side]
        pb['shoulder.' + side].rotation_euler = Euler((D(sx2), D(sy2), D(sz2)), 'XYZ')
        key('shoulder.' + side, f)

# ---------- smooth interpolation ----------
def get_fcurves(act):
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
print('ACTION %s: fcurves=%d  keys=%d' % (
    action.name, len(fcs), sum(len(fc.keyframe_points) for fc in fcs)))

# ---------- render a strip of frames ----------
sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x = 460
sc.render.resolution_y = 640
sc.eevee.taa_render_samples = 24
sc.view_settings.view_transform = 'Standard'
sc.view_settings.exposure = 1.05
for name, e in [('Key', 90), ('Fill', 34), ('RimL', 70), ('RimR', 52), ('Front', 26)]:
    o = bpy.data.objects.get(name)
    if o:
        o.data.energy = e
        o.hide_render = False

cam = bpy.data.objects['PreviewCam']
sc.camera = cam
tgt = Vector((0.0, 0.18, 1.00))
loc = Vector((2.95, 0.30, 1.30))
cam.location = loc
cam.data.lens = 45
cam.rotation_euler = (tgt - loc).to_track_quat('-Z', 'Y').to_euler()

for f in (0, 6, 12, 18, 24):
    sc.frame_set(f)
    sc.render.filepath = 'C:/Users/zhangshuai/WorkBuddy AI/3D_shooter/walk2_f%02d.png' % f
    bpy.ops.render.render(write_still=True)
print('rendered frames')

sc.frame_set(0)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_mainfile()
print('SAVED')
