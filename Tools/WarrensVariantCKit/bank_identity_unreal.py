"""Bounded Bellbank ART03 asset and disposable PIE identity trial.

Importing this module is inert. Call the explicit phases from Unreal Editor Python:
    preflight_assets() -> create_assets(receipt, sha)
    preflight_trial(exact_belfry_level_path) -> apply_trial(receipt, sha)
    toggle_trial(card_visible) -> restore_trial()

Only one owned Texture2D and one owned Material are saved. PIE components are
temporary clones under their existing Hub owners; source components and maps stay
untouched. Receipts are unique and never overwritten.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import re
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
REVIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024'
CHECKPOINT = ROOT / 'Saved/WarrensCGameplay-20261024/BankIdentityCheckpoint'
LIBRARY_VERIFY = ROOT / 'Saved/WarrensCGameplay-20261024/art_verify_belfry_libraries_root_20261025.json'
LIBRARY_VERIFY_SHA256 = '81ffb1e9ce424ef229342e2f9477f2fd815114667b9b3395f4c2e53f26b97157'
FIT = HERE / 'Output/fitted_instances.json'
MANIFEST = HERE / 'Output/asset_manifest.json'
CHAIN_MANIFEST = HERE.parent / 'ChainCrossingKit/Output/asset_manifest.json'
IMAGE = ROOT / 'docs/art/warrens-c-dressing-r01/art/painted/ART03_BellBankEmblem-r02.png'
IMAGE_SHA256 = '435f7ab2b675a34f1e34b59f6ad140e9e42bdf6c198e455630a23c8491e2ae08'
ART01_T3D = ROOT / 'Saved/WarrensCGameplay-20261024/BankIdentityCheckpoint/ART01_observed_1792912518986825700.t3d'
ART01_T3D_SHA256 = '83072050bee6257481b3bcb87dc046d38af27eab5bf7b3327b3beeecb75d7a2c'
R03_APPROVAL = REVIEW / 'bank-identity-preview/r03/ASTRA_REVIEW.md'
R03_APPROVAL_SHA256 = '2e813385e5b5fc4f9904fb37928e724b8e0dfc58b12e0d9b2c3321350596d814'
R03_RECEIPT = REVIEW / 'bank-identity-preview/r03/receipt.json'
R03_RECEIPT_SHA256 = '3d6713c8b56027bbab81d8499bc41c68154ec66025f23904df845f8d5903a93d'

OWNER = 'Mars.WarrensC.BankIdentity.ART03R02.20261025'
TAG = 'MarsWarrensCBankIdentityOwner'
DEST = '/Game/Mars/Environment/WarrensVariantCKit/BankIdentity'
TEXTURE_PATH = DEST + '/Textures/T_WVC_ART03_BellBankEmblemR02'
MATERIAL_PATH = DEST + '/Materials/M_BankIdentity_BellBankEmblemR02'
SOURCE_MATERIAL = '/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_ART01'
SOURCE_TEXTURE = '/Game/Mars/Environment/ChainCrossingKit/Textures/T_CCK_ART01_RoyalClocheCrest'
SOURCE_MESHES = {
    'board': '/Game/Mars/Environment/ChainCrossingKit/Meshes/WarrensC_CCS78_MaintenanceNoticeBoard_Mars_SM',
    'card': '/Game/Mars/Environment/WarrensVariantCKit/Meshes/WarrensC_WVC083_EmblemSurfaceCarrier_Mars_SM',
}
TARGET_ROWS = {
    'board': dict(at=[93.7, 44.027, 1.0], scale=[1.3, 1.0, 1.0], yaw=0.0),
    'card': dict(at=[93.7, 44.048, 1.1], scale=[4.0 / 3.0, 1.0, 1.0], yaw=0.0),
}
TRIAL_PREFIX = 'WVC_BankIdentityTrial_'
STATE_MODULE = '_mars_wvc_bank_identity_trial_state'
ASSET_RECEIPT = 'asset_preflight'
TRIAL_RECEIPT = 'pie_preflight'


def _sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def _write_unique(kind, record):
    CHECKPOINT.mkdir(parents=True, exist_ok=True)
    token = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ') + '_' + uuid.uuid4().hex[:8]
    path = CHECKPOINT / (kind + '_' + token + '.json')
    assert not path.exists()
    record.update(schema=1, created_utc=datetime.now(timezone.utc).isoformat(), tool_sha256=_sha(__file__))
    path.write_text(json.dumps(record, sort_keys=True, indent=2, allow_nan=False) + '\n', encoding='utf-8')
    return path


def _u():
    import unreal
    return unreal


def _package(obj):
    if not obj:
        return None
    return obj.get_path_name().split('.')[0]


def _dirty():
    u = _u()
    return dict(maps=sorted(_package(p) for p in u.EditorLoadingAndSavingUtils.get_dirty_map_packages()),
                content=sorted(_package(p) for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()))


def _promotion_chain():
    verify = _json(LIBRARY_VERIFY)
    assert _sha(LIBRARY_VERIFY) == LIBRARY_VERIFY_SHA256, 'Fresh combined library verifier receipt changed'
    assert verify.get('status') == 'PASS' and verify.get('counts', {}).get('fail') == 0
    assert verify.get('counts', {}).get('pending') == 0
    assert isinstance(verify.get('checks'), list)
    assert len(verify['checks']) == verify['counts'].get('pass')
    assert all(c.get('status') == 'PASS' for c in verify['checks'])
    retention = [c for c in verify['checks'] if c.get('name') == 'Belfry palette exact three-artifact library supersession and reopen']
    assert len(retention) == 1 and retention[0]['status'] == 'PASS'
    for rel, row in retention[0]['detail']['supersessions'].items():
        path = ROOT / rel
        assert path.is_file() and _sha(path) == row['after'], 'Current library supersession differs: ' + rel
    for rel, digest in retention[0]['detail']['evidence'].items():
        assert _sha(ROOT / rel) == digest, 'Current library reopen evidence changed: ' + rel
    current_blends = {}
    for rel in ('Tools/WarrensVariantCKit/Output/WarrensVariantC_Diorama.blend',
                'Tools/WarrensVariantCKit/Output/WarrensVariantC_KitLibrary.blend'):
        path = ROOT / rel
        assert path.is_file()
        current_blends[rel] = _sha(path)
    assert _sha(R03_APPROVAL) == R03_APPROVAL_SHA256, 'Approved R03 source review changed'
    assert _sha(R03_RECEIPT) == R03_RECEIPT_SHA256, 'Approved R03 source receipt changed'
    r03 = _json(R03_RECEIPT)
    assert r03['bindings'][0]['image_sha256'] == IMAGE_SHA256
    assert r03['source_sha256'] == current_blends['Tools/WarrensVariantCKit/Output/WarrensVariantC_Diorama.blend']
    return dict(verification_path=LIBRARY_VERIFY.relative_to(ROOT).as_posix(),
                verification_sha256=_sha(LIBRARY_VERIFY), status=verify['status'],
                passing_checks=verify['counts']['pass'], current_blender_sha256=current_blends,
                r03_source_approval=dict(path=R03_APPROVAL.relative_to(ROOT).as_posix(), sha256=R03_APPROVAL_SHA256),
                r03_source_receipt=dict(path=R03_RECEIPT.relative_to(ROOT).as_posix(), sha256=R03_RECEIPT_SHA256))


def _content_guards():
    """Recalculate the current 555-key roster and add all maps, palette assets and Blends."""
    result = {}
    roster = _json(REVIEW / 'belfry-palette/source_guards.json')
    assert len(roster) == 555
    for rel in sorted(roster):
        path = ROOT / rel
        assert path.is_file(), 'Current source-guard path is missing: ' + rel
        result[rel] = _sha(path)  # Use the roster only as a path set; old hashes are superseded.
    for path in sorted((ROOT / 'Content').rglob('*.umap')):
        result[path.relative_to(ROOT).as_posix()] = _sha(path)
    for rel in (
        'Content/Mars/Environment/ChainCrossingKit/Materials/M_CCK_ART01.uasset',
        'Content/Mars/Environment/ChainCrossingKit/Textures/T_CCK_ART01_RoyalClocheCrest.uasset',
        'Content/Mars/Environment/ChainCrossingKit/Meshes/WarrensC_CCS78_MaintenanceNoticeBoard_Mars_SM.uasset',
        'Content/Mars/Environment/WarrensVariantCKit/Meshes/WarrensC_WVC083_EmblemSurfaceCarrier_Mars_SM.uasset',
        'Content/Mars/Environment/WarrensVariantCKit/Materials/M_WVC_BelfryStone.uasset',
        'Content/Mars/Environment/WarrensVariantCKit/Materials/M_WVC_BelfryFlagstone.uasset',
        'Tools/WarrensVariantCKit/Output/WarrensVariantC_Diorama.blend',
        'Tools/WarrensVariantCKit/Output/WarrensVariantC_KitLibrary.blend',
    ):
        path = ROOT / rel
        assert path.is_file(), 'Missing guarded input: ' + rel
        result[rel] = _sha(path)
    return result


def _receipt(path, expected_sha, phase):
    path = Path(path)
    assert path.is_file() and _sha(path) == expected_sha, phase + ' receipt hash mismatch'
    record = _json(path)
    assert record.get('phase') == phase and record.get('schema') == 1
    return path, record


def _assert_assets_absent(u):
    for asset in (TEXTURE_PATH, MATERIAL_PATH):
        disk = ROOT / ('Content/' + asset.removeprefix('/Game/') + '.uasset')
        assert not disk.exists() and not u.EditorAssetLibrary.does_asset_exist(asset), 'Refuse preexisting target: ' + asset


def _export_material(u, material, label):
    folder = CHECKPOINT / 'graphs'
    folder.mkdir(parents=True, exist_ok=True)
    token = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ') + '_' + uuid.uuid4().hex[:6]
    path = folder / (label + '_' + token + '.t3d')
    task = u.AssetExportTask()
    for name, value in dict(object=material, exporter=u.ObjectExporterT3D(), filename=str(path), selected=False,
                            replace_identical=False, prompt=False, automated=True, use_file_archive=False,
                            write_empty_files=False).items():
        task.set_editor_property(name, value)
    assert u.Exporter.run_asset_export_task(task), list(task.get_editor_property('errors'))
    assert not list(task.get_editor_property('errors')) and path.is_file() and path.stat().st_size > 0
    return path


def _parse_t3d(path):
    text = Path(path).read_bytes()
    text = text.decode('utf-16' if text.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')
    blocks, stack = {}, []
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith('Begin Object '):
            m = re.search(r'\bName="([^"]+)"', line)
            assert m, 'Unrecognized public material export object header'
            stack.append(m.group(1))
            blocks.setdefault(tuple(stack), {})
        elif line == 'End Object':
            assert stack
            stack.pop()
        elif line:
            assert stack and '=' in line, 'Unrecognized public material export property'
            field, value = line.split('=', 1)
            assert field not in blocks[tuple(stack)]
            blocks[tuple(stack)][field] = value
    assert not stack and blocks
    return {'/'.join(k): v for k, v in blocks.items()}


def _canonical_graph(path, root_name, root_asset_path):
    blocks = _parse_t3d(path)
    normalized, root_ids = {}, {}
    for object_path, props in blocks.items():
        key = object_path.replace(root_name, '@M@')
        assert key not in normalized
        normalized[key] = {}
        for field, value in props.items():
            if object_path == root_name and field == 'StateId':
                assert re.fullmatch(r'[0-9A-F]{32}', value)
                root_ids[field] = value
            else:
                normalized[key][field] = value.replace(root_asset_path, '@M@').replace(root_name, '@M@')
    return normalized, root_ids


def _graph_delta(source_t3d, candidate_t3d, source_name, candidate_name, source_asset, candidate_asset,
                 new_texture_object_path):
    expected, source_ids = _canonical_graph(source_t3d, source_name, source_asset)
    actual, candidate_ids = _canonical_graph(candidate_t3d, candidate_name, candidate_asset)
    sample_key = '@M@/MaterialExpressionTextureSample_0'
    assert sample_key in expected and sample_key in actual
    # T3D exporter serializes a material expression texture as a quoted object path.
    old_value = expected[sample_key].get('Texture')
    new_value = actual[sample_key].get('Texture')
    assert old_value and SOURCE_TEXTURE in old_value and new_texture_object_path in new_value
    expected[sample_key]['Texture'] = new_value
    # Compilation may update the candidate identity and these explicitly observed derived fields.
    root = '@M@'
    allowed_root_changes = {}
    for field in ('ReferencedTextureGuids(0)', 'TextureStreamingData(0)', 'LightingGuid'):
        if field in expected[root] or field in actual[root]:
            assert field in expected[root] and field in actual[root]
            if field == 'TextureStreamingData(0)':
                old_ref = SOURCE_TEXTURE + '.T_CCK_ART01_RoyalClocheCrest'
                new_name = TEXTURE_PATH.rsplit('/', 1)[1]
                wanted_streaming = expected[root][field].replace(old_ref, new_texture_object_path)
                wanted_streaming = wanted_streaming.replace('T_CCK_ART01_RoyalClocheCrest', new_name)
                assert wanted_streaming != expected[root][field]
                assert wanted_streaming == actual[root][field], 'Unexpected change to texture streaming settings'
                expected[root][field] = wanted_streaming
            else:
                assert re.fullmatch(r'[0-9A-F]{32}', actual[root][field])
                allowed_root_changes[field] = dict(source=expected[root][field], candidate=actual[root][field])
                expected[root][field] = actual[root][field]
    assert expected == actual, 'Material copy has changes beyond texture binding and texture-derived root metadata'
    return dict(source_state_id=source_ids.get('StateId'), candidate_state_id=candidate_ids.get('StateId'),
                derived_root_metadata=allowed_root_changes,
                source_graph_sha256=_sha(source_t3d), candidate_graph_sha256=_sha(candidate_t3d),
                exact_delta='MaterialExpressionTextureSample_0.Texture plus exact texture-reference substitution in TextureStreamingData(0), updated ReferencedTextureGuids(0), and candidate LightingGuid')


def _asset_paths_absent_editor(u):
    _assert_assets_absent(u)


def preflight_assets():
    """Read-only proof before creating the two owned art assets."""
    u = _u()
    ed = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    assert ed.get_game_world() is None, 'Stop PIE before asset preflight'
    assert _dirty() == dict(maps=[], content=[]), 'Asset preparation requires clean map/content packages'
    assert _sha(IMAGE) == IMAGE_SHA256
    assert _sha(ART01_T3D) == ART01_T3D_SHA256
    chain = _promotion_chain()
    guards = _content_guards()
    _asset_paths_absent_editor(u)
    material = u.load_asset(SOURCE_MATERIAL)
    assert isinstance(material, u.Material) and _package(material) == SOURCE_MATERIAL
    source_file = ROOT / ('Content/' + SOURCE_MATERIAL.removeprefix('/Game/') + '.uasset')
    assert source_file.is_file()
    graph = _export_material(u, material, 'ART01_source_preflight')
    baseline_graph, _ = _canonical_graph(ART01_T3D, 'M_CCK_ART01', SOURCE_MATERIAL)
    current_graph, _ = _canonical_graph(graph, 'M_CCK_ART01', SOURCE_MATERIAL)
    assert current_graph == baseline_graph, 'Current ART01 graph differs from approved observed graph'
    receipt = dict(phase='asset_preflight', status='READ_ONLY_PREPARED',
        image=dict(path=IMAGE.relative_to(ROOT).as_posix(), sha256=IMAGE_SHA256),
        source_material=dict(path=SOURCE_MATERIAL, package_sha256=_sha(source_file), graph_file=graph.relative_to(ROOT).as_posix(),
                             graph_sha256=_sha(graph)),
        targets=dict(texture=TEXTURE_PATH, material=MATERIAL_PATH, both_absent=True),
        promotion_chain=chain, file_guards=guards, dirty_before=_dirty(),
        boundary='Read-only asset preflight. Does not import or create assets.')
    path = _write_unique(ASSET_RECEIPT, receipt)
    return dict(receipt=str(path.relative_to(ROOT)), sha256=_sha(path), status=receipt['status'])


def _asset_files_match(record):
    for key in ('texture', 'material'):
        item = record[key]
        path = ROOT / ('Content/' + item['path'].removeprefix('/Game/') + '.uasset')
        assert path.is_file() and _sha(path) == item['package_sha256'], 'Owned asset changed: ' + item['path']


def create_assets(preflight_file, preflight_sha256):
    """Create exactly one owned Texture2D and one duplicate Material."""
    u = _u()
    path, prior = _receipt(preflight_file, preflight_sha256, 'asset_preflight')
    assert prior['status'] == 'READ_ONLY_PREPARED'
    assert _dirty() == dict(maps=[], content=[])
    assert _content_guards() == prior['file_guards']
    assert _promotion_chain() == prior['promotion_chain']
    assert _sha(IMAGE) == IMAGE_SHA256
    source = u.load_asset(SOURCE_MATERIAL)
    source_file = ROOT / ('Content/' + SOURCE_MATERIAL.removeprefix('/Game/') + '.uasset')
    assert source and _sha(source_file) == prior['source_material']['package_sha256']
    source_graph = _export_material(u, source, 'ART01_source_create')
    baseline_graph, _ = _canonical_graph(ART01_T3D, 'M_CCK_ART01', SOURCE_MATERIAL)
    current_graph, _ = _canonical_graph(source_graph, 'M_CCK_ART01', SOURCE_MATERIAL)
    assert current_graph == baseline_graph
    _asset_paths_absent_editor(u)

    importer_path = HERE.parent / 'ChainCrossingKit/import_assets.py'
    importer_spec = importlib.util.spec_from_file_location('_wvc_bank_identity_import_assets', importer_path)
    assert importer_spec and importer_spec.loader
    importer = importlib.util.module_from_spec(importer_spec)
    importer_spec.loader.exec_module(importer)
    # The importer is reused for one texture only, with isolated owner/destination globals.
    importer.MATERIAL_DEST = DEST
    importer.OWNER = OWNER
    importer.TAG = TAG
    recipes = importer.recipes()
    recipe = recipes['ART03']
    assert recipe.get('alpha') == 'masked' and list(recipe.get('maps', {})) == ['BaseColor']
    spec = importer.texture_spec('art/painted/ART03_BellBankEmblem-r02.png', 'BaseColor', recipe)
    spec['source'] = IMAGE
    spec['name'] = TEXTURE_PATH.rsplit('/', 1)[1]
    stage, texture, copied, source_graph_path, candidate_graph_path, graph_delta = 'texture_import', None, None, source_graph, None, None
    try:
        assert importer.import_texture(spec)
        texture = u.load_asset(TEXTURE_PATH)
        assert isinstance(texture, u.Texture2D) and _package(texture) == TEXTURE_PATH
        assert texture.get_editor_property('srgb') is True
        assert texture.get_editor_property('address_x') == u.TextureAddress.TA_CLAMP
        assert texture.get_editor_property('address_y') == u.TextureAddress.TA_CLAMP
        assert u.EditorAssetLibrary.get_metadata_tag(texture, TAG) == OWNER

        stage = 'material_duplicate'
        assert not u.EditorAssetLibrary.does_asset_exist(MATERIAL_PATH)
        copied = u.EditorAssetLibrary.duplicate_asset(SOURCE_MATERIAL, MATERIAL_PATH)
        if copied is not None:
            # Establish ownership before any validation or graph mutation can fail.
            u.EditorAssetLibrary.set_metadata_tag(copied, TAG, OWNER)
        assert isinstance(copied, u.Material) and _package(copied) == MATERIAL_PATH
        stage = 'material_graph_validation'
        expressions = [node for node in u.ObjectIterator(u.MaterialExpression) if node.get_outer() == copied]
        samples = [node for node in expressions if isinstance(node, u.MaterialExpressionTextureSample)]
        assert len(samples) == 1 and _package(samples[0].get_editor_property('texture')) == SOURCE_TEXTURE
        samples[0].set_editor_property('texture', texture)
        u.MaterialEditingLibrary.recompile_material(copied)
        candidate_graph_path = _export_material(u, copied, 'ART03_candidate_after_recompile')
        graph_delta = _graph_delta(source_graph, candidate_graph_path, source.get_name(), copied.get_name(),
                                   SOURCE_MATERIAL, MATERIAL_PATH, texture.get_path_name())
        assert copied.get_editor_property('blend_mode') == u.BlendMode.BLEND_MASKED
        assert copied.get_editor_property('two_sided') is True
        u.EditorAssetLibrary.set_metadata_tag(copied, 'SourceMaterialSHA256', prior['source_material']['package_sha256'])
        u.EditorAssetLibrary.set_metadata_tag(copied, 'SourceImageSHA256', IMAGE_SHA256)
        u.EditorAssetLibrary.set_metadata_tag(copied, 'GraphDelta', graph_delta['exact_delta'])
        stage = 'material_save'
        assert u.EditorAssetLibrary.save_loaded_asset(copied, False)

        texture_file = ROOT / ('Content/' + TEXTURE_PATH.removeprefix('/Game/') + '.uasset')
        material_file = ROOT / ('Content/' + MATERIAL_PATH.removeprefix('/Game/') + '.uasset')
        assert texture_file.is_file() and material_file.is_file()
        assert _dirty() == dict(maps=[], content=[]), 'Only the two owned assets may be saved; unexpected package dirt'
        assert _content_guards() == prior['file_guards']
    except Exception as exc:
        def try_capture(callback):
            try:
                return callback()
            except Exception as capture_error:
                return dict(capture_error=repr(capture_error))

        def existing_asset(path):
            file = ROOT / ('Content/' + path.removeprefix('/Game/') + '.uasset')
            exists = try_capture(lambda: u.EditorAssetLibrary.does_asset_exist(path))
            owner = try_capture(lambda: u.EditorAssetLibrary.get_metadata_tag(u.load_asset(path), TAG)) if exists is True else None
            return dict(path=path, exists=exists, package_sha256=_sha(file) if file.is_file() else None,
                        metadata_owner=owner)
        failure = dict(phase='partial_asset_prep_failure', status='PARTIAL_ASSET_PREP_FAILURE', failed_stage=stage,
            error=repr(exc), existing_assets=[existing_asset(TEXTURE_PATH), existing_asset(MATERIAL_PATH)],
            source_guards_before=prior['file_guards'], source_guards_now=try_capture(_content_guards),
            dirty_now=try_capture(_dirty), source_graph_file=source_graph_path.relative_to(ROOT).as_posix(),
            source_graph_sha256=_sha(source_graph_path),
            candidate_graph_file=candidate_graph_path.relative_to(ROOT).as_posix() if candidate_graph_path else None,
            candidate_graph_sha256=_sha(candidate_graph_path) if candidate_graph_path else None,
            graph_delta=graph_delta, automatic_cleanup='none; preserve partial owned assets for diagnosis')
        _write_unique('partial_asset_prep_failure', failure)
        raise
    report = dict(phase='assets_created', status='TWO_OWNED_ASSETS_CREATED',
        preflight=dict(path=path.relative_to(ROOT).as_posix(), sha256=preflight_sha256),
        texture=dict(path=TEXTURE_PATH, source_sha256=IMAGE_SHA256, package_sha256=_sha(texture_file),
                     owner=OWNER, srgb=True, address='CLAMP'),
        material=dict(path=MATERIAL_PATH, package_sha256=_sha(material_file), source=SOURCE_MATERIAL,
                      source_package_sha256=prior['source_material']['package_sha256'], graph=graph_delta),
        protected_file_guards=prior['file_guards'], promotion_chain=prior['promotion_chain'],
        dirty_after=_dirty(), boundary='Only the ART03 Texture2D and its duplicate ART01 Material were created/saved.')
    out = _write_unique('assets_created', report)
    return dict(receipt=str(out.relative_to(ROOT)), sha256=_sha(out), status=report['status'])


def _state_holder():
    if STATE_MODULE not in sys.modules:
        import types
        sys.modules[STATE_MODULE] = types.ModuleType(STATE_MODULE)
        sys.modules[STATE_MODULE].active = None
    return sys.modules[STATE_MODULE]


def _pose(transform):
    return dict(at=[float(v) for v in transform.translation.to_tuple()],
        scale=[float(v) for v in transform.scale3d.to_tuple()],
        q=[float(transform.rotation.x), float(transform.rotation.y), float(transform.rotation.z), float(transform.rotation.w)])


def _near(actual, wanted):
    return ((actual.translation - wanted.translation).length() < 0.1 and
            (actual.scale3d - wanted.scale3d).length() < 0.001 and
            actual.rotation.angular_distance(wanted.rotation) < 0.001)


def _component(component):
    owner = component.get_owner()
    return dict(path=component.get_path_name(), owner=owner.get_path_name(), owner_label=owner.get_actor_label(),
        level=owner.get_level().get_path_name(), mesh=_package(component.static_mesh),
        materials=[_package(m) for m in component.get_materials()], pose=_pose(component.get_world_transform()),
        visible=component.is_visible(), hidden_in_game=component.get_editor_property('hidden_in_game'),
        cast_shadow=component.cast_shadow, collision_profile=str(component.get_collision_profile_name()),
        collision_enabled=str(component.get_collision_enabled()), collision_type=str(component.get_collision_object_type()),
        body_instance=component.get_editor_property('body_instance').export_text(),
        generate_overlap_events=component.get_editor_property('generate_overlap_events'),
        custom_data_floats=component.get_editor_property('num_custom_data_floats'),
        random_seed=component.get_editor_property('instancing_random_seed'),
        cull_start=component.get_editor_property('instance_start_cull_distance'),
        cull_end=component.get_editor_property('instance_end_cull_distance'),
        instances=[_pose(component.get_instance_transform(i, world_space=True)) for i in range(component.get_instance_count())])


def _hism_snapshot(world):
    u = _u()
    actors = list(u.GameplayStatics.get_all_actors_of_class(world, u.Actor))
    rows = {}
    for actor in actors:
        for component in actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent):
            key = component.get_path_name()
            assert key not in rows
            rows[key] = _component(component)
    return actors, rows


def _row_transform(u, row, pivot, level_transform):
    local = u.Transform(location=u.Vector(*[(row['at'][i] - pivot[i]) * 100.0 for i in range(3)]),
        rotation=u.Rotator(pitch=0.0, yaw=float(row['yaw']), roll=0.0),
        scale=u.Vector(*[float(v) for v in row['scale']]))
    return u.MathLibrary.compose_transforms(local, level_transform)


def _fit_rows():
    fit = _json(FIT)
    placements = fit['placements']
    result = {}
    for key, ident in (('board', 'CCS78'), ('card', 'WVC083_ART01')):
        rows = [r for r in placements if r.get('tile') == 'Hub' and r.get('id') == ident]
        assert len(rows) == 1
        result[key] = rows[0]
    pivot = fit['pivots']['Hub']
    belfry_pivot = fit['pivots']['Belfry']
    assert len(pivot) == len(belfry_pivot) == 3
    return result, belfry_pivot


def preflight_trial(exact_belfry_level_path, asset_receipt_file, asset_receipt_sha256):
    """Read-only PIE inventory and source-instance admission for the two-component trial."""
    u = _u()
    asset_path, assets = _receipt(asset_receipt_file, asset_receipt_sha256, 'assets_created')
    assert assets.get('status') == 'TWO_OWNED_ASSETS_CREATED'
    _asset_files_match(assets)
    assert _dirty() == dict(maps=[], content=[])
    chain = _promotion_chain()
    assert chain == assets['promotion_chain']
    guards = _content_guards()
    ed = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    world = ed.get_game_world()
    assert world and 'Warrens_VariantC_Mars_MAP' in world.get_name(), 'Requires actual Variant C PIE world'
    assert _package(u.load_asset(MATERIAL_PATH)) == MATERIAL_PATH
    actors, snapshot = _hism_snapshot(world)
    levels = {a.get_level().get_path_name(): a.get_level() for a in actors}
    assert exact_belfry_level_path in levels and 'LI_Warrens_Belfry' in exact_belfry_level_path
    belfry_level = levels[exact_belfry_level_path]
    hub_levels = [level for path, level in levels.items() if 'LI_Warrens_Hub' in path]
    assert len(hub_levels) == 1, 'Need exactly one loaded Hub Level Instance'
    rows, pivot = _fit_rows()
    manifest = _json(MANIFEST)
    chain_manifest = _json(CHAIN_MANIFEST)
    wvc_mesh_names = {r['id']: r['name'] for r in manifest.get('assets', [])}
    ccs_mesh_names = {r['id']: r['name'] for r in chain_manifest.get('assets', [])}
    assert wvc_mesh_names.get('WVC083') == SOURCE_MESHES['card'].rsplit('/', 1)[1]
    assert ccs_mesh_names.get('CCS78') == SOURCE_MESHES['board'].rsplit('/', 1)[1]
    hub_level = hub_levels[0]
    hub_level_actor = next(a for a in actors if a.get_level() == hub_level)
    belfry_level_actor = next(a for a in actors if a.get_level() == belfry_level)
    sources = {}
    for key in ('board', 'card'):
        row = rows[key]
        expected_mesh = SOURCE_MESHES[key]
        source_pose = _row_transform(u, row, _json(FIT)['pivots']['Hub'], hub_level_actor.get_level_transform())
        matches = []
        for actor in actors:
            if actor.get_level() != hub_level:
                continue
            for component in actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent):
                if _package(component.static_mesh) != expected_mesh:
                    continue
                assert component.get_collision_enabled() == u.CollisionEnabled.NO_COLLISION
                for index in range(component.get_instance_count()):
                    pose = component.get_instance_transform(index, world_space=True)
                    if _near(pose, source_pose):
                        matches.append((actor, component, index))
        assert len(matches) == 1, key + ' Hub source placement did not resolve uniquely'
        sources[key] = dict(actor=matches[0][0].get_path_name(), actor_label=matches[0][0].get_actor_label(),
            component=matches[0][1].get_path_name(), index=matches[0][2], source_pose=_pose(source_pose),
            component_snapshot=snapshot[matches[0][1].get_path_name()])
    target_transforms = {}
    for key in ('board', 'card'):
        target = TARGET_ROWS[key]
        fake_row = dict(at=target['at'], scale=target['scale'], yaw=target['yaw'])
        target_transforms[key] = _pose(_row_transform(u, fake_row, pivot, belfry_level_actor.get_level_transform()))
    report = dict(phase='pie_preflight', status='PIE_SOURCES_AND_TARGETS_RESOLVED',
        asset_receipt=dict(path=asset_path.relative_to(ROOT).as_posix(), sha256=asset_receipt_sha256),
        world_path=world.get_path_name(), belfry_level_path=exact_belfry_level_path,
        hub_level_path=hub_level.get_path_name(), belfry_pivot=pivot, sources=sources,
        target_transforms=target_transforms, original_hism_roster=snapshot,
        file_guards=guards, promotion_chain=chain, dirty_before=_dirty(),
        boundary='Read-only PIE source/placement inventory. No actors/components/materials were changed.')
    out = _write_unique(TRIAL_RECEIPT, report)
    return dict(receipt=str(out.relative_to(ROOT)), sha256=_sha(out), status=report['status'])


def _trial_state():
    holder = _state_holder()
    assert holder.active is None, 'Restore any previous trial first'
    return holder


def _load_trial_preflight(path, digest):
    p, record = _receipt(path, digest, 'pie_preflight')
    assert record.get('status') == 'PIE_SOURCES_AND_TARGETS_RESOLVED'
    return p, record


def _live_world(state):
    u = _u()
    world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert world and world.get_path_name() == state['world_path'] and world == state['world']
    return world


def _make_trial_clone(state, key, material=None):
    u = _u()
    source = state['sources'][key]['component_obj']
    owner = source.get_owner()
    assert source.get_collision_enabled() == u.CollisionEnabled.NO_COLLISION
    clone = u.SystemLibrary.duplicate_object(source, owner, TRIAL_PREFIX + key + '_' + state['token'])
    if clone is not None:
        state['clones'].append(clone)
    assert isinstance(clone, u.HierarchicalInstancedStaticMeshComponent) and clone.get_outer() == owner
    assert clone.get_collision_enabled() == u.CollisionEnabled.NO_COLLISION
    clone.set_visibility(False, False)
    clone.clear_instances()
    owner.call_method('FinishAddComponent', args=(clone, True, source.get_relative_transform()))
    if material:
        clone.set_material(0, material)
    transform = state['target_transforms'][key]
    pose = u.Transform(location=u.Vector(*transform['at']),
        rotation=u.Quat(transform['q'][0], transform['q'][1], transform['q'][2], transform['q'][3]).rotator(),
        scale=u.Vector(*transform['scale']))
    assert list(clone.add_instances([pose], True, True, False)) == [0]
    clone.set_visibility(True, False)
    assert clone.get_world() == state['world'] and clone.get_owner() == owner
    assert clone.get_collision_enabled() == u.CollisionEnabled.NO_COLLISION
    observed = _component(clone)
    assert len(observed['instances']) == 1 and observed['mesh'] == state['sources'][key]['component_snapshot']['mesh']
    assert _near(clone.get_instance_transform(0, world_space=True), pose)
    return clone, observed


def apply_trial(preflight_file, preflight_sha256):
    """Create the two temporary NoCollision instances in the current C PIE world."""
    u = _u()
    path, prior = _load_trial_preflight(preflight_file, preflight_sha256)
    holder = _trial_state()
    assert _dirty() == dict(maps=[], content=[])
    assert _content_guards() == prior['file_guards']
    assert _promotion_chain() == prior['promotion_chain']
    world = _live_world(dict(world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world(), world_path=prior['world_path']))
    actors, snapshot = _hism_snapshot(world)
    assert snapshot == prior['original_hism_roster'], 'World source roster changed since PIE preflight'
    sources = {}
    for key, binding in prior['sources'].items():
        component = next(c for a in actors if a.get_path_name() == binding['actor']
                         for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
                         if c.get_path_name() == binding['component'])
        sources[key] = dict(component_obj=component, **binding)
    candidate = u.load_asset(MATERIAL_PATH)
    assert isinstance(candidate, u.Material) and _package(candidate) == MATERIAL_PATH
    state = dict(token=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ') + '_' + uuid.uuid4().hex[:8],
        world=world, world_path=world.get_path_name(), sources=sources, clones=[], baseline=snapshot,
        source_roster=snapshot, target_transforms=prior['target_transforms'], file_guards=prior['file_guards'],
        promotion_chain=prior['promotion_chain'], dirty=_dirty(), candidate=candidate, active=True)
    holder.active = state
    try:
        board, board_record = _make_trial_clone(state, 'board')
        card, card_record = _make_trial_clone(state, 'card', candidate)
        state['clones_by_key'] = dict(board=board, card=card)
        state['active_records'] = dict(board=board_record, card=card_record)
        after = _hism_snapshot(world)[1]
        assert len(after) == len(snapshot) + 2
        assert all(after[k] == snapshot[k] for k in snapshot)
        added = [v for k, v in after.items() if k not in snapshot]
        assert len(added) == 2 and all(v['collision_enabled'] == str(u.CollisionEnabled.NO_COLLISION) for v in added)
        assert any(v['materials'][0] == MATERIAL_PATH for v in added if v['mesh'] == SOURCE_MESHES['card'])
        report = dict(phase='pie_trial_applied', status='TWO_TEMPORARY_COMPONENTS_ACTIVE',
            preflight=dict(path=path.relative_to(ROOT).as_posix(), sha256=preflight_sha256),
            clone_components=state['active_records'], visible_hism_roster_count=len(after),
            board_pose=prior['target_transforms']['board'], card_pose=prior['target_transforms']['card'],
            original_components_unchanged=True, maps_unchanged=True, assets_unchanged=True,
            boundary='Unsaved PIE only. Two NoCollision HISM clones are visible; original Hub components remain unchanged.')
        out = _write_unique('pie_trial_applied', report)
        state['last_receipt'] = str(out.relative_to(ROOT))
        state['last_receipt_sha256'] = _sha(out)
        return dict(receipt=state['last_receipt'], sha256=state['last_receipt_sha256'], status=report['status'])
    except Exception:
        # Keep active references for an explicit restore after any partial setup failure.
        raise


def toggle_trial(assembly_visible):
    """Toggle the complete temporary board/card assembly for matched views."""
    holder = _state_holder()
    state = holder.active
    assert state and state.get('active') and set(state.get('clones_by_key', {})) == {'board', 'card'}
    world = _live_world(state)
    card = state['clones_by_key']['card']
    board = state['clones_by_key']['board']
    assert board.is_visible() == card.is_visible(), 'Trial assembly visibility diverged before toggle'
    board.set_visibility(bool(assembly_visible), False)
    card.set_visibility(bool(assembly_visible), False)
    assert board.is_visible() == bool(assembly_visible) and card.is_visible() == bool(assembly_visible)
    report = dict(phase='pie_trial_toggle', status='TOGGLED', world_path=world.get_path_name(),
        assembly_visible=bool(assembly_visible), board_visible=board.is_visible(), card_visible=card.is_visible(),
        both_clones_changed_together=True,
        previous_receipt=state.get('last_receipt'), previous_receipt_sha256=state.get('last_receipt_sha256'))
    out = _write_unique('pie_trial_toggle', report)
    state['last_receipt'] = str(out.relative_to(ROOT))
    state['last_receipt_sha256'] = _sha(out)
    return dict(receipt=state['last_receipt'], sha256=state['last_receipt_sha256'], status=report['status'])


def restore_trial():
    """Destroy only the two trial clones, prove exact original HISM restoration, release PIE refs."""
    holder = _state_holder()
    state = holder.active
    assert state and state.get('active')
    world = _live_world(state)
    u = _u()
    for clone in reversed(state['clones']):
        if u.SystemLibrary.is_valid(clone):
            clone.set_visibility(False, False)
            clone.destroy_component(clone.get_owner())
    state['clones'].clear()
    actors, after = _hism_snapshot(world)
    assert after == state['baseline'], 'Original complete HISM roster/instances/materials did not restore exactly'
    assert _content_guards() == state['file_guards']
    assert _promotion_chain() == state['promotion_chain']
    assert _dirty() == state['dirty'] == dict(maps=[], content=[])
    report = dict(phase='pie_trial_restored', status='RESTORED_AND_VERIFIED',
        original_hism_count=len(after), original_hism_roster_exact=True,
        source_components_unchanged=True, no_trial_components_remaining=True,
        file_guards_unchanged=True, promotion_chain_unchanged=True, dirty_after=_dirty(),
        preceding_receipt=state.get('last_receipt'), preceding_receipt_sha256=state.get('last_receipt_sha256'),
        boundary='Exact original runtime HISM state restored; owned candidate assets remain saved for review.')
    out = _write_unique('pie_trial_restored', report)
    result = dict(receipt=str(out.relative_to(ROOT)), sha256=_sha(out), status=report['status'])
    # Release every retained PIE UObject before PIE is stopped or restarted.
    state.clear()
    holder.active = None
    return result
