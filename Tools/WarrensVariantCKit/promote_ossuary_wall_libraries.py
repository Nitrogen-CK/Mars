"""Promote two audited copies with backups, then audit each canonical file in Blender."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
RUN = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryWallLibraryStage'
PROMOTION = RUN / 'promotion.json'
HELPER = HERE / 'ossuary_wall_libraries.py'
HELPER_SHA = 'cacb3130ff754298eb54d91333d552478ab7a98f75af3d3122d4964d84097967'
BASELINE = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryWallMaterialCheckpoint/audit_reloaded_20261026T005527_886384Z/receipt.json'
BASELINE_SHA = '64dc4d3062fc64427a9bac19c1c5e1a6ceb90183dab8f0e922e503ac69e8674a'
APPROVAL = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/OSSUARY_WALL_PBR_RUNTIME_REVIEW.md'
APPROVAL_SHA = 'c527bbd763c5330e26061d9c8a30d7437c53400baaee3007f71b8b6970c89472'
SPECS = {
    'Diorama': dict(attempt='Diorama/6728d2322f7042caa1d7c437178d09e0', stage_sha='44708eb4a39b6ecea287870e71790aa41cd4213f125d3ee7cc9dd53a7a8da00d', audit_sha='7e641ba351f3811c59b76f9a6f8708ed88fef641783c00441f0d5a4092ca96f2', after='9e4f1f4e20ed64e6f228e635ac781d6bcb01daea44c9781eb5be96702b2b497a', views_sha='a94afa2fe457c0702c65cfa84b45536aca5b13367e3b7a69dcbb98fbb6d72450'),
    'KitLibrary': dict(attempt='KitLibrary/61dddb145f064c8bb39fc0cbbf506fc3', stage_sha='b137dda90d90c2cddeb89ea52ca59860a40773aee0bee3d77547a2395bdb5b6b', audit_sha='b13bf377587c7bc979588d5b4fc8982804b06fd65b08dc32bfe719155f5ec3dd', after='84e24d4133ea31f7377881475409dc86d14503c94f947b1257b04afaeacf653d', views_sha='357d0f4cd37b82fca90bef79f0bf3ff56b2624d04edc1f7dad5fdc55737ca3ec'),
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text())


def helper():
    assert sha(HELPER) == HELPER_SHA
    spec = importlib.util.spec_from_file_location('_ossuary_library_promotion_contract', HELPER)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def source_guard():
    assert sha(BASELINE) == BASELINE_SHA and sha(APPROVAL) == APPROVAL_SHA
    guards = read(BASELINE)['protected_files']
    assert len(guards) == 614
    return dict(guards)


def promote():
    assert not PROMOTION.exists()
    h = helper()
    guards = source_guard()
    assert all(sha(ROOT / p) == value for p,value in guards.items())
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ')
    backup_folder = RUN / ('canonical_backups_' + stamp)
    backup_folder.mkdir()
    files, prepared, replaced = [], [], []
    try:
        for name, spec in SPECS.items():
            stage_file, audit_file = [RUN / spec['attempt'] / filename for filename in ('stage.json','reopen_audit.json')]
            assert sha(stage_file) == spec['stage_sha'] and sha(audit_file) == spec['audit_sha']
            stage, audit = read(stage_file), read(audit_file)
            assert all(sha(ROOT / p) == value for p,value in stage['immutable_file_guards'].items())
            assert stage['library'] == name and stage['tool_sha256'] == HELPER_SHA
            assert audit['status'] == 'REOPEN_AUDIT_PASS' and audit['stage_sha256'] == spec['stage_sha']
            assert stage['geometry_before'] == stage['geometry_after'] == audit['geometry']
            assert len(stage['bindings']) == 2388 and stage['inventory_counts']['wrapper_objects'] == 2
            assert stage['inventory_counts']['scenes'] == 15
            target, before = h.LIBRARIES[name]
            assert target.resolve().is_relative_to((HERE / 'Output').resolve())
            staged = ROOT / stage['staged_blend']
            assert sha(staged) == spec['after'] and sha(target) == before
            views = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/lookdev/ossuary-painterly-r01/library-preview-r01' / name / 'SOURCE_VIEWS_VERIFIED.json'
            assert sha(views) == spec['views_sha']
            view_data = read(views)
            assert view_data['source_sha256'] == spec['after'] and len(view_data['frames']) == 2
            assert all(sha(ROOT / r['file']) == r['sha256'] for r in view_data['frames'])
            backup = backup_folder / target.name
            shutil.copy2(target, backup)
            assert sha(backup) == before
            temporary = backup_folder / ('new_' + target.name)
            shutil.copy2(staged, temporary)
            assert sha(temporary) == spec['after']
            row = dict(library=name, target=target.relative_to(ROOT).as_posix(), before_sha256=before,
                after_sha256=spec['after'], backup=backup.relative_to(ROOT).as_posix(),
                stage_receipt=stage_file.relative_to(ROOT).as_posix(), stage_receipt_sha256=spec['stage_sha'],
                reopen_audit=audit_file.relative_to(ROOT).as_posix(), reopen_audit_sha256=spec['audit_sha'],
                source_views=views.relative_to(ROOT).as_posix(), source_views_sha256=spec['views_sha'])
            files.append(row)
            prepared.append((temporary,target,row))
        for temporary,target,row in prepared:
            assert sha(target) == row['before_sha256']
            os.replace(temporary,target)
            replaced.append(row)
            assert sha(target) == row['after_sha256']
        for row in files:
            guards[row['target']] = row['after_sha256']
        assert all(sha(ROOT / p) == value for p,value in guards.items())
        report = dict(status='BOTH_ORIGINAL_BLENDS_PROMOTED', schema=1, tool_sha256=sha(__file__),
            created_utc=datetime.now(timezone.utc).isoformat(), files=files, protected_files=guards,
            approval=APPROVAL.relative_to(ROOT).as_posix(), approval_sha256=APPROVAL_SHA,
            boundary='Exact byte copies of separately reopened, source-rendered candidates. Fresh canonical-path Blender reopen audits still required. No Unreal map or asset write.')
        PROMOTION.write_text(json.dumps(report,indent=2)+'\n')
        return dict(status=report['status'], file=PROMOTION.relative_to(ROOT).as_posix(),sha256=sha(PROMOTION))
    except Exception as error:
        # Roll back only exact own child bytes. Never replace a foreign change.
        restored = []
        for row in reversed(replaced):
            target = ROOT / row['target']
            assert sha(target) == row['after_sha256'], 'Foreign change during promotion; inspect checkpoint before recovery'
            temporary = backup_folder / ('rollback_' + target.name)
            shutil.copy2(ROOT / row['backup'], temporary)
            assert sha(temporary) == row['before_sha256']
            os.replace(temporary,target)
            restored.append(row['target'])
        (backup_folder / 'failure.json').write_text(json.dumps(dict(error=repr(error),restored=restored,files=files),indent=2)+'\n')
        raise


def audit_promoted(name):
    import bpy
    h = helper()
    promotion = read(PROMOTION)
    assert promotion['status'] == 'BOTH_ORIGINAL_BLENDS_PROMOTED'
    row, = [r for r in promotion['files'] if r['library'] == name]
    path = ROOT / row['target']
    assert Path(bpy.data.filepath).resolve() == path.resolve() and sha(path) == row['after_sha256']
    stage = read(ROOT / row['stage_receipt'])
    sync, materials, geometry = h._helpers()
    current = sync.stable(sync.inventory())
    assert current == stage['inventory_after']
    h._validate_inventory(stage['inventory_before'],current,
        dict(wrappers=stage['wrappers'],materials=stage['candidate_material'],image=stage['candidate_image'],bindings=stage['bindings']))
    assert h._geometry_by_scene(sync,materials,h.SCENES) == stage['geometry_after']
    assert all(sha(ROOT / p) == value for p,value in promotion['protected_files'].items())
    output = RUN / ('canonical_reopen_' + name + '.json')
    assert not output.exists()
    report = dict(status='PROMOTED_LIBRARY_REOPEN_PASS', target=row['target'], sha256=row['after_sha256'],
        promotion_sha256=sha(PROMOTION), tool_sha256=sha(__file__), inventory_exact=True,
        geometry_exact=True, full_614_guards_exact=True)
    output.write_text(json.dumps(report,indent=2)+'\n')
    return dict(status=report['status'],file=output.relative_to(ROOT).as_posix(),sha256=sha(output))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--action',choices=('promote','audit'),required=True)
    parser.add_argument('--library',choices=tuple(SPECS))
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else None)
    if args.action == 'promote':
        print(json.dumps(promote()))
    else:
        assert args.library
        print(json.dumps(audit_promoted(args.library)))
