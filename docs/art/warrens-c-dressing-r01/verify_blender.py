"""Fresh-process validation of the saved library, not the generator's completion message."""
import bpy,json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parent
manifest=json.loads((ROOT/'blender/library_manifest.json').read_text())
assert len(bpy.data.scenes)==3
assert manifest['material_count']==35
art_materials=[m for m in bpy.data.materials if m.asset_data]
assert len(art_materials)==35,[(m.name,m.get('catalog_id')) for m in art_materials]
file_images=[i for i in bpy.data.images if i.source=='FILE']
assert len(file_images)==77,len(file_images)
assert all(image.packed_file for image in file_images),[i.name for i in file_images if not i.packed_file]
for image in file_images:
    relative=image.filepath.replace('\\','/')[2:]
    source=(ROOT/'blender'/relative).resolve()
    assert source.is_relative_to(ROOT)
    assert hashlib.sha256(bytes(image.packed_file.data)).digest()==hashlib.sha256(source.read_bytes()).digest(),image.name
for ident,name in manifest['materials'].items():
    material=bpy.data.materials.get(name);assert material and material.use_nodes,(ident,name)
    for node in material.node_tree.nodes:
        if node.type!='TEX_IMAGE':continue
        assert node.image and node.image.packed_file
        path=node.image.filepath.replace('\\','/')
        assert path.startswith('//../'),node.image.filepath
        if '_ORM' in path or '_Normal' in path:assert node.image.colorspace_settings.name=='Non-Color'
        else:assert node.image.colorspace_settings.name=='sRGB'
        assert 'NormalDX' not in path,'DX normal accidentally loaded into Blender'
for scene in bpy.data.scenes:
    assert scene.camera and scene.unit_settings.scale_length==1
report={'fresh_process_open':True,'blender_version':bpy.app.version_string,'scenes':len(bpy.data.scenes),
        'unique_asset_materials':len(art_materials),'packed_images':len(file_images),'relative_image_paths':True,
        'internal_viewer_images_excluded':len(bpy.data.images)-len(file_images),
        'packed_image_hashes_match_sources':True,
        'normal_and_color_space_nodes_checked':True,'production_meshes_or_unreal_integration_claimed':False}
(ROOT/'qa/BLENDER_REOPEN_VERIFICATION.json').write_text(json.dumps(report,indent=2)+'\n')
print('BLENDER_REOPEN_VERIFIED',json.dumps(report))
