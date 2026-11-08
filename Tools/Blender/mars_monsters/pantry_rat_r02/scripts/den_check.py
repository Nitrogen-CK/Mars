"""Pantry Rat R02 - den clearance against the R01 den MESH (copied to review/den_ref/PantryRat_R01_Den_Mars_SM.fbx).

  blender -b --factory-startup source/PantryRat_R02.blend --python scripts/den_check.py

1. Imports the R01 den FBX into a scratch scene, reads its opening profile (the tightest half-width of the stone shell
   inside the portal, per 1 cm height band) and compares it with the analytic 60 x 60 profile (30 cm jambs + r 30 head)
   that animate_pantry_rat.py audits every den frame against.
2. Re-evaluates every frame of DenEmerge / DenEnter (and den_crouch) on the R02 rat and measures the YZ clearance to
   the MESH profile directly. Writes review/round_05/den_check.json. Prints PANTRY_RAT_OK / PANTRY_RAT_FAIL.
"""
import json
import math
import os
import sys
import traceback

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import rat_common as rc  # noqa: E402

ROOT = os.path.dirname(HERE)
FBX = os.path.join(ROOT, "review", "den_ref", "PantryRat_R01_Den_Mars_SM.fbx")
ARM, BODY = "PantryRat_R02_Armature", "PantryRat_R02_Body"


def main():
    rat_scene = bpy.context.scene
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=FBX)   # into the rat scene (1 BU = 1 cm), removed again below
    den = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    new_objs = [o for o in bpy.data.objects if o not in before]
    pts = []
    for o in den:
        me = o.data
        M = o.matrix_world
        for p in me.polygons:
            if len(me.materials) and me.materials[p.material_index] and "Stone" not in me.materials[p.material_index].name:
                continue
            for i in p.vertices:
                pts.append(tuple(M @ me.vertices[i].co))
    P = np.array(pts)
    for o in new_objs:
        bpy.data.objects.remove(o, do_unlink=True)
    rep_bounds = {"den_bounds_min": P.min(0).round(2).tolist(), "den_bounds_max": P.max(0).round(2).tolist()}
    # den local frame: opening faces +X (R01 export). Inside the portal (the tunnel walls just behind the front face):
    xs = P[:, 0]
    front = xs.max()
    inner = P[(np.abs(P[:, 1]) <= 34.0) & (xs < front - 0.5) & (xs > front - 30.0)]
    prof = {}
    for zb in range(0, 61, 2):
        sel = inner[(inner[:, 2] >= zb - 1) & (inner[:, 2] <= zb + 1)]
        if len(sel):
            prof[zb] = float(np.abs(sel[:, 1]).min())
    analytic = {z: (30.0 if z <= 30 else math.sqrt(max(0.0, 900.0 - (z - 30.0) ** 2))) for z in prof}
    dev = {z: round(prof[z] - analytic[z], 3) for z in prof}
    rep = {**rep_bounds, "den_fbx": os.path.relpath(FBX, ROOT).replace("\\", "/"), "mesh_halfwidth_by_z": {k: round(v, 3) for k, v in prof.items()},
           "analytic_halfwidth_by_z": {k: round(v, 3) for k, v in analytic.items()}, "mesh_minus_analytic": dev}
    zs = np.array(sorted(prof))
    hw = np.array([prof[z] for z in zs])

    def mesh_clear(co):
        y, z = np.abs(co[:, 1]), co[:, 2]
        lim = np.interp(z, zs, hw, right=0.0)
        c = lim - y
        i = int(np.argmin(c))
        return float(c[i]), (round(float(co[i, 1]), 2), round(float(co[i, 2]), 2))
    arm, body = bpy.data.objects[ARM], bpy.data.objects[BODY]
    out = {}
    for clip in ("DenEmerge", "DenEnter"):
        act = bpy.data.actions[clip]
        arm.animation_data_create()
        arm.animation_data.action = act
        try:
            if arm.animation_data.action_slot is None and len(act.slots):
                arm.animation_data.action_slot = act.slots[0]
        except AttributeError:
            pass
        worst = (1e9, None, None)
        for f in range(int(act.frame_range[1]) + 1):
            rat_scene.frame_set(f)
            co = rc.evaluated_tris(body)[0]
            c, pt = mesh_clear(co)
            if c < worst[0]:
                worst = (c, f, pt)
        out[clip] = {"min_clear_to_den_mesh_cm": round(worst[0], 3), "frame": worst[1], "point_yz": worst[2]}
    arm.animation_data.action = None
    rep["clips"] = out
    rep["rule"] = ">= 8 cm (R02 brief)"
    rep["ok"] = all(v["min_clear_to_den_mesh_cm"] >= 8.0 for v in out.values())
    with open(os.path.join(ROOT, "review", "round_05", "den_check.json"), "w") as fh:
        json.dump(rep, fh, indent=1)
    print("DEN", json.dumps({"max_abs_profile_dev": max(abs(v) for v in dev.values()), "clips": out}))
    print("PANTRY_RAT_OK" if rep["ok"] else "PANTRY_RAT_FAIL den clearance < 8")
    if not rep["ok"]:
        sys.exit(1)


try:
    main()
except SystemExit:
    raise
except Exception:
    traceback.print_exc()
    print("PANTRY_RAT_FAIL")
    sys.exit(1)
