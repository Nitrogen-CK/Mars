"""Actual frame metadata for disposable room surfaces, including appearance scope."""
import json

def capture(controller,trial,label):
    import unreal as u
    s=trial.STATE;assert s and s['stage']=='surface_only' and controller.STATE['world']==s['world']
    folder=controller.STATE['out'];assert not (folder/(label+'.png')).exists() and not (folder/(label+'.json')).exists()
    u.GameplayStatics.set_game_paused(s['world'],True);trial.guard();trial.clean()
    _,hisms=s['core']._hism_snapshot(s['world']);assert hisms==s['before']
    rows=[]
    for a in s['created']:
        c=a.static_mesh_component
        assert c.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION
        rows.append(dict(path=a.get_path_name(),label=a.get_actor_label(),mesh=c.static_mesh.get_path_name(),pose=s['core']._pose(c.get_world_transform()),materials=[m.get_path_name() for m in c.get_materials()],collision=str(c.get_collision_enabled()),profile=str(c.get_collision_profile_name()),visible=c.is_visible(),hidden=c.get_editor_property('hidden_in_game'),shadow=c.cast_shadow))
    controller.capture(label)
    # Complete this newly-created sidecar in the same operation. The base
    # capture's source-only boundary is not true for an appearance trial.
    p=folder/(label+'.json');record=json.loads(p.read_text());record['art_state']=rows
    record['boundary']='Actual Main PIE, natural held/open lantern, three reviewed disposable NoCollision surface actors. Wall mesh may be the old or repaired private successor, explicitly recorded in art_state. Existing source HISMs/transforms/materials, physical collision, lights, water, props, gameplay and original packages remain unchanged. Teleport/paused appearance capture; not physical movement or pacing/multiplayer proof.'
    p.write_text(json.dumps(record,indent=2)+'\n');print('ACTUAL_SURFACE_TRIAL_METADATA_COMPLETED',label)
