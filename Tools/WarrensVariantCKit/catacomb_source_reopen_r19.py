"""Read-only two-reopen proof with nine exact reviewed new-only PostLoad pairs."""
import copy
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02'
STATE=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
LOADED_TOOL_SHA256=sha(__file__)
def write(name,data):
    p=RUN/(name+'_r19.json');assert not p.exists();p.write_text(json.dumps(data,indent=2)+'\n')
    return dict(file=p.relative_to(ROOT).as_posix(),sha256=sha(p))
def check_exports(snap):
    refs=[snap['script']]
    for r in snap['roster'].values():refs+=[r['raw']]+[c['raw'] for c in r['components'].values()]
    assert len(refs)==134 #41 actors +92 components +one separate archetype script.
    assert all(sha(ROOT/r['file'])==r['sha256'] for r in refs)
def clean(source):
    import unreal as u
    source.guard();assert source.STATE['source'].dirty()==dict(maps=[],content=[])
    p=source.STATE['source'].settings();old=source.STATE['prefs']
    assert p['autosave']==old['autosave'] and p['cook']==old['cook']
    assert u.SystemLibrary.get_console_variable_int_value('r.AntiAliasingMethod')==0
def accept_first(source):
    global STATE
    assert STATE is None and source.STATE['stage']=='saved' and len(source.STATE['unloads'])==1 and not source.STATE['reopens']
    gate=read(DOC/'SOURCE_ROOM_POSTLOAD_GATE_R19.json');pairs_file=RUN/'source_room_postload_pairs_r19.json'
    assert gate['status']=='APPROVED_EXACT_NINE_NEW_ONLY_POSTLOAD_PAIRS' and gate['tool_sha256']==LOADED_TOOL_SHA256==sha(__file__)
    assert gate['pairs_sha256']==sha(pairs_file)
    proposal=read(pairs_file);assert len(proposal['pairs'])==9 and proposal['source_map_sha256']==source.STATE['current_hash']
    observed_file=RUN/'source_room_reopen_observed_r19.json';assert sha(observed_file)==proposal['first_observed_sha256']
    observed=read(observed_file)['snapshot'];saved=source.STATE['saved'];check_exports(saved);check_exports(observed)
    expected=copy.deepcopy(saved)
    for p in proposal['pairs']:
        assert p['label'].startswith('WVC_Catacomb_') and p['label'] in {r['label'] for r in source.STATE['m']['new_actors'] if 'light' in r}
        a=expected['roster'][p['actor']];b=observed['roster'][p['actor']];assert a['label']==b['label']==p['label']
        old=a['raw'] if p['component'] is None else a['components'][p['component']]['raw']
        new=b['raw'] if p['component'] is None else b['components'][p['component']]['raw']
        assert old==p['before'] and new==p['after']
        old['sha256']=new['sha256']
    assert source.semantic_snapshot(expected)==source.semantic_snapshot(observed)
    current=source.snapshot('reopen_1_confirmed_r19');check_exports(current);source.compare_delta(current)
    assert source.semantic_snapshot(current)==source.semantic_snapshot(observed);clean(source)
    first=write('source_room_reopen_1',dict(status='FIRST_UNLOADED_REOPEN_EXACT_EXCEPT_NINE_REVIEWED_NEW_ONLY_POSTLOAD_PAIRS',snapshot=current,pairs_sha256=sha(pairs_file),gate_sha256=sha(DOC/'SOURCE_ROOM_POSTLOAD_GATE_R19.json'),unloaded=source.STATE['unloads'][0],map_sha256=source.STATE['current_hash']))
    source.STATE['reopens'].append(first);STATE=dict(source=source,first=current,first_receipt=first)
    print('FIRST_SOURCE_REOPEN_ACCEPTED',first)
def second():
    s=STATE;source=s['source'];assert len(source.STATE['unloads'])==2 and len(source.STATE['reopens'])==1
    current=source.snapshot('reopen_2_confirmed_r19');check_exports(current);source.compare_delta(current)
    assert source.semantic_snapshot(current)==source.semantic_snapshot(s['first']),'Second unloaded reopen not exactly stable'
    clean(source);r=write('source_room_reopen_2',dict(status='SECOND_UNLOADED_REOPEN_ALL134_EXPORTS_AND_FULL_SNAPSHOT_EXACT',snapshot=current,first=s['first_receipt'],unloaded=source.STATE['unloads'][1],map_sha256=source.STATE['current_hash']))
    source.STATE['reopens'].append(r);print('SECOND_SOURCE_REOPEN_EXACT',r)
