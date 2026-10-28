"""Save-only pending-asset recovery and finite owned-Sack mesh comparison."""
import copy,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/sack-winding-r01'
TARGET='/Game/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01/Meshes/WVC_Larder_OutwardClothSack_R01_SM'
STATE=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def disk(p):return ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset')
def seven_guard(controller):
    assert sha(controller.__file__)=='575b8b7e11305c89549b96c54148e6d3bc879b4c4b13921252f2c4e2b151cfff'
    assert sha(Path(controller.__file__).with_name('larder_surface_pie_trial_r04.py'))=='c4f40842a3ab4ed93ce93e51b6c6b3b6c1c426c08b0aa3ebb2a0376b35f1da9e'
    controller.load('larder_surface_pie_trial_r04').guard()
    folder=ROOT/'Saved/WarrensCGameplay-20261024/LarderRollout'
    for name,count in [('closed_jar_mesh_asset_r01.json',1),('corrective_assets_r01.json',2)]:
        rows=json.loads((folder/name).read_text())['assets'];assert len(rows)==count
        for p,r in rows.items():assert sha(disk(p))==r['package_sha256']
def dump(mesh):
    import unreal as u
    out={}
    for label,kind in [('source',u.GeometryScriptLODType.SOURCE_MODEL),('render',u.GeometryScriptLODType.RENDER_DATA)]:
        dm=u.DynamicMesh();lod=u.GeometryScriptMeshReadLOD();lod.lod_type=kind;lod.lod_index=0;res=u.GeometryScript_AssetUtils.copy_mesh_from_static_mesh(mesh,dm,u.GeometryScriptCopyMeshFromAssetOptions(),lod);assert res[1]==u.GeometryScriptOutcomePins.SUCCESS and dm.get_triangle_count()==320;rows=[]
        for i in range(320):
            p=u.GeometryScript_MeshQueries.get_triangle_positions(dm,i);uv=u.GeometryScript_MeshQueries.get_triangle_u_vs(dm,0,i);ns=u.GeometryScript_MeshQueries.get_triangle_normals(dm,i);mat,valid=u.GeometryScript_Materials.get_triangle_material_id(dm,i);assert p[0] and uv[3] and ns[4] and valid
            rows.append(dict(material=mat,positions=[list(v.to_tuple()) for v in p[1:]],uv=[list(v.to_tuple()) for v in uv[:3]],normals=[list(v.to_tuple()) for v in ns[1:4]]))
        out[label]=rows
    return out
def _save_pending_inner(importer,controller):
    import unreal as u
    assert Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve();ed=u.get_editor_subsystem(u.UnrealEditorSubsystem)
    assert ed.get_game_world() is None and ed.get_editor_world().get_path_name()=='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    assert sha(importer.__file__)=='4eb622e12a5b18e90f5ee2026f4f317a953e5928d8a32df8b0d9f338d115b6de'
    assert importer.STATE['status']=='PENDING_VALIDATION_NO_FACTORY_RETRY' and not disk(TARGET).exists() and not (DOC/'native_asset.json').exists()
    asset=importer.STATE['asset'];assert asset.get_path_name().split('.')[0]==TARGET
    seven_guard(controller);assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages() and [p.get_path_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()]==[TARGET]
    audit=DOC/'native_finite_correspondence.json';assert sha(audit)=='5234075c9eb718effbb5cba6df21e23e35e86abecd5c058930162505927c9071'
    proof=json.loads(audit.read_text());native=DOC/'native_pending_geometry.json';assert sha(native)==proof['native_dump_sha256'];expected=json.loads(native.read_text());original=u.load_asset(importer.ORIGINAL)
    assert dict(old=dump(original),new=dump(asset))==expected
    slots=list(asset.static_materials);assert [str(s.get_editor_property('imported_material_slot_name')) for s in slots]==['WarrensC_LinenCanvas_Mars_MI','WarrensC_RopeFibre_Mars_MI']
    assert [s.get_editor_property('material_interface').get_path_name().split('.')[0] for s in slots]==['/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_'+n for n in ['TX12','TX14']]
    filenames=asset.get_editor_property('asset_import_data').extract_filenames();assert len(filenames)==1 and Path(filenames[0]).resolve()==(DOC/'WVC_Larder_OutwardClothSack_R01_SM.fbx').resolve()
    assert sha(Path(filenames[0]))=='2dd7480f4616fdeb86cec034c2d5f322d00edfb9ad0892f0c9530a1742985905'
    sub=u.get_editor_subsystem(u.StaticMeshEditorSubsystem);assert sub.get_num_uv_channels(asset,0)==1 and sub.get_simple_collision_count(asset)==sub.get_convex_collision_count(asset)==0
    assert not asset.get_editor_property('nanite_settings').get_editor_property('enabled') and not asset.get_editor_property('asset_import_data').get_editor_property('remove_degenerates') and not sub.get_lod_build_settings(asset,0).get_editor_property('remove_degenerates')
    u.EditorAssetLibrary.set_metadata_tag(asset,'Owner','Mars.WarrensVariantC.Larder.WindingOnly.R01');assert u.EditorAssetLibrary.save_loaded_asset(asset,False)
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages() and not u.EditorLoadingAndSavingUtils.get_dirty_content_packages();seven_guard(controller)
    assert dict(old=dump(original),new=dump(asset))==expected
    receipt=dict(status='SAVED_PRIVATE_WINDING_SUCCESSOR_FINITE_NATIVE_IMPORT_CORRESPONDENCE_NOT_APPEARANCE_ACCEPTANCE',target=TARGET,package_sha256=sha(disk(TARGET)),audit_sha256=sha(audit),tool_sha256=sha(__file__),source_render=dict(triangles=320,reversed_cloth=128,ties=192,UV_materials_Z_exact=True,maximum_XY_delta_cm=[1.9073486328125e-6,2.1457672119140625e-6],maximum_source_normal_delta=9.340306487211477e-7,maximum_render_normal_delta=0.),boundary='Save-only recovery of same pending asset, no factory retry/reimport, no original package or library binding. Exact native XY equality is not claimed.')
    (DOC/'native_asset.json').write_text(json.dumps(receipt,indent=2)+'\n');importer.STATE=dict(asset=asset,status='SAVED_NOT_BOUND',proof=receipt);print('OUTWARD_SACK_PENDING_SAVED',receipt['package_sha256'])
def save_pending(importer,controller):
    import unreal as u
    assert importer.STATE['status']=='PENDING_VALIDATION_NO_FACTORY_RETRY'
    attempt=DOC/'native_save_pending_attempt.json';assert not attempt.exists()
    settings=u.get_default_object(u.load_class(None,'/Script/UnrealEd.EditorLoadingSavingSettings'));autosave=settings.get_editor_property('bAutoSaveEnable');jolt=u.get_default_object(u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'));cook=jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    attempt.write_text(json.dumps(dict(status='ONE_SAVE_ONLY_PENDING_ASSET_ATTEMPT_NO_FACTORY_OR_AUTOMATIC_RETRY',tool_sha256=sha(__file__),target=TARGET,autosave=autosave,cook=str(cook)),indent=2)+'\n')
    try:
        settings.set_editor_property('bAutoSaveEnable',False);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',u.Ck_EnableDisable.DISABLE)
        assert settings.get_editor_property('bAutoSaveEnable') is False and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==u.Ck_EnableDisable.DISABLE
        _save_pending_inner(importer,controller)
    finally:
        settings.set_editor_property('bAutoSaveEnable',autosave);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',cook)
        assert settings.get_editor_property('bAutoSaveEnable')==autosave and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==cook
def signature(extension):
    t=extension.STATE
    return {k:t[k] for k in ['stable','successor_on','repeat','new_normal','s3_on']}
def s3_signature(extension,controller):
    r=extension.read_s3(controller);return {k:r[k] for k in ['role','contract','records']}
def begin(controller,extension):
    import unreal as u
    global STATE
    assert STATE is None;extension.check();s=controller.STATE;assert not extension.STATE['stable'] and not extension.STATE['successor_on'] and not extension.STATE['s3_on']
    asset=u.load_asset(TARGET);proof=json.loads((DOC/'native_asset.json').read_text());assert sha(disk(TARGET))==proof['package_sha256']
    a=s['props']['sack']['actor'];c=a.static_mesh_component;assert c.static_mesh==s['props']['sack']['original'] and c.get_material(0)==s['paint_mids']['sack']
    STATE=dict(controller=controller,extension=extension,actor=a,component=c,old=c.static_mesh,new=asset,proof=proof,original=copy.deepcopy(controller.owned(a)),index=s['created'].index(a),candidate=False,signature=signature(extension),s3=s3_signature(extension,controller));check()
def check():
    import unreal as u
    t=STATE;assert t;controller=t['controller'];controller.check();assert u.GameplayStatics.is_game_paused(controller.STATE['world'])
    assert sha(disk(TARGET))==t['proof']['package_sha256'] and signature(t['extension'])==t['signature'] and s3_signature(t['extension'],controller)==t['s3']
    expected=copy.deepcopy(t['original']);expected['mesh']=(t['new'] if t['candidate'] else t['old']).get_path_name();assert controller.owned(t['actor'])==expected and controller.STATE['owned_expected'][t['index']]==expected
def bind(candidate):
    import unreal as u
    assert isinstance(candidate,bool);t=STATE;u.GameplayStatics.set_game_paused(t['controller'].STATE['world'],True);check();s=t['controller'].STATE;before=t['controller'].owned(t['actor']);mesh=t['new'] if candidate else t['old'];assert t['component'].set_static_mesh(mesh)
    expected=dict(before,mesh=mesh.get_path_name());assert t['controller'].owned(t['actor'])==expected;s['owned_expected'][t['index']]=expected;t['candidate']=candidate;check()
def capture(label):
    import unreal as u
    t=STATE;u.GameplayStatics.set_game_paused(t['controller'].STATE['world'],True);check();t['controller'].capture(label);p=t['controller'].STATE['capture'].STATE['out']/(label+'.json');r=json.loads(p.read_text());r['sack_winding_trial']=dict(candidate=t['candidate'],asset=t['proof']['target'],asset_sha256=t['proof']['package_sha256'],correction_signature=t['signature']);p.write_text(json.dumps(r,indent=2)+'\n')
def restore():
    global STATE
    bind(False);t=STATE;assert t['controller'].owned(t['actor'])==t['original'];extension=t['extension'];STATE=None;extension.check();print('OUTWARD_SACK_TRIAL_EXACT_ORIGINAL_RESTORED_REFERENCES_RELEASED')
def abort(controller,extension):
    global STATE
    try:extension.abort(controller)
    finally:STATE=None
