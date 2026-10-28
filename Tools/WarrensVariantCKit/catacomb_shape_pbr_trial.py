"""Bounded saved-material and isolated normal/roughness comparison in real PIE."""
import json
def install(trial,assets):
    import unreal as u
    s=trial.STATE;assert s and s['stage']=='F_complete_room_ivory' and len(s['prop_slots'])==4
    rows=[]
    for family in ('Walls','Floor','Ceiling'):
        actor,=[a for a in s['created'] if a.get_actor_label()=='CP_TRIAL_'+family.lower()]
        c=actor.static_mesh_component;assert c.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION
        parent=u.load_asset(assets.DEST+'/Materials/M_CP_'+family+'_PBR_'+getattr(assets,'VERSION','R08'));assert parent
        c.set_material(0,parent);rows.append(dict(component=c,slot=0,parent=parent,family=family))
    for c,i,old in s['prop_slots']:
        name=c.static_mesh.get_name()
        if 'WVC026' in name:family='Prop';p=assets.DEST+'/Materials/M_CP_Prop_PBR_'+getattr(assets,'VERSION','R08')
        elif 'WVC081' in name:family='Prop';p=assets.DEST+'/Materials/MI_CP_PropLid_PBR_'+getattr(assets,'VERSION','R08')
        else:continue
        parent=u.load_asset(p);assert parent;c.set_material(i,parent);rows.append(dict(component=c,slot=i,parent=parent,family=family))
    assert len(rows)==5
    for r in rows:
        r['mid']=r['component'].create_dynamic_material_instance(r['slot']);assert isinstance(r['mid'],u.MaterialInstanceDynamic)
        assert r['mid'].get_editor_property('parent')==r['parent']
    s['pbr_rows']=rows;s['pbr_settings']=assets.SETTINGS;s['stage']='PBR_A_CleanAlbedoOnly'
    trial.VIEWS.update(wall_grazing=([-22,74],[-23.8,75.4,1.4]),floor_grazing=([-22,74],[-21.3,76.5,.02]),ceiling_grazing=([-22,74],[-20.5,76.5,3.4]))
    mode(trial,'A')
    print('SAVED_PBR_PARENTS_INSTALLED',[(r['family'],r['parent'].get_path_name()) for r in rows])
def _lamp(trial):
    import unreal as u
    s=trial.STATE;p=s['pawn']
    lamp,=[c for a in u.GameplayStatics.get_all_actors_of_class(s['world'],u.Actor) if 'Ck_UnrealComponent_Host' in a.get_name() for c in a.get_components_by_class(u.PointLightComponent) if (c.get_world_location()-p.get_actor_location()).length()<250 and c.is_visible() and c.intensity>0 and c.attenuation_radius==700]
    return lamp
def signature(trial):
    import unreal as u
    s=trial.STATE;camera=u.GameplayStatics.get_player_camera_manager(s['world'],0);lamp=_lamp(trial)
    return dict(pawn=list(s['pawn'].get_actor_location().to_tuple()),camera=list(camera.get_camera_location().to_tuple()),rotation=list(camera.get_camera_rotation().to_tuple()),fov=camera.get_fov_angle(),
        lamp_transform=s['core']._pose(lamp.get_world_transform()),lamp_intensity=lamp.intensity,lamp_color=[lamp.light_color.r,lamp.light_color.g,lamp.light_color.b,lamp.light_color.a])
def prepare(trial,view):
    import unreal as u
    assert view in trial.VIEWS
    u.GameplayStatics.set_game_paused(trial.STATE['world'],False);trial.position(view)
    trial.STATE.pop('pbr_pair_signature',None)
def pause_pair(trial):
    import unreal as u
    s=trial.STATE;assert not u.GameplayStatics.is_game_paused(s['world'])
    assert u.GameplayStatics.set_game_paused(s['world'],True)
    s['pbr_pair_signature']=signature(trial);print('PBR_COMPARISON_PAUSED',json.dumps(s['pbr_pair_signature']))
def mode(trial,stage):
    import unreal as u
    s=trial.STATE;assert s and stage in ('A','N','NR','SAVED')
    for r in s['pbr_rows']:
        if stage=='SAVED':r['component'].set_material(r['slot'],r['parent'])
        else:
            r['component'].set_material(r['slot'],r['mid']);conf=s['pbr_settings'][r['family']]
            r['mid'].set_scalar_parameter_value('NormalStrength',0 if stage=='A' else conf['normal'])
            r['mid'].set_scalar_parameter_value('RoughnessBlend',conf['rough'] if stage=='NR' else 0)
    s['stage']={'A':'PBR_A_CleanAlbedoOnly','N':'PBR_N_NormalOnly','NR':'PBR_NR_NormalRoughness','SAVED':'PBR_SavedCompleteRoom'}[stage]
def capture(trial):
    import unreal as u
    s=trial.STATE;assert u.GameplayStatics.is_game_paused(s['world'])
    before=signature(trial);assert before==s['pbr_pair_signature'],('Paused real camera/light changed',before,s['pbr_pair_signature'])
    trial.capture()
    path=trial.OUT/(s['stage']+'_'+s['view']+'.json');r=trial.read(path)
    r.update(simulation_paused_for_still=True,exact_comparison_signature=before,normal_roughness_mode=s['stage'],normal_roughness_saved_parents=[dict(family=v['family'],path=v['parent'].get_path_name()) for v in s['pbr_rows']])
    path.write_text(json.dumps(r,indent=2)+'\n');print('PBR_EXACT_POSE_AND_REAL_LIGHT_CAPTURE',s['stage'],s['view'])
