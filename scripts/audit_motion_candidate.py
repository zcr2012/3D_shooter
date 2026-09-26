"""Fresh-session audit of actual deformed meshes, not only rig targets."""
import bpy, bmesh, json, math
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
arm=bpy.data.objects['SWAT_Rig']; ob=bpy.data.objects['SWAT_Operator']; sc=bpy.context.scene
# Rigid shell edge strain across all poses; boots use actual transformed vertices.
rigid_edges=[(e.vertices[0],e.vertices[1],(ob.data.vertices[e.vertices[0]].co-ob.data.vertices[e.vertices[1]].co).length)
             for e in ob.data.edges if all(len(ob.data.vertices[i].groups)==1 for i in e.vertices)]
boot_ids={s:[v.index for v in ob.data.vertices if v.co.z<.11 and len(v.groups)==1 and ob.vertex_groups[v.groups[0].group].name=='foot.'+s] for s in ['L','R']}
report={'clips':{},'assets':{},'warnings':['No finger articulation, slope IK, mocap or release-grade visual certification.']}
for action in bpy.data.actions:
    arm.animation_data.action=action
    max_strain=0; min_sole=1; errors=0; sample_count=0; hand_gaps=[]; mag_gaps=[]
    for frame in range(int(action.frame_range[0]),int(action.frame_range[1])+1):
        sc.frame_set(frame); dg=bpy.context.evaluated_depsgraph_get(); ev=ob.evaluated_get(dg); me=ev.to_mesh()
        for a,b,rest in rigid_edges:
            if rest>1e-6:
                ratio=abs((me.vertices[a].co-me.vertices[b].co).length/rest-1)
                max_strain=max(max_strain,ratio)
        for side,ids in boot_ids.items():
            min_sole=min(min_sole,min(me.vertices[i].co.z for i in ids))
        for v in me.vertices:
            if not all(math.isfinite(x) for x in v.co): errors+=1
        rifle=bpy.data.objects['AR_AssaultRifle']; mag=bpy.data.objects['AR_Magazine']
        hand_gaps.append((arm.matrix_world@arm.pose.bones['hand.R'].tail-rifle.matrix_world@Vector((0,-.055,-.098))).length)
        if action.name!='ReloadArmed':
            mag_gaps.append((rifle.matrix_world.translation-mag.matrix_world.translation).length)
        ev.to_mesh_clear(); sample_count+=1
    report['clips'][action.name]={'sampled_frames':sample_count,'max_rigid_edge_strain':max_strain,'min_boot_sole_z_m':min_sole,
        'non_finite_vertices':errors,'max_right_grip_gap_m':max(hand_gaps),'max_seated_magazine_offset_m':max(mag_gaps,default=0)}
for name in ['SWAT_Operator','AR_AssaultRifle','AR_Magazine']:
    mesh=bpy.data.objects[name].data
    bm=bmesh.new(); bm.from_mesh(mesh)
    report['assets'][name]={'vertices':len(mesh.vertices),'triangles':sum(len(p.vertices)-2 for p in mesh.polygons),
        'boundary_edges':sum(e.is_boundary for e in bm.edges),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),
        'uv_layers':len(mesh.uv_layers),'materials':len(mesh.materials)}
    bm.free()
report['weightless_vertices']=sum(sum(g.weight for g in v.groups)<.001 for v in ob.data.vertices)
report['max_weight_sum_error']=max(abs(sum(g.weight for g in v.groups)-1) for v in ob.data.vertices)
report['max_influences']=max(len(v.groups) for v in ob.data.vertices)
report['bones']=len(arm.data.bones)
print(json.dumps(report,indent=2))
(ROOT/'outputs'/'motion_mesh_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
assert report['weightless_vertices']==0
assert all(c['max_rigid_edge_strain']<.001 and c['non_finite_vertices']==0 and c['max_right_grip_gap_m']<.003 for c in report['clips'].values())
print('MESH_MOTION_AUDIT_PASS')
