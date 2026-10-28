"""Prepare a disposable, owned Hall wall material set for a later reviewed trial.

Import is inert. In Unreal Editor Python, call preflight() with the exact
RELOAD_AUDITED guard receipt, reviewed Hall render receipt, selection file and
review Markdown hashes. Only then call create_assets() with that preflight
receipt and hash. No map, source material, source texture, or library is saved.
"""
from __future__ import annotations

import hashlib
import json
import struct
import uuid
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CHECKPOINT = ROOT / 'Saved/WarrensCGameplay-20261024/HallMaterialAssets'
MAP = '/Game/Mars/Maps/Warrens_VariantC_Mars_MAP'

REVIEW_ROOT = ROOT / 'docs/art/warrens-c-gameplay-review-20261024'
IMAGE = REVIEW_ROOT / 'lookdev/hall-painterly-r01/Hall_PainterlyStone_Albedo_Quiet_r01.png'
IMAGE_SHA256 = '9d1b6f10405dca1f89890956b6e4f1f67c0ec36dd8fb96c67997ec1f412a951d'
SOURCE_GRAPH = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryMaterialCandidate/runtime_TX01_graph.json'
SOURCE_GRAPH_SHA256 = 'e4f583a7b76afcdda2d8604e8e642fac5973b1d539791508b2a03a13910cf43e'
SOURCE_MATERIAL = '/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX01'
SOURCE_MATERIAL_FILE = ROOT / 'Content/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX01.uasset'
SOURCE_MATERIAL_SHA256 = '8cdf0cda072b3d3d95a57cc4d24e70af4ca09323910e896ac79b90cbd67d96a4'
COLOR_SOURCE_RECEIPT = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryMaterialTrial/assets_created_20261026T002324_985770Z_b8823bc5.json'
COLOR_SOURCE_RECEIPT_SHA256 = 'a0745bdea6852636b7fe376cf605c2ebb3be58c1d7ac2e0577cedaa7777f4ea9'
COLOR_SOURCE_MATERIAL = '/Game/Mars/ArtReview/Lookdev/OssuaryPainterly_20261025/Materials/M_Ossuary_TX01_R02_C_PainterlyAlbedo_Mix060'
COLOR_SOURCE_FILE = ROOT / ('Content/' + COLOR_SOURCE_MATERIAL.removeprefix('/Game/') + '.uasset')
COLOR_SOURCE_PACKAGE_SHA256 = '11376944ff6bd25178376d6fee7ac754c4ace383a12323c8f51bf6d6fd485859'
COLOR = (0.2345505803823471, 0.23074005544185638, 0.17144110798835754, 1.0)

DEST = '/Game/Mars/ArtReview/Lookdev/StaticPainterlyWalls_20261026'
OWNER = 'Mars.WarrensC.StaticPainterlyWalls.R01.20261026'
TAG = 'MarsWarrensCStaticPainterlyWallsOwner'
TEXTURE_PATH = '/Game/Mars/ArtReview/Lookdev/HallPainterly_20261026/Textures/T_Hall_Quiet_R01_Albedo'
MATERIAL_PATH = DEST + '/Materials/M_Hall_PainterlyWall_R01'
INSTANCE_NORMAL_X_PATH = DEST + '/Materials/MI_Hall_PainterlyWall_NormalX_R01'
INSTANCE_NORMAL_Y_PATH = DEST + '/Materials/MI_Hall_PainterlyWall_NormalY_R01'
PARAM_TEXTURE = 'WallAlbedo'
PARAM_TANGENT = 'WallTangent'
PARAM_REPEAT = 'RepeatCm'
MIX = 0.60
ROUGHNESS = 0.88
METALLIC = 0.0
EXPECTED_MATERIAL_NODES = 15

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
    assert not path.exists(), 'Refuse to overwrite an existing receipt'
    record = dict(record, schema=1, created_utc=datetime.now(timezone.utc).isoformat(),
                  tool_sha256=_sha(__file__))
    path.write_text(json.dumps(record, sort_keys=True, indent=2, allow_nan=False) + '\n', encoding='utf-8')
    return path


def _editor_state(u):
    editor = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    assert editor.get_game_world() is None, 'Stop PIE before creating owned material assets'
    world = editor.get_editor_world()
    assert world, 'No editor world'
    maps = sorted(_package(p) for p in u.EditorLoadingAndSavingUtils.get_dirty_map_packages())
    content = sorted(_package(p) for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages())
    return dict(map=_package(world), dirty_maps=maps, dirty_content=content)


def _texture_targets_absent(u):
    assert IMAGE.is_file() and _sha(IMAGE) == IMAGE_SHA256, 'Hall source image changed'
    raw = IMAGE.read_bytes()
    assert raw[:8] == b'\x89PNG\r\n\x1a\n'
    width, height = struct.unpack('>II', raw[16:24])
    assert (width, height) == (1254, 1254), ('Unexpected source image dimensions', width, height)
    for path in (TEXTURE_PATH, MATERIAL_PATH, INSTANCE_NORMAL_X_PATH, INSTANCE_NORMAL_Y_PATH):
        disk = ROOT / ('Content/' + path.removeprefix('/Game/') + '.uasset')
        assert not disk.exists() and not u.EditorAssetLibrary.does_asset_exist(path), ('Refuse existing asset', path)
    return dict(path=IMAGE.relative_to(ROOT).as_posix(), sha256=IMAGE_SHA256,
                source_dimensions=[width, height], build_resize=[1024, 1024])


def _verify_guard_receipt(path, sha):
    resolved = (ROOT / path).resolve()
    assert resolved.is_relative_to((ROOT / 'Saved/WarrensCGameplay-20261024').resolve())
    assert resolved.is_file() and _sha(resolved) == sha, 'Pinned guard receipt hash mismatch'
    data = _json(resolved)
    assert data.get('status') == 'RELOAD_AUDITED', ('Guard receipt is not a reload audit', data.get('status'))
    guards = data.get('immutable_guards')
    assert isinstance(guards, dict) and len(guards) >= 634, 'Expected current flat immutable guard map'
    for rel, expected in guards.items():
        file = (ROOT / rel).resolve()
        assert file.is_relative_to(ROOT.resolve()) and file.is_file()
        assert _sha(file) == expected, ('Current immutable guard mismatch', rel)
    return resolved, data, guards


def _verify_preview_guards(preview):
    guards = preview.get('guards')
    assert isinstance(guards, dict) and len(guards) >= 400, 'Hall render receipt has no complete guard map'
    for rel, expected in guards.items():
        file = (ROOT / rel).resolve()
        assert file.is_relative_to(ROOT.resolve()) and file.is_file()
        assert _sha(file) == expected, ('Hall render source guard changed', rel)
    return dict(guard_count=len(guards), all_exact_current=True)


def _color_contract():
    assert _sha(SOURCE_GRAPH) == SOURCE_GRAPH_SHA256
    assert _sha(COLOR_SOURCE_RECEIPT) == COLOR_SOURCE_RECEIPT_SHA256
    assert _sha(COLOR_SOURCE_FILE) == COLOR_SOURCE_PACKAGE_SHA256
    saved = _json(COLOR_SOURCE_RECEIPT)
    assert saved.get('material_c', {}).get('path') == COLOR_SOURCE_MATERIAL
    assert saved['material_c'].get('package_sha256') == COLOR_SOURCE_PACKAGE_SHA256
    actual = saved['material_c']['graph']['nodes']['MaterialExpressionConstant3Vector_0']['constant']
    assert len(actual) == 4 and all(abs(float(a) - b) < 1e-7 for a, b in zip(actual, COLOR))
    graph = _json(SOURCE_GRAPH)
    assert graph.get('asset_path') == SOURCE_MATERIAL
    assert _sha(SOURCE_MATERIAL_FILE) == SOURCE_MATERIAL_SHA256
    return dict(source_material=SOURCE_MATERIAL, source_material_sha256=SOURCE_MATERIAL_SHA256,
                color_source_material=COLOR_SOURCE_MATERIAL,
                color_source_package_sha256=COLOR_SOURCE_PACKAGE_SHA256,
                tint=list(COLOR), source_graph_sha256=SOURCE_GRAPH_SHA256,
                color_receipt_sha256=COLOR_SOURCE_RECEIPT_SHA256)


def _validate_selection(preview, selection, selection_sha):
    assert selection.get('selected_source_keys') == preview.get('selected_source_keys')
    assert selection.get('selected_wall_instances') == preview.get('selected_wall_instances')
    assert preview.get('selection_sha256') == selection_sha
    assert int(preview.get('selected_wall_instances', 0)) > 0
    assert len(preview.get('selected_source_keys', [])) == int(preview['selected_wall_instances'])
    return dict(selected_wall_instances=preview['selected_wall_instances'],
                selected_source_key_count=len(preview['selected_source_keys']), sha256=selection_sha)


def _validate_render_artifacts(receipt_path, preview):
    renders = preview.get('renders')
    assert isinstance(renders, list) and renders, 'Render receipt has no captured frame roster'
    rows = []
    for row in renders:
        path = (receipt_path.parent / row['file']).resolve()
        assert path.is_relative_to(receipt_path.parent.resolve()) and path.is_file()
        actual = _sha(path)
        assert actual == row.get('sha256'), ('Hall render frame hash mismatch', row.get('file'), actual)
        rows.append(dict(file=row['file'], sha256=actual, stage=row.get('stage'), view=row.get('view')))
    return rows


def _preview_source(preview):
    source = (ROOT / preview['source']).resolve()
    assert source.is_relative_to(ROOT.resolve()) and source.is_file()
    assert _sha(source) == preview.get('source_sha256'), 'Hall source Blend changed'
    return source


def preflight(guard_receipt, guard_sha256, review_markdown, review_sha256,
              render_receipt, render_sha256, selection_file, selection_sha256):
    """Read-only preparation. All external evidence is an explicit path/hash pair."""
    u = _u()
    editor = _editor_state(u)
    assert editor['map'] == MAP and editor['dirty_maps'] == [] and editor['dirty_content'] == [], (
        'Preflight requires the clean Variant C editor map')
    guard_path, guard_data, guard_map = _verify_guard_receipt(guard_receipt, guard_sha256)
    for file, expected, label in ((Path(review_markdown), review_sha256, 'review markdown'),
                                  (Path(render_receipt), render_sha256, 'render receipt'),
                                  (Path(selection_file), selection_sha256, 'wall selection')):
        path = (ROOT / file).resolve()
        assert path.is_relative_to(REVIEW_ROOT.resolve()) and path.is_file()
        assert _sha(path) == expected, label + ' hash mismatch'
    review = (ROOT / review_markdown).resolve()
    receipt_file = (ROOT / render_receipt).resolve()
    selection_path = (ROOT / selection_file).resolve()
    assert 'Hall' in review.read_text(encoding='utf-8')
    preview = _json(receipt_file)
    assert preview.get('status') == 'DERIVED_STATIC_SURFACE_PREVIEW_RENDERED'
    assert preview.get('projection_comparison') is True and preview.get('geometry_unchanged')
    assert preview.get('source') == 'Tools/WarrensVariantCKit/Output/WarrensVariantC_Diorama.blend'
    assert isinstance(preview.get('source_sha256'), str) and len(preview['source_sha256']) == 64
    _preview_source(preview)
    assert _sha(IMAGE) == IMAGE_SHA256 and preview.get('image_sha256') == IMAGE_SHA256
    selection = _json(selection_path)
    selection_summary = _validate_selection(preview, selection, selection_sha256)
    render_guard_summary = _verify_preview_guards(preview)
    render_frames = _validate_render_artifacts(receipt_file, preview)
    color = _color_contract()
    raw_dimensions = _texture_targets_absent(u)
    record = dict(phase='asset_preflight', status='READ_ONLY_PREPARED', editor=editor,
        guard_receipt=dict(path=guard_path.relative_to(ROOT).as_posix(), sha256=guard_sha256,
                           status=guard_data['status'], guarded_file_count=len(guard_map),
                           immutable_guards=guard_map),
        review=dict(path=review.relative_to(ROOT).as_posix(), sha256=review_sha256),
        render=dict(path=receipt_file.relative_to(ROOT).as_posix(), sha256=render_sha256,
                    source=preview['source'], source_sha256=preview['source_sha256'],
                    image_sha256=preview['image_sha256'], geometry_unchanged=preview['geometry_unchanged'],
                    projection_comparison=preview['projection_comparison'], guard_summary=render_guard_summary,
                    frames=render_frames),
        selection=dict(path=selection_path.relative_to(ROOT).as_posix(), **selection_summary),
        color_source=color, image=raw_dimensions,
        targets=dict(texture=TEXTURE_PATH, material=MATERIAL_PATH,
                     normal_x=INSTANCE_NORMAL_X_PATH, normal_y=INSTANCE_NORMAL_Y_PATH, all_absent=True),
        boundary='Preflight only. No asset import, asset creation, map edit, library sync, or runtime validation.')
    path = _write_unique('asset_preflight', record)
    return dict(receipt=path.relative_to(ROOT).as_posix(), sha256=_sha(path), status=record['status'],
                targets=record['targets'])


def _set_owner(u, asset, **metadata):
    for key, value in dict({TAG: OWNER}, **metadata).items():
        u.EditorAssetLibrary.set_metadata_tag(asset, key, str(value))


def _assert_targets_absent(u):
    _texture_targets_absent(u)


def _make_expression(u, material, cls, x, y, props=None):
    node = u.MaterialEditingLibrary.create_material_expression(material, cls, x, y)
    assert node, ('Could not create material expression', cls.__name__)
    for key, value in (props or {}).items():
        node.set_editor_property(key, value)
    return node


def _connect(u, source, output, target, pin):
    assert u.MaterialEditingLibrary.connect_material_expressions(source, output, target, pin), (
        source.get_name(), output, target.get_name(), pin)


def _assert_parent_graph(u, material, texture, nodes):
    mel = u.MaterialEditingLibrary
    expressions = [node for node in u.ObjectIterator(u.MaterialExpression) if node.get_outer() == material]
    assert len(expressions) == EXPECTED_MATERIAL_NODES == int(mel.get_num_material_expressions(material))
    expected_types = {
        'albedo': u.MaterialExpressionTextureSampleParameter2D,
        'world': u.MaterialExpressionWorldPosition,
        'tangent': u.MaterialExpressionVectorParameter,
        'dot': u.MaterialExpressionDotProduct,
        'zmask': u.MaterialExpressionComponentMask,
        'neg': u.MaterialExpressionConstant,
        'negz': u.MaterialExpressionMultiply,
        'uv': u.MaterialExpressionAppendVector,
        'repeat': u.MaterialExpressionScalarParameter,
        'scaled': u.MaterialExpressionDivide,
        'tint': u.MaterialExpressionConstant3Vector,
        'mix': u.MaterialExpressionConstant,
        'base': u.MaterialExpressionLinearInterpolate,
        'rough': u.MaterialExpressionConstant,
        'metal': u.MaterialExpressionConstant,
    }
    assert all(isinstance(nodes[key], cls) for key, cls in expected_types.items())
    assert nodes['albedo'].get_editor_property('parameter_name') == PARAM_TEXTURE
    assert _package(nodes['albedo'].get_editor_property('texture')) == TEXTURE_PATH
    assert nodes['albedo'].get_editor_property('sampler_type') == u.MaterialSamplerType.SAMPLERTYPE_COLOR
    assert nodes['tangent'].get_editor_property('parameter_name') == PARAM_TANGENT
    assert nodes['repeat'].get_editor_property('parameter_name') == PARAM_REPEAT
    assert abs(float(nodes['repeat'].get_editor_property('default_value')) - 200.0) < 1e-6
    assert abs(float(nodes['mix'].get_editor_property('r')) - MIX) < 1e-6
    assert abs(float(nodes['rough'].get_editor_property('r')) - ROUGHNESS) < 1e-6
    assert abs(float(nodes['metal'].get_editor_property('r')) - METALLIC) < 1e-6
    color = nodes['tint'].get_editor_property('constant')
    assert all(abs(a - b) < 1e-7 for a, b in zip((color.r, color.g, color.b, color.a), COLOR))
    tangent_default = nodes['tangent'].get_editor_property('default_value')
    assert all(abs(a - b) < 1e-7 for a, b in zip(
        (tangent_default.r, tangent_default.g, tangent_default.b), (1.0, 0.0, 0.0)))
    offset = nodes['world'].get_editor_property('world_position_shader_offset')
    assert offset == u.WorldPositionIncludedOffsets.WPT_EXCLUDE_ALL_SHADER_OFFSETS
    mask = nodes['zmask']
    assert tuple(bool(mask.get_editor_property(k)) for k in ('r', 'g', 'b', 'a')) == (False, False, True, False)
    assert abs(float(nodes['neg'].get_editor_property('r')) + 1.0) < 1e-7

    expected = {
        ('dot', 'A'): 'world', ('dot', 'B'): 'tangent',
        ('zmask', 'None'): 'world', ('negz', 'A'): 'zmask', ('negz', 'B'): 'neg',
        ('uv', 'A'): 'dot', ('uv', 'B'): 'negz', ('scaled', 'A'): 'uv',
        ('scaled', 'B'): 'repeat', ('albedo', 'UVs'): 'scaled',
        ('base', 'A'): 'tint', ('base', 'B'): 'albedo', ('base', 'Alpha'): 'mix',
    }
    actual = {}
    actual_outputs = {}
    input_snapshots = {}
    for target_key, target in nodes.items():
        names = list(mel.get_material_expression_input_names(target))
        values = list(mel.get_inputs_for_material_expression(material, target))
        assert len(names) == len(values), ('Cannot inspect material inputs', target_key)
        input_snapshots[target_key] = {}
        for pin, source in zip(names, values):
            if source:
                source_key = next((key for key, value in nodes.items() if value == source), None)
                assert source_key is not None, ('Unexpected graph source', target_key, str(pin), source.get_name())
                actual[(target_key, str(pin))] = source_key
                output_name = mel.get_input_node_output_name_for_material_expression(target, source)
                actual_outputs[(target_key, str(pin))] = output_name
                input_snapshots[target_key][str(pin)] = dict(source=source_key, output=output_name)
            else:
                input_snapshots[target_key][str(pin)] = None
    assert actual == expected, ('Material wiring differs', actual, expected)
    expected_outputs = {edge: '' for edge in expected}
    expected_outputs.update({('dot', 'A'): 'XYZ', ('zmask', 'None'): 'XYZ',
                             ('dot', 'B'): 'RGB', ('base', 'B'): 'RGB'})
    assert actual_outputs == expected_outputs, actual_outputs
    output_keys = ('MP_BASE_COLOR', 'MP_ROUGHNESS', 'MP_METALLIC', 'MP_NORMAL', 'MP_AMBIENT_OCCLUSION',
                   'MP_EMISSIVE_COLOR', 'MP_OPACITY', 'MP_OPACITY_MASK')
    output_nodes = {key: mel.get_material_property_input_node(material, getattr(u.MaterialProperty, key))
                    for key in output_keys}
    assert output_nodes == dict(MP_BASE_COLOR=nodes['base'], MP_ROUGHNESS=nodes['rough'],
                                MP_METALLIC=nodes['metal'], MP_NORMAL=None, MP_AMBIENT_OCCLUSION=None,
                                MP_EMISSIVE_COLOR=None, MP_OPACITY=None, MP_OPACITY_MASK=None)
    assert _package(texture) == TEXTURE_PATH
    node_properties = {
        'albedo': dict(parameter_name=str(nodes['albedo'].get_editor_property('parameter_name')),
                       texture=_package(nodes['albedo'].get_editor_property('texture')),
                       sampler_type=str(nodes['albedo'].get_editor_property('sampler_type'))),
        'world': dict(world_position_shader_offset=str(offset)),
        'tangent': dict(parameter_name=str(nodes['tangent'].get_editor_property('parameter_name')),
                        default_value=[float(tangent_default.r), float(tangent_default.g),
                                       float(tangent_default.b), float(tangent_default.a)]),
        'zmask': dict(r=False, g=False, b=True, a=False),
        'neg': dict(r=float(nodes['neg'].get_editor_property('r'))),
        'repeat': dict(parameter_name=str(nodes['repeat'].get_editor_property('parameter_name')),
                       default_value=float(nodes['repeat'].get_editor_property('default_value'))),
        'tint': dict(constant=[float(color.r), float(color.g), float(color.b), float(color.a)]),
        'mix': dict(r=float(nodes['mix'].get_editor_property('r'))),
        'rough': dict(r=float(nodes['rough'].get_editor_property('r'))),
        'metal': dict(r=float(nodes['metal'].get_editor_property('r'))),
        'base': dict(const_a=float(nodes['base'].get_editor_property('const_a')),
                     const_b=float(nodes['base'].get_editor_property('const_b')),
                     const_alpha=float(nodes['base'].get_editor_property('const_alpha'))),
    }
    serialized = dict(material=dict(blend_mode=str(material.get_editor_property('blend_mode')),
                                    shading_model=str(material.get_editor_property('shading_model')),
                                    two_sided=bool(material.get_editor_property('two_sided')),
                                    used_with_instanced_static_meshes=bool(
                                        material.get_editor_property('used_with_instanced_static_meshes'))),
        nodes={key: dict(name=node.get_name(), class_name=node.get_class().get_name(),
                         input_names=[str(pin) for pin in mel.get_material_expression_input_names(node)],
                         inputs=input_snapshots[key], properties=node_properties.get(key, {}))
               for key, node in nodes.items()},
        outputs={key: (node.get_name() if node else None) for key, node in output_nodes.items()})
    return serialized


def _set_property(u, material, node, output, prop):
    assert u.MaterialEditingLibrary.connect_material_property(node, output, getattr(u.MaterialProperty, prop)), prop


def _build_parent(u, texture):
    mel = u.MaterialEditingLibrary
    assets = u.AssetToolsHelpers.get_asset_tools()
    material = assets.create_asset(MATERIAL_PATH.rsplit('/', 1)[1], DEST + '/Materials',
                                   u.Material, u.MaterialFactoryNew())
    assert isinstance(material, u.Material) and _package(material) == MATERIAL_PATH
    _set_owner(u, material, SourceImageSHA256=IMAGE_SHA256,
               SourceTintMaterial=COLOR_SOURCE_MATERIAL, Projection='WorldTangentZNegative_200cm')
    material.set_editor_property('blend_mode', u.BlendMode.BLEND_OPAQUE)
    material.set_editor_property('shading_model', u.MaterialShadingModel.MSM_DEFAULT_LIT)
    material.set_editor_property('two_sided', False)
    material.set_editor_property('used_with_instanced_static_meshes', True)

    tex = _make_expression(u, material, u.MaterialExpressionTextureSampleParameter2D, -1100, 420,
        dict(parameter_name=PARAM_TEXTURE, texture=texture,
             sampler_type=u.MaterialSamplerType.SAMPLERTYPE_COLOR))
    world = _make_expression(u, material, u.MaterialExpressionWorldPosition, -1100, -120)
    world.set_editor_property('world_position_shader_offset',
                              u.WorldPositionIncludedOffsets.WPT_EXCLUDE_ALL_SHADER_OFFSETS)
    tangent = _make_expression(u, material, u.MaterialExpressionVectorParameter, -1100, 80,
        dict(parameter_name=PARAM_TANGENT, default_value=u.LinearColor(1.0, 0.0, 0.0, 1.0)))
    dot = _make_expression(u, material, u.MaterialExpressionDotProduct, -820, 40)
    zmask = _make_expression(u, material, u.MaterialExpressionComponentMask, -820, -180,
                             dict(r=False, g=False, b=True, a=False))
    neg = _make_expression(u, material, u.MaterialExpressionConstant, -820, -360, dict(r=-1.0))
    negz = _make_expression(u, material, u.MaterialExpressionMultiply, -560, -160)
    uv = _make_expression(u, material, u.MaterialExpressionAppendVector, -320, 20)
    repeat = _make_expression(u, material, u.MaterialExpressionScalarParameter, -560, 180,
                              dict(parameter_name=PARAM_REPEAT, default_value=200.0))
    scaled = _make_expression(u, material, u.MaterialExpressionDivide, -60, 120)
    tint = _make_expression(u, material, u.MaterialExpressionConstant3Vector, -560, 520,
                            dict(constant=u.LinearColor(*COLOR)))
    mix = _make_expression(u, material, u.MaterialExpressionConstant, -320, 520, dict(r=MIX))
    base = _make_expression(u, material, u.MaterialExpressionLinearInterpolate, 220, 420)
    rough = _make_expression(u, material, u.MaterialExpressionConstant, 220, 680, dict(r=ROUGHNESS))
    metal = _make_expression(u, material, u.MaterialExpressionConstant, 220, 820, dict(r=METALLIC))

    _connect(u, world, 'XYZ', dot, 'A')
    _connect(u, tangent, 'RGB', dot, 'B')
    _connect(u, world, 'XYZ', zmask, '')
    _connect(u, zmask, '', negz, 'A')
    _connect(u, neg, '', negz, 'B')
    _connect(u, dot, '', uv, 'A')
    _connect(u, negz, '', uv, 'B')
    _connect(u, uv, '', scaled, 'A')
    _connect(u, repeat, '', scaled, 'B')
    _connect(u, scaled, '', tex, 'UVs')
    _connect(u, tint, '', base, 'A')
    _connect(u, tex, 'RGB', base, 'B')
    _connect(u, mix, '', base, 'Alpha')
    _set_property(u, material, base, '', 'MP_BASE_COLOR')
    _set_property(u, material, rough, '', 'MP_ROUGHNESS')
    _set_property(u, material, metal, '', 'MP_METALLIC')
    mel.recompile_material(material)
    nodes = dict(albedo=tex, world=world, tangent=tangent, dot=dot, zmask=zmask, neg=neg,
                 negz=negz, uv=uv, repeat=repeat, scaled=scaled, tint=tint,
                 mix=mix, base=base, rough=rough, metal=metal)
    serialized_graph = _assert_parent_graph(u, material, texture, nodes)
    assert material.get_editor_property('blend_mode') == u.BlendMode.BLEND_OPAQUE
    assert material.get_editor_property('shading_model') == u.MaterialShadingModel.MSM_DEFAULT_LIT
    assert material.get_editor_property('two_sided') is False
    assert material.get_editor_property('used_with_instanced_static_meshes') is True
    outputs = {
        prop: mel.get_material_property_input_node(material, getattr(u.MaterialProperty, prop))
        for prop in ('MP_BASE_COLOR', 'MP_ROUGHNESS', 'MP_METALLIC', 'MP_NORMAL', 'MP_AMBIENT_OCCLUSION')}
    assert outputs['MP_BASE_COLOR'] == base and outputs['MP_ROUGHNESS'] == rough and outputs['MP_METALLIC'] == metal
    assert outputs['MP_NORMAL'] is None and outputs['MP_AMBIENT_OCCLUSION'] is None
    return material, dict(node_count=EXPECTED_MATERIAL_NODES, graph=serialized_graph,
        projection='U=dot(AbsoluteWorldPosition, WallTangent); V=-AbsoluteWorldPosition.Z; UV=(U,V)/RepeatCm',
        repeat_cm=200.0, tint=list(COLOR), albedo_mix=MIX, roughness=ROUGHNESS, metallic=METALLIC,
        normal_connected=False, ao_connected=False)


def _make_instance(u, material, path, tangent):
    instance = u.AssetToolsHelpers.get_asset_tools().create_asset(
        path.rsplit('/', 1)[1], DEST + '/Materials', u.MaterialInstanceConstant,
        u.MaterialInstanceConstantFactoryNew())
    assert isinstance(instance, u.MaterialInstanceConstant) and _package(instance) == path
    _set_owner(u, instance, ParentMaterial=MATERIAL_PATH, Tangent=','.join(str(v) for v in tangent))
    u.MaterialEditingLibrary.set_material_instance_parent(instance, material)
    assert u.MaterialEditingLibrary.set_material_instance_vector_parameter_value(
        instance, PARAM_TANGENT, u.LinearColor(tangent[0], tangent[1], tangent[2], 1.0))
    assert u.MaterialEditingLibrary.set_material_instance_scalar_parameter_value(instance, PARAM_REPEAT, 200.0)
    assert _package(instance.get_editor_property('parent')) == MATERIAL_PATH
    vector = u.MaterialEditingLibrary.get_material_instance_vector_parameter_value(instance, PARAM_TANGENT)
    scalar = u.MaterialEditingLibrary.get_material_instance_scalar_parameter_value(instance, PARAM_REPEAT)
    assert all(abs(float(a) - b) < 1e-6 for a, b in zip((vector.r, vector.g, vector.b), tangent))
    assert abs(float(scalar) - 200.0) < 1e-6
    return instance


def _import_texture(u):
    task = u.AssetImportTask()
    for name, value in dict(filename=str(IMAGE), destination_path=TEXTURE_PATH.rsplit('/', 1)[0],
            destination_name=TEXTURE_PATH.rsplit('/', 1)[1], automated=True,
            replace_existing=False, replace_existing_settings=False, save=False,
            async_=False, factory=u.TextureFactory()).items():
        task.set_editor_property(name, value)
    u.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
    imported = [str(p) for p in task.get_editor_property('imported_object_paths')]
    assert any(p.split('.')[0] == TEXTURE_PATH for p in imported), ('Texture import did not return exact target', imported)
    texture = u.load_asset(TEXTURE_PATH)
    assert isinstance(texture, u.Texture2D) and _package(texture) == TEXTURE_PATH
    _set_owner(u, texture, SourceImageSHA256=IMAGE_SHA256,
               SourcePath=IMAGE.relative_to(ROOT).as_posix(), RawSourceSize='1254x1254')
    texture.set_editor_property('srgb', True)
    texture.set_editor_property('compression_settings', u.TextureCompressionSettings.TC_DEFAULT)
    texture.set_editor_property('address_x', u.TextureAddress.TA_WRAP)
    texture.set_editor_property('address_y', u.TextureAddress.TA_WRAP)
    texture.set_editor_property('power_of_two_mode', u.TexturePowerOfTwoSetting.RESIZE_TO_SPECIFIC_RESOLUTION)
    texture.set_editor_property('resize_during_build_x', 1024)
    texture.set_editor_property('resize_during_build_y', 1024)
    texture.set_editor_property('mip_gen_settings', u.TextureMipGenSettings.TMGS_FROM_TEXTURE_GROUP)
    assert texture.get_editor_property('srgb') is True
    assert texture.get_editor_property('compression_settings') == u.TextureCompressionSettings.TC_DEFAULT
    assert texture.get_editor_property('address_x') == u.TextureAddress.TA_WRAP
    assert texture.get_editor_property('address_y') == u.TextureAddress.TA_WRAP
    assert texture.get_editor_property('resize_during_build_x') == 1024
    assert texture.get_editor_property('resize_during_build_y') == 1024
    return texture, dict(source_sha256=IMAGE_SHA256, raw_source_dimensions=[1254, 1254],
        srgb=True, compression_settings=str(texture.get_editor_property('compression_settings')),
        address_x=str(texture.get_editor_property('address_x')), address_y=str(texture.get_editor_property('address_y')),
        power_of_two_mode=str(texture.get_editor_property('power_of_two_mode')),
        resize_during_build=[1024, 1024],
        runtime_dimensions=[int(texture.blueprint_get_size_x()), int(texture.blueprint_get_size_y())],
        mip_gen_settings=str(texture.get_editor_property('mip_gen_settings')))


def create_assets(preflight_receipt, preflight_sha256):
    """Import and save the four owned assets described by an exact preflight."""
    u = _u()
    receipt = (ROOT / preflight_receipt).resolve()
    assert receipt.is_relative_to(CHECKPOINT.resolve()) and receipt.is_file()
    assert _sha(receipt) == preflight_sha256
    prior = _json(receipt)
    assert prior.get('phase') == 'asset_preflight' and prior.get('status') == 'READ_ONLY_PREPARED'
    assert prior.get('tool_sha256') == _sha(__file__), 'Preflight belongs to another helper revision'
    editor = _editor_state(u)
    assert editor == prior['editor'] and editor['map'] == MAP
    assert editor['dirty_maps'] == [] and editor['dirty_content'] == []
    guard_file = prior['guard_receipt']['path']
    _verify_guard_receipt(guard_file, prior['guard_receipt']['sha256'])
    assert _sha((ROOT / guard_file).resolve()) == prior['guard_receipt']['sha256']
    for record in (prior['review'], prior['render'], prior['selection']):
        path = ROOT / record['path']
        assert _sha(path) == record['sha256']
    preview_path = ROOT / prior['render']['path']
    preview = _json(preview_path)
    _verify_preview_guards(preview)
    render_frames = _validate_render_artifacts(preview_path, preview)
    selection = _json(ROOT / prior['selection']['path'])
    _validate_selection(preview, selection, prior['selection']['sha256'])
    _preview_source(preview)
    assert _sha(IMAGE) == IMAGE_SHA256
    assert _color_contract() == prior['color_source']
    _assert_targets_absent(u)
    stage = 'texture_import'
    created = []
    try:
        texture, texture_settings = _import_texture(u)
        created.append(texture)
        stage = 'parent_material'
        material, material_graph = _build_parent(u, texture)
        created.append(material)
        stage = 'tangent_instances'
        inst_x = _make_instance(u, material, INSTANCE_NORMAL_X_PATH, (0.0, -1.0, 0.0))
        created.append(inst_x)
        inst_y = _make_instance(u, material, INSTANCE_NORMAL_Y_PATH, (1.0, 0.0, 0.0))
        created.append(inst_y)
        for asset in created:
            assert u.EditorAssetLibrary.save_loaded_asset(asset, False), ('Could not save owned asset', asset.get_path_name())
        assert _editor_state(u) == prior['editor'], 'Asset save dirtied map or changed editor context'
        _verify_guard_receipt(guard_file, prior['guard_receipt']['sha256'])
        assert _color_contract() == prior['color_source']
        asset_rows = []
        for asset, path in zip(created, (TEXTURE_PATH, MATERIAL_PATH, INSTANCE_NORMAL_X_PATH, INSTANCE_NORMAL_Y_PATH)):
            package = ROOT / ('Content/' + path.removeprefix('/Game/') + '.uasset')
            assert package.is_file()
            asset_rows.append(dict(path=path, package_sha256=_sha(package),
                                   owner=u.EditorAssetLibrary.get_metadata_tag(asset, TAG)))
        assert len(asset_rows) == 4 and all(row['owner'] == OWNER for row in asset_rows)
        report = dict(phase='assets_created', status='FOUR_OWNED_HALL_MATERIAL_ASSETS_CREATED',
            preflight=dict(path=receipt.relative_to(ROOT).as_posix(), sha256=preflight_sha256),
            texture=dict(path=TEXTURE_PATH, package_sha256=asset_rows[0]['package_sha256'], settings=texture_settings),
            material=dict(path=MATERIAL_PATH, package_sha256=asset_rows[1]['package_sha256'], graph=material_graph),
            tangent_instances=[dict(path=INSTANCE_NORMAL_X_PATH, tangent=[0.0, -1.0, 0.0], package_sha256=asset_rows[2]['package_sha256']),
                               dict(path=INSTANCE_NORMAL_Y_PATH, tangent=[1.0, 0.0, 0.0], package_sha256=asset_rows[3]['package_sha256'])],
            render_frames=render_frames,
            owned_assets=asset_rows, protected_guards_unchanged=True, source_material_unchanged=True,
            editor_state=_editor_state(u),
            boundary='Owned material assets only. No original material, map, library, or runtime assignment was saved or tested.')
        output = _write_unique('assets_created', report)
        return dict(receipt=output.relative_to(ROOT).as_posix(), sha256=_sha(output), status=report['status'],
                    assets=[r['path'] for r in asset_rows])
    except Exception as exc:
        def capture(callback):
            try:
                return callback()
            except Exception as error:
                return dict(capture_error=repr(error))
        partial = []
        for path in (TEXTURE_PATH, MATERIAL_PATH, INSTANCE_NORMAL_X_PATH, INSTANCE_NORMAL_Y_PATH):
            package = ROOT / ('Content/' + path.removeprefix('/Game/') + '.uasset')
            loaded = u.load_asset(path) if u.EditorAssetLibrary.does_asset_exist(path) else None
            partial.append(dict(path=path, exists=bool(loaded), package_sha256=_sha(package) if package.is_file() else None,
                                owner=u.EditorAssetLibrary.get_metadata_tag(loaded, TAG) if loaded else None))
        _write_unique('partial_asset_prep_failure', dict(phase='partial_asset_prep_failure',
            status='PARTIAL_HALL_ASSET_PREPARATION', failed_stage=stage, error=repr(exc),
            preflight=dict(path=receipt.relative_to(ROOT).as_posix(), sha256=preflight_sha256),
            partial_assets=partial, editor_state=capture(lambda: _editor_state(u)),
            protected_guard_check=capture(lambda: _verify_guard_receipt(guard_file, prior['guard_receipt']['sha256'])[0].as_posix()),
            source_material_file_sha256=capture(lambda: _sha(SOURCE_MATERIAL_FILE)),
            color_source_file_sha256=capture(lambda: _sha(COLOR_SOURCE_FILE))))
        raise

