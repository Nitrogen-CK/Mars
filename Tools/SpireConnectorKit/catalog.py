"""Portable CSV inventory of every export, dimensions and reuse."""
import json,csv
from pathlib import Path
HERE=Path(__file__).resolve().parent;OUT=HERE/'Output';data=json.loads((OUT/'asset_manifest.json').read_text());spec=json.loads((HERE.parents[1]/'Docs/design/spire-blender-handoff-20261026/spire_spec.json').read_text(encoding='utf-8'))
props={p['id']:p for p in spec['props']}
with (OUT/'KitCatalog.csv').open('w',newline='',encoding='utf-8-sig') as f:
 w=csv.writer(f);w.writerow(['ID','Category','Name','X_cm','Y_cm','Z_cm','Triangles','Convex_hulls','HS_instances','BW_instances','RW_instances','HL_instances','Unreal_asset','FBX'])
 for r in data['assets']:
  counts=[sum(p['asset']==r['id'] for p in data['assemblies'][cid]) for cid in ['HS','BW','RW','HL']]
  w.writerow([r['id'],r['category'],props.get(r['id'].removeprefix('PR_'),{}).get('name',r['id']),*r['dimensions_cm'],r['triangles'],r['collision_hulls'],*counts,'/Game/Mars/Environment/SpireConnectorKit/Meshes/'+r['name'],r['fbx']])
print('SPIRE_CATALOG_WRITTEN',len(data['assets']))
