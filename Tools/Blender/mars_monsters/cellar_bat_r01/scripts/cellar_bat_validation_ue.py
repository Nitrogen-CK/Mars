"""Cellar Bat R01 - Unreal-side validation of the export recipe (runs inside the editor through Monolith
editor_query run_python). Imports the three validation FBXs into /Game/ArtCandidates/CellarBat/R01/Validation/ with the
legacy FBX importer (Interchange FBX flag off in a try/finally, FbxImportUI, FBXNIM_IMPORT_NORMALS, materials and
textures off), reads the assets back, saves ONLY those assets and writes export/validation/unreal_readback.json.

Run from the editor's Python:
  import runpy; runpy.run_path(r"<this file>", run_name="__main__")
Prints CELLAR_BAT_OK or CELLAR_BAT_FAIL <reasons>.
"""
import json
import os

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
VAL = os.path.join(os.path.dirname(HERE), "export", "validation")
FOLDER = "/Game/ArtCandidates/CellarBat/R01/Validation"
PROJECT = "D:/Repositories/CkRepos/Orion/Mars.uproject"
FBX_FLAG = "Interchange.FeatureFlags.Import.FBX"
EAL = unreal.EditorAssetLibrary
CUBE, SK, SKEL, ANIM = "Cube10_Mars_SM", "CellarBat_R01_Blockout_Mars_SK", "CellarBat_R01_Blockout_Mars_SKEL", \
    "CellarBat_R01_Blockout_Flap_Mars_ANIM"


def path(n):
    return "%s/%s.%s" % (FOLDER, n, n)


def load(n):
    return unreal.load_asset(path(n)) if EAL.does_asset_exist(path(n)) else None


def _set(obj, name, value):
    try:
        obj.set_editor_property(name, value)
        return True
    except Exception:
        return False


def task(fbx, name, opts):
    t = unreal.AssetImportTask()
    t.filename = os.path.join(VAL, fbx)
    t.destination_path = FOLDER
    t.destination_name = name
    t.replace_existing = True
    t.automated = True
    t.save = False
    _set(t, "async_", False)
    t.options = opts
    return t


def base_opts():
    o = unreal.FbxImportUI()
    o.automated_import_should_detect_type = False
    o.import_materials = False
    o.import_textures = False
    return o


def run_import(tasks):
    was = unreal.SystemLibrary.get_console_variable_bool_value(FBX_FLAG)
    unreal.SystemLibrary.execute_console_command(None, "%s 0" % FBX_FLAG)
    try:
        unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks(tasks)
    finally:
        unreal.SystemLibrary.execute_console_command(None, "%s %d" % (FBX_FLAG, 1 if was else 0))
    return was, unreal.SystemLibrary.get_console_variable_bool_value(FBX_FLAG)


def vec(v):
    return [round(v.x, 4), round(v.y, 4), round(v.z, 4)]


def main():
    fails, rb = [], {}
    proj = unreal.Paths.convert_relative_path_to_full(unreal.Paths.get_project_file_path())
    pie = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).is_in_play_in_editor()
    rb["editor"] = {"project": proj, "pie": pie, "engine": unreal.SystemLibrary.get_engine_version()}
    if proj != PROJECT or pie:
        print("CELLAR_BAT_FAIL wrong editor or PIE (%s, %s)" % (proj, pie))
        return
    exp = json.load(open(os.path.join(VAL, "expected.json")))

    # ---- 1. cube + skeletal mesh (new skeleton)
    o = base_opts()
    o.import_mesh, o.import_as_skeletal, o.import_animations = True, False, False
    o.mesh_type_to_import = unreal.FBXImportType.FBXIT_STATIC_MESH
    d = o.static_mesh_import_data
    d.combine_meshes = True
    d.generate_lightmap_u_vs = False
    d.normal_import_method = unreal.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS
    s = base_opts()
    s.import_mesh, s.import_as_skeletal, s.import_animations = True, True, False
    s.mesh_type_to_import = unreal.FBXImportType.FBXIT_SKELETAL_MESH
    s.skeleton = None
    s.create_physics_asset = False
    sd = s.skeletal_mesh_import_data
    sd.normal_import_method = unreal.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS
    _set(sd, "import_morph_targets", False)
    _set(sd, "use_t0_as_ref_pose", False)
    flag = run_import([task("Cube10_Mars_SM.fbx", CUBE, o), task("CellarBat_R01_Blockout_Mars_SK.fbx", SK, s)])
    rb["interchange_fbx_flag_before_after"] = flag
    cube, sk = load(CUBE), load(SK)
    if cube is None or sk is None:
        print("CELLAR_BAT_FAIL import cube=%s sk=%s" % (cube, sk))
        return
    # rename the auto-made skeleton to the owned name
    skel = sk.skeleton
    auto = skel.get_path_name().split(".")[0]
    if not auto.endswith("/" + SKEL):
        EAL.rename_asset(auto, "%s/%s" % (FOLDER, SKEL))
    skel = sk.skeleton
    rb["assets"] = {"cube": cube.get_path_name(), "skeletal_mesh": sk.get_path_name(), "skeleton": skel.get_path_name()}

    # ---- 2. anim against that skeleton
    a = base_opts()
    a.import_mesh, a.import_as_skeletal, a.import_animations = False, False, True
    a.mesh_type_to_import = unreal.FBXImportType.FBXIT_ANIMATION
    a.skeleton = skel
    ad = a.anim_sequence_import_data
    _set(ad, "import_bone_tracks", True)
    _set(ad, "remove_redundant_keys", False)
    _set(ad, "animation_length", unreal.FBXAnimationLengthImportType.FBXALIT_EXPORTED_TIME)
    run_import([task("CellarBat_R01_Blockout_Flap.fbx", ANIM, a)])
    anim = load(ANIM)
    if anim is None:
        # the legacy importer may name the sequence after the take; find it
        for p in EAL.list_assets(FOLDER, recursive=False):
            x = unreal.load_asset(p)
            if isinstance(x, unreal.AnimSequence):
                EAL.rename_asset(p.split(".")[0], "%s/%s" % (FOLDER, ANIM))
                anim = load(ANIM)
                break
    rb["assets"]["anim"] = anim.get_path_name() if anim else None
    rb["folder_contents"] = [p.split(".")[0] for p in EAL.list_assets(FOLDER, recursive=False)]

    # ---- 3. readback: cube
    bb = cube.get_bounding_box()
    rb["cube"] = {"min": vec(bb.min), "max": vec(bb.max), "size": vec(bb.max - bb.min)}
    if max(abs(x - 10.0) for x in rb["cube"]["size"]) > 0.01:
        fails.append("cube size %s" % rb["cube"]["size"])

    # ---- skeletal mesh bounds / slots
    ib = sk.get_imported_bounds()
    lo, hi = ib.origin - ib.box_extent, ib.origin + ib.box_extent
    rb["skeletal_mesh"] = {"imported_bounds_min": vec(lo), "imported_bounds_max": vec(hi),
                           "span_y": round(hi.y - lo.y, 4), "nose_max_x": round(hi.x, 4),
                           "slots": [str(m.material_slot_name) for m in sk.materials]}
    if abs(rb["skeletal_mesh"]["span_y"] - 75.0) > 0.5:
        fails.append("span %.3f" % rb["skeletal_mesh"]["span_y"])
    if abs(hi.x - exp["nose_ue_x_cm"]) > 0.1:
        fails.append("max x %.3f != nose %.3f" % (hi.x, exp["nose_ue_x_cm"]))
    if rb["skeletal_mesh"]["slots"] != ["Body", "Membrane", "Eyes"]:
        fails.append("slots %s" % rb["skeletal_mesh"]["slots"])
    try:
        lod = unreal.SkeletalMeshEditorSubsystem if False else None
        rb["skeletal_mesh"]["lod0_tris"] = None
        es = unreal.get_editor_subsystem(unreal.SkeletalMeshEditorSubsystem)
        rb["skeletal_mesh"]["lod0_verts"] = es.get_num_verts(sk, 0)
    except Exception as e:
        rb["skeletal_mesh"]["lod0_verts"] = "n/a (%s)" % e

    # ---- skeleton reference pose: names, parents, root identity, unit scale, handedness
    pose = unreal.AnimPoseExtensions.get_reference_pose(skel)
    names = [str(n) for n in unreal.AnimPoseExtensions.get_bone_names(pose)]
    want = {b["name"]: b["parent"] for b in exp["bones"]}
    parents = {}
    try:
        rs = unreal.get_editor_subsystem(unreal.SkeletalMeshEditorSubsystem)
    except Exception:
        rs = None
    for n in names:
        p = None
        try:
            p = str(unreal.AnimPoseExtensions.get_parent_bone_name(pose, n)) if hasattr(unreal.AnimPoseExtensions, "get_parent_bone_name") else None
        except Exception:
            p = None
        parents[n] = None if p in (None, "None", "") else p
    rb["skeleton"] = {"bone_count": len(names), "order": names, "parents_api": hasattr(unreal.AnimPoseExtensions, "get_parent_bone_name")}
    if len(names) != 42 or sorted(names) != sorted(want):
        fails.append("bones %d extra %s missing %s" % (len(names), sorted(set(names) - set(want)), sorted(set(want) - set(names))))
    if rb["skeleton"]["parents_api"]:
        wrong = sorted(n for n in want if parents.get(n) != want[n])
        rb["skeleton"]["wrong_parents"] = wrong
        if wrong:
            fails.append("parents %s" % wrong)
    worst_scale, worst_head, bones = 0.0, 0.0, {}
    exp_head = {b["name"]: b["head_ue_cm"] for b in exp["bones"]}
    for n in names:
        lt = unreal.AnimPoseExtensions.get_bone_pose(pose, n, unreal.AnimPoseSpaces.LOCAL)
        wt = unreal.AnimPoseExtensions.get_bone_pose(pose, n, unreal.AnimPoseSpaces.WORLD)
        sc = lt.scale3d
        worst_scale = max(worst_scale, abs(sc.x - 1), abs(sc.y - 1), abs(sc.z - 1))
        h = wt.translation
        if n in exp_head:
            e = exp_head[n]
            worst_head = max(worst_head, ((h.x - e[0]) ** 2 + (h.y - e[1]) ** 2 + (h.z - e[2]) ** 2) ** 0.5)
        bones[n] = {"world": vec(h), "local_rot": [round(x, 4) for x in (lt.rotation.x, lt.rotation.y, lt.rotation.z, lt.rotation.w)],
                    "local_scale": vec(sc)}
    root = unreal.AnimPoseExtensions.get_bone_pose(pose, "root", unreal.AnimPoseSpaces.LOCAL)
    r = root.rotation
    rb["skeleton"].update({
        "root_local": {"translation": vec(root.translation), "rotation_xyzw": [round(x, 6) for x in (r.x, r.y, r.z, r.w)],
                       "scale": vec(root.scale3d)},
        "max_bone_scale_dev": round(worst_scale, 6), "max_bone_world_head_err_cm": round(worst_head, 4),
        "upperarm_r_world": bones.get("upperarm_r", {}).get("world"), "upperarm_l_world": bones.get("upperarm_l", {}).get("world"),
        "head_world": bones.get("head", {}).get("world"), "bones": bones})
    if abs(abs(r.w) - 1) > 1e-4 or root.translation.length() > 1e-3 or abs(root.scale3d.x - 1) > 1e-4:
        fails.append("root not identity %s" % rb["skeleton"]["root_local"])
    if worst_scale > 1e-4:
        fails.append("bone scale dev %.6f" % worst_scale)
    if worst_head > 0.1:
        fails.append("bone head err %.4f" % worst_head)
    if not (bones["upperarm_r"]["world"][1] > 0 > bones["upperarm_l"]["world"][1]):
        fails.append("handedness: upperarm_r y %s" % bones["upperarm_r"]["world"][1])

    # ---- anim
    if anim is None:
        fails.append("no anim")
    else:
        al = unreal.AnimationLibrary
        info = {"num_frames": al.get_num_frames(anim), "length_s": round(al.get_sequence_length(anim), 5)}
        try:
            fr = al.get_frame_rate(anim)
            info["frame_rate"] = [fr.numerator, fr.denominator]
        except Exception as e:
            info["frame_rate"] = "n/a in this engine's Python (%s); read it with Monolith animation_query get_sequence_info" % e
        try:
            info["num_keys"] = al.get_num_keys(anim)
        except Exception:
            pass
        tracks = [str(t) for t in al.get_animation_track_names(anim)]
        info["track_count"] = len(tracks)
        info["skeleton"] = anim.get_editor_property("skeleton").get_path_name()
        samples = {}
        for n in ("wrist_l", "wrist_r", "upperarm_l", "root"):
            rots = []
            for f in (0, 4, 8, 12, 15):
                t = al.get_bone_pose_for_frame(anim, n, f, False)
                q = t.rotation
                rots.append([round(x, 4) for x in (q.x, q.y, q.z, q.w)])
            samples[n] = rots
        info["samples_local_rot_xyzw_at_0_4_8_12_15"] = samples
        diff = lambda a, b: max(abs(x - y) for x, y in zip(a, b))
        info["wrist_l_rot_change_0_vs_12"] = round(diff(samples["wrist_l"][0], samples["wrist_l"][3]), 4)
        info["wrist_l_seam_0_vs_15"] = round(diff(samples["wrist_l"][0], samples["wrist_l"][4]), 5)
        info["root_rot_change_max"] = round(max(diff(samples["root"][0], s) for s in samples["root"]), 6)
        rb["anim"] = info
        frames = info.get("num_keys", info["num_frames"])
        if frames not in (16,) and info["num_frames"] not in (15, 16):
            fails.append("anim frames %s" % info["num_frames"])
        if isinstance(info["frame_rate"], list) and info["frame_rate"] != [30, 1]:
            fails.append("frame rate %s" % info["frame_rate"])
        if info["wrist_l_rot_change_0_vs_12"] < 0.05:
            fails.append("wrist_l not animated")
        if info["root_rot_change_max"] > 1e-4:
            fails.append("root animated")

    # ---- save only the validation assets
    saved = []
    for x in (cube, sk, skel, anim):
        if x is not None and x.get_path_name().startswith(FOLDER + "/"):
            if EAL.save_loaded_asset(x, only_if_is_dirty=False):
                saved.append(x.get_path_name())
    rb["saved"] = saved
    rb["folder_contents_after_save"] = [p.split(".")[0] for p in EAL.list_assets(FOLDER, recursive=False)]
    rb["fails"] = fails
    with open(os.path.join(VAL, "unreal_readback_rerun.json" if os.environ.get("CELLAR_BAT_RERUN") else "unreal_readback.json"), "w") as fh:
        json.dump(rb, fh, indent=1)
    summary = {k: v for k, v in rb.items() if k not in ("skeleton",)}
    summary["skeleton_summary"] = {k: v for k, v in rb["skeleton"].items() if k not in ("bones", "order")}
    print("READBACK " + json.dumps(summary))
    print(("CELLAR_BAT_FAIL " + "; ".join(fails)) if fails else "CELLAR_BAT_OK")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        print("CELLAR_BAT_FAIL exception")
