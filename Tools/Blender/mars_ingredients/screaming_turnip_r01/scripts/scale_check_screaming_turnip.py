"""Screaming Turnip R01 - Phase B4 scale proof: every length of the B4 build / clips / export == 3.0 x the B3 one.

Two checks, both against the B3 baseline (review/phaseB4/b3_baseline/ = copies of the B3 reports taken before B4 wrote
anything; source/ScreamingTurnip_R01_phaseB3.blend = byte copy of the B3 blend):

  json   walks every numeric leaf of each (B3, B4) report pair; a leaf is a LENGTH unless its path is a count, a ratio,
         an angle, a unit vector, a key value, a design-frame parameter (`params`, pose `spec`), an error/deviation or an
         area (areas must scale by SCALE^2). Every length must satisfy |new / old - SCALE| <= 0.5 % or, for small
         rounded values, |new - SCALE old| <= 0.002 cm (3-decimal rounding slack). Anything else is a FAIL to fix.
  blend  (run inside Blender on source/ScreamingTurnip_R01.blend) loads the B3 blend's datablocks and compares
         vertex by vertex: body Basis and every shape-key block, statics, bone heads / tails x SCALE; rest rotations,
         weights, vertex colours, polygons and material indices identical.

Writes review/phaseB4/scale_check.json (+ ratio_table.md, the headline quantities). Prints TURNIP_OK / TURNIP_FAIL.
Run (from the screaming_turnip_r01 folder):
  "$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/scale_check_screaming_turnip.py -- [--stage build|anim|export]
"""
import json
import os
import re
import sys
import traceback

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "review", "phaseB4", "b3_baseline")
B4 = os.path.join(ROOT, "review", "phaseB4")
SCALE = 3.0
REL_TOL, ABS_SLACK = 0.005, 0.002

# path patterns (on the '/'-joined key path with list indices stripped) that are NOT lengths
NOT_LENGTH = [
    r"^/params/", r"/spec/", r"/anatomy/", r"/tris", r"/verts$", r"/islands$", r"/count$", r"_ratio", r"_over_",
    r"/axis$", r"/max_influences$", r"/vertices_moved$", r"/leaf_length_scale$", r"ue_dev", r"root_max_dev",
    r"root_matrix_max_abs_dev", r"_err_cm", r"/identity_rest_rotation/", r"rest_quat", r"/rest_rotation_change_deg$",
    r"/max_rot_delta_deg$", r"/max_shape_key_delta$", r"^/clips/[^/]+/shape_keys/", r"shape_key_peaks/", r"/sk/",
    r"/curve_peaks/", r"/scale/", r"/frames", r"/samples$", r"/first$", r"/last$", r"/fps$", r"/duration_s$",
    r"/key_frames", r"/scale_peak_frame$", r"isect", r"/intersections/", r"/seconds$", r"/scale_factor$",
    r"/scale_check/", r"/unit_read_back$", r"/mesh/audit/", r"/weights/", r"/bytes$", r"/root_dev$", r"/frame$",
    r"/dev$", r"/num_keys/", r"/rotation_ue_deg_pyr", r"/zero_from_frame$", r"/velocity_delta",
    r"/pose_delta_cm_deg/1", r"/pose_delta_cm_deg/2", r"action_vs_authored", r"^/cube/", r"/peak_rule",
    r"/statics/[^/]+/audit/(tris|verts|islands)",
]
AREA = [r"min_tri_area_cm2$"]


def norm_path(p):
    return re.sub(r"\[\d+\]", "", p)


def walk(a, b, p=""):
    if isinstance(a, dict):
        for k in a:
            if isinstance(b, dict) and k in b:
                yield from walk(a[k], b[k], p + "/" + str(k))
            else:
                yield p + "/" + str(k), "MISSING", None
    elif isinstance(a, list):
        if not isinstance(b, list) or len(a) != len(b):
            yield p, "LEN", None
            return
        for i, (x, y) in enumerate(zip(a, b)):
            # keep the index visible for pose_delta_cm_deg-style triples (index 0 = cm)
            yield from walk(x, y, p + "/%d" % i if p.endswith("pose_delta_cm_deg") else p + "[%d]" % i)
    elif isinstance(a, (int, float)) and not isinstance(a, bool):
        yield p, a, b


def classify(p):
    q = norm_path(p)
    if any(re.search(r, q) for r in AREA):
        return "area"
    if any(re.search(r, q) for r in NOT_LENGTH):
        return "skip"
    return "length"


def check_pair(name, old, new):
    out = {"pair": name, "lengths": 0, "areas": 0, "skipped": 0, "zero": 0, "worst_rel": 0.0, "fails": [],
           "missing": []}
    for p, a, b in walk(old, new):
        if a in ("MISSING", "LEN"):
            out["missing"].append("%s %s" % (p, a))
            continue
        kind = classify(p)
        if kind == "skip":
            out["skipped"] += 1
            continue
        f = SCALE * SCALE if kind == "area" else SCALE
        if a == 0 and b == 0:
            out["zero"] += 1
            continue
        out["areas" if kind == "area" else "lengths"] += 1
        rel = abs(b / a - f) / f if a else float("inf")
        ok = rel <= REL_TOL or abs(b - f * a) <= ABS_SLACK * (f / SCALE)
        if a and abs(b - f * a) > ABS_SLACK:
            out["worst_rel"] = max(out["worst_rel"], rel)
        if not ok:
            out["fails"].append({"path": p, "b3": a, "b4": b, "ratio": round(b / a, 5) if a else None})
    return out


def load(path):
    return json.load(open(path)) if os.path.exists(path) else None


HEADLINE = [  # (label, file key, path)
    ("neutral height (tip to highest leaf)", "meas", "/overall_height_tip_to_highest_leaf_cm"),
    ("neutral width w_y", "meas", "/overall/w_y"),
    ("neutral depth d_x", "meas", "/overall/d_x"),
    ("bulb h_z", "meas", "/bulb/h_z"),
    ("bulb w_y", "meas", "/bulb/w_y"),
    ("bulb d_x", "meas", "/bulb/d_x"),
    ("body bone head z", "meas", "/landmarks/body_centre_bone_head[2]"),
    ("jaw hinge x", "meas", "/landmarks/jaw_hinge[0]"),
    ("jaw hinge z", "meas", "/landmarks/jaw_hinge[2]"),
    ("crown base z", "meas", "/landmarks/crown_base[2]"),
    ("cheek_l head y", "meas", "/landmarks/cheek_l_head[1]"),
    ("Grip_L y (UE)", "meas", "/landmarks/sockets_unreal_cm/Grip_L[1]"),
    ("Grip_L z", "meas", "/landmarks/sockets_unreal_cm/Grip_L[2]"),
    ("MouthCue x", "meas", "/landmarks/sockets_unreal_cm/MouthCue[0]"),
    ("MouthCue z", "meas", "/landmarks/sockets_unreal_cm/MouthCue[2]"),
    ("SoilLine z", "meas", "/landmarks/sockets_unreal_cm/SoilLine[2]"),
    ("HarvestGrip_L z", "meas", "/landmarks/sockets_unreal_cm/HarvestGrip_L[2]"),
    ("hull extents d_x", "meas", "/collision_hull/extents_cm/d_x"),
    ("hull extents w_y", "meas", "/collision_hull/extents_cm/w_y"),
    ("hull extents h_z", "meas", "/collision_hull/extents_cm/h_z"),
    ("hull front x (widened)", "meas", "/collision_hull/extents_cm/max[0]"),
    ("hull centre offset x", "meas", "/collision_hull/centre_offset_from_root_cm[0]"),
    ("hull centre offset z", "meas", "/collision_hull/centre_offset_from_root_cm[2]"),
    ("bed outer w", "meas", "/statics/TurnipBed_R01/bounds_local/w_y"),
    ("bed h", "meas", "/statics/TurnipBed_R01/bounds_local/h_z"),
    ("bed top z (above soil line)", "meas", "/statics/TurnipBed_R01/bounds_local/max[2]"),
    ("bed scene z", "meas", "/statics/TurnipBed_R01/object_location[2]"),
    ("muzzle protrusion max", "meas", "/muzzle_rest/muzzle_protrusion_max_cm"),
    ("seam floor x_c", "meas", "/muzzle_rest/x_c_seam_floor"),
    ("Inhale key max rest delta", "meas", "/shape_keys[0]/max_rest_delta_cm"),
    ("Scream key max rest delta", "meas", "/shape_keys[1]/max_rest_delta_cm"),
    ("scream pose height", "pose", "/poses/scream/bounds/h_z"),
    ("scream side lip separation", "pose", "/poses/scream/gape/side_lip_separation_cm"),
    ("scream cavity depth", "pose", "/poses/scream/mouth_b2/cavity_depth_cm"),
    ("inhale lobe forward (l)", "pose", "/poses/inhale/mouth_b2/lobes/lobe_l/forward_cm"),
    ("recover width", "pose", "/poses/recover/bounds/w_y"),
    ("clip envelope h", "anim", "/envelope/h_z"),
    ("clip envelope w", "anim", "/envelope/w_y"),
    ("clip envelope d", "anim", "/envelope/d_x"),
    ("ROOT_Scream clip height", "anim", "/clips/ROOT_Scream/clip_bounds/h_z"),
    ("planted seam top z", "anim", "/planted/seam_top_z"),
    ("planted shoulder above soil", "anim", "/planted/shoulder_above_soil_cm"),
    ("QuietIdle->Anticipate hard cut (cm)", "anim", "/chain[9]/max_head_delta_cm"),
    ("RecoveryIdle any->AnticipateTired cut (cm)", "anim", "/chain[7]/max_head_delta_cm"),
]


def get_path(d, p):
    for tok in re.findall(r"/([^/\[]+)|\[(\d+)\]", p):
        k, i = tok
        d = d[k] if k else d[int(i)]
    return d


def json_checks(stage):
    pairs = [("measurements", "measurements.json", os.path.join(B4, "measurements.json")),
             ("pose_report", "pose_report.json", os.path.join(B4, "pose_report.json"))]
    if stage in ("anim", "export"):
        pairs.append(("anim_report", "anim_report.json", os.path.join(B4, "anim_report.json")))
    if stage == "export":
        pairs += [("expected", "expected.json", os.path.join(ROOT, "export", "expected.json")),
                  ("expected_anims", "expected_anims.json", os.path.join(ROOT, "export", "anims", "expected_anims.json"))]
    res, docs = [], {}
    for name, bf, nf in pairs:
        old, new = load(os.path.join(BASE, bf)), load(nf)
        if name == "pose_report" and old is not None:      # B4 renamed the envelope key (the limit now scales)
            for v in old["poses"].values():
                v["envelope_exceeded_by_cm"] = v.pop("envelope_22x14x13_exceeded_by_cm", {})
        if old is None or new is None:
            res.append({"pair": name, "fails": ["missing file %s / %s" % (bf, nf)]})
            continue
        docs[name] = (old, new)
        r = check_pair(name, old, new)
        res.append(r)
        print("PAIR %-15s lengths %6d areas %3d zero %5d skipped %6d worst_rel %.5f fails %d missing %d" % (
            name, r["lengths"], r["areas"], r["zero"], r["skipped"], r["worst_rel"], len(r["fails"]), len(r["missing"])))
        for f in r["fails"][:12]:
            print("  FAIL", json.dumps(f))
    table = []
    key = {"meas": "measurements", "pose": "pose_report", "anim": "anim_report"}
    for label, fk, p in HEADLINE:
        if key[fk] not in docs:
            continue
        old, new = docs[key[fk]]
        try:
            a, b = float(get_path(old, p)), float(get_path(new, p))
        except (KeyError, IndexError, TypeError):
            table.append({"quantity": label, "path": p, "b3": None, "b4": None, "ratio": None})
            continue
        table.append({"quantity": label, "path": p, "b3": a, "b4": b, "ratio": round(b / a, 4) if a else None})
    return res, table


def blend_check():
    import bpy
    import numpy as np
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import build_screaming_turnip as BT
    old_path = os.path.join(ROOT, "source", "ScreamingTurnip_R01_phaseB3.blend")
    names = [BT.MESH_NAME, BT.BED_NAME, BT.BED_EMPTY_NAME, BT.COLL_NAME, BT.ARM_NAME]
    with bpy.data.libraries.load(old_path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n in names]
    old = {o.name.rsplit(".", 1)[0] if o.name not in names else o.name: o for o in dst.objects if o is not None}
    new = {n: bpy.data.objects[n] for n in names}
    out, fails = {}, []

    def co_of(me):
        a = np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get("co", a)
        return a.reshape(-1, 3)

    for n in (BT.MESH_NAME, BT.BED_NAME, BT.BED_EMPTY_NAME, BT.COLL_NAME):
        mo, mn = old[n].data, new[n].data
        r = {"verts": [len(mo.vertices), len(mn.vertices)], "polys": [len(mo.polygons), len(mn.polygons)]}
        if len(mo.vertices) != len(mn.vertices) or len(mo.polygons) != len(mn.polygons):
            fails.append("%s topology %s" % (n, r))
            out[n] = r
            continue
        r["vertex_err_cm"] = float(np.abs(co_of(mn) - SCALE * co_of(mo)).max())
        po = [tuple(p.vertices) for p in mo.polygons]
        pn = [tuple(p.vertices) for p in mn.polygons]
        r["polygons_identical"] = po == pn
        r["material_index_identical"] = [p.material_index for p in mo.polygons] == [p.material_index for p in mn.polygons]
        if mo.color_attributes.get("Col") is not None:
            ca, cb = mo.color_attributes["Col"], mn.color_attributes["Col"]
            a, b = np.empty(len(ca.data) * 4), np.empty(len(cb.data) * 4)
            ca.data.foreach_get("color", a)
            cb.data.foreach_get("color", b)
            r["vertex_colour_max_diff"] = float(np.abs(a - b).max())
        if mo.shape_keys:
            r["shape_keys"] = {}
            for kb in mo.shape_keys.key_blocks:
                kn = mn.shape_keys.key_blocks[kb.name]
                a, b = np.empty(len(mo.vertices) * 3), np.empty(len(mo.vertices) * 3)
                kb.data.foreach_get("co", a)
                kn.data.foreach_get("co", b)
                r["shape_keys"][kb.name] = float(np.abs(b - SCALE * a).max())
            ow = BT.weight_matrix(old[n])
            nw = BT.weight_matrix(new[n])
            r["weights_max_diff"] = float(np.abs(ow - nw).max())
        r["location"] = [list(old[n].location), list(new[n].location)]
        r["location_err_cm"] = float(max(abs(b - SCALE * a) for a, b in zip(old[n].location, new[n].location)))
        out[n] = r
        worst = max([r["vertex_err_cm"], r["location_err_cm"]] + list(r.get("shape_keys", {}).values()))
        if worst > 1e-3 or not r["polygons_identical"] or not r["material_index_identical"] or \
                r.get("vertex_colour_max_diff", 0) > 1e-6 or r.get("weights_max_diff", 0) > 1e-6:
            fails.append("%s %s" % (n, json.dumps(r)[:400]))
    ao, an = old[BT.ARM_NAME].data, new[BT.ARM_NAME].data
    rb = {"count": [len(ao.bones), len(an.bones)], "head_err_cm": 0.0, "tail_err_cm": 0.0, "rest_rot_err_deg": 0.0,
          "parents_identical": True}
    import math
    for b in ao.bones:
        c = an.bones[b.name]
        rb["head_err_cm"] = max(rb["head_err_cm"], (c.head_local - b.head_local * SCALE).length)
        rb["tail_err_cm"] = max(rb["tail_err_cm"], (c.tail_local - b.tail_local * SCALE).length)
        d = math.degrees(b.matrix_local.to_quaternion().rotation_difference(c.matrix_local.to_quaternion()).angle)
        rb["rest_rot_err_deg"] = max(rb["rest_rot_err_deg"], min(d, 360 - d))
        rb["parents_identical"] &= (b.parent.name if b.parent else None) == (c.parent.name if c.parent else None)
    out["bones"] = rb
    if rb["count"] != [17, 17] or rb["head_err_cm"] > 1e-3 or rb["tail_err_cm"] > 1e-3 or rb["rest_rot_err_deg"] > 1e-4 \
            or not rb["parents_identical"]:
        fails.append("bones %s" % rb)
    print("BLEND", json.dumps(out)[:3000])
    return out, fails


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    stage = argv[argv.index("--stage") + 1] if "--stage" in argv else "build"
    fails = []
    res, table = json_checks(stage)
    for r in res:
        fails += ["%s: %s" % (r["pair"], f) for f in r["fails"][:5]]
        if r.get("missing"):
            fails.append("%s: %d missing keys (%s)" % (r["pair"], len(r["missing"]), r["missing"][:3]))
    blend = None
    try:
        import bpy  # noqa: F401
        in_blender = True
    except ImportError:
        in_blender = False
    if in_blender:
        blend, bf = blend_check()
        fails += bf
    for t in table:
        print("RATIO %-44s B3 %10s  B4 %10s  x%s" % (t["quantity"], t["b3"], t["b4"], t["ratio"]))
    bad_rows = [t for t in table if t["ratio"] is None or abs(t["ratio"] - SCALE) > SCALE * REL_TOL + 1e-9]
    for t in bad_rows:
        if t["b3"] is not None and abs(t["b4"] - SCALE * t["b3"]) <= ABS_SLACK:
            continue
        fails.append("headline %s %s" % (t["quantity"], t))
    os.makedirs(B4, exist_ok=True)
    with open(os.path.join(B4, "scale_check%s.json" % ("" if stage == "build" else "_" + stage)), "w") as fh:
        json.dump({"scale": SCALE, "tolerance": {"rel": REL_TOL, "abs_slack_cm": ABS_SLACK}, "pairs": res,
                   "headline": table, "blend": blend, "fails": fails}, fh, indent=1)
    with open(os.path.join(B4, "ratio_table%s.md" % ("" if stage == "build" else "_" + stage)), "w") as fh:
        fh.write("| quantity | B3 (cm) | B4 (cm) | ratio |\n|---|---|---|---|\n")
        for t in table:
            fh.write("| %s | %s | %s | %s |\n" % (t["quantity"], t["b3"], t["b4"], t["ratio"]))
    if fails:
        print("TURNIP_FAIL " + "; ".join(str(f) for f in fails[:20]))
        sys.exit(1)
    print("TURNIP_OK")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        print("TURNIP_FAIL exception")
        sys.exit(1)
