"""Finish validation and save only the existing imported Hall wall candidate."""
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(name):
    p=Path(__file__).with_name(name+'.py');s=importlib.util.spec_from_file_location('_hall_mesh_recovery_'+name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m


def run(creator,asset):
    import unreal as u
    assert Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve()
    gate=json.loads((DOC/'NATIVE_PENDING_HALL_WALL_SAVE_GATE_R01.json').read_text())
    assert gate['status']=='APPROVED_EXISTING_HALL_WALL_MESH_VALIDATION_AND_SAVE_ONLY' and gate['tool_sha256']==sha(__file__)
    for p,h in gate['input_sha256'].items():assert sha(ROOT/p)==h
    successor=json.loads((DOC/'NATIVE_FOUR_ROOM_ASSETS_GATE_R03.json').read_text())
    config,=[r for r in successor['surfaces'] if r['room']=='hall' and r['family']=='walls'];target=config['mesh_target']
    assert creator.STATE[('mesh','hall','walls')]['asset']==asset and asset.get_path_name().split('.')[0]==target
    assert not creator.disk(target).exists() and not creator.ledger_path('mesh','hall','walls').exists()
    helper=creator.load('room_tint_owned_assets_r01');creator.guard();assert helper.dirty()==dict(maps=[],content=[target])
    ed=u.get_editor_subsystem(u.UnrealEditorSubsystem);assert ed.get_game_world() is None and ed.get_editor_world().get_path_name()=='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    validator=load('validate_room_native_mesh_r02');details=validator.validate(asset,config)
    assert details['source_render_counts']==dict(source=37416,render=37416) and details['exact_zero_area_FBX_faces']==4158 and details['maximum_corner_displacement_cm']==0
    attempt=DOC/'existing_hall_wall_mesh_save_attempt_r01.json';assert not attempt.exists();attempt.write_text(json.dumps(dict(target=target,details=details,tool_sha256=sha(__file__)),indent=2)+'\n')
    settings=u.get_default_object(u.load_class(None,'/Script/UnrealEd.EditorLoadingSavingSettings'));autosave=settings.get_editor_property('bAutoSaveEnable')
    jolt=u.get_default_object(u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'));cook=jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    try:
        settings.set_editor_property('bAutoSaveEnable',False);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',u.Ck_EnableDisable.DISABLE)
        assert settings.get_editor_property('bAutoSaveEnable') is False and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==u.Ck_EnableDisable.DISABLE
        creator.guard();assert helper.dirty()==dict(maps=[],content=[target])
        u.EditorAssetLibrary.set_metadata_tag(asset,'Owner','Mars.WarrensVariantC.RoomRollout.R01')
        assert u.EditorAssetLibrary.save_loaded_asset(asset,False)
        assert validator.validate(asset,config)==details
        creator.guard();assert helper.dirty()==dict(maps=[],content=[])
        receipt=dict(status='PRIVATE_ROOM_MESH_SAVED_NOT_BOUND_OR_NATIVE_ART_ACCEPTED',room='hall',family='walls',target=target,package_sha256=sha(creator.disk(target)),tool_sha256=sha(__file__),gate_sha256=sha(DOC/'NATIVE_PENDING_HALL_WALL_SAVE_GATE_R01.json'),config=config,details=details,boundary='Save existing imported candidate only, no Factory retry or geometry repair. Every positive-area source face matches native exactly; 4158 omitted FBX faces have mathematically exact-zero area and are explicitly listed in full proof. Colour/UV/normal/bounds/slots checked, not native room art acceptance or normal-field parity.')
        creator.ledger_path('mesh','hall','walls').write_text(json.dumps(receipt,indent=2)+'\n')
        creator.STATE[('mesh','hall','walls')]['stage']='SAVED_NOT_BOUND'
        creator.guard();print('PENDING_HALL_WALL_MESH_SAVED',receipt['package_sha256'])
    finally:
        settings.set_editor_property('bAutoSaveEnable',autosave);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',cook)
        assert settings.get_editor_property('bAutoSaveEnable')==autosave and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==cook
