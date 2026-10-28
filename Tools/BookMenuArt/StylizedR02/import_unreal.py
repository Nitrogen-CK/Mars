"""Import the final standalone cookbook FBXs and sample materials into a NEW namespace.

Run in Unreal Editor Python after Model/roundtrip_validation.json is final.
Never changes the original /BookMenu assets, existing cookbook, or current world.
"""
import ast
import hashlib
import json
import runpy
from pathlib import Path

import unreal

ROOT = Path(__file__).resolve().parent
MODEL = ROOT / 'Model'
DEST = '/Game/Mars/Gameplay/PlayerCookbook/StylizedR02'
MESH_NAME = 'SK_Cookbook_Field'
CLIP_NAMES = {
    'Book_Lying_R_01': 'Cookbook_Closed_AS',
    'Book_Lying_Open_01': 'Cookbook_Open_AS',
    'Book_Lying_R_to_Open_01': 'Cookbook_Opening_AS',
    'Book_Lying_Open_to_R_01': 'Cookbook_Closing_AS',
    'Book_Lying_Open_Page_Turn_R_to_L_02': 'Cookbook_TurnForward_AS',
    'Book_Lying_Open_Page_Turn_L_to_R_02': 'Cookbook_TurnReverse_AS',
}
SLOTS = ['Cover', 'PagesBase', 'PageA', 'PageB', 'PageC', 'PageD', 'PageFirst', 'PageLast']
EAL = unreal.EditorAssetLibrary
TOOLS = unreal.AssetToolsHelpers.get_asset_tools()
MEL = unreal.MaterialEditingLibrary
REPORT = {'mesh': {}, 'animations': [], 'materials': {}, 'source_sha256': {}}


def source_hash(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def import_fbx(path, destination, name, skeleton=None):
    asset_path = destination + '/' + name
    existing = None
    if EAL.does_asset_exist(asset_path):
        existing = unreal.load_asset(asset_path)
        previous_source = existing.get_editor_property('asset_import_data').get_first_filename()
        assert Path(previous_source).resolve() == path.resolve(), ('Different existing import', asset_path, previous_source)
    task = unreal.AssetImportTask()
    task.filename = str(path)
    task.destination_path = destination
    task.destination_name = name
    task.automated = True
    task.replace_existing = existing is not None
    task.replace_existing_settings = existing is not None
    task.save = True
    task.factory = unreal.FbxFactory()
    opts = unreal.FbxImportUI()
    opts.automated_import_should_detect_type = False
    opts.import_as_skeletal = True
    opts.import_mesh = skeleton is None
    opts.import_animations = skeleton is not None
    opts.import_materials = False
    opts.import_textures = False
    opts.create_physics_asset = False
    opts.mesh_type_to_import = (unreal.FBXImportType.FBXIT_ANIMATION if skeleton
                               else unreal.FBXImportType.FBXIT_SKELETAL_MESH)
    if skeleton:
        opts.skeleton = skeleton
        opts.anim_sequence_import_data.set_editor_property('import_custom_attribute', True)
        opts.anim_sequence_import_data.set_editor_property('import_bone_tracks', True)
        opts.anim_sequence_import_data.set_editor_property('use_default_sample_rate', False)
        opts.anim_sequence_import_data.set_editor_property('custom_sample_rate', 60)
    else:
        if existing:
            opts.skeleton = existing.get_editor_property('skeleton')
            opts.skeletal_mesh_import_data.set_editor_property('update_skeleton_reference_pose', True)
        opts.skeletal_mesh_import_data.set_editor_property('import_morph_targets', True)
        opts.skeletal_mesh_import_data.set_editor_property('normal_import_method', unreal.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS)
    task.options = opts
    # Interchange selects a different reimport path and ignores part of FbxImportUI.
    # Use the legacy FBX factory only for this operation, then restore the user's flag.
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    previous_flag = unreal.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX')
    try:
        unreal.SystemLibrary.execute_console_command(world, 'Interchange.FeatureFlags.Import.FBX 0')
        TOOLS.import_asset_tasks([task])
    finally:
        unreal.SystemLibrary.execute_console_command(world, 'Interchange.FeatureFlags.Import.FBX ' + ('1' if previous_flag else '0'))
    paths = list(task.imported_object_paths)
    if not paths:
        raise RuntimeError('No assets imported from ' + str(path))
    REPORT['source_sha256'][str(path.relative_to(ROOT))] = source_hash(path)
    return paths


def material(name, color=None, texture=None):
    path = DEST + '/Materials'
    asset_path = path + '/' + name
    if EAL.does_asset_exist(asset_path):
        mat = unreal.load_asset(asset_path)
        assert isinstance(mat, unreal.Material), asset_path
        return mat
    mat = TOOLS.create_asset(name, path, unreal.Material, unreal.MaterialFactoryNew())
    assert mat, asset_path
    if texture:
        node = MEL.create_material_expression(mat, unreal.MaterialExpressionTextureSampleParameter2D, -300, 0)
        node.set_editor_property('parameter_name', 'BC')
        node.set_editor_property('texture', texture)
        assert MEL.connect_material_property(node, 'RGB', unreal.MaterialProperty.MP_BASE_COLOR)
    else:
        node = MEL.create_material_expression(mat, unreal.MaterialExpressionConstant3Vector, -300, 0)
        node.set_editor_property('constant', unreal.LinearColor(*color))
        assert MEL.connect_material_property(node, '', unreal.MaterialProperty.MP_BASE_COLOR)
    roughness = MEL.create_material_expression(mat, unreal.MaterialExpressionConstant, -300, 180)
    roughness.set_editor_property('r', .86)
    assert MEL.connect_material_property(roughness, '', unreal.MaterialProperty.MP_ROUGHNESS)
    MEL.recompile_material(mat)
    assert EAL.save_loaded_asset(mat)
    return mat


def main():
    validation = json.loads((MODEL / 'validation.json').read_text())
    assert validation['skeleton_compatible_with_original'] is False
    assert validation['unweighted_vertices'] == 0
    assert validation['page_dimensions_cm'] == [17, 23]
    assert all(v['nonfinite_samples'] == 0 for v in validation['actions'].values())
    fbx = MODEL / 'FBX' / 'SK_Cookbook_StylizedR02.fbx'
    paths = import_fbx(fbx, DEST + '/Meshes', MESH_NAME)
    meshes = [unreal.load_asset(p) for p in paths]
    mesh = next(x for x in meshes if isinstance(x, unreal.SkeletalMesh))
    skeleton = mesh.get_editor_property('skeleton')
    assert skeleton
    morphs = [str(x) for x in mesh.get_all_morph_target_names()]
    assert set(morphs) == {'PageBend_01', 'PageBend_02', 'PageBend_03', 'PageBend_04'}, morphs
    slots = list(mesh.get_editor_property('materials'))
    slot_names = [str(x.get_editor_property('material_slot_name')) for x in slots]
    assert slot_names[:8] == SLOTS, slot_names
    # Read the literal palette without executing the Blender build script.
    tree = ast.parse((MODEL / 'build_stylized.py').read_text())
    colors = next(ast.literal_eval(n.value) for n in tree.body
                  if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'COLORS' for t in n.targets))
    page_side = {'PageA': 'Left', 'PageB': 'Right', 'PageC': 'Left', 'PageD': 'Right',
                 'PageFirst': 'Right', 'PageLast': 'Left'}
    for i, slot in enumerate(slots):
        name = slot_names[i]
        texture = None
        if name in page_side:
            texture = unreal.load_asset(DEST + '/Textures/Cookbook_Sample_' + page_side[name] + '_T')
            assert texture
        mat = material('Cookbook_' + name + '_M', color=colors[name], texture=texture)
        slot.set_editor_property('material_interface', mat)
        REPORT['materials'][name] = mat.get_path_name()
    mesh.set_editor_property('materials', slots)
    assert EAL.save_loaded_asset(mesh)
    bounds = mesh.get_imported_bounds()
    extent = bounds.box_extent
    REPORT['mesh'] = {'path': mesh.get_path_name(), 'skeleton': skeleton.get_path_name(),
                      'slots': slot_names, 'morphs': morphs,
                      'reference_bounds_cm': [extent.x * 2, extent.y * 2, extent.z * 2]}
    for name in validation['actions']:
        imported = import_fbx(MODEL / 'FBX' / (name + '.fbx'), DEST + '/Animations', CLIP_NAMES[name], skeleton)
        sequence = next(unreal.load_asset(p) for p in imported if isinstance(unreal.load_asset(p), unreal.AnimSequence))
        assert sequence.get_skeleton() == skeleton
        data = sequence.get_editor_property('data_model_interface')
        frames = data.get_number_of_frames()
        tracks = data.get_num_bone_tracks()
        assert frames > 0 and tracks == validation['bones'], (name, frames, tracks)
        REPORT['animations'].append({'path': sequence.get_path_name(), 'seconds': sequence.get_play_length(),
                                     'frames': frames, 'bone_tracks': tracks,
                                     'float_curves': data.get_number_of_float_curves()})
    runpy.run_path(str(ROOT / 'apply_morph_curves.py'), run_name='__main__')
    for item in REPORT['animations']:
        sequence = unreal.load_asset(item['path'])
        item['float_curves'] = sequence.get_editor_property('data_model_interface').get_number_of_float_curves()
        assert item['float_curves'] == 4
    REPORT['original_skeleton_compatible'] = False
    REPORT['runtime_bookmenu_wired'] = False
    REPORT['current_world'] = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world().get_path_name()
    (ROOT / 'unreal_import_report.json').write_text(json.dumps(REPORT, indent=2))
    print('COOKBOOK_IMPORT ' + json.dumps(REPORT))


if __name__ == '__main__':
    main()
