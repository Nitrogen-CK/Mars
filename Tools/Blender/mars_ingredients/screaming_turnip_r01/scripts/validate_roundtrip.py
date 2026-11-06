"""Screaming Turnip R01 - Phase B Blender round trip of every exported FBX (fresh scene per file, anim_offset=0).

Compares, in Unreal cm ((x, -y, z)), against export/expected.json and export/anims/expected_anims.json (written by
export_screaming_turnip.py):
  cube      one mesh, object scale 1, bounds +/-5 cm (0.01)
  SK        one armature named `Armature`, object scale 1; 17 bones, names + parents exact; bind heads within 0.1 cm;
            bind rest rotations within 0.01 deg; tri count; slot names in order; bounds (0.1); colour attribute `Col`;
            max 4 influences, normalised, nothing weighted to root
  statics   each: one mesh, object scale 1, tri count, slot names, local bounds within 0.1 cm, closed
  anims     (check_anims) per clip: exactly one action; keyed frames == first..last, N+1 samples; root == its rest on
            EVERY frame (<= 1e-4); landmark bone heads on EVERY frame within 0.1 cm; skinned extremes (6 scalars) on
            every frame within 0.1 cm; loop seams (frame N vs 0) within 1e-3 cm; body / cheek scale keys at the clip's
            peak frame == authored within 0.01
Writes export/roundtrip_report.json and export/anims/roundtrip_report.json. Prints TURNIP_OK or TURNIP_FAIL <reasons>.

Phase B3 (shape keys): SK - the shape keys Basis / Inhale / Scream come back by name. Every clip - exactly one armature
action plus the mesh Key's action (nothing else); the Inhale / Scream values on EVERY frame within 1e-3 of the authored;
the authored peaks (Inhale 1.0 at ROOT_Inhale's last frame, Scream 1.0 at ROOT_Scream f3..f18) and both 0.0 on every
frame of the clips that do not use them; the evaluated (skinned + morphed) mesh at the peak frames within 0.01 cm of
the authored (expected_anims.json `peak_verts_blender_cm`).

Phase B2b: --shapekey-test runs ONLY the shape-key route proof: re-imports
export/validation/ScreamingTurnip_R01_ShapeKeyTest_Mars_ANIM.fbx (shapekey_test_screaming_turnip.py) in a fresh scene and
checks against review/phaseB2b/shapekey_test_expected.json: the shape keys come back by name, the keyed value is 1.0 at
the peak frame (5) and 0.0 at frames 0 / 10 (every frame within 1e-3 of the authored value), and the evaluated
(skinned + morphed) vertices at frames 0 / 5 / 10 match the authored mesh. Writes review/phaseB2b/shapekey_roundtrip.json.

Run (from the screaming_turnip_r01 folder):
  "$B" -b --factory-startup --python scripts/validate_roundtrip.py [-- --clips A,B]
  "$B" -b --factory-startup --python scripts/validate_roundtrip.py -- --shapekey-test
"""
import json
import math
import os
import sys
import traceback

import bpy
import numpy as np
from mathutils import Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import turnip_audit  # noqa: E402

ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "export")
VAL = os.path.join(OUT, "validation")
ANIMS = os.path.join(OUT, "anims")
TO_UE = np.array([1.0, -1.0, 1.0])
POS_TOL, CUBE_TOL, SCALE_TOL, ROT_TOL_DEG = 0.1, 0.01, 0.01, 0.01
SK_VAL_TOL, SK_VERT_TOL = 1e-3, 0.01      # B3: shape-key value per frame, evaluated mesh at the peak frames (cm)
SK_NAMES = ("Inhale", "Scream")


def clean():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.armatures, bpy.data.actions, bpy.data.materials):
        for d in list(coll):
            coll.remove(d)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.scale_length = 0.01
    sc.render.fps, sc.render.fps_base = 30, 1.0


def imp(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, anim_offset=0.0)   # default 1.0 would shift frame 0 to frame 1
    return [o for o in bpy.data.objects if o not in before]


def world_verts(obj, evaluated=False):
    if evaluated:
        dg = bpy.context.evaluated_depsgraph_get()
        ev = obj.evaluated_get(dg)
        me = ev.to_mesh()
    else:
        me = obj.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    if evaluated:
        ev.to_mesh_clear()
    m = np.array(obj.matrix_world)
    return (co.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]) * TO_UE


def fcurves(action):
    out = []
    try:
        for layer in action.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    out.extend(cb.fcurves)
    except AttributeError:
        pass
    if not out and hasattr(action, "fcurves"):
        out = list(action.fcurves)
    return out


def bounds_err(v, exp):
    return float(max(np.abs(v.min(0) - exp["min"]).max(), np.abs(v.max(0) - exp["max"]).max()))


def check_cube(fails):
    clean()
    objs = imp(os.path.join(VAL, "Cube10_Mars_SM.fbx"))
    meshes = [o for o in objs if o.type == "MESH"]
    if len(meshes) != 1:
        fails.append("cube: %d meshes" % len(meshes))
        return {}
    c = meshes[0]
    v = world_verts(c)
    r = {"object_scale": list(c.scale), "bounds_min": v.min(0).round(4).tolist(),
         "bounds_max": v.max(0).round(4).tolist()}
    if np.abs(v.min(0) + 5).max() > CUBE_TOL or np.abs(v.max(0) - 5).max() > CUBE_TOL:
        fails.append("cube bounds %s %s" % (v.min(0), v.max(0)))
    if np.abs(np.array(c.scale) - 1).max() > 1e-6:
        fails.append("cube object scale %s" % list(c.scale))
    return r


def check_bones(arm, exp, fails, tag):
    got = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
    want = {b["name"]: b["parent"] for b in exp["bones"]}
    extra, missing = sorted(set(got) - set(want)), sorted(set(want) - set(got))
    wrongp = sorted(n for n in want if n in got and got[n] != want[n])
    r = {"armature_object": arm.name, "armature_scale": [round(x, 6) for x in arm.scale], "bone_count": len(got),
         "extra_bones": extra, "missing_bones": missing, "wrong_parents": wrongp}
    if arm.name.split(".")[0] != "Armature":
        fails.append("%s armature object named %s" % (tag, arm.name))
    if np.abs(np.array(arm.scale) - 1).max() > 1e-5:
        fails.append("%s armature scale %s" % (tag, list(arm.scale)))
    if len(got) != 17 or extra or missing or wrongp:
        fails.append("%s hierarchy extra %s missing %s parents %s" % (tag, extra, missing, wrongp))
    dmax, amax = 0.0, 0.0
    for b in exp["bones"]:
        if b["name"] not in arm.data.bones:
            continue
        bb = arm.data.bones[b["name"]]
        h = arm.matrix_world @ bb.head_local
        dmax = max(dmax, float(np.linalg.norm(np.array((h.x, -h.y, h.z)) - np.array(b["head_ue_cm"]))))
        q = (arm.matrix_world.to_quaternion() @ bb.matrix_local.to_quaternion())
        d = math.degrees(q.rotation_difference(Quaternion(b["rest_quat_blender"])).angle)
        amax = max(amax, min(d, 360 - d))
    r["max_bind_head_error_cm"] = round(dmax, 6)
    r["max_bind_rest_rotation_error_deg"] = round(amax, 5)
    if dmax > POS_TOL:
        fails.append("%s bind head error %.4f" % (tag, dmax))
    if amax > ROT_TOL_DEG:
        fails.append("%s bind rest rotation error %.4f deg" % (tag, amax))
    return r


def check_sk(exp, fails):
    clean()
    e = exp["sk"]
    objs = imp(os.path.join(OUT, e["file"]))
    arms = [o for o in objs if o.type == "ARMATURE"]
    meshes = [o for o in objs if o.type == "MESH"]
    if len(arms) != 1 or len(meshes) != 1:
        fails.append("SK: %d armatures %d meshes" % (len(arms), len(meshes)))
        return {"objects": [(o.name, o.type) for o in objs]}
    arm, me = arms[0], meshes[0]
    r = check_bones(arm, exp, fails, "SK")
    me.data.calc_loop_triangles()
    r["tris"] = len(me.data.loop_triangles)
    if r["tris"] != e["tris"]:
        fails.append("SK tris %d != %d" % (r["tris"], e["tris"]))
    r["slots"] = [m.name.split(".")[0] for m in me.data.materials]
    if r["slots"] != e["slots"]:
        fails.append("SK slots %s" % r["slots"])
    v = world_verts(me)
    r["bounds_error_cm"] = round(bounds_err(v, e["bounds_ue_cm"]), 6)
    if r["bounds_error_cm"] > POS_TOL:
        fails.append("SK bounds error %.4f" % r["bounds_error_cm"])
    ca = me.data.color_attributes
    r["colour_attributes"] = [(c.name, c.data_type, c.domain) for c in ca]
    if not any(c.name == "Col" for c in ca):
        fails.append("SK colour attribute Col missing (%s)" % r["colour_attributes"])
    else:
        c = ca["Col"]
        a = np.empty(len(c.data) * 4)
        c.data.foreach_get("color_srgb", a)
        r["col_alpha_min_mean"] = [round(float(a[3::4].min()), 3), round(float(a[3::4].mean()), 3)]
    keys = [kb.name for kb in me.data.shape_keys.key_blocks] if me.data.shape_keys else []
    r["shape_keys"] = keys
    if keys != e.get("shape_keys", keys) or any(n not in keys for n in SK_NAMES):
        fails.append("SK shape keys %s (want %s)" % (keys, e.get("shape_keys")))
    wc = turnip_audit.weights_check(me, {b["name"] for b in exp["bones"]})
    r["weights"] = wc
    if wc["max_influences"] > 4 or wc["unnormalized"] or wc["unweighted"] or wc["root_weighted_verts"]:
        fails.append("SK weights %s" % wc)
    return r


def landmark_err(arm, me, k, bones):
    eb = 0.0
    for n in bones:
        p = arm.matrix_world @ arm.pose.bones[n].head
        eb = max(eb, float(np.linalg.norm(np.array((p.x, -p.y, p.z)) - np.array(k[n]))))
    v = world_verts(me, evaluated=True)
    ext = np.array(list(v.min(0)) + list(v.max(0)))
    return eb, float(np.abs(ext - np.array(k["extremes"])).max()), ext


def check_anims(exp, ea, fails, only=None):
    out = {}
    for name, e in ea["clips"].items():
        if only and name not in only:
            continue
        clean()
        objs = imp(os.path.join(ANIMS, e["file"]))
        arms = [o for o in objs if o.type == "ARMATURE"]
        meshes = [o for o in objs if o.type == "MESH"]
        r = {"actions": [a.name for a in bpy.data.actions]}
        out[name] = r
        if len(arms) != 1 or len(meshes) != 1 or arms[0].animation_data is None or \
                arms[0].animation_data.action is None:
            fails.append("%s: no single animated armature + mesh" % name)
            continue
        arm, me = arms[0], meshes[0]
        bc = check_bones(arm, exp, fails, name)
        r["bones_ok"] = not (bc["extra_bones"] or bc["missing_bones"] or bc["wrong_parents"])
        act = arm.animation_data.action
        key = me.data.shape_keys
        kact = key.animation_data.action if (key and key.animation_data) else None
        r["armature_action"] = act.name
        r["key_action"] = kact.name if kact else None
        r["key_action_curves"] = sorted(fc.data_path for fc in fcurves(kact)) if kact else []
        others = [a.name for a in bpy.data.actions if a not in (act, kact)]
        if others or kact is None:
            fails.append("%s actions %s (want one armature action + the Key action)" % (name, r["actions"]))
            continue
        keyed = sorted({int(round(k.co[0])) for fc in fcurves(act) for k in fc.keyframe_points})
        r["keyed_first_last_count"] = [keyed[0], keyed[-1], len(keyed)] if keyed else []
        if not keyed or keyed[0] != e["first"] or keyed[-1] != e["last"] or len(keyed) != e["samples"]:
            fails.append("%s keyed frames %s (want %d..%d, %d)" % (name, r["keyed_first_last_count"], e["first"],
                                                                  e["last"], e["samples"]))
        sc = bpy.context.scene
        root_rest = arm.matrix_world @ arm.data.bones["root"].matrix_local
        worst_root, worst_b, worst_m = 0.0, 0.0, 0.0
        ext_first = ext_last = None
        for f in range(e["first"], e["last"] + 1):
            sc.frame_set(f)
            rm = arm.matrix_world @ arm.pose.bones["root"].matrix
            dq = rm.to_quaternion().rotation_difference(root_rest.to_quaternion()).angle
            ds = float(np.abs(np.array(rm.to_scale()) - np.array(root_rest.to_scale())).max())
            worst_root = max(worst_root, (rm.translation - root_rest.translation).length,
                             min(dq, 2 * math.pi - dq), ds)
            eb, em, ext = landmark_err(arm, me, e["landmarks"][str(f)], ea["landmark_bones"])
            worst_b, worst_m = max(worst_b, eb), max(worst_m, em)
            if f == e["first"]:
                ext_first = ext
            if f == e["last"]:
                ext_last = ext
        r.update({"root_max_deviation_all_frames": round(worst_root, 8), "max_landmark_err_cm": round(worst_b, 6),
                  "max_extremes_err_cm": round(worst_m, 6)})
        # B3: shape-key values on every frame, peaks, evaluated mesh at the peak frames
        kb = key.key_blocks
        worst_v, got = 0.0, {n: [] for n in SK_NAMES}
        for f in range(e["first"], e["last"] + 1):
            sc.frame_set(f)
            for n in SK_NAMES:
                got[n].append(float(kb[n].value))
                worst_v = max(worst_v, abs(kb[n].value - e["landmarks"][str(f)]["sk"][n]))
        peaks = {}
        for n in SK_NAMES:
            m = max(got[n])
            fr = [e["first"] + i for i, v in enumerate(got[n]) if abs(v - m) <= 1e-4] if m > 1e-4 else []
            peaks[n] = {"max": round(m, 6), "frames_at_max": [fr[0], fr[-1]] if fr else []}
        r["shape_key_value_max_err"] = round(worst_v, 7)
        r["shape_key_peaks"] = peaks
        if worst_v > SK_VAL_TOL:
            fails.append("%s shape-key values off by %.5f" % (name, worst_v))
        rule = e.get("peak_rule", {})
        for n in SK_NAMES:
            if n not in rule and peaks[n]["max"] > 1e-4 and name not in ("ROOT_Scream", "ROOT_Recover"):
                fails.append("%s %s not 0 on every frame (max %.4f)" % (name, n, peaks[n]["max"]))
            if n in rule:
                want = [e["last"]] if rule[n] == "last" else list(range(rule[n][0], rule[n][1] + 1))
                bad = [f for f in want if abs(got[n][f - e["first"]] - 1.0) > 1e-4]
                if bad:
                    fails.append("%s %s != 1.0 at frames %s" % (name, n, bad))
        verr = {}
        for f, want in e.get("peak_verts_blender_cm", {}).items():
            sc.frame_set(int(f))
            v = world_verts(me, evaluated=True) * TO_UE          # back to Blender axes
            want = np.array(want)
            verr[f] = round(float(np.abs(v - want).max()), 6) if v.shape == want.shape else None
        r["peak_vertex_max_err_cm"] = verr
        if any(x is None or x > SK_VERT_TOL for x in verr.values()):
            fails.append("%s evaluated mesh at the peak frames off %s" % (name, verr))
        if worst_root > 1e-4:
            fails.append("%s root moves %.6f" % (name, worst_root))
        if worst_b > POS_TOL or worst_m > POS_TOL:
            fails.append("%s landmark error bone %.4f extremes %.4f" % (name, worst_b, worst_m))
        if e["loop"]:
            seam = float(np.abs(ext_first - ext_last).max())
            sc.frame_set(e["first"])
            h0 = {n: arm.pose.bones[n].head.copy() for n in ea["landmark_bones"]}
            sc.frame_set(e["last"])
            seam = max(seam, max((arm.pose.bones[n].head - h0[n]).length for n in h0))
            r["loop_seam_cm"] = round(seam, 7)
            if seam > 1e-3:
                fails.append("%s loop seam %.5f" % (name, seam))
        pf = e["scale_peak_frame"]
        sc.frame_set(pf)
        authored = e["landmarks"][str(pf)]["scale"]
        err = max(float(np.abs(np.array(arm.pose.bones[n].scale) - np.array(authored[n])).max())
                  for n in ("body", "cheek_l", "cheek_r"))
        r["scale_peak"] = {"frame": pf, "body": [round(x, 5) for x in arm.pose.bones["body"].scale],
                           "cheek_l": [round(x, 5) for x in arm.pose.bones["cheek_l"].scale],
                           "authored_body": authored["body"], "authored_cheek_l": authored["cheek_l"],
                           "err": round(err, 6)}
        if err > SCALE_TOL:
            fails.append("%s scale keys lost at frame %d: err %.4f" % (name, pf, err))
        print("ANIM %-24s keyed %s root %.1e landmark %.6f extremes %.6f seam %s scale_err %.6f sk_err %.6f "
              "peaks %s verts %s" % (name, r["keyed_first_last_count"], worst_root, worst_b, worst_m,
                                     r.get("loop_seam_cm"), err, worst_v, json.dumps(peaks),
                                     max([x for x in verr.values() if x is not None], default=None)))
    return out


def check_static(name, e, fails):
    clean()
    objs = imp(os.path.join(OUT, e["file"]))
    meshes = [o for o in objs if o.type == "MESH"]
    if len(meshes) != 1 or len(objs) != 1:
        fails.append("%s: objects %s" % (name, [(o.name, o.type) for o in objs]))
        return {}
    m = meshes[0]
    m.data.calc_loop_triangles()
    v = world_verts(m)
    a = turnip_audit.defect_audit(m) if all(len(p.vertices) == 3 for p in m.data.polygons) else {}
    r = {"object_scale": [round(x, 6) for x in m.scale], "tris": len(m.data.loop_triangles),
         "slots": [x.name.split(".")[0] for x in m.data.materials],
         "bounds_error_cm": round(bounds_err(v, e["bounds_ue_cm"]), 6),
         "boundary_edges": a.get("boundary_edges (defect)")}
    if r["tris"] != e["tris"] or r["slots"] != e["slots"] or r["bounds_error_cm"] > POS_TOL or r["boundary_edges"]:
        fails.append("%s %s (expected tris %d slots %s)" % (name, r, e["tris"], e["slots"]))
    if np.abs(np.array(m.scale) - 1).max() > 1e-5:
        fails.append("%s object scale %s" % (name, list(m.scale)))
    return r


def check_shapekey_test(fails):
    exp = json.load(open(os.path.join(ROOT, "review", "phaseB2b", "shapekey_test_expected.json")))
    clean()
    objs = imp(os.path.join(ROOT, exp["file"]))
    arms = [o for o in objs if o.type == "ARMATURE"]
    meshes = [o for o in objs if o.type == "MESH"]
    r = {"file": exp["file"], "objects": [(o.name, o.type) for o in objs]}
    if len(arms) != 1 or len(meshes) != 1:
        fails.append("shapekey test: %d armatures %d meshes" % (len(arms), len(meshes)))
        return r
    me = meshes[0]
    sk = me.data.shape_keys
    r["shape_keys"] = [kb.name for kb in sk.key_blocks] if sk else []
    r["actions"] = [{"name": a.name, "id_root": getattr(a, "id_root", "?"), "fcurves": [fc.data_path for fc in fcurves(a)]}
                    for a in bpy.data.actions]
    r["key_animation"] = bool(sk and sk.animation_data and sk.animation_data.action)
    for nm in exp["shape_keys"][1:]:
        if nm not in r["shape_keys"]:
            fails.append("shapekey test: key %s missing after import (%s)" % (nm, r["shape_keys"]))
    if exp["key"] not in r["shape_keys"]:
        return r
    kb = sk.key_blocks[exp["key"]]
    sc = bpy.context.scene
    vals, worst = {}, 0.0
    for f in exp["frames"]:
        sc.frame_set(f)
        vals[str(f)] = round(float(kb.value), 6)
        worst = max(worst, abs(kb.value - exp["value"][str(f)]))
    r["value"] = vals
    r["value_max_err"] = round(worst, 6)
    pk = exp["peak"]
    r["value_at_peak"] = vals[str(pk)]
    if abs(vals[str(pk)] - 1.0) > 1e-4 or abs(vals[str(exp["frames"][0])]) > 1e-4 or             abs(vals[str(exp["frames"][-1])]) > 1e-4 or worst > 1e-3:
        fails.append("shapekey test: values %s" % vals)
    verr = {}
    for f, d in exp["verts"].items():
        sc.frame_set(int(f))
        v = world_verts(me, evaluated=True) * TO_UE          # back to Blender axes (world_verts returns UE)
        want = np.array(d["co"])
        if v.shape != want.shape:
            fails.append("shapekey test: vertex count %s != %s" % (v.shape, want.shape))
            continue
        verr[f] = round(float(np.abs(v - want).max()), 6)
    r["evaluated_vertex_max_err_cm"] = verr
    if any(e > POS_TOL * 0.1 for e in verr.values()):
        fails.append("shapekey test: evaluated vertices off %s" % verr)
    sc.frame_set(pk)
    rest = np.array([tuple(x.co) for x in me.data.vertices])
    kd = np.array([tuple(x.co) for x in kb.data])
    r["peak_max_morph_delta_cm"] = round(float(np.linalg.norm(kd - rest, axis=1).max()), 4)
    print("SHAPEKEY_ROUNDTRIP", json.dumps(r))
    with open(os.path.join(ROOT, "review", "phaseB2b", "shapekey_roundtrip.json"), "w") as fh:
        json.dump(r, fh, indent=1)
    return r


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--shapekey-test" in argv:            # B2b: the shape-key route proof only (no production files read)
        fails = []
        check_shapekey_test(fails)
        if fails:
            print("TURNIP_FAIL " + "; ".join(fails))
            sys.exit(1)
        print("TURNIP_OK")
        return
    only = argv[argv.index("--clips") + 1].split(",") if "--clips" in argv else None
    fails, rep = [], {}
    exp = json.load(open(os.path.join(OUT, "expected.json")))
    ea = json.load(open(os.path.join(ANIMS, "expected_anims.json")))
    if not only:
        rep["cube"] = check_cube(fails)
        rep["sk"] = check_sk(exp, fails)
        rep["statics"] = {n: check_static(n, e, fails) for n, e in exp["statics"].items()}
    rep["anims"] = check_anims(exp, ea, fails, only)
    rep["tolerances"] = {"pos_cm": POS_TOL, "cube_cm": CUBE_TOL, "scale": SCALE_TOL, "rest_rot_deg": ROT_TOL_DEG,
                         "root": 1e-4, "loop_seam_cm": 1e-3, "shape_key_value": SK_VAL_TOL,
                         "shape_key_peak_mesh_cm": SK_VERT_TOL}
    rep["fails"] = fails

    def dump(p, d):
        with open(p, "w") as fh:
            json.dump(d, fh, indent=1, default=lambda o: o.tolist() if hasattr(o, "tolist") else str(o))

    if not only:
        dump(os.path.join(OUT, "roundtrip_report.json"), {k: v for k, v in rep.items() if k != "anims"})
        dump(os.path.join(ANIMS, "roundtrip_report.json"), {"anims": rep["anims"], "fails": fails,
                                                             "tolerances": rep["tolerances"]})
        for k in ("cube", "sk"):
            print("ROUNDTRIP %s %s" % (k, json.dumps(rep[k])))
        for n, s_ in rep["statics"].items():
            print("ROUNDTRIP %s %s" % (n, json.dumps(s_)))
    if fails:
        print("TURNIP_FAIL " + "; ".join(fails))
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
