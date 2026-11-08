"""Phase 9 (2026-11-07): reimport the re-authored locomotion clips (BoundCycle, LoadedBound, BoundStart, BoundStop) over
their /Game/ArtCandidates/PantryRat/R02/Animation assets and import the new Walk beside them, with the import script's own
task options (_anim_opts against the R02 SKEL, legacy FBX path), the same post-import flags as import_clips (no root
motion, rate scale 1, loop from the manifest), save only those five by name, and print a JSON readback (frames, length,
loop, root motion, tracks, landmark error vs export/anims/expected_anims.json at frames 0, N/2, N). Runs in the editor's
Python via Monolith editor_query run_python (execute_file)."""
import json
import math
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pantry_rat_import_ue as im  # noqa: E402

CLIPS = ("BoundStart", "BoundCycle", "BoundStop", "LoadedBound", "Walk")
man = im._manifest()
exp = json.load(open(os.path.join(im.ANIMS, "expected_anims.json"), "r", encoding="utf-8"))
skel = im._load(im._path(im.F_MESH, im.SKEL))
rep = {"preflight": im._preflight(), "clips": {}, "fbx_mtime": {}}
if not rep["preflight"]["ok"]:
    rep["error"] = "wrong editor or PIE"
    print("CLIPS_REIMPORT " + json.dumps(rep))
    raise SystemExit
tasks = []
for c in CLIPS:
    fbx = os.path.join(im.ROOT_DIR, man["clips"][c]["file"])
    rep["fbx_mtime"][c] = os.path.getmtime(fbx)
    rep["clips"][c] = {"existed_before": im._load(im._path(im.F_ANIM, im.ANIM % c)) is not None}
    tasks.append(im._task(fbx, im.F_ANIM, im.ANIM % c, im._anim_opts(skel)))
with im._LegacyFbx() as flag:
    unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks(tasks)
rep["interchange_flag_before_after"] = [flag.was, flag.after]
assets = []
for c in CLIPS:
    a = im._load(im._path(im.F_ANIM, im.ANIM % c))
    r = rep["clips"][c]
    if a is None:
        r["error"] = "missing after import"
        continue
    im.AL.set_root_motion_enabled(a, False)
    im.AL.set_rate_scale(a, 1.0)
    im._set(a, "loop", bool(man["clips"][c]["loop"]))
    assets.append(a)
    N = man["clips"][c]["frame_count"]
    opt = unreal.AnimPoseEvaluationOptions()
    im._set(opt, "extract_root_motion", False)
    worst = 0.0
    for f in sorted({0, N // 2, N}):
        p = unreal.AnimPoseExtensions.get_anim_pose_at_frame(a, f, opt)
        for bn in ("body", "head", "jaw", "fore_foot_l", "hind_foot_r", "tail_04", "spoon_prop"):
            w = unreal.AnimPoseExtensions.get_bone_pose(p, bn, unreal.AnimPoseSpaces.WORLD).translation
            e = exp["clips"][c]["landmarks"][str(f)][bn]
            worst = max(worst, math.sqrt((w.x - e[0]) ** 2 + (w.y - e[1]) ** 2 + (w.z - e[2]) ** 2))
    r.update({"path": a.get_path_name(), "num_frames": im.AL.get_num_frames(a),
              "length_s": round(im.AL.get_sequence_length(a), 5), "loop": im._get(a, "loop"),
              "root_motion": im.AL.is_root_motion_enabled(a), "tracks": len(im.AL.get_animation_track_names(a)),
              "skeleton_ok": a.get_editor_property("skeleton").get_path_name() == im._path(im.F_MESH, im.SKEL),
              "manifest_frames": N, "landmark_max_err_cm": round(worst, 5)})
    r["ok"] = (r["num_frames"] == N and abs(r["length_s"] - N / 30.0) < 1e-3 and bool(r["loop"]) == man["clips"][c]["loop"]
               and not r["root_motion"] and r["skeleton_ok"] and r["tracks"] == 26 and worst <= 0.1)
rep["saved"] = im.save_owned(assets)
rep["pass"] = all(rep["clips"][c].get("ok") for c in CLIPS) and len(rep["saved"]) == len(CLIPS)
print("CLIPS_REIMPORT " + json.dumps(rep))
