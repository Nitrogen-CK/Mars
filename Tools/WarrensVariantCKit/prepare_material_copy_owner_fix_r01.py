"""Make an exact-clone successor retaining original failed-attempt tools."""
import ast
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2];TOOLS=Path(__file__).parent
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


old=TOOLS/'clone_reviewed_material_graph_r01.py';new=TOOLS/'clone_reviewed_material_graph_r02.py';source=old.read_text()
source=source[:source.index('    # Use the source names')]+"    return load('material_copy_semantic_readback_r01').readback(destination,source,{k:v.get_name() for k,v in copies.items()})\n"
assert not new.exists();ast.parse(source);new.write_text(source)
old_creator=TOOLS/'larder_retention_material_assets_r01.py';creator=TOOLS/'larder_retention_material_assets_r02.py'
source=old_creator.read_text().replace('NATIVE_RETENTION_MASTERS_GATE_R01.json','NATIVE_RETENTION_MASTERS_GATE_R02.json').replace("load('clone_reviewed_material_graph_r01')","load('clone_reviewed_material_graph_r02')")
assert not creator.exists();ast.parse(source);creator.write_text(source)
gate=json.loads((DOC/'NATIVE_RETENTION_MASTERS_GATE_R01.json').read_text());gate['status']='PENDING_ASTRA_MATERIAL_OWNER_REFERENCE_SUCCESSOR';gate['tool_sha256']=sha(creator);gate['review']=dict(status='PENDING_ASTRA_REVIEW')
files=[new,creator,TOOLS/'material_copy_semantic_readback_r01.py']
gate['input_sha256'].update({p.relative_to(ROOT).as_posix():sha(p) for p in files})
(DOC/'NATIVE_RETENTION_MASTERS_GATE_R02.json').write_text(json.dumps(gate,indent=2)+'\n')
print('OWNER_REFERENCE_SUCCESSOR_DRAFT_READY',sha(creator))
