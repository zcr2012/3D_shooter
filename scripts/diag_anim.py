import bpy, math
from mathutils import Vector

arm = bpy.data.objects['SWAT_Rig']
sc = bpy.context.scene
act = arm.animation_data.action if arm.animation_data else None
print('action:', act.name if act else 'NONE')

pb = arm.pose.bones

def dump(frame):
    sc.frame_set(frame)
    bpy.context.view_layer.update()
    out = []
    for n in ('head', 'hand.R', 'foot.L', 'foot.R', 'hip'):
        p = arm.matrix_world @ pb[n].tail
        out.append('%s=(%.2f,%.2f,%.2f)' % (n, p.x, p.y, p.z))
    print('  f=%2d  %s' % (frame, '  '.join(out)))
    # also report the raw channel values so we can spot bad keys
    h = pb['hip']
    print('        hip.loc=(%.3f,%.3f,%.3f) hip.rot=(%.1f,%.1f,%.1f)deg' % (
        h.location.x, h.location.y, h.location.z,
        math.degrees(h.rotation_euler.x), math.degrees(h.rotation_euler.y),
        math.degrees(h.rotation_euler.z)))

print('=== pose samples ===')
for f in (0, 6, 12, 18, 24):
    dump(f)

# check the hip location fcurve range
def get_fcurves(a):
    try:
        return list(a.fcurves)
    except AttributeError:
        out = []
        for layer in a.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    out.extend(cb.fcurves)
        return out

print('=== hip location fcurves ===')
for fc in get_fcurves(act):
    if 'hip' in fc.data_path and 'location' in fc.data_path:
        vals = [kp.co[1] for kp in fc.keyframe_points]
        print('  %s[%d]  min=%.4f max=%.4f' % (fc.data_path, fc.array_index,
                                              min(vals), max(vals)))
