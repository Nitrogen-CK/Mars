"""Screaming Turnip R01 Phase J Part 3: SK (Part 1b skin weights, bounds widened for the 36 cm lean) + SRC_Tug / SRC_Cancel /
SRC_Release reimport and readback. Runs inside the editor's Python (Monolith editor_query run_python, execute_file), never in
PIE. Drives the campaign importer's own functions (Tools/Blender/.../scripts/screaming_turnip_import_ue.py) without editing it:
its `clips` stage imports all 16 clips, so the clip list is filtered to the three changed ones here. The importer's ledger
(export/unreal_readback_final.json) is NOT written; the report goes to phaseJ/reimport_phaseJ.json beside this file.

    exec: <this file> [import [1d]|readback|clips <A,B>]   (import 1d: Part 3c, the 2x stretch: bounds to x -100, the 1d
    crown target, report reimport_phaseJ_1d.json diffed against reimport_phaseJ_clips.json)   (import = mesh + 3 clips + full readback; readback = full readback
    only; clips = the named clips only (Part 3b: SRC_Cancel), then full readback, report reimport_phaseJ_clips.json)
"""
import importlib.util
import json
import os
import sys
import time

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
IMPORTER = os.path.normpath(os.path.join(HERE, "..", "..", "..", "Blender", "mars_ingredients", "screaming_turnip_r01",
                                         "scripts", "screaming_turnip_import_ue.py"))
CLIPS = ("SRC_Tug", "SRC_Cancel", "SRC_Release")
CROWN_TARGET_F15 = (-35.998, 0.0, 42.3013)       # review/phaseJ/crown_travel.json, SRC_Tug f15, UE root-relative (Part 3)
CROWN_TARGET_F15_1D = (-71.9944, 0.0, 45.7995)   # Part 1d (2x stretch), the same file re-written; used with the "1d" tag
# Fable 2026-11-08: the SK's bounds must cover x -60..+30 and z to 50 (the clips lean to x -57.9). The importer's own rule
# (envelope + 6 cm) gives x -64.7..+26.2; +x is raised to reach +30.
MIN_POS_EXT_X = 14.0                             # bind max x 16.21 + 14 = 30.21
# Part 3c (Fable 2026-11-09): the 2x clips reach x -93.2; the bounds must cover x -100: bind min x -17.69 - 83 = -100.69.
MIN_NEG_EXT_X_1D = 83.0
# Phase K (clips keep only the pose): SRC_Tug's crown head stays at x 0 (review/phaseK/crown_travel.json, |x| <= 0.016)
CROWN_K_F0 = (0.0, 0.0, 33.8646)   # f15
# Part 3d (Fable 2026-11-09, 4x): crown f15 (-143.9856, 0, 51.7974); bounds x -170..+30, z to 75: bind min x -17.69 - 153 =
# -170.69, bind max z 48 + 27 = 75.
TAGS = {"1d": dict(crown=(-71.9944, 0.0, 45.7995), neg_x=83.0, pos_z=None, diff="reimport_phaseJ_clips.json"),
        "1e": dict(crown=(-143.9856, 0.0, 51.7974), neg_x=153.0, pos_z=27.0, diff="reimport_phaseJ_1d.json")}


def _imp():
    spec = importlib.util.spec_from_file_location("screaming_turnip_import_ue_phaseJ", IMPORTER)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main(mode, only=None):
    t0 = time.time()
    m = _imp()
    rep = {"mode": mode, "importer": IMPORTER, "error": None}
    try:
        exp = m._expected()
        if mode == "clips":
            if not (m._guard(rep, True) and m._collision_guard(rep, exp)):
                raise RuntimeError(rep.get("error"))
            want = [c for c in (only or "").split(",") if c]
            rep["only"] = want
            rep["root_assets_before"] = m.root_assets()
            expc = dict(exp)
            expc["clips"] = {k: v for k, v in exp["clips"].items() if k in want}
            if sorted(expc["clips"]) != sorted(want):
                raise RuntimeError("unknown clips %s" % want)
            rep["clips"] = m.import_clips(expc)
            rep["root_assets_after"] = m.root_assets()
            rep["duplicates"] = [p for p in rep["root_assets_after"] if p.rsplit("_", 1)[-1].isdigit()]
        if mode == "import":
            if not (m._guard(rep, True) and m._collision_guard(rep, exp)):
                raise RuntimeError(rep.get("error"))
            rep["root_assets_before"] = m.root_assets()
            rep["mesh"] = mesh = m.run_mesh()
            sk = m._load(m._path(m.F_MESH, m.SK))
            pos = sk.get_editor_property("positive_bounds_extension")
            raised = False
            if pos.x < MIN_POS_EXT_X:
                sk.set_editor_property("positive_bounds_extension", unreal.Vector(MIN_POS_EXT_X, pos.y, pos.z))
                rep["positive_extension_raised"] = [pos.x, MIN_POS_EXT_X]
                raised = True
            neg = sk.get_editor_property("negative_bounds_extension")
            tag = TAGS.get(only)
            if tag and neg.x < tag["neg_x"]:
                sk.set_editor_property("negative_bounds_extension", unreal.Vector(tag["neg_x"], neg.y, neg.z))
                rep["negative_extension_raised"] = [neg.x, tag["neg_x"]]
                raised = True
            pos = sk.get_editor_property("positive_bounds_extension")
            if tag and tag["pos_z"] and pos.z < tag["pos_z"]:
                sk.set_editor_property("positive_bounds_extension", unreal.Vector(pos.x, pos.y, tag["pos_z"]))
                rep["positive_extension_z_raised"] = [pos.z, tag["pos_z"]]
                raised = True
            if raised:
                rep["mesh"]["saved_again"] = m.save_owned([sk])
            exp3 = dict(exp)
            exp3["clips"] = {k: v for k, v in exp["clips"].items() if k in CLIPS}
            rep["clips"] = m.import_clips(exp3)
            rep["root_assets_after"] = m.root_assets()
            rep["duplicates"] = [p for p in rep["root_assets_after"] if p.rsplit("_", 1)[-1].isdigit()]
        rep["preflight"] = m._preflight()
        rep.update(m.full_readback(exp))
        # SRC_Tug crown head at the last frame, component space (as clip_readback reads landmarks: AnimPose WORLD = root space)
        a = m._load(m._path(m.F_ANIM, m.ANIM % "SRC_Tug"))
        n = unreal.AnimationLibrary.get_num_frames(a)
        heads = m._world_heads(a, n)
        c = heads["crown"].translation
        got = [round(c.x, 4), round(c.y, 4), round(c.z, 4)]
        want = TAGS[only]["crown"] if only in TAGS else (CROWN_K_F0 if mode == "clips" else CROWN_TARGET_F15)
        rep["crown_SRC_Tug_last"] = {"frame": n, "got": got, "want": list(want), "err_cm": round(m._dist(got, want), 5)}
        # Phase K: SRC_Tug's crown head x at every frame against f0 (the clips keep only the pose: |x - x0| <= 0.05 cm)
        xs = []
        for f in range(n + 1):
            h = m._world_heads(a, f)["crown"].translation
            xs.append([f, round(h.x, 4), round(h.z, 4)])
        rep["crown_SRC_Tug_x_per_frame"] = xs
        rep["crown_SRC_Tug_x_max_dev_from_f0"] = round(max(abs(x - xs[0][1]) for _, x, _ in xs), 5)
        prev = m._saved_readback("reimport_phaseI")
        if mode == "clips" or (mode == "import" and only):
            # Phase K: a clips-only run diffs against the last full readback (the 1e import)
            pj = os.path.join(HERE, TAGS[only]["diff"] if mode == "import" else "reimport_phaseJ_1e.json")
            prev = json.load(open(pj, encoding="utf-8")) if os.path.isfile(pj) else None
            rep["diffed_against"] = os.path.basename(pj)
        if prev:
            rep["diff_vs_previous"] = {k: m._diff(m._comparable(prev.get(k)), m._comparable(rep.get(k)))
                                              for k in ("material_readback", "mesh_readback", "statics_readback",
                                                        "clip_readback", "owned_assets", "root_assets")}
        rep["preflight_after"] = m._preflight()
    except Exception as e:
        import traceback
        rep["error"] = m._err(e)
        rep["trace"] = traceback.format_exc()
    rep["seconds"] = round(time.time() - t0, 2)
    rep = json.loads(json.dumps(rep, default=str))
    out = os.path.join(HERE, {"import": "reimport_phaseJ%s.json" % ("_" + only if only else ""),
                              "clips": "reimport_phaseK_clips.json"}.get(mode, "readback_phaseJ.json"))
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(rep, fh, indent=1)
    summary = {k: (rep.get(k) or {}).get("pass") for k in ("material_readback", "mesh_readback", "statics_readback",
                                                             "clip_readback")}
    print("TURNIP_UE phaseJ %s error=%s pass=%s crown=%s" % (mode, rep["error"], summary, rep.get("crown_SRC_Tug_last")))
    for k in ("mesh_readback", "clip_readback"):
        fails = {c: v[1] for c, v in ((rep.get(k) or {}).get("checks") or {}).items() if not v[0]}
        print("TURNIP_UE %s fails=%s" % (k, json.dumps(fails, default=str)[:2000]))
    print("TURNIP_OK" if rep["error"] is None and all(summary.values()) else "TURNIP_FAIL")
    return out


main(sys.argv[1] if len(sys.argv) > 1 else "readback", sys.argv[2] if len(sys.argv) > 2 else None)
