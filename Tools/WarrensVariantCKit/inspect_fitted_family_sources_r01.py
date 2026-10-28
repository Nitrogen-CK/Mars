"""Read accepted native family values/colours for a fitted-stone material proposal."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read():
    import unreal as u
    assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages() and not u.EditorLoadingAndSavingUtils.get_dirty_content_packages()
    out = DOC/'fitted-context-family-r01'
    assert not out.exists()
    meshes = dict(Walls='WVC_Larder_Walls_R02_SM', Floor='WVC_Larder_Floor_R01_SM', Ceiling='WVC_Larder_HighRoof_R01_SM')
    rows = {}
    mel = u.MaterialEditingLibrary
    for family, name in meshes.items():
        path = '/Game/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01/Meshes/'+name
        mesh = u.load_asset(path)
        material = mesh.static_materials[0].get_editor_property('material_interface')
        assert material.get_path_name().split('.')[0] == '/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02/PBR_R09/Materials/M_CP_'+family+'_PBR_R09'
        nodes = [n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer() == material]
        colour_lerps = []
        for node in nodes:
            if not isinstance(node, u.MaterialExpressionLinearInterpolate):
                continue
            inputs = list(mel.get_inputs_for_material_expression(material, node))
            if isinstance(inputs[0], u.MaterialExpressionConstant3Vector) and isinstance(inputs[1], u.MaterialExpressionTextureSample) and inputs[1].get_editor_property('sampler_type') == u.MaterialSamplerType.SAMPLERTYPE_COLOR:
                colour_lerps.append(node)
        colour_lerp, = colour_lerps
        colour_inputs = list(mel.get_inputs_for_material_expression(material, colour_lerp))
        base = colour_inputs[0]
        assert colour_inputs[0] == base and isinstance(colour_inputs[2], u.MaterialExpressionConstant)
        rough = mel.get_material_property_input_node(material, u.MaterialProperty.MP_ROUGHNESS)
        assert isinstance(rough, u.MaterialExpressionLinearInterpolate)
        rough_inputs = list(mel.get_inputs_for_material_expression(material, rough))
        assert isinstance(rough_inputs[0], u.MaterialExpressionConstant)
        dm = u.DynamicMesh()
        lod = u.GeometryScriptMeshReadLOD()
        lod.lod_type = u.GeometryScriptLODType.RENDER_DATA
        lod.lod_index = 0
        result = u.GeometryScript_AssetUtils.copy_mesh_from_static_mesh(mesh, dm, u.GeometryScriptCopyMeshFromAssetOptions(), lod)
        assert result[1] == u.GeometryScriptOutcomePins.SUCCESS
        colours = u.GeometryScript_VertexColors.get_mesh_per_vertex_colors(dm, False)
        assert colours[2] is True and colours[3] is False
        values = u.GeometryScript_List.convert_color_list_to_array(colours[1])
        rgb = sorted({tuple(round(v.to_tuple()[k]*255) for k in range(3)) for v in values})
        files = list(map(str, mesh.get_editor_property('asset_import_data').extract_filenames()))
        assert len(files) == 1 and Path(files[0]).resolve().is_relative_to(ROOT)
        source = Path(files[0]).resolve()
        package = ROOT/('Content/'+path.removeprefix('/Game/')+'.uasset')
        textures = sorted({n.get_editor_property('texture').get_path_name() for n in nodes if isinstance(n, u.MaterialExpressionTextureSample)})
        rows[family] = dict(mesh=path, package_sha256=sha(package), source_file=source.relative_to(ROOT).as_posix(), source_sha256=sha(source), native_render_triangles=dm.get_triangle_count(), native_RGB_bytes=rgb, material=material.get_path_name(), base_colour=list(base.get_editor_property('constant').to_tuple()[:3]), pigment_mix=colour_inputs[2].get_editor_property('r'), normal_strength=mel.get_material_default_scalar_parameter_value(material, 'NormalStrength'), roughness_base=rough_inputs[0].get_editor_property('r'), roughness_blend=mel.get_material_default_scalar_parameter_value(material, 'RoughnessBlend'), pigment_period_metres=1.8 if family == 'Walls' else 1., textures=textures)
        print('NATIVE_FITTED_FAMILY_SOURCE', family, rows[family]['base_colour'], rows[family]['pigment_mix'], rows[family]['normal_strength'], rows[family]['roughness_base'], rows[family]['roughness_blend'], len(rgb))
    out.mkdir()
    (out/'native_family_sources_r01.json').write_text(json.dumps(dict(status='READ_ONLY_ACCEPTED_NATIVE_FAMILY_SOURCE_VALUES_AND_RENDER_BYTES', tool_sha256=sha(__file__), families=rows, boundary='Read-only native meshes/materials. No graph build or binding. Family RGB sets are render-data bytes, not screenshot colours. Fitted geometry needs a separate pigment-only per-instance variation profile without additional drawn joints. Source physical/gameplay roles and existing adopted non-TX01 materials remain protected.'), indent=2)+'\n')
    return rows
