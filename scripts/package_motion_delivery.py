"""Package the validated v07 increment; explicit status, no production claims."""
from pathlib import Path
import json, shutil, zipfile, hashlib, html
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'outputs'
font_path='C:/Windows/Fonts/msyh.ttc'
font=lambda size: ImageFont.truetype(font_path,size)
# Animated motion proofs assembled from authored Blender frames.
for name,step in [('walk',33),('reload',67)]:
    files=sorted((OUT/'motion_frames').glob(name+'_*.png'))
    assert len(files)==(36 if name=='walk' else 43),(name,len(files))
    frames=[]
    for i,p in enumerate(files):
        im=Image.open(p).convert('RGB')
        draw=ImageDraw.Draw(im)
        draw.rounded_rectangle((12,12,im.width-12,49),radius=8,fill='#F3F6FA')
        draw.text((22,20),('持枪行走 · 1.2 秒循环' if name=='walk' else '换弹 · 2.8 秒动作'),font=font(16),fill='#243346')
        frames.append(im)
    durations=[([30,30,40] if name=='walk' else [70,60,70])[i%3] for i in range(len(frames))]
    if name=='reload': durations[-1]=750
    frames[0].save(OUT/('motion_'+name+'.gif'),save_all=True,append_images=frames[1:],duration=durations,loop=0,optimize=False)
# Contact sheet, preserving actual render appearance.
items=[('idle','待机'),('walk','行走'),('run','跑步'),('aim','瞄准'),('fire','射击'),('reload','换弹'),('hit','受击')]
canvas=Image.new('RGB',(1400,934),'#F4F6F9'); draw=ImageDraw.Draw(canvas)
draw.text((32,22),'SWAT / 动作与蒙皮迭代 v07',font=font(26),fill='#233246')
draw.text((34,62),'实际 Blender 渲染 · 原型美术尚未达到商业写实标准',font=font(17),fill='#586A7E')
for i,(tag,label) in enumerate(items):
    x=24+(i%4)*344; y=112+(i//4)*402
    im=Image.open(OUT/('motion_'+tag+'.png')).convert('RGB'); im.thumbnail((324,354))
    canvas.paste(im,(x+(324-im.width)//2,y))
    draw.text((x+12,y+362),label,font=font(20),fill='#243346')
canvas.save(OUT/'motion_contact_sheet.jpg',quality=91)
verify=json.loads((OUT/'production_motion_verification.json').read_text(encoding='utf-8'))
audit=json.loads((OUT/'motion_mesh_audit.json').read_text(encoding='utf-8'))
assert verify['failure_count']==0
textures=json.loads((OUT/'texture_manifest.json').read_text(encoding='utf-8'))
assert len(textures)==22
# No accidentally-black source images; record source statistics.
from PIL import ImageStat
texture_stats=[]
for t in textures:
    im=Image.open(OUT/t['path']).convert('RGB'); st=ImageStat.Stat(im)
    texture_stats.append({'file':t['path'],'size':im.size,'mean':st.mean,'extrema':im.getextrema()})
(OUT/'texture_pixel_audit.json').write_text(json.dumps(texture_stats,indent=2),encoding='utf-8')
shutil.copy2(ROOT/'godot_project/assets/swat_operator.glb',OUT/'swat_operator_v07.glb')
shutil.copy2(ROOT/'godot_project/assets/tactical_room.glb',OUT/'tactical_room_v07.glb')
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SWAT v07 · 动作与蒙皮验收</title><style>
:root{color-scheme:light;font-family:system-ui,"Microsoft YaHei",sans-serif;color:#233246;background:#f4f6f9}*{box-sizing:border-box}body{margin:0}main{max-width:1180px;margin:auto;padding:36px 28px 60px}header{border-bottom:1px solid #d9e1eb;padding-bottom:24px}.eyebrow{font-size:12px;letter-spacing:2px;color:#55728e}h1{font-size:34px;margin:10px 0 12px}p{line-height:1.8;color:#566579;margin:8px 0}.status{display:inline-block;border:1px solid #e4bf6b;background:#fff6dc;color:#806019;border-radius:30px;padding:6px 14px;font-size:13px}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin:24px 0}.card{background:#fff;border:1px solid #dbe3ec;border-radius:12px;padding:20px}.value{font-size:28px;font-weight:650;margin-bottom:6px}.label{font-size:13px;color:#617185}h2{font-size:22px;margin:30px 0 16px}.columns{display:grid;grid-template-columns:1fr 1fr;gap:20px}.media{background:#fff;border:1px solid #dbe3ec;border-radius:12px;overflow:hidden}.media img{display:block;width:100%;height:auto}.media .gif{width:360px;max-width:100%;margin:auto}.caption{padding:13px 18px;font-size:14px;color:#4f6075}.wide{margin-top:18px}ul{padding-left:22px;color:#516278;line-height:1.9}table{border-collapse:collapse;width:100%;font-size:14px}td,th{padding:11px 14px;text-align:left;border-bottom:1px solid #e2e8ef}th{background:#edf3f8;font-weight:600}code{font-size:12px;background:#eef2f7;padding:2px 5px;border-radius:4px}a{color:#245e9b;text-decoration:none}.downloads{display:flex;flex-wrap:wrap;gap:12px;margin:18px 0}.button{padding:12px 16px;border:1px solid #b7cadd;border-radius:8px;background:white}.primary{background:#245e9b;color:#fff;border-color:#245e9b}.note{padding:16px 20px;background:#fff7e8;border:1px solid #eed5a6;border-radius:10px;color:#805b24;line-height:1.8}footer{margin-top:30px;font-size:12px;color:#708093}@media(max-width:760px){.grid{grid-template-columns:1fr 1fr}.columns{grid-template-columns:1fr}h1{font-size:27px}main{padding:24px 16px}}
</style><main><header><div class="eyebrow">LOCAL BUILD / 2026-09-26 / GODOT 4.6.3</div><h1>特警行动：动作与蒙皮迭代 v07</h1><p>已落地的基础动作工程，不是商业级美术完成稿。保留原工程，新增可复用动作、修复动态权重，并完成游戏内逻辑回归。</p><span class="status">功能回归通过 · 商业视觉与目标性能尚未验收</span></header>
<div class="grid"><div class="card"><div class="value">7 类</div><div class="label">基础动作，含独立弹匣换弹</div></div><div class="card"><div class="value">374 / 374</div><div class="label">Godot 功能检查通过</div></div><div class="card"><div class="value">8,688</div><div class="label">角色 + 武器 / 弹匣三角面</div></div><div class="card"><div class="value">22 张</div><div class="label">可编辑 PNG 贴图源文件</div></div></div>
<div class="downloads"><a class="button primary" href="SWAT_v07_delivery.zip" download>下载本轮完整工程包</a><a class="button" href="swat_motion_v07.blend" download>Blender 源工程</a><a class="button" href="swat_operator_v07.glb" download>角色与动作 GLB</a><a class="button" href="production_motion_verification.json" download>374 项回归记录</a></div>
<h2>先看真实动作</h2><div class="columns"><div class="media"><img class="gif" src="motion_walk.gif"><div class="caption">持枪行走 / 1.2 秒循环，原地预览；游戏按真实地速驱动步频。</div></div><div class="media"><img class="gif" src="motion_reload.gif"><div class="caption">换弹 / 2.8 秒：支撑手离开护木，抽离并重新插入弹匣。手指和新旧弹匣交替仍未制作。</div></div></div>
<div class="media wide"><img src="motion_contact_sheet.jpg"><div class="caption">七类动作的真实棚拍截图：待机、行走、跑步、瞄准、射击、换弹、受击。</div></div>
<div class="columns"><section><h2>这轮实际修改</h2><div class="card"><ul><li>24 个装备壳体改为整块刚性赋权，修复背心、护具被多骨拉扯。</li><li>身体权重使用平滑解剖区域，最多 4 个骨骼影响；装备增加小倒角并校正外法线。</li><li>解析双骨腿部 + 接触轨迹；足部滚动按靴底包络补偿，修掉约 7 mm 穿地。</li><li>双手按武器握持点求解，新增 weapon_root / weapon_mag，武器随胸部与骨盆稳定继承。</li><li>Godot 上、下半身独立动画轨：行走时开火、瞄准或换弹，不冻结腿部。</li><li>库存 30 / 90；只在换弹完成时结算一次，受击取消不补弹，缺换弹片段直接拒绝。</li></ul></div></section><section><h2>验证边界</h2><div class="card"><ul><li>359 帧实际变形网格检查：0 未赋权顶点、0 非有限坐标、0 边界边／非流形边。</li><li>采样帧的最低靴底误差、右手握持误差均小于 0.001 mm；这是平地离散采样，不代表斜坡或所有混合过渡。</li><li>刚性装备边长相对变化小于 0.01%。四个循环首末端点通过。</li><li>4 个视角 × WASD 共 16 组方向检查，角色落地稳定；36 个静态碰撞体。</li><li>移动换弹、受击中断、弹空保护、动作不反复重启、鼠标捕获失败与首击门控均通过。</li><li>Intel Iris Xe / Vulkan Forward+ 实际渲染可显示。单帧 128 draw calls；未作 1080p60 持续性能验收。</li></ul></div></section></div>
<h2>动作清单</h2><div class="card"><table><thead><tr><th>片段</th><th>时长</th><th>模式</th><th>说明</th></tr></thead><tbody><tr><td>IdleArmed</td><td>3.00 s</td><td>循环</td><td>站立与呼吸</td></tr><tr><td>WalkArmed</td><td>1.20 s</td><td>循环</td><td>基准 1.0 m/s；游戏步行 1.8 m/s</td></tr><tr><td>RunArmed</td><td>0.80 s</td><td>循环</td><td>基准 2.6 m/s；游戏冲刺 3.5 m/s</td></tr><tr><td>AimArmed</td><td>3.00 s</td><td>循环</td><td>上半身瞄准姿态，并非完整镜内瞄准系统</td></tr><tr><td>FireArmed</td><td>0.267 s</td><td>一次</td><td>后坐动作与扣弹；未新增弹道／伤害／特效</td></tr><tr><td>ReloadArmed</td><td>2.80 s</td><td>一次</td><td>独立弹匣、完成结算、可被受击打断</td></tr><tr><td>HitReact</td><td>0.667 s</td><td>一次</td><td>receive_hit() 触发；非完整生命／敌人系统</td></tr></tbody></table></div>
<h2>真实 Godot 截图</h2><div class="media"><img src="godot_motion_runtime.png"><div class="caption">继承原室内场景与照明。当前场景偏暗，环境质量未在本轮重建；此图不代替性能测试。</div></div>
<h2>如何打开</h2><div class="card"><p>解压 <code>SWAT_v07_delivery.zip</code>，用 Godot 4.6.3 导入 <code>godot_project/project.godot</code> 后运行；用 Blender 打开 <code>swat_motion_v07.blend</code>。GLB 在 <code>godot_project/assets/</code>，源贴图在 <code>texture_sources/</code>，检测结果在 <code>validation/</code>。压缩包不包含引擎缓存，首次打开需重新导入。</p><p><b>操作：</b>WASD 移动，鼠标转视角，Shift 冲刺，右键瞄准姿态，左键单发动作，R 换弹，Esc 释放鼠标。重新捕获的第一次点击不射击。受击通过 <code>receive_hit()</code> 调用。</p><p>原工作区入口不变：<code>godot_project/project.godot</code>。Blender 新版本另存为 <code>outputs/swat_motion_v07.blend</code>，旧 <code>swat_operator.blend</code> 保留作上一版基线，避免误覆盖。</p></div>
<h2>尚未完成，不应误认为已达标</h2><div class="note">角色仍是明显原型化的体型、脸部、手部、靴子和装备；武器约 800 三角面，细节与表面层次不足。现有材质主要是 BaseColor / Roughness，没有完整商业法线与磨损制作。本轮没有重新制作室内场景。仍缺手指抓握、肩托贴合、不同方向战术移动、转身、蹲伏、跳跃／落地、坡地 IK、动捕级润色、完整射击反馈、LOD／遮挡系统与目标中低端 PC 的长期性能测试。已完成的是可靠的基础动作与控制增量，而非 Ready or Not 等级成品。</div>
<footer>独立证据：motion_authoring.json / motion_mesh_audit.json / production_motion_verification.json / texture_manifest.json。无外部商业素材导入，本轮保留现有程序化资源。</footer></main></html>'''
(OUT/'motion_review.html').write_text(page,encoding='utf-8')
# Portable deliverable: no .godot cache, backups, personal metadata or binaries.
zip_path=OUT/'SWAT_v07_delivery.zip'
with zipfile.ZipFile(zip_path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    z.write(OUT/'swat_motion_v07.blend','swat_motion_v07.blend')
    z.write(ROOT/'swat_operator.blend','authoring_input/swat_pre_v07.blend')
    z.writestr('authoring_input/REBUILD.txt','Use Blender -b swat_pre_v07.blend -P ../scripts/prepare_motion_rig.py -P ../scripts/build_motion_pack.py -P ../scripts/export_anim.py. Paths in these examples are relative to this folder. The candidate is written under outputs/. The baseline is only required for rebuilding, not playing.\n')
    for p in sorted((ROOT/'godot_project').rglob('*')):
        if p.is_file() and '.godot' not in p.parts and not p.name.endswith('.tmp'):
            z.write(p,p.relative_to(ROOT).as_posix())
    for p in sorted((OUT/'texture_sources').glob('*.png')): z.write(p,'texture_sources/'+p.name)
    for name in ['motion_authoring.json','motion_mesh_audit.json','production_motion_verification.json','texture_manifest.json','texture_pixel_audit.json','rig_repair.json']:
        z.write(OUT/name,'validation/'+name)
    offline_page=page.replace('href="swat_motion_v07.blend"','href="../swat_motion_v07.blend"').replace('href="swat_operator_v07.glb"','href="../godot_project/assets/swat_operator.glb"').replace('href="production_motion_verification.json"','href="../validation/production_motion_verification.json"').replace('<a class="button primary" href="SWAT_v07_delivery.zip" download>下载本轮完整工程包</a>','<span class="button">当前为已解压工程包</span>')
    z.writestr('review/motion_review.html',offline_page)
    for name in ['motion_contact_sheet.jpg','motion_walk.gif','motion_reload.gif','godot_motion_runtime.png']:
        z.write(OUT/name,'review/'+name)
    for name in ['prepare_motion_rig.py','motion_math.py','build_motion_pack.py','export_anim.py','audit_motion_candidate.py','render_motion_review.py','export_motion_sources.py']:
        z.write(ROOT/'scripts'/name,'scripts/'+name)
with zipfile.ZipFile(zip_path) as z:
    assert z.testzip() is None
    names=z.namelist()
    assert 'godot_project/project.godot' in names
    assert sum(n.startswith('texture_sources/') for n in names)==22
print('ZIP_FILES',len(names),'ZIP_MB',round(zip_path.stat().st_size/1024/1024,2))
print('ZIP_SHA256',hashlib.sha256(zip_path.read_bytes()).hexdigest())
print('RENDER_SCREENSHOT',Image.open(OUT/'godot_motion_runtime.png').size)
print('DELIVERY_READY')
