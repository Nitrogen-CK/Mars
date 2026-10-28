"""Two reversible Catacomb ivory bindings in the accepted full-room trial."""
def views(trial):
    trial.VIEWS.update(urn_detail=([-22.5,70],[-23.66,70,.35]),bone_detail=([-15.25,66.7],[-15.25,65.24,.18]),
                       urn_standing=([-21.7,70],[-23.66,70,.35]),bone_standing=([-15.25,68],[-15.25,65.24,.18]))

def apply(trial):
    import unreal as u
    s=trial.STATE;assert s and s['stage']=='E_accepted_room_original_ivory'
    gate=trial.read(trial.DOC/'IVORY_PROP_TRIAL_GATE_R01.json');assert gate['status']=='APPROVED_FOR_TWO_PROP_OWNED_IVORY_TRIAL'
    assert len(s['prop_slots'])==2
    actors=u.GameplayStatics.get_all_actors_of_class(s['world'],u.Actor)
    result=[]
    for ident,name in (('WVC052','MI_CP_Bone_R01'),('WVC053','MI_CP_Urn_R01')):
        c,=[c for a in actors if 'LI_Warrens_Catacomb' in a.get_path_name() for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent) if ident in c.static_mesh.get_name()]
        assert c.get_instance_count()==1 and c.get_material(0).get_path_name().split('.')[0]=='/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX06'
        assert c.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION
        s['prop_slots'].append((c,0,c.get_material(0)));c.set_material(0,u.load_asset(trial.DEST+'/Materials/'+name))
        result.append(dict(component=c.get_path_name(),material=c.get_material(0).get_path_name(),instances=c.get_instance_count()))
    s['stage']='F_complete_room_ivory';trial._guard()
    print('TWO_OWNED_IVORY_BINDINGS',result)
