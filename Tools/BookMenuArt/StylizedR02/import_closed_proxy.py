"""Import the closed physics/remote-view proxy, preserving the rig's material slots."""
from pathlib import Path
import json
import unreal

root = Path(__file__).resolve().parent
dest = '/Game/Mars/Gameplay/PlayerCookbook/StylizedR02'
task = unreal.AssetImportTask()
task.filename = str(root/'Model/FBX/SM_Cookbook_Closed.fbx')
task.destination_path = dest+'/Meshes'
task.destination_name = 'SM_Cookbook_Closed'
task.automated = True
task.replace_existing = True
task.replace_existing_settings = True
task.save = True
task.factory = unreal.FbxFactory()
opts = unreal.FbxImportUI()
opts.automated_import_should_detect_type = False
opts.import_as_skeletal = False
opts.import_mesh = True
opts.import_animations = False
opts.import_materials = False
opts.import_textures = False
opts.mesh_type_to_import = unreal.FBXImportType.FBXIT_STATIC_MESH
opts.static_mesh_import_data.set_editor_property('combine_meshes', True)
opts.static_mesh_import_data.set_editor_property('auto_generate_collision', True)
task.options = opts
world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
previous = unreal.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX')
try:
    unreal.SystemLibrary.execute_console_command(world, 'Interchange.FeatureFlags.Import.FBX 0')
    unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
finally:
    unreal.SystemLibrary.execute_console_command(world, 'Interchange.FeatureFlags.Import.FBX '+('1' if previous else '0'))
mesh = unreal.load_asset(dest+'/Meshes/SM_Cookbook_Closed')
assert isinstance(mesh, unreal.StaticMesh)
materials = mesh.get_editor_property('static_materials')
for slot in materials:
    name = str(slot.get_editor_property('material_slot_name'))
    material = unreal.load_asset(dest+'/Materials/Cookbook_'+name+'_M')
    assert material, name
    slot.set_editor_property('material_interface', material)
mesh.set_editor_property('static_materials', materials)
assert unreal.EditorAssetLibrary.save_loaded_asset(mesh)
bounds = mesh.get_bounds()
report = {'asset': mesh.get_path_name(), 'origin': list(bounds.origin.to_tuple()),
          'extent': list(bounds.box_extent.to_tuple()), 'materials': len(materials)}
expected = json.loads((root/'Model/closed_proxy_report.json').read_text())
for i, axis in enumerate(['x','y','z']):
    # The static importer drops unreferenced bevel vertices from its render bounds.
    assert abs(getattr(bounds.box_extent, axis)*2-(expected['unreal_max_cm'][i]-expected['unreal_min_cm'][i])) < .2
(root/'unreal_proxy_report.json').write_text(json.dumps(report, indent=2))
print('COOKBOOK_PROXY '+json.dumps(report))
