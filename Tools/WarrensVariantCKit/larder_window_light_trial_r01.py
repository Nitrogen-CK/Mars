"""One disposable upper-window RectLight, off/on; no source-light edits."""
import hashlib,importlib.util,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
RUN=ROOT/'Saved/WarrensCGameplay-20261024/LarderRollout'
OWNER='Mars.WarrensVariantC.Larder.WindowLightDiagnostic.R01'
STATE=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def own_light():
    s=STATE;c=s['light'];return dict(path=c.get_path_name(),pose=s['core']._pose(c.get_world_transform()),intensity=c.intensity,units=str(c.intensity_units),radius=c.attenuation_radius,width=c.source_width,height=c.source_height,rgba=[c.light_color.r,c.light_color.g,c.light_color.b,c.light_color.a],shadow=c.cast_shadows,barn_angle=c.barn_door_angle,barn_length=c.barn_door_length,visible=c.is_visible())

def check():
    import unreal as u
    s=STATE;assert s and s['stage']=='ready' and s['world']==u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() and u.GameplayStatics.is_game_paused(s['world'])
    s['surface'].guard();s['surface'].clean();assert sha(__file__)==s['tool_sha256']
    _,hisms=s['core']._hism_snapshot(s['world']);assert hisms==s['hisms'] and s['source_lights'].lights(s['world'])==s['lights']
    r=own_light();wanted=dict(s['own_before'],visible=s['on']);assert r==wanted

def begin(surface,capture,core,trial_capture):
    import unreal as u
    global STATE
    assert STATE is None and Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve()
    gate=json.loads((DOC/'NATIVE_WINDOW_LIGHT_GATE_R01.json').read_text());assert gate['status']=='APPROVED_DISPOSABLE_WINDOW_LIGHT_DIAGNOSTIC_ONLY' and gate['tool_sha256']==sha(__file__)
    proposal_path=DOC/'WINDOW_LIGHT_PROPOSAL_R01.json';assert sha(proposal_path)==gate['proposal_sha256'];p=json.loads(proposal_path.read_text())
    assert surface.STATE and surface.STATE['stage']=='surface_only' and capture.STATE['world']==surface.STATE['world'];w=surface.STATE['world'];assert u.GameplayStatics.is_game_paused(w)
    surface.guard();surface.clean();sp=importlib.util.spec_from_file_location('_window_light_source_readonly',Path(__file__).with_name('larder_finish_diagnostics_r01.py'));source=importlib.util.module_from_spec(sp);sp.loader.exec_module(source)
    _,hisms=core._hism_snapshot(w);STATE=dict(world=w,surface=surface,capture=capture,core=core,trial_capture=trial_capture,source_lights=source,lights=source.lights(w),hisms=hisms,actor=None,light=None,stage='preparing',on=False,tool_sha256=sha(__file__))
    previous={a.get_path_name() for a in u.GameplayStatics.get_all_actors_of_class(w,u.RectLight)}
    u.SystemLibrary.execute_console_command(w,'Summon /Script/Engine.RectLight',u.GameplayStatics.get_player_controller(w,0))
    a,=[a for a in u.GameplayStatics.get_all_actors_of_class(w,u.RectLight) if a.get_path_name() not in previous];STATE['actor']=a;a.tags=[u.Name(OWNER)];a.set_actor_label('WVC_Larder_WindowLightTrial_R01');c,=a.get_components_by_class(u.RectLightComponent);STATE['light']=c
    c.set_visibility(False);c.set_mobility(u.ComponentMobility.MOVABLE);c.set_intensity_units(u.LightUnits.LUMENS);c.set_intensity(p['intensity']);c.set_attenuation_radius(p['attenuation_radius_cm']);c.set_source_width(p['source_width_cm']);c.set_source_height(p['source_height_cm']);c.set_barn_door_angle(p['barn_door_angle']);c.set_barn_door_length(p['barn_door_length']);c.set_cast_shadows(True)
    rgba=p['colour_srgb_bytes'];c.set_light_color(u.MathLibrary.conv_color_to_linear_color(u.Color(r=rgba[0],g=rgba[1],b=rgba[2],a=rgba[3])));c.set_editor_property('use_temperature',False)
    a.set_actor_transform(u.Transform(location=u.Vector(*p['location_native_cm']),rotation=u.Rotator(**p['rotation'])),False,True)
    assert (a.get_actor_location()-u.Vector(*p['location_native_cm'])).length()<.001 and a.get_actor_rotation().quaternion().angular_distance(u.Rotator(**p['rotation']).quaternion())<.000001
    assert [c.light_color.r,c.light_color.g,c.light_color.b,c.light_color.a]==rgba and c.intensity==1800 and c.source_width==220 and c.source_height==400 and c.attenuation_radius==2400 and c.intensity_units==u.LightUnits.LUMENS
    STATE['own_before']=own_light();STATE['stage']='ready';check();out=RUN/'window_light_staged_r01.json';assert not out.exists();out.write_text(json.dumps(dict(status='ONE_HIDDEN_DISPOSABLE_RECT_LIGHT_STAGED',light=own_light(),five_original_lights=STATE['lights'],proposal_sha256=sha(proposal_path),tool_sha256=sha(__file__)),indent=2)+'\n');print('WINDOW_LIGHT_STAGED_OFF')

def visible(on):
    check();s=STATE;s['light'].set_visibility(bool(on));s['on']=bool(on);check();print('WINDOW_LIGHT_ON',on)

def capture(label):
    check();s=STATE;s['trial_capture'].capture(s['capture'],s['surface'],label);p=s['capture'].STATE['out']/(label+'.json');r=json.loads(p.read_text());r['window_light']=own_light();r['five_original_room_lights']=s['lights'];r['boundary']+=' One extra temporary upper-window RectLight is independently off/on as recorded; five original room lights remain exact. No exposure, AA, held-lantern, brine, prop or source edits.';p.write_text(json.dumps(r,indent=2)+'\n')

def restore_request():
    import unreal as u
    check();s=STATE;visible(False);s['destroy_path']=s['actor'].get_path_name();assert OWNER in [str(v) for v in s['actor'].tags];s['actor'].destroy_actor();assert not u.SystemLibrary.is_valid(s['actor']) or s['actor'].is_actor_being_destroyed();s['actor']=None;s['light']=None;s['stage']='await_absence';print('WINDOW_LIGHT_DESTROY_REQUESTED_CHECK_NEXT_TURN')

def confirm_restored():
    import unreal as u
    global STATE
    s=STATE;assert s and s['stage']=='await_absence' and s['world']==u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert s['destroy_path'] not in {a.get_path_name() for a in u.GameplayStatics.get_all_actors_of_class(s['world'],u.Actor)} and not u.SystemLibrary.is_valid(u.find_object(None,s['destroy_path']))
    assert s['source_lights'].lights(s['world'])==s['lights'];_,hisms=s['core']._hism_snapshot(s['world']);assert hisms==s['hisms'];s['surface'].guard();s['surface'].clean();p=RUN/'window_light_restored_r01.json';assert not p.exists();p.write_text(json.dumps(dict(status='LATER_TURN_ACTUAL_LIGHT_ABSENCE_ORIGINAL_FIVE_LIGHTS_AND_ALL_HISMS_EXACT',removed=s['destroy_path'],tool_sha256=sha(__file__)),indent=2)+'\n');STATE=None;print('WINDOW_LIGHT_ABSENT_REFERENCES_RELEASED')

def abort(surface):
    global STATE
    s=STATE
    try:
        if s and s['actor'] and s['stage']!='await_absence':s['actor'].destroy_actor()
    finally:
        STATE=None;surface.abort()
