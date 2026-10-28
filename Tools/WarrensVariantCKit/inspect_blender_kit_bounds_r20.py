"""Read-only evaluated mesh/text footprint of the original Blender kit scene."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
def main():
    import bpy
    from mathutils import Vector
    root=Path(__file__).resolve().parents[2];p=argparse.ArgumentParser();p.add_argument('--label',required=True,choices=('Diorama','KitLibrary'));a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
    source=Path(bpy.data.filepath).resolve();assert source==root/'Tools/WarrensVariantCKit/Output'/('WarrensVariantC_'+a.label+'.blend')
    digest=hashlib.sha256(source.read_bytes()).hexdigest();bpy.context.window.scene=bpy.data.scenes['01_VariantCLibrary'];bpy.context.view_layer.update();rows=[]
    for item in bpy.context.evaluated_depsgraph_get().object_instances:
        if item.object.type not in ('MESH','FONT'):continue
        points=[item.matrix_world@Vector(v) for v in item.object.bound_box]
        rows.append(dict(name=item.object.original.name,parent=item.parent.original.name if item.parent else None,lo=[min(v[i] for v in points) for i in range(3)],hi=[max(v[i] for v in points) for i in range(3)]))
    assert rows;lo=[min(r['lo'][i] for r in rows) for i in range(3)];hi=[max(r['hi'][i] for r in rows) for i in range(3)]
    assert hashlib.sha256(source.read_bytes()).hexdigest()==digest
    out=root/'Saved/WarrensCGameplay-20261024/CatacombPilot/library_inventory_r20'/('Blender_'+a.label+'_kit_bounds.json');assert not out.exists();out.write_text(json.dumps(dict(status='EVALUATED_ORIGINAL_KIT_MESH_TEXT_BOUNDS',source=source.relative_to(root).as_posix(),source_sha256=digest,lo=lo,hi=hi,rows=rows),indent=2)+'\n');print('KIT_BLENDER_BOUNDS',a.label,lo,hi,hashlib.sha256(out.read_bytes()).hexdigest())
if __name__=='__main__':main()
