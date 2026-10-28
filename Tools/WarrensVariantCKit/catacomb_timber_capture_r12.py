"""Matched paused timber-only A/B captures with physical/light/HISM readback."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
PAIR=None

def digest(value):return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def isolation(room,pbr):
    import unreal as u
    s=room.STATE;assert u.GameplayStatics.is_game_paused(s['world'])
    original=json.loads((RUN/'source_profile_fig_parts_r12.json').read_text())['parts'];parts={}
    for row in original:
        c=u.find_object(None,row['path']);assert isinstance(c,u.StaticMeshComponent) and c.get_owner().get_world()==s['world']
        parts[row['path']]=dict(mesh=c.static_mesh.get_path_name(),material=c.get_material(0).get_path_name(),pose=c.get_world_transform().export_text(),collision=str(c.get_collision_profile_name()),collision_enabled=str(c.get_collision_enabled()),visible=c.is_visible())
    _,hisms=s['core']._hism_snapshot(s['world']);lights={}
    for a in u.GameplayStatics.get_all_actors_of_class(s['world'],u.Actor):
        for c in a.get_components_by_class(u.PointLightComponent):
            lights[c.get_path_name()]=dict(pose=c.get_world_transform().export_text(),intensity=c.intensity,color=c.light_color.export_text(),visible=c.is_visible(),radius=c.attenuation_radius)
    parents={r['component'].get_path_name():r['component'].get_material(r['slot']).get_path_name() for r in s['pbr_rows']}
    assert all('/PBR_R09/Materials/' in p for p in parents.values())
    assert u.SystemLibrary.get_console_variable_int_value('r.AntiAliasingMethod')==0
    return dict(signature=pbr.signature(room),parts=parts,hism_digest=digest(hisms),hism_count=len(hisms),instance_count=sum(len(r['instances']) for r in hisms.values()),lights=lights,stone_parents=parents,aa=0)

def _capture(room,pbr,mode,iso):
    room.STATE['stage']='Timber_'+mode;pbr.capture(room)
    p=room.OUT/(room.STATE['stage']+'_'+room.STATE['view']+'.json');data=json.loads(p.read_text())
    data.update(timber_comparison_mode=mode,isolation=iso,controlled_replay_seed=1632092801,appearance_acceptance=False)
    p.write_text(json.dumps(data,indent=2)+'\n');return p.with_suffix('.png')

def capture_original(room,pbr,timber):
    global PAIR
    assert PAIR is None and not timber.STATE['bindings']
    pbr.pause_pair(room);iso=isolation(room,pbr)
    assert iso['hism_count']==383 and iso['instance_count']==45452
    path=_capture(room,pbr,'A_Original',iso);PAIR=dict(view=room.STATE['view'],original=iso,a=path)

def capture_candidate(room,pbr,timber):
    assert PAIR and PAIR['view']==room.STATE['view'] and PAIR['a'].is_file() and PAIR['a'].stat().st_size>1000
    assert isolation(room,pbr)==PAIR['original'],'Paused state changed before timber bind'
    timber.bind(room);after=isolation(room,pbr);expected=json.loads(json.dumps(PAIR['original']))
    for c,old,role in timber.STATE['bindings']:expected['parts'][c.get_path_name()]['material']=timber.STATE['materials'][role].get_path_name()
    assert after==expected,'More than the three timber bindings changed'
    PAIR['candidate']=after;PAIR['b']=_capture(room,pbr,'B_BroadPlanes',after)

def finish_pair(room,pbr,timber):
    global PAIR
    assert PAIR and PAIR['b'].is_file() and PAIR['b'].stat().st_size>1000
    assert isolation(room,pbr)==PAIR['candidate'],'Paused state changed after candidate capture'
    timber.restore_bindings();assert isolation(room,pbr)==PAIR['original'],'Timber pair did not restore exactly'
    pair=dict(status='PAUSED_EXACT_CAMERA_LIGHT_GEOMETRY_THREE_SLOT_TIMBER_AB',view=PAIR['view'],a=dict(file=PAIR['a'].relative_to(ROOT).as_posix(),sha256=sha(PAIR['a'])),b=dict(file=PAIR['b'].relative_to(ROOT).as_posix(),sha256=sha(PAIR['b'])),original=PAIR['original'],candidate=PAIR['candidate'],boundary='Same actual camera and held-lantern state, sampled PointLight pose/intensity/color/visibility/radius, source HISM geometry and eight Fig part properties except three timber material slots. Controlled replay; no source/asset save or appearance acceptance.')
    p=room.OUT/('Timber_AB_'+PAIR['view']+'.json');assert not p.exists();p.write_text(json.dumps(pair,indent=2)+'\n');print('EXACT_TIMBER_PAIR',p.name,sha(p));PAIR=None
