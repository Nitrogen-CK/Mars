"""Cellar Bat R01 - candidate-only Unreal importer + validator (Phase 5). Runs inside the editor's Python through Monolith
`editor_query run_python` ({"command": "<this file> <stage>", "mode": "execute_file", "unattended": true}), never in PIE.

Writes only under /Game/ArtCandidates/CellarBat/R01/{Meshes,Materials,Physics,Animation}/ and saves only the assets it
creates (EditorAssetLibrary.save_loaded_asset per asset; never Save All). Importer flag (Interchange FBX) is restored in a
finally. Every stage returns/prints a JSON report and merges it into export/unreal_readback_final.json.

Stages (argv[1]):
  part_a      materials -> bind mesh (new dedicated skeleton) -> LOD1/LOD2 -> slots -> sockets -> bounds -> physics -> save
              -> readback (mesh side)
  readback    mesh-side readback only (no writes)
  reload      cold-read proof: run in a FRESH editor process; readback vs review/phase5/readback_pre_restart.json (no unload: I-4)
  reimport_a  run part_a again on the existing assets (replace_existing) and diff against the first pass
  part_b      the 18 clips against the SKEL, loop flags, additive banks, notifies, save, clip readback (needs the manifest
              or export/anims/clips.json and the clip FBXs)
  reimport_b  part_b again (replace_existing) and diff

Expected values come from export/CellarBat_R01_Manifest.json when it exists; until then from
export/validation/expected.json (bones, LOD tris, bind bounds) and export/anims/clips.json (clips) - both written by the
Blender exporter. The source of every expected value is recorded in the readback ("expected_source").
"""
import hashlib
import json
import math
import os
import sys
import time

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(HERE)
EXPORT = os.path.join(ROOT_DIR, "export")
ANIMS = os.path.join(EXPORT, "anims")
READBACK = os.path.join(EXPORT, "unreal_readback_final.json")
MANIFEST = os.path.join(EXPORT, "CellarBat_R01_Manifest.json")
PROJECT = "D:/Repositories/CkRepos/Orion/Mars.uproject"
FBX_FLAG = "Interchange.FeatureFlags.Import.FBX"

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary
AL = unreal.AnimationLibrary

F_ROOT = "/Game/ArtCandidates/CellarBat/R01"
F_MESH, F_MAT, F_PHYS, F_ANIM = F_ROOT + "/Meshes", F_ROOT + "/Materials", F_ROOT + "/Physics", F_ROOT + "/Animation"
OWNED_FOLDERS = (F_MESH, F_MAT, F_PHYS, F_ANIM)
SK, SKEL, PHYS = "CellarBat_R01_Mars_SK", "CellarBat_R01_Mars_SKEL", "CellarBat_R01_Mars_PHYS"
MASTER = "CellarBat_R01_Mars_M"
MASTER_TWO_SIDED = "CellarBat_R01_TwoSided_Mars_M"      # only created if the MI two-sided override is unavailable
MI = "CellarBat_R01_%s_Mars_MI"
ANIM = "CellarBat_R01_%s_Mars_ANIM"
SLOTS = ("Body", "Membrane", "Eyes")
FBX_SK = "CellarBat_R01_Mars_SK.fbx"
FBX_LOD = {1: "CellarBat_R01_LOD1_Mars_SK.fbx", 2: "CellarBat_R01_LOD2_Mars_SK.fbx"}
LOD_SCREEN_SIZES = (1.0, 0.35, 0.15)
SPAN_CM, SPAN_TOL = 75.0, 0.5


def _srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


EYE_SRGB = (0xFF / 255.0, 0xC5 / 255.0, 0x70 / 255.0)
# Material instance values (brief item 1; Phase 3b: Body rough 0.85 / spec 0.25, Membrane rough 0.8 + two-sided).
MI_VALUES = {
    "Body": {"scalars": {"Roughness": 0.85, "Specular": 0.25}, "two_sided": False},
    "Membrane": {"scalars": {"Roughness": 0.8, "Specular": 0.25}, "two_sided": True},
    "Eyes": {"scalars": {"Roughness": 0.4, "Specular": 0.5, "EmissiveIntensity": 3.0},
             "vectors": {"EmissiveColor": tuple(_srgb_to_linear(c) for c in EYE_SRGB)}, "two_sided": False},
}
MASTER_DEFAULTS = {"Roughness": 0.85, "Specular": 0.25, "CavityFloor": 0.45, "VertexColorGamma": 2.2,
                   "EmissiveIntensity": 0.0}

# Socket targets in Unreal component space of the BIND pose (cm). Derived 2026-11-05 from the Blender source
# (scratch probe, source/CellarBat_R01.blend, Blender frame (x, y, z) == Unreal (x, -y, z)):
#  - Mouth: the front of the mouth slit, head_centre + HEAD_SCALE * (3.5, 0, -1.61) (between the muzzle roof at -1.5 and
#    the jaw top at -1.72, build_face) = (7.703, 0, 3.749). Rides `head`.
#  - Perch: the perch-bar centre (3.0, 0, 18.75) of the hang, carried back into the bind pose by the pelvis delta of
#    RoostIdle frame 0 (D = pelvis_hang * pelvis_bind^-1; point = D^-1 * bar) = (-6.668, 0, -17.779). Rides `pelvis`, so
#    while RoostIdle plays the socket sits on the bar centre.
#  - RoostFootL/R: the foot bone tails (claw tips) of the bind pose, riding foot_l / foot_r.
# A manifest "sockets" block {name: {"bone": b, "component_cm": [x, y, z]}} overrides these.
SOCKETS = {
    "Mouth": {"bone": "head", "component_cm": [7.703, 0.0, 3.749]},
    "Perch": {"bone": "pelvis", "component_cm": [-6.668, 0.0, -17.779]},
    "RoostFootL": {"bone": "foot_l", "component_cm": [-4.3882, -5.3923, -15.4025]},
    "RoostFootR": {"bone": "foot_r", "component_cm": [-4.3882, 5.3923, -15.4025]},
}
# Bounds: union of the posed LOD0 mesh over every Phase 3 pose action (Spread/Up/Down/Recover/HalfFold/Wrap/Banks/Hang/
# Screech/EarsFlat + the flap test), Blender probe 2026-11-05: min (-19.511, -38.910, -17.809) max (17.048, 38.910,
# 27.586) vs bind min (-11.889, -37.5, -16.339) max (8.353, 37.5, 17.023). Extension = excess + 3 cm margin, rounded up.
# Part B recomputes this from the 18 imported clips (bone extents) and widens it if a clip reaches further.
# Part B (2026-11-05, first clip import): bone-head + tip-tail extents over every frame of the 18 clips reached
# min (-21.62, -39.67, -22.78) max (30.14, 39.77, 25.19) (Launch dive x 30.14, Launch z -22.78), past the Phase 3 pose
# union; POSE_UNION_CM is the union of both.
POSE_UNION_CM = {"min": [-21.62, -39.67, -22.78], "max": [30.14, 39.77, 27.586]}
BOUNDS_MARGIN_CM = 3.0
# Physics: one capsule on `spine`, centred on the torso (midpoint of the pelvis tail and spine tail, bind pose), its
# axis along the 30 deg body lean (pelvis tail -> spine tail), radius = half the torso width (12 cm), no wing bodies.
TORSO = {"bone": "spine", "a": [-3.75, 0.0, -6.4952], "b": [2.3, 0.0, 3.9837], "radius": 5.5, "length": 7.0}

# Notifies: one track per marker named <Marker>_Silent with a sound-less AnimNotify_PlaySound (see _set_notifies).
ADDITIVE = ("BankLeft", "BankRight")
ADDITIVE_REF = "Hover"


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


def _pie():
    try:
        return unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).is_in_play_in_editor()
    except Exception:
        return False


def _preflight():
    proj = unreal.Paths.convert_relative_path_to_full(unreal.Paths.get_project_file_path())
    pie = _pie()
    return {"project": proj, "pie": pie, "engine": unreal.SystemLibrary.get_engine_version(),
            "ok": proj == PROJECT and not pie}


def _content_dir():
    return os.path.normpath(unreal.Paths.convert_relative_path_to_full(unreal.Paths.project_content_dir()))


def _disk(pkg):
    return os.path.join(_content_dir(), *pkg[len("/Game/"):].split("/"))


def _ar_assets(root):
    flt = unreal.ARFilter(package_paths=[root], recursive_paths=True)
    return unreal.AssetRegistryHelpers.get_asset_registry().get_assets(flt)


def owned_assets():
    """Assets in the folders this importer owns (Meshes, Materials, Physics, and its own clips in Animation)."""
    out = []
    for f in (F_MESH, F_MAT, F_PHYS):
        out += [str(a.package_name) for a in _ar_assets(f)]
    for a in _ar_assets(F_ANIM):
        n = str(a.asset_name)
        if n.startswith("CellarBat_R01_") and n.endswith("_Mars_ANIM") and "/Additive/" not in str(a.package_name):
            out.append(str(a.package_name))
    return sorted(set(out))


def _expected():
    """Expected values: manifest first, Blender sidecars as the fallback (recorded in expected_source)."""
    exp = {"source": None}
    if os.path.isfile(MANIFEST):
        with open(MANIFEST, "r", encoding="utf-8") as fh:
            exp["manifest"] = json.load(fh)
        exp["source"] = "export/CellarBat_R01_Manifest.json"
    side = json.load(open(os.path.join(EXPORT, "validation", "expected.json"), "r", encoding="utf-8"))
    exp["bones"] = [(b["name"], b["parent"]) for b in side["bones"]]
    exp["bone_heads"] = {b["name"]: b["head_ue_cm"] for b in side["bones"]}
    exp["lods"] = {int(k): v for k, v in side["lods"].items()}
    exp["slots"] = list(side["slots"])
    m = exp.get("manifest") or {}
    # manifest overrides where it carries the same facts (key names tolerant: the Blender executor owns the schema)
    for key in ("lods", "LODs"):
        if isinstance(m.get(key), (dict, list)):
            src = m[key]
            items = src.items() if isinstance(src, dict) else enumerate(src)
            for k, v in items:
                try:
                    idx = int(str(k).replace("LOD", ""))
                except ValueError:
                    continue
                if isinstance(v, dict) and ("tris" in v or "triangles" in v):
                    exp["lods"].setdefault(idx, {})["tris"] = v.get("tris", v.get("triangles"))
    if isinstance(m.get("slots"), list) and m["slots"]:
        exp["slots"] = [s if isinstance(s, str) else s.get("name") for s in m["slots"]]
    if isinstance(m.get("bones"), list) and m["bones"] and isinstance(m["bones"][0], dict):
        exp["bones"] = [(b["name"], b.get("parent")) for b in m["bones"]]
    if exp["source"] is None:
        exp["source"] = "export/validation/expected.json (manifest absent)"
    exp["sockets"] = dict(SOCKETS)
    if isinstance(m.get("sockets"), dict):
        for k, v in m["sockets"].items():
            if isinstance(v, dict) and "bone" in v and "component_cm" in v:
                exp["sockets"][k] = v
    exp["clips"] = _clips(m)
    return exp


def _clips(m):
    src = m.get("clips") if isinstance(m.get("clips"), (dict, list)) else None
    if src is None and os.path.isfile(os.path.join(ANIMS, "clips.json")):
        src = json.load(open(os.path.join(ANIMS, "clips.json"), "r", encoding="utf-8"))
    out = {}
    items = src.items() if isinstance(src, dict) else ((c.get("name"), c) for c in (src or []))
    for name, c in items:
        fr = c.get("frames") or [c.get("start_frame", 0), c.get("end_frame", 0)]
        out[name] = {"frames": list(fr), "samples": c.get("samples", fr[1] - fr[0] + 1), "fps": c.get("fps", 30),
                     "loop": bool(c.get("loop")), "markers": dict(c.get("markers") or {}),
                     "fbx": c.get("fbx") or c.get("file") or c.get("export_path") or "CellarBat_R01_%s_Mars_ANIM.fbx" % name}
    return out


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
    """Interchange FBX off for the block, restored to its previous value in a finally."""

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
                        ("import_meshes_in_bone_hierarchy", False), ("update_skeleton_reference_pose", False),
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
                        ("do_not_import_curve_with_zero", True), ("preserve_local_transform", False),
                        ("convert_scene", True), ("force_front_x_axis", False), ("convert_scene_unit", False),
                        ("import_uniform_scale", 1.0)):
        _set(d, prop, value)
    return o


def _collisions(names):
    """Same-named assets outside the owned root (asset-registry check before writing)."""
    want = set(names)
    hits = {}
    for a in _ar_assets("/Game"):
        n = str(a.asset_name)
        if n in want:
            pkg = str(a.package_name)
            if not pkg.startswith(F_ROOT + "/"):
                hits.setdefault(n, []).append(pkg)
    return hits


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
    """BaseColor = VertexColor.RGB ^ VertexColorGamma x lerp(CavityFloor, 1, VertexColor.A); Roughness, Specular
    scalars; Metallic 0; Emissive = EmissiveColor x EmissiveIntensity."""
    for _ in range(8):
        if MEL.get_num_material_expressions(m) == 0:
            break
        MEL.delete_all_material_expressions(m)
    _set(m, "used_with_skeletal_mesh", True)
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
    ecol = E(m, unreal.MaterialExpressionVectorParameter, -850, 550)
    ecol.set_editor_property("parameter_name", "EmissiveColor")
    ecol.set_editor_property("default_value", unreal.LinearColor(r=0.0, g=0.0, b=0.0, a=1.0))
    eint = scalar("EmissiveIntensity", -850, 750)
    emul = E(m, unreal.MaterialExpressionMultiply, -600, 600)
    MEL.connect_material_expressions(ecol, "", emul, "A")
    MEL.connect_material_expressions(eint, "", emul, "B")
    MEL.connect_material_property(emul, "", unreal.MaterialProperty.MP_EMISSIVE_COLOR)
    MEL.recompile_material(m)


def _set_two_sided(mi, on):
    """MI base-property override (bOverride_TwoSided + TwoSided). Returns True when the override reads back."""
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


def create_materials():
    out = {"master": None, "instances": {}, "two_sided_route": None}
    master, new = _new_or_load(MASTER, F_MAT, unreal.Material, unreal.MaterialFactoryNew())
    _build_master(master)
    out["master"] = {"path": master.get_path_name(), "new": new}
    for slot in SLOTS:
        cfg = MI_VALUES[slot]
        mi, new = _new_or_load(MI % slot, F_MAT, unreal.MaterialInstanceConstant,
                               unreal.MaterialInstanceConstantFactoryNew())
        MEL.set_material_instance_parent(mi, master)
        for k, v in cfg.get("scalars", {}).items():
            MEL.set_material_instance_scalar_parameter_value(mi, k, float(v))
        for k, v in cfg.get("vectors", {}).items():
            MEL.set_material_instance_vector_parameter_value(mi, k, unreal.LinearColor(r=v[0], g=v[1], b=v[2], a=1.0))
        ok = _set_two_sided(mi, cfg["two_sided"])
        if cfg["two_sided"]:
            if ok:
                out["two_sided_route"] = "MaterialInstance base_property_overrides (override_two_sided + two_sided)"
            else:   # fall back to the brief's second master
                m2, _ = _new_or_load(MASTER_TWO_SIDED, F_MAT, unreal.Material, unreal.MaterialFactoryNew())
                _build_master(m2)
                m2.set_editor_property("two_sided", True)
                MEL.recompile_material(m2)
                MEL.set_material_instance_parent(mi, m2)
                for k, v in cfg.get("scalars", {}).items():
                    MEL.set_material_instance_scalar_parameter_value(mi, k, float(v))
                out["two_sided_route"] = "second master %s" % MASTER_TWO_SIDED
        MEL.update_material_instance(mi)
        out["instances"][slot] = {"path": mi.get_path_name(), "new": new}
    return out


def material_readback():
    out = {}
    master = _load(_path(F_MAT, MASTER))
    out["master"] = None if master is None else {
        "path": master.get_path_name(), "used_with_skeletal_mesh": _get(master, "used_with_skeletal_mesh"),
        "two_sided": _get(master, "two_sided"), "expressions": MEL.get_num_material_expressions(master),
        "scalar_params": sorted(str(n) for n in MEL.get_scalar_parameter_names(master)),
        "vector_params": sorted(str(n) for n in MEL.get_vector_parameter_names(master))}
    out["instances"] = {}
    for slot in SLOTS:
        mi = _load(_path(F_MAT, MI % slot))
        if mi is None:
            out["instances"][slot] = None
            continue
        r = {"parent": mi.get_editor_property("parent").get_name() if mi.get_editor_property("parent") else None}
        for k in ("Roughness", "Specular", "EmissiveIntensity", "CavityFloor", "VertexColorGamma"):
            r[k] = round(MEL.get_material_instance_scalar_parameter_value(mi, k), 5)
        c = MEL.get_material_instance_vector_parameter_value(mi, "EmissiveColor")
        r["EmissiveColor"] = [round(c.r, 5), round(c.g, 5), round(c.b, 5)]
        try:
            o = mi.get_editor_property("base_property_overrides")
            r["two_sided_override"] = [bool(o.get_editor_property("override_two_sided")),
                                       bool(o.get_editor_property("two_sided"))]
        except Exception as e:
            r["two_sided_override"] = "n/a (%s)" % _err(e)
        out["instances"][slot] = r
    return out


# ------------------------------------------------------------------------------------------------------------- mesh
def _ref_pose_world(skel):
    pose = unreal.AnimPoseExtensions.get_reference_pose(skel)
    names = [str(n) for n in unreal.AnimPoseExtensions.get_bone_names(pose)]
    return pose, names


def import_mesh(exp):
    out = {}
    existing = _load(_path(F_MESH, SK))
    skel = _load(_path(F_MESH, SKEL))
    out["existing_mesh"] = existing is not None
    with _LegacyFbx() as flag:
        unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks(
            [_task(os.path.join(EXPORT, FBX_SK), F_MESH, SK, _sk_opts(skel))])
        mesh = _load(_path(F_MESH, SK))
        if mesh is None:
            raise RuntimeError("bind mesh import produced nothing")
        # the importer names a new skeleton <mesh>_Skeleton: give it the owned name (only on the first import)
        sk_path = mesh.skeleton.get_path_name().split(".")[0]
        if not sk_path.endswith("/" + SKEL):
            if EAL.does_asset_exist(_path(F_MESH, SKEL)):
                raise RuntimeError("mesh got skeleton %s while %s exists" % (sk_path, SKEL))
            EAL.rename_asset(sk_path, "%s/%s" % (F_MESH, SKEL))
        out["skeleton"] = mesh.skeleton.get_path_name()
        sub = unreal.get_editor_subsystem(unreal.SkeletalMeshEditorSubsystem)
        out["lod_import"] = {}
        for lod, fbx in sorted(FBX_LOD.items()):
            out["lod_import"][lod] = sub.import_lod(mesh, lod, os.path.join(EXPORT, fbx))
    out["interchange_flag_before_after"] = [flag.was, flag.after]
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


def _bone_world(skel):
    pose, names = _ref_pose_world(skel)
    return {n: unreal.AnimPoseExtensions.get_bone_pose(pose, n, unreal.AnimPoseSpaces.WORLD) for n in names}


def socket_plan(mesh, exp):
    """Bone-local offsets for the sockets (READ ONLY). The sockets themselves are written on the dedicated skeleton by
    Monolith `animation_query add_socket` / `set_socket_transform` from outside the editor's Python: incident I-3 - a raw
    Python SkeletalMesh.add_socket killed the editor, so this script never calls add_socket / rename_socket /
    set_socket_parent. mesh.find_socket (used by the readback) also finds skeleton sockets."""
    world = _bone_world(mesh.skeleton)
    out = {}
    for name, s in sorted(exp["sockets"].items()):
        rel = world[s["bone"]].inverse_transform_location(unreal.Vector(*[float(x) for x in s["component_cm"]]))
        out[name] = {"bone": s["bone"], "location": [round(rel.x, 4), round(rel.y, 4), round(rel.z, 4)],
                     "rotation": [0.0, 0.0, 0.0], "exists": mesh.find_socket(name) is not None}
    return out


def set_bounds(mesh):
    ib = mesh.get_imported_bounds()
    lo, hi = ib.origin - ib.box_extent, ib.origin + ib.box_extent
    pos = [math.ceil(max(0.0, POSE_UNION_CM["max"][i] - (hi.x, hi.y, hi.z)[i]) + BOUNDS_MARGIN_CM) for i in range(3)]
    neg = [math.ceil(max(0.0, (lo.x, lo.y, lo.z)[i] - POSE_UNION_CM["min"][i]) + BOUNDS_MARGIN_CM) for i in range(3)]
    mesh.set_editor_property("positive_bounds_extension", unreal.Vector(*pos))
    mesh.set_editor_property("negative_bounds_extension", unreal.Vector(*neg))
    return {"positive": pos, "negative": neg}


def _torso_capsule():
    a, b = TORSO["a"], TORSO["b"]
    c = [(a[i] + b[i]) / 2.0 for i in range(3)]
    d = [b[i] - a[i] for i in range(3)]
    n = math.sqrt(sum(x * x for x in d))
    return c, [x / n for x in d]


def build_physics(mesh):
    """One capsule on `spine`. The PhysicsAsset bodies are not exposed to Python in 5.7.4, so the asset is made by
    SkeletalMeshEditorSubsystem.create_physics_asset (the importer's generator) and then reduced/reshaped through
    whatever this engine exposes; the readback reports what it got."""
    out = {}
    p = _path(F_PHYS, PHYS)
    phys = _load(p)
    if phys is None:
        sub = unreal.get_editor_subsystem(unreal.SkeletalMeshEditorSubsystem)
        phys = sub.create_physics_asset(mesh, False, 0)
        if phys is None:
            raise RuntimeError("create_physics_asset returned None")
        src = phys.get_path_name().split(".")[0]
        out["generated_at"] = src
        if src != F_PHYS + "/" + PHYS:
            EAL.rename_asset(src, F_PHYS + "/" + PHYS)
        phys = _load(p)
        out["new"] = True
    else:
        out["new"] = False
    out["shape"] = _reshape_physics(phys)
    mesh.set_editor_property("physics_asset", phys)
    out["path"] = phys.get_path_name()
    return phys, out


def _body_setups(phys):
    """PhysicsAsset.SkeletalBodySetups is protected in 5.7.4 Python; the setups are reachable as sub-objects."""
    return [o for o in unreal.ObjectIterator(unreal.BodySetup) if o.get_outer() == phys]


def _bodies_report(phys):
    out = {}
    for o in _body_setups(phys):
        ag = o.get_editor_property("agg_geom")
        out[str(o.get_editor_property("bone_name"))] = [
            {"center": _v(e.get_editor_property("center"), 3), "rotation": [round(x, 3) for x in (e.get_editor_property("rotation").pitch, e.get_editor_property("rotation").yaw,
                                                e.get_editor_property("rotation").roll)],
             "radius": round(e.get_editor_property("radius"), 3), "length": round(e.get_editor_property("length"), 3)}
            for e in ag.get_editor_property("sphyl_elems")]
    return out


def _bodies_collision(phys):
    out = {}
    for o in _body_setups(phys):
        r = {}
        try:
            r["type"] = str(o.get_editor_property("physics_type")).split(".")[-1].split(":")[0]
        except Exception as e:
            r["type"] = "n/a %s" % _err(e)
        try:
            bi = o.get_editor_property("default_instance")
            r["collision"] = str(bi.get_editor_property("collision_enabled")).split(".")[-1].split(":")[0]
        except Exception as e:
            r["collision"] = None
            r["collision_error"] = _err(e)
        out[str(o.get_editor_property("bone_name"))] = r
    return out


# Torso capsules (component space, bind pose): spine = the chest/belly capsule along the 30 deg body lean; pelvis = a
# small rump capsule inside the lower torso. The generator also adds head and wrist bodies; those cannot be removed from
# Python or Monolith in 5.7.4 (see PROGRESS Phase 5) and are handled outside this function.
TORSO_BODIES = {
    "spine": {"center": None, "radius": 6.0, "length": 6.0},
    "pelvis": {"center": [-2.6, 0.0, -4.5], "radius": 4.5, "length": 1.0},
}


def _reshape_physics(phys):
    """Reshape the spine (+pelvis) bodies into torso capsules; returns before/after shapes."""
    rep = {"before": _bodies_report(phys)}
    mesh = _load(_path(F_MESH, SK))
    world = _bone_world(mesh.skeleton)
    c, axis = _torso_capsule()
    for o in _body_setups(phys):
        bone = str(o.get_editor_property("bone_name"))
        if bone not in TORSO_BODIES:
            continue
        cfg = TORSO_BODIES[bone]
        centre = cfg["center"] or c
        bw = world[bone]
        lc = bw.inverse_transform_location(unreal.Vector(*centre))
        la = bw.rotation.unrotate_vector(unreal.Vector(*axis))
        rot = unreal.MathLibrary.make_rot_from_z(la)
        ag = o.get_editor_property("agg_geom")
        el = unreal.KSphylElem()
        el.set_editor_property("center", lc)
        el.set_editor_property("rotation", rot)
        el.set_editor_property("radius", float(cfg["radius"]))
        el.set_editor_property("length", float(cfg["length"]))
        ag.set_editor_property("sphyl_elems", [el])
        o.set_editor_property("agg_geom", ag)
    rep["after"] = _bodies_report(phys)
    return rep


def save_owned(assets):
    saved = []
    for a in assets:
        if a is None:
            continue
        pn = a.get_path_name()
        if any(pn.startswith(f + "/") for f in OWNED_FOLDERS):
            if EAL.save_loaded_asset(a, False):
                saved.append(pn)
    return saved


def mesh_readback(exp):
    rb = {"checks": {}}
    chk = rb["checks"]
    mesh = _load(_path(F_MESH, SK))
    if mesh is None:
        chk["mesh_exists"] = [False, None]
        return rb
    skel = mesh.skeleton
    rb["mesh"] = mesh.get_path_name()
    rb["skeleton"] = skel.get_path_name() if skel else None
    chk["dedicated_skeleton"] = [rb["skeleton"] == _path(F_MESH, SKEL), rb["skeleton"]]
    ib = mesh.get_imported_bounds()
    lo, hi = ib.origin - ib.box_extent, ib.origin + ib.box_extent
    span = hi.y - lo.y
    rb["imported_bounds"] = {"min": _v(lo), "max": _v(hi), "span_y": round(span, 4)}
    chk["span_75"] = [abs(span - SPAN_CM) <= SPAN_TOL, round(span, 4)]
    b0 = exp["lods"].get(0, {}).get("bounds_ue_cm")
    if b0:
        err = max(max(abs(a - b) for a, b in zip(_v(lo), b0["min"])), max(abs(a - b) for a, b in zip(_v(hi), b0["max"])))
        chk["bind_bounds_match_blender"] = [err <= 0.1, round(err, 4)]
    chk["nose_at_plus_x"] = [hi.x > 0 and hi.x > abs(lo.x) * 0.5 and abs(hi.x - (b0 or {}).get("max", [hi.x])[0]) <= 0.1,
                             round(hi.x, 4)]
    b = mesh.get_bounds()
    rb["bounds_with_extension"] = {"origin": _v(b.origin), "extent": _v(b.box_extent),
                                   "positive_extension": _v(mesh.get_editor_property("positive_bounds_extension")),
                                   "negative_extension": _v(mesh.get_editor_property("negative_bounds_extension"))}
    elo, ehi = b.origin - b.box_extent, b.origin + b.box_extent
    contains = all(elo_i <= u - 0.01 for elo_i, u in zip((elo.x, elo.y, elo.z), POSE_UNION_CM["min"])) and \
        all(ehi_i >= u + 0.01 for ehi_i, u in zip((ehi.x, ehi.y, ehi.z), POSE_UNION_CM["max"]))
    chk["bounds_contain_pose_union"] = [contains, {"min": _v(elo), "max": _v(ehi)}]

    # skeleton: ref pose, names, parents (SkeletonModifier reads the mesh's skeleton; nothing is committed)
    pose, names = _ref_pose_world(skel)
    want = exp["bones"]
    parents = {}
    try:
        sm = unreal.SkeletonModifier()
        sm.set_skeletal_mesh(mesh)
        for n in names:
            p = str(sm.get_parent_name(n))
            parents[n] = None if p in ("None", "") else p
        rb["parents_source"] = "SkeletonModifier.get_parent_name (read only, never committed)"
    except Exception as e:
        rb["parents_source"] = "unavailable: %s" % _err(e)
    rb["bone_order"] = names
    chk["bone_count_42"] = [len(names) == 42, len(names)]
    chk["bone_order_matches_source"] = [names == [n for n, _ in want], None]
    wrong = [n for n, p in want if parents.get(n, "<missing>") != p] if parents else ["<no parent api>"]
    chk["parents_exact"] = [not wrong, wrong]
    root = unreal.AnimPoseExtensions.get_bone_pose(pose, "root", unreal.AnimPoseSpaces.LOCAL)
    r = root.rotation
    root_ok = abs(abs(r.w) - 1) < 1e-5 and root.translation.length() < 1e-4 and \
        max(abs(root.scale3d.x - 1), abs(root.scale3d.y - 1), abs(root.scale3d.z - 1)) < 1e-5
    chk["root_identity"] = [root_ok, {"t": _v(root.translation, 6), "q": _q(r), "s": _v(root.scale3d, 6)}]
    worst_s, worst_h = 0.0, 0.0
    for n in names:
        lt = unreal.AnimPoseExtensions.get_bone_pose(pose, n, unreal.AnimPoseSpaces.LOCAL)
        wt = unreal.AnimPoseExtensions.get_bone_pose(pose, n, unreal.AnimPoseSpaces.WORLD)
        s = lt.scale3d
        worst_s = max(worst_s, abs(s.x - 1), abs(s.y - 1), abs(s.z - 1))
        e = exp["bone_heads"].get(n)
        if e:
            h = wt.translation
            worst_h = max(worst_h, math.sqrt((h.x - e[0]) ** 2 + (h.y - e[1]) ** 2 + (h.z - e[2]) ** 2))
    chk["bone_scales_1"] = [worst_s < 1e-5, round(worst_s, 7)]
    chk["bone_heads_match_blender"] = [worst_h <= 0.1, round(worst_h, 5)]
    w = _bone_world(skel)
    chk["handedness_upperarm_r_plus_y"] = [w["upperarm_r"].translation.y > 0 > w["upperarm_l"].translation.y,
                                           [round(w["upperarm_r"].translation.y, 3), round(w["upperarm_l"].translation.y, 3)]]

    # slots and materials
    slots = [str(m.material_slot_name) for m in mesh.materials]
    mats = [m.material_interface.get_name() if m.material_interface else None for m in mesh.materials]
    rb["slots"] = list(zip(slots, mats))
    chk["slots_in_order"] = [slots == exp["slots"], slots]
    chk["slots_bound_to_instances"] = [mats == [MI % s for s in slots], mats]

    # LODs (triangles per LOD come from Monolith mesh_query get_mesh_lods, merged by the caller)
    sub = unreal.get_editor_subsystem(unreal.SkeletalMeshEditorSubsystem)
    n_lod = sub.get_lod_count(mesh)
    rb["lods"] = {i: {"render_verts": sub.get_num_verts(mesh, i), "sections": sub.get_num_sections(mesh, i)}
                  for i in range(n_lod)}
    chk["lod_count_3"] = [n_lod == 3, n_lod]
    morphs = [str(x) for x in mesh.get_all_morph_target_names()]
    chk["morph_count_0"] = [not morphs, morphs]

    # sockets
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
        comp = w[bone].transform_location(rel) if bone in w else None
        err = None if comp is None else math.sqrt(sum((a - b) ** 2 for a, b in zip(_v(comp), s["component_cm"])))
        rb["sockets"][name] = {"bone": bone, "relative_cm": _v(rel), "component_cm": _v(comp) if comp else None,
                               "target_cm": s["component_cm"], "err_cm": None if err is None else round(err, 4)}
        ok_s = ok_s and bone == s["bone"] and err is not None and err <= 0.01
    chk["sockets"] = [ok_s, sorted(rb["sockets"])]

    # physics
    phys = mesh.get_editor_property("physics_asset")
    rb["physics_asset"] = phys.get_path_name() if phys else None
    chk["physics_asset_assigned"] = [rb["physics_asset"] == _path(F_PHYS, PHYS), rb["physics_asset"]]
    bodies = _bodies_report(phys) if phys else {}
    rb["physics_bodies"] = bodies
    coll = _bodies_collision(phys) if phys else {}
    rb["physics_collision"] = coll
    torso = {b: coll.get(b) for b in bodies if b in ("spine", "pelvis")}
    extra = {b: coll.get(b) for b in bodies if b not in ("spine", "pelvis")}
    # Stopgap (coordinator decision): 2 torso bodies with collision; head/wrists collision off + kinematic until a human
    # deletes them in the Physics Asset editor. The clean target is 1-2 torso bodies only.
    chk["physics_torso_bodies_collide"] = [set(torso) == {"spine", "pelvis"} and
                                           all(v and v.get("collision") not in (None, "NO_COLLISION") for v in torso.values()),
                                           torso]
    chk["physics_extra_bodies_off_or_absent"] = [
        set(extra) <= {"head", "wrist_l", "wrist_r"} and
        all(v and v.get("collision") == "NO_COLLISION" and v.get("type") == "PHYS_TYPE_KINEMATIC" for v in extra.values()),
        extra]
    chk["physics_no_finger_bodies"] = [not any(b.startswith(("finger", "thumb")) for b in bodies), sorted(bodies)]
    rb["physics_clean_target_met"] = 1 <= len(bodies) <= 2 and set(bodies) <= {"spine", "pelvis"}
    # import data as saved (options alone are not proof)
    d = mesh.get_editor_property("asset_import_data")
    rb["import_data"] = {}
    if d is not None:
        for f in ("normal_import_method", "vertex_color_import_option", "import_morph_targets", "convert_scene",
                  "force_front_x_axis", "convert_scene_unit", "import_uniform_scale", "use_t0_as_ref_pose"):
            rb["import_data"][f] = str(_get(d, f, "n/a"))
        try:
            rb["import_data"]["source_files"] = [str(x) for x in d.extract_filenames()]
        except Exception:
            pass
    chk["import_normals_and_vcolor"] = [
        "IMPORT_NORMALS" in rb["import_data"].get("normal_import_method", "") and
        "REPLACE" in rb["import_data"].get("vertex_color_import_option", ""), rb["import_data"]]
    rb["pass"] = all(v[0] for v in chk.values())
    return rb


def run_part_a():
    rep = {"stage": "part_a", "preflight": _preflight(), "error": None}
    if not rep["preflight"]["ok"]:
        rep["error"] = "wrong editor or PIE"
        return rep
    exp = _expected()
    rep["expected_source"] = exp["source"]
    names = [SK, SKEL, PHYS, MASTER] + [MI % s for s in SLOTS]
    rep["collisions_outside_root"] = _collisions(names)
    if rep["collisions_outside_root"]:
        rep["error"] = "name collision outside the owned root"
        return rep
    rep["materials"] = create_materials()
    mesh, rep["import"] = import_mesh(exp)
    rep["bound"] = bind_materials(mesh)
    rep["socket_plan"] = socket_plan(mesh, exp)
    rep["bounds_extension"] = set_bounds(mesh)
    phys, rep["physics"] = build_physics(mesh)
    assets = [_load(_path(F_MAT, MASTER)), _load(_path(F_MAT, MASTER_TWO_SIDED))] + \
        [_load(_path(F_MAT, MI % s)) for s in SLOTS] + [mesh, mesh.skeleton, phys]
    rep["saved"] = save_owned(assets)
    rep["owned_assets"] = owned_assets()
    rep["material_readback"] = material_readback()
    rep["mesh_readback"] = mesh_readback(exp)
    return rep


# ------------------------------------------------------------------------------------------------------------ reload
def _hashes(pkg):
    out = {}
    for ext in (".uasset", ".uexp", ".ubulk"):
        f = _disk(pkg) + ext
        if os.path.isfile(f):
            with open(f, "rb") as fh:
                out[ext] = {"size": os.path.getsize(f), "sha256": hashlib.sha256(fh.read()).hexdigest()}
    return out


PRE_RESTART = os.path.join(ROOT_DIR, "review", "phase5", "readback_pre_restart.json")


def _diff(a, b, path=""):
    """Field-by-field differences between two JSON-like trees (list of 'path: a != b')."""
    out = []
    if isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a) | set(b)):
            out += _diff(a.get(k, "<absent>"), b.get(k, "<absent>"), "%s/%s" % (path, k))
    elif isinstance(a, list) and isinstance(b, list) and len(a) == len(b):
        for n, (x, y) in enumerate(zip(a, b)):
            out += _diff(x, y, "%s[%d]" % (path, n))
    elif a != b:
        out.append("%s: %s != %s" % (path, json.dumps(a, default=str)[:120], json.dumps(b, default=str)[:120]))
    return out


def prove_reload():
    """Cold-read proof (incident I-4: never unload/reload packages in the live editor). Run in a freshly started editor
    process, which loads every asset from disk; compare its readback field by field with the readback logged before the
    restart (review/phase5/readback_pre_restart.json) and record the disk hashes."""
    rep = {"stage": "reload", "preflight": _preflight(), "error": None,
           "method": "fresh editor process = cold disk read; readback compared with the pre-restart readback"}
    if not rep["preflight"]["ok"]:
        rep["error"] = "wrong editor or PIE"
        return rep
    exp = _expected()
    pkgs = owned_assets()
    rep["hashes"] = {p: _hashes(p) for p in pkgs}
    pre = json.load(open(PRE_RESTART, "r", encoding="utf-8"))
    now_mesh = json.loads(json.dumps(mesh_readback(exp), default=str))
    now_mat = json.loads(json.dumps(material_readback(), default=str))
    now_clips = json.loads(json.dumps(clip_readback(exp), default=str))
    old_mesh = pre["readback_a"]["mesh_readback"]
    old_mat = pre["readback_a"]["material_readback"]
    old_clips = pre["part_b_pass1"]["clip_readback"]
    # the pre-restart physics report printed rotations as struct reprs (memory addresses); compare numbers only
    for d in (old_mesh, now_mesh):
        for bodies in (d.get("physics_bodies") or {}).values():
            for e in bodies:
                e.pop("rotation", None)
    rep["diff_mesh"] = _diff(old_mesh, now_mesh)
    rep["diff_materials"] = _diff(old_mat, now_mat)
    rep["diff_clips"] = _diff({k: v for k, v in old_clips["clips"].items() if v is not None},
                              {k: v for k, v in now_clips["clips"].items() if k in old_clips["clips"] and
                               old_clips["clips"][k] is not None})
    rep["readings_match"] = not (rep["diff_mesh"] or rep["diff_materials"] or rep["diff_clips"])
    rep["mesh_pass"] = now_mesh.get("pass")
    return rep


# ------------------------------------------------------------------------------------------------------------ clips
def import_clips(exp):
    """Part B: 18 clips against the SKEL. Requires the clip FBXs."""
    out = {"clips": {}, "missing": []}
    skel = _load(_path(F_MESH, SKEL))
    if skel is None:
        raise RuntimeError("no %s - run part_a first" % SKEL)
    tasks, names = [], []
    for clip, c in sorted(exp["clips"].items()):
        fbx = c["fbx"] if os.path.isabs(c["fbx"]) else os.path.join(ANIMS, os.path.basename(c["fbx"]))
        if not os.path.isfile(fbx):
            out["missing"].append(fbx)
            continue
        opts = _anim_opts(skel)
        if c["samples"] == 1:
            # The legacy FBX importer rejects a zero-duration take (SkeletalMeshEdit.cpp ValidateAnimStack:
            # `AnimTimeSpan.GetDuration() <= 0 -> return false`), so a one-sample pose imports over the range 0..1: two
            # keys holding the same pose, length 1/30 s. The readback asserts the two keys are identical.
            d = opts.anim_sequence_import_data
            _set(d, "animation_length", unreal.FBXAnimationLengthImportType.FBXALIT_SET_RANGE)
            rng = unreal.Int32Interval()
            rng.set_editor_property("min", 0)
            rng.set_editor_property("max", 1)
            _set(d, "frame_import_range", rng)
        tasks.append(_task(fbx, F_ANIM, ANIM % clip, opts))
        names.append(clip)
    if out["missing"]:
        raise RuntimeError("missing clip FBXs: %s" % out["missing"])
    with _LegacyFbx() as flag:
        unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks(tasks)
    out["interchange_flag_before_after"] = [flag.was, flag.after]
    hover = _load(_path(F_ANIM, ANIM % ADDITIVE_REF))
    for clip in names:
        c = exp["clips"][clip]
        a = _load(_path(F_ANIM, ANIM % clip))
        if a is None:
            out["clips"][clip] = None
            continue
        AL.set_root_motion_enabled(a, False)
        AL.set_rate_scale(a, 1.0)
        _set(a, "loop", bool(c["loop"]))
        if clip in ADDITIVE:
            a.set_editor_property("additive_anim_type", unreal.AdditiveAnimationType.AAT_LOCAL_SPACE_BASE)
            a.set_editor_property("ref_pose_type", unreal.AdditiveBasePoseType.ABPT_ANIM_FRAME)
            a.set_editor_property("ref_pose_seq", hover)
            a.set_editor_property("ref_frame_index", 0)
        out["clips"][clip] = {"path": a.get_path_name(), "notifies": _set_notifies(a, c)}
    return out


def _set_notifies(anim, c):
    """Silent marker hooks: one notify track per marker, named <Marker>_Silent, holding one AnimNotify_PlaySound with no
    Sound (a silent, concrete native notify) at the marker frame. Deviation: 5.7.4 exposes no way to author a name-only
    skeleton notify (AnimSequenceBase.Notifies is protected; AddAnimationNotifyEventFromSource needs a notify object and
    resets NotifyName; Monolith add_notify is class-based too), so the marker identity is the TRACK name. Idempotent:
    a re-run empties the marker tracks before adding."""
    out = []
    try:
        tracks = [str(t) for t in AL.get_animation_notify_track_names(anim)]
        fps = float(c.get("fps", 30))
        for marker, frame in sorted(c["markers"].items()):
            tr = "%s_Silent" % marker
            if tr in tracks:
                AL.remove_animation_notify_events_by_track(anim, tr)
            else:
                AL.add_animation_notify_track(anim, tr)
            n = AL.add_animation_notify_event(anim, tr, float(frame) / fps, unreal.AnimNotify_PlaySound)
            out.append([tr, frame, n.get_class().get_name() if n else None])
    except Exception as e:
        out.append("error: %s" % _err(e))
    return out


def _notify_readback(a):
    out = []
    for tr in AL.get_animation_notify_track_names(a):
        for e in AL.get_animation_notify_events_for_track(a, tr):
            n = e.get_editor_property("notify")
            snd = n.get_editor_property("sound") if n is not None and isinstance(n, unreal.AnimNotify_PlaySound) else None
            out.append([str(tr), round(AL.get_anim_notify_event_trigger_time(e), 4),
                        n.get_class().get_name() if n else None, snd.get_name() if snd else None])
    return out


TIP_BONES = ("finger_01b_l", "finger_02b_l", "finger_03b_l", "finger_04b_l", "thumb_b_l", "ear_tip_l", "foot_l",
             "finger_01b_r", "finger_02b_r", "finger_03b_r", "finger_04b_r", "thumb_b_r", "ear_tip_r", "foot_r", "jaw")


def _tail_offsets(exp, skel):
    """Bone-local offset of each tip bone's tail (bind pose), so animated tips = bone transform x offset."""
    tails = {}
    m = exp.get("manifest") or {}
    side = json.load(open(os.path.join(EXPORT, "validation", "expected.json"), "r", encoding="utf-8"))
    for b in side["bones"]:
        if b["name"] in TIP_BONES and b.get("tail_ue_cm"):
            tails[b["name"]] = b["tail_ue_cm"]
    world = _bone_world(skel)
    return {n: world[n].inverse_transform_location(unreal.Vector(*t)) for n, t in tails.items()}


def clip_extents(exp):
    """Component-space extents of every bone head and every tip-bone tail over every frame of every clip (additive banks
    evaluated as full poses). The mesh reaches past the bone tails (membrane, claws), so this is a lower bound."""
    skel = _load(_path(F_MESH, SKEL))
    offs = _tail_offsets(exp, skel)
    lo, hi, per = [1e9] * 3, [-1e9] * 3, {}
    for clip, c in sorted(exp["clips"].items()):
        a = _load(_path(F_ANIM, ANIM % clip))
        if a is None:
            continue
        opt = unreal.AnimPoseEvaluationOptions()
        _set(opt, "retrieve_additive_as_full_pose", True)
        _set(opt, "extract_root_motion", False)
        clo, chi = [1e9] * 3, [-1e9] * 3
        for f in range(0, c["frames"][1] - c["frames"][0] + 1):
            pose = unreal.AnimPoseExtensions.get_anim_pose_at_frame(a, f, opt)
            pts = []
            for n in unreal.AnimPoseExtensions.get_bone_names(pose):
                w = unreal.AnimPoseExtensions.get_bone_pose(pose, n, unreal.AnimPoseSpaces.WORLD)
                pts.append(w.translation)
                if str(n) in offs:
                    pts.append(w.transform_location(offs[str(n)]))
            for p in pts:
                for k, v in enumerate((p.x, p.y, p.z)):
                    clo[k], chi[k] = min(clo[k], v), max(chi[k], v)
        per[clip] = {"min": [round(x, 2) for x in clo], "max": [round(x, 2) for x in chi]}
        lo = [min(x, y) for x, y in zip(lo, clo)]
        hi = [max(x, y) for x, y in zip(hi, chi)]
    mesh = _load(_path(F_MESH, SK))
    b = mesh.get_bounds()
    blo, bhi = b.origin - b.box_extent, b.origin + b.box_extent
    blo, bhi = [blo.x, blo.y, blo.z], [bhi.x, bhi.y, bhi.z]
    margin = [min(l - bl for l, bl in zip(lo, blo)), min(bh - h for h, bh in zip(hi, bhi))]
    return {"union": {"min": [round(x, 2) for x in lo], "max": [round(x, 2) for x in hi]}, "per_clip": per,
            "mesh_bounds": {"min": [round(x, 2) for x in blo], "max": [round(x, 2) for x in bhi]},
            "min_margin_cm": round(min(margin), 2)}


def clip_readback(exp):
    rb = {"clips": {}, "checks": {}}
    skel_path = _path(F_MESH, SKEL)
    for clip, c in sorted(exp["clips"].items()):
        a = _load(_path(F_ANIM, ANIM % clip))
        if a is None:
            rb["clips"][clip] = None
            rb["checks"][clip] = [False, "missing"]
            continue
        r = {"num_frames": AL.get_num_frames(a), "length_s": round(AL.get_sequence_length(a), 5)}
        try:
            r["num_keys"] = AL.get_num_keys(a)
        except Exception:
            pass
        tracks = [str(t) for t in AL.get_animation_track_names(a)]
        r["track_count"] = len(tracks)
        r["skeleton"] = a.get_editor_property("skeleton").get_path_name()
        r["loop"] = _get(a, "loop")
        r["root_motion"] = AL.is_root_motion_enabled(a)
        r["rate_scale"] = AL.get_rate_scale(a)
        r["additive"] = [str(AL.get_additive_animation_type(a)), str(AL.get_additive_base_pose_type(a)),
                         (_get(a, "ref_pose_seq").get_name() if _get(a, "ref_pose_seq") else None),
                         _get(a, "ref_frame_index")]
        r["notifies"] = _notify_readback(a)
        last = c["frames"][1] - c["frames"][0]
        rs = []
        for k in range(5):
            f = int(round(last * k / 4.0))
            t = AL.get_bone_pose_for_frame(a, "root", f, False)
            rs.append({"f": f, "t": _v(t.translation, 5), "q": _q(t.rotation)})
        r["root_samples"] = rs
        root_still = all(max(abs(x) for x in s["t"]) < 1e-3 and abs(abs(s["q"][3]) - 1) < 1e-5 for s in rs)
        seam = None
        if c["loop"] and last > 0:
            worst = 0.0
            for bn in tracks:
                p0 = AL.get_bone_pose_for_frame(a, bn, 0, False)
                p1 = AL.get_bone_pose_for_frame(a, bn, last, False)
                dq = min(sum((x - y) ** 2 for x, y in zip(_q(p0.rotation), _q(p1.rotation))),
                         sum((x + y) ** 2 for x, y in zip(_q(p0.rotation), _q(p1.rotation))))
                worst = max(worst, math.sqrt(dq), (p0.translation - p1.translation).length())
            seam = round(worst, 6)
        r["loop_seam_max_delta"] = seam
        if c["samples"] == 1 or clip in ADDITIVE:
            worst = 0.0
            for bn in tracks:
                p0 = AL.get_bone_pose_for_frame(a, bn, 0, False)
                p1 = AL.get_bone_pose_for_frame(a, bn, 1, False)
                dq = min(sum((x - y) ** 2 for x, y in zip(_q(p0.rotation), _q(p1.rotation))),
                         sum((x + y) ** 2 for x, y in zip(_q(p0.rotation), _q(p1.rotation))))
                worst = max(worst, math.sqrt(dq), (p0.translation - p1.translation).length())
            r["single_pose_key_delta"] = round(worst, 7)
        want_markers = sorted(["%s_Silent" % m, round(f / float(c["fps"]), 4)] for m, f in c["markers"].items())
        if c["samples"] == 1 or clip in ADDITIVE:
            # bank poses: 2 keys holding one pose (re-exported as frames 0..1, or padded by SET_RANGE from 1 sample)
            frames_ok = r.get("num_keys") == 2 and r.get("single_pose_key_delta", 1) < 1e-5
            length_ok = abs(r["length_s"] - 1.0 / float(c["fps"])) < 1e-3
        else:
            frames_ok = r.get("num_keys", r["num_frames"] + 1) == c["samples"] and r["num_frames"] == c["samples"] - 1
            length_ok = abs(r["length_s"] - (c["samples"] - 1) / float(c["fps"])) < 1e-3
        ok = {"frames": frames_ok, "length": length_ok,
              "tracks_42": r["track_count"] == 42, "skeleton": r["skeleton"] == skel_path,
              "root_stationary": root_still, "loop_flag": bool(r["loop"]) == c["loop"],
              "no_root_motion": not r["root_motion"],
              "seam": seam is None or seam < 1e-3,
              "notifies": sorted([n[0], n[1]] for n in r["notifies"]) == want_markers and
              all(n[2] == "AnimNotify_PlaySound" and n[3] is None for n in r["notifies"])}
        if clip in ADDITIVE:
            ok["additive"] = "LOCAL_SPACE_BASE" in r["additive"][0] and "ANIM_FRAME" in r["additive"][1] and \
                r["additive"][2] == ANIM % ADDITIVE_REF and r["additive"][3] == 0
        r["ok"] = ok
        rb["clips"][clip] = r
        rb["checks"][clip] = [all(ok.values()), [k for k, v in ok.items() if not v]]
    try:
        rb["extents"] = clip_extents(exp)
        # bone tails must sit >= 2 cm inside the bounds (membrane/claws reach a little past the tails)
        rb["checks"]["bounds_contain_clip_extents"] = [rb["extents"]["min_margin_cm"] >= 2.0, rb["extents"]["min_margin_cm"]]
    except Exception as e:
        rb["checks"]["bounds_contain_clip_extents"] = [False, _err(e)]
    rb["pass"] = all(v[0] for v in rb["checks"].values()) and len(rb["checks"]) == 19
    return rb


def run_part_b():
    rep = {"stage": "part_b", "preflight": _preflight(), "error": None}
    if not rep["preflight"]["ok"]:
        rep["error"] = "wrong editor or PIE"
        return rep
    exp = _expected()
    rep["expected_source"] = exp["source"]
    rep["collisions_outside_root"] = _collisions([ANIM % c for c in exp["clips"]])
    if rep["collisions_outside_root"]:
        rep["error"] = "name collision outside the owned root"
        return rep
    rep["import"] = import_clips(exp)
    rep["saved"] = save_owned([_load(_path(F_ANIM, ANIM % c)) for c in exp["clips"]])
    rep["owned_assets"] = owned_assets()
    rep["clip_readback"] = clip_readback(exp)
    return rep


# ------------------------------------------------------------------------------------------------------------ entry
def _strip(rep):
    s = json.loads(json.dumps(rep, default=str))
    mr = s.get("mesh_readback") or {}
    mr.pop("bone_order", None)
    return s


def main(stage):
    t0 = time.time()
    try:
        if stage == "part_a":
            rep = run_part_a()
            key = "part_a_pass1"
        elif stage == "reimport_a":
            rep = run_part_a()
            rep["stage"] = "reimport_a"
            key = "part_a_reimport"
        elif stage == "socket_plan":
            exp = _expected()
            rep = {"stage": "socket_plan", "preflight": _preflight(),
                   "socket_plan": socket_plan(_load(_path(F_MESH, SK)), exp)}
            key = "socket_plan"
        elif stage == "physics":
            mesh = _load(_path(F_MESH, SK))
            phys, prep = build_physics(mesh)
            rep = {"stage": "physics", "preflight": _preflight(), "physics": prep,
                   "saved": save_owned([phys, mesh]) if _preflight()["ok"] else []}
            key = "physics"
        elif stage == "bounds":
            mesh = _load(_path(F_MESH, SK))
            rep = {"stage": "bounds", "preflight": _preflight(), "bounds_extension": set_bounds(mesh),
                   "saved": save_owned([mesh])}
            key = "bounds"
        elif stage == "save_skeleton":
            rep = {"stage": "save_skeleton", "saved": save_owned([_load(_path(F_MESH, SKEL))])}
            key = "save_skeleton"
        elif stage == "readback":
            exp = _expected()
            rep = {"stage": "readback", "preflight": _preflight(), "material_readback": material_readback(),
                   "mesh_readback": mesh_readback(exp), "owned_assets": owned_assets()}
            key = "readback_a"
        elif stage == "reload":
            rep = prove_reload()
            key = "reload_a"
        elif stage in ("part_b", "reimport_b"):
            rep = run_part_b()
            key = "part_b_pass1" if stage == "part_b" else "part_b_reimport"
        else:
            raise ValueError("unknown stage %s" % stage)
    except Exception as e:
        import traceback
        rep = {"stage": stage, "error": _err(e), "trace": traceback.format_exc()}
        key = stage + "_error"
    rep["seconds"] = round(time.time() - t0, 2)
    rep = json.loads(json.dumps(rep, default=str))
    _merge_readback(key, rep)
    print("CELLAR_BAT_IMPORT " + json.dumps(_strip(rep)))
    passed = rep.get("error") is None and all(
        (rep.get(k) or {}).get("pass", True) for k in ("mesh_readback", "clip_readback"))
    print("CELLAR_BAT_OK" if passed else "CELLAR_BAT_FAIL")
    return rep


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "readback")
