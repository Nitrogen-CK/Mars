"""Persist five reviewed Larder masters as new private, unbound graph copies."""
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
DEST='/Game/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01/Persist_R01/Materials'
STATE={}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(name):
    path=Path(__file__).with_name(name+'.py');spec=importlib.util.spec_from_file_location('_larder_retained_'+name,path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result


def disk(path):
    return ROOT/('Content/'+path.removeprefix('/Game/')+'.uasset')


def guard():
    load('four_room_owned_assets_r02').guard()
    for role in ('props','brine','s3','rawshell','fitted'):
        path=DOC/('retained_master_'+role+'_r01.json')
        if path.exists():
            row=json.loads(path.read_text());assert sha(disk(row['target']))==row['package_sha256']


def create(role,source):
    import unreal as u
    assert role in ('Props','Brine','S3','RawShell','Fitted') and role not in STATE
    assert Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve()
    gate=json.loads((DOC/'NATIVE_RETENTION_MASTERS_GATE_R01.json').read_text())
    assert gate['status']=='APPROVED_FIVE_ABSENT_PRIVATE_RETAINED_MASTERS_ONLY' and gate['tool_sha256']==sha(__file__)
    for path,digest in gate['input_sha256'].items():assert sha(ROOT/path)==digest
    proof=json.loads((DOC/'fitted-context-family-r01/retention_source_materials_r01.json').read_text())[role]
    values=load('material_graph_values_r02');links=load('material_graph_links_r01');snapshot=load('catacomb_plane_normal_materials')
    assert source.get_path_name()==proof['material'] and source.get_outer().get_path_name()=='/Engine/Transient'
    assert values.read(source)==proof['explicit_values'] and links.read(source)==proof['links'] and snapshot.snapshot(source)==proof['graph']
    property_names=load('room_tint_master_build_r01').PROPERTIES
    assert {k:snapshot.serial(source.get_editor_property(k)) for k in property_names}==proof['explicit_material_properties']
    target=DEST+'/M_WVC_Larder_'+role+'_R01'
    assert target==gate['targets'][role] and not u.EditorAssetLibrary.does_asset_exist(target) and not disk(target).exists()
    guard();helper=load('room_tint_owned_assets_r01');assert helper.dirty()==dict(maps=[],content=[])
    ed=u.get_editor_subsystem(u.UnrealEditorSubsystem);assert ed.get_game_world() is None and ed.get_editor_world().get_path_name()=='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    attempt=DOC/('retained_master_'+role.lower()+'_attempt_r01.json');assert not attempt.exists()
    settings=u.get_default_object(u.load_class(None,'/Script/UnrealEd.EditorLoadingSavingSettings'));autosave=settings.get_editor_property('bAutoSaveEnable')
    jolt=u.get_default_object(u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'));cook=jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    attempt.write_text(json.dumps(dict(status='ONE_ABSENT_PRIVATE_MASTER_NO_FACTORY_RETRY',target=target,source=source.get_path_name(),tool_sha256=sha(__file__)),indent=2)+'\n')
    try:
        settings.set_editor_property('bAutoSaveEnable',False);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',u.Ck_EnableDisable.DISABLE)
        assert settings.get_editor_property('bAutoSaveEnable') is False and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==u.Ck_EnableDisable.DISABLE
        asset=u.AssetToolsHelpers.get_asset_tools().create_asset(target.rsplit('/',1)[1],DEST,u.Material,u.MaterialFactoryNew());assert asset
        STATE[role]=dict(stage='PENDING_NO_FACTORY_RETRY',asset=asset,target=target)
        build=load('clone_reviewed_material_graph_r01').build(asset,source)
        assert build['compile_statistics']==proof['compile_statistics']
        assert build['explicit_material_properties']==proof['explicit_material_properties']
        guard();assert helper.dirty()==dict(maps=[],content=[target])
        u.EditorAssetLibrary.set_metadata_tag(asset,'Owner','Mars.WarrensVariantC.Larder.RetainedArt.R01')
        assert u.EditorAssetLibrary.save_loaded_asset(asset,False)
        assert snapshot.snapshot(asset)==build['graph'] and values.read(asset)==build['explicit_values'] and links.read(asset)==build['links']
        assert {k:snapshot.serial(asset.get_editor_property(k)) for k in property_names}==proof['explicit_material_properties']
        assert values.read(source)==proof['explicit_values'] and links.read(source)==proof['links'] and snapshot.snapshot(source)==proof['graph']
        assert helper.dirty()==dict(maps=[],content=[]);guard()
        receipt=dict(status='REVIEWED_LARDER_MASTER_PRIVATE_SAVED_NOT_BOUND',role=role,target=target,package_sha256=sha(disk(target)),tool_sha256=sha(__file__),gate_sha256=sha(DOC/'NATIVE_RETENTION_MASTERS_GATE_R01.json'),build=build,boundary='New private exact reviewed graph copy only. No source/library/package binding; actual persisted-room comparison remains required.')
        (DOC/('retained_master_'+role.lower()+'_r01.json')).write_text(json.dumps(receipt,indent=2)+'\n')
        STATE[role]['stage']='SAVED_NOT_BOUND';guard();print('RETAINED_LARDER_MASTER_SAVED',role,receipt['package_sha256'])
    finally:
        settings.set_editor_property('bAutoSaveEnable',autosave);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',cook)
        assert settings.get_editor_property('bAutoSaveEnable')==autosave and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==cook
