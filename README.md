# Sector Nine · 寂静港口 / Silent Harbor

Godot 4 第一人称城市战术射击**开发切片**，使用原创 Blender 模型及许可明确的免费材质。当前制作一个可重复试玩的首关，**不是商业级成品或完整多章节战役**。

## 开始试玩

用 **Godot 4.6.3** 打开 `godot_project/project.godot`，等待资源导入，点击右上角 **▶**，再点击 **开始行动**。
笔记本可使用 **Fn + F5**。运行游戏不需要安装 Blender。

- [城市首关操作、剧情、流程与限制](docs/URBAN_CHAPTER.md)
- [本轮实际验证结果](docs/URBAN_VALIDATION.md)
- [Windows / Linux 工具链及导出说明](docs/PLAY.md)

## 最新中文叙事迭代

全中文界面与场景标识、内置中文字库、两位角色共 8 段合成配音、三个可跳过过场、行动记录，以及掩体/警戒 AI 和环境细节改进，见 [本轮说明](docs/CHAPTER_ZH.md)。配音按 F7 开关，空格跳过过场，按住 Tab 查看记录（不暂停）。本轮专项 **33/33**、城市 **47/47**、旧玩法 **31/31**、动作 **374/374**、Python **14/14** 通过；[验证记录](docs/CHAPTER_ZH_VALIDATION.md)。

## 城市首关基础内容

- 约 **92 × 140 米**地图边界，中央街区与可进入的仓库；两侧楼体主要是不可进入的背景建筑。
- 四段任务：**封锁线 → 切断中继 → 营救线人 → 护送撤离**，共 10 名敌人，按阶段激活。
- 原创停电调查剧情、位置触发电台字幕、目标方向/距离、一次性弹药和医疗补给。
- 第一人称独立手臂/枪械，ADS、后坐力、近墙压枪、换弹部件运动、Ctrl 蹲下及头顶站起检查。
- 敌人暖棕制服版本，沿用旧骨骼动作，新增横移和倒地动画；平民模型使用静态障碍网格寻路护送。
- Compatibility 渲染、静态建筑材质合批、512px 城市纹理，F6 可关闭太阳阴影。尚未获得核显实测帧率。

**操作：** WASD 移动，鼠标观察，左键单发，右键瞄准，R 换弹，Shift 冲刺，Ctrl 蹲下，Space 跳跃，E 交互，Enter 部署/重开。Esc 仅释放鼠标，**不暂停战斗**。

## 工程结构

```text
godot_project/
  scenes/urban_operation.tscn   # 当前默认首关
  scripts/urban/               # 城市、FPS、分阶段剧情、敌人、HUD
  assets/urban/                # 三个新 GLB 和贴图
  scenes/mission.tscn          # 保留的 v09 第三人称仓库关
  scenes/main.tscn             # 旧动作回归场景
  tools/verify_urban.gd        # 新关引擎测试
outputs/urban/                # Blender 源文件、模型预览、审计与测试报告
outputs/v09/                  # 保留的旧角色源文件和回归报告
outputs/v08/                  # 保留的原始交付
scripts/                     # Blender 生成、审计和预览脚本
third_party/polyhaven/        # CC0 原图、来源、固定镜像版本与哈希
tools/project.py             # 跨平台运行、验证、建模与 Windows 导出
```

## 验证与制作

设置 `GODOT_BIN` / `BLENDER_BIN`，或将程序放入 PATH。

```text
python tools/project.py run
python tools/project.py verify
python -m unittest discover -s tests -v
python tools/project.py model-urban
python tools/project.py audit-urban
python tools/project.py render-urban
python tools/project.py export-windows
```

重新生成模型需要 Blender 5.x，其 Python 环境须能导入 Pillow。Windows 导出还需要匹配版本的官方导出模板；本轮没有提供已验收的 exe。
旧 `model` / `audit` / `render` 命令仍用于 v09，不覆盖其历史源文件。

**上一轮基础结果：** 374 项旧动作回归、31 项旧玩法回归、47 项城市首关回归、9 项 Python 检查通过；两段新骨骼动画采样 60 帧。详情和验证边界见 [验证记录](docs/URBAN_VALIDATION.md)。

## 质量边界

美术仍偏简化。FPS 手臂和线人腿部采用刚性枢轴，尚无完整手指骨骼、动作捕捉、专业录音棚音效/配音、面部口型和完整表演、复杂战术规划、多章节战役或中途存档。未完成新关的 Windows 图形试玩、GPU 帧率、声音试听和全部穿插验收。

`outputs/urban/fps_preview.png` 是 Blender 离线模型预览，**不是 Godot 游戏截图**。旧版成功运行和自动化检查不等于新版已经达到商业发行质量。

## 许可

工程代码及程序化建模资产沿用 [MIT License](LICENSE)。新增外部布料贴图为 **Poly Haven CC0**，具体文件和处理记录见 [第三方资源说明](third_party/polyhaven/README.md)。中文字体为 SIL OFL 1.1，许可随字体分发；合成配音另记录来源，使用受生成服务条款约束。不包含《使命召唤》或其他商业游戏的模型、贴图、角色或剧情资产。
