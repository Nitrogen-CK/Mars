"""Freeze final source/test evidence and a finite proposed test-map guard successor."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-forage-props-r04'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    gate=json.loads((DOC/'SOURCE_INTEGRATION_GATE_R01.json').read_text())
    files=gate['allowed_existing_source_files']+[gate['allowed_new_source'],'Script/Tests/Anchor/Mars_AutoTest_Anchor_PresentationSurvivesDeferredResolveAndClear.as']
    logs={}
    for role,path,passed in [('forage','Saved/Logs/WarrensCatacomb_Forage_Implementation_R02.log',9),('anchor','Saved/Logs/WarrensCatacomb_Anchor_Implementation_R01.log',42)]:
        text=(ROOT/path).read_text(errors='replace');assert f'Passed: {passed}' in text and 'Failed: 0' in text and 'Contaminated: 0' in text
        logs[role]=dict(path=path,sha256=sha(ROOT/path),passed=passed,failed=0,contaminated=0,actual_process_exit=0)
    old=RUN/'baseline_guard_r02.json';g=json.loads(old.read_text());union=g['immutable_guards']|g['collision_hashes'];drift=[p for p,h in union.items() if sha(ROOT/p)!=h]
    testmap='Content/Mars/Maps/AutoTests_Mars_MAP.umap';assert drift==[testmap],drift
    old_hash=union[testmap];new_hash=sha(ROOT/testmap);g['immutable_guards'][testmap]=new_hash
    record=dict(status='POST_TEST_GUARD_SUCCESSOR_FOR_REVIEW',predecessor='Saved/WarrensCGameplay-20261024/CatacombPilot/baseline_guard_r02.json',predecessor_sha256=sha(old),changed_only=testmap,old_sha256=old_hash,new_sha256=new_hash,reason='Approved Toolbox-generated test scope; new context/lifetime wrapper and42/42 Anchor result. Binary actor diff is not proven.',source_sha256={p:sha(ROOT/p) for p in files},tests=logs)
    g['post_test_provenance']=record
    out=RUN/'baseline_guard_after_forage_tests_r01.json';assert not out.exists();out.write_text(json.dumps(g,indent=2)+'\n')
    assert all(sha(ROOT/p)==h for p,h in (g['immutable_guards']|g['collision_hashes']).items())
    record['guard_successor_sha256']=sha(out);record['static_contracts']=json.loads((RUN/'forage_source_contract_static_r01.json').read_text());record['generated']={p:sha(ROOT/p) for p in ['Script/Generated/Mars_EntitySpawnParams.as','Script/Generated/Mars_AutoTestActors.as']}
    report=RUN/'forage_source_implementation_r02.json';assert not report.exists();report.write_text(json.dumps(record,indent=2)+'\n');print('POST_TEST_GUARD',sha(out),'SOURCE_GATE',sha(report))
if __name__=='__main__':main()
