"""CPU-renderable, reproducible inspection view; does not save studio changes."""
import bpy
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'outputs' / 'v09'
OUT.mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene
rig = bpy.data.objects['SWAT_Rig']
rig.animation_data.action = bpy.data.actions['IdleArmed']
scene.frame_set(0)
for ob in scene.objects:
    ob.hide_render = ob.name not in {'SWAT_Rig', 'SWAT_Operator', 'AR_AssaultRifle', 'AR_Magazine'}
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.004))
floor = bpy.context.object
mat = bpy.data.materials.new('ReviewFloor')
mat.diffuse_color = (.085, .11, .13, 1)
floor.data.materials.append(mat)
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.35, .42, .5, 1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .35
for name, loc, power, size in [('Key', (3, 4, 4), 650, 3), ('Fill', (-3, 2, 2), 350, 3), ('Rim', (-1, -3, 3), 750, 2)]:
    data = bpy.data.lights.new('Review' + name, 'AREA')
    data.energy = power
    data.size = size
    ob = bpy.data.objects.new(data.name, data)
    scene.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector((0, 0, .9)) - ob.location).to_track_quat('-Z', 'Y').to_euler()
data = bpy.data.cameras.new('ReviewCamera')
cam = bpy.data.objects.new('ReviewCamera', data)
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 2.0
cam.location = (2.6, 4, 2)
cam.rotation_euler = (Vector((0, .08, .83)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.threads_mode = 'FIXED'
scene.render.threads = 2
scene.render.resolution_x = 640
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'AgX'
scene.view_settings.exposure = .4
scene.render.filepath = str(OUT / 'v09_hero.png')
bpy.ops.render.render(write_still=True)
print('V09_CPU_RENDER_DONE')
