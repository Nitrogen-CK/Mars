"""Saved / accepted-transient / saved-repeat capture on the same paused fixture."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
PAIR=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def digest(v):return hashlib.sha256(json.dumps(v,sort_keys=True,separators=(',',':')).encode()).hexdigest()

def isolation(room,pbr,fixture,execution):
    import unreal as u
    s=room.STATE;a=fixture.STATE['active'];assert a['role']=='Fig' and a['runtime_verified']
    assert u.GameplayStatics.is_game_paused(s['world']) and a['world']==s['world']
    parts={c.get_path_name():execution.part_row(c) for c in a['components']};assert len(parts)==8
    _,hisms=s['core']._hism_snapshot(s['world']);lights={}
    for actor in u.GameplayStatics.get_all_actors_of_class(s['world'],u.Actor):
        for c in actor.get_components_by_class(u.PointLightComponent):lights[c.get_path_name()]=dict(pose=c.get_world_transform().export_text(),intensity=c.intensity,color=c.light_color.export_text(),visible=c.is_visible(),radius=c.attenuation_radius)
    parents={r['component'].get_path_name():r['component'].get_material(r['slot']).get_path_name() for r in s['pbr_rows']}
    assert all('/PBR_R09/Materials/' in p for p in parents.values())
    assert len(hisms)==383 and sum(len(r['instances']) for r in hisms.values())==45452
    assert u.SystemLibrary.get_console_variable_int_value('r.AntiAliasingMethod')==0
    return dict(signature=pbr.signature(room),parts=parts,hism_digest=digest(hisms),hism_count=383,instance_count=45452,sampled_lights=lights,stone_parents=parents,aa=0)

def decoded(path):
    d=path.with_suffix('.decode.json');assert d.is_file();r=json.loads(d.read_text())
    assert r['status']=='PNG_CRC_AND_FULL_PIXEL_DECODE_PASSED' and r['sha256']==sha(path) and r['size']==[1600,1000]

def capture(room,pbr,label,snapshot):
    room.STATE['stage']='Timber_'+label;pbr.capture(room)
    path=room.OUT/(room.STATE['stage']+'_'+room.STATE['view']+'.json');r=json.loads(path.read_text())
    r.update(saved_timber_comparison=label,isolation=snapshot,synthetic_fixture=True,source_anchor_result='Nothing row4; separate synthetic Fig',appearance_accepted=False)
    path.write_text(json.dumps(r,indent=2)+'\n');return path.with_suffix('.png')

def saved(room,pbr,fixture,execution):
    global PAIR
    assert PAIR is None;pbr.pause_pair(room)
    original=isolation(room,pbr,fixture,execution)
    path=capture(room,pbr,'SavedA',original);PAIR=dict(original=original,saved=path,bindings=[],view=room.STATE['view'])

def transient(room,pbr,fixture,execution,accepted,creator):
    assert PAIR and PAIR['view']==room.STATE['view'] and not PAIR['bindings'];decoded(PAIR['saved'])
    assert isolation(room,pbr,fixture,execution)==PAIR['original']
    components=fixture.STATE['active']['components'];roles={p:role for role,p in creator.MATERIALS.items()}
    selected=[(c,roles[c.get_material(0).get_path_name().split('.')[0]]) for c in components if c.get_material(0).get_path_name().split('.')[0] in roles]
    assert len(selected)==3 and sorted(role for _,role in selected)==['Arm','Post','Post']
    expected=json.loads(json.dumps(PAIR['original']))
    for c,role in selected:
        material=accepted.STATE['materials'][role];assert creator.graph(material)==creator.graph(c.get_material(0))
        PAIR['bindings'].append((c,c.get_material(0)));c.set_material(0,material)
        expected['parts'][c.get_path_name()]['material']=material.get_path_name().split('.')[0]
    current=isolation(room,pbr,fixture,execution);assert current==expected
    PAIR['candidate']=current;PAIR['transient']=capture(room,pbr,'AcceptedTransientB',current)

def restore_bindings():
    if PAIR:
        for c,original in PAIR['bindings']:c.set_material(0,original);assert c.get_material(0)==original
        PAIR['bindings'].clear()

def repeat(room,pbr,fixture,execution):
    assert PAIR and PAIR['view']==room.STATE['view'];decoded(PAIR['transient'])
    assert isolation(room,pbr,fixture,execution)==PAIR['candidate']
    restore_bindings();assert isolation(room,pbr,fixture,execution)==PAIR['original']
    PAIR['repeat']=capture(room,pbr,'SavedARepeat',PAIR['original'])

def finish(room,pbr,fixture,execution):
    global PAIR
    assert PAIR and not PAIR['bindings'];decoded(PAIR['repeat'])
    assert isolation(room,pbr,fixture,execution)==PAIR['original'];fixture.guard();fixture.assert_dirty_scope()
    frames={k:dict(file=PAIR[k].relative_to(ROOT).as_posix(),sha256=sha(PAIR[k])) for k in ('saved','transient','repeat')}
    r=dict(status='EXACT_PAUSED_SAVED_TRANSIENT_SAVED_TRIPLET',view=PAIR['view'],frames=frames,saved_state=PAIR['original'],transient_state=PAIR['candidate'],boundary='Same actual fixture, camera, lantern, sampled light fields, HISM state and part physical properties; only three timber material paths change. All PNGs fully decoded before each transition. Pixel equality is measured separately. Synthetic class evidence, not an authored selection or source adoption.')
    p=room.OUT/('Timber_Triplet_'+PAIR['view']+'.json');assert not p.exists();p.write_text(json.dumps(r,indent=2)+'\n');print('SAVED_TIMBER_TRIPLET',p.name,sha(p));PAIR=None
