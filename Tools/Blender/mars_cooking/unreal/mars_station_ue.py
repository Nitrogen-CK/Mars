"""Editor side of the Mars cooking STATION props (fryer vat / baskets, cutting station, hearth): imports the FBXs the
station builders export (station_spec.EXPORT_DIR) with their UCX collision and SOCKET_ empties intact, makes the
accent instances for the new slots (Iron / Wire / Rope on Accent_Mars_M, Ember on the environment Emissive_Mars_M),
assigns slots from the JSON sidecars, builds StationLookdev_Mars_MAP from the layout JSONs and captures review shots.
Run in the editor's Python (Monolith `editor_query run_python`):

    import sys, importlib
    sys.path.insert(0, r"D:\\Repo\\Mars\\Tools\\Blender\\mars_cooking\\unreal")
    import mars_station_ue as ms; importlib.reload(ms)
    ms.run_all()            # import_meshes, build_materials, assign_slots, build_lookdev_map
    ms.capture(r"D:\\Repo\\Content\\Cooking\\export\\stations\\review\\ue")

Reuses mars_cooking_ue (import task, asset helpers, lookdev rig, spawn) and mars_food_ue's material helper without
reloading or editing them. Never calls the food importer's collision replacement: the station vessels rely on their
authored UCX pieces (a 26-DOP hull would seal a bowl).
"""
import glob
import importlib
import json
import math
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
for _p in (HERE, os.path.dirname(HERE)):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import station_spec as ss  # noqa: E402
import mars_cooking_ue as mc  # noqa: E402

importlib.reload(ss)

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary

F_MESH = ss.UE_FOLDER + "/Meshes"
F_MAT = ss.UE_FOLDER + "/Materials"
F_FOOD_MAT = "/Game/Mars/Gameplay/Cooking/Food/Materials"
F_FOOD_INST = F_FOOD_MAT + "/Instances"
F_FOOD_MESH = "/Game/Mars/Gameplay/Cooking/Food/Meshes"
F_COOK_MESH = "/Game/Mars/Gameplay/Cooking/Meshes"
ACCENT_MASTER = F_FOOD_MAT + "/Accent_Mars_M"
EMISSIVE_MASTER = "/Game/Mars/Environment/Materials/Emissive_Mars_M"
LOOKDEV_MAP = "/Game/Mars/Maps/StationLookdev_Mars_MAP"
assert LOOKDEV_MAP not in (mc.spec.UE_LOOKDEV_MAP, "/Game/Mars/Maps/FoodLookdev_Mars_MAP")

# slot -> (parent, scalars, vectors). Stone / Wood instances already exist in the food library.
STATION_LOOK = {
    "Iron": (ACCENT_MASTER, {"Roughness": 0.72, "Specular": 0.45}, {}),
    "Wire": (ACCENT_MASTER, {"Roughness": 0.55, "Specular": 0.5}, {}),
    "Rope": (ACCENT_MASTER, {"Roughness": 0.9, "Specular": 0.3}, {}),
    "Ember": (EMISSIVE_MASTER, {"Strength": 8.0}, {"Color": (1.0, 0.40, 0.08, 1.0)}),
    # The cutting station's sliceable MeatSlab lives as a procedural mesh copy (no vertex colours survive the copy), so its
    # flesh, fat cap and the cut faces the slicing caps with are flat Accent tints rather than the food master.
    "MeatSlabFlesh": (ACCENT_MASTER, {"Roughness": 0.5, "Specular": 0.4}, {"Tint": (0.55, 0.06, 0.05, 1.0)}),
    "MeatSlabFat": (ACCENT_MASTER, {"Roughness": 0.55, "Specular": 0.35}, {"Tint": (0.86, 0.76, 0.6, 1.0)}),
    "MeatSlabCut": (ACCENT_MASTER, {"Roughness": 0.45, "Specular": 0.45}, {"Tint": (0.78, 0.16, 0.14, 1.0)}),
}
FOOD_SLOTS = ("Stone", "Wood")


def _log(msg):
    unreal.log("[station] %s" % msg)


def _warn(msg):
    unreal.log_warning("[station] %s" % msg)


def export_dir(path=None):
    return path or ss.EXPORT_DIR


def read_metas(folder):
    metas = []
    for p in sorted(glob.glob(os.path.join(folder, "*_Mars_SM.json"))):
        try:
            with open(p) as fh:
                metas.append(json.load(fh))
        except Exception as exc:
            _warn("%s unreadable: %s" % (p, exc))
    return metas


# ------------------------------------------------------------------ meshes
def _mesh_task(path, name):
    """Legacy FBX import: normals as authored (flat facets), no lightmap UVs, no auto collision (the UCX_ children are
    the collision), vertex colours replaced, sockets from SOCKET_ empties, Nanite off."""
    task = mc._task(path, F_MESH, name)
    opts = unreal.FbxImportUI()
    opts.import_mesh = True
    opts.import_as_skeletal = False
    opts.import_materials = False
    opts.import_textures = False
    sm = opts.static_mesh_import_data
    sm.combine_meshes = True
    sm.generate_lightmap_u_vs = False
    sm.auto_generate_collision = False
    sm.set_editor_property("normal_import_method", unreal.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS)
    for prop, value in (("vertex_color_import_option", unreal.VertexColorImportOption.REPLACE), ("build_nanite", False),
                        ("remove_degenerates", True), ("one_convex_hull_per_ucx", True)):
        try:
            sm.set_editor_property(prop, value)
        except Exception:
            pass
    task.options = opts
    return task


def _check_mesh(mesh, meta):
    """Report what the import produced against the sidecar: sockets, collision pieces, slot names."""
    sme = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
    name = mesh.get_name()
    want_sockets = sorted((meta.get("sockets") or {}).keys())
    missing = [s for s in want_sockets if mesh.find_socket(s) is None]
    try:
        hulls = sme.get_convex_collision_count(mesh)
    except Exception:
        hulls = -1
    try:
        simple = sme.get_simple_collision_count(mesh)
    except Exception:
        simple = -1
    slots = [str(s.get_editor_property("material_slot_name")) for s in mesh.get_editor_property("static_materials")]
    _log("%s: slots %s  sockets %s%s  convex %d simple %d (sidecar ucx %s)" % (
        name, slots, want_sockets, ("  MISSING %s" % missing) if missing else "", hulls, simple, meta.get("ucx_pieces")))
    if missing:
        _warn("%s: sockets missing after import: %s" % (name, missing))
    if meta.get("ucx_pieces") and hulls == 0:
        _warn("%s: no convex hulls imported though the FBX carries %d UCX pieces" % (name, meta["ucx_pieces"]))
    return {"name": name, "slots": slots, "sockets_missing": missing, "convex": hulls, "simple": simple}


def import_meshes(path=None):
    if mc._in_pie():
        raise RuntimeError("stop PIE before importing (assets imported during PIE vanish)")
    src = export_dir(path)
    files = sorted(glob.glob(os.path.join(src, "*_Mars_SM.fbx")))
    if not files:
        _warn("no *_Mars_SM.fbx in %s" % src)
        return []
    metas = {m["name"]: m for m in read_metas(src)}
    names = [os.path.splitext(os.path.basename(p))[0] for p in files]
    tasks = [_mesh_task(p, n) for p, n in zip(files, names)]
    cvar = "Interchange.FeatureFlags.Import.FBX"            # the legacy importer honours FbxImportUI (and UCX / sockets)
    was = unreal.SystemLibrary.get_console_variable_bool_value(cvar)
    unreal.SystemLibrary.execute_console_command(None, "%s 0" % cvar)
    try:
        mc._tools().import_asset_tasks(tasks)
    finally:
        unreal.SystemLibrary.execute_console_command(None, "%s %d" % (cvar, 1 if was else 0))
    reports = []
    for name in names:
        mesh = mc._asset(F_MESH, name)
        if mesh is None:
            _warn("mesh %s did not import" % name)
            continue
        reports.append(_check_mesh(mesh, metas.get(name, {})))
        EAL.save_loaded_asset(mesh)
    _log("%d of %d station meshes imported from %s" % (len(reports), len(names), src))
    return reports


# ------------------------------------------------------------------ materials
def _instance(name, folder, parent_path, scalars, vectors):
    parent = mc._load(parent_path)
    if parent is None:
        _warn("%s: parent %s missing" % (name, parent_path))
        return None
    inst = mc._asset(folder, name)
    created = inst is None
    if created:
        inst = mc._tools().create_asset(name, folder, unreal.MaterialInstanceConstant,
                                        unreal.MaterialInstanceConstantFactoryNew())
    MEL.set_material_instance_parent(inst, parent)
    if created:                                   # look presets only on creation: artist edits survive a rerun
        for k, v in scalars.items():
            MEL.set_material_instance_scalar_parameter_value(inst, k, float(v))
        for k, v in vectors.items():
            MEL.set_material_instance_vector_parameter_value(inst, k, unreal.LinearColor(*v))
    MEL.update_material_instance(inst)
    EAL.save_loaded_asset(inst)
    return inst


def build_materials():
    made = []
    for slot, (parent, scalars, vectors) in STATION_LOOK.items():
        inst = _instance("%s_Mars_MI" % slot, F_MAT, parent, scalars, vectors)
        if inst is not None:
            made.append(inst.get_name())
    _log("station instances: %s" % made)
    return made


def slot_material(slot):
    if slot in FOOD_SLOTS:
        return mc._asset(F_FOOD_INST, "%s_Mars_MI" % slot)
    return mc._asset(F_MAT, "%s_Mars_MI" % slot)


def assign_slots(path=None):
    assigned, missing = 0, set()
    for meta in read_metas(export_dir(path)):
        mesh = mc._asset(F_MESH, meta["name"])
        if mesh is None:
            continue
        changed = False
        for i, sm in enumerate(mesh.get_editor_property("static_materials")):
            slot = str(sm.get_editor_property("material_slot_name")).split(".")[0]
            mi = slot_material(slot)
            if mi is None:
                missing.add(slot)
                continue
            mesh.set_material(i, mi)
            changed = True
            assigned += 1
        if changed:
            EAL.save_loaded_asset(mesh)
    if missing:
        _warn("no instance for slots %s (run build_materials / the food library)" % sorted(missing))
    _log("%d station slots assigned" % assigned)


# ------------------------------------------------------------------ lookdev
def _place(mesh_name, loc, rot=(0.0, 0.0, 0.0), scale=1.0, label=None, folder="Stations", material_overrides=None):
    mesh = None
    for f in (F_MESH, F_FOOD_MESH, F_COOK_MESH):
        mesh = mc._asset(f, mesh_name)
        if mesh is not None:
            break
    if mesh is None:
        _warn("mesh %s not found for the lookdev" % mesh_name)
        return None
    a = mc._spawn(mesh, tuple(loc), tuple(rot), label or mesh_name, folder)
    s = scale if isinstance(scale, (tuple, list)) else (scale, scale, scale)
    a.set_actor_scale3d(unreal.Vector(*s))
    if material_overrides:
        comp = a.get_component_by_class(unreal.StaticMeshComponent)
        for i, mi in material_overrides.items():
            comp.set_material(int(i), mi)
    return a


def _layout_entries(layout):
    """Normalise a station layout JSON into [(mesh, location_cm, rotation_deg, scale, label)]: accepts a list of
    entries or a dict of name -> entry, each with mesh / location_cm (or location) / rotation_deg / scale."""
    items = layout.get("props", layout.get("placements", layout)) if isinstance(layout, dict) else layout
    entries = []
    pairs = items.items() if isinstance(items, dict) else [(None, e) for e in items]
    for key, e in pairs:
        if not isinstance(e, dict):
            continue
        mesh = e.get("mesh") or e.get("name") or (key if key and key.endswith("_Mars_SM") else None)
        loc = e.get("location_cm") or e.get("location")
        if not mesh or loc is None or (key and key.endswith("_Raised")):      # one pose per prop in the lookdev
            continue
        if not mesh.endswith("_Mars_SM"):
            mesh += "_Mars_SM"
        rot = e.get("rotation_deg") or e.get("rotation") or (0.0, 0.0, 0.0)
        if isinstance(rot, dict):
            rot = (rot.get("roll", 0.0), rot.get("pitch", 0.0), rot.get("yaw", 0.0))
        entries.append((mesh, loc, rot, e.get("scale", 1.0), e.get("label") or key or mesh))
    return entries


STATION_OFFSETS = {"FryerStation": (0.0, -260.0), "CuttingStation": (0.0, 0.0), "HearthStation": (0.0, 260.0)}


def build_lookdev_map(path=None, stay=False):
    """The three stations side by side along Y (operator side -X) from their *_Layout.json, under the gyms' lighting
    (mars_cooking_ue.lookdev_rig). Rebuilt from scratch on every call."""
    if mc._in_pie():
        raise RuntimeError("stop PIE before building the lookdev map")
    les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    current = world.get_outermost().get_name() if world else None
    dirty = [p.get_name() for p in unreal.EditorLoadingAndSavingUtils.get_dirty_map_packages()]
    if current in dirty and current != LOOKDEV_MAP:
        raise RuntimeError("%s has unsaved changes; save it before building the station lookdev" % current)
    if EAL.does_asset_exist(LOOKDEV_MAP):
        les.load_level(LOOKDEV_MAP)
        eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
        eas.destroy_actors([a for a in eas.get_all_level_actors() if not isinstance(a, (unreal.WorldSettings, unreal.Brush))])
    else:
        les.new_level(LOOKDEV_MAP)
    # the cameras stand on the operator side (-X), so the Sun travels toward +X over their shoulder
    mc.lookdev_rig(floor_m=12.0, balls_at=((-120.0, -420.0), (-120.0, -440.0)), sun_yaw=20.0)
    src = export_dir(path)
    placed = 0
    for station, (ox, oy) in STATION_OFFSETS.items():
        p = os.path.join(src, "%s_Layout.json" % station)
        if not os.path.exists(p):
            _warn("no layout %s" % p)
            continue
        with open(p) as fh:
            layout = json.load(fh)
        entries = _layout_entries(layout)
        if station == "HearthStation":                      # the hearth sits on the shared prep table
            entries.insert(0, ("PrepTable_Mars_SM", (0.0, 0.0, 0.0), (0.0, 0.0, 0.0), 1.0, "PrepTable"))
        for mesh, loc, rot, scale, label in entries:
            if _place(mesh, (loc[0] + ox, loc[1] + oy, loc[2]), rot, scale, "%s_%s" % (station, label), station):
                placed += 1
    les.save_current_level()
    if current and current != LOOKDEV_MAP and not stay:
        les.load_level(current)
    _log("station lookdev built: %s (%d props)" % (LOOKDEV_MAP, placed))


# name -> (eye, target, fov); the operator side is -X, so the cameras stand at -X looking +X
SHOTS = {
    "fryer": ((-330, -260, 190), (0, -260, 60), 50),
    "fryer_top": ((-120, -260, 330), (0, -260, 60), 50),
    "cutting": ((-300, 0, 170), (0, 0, 70), 50),
    "cutting_board": ((-110, 0, 150), (0, 0, 72), 55),
    "hearth": ((-220, 260, 160), (0, 260, 80), 45),
    "hearth_low": ((-150, 330, 100), (0, 260, 84), 38),
    "all": ((-560, 0, 330), (0, 0, 60), 70),
}


def capture(out_dir, shots=None, size=(1600, 1000)):
    saved = dict(mc.SHOTS)
    mc.SHOTS.clear()
    mc.SHOTS.update(SHOTS)
    try:
        mc.capture(out_dir, shots=shots, size=size)
    finally:
        mc.SHOTS.clear()
        mc.SHOTS.update(saved)


def run_all(path=None):
    reports = import_meshes(path)
    build_materials()
    assign_slots(path)
    build_lookdev_map(path)
    return reports
