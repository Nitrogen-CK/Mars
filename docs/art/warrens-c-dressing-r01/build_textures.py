"""Deterministic code-native UV materials and exact glyphs. Does not alter generated art.
Run with bundled Python (numpy/Pillow). Albedo has no baked scene illumination.
"""
from pathlib import Path
import hashlib,json,math
import numpy as np
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parent
SIZE=1024;N=SIZE-1
v,u=np.mgrid[0:N,0:N].astype(np.float32)/N
TAU=math.tau
def rgb(value):return np.array([int(value[i:i+2],16) for i in (1,3,5)],dtype=np.float32)/255
def noise(seed=0):
    rng=np.random.default_rng(seed);out=np.zeros_like(u)
    for scale,weight in [(1,.45),(2,.28),(4,.17),(8,.10)]:
        for _ in range(2):
            a,b=rng.integers(-scale,scale+1,size=2)
            if a==b==0:a=1
            out+=weight*.5*np.sin(TAU*(a*u+b*v)+rng.uniform(0,TAU))
    return out
def smooth(a,b,x):
    t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
def wrap(a):return np.pad(a,((0,1),(0,1))+((0,0),)*(a.ndim-2),mode='wrap')
def pixels(a):return np.uint8(np.clip(a,0,1)*255+.5)
def write(path,array,mode=None):
    path=ROOT/path;path.parent.mkdir(parents=True,exist_ok=True)
    Image.fromarray(array,mode=mode).save(path)
def normals(height,tile):
    dx=(np.roll(height,-1,1)-np.roll(height,1,1))/(2*tile[0]/N)
    dy=(np.roll(height,-1,0)-np.roll(height,1,0))/(2*tile[1]/N)
    # PNG +Y is down; UV +V is up. OpenGL green is +dH/d(image Y).
    n=np.stack([-dx,dy,np.ones_like(dx)],axis=-1);n/=np.linalg.norm(n,axis=-1,keepdims=True)
    gl=pixels(wrap(n*.5+.5));n[...,1]*=-1;dxmap=pixels(wrap(n*.5+.5))
    return gl,dxmap
def pattern(spec,index):
    f=spec['family'];a=noise(index+31);b=noise(index+97)
    variation=a*.045;height=a*.04;cavity=np.zeros_like(a)
    if f in ('ashlar','flagstone','wetstone'):
        rows,columns=(6,4) if f=='ashlar' else (4,3)
        y=v*rows;row=np.floor(y).astype(int);x=u*columns+(row%2)*.5
        fx=x%1;fy=y%1
        edge=np.minimum(np.minimum(fx,1-fx),np.minimum(fy,1-fy))
        top=smooth(.022,.05,edge);cavity=1-top
        cell=((np.floor(x).astype(int)%columns)*37+(row%rows)*19+index*3)%13/12-.5
        variation=cell*.11+a*.035-cavity*.09
        height=top*.8+a*.015
    elif f=='plank':
        edge=np.minimum((u*4)%1,1-(u*4)%1);top=smooth(.013,.035,edge);cavity=1-top
        grain=np.sin(TAU*(13*u+.20*np.sin(TAU*v*2)))
        variation=a*.055+grain*.018-cavity*.11;height=top*.7+grain*.025
    elif f=='timber':
        grain=np.sin(TAU*(9*u+.18*np.sin(TAU*v)))
        variation=a*.045+grain*.012;height=grain*.04
    elif f=='rock':
        variation=np.round(a*5)/5*.035;height=a*.025
    elif f=='salt':
        variation=np.round(a*7)/7*.03;height=smooth(-.05,.3,b)*.15
    elif f=='cloth':
        weave=np.sin(TAU*u*32)*np.sin(TAU*v*32)
        variation=a*.035+weave*.004;height=weave*.03
    elif f=='rope':
        strand=np.sin(TAU*(6*u+2*v));variation=a*.04+strand*.025;height=strand*.08
    elif f in ('iron','brass','copper'):
        variation=a*.035;height=np.zeros_like(a)
    elif f in ('bone','paper','ceramic','wax'):
        variation=a*.025;height=a*.01
    elif f=='leather':variation=a*.05;height=a*.04
    elif f=='soot':variation=a*.018;height=np.zeros_like(a)
    rough=np.clip(spec['roughness']+a*.035,0,1)
    metal=np.full_like(a,spec['metallic'])
    color=rgb(spec['base_srgb_hex'])[None,None,:]*(1+variation[...,None])
    if f=='copper':
        patina=smooth(-.22,.12,a)
        # Keep patina quiet: a full brown/green breakup overpowers flat-shaded prop forms.
        color=rgb('#6b7c6b')[None,None,:]+(rgb('#938265')-rgb('#6b7c6b'))[None,None,:]*(1-patina[...,None])*.35
        # This is fully oxidized copper: the opaque oxide surface is dielectric.
        # Bare-metal islands caused camo-like reflection patches even with quiet albedo.
        metal=np.zeros_like(a);rough=.80+a*.025
    if f=='wetstone':color*=.96
    ao=1-cavity*.07
    orm=np.stack([ao,rough,metal],axis=-1)
    height=height*spec['relief_mm']/1000
    return np.clip(color,0,1),orm,height

def make_surfaces():
    materials=json.loads((ROOT/'materials.json').read_text())
    for i,s in enumerate(materials):
        color,orm,h=pattern(s,i)
        write(s['maps']['BaseColor'],pixels(wrap(color)))
        write(s['maps']['ORM'],pixels(wrap(orm)))
        gl,dx=normals(h,s['tile_metres'])
        write(s['maps']['NormalGL'],gl);write(s['maps']['NormalDX'],dx)
        # Height normalized to the declared relief range; zero relief is mid grey.
        height01=np.clip(h/max(s['relief_mm']/1000,1e-8)*.5+.5,0,1)
        write(s['maps']['Height'],np.uint16(wrap(height01)*65535+.5))
        print('SURFACE',s['id'],s['name'],flush=True)

def make_atlases():
    palette=json.loads((ROOT/'palette.json').read_text())
    p=np.zeros((256,512,3),np.uint8)
    for sw in palette:
        row,col=divmod(sw['index'],8);p[row*64:(row+1)*64,col*64:(col+1)*64]=pixels(rgb(sw['srgb_hex']))
    write('textures/atlases/AT01_Palette_BaseColor.png',p)
    materials={s['id']:s for s in json.loads((ROOT/'materials.json').read_text())}
    all_meta=[]
    for ident,title,ids in [('AT02','ArchitectureTrim',['TX01','TX03','TX08','TX09','TX10','TX06','TX17','TX19']),
                          ('AT03','PropTrim',['TX12','TX13','TX14','TX09','TX10','TX15','TX18','TX16'])]:
        arrays={name:np.zeros((1024,1024,3),np.uint8) for name in ['BaseColor','ORM','NormalGL','NormalDX']}
        height=np.full((1024,1024),32768,np.uint16);bands=[]
        for row,mid in enumerate(ids):
            spec=materials[mid]
            for name in arrays:
                with Image.open(ROOT/spec['maps'][name]) as im:source=np.asarray(im.convert('RGB'))
                # UV crop: real source samples, not a shrunken material chart.
                arrays[name][row*128:(row+1)*128]=source[row*97:row*97+128]
            bands.append({'row_from_top':row,'material':mid,'name':spec['name'],
                          'uv_min':[0,1-(row*128+120)/1024],'uv_max':[1,1-(row*128+8)/1024],
                          'v_center':1-(row*128+64)/1024,'gutter_pixels':8})
        maps={k:f'textures/atlases/{ident}_{title}_{k}.png' for k in arrays}
        for name,array in arrays.items():write(maps[name],array)
        maps['Height']=f'textures/atlases/{ident}_{title}_Height.png';write(maps['Height'],height)
        all_meta.append({'id':ident,'name':title,'repeat_u':True,'repeat_v':False,'resolution':[1024,1024],
                         'bands':bands,'maps':maps,'usage':'Place UVs inside one band; repeat U only. Never stretch UVs across band boundaries.'})
    (ROOT/'trim_metadata.json').write_text(json.dumps(all_meta,indent=2)+'\n')

def svg_icons():
    # Exact glyph and navigation geometry, authored as vectors and rasterized from the same shape descriptions.
    icons={
      'Glyph_Square':[('rect',(42,42,214,214))],
      'Glyph_Circle':[('ellipse',(32,32,224,224))],
      'Glyph_Triangle':[('polygon',[(128,28),(230,218),(26,218)])],
      'Glyph_Diamond':[('polygon',[(128,20),(236,128),(128,236),(20,128)])],
      'Glyph_Cross':[('rect',(101,29,155,227)),('rect',(29,101,227,155))],
      'Glyph_Bars':[('rect',(28,y,228,y+30)) for y in [47,113,179]],
      'Nav_Bell':[('polygon',[(74,166),(82,70),(102,48),(154,48),(174,70),(182,166),(207,184),(49,184)]),('ellipse',(111,183,145,214))],
      'Nav_Hoist':[('rect',(38,28,68,222)),('rect',(188,28,218,222)),('rect',(38,28,218,58)),('rect',(117,58,139,148)),('line',[(128,137),(128,171),(151,187),(174,171)],20)],
      'Nav_Vat':[('polygon',[(37,83),(219,83),(202,214),(54,214)]),('rect',(27,68,229,93)),('rect',(50,146,206,163))],
      'Nav_Pack':[('rect',(65,66,191,213)),('rect',(82,30,174,76)),('rect',(48,107,72,184)),('rect',(184,107,208,184)),('rect',(93,138,163,182))],
      'Nav_Lantern':[('rect',(74,64,182,216)),('rect',(65,56,191,81)),('rect',(65,199,191,222)),('ellipse',(99,17,157,77))],
      'Nav_Key':[('ellipse',(33,29,123,119)),('rect',(103,95,126,219)),('rect',(116,174,169,198))],
      'Nav_Ladder':[('rect',(64,24,87,232)),('rect',(169,24,192,232))]+[('rect',(79,y,177,y+18)) for y in [46,95,144,193]],
      'Nav_Crawl':[('rect',(25,182,231,205)),('rect',(46,68,69,184)),('rect',(187,68,210,184)),('rect',(46,57,210,83)),('ellipse',(100,117,130,147)),('rect',(122,143,174,164))],
      'Nav_ArrowRight':[('polygon',[(30,101),(151,101),(151,55),(232,128),(151,201),(151,155),(30,155)])],
      'Nav_ArrowLeft':[('polygon',[(226,101),(105,101),(105,55),(24,128),(105,201),(105,155),(226,155)])],
      'Nav_ArrowUp':[('polygon',[(101,226),(101,105),(55,105),(128,24),(201,105),(155,105),(155,226)])],
      'Nav_ArrowDown':[('polygon',[(101,30),(101,151),(55,151),(128,232),(201,151),(155,151),(155,30)])],
      'Nav_DropWarning':[('polygon',[(128,22),(238,222),(18,222)]),('rect_black',(115,87,141,153)),('ellipse_black',(115,174,141,200))],
      'Nav_CookPot':[('polygon',[(53,102),(203,102),(187,218),(69,218)]),('rect',(37,87,219,111)),('rect',(113,64,143,88)),('line',[(100,58),(90,42),(101,23)],12),('line',[(156,58),(146,42),(157,23)],12)]}
    atlas=Image.new('RGBA',(1024,2048),(255,255,255,0));metadata=[]
    for index,(name,shapes) in enumerate(icons.items()):
        image=Image.new('RGBA',(1024,1024),(255,255,255,0));draw=ImageDraw.Draw(image);sv=[]
        for item in shapes:
            kind,coords=item[:2];fill='#000000' if kind.endswith('_black') else '#ffffff';kind=kind.removesuffix('_black')
            scaled=[(x*4,y*4) for x,y in coords] if kind in ['polygon','line'] else tuple(x*4 for x in coords)
            if kind=='rect':
                draw.rectangle(scaled,fill=fill);x0,y0,x1,y1=coords;sv.append(f'<rect x="{x0}" y="{y0}" width="{x1-x0}" height="{y1-y0}" fill="{fill}"/>')
            elif kind=='ellipse':
                draw.ellipse(scaled,fill=fill);x0,y0,x1,y1=coords;sv.append(f'<ellipse cx="{(x0+x1)/2}" cy="{(y0+y1)/2}" rx="{(x1-x0)/2}" ry="{(y1-y0)/2}" fill="{fill}"/>')
            elif kind=='polygon':
                draw.polygon(scaled,fill=fill);sv.append('<polygon points="'+' '.join(f'{x},{y}' for x,y in coords)+f'" fill="{fill}"/>')
            else:
                draw.line(scaled,fill=fill,width=item[2]*4,joint='curve');sv.append('<polyline points="'+' '.join(f'{x},{y}' for x,y in coords)+f'" fill="none" stroke="{fill}" stroke-width="{item[2]}"/>')
        # White atlas shapes use alpha cutouts for black holes.
        arr=np.array(image);black=(arr[...,:3].max(-1)==0)&(arr[...,3]>0);arr[black,3]=0;arr[...,:3]=255
        image=Image.fromarray(arr).resize((256,256),Image.Resampling.LANCZOS)
        png=f'textures/decals/{name}.png';image.save(ROOT/png)
        (ROOT/'textures/decals'/f'{name}.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256"><defs><mask id="shape" maskUnits="userSpaceOnUse" x="0" y="0" width="256" height="256">'+''.join(sv)+'</mask></defs><rect width="256" height="256" fill="white" mask="url(#shape)"/></svg>',encoding='utf-8')
        col,row=index%4,index//4;atlas.alpha_composite(image,(col*256,row*256))
        metadata.append({'name':name,'png':png,'svg':f'textures/decals/{name}.svg','cell':[col,row],
                         'uv_min':[(col*256+20)/1024,1-(row*256+236)/2048],
                         'uv_max':[(col*256+236)/1024,1-(row*256+20)/2048],
                         'semantic':'runtime-authored lock glyph' if name.startswith('Glyph') else 'proposed navigation art; place only on a route that actually exists'})
    atlas.save(ROOT/'textures/atlases/AT04_GlyphAndNavigation_Alpha.png')
    (ROOT/'decal_metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')

def make_fx():
    h=(np.sin(TAU*(3*u+v))*.55+np.sin(TAU*(u-4*v))*.30+np.sin(TAU*(7*u+5*v))*.15)*.002
    gl,dx=normals(h,[4,4]);write('textures/fx/Water_NormalGL.png',gl);write('textures/fx/Water_NormalDX.png',dx)
    a=noise(901)*.5+.5;b=noise(902)*.5+.5
    packed=np.stack([a,b,smooth(.62,.82,a),np.ones_like(a)],-1)
    write('textures/fx/Water_NoiseFoam_RGBA.png',pixels(wrap(packed)))
    # Non-directional breakup masks. R slow noise, G second phase, B sparse foam, A white.
    for name,color,shape in [('Wear_DampLeak','#647a63','leak'),('Wear_SaltResidue','#e1d8b5','edge'),
                             ('Wear_SootFan','#333c34','fan'),('Wear_FlourScuff','#d3ceb8','scuff')]:
        x=(u-.5)*2;y=(v-.5)*2
        if shape=='leak':distance=np.sqrt((x*2)**2+(y*.72+.1)**2)
        elif shape=='edge':distance=np.abs(y+.35)*2.0+np.abs(x)*.25
        elif shape=='fan':distance=np.sqrt(x*x+(y*1.1-.25)**2)
        else:distance=np.sqrt((x*.7)**2+(y*2.8)**2)
        mask=(1-smooth(.35,.85,distance+noise(909)*.18))*.5
        mask*=1-smooth(.8,.98,np.maximum(np.abs(x),np.abs(y)))
        rgba=np.empty((N,N,4),np.float32);rgba[...,:3]=rgb(color);rgba[...,3]=mask
        # Non-tiling, soft localized decal. Alpha reaches zero before texture edges.
        write(f'textures/decals/{name}.png',np.pad(pixels(rgba),((0,1),(0,1),(0,0))))
    flame=Image.new('RGBA',(256,512),(0,0,0,0));d=ImageDraw.Draw(flame)
    d.polygon([(128,17),(152,122),(215,212),(194,365),(128,480),(58,365),(40,249),(91,165)],fill='#d87939')
    d.polygon([(133,144),(174,262),(151,416),(109,421),(85,306)],fill='#f4bc58')
    d.polygon([(129,269),(146,347),(128,432),(111,358)],fill='#ffe5a0')
    flame.save(ROOT/'textures/fx/FlameCard_RGBA.png')
    (ROOT/'fx_metadata.json').write_text(json.dumps({'water_tile_metres':4,'water_noise_channels':{'R':'slow breakup','G':'second periodic phase','B':'sparse foam mask','A':'white'},'water_flow':'No authored flow direction. Pan two normal samples in shader; do not infer traversability from texture.', 'flame':'Mesh/card only, proposed emissive material; no animated simulation or light tuning supplied.'},indent=2)+'\n')

def contact():
    mats=json.loads((ROOT/'materials.json').read_text())
    sheet=Image.new('RGB',(1600,5*245+75),'#252d26');d=ImageDraw.Draw(sheet)
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
    d.text((18,17),'WARRENS C / UNLIT MATERIAL BASE COLORS',font=font,fill='#efdfba')
    for i,s in enumerate(mats):
        x=i%4*400+10;y=i//4*245+65
        image=Image.open(ROOT/s['maps']['BaseColor']);image.thumbnail((380,200));sheet.paste(image,(x,y))
        d.text((x,y+204),s['id']+' '+s['name'],font=font,fill='#efdfba')
    sheet.save(ROOT/'qa/TEXTURE_CONTACT.jpg',quality=94)
    tiled=Image.new('RGB',(1200,1200),'#202820')
    for i,ident in enumerate(['TX01','TX02','TX07','TX12']):
        s=next(m for m in mats if m['id']==ident);im=Image.open(ROOT/s['maps']['BaseColor']).resize((300,300))
        x=i%2*600;y=i//2*600
        for dx in [0,300]:
            for dy in [0,300]:tiled.paste(im,(x+dx,y+dy))
    tiled.save(ROOT/'qa/TILING_2X2.jpg',quality=94)

if __name__=='__main__':
    make_surfaces();make_atlases();svg_icons();make_fx();contact()
    print('Technical texture generation complete.')
