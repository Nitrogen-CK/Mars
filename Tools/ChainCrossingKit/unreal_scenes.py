"""Owned, repeatable HISM library/diorama authoring and existing-tile dressing.

Run only in editor Python, outside PIE. Never rebuilds gameplay or Jolt.
Rollback existing tile edits: restore the timestamped .umap backups with editor
closed. Reapply removes only actors bearing OWNER; original actors stay intact.
"""
import json
import gc
from collections import defaultdict
from pathlib import Path
import unreal as u

HERE=Path(__file__).resolve().parent
OUT=HERE/'Output'
DEST='/Game/Mars/Environment/ChainCrossingKit'
MAIN='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP'
OWNER='Mars.ChainCrossingKit.Authoring.v1'
PREFIX='CCK_'
FOLDER='ChainCrossingKit'
EA=u.get_editor_subsystem(u.EditorActorSubsystem)
LES=u.get_editor_subsystem(u.LevelEditorSubsystem)
SS=u.get_engine_subsystem(u.SubobjectDataSubsystem)
ED=u.get_editor_subsystem(u.UnrealEditorSubsystem)

def clean():
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages(),'Unsaved map changes; refusing level switch'
    assert not u.EditorLoadingAndSavingUtils.get_dirty_content_packages(),'Unsaved content; save only owned imports before continuing'
    assert not u.GameplayStatics.get_all_actors_of_class(ED.get_game_world(),u.PlayerController) if ED.get_game_world() else True,'Stop PIE before authoring'

def prepare_switch():
    # Private Python script scopes can form cycles via function.__globals__.
    # Release unreachable UObject wrappers BEFORE Unreal's world-unload GC.
    clean();print('CHAIN_KIT_RELEASED_PYTHON_CYCLES',gc.collect())

def actor(cls,label,at=(0,0,0)):
    a=EA.spawn_actor_from_class(cls,u.Vector(*at),u.Rotator())
    assert a,label
    a.set_actor_scale3d(u.Vector(1,1,1))
    a.set_actor_label(PREFIX+label);a.tags=[u.Name(OWNER)];a.set_folder_path(FOLDER)
    return a

def clear_owned():
    for a in EA.get_all_level_actors():
        if OWNER in [str(t) for t in a.tags]:assert EA.destroy_actor(a)

def mesh_paths():
    paths={r['id']:DEST+'/Meshes/'+r['name'] for r in json.loads((OUT/'asset_manifest.json').read_text())['assets']}
    paths.update({k:'/Engine/BasicShapes/Cube' for k in ['BACKING_TX01','BACKING_TX02','SOURCE_GALLERY']})
    return paths

def add_instances(placements,pivot=(0,0,0),plan_frame=False,registry=None,material_root=None):
    groups=defaultdict(list)
    for p in placements:groups[p['id']].append(p)
    paths=mesh_paths() if registry is None else registry;counts={}
    for ident,rows in sorted(groups.items()):
        mesh=u.load_asset(paths[ident]);assert isinstance(mesh,u.StaticMesh),paths[ident]
        a=actor(u.Actor,ident);a.root_component.set_mobility(u.ComponentMobility.STATIC)
        h=SS.k2_gather_subobject_data_for_instance(a)[0]
        ch,reason=SS.add_new_subobject(u.AddNewSubobjectParams(parent_handle=h,new_class=u.HierarchicalInstancedStaticMeshComponent))
        c=u.SubobjectDataBlueprintFunctionLibrary.get_associated_object(u.SubobjectDataBlueprintFunctionLibrary.get_data(ch));assert c,str(reason)
        c.set_mobility(u.ComponentMobility.STATIC);c.set_static_mesh(mesh);c.set_collision_profile_name('NoCollision')
        c.set_editor_property('generate_overlap_events',False)
        if rows[0].get('material_path') or rows[0].get('material'):
            path=rows[0].get('material_path') or (material_root or DEST)+'/Materials/M_CCK_'+rows[0]['material']
            material=u.load_asset(path);assert material,path;c.set_material(0,material)
        if ident.startswith('BACKING') or ident=='CCS61':c.set_cast_shadow(False)
        for p in rows:
            at=[(p['at'][i]-pivot[i])*100 for i in range(3)]
            if not plan_frame:at[1]*=-1 # Same handedness conversion as the FBX vertices.
            if 'rotation' in p:
                r=p['rotation'];rot=u.Rotator(pitch=r[0],yaw=r[1],roll=r[2]) if plan_frame else u.Rotator(pitch=-r[1],yaw=-r[2],roll=r[0])
            else:rot=u.Rotator(pitch=0,yaw=p.get('yaw',0)*(1 if plan_frame else -1),roll=0)
            c.add_instance(u.Transform(location=u.Vector(*at),rotation=rot,scale=u.Vector(*p.get('scale',(1,1,1)))),world_space=True)
        assert c.get_instance_count()==len(rows)
        assert str(c.get_collision_profile_name())=='NoCollision'
        counts[ident]=len(rows)
    return counts

def camera(label,at,target):
    a=actor(u.CameraActor,label,[at[0]*100,-at[1]*100,at[2]*100])
    r=u.MathLibrary.find_look_at_rotation(a.get_actor_location(),u.Vector(target[0]*100,-target[1]*100,target[2]*100));a.set_actor_rotation(r,False)
    a.camera_component.set_editor_property('field_of_view',65)
    ED.set_level_viewport_camera_info(a.get_actor_location(),a.get_actor_rotation())
    return a

def light(label,at,intensity=1500,color=(1,.7,.4),radius=1000,blender_space=False):
    a=actor(u.PointLight,label,[at[0]*100,at[1]*100*(-1 if blender_space else 1),at[2]*100]);c=a.point_light_component
    c.set_mobility(u.ComponentMobility.MOVABLE);c.set_intensity(intensity);c.set_attenuation_radius(radius);c.set_light_color(u.LinearColor(*color,1))
    return a

def review_lighting():
    a=actor(u.PostProcessVolume,'ReviewExposure');a.set_editor_property('unbound',True);a.set_editor_property('priority',100)
    settings=a.get_editor_property('settings')
    for key,value in [('auto_exposure_min_brightness',1.0),('auto_exposure_max_brightness',1.0),('auto_exposure_bias',0.0),('ambient_cubemap_intensity',0.0),('bloom_intensity',0.0)]:
        settings.set_editor_property(key,value)
        settings.set_editor_property('override_'+key,True)
    a.set_editor_property('settings',settings)
    a=actor(u.DirectionalLight,'ReviewKey')
    a.set_actor_rotation(u.Rotator(pitch=-45,yaw=-45,roll=0),False)
    a.light_component.set_mobility(u.ComponentMobility.MOVABLE);a.light_component.set_intensity(30)
    a=actor(u.SkyLight,'ReviewSky');c=a.light_component;c.set_mobility(u.ComponentMobility.MOVABLE)
    c.set_editor_property('source_type',u.SkyLightSourceType.SLS_SPECIFIED_CUBEMAP)
    c.set_editor_property('cubemap',u.load_asset('/Engine/EngineResources/GrayLightTextureCube'))
    c.set_editor_property('lower_hemisphere_is_black',False);c.set_intensity(1)

def preview_world(kind):
    clean();path=DEST+'/Maps/ChainCrossing_'+kind+'_Mars_MAP'
    if u.EditorAssetLibrary.does_asset_exist(path):
        assert ED.get_editor_world().get_path_name().split('.')[0]==path,'Open target through guarded Monolith load_level first'
        existing=EA.get_all_level_actors()
        assert any(OWNER in [str(t) for t in a.tags] for a in existing),'Refusing unrelated map '+path
    else:assert LES.new_level(path,False)
    clear_owned()
    review_lighting()
    if kind=='KitLibrary':
        rows=json.loads((OUT/'asset_manifest.json').read_text())['assets']
        placements=[dict(id=r['id'],at=[(i%11-5)*6,(i//11)*7,0]) for i,r in enumerate(rows)]
        for i,r in enumerate(rows):
            a=actor(u.TextRenderActor,'Label_'+r['id'],[((i%11-5)*6)*100,-((i//11)*7-2.5)*100,20])
            a.text_render.set_text(r['id']+'  '+r['name'].split('_')[2]);a.text_render.set_world_size(28)
            a.set_actor_rotation(u.MathLibrary.find_look_at_rotation(a.get_actor_location(),u.Vector(3800,4000,4800)),False)
        camera('Library_Camera',(38,-40,48),(0,21,0))
        for x in [-20,0,20]:
            for y in [0,20,40]:light('LibraryStudio',(x,y,10),60,(.85,.88,1),2200,True)
    else:
        placements=json.loads((OUT/'diorama_instances.json').read_text())
        camera('Diorama_Camera',(22,-28,23),(5,1,1))
        for x in [-12,0,14]:light('DioramaStudio',(x,-3,7),40,(1,.7,.4),2200,True)
        light('DioramaCool',(18,6,6),30,(.3,.6,1),1800,True)
        for at in [(-12,0,2),(16,4.3,2.2)]:light('DioramaLantern',at,6,(1,.48,.13),600,True)
    counts=add_instances(placements)
    assert LES.save_current_level()
    report=dict(map=path,unique_meshes=len(counts),instances=sum(counts.values()),counts=counts,collision='NoCollision')
    (OUT/'Reports'/('unreal_'+kind+'.json')).write_text(json.dumps(report,indent=2))
    print('CHAIN_KIT_SCENE',report['map'],report['unique_meshes'],report['instances'])
    return report

def dress(tile):
    assert not any('Mars.WarrensVariantCKit.Authoring.v1' in [str(t) for t in a.tags] for a in EA.get_all_level_actors()),'This tile is owned by the complete Variant C pass; use WarrensVariantCKit/unreal_scenes.py'
    data=json.loads((OUT/'fitted_instances.json').read_text());assert tile in data['pivots']
    baseline=json.loads((OUT/'Reports/level_baseline.json').read_text())[tile]
    assert Path(baseline['backup']).is_file(),'No rollback copy for '+tile
    clean()
    assert ED.get_editor_world().get_path_name().split('.')[0]==baseline['asset'],'Open target through guarded Monolith load_level first'
    clear_owned()
    originals={a.get_actor_label():a for a in EA.get_all_level_actors()}
    # EditorActorSubsystem omits engine world-settings/brush/level-script placeholders.
    expected={a['label'] for a in baseline['actors'] if a['label'].startswith('Warrens_') or a['components']}
    assert expected.issubset(originals),'Original authored actor set changed: '+str(expected-set(originals))
    counts=add_instances([p for p in data['placements'] if p['tile']==tile],data['pivots'][tile],True)
    for change in data['visibility_overrides']:
        if change['tile']!=tile:continue
        a=originals[change['label']]
        a.set_actor_hidden_in_game(not change['visible'])
        for c in a.get_components_by_class(u.InstancedStaticMeshComponent):
            c.set_visibility(change['visible'],False)
            c.set_hidden_in_game(not change['visible'],False)
    # Quiet shared base surfaces also remove prototype grid bleed through joints.
    # Component overrides are confined to these three district packages.
    # Undo the previous pass's whole-tile overrides before applying a bounded pass.
    # Local veneer/backing instances now own all Canal/Brineworks surface changes.
    for old in baseline['actors']:
        a=originals.get(old['label'])
        if not a:continue
        comps={c.get_name():c for c in a.get_components_by_class(u.StaticMeshComponent)}
        for old_c in old['components']:
            for slot,path in enumerate(old_c.get('materials',[])):
                if path:comps[old_c['name']].set_material(slot,u.load_asset(path))
    base_materials={'floor':'TX02','wall':'TX01','ramp':'TX02','water':'FX_Water'} if tile=='WaterworksW' else {}
    material_overrides=[]
    for kind,key in base_materials.items():
        a=originals.get('Warrens_Greybox_'+kind)
        if not a:continue
        material=u.load_asset(DEST+'/Materials/M_CCK_'+key);assert material,key
        for c in a.get_components_by_class(u.StaticMeshComponent):
            c.set_material(0,material);material_overrides.append({'actor':a.get_actor_label(),'component':c.get_name(),'material':material.get_path_name()})
    # Emissive cards do not illuminate rooms in the project's SSGI renderer.
    # Lights belong to the same owned dressing pass, without touching exposure.
    lamps=[(69.5,30.35,-.1)] if tile=='WaterworksW' else [(x,y,-.1) for x,y in [(115,9),(129,9),(115,20),(129,20)]] if tile=='Brineworks' else []
    for i,at in enumerate(lamps):
        local=[at[k]-data['pivots'][tile][k] for k in range(3)]
        light('WallLamp_'+str(i),local,6,(1,.62,.28),500)
    for i,spec in enumerate(data.get('crossing_lights',[])):
        if spec['tile']!=tile:continue
        local=[spec['at'][k]-data['pivots'][tile][k] for k in range(3)]
        light('CrossingLamp_'+str(i),local,spec['intensity'],(1,.62,.28),450)
    for spec in data.get('light_overrides',[]):
        if spec['tile']==tile:
            a=originals[spec['label']];assert isinstance(a,u.PointLight)
            a.point_light_component.set_intensity(spec['intensity'])
    # Original collision, transforms, channel parameters and water geometry remain untouched.
    assert LES.save_current_level()
    report={'tile':tile,'asset':baseline['asset'],'instances':sum(counts.values()),'unique_meshes':len(counts),'counts':counts,'backup':baseline['backup'],'material_overrides':material_overrides}
    (OUT/'Reports'/('dressed_'+tile+'.json')).write_text(json.dumps(report,indent=2))
    print('CHAIN_KIT_DRESSED',tile,report['instances'],report['unique_meshes'])
    return report

def restore_main():
    clean();assert ED.get_editor_world().get_path_name().split('.')[0]==MAIN,'Open main through guarded Monolith load_level first'
    print('CHAIN_KIT_MAIN_RESTORED',ED.get_editor_world().get_path_name())

def frame_review_map():
    clean()
    assert ED.get_editor_world().get_path_name().startswith(DEST+'/Maps/')
    cameras=[a for a in EA.get_all_level_actors() if isinstance(a,u.CameraActor) and OWNER in [str(t) for t in a.tags]]
    assert len(cameras)==1
    ED.set_level_viewport_camera_info(cameras[0].get_actor_location(),cameras[0].get_actor_rotation())
    assert LES.save_current_level()
    print('CHAIN_KIT_REVIEW_CAMERA_FRAMED',cameras[0].get_actor_label())
