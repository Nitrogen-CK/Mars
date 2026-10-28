"""Four new private instances reproducing the reviewed prop and brine settings."""
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
DEST='/Game/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01/Persist_R01/Materials'
STATE={}


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def load(name):
    p=Path(__file__).with_name(name+'.py');s=importlib.util.spec_from_file_location('_retained_instance_'+name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m


def specs():
    paint=load('larder_room_finish_trial_r02').PAINT
    rows={role:dict(parent=DEST+'/M_WVC_Larder_Props_R01',scalars=dict(WorldTileCm=80.,NormalStrength=.15,RoughnessBlend=.2,PigmentMix=values['mix']),vectors=dict(BaseColour=list(values['base']),PigmentTint=list(values['tint'])),textures={}) for role,values in paint.items()}
    rows['brine']=dict(parent=DEST+'/M_WVC_Larder_Brine_R01',scalars=dict(BrineRoughness=.45,NormalURepeat=4.,NormalVRepeat=3.5),vectors=dict(BrineColour=[.025,.075,.055,1.]),textures=dict(WaterNormal='/Game/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01/PBR_R02/Textures/T_Larder_BrineWave_NormalDX_R01'))
    return rows


def guard():
    load('larder_retention_material_assets_r02').guard()
    for role in ('barrel','sack','jar','brine'):
        p=DOC/('retained_instance_'+role+'_r01.json')
        if p.exists():
            row=json.loads(p.read_text());assert sha(ROOT/('Content/'+row['target'].removeprefix('/Game/')+'.uasset'))==row['package_sha256']


def readback(asset,config):
    import unreal as u
    mel=u.MaterialEditingLibrary
    assert asset.get_editor_property('parent').get_path_name().split('.')[0]==config['parent']
    scalars={key:mel.get_material_instance_scalar_parameter_value(asset,key) for key in config['scalars']}
    vectors={key:list(mel.get_material_instance_vector_parameter_value(asset,key).to_tuple()) for key in config['vectors']}
    textures={key:mel.get_material_instance_texture_parameter_value(asset,key).get_path_name().split('.')[0] for key in config['textures']}
    assert all(abs(scalars[k]-v)<1e-6 for k,v in config['scalars'].items())
    assert all(max(abs(a-b) for a,b in zip(vectors[k],v))<1e-6 for k,v in config['vectors'].items())
    assert textures==config['textures']
    assert len(asset.get_editor_property('scalar_parameter_values'))==len(scalars) and len(asset.get_editor_property('vector_parameter_values'))==len(vectors) and len(asset.get_editor_property('texture_parameter_values'))==len(textures)
    return dict(parent=config['parent'],scalars=scalars,vectors=vectors,textures=textures)


def create(role):
    import unreal as u
    assert role in specs() and role not in STATE
    assert Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve()
    gate=json.loads((DOC/'NATIVE_RETAINED_INSTANCES_GATE_R01.json').read_text())
    assert gate['status']=='APPROVED_FOUR_ABSENT_PRIVATE_REVIEWED_INSTANCES_ONLY' and gate['tool_sha256']==sha(__file__)
    for path,digest in gate['input_sha256'].items():assert sha(ROOT/path)==digest
    config=specs()[role];assert config==gate['specs'][role]
    target=DEST+'/MI_WVC_Larder_'+role.title()+'_R01';disk=ROOT/('Content/'+target.removeprefix('/Game/')+'.uasset')
    assert target==gate['targets'][role] and not disk.exists() and not u.EditorAssetLibrary.does_asset_exist(target)
    guard();helper=load('room_tint_owned_assets_r01');assert helper.dirty()==dict(maps=[],content=[])
    ed=u.get_editor_subsystem(u.UnrealEditorSubsystem);assert ed.get_game_world() is None and ed.get_editor_world().get_path_name()=='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    attempt=DOC/('retained_instance_'+role+'_attempt_r01.json');assert not attempt.exists();attempt.write_text(json.dumps(dict(target=target,config=config,tool_sha256=sha(__file__)),indent=2)+'\n')
    settings=u.get_default_object(u.load_class(None,'/Script/UnrealEd.EditorLoadingSavingSettings'));autosave=settings.get_editor_property('bAutoSaveEnable')
    jolt=u.get_default_object(u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'));cook=jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    try:
        settings.set_editor_property('bAutoSaveEnable',False);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',u.Ck_EnableDisable.DISABLE)
        assert settings.get_editor_property('bAutoSaveEnable') is False and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==u.Ck_EnableDisable.DISABLE
        asset=u.AssetToolsHelpers.get_asset_tools().create_asset(target.rsplit('/',1)[1],DEST,u.MaterialInstanceConstant,u.MaterialInstanceConstantFactoryNew());assert asset
        STATE[role]=dict(stage='PENDING_NO_FACTORY_RETRY',asset=asset)
        mel=u.MaterialEditingLibrary;mel.set_material_instance_parent(asset,u.load_asset(config['parent']))
        for key,value in config['scalars'].items():mel.set_material_instance_scalar_parameter_value(asset,key,value)
        for key,value in config['vectors'].items():mel.set_material_instance_vector_parameter_value(asset,key,u.LinearColor(*value))
        for key,value in config['textures'].items():mel.set_material_instance_texture_parameter_value(asset,key,u.load_asset(value))
        actual=readback(asset,config);guard();assert helper.dirty()==dict(maps=[],content=[target])
        u.EditorAssetLibrary.set_metadata_tag(asset,'Owner','Mars.WarrensVariantC.Larder.RetainedArt.R01')
        assert u.EditorAssetLibrary.save_loaded_asset(asset,False) and readback(asset,config)==actual
        assert helper.dirty()==dict(maps=[],content=[]);guard()
        receipt=dict(status='REVIEWED_PROP_OR_BRINE_INSTANCE_PRIVATE_SAVED_NOT_BOUND',role=role,target=target,package_sha256=sha(disk),config=config,readback=actual,tool_sha256=sha(__file__),boundary='New private instance reproduces accepted R16 values and independent brine normal. Setter return values are not success evidence; exact parent/values/override counts verified before and after save. No source or library bindings.')
        (DOC/('retained_instance_'+role+'_r01.json')).write_text(json.dumps(receipt,indent=2)+'\n')
        STATE[role]['stage']='SAVED_NOT_BOUND';guard();print('RETAINED_INSTANCE_SAVED',role,receipt['package_sha256'])
    finally:
        settings.set_editor_property('bAutoSaveEnable',autosave);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',cook)
        assert settings.get_editor_property('bAutoSaveEnable')==autosave and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==cook
