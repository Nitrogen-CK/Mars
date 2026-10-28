"""Pin complete saved candidate/readback proofs for bounded native comparisons."""
import ast
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2];TOOLS=Path(__file__).parent
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


tool=TOOLS/'room_rollout_surface_trial_r01.py';ast.parse(tool.read_text())
files=[tool,TOOLS/'room_art_capture_r33.py',TOOLS/'larder_room_finish_trial_r02.py',TOOLS/'bank_identity_unreal.py',TOOLS/'four_room_owned_assets_r03.py',TOOLS/'validate_room_native_mesh_r02.py',TOOLS/'compare_room_native_triangles_r02.py',DOC/'private_29_reload_readback_r01.json',DOC/'four_room_native_corner_attributes_r01.json',DOC/'zero_corner_normal_diagnostic_r01.json',DOC/'NATIVE_FOUR_ROOM_ASSETS_GATE_R03.json']
for kind in ('palette','mesh'):
    for path in sorted(DOC.glob('native_'+kind+'_*_r01.json')):
        row=json.loads(path.read_text());files += [path,ROOT/('Content/'+row['target'].removeprefix('/Game/')+'.uasset')]
for role in ('walls','floor','ceiling'):
    path=DOC/('owned_'+role+'_master_r01.json');row=json.loads(path.read_text());files += [path,ROOT/('Content/'+row['target'].removeprefix('/Game/')+'.uasset')]
rooms=[]
for room in ('hall','ossuary','cellar','sluice'):
    path=DOC/('profiles-r02' if room in ('hall','sluice') else 'profiles-r01')/(room+'.json');profile=json.loads(path.read_text());assert profile['camera_source']['physical_support_checked']
    files.append(path);rooms.append(dict(room=room,profile=path.relative_to(ROOT).as_posix(),floor_z=profile['camera_source']['floor_z'],views=profile['views'],palette=profile['palette_multiplier']))
gate=dict(status='PENDING_ASTRA_FOUR_ROOM_NATIVE_SURFACE_DIAGNOSTIC',tool_sha256=sha(tool),input_sha256={p.relative_to(ROOT).as_posix():sha(p) for p in files},capture_folder='docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01/native-four-room-surfaces-r17',rooms=rooms,scope='One room at a time, three private NoCollision surface actors; original/new/original standing view plus floor/upper candidates. Natural real lantern, no seeds or original light/material/prop/physics/gameplay changes. Each PNG fullydecoded beforestate/poseadvance. SourceHISMroster exact eachcheck; expected owned records change only explicit visibility flags. Restore/destroy thenlaterabsencecheck perroom, capture.release/stopPIE at end. Every failure unconditionallyabort discardsPIE and clearscapture refs. No source/library adoption.',normal_boundary='Ossuary348 corners/116 source thin faces have invalidzero FBXnormals and native+Z. Max area .0029480029cm²/48.30008cm maxedge. Their geometry/RGB exactlycorrespond; no normalparityclaim there. Validsource normals acrossall12 maxcomponenterror.003894389/maxangle.276042degrees. Judge actual native art beforeanyretention; do not silently alter normals/geometry.',review=dict(status='PENDING_ASTRA_REVIEW'))
path=DOC/'NATIVE_FOUR_ROOM_SURFACE_TRIAL_GATE_R01.json';assert not path.exists();path.write_text(json.dumps(gate,indent=2)+'\n')
print('FOUR_ROOM_NATIVE_DIAGNOSTIC_GATE_READY',sha(tool),len(gate['input_sha256']))
