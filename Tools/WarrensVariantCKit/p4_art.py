"""Owned Bellkeeper presentation material and exact optional parameter binding.

Does not change phrase, glyph geometry, collision, controls or puzzle state.
Bindings can be inspected in a dirty, unsaved level before an approved save.
"""
import json
import hashlib
import importlib.util
from pathlib import Path

import unreal as u

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/art/warrens-c-gameplay-review-20261024'
OWNER = 'Mars.WarrensC.BellkeeperArt.20261024'
TAG = 'WarrensBellkeeperArtOwner'
COLOR_PATH = '/Game/Mars/Environment/WarrensVariantCKit/Materials/M_WVC_BellkeeperPrimaryColor'
KIT = '/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_'
FIELDS = {
    'Mars_Bellkeeper_EntityScript': dict(BodyMaterialOverride=KIT + 'TX10', FaceMaterialOverride=COLOR_PATH,
        ControlMaterialOverride=KIT + 'TX10', GlyphMaterialOverride=COLOR_PATH, IndicatorMaterialOverride=COLOR_PATH),
    'Mars_BellkeeperClue_EntityScript': dict(BodyMaterialOverride=KIT + 'TX01', FaceMaterialOverride=COLOR_PATH, GlyphMaterialOverride=COLOR_PATH),
}

LIVE_PARTS = {
    'Bellkeeper_Plate': KIT + 'TX10', 'BellkeeperClue_Plaque': KIT + 'TX01',
    'Bellkeeper_DialFace': COLOR_PATH, 'BellkeeperClue_Disc': COLOR_PATH,
    'Bellkeeper_Knob': KIT + 'TX10', 'Bellkeeper_Bell': KIT + 'TX10',
    'Bellkeeper_Glyph': COLOR_PATH, 'Bellkeeper_Pointer': COLOR_PATH,
    'Bellkeeper_Candle': COLOR_PATH, 'Bellkeeper_Lamp': COLOR_PATH,
}


def preview_live():
    world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert world and 'UEDPIE' in world.get_path_name()
    rows = []
    for actor in u.GameplayStatics.get_all_actors_of_class(world, u.Actor):
        if 'Ck_UnrealComponent_Host' not in actor.get_name():
            continue
        for component in actor.get_components_by_class(u.StaticMeshComponent):
            handle = u.Ck_Utils_UnrealComponent_UE.try_get_owning_handle_from_component(component)
            name = str(u.Ck_Utils_Handle_UE.get_debug_name(handle)).removeprefix('UnrealComponent: ')
            if name not in LIVE_PARTS:
                continue
            original = component.get_material(0)
            color = original.get_vector_parameter_value('PrimaryColor') if isinstance(original, u.MaterialInstanceDynamic) else None
            material = u.load_asset(LIVE_PARTS[name])
            assert material
            component.set_material(0, material)
            if LIVE_PARTS[name] == COLOR_PATH:
                assert color is not None, 'Missing legacy color for ' + name
                dynamic = component.create_dynamic_material_instance(0)
                dynamic.set_vector_parameter_value('PrimaryColor', color)
            rows.append(dict(part=name, component=component.get_path_name(), original=original.get_path_name(), candidate=material.get_path_name(), primary_color=str(color)))
    assert set(r['part'] for r in rows) == set(LIVE_PARTS)
    (OUT / 'P4_ART_LIVE_PREVIEW.json').write_text(json.dumps(dict(rows=rows, saved=False, boundary='PIE-only material trial on actual runtime parts. Existing PrimaryColor copied; state callbacks retain current dynamic material. No puzzle state, shape, phrase, light or map change.'), indent=2) + '\n')
    print('P4_LIVE_ART_PREVIEW', len(rows))
    return rows


def make_color_material():
    assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    eal = u.EditorAssetLibrary
    if eal.does_asset_exist(COLOR_PATH):
        material = u.load_asset(COLOR_PATH)
        assert isinstance(material, u.Material) and eal.get_metadata_tag(material, TAG) == OWNER
        assert eal.get_metadata_tag(material, 'GraphVersion') == '1'
        return material
    material = u.AssetToolsHelpers.get_asset_tools().create_asset(COLOR_PATH.rsplit('/', 1)[1], COLOR_PATH.rsplit('/', 1)[0], u.Material, u.MaterialFactoryNew())
    assert isinstance(material, u.Material)
    mel = u.MaterialEditingLibrary
    color = mel.create_material_expression(material, u.MaterialExpressionVectorParameter, -250, 0)
    color.set_editor_property('parameter_name', 'PrimaryColor')
    color.set_editor_property('default_value', u.LinearColor(.9, .85, .7, 1))
    assert mel.connect_material_property(color, '', u.MaterialProperty.MP_BASE_COLOR)
    roughness = mel.create_material_expression(material, u.MaterialExpressionConstant, -250, 180)
    roughness.set_editor_property('r', .86)
    assert mel.connect_material_property(roughness, '', u.MaterialProperty.MP_ROUGHNESS)
    material.set_editor_property('used_with_instanced_static_meshes', True)
    mel.recompile_material(material)
    eal.set_metadata_tag(material, TAG, OWNER)
    eal.set_metadata_tag(material, 'GraphVersion', '1')
    assert eal.save_loaded_asset(material, False)
    return material


def bind_preview():
    ed = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    world = ed.get_editor_world()
    assert ed.get_game_world() is None
    assert world.get_path_name().split('.')[0] == '/Game/Mars/Maps/Variants/v8c/LI_Warrens_Belfry'
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
    assert not u.EditorLoadingAndSavingUtils.get_dirty_content_packages()
    resolved = {name: {key: u.load_asset(path) for key, path in fields.items()} for name, fields in FIELDS.items()}
    assert all(value for fields in resolved.values() for value in fields.values())
    rows = []
    for actor in u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors():
        if not actor.get_path_name().startswith(world.get_path_name() + ':'):
            continue
        if 'Spawner' not in actor.get_class().get_name():
            continue
        script = actor.get_editor_property('_EntityScript')
        if not script or script.get_class().get_name() not in FIELDS:
            continue
        name = script.get_class().get_name()
        before = {key: script.get_editor_property(key) for key in FIELDS[name]}
        assert all(value is None for value in before.values()), 'Existing presentation binding must be reviewed'
        actor.modify()
        script.modify()
        for key, material in resolved[name].items():
            script.set_editor_property(key, material)
            assert script.get_editor_property(key) == material
        rows.append(dict(actor=actor.get_path_name(), cls=name, fields=FIELDS[name]))
    assert sorted(r['cls'] for r in rows) == sorted(FIELDS)
    (OUT / 'P4_ART_BINDING_PREVIEW.json').write_text(json.dumps(dict(rows=rows, saved=False, boundary='Only eight nullable material properties changed; original phrase, transforms, collision, control and reward data retained.'), indent=2) + '\n')
    print('P4_ART_UNSAVED_BINDING', json.dumps(rows))
    return rows


def save_binding():
    disk = ROOT / 'Content/Mars/Maps/Variants/v8c/LI_Warrens_Belfry.umap'
    receipt_path = ROOT / 'Saved/WarrensCGameplay-20261024/ArtCheckpoint/P4_Belfry.json'
    assert not receipt_path.exists(), 'Inspect preceding art receipt before reapplying'
    before = hashlib.sha256(disk.read_bytes()).hexdigest()
    assert before == 'a957d97b99c0ce2642484f317f69dd390f4205d1cd2fafcff26a89eb5ae99cea'
    spec = importlib.util.spec_from_file_location('p4_art_checkpoint', ROOT / 'Tools/WarrensVariantCKit/apply_art_delta.py')
    guard = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(guard)
    backup = guard.checkpoint(disk)
    guard.collision_guard()
    fields = ['SpawnTransform', 'Phrase', 'StartGlyphs', 'Rewards', 'CommitChannel', 'VentChannel', 'VentPulseSeconds', 'Source', 'PromptText', 'DialDegreesPerLookDegree', 'OwnedVent', 'BellOffsetWorld']

    def value(v):
        if isinstance(v, u.Object):
            return v.get_path_name()
        if hasattr(v, 'export_text'):
            return v.export_text()
        if isinstance(v, u.Array):
            return [value(x) for x in v]
        return str(v)

    def invariants():
        result = {}
        for actor in u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors():
            if 'Spawner' not in actor.get_class().get_name():
                continue
            script = actor.get_editor_property('_EntityScript')
            if not script or script.get_class().get_name() not in FIELDS:
                continue
            keys = fields if script.get_class().get_name() == 'Mars_Bellkeeper_EntityScript' else ['SpawnTransform', 'Phrase', 'GlyphSize']
            result[actor.get_actor_label()] = {key: value(script.get_editor_property(key)) for key in keys}
        assert len(result) == 2
        return result

    original = invariants()
    rows = bind_preview()
    assert invariants() == original, 'Non-art puzzle fields changed'
    settings = u.get_default_object(u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'))
    old = settings.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    try:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', type(old).DISABLE)
        assert u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
    finally:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', old)
    assert guard.collision_guard() == 54
    assert invariants() == original
    report = dict(before_sha256=before, after_sha256=hashlib.sha256(disk.read_bytes()).hexdigest(), checkpoint=backup, rows=rows,
                  non_art_fields_before_and_after=original, collision_files_preserved=54, auto_cook_restored=True,
                  boundary='Eight optional material fields only. No geometry, collision, phrase, size, reward, or interaction changes. Final lighting/distance readability remains unaccepted.')
    receipt_path.write_text(json.dumps(report, indent=2) + '\n')
    print('P4_ART_BINDING_SAVED', report['after_sha256'])
    return report
