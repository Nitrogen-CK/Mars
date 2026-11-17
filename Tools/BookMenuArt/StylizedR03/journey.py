"""Short, real-player raw-input observation; no forced item/mount state."""
import unreal,math,json,traceback
from pathlib import Path
ROOT=Path('D:/Repositories/CkRepos/Orion/Tools/BookMenuArt/StylizedR03')
def start_cookbook_journey(label):
    world=unreal.EditorLevelLibrary.get_game_world()
    assert world and unreal.GameplayStatics.get_player_controller(world,0)
    out=ROOT/'UnrealGameplay'/label;out.mkdir(parents=True,exist_ok=True)
    global COOKBOOK_CAPTURE_ROOT
    COOKBOOK_CAPTURE_ROOT=out
    state={'label':label,'world':world.get_path_name(),'start':unreal.GameplayStatics.get_time_seconds(world),'next':0,'events':[],'captures':[],'book':None,'handle':None}
    aid=unreal.new_object(unreal.load_class(None,'/Script/Angelscript.Mars_ExpeditionAcceptance'))
    def player():
        return unreal.GameplayStatics.get_player_character(world,0)
    def point_at_book():
        pawn=player()
        found=[c for c in unreal.ObjectIterator(unreal.SkeletalMeshComponent) if c.get_world()==world and 'CookbookPresentation' in c.get_class().get_name()]
        book=min(found,key=lambda b:(b.get_world_location()-pawn.get_actor_location()).length())
        state['book']=book
        cam=unreal.GameplayStatics.get_player_camera_manager(world,0).get_camera_location()
        delta=book.get_world_location()+unreal.Vector(8,0,1)-cam
        rot=unreal.Rotator(pitch=math.degrees(math.atan2(delta.z,math.hypot(delta.x,delta.y))),yaw=math.degrees(math.atan2(delta.y,delta.x)),roll=0)
        assert aid.aim(pawn,rot)
        state['yaw']=rot.yaw
    def tap(key):
        cookbook_tap(key)
    def capture(name,expected_state=None,section=None):
        book=state['book'];actual=str(book.get_editor_property('_State'))
        if expected_state:
            assert ("."+expected_state.upper()+":") in actual,(name,actual,expected_state)
        if section is not None:
            assert book.get_editor_property('_PageSectionIndex')==section,(name,book.get_editor_property('_PageSectionIndex'))
        snapshot=cookbook_snapshot(name)
        pose=book.get_socket_transform('Spine',unreal.RelativeTransformSpace.RTS_COMPONENT)
        snapshot['observedBook']={'name':book.get_name(),'spineScale':pose.scale3d.to_tuple(),'spineTranslation':pose.translation.to_tuple()}
        (out/(name+'.json')).write_text(json.dumps(snapshot,indent=2))
        state['captures'].append(name)
    def spawn():
        pc=unreal.GameplayStatics.get_player_controller(world,0)
        unreal.SystemLibrary.execute_console_command(world,'Mars_SpawnCookbook',pc)
    def look_away():
        assert aid.aim(player(),unreal.Rotator(pitch=0,yaw=state['yaw'],roll=0))
    def finish():
        state['status']='complete'
        unreal.unregister_slate_post_tick_callback(state['handle'])
        report={k:v for k,v in state.items() if k not in ['book','handle']}
        (out/'journey.json').write_text(json.dumps(report,indent=2))
        print('COOKBOOK_JOURNEY_COMPLETE '+json.dumps(report))
    steps=[
      (.3,'spawn loose book',spawn),
      (1.0,'aim at nearest loose book',point_at_book),
      (1.5,'raw pickup',lambda:tap('LeftMouseButton')),
      (2.3,'clear world focus',look_away),
      (2.7,'held closed capture',lambda:capture('01-held-closed','Closed')),
      (3.0,'raw open',lambda:tap('LeftMouseButton')),
      (4.0,'open index capture',lambda:capture('02-open-index','Open',0)),
      (4.3,'raw next',lambda:tap('E')),
      (4.9,'mid-turn capture',lambda:capture('03-turn-mid')),
      (5.8,'recipe capture',lambda:capture('04-recipe','Open',1)),
      (6.1,'raw previous',lambda:tap('Q')),
      (7.6,'reverse index capture',lambda:capture('05-reverse-index','Open',0)),
      (7.9,'raw close',lambda:tap('LeftMouseButton')),
      (8.9,'closed capture',lambda:capture('06-closed','Closed')),
      (9.2,'raw reopen',lambda:tap('LeftMouseButton')),
      (10.2,'raw next before dropping',lambda:tap('E')),
      (10.4,'raw drop mid turn',lambda:tap('R')),
      (11.4,'dropped closed capture',lambda:capture('07-dropped','Closed')),
      (11.7,'finish',finish)]
    def tick(dt):
        try:
            current=unreal.EditorLevelLibrary.get_game_world()
            if current is None or current.get_path_name()!=state['world']:
                raise RuntimeError('PIE ended or changed during the observation')
            elapsed=unreal.GameplayStatics.get_time_seconds(world)-state['start']
            while state['next']<len(steps) and elapsed>=steps[state['next']][0]:
                at,name,fn=steps[state['next']];state['next']+=1
                state['events'].append({'at':elapsed,'action':name});fn()
        except Exception:
            unreal.unregister_slate_post_tick_callback(state['handle'])
            state['status']='failed';state['error']=traceback.format_exc()
            report={k:v for k,v in state.items() if k not in ['book','handle']}
            (out/'journey.json').write_text(json.dumps(report,indent=2))
            unreal.log_error('COOKBOOK_JOURNEY_FAILED '+state['error'])
    state['handle']=unreal.register_slate_post_tick_callback(tick)
    print('COOKBOOK_JOURNEY_STARTED '+label)

