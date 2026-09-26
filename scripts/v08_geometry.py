"""Shared low-poly surface construction with atlas UVs and explicit skinning."""
import bpy, bmesh, math
from mathutils import Vector, Matrix
TILE={'cloth':0,'webbing':1,'polymer':2,'metal':3,'rubber':4,'glove':5,'lens':6,'mark':7}
class Builder:
    def __init__(self):
        self.v=[]; self.f=[]; self.uv=[]; self.w=[]; self.smooth=[]
    def vert(self,p,uv,weights):
        self.v.append(tuple(p)); self.uv.append(uv); self.w.append(dict(weights)); return len(self.v)-1
    def face(self,ids,smooth=True):
        self.f.append(tuple(ids)); self.smooth.append(smooth)
    def atlas(self,uv,tile):
        t=TILE[tile] if isinstance(tile,str) else tile
        # 2 percent gutter protects mipmaps; primitive UV domain is 0..1.
        return ((t%4+.025+.95*uv[0])/4,(t//4+.025+.95*uv[1])/2)
    def loft(self,rings,tile='cloth',weights=None,n=20,fold=0,phase=0):
        # rings = [(x,y,z,rx,ry),...], ordered along axis Z.
        if fold:
            dense=[]
            for j,(a,bb) in enumerate(zip(rings,rings[1:])):
                dense.append(a)
                mid=[(a[k]+bb[k])*.5 for k in range(5)]
                wrinkle=1+fold*1.7*math.sin(j*2.3+phase)
                mid[3]*=wrinkle; mid[4]*=wrinkle
                dense.append(tuple(mid))
            dense.append(rings[-1]); rings=dense
        start=len(self.v)
        for j,(x,y,z,rx,ry) in enumerate(rings):
            for i in range(n):
                a=2*math.pi*i/n
                fac=1+fold*(math.sin(3*a+j*.95+phase)*.5+math.sin(7*a-j*1.5)*.3)
                p=(x+rx*fac*math.cos(a),y+ry*fac*math.sin(a),z)
                w=weights(Vector(p)) if callable(weights) else (weights or {})
                self.vert(p,self.atlas((i/n,j/max(1,len(rings)-1)),tile),w)
        for j in range(len(rings)-1):
            for i in range(n): self.face((start+j*n+i,start+j*n+(i+1)%n,start+(j+1)*n+(i+1)%n,start+(j+1)*n+i))
        self.face(tuple(start+i for i in reversed(range(n))),False)
        self.face(tuple(start+(len(rings)-1)*n+i for i in range(n)),False)
    def ellipsoid(self,center,scale,tile='polymer',weights=None,n=24,rings=12):
        cx,cy,cz=center; sx,sy,sz=scale
        profiles=[]
        for j in range(rings+1):
            lat=-math.pi/2+math.pi*(.003+.994*j/rings)
            profiles.append((cx,cy,cz+sz*math.sin(lat),sx*math.cos(lat),sy*math.cos(lat)))
        self.loft(profiles,tile,weights,n)
    def append_mesh(self,mesh,tile='webbing',weights=None,matrix=None,smooth=False):
        offset=len(self.v); m=matrix or Matrix.Identity(4)
        co=[m@v.co for v in mesh.vertices]
        lo=[min(v[k] for v in co) for k in range(3)]; hi=[max(v[k] for v in co) for k in range(3)]
        for v in co:
            # Dominant face projection is overridden per loop on material build.
            uv=((v.x-lo[0])/max(hi[0]-lo[0],.001),(v.z-lo[2])/max(hi[2]-lo[2],.001))
            self.vert(v,self.atlas(uv,tile),weights(v) if callable(weights) else (weights or {}))
        for p in mesh.polygons: self.face([offset+i for i in p.vertices],smooth)
    def box(self,center,size,tile='webbing',weights=None,bevel=.004,rot=None):
        bm=bmesh.new(); bmesh.ops.create_cube(bm,size=1)
        for v in bm.verts:
            v.co.x*=size[0]; v.co.y*=size[1]; v.co.z*=size[2]
        if bevel>0:
            bmesh.ops.bevel(bm,geom=list(bm.edges),offset=bevel,segments=2,affect='EDGES',clamp_overlap=True)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        me=bpy.data.meshes.new('_part'); bm.to_mesh(me); bm.free()
        matrix=Matrix.Translation(Vector(center))
        if rot is not None: matrix @= rot.to_matrix().to_4x4()
        self.append_mesh(me,tile,weights,matrix)
        bpy.data.meshes.remove(me)
    def tube(self,points,radius,tile='metal',weights=None,n=10):
        pts=[Vector(p) for p in points]; start=len(self.v)
        for j,p in enumerate(pts):
            d=(pts[min(j+1,len(pts)-1)]-pts[max(j-1,0)]).normalized()
            ref=Vector((0,0,1)) if abs(d.z)<.95 else Vector((0,1,0))
            x=d.cross(ref).normalized(); y=d.cross(x).normalized()
            r=radius[j] if isinstance(radius,(list,tuple)) else radius
            for i in range(n):
                v=p+r*(x*math.cos(math.tau*i/n)+y*math.sin(math.tau*i/n))
                self.vert(v,self.atlas((i/n,j/max(1,len(pts)-1)),tile),weights(v) if callable(weights) else (weights or {}))
        for j in range(len(pts)-1):
            for i in range(n): self.face((start+j*n+i,start+j*n+(i+1)%n,start+(j+1)*n+(i+1)%n,start+(j+1)*n+i))
        self.face(tuple(start+i for i in reversed(range(n))),False)
        self.face(tuple(start+(len(pts)-1)*n+i for i in range(n)),False)
    def plate(self,outline,y,depth,tile='webbing',weights=None,bevel=.004):
        # Closed XZ outline extruded in Y.
        bm=bmesh.new(); n=len(outline)
        v=[bm.verts.new((x,y+d,z)) for d in [-depth/2,depth/2] for x,z in outline]
        bm.faces.new(list(reversed(v[:n]))); bm.faces.new(v[n:])
        for i in range(n): bm.faces.new([v[i],v[(i+1)%n],v[(i+1)%n+n],v[i+n]])
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        if bevel: bmesh.ops.bevel(bm,geom=list(bm.edges),offset=bevel,segments=2,affect='EDGES',clamp_overlap=True)
        me=bpy.data.meshes.new('_plate'); bm.to_mesh(me); bm.free()
        self.append_mesh(me,tile,weights); bpy.data.meshes.remove(me)
    def object(self,name,material,rig=None):
        me=bpy.data.meshes.new(name+'_Mesh'); me.from_pydata(self.v,[],self.f); me.update()
        layer=me.uv_layers.new(name='AtlasUV')
        for p,smooth in zip(me.polygons,self.smooth):
            p.use_smooth=smooth
            for li in p.loop_indices: layer.data[li].uv=self.uv[me.loops[li].vertex_index]
        bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free()
        ob=bpy.data.objects.new(name,me); bpy.context.scene.collection.objects.link(ob)
        me.materials.append(material)
        names=set(k for w in self.w for k in w)
        groups={n:ob.vertex_groups.new(name=n) for n in names}
        for i,w in enumerate(self.w):
            total=sum(w.values())
            for n,value in w.items():
                if value>0: groups[n].add([i],value/total,'REPLACE')
        if rig:
            ob.parent=rig; ob.matrix_parent_inverse=rig.matrix_world.inverted()
            mod=ob.modifiers.new('Skin','ARMATURE'); mod.object=rig
        return ob
