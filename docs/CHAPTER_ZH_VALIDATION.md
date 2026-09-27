# 《寂静港口》实际验证记录 · 2026-09-27

以 GitHub Actions 上**官方 Godot 4.6.3**（ubuntu-latest 与 windows-latest）的真实运行为准；本地沙箱无法运行 Godot，
因此本页所有引擎结果都来自 CI，不来自旧报告。每次提交的逐项结果可在该提交的 check-runs / annotations 中查看。

| 套件 | 检查数 | 覆盖 |
|---|---|---|
| `verify_session.gd` | **88** | 暂停冻结、存档/恢复、坏存档回退到备份、补给一次性、重试资源下限、门碰撞与敌组阶段、H 等待/跟随、完整护送不卡住并撤离、证人骨骼动画状态 |
| `verify_chapter_zh.gd` | **33** | 中文字体与换行、8 段配音解码、字幕计时、过场、掩体/视野/听觉/换弹等战术 AI |
| `verify_urban.gd` | **47** | 城市首关流程、门禁、证人救援、撤离条件、静态批次预算 |
| `verify_gameplay.gd` | **31** | 旧仓库玩法回归 |
| `verify_production_motion.gd` | **374** | 角色动作与控制器 |
| Python `unittest` | 17 | 字体许可/哈希、对白与录音对应、音效 PCM、glb 结构（含证人骨骼/动作）、资产审计哈希、GDScript 类型推断静态扫描 |

合计 573 项引擎检查。`tools/project.py verify` 把非零退出、`SCRIPT ERROR:` 或任何引擎 `ERROR:` 行都算失败，
所以“检查全过但引擎报错”也会让 CI 变红（本轮确实因此抓到 Godot #85817 的材质释放报错并修复）。

## 导出与画面

- Windows 官方模板导出 `SectorNine.exe`（嵌入 pck，约 130 MB），CI 在 windows-latest 上无头启动冒烟，退出码 0、无脚本错误。
  附件名 `SilentHarbor-Windows-x64`。
- 画面截图：Linux Xvfb + Mesa llvmpipe 运行**兼容渲染器**的真实渲染（`capture_chapter.gd`，11 张），
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
