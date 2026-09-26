"""Export Godot-ready glTF assets.
Run: blender -b file.blend -P export_gltf.py
"""
import bpy, os

OUT = 'C:/Users/zhangshuai/WorkBuddy AI/3D_shooter/godot_project/assets'
os.makedirs(OUT, exist_ok=True)

sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'

# ---------- ensure UVs + packed images survive ----------
for img in bpy.data.images:
    if img.name.endswith(('_BaseColor', '_Roughness')):
        if not img.packed_file:
            img.pack()
        print('image %s packed=%s %dx%d' % (img.name, bool(img.packed_file),
                                            img.size[0], img.size[1]))

def export(name, objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    path = os.path.join(OUT, name + '.glb')
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format='GLB',
        use_selection=True,
        export_yup=True,
        export_apply=False,          # keep armature modifier intact
        export_skins=True,
        export_animations=True,
        export_materials='EXPORT',
        export_image_format='AUTO',
        export_texture_dir='',
        export_normals=True,
        export_tangents=False,
        export_extras=False,
        export_cameras=False,
        export_lights=False,
    )
    size = os.path.getsize(path)
    print('EXPORTED %s -> %.1f KB' % (path, size / 1024.0))

# ---------- 1. character + rig + rifle ----------
chars = []
for n in ('SWAT_Rig', 'SWAT_Operator', 'AR_AssaultRifle'):
    o = bpy.data.objects.get(n)
    if o:
        chars.append(o)
    else:
        print('WARN missing', n)
export('swat_operator', chars)

# ---------- 2. the room ----------
scene_col = bpy.data.collections.get('SceneRoom')
if scene_col:
    room = [o for o in scene_col.objects if o.type == 'MESH']
    print('room meshes:', len(room))
    export('tactical_room', room)

print('DONE')
