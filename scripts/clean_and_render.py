import bpy, bmesh, math
from mathutils import Vector

ob = bpy.data.objects['SWAT_Operator']

# ---------- delete loose vertices ----------
bm = bmesh.new(); bm.from_mesh(ob.data)
loose = [v for v in bm.verts if len(v.link_edges) == 0]
print('loose verts removed:', len(loose))
bmesh.ops.delete(bm, geom=loose, context='VERTS')
bm.to_mesh(ob.data); bm.free(); ob.data.update()
print('clean: verts=%d faces=%d' % (len(ob.data.vertices), len(ob.data.polygons)))

# ---------- base material ----------
mat = bpy.data.materials.get('SWAT_Base')
if not mat:
    mat = bpy.data.materials.new('SWAT_Base')
mat.use_nodes = True
b = mat.node_tree.nodes.get('Principled BSDF')
b.inputs['Base Color'].default_value = (0.085, 0.105, 0.150, 1)
b.inputs['Roughness'].default_value = 0.72
mat.diffuse_color = (0.085, 0.105, 0.150, 1)
ob.data.materials.clear()
ob.data.materials.append(mat)

# ---------- render setup ----------
sc = bpy.context.scene
cam = bpy.data.objects.get('PreviewCam')
if not cam:
    cd = bpy.data.cameras.new('PreviewCam')
    cam = bpy.data.objects.new('PreviewCam', cd)
    sc.collection.objects.link(cam)
sc.camera = cam
cam.data.lens = 60
target = Vector((0, 0, 0.88))

sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x = 620
sc.render.resolution_y = 860
sc.eevee.taa_render_samples = 48
sc.view_settings.view_transform = 'Standard'
sc.view_settings.exposure = 1.15

w = sc.world; w.use_nodes = True
bg = w.node_tree.nodes.get('Background')
bg.inputs[0].default_value = (0.06, 0.068, 0.085, 1)
bg.inputs[1].default_value = 0.8
for n, e in [('Key', 70), ('Fill', 26), ('RimL', 50), ('RimR', 38), ('Front', 20)]:
    o = bpy.data.objects.get(n)
    if o:
        o.data.energy = e

for tag, loc in {'front': Vector((0, 3.0, 1.15)),
                 'side':  Vector((3.0, 0.10, 1.15)),
                 'q34':   Vector((2.0, 2.2, 1.50))}.items():
    cam.location = loc
    cam.rotation_euler = (target - loc).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = 'C:/Users/zhangshuai/WorkBuddy AI/3D_shooter/body_%s.png' % tag
    bpy.ops.render.render(write_still=True)
    print('rendered', tag)

bpy.ops.wm.save_mainfile()
print('SAVED')
