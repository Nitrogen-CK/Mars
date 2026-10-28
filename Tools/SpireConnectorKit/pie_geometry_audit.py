"""Runtime capsule sweeps for safety rails, door clearance and main ceilings."""
import json,math,re
from pathlib import Path
import unreal as u
import pie_acceptance as qa
OUT=qa.OUT
def sweep(start,end,radius=39,half=75):
 w=qa.ED.get_game_world();assert w
 p=u.GameplayStatics.get_player_controller(w,0).get_controlled_pawn()
 h=u.SystemLibrary.capsule_trace_single(w,u.Vector(*start),u.Vector(*end),radius,half,u.TraceTypeQuery.TRACE_TYPE_QUERY1,False,[p],u.DrawDebugTrace.NONE)
 text=h.export_text() if h else '';hit='bBlockingHit=True' in text;m=re.search(r'Component="[^"]*\x27([^\x27]+)\x27"',text)
 component=u.find_object(None,m.group(1)) if m else None
 mesh=component.static_mesh.get_name() if isinstance(component,u.StaticMeshComponent) and component.static_mesh else ''
 return dict(blocking=hit,mesh=mesh,initial_overlap='bStartPenetrating=True' in text,raw=text if hit else '')
def run(label='baseline'):
 errors=[];rails=[];ceilings=[];doors=[]
 for c in qa.SPEC['concepts']:
  cid=c['id'];g=c['geometry'];R=g['shaft_outer_radius_cm'];r=(g['route_inner_radius_cm']+g['route_outer_radius_cm'])/2;ox,oy,oz=qa.OFFSETS[cid]
  def p(rad,a,z):return [R+rad*math.cos(a)+ox,rad*math.sin(a)+oy,z+oz]
  for f in c['flights']:
   for k in range(g['risers_per_flight']):
    a=math.radians(f['start_angle_deg']+(k+.5)*g['flight_angle_deg']/g['risers_per_flight']);z=f['start_z_cm']-(k+1)*g['riser_cm']+95
    for side,target in [('inner',g['route_inner_radius_cm']-100),('outer',g['route_outer_radius_cm']+100)]:
     result=sweep(p(r,a,z),p(target,a,z));row=dict(cid=cid,flight=f['id'],tread=k+1,side=side,**result);rails.append(row)
     if not result['blocking'] or 'FlightGuard' not in result['mesh'] or result['initial_overlap']:errors.append(dict(kind='rail',**row))
  for a in c['areas']:
   if cid=='BW':continue # Yoke openings intentionally cross the inner guard.
   angle=math.radians(a['angle_center_unwrapped_deg']);z=a['floor_z_cm']+95;result=sweep(p(r,angle,z),p(g['route_inner_radius_cm']-100,angle,z));row=dict(cid=cid,area=a['id'],**result);rails.append(row)
   if not result['blocking'] or 'LandingGuard' not in result['mesh'] or result['initial_overlap']:errors.append(dict(kind='rail',**row))
  # Exclude the flue/root/well; this is directly above the upper walking band.
  top=next(a for a in c['areas'] if a['route']=='A' and a['index']==0);a=math.radians(top['angle_center_unwrapped_deg']);result=sweep(p(r,a,120),p(r,a,340));row=dict(cid=cid,**result);ceilings.append(row)
  if not result['blocking'] or 'Roof' not in result['mesh']:errors.append(dict(kind='main_ceiling_missing',**row))
  for portal,x0,x1,z in [('upper',-80,180,0),('lower',2*R-120,2*R+380,-1200)]:
   for y in [-60,0,60]:
    result=sweep([x0+ox,y+oy,z+130],[x1+ox,y+oy,z+130],55,110);row=dict(cid=cid,portal=portal,lane_y_cm=y,**result);doors.append(row)
    if result['blocking']:errors.append(dict(kind='door_clearance',**row))
 report=dict(status='failed' if errors else 'passed',rail_sweeps=len(rails),ceiling_sweeps=len(ceilings),door_sweeps=len(doors),errors=errors,rails=rails,ceilings=ceilings,doors=doors,scope='Live PIE simple-collision capsule sweeps. Rails sampled at tread/landing stations; portal gauge110x220 raised20cm above floor to exclude step lips.')
 path=OUT/'PIE'/label;path.mkdir(parents=True,exist_ok=True);(path/'geometry_sweeps.json').write_text(json.dumps(report,indent=2));print('SPIRE_PIE_GEOMETRY',label,len(rails),len(doors),'errors',[(e['kind'],e['cid'],e.get('flight',e.get('area','')),e.get('side',''),e['mesh']) for e in errors]);return report
