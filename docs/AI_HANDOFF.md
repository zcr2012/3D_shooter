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

## 本次交接的实际状态
- 功能代码提交到 `d520f79`（之后的交接提交只增加说明文件）。用户明确要求将当前开发进度合并 main，供另一位 AI 接手。
- **当前有已知启动阻断，尚未完成交付验收。** Windows/Linux 官方 Godot 4.6.3 CI 都失败。
- 最新已检查 CI：https://github.com/zcr2012/3D_shooter/actions/runs/36291538199
- 两个平台的确切错误相同：
  `SCRIPT ERROR: Parse Error: Cannot infer the type of "path" variable because the value doesn't have a set type.`
  `res://scripts/urban/session_store.gd:118`
  导致 `operation.gd` 依赖编译失败，城市首关脚本无法加载。
- 优先把 `clear_checkpoint()` 内 `var path := directory+"checkpoint.json"+suffix` 改为显式 String（同时检查其他 Variant 推断），然后重新跑全套。此提示只是已定位问题，不意味着改一行就全部通过。
- 本地最新 Python 完整性测试 16 项通过；字体覆盖审计 423 个非 ASCII 字符，0 缺字。新存档/暂停专项尚未跑通。
- 较早基线结果：动作374、旧玩法31、城市47、中文33项通过。它们发生在新增暂停/存档代码之前，不能作为当前版本结果。
- Windows 试玩包与 Linux 实际渲染截图工作流已经写入，但最新 CI 在导入阶段失败，后续导出/截图被跳过。**没有可声称已成功交付的最新包或截图。**

## 已有实现
- 中文 HUD/剧情/场景标识，内置 Noto Sans CJK 与 OFL/来源。
- 8 段中文合成对白（女指挥员、男证人），7 种程序音效，分离的对白/效果轨；音频与 manifest 已在 assets/audio，无需重新生成。
- 三段程序运镜过场，可跳过；没有完整口型动画。
- 城市建筑/仓库、第一人称枪械手臂、敌人与证人；几何细节与批量静态绘制，美术仍需真实画面评审。
- AI 视野/声音/队友警戒、掩体占用、换弹、友军射线阻挡、阻塞释放。
- 新增（未通过完整引擎回归）：Esc 真正暂停 SceneTree/声音，失焦暂停，设置界面；阶段入口检查点、C继续、死亡重试；设置/存档 JSON 验证、tmp/bak替换。
- 检查点重试重建玩家/本阶段敌人，保留已用补给与弹匣；最低60生命、30备弹，避免缺弹卡关。不是任意时刻快速存档。
- 护送新增 H 等待/跟随、靠近障碍的目标点修正与路径起点剪裁。需要验证实际护送不卡住。

## 重点文件
- `godot_project/scripts/urban/operation.gd`：剧情、过场、阶段流程、存档恢复、护送。
- `session_store.gd`：存档校验/磁盘读写（当前解析错误在这里）。
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
