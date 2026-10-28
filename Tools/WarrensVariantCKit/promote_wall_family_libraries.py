"""Promote reviewed library copies with byte backups and canonical reopen audits."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'Tools/WarrensVariantCKit/Output'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(relative, digest):
    path = (ROOT / relative).resolve()
    assert path.is_relative_to(ROOT.resolve()) and path.is_file() and sha(path) == digest
    return path, json.loads(path.read_text())


def contract(manifest_path, manifest_sha):
    file, c = read(manifest_path, manifest_sha)
    assert c['tool_sha256'] == sha(__file__)
    assert c['status'] == 'REVIEWED_TWO_LIBRARY_PROMOTION'
    assert {row['library'] for row in c['libraries']} == {'Diorama', 'KitLibrary'}
    review = (ROOT / c['review']['path']).resolve()
    assert review.is_relative_to(ROOT.resolve()) and sha(review) == c['review']['sha256']
    _, restored = read(c['required_restoration']['path'], c['required_restoration']['sha256'])
    assert restored['status'] == c['required_restoration']['status']
    assert restored['dirty'] == dict(maps=[], content=[]) and restored['pie'] is False
    assert restored['trial_state_cleared'] is True
    assert all(sha(ROOT / p) == d for p, d in restored['immutable_guards'].items())
    return file, c


def promote(manifest_path, manifest_sha):
    manifest, c = contract(manifest_path, manifest_sha)
    run = manifest.parent
    output = run / 'promotion.json'
    assert not output.exists()
    backups = run / ('canonical_backups_' + uuid.uuid4().hex)
    backups.mkdir()
    files, prepared, replaced = [], [], []
    common_guards = None
    try:
        for spec in c['libraries']:
            stage_file, stage = read(spec['stage']['path'], spec['stage']['sha256'])
            audit_file, audit = read(spec['audit']['path'], spec['audit']['sha256'])
            views_file, views = read(spec['views']['path'], spec['views']['sha256'])
            assert stage['status'] == 'DERIVED_LIBRARY_STAGE_REOPEN_AUDIT_REQUIRED'
            assert audit['status'] == 'SEPARATE_PROCESS_REOPEN_AUDIT_PASS'
            assert audit['stage_receipt_sha256'] == spec['stage']['sha256']
            assert views['status'] == 'MATCHED_LIBRARY_SOURCE_VIEWS_RENDERED'
            assert views['stage_receipt'] == spec['stage'] and views['audit_receipt'] == spec['audit']
            assert stage['library'] == audit['library'] == views['library'] == spec['library']
            assert stage['geometry_before'] == stage['geometry_after']
            assert stage['inventory_counts'] == c['expected_inventory_delta']
            assert stage['selected_source_keys'] == c['selected_source_keys']
            assert len(stage['bindings']) == c['expected_inventory_delta']['selected_placement_bindings']
            source = ROOT / stage['staged_blend']
            assert sha(source) == stage['staged_blend_sha256'] == audit['staged_blend_sha256'] == views['source_sha256']
            assert len(views['frames']) == c['expected_view_count']
            assert all(sha(ROOT / frame['file']) == frame['sha256'] for frame in views['frames'])
            target = (ROOT / stage['source_blend']).resolve()
            assert target.is_relative_to(OUTPUT.resolve()) and target.parent == OUTPUT.resolve()
            assert target.name == 'WarrensVariantC_' + spec['library'] + '.blend'
            before, after = stage['source_blend_sha256'], stage['staged_blend_sha256']
            assert sha(target) == before and before != after
            guards = stage['immutable_file_guards']
            assert all(sha(ROOT / path) == digest for path, digest in guards.items())
            assert common_guards is None or guards == common_guards
            common_guards = dict(guards)
            backup = backups / target.name
            temporary = backups / ('new_' + target.name)
            shutil.copy2(target, backup)
            shutil.copy2(source, temporary)
            assert sha(backup) == before and sha(temporary) == after
            row = dict(library=spec['library'], target=target.relative_to(ROOT).as_posix(),
                before_sha256=before, after_sha256=after, backup=backup.relative_to(ROOT).as_posix(),
                stage=spec['stage'], audit=spec['audit'], views=spec['views'])
            files.append(row)
            prepared.append((temporary, target, row))
        assert len(prepared) == 2
        for temporary, target, row in prepared:
            assert sha(target) == row['before_sha256']
            os.replace(temporary, target)
            replaced.append(row)
            assert sha(target) == row['after_sha256']
        for row in files:
            common_guards[row['target']] = row['after_sha256']
        assert all(sha(ROOT / p) == d for p, d in common_guards.items())
        result = dict(status='BOTH_ORIGINAL_WALL_LIBRARIES_PROMOTED', tool_sha256=sha(__file__),
            manifest=dict(path=manifest.relative_to(ROOT).as_posix(), sha256=manifest_sha),
            files=files, immutable_guards_after=common_guards,
            boundary='Exact bytes of separately reopened and visually reviewed candidates. Fresh canonical-path Blender reopens are required; no Unreal asset/map write.')
        output.write_text(json.dumps(result, indent=2) + '\n')
        return dict(file=output.relative_to(ROOT).as_posix(), sha256=sha(output), status=result['status'])
    except Exception as error:
        restored = []
        for row in reversed(replaced):
            target = ROOT / row['target']
            assert sha(target) == row['after_sha256'], 'Foreign file changed; inspect backups before recovery'
            temporary = backups / ('rollback_' + target.name)
            shutil.copy2(ROOT / row['backup'], temporary)
            assert sha(temporary) == row['before_sha256']
            os.replace(temporary, target)
            restored.append(row['target'])
        (backups / 'failure.json').write_text(json.dumps(dict(error=repr(error), restored=restored, files=files), indent=2) + '\n')
        raise


def audit_canonical(promotion_path, promotion_sha, library):
    import bpy
    file, promotion = read(promotion_path, promotion_sha)
    assert promotion['status'] == 'BOTH_ORIGINAL_WALL_LIBRARIES_PROMOTED'
    assert promotion['tool_sha256'] == sha(__file__)
    row, = [item for item in promotion['files'] if item['library'] == library]
    target = ROOT / row['target']
    assert Path(bpy.data.filepath).resolve() == target.resolve() and sha(target) == row['after_sha256']
    _, stage = read(row['stage']['path'], row['stage']['sha256'])
    _, c = read(stage['config'], stage['config_sha256'])
    tool = ROOT / stage['tool_path']
    assert sha(tool) == stage['tool_sha256']
    spec = importlib.util.spec_from_file_location('_canonical_wall_library_audit', tool)
    h = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(h)
    sync, materials, geometry, projection = h._helpers(c)
    assert h.stable(sync.inventory()) == stage['inventory_after']
    assert h._geometry_by_scene(bpy, geometry, stage['target_scenes']) == stage['geometry_after']
    assert all(sha(ROOT / p) == d for p, d in promotion['immutable_guards_after'].items())
    out = file.parent / ('canonical_reopen_' + library + '.json')
    assert not out.exists()
    result = dict(status='CANONICAL_WALL_LIBRARY_REOPEN_PASS', library=library,
        target=row['target'], target_sha256=row['after_sha256'],
        promotion=dict(path=promotion_path, sha256=promotion_sha),
        inventory_exact=True, geometry_exact=True, guard_count=len(promotion['immutable_guards_after']),
        immutable_guards_exact=True, tool_sha256=sha(__file__))
    out.write_text(json.dumps(result, indent=2) + '\n')
    return dict(file=out.relative_to(ROOT).as_posix(), sha256=sha(out), status=result['status'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--action', choices=('promote', 'audit'), required=True)
    parser.add_argument('--receipt', required=True)
    parser.add_argument('--sha256', required=True)
    parser.add_argument('--library')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else None)
    result = promote(args.receipt, args.sha256) if args.action == 'promote' else audit_canonical(args.receipt, args.sha256, args.library)
    print(json.dumps(result), flush=True)
