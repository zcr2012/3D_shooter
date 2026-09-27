# Godot 贴图导入统一为 VRAM 压缩（S3TC）说明

2026-09-27 · 提交见本文件所在提交

## 问题

在 Windows 上打开 Godot 编辑器后，GitHub Desktop 会出现大量 `.import` 改动
（`compress/mode=0`→`2`、`path`→`path.s3tc`、`.ctex`→`.s3tc.ctex`、`detect_3d/compress_to=1`→`0`）。

机制（Godot 源码 `editor/import/resource_importer_texture.cpp`）：

1. 纹理被 3D 场景使用后，`ResourceImporterTexture::update_imports()` 检测到 `detect_3d/compress_to=1`，
   自动改写 `.import`：`compress/mode=2`、`mipmaps/generate=true`、`detect_3d/compress_to=0`，然后重导入。
2. 被用作法线的贴图额外置 `compress/normal_map=1`（BC5/RGTC，红绿双通道存 XY，着色器重建 Z）。
3. 被用作 ORM 且材质带法线的贴图置 `roughness/mode=3`（G 通道）并记录 `roughness/src_normal`
   （仅影响 mipmap 粗糙度限幅，不改变外观）。
4. GLB 提取的伴生贴图（如 `swat_operator_*.png`、`fps_kit_*.png`）带有
   `generator_parameters.md5`（GLB 内嵌图像像素数据的 md5）。像素数据不变时编辑器直接跳过，
   不会重写（`modules/gltf/gltf_document.cpp` `_parse_image_save_image`）。

这些改写是**确定性的终态**，因此本提交把终态显式写入仓库：任何机器打开编辑器都会得到相同字节，
GitHub Desktop 不再出现改动。`scripts/unify_texture_imports.py` 可幂等重放该转换；
`tests/test_project.py::test_texture_imports_unified_vram` 防止回退。

`icon.svg.import` 是 2D/UI 贴图，编辑器不会自动改写，保持无损。音效 `.import` 的
`compress/mode=2` 是 QOA 音频编码，语义不同，不属于本约束。

## 对核显/旧电脑的好处评估

目标是核显和旧电脑（GL Compatibility 渲染器）。S3TC/DXT（`compress/high_quality=false`）：

- **显存**：DXT1=4 bpp、DXT5/BC5=8 bpp。项目贴图合计约 18.6 兆像素，
  未压缩（含 mipmap +33%）约 56–75 MB（RGB/RGBA），DXT 压缩后约 12–25 MB —— 省 3–4.5 倍。
  核显没有独立显存，占用即内存占用，省下的都是与系统共享的 RAM。
- **带宽**：核显最大瓶颈是内存带宽（无 GDDR）。纹理采样读取压缩块，
  有效带宽需求降 4–6 倍；同时纹理缓存以压缩块存储，等效缓存容量同样扩大。
- **兼容性**：S3TC 专利 2017 年到期，EXT_texture_compression_s3tc 与 RGTC（BC5）
  在 Intel/AMD/NVIDIA 所有支持 OpenGL 3.3 的驱动上原生可用；Mesa llvmpipe 软件渲染同样支持
  （CI 的 Linux 截图即此路径）。BPTC（high_quality）要求更高，故保持关闭。
- **加载**：导出包内嵌预压缩的 `.s3tc.ctex`，载入即上传，无运行时压缩开销。
- **附带质量收益**：`materials/` 下城市贴图原本 `mipmaps/generate=false`
  （三平面采样的路面/墙面/灰泥），本次随统一开启 mipmap，远景闪烁与锯齿明显改善。

代价：DXT 是有损块状压缩，大面积平滑渐变可能出现轻微块斑；本项目贴图均为
写实噪点纹理（沥青/混凝土/织物/装备），主观影响可忽略，CI 截图逐张复核。

## CI 验证

- `tools/project.py verify`：官方 Godot 4.6.3 全新导入（应用本提交的 `.import` 参数、
  生成 `.s3tc.ctex`），五套引擎回归全部通过，无 `SCRIPT ERROR`/`ERROR`。
- Linux Xvfb + Mesa llvmpipe 兼容渲染器 11 张实机截图（`preview/*` check-run）：
  街道（沥青/混凝土/灰泥）、角色（v08 图集法线+ORM）、敌人（contractor 图集）、
  仓库（tactical_room 全套 BC/RG）纹理渲染正常，与压缩前截图对比无外观退化。
- Windows 官方模板导出 + 无头冒烟通过（导出包现在携带 S3TC 压缩纹理）。
