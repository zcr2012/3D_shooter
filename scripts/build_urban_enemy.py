"""Blender enemy variant: distinct cloth atlas, ID removal and authored fall clip.
Does not overwrite v09 source/assets. Run Blender -b -P this script.
"""
import bpy,bmesh,pathlib,math
from mathutils import Quaternion,Vector
from PIL import Image,ImageOps
ROOT=pathlib.Path(__file__).resolve().parents[1];OUT=ROOT/'godot_project/assets/urban';SOURCE=ROOT/'outputs/urban'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'outputs/v09/swat_visual_v09.blend'))
keep={'SWAT_Rig','SWAT_Operator','AR_AssaultRifle','AR_Magazine'}
for o in list(bpy.data.objects):
 if o.name not in keep:bpy.data.objects.remove(o,do_unlink=True)
# Replace the authored cloth tile with licensed fabric, warm clay palette.
im=Image.open(ROOT/'godot_project/assets/swat_operator_SWAT_v08_Atlas_BaseColor.png').convert('RGBA')
fabric=Image.open(ROOT/'third_party/polyhaven/fabric_pattern_07_col_1_1k.jpg').convert('L').resize((256,512))
fabric=ImageOps.colorize(fabric,(47,34,26),(153,119,83)).convert('RGBA');im.paste(fabric,(0,512))
im.save(OUT/'materials/contractor_atlas.png')
image=bpy.data.images.load(str(OUT/'materials/contractor_atlas.png'));image.name='Contractor_Atlas';image.pack()
for m in bpy.data.materials:
 if m.use_nodes:
  for n in m.node_tree.nodes:
   if n.type=='TEX_IMAGE' and n.image and n.image.name=='SWAT_v08_Atlas_BaseColor':n.image=image
# Remove the old SWAT lettering only, keeping the underlying carrier patch.
char=bpy.data.objects['SWAT_Operator'];bm=bmesh.new();bm.from_mesh(char.data)
faces=[f for f in bm.faces if all(abs(v.co.x)<.05 and -.175<v.co.y<-.167 and 1.338<v.co.z<1.370 for v in f.verts)]
bmesh.ops.delete(bm,geom=faces,context='FACES');bm.to_mesh(char.data);bm.free()
rig=bpy.data.objects['SWAT_Rig'];rig.animation_data.action=bpy.data.actions['IdleArmed'];bpy.context.scene.frame_set(0)
base={b.name:(b.location.copy(),b.rotation_quaternion.copy(),b.scale.copy()) for b in rig.pose.bones}
a=bpy.data.actions.new('FallArmed');a.use_fake_user=True;rig.animation_data.action=a
for frame,amount in [(0,0),(7,.16),(16,.63),(25,1),(34,1)]:
 for b in rig.pose.bones:
  loc,rot,scale=base[b.name];b.rotation_mode='QUATERNION';b.location=loc;b.rotation_quaternion=rot;b.scale=scale
  if b.name=='hip':
   b.location.y-=.69*amount;b.rotation_quaternion=rot@Quaternion(Vector((1,0,0)),math.radians(83)*amount)
  if b.name.startswith('shin.'):
   b.rotation_quaternion=rot@Quaternion(Vector((1,0,0)),math.radians(18)*amount)
  if b.name.startswith('upperarm.'):
   b.rotation_quaternion=rot@Quaternion(Vector((0,0,1)),math.radians(15)*amount)
  b.keyframe_insert('location',frame=frame,group=b.name);b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name);b.keyframe_insert('scale',frame=frame,group=b.name)
# Contact correction is sampled on every exported fall frame: no below-floor torso.
for frame in range(35):
 bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
 ev=char.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
 lowest=min((ev.matrix_world@v.co).z for v in mesh.vertices);ev.to_mesh_clear()
 hip=rig.pose.bones['hip'];hip.location.y-=lowest;hip.keyframe_insert('location',frame=frame,group='hip')
# Original short lateral locomotion cycle, distinct from the old forward walk.
strafe=bpy.data.actions.new('StrafeArmed');strafe.use_fake_user=True;rig.animation_data.action=strafe
for frame in range(25):
 phase=math.tau*frame/24
 for b in rig.pose.bones:
  loc,rot,scale=base[b.name];b.rotation_mode='QUATERNION';b.location=loc;b.rotation_quaternion=rot;b.scale=scale
  side_phase=phase+(math.pi if b.name.endswith('.R') else 0)
  if b.name.startswith('thigh.'):
   b.rotation_quaternion=rot@Quaternion(Vector((0,0,1)),math.sin(side_phase)*.16)
  elif b.name.startswith('shin.'):
   b.rotation_quaternion=rot@Quaternion(Vector((1,0,0)),max(0,math.sin(side_phase))*.17)
  elif b.name=='hip':b.location.x+=math.sin(phase)*.012
  b.keyframe_insert('location',frame=frame,group=b.name);b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name);b.keyframe_insert('scale',frame=frame,group=b.name)
for frame in range(25):
 bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
 ev=char.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
 lowest=min((ev.matrix_world@v.co).z for v in mesh.vertices);ev.to_mesh_clear()
 hip=rig.pose.bones['hip'];hip.location.y-=lowest;hip.keyframe_insert('location',frame=frame,group='hip')
rig.animation_data.action=bpy.data.actions['IdleArmed'];bpy.context.scene.frame_set(0)
bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'contractor.blend'),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'contractor.glb'),export_format='GLB',use_selection=True,export_skins=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_force_sampling=True,export_anim_slide_to_zero=True,export_anim_single_armature=True,export_optimize_animation_size=False,export_cameras=False,export_lights=False)
print('CONTRACTOR_BUILT',len(faces),'ID faces removed')
