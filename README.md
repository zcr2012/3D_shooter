# SWAT 战术射击 · Sector Nine（v09）

以战术射击为方向的 **Godot 4 单机原型与程序化资产工程**。v09 在 v08 角色上追加细节与网格清理，并加入可重复游玩的仓库遭遇战；不是商业写实成品。

**开始：** 用 Godot 4.6.3 导入 `godot_project/project.godot`，按 F5，点击 DEPLOY。
详见 [操作、Windows/Linux 工具链与已知限制](docs/PLAY.md) 和 [本轮实际验证记录](docs/VALIDATION.md)。

## v09 新增

- 四名敌人的巡逻、视线检测、预警、射击、受击与清除；清场后撤离、死亡失败、结算重开。
- 相机准星射线 + 枪口遮挡检查、血量、有限弹药、一次性补给、光迹/命中反馈及合成音效。
- 简报与结算界面、准星、雷达、任务状态、血量/弹药/换弹进度 HUD。
- v09 角色：头盔缝线/麦克风、面罩细节、护膝绑带、靴口与装备缝线；退化面清理。
- `tools/project.py` 统一 Windows/Linux 运行、验证、建模和 Windows 导出；默认 Compatibility 渲染。
- v08 交付目录和旧 `main.tscn` 验证场景保留不覆盖；实际游玩入口为 `mission.tscn`。

## 交付内容

| 类别 | 内容 |
| --- | --- |
| 角色 | 现代特警（头盔 / 面罩 / MOLLE 背心 / 织带 / 弹匣袋 / 电台 / 水袋 / 战术靴），22 骨骼可绑定骨架 |
| 武器 | AR 突击步枪（可分离弹匣、皮卡汀尼导轨、伸缩枪托、光学瞄准具） |
| 场景 | 室内战术环境（混凝土 / 瓷砖 / 金属 / 木质等 PBR 材质） |
| 动作 | 7 个分层动作：Idle、Aim、Fire、Reload、Walk、Run、HitReact，30fps 逐帧烘焙 |
| 材质 | 程序化 PBR 图集（BaseColor / ORM / Normal，8 图块） |

## 仓库结构

```
3D_shooter/
├── godot_project/           # Godot 4 验证工程（主入口）
│   ├── scenes/main.tscn
│   ├── scripts/             # player.gd 等运行时逻辑
│   └── tools/               # 回归验证 / 截图脚本
├── outputs/v09/             # 当前源工程、网格审计与实际检查渲染
├── tools/project.py         # 跨平台统一入口
├── tests/                   # Python 资产/工具完整性检查
├── docs/PLAY.md             # 操作、构建与验证边界
├── outputs/v08/             # 保留的原始资产交付
│   ├── swat_visual_v08.blend    # Blender 源工程
│   ├── texture_sources/         # PBR 贴图源文件
│   ├── godot_project/           # 隔离验证副本
│   ├── v08_*.png                # 渲染验证图
│   └── visual_audit.json        # 逐帧几何审计报告
└── scripts/                 # 程序化构建流水线（Blender 后台脚本）
```

## 运行方法

1. 安装 [Godot 4.x](https://godotengine.org/download)（本项目验证于 Godot 4.6）
2. 用 Godot 导入 `godot_project/project.godot`
3. 按 F5 运行任务场景 `scenes/mission.tscn`；`scenes/main.tscn` 仅作旧动作回归夹具。

操控：WASD 移动、鼠标转视角、右键瞄准、左键单发、R 换弹、Shift 跑动、E 补给、Space 物理跳跃、Esc 释放鼠标。

## 质量控制

- 旧动作套件：动作时长 / 循环接缝 / 16 组 WASD 位移 / 分层动作 / 弹药逻辑 / 鼠标捕获。另增 `verify_gameplay.gd` 玩法回归。本轮重新运行：旧套件 374/374、新玩法 31/31 通过；报告保存在 `outputs/v09/`。
- 逐帧网格审计：权重归一化误差 < 1e-7、无无效顶点、鞋底离地 < 3mm、刚性装备应变 < 0.3%
- v09 三角形总数：29,842（角色 21,776、步枪 7,090、弹匣 976）；具体统计见 `outputs/v09/visual_audit.json`。目标硬件性能尚未验收。

## 技术栈

- **Blender 5.x**（后台脚本化建模 / 绑定 / PBR / 渲染，见 `scripts/`）
- **Godot 4.6**（双层动画播放器、WASD 摄像机相对移动、鼠标捕获）
- **glTF 2.0 / GLB**（单骨架多动作导出）

## 已知限制

- 手指为握持姿态建模，未单独关节化
- 布料与装备壳体间的重叠穿插未自动校验
- 平地样本测试未覆盖斜坡 IK 与全部混合状态

## 许可

MIT License，见 [LICENSE](LICENSE)。
