"""Create a texture and two instances of the reviewed static-wall parent.

Config-driven and inert on import. Only new owned assets may be saved.
"""
import hashlib
import importlib.util
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
RUN = ROOT / 'Saved/WarrensCGameplay-20261024/WallFamilyAssets'
HALL_RECEIPT = ROOT / 'Saved/WarrensCGameplay-20261024/HallMaterialAssets/assets_created_recovered_20261026T022350_339227Z_cdc15829.json'
HALL_SHA = 'd9147e97cbdc618463b28a69298e75f08c3781203b795dfe59d90f5fc288fda8'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text())


def module(name, filename, digest):
    path = HERE / filename
    assert sha(path) == digest
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def helpers():
    h = module('_wall_family_frozen_assets', 'static_wall_material_assets.py',
        '1c2fff2a8a5106ddf87e9ef1d64913e8b36e667ad0c76903142d9fef8d77c8e9')
    r = module('_wall_family_frozen_graph', 'static_wall_material_assets_resume.py',
        '78960d688a52540227e7958523f8da304956b400e450eff92c0f5c2a259fca58')
    return h, r


def pinned(record):
    path = (ROOT / record['path']).resolve()
    assert path.is_relative_to(ROOT.resolve()) and path.is_file() and sha(path) == record['sha256']
    return path


def config(file, digest):
    path = (ROOT / file).resolve()
    assert path.is_relative_to(RUN.resolve()) and sha(path) == digest
    value = read(path)
    assert value['schema'] == 1
    assert value['destination'].startswith('/Game/Mars/ArtReview/Lookdev/')
    targets = [value[k] for k in ('texture', 'normal_x', 'normal_y')]
    assert len(set(targets)) == 3 and all(p.startswith(value['destination'] + '/') for p in targets)
    return path, value


def source_contract(c, u):
    h, graph_helper = helpers()
    assert sha(HALL_RECEIPT) == HALL_SHA
    hall = read(HALL_RECEIPT)
    guard = pinned(c['guard'])
    _, _, guards = h._verify_guard_receipt(guard, c['guard']['sha256'])
    for row in hall['owned_assets']:
        file = ROOT / ('Content/' + row['path'].removeprefix('/Game/') + '.uasset')
        assert sha(file) == row['package_sha256']
    image, preview_path, selection_path, _ = [pinned(c[key]) for key in ('image', 'preview', 'selection', 'review')]
    raw = image.read_bytes()
    assert raw[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II', raw[16:24]) == (1254, 1254)
    preview, selection = read(preview_path), read(selection_path)
    assert preview['status'] == 'DERIVED_STATIC_SURFACE_PREVIEW_RENDERED' and preview['projection_comparison'] is True
    assert preview['selection_sha256'] == c['selection']['sha256'] and preview['image_sha256'] == c['image']['sha256']
    assert preview['selected_source_keys'] == selection['selected_source_keys']
    assert preview['selected_wall_instances'] == selection['selected_wall_instances']
    h._preview_source(preview)
    h._verify_preview_guards(preview)
    frames = h._validate_render_artifacts(preview_path, preview)
    parent = u.load_asset(hall['material']['path'])
    hall_texture = u.load_asset(hall['texture']['path'])
    assert isinstance(parent, u.Material) and isinstance(hall_texture, u.Texture2D)
    actual_graph = graph_helper.parent_graph(h, u, parent, hall_texture)
    assert actual_graph == hall['material']['graph']['graph']
    editor = h._editor_state(u)
    assert editor['dirty_maps'] == editor['dirty_content'] == []
    return h, parent, hall, dict(guards=guards, parent_graph=actual_graph, frames=frames,
        editor=editor, selection_count=selection['selected_wall_instances'])


def absent(c, u):
    for key in ('texture', 'normal_x', 'normal_y'):
        path = c[key]
        assert not (ROOT / ('Content/' + path.removeprefix('/Game/') + '.uasset')).exists()
        assert not u.EditorAssetLibrary.does_asset_exist(path), path


def write(kind, data):
    from datetime import datetime, timezone
    import uuid
    path = RUN / (kind + '_' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ') + '_' + uuid.uuid4().hex[:8] + '.json')
    assert not path.exists()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(dict(data, tool_sha256=sha(__file__)), indent=2, sort_keys=True, allow_nan=False) + '\n')
    return dict(file=path.relative_to(ROOT).as_posix(), sha256=sha(path), status=data['status'])


def preflight(config_file, config_sha):
    import unreal as u
    path, c = config(config_file, config_sha)
    _, _, _, proof = source_contract(c, u)
    absent(c, u)
    return write('preflight', dict(status='READ_ONLY_PREPARED', config_file=path.relative_to(ROOT).as_posix(),
        config_sha256=config_sha, proof=proof, targets=[c[k] for k in ('texture', 'normal_x', 'normal_y')]))


def values(h, u, instance, parent, texture, tangent):
    assert instance.get_editor_property('parent') == parent
    assert u.MaterialEditingLibrary.get_material_instance_texture_parameter_value(instance, 'WallAlbedo') == texture
    vector = u.MaterialEditingLibrary.get_material_instance_vector_parameter_value(instance, 'WallTangent')
    assert [float(x) for x in (vector.r, vector.g, vector.b, vector.a)] == list(tangent) + [1.0]
    assert u.MaterialEditingLibrary.get_material_instance_scalar_parameter_value(instance, 'RepeatCm') == 200.0


def texture_policy(u, texture):
    assert texture.get_editor_property('srgb') is True
    assert texture.get_editor_property('compression_settings') == u.TextureCompressionSettings.TC_DEFAULT
    assert texture.get_editor_property('power_of_two_mode') == u.TexturePowerOfTwoSetting.RESIZE_TO_SPECIFIC_RESOLUTION
    assert texture.get_editor_property('mip_gen_settings') == u.TextureMipGenSettings.TMGS_FROM_TEXTURE_GROUP
    for axis in ('x', 'y'):
        assert texture.get_editor_property('address_' + axis) == u.TextureAddress.TA_WRAP
        assert texture.get_editor_property('resize_during_build_' + axis) == 1024
    return dict(srgb=True, compression_settings=str(texture.get_editor_property('compression_settings')),
        power_of_two_mode=str(texture.get_editor_property('power_of_two_mode')),
        address_x=str(texture.get_editor_property('address_x')), address_y=str(texture.get_editor_property('address_y')),
        mip_gen_settings=str(texture.get_editor_property('mip_gen_settings')), resize_during_build=[1024, 1024],
        runtime_dimensions=[int(texture.blueprint_get_size_x()), int(texture.blueprint_get_size_y())])


def create(preflight_file, preflight_sha):
    import unreal as u
    path = (ROOT / preflight_file).resolve()
    assert path.is_relative_to(RUN.resolve()) and sha(path) == preflight_sha
    prior = read(path)
    assert prior['status'] == 'READ_ONLY_PREPARED' and prior['tool_sha256'] == sha(__file__)
    _, c = config(prior['config_file'], prior['config_sha256'])
    h, parent, hall, proof = source_contract(c, u)
    assert proof == prior['proof']
    absent(c, u)
    created = []
    try:
        task = u.AssetImportTask()
        for key, value in dict(filename=str(pinned(c['image'])), destination_path=c['texture'].rsplit('/', 1)[0],
                destination_name=c['texture'].rsplit('/', 1)[1], automated=True, replace_existing=False,
                replace_existing_settings=False, save=False, async_=False, factory=u.TextureFactory()).items():
            task.set_editor_property(key, value)
        u.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
        assert [str(p).split('.')[0] for p in task.imported_object_paths] == [c['texture']]
        texture = u.load_asset(c['texture'])
        assert isinstance(texture, u.Texture2D)
        created.append(texture)
        texture.set_editor_property('srgb', True)
        texture.set_editor_property('compression_settings', u.TextureCompressionSettings.TC_DEFAULT)
        texture.set_editor_property('address_x', u.TextureAddress.TA_WRAP)
        texture.set_editor_property('address_y', u.TextureAddress.TA_WRAP)
        texture.set_editor_property('power_of_two_mode', u.TexturePowerOfTwoSetting.RESIZE_TO_SPECIFIC_RESOLUTION)
        texture.set_editor_property('resize_during_build_x', 1024)
        texture.set_editor_property('resize_during_build_y', 1024)
        texture.set_editor_property('mip_gen_settings', u.TextureMipGenSettings.TMGS_FROM_TEXTURE_GROUP)
        texture_policy(u, texture)
        for key, tangent in [('normal_x', (0.0, -1.0, 0.0)), ('normal_y', (1.0, 0.0, 0.0))]:
            instance = u.AssetToolsHelpers.get_asset_tools().create_asset(c[key].rsplit('/', 1)[1],
                c[key].rsplit('/', 1)[0], u.MaterialInstanceConstant, u.MaterialInstanceConstantFactoryNew())
            assert isinstance(instance, u.MaterialInstanceConstant)
            created.append(instance)
            # UE5.7 writes/updates but returns false from these parameter setters.
            u.MaterialEditingLibrary.set_material_instance_parent(instance, parent)
            u.MaterialEditingLibrary.set_material_instance_texture_parameter_value(instance, 'WallAlbedo', texture)
            u.MaterialEditingLibrary.set_material_instance_vector_parameter_value(instance, 'WallTangent', u.LinearColor(*tangent, 1.0))
            u.MaterialEditingLibrary.set_material_instance_scalar_parameter_value(instance, 'RepeatCm', 200.0)
            values(h, u, instance, parent, texture, tangent)
        targets = [c[k] for k in ('texture', 'normal_x', 'normal_y')]
        for asset, target in zip(created, targets):
            assert h._package(asset) == target
            u.EditorAssetLibrary.set_metadata_tag(asset, 'MarsWarrensCWallFamilyOwner', c['owner'])
            u.EditorAssetLibrary.set_metadata_tag(asset, 'SourceImageSHA256', c['image']['sha256'])
            u.EditorAssetLibrary.set_metadata_tag(asset, 'ReviewedParentSHA256', hall['material']['package_sha256'])
        assert h._editor_state(u) == dict(map=proof['editor']['map'], dirty_maps=[], dirty_content=sorted(targets))
        rows = []
        for asset, target in zip(created, targets):
            assert u.EditorAssetLibrary.save_loaded_asset(asset, False)
            file = ROOT / ('Content/' + target.removeprefix('/Game/') + '.uasset')
            rows.append(dict(path=target, package_sha256=sha(file), owner=u.EditorAssetLibrary.get_metadata_tag(asset, 'MarsWarrensCWallFamilyOwner')))
        assert all(row['owner'] == c['owner'] for row in rows)
        settings = texture_policy(u, texture)
        _, _, _, after = source_contract(c, u)
        assert after == proof
        values(h, u, created[1], parent, texture, (0.0, -1.0, 0.0))
        values(h, u, created[2], parent, texture, (1.0, 0.0, 0.0))
        return write('created', dict(status='THREE_OWNED_WALL_FAMILY_ASSETS_CREATED',
            preflight=dict(path=path.relative_to(ROOT).as_posix(), sha256=preflight_sha),
            config=c, owned_assets=rows, texture_settings=settings, proof=proof,
            reused_parent=hall['material'], normal=None, roughness=.88, albedo_mix=.60,
            boundary='Three new candidate packages only; no map, parent, Hall asset or library assignment changed.'))
    except Exception as error:
        write('failure', dict(status='PARTIAL_WALL_FAMILY_ASSETS_INSPECT_BEFORE_RETRY', error=repr(error),
            config=c, completed=[h._package(a) for a in created], editor=h._editor_state(u)))
        raise
