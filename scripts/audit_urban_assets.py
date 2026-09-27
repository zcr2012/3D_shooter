"""Small reproducible Blender audit; reports geometry limits, not commercial certification."""
import bpy,json,pathlib,hashlib,math
ROOT=pathlib.Path(__file__).resolve().parents[1];report={}
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'outputs/urban/contractor.blend'))
rig=bpy.data.objects['SWAT_Rig']
for name in ['FallArmed','StrafeArmed']:
 action=bpy.data.actions[name];rig.animation_data.action=action;low=100;high=-100;bad=0
 for frame in range(int(action.frame_range[1])+1):
  bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();e=bpy.data.objects['SWAT_Operator'].evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=e.to_mesh()
  points=[e.matrix_world@v.co for v in mesh.vertices];low=min(low,min(v.z for v in points));high=max(high,max(v.z for v in points));bad+=sum(not all(math.isfinite(c) for c in v) for v in points);e.to_mesh_clear()
 report[name]={'frames':int(action.frame_range[1])+1,'lowest_vertex_m':low,'highest_vertex_m':high,'non_finite_vertices':bad}
 assert low > -.003 and bad==0,(name,low,bad)
report['assets']={}
for name in ['contractor','fps_kit','witness']:
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/f'outputs/urban/{name}.blend'))
 meshes=[o for o in bpy.data.objects if o.type=='MESH']
 report['assets'][name]={'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),'mesh_objects':len(meshes)}
report['files']={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for name in ['contractor','fps_kit','witness'] for p in [f'godot_project/assets/urban/{name}.glb',f'outputs/urban/{name}.blend']}
report['limitations']=['Only two new skeletal clips are sampled here; prior clips retain their v09 audit.','No skin self-intersection, foot IK, hand-to-magazine contact or performance certification.','FPS limbs and civilian legs use rigid pivots, not production anatomical rigs.']
(ROOT/'outputs/urban/asset_audit.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
