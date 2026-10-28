"""Repeatable owned source levels, HISM kit library and comparison diorama.

No camp mutation. Source levels are visual assemblies. Stable-map collision is
an explicit separate operation because CkJolt cannot resolve transient LI IDs.
"""
import json,math,gc,sys
from pathlib import Path
from collections import defaultdict
import unreal as u
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
from import_unreal import OUT,DEST,OWNER,TAG,manifest,own
EA=u.get_editor_subsystem(u.EditorActorSubsystem);LES=u.get_editor_subsystem(u.LevelEditorSubsystem);ED=u.get_editor_subsystem(u.UnrealEditorSubsystem);SS=u.get_engine_subsystem(u.SubobjectDataSubsystem)
NAMES={'HS':'Hearthscrew','BW':'BraidedWell','RW':'Rootwinder','HL':'HangingLarder'}
OFFSETS={'HS':(-2200,-2200,0),'BW':(1200,-2200,0),'RW':(-2200,1200,0),'HL':(1200,1200,0)}

def map_path(kind):return '/Game/Mars/Maps/Spire/LI_Spire_'+NAMES[kind]+'_Mars_MAP' if kind in NAMES else DEST+'/Maps/Spire_'+kind+'_Mars_MAP'
def world_path():return ED.get_editor_world().get_path_name().split('.')[0]
def clean():
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages(),'Unsaved map; refusing switch'
    # First HISM use can set a material usage flag after its initial import save.
    for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages():
        path=p.get_path_name();a=u.load_asset(path)
        assert path.startswith(DEST+'/') and u.EditorAssetLibrary.get_metadata_tag(a,TAG)==OWNER,'Unowned dirty package '+path
        assert u.EditorAssetLibrary.save_loaded_asset(a,False),path
    assert not u.EditorLoadingAndSavingUtils.get_dirty_content_packages(),'Unsaved content; refusing switch'
    assert not ED.get_game_world(),'Stop PIE before authoring'
def actor(cls,label,at=(0,0,0),yaw=0):
    a=EA.spawn_actor_from_class(cls,u.Vector(*at),u.Rotator(yaw=yaw));assert a,label
    a.set_actor_label('SP_'+label);a.tags=[u.Name(OWNER)];a.set_folder_path('SpireConnectorKit');return a
def start_map(kind):
    clean();gc.collect();path=map_path(kind)
    if u.EditorAssetLibrary.does_asset_exist(path):
        assert LES.load_level(path)
        assert u.EditorAssetLibrary.get_metadata_tag(ED.get_editor_world(),TAG)==OWNER,'Foreign map '+path
        for a in EA.get_all_level_actors():
            assert OWNER in [str(t) for t in a.tags],'Unowned actor; refusing rebuild '+a.get_actor_label()
        for a in EA.get_all_level_actors():assert EA.destroy_actor(a)
    else:assert LES.new_level(path,False)
    return path
def save_map():
    own(ED.get_editor_world())
    cls=u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE');settings=u.get_default_object(cls);old=settings.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    try:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave',type(old).DISABLE);assert LES.save_current_level()
    finally:settings.set_editor_property('_AutoCookStaticWorldOnLevelSave',old)
def shifted(row,offset=(0,0,0),yaw=0):
    p=dict(row);x,y,z=row['at_cm'];a=math.radians(yaw);p['at_cm']=[x*math.cos(a)-y*math.sin(a)+offset[0],x*math.sin(a)+y*math.cos(a)+offset[1],z+offset[2]];p['yaw_deg']+=yaw;return p
def instances(rows,prefix='Visual',collision=False):
    data=manifest();lookup={r['id']:r for r in data['assets']};groups=defaultdict(list);counts={}
    for row in rows:groups[(row['asset'],row['layer'])].append(row)
    for (key,layer),placements in sorted(groups.items()):
        mesh=u.load_asset(DEST+'/Meshes/'+lookup[key]['name']);assert isinstance(mesh,u.StaticMesh),key
        a=actor(u.Actor,prefix+'_'+layer+'_'+key);a.root_component.set_mobility(u.ComponentMobility.STATIC);a.set_folder_path('SpireConnectorKit/'+prefix+'/'+layer)
        h=SS.k2_gather_subobject_data_for_instance(a)[0];ch,reason=SS.add_new_subobject(u.AddNewSubobjectParams(parent_handle=h,new_class=u.HierarchicalInstancedStaticMeshComponent));c=u.SubobjectDataBlueprintFunctionLibrary.get_associated_object(u.SubobjectDataBlueprintFunctionLibrary.get_data(ch));assert c,str(reason)
        c.set_mobility(u.ComponentMobility.STATIC);c.set_static_mesh(mesh);c.set_collision_profile_name('BlockAll' if collision else 'NoCollision');c.set_editor_property('generate_overlap_events',False)
        if collision:c.set_visibility(False);c.set_hidden_in_game(True);c.set_cast_shadow(False)
        for p in placements:c.add_instance(u.Transform(location=u.Vector(*p['at_cm']),rotation=u.Rotator(yaw=p['yaw_deg']),scale=u.Vector(*p['scale'])),world_space=True)
        assert c.get_instance_count()==len(placements);counts[key+'|'+layer]=len(placements)
    return counts
def camera(label,at,target):
    a=actor(u.CameraActor,label,at);a.set_actor_rotation(u.MathLibrary.find_look_at_rotation(u.Vector(*at),u.Vector(*target)),False);a.camera_component.set_editor_property('field_of_view',55);a.camera_component.set_editor_property('aspect_ratio',4/3);return a
def frame(a):ED.set_level_viewport_camera_info(a.get_actor_location(),a.get_actor_rotation())
def light(label,at,intensity=12,color=(1,.62,.28),radius=700):
    a=actor(u.PointLight,label,at);c=a.point_light_component;c.set_mobility(u.ComponentMobility.MOVABLE);c.set_intensity(intensity);c.set_attenuation_radius(radius);c.set_light_color(u.LinearColor(*color,1));return a
def studio():
    a=actor(u.PostProcessVolume,'ReviewExposure');a.set_editor_property('unbound',True);s=a.get_editor_property('settings')
    for k,v in [('auto_exposure_min_brightness',1.),('auto_exposure_max_brightness',1.),('auto_exposure_bias',0.),('bloom_intensity',.1)]:s.set_editor_property(k,v);s.set_editor_property('override_'+k,True)
    a.set_editor_property('settings',s);a=actor(u.DirectionalLight,'ReviewKey');a.set_actor_rotation(u.Rotator(pitch=-45,yaw=35),False);a.light_component.set_mobility(u.ComponentMobility.MOVABLE);a.light_component.set_intensity(12)
    a=actor(u.SkyLight,'ReviewFill');c=a.light_component;c.set_mobility(u.ComponentMobility.MOVABLE);c.set_editor_property('source_type',u.SkyLightSourceType.SLS_SPECIFIED_CUBEMAP);c.set_editor_property('cubemap',u.load_asset('/Engine/EngineResources/GrayLightTextureCube'));c.set_editor_property('lower_hemisphere_is_black',False);c.set_intensity(1)
def label(text,at,size=30):
    a=actor(u.TextRenderActor,'Label_'+text,at);a.text_render.set_text(text);a.text_render.set_world_size(size);a.set_actor_rotation(u.Rotator(pitch=90),False)
def source_lamps(cid,offset=(0,0,0)):
    spec=json.loads((HERE.parents[1]/'Docs/design/spire-blender-handoff-20261026/spire_spec.json').read_text(encoding='utf-8'));c=next(c for c in spec['concepts'] if c['id']==cid)
    for p in c['prop_instances']:
        if p['asset']=='P08':
            x,y,z=p['local_origin_cm'];a=math.radians(p['yaw_outward_deg']);light(cid+'_'+p['id'],(x-12*math.cos(a)+offset[0],y-12*math.sin(a)+offset[1],z+21+offset[2]))
def build_map(kind):
    path=start_map(kind);data=manifest();cols=10
    if kind in NAMES:
        counts=instances(data['assemblies'][kind]);source_lamps(kind);R=700 if kind=='BW' else 600
        # Stable origin and two seam transforms are editable integration helpers.
        for name,at in [('UpperSocket',(0,0,0)),('LowerSocket',(2*R+300,0,-1200))]:actor(u.TargetPoint,name,at)
        cam=camera('Overview',(-1900,2800,1700),(R,0,-500));camera('Entry',(-80,0,165),(350,-200,-100));camera('LowerReturn',(2*R+220,0,-1035),(R,0,-600));frame(cam)
    elif kind=='KitLibrary':
        rows=[]
        for i,r in enumerate(data['assets']):
            lo,hi=r['bounds_min_cm'],r['bounds_max_cm'];x=(i%cols)*900;y=(i//cols)*900
            rows.append(dict(asset=r['id'],at_cm=[x-(lo[0]+hi[0])/2,y-(lo[1]+hi[1])/2,-lo[2]],yaw_deg=0,scale=[1,1,1],layer=r['category']))
            label(r['id'],(x-220,y-390,5),25)
        counts=instances(rows);studio();cam=camera('LibraryOverview',(4000,4500,15000),(4000,4500,0));cam.camera_component.set_editor_property('projection_mode',u.CameraProjectionMode.ORTHOGRAPHIC);cam.camera_component.set_editor_property('ortho_width',14000);frame(cam)
        camera('PropsDetail',(-800,-950,1250),(1600,450,50))
    elif kind=='Diorama':
        rows=[];collisions=[]
        for cid,offset in OFFSETS.items():
            R=700 if cid=='BW' else 600
            rows.extend(shifted(p,offset) for p in data['assemblies'][cid] if p['layer'] not in ['Roof','ShellFront'])
            rows.append(dict(asset='ReviewPlinth',at_cm=[offset[0]+R+150,offset[1],-1240],yaw_deg=0,scale=[(2*R+600)/100,(2*R+400)/100,1],layer='Presentation'))
            collisions.extend(shifted(p,offset) for p in data['collision_assemblies'][cid]);source_lamps(cid,offset);label(NAMES[cid],(offset[0]+R-450,offset[1]-R-150,-1235),60)
            camera(cid+'_Overview',(offset[0]-1900,offset[1]+2800,1700),(offset[0]+R,offset[1],-500))
        counts=instances(rows);instances(collisions,'StableCollision',True);studio()
        for cid,offset in OFFSETS.items():
            R=700 if cid=='BW' else 600
            for z in [-900,-400,150]:
                a=light('ReviewFill_'+cid+'_'+str(z),(offset[0]+R-250,offset[1]+750,z),100,(.65,.78,1),1900);a.point_light_component.set_cast_shadows(False)
            camera(cid+'_Entry',(offset[0]-80,offset[1],165),(offset[0]+350,offset[1]-200,-100))
        frame(camera('DioramaOverview',(-4600,6300,4500),(0,0,-500)))
    else:raise ValueError(kind)
    save_map();report=dict(map=path,visual_instances=sum(counts.values()),hism_groups=len(counts),counts=counts,collision='Separate stable proxies in Diorama; NoCollision visual components',status='saved')
    (OUT/'Reports'/('unreal_'+kind+'.json')).write_text(json.dumps(report,indent=2));print('SPIRE_MAP_SAVED',kind,json.dumps(report));return report
def place_stable_collision(cid,expected_map,location_cm=(1640,0,0),yaw_deg=0):
    """Opt-in persistent-level collision; caller must own integration map and save it."""
    assert cid in NAMES and world_path()==expected_map,'Unexpected destination map'
    assert '_LevelInstance_' not in expected_map and '/Temp/' not in expected_map,'Transient map unsupported by CkJolt'
    prefix='StableCollision_'+cid
    assert not any(a.get_actor_label().startswith('SP_'+prefix+'_') for a in EA.get_all_level_actors()),'Collision already placed'
    return instances([shifted(p,location_cm,yaw_deg) for p in manifest()['collision_assemblies'][cid]],prefix,True)
def capture(name='DioramaOverview',filename='Unreal_Diorama.png'):
    a=next(a for a in EA.get_all_level_actors() if a.get_actor_label()=='SP_'+name);frame(a)
    return u.AutomationLibrary.take_high_res_screenshot(1600,1200,str(OUT/'Renders'/filename),camera=a,delay=1.,force_game_view=True)
