"""Unreal side of Mars - Send to Unreal (props). Runs inside the editor's Python (Monolith editor_query run_python);
`import_props(jobs)` imports single static-mesh props exported by the panel's "Send Selected Props".

A job: {"fbx": "D:/.../MeatCleaver_Mars_SM.fbx", "name": "MeatCleaver_Mars_SM",
        "folder": "/Game/Mars/Gameplay/Cooking/Stations/Meshes",    # only used when the asset does not exist yet
        "sockets": ["Grip_R", ...]}                                 # the SOCKET_ empties exported, checked after import

Where a prop lands: a StaticMesh of that name anywhere under /Game/Mars is re-imported IN PLACE (so a station prop,
a kitchen prop, a food mesh or a candle each go back to their own folder); only a new name goes to the job's folder.
Two assets with the same name is an error for that job: the panel cannot know which one is meant.

The import is the station importer's (mars_station_ue._mesh_task): the legacy FBX importer with Interchange's FBX flag
off for the batch, authored normals, no lightmap UV generation (extra UV channels may carry data), no auto collision -
the UCX_<Name>_NN children are the collision, one convex hull each - and SOCKET_<Name> empties become mesh sockets.
Materials: a slot keeps the material it had before the import; a slot left on the default material is bound to
<Slot>_Mars_MI if one exists in the cooking / environment material folders (the station pipeline's slot convention).
Returns {"imported": [...], "failed": [...], "skipped": [...], "report": {name: {...}}, "error": str or None}.
"""

import os
import re

import unreal

import mars_character_ue as base

EAL = unreal.EditorAssetLibrary
SEARCH_ROOT = "/Game/Mars"
# where a <Slot>_Mars_MI is looked for, first hit wins
SLOT_FOLDERS = ("/Game/Mars/Gameplay/Cooking/Stations/Materials", "/Game/Mars/Gameplay/Cooking/Food/Materials/Instances",
                "/Game/Mars/Gameplay/Cooking/Materials/Instances", "/Game/Mars/Gameplay/Cooking/Candles/Materials",
                "/Game/Mars/Environment/Materials")
DEFAULT_MATERIALS = ("WorldGridMaterial", "DefaultMaterial")


def find_static_meshes(name):
    """Package paths of every StaticMesh called `name` under SEARCH_ROOT."""
    ar = unreal.AssetRegistryHelpers.get_asset_registry()
    flt = unreal.ARFilter(class_paths=[unreal.TopLevelAssetPath("/Script/Engine", "StaticMesh")],
                          package_paths=[SEARCH_ROOT], recursive_paths=True)
    return sorted(str(a.package_name) for a in ar.get_assets(flt) if str(a.asset_name) == name)


def _options():
    opts = unreal.FbxImportUI()
    opts.automated_import_should_detect_type = False
    opts.import_mesh = True
    opts.import_as_skeletal = False
    opts.import_animations = False
    opts.import_materials = False
    opts.import_textures = False
    opts.mesh_type_to_import = unreal.FBXImportType.FBXIT_STATIC_MESH
    d = opts.static_mesh_import_data
    d.combine_meshes = True
    d.generate_lightmap_u_vs = False
    d.auto_generate_collision = False
    d.normal_import_method = unreal.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS
    for prop, value in (("vertex_color_import_option", unreal.VertexColorImportOption.REPLACE), ("build_nanite", False),
                        ("remove_degenerates", True), ("one_convex_hull_per_ucx", True)):
        base._set(d, prop, value)
    return opts


def _is_default(material):
    return material is None or material.get_name() in DEFAULT_MATERIALS


def _slot_instance(slot):
    slot = re.sub(r"[._]\d{3}$", "", slot)         # Blender's Stone.001 (imported as Stone_001) is still the Stone slot
    for folder in SLOT_FOLDERS:
        mi = base._load("%s/%s_Mars_MI.%s_Mars_MI" % (folder, slot, slot))
        if mi is not None:
            return mi
    return None


def _bind_slots(mesh, before):
    """Restore the pre-import materials by slot name, then give the slots still on the default material their
    <Slot>_Mars_MI.  Returns {slot: material name or None}."""
    base._restore_materials(mesh, before)
    out = {}
    for i, m in enumerate(mesh.static_materials):
        name = str(m.material_slot_name)
        mat = m.material_interface
        if _is_default(mat):
            mi = _slot_instance(name)
            if mi is not None:
                mesh.set_material(i, mi)
                mat = mi
        out[name] = None if _is_default(mat) else mat.get_name()
    return out


def import_props(jobs, save=True):
    res = {"imported": [], "failed": [], "skipped": [], "report": {}, "error": None}
    if base._in_pie():
        res["error"] = "the editor is in PIE - stop it and send again"
        return res
    tasks, entries = [], []
    for job in jobs:
        name = job["name"]
        if not os.path.isfile(job["fbx"]):
            res["skipped"].append("%s (no file %s)" % (name, job["fbx"]))
            continue
        found = find_static_meshes(name)
        if len(found) > 1:
            res["skipped"].append("%s (%d assets share the name: %s)" % (name, len(found), ", ".join(found)))
            continue
        folder = found[0].rsplit("/", 1)[0] if found else job["folder"]
        path = base._asset_path(folder, name)
        existing = base._load(path)
        task = base._task({"fbx": job["fbx"], "folder": folder, "name": name})
        task.options = _options()
        tasks.append(task)
        entries.append((name, path, base._materials(existing) if existing is not None else [], existing is None,
                        list(job.get("sockets") or [])))
    if not tasks:
        return res
    was = unreal.SystemLibrary.get_console_variable_bool_value(base.FBX_FLAG)
    unreal.SystemLibrary.execute_console_command(None, "%s 0" % base.FBX_FLAG)
    try:
        unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks(tasks)
    finally:
        unreal.SystemLibrary.execute_console_command(None, "%s %d" % (base.FBX_FLAG, 1 if was else 0))
    for name, path, before, is_new, want_sockets in entries:
        mesh = base._load(path)
        if mesh is None:
            res["failed"].append(name)
            unreal.log_warning("Mars send: prop %s did not import" % name)
            continue
        slots = _bind_slots(mesh, before)
        body = mesh.get_editor_property("body_setup")
        hulls = len(body.get_editor_property("agg_geom").get_editor_property("convex_elems")) if body else 0
        missing = sorted(s for s in want_sockets if mesh.find_socket(s) is None)
        res["report"][name] = {"path": path.split(".")[0], "new": is_new, "slots": slots, "convex": hulls,
                               "sockets": len(want_sockets) - len(missing), "sockets_missing": missing,
                               "unbound": sorted(s for s, m in slots.items() if m is None)}
        if save:
            EAL.save_loaded_asset(mesh)
        res["imported"].append(name)
    unreal.log("Mars send: %d props imported, %d failed, %d skipped" % (
        len(res["imported"]), len(res["failed"]), len(res["skipped"])))
    return res
