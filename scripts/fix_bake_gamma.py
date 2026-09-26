"""Fix the double colour-space conversion on baked base-colour maps.
Bake writes LINEAR values; the image is tagged sRGB, so reading it applies
sRGB->linear again and darkens everything. Pre-encode to sRGB so the round
trip is identity.
"""
import bpy

def lin_to_srgb(c):
    if c <= 0.0031308:
        return c * 12.92
    return 1.055 * (c ** (1.0 / 2.4)) - 0.055

for name in ('SWAT_Operator_BaseColor', 'AR_AssaultRifle_BaseColor'):
    img = bpy.data.images.get(name)
    if not img:
        print('missing', name)
        continue
    px = list(img.pixels[:])
    n = len(px) // 4
    for i in range(n):
        j = i * 4
        px[j]     = lin_to_srgb(px[j])
        px[j + 1] = lin_to_srgb(px[j + 1])
        px[j + 2] = lin_to_srgb(px[j + 2])
    img.pixels[:] = px
    img.pack()
    avg = sum(px[0::4]) / n
    print('%s corrected, new avg=%.3f' % (name, avg))

bpy.ops.wm.save_mainfile()
print('SAVED')
