"""Four complete assemblies built from reusable parametric meshes and instances."""
import json,math,hashlib,uuid
from pathlib import Path
from collections import Counter
import bpy,bmesh
from mathutils import Vector
from geometry import Mesh,export_fbx,record
from props import prop
HERE=Path(__file__).resolve().parent;OUT=HERE/'Output'

def polar(r,a,z=0):return (r*math.cos(math.radians(a)),r*math.sin(math.radians(a)),z)

def flight(g,wood=False):
    m=Mesh();n=g['risers_per_flight'];da=g['flight_angle_deg']/n;h=g['riser_cm'];ri,ro=g['route_inner_radius_cm'],g['route_outer_radius_cm']
    for k in range(n):
        z=-(k+1)*h
        m.sector(ri,ro,k*da,(k+1)*da,z,35,'M04' if wood else 'M01')
        if wood:
            # Shallow plank seams on the riser face, never proud of the tread.
            for r in [ri+65,ri+130,ri+195]:m.tube(polar(r,k*da,z-28),polar(r,k*da,z-3),.45,'M05',4)
    return m

def landing(g,wood=False,port=False,collision=False,bores=()):
    m=Mesh();ri,R=g['route_inner_radius_cm'],g['shaft_outer_radius_cm'];mat='M04' if wood else 'M01'
    if collision:
        for a in [-26,-13,0,13]:m.sector(ri,R,a,a+13,0,35,mat)
        if port:m.box((R-65,0,-20),(130,300,40),mat)
    else:
        holes=[]
        for angle in bores:
            x,y,_=polar(530,angle);holes.append([(x+6*math.cos(math.tau*i/16),y+6*math.sin(math.tau*i/16)) for i in range(16)])
        m.sector(ri,R,-26,26,0,35,mat,apron=port,holes=holes)
        # Seams are dark narrow inlays flush to the floor, not blocking props.
        for a in [-13,0,13]:
            if any(abs(math.radians(a-b)*530)<7 for b in bores):continue
            points=[polar(r,a,-.15) for r in [ri+12,R-45]]
            m.tube(points[0],points[1],.12,'M00',4)
    return m

def wall(R,height,portal=False,collision=False):
    m=Mesh();inside=R-40+.12
    if portal:
        half=math.degrees(math.asin(120/inside))
        spans=[(-15,-half,0,280),(half,15,0,280),(-15,15,280,height)]
    else:spans=[(-15,15,0,height)]
    if collision:
        for a,b,z0,z1 in spans:
            for i in range(max(1,math.ceil((b-a)/6))):
                n=max(1,math.ceil((b-a)/6));m.sector(inside,R,a+(b-a)*i/n,a+(b-a)*(i+1)/n,z1,z1-z0,'M02')
        return m
    for a,b,z0,z1 in spans:
        m.sector(inside+5,R-6,a,b,z1,z1-z0,'M02')
        courses=max(1,round((z1-z0)/80))
        for j in range(courses):
            low=z0+j*(z1-z0)/courses;high=z0+(j+1)*(z1-z0)/courses
            count=max(1,math.ceil((b-a)/8));offset=(j%2)*.3
            cuts=[a]+[a+(b-a)*(i+offset)/count for i in range(1,count)]+[b]
            for x,y in zip(cuts,cuts[1:]):
                m.sector(inside,inside+5,x+.12,y-.12,high-.8,high-low-1.6,'M01')
                m.sector(R-6,R,x+.12,y-.12,high-.8,high-low-1.6,'M01')
    return m

def guards(g,wood=False,flat=False,collision=False):
    m=Mesh();mat='M04' if wood else 'M05';ri,ro=g['route_inner_radius_cm'],g['route_outer_radius_cm'];span=52 if flat else g['flight_angle_deg'];start=-26 if flat else 0;drop=0 if flat else 1200/g['flight_count_per_route'];n=max(1,math.ceil(span/2))
    radii=[ri-4] if flat else [ri-4,ro+4]
    for r in radii:
        ranges=[(start,start+span)]
        if flat and g['route_count']==2:
            half=math.degrees(math.asin(128/(ri-4)));ranges=[(-26,-half),(half,26)]
        for a,b in ranges:
            nn=max(1,math.ceil((b-a)/2));points=[polar(r,a+(b-a)*i/nn,110-drop*(a+(b-a)*i/nn)/span) for i in range(nn+1)]
            if collision:
                for p,q in zip(points,points[1:]):
                    mid=[(p[k]+q[k])/2 for k in range(3)];length=math.hypot(q[0]-p[0],q[1]-p[1]);yaw=math.degrees(math.atan2(q[1]-p[1],q[0]-p[0]));m.box((mid[0],mid[1],mid[2]-55),(length+1,8,110),mat,yaw)
            else:
                m.rod_curve([(x,y,z-4) for x,y,z in points],4,mat)
                m.rod_curve([(x,y,z-55) for x,y,z in points],2.4,mat)
                if flat:angles=[a,(a+b)/2,b]
                else:angles=[(k-.5)*span/g['risers_per_flight'] for k in range(1,g['risers_per_flight']+1,2)]
                for angle in angles:
                    floor=0 if flat else -math.ceil(angle/span*g['risers_per_flight']-1e-8)*g['riser_cm'];top=110-drop*angle/span
                    x,y,_=polar(r,angle);m.box((x,y,(floor+top)/2),(8,8,top-floor),mat,angle)
    if flat:
        for angle in [-26,26]:
            a=polar(ro+4,angle);b=polar(g['shaft_wall_inner_radius_cm']-1,angle)
            if collision:
                mid=[(a[i]+b[i])/2 for i in range(3)];m.box((mid[0],mid[1],55),(Vector(b).length-Vector(a).length,8,110),mat,angle)
            else:
                for z in [55,106]:m.tube((a[0],a[1],z),(b[0],b[1],z),4 if z==106 else 2.4,mat)
                for p in [a,b]:m.box((p[0],p[1],55),(8,8,110),mat,angle)
    return m

def collar():
    m=Mesh()
    for y in [-135,135]:
        for i in range(4):m.box((20,y,i*80+39),(40,30,78),'M01')
    for i in range(5):m.box((20,-120+i*60,300),(40,58,40),'M01')
    return m

def core_flue(height):
    m=Mesh()
    for i in range(8):m.sector(120,157,i*45,(i+1)*45,height,height,'M03',45)
    for j in range(max(1,int(height/50))):
        for i in range(16):m.sector(157,160,i*22.5+.2,(i+1)*22.5-.2,min(height,j*50+49),48,'M03',22.5)
    for z in [12,height-12]:
        for i in range(8):m.sector(151,160,i*45,(i+1)*45,z+6,12,'M05',45)
    return m

def root_course(z0,z1):
    m=Mesh();rings=max(3,math.ceil((z1-z0)/35));sides=12;vs=[]
    for j in range(rings+1):
        z=z0+(z1-z0)*j/rings;t=math.tau*2.5*(z+1240)/1540;cx,cy=50*math.cos(t),50*math.sin(t)
        for i in range(sides):
            a=math.tau*i/sides+t*.15;r=135*(.9+.1*math.cos(i*2.3+z*.008));vs.append((cx+r*math.cos(a),cy+r*math.sin(a),z-z0))
    fs=[tuple(reversed(range(sides))),tuple(range(rings*sides,(rings+1)*sides))]
    for j in range(rings):
        for i in range(sides):fs.append((j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i))
    m.part(vs,fs,'M08');return m

def root_arch():
    m=Mesh();m.tube((180,0,0),(180,0,300),20,'M08',9);m.tube((500,0,0),(500,0,300),20,'M08',9)
    m.rod_curve([(180,0,300),(250,12,300),(340,18,300),(420,12,300),(500,0,300)],20,'M08',9)
    for r in [200,480]:m.box((r,0,293),(30,44,18),'M05')
    return m

def yoke(collision=False):
    m=Mesh();r=310;half=120;t=math.degrees(math.asin(half/r))
    points=[(r*math.cos(math.radians(a)),r*math.sin(math.radians(a))) for a in [t-2*t*i/20 for i in range(21)]]
    points.extend((r*math.cos(math.radians(a)),r*math.sin(math.radians(a))) for a in [180+t-2*t*i/20 for i in range(21)])
    m.polygon_prism(points,0,25,'M01')
    m.box((0,0,-30),(720,35,10),'M05')
    for y in [-124,124]:
        if collision:m.box((0,y,55),(570,8,110),'M05')
        else:
            for z in [55,106]:m.tube((-285,y,z),(285,y,z),4,'M05')
            for x in [-280,-140,0,140,280]:m.box((x,y,55),(8,8,110),'M05')
    return m

def build_all(spec,source_scene,mats,args):
    rows=[];objects={};placements={};collision_placements={}
    fixture=bpy.data.objects['Spire_AxisGauge_Mars_SM'];fixture['category']='Presentation';fixture.asset_data.catalog_id=str(uuid.uuid5(uuid.NAMESPACE_URL,'SpireConnectorKit/Presentation'))
    row=record(fixture);row.update(id='AxisGauge',category='Presentation',fbx='FBX/Spire_AxisGauge_Mars_SM.fbx',collision_hulls=0)
    row['sha256']=hashlib.sha256((OUT/row['fbx']).read_bytes()).hexdigest();rows.append(row);objects['AxisGauge']=fixture
    def register(key,mesh,category='Architecture',convex=False):
        if key in objects:return key
        bpy.context.window.scene=source_scene
        o=mesh.object('Spire_'+key+'_Mars_SM',mats,source_scene.collection);o['catalog_id']=key;o['category']=category
        o.asset_data.catalog_id=str(uuid.uuid5(uuid.NAMESPACE_URL,'SpireConnectorKit/'+category));o.asset_data.tags.new(category)
        hulls=export_fbx(o,OUT/'FBX'/(o.name+'.fbx'),convex);row=record(o);row.update(id=key,category=category,fbx='FBX/'+o.name+'.fbx',collision_hulls=hulls)
        row['sha256']=hashlib.sha256((OUT/row['fbx']).read_bytes()).hexdigest();rows.append(row);objects[key]=o;print('SPIRE_ASSET',key,row['triangles'],flush=True);return key
    def place(target,asset,at=(0,0,0),yaw=0,layer='Architecture',**extra):target.append(dict(asset=asset,at_cm=list(at),yaw_deg=yaw,scale=[1,1,1],layer=layer,**extra))
    for row in spec['props']:register('PR_'+row['id'],prop(row),'Props')
    m=Mesh();m.box((0,0,-25),(100,100,50),'M00');register('ReviewPlinth',m,'Presentation')
    m=Mesh();m.torus((0,0,6),2.9,.7,'M05','Y',12,5,stretch=(1,1.47));register('ChainLink',m,'Supports')
    m=Mesh();m.sector(6,10,0,90,0,3,'M05');m.sector(6,10,90,180,0,3,'M05');m.sector(6,10,180,270,0,3,'M05');m.sector(6,10,270,360,0,3,'M05');register('DeckGrommet',m,'Supports')
    register('PortalCollar',collar())
    # Shared service vestibule elements, with datum on near threshold floor.
    for key,at,size in [('VestFloor',(150,0,-20),(300,300,40)),('VestWall',(150,0,140),(300,30,280)),('VestRoof',(150,0,300),(300,300,40))]:
        m=Mesh();m.box(at,size,'M01');register(key,m)
        register('COL_'+key,m,'Collision',True)
    for c in spec['concepts']:
        g=c['geometry'];cid=c['id'];R=g['shaft_outer_radius_cm'];wood=cid in ['RW','HL'];style=('WD' if wood else 'ST');prefix=f'R{R}_{style}';p=[];cp=[];placements[cid]=p;collision_placements[cid]=cp
        fid=register(prefix+'_Flight',flight(g,wood));cfid=register('COL_'+prefix+'_Flight',flight(g,False),'Collision',True)
        guard=register(prefix+'_FlightGuard',guards(g,wood));cguard=register('COL_'+prefix+'_FlightGuard',guards(g,False,collision=True),'Collision',True)
        lg=register(prefix+'_LandingGuard',guards(g,wood,flat=True));clg=register('COL_'+prefix+'_LandingGuard',guards(g,False,flat=True,collision=True),'Collision',True)
        for f in c['flights']:
            at=(R,0,f['start_z_cm']);yaw=f['start_angle_deg'];place(p,fid,at,yaw,'Deck',source_id=f['id']);place(p,guard,at,yaw,'Guards');place(cp,cfid,at,yaw,'Collision');place(cp,cguard,at,yaw,'Collision')
        for a in c['areas']:
            port=(a['route']=='A' and a['index'] in [0,g['flight_count_per_route']]);lid=prefix+('_PortLanding' if port else '_Landing')
            bores=[b['angle_unwrapped_deg']-a['angle_center_unwrapped_deg'] for b in c['supports'].get('floor_bore_placements',[]) if b['landing']==a['id']]
            mesh=landing(g,wood,port,bores=bores)
            if cid=='HL':lid='HL_Landing'+str(a['index'])
            key=register(lid,mesh)
            clid=register('COL_'+prefix+('_PortLanding' if port else '_Landing'),landing(g,False,port,True),'Collision',True)
            at=(R,0,a['floor_z_cm']);yaw=a['angle_center_unwrapped_deg'];place(p,key,at,yaw,'Deck',source_id=a['id']);place(p,lg,at,yaw,'Guards');place(cp,clid,at,yaw,'Collision');place(cp,clg,at,yaw,'Collision')
        for height,z,tier in [(400,-1200,0),(400,-800,1),(400,-400,2),(360,0,3)]:
            for angle in range(0,360,30):
                portal=(tier==0 and angle==0) or (tier==3 and angle==180);key=f'R{R}_Wall{height}'+('_Portal' if portal else '')
                register(key,wall(R,height,portal));register('COL_'+key,wall(R,height,portal,True),'Collision',True)
                layer='ShellFront' if 40<=angle<=220 else 'ShellBack'
                place(p,key,(R,0,z),angle,layer);place(cp,'COL_'+key,(R,0,z),angle,'Collision')
        m=Mesh();m.sector(0,R,-15,15,360,40,'M02');roof=register(f'R{R}_Roof',m)
        roof_collision=register(f'COL_R{R}_Roof',m,'Collision',True)
        m=Mesh();m.sector(R-40,R,-15,15,-1200,40,'M02');foot=register(f'R{R}_Foundation',m)
        for angle in range(0,360,30):place(p,roof,(R,0,0),angle,'Roof');place(p,foot,(R,0,0),angle,'Foundation');place(cp,roof_collision,(R,0,0),angle,'Collision')
        place(p,'PortalCollar',(0,0,0),0,'Architecture');place(p,'PortalCollar',(2*R,0,-1200),0,'Architecture')
        for key,at in [('VestFloor',(2*R,0,-1200)),('VestWall',(2*R,-135,-1200)),('VestWall',(2*R,135,-1200)),('VestRoof',(2*R,0,-1200))]:place(p,key,at,0,'Vestibule');place(cp,'COL_'+key,at,0,'Collision')
        for q in c['prop_instances']:place(p,'PR_'+q['asset'],q['local_origin_cm'],q['yaw_outward_deg'],'Props',source_id=q['id'])
        # Repeated shallow joists + external/deep braces, instanced at three stations per flight.
        mk=prefix+'_Joist';m=Mesh();m.box(((g['route_inner_radius_cm']+g['route_outer_radius_cm'])/2,0,-22),(260,18,24),'M04' if wood else 'M02');register(mk,m,'Supports')
        for f in c['flights']:
            for t in [1/6,.5,5/6]:
                z=f['start_z_cm']-math.ceil(t*g['risers_per_flight']-1e-7)*g['riser_cm'];place(p,mk,(R,0,z),f['start_angle_deg']+t*g['flight_angle_deg'],'Supports')
        if cid=='HS':
            register('HS_Flue400',core_flue(400),'Hero');register('HS_Flue300',core_flue(300),'Hero')
            for z in [-1200,-800,-400]:place(p,'HS_Flue400',(R,0,z),0,'Hero')
            place(p,'HS_Flue300',(R,0,0),0,'Hero');m=Mesh();m.tube((0,0,300),(440,0,300),20,'M05',12);register('HS_Duct',m,'Hero');place(p,'HS_Duct')
        if cid=='RW':
            for i,(z0,z1) in enumerate([(-1240,-840),(-840,-440),(-440,-40),(-40,300)]):
                key=register('RW_RootCourse'+str(i+1),root_course(z0,z1),'Hero');place(p,key,(R,0,z0),0,'Hero')
            register('RW_RootArch',root_arch(),'Hero')
            for j in [2,5]:a=c['areas'][j];place(p,'RW_RootArch',(R,0,a['floor_z_cm']),a['angle_center_unwrapped_deg'],'Hero')
            m=Mesh();m.tube((-50,0,300),(-50,0,320),135,'M05',12);register('RW_RoofClamp',m,'Supports');place(p,'RW_RoofClamp',(R,0,0),0,'Supports')
        if cid=='BW':
            register('BW_Yoke',yoke(),'Architecture');register('COL_BW_Yoke',yoke(True),'Collision',True)
            for y in c['supports']['cross_yokes']:place(p,'BW_Yoke',y['center_local_cm'],0,'Deck');place(cp,'COL_BW_Yoke',y['center_local_cm'],0,'Collision')
        if cid=='HL':
            for ch in c['supports']['chain_placements']:
                a=ch['angle_unwrapped_deg'];x,y,_=polar(530,a);length=ch['length_cm'];count=math.ceil(length/8);pitch=(length-12)/(count-1)
                for i in range(count):place(p,'ChainLink',(R+x,y,ch['bottom_z_cm']+i*pitch),a+(i%2)*90,'Chains')
                place(p,'PR_P18',(R+x,y,295),a,'Supports')
            for b in c['supports']['floor_bore_placements']:
                x,y,_=polar(530,b['angle_unwrapped_deg']);place(p,'DeckGrommet',(R+x,y,b['floor_z_cm']),b['angle_unwrapped_deg'],'Supports')
            m=Mesh();m.tube((0,0,0),(0,0,780),1.5,'M05',8);register('HL_BasketRope',m,'Supports')
            for x in [-50,50]:
                for y in [-50,50]:place(p,'HL_BasketRope',(R+x,y,-460),0,'Supports');place(p,'PR_P18',(R+x,y,295),0,'Supports')
    manifest={'generator':'SpireConnectorKit.v1','spec_sha256':hashlib.sha256((HERE.parents[1]/'Docs/design/spire-blender-handoff-20261026/spire_spec.json').read_bytes()).hexdigest(),'axes':'UE centimetres; Blender Y reflected once in mesh and placement','assets':rows,'assemblies':placements,'collision_assemblies':collision_placements}
    (OUT/'asset_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    from scenes import build_scenes
    build_scenes(spec,manifest,objects,mats,args)
    print('SPIRE_PRODUCTION_COMPLETE',len(rows),{k:len(v) for k,v in placements.items()},flush=True)
