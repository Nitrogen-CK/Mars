"""Save only the existing verified Hall Walls MI; no setters or Factory retry."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run(creator,asset):
    import unreal as u
    assert Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve()
    gate=json.loads((DOC/'NATIVE_PENDING_HALL_PALETTE_GATE_R01.json').read_text())
    assert gate['status']=='APPROVED_SAVE_EXISTING_HALL_WALL_PALETTE_ONLY' and gate['tool_sha256']==sha(__file__)
    for path,digest in gate['input_sha256'].items():assert sha(ROOT/path)==digest
    source=json.loads((DOC/'NATIVE_FOUR_ROOM_ASSETS_GATE_R01.json').read_text())
    config,=[r for r in source['surfaces'] if r['room']=='hall' and r['family']=='walls']
    target=config['palette_target'];parent=u.load_asset(config['master'])
    assert creator.STATE[('palette','hall','walls')]['asset']==asset
    assert asset.get_path_name().split('.')[0]==target and asset.get_editor_property('parent')==parent
    assert not creator.disk(target).exists() and not creator.ledger_path('palette','hall','walls').exists()
    assert max(abs(a-b) for a,b in zip(u.MaterialEditingLibrary.get_material_instance_vector_parameter_value(asset,'RoomTint').to_tuple(),config['tint']+[1.]))<1e-6
    assert len(asset.get_editor_property('vector_parameter_values'))==1 and not asset.get_editor_property('scalar_parameter_values') and not asset.get_editor_property('texture_parameter_values')
    ed=u.get_editor_subsystem(u.UnrealEditorSubsystem)
    assert ed.get_game_world() is None and ed.get_editor_world().get_path_name()=='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    helper=creator.load('room_tint_owned_assets_r01');creator.guard()
    assert helper.dirty()==dict(maps=[],content=[target])
    settings=u.get_default_object(u.load_class(None,'/Script/UnrealEd.EditorLoadingSavingSettings'));autosave=settings.get_editor_property('bAutoSaveEnable')
    jolt=u.get_default_object(u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'));cook=jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    try:
        settings.set_editor_property('bAutoSaveEnable',False);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',u.Ck_EnableDisable.DISABLE)
        assert settings.get_editor_property('bAutoSaveEnable') is False and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==u.Ck_EnableDisable.DISABLE
        u.EditorAssetLibrary.set_metadata_tag(asset,'Owner','Mars.WarrensVariantC.RoomRollout.R01')
        assert u.EditorAssetLibrary.save_loaded_asset(asset,False)
        actual=u.MaterialEditingLibrary.get_material_instance_vector_parameter_value(asset,'RoomTint').to_tuple()
        assert max(abs(a-b) for a,b in zip(actual,config['tint']+[1.]))<1e-6 and asset.get_editor_property('parent')==parent
        assert helper.dirty()==dict(maps=[],content=[]);creator.guard()
        receipt=dict(status='PRIVATE_ROOM_PALETTE_SAVED_NOT_BOUND_OR_NATIVE_ART_ACCEPTED',room='hall',family='walls',target=target,package_sha256=sha(creator.disk(target)),tool_sha256=sha(__file__),gate_sha256=sha(DOC/'NATIVE_PENDING_HALL_PALETTE_GATE_R01.json'),config=config,details=dict(parent=parent.get_path_name(),RoomTint=actual,scalar_overrides=0,texture_overrides=0,vector_overrides=1),boundary='Existing pending MI saved only; no Factory retry or parameter setter. UE MaterialEditingLibrary.cpp1253-1261 applies Vector and UpdateMaterialInstance but always returns local false. Actual parent/value/soleoverride verified before and after save. No source binding or native art acceptance.')
        creator.ledger_path('palette','hall','walls').write_text(json.dumps(receipt,indent=2)+'\n')
        creator.STATE[('palette','hall','walls')]['stage']='SAVED_NOT_BOUND'
        creator.guard();print('PENDING_HALL_WALL_MI_SAVED_NO_FACTORY_RETRY',receipt['package_sha256'])
    finally:
        settings.set_editor_property('bAutoSaveEnable',autosave);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',cook)
        assert settings.get_editor_property('bAutoSaveEnable')==autosave and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==cook
