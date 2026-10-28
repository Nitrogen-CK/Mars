"""Read-only capture of the complete R09 stone/ivory/R02 forage room proposal."""
import hashlib,json,copy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def capture(trial):
    import unreal as u
    s=trial.STATE;assert s and u.GameplayStatics.is_game_paused(s['world'])
    assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    fit=json.loads((ROOT/'Tools/WarrensVariantCKit/Output/fitted_instances.json').read_text());pivot=fit['pivots']['Catacomb'];offset=[(pivot[0]-70)*100,(pivot[1]-55)*100,pivot[2]*100]
    def local_pose(actor):
        p=s['core']._pose(actor.get_actor_transform());p['at']=[a-b for a,b in zip(p['at'],offset)];return p
    actors=[]
    labels={'CP_TRIAL_walls':'WVC_Catacomb_Complete_Walls','CP_TRIAL_floor':'WVC_Catacomb_Complete_Floor','CP_TRIAL_ceiling':'WVC_Catacomb_Complete_Ceiling','CP_TRIAL_LIGHT_west':'WVC_Catacomb_Practical_West','CP_TRIAL_LIGHT_rear':'WVC_Catacomb_Practical_Rear','CP_TRIAL_LIGHT_east_rear':'WVC_Catacomb_Practical_EastRear','CP_TRIAL_DirectedTombBounce':'WVC_Catacomb_Tomb_Bounce'}
    assert len(s['created'])==7 and {a.get_actor_label() for a in s['created']}==set(labels)
    for a in s['created']:
        row=dict(label=labels[a.get_actor_label()],actor_class=a.get_class().get_path_name(),pose=local_pose(a))
        if isinstance(a,u.StaticMeshActor):
            c=a.static_mesh_component;assert c.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION
            row['mesh']=c.static_mesh.get_path_name().split('.')[0];row['materials']=[m.get_path_name().split('.')[0] for m in c.get_materials()];row['collision']='NoCollision';row['cast_shadow']=c.cast_shadow
        else:
            c,=a.get_components_by_class(u.PointLightComponent)
            assert c.get_editor_property('intensity_units')==u.LightUnits.CANDELAS
            row['light']=dict(intensity=c.intensity,units=str(c.get_editor_property('intensity_units')),radius=c.attenuation_radius,color_rgba=[c.light_color.r,c.light_color.g,c.light_color.b,c.light_color.a],source_radius=c.source_radius,source_length=c.source_length,soft_source_radius=c.soft_source_radius,inverse_squared=c.use_inverse_squared_falloff,cast_shadows=c.cast_shadows)
            if isinstance(c,u.SpotLightComponent):row['light'].update(inner_cone=c.inner_cone_angle,outer_cone=c.outer_cone_angle)
        actors.append(row)
    append=[]
    for c,start in s['fixture_components']:
        assert start==2 and c.get_instance_count()==5 and c.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION
        append.append(dict(actor_label=c.get_owner().get_actor_label(),component_name=c.get_name(),mesh=c.static_mesh.get_path_name().split('.')[0],before_count=start,add_local_poses=[s['core']._pose(c.get_instance_transform(i,world_space=False)) for i in range(start,c.get_instance_count())]))
    bindings=[dict(actor_label=c.get_owner().get_actor_label(),mesh=c.static_mesh.get_path_name().split('.')[0],slot=i,before=old.get_path_name().split('.')[0],after=c.get_material(i).get_path_name().split('.')[0],instance_count=c.get_instance_count()) for c,i,old in s['prop_slots']]
    lights=[dict(actor_label=r['label'],before=r['intensity'],after=r['component'].intensity,color_before=r['color'].export_text(),color_after=r['component'].light_color.export_text()) for r in s['source_lights'] if r['component'].intensity!=r['intensity']]
    assert len(append)==4 and len(bindings)==4 and len(lights)==3
    assert all('/PBR_R09/Materials/' in row['materials'][0] for row in actors if 'mesh' in row)
    assert sum('/PBR_R09/Materials/' in row['after'] for row in bindings)==2
    assert sum('/Materials/MI_CP_' in row['after'] and any(k in row['after'] for k in ('Bone_R01','Urn_R01')) for row in bindings)==2
    for c,start in s['fixture_components']:
        root=c.get_owner().get_actor_location();assert (root-u.Vector(*offset)).length()<.1,root
    _,current_hisms=s['core']._hism_snapshot(s['world'])
    restored_hisms=copy.deepcopy(current_hisms)
    assert len(current_hisms)==383 and sum(len(v['instances']) for v in current_hisms.values())==45452
    for c,start in s['fixture_components']:
        assert len(restored_hisms[c.get_path_name()]['instances'])==start+3
        restored_hisms[c.get_path_name()]['instances']=restored_hisms[c.get_path_name()]['instances'][:start]
    assert len(s['prop_slots'])==4
    for c,slot,original in s['prop_slots']:
        assert restored_hisms[c.get_path_name()]['materials'][slot]==c.get_material(slot).get_path_name().split('.')[0]
        restored_hisms[c.get_path_name()]['materials'][slot]=original.get_path_name().split('.')[0]
    assert restored_hisms==s['before'],'Original HISM state changed beyond12tracked appends and4tracked material slots'
    assert sum(len(v['instances']) for v in restored_hisms.values())==45440
    assert all(r['component'].light_color==r['color'] for r in s['source_lights']),'Source light color changed'
    source_file='Content/Mars/Maps/Variants/v8c/LI_Warrens_Catacomb.umap';guards=trial._guard();assert guards[source_file]==sha(ROOT/source_file)
    result=dict(status='EXACT_ACCEPTED_ROOM_DELTA_RETENTION_PROPOSAL_NOT_RELEASED',source_map='/Game/Mars/Maps/Variants/v8c/LI_Warrens_Catacomb',source_map_file=source_file,source_map_sha256_before=sha(ROOT/source_file),source_pivot_plan_metres=pivot,source_main_offset_cm=offset,owner='Mars.WarrensVariantC.Catacomb.CompleteRoom',folder='WarrensC/Art/CatacombCompleteRoom',new_actors=actors,append_hism_instances=append,material_bindings=bindings,source_light_intensities=lights,candidate_assets_receipt=dict(file='Saved/WarrensCGameplay-20261024/CatacombPilot/candidate_assets_timber_r13.json',sha256=sha(trial.RUN/'candidate_assets_timber_r13.json')),appearance_review=dict(status='FULL_ROOM_ACCEPTANCE_REQUIRED_BEFORE_SOURCE_SAVE',stone_review='lookdev/catacomb-shape-pbr-r03/NATIVE_R09_ENVELOPE_AND_FORAGE_REVIEW.md',timber_review='lookdev/catacomb-forage-props-r04/TIMBER_ART_REVIEW_R12.md'),manifest_sha256=sha(DOC/'geometry-r05/room_geometry.json'),protected_guards=guards,all_original_instance_poses_preserved=sum(len(v['instances']) for v in restored_hisms.values()),reviewed_fixture_instance_additions=12,allowed_source_changes='Only this source LI: 7 new actors (3 NoCollision static meshes, 3 point lights, 1 directed spot), append12 existing kit fixture instances, four tomb/lid/bone/urn slot bindings plus R01-to-R02 forage profile reference and three existing light intensities. No original instance removal/reorder/pose or collision changes.',boundary='Proposal captured from actual accepted PIE state; source staging/save and original library sync remain gated. Omen supplementary envelope geometry exists on the Court side; no Court gameplay actor/door change permitted.')
    result['forage_profile']={'source_actor_guid':'C0A9DC4E470DF98E780207AF46D150D9','before':trial.DEST+'/Forage_R04/DA_CP_ForagePresentation_R01','after':trial.DEST+'/Forage_R04/Timber_R02/DA_CP_ForagePresentation_R02','boundary':'One existing source archetype reference only; synthetic review fixture is never retained.'}
    result['runtime_trial_role']=trial.PROFILE_CONTROLLER.STATE['active']['role']
    result['boundary']+=' No synthetic review owner/entity/fixture is retained. Current source profile reference remains R01 until a separate exact source gate.'
    out=DOC/'SOURCE_RETENTION_MANIFEST_R15.json';assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n');print('EXACT_ROOM_RETENTION_PROPOSAL',sha(out))
