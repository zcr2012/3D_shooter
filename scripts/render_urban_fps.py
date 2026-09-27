"""Blender offline FPS asset preview, not a rendered Godot frame."""
import bpy,math,pathlib
from mathutils import Vector
root=str(pathlib.Path(__file__).resolve().parents[1])+'/'
bpy.ops.wm.open_mainfile(filepath=root+'outputs/urban/fps_kit.blend')
s=bpy.context.scene
s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.17,.22,.27,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.7
for loc,power in [((1,0,2),150),((-2,1,1),100)]:
 d=bpy.data.lights.new('Studio','AREA');d.energy=power;d.size=3;o=bpy.data.objects.new('Studio',d);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,.5,-.2))-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('FirstPerson');o=bpy.data.objects.new('FirstPerson',d);s.collection.objects.link(o);s.camera=o;o.rotation_euler=(Vector((0,1,0))).to_track_quat('-Z','Y').to_euler();d.sensor_fit='VERTICAL';d.sensor_height=24;d.lens=24/(2*math.tan(math.radians(72)/2));d.clip_start=.02
s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=True;s.cycles.device='CPU';s.render.threads_mode='FIXED';s.render.threads=2;s.render.resolution_x=960;s.render.resolution_y=540;s.render.resolution_percentage=100;s.render.filepath=root+'outputs/urban/fps_preview.png';bpy.ops.render.render(write_still=True)
