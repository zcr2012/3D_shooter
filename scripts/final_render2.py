import bpy, math
from mathutils import Vector

sc = bpy.context.scene
rifle = bpy.data.objects['AR_AssaultRifle']

# ---------- verify the rifle is present and where it sits ----------
print('rifle parent:', rifle.parent.name if rifle.parent else None,
      '| bone:', rifle.parent_bone)
print('rifle world loc: (%.2f, %.2f, %.2f)' % tuple(rifle.matrix_world.translation))
bb = [rifle.matrix_world @ Vector(c) for c in rifle.bound_box]
print('rifle bounds X %.2f..%.2f  Y %.2f..%.2f  Z %.2f..%.2f' % (
    min(v.x for v in bb), max(v.x for v in bb),
    min(v.y for v in bb), max(v.y for v in bb),
    min(v.z for v in bb), max(v.z for v in bb)))
print('rifle hide_render:', rifle.hide_render, '| hide_viewport:', rifle.hide_viewport)

# ---------- cameras INSIDE the room (room is X -4..4, Y -3.5..3.5) ----------
cam = bpy.data.objects['PreviewCam']
sc.camera = cam
cam.data.lens = 28

shots = {
    'scene_wide':   (Vector((-3.0, -3.0, 2.20)), Vector(( 0.6,  0.9, 1.00))),
    'scene_hero':   (Vector(( 1.9, -2.7, 1.65)), Vector((-1.1, -0.5, 1.10))),
    'scene_corner': (Vector(( 2.9,  2.7, 2.15)), Vector((-1.1, -0.8, 1.05))),
}
sc.render.resolution_x = 1280
sc.render.resolution_y = 760
sc.eevee.taa_render_samples = 96
for tag, (loc, tgt) in shots.items():
    cam.location = loc
    cam.rotation_euler = (tgt - loc).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = 'C:/Users/zhangshuai/WorkBuddy AI/3D_shooter/%s.png' % tag
    bpy.ops.render.render(write_still=True)
    print('rendered', tag)

bpy.ops.wm.save_mainfile()
print('SAVED')
