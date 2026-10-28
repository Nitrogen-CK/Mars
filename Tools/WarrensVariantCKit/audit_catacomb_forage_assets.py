"""Read back the completed owned assets and combine the36-asset trial inventory."""
import hashlib,json,importlib.util
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-forage-props-r04'
OLD='/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02';DEST=OLD+'/Forage_R04'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def audit(creator):
    import unreal as u
    assert Path(u.Paths.project_dir()).resolve()==ROOT.resolve() and u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    creator.guard();created=read(RUN/'forage_assets_r04.json');assert created['status']=='TEN_OWNED_FORAGE_ASSETS_IMPORTED_PENDING_SHADER_QUERY' and len(created['assets'])==10
    old=read(RUN/'candidate_assets_r09.json');assets=old['assets']|created['assets'];assert len(assets)==36
    assert all(sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset'))==r['package_sha256'] for p,r in assets.items())
    retained=read(RUN/'forage_assets_r04_partial2.json');assert all(assets[p]==r for p,r in retained['assets'].items())
    shader=read(RUN/'forage_shader_validation_r04.json');assert shader['status']=='FOUR_OWNED_FORAGE_MATERIALS_COMPILED' and all(r['query']['is_compiled'] for r in shader['materials'].values())
    spec=importlib.util.spec_from_file_location('_cp_forage_graph_snapshot',ROOT/'Tools/WarrensVariantCKit/catacomb_plane_normal_materials.py');snap=importlib.util.module_from_spec(spec);spec.loader.exec_module(snap)
    graphs={}
    for role in shader['materials']:
        mat=u.load_asset(DEST+'/Materials/M_CP_Forage'+role+'_R01');graphs[role]=snap.snapshot(mat)
        assert all(u.MaterialEditingLibrary.get_material_property_input_node(mat,p) for p in (u.MaterialProperty.MP_BASE_COLOR,u.MaterialProperty.MP_ROUGHNESS,u.MaterialProperty.MP_METALLIC))
        if role in ('Bronze','Fruit'):
            mask=u.MaterialEditingLibrary.get_material_property_input_node(mat,u.MaterialProperty.MP_BASE_COLOR);assert isinstance(mask,u.MaterialExpressionComponentMask)
            vertex,=u.MaterialEditingLibrary.get_inputs_for_material_expression(mat,mask);assert isinstance(vertex,u.MaterialExpressionVertexColor)
            assert all(mask.get_editor_property(c) for c in ('r','g','b')) and not mask.get_editor_property('a')
        if role=='Fruit':assert mat.get_editor_property('two_sided') is True
    source_colors=read(DOC/'SOURCE_VERTEX_RANGES.json');ranges={}
    for p,r in created['assets'].items():
        if '/Meshes/' not in p:continue
        name=p.rsplit('/',1)[1];expected=source_colors[name];actual=r['details']['render_vertex_colors']
        error=max(abs(actual[k]-expected[k]) for k in ('min','max'));assert error<=1/255+1e-6,(name,error)
        ranges[name]=dict(authored=expected,actual_render=actual,range_error=error,boundary='Linear range preservation within8bit quantization; not full palette/pixel/appearance acceptance.')
    profile=u.load_asset(DEST+'/DA_CP_ForagePresentation_R01');censer=profile.get_editor_property('censer');vine=profile.get_editor_property('vine')
    def ref(struct,key,path):
        obj=struct.get_editor_property(key);assert obj and obj.get_path_name().split('.')[0]==path;return obj.get_path_name()
    refs={}
    for field,name in [('bob_mesh','WVC_Forage_CenserBob_R01_SM'),('chain_mesh','WVC_Forage_Chain_R01_SM'),('contents_mesh','WVC_Forage_PepperContents_R01_SM')]:refs[field]=ref(censer,field,DEST+'/Meshes/'+name)
    for field,name in [('fig_mesh','WVC_Forage_Fig_R01_SM'),('bellnut_mesh','WVC_Forage_Bellnut_R01_SM')]:refs[field]=ref(vine,field,DEST+'/Meshes/'+name)
    for field,path in [('stone_material',OLD+'/PBR_R09/Materials/M_CP_Prop_PBR_R09'),('timber_post_material',DEST+'/Materials/M_CP_ForageTimberPost_R01'),('timber_arm_material',DEST+'/Materials/M_CP_ForageTimberArm_R01')]:refs[field]=ref(profile,field,path)
    assert censer.get_editor_property('ceiling_height_cm')==460 and vine.get_editor_property('connector_length_cm')==12 and vine.get_editor_property('connector_width_cm')==2.5
    creator.guard();assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    result=dict(status='OWNED_FORAGE_ASSETS_AND_SHADERS_READ_BACK',creation_receipt_sha256=sha(RUN/'forage_assets_r04.json'),shader_receipt_sha256=sha(RUN/'forage_shader_validation_r04.json'),profile=refs,dimensions=dict(ceiling_height_cm=460,connector_length_cm=12,connector_width_cm=2.5),graphs=graphs,source_and_render_color_ranges=ranges,retained_two_packages_exact=True,guards=651,boundary='Owned assets only. No room assignment/map/library save. Native appearance and gameplay interaction checks remain pending.')
    out=RUN/'forage_assets_validated_r04.json';assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n')
    inventory=dict(old,status='THIRTYSIX_OWNED_NATIVE_PILOT_ASSETS_CREATED_AND_READ_BACK',assets=assets,forage_validation_sha256=sha(out),source_guard_receipt='baseline_guard_after_forage_tests_r01.json',source_guard_sha256=sha(RUN/'baseline_guard_after_forage_tests_r01.json'))
    path=RUN/'candidate_assets_forage_r04.json';assert not path.exists();path.write_text(json.dumps(inventory,indent=2)+'\n');print('FORAGE_ASSETS_VALIDATED',sha(out),'CANDIDATE_36',sha(path))
