# Sector Nine · v09 操作与跨平台工作流

这是一次小型纵向切片：保留 v08 原件，增量修整角色，新增四名敌人的仓库遭遇战。
不是完整商业 FPS，也未声称达到 Ready or Not 的美术或 AI 水平。

## Windows：直接游玩

1. 安装 **Godot 4.6.3 Standard**（非 .NET 版即可）。使用其他 4.6 版本可能可用，但测试版本固定为 4.6.3。
2. Godot 项目管理器导入 `godot_project/project.godot`，等待 GLB / 贴图首次导入。
3. 按 F6 只运行当前场景，**按 F5 运行整个项目**；默认进入 `scenes/mission.tscn`。
4. 点击 **DEPLOY** 或按 Enter 开始。

只运行游戏不需要 Blender 或 Python。界面目前使用英文，避免依赖 Windows / Linux 不一致的中文系统字体。

| 操作 | 按键 |
| --- | --- |
| 移动 / 跑动 | WASD / Shift |
| 转动视角 | 鼠标 |
| 瞄准（缩小 FOV） | 按住右键 |
| 单发射击 | 左键，每发有动作冷却 |
| 换弹 | R；动作结束才补弹，受击可打断 |
| 补给 | 接近出生区右侧箱子，按 E；一次性增加 60 备弹 |
| 跳跃 | Space（只有物理跳跃，暂无专用跳跃动画） |
| 释放 / 重新捕获鼠标 | Esc / 点击；重新捕获的第一下不会开火 |
| 开始 / 结算后重开 | Enter 或界面按钮 |

**目标：** 清除四个接触目标后，到仓库北侧绿色撤离区结束任务。
敌人发现玩家后有 1.4 秒警告，之后约每 1.8 秒开火一次；掩体阻断视线与命中。
每个敌人 100 生命，玩家单次身体命中 34 伤害。没有爆头倍率、敌人掉落或复活。
玩家 100 生命，敌人命中扣 12，连续伤害有 0.5 秒保护。
Esc 只是释放鼠标，**不是暂停**。右上角雷达会显示所有存活敌人，属于原型辅助而非拟真侦察。

## Windows：开发与导出

安装 Python 3.10+、Blender 5.x。可通过官方安装包安装，也可使用 winget：

```powershell
winget install --exact --id GodotEngine.Godot
winget install --exact --id BlenderFoundation.Blender
```

winget 默认安装当前版本，不保证是本项目测试版本；版本可用 `doctor` 检查。
路径没有加入 PATH 时，在 PowerShell 设置实际路径（不要包含额外的引号字符）：

```powershell
$env:GODOT_BIN = 'C:\Tools\Godot\Godot_v4.6.3-stable_win64.exe'
$env:BLENDER_BIN = 'C:\Program Files\Blender Foundation\Blender 5.0\blender.exe'
py tools/project.py doctor
py tools/project.py verify
py tools/project.py run
```

工具使用参数列表启动进程，不拼接 shell 命令，支持中文目录和路径中的空格。

导出 exe：先在 Godot 的 **Editor → Manage Export Templates** 安装与引擎版本相同的官方模板，然后：

```powershell
py tools/project.py export-windows
```

产物为 `build/windows/SectorNine.exe`（嵌入 PCK）。该目录已忽略，不会把导出文件或引擎缓存提交进仓库。
预设是 x86_64、Compatibility/OpenGL 3.3；比 Forward+ 更适合较旧显卡，但仍需要支持该图形 API。
**Linux 上的无头回归不等于 Windows exe 已经实机验收，也不等于目标电脑达到 60 FPS。**

## Linux：同一套工作流

安装相同版本的 Godot 与 Blender，然后设置可执行文件位置：

```bash
export GODOT_BIN=/path/to/Godot_v4.6.3-stable_linux.x86_64
export BLENDER_BIN=/path/to/blender
python3 tools/project.py doctor
python3 tools/project.py verify
python3 tools/project.py run
```

无头服务器可跑 `verify`；运行图形窗口还需要正常显示服务器与 GPU/软件图形驱动。
Blender 官方 `bpy` 模块也可用于后台建模，但它不是 Blender GUI 安装包，且仍依赖 Linux X11/OpenGL 动态库。
不要将当前沙箱的绝对路径复制到你的 Windows 工程中。

## 建模流水线（可重复）

```bash
python tools/project.py model    # 从已入库的 v08 .blend 生成 v09，不依赖缺失的 v07
python tools/project.py audit    # 359 帧变形网格采样、权重与预算检查
python tools/project.py render   # Cycles CPU 检查图，不修改交付场景照明
python tools/project.py verify   # Godot 首次导入 + 旧动作套件 + 新玩法套件
python -m unittest discover -s tests -v
```

- v08 原件：`outputs/v08/swat_visual_v08.blend`，保留不覆盖。
- v09 源工程：`outputs/v09/swat_visual_v09.blend`，压缩保存且贴图打包。
- 实际运行资产：`godot_project/assets/swat_operator.glb`，纹理内嵌，无外部绝对路径。
- 建模脚本：`scripts/polish_v09.py`；追加头盔缝线、麦克风、面罩细节、护膝绑带、靴口与装备缝线，微米级重复点合并及退化面清理。
- 检查图：`outputs/v09/v09_hero.png`，真实 Blender CPU 渲染，不是游戏截图。
- `scripts/` 中早期 `stance_*` / `bake_*` 等脚本保留为历史实验，含旧 Windows 路径；不属于上述可移植构建入口。
- v08 .blend 的文件版本标记来自更新的 Blender 构建；在本轮 5.0.1 读取时会出现版本警告，因此必须以导出动作和网格审计结果复核，不能仅凭“成功打开”判断兼容。

## 当前边界与后续优先级

1. 美术仍为程序化原型；增量细节修整不等于重新制作写实解剖、服装褶皱和高低模烘焙。
2. 敌人为明确的巡逻/发现/瞄准/射击状态逻辑，巡逻线路人工避开掩体；没有导航追击、侧翼、听觉或队伍协作。
3. 第三人称相机先确定准星目标，再验证枪口前的遮挡；尚无武器上半身俯仰 IK、移动瞄准专用侧步动画和逐指抓握。
4. 射击是即时射线 + 短时光迹、命中标记、合成音效，无实体弹道、穿透、后坐散布或联网。
5. 角色仍有开放细节边界，不适合直接用于 3D 打印；布料/装备互穿、斜坡 IK、全部动画混合姿态未自动认证。
6. 下一步优先：Windows 实机画面与输入验收 → 身体比例与面部/手部精修 → 蹲伏/侧移/转身动画 → 导航与掩体 AI → 性能分档与持续帧率测试。
