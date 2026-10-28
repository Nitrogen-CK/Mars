"""Press the real chef into representative inner/outer stair guards in PIE."""
import math,json,traceback
import unreal as u
import pie_acceptance as qa
STATE=None;HANDLE=None
def start(label='final'):
 global STATE,HANDLE
 assert qa.HANDLE is None and qa.SUITE_HANDLE is None and HANDLE is None
 w=qa.ED.get_game_world();assert w;pc=u.GameplayStatics.get_player_controller(w,0);pawn=pc.get_controlled_pawn();cap=pawn.get_component_by_class(u.CapsuleComponent);move=pawn.get_component_by_class(u.CharacterMovementComponent)
 helper=u.new_object(u.load_class(None,'/Script/Angelscript.Mars_ExpeditionAcceptance'),outer=pc)
 jobs=[]
 for c in qa.SPEC['concepts']:
  flights=[f for f in c['flights'] if f['route']=='A']
  for f in [flights[0],flights[-1]]:
   for side in ['inner','outer']:jobs.append(dict(cid=c['id'],flight=f['id'],angle=(f['start_angle_deg']+f['end_angle_deg'])/2,floor=(f['start_z_cm']+f['end_z_cm'])/2,side=side))
 STATE=dict(status='running',index=0,jobs=jobs,results=[],phase='setup',seconds=0.)
 folder=qa.OUT/'PIE'/label;folder.mkdir(parents=True,exist_ok=True)
 runtime=dict(last=u.GameplayStatics.get_time_seconds(w))
 def finish(status):
  global HANDLE
  move.stop_movement_immediately();STATE['status']=status
  (folder/'physical_guards.json').write_text(json.dumps(STATE,indent=2));u.unregister_slate_post_tick_callback(HANDLE);HANDLE=None;print('SPIRE_PHYSICAL_GUARDS',status,len(STATE['results']),len(jobs))
 def tick(dt):
  try:
   now=u.GameplayStatics.get_time_seconds(w);delta=now-runtime['last'];runtime['last']=now
   if delta<=0:return
   job=jobs[STATE['index']];c=qa.concept(job['cid']);g=c['geometry'];R=g['shaft_outer_radius_cm'];ri,ro=g['route_inner_radius_cm'],g['route_outer_radius_cm'];r=(ri+ro)/2;ox,oy,oz=qa.OFFSETS[job['cid']];angle=math.radians(job['angle']);sign=-1 if job['side']=='inner' else 1
   if STATE['phase']=='setup':
    move.stop_movement_immediately();cap.set_capsule_size(39,75,True);move.set_movement_mode(u.MovementMode.MOVE_WALKING);pawn.set_actor_location(u.Vector(ox+R+r*math.cos(angle),oy+r*math.sin(angle),job['floor']+78),False,True);STATE['seconds']=0.;STATE['phase']='settle';return
   STATE['seconds']+=delta
   if STATE['phase']=='settle':
    if STATE['seconds']>=.5:STATE['phase']='press';STATE['seconds']=0.
    return
   if STATE['seconds']<1.5:
    direction=u.Vector(sign*math.cos(angle),sign*math.sin(angle),0);pawn.add_movement_input(direction,1,False);helper.call_method('Aim',args=(pawn,u.Rotator(yaw=math.degrees(math.atan2(direction.y,direction.x)))));return
   at=pawn.get_actor_location();radius=math.hypot(at.x-ox-R,at.y-oy);feet=at.z-75;cap_radius,cap_half=cap.get_scaled_capsule_size()
   boundary=ri+39 if sign<0 else ro-39;near=abs(radius-boundary)<8;safe=radius>=ri+39-3 if sign<0 else radius<=ro-39+3
   passed=near and safe and abs(feet-job['floor'])<25 and abs(cap_radius-39)<.01 and abs(cap_half-75)<.01 and move.movement_mode==u.MovementMode.MOVE_WALKING
   STATE['results'].append(dict(**job,status='passed' if passed else 'failed',radius_cm=radius,boundary_cm=boundary,feet_z=feet,mode=str(move.movement_mode)))
   move.stop_movement_immediately();STATE['index']+=1;STATE['phase']='setup'
   if not passed or STATE['index']==len(jobs):finish('passed' if passed else 'failed')
  except Exception:
   traceback.print_exc();finish('driver exception')
 HANDLE=u.register_slate_post_tick_callback(tick)
 print('SPIRE_PHYSICAL_GUARDS_STARTED',len(jobs))
