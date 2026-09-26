import bpy, os

OUT = 'C:/Users/zhangshuai/WorkBuddy AI/3D_shooter/baked'
os.makedirs(OUT, exist_ok=True)

for name in ('SWAT_Operator_BAKE', 'AR_AssaultRifle_BAKE'):
    img = bpy.data.images.get(name)
    if not img:
        print('missing image:', name)
        continue
    px = list(img.pixels[:])
    n = len(px) // 4
    # sample stats
    rs = px[0::4]; gs = px[1::4]; bs = px[2::4]
    print('%s  %dx%d  R avg=%.4f max=%.4f | G avg=%.4f | B avg=%.4f' % (
        name, img.size[0], img.size[1],
        sum(rs)/n, max(rs), sum(gs)/n, sum(bs)/n))
    # count non-black pixels
    nonblack = sum(1 for i in range(n) if px[i*4] + px[i*4+1] + px[i*4+2] > 0.01)
    print('   non-black pixels: %d / %d (%.1f%%)' % (nonblack, n, 100.0*nonblack/n))
    img.filepath_raw = os.path.join(OUT, name + '.png')
    img.file_format = 'PNG'
    img.save()
    print('   saved ->', img.filepath_raw)
