"""Blender 5: original FPS kit + textured city materials; run with Blender -b -P.
Downloaded CC0 inputs and checksums: third_party/polyhaven/manifest.json.
"""
import bpy, math, pathlib, json, random
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/'godot_project/assets/urban'; OUT.mkdir(parents=True,exist_ok=True)
SRC=ROOT/'third_party/polyhaven'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,color,metal=0,rough=.6):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 return m
steel=mat('Parkerized graphite',(.055,.068,.076),.8,.32);rubber=mat('Rubber grips',(.024,.031,.035),0,.82)
edge=mat('Machined edges',(.21,.24,.26),.75,.27);glove=mat('Reinforced leather',(.085,.10,.11),0,.66)
cloth=mat('CC0 Poly Haven woven sleeve',(.11,.17,.18))
# Desaturate and tint the CC0 albedo into an original 512px tactical variant.
from PIL import Image,ImageOps,ImageChops,ImageFilter
img=Image.open(SRC/'fabric_pattern_07_col_1_1k.jpg').convert('L').resize((512,512))
img=ImageOps.colorize(img,(18,26,29),(72,88,90)); img.save(OUT/'materials/sleeve_albedo.png')
for source,dest in [('nor_gl','sleeve_normal'),('arm','sleeve_arm')]:
 Image.open(SRC/f'fabric_pattern_07_{source}_1k.jpg').resize((512,512)).save(OUT/f'materials/{dest}.png')
p=cloth.node_tree.nodes.get('Principled BSDF');n=cloth.node_tree.nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(OUT/'materials/sleeve_albedo.png'));cloth.node_tree.links.new(n.outputs['Color'],p.inputs['Base Color'])
normal=cloth.node_tree.nodes.new('ShaderNodeTexImage');normal.image=bpy.data.images.load(str(OUT/'materials/sleeve_normal.png'));normal.image.colorspace_settings.name='Non-Color'
normal_map=cloth.node_tree.nodes.new('ShaderNodeNormalMap');cloth.node_tree.links.new(normal.outputs['Color'],normal_map.inputs['Color']);cloth.node_tree.links.new(normal_map.outputs['Normal'],p.inputs['Normal'])
arm=cloth.node_tree.nodes.new('ShaderNodeTexImage');arm.image=bpy.data.images.load(str(OUT/'materials/sleeve_arm.png'));arm.image.colorspace_settings.name='Non-Color'
sep=cloth.node_tree.nodes.new('ShaderNodeSeparateColor');cloth.node_tree.links.new(arm.outputs['Color'],sep.inputs[0]);cloth.node_tree.links.new(sep.outputs['Green'],p.inputs['Roughness'])
def box(name,loc,scale,material,bevel=.008):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material)
 if bevel:
  mod=o.modifiers.new('Machined bevel','BEVEL');mod.width=bevel;mod.segments=2;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
def rod(name,a,b,r,material,vertices=12,r2=None):
 a,b=Vector(a),Vector(b);d=b-a
 bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r if r2 is None else r2,depth=d.length,location=(a+b)/2)
 o=bpy.context.object;o.name=name;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(material)
 for p in o.data.polygons:p.use_smooth=True
 return o
def parent_objs(name,objects):
 root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
 for o in objects:o.parent=root
 return root
x=.18
parts=[]
parts.append(box('Receiver',(x,.48,-.17),(.085,.29,.11),steel))
parts.append(box('Handguard',(x,.70,-.16),(.074,.22,.09),steel))
parts.append(rod('Barrel',(x,.79,-.15),(x,.98,-.15),.017,steel))
parts.append(rod('Muzzle brake',(x,.95,-.15),(x,1.01,-.15),.024,edge))
parts.append(box('Stock',(x,.27,-.17),(.065,.20,.11),rubber))
parts.append(box('Grip',(x,.38,-.265),(.053,.06,.12),rubber))
parts.append(box('Trigger guard',(x,.45,-.245),(.018,.08,.015),edge))
for y in [.59,.63,.67,.71,.75,.79]:
 parts.append(box('Rail tooth',(x,y,-.107),(.076,.016,.01),edge,.002))
for side in [-1,1]:
 for y in [.62,.67,.72,.77]:parts.append(box('Cooling vent',(x+side*.038,y,-.145),(.004,.027,.018),rubber,.001))
parts.append(box('Rear sight left',(x-.020,.40,-.057),(.01,.035,.084),steel,.003))
parts.append(box('Rear sight right',(x+.020,.40,-.057),(.01,.035,.084),steel,.003))
parts.append(box('Rear sight mount',(x,.40,-.110),(.065,.05,.027),steel,.003))
parts.append(box('Front sight mount',(x,.79,-.108),(.04,.035,.028),steel,.003))
parts.append(box('Front sight',(x,.79,-.064),(.012,.024,.069),steel,.002))
parts.append(box('Front sight insert',(x,.785,-.026),(.005,.008,.01),mat('Sight phosphor',(.64,.85,.66)),.001))
parts.append(box('Ejection port',(x+.046,.48,-.155),(.005,.084,.03),rubber))
for y in [.41,.56]:parts.append(rod('Receiver pin',(x+.04,y,-.185),(x+.05,y,-.185),.006,edge,8))
# Second-generation furniture pass: narrow controls and furniture silhouette.
# All parts stay under the Weapon empty so the joined mesh keeps one transform.
# Second-generation furniture pass; bevel=0 keeps the audit under 6000 triangles.
parts.append(box('Charging handle spine',(x,.285,-.101),(.014,.075,.028),steel,0))
parts.append(box('Charging handle latch',(x+.024,.252,-.101),(.024,.016,.026),steel,0))
parts.append(box('Trigger',(x,.472,-.228),(.011,.05,.017),steel,0))
parts.append(box('Bolt release paddle',(x-.044,.518,-.158),(.005,.048,.02),edge,0))
parts.append(box('Brass deflector',(x+.048,.428,-.146),(.006,.028,.024),edge,0))
parts.append(rod('Selector drum',(x-.041,.463,-.25),(x-.053,.463,-.25),.013,edge,6))
parts.append(box('Selector lever',(x-.054,.447,-.256),(.006,.032,.011),edge,0))
parts.append(box('Rail spine',(x,.855,-.1015),(.05,.315,.011),edge,0))
for y in [.825,.88,.935,.99]:
 parts.append(box('Rail tooth forward',(x,y,-.093),(.05,.014,.012),edge,0))
parts.append(box('Gas block',(x,.906,-.127),(.042,.052,.028),steel,0))
parts.append(rod('Gas tube',(x,.795,-.112),(x,.90,-.112),.0055,steel,8))
for z in [-.135,-.165]:
 parts.append(box('Muzzle port',(x,.972,z),(.05,.012,.018),rubber,0))
parts.append(rod('Vertical foregrip',(x,.63,-.212),(x,.668,-.268),.0165,rubber,10,.013))
parts.append(box('Foregrip collar',(x,.665,-.207),(.036,.04,.024),edge,0))
for side in [-1,1]:
 for y in [.63,.70,.77]:parts.append(box('Handguard slot',(x+side*.0385,y,-.19),(.0035,.032,.012),rubber,0))
 parts.append(box('Sling slot',(x+side*.036,.225,-.205),(.006,.014,.05),steel,0))
parts.append(box('Cheek riser',(x,.305,-.1075),(.054,.135,.024),rubber,.006))
parts.append(box('Recoil pad',(x,.167,-.17),(.07,.018,.115),rubber,.006))
parent_objs('Weapon',parts)
mag=box('Magazine',(x,.52,-.29),(.054,.089,.17),steel)
for y in [.49,.52,.55]:
 o=box('Magazine channel',(x+.029,y,-.29),(.004,.006,.13),rubber,.001);o.parent=mag;o.matrix_parent_inverse=mag.matrix_world.inverted()
# Curved-look furniture on the magazine travels with the reload animation.
for o in [box('Magazine baseplate',(x,.52,-.378),(.063,.102,.015),rubber,0),
 box('Magazine toe',(x,.575,-.372),(.063,.028,.02),rubber,0),
 box('Magazine feed lips',(x,.52,-.199),(.042,.07,.01),edge,0),
 box('Magazine window left',(x-.0282,.53,-.315),(.0035,.052,.086),rubber,0),
 box('Magazine window right',(x+.0282,.53,-.315),(.0035,.052,.086),rubber,0)]:
 o.parent=mag;o.matrix_parent_inverse=mag.matrix_world.inverted()
for side,palm,start in [('Right',(x,.38,-.25),(.32,.04,-.43)),('Left',(x-.035,.70,-.21),(-.27,.05,-.43))]:
 palm=Vector(palm);start=Vector(start);wrist=start.lerp(palm,.79);objects=[]
 objects.append(rod(side+' sleeve',start,wrist,.078,cloth,16,.048))
 objects.append(rod(side+' cuff',wrist-(palm-start).normalized()*.035,wrist+.015*(palm-start).normalized(),.055,rubber,16))
 objects.append(rod(side+' wrist',wrist,palm,.041,glove,12))
 objects.append(box(side+' glove palm',palm,(.086,.105,.044),glove,.016))
 # Four individual segmented fingers curve around the foregrip/pistol grip.
 for i in range(4):
  base=palm+Vector((-.028+i*.018,.038,.008));mid=base+Vector((0,.027,.019));tip=mid+Vector((0,.012,-.025))
  objects.append(rod(side+' finger proximal',base,mid,.011,glove,8));objects.append(rod(side+' finger distal',mid,tip,.009,glove,8))
  objects.append(box(side+' knuckle',base,(.014,.021,.012),rubber,.004))
 objects.append(rod(side+' thumb',palm+Vector((-.045,0,0)),palm+Vector((-.028,.047,.028)),.014,glove,10))
 parent_objs(side+'Arm',objects)
# Consolidate rigid parts into four animated transform groups, rather than dozens of draw nodes.
for group in ['Weapon','LeftArm','RightArm']:
 root=bpy.data.objects[group];children=list(root.children)
 bpy.ops.object.select_all(action='DESELECT')
 for child in children:child.select_set(True)
 bpy.context.view_layer.objects.active=children[0];bpy.ops.object.join()
 children[0].name=group+'Mesh'
# Pack to one reproducible source .blend; glTF embeds the material image.
for im in bpy.data.images:
 if im.source=='FILE':im.pack()
source=ROOT/'outputs/urban';source.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(source/'fps_kit.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'fps_kit.glb'),export_format='GLB',export_apply=True)
# Original tileable concrete/asphalt maps: deterministic grain, not third-party imagery.
random.seed(904)
for name,base in [('concrete',(114,117,111)),('asphalt',(45,50,53)),('plaster',(154,143,122))]:
 im=Image.new('RGB',(512,512));pix=im.load()
 for yy in range(512):
  for xx in range(512):
   noise=random.gauss(0,7);seam=-24 if name=='concrete' and (xx<2 or yy<2) else 0
   pix[xx,yy]=tuple(max(0,min(255,int(c+noise+seam))) for c in base)
 im.save(OUT/f'materials/{name}.png')
print('URBAN_ASSETS_COMPLETE')
