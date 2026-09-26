"""Unpack source textures and organize a final delivery copy."""
import bpy, json
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'outputs'
texdir=OUT/'texture_sources'; texdir.mkdir(exist_ok=True)
records=[]
for img in bpy.data.images:
    if img.name=='Render Result' or img.size[0]<1: continue
    # Packed images load lazily in a fresh headless session.
    _ = img.pixels[0] if len(img.pixels) else 0
    if not img.has_data: continue
    if img.name.startswith(('SWAT_','AR_','SC_')):
        path=texdir/(img.name+'.png')
        img.filepath_raw=str(path); img.file_format='PNG'; img.save()
        if not img.packed_file: img.pack()
        img.filepath_raw='//texture_sources/'+path.name
        records.append({'name':img.name,'path':'texture_sources/'+path.name,'width':img.size[0],'height':img.size[1],
            'color_space':img.colorspace_settings.name,'packed':bool(img.packed_file)})
arm=bpy.data.objects['SWAT_Rig']; arm.animation_data.action=bpy.data.actions['IdleArmed']
bpy.context.scene.frame_set(0)
# Save the validated candidate; preserve all scene geometry and editable actions.
bpy.ops.wm.save_mainfile()
(OUT/'texture_manifest.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
print('SOURCE_TEXTURES',len(records))
