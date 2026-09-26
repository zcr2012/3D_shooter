"""Restore procedural materials by re-classifying faces by region.
Run: blender -b file.blend -P restore_mats.py
"""
import bpy

def mk(name, color, rough=0.7, metal=0.0, nscale=0, namt=0.0):
    m = bpy.data.materials.get(name)
    if m:
        bpy.data.materials.remove(m)
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

# ---------- character materials ----------
CM = {
    'uniform': mk('SWAT_Uniform', (0.075, 0.095, 0.140), 0.82, 0.0,  90, 0.35),
    'gear':    mk('SWAT_Gear',    (0.042, 0.046, 0.054), 0.68, 0.0, 140, 0.30),
    'polymer': mk('SWAT_Polymer', (0.062, 0.070, 0.082), 0.42, 0.0, 200, 0.25),
    'skin':    mk('SWAT_Skin',    (0.44, 0.33, 0.26),    0.62, 0.0, 260, 0.15),
    'lens':    mk('SWAT_Lens',    (0.05, 0.11, 0.09),    0.08, 0.0),
    'metal':   mk('SWAT_Metal',   (0.28, 0.29, 0.31),    0.30, 0.95),
}
CO = ['uniform', 'gear', 'polymer', 'skin', 'lens', 'metal']
CIDX = {k: i for i, k in enumerate(CO)}

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

ob = bpy.data.objects['SWAT_Operator']
me = ob.data
me.materials.clear()
for k in CO:
    me.materials.append(CM[k])
cnt = {}
for p in me.polygons:
    t = classify(p.center)
    p.material_index = CIDX[t]
    cnt[t] = cnt.get(t, 0) + 1
print('CHAR MATERIAL FACES:', cnt)

# ---------- rifle materials ----------
RM = {
    'steel':   mk('Gun_Steel',   (0.020, 0.021, 0.024), 0.40, 1.0, 220, 0.30),
    'polymer': mk('Gun_Polymer', (0.026, 0.027, 0.031), 0.66, 0.0, 320, 0.30),
    'glass':   mk('Gun_Glass',   (0.05, 0.13, 0.09),    0.06, 0.0),
}
RO = ['steel', 'polymer', 'glass']
RIDX = {k: i for i, k in enumerate(RO)}
SC = 0.86 / 0.612

rifle = bpy.data.objects['AR_AssaultRifle']
rme = rifle.data
rme.materials.clear()
for k in RO:
    rme.materials.append(RM[k])

def rclass(c):
    x, y, z = c.x, c.y, c.z
    if z > 0.085 and y > 0.165:
        return 'glass'
    if y > 0.24 and abs(x) < 0.030:
        return 'steel'
    if y > 0.42 and abs(x) < 0.030:
        return 'steel'
    if abs(x) < 0.040 and -0.10 < y < 0.24 and z > -0.055:
        return 'steel'
    if z < -0.045:
        return 'polymer' if y < -0.02 else 'steel'
    if z < -0.075 and -0.02 < y < 0.10:
        return 'polymer'
    if 0.13 < y < 0.36 and z > -0.045:
        return 'polymer'
    if y < -0.10:
        return 'polymer'
    return 'polymer'

rc = {}
for p in rme.polygons:
    t = rclass(p.center)
    p.material_index = RIDX[t]
    rc[t] = rc.get(t, 0) + 1
print('RIFLE MATERIAL FACES:', rc)

bpy.ops.wm.save_mainfile()
print('SAVED')
