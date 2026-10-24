"""Generate visual-only dressing from the saved level's actual box envelopes.

Unlike the standalone diorama, this fits the rasterised floor, wall and rail
geometry; it never creates a walking surface or changes collision/route data.
Coordinates are metres in the author's plan frame. Seed and density are reusable.
"""
import importlib.util
import json
import math
import random
from pathlib import Path

HERE=Path(__file__).resolve().parent
OUT=HERE/'Output'
PIVOTS={'WaterworksW':(4,14,-2.5),'Canal':(66,-4,-2.5),'Brineworks':(88,4,-2.5)}
ROI=(63,7,131,31)

def chunks(a,b,step):
    n=max(1,math.ceil((b-a)/step))
    return [(a+(b-a)*i/n,a+(b-a)*(i+1)/n) for i in range(n)]

def build(seed=724,detail_density=1):
    baseline=json.loads((OUT/'Reports/level_baseline.json').read_text())
    catalog=json.loads((OUT/'asset_manifest.json').read_text())['assets']
    dims={x['id']:[v/100 for v in x['dimensions_cm']] for x in catalog}
    placements=[];rng=random.Random(seed);visibility=[]
    def add(tile,n,at,scale=(1,1,1),yaw=0,rotation=None,role='dressing'):
        item={'tile':tile,'id':f'CCS{n:02}','at':list(at),'scale':list(scale),'yaw':yaw,'role':role}
        if rotation:item['rotation']=rotation # UE pitch,yaw,roll (NOT Blender Euler)
        placements.append(item)
    def inside(x,y):return ROI[0]<=x<=ROI[2] and ROI[1]<=y<=ROI[3]
    def boxes(tile):
        pivot=PIVOTS[tile]
        for a in baseline[tile]['actors']:
            for c in a['components']:
                for i in c.get('instances',[]):
                    if any(abs(v)>.001 for v in i['rotation']):continue
                    at=[i['at'][k]/100+pivot[k] for k in range(3)]
                    yield a['label'],at,i['scale']
    # Pump/Cistern owns the Canal + Brineworks structural surface fit. Import by path
    # so this tool remains runnable as a standalone script, without package setup.
    fit_path=HERE.parent/'PumpCisternKit'/'surface_fitting.py'
    fit_spec=importlib.util.spec_from_file_location('pump_cistern_surface_fitting',fit_path)
    if fit_spec is None or fit_spec.loader is None:raise RuntimeError(f'Cannot load {fit_path}')
    surface=importlib.util.module_from_spec(fit_spec);fit_spec.loader.exec_module(surface)
    report_path=OUT/'Reports/level_baseline.json'
    surface_specs={tile:{'baseline_path':report_path,'pivot':PIVOTS[tile],
                         'rect':ROI,'min_floor_z':-3,'max_floor_z':-2}
                   for tile in ('Canal','Brineworks')}
    fitted=surface.build(surface_specs)
    for row in fitted['placements']:
        ident=row['id']
        if ident=='BACKING':ident='BACKING_TX'+row.get('material','TX01')[-2:]
        item={**row,'id':ident}
        placements.append(item)
    baseline=json.loads(report_path.read_text())
    # Canal source gallery is replaced only inside ROI; emit untouched source cubes
    # outside it. Waterworks and Brineworks originals stay visible and are not duplicated.
    for actor in baseline['Canal']['actors']:
        if actor['label']!='Warrens_Greybox_gallery':continue
        for component in actor['components']:
            for inst in component.get('instances',[]):
                at=[inst['at'][k]/100+PIVOTS['Canal'][k] for k in range(3)]
                sx,sy,h=inst['scale']
                x0,x1=at[0]-sx/2,at[0]+sx/2;y0,y1=at[1]-sy/2,at[1]+sy/2
                in_roi=x1>ROI[0] and x0<ROI[2] and y1>ROI[1] and y0<ROI[3]
                if not in_roi:
                    placements.append({'tile':'Canal','id':'SOURCE_GALLERY','at':at,
                        'scale':inst['scale'],'rotation':inst['rotation'],'role':'preserved gallery source',
                        'material_path':component['materials'][0]})
                    continue
                top=at[2]+h/2
                # The saved rail starts 20cm above the deck. Extend its visual posts
                # down to the actual crossing floor; retain the original cap height.
                bottom=-2.7
                long_x=sx>=sy;axis_len=sx if long_x else sy
                tangent_axis=0 if long_x else 1
                transverse_axis=1-tangent_axis
                transverse_center=at[transverse_axis];transverse_half=(sy if long_x else sx)/2
                # Keep the replacement chain on the source rail's outside edge.
                side=-1 if transverse_center<25.25 else 1
                rail_center=[at[0],at[1]]
                rail_center[transverse_axis]+=side*(transverse_half+.07)
                t0=at[tangent_axis]-axis_len/2;t1=at[tangent_axis]+axis_len/2
                usable0=max(t0,ROI[tangent_axis]);usable1=min(t1,ROI[tangent_axis+2])
                if usable1<=usable0:continue
                post_xs=[]
                post_step=1.5
                n=max(1,math.ceil((usable1-usable0)/post_step))
                post_xs=[usable0+(usable1-usable0)*i/n for i in range(n+1)]
                for tangent in post_xs:
                    pos=list(rail_center);pos[tangent_axis]=tangent
                    add('Canal',9,(pos[0],pos[1],bottom),(.75,.75,top-bottom),
                        yaw=90 if not long_x else 0,role='source gallery chain post')
                    add('Canal',10,(pos[0],pos[1],top),(.5625,.5625,.5625),
                        yaw=90 if not long_x else 0,role='source gallery post cap')
                link_len=.16;link_count=max(1,math.ceil((usable1-usable0)/link_len))
                step=(usable1-usable0)/link_count
                for j in range(link_count):
                    tangent=usable0+(j+.5)*step
                    sag=-.035*math.sin(math.pi*(j+.5)/link_count)
                    pos=list(rail_center);pos[tangent_axis]=tangent
                    add('Canal',27,(pos[0],pos[1],bottom+h*.62+sag),(.65,.65,.65),
                        rotation=[0,90 if not long_x else 0,90 if j%2 else 0],role='source gallery linked chain')
    visibility.append({'tile':'Canal','label':'Warrens_Greybox_gallery','visible':False})
    # Full Waterworks ownership includes the four small stair/gate gallery pieces.
    # Thin posts and links stay inside their source 10cm barrier envelopes.
    for label,at,sz in boxes('WaterworksW'):
        if label!='Warrens_Greybox_gallery':continue
        x,y,z=at;w,d,h=sz;along_x=w>=d;length=max(w,d);yaw=0 if along_x else 90
        bottom=z-h/2;top=z+h/2
        for t in [-length/2,length/2]:
            xx=x+(t if along_x else 0);yy=y+(0 if along_x else t)
            add('WaterworksW',9,(xx,yy,bottom),(.3,.3,h),role='Waterworks gallery post')
            add('WaterworksW',10,(xx,yy,top),(.225,.225,.225),role='Waterworks gallery cap')
        count=max(1,math.ceil(length/.075))
        for i in range(count):
            t=-length/2+(i+.5)*length/count
            add('WaterworksW',27,(x+(t if along_x else 0),y+(0 if along_x else t),bottom+h*.65),(.25,.25,.25),rotation=[0,yaw,90 if i%2 else 0],role='Waterworks gallery chain')
    visibility.append({'tile':'WaterworksW','label':'Warrens_Greybox_gallery','visible':False})
    # Fascia follows exposed edges of the actual Canal crossing floor boxes (top -2.7m).
    floor_rects=[]
    for actor in baseline['Canal']['actors']:
        if actor['label']!='Warrens_Greybox_floor':continue
        for comp in actor['components']:
            for inst in comp.get('instances',[]):
                at=[inst['at'][k]/100+PIVOTS['Canal'][k] for k in range(3)]
                w,d,h=inst['scale'];top=at[2]+h/2
                if abs(top+2.7)>.01:continue
                rect=(at[0]-w/2,at[1]-d/2,at[0]+w/2,at[1]+d/2)
                clipped=(max(rect[0],ROI[0]),max(rect[1],ROI[1]),min(rect[2],ROI[2]),min(rect[3],ROI[3]))
                if clipped[2]>clipped[0] and clipped[3]>clipped[1]:floor_rects.append((rect,clipped,top))
    # Subtract adjacent floor coverage from each edge, so only the real crossing
    # perimeter gets fascia; each segment is at most the CCS03 2m source length.
    for rect,clipped,top in floor_rects:
        x0,y0,x1,y1=clipped
        for axis,fixed,lo,hi in ((1,y0,x0,x1),(1,y1,x0,x1),(0,x0,y0,y1),(0,x1,y0,y1)):
            cuts=[]
            for other,other_clip,_ in floor_rects:
                if other is rect:continue
                if axis==1 and ((abs(other[3]-fixed)<.01) or (abs(other[1]-fixed)<.01)):
                    a,b=max(lo,other_clip[0]),min(hi,other_clip[2])
                elif axis==0 and ((abs(other[2]-fixed)<.01) or (abs(other[0]-fixed)<.01)):
                    a,b=max(lo,other_clip[1]),min(hi,other_clip[3])
                else:continue
                if b>a:cuts.append((a,b))
            segments=[(lo,hi)]
            for a,b in cuts:
                next_segments=[]
                for u,v in segments:
                    if b<=u or a>=v:next_segments.append((u,v));continue
                    if a>u:next_segments.append((u,a))
                    if b<v:next_segments.append((b,v))
                segments=next_segments
            for a,b in segments:
                if b-a<.3:continue
                count=math.ceil((b-a)/2.0);seg=(b-a)/count
                for j in range(count):
                    mid=a+(j+.5)*seg
                    if axis==1:add('Canal',3,(mid,fixed,top-.6),(seg/2,1,1),yaw=0,role='crossing deck fascia')
                    else:add('Canal',3,(fixed,mid,top-.6),(seg/2,1,1),yaw=90,role='crossing deck fascia')
    # Short underside ribs sit only along the two deck margins, below the source floor.
    # Their CCS04 envelope is 2.5 x .4 x .5m; the centre walking/underpass span stays clear.
    rib_xs=[]
    for _,rect,top in floor_rects:
        if rect[2]-rect[0]<.8 or rect[3]-rect[1]<.8:continue
        x=rect[0]+1.25
        while x<rect[2]-1.0:
            rib_xs.append((x,(rect[1],rect[3]),top));x+=2.5
    seen_ribs=set()
    for x,(y0,y1),top in rib_xs:
        for y in (y0+.2,y1-.2):
            key=(round(x,3),round(y,3))
            if key in seen_ribs:continue
            seen_ribs.add(key)
            add('Canal',4,(x,y,top-.7),(1,1,1),yaw=0,role='crossing underside edge rib')
    # Bank rocks sit against existing solid margins, outside the 2.5m crossing.
    for x,y,yaw in [(68.2,23,20),(68.3,28.7,160),(78.8,22.5,35),(79.5,28.5,160),(91,22.3,20),(91,27.5,150)]:
        tile='WaterworksW' if x<70 else 'Canal' if x<88 else 'Brineworks'
        add(tile,43,(x,y,-3.1),(.85,.65,.8),yaw)
        add(tile,50,(x+.5,y,-2.55),(.65,.65,.65),yaw)
    # Gate hood is deliberately matched to current actor Z=0, not a frozen leaf.
    add('WaterworksW',37,(67,26,4.4),yaw=180,role='static current gate surround')
    for x in [65.9,68.1]:add('WaterworksW',36,(x,26,0),yaw=180,role='static current gate guide')
    # Pump-side rest alcove, keep its centre open for the existing station.
    add('WaterworksW',65,(68,30.7,-2.5),yaw=180)
    add('WaterworksW',62,(69.5,30.6,-.15),yaw=180)
    for n,z in [(60,-.55),(61,-.5),(64,-.48)]:add('WaterworksW',n,(69.5,30.45,z),yaw=180)
    # Maintenance shelves, stored spares and tools: no pretend active wheel control.
    for x in [116,128]:
        add('Brineworks',69,(x,21.6,-2.5),yaw=180)
        for j in range(3):add('Brineworks',68,(x-.45+j*.45,21.5,-1.55),(.5,.5,.5),yaw=j*35)
        add('Brineworks',66,(x,20.4,-2.5));add('Brineworks',67,(x+1.1,20.5,-2.5),(.8,.8,.8))
        add('Brineworks',70,(x-.6,21.4,-.5),(.5,.5,.5))
        add('Brineworks',71,(x+1.2,20.5,-1.84),(.8,.8,.8))
    add('Brineworks',21,(117.2,20.5,-1.78),rotation=[0,0,90],role='stored spare wheel - noninteractive')
    add('Brineworks',22,(116,21.5,-1.55),(.7,.7,.7),role='stored spare axle')
    for x,y in [(115,9),(129,9),(115,20),(129,20)]:
        add('Brineworks',16,(x,y,-2.5),(1,1,1.4))
        add('Brineworks',63,(x,y,-.3),yaw=0 if y<15 else 180)
        add('Brineworks',64,(x,y-.2,-.05),(.8,.8,.8))
    add('Brineworks',79,(122,8.25,-1.2),yaw=0)
    add('Brineworks',78,(126,21.65,-1),yaw=180)
    for n,x,y in [(75,116.8,20),(76,116.9,20),(77,127,20),(72,128,19),(73,117,21),(74,127,21),(85,114.8,9.1),(88,121,10.3)]:
        add('Brineworks',n,(x,y,-2.49 if n in [85,88] else -2.5),yaw=20 if n==72 else 0)
    # The source's straight 24m floor tell; do not invent a connected routing puzzle.
    for x in range(99,122,2):
        add('Brineworks',29,(x,20,-2.49),role='existing straight chain proxy dressing')
        for j in range(9):
            add('Brineworks',27,(x-.9+j*.22,20,-2.35),(.8,.8,.8),rotation=[0,0,90 if j%2 else 0],role='instanced chain')
    add('Brineworks',28,(121.5,20,-2.5))
    # Gutter, hollow outlet and sparse wet accents on the north room margin.
    for x in range(116,130,2):add('Brineworks',54,(x,8.4,-2.45))
    add('Brineworks',55,(129.4,8.8,-2.4),(.7,.7,.7),yaw=90)
    add('Brineworks',56,(129.4,9.3,-2.5),(.6,.6,.6));add('Brineworks',57,(129.4,9.8,-2.47),(.7,.7,.7))
    for x,y in [(115,10),(127,20),(121,9.5)]:add('Brineworks',59,(x,y,-2.485))
    add('Brineworks',84,(129.8,21.8,.1),yaw=180)
    add('Brineworks',58,(114.3,9,.5),(.6,.6,.6),yaw=90)
    # Structural braces on the solid wall margins, not across an entry port.
    for x in [116,120,124,128]:
        add('Brineworks',86,(x,21.75,-1),(1.5,1,1),rotation=[90,0,0])
        add('Brineworks',87,(x,21.65,.25),yaw=180)
    # Use actual exposed south wall faces (roomward +Y) and mount the native +Y
    # fixture assembly from its backplate at the measured source wall plane.
    crossing_lights=[]
    north_faces=[p for p in placements if p.get('role')=='source exposed wall veneer'
                 and p.get('tile') in ('Canal','Brineworks') and p.get('yaw')==180
                 and p['at'][2]<-2.2 and p['scale'][2]>.8]
    for target_x in [78,83,89,94]:
        candidates=[p for p in north_faces if abs(p['at'][0]-target_x)<2 and 22.5<p['at'][1]<24.2]
        if not candidates:continue
        face=min(candidates,key=lambda p:abs(p['at'][0]-target_x))
        x,fy,z=face['at'];tile=face['tile']
        face_y=fy+.175*face['scale'][1]
        base_z=-1.0
        yaw=0
        # CCS62 backplate (rear local -Y) at wall; cage/glass/flame extend into room.
        add(tile,62,(x,face_y+.1125,base_z+.3935),(.9,.9,.9),yaw=yaw,role='crossing lamp wall bracket')
        add(tile,60,(x,face_y+.2135,base_z),(.9,.9,.9),yaw=yaw,role='crossing lamp cage')
        add(tile,61,(x,face_y+.2135,base_z+.05),(.9,.9,.9),yaw=yaw,role='crossing lamp glass')
        add(tile,64,(x,face_y+.2135,base_z+.10),(.35,.35,.35),yaw=yaw,role='crossing lamp flame')
        crossing_lights.append({'tile':tile,'at':[x,face_y+.35,base_z+.28],'intensity':30})
    # Dedupe component flags; every placement remains a visual, with no collision.
    # The saved 24m tell is the inlay group, not the separate Cellar crate.
    visibility.append({'tile':'Brineworks','label':'Warrens_Greybox_prop','visible':True})
    visibility.append({'tile':'Brineworks','label':'Warrens_Greybox_inlay','visible':False})
    flags=list({(v['tile'],v['label']):v for v in visibility}.values())
    return {'seed':seed,'detail_density':detail_density,'roi_plan_metres':ROI,'pivots':PIVOTS,'placements':placements,'crossing_lights':crossing_lights,'light_overrides':[{'tile':'Brineworks','label':'Warrens_Light_dim_13','intensity':70}],'surface_fitting_coverage':fitted['coverage'],'visibility_overrides':flags,'gameplay_changes':False,'limitations':['Current Z=0 lever gate preserved; intended Sluice wheel absent in source. Stored wheel is a noninteractive spare.','No water depth, collision, traversal, source/sink or route changes.']}

if __name__=='__main__':
    data=build();(OUT/'fitted_instances.json').write_text(json.dumps(data,indent=2))
    print('FITTED_INSTANCES',len(data['placements']),{t:sum(p['tile']==t for p in data['placements']) for t in PIVOTS})
