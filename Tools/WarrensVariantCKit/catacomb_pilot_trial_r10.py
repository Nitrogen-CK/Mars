"""PIE-only Catacomb art trial; explicit capture/restore, never saves an editor map."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02'
OUT=DOC.parent/'catacomb-forage-props-r04/native-room-r10';DEST='/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02'
OWNER='Mars.WarrensVariantC.CatacombPilot.R02.Trial';STATE=None;RUN_SUFFIX='r10';PROFILE_CONTROLLER=None
VIEWS={'standing':([-22,74],[-18,80,1]),'ceiling':([-22,74],[-16.5,81,3.4]),
       'reverse':([-14,84],[-22,73,1.2]),'tomb':([-19.2,78.5],[-18,80,.8]),
       'husk':([-23,74],[-26,74,1]),'cache':([-13,85],[-8.5,88,.9]),'omen':([-6,78],[-3,79,1])}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
LOADED_TOOL_SHA256=sha(__file__)
def _u():import unreal;return unreal
def _world():
    u=_u();w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world();assert w and 'UEDPIE_0_Warrens_VariantC_Mars_MAP' in w.get_path_name();return w
def _guard():
    assert PROFILE_CONTROLLER and PROFILE_CONTROLLER.STATE and PROFILE_CONTROLLER.STATE['protected']
    return PROFILE_CONTROLLER.guard()

def _clean():
    return PROFILE_CONTROLLER.assert_dirty_scope()

def _write(name,data):
    if RUN_SUFFIX!='r02':name=name.removesuffix('_r02')+'_'+RUN_SUFFIX
    out=RUN/(name+'.json');assert not out.exists();out.write_text(json.dumps(data,indent=2)+'\n');return sha(out)
def begin(core,helper,profile_controller):
    global STATE,PROFILE_CONTROLLER
    u=_u();assert STATE is None;w=_world();PROFILE_CONTROLLER=profile_controller
    assert PROFILE_CONTROLLER.STATE['runtime_verified'];_clean();_guard()
    gate_path=DOC.parent/'catacomb-forage-props-r04/NATIVE_ROOM_TRIAL_GATE_R10.json';gate=read(gate_path)
    assert gate['status']=='APPROVED_FOR_REVERSIBLE_COMPLETE_ROOM_TRIAL' and gate['room_helper_sha256']==LOADED_TOOL_SHA256==sha(__file__)
    assert gate['asset_inventory_sha256']==sha(RUN/'candidate_assets_forage_r04.json')
    assets=read(RUN/'candidate_assets_forage_r04.json');assert assets['status']=='THIRTYSIX_OWNED_NATIVE_PILOT_ASSETS_CREATED_AND_READ_BACK' and len(assets['assets'])==36
    for p,r in assets['assets'].items():assert sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset'))==r['package_sha256']
    pawn=u.GameplayStatics.get_player_pawn(w,0);assert 'pack=true' in helper.inspect(pawn).splitlines()[0] and 'Item (Mars_ItemDef_Lantern)' in helper.inspect(pawn).splitlines()[0]
    actors,before=core._hism_snapshot(w);lights=[]
    for a in actors:
        if 'LI_Warrens_Catacomb' not in a.get_path_name():continue
        for c in a.get_components_by_class(u.PointLightComponent):lights.append(dict(component=c,color=c.light_color,intensity=c.intensity,visible=c.is_visible(),label=a.get_actor_label()))
    assert len(lights)==4
    STATE=dict(world=w,core=core,helper=helper,pawn=pawn,before=before,source_lights=lights,created=[],fixture_components=[],prop_slots=[],stage='A_source',captures=[],guards=_guard())
    OUT.mkdir(exist_ok=False)
    result=dict(world=w.get_path_name(),hisms=before,lights=[dict(path=l['component'].get_path_name(),color=l['color'].export_text(),intensity=l['intensity'],visible=l['visible'],label=l['label']) for l in lights],
        assets_receipt_sha256=sha(RUN/'candidate_assets_forage_r04.json'),gate_sha256=sha(gate_path),guards=STATE['guards'],boundary='PIE-only room baseline; one independently guarded TEMP-clone presentation override, no original map mutation/save.')
    print('PILOT_PIE_BASELINE',len(before),sum(len(v['instances']) for v in before.values()),_write('trial_baseline_r02',result));return 'A_source'
def position(name):
    u=_u();s=STATE;assert s and _world()==s['world'];at,target=VIEWS[name];pawn=s['pawn'];helper=s['helper']
    p=u.Vector((at[0]-70)*100,(at[1]-55)*100,77.2);assert pawn.teleport(p,u.Rotator())
    eye=u.Vector(p.x,p.y,p.z+34.8);t=u.Vector((target[0]-70)*100,(target[1]-55)*100,target[2]*100)
    assert helper.aim(pawn,u.MathLibrary.find_look_at_rotation(eye,t));s['view']=name;print('PILOT_POSITION',s['stage'],name,list(p.to_tuple()))
def capture():
    u=_u();s=STATE;assert s and _world()==s['world'];name=s['view'];camera=u.GameplayStatics.get_player_camera_manager(s['world'],0);pawn=s['pawn'];inventory=s['helper'].inspect(pawn).splitlines()[0]
    assert 'pack=true' in inventory and 'Item (Mars_ItemDef_Lantern)' in inventory and abs(camera.get_fov_angle()-90)<.01
    at,_=VIEWS[name];assert (pawn.get_actor_location()-u.Vector((at[0]-70)*100,(at[1]-55)*100,77.2)).length()<2
    lamps=[c for a in u.GameplayStatics.get_all_actors_of_class(s['world'],u.Actor) if 'Ck_UnrealComponent_Host' in a.get_name() for c in a.get_components_by_class(u.PointLightComponent) if (c.get_world_location()-pawn.get_actor_location()).length()<250 and c.is_visible() and c.intensity>0 and c.attenuation_radius==700]
    lamp,=lamps;path=OUT/(s['stage']+'_'+name+'.png');assert not path.exists()
    record=dict(stage=s['stage'],view=name,world=s['world'].get_path_name(),pawn=list(pawn.get_actor_location().to_tuple()),camera=list(camera.get_camera_location().to_tuple()),rotation_roll_pitch_yaw=list(camera.get_camera_rotation().to_tuple()),fov=camera.get_fov_angle(),
        inventory=inventory,held_light=dict(path=lamp.get_path_name(),at=list(lamp.get_world_location().to_tuple()),intensity=lamp.intensity,radius=lamp.attenuation_radius),
        boundary='Actual possessed packed pawn and real picked-up/opened lantern. Isolated teleported viewing positions, no fabricated inventory or proxy lights. View/traversal evidence is separately recorded; not a played expedition or duration/co-op proof.')
    path.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n');s['captures'].append(path)
    u.AutomationLibrary.take_high_res_screenshot(1600,1000,str(path),delay=.2);print('PILOT_CAPTURE_QUEUED',path.name)
def _spawn(cls,transform):
    """The engine's native Summon exec is exposed through the PIE controller;
    the Blueprint-internal deferred-spawn functions are not Python bindings.
    Verify the exact new actor/world and track it before configuring anything.
    """
    u=_u();s=STATE;before={a.get_path_name() for a in u.GameplayStatics.get_all_actors_of_class(s['world'],cls)}
    command='Summon '+cls.static_class().get_path_name()
    u.SystemLibrary.execute_console_command(s['world'],command,u.GameplayStatics.get_player_controller(s['world'],0))
    actor,=[a for a in u.GameplayStatics.get_all_actors_of_class(s['world'],cls) if a.get_path_name() not in before]
    s['created'].append(actor);assert actor.get_world()==s['world'];actor.tags=[u.Name(OWNER)]
    if isinstance(actor,u.StaticMeshActor):
        actor.static_mesh_component.set_collision_profile_name('NoCollision');actor.static_mesh_component.set_collision_enabled(u.CollisionEnabled.NO_COLLISION)
        actor.static_mesh_component.set_mobility(u.ComponentMobility.MOVABLE)
    actor.root_component.set_mobility(u.ComponentMobility.MOVABLE)
    actor.set_actor_transform(transform,False,True)
    assert (actor.get_actor_location()-transform.translation).length()<.1
    return actor
def stage():
    u=_u();s=STATE;assert s and s['stage']=='A_source' and _world()==s['world'];core=s['core'];_,actual=core._hism_snapshot(s['world']);assert actual==s['before'];_guard()
    export=read(DOC/'export-r03/audit_export.json');actors=u.GameplayStatics.get_all_actors_of_class(s['world'],u.Actor)
    # All original source instances remain: a shallow continuous new backing
    # covers the old skin. No original HISM removal, broad hide or pose change.
    assert len(s['created']) in (0,1)
    for index,row in enumerate(export['exports']):
        transform=u.Transform(location=u.Vector(*row['placement_main_cm']))
        if index==0 and len(s['created'])==1:
            actor=s['created'][0];assert isinstance(actor,u.StaticMeshActor) and actor.static_mesh_component.static_mesh is None and OWNER in [str(t) for t in actor.tags]
            actor.set_actor_transform(transform,False,True)
        else:actor=_spawn(u.StaticMeshActor,transform)
        component=actor.static_mesh_component;component.set_static_mesh(u.load_asset(DEST+'/Meshes/'+row['name']));component.set_collision_profile_name('NoCollision');component.set_collision_enabled(u.CollisionEnabled.NO_COLLISION)
        actor.set_actor_label('CP_TRIAL_'+row['kind'])
        assert actor.get_world()==s['world'] and component.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION
    for ident,mat in (('WVC026','M_CP_Prop_R02'),('WVC081','MI_CP_PropLid_R02')):
        matches=[c for a in actors if 'LI_Warrens_Catacomb' in a.get_path_name() for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent) if ident in c.static_mesh.get_name()]
        c,=matches;assert c.get_instance_count()==1;s['prop_slots'].append((c,0,c.get_material(0)));c.set_material(0,u.load_asset(DEST+'/Materials/'+mat))
    fixture=read(DOC/'pilot-preview-r03/receipt.json')['fixture_art_delta']
    for ident in ('CCS62','CCS60','CCS61','CCS64'):
        matches=[c for a in actors if 'LI_Warrens_Catacomb' in a.get_path_name() for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent) if ('_'+ident+'_') in c.static_mesh.get_name()]
        c,=matches;start=c.get_instance_count();s['fixture_components'].append((c,start))
        for row in [r for r in fixture if r['id']==ident]:
            t=u.Transform(location=u.Vector((row['at'][0]-70)*100,(row['at'][1]-55)*100,row['at'][2]*100),rotation=u.Rotator(pitch=0,yaw=row['yaw'],roll=0),scale=u.Vector(*row['scale']))
            assert c.add_instance(t,world_space=True)==c.get_instance_count()-1
        assert c.get_instance_count()==start+2 and c.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION
    s['stage']='B_art_existing_lights';assert len(s['created'])==3 and len(s['prop_slots'])==2 and len(s['fixture_components'])==4
    _,after=core._hism_snapshot(s['world']);assert len(after)==len(s['before']) and sum(len(v['instances']) for v in after.values())==45448
    result=dict(stage=s['stage'],created_mesh_actors=[a.get_path_name() for a in s['created']],prop_slots=[dict(component=c.get_path_name(),slot=i,original=m.get_path_name(),candidate=c.get_material(i).get_path_name()) for c,i,m in s['prop_slots']],fixture_groups=[dict(component=c.get_path_name(),original_count=n,current_count=c.get_instance_count()) for c,n in s['fixture_components']],guard_count=len(_guard()),boundary='Only PIE objects; all original instances remain, original source poses/collision untouched.')
    print('PILOT_ART_STAGED',_write('trial_art_staged_r02',result));return s['stage']
def lighting(new_intensity=55,ambient_intensity=65):
    u=_u();s=STATE;assert s and s['stage']=='B_art_existing_lights'
    for l in s['source_lights']:
        if l['label']=='Warrens_Light_cold_19':l['component'].set_intensity(ambient_intensity);l['component'].set_light_color(u.LinearColor(.82,.76,.63,1))
        elif l['label'].startswith('WVC_Practical_'):l['component'].set_intensity(35)
    for label,at in [('west',[-23.75,79,1.7]),('rear',[-19,84.75,1.7])]:
        t=u.Transform(location=u.Vector((at[0]-70)*100,(at[1]-55)*100,at[2]*100));actor=_spawn(u.PointLight,t)
        c=actor.point_light_component;c.set_mobility(u.ComponentMobility.MOVABLE);c.set_editor_property('intensity_units',u.LightUnits.CANDELAS);c.set_intensity(new_intensity);c.set_attenuation_radius(650);c.set_light_color(u.LinearColor(1,.66,.34,1));c.set_editor_property('source_radius',12)
        actor.set_actor_label('CP_TRIAL_LIGHT_'+label)
    s['stage']='C_local_warm_lights';print('PILOT_LOCAL_LIGHTS',new_intensity,ambient_intensity);return s['stage']
def finish(pending_owned_materials=()):
    u=_u();s=STATE;assert s and _world()==s['world']
    for row in s.get('source_light_extra',[]):
        row['actor'].set_actor_transform(row['transform'],False,True)
        row['component'].set_editor_property('source_radius',row['source_radius'])
        row['component'].set_mobility(row['mobility'])
        assert (row['actor'].get_actor_location()-row['transform'].translation).length()<.1
    for c,i,m in s['prop_slots']:c.set_material(i,m)
    for c,n in s['fixture_components']:
        for i in range(c.get_instance_count()-1,n-1,-1):assert c.remove_instance(i)
        assert c.get_instance_count()==n
    for l in s['source_lights']:
        c=l['component'];c.set_intensity(l['intensity']);c.set_editor_property('light_color',l['color']);c.set_visibility(l['visible'])
    for actor in reversed(s['created']):actor.destroy_actor()
    _,actual=s['core']._hism_snapshot(s['world']);assert actual==s['before'],'Original runtime HISM roster differs after restoration'
    assert all(l['component'].intensity==l['intensity'] and l['component'].light_color==l['color'] and l['component'].is_visible()==l['visible'] for l in s['source_lights'])
    _clean()
    pending=set(pending_owned_materials)
    if pending:
        assert pending=={DEST+'/Materials/M_CP_Floor_R02',DEST+'/Materials/M_CP_Ceiling_R02'}
        assert sha(DOC/'NORMAL_MATERIAL_TRIAL_GATE_R01.json')=='179d19dc44348e6c74f4670cf5f6461aa6aa9c08a570ebdbe0e9240e468298d9'
    assert {p.get_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()}==pending;_guard()
    frames=[]
    for p in s['captures']:
        assert p.exists() and p.stat().st_size>1000;r=read(p.with_suffix('.json'));r['image_sha256']=sha(p);p.with_suffix('.json').write_text(json.dumps(r,indent=2)+'\n');frames.append(dict(file=p.relative_to(ROOT).as_posix(),sha256=sha(p),metadata_sha256=sha(p.with_suffix('.json'))))
    s['stage']='RESTORED';result=dict(status='EXACT_ORIGINAL_PIE_HISMS_AND_LIGHTS_RESTORED',hism_count=len(actual),instance_count=sum(len(v['instances']) for v in actual.values()),frames=frames,guard_count=len(_guard()),pending_owned_materials=sorted(pending),boundary='No source map save, original mesh/material or collision-file changes. Only explicitly gated owned material edits may remain pending editor-mode compiler inspection/save, because Unreal asset-library operations refuse PIE. Actual result still needs independent review.')
    print('PILOT_TRIAL_RESTORED',_write('trial_restored_r02',result));return result['status']
