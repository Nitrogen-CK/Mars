"""Recreate the reviewed Z lighting/fixture state in a fresh reversible trial."""
import json
def apply(trial):
    import unreal as u
    s=trial.STATE;assert s and s['stage']=='B_art_existing_lights'
    for family in ('floor','ceiling'):
        actor,=[a for a in s['created'] if a.get_actor_label()=='CP_TRIAL_'+family]
        assert actor.static_mesh_component.get_material(0).get_path_name().startswith(trial.DEST+'/Materials/M_CP_'+family.capitalize())
    trial.lighting(new_intensity=55,ambient_intensity=0)
    for row in s['source_lights']:
        if row['label']=='Warrens_Light_cold_19':row['component'].set_editor_property('light_color',row['color'])
    manifest=json.loads((trial.DOC/'geometry-r05/room_geometry.json').read_text())
    assert any(f['axis']==1 and f['normal_sign']==-1 and f['plane']==85 and f['tangent_bounds'][0]<=-8<=f['tangent_bounds'][1] for f in manifest['wall_faces'])
    fixture=json.loads((trial.DOC/'pilot-preview-r03/receipt.json').read_text())['fixture_art_delta'];s['fixture_art_delta_extra']=[]
    for c,start in s['fixture_components']:
        ident,=[v for v in ('CCS62','CCS60','CCS61','CCS64') if '_'+v+'_' in c.static_mesh.get_name()]
        row=dict(next(r for r in fixture if r['id']==ident and abs(r['at'][0]+19)<.01));row['at']=list(row['at']);row['at'][0]+=11
        t=u.Transform(location=u.Vector((row['at'][0]-70)*100,(row['at'][1]-55)*100,row['at'][2]*100),rotation=u.Rotator(pitch=0,yaw=row['yaw'],roll=0),scale=u.Vector(*row['scale']))
        n=c.get_instance_count();assert c.add_instance(t,world_space=True)==n;s['fixture_art_delta_extra'].append(row)
    spot=trial._spawn(u.SpotLight,u.Transform(location=u.Vector(-8800,2250,270),rotation=u.Rotator(pitch=-60,yaw=90,roll=0)))
    c,=spot.get_components_by_class(u.SpotLightComponent);c.set_editor_property('intensity_units',u.LightUnits.CANDELAS);c.set_intensity(80);c.set_attenuation_radius(1100);c.set_light_color(u.LinearColor(.82,.67,.48,1));c.set_outer_cone_angle(55);c.set_inner_cone_angle(25);c.set_editor_property('source_radius',50);spot.set_actor_label('CP_TRIAL_DirectedTombBounce')
    east=trial._spawn(u.PointLight,u.Transform(location=u.Vector(-7800,2975,170)));c=east.point_light_component;c.set_editor_property('intensity_units',u.LightUnits.CANDELAS);c.set_intensity(55);c.set_attenuation_radius(750);c.set_light_color(u.LinearColor(1,.66,.34,1));c.set_editor_property('source_radius',12);east.set_actor_label('CP_TRIAL_LIGHT_east_rear')
    _,after=s['core']._hism_snapshot(s['world']);assert len(after)==383 and sum(len(v['instances']) for v in after.values())==45452 and len(s['created'])==7
    s['stage']='C_complete_room_saved_materials'
    trial.VIEWS['omen']=([-2.5,77.3],[-3,79.5,1])
    result=dict(status='REVIEWED_COMPLETE_ROOM_STATE_RECREATED',created=[dict(label=a.get_actor_label(),path=a.get_path_name(),pose=s['core']._pose(a.get_actor_transform())) for a in s['created']],extra_fixture_rows=s['fixture_art_delta_extra'],source_hisms=383,current_instances=45452,original_instances=45440,guard_count=len(trial._guard()),boundary='Reversible PIE state; actual saved owned materials, no transient normal overrides. Omen supplementary viewpoint is through the authored Court entrance, not a Catacomb doorway. No source map save.')
    print('FINAL_ROOM_STATE',trial._write('trial_final_lighting_r02',result))
