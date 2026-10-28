"""Stage one finite decorative tail so each original/clone view stays paused."""
import copy,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def stage(controller,role):
    import unreal as u
    gate=json.loads((DOC/'NATIVE_SINGLE_DECOR_STAGE_GATE_R01.json').read_text());assert gate['status']=='APPROVED_SINGLE_FINITE_DECOR_TAIL_STAGE_FOR_MATCHED_BASELINE' and gate['tool_sha256']==sha(__file__) and gate['controller_sha256']==sha(controller.__file__)
    controller.check();s=controller.STATE;assert role in ('barrel','sack','jar') and role not in s['props'] and not s['paint_mids']
    label,index,count,at=controller.PROPS[role]
    actor,=[a for a in u.GameplayStatics.get_all_actors_of_class(s['world'],u.Actor) if a.get_actor_label()==label and 'LI_Warrens_Brineworks' in a.get_path_name()]
    c,=actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
    assert c.get_instance_count()==count and index==count-1 and c.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION and c.mobility==u.ComponentMobility.STATIC and c.get_editor_property('num_custom_data_floats')==0
    assert c.static_mesh.get_path_name().split('.')[0]==controller.PROP_MESHES[role]
    material_ids,slot_ids=controller.PROP_SLOTS[role]
    assert [m.get_path_name().split('.')[0] for m in c.get_materials()]==['/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_'+n for n in material_ids]
    assert [str(v.get_editor_property('imported_material_slot_name')) for v in c.static_mesh.static_materials]==['WarrensC_'+n+'_Mars_MI' for n in slot_ids]
    source_flags=controller.flags(c);assert source_flags['visible'] is True and source_flags['hidden_in_game'] is False and actor.get_editor_property('hidden') is False
    tf=c.get_instance_transform(index,world_space=True);assert (tf.translation-u.Vector(*at)).length()<.001 and (tf.scale3d-u.Vector(1,1,1)).length()<1e-6
    original=c.static_mesh;materials=list(c.get_materials());a=controller.mesh_actor(original,tf,materials,'WVC_Larder_Finish_'+role)
    for key in controller.FLAGS:
        if key in ('visible','hidden_in_game'):continue
        value=c.get_editor_property(key);a.static_mesh_component.set_editor_property(key,value.copy() if isinstance(value,u.StructBase) else value)
    assert controller.flags(a.static_mesh_component)==source_flags
    s['props'][role]=dict(source=c,index=index,count=count,transform=tf,original=original,materials=materials,actor=a,closed=False,source_flags=source_flags)
    assert c.remove_instance(index)
    expected=copy.deepcopy(s['before'][c.get_path_name()]);expected['instances']=expected['instances'][:-1];s['expected_hisms'][c.get_path_name()]=expected
    s['owned_expected']=[controller.owned(a) for a in s['created']];controller.check()
