"""Additive high-roof visibility A/B; original seven actors and source stay fixed."""
import copy,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
STATE=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def begin(controller,extension):
    import unreal as u
    global STATE
    assert STATE is None;extension.check();s=controller.STATE;assert len(s['created'])==7
    gate=json.loads((DOC/'NATIVE_HIGH_ROOF_GATE_R01.json').read_text());assert gate['status']=='APPROVED_ABSENT_PRIVATE_HIGH_ROOF_AND_DISPOSABLE_TRIAL_ONLY' and gate['trial_tool_sha256']==sha(__file__) and gate['controller_sha256']==sha(controller.__file__) and gate['extension_sha256']==sha(extension.__file__)
    for p,h in gate['input_sha256'].items():assert sha(ROOT/p)==h
    proof=json.loads((DOC/'roof-completion-export-r01/native_asset.json').read_text());target=proof['target'];assert target=='/Game/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01/Meshes/WVC_Larder_HighRoof_R01_SM' and proof['status']=='ONE_PRIVATE_HIGH_ROOF_SAVED_NOT_BOUND_OR_ART_ACCEPTED';path=ROOT/('Content/'+target.removeprefix('/Game/')+'.uasset');assert sha(path)==proof['package_sha256'];mesh=u.load_asset(target);assert isinstance(mesh,u.StaticMesh)
    signature={k:extension.STATE[k] for k in ['outward','successor_on','repeat','new_normal','s3_on']}
    STATE=dict(controller=controller,extension=extension,gate=gate,proof=proof,asset_file=path,old_created=list(s['created']),old_owned=copy.deepcopy(s['owned_expected']),correction_signature=signature,actor=None,on=False)
    actor=controller.mesh_actor(mesh,u.Transform(location=u.Vector(5000,-1500,-250)),[v.get_editor_property('material_interface') for v in mesh.static_materials],'WVC_Larder_Finish_HighRoof');STATE['actor']=actor
    assert actor.static_mesh_component.get_editor_property('cast_hidden_shadow') is False
    actor.static_mesh_component.set_visibility(False,False);actor.static_mesh_component.set_hidden_in_game(True,False);s['owned_expected']=[controller.owned(a) for a in s['created']]
    assert s['created'][:7]==STATE['old_created'] and s['owned_expected'][:7]==STATE['old_owned'] and len(s['created'])==8;check();print('HIGH_ROOF_DISPOSABLE_ACTOR_HIDDEN_READY')
def check():
    import unreal as u
    t=STATE;assert t;t['extension'].check();s=t['controller'].STATE;assert sha(__file__)==t['gate']['trial_tool_sha256'] and sha(t['asset_file'])==t['proof']['package_sha256']
    assert len(s['created'])==8 and s['created'][:7]==t['old_created'] and [t['controller'].owned(a) for a in t['old_created']]==t['old_owned']
    assert {k:t['extension'].STATE[k] for k in t['correction_signature']}==t['correction_signature']
    c=t['actor'].static_mesh_component;assert c.is_visible()==t['on'] and c.get_editor_property('hidden_in_game')==(not t['on']) and c.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION and c.get_editor_property('cast_hidden_shadow') is False
def visible(on):
    assert isinstance(on,bool);check();t=STATE;s=t['controller'].STATE;a=t['actor'];before=t['controller'].owned(a);c=a.static_mesh_component;c.set_visibility(on,False);c.set_hidden_in_game(not on,False)
    expected=copy.deepcopy(before);expected['visible']=on;expected['hidden']=not on;expected['lighting_flags']['visible']=on;expected['lighting_flags']['hidden_in_game']=not on
    assert t['controller'].owned(a)==expected;s['owned_expected'][-1]=expected;t['on']=on;check()
def capture(label):
    import unreal as u
    t=STATE;u.GameplayStatics.set_game_paused(t['controller'].STATE['world'],True);check();t['extension'].capture(label);p=t['controller'].STATE['capture'].STATE['out']/(label+'.json');r=json.loads(p.read_text());r['high_roof_state']=dict(visible=t['on'],actor=t['actor'].get_path_name(),asset=t['proof']['target'],package_sha256=t['proof']['package_sha256'],boundary='Only the additive source-supported12mroofvisibility toggles. Existing132localceilings/sevenotherownedactors/sourceHISMs/lights/physics stay exact. Source adoption and whole-room acceptance remain separate.');p.write_text(json.dumps(r,indent=2)+'\n')
def release():
    global STATE
    visible(False);t=STATE;controller=t['controller'];STATE=None;controller.check();print('HIGH_ROOF_REFERENCES_RELEASED_HIDDEN_ACTOR_OWNED_BY_BASE_CLEANUP')
def abort(controller,extension):
    global STATE
    try:extension.abort(controller)
    finally:STATE=None
