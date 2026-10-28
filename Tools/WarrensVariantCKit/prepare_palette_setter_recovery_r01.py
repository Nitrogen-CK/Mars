"""Freeze failed attempt and prepare exact readback-based successors offline."""
import ast
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
TOOLS=Path(__file__).parent
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


old=TOOLS/'four_room_owned_assets_r01.py'
new=TOOLS/'four_room_owned_assets_r02.py'
source=old.read_text()
before="assert u.MaterialEditingLibrary.set_material_instance_vector_parameter_value(asset,'RoomTint',u.LinearColor(*config['tint'],1))"
after="u.MaterialEditingLibrary.set_material_instance_vector_parameter_value(asset,'RoomTint',u.LinearColor(*config['tint'],1))"
assert source.count(before)==1 and not new.exists()
source=source.replace('NATIVE_FOUR_ROOM_ASSETS_GATE_R01.json','NATIVE_FOUR_ROOM_ASSETS_GATE_R02.json').replace(before,after)
ast.parse(source);new.write_text(source)
gate=json.loads((DOC/'NATIVE_FOUR_ROOM_ASSETS_GATE_R01.json').read_text())
gate['status']='PENDING_ASTRA_SETTER_READBACK_SUCCESSOR'
gate['tool_sha256']=sha(new)
gate['input_sha256'][new.relative_to(ROOT).as_posix()]=sha(new)
gate['review']=dict(status='PENDING_ASTRA_REVIEW')
(DOC/'NATIVE_FOUR_ROOM_ASSETS_GATE_R02.json').write_text(json.dumps(gate,indent=2)+'\n')
tool=TOOLS/'save_pending_hall_palette_r01.py';ast.parse(tool.read_text())
files=[tool,old,DOC/'NATIVE_FOUR_ROOM_ASSETS_GATE_R01.json',DOC/'attempt_palette_hall_walls_r01.json']
gate=dict(status='PENDING_ASTRA_SAVE_ONLY',tool_sha256=sha(tool),input_sha256={p.relative_to(ROOT).as_posix():sha(p) for p in files},review=dict(status='PENDING_ASTRA_REVIEW'))
(DOC/'NATIVE_PENDING_HALL_PALETTE_GATE_R01.json').write_text(json.dumps(gate,indent=2)+'\n')
print('PENDING_SAVE_AND_SUCCESSOR_READY',sha(tool),sha(new))
