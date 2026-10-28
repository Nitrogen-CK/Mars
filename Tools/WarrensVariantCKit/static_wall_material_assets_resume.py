"""Resume only the exact unsaved owned Hall assets after UE's false setter result."""
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
FROZEN = HERE / 'static_wall_material_assets.py'
FROZEN_SHA = '1c2fff2a8a5106ddf87e9ef1d64913e8b36e667ad0c76903142d9fef8d77c8e9'
PREFLIGHT = ROOT / 'Saved/WarrensCGameplay-20261024/HallMaterialAssets/asset_preflight_20261026T021819_804432Z_c54c19fb.json'
PREFLIGHT_SHA = '5a208e499ee9cbbe0cb4f9b553a8746f04580f3d20d970a6f9d754ca497e91da'
FAILURE = ROOT / 'Saved/WarrensCGameplay-20261024/HallMaterialAssets/partial_asset_prep_failure_20261026T021912_640893Z_4eb04288.json'


def load():
    import hashlib
    assert hashlib.sha256(FROZEN.read_bytes()).hexdigest() == FROZEN_SHA
    spec = importlib.util.spec_from_file_location('_hall_frozen_assets_resume', FROZEN)
    h = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(h)
    assert h._sha(PREFLIGHT) == PREFLIGHT_SHA
    return h


def parent_graph(h, u, material, texture):
    assert material.get_editor_property('blend_mode') == u.BlendMode.BLEND_OPAQUE
    assert material.get_editor_property('shading_model') == u.MaterialShadingModel.MSM_DEFAULT_LIT
    assert material.get_editor_property('two_sided') is False
    assert material.get_editor_property('used_with_instanced_static_meshes') is True
    nodes = [n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer() == material]
    roles = {}
    for role, cls in dict(albedo=u.MaterialExpressionTextureSampleParameter2D,
            world=u.MaterialExpressionWorldPosition, tangent=u.MaterialExpressionVectorParameter,
            dot=u.MaterialExpressionDotProduct, zmask=u.MaterialExpressionComponentMask,
            negz=u.MaterialExpressionMultiply, uv=u.MaterialExpressionAppendVector,
            repeat=u.MaterialExpressionScalarParameter, scaled=u.MaterialExpressionDivide,
            tint=u.MaterialExpressionConstant3Vector, base=u.MaterialExpressionLinearInterpolate).items():
        roles[role], = [n for n in nodes if n.get_class() == cls.static_class()]
    for role, value in dict(neg=-1.0, mix=.60, rough=.88, metal=0.0).items():
        roles[role], = [n for n in nodes if isinstance(n, u.MaterialExpressionConstant)
                       and abs(n.get_editor_property('r') - value) < 1e-6]
    return h._assert_parent_graph(u, material, texture, roles)


def texture_settings(h, u, texture):
    assert texture.get_editor_property('srgb') is True
    assert texture.get_editor_property('compression_settings') == u.TextureCompressionSettings.TC_DEFAULT
    assert texture.get_editor_property('power_of_two_mode') == u.TexturePowerOfTwoSetting.RESIZE_TO_SPECIFIC_RESOLUTION
    assert texture.get_editor_property('mip_gen_settings') == u.TextureMipGenSettings.TMGS_FROM_TEXTURE_GROUP
    for axis in ('x', 'y'):
        assert texture.get_editor_property('address_' + axis) == u.TextureAddress.TA_WRAP
        assert texture.get_editor_property('resize_during_build_' + axis) == 1024
    return dict(source_sha256=h.IMAGE_SHA256, raw_source_dimensions=[1254, 1254],
        srgb=True, compression_settings=str(texture.get_editor_property('compression_settings')),
        address_x=str(texture.get_editor_property('address_x')), address_y=str(texture.get_editor_property('address_y')),
        power_of_two_mode=str(texture.get_editor_property('power_of_two_mode')),
        resize_during_build=[1024, 1024], mip_gen_settings=str(texture.get_editor_property('mip_gen_settings')),
        runtime_dimensions=[int(texture.blueprint_get_size_x()), int(texture.blueprint_get_size_y())])


def instance_values(h, u, instance, tangent):
    assert h._package(instance.get_editor_property('parent')) == h.MATERIAL_PATH
    vector = u.MaterialEditingLibrary.get_material_instance_vector_parameter_value(instance, h.PARAM_TANGENT)
    assert [float(v) for v in (vector.r, vector.g, vector.b, vector.a)] == list(tangent) + [1.0]
    assert u.MaterialEditingLibrary.get_material_instance_scalar_parameter_value(instance, h.PARAM_REPEAT) == 200.0


def resume(failure_sha):
    import unreal as u
    h = load()
    assert h._sha(FAILURE) == failure_sha
    failed, prior = h._json(FAILURE), h._json(PREFLIGHT)
    assert failed['tool_sha256'] == FROZEN_SHA and failed['status'] == 'PARTIAL_HALL_ASSET_PREPARATION'
    assert failed['failed_stage'] == 'tangent_instances'
    assert h._editor_state(u) == failed['editor_state']
    assert failed['editor_state']['dirty_maps'] == [] and failed['editor_state']['map'] == h.MAP
    paths = [h.TEXTURE_PATH, h.MATERIAL_PATH, h.INSTANCE_NORMAL_X_PATH, h.INSTANCE_NORMAL_Y_PATH]
    assert failed['editor_state']['dirty_content'] == sorted(paths[:3])
    for record in (prior['guard_receipt'], prior['review'], prior['render'], prior['selection']):
        assert h._sha(ROOT / record['path']) == record['sha256']
    h._verify_guard_receipt(prior['guard_receipt']['path'], prior['guard_receipt']['sha256'])
    preview_path = ROOT / prior['render']['path']
    preview = h._json(preview_path)
    h._preview_source(preview)
    h._verify_preview_guards(preview)
    frames = h._validate_render_artifacts(preview_path, preview)
    assert h._color_contract() == prior['color_source']
    assert h._sha(h.IMAGE) == h.IMAGE_SHA256
    for index, path in enumerate(paths):
        assert not (ROOT / ('Content/' + path.removeprefix('/Game/') + '.uasset')).exists()
        assert u.EditorAssetLibrary.does_asset_exist(path) == (index < 3)
    texture, material, inst_x = [u.load_asset(p) for p in paths[:3]]
    assert isinstance(texture, u.Texture2D) and isinstance(material, u.Material)
    assert isinstance(inst_x, u.MaterialInstanceConstant)
    for asset in (texture, material, inst_x):
        assert u.EditorAssetLibrary.get_metadata_tag(asset, h.TAG) == h.OWNER
    graph = parent_graph(h, u, material, texture)
    settings = texture_settings(h, u, texture)
    instance_values(h, u, inst_x, (0.0, -1.0, 0.0))
    # UE5.7 sets/updates parameters but both native setter implementations return
    # their unchanged false local. Validate the resulting values, not that flag.
    scalar_result = u.MaterialEditingLibrary.set_material_instance_scalar_parameter_value(inst_x, h.PARAM_REPEAT, 200.0)
    inst_y = u.AssetToolsHelpers.get_asset_tools().create_asset(paths[3].rsplit('/', 1)[1],
        h.DEST + '/Materials', u.MaterialInstanceConstant, u.MaterialInstanceConstantFactoryNew())
    assert isinstance(inst_y, u.MaterialInstanceConstant) and h._package(inst_y) == paths[3]
    h._set_owner(u, inst_y, ParentMaterial=h.MATERIAL_PATH, Tangent='1.0,0.0,0.0')
    u.MaterialEditingLibrary.set_material_instance_parent(inst_y, material)
    vector_result = u.MaterialEditingLibrary.set_material_instance_vector_parameter_value(
        inst_y, h.PARAM_TANGENT, u.LinearColor(1.0, 0.0, 0.0, 1.0))
    scalar_y_result = u.MaterialEditingLibrary.set_material_instance_scalar_parameter_value(inst_y, h.PARAM_REPEAT, 200.0)
    instance_values(h, u, inst_x, (0.0, -1.0, 0.0))
    instance_values(h, u, inst_y, (1.0, 0.0, 0.0))
    assert parent_graph(h, u, material, texture) == graph
    assets = [texture, material, inst_x, inst_y]
    assert h._editor_state(u) == dict(map=h.MAP, dirty_maps=[], dirty_content=sorted(paths))
    rows = []
    for asset, path in zip(assets, paths):
        assert u.EditorAssetLibrary.save_loaded_asset(asset, False)
        file = ROOT / ('Content/' + path.removeprefix('/Game/') + '.uasset')
        rows.append(dict(path=path, package_sha256=h._sha(file), owner=u.EditorAssetLibrary.get_metadata_tag(asset, h.TAG)))
    assert all(r['owner'] == h.OWNER for r in rows)
    assert h._editor_state(u) == prior['editor']
    h._verify_guard_receipt(prior['guard_receipt']['path'], prior['guard_receipt']['sha256'])
    assert h._color_contract() == prior['color_source']
    record = dict(phase='assets_created', status='FOUR_OWNED_HALL_MATERIAL_ASSETS_CREATED',
        preflight=dict(path=PREFLIGHT.relative_to(ROOT).as_posix(), sha256=PREFLIGHT_SHA),
        recovered_failure=dict(path=FAILURE.relative_to(ROOT).as_posix(), sha256=failure_sha),
        recovery_tool_sha256=h._sha(__file__), frozen_creation_tool_sha256=FROZEN_SHA,
        texture=dict(path=paths[0], package_sha256=rows[0]['package_sha256'], settings=settings),
        material=dict(path=paths[1], package_sha256=rows[1]['package_sha256'], graph=dict(graph=graph, node_count=15)),
        tangent_instances=[dict(path=paths[2], tangent=[0.0, -1.0, 0.0], package_sha256=rows[2]['package_sha256']),
                           dict(path=paths[3], tangent=[1.0, 0.0, 0.0], package_sha256=rows[3]['package_sha256'])],
        owned_assets=rows, render_frames=frames, protected_guards_unchanged=True, source_material_unchanged=True,
        editor_state=h._editor_state(u), setter_return_values=[scalar_result, vector_result, scalar_y_result],
        boundary='Exactly four new owned assets saved. Native void/false setter returns replaced by exact readback gates. No original map, library or material write.')
    out = h._write_unique('assets_created_recovered', record)
    return dict(status=record['status'], receipt=out.relative_to(ROOT).as_posix(), sha256=h._sha(out))
