import bpy, math
from mathutils import Vector

sc = bpy.context.scene
arm = bpy.data.objects['SWAT_Rig']
swat = bpy.data.objects['SWAT_Operator']

# ---------- place the operator in a tactical spot in the room ----------
arm.location = Vector((-1.2, -0.6, 0.0))
arm.rotation_euler = (0, 0, math.radians(28))
bpy.context.view_layer.update()

# ---------- remove the old studio lights, light the room instead ----------
for o in list(bpy.data.objects):
    if o.name in ('Key', 'Fill', 'RimL', 'RimR', 'Front'):
        bpy.data.objects.remove(o, do_unlink=True)

def area(name, loc, target, energy, size, color=(1, 1, 1)):
    ld = bpy.data.lights.new(name, 'AREA')
    ld.energy = energy
    ld.size = size
    ld.color = color
    o = bpy.data.objects.new(name, ld)
    sc.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    return o

# ceiling strip lights
area('CeilL', (-2.0, -1.5, 2.80), (-2.0, -1.5, 0.0), 120, 2.0, (1.0, 0.97, 0.90))
area('CeilR', ( 2.0,  1.5, 2.80), ( 2.0,  1.5, 0.0), 120, 2.0, (1.0, 0.97, 0.90))
# daylight through the window (+X wall)
area('WinLight', (4.4, 0.0, 1.6), (0.0, 0.0, 1.2), 260, 2.6, (0.72, 0.83, 1.0))
# fill from the doorway (-Y)
area('DoorFill', (1.95, -4.2, 1.5), (1.95, 0.0, 1.2), 90, 2.2, (0.85, 0.90, 1.0))
# gentle bounce
area('Bounce', (0.0, 0.0, 0.25), (0.0, 0.0, 1.5), 30, 4.0, (0.95, 0.93, 0.88))

# ---------- world ----------
w = sc.world
w.use_nodes = True
bg = w.node_tree.nodes.get('Background')
bg.inputs[0].default_value = (0.045, 0.050, 0.062, 1)
bg.inputs[1].default_value = 0.55

# ---------- render settings ----------
sc.render.engine = 'BLENDER_EEVEE'
sc.eevee.taa_render_samples = 96
sc.view_settings.view_transform = 'Filmic' if 'Filmic' in [
    t.name for t in sc.view_settings.bl_rna.properties['view_transform'].enum_items] else 'Standard'
sc.view_settings.exposure = 0.35

cam = bpy.data.objects['PreviewCam']
sc.camera = cam
cam.data.lens = 32

shots = {
    'scene_wide':   (Vector((-3.4, -5.2, 2.30)), Vector((-0.4, 0.2, 1.05))),
    'scene_hero':   (Vector(( 1.5, -3.4, 1.70)), Vector((-1.0, -0.4, 1.15))),
    'scene_corner': (Vector(( 3.3,  3.0, 2.20)), Vector((-0.8, -0.5, 1.05))),
}
for tag, (loc, tgt) in shots.items():
    cam.location = loc
    cam.rotation_euler = (tgt - loc).to_track_quat('-Z', 'Y').to_euler()
    sc.render.resolution_x = 1280
    sc.render.resolution_y = 760
    sc.render.filepath = 'C:/Users/zhangshuai/WorkBuddy AI/3D_shooter/%s.png' % tag
    bpy.ops.render.render(write_still=True)
    print('rendered', tag)

bpy.ops.wm.save_mainfile()
print('SAVED')
