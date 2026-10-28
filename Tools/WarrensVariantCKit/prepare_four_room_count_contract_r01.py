"""Keep failed import immutable; draft explicit zero-area-face correspondence rules."""
import ast
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2];TOOLS=Path(__file__).parent
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


old=TOOLS/'four_room_owned_assets_r02.py';new=TOOLS/'four_room_owned_assets_r03.py'
s=old.read_text();start=s.index('        counts={};dm=None');end=s.index("    transaction(room,family,'mesh',build)")
s=s[:start]+"        details=load('validate_room_native_mesh_r01').validate(mesh,config)\n        return mesh,details\n"+s[end:]
s=s.replace('NATIVE_FOUR_ROOM_ASSETS_GATE_R02.json','NATIVE_FOUR_ROOM_ASSETS_GATE_R03.json')
assert not new.exists();ast.parse(s);new.write_text(s)
module_path=TOOLS/'compare_room_native_triangles_r01.py';spec=importlib.util.spec_from_file_location('_count_contract',module_path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
g=json.loads((DOC/'NATIVE_FOUR_ROOM_ASSETS_GATE_R02.json').read_text());g['status']='PENDING_ASTRA_EXACT_ZERO_FACE_NATIVE_CONTRACT';g['tool_sha256']=sha(new);g['review']=dict(status='PENDING_ASTRA_REVIEW')
files=[new,TOOLS/'validate_room_native_mesh_r01.py',module_path,TOOLS/'dump_room_fbx_geometry_r01.py']
for row in g['surfaces']:
    folder=Path(row['export']['file']).parent
    path=ROOT/folder/('actual_fbx_'+row['family']+'_geometry_r01.json')
    data=json.loads(path.read_text());assert data['fbx_sha256']==row['export']['sha256']
    row['expected_geometry_file']=path.relative_to(ROOT).as_posix();row['expected_geometry_sha256']=sha(path);row['exact_zero_area_FBX_triangles']=sum(module.cross_area_squared(t)==0 for t in data['triangles'])
    files.append(path)
g['input_sha256'].update({p.relative_to(ROOT).as_posix():sha(p) for p in files})
g['scope']+=' R03 explicitly enumerates exact-zero-area FBX faces; every nonzero face must match native cyclic positions/material/half-packed UV before saving. Source counts never silently widened; original geometry/footprint audits immutable. No normal-field or native appearance claim.'
(DOC/'NATIVE_FOUR_ROOM_ASSETS_GATE_R03.json').write_text(json.dumps(g,indent=2)+'\n')
tool=TOOLS/'save_pending_hall_wall_mesh_r01.py';ast.parse(tool.read_text())
files=[tool,old,TOOLS/'validate_room_native_mesh_r01.py',module_path,DOC/'attempt_mesh_hall_walls_r01.json',DOC/'pending_hall_wall_geometry_r01.json',DOC/'hall_wall_native_correspondence_r01.json']
gate=dict(status='PENDING_ASTRA_EXISTING_HALL_WALL_MESH_SAVE',tool_sha256=sha(tool),input_sha256={p.relative_to(ROOT).as_posix():sha(p) for p in files},review=dict(status='PENDING_ASTRA_REVIEW'))
(DOC/'NATIVE_PENDING_HALL_WALL_SAVE_GATE_R01.json').write_text(json.dumps(gate,indent=2)+'\n')
print('FINITE_COUNT_CONTRACT_AND_PENDING_SAVE_READY',sha(new),sha(tool))
