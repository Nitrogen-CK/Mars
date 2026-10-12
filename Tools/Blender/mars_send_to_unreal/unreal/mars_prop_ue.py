"""Unreal side of Send to Unreal (props). Runs inside the editor's Python (Monolith editor_query run_python), loaded
from the Blender add-on's own folder, so it works in whatever project the editor has open, on any branch.

`import_props(jobs, settings)` imports single static-mesh props exported by the panel's "Send Selected Props".

A job: {"fbx": "D:/.../MeatCleaver_Mars_SM.fbx", "name": "MeatCleaver_Mars_SM",
        "folder": "/Game/Mars/Gameplay/Cooking/Stations/Meshes",    # only used when the asset does not exist yet
        "sockets": ["Grip_R", ...]}                                 # the SOCKET_ empties exported, checked after import
Settings (the add-on's profile of the open project; every key optional):
        {"search_root": "/Game",              # where an existing asset of that name is looked for
         "material_pattern": "{slot}"}        # the name of the material a slot is bound to, e.g. "{slot}_Mars_MI"

Where a prop lands: a StaticMesh of that name anywhere under search_root is re-imported IN PLACE; only a new name goes
to the job's folder.  Two assets with the same name is an error for that job: the panel cannot know which is meant.

The import is the legacy FBX importer with Interchange's FBX flag off for the batch: authored normals, no lightmap UV
generation (extra UV channels may carry data), no auto collision - the UCX_<Name>_NN children are the collision, one
convex hull each - and SOCKET_<Name> empties become mesh sockets.  Materials: a slot keeps the material it had before
the import; a slot left on the default material is bound to the material named by material_pattern if the project has
one under search_root (when several share the name, the one nearest the mesh's own folder).
Returns {"imported": [...], "failed": [...], "skipped": [...], "report": {name: {...}}, "error": str or None}.
"""

import os
import re

import unreal

import mars_character_ue as base

EAL = unreal.EditorAssetLibrary
DEFAULTS = {"search_root": "/Game", "material_pattern": "{slot}"}
DEFAULT_MATERIALS = ("WorldGridMaterial", "DefaultMaterial")
MATERIAL_CLASSES = ("Material", "MaterialInstanceConstant")


def _assets(root, classes):
    ar = unreal.AssetRegistryHelpers.get_asset_registry()
    flt = unreal.ARFilter(class_paths=[unreal.TopLevelAssetPath("/Script/Engine", c) for c in classes],
                          package_paths=[root], recursive_paths=True)
    return ar.get_assets(flt)


def find_static_meshes(name, search_root="/Game"):
    """Package paths of every StaticMesh called `name` under search_root."""
    return sorted(str(a.package_name) for a in _assets(search_root, ("StaticMesh",)) if str(a.asset_name) == name)


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


class _Materials:
    """The project's materials by name (one registry query per import call)."""

    def __init__(self, settings):
        self.pattern = settings["material_pattern"]
        self.by_name = {}
        for a in _assets(settings["search_root"], MATERIAL_CLASSES):
            self.by_name.setdefault(str(a.asset_name), []).append(str(a.package_name))

    def for_slot(self, slot, near):
        slot = re.sub(r"[._]\d{3}$", "", slot)       # Blender's Stone.001 (imported as Stone_001) is still the Stone slot
        try:
            name = self.pattern.format(slot=slot)
        except (KeyError, IndexError, ValueError):
            return None
        found = self.by_name.get(name)
        if not found:
            return None

        def shared(path):                              # folders in common with the mesh's own path
            n = 0
            for a, b in zip(path.split("/"), near.split("/")):
                if a != b:
                    break
                n += 1
            return n
        best = sorted(found, key=lambda p: (-shared(p), p))[0]
        return base._load("%s.%s" % (best, name))


def _bind_slots(mesh, before, materials, near):
    """Restore the pre-import materials by slot name, then give the slots still on the default material the project's
    material for that slot.  Returns {slot: material name or None}."""
    base._restore_materials(mesh, before)
    out = {}
    for i, m in enumerate(mesh.static_materials):
        name = str(m.material_slot_name)
        mat = m.material_interface
        if _is_default(mat):
            mi = materials.for_slot(name, near)
            if mi is not None:
                mesh.set_material(i, mi)
                mat = mi
        out[name] = None if _is_default(mat) else mat.get_name()
    return out


def import_props(jobs, settings=None, save=True):
    cfg = dict(DEFAULTS)
    cfg.update({k: v for k, v in (settings or {}).items() if v})
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
        found = find_static_meshes(name, cfg["search_root"])
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
    materials = _Materials(cfg)
    for name, path, before, is_new, want_sockets in entries:
        mesh = base._load(path)
        if mesh is None:
            res["failed"].append(name)
            unreal.log_warning("Send to Unreal: prop %s did not import" % name)
            continue
        slots = _bind_slots(mesh, before, materials, path.split(".")[0])
        body = mesh.get_editor_property("body_setup")
        hulls = len(body.get_editor_property("agg_geom").get_editor_property("convex_elems")) if body else 0
        missing = sorted(s for s in want_sockets if mesh.find_socket(s) is None)
        res["report"][name] = {"path": path.split(".")[0], "new": is_new, "slots": slots, "convex": hulls,
                               "sockets": len(want_sockets) - len(missing), "sockets_missing": missing,
                               "unbound": sorted(s for s, m in slots.items() if m is None)}
        if save:
            EAL.save_loaded_asset(mesh)
        res["imported"].append(name)
    unreal.log("Send to Unreal: %d props imported, %d failed, %d skipped" % (
        len(res["imported"]), len(res["failed"]), len(res["skipped"])))
    return res
