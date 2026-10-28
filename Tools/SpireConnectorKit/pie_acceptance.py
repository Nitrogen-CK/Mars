"""Isolated Level Instance integration harness and observed pawn traversal.

Run via runpy in editor Python. Teleports are limited to explicit test setup;
route traversal uses AddMovementInput on the possessed Mars chef, with gravity,
step handling and collision enabled. A stall/fall stops rather than skipping it.
"""
import sys,json,math,time,hashlib,gc,traceback
from pathlib import Path
import unreal as u
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
import unreal_scenes as scenes
from import_unreal import manifest,OUT,DEST,OWNER
QA=DEST+'/Maps/Spire_PIEAcceptance_R02_Mars_MAP';QATAG=OWNER+'.PIE'
OFFSETS={'HS':(0,0,0),'BW':(4000,0,0),'RW':(0,4000,0),'HL':(4000,4000,0)}
SPEC=json.loads((HERE.parents[1]/'Docs/design/spire-blender-handoff-20261026/spire_spec.json').read_text(encoding='utf-8'))
EA=scenes.EA;ED=scenes.ED;LES=scenes.LES
STATE=None;HANDLE=None;SUITE=None;SUITE_HANDLE=None

def snapshot_baseline():
    folder=OUT/'PIE'/('baseline-'+time.strftime('%Y%m%d-%H%M%S'));folder.mkdir(parents=True)
    paths=list((HERE.parents[1]/'Content/Mars/Maps/Spire').glob('*.umap'))+[HERE.parents[1]/'Content/Mars/Maps/Camp_Mars_MAP.umap',HERE.parents[1]/'Content/Mars/Maps/Warrens_VariantC_Mars_MAP.umap',OUT/'asset_manifest.json']
    report={str(p.relative_to(HERE.parents[1])):dict(sha256=hashlib.sha256(p.read_bytes()).hexdigest(),mtime_ns=p.stat().st_mtime_ns) for p in paths}
    (folder/'files.json').write_text(json.dumps(report,indent=2));print('SPIRE_PIE_BASELINE',str(folder));return str(folder)

def qa_actor(cls,label,at=(0,0,0)):
    a=scenes.actor(cls,'QA_'+label,at);a.tags=[u.Name(OWNER),u.Name(QATAG)];return a

def save_dirty_owned_maps():
    """Return only strings; no Package/World wrappers may cross a level switch."""
    packages=u.EditorLoadingAndSavingUtils.get_dirty_map_packages();paths=[]
    for package in packages:
        path=package.get_path_name();assert path.startswith('/Game/Mars/Maps/Spire/') or path.startswith(DEST+'/Maps/'),path
        assert u.EditorAssetLibrary.get_metadata_tag(u.load_asset(path),'SpireConnectorOwner')==OWNER,path;paths.append(path)
    settings=u.get_default_object(u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'));old=settings.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    try:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave',type(old).DISABLE)
        if packages:assert u.EditorLoadingAndSavingUtils.save_packages(packages,True)
    finally:settings.set_editor_property('_AutoCookStaticWorldOnLevelSave',old)
    return paths

def build_harness():
    scenes.clean();gc.collect()
    if u.EditorAssetLibrary.does_asset_exist(QA):
        assert LES.load_level(QA)
        current=hashlib.sha256((OUT/'asset_manifest.json').read_bytes()).hexdigest()
        assert u.EditorAssetLibrary.get_metadata_tag(ED.get_editor_world(),'SpireAcceptanceManifestSHA256')==current,'Stale harness. Set QA to a fresh owned map path and build it.'
        print('SPIRE_PIE_HARNESS_REUSED',QA);return
    else:assert LES.new_level(QA,False)
    data=manifest();collisions=0
    for cid,offset in OFFSETS.items():
        li=qa_actor(u.LevelInstance,'Visual_'+cid,offset);assert li.set_world_asset(u.load_asset(scenes.map_path(cid)));li.load_level_instance()
        prior={a.get_path_name() for a in EA.get_all_level_actors()}
        counts=scenes.instances([scenes.shifted(p,offset) for p in data['collision_assemblies'][cid]],'QA_Collision_'+cid,True);collisions+=sum(counts.values())
        for a in EA.get_all_level_actors():
            if a.get_path_name() not in prior:a.tags=[u.Name(OWNER),u.Name(QATAG)]
        R=700 if cid=='BW' else 600
        for label,x,z in [('Upper',-200,0),('Lower',2*R+500,-1200)]:
            a=qa_actor(u.StaticMeshActor,cid+'_'+label+'Pad',(x+offset[0],offset[1],z-25));c=a.static_mesh_component;c.set_mobility(u.ComponentMobility.STATIC);c.set_static_mesh(u.load_asset('/Engine/BasicShapes/Cube'));c.set_collision_profile_name('BlockAll');c.set_material(0,u.load_asset(DEST+'/Materials/M_Spire_M01'));a.set_actor_scale3d(u.Vector(4,3,.5))
        for z in [-1100,-700,-300,100]:
            a=scenes.light('QA_'+cid+'_Fill'+str(z),(offset[0]+R,offset[1],z+150),35,(.8,.85,1),1100);a.tags=[u.Name(OWNER),u.Name(QATAG)];a.point_light_component.set_cast_shadows(False)
    a=qa_actor(u.PlayerStart,'ChefStart',(-200,0,82));a.set_editor_property('player_start_tag',u.Name('Spire.Acceptance'))
    ED.get_editor_world().get_world_settings().set_editor_property('default_game_mode',u.load_class(None,'/Script/Angelscript.Mars_Gameplay_GameMode'))
    u.EditorAssetLibrary.set_metadata_tag(ED.get_editor_world(),'SpireAcceptanceManifestSHA256',hashlib.sha256((OUT/'asset_manifest.json').read_bytes()).hexdigest())
    scenes.save_map();report=dict(map=QA,visual_level_instances=4,collision_instances=collisions,approach_pads=8,mode='/Script/Angelscript.Mars_Gameplay_GameMode');(OUT/'Reports/pie_harness.json').write_text(json.dumps(report,indent=2));print('SPIRE_PIE_HARNESS_SAVED',json.dumps(report))

def concept(cid):return next(c for c in SPEC['concepts'] if c['id']==cid)
def route_points(cid,route='A',radial_offset=0):
    c=concept(cid);g=c['geometry'];R=g['shaft_outer_radius_cm'];r=(g['route_inner_radius_cm']+g['route_outer_radius_cm'])/2+radial_offset;off=OFFSETS[cid];points=[]
    def add(x,y,z,label):points.append(dict(at=[x+off[0],y+off[1],z],label=label))
    def arc(a,b,z,label):
        for i in range(1,max(1,math.ceil(abs(b-a)/4))+1):
            angle=math.radians(a+(b-a)*i/max(1,math.ceil(abs(b-a)/4)));add(R+r*math.cos(angle),r*math.sin(angle),z,label)
    if route.startswith('Y'):
        assert cid=='BW';level=int(route[1:]);assert 0<=level<=3
        for i in range(25):add(R-r+2*r*i/24,0,-400*level,'cross-yoke '+str(level))
        return points
    for x in [-200,-100,0,100,R-r]:add(x,0,0,'upper threshold')
    areas=sorted((a for a in c['areas'] if a['route']==route),key=lambda a:a['index']);flights=sorted((f for f in c['flights'] if f['route']==route),key=lambda f:f['index'])
    if route=='B':
        for x in range(int(R-r)+40,int(R+r)+1,40):add(x,0,0,'top cross-yoke')
        add(R+r,0,0,'top cross-yoke')
    for j,f in enumerate(flights):
        a=areas[j];start=a['angle_center_unwrapped_deg']
        arc(start,f['start_angle_deg'],a['floor_z_cm'],a['id'])
        for k in range(g['risers_per_flight']):
            # One target per tread centre; no step can be skipped in progress accounting.
            angle=math.radians(f['start_angle_deg']+(k+.5)*g['flight_angle_deg']/g['risers_per_flight']);add(R+r*math.cos(angle),r*math.sin(angle),f['start_z_cm']-(k+1)*g['riser_cm'],f['id']+'/tread'+str(k+1))
        # End of last tread into the next flat, maintaining the same floor.
        a=areas[j+1];arc(f['end_angle_deg']-.1,a['angle_center_unwrapped_deg'],a['floor_z_cm'],a['id'])
    if route=='B':
        for x in range(int(R-r)+40,int(R+r)+1,40):add(x,0,-1200,'bottom cross-yoke')
        add(R+r,0,-1200,'bottom cross-yoke')
    for x in [R+r,2*R-100,2*R,2*R+100,2*R+300,2*R+500]:add(x,0,-1200,'lower threshold')
    # Arc segment duplication is harmless only at identical floor positions.
    return points

def position():
    p=STATE['pawn'].get_actor_location();return [p.x,p.y,p.z]
def write():
    s=STATE;report={k:v for k,v in s.items() if k not in ['world','pc','pawn','move','capsule','helper','callback','last_at','last_game','folder']};report['folder']=str(s['folder']);(s['folder']/'run.json').write_text(json.dumps(report,indent=2))
def shot(label):
    s=STATE;path=str(s['folder']/(label+'.png')).replace('\\','/');u.SystemLibrary.execute_console_command(s['world'],'Shot filename="'+path+'" -nosuffix',s['pc'])
def stop(reason='operator'):
    global HANDLE
    if HANDLE is not None:u.unregister_slate_post_tick_callback(HANDLE);HANDLE=None
    if STATE:
        STATE['move'].stop_movement_immediately();STATE['status']=reason;write()

def begin(cid,route='A',direction='down',radial_offset=0,label='baseline',gauge=False):
    global STATE,HANDLE
    assert HANDLE is None,'Traversal already running'
    w=ED.get_game_world();assert w,'Start PIE first';pc=u.GameplayStatics.get_player_controller(w,0);pawn=pc.get_controlled_pawn();assert pawn and pawn.get_class().get_name()=='Mars_PlayerCharacter',str(pawn)
    move=pawn.get_component_by_class(u.CharacterMovementComponent);cap=pawn.get_component_by_class(u.CapsuleComponent);helper=u.new_object(u.load_class(None,'/Script/Angelscript.Mars_ExpeditionAcceptance'),outer=pc)
    points=route_points(cid,route,radial_offset)
    if direction=='up':points.reverse()
    radius,half=(55,110) if gauge else (39,75);cap.set_capsule_size(radius,half,True);move.stop_movement_immediately();move.set_movement_mode(u.MovementMode.MOVE_WALKING)
    start=points[0]['at'];pawn.set_actor_location(u.Vector(start[0],start[1],start[2]+half+3),False,True)
    folder=OUT/'PIE'/label/(cid+'_'+route+'_'+direction+('_gauge' if gauge else '')+('_lane'+str(radial_offset) if radial_offset else ''));folder.mkdir(parents=True,exist_ok=True)
    STATE=dict(world=w,pc=pc,pawn=pawn,move=move,capsule=cap,helper=helper,cid=cid,route=route,direction=direction,radial_offset=radial_offset,gauge=gauge,folder=folder,points=points,index=1,status='running',samples=[],events=[],elapsed=0.,stalled=0.,settle=.5,last_at=list(start),last_game=u.GameplayStatics.get_time_seconds(w),capsule_radius_cm=radius,capsule_half_height_cm=half,max_step_height_cm=move.max_step_height,max_walk_speed_cm=move.max_walk_speed,teleports_during_route=0)
    STATE['last_at']=position()
    print('SPIRE_PIE_TRAVERSE_STARTED',cid,route,direction,'points',len(points),'capsule',radius,half)
    def tick(dt):
        global HANDLE
        s=STATE
        try:
            if not u.SystemLibrary.is_valid(pawn) or not ED.get_game_world():stop('PIE ended');return
            game=u.GameplayStatics.get_time_seconds(w);delta=game-s['last_game'];s['last_game']=game
            if delta<=0:return
            s['elapsed']+=delta
            actual_radius,actual_half=cap.get_scaled_capsule_size()
            if abs(actual_radius-radius)>.01 or abs(actual_half-half)>.01:
                s['events'].append(dict(kind='capsule_changed',radius=actual_radius,half_height=actual_half));stop('failed');return
            at=position();target=s['points'][s['index']];x,y,z=target['at'];dx,dy=x-at[0],y-at[1];dist=math.hypot(dx,dy);feet=at[2]-half;speed=pawn.get_velocity().length()
            if s['settle']>0:s['settle']-=delta;return
            s['samples'].append(dict(t=round(s['elapsed'],3),at=at,feet_z=feet,target=s['index'],label=target['label'],mode=str(move.movement_mode),speed_cm_s=speed))
            if feet<z-100:
                s['events'].append(dict(kind='fell_below_route',at=at,target=target));shot('failed');stop('failed');return
            if dist<=12 and abs(feet-z)<48:
                s['events'].append(dict(kind='waypoint',index=s['index'],label=target['label'],at=at,feet_z=feet,expected_z=z));s['index']+=1;s['stalled']=0
                if s['index']==len(s['points']):shot('arrived');stop('passed');print('SPIRE_PIE_TRAVERSE_PASSED',cid,route,direction,s['elapsed']);return
                if '/tread' not in target['label'] and len(s['events'])%7==0:shot('waypoint_'+str(s['index']))
            else:
                moved=math.dist(at,s['last_at']);s['stalled']=s['stalled']+delta if moved<.1 else 0
                if s['stalled']>2 or s['elapsed']>180:
                    s['events'].append(dict(kind='blocked',at=at,target=target,remaining_cm=dist));shot('blocked');stop('failed');print('SPIRE_PIE_TRAVERSE_BLOCKED',json.dumps(s['events'][-1]));return
                helper.call_method('Aim',args=(pawn,u.Rotator(yaw=math.degrees(math.atan2(dy,dx)))))
                pawn.add_movement_input(u.Vector(dx/dist,dy/dist,0),min(1,max(.18,dist/55)),False)
            s['last_at']=at
            if len(s['samples'])%60==0:write()
        except Exception:
            traceback.print_exc();stop('driver exception')
    HANDLE=u.register_slate_post_tick_callback(tick);STATE['callback']=tick
    shot('start')

def status():
    if not STATE:return None
    s=STATE;print('SPIRE_PIE_STATUS',s['cid'],s['route'],s['direction'],s['status'],s['index'],len(s['points']),round(s['elapsed'],2),position(),s['events'][-1:] if s['status']!='running' else '')

def start_suite(label='baseline-suite',gauge=False,directions=('down','up'),include_yokes=False):
    global SUITE,SUITE_HANDLE
    assert HANDLE is None and SUITE_HANDLE is None
    jobs=[dict(cid=cid,route=r,direction=d,gauge=gauge,label=label) for cid in ['HS','BW','RW','HL'] for r in (['A','B'] if cid=='BW' else ['A']) for d in directions]
    if include_yokes:jobs.extend(dict(cid='BW',route='Y'+str(level),direction=d,gauge=gauge,label=label) for level in range(4) for d in directions)
    SUITE=dict(label=label,gauge=gauge,status='running',jobs=jobs,index=0,results=[],wait=0.)
    def save_suite():
        path=OUT/'PIE'/label;path.mkdir(parents=True,exist_ok=True);(path/'suite.json').write_text(json.dumps(SUITE,indent=2))
    def monitor(dt):
        global SUITE_HANDLE
        try:
            if HANDLE is not None:return
            if SUITE['index']:
                if STATE['status']!='passed':
                    SUITE['status']='failed';SUITE['failure']=dict(job=jobs[SUITE['index']-1],events=STATE['events'][-3:]);save_suite();u.unregister_slate_post_tick_callback(SUITE_HANDLE);SUITE_HANDLE=None;return
                SUITE['results'].append(dict(job=jobs[SUITE['index']-1],status=STATE['status'],seconds=STATE['elapsed'],waypoints=len(STATE['points']),samples=len(STATE['samples']),report=str(STATE['folder']/'run.json')))
            if SUITE['index']==len(jobs):
                SUITE['status']='passed';save_suite();u.unregister_slate_post_tick_callback(SUITE_HANDLE);SUITE_HANDLE=None;print('SPIRE_PIE_SUITE_PASSED',label,len(jobs));return
            job=jobs[SUITE['index']];SUITE['index']+=1;save_suite();begin(**job)
        except Exception:
            traceback.print_exc();SUITE['status']='driver exception';save_suite();u.unregister_slate_post_tick_callback(SUITE_HANDLE);SUITE_HANDLE=None
    SUITE_HANDLE=u.register_slate_post_tick_callback(monitor)
    print('SPIRE_PIE_SUITE_STARTED',label,len(jobs))

def suite_status():
    print('SPIRE_PIE_SUITE_STATUS',json.dumps(SUITE));status()
