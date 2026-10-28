"""Transient native paired-cube normal proof; exact source roster restoration."""
import json,math
STATE=None
def begin(trial,assets):
    global STATE
    import unreal as u
    assert STATE is None and u.GameplayStatics.is_game_paused(trial.STATE['world'])
    _,before=trial.STATE['core']._hism_snapshot(trial.STATE['world']);actors=[]
    for label,at in [('candidate',[-9050,2040,130]),('geometric_reference',[-8990,1980,130])]:
        a=trial._spawn(u.StaticMeshActor,u.Transform(location=u.Vector(*at),rotation=u.Rotator(pitch=45,yaw=0,roll=0),scale=u.Vector(.6,.6,.6)))
        a.static_mesh_component.set_static_mesh(u.load_asset('/Engine/BasicShapes/Cube'));a.set_actor_label('CP_PROBE_'+label);actors.append(a)
    actors[1].static_mesh_component.set_material(0,u.load_asset(assets.MATERIALS['mortar']))
    STATE=dict(trial=trial,assets=assets,actors=actors,before=before)
    trial.VIEWS['rotated_normal_probe']=([-22,74],[-20.2,75.1,1.3])
    select('floor')
def select(family):
    import unreal as u
    s=STATE;assert s and family in ('floor','ceiling')
    pitch=45 if family=='floor' else -135
    for a in s['actors']:a.set_actor_rotation(u.Rotator(pitch=pitch,yaw=0,roll=0),True)
    s['actors'][0].static_mesh_component.set_material(0,u.load_asset(s['assets'].MATERIALS[family]));s['family']=family
    s['trial'].STATE['stage']='AB_rotated_'+family+'_normal'
    w=s['trial'].STATE['world'];u.SystemLibrary.execute_console_command(w,'r.BufferVisualizationTarget WorldNormal',u.GameplayStatics.get_player_controller(w,0));u.SystemLibrary.execute_console_command(w,'viewmode visualizebuffer',u.GameplayStatics.get_player_controller(w,0));u.GameplayStatics.set_game_paused(w,False);s['trial'].position('rotated_normal_probe')
def record():
    import unreal as u
    s=STATE;assert s and u.GameplayStatics.is_game_paused(s['trial'].STATE['world'])
    family=s['family'];sign=1 if family=='floor' else -1;camera=u.GameplayStatics.get_player_camera_manager(s['trial'].STATE['world'],0)
    ct=u.Transform(location=camera.get_camera_location(),rotation=camera.get_camera_rotation())
    c,r=s['actors'];normal=u.MathLibrary.transform_direction(c.get_actor_transform(),u.Vector(0,0,sign));normal=normal/normal.length()
    reference_point=u.MathLibrary.transform_location(r.get_actor_transform(),u.Vector(0,0,sign*50))
    def project(point):
        v=u.MathLibrary.inverse_transform_location(ct,point);assert v.x>0
        focal=800/math.tan(math.radians(camera.get_fov_angle()/2));return [800+v.y/v.x*focal,500-v.z/v.x*focal]
    path=s['trial'].OUT/(s['trial'].STATE['stage']+'_rotated_normal_probe.json');data=json.loads(path.read_text())
    data['rotated_normal_proof']=dict(family=family,expected_world_normal=list(normal.to_tuple()),candidate_transform=c.get_actor_transform().export_text(),reference_transform=r.get_actor_transform().export_text(),candidate_pixel=project(c.get_actor_location()),reference_face_center_pixel=project(reference_point),reference_local_face_normal=[0,0,sign],reference_material=r.static_mesh_component.get_material(0).get_path_name(),candidate_material=c.static_mesh_component.get_material(0).get_path_name(),boundary='Candidate entire cube uses the owned local-plane-normal material. Reference retains actual geometric face normals. Compare the two projected patches in actual native WorldNormal PNG; no color decoding assumption.')
    path.write_text(json.dumps(data,indent=2)+'\n');print('ROTATED_NORMAL_PROJECTION',data['rotated_normal_proof'])
def finish():
    global STATE
    import unreal as u
    s=STATE;assert s
    for a in s['actors']:
        a.destroy_actor();s['trial'].STATE['created'].remove(a)
    _,after=s['trial'].STATE['core']._hism_snapshot(s['trial'].STATE['world']);assert after==s['before']
    w=s['trial'].STATE['world'];u.SystemLibrary.execute_console_command(w,'r.BufferVisualizationTarget ""',u.GameplayStatics.get_player_controller(w,0));u.SystemLibrary.execute_console_command(w,'viewmode lit',u.GameplayStatics.get_player_controller(w,0))
    print('ROTATED_PROBES_REMOVED_SOURCE_ROSTER_EXACT');STATE=None
