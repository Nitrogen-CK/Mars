"""Checkpointed Catacomb-only library synchronization; save is separately gated."""
import copy
import hashlib
import importlib.util
import json
import re
from pathlib import Path
import shutil
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02'
OWNER='Mars.WarrensVariantC.Catacomb.LibrarySync.R23'
ATTEMPT='native_libraries_r23b'
MAPS={k:'/Game/Mars/Environment/WarrensVariantCKit/Maps/WarrensVariantC_'+k+'_Mars_MAP' for k in ('Diorama','KitLibrary')}
STATE=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
LOADED=sha(__file__)
def module(name):
    p=Path(__file__).with_name(name+'.py');s=importlib.util.spec_from_file_location('_cp23_'+name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def disk(target):return ROOT/('Content/'+MAPS[target].removeprefix('/Game/')+'.umap')
def write(name,data):
    p=RUN/ATTEMPT/STATE['target']/(name+'.json');assert not p.exists();p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(data,indent=2)+'\n');return dict(file=p.relative_to(ROOT).as_posix(),sha256=sha(p))
def guard():
    import unreal as u
    assert Path(u.Paths.project_dir()).resolve()==ROOT.resolve()
    gpath=RUN/'baseline_guard_after_source_room_r19.json';assert sha(gpath)=='16ffda7943311dc84077c39a3c3905c3c13e5806d4579b4c1e7dd2919471aa72';g=read(gpath);files=g['immutable_guards']|g['collision_hashes'];assert len(files)==651
    overrides=STATE['saved_hashes'] if STATE else {};assert not overrides,'Unsaved Kit preview cannot override any protected hash'
    assert all(sha(ROOT/p)==overrides.get(p,h) for p,h in files.items()),'Protected file drift'
    assert all(sha(ROOT/p)==h for p,h in g['post_test_provenance']['source_sha256'].items())
    a=read(RUN/'candidate_assets_timber_r13.json');assert len(a['assets'])==39 and all(sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset'))==r['package_sha256'] for p,r in a['assets'].items());return len(files)
def world():
    import unreal as u
    ed=u.get_editor_subsystem(u.UnrealEditorSubsystem);assert ed.get_game_world() is None;w=ed.get_editor_world();assert w.get_path_name().split('.')[0]==MAPS[STATE['target']];return w
def snapshot(label):
    import unreal as u
    s=STATE;base,core=s['source'].dependencies();folder=RUN/ATTEMPT/s['target']/label;assert not folder.exists();roster,hisms=base._roster(u,core,world(),folder)
    return dict(roster=roster,hisms=hisms)
def same_raw(a,b):return a['sha256']==b['sha256']
def checkpoint(target,source,saved_hashes=None):
    global STATE
    import unreal as u
    assert STATE is None and target=='KitLibrary' and not saved_hashes and source.dirty()==dict(maps=[],content=[])
    STATE=dict(target=target,source=source,saved_hashes=dict(saved_hashes or {}),stage='checkpointing',created=[],expected=[],extras=[],prefs=source.settings())
    guard();world();selection=read(DOC/'LIBRARY_SELECTION_R21.json');assert sha(DOC/'LIBRARY_SELECTION_R21.json')=='7b8f90006ec304be2481ccefb5659bcb0d455b6f260371ef023622ce65283ce3'
    STATE['selection']=selection;STATE['retained']=read(DOC/'SOURCE_RETENTION_MANIFEST_R17.json');STATE['parts']=module('catacomb_fixture_execution_r14');STATE['pose']=module('catacomb_source_room_r18')
    assert sha(Path(STATE['parts'].__file__))=='f138dfc5fb8a0a06907f2ad222710cb4fd844ecad149c158e3821d03f6c0a556'
    assert sha(Path(STATE['pose'].__file__))=='d00fcfad55e51561420140b518e276c4eb5229adbb8f6bf56e4019879be6150a'
    assert all(sha(ROOT/p)==h for p,h in selection['inputs'].items())
    before=snapshot('before');expected=read(RUN/'library_inventory_r20'/target/'inventory.json')
    assert before['hisms']==expected['hisms'] and set(before['roster'])==set(expected['roster'])
    for n,row in before['roster'].items():
        old=expected['roster'][n];assert all(row[k]==old[k] for k in ('label','type','tags','pose','hidden','folder'));assert same_raw(row['raw'],old['raw'])
        assert set(row['components'])==set(old['components'])
        for cn,c in row['components'].items():assert same_raw(c['raw'],old['components'][cn]['raw'])
    folder=RUN/ATTEMPT/target;backup=folder/'before.umap';assert not backup.exists();shutil.copy2(disk(target),backup);assert sha(backup)==expected['map_sha256']
    STATE.update(before=before,backup=backup.relative_to(ROOT).as_posix(),original_sha=sha(disk(target)),stage='checkpointed')
    STATE['checkpoint']=write('checkpoint',dict(status='READ_ONLY_LIBRARY_CHECKPOINT',map_sha256=STATE['original_sha'],backup=STATE['backup'],tool_sha256=LOADED,selection_sha256=sha(DOC/'LIBRARY_SELECTION_R21.json'),snapshot=before))
    guard();print('LIBRARY_CHECKPOINT',target,len(before['roster']),len(before['hisms']))
def actor(label,typ=None):
    import unreal as u
    a=u.get_editor_subsystem(u.EditorActorSubsystem).spawn_actor_from_class(typ or u.Actor,u.Vector(),u.Rotator());assert a and a.get_world()==world();a.set_actor_label('CP23_'+label);a.tags=[u.Name(OWNER)];a.set_folder_path(u.Name('ArtReview/CatacombAccepted'));a.root_component.set_mobility(u.ComponentMobility.MOVABLE);STATE['created'].append(a);return a
def component(a,typ):
    import unreal as u
    sub=u.get_engine_subsystem(u.SubobjectDataSubsystem);root=sub.k2_gather_subobject_data_for_instance(a)[0];h,reason=sub.add_new_subobject(u.AddNewSubobjectParams(parent_handle=root,new_class=typ));c=u.SubobjectDataBlueprintFunctionLibrary.get_associated_object(u.SubobjectDataBlueprintFunctionLibrary.get_data(h));assert isinstance(c,typ),str(reason);c.set_mobility(u.ComponentMobility.MOVABLE);return c
def pose(at,scale=(1,1,1),q=(0,0,0,1)):return dict(at=list(at),scale=list(scale),q=list(q))
def shifted(p,offset):
    r=copy.deepcopy(p);r['at']=[v+d for v,d in zip(r['at'],offset)];return r
def mesh_group(a,mesh,mats,poses,instanced=True,cast_shadow=True):
    import unreal as u
    effective=[u.load_asset(p) if p else None for p in mats]
    assert all(effective),('Unbound material slot',mesh,mats)
    instanced=instanced and all(m.get_base_material().get_editor_property('used_with_instanced_static_meshes') for m in effective)
    if not instanced and len(poses)>1:
        for p in poses:mesh_group(a,mesh,mats,[p],False,cast_shadow)
        return None
    typ=u.HierarchicalInstancedStaticMeshComponent if instanced else u.StaticMeshComponent;c=component(a,typ)
    # Registered empty HISMs must receive validated overrides before assigning a
    # mesh can precache/recreate render state with that mesh's default materials.
    for i,p in enumerate(mats):c.set_material(i,u.load_asset(p) if p else None)
    assert c.set_static_mesh(u.load_asset(mesh));c.set_collision_profile_name('NoCollision');c.set_collision_enabled(u.CollisionEnabled.NO_COLLISION);c.set_generate_overlap_events(False);c.set_cast_shadow(cast_shadow);c.set_visibility(True,False);c.set_hidden_in_game(False,False)
    if instanced:
        for index,p in enumerate(poses):assert c.add_instance(STATE['pose'].transform(p),world_space=False)==index
    else:
        assert len(poses)==1;c.set_world_transform(STATE['pose'].transform(poses[0]),False,True)
    STATE['expected'].append(dict(actor=a.get_name(),component=c.get_name(),mesh=mesh,materials=mats,poses=poses,instanced=instanced,cast_shadow=cast_shadow));return c
def forage(role,centre,label):
    rows=STATE['parts'].expected_parts(role);a=actor(label);groups={}
    for r in rows:
        p=pose([r['at'][0]+centre[0]+9600,r['at'][1]+centre[1]-1900,r['at'][2]+centre[2]],r['scale']);m=r['material'];supported=_material_support(m)
        if supported:groups.setdefault((r['mesh'],m),[]).append(p)
        else:mesh_group(a,r['mesh'],[m],[p],False)
    for (mesh,mat),poses in groups.items():mesh_group(a,mesh,[mat],poses)
    return a
def label(text,at):
    import unreal as u
    a=actor('Label_'+text,u.TextRenderActor);a.set_actor_location(u.Vector(*at),False,True);a.set_actor_rotation(u.Rotator(0,-90,0),True);c=a.text_render;c.set_text(text+' / Catacomb');c.set_world_size(22);c.set_horizontal_alignment(u.HorizTextAligment.EHTA_CENTER);c.set_collision_enabled(u.CollisionEnabled.NO_COLLISION);assert str(c.text)==text+' / Catacomb' and c.world_size==22;record_extra(a);return a
def camera(name,at,target,fov=65):
    import unreal as u
    a=actor(name,u.CameraActor);a.set_actor_location(u.Vector(*at),False,True);a.set_actor_rotation(u.MathLibrary.find_look_at_rotation(u.Vector(*at),u.Vector(*target)),True);a.camera_component.set_field_of_view(fov);assert a.camera_component.field_of_view==fov;record_extra(a);return a
def light(row,offset):
    import unreal as u
    p=shifted(row['pose'],offset);a=actor(row['label'],u.SpotLight if 'inner_cone' in row['light'] else u.PointLight);a.set_actor_transform(STATE['pose'].transform(p),False,True);c,=a.get_components_by_class(u.PointLightComponent);v=row['light'];c.set_editor_property('intensity_units',u.LightUnits.CANDELAS);c.set_intensity(v['intensity']);c.set_attenuation_radius(v['radius']);c.set_editor_property('light_color',STATE['pose'].color(v['color_rgba']))
    for k in ('source_radius','source_length','soft_source_radius'):c.set_editor_property(k,v[k])
    c.set_editor_property('use_inverse_squared_falloff',v['inverse_squared']);c.set_cast_shadows(v['cast_shadows'])
    if 'inner_cone' in v:c.set_inner_cone_angle(v['inner_cone']);c.set_outer_cone_angle(v['outer_cone'])
    assert STATE['source'].dependencies()[1]._near(a.get_actor_transform(),STATE['pose'].transform(p)) and a.root_component.get_editor_property('mobility')==u.ComponentMobility.MOVABLE
    actual=extra(a)['details'];expected=dict(v,units=str(u.LightUnits.CANDELAS));assert all(actual[k]==value for k,value in expected.items()),(actual,expected);record_extra(a)
def extra(a):
    import unreal as u
    core=STATE['source'].dependencies()[1];row=dict(actor=a.get_name(),type=a.get_class().get_path_name(),pose=core._pose(a.get_actor_transform()),mobility=str(a.root_component.get_editor_property('mobility')),details={})
    if a.get_components_by_class(u.PointLightComponent):
        c,=a.get_components_by_class(u.PointLightComponent);row['details']=dict(intensity=c.intensity,radius=c.attenuation_radius,color_rgba=STATE['pose'].rgba(c.light_color),source_radius=c.source_radius,source_length=c.source_length,soft_source_radius=c.soft_source_radius,inverse_squared=c.use_inverse_squared_falloff,cast_shadows=c.cast_shadows,units=str(c.get_editor_property('intensity_units')))
        if isinstance(c,u.SpotLightComponent):row['details'].update(inner_cone=c.inner_cone_angle,outer_cone=c.outer_cone_angle)
    elif isinstance(a,u.CameraActor):row['details']=dict(fov=a.camera_component.field_of_view)
    elif isinstance(a,u.TextRenderActor):row['details']=dict(text=str(a.text_render.text),world_size=a.text_render.world_size,alignment=str(a.text_render.horizontal_alignment),collision=str(a.text_render.get_collision_enabled()))
    return row
def record_extra(a):STATE['extras'].append(extra(a))
def _material_support(path):
    import unreal as u
    m=u.load_asset(path);assert isinstance(m,u.MaterialInterface);return bool(m.get_base_material().get_editor_property('used_with_instanced_static_meshes'))
def find(path):
    import unreal as u
    o=u.find_object(None,path);assert o;return o
def stage(review_file,review_sha):
    import unreal as u
    s=STATE;assert s['target']=='KitLibrary' and s['stage']=='checkpointed' and LOADED==sha(__file__);assert sha(ROOT/review_file)==review_sha
    gate=read(ROOT/review_file);assert gate['status']=='APPROVED_UNSAVED_NATIVE_LIBRARY_STAGE' and gate['target']==s['target'] and gate['tool_sha256']==LOADED and gate['checkpoint']==s['checkpoint'] and gate['export_settle']==s['export_settle'] and gate['selection_sha256']==sha(DOC/'LIBRARY_SELECTION_R21.json') and gate['export_settle_helper_sha256']==sha(Path(__file__).with_name('catacomb_library_export_settle_r24.py'))
    assert sha(ROOT/gate['review']['file'])==gate['review']['sha256'];guard();assert s['source'].dirty()==dict(maps=[],content=[])
    s['stage']='staging';p=s['prefs'];p['editor'].set_editor_property('bAutoSaveEnable',False);p['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave',type(p['cook']).DISABLE);now=s['source'].settings();assert now['autosave'] is False and now['cook']==type(p['cook']).DISABLE
    s.setdefault('extras',[]);sel=s['selection'];core=s['source'].dependencies()[1];assert sha(Path(s['pose'].__file__))=='d00fcfad55e51561420140b518e276c4eb5229adbb8f6bf56e4019879be6150a' and sha(Path(s['parts'].__file__))=='f138dfc5fb8a0a06907f2ad222710cb4fd844ecad149c158e3821d03f6c0a556';assert all(sha(ROOT/p)==h for p,h in sel['inputs'].items())
    if s['target']=='KitLibrary':
        for cell in sel['kit_cells']:
            role=cell['role'];centre=cell['centre_native_cm']
            if role in ('Fig','Bellnut','Censer'):forage(role,centre,'Kit_'+role)
            elif role in ('TimberPost','TimberArm'):
                OLD=s['parts'].OLD;a=actor('Kit_'+role);mat=OLD+'/Timber_R02/Materials/M_CP_ForageTimber'+('Post' if role=='TimberPost' else 'Arm')+'_R02';mesh_group(a,'/Engine/BasicShapes/Cube',[mat],[pose([centre[0],centre[1],130],[.24,.24,2.6] if role=='TimberPost' else [1.2,.12,.12])],False)
            else:
                d,=[r for r in sel['mesh_displays'] if r['role']==role];a=actor('Kit_'+role)
                if role in ('Walls','Floor','Ceiling'):r,=[r for r in sel['retained_source_actors'] if r.get('mesh')==d['mesh']];mats=r['materials']
                else:
                    ident={'Tomb':'WVC026','Lid':'WVC081','Bone':'WVC052','Urn':'WVC053'}[role];r,=[r for r in sel['diorama_splits'] if r['ident']==ident];mats=list(r['before']['materials']);mats[0]=r['material_after']
                mesh_group(a,d['mesh'],mats,[d['kit_native_actor_pose']])
            label(role,[centre[0],centre[1]-280,0])
        cy=sel['kit_cells'][0]['centre_native_cm'][1]
        for name,at,target in [('Kit_Forage',[1050,cy-1900,260],[1050,cy,220]),('Kit_Props',[3500,cy-2100,700],[3500,cy,60]),('Kit_Surfaces',[5950,cy-1900,550],[5950,cy,120]),('Kit_Ceiling',[6650,cy-450,90],[6650,cy,210]),('Kit_Timber',[7700,cy-900,200],[7700,cy,130])]:camera(name,at,target)
        # Local movable lamps illuminate exhibits without changing original library lights.
        for i,x in enumerate((1050,3500,5950,7700)):
            r=dict(label='Kit_LocalLight_'+str(i),pose=pose([x,cy-350,400]),light=dict(intensity=1700,radius=2500,color_rgba=[255,239,216,255],source_radius=120,source_length=0,soft_source_radius=120,inverse_squared=True,cast_shadows=True));light(r,[0,0,0])
    else:
        base,core=s['source'].dependencies()
        for r in sel['diorama_splits']:
            c=find(r['component']);assert core._component(c)==r['before'] and r['index']==c.get_instance_count()-1;mats=list(r['before']['materials']);mats[0]=r['material_after'];assert all(_material_support(p) for p in mats),'Shared prop clone requires all material slots to support HISM';a,new,native=base._new_group(u,world(),c,[r['index']],u.load_asset(r['material_after']),'CP23_Prop_'+r['ident'],OWNER,u.Name('ArtReview/CatacombAccepted'),RUN/ATTEMPT/'Diorama'/'split_components');s['created'].append(a);c.modify();c.get_owner().modify();assert c.remove_instance(r['index'])
        for r in sel['fixture_appends']:
            c,=[c for a in u.GameplayStatics.get_all_actors_of_class(world(),u.Actor) for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent) if a.get_actor_label()==r['actor_label'] and STATE['pose'].package(c.static_mesh)==r['mesh']];c.modify();c.get_owner().modify()
            for p in r['add_local_poses']:c.add_instance(s['pose'].transform(shifted(p,sel['source_to_diorama_translation_cm'])),world_space=False)
        for r in sel['retained_source_actors']:
            if 'light' in r:light(r,sel['source_to_diorama_translation_cm'])
            elif 'Ceiling' not in r['mesh']:mesh_group(actor('Room_'+r['label']),r['mesh'],r['materials'],[shifted(r['pose'],sel['source_to_diorama_translation_cm'])],True,r['cast_shadow'])
        forage('Fig',[-8400,1900,0],'Diorama_StaticFig_OnePossibleOutcome');camera('Room_Review',[-8600,1900,112],[-8200,2500,100],90)
    after=snapshot('staged');s['staged']=after;write('staged_unvalidated',dict(snapshot=after,expected=s['expected']));verify(after);guard();assert s['source'].dirty()==dict(maps=[MAPS[s['target']]],content=[]);s['stage']='staged';print('NATIVE_LIBRARY_UNSAVED',s['target'],len(after['roster']),len(after['hisms']))
def verify(after):
    import unreal as u
    s=STATE;before=s['before'];core=s['source'].dependencies()[1];assert set(before['roster'])<set(after['roster'])
    touched=set()
    if s['target']=='Diorama':touched={r['before']['owner'].rsplit('.',1)[1] for r in s['selection']['diorama_splits']}|{n for n,r in before['roster'].items() if r['label'] in {v['actor_label'] for v in s['selection']['fixture_appends']}}
    for n,r in before['roster'].items():
        a=after['roster'][n];assert all(a[k]==r[k] for k in ('label','type','tags','pose','hidden','folder'));assert set(a['components'])==set(r['components'])
        if n not in touched:
            assert same_raw(a['raw'],r['raw']),('Original actor changed',n)
            for cn,c in r['components'].items():assert same_raw(a['components'][cn]['raw'],c['raw']),('Original component changed',n,cn)
        else:
            split=next((v for v in s['selection']['diorama_splits'] if v['before']['owner'].rsplit('.',1)[1]==n),None)
            append=next((v for v in s['selection']['fixture_appends'] if v['actor_label']==r['label']),None)
            assert bool(split)!=bool(append)
            indices={split['index']} if split else set(range(append['before_count'],append['before_count']+len(append['add_local_poses'])))
            def normal(raw):
                result=[]
                for line in (ROOT/raw['file']).read_text().splitlines():
                    key=line.strip().split('=',1)[0]
                    if re.fullmatch(r'(SortedInstances\(\d+\)|NumBuiltInstances|BuiltInstanceBounds|UnbuiltInstanceBounds|UnbuiltInstanceBoundsList\(\d+\)|CacheMeshExtendedBounds|InstanceCountToRender|InstanceReorderTable\(\d+\)|CachedBounds\(\d+\))',key):continue
                    match=re.fullmatch(r'PerInstanceSMData\((\d+)\)',key)
                    if match and int(match[1]) in indices:continue
                    result.append(line)
                return result
            assert normal(a['raw'])==normal(r['raw']),('Unexpected touched actor raw delta',n)
            for cn,c in r['components'].items():assert normal(a['components'][cn]['raw'])==normal(c['raw']),('Unexpected touched component raw delta',n,cn)
    expected=copy.deepcopy(before['hisms'])
    if s['target']=='Diorama':
        for r in s['selection']['diorama_splits']:expected[r['component']]['instances'].pop(r['index'])
        for r in s['selection']['fixture_appends']:
            p,= [p for p,v in expected.items() if v['owner_label']==r['actor_label'] and v['mesh']==r['mesh']]
            expected[p]['instances'] += [shifted(v,s['selection']['source_to_diorama_translation_cm']) for v in r['add_local_poses']]
    for p,r in expected.items():assert r==after['hisms'][p],('Original HISM changed',p)
    for r in s['expected']:
        a=find(MAPS[s['target']]+'.'+MAPS[s['target']].rsplit('/',1)[1]+':PersistentLevel.'+r['actor']);c,=[v for v in a.get_components_by_class(u.StaticMeshComponent) if v.get_name()==r['component']]
        assert s['pose'].package(c.static_mesh)==r['mesh'] and [s['pose'].package(v) for v in c.get_materials()]==r['materials'];assert c.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION and str(c.get_collision_profile_name())=='NoCollision' and c.cast_shadow==r['cast_shadow']
        assert c.get_editor_property('mobility')==u.ComponentMobility.MOVABLE and a.root_component.get_editor_property('mobility')==u.ComponentMobility.MOVABLE and c.is_visible() and not c.get_editor_property('hidden_in_game') and not c.get_editor_property('generate_overlap_events')
        if r['instanced']:assert c.get_instance_count()==len(r['poses']) and all(core._near(c.get_instance_transform(i,world_space=False),s['pose'].transform(p)) for i,p in enumerate(r['poses']))
        else:assert core._near(c.get_world_transform(),s['pose'].transform(r['poses'][0]))
    added=set(after['roster'])-set(before['roster']);assert len(added)==len(s['created']) and all(after['roster'][n]['tags']==[OWNER] for n in added)
    for row in s['extras']:assert extra(find(MAPS[s['target']]+'.'+MAPS[s['target']].rsplit('/',1)[1]+':PersistentLevel.'+row['actor']))==row,('New actor readback drift',row['actor'])
def restore_preferences():
    p=STATE['prefs'];p['editor'].set_editor_property('bAutoSaveEnable',p['autosave']);p['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave',p['cook']);now=STATE['source'].settings();assert now['autosave']==p['autosave'] and now['cook']==p['cook']
def abort():
    import unreal as u
    s=STATE;assert s['stage'] in ('staging','staged') and sha(disk(s['target']))==s['original_sha'];guard();d=s['source'].dirty();assert not d['content'] and set(d['maps'])<={MAPS[s['target']]}
    try:
        s['created'].clear();loaded=u.EditorLoadingAndSavingUtils.load_map(str(ROOT/'Content/Mars/Maps/StationGym_Mars_MAP.umap'));assert loaded and loaded.get_path_name()=='/Game/Mars/Maps/StationGym_Mars_MAP.StationGym_Mars_MAP';assert s['source'].dirty()==dict(maps=[],content=[]);s['stage']='aborted';guard();print('UNSAVED_LIBRARY_DISCARDED')
    finally:restore_preferences()
