import bpy, math
from mathutils import Vector

ob = bpy.data.objects['SWAT_Operator']

# report body size so gear can be aligned
xs = [v.co.x for v in ob.data.vertices]
ys = [v.co.y for v in ob.data.vertices]
zs = [v.co.z for v in ob.data.vertices]
print('BODY bounds X %.3f..%.3f  Y %.3f..%.3f  Z %.3f..%.3f' % (
    min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
print('BODY height %.3f m' % (max(zs) - min(zs)))

def box(name, cx, cy, cz, sx, sy, sz, tt=1.0, tb=1.0):
    bhx, bhy = sx * tb, sy * tb
    thx, thy = sx * tt, sy * tt
    v = [(cx-bhx, cy-bhy, cz-sz), (cx+bhx, cy-bhy, cz-sz),
         (cx+bhx, cy+bhy, cz-sz), (cx-bhx, cy+bhy, cz-sz),
         (cx-thx, cy-thy, cz+sz), (cx+thx, cy-thy, cz+sz),
         (cx+thx, cy+thy, cz+sz), (cx-thx, cy+thy, cz+sz)]
    f = [(0,1,2,3), (4,7,6,5), (0,4,5,1), (1,5,6,2), (2,6,7,3), (3,7,4,0)]
    me = bpy.data.meshes.new(name)
    me.from_pydata(v, [], f)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o

G = []
# helmet + face
G.append(('gear', box('g_helmet', 0, 0.010, 1.600, 0.092, 0.098, 0.062, 0.72, 0.98)))
G.append(('gear', box('g_brim',   0, 0.118, 1.585, 0.070, 0.028, 0.014, 0.90)))
G.append(('gear', box('g_rear',   0, -0.094, 1.572, 0.080, 0.022, 0.045, 0.95)))
for sx in (1, -1):
    G.append(('gear', box('g_rail%d' % sx, 0.094 * sx, 0.010, 1.596, 0.010, 0.060, 0.014)))
G.append(('gear', box('g_mask',   0, 0.062, 1.482, 0.072, 0.058, 0.038, 0.92, 0.88)))
G.append(('lens', box('g_goggle', 0, 0.100, 1.536, 0.074, 0.018, 0.030, 0.95)))

# vest
G.append(('gear', box('g_vestf', 0, 0.120, 1.265, 0.168, 0.038, 0.105, 0.95)))
G.append(('gear', box('g_vestb', 0, -0.116, 1.265, 0.166, 0.036, 0.105, 0.95)))
for sx in (1, -1):
    G.append(('gear',    box('g_vside%d' % sx, 0.152 * sx, 0.002, 1.190, 0.022, 0.098, 0.062)))
    G.append(('polymer', box('g_spad%d'  % sx, 0.170 * sx, 0.004, 1.400, 0.058, 0.092, 0.030, 0.85)))
G.append(('gear', box('g_mag0', -0.054, 0.164, 1.225, 0.044, 0.026, 0.042)))
G.append(('gear', box('g_mag1',  0.054, 0.164, 1.225, 0.044, 0.026, 0.042)))
G.append(('polymer', box('g_radio', -0.130, 0.128, 1.330, 0.026, 0.022, 0.040)))

# belt / holster / pouch
G.append(('gear', box('g_belt',   0, 0, 0.985, 0.148, 0.104, 0.028, 1.0, 0.98)))
G.append(('metal', box('g_buckle', 0, 0.114, 0.985, 0.030, 0.012, 0.022)))
G.append(('gear', box('g_holster', -0.152, 0.055, 0.660, 0.030, 0.052, 0.078)))
G.append(('gear', box('g_pouch',    0.154, 0.048, 0.940, 0.026, 0.050, 0.052)))

# kneepads + boots
for sx in (1, -1):
    G.append(('polymer', box('g_knee%d' % sx, 0.110 * sx, 0.070, 0.500, 0.070, 0.030, 0.058, 0.92, 0.92)))
    G.append(('gear',    box('g_boot%d' % sx, 0.110 * sx, 0.032, 0.055, 0.060, 0.105, 0.052)))

print('GEAR BOXES:', len(G))

bpy.ops.object.select_all(action='DESELECT')
for tag, g in G:
    g.select_set(True)
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.object.join()
print('JOINED: %d verts / %d faces' % (len(ob.data.vertices), len(ob.data.polygons)))

# ============================================================
#  MATERIALS
# ============================================================
me = ob.data

def mk(name, color, rough=0.7, metal=0.0, nscale=0, namt=0.0):
    m = bpy.data.materials.get(name)
    if not m:
        m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type != 'OUTPUT_MATERIAL':
            nt.nodes.remove(n)
    out = nt.nodes['Material Output']
    b = nt.nodes.new('ShaderNodeBsdfPrincipled')
    b.location = (200, 0)
    nt.links.new(b.outputs['BSDF'], out.inputs['Surface'])
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if nscale:
        tc = nt.nodes.new('ShaderNodeTexCoord'); tc.location = (-900, 0)
        mp = nt.nodes.new('ShaderNodeMapping'); mp.location = (-700, 0)
        nt.links.new(tc.outputs['Object'], mp.inputs['Vector'])
        nz = nt.nodes.new('ShaderNodeTexNoise'); nz.location = (-500, 0)
        nz.inputs['Scale'].default_value = nscale
        nz.inputs['Detail'].default_value = 8.0
        nt.links.new(mp.outputs['Vector'], nz.inputs['Vector'])
        mx = nt.nodes.new('ShaderNodeMixRGB'); mx.location = (-250, 120)
        mx.blend_type = 'MIX'
        mx.inputs['Color1'].default_value = (*color, 1)
        mx.inputs['Color2'].default_value = (*[min(1.0, c * 1.7) for c in color], 1)
        mx.inputs['Fac'].default_value = namt
        nt.links.new(nz.outputs['Fac'], mx.inputs['Fac'])
        nt.links.new(mx.outputs['Color'], b.inputs['Base Color'])
        rr = nt.nodes.new('ShaderNodeMapRange'); rr.location = (-250, -160)
        rr.inputs['To Min'].default_value = max(0.0, rough - 0.15)
        rr.inputs['To Max'].default_value = min(1.0, rough + 0.15)
        nt.links.new(nz.outputs['Fac'], rr.inputs['Value'])
        nt.links.new(rr.outputs['Result'], b.inputs['Roughness'])
    m.diffuse_color = (*color, 1)
    return m

M = {
    'uniform': mk('SWAT_Uniform', (0.075, 0.095, 0.140), 0.82, 0.0,  90, 0.35),
    'gear':    mk('SWAT_Gear',    (0.042, 0.046, 0.054), 0.68, 0.0, 140, 0.30),
    'polymer': mk('SWAT_Polymer', (0.062, 0.070, 0.082), 0.42, 0.0, 200, 0.25),
    'skin':    mk('SWAT_Skin',    (0.44, 0.33, 0.26),    0.62, 0.0, 260, 0.15),
    'lens':    mk('SWAT_Lens',    (0.05, 0.11, 0.09),    0.08, 0.0),
    'metal':   mk('SWAT_Metal',   (0.28, 0.29, 0.31),    0.30, 0.95),
}
ORDER = ['uniform', 'gear', 'polymer', 'skin', 'lens', 'metal']
me.materials.clear()
for k in ORDER:
    me.materials.append(M[k])
IDX = {k: i for i, k in enumerate(ORDER)}

# assign: gear boxes got their tag recorded by position; body defaults to uniform
for p in me.polygons:
    p.material_index = IDX['uniform']

# re-tag gear by the object names we merged (their verts are the last ones)
gear_start = None
for i, v in enumerate(me.vertices):
    pass

# simpler: classify by region, same rules as before
def classify(c):
    x, y, z = c.x, c.y, c.z
    if z > 1.50:
        return 'gear'
    if 1.47 < z < 1.56 and y > 0.085:
        return 'lens'
    if 1.44 < z <= 1.50 and y > 0.05 and abs(x) < 0.07:
        return 'skin'
    if 1.15 < z < 1.42 and (abs(y) > 0.075 or abs(x) > 0.145):
        return 'gear'
    if z > 1.36 and abs(x) > 0.14:
        return 'polymer'
    if 0.94 < z < 1.03 and (abs(y) > 0.09 or abs(x) > 0.13):
        return 'gear'
    if 0.60 < z < 0.74 and abs(x) > 0.13:
        return 'gear'
    if 0.44 < z < 0.58 and y > 0.03:
        return 'polymer'
    if z < 0.12:
        return 'gear'
    return 'uniform'

cnt = {}
for p in me.polygons:
    t = classify(p.center)
    p.material_index = IDX[t]
    cnt[t] = cnt.get(t, 0) + 1
print('MATERIAL FACES:', cnt)
print('SLOTS:', [m.name for m in me.materials])

bpy.ops.wm.save_mainfile()
print('SAVED')
