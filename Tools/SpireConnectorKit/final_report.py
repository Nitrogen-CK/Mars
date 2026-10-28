"""Hash the actual delivery and aggregate its bounded validation evidence."""
import json,hashlib,re,subprocess
from pathlib import Path
from datetime import datetime,timezone
HERE=Path(__file__).resolve().parent;OUT=HERE/'Output';REPO=HERE.parents[1]
def read(name):return json.loads((OUT/'Reports'/name).read_text(encoding='utf-8-sig'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
data=json.loads((OUT/'asset_manifest.json').read_text());baseline=read('baseline.json');protected=[]
for rel,row in baseline['files'].items():
 actual=sha(REPO/rel);protected.append(dict(path=rel,sha256=actual,unchanged=actual==row['sha256']));assert actual==row['sha256'],rel
for row in data['assets']:assert sha(OUT/row['fbx'])==row['sha256'],row['id']
reports={k:read(k+'.json') for k in ['blender_validation','blender_clearance','unreal_mesh_validation','unreal_collision_validation']}
assert all(r['status']=='passed' and not r['errors'] for r in reports.values())
maps=[]
for key in ['HS','BW','RW','HL','KitLibrary','Diorama']:
 report=read('saved_map_'+key+'.json');assert report['status']=='passed' and not report['errors'];path=REPO/('Content/'+report['map'].removeprefix('/Game/')+'.umap');assert path.is_file();maps.append(dict(key=key,asset=report['map'],sha256=sha(path),instances=report['instances'],groups=report['groups'],transforms_checked=report['transforms_checked']))
log=REPO/'Saved/Logs/Spire-PIE-CkJolt-Test.log';raw=log.read_text(encoding='utf-8',errors='replace');tail=raw[raw.rfind('=== Test summary ==='):]
nums={k:int(re.search(r'^'+k+r':\s*(\d+)',tail,re.M).group(1)) for k in ['Total','Passed','Failed','Skipped','Contaminated']};assert nums==dict(Total=40,Passed=40,Failed=0,Skipped=0,Contaminated=0);assert 'TEST COMPLETE. EXIT CODE: 0' in raw
blends=[]
for key in ['HS','BW','RW','HL','KitLibrary','Diorama']:
 path=OUT/'Blender'/('Spire_'+key+'.blend');assert path.is_file();blends.append(dict(file=str(path.relative_to(OUT)),sha256=sha(path)))
library=OUT/'AssetLibrary/Spire_Assets.blend';assert library.is_file();blends.append(dict(file=str(library.relative_to(OUT)),sha256=sha(library)))
pie=read('pie_acceptance.json');assert pie['status']=='passed' and pie['asset_manifest_sha256']==sha(OUT/'asset_manifest.json')
assert next(m for m in maps if m['key']=='KitLibrary')['instances']==len(data['assets'])
result=dict(status='validated_in_single_player_PIE',utc=datetime.now(timezone.utc).isoformat(),assets=len(data['assets']),props=sum(r['category']=='Props' for r in data['assets']),collision_meshes=sum(r['category']=='Collision' for r in data['assets']),materials=11,maps=maps,blends=blends,reports=reports,pie=pie,toolbox=dict(**nums,log=str(log.relative_to(REPO)),sha256=sha(log),process_exit_code=0),protected_files=protected,unverified=['co-op playtest','packaged CkJolt collision','performance','manual keyboard feel'],changes='New owned content and tools only; no live map integration, commit or push by this task.')
(OUT/'Reports/delivery.json').write_text(json.dumps(result,indent=2));print('SPIRE_DELIVERY_VALIDATED',len(maps),len(data['assets']),nums)
