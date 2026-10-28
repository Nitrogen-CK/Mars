"""Pin four accepted R16 instances against saved/reloaded retained masters."""
import ast
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2];TOOLS=Path(__file__).parent
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


tool=TOOLS/'larder_retained_instances_r01.py';ast.parse(tool.read_text());spec=importlib.util.spec_from_file_location('_instance_gate_specs',tool);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
files=[tool,TOOLS/'larder_room_finish_trial_r02.py',TOOLS/'larder_retention_material_assets_r02.py',DOC/'native-fitted-stone-r16/storage_fitted_B.json',DOC/'native-fitted-stone-r16/bank_fitted_B.json',DOC/'native-fitted-stone-r16/ASTRA_FITTED_STONE_AND_WORKING_ROOM_REVIEW_R16.md',DOC.parent/'remaining-room-rollout-r01/private_29_reload_readback_r01.json']
for role in ('props','brine','s3','rawshell','fitted'):
    path=DOC/('retained_master_'+role+'_r01.json');row=json.loads(path.read_text());files += [path,ROOT/('Content/'+row['target'].removeprefix('/Game/')+'.uasset')]
normal=ROOT/'Content/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01/PBR_R02/Textures/T_Larder_BrineWave_NormalDX_R01.uasset';files.append(normal)
targets={role:module.DEST+'/MI_WVC_Larder_'+role.title()+'_R01' for role in module.specs()}
assert all(not (ROOT/('Content/'+target.removeprefix('/Game/')+'.uasset')).exists() for target in targets.values())
gate=dict(status='PENDING_ASTRA_FOUR_RETAINED_INSTANCES',tool_sha256=sha(tool),input_sha256={p.relative_to(ROOT).as_posix():sha(p) for p in files},targets=targets,specs=module.specs(),scope='Four absent private MI only: three accepted quiet prop body finishes and accepted brine .45/dark/UV4x3.5/new independent NormalDX. Exact actual parent/values/overridecounts before/aftersave. No setter bool success assumptions, no source/library binding. Once/role Factory; retain pending on failure/no retry. Main/noPIE/clean and all source/private guards/prefsfinally.',review=dict(status='PENDING_ASTRA_REVIEW'))
path=DOC/'NATIVE_RETAINED_INSTANCES_GATE_R01.json';assert not path.exists();path.write_text(json.dumps(gate,indent=2)+'\n')
print('FOUR_RETAINED_INSTANCES_DRAFT_READY',sha(tool))
