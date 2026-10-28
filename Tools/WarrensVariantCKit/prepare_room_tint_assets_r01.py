"""Prepare a bounded successor builder and draft asset review gate offline."""
import ast
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).parent
DOC = ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


source = (TOOLS/'room_tint_master_build_r01.py').read_text()
old = "assert isinstance(destination, u.Material) and destination.get_outer().get_path_name() == '/Engine/Transient'"
new = "assert isinstance(destination, u.Material) and destination.get_path_name().split('.')[0] == '/Game/Mars/ArtReview/Lookdev/RoomRollout_20261027R01/Materials/M_WVC_'+family+'_RoomTint_R01'"
assert source.count(old) == 1
builder = TOOLS/'room_tint_master_build_r02.py'
assert not builder.exists()
builder.write_text(source.replace(old, new))
tool = TOOLS/'room_tint_owned_assets_r01.py'
for path in (builder, tool):
    ast.parse(path.read_text())
files = [builder, tool, TOOLS/'room_tint_master_build_r01.py', TOOLS/'material_graph_values_r02.py', TOOLS/'material_graph_links_r01.py', TOOLS/'catacomb_plane_normal_materials.py', TOOLS/'room_art_capture_r33.py', TOOLS/'larder_high_roof_assets_r01.py', DOC/'room_tint_transient_builds_r01.json', DOC/'native-room-tint-parity-r15/ASTRA_ROOM_TINT_WHITE_RESULT_R15.md']
gate = dict(status='PENDING_ASTRA_THREE_ABSENT_PRIVATE_MASTERS_REVIEW', tool_sha256=sha(tool), input_sha256={p.relative_to(ROOT).as_posix():sha(p) for p in files}, targets=['/Game/Mars/ArtReview/Lookdev/RoomRollout_20261027R01/Materials/M_WVC_'+family+'_RoomTint_R01' for family in ('Walls','Floor','Ceiling')], scope='Three absent private masters only; exact new graph copies of accepted R09 families with RoomTint white. Native white-copy parity already reviewed R15. No MI, mesh import, binding, source/library save, texture or accepted parent edits.', rollback='These new private unbound packages can remain unused; no source references are added. Never overwrite/reimport/delete or retry a failed Factory attempt. Retain pending object for diagnosis/save-only recovery.', review=dict(status='PENDING_ASTRA_REVIEW'))
(DOC/'NATIVE_ROOM_TINT_ASSETS_GATE_R01.json').write_text(json.dumps(gate,indent=2)+'\n')
print('THREE_PRIVATE_MATERIALS_DRAFT_GATE_READY',sha(tool))
