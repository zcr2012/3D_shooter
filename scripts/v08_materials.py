"""Reproducible authored PBR atlases. No external/licensed image inputs."""
import bpy, numpy as np, math
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'outputs'/'v08'
TEX=OUT/'texture_sources'; TEX.mkdir(exist_ok=True)
# 8 swatches, each with local UV space; microsurface at restrained amplitude.
COLORS=[(.19,.235,.28),(.25,.275,.23),(.135,.155,.17),(.25,.265,.27),(.065,.07,.075),(.15,.165,.16),(.065,.14,.16),(.62,.65,.57)]
ROUGHS=[.82,.8,.52,.38,.87,.66,.16,.76]
METALS=[0,0,0,.92,0,0,.10,0]

def image(name,array,space):
    h,w,c=array.shape
    img=bpy.data.images.new(name,width=w,height=h,alpha=True)
    img.colorspace_settings.name=space
    rgba=np.ones((h,w,4),np.float32); rgba[:,:,:c]=array
    img.pixels.foreach_set(rgba.reshape(-1)); img.update()
    img.file_format='PNG'; img.filepath_raw=str(TEX/(name+'.png')); img.save(); img.pack()
    img.filepath_raw='//texture_sources/'+name+'.png'
    return img

def material():
    name='SWAT_v08_Atlas'
    N=1024; tilew=N//4; tileh=N//2
    yy,xx=np.mgrid[0:tileh,0:tilew]; rng=np.random.default_rng(8042)
    bc=np.zeros((N,N,3),np.float32); orm=np.zeros_like(bc); nm=np.zeros_like(bc)
    for t,base in enumerate(COLORS):
        noise=rng.normal(0,1,(tileh,tilew)).astype(np.float32)
        weave=.5*np.sin(xx*math.pi)+.5*np.sin(yy*math.pi*.5+xx*.3)
        coarse=(np.sin(xx*.027+np.sin(yy*.022))*np.cos(yy*.037))
        h=.5+.04*noise+.03*coarse
        amp=.024
        if t in [0,1]:
            h+=.09*weave; amp=.11
        elif t in [2,4,5]:
            h+=.04*np.sin(xx*.65)*np.sin(yy*.7); amp=.06
        elif t==3:
            h+=.012*np.sin(xx*.5); amp=.018
        else: amp=.003
        y0=(t//4)*tileh; x0=(t%4)*tilew
        col=np.array(base)[None,None,:]*(1+.10*coarse[:,:,None]+.075*noise[:,:,None])
        bc[y0:y0+tileh,x0:x0+tilew]=np.clip(col,0,1)
        # R=AO, G=roughness, B=metallic, valid glTF channel packing.
        orm[y0:y0+tileh,x0:x0+tilew,0]=1
        orm[y0:y0+tileh,x0:x0+tilew,1]=np.clip(ROUGHS[t]+.035*noise+.02*coarse,.03,.99)
        orm[y0:y0+tileh,x0:x0+tilew,2]=METALS[t]
        gy,gx=np.gradient(h)
        norm=np.stack((-gx*amp,-gy*amp,np.ones_like(h)),axis=-1)
        norm/=np.linalg.norm(norm,axis=-1,keepdims=True)
        nm[y0:y0+tileh,x0:x0+tilew]=norm*.5+.5
    # Blender float pixel arrays are scene-linear for sRGB images. Convert
    # palette sRGB values to linear before encoding, rather than double gamma.
    bc=np.where(bc<=.04045,bc/12.92,((bc+.055)/1.055)**2.4)
    imgs=[image(name+'_BaseColor',bc,'sRGB'),image(name+'_ORM',orm,'Non-Color'),image(name+'_Normal',nm,'Non-Color')]
    mat=bpy.data.materials.new(name); mat.use_nodes=True; nt=mat.node_tree
    bs=nt.nodes.get('Principled BSDF'); bs.inputs['Roughness'].default_value=.7
    for i,img in enumerate(imgs):
        node=nt.nodes.new('ShaderNodeTexImage'); node.image=img; node.interpolation='Linear'; node.location=(-600,-i*260)
        if i==0: nt.links.new(node.outputs['Color'],bs.inputs['Base Color'])
        elif i==1:
            sep=nt.nodes.new('ShaderNodeSeparateColor'); sep.mode='RGB'; nt.links.new(node.outputs['Color'],sep.inputs['Color'])
            nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']); nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
        else:
            normal=nt.nodes.new('ShaderNodeNormalMap'); normal.inputs['Strength'].default_value=.4
            nt.links.new(node.outputs['Color'],normal.inputs['Color']); nt.links.new(normal.outputs['Normal'],bs.inputs['Normal'])
    return mat
