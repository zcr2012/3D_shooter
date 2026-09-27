"""Witness Chen Mo v2: original skinned civilian built procedurally in Blender (4.2+).

Continuous skin-modifier body, 15-bone rig with automatic weights, separate rigid head
accessories, hi-vis vest, and four authored actions (Captive, Idle, Jog, Plead).
This is a stylised low-poly game character, not a scanned or sculpted production model.
Run:  blender -b --python-exit-code 1 -P scripts/build_urban_witness.py
"""
import bpy, bmesh, math, pathlib, sys
from mathutils import Vector, Matrix, Quaternion

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / 'godot_project/assets/urban'
FPS = 24

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS


def mat(name, color, rough=.85, metal=0.0, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = metal
    if emit:
        bsdf.inputs['Emission Color'].default_value = (*emit, 1)
        bsdf.inputs['Emission Strength'].default_value = .35
    m.diffuse_color = (*color, 1)
    return m


# Names containing "uniform"/"denim" receive the in-engine fabric normal overlay.
M = {
    'shirt': mat('Dock uniform', (.085, .12, .16)),
    'pants': mat('Denim', (.12, .13, .12)),
    'skin': mat('Skin', (.56, .37, .27), .6),
    'hair': mat('Hair', (.035, .028, .024), .7),
    'white': mat('Eye white', (.78, .76, .72), .35),
    'iris': mat('Iris', (.05, .032, .02), .25),
    'lips': mat('Lips', (.36, .19, .15), .55),
    'boot': mat('Boot leather', (.07, .055, .045), .6),
    'vest': mat('Hi-vis vest', (.95, .42, .05), .7, emit=(.35, .13, .0)),
    'strip': mat('Reflective strip', (.72, .74, .72), .3, .3),
    'hat': mat('Hard hat', (.86, .64, .09), .45),
    'badge': mat('ID card', (.82, .84, .80), .4),
    'rope': mat('Cable tie', (.10, .10, .11), .5),
}


def link(obj):
    bpy.context.collection.objects.link(obj)
    return obj


def ellipsoid(name, loc, scale, material, seg=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    # Apply location too: later bmesh edits use world-space heights.
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    o.data.materials.append(material)
    for f in o.data.polygons:
        f.use_smooth = True
    return o


def box(name, loc, size, material, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    if bevel:
        mod = o.modifiers.new('Bevel', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    o.data.materials.append(material)
    return o


# ---------------------------------------------------------------- body (skin modifier)
# Character faces +Y in Blender (glTF -Z, the Godot look_at forward used by operation.gd).
J = {
    'pelvis': (0, 0, .93), 'spine': (0, -.005, 1.10), 'chest': (0, -.01, 1.28), 'neck0': (0, -.01, 1.43), 'neck1': (0, 0, 1.50),
}
for s, x in (('L', 1), ('R', -1)):
    J['shoulder' + s] = (x * .185, -.015, 1.385)
    J['elbow' + s] = (x * .265, -.03, 1.13)
    J['wrist' + s] = (x * .29, .0, .875)
    J['hip' + s] = (x * .095, 0, .9)
    J['knee' + s] = (x * .1, .015, .50)
    J['ankle' + s] = (x * .1, -.01, .105)
RADIUS = {
    'pelvis': (.155, .105), 'spine': (.14, .095), 'chest': (.165, .105), 'neck0': (.058, .058), 'neck1': (.052, .052),
    'shoulder': (.062, .062), 'elbow': (.047, .047), 'wrist': (.036, .032), 'hip': (.088, .09), 'knee': (.062, .064), 'ankle': (.045, .048),
}
EDGES = [('pelvis', 'spine'), ('spine', 'chest'), ('chest', 'neck0'), ('neck0', 'neck1')]
for s in 'LR':
    EDGES += [('chest', 'shoulder' + s), ('shoulder' + s, 'elbow' + s), ('elbow' + s, 'wrist' + s),
              ('pelvis', 'hip' + s), ('hip' + s, 'knee' + s), ('knee' + s, 'ankle' + s)]
names = list(J)
me = bpy.data.meshes.new('WitnessBody')
me.from_pydata([J[n] for n in names], [(names.index(a), names.index(b)) for a, b in EDGES], [])
body = link(bpy.data.objects.new('WitnessBody', me))
bpy.context.view_layer.objects.active = body
body.select_set(True)
skin = body.modifiers.new('Skin', 'SKIN')
skin.use_smooth_shade = True
skin.branch_smoothing = .4
for i, n in enumerate(names):
    key = n.rstrip('LR') if n[-1] in 'LR' and n not in ('pelvis',) else n
    me.skin_vertices[0].data[i].radius = RADIUS[key]
me.skin_vertices[0].data[names.index('pelvis')].use_root = True
sub = body.modifiers.new('Subsurf', 'SUBSURF')
sub.levels = 1
bpy.ops.object.modifier_apply(modifier='Skin')
bpy.ops.object.modifier_apply(modifier='Subsurf')
for m in ('shirt', 'pants', 'skin'):
    body.data.materials.append(M[m])
for f in body.data.polygons:
    c = f.center
    arm = abs(c.x) > .2 or (abs(c.x) > .15 and c.z > 1.2)
    if c.z > 1.445 and abs(c.x) < .08:
        f.material_index = 2              # neck
    elif arm:
        f.material_index = 0 if c.z > 1.0 else 2   # rolled sleeve, bare forearm
    elif c.z > .875:
        f.material_index = 0
    else:
        f.material_index = 1
    f.use_smooth = True

# ---------------------------------------------------------------- head and face
head = ellipsoid('Head', (0, .01, 1.615), (.098, .112, .128), M['skin'], 24, 16)
bm = bmesh.new()
bm.from_mesh(head.data)
for v in bm.verts:
    z = v.co.z - 1.615
    if z < -.03:                     # narrower jaw and chin
        t = min(1, (-.03 - z) / .1)
        v.co.x *= 1 - .28 * t
        v.co.y = .01 + (v.co.y - .01) * (1 - .12 * t) + .012 * t
    if v.co.y > .08 and -.02 < z < .05:  # flatten the face plane a little
        v.co.y -= .01
    if v.co.y > .07 and .045 < z < .065:  # brow ridge
        v.co.y += .008
bm.to_mesh(head.data)
bm.free()
parts = [head]
parts.append(ellipsoid('Nose', (0, .112, 1.603), (.013, .02, .027), M['skin'], 10, 6))
parts.append(ellipsoid('NoseTip', (0, .119, 1.586), (.015, .012, .011), M['skin'], 10, 6))
for x in (-.037, .037):
    parts.append(ellipsoid('EyeWhite', (x, .100, 1.628), (.019, .01, .011), M['white'], 12, 8))
    parts.append(ellipsoid('Iris', (x, .108, 1.628), (.0085, .004, .0085), M['iris'], 10, 6))
    parts.append(box('Brow', (x * 1.05, .106, 1.652), (.038, .01, .008), M['hair'], .003))
    parts.append(ellipsoid('Ear', (math.copysign(.097, x), .0, 1.61), (.014, .024, .034), M['skin'], 10, 6))
parts.append(ellipsoid('Lips', (0, .108, 1.55), (.024, .006, .005), M['lips'], 12, 6))
parts.append(ellipsoid('Hair', (0, -.012, 1.655), (.104, .112, .092), M['hair'], 20, 12))
for x in (-.09, .09):
    parts.append(ellipsoid('Sideburn', (x, .03, 1.60), (.012, .022, .03), M['hair'], 8, 6))
# Hard hat: dome, brim and ridge.
hat = ellipsoid('HatDome', (0, .005, 1.705), (.118, .128, .085), M['hat'], 20, 10)
bm = bmesh.new()
bm.from_mesh(hat.data)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < 1.69], context='VERTS')
bm.to_mesh(hat.data)
bm.free()
parts.append(hat)
bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=1, depth=.012, location=(0, .02, 1.692))
brim = bpy.context.object
brim.scale = (.138, .155, 1)
bpy.ops.object.transform_apply(location=True, scale=True)
brim.data.materials.append(M['hat'])
parts.append(brim)
parts.append(box('HatRidge', (0, .005, 1.787), (.022, .2, .014), M['hat'], .005))

# Hands (mitten with thumb) and boots.
for s, x in (('L', 1), ('R', -1)):
    parts.append(ellipsoid('Hand' + s, (x * .295, .012, .815), (.034, .045, .065), M['skin'], 12, 8))
    parts.append(ellipsoid('Thumb' + s, (x * .283, .045, .84), (.014, .016, .03), M['skin'], 8, 6))
    boot = box('Boot' + s, (x * .1, .03, .055), (.105, .25, .11), M['boot'], .03)
    parts.append(boot)
    parts.append(box('Sole' + s, (x * .1, .03, .008), (.11, .26, .016), M['rope']))

# Hi-vis vest: an offset shell of the torso with two reflective bands.
vest = body.copy()
vest.data = body.data.copy()
vest.name = 'Vest'
link(vest)
bm = bmesh.new()
bm.from_mesh(vest.data)
keep = [f for f in bm.faces if .95 < f.calc_center_median().z < 1.40 and abs(f.calc_center_median().x) < .165]
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in keep], context='FACES')
for v in bm.verts:
    v.co += v.normal * .012
bm.to_mesh(vest.data)
bm.free()
vest.data.materials.clear()
vest.data.materials.append(M['vest'])
vest.data.materials.append(M['strip'])
for f in vest.data.polygons:
    z = f.center.z
    f.material_index = 1 if (1.04 < z < 1.075) or (1.16 < z < 1.195) else 0
solid = vest.modifiers.new('Solid', 'SOLIDIFY')
solid.thickness = .006
bpy.context.view_layer.objects.active = vest
bpy.ops.object.modifier_apply(modifier='Solid')
parts.append(box('Badge', (-.075, .117, 1.30), (.05, .006, .07), M['badge'], .004))

# ---------------------------------------------------------------- armature
arm_data = bpy.data.armatures.new('WitnessRig')
rig = link(bpy.data.objects.new('WitnessRig', arm_data))
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
BONES = {}


def bone(name, head_pos, tail_pos, parent=None):
    b = arm_data.edit_bones.new(name)
    b.head = head_pos
    b.tail = tail_pos
    b.roll = 0
    if parent:
        b.parent = arm_data.edit_bones[parent]
        b.use_connect = False
    BONES[name] = (Vector(head_pos), Vector(tail_pos))


bone('Hips', (0, 0, .93), (0, 0, 1.06))
bone('Spine', (0, 0, 1.06), (0, -.005, 1.24), 'Hips')
bone('Chest', (0, -.005, 1.24), (0, -.01, 1.43), 'Spine')
bone('Neck', (0, -.01, 1.43), (0, 0, 1.53), 'Chest')
bone('Head', (0, 0, 1.53), (0, .01, 1.78), 'Neck')
for s, x in (('L', 1), ('R', -1)):
    bone('UpperArm.' + s, (x * .17, -.015, 1.39), (x * .265, -.03, 1.13), 'Chest')
    bone('LowerArm.' + s, (x * .265, -.03, 1.13), (x * .29, 0, .875), 'UpperArm.' + s)
    bone('Hand.' + s, (x * .29, 0, .875), (x * .295, .015, .76), 'LowerArm.' + s)
    bone('UpperLeg.' + s, (x * .095, 0, .9), (x * .1, .015, .5), 'Hips')
    bone('LowerLeg.' + s, (x * .1, .015, .5), (x * .1, -.01, .105), 'UpperLeg.' + s)
    bone('Foot.' + s, (x * .1, -.01, .105), (x * .1, .16, .03), 'LowerLeg.' + s)
bpy.ops.object.mode_set(mode='OBJECT')


def weight_rigid(obj, bone_name):
    group = obj.vertex_groups.new(name=bone_name)
    group.add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')


# Body: heat weights (automatic).
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
if len(body.vertex_groups) < 10:
    raise SystemExit('automatic weights failed')
# Vest: copy weights from the body surface it was offset from.
vest.parent = rig
dt = vest.modifiers.new('Weights', 'DATA_TRANSFER')
dt.object = body
dt.use_vert_data = True
dt.data_types_verts = {'VGROUP_WEIGHTS'}
dt.vert_mapping = 'POLYINTERP_NEAREST'
bpy.context.view_layer.objects.active = vest
bpy.ops.object.datalayout_transfer(modifier=dt.name)
bpy.ops.object.modifier_apply(modifier=dt.name)
# Rigid parts follow a single bone.
rigid = {'Hand': None, 'Thumb': None, 'Boot': None, 'Sole': None}
for p in parts:
    if p is vest:
        continue
    n = p.name
    if n.startswith(('Hand', 'Thumb')):
        target = 'Hand.' + n[-1] if n[-1] in 'LR' else 'Head'
    elif n.startswith(('Boot', 'Sole')):
        target = 'Foot.' + n[-1]
    elif n.startswith('Badge'):
        target = 'Chest'
    else:
        target = 'Head'
    weight_rigid(p, target)
# Join into one skinned mesh (single draw-call material set per material).
bpy.ops.object.select_all(action='DESELECT')
for p in parts + [vest]:
    p.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body.name = 'ChenMo'
for m in list(body.modifiers):
    if m.type == 'ARMATURE':
        body.modifiers.remove(m)
mod = body.modifiers.new('Armature', 'ARMATURE')
mod.object = rig
body.parent = rig
# Normalize and limit to 4 influences for glTF.
bpy.context.view_layer.objects.active = body
bpy.ops.object.mode_set(mode='WEIGHT_PAINT')
bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)
bpy.ops.object.mode_set(mode='OBJECT')

# ---------------------------------------------------------------- animation helpers
pose = rig.pose
for pb in pose.bones:
    pb.rotation_mode = 'QUATERNION'


def world_rot(axis, degrees):
    return Quaternion(Vector(axis), math.radians(degrees))


def local_quat(bone_name, *rotations):
    """Rotations given in armature (world) axes, converted into the bone's rest frame."""
    rest = arm_data.bones[bone_name].matrix_local.to_3x3()
    q = Quaternion()
    for axis, deg in rotations:
        q = world_rot(axis, deg) @ q
    return (rest.inverted() @ q.to_matrix() @ rest).to_quaternion()


X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)


def key(frame, spec, hips_offset=(0, 0, 0)):
    for pb in pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    for name, rots in spec.items():
        pose.bones[name].rotation_quaternion = local_quat(name, *rots)
    rest = arm_data.bones['Hips'].matrix_local.to_3x3()
    pose.bones['Hips'].location = rest.inverted() @ Vector(hips_offset)
    for pb in pose.bones:
        pb.keyframe_insert('rotation_quaternion', frame=frame)
        pb.keyframe_insert('location', frame=frame)


def action(name, frames, builder):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    for f in frames:
        builder(f)
    act.frame_range = (frames[0], frames[-1])
    for fc in getattr(act, 'fcurves', []):
        for kp in fc.keyframe_points:
            kp.interpolation = 'BEZIER'
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, frames[0], act)
    track.mute = True
    rig.animation_data.action = None
    return act


def arms_down(spread=4):
    return {'UpperArm.L': [(Y, -spread)], 'UpperArm.R': [(Y, spread)]}


# Captive: kneeling, wrists tied behind the back, head lowered, uneven breathing.
def captive(f):
    t = f / 48 * math.tau
    b = math.sin(t)
    spec = {
        'UpperLeg.L': [(X, 8)], 'UpperLeg.R': [(X, 6)],
        'LowerLeg.L': [(X, -96)], 'LowerLeg.R': [(X, -94)],
        'Foot.L': [(X, -38)], 'Foot.R': [(X, -40)],
        'Spine': [(X, -6 - 1.5 * b)], 'Chest': [(X, -4 - 1.5 * b)],
        'Neck': [(X, -14)], 'Head': [(X, -12 + 2 * b), (Z, 8 * math.sin(t * .5))],
        'UpperArm.L': [(X, -22), (Y, 4)], 'UpperArm.R': [(X, -22), (Y, -4)],
        'LowerArm.L': [(Y, 78), (X, -18)], 'LowerArm.R': [(Y, -78), (X, -18)],
        'Hand.L': [(Z, 20)], 'Hand.R': [(Z, -20)],
    }
    key(f, spec, (0, -.02, -.387 + .004 * b))


# Idle: relaxed stance, breathing, nervous glances.
def idle(f):
    t = f / 72 * math.tau
    spec = arms_down(5)
    spec.update({
        'Spine': [(X, 1.2 * math.sin(t))], 'Chest': [(X, -1.2 * math.sin(t))],
        'Head': [(Z, 14 * math.sin(t * .5)), (X, -3)],
        'LowerArm.L': [(X, 8 + 2 * math.sin(t))], 'LowerArm.R': [(X, 8 + 2 * math.sin(t + .6))],
        'UpperLeg.L': [(X, 2)], 'UpperLeg.R': [(X, -2)],
    })
    key(f, spec, (0, 0, .004 * math.sin(t * 2)))


# Jog: hunched, quick civilian run matched to 3.1 m/s escort speed (stride ~1.55 m, 12 frames/step).
def jog(f):
    t = f / 24 * math.tau
    s = math.sin(t)
    spec = {
        'UpperLeg.L': [(X, 34 * s)], 'UpperLeg.R': [(X, -34 * s)],
        'LowerLeg.L': [(X, -18 - 42 * max(0, -math.sin(t + .9)))],
        'LowerLeg.R': [(X, -18 - 42 * max(0, math.sin(t + .9)))],
        'Foot.L': [(X, 10 * s)], 'Foot.R': [(X, -10 * s)],
        'Spine': [(X, -10)], 'Chest': [(X, -4), (Z, 6 * s)], 'Head': [(X, 8), (Z, -5 * s)],
        'UpperArm.L': [(X, -30 * s), (Y, -8)], 'UpperArm.R': [(X, 30 * s), (Y, 8)],
        'LowerArm.L': [(X, 70)], 'LowerArm.R': [(X, 70)],
    }
    key(f, spec, (0, .02, -.03 + .035 * abs(math.cos(t))))


# Plead: standing explanation for the rescue scene, open palms and small nods.
def plead(f):
    t = f / 72 * math.tau
    s = math.sin(t)
    spec = {
        'UpperArm.L': [(X, 28 + 6 * s), (Y, -10)], 'UpperArm.R': [(X, 22 - 6 * s), (Y, 10)],
        'LowerArm.L': [(X, 55 + 10 * s), (Z, -20)], 'LowerArm.R': [(X, 60 - 10 * s), (Z, 20)],
        'Hand.L': [(Y, 20)], 'Hand.R': [(Y, -20)],
        'Head': [(X, -4 + 4 * math.sin(t * 2)), (Z, 6 * s)], 'Chest': [(X, 2 * s)],
    }
    key(f, spec)


action('Captive', list(range(0, 49, 6)), captive)
action('Idle', list(range(0, 73, 6)), idle)
action('Jog', list(range(0, 25, 2)), jog)
action('Plead', list(range(0, 73, 6)), plead)
for pb in pose.bones:
    pb.rotation_quaternion = Quaternion()
    pb.location = Vector()

tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
print('WITNESS_TRIANGLES', tris, 'BONES', len(arm_data.bones), 'ACTIONS', [a.name for a in bpy.data.actions])
if tris >= 7000:
    raise SystemExit('triangle budget exceeded: %d' % tris)

(ROOT / 'outputs/urban').mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'outputs/urban/witness.blend'), compress=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT / 'witness.glb'), export_format='GLB', export_apply=True,
                          export_animations=True, export_animation_mode='ACTIONS', export_skins=True,
                          export_yup=True, export_image_format='NONE')
print('WITNESS_COMPLETE')
