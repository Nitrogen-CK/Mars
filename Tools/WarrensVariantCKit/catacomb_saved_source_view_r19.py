"""Observe/capture the retained room in Main PIE; never stages art or saves assets."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-forage-props-r04/saved-source-r19'
STATE=None
VIEWS={'standing':([-22,74],[-18,80,1]),'wall_grazing':([-22,74],[-23.8,75.4,1.4]),'floor_grazing':([-22,74],[-21.3,76.5,.02]),'ceiling_grazing':([-22,74],[-20.5,76.5,3.4])}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def package(o):return o.get_path_name().split('.')[0] if o else None
def begin(source,core,helper):
    global STATE
    import unreal as u
    assert STATE is None and source.STATE['stage']=='saved' and len(source.STATE['reopens'])==2
    source.guard();assert source.STATE['source'].dirty()==dict(maps=[],content=[])
    w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world();assert w and w.get_path_name()=='/Game/Mars/Maps/UEDPIE_0_Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    m=source.STATE['m'];actors=list(u.GameplayStatics.get_all_actors_of_class(w,u.Actor));owned=[a for a in actors if m['owner'] in map(str,a.tags)]
    assert len(owned)==7 and {a.get_actor_label() for a in owned}=={r['label'] for r in m['new_actors']}
    assert not any('Mars.WarrensVariantC.CatacombPilot.R02.Trial' in map(str,a.tags) for a in actors)
    rows=[]
    for r in m['new_actors']:
        a,=[a for a in owned if a.get_actor_label()==r['label']];expected=dict(r['pose']);expected['at']=[v+d for v,d in zip(expected['at'],m['source_main_offset_cm'])]
        assert core._near(a.get_actor_transform(),source.transform(expected)) and a.get_class().get_path_name()==r['actor_class']
        assert a.root_component.get_editor_property('mobility')==u.ComponentMobility.MOVABLE
        row=dict(label=r['label'],path=a.get_path_name(),pose=core._pose(a.get_actor_transform()))
        if 'mesh' in r:
            c=a.static_mesh_component;assert package(c.static_mesh)==r['mesh'] and [package(v) for v in c.get_materials()]==r['materials'] and c.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION
            row.update(mesh=package(c.static_mesh),materials=[package(v) for v in c.get_materials()],collision='NoCollision')
        else:
            c,=a.get_components_by_class(u.PointLightComponent);v=r['light'];assert c.intensity==v['intensity'] and source.rgba(c.light_color)==v['color_rgba'] and c.attenuation_radius==v['radius'] and str(c.get_editor_property('intensity_units'))==v['units']
            if 'inner_cone' in v:assert c.inner_cone_angle==v['inner_cone'] and c.outer_cone_angle==v['outer_cone']
            row.update(light=dict(intensity=c.intensity,color=source.rgba(c.light_color),radius=c.attenuation_radius))
        rows.append(row)
    _,hisms=core._hism_snapshot(w);assert len(hisms)==383 and sum(len(v['instances']) for v in hisms.values())==45452
    for r in m['material_bindings']:
        matches=[c for a in actors if 'LI_Warrens_Catacomb' in a.get_path_name() for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent) if package(c.static_mesh)==r['mesh']];c,=matches
        assert package(c.get_material(r['slot']))==r['after'] and c.get_instance_count()==r['instance_count']
    typ=u.get_type_from_class(u.load_class(None,'/Script/Angelscript.Mars_Anchor_Forage_EntityScript'))
    target,=[o for o in u.ObjectIterator(typ) if isinstance(o.get_outer(),u.Actor) and o.get_outer().get_world()==w and o.get_path_name().startswith('/Temp/Game/') and 'CatacombHusk' in o.get_editor_property('AnchorId').export_text()]
    assert package(target.get_editor_property('ForagePresentation'))==m['forage_profile']['after']
    pawn=u.GameplayStatics.get_player_pawn(w,0);assert 'pack=true' in helper.inspect(pawn).splitlines()[0] and 'Item (Mars_ItemDef_Lantern)' in helper.inspect(pawn).splitlines()[0]
    assert u.SystemLibrary.get_console_variable_int_value('r.AntiAliasingMethod')==0
    OUT.mkdir(parents=True,exist_ok=False)
    STATE=dict(source=source,core=core,helper=helper,world=w,pawn=pawn,frames=[])
    receipt=dict(status='ACTUAL_SAVED_SOURCE_ROOM_PRESENT_WITHOUT_ART_OVERRIDES',world=w.get_path_name(),source_map_sha256=source.STATE['current_hash'],reopens=source.STATE['reopens'],new_actors=rows,hisms=383,instances=45452,source_profile=package(target.get_editor_property('ForagePresentation')),boundary='Fresh assembled Main PIE with retained source assets only; no room trial/staging calls, temporary materials or synthetic fixture. Prop variants were independently reviewed earlier. Viewing teleports do not prove a played expedition.')
    p=OUT/'READBACK.json';p.write_text(json.dumps(receipt,indent=2)+'\n');print('SAVED_SOURCE_NATIVE_READBACK',sha(p))
def position(view):
    import unreal as u
    s=STATE;assert view in VIEWS;u.GameplayStatics.set_game_paused(s['world'],False)
    at,target=VIEWS[view];p=u.Vector((at[0]-70)*100,(at[1]-55)*100,77.2);assert s['pawn'].teleport(p,u.Rotator())
    assert s['helper'].aim(s['pawn'],u.MathLibrary.find_look_at_rotation(u.Vector(p.x,p.y,112),u.Vector((target[0]-70)*100,(target[1]-55)*100,target[2]*100)))
    s['view']=view
def capture():
    import unreal as u
    s=STATE;assert not u.GameplayStatics.is_game_paused(s['world']);assert u.GameplayStatics.set_game_paused(s['world'],True)
    camera=u.GameplayStatics.get_player_camera_manager(s['world'],0);pawn=s['pawn'];assert abs(camera.get_fov_angle()-90)<.01
    lamp,=[c for a in u.GameplayStatics.get_all_actors_of_class(s['world'],u.Actor) if 'Ck_UnrealComponent_Host' in a.get_name() for c in a.get_components_by_class(u.PointLightComponent) if (c.get_world_location()-pawn.get_actor_location()).length()<250 and c.is_visible() and c.intensity>0 and c.attenuation_radius==700]
    path=OUT/('SavedSource_'+s['view']+'.png');assert not path.exists()
    record=dict(view=s['view'],world=s['world'].get_path_name(),source_map_sha256=s['source'].STATE['current_hash'],pawn=s['core']._pose(pawn.get_actor_transform()),camera=list(camera.get_camera_location().to_tuple()),rotation=list(camera.get_camera_rotation().to_tuple()),fov=camera.get_fov_angle(),inventory=s['helper'].inspect(pawn).splitlines()[0],real_lantern=dict(path=lamp.get_path_name(),pose=s['core']._pose(lamp.get_world_transform()),intensity=lamp.intensity,color=s['source'].rgba(lamp.light_color)),aa=u.SystemLibrary.get_console_variable_int_value('r.AntiAliasingMethod'),boundary='Actual saved source, no art overrides; real carried lantern state varies between views/runs. Not an exact cross-session lighting A/B or physical keyboard proof.')
    path.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n');s['frames'].append(path);u.AutomationLibrary.take_high_res_screenshot(1600,1000,str(path),delay=.2);print('SAVED_SOURCE_CAPTURE_QUEUED',path.name)
def release():
    global STATE
    import unreal as u
    s=STATE;assert len(s['frames'])==4
    for p in s['frames']:
        r=json.loads(p.with_suffix('.decode.json').read_text());assert r['status']=='PNG_CRC_AND_FULL_PIXEL_DECODE_PASSED' and r['sha256']==sha(p) and r['size']==[1600,1000]
    s['source'].guard();assert s['source'].STATE['source'].dirty()==dict(maps=[],content=[])
    assert u.GameplayStatics.set_game_paused(s['world'],False);STATE=None;print('SAVED_SOURCE_CAPTURE_RUNTIME_REFS_RELEASED')
