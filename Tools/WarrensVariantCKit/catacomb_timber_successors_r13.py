"""Three owned successors only. Reproduce accepted transient graphs; source remains fixed."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-forage-props-r04'
OLD='/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02/Forage_R04'
DEST=OLD+'/Timber_R02'
PROFILE=DEST+'/DA_CP_ForagePresentation_R02'
MATERIALS={role:DEST+'/Materials/M_CP_ForageTimber'+role+'_R02' for role in ('Post','Arm')}
STATE=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
LOADED_TOOL_SHA256=sha(__file__)

def graph(mat):
    import unreal as u
    mel=u.MaterialEditingLibrary;nodes=[n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer()==mat];assert len(nodes)==9
    rows={}
    for n in nodes:
        row=dict(type=n.get_class().get_path_name(),inputs={str(k):v.get_name() if v else None for k,v in zip(mel.get_material_expression_input_names(n),mel.get_inputs_for_material_expression(mat,n))})
        if isinstance(n,u.MaterialExpressionConstant):row['r']=n.get_editor_property('r')
        elif isinstance(n,u.MaterialExpressionConstant3Vector):row['constant']=list(n.get_editor_property('constant').to_tuple())
        elif isinstance(n,u.MaterialExpressionCustom):
            row.update(code=n.get_editor_property('code'),output_type=str(n.get_editor_property('output_type')),input_names=[str(v.get_editor_property('input_name')) for v in n.get_editor_property('inputs')])
        rows[n.get_name()]=row
    terminals={}
    for name,prop in (('base',u.MaterialProperty.MP_BASE_COLOR),('roughness',u.MaterialProperty.MP_ROUGHNESS),('metallic',u.MaterialProperty.MP_METALLIC),('normal',u.MaterialProperty.MP_NORMAL),('emissive',u.MaterialProperty.MP_EMISSIVE_COLOR),('wpo',u.MaterialProperty.MP_WORLD_POSITION_OFFSET)):
        node=mel.get_material_property_input_node(mat,prop);terminals[name]=node.get_name() if node else None
    assert all(terminals[k] for k in ('base','roughness','metallic')) and all(terminals[k] is None for k in ('normal','emissive','wpo'))
    return dict(nodes=rows,terminals=terminals,two_sided=mat.get_editor_property('two_sided'),blend=str(mat.get_editor_property('blend_mode')),tangent_space_normal=mat.get_editor_property('tangent_space_normal'),domain=str(mat.get_editor_property('material_domain')))

def profile_refs(profile):
    return {name:(profile.get_editor_property(name).get_path_name() if profile.get_editor_property(name) else None) for name in ('stone_material','timber_post_material','timber_arm_material')}|{name:profile.get_editor_property(name).export_text() for name in ('censer','vine')}

def write(name,data):
    p=RUN/(name+'.json');assert not p.exists();p.write_text(json.dumps(data,indent=2)+'\n');return dict(file=p.relative_to(ROOT).as_posix(),sha256=sha(p))

def preflight(source,accepted):
    global STATE
    import unreal as u
    assert STATE is None and u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    source.guard(source.STATE['map_after']);assert source.dirty()==dict(maps=[],content=[])
    assert accepted.LOADED_TOOL_SHA256==sha(accepted.__file__)=='0332d34df7a35f3c51b071ebfa4864d1568d7397182c2e6cf616a8623cc20937'
    assert not accepted.STATE['bindings'] and accepted.STATE['engine'].get_editor_property('InEditorGameURLOptions')==''
    targets=list(MATERIALS.values())+[PROFILE];assert all(not u.EditorAssetLibrary.does_asset_exist(p) and not (ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset')).exists() for p in targets)
    mats={role:graph(m) for role,m in accepted.STATE['materials'].items()}
    assert set(mats)=={'Post','Arm'}
    profile=u.load_asset(OLD+'/DA_CP_ForagePresentation_R01');assert profile
    base=source.dependencies()[0];export=base._export(u,profile,RUN/'timber_successors_r13/source_profile.t3d')
    refs=profile_refs(profile)
    assert refs['timber_post_material']==OLD+'/Materials/M_CP_ForageTimberPost_R01.M_CP_ForageTimberPost_R01'
    assert refs['timber_arm_material']==OLD+'/Materials/M_CP_ForageTimberArm_R01.M_CP_ForageTimberArm_R01'
    STATE=dict(source=source,accepted=accepted,graphs=mats,profile_refs=refs,profile_export=export,created={},targets=targets)
    receipt=write('timber_successors_preflight_r13',dict(status='READ_ONLY_THREE_OWNED_SUCCESSORS_PREFLIGHT',tool_sha256=LOADED_TOOL_SHA256,accepted_graphs=mats,source_profile_refs=refs,source_profile_export=export,targets=targets,art_review_sha256=sha(DOC/'TIMBER_ART_REVIEW_R12.md'),cleanup_sha256=sha(RUN/'timber_trial_cleanup_r12.json'),source_map_sha256=source.STATE['map_after'],asset_inventory_sha256=sha(RUN/'candidate_assets_forage_r04.json'),boundary='No saved asset/source mutations. Existing36 packages remain exact.'))
    STATE['preflight']=receipt;print('SUCCESSOR_PREFLIGHT',receipt)

def create():
    import unreal as u
    s=STATE;assert s and not s['created'] and u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    assert LOADED_TOOL_SHA256==sha(__file__)
    g=read(DOC/'TIMBER_SUCCESSORS_GATE_R13.json');assert g['status']=='APPROVED_THREE_OWNED_TIMBER_SUCCESSORS' and g['tool_sha256']==LOADED_TOOL_SHA256 and g['preflight']==s['preflight']
    source=s['source'];source.guard(source.STATE['map_after']);assert source.dirty()==dict(maps=[],content=[])
    assert all(not u.EditorAssetLibrary.does_asset_exist(p) for p in s['targets'])
    assert all(graph(s['accepted'].STATE['materials'][role])==s['graphs'][role] for role in MATERIALS)
    eal=u.EditorAssetLibrary;tools=u.AssetToolsHelpers.get_asset_tools();base=source.dependencies()[0]
    ledger=dict(status='CREATING_THREE_OWNED_TIMBER_SUCCESSORS',assets={},gate_sha256=sha(DOC/'TIMBER_SUCCESSORS_GATE_R13.json'),preflight=s['preflight'])
    def save(asset,details):
        path=asset.get_path_name().split('.')[0];assert path in s['targets']
        eal.set_metadata_tag(asset,'Owner','Mars.WarrensVariantC.Catacomb.ForageTimber.R02')
        eal.set_metadata_tag(asset,'State','PendingSavedAppearanceAndSourceAdoption')
        assert eal.save_loaded_asset(asset,False)
        row=dict(package_sha256=sha(ROOT/('Content/'+path.removeprefix('/Game/')+'.uasset')),details=details)
        s['created'][path]=row;ledger['assets'][path]=row
        (RUN/'timber_successors_assets_r13.json').write_text(json.dumps(ledger,indent=2)+'\n')
        source.guard(source.STATE['map_after'])
    for role,path in MATERIALS.items():
        m=tools.create_asset(path.rsplit('/',1)[1],path.rsplit('/',1)[0],u.Material,u.MaterialFactoryNew());assert isinstance(m,u.Material)
        s['accepted'].build(m,role);assert graph(m)==s['graphs'][role],'Saved successor graph differs from accepted transient'
        stats=u.MaterialEditingLibrary.get_statistics(m);assert stats.num_pixel_shader_instructions>0 and stats.num_vertex_shader_instructions>0
        export=base._export(u,m,RUN/'timber_successors_r13'/('saved_'+role+'.t3d'))
        save(m,dict(role=role,graph=graph(m),accepted_transient=s['accepted'].STATE['materials'][role].get_path_name(),export=export,pixel_instructions=stats.num_pixel_shader_instructions,vertex_instructions=stats.num_vertex_shader_instructions))
    p=eal.duplicate_asset(OLD+'/DA_CP_ForagePresentation_R01',PROFILE);assert p
    assert profile_refs(p)==s['profile_refs']
    p.set_editor_property('timber_post_material',u.load_asset(MATERIALS['Post']));p.set_editor_property('timber_arm_material',u.load_asset(MATERIALS['Arm']))
    expected=dict(s['profile_refs']);expected['timber_post_material']=MATERIALS['Post']+'.M_CP_ForageTimberPost_R02';expected['timber_arm_material']=MATERIALS['Arm']+'.M_CP_ForageTimberArm_R02'
    assert profile_refs(p)==expected
    export=base._export(u,p,RUN/'timber_successors_r13/saved_profile.t3d')
    old=(ROOT/s['profile_export']['file']).read_text();new=(ROOT/export['file']).read_text()
    old=old.replace(OLD+'/DA_CP_ForagePresentation_R01',PROFILE).replace('DA_CP_ForagePresentation_R01','DA_CP_ForagePresentation_R02')
    for role in MATERIALS:
        old=old.replace(OLD+'/Materials/M_CP_ForageTimber'+role+'_R01',MATERIALS[role]).replace('M_CP_ForageTimber'+role+'_R01','M_CP_ForageTimber'+role+'_R02')
    assert old==new,'Profile changed beyond duplicate identity and two timber references'
    save(p,dict(only_delta='Duplicate identity plus two timber references',refs=expected,export=export))
    assert len(s['created'])==3 and source.dirty()==dict(maps=[],content=[])
    prior=read(RUN/'candidate_assets_forage_r04.json');assert len(prior['assets'])==36
    inventory=dict(prior);inventory['assets']=dict(prior['assets'])|s['created'];inventory.update(status='THIRTYNINE_OWNED_NATIVE_PILOT_ASSETS_CREATED_AND_READ_BACK',predecessor=dict(file='Saved/WarrensCGameplay-20261024/CatacombPilot/candidate_assets_forage_r04.json',sha256=sha(RUN/'candidate_assets_forage_r04.json')),timber_successor_gate_sha256=ledger['gate_sha256'])
    assert len(inventory['assets'])==39
    ledger['status']='THREE_OWNED_TIMBER_SUCCESSORS_SAVED_PENDING_NATIVE_SAVED_APPEARANCE'
    (RUN/'timber_successors_assets_r13.json').write_text(json.dumps(ledger,indent=2)+'\n')
    print('TIMBER_SUCCESSORS_CREATED',write('candidate_assets_timber_r13',inventory))
