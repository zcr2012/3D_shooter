import bpy, math
from mathutils import Vector

sc = bpy.context.scene
cam = bpy.data.objects['PreviewCam']
sc.camera = cam

# character is at the origin; frame it properly
target = Vector((0.0, 0.18, 1.05))

sc.render.engine = 'BLENDER_EEVEE'
sc.eevee.taa_render_samples = 128
sc.view_settings.view_transform = 'Standard'
sc.view_settings.exposure = 1.05

# studio-ish lighting for the character shot
for name, energy in [('Key', 90), ('Fill', 34), ('RimL', 70), ('RimR', 52), ('Front', 26)]:
    o = bpy.data.objects.get(name)
    if o:
        o.data.energy = energy
        o.hide_render = False

bg = sc.world.node_tree.nodes.get('Background')
bg.inputs[0].default_value = (0.055, 0.062, 0.078, 1)
bg.inputs[1].default_value = 0.70

shots = {
    'char_q34':   (Vector((2.10, 2.35, 1.62)), 42),
    'char_side':  (Vector((3.05, 0.30, 1.35)), 45),
    'char_front': (Vector((0.30, 3.05, 1.45)), 45),
}
for tag, (loc, lens) in shots.items():
    cam.location = loc
    cam.data.lens = lens
    cam.rotation_euler = (target - loc).to_track_quat('-Z', 'Y').to_euler()
    sc.render.resolution_x = 760
    sc.render.resolution_y = 1000
    sc.render.filepath = 'C:/Users/zhangshuai/WorkBuddy AI/3D_shooter/%s.png' % tag
    bpy.ops.render.render(write_still=True)
    print('rendered', tag)

bpy.ops.wm.save_mainfile()
print('SAVED')
