"""Prepare and create owned Unreal assets for the approved Ossuary albedo trial.

Importing this module is inert. Call preflight() first, then explicitly call
create_assets(receipt_path, receipt_sha256) in Unreal Editor Python. Only the
new texture and two owned material copies are saved; no source asset or map is
written.
"""
import hashlib
import json
import re
import struct
import uuid
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
CHECKPOINT = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryMaterialTrial'

SOURCE_READY = ROOT / 'Saved/WarrensCGameplay-20261024/MechanismLayoutCheckpoint/source_layout_20261025T090434_092884Z_1e6e87b9.json'
SOURCE_READY_SHA = 'a23c2d371433c647061446bbcd822d138094bf2774f739d364622a8ea8ab260f'
RECOVERY = ROOT / 'Saved/WarrensCGameplay-20261024/MechanismLayoutCheckpoint/second_attempt_recovery/restored.json'
RECOVERY_SHA = 'e29a4d6bd8cc02621e7604845cc85b76ed22225c3320f5f93f7b4f847174b7e4'

REVIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024'
APPROVAL = REVIEW / 'OSSUARY_MATERIAL_CANDIDATE_REVIEW.md'
APPROVAL_SHA = '459d544d53297d34c7a9bac1e80e8e053e22bc52bc5b768fcb9b05083d4a8237'
IMAGE = REVIEW / 'lookdev/ossuary-painterly-r01/Ossuary_PainterlyStone_Albedo_Quiet_r02.png'
IMAGE_SHA = '3ddb6bd818cb98422fd6594a0c6539455222e3b876f1a67cf3a91a540a4d127f'
PREVIEW_RECEIPT = REVIEW / 'lookdev/ossuary-painterly-r01/room-preview-r02/receipt.json'
PREVIEW_RECEIPT_SHA = '3100a2046fd5b713b5683333b3fd6a44067c2eddc7a088e6b8f82834926fd291'
PREVIEW_BLEND = REVIEW / 'lookdev/ossuary-painterly-r01/room-preview-r02/Ossuary_PainterlyStone_Candidate.blend'
PREVIEW_BLEND_SHA = '7c4e636bded992d2f1f6b4384d84de86254c3fef54e6f25c0d0c53880acb740c'
LIVE_GRAPH = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryMaterialCandidate/runtime_TX01_graph.json'
LIVE_GRAPH_SHA = 'e4f583a7b76afcdda2d8604e8e642fac5973b1d539791508b2a03a13910cf43e'
SOURCE_MATERIAL = '/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX01'
SOURCE_MATERIAL_FILE = ROOT / 'Content/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX01.uasset'
SOURCE_MATERIAL_SHA = '8cdf0cda072b3d3d95a57cc4d24e70af4ca09323910e896ac79b90cbd67d96a4'

DEST = '/Game/Mars/ArtReview/Lookdev/OssuaryPainterly_20261025'
OWNER = 'Mars.WarrensC.OssuaryPainterly.R02.20261025'
TAG = 'MarsWarrensCOssuaryPainterlyOwner'
TEXTURE_PATH = DEST + '/Textures/T_Ossuary_TX01_R02_Albedo'
MATERIAL_B_PATH = DEST + '/Materials/M_Ossuary_TX01_R02_B_SourceAlbedo_Mix060'
MATERIAL_C_PATH = DEST + '/Materials/M_Ossuary_TX01_R02_C_PainterlyAlbedo_Mix060'
MIX_FACTOR = 0.60
EXPECTED_NODES = {
    'MaterialExpressionTextureSample_3', 'MaterialExpressionTextureSample_0',
    'MaterialExpressionTextureSample_2', 'MaterialExpressionTextureSample_6',
    'MaterialExpressionConstant3Vector_0', 'MaterialExpressionConstant_0',
    'MaterialExpressionLinearInterpolate_0', 'MaterialExpressionConstant_1',
    'MaterialExpressionConstant_2',
}
MAP_PACKAGE = '/Game/Mars/Maps/Warrens_VariantC_Mars_MAP'


def _sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def _u():
    import unreal
    return unreal


def _package(asset):
    return asset.get_path_name().split('.')[0] if asset else None


def _write_unique(prefix, record):
    CHECKPOINT.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ') + '_' + uuid.uuid4().hex[:8]
    path = CHECKPOINT / (prefix + '_' + stamp + '.json')
    assert not path.exists()
    record.update(schema=1, created_utc=datetime.now(timezone.utc).isoformat(), tool_sha256=_sha(__file__))
    path.write_text(json.dumps(record, sort_keys=True, indent=2, allow_nan=False) + '\n', encoding='utf-8')
    return path


def _editor_state(u):
    ed = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    assert ed.get_game_world() is None, 'Stop PIE before material asset work'
    world = ed.get_editor_world()
    assert world and world.get_path_name().split('.')[0] == MAP_PACKAGE, ('Wrong editor map', world.get_path_name() if world else None)
    dirty_maps = sorted(_package(p) for p in u.EditorLoadingAndSavingUtils.get_dirty_map_packages())
    dirty_content = sorted(_package(p) for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages())
    return dict(map=MAP_PACKAGE, dirty_maps=dirty_maps, dirty_content=dirty_content)


def _protected_files():
    assert _sha(SOURCE_READY) == SOURCE_READY_SHA, '614-file source baseline receipt changed'
    assert _sha(RECOVERY) == RECOVERY_SHA, 'Source restore receipt changed'
    baseline = _json(SOURCE_READY)
    recovery = _json(RECOVERY)
    assert baseline.get('phase') == 'RELIQUARY_READY' and baseline.get('schema') == 1
    guarded = baseline.get('initial_614_guards')
    assert isinstance(guarded, dict) and len(guarded) == 614, 'Unexpected protected-file roster'
    assert recovery.get('status') == 'ALL_614_FILES_AND_54_COLLISION_FILES_RESTORED_EDITOR_CLOSED'
    assert recovery.get('baseline_sha256') == SOURCE_READY_SHA
    assert recovery.get('all_614_exact') is True and recovery.get('collision_54_exact') is True
    assert recovery.get('all_original_map_bytes_unchanged') is True
    assert all(_sha(ROOT / rel) == expected for rel, expected in guarded.items()), 'Protected source file changed'
    return guarded


def _expected_graph_contract(graph):
    assert graph.get('asset_path') == SOURCE_MATERIAL
    nodes = {node['id']: node for node in graph.get('nodes', [])}
    assert set(nodes) == EXPECTED_NODES and len(nodes) == 9
    assert nodes['MaterialExpressionConstant_0']['class'] == 'Constant'
    assert abs(float(nodes['MaterialExpressionConstant_0']['props']['R']) - 0.12) < 1e-6
    assert abs(float(nodes['MaterialExpressionConstant_1']['props']['R']) - 0.88) < 1e-6
    assert float(nodes['MaterialExpressionConstant_2']['props']['R']) == 0.0
    assert nodes['MaterialExpressionTextureSample_0']['props']['Texture'].endswith(
        '/T_CCK_TX01_LimestoneAshlar_BaseColor.T_CCK_TX01_LimestoneAshlar_BaseColor\'')
    assert nodes['MaterialExpressionTextureSample_0']['props']['SamplerType'] == 'SAMPLERTYPE_Color'
    assert nodes['MaterialExpressionTextureSample_2']['props']['SamplerType'] == 'SAMPLERTYPE_Masks'
    assert nodes['MaterialExpressionTextureSample_6']['props']['SamplerType'] == 'SAMPLERTYPE_Normal'
    assert len(graph.get('connections', [])) == 3
    assert {(row['to_property'], row['from']) for row in graph.get('outputs', [])} == {
        ('BaseColor', 'MaterialExpressionLinearInterpolate_0'),
        ('Roughness', 'MaterialExpressionConstant_1'),
        ('Metallic', 'MaterialExpressionConstant_2'),
    }
    assert not graph.get('custom_hlsl_nodes')
    return graph


def _source_material_properties(u, material):
    def path(name):
        value = material.get_editor_property(name)
        return value.get_path_name() if value else None
    return dict(blend_mode=str(material.get_editor_property('blend_mode')),
        two_sided=bool(material.get_editor_property('two_sided')),
        used_with_instanced_static_meshes=bool(material.get_editor_property('used_with_instanced_static_meshes')),
        phys_material=path('phys_material'), phys_material_mask=path('phys_material_mask'))


def _asset_paths_absent(u):
    for path in (TEXTURE_PATH, MATERIAL_B_PATH, MATERIAL_C_PATH):
        disk = ROOT / ('Content/' + path.removeprefix('/Game/') + '.uasset')
        assert not disk.exists() and not u.EditorAssetLibrary.does_asset_exist(path), ('Refuse existing target', path)


def preflight():
    """Read-only preflight; returns a unique receipt path and SHA for creation."""
    u = _u()
    editor = _editor_state(u)
    assert editor['dirty_maps'] == [] and editor['dirty_content'] == [], 'Asset preflight requires clean editor packages'
    guarded = _protected_files()
    for path, expected in ((APPROVAL, APPROVAL_SHA), (IMAGE, IMAGE_SHA),
                           (PREVIEW_RECEIPT, PREVIEW_RECEIPT_SHA), (PREVIEW_BLEND, PREVIEW_BLEND_SHA),
                           (LIVE_GRAPH, LIVE_GRAPH_SHA), (SOURCE_MATERIAL_FILE, SOURCE_MATERIAL_SHA)):
        assert path.is_file() and _sha(path) == expected, ('Approved input changed', str(path))
    expected_graph = _expected_graph_contract(_json(LIVE_GRAPH))
    source = u.load_asset(SOURCE_MATERIAL)
    assert isinstance(source, u.Material) and _package(source) == SOURCE_MATERIAL
    assert _sha(SOURCE_MATERIAL_FILE) == SOURCE_MATERIAL_SHA
    source_graph = _read_material_graph(u, source)
    _assert_live_source_graph(source_graph, expected_graph)
    preview = _json(PREVIEW_RECEIPT)
    assert preview.get('status') == 'OFFLINE_STATIC_MATERIAL_COMPARISON_RENDERED'
    assert preview.get('candidate_blend_sha256') == PREVIEW_BLEND_SHA
    assert preview.get('tx01_material_slot_usage_count') == 1194
    assert preview.get('evidence_boundary') and len(preview['evidence_boundary']) >= 4
    _asset_paths_absent(u)
    receipt = dict(phase='asset_preflight', status='READ_ONLY_PREPARED', editor=editor,
        source_ready=dict(path=SOURCE_READY.relative_to(ROOT).as_posix(), sha256=SOURCE_READY_SHA,
                          protected_file_count=len(guarded)),
        recovery=dict(path=RECOVERY.relative_to(ROOT).as_posix(), sha256=RECOVERY_SHA,
                      all_614_exact=True, collision_54_exact=True),
        protected_files=guarded,
        inputs={p.relative_to(ROOT).as_posix(): _sha(p) for p in
                (APPROVAL, IMAGE, PREVIEW_RECEIPT, PREVIEW_BLEND, LIVE_GRAPH, SOURCE_MATERIAL_FILE)},
        source_material=dict(path=SOURCE_MATERIAL, graph=source_graph,
                             package_sha256=SOURCE_MATERIAL_SHA),
        targets=dict(texture=TEXTURE_PATH, material_b=MATERIAL_B_PATH, material_c=MATERIAL_C_PATH,
                     all_absent=True),
        boundary='Read-only preflight. No asset import, material duplication, map mutation, or save.')
    path = _write_unique('asset_preflight', receipt)
    return dict(receipt=path.relative_to(ROOT).as_posix(), sha256=_sha(path), status=receipt['status'],
                targets=receipt['targets'])


def _read_material_graph(u, material):
    mel = u.MaterialEditingLibrary
    properties = ('MP_BASE_COLOR', 'MP_ROUGHNESS', 'MP_METALLIC', 'MP_NORMAL', 'MP_AMBIENT_OCCLUSION',
                  'MP_EMISSIVE_COLOR', 'MP_OPACITY', 'MP_OPACITY_MASK')
    outputs = {}
    output_names = {}
    for key in properties:
        prop = getattr(u.MaterialProperty, key)
        node = mel.get_material_property_input_node(material, prop)
        outputs[key] = node.get_name() if node else None
        output_names[key] = str(mel.get_material_property_input_node_output_name(material, prop))
    nodes = {node.get_name(): node for node in u.ObjectIterator(u.MaterialExpression) if node.get_outer() == material}
    assert len(nodes) == mel.get_num_material_expressions(material) == 9
    rows = {}
    for name, node in nodes.items():
        input_names = list(mel.get_material_expression_input_names(node))
        inputs = list(mel.get_inputs_for_material_expression(material, node))
        assert len(input_names) == len(inputs)
        row = dict(type=node.get_class().get_name(), inputs={str(pin): value.get_name() if value else None
                                                             for pin, value in zip(input_names, inputs)},
                   input_output_names={str(pin): mel.get_input_node_output_name_for_material_expression(node, value)
                                       if value else None for pin, value in zip(input_names, inputs)})
        assert all(output is None or isinstance(output, str) for output in row['input_output_names'].values())
        assert all(value is None or row['input_output_names'][str(pin)] is not None
                   for pin, value in zip(input_names, inputs)), (
            'A connected material expression output was not observable', name)
        if isinstance(node, u.MaterialExpressionConstant):
            row['r'] = float(node.get_editor_property('r'))
        elif isinstance(node, u.MaterialExpressionConstant3Vector):
            color = node.get_editor_property('constant')
            row['constant'] = [float(color.r), float(color.g), float(color.b), float(color.a)]
        elif isinstance(node, u.MaterialExpressionTextureSample):
            row.update(texture=_package(node.get_editor_property('texture')),
                       sampler_type=str(node.get_editor_property('sampler_type')),
                       sampler_source=str(node.get_editor_property('sampler_source')))
        elif isinstance(node, u.MaterialExpressionLinearInterpolate):
            row.update(const_a=float(node.get_editor_property('const_a')),
                       const_b=float(node.get_editor_property('const_b')),
                       const_alpha=float(node.get_editor_property('const_alpha')))
        else:
            raise AssertionError(('Unexpected TX01 expression type', name, row['type']))
        rows[name] = row
    properties_snapshot = _source_material_properties(u, material)
    return dict(outputs=outputs, output_names=output_names, nodes=rows, material=properties_snapshot)


def _asset_package_from_export(value):
    match = re.search(r"'(/Game/[^']+)'", value)
    assert match, ('Unexpected Texture property serialization', value)
    return match.group(1).split('.')[0]


def _assert_live_source_graph(graph, expected):
    baseline_nodes = {node['id']: node for node in expected['nodes']}
    assert set(graph['nodes']) == set(baseline_nodes) == EXPECTED_NODES
    type_names = dict(Constant='MaterialExpressionConstant', Constant3Vector='MaterialExpressionConstant3Vector',
                      TextureSample='MaterialExpressionTextureSample', LinearInterpolate='MaterialExpressionLinearInterpolate')
    for name, old in baseline_nodes.items():
        current = graph['nodes'][name]
        assert current['type'] == type_names[old['class']], (name, current['type'], old['class'])
        if old['class'] == 'Constant':
            assert abs(current['r'] - float(old['props']['R'])) < 1e-6
        elif old['class'] == 'Constant3Vector':
            values = [float(v) for v in re.findall(r'(?:R|G|B|A)=([0-9.]+)', old['props']['Constant'])]
            assert len(values) == 4 and max(abs(a-b) for a, b in zip(current['constant'], values)) < 2e-6
        elif old['class'] == 'TextureSample':
            assert current['texture'] == _asset_package_from_export(old['props']['Texture'])
            sampler_type_names = {
                'SAMPLERTYPE_Color': 'SAMPLERTYPE_COLOR',
                'SAMPLERTYPE_Masks': 'SAMPLERTYPE_MASKS',
                'SAMPLERTYPE_Normal': 'SAMPLERTYPE_NORMAL',
            }
            sampler_source_names = {
                'SSM_FromTextureAsset': 'SSM_FROM_TEXTURE_ASSET',
            }
            actual_type_name = current['sampler_type'].partition('.')[2].partition(':')[0]
            actual_source_name = current['sampler_source'].partition('.')[2].partition(':')[0]
            assert actual_type_name == sampler_type_names[old['props']['SamplerType']]
            assert actual_source_name == sampler_source_names[old['props']['SamplerSource']]
        elif old['class'] == 'LinearInterpolate':
            assert current['const_a'] == float(old['props']['ConstA'])
            assert current['const_b'] == float(old['props']['ConstB'])
            assert current['const_alpha'] == float(old['props']['ConstAlpha'])
    expected_links = {(row['from'], row['to'], row['to_pin']) for row in expected['connections']}
    actual_links = {(source, target, pin) for target, node in graph['nodes'].items()
                    for pin, source in node['inputs'].items() if source is not None}
    assert actual_links == expected_links, ('Material expression links differ', actual_links, expected_links)
    expected_outputs = {'MP_BASE_COLOR': 'MaterialExpressionLinearInterpolate_0',
                        'MP_ROUGHNESS': 'MaterialExpressionConstant_1',
                        'MP_METALLIC': 'MaterialExpressionConstant_2'}
    assert graph['outputs'] == {key: expected_outputs.get(key) for key in graph['outputs']}
    assert graph['nodes']['MaterialExpressionLinearInterpolate_0']['input_output_names'].get('B') == 'RGB'


def _assert_graph_delta(source, candidate, stage):
    expected = json.loads(json.dumps(source))
    alpha = expected['nodes']['MaterialExpressionConstant_0']
    alpha['r'] = struct.unpack('f', struct.pack('f', MIX_FACTOR))[0]
    if stage == 'C':
        sample = expected['nodes']['MaterialExpressionTextureSample_0']
        sample['texture'] = TEXTURE_PATH
    assert candidate == expected, ('Unexpected material graph or settings change', stage)
    assert candidate['outputs'] == source['outputs'] and candidate['output_names'] == source['output_names']
    assert candidate['material'] == source['material']


def _set_owner(u, asset, **metadata):
    eal = u.EditorAssetLibrary
    eal.set_metadata_tag(asset, TAG, OWNER)
    for name, value in metadata.items():
        eal.set_metadata_tag(asset, name, str(value))


def _import_texture(u):
    task = u.AssetImportTask()
    for name, value in dict(filename=str(IMAGE), destination_path=DEST + '/Textures',
            destination_name=TEXTURE_PATH.rsplit('/', 1)[1], automated=True,
            replace_existing=False, replace_existing_settings=False, save=False,
            async_=False, factory=u.TextureFactory()).items():
        task.set_editor_property(name, value)
    u.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
    imported = [str(path) for path in task.get_editor_property('imported_object_paths')]
    assert any(path.split('.')[0] == TEXTURE_PATH for path in imported), ('Texture import missed target', imported)
    texture = u.load_asset(TEXTURE_PATH)
    assert isinstance(texture, u.Texture2D) and _package(texture) == TEXTURE_PATH
    _set_owner(u, texture, SourceSHA256=IMAGE_SHA, SourcePath=IMAGE.relative_to(ROOT).as_posix())
    texture.set_editor_property('srgb', True)
    texture.set_editor_property('compression_settings', u.TextureCompressionSettings.TC_DEFAULT)
    texture.set_editor_property('address_x', u.TextureAddress.TA_WRAP)
    texture.set_editor_property('address_y', u.TextureAddress.TA_WRAP)
    texture.set_editor_property('power_of_two_mode', u.TexturePowerOfTwoSetting.RESIZE_TO_SPECIFIC_RESOLUTION)
    texture.set_editor_property('resize_during_build_x', 1024)
    texture.set_editor_property('resize_during_build_y', 1024)
    texture.set_editor_property('mip_gen_settings', u.TextureMipGenSettings.TMGS_FROM_TEXTURE_GROUP)
    settings = dict(srgb=texture.get_editor_property('srgb'),
        compression_settings=str(texture.get_editor_property('compression_settings')),
        address_x=str(texture.get_editor_property('address_x')), address_y=str(texture.get_editor_property('address_y')),
        power_of_two_mode=str(texture.get_editor_property('power_of_two_mode')),
        resize_during_build_x=int(texture.get_editor_property('resize_during_build_x')),
        resize_during_build_y=int(texture.get_editor_property('resize_during_build_y')),
        mip_gen_settings=str(texture.get_editor_property('mip_gen_settings')),
        runtime_size_x=int(texture.blueprint_get_size_x()),
        runtime_size_y=int(texture.blueprint_get_size_y()),
        source_image_sha256=IMAGE_SHA)
    assert settings['srgb'] is True and settings['resize_during_build_x'] == settings['resize_during_build_y'] == 1024
    assert texture.get_editor_property('address_x') == u.TextureAddress.TA_WRAP
    assert texture.get_editor_property('address_y') == u.TextureAddress.TA_WRAP
    return texture, settings


def _duplicate_material(u, source, path, stage, source_graph):
    eal = u.EditorAssetLibrary
    assert not eal.does_asset_exist(path)
    copied = eal.duplicate_asset(SOURCE_MATERIAL, path)
    if copied:
        _set_owner(u, copied, SourceMaterial=SOURCE_MATERIAL, CandidateStage=stage)
    assert isinstance(copied, u.Material) and _package(copied) == path
    expressions = {node.get_name(): node for node in u.ObjectIterator(u.MaterialExpression) if node.get_outer() == copied}
    assert set(expressions) == EXPECTED_NODES
    alpha = expressions['MaterialExpressionConstant_0']
    alpha.set_editor_property('r', MIX_FACTOR)
    if stage == 'C':
        sample = expressions['MaterialExpressionTextureSample_0']
        texture = u.load_asset(TEXTURE_PATH)
        assert isinstance(texture, u.Texture2D) and _package(texture) == TEXTURE_PATH
        sample.set_editor_property('texture', texture)
    u.MaterialEditingLibrary.recompile_material(copied)
    candidate_graph = _read_material_graph(u, copied)
    _assert_graph_delta(source_graph, candidate_graph, stage)
    assert u.EditorAssetLibrary.save_loaded_asset(copied, False), ('Could not save owned material', path)
    return copied, candidate_graph


def create_assets(preflight_receipt, preflight_sha256):
    """Create and save exactly one Texture2D plus B/C owned material copies."""
    u = _u()
    receipt_path = (ROOT / preflight_receipt).resolve()
    assert receipt_path.is_relative_to(CHECKPOINT.resolve()) and receipt_path.is_file()
    assert _sha(receipt_path) == preflight_sha256, 'Preflight receipt hash mismatch'
    prior = _json(receipt_path)
    assert prior.get('phase') == 'asset_preflight' and prior.get('status') == 'READ_ONLY_PREPARED'
    editor = _editor_state(u)
    assert editor['dirty_maps'] == [] and editor['dirty_content'] == []
    assert editor['map'] == prior['editor']['map'] and editor['map'] == MAP_PACKAGE
    assert _protected_files() == prior['protected_files']
    for rel, expected in prior['inputs'].items():
        assert _sha(ROOT / rel) == expected, ('Preflight input changed', rel)
    _asset_paths_absent(u)
    source = u.load_asset(SOURCE_MATERIAL)
    assert isinstance(source, u.Material) and _package(source) == SOURCE_MATERIAL
    assert _sha(SOURCE_MATERIAL_FILE) == SOURCE_MATERIAL_SHA
    source_graph = _read_material_graph(u, source)
    _assert_live_source_graph(source_graph, _expected_graph_contract(_json(LIVE_GRAPH)))
    assert abs(source_graph['nodes']['MaterialExpressionConstant_0']['r'] - 0.12) < 1e-6
    assert abs(source_graph['nodes']['MaterialExpressionConstant_1']['r'] - 0.88) < 1e-6
    assert source_graph['nodes']['MaterialExpressionConstant_2']['r'] == 0.0
    source_file_sha = _sha(SOURCE_MATERIAL_FILE)

    stage = 'texture_import'
    texture = material_b = material_c = None
    try:
        texture, texture_settings = _import_texture(u)
        stage = 'material_b_duplicate'
        material_b, graph_b = _duplicate_material(u, source, MATERIAL_B_PATH, 'B', source_graph)
        stage = 'material_c_duplicate'
        material_c, graph_c = _duplicate_material(u, source, MATERIAL_C_PATH, 'C', source_graph)
        stage = 'asset_save'
        for asset in (texture, material_b, material_c):
            assert u.EditorAssetLibrary.save_loaded_asset(asset, False), ('Could not save owned asset', asset.get_path_name())
        assert _editor_state(u)['dirty_maps'] == [] and _editor_state(u)['dirty_content'] == []
        assert _protected_files() == prior['protected_files'], 'Protected 614-file source baseline changed'
        assert _sha(SOURCE_MATERIAL_FILE) == source_file_sha == SOURCE_MATERIAL_SHA
        for material in (source,):
            current = _read_material_graph(u, material)
            assert current == source_graph, 'Shared source material changed'
        assets = []
        for asset in (texture, material_b, material_c):
            path = asset.get_path_name().split('.')[0]
            file = ROOT / ('Content/' + path.removeprefix('/Game/') + '.uasset')
            assert file.is_file()
            assets.append(dict(path=path, package_sha256=_sha(file), owner=u.EditorAssetLibrary.get_metadata_tag(asset, TAG)))
        assert len(assets) == 3 and {r['path'] for r in assets} == {TEXTURE_PATH, MATERIAL_B_PATH, MATERIAL_C_PATH}
        report = dict(phase='assets_created', status='THREE_OWNED_ASSETS_CREATED',
            preflight=dict(path=receipt_path.relative_to(ROOT).as_posix(), sha256=preflight_sha256),
            source_material=dict(path=SOURCE_MATERIAL, package_sha256=SOURCE_MATERIAL_SHA,
                                 graph_file=LIVE_GRAPH.relative_to(ROOT).as_posix(), graph_sha256=LIVE_GRAPH_SHA,
                                 graph=source_graph),
            texture=dict(path=TEXTURE_PATH, package_sha256=assets[0]['package_sha256'], settings=texture_settings),
            material_b=dict(path=MATERIAL_B_PATH, package_sha256=assets[1]['package_sha256'],
                            graph=graph_b, only_graph_delta='Constant_0.R 0.12 -> 0.60'),
            material_c=dict(path=MATERIAL_C_PATH, package_sha256=assets[2]['package_sha256'],
                            graph=graph_c, only_graph_deltas=['Constant_0.R 0.12 -> 0.60',
                                'MaterialExpressionTextureSample_0.Texture -> ' + TEXTURE_PATH]),
            owned_assets=assets, source_files_614_unchanged=True, dirty_state=_editor_state(u),
            boundary='New owned preview assets only. No original material, texture, map, library, or cooked build is modified or validated.')
        output = _write_unique('assets_created', report)
        return dict(receipt=output.relative_to(ROOT).as_posix(), sha256=_sha(output), status=report['status'],
                    texture=TEXTURE_PATH, material_b=MATERIAL_B_PATH, material_c=MATERIAL_C_PATH)
    except Exception as exc:
        def capture(callback):
            try:
                return callback()
            except Exception as error:
                return dict(capture_error=repr(error))
        partial = []
        for path in (TEXTURE_PATH, MATERIAL_B_PATH, MATERIAL_C_PATH):
            file = ROOT / ('Content/' + path.removeprefix('/Game/') + '.uasset')
            loaded = u.load_asset(path) if u.EditorAssetLibrary.does_asset_exist(path) else None
            partial.append(dict(path=path, exists=bool(loaded), package_sha256=_sha(file) if file.is_file() else None,
                                owner=u.EditorAssetLibrary.get_metadata_tag(loaded, TAG) if loaded else None))
        failure = dict(phase='partial_asset_prep_failure', status='PARTIAL_OWNED_ASSET_PREPARATION', failed_stage=stage,
            error=repr(exc), preflight=dict(path=receipt_path.relative_to(ROOT).as_posix(), sha256=preflight_sha256),
            partial_assets=partial, source_package_sha256=capture(lambda: _sha(SOURCE_MATERIAL_FILE)),
            protected_file_guards=capture(_protected_files), dirty_state=capture(lambda: _editor_state(u)))
        _write_unique('partial_asset_prep_failure', failure)
        raise

