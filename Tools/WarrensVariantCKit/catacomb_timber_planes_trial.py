"""Transient timber-only lookdev. No asset save or production-profile mutation."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-forage-props-r04'
ENGINE='/Engine/Transient.UnrealEdEngine_0'
REPLAY='?seed=1632092801'
STATE=None
LOADED_TOOL_SHA256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()

def _u():import unreal;return unreal
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def write(name,data):
    p=RUN/(name+'.json');assert not p.exists();p.write_text(json.dumps(data,indent=2)+'\n');return dict(file=p.relative_to(ROOT).as_posix(),sha256=sha(p))

def build(mat,role):
    u=_u();mel=u.MaterialEditingLibrary;assert role in ('Post','Arm')
    def expr(cls,**props):
        n=mel.create_material_expression(mat,cls,0,0);assert n
        for key,value in props.items():n.set_editor_property(key,value)
        return n
    def link(a,b,pin):assert mel.connect_material_expressions(a,'',b,str(pin))
    p=expr(u.MaterialExpressionPreSkinnedPosition);vi=expr(u.MaterialExpressionVertexInterpolator)
    pin,=mel.get_material_expression_input_names(vi);link(p,vi,pin)
    factor=expr(u.MaterialExpressionConstant,r=.01);mul=expr(u.MaterialExpressionMultiply);link(vi,mul,'A');link(factor,mul,'B')
    half=expr(u.MaterialExpressionConstant3Vector,constant=u.LinearColor(.5,.5,.5,1));norm=expr(u.MaterialExpressionAdd);link(mul,norm,'A');link(half,norm,'B')
    # Cube local [-50,50]cm -> [0,1]. Different width/length scales do not change frequency.
    axis='float L=P.z; float Q=abs(P.x-.5)>abs(P.y-.5)?P.y:P.x;' if role=='Post' else 'float L=P.x; float Q=abs(P.y-.5)>abs(P.z-.5)?P.z:P.y;'
    code=axis+'''\nfloat3 C=float3(.100,.052,.024);
// Unequal interrupted wedges, with broad straight edges and no fractal/grain noise.
if(L<.76 && Q<(.12+.26*L)) C=float3(.082,.040,.018);
if(L>.20 && Q>(.64+.10*abs(L-.37))) C=float3(.118,.064,.030);
if(L>.72 && Q>.24 && Q<(.55+.12*(L-.72))) C=float3(.106,.050,.023);
return C;'''
    custom=expr(u.MaterialExpressionCustom,code=code,output_type=u.CustomMaterialOutputType.CMOT_FLOAT3,description='Quiet timber with broad unequal interrupted painted planes')
    inp=u.CustomInput();inp.set_editor_property('input_name','P');custom.set_editor_property('inputs',[inp]);link(norm,custom,'P')
    assert mel.connect_material_property(custom,'',u.MaterialProperty.MP_BASE_COLOR)
    for value,prop in ((0,u.MaterialProperty.MP_METALLIC),(.86,u.MaterialProperty.MP_ROUGHNESS)):
        n=expr(u.MaterialExpressionConstant,r=value);assert mel.connect_material_property(n,'',prop)
    nodes=[n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer()==mat]
    assert len(nodes)==9 and not any(isinstance(n,u.MaterialExpressionNoise) for n in nodes)
    assert all(mel.get_material_property_input_node(mat,p) for p in (u.MaterialProperty.MP_BASE_COLOR,u.MaterialProperty.MP_ROUGHNESS,u.MaterialProperty.MP_METALLIC))
    mel.recompile_material(mat)
    return dict(role=role,path=mat.get_path_name(),nodes=len(nodes),code=code,roughness=.86,metallic=0,normal='Default flat tangent-space normal; unchanged from original timber',boundary='Transient graph construction; actual native appearance still pending')

def prepare(source):
    global STATE
    u=_u();assert STATE is None and u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    source.guard(source.STATE['map_after']);assert source.dirty()==dict(maps=[],content=[])
    engine=u.find_object(None,ENGINE);assert engine and u.Object.get_class(engine).get_path_name()=='/Script/UnrealEd.UnrealEdEngine'
    assert engine.get_editor_property('InEditorGameURLOptions')==''
    mats={};rows=[]
    for role in ('Post','Arm'):
        m=u.new_object(u.Material,name='CP_ForageTimber'+role+'_BroadPlaneTrial_R12')
        assert m.get_outer().get_path_name()=='/Engine/Transient';mats[role]=m;rows.append(build(m,role))
    STATE=dict(source=source,engine=engine,url_before='',url_staged=False,materials=mats,rows=rows,bindings=[],verified=False)
    base=source.dependencies()[0];exports={role:base._export(u,m,RUN/'timber_planes_r12'/('Transient_'+role+'.t3d')) for role,m in mats.items()}
    assert source.dirty()==dict(maps=[],content=[]);source.guard(source.STATE['map_after'])
    receipt=write('timber_planes_preflight_r12',dict(status='TWO_TRANSIENT_NINE_NODE_GRAPHS_PREPARED',graphs=rows,exports=exports,engine=ENGINE,url_before='',replay=REPLAY,tool_sha256=LOADED_TOOL_SHA256,source_guard_sha256=sha(RUN/'baseline_guard_after_source_profile_r11.json'),asset_inventory_sha256=sha(RUN/'candidate_assets_forage_r04.json'),boundary='No map, asset, editor option or profile writes. No native appearance acceptance.'))
    STATE['preflight']=receipt;print('TIMBER_PREFLIGHT',receipt)

def verify_after_gc():
    u=_u();s=STATE;assert s
    for role,m in s['materials'].items():
        assert u.SystemLibrary.is_valid(m) and u.find_object(None,s['rows'][0 if role=='Post' else 1]['path'])==m
        assert m.get_outer().get_path_name()=='/Engine/Transient'
        assert len([n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer()==m])==9
    s['source'].guard(s['source'].STATE['map_after']);assert s['source'].dirty()==dict(maps=[],content=[])
    r=write('timber_planes_after_gc_r12',dict(status='SAME_TWO_TRANSIENT_GRAPH_IDENTITIES_OBSERVED_AFTER_SEPARATE_GC_TURN',preflight=s['preflight'],paths=[m.get_path_name() for m in s['materials'].values()],boundary='Actual separate-turn observation after queued collect_garbage; no disk save or claimed shader appearance. Bound component OverrideMaterials will retain the trial materials.'))
    s['after_gc']=r;print('TIMBER_AFTER_GC',r)

def gate():
    s=STATE;assert s and sha(__file__)==LOADED_TOOL_SHA256
    g=read(DOC/'TIMBER_PLANES_TRIAL_GATE_R12.json')
    assert g['status']=='APPROVED_TRANSIENT_TIMBER_REPLAY_COMPARISON' and g['tool_sha256']==LOADED_TOOL_SHA256
    assert g['preflight']==s['preflight'] and g['after_gc']==s['after_gc'] and g['replay']==REPLAY
    return g

def stage_replay():
    u=_u();s=STATE;gate();assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    assert not s['url_staged'] and s['engine'].get_editor_property('InEditorGameURLOptions')==s['url_before']==''
    s['source'].guard(s['source'].STATE['map_after']);assert s['source'].dirty()==dict(maps=[],content=[])
    s['url_staged']=True;s['engine'].set_editor_property('InEditorGameURLOptions',REPLAY)
    assert s['engine'].get_editor_property('InEditorGameURLOptions')==REPLAY
    print('REPLAY_OPTION_STAGED_IN_MEMORY',write('timber_replay_option_staged_r12',dict(status='CONTROLLED_REPLAY_URL_STAGED',engine=ENGINE,before=s['url_before'],after=REPLAY,save_config=False,boundary='Controlled reproduction of an already observed run, not fresh unforced seed evidence. Restore on every exit.')))

def restore_replay():
    s=STATE;assert s
    assert s['engine'].get_editor_property('InEditorGameURLOptions') in (s['url_before'],REPLAY)
    s['engine'].set_editor_property('InEditorGameURLOptions',s['url_before'])
    assert s['engine'].get_editor_property('InEditorGameURLOptions')==s['url_before'];s['url_staged']=False
    print('REPLAY_OPTION_RESTORED',s['url_before'])

def verify_runtime():
    u=_u();s=STATE;gate();w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert w and w.get_path_name()=='/Game/Mars/Maps/UEDPIE_0_Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    kind=u.get_type_from_class(u.load_class(None,'/Script/Angelscript.Mars_ForageSource_EntityScript'))
    sources=[o for o in u.ObjectIterator(kind) if not o.get_name().startswith('Default__') and o.get_world()==w];assert sources
    handle=sources[0].do_get_script_entity();tag=u.get_type_from_class(u.load_class(None,'/Script/CkEntityTag.Ck_Utils_EntityTag_UE'));dyn=u.get_type_from_class(u.load_class(None,'/Script/CkDynamic.Ck_Utils_DynamicFragment_UE'))
    rows={}
    for label in ('TAG_MarsAnchor','TAG_MarsAnchorResolver'):
        rows[label]=[]
        for h in tag.for_each_entity(handle,u.Name(label)):
            texts=[f.export_text() for f in dyn.get_all_fragments(h)]
            if label=='TAG_MarsAnchorResolver' or any('Anchor.Mars.Warrens.CatacombHusk' in t for t in texts):rows[label].append(dict(handle=h.export_text(),fragments=texts))
    typ=u.get_type_from_class(u.load_class(None,'/Script/Angelscript.Mars_Anchor_Forage_EntityScript'))
    rows['catacomb_archetypes']=[dict(path=o.get_path_name(),tag=o.get_editor_property('AnchorId').export_text(),profile=o.get_editor_property('ForagePresentation').get_path_name() if o.get_editor_property('ForagePresentation') else None) for o in u.ObjectIterator(typ) if 'UEDPIE_0_LI_Warrens_Catacomb' in o.get_path_name()]
    rows['source_contexts']=[dict(path=o.get_path_name(),type=o.get_class().get_path_name(),context=o.get_editor_property('Anchor').export_text()) for o in sources];rows['world']=w.get_path_name()
    r=write('source_profile_runtime_readback_r12',rows)
    old=read(RUN/'source_profile_runtime_readback_r11.json')
    def canonical(data):
        value=json.loads(json.dumps(data))
        # ObjectIterator and fragment enumeration order are not runtime contracts.
        for label in ('TAG_MarsAnchor','TAG_MarsAnchorResolver'):
            for row in value[label]:row['fragments']=sorted(row['fragments'])
            value[label]=sorted(value[label],key=lambda row:json.dumps(row,sort_keys=True))
        for label in ('source_contexts','catacomb_archetypes'):value[label]=sorted(value[label],key=lambda row:row['path'])
        return value
    assert canonical(rows)==canonical(old),'Replay differs from observed R11 result/ledger/contexts; no history manipulation or row forcing allowed'
    assert not s['url_staged'] and s['engine'].get_editor_property('InEditorGameURLOptions')==s['url_before']
    s['verified']=True;s['runtime']=r
    print('CONTROLLED_REPLAY_EXACT_RESULT_LEDGER_CONTEXT',r)

def bind(room):
    u=_u();s=STATE;gate();assert s['verified'] and not s['bindings'];assert u.GameplayStatics.is_game_paused(room.STATE['world'])
    old=s['source'].PROFILE.rsplit('/',1)[0]+'/Materials/M_CP_ForageTimber'
    expected=read(RUN/'source_profile_fig_parts_r11.json')['parts'];rows=[]
    for a in u.GameplayStatics.get_all_actors_of_class(room.STATE['world'],u.Actor):
        for c in a.get_components_by_class(u.StaticMeshComponent):
            if not c.static_mesh or not c.get_material(0):continue
            p=c.get_world_location();at=list(p.to_tuple());material=c.get_material(0)
            if abs(p.x+9600)>150 or abs(p.y-1900)>100 or not 0<=p.z<=270:continue
            role='Post' if material.get_path_name().split('.')[0]==old+'Post_R01' else 'Arm' if material.get_path_name().split('.')[0]==old+'Arm_R01' else None
            if not role:continue
            ref,=[r for r in expected if max(abs(x-y) for x,y in zip(r['at'],at))<.001]
            assert max(abs(x-y) for x,y in zip(ref['scale'],list(c.get_world_scale().to_tuple())))<.00001
            assert ref['collision']==str(c.get_collision_profile_name()) and ref['material']==material.get_path_name().split('.')[0]
            rows.append((c,material,role))
    assert len(rows)==3 and sorted(r[2] for r in rows)==['Arm','Post','Post']
    for c,original,role in rows:
        s['bindings'].append((c,original,role));c.set_material(0,s['materials'][role]);assert c.get_material(0)==s['materials'][role]
    print('THREE_TRANSIENT_TIMBER_BINDINGS',[(c.get_path_name(),role) for c,_,role in s['bindings']])

def restore_bindings():
    s=STATE;assert s
    for c,original,role in s['bindings']:
        c.set_material(0,original);assert c.get_material(0)==original
    s['bindings'].clear();restore_replay();print('TIMBER_BINDINGS_RESTORED')
