import bpy

ob = bpy.data.objects['SWAT_Operator']
me = ob.data

def mk(name, color, rough=0.7, metal=0.0, noise_scale=0, noise_amt=0.0):
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
    if noise_scale:
        tc = nt.nodes.new('ShaderNodeTexCoord'); tc.location = (-900, 0)
        mp = nt.nodes.new('ShaderNodeMapping'); mp.location = (-700, 0)
        nt.links.new(tc.outputs['UV'], mp.inputs['Vector'])
        nz = nt.nodes.new('ShaderNodeTexNoise'); nz.location = (-500, 0)
        nz.inputs['Scale'].default_value = noise_scale
        nz.inputs['Detail'].default_value = 8.0
        nt.links.new(mp.outputs['Vector'], nz.inputs['Vector'])
        mx = nt.nodes.new('ShaderNodeMixRGB'); mx.location = (-250, 120)
        mx.blend_type = 'MIX'
        mx.inputs['Color1'].default_value = (*color, 1)
        mx.inputs['Color2'].default_value = (*[min(1.0, c * 1.7) for c in color], 1)
        nt.links.new(nz.outputs['Fac'], mx.inputs['Fac'])
        mx.inputs['Fac'].default_value = noise_amt
        nt.links.new(mx.outputs['Color'], b.inputs['Base Color'])
        rr = nt.nodes.new('ShaderNodeMapRange'); rr.location = (-250, -160)
        rr.inputs['To Min'].default_value = max(0.0, rough - 0.15)
        rr.inputs['To Max'].default_value = min(1.0, rough + 0.15)
        nt.links.new(nz.outputs['Fac'], rr.inputs['Value'])
        nt.links.new(rr.outputs['Result'], b.inputs['Roughness'])
    m.diffuse_color = (*color, 1)
    return m

M = {
    'uniform': mk('SWAT_Uniform', (0.075, 0.095, 0.140), 0.82, 0.0, 90, 0.35),
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

def classify(c):
    x, y, z = c.x, c.y, c.z
    if z > 1.50:
        return 'gear'
    if 1.47 < z < 1.56 and y > 0.085:
        return 'lens'
    if 1.44 < z <= 1.50 and y > 0.05 and abs(x) < 0.07:
        return 'skin'
    if 1.15 < z < 1.42:
        if abs(y) > 0.075 or abs(x) > 0.145:
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
