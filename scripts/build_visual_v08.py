"""Run against outputs/swat_motion_v07.blend, never in-place on v07."""
import bpy, sys, json
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'scripts'))
from v08_materials import material
from v08_character import make_character
from v08_weapon import make_weapon
OUT=ROOT/'outputs'/'v08'; OUT.mkdir(exist_ok=True)
rig=bpy.data.objects['SWAT_Rig']
rig.animation_data.action=bpy.data.actions['IdleArmed']
bpy.context.scene.frame_set(0)
mat=material()
character=make_character(mat,rig)
from v08_tailor import tailor
tailor(character,rig)
weapons=make_weapon(mat,rig)
bpy.context.view_layer.update()
report={o.name:{'vertices':len(o.data.vertices),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),
              'materials':len(o.data.materials)} for o in [character]+weapons}
report['actions']=[a.name for a in bpy.data.actions]
print('V08_ASSETS',json.dumps(report))
(OUT/'asset_build.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'swat_visual_v08.blend'))
