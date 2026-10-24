"""Deterministic, source-fitted whole-level visual assembly; no world mutations."""
import copy,importlib.util,json,math
from collections import Counter
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OUT=HERE/'Output'
BASE=OUT/'Reports/full_source_baseline.json'

def module(name,path):
    s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m

def build():
    source=json.loads((ROOT/'Tools/LevelDesign/anchor_plans/data/warrens_v8c.json').read_text())
    baseline=json.loads(BASE.read_text());pivots={k:v['pivot'] for k,v in baseline.items()}
    surface=module('whole_level_source_surfaces',HERE.parent/'PumpCisternKit/surface_fitting.py')
    specs={k:dict(baseline_path=BASE,pivot=v) for k,v in pivots.items()}
    raw_boxes=surface.load_boxes(specs)
    boxes=copy.deepcopy(raw_boxes)
    for bs in boxes.values():
        for b in bs:
            if b['label']=='Warrens_Greybox_gallery' and min(b['size'][:2])>.11 and b['size'][2]<=.5:
                b['label']='Warrens_Greybox_floor'
    surface.load_boxes=lambda unused=None:boxes
    shell=surface.build(specs);rows=shell['placements']
    for r in rows:
        if r['id']=='BACKING':r['id']='BACKING_'+r['material']
        # Retained source ceilings are flat structural soffits. Repeating a
        # compressed groin vault on every raster cell reads as folded panels.
        # Flip the broad stone top-contact slab against the source underside;
        # its thickness points into the retained solid, leaving 12mm projection.
        if r['id']=='CCS18' and r['role']=='source ceiling underside':
            r.update(id='CCS13',material='TX01',rotation=[180,0,0])
            r['at'][2]+=.146;r['scale'][2]=1
    assets={}
    for kit in ['ChainCrossingKit','PumpCisternKit','WarrensVariantCKit']:
        assets.update({a['id']:a for a in json.loads((HERE.parent/kit/'Output/asset_manifest.json').read_text())['assets']})
    visibility=[];lights=[];overrides=[];contacts=[];bay_audit=[]
    # Retain the already-reviewed waterworks and crossing prop assemblies, but
    # replace all former partial structural extraction with this complete pass.
    for kit in ['ChainCrossingKit','PumpCisternKit']:
        data=json.loads((HERE.parent/kit/'Output/fitted_instances.json').read_text())
        for r in data['placements']:
            role=r['role'].lower()
            if r['id'].startswith('BACKING') or r['id']=='SOURCE_GALLERY' or any(w in role for w in ['veneer','seam backing','source floor','source wall','source ceiling','source ramp','gallery','rail infill','rail post','rail cap','preserved upper']):continue
            rows.append(dict(r))
        lights.extend(data.get('lights',data.get('crossing_lights',[])))
        overrides.extend(data.get('light_overrides',[]))
        visibility.extend(v for v in data.get('visibility_overrides',[]) if v['label']!='Warrens_Greybox_gallery')
    def add(tile,ident,at,scale=(1,1,1),yaw=0,role='prop',rotation=None,**kw):
        row=dict(tile=tile,id=ident,at=list(at),scale=list(scale),yaw=yaw,role=role,collision='NoCollision',**kw)
        if rotation is not None:row['rotation']=list(rotation)
        rows.append(row);return row
    def floors(tile,x,y,z,tolerance=.6):
        return [b for b in boxes[tile] if b['label']=='Warrens_Greybox_floor' and surface.contains(b,x,y) and abs(b['hi'][2]-z)<tolerance]
    def grounded(tile,ident,x,y,z,scale=(1,1,1),yaw=0,role='supported prop'):
        fs=floors(tile,x,y,z)
        if not fs:return None
        f=min(fs,key=lambda b:abs(b['hi'][2]-z));row=add(tile,ident,(x,y,f['hi'][2]+.008),scale,yaw,role)
        contacts.append(dict(tile=tile,id=ident,source=f['key'],floor=f['hi'][2],at=row['at']))
        return row
    # The inherited Sluice diagonals ended beside the posts rather than on them.
    # Seat the post backs on the actual Y22 wall, join each brace's low end to
    # its post, and carry the high ends on a shared header (3m above the floor).
    brace_sockets=assets['CCS87']['flags']['sockets_m'];embed=.04
    post_side_depth=assets['CCS86']['bounds_max_cm'][2]/100
    for r in rows:
        if r['tile']!='Brineworks' or r['at'][0] not in [116,120,124,128]:continue
        if r['id']=='CCS86' and abs(r['at'][1]-21.75)<.001:
            r['at'][1]=21.85;r['role']='Sluice wall-backed upright'
        if r['id']=='CCS87' and abs(r['at'][1]-21.65)<.001:
            post_x=r['at'][0];right=post_x<128
            x=post_x-brace_sockets['post_end'][0]-embed if right else post_x-post_side_depth+brace_sockets['post_end'][0]+embed
            r['at']=[x,21.85,.5-brace_sockets['header_end'][2]+embed]
            r['yaw']=0 if right else 180;r['role']='Sluice post-to-header brace'
    header_min=116-post_side_depth;header_max=128
    add('Brineworks','CCS86',((header_min+header_max)/2,21.85,.5),((header_max-header_min)/(assets['CCS86']['actual_dimensions_cm'][0]/100),1,1),role='Sluice supported continuous timber header')
    for r in json.loads((HERE/'arch_candidates.json').read_text())['candidates']:
        add(r['tile'],r['mesh_id'],r['at'],r.get('scale',(1,1,1)),r['yaw'],'source-supported unlocked entrance arch',source_candidate_id=r['id'])
    # Every authored gallery has the same contact/thickness policy, including
    # the upper Hub and Catacomb galleries outside the previous partial scope.
    gallery_count=0
    for tile,bs in raw_boxes.items():
        galleries=[b for b in bs if b['label']=='Warrens_Greybox_gallery']
        if galleries:visibility.append(dict(tile=tile,label='Warrens_Greybox_gallery',visible=False))
        for b in galleries:
            x,y,z=b['at'];w,d,h=b['size'];along_x=w>=d;length=max(w,d);n=max(1,math.ceil(length/2));step=length/n;yaw=0 if along_x else 90
            if min(w,d)>.11 and h<=.5:
                add(tile,'SOURCE_CUBE_TX02',b['at'],b['size'],role='retained gallery walking deck',rotation=b['rotation'],material='TX02')
                gallery_count+=1;continue
            bottom=z-h/2;near=[f for f in bs if f['label']=='Warrens_Greybox_floor' and surface.contains(f,x,y) and 0<=bottom-f['hi'][2]<.3]
            if near:bottom=max(f['hi'][2] for f in near)
            top=z+h/2;bone=tile=='Ossuary' or tile=='Canal' and 65<x<82 and 70<y<78 and z>2
            for j in range(n):
                xx=x+(-length/2+(j+.5)*step if along_x else 0);yy=y+(-length/2+(j+.5)*step if not along_x else 0)
                add(tile,'WVC008' if bone else 'CCS11',(xx,yy,top-.12 if bone else bottom),(step/2,min(w,d)/(.35 if bone else .12),.12/.35 if bone else (top-bottom)/.8),yaw,'fitted source gallery infill')
            for j in range(n+1):
                xx=x+(-length/2+j*step if along_x else 0);yy=y+(-length/2+j*step if not along_x else 0)
                ident='WVC007' if bone else 'CCS09';th=min(min(w,d),.16)
                add(tile,ident,(xx,yy,bottom),(th/(.5 if bone else .3),th/(.5 if bone else .3),(top-bottom)/(1.1 if bone else 1)) ,role='fitted source gallery post')
            gallery_count+=1
    # Lantern feet rest on the four existing ivory post caps. Above-rail flames
    # light the deck instead of casting the continuous infill's shadow across it.
    for y in [72.5,75.5]:
        posts=sorted([r for r in rows if r['tile']=='Canal' and r['id']=='WVC007' and abs(r['at'][1]-y)<.001],key=lambda r:r['at'][0])
        assert len(posts)>=2
        for post in [posts[0],posts[-1]]:
            x=post['at'][0];top=post['at'][2]+post['scale'][2]*assets['WVC007']['actual_dimensions_cm'][2]/100
            for ident,at,scale in [('CCS60',(x,y,top),(.5,.5,.5)),('CCS61',(x,y,top+.04),(.5,.5,.5)),('CCS64',(x,y,top+.06),(.225,.225,.25))]:
                add('Canal',ident,at,scale,0,'Bone Bridge post-cap supported practical')
            contacts.append(dict(tile='Canal',id='CCS60',source='fitted ivory post',at=[x,y,top],post_at=post['at'],contact_gap_m=0))
            lights.append(dict(tile='Canal',at=[x,y,top+.15],intensity=28,radius=600))
    # Existing north-facing bridgehead masonry ends at Y70, top4.6m.
    for ident,at,scale in [('CCS62',(60.5,70.02,4.3935),(1,1,1)),('CCS60',(60.5,70.14,4),(1,1,1)),('CCS61',(60.5,70.14,4.08),(1,1,1)),('CCS64',(60.5,70.14,4.12),(.45,.45,.5))]:
        add('Ossuary',ident,at,scale,0,'source wall9 bridgehead practical')
    lights.append(dict(tile='Ossuary',at=[60.5,70.24,4.25],intensity=25,radius=600))
    # The hearth is fixed environmental furniture, not another cooking control.
    add('Hub','WVC065',(16,50,.008),(1.4,1.4,1),role='authored arrival hearth brazier')
    add('Hub','CCS64',(16,50,.82),(1.4,1.4,.8),role='hearth flame')
    visibility.append(dict(tile='Hub',label='Warrens_Greybox_hearth',visible=False))
    # Original candles are source-positioned anchors; replace each full proxy.
    for tile,bs in boxes.items():
        candles=[b for b in bs if b['label']=='Warrens_Greybox_candle']
        for b in candles:
            x,y,z=b['at'];base=z-b['size'][2]/2
            add(tile,'WVC064',(x,y,base),role='authored tallow holder')
            for dx in [-.1,0,.1]:add(tile,'CCS64',(x+dx,y,base+.4),(.18,.18,.18),role='tallow wick flame')
            lights.append(dict(tile=tile,at=[x,y,base+.45],intensity=5,radius=380))
        if candles:visibility.append(dict(tile=tile,label='Warrens_Greybox_candle',visible=False))
    # Whole source tree, same 1.4x1.4x14m occupied envelope, rooted on Pit floor.
    add('Pit','PWC14',(35,46,-5),(.7,1.4,5.6),role='source Well root landmark')
    visibility.append(dict(tile='Pit',label='Warrens_Greybox_root',visible=False))
    # Main writes source-specific hero assemblies after independent family review.
    prop_file=HERE/'prop_assemblies.json'
    if prop_file.exists():
        data=json.loads(prop_file.read_text());new=data if isinstance(data,list) else data['placements']
        # Proposals overlap reviewed candles/pump/root and several chime parts
        # were unsupported. Accept only independently fitted static groups.
        for r in new:
            index=r['source_prop_index']
            if index not in (3,6,7,9,15,23,24,25):continue
            if index==23 and r['id']!='WVC037':continue
            if index in (6,7) and r['id']=='WVC052':r['at'][2]=3.6305
            if index==9 and r['id']=='WVC026':r['scale'][2]=5/6
            if index==9 and r['id']=='WVC081':r['at'][2]=3.5
            rows.append(dict(r))
    # Static hero assemblies replace whole source proxies; all runtime control
    # nodes remain present. Hoist optional cage stays in library only.
    add('Hub','WVC013',(40,55.5,0),role='source hoist open frame')
    # North feet bear on the narrow authored rim. Two bracketed cantilevers
    # support the south feet over the shaft; no new platform or Pit-floor post.
    for x in [39.408,40.592]:
        add('Hub','CCS86',(x,55.6,-.35),(1,.75,1),yaw=90,role='rim-anchored hoist cantilever bearer')
        add('Hub','CCS73',(x,56.2,.008),(.3,.45,.35),role='hoist rim bearer anchor plate')
    def socket(ident,key):return assets[ident]['flags']['sockets_m'][key]
    def plus(a,b):return [a[k]+b[k] for k in range(3)]
    pulley=plus([40,55.5,0],socket('WVC013','pulley_axle'))
    drum=plus([40,55.5,0],socket('WVC013','drum_axle'))
    add('Hub','WVC014',pulley,role='hoist supported upper pulley')
    add('Hub','WVC015',drum,role='hoist supported lower drum')
    for center,width in [(pulley,.8),(drum,.8)]:
        add('Hub','PWC03',center,(.4,.4,width/.8),rotation=[0,0,90],role='hoist bearing shaft')
    # A chain run joins the drum tangent to the pulley and hangs through the
    # clear central load space. The terminal hook is attached by its real eye.
    chain_x=40.33
    for i in range(max(1,int((pulley[2]-drum[2]-.35)/.08)+1)):
        z=drum[2]+.35+i*.08
        add('Hub','CCS27',(chain_x,55.5,z),(.5,.5,.5),rotation=[90,0,0] if i%2 else [0,0,90],role='hoist vertical load chain')
    eye=socket('WVC016','suspension_eye');hook_at=[chain_x-eye[0],55.5-eye[1],drum[2]+.35-eye[2]]
    add('Hub','WVC016',hook_at,role='hoist terminal hook')
    # A visible practical is attached to the north-left timber, lighting the
    # load space without adding a camera-relative fill or changing exposure.
    for ident,at,scale in [('CCS62',(39.408,55.96,2.4935),(1,1,1)),('CCS60',(39.408,55.84,2.1),(1,1,1)),('CCS61',(39.408,55.84,2.18),(1,1,1)),('CCS64',(39.408,55.84,2.22),(.45,.45,.5))]:add('Hub',ident,at,scale,180,'hoist timber-mounted practical')
    lights.append(dict(tile='Hub',at=[39.408,55.6,2.35],intensity=30,radius=650))
    add('Hub','WVC044',(10,47.5,0),role='existing camp pack plinth skin')
    visibility.extend([dict(tile='Hub',label='Warrens_Greybox_prop',visible=False),dict(tile='Court',label='Warrens_Greybox_prop',visible=False),dict(tile='Ossuary',label='Warrens_Greybox_prop',visible=False),dict(tile='Reliquary',label='Warrens_Greybox_prop',visible=False),dict(tile='Mill',label='Warrens_Greybox_prop',visible=False),dict(tile='Catacomb',label='Warrens_Greybox_prop',visible=False),dict(tile='Brineworks',label='Warrens_Greybox_prop',visible=False)])
    # Source envelope4x4x22m. Four segmented corner piers carry two open crown
    # modules. The bell mouth is near+14.5, crown+17.25, matching the +16 view.
    for x in [102.3,105.7]:
        for y in [48.3,51.7]:
            for z in [0,2.8,5.6,8.4,11.2]:add('Belfry','CCS06',(x,y,z),(.5,.5,2.8/3),role='bell tower corner pier course')
    for z in [14,18]:add('Belfry','WVC018',(104,50,z),role='bell tower open crown')
    yoke=plus([104,50,14],socket('WVC018','yoke_axle'))
    add('Belfry','WVC020',yoke,role='supported bell yoke')
    crown=plus(yoke,socket('WVC020','bell_attachment'));bell=[crown[k]-socket('WVC019','crown_attachment')[k] for k in range(3)]
    add('Belfry','WVC019',bell,role='source high landmark hollow bell')
    hinge=plus(bell,socket('WVC019','clapper_hinge'));clapper=[hinge[k]-socket('WVC021','hinge_center')[k] for k in range(3)]
    add('Belfry','WVC021',clapper,role='bell clapper socket assembly')
    # Exterior cool illumination enters the open crown; the retained point
    # inside the cavity is dimmed separately to prevent a white bell mouth.
    lights.append(dict(tile='Belfry',at=[100,46,18],intensity=120,radius=1000,color=[.55,.72,1]))
    add('Belfry','WVC028',(104,60,2.5),role='existing Red key plinth skin')
    # Backing panels keep the source clue and dial presentation envelopes.
    # They carry no invented marks or answers and do not duplicate a control.
    for at,scale in [([102,50,3],[.3,4,2]),([108,46,.7],[1,.4,1.4])]:add('Belfry','SOURCE_CUBE_TX01',at,scale,role='retained clue housing envelope',material='TX01')
    # Chimes hang from one crossbeam carried by two floor-standing posts.
    for x in [95.05,100.95]:
        for i in range(math.ceil((24-3.5)/.08)+1):
            z=3.5+min(i*.08,20.5)
            add('Belfry','CCS27',(x,54,z),(.5,.5,.5),rotation=[90,0,0] if i%2 else [0,0,90],role='roof-supported chime frame suspension')
    add('Belfry','CCS86',(98,54,3.4),(3,.65,.3),role='bone chime support beam')
    for i,x in enumerate([96,97,98,99,100]):
        top=3.35;bone_z=2.15+(i%2)*.2
        for j in range(max(1,int((top-bone_z-.4)/.08)+1)):add('Belfry','CCS27',(x,54,top-j*.08),(.5,.5,.5),rotation=[90,0,0] if j%2 else [0,0,90],role='chime suspension chain')
        add('Belfry','WVC082',(x,54,bone_z),rotation=[90,0,0],role='hanging blunt bone chime')
    visibility.append(dict(tile='Belfry',label='Warrens_Greybox_prop',visible=False))
    for x in [14.4,15.6]:
        if grounded('Court','WVC064',x,87.35,0,role='Mourner plinth votive'):
            for dx in [-.1,0,.1]:add('Court','CCS64',(x+dx,87.35,.408),(.18,.18,.18),role='Mourner votive flame')
            lights.append(dict(tile='Court',at=[x,87.35,.5],intensity=12,radius=450))
    # Mill chute terminates into the open vat; no decorative lid over gameplay.
    add('Mill','WVC024',(88,105.2,6.25),(.8,.8,.8),yaw=180,role='vat delivery chute')
    add('Mill','WVC027',(88,106,6.27),role='recessed curing vat liquid')
    # Royal/service emblems are layered above opaque support boards; a masked
    # crest never replaces the entire board or fabric material.
    for tile,at,key,yaw in [('Hub',(39.4,56.23,1.25),'ART01',0),('Ossuary',(54,68.31,3.7),'ART04',0),('Mill',(88,106.82,5.4),'ART06',0)]:
        add(tile,'CCS78',at,(1.1,1,1),yaw,'opaque service notice backing')
        off=surface.rotate([0,.021,0],[0,yaw,0]);front=[at[k]+off[k] for k in range(3)]
        add(tile,'WVC083',front,(1,1,1),yaw,'painted service emblem',material=key)
    # Physical controls, glyphs, ladders and doors remain their working runtime
    # actors. Never add a frozen HISM leaf, decorative dial or invented handwheel.
    ports=[p['at'] for t in source['instances'] for p in t.get('ports',[])]
    controls=[p.get('at',p.get('pos')) for p in source['props']]
    controls=[p for p in controls if p]
    solid=[b for bs in boxes.values() for b in bs if b['label'] in ['Warrens_Greybox_wall','Warrens_Greybox_roof','Warrens_Greybox_floor'] and all(abs(r)<.001 for r in b['rotation'])]
    def blocked(x,y,z):return any(surface.contains(b,x,y,z) for b in solid)
    # Room identities are expressed at closed wall bays, never automatic floor scatter.
    room_tiles={r:('WaterworksW' if z['id']=='Waterworks-W' else z['id']) for z in json.loads((ROOT/'docs/art/warrens-c-dressing-r01/room_dressing.json').read_text()) for r in z['rooms']}
    palette={'Hub':['CCS67','CCS71','WVC048'],'Court':['CCS44','WVC067','WVC070'],'Ossuary':['WVC053','WVC052','WVC071'],'WaterworksW':['PWC21','CCS75','CCS71'],'Pit':['CCS44','WVC067','CCS50'],'Canal':['CCS71','CCS67','CCS77'],'Belfry':['CCS71','WVC077','WVC080'],'Reliquary':['WVC053','WVC054','WVC060'],'Mill':['CCS68','WVC050','WVC056'],'Catacomb':['WVC053','WVC052','WVC071'],'Brineworks':['CCS66','CCS68','WVC048']}
    def inside_room(room,x,y):
        if 'rect' in room:a,b,c,d=room['rect'];return a<x<c and b<y<d
        poly=room['poly'];inside=False;j=len(poly)-1
        for i,a in enumerate(poly):
            b=poly[j]
            if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:inside=not inside
            j=i
        return inside
    for room in source['rooms']:
        tile=room_tiles[room['id']];z=room['z'];candidates=[]
        for wall in boxes[tile]:
            if wall['label']!='Warrens_Greybox_wall' or any(abs(r)>.001 for r in wall['rotation']):continue
            if not wall['lo'][2]<z+1.8<wall['hi'][2]:continue
            for axis,sign,yaw in [(1,-1,180),(1,1,0),(0,-1,90),(0,1,-90)]:
                # normal points from the source solid toward room free space.
                n=[0,0];n[axis]=sign;at=wall['at'][:2];at[axis]=wall['lo'][axis] if sign<0 else wall['hi'][axis]
                px,py=at[0]+n[0]*.5,at[1]+n[1]*.5
                if not inside_room(room,px,py) or blocked(px,py,z+1.2) or not floors(tile,px,py,z):continue
                if any(math.hypot(px-p[0],py-p[1])<3 and abs(z-p[2])<2 for p in ports+controls):continue
                # A usable closed bay must be at least1.2m wide along its wall.
                if wall['size'][1-axis]<1.2:continue
                candidates.append((at,n,yaw))
        chosen=[];pending=sorted(candidates,key=lambda c:(c[0][0],c[0][1]))
        while pending:
            index=max(range(len(pending)),key=lambda i:min(math.dist(pending[i][0],p) for p in chosen)) if chosen else 0
            at,n,yaw=pending.pop(index)
            if any(math.dist(at,p)<7 for p in chosen):continue
            chosen.append(at)
            # Hooks sit on the wall; hanging cage lies inside the roomward side.
            cx,cy=at[0]+n[0]*.14,at[1]+n[1]*.14;base=z+1.45
            add(tile,'CCS62',(at[0]+n[0]*.02,at[1]+n[1]*.02,base+.3935),yaw=yaw,role='closed-bay wall hook')
            add(tile,'CCS60',(cx,cy,base),yaw=yaw,role='closed-bay lantern cage')
            add(tile,'CCS61',(cx,cy,base+.08),yaw=yaw,role='closed-bay lantern glass')
            add(tile,'CCS64',(cx,cy,base+.12),(.45,.45,.5),yaw,role='closed-bay lantern flame')
            lights.append(dict(tile=tile,at=[cx+n[0]*.08,cy+n[1]*.08,base+.25],intensity=18,radius=550))
            if len(chosen)<=3 and tile not in ['WaterworksW']:
                ident=palette[tile][(len(chosen)-1)%3];sx,sy,_=[v/100 for v in assets[ident]['actual_dimensions_cm']]
                offset=max(sx,sy)*.5+.14;px,py=at[0]+n[0]*offset,at[1]+n[1]*offset
                grounded(tile,ident,px,py,z,role=room['id']+' closed-wall story dressing')
            if len(chosen)>=4:break
        bay_audit.append(dict(room=room['id'],tile=tile,candidate_closed_bays=len(candidates),selected_bays=len(chosen)))
    # Base lighting per source intent. Local practicals supply warm pools; the
    # tall bell/shaft retain cool landmark lights and never receive a fake roof.
    for tile,base in baseline.items():
        for a in base['actors']:
            if a['class']!='PointLight':continue
            label=a['label'];value=140 if 'cold' in label else 100 if 'foyer' in label else 70 if 'dim' in label else 120 if 'hearth' in label else 90
            if label=='Warrens_Light_cold_9':value=8
            if tile=='Court':value=400
            overrides.append(dict(tile=tile,label=label,intensity=value))
    # Material variants need independent groups even when sharing one mesh.
    for r in rows:
        r.setdefault('scale',[1,1,1]);r.setdefault('yaw',0);r['collision']='NoCollision'
        if r.get('material') and not r['id'].startswith('BACKING'):
            r['mesh_id']=r['id'];r['id']+='_'+r['material']
        assert r['tile'] in pivots and all(math.isfinite(v) and v>0 for v in r['scale'])
    # Adjacent source rows share endpoints, and named room records overlap.
    # One visual/contact at each exact mesh/material transform is authoritative.
    rows=[r for r in rows if not (r['tile']=='Pit' and r['id']=='WVC067' and 'story dressing' in r['role']) and not (r['tile']=='Brineworks' and r['id']=='CCS79' and abs(r['at'][0]-122)<.01 and abs(r['at'][1]-8.25)<.01)]
    unique={}
    for r in rows:
        key=(r['tile'],r['id'],tuple(round(v,6) for v in r['at']),tuple(round(v,6) for v in r['scale']),tuple(round(v,6) for v in r.get('rotation',[0,r.get('yaw',0),0])),r.get('material_path'),r.get('material'))
        unique.setdefault(key,r)
    removed_duplicates=len(rows)-len(unique);rows=list(unique.values())
    lights=list({(r['tile'],tuple(round(v,5) for v in r['at']),r['intensity']):r for r in lights}.values())
    visibility=list({(r['tile'],r['label']):r for r in visibility}.values())
    result=dict(schema=1,pivots=pivots,placements=rows,visibility_overrides=visibility,lights=lights,light_overrides=overrides,coverage=shell['coverage'],source_gallery_instances=gallery_count,support_contacts=contacts,room_bays=bay_audit,source_instance_count=sum(len(c.get('instances',[])) for v in baseline.values() for a in v['actors'] for c in a['components']))
    (OUT/'fitted_instances.json').write_text(json.dumps(result,indent=2))
    summary=dict(instances=len(rows),removed_exact_duplicates=removed_duplicates,by_tile=dict(Counter(r['tile'] for r in rows)),source_gallery_instances=gallery_count,rooms=bay_audit,source_instance_count=result['source_instance_count'],invalid_dimensions=0,missing_floor_samples=sum(v['missing_floor_samples'] for v in shell['coverage']['tiles'].values()))
    (OUT/'Reports/placement_checks.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2))
    return result
if __name__=='__main__':build()
