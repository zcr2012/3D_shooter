"""Actual-mesh sampling and source budget report for v09, no visual overclaim."""
import bpy,bmesh,json,math,hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parent.parent; OUT=ROOT/'outputs'/'v09'
rig=bpy.data.objects['SWAT_Rig']; ob=bpy.data.objects['SWAT_Operator']; sc=bpy.context.scene
# Only edges whose endpoints share the SAME single rigid influence count.
rigid_edges=[]
for e in ob.data.edges:
    a,b=e.vertices; va,vb=ob.data.vertices[a],ob.data.vertices[b]
    if len(va.groups)==len(vb.groups)==1 and va.groups[0].group==vb.groups[0].group:
        length=(va.co-vb.co).length
        if length>.0005: rigid_edges.append((a,b,length))
sole_ids={side:[v.index for v in ob.data.vertices if len(v.groups)==1 and ob.vertex_groups[v.groups[0].group].name=='foot.'+side and v.co.z<.028] for side in ['L','R']}
report={'assets':{},'actions':{},'limitations':['Intersections between intentionally overlapping cloth/equipment shells not automatically certified.','Fingers are geometry posed for grip, not separately articulated.','Flat-ground sample tests do not certify slope IK or all blending states.']}
for name in ['SWAT_Operator','AR_AssaultRifle','AR_Magazine']:
    obj=bpy.data.objects[name]; mesh=obj.data
    bm=bmesh.new(); bm.from_mesh(mesh)
    report['assets'][name]={'vertices':len(mesh.vertices),'triangles':sum(len(p.vertices)-2 for p in mesh.polygons),
        'boundary_edges':sum(e.is_boundary for e in bm.edges),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),
        'degenerate_faces':sum(f.calc_area()<1e-11 for f in bm.faces),'materials':len(mesh.materials),'uv_layers':len(mesh.uv_layers)}
    bm.free()
for action in bpy.data.actions:
    rig.animation_data.action=action; max_strain=0; min_sole=1; max_r=0; nonfinite=0; count=0
    for frame in range(int(action.frame_range[0]),int(action.frame_range[1])+1):
        sc.frame_set(frame); dg=bpy.context.evaluated_depsgraph_get(); ev=ob.evaluated_get(dg); mesh=ev.to_mesh()
        for a,b,length in rigid_edges: max_strain=max(max_strain,abs((mesh.vertices[a].co-mesh.vertices[b].co).length/length-1))
        for ids in sole_ids.values(): min_sole=min(min_sole,min(mesh.vertices[i].co.z for i in ids))
        nonfinite+=sum(not all(math.isfinite(x) for x in v.co) for v in mesh.vertices)
        r=bpy.data.objects['AR_AssaultRifle']
        max_r=max(max_r,(rig.matrix_world@rig.pose.bones['hand.R'].tail-r.matrix_world@Vector((0,-.055,-.098))).length)
        ev.to_mesh_clear(); count+=1
    report['actions'][action.name]={'sample_frames':count,'lowest_sole_m':min_sole,'max_rigid_edge_strain':max_strain,
        'non_finite_vertices':nonfinite,'right_hand_target_gap_m':max_r,'duration':(action.frame_range[1]-action.frame_range[0])/30}
report['weightless']=sum(sum(g.weight for g in v.groups)<.001 for v in ob.data.vertices)
report['weight_sum_error']=max(abs(sum(g.weight for g in v.groups)-1) for v in ob.data.vertices)
report['max_influences']=max(len(v.groups) for v in ob.data.vertices)
report['bone_count']=len(rig.data.bones)
report['total_triangles']=sum(a['triangles'] for a in report['assets'].values())
report['exported_glb_sha256']=hashlib.sha256((ROOT/'godot_project/assets/swat_operator.glb').read_bytes()).hexdigest()
report['source_blend_sha256']=hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()
print(json.dumps(report,indent=2)); (OUT/'visual_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
assert report['weightless']==0 and report['max_influences']<=4
assert all(v['non_finite_vertices']==0 and v['max_rigid_edge_strain']<.003 and v['right_hand_target_gap_m']<.003 for v in report['actions'].values())
assert all(v['lowest_sole_m']>-.003 for v in report['actions'].values())
assert all(v['degenerate_faces'] == 0 for v in report['assets'].values())
assert report['weight_sum_error'] < 1e-5
assert report['bone_count'] == 22 and len(report['actions']) == 7
print('V09_MESH_AUDIT_PASS')
