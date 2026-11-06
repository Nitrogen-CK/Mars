"""Cellar Bat R01 - Blender round trip of the exported files (Phase 3: bind mesh, LOD1, LOD2, baked flap clip;
Phase 4: every clip FBX under export/anims, see check_anims, report export/anims/roundtrip_report.json).

Imports each FBX into a fresh background scene (1 BU = 1 cm like the source) and compares, in Unreal cm ((x, -y, z)),
against export/validation/expected.json and the source meshes in source/CellarBat_R01.blend:
  cube      one mesh, object scale 1, bounds +/-5 cm (0.01)
  each LOD  one armature (object scale 1) + one mesh; 42 bones, names and parents exact; bind heads within 0.1 cm;
            triangle count; slot names in order; bounds (0.1); every imported triangle matched to a source triangle by
            centroid (0.01 cm) with its face normal within 0.5 deg; per matched corner: vertex colour RGBA within 2/255
            and UV0 within 1e-4; UV0 present and non-overlapping (rasterised); max 4 influences, normalized; no shape
            keys on either side (no morphs are used)
  clip      one action, frames 0..15 (16); at the flap keys 0/4/8/12/15 the knuckle / wrist / thumb joints and the
            skinned mesh's lateral extremes within 0.1 cm
Writes export/validation/roundtrip_report.json. Prints CELLAR_BAT_OK or CELLAR_BAT_FAIL <reasons>.

Run:
  blender -b --factory-startup --python validate_roundtrip.py
"""
import json
import math
import os
import sys
import traceback

import bpy
import numpy as np
from mathutils import kdtree

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import bat_audit  # noqa: E402

ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "export")
VAL = os.path.join(OUT, "validation")
BLEND = os.path.join(ROOT, "source", "CellarBat_R01.blend")
TO_UE = np.array([1.0, -1.0, 1.0])
POS_TOL, CENT_TOL, NRM_TOL_DEG, CUBE_TOL, COL_TOL, UV_TOL = 0.1, 0.01, 0.5, 0.01, 2.0 / 255.0, 1e-4


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


def corners(obj):
    """Per triangle (polygon; the meshes are all triangles): centroid, normal (UE frame), corner positions, colours,
    UVs."""
    me = obj.data
    m = obj.matrix_world
    nm = m.to_3x3().inverted().transposed()
    ca = me.color_attributes.get("Col") or (me.color_attributes[0] if len(me.color_attributes) else None)
    col = None
    if ca is not None:
        col = np.empty(len(me.loops) * 4)
        if ca.domain == "CORNER":
            ca.data.foreach_get("color_srgb", col)
            col = col.reshape(-1, 4)
        else:
            cv = np.empty(len(me.vertices) * 4)
            ca.data.foreach_get("color_srgb", cv)
            cv = cv.reshape(-1, 4)
            vi = np.empty(len(me.loops), dtype=np.int64)
            me.loops.foreach_get("vertex_index", vi)
            col = cv[vi]
    uvl = me.uv_layers.get("UV0") or me.uv_layers.active
    uv = None
    if uvl is not None:
        uv = np.empty(len(me.loops) * 2)
        uvl.data.foreach_get("uv", uv)
        uv = uv.reshape(-1, 2)
    out = []
    for p in me.polygons:
        c = m @ p.center
        n = (nm @ p.normal).normalized()
        cps = []
        for li in p.loop_indices:
            v = m @ me.vertices[me.loops[li].vertex_index].co
            cps.append(((v.x, -v.y, v.z), None if col is None else col[li], None if uv is None else uv[li]))
        out.append(((c.x, -c.y, c.z), (n.x, -n.y, n.z), cps))
    return out, (None if ca is None else ca.name), (None if uvl is None else uvl.name)


def check_skeletal(path, src_mesh_name, exp, lod_exp, fails, tag):
    clean()
    objs = imp(path)
    arms = [o for o in objs if o.type == "ARMATURE"]
    meshes = [o for o in objs if o.type == "MESH"]
    sk = {"file": os.path.basename(path), "objects": [(o.name, o.type) for o in objs]}
    if len(arms) != 1 or len(meshes) != 1:
        fails.append("%s: %d armatures %d meshes" % (tag, len(arms), len(meshes)))
        return sk
    arm, me = arms[0], meshes[0]
    sk["armature_object"] = {"name": arm.name, "scale": [round(x, 6) for x in arm.scale],
                             "rotation": [round(x, 6) for x in arm.rotation_euler], "location": list(arm.location)}
    if np.abs(np.array(arm.scale) - 1).max() > 1e-5:
        fails.append("%s armature object scale %s" % (tag, list(arm.scale)))
    got = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
    want = {b["name"]: b["parent"] for b in exp["bones"]}
    extra, missing = sorted(set(got) - set(want)), sorted(set(want) - set(got))
    wrongp = sorted(n for n in want if n in got and got[n] != want[n])
    sk.update({"bone_count": len(got), "extra_bones": extra, "missing_bones": missing, "wrong_parents": wrongp})
    if extra or missing or wrongp:
        fails.append("%s hierarchy extra %s missing %s parents %s" % (tag, extra, missing, wrongp))
    mw = arm.matrix_world
    dmax = 0.0
    for b in exp["bones"]:
        if b["name"] in arm.data.bones:
            h = mw @ arm.data.bones[b["name"]].head_local
            dmax = max(dmax, float(np.linalg.norm(np.array((h.x, -h.y, h.z)) - np.array(b["head_ue_cm"]))))
    sk["max_bind_head_error_cm"] = round(dmax, 5)
    if dmax > POS_TOL:
        fails.append("%s bind head error %.4f" % (tag, dmax))
    me.data.calc_loop_triangles()
    sk["tris"] = len(me.data.loop_triangles)
    sk["all_triangles"] = all(len(p.vertices) == 3 for p in me.data.polygons)
    if sk["tris"] != lod_exp["tris"] or not sk["all_triangles"]:
        fails.append("%s tris %d != %d" % (tag, sk["tris"], lod_exp["tris"]))
    sk["slots"] = [m.name.split(".")[0] for m in me.data.materials]
    if sk["slots"] != lod_exp["slots"]:
        fails.append("%s slots %s" % (tag, sk["slots"]))
    v = world_verts(me)
    sk["bounds_min"], sk["bounds_max"] = v.min(0).round(3).tolist(), v.max(0).round(3).tolist()
    bd = max(np.abs(v.min(0) - lod_exp["bounds_ue_cm"]["min"]).max(), np.abs(v.max(0) - lod_exp["bounds_ue_cm"]["max"]).max())
    sk["bounds_error_cm"] = round(float(bd), 5)
    sk["span_cm"] = round(float(v[:, 1].max() - v[:, 1].min()), 3)
    if bd > POS_TOL:
        fails.append("%s bounds error %.4f" % (tag, bd))
    # semantic triangle + corner match against the source mesh
    with bpy.data.libraries.load(BLEND, link=False) as (src, dst):
        dst.meshes = [src_mesh_name]
    sobj = bpy.data.objects.new("_src", dst.meshes[0])
    bpy.context.scene.collection.objects.link(sobj)
    scs, s_col_name, s_uv_name = corners(sobj)
    ics, i_col_name, i_uv_name = corners(me)
    kd = kdtree.KDTree(len(scs))
    for i, t in enumerate(scs):
        kd.insert(t[0], i)
    kd.balance()
    worst_c, worst_n, unmatched, col_err, uv_err, col_bad, uv_bad = 0.0, 0.0, 0, 0.0, 0.0, 0, 0
    for c, n, cps in ics:
        _co, idx, dist = kd.find(c)
        worst_c = max(worst_c, dist)
        sn = scs[idx][1]
        ang = math.degrees(math.acos(max(-1.0, min(1.0, float(np.dot(n, sn))))))
        worst_n = max(worst_n, ang)
        if dist > CENT_TOL or ang > NRM_TOL_DEG:
            unmatched += 1
            continue
        for p, colv, uvv in cps:
            sp = min(scs[idx][2], key=lambda s: (np.array(s[0]) - np.array(p)) @ (np.array(s[0]) - np.array(p)))
            if colv is not None and sp[1] is not None:
                e = float(np.abs(np.array(colv) - np.array(sp[1])).max())
                col_err = max(col_err, e)
                col_bad += e > COL_TOL
            if uvv is not None and sp[2] is not None:
                e = float(np.abs(np.array(uvv) - np.array(sp[2])).max())
                uv_err = max(uv_err, e)
                uv_bad += e > UV_TOL
    sk.update({"tri_centroid_max_err_cm": round(worst_c, 5), "tri_normal_max_err_deg": round(worst_n, 4),
               "tri_unmatched": unmatched, "colour_attribute": i_col_name, "colour_rgba_max_err": round(col_err, 5),
               "colour_corners_out_of_tol": col_bad, "uv_layer": i_uv_name, "uv_max_err": round(uv_err, 6),
               "uv_corners_out_of_tol": uv_bad})
    if unmatched:
        fails.append("%s %d triangles unmatched (centroid %.4f normal %.3f)" % (tag, unmatched, worst_c, worst_n))
    if i_col_name is None or col_bad:
        fails.append("%s vertex colours %s bad %d" % (tag, i_col_name, col_bad))
    if i_uv_name is None or uv_bad:
        fails.append("%s UV0 %s bad %d" % (tag, i_uv_name, uv_bad))
    uvo = bat_audit.uv_overlap(me)
    sk["uv_overlap"] = uvo
    if uvo.get("overlap_px", 1) or uvo.get("out_of_range_loops", 1):
        fails.append("%s imported UV overlap %s" % (tag, uvo))
    sk["shape_keys_imported"] = 0 if me.data.shape_keys is None else len(me.data.shape_keys.key_blocks)
    sk["shape_keys_source"] = 0 if sobj.data.shape_keys is None else len(sobj.data.shape_keys.key_blocks)
    if sk["shape_keys_imported"] != sk["shape_keys_source"]:
        fails.append("%s morph count %d != %d" % (tag, sk["shape_keys_imported"], sk["shape_keys_source"]))
    bpy.data.objects.remove(sobj, do_unlink=True)
    maxinf, bad = 0, 0
    for vtx in me.data.vertices:
        ws = [g.weight for g in vtx.groups if g.weight > 1e-6]
        maxinf = max(maxinf, len(ws))
        if not ws or abs(sum(ws) - 1) > 1e-3:
            bad += 1
    sk["max_influences"], sk["unnormalized_or_unweighted"] = maxinf, bad
    if maxinf > 4 or bad:
        fails.append("%s weights maxinf %d bad %d" % (tag, maxinf, bad))
    return sk


ANIMS = os.path.join(OUT, "anims")


def check_anims(exp_bones, fails):
    """Phase 4: every clip FBX in export/anims (expected_anims.json from export_anims_cellar_bat.py), each imported
    into a fresh scene: one armature + one mesh, the 42 bones with their parents, one action, frame range, the root
    bone identical to its rest on every sample, loop seam (first == last), every sampled landmark (knuckles,
    wrists, head, jaw, ankles, ear) on EVERY frame within 0.1 cm, and the skinned mesh extremes at the first/last frames and at
    the flap keys 0/4/8/12/15 of Hover and FlyForward."""
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
        if len(arms) != 1 or len(meshes) != 1 or arms[0].animation_data is None or \
                arms[0].animation_data.action is None:
            fails.append("%s: no single animated armature + mesh (%d/%d)" % (name, len(arms), len(meshes)))
            continue
        arm, me = arms[0], meshes[0]
        got = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
        bad = sorted(set(got) ^ set(want)) + sorted(n for n in want if n in got and got[n] != want[n])
        r["bones"] = len(got)
        r["bone_mismatch"] = bad
        if bad:
            fails.append("%s bones %s" % (name, bad))
        if len(bpy.data.actions) != 1:
            fails.append("%s actions %s" % (name, r["actions"]))
        act = arm.animation_data.action
        fr = [round(x, 4) for x in act.frame_range]
        keyed = sorted({int(round(k.co[0])) for fc in _fcurves(act) for k in fc.keyframe_points})
        r["frame_range"] = fr
        r["keyed_frames"] = [keyed[0], keyed[-1], len(keyed)] if keyed else []
        r["samples"] = len(keyed)
        if not keyed or keyed[0] != ce["first"] or keyed[-1] != ce["last"] or len(keyed) != ce["samples"]:
            fails.append("%s keyed frames %s (want %d..%d, %d samples)" % (name, r["keyed_frames"], ce["first"],
                                                                          ce["last"], ce["samples"]))
        root_rest = arm.matrix_world @ arm.data.bones["root"].matrix_local
        worst_b, worst_m, worst_root = 0.0, 0.0, 0.0
        first_lm, last_lm = None, None
        for f, k in ce["landmarks"].items():
            sc.frame_set(int(f))
            bpy.context.view_layer.update()
            rm = arm.matrix_world @ arm.pose.bones["root"].matrix
            dq = rm.to_quaternion().rotation_difference(root_rest.to_quaternion()).angle
            worst_root = max(worst_root, (rm.translation - root_rest.translation).length, min(dq, 2 * math.pi - dq))
            lm = {}
            for n in ea["landmark_bones"]:
                t = arm.matrix_world @ arm.pose.bones[n].head
                lm[n] = np.array((t.x, -t.y, t.z))
                worst_b = max(worst_b, float(np.linalg.norm(lm[n] - np.array(k[n]))))
            if int(f) == ce["first"]:
                first_lm = lm
            if int(f) == ce["last"]:
                last_lm = lm
            if "mesh" in k:   # scalar extremes (a point extreme can swap between two near-equal wing tips)
                v = world_verts(me, evaluated=True)
                em = max(abs(float(v[:, 1].max()) - k["mesh"]["max_y_point"][1]),
                         abs(float(v[:, 1].min()) - k["mesh"]["min_y_point"][1]),
                         abs(float(v[:, 2].max()) - k["mesh"]["max_z"]), abs(float(v[:, 2].min()) - k["mesh"]["min_z"]))
                worst_m = max(worst_m, em)
        r.update({"landmark_max_err_cm": round(worst_b, 5), "mesh_extreme_max_err_cm": round(worst_m, 5),
                  "root_max_dev": round(worst_root, 7)})
        if worst_b > POS_TOL or worst_m > POS_TOL:
            fails.append("%s landmark error bone %.4f mesh %.4f" % (name, worst_b, worst_m))
        if worst_root > 1e-4:
            fails.append("%s root moves %.6f" % (name, worst_root))
        if ce["loop"]:
            seam = max(float(np.linalg.norm(first_lm[n] - last_lm[n])) for n in first_lm)
            r["loop_seam_landmark_err_cm"] = round(seam, 6)
            if seam > 1e-3:
                fails.append("%s loop seam %.5f" % (name, seam))
        print("ROUNDTRIP anim %-15s %s" % (name, json.dumps(r)))
    return out


def _fcurves(action):
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


def main():
    fails, rep = [], {}
    exp = json.load(open(os.path.join(VAL, "expected.json")))

    # ---- cube
    clean()
    objs = imp(os.path.join(VAL, "Cube10_Mars_SM.fbx"))
    meshes = [o for o in objs if o.type == "MESH"]
    if len(meshes) != 1:
        fails.append("cube: %d meshes" % len(meshes))
    else:
        c = meshes[0]
        v = world_verts(c)
        rep["cube"] = {"objects": [o.name for o in objs], "object_scale": list(c.scale),
                       "bounds_min": v.min(0).round(4).tolist(), "bounds_max": v.max(0).round(4).tolist()}
        if np.abs(v.min(0) + 5).max() > CUBE_TOL or np.abs(v.max(0) - 5).max() > CUBE_TOL:
            fails.append("cube bounds %s %s" % (v.min(0), v.max(0)))
        if np.abs(np.array(c.scale) - 1).max() > 1e-6:
            fails.append("cube object scale %s" % list(c.scale))

    # ---- bind mesh + LODs
    rep["lods"] = {}
    for lod, le in sorted(exp["lods"].items()):
        rep["lods"][lod] = check_skeletal(os.path.join(OUT, le["file"]), le["object"], exp, le, fails, "LOD" + lod)

    # ---- clip
    clean()
    objs = imp(os.path.join(VAL, exp["flap"]["file"]))
    arms = [o for o in objs if o.type == "ARMATURE"]
    meshes = [o for o in objs if o.type == "MESH"]
    cl = {"file": exp["flap"]["file"], "actions": [a.name for a in bpy.data.actions]}
    if len(arms) != 1 or len(meshes) != 1 or arms[0].animation_data is None or arms[0].animation_data.action is None:
        fails.append("clip: import has no single animated armature")
    else:
        arm, me = arms[0], meshes[0]
        act = arm.animation_data.action
        fr = [round(x, 4) for x in act.frame_range]
        cl["frame_range"] = fr
        cl["frames"] = int(round(fr[1] - fr[0])) + 1
        if fr != [0.0, 15.0]:
            fails.append("clip frame range %s" % fr)
        if len(bpy.data.actions) != 1:
            fails.append("clip actions %s" % cl["actions"])
        sc = bpy.context.scene
        worst_bone, worst_mesh, per = 0.0, 0.0, {}
        for f, k in exp["flap"]["keys"].items():
            sc.frame_set(int(f))
            bpy.context.view_layer.update()
            eb = 0.0
            for n in ("finger_01b_l", "finger_01b_r", "finger_03b_l", "wrist_l", "wrist_r", "thumb_b_l"):
                t = arm.matrix_world @ arm.pose.bones[n].head
                eb = max(eb, float(np.linalg.norm(np.array((t.x, -t.y, t.z)) - np.array(k[n]))))
            v = world_verts(me, evaluated=True)
            mx, mn = v[np.argmax(v[:, 1])], v[np.argmin(v[:, 1])]
            em = max(float(np.linalg.norm(mx - np.array(k["mesh"]["max_y_point"]))),
                     float(np.linalg.norm(mn - np.array(k["mesh"]["min_y_point"]))),
                     abs(float(v[:, 2].max()) - k["mesh"]["max_z"]), abs(float(v[:, 2].min()) - k["mesh"]["min_z"]))
            per[f] = {"bone_head_err_cm": round(eb, 5), "mesh_wingtip_err_cm": round(em, 5)}
            worst_bone, worst_mesh = max(worst_bone, eb), max(worst_mesh, em)
        cl.update({"keys": per, "max_bone_err_cm": round(worst_bone, 5), "max_mesh_err_cm": round(worst_mesh, 5)})
        if worst_bone > POS_TOL or worst_mesh > POS_TOL:
            fails.append("clip landmark error bone %.4f mesh %.4f" % (worst_bone, worst_mesh))
    rep["clip"] = cl
    if os.path.exists(os.path.join(ANIMS, "expected_anims.json")):
        afails = []
        rep["anims"] = check_anims(exp["bones"], afails)
        rep["anims_fails"] = afails
        fails.extend(afails)
        with open(os.path.join(ANIMS, "roundtrip_report.json"), "w") as fh:
            json.dump({"clips": rep["anims"], "fails": afails, "tolerance_cm": POS_TOL}, fh, indent=1,
                      default=lambda o: o.tolist() if hasattr(o, "tolist") else str(o))
    rep["fails"] = fails
    with open(os.path.join(VAL, "roundtrip_report.json"), "w") as fh:
        json.dump(rep, fh, indent=1, default=lambda o: o.tolist() if hasattr(o, "tolist") else str(o))
    for lod, s in rep["lods"].items():
        print("ROUNDTRIP LOD%s %s" % (lod, json.dumps({k: v for k, v in s.items() if k not in ("objects", "uv_overlap")})))
    print("ROUNDTRIP clip %s" % json.dumps(cl))
    if fails:
        print("CELLAR_BAT_FAIL " + "; ".join(fails))
        sys.exit(1)
    print("CELLAR_BAT_OK")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        print("CELLAR_BAT_FAIL exception")
        sys.exit(1)
