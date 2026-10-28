"""Actual Main PIE room views with real carried lantern; no asset/scene overrides."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
GUARD=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot/baseline_guard_after_catacomb_libraries_r32.json'
STATE=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def guard():
    assert sha(GUARD)=='24da2674c8d7c178f626dc7b93c8fdb5940e55aceac94dcc6b2333a3e6c95eaa';g=json.loads(GUARD.read_text());files=g['immutable_guards']|g['collision_hashes'];assert len(files)==651 and all(sha(ROOT/p)==h for p,h in files.items());assert all(sha(ROOT/p)==h for p,h in g['post_test_provenance']['source_sha256'].items());p=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot/candidate_assets_timber_r13.json';a=json.loads(p.read_text());assert len(a['assets'])==39 and all(sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset'))==r['package_sha256'] for p,r in a['assets'].items());return g
def begin(room,output,pawn,helper):
    global STATE
    import unreal as u
    assert STATE is None;g=guard();w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world();assert w and w.get_path_name()=='/Game/Mars/Maps/UEDPIE_0_Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP' and pawn.get_world()==w
    folder=(ROOT/output).resolve();assert folder.is_relative_to((ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev').resolve()) and not folder.exists();folder.mkdir(parents=True)
    assert 'pack=true' in helper.inspect(pawn).splitlines()[0] and 'Mars_ItemDef_Lantern' in helper.inspect(pawn).splitlines()[0]
    STATE=dict(room=room,out=folder,world=w,pawn=pawn,helper=helper,frames=[],guard_sha256=sha(GUARD),source_maps={p:h for p,h in g['immutable_guards'].items() if p in ('Content/Mars/Maps/Warrens_VariantC_Mars_MAP.umap','Content/Mars/Maps/Variants/v8c/LI_Warrens_Brineworks.umap','Content/Mars/Maps/Variants/v8c/LI_Warrens_Belfry.umap')});print('ROOM_CAPTURE_READY',room)
def position(label,plan_xy,floor_z,target_plan):
    import unreal as u
    s=STATE;assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()==s['world'];u.GameplayStatics.set_game_paused(s['world'],False);p=u.Vector((plan_xy[0]-70)*100,(plan_xy[1]-55)*100,floor_z*100+77.2);assert s['pawn'].teleport(p,u.Rotator());target=u.Vector((target_plan[0]-70)*100,(target_plan[1]-55)*100,target_plan[2]*100);eye=u.Vector(p.x,p.y,floor_z*100+112.2);assert s['helper'].aim(s['pawn'],u.MathLibrary.find_look_at_rotation(eye,target));s['view']=label;s['expected_pawn']=list(p.to_tuple());print('ROOM_CAPTURE_POSITIONED',label)
def capture(label=None):
    import unreal as u
    s=STATE;guard();assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()==s['world'];u.GameplayStatics.set_game_paused(s['world'],True);label=label or s['view'];path=s['out']/(label+'.png');assert not path.exists();camera=u.GameplayStatics.get_player_camera_manager(s['world'],0);pawn=s['pawn'];rotation=camera.get_camera_rotation();lights=[c for a in u.GameplayStatics.get_all_actors_of_class(s['world'],u.Actor) if 'Ck_UnrealComponent_Host' in a.get_name() for c in a.get_components_by_class(u.PointLightComponent) if (c.get_world_location()-pawn.get_actor_location()).length()<250 and c.is_visible() and c.intensity>0 and c.attenuation_radius==700];lamp,=lights;assert abs(camera.get_fov_angle()-90)<.01
    r=dict(room=s['room'],view=label,world=s['world'].get_path_name(),pawn=list(pawn.get_actor_location().to_tuple()),camera=list(camera.get_camera_location().to_tuple()),rotation=dict(pitch=rotation.pitch,yaw=rotation.yaw,roll=rotation.roll),fov=camera.get_fov_angle(),world_time=u.GameplayStatics.get_time_seconds(s['world']),inventory=s['helper'].inspect(pawn).splitlines()[0],real_lantern=dict(path=lamp.get_path_name(),at=list(lamp.get_world_location().to_tuple()),intensity=lamp.intensity,radius=lamp.attenuation_radius,rgba=[lamp.light_color.r,lamp.light_color.g,lamp.light_color.b,lamp.light_color.a]),aa=u.SystemLibrary.get_console_variable_int_value('r.AntiAliasingMethod'),source_maps=s['source_maps'],guard_sha256=s['guard_sha256'],boundary='Real equipped/opened lantern through normal raw gameplay Use. Teleported player and paused capture, no art/material/light overrides. Natural lantern state varies; not exact cross-session lighting AB, physical-input, played-duration or multiplayer proof.')
    path.with_suffix('.json').write_text(json.dumps(r,indent=2)+'\n');s['frames'].append(path);u.AutomationLibrary.take_high_res_screenshot(1600,1000,str(path),delay=.2);print('ACTUAL_ROOM_CAPTURE',label,r['camera'],r['real_lantern']['intensity'])
def release():
    global STATE
    import unreal as u
    guard();s=STATE;assert s['frames'];assert all(p.is_file() and p.stat().st_size>1000 for p in s['frames']);u.GameplayStatics.set_game_paused(s['world'],False);STATE=None;print('ROOM_CAPTURE_REFERENCES_RELEASED')
