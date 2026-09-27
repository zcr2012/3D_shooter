#!/usr/bin/env python3
"""统一 godot_project 内贴图 .import 为 VRAM 压缩 (compress/mode=2, S3TC)。

背景：Godot 编辑器的 ResourceImporterTexture::update_imports() 会检测 3D 用法，
自动改写 .import（受 detect_3d/compress_to=1 控制），在 GitHub Desktop 中产生反复改动。
这些改动是确定性的：compress/mode=0→2、mipmaps/generate→true、detect_3d/compress_to→0；
法线贴图 compress/normal_map=0→1；带法线的 ORM 贴图 roughness/mode→3 (G 通道) 并记录 src_normal。
GLB 提取的伴生贴图有 generator_parameters.md5（GLB 内图像像素数据的 md5），
像素不变时编辑器跳过重写，因此提交后任何机器打开编辑器都会落回相同字节，不再产生改动。

本脚本把上述终态显式写入仓库（幂等；重复运行无 diff）。图标等 2D/UI 贴图不处理：
icon.svg.import 保持 compress/mode=0（编辑器不会自动改写，UI 用途也不需要 VRAM 压缩）。
音效 .import 的 compress/mode=2 含义不同（QOA），不属于本脚本范围。
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / 'godot_project/assets'

# (路径, 法线槽, ORM 关联法线路径) —— 依据 glTF 材质与运行时代码的角色归类。
# ORM/arm = glTF metallicRoughness（roughness 恒在 G 通道 → roughness/mode=3 "Green"）。
NORMAL = 'normal'
PLAIN = 'plain'

TARGETS = {
    'swat_operator_SWAT_v08_Atlas_BaseColor.png': PLAIN,
    'swat_operator_SWAT_v08_Atlas_Normal.png': NORMAL,
    'swat_operator_SWAT_v08_Atlas_ORM.png': ('orm', 'res://assets/swat_operator_SWAT_v08_Atlas_Normal.png'),
    'urban/contractor_SWAT_v08_Atlas_Normal.png': NORMAL,
    'urban/contractor_SWAT_v08_Atlas_ORM.png': ('orm', 'res://assets/urban/contractor_SWAT_v08_Atlas_Normal.png'),
    'urban/contractor_contractor_atlas.png': PLAIN,
    'urban/fps_kit_sleeve_albedo.png': PLAIN,
    'urban/fps_kit_sleeve_normal.png': NORMAL,
    'urban/fps_kit_sleeve_arm.png': ('orm', 'res://assets/urban/fps_kit_sleeve_normal.png'),
    'urban/materials/asphalt.png': PLAIN,
    'urban/materials/concrete.png': PLAIN,
    'urban/materials/plaster.png': PLAIN,
    'urban/materials/contractor_atlas.png': PLAIN,
    'urban/materials/sleeve_albedo.png': PLAIN,
    'urban/materials/sleeve_arm.png': PLAIN,
    'urban/materials/sleeve_normal.png': NORMAL,  # operation.gd 证人服装 normal_texture
}


def convert(rel, role):
    path = ASSETS / (rel + '.import')
    text = path.read_text(encoding='utf-8')
    if 'compress/mode=2' in text and 'path.s3tc=' in text:
        return False  # 幂等：已转换
    assert 'compress/mode=0' in text, f'{rel} 不是预期的无损格式'
    assert 'detect_3d/compress_to=' in text, f'{rel} 缺少 detect_3d 选项'

    # [remap]：path → path.s3tc，目标文件名 .ctex → .s3tc.ctex，metadata 标记 VRAM
    text = text.replace('path="res://.godot/imported/', 'path.s3tc="res://.godot/imported/', 1)
    text = re.sub(r'(?<!s3tc)\.ctex"', '.s3tc.ctex"', text)
    assert 'path.s3tc=' in text and '\npath="' not in text, f'{rel} 目标路径替换失败'
    old_meta = 'metadata={\n"vram_texture": false\n}'
    new_meta = 'metadata={\n"imported_formats": ["s3tc_bptc"],\n"vram_texture": true\n}'
    assert old_meta in text, f'{rel} metadata 不符合预期'
    text = text.replace(old_meta, new_meta, 1)

    # [params]：VRAM 压缩 + mipmap + 关闭 3D 自动检测（编辑器 update_imports 的稳定终态）
    text = text.replace('compress/mode=0', 'compress/mode=2', 1)
    text = text.replace('mipmaps/generate=false', 'mipmaps/generate=true', 1)
    assert re.search(r'(?m)^detect_3d/compress_to=1$', text), f'{rel} detect_3d 值异常'
    text = text.replace('detect_3d/compress_to=1', 'detect_3d/compress_to=0', 1)
    if role == NORMAL:
        assert 'compress/normal_map=0' in text, f'{rel} normal_map 已有设置'
        text = text.replace('compress/normal_map=0', 'compress/normal_map=1', 1)
    elif isinstance(role, tuple) and role[0] == 'orm':
        assert 'roughness/mode=0' in text and 'roughness/src_normal=""' in text, f'{rel} roughness 已有设置'
        text = text.replace('roughness/mode=0', 'roughness/mode=3', 1)
        text = text.replace('roughness/src_normal=""', f'roughness/src_normal="{role[1]}"', 1)
    path.write_text(text, encoding='utf-8')
    return True


def main():
    changed = []
    for rel, role in TARGETS.items():
        if convert(rel, role):
            changed.append(rel)
    print(f'转换 {len(changed)} 个 .import（其余 {len(TARGETS) - len(changed)} 个已是 VRAM 压缩）')
    for rel in changed:
        print('  +', rel)
    return 0


if __name__ == '__main__':
    sys.exit(main())
