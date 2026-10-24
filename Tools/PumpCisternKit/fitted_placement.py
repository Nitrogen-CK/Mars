"""Source-fitted Waterworks assembly; shared skins, separate new prop family."""
import json,math,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from surface_fitting import build as surfaces,load_boxes,contains
PIVOTS={'WaterworksW':(4,14,-2.5),'Hub':(4,36,0)}

def build():
    shell=surfaces();rows=shell['placements'];boxes=load_boxes()
    for p in rows:
        if p['id']=='BACKING':p['id']='BACKING_'+p['material']
    def floor(x,y):
        floors=[b for bs in boxes.values() for b in bs if b['label']=='Warrens_Greybox_floor' and contains(b,x,y) and b['hi'][2]<.1]
        assert floors,(x,y)
        return max(b['hi'][2] for b in floors)
    def add(ident,at,scale=(1,1,1),yaw=0,rotation=None,role='prop'):
        p=dict(tile='Hub' if at[1]>=36 else 'WaterworksW',id=ident,at=list(at),scale=list(scale),yaw=yaw,role=role)
        if rotation is not None:p['rotation']=rotation
        rows.append(p)
    def ground(ident,x,y,scale=(1,1,1),yaw=0,role='prop'):add(ident,(x,y,floor(x,y)+.012),scale,yaw,role=role)
    # This gallery forms the visible Cistern boundary beneath the upper Hub.
    # Retain its collider, replace six scoped visual rails; restore four unrelated
    # gallery instances exactly through material-matched source proxies.
    hub=json.loads((HERE/'Output/Reports/level_baseline.json').read_text())['Hub']
    for a in hub['actors']:
        if a['label']!='Warrens_Greybox_gallery':continue
        for c in a['components']:
            for i,inst in enumerate(c['instances']):
                at=[inst['at'][k]/100+PIVOTS['Hub'][k] for k in range(3)]
                if i in (3,4,5,6):
                    rows.append(dict(tile='Hub',id='SOURCE_GALLERY',at=at,scale=inst['scale'],rotation=inst['rotation'],role='preserved upper Hub gallery',material_path=c['materials'][0]));continue
                x,y,z=at;w,d,h=inst['scale'];length=max(w,d);count=max(1,math.ceil(length/2));step=length/count;yaw=0 if w>=d else 90
                for j in range(count):
                    xx=x+(-length/2+(j+.5)*step if w>=d else 0);yy=y+(-length/2+(j+.5)*step if d>w else 0)
                    add('CCS11',(xx,yy,z-h/2),(step/2,1,h/.8),yaw,role='Cistern gallery infill')
                for j in range(count+1):
                    xx=x+(-length/2+j*step if w>=d else 0);yy=y+(-length/2+j*step if d>w else 0)
                    add('CCS09',(xx,yy,z-h/2),(.3,.3,h-.03375),role='Cistern gallery post')
                    add('CCS10',(xx,yy,z+h/2-.03375),(.225,.225,.225),role='Cistern gallery cap')
    z=floor(54,22)
    add('PWC01',(54,22,z),(.90,.90,1),role='source pump landmark')
    add('PWC02',(54,22.86,z+1.35),role='pump flywheel - static visual')
    add('PWC03',(54,22.72,z+1.35),(.6,.6,.16),rotation=[0,0,90],role='flywheel support shaft')
    add('PWC03',(54,22,z+5.20),(.55,.55,.75),role='pump piston')
    for x,y,yaw in [(54.55,22,0),(53.45,22,180),(54,21.45,90)]:add('PWC04',(x,y,z+.12),(.8,.8,1),yaw)
    # One coherent wall-bound main, repeated 2m sections and shared couplings.
    for x in [51.8,53.8,55.8,57.8,59.8,61.8,63.8]:
        add('PWC05',(x,18.25,.55),role='closed-wall service pipe')
        add('PWC07',(x+1,18.25,.55),(.8,.8,.8),role='pipe coupling')
        add('PWC08',(x,18.15,-.30),yaw=0,role='wall pipe bracket')
    for x in [50.8,64.8]:add('PWC09',(x,18.25,.55),(.8,.8,.8),role='service main closed termination')
    add('PWC18',(59.8,18.25,.55),(.8,.8,.8),role='single maintenance repair')
    # Pump outlet run at 3m above the authored floor; floor approaches stay open.
    for x in [55.8,57.8]:add('PWC05',(x,22,.55),role='pump discharge pipe')
    add('PWC09',(58.8,22,.55),(.8,.8,.8),role='discharge closed service end')
    # Stored elbow demonstrates the same reusable pipe family without a fake valve.
    ground('CCS67',63.8,19.7,(.8,.8,.8))
    add('PWC06',(63.8,19.7,z+.852),role='stored replacement elbow')
    # One maintenance cluster tucked against the north solid wall.
    ground('PWC19',61.7,18.11,yaw=0)
    add('PWC20',(61.7,18.16,z+1.016),(.7,.7,.7),yaw=0)
    ground('PWC21',62.5,19.2)
    ground('CCS66',65,20.2,(.7,.7,.7))
    ground('CCS88',57,20.1)
    # Roots replace the saved 1.2x1.2x5m root proxy, keeping its collision.
    add('PWC14',(24,34,-2.48),(.58,.95,1.95),yaw=12,role='authored roof-root silhouette')
    add('PWC15',(23.65,34,-1.2),(.55,.55,1.3),yaw=-20)
    add('PWC16',(24,34,2.1),(.9,1.8,1),role='root penetration transition')
    # Basin floor and water are source data, not a newly invented pool.
    water=json.loads((HERE.parents[1]/'Tools/LevelDesign/anchor_plans/data/warrens_v8c.json').read_text())['water']
    poly=next(w['poly'] for w in water if w['id']=='cistern-basin')
    add('PWC25',(15.75,37.5,-2.589),role='source polygon shallow-water surface')
    for x,y,scale in [(12.5,34.5,.60),(18.2,35.4,.45),(12.5,40.6,.55)]:
        add('CCS57',(x,y,-2.580),(scale,scale,1),role='quiet cistern surface ripple')
    def in_poly(x,y):
        inside=False;j=len(poly)-1
        for i in range(len(poly)):
            a,b=poly[i],poly[j]
            if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:inside=not inside
            j=i
        return inside
    # Low rim on existing bank, opening the west bank as a wadeable entry.
    for a,b in zip(poly,poly[1:]+poly[:1]):
        dx,dy=b[0]-a[0],b[1]-a[1];length=math.hypot(dx,dy);yaw=math.degrees(math.atan2(dy,dx))
        if a[0]==10 and b[0]==10:continue
        nx,ny=dy/length,-dx/length
        if in_poly((a[0]+b[0])/2+nx*.1,(a[1]+b[1])/2+ny*.1):nx,ny=-nx,-ny
        count=max(1,math.ceil(length/2));step=length/count
        for i in range(count):
            t=(i+.5)/count;x=a[0]+dx*t+nx*.12;y=a[1]+dy*t+ny*.12
            base=floor(x,y)-.01
            add('PWC10',(x,y,base),(step/2,.65,(-2.311-base)/.55),yaw,role='low bank coping - visual only')
    for x,y in [(10,32),(10,42)]:add('PWC12',(x,y,-2.52),(.65,.65,.38),yaw=90,role='open-bank coping termination')
    # The inner corner module is used only at the actual notch, not as a stepping stone.
    add('PWC11',(15.18,37.16,-2.52),(.55,.55,.38),yaw=180,role='source basin notch coping')
    for x,y in [(12,34),(18,34),(18,35.8),(13,38),(12,40.6)]:
        add('PWC17',(x,y,-2.88),(.7,.7,.38),yaw=x*13,role='submerged bed pebbles')
    add('PWC13',(20.9,36.4,floor(20.9,36.4)-.01),(.8,.8,1),yaw=-15,role='plain shallow-water gauge')
    # No source wall supports an outlet at pool level; do not float one over dry bank.
    ground('PWC21',8.8,34.5,(.8,.8,.8))
    ground('PWC19',6,37.89,yaw=180)
    add('PWC20',(6,37.84,-1.484),(.7,.7,.7),yaw=0)
    ground('PWC22',8.4,33.8)
    add('PWC23',(8.4,33.8,floor(8.4,33.8)+.012+.057143),(.8,.8,.8),role='candle seated on tray interior')
    for x,y,yaw in [(52,18.026,0),(66.5,28.026,0),(5.25,37.974,180)]:
        add('PWC24',(x,y,-.2),(.8,.8,.8),yaw,role='quiet royal-service cloth')
    lamps=[]
    # Positions audited against source walls 78/93/111/117, Hub155, 135/162.
    # Hook and hanging eye use actual normalized mesh bounds, not one shared pivot.
    fixtures=[((51,18.2135,-.8),(51,18.1125,-.4065),0),
              ((65.7865,27.75,-.8),(65.8875,27.75,-.4065),90),
              ((8.2135,32.5,-.8),(8.1125,32.5,-.4065),-90),
              ((23.7865,33.25,-.8),(23.8875,33.25,-.4065),90),
              ((12,43.2865,-.4),(12,43.3875,-.0065),180),
              ((36.2135,20.75,.405),(36.1125,20.75,.7985),-90),
              ((44.2135,23.25,-.312),(44.1125,23.25,.0815),-90)]
    for at,bracket,yaw in fixtures:
        x,y,z=at
        for ident,dz in [('CCS60',0),('CCS61',.05),('CCS64',.10)]:add(ident,(x,y,z+dz),(.35,.35,.35) if ident=='CCS64' else (.9,.9,.9),yaw,role='practical fixture')
        add('CCS62',bracket,(.9,.9,.9),yaw,role='wall-attached hanging hook')
        forward=(-math.sin(math.radians(yaw)),math.cos(math.radians(yaw)))
        lamps.append(dict(tile='Hub' if y>=36 else 'WaterworksW',at=[x+forward[0]*.14,y+forward[1]*.14,z+.30],intensity=18,radius=550))
    return dict(pivots=PIVOTS,placements=rows,coverage=shell['coverage'],lights=lamps,visibility_overrides=[{'tile':'WaterworksW','label':'Warrens_Greybox_prop','visible':False},{'tile':'WaterworksW','label':'Warrens_Greybox_root','visible':False},{'tile':'Hub','label':'Warrens_Greybox_water','visible':False},{'tile':'Hub','label':'Warrens_Greybox_gallery','visible':False}],light_overrides=[{'tile':'WaterworksW','label':'Warrens_Light_dim_12','intensity':70},{'tile':'WaterworksW','label':'Warrens_Light_foyer_4','intensity':100},{'tile':'Hub','label':'Warrens_Light_dim_15','intensity':70}],source_collision_changes=False)

if __name__=='__main__':
    d=build();(HERE/'Output').mkdir(exist_ok=True);(HERE/'Output/fitted_instances.json').write_text(json.dumps(d,indent=2));print('PUMP_FITTED',len(d['placements']))
