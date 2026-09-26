import bpy, math
from mathutils import Euler

arm = bpy.data.objects['SWAT_Rig']
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
pb = arm.pose.bones
D = math.radians

def reset():
    for b in pb:
        b.rotation_mode = 'XYZ'
        b.rotation_euler = (0, 0, 0)

def test(uaR, faR, zR, uaL, faL, zL):
    reset()
    pb['thigh.L'].rotation_euler = Euler((D(14), 0, 0), 'XYZ')
    pb['shin.L'].rotation_euler  = Euler((D(-26), 0, 0), 'XYZ')
    pb['thigh.R'].rotation_euler = Euler((D(-13), 0, 0), 'XYZ')
    pb['shin.R'].rotation_euler  = Euler((D(-22), 0, 0), 'XYZ')
    pb['spine'].rotation_euler   = Euler((D(11), 0, 0), 'XYZ')
    pb['upperarm.L'].rotation_euler = Euler((D(uaL), 0, D(zL)), 'XYZ')
    pb['forearm.L'].rotation_euler  = Euler((D(faL), 0, D(16)), 'XYZ')
    pb['upperarm.R'].rotation_euler = Euler((D(uaR), 0, D(zR)), 'XYZ')
    pb['forearm.R'].rotation_euler  = Euler((D(faR), 0, D(-20)), 'XYZ')
    bpy.context.view_layer.update()
    l = arm.matrix_world @ pb['hand.L'].tail
    r = arm.matrix_world @ pb['hand.R'].tail
    return l, r

# want R back near chest (y~0.18) and L forward (y~0.45)
for uaR, faR, zR in [(20, 62, -40), (12, 70, -40), (5, 75, -35),
                     (12, 70, -50), (5, 80, -45), (-5, 82, -40)]:
    l, r = test(uaR, faR, zR, 48, 20, 35)
    print('uaR=%3d faR=%2d zR=%+3d | R=(%+.2f,%+.2f,%.2f)  L=(%+.2f,%+.2f,%.2f)  gap=%.2f' % (
        uaR, faR, zR, r.x, r.y, r.z, l.x, l.y, l.z, (l - r).length))
