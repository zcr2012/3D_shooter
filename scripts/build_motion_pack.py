"""Seven baked clips, analytic ground contact and weapon-relative hand placement."""
import bpy, bmesh, math, sys, json
from pathlib import Path
from mathutils import Vector, Matrix, Euler
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'scripts'))
from motion_math import *
sc = bpy.context.scene
sc.render.fps = 30
arm = bpy.data.objects['SWAT_Rig']
ob = bpy.data.objects['SWAT_Operator']
rifle = bpy.data.objects['AR_AssaultRifle']
if bpy.context.object and bpy.context.object.mode != 'OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
bpy.context.view_layer.objects.active = arm
arm.animation_data_clear()
# Keep original file untouched; the candidate is reproducible from prepare_motion_rig.py.
for a in list(bpy.data.actions): bpy.data.actions.remove(a)
for b in arm.pose.bones:
    b.matrix_basis = Matrix.Identity(4)
# Detach render weapon before changing rig; vertex coordinates already are metres.
rifle.parent = None
rifle.matrix_world = Matrix.Identity(4)
# Separate magazine's four disconnected shells, preserving atlas coordinates.
mag_ids = set()
for v in rifle.data.vertices:
    x,y,z = v.co
    if -0.065 < y < 0.11 and z < -0.13:
        pass
# Select components by centroid rather than broad vertex cutting.
adj = [[] for _ in rifle.data.vertices]
for e in rifle.data.edges:
    a,b=e.vertices; adj[a].append(b); adj[b].append(a)
unseen=set(range(len(adj)))
while unseen:
    stack=[unseen.pop()]; ids=[]
    while stack:
        i=stack.pop(); ids.append(i)
        for j in adj[i]:
            if j in unseen: unseen.remove(j); stack.append(j)
    c=sum((rifle.data.vertices[i].co for i in ids),Vector())/len(ids)
    if c.z < -0.095 and c.y > -0.015 and abs(c.x)<0.005 and max(rifle.data.vertices[i].co.y for i in ids)>0.05:
        mag_ids.update(ids)
assert len(mag_ids)==32, ('magazine selection',len(mag_ids))
magmesh=rifle.data.copy(); magmesh.name='AR_MagazineMesh'
mag=bpy.data.objects.new('AR_Magazine',magmesh); sc.collection.objects.link(mag)
for mesh, keep in [(rifle.data,False),(magmesh,True)]:
    bm=bmesh.new(); bm.from_mesh(mesh); bm.verts.ensure_lookup_table()
    remove=[v for v in bm.verts if (v.index in mag_ids) != keep]
    bmesh.ops.delete(bm,geom=remove,context='VERTS')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(mesh); bm.free(); mesh.update()
# Dedicated weapon bones simplify multi-action glTF and prevent support-hand drift.
bpy.ops.object.mode_set(mode='EDIT')
for name, parent in [('weapon_root','chest'),('weapon_mag','weapon_root')]:
    b=arm.data.edit_bones.new(name); b.head=(0,0,0); b.tail=(0,0.1,0)
    b.parent=arm.data.edit_bones[parent]; b.use_connect=False
bpy.ops.object.mode_set(mode='OBJECT')
pb=arm.pose.bones
for b in pb:
    b.rotation_mode='QUATERNION'; b.matrix_basis=Matrix.Identity(4)
for obj,bone in [(rifle,'weapon_root'),(mag,'weapon_mag')]:
    obj.parent=arm; obj.parent_type='BONE'; obj.parent_bone=bone
    obj.matrix_parent_inverse=Matrix.Identity(4)
    obj.matrix_basis=Matrix.Translation((0,-0.1,0))
# All actions key every bone, avoiding residue from a preceding clip.
SPECS=[('IdleArmed',90,True,0),('WalkArmed',36,True,1.0),('RunArmed',24,True,2.6),
       ('AimArmed',90,True,0),('FireArmed',8,False,0),('ReloadArmed',84,False,0),('HitReact',20,False,0)]
report={'fps':30,'clips':{},'note':'Flat-ground analytic contacts. No slope IK, finger rig, or AAA animation claim.'}
max_reach=0.0

def set_hand(side, contact, pole):
    global max_reach
    name='hand.'+side
    direction=Vector((0,0.038,-0.044))
    direction.normalize(); direction*=pb[name].bone.length
    wrist=contact-direction
    error=two_bone(pb,'upperarm.'+side,'forearm.'+side,wrist,pole)
    max_reach=max(max_reach,error)
    set_segment(pb,name,pb['forearm.'+side].tail.copy(),pb['forearm.'+side].tail+direction)

for name,last,loop,speed in SPECS:
    action=bpy.data.actions.new(name); action.use_fake_user=True
    action.use_frame_range=True; action.frame_start=0; action.frame_end=last
    action['loop']=loop; action['authored_speed_mps']=speed
    arm.animation_data_create(); arm.animation_data.action=action
    endpoints=[]; contacts=[]; errors=[]; previous_quats={}; max_reach=0.0
    for f in range(last+1):
        sc.frame_set(f); t=f/last
        phase=(f % last)/last if loop else t
        for b in pb: b.matrix_basis=Matrix.Identity(4)
        moving=name in {'WalkArmed','RunArmed'}
        running=name=='RunArmed'
        breathe=math.sin(TAU*phase)
        bob=(0.009 if running else 0.006)*math.cos(2*TAU*phase) if moving else 0.0015*breathe
        hip_z=(-0.145 if running else -0.135) + bob if moving else -0.055+bob
        hip_x=0.013*math.sin(TAU*phase) if moving else 0.002*breathe
        pb['hip'].location=(hip_x,hip_z,0)
        fk(pb,'hip',(0,2*math.sin(TAU*phase) if moving else 0,0))
        hit=curve(t,[(0,0),(.15,1),(.45,.35),(1,0)]) if name=='HitReact' else 0
        fk(pb,'spine',(-7+8*hit,0,0)); fk(pb,'chest',(-5+5*hit,0,-3*hit))
        fk(pb,'neck',(5,0,0)); fk(pb,'head',(7,-3*hit,0))
        bpy.context.view_layer.update()
        frame_contacts={}
        for side,offset in [('L',0.5),('R',0.0)]:
            sx=1 if side=='L' else -1
            if moving:
                y,z,roll,planted=foot_path(phase+offset,last/30,speed,0.38 if running else 0.62,0.16 if running else 0.10)
            else:
                y,z,roll,planted=(0.055*sx,0.097,0,True)
            # Rolling the boot about its ankle must not push its heel/toe
            # below the ground. Compensate the real sole envelope in swing.
            if not planted:
                angle=D(roll)
                z += 0.137*abs(math.sin(angle))+0.097*(math.cos(angle)-1.0)
            target=Vector((sx*0.13,y,z))
            errors.append(two_bone(pb,'thigh.'+side,'shin.'+side,target,(0,1,0)))
            foot=pb['foot.'+side]
            m=Matrix.Rotation(D(roll),4,'X') @ foot.bone.matrix_local.copy()
            m.translation=pb['shin.'+side].tail.copy()
            foot.matrix=m
            bpy.context.view_layer.update()
            frame_contacts[side]={'planted':planted,'ankle':list(foot.head),'phase':(phase+offset)%1.0}
        # Rifle near shoulder, arms solved to grip points rather than free FK.
        weapon_pos=Vector((-0.080,0.245,1.265+bob*0.40))
        weapon_rot=[-7,0,-2]
        if name in {'AimArmed','FireArmed'}:
            weapon_pos.z+=0.026; weapon_rot[0]=-2
        if running:
            weapon_pos.z-=0.065; weapon_rot[0]=-14
        pulse=curve(t,[(0,0),(.125,1),(.4,.32),(1,0)]) if name=='FireArmed' else 0
        weapon_pos.y-=0.018*pulse; weapon_rot[0]+=3*pulse
        weapon_pos.y-=0.035*hit; weapon_rot[0]+=10*hit
        reload_amount=curve(t,[(0,0),(.17,1),(.80,1),(1,0)]) if name=='ReloadArmed' else 0
        weapon_rot[1]=-12*reload_amount
        weapon_pos.z-=0.075*reload_amount
        weapon=trs(weapon_pos,weapon_rot)
        pb['weapon_root'].matrix=weapon
        bpy.context.view_layer.update()
        mag_delta=Vector((0,0,0))
        if name=='ReloadArmed':
            down=curve(t,[(0,0),(.25,0),(.38,.19),(.54,.19),(.72,0),(1,0)])
            side_shift=curve(t,[(0,0),(.38,0),(.47,.14),(.56,.14),(.66,0),(1,0)])
            mag_delta=Vector((side_shift,-side_shift*.45,-down))
        pb['weapon_mag'].matrix=weapon @ Matrix.Translation(mag_delta)
        bpy.context.view_layer.update()
        right=weapon @ Vector((0,-0.055,-0.098))
        support=weapon @ Vector((0,0.19,-0.035))
        if name=='ReloadArmed':
            hand_mag=weapon @ (Vector((0.015,0.020,-0.22))+mag_delta)
            mix=curve(t,[(0,0),(.18,1),(.73,1),(.9,0),(1,0)])
            support=support.lerp(hand_mag,mix)
        set_hand('R',right,(-1,0,-1)); set_hand('L',support,(1,0,-1))
        bpy.context.view_layer.update()
        contacts.append(frame_contacts)
        for b in pb:
            q=b.rotation_quaternion.copy()
            if b.name in previous_quats and q.dot(previous_quats[b.name])<0:
                q.negate(); b.rotation_quaternion=q
            previous_quats[b.name]=q.copy()
            b.keyframe_insert('location',frame=f,group=b.name)
            b.keyframe_insert('rotation_quaternion',frame=f,group=b.name)
            b.keyframe_insert('scale',frame=f,group=b.name)
        if f in {0,last}: endpoints.append([b.matrix.copy() for b in pb])
    for fc in fcurves(action):
        # Continuous quaternion hemispheres prevent long interpolation arcs.
        for kp in fc.keyframe_points: kp.interpolation='LINEAR'
    seam=max((a.translation-b.translation).length for a,b in zip(*endpoints))
    contact_residual=[]; contact_heights=[]
    for side in ['L','R']:
        for i in range(last):
            a,b=contacts[i][side],contacts[i+1][side]
            if a['planted'] and b['planted'] and b['phase']>=a['phase']:
                delta=Vector(b['ankle'])-Vector(a['ankle'])+Vector((0,speed/30,0))
                contact_residual.append(delta.length)
                contact_heights.append(abs(a['ankle'][2]-0.097))
    report['clips'][name]={'frames':last,'duration':last/30,'loop':loop,'authored_speed_mps':speed,
        'seam_position_m':seam,'max_leg_reach_clamp_m':max(errors),
        'max_contact_step_residual_m':max(contact_residual,default=0),
        'max_contact_height_error_m':max(contact_heights,default=0),'max_hand_reach_clamp_m':max_reach}
    print('CLIP',name,json.dumps(report['clips'][name]))
report['max_hand_target_clamp_m']=max(c['max_hand_reach_clamp_m'] for c in report['clips'].values())
# Give export/playback a clean initial pose and explicit metre units.
arm.animation_data.action=bpy.data.actions['IdleArmed']; sc.frame_start=0; sc.frame_end=90; sc.frame_set(0)
sc.unit_settings.system='METRIC'; sc.unit_settings.scale_length=1.0
(ROOT/'outputs'/'motion_authoring.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.ops.wm.save_mainfile()
print('MOTION_PACK_SAVED hand_clamp=',max_reach)
