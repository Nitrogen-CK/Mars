"""Read-only source topology/material evidence for garment weight correction."""
import bpy,json
from pathlib import Path
OUT=Path(__file__).resolve().parents[1]/'Output/Art'
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.fbx(filepath=str(OUT/'Steward_Source.fbx'))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH');me=o.data
adj=[set() for _ in me.vertices]
for e in me.edges:
    a,b=e.vertices;adj[a].add(b);adj[b].add(a)
unseen=set(range(len(me.vertices)));rows=[]
while unseen:
    todo=[unseen.pop()];ids=[]
    while todo:
        i=todo.pop();ids.append(i)
        for j in adj[i]&unseen:unseen.remove(j);todo.append(j)
    pts=[o.matrix_world @ me.vertices[i].co for i in ids]
    weights={}
    for i in ids:
        for g in me.vertices[i].groups:
            n=o.vertex_groups[g.group].name
            if 'thumb' in n or any(f in n for f in ['index_','middle_','ring_','pinky_','hand_']):weights[n]=weights.get(n,0)+1
    mats=sorted({p.material_index for p in me.polygons if any(i in ids for i in p.vertices)})
    rows.append(dict(vertices=len(ids),ids=sorted(ids),bounds_min=[min(p[k] for p in pts) for k in range(3)],bounds_max=[max(p[k] for p in pts) for k in range(3)],materials=mats,finger_weights=weights))
(OUT/'source_components.json').write_text(json.dumps(rows,indent=2))
print('SOURCE_COMPONENTS',json.dumps([{k:v for k,v in r.items() if k!='ids'} for r in rows if r['finger_weights']]))
