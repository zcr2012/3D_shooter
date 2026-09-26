import bpy, math
from mathutils import Euler, Vector

arm = bpy.data.objects['SWAT_Rig']
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
pb = arm.pose.bones
D = math.radians

def reset():
    for b in pb:
        b.rotation_mode = 'XYZ'
        b.rotation_euler = (0, 0, 0)

def measure(uaL, faL, uaR, faR):
    reset()
    # keep torso/legs constant
    pb['thigh.L'].rotation_euler = Euler((D(14), 0, 0), 'XYZ')
    pb['shin.L'].rotation_euler  = Euler((D(-26), 0, 0), 'XYZ')
    pb['thigh.R'].rotation_euler = Euler((D(-13), 0, 0), 'XYZ')
    pb['shin.R'].rotation_euler  = Euler((D(-22), 0, 0), 'XYZ')
    pb['spine'].rotation_euler   = Euler((D(11), 0, 0), 'XYZ')

    pb['upperarm.L'].rotation_euler = Euler((D(uaL[0]), 0, D(uaL[1])), 'XYZ')
    pb['forearm.L'].rotation_euler  = Euler((D(faL[0]),  0, D(faL[1])), 'XYZ')
    pb['upperarm.R'].rotation_euler = Euler((D(uaR[0]), 0, D(uaR[1])), 'XYZ')
    pb['forearm.R'].rotation_euler  = Euler((D(faR[0]),  0, D(faR[1])), 'XYZ')
    bpy.context.view_layer.update()

    l = arm.matrix_world @ pb['hand.L'].tail
    r = arm.matrix_world @ pb['hand.R'].tail
    return l, r

# target: hands near chest height Z~1.22-1.32, forward Y~0.25-0.42,
# close together in X (support hand near centreline, trigger hand at right side)
tests = [
    ('A', (58, -22), (24, 16), (46, 24), (58, -20)),
    ('B', (44, -20), (16, 14), (34, 22), (40, -16)),
    ('C', (36, -18), (12, 12), (26, 20), (30, -14)),
    ('D', (30, -16), (10, 10), (20, 18), (22, -12)),
]
for name, uaL, faL, uaR, faR in tests:
    l, r = measure(uaL, faL, uaR, faR)
    print('%s  handL=(%.2f,%.2f,%.2f)  handR=(%.2f,%.2f,%.2f)  gap=%.2f' % (
        name, l.x, l.y, l.z, r.x, r.y, r.z, (l - r).length))
