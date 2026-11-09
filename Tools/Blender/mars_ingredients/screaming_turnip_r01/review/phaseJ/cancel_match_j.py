"""Phase J Part 1c: SRC_Cancel at 1 - a vs SRC_Tug at a, every 0.01 of alpha, crown head + HarvestGrip sockets (UE cm,
root-relative). Two evaluations: `actions` = the saved, exported actions (keyed every integer frame, LINEAR between, as
Unreal plays them; sub-frame via frame_set), `spline` = the animate script's Clip splines through the rig.
Run: "$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python review/phaseJ/cancel_match_j.py
Writes review/phaseJ/cancel_match.json. A measurement, not a gate: TURNIP_OK once written; a `TARGET` line says whether the
coordinator's <= 1.0 cm over a 0.05..0.95 holds for each evaluation (it does not: the Grip dip floor, PROGRESS Part 1c)."""
import sys, os, json
ROOT = "D:/Repositories/CkRepos/Orion/Tools/Blender/mars_ingredients/screaming_turnip_r01"
sys.path.insert(0, ROOT + "/scripts")
import bpy, numpy as np
from mathutils import Vector
import build_screaming_turnip as BT
import animate_screaming_turnip as A
TO_UE = np.array([1.0, -1.0, 1.0])
arm = bpy.data.objects[BT.ARM_NAME]
sc = bpy.context.scene
meas = json.load(open(ROOT + "/review/phaseB4/measurements.json"))
hg = {n: Vector(meas["landmarks"]["sockets_blender_cm"][n]) for n in ("HarvestGrip_R", "HarvestGrip_L")}
crinv = arm.data.bones["crown"].matrix_local.inverted()


def read():
    c = np.array(arm.matrix_world @ arm.pose.bones["crown"].head) * TO_UE
    M = arm.matrix_world @ arm.pose.bones["crown"].matrix @ crinv
    return {"crown": c, **{n: np.array(M @ p) * TO_UE for n, p in hg.items()}}


def at_action(name, t):
    arm.animation_data_create()
    act = bpy.data.actions[name]
    arm.animation_data.action = act
    if arm.animation_data.action_slot is None:
        arm.animation_data.action_slot = act.slots[0]
    sc.frame_set(int(t), subframe=t - int(t))
    return read()


def at_spline(clip, t):
    BT.apply_params(arm, clip.sample(t))
    return read()


clips = {c.name: c for c in A.build_clips(BT.unit(arm))}
alphas = [round(i / 100.0, 2) for i in range(101)]
out, ok = {}, True
for mode in ("actions", "spline"):
    rows, wc, ws = [], 0.0, 0.0
    for a in alphas:
        if mode == "actions":
            t, c = at_action("SRC_Tug", 15.0 * a), at_action("SRC_Cancel", 7.0 * (1.0 - a))
        else:
            t, c = at_spline(clips["SRC_Tug"], 15.0 * a), at_spline(clips["SRC_Cancel"], 7.0 * (1.0 - a))
        dc = float(np.linalg.norm(c["crown"] - t["crown"]))
        ds = max(float(np.linalg.norm(c[n] - t[n])) for n in hg)
        rows.append({"a": a, "tug_crown": t["crown"].round(3).tolist(), "cancel_crown": c["crown"].round(3).tolist(),
                     "crown_mismatch": round(dc, 3), "tug_HG_R": t["HarvestGrip_R"].round(3).tolist(),
                     "cancel_HG_R": c["HarvestGrip_R"].round(3).tolist(), "socket_mismatch": round(ds, 3)})
        if 0.05 <= a <= 0.95:
            wc, ws = max(wc, dc), max(ws, ds)
    worst_a = max((r for r in rows if 0.05 <= r["a"] <= 0.95), key=lambda r: r["crown_mismatch"])["a"]
    out[mode] = {"max_crown_mismatch_05_95": round(wc, 3), "max_socket_mismatch_05_95": round(ws, 3), "at_a": worst_a,
                 "max_crown_mismatch_20_95": max(r["crown_mismatch"] for r in rows if 0.2 <= r["a"] <= 0.95),
                 "rows": rows}
    print("MATCH", mode, "crown", round(wc, 3), "socket", round(ws, 3), "worst at a", worst_a,
          "a0.59", [r for r in rows if r["a"] == 0.59][0]["crown_mismatch"], flush=True)
    print("TARGET", mode, "met" if max(wc, ws) <= 1.0 else "MISSED (%.3f > 1.0)" % max(wc, ws), flush=True)
arm.animation_data.action = None
out["what"] = ("SRC_Cancel at frame 7 * (1 - a) vs SRC_Tug at frame 15 * a; UE cm root-relative; actions = exported keys "
               "with linear sub-frame interpolation; spline = authored Catmull-Rom")
out["cancel_keys"] = [round(float(k), 4) for k in clips["SRC_Cancel"].F]
json.dump(out, open(ROOT + "/review/phaseJ/cancel_match.json", "w"), indent=1)
print("TURNIP_OK cancel_match" if ok else "TURNIP_FAIL cancel_match")
sys.exit(0 if ok else 1)
