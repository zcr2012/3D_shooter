# SWAT 战术射击 · 3D 角色与动作包（v08）

Ready or Not 写实战术风格的 3D 特警战术射击资产包。包含可绑定特警角色、突击步枪、室内战术场景与完整动作集，面向 Windows 中低端 PC 的 Godot 4 项目交付。

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
├── outputs/v08/             # 最新版资产交付
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
3. 运行主场景 `scenes/main.tscn`

操控：WASD 移动（方向跟随摄像机朝向）、鼠标瞄准、左键射击、R 换弹、Shift 跑动。

## 质量控制

- 374 项无头回归（动作时长 / 循环接缝 / 16 向 WSD 位移 / 分层动作 / 弹匣逻辑 / 鼠标捕获）
- 逐帧网格审计：权重归一化误差 < 1e-7、无无效顶点、鞋底离地 < 3mm、刚性装备应变 < 0.3%
- 三角形预算：角色 ≈ 20k、步枪 ≈ 7k、弹匣 ≈ 1k，适配中低端集显

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
