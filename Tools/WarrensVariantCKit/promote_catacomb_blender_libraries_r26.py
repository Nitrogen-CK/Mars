"""Exactly two reviewed byte copies, scoped backups, independent canonical reload."""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import sys
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev'
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
OUT=RUN/'blender_library_promotion_r26'
REVIEW=DOC/'catacomb-library-sync-r22/BLENDER_LIBRARY_CANDIDATE_ACCEPTANCE_R25.md'
APPROVED={'Diorama':'dc5a4116558c47dc70e1da898179daf71993780e845c3f3bdb67b6d770dac44d','KitLibrary':'89ce8f7357ea77a1af623e9ff604f5b74d13d14b8b78f0ce2a50bf7256f9dc48'}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def original(k):return ROOT/'Tools/WarrensVariantCKit/Output'/('WarrensVariantC_'+k+'.blend')
def candidate(k):return DOC/'catacomb-library-sync-r24'/k/('WarrensVariantC_'+k+'_Catacomb_R24.blend')
def baseline():
    p=RUN/'baseline_guard_after_source_room_r19.json';assert sha(p)=='16ffda7943311dc84077c39a3c3905c3c13e5806d4579b4c1e7dd2919471aa72';return read(p)
def guard(promoted=False):
    assert sha(REVIEW)=='fa3adc47c783590291dce888d308e5d8918556549644208f43072912a23c20c5';g=baseline();files=g['immutable_guards']|g['collision_hashes'];assert len(files)==651
    overrides={original(k).relative_to(ROOT).as_posix():h for k,h in APPROVED.items()} if promoted else {}
    assert all(sha(ROOT/p)==overrides.get(p,h) for p,h in files.items()),'Protected file drift'
    assert all(sha(ROOT/p)==h for p,h in g['post_test_provenance']['source_sha256'].items());a=read(RUN/'candidate_assets_timber_r13.json');assert len(a['assets'])==39 and all(sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset'))==r['package_sha256'] for p,r in a['assets'].items())
def promote():
    guard();assert not OUT.exists();OUT.mkdir();rows=[]
    for k,h in APPROVED.items():
        assert sha(candidate(k))==h
        audit=RUN/'blender_library_audit_r25'/k/'r24_reopen.json';a=read(audit);assert a['candidate_sha256']==h and a['status']=='INDEPENDENT_PROCESS_REOPEN_LIBRARY_AND_CAMERA_BOUNDS_ACCEPTED';backup=OUT/(k+'_before.blend');shutil.copy2(original(k),backup);assert sha(backup)==sha(original(k));rows.append(dict(target=k,original=original(k).relative_to(ROOT).as_posix(),before_sha256=sha(backup),backup=backup.relative_to(ROOT).as_posix(),candidate=candidate(k).relative_to(ROOT).as_posix(),after_sha256=h,audit=dict(file=audit.relative_to(ROOT).as_posix(),sha256=sha(audit))))
    # All backups exist before either original is changed. A failed copy restores
    # only a target whose bytes equal this operation's intended candidate.
    copied=[]
    try:
        for r in rows:
            assert sha(ROOT/r['original'])==r['before_sha256'];shutil.copy2(ROOT/r['candidate'],ROOT/r['original']);assert sha(ROOT/r['original'])==r['after_sha256'];copied.append(r)
        guard(True)
    except Exception:
        for r in copied:
            assert sha(ROOT/r['original'])==r['after_sha256'];shutil.copy2(ROOT/r['backup'],ROOT/r['original']);assert sha(ROOT/r['original'])==r['before_sha256']
        raise
    result=dict(status='EXACT_TWO_BLENDER_LIBRARIES_PROMOTED_CANONICAL_REOPEN_PENDING',review=dict(file=REVIEW.relative_to(ROOT).as_posix(),sha256=sha(REVIEW)),tool_sha256=sha(__file__),rows=rows,protected_unique_files=651,unchanged_other_files=649,native_library_files_changed=False)
    (OUT/'promotion.json').write_text(json.dumps(result,indent=2)+'\n');print('TWO_LIBRARIES_PROMOTED',sha(OUT/'promotion.json'))
def verify(k):
    import bpy
    guard(True);assert Path(bpy.data.filepath).resolve()==original(k).resolve() and sha(original(k))==APPROVED[k];receipt=read(OUT/'promotion.json');row,=[r for r in receipt['rows'] if r['target']==k];assert sha(ROOT/row['backup'])==row['before_sha256']
    def module(name):
        p=Path(__file__).with_name(name+'.py');s=importlib.util.spec_from_file_location('_canonical26_'+name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
    writer=module('stage_catacomb_blender_libraries_r21');sync=module('sync_art_libraries');snap=writer.snapshot(sync);accepted=read(RUN/'blender_library_audit_r25'/k/'r24_snapshot.json');assert snap==accepted,'Canonical reopened data differs from accepted candidate'
    assert len(snap['images'])==153 and all(r['packed_sha256'] for r in snap['images'].values());guard(True);report=OUT/(k+'_canonical_reopen.json');assert not report.exists();report.write_text(json.dumps(dict(status='CANONICAL_BLENDER_REOPEN_FULL_SNAPSHOT_EXACT',target=k,original=row['original'],sha256=sha(original(k)),accepted_snapshot_sha256=sha(RUN/'blender_library_audit_r25'/k/'r24_snapshot.json'),all153_file_images_packed=True,tool_sha256=sha(__file__),promotion_sha256=sha(OUT/'promotion.json')),indent=2)+'\n');print('CANONICAL_LIBRARY_VERIFIED',k,sha(report))
def finalize():
    guard(True);g=copy.deepcopy(baseline());r=read(OUT/'promotion.json');proof=[]
    for row in r['rows']:
        k=row['target'];p=OUT/(k+'_canonical_reopen.json');a=read(p);assert a['status']=='CANONICAL_BLENDER_REOPEN_FULL_SNAPSHOT_EXACT' and a['sha256']==APPROVED[k];assert g['immutable_guards'][row['original']]==row['before_sha256'];g['immutable_guards'][row['original']]=row['after_sha256'];proof.append(dict(file=p.relative_to(ROOT).as_posix(),sha256=sha(p)))
    g['blender_catacomb_library_retention_r26']=dict(promotion=dict(file=(OUT/'promotion.json').relative_to(ROOT).as_posix(),sha256=sha(OUT/'promotion.json')),canonical_reopens=proof,boundary='Only two canonical Blender library byte copies accepted. Native library synchronization and prior Sluice remain pending. Accepted Catacomb source/collision/tested source/packages unchanged.');g['status']='CATACOMB_SOURCE_AND_TWO_BLENDER_LIBRARIES_RETAINED_NATIVE_LIBRARIES_PENDING';p=RUN/'baseline_guard_after_blender_libraries_r26.json';assert not p.exists();p.write_text(json.dumps(g,indent=2)+'\n');print('NEW_CANONICAL_GUARD',p.relative_to(ROOT).as_posix(),sha(p))
def main():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else sys.argv[1:];p=argparse.ArgumentParser();p.add_argument('action',choices=('promote','verify','finalize'));p.add_argument('--target',choices=tuple(APPROVED));a=p.parse_args(args)
    if a.action=='promote':promote()
    elif a.action=='verify':assert a.target;verify(a.target)
    else:finalize()
if __name__=='__main__':main()
