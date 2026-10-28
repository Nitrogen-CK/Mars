"""Record the finite prechange source and focused-test baseline without touching git."""
import hashlib,json,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot';OUT=RUN/'forage_presentation_prechange_r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    assert not OUT.exists();OUT.mkdir()
    files=['Script/ECS/Anchor/Mars_Anchor_Feature.as','Script/ECS/Anchor/Mars_Anchor_Utils.as','Script/ECS/AnchorResolver/Mars_AnchorResolver_Processor_Requests.as','Script/WorldObjects/Anchors/Mars_Anchor_Presets.as']+['Script/WorldObjects/Forage/'+n for n in ('Mars_ForageSource_EntityScript.as','Mars_ForageCenser_EntityScript.as','Mars_ForageVine_EntityScript.as','Mars_ForageBasin.as')]
    result={}
    for name in files:
        path=ROOT/name;dest=OUT/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,dest);result[name]=sha(path);assert sha(dest)==result[name]
    g=json.loads((RUN/'baseline_guard_r02.json').read_text());guards=g['immutable_guards']|g['collision_hashes'];drift=[p for p,h in guards.items() if sha(ROOT/p)!=h];assert not drift,drift
    log=ROOT/'Saved/Logs/WarrensCatacomb_Anchor_Baseline_R01.log';text=log.read_text(errors='replace');assert 'Passed: 41' in text and 'Failed: 0' in text and 'Contaminated: 0' in text
    receipt=dict(status='PRE_CHANGE_ANCHOR_BASELINE',total=41,passed=41,failed=0,contaminated=0,test_log=log.relative_to(ROOT).as_posix(),test_log_sha256=sha(log),protected_count=len(guards),protected_drift=drift,source_sha256=result)
    (RUN/'anchor_prechange_baseline_r01.json').write_text(json.dumps(receipt,indent=2)+'\n');(OUT/'manifest.json').write_text(json.dumps(result,indent=2)+'\n');print('PRECHANGE_CHECKPOINT',len(result),'files;41/41Anchor;651guards exact')
if __name__=='__main__':main()
