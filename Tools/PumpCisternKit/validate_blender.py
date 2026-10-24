"""Fresh saved-file audit of new models, shared instances and packed assets."""
import json,math
from pathlib import Path
import bpy
OUT=Path(__file__).resolve().parent/'Output'
manifest=json.loads((OUT/'asset_manifest.json').read_text())
rows=[]
for row in manifest['assets']:
    o=bpy.data.objects.get(row['name']);assert o and o.type=='MESH',row['id']
    assert o.asset_data and o.data.uv_layers and o.data.polygons,row['id']
    assert all(math.isfinite(c) for v in o.data.vertices for c in v.co)
    assert all(m for m in o.data.materials)
    lo=[min(v.co[k] for v in o.data.vertices)*100 for k in range(3)]
    hi=[max(v.co[k] for v in o.data.vertices)*100 for k in range(3)]
    assert all(abs(hi[k]-lo[k]-row['actual_dimensions_cm'][k])<.001 for k in range(3)),row['id']
    assert (OUT/row['fbx']).is_file()
    rows.append(dict(id=row['id'],triangles=sum(len(p.vertices)-2 for p in o.data.polygons),bounds_cm=[hi[k]-lo[k] for k in range(3)]))
assert len(rows)==25
scenes={}
for name in ['01_PumpCisternLibrary','02_WaterworksCutaway']:
    sc=bpy.data.scenes[name];instances=[o for o in sc.objects if o.instance_type=='COLLECTION']
    assert instances and not any(o.type=='MESH' for o in sc.objects)
    scenes[name]=dict(instances=len(instances),unique_collections=len({o.instance_collection.name for o in instances}))
assert scenes['01_PumpCisternLibrary']['instances']==manifest['library_entries']
assert scenes['02_WaterworksCutaway']['instances']==manifest['diorama_instances']
images=[i for i in bpy.data.images if i.source=='FILE'];assert all(i.packed_file for i in images)
report=dict(status='passed',new_models=len(rows),triangles=sum(r['triangles'] for r in rows),shared_reuse_ids=manifest['shared_reuse_ids'],scenes=scenes,packed_images=len(images),assets=rows)
(OUT/'Reports/blender_validation.json').write_text(json.dumps(report,indent=2))
print('PUMP_SAVED_BLENDER_VALIDATED',len(rows),report['triangles'],scenes)
