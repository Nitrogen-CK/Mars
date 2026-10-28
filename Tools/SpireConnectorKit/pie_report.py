"""Require final on-disk PIE evidence; bind each run and source asset revision."""
import json,hashlib,collections
from pathlib import Path
HERE=Path(__file__).resolve().parent;OUT=HERE/'Output';REPO=HERE.parents[1]
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
baseline=read(OUT/'PIE/baseline/geometry_sweeps.json');final=read(OUT/'PIE/final/geometry_sweeps.json')
assert len(baseline['errors'])==4 and all(e['kind']=='main_ceiling_missing' for e in baseline['errors'])
assert final['status']=='passed' and not final['errors']
contacts=read(OUT/'PIE/final/physical_guards.json')
assert contacts['status']=='passed' and len(contacts['results'])==16 and all(r['status']=='passed' for r in contacts['results'])
cases=[];modes=collections.Counter();stair_waypoints=0
for label,expected,gauge in [('final-chef',18,False),('final-gauge',9,True)]:
 suite=read(OUT/'PIE'/label/'suite.json');assert suite['status']=='passed' and len(suite['results'])==expected,(label,suite['status'],len(suite['results']))
 for result in suite['results']:
  path=Path(result['report']);run=read(path);assert result['status']==run['status']=='passed';assert run['teleports_during_route']==0 and run['gauge']==gauge
  assert run['index']==len(run['points']) and len(run['samples'])>0
  assert len([e for e in run['events'] if e['kind']=='waypoint'])==len(run['points'])-1
  assert not any(e['kind'] in ['blocked','fell_below_route','capsule_changed'] for e in run['events'])
  expected_radius,expected_half=(55,110) if gauge else (39,75)
  assert run['capsule_radius_cm']==expected_radius and run['capsule_half_height_cm']==expected_half
  mm=collections.Counter(s['mode'] for s in run['samples']);assert not any('FLYING' in m or 'SWIMMING' in m for m in mm);modes.update(mm)
  steps=sum('/tread' in e.get('label','') for e in run['events']);stair_waypoints+=steps
  max_error=max(abs(e['feet_z']-e['expected_z']) for e in run['events'] if e['kind']=='waypoint')
  cases.append(dict(concept=run['cid'],route=run['route'],direction=run['direction'],gauge=gauge,status=run['status'],game_seconds=run['elapsed'],waypoints=len(run['points'])-1,stair_waypoints=steps,frame_samples=len(run['samples']),max_waypoint_height_error_cm=max_error,report=str(path.relative_to(REPO)),sha256=sha(path),screenshots=len(list(path.parent.glob('*.png')))))
assert stair_waypoints==1080,stair_waypoints
manifest=OUT/'asset_manifest.json';data=read(manifest)
result=dict(status='passed',cases=len(cases),chef_cases=18,gauge_cases=9,physical_guard_contacts=16,stair_waypoints=stair_waypoints,frame_samples=sum(modes.values()),movement_modes=dict(modes),safety_sweeps=dict(rails=final['rail_sweeps'],doors=final['door_sweeps'],ceilings=final['ceiling_sweeps'],baseline_failed=4,final_failed=0),fix='Added shared persistent roof collision proxies to all four assemblies',case_reports=cases,asset_manifest_sha256=sha(manifest),native_meshes=len(data['assets']),scope='Automated single-player PIE with actual Mars chef, real movement/collision, and a separate enlarged design-envelope capsule. Setup relocations occur between cases only. Not packaged, co-op or manual keyboard-feel acceptance.')
(OUT/'Reports/pie_acceptance.json').write_text(json.dumps(result,indent=2));print('SPIRE_PIE_ACCEPTANCE_PASSED',len(cases),stair_waypoints,sum(modes.values()))
