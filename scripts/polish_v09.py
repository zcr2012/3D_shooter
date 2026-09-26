"""Incremental mesh polish, from the checked-in v08 source (no v07 dependency).

blender -b outputs/v08/swat_visual_v08.blend -P scripts/polish_v09.py
Never edits v08. Output: outputs/v09/swat_visual_v09.blend + main-project GLB.
"""
import bpy
import bmesh
import json
import runpy
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'scripts'))
from v08_geometry import Builder

OUT = ROOT / 'outputs' / 'v09'
OUT.mkdir(parents=True, exist_ok=True)
rig = bpy.data.objects['SWAT_Rig']
character = bpy.data.objects['SWAT_Operator']
if character.get('asset_version') == 'v09':
    raise RuntimeError('Use the immutable v08 source, not the already polished v09.')
rig.animation_data.action = bpy.data.actions['IdleArmed']
bpy.context.scene.frame_set(0)
material = character.data.materials[0]
builder = Builder()
rigid = lambda bone: {bone: 1.0}

# Physical, restrained surface details, all attached to their anatomical bone.
# Helmet cover stitching and a boom microphone break the featureless dome.
for side in [-1, 1]:
    builder.tube([(side * .044, .083, 1.634), (side * .053, .028, 1.682),
                  (side * .048, -.048, 1.677), (side * .041, -.105, 1.619)],
                 .0018, 'webbing', rigid('head'), n=5)
builder.tube([(-.106, -.014, 1.524), (-.112, .062, 1.499),
              (-.047, .116, 1.487)], .003, 'rubber', rigid('head'), n=8)
builder.ellipsoid((-.040, .116, 1.487), (.014, .007, .009),
                  'rubber', rigid('head'), n=12, rings=6)
# Mask seams and a small ventilated front contour, not a box-like face.
for x in [-.027, -.0135, 0, .0135, .027]:
    builder.tube([(x, .110, 1.482), (x, .112, 1.506)],
                 .0018, 'rubber', rigid('head'), n=5)
# Plate-carrier stitching, zipper and small hardware remain rigid with chest.
for x in [-.142, .142]:
    builder.tube([(x, .166, 1.137), (x, .166, 1.25), (x * .68, .163, 1.347)],
                 .0014, 'mark', rigid('chest'), n=5)
builder.box((0, .165, 1.306), (.062, .009, .023), 'rubber', rigid('chest'), .002)
for x in [-.02, -.008, .004, .016]:
    builder.box((x, .171, 1.307), (.005, .003, .009), 'mark', rigid('chest'), .0005)
for side, sx in [('L', 1), ('R', -1)]:
    # Two tibial retention straps give the knee shell a visible attachment.
    for z in [.433, .521]:
        builder.loft([(sx * .11, .002, z - .012, .073, .079),
                      (sx * .11, .002, z + .012, .073, .079)],
                     'webbing', rigid('shin.' + side), n=24)
        builder.box((sx * .185, 0, z), (.012, .029, .024),
                    'polymer', rigid('shin.' + side), .003)
    # Padded ankle collars bridge the old visual trouser/boot separation.
    builder.loft([(sx * .11, -.006, .163, .057, .064),
                  (sx * .11, -.003, .185, .059, .067),
                  (sx * .11, -.001, .204, .056, .063)],
                 'glove', rigid('foot.' + side), n=24, fold=.015)
    # Lower sleeve cuff seam and cargo pocket stitching.
    builder.loft([(sx * .252, .004, .910, .047, .049),
                  (sx * .252, .004, .915, .047, .049)],
                 'rubber', rigid('forearm.' + side), n=20)
    builder.tube([(sx * .212, -.046, .753), (sx * .212, -.046, .679),
                  (sx * .212, .046, .679), (sx * .212, .046, .753)],
                 .0012, 'mark', rigid('thigh.' + side), n=5)

addition = builder.object('V09_SurfaceDetails', material, rig)
bpy.ops.object.select_all(action='DESELECT')
character.select_set(True)
addition.select_set(True)
bpy.context.view_layer.objects.active = character
bpy.ops.object.join()
# Remove zero-area export noise without blindly sealing text contours or
# welding unrelated garment/equipment shells, which would corrupt skinning.
report = {'source': 'outputs/v08/swat_visual_v08.blend', 'assets': {}}
for name in ['SWAT_Operator', 'AR_AssaultRifle', 'AR_Magazine']:
    ob = bpy.data.objects[name]
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    before = len(bm.faces)
    # Merge exact duplicate positions at collapsed caps (micrometre tolerance).
    # UVs remain per-loop; meaningful equipment gaps are not welded.
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-7, edges=list(bm.edges))
    zero = [f for f in bm.faces if f.calc_area() < 1e-11]
    bmesh.ops.delete(bm, geom=zero, context='FACES_ONLY')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    report['assets'][name] = {
        'faces_before_cleanup': before, 'faces_after_cleanup': len(bm.faces),
        'degenerate_faces': sum(f.calc_area() < 1e-11 for f in bm.faces),
        'boundary_edges': sum(e.is_boundary for e in bm.edges),
        'triangles': sum(len(f.verts) - 2 for f in bm.faces),
    }
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    ob['asset_version'] = 'v09'
# Ensure portable texture data regardless of Blender's original Windows paths.
for image in bpy.data.images:
    if image.name != 'Render Result' and image.source in {'FILE', 'GENERATED'}:
        if image.has_data and not image.packed_file:
            image.pack()
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.context.scene.unit_settings.scale_length = 1.0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'swat_visual_v09.blend'), compress=True)
report['limitations'] = [
    'Incremental procedural polish, not a photorealistic character rebuild.',
    'Open text/detail boundaries are retained; not a watertight printing mesh.',
    'Fixed grip fingers; no slope IK or collision certification for blended poses.',
]
(OUT / 'mesh_cleanup.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
runpy.run_path(str(ROOT / 'scripts' / 'export_anim.py'), run_name='__main__')
print('V09_POLISH_DONE', json.dumps(report))
