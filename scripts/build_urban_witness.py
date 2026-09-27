"""Original low-poly civilian with rigid limb pivots (not a mocap-ready full rig)."""
import bpy,pathlib,math
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1];OUT=ROOT/'godot_project/assets/urban'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,color):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85;return m
shirt=mat('Dock uniform',(.31,.38,.39));pants=mat('Denim',(.095,.12,.15));skin=mat('Skin',(.48,.31,.22));hair=mat('Hair',(.06,.035,.025));rubber=mat('Shoe rubber',(.03,.036,.04));iris=mat('Eyes',(.055,.038,.025));badge=mat('ID card',(.68,.72,.68))
def ellipsoid(name,loc,scale,m):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=10,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
 for f in o.data.polygons:f.use_smooth=True
 return o
def tapered(name,rings,material):
 verts=[];faces=[];n=16
 for x,y,z,rx,ry in rings:
  verts.extend((x+rx*math.cos(i*math.tau/n),y+ry*math.sin(i*math.tau/n),z) for i in range(n))
 for j in range(len(rings)-1):
  for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
 faces.extend([tuple(reversed(range(n))),tuple((len(rings)-1)*n+i for i in range(n))]);me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.data.materials.append(material)
 for f in me.polygons:f.use_smooth=True
 return o
torso=tapered('WorkShirt',[(0,0,.79,.20,.12),(0,0,.91,.18,.12),(0,0,1.12,.21,.135),(0,0,1.32,.25,.13),(0,0,1.39,.12,.095)],shirt)
ellipsoid('Head',(0,0,1.58),(.112,.108,.152),skin)
ellipsoid('Hair',(0,-.026,1.67),(.112,.091,.073),hair)
ellipsoid('Nose',(0,.105,1.56),(.021,.036,.035),skin)
for x in [-.043,.043]:
 ellipsoid('Eye',(x,.097,1.615),(.014,.01,.008),iris)
 ellipsoid('Ear',(math.copysign(.112,x),0,1.575),(.018,.014,.032),skin)
ellipsoid('Mouth',(0,.100,1.515),(.030,.009,.006),hair)
ellipsoid('Collar',(0,0,1.385),(.095,.095,.035),shirt)
for z in [1,1.08,1.16,1.24,1.32]:ellipsoid('Button',(0,.137,z),(.004,.004,.004),rubber)
ellipsoid('Badge',(-.105,.134,1.235),(.032,.008,.046),badge)
for side,name in [(-1,'LegLeft'),(1,'LegRight')]:
 x=side*.115;objects=[]
 objects.append(tapered('Trouser',[(x,0,.10,.066,.064),(x,0,.35,.075,.075),(x,0,.45,.084,.085),(x,0,.60,.09,.086),(x,0,.84,.106,.10)],pants))
 objects.append(ellipsoid('Shoe',(x,.05,.072),(.085,.147,.068),rubber))
 pivot=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(pivot);pivot.location=(x,0,.82);bpy.context.view_layer.update()
 for o in objects:o.parent=pivot;o.matrix_parent_inverse=pivot.matrix_world.inverted()
 tapered('Sleeve',[(side*.27,0,1.30,.09,.085),(side*.29,0,1.16,.075,.074),(side*.29,0,1.02,.064,.063)],shirt)
 tapered('Forearm',[(side*.29,0,.82,.043,.042),(side*.29,0,1.03,.059,.057)],skin)
 ellipsoid('Hand',(side*.29,.013,.775),(.050,.04,.08),skin)
# Merge static surfaces and each rigid leg independently; keep pivot names.
for parent in [None,bpy.data.objects['LegLeft'],bpy.data.objects['LegRight']]:
 objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==parent]
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();objects[0].name='Body' if parent is None else parent.name+'Mesh'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'outputs/urban/witness.blend'),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'witness.glb'),export_format='GLB',export_apply=True)
print('WITNESS_COMPLETE')
