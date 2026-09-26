import bpy

def make(name, color, rough, metal=0.0, scale=0.0, detail=8.0,
         dark=0.35, variation=0.45, bump=0.0):
    """Procedural PBR material: noise-driven colour variation, roughness
    breakup, and optional bump for surface texture."""
    m = bpy.data.materials.get(name)
    if not m:
        m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type != 'OUTPUT_MATERIAL':
            nt.nodes.remove(n)
    out = nt.nodes['Material Output']
    out.location = (600, 0)
    b = nt.nodes.new('ShaderNodeBsdfPrincipled')
    b.location = (300, 0)
    nt.links.new(b.outputs['BSDF'], out.inputs['Surface'])
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal

    if scale:
        tc = nt.nodes.new('ShaderNodeTexCoord'); tc.location = (-1100, 0)
        mp = nt.nodes.new('ShaderNodeMapping'); mp.location = (-900, 0)
        nt.links.new(tc.outputs['Object'], mp.inputs['Vector'])

        nz = nt.nodes.new('ShaderNodeTexNoise'); nz.location = (-700, 100)
        nz.inputs['Scale'].default_value = scale
        nz.inputs['Detail'].default_value = detail
        nz.inputs['Roughness'].default_value = 0.62
        nt.links.new(mp.outputs['Vector'], nz.inputs['Vector'])

        # colour variation: base -> darker grime
        cr = nt.nodes.new('ShaderNodeValToRGB'); cr.location = (-450, 220)
        cr.color_ramp.elements[0].position = 0.32
        cr.color_ramp.elements[0].color = (*[c * (1.0 - dark) for c in color], 1)
        cr.color_ramp.elements[1].position = 0.72
        cr.color_ramp.elements[1].color = (*[min(1.0, c * (1.0 + variation)) for c in color], 1)
        nt.links.new(nz.outputs['Fac'], cr.inputs['Fac'])
        nt.links.new(cr.outputs['Color'], b.inputs['Base Color'])

        # roughness breakup
        rr = nt.nodes.new('ShaderNodeMapRange'); rr.location = (-450, -80)
        rr.inputs['To Min'].default_value = max(0.02, rough - 0.22)
        rr.inputs['To Max'].default_value = min(1.0, rough + 0.22)
        nt.links.new(nz.outputs['Fac'], rr.inputs['Value'])
        nt.links.new(rr.outputs['Result'], b.inputs['Roughness'])

        # subtle bump so surfaces aren't perfectly flat
        if bump:
            nz2 = nt.nodes.new('ShaderNodeTexNoise'); nz2.location = (-700, -320)
            nz2.inputs['Scale'].default_value = scale * 4.0
            nz2.inputs['Detail'].default_value = 10.0
            nt.links.new(mp.outputs['Vector'], nz2.inputs['Vector'])
            bp = nt.nodes.new('ShaderNodeBump'); bp.location = (60, -260)
            bp.inputs['Strength'].default_value = bump
            bp.inputs['Distance'].default_value = 0.012
            nt.links.new(nz2.outputs['Fac'], bp.inputs['Height'])
            nt.links.new(bp.outputs['Normal'], b.inputs['Normal'])

    m.diffuse_color = (*color, 1)
    return m

MATS = {
    'wall':   make('SC_Concrete',  (0.300, 0.295, 0.285), 0.88, 0.0,  5.0, 10.0, 0.30, 0.30, 0.35),
    'floor':  make('SC_Tile',      (0.205, 0.200, 0.195), 0.62, 0.0, 26.0,  8.0, 0.25, 0.40, 0.18),
    'ceiling':make('SC_Ceiling',   (0.400, 0.395, 0.385), 0.92, 0.0,  4.0,  8.0, 0.22, 0.20, 0.10),
    'metal':  make('SC_Metal',     (0.230, 0.235, 0.245), 0.42, 0.85, 40.0,  8.0, 0.28, 0.35, 0.08),
    'frame':  make('SC_Steel',     (0.190, 0.192, 0.200), 0.38, 0.90, 55.0,  8.0, 0.30, 0.30, 0.06),
    'wood':   make('SC_Wood',      (0.290, 0.185, 0.105), 0.66, 0.0, 14.0, 10.0, 0.28, 0.45, 0.22),
    'crate':  make('SC_Crate',     (0.330, 0.225, 0.130), 0.74, 0.0, 20.0,  9.0, 0.30, 0.40, 0.28),
    'door':   make('SC_Door',      (0.240, 0.195, 0.150), 0.58, 0.0, 12.0,  8.0, 0.25, 0.35, 0.14),
    'glass':  make('SC_Glass',     (0.055, 0.075, 0.080), 0.06, 0.0),
}

# assign by object-name prefix
scene_col = bpy.data.collections['SceneRoom']
for o in scene_col.objects:
    n = o.name.lower()
    if n.startswith('win_glass'):
        key = 'glass'
    elif n.startswith('floor'):
        key = 'floor'
    elif n.startswith('ceiling'):
        key = 'ceiling'
    elif n.startswith('door_panel'):
        key = 'door'
    elif n.startswith('door_frame') or n.startswith('win_frame'):
        key = 'frame'
    elif n.startswith('wall'):
        key = 'wall'
    elif n.startswith('crate'):
        key = 'crate'
    elif n.startswith('desk') and 'top' in n:
        key = 'wood'
    else:
        key = 'metal'
    o.data.materials.clear()
    o.data.materials.append(MATS[key])

# count
from collections import Counter
c = Counter()
for o in scene_col.objects:
    c[o.data.materials[0].name] += 1
print('MATERIAL ASSIGNMENT:', dict(c))
print('TOTAL OBJECTS:', len(scene_col.objects))

bpy.ops.wm.save_mainfile()
print('SAVED')
