"""Create three absent private RoomTint masters; never bind or save source worlds."""
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'
FOLDER = '/Game/Mars/ArtReview/Lookdev/RoomRollout_20261027R01/Materials'
STATE = {}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(name):
    path = Path(__file__).with_name(name+'.py')
    spec = importlib.util.spec_from_file_location('_owned_tint_'+name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def disk(asset):
    return ROOT/('Content/'+asset.removeprefix('/Game/')+'.uasset')


def dirty():
    import unreal as u
    return dict(maps=[p.get_path_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_map_packages()], content=[p.get_path_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()])


def guard():
    load('room_art_capture_r33').guard()
    roof = load('larder_high_roof_assets_r01')
    roof.guard()
    roof_receipt = json.loads((ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/roof-completion-export-r01/native_asset.json').read_text())
    assert sha(disk(roof_receipt['target'])) == roof_receipt['package_sha256']
    for family in ('Walls', 'Floor', 'Ceiling'):
        receipt = DOC/('owned_'+family.lower()+'_master_r01.json')
        if receipt.exists():
            row = json.loads(receipt.read_text())
            assert sha(disk(row['target'])) == row['package_sha256']


def gate():
    data = json.loads((DOC/'NATIVE_ROOM_TINT_ASSETS_GATE_R01.json').read_text())
    assert data['status'] == 'APPROVED_THREE_ABSENT_PRIVATE_ROOM_TINT_MASTERS_ONLY'
    assert data['tool_sha256'] == sha(__file__)
    for path, digest in data['input_sha256'].items():
        assert sha(ROOT/path) == digest
    return data


def validate(material, family):
    import unreal as u
    proof = json.loads((DOC/'room_tint_transient_builds_r01.json').read_text())['families'][family]
    values = load('material_graph_values_r02')
    links = load('material_graph_links_r01')
    snapshots = load('catacomb_plane_normal_materials')
    assert values.read(material) == proof['destination_explicit_values']
    assert links.read(material) == proof['destination_links']
    actual = snapshots.snapshot(material)
    expected = json.loads(json.dumps(proof['destination_full_graph']).replace(proof['destination'], material.get_path_name()))
    assert actual == expected
    original = u.load_asset(proof['source'])
    assert snapshots.snapshot(original)['properties'] == proof['source_properties']
    assert values.read(original) == proof['source_values'] and links.read(original) == proof['source_links']
    assert sha(disk(original.get_path_name().split('.')[0])) == proof['source_sha256']
    assert u.MaterialEditingLibrary.get_material_default_vector_parameter_value(material, 'RoomTint').to_tuple() == (1., 1., 1., 1.)
    stats = u.MaterialEditingLibrary.get_statistics(material)
    stats_row = {key: getattr(stats, key) for key in proof['compile_statistics']}
    assert stats_row == proof['compile_statistics']
    return dict(graph=actual, explicit_values=values.read(material), links=links.read(material), compile_statistics=stats_row)


def create(family):
    import unreal as u
    assert family in ('Walls', 'Floor', 'Ceiling') and family not in STATE
    assert Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve() == ROOT.resolve()
    approved = gate()
    guard()
    assert dirty() == dict(maps=[], content=[])
    ed = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    assert ed.get_game_world() is None and ed.get_editor_world().get_path_name() == '/Game/Mars/Maps/Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    name = 'M_WVC_'+family+'_RoomTint_R01'
    target = FOLDER+'/'+name
    attempt = DOC/('owned_'+family.lower()+'_master_attempt_r01.json')
    assert target in approved['targets'] and not attempt.exists() and not u.EditorAssetLibrary.does_asset_exist(target) and not disk(target).exists()
    settings = u.get_default_object(u.load_class(None, '/Script/UnrealEd.EditorLoadingSavingSettings'))
    autosave = settings.get_editor_property('bAutoSaveEnable')
    jolt = u.get_default_object(u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'))
    cook = jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    attempt.write_text(json.dumps(dict(status='ONE_ABSENT_PRIVATE_ASSET_ATTEMPT_NO_FACTORY_RETRY', target=target, tool_sha256=sha(__file__), autosave=autosave, cook=str(cook)), indent=2)+'\n')
    try:
        settings.set_editor_property('bAutoSaveEnable', False)
        jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave', u.Ck_EnableDisable.DISABLE)
        assert settings.get_editor_property('bAutoSaveEnable') is False
        assert jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave') == u.Ck_EnableDisable.DISABLE
        material = u.AssetToolsHelpers.get_asset_tools().create_asset(name, FOLDER, u.Material, u.MaterialFactoryNew())
        assert material and material.get_path_name().split('.')[0] == target
        STATE[family] = dict(stage='PENDING_VALIDATION_NO_FACTORY_RETRY', asset=material, target=target)
        build = load('room_tint_master_build_r02').build(material, family)
        STATE[family]['build'] = build
        readback = validate(material, family)
        guard()
        assert dirty() == dict(maps=[], content=[target])
        u.EditorAssetLibrary.set_metadata_tag(material, 'Owner', 'Mars.WarrensVariantC.RoomRollout.RoomTint.R01')
        assert u.EditorAssetLibrary.save_loaded_asset(material, False)
        assert validate(material, family) == readback
        assert dirty() == dict(maps=[], content=[])
        guard()
        receipt = dict(status='PRIVATE_ROOM_TINT_MASTER_SAVED_NOT_BOUND_OR_PALETTE_ACCEPTED', family=family, target=target, package_sha256=sha(disk(target)), tool_sha256=sha(__file__), gate_sha256=sha(DOC/'NATIVE_ROOM_TINT_ASSETS_GATE_R01.json'), build=build, readback=readback, boundary='New private asset only; exact accepted white-copy graph values, pin/channels, readable properties and completed compile statistics. No source parent, texture, geometry, map or library edits. Nonwhite native palettes and room appearance remain pending.')
        (DOC/('owned_'+family.lower()+'_master_r01.json')).write_text(json.dumps(receipt, indent=2)+'\n')
        STATE[family]['stage'] = 'SAVED_NOT_BOUND'
        guard()
        print('PRIVATE_ROOM_TINT_MASTER_SAVED', family, receipt['package_sha256'])
    finally:
        settings.set_editor_property('bAutoSaveEnable', autosave)
        jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave', cook)
        assert settings.get_editor_property('bAutoSaveEnable') == autosave and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave') == cook
