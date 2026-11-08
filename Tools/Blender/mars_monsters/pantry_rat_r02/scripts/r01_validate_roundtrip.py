"""Pantry Rat R01 - Blender round trip of every exported FBX, each imported into a fresh background scene (1 BU = 1 cm),
compared in Unreal cm ((x, -y, z)) with export/validation/expected.json and export/anims/expected_anims.json:
  cube    one mesh, object scale 1, bounds +/-5 (0.01)
  bind    one armature (scale 1) + one mesh; 26 bones, names + parents exact; bind heads within 0.1 cm; tri count; slot
          order; bounds (0.1); max 4 influences, normalised; Carry_Mouth / Carry_Drag rebuilt on the imported jaw bone
          (Blender bone-local values) land on their exported component positions (0.1)
  clips   34 FBXs: one armature + one mesh, 26 bones, ONE action, keyed frames 0..N (N+1 samples), the root identical
          to its rest on every sample, loop seam (landmarks frame 0 == N), landmark bone heads at the first / middle /
          last frame within 0.1 cm
  statics den (slots Stone, Void), den eye plate (1 quad, UV 0..1, normal +X), cheese (Rind, Flesh): tris, slots, bounds
Writes export/anims/roundtrip_report.json. Prints PANTRY_RAT_OK / PANTRY_RAT_FAIL <reasons>.

Run:  blender -b --factory-startup --python scripts/validate_roundtrip.py
"""
import json
import math
import os
import sys
import traceback

import bpy
import numpy as np
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "export")
VAL = os.path.join(OUT, "validation")
ANIMS = os.path.join(OUT, "anims")
TO_UE = np.array([1.0, -1.0, 1.0])
TOL = 0.1


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
    bpy.ops.import_scene.fbx(filepath=path, anim_offset=0.0)
    return [o for o in bpy.data.objects if o not in before]


def verts_ue(obj):
    co = np.empty(len(obj.data.vertices) * 3)
    obj.data.vertices.foreach_get("co", co)
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
    return out


def bounds_err(v, b):
    return float(max(np.abs(v.min(0) - b["min"]).max(), np.abs(v.max(0) - b["max"]).max()))


def check_bind(exp, fails):
    clean()
    objs = imp(os.path.join(OUT, "PantryRat_R01_Mars_SK.fbx"))
    arms = [o for o in objs if o.type == "ARMATURE"]
    meshes = [o for o in objs if o.type == "MESH"]
    r = {"objects": [(o.name, o.type) for o in objs]}
    if len(arms) != 1 or len(meshes) != 1:
        fails.append("bind: %d armatures %d meshes" % (len(arms), len(meshes)))
        return r
    arm, me = arms[0], meshes[0]
    r["armature_scale"] = [round(x, 6) for x in arm.scale]
    if np.abs(np.array(arm.scale) - 1).max() > 1e-5:
        fails.append("bind armature scale %s" % list(arm.scale))
    got = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
    want = {b["name"]: b["parent"] for b in exp["bones"]}
    bad = sorted(set(got) ^ set(want)) + sorted(n for n in want if n in got and got[n] != want[n])
    r["bone_count"], r["bone_mismatch"] = len(got), bad
    if bad or len(got) != 26:
        fails.append("bind bones %d %s" % (len(got), bad))
    mw = arm.matrix_world
    dh = 0.0
    for b in exp["bones"]:
        h = mw @ arm.data.bones[b["name"]].head_local
        dh = max(dh, float(np.linalg.norm(np.array((h.x, -h.y, h.z)) - np.array(b["head_ue_cm"]))))
    r["max_bind_head_err_cm"] = round(dh, 5)
    if dh > TOL:
        fails.append("bind head err %.4f" % dh)
    me.data.calc_loop_triangles()
    r["tris"] = len(me.data.loop_triangles)
    r["slots"] = [m.name.split(".")[0] for m in me.data.materials]
    v = verts_ue(me)
    r["bounds"] = {"min": v.min(0).round(3).tolist(), "max": v.max(0).round(3).tolist()}
    r["bounds_err_cm"] = round(bounds_err(v, exp["bind"]["bounds_ue_cm"]), 5)
    if r["tris"] != exp["bind"]["tris"]:
        fails.append("bind tris %d != %d" % (r["tris"], exp["bind"]["tris"]))
    if r["slots"] != exp["slots"]:
        fails.append("bind slots %s" % r["slots"])
    if r["bounds_err_cm"] > TOL:
        fails.append("bind bounds err %.4f" % r["bounds_err_cm"])
    maxinf, badw = 0, 0
    for vt in me.data.vertices:
        ws = [g.weight for g in vt.groups if g.weight > 1e-6]
        maxinf = max(maxinf, len(ws))
        badw += (not ws) or abs(sum(ws) - 1) > 1e-3
    r["max_influences"], r["bad_weights"] = maxinf, badw
    if maxinf > 4 or badw:
        fails.append("bind weights %d %d" % (maxinf, badw))
    # sockets: the Blender jaw-local offsets, rebuilt on the IMPORTED jaw bone, must land on the exported positions
    jb = arm.data.bones["jaw"]
    r["sockets"] = {}
    for nm, s in exp["sockets"].items():
        Mloc = Matrix.Translation(s["blender_jaw_local_cm"])
        p = (mw @ jb.matrix_local @ Mloc).translation
        e = float(np.linalg.norm(np.array((p.x, -p.y, p.z)) - np.array(s["component_cm"])))
        r["sockets"][nm] = {"rebuilt_ue_cm": [round(p.x, 4), round(-p.y, 4), round(p.z, 4)], "err_cm": round(e, 5)}
        if e > TOL:
            fails.append("socket %s err %.4f" % (nm, e))
    r["imported_jaw_axis_y_ue"] = [round(x, 5) for x in np.array((mw.to_3x3() @ jb.matrix_local.to_3x3()).col[1]) * TO_UE]
    return r


def check_clips(exp_bones, fails):
    ea = json.load(open(os.path.join(ANIMS, "expected_anims.json")))
    want = {b["name"]: b["parent"] for b in exp_bones}
    out = {}
    sc = bpy.context.scene
    for name, ce in ea["clips"].items():
        clean()
        objs = imp(os.path.join(ANIMS, ce["file"]))
        arms = [o for o in objs if o.type == "ARMATURE"]
        meshes = [o for o in objs if o.type == "MESH"]
        r = {"file": ce["file"], "actions": [a.name for a in bpy.data.actions]}
        out[name] = r
        if len(arms) != 1 or len(meshes) != 1 or arms[0].animation_data is None or arms[0].animation_data.action is None:
            fails.append("%s: no single animated armature + mesh" % name)
            continue
        arm = arms[0]
        got = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
        bad = sorted(set(got) ^ set(want)) + sorted(n for n in want if n in got and got[n] != want[n])
        r["bones"], r["bone_mismatch"] = len(got), bad
        if bad:
            fails.append("%s bones %s" % (name, bad))
        if len(bpy.data.actions) != 1:
            fails.append("%s actions %s" % (name, r["actions"]))
        act = arm.animation_data.action
        keyed = sorted({int(round(k.co[0])) for fc in fcurves(act) for k in fc.keyframe_points})
        r["keyed"] = [keyed[0], keyed[-1], len(keyed)] if keyed else []
        if not keyed or keyed[0] != ce["first"] or keyed[-1] != ce["last"] or len(keyed) != ce["samples"]:
            fails.append("%s keyed %s want %d..%d/%d" % (name, r["keyed"], ce["first"], ce["last"], ce["samples"]))
        rest = arm.matrix_world @ arm.data.bones["root"].matrix_local
        worst_root = 0.0
        for f in range(ce["first"], ce["last"] + 1):
            sc.frame_set(f)
            rm = arm.matrix_world @ arm.pose.bones["root"].matrix
            dq = rm.to_quaternion().rotation_difference(rest.to_quaternion()).angle
            worst_root = max(worst_root, (rm.translation - rest.translation).length, min(dq, 2 * math.pi - dq))
        mid = (ce["first"] + ce["last"]) // 2
        worst, at = 0.0, {}
        for f in sorted({ce["first"], mid, ce["last"]}):
            sc.frame_set(f)
            e = 0.0
            for n in ea["landmark_bones"]:
                t = arm.matrix_world @ arm.pose.bones[n].head
                e = max(e, float(np.linalg.norm(np.array((t.x, -t.y, t.z)) - np.array(ce["landmarks"][str(f)][n]))))
            at[str(f)] = round(e, 5)
            worst = max(worst, e)
        r.update({"landmark_err_cm_at": at, "landmark_max_err_cm": round(worst, 5), "root_max_dev": round(worst_root, 7)})
        if worst > TOL:
            fails.append("%s landmark err %.4f" % (name, worst))
        if worst_root > 1e-4:
            fails.append("%s root moves %.6f" % (name, worst_root))
        if ce["loop"]:
            l0, lN = ce["landmarks"][str(ce["first"])], ce["landmarks"][str(ce["last"])]
            sc.frame_set(ce["first"])
            a0 = {n: np.array(arm.pose.bones[n].head) for n in ea["landmark_bones"]}
            sc.frame_set(ce["last"])
            seam = max(float(np.linalg.norm(a0[n] - np.array(arm.pose.bones[n].head))) for n in a0)
            r["loop_seam_cm"] = round(seam, 6)
            if seam > 1e-3:
                fails.append("%s seam %.5f" % (name, seam))
        print("ROUNDTRIP %-17s %s" % (name, json.dumps({k: v for k, v in r.items() if k != "actions"})))
    return out


def check_static(path, e, fails, tag, quad=False):
    clean()
    objs = imp(path)
    meshes = [o for o in objs if o.type == "MESH"]
    r = {"objects": [o.name for o in objs]}
    if len(meshes) != 1:
        fails.append("%s meshes %d" % (tag, len(meshes)))
        return r
    m = meshes[0]
    m.data.calc_loop_triangles()
    v = verts_ue(m)
    r.update({"tris": len(m.data.loop_triangles), "slots": [x.name.split(".")[0] for x in m.data.materials],
              "bounds_err_cm": round(bounds_err(v, e["bounds_ue_cm"]), 5), "scale": [round(x, 6) for x in m.scale]})
    if r["tris"] != e["tris"] or r["slots"] != e["slots"] or r["bounds_err_cm"] > TOL:
        fails.append("%s %s vs %s" % (tag, r, {k: e[k] for k in ("tris", "slots")}))
    if quad:
        uv = m.data.uv_layers[0]
        us = np.array([d.uv[:] for d in uv.data])
        r["uv_min"], r["uv_max"] = us.min(0).round(4).tolist(), us.max(0).round(4).tolist()
        n = m.matrix_world.to_3x3() @ m.data.polygons[0].normal
        r["normal_ue"] = [round(n.x, 4), round(-n.y, 4), round(n.z, 4)]
        # U at the UE -Y edge (resident's left) must be 0
        vu = {}
        for p in m.data.polygons:
            for li in p.loop_indices:
                co = m.matrix_world @ m.data.vertices[m.data.loops[li].vertex_index].co
                vu[round(-co.y, 2)] = round(uv.data[li].uv[0], 3)
        r["u_by_ue_y"] = vu
        if r["uv_min"] != [0.0, 0.0] or r["uv_max"] != [1.0, 1.0] or r["normal_ue"][0] < 0.99:
            fails.append("%s uv/normal %s" % (tag, r))
    return r


def main():
    fails, rep = [], {}
    exp = json.load(open(os.path.join(VAL, "expected.json")))
    clean()
    objs = imp(os.path.join(VAL, "Cube10_Mars_SM.fbx"))
    c = [o for o in objs if o.type == "MESH"][0]
    v = verts_ue(c)
    rep["cube"] = {"bounds_min": v.min(0).round(4).tolist(), "bounds_max": v.max(0).round(4).tolist()}
    if np.abs(v.min(0) + 5).max() > 0.01 or np.abs(v.max(0) - 5).max() > 0.01:
        fails.append("cube %s" % rep["cube"])
    rep["bind"] = check_bind(exp, fails)
    rep["clips"] = check_clips(exp["bones"], fails)
    rep["den"] = check_static(os.path.join(OUT, "PantryRat_R01_Den_Mars_SM.fbx"), exp["den"], fails, "den")
    rep["den_eye_plate"] = check_static(os.path.join(OUT, "PantryRat_R01_DenEyePlate_Mars_SM.fbx"), exp["den_eye_plate"],
                                        fails, "plate", quad=True)
    rep["cheese"] = check_static(os.path.join(OUT, "PantryRat_R01_Cheese_Mars_SM.fbx"), exp["cheese"], fails, "cheese")
    rep["clip_count"] = len(rep["clips"])
    rep["fails"] = fails
    rep["tolerance_cm"] = TOL
    with open(os.path.join(ANIMS, "roundtrip_report.json"), "w") as fh:
        json.dump(rep, fh, indent=1, default=lambda o: o.tolist() if hasattr(o, "tolist") else str(o))
    print("ROUNDTRIP bind", json.dumps(rep["bind"]))
    print("ROUNDTRIP statics", json.dumps({k: rep[k] for k in ("den", "den_eye_plate", "cheese")}))
    if rep["clip_count"] != 34:
        fails.append("clips %d" % rep["clip_count"])
    if fails:
        print("PANTRY_RAT_FAIL " + "; ".join(fails))
        sys.exit(1)
    print("PANTRY_RAT_OK")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        print("PANTRY_RAT_FAIL exception")
        sys.exit(1)
