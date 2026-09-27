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
- `godot_project/scripts/urban/operation.gd`：剧情、过场、阶段流程、存档恢复、护送。
- `session_store.gd`：存档校验/磁盘读写（tmp/bak 原子替换）。
- `session_menu.gd`：暂停设置与失焦处理。
- `urban_hud.gd`：中文界面、字幕、检查点提示。
- `chapter_audio.gd`：配音/环境/音效与暂停。
- `city_map.gd`、`urban_enemy.gd`：地图、寻路、战术 AI。
- `godot_project/tools/verify_session.gd`：新暂停/存档/恢复/护送专项，需要运行、修复并增加边界覆盖。
- `verify_chapter_zh.gd`、`verify_urban.gd`、`verify_gameplay.gd`、`verify_production_motion.gd`：其他回归。
- `tools/project.py verify`：导入并运行以上五套；遇脚本错误/超时会失败，并向 GitHub annotations 写错误摘要。
- `.github/workflows/verify.yml`：Windows/Linux 官方引擎验证、Linux Xvfb/Mesa截图、Windows官方模板导出。
- `godot_project/tools/capture_chapter.gd`：简报/街道/暂停截图；它是程序布置场景截图，不是人工通关录像。
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
