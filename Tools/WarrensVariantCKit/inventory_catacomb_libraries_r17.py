"""Read-only headless Blender inventory; never saves a blend or changes a scene."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

def main():
    import bpy
    root=Path(__file__).resolve().parents[2]
    parser=argparse.ArgumentParser();parser.add_argument('--label',required=True,choices=('Diorama','KitLibrary','ForageSource'))
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);source=Path(bpy.data.filepath).resolve()
    assert source.is_relative_to(root) and source.suffix=='.blend'
    folder=root/'Saved/WarrensCGameplay-20261024/CatacombPilot/library_inventory_r17';folder.mkdir(parents=True,exist_ok=True)
    out=folder/(args.label+'.json');assert not out.exists()
    digest=hashlib.sha256(source.read_bytes()).hexdigest()
    selected=lambda name:any(k in name.lower() for k in ('catacomb','wvc026','wvc052','wvc053','wvc081','forage','broadplane','angularpigment','timber'))
    scenes={s.name:dict(objects=len(s.objects),collections=sorted(c.name for c in s.collection.children)) for s in bpy.data.scenes}
    objects={o.name:dict(type=o.type,collections=sorted(c.name for c in o.users_collection),instance=o.instance_collection.name if o.instance_collection else None,pose=[list(row) for row in o.matrix_world],mesh=o.data.name if o.type=='MESH' else None,materials=[s.material.name if s.material else None for s in o.material_slots] if o.type=='MESH' else []) for o in bpy.data.objects if selected(o.name)}
    collections={c.name:dict(objects=sorted(o.name for o in c.objects),children=sorted(v.name for v in c.children)) for c in bpy.data.collections if selected(c.name)}
    meshes={m.name:dict(vertices=len(m.vertices),polygons=len(m.polygons),uvs=[v.name for v in m.uv_layers],materials=[v.name if v else None for v in m.materials]) for m in bpy.data.meshes}
    materials={m.name:dict(users=m.users,nodes=[dict(name=n.name,type=n.bl_idname,image=n.image.name if n.bl_idname=='ShaderNodeTexImage' and n.image else None) for n in m.node_tree.nodes] if m.use_nodes else []) for m in bpy.data.materials if selected(m.name)}
    images={i.name:dict(filepath=i.filepath,size=list(i.size),colorspace=i.colorspace_settings.name,packed=bool(i.packed_file)) for i in bpy.data.images}
    r=dict(status='READ_ONLY_BLENDER_LIBRARY_INVENTORY',label=args.label,source=source.relative_to(root).as_posix(),sha256=digest,blender=bpy.app.version_string,scenes=scenes,selected_objects=objects,selected_collections=collections,meshes=meshes,selected_materials=materials,images=images,boundary='Inventory only; no generated geometry, material binding or blend save.')
    assert hashlib.sha256(source.read_bytes()).hexdigest()==digest
    out.write_text(json.dumps(r,indent=2)+'\n');print('LIBRARY_READ_ONLY_INVENTORY',args.label,len(objects),len(meshes),out)

if __name__=='__main__':main()
