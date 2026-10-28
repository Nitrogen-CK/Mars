"""Save the existing pending Props master after exact owner-aware readback."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def run(creator,asset,source):
    import unreal as u
    assert Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve()
    gate=json.loads((DOC/'NATIVE_PENDING_PROPS_MASTER_GATE_R01.json').read_text())
    assert gate['status']=='APPROVED_SAVE_EXISTING_REVIEWED_PROPS_MASTER_ONLY' and gate['tool_sha256']==sha(__file__)
    for p,h in gate['input_sha256'].items():assert sha(ROOT/p)==h
    target='/Game/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01/Persist_R01/Materials/M_WVC_Larder_Props_R01'
    assert creator.STATE['Props']['asset']==asset and asset.get_path_name().split('.')[0]==target
    assert not creator.disk(target).exists() and not (DOC/'retained_master_props_r01.json').exists()
    ed=u.get_editor_subsystem(u.UnrealEditorSubsystem);assert ed.get_game_world() is None and ed.get_editor_world().get_path_name()=='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    baseline=json.loads((DOC/'fitted-context-family-r01/retention_source_materials_r01.json').read_text())['Props']
    values=creator.load('material_graph_values_r02');links=creator.load('material_graph_links_r01');snapshots=creator.load('catacomb_plane_normal_materials')
    assert source.get_path_name()==baseline['material'] and values.read(source)==baseline['explicit_values'] and links.read(source)==baseline['links'] and snapshots.snapshot(source)==baseline['graph']
    reader=creator.load('material_copy_semantic_readback_r01')
    node_map={name:name for name in baseline['explicit_values']}
    proof=reader.readback(asset,source,node_map)
    assert proof['explicit_material_properties']==baseline['explicit_material_properties'] and proof['compile_statistics']==baseline['compile_statistics']
    helper=creator.load('room_tint_owned_assets_r01');creator.guard();assert helper.dirty()==dict(maps=[],content=[target])
    attempt=DOC/'pending_props_master_save_attempt_r01.json';assert not attempt.exists();attempt.write_text(json.dumps(dict(target=target,proof=proof,tool_sha256=sha(__file__)),indent=2)+'\n')
    settings=u.get_default_object(u.load_class(None,'/Script/UnrealEd.EditorLoadingSavingSettings'));autosave=settings.get_editor_property('bAutoSaveEnable')
    jolt=u.get_default_object(u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'));cook=jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    try:
        settings.set_editor_property('bAutoSaveEnable',False);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',u.Ck_EnableDisable.DISABLE)
        assert settings.get_editor_property('bAutoSaveEnable') is False and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==u.Ck_EnableDisable.DISABLE
        u.EditorAssetLibrary.set_metadata_tag(asset,'Owner','Mars.WarrensVariantC.Larder.RetainedArt.R01')
        assert u.EditorAssetLibrary.save_loaded_asset(asset,False)
        assert reader.readback(asset,source,node_map)==proof
        creator.guard();assert helper.dirty()==dict(maps=[],content=[])
        receipt=dict(status='REVIEWED_LARDER_MASTER_PRIVATE_SAVED_NOT_BOUND',role='Props',target=target,package_sha256=sha(creator.disk(target)),tool_sha256=sha(__file__),gate_sha256=sha(DOC/'NATIVE_PENDING_PROPS_MASTER_GATE_R01.json'),build=proof,boundary='Existing pending reviewed graph saved only. Custom input ownership references map to identical copied nodes; HLSL, parameters, masks/indices, links and nine flags exact. No Factory or graph rebuild retry, binding or source/library save.')
        (DOC/'retained_master_props_r01.json').write_text(json.dumps(receipt,indent=2)+'\n')
        creator.STATE['Props']['stage']='SAVED_NOT_BOUND';creator.guard();print('EXISTING_PROPS_MASTER_SAVED',receipt['package_sha256'])
    finally:
        settings.set_editor_property('bAutoSaveEnable',autosave);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',cook)
        assert settings.get_editor_property('bAutoSaveEnable')==autosave and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==cook
