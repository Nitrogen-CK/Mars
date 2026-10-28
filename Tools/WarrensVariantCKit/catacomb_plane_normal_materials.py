"""Two gated owned-material corrections; source maps/libraries are never saved."""
import hashlib,json,shutil,types
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02'
STATE=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def file(asset,suffix='.uasset'):return ROOT/('Content/'+asset.removeprefix('/Game/')+suffix)
def serial(value):
    import unreal as u
    if value is None or isinstance(value,(str,bool,int,float)):return value
    if isinstance(value,u.Object):return value.get_path_name()
    if isinstance(value,u.StructBase):return value.export_text()
    if isinstance(value,(u.Array,list,tuple)):return [serial(v) for v in value]
    if isinstance(value,(u.Map,dict)):return {str(k):serial(v) for k,v in value.items()}
    return str(value)
def properties(obj):
    names={k for cls in type(obj).__mro__ for k,v in vars(cls).items() if isinstance(v,types.GetSetDescriptorType) and not k.startswith('_')}
    result={}
    for k in sorted(names):
        try:result[k]=serial(getattr(obj,k))
        except Exception as e:result[k]=dict(read_error=str(e))
    return result
def snapshot(mat):
    import unreal as u
    mel=u.MaterialEditingLibrary;nodes={}
    for n in u.ObjectIterator(u.MaterialExpression):
        if n.get_outer()!=mat:continue
        names=list(map(str,mel.get_material_expression_input_names(n)));inputs=mel.get_inputs_for_material_expression(mat,n)
        nodes[n.get_name()]=dict(cls=n.get_class().get_name(),properties=properties(n),inputs=[dict(pin=k,node=v.get_name() if v else None) for k,v in zip(names,inputs)])
    props=properties(mat);props['tangent_space_normal']=mat.get_editor_property('tangent_space_normal')
    return dict(properties=props,nodes=nodes,outputs={str(p):serial(mel.get_material_property_input_node(mat,p)) for p in (u.MaterialProperty.MP_BASE_COLOR,u.MaterialProperty.MP_ROUGHNESS,u.MaterialProperty.MP_METALLIC,u.MaterialProperty.MP_NORMAL)})
def _write(name,data):
    p=RUN/name;assert not p.exists();p.write_text(json.dumps(data,indent=2,sort_keys=True)+'\n');return sha(p)
def preflight(trial):
    global STATE
    import unreal as u
    assert STATE is None and u.GameplayStatics.is_game_paused(trial.STATE['world'])
    gate_path=DOC/'NORMAL_MATERIAL_TRIAL_GATE_R01.json';assert sha(gate_path)=='179d19dc44348e6c74f4670cf5f6461aa6aa9c08a570ebdbe0e9240e468298d9'
    gate=read(gate_path);assert gate['status']=='APPROVED_FOR_TWO_OWNED_MATERIAL_NORMAL_CORRECTION'
    assert sha(DOC/'NATIVE_TRIAL_GATE.json')==gate['parent_trial_gate_sha256'] and sha(ROOT/gate['source_assets_receipt'])==gate['source_assets_receipt_sha256']
    assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    old=read(ROOT/gate['source_assets_receipt']);guards={str(file(p)):r['package_sha256'] for p,r in old['assets'].items()}
    for p in old['assets']:
        companion=file(p,'.ckexport')
        if companion.exists():guards[str(companion)]=sha(companion)
    assert all(sha(p)==v for p,v in guards.items())
    backup=RUN/'normal_material_backups_r06';backup.mkdir(exist_ok=True);rows=[]
    for r in gate['allowed_materials']:
        assert sha(file(r['path']))==r['package_sha256_before'] and sha(file(r['path'],'.ckexport'))==r['ckexport_sha256_before']
        for suffix in ('.uasset','.ckexport'):
            src=file(r['path'],suffix);dst=backup/src.name
            if not dst.exists():shutil.copyfile(src,dst)
            assert sha(dst)==sha(src)
        mat=u.load_asset(r['path']);assert mat and mat.get_path_name()==r['path']+'.'+r['name']
        # PIE readback exposes no metadata tags on these loaded candidates.
        # Ownership is pinned by the independent gate's exact path + package
        # and ckexport hashes and the original creation receipt, not a tag.
        assert u.MaterialEditingLibrary.get_material_property_input_node(mat,u.MaterialProperty.MP_NORMAL) is None
        rows.append(dict(config=r,material=mat,before=snapshot(mat),added=[]))
    STATE=dict(trial=trial,rows=rows,guards=guards,gate=gate,old=old,backup=backup)
    record_preflight()
def record_preflight():
    s=STATE;assert s and all(snapshot(r['material'])==r['before'] and not r['added'] for r in s['rows'])
    assert all(sha(p)==v for p,v in s['guards'].items())
    result=dict(status='READ_ONLY_NATIVE_GRAPH_AND_HASH_BASELINE',gate_sha256=sha(DOC/'NORMAL_MATERIAL_TRIAL_GATE_R01.json'),candidate_guards=s['guards'],protected_guards=s['trial']._guard(),rows=[dict(config=r['config'],graph=r['before']) for r in s['rows']],backup=str(s['backup'].relative_to(ROOT)))
    print('PLANE_NORMAL_PREFLIGHT',_write('materials_plane_normals_preflight_r06.json',result))
def restore_unsaved_stage_and_reflect_flag():
    import unreal as u
    s=STATE;assert s and all(sha(p)==v for p,v in s['guards'].items())
    assert u.get_default_object(u.Material).get_editor_property('tangent_space_normal') is True
    for row in s['rows']:
        mat=row['material']
        for node in reversed(row['added']):u.MaterialEditingLibrary.delete_material_expression(mat,node)
        if row['added']:
            mat.set_editor_property('tangent_space_normal',True);u.MaterialEditingLibrary.recompile_material(mat)
        after=snapshot(mat);original=row['before']
        assert after['nodes']==original['nodes'] and after['outputs']==original['outputs']
        assert {k:v for k,v in after['properties'].items() if k!='tangent_space_normal'}==original['properties']
        assert after['properties']['tangent_space_normal'] is True
        row['before']=after;row['added']=[];row.pop('after',None)
    print('UNSAVED_STAGE_ROLLED_BACK_AND_EXPLICIT_EDITOR_FLAG_BASELINED',_write('materials_plane_normals_preflight_flag_r07.json',dict(status='NATIVE_BASELINE_INCLUDES_EDITOR_ONLY_TANGENT_FLAG',rows=[dict(path=r['config']['path'],before=r['before']) for r in s['rows']],boundary='No package saved. Original 56 descriptor properties, all original node properties/connections and outputs restored exactly; explicit tangent-space flag now separately captured.')))
def stage():
    import unreal as u
    s=STATE;assert s and all(not r['added'] for r in s['rows']);mel=u.MaterialEditingLibrary
    for row in s['rows']:
        mat=row['material'];assert snapshot(mat)==row['before']
        n=mel.create_material_expression(mat,u.MaterialExpressionConstant3Vector,400,500);row['added'].append(n);n.set_editor_property('constant',u.LinearColor(*row['config']['constant_local_normal'],1))
        t=mel.create_material_expression(mat,u.MaterialExpressionTransform,600,500);row['added'].append(t);t.set_editor_property('transform_source_type',u.MaterialVectorCoordTransformSource.TRANSFORMSOURCE_LOCAL);t.set_editor_property('transform_type',u.MaterialVectorCoordTransform.TRANSFORM_WORLD)
        normalize=mel.create_material_expression(mat,u.MaterialExpressionNormalize,800,500);row['added'].append(normalize)
        for a,b in ((n,t),(t,normalize)):
            pin,=mel.get_material_expression_input_names(b);assert mel.connect_material_expressions(a,'',b,str(pin))
        assert mel.connect_material_property(normalize,'',u.MaterialProperty.MP_NORMAL)
        mat.set_editor_property('tangent_space_normal',False);mel.recompile_material(mat)
        after=snapshot(mat)
        assert {k:v for k,v in after['nodes'].items() if k in row['before']['nodes']}==row['before']['nodes']
        changed={k for k in after['properties'] if after['properties'][k]!=row['before']['properties'][k]};assert changed=={'tangent_space_normal'},changed
        assert all(after['outputs'][p]==v for p,v in row['before']['outputs'].items() if 'MP_NORMAL' not in p)
        assert len(after['nodes'])==len(row['before']['nodes'])+3 and mel.get_material_property_input_node(mat,u.MaterialProperty.MP_NORMAL)==normalize
        row['after']=after
    print('PLANE_NORMALS_EXACT_GRAPH_DELTA_STAGED',_write('materials_plane_normals_staged_r06.json',dict(status='ONLY_THREE_NODES_AND_TANGENT_SPACE_CHANGE_PER_PARENT_UNSAVED',rows=[dict(path=r['config']['path'],before=r['before'],after=r['after']) for r in s['rows']])))
def save():
    import unreal as u
    s=STATE;assert s and all('after' in r for r in s['rows'])
    expected={r['config']['path'] for r in s['rows']};assert {p.get_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()}==expected
    compiler=[]
    for name in s['compile_receipts']:
        response=read(ROOT/name)['response'];result=json.loads(response['result']['content'][0]['text'])
        assert result['is_compiled'] is True and not result.get('compile_errors')
        compiler.append(dict(file=name,sha256=sha(ROOT/name),result=result))
    assert {r['result']['asset_path'] for r in compiler}==expected
    assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==[]
    for row in s['rows']:
        mat=row['material'];assert snapshot(mat)==row['after'];assert u.MaterialEditingLibrary.get_statistics(mat).num_pixel_shader_instructions>0
        assert u.EditorAssetLibrary.save_loaded_asset(mat,only_if_is_dirty=True)
        assert snapshot(mat)==row['after'];row['package_after']=sha(file(row['config']['path']));row['ckexport_after']=sha(file(row['config']['path'],'.ckexport'))
        assert row['package_after']!=row['config']['package_sha256_before'] and row['ckexport_after']!=row['config']['ckexport_sha256_before']
        exported=read(file(row['config']['path'],'.ckexport'));assert len(exported['graph']['nodes'])==len(row['after']['nodes'])
    permitted={str(file(p,suffix)) for p in expected for suffix in ('.uasset','.ckexport')}
    assert all(sha(p)==v for p,v in s['guards'].items() if p not in permitted);s['trial']._guard()
    assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    result=dict(status='TWO_OWNED_LOCAL_PLANE_NORMAL_MATERIALS_SAVED_GRAPH_DELTA_VERIFIED',policy='Intentional planar shading for shallow veneer; normalized local ±Z transformed to world. No physical normal texture derived from albedo.',rows=[dict(path=r['config']['path'],before=r['before'],after=r['after'],package_before=r['config']['package_sha256_before'],package_after=r['package_after'],ckexport_before=r['config']['ckexport_sha256_before'],ckexport_after=r['ckexport_after']) for r in s['rows']],compiler_readbacks=compiler,backup=str(s['backup'].relative_to(ROOT)),tool_sha256=sha(__file__),protected_guard_count=len(s['trial']._guard()),boundary='Only two owned candidate materials saved. Source maps/libraries untouched. Native rotated/WorldNormal/Lit images exist; saved-state and final complete-room review pending.')
    receipt_sha=_write('materials_plane_normals_r06.json',result)
    candidate=json.loads(json.dumps(s['old']))
    for row in s['rows']:
        r=candidate['assets'][row['config']['path']];r['package_sha256']=row['package_after'];r['details']['normal']='Normalized source-local plane normal transformed to world; intentional shallow-veneer art shading'
    candidate['normal_material_receipt_sha256']=receipt_sha;candidate['normal_material_gate_sha256']=sha(DOC/'NORMAL_MATERIAL_TRIAL_GATE_R01.json')
    print('PLANE_NORMALS_SAVED',receipt_sha,_write('candidate_assets_r03.json',candidate))
def bind_staged():
    s=STATE;assert s and all('after' in r for r in s['rows'])
    for c,i,old in s['trial'].STATE['scratch_normals']['rows']:c.set_material(i,old);assert c.get_material(i)==old
    s['trial'].STATE['stage']='AA_owned_plane_normal_materials'
