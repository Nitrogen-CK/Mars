"""Resume two untouched rooms using observed exact movement representation."""
import ast
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2];TOOLS=Path(__file__).parent
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


old=TOOLS/'room_rollout_surface_trial_r01.py';new=TOOLS/'room_rollout_surface_trial_r02.py'
source=old.read_text().replace('NATIVE_FOUR_ROOM_SURFACE_TRIAL_GATE_R01.json','NATIVE_FOUR_ROOM_SURFACE_TRIAL_GATE_R02.json')
before='actor.set_actor_transform(transform,False,True);assert core._pose(actor.get_actor_transform())==core._pose(transform)'
after="pose=base.load('checked_surface_pose_r01').set_pose(actor,transform,core)\n        STATE.setdefault('placement_readbacks',[]).append(pose)"
assert source.count(before)==1 and not new.exists();source=source.replace(before,after)
source=source.replace("record['room']=t['room'];record['room_surfaces']=dict(on=t['on'],actors=t['expected'])","record['room']=t['room'];record['room_surfaces']=dict(on=t['on'],actors=t['expected'],placement_readbacks=t['placement_readbacks'])")
ast.parse(source);new.write_text(source)
gate=json.loads((DOC/'NATIVE_FOUR_ROOM_SURFACE_TRIAL_GATE_R01.json').read_text())
gate['status']='PENDING_ASTRA_EXACT_MOVEMENT_REPRESENTATION_RESUME';gate['tool_sha256']=sha(new);gate['review']=dict(status='PENDING_ASTRA_REVIEW')
gate['capture_folder']='docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01/native-four-room-surfaces-r18'
files=[new,TOOLS/'checked_surface_pose_r01.py',TOOLS/'probe_surface_pose_precision_r01.py',TOOLS/'probe_surface_pose_precision_r02.py',DOC/'surface_pose_precision_experiment_r01.json',DOC/'surface_pose_precision_experiment_r02.json']
gate['input_sha256'].update({p.relative_to(ROOT).as_posix():sha(p) for p in files})
gate['scope']+=' Resume only Cellar/Sluice; R17Hall/Ossuary views and normal restoration remain valid. New pose checker accepts literal target or exact binary64 old+(target-old), with q/scale exact and unattached Movable nonphysical root. Every actual pose and arithmetic input is recorded then remains exactly frozen. No blanket epsilon or geometry support tolerance change.'
(DOC/'NATIVE_FOUR_ROOM_SURFACE_TRIAL_GATE_R02.json').write_text(json.dumps(gate,indent=2)+'\n')
print('CELLAR_SLUICE_FINITE_POSE_RESUME_READY',sha(new),sha(TOOLS/'checked_surface_pose_r01.py'))
