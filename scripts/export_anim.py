"""Export the animated character to glTF for Godot.
Exports every authored clip plus the separately animated magazine.
"""
import bpy, os
from pathlib import Path

OUT = os.environ.get('SWAT_EXPORT_DIR', str(Path(__file__).resolve().parent.parent / 'godot_project' / 'assets'))
os.makedirs(OUT, exist_ok=True)

sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'
sc.frame_set(0)

# the rig may still be in POSE mode from the animation script
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')

# make sure every image is packed before export
for img in bpy.data.images:
    if img.name.endswith(('_BaseColor', '_Roughness', '_BC', '_RG')):
        if not img.packed_file:
            img.pack()

arm = bpy.data.objects['SWAT_Rig']
act = bpy.data.actions.get('IdleArmed') or bpy.data.actions.get('WalkArmed')
if act:
    arm.animation_data.action = act
    sc.frame_set(0)
print('action:', act.name if act else 'NONE')
if act:
    print('  frame_range:', tuple(act.frame_range))

objs = []
for n in ('SWAT_Rig', 'SWAT_Operator', 'AR_AssaultRifle', 'AR_Magazine'):
    o = bpy.data.objects.get(n)
    if o:
        objs.append(o)
    else:
        print('WARN missing', n)

bpy.ops.object.select_all(action='DESELECT')
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]

path = os.path.join(OUT, 'swat_operator.glb')
bpy.ops.export_scene.gltf(
    filepath=path,
    export_format='GLB',
    use_selection=True,
    export_yup=True,
    export_apply=False,
    export_skins=True,
    export_animations=True,
    export_animation_mode='ACTIONS',      # one clip per Blender action
    export_bake_animation=False,
    export_frame_range=False,
    export_force_sampling=True,
    export_anim_slide_to_zero=True,
    export_anim_single_armature=True,
    export_optimize_animation_size=False, # keep the keys we authored
    export_materials='EXPORT',
    export_image_format='AUTO',
    export_normals=True,
    export_cameras=False,
    export_lights=False,
)
print('EXPORTED %s -> %.1f KB' % (path, os.path.getsize(path) / 1024.0))
print('DONE')
