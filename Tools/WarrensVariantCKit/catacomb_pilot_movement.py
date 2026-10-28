"""Bounded normal-input movement probes; no transform writes during a probe."""
import json,time
JOB=None
ROUTES={'main_aisle':([-22,74],[-22,80,1],.8),
        'husk_entry':([-23,74],[-26,74,1],.5),
        'cache_entry':([-13,85],[-8.5,88,1],.8),
        'tomb_circulation':([-20.5,77.5],[-14.5,77.5,1],.8),
        'omen_court_entry':([-2.5,77.3],[-2.5,79.4,1],.55)}
def prepare(trial,name):
    import unreal as u
    assert JOB is None and name in ROUTES and u.GameplayStatics.is_game_paused(trial.STATE['world'])
    at,target,duration=ROUTES[name];trial.VIEWS['move_'+name]=(at,target)
    u.GameplayStatics.set_game_paused(trial.STATE['world'],False);trial.position('move_'+name)
def start(trial,name):
    global JOB
    import unreal as u
    assert JOB is None and name in ROUTES and hasattr(u,'register_slate_pre_tick_callback')
    s=trial.STATE;w=s['world'];p=s['pawn'];helper=s['helper'];assert not u.GameplayStatics.is_game_paused(w)
    at,_,duration=ROUTES[name];expected=u.Vector((at[0]-70)*100,(at[1]-55)*100,77.2)
    assert (p.get_actor_location()-expected).length()<2
    subsystem,=[v for v in u.ObjectIterator(u.EnhancedInputLocalPlayerSubsystem) if v.get_path_name().startswith('/Engine/Transient.')]
    action,=[v for v in u.ObjectIterator(u.InputAction) if v.get_path_name()=='/Script/AngelscriptAssets.Mars_IA_Move']
    JOB=dict(trial=trial,name=name,duration=duration,start_time=u.GameplayStatics.get_time_seconds(w),start_real=time.perf_counter(),before=list(p.get_actor_location().to_tuple()),samples=[],released=False,done=False,input_subsystem=subsystem.get_path_name(),action=action.get_path_name())
    subsystem.inject_input_vector_for_action(action,u.Vector(1,0,0),[],[])
    def tick(delta):
        j=JOB
        if not j or j['done']:return
        try:
            elapsed=u.GameplayStatics.get_time_seconds(w)-j['start_time'];j['samples'].append(dict(time=elapsed,at=list(p.get_actor_location().to_tuple())))
            if not j['released'] and (elapsed>=duration or time.perf_counter()-j['start_real']>6):
                subsystem.inject_input_vector_for_action(action,u.Vector(0,0,0),[],[]);j['released']=True;j['released_at']=elapsed
            elif not j['released']:subsystem.inject_input_vector_for_action(action,u.Vector(1,0,0),[],[])
            if j['released'] and elapsed>=j['released_at']+.18:
                u.GameplayStatics.set_game_paused(w,True);j['after']=list(p.get_actor_location().to_tuple());j['done']=True
        except Exception as e:
            subsystem.inject_input_vector_for_action(action,u.Vector(0,0,0),[],[]);u.GameplayStatics.set_game_paused(w,True);j['error']=str(e);j['done']=True
    JOB['callback']=u.register_slate_pre_tick_callback(tick)
    print('ENHANCED_MOVEMENT_PROBE_STARTED',name,duration)
def collect():
    global JOB
    import unreal as u
    j=JOB;assert j and j['done'], 'Movement callback is still active; inspect before waiting again'
    u.unregister_slate_pre_tick_callback(j['callback']);assert j['released'] and 'error' not in j,j
    delta=[b-a for a,b in zip(j['before'],j['after'])];distance=sum(v*v for v in delta[:2])**.5
    result={k:v for k,v in j.items() if k not in ('trial','callback','start_real')};result['horizontal_distance_cm']=distance;result['delta_cm']=delta
    result['boundary']='Native Enhanced Input vector injection into the actual Mars_IA_Move action and sampled player positions through real simulation frames. Only starting placement is teleported; no transforms written during movement. Raw Ck button injection does not drive this legacy Enhanced Input axis. Focused clearance probe, not route duration/co-op/physical-keyboard proof.'
    path=j['trial'].RUN/('movement_'+j['name']+'_enhanced_r04.json');assert not path.exists();path.write_text(json.dumps(result,indent=2)+'\n')
    print('ENHANCED_MOVEMENT_RESULT',json.dumps(dict(name=j['name'],before=j['before'],after=j['after'],distance_cm=distance,samples=len(j['samples']),released=True)))
    view='after_move_'+j['name'];j['trial'].VIEWS[view]=([j['after'][0]/100+70,j['after'][1]/100+55],ROUTES[j['name']][1])
    j['trial'].STATE['stage']='D_enhanced_movement';j['trial'].STATE['view']=view;JOB=None
