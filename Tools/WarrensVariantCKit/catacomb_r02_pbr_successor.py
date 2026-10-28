"""Owned successor: closest observed R02 angular albedo plus newly baked PBR maps."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-shape-pbr-r03'
OLD='/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02'
SOURCE=OLD+'/PBR_R08';DEST=OLD+'/PBR_R09';VERSION='R09'
OWNER='Mars.WarrensVariantC.Catacomb.ShapePBR.R09'
SETTINGS={'Walls':dict(normal=.8,rough=.8,mix=.85),'Floor':dict(normal=.3,rough=.75,mix=.70),'Ceiling':dict(normal=.18,rough=.35,mix=.25),'Prop':dict(normal=.6,rough=.65,mix=.45)}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def guard():
    g=read(RUN/'baseline_guard_r02.json');g=g['immutable_guards']|g['collision_hashes'];assert len(g)==651 and all(sha(ROOT/k)==v for k,v in g.items())
    old=read(RUN/'candidate_assets_r08.json');assert len(old['assets'])==21
    assert all(sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset'))==v['package_sha256'] for p,v in old['assets'].items())
    return g,old
def create():
    import unreal as u
    assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    gate=read(DOC/'NATIVE_PBR_TRIAL_GATE_R09.json');assert gate['status']=='SCOPED_SUCCESSOR_OF_APPROVED_PBR_TRIAL' and gate['tool_sha256']==sha(__file__)
    assert gate['comparison_review_sha256']==sha(DOC/'NATIVE_R08_ALBEDO_COMPARISON.md')
    guards,old=guard();mel=u.MaterialEditingLibrary;eal=u.EditorAssetLibrary
    names=[f'M_CP_{f}_PBR_R09' for f in SETTINGS]+['MI_CP_PropLid_PBR_R09']
    assert all(not eal.does_asset_exist(DEST+'/Materials/'+n) for n in names)
    receipt=dict(status='CREATING_FIVE_OWNED_R02_ALBEDO_PBR_SUCCESSORS',assets={},settings=SETTINGS,gate_sha256=sha(DOC/'NATIVE_PBR_TRIAL_GATE_R09.json'))
    def save(asset,details):
        eal.set_metadata_tag(asset,'Owner',OWNER);eal.set_metadata_tag(asset,'State','Complete');eal.set_metadata_tag(asset,'GateSHA256',receipt['gate_sha256'])
        assert eal.save_loaded_asset(asset,False)
        path=asset.get_path_name().split('.')[0];receipt['assets'][path]=dict(package_sha256=sha(ROOT/('Content/'+path.removeprefix('/Game/')+'.uasset')),details=details)
        (RUN/'shape_pbr_assets_r09.json').write_text(json.dumps(receipt,indent=2)+'\n')
    albedo=u.load_asset(OLD+'/Textures/T_CP_AngularPigment_R02');assert isinstance(albedo,u.Texture2D) and albedo.get_editor_property('srgb')
    for family,settings in SETTINGS.items():
        source=SOURCE+'/Materials/M_CP_'+family+'_PBR_R08';target=DEST+'/Materials/M_CP_'+family+'_PBR_R09'
        mat=eal.duplicate_asset(source,target);assert isinstance(mat,u.Material)
        nodes=[n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer()==mat]
        pigment,=[n for n in nodes if isinstance(n,(u.MaterialExpressionTextureObject,u.MaterialExpressionTextureSample)) and n.get_editor_property('texture') and n.get_editor_property('texture').get_path_name().split('.')[0]==SOURCE+'/Textures/T_CP_GroupedPigment_BaseColor_R08']
        if family=='Prop':
            pigment_output,=[n for n in nodes if isinstance(n,u.MaterialExpressionCustom) and pigment in mel.get_inputs_for_material_expression(mat,n)]
        else:pigment_output=pigment
        blend,=[n for n in nodes if isinstance(n,u.MaterialExpressionLinearInterpolate) and dict(zip(map(str,mel.get_material_expression_input_names(n)),mel.get_inputs_for_material_expression(mat,n))).get('B')==pigment_output]
        inputs=dict(zip(map(str,mel.get_material_expression_input_names(blend)),mel.get_inputs_for_material_expression(mat,blend)))
        alpha=inputs['Alpha'];assert isinstance(alpha,u.MaterialExpressionConstant)
        before_mix=alpha.get_editor_property('r');pigment.set_editor_property('texture',albedo);alpha.set_editor_property('r',settings['mix'])
        assert abs(alpha.get_editor_property('r')-settings['mix'])<.00001 and pigment.get_editor_property('texture')==albedo
        assert len([n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer()==mat])==len(nodes)
        assert mel.get_material_property_input_node(mat,u.MaterialProperty.MP_NORMAL) and mel.get_material_property_input_node(mat,u.MaterialProperty.MP_ROUGHNESS)
        mel.recompile_material(mat);stats=mel.get_statistics(mat);assert stats.num_pixel_shader_instructions>0
        save(mat,dict(family=family,source=source,source_sha256=old['assets'][source]['package_sha256'],only_graph_delta=dict(albedo_texture=albedo.get_path_name(),pigment_mix_before=before_mix,pigment_mix_after=alpha.get_editor_property('r')),
            preserved='All normal/roughness nodes, parameters, texture references, planar policy and other original nodes; no new graph node.',
            pixel_instructions=stats.num_pixel_shader_instructions,vertex_instructions=stats.num_vertex_shader_instructions,tangent_space_normal=mat.get_editor_property('tangent_space_normal')))
    lid=eal.duplicate_asset(SOURCE+'/Materials/MI_CP_PropLid_PBR_R08',DEST+'/Materials/MI_CP_PropLid_PBR_R09');assert isinstance(lid,u.MaterialInstanceConstant)
    parent=u.load_asset(DEST+'/Materials/M_CP_Prop_PBR_R09');mel.set_material_instance_parent(lid,parent)
    value=mel.get_material_instance_vector_parameter_value(lid,'PropOriginB');assert max(abs(a-b) for a,b in zip(value.to_tuple()[:3],[-72.65,-25,0]))<.0001
    save(lid,dict(only_delta='Parent switches to owned R09 prop successor',parent=parent.get_path_name(),PropOriginB=list(value.to_tuple())))
    guard();assert len(receipt['assets'])==5 and u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    receipt['status']='FIVE_OWNED_R02_ALBEDO_PBR_SUCCESSORS_CREATED_AND_READ_BACK';receipt['guard_count']=len(guards)
    (RUN/'shape_pbr_assets_r09.json').write_text(json.dumps(receipt,indent=2)+'\n')
    candidate=dict(old);candidate['assets']=dict(old['assets'])|receipt['assets'];candidate.update(status='TWENTYSIX_OWNED_NATIVE_PILOT_ASSETS_CREATED_AND_READ_BACK',pbr_gate_sha256=sha(DOC/'NATIVE_PBR_TRIAL_GATE_R09.json'))
    out=RUN/'candidate_assets_r09.json';assert not out.exists();out.write_text(json.dumps(candidate,indent=2)+'\n');print('FIVE_OWNED_PBR_SUCCESSORS_READY',sha(RUN/'shape_pbr_assets_r09.json'),'ALL26',sha(out))
