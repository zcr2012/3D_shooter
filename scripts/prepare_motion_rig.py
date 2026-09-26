"""Repair skinning without rebuilding the existing UV atlas. Save a candidate."""
import bpy, bmesh, json
from pathlib import Path
from mathutils import Vector
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'outputs'
OUT.mkdir(exist_ok=True)
ob = bpy.data.objects['SWAT_Operator']
arm = bpy.data.objects['SWAT_Rig']

def components(mesh):
    edges = [[] for _ in mesh.vertices]
    for e in mesh.edges:
        a, b = e.vertices
        edges[a].append(b); edges[b].append(a)
    remaining = set(range(len(edges))); result = []
    while remaining:
        stack = [remaining.pop()]; ids = []
        while stack:
            i = stack.pop(); ids.append(i)
            for j in edges[i]:
                if j in remaining:
                    remaining.remove(j); stack.append(j)
        result.append(ids)
    return sorted(result, key=len, reverse=True)

shells = components(ob.data)
deform_names = {b.name for b in arm.data.bones if b.use_deform}
groups = {g.name: g for g in ob.vertex_groups}
records = []
for ids in shells[1:]:
    c = sum((ob.data.vertices[i].co for i in ids), Vector()) / len(ids)
    side = 'L' if c.x > 0 else 'R'
    if c.z > 1.43:
        bone = 'head'
    elif c.z > 1.365 and abs(c.x) > 0.10:
        bone = 'upperarm.' + side
    elif c.z > 1.10:
        bone = 'chest'
    elif c.z > 0.85:
        bone = 'hip'
    elif c.z > 0.57:
        bone = 'thigh.' + side
    elif c.z > 0.20:
        bone = 'shin.' + side
    else:
        bone = 'foot.' + side
    for g in ob.vertex_groups:
        g.remove(ids)
    groups[bone].add(ids, 1.0, 'REPLACE')
    records.append({'bone': bone, 'vertices': len(ids), 'center': list(c)})

# Smooth anatomical masks prevent an elbow from pulling the abdomen or the
# opposite thigh pulling the crotch. No hard seams at shoulder/hip transitions.
def fade(value, a, b):
    t=max(0.0,min(1.0,(value-a)/(b-a)))
    return t*t*(3-2*t)
def segment_distance(p, name):
    b=arm.data.bones[name]; a=b.head_local; delta=b.tail_local-a
    t=max(0.0,min(1.0,(p-a).dot(delta)/delta.length_squared))
    return (p-a-t*delta).length
for i in shells[0]:
    p=ob.data.vertices[i].co
    side='L' if p.x>=0 else 'R'
    arm_mask=fade(abs(p.x),.115,.215)*fade(p.z,.70,.92)*(1-fade(p.z,1.42,1.51))
    leg_mask=(1-fade(p.z,.79,1.01))*(1-arm_mask)
    torso_mask=max(0,1-arm_mask-leg_mask)
    pools=[(arm_mask,['shoulder.'+side,'upperarm.'+side,'forearm.'+side,'hand.'+side]),
           (leg_mask,['thigh.'+side,'shin.'+side,'foot.'+side]),
           (torso_mask,['hip','spine','chest','neck','head'])]
    weights={}
    for mask,names in pools:
        ws=[(n,1/(segment_distance(p,n)+.014)**4) for n in names]
        total=sum(w for _,w in ws)
        for n,w in ws: weights[n]=weights.get(n,0)+mask*w/total
    best=sorted(weights.items(),key=lambda x:x[1],reverse=True)[:4]
    total=sum(w for _,w in best)
    for g in ob.vertex_groups: g.remove([i])
    for n,w in best:
        if w>0: groups[n].add([i],w/total,'REPLACE')

# Correct outward orientation separately for each closed connected component.
# The old tapered boxes used reversed winding. Preserve their atlas UVs.
bm = bmesh.new(); bm.from_mesh(ob.data)
bm.verts.ensure_lookup_table()
rigid_ids = set(i for ids in shells[1:] for i in ids)
gear_edges = [e for e in bm.edges if all(v.index in rigid_ids for v in e.verts)]
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
bmesh.ops.bevel(bm, geom=gear_edges, offset=0.003, segments=2, affect='EDGES', clamp_overlap=True)
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
bm.to_mesh(ob.data); bm.free(); ob.data.update()
for p in ob.data.polygons:
    # All interpolated bevel vertices remain rigidly weighted to one bone.
    p.use_smooth = any(len(ob.data.vertices[i].groups) > 1 for i in p.vertices)

# Remove accidental accumulated display pose before generating new actions.
arm.animation_data_clear()
for b in arm.pose.bones:
    b.rotation_mode = 'QUATERNION'
    b.rotation_quaternion = (1, 0, 0, 0)
    b.location = (0, 0, 0)
    b.scale = (1, 1, 1)
bpy.context.view_layer.update()
print('RIGID_SHELLS_REPAIRED', len(records), 'VERTS', len(ob.data.vertices))
for name in ['thigh.L', 'shin.L', 'foot.L', 'upperarm.R', 'forearm.R', 'hand.R']:
    b = arm.data.bones[name]
    print('BONE', name, 'head', list(b.head_local), 'tail', list(b.tail_local))
r = bpy.data.objects['AR_AssaultRifle']
for i, ids in enumerate(components(r.data)):
    vs = [r.data.vertices[j].co for j in ids]
    center = sum(vs, Vector()) / len(vs)
    print('RIFLE_SHELL', i, len(ids), 'center', [round(v, 4) for v in center],
          'min', [round(min(v[k] for v in vs), 4) for k in range(3)],
          'max', [round(max(v[k] for v in vs), 4) for k in range(3)])
for img in bpy.data.images:
    if img.source in {'GENERATED', 'FILE'} and img.has_data and img.name != 'Render Result':
        if not img.packed_file: img.pack()
(OUT / 'rig_repair.json').write_text(json.dumps({'rigid_shells': records}, indent=2), encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'swat_motion_v07.blend'))
print('CANDIDATE_SAVED')
