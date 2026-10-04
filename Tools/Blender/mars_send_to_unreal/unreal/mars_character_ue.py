"""Unreal side of Mars - Send to Unreal (character). Runs inside the editor's Python (Monolith editor_query
run_python); `import_character(jobs)` re-imports exported FBX files onto their existing assets.

A job: {"fbx": "D:/.../SK_Chef.fbx", "folder": "/Game/Mars/Gameplay/PlayerCharacter/Chef/Meshes", "name": "SK_Chef",
        "kind": "skeletal" | "static" | "anim", "skeleton": "/Game/.../SKEL_Chef" or None}

Imports go through the legacy FBX importer (FbxImportUI, synchronous AssetImportTask) with Interchange's FBX
feature flag switched off for the batch and restored after, as the crypt kit's mise_mars_ue does: Interchange
imports asynchronously and cannot be given a skeleton from here. An existing SkeletalMesh keeps its skeleton,
physics asset and material slots (the slots are restored by name after the import); an existing AnimSequence is
reused by the importer, so its notifies, curves and the montages built on it survive. Returns
{"imported": [...], "failed": [...], "skipped": [...], "error": str or None}.
"""

import os

import unreal

EAL = unreal.EditorAssetLibrary
FBX_FLAG = "Interchange.FeatureFlags.Import.FBX"


def _load(path):
    try:
        return unreal.load_object(None, path) if EAL.does_asset_exist(path) else None
    except Exception:
        return None


def _asset_path(folder, name):
    return "%s/%s.%s" % (folder, name, name)


def _in_pie():
    try:
        return unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).is_in_play_in_editor()
    except Exception:
        return False


def _set(obj, name, value):
    """set_editor_property for the import options that are not plain attributes in every engine build."""
    try:
        obj.set_editor_property(name, value)
        return True
    except Exception:
        return False


def _task(job):
    task = unreal.AssetImportTask()
    task.filename = job["fbx"]
    task.destination_path = job["folder"]
    task.destination_name = job["name"]
    task.replace_existing = True
    task.automated = True
    task.save = False
    try:
        task.set_editor_property("async_", False)
    except Exception:
        pass
    return task


def _options(job, existing):
    opts = unreal.FbxImportUI()
    opts.automated_import_should_detect_type = False
    opts.import_materials = False
    opts.import_textures = False
    kind = job["kind"]
    skeleton = _load(job["skeleton"]) if job.get("skeleton") else None
    if existing is not None and kind == "skeletal":
        skeleton = existing.skeleton or skeleton
    if kind == "skeletal":
        opts.import_mesh = True
        opts.import_as_skeletal = True
        opts.import_animations = False
        opts.mesh_type_to_import = unreal.FBXImportType.FBXIT_SKELETAL_MESH
        opts.skeleton = skeleton
        opts.create_physics_asset = existing is None
        if existing is not None and existing.physics_asset is not None:
            opts.physics_asset = existing.physics_asset
        d = opts.skeletal_mesh_import_data
        d.normal_import_method = unreal.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS
        _set(d, "import_morph_targets", False)
        _set(d, "update_skeleton_reference_pose", False)
        _set(d, "use_t0_as_ref_pose", False)
    elif kind == "static":
        opts.import_mesh = True
        opts.import_as_skeletal = False
        opts.import_animations = False
        opts.mesh_type_to_import = unreal.FBXImportType.FBXIT_STATIC_MESH
        d = opts.static_mesh_import_data
        d.combine_meshes = True
        d.generate_lightmap_u_vs = False
        d.normal_import_method = unreal.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS
    elif kind == "anim":
        opts.import_mesh = False
        opts.import_as_skeletal = False
        opts.import_animations = True
        opts.mesh_type_to_import = unreal.FBXImportType.FBXIT_ANIMATION
        opts.skeleton = skeleton
        d = opts.anim_sequence_import_data
        _set(d, "import_bone_tracks", True)
        _set(d, "remove_redundant_keys", False)
    else:
        raise ValueError("unknown job kind %r" % kind)
    return opts


def _materials(asset):
    """[(slot name, material)] of a skeletal or static mesh."""
    if isinstance(asset, unreal.SkeletalMesh):
        return [(str(m.material_slot_name), m.material_interface) for m in asset.materials]
    if isinstance(asset, unreal.StaticMesh):
        return [(str(m.material_slot_name), m.material_interface) for m in asset.static_materials]
    return []


def _restore_materials(asset, before):
    """Put the pre-import material back on every slot the import left empty or on the default material."""
    want = dict(before)
    if isinstance(asset, unreal.SkeletalMesh):
        mats = list(asset.materials)
        for i, m in enumerate(mats):
            name = str(m.material_slot_name)
            if name in want and want[name] is not None and m.material_interface != want[name]:
                mats[i] = unreal.SkeletalMaterial(material_interface=want[name], material_slot_name=m.material_slot_name)
        asset.set_editor_property("materials", mats)
    elif isinstance(asset, unreal.StaticMesh):
        for i, m in enumerate(asset.static_materials):
            name = str(m.material_slot_name)
            if name in want and want[name] is not None and m.material_interface != want[name]:
                asset.set_material(i, want[name])


def import_character(jobs, save=True):
    res = {"imported": [], "failed": [], "skipped": [], "error": None}
    if _in_pie():
        res["error"] = "the editor is in PIE - stop it and send again"
        return res
    tasks, entries = [], []
    for job in jobs:
        if not os.path.isfile(job["fbx"]):
            res["skipped"].append("%s (no file %s)" % (job["name"], job["fbx"]))
            continue
        path = _asset_path(job["folder"], job["name"])
        existing = _load(path)
        if job["kind"] in ("skeletal", "anim") and job.get("skeleton") and _load(job["skeleton"]) is None \
                and (existing is None or job["kind"] == "anim"):
            res["skipped"].append("%s (skeleton %s missing)" % (job["name"], job["skeleton"]))
            continue
        task = _task(job)
        task.options = _options(job, existing)
        tasks.append(task)
        entries.append((job, path, _materials(existing) if existing is not None else []))
    if not tasks:
        return res
    was = unreal.SystemLibrary.get_console_variable_bool_value(FBX_FLAG)
    unreal.SystemLibrary.execute_console_command(None, "%s 0" % FBX_FLAG)
    try:
        unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks(tasks)
    finally:
        unreal.SystemLibrary.execute_console_command(None, "%s %d" % (FBX_FLAG, 1 if was else 0))
    for job, path, before in entries:
        asset = _load(path)
        if asset is None:
            res["failed"].append(job["name"])
            unreal.log_warning("Mars send: %s did not import from %s" % (job["name"], job["fbx"]))
            continue
        if before:
            _restore_materials(asset, before)
        if save:
            EAL.save_loaded_asset(asset)
        res["imported"].append(job["name"])
    unreal.log("Mars send: %d imported, %d failed, %d skipped" % (
        len(res["imported"]), len(res["failed"]), len(res["skipped"])))
    return res
