"""Screaming Turnip R01 - candidate-only Unreal importer + validator (Phase C). Runs inside the editor's Python through Monolith
`editor_query run_python` ({"command": "<this file> <stage>", "mode": "execute_file", "unattended": true}), never in PIE.

Adapted from the Cellar Bat importer (Tools/Blender/mars_monsters/cellar_bat_r01/scripts/cellar_bat_import_ue.py).
Writes only under /Game/ArtCandidates/ScreamingTurnip/R01/{Materials,Meshes,Animation,Validation}/ and saves only the assets it
owns (EditorAssetLibrary.save_loaded_asset per asset; never Save All). The Interchange FBX flag is restored in a finally.
Every stage prints a JSON report and merges it into export/unreal_readback_final.json.

Never here (editor-killing operations, see PROGRESS.md Phase 1): raw Python SkeletalMesh.add_socket (the six skeleton sockets
are added by Monolith `animation_query add_socket` from outside; `socket_plan` prints the bone-relative transforms),
unload_packages / reload of live packages, level loads, Save All. Static-mesh sockets (Grip_L/Grip_R on the collision proxy)
use StaticMesh.add_socket on the real imported mesh (the potion importer's proven route).

Stages (argv[1]):
  materials    master + 4 slot instances + bed Soil instance, save, readback
  mesh         bind SK (legacy FBX, dedicated SKEL, no physics asset), bind slots, bounds extension, save
  socket_plan  read only: the sockets' bone-relative transforms from the imported bind pose vs the manifest
  statics      collision proxy (+ convex hull + Grip_L/Grip_R sockets), two beds (+ box), Cube10, save
  clips        the 15 clips against the SKEL, loop flags, no root motion, rate 1, save
  readback     everything, no writes (key "readback"; also copied to review/phaseC/readback_pre_restart.json)
  reimport     materials + mesh + statics + clips again (replace_existing), then readback, diffed against "readback"
  reload       cold-read proof: run in the NEXT editor session; readback diffed against review/phaseC/readback_pre_restart.json
  all          materials, mesh, statics, clips, readback
Phase C2 (B3 assets: morph targets Inhale/Scream, morph curves on every clip, 16 clips incl. ROOT_AnticipateTired):
  reimport_b3 [key]  materials + mesh (import_morph_targets) + statics + clips, full readback, diffed against "readback_b3"
                     when present; stored under [key] (default "reimport_b3")
  readback_b3        full readback stored as "readback_b3"; snapshot review/phaseC2/readback_pre_restart.json (reload uses it)
  playback_*         single-node playback proof in the owned review map (see the playback section)
Phase C3 (B4 assets, x3.0: every bone head, socket, bound and static scaled; numbers read from the refreshed manifest):
  reimport_b4 [key]  as reimport_b3 for the B4 exports, diffed against "readback_b4"; stored under [key] (default "reimport_b4")
  readback_b4        full readback stored as "readback_b4"; snapshot review/phaseC3/readback_pre_restart.json (reload uses it)
  playback_* now write under review/phaseC3/ and frame the probe by the manifest's scale_factor.
  Expected values come from the manifest (bounds margin = phase_c_readback.import.bounds_extension, cuts =
  phase_c_readback.cuts, bone heads / statics / hull sockets / envelope = phase_c_readback.assert_on_*), never from constants.
"""
import hashlib
import json
import math
import os
import re
import sys
import time

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(HERE)
EXPORT = os.path.join(ROOT_DIR, "export")
ANIMS = os.path.join(EXPORT, "anims")
READBACK = os.path.join(EXPORT, "unreal_readback_final.json")
MANIFEST = os.path.join(EXPORT, "ScreamingTurnip_R01_Manifest.json")
EXPECTED = os.path.join(EXPORT, "expected.json")
EXPECTED_ANIMS = os.path.join(ANIMS, "expected_anims.json")
PRE_RESTART = os.path.join(ROOT_DIR, "review", "phaseC3", "readback_pre_restart.json")   # C3: the B4 (x3.0) assets
REVIEW_DIR = os.path.join(ROOT_DIR, "review", "phaseC3")
REVIEW_MODULE_DIR = os.path.normpath(os.path.join(ROOT_DIR, "..", "..", "..", "LevelDesign", "screaming_turnip_r01_review"))
PLAYBACK_STATE = os.path.join(REVIEW_DIR, "playback_state.json")
PROJECT = "D:/Repositories/CkRepos/Orion/Mars.uproject"
FBX_FLAG = "Interchange.FeatureFlags.Import.FBX"

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary
AL = unreal.AnimationLibrary

F_ROOT = "/Game/ArtCandidates/ScreamingTurnip/R01"
F_MESH, F_MAT, F_ANIM, F_VAL = F_ROOT + "/Meshes", F_ROOT + "/Materials", F_ROOT + "/Animation", F_ROOT + "/Validation"
OWNED_FOLDERS = (F_MESH, F_MAT, F_ANIM, F_VAL)
SK, SKEL = "ScreamingTurnip_R01_Mars_SK", "ScreamingTurnip_R01_Mars_SKEL"
MASTER = "ScreamingTurnip_R01_Mars_M"
MI = "ScreamingTurnip_R01_%s_Mars_MI"
BED_MI = "TurnipBed_R01_Mars_MI"
ANIM = "ScreamingTurnip_R01_%s_Mars_ANIM"
SLOTS = ("Skin", "Leaf", "Mouth", "Teeth")
FBX_SK = "ScreamingTurnip_R01_Mars_SK.fbx"

# Statics: asset name -> (fbx relative to export/, expected.json key or "cube", collision kind, slot material, sockets)
PROXY, BED, BED_EMPTY, CUBE = ("ScreamingTurnip_R01_Collision_Mars_SM", "TurnipBed_R01_Mars_SM",
                               "TurnipBedEmpty_R01_Mars_SM", "Cube10_Mars_SM")
STATICS = {
    PROXY: {"fbx": "ScreamingTurnip_R01_Collision_Mars_SM.fbx", "key": "ScreamingTurnip_R01_Collision", "folder": F_MESH,
            "collision": "convex", "material": MI % "Skin", "sockets": ("Grip_L", "Grip_R")},
    BED: {"fbx": "TurnipBed_R01_Mars_SM.fbx", "key": "TurnipBed_R01", "folder": F_MESH, "collision": "box",
          "material": BED_MI, "sockets": ()},
    BED_EMPTY: {"fbx": "TurnipBedEmpty_R01_Mars_SM.fbx", "key": "TurnipBedEmpty_R01", "folder": F_MESH, "collision": "box",
                "material": BED_MI, "sockets": ()},
    CUBE: {"fbx": os.path.join("validation", "Cube10_Mars_SM.fbx"), "key": "cube", "folder": F_VAL, "collision": "none",
           "material": None, "sockets": ()},
}

# Material values (brief item 1). Leaf is two-sided through the MI base-property override.
MI_VALUES = {
    "Skin": {"Roughness": 0.85, "Specular": 0.25, "two_sided": False},
    "Leaf": {"Roughness": 0.7, "Specular": 0.3, "two_sided": True},
    "Mouth": {"Roughness": 0.9, "Specular": 0.1, "two_sided": False},
    "Teeth": {"Roughness": 0.5, "Specular": 0.4, "two_sided": False},
}
BED_VALUES = {"Roughness": 0.95, "Specular": 0.1, "two_sided": False}
MASTER_DEFAULTS = {"Roughness": 0.85, "Specular": 0.25, "CavityFloor": 0.45, "VertexColorGamma": 2.2}

# C3: the bounds margin is read from the manifest (phase_c_readback.import.bounds_extension), see _manifest_margin()
SOCKET_TOL_CM = 0.1
LANDMARK_TOL_CM = 0.02
SCALE_TOL = 1e-3
CHAIN_TOL = 1e-3
LOOPS_BRIEF = ("ROOT_QuietIdle", "ROOT_RecoveryIdle", "SRC_Idle", "ROOT_AirborneLeafTrail")
# Documented hard cuts (PROGRESS Phase B, Blender): from frame 0 of the source and from its worst frame over the loop.
# C3: the Blender numbers come from the manifest's phase_c_readback.cuts ("<A> f0 -> <B> f0" / "<A> fany -> <B> f0").
HARD_CUT_PAIRS = (("ROOT_RecoveryIdle", "ROOT_Anticipate"), ("ROOT_QuietIdle", "ROOT_Anticipate"),
                  ("ROOT_RecoveryIdle", "ROOT_AnticipateTired"))
CUT_MATCH_TOL = (0.01, 0.1)  # cm / deg: Unreal cut vs the manifest's Blender cut
CUT_GATES = {"ROOT_RecoveryIdle -> ROOT_AnticipateTired f0": (0.1, 1.0)}     # f0 head cm / rot deg, bone level
MORPHS = ("Inhale", "Scream")
CURVE_TOL = 1e-3
N_CLIPS = 16
# Ends the manifest's chain block does not list but its notes state ("ends == ROOT_QuietIdle f0", "== SRC_Idle f0").
EXTRA_CHAIN = (("SRC_Release", "ROOT_QuietIdle", 0), ("SRC_Cancel", "SRC_Idle", 0))


# --------------------------------------------------------------------------------------------------------------- utils
def _err(e):
    return "%s: %s" % (type(e).__name__, e)


def _path(folder, name):
    return "%s/%s.%s" % (folder, name, name)


def _load(p):
    try:
        return unreal.load_asset(p) if EAL.does_asset_exist(p) else None
    except Exception:
        return None


def _set(obj, name, value):
    try:
        obj.set_editor_property(name, value)
        return True
    except Exception:
        return False


def _get(obj, name, default=None):
    try:
        return obj.get_editor_property(name)
    except Exception:
        return default


def _v(vec, n=4):
    return [round(vec.x, n), round(vec.y, n), round(vec.z, n)]


def _q(q, n=6):
    return [round(q.x, n), round(q.y, n), round(q.z, n), round(q.w, n)]


def _dist(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def _qdelta(q0, q1):
    """Rotation angle in degrees between two quaternions (sign-safe)."""
    d = abs(q0.x * q1.x + q0.y * q1.y + q0.z * q1.z + q0.w * q1.w)
    return math.degrees(2.0 * math.acos(min(1.0, d)))


def _pie():
    try:
        return unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_game_world() is not None
    except Exception:
        return False


def _dirty():
    out = []
    try:
        for p in list(unreal.EditorLoadingAndSavingUtils.get_dirty_content_packages()) + \
                list(unreal.EditorLoadingAndSavingUtils.get_dirty_map_packages()):
            out.append(p.get_name())
    except Exception as e:
        out.append("unavailable: %s" % _err(e))
    return sorted(set(out))


def _preflight():
    proj = unreal.Paths.convert_relative_path_to_full(unreal.Paths.get_project_file_path())
    pie = _pie()
    dirty = _dirty()
    foreign = [p for p in dirty if not p.startswith(F_ROOT + "/")]
    return {"project": proj, "pie": pie, "engine": unreal.SystemLibrary.get_engine_version(), "dirty": dirty,
            "foreign_dirty": foreign, "ok": proj == PROJECT and not pie}


def _ar_assets(root):
    flt = unreal.ARFilter(package_paths=[root], recursive_paths=True)
    return unreal.AssetRegistryHelpers.get_asset_registry().get_assets(flt)


def owned_assets():
    return sorted(set(str(a.package_name) for f in OWNED_FOLDERS for a in _ar_assets(f)))


def root_assets():
    return sorted(set(str(a.package_name) for a in _ar_assets(F_ROOT)))


def _collisions(names):
    want, hits = set(names), {}
    for a in _ar_assets("/Game"):
        n = str(a.asset_name)
        if n in want and not str(a.package_name).startswith(F_ROOT + "/"):
            hits.setdefault(n, []).append(str(a.package_name))
    return hits


def _expected():
    m = json.load(open(MANIFEST, "r", encoding="utf-8"))
    e = json.load(open(EXPECTED, "r", encoding="utf-8"))
    a = json.load(open(EXPECTED_ANIMS, "r", encoding="utf-8"))
    return {"manifest": m, "expected": e, "anims": a, "source": "export/ScreamingTurnip_R01_Manifest.json + "
            "export/expected.json + export/anims/expected_anims.json",
            "bones": [(b["name"], b["parent"]) for b in m["bones"]],
            "bone_heads": {b["name"]: b["head_ue_cm"] for b in e["bones"]},
            "slots": list(m["material_slots"]), "clips": m["clips"], "sockets": m["sockets"],
            "margin_cm": _manifest_margin(m), "hard_cuts": _manifest_cuts(m), "pcr": m["phase_c_readback"]}


def _manifest_margin(m):
    """'envelope (...) + 6 cm margin (...)' -> 6.0; cross-checked against 2 cm x scale_factor (the C2 rule)."""
    txt = m["phase_c_readback"]["import"]["bounds_extension"]
    hit = re.search(r"\+\s*([0-9.]+)\s*cm margin", txt)
    k = float(m.get("scale_factor", 1.0))
    val = float(hit.group(1)) if hit else 2.0 * k
    if abs(val - 2.0 * k) > 1e-6:
        raise RuntimeError("manifest margin %s != 2 cm x scale_factor %s" % (val, k))
    return val


def _manifest_cuts(m):
    cuts = m["phase_c_readback"]["cuts"]
    return [(c0, c1, {"f0": cuts.get("%s f0 -> %s f0" % (c0, c1)), "worst": cuts.get("%s fany -> %s f0" % (c0, c1))})
            for c0, c1 in HARD_CUT_PAIRS]


def _merge_readback(key, value):
    data = {}
    if os.path.isfile(READBACK):
        try:
            data = json.load(open(READBACK, "r", encoding="utf-8"))
        except Exception:
            data = {}
    data[key] = value
    data["updated_utc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    with open(READBACK, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=1)


def _saved_readback(key):
    if not os.path.isfile(READBACK):
        return None
    try:
        return json.load(open(READBACK, "r", encoding="utf-8")).get(key)
    except Exception:
        return None


def save_owned(assets):
    saved = []
    for a in assets:
        if a is None:
            continue
        pn = a.get_path_name()
        if any(pn.startswith(f + "/") for f in OWNED_FOLDERS) and EAL.save_loaded_asset(a, False):
            saved.append(pn)
    return saved


# ------------------------------------------------------------------------------------------------------------ importer
def _task(fbx, folder, name, options):
    t = unreal.AssetImportTask()
    t.filename = fbx
    t.destination_path = folder
    t.destination_name = name
    t.replace_existing = True
    t.automated = True
    t.save = False
    _set(t, "async_", False)
    t.options = options
    return t


class _LegacyFbx(object):
    """Interchange FBX off for the block, restored to its previous value in the exit (a finally)."""

    def __enter__(self):
        self.was = unreal.SystemLibrary.get_console_variable_bool_value(FBX_FLAG)
        unreal.SystemLibrary.execute_console_command(None, "%s 0" % FBX_FLAG)
        return self

    def __exit__(self, *exc):
        unreal.SystemLibrary.execute_console_command(None, "%s %d" % (FBX_FLAG, 1 if self.was else 0))
        self.after = unreal.SystemLibrary.get_console_variable_bool_value(FBX_FLAG)
        return False


def _base_opts():
    o = unreal.FbxImportUI()
    o.automated_import_should_detect_type = False
    o.import_materials = False
    o.import_textures = False
    return o


def _sk_opts(skeleton):
    o = _base_opts()
    o.import_mesh, o.import_as_skeletal, o.import_animations = True, True, False
    o.mesh_type_to_import = unreal.FBXImportType.FBXIT_SKELETAL_MESH
    o.skeleton = skeleton
    o.create_physics_asset = False
    _set(o, "physics_asset", None)
    d = o.skeletal_mesh_import_data
    for prop, value in (("normal_import_method", unreal.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS),
                        ("vertex_color_import_option", unreal.VertexColorImportOption.REPLACE),
                        ("import_morph_targets", True), ("use_t0_as_ref_pose", False),
                        ("import_meshes_in_bone_hierarchy", False), ("update_skeleton_reference_pose", True),
                        ("preserve_smoothing_groups", True), ("import_uniform_scale", 1.0),
                        ("import_translation", unreal.Vector(0.0, 0.0, 0.0)),
                        ("import_rotation", unreal.Rotator(roll=0.0, pitch=0.0, yaw=0.0)),
                        ("convert_scene", True), ("force_front_x_axis", False), ("convert_scene_unit", False)):
        _set(d, prop, value)
    return o


def _anim_opts(skeleton):
    o = _base_opts()
    o.import_mesh, o.import_as_skeletal, o.import_animations = False, False, True
    o.mesh_type_to_import = unreal.FBXImportType.FBXIT_ANIMATION
    o.skeleton = skeleton
    d = o.anim_sequence_import_data
    for prop, value in (("import_bone_tracks", True), ("remove_redundant_keys", False),
                        ("animation_length", unreal.FBXAnimationLengthImportType.FBXALIT_EXPORTED_TIME),
                        ("use_default_sample_rate", False), ("custom_sample_rate", 30),
                        ("snap_to_closest_frame_boundary", True), ("import_meshes_in_bone_hierarchy", False),
                        ("import_custom_attribute", False), ("delete_existing_morph_target_curves", True),
                        ("do_not_import_curve_with_zero", False), ("preserve_local_transform", False),
                        ("convert_scene", True), ("force_front_x_axis", False), ("convert_scene_unit", False),
                        ("import_uniform_scale", 1.0)):
        _set(d, prop, value)
    return o


# C2: `replace_existing` on an existing asset goes through FReimportManager, which uses the asset's STORED import data and
# ignores the task options (EditorFactories.cpp "Performing atomic reimport"). These options are therefore written onto the
# stored data before every reimport. update_skeleton_reference_pose: B2b moved cheek_l/r (1.7,-+3.25 -> 1.5,-+3.3); the
# dedicated SKEL must follow the new bind.
SK_STORED = (("import_morph_targets", True), ("update_skeleton_reference_pose", True),
             ("normal_import_method", None), ("vertex_color_import_option", None))
ANIM_STORED = (("do_not_import_curve_with_zero", False), ("delete_existing_morph_target_curves", True),
               ("import_bone_tracks", True))


def _sync_stored(asset, wanted, fresh_data):
    """Write `wanted` (prop, value; None = copy from fresh_data) onto the asset's stored FBX import data."""
    out = {}
    d = asset.get_editor_property("asset_import_data") if asset is not None else None
    if d is None:
        return {"stored": None}
    for prop, value in wanted:
        v = _get(fresh_data, prop) if value is None else value
        out[prop] = [str(_get(d, prop)), str(v), _set(d, prop, v)]
    return out


def _sm_opts():
    o = _base_opts()
    o.import_mesh, o.import_as_skeletal, o.import_animations = True, False, False
    o.mesh_type_to_import = unreal.FBXImportType.FBXIT_STATIC_MESH
    d = o.static_mesh_import_data
    for prop, value in (("combine_meshes", True), ("generate_lightmap_u_vs", False), ("auto_generate_collision", False),
                        ("normal_import_method", unreal.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS),
                        ("vertex_color_import_option", unreal.VertexColorImportOption.REPLACE),
                        ("remove_degenerates", False), ("build_nanite", False), ("import_uniform_scale", 1.0),
                        ("import_translation", unreal.Vector(0.0, 0.0, 0.0)),
                        ("import_rotation", unreal.Rotator(roll=0.0, pitch=0.0, yaw=0.0)),
                        ("convert_scene", True), ("force_front_x_axis", False), ("convert_scene_unit", False)):
        _set(d, prop, value)
    return o


# ------------------------------------------------------------------------------------------------------------ materials
def _new_or_load(name, folder, cls, factory):
    p = _path(folder, name)
    if EAL.does_asset_exist(p):
        a = _load(p)
        if not isinstance(a, cls):
            raise RuntimeError("%s exists but is a %s" % (p, a.get_class().get_name() if a else None))
        return a, False
    return unreal.AssetToolsHelpers.get_asset_tools().create_asset(name, folder, cls, factory), True


def _build_master(m):
    """BaseColor = VertexColor.RGB ^ VertexColorGamma x lerp(CavityFloor, 1, VertexColor.A); Roughness, Specular scalars;
    Metallic 0. Used with skeletal meshes (and instanced statics; plain static meshes need no flag)."""
    for _ in range(8):
        if MEL.get_num_material_expressions(m) == 0:
            break
        MEL.delete_all_material_expressions(m)
    _set(m, "used_with_skeletal_mesh", True)
    _set(m, "used_with_instanced_static_meshes", True)
    _set(m, "used_with_morph_targets", True)     # C2: the SK carries Inhale/Scream (the engine set it lazily otherwise)
    E = MEL.create_material_expression

    def scalar(name, x, y):
        p = E(m, unreal.MaterialExpressionScalarParameter, x, y)
        p.set_editor_property("parameter_name", name)
        p.set_editor_property("default_value", MASTER_DEFAULTS[name])
        return p

    vc = E(m, unreal.MaterialExpressionVertexColor, -1100, -100)
    gamma = scalar("VertexColorGamma", -1100, 100)
    pw = E(m, unreal.MaterialExpressionPower, -850, -100)
    MEL.connect_material_expressions(vc, "", pw, "Base")
    MEL.connect_material_expressions(gamma, "", pw, "Exp")
    cav = scalar("CavityFloor", -1100, 250)
    one = E(m, unreal.MaterialExpressionConstant, -1100, 350)
    one.set_editor_property("r", 1.0)
    lerp = E(m, unreal.MaterialExpressionLinearInterpolate, -850, 200)
    MEL.connect_material_expressions(cav, "", lerp, "A")
    MEL.connect_material_expressions(one, "", lerp, "B")
    MEL.connect_material_expressions(vc, "A", lerp, "Alpha")
    base = E(m, unreal.MaterialExpressionMultiply, -600, 0)
    MEL.connect_material_expressions(pw, "", base, "A")
    MEL.connect_material_expressions(lerp, "", base, "B")
    MEL.connect_material_property(base, "", unreal.MaterialProperty.MP_BASE_COLOR)
    MEL.connect_material_property(scalar("Roughness", -600, 250), "", unreal.MaterialProperty.MP_ROUGHNESS)
    MEL.connect_material_property(scalar("Specular", -600, 350), "", unreal.MaterialProperty.MP_SPECULAR)
    metal = E(m, unreal.MaterialExpressionConstant, -600, 450)
    metal.set_editor_property("r", 0.0)
    MEL.connect_material_property(metal, "", unreal.MaterialProperty.MP_METALLIC)
    MEL.recompile_material(m)


def _set_two_sided(mi, on):
    try:
        o = mi.get_editor_property("base_property_overrides")
        o.set_editor_property("override_two_sided", bool(on))
        o.set_editor_property("two_sided", bool(on))
        mi.set_editor_property("base_property_overrides", o)
        back = mi.get_editor_property("base_property_overrides")
        return bool(back.get_editor_property("override_two_sided")) == bool(on) and \
            bool(back.get_editor_property("two_sided")) == bool(on)
    except Exception:
        return False


def _all_mi():
    """name -> values for every instance this importer owns."""
    out = {MI % s: v for s, v in MI_VALUES.items()}
    out[BED_MI] = BED_VALUES
    return out


def create_materials():
    out = {"master": None, "instances": {}}
    master, new = _new_or_load(MASTER, F_MAT, unreal.Material, unreal.MaterialFactoryNew())
    _build_master(master)
    out["master"] = {"path": master.get_path_name(), "new": new}
    for name, cfg in _all_mi().items():
        mi, new = _new_or_load(name, F_MAT, unreal.MaterialInstanceConstant, unreal.MaterialInstanceConstantFactoryNew())
        MEL.set_material_instance_parent(mi, master)
        for k in ("Roughness", "Specular"):
            MEL.set_material_instance_scalar_parameter_value(mi, k, float(cfg[k]))
        ok = _set_two_sided(mi, cfg["two_sided"])
        MEL.update_material_instance(mi)
        out["instances"][name] = {"path": mi.get_path_name(), "new": new, "two_sided_override_ok": ok}
    out["saved"] = save_owned([master] + [_load(_path(F_MAT, n)) for n in _all_mi()])
    return out


def material_readback():
    out, chk = {}, {}
    master = _load(_path(F_MAT, MASTER))
    out["master"] = None if master is None else {
        "path": master.get_path_name(), "used_with_skeletal_mesh": _get(master, "used_with_skeletal_mesh"),
        "used_with_instanced_static_meshes": _get(master, "used_with_instanced_static_meshes"),
        "used_with_morph_targets": _get(master, "used_with_morph_targets"),
        "two_sided": _get(master, "two_sided"), "expressions": MEL.get_num_material_expressions(master),
        "scalar_params": sorted(str(n) for n in MEL.get_scalar_parameter_names(master))}
    chk["master"] = [master is not None and bool(out["master"]["used_with_skeletal_mesh"]) and
                     bool(out["master"]["used_with_morph_targets"]) and
                     out["master"]["scalar_params"] == sorted(MASTER_DEFAULTS), out["master"]]
    out["instances"] = {}
    for name, cfg in _all_mi().items():
        mi = _load(_path(F_MAT, name))
        if mi is None:
            out["instances"][name] = None
            chk[name] = [False, "missing"]
            continue
        r = {"parent": mi.get_editor_property("parent").get_name() if mi.get_editor_property("parent") else None}
        for k in ("Roughness", "Specular", "CavityFloor", "VertexColorGamma"):
            r[k] = round(MEL.get_material_instance_scalar_parameter_value(mi, k), 5)
        try:
            o = mi.get_editor_property("base_property_overrides")
            r["two_sided_override"] = [bool(o.get_editor_property("override_two_sided")),
                                       bool(o.get_editor_property("two_sided"))]
        except Exception as e:
            r["two_sided_override"] = "n/a (%s)" % _err(e)
        out["instances"][name] = r
        chk[name] = [r["parent"] == MASTER and abs(r["Roughness"] - cfg["Roughness"]) < 1e-4 and
                     abs(r["Specular"] - cfg["Specular"]) < 1e-4 and abs(r["CavityFloor"] - 0.45) < 1e-4 and
                     abs(r["VertexColorGamma"] - 2.2) < 1e-4 and
                     r["two_sided_override"] == [bool(cfg["two_sided"]), bool(cfg["two_sided"])],
                     {"want": cfg, "got": r}]
    out["checks"] = chk
    out["pass"] = all(v[0] for v in chk.values())
    return out


# ------------------------------------------------------------------------------------------------------------- mesh
def import_mesh():
    out = {}
    skel = _load(_path(F_MESH, SKEL))
    out["existing_mesh"] = _load(_path(F_MESH, SK)) is not None
    out["existing_skeleton"] = skel is not None
    opts = _sk_opts(skel)
    out["stored_import_data_sync"] = _sync_stored(_load(_path(F_MESH, SK)), SK_STORED, opts.skeletal_mesh_import_data)
    with _LegacyFbx() as flag:
        unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks(
            [_task(os.path.join(EXPORT, FBX_SK), F_MESH, SK, opts)])
    out["interchange_flag_before_after"] = [flag.was, flag.after]
    mesh = _load(_path(F_MESH, SK))
    if mesh is None:
        raise RuntimeError("bind mesh import produced nothing")
    sk_path = mesh.skeleton.get_path_name().split(".")[0]
    if not sk_path.endswith("/" + SKEL):
        if EAL.does_asset_exist(_path(F_MESH, SKEL)):
            raise RuntimeError("mesh got skeleton %s while %s exists" % (sk_path, SKEL))
        out["renamed_skeleton_from"] = sk_path
        EAL.rename_asset(sk_path, "%s/%s" % (F_MESH, SKEL))
    out["skeleton"] = mesh.skeleton.get_path_name()
    phys = mesh.get_editor_property("physics_asset")
    out["physics_asset"] = phys.get_path_name() if phys else None
    return mesh, out


def bind_materials(mesh):
    mats = list(mesh.materials)
    bound = {}
    for i, sm in enumerate(mats):
        slot = str(sm.material_slot_name)
        mi = _load(_path(F_MAT, MI % slot))
        if mi is not None:
            sm.set_editor_property("material_interface", mi)
            mats[i] = sm
        bound[slot] = mi.get_name() if mi else None
    mesh.set_editor_property("materials", mats)
    return bound


def set_bounds(mesh, exp):
    env = exp["manifest"]["dimensions_cm"]["global_clip_envelope"]
    ib = mesh.get_imported_bounds()
    lo, hi = ib.origin - ib.box_extent, ib.origin + ib.box_extent
    mg = exp["margin_cm"]
    pos = [math.ceil(max(0.0, env["max"][i] - (hi.x, hi.y, hi.z)[i]) + mg) for i in range(3)]
    neg = [math.ceil(max(0.0, (lo.x, lo.y, lo.z)[i] - env["min"][i]) + mg) for i in range(3)]
    mesh.set_editor_property("positive_bounds_extension", unreal.Vector(*pos))
    mesh.set_editor_property("negative_bounds_extension", unreal.Vector(*neg))
    return {"positive": pos, "negative": neg, "envelope": env, "margin_cm": mg}


def run_mesh():
    exp = _expected()
    mesh, out = import_mesh()
    out["bound"] = bind_materials(mesh)
    out["bounds_extension"] = set_bounds(mesh, exp)
    out["saved"] = save_owned([mesh, mesh.skeleton])
    return out


def _ref_pose(skel):
    pose = unreal.AnimPoseExtensions.get_reference_pose(skel)
    names = [str(n) for n in unreal.AnimPoseExtensions.get_bone_names(pose)]
    return pose, names


def _bone_world(skel):
    pose, names = _ref_pose(skel)
    return {n: unreal.AnimPoseExtensions.get_bone_pose(pose, n, unreal.AnimPoseSpaces.WORLD) for n in names}


def socket_plan(exp):
    """Bone-local socket offsets from the imported bind pose (READ ONLY; the sockets are written by Monolith add_socket)."""
    mesh = _load(_path(F_MESH, SK))
    world = _bone_world(mesh.skeleton)
    out = {}
    for name, s in sorted(exp["sockets"].items()):
        rel = world[s["bone"]].inverse_transform_location(unreal.Vector(*[float(x) for x in s["root_relative_ue_cm"]]))
        got = [round(rel.x, 4), round(rel.y, 4), round(rel.z, 4)]
        out[name] = {"bone": s["bone"], "location": got, "manifest_bone_relative": s["bone_relative_ue_cm"],
                     "delta_vs_manifest": round(_dist(got, s["bone_relative_ue_cm"]), 5),
                     "rotation": s["rotation_ue_deg_pyr"], "exists": mesh.find_socket(name) is not None}
    return out


def mesh_readback(exp):
    rb = {"checks": {}}
    chk = rb["checks"]
    mesh = _load(_path(F_MESH, SK))
    if mesh is None:
        chk["mesh_exists"] = [False, None]
        rb["pass"] = False
        return rb
    skel = mesh.skeleton
    rb["mesh"] = mesh.get_path_name()
    rb["skeleton"] = skel.get_path_name() if skel else None
    chk["dedicated_skeleton"] = [rb["skeleton"] == _path(F_MESH, SKEL), rb["skeleton"]]
    ib = mesh.get_imported_bounds()
    lo, hi = ib.origin - ib.box_extent, ib.origin + ib.box_extent
    want = exp["manifest"]["mesh"]["bounds_ue_cm"]
    err = max(max(abs(a - b) for a, b in zip(_v(lo), want["min"])), max(abs(a - b) for a, b in zip(_v(hi), want["max"])))
    rb["imported_bounds"] = {"min": _v(lo), "max": _v(hi)}
    chk["bind_bounds_vs_manifest"] = [err <= 0.1, {"err_cm": round(err, 5), "got": rb["imported_bounds"], "want": want}]
    chk["mouth_at_plus_x"] = [hi.x > 5.0 and abs(hi.x - want["max"][0]) <= 0.1, round(hi.x, 4)]
    b = mesh.get_bounds()
    elo, ehi = b.origin - b.box_extent, b.origin + b.box_extent
    env = exp["manifest"]["dimensions_cm"]["global_clip_envelope"]
    margin = min(min(u - e for e, u in zip((elo.x, elo.y, elo.z), env["min"])),
                 min(e - u for e, u in zip((ehi.x, ehi.y, ehi.z), env["max"])))
    rb["bounds_with_extension"] = {"min": _v(elo), "max": _v(ehi),
                                   "positive_extension": _v(mesh.get_editor_property("positive_bounds_extension")),
                                   "negative_extension": _v(mesh.get_editor_property("negative_bounds_extension"))}
    chk["bounds_contain_clip_envelope_margin"] = [margin >= exp["margin_cm"] - 1e-3,
                                                  {"min_margin_cm": round(margin, 4), "want_cm": exp["margin_cm"]}]
    pcr_sk = exp["pcr"]["assert_on_skeletal_mesh"]
    env_err = max(max(abs(a - b) for a, b in zip(env["min"], pcr_sk["envelope_cm"]["min"])),
                  max(abs(a - b) for a, b in zip(env["max"], pcr_sk["envelope_cm"]["max"])))
    chk["envelope_matches_phase_c_readback"] = [env_err <= 1e-3, round(env_err, 6)]
    berr = max(max(abs(a - b) for a, b in zip(_v(lo), pcr_sk["bind_bounds_ue_cm"]["min"])),
               max(abs(a - b) for a, b in zip(_v(hi), pcr_sk["bind_bounds_ue_cm"]["max"])))
    chk["bind_bounds_vs_phase_c_readback"] = [berr <= 0.1, round(berr, 5)]

    pose, names = _ref_pose(skel)
    parents = {}
    try:
        sm = unreal.SkeletonModifier()
        sm.set_skeletal_mesh(mesh)
        for n in names:
            p = str(sm.get_parent_name(n))
            parents[n] = None if p in ("None", "") else p
    except Exception as e:
        rb["parents_error"] = _err(e)
    rb["bone_order"] = names
    want_b = exp["bones"]
    chk["bone_count_17"] = [len(names) == 17, len(names)]
    chk["bone_names_exact"] = [sorted(names) == sorted(n for n, _ in want_b), sorted(set(names) ^ set(n for n, _ in want_b))]
    wrong = [n for n, p in want_b if parents.get(n, "<missing>") != p] if parents else ["<no parent api>"]
    chk["parents_exact"] = [not wrong, wrong]
    root = unreal.AnimPoseExtensions.get_bone_pose(pose, "root", unreal.AnimPoseSpaces.LOCAL)
    root_ok = abs(abs(root.rotation.w) - 1) < 1e-5 and root.translation.length() < 1e-4 and \
        max(abs(root.scale3d.x - 1), abs(root.scale3d.y - 1), abs(root.scale3d.z - 1)) < 1e-5
    chk["root_identity"] = [root_ok, {"t": _v(root.translation, 6), "q": _q(root.rotation), "s": _v(root.scale3d, 6)}]
    worst_s, worst_h, heads = 0.0, 0.0, {}
    for n in names:
        lt = unreal.AnimPoseExtensions.get_bone_pose(pose, n, unreal.AnimPoseSpaces.LOCAL)
        wt = unreal.AnimPoseExtensions.get_bone_pose(pose, n, unreal.AnimPoseSpaces.WORLD)
        s = lt.scale3d
        worst_s = max(worst_s, abs(s.x - 1), abs(s.y - 1), abs(s.z - 1))
        e = exp["bone_heads"].get(n)
        heads[n] = _v(wt.translation)
        if e:
            worst_h = max(worst_h, _dist(heads[n], e))
    rb["bone_heads"] = heads
    chk["bone_scales_1"] = [worst_s < 1e-5, round(worst_s, 7)]
    chk["bone_heads_vs_blender"] = [worst_h <= 0.01, round(worst_h, 5)]
    wm = max(_dist(heads[n], v) for n, v in pcr_sk["bone_heads_ue_cm"].items() if n in heads)
    chk["bone_heads_vs_phase_c_readback"] = [wm <= 0.01 and set(pcr_sk["bone_heads_ue_cm"]) <= set(heads), round(wm, 5)]
    chk["handedness_cheek_l_minus_y"] = [heads["cheek_l"][1] < 0 < heads["cheek_r"][1],
                                         [heads["cheek_l"][1], heads["cheek_r"][1]]]

    slots = [str(m.material_slot_name) for m in mesh.materials]
    mats = [m.material_interface.get_name() if m.material_interface else None for m in mesh.materials]
    rb["slots"] = list(zip(slots, mats))
    chk["slots_in_order"] = [slots == exp["slots"] and slots == list(pcr_sk["material_slots"]), slots]
    chk["slots_bound_to_instances"] = [mats == [MI % s for s in slots], mats]
    sub = unreal.get_editor_subsystem(unreal.SkeletalMeshEditorSubsystem)
    n_lod = sub.get_lod_count(mesh)
    rb["lods"] = {i: {"render_verts": sub.get_num_verts(mesh, i), "sections": sub.get_num_sections(mesh, i)}
                  for i in range(n_lod)}
    chk["lod_count_1"] = [n_lod == 1, n_lod]
    morphs = [str(x) for x in mesh.get_all_morph_target_names()]
    rb["morph_targets"] = morphs
    want_m = list(exp["manifest"]["phase_c_readback"]["assert_on_skeletal_mesh"]["morph_target_names"])
    chk["morph_targets_inhale_scream"] = [sorted(morphs) == sorted(want_m) and len(morphs) == len(want_m),
                                          {"got": morphs, "want": want_m}]
    meta = {}
    for n in want_m:
        try:
            meta[n] = bool(AL.get_curve_meta_data_morph_target(skel, n))
        except Exception as e:
            meta[n] = "n/a (%s)" % _err(e)
    rb["skeleton_curve_morph_flag"] = meta
    chk["skeleton_curves_flagged_morph"] = [all(v is True for v in meta.values()), meta]
    phys = mesh.get_editor_property("physics_asset")
    rb["physics_asset"] = phys.get_path_name() if phys else None
    chk["no_physics_asset"] = [phys is None, rb["physics_asset"]]

    w = _bone_world(skel)
    rb["sockets"] = {}
    ok_s = True
    for name, s in sorted(exp["sockets"].items()):
        sock = mesh.find_socket(name)
        if sock is None:
            rb["sockets"][name] = None
            ok_s = False
            continue
        bone = str(sock.get_editor_property("bone_name"))
        rel = sock.get_editor_property("relative_location")
        rot = sock.get_editor_property("relative_rotation")
        comp = w[bone].transform_location(rel) if bone in w else None
        e = None if comp is None else _dist(_v(comp), s["root_relative_ue_cm"])
        rb["sockets"][name] = {"bone": bone, "relative_cm": _v(rel),
                               "relative_rot_pyr": [round(rot.pitch, 4), round(rot.yaw, 4), round(rot.roll, 4)],
                               "component_cm": _v(comp) if comp else None, "target_cm": s["root_relative_ue_cm"],
                               "err_cm": None if e is None else round(e, 5)}
        ps = pcr_sk["sockets"].get(name) or {}
        e_rel = _dist(_v(rel), ps["relative_ue_cm"]) if ps else None
        rb["sockets"][name]["pcr_relative_cm"] = ps.get("relative_ue_cm")
        rb["sockets"][name]["pcr_relative_err_cm"] = None if e_rel is None else round(e_rel, 5)
        ok_s = ok_s and bone == s["bone"] and e is not None and e <= SOCKET_TOL_CM and \
            bone == ps.get("bone") and e_rel is not None and e_rel <= SOCKET_TOL_CM
    chk["sockets_6"] = [ok_s and len(rb["sockets"]) == 6, {k: (v or {}).get("err_cm") for k, v in rb["sockets"].items()}]

    d = mesh.get_editor_property("asset_import_data")
    rb["import_data"] = {}
    if d is not None:
        for f in ("normal_import_method", "vertex_color_import_option", "import_morph_targets", "convert_scene",
                  "force_front_x_axis", "convert_scene_unit", "import_uniform_scale", "use_t0_as_ref_pose",
                  "update_skeleton_reference_pose"):
            rb["import_data"][f] = str(_get(d, f, "n/a"))
        try:
            rb["import_data"]["source_files"] = [str(x) for x in d.extract_filenames()]
        except Exception:
            pass
    chk["import_normals_vcolor_scale1"] = [
        "IMPORT_NORMALS" in rb["import_data"].get("normal_import_method", "") and
        "REPLACE" in rb["import_data"].get("vertex_color_import_option", "") and
        rb["import_data"].get("import_uniform_scale") == "1.0", rb["import_data"]]
    rb["pass"] = all(v[0] for v in chk.values())
    return rb


# ------------------------------------------------------------------------------------------------------------ statics
def _collision_counts(mesh):
    try:
        body = mesh.get_editor_property("body_setup")
        if body is None:
            return {"body_setup": False}
        agg = body.get_editor_property("agg_geom")
        n = {k: len(agg.get_editor_property(k)) for k in ("convex_elems", "box_elems", "sphere_elems", "sphyl_elems")}
        return {"body_setup": True, "elems": n,
                "trace": str(body.get_editor_property("collision_trace_flag")).split(".")[-1].split(":")[0]}
    except Exception as e:
        return {"error": _err(e)}


def _add_static_socket(mesh, name, loc):
    existing = mesh.find_socket(name)
    if existing is not None:
        mesh.remove_socket(existing)
    s = unreal.StaticMeshSocket(mesh)
    s.set_editor_property("socket_name", name)
    s.set_editor_property("relative_location", unreal.Vector(*[float(x) for x in loc]))
    s.set_editor_property("relative_rotation", unreal.Rotator(roll=0.0, pitch=0.0, yaw=0.0))
    mesh.add_socket(s)


def import_statics(exp):
    out = {"meshes": {}}
    tasks = [_task(os.path.join(EXPORT, c["fbx"]), c["folder"], n, _sm_opts()) for n, c in STATICS.items()]
    with _LegacyFbx() as flag:
        unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks(tasks)
    out["interchange_flag_before_after"] = [flag.was, flag.after]
    sme = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
    saved = []
    for name, c in STATICS.items():
        mesh = _load(_path(c["folder"], name))
        if mesh is None:
            out["meshes"][name] = None
            continue
        r = {}
        if c["material"]:
            mi = _load(_path(F_MAT, c["material"]))
            for i in range(len(mesh.static_materials)):
                mesh.set_material(i, mi)
            r["material"] = mi.get_name() if mi else None
        sme.remove_collisions(mesh)
        if c["collision"] == "convex":
            r["collision_call"] = sme.set_convex_decomposition_collisions(mesh, 1, 32, 100000)
        elif c["collision"] == "box":
            r["collision_call"] = sme.add_simple_collisions(mesh, unreal.ScriptCollisionShapeType.BOX)
        for s in c["sockets"]:
            _add_static_socket(mesh, s, exp["sockets"][s]["root_relative_ue_cm"])
        out["meshes"][name] = r
        saved.append(mesh)
    out["saved"] = save_owned(saved)
    return out


def statics_readback(exp):
    rb = {"meshes": {}, "checks": {}}
    for name, c in STATICS.items():
        mesh = _load(_path(c["folder"], name))
        if mesh is None:
            rb["meshes"][name] = None
            rb["checks"][name] = [False, "missing"]
            continue
        want = exp["expected"]["cube"] if c["key"] == "cube" else exp["expected"]["statics"][c["key"]]
        box = mesh.get_bounding_box()
        got = {"min": _v(box.min), "max": _v(box.max)}
        err = max(max(abs(a - b) for a, b in zip(got["min"], want["bounds_ue_cm"]["min"])),
                  max(abs(a - b) for a, b in zip(got["max"], want["bounds_ue_cm"]["max"])))
        r = {"bounds": got, "bounds_err_cm": round(err, 5), "tris": mesh.get_num_triangles(0),
             "verts": mesh.get_num_vertices(0),
             "slots": [[str(m.material_slot_name), m.material_interface.get_name() if m.material_interface else None]
                       for m in mesh.static_materials],
             "collision": _collision_counts(mesh), "sockets": {}}
        d = mesh.get_editor_property("asset_import_data")
        r["import_data"] = {f: str(_get(d, f, "n/a")) for f in ("normal_import_method", "vertex_color_import_option",
                                                              "import_uniform_scale", "remove_degenerates",
                                                              "auto_generate_collision")} if d else None
        ok = {"bounds": err <= 0.1}
        if "tris" in want:
            ok["tris"] = r["tris"] == want["tris"]
        pw = exp["pcr"]["assert_on_statics"].get(c["key"])
        if pw:
            perr = max(max(abs(a - b) for a, b in zip(got["min"], pw["bounds_ue_cm"]["min"])),
                       max(abs(a - b) for a, b in zip(got["max"], pw["bounds_ue_cm"]["max"])))
            r["pcr_bounds_err_cm"] = round(perr, 5)
            ok["bounds_vs_phase_c_readback"] = perr <= 0.1
            ok["tris_vs_phase_c_readback"] = r["tris"] == pw["tris"]
        if c["material"]:
            ok["material"] = all(s[1] == c["material"] for s in r["slots"]) and len(r["slots"]) >= 1
        el = (r["collision"].get("elems") or {})
        if c["collision"] == "convex":
            ok["collision"] = el.get("convex_elems") == 1 and sum(el.values()) == 1
        elif c["collision"] == "box":
            ok["collision"] = el.get("box_elems") == 1 and sum(el.values()) == 1
        for s in c["sockets"]:
            sock = mesh.find_socket(s)
            if sock is None:
                r["sockets"][s] = None
                ok["socket_" + s] = False
                continue
            loc = _v(sock.get_editor_property("relative_location"))
            rot = sock.get_editor_property("relative_rotation")
            e = _dist(loc, exp["sockets"][s]["root_relative_ue_cm"])
            e2 = _dist(loc, exp["pcr"]["hull_sockets"][s])
            r["sockets"][s] = {"location": loc, "rotation_pyr": [round(rot.pitch, 4), round(rot.yaw, 4), round(rot.roll, 4)],
                               "err_cm": round(e, 5), "pcr_err_cm": round(e2, 5)}
            ok["socket_" + s] = e <= 1e-3 and e2 <= 1e-3 and max(abs(rot.pitch), abs(rot.yaw), abs(rot.roll)) < 1e-4
        r["ok"] = ok
        rb["meshes"][name] = r
        rb["checks"][name] = [all(ok.values()), [k for k, v in ok.items() if not v]]
    rb["pass"] = all(v[0] for v in rb["checks"].values())
    return rb


# ------------------------------------------------------------------------------------------------------------ clips
def import_clips(exp):
    out = {"clips": {}, "missing": []}
    skel = _load(_path(F_MESH, SKEL))
    if skel is None:
        raise RuntimeError("no %s - run the mesh stage first" % SKEL)
    tasks, names = [], []
    for clip, c in sorted(exp["clips"].items()):
        fbx = os.path.join(ANIMS, os.path.basename(c["file"]))
        if not os.path.isfile(fbx):
            out["missing"].append(fbx)
            continue
        opts = _anim_opts(skel)
        out.setdefault("stored_import_data_sync", {})[clip] = _sync_stored(_load(_path(F_ANIM, ANIM % clip)), ANIM_STORED,
                                                                           opts.anim_sequence_import_data)
        tasks.append(_task(fbx, F_ANIM, ANIM % clip, opts))
        names.append(clip)
    if out["missing"]:
        raise RuntimeError("missing clip FBXs: %s" % out["missing"])
    with _LegacyFbx() as flag:
        unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks(tasks)
    out["interchange_flag_before_after"] = [flag.was, flag.after]
    saved = []
    for clip in names:
        a = _load(_path(F_ANIM, ANIM % clip))
        if a is None:
            out["clips"][clip] = None
            continue
        AL.set_root_motion_enabled(a, False)
        AL.set_rate_scale(a, 1.0)
        _set(a, "loop", bool(exp["clips"][clip]["loop"]))
        out["clips"][clip] = a.get_path_name()
        saved.append(a)
    out["saved"] = save_owned(saved)
    return out


def _local(a, bone, f):
    return AL.get_bone_pose_for_frame(a, bone, f, False)


def _pose_delta(a0, f0, a1, f1, bones):
    """Max local translation (cm), rotation (deg) and scale delta over bones between two clip frames."""
    dt = dr = ds = 0.0
    for bn in bones:
        p0, p1 = _local(a0, bn, f0), _local(a1, bn, f1)
        dt = max(dt, (p0.translation - p1.translation).length())
        dr = max(dr, _qdelta(p0.rotation, p1.rotation))
        ds = max(ds, abs(p0.scale3d.x - p1.scale3d.x), abs(p0.scale3d.y - p1.scale3d.y), abs(p0.scale3d.z - p1.scale3d.z))
    return {"t_cm": round(dt, 6), "rot_deg": round(dr, 5), "scale": round(ds, 6)}


def _world_heads(a, f):
    opt = unreal.AnimPoseEvaluationOptions()
    _set(opt, "extract_root_motion", False)
    pose = unreal.AnimPoseExtensions.get_anim_pose_at_frame(a, f, opt)
    return {str(n): unreal.AnimPoseExtensions.get_bone_pose(pose, n, unreal.AnimPoseSpaces.WORLD)
            for n in unreal.AnimPoseExtensions.get_bone_names(pose)}


def clip_readback(exp):
    rb = {"clips": {}, "checks": {}, "chain": {}, "hard_cuts": {}}
    skel_path = _path(F_MESH, SKEL)
    ea = exp["anims"]["clips"]
    loaded = {}
    for clip, c in sorted(exp["clips"].items()):
        a = _load(_path(F_ANIM, ANIM % clip))
        if a is None:
            rb["clips"][clip] = None
            rb["checks"][clip] = [False, "missing"]
            continue
        loaded[clip] = a
        n_last = c["frames"][1] - c["frames"][0]
        r = {"num_frames": AL.get_num_frames(a), "length_s": round(AL.get_sequence_length(a), 5)}
        try:
            r["num_keys"] = AL.get_num_keys(a)
        except Exception:
            r["num_keys"] = None
        tracks = [str(t) for t in AL.get_animation_track_names(a)]
        r["track_count"] = len(tracks)
        r["skeleton"] = a.get_editor_property("skeleton").get_path_name()
        r["loop"] = _get(a, "loop")
        r["root_motion"] = AL.is_root_motion_enabled(a)
        _d = _get(a, "asset_import_data")
        r["import_data"] = None if _d is None else {f: str(_get(_d, f, "n/a")) for f, _ in ANIM_STORED}
        r["rate_scale"] = AL.get_rate_scale(a)
        r["frame_rate"] = str(AL.get_frame_rate(a)) if hasattr(AL, "get_frame_rate") else None
        rs = []
        for k in range(5):
            f = int(round(n_last * k / 4.0))
            t = _local(a, "root", f)
            rs.append({"f": f, "t": _v(t.translation, 5), "q": _q(t.rotation), "s": _v(t.scale3d, 5)})
        r["root_samples"] = rs
        root_still = all(max(abs(x) for x in s["t"]) < 1e-3 and abs(abs(s["q"][3]) - 1) < 1e-5 and
                         max(abs(x - 1) for x in s["s"]) < 1e-5 for s in rs)
        seam = _pose_delta(a, 0, a, n_last, tracks) if c["loop"] else None
        r["loop_seam"] = seam
        # landmarks: every frame, component-space bone heads vs the Blender exporter's expected_anims.json
        worst, worst_at = 0.0, None
        e = ea.get(clip, {})
        for fs, lm in sorted((e.get("landmarks") or {}).items(), key=lambda kv: int(kv[0])):
            f = int(fs) - e.get("first", 0)
            heads = _world_heads(a, f)
            for bn, want in lm.items():
                if bn in heads and isinstance(want, list) and len(want) == 3:
                    d = _dist(_v(heads[bn].translation, 6), want)
                    if d > worst:
                        worst, worst_at = d, [f, bn]
        r["landmark_worst_cm"] = [round(worst, 6), worst_at]
        # scale keys at the peak frame (non-uniform bone scale survives the import)
        pk = e.get("scale_peak_frame")
        sc_err, sc_got = None, {}
        if pk is not None:
            want_sc = e["landmarks"][str(pk)]["scale"]
            sc_err = 0.0
            for bn, ws in want_sc.items():
                s = _local(a, bn, pk - e.get("first", 0)).scale3d
                sc_got[bn] = _v(s, 6)
                sc_err = max(sc_err, max(abs(x - y) for x, y in zip(sc_got[bn], ws)))
            r["scale_peak"] = {"frame": pk, "got": sc_got, "want": want_sc, "max_err": round(sc_err, 7)}
        pk_keys = exp["pcr"]["assert_on_each_anim_sequence"]["num_keys"].get(clip)
        ok = {"keys_N+1": r["num_keys"] == c["samples"] and r["num_frames"] == c["samples"] - 1 and r["num_keys"] == pk_keys,
              "length_N/30": abs(r["length_s"] - n_last / 30.0) < 1e-3,
              "tracks_17": r["track_count"] == 17, "skeleton": r["skeleton"] == skel_path,
              "root_identity_5": root_still, "loop_flag": bool(r["loop"]) == bool(c["loop"]),
              "no_root_motion": not r["root_motion"], "rate_1": abs(r["rate_scale"] - 1.0) < 1e-6,
              "seam": seam is None or (seam["t_cm"] < CHAIN_TOL and seam["rot_deg"] < 0.05 and seam["scale"] < SCALE_TOL),
              "landmarks": worst <= LANDMARK_TOL_CM,
              "scale_peak": sc_err is None or sc_err <= SCALE_TOL}
        # morph curves (B3): names, keys, every-frame value vs the Blender table, peaks
        cv = {"names": [], "per_curve": {}}
        try:
            cv["names"] = sorted(str(n) for n in AL.get_animation_curve_names(a, unreal.RawCurveTrackTypes.RCT_FLOAT))
        except Exception as ex:
            cv["error"] = _err(ex)
        cworst = 0.0
        for m in MORPHS:
            pc = {"present": m in cv["names"]}
            if pc["present"]:
                times, vals = AL.get_float_keys(a, m)
                pc["num_keys"] = len(times)
                per_f, worst_f = [], [0.0, None]
                for f in range(n_last + 1):
                    want_v = (((e.get("landmarks") or {}).get(str(f + e.get("first", 0))) or {}).get("sk") or {}).get(m)
                    got_v = AL.get_float_value_at_time(a, m, f / 30.0)
                    per_f.append(round(got_v, 6))
                    if want_v is not None and abs(got_v - want_v) > worst_f[0]:
                        worst_f = [abs(got_v - want_v), f]
                pc["values_per_frame"] = per_f
                pc["max"] = round(max(per_f), 6)
                pc["frames_at_max"] = [f for f, v in enumerate(per_f) if pc["max"] > 0 and abs(v - pc["max"]) <= CURVE_TOL]
                pc["worst_vs_blender"] = [round(worst_f[0], 7), worst_f[1]]
                cworst = max(cworst, worst_f[0])
            cv["per_curve"][m] = pc
        want_pk = exp["manifest"]["phase_c_readback"]["assert_on_each_anim_sequence"]["curve_peaks"].get(clip, {})
        pk_ok = True
        for m, w in want_pk.items():
            pc = cv["per_curve"].get(m) or {}
            if not pc.get("present"):
                pk_ok = False
                continue
            fa = pc["frames_at_max"]
            pk_ok = pk_ok and abs(pc["max"] - w["max"]) <= CURVE_TOL and                 (not w["frames_at_max"] or (fa and fa[0] == w["frames_at_max"][0] and fa[-1] == w["frames_at_max"][1]))
        r["curves"] = cv
        ok["curves_inhale_scream"] = all((cv["per_curve"].get(m) or {}).get("present") for m in MORPHS)
        ok["curve_values_every_frame"] = ok["curves_inhale_scream"] and cworst <= CURVE_TOL
        ok["curve_peaks"] = pk_ok
        r["ok"] = ok
        rb["clips"][clip] = r
        rb["checks"][clip] = [all(ok.values()), [k for k, v in ok.items() if not v]]
    # chain: each clip's f0 against its "from" clip frame, and its last frame against its "to" clip frame
    chain_ok = True
    bones = [n for n, _ in exp["bones"]]
    for clip, c in sorted(exp["clips"].items()):
        ch = c.get("chain") or {}
        n_last = c["frames"][1] - c["frames"][0]
        for kind, (src, sf) in ((k, v) for k, v in ch.items() if k in ("from", "to")):
            if clip not in loaded or src not in loaded:
                chain_ok = False
                continue
            d = _pose_delta(loaded[clip], 0 if kind == "from" else n_last, loaded[src], sf, bones)
            rb["chain"]["%s.%s <- %s f%d" % (clip, kind, src, sf)] = d
            chain_ok = chain_ok and d["t_cm"] < CHAIN_TOL and d["rot_deg"] < 0.05 and d["scale"] < SCALE_TOL
    for clip, src, sf in EXTRA_CHAIN:
        if clip in loaded and src in loaded:
            n_last = exp["clips"][clip]["frames"][1] - exp["clips"][clip]["frames"][0]
            d = _pose_delta(loaded[clip], n_last, loaded[src], sf, bones)
            rb["chain"]["%s.end <- %s f%d (notes)" % (clip, src, sf)] = d
            chain_ok = chain_ok and d["t_cm"] < CHAIN_TOL and d["rot_deg"] < 0.05 and d["scale"] < SCALE_TOL
    n_links = sum(len([k for k in (c.get("chain") or {}) if k in ("from", "to")]) for c in exp["clips"].values())
    rb["checks"]["chain"] = [chain_ok and len(rb["chain"]) == n_links + len(EXTRA_CHAIN), len(rb["chain"])]
    for c0, c1, blender in exp["hard_cuts"]:
        if c0 in loaded and c1 in loaded:
            h1 = _world_heads(loaded[c1], 0)
            res = {"blender_manifest": blender}
            n_last = exp["clips"][c0]["frames"][1] - exp["clips"][c0]["frames"][0]
            worst = [0.0, 0.0, None]
            for f in range(n_last + 1):
                h0 = _world_heads(loaded[c0], f)
                dh = max(_dist(_v(h0[n].translation, 6), _v(h1[n].translation, 6)) for n in h0)
                dr = max(_qdelta(h0[n].rotation, h1[n].rotation) for n in h0)
                if f == 0:
                    res["f0"] = [round(dh, 4), round(dr, 3)]
                if dh > worst[0]:
                    worst = [round(dh, 4), round(dr, 3), f]
            res["worst_head"] = worst
            key_cut = "%s -> %s f0" % (c0, c1)
            rb["hard_cuts"][key_cut] = res
            m_ok = True
            for which, got in (("f0", res.get("f0")), ("worst", worst[:2])):
                want = blender.get(which)
                if want is not None:
                    m_ok = m_ok and abs(got[0] - want[0]) <= CUT_MATCH_TOL[0] and abs(got[1] - want[1]) <= CUT_MATCH_TOL[1]
            rb["checks"]["cut matches manifest " + key_cut] = [m_ok, {"unreal_f0": res.get("f0"), "unreal_worst": worst,
                                                                       "manifest": blender, "tol": list(CUT_MATCH_TOL)}]
            if key_cut in CUT_GATES:
                g = CUT_GATES[key_cut]
                rb["checks"]["cut " + key_cut] = [res["f0"][0] <= g[0] and res["f0"][1] <= g[1],
                                                  {"f0": res["f0"], "gate": list(g), "worst_any_frame": worst}]
    rb["loops_brief"] = {c: (rb["clips"].get(c) or {}).get("loop_seam") for c in LOOPS_BRIEF}
    rb["pass"] = all(v[0] for v in rb["checks"].values()) and len(rb["clips"]) == N_CLIPS
    return rb


# ------------------------------------------------------------------------------------------------------------ readback
def full_readback(exp):
    return {"material_readback": material_readback(), "mesh_readback": mesh_readback(exp),
            "statics_readback": statics_readback(exp), "clip_readback": clip_readback(exp),
            "owned_assets": owned_assets(), "root_assets": root_assets()}


def _hashes(pkg):
    out = {}
    base = os.path.join(os.path.normpath(unreal.Paths.convert_relative_path_to_full(unreal.Paths.project_content_dir())),
                        *pkg[len("/Game/"):].split("/"))
    for ext in (".uasset", ".uexp", ".ubulk"):
        f = base + ext
        if os.path.isfile(f):
            with open(f, "rb") as fh:
                out[ext] = {"size": os.path.getsize(f), "sha256": hashlib.sha256(fh.read()).hexdigest()}
    return out


def _diff(a, b, path=""):
    out = []
    if isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a) | set(b)):
            out += _diff(a.get(k, "<absent>"), b.get(k, "<absent>"), "%s/%s" % (path, k))
    elif isinstance(a, list) and isinstance(b, list) and len(a) == len(b):
        for n, (x, y) in enumerate(zip(a, b)):
            out += _diff(x, y, "%s[%d]" % (path, n))
    elif isinstance(a, float) and isinstance(b, float):
        if abs(a - b) > 1e-6:
            out.append("%s: %s != %s" % (path, a, b))
    elif a != b:
        out.append("%s: %s != %s" % (path, json.dumps(a, default=str)[:120], json.dumps(b, default=str)[:120]))
    return out


def _comparable(rb):
    """Drop the fields that legitimately differ between runs (paths of source files are kept)."""
    s = json.loads(json.dumps(rb, default=str))
    return s


def _passes(rb):
    return all((rb.get(k) or {}).get("pass", False) for k in
               ("material_readback", "mesh_readback", "statics_readback", "clip_readback"))


# ------------------------------------------------------------------------------------------------------------ playback
# Single-node playback proof outside PIE (C2 brief item 3). A transient SkeletalMeshActor is spawned in the owned review map
# (never in a foreign level), animated with bUpdateAnimationInEditor so the editor world's own tick evaluates it, and read
# in a LATER run_python call (the evaluation happens on the editor tick after the call that sets it up). Stages:
#   playback_setup             open the review map (remember the previous level), spawn the probe, play ROOT_Scream at 0.4 s
#   playback_set <t> <on|off>  set position t (paused) and morph targets enabled (on) / disabled (off)
#   playback_read <tag>        read position, anim-instance curves, GetMorphTarget, jaw/MouthCue, bounds; capture the mouth
#   playback_room              capture the review room views (review module) into review/phaseC2/room
#   playback_cleanup           destroy the probe, restore the previous level
PROBE_LABEL = "ScreamingTurnipR01Review_C2PlaybackProbe_SK"
PROBE_LOC = (-150.0, 120.0, 60.0)
PROBE_YAW = 180.0           # mouth (+X) toward the amber key behind the player start


def _probe_cam():
    """C2 framing (24 cm in front, at the MouthCue height) x the manifest's scale_factor; (loc, target, fov)."""
    m = json.load(open(MANIFEST, "r", encoding="utf-8"))
    k = float(m.get("scale_factor", 1.0))
    mz = float(m["sockets"]["MouthCue"]["root_relative_ue_cm"][2])
    return ((-150.0 - 24.0 * k, 120.0, 60.0 + mz), (-150.0, 120.0, 60.0 + mz), 45.0)


def _review():
    if REVIEW_MODULE_DIR not in sys.path:
        sys.path.insert(0, REVIEW_MODULE_DIR)
    import importlib
    import screaming_turnip_review_ue as m
    importlib.reload(m)
    return m


def _probe():
    # transient actors are not listed by EditorActorSubsystem.get_all_level_actors
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    for a in unreal.GameplayStatics.get_all_actors_of_class(world, unreal.SkeletalMeshActor):
        if a.get_actor_label() == PROBE_LABEL:
            return a
    return None


def _capture_probe(path):
    rv = _review()
    world = rv._world()
    w, h = 960, 960
    rt = unreal.RenderingLibrary.create_render_target2d(world, w, h, unreal.TextureRenderTargetFormat.RTF_RGBA8,
                                                         unreal.LinearColor(r=0.0, g=0.0, b=0.0, a=1.0), False, False)
    cap = rv._eas().spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(0.0, 0.0, 100.0), rv._rot(), True)
    try:
        comp = cap.get_editor_property("capture_component2d")
        comp.set_editor_property("texture_target", rt)
        comp.set_editor_property("capture_source", unreal.SceneCaptureSource.SCS_FINAL_COLOR_LDR)
        comp.set_editor_property("capture_every_frame", False)
        comp.set_editor_property("capture_on_movement", False)
        pp = comp.get_editor_property("post_process_settings")
        for k, v in (("override_auto_exposure_method", True), ("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL),
                     ("override_auto_exposure_apply_physical_camera_exposure", True),
                     ("auto_exposure_apply_physical_camera_exposure", False),
                     ("override_auto_exposure_bias", True), ("auto_exposure_bias", rv.EXPOSURE_BIAS)):
            pp.set_editor_property(k, v)
        comp.set_editor_property("post_process_settings", pp)
        loc, target, fov = _probe_cam()
        comp.set_editor_property("fov_angle", float(fov))
        cap.set_actor_location(rv._v(loc), False, True)
        cap.set_actor_rotation(unreal.MathLibrary.find_look_at_rotation(rv._v(loc), rv._v(target)), True)
        for _ in range(3):
            comp.capture_scene()
        d, f = os.path.split(path)
        os.makedirs(d, exist_ok=True)
        unreal.RenderingLibrary.export_render_target(world, rt, d, f)
        rv._opaque_png(world, rt, path, w, h)
        return path if os.path.isfile(path) else None
    finally:
        rv._eas().destroy_actor(cap)
        unreal.RenderingLibrary.release_render_target2d(rt)


def _state(update=None):
    st = {}
    if os.path.isfile(PLAYBACK_STATE):
        st = json.load(open(PLAYBACK_STATE, "r", encoding="utf-8"))
    if update:
        st.update(update)
        os.makedirs(REVIEW_DIR, exist_ok=True)
        with open(PLAYBACK_STATE, "w", encoding="utf-8") as fh:
            json.dump(st, fh, indent=1)
    return st


def _xf(t):
    r = t.rotation.rotator()
    return {"t": _v(t.translation), "rot_pyr": [round(r.pitch, 3), round(r.yaw, 3), round(r.roll, 3)], "s": _v(t.scale3d)}


def playback(stage, arg):
    out = {"preflight": _preflight()}
    if not out["preflight"]["ok"]:
        raise RuntimeError("wrong editor or PIE running")
    rv = _review()
    scream = _load(_path(F_ANIM, ANIM % "ROOT_Scream"))
    if stage == "playback_setup":
        if out["preflight"]["foreign_dirty"]:
            raise RuntimeError("foreign dirty packages, not changing level: %s" % out["preflight"]["foreign_dirty"])
        prev = rv._world_package()
        out["open"] = rv.open_review()
        if out["open"]["current_level"] != rv.REVIEW_MAP:
            raise RuntimeError("review map did not open: %s" % out["open"])
        if prev != rv.REVIEW_MAP:
            _state({"previous_level": prev})
        out["dirty_after_open"] = _dirty()
        old = _probe()
        if old is not None:
            rv._eas().destroy_actor(old)
        a = rv._eas().spawn_actor_from_class(unreal.SkeletalMeshActor, rv._v(PROBE_LOC), rv._rot(yaw=PROBE_YAW), True)
        a.set_actor_label(PROBE_LABEL)
        c = a.skeletal_mesh_component
        c.set_skinned_asset_and_update(_load(_path(F_MESH, SK)), True)
        _set(c, "visibility_based_anim_tick_option",
             unreal.VisibilityBasedAnimTickOption.ALWAYS_TICK_POSE_AND_REFRESH_BONES)
        c.set_update_animation_in_editor(True)
        c.play_animation(scream, False)
        c.set_position(0.4, False)
        c.stop()
        out["probe"] = {"label": a.get_actor_label(), "anim_mode": str(_get(c, "animation_mode")),
                        "position_set": c.get_position(), "is_playing": c.is_playing()}
        out["dirty_after_spawn"] = _dirty()
        return out
    a = _probe()
    if stage == "playback_cleanup":
        if a is not None:
            out["destroyed"] = rv._eas().destroy_actor(a)
        out["dirty_before_restore"] = _dirty()
        prev = _state().get("previous_level")
        if out["dirty_before_restore"]:
            raise RuntimeError("dirty packages after the probe was destroyed - not changing level: %s"
                               % out["dirty_before_restore"])
        out["restore"] = rv.restore_level(prev) if prev else {"loaded": False, "error": "no previous level"}
        out["dirty_after"] = _dirty()
        return out
    if stage == "playback_room":
        if a is not None:                    # the probe floats in the room view; remove it first
            out["destroyed"] = rv._eas().destroy_actor(a)
        out["room"] = rv.capture_views(os.path.join(REVIEW_DIR, "room"))
        return out
    if a is None:
        raise RuntimeError("no probe - run playback_setup")
    c = a.skeletal_mesh_component
    if stage == "playback_set":
        t, morphs = (arg or "0.4 on").split()
        # set_editor_property re-registers the component (PostEditChange) and resets the single-node instance, so the
        # flag goes first and the clip is re-played and re-seeked after it
        if bool(_get(c, "disable_morph_target")) != (morphs == "off"):
            _set(c, "disable_morph_target", morphs == "off")
        c.set_update_animation_in_editor(True)
        c.play_animation(scream, False)
        c.set_position(float(t), False)
        c.stop()
        out["set"] = {"t": float(t), "morphs": morphs, "position_now": c.get_position(),
                      "disable_morph_target": _get(c, "disable_morph_target")}
        return out
    if stage == "playback_read":
        tag = arg or "read"
        inst = c.get_anim_instance()
        r = {"tag": tag, "position": round(c.get_position(), 5), "is_playing": c.is_playing(),
             "anim_instance": inst.get_class().get_name() if inst else None,
             "disable_morph_target": _get(c, "disable_morph_target"),
             "update_animation_in_editor": _get(c, "update_animation_in_editor")}
        r["anim_instance_curves"] = {}
        for m in MORPHS:
            try:
                r["anim_instance_curves"][m] = round(inst.get_curve_value(m), 6) if inst else None
            except Exception as e:
                r["anim_instance_curves"][m] = "n/a (%s)" % _err(e)
        r["get_morph_target"] = {m: round(c.get_morph_target(m), 6) for m in MORPHS}
        r["sequence_curves_at_position"] = {m: round(AL.get_float_value_at_time(scream, m, c.get_position()), 6)
                                            for m in MORPHS}
        try:
            r["jaw_component"] = _xf(c.get_socket_transform("jaw", unreal.RelativeTransformSpace.RTS_COMPONENT))
            r["body_component"] = _xf(c.get_socket_transform("body", unreal.RelativeTransformSpace.RTS_COMPONENT))
            r["mouthcue_component"] = _v(c.get_socket_transform(
                "MouthCue", unreal.RelativeTransformSpace.RTS_COMPONENT).translation)
        except Exception as e:
            r["bone_error"] = _err(e)
        bo, be = a.get_actor_bounds(False)      # world-space; the component bounds incl. the bounds extension
        r["actor_bounds"] = {"origin": _v(bo), "extent": _v(be)}
        r["capture"] = _capture_probe(os.path.join(REVIEW_DIR, "playback", "UE_probe_%s.png" % tag))
        out["read"] = r
        return out
    raise ValueError("unknown playback stage %s" % stage)


# ------------------------------------------------------------------------------------------------------------ entry
def _guard(rep, saves):
    pf = rep["preflight"] = _preflight()
    if not pf["ok"]:
        rep["error"] = "wrong editor or PIE running"
        return False
    if saves and pf["foreign_dirty"]:
        rep["error"] = "packages outside %s are dirty and this stage saves: %s" % (F_ROOT, pf["foreign_dirty"])
        return False
    return True


def _collision_guard(rep, exp):
    # Cube10_Mars_SM is every campaign's validation cube by convention (the bat has one under its own Validation/), so a
    # same-named asset in another candidate root is expected and not a collision.
    names = [SK, SKEL, MASTER, BED_MI] + [MI % s for s in SLOTS] + [n for n in STATICS if n != CUBE] + \
        [ANIM % c for c in exp["clips"]]
    rep["collisions_outside_root"] = _collisions(names)
    if rep["collisions_outside_root"]:
        rep["error"] = "name collision outside the owned root"
        return False
    return True


def run_imports(rep, exp, which):
    if "materials" in which:
        rep["materials"] = create_materials()
    if "mesh" in which:
        rep["mesh"] = run_mesh()
    if "statics" in which:
        rep["statics"] = import_statics(exp)
    if "clips" in which:
        rep["clips"] = import_clips(exp)


def main(stage, arg=None):
    t0 = time.time()
    rep = {"stage": stage, "arg": arg, "error": None}
    key = stage if stage not in ("reimport_b3", "reimport_b4") else (arg or stage)
    try:
        exp = _expected()
        rep["expected_source"] = exp["source"]
        if stage.startswith("playback_"):
            rep.update(playback(stage, arg))
        elif stage in ("materials", "mesh", "statics", "clips", "all", "reimport", "reimport_b3", "reimport_b4"):
            if _guard(rep, True) and _collision_guard(rep, exp):
                which = ("materials", "mesh", "statics", "clips") if stage in ("all", "reimport", "reimport_b3",
                                                                                "reimport_b4") \
                    else (stage,)
                rep["root_assets_before"] = root_assets()
                run_imports(rep, exp, which)
                rep["owned_assets"] = owned_assets()
                rep["root_assets_after"] = root_assets()
                rep["duplicates"] = [p for p in rep["root_assets_after"] if p.rsplit("_", 1)[-1].isdigit()]
                if stage == "materials":
                    rep["material_readback"] = material_readback()
                elif stage == "statics":
                    rep["statics_readback"] = statics_readback(exp)
                elif stage == "clips":
                    rep["clip_readback"] = clip_readback(exp)
                elif stage in ("all", "reimport", "reimport_b3", "reimport_b4"):
                    rep.update(full_readback(exp))
                if stage in ("reimport", "reimport_b3", "reimport_b4"):
                    rb_key = {"reimport": "readback", "reimport_b3": "readback_b3", "reimport_b4": "readback_b4"}[stage]
                    prev = _saved_readback(rb_key)
                    rep["diffed_against"] = rb_key if prev else None
                    if prev:
                        rep["diff_vs_readback"] = {
                            k: _diff(_comparable(prev.get(k)), _comparable(rep.get(k)))
                            for k in ("material_readback", "mesh_readback", "statics_readback", "clip_readback",
                                      "owned_assets", "root_assets")}
                        rep["identical"] = not any(rep["diff_vs_readback"].values())
                    rep["preflight_after"] = _preflight()
        elif stage == "socket_plan":
            rep["preflight"] = _preflight()
            rep["socket_plan"] = socket_plan(exp)
        elif stage in ("readback", "readback_b3", "readback_b4"):
            rep["preflight"] = _preflight()
            rep.update(full_readback(exp))
            rep["hashes"] = {p: _hashes(p) for p in owned_assets()}
            snap = json.loads(json.dumps(rep, default=str))
            os.makedirs(os.path.dirname(PRE_RESTART), exist_ok=True)
            with open(PRE_RESTART, "w", encoding="utf-8") as fh:
                json.dump(snap, fh, indent=1)
        elif stage == "reload":
            rep["preflight"] = _preflight()
            rep["method"] = ("fresh editor process = cold disk read; readback compared with "
                             "review/phaseC3/readback_pre_restart.json; no unload (bat I-4)")
            pre = json.load(open(PRE_RESTART, "r", encoding="utf-8"))
            now = json.loads(json.dumps(full_readback(exp), default=str))
            rep["hashes"] = {p: _hashes(p) for p in owned_assets()}
            rep["diff"] = {k: _diff(pre.get(k), now.get(k)) for k in now}
            rep["hash_diff"] = _diff(pre.get("hashes"), rep["hashes"])
            rep["readings_match"] = not any(rep["diff"].values())
            rep["pass_now"] = _passes(now)
        else:
            raise ValueError("unknown stage %s" % stage)
    except Exception as e:
        import traceback
        rep["error"] = _err(e)
        rep["trace"] = traceback.format_exc()
        key = stage + "_error"
    rep["seconds"] = round(time.time() - t0, 2)
    rep = json.loads(json.dumps(rep, default=str))
    _merge_readback(key, rep)
    summary = {k: (rep.get(k) or {}).get("pass") for k in
               ("material_readback", "mesh_readback", "statics_readback", "clip_readback") if k in rep}
    print("TURNIP_UE stage=%s error=%s seconds=%s pass=%s" % (stage, rep.get("error"), rep["seconds"], summary))
    for k in ("material_readback", "mesh_readback", "statics_readback", "clip_readback"):
        if k in rep:
            fails = {c: v[1] for c, v in (rep[k].get("checks") or {}).items() if not v[0]}
            print("TURNIP_UE %s fails=%s" % (k, json.dumps(fails, default=str)[:3000]))
    for k in ("socket_plan", "collisions_outside_root", "duplicates", "identical", "readings_match", "preflight",
              "open", "probe", "dirty_after_spawn", "set", "read", "room", "destroyed", "dirty_before_restore", "restore",
              "dirty_after"):
        if k in rep:
            print("TURNIP_UE %s=%s" % (k, json.dumps(rep[k], default=str)[:3000]))
    passed = rep.get("error") is None and all(v for v in summary.values() if v is not None)
    print("TURNIP_OK" if passed else "TURNIP_FAIL")
    return rep


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "readback", " ".join(sys.argv[2:]) if len(sys.argv) > 2 else None)
