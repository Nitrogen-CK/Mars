"""Fresh-process audit of the saved library, not the generator's in-memory report."""
import json
import math
from pathlib import Path
import bpy

OUT=Path(__file__).resolve().parent/'Output'
manifest=json.loads((OUT/'asset_manifest.json').read_text())
rows=[]
for row in manifest['assets']:
    o=bpy.data.objects.get(row['name']);assert o and o.type=='MESH',row['id']
    assert o.asset_data and len(o.asset_data.catalog_id)==36,row['id']
    assert o.data.uv_layers and len(o.data.polygons)>0,row['id']
    assert all(math.isfinite(v) for p in o.data.vertices for v in p.co),row['id']
    assert all(m is not None for m in o.data.materials),row['id']
    lo=[min(v.co[k] for v in o.data.vertices)*100 for k in range(3)]
    hi=[max(v.co[k] for v in o.data.vertices)*100 for k in range(3)]
    actual=[hi[k]-lo[k] for k in range(3)]
    assert all(abs(actual[k]-row['actual_dimensions_cm'][k])<.001 for k in range(3)),row['id']
    assert (OUT/row['fbx']).is_file(),row['fbx']
    rows.append({'id':row['id'],'vertices':len(o.data.vertices),'triangles':sum(len(f.vertices)-2 for f in o.data.polygons),'bounds_cm':actual,'uv0':True,'asset_catalog':o.asset_data.catalog_id})
assert len(rows)==88 and len({r['id'] for r in rows})==88
vault_row=next(r for r in manifest['assets'] if r['id']=='CCS18')
vault=bpy.data.objects[vault_row['name']].data
# The shell is the first joined island: matching diagonals are load-bearing.
# Identical XY triangulation and constant positive vertical thickness prove
# the two piecewise-planar shell surfaces cannot cut through each other.
bottom=[p for p in vault.polygons if max(p.vertices)<25]
top=[p for p in vault.polygons if min(p.vertices)>=25 and max(p.vertices)<50]
assert len(bottom)==len(top)==32 and all(len(p.vertices)==3 for p in bottom+top)
assert {frozenset(p.vertices) for p in bottom}=={frozenset(i-25 for i in p.vertices) for p in top}
thickness=[vault.vertices[i+25].co.z-vault.vertices[i].co.z for i in range(25)]
assert min(thickness)>.001 and max(thickness)-min(thickness)<1e-5
scenes={}
for name in ['01_KitLibrary','02_ChainCrossingDiorama']:
    sc=bpy.data.scenes[name];instances=[o for o in sc.objects if o.instance_type=='COLLECTION']
    assert instances and not any(o.type=='MESH' for o in sc.objects)
    scenes[name]={'linked_collection_instances':len(instances),'unique_collections':len({o.instance_collection.name for o in instances})}
assert scenes['01_KitLibrary']['unique_collections']==88
images=[i for i in bpy.data.images if i.source=='FILE'];assert all(i.packed_file for i in images),'Unpacked texture dependency'
report={'status':'passed','asset_count':len(rows),'triangles':sum(r['triangles'] for r in rows),'scenes':scenes,'packed_images':len(images),'vault_matching_triangle_pairs':len(bottom),'vault_minimum_shell_thickness_cm':min(thickness)*100,'assets':rows}
(OUT/'Reports/blender_validation.json').write_text(json.dumps(report,indent=2))
print('FRESH_BLENDER_AUDIT_PASSED',len(rows),report['triangles'],scenes)
