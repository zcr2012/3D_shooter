"""Union intersecting garment panels, transfer skinning, preserve rigid gear."""
import bpy,bmesh,math
from mathutils import Vector
from mathutils.kdtree import KDTree

def tailor(ob,rig):
    original=ob.data
    # Only fabric tile 0; all faces of a primitive share the same tile.
    uv=original.uv_layers.active.data
    cloth=set(p.index for p in original.polygons if all(int(uv[li].uv.x*4)==0 and int(uv[li].uv.y*2)==0 for li in p.loop_indices))
    cloth_ids=set(i for p in original.polygons if p.index in cloth for i in p.vertices)
    kd=KDTree(len(cloth_ids)); weights={}
    for ii,i in enumerate(sorted(cloth_ids)):
        kd.insert(original.vertices[i].co,i)
        weights[i]={ob.vertex_groups[g.group].name:g.weight for g in original.vertices[i].groups}
    kd.balance()
    # Copy fabric into a temporary object, preserving the untouched gear atlas.
    mesh=original.copy(); bm=bmesh.new(); bm.from_mesh(mesh); bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.index not in cloth],context='FACES')
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    bm.to_mesh(mesh); bm.free()
    garment=bpy.data.objects.new('_GarmentUnion',mesh); bpy.context.scene.collection.objects.link(garment)
    bpy.ops.object.select_all(action='DESELECT'); garment.select_set(True); bpy.context.view_layer.objects.active=garment
    garment.data.remesh_voxel_size=.007
    garment.data.remesh_voxel_adaptivity=0
    bpy.ops.object.voxel_remesh()
    smooth=garment.modifiers.new('RelaxStitchJunctions','SMOOTH'); smooth.factor=.45; smooth.iterations=3
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    dec=garment.modifiers.new('GarmentBudget','DECIMATE'); dec.ratio=min(1,11500/max(1,len(garment.data.polygons)))
    bpy.ops.object.modifier_apply(modifier=dec.name)
    # Data transfer from nearby original cloth, capped and renormalized to four.
    names={n for w in weights.values() for n in w}; groups={n:garment.vertex_groups.new(name=n) for n in names}
    for v in garment.data.vertices:
        mixed={}
        for co,i,d in kd.find_n(v.co,4):
            for n,w in weights[i].items(): mixed[n]=mixed.get(n,0)+w/(d+.004)**3
        top=sorted(mixed.items(),key=lambda kv:kv[1],reverse=True)[:4]; total=sum(w for n,w in top)
        for n,w in top: groups[n].add([v.index],w/total,'REPLACE')
    # New simple cloth UVs sample only the dedicated repeatable fabric swatch.
    garment.data.uv_layers.clear(); uv=garment.data.uv_layers.new(name='AtlasUV')
    for p in garment.data.polygons:
        p.use_smooth=True
        for li in p.loop_indices:
            co=garment.data.vertices[garment.data.loops[li].vertex_index].co
            uv.data[li].uv=((.025+.95*((math.atan2(co.y,co.x)/math.tau+.5)%1))/4,(.025+.95*(co.z/1.75))/2)
    garment.data.materials.clear(); garment.data.materials.append(original.materials[0])
    # Remove original fabric only after replacement exists, then merge render mesh.
    bm=bmesh.new(); bm.from_mesh(original); bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.index in cloth],context='FACES')
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    bm.to_mesh(original); bm.free()
    bpy.ops.object.select_all(action='DESELECT'); garment.select_set(True); ob.select_set(True); bpy.context.view_layer.objects.active=ob
    bpy.ops.object.join()
    print('TAILORED',len(ob.data.vertices),len(ob.data.polygons))
