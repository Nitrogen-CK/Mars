"""Report source weights behind newly observed coat deformation; never edits."""
import bpy,json,sys
from pathlib import Path
OUT=Path(__file__).resolve().parents[1]/'Output/Art'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'StewardService_Review.blend'))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith('Steward_Mars_SK'))
posed=o.evaluated_get(bpy.context.evaluated_depsgraph_get());me=posed.to_mesh()
rows=[]
for v in me.vertices:
    p=o.matrix_world @ v.co
    if p.y<-.54 and .6<p.z<1.65:
        original=o.data.vertices[v.index]
        rows.append(dict(index=v.index,posed=list(p),original=list(o.matrix_world @ original.co),
            weights={o.vertex_groups[g.group].name:g.weight for g in original.groups if g.weight>.05}))
report_name=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'skin_diagnosis.json'
posed.to_mesh_clear();(OUT/report_name).write_text(json.dumps(rows,indent=2));print('SKIN_DIAGNOSIS',json.dumps(rows[:20]),'total',len(rows))
