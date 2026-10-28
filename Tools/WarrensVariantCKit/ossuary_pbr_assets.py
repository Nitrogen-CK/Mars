"""Owned normal-only / roughness-only material copies; inert until create()."""
import copy
import hashlib
import importlib.util
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HELPER = Path(__file__).with_name('ossuary_material_assets.py')
HELPER_SHA = '7fc677d54a589837ed67631b02cffac2a73a6b4c8f4a31c9588f6d530c0101e5'
RECEIPT = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryMaterialTrial/assets_created_20261026T002324_985770Z_b8823bc5.json'
RECEIPT_SHA = 'a0745bdea6852636b7fe376cf605c2ebb3be58c1d7ac2e0577cedaa7777f4ea9'
OUT = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryPbrTrial'
OWNER = 'Mars.WarrensC.OssuaryPbrTrial.R01'


def editor_clean(u):
    editor = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    assert editor.get_game_world() is None
    assert editor.get_editor_world().get_path_name().split('.')[0] == '/Game/Mars/Maps/Variants/v8c/LI_Warrens_Ossuary'
    return u.EditorLoadingAndSavingUtils.get_dirty_map_packages() == [] and u.EditorLoadingAndSavingUtils.get_dirty_content_packages() == []


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save_receipt(kind, value):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / (kind + '_' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ') + '.json')
    assert not path.exists()
    path.write_text(json.dumps(dict(value, tool_sha256=sha(__file__)), indent=2) + '\n')
    return dict(receipt=path.relative_to(ROOT).as_posix(), sha256=sha(path))


def create():
    import unreal as u
    assert sha(HELPER) == HELPER_SHA and sha(RECEIPT) == RECEIPT_SHA
    spec = importlib.util.spec_from_file_location('_ossuary_pbr_frozen_assets', HELPER)
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    baseline = json.loads(RECEIPT.read_text())
    source_path = baseline['material_c']['path']
    source_file = ROOT / ('Content/' + source_path.removeprefix('/Game/') + '.uasset')
    assert sha(source_file) == baseline['material_c']['package_sha256']
    assert not u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    clean = dict(maps=[], content=[])
    assert editor_clean(u)
    guards = helper._protected_files()
    source = u.load_asset(source_path)
    assert isinstance(source, u.Material)
    assert u.EditorAssetLibrary.get_metadata_tag(source, helper.TAG) == helper.OWNER
    graph = helper._read_material_graph(u, source)
    assert graph == baseline['material_c']['graph']
    normal = graph['nodes']['MaterialExpressionTextureSample_6']
    masks = graph['nodes']['MaterialExpressionTextureSample_2']
    assert normal['texture'].endswith('T_CCK_TX01_LimestoneAshlar_NormalDX')
    assert masks['texture'].endswith('T_CCK_TX01_LimestoneAshlar_ORM')
    normal_texture = u.load_asset(normal['texture'])
    masks_texture = u.load_asset(masks['texture'])
    assert normal_texture.get_editor_property('srgb') is False
    assert normal_texture.get_editor_property('compression_settings') == u.TextureCompressionSettings.TC_NORMALMAP
    assert masks_texture.get_editor_property('srgb') is False
    assert masks_texture.get_editor_property('compression_settings') == u.TextureCompressionSettings.TC_MASKS
    choices = {
        'NormalOnly': ('MP_NORMAL', 'MaterialExpressionTextureSample_6', 'RGB'),
        'RoughnessOnly': ('MP_ROUGHNESS', 'MaterialExpressionTextureSample_2', 'G'),
    }
    paths = {key: source_path.rsplit('/', 1)[0] + '/M_Ossuary_TX01_R02_PBR_' + key for key in choices}
    for path in paths.values():
        assert not u.EditorAssetLibrary.does_asset_exist(path)
        assert not (ROOT / ('Content/' + path.removeprefix('/Game/') + '.uasset')).exists()
    created = []
    try:
        for key, (property_name, node_name, channel) in choices.items():
            material = u.EditorAssetLibrary.duplicate_asset(source_path, paths[key])
            assert isinstance(material, u.Material)
            nodes = {node.get_name(): node for node in u.ObjectIterator(u.MaterialExpression) if node.get_outer() == material}
            assert u.MaterialEditingLibrary.connect_material_property(nodes[node_name], channel,
                getattr(u.MaterialProperty, property_name))
            u.MaterialEditingLibrary.recompile_material(material)
            expected = copy.deepcopy(graph)
            expected['outputs'][property_name] = node_name
            expected['output_names'][property_name] = channel
            actual = helper._read_material_graph(u, material)
            assert actual == expected, ('Unexpected PBR graph delta', key, actual, expected)
            u.EditorAssetLibrary.set_metadata_tag(material, 'MarsWarrensCOssuaryPbrOwner', OWNER)
            assert u.EditorAssetLibrary.save_loaded_asset(material, False)
            file = ROOT / ('Content/' + paths[key].removeprefix('/Game/') + '.uasset')
            created.append(dict(stage=key, path=paths[key], package_sha256=sha(file), graph=actual,
                                only_delta=dict(property=property_name, node=node_name, channel=channel)))
        assert helper._protected_files() == guards
        assert helper._read_material_graph(u, source) == graph
        assert sha(source_file) == baseline['material_c']['package_sha256']
        assert editor_clean(u)
        return dict(status='TWO_OWNED_PBR_COPIES_CREATED', paths=paths,
            **save_receipt('created', dict(assets=created, source=source_path, source_graph=graph,
                protected_files=guards, dirty=clean,
                boundary='Only existing normal or roughness output is connected in each owned copy. No texture, AO, geometry, UV, light, source asset or map change. Trial only: existing joint relief may conflict with modeled masonry.')))
    except Exception as error:
        save_receipt('failure', dict(error=repr(error), completed=created, intended_paths=paths,
            boundary='Inspect partial owned assets; no automatic deletion or retry.'))
        raise
