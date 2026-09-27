# 《寂静港口》实际验证记录 · 2026-09-27

以 GitHub Actions 上**官方 Godot 4.6.3**（ubuntu-latest 与 windows-latest）的真实运行为准。前两批在沙箱内无法运行 Godot，
所有引擎结果都来自 CI；第三、四批在沙箱内用源码编译的无头 4.6.3（无渲染）先行跑过全部套件，再以 CI 为准。
每次提交的逐项结果可在该提交的 check-runs / annotations 中查看。

| 套件 | 检查数 | 覆盖 |
|---|---|---|
| `verify_session.gd` | **95** | 暂停冻结、存档/恢复、坏存档回退到备份、补给一次性、重试资源下限、门碰撞与敌组阶段、H 等待/跟随、完整护送不卡住并撤离、证人骨骼动画状态、检查点 `headshots` 字段接受/拒绝/旧档缺省、恢复后反馈状态清零 |
| `verify_chapter_zh.gd` | **33** | 中文字体与换行、19 段对白全部解码（缺音频时的字幕回退路径也在套件内）、字幕计时、过场、掩体/视野/听觉/换弹等战术 AI |
| `verify_urban.gd` | **71** | 城市首关流程、门禁、证人救援、撤离条件、静态批次预算，以及命中/受击反馈（血雾池复用、增亮覆盖材质共享、墙面尘土、爆头几何、击杀标记、受击弧/血晕/镜头下沉、抛壳、清理） |
| `verify_gameplay.gd` | **31** | 旧仓库玩法回归 |
| `verify_production_motion.gd` | **374** | 角色动作与控制器 |
| `verify_campaign.gd` | **87** | 第二章「堆场」与第三章「潮汐」完整推进、两张新图布局/批次/寻路落点、各阶段路线物理无阻、章节路由、`chapter` 字段与 `campaign.json` 进度校验（含磁盘写入/回读/损坏回退）、跨章检查点拒绝、尾声 |
| Python `unittest` | 18 | 字体许可/哈希、对白与录音对应、音效 PCM、glb 结构（含证人骨骼/动作）、资产审计哈希、GDScript 类型推断静态扫描、纹理 VRAM 压缩一致性 |

合计 691 项引擎检查（第四批前为 604，第三批前为 573）。`tools/project.py verify` 把非零退出、`SCRIPT ERROR:` 或任何引擎 `ERROR:` 行都算失败，
所以“检查全过但引擎报错”也会让 CI 变红（本轮确实因此抓到 Godot #85817 的材质释放报错并修复）。

## 2026-09-27 第四批：完整剧本 + 三章战役（本会话）

范围：先写完整剧本 `docs/STORY_SCRIPT_ZH.md`，再把第二章「堆场」、第三章「潮汐」做成可玩章节，最后统一推送。实现说明见 `docs/CAMPAIGN.md`。

- **重构不改第一章行为**：`operation.gd` 拆成通用基类 `chapter.gd` + 第一章表；重构后本地无头引擎五套件通过数与重构前完全一致
  （urban 71、session 95、chapter_zh 33、gameplay 31、motion 374，0 失败），护送/撤离/检查点/反馈检查全部原样通过。
- **新套件 `verify_campaign.gd` 87/87**（本地无头 4.6.3，源码编译、无渲染）。覆盖：三个场景的章节索引；两张新图 MultiMesh 批次 ≤16、
  两扇门登记、全部敌位/出生点/补给点落在可走格、目标点旁有可走格、首目标自出生点可达、每个阶段的网格路线在小腿/髋/眼三个高度射线无碰撞
  （规划网格与物理世界一致）、走廊边界判定、夜景灯光、文案与对白 id 齐全；
  第二章从闸口到出口闸的完整推进（清场前不可交互、门开后可达、箱门打开 + 箱内灯 + 门碰撞关闭、截获对讲只在中段巷道触发一次、
  结算解锁第三章、道闸放平、结算后不可射击）；同章检查点恢复（门态/箱态/击杀计数/补给标记）与拒绝第一章存档；
  `chapter` 字段与进度文件的接受/拒绝；进度不回退；隔离目录下 `campaign.json` 的写入/回读/完成标记/篡改回退备份/双损坏重置，
  以及带 `chapter` 的检查点磁盘往返；第三章从泊位闸门到控制沈国栋的完整推进、缺音频时的字幕回退分支（manifest 无待合成项时自动跳过）、
  `completed = true`、尾声文本、HUD 章节标签。
- **截图流程**：`capture_chapter.gd` 扩到 23 帧；无渲染冒烟（临时把 capture() 换成状态打印，脚本未入库）跑通 23 帧，
  各帧状态/阶段/敌人数符合预期。17–23 帧已由提交 `9a5f7e3` 的 CI（Xvfb + llvmpipe）产出并逐帧目视：
  第二章简报、开场过场（红色货车 + 夜间堆场）、闸口夜景、CN 20437 箱门打开 + 箱内灯、第三章岸吊与潮汐号、港务终端与船尾、
  尾声五行；中文全部正常渲染，HUD 章节标签/目标/威胁数正确。
- **对白**：新增 11 段文本与 11 段合成音频（`yard_*` 6 段、`pier_*` 5 段，`pier_hold` 在推送前补齐）；
  `scripts/build_dialogue_manifest.py` 生成对白 JSON 与 manifest（第一章 8 段文本与哈希未变）。
- **本地引擎注意**：本批的源码编译使用 `deprecated=no`，由此发现 `procedural_textures.gd` 用了已弃用的 `Image.create()`，
  已改为 `Image.create_empty()`（官方二进制两者都能跑，但以后不再依赖弃用 API）。
- **官方引擎 CI 已通过**：提交 `9a5f7e3`（Actions run 36314724658）ubuntu-latest 与 windows-latest 六套件
  87 / 95 / 33 / 71 / 31 / 374 全部 0 失败，与本地无头引擎通过数一致；Windows 官方模板导出 `SectorNine.exe`（131.0 MB）
  无头启动 exit 0、无脚本错误；23 帧 preview 全部产出。仍未做的是真人通关三章、核显帧率与声音听审。

## 2026-09-27 追加批次（本会话）

- **纹理导入统一**：全部 3D 贴图 `.import` 显式写入编辑器自动改写的终态（S3TC VRAM 压缩），
  打开编辑器/GLB 重导入不再产生改动；机制与核显收益评估见 `docs/TEXTURE_IMPORT.md`。
  提交 `ff2aeee` 在官方 4.6.3（Windows+Linux）CI 全套回归、Windows 导出冒烟、11 张 llvmpipe 截图验证通过。
- **HUD 可读性**：护送/证据/等候绿色状态行从固定槽位裸绘改为信息框下方深色面板（宽度按字宽自适应），
  居中通知加同款深色药丸底。CI llvmpipe 截图曾显示这些行压在阳光建筑上首字符几乎不可读；
  提交 `7da6028` CI 通过，且 `preview/09_escort` 截图确认三行完整可读。
- **美术细节**：第一人称枪械补全导轨桥/导气管/快慢机/拉机柄/独立扳机/前握把/腮垫缓冲垫/弹匣多部件
  （5948 三角面 <6000 预算；内嵌贴图像素 md5 未变，编辑器 `.import` 零改动）；
  街道六间店面、仓库钢货架与木托盘、两只侧放集装箱（均未侵入已验证护送路线/敌人路径窗口；
  批次染色语义修正了 vertex_color_use_as_albedo 白化旧件的风险）。提交 `e8043de`。
- **战术 AI**：丢失视线不再原地僵立——走向可达的最后目击点，无法接近时以扫视观察扇区后再回常态巡逻；
  记忆点仍不随猜测更新，伤害仍严格要求实际视线（wall-hack 不可能的既有约束不变）。

注意：`scripts/check_chinese_font.py` 会在任何 `.gd` 文案改动后报告过期哈希，
应先重跑它再跑 unittest（本批次曾两次按正确顺序重跑）。

## 2026-09-27 第三批：命中 / 受击反馈（arena/01a0e180-3d-shooter 会话）

用户需求：敌人被击中和自己被击中都要有特效，并顺手修掉与《使命召唤》手感差距中便宜的项。以下区分“自动测试已过”与“待人工验收”。

### 自动测试已覆盖（本地源码编译无头引擎 0 失败；`24ff141` 因工作区重建丢失、内容并入 `b929904`，官方引擎 CI 见 `9a5f7e3` run 36314724658：Windows + Linux 全绿）

| 需求 | 实现 | 自动检查 |
|---|---|---|
| A1 血雾 | `hit_effects.gd` 6 个一次性 GPUParticles3D 轮换，14 粒/次，初速沿弹道 | `feedback.blood_burst_pooled`、`kill.blood_reuses_pool`（子节点数恒为 54） |
| A2 敌人增亮 | 静态共享的加色 `material_overlay`，0.09 s 后清除，不复制 swat 材质 | `feedback.enemy_flash_overlay/_clears`、`feedback.flash_material_shared_not_duplicated` |
| A3 击杀确认 | 标记青→红并放大 0.42 s，`kill_confirm.wav`；爆头淡黄 + `headshot.wav` | `kill.confirmed_kind`、`kill.marker_and_counter`、`headshot.marker_and_counter` |
| A4 墙面/地面 | 尘土 + 火花粒子池、24 个弹孔贴片、12 个地面血迹贴片 | `feedback.wall_impact_effect`、`feedback.floor_splat_placed`、`feedback.clear_hides_decals` |
| A5 爆头 | 敌人局部 y ≥ 1.42 且离脊柱轴 < 0.17 m → 68 伤害（躯干 34） | `headshot.double_damage`、`headshot.shoulder_is_body_hit`（侧偏 0.2 m 为躯干） |
| B1 方向指示 | `damaged(health, amount, source)` 传来源；HUD 画 1.3 s 世界朝向弧，随转身旋转 | `hurt.directional_mark`、`hurt.cooldown_keeps_single_mark` |
| B2 镜头冲击 | 弹簧阻尼（k=260, c=19.4）脉冲，开火抬头、受击下沉侧滚，无持续抖动 | `feedback.shot_adds_camera_punch`、`hurt.camera_dip` |
| B3 血晕 | 峰值随伤害与剩余血量缩放，<30 血脉冲 + 屏幕脱色 + 心跳循环 | `hurt.vignette_scaled`、`hurt.low_health_state`、`hurt.low_health_recovers`（心跳音频无引擎检查） |
| B4 血溅 | 四张程序血斑随机贴在受击侧 | `hurt.vignette_scaled`（同时要求 splats 非空） |
| C | 抛壳（6 枚池）、一次性硝烟、三片火焰 + 点光、准星随后坐力/奔跑扩散、结算“爆头 N” | `feedback.casing_ejected`、`feedback.shot_adds_camera_punch`（硝烟/火焰/结算文案只靠截图与字体覆盖检查） |
| 存档 | 检查点 `headshots` 可选字段，缺省 0，需 ≤ hits；恢复后清空特效池与 HUD 反馈 | `checkpoint.*headshots*` 6 项、`checkpoint.feedback_cleared` |

爆头几何说明：敌人模型 1.69 m，头骨 1.455 m；玩家眼高 1.58 m，所以**水平平射**命中站立敌人上部时按构造就是爆头；
`verify_urban` 用 (1000,0,1000) 夹具分别验证平射 68、俯角 -0.14 rad 34、侧偏 0.2 m 34。这是命中区域规则，不是骨骼级 hitbox。

### 画面证据（`capture_chapter.gd`，16 帧）

新增 12–16 帧在第 0 阶段冻结敌人后，用 `advance()` 把游戏时钟以 0.05 倍速推进到固定时刻再近冻结（`FROZEN = 0.0001`），
所以软件渲染的帧耗时不影响粒子/标记的时相：

| 帧 | 内容 | 时刻 |
|---|---|---|
| 12_muzzle_flash | 朝混凝土路障射击：火焰三片 + 点光 + 硝烟 + 抛壳 + 准星扩散 | 击发后 0.03 s |
| 13_wall_impact | 同一发：尘土/火花 + 弹孔，火焰已熄 | 0.12 s |
| 14_hit_effects | 躯干命中 enemies[1]：血雾 + 敌人增亮 + 青色标记 | 0.065 s |
| 15_kill_confirm | 平射爆头击杀：红色大标记、血雾、可能的地面血迹 | 0.12 s |
| 16_player_hurt | 22 血时被左后方敌人打 10：受击弧、血晕、脱色、血溅、镜头下沉 | 0.05 s |

沙箱内无法渲染：这些帧只能由 CI 的 Xvfb + llvmpipe 产出，以 `preview/*` check-run 附在提交上。
提交 `9a5f7e3` 的 CI 已产出全部帧并逐帧查看：12 枪口焰与弹着尘土；13 同一发的尘土/火花与抛壳、火焰已熄；
14 曳光与敌人增亮可见（960×540 JPEG 里血雾与青色标记很小，需在游戏内确认）；15 红色击杀标记、头部血雾、敌人倒地、威胁数 03→02；
16 血量 12：整屏红晕 + 脱色 + 受击方向弧 + 血溅 + 镜头下沉。**待人工验收**：低血量红晕是否偏重需要调淡；血雾与标记的实际尺寸手感。

无渲染流程冒烟（临时把 capture() 换成状态打印）抓到的真问题：`Engine.time_scale = 0` 时 `move_and_slide()` 除以 0 → `get_real_velocity()` NaN →
枪械 bob NaN → 每物理帧刷 `instance_set_transform` 非有限 ERROR。已改为近冻结并在 `player.gd` 对非有限速度回退 0。

### 与《使命召唤》对照后仍未做（不是遗漏，是决定或超范围）

- 自动回血：会改变“检查点最低 60 生命”与补给的难度语义，需要用户拍板，本批故意未做。
- 空仓扣机声、冲刺后出枪延迟、敌人布娃娃、子弹呼啸/擦过声（现在敌人子弹全部命中，没有擦过弹道可播）。
- 手雷、新枪械、配件、连杀、载具、多人：明确超范围。

### 待人工验收

- 16 帧截图逐帧目视（尤其火焰朝向、血雾/尘土在软件渲染下是否可见、标记颜色、弧与晕影位置）；第四批新增的 17–23 帧同样待看
  （夜景是否过暗、堆场/码头文字牌可读性、打开的箱门与坐姿剪影、舷梯斜置与船体比例、尾声排版）。
- 第二、三章没有任何真人通关：敌位/掩体只经过无头几何与寻路检查，节奏、难度与可读性完全未评审。
- 真机上的镜头冲击幅度、抛壳/硝烟是否干扰视线、低血量脱色是否过重、心跳/命中音量平衡——这些参数没有经过任何人耳/人眼评审。
- 核显帧率：粒子池总量固定（血雾 6×14、尘土 6×12、火花 6×10、硝烟 5、抛壳 6），但没有实测。

## 导出与画面

- Windows 官方模板导出 `SectorNine.exe`（嵌入 pck，约 130 MB），CI 在 windows-latest 上无头启动冒烟，退出码 0、无脚本错误。
  附件名 `SilentHarbor-Windows-x64`。
- 画面截图：Linux Xvfb + Mesa llvmpipe 运行**兼容渲染器**的真实渲染（`capture_chapter.gd`，第三批起 16 张），
  以 `preview/*` check-run 形式附在每个提交上。它们是程序布置的镜头，不是人工通关录像；llvmpipe 是软件渲染，不代表核显帧率。

## 证人模型（陈默）

- `scripts/build_urban_witness.py` 用 Blender（bpy 4.5，无头）程序化生成：约 5,300 三角面，17 骨骼，自动权重，
  安全帽、反光背心、工牌、五官；动作 Captive（跪姿反绑）、Idle、Jog（与 3.1 m/s 护送速度匹配）、Plead。
- `scripts/audit_urban_assets.py` 逐帧采样四个动作：无非有限顶点；跪姿不穿地（审计曾抓到 4 cm 穿地并修正）。
- 游戏内：救援前跪姿，救援时 Plead，护送中 Jog/Idle（带迟滞防抖），停下时面向玩家。

## 未验证 / 不应声称

- 没有真人完整通关、核显/旧电脑帧率实测或 Windows 实机画面验收；自动测试使用传送、冻结 AI 和加速时间。
- 配音是 AI 合成、音效为程序合成；没有演员棚录、枪械外录或混音听审。
- 证人是风格化低多边形程序模型，没有面部骨骼、手指或布料模拟；过场没有口型同步。
- AI 不是完整战术规划系统，寻路依赖静态网格。
- 不是完整商业级游戏。
