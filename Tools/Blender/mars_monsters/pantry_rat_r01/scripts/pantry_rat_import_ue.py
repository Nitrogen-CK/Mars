"""Pantry Rat R01 - candidate-only Unreal importer + readback (Phase 2). Runs inside the editor's Python through Monolith
`editor_query run_python` ({"command": "<this file> <stage>", "mode": "execute_file", "unattended": true}), never in PIE.
Pattern: Tools/Blender/mars_monsters/cellar_bat_r01/scripts/cellar_bat_import_ue.py (legacy FBX importer with the
Interchange FBX flag off in a finally, new dedicated skeleton, slots, clips with loop flags, save_loaded_asset per asset).

Writes only under /Game/ArtCandidates/PantryRat/R01/{Meshes,Materials,Animation,Props} and saves only the assets it
creates (EditorAssetLibrary.save_loaded_asset; never Save All). Never calls SkeletalMesh.add_socket (incident I-3 of the
cellar bat): sockets go on the skeleton through Monolith `animation_query add_socket` with the values `socket_plan`
prints. Never unloads or reloads packages (incident I-4).

Stages (argv[1]):
  part_a       materials (rat MIs on the generated MarsPantryRatSurface master, an opaque prop master + MIs), bind mesh +
               new SKEL, slot materials (EyePatch = the raw MarsPantryRatEyePlate master), den / plate / cheese statics
               with collision, save
  socket_plan  bone-relative Carry_Mouth / Carry_Drag transforms for Monolith add_socket (read only)
  part_b       the 34 clips against the SKEL: loop flags, no root motion, EarFlick / TailSettle additive vs IdleBreath f0
  readback     everything (no writes) -> export/unreal_readback.json
Prints PANTRY_RAT_OK / PANTRY_RAT_FAIL.
"""
import json
import math
import os
import sys
import time
import traceback

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(HERE)
EXPORT = os.path.join(ROOT_DIR, "export")
ANIMS = os.path.join(EXPORT, "anims")
READBACK = os.path.join(EXPORT, "unreal_readback.json")
MANIFEST = os.path.join(EXPORT, "PantryRat_R01_Manifest.json")
PROJECT = "D:/Repositories/CkRepos/Orion/Mars.uproject"
FBX_FLAG = "Interchange.FeatureFlags.Import.FBX"

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary
AL = unreal.AnimationLibrary

F_ROOT = "/Game/ArtCandidates/PantryRat/R01"
F_MESH, F_MAT, F_ANIM, F_PROPS = F_ROOT + "/Meshes", F_ROOT + "/Materials", F_ROOT + "/Animation", F_ROOT + "/Props"
OWNED = (F_MESH, F_MAT, F_ANIM, F_PROPS)
SK, SKEL = "PantryRat_R01_Mars_SK", "PantryRat_R01_Mars_SKEL"
MI = "PantryRat_R01_%s_Mars_MI"
PROP_M = "PantryRat_R01_Prop_Mars_M"
ANIM = "PantryRat_R01_%s_Mars_ANIM"
SURFACE_MASTER = "/Game/Mars/Materials/GeneratedLooks/M_CkUsf_Look_MarsPantryRatSurface"
EYE_MASTER = "/Game/Mars/Materials/GeneratedLooks/M_CkUsf_Look_MarsPantryRatEyePlate"
SHARED_EYE_MASTER = "/Game/Mars/Materials/GeneratedLooks/M_CkUsf_Look_MarsEyePlate"
SLOTS = ("Body", "Pink", "Belly", "Wood", "Harness", "EyePatch")


def _lin(h):
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


RAT_COLORS = {"Body": "5A4553", "Pink": "D97B86", "Belly": "E9D5C1", "Wood": "A8683B", "Harness": "6E4327"}
PROP_COLORS = {"Stone": "8C8478", "Void": "050505", "Rind": "D9842B", "Flesh": "F2E6C8"}
STATICS = {   # asset name -> (fbx, slot -> MI name or master, collision)
    "PantryRat_R01_Den_Mars_SM": ("PantryRat_R01_Den_Mars_SM.fbx", "complex_as_simple"),
    "PantryRat_R01_DenEyePlate_Mars_SM": ("PantryRat_R01_DenEyePlate_Mars_SM.fbx", "box"),
    "PantryRat_R01_Cheese_Mars_SM": ("PantryRat_R01_Cheese_Mars_SM.fbx", "box"),
}
ADDITIVE = ("EarFlick", "TailSettle")
ADDITIVE_REF = "IdleBreath"
WITHERS = (35.3, 0.5)


def _err(e):
    return "%s: %s" % (type(e).__name__, e)


def _path(folder, name):
    return "%s/%s.%s" % (folder, name, name)


def _load(p):
    try:
        return unreal.load_asset(p) if EAL.does_asset_exist(p.split(".")[0]) else None
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


def _preflight():
    proj = unreal.Paths.convert_relative_path_to_full(unreal.Paths.get_project_file_path())
    pie = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).is_in_play_in_editor()
    return {"project": proj, "pie": pie, "engine": unreal.SystemLibrary.get_engine_version(),
            "ok": proj == PROJECT and not pie}


def _manifest():
    with open(MANIFEST, "r", encoding="utf-8") as fh:
        return json.load(fh)


def _ar_assets(root):
    flt = unreal.ARFilter(package_paths=[root], recursive_paths=True)
    return unreal.AssetRegistryHelpers.get_asset_registry().get_assets(flt)


def owned_assets():
    return sorted({str(a.package_name) for f in OWNED for a in _ar_assets(f)})


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


def _collisions(names):
    want, hits = set(names), {}
    for a in _ar_assets("/Game"):
        n = str(a.asset_name)
        if n in want and not str(a.package_name).startswith(F_ROOT + "/"):
            hits.setdefault(n, []).append(str(a.package_name))
    return hits


# ------------------------------------------------------------------------------------------------------- importer
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


def _common_data(d):
    for prop, value in (("convert_scene", True), ("force_front_x_axis", False), ("convert_scene_unit", False),
                        ("import_uniform_scale", 1.0), ("import_translation", unreal.Vector(0.0, 0.0, 0.0)),
                        ("import_rotation", unreal.Rotator(roll=0.0, pitch=0.0, yaw=0.0))):
        _set(d, prop, value)


def _sk_opts(skeleton):
    o = _base_opts()
    o.import_mesh, o.import_as_skeletal, o.import_animations = True, True, False
    o.mesh_type_to_import = unreal.FBXImportType.FBXIT_SKELETAL_MESH
    o.skeleton = skeleton
    o.create_physics_asset = False
    d = o.skeletal_mesh_import_data
    _common_data(d)
    for prop, value in (("normal_import_method", unreal.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS),
                        ("vertex_color_import_option", unreal.VertexColorImportOption.REPLACE),
                        ("import_morph_targets", False), ("use_t0_as_ref_pose", False),
                        ("import_meshes_in_bone_hierarchy", False), ("update_skeleton_reference_pose", False)):
        _set(d, prop, value)
    return o


def _sm_opts():
    o = _base_opts()
    o.import_mesh, o.import_as_skeletal, o.import_animations = True, False, False
    o.mesh_type_to_import = unreal.FBXImportType.FBXIT_STATIC_MESH
    d = o.static_mesh_import_data
    _common_data(d)
    for prop, value in (("combine_meshes", True), ("auto_generate_collision", False), ("generate_lightmap_u_vs", True),
                        ("normal_import_method", unreal.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS),
                        ("vertex_color_import_option", unreal.VertexColorImportOption.REPLACE)):
        _set(d, prop, value)
    return o


def _anim_opts(skeleton):
    o = _base_opts()
    o.import_mesh, o.import_as_skeletal, o.import_animations = False, False, True
    o.mesh_type_to_import = unreal.FBXImportType.FBXIT_ANIMATION
    o.skeleton = skeleton
    d = o.anim_sequence_import_data
    _common_data(d)
    for prop, value in (("import_bone_tracks", True), ("remove_redundant_keys", False),
                        ("animation_length", unreal.FBXAnimationLengthImportType.FBXALIT_EXPORTED_TIME),
                        ("use_default_sample_rate", False), ("custom_sample_rate", 30),
                        ("snap_to_closest_frame_boundary", True), ("import_meshes_in_bone_hierarchy", False),
                        ("import_custom_attribute", False), ("delete_existing_morph_target_curves", True),
                        ("do_not_import_curve_with_zero", True), ("preserve_local_transform", False)):
        _set(d, prop, value)
    return o


# ------------------------------------------------------------------------------------------------------- materials
def _new_or_load(name, folder, cls, factory):
    p = _path(folder, name)
    if EAL.does_asset_exist(p.split(".")[0]):
        a = _load(p)
        if not isinstance(a, cls):
            raise RuntimeError("%s exists but is a %s" % (p, a.get_class().get_name() if a else None))
        return a, False
    return unreal.AssetToolsHelpers.get_asset_tools().create_asset(name, folder, cls, factory), True


def _build_prop_master(m):
    """Opaque lit: BaseColor = Color (vector param), Roughness 0.8, Specular 0.3. Food and stone never fade."""
    for _ in range(8):
        if MEL.get_num_material_expressions(m) == 0:
            break
        MEL.delete_all_material_expressions(m)
    E = MEL.create_material_expression
    col = E(m, unreal.MaterialExpressionVectorParameter, -500, 0)
    col.set_editor_property("parameter_name", "Color")
    col.set_editor_property("default_value", unreal.LinearColor(r=0.5, g=0.5, b=0.5, a=1.0))
    MEL.connect_material_property(col, "", unreal.MaterialProperty.MP_BASE_COLOR)
    for prop, val, y in ((unreal.MaterialProperty.MP_ROUGHNESS, 0.8, 200), (unreal.MaterialProperty.MP_SPECULAR, 0.3, 300)):
        c = E(m, unreal.MaterialExpressionConstant, -500, y)
        c.set_editor_property("r", val)
        MEL.connect_material_property(c, "", prop)
    MEL.recompile_material(m)


def create_materials():
    out = {"rat": {}, "props": {}}
    surface = _load(SURFACE_MASTER)
    eye = _load(EYE_MASTER)
    if surface is None or eye is None:
        raise RuntimeError("generated rat masters missing (run Ck_Usf_GenerateLooks MarsPantryRatSurface / "
                           "MarsPantryRatEyePlate)")
    for slot, hx in RAT_COLORS.items():
        mi, new = _new_or_load(MI % slot, F_MAT, unreal.MaterialInstanceConstant,
                               unreal.MaterialInstanceConstantFactoryNew())
        MEL.set_material_instance_parent(mi, surface)
        c = _lin(hx)
        MEL.set_material_instance_vector_parameter_value(mi, "Color", unreal.LinearColor(r=c[0], g=c[1], b=c[2], a=1.0))
        MEL.update_material_instance(mi)
        out["rat"][slot] = {"path": mi.get_path_name(), "new": new, "srgb": "#" + hx}
    pm, new = _new_or_load(PROP_M, F_MAT, unreal.Material, unreal.MaterialFactoryNew())
    _build_prop_master(pm)
    out["prop_master"] = {"path": pm.get_path_name(), "new": new}
    for slot, hx in PROP_COLORS.items():
        mi, new = _new_or_load(MI % slot, F_MAT, unreal.MaterialInstanceConstant,
                               unreal.MaterialInstanceConstantFactoryNew())
        MEL.set_material_instance_parent(mi, pm)
        c = _lin(hx)
        MEL.set_material_instance_vector_parameter_value(mi, "Color", unreal.LinearColor(r=c[0], g=c[1], b=c[2], a=1.0))
        MEL.update_material_instance(mi)
        out["props"][slot] = {"path": mi.get_path_name(), "new": new, "srgb": "#" + hx}
    return out


# ------------------------------------------------------------------------------------------------------- meshes
def import_mesh():
    out = {}
    skel = _load(_path(F_MESH, SKEL))
    with _LegacyFbx() as flag:
        unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks(
            [_task(os.path.join(EXPORT, "PantryRat_R01_Mars_SK.fbx"), F_MESH, SK, _sk_opts(skel))])
    out["interchange_flag_before_after"] = [flag.was, flag.after]
    mesh = _load(_path(F_MESH, SK))
    if mesh is None:
        raise RuntimeError("bind mesh import produced nothing")
    sk_path = mesh.skeleton.get_path_name().split(".")[0]
    if not sk_path.endswith("/" + SKEL):
        if EAL.does_asset_exist(F_MESH + "/" + SKEL):
            raise RuntimeError("mesh got skeleton %s while %s exists" % (sk_path, SKEL))
        EAL.rename_asset(sk_path, "%s/%s" % (F_MESH, SKEL))
    out["skeleton"] = mesh.skeleton.get_path_name()
    return mesh, out


def bind_materials(mesh):
    mats = list(mesh.materials)
    bound = {}
    for i, sm in enumerate(mats):
        slot = str(sm.material_slot_name)
        mat = _load(EYE_MASTER) if slot == "EyePatch" else _load(_path(F_MAT, MI % slot))
        if mat is not None:
            sm.set_editor_property("material_interface", mat)
            mats[i] = sm
        bound[slot] = mat.get_path_name() if mat else None
    mesh.set_editor_property("materials", mats)
    return bound


def import_statics():
    out = {}
    tasks = [_task(os.path.join(EXPORT, fbx), F_PROPS, name, _sm_opts()) for name, (fbx, _c) in STATICS.items()]
    with _LegacyFbx() as flag:
        unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks(tasks)
    out["interchange_flag_before_after"] = [flag.was, flag.after]
    sel = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
    for name, (fbx, coll) in STATICS.items():
        sm = _load(_path(F_PROPS, name))
        if sm is None:
            out[name] = None
            continue
        mats = list(sm.static_materials)
        for i, m in enumerate(mats):
            slot = str(m.material_slot_name)
            mat = _load(SHARED_EYE_MASTER) if slot == "EyePatch" else _load(_path(F_MAT, MI % slot))
            if mat is not None:
                m.set_editor_property("material_interface", mat)
                mats[i] = m
        sm.set_editor_property("static_materials", mats)
        if coll == "box":
            sel.remove_collisions(sm)
            sel.add_simple_collisions(sm, unreal.ScriptCollisionShapeType.BOX)
        else:
            sel.remove_collisions(sm)
            bs = sm.get_editor_property("body_setup")
            bs.set_editor_property("collision_trace_flag", unreal.CollisionTraceFlag.CTF_USE_COMPLEX_AS_SIMPLE)
        out[name] = {"path": sm.get_path_name(), "slots": [str(m.material_slot_name) for m in sm.static_materials],
                     "collision": coll}
    return out


def save_owned(assets):
    saved = []
    for a in assets:
        if a is None:
            continue
        pn = a.get_path_name()
        if any(pn.startswith(f + "/") for f in OWNED) and EAL.save_loaded_asset(a, False):
            saved.append(pn)
    return saved


def run_part_a():
    rep = {"stage": "part_a", "preflight": _preflight(), "error": None}
    if not rep["preflight"]["ok"]:
        rep["error"] = "wrong editor or PIE"
        return rep
    names = [SK, SKEL, PROP_M] + [MI % s for s in list(RAT_COLORS) + list(PROP_COLORS)] + list(STATICS)
    rep["collisions_outside_root"] = _collisions(names)
    if rep["collisions_outside_root"]:
        rep["error"] = "name collision outside the owned root"
        return rep
    rep["materials"] = create_materials()
    mesh, rep["import"] = import_mesh()
    rep["bound"] = bind_materials(mesh)
    rep["statics"] = import_statics()
    assets = [_load(_path(F_MAT, MI % s)) for s in list(RAT_COLORS) + list(PROP_COLORS)] + \
        [_load(_path(F_MAT, PROP_M)), mesh, mesh.skeleton] + [_load(_path(F_PROPS, n)) for n in STATICS]
    rep["saved"] = save_owned(assets)
    rep["owned_assets"] = owned_assets()
    return rep


# ------------------------------------------------------------------------------------------------------- sockets
def _bone_world(skel):
    pose = unreal.AnimPoseExtensions.get_reference_pose(skel)
    return {str(n): unreal.AnimPoseExtensions.get_bone_pose(pose, n, unreal.AnimPoseSpaces.WORLD)
            for n in unreal.AnimPoseExtensions.get_bone_names(pose)}


def socket_plan():
    man = _manifest()
    mesh = _load(_path(F_MESH, SK))
    world = _bone_world(mesh.skeleton)
    out = {}
    for name, s in man["sockets"].items():
        bw = world[s["bone"]]
        rot = unreal.MathLibrary.make_rot_from_xz(unreal.Vector(*s["component_axis_x"]), unreal.Vector(*s["component_axis_z"]))
        st = unreal.Transform(location=unreal.Vector(*s["component_cm"]), rotation=rot, scale=unreal.Vector(1, 1, 1))
        rel = unreal.MathLibrary.make_relative_transform(st, bw)
        rr = rel.rotation.rotator()
        loc = rel.translation
        rx = rel.rotation.get_axis_x()
        rz = rel.rotation.get_axis_z()
        pl, px, pz = s["ue_relative_location_cm_predicted"], s["ue_relative_axis_x_predicted"], s["ue_relative_axis_z_predicted"]
        out[name] = {"bone": s["bone"], "location": _v(loc), "rotation_pyr": [round(rr.pitch, 4), round(rr.yaw, 4), round(rr.roll, 4)],
                     "relative_axis_x": _v(rx, 6), "relative_axis_z": _v(rz, 6),
                     "predicted_location": pl, "predicted_axis_x": px, "predicted_axis_z": pz,
                     "predicted_location_err_cm": round(math.sqrt(sum((a - b) ** 2 for a, b in zip(_v(loc), pl))), 5),
                     "predicted_axis_err": round(max(max(abs(a - b) for a, b in zip(_v(rx, 6), px)),
                                                     max(abs(a - b) for a, b in zip(_v(rz, 6), pz))), 6),
                     "exists": mesh.find_socket(name) is not None}
    return out


# ------------------------------------------------------------------------------------------------------- clips
def import_clips():
    man = _manifest()
    skel = _load(_path(F_MESH, SKEL))
    if skel is None:
        raise RuntimeError("no %s - run part_a first" % SKEL)
    tasks, names = [], []
    for clip, c in man["clips"].items():
        fbx = os.path.join(ROOT_DIR, c["file"])
        if not os.path.isfile(fbx):
            raise RuntimeError("missing %s" % fbx)
        tasks.append(_task(fbx, F_ANIM, ANIM % clip, _anim_opts(skel)))
        names.append(clip)
    with _LegacyFbx() as flag:
        unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks(tasks)
    out = {"interchange_flag_before_after": [flag.was, flag.after], "clips": {}}
    ref = _load(_path(F_ANIM, ANIM % ADDITIVE_REF))
    for clip in names:
        a = _load(_path(F_ANIM, ANIM % clip))
        if a is None:
            out["clips"][clip] = None
            continue
        AL.set_root_motion_enabled(a, False)
        AL.set_rate_scale(a, 1.0)
        _set(a, "loop", bool(man["clips"][clip]["loop"]))
        if clip in ADDITIVE:
            a.set_editor_property("additive_anim_type", unreal.AdditiveAnimationType.AAT_LOCAL_SPACE_BASE)
            a.set_editor_property("ref_pose_type", unreal.AdditiveBasePoseType.ABPT_ANIM_FRAME)
            a.set_editor_property("ref_pose_seq", ref)
            a.set_editor_property("ref_frame_index", 0)
        out["clips"][clip] = a.get_path_name()
    return out


def run_part_b():
    rep = {"stage": "part_b", "preflight": _preflight(), "error": None}
    if not rep["preflight"]["ok"]:
        rep["error"] = "wrong editor or PIE"
        return rep
    man = _manifest()
    rep["collisions_outside_root"] = _collisions([ANIM % c for c in man["clips"]])
    if rep["collisions_outside_root"]:
        rep["error"] = "name collision outside the owned root"
        return rep
    rep["import"] = import_clips()
    rep["saved"] = save_owned([_load(_path(F_ANIM, ANIM % c)) for c in man["clips"]])
    return rep


# ------------------------------------------------------------------------------------------------------- readback
def _dist(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def readback():
    man = _manifest()
    exp_anims = json.load(open(os.path.join(ANIMS, "expected_anims.json"), "r", encoding="utf-8"))
    rb = {"checks": {}, "preflight": _preflight()}
    chk = rb["checks"]
    mesh = _load(_path(F_MESH, SK))
    if mesh is None:
        chk["mesh_exists"] = [False, None]
        rb["pass"] = False
        return rb
    skel = mesh.skeleton
    rb["skeleton"] = skel.get_path_name()
    chk["dedicated_skeleton"] = [rb["skeleton"] == _path(F_MESH, SKEL), rb["skeleton"]]
    ib = mesh.get_imported_bounds()
    lo, hi = ib.origin - ib.box_extent, ib.origin + ib.box_extent
    rb["imported_bounds"] = {"min": _v(lo), "max": _v(hi)}
    b0 = man["bind"]["bounds_ue_cm"]
    err = max(max(abs(a - b) for a, b in zip(_v(lo), b0["min"])), max(abs(a - b) for a, b in zip(_v(hi), b0["max"])))
    chk["bind_bounds_match_blender"] = [err <= 0.1, round(err, 4)]
    chk["nose_at_max_x"] = [abs(hi.x - man["bind"]["nose_point_ue_cm"][0]) <= 0.1 and hi.x > abs(lo.x) * 0.3,
                            {"max_x": round(hi.x, 4), "blender_nose_x": man["bind"]["nose_point_ue_cm"][0]}]
    pose = unreal.AnimPoseExtensions.get_reference_pose(skel)
    names = [str(n) for n in unreal.AnimPoseExtensions.get_bone_names(pose)]
    parents = {}
    try:
        sm = unreal.SkeletonModifier()
        sm.set_skeletal_mesh(mesh)
        for n in names:
            p = str(sm.get_parent_name(n))
            parents[n] = None if p in ("None", "") else p
    except Exception as e:
        rb["parents_error"] = _err(e)
    want = {b["name"]: b["parent"] for b in man["bones"]}
    chk["bone_count_26"] = [len(names) == 26, len(names)]
    wrong = [n for n in want if parents.get(n, "<missing>") != want[n]]
    chk["parents_exact"] = [not wrong, wrong]
    root = unreal.AnimPoseExtensions.get_bone_pose(pose, "root", unreal.AnimPoseSpaces.LOCAL)
    chk["root_identity"] = [abs(abs(root.rotation.w) - 1) < 1e-5 and root.translation.length() < 1e-4,
                            {"t": _v(root.translation, 6), "q": [root.rotation.x, root.rotation.y, root.rotation.z, root.rotation.w]}]
    worst_s, worst_h = 0.0, 0.0
    heads = {b["name"]: b["head_ue_cm"] for b in man["bones"]}
    world = _bone_world(skel)
    for n in names:
        s = unreal.AnimPoseExtensions.get_bone_pose(pose, n, unreal.AnimPoseSpaces.LOCAL).scale3d
        worst_s = max(worst_s, abs(s.x - 1), abs(s.y - 1), abs(s.z - 1))
        worst_h = max(worst_h, _dist(_v(world[n].translation, 6), heads[n]))
    chk["bone_scales_1"] = [worst_s < 1e-5, round(worst_s, 7)]
    chk["bone_heads_match_blender"] = [worst_h <= 0.1, round(worst_h, 5)]
    chk["handedness_ear_l_minus_y"] = [world["ear_l"].translation.y < 0 < world["ear_r"].translation.y,
                                       [round(world["ear_l"].translation.y, 3), round(world["ear_r"].translation.y, 3)]]
    slots = [str(m.material_slot_name) for m in mesh.materials]
    mats = [m.material_interface.get_path_name() if m.material_interface else None for m in mesh.materials]
    rb["slots"] = list(zip(slots, mats))
    chk["slots_in_order"] = [slots == list(SLOTS), slots]
    chk["slot_materials"] = [mats[:5] == [_path(F_MAT, MI % s) for s in SLOTS[:5]] and
                             (mats[5] or "").split(".")[0] == EYE_MASTER, mats]
    # MI parameters
    mi_r = {}
    for slot in RAT_COLORS:
        mi = _load(_path(F_MAT, MI % slot))
        c = MEL.get_material_instance_vector_parameter_value(mi, "Color")
        f = MEL.get_material_instance_scalar_parameter_value(mi, "FadeAlpha")
        mi_r[slot] = {"parent": mi.get_editor_property("parent").get_path_name(), "Color": [round(c.r, 4), round(c.g, 4), round(c.b, 4)],
                      "FadeAlpha_default": round(f, 4)}
    rb["rat_mis"] = mi_r
    chk["rat_mis_on_surface_master_with_fadealpha"] = [
        all(v["parent"].split(".")[0] == SURFACE_MASTER and abs(v["FadeAlpha_default"] - 1.0) < 1e-4 for v in mi_r.values()), None]
    # sockets
    rb["sockets"] = {}
    ok_s = True
    for name, s in man["sockets"].items():
        sock = mesh.find_socket(name)
        if sock is None:
            rb["sockets"][name] = None
            ok_s = False
            continue
        bone = str(sock.get_editor_property("bone_name"))
        rel = unreal.Transform(location=sock.get_editor_property("relative_location"),
                               rotation=sock.get_editor_property("relative_rotation"),
                               scale=unreal.Vector(1, 1, 1))
        comp = unreal.MathLibrary.compose_transforms(rel, world[bone])
        e = _dist(_v(comp.translation), s["component_cm"])
        ax = comp.rotation.get_axis_x()
        az = comp.rotation.get_axis_z()
        ae = max(max(abs(a - b) for a, b in zip(_v(ax, 6), s["component_axis_x"])),
                 max(abs(a - b) for a, b in zip(_v(az, 6), s["component_axis_z"])))
        rb["sockets"][name] = {"bone": bone, "relative_cm": _v(rel.translation),
                               "relative_rotation_pyr": [round(x, 4) for x in (rel.rotation.rotator().pitch,
                                                                               rel.rotation.rotator().yaw, rel.rotation.rotator().roll)],
                               "component_cm": _v(comp.translation), "blender_world_rest_cm": s["blender_world_rest_cm"],
                               "target_ue_cm": s["component_cm"], "err_cm": round(e, 4), "axis_err": round(ae, 5)}
        ok_s = ok_s and bone == "jaw" and e <= 0.5 and ae <= 0.01
    chk["sockets_carry_mouth_drag"] = [ok_s, sorted(rb["sockets"])]
    # statics
    rb["statics"] = {}
    for name in STATICS:
        sm = _load(_path(F_PROPS, name))
        if sm is None:
            rb["statics"][name] = None
            continue
        bb = sm.get_bounding_box()
        bs = sm.get_editor_property("body_setup")
        ag = bs.get_editor_property("agg_geom") if bs else None
        rb["statics"][name] = {"slots": [str(m.material_slot_name) for m in sm.static_materials],
                               "materials": [m.material_interface.get_path_name() if m.material_interface else None
                                             for m in sm.static_materials],
                               "bounds": {"min": _v(bb.min), "max": _v(bb.max)},
                               "boxes": len(ag.get_editor_property("box_elems")) if ag else None,
                               "trace_flag": str(bs.get_editor_property("collision_trace_flag")) if bs else None}
    chk["statics_present"] = [all(rb["statics"].values()), sorted(k for k, v in rb["statics"].items() if v)]
    # clips
    rb["clips"] = {}
    bad = []
    lm_worst = 0.0
    for clip, c in man["clips"].items():
        a = _load(_path(F_ANIM, ANIM % clip))
        if a is None:
            rb["clips"][clip] = None
            bad.append(clip)
            continue
        r = {"num_frames": AL.get_num_frames(a), "length_s": round(AL.get_sequence_length(a), 5),
             "loop": _get(a, "loop"), "root_motion": AL.is_root_motion_enabled(a),
             "additive": str(AL.get_additive_animation_type(a)),
             "skeleton_ok": a.get_editor_property("skeleton").get_path_name() == _path(F_MESH, SKEL)}
        try:
            r["num_keys"] = AL.get_num_keys(a)
        except Exception:
            pass
        r["tracks"] = len(AL.get_animation_track_names(a))
        N = c["frame_count"]
        opt = unreal.AnimPoseEvaluationOptions()
        _set(opt, "retrieve_additive_as_full_pose", True)
        _set(opt, "extract_root_motion", False)
        lm = {}
        ec = exp_anims["clips"][clip]["landmarks"]
        for f in sorted({0, N // 2, N}):
            p = unreal.AnimPoseExtensions.get_anim_pose_at_frame(a, f, opt)
            e = 0.0
            for bn in ("body", "head", "jaw", "fore_foot_l", "hind_foot_r", "tail_04", "spoon_prop"):
                w = unreal.AnimPoseExtensions.get_bone_pose(p, bn, unreal.AnimPoseSpaces.WORLD).translation
                e = max(e, _dist(_v(w), ec[str(f)][bn]))
            rt = unreal.AnimPoseExtensions.get_bone_pose(p, "root", unreal.AnimPoseSpaces.LOCAL)
            lm[str(f)] = {"landmark_err_cm": round(e, 4), "root_t": _v(rt.translation, 5)}
            lm_worst = max(lm_worst, e)
        r["landmarks"] = lm
        ok = (r["num_frames"] == N and abs(r["length_s"] - N / 30.0) < 1e-3 and bool(r["loop"]) == c["loop"] and
              not r["root_motion"] and r["skeleton_ok"] and r["tracks"] == 26 and
              all(v["landmark_err_cm"] <= 0.1 and max(abs(x) for x in v["root_t"]) < 1e-3 for v in lm.values()) and
              (("LOCAL_SPACE_BASE" in r["additive"]) == (clip in ADDITIVE)))
        r["ok"] = ok
        if not ok:
            bad.append(clip)
        rb["clips"][clip] = r
    chk["clips_34"] = [len([v for v in rb["clips"].values() if v]) == 34 and not bad, bad]
    chk["clip_landmarks_vs_blender_max_cm"] = [lm_worst <= 0.1, round(lm_worst, 5)]
    rb["owned_assets"] = owned_assets()
    rb["pass"] = all(v[0] for v in rb["checks"].values())
    return rb


def main(stage):
    t0 = time.time()
    try:
        if stage == "part_a":
            rep = run_part_a()
        elif stage == "socket_plan":
            rep = {"stage": stage, "socket_plan": socket_plan()}
        elif stage == "part_b":
            rep = run_part_b()
        elif stage == "readback":
            rep = readback()
        elif stage == "save":
            rep = {"saved": save_owned([_load(_path(F_MESH, SKEL)), _load(_path(F_MESH, SK))])}
        else:
            raise ValueError("unknown stage %s" % stage)
    except Exception as e:
        rep = {"stage": stage, "error": _err(e), "trace": traceback.format_exc()}
    rep["seconds"] = round(time.time() - t0, 2)
    rep = json.loads(json.dumps(rep, default=str))
    _merge_readback(stage, rep)
    print("PANTRY_RAT_IMPORT " + json.dumps(rep)[:20000])
    ok = rep.get("error") is None and rep.get("pass", True)
    print("PANTRY_RAT_OK" if ok else "PANTRY_RAT_FAIL")
    return rep


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "readback")
