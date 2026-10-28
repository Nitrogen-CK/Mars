"""Keep original proof producer immutable; canonicalize JSON count keys."""
import ast
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2];TOOLS=Path(__file__).parent
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


old=TOOLS/'compare_room_native_triangles_r01.py';new=TOOLS/'compare_room_native_triangles_r02.py'
source=old.read_text();before="omitted_material_counts=dict(collections.Counter(expected_rows[i]['material'] for i in zero))";after="omitted_material_counts={str(k):v for k,v in collections.Counter(expected_rows[i]['material'] for i in zero).items()}"
assert source.count(before)==1 and not new.exists();new.write_text(source.replace(before,after))
old_validator=TOOLS/'validate_room_native_mesh_r01.py';validator=TOOLS/'validate_room_native_mesh_r02.py'
assert not validator.exists();validator.write_text(old_validator.read_text().replace('compare_room_native_triangles_r01.py','compare_room_native_triangles_r02.py'))
creator=TOOLS/'four_room_owned_assets_r03.py';creator.write_text(creator.read_text().replace("load('validate_room_native_mesh_r01')","load('validate_room_native_mesh_r02')"))
saver=TOOLS/'save_pending_hall_wall_mesh_r01.py';saver.write_text(saver.read_text().replace("load('validate_room_native_mesh_r01')","load('validate_room_native_mesh_r02')"))
for p in [new,validator,creator,saver]:ast.parse(p.read_text())
for name in ['NATIVE_FOUR_ROOM_ASSETS_GATE_R03.json','NATIVE_PENDING_HALL_WALL_SAVE_GATE_R01.json']:
    p=DOC/name;g=json.loads(p.read_text());g['input_sha256']={path:sha(ROOT/path) for path in g['input_sha256']}
    g['input_sha256'].update({v.relative_to(ROOT).as_posix():sha(v) for v in [new,validator]})
    g['tool_sha256']=sha(creator if name.startswith('NATIVE_FOUR_ROOM') else saver)
    p.write_text(json.dumps(g,indent=2)+'\n')
print('JSON_CANONICAL_KEY_FIX_READY',sha(creator),sha(saver))
