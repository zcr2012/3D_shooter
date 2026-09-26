"""Neutral studio review: do not save temporary lights into the deliverable."""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'outputs'
sc=bpy.context.scene; rig=bpy.data.objects['SWAT_Rig']
for ob in sc.objects:
    ob.hide_render=ob.name not in {'SWAT_Rig','SWAT_Operator','AR_AssaultRifle','AR_Magazine'}
# Minimal light studio makes deformation visible, not hidden by scene props.
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.002))
floor=bpy.context.object; floor.name='ReviewFloor'
m=bpy.data.materials.new('ReviewFloor_Mat'); m.diffuse_color=(.22,.24,.27,1)
floor.data.materials.append(m)
sc.world.use_nodes=True
sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.4,.43,.48,1)
sc.world.node_tree.nodes['Background'].inputs[1].default_value=.4
for name,loc,power,size in [('StudioKey',(3,3,4),550,4),('StudioFill',(-3,2,2),300,3),('StudioRim',(0,-2,3),600,2)]:
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size
    ob=bpy.data.objects.new(name,data); sc.collection.objects.link(ob); ob.location=loc
    ob.rotation_euler=(Vector((0,0,.9))-ob.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('ReviewCamera'); cam=bpy.data.objects.new('ReviewCamera',data); sc.collection.objects.link(cam)
sc.camera=cam; cam.data.type='ORTHO'; cam.data.ortho_scale=2.06
sc.render.engine='BLENDER_EEVEE'; sc.eevee.taa_render_samples=32
sc.render.resolution_x=640; sc.render.resolution_y=720; sc.render.resolution_percentage=100
sc.view_settings.view_transform='AgX'; sc.view_settings.exposure=0
shots=[('idle','IdleArmed',0,(2.6,4,2)),('walk','WalkArmed',9,(3.8,1.5,1.7)),
       ('run','RunArmed',6,(3.8,1.5,1.7)),('aim','AimArmed',30,(-2.4,4,1.9)),
       ('fire','FireArmed',1,(-2.4,4,1.9)),('reload','ReloadArmed',40,(2.6,4,2)),
       ('hit','HitReact',3,(2.6,4,2))]
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
if args == ['reel']:
    (OUT/'motion_frames').mkdir(exist_ok=True)
    sc.render.resolution_x=360; sc.render.resolution_y=420
    sc.eevee.taa_render_samples=16
    shots=[('frames/walk_%02d'%i,'WalkArmed',i,(3.8,1.5,1.7)) for i in range(36)]
    shots += [('frames/reload_%02d'%i,'ReloadArmed',i*2,(2.6,4,2)) for i in range(43)]
elif args:
    shots=[s for s in shots if s[0] in args]
for tag,clip,f,loc in shots:
    rig.animation_data.action=bpy.data.actions[clip]; sc.frame_set(f)
    cam.location=loc; cam.rotation_euler=(Vector((0,.06,.83))-cam.location).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=str(OUT/('motion_'+tag+'.png'))
    bpy.ops.render.render(write_still=True)
    print('REVIEW_RENDER',tag)
