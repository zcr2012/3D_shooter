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

def test(zL, zR, faLz, faRz, uaL=48, faL=20, uaR=38, faR=44):
    reset()
    pb['thigh.L'].rotation_euler = Euler((D(14), 0, 0), 'XYZ')
    pb['shin.L'].rotation_euler  = Euler((D(-26), 0, 0), 'XYZ')
    pb['thigh.R'].rotation_euler = Euler((D(-13), 0, 0), 'XYZ')
    pb['shin.R'].rotation_euler  = Euler((D(-22), 0, 0), 'XYZ')
    pb['spine'].rotation_euler   = Euler((D(11), 0, 0), 'XYZ')
    pb['upperarm.L'].rotation_euler = Euler((D(uaL), 0, D(zL)), 'XYZ')
    pb['forearm.L'].rotation_euler  = Euler((D(faL), 0, D(faLz)), 'XYZ')
    pb['upperarm.R'].rotation_euler = Euler((D(uaR), 0, D(zR)), 'XYZ')
    pb['forearm.R'].rotation_euler  = Euler((D(faR), 0, D(faRz)), 'XYZ')
    bpy.context.view_layer.update()
    l = arm.matrix_world @ pb['hand.L'].tail
    r = arm.matrix_world @ pb['hand.R'].tail
    return l, r

# sweep Z to bring hands inward toward the centreline
for zL, zR, flz, frz in [
    (-20, 24, 16, -20),
    (  0, 24, 16, -20),
    ( 20, 24, 16, -20),
    ( 35, 24, 16, -20),
    ( 35, 40, 16, -20),
    ( 50, 50, 16, -20),
]:
    l, r = test(zL, zR, flz, frz)
    print('zL=%+3d zR=%+3d | L=(%+.2f,%+.2f,%.2f) R=(%+.2f,%+.2f,%.2f) gap=%.2f' % (
        zL, zR, l.x, l.y, l.z, r.x, r.y, r.z, (l - r).length))
