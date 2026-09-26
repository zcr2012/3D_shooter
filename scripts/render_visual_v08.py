"""Matched studio comparisons and close details, using actual mesh/materials."""
import bpy, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parent.parent; OUT=ROOT/'outputs'/'v08'
sc=bpy.context.scene; rig=bpy.data.objects['SWAT_Rig']
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
prefix='v07' if 'before' in args else 'v08'
for ob in sc.objects: ob.hide_render=ob.name not in {'SWAT_Rig','SWAT_Operator','AR_AssaultRifle','AR_Magazine'}
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.003))
floor=bpy.context.object; floor.name='StudioFloor'
m=bpy.data.materials.new('StudioFloorMat'); m.diffuse_color=(.3,.32,.35,1); floor.data.materials.append(m)
sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.5,.55,.6,1)
sc.world.node_tree.nodes['Background'].inputs[1].default_value=.4
for name,loc,power,size in [('ReviewKey',(3,4,4),750,3),('ReviewFill',(-3,1,2),420,3),('ReviewRim',(-1,-3,3),800,2)]:
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.size=size
    ob=bpy.data.objects.new(name,data); sc.collection.objects.link(ob); ob.location=loc
    ob.rotation_euler=(Vector((0,0,.9))-ob.location).to_track_quat('-Z','Y').to_euler()
camdata=bpy.data.cameras.new('ReviewCamera'); cam=bpy.data.objects.new('ReviewCamera',camdata); sc.collection.objects.link(cam)
sc.camera=cam; cam.data.type='ORTHO'
sc.render.engine='BLENDER_EEVEE'; sc.eevee.taa_render_samples=48
sc.render.resolution_x=840; sc.render.resolution_y=960; sc.render.resolution_percentage=100
sc.view_settings.view_transform='AgX'; sc.view_settings.exposure=.4
shots=[('hero','IdleArmed',0,(2.6,4,2),(.0,.08,.83),2.06),
       ('side','WalkArmed',9,(3.8,1.5,1.7),(0,.08,.83),2.06),
       ('rear','IdleArmed',0,(-2.6,-4,2),(0,0,.83),2.06),
       ('close','AimArmed',0,(-2.4,4,2.1),(-.025,.15,1.28),.95),
       ('reload','ReloadArmed',40,(2.6,4,2),(.0,.08,.83),2.06),
       ('run','RunArmed',6,(3.8,1.5,1.7),(0,.08,.83),2.06)]
if 'quick' in args: shots=shots[:2]
for tag,clip,frame,loc,target,scale in shots:
    rig.animation_data.action=bpy.data.actions[clip]; sc.frame_set(frame)
    cam.location=loc; cam.data.ortho_scale=scale
    cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=str(OUT/(prefix+'_'+tag+'.png')); bpy.ops.render.render(write_still=True)
    print('RENDERED',prefix,tag)
