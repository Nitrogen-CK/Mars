"""Owned, repeatable Chain Crossing art import; execute inside Unreal Editor Python.

    ns = runpy.run_path('D:/Repositories/CkRepos/Orion/Tools/ChainCrossingKit/import_assets.py')
    ns['main'](['CCS01', 'CCS21'])  # Small synchronous batch; None imports all assets.

No map actors, gameplay, existing collision or project settings are changed. Assets
are written only below DEST. Reimports require both the ownership tag and the exact
original source file. The temporary legacy FBX switch is restored in finally.
"""
import hashlib
import json
import time
from pathlib import Path

import unreal


ROOT = Path(__file__).resolve().parent
ART = ROOT.parents[1] / 'docs/art/warrens-c-dressing-r01'
OUT = ROOT / 'Output'
DEST = '/Game/Mars/Environment/ChainCrossingKit'
MATERIAL_DEST = DEST
OWNER = 'ChainCrossingKit.ProceduralV1'
TAG = 'ChainCrossingKitOwner'
RECIPE_VERSION = 2
EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary
TOOLS = unreal.AssetToolsHelpers.get_asset_tools()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def package_path(folder, name):
    return (MATERIAL_DEST if folder in ('Materials','Textures') else DEST) + '/' + folder + '/' + name


def load_owned(path, kind, source=None):
    """Do not silently adopt matching-name assets made by another tool/person."""
    if not EAL.does_asset_exist(path):
        return None
    asset = unreal.load_asset(path)
    if not isinstance(asset, kind) or EAL.get_metadata_tag(asset, TAG) != OWNER:
        raise RuntimeError('Refusing foreign asset: ' + path)
    if source:
        imported_from = asset.get_editor_property('asset_import_data').get_first_filename()
        if str(Path(imported_from).resolve()).casefold() != str(source.resolve()).casefold():
            raise RuntimeError('Import source changed for ' + path + ': ' + imported_from)
    return asset


def save_owned(asset, **metadata):
    EAL.set_metadata_tag(asset, TAG, OWNER)
    for key, value in metadata.items():
        EAL.set_metadata_tag(asset, key, str(value))
    if not EAL.save_loaded_asset(asset, False):
        raise RuntimeError('Save failed: ' + asset.get_path_name())


def recipes():
    """Match Blender's material keys; UV0 already contains physical tiling."""
    result = {}
    for spec in json.loads((ART / 'materials.json').read_text()):
        result[spec['id']] = dict(maps={k: spec['maps'][k] for k in ('BaseColor', 'ORM', 'NormalDX')},
                                  roughness=spec['roughness'], metallic=spec['metallic'])
        if spec['id'] in {'TX01','TX02','TX03','TX04','TX17'}:
            tint=spec['base_srgb_hex'].lstrip('#');rgb=[int(tint[i:i+2],16)/255 for i in (0,2,4)]
            result[spec['id']].update(quiet_color=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb],texture_weight=.12,roughness=.88)
    for spec in json.loads((ART / 'trim_metadata.json').read_text()):
        result[spec['id']] = dict(maps={k: spec['maps'][k] for k in ('BaseColor', 'ORM', 'NormalDX')})
    result['AT01'] = dict(maps={'BaseColor': 'textures/atlases/AT01_Palette_BaseColor.png'}, nearest=True)
    result['AT04'] = dict(maps={'BaseColor': 'textures/atlases/AT04_GlyphAndNavigation_Alpha.png'}, alpha='masked')
    for job in json.loads((ART / 'image_jobs.json').read_text()):
        if job['type'] == 'painted':
            result[job['id']] = dict(maps={'BaseColor': job['image']}, alpha='masked')
    for key in ('Wear_DampLeak', 'Wear_SaltResidue', 'Wear_SootFan', 'Wear_FlourScuff'):
        result[key] = dict(maps={'BaseColor': 'textures/decals/' + key + '.png'}, alpha='translucent')
    result['FX_Dust'] = dict(result['Wear_FlourScuff'])
    result['FX_Flame'] = dict(maps={'BaseColor': 'textures/fx/FlameCard_RGBA.png'}, alpha='masked', emission=1.5)
    # Opaque water intentionally retains reliable depth/silhouettes and cheap instancing.
    # No displacement, scene-depth dependency or implicit gameplay water volume.
    result['FX_Water'] = dict(maps={'NormalDX': 'textures/fx/Water_NormalDX.png'},
                              color=(.055, .12, .095), roughness=.24)
    result['FX_ShallowWater'] = dict(maps={'NormalDX':'textures/fx/Water_NormalDX.png'},color=(.035,.16,.14),roughness=.30,opacity=.72,alpha='translucent')
    for key, color, rough, opacity in [
        ('Glass', (.55, .64, .55), .12, .20),
        ('Ink', (.025, .032, .024), .8, 1),
        ('Foam', (.65, .68, .54), .8, .65),
        ('Puddle', (.06, .10, .085), .20, .38),
        ('Waterline', (.15, .20, .13), .9, .55),
        ('Ripple', (.45, .57, .48), .4, .45),
        ('Drip', (.20, .35, .31), .2, .45),
    ]:
        result[key] = dict(maps={}, color=color, roughness=rough, opacity=opacity,
                           alpha='translucent' if opacity < 1 else 'opaque')
    return result


def texture_name(relative):
    return 'T_CCK_' + Path(relative).stem


def texture_spec(relative, channel, recipe):
    return dict(source=ART / relative, relative=relative, name=texture_name(relative),
                normal=channel == 'NormalDX', linear=channel == 'ORM',
                clamp=channel=='BaseColor' and (recipe.get('alpha') in ('masked', 'translucent') or recipe.get('nearest', False)),
                nearest=recipe.get('nearest', False))


def require_import_result(task, expected_path):
    paths = [str(path) for path in task.imported_object_paths]
    if not any(path.split('.')[0] == expected_path for path in paths):
        raise RuntimeError('Importer did not report expected asset ' + expected_path + ': ' + repr(paths))


def import_texture(spec):
    path = package_path('Textures', spec['name'])
    existing = load_owned(path, unreal.Texture2D, spec['source'])
    sha = digest(spec['source'])
    if existing and EAL.get_metadata_tag(existing, 'SourceSHA256') == sha:
        return existing
    task = unreal.AssetImportTask()
    task.filename = str(spec['source'])
    task.destination_path = MATERIAL_DEST + '/Textures'
    task.destination_name = spec['name']
    task.automated = True
    task.replace_existing = existing is not None
    task.replace_existing_settings = existing is not None
    task.save = False
    task.async_ = False
    task.factory = unreal.TextureFactory()
    TOOLS.import_asset_tasks([task])
    require_import_result(task, path)
    texture = unreal.load_asset(path)
    if not isinstance(texture, unreal.Texture2D):
        raise RuntimeError('No texture imported: ' + path)
    EAL.set_metadata_tag(texture, TAG, OWNER)
    texture.set_editor_property('srgb', not spec['normal'] and not spec['linear'])
    texture.set_editor_property('compression_settings',
        unreal.TextureCompressionSettings.TC_NORMALMAP if spec['normal'] else
        unreal.TextureCompressionSettings.TC_MASKS if spec['linear'] else
        unreal.TextureCompressionSettings.TC_DEFAULT)
    texture.set_editor_property('flip_green_channel', False)  # Supplied files are already DirectX.
    address = unreal.TextureAddress.TA_CLAMP if spec['clamp'] else unreal.TextureAddress.TA_WRAP
    texture.set_editor_property('address_x', address)
    texture.set_editor_property('address_y', address)
    if spec['nearest']:
        texture.set_editor_property('filter', unreal.TextureFilter.TF_NEAREST)
    save_owned(texture, SourceSHA256=sha, SourceRelative=spec['relative'])
    return texture


def expression(mat, cls, x, y, **properties):
    node = MEL.create_material_expression(mat, cls, x, y)
    if not node:
        raise RuntimeError('Cannot create material expression: ' + str(cls))
    for key, value in properties.items():
        node.set_editor_property(key, value)
    return node


def connect(node, output, mat, prop):
    if not MEL.connect_material_property(node, output, prop):
        raise RuntimeError('Cannot connect material property ' + str(prop))


def scalar(mat, value, prop, y):
    node = expression(mat, unreal.MaterialExpressionConstant, -200, y, r=float(value))
    connect(node, '', mat, prop)
    return node


def make_material(key, recipe, textures):
    name = 'M_CCK_' + key
    path = package_path('Materials', name)
    mat = load_owned(path, unreal.Material)
    signature = hashlib.sha256(json.dumps([RECIPE_VERSION, recipe, {
        relative: digest(ART / relative) for relative in recipe['maps'].values()
    }], sort_keys=True).encode()).hexdigest()
    if (mat and EAL.get_metadata_tag(mat, 'RecipeSHA256') == signature
            and EAL.get_metadata_tag(mat, 'GraphBuildState') == 'ready'):
        return mat
    if mat is None:
        mat = TOOLS.create_asset(name, MATERIAL_DEST + '/Materials', unreal.Material, unreal.MaterialFactoryNew())
        if not isinstance(mat, unreal.Material):
            raise RuntimeError('Cannot create material: ' + path)
        EAL.set_metadata_tag(mat, TAG, OWNER)
    EAL.set_metadata_tag(mat, 'GraphBuildState', 'building')
    EAL.set_metadata_tag(mat, 'RecipeSHA256', '')
    MEL.delete_all_material_expressions(mat)
    alpha = recipe.get('alpha', 'opaque')
    mat.set_editor_property('blend_mode', unreal.BlendMode.BLEND_MASKED if alpha == 'masked' else
                            unreal.BlendMode.BLEND_TRANSLUCENT if alpha == 'translucent' else
                            unreal.BlendMode.BLEND_OPAQUE)
    mat.set_editor_property('two_sided', alpha != 'opaque' or key == 'FX_Water')
    mat.set_editor_property('used_with_instanced_static_meshes', True)
    if alpha == 'translucent':
        mat.set_editor_property('translucency_lighting_mode', unreal.TranslucencyLightingMode.TLM_SURFACE)
    nodes = {}
    for i, (channel, relative) in enumerate(recipe['maps'].items()):
        sampler = (unreal.MaterialSamplerType.SAMPLERTYPE_NORMAL if channel == 'NormalDX' else
                   unreal.MaterialSamplerType.SAMPLERTYPE_MASKS if channel == 'ORM' else
                   unreal.MaterialSamplerType.SAMPLERTYPE_COLOR)
        nodes[channel] = expression(mat, unreal.MaterialExpressionTextureSample, -650, i * 220,
                                    texture=textures[relative], sampler_type=sampler)
    if 'BaseColor' in nodes:
        if 'quiet_color' in recipe:
            tint=expression(mat,unreal.MaterialExpressionConstant3Vector,-450,-180,constant=unreal.LinearColor(*recipe['quiet_color'],1))
            weight=expression(mat,unreal.MaterialExpressionConstant,-450,-100,r=recipe['texture_weight'])
            mix=expression(mat,unreal.MaterialExpressionLinearInterpolate,-200,-180)
            for node,out,pin in [(tint,'','A'),(nodes['BaseColor'],'RGB','B'),(weight,'','Alpha')]:
                if not MEL.connect_material_expressions(node,out,mix,pin):raise RuntimeError('Quiet stone blend connection failed')
            connect(mix,'',mat,unreal.MaterialProperty.MP_BASE_COLOR)
        else:connect(nodes['BaseColor'], 'RGB', mat, unreal.MaterialProperty.MP_BASE_COLOR)
    else:
        color = recipe.get('color', (.5, .5, .5))
        rgb = expression(mat, unreal.MaterialExpressionConstant3Vector, -450, -180,
                         constant=unreal.LinearColor(*color, 1.0))
        connect(rgb, '', mat, unreal.MaterialProperty.MP_BASE_COLOR)
    if 'ORM' in nodes and 'quiet_color' not in recipe:
        for output, prop in [('R', unreal.MaterialProperty.MP_AMBIENT_OCCLUSION),
                             ('G', unreal.MaterialProperty.MP_ROUGHNESS),
                             ('B', unreal.MaterialProperty.MP_METALLIC)]:
            connect(nodes['ORM'], output, mat, prop)
    else:
        scalar(mat, recipe.get('roughness', .8), unreal.MaterialProperty.MP_ROUGHNESS, 200)
        scalar(mat, recipe.get('metallic', 0), unreal.MaterialProperty.MP_METALLIC, 280)
    if 'NormalDX' in nodes and 'quiet_color' not in recipe:
        connect(nodes['NormalDX'], 'RGB', mat, unreal.MaterialProperty.MP_NORMAL)
    if alpha != 'opaque':
        prop = unreal.MaterialProperty.MP_OPACITY_MASK if alpha == 'masked' else unreal.MaterialProperty.MP_OPACITY
        if 'BaseColor' in nodes:
            connect(nodes['BaseColor'], 'A', mat, prop)
        else:
            scalar(mat, recipe.get('opacity', 1), prop, 360)
    if recipe.get('emission'):
        multiply = expression(mat, unreal.MaterialExpressionMultiply, -150, -250)
        strength = expression(mat, unreal.MaterialExpressionConstant, -450, -350, r=recipe['emission'])
        if not MEL.connect_material_expressions(nodes['BaseColor'], 'RGB', multiply, 'A'):
            raise RuntimeError('Flame emission color connection failed')
        if not MEL.connect_material_expressions(strength, '', multiply, 'B'):
            raise RuntimeError('Flame emission strength connection failed')
        connect(multiply, '', mat, unreal.MaterialProperty.MP_EMISSIVE_COLOR)
    MEL.recompile_material(mat)
    save_owned(mat, RecipeSHA256=signature, CatalogMaterialKey=key, GraphBuildState='ready')
    return mat


def expected_bounds(row):
    actual = row.get('actual_dimensions_cm')
    if actual is not None:
        return list(actual)
    # A catalog envelope is insufficient to prove a carrier's real geometry axes.
    # Refuse to infer which axis is flat. The Blender generator must record it.
    if row.get('flags', {}).get('card') or row['id'] in {'CCS51', 'CCS52', 'CCS53', 'CCS56', 'CCS57', 'CCS58', 'CCS59', 'CCS64', 'CCS82', 'CCS83'}:
        raise RuntimeError(row['id'] + ': missing actual_dimensions_cm for card geometry')
    return list(row['dimensions_cm'])


def import_mesh(row, materials):
    source = OUT / row['fbx']
    path = package_path('Meshes', row['name'])
    existing = load_owned(path, unreal.StaticMesh, source)
    sha = digest(source)
    if not existing or EAL.get_metadata_tag(existing, 'SourceSHA256') != sha:
        task = unreal.AssetImportTask()
        task.filename = str(source)
        task.destination_path = DEST + '/Meshes'
        task.destination_name = row['name']
        task.automated = True
        task.replace_existing = existing is not None
        task.replace_existing_settings = existing is not None
        task.save = False
        task.async_ = False
        task.factory = unreal.FbxFactory()
        opts = unreal.FbxImportUI()
        opts.automated_import_should_detect_type = False
        opts.import_as_skeletal = False
        opts.import_mesh = True
        opts.import_animations = False
        opts.import_materials = False
        opts.import_textures = False
        opts.mesh_type_to_import = unreal.FBXImportType.FBXIT_STATIC_MESH
        data = opts.static_mesh_import_data
        for key, value in dict(combine_meshes=True, auto_generate_collision=False,
                               generate_lightmap_u_vs=False, build_nanite=False,
                               transform_vertex_to_absolute=True, reorder_material_to_fbx_order=True,
                               import_uniform_scale=1.0,
                               normal_import_method=unreal.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS).items():
            data.set_editor_property(key, value)
        task.options = opts
        world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
        old_flag = unreal.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX')
        try:
            unreal.SystemLibrary.execute_console_command(world, 'Interchange.FeatureFlags.Import.FBX 0')
            TOOLS.import_asset_tasks([task])
        finally:
            unreal.SystemLibrary.execute_console_command(world, 'Interchange.FeatureFlags.Import.FBX ' + ('1' if old_flag else '0'))
        require_import_result(task, path)
    mesh = unreal.load_asset(path)
    if not isinstance(mesh, unreal.StaticMesh):
        raise RuntimeError('No static mesh imported: ' + path)
    import_data=mesh.get_editor_property('asset_import_data')
    assert import_data.get_editor_property('convert_scene') and not import_data.get_editor_property('force_front_x_axis'), 'Unexpected FBX axis conversion: '+row['id']
    # Claim immediately so an interrupted first import is safely retryable; the
    # source hash is committed only after all shape/material/collision checks pass.
    EAL.set_metadata_tag(mesh, TAG, OWNER)
    names = dict(zip(row['materials'], row['material_keys']))
    if len(names) != len(row['materials']):
        raise RuntimeError('Duplicate Blender slot names: ' + row['id'])
    slots = list(mesh.get_editor_property('static_materials'))
    # FBX reimport can retain obsolete, unreferenced slots after a deliberate
    # material change. Resolve real section references first; never map by index
    # or discard a slot still used by any LOD.
    subsystem = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
    section_slots={(lod,section):subsystem.get_lod_material_slot(mesh,lod,section)
                   for lod in range(subsystem.get_lod_count(mesh))
                   for section in range(mesh.get_num_sections(lod))}
    used=sorted(set(section_slots.values()))
    pruned=[]
    if len(slots)>len(names) and len(used)==len(names) and all(0<=i<len(slots) for i in used):
        live_names={str(slots[i].get_editor_property('imported_material_slot_name')) for i in used}
        if live_names==set(names):
            pruned=[str(s.get_editor_property('imported_material_slot_name')) for i,s in enumerate(slots) if i not in used]
            for (lod,section),index in section_slots.items():subsystem.set_lod_material_slot(mesh,used.index(index),lod,section)
            slots=[slots[i] for i in used]
            mesh.set_editor_property('static_materials',slots)
    assigned = []
    for slot in slots:
        imported = str(slot.get_editor_property('imported_material_slot_name'))
        slot_name = str(slot.get_editor_property('material_slot_name'))
        # No index-based fallback: Unreal may reorder FBX material slots.
        source_name = imported if imported in names else slot_name
        if source_name not in names:
            raise RuntimeError('Unknown FBX slot for ' + row['id'] + ': ' + repr((imported, slot_name)))
        key = names[source_name]
        slot.set_editor_property('material_interface', materials[key])
        assigned.append(dict(imported_name=imported, slot_name=slot_name, key=key, material=materials[key].get_path_name()))
    if len(slots) != len(names):
        raise RuntimeError('FBX material slot count mismatch: ' + row['id'])
    mesh.set_editor_property('static_materials', slots)
    subsystem = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
    subsystem.remove_collisions(mesh)
    simple = subsystem.get_simple_collision_count(mesh)
    convex = subsystem.get_convex_collision_count(mesh)
    if simple != 0 or convex != 0:
        raise RuntimeError('Unexpected generated collision: ' + row['id'])
    bounds = mesh.get_bounds()
    actual = [getattr(bounds.box_extent, k) * 2 for k in ('x', 'y', 'z')]
    expected = expected_bounds(row)
    delta = [abs(a - b) for a, b in zip(actual, expected)]
    if any(error > max(.15, size * .003) for error, size in zip(delta, expected)):
        raise RuntimeError('UE centimetre/axis bounds mismatch ' + row['id'] + ': actual=' + str(actual) + ', expected=' + str(expected))
    save_owned(mesh, SourceSHA256=sha, CatalogId=row['id'], CollisionPolicy='No generated collision; visual dressing',
               GeneratorManifestSHA256=digest(OUT / 'asset_manifest.json'),
               BlenderToUnrealAxes='X,-Y,Z', ImportedFrontAxis='+Y (Blender neutral front -Y)',
               ImportedMechanismAxisAdapter='yaw -90deg: imported +Y to actor +X; preserve source grips' if row['flags'].get('axis')=='+X' else 'placement-specific')
    return dict(id=row['id'], path=mesh.get_path_name(), actual_dimensions_cm=actual,
                expected_dimensions_cm=expected, catalog_dimensions_cm=row['dimensions_cm'],
                max_axis_error_cm=max(delta), bounds_origin_cm=list(bounds.origin.to_tuple()),
                material_slots=assigned, pruned_unreferenced_material_slots=pruned, simple_collision_count=simple, convex_collision_count=convex,
                sections_lod0=mesh.get_num_sections(0), source_sha256=sha,
                blender_to_unreal_axes='X,-Y,Z', imported_front_axis='+Y',
                imported_mechanism_yaw_adapter=-90 if row['flags'].get('axis')=='+X' else None)


def main(ids=None):
    """Import all or selected CCS IDs; each call is synchronous and writes its own report."""
    started = time.time()
    if ids is not None:
        if isinstance(ids, str):
            ids = [value.strip() for value in ids.split(',') if value.strip()]
        ids = set(ids)
    manifest = json.loads((OUT / 'asset_manifest.json').read_text())
    rows = [row for row in manifest['assets'] if ids is None or row['id'] in ids]
    if not rows or (ids is not None and ids != {row['id'] for row in rows}):
        raise ValueError('Unknown/empty requested IDs: ' + str(ids))
    report = dict(status='preflight', requested_ids=[row['id'] for row in rows],
                  destination=DEST, source_manifest_sha256=digest(OUT / 'asset_manifest.json'),
                  meshes=[], materials={}, textures={}, errors=[])
    report_dir = OUT / 'Reports'
    report_dir.mkdir(parents=True, exist_ok=True)
    suffix = 'all' if ids is None else '_'.join(sorted(ids))
    if len(suffix)>80:
        suffix=sorted(ids)[0]+'-'+sorted(ids)[-1]+'_'+hashlib.sha256(suffix.encode()).hexdigest()[:10]
    report_file = report_dir / ('unreal_import_' + suffix + '.json')
    try:
        all_recipes = recipes()
        needed = set(key for row in rows for key in row['material_keys'])
        # The complete authored surface family is reusable beyond the current placement.
        needed.update('TX' + str(i).zfill(2) for i in range(1, 20))
        unknown = needed - set(all_recipes)
        if unknown:
            raise ValueError('Unknown material keys: ' + str(sorted(unknown)))
        texture_specs = {}
        for key in sorted(needed):
            recipe = all_recipes[key]
            load_owned(package_path('Materials', 'M_CCK_' + key), unreal.Material)
            for channel, relative in recipe['maps'].items():
                spec = texture_spec(relative, channel, recipe)
                if not spec['source'].is_file():
                    raise FileNotFoundError(spec['source'])
                old = texture_specs.get(relative)
                if old is not None and old != spec:
                    raise ValueError('Conflicting texture sampler settings: ' + relative)
                texture_specs[relative] = spec
                load_owned(package_path('Textures', spec['name']), unreal.Texture2D, spec['source'])
        for row in rows:
            source = OUT / row['fbx']
            if not source.is_file():
                raise FileNotFoundError(source)
            expected_bounds(row)
            if len(row['materials']) != len(row['material_keys']):
                raise ValueError('Missing material slot key: ' + row['id'])
            load_owned(package_path('Meshes', row['name']), unreal.StaticMesh, source)
        report['status'] = 'importing'
        textures = {relative: import_texture(spec) for relative, spec in sorted(texture_specs.items())}
        report['textures'] = {key: value.get_path_name() for key, value in textures.items()}
        materials = {key: make_material(key, all_recipes[key], textures) for key in sorted(needed)}
        report['materials'] = {key: value.get_path_name() for key, value in materials.items()}
        for row in rows:
            report['meshes'].append(import_mesh(row, materials))
            print('CHAIN_KIT_IMPORTED ' + row['id'], flush=True)
        report['status'] = 'passed'
        report['count'] = len(report['meshes'])
    except Exception as exc:
        report['status'] = 'failed'
        report['errors'].append(type(exc).__name__ + ': ' + str(exc))
        raise
    finally:
        report['elapsed_seconds'] = round(time.time() - started, 3)
        report_file.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        print('CHAIN_KIT_IMPORT_REPORT ' + str(report_file), flush=True)
    return report


if __name__ == '__main__':
    main()
