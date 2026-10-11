"""Cube vs cut-piece look parity capture (Stephen 2026-10-10: a player who cuts meat at the bench must get the same
sear behaviour and the same visual quality in the pan as the steak minigame's MeatCube_Mars_SM).

Renders, under the CookingLookdev_Mars_MAP lighting, side by side and at the same cook states (Custom Primitive Data on
the static-mesh component, the contract every cooking mesh shares):

    Cube      MeatCube_Mars_SM + Meat_Wagyu_Mars_MI (Meat_Mars_M)                the reference
    Slab      MeatSlab_Mars_SM as imported in the project + MeatSlab_Mars_MI      (Food_Mars_M), before the prep standard
    Slab std  the re-exported MeatSlab_Mars_SM.fbx (prep standard) + MeatSlab_Mars_MI, imported transient
    Half      MeatSlab_HalfA_Mars_SM.fbx (the standard slab cut at x = 0, flat cut-lean cap) + MeatSlab_Mars_MI
    Half TUNED  the half on a transient child of MeatSlab_Mars_MI with TUNED_* (proves instance params cannot fix it)
    Slab Meat   MeatSlab_Mars_SM on Meat_Mars_M: MeatSlab_Wagyu_Mars_MI (mars_meat_ue), every slot
    Half Meat   the half stand-in on MeatSlab_Wagyu_Mars_MI, its cut cap slot (2) on MeatSlab_WagyuCap_Mars_MI

MeatSlab_Wagyu_Mars_MI is used as saved when it exists; otherwise it is built transiently (mars_meat_ue with save off:
its two textures import from food_spec.EXPORT_DIR into the transient folder, nothing is saved). --meat_params '{"Band
Depth": 1.5}' renders the two Meat columns on a transient child of it carrying those scalar overrides (look iteration
without touching the saved instance). --columns cube,slabmeat,halfmeat limits the run to those columns.

Lighting: the pieces are spawned parked off the counter (PARK_ORIGIN grid, hidden from every capture) and each one is
moved onto STUDIO_SPOT, on the lookdev map's Counter (its floor) inside the studio reflection capture's radius, only
for its own capture and parked again after it, so every tile gets the same floor bounce, key / fill shadows and
reflections, and no neighbour shades another.

States (STATES): raw, -Z seared (Penetration 1/6), three faces, all six (Penetration 1, Shape 1), all six oiled, one
burnt face (1.9). Two views per state: "crust" (the piece flipped so its seared -Z face looks up, cube_crust style 3/4
from above) and "band" (upright, low side view: the cooked band creeping up from the -Z face, cube_band style).

Run OUTSIDE the editor (plain Python 3 + Pillow); it drives a HIDDEN editor over Monolith JSON-RPC:

    python mars_cook_parity.py --launch --port 9317 --out D:\\Repo\\Content\\Cooking\\export\\review\\parity

--launch starts MarsEditor.exe -RenderOffscreen on that Monolith port, waits for it, builds the scene in memory (the
lookdev map is loaded but NEVER saved; the two FBX meshes import into /Game/Mars/Maps/CookParity unsaved), captures in a
second call (the reflection capture needs a tick), quits the editor and writes the contact sheets. Without --launch it
talks to an editor already on --port. Never point it at Stephen's interactive editor (9316) while he works.
"""
import argparse
import importlib
import json
import math
import os
import subprocess
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))       # D:\Repo\Mars
UPROJECT = os.path.join(PROJECT, "Mars.uproject")
EDITOR = os.path.join(PROJECT, "Binaries", "Win64", "MarsEditor.exe")
DEFAULT_OUT = r"D:\Repo\Content\Cooking\export\review\parity"
FOOD_EXPORT = r"D:\Repo\Content\Cooking\export\food"

LOOKDEV_MAP = "/Game/Mars/Maps/CookingLookdev_Mars_MAP"
TRANSIENT = "/Game/Mars/Maps/CookParity"                   # in-memory imports, never saved
CUBE = "/Game/Mars/Gameplay/Cooking/Meshes/MeatCube_Mars_SM.MeatCube_Mars_SM"
CUBE_MI = "/Game/Mars/Gameplay/Cooking/Materials/Instances/Meat_Wagyu_Mars_MI.Meat_Wagyu_Mars_MI"
SLAB = "/Game/Mars/Gameplay/Cooking/Food/Meshes/MeatSlab_Mars_SM.MeatSlab_Mars_SM"
SLAB_MI = "/Game/Mars/Gameplay/Cooking/Food/Materials/Instances/MeatSlab_Mars_MI.MeatSlab_Mars_MI"
MEAT_FOLDER = "/Game/Mars/Gameplay/Cooking/Food/Materials/Instances"
MEAT_MI_NAME = "MeatSlab_Wagyu_Mars_MI"                    # mars_meat_ue.INSTANCES: the body
MEAT_CAP_MI_NAME = "MeatSlab_WagyuCap_Mars_MI"             # and the cut cap slot
MEAT_ITER_MI = "MeatSlabParityMeat_Mars_MI"                 # transient children carrying --meat_params
MEAT_ITER_CAP_MI = "MeatSlabParityMeatCap_Mars_MI"
CAP_SLOT = 2                                                # the Food def's Visuals.Cap material ID
HALF_FBX = os.path.join(DEFAULT_OUT, "src", "MeatSlab_HalfA_Mars_SM.fbx")

# column -> (label, mesh source: asset path or FBX path, material, transient asset name)
COLUMNS = (
    ("cube", "Cube (Meat_Wagyu_Mars_MI)", CUBE, CUBE_MI, None),
    ("slab", "Slab as imported (MeatSlab_Mars_MI)", SLAB, SLAB_MI, None),
    ("slabstd", "Slab, prep standard (MeatSlab_Mars_MI)", os.path.join(FOOD_EXPORT, "MeatSlab_Mars_SM.fbx"), SLAB_MI,
     "MeatSlabStd_Parity_Mars_SM"),
    ("half", "Half slab, cut cap (MeatSlab_Mars_MI)", HALF_FBX, SLAB_MI, "MeatSlab_HalfA_Mars_SM"),
    ("halftuned", "Half slab + TUNED instance params", HALF_FBX, "TUNED", "MeatSlab_HalfA_Mars_SM"),
    ("slabmeat", "Slab on Meat_Mars_M (MeatSlab_Wagyu_Mars_MI)", SLAB, "MEAT", None),
    ("halfmeat", "Half on Meat_Mars_M (MeatSlab_Wagyu_Mars_MI)", HALF_FBX, "MEAT", "MeatSlab_HalfA_Mars_SM"),
)
# Candidate MeatSlab_Mars_MI overrides that bring Food_Mars_M toward Meat_Wagyu_Mars_MI (plain instance parameters):
# rendered on a transient child instance of MeatSlab_Mars_MI (never saved) for the "halftuned" column.
TUNED_MI = "MeatSlabParityTuned_Mars_MI"
TUNED_SCALARS = {
    "Face Sharpness": 6.0,          # cube 6: each sear stays on its own face
    "Crevice Lag": 0.0,             # Meat_Mars_M has no cook-first lag: the full CPD sear lands on every facet
    "Band Depth": 1.1, "Band Wobble": 0.25, "Crust Breakup": 0.15, "Edge Boost": 0.3,     # the Wagyu numbers (cm)
    "Crust Replace": 0.85,          # the crust pulled to the crust albedo, not a darker red
    "Raw Wetness": 1.0, "Oil Coat Strength": 0.4, "Glaze Strength": 0.3,                # raw coat 0.4, oil coat 0.32
    "Oil Coat Roughness": 0.2, "Oil Coat Breakup": 0.6, "Oil Base Gloss": 1.0,
}
TUNED_VECTORS = {
    "Crust Albedo": (0.133, 0.051, 0.023, 1.0),     # the lean ramp at sear 1 (curve time 0.5)
}
# state -> (label, Sear XY (+X -X +Y -Y), Sear Z + Cook (+Z -Z Penetration Oil), Finish (Glaze Shape Fry Wet))
STATES = (
    ("raw", "raw", (0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0)),
    ("one", "-Z seared, Pen 1/6", (0, 0, 0, 0), (0, 1.0, 1.0 / 6.0, 0), (0, 0, 0, 0)),
    ("three", "-Z +X +Y seared, Pen 1/2", (1.0, 0, 1.0, 0), (0, 1.0, 0.5, 0), (0, 0.5, 0, 0)),
    ("six", "all six, Pen 1, Shape 1", (1, 1, 1, 1), (1, 1, 1, 0), (0, 1, 0, 0)),
    ("oiled", "all six + Oil 0.8", (1, 1, 1, 1), (1, 1, 1, 0.8), (0, 1, 0, 0)),
    ("burnt", "-Z burnt 1.9, Pen 1/6", (0, 0, 0, 0), (0, 1.9, 1.0 / 6.0, 0), (0, 0, 0, 0)),
)
# view -> (flip the piece so local -Z looks up, camera elevation deg, camera yaw from +X toward -Y deg, fov)
# A flip is a 180 deg roll about X: local +X stays +X, local +Y -> world -Y, local -Z -> world +Z, so the camera at
# (+x, -y, +z) sees the seared -Z face on top and local +X / +Y on the sides (the "three" state's faces).
VIEWS = {
    "crust": (True, 38.0, -35.0, 30.0),
    "band": (False, 9.0, -35.0, 30.0),
}
PARK_ORIGIN = (0.0, -420.0)          # parking grid, off the 600 x 600 cm Counter (x, y in -300..300): never in a frame
GRID_STEP = 140.0                    # cm between parked pieces
# where each piece stands for its capture: on the Counter (the lookdev floor, top at z = 0), clear of the pans at
# (0, 0) / (48, 0) and the cube row at y = -34, within the studio SphereReflectionCapture's 400 cm (it sits at
# (20, 10, 14)); the cameras look from +x / -y toward -x / +y, so the pans and cubes stay behind them
STUDIO_SPOT = (-150.0, -150.0)
FLOOR_LABEL = "Counter"


# ====================================================================================== editor side (import unreal)
def _u():
    import unreal
    return unreal


def _log(msg):
    _u().log("MarsCookParity: %s" % msg)


def _load(path):
    unreal = _u()
    obj = unreal.EditorAssetLibrary.load_asset(path) if unreal.EditorAssetLibrary.does_asset_exist(path) else None
    return obj or unreal.find_object(None, path)


def _import_fbx(fbx, name):
    """Legacy FBX import as mars_food_ue._mesh_task does (normals, vertex colours, combined, degenerates kept), into the
    TRANSIENT folder, save off: the asset lives in memory only."""
    unreal = _u()
    task = unreal.AssetImportTask()
    task.filename = fbx
    task.destination_path = TRANSIENT
    task.destination_name = name
    task.replace_existing = True
    task.automated = True
    task.save = False
    try:
        task.set_editor_property("async_", False)
    except Exception:
        pass
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
    sm.set_editor_property("vertex_color_import_option", unreal.VertexColorImportOption.REPLACE)
    for prop, val in (("build_nanite", False), ("remove_degenerates", False)):
        try:
            sm.set_editor_property(prop, val)
        except Exception:
            pass
    task.options = opts
    cvar = "Interchange.FeatureFlags.Import.FBX"            # the legacy importer honours FbxImportUI (as mars_food_ue)
    was = unreal.SystemLibrary.get_console_variable_bool_value(cvar)
    unreal.SystemLibrary.execute_console_command(None, "%s 0" % cvar)
    try:
        unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
    finally:
        unreal.SystemLibrary.execute_console_command(None, "%s %d" % (cvar, 1 if was else 0))
    mesh = _load("%s/%s.%s" % (TRANSIENT, name, name))
    if mesh is None:
        raise RuntimeError("import of %s failed" % fbx)
    return mesh


def _tuned_instance():
    """A transient child of MeatSlab_Mars_MI carrying TUNED_* (in memory, never saved)."""
    unreal = _u()
    mel = unreal.MaterialEditingLibrary
    path = "%s/%s.%s" % (TRANSIENT, TUNED_MI, TUNED_MI)
    inst = _load(path)
    if inst is None:
        inst = unreal.AssetToolsHelpers.get_asset_tools().create_asset(
            TUNED_MI, TRANSIENT, unreal.MaterialInstanceConstant, unreal.MaterialInstanceConstantFactoryNew())
    mel.set_material_instance_parent(inst, _load(SLAB_MI))
    for k, v in TUNED_SCALARS.items():
        mel.set_material_instance_scalar_parameter_value(inst, k, float(v))
    for k, v in TUNED_VECTORS.items():
        mel.set_material_instance_vector_parameter_value(inst, k, unreal.LinearColor(*v))
    mel.update_material_instance(inst)
    return inst


def _transient_mi(name, parent):
    unreal = _u()
    inst = _load("%s/%s.%s" % (TRANSIENT, name, name))
    if inst is None:
        inst = unreal.AssetToolsHelpers.get_asset_tools().create_asset(
            name, TRANSIENT, unreal.MaterialInstanceConstant, unreal.MaterialInstanceConstantFactoryNew())
    unreal.MaterialEditingLibrary.set_material_instance_parent(inst, parent)
    unreal.MaterialEditingLibrary.clear_all_material_instance_parameters(inst)
    return inst


def _meat_instances(meat_params=None):
    """(body, cap): MeatSlab_Wagyu_Mars_MI / MeatSlab_WagyuCap_Mars_MI as saved, else built transiently by mars_meat_ue
    (textures imported into TRANSIENT, nothing saved). With meat_params the body is a transient child of the saved body
    carrying those scalar overrides, and the cap a transient child of THAT body with the cap's Mask / Normal, so both
    follow the iteration."""
    unreal = _u()
    mel = unreal.MaterialEditingLibrary
    body = _load("%s/%s.%s" % (MEAT_FOLDER, MEAT_MI_NAME, MEAT_MI_NAME))
    cap = _load("%s/%s.%s" % (MEAT_FOLDER, MEAT_CAP_MI_NAME, MEAT_CAP_MI_NAME))
    if body is None or cap is None:
        if HERE not in sys.path:
            sys.path.insert(0, HERE)
        import mars_meat_ue as mm
        importlib.reload(mm)
        if any(_load("%s/%s.%s" % (mm.F_TEX, n, n)) is None for n, _, _ in mm.TEXTURES):
            mm.import_textures(folder=TRANSIENT, save=False)
        made = mm.build_meat_instances(folder=TRANSIENT, tex_folders=(mm.F_TEX, TRANSIENT), save=False)
        body, cap = made[MEAT_MI_NAME], made[MEAT_CAP_MI_NAME]
        _log("%s / %s not in the project: built transiently in %s" % (MEAT_MI_NAME, MEAT_CAP_MI_NAME, TRANSIENT))
    if not meat_params:
        return body, cap
    child = _transient_mi(MEAT_ITER_MI, body)
    known = set(str(n) for n in mel.get_scalar_parameter_names(child))
    for k, v in meat_params.items():
        if k not in known:
            raise RuntimeError("Meat_Mars_M has no scalar parameter %r" % k)
        mel.set_material_instance_scalar_parameter_value(child, k, float(v))
    mel.update_material_instance(child)
    cap_child = _transient_mi(MEAT_ITER_CAP_MI, child)
    for k in ("Mask", "Normal"):
        tex = mel.get_material_instance_texture_parameter_value(cap, k)
        if tex is None:
            raise RuntimeError("%s has no %s texture" % (cap.get_name(), k))
        mel.set_material_instance_texture_parameter_value(cap_child, k, tex)
    mel.update_material_instance(cap_child)
    _log("meat columns on transient children of %s: %s" % (body.get_name(), meat_params))
    return child, cap_child


def _floor_box():
    """(min xy, max xy, top z) of the lookdev floor actor."""
    unreal = _u()
    for a in unreal.get_editor_subsystem(unreal.EditorActorSubsystem).get_all_level_actors():
        if a.get_actor_label() == FLOOR_LABEL:
            origin, ext = a.get_actor_bounds(False)
            return ((origin.x - ext.x, origin.y - ext.y), (origin.x + ext.x, origin.y + ext.y), origin.z + ext.z)
    raise RuntimeError("no %r actor in %s: the lookdev floor moved, update STUDIO_SPOT / FLOOR_LABEL"
                       % (FLOOR_LABEL, LOOKDEV_MAP))


def _bounds(mesh):
    b = mesh.get_bounding_box()
    lo, hi = b.min, b.max
    return (lo.x, lo.y, lo.z), (hi.x, hi.y, hi.z)


def setup(out_dir=DEFAULT_OUT, columns=None, meat_params=None):
    """Loads the lookdev map (in memory, never saved), imports the FBX meshes transient, spawns every (column, state,
    view) piece parked with its CPD, writes <out_dir>/parity_layout.json (park and studio placement + camera per
    tile). columns: COLUMNS keys to render (all when empty); meat_params: scalar overrides for the Meat columns."""
    unreal = _u()
    les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
    if les.is_in_play_in_editor():
        raise RuntimeError("stop PIE first")
    les.load_level(LOOKDEV_MAP)
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    if world.get_outermost().get_name() != LOOKDEV_MAP:
        raise RuntimeError("could not open %s" % LOOKDEV_MAP)
    eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    lo_xy, hi_xy, floor_z = _floor_box()
    if not (lo_xy[0] + 60 < STUDIO_SPOT[0] < hi_xy[0] - 60 and lo_xy[1] + 60 < STUDIO_SPOT[1] < hi_xy[1] - 60):
        raise RuntimeError("STUDIO_SPOT %s is not inside the %s floor %s..%s" % (STUDIO_SPOT, FLOOR_LABEL, lo_xy, hi_xy))
    unknown = [c for c in (columns or ()) if c not in [k for k, _, _, _, _ in COLUMNS]]
    if unknown:
        raise RuntimeError("unknown columns %s" % unknown)
    cols = [c for c in COLUMNS if not columns or c[0] in columns]
    tiles = []
    meshes = {}
    imported = {}
    meat = None
    for key, label, src, mi, tname in cols:
        if tname and tname not in imported:
            imported[tname] = _import_fbx(src, tname)
        mesh = imported[tname] if tname else _load(src)
        if mesh is None:
            raise RuntimeError("%s missing" % src)
        if mi == "MEAT":
            meat = meat or _meat_instances(meat_params)
            mat = meat                                  # (body, cap): slot CAP_SLOT takes the cap
        else:
            mat = _tuned_instance() if mi == "TUNED" else _load(mi)
        if mat is None:
            raise RuntimeError("%s: material %s missing" % (key, mi))
        meshes[key] = (mesh, mat)
    for ci, (key, label, src, mi, tname) in enumerate(cols):
        mesh, mat = meshes[key]
        lo, hi = _bounds(mesh)
        centre = [(a + b) * 0.5 for a, b in zip(lo, hi)]
        ext = [b - a for a, b in zip(lo, hi)]
        radius = 0.5 * math.sqrt(sum(e * e for e in ext))
        for si, (skey, slabel, sxy, sz, fin) in enumerate(STATES):
            for vi, (vkey, (flip, elev, yaw, fov)) in enumerate(VIEWS.items()):
                px = PARK_ORIGIN[0] + (ci * len(VIEWS) + vi) * GRID_STEP
                py = PARK_ORIGIN[1] - si * GRID_STEP
                x, y = STUDIO_SPOT
                # rest the piece on the floor: upright its base (local z = lo.z) on it, flipped its top (hi.z)
                if flip:
                    offset = (-centre[0], centre[1], floor_z + hi[2])
                    rot = unreal.Rotator(roll=180.0, pitch=0.0, yaw=0.0)
                    world_centre = (x, y, floor_z + hi[2] - centre[2])
                else:
                    offset = (-centre[0], -centre[1], floor_z - lo[2])
                    rot = unreal.Rotator(roll=0.0, pitch=0.0, yaw=0.0)
                    world_centre = (x, y, floor_z + centre[2] - lo[2])
                studio = (x + offset[0], y + offset[1], offset[2])
                park = (px + offset[0], py + offset[1], offset[2])
                a = eas.spawn_actor_from_object(mesh, unreal.Vector(*park), rot)
                a.set_actor_label("Parity_%s_%s_%s" % (key, skey, vkey))
                a.set_folder_path("CookParity")
                comp = a.get_component_by_class(unreal.StaticMeshComponent)
                comp.set_mobility(unreal.ComponentMobility.MOVABLE)
                for i in range(max(1, len(comp.get_materials()))):
                    if isinstance(mat, tuple):
                        comp.set_material(i, mat[1] if i == CAP_SLOT else mat[0])
                    else:
                        comp.set_material(i, mat)
                comp.set_default_custom_primitive_data_vector4(0, unreal.Vector4(*sxy))
                comp.set_default_custom_primitive_data_vector4(4, unreal.Vector4(*sz))
                comp.set_default_custom_primitive_data_vector4(8, unreal.Vector4(*fin))
                dist = max(radius / math.tan(math.radians(fov * 0.5)) * 1.12, 18.0)   # near clip is 10 cm
                el, yw = math.radians(elev), math.radians(yaw)
                eye = (world_centre[0] + dist * math.cos(el) * math.cos(yw),
                       world_centre[1] + dist * math.cos(el) * math.sin(yw),
                       world_centre[2] + dist * math.sin(el))
                tiles.append({"actor": a.get_actor_label(), "column": key, "column_label": label, "state": skey, "state_label": slabel,
                              "view": vkey, "eye": eye, "target": world_centre, "fov": fov, "studio": studio, "park": park,
                              "size_cm": [round(e, 2) for e in ext], "file": "%s_%s_%s.png" % (key, skey, vkey)})
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, "parity_layout.json"), "w") as fh:
        json.dump({"columns": [c[:2] for c in cols], "meat_params": meat_params or {}, "states": [s[:2] for s in STATES], "views": list(VIEWS),
                   "tiles": tiles}, fh, indent=1)
    _log("spawned %d pieces" % len(tiles))
    return len(tiles)


def shoot(out_dir=DEFAULT_OUT, size=(800, 640)):
    """Captures every tile of parity_layout.json (call after setup, in a separate run_python call)."""
    unreal = _u()
    with open(os.path.join(out_dir, "parity_layout.json")) as fh:
        tiles = json.load(fh)["tiles"]
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    unreal.SystemLibrary.execute_console_command(world, "r.TextureStreaming 0")      # session cvar, never saved
    tile_dir = os.path.join(out_dir, "tiles")
    os.makedirs(tile_dir, exist_ok=True)
    rt = unreal.RenderingLibrary.create_render_target2d(world, size[0], size[1], unreal.TextureRenderTargetFormat.RTF_RGBA8)
    actor = unreal.get_editor_subsystem(unreal.EditorActorSubsystem).spawn_actor_from_class(unreal.SceneCapture2D,
                                                                                            unreal.Vector(0, 0, 0))
    pieces = {a.get_actor_label(): a for a in unreal.get_editor_subsystem(unreal.EditorActorSubsystem).get_all_level_actors()
              if a.get_actor_label().startswith("Parity_")}
    try:
        comp = actor.get_component_by_class(unreal.SceneCaptureComponent2D)
        comp.set_editor_property("texture_target", rt)
        comp.set_editor_property("capture_source", unreal.SceneCaptureSource.SCS_FINAL_COLOR_LDR)
        comp.set_editor_property("capture_every_frame", False)
        comp.set_editor_property("capture_on_movement", False)
        for t in tiles:
            # only this piece: the other parity pieces stay out of the frame's background
            # (HiddenActors is template-only to Python: hide through the component calls instead)
            comp.clear_hidden_components()
            for k, a in pieces.items():
                if k != t["actor"]:
                    comp.hide_actor_components(a, False)
            piece = pieces[t["actor"]]
            piece.set_actor_location(unreal.Vector(*t["studio"]), False, False)
            eye, target = t["eye"], t["target"]
            d = [b - a for a, b in zip(eye, target)]
            yaw = math.degrees(math.atan2(d[1], d[0]))
            pitch = math.degrees(math.atan2(d[2], math.hypot(d[0], d[1])))
            actor.set_actor_location_and_rotation(unreal.Vector(*eye), unreal.Rotator(roll=0.0, pitch=pitch, yaw=yaw),
                                                  False, False)
            comp.set_editor_property("fov_angle", float(t["fov"]))
            comp.capture_scene()
            unreal.RenderingLibrary.export_render_target(world, rt, tile_dir, t["file"])
            piece.set_actor_location(unreal.Vector(*t["park"]), False, False)
    finally:
        actor.destroy_actor()
    _log("captured %d tiles -> %s" % (len(tiles), tile_dir))
    return len(tiles)


def inspect():
    """Actors of the open map (class, label, location) for checking the rig; returns a list of strings."""
    unreal = _u()
    out = []
    for a in unreal.get_editor_subsystem(unreal.EditorActorSubsystem).get_all_level_actors():
        loc = a.get_actor_location()
        out.append("%s | %s | %.0f %.0f %.0f | scale %s" % (type(a).__name__, a.get_actor_label(), loc.x, loc.y, loc.z,
                                                            a.get_actor_scale3d()))
    return out


# ====================================================================================== host side (no unreal)
class Monolith:
    """Minimal Monolith MCP client (same protocol as mars_food_niagara.Monolith)."""

    def __init__(self, port):
        self.url = "http://localhost:%d/mcp" % port
        self.sid, self.rpc = None, 0
        self._post({"jsonrpc": "2.0", "id": self._id(), "method": "initialize", "params": {
            "protocolVersion": "2025-03-26", "capabilities": {}, "clientInfo": {"name": "mars_cook_parity", "version": "1"}}})
        try:
            self._post({"jsonrpc": "2.0", "method": "notifications/initialized"})
        except Exception:
            pass

    def _id(self):
        self.rpc += 1
        return self.rpc

    def _post(self, payload, timeout=1200):
        req = urllib.request.Request(self.url, data=json.dumps(payload).encode(), method="POST", headers={
            "Content-Type": "application/json", "Accept": "application/json, text/event-stream"})
        if self.sid:
            req.add_header("Mcp-Session-Id", self.sid)
        with urllib.request.urlopen(req, timeout=timeout) as r:
            self.sid = r.headers.get("Mcp-Session-Id") or self.sid
            body = r.read().decode("utf-8", "replace")
        if body.startswith("event:") or "\ndata:" in body or body.startswith("data:"):
            chunks = [l[5:].strip() for l in body.splitlines() if l.startswith("data:")]
            body = chunks[-1] if chunks else "{}"
        return json.loads(body) if body.strip() else {}

    def python(self, code, check=True):
        rep = self._post({"jsonrpc": "2.0", "id": self._id(), "method": "tools/call", "params": {
            "name": "editor_query", "arguments": {"action": "run_python",
                                                  "params": {"command": code, "unattended": True}}}})
        res = rep.get("result", {})
        text = "\n".join(c.get("text", "") for c in res.get("content", []) if c.get("type") == "text")
        if check and (rep.get("error") or res.get("isError")):
            raise RuntimeError("run_python failed: %s" % (rep.get("error") or text))
        return text


def _module_call(call):
    return ("import sys, importlib\nsys.path.insert(0, r'%s')\nimport mars_cook_parity as p\nimportlib.reload(p)\n"
            "print('RESULT', %s)" % (HERE, call))


def wait_for(port, seconds=900):
    t0 = time.time()
    while time.time() - t0 < seconds:
        try:
            m = Monolith(port)
            m.python("print(1)")
            return m
        except Exception:
            time.sleep(5)
    raise TimeoutError("no Monolith on port %d after %ds" % (port, seconds))


def launch(port, log):
    args = [EDITOR, UPROJECT, "/Engine/Maps/Entry", "-RenderOffscreen", "-unattended", "-nosplash", "-NoSound",
            "-ini:Monolith:[/Script/MonolithCore.MonolithSettings]:ServerPort=%d" % port, "-abslog=%s" % log]
    return subprocess.Popen(args, cwd=PROJECT)


def quit_editor(m, proc, seconds=180):
    try:
        m.python("import unreal\nunreal.SystemLibrary.quit_editor()", check=False)
    except Exception:
        pass                                    # the connection drops as the editor goes down
    if proc is None:
        return
    try:
        proc.wait(seconds)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(60)


def contact_sheets(out_dir):
    """One sheet per view: rows = states, columns = COLUMNS, labelled; plus parity_<view>.png paths returned."""
    from PIL import Image, ImageDraw, ImageFont
    with open(os.path.join(out_dir, "parity_layout.json")) as fh:
        lay = json.load(fh)
    try:
        font = ImageFont.truetype("arial.ttf", 22)
        small = ImageFont.truetype("arial.ttf", 17)
    except OSError:
        font = small = ImageFont.load_default()
    by = {(t["column"], t["state"], t["view"]): t for t in lay["tiles"]}
    paths = []
    for view in lay["views"]:
        first = Image.open(os.path.join(out_dir, "tiles", lay["tiles"][0]["file"]))
        w, h = first.size
        head, side = 64, 230
        sheet = Image.new("RGB", (side + w * len(lay["columns"]), head + h * len(lay["states"])), (24, 24, 26))
        d = ImageDraw.Draw(sheet)
        d.text((10, 8), "%s view" % view, fill=(235, 235, 235), font=font)
        for ci, (ck, clabel) in enumerate(lay["columns"]):
            sz = next(t["size_cm"] for t in lay["tiles"] if t["column"] == ck)
            d.text((side + ci * w + 10, 8), clabel, fill=(235, 235, 235), font=small)
            d.text((side + ci * w + 10, 32), "%.1f x %.1f x %.1f cm (framed to fit)" % tuple(sz), fill=(170, 170, 170),
                   font=small)
        for si, (sk, slabel) in enumerate(lay["states"]):
            d.text((10, head + si * h + h // 2 - 12), slabel, fill=(235, 235, 235), font=small)
            for ci, (ck, _) in enumerate(lay["columns"]):
                t = by.get((ck, sk, view))
                p = os.path.join(out_dir, "tiles", t["file"]) if t else None
                if p and os.path.exists(p):
                    sheet.paste(Image.open(p).convert("RGB"), (side + ci * w, head + si * h))
        path = os.path.join(out_dir, "CookParity_%s_sheet.png" % view)
        sheet.save(path)
        paths.append(path)
    return paths


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=9317)
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--launch", action="store_true")
    ap.add_argument("--keep", action="store_true", help="leave the editor running")
    ap.add_argument("--sheets_only", action="store_true")
    ap.add_argument("--columns", default="", help="comma list of COLUMNS keys (default: all)")
    ap.add_argument("--meat_params", default="", help='JSON scalar overrides for the Meat columns, e.g. {"Band Depth": 1.5}')
    ap.add_argument("--log", default=os.path.join(PROJECT, "Saved", "Logs", "HiddenParity_Mars.log"))
    a = ap.parse_args()
    columns = [c for c in a.columns.split(",") if c]
    meat_params = json.loads(a.meat_params) if a.meat_params else None
    if a.port == 9316 and a.launch:
        raise SystemExit("9316 is Stephen's interactive editor")
    if not a.sheets_only:
        proc = launch(a.port, a.log) if a.launch else None
        m = wait_for(a.port)
        try:
            print(m.python(_module_call("p.setup(r'%s', %r, %r)" % (a.out, columns, meat_params))))
            time.sleep(3)
            print(m.python(_module_call("p.shoot(r'%s')" % a.out)))
        finally:
            if not a.keep:
                quit_editor(m, proc)
    for p in contact_sheets(a.out):
        print("SHEET", p)


if __name__ == "__main__":
    main()
