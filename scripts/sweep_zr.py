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

def test(zR, uaR, faR, faRz, zL=35, uaL=48, faL=20, faLz=16):
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

for zR, uaR, faR in [(-24, 38, 44), (-40, 38, 44), (-55, 38, 44),
                     (-55, 30, 50), (-70, 30, 50), (-70, 24, 55)]:
    l, r = test(zR, uaR, faR, -20)
    print('zR=%+3d uaR=%2d faR=%2d | L=(%+.2f,%+.2f,%.2f) R=(%+.2f,%+.2f,%.2f) gap=%.2f' % (
        zR, uaR, faR, l.x, l.y, l.z, r.x, r.y, r.z, (l - r).length))
