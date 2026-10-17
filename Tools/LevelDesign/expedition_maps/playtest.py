"""Observed single-player playtests. Movement/input only: never spawn rewards or set puzzle/food state."""
import heapq
import json
import math
import re
import time
from pathlib import Path

import unreal as u
import build_maps

OUT = build_maps.OUT / 'playtest-r02'
session = globals().get('session')
move_handle = globals().get('move_handle')
gesture_handle = globals().get('gesture_handle')
stage_handle = globals().get('stage_handle')


def begin(index, label=None):
    global session
    world = u.EditorLevelLibrary.get_game_world()
    assert world, 'Start normal PIE first'
    pc = u.GameplayStatics.get_player_controller(world, 0)
    pawn = pc.get_controlled_pawn()
    assert pawn, 'Wait for the actual player'
    assert u.GameplayStatics.get_world_delta_seconds(world)<.1,'Restore the Unreal window before testing: world is throttled below 10 FPS'
    data = json.loads((build_maps.DATA / 'layouts.json').read_text())[index]
    helper = u.new_object(u.load_class(None, '/Script/Angelscript.Mars_ExpeditionAcceptance'), outer=pc)
    session = dict(index=index, name=build_maps.MAPS[index], data=data, world=world, pc=pc, pawn=pawn,
                   helper=helper, started=time.monotonic(), events=[], held_keys=set(),
                   run=label or time.strftime('run-%Y%m%d-%H%M%S'), active=0.,
                   game_started=u.GameplayStatics.get_time_seconds(world))
    folder().mkdir(parents=True, exist_ok=True)
    note('begin')
    screenshot('spawn')


def folder():
    return OUT / session['name'] / session['run']


def pos(at):
    w, d = session['data']['envelope']
    return u.Vector((at[0] - w/2)*100, (at[1] - d/2)*100, at[2]*100)


def note(event, **extra):
    state = session['helper'].call_method('Inspect', args=(session['pawn'],))
    game_elapsed=u.GameplayStatics.get_time_seconds(session['world'])-session.get('game_started',0.)
    row = dict(t=round(time.monotonic()-session['started'], 2), active_seconds=round(session['active'],2),
               game_elapsed_seconds=round(game_elapsed,2),play_elapsed_seconds=round(game_elapsed-session.get('excluded_idle',0),2),
               excluded_driver_idle_seconds=round(session.get('excluded_idle',0),2),
               frame_delta_seconds=round(u.GameplayStatics.get_world_delta_seconds(session['world']),4),
               event=event,state=state,**extra)
    session['events'].append(row)
    (folder() / 'run.json').write_text(json.dumps(session['events'], indent=2))
    print(json.dumps(row))


def screenshot(label):
    # Engine's screenshot path includes prompts/HUD. Scene-only captures hid the interaction feedback.
    path=str(folder() / (label+'.png')).replace('\\','/')
    u.SystemLibrary.execute_console_command(session['world'], 'Shot SHOWUI filename="'+path+'" -nosuffix', session['pc'])


def aim(at):
    camera = u.GameplayStatics.get_player_camera_manager(session['world'], 0)
    rotation = u.MathLibrary.find_look_at_rotation(camera.get_camera_location(), pos(at))
    assert session['helper'].call_method('Aim', args=(session['pawn'], rotation))


def key(name, down):
    assert session['helper'].call_method('Key', args=(session['pawn'], u.Name(name), down))
    if down:
        session['held_keys'].add(name)
    else:
        session['held_keys'].discard(name)


def look(yaw=0, pitch=0):
    assert session['helper'].call_method('Look', args=(session['pawn'], u.Vector(yaw, pitch, 0)))


def tap(name='LeftMouseButton', hold=.2):
    key(name, True)
    state=dict(start=time.monotonic(),handle=None)
    def release(dt):
        if time.monotonic()-state['start']>=hold:
            key(name,False)
            u.unregister_slate_post_tick_callback(state['handle'])
    state['handle']=u.register_slate_post_tick_callback(release)


def later(seconds, action):
    state=dict(start=time.monotonic(),handle=None)
    def tick(dt):
        if time.monotonic()-state['start']>=seconds:
            u.unregister_slate_post_tick_callback(state['handle'])
            try:action()
            except Exception:
                pause('driver callback failed; diagnose before continuing')
                raise
    state['handle']=u.register_slate_post_tick_callback(tick)


def items(token):
    text=session['helper'].call_method('WorldItems',args=(session['pawn'],))
    result=[]
    for line in text.splitlines():
        if token.lower() not in line.lower() or 'mount=World' not in line: continue
        coords=re.findall(r'[XYZ]=(-?[0-9.]+)',line)
        if len(coords)==3:
            result.append((line.split('|')[0],u.Vector(*map(float,coords))))
    return result


def approach_item(token,on_complete=None):
    here=session['pawn'].get_actor_location()
    candidates=items(token); assert candidates,token+' not found in world'
    name,target=min(candidates,key=lambda row:(row[1]-here).length_squared())
    dx,dy=here.x-target.x,here.y-target.y; distance=max(1,math.hypot(dx,dy))
    target_at=[target.x/100+session['data']['envelope'][0]/2,target.y/100+session['data']['envelope'][1]/2,target.z/100]
    # Gameplay view trace is 250 cm. A 200 cm stance clears the full-width supply plinth and remains in actual reach.
    stance=[target_at[0]+dx/distance*2.0,target_at[1]+dy/distance*2.0,(here.z-75)/100]
    def pickup():
        global gesture_handle
        assert gesture_handle is None
        tracking=dict(t=0.)
        def track(dt):
            global gesture_handle
            tracking['t']+=dt
            current=items(token)
            if not current:
                u.unregister_slate_post_tick_callback(gesture_handle);gesture_handle=None
                pause('item disappeared before pickup');return
            _,centre=min(current,key=lambda row:(row[1]-session['pawn'].get_actor_location()).length_squared())
            aim([centre.x/100+session['data']['envelope'][0]/2,centre.y/100+session['data']['envelope'][1]/2,centre.z/100])
            if tracking['t']>=.65:
                # Stop tracking when Use starts, respecting the grab's view hold.
                u.unregister_slate_post_tick_callback(gesture_handle);gesture_handle=None;tap()
        gesture_handle=u.register_slate_post_tick_callback(track)
        later(1.5,lambda:note('item-use-result',item=name))
        def finish():
            state=session['helper'].call_method('Inspect',args=(session['pawn'],)).splitlines()[0]
            success=('pack=true' in state) if 'Backpack' in token else token.lower() in state.lower()
            if not success: pause('item use did not acquire '+token)
            elif on_complete: on_complete()
            else: pause('inspect pickup result')
        later(1.6,finish)
    walk([stance],'take-'+token,tolerance=25,on_arrive=pickup)


def use_at(at, label='use', wait=1.8, on_complete=None):
    resume();aim(at)
    later(.3,lambda:tap())
    later(wait,lambda:note(label))
    later(wait+.1,on_complete or (lambda:pause('inspect '+label)))


def stop():
    global move_handle,gesture_handle,stage_handle
    if move_handle is not None:
        u.unregister_slate_post_tick_callback(move_handle)
        move_handle = None
    if gesture_handle is not None:
        u.unregister_slate_post_tick_callback(gesture_handle);gesture_handle=None
    if stage_handle is not None:
        u.unregister_slate_post_tick_callback(stage_handle);stage_handle=None
    for name in list(session['held_keys']):
        key(name, False)


def pause(reason='operator'):
    u.GameplayStatics.set_game_paused(session['world'], True)
    note('pause', reason=reason)


def resume():
    u.GameplayStatics.set_game_paused(session['world'], False)
    note('resume')


def walk(points, label, tolerance=90, on_arrive=None):
    """Native movement/collision, with a stalled-path failure instead of teleport/retry."""
    global move_handle
    assert move_handle is None, 'Movement already running'
    if 'operating=false' not in session['helper'].call_method('Inspect',args=(session['pawn'],)):
        pause('driver attempted movement before station leave')
        raise AssertionError('Leave the station before walking')
    resume()
    targets = [pos(p) for p in points]
    state = dict(i=0, elapsed=0., stagnant=0., previous=session['pawn'].get_actor_location(),last=time.monotonic(),aimed=-1)
    note('walk-start', label=label, points=points)
    def tick(dt):
        global move_handle
        if not u.SystemLibrary.is_valid(session['pawn']):
            u.unregister_slate_post_tick_callback(move_handle); move_handle=None
            return
        state['elapsed'] += dt
        now=time.monotonic(); session['active']+=now-state['last']; state['last']=now
        at = session['pawn'].get_actor_location()
        target = targets[state['i']]
        dx, dy = target.x-at.x, target.y-at.y
        distance = math.hypot(dx, dy)
        if distance <= tolerance:
            state['i'] += 1
            state['stagnant'] = 0.
            if state['i'] == len(targets):
                u.unregister_slate_post_tick_callback(move_handle); move_handle=None
                note('arrive', label=label, travel_seconds=state['elapsed'])
                screenshot(label)
                if on_arrive: on_arrive()
                else: pause('waypoint inspection; excluded from active travel')
                return
        else:
            if state['aimed']!=state['i']:
                p=points[state['i']]
                aim((p[0],p[1],at.z/100+.35)); state['aimed']=state['i']
            moved = (at-state['previous']).length()
            state['stagnant'] = state['stagnant']+dt if moved<1 else 0.
            if state['stagnant'] > 3 or state['elapsed'] > 120:
                u.unregister_slate_post_tick_callback(move_handle); move_handle=None
                note('blocked', label=label, remaining_cm=distance)
                screenshot(label+'-blocked')
                pause('blocked path; diagnose before retry')
                return
            session['pawn'].add_movement_input(u.Vector(dx/distance, dy/distance, 0), 1, False)
        state['previous'] = at
    move_handle = u.register_slate_post_tick_callback(tick)


def go(node_id,on_arrive=None,arrival_offset=(0,0,0)):
    nodes = {n['id']: n for n in session['data']['nodes']}
    at = session['pawn'].get_actor_location()
    source = min(nodes, key=lambda k: (pos(nodes[k]['at'])-at).length_squared())
    graph = {k: [] for k in nodes}
    for e in session['data']['edges']:
        a,b = e['a'],e['b']
        distance = (pos(nodes[a]['at'])-pos(nodes[b]['at'])).length()
        graph[a].append((b,distance,e['via']))
        graph[b].append((a,distance,list(reversed(e['via']))))
    queue = [(0,source,[])]; visited=set()
    while queue:
        cost,node,path=heapq.heappop(queue)
        if node in visited: continue
        visited.add(node)
        if node==node_id:
            arrival=[nodes[node]['at'][i]+arrival_offset[i] for i in range(3)]
            walk(route_around_censer(path+[arrival]), 'to-'+node_id,on_arrive=on_arrive)
            return
        for nxt,dist,via in graph[node]:
            heapq.heappush(queue,(cost+dist,nxt,path+[nodes[node]['at']]+via))
    raise RuntimeError('No authored route')


def route_around_censer(points):
    """Choose the visible permanent lane around the timed lane's divider and staggered crates."""
    node_id=['B','L','S','SE'][session['index']]
    centre=next(n['at'] for n in session['data']['nodes'] if n['id']==node_id)
    axis=(1,0) if session['index']==0 else (0,1)
    side=(0,-3.5) if session['index']==0 else (3.5,0)
    here=session['pawn'].get_actor_location()
    previous=[here.x/100+session['data']['envelope'][0]/2,here.y/100+session['data']['envelope'][1]/2,(here.z-75)/100]
    result=[]
    for i,point in enumerate(points):
        if point==centre:
            before=points[i-1] if i else previous
            following=points[i+1] if i+1<len(points) else centre
            entry=-1 if sum((before[j]-centre[j])*axis[j] for j in range(2))<0 else 1
            leave=-1 if sum((following[j]-centre[j])*axis[j] for j in range(2))<0 else 1
            result.append([centre[0]+side[0]+axis[0]*entry*6.5,centre[1]+side[1]+axis[1]*entry*6.5,centre[2]])
            if following==centre:
                result.append([centre[0]+side[0],centre[1]+side[1],centre[2]])
            else:
                result.append([centre[0]+side[0]+axis[0]*leave*6.5,centre[1]+side[1]+axis[1]*leave*6.5,centre[2]])
                # A departure toward the opposite court must first round the whole lane enclosure.
                # A diagonal from the bypass mouth can cut back through the outer masonry wall.
                side_dir=(side[0]/3.5,side[1]/3.5)
                if sum((following[j]-centre[j])*side_dir[j] for j in range(2)) < -6:
                    result.append([centre[0]-side_dir[0]*8+axis[0]*leave*6.5,
                                   centre[1]-side_dir[1]*8+axis[1]*leave*6.5,centre[2]])
                dx,dy=following[0]-centre[0],following[1]-centre[1];length=max(1,math.hypot(dx,dy))
                result.append([centre[0]+dx/length*14,centre[1]+dy/length*14,centre[2]])
        else:result.append(point)
    return result


def duel(seconds=25,on_complete=None):
    """Play the nearest live encounter with camera, movement and mapped cleaver input only."""
    global move_handle
    assert move_handle is None
    resume()
    state=dict(elapsed=0.,next_hit=.4,next_read=0.,target=None,captured=False)
    note('combat-start')
    def tick(dt):
        global move_handle
        state['elapsed']+=dt
        if state['elapsed']>=state['next_read']:
            text=session['helper'].call_method('Inspect',args=(session['pawn'],))
            rows=[]
            for line in text.splitlines():
                if not line.startswith('crawler') or 'dead=true' in line: continue
                xyz=re.findall(r'[XYZ]=(-?[0-9.]+)',line)
                if len(xyz)==3:
                    candidate=u.Vector(*map(float,xyz))
                    if (candidate-session['pawn'].get_actor_location()).length()<2000:
                        rows.append(candidate)
            if not rows or state['elapsed']>=seconds or 'health=0.0 ' in text:
                u.unregister_slate_post_tick_callback(move_handle); move_handle=None
                note('combat-stop',reason='no live target' if not rows else 'time or health limit')
                screenshot('combat-result')
                if not rows and on_complete: on_complete()
                else: pause('inspect combat result')
                return
            here=session['pawn'].get_actor_location()
            state['target']=min(rows,key=lambda v:(v-here).length_squared())
            state['next_read']=state['elapsed']+.1
        target=state['target']; here=session['pawn'].get_actor_location()
        camera=u.GameplayStatics.get_player_camera_manager(session['world'],0)
        rotation=u.MathLibrary.find_look_at_rotation(camera.get_camera_location(),target)
        session['helper'].call_method('Aim',args=(session['pawn'],rotation))
        dx,dy=target.x-here.x,target.y-here.y;dist=max(1,math.hypot(dx,dy))
        if dist>150:
            session['pawn'].add_movement_input(u.Vector(dx/dist,dy/dist,0),1,False)
        if dist<230 and state['elapsed']>=state['next_hit']:
            if not state['captured']:
                screenshot('combat-live-'+str(sum(e['event']=='combat-start' for e in session['events'])))
                state['captured']=True
            note('combat-swing',distance_cm=dist)
            tap(hold=.12);state['next_hit']=state['elapsed']+.8
    move_handle=u.register_slate_post_tick_callback(tick)


def gate_clear(kind):
    data=json.loads((build_maps.OUT/'construction.json').read_text())[session['index']]
    gate=next(e for e in data['entities'] if kind in e['cls'] and ('Gate' in e['cls'] or 'Shutter' in e['cls']))
    at=pos(gate['at']);at.z+=85
    ux,uy=build_maps.rotate(1,0,gate['yaw']);delta=u.Vector(ux*150,uy*150,0)
    hit=u.SystemLibrary.capsule_trace_single(session['world'],at-delta,at+delta,39,75,
            u.TraceTypeQuery.TRACE_TYPE_QUERY1,False,[session['pawn']],u.DrawDebugTrace.NONE)
    note('gate-observation',kind=kind,clear=not bool(hit))
    return not bool(hit)


def station_point(kind, local=(0, 0, 0)):
    data=json.loads((build_maps.OUT/'construction.json').read_text())[session['index']]
    station=next(e for e in data['entities'] if e['cls'].endswith('_'+kind+'Station_EntityScript'))
    dx,dy=build_maps.rotate(local[0],local[1],station['yaw'])
    return [station['at'][0]+dx,station['at'][1]+dy,station['at'][2]+local[2]]


def station_stance(kind, local_y=0, on_arrive=None):
    walk([station_point(kind,(-1.5,local_y,0))], 'approach-'+kind,tolerance=25,on_arrive=on_arrive)


def ensure_selected(token):
    state=session['helper'].call_method('Inspect',args=(session['pawn'],))
    # Restrict each match to its individual slot; the diagnostic line contains all three.
    slots=re.findall(r'slot([123])=(.*?)(?= slot[123]=| held=| operating=|$)',state.splitlines()[0])
    slot=next((int(i) for i,item in slots if token.lower() in item.lower()),None)
    assert slot is not None, token+' not in bag: '+state
    selected=state.split(' selected=',1)[1].split(' slot1=',1)[0]
    if token.lower() not in selected.lower():
        tap(['One','Two','Three'][slot-1])


def select_item(token):
    resume();ensure_selected(token);later(.7,lambda:pause('selected '+token))


def gather_route(with_kit=True,on_return=None):
    """Entrance kit, guarded harvest and hunt, then return with real ingredients. Stops on blocked movement."""
    nodes={n['id']:n for n in session['data']['nodes']}
    root=nodes['R']['at']; crop=[root[0]-9,root[1]-4,root[2]+1.15]
    stance=[crop[0],crop[1]-1.4,root[2]]
    def hunt():
        ensure_selected('Cleaver');later(.7,lambda:duel(on_complete=lambda:approach_item('MeatSlab',on_complete=on_return or (lambda:go('K')))))
    def harvest():
        aim(crop);later(.3,lambda:tap());later(1.4,lambda:note('harvest-strike'))
        later(1.5,lambda:approach_item('Mushroom',on_complete=lambda:go('H',on_arrive=hunt)))
    def root_fight():
        ensure_selected('Cleaver');later(.7,lambda:duel(on_complete=lambda:walk([stance],'harvest-bed',tolerance=20,on_arrive=harvest)))
    if with_kit:
        approach_item('Cleaver',on_complete=lambda:approach_item('Backpack',on_complete=lambda:go('R',on_arrive=root_fight)))
    else:
        go('R',on_arrive=root_fight)


def skimmer_to(target, seconds=2, on_complete=None):
    """Ease mouse look along a carry, using the station's read-only current target."""
    global gesture_handle
    assert gesture_handle is None
    text=session['helper'].call_method('Inspect',args=(session['pawn'],))
    match=re.search(r'target=\(?X=([-0-9.]+) Y=([-0-9.]+)',text)
    assert match, text
    start=list(map(float,match.groups())); issued=start[:]
    state=dict(t=0.)
    resume()
    def tick(dt):
        global gesture_handle
        state['t']+=dt;alpha=min(1,state['t']/seconds);ease=alpha*alpha*(3-2*alpha)
        wanted=[start[i]+(target[i]-start[i])*ease for i in range(2)]
        look(yaw=(wanted[1]-issued[1])/1.6,pitch=-(wanted[0]-issued[0])/1.6)
        issued[:]=wanted
        if alpha>=1:
            u.unregister_slate_post_tick_callback(gesture_handle);gesture_handle=None
            later(.6,on_complete or (lambda:pause('inspect skimmer carry')))
    gesture_handle=u.register_slate_post_tick_callback(tick)


def batter_load():
    """Dock a real tray, deposit the harvested mushroom, feed and coat through the mapped controls."""
    kitchen=next(n['at'] for n in session['data']['nodes'] if n['id']=='K')
    dock=station_point('Batter',(0,-.8,.715))
    def verify(label,token,next_action):
        note(label)
        text=session['helper'].call_method('Inspect',args=(session['pawn'],))
        if token not in text: pause('unexpected '+label)
        else: next_action()
    def coat():
        key('LeftMouseButton',True)
        later(3.4,lambda:key('LeftMouseButton',False))
        later(4.1,lambda:pause('inspect actual batter coat'))
    def feed():
        verify('batter-operating','operating=true',lambda:tap('Q'))
        later(2.2,lambda:verify('batter-admitted','batter_pieces=1',coat))
    def deposit():
        ensure_selected('Mushroom')
        later(.7,lambda:use_at(dock,'mushroom-on-raw-tray',on_complete=lambda:use_at(station_point('Batter',(0,0,.5)),'operate-batter',on_complete=feed)))
    def dock_tray():
        station_stance('Batter',-.8,on_arrive=lambda:use_at(dock,'batter-tray-docked',on_complete=deposit))
    walk([[kitchen[0],kitchen[1]+10,kitchen[2]]],'kitchen-stock-approach',on_arrive=lambda:approach_item('Platter_Large',on_complete=dock_tray))


def carry_battered_to_fry():
    kitchen=next(n['at'] for n in session['data']['nodes'] if n['id']=='K')
    stance=station_point('Fry',(-1.5,-.85,0))
    walk([[kitchen[0],kitchen[1]-3.2,kitchen[2]],[kitchen[0],stance[1],kitchen[2]],stance],
         'carry-battered-tray-to-fryer',tolerance=25,
         on_arrive=lambda:use_at(station_point('Fry',(0,-.85,.715)),'dock-battered-fryer-input'))


def batter_finish():
    def take_output():
        leave_station(lambda:use_at(station_point('Batter',(-.20,.8,.76)),'take-battered-tray',on_complete=carry_battered_to_fry))
    def takeout():
        tap('RightMouseButton');later(1.5,take_output)
    def operate():
        use_at(station_point('Batter',(0,0,.5)),'reoperate-batter',on_complete=takeout)
    def move_output():
        station_stance('Batter',.8,on_arrive=lambda:use_at(station_point('Batter',(0,.8,.715)),'dock-batter-output',on_complete=operate))
    leave_station(lambda:use_at(station_point('Batter',(0,-.8,.715)),'take-empty-batter-input',on_complete=move_output))


def leave_station(on_complete=None):
    # Let releases queued during an operator inspection pause drain before the next press.
    resume();later(.25,lambda:tap('Tab'))
    def check():
        text=session['helper'].call_method('Inspect',args=(session['pawn'],))
        note('station-leave-result')
        if 'operating=true' in text: pause('leave did not complete')
        elif on_complete: on_complete()
        else: pause('left station')
    later(1.2,check)


def fry_load():
    kitchen=next(n['at'] for n in session['data']['nodes'] if n['id']=='K')
    def feed():
        tap('Q');later(2.2,lambda:pause('inspect actual fryer admission'))
    def dock():
        stance=station_point('Fry',(-1.5,.9,0))
        walk([[kitchen[0],kitchen[1]+10,kitchen[2]],[kitchen[0],stance[1],kitchen[2]],stance],
             'carry-empty-output-tray',tolerance=25,
             on_arrive=lambda:use_at(station_point('Fry',(.4,.9,.715)),'dock-fryer-output',
                 on_complete=lambda:use_at(station_point('Fry',(0,0,.5)),'operate-fryer',on_complete=feed)))
    walk([[kitchen[0],kitchen[1]+10,kitchen[2]]],'kitchen-small-tray-approach',
         on_arrive=lambda:approach_item('Platter',on_complete=dock))


def fry_retrieve():
    text=session['helper'].call_method('Inspect',args=(session['pawn'],))
    match=re.search(r'centre=X=([-0-9.]+) Y=([-0-9.]+) Z=([-0-9.]+) where=Oil',text)
    assert match,text
    centre=u.Vector(*map(float,match.groups())); root=pos(station_point('Fry'))
    # The authored fryer faces 180 degrees; use its manifest yaw for the measured world-to-root conversion.
    data=json.loads((build_maps.OUT/'construction.json').read_text())[session['index']]
    yaw=next(e['yaw'] for e in data['entities'] if e['cls']=='Mars_FryStation_EntityScript')
    target=build_maps.rotate(centre.x-root.x,centre.y-root.y,-yaw)
    def under_food():
        # Enter beneath the floating piece. Dipping directly on top pins it under the disc.
        skimmer_to(target,seconds=1.5,on_complete=fry_lift_when_golden)
    resume();later(.25,lambda:key('LeftMouseButton',True));later(1.4,under_food)


def fry_lift_when_golden():
    """Read the actual heat while holding the dip; release the mapped button when the shell is golden."""
    global gesture_handle
    assert gesture_handle is None
    state=dict(t=0.,read=0.)
    def tick(dt):
        global gesture_handle
        state['t']+=dt
        if state['t']<state['read']:return
        state['read']=state['t']+.15
        text=session['helper'].call_method('Inspect',args=(session['pawn'],)).splitlines()[0]
        done='pale=0 overdone=0' in text
        failed='lost=1' in text or 'overdone=0' not in text or state['t']>12
        if done or failed:
            u.unregister_slate_post_tick_callback(gesture_handle);gesture_handle=None
            key('LeftMouseButton',False)
            later(1.6,lambda:pause('inspect real skimmer retrieval' if done else 'fryer heat did not complete cleanly'))
    gesture_handle=u.register_slate_post_tick_callback(tick)


def fry_pour():
    text=session['helper'].call_method('Inspect',args=(session['pawn'],))
    assert 'scoop=1 ' in text and 'clear_rim=true' in text,text
    def pour():
        key('LeftMouseButton',True)
        later(2.5,lambda:key('LeftMouseButton',False))
        later(7,lambda:pause('inspect real basket drain'))
    skimmer_to((15,20),seconds=1.5,
        on_complete=lambda:skimmer_to((0,90),seconds=3.5,on_complete=pour))


def fry_finish():
    text=session['helper'].call_method('Inspect',args=(session['pawn'],))
    assert 'drained=1 ' in text,text
    initial=re.findall(r'[XYZ]=(-?[0-9.]+)',session['events'][0]['state'].split(' health=')[0])
    start=u.Vector(*map(float,initial))
    entrance=min((n for n in session['data']['nodes'] if n['kind']=='spawn'),key=lambda n:(pos(n['at'])-start).length_squared())['id']
    def complete():
        note('available-loop-complete-at-entrance',world_items=session['helper'].call_method('WorldItems',args=(session['pawn'],)),
             limits='standalone map loop; camp travel separately tested; no service scoring or meal delivery')
        screenshot('cooked-dish-returned-to-entrance');pause('available map loop finished; review pacing and dish ledger')
    def carry():
        state=session['helper'].call_method('Inspect',args=(session['pawn'],)).splitlines()[0]
        if 'Platter' not in state.split(' held=',1)[1]:pause('finished tray was not picked up');return
        kitchen=next(n['at'] for n in session['data']['nodes'] if n['id']=='K')
        # Return to the central aisle before taking the district exit.
        walk([[kitchen[0],kitchen[1],kitchen[2]]],'leave-kitchen-with-dish',
             on_arrive=lambda:go(entrance,on_arrive=complete))
    def plated():
        note('cooked-plated-dish',world_items=session['helper'].call_method('WorldItems',args=(session['pawn'],)))
        screenshot('cooked-mushroom-output')
        leave_station(lambda:use_at(station_point('Fry',(.295,.9,.76)),'take-cooked-dish',on_complete=carry))
    resume();later(.25,lambda:tap('RightMouseButton'));later(1.8,plated)


def watch_cooking(stages=None):
    """Advance only after each input sequence has paused with its expected actual kernel result."""
    global stage_handle
    assert stage_handle is None
    stages=stages or [(['operating=true','fry_oil=1 '],fry_retrieve),
                      (['scoop=1 ','clear_rim=true','pale=0 overdone=0'],fry_pour),
                      (['basket=1 drained=1 lost=0'],fry_finish)]
    state=dict(i=0)
    def tick(dt):
        global stage_handle
        if not u.GameplayStatics.is_game_paused(session['world']):return
        tokens,action=stages[state['i']]
        actual=session['helper'].call_method('Inspect',args=(session['pawn'],))
        if not all(t in actual for t in tokens):
            u.unregister_slate_post_tick_callback(stage_handle);stage_handle=None
            note('sequence-stop',expected=tokens);return
        state['i']+=1
        if state['i']==len(stages):
            u.unregister_slate_post_tick_callback(stage_handle);stage_handle=None
        try:action()
        except Exception:
            if stage_handle is not None:u.unregister_slate_post_tick_callback(stage_handle);stage_handle=None
            pause('cooking input sequence failed');raise
    stage_handle=u.register_slate_post_tick_callback(tick)


def mourner():
    """Solve with the chef's carried pack, then actually walk into the latched room and recover the pack."""
    data=json.loads((build_maps.OUT/'construction.json').read_text())[session['index']]
    def entity(token): return next(e['at'] for e in data['entities'] if 'Gauntlet_Mourner_'+token in e['cls'])
    pack=entity('PackPlate');chef=entity('ChefPlate');gate=entity('AlcoveGate')
    def recover():
        gate_clear('Mourner')
        approach_item('Backpack',on_complete=lambda:pause('pack recovered after real Mourner solve'))
    def enter():
        gate_clear('Mourner')
        walk([[gate[0],gate[1]-1.2,gate[2]],[gate[0],gate[1]+2.2,gate[2]]],'enter-mourner-room',tolerance=30,
             on_arrive=lambda:walk([[gate[0],gate[1]-2,gate[2]]],'leave-mourner-room',on_arrive=recover))
    def stand_chef():
        walk([chef],'chef-plate',tolerance=15,on_arrive=lambda:later(1.2,enter))
    def drop():
        aim([pack[0],pack[1],pack[2]+.1]);equip_pack()
        later(.8,lambda:tap('R',hold=.15));later(2.0,stand_chef)
    walk([[pack[0],pack[1]-1.6,pack[2]]],'pack-plate-stance',tolerance=15,on_arrive=drop)


def equip_pack():
    text=session['helper'].call_method('Inspect',args=(session['pawn'],)).splitlines()[0]
    selected=text.split(' selected=',1)[1].split(' slot1=',1)[0]
    if 'Backpack' not in selected: tap('Four')


def stow_held():
    text=session['helper'].call_method('Inspect',args=(session['pawn'],)).splitlines()[0]
    selected=text.split(' selected=',1)[1].split(' slot1=',1)[0]
    if selected=='TOMBSTONE':return
    if 'Backpack' in selected:tap('Four');return
    slots=re.findall(r'slot([123])=(.*?)(?= slot[123]=| held=| operating=|$)',text)
    slot=next((int(i) for i,item in slots if selected==item),None)
    assert slot is not None,'Dock the hands-only item before working a control: '+selected
    tap(['One','Two','Three'][slot-1])


def pull_chain(at,yaw,label,on_complete=None):
    ux,uy=build_maps.rotate(.18,0,yaw)
    grip=[at[0]+ux,at[1]+uy,at[2]-1.42]
    resume();later(.25,lambda:aim(grip))
    later(.55,lambda:key('LeftMouseButton',True))
    later(1.6,lambda:look(pitch=38))
    later(2.2,lambda:key('LeftMouseButton',False))
    later(2.7,on_complete or (lambda:pause('inspect '+label)))


def porter():
    data=json.loads((build_maps.OUT/'construction.json').read_text())[session['index']]
    def entity(token):return next(e for e in data['entities'] if 'Gauntlet_Porter_'+token in e['cls'])
    slab=entity('Slab')['at'];gate=entity('Gate')['at'];chain=entity('Chain')
    def rescue():
        gate_clear('Porter')
        # Stow the worn pack to free both hands for the interior rescue chain.
        tap('Four')
        stance=[chain['at'][0],chain['at'][1]+1.6,gate[2]]
        walk([stance],'porter-rescue-chain-stance',tolerance=20,
             on_arrive=lambda:pull_chain(chain['at'],chain['yaw'],'porter-rescue',
                 on_complete=lambda:(gate_clear('Porter'),walk([[gate[0],gate[1]+.9,gate[2]],[gate[0],gate[1]-1.5,gate[2]]],
                     'porter-rescue-exit',tolerance=25))))
    def inside():
        gate_clear('Porter')
        later(9.2,rescue)
    def enter():
        gate_clear('Porter')
        walk([[gate[0],gate[1]-1.1,gate[2]],[gate[0],gate[1]+2.2,gate[2]]],
             'porter-grace-entry',tolerance=25,on_arrive=inside)
    def pick():
        gate_clear('Porter');approach_item('Backpack',on_complete=enter)
    def drop():
        aim([slab[0],slab[1],slab[2]+.1]);equip_pack()
        later(.8,lambda:tap('R',hold=.15));later(2.0,pick)
    walk([[slab[0],slab[1]-1.6,slab[2]]],'porter-pack-slab',tolerance=15,on_arrive=drop)


def bell(on_complete=None):
    data=json.loads((build_maps.OUT/'construction.json').read_text())[session['index']]
    circle=next(e['at'] for e in data['entities'] if 'Bell_CircleSeal' in e['cls'])
    origin=[circle[0]+4,circle[1]-2,circle[2]-1.2]
    x,y,z=origin
    def leave_reliquary():
        pocket=build_maps.POCKETS[(session['index'],'Bell')]
        parent=next(n['at'] for n in session['data']['nodes'] if n['id']==pocket['node'])
        mouth=list(pocket['mouth'])+[z]
        walk([[x,y+6.5,z],mouth,parent],'leave-bell-pocket',tolerance=25,
             on_arrive=on_complete or (lambda:pause('Bell solved through actual upper stair')))
    def enter():
        gate_clear('Bell')
        walk([[x+4.5,y+4.2,z+4],[x+4.5,y-3.6,z],[x,y+6.6,z],[x,y+10.3,z]],
             'bell-stair-return-and-reliquary',tolerance=25,
             on_arrive=leave_reliquary)
    def upper():
        use_at([x+4.9,y+6,z+5.1],'upper-triangle-seal',on_complete=enter)
    def stairs():
        gate_clear('Bell')
        walk([[x+4.5,y-3.6,z],[x+4.5,y+4.2,z+4],[x+4.1,y+6,z+4]],
             'climb-bell-gallery',tolerance=20,on_arrive=upper)
    stow_held()
    walk([[circle[0]+.9,circle[1],z]],'lower-circle-seal-stance',tolerance=20,
         on_arrive=lambda:use_at([circle[0]+.1,circle[1],circle[2]],'lower-circle-seal',on_complete=stairs))


def censer(on_complete=None):
    data=json.loads((build_maps.OUT/'construction.json').read_text())[session['index']]
    chain=next(e for e in data['entities'] if 'Censer_Chain' in e['cls'])
    gate=next(e for e in data['entities'] if 'Censer_Shutter' in e['cls'])
    axis=build_maps.rotate(1,0,gate['yaw']);ux,uy=build_maps.rotate(1.6,0,chain['yaw'])
    stance=[chain['at'][0]+ux,chain['at'][1]+uy,chain['at'][2]-2.6]
    centre=next(n['at'] for n in session['data']['nodes'] if n['id']==['B','L','S','SE'][session['index']])
    side=(0,-3.5) if session['index']==0 else (3.5,0)
    entry=[centre[0]+side[0]-axis[0]*6.5,centre[1]+side[1]-axis[1]*6.5,centre[2]]
    def cross():
        gate_clear('Censer');at=gate['at']
        walk([[at[0]+axis[0]*offset,at[1]+axis[1]*offset,at[2]] for offset in [-1.5,1.5,4.5]],
             'censer-real-timed-crossing',tolerance=25,on_arrive=on_complete)
    stow_held()
    walk([entry,[stance[0]-axis[0]*3,stance[1]-axis[1]*3,stance[2]],stance],
         'censer-start-chain-stance',tolerance=20,
         on_arrive=lambda:pull_chain(chain['at'],chain['yaw'],'censer-held-pull',on_complete=cross))


def pan_play(seconds=100,gentle=False):
    """Continuous mouse-sized tilts followed by upward flicks; observe the kernel's actual result."""
    global gesture_handle
    assert gesture_handle is None
    resume();note('pan-input-start')
    state=dict(t=0.,cycle=-1,kicked=False,next_read=0.)
    def tick(dt):
        global gesture_handle
        state['t']+=dt
        if state['t']>=state['next_read']:
            text=session['helper'].call_method('Inspect',args=(session['pawn'],))
            note('pan-observation')
            state['next_read']=state['t']+4
            if re.search(r' ready=[1-9][0-9]*',text) or 'pan_pieces=0 ' in text or state['t']>=seconds:
                u.unregister_slate_post_tick_callback(gesture_handle);gesture_handle=None
                screenshot('pan-play-result');pause('inspect pan result');return
        period=5 if gentle else 7
        cycle=int(state['t']//period);phase=state['t']%period
        if cycle!=state['cycle']: state['cycle']=cycle;state['kicked']=False
        sign=1 if cycle%2 else -1
        if gentle:
            if not state['kicked']:
                look(yaw=3 if cycle%2 else -3,pitch=-22);state['kicked']=True
        elif phase<.65:
            look(yaw=sign*90*dt,pitch=(35 if cycle%4<2 else -35)*dt)
        elif not state['kicked']:
            look(pitch=-42);state['kicked']=True
    gesture_handle=u.register_slate_post_tick_callback(tick)


def protein_prepare():
    """Reuse the empty large tray; cut the actual guarded joint into two pan-sized portions."""
    state=session['helper'].call_method('Inspect',args=(session['pawn'],)).splitlines()[0]
    assert 'held=TOMBSTONE' in state, 'Put down the cooked side and free both hands before reusing the large tray'
    def chop():
        tap('Q');later(2.2,lambda:tap());later(4,lambda:pause('inspect actual protein cut'))
    def deposit():
        ensure_selected('MeatSlab')
        later(.7,lambda:use_at(station_point('Cutting',(-.05,-.62,.715)),'deposit-guarded-joint',
            on_complete=lambda:use_at(station_point('Cutting',(0,0,.5)),'operate-cutting',on_complete=chop)))
    def dock():
        station_stance('Cutting',-.62,on_arrive=lambda:use_at(station_point('Cutting',(-.05,-.62,.715)),
            'dock-protein-cutting-input',on_complete=deposit))
    station_stance('Fry',-.85,on_arrive=lambda:use_at(station_point('Fry',(0,-.85,.715)),
        'reuse-empty-large-tray',on_complete=dock))


def protein_cut_finish():
    def sweep():
        tap('RightMouseButton');later(2,lambda:pause('inspect cut protein on output tray'))
    def output():
        station_stance('Cutting',.62,on_arrive=lambda:use_at(station_point('Cutting',(-.05,.62,.715)),
            'dock-cutting-output',on_complete=lambda:use_at(station_point('Cutting',(0,0,.5)),
                'reoperate-cutting',on_complete=sweep)))
    leave_station(lambda:use_at(station_point('Cutting',(-.05,-.62,.715)),
        'take-empty-cutting-input',on_complete=output))


def protein_pan_load():
    def feed():
        tap('Q');later(2.5,lambda:tap('Q'));later(5,lambda:pause('inspect actual protein pan admission'))
    def dock():
        station_stance('Searing',-.54,on_arrive=lambda:use_at(station_point('Searing',(0,-.54,.715)),
            'dock-cut-protein',on_complete=lambda:use_at(station_point('Searing',(0,0,.5)),
                'operate-searing',on_complete=feed)))
    leave_station(lambda:use_at(station_point('Cutting',(-.25,.62,.76)),
        'take-cut-protein-tray',on_complete=dock))


def protein_pan_output():
    def output():
        station_stance('Searing',.54,on_arrive=lambda:use_at(station_point('Searing',(-.25,.54,.715)),
            'dock-protein-output',on_complete=lambda:use_at(station_point('Searing',(0,0,.5)),
                'reoperate-searing',on_complete=lambda:pan_play(gentle=True))))
    leave_station(lambda:use_at(station_point('Searing',(0,-.54,.715)),
        'take-empty-searing-input',on_complete=output))
