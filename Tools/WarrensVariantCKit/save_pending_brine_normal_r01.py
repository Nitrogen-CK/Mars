"""Save-only recovery of the existing owned pending normal; never imports/retries."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
RUN=ROOT/'Saved/WarrensCGameplay-20261024/LarderRollout'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def run(importer,texture):
    import unreal as u
    gate=json.loads((DOC/'NATIVE_PENDING_NORMAL_SAVE_GATE_R01.json').read_text());assert gate['status']=='APPROVED_PENDING_NORMAL_SAVE_ONLY_NO_REIMPORT' and gate['tool_sha256']==sha(__file__) and gate['importer_sha256']==sha(importer.__file__)
    for path,digest in gate['input_sha256'].items():assert sha(ROOT/path)==digest
    assert Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve();editor=u.get_editor_subsystem(u.UnrealEditorSubsystem);assert editor.get_game_world() is None and editor.get_editor_world().get_path_name()=='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    target=importer.TARGETS['normal'];assert isinstance(texture,u.Texture2D) and texture==u.load_asset(target) and texture.get_path_name()==target+'.'+target.rsplit('/',1)[1] and not importer.disk(target).exists()
    ledger=RUN/'corrective_assets_r01.json';backup=RUN/'corrective_assets_after_sack_r01.json';assert ledger.read_bytes()==backup.read_bytes();before=json.loads(ledger.read_text());assert len(before['assets'])==len(importer.STATE['assets'])==1 and before['assets']==importer.STATE['assets']
    assert importer.dirty()==dict(maps=[],content=[target]);importer.guard()
    wave=json.loads((DOC/'brine-wave-normal-r01/receipt.json').read_text());source=ROOT/wave['maps']['DX']['file'];assert sha(source)==wave['maps']['DX']['sha256'];assert list(texture.get_editor_property('asset_import_data').extract_filenames())==[str(source).replace('\\','/')]
    expected=dict(srgb=False,compression_settings=u.TextureCompressionSettings.TC_NORMALMAP,address_x=u.TextureAddress.TA_WRAP,address_y=u.TextureAddress.TA_WRAP,flip_green_channel=False,max_texture_size=0,lod_bias=0)
    def verify():
        assert all(texture.get_editor_property(k)==v for k,v in expected.items()) and texture.blueprint_get_size_x()==texture.blueprint_get_size_y()==1024
        filenames=texture.get_editor_property('asset_import_data').extract_filenames();assert len(filenames)==1 and Path(filenames[0]).resolve()==source.resolve()
    verify();attempt=RUN/'pending_normal_save_attempt_r01.json';assert not attempt.exists()
    settings=u.get_default_object(u.load_class(None,'/Script/UnrealEd.EditorLoadingSavingSettings'));autosave=settings.get_editor_property('bAutoSaveEnable');jolt=u.get_default_object(u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'));cook=jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    attempt.write_text(json.dumps(dict(status='SAVE_EXISTING_PENDING_OWNED_NORMAL_ONCE_NO_REIMPORT',target=target,tool_sha256=sha(__file__),importer_sha256=sha(importer.__file__),saved_sack_ledger_sha256=sha(backup),source_sha256=sha(source),original_failed_size='UNRECORDED',compilation_cause='INFERRED from failed immediate check/later1024reads and engine placeholder contract, not reproduced initial sample',original_autosave=autosave,original_cook=str(cook)),indent=2)+'\n')
    try:
        settings.set_editor_property('bAutoSaveEnable',False);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',u.Ck_EnableDisable.DISABLE);assert settings.get_editor_property('bAutoSaveEnable') is False and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==u.Ck_EnableDisable.DISABLE
        # UTexture::Modify(false) calls BlockOnAnyAsyncBuild, which finishes
        # this texture's cache/compilation and checks !IsDefaultTexture.
        # See UE Texture.cpp:536-568. No texture property is rewritten.
        texture.modify(False);verify();importer.guard();assert importer.dirty()==dict(maps=[],content=[target]) and not importer.disk(target).exists() and ledger.read_bytes()==backup.read_bytes()
        u.EditorAssetLibrary.set_metadata_tag(texture,'Owner','Mars.WarrensVariantC.Larder.CorrectiveAssets.R01');assert u.EditorAssetLibrary.save_loaded_asset(texture,False);assert importer.disk(target).is_file();verify()
        proof=dict(source_sha256=sha(source),source_file=source.relative_to(ROOT).as_posix(),size=[1024,1024],srgb=False,compression=str(texture.get_editor_property('compression_settings')),wrap=[str(texture.get_editor_property('address_x')),str(texture.get_editor_property('address_y'))],flip_green=False,convention='Geometry-baked DirectX normal, no additional green flip',package_sha256=sha(importer.disk(target)),recovery_tool_sha256=sha(__file__),compilation_boundary='UTexture.Modify(false) synchronizes native asynchronous build before fresh readbacks/save; initial bad size unrecorded, cause remains inferred')
        importer.STATE['assets'][target]=proof;after=dict(status='TWO_PRIVATE_CORRECTIVE_ASSETS_SAVED_NOT_BOUND_OR_ROOM_ACCEPTED',tool_sha256=sha(importer.__file__),gate_sha256=sha(DOC/'NATIVE_CORRECTIVE_ASSETS_GATE_R01.json'),recovery_tool_sha256=sha(__file__),recovery_gate_sha256=sha(DOC/'NATIVE_PENDING_NORMAL_SAVE_GATE_R01.json'),saved_sack_ledger_backup_sha256=sha(backup),assets=importer.STATE['assets'])
        assert {k:v for k,v in after['assets'].items() if k!=target}==before['assets'];ledger.write_text(json.dumps(after,indent=2)+'\n');importer.guard();assert importer.dirty()==dict(maps=[],content=[]);print('PENDING_PRIVATE_NORMAL_SAVED_WITHOUT_REIMPORT',proof['package_sha256'])
    finally:
        settings.set_editor_property('bAutoSaveEnable',autosave);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',cook);assert settings.get_editor_property('bAutoSaveEnable')==autosave and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==cook
