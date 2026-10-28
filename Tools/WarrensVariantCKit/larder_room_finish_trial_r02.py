"""Disposable Main PIE room finish; finite material/mesh axes, no source saves.

Fixed decorative tails are replaced only inside this PIE. No shared material,
gameplay jar, anchor, water transform, collision or original light is edited.
"""
import copy,hashlib,importlib.util,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
RUN=ROOT/'Saved/WarrensCGameplay-20261024/LarderRollout/finish_room_trial_r02'
DEST='/Game/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01'
OWNER='Mars.WarrensVariantC.Larder.CompleteFinishTrial.R02'
PROPS={'barrel':('WVC_CCS66',4,5,[3959.,-1250.,-249.2]),'sack':('WVC_CCS68',8,9,[5725.,-2251.,-249.2]),'jar':('WVC_WVC048',2,3,[5650.,-636.5,-249.2])}
PROP_MESHES={'barrel':'/Game/Mars/Environment/ChainCrossingKit/Meshes/WarrensC_CCS66_BrineBarrel_Mars_SM','sack':'/Game/Mars/Environment/ChainCrossingKit/Meshes/WarrensC_CCS68_ClothSack_Mars_SM','jar':'/Game/Mars/Environment/WarrensVariantCKit/Meshes/WarrensC_WVC048_OliveStorageJar_Mars_SM'}
PROP_SLOTS={'barrel':(['TX08','TX09','TX07'],['DarkTimber','BlackIron','OakPlank']),'sack':(['TX12','TX14'],['LinenCanvas','RopeFibre']),'jar':(['TX15'],['OliveCeramic'])}
FLAGS=['cast_shadow','cast_dynamic_shadow','cast_static_shadow','cast_hidden_shadow','cast_inset_shadow','affect_dynamic_indirect_lighting','affect_distance_field_lighting','receives_decals','render_in_main_pass','render_in_depth_pass','render_custom_depth','owner_no_see','only_owner_see','lighting_channels','visible','hidden_in_game']
PAINT={'barrel':dict(base=(.18,.085,.035,1),tint=(1.,.85,.65,1),mix=.18),'sack':dict(base=(.25,.18,.085,1),tint=(1.,.9,.7,1),mix=.14),'jar':dict(base=(.08,.11,.035,1),tint=(.9,1.,.7,1),mix=.15)}
STATE=None

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def load(name):
    spec=importlib.util.spec_from_file_location('_finish_'+name,Path(__file__).with_name(name+'.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def flags(component):
    import unreal as u
    return {k:(v.export_text() if isinstance(v,u.StructBase) else v) for k in FLAGS for v in [component.get_editor_property(k)]}

def guard():
    s=STATE;gate=s['gate'] if s else json.loads((DOC/'NATIVE_ROOM_FINISH_GATE_R02.json').read_text())
    for path,digest in gate['helper_sha256'].items():assert sha(ROOT/path)==digest,path
    m=load('larder_surface_pie_trial_r04');m.guard();m.clean()
    ledger=json.loads((ROOT/'Saved/WarrensCGameplay-20261024/LarderRollout/closed_jar_mesh_asset_r01.json').read_text());assert len(ledger['assets'])==1
    for path,row in ledger['assets'].items():assert sha(ROOT/('Content/'+path.removeprefix('/Game/')+'.uasset'))==row['package_sha256']
    corrective=json.loads((ROOT/'Saved/WarrensCGameplay-20261024/LarderRollout/corrective_assets_r01.json').read_text());assert len(corrective['assets'])==2
    for path,row in corrective['assets'].items():assert sha(ROOT/('Content/'+path.removeprefix('/Game/')+'.uasset'))==row['package_sha256']

def owned(a):
    import unreal as u
    s=STATE;r=dict(path=a.get_path_name(),pose=s['core']._pose(a.get_actor_transform()),tag=list(map(str,a.tags)))
    if isinstance(a,u.StaticMeshActor):
        c=a.static_mesh_component;r.update(mesh=c.static_mesh.get_path_name(),materials=[m.get_path_name() for m in c.get_materials()],collision=str(c.get_collision_enabled()),profile=str(c.get_collision_profile_name()),visible=c.is_visible(),hidden=c.get_editor_property('hidden_in_game'),shadow=c.cast_shadow,mobility=str(c.mobility),lighting_flags=flags(c))
    else:
        c,=a.get_components_by_class(u.RectLightComponent);r.update(intensity=c.intensity,units=str(c.intensity_units),width=c.source_width,height=c.source_height,radius=c.attenuation_radius,rgba=[c.light_color.r,c.light_color.g,c.light_color.b,c.light_color.a],shadow=c.cast_shadows,visible=c.is_visible(),mobility=str(c.mobility),temperature=c.get_editor_property('use_temperature'),barn_angle=c.barn_door_angle,barn_length=c.barn_door_length)
    return r

def check():
    import unreal as u
    s=STATE;assert s and s['stage']=='ready' and s['world']==u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() and u.GameplayStatics.is_game_paused(s['world'])
    assert sha(__file__)==s['gate']['tool_sha256'];guard()
    _,actual=s['core']._hism_snapshot(s['world']);assert actual==s['expected_hisms']
    assert s['light_reader'].lights(s['world'])==s['source_lights']
    assert [owned(a) for a in s['created']]==s['owned_expected']
    for r in s['props'].values():assert flags(r['source'])==r['source_flags'] and r['source'].get_owner().get_editor_property('hidden') is False
    if s['water_mid']:
        assert s['water_component'].get_material(0)==s['water_mid'] and s['water_mid'].get_editor_property('parent')==s['water_parent_active']
        assert abs(s['water_mid'].get_scalar_parameter_value('BrineRoughness')-s['water_rough'])<1e-6
        assert max(abs(a-b) for a,b in zip(s['water_mid'].get_vector_parameter_value('BrineColour').to_tuple(),s['water_colour']))<1e-6
    for role,mid in s['paint_mids'].items():
        for key,value in {'WorldTileCm':80.,'NormalStrength':.15,'RoughnessBlend':.2,'PigmentMix':PAINT[role]['mix']}.items():assert abs(mid.get_scalar_parameter_value(key)-value)<1e-6
        for key,value in [('BaseColour',PAINT[role]['base']),('PigmentTint',PAINT[role]['tint'])]:assert max(abs(a-b) for a,b in zip(mid.get_vector_parameter_value(key).to_tuple(),value))<1e-6

def spawn(cls):
    import unreal as u
    s=STATE;before={a.get_path_name() for a in u.GameplayStatics.get_all_actors_of_class(s['world'],cls)}
    u.SystemLibrary.execute_console_command(s['world'],'Summon /Script/Engine.'+cls.static_class().get_name(),u.GameplayStatics.get_player_controller(s['world'],0))
    actor,=[a for a in u.GameplayStatics.get_all_actors_of_class(s['world'],cls) if a.get_path_name() not in before];s['created'].append(actor);actor.tags=[u.Name(OWNER)];return actor

def mesh_actor(mesh,transform,materials,label):
    import unreal as u
    a=spawn(u.StaticMeshActor);c=a.static_mesh_component;c.set_mobility(u.ComponentMobility.MOVABLE);c.set_collision_profile_name('NoCollision');c.set_collision_enabled(u.CollisionEnabled.NO_COLLISION);c.set_editor_property('generate_overlap_events',False)
    assert c.set_static_mesh(mesh)
    for i,m in enumerate(materials):c.set_material(i,m)
    a.set_actor_transform(transform,False,True);a.set_actor_label(label);c.set_visibility(True,False);c.set_hidden_in_game(False,False)
    assert STATE['core']._pose(a.get_actor_transform())==STATE['core']._pose(transform)
    return a

def begin(core,capture,world_painterly,brine):
    import unreal as u
    global STATE
    assert STATE is None and Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve()
    gate=json.loads((DOC/'NATIVE_ROOM_FINISH_GATE_R02.json').read_text());assert gate['status']=='APPROVED_DISPOSABLE_FINITE_LARDER_CORRECTION_TRIAL_ONLY' and gate['tool_sha256']==sha(__file__)
    for path,digest in gate['input_sha256'].items():assert sha(ROOT/path)==digest
    guard();w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world();assert w and w.get_path_name()=='/Game/Mars/Maps/UEDPIE_0_Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP' and capture.STATE['world']==w and u.GameplayStatics.is_game_paused(w)
    assert not RUN.exists();RUN.mkdir()
    for mat in [world_painterly,brine]:assert isinstance(mat,u.Material) and mat.get_outer().get_path_name()=='/Engine/Transient'
    identity=ROOT/gate['transient_identity_file'];assert sha(identity)==gate['transient_identity_sha256'];expected_identity=json.loads(identity.read_text());reader_props=load('catacomb_plane_normal_materials')
    for role,mat in [('world_painterly',world_painterly),('brine',brine)]:
        assert mat.get_path_name()==expected_identity[role]['path'] and reader_props.snapshot(mat)==expected_identity[role]['snapshot']
        stats=u.MaterialEditingLibrary.get_statistics(mat);assert stats.num_pixel_shader_instructions>0 and stats.num_vertex_shader_instructions>0
    mel=u.MaterialEditingLibrary
    for mat,scalars,vectors in [(world_painterly,{'WorldTileCm':180.,'NormalStrength':.6,'RoughnessBlend':.65,'PigmentMix':.45},{'BaseColour':(.2,.18,.14,1.),'PigmentTint':(.95,.92,.86,1.)}),(brine,{'BrineRoughness':.24},{'BrineColour':(.055,.12,.095,1.)})]:
        assert set(map(str,mel.get_scalar_parameter_names(mat)))==set(scalars) and set(map(str,mel.get_vector_parameter_names(mat)))==set(vectors)
        for key,value in scalars.items():assert abs(mel.get_material_default_scalar_parameter_value(mat,key)-value)<1e-6
        for key,value in vectors.items():assert max(abs(a-b) for a,b in zip(mel.get_material_default_vector_parameter_value(mat,key).to_tuple(),value))<1e-6
    sample=u.MaterialEditingLibrary.get_material_property_input_node(brine,u.MaterialProperty.MP_NORMAL);assert sample.get_editor_property('const_coordinate')==0
    _,before=core._hism_snapshot(w);reader=load('larder_finish_diagnostics_r01')
    STATE=dict(world=w,core=core,capture=capture,gate=gate,before=before,expected_hisms=copy.deepcopy(before),created=[],owned_expected=[],props={},paint_mids={},world_painterly=world_painterly,brine=brine,water_parent_active=brine,water_mid=None,water_component=None,water_original=None,water_rough=.23999999463558197,water_colour=(.054999999701976776,.11999999731779099,.0949999988079071,1.),light_reader=reader,source_lights=reader.lights(w),stage='preparing')
    try:
        export=json.loads((DOC/'export-r03/export.json').read_text())
        for row in export['exports']:
            name='WVC_Larder_Walls_R02_SM' if row['family']=='walls' else row['name'];mesh=u.load_asset(DEST+'/Meshes/'+name)
            mesh_actor(mesh,u.Transform(location=u.Vector(*row['placement_main_cm'])),[v.material_interface for v in mesh.static_materials],'WVC_Larder_Finish_'+row['family'])
        p=json.loads((DOC/'WINDOW_LIGHT_PROPOSAL_R01.json').read_text());a=spawn(u.RectLight);c,=a.get_components_by_class(u.RectLightComponent)
        c.set_mobility(u.ComponentMobility.MOVABLE);c.set_intensity_units(u.LightUnits.LUMENS);c.set_intensity(7200.);c.set_attenuation_radius(p['attenuation_radius_cm']);c.set_source_width(1.);c.set_source_height(1.);c.set_barn_door_angle(p['barn_door_angle']);c.set_barn_door_length(p['barn_door_length']);c.set_cast_shadows(True)
        rgba=p['colour_srgb_bytes'];c.set_light_color(u.MathLibrary.conv_color_to_linear_color(u.Color(r=rgba[0],g=rgba[1],b=rgba[2],a=rgba[3])));c.set_editor_property('use_temperature',False);c.set_visibility(True)
        tf=u.Transform(location=u.Vector(*p['location_native_cm']),rotation=u.Rotator(**p['rotation']));a.set_actor_transform(tf,False,True);a.set_actor_label('WVC_Larder_Finish_Window')
        assert core._pose(a.get_actor_transform())==core._pose(tf) and c.intensity_units==u.LightUnits.LUMENS and c.get_editor_property('use_temperature') is False and c.mobility==u.ComponentMobility.MOVABLE
        assert c.intensity==7200 and c.source_width==c.source_height==1 and c.cast_shadows and c.attenuation_radius==2400 and [c.light_color.r,c.light_color.g,c.light_color.b,c.light_color.a]==rgba
        STATE['owned_expected']=[owned(a) for a in STATE['created']];STATE['stage']='ready';check()
        (RUN/'staged.json').write_text(json.dumps(dict(status='THREE_REVIEWED_SURFACES_ONE_REVIEWED_WINDOW_IN_DISPOSABLE_PIE',owned=STATE['owned_expected'],hism_count=len(before),instance_count=sum(len(r['instances']) for r in before.values()),source_lights=STATE['source_lights'],tool_sha256=sha(__file__)),indent=2)+'\n')
    except Exception:abort();raise

def stage_props():
    import unreal as u
    check();s=STATE;assert not s['props']
    try:
        for role,(label,index,count,at) in PROPS.items():
            actor,=[a for a in u.GameplayStatics.get_all_actors_of_class(s['world'],u.Actor) if a.get_actor_label()==label and 'LI_Warrens_Brineworks' in a.get_path_name()]
            c,=actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
            assert c.get_instance_count()==count and index==count-1 and c.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION and c.mobility==u.ComponentMobility.STATIC
            assert c.get_editor_property('num_custom_data_floats')==0
            assert c.static_mesh.get_path_name().split('.')[0]==PROP_MESHES[role]
            material_ids,slot_ids=PROP_SLOTS[role]
            assert [m.get_path_name().split('.')[0] for m in c.get_materials()]==['/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_'+n for n in material_ids]
            assert [str(v.get_editor_property('imported_material_slot_name')) for v in c.static_mesh.static_materials]==['WarrensC_'+n+'_Mars_MI' for n in slot_ids]
            source_flags=flags(c);assert source_flags['visible'] is True and source_flags['hidden_in_game'] is False and actor.get_editor_property('hidden') is False
            tf=c.get_instance_transform(index,world_space=True);assert (tf.translation-u.Vector(*at)).length()<.001 and (tf.scale3d-u.Vector(1,1,1)).length()<1e-6
            original=c.static_mesh;materials=list(c.get_materials());a=mesh_actor(original,tf,materials,'WVC_Larder_Finish_'+role)
            for key in FLAGS:
                if key in ('visible','hidden_in_game'):continue
                value=c.get_editor_property(key);a.static_mesh_component.set_editor_property(key,value.copy() if isinstance(value,u.StructBase) else value)
            assert flags(a.static_mesh_component)==source_flags
            s['props'][role]=dict(source=c,index=index,count=count,transform=tf,original=original,materials=materials,actor=a,closed=False,source_flags=source_flags)
            assert c.remove_instance(index)
            expected=copy.deepcopy(s['before'][c.get_path_name()]);expected['instances']=expected['instances'][:-1];s['expected_hisms'][c.get_path_name()]=expected
        s['owned_expected']=[owned(a) for a in s['created']];check()
    except Exception:abort();raise

def close_jar(closed):
    import unreal as u
    check();s=STATE;assert isinstance(closed,bool) and not s['paint_mids'];r=s['props']['jar'];a=r['actor'];before=owned(a)
    mesh=u.load_asset(DEST+'/Meshes/WVC_Larder_ClosedStorageJar_R01_SM') if closed else r['original']
    assert a.static_mesh_component.set_static_mesh(mesh)
    assert owned(a)==dict(before,mesh=mesh.get_path_name());r['closed']=closed;s['owned_expected']=[owned(a) for a in s['created']];check()

def paint_prop(role,on):
    import unreal as u
    check();s=STATE;assert role in PAINT and isinstance(on,bool) and s['props']['jar']['closed'];r=s['props'][role];c=r['actor'].static_mesh_component;before=owned(r['actor'])
    if on:
        assert role not in s['paint_mids'];mid=c.create_dynamic_material_instance(0,s['world_painterly'],'Larder_'+role+'_Painterly_R01');assert isinstance(mid,u.MaterialInstanceDynamic);s['paint_mids'][role]=mid
        for key,value in {'WorldTileCm':80.,'NormalStrength':.15,'RoughnessBlend':.2,'PigmentMix':PAINT[role]['mix']}.items():mid.set_scalar_parameter_value(key,value)
        for key,value in [('BaseColour',PAINT[role]['base']),('PigmentTint',PAINT[role]['tint'])]:mid.set_vector_parameter_value(key,u.LinearColor(*value))
        material=mid
    else:
        assert role in s['paint_mids'];material=r['materials'][0];c.set_material(0,material);del s['paint_mids'][role]
    expected=copy.deepcopy(before);expected['materials'][0]=material.get_path_name();assert owned(r['actor'])==expected;s['owned_expected']=[owned(a) for a in s['created']];check()

def brine_baseline(on):
    import unreal as u
    check();s=STATE;assert isinstance(on,bool)
    if on:
        assert s['water_mid'] is None
        rows=[(a,c) for a in u.GameplayStatics.get_all_actors_of_class(s['world'],u.Actor) if 'LI_Warrens_Brineworks' in a.get_path_name() for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent) if c.get_instance_count()==1 and len(c.get_materials())==1 and c.get_material(0).get_path_name()=='/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_FX_Water.M_CCK_FX_Water']
        (_,c),=rows;tf=c.get_instance_transform(0,world_space=True);assert (tf.translation-u.Vector(5000,-1400,-260)).length()<.001 and (tf.scale3d-u.Vector(16,14,.02)).length()<1e-6
        s['water_parent_active']=s['brine'];s['water_component']=c;s['water_original']=c.get_material(0);s['water_mid']=c.create_dynamic_material_instance(0,s['brine'],'Larder_Brine_R01');assert isinstance(s['water_mid'],u.MaterialInstanceDynamic)
        s['expected_hisms'][c.get_path_name()]['materials']=[s['water_mid'].get_path_name().split('.')[0]]
    else:
        assert s['water_mid'];c=s['water_component'];c.set_material(0,s['water_original']);s['expected_hisms'][c.get_path_name()]=copy.deepcopy(s['before'][c.get_path_name()]);s['water_mid']=None;s['water_component']=None;s['water_original']=None;s['water_parent_active']=s['brine'];s['water_rough']=.23999999463558197;s['water_colour']=(.054999999701976776,.11999999731779099,.0949999988079071,1.)
    check()

def brine_roughness(value):
    check();s=STATE;gate=json.loads((DOC/'NATIVE_BRINE_WORKING_GATE_R02.json').read_text());assert gate['status']=='APPROVED_FIXED_WORKING_BRINE_AFTER_PRIOR_NATIVE_REVIEW' and gate['tool_sha256']==sha(__file__) and sha(ROOT/gate['baseline_receipt'])==gate['baseline_receipt_sha256']
    assert s['water_mid'] and value==.45;s['water_mid'].set_scalar_parameter_value('BrineRoughness',value);s['water_rough']=value;check()

def brine_colour(dark):
    import unreal as u
    check();s=STATE;gate=json.loads((DOC/'NATIVE_BRINE_WORKING_GATE_R02.json').read_text());assert gate['status']=='APPROVED_FIXED_WORKING_BRINE_AFTER_PRIOR_NATIVE_REVIEW' and gate['tool_sha256']==sha(__file__) and sha(ROOT/gate['baseline_receipt'])==gate['baseline_receipt_sha256']
    assert s['water_mid'] and dark is True
    value=(.025,.075,.055,1.) if dark else (.054999999701976776,.11999999731779099,.0949999988079071,1.)
    s['water_mid'].set_vector_parameter_value('BrineColour',u.LinearColor(*value));s['water_colour']=value;check()

def capture(label):
    import unreal as u
    s=STATE;u.GameplayStatics.set_game_paused(s['world'],True);check();s['capture'].capture(label)
    p=s['capture'].STATE['out']/(label+'.json');record=json.loads(p.read_text());record.update(art_state=s['owned_expected'],five_original_room_lights=s['source_lights'],prop_state={role:dict(closed=r['closed'],painted=role in s['paint_mids'],source_path=r['source'].get_path_name(),source_tail_index=r['index']) for role,r in s['props'].items()},brine_state=dict(material=s['water_component'].get_material(0).get_path_name() if s['water_mid'] else 'SOURCE',roughness=s['water_rough'],colour=s['water_colour']))
    record['boundary']='Actual Main PIE with natural held lantern. Disposable reviewed surfaces/window and fixed-decor clones; only explicitly recorded finite mesh/body-material/water-material axes change. Original physical transforms, collision, gameplay, five source lights, all nonowned HISM rows and source packages remain exact. Teleport/paused appearance evidence, not physical input, pacing or multiplayer proof.'
    p.write_text(json.dumps(record,indent=2)+'\n')

def restore():
    import unreal as u
    check();s=STATE
    try:
        if s['water_mid']:brine_baseline(False)
        for r in s['props'].values():
            c=r['source'];assert c.get_instance_count()==r['count']-1 and c.add_instance(r['transform'],world_space=True)==r['index']
        _,actual=s['core']._hism_snapshot(s['world']);assert actual==s['before']
        s['destroy_paths']=[a.get_path_name() for a in s['created']]
        for a in reversed(s['created']):
            assert OWNER in list(map(str,a.tags));a.destroy_actor();assert not u.SystemLibrary.is_valid(a) or a.is_actor_being_destroyed()
        s['created']=[];s['owned_expected']=[];s['props']={};s['paint_mids']={};s['stage']='await_absence';guard()
    except Exception:abort();raise

def confirm_restored():
    import unreal as u
    global STATE
    s=STATE;assert s and s['stage']=='await_absence'
    try:
        actual={a.get_path_name() for a in u.GameplayStatics.get_all_actors_of_class(s['world'],u.Actor)}
        assert all(p not in actual and not u.SystemLibrary.is_valid(u.find_object(None,p)) for p in s['destroy_paths'])
        _,after=s['core']._hism_snapshot(s['world']);assert after==s['before'] and s['light_reader'].lights(s['world'])==s['source_lights'];guard()
        (RUN/'restored.json').write_text(json.dumps(dict(status='LATER_TURN_OWNED_ACTOR_ABSENCE_ORIGINAL_HISMS_AND_FIVE_LIGHTS_EXACT',removed=s['destroy_paths'],hisms=len(after),instances=sum(len(r['instances']) for r in after.values()),tool_sha256=sha(__file__)),indent=2)+'\n');STATE=None
    except Exception:abort();raise

def abort():
    import unreal as u
    global STATE
    s=STATE
    try:
        w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
        if w:
            assert w.get_path_name()=='/Game/Mars/Maps/UEDPIE_0_Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
            u.get_editor_subsystem(u.LevelEditorSubsystem).editor_request_end_play()
    finally:
        if s:s['capture'].STATE=None
        STATE=None
