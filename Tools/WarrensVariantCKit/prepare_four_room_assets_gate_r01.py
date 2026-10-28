"""Pin already audited original exports and separate room palette parameters."""
import ast
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).parent
DOC = ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'
DEST = '/Game/Mars/ArtReview/Lookdev/RoomRollout_20261027R01'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


tool = TOOLS/'four_room_owned_assets_r01.py'
ast.parse(tool.read_text())
exports = json.loads((DOC/'four_room_exports_r01.json').read_text())
files = [tool,TOOLS/'room_tint_owned_assets_r01.py',TOOLS/'room_tint_master_build_r02.py',DOC/'four_room_exports_r01.json',DOC/'four_room_vertex_range_contract_r01.json',DOC/'ASTRA_FOUR_ROOM_DERIVED_REVIEW_R01.md',DOC/'owned_masters_reload_r01.json']
surfaces = []
for room in exports['rooms']:
    export_path = DOC/room['folder']/'export.json'
    audit_path = export_path.with_name('fresh_fbx_roundtrip.json')
    assert sha(export_path) == room['export_sha256'] and sha(audit_path) == room['fresh_FBX_sha256']
    export = json.loads(export_path.read_text())
    profile_path = DOC/('profiles-r02' if room['room'] in ('hall','sluice') else 'profiles-r01')/(room['room']+'.json')
    profile = json.loads(profile_path.read_text())
    assert profile['room'] == room['room']
    files += [export_path,audit_path,profile_path]
    for row in export['exports']:
        family = row['family']
        source = ROOT/row['file']
        assert sha(source) == row['sha256']
        title = family.title()
        master_path = DOC/('owned_'+family+'_master_r01.json')
        master = json.loads(master_path.read_text())
        assert master['family'] == title
        files += [source,master_path,ROOT/('Content/'+master['target'].removeprefix('/Game/')+'.uasset')]
        surfaces.append(dict(room=room['room'],family=family,export=row,tint=profile['palette_multiplier'][family],profile=profile_path.relative_to(ROOT).as_posix(),profile_sha256=sha(profile_path),master=master['target'],master_package_sha256=master['package_sha256'],palette_target=DEST+'/Materials/MI_WVC_'+room['room'].title()+'_'+title+'_R01',mesh_target=DEST+'/Meshes/'+row['name']))
assert len(surfaces) == 12
targets = [row[k] for row in surfaces for k in ('palette_target','mesh_target')]
assert len(set(targets)) == 24 and all(not (ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset')).exists() for p in targets)
gate = dict(status='PENDING_ASTRA_FOUR_ROOM_PRIVATE_ASSETS_REVIEW',tool_sha256=sha(tool),input_sha256={p.relative_to(ROOT).as_posix():sha(p) for p in files},surfaces=surfaces,scope='Twelve new unbound private RoomTint MI and twelve new unbound surface meshes from original range-safe exports. Per-target single attempt, no replacement/reimport/retry. Main/noPIE/clean/projectidentity guards, canonical+nine+three master+previouscandidate guards, restored preferences. All render triangles/UV/materialIDs dumped for subsequent correspondence; counts/bounds/native RGB set/normal checks before save. Native art and full correspondence review before source/library adoption.',rollback='All targets are absent private unbound candidates. They may remain unused; no source reference added. Failed target stays pending for diagnosis/save-only recovery, never delete/reimport/retry.',review=dict(status='PENDING_ASTRA_REVIEW'))
path = DOC/'NATIVE_FOUR_ROOM_ASSETS_GATE_R01.json'
assert not path.exists()
path.write_text(json.dumps(gate,indent=2)+'\n')
print('FOUR_ROOM_PRIVATE_CANDIDATE_GATE_READY',sha(tool))
