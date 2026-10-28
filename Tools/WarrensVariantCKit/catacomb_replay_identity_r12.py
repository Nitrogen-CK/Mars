"""Fresh read-only validation of the finite, observed allocation-name permutation."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-forage-props-r04'
LOADED_TOOL_SHA256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
VALIDATED=None

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(name):return json.loads((RUN/name).read_text())

def collect():
    import unreal as u
    w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert w and w.get_path_name()=='/Game/Mars/Maps/UEDPIE_0_Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    kind=u.get_type_from_class(u.load_class(None,'/Script/Angelscript.Mars_ForageSource_EntityScript'))
    sources=[o for o in u.ObjectIterator(kind) if not o.get_name().startswith('Default__') and o.get_world()==w];assert sources
    h=sources[0].do_get_script_entity()
    life=u.get_type_from_class(u.load_class(None,'/Script/CkEcs.Ck_Utils_EntityLifetime_UE'));assert life.get_world_for_entity(h)==w
    tag=u.get_type_from_class(u.load_class(None,'/Script/CkEntityTag.Ck_Utils_EntityTag_UE'));dyn=u.get_type_from_class(u.load_class(None,'/Script/CkDynamic.Ck_Utils_DynamicFragment_UE'))
    rows={}
    for label in ('TAG_MarsAnchor','TAG_MarsAnchorResolver'):
        rows[label]=[]
        for handle in tag.for_each_entity(h,u.Name(label)):
            texts=[f.export_text() for f in dyn.get_all_fragments(handle)]
            if label=='TAG_MarsAnchorResolver' or any('Anchor.Mars.Warrens.CatacombHusk' in t for t in texts):rows[label].append(dict(handle=handle.export_text(),fragments=texts))
    typ=u.get_type_from_class(u.load_class(None,'/Script/Angelscript.Mars_Anchor_Forage_EntityScript'))
    rows['catacomb_archetypes']=[dict(path=o.get_path_name(),tag=o.get_editor_property('AnchorId').export_text(),profile=o.get_editor_property('ForagePresentation').get_path_name() if o.get_editor_property('ForagePresentation') else None) for o in u.ObjectIterator(typ) if 'UEDPIE_0_LI_Warrens_Catacomb' in o.get_path_name()]
    rows['source_contexts']=[dict(path=o.get_path_name(),type=o.get_class().get_path_name(),context=o.get_editor_property('Anchor').export_text()) for o in sources];rows['world']=w.get_path_name()
    parts=[]
    for a in u.GameplayStatics.get_all_actors_of_class(w,u.Actor):
        for c in a.get_components_by_class(u.StaticMeshComponent):
            if not c.static_mesh:continue
            p=c.get_world_location()
            if not abs(p.x+9600)<150 or not abs(p.y-1900)<100 or not 0<=p.z<=270:continue
            parts.append(dict(path=c.get_path_name(),mesh=c.static_mesh.get_path_name().split('.')[0],material=c.get_material(0).get_path_name().split('.')[0] if c.get_material(0) else None,at=list(p.to_tuple()),scale=list(c.get_world_scale().to_tuple()),rotation=c.get_world_transform().export_text(),collision=str(c.get_collision_profile_name()),collision_enabled=str(c.get_collision_enabled()),visible=c.is_visible()))
    assert len(parts)==8 and len({r['path'] for r in parts})==8
    return rows,parts

def canonical(rows):
    v=json.loads(json.dumps(rows))
    for label in ('TAG_MarsAnchor','TAG_MarsAnchorResolver'):
        for r in v[label]:r['fragments']=sorted(r['fragments'])
        v[label]=sorted(v[label],key=lambda r:json.dumps(r,sort_keys=True))
    for label in ('source_contexts','catacomb_archetypes'):v[label]=sorted(v[label],key=lambda r:r['path'])
    return v

def validate(trial):
    global VALIDATED
    import unreal as u
    assert VALIDATED is None and LOADED_TOOL_SHA256==sha(__file__)
    g=json.loads((DOC/'TIMBER_REPLAY_IDENTITY_GATE_R12.json').read_text())
    assert g['status']=='APPROVED_FINITE_RUNTIME_IDENTITY_VALIDATION' and g['tool_sha256']==LOADED_TOOL_SHA256
    for name,h in g['evidence_sha256'].items():assert sha(RUN/name)==h
    assert trial.LOADED_TOOL_SHA256==sha(trial.__file__)=='0332d34df7a35f3c51b071ebfa4864d1568d7397182c2e6cf616a8623cc20937'
    trial.gate();s=trial.STATE;assert not s['verified'] and not s['url_staged'] and not s['bindings']
    assert s['engine'].get_editor_property('InEditorGameURLOptions')==s['url_before']==''
    old=canonical(read('source_profile_runtime_readback_r11.json'));observed=canonical(read('source_profile_runtime_readback_r12.json'));fresh,parts=collect();fresh=canonical(fresh)
    assert fresh==observed,'Current runtime differs from the specific reviewed replay'
    assert len(old['source_contexts'])==len(fresh['source_contexts'])==9
    assert len({r['path'] for r in fresh['source_contexts']})==9
    prefix=old['world']+':Mars_ForageCenser_EntityScript_'
    pair={prefix+'1',prefix+'2'}
    a={r['path']:r for r in old['source_contexts']};b={r['path']:r for r in fresh['source_contexts']};assert set(a)==set(b)
    for path in set(a)-pair:assert a[path]==b[path]
    expected_type='/Script/Angelscript.Mars_ForageCenser_EntityScript'
    for path in pair:assert a[path]['type']==b[path]['type']==expected_type
    assert a[prefix+'1']['context']==b[prefix+'2']['context'] and a[prefix+'2']['context']==b[prefix+'1']['context']
    assert 'Anchor.Mars.Warrens.LarderForage' in a[prefix+'1']['context'] and 'Anchor.Mars.Warrens.PitForage' in a[prefix+'2']['context']
    assert all(old[k]==fresh[k] for k in old if k!='source_contexts')
    before=read('source_profile_fig_parts_r11.json')['parts'];current=read('source_profile_fig_parts_r12.json')['parts']
    by_path=lambda rows:{r['path']:r for r in rows}
    assert by_path(parts)==by_path(current),'Current native part attributes differ from the reviewed eight-part replay'
    component_prefix=old['world']+':PersistentLevel.Ck_UnrealComponent_Host.StaticMeshComponent_'
    expected_mapping={component_prefix+str(i):component_prefix+str(i-51) for i in range(292,300)}
    assert set(by_path(before))==set(expected_mapping) and set(by_path(current))==set(expected_mapping.values())
    for path,old_part in by_path(before).items():
        expected=dict(old_part,path=expected_mapping[path]);assert expected==by_path(current)[expected_mapping[path]]
    s['source'].guard(s['source'].STATE['map_after']);assert s['source'].dirty()==dict(maps=[],content=[])
    assert u.GameplayStatics.is_game_paused(u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world())
    receipt=trial.write('timber_replay_identity_validated_r12',dict(status='FINITE_CENSER_AND_EIGHT_COMPONENT_ALLOCATION_PERMUTATION_VALIDATED_ON_FRESH_NATIVE_READ',gate_sha256=sha(DOC/'TIMBER_REPLAY_IDENTITY_GATE_R12.json'),tool_sha256=LOADED_TOOL_SHA256,current=fresh,parts=parts,component_mapping=expected_mapping,source_context_exception=sorted(pair),unchanged_source_rows=7,editor_url_restored=True,boundary='Same actual seed/result/ledger/targetFig/context/geometry. Only the explicitly observed allocation-name bijections are accepted; no relaunch, row forcing or runtime mutation. Not material appearance acceptance.'))
    VALIDATED=receipt
    # Derived validator state only after all fresh native checks; never a manual bypass or live ECS write.
    s['verified']=True;s['runtime']=receipt;s['identity_validation']=receipt
    print('FINITE_REPLAY_IDENTITY_VALIDATED',receipt)
