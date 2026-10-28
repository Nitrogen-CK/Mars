"""Evaluate original Catacomb witnesses per scene; record serialized-pose baselines."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

def main():
    import bpy
    root=Path(__file__).resolve().parents[2];here=Path(__file__).resolve().parent
    p=argparse.ArgumentParser();p.add_argument('--label',required=True,choices=('Diorama','KitLibrary'));args=p.parse_args(sys.argv[sys.argv.index('--')+1:])
    source=Path(bpy.data.filepath).resolve();assert source==here/'Output'/('WarrensVariantC_'+args.label+'.blend')
    before=hashlib.sha256(source.read_bytes()).hexdigest()
    spec=importlib.util.spec_from_file_location('_r20_library_data',here/'sync_art_libraries.py');sync=importlib.util.module_from_spec(spec);spec.loader.exec_module(sync)
    fit=json.loads((here/'Output/fitted_instances.json').read_text());rows={row['id']:(i,row) for i,row in enumerate(fit['placements']) if row['tile']=='Catacomb' and row['id'] in ('WVC026','WVC052','WVC053','WVC081')};assert len(rows)==4
    active=bpy.context.window.scene;scenes={}
    for name in ('02_VariantC_Cutaway','Zone_Catacomb'):
        scene=bpy.data.scenes[name];bpy.context.window.scene=scene;bpy.context.view_layer.update();witnesses={}
        for ident,(index,row) in rows.items():
            obj,=[o for o in scene.objects if re.sub(r'\.\d{3}$','',o.name)==ident+'_Assembly_'+str(index)]
            sync.check_pose(obj,row)
            witnesses[ident]=dict(name=obj.name,location=list(obj.location),basis=[list(v) for v in obj.matrix_basis],world=[list(v) for v in obj.matrix_world],instance=obj.instance_collection.name,parent=obj.parent.name if obj.parent else None,hidden=obj.hide_render,row_index=index,fit_row=row)
        scenes[name]=dict(objects=len(scene.objects),witnesses=witnesses)
    scene=bpy.data.scenes['01_VariantCLibrary'];bpy.context.window.scene=scene;bpy.context.view_layer.update()
    boxes=[]
    for o in scene.objects:
        if o.instance_type!='COLLECTION':continue
        boxes.append(dict(name=o.name,at=list(o.matrix_world.translation),scale=list(o.scale),collection=o.instance_collection.name))
    scenes[scene.name]=dict(objects=len(scene.objects),instances=boxes)
    bpy.context.window.scene=active;bpy.context.view_layer.update()
    assert hashlib.sha256(source.read_bytes()).hexdigest()==before
    folder=root/'Saved/WarrensCGameplay-20261024/CatacombPilot/library_inventory_r20';folder.mkdir(parents=True,exist_ok=True);out=folder/('Blender_'+args.label+'_scenes.json');assert not out.exists()
    out.write_text(json.dumps(dict(status='EVALUATED_ORIGINAL_BLENDER_SCENE_WITNESSES',source=source.relative_to(root).as_posix(),sha256=before,active_scene=active.name,scenes=scenes),indent=2)+'\n')
    print('PER_SCENE_WITNESSES',args.label,hashlib.sha256(out.read_bytes()).hexdigest())

if __name__=='__main__':main()
