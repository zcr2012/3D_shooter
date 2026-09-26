"""Production asset audit for the SWAT Blender/Godot project.
Run: blender -b swat_operator.blend -P audit_production.py
"""
import bpy, bmesh, json, os, math

sc = bpy.context.scene
print('=== PRODUCTION AUDIT ===')
print('Blender:', bpy.app.version_string)
print('Scene:', sc.name, 'FPS:', sc.render.fps)

for ob in bpy.data.objects:
    if ob.type != 'MESH':
        continue
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me)
    tris = sum(len(f.verts) - 2 for f in bm.faces)
    boundary = sum(1 for e in bm.edges if len(e.link_faces) == 1)
    nonman = sum(1 for e in bm.edges if len(e.link_faces) > 2)
    loose = sum(1 for v in bm.verts if len(v.link_edges) == 0)
    bm.free()
    uv = len(me.uv_layers)
    mats = [m.name for m in me.materials if m]
    print('MESH %-24s verts=%-6d faces=%-6d tris=%-7d uv=%d mats=%s boundary=%d nonman=%d loose=%d' % (
        ob.name, len(me.vertices), len(me.polygons), tris, uv, mats,
        boundary, nonman, loose))

for arm in [o for o in bpy.data.objects if o.type == 'ARMATURE']:
    print('ARMATURE %-20s bones=%d' % (arm.name, len(arm.data.bones)))
    print('  bones:', ', '.join(b.name for b in arm.data.bones))
    if arm.animation_data and arm.animation_data.action:
        a = arm.animation_data.action
        print('  active action:', a.name, 'range:', tuple(a.frame_range))
for a in bpy.data.actions:
    print('ACTION %-24s range=%s' % (a.name, tuple(a.frame_range)))

for ob in [o for o in bpy.data.objects if o.type == 'MESH']:
    if ob.name == 'SWAT_Operator':
        no_w = sum(1 for v in ob.data.vertices if sum(g.weight for g in v.groups) < 0.001)
        print('SKIN weightless_vertices:', no_w, '/', len(ob.data.vertices))
        print('SKIN vertex_groups:', len(ob.vertex_groups))

# dimensions / scale sanity
for name in ('SWAT_Operator', 'AR_AssaultRifle'):
    ob = bpy.data.objects.get(name)
    if ob:
        print('DIM %-24s dims=(%.3f, %.3f, %.3f) scale=(%.3f, %.3f, %.3f)' % (
            name, ob.dimensions.x, ob.dimensions.y, ob.dimensions.z,
            ob.scale.x, ob.scale.y, ob.scale.z))

print('IMAGES:')
for img in bpy.data.images:
    if img.name.startswith(('SWAT_', 'AR_', 'SC_')):
        print('  %-36s %dx%d packed=%s' % (
            img.name, img.size[0], img.size[1], bool(img.packed_file)))
print('=== END AUDIT ===')
