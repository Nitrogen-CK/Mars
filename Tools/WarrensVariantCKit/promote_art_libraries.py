"""Promote reviewed v3 Blends, or independently reopen originals in Blender.

Only the two named source Blends can change; exact backups and a journal remain.
Run standard Python with --action promote; Blender with --action verify --target.
"""
import argparse
import json
from pathlib import Path
import shutil
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
import sync_art_libraries as sync

RUN = sync.RUN_ROOT / 'promoted-v3'
JOURNAL = RUN / 'promotion.json'
EXPECTED = {
    'KitLibrary': ('860cac453221d8b3d14657c822ac9d00c4d5411d99ad0d8c5c14b7972796afa2',
                   '50a54a4d7efbff84314cc6dfb303a2308fc801474ae8292d7cb050bfcfc388cf'),
    'Diorama': ('d6c09f86469a515bf47b5d8b2f9782e30950b8df58a9d7b26f38640703f64945',
                'ac79fa7e3636891688f95939815188e4cf92f67f607e139af28aeb6436500d5f'),
}


def write(path, value):
    assert path.resolve().is_relative_to(RUN.resolve())
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def protected(journal):
    current = sync.immutable_files()
    expected = dict(journal['protected_before'])
    for item in journal['targets'].values():
        expected[item['source']] = item['after_sha256']
    assert current == expected, 'Unapproved source/FBX/imported mesh/collision change'


def promote():
    if JOURNAL.exists():
        previous = sync.read(JOURNAL)
        assert previous['status'] == 'PROMOTED'
        assert previous['spec_sha256'] == sync.projection()['spec_sha256']
        protected(previous)
        print('BLEND_PROMOTION_NOOP', 0)
        return
    assert not RUN.exists(), 'Unrecorded promotion checkpoint'
    projection = sync.projection()
    baseline = sync.immutable_files()
    journal = dict(status='PREPARED', targets={}, protected_before=baseline, spec_sha256=projection['spec_sha256'],
                   tool_sha256=sync.sha(Path(__file__)), static_count=32646, catalog_count=196)
    for target, (before, after) in EXPECTED.items():
        source = sync.TARGETS[target]
        folder = sync.RUN_ROOT / 'staged-v3' / target
        receipt = sync.read(folder / 'stage.json')
        staged = sync.ROOT / receipt['stage_path']
        assert source.resolve().is_relative_to(sync.ROOT.resolve()) and staged.resolve().is_relative_to(sync.RUN_ROOT.resolve())
        assert sync.sha(source) == before and sync.sha(staged) == after
        assert receipt['status'] == 'STAGED' and receipt['stage_sha256'] == after and receipt['spec_sha256'] == projection['spec_sha256']
        audit = sync.read(folder / 'reopened_audit.json')
        assert audit['stage_sha256'] == after and audit['audit']['catalog_entries'] == 196
        assert audit['audit']['counts']['02_VariantC_Cutaway'] == 32646 and audit['audit']['counts']['Zone_Brineworks'] == 3667
        backup = RUN / 'Original' / source.name
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, backup)
        assert sync.sha(backup) == before
        journal['targets'][target] = dict(source=source.relative_to(sync.ROOT).as_posix(),
            staged=staged.relative_to(sync.ROOT).as_posix(), backup=backup.relative_to(sync.ROOT).as_posix(),
            before_sha256=before, after_sha256=after, stage_receipt=(folder / 'stage.json').relative_to(sync.ROOT).as_posix())
    write(JOURNAL, journal)
    try:
        for item in journal['targets'].values():
            source, staged = sync.ROOT / item['source'], sync.ROOT / item['staged']
            assert sync.sha(source) == item['before_sha256']
            pending = source.with_suffix('.promotion-part')
            assert not pending.exists()
            shutil.copy2(staged, pending)
            assert sync.sha(pending) == item['after_sha256']
            pending.replace(source)
        protected(journal)
        journal['status'] = 'PROMOTED'
        write(JOURNAL, journal)
        print('BLEND_PROMOTED', {k: v['after_sha256'] for k, v in journal['targets'].items()})
    except Exception as error:
        journal.update(status='FAILED_REVIEW_REQUIRED', error=str(error))
        write(JOURNAL, journal)
        raise


def verify(target):
    import bpy
    journal = sync.read(JOURNAL)
    assert journal['status'] == 'PROMOTED'
    projection = sync.projection()
    assert journal['spec_sha256'] == projection['spec_sha256']
    item = journal['targets'][target]
    original = sync.ROOT / item['source']
    assert sync.sha(original) == item['after_sha256']
    protected(journal)
    folder = sync.RUN_ROOT / 'staged-v3' / target
    receipt = sync.read(folder / 'stage.json')
    bpy.ops.wm.open_mainfile(filepath=str(original))
    audit, _ = sync.effective_audit(projection, sync.read(folder / 'original_inventory.json'), receipt['changes'])
    assert sync.sha(original) == item['after_sha256']
    protected(journal)
    report = dict(status='REOPENED_ORIGINAL_VERIFIED', source=item['source'], source_sha256=item['after_sha256'],
                  spec_sha256=projection['spec_sha256'], audit=audit, protected_file_count=len(journal['protected_before']))
    write(RUN / (target + '_reopened.json'), report)
    print('PROMOTED_ORIGINAL_VERIFIED', target, audit['counts'], audit['catalog_entries'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--action', choices=('promote', 'verify'), required=True)
    parser.add_argument('--target', choices=tuple(EXPECTED))
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else None)
    if args.action == 'promote':
        promote()
    else:
        assert args.target
        verify(args.target)


if __name__ == '__main__':
    main()
