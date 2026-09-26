import bpy, math

# ============================================================
#  INDOOR TACTICAL ROOM  -  static geometry, Z-up, floor at Z=0
#  Room 8m x 7m, ceiling 2.9m. Door on -Y wall, window on +X wall.
# ============================================================
scene_col = bpy.data.collections.get('SceneRoom')
if scene_col:
    for o in list(scene_col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
else:
    scene_col = bpy.data.collections.new('SceneRoom')
    bpy.context.scene.collection.children.link(scene_col)

RW, RD, RH = 8.0, 7.0, 2.9      # room width(X), depth(Y), height(Z)
T = 0.14                        # wall thickness

def box(name, cx, cy, cz, sx, sy, sz):
    v = [(cx-sx, cy-sy, cz-sz), (cx+sx, cy-sy, cz-sz),
         (cx+sx, cy+sy, cz-sz), (cx-sx, cy+sy, cz-sz),
         (cx-sx, cy-sy, cz+sz), (cx+sx, cy-sy, cz+sz),
         (cx+sx, cy+sy, cz+sz), (cx-sx, cy+sy, cz+sz)]
    f = [(0,1,2,3), (4,7,6,5), (0,4,5,1), (1,5,6,2), (2,6,7,3), (3,7,4,0)]
    me = bpy.data.meshes.new(name)
    me.from_pydata(v, [], f)
    me.update()
    o = bpy.data.objects.new(name, me)
    scene_col.objects.link(o)
    return o

S = []
# ---------- floor / ceiling ----------
S.append(('floor',   box('floor',   0, 0, -0.05, RW/2, RD/2, 0.05)))
S.append(('ceiling', box('ceiling', 0, 0, RH+0.05, RW/2, RD/2, 0.05)))

# ---------- walls (with a door gap on -Y and a window gap on +X) ----------
# back wall (+Y) solid
S.append(('wall', box('wall_back', 0, RD/2, RH/2, RW/2, T/2, RH/2)))
# front wall (-Y) split around a 1.1m doorway at X 1.4..2.5
S.append(('wall', box('wall_front_a', -1.6, -RD/2, RH/2, 4.3, T/2, RH/2)))
S.append(('wall', box('wall_front_b',  4.0, -RD/2, RH/2, 2.4, T/2, RH/2)))
S.append(('wall', box('wall_front_head', 1.95, -RD/2, 2.55, 0.55, T/2, 0.35)))
# left wall (-X)
S.append(('wall', box('wall_left', -RW/2, 0, RH/2, T/2, RD/2, RH/2)))
# right wall (+X) split around a window at Y -1.2..1.2, Z 0.95..2.15
S.append(('wall', box('wall_right_a', RW/2, -2.6, RH/2, T/2, 1.8, RH/2)))
S.append(('wall', box('wall_right_b', RW/2,  2.6, RH/2, T/2, 1.8, RH/2)))
S.append(('wall', box('wall_right_sill', RW/2, 0, 0.475, T/2, 1.2, 0.475)))
S.append(('wall', box('wall_right_head', RW/2, 0, 2.525, T/2, 1.2, 0.375)))

# ---------- door frame + door ----------
S.append(('frame', box('door_frame_l', 1.35, -RD/2, 1.10, 0.07, 0.09, 1.10)))
S.append(('frame', box('door_frame_r', 2.55, -RD/2, 1.10, 0.07, 0.09, 1.10)))
S.append(('frame', box('door_frame_top', 1.95, -RD/2, 2.24, 0.67, 0.09, 0.07)))
S.append(('door',  box('door_panel', 2.42, -RD/2 + 0.22, 1.08, 0.55, 0.035, 1.05)))

# ---------- window frame + glass ----------
S.append(('frame', box('win_frame_t', RW/2, 0, 2.15, 0.07, 1.22, 0.05)))
S.append(('frame', box('win_frame_b', RW/2, 0, 0.95, 0.07, 1.22, 0.05)))
S.append(('frame', box('win_frame_l', RW/2, -1.17, 1.55, 0.07, 0.05, 0.62)))
S.append(('frame', box('win_frame_r', RW/2,  1.17, 1.55, 0.07, 0.05, 0.62)))
S.append(('glass', box('win_glass', RW/2, 0, 1.55, 0.015, 1.12, 0.58)))

# ---------- cover: desks, cabinets, crates ----------
S.append(('wood', box('desk_a_top', -2.2, -1.6, 0.74, 0.75, 0.42, 0.035)))
for dx in (-0.68, 0.68):
    for dy in (-0.36, 0.36):
        S.append(('metal', box('desk_a_leg%.0f%.0f' % (dx*10, dy*10),
                               -2.2+dx, -1.6+dy, 0.36, 0.035, 0.035, 0.36)))
S.append(('wood', box('desk_b_top', 2.6, 2.2, 0.74, 0.70, 0.42, 0.035)))
for dx in (-0.63, 0.63):
    for dy in (-0.36, 0.36):
        S.append(('metal', box('desk_b_leg%.0f%.0f' % (dx*10, dy*10),
                               2.6+dx, 2.2+dy, 0.36, 0.035, 0.035, 0.36)))

S.append(('metal', box('cabinet_a', -3.35, 1.9, 0.62, 0.30, 0.42, 0.62)))
S.append(('metal', box('cabinet_b', -3.35, 1.0, 0.62, 0.30, 0.42, 0.62)))
S.append(('metal', box('cabinet_c',  3.4, -2.3, 0.62, 0.30, 0.42, 0.62)))

S.append(('crate', box('crate_a', -0.6, 2.5, 0.35, 0.35, 0.35, 0.35)))
S.append(('crate', box('crate_b',  0.2, 2.5, 0.35, 0.35, 0.35, 0.35)))
S.append(('crate', box('crate_c', -0.2, 2.5, 1.05, 0.35, 0.35, 0.35)))
S.append(('crate', box('crate_d',  2.0, -1.0, 0.30, 0.30, 0.30, 0.30)))

print('SCENE PARTS:', len(S))

# ---------- build ----------
objs = []
for tag, o in S:
    objs.append((tag, o))
print('built %d objects' % len(objs))

# tag materials by group for later assignment
import json
groups = {}
for tag, o in objs:
    groups.setdefault(tag, []).append(o.name)
print('GROUPS:', json.dumps({k: len(v) for k, v in groups.items()}))

bpy.ops.wm.save_mainfile()
print('SAVED')
