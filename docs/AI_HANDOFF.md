# 给下一位 AI 的交接提示词

请接手 GitHub 仓库 `zcr2012/3D_shooter`，先读本文件、README、`docs/CHAPTER_ZH.md`、`docs/CHAPTER_ZH_VALIDATION.md`、`docs/WINDOWS_PLAYTEST.md` 和最新 CI，再继续开发。以实际文件及最新运行结果为准，不要把旧测试报告视为当前版本通过。

## 用户目标与约束
- 用户在 Windows 上用 GitHub Desktop 更新项目；希望继续自主推进，不必每个小步骤询问。
- 已收敛范围：优先做好原创第一人称现代城市反恐首关《寂静港口》，适配核显和旧电脑，不是立即制作完整 AAA 游戏。
- 游戏内文字全部中文；中文字体随项目分发，不能依赖系统字体。
- 持续完善建筑/人物美术、建模贴图、玩家/敌人动作、战术 AI、剧情、配音音效和过场。
- 可以用 Blender 和授权允许商用的免费素材；保留来源与许可。不要复制《使命召唤》的受保护素材。
- 不能将合成配音/程序音效说成专业演员棚录，不能以无头测试代替画面、听审或用户硬件帧率验收。
- 用户曾对较早 Windows 试玩版反馈良好，但没有验收最新暂停/存档版本。

## 2026-09-27 第二批交接（arena/01a0e133-3d-shooter 会话追加）

本地已提交顺序：`ff2aeee` 纹理统一 → `7da6028` HUD 面板 → `e8043de` 枪械/店面/仓库陈设 → 战术 AI 搜索移动 + 文档（见下）。
- `ff2aeee`、`7da6028` 的 GitHub Actions（win+linux 五套回归、导出、11 张 preview 截图）在提交时确认为全绿。
- `e8043de` 与随后的 AI 批次：推送/查询过程中沙箱 GitHub token 失效（~05:50），
  **下一位接手时第一步就是查看这些提交的 CI 与 preview 截图**，重点核对：
  ① 枪械新部件朝向/尺寸；② 六间店面与集装箱外观及 batch 预算检查（`city.static_batch_budget` ≤16）；
  ③ verify_session 护送全程仍不卡（新钢货架为实体障碍，托盘与店面纯视觉）；④ 敌人 search 扫视没有新报错。
  若 `static_batch_budget` 超支，可把 wood 并入调色板既有键或合并门店材质。
- 本沙箱 GH token 失效后只能用 api.github.com 之外无凭据；重新连接后 `git push origin arena/01a0e133-3d-shooter` 即可（本地提交见 git log）。
- Blender 环境：`/tmp/blendenv`(bpy 4.5.0) + `/tmp/stubs` 空桩 .so + `LD_LIBRARY_PATH=/tmp/stubs`，`/tmp/blender_loader.py <script>` 运行；
  换环境后需重建。fps_kit 内嵌贴图 md5 == .import generator_parameters（已用 RGB 像素 md5 验证），可以放心改几何不动贴图。
- 仍未做：真人 Windows 试玩验收、配音听审、更多剧情/过场/配音扩展（配音生成管线见 build_chapter_audio.py，注意是否需要联网 TTS）。

## 2026-09-27 第三批交接（arena/01a0e180-3d-shooter 会话：命中/受击反馈）

用户原话：“敌人被击中和我被击中都能有特效，并且对比和使命召唤还有不同的一并修复。” 范围是命中反馈包 + 射击手感，
不含连杀、配件、载具、多人；不得声称“已达使命召唤水准”或“商业级”。

- 本地提交 `24ff141`（实现）及其后的文档/两项低血量检查提交；推送时沙箱 GitHub token 再次失效，
  **接手第一步：`git push origin <本会话分支>`，看 CI（win+linux）与 16 张 preview 截图，再把结果写回 `docs/CHAPTER_ZH_VALIDATION.md`**。
  重点核对 `preview/12_muzzle_flash`（三片火焰朝向/尺寸）、`13_wall_impact`（尘土 + 弹孔）、`14_hit_effects`（血雾 + 敌人增亮）、
  `15_kill_confirm`（红色击杀标记、爆头计数）、`16_player_hurt`（左后方受击弧 + 血晕 + 低血量脱色）。
- 本批次在沙箱内用 Godot 4.6.3 **源码编译的无头引擎**（无 Vulkan/GL，只能跑脚本）实际运行了五套回归：
  session 95、chapter_zh 33、urban 71、gameplay 31、production motion 374，全部 0 失败；无法在沙箱渲染截图。
  用同一引擎把 `capture_chapter.gd` 的 16 帧流程无渲染跑通（临时替换 capture() 为状态打印，脚本未入库），
  由此抓到并修复一个 NaN：`Engine.time_scale = 0` 时 `move_and_slide()` 用 0 除位移，`get_real_velocity()` 变 NaN，
  枪械 bob 随之 NaN 并刷屏 `instance_set_transform` ERROR。修法是 capture 用 `FROZEN = 0.0001` 近冻结，且 `player.gd` 对非有限速度回退 0。
- 编译方法（约 53 分钟，-j2）：codeload.github.com 下载 `godot-4.6.3-stable` 源码，`scons platform=linuxbsd target=editor
  vulkan=no opengl3=no use_llvm=no` 并关闭大部分模块，另需 pkg-config 空桩；产物在 `~/.cache/godot-build/`（不持久，换环境要重编）。
  它报 `ERROR: Godot was compiled without fontconfig`，所以不能直接用 `tools/project.py verify`（会把该行算失败），要逐套 `--headless --script` 运行。
- 信号/接口变化：`player.take_damage(amount, source := Vector3.INF)`、`damaged(health, amount, source)`、
  新增 `bullet_impact(where, normal, direction, kind, headshot)`，kind ∈ miss/world/hit/kill/dead；敌人传 `global_position + UP*1.4`。
  `mission.gd`/`operation.gd` 都已改连接；`verify_gameplay.gd` 的位置参数调用仍兼容。
- 新文件：`scripts/game/hit_effects.gd`（血雾/尘土/火花/弹孔/地面血迹对象池，固定 54 个子节点，不占 MultiMesh 批次）、
  `scripts/game/procedural_textures.gd`（软圆盘/星形/血斑/晕影程序贴图）；`enemy.gd` 用 `material_overlay` 做增亮，不复制共享材质。
- 存档：检查点新增可选 `headshots`（缺省 0，需 ≤ hits），旧存档仍有效；`verify_session` 覆盖接受/拒绝/回退。
- 音效：`scripts/build_chapter_audio.py` 新增 hit_confirm/kill_confirm/headshot/flesh_impact/bullet_impact/heartbeat 六个程序合成 wav
  （幂等，manifest 13 项）；仍是程序合成，不是录音。
- 与《使命召唤》对照后**已做**：命中/爆头/击杀三色标记与音效、血雾+墙面尘土火花+弹孔+地面血迹、敌人受击增亮、
  受击方向弧、开火/受击弹簧式镜头冲击、按血量缩放的血晕 + 低血量脉冲/脱色/心跳、血溅覆盖层、三片枪口焰+点光+一次性硝烟+抛壳、
  动态准星扩散、结算界面爆头数、冲刺持枪姿态与转向枪械滞后、罗盘指针方向修正。
  **未做**（需要用户决定或超范围）：自动回血（会改变检查点最低生命与难度语义，故意没做）、空仓扣机声、冲刺后出枪延迟、
  敌人布娃娃、子弹呼啸声（敌人子弹全部命中，无擦过弹道）、手雷/新枪械/配件/连杀。
- 验证语义：Tactical AI 不变量测试一项未改（last_seen 只随目视更新、`_plan_to` 距离/横向限制、卡住>1.2s 转搜索、穿墙零伤害）。

## 2026-09-27 第四批交接（arena/01a0e180-3d-shooter 会话：完整剧本 + 三章战役）

用户原话：“你先设计出完整的剧本，然后把游戏先做完，最后统一一起推送。” 做法：先写 `docs/STORY_SCRIPT_ZH.md`
（三章 + 尾声，权威文本），再把第二、三章做成可玩章节，最后一次性推送（沙箱 GitHub 凭据失效时未推送，见 git log）。

- 结构：`scripts/urban/chapter.gd` 是章节基类（从原 `operation.gd` 抽出），`operation.gd` 只剩第一章的表和护送逻辑；
  `chapter2.gd`/`yard_map.gd`、`chapter3.gd`/`pier_map.gd`、`campaign.gd`（路由 + `pending_restore`）、
  `scenes/yard_operation.tscn`、`scenes/pier_operation.tscn`。实现说明见 `docs/CAMPAIGN.md`。
- `city_map.gd`：`_ready()` = 环境 → `build()` → 合批 → 寻路；子类重写 `build()` 与 `_init()` 里的天空/环境光/太阳参数；
  新增 `gates` 列表、`set_gate_open()`、`inside_corridor()`、`block_rotated()`、`solid_box()`、`lamp_post()`。
  `urban_enemy._plan_to` 用 `city.inside_corridor()`，AI 不变量未变。
- 存档：`checkpoint.json` 可选 `chapter`（缺省 1）；新增 `campaign.json` 进度（`unlocked`/`completed`）。
  `restore_checkpoint()` 拒绝他章存档，`continue_checkpoint()` 会经 `Campaign.open_chapter(tree, chapter, true)` 跳章后恢复。
  HUD/回车：结算按回车 `next_chapter()`；第三章结算显示 `epilogue` 五行。
- 对白：`scripts/build_dialogue_manifest.py` 是 19 段对白与 manifest 的唯一来源；三种 AI 合成声音（voice-00/01/02）。
  **`pier_hold.mp3` 尚未合成**（本会话单轮生成上限），manifest 标 `pending-synthesis`，游戏按字数计时显示字幕。
  下一步：用 voice-00 合成该句（文本见剧本第三章阶段 1）、重跑 manifest 脚本、引擎 `--editor --import` 生成 `.import`。
- 验证：新增 `tools/verify_campaign.gd`（已加入 `tools/project.py` SUITES 与 CI 产物）；`capture_chapter.gd` 扩到 23 帧
  （CI grep 已改为 `CAPTURE: 23 frames`）。第一章五套件在重构后应保持原通过数（urban 71 / session 95 / chapter_zh 33 /
  gameplay 31 / motion 374）；本地无头引擎结果记录在 `docs/CHAPTER_ZH_VALIDATION.md`。
- 未做/待人工：真人通关三章；新章节截图目视（17–23 帧）；沈国栋无模型（只声音）；第二、三章敌人沿用承包商模型；
  尾声没有滚动字幕动画（静态五行）。

## 本次交接的实际状态（2026-09-27 更新）
- 分支 `arena/01a0e0e4-3d-shooter` 已修复原 CI 阻断（`session_store.gd:118` 类型推断），并继续修复后续暴露的问题。
- 最新 CI（官方 Godot 4.6.3，Windows + Linux）五套引擎回归共 573 项检查通过：session 88、chapter_zh 33、urban 47、
  gameplay 31、production motion 374；Python 17 项通过；Windows 导出包无头冒烟启动通过；11 张兼容渲染器真实截图以 `preview/*` check-run 附在提交上。
  以你接手时该分支最新提交的 CI 为准，不要只信本段文字。
- 详细覆盖与限制见 `docs/CHAPTER_ZH_VALIDATION.md`。
- 证人陈默已替换为 Blender 程序化生成的蒙皮角色（17 骨骼，4 个动作），见 `scripts/build_urban_witness.py`。

## 工具提示（沙箱内无法下载 Godot 时）
- PyPI `bpy==4.5.0` 可在 venv 中无头运行 Blender 脚本；若缺 X11/GL 系统库，可用空桩 `.so` 并以
  `sys.setdlopenflags(os.RTLD_LAZY|os.RTLD_GLOBAL)` 导入。EEVEE 不可用，预览用 Cycles CPU。
  用 `runpy.run_path('scripts/xxx.py', run_name='__main__')` 运行（脚本依赖 `__file__`）。
- 修改证人后依次运行 `build_urban_witness.py`、`audit_urban_assets.py`（更新 `outputs/urban/asset_audit.json` 哈希），再跑 unittest。
- Godot 4.6 对 `var x := 未声明类型成员...` 报解析错误；`tests/test_project.py` 有静态扫描，但不能替代真实引擎。
- 截图：`gh api repos/<repo>/check-runs/<id> --jq '.output.summary + .output.text' | tr -d ' \n' | base64 -d > x.jpg`。

## 已有实现
- 中文 HUD/剧情/场景标识，内置 Noto Sans CJK 与 OFL/来源。
- 8 段中文合成对白（女指挥员、男证人），7 种程序音效，分离的对白/效果轨；音频与 manifest 已在 assets/audio，无需重新生成。
- 三段程序运镜过场，可跳过；没有完整口型动画。
- 城市建筑/仓库、第一人称枪械手臂、敌人与证人；几何细节与批量静态绘制，美术仍需真实画面评审。
- AI 视野/声音/队友警戒、掩体占用、换弹、友军射线阻挡、阻塞释放。
- 已通过引擎回归：Esc 真正暂停 SceneTree/声音，失焦暂停，设置界面；阶段入口检查点、C继续、死亡重试；设置/存档 JSON 验证、tmp/bak替换。
- 检查点重试重建玩家/本阶段敌人，保留已用补给与弹匣；最低60生命、30备弹，避免缺弹卡关。不是任意时刻快速存档。
- 护送新增 H 等待/跟随、靠近障碍的目标点修正与路径起点剪裁。CI 中完整护送路线已验证不卡住并成功撤离；仍需真人游玩验收。

## 重点文件
- `godot_project/scripts/urban/chapter.gd`：章节基类（阶段流程、过场、电台、补给、检查点、结算、章节路由）。
- `operation.gd`（第一章 + 护送）、`chapter2.gd`/`yard_map.gd`（堆场）、`chapter3.gd`/`pier_map.gd`（码头）、`campaign.gd`。
- `session_store.gd`：存档校验/磁盘读写（tmp/bak 原子替换）。
- `session_menu.gd`：暂停设置与失焦处理。
- `urban_hud.gd`：中文界面、字幕、检查点提示。
- `chapter_audio.gd`：配音/环境/音效与暂停。
- `city_map.gd`、`urban_enemy.gd`：地图、寻路、战术 AI。
- `scripts/game/hit_effects.gd`、`procedural_textures.gd`、`fps_player.gd`、`game/hud.gd`：命中/受击特效池、程序贴图、枪口焰/抛壳/镜头冲击、受击弧/血晕/血溅。
- `godot_project/tools/verify_session.gd`：新暂停/存档/恢复/护送专项，需要运行、修复并增加边界覆盖。
- `verify_chapter_zh.gd`、`verify_urban.gd`、`verify_gameplay.gd`、`verify_production_motion.gd`：其他回归。
- `tools/project.py verify`：导入并运行以上五套；遇脚本错误/超时会失败，并向 GitHub annotations 写错误摘要。
- `.github/workflows/verify.yml`：Windows/Linux 官方引擎验证、Linux Xvfb/Mesa截图、Windows官方模板导出。
- `godot_project/tools/verify_campaign.gd`：第二、三章推进、地图布局、进度/章节存档规则。
- `godot_project/tools/capture_chapter.gd`：简报/街道/暂停 + 命中特效 + 第二、三章共 23 帧截图；它是程序布置场景截图（特效帧用 `advance()` 慢放到固定游戏时刻），不是人工通关录像。
- `scripts/check_chinese_font.py`：fonttools 字库覆盖及源文件哈希报告生成。修改脚本文案后重跑，否则完整性测试会报告旧哈希。

## 推荐执行顺序
1. 修复已知 GDScript 解析错误，继续处理实际 CI 暴露的问题。
2. 跑 `python -m unittest discover -s tests -v`；安装官方 Godot 4.6.3，设置 GODOT_BIN，再跑 `python tools/project.py verify`。
3. 验证暂停确实冻结战斗、换弹、过场和声音；关闭菜单不误开火；场景清理不遗留暂停。
4. 验证所有阶段保存/重新启动恢复/死亡重试、门碰撞/当前敌组、坏存档/备份回退、补给不重复、证人与证据撤离条件。检查原子替换失败时保留有效备份的健壮性。
5. 真实跑通护送，验证 H、拐角、仓库门与玩家走出寻路范围时的行为。
6. 确认 Windows 包导出完成，查看实际截图，检查中文 UI/字号/菜单布局，再做手动游玩与声音听审；不要只看 CI 绿色。
7. 更新验证文档，清楚区分旧结果、新自动测试、实机结果和仍待验收项。后续继续提升首关美术/动作/剧情，而不是宣布商业级已经完成。

## 环境提醒
- 前一个 Arena 工作区重建时 Git HEAD 有时回到初始4fde857，但工作文件已恢复成较新版本；先比较远端树，不要把它们当成要删除的陌生文件或强推覆盖远端。
- 原工作会话固定在 `arena/01a0ddfc-3d-shooter`；新的会话遵守自己平台的分支约束。
- 本地旧 `.tools` 引擎/Blender 缓存没有持久化，不要假设存在。
- 沙箱可能无法下载 GitHub Actions Azure blob 日志/附件。可用 `gh api repos/zcr2012/3D_shooter/commits/<sha>/check-runs` 查 ID，再读取 `check-runs/<id>/annotations` 查看脚本错误摘要。
- 不要索要 GitHub 密码或 token。不要伪造成功测试、导出包、截图、性能或素材授权。
