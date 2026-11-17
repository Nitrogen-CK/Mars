"""Pale Crawler R01 - FBX round-trip validator (contract: SCHEMA.md beside this file).

Run:
    blender -b --factory-startup --python validate_roundtrip.py -- --export-dir <dir> [--report <path>]

For every mesh in <dir>/PaleCrawler_R01_Assembly.json it imports <Mesh>.fbx into an empty scene, bakes the object's world
matrix into the geometry, maps each Blender vertex v (metres) to Unreal cm as (100 v.x, -100 v.y, 100 v.z) and compares it
with the sidecar <Mesh>.json and the authored triangles in <Mesh>.tris.json (same local frame, cm):
  triangle count exact, every imported polygon a triangle; bounds per axis within BOUNDS_TOL_CM; slot names exact and in
  order (a Blender ".001" suffix is stripped and reported); every imported triangle matched to an authored one by centroid
  within CENTROID_TOL_CM, its winding normal and its corner normals within NORMAL_TOL_DEG of the authored normal (a
  mirrored import flips every normal); per-triangle slot index; no loose vertices, no open/non-manifold edges, no
  zero-area triangles.
Then, for every pose (neutral required), each instance's rotation_cols must be orthonormal with det +1 (ROT_TOL), and the
sidecar joints_local placed by the instance must land on the manifest's leg hip/knee/foot and chelicera root/tip within
JOINT_TOL_CM. Writes a JSON report (default <dir>/../review/roundtrip_report.json), prints one line per mesh, then
ROUNDTRIP_OK or ROUNDTRIP_FAIL with the reasons; exit code 0 / 1.
"""
import argparse
import json
import math
import os
import re
import sys
import traceback

import bpy
import numpy as np
from mathutils import Vector, kdtree

# Fixed tolerances. Never relax one to make a build pass: a failure here is a builder or exporter bug.
BOUNDS_TOL_CM = 0.05      # per-axis |imported - sidecar| bounds
CENTROID_TOL_CM = 0.01    # imported triangle centroid to its authored triangle centroid
NORMAL_TOL_DEG = 0.5      # winding normal and corner normals vs the authored normal
JOINT_TOL_CM = 0.1        # placed joints_local vs manifest leg / chelicera joints
ROT_TOL = 1e-6            # |R^T R - I| max and |det R - 1|
ZERO_AREA_CM2 = 1e-6      # a triangle below this area is degenerate

MANIFEST = "PaleCrawler_R01_Assembly.json"
SUFFIX = re.compile(r"\.\d{3}$")
TO_UE = np.array([100.0, -100.0, 100.0])
DIR_UE = np.array([1.0, -1.0, 1.0])


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(prog="validate_roundtrip.py")
    ap.add_argument("--export-dir", required=True)
    ap.add_argument("--report", default=None)
    return ap.parse_args(argv)


def clean_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials):
        for d in list(coll):
            coll.remove(d)


def unit(v):
    n = np.linalg.norm(v, axis=-1, keepdims=True)
    return np.divide(v, n, out=np.zeros_like(v), where=n > 0)


def angles_deg(a, b):
    return np.degrees(np.arccos(np.clip(np.sum(unit(a) * unit(b), axis=-1), -1.0, 1.0)))


def import_fbx(path):
    """The single mesh in path, world matrix baked, as Unreal-cm arrays."""
    clean_scene()
    bpy.ops.import_scene.fbx(filepath=path)
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    if len(objs) != 1:
        raise RuntimeError("expected 1 mesh object in %s, got %d" % (os.path.basename(path), len(objs)))
    obj = objs[0]
    me = obj.data
    det = obj.matrix_world.to_3x3().determinant()
    me.transform(obj.matrix_world)
    me.update()
    nv, npoly, nl, ne = len(me.vertices), len(me.polygons), len(me.loops), len(me.edges)
    co = np.empty(nv * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(nv, 3)
    total, start, mat = (np.empty(npoly, dtype=np.int64) for _ in range(3))
    me.polygons.foreach_get("loop_total", total)
    me.polygons.foreach_get("loop_start", start)
    me.polygons.foreach_get("material_index", mat)
    lv, le = np.empty(nl, dtype=np.int64), np.empty(nl, dtype=np.int64)
    me.loops.foreach_get("vertex_index", lv)
    me.loops.foreach_get("edge_index", le)
    cn = np.empty(nl * 3)
    if hasattr(me, "corner_normals"):
        me.corner_normals.foreach_get("vector", cn)
    else:
        me.loops.foreach_get("normal", cn)
    edge_faces = np.bincount(le, minlength=ne)
    return {"co_b": co, "co_ue": co * TO_UE, "total": total, "start": start, "mat": mat, "lv": lv,
            "corner_n_ue": cn.reshape(nl, 3) * DIR_UE, "slots": [m.name if m else "" for m in me.materials],
            "loose": int(nv - np.unique(lv).size), "open_edges": int(np.sum(edge_faces < 2)),
            "nonmanifold_edges": int(np.sum(edge_faces > 2)), "matrix_det": round(float(det), 6),
            "custom_normals": bool(getattr(me, "has_custom_normals", False))}


def check_mesh(export_dir, name):
    r = {"name": name, "fails": [], "notes": []}
    fail = r["fails"].append
    side = json.load(open(os.path.join(export_dir, name + ".json")))
    tris = json.load(open(os.path.join(export_dir, name + ".tris.json")))
    imp = import_fbx(os.path.join(export_dir, side.get("fbx", name + ".fbx")))
    r["matrix_det"], r["custom_normals"] = imp["matrix_det"], imp["custom_normals"]
    if imp["matrix_det"] < 0:
        fail("imported object matrix has det %.4f (negative scale in the FBX)" % imp["matrix_det"])

    # triangle count, all triangles
    r["tris"] = [int(imp["total"].size), int(side["tris"])]
    non_tri = int(np.sum(imp["total"] != 3))
    r["non_triangles"] = non_tri
    if imp["total"].size != side["tris"]:
        fail("tris %d != sidecar %d" % (imp["total"].size, side["tris"]))
    if len(tris["triangles"]) != side["tris"]:
        fail("tris.json has %d triangles, sidecar %d" % (len(tris["triangles"]), side["tris"]))
    if non_tri:
        fail("%d imported polygons are not triangles" % non_tri)

    # bounds
    lo, hi = imp["co_ue"].min(axis=0), imp["co_ue"].max(axis=0)
    d = np.maximum(np.abs(lo - side["bounds_min"]), np.abs(hi - side["bounds_max"]))
    r["bounds_min"], r["bounds_max"] = np.round(lo, 4).tolist(), np.round(hi, 4).tolist()
    r["bounds_max_diff"] = round(float(d.max()), 5)
    if d.max() > BOUNDS_TOL_CM:
        fail("bounds off by %.4f cm (axis diffs %s)" % (d.max(), np.round(d, 4).tolist()))
    auth = np.asarray(tris["triangles"], float).reshape(-1, 3, 3)
    ad = np.maximum(np.abs(auth.reshape(-1, 3).min(axis=0) - side["bounds_min"]),
                    np.abs(auth.reshape(-1, 3).max(axis=0) - side["bounds_max"])).max() if auth.size else 0.0
    if ad > BOUNDS_TOL_CM:
        fail("tris.json bounds differ from the sidecar by %.4f cm (not the same local frame?)" % ad)

    # slots
    stripped = [SUFFIX.sub("", s) for s in imp["slots"]]
    r["slots"] = stripped
    if stripped != imp["slots"]:
        r["notes"].append("stripped suffix: %s" % [s for s in imp["slots"] if SUFFIX.search(s)])
    if stripped != list(side["slots"]):
        fail("slots %s != sidecar %s" % (stripped, side["slots"]))

    # sanity
    r.update({k: imp[k] for k in ("loose", "open_edges", "nonmanifold_edges")})
    if imp["loose"]:
        fail("%d loose vertices" % imp["loose"])
    if imp["open_edges"] or imp["nonmanifold_edges"]:
        fail("%d open edges, %d non-manifold edges" % (imp["open_edges"], imp["nonmanifold_edges"]))
    if non_tri:
        r["ok"] = False
        return r, imp

    # orientation: winding normal in Blender space mapped to Unreal (the y flip is a reflection, so the normal maps as
    # a direction while the Unreal-space cross product would come out negated)
    idx = imp["lv"][imp["start"][:, None] + np.arange(3)]
    tb, tu = imp["co_b"][idx], imp["co_ue"][idx]
    n_imp = np.cross(tb[:, 1] - tb[:, 0], tb[:, 2] - tb[:, 0]) * DIR_UE
    area = 0.5 * np.linalg.norm(np.cross(tu[:, 1] - tu[:, 0], tu[:, 2] - tu[:, 0]), axis=1)
    r["zero_area"] = int(np.sum(area < ZERO_AREA_CM2))
    if r["zero_area"]:
        fail("%d zero-area triangles" % r["zero_area"])
    # authored winding is CCW seen from outside in the right-handed Unreal frame, so its plain cross product is outward
    n_wind = np.cross(auth[:, 1] - auth[:, 0], auth[:, 2] - auth[:, 0])
    if "normals" in tris:
        n_auth = np.asarray(tris["normals"], float)
        wa = angles_deg(n_wind, n_auth)
        r["max_authored_winding_angle_deg"] = round(float(wa.max()), 4) if wa.size else None
        if wa.size and wa.max() > NORMAL_TOL_DEG:
            fail("tris.json winding disagrees with its normals by up to %.2f deg on %d triangles" % (
                wa.max(), int(np.sum(wa > NORMAL_TOL_DEG))))
    else:
        n_auth = n_wind
        r["notes"].append("tris.json has no normals; derived from the authored (Unreal CCW) winding")
    slot_auth = np.asarray(tris.get("slot_index", []), dtype=np.int64)
    c_auth, c_imp = auth.mean(axis=1), tu.mean(axis=1)
    kd = kdtree.KDTree(len(c_auth))
    for i, c in enumerate(c_auth):
        kd.insert(Vector(c), i)
    kd.balance()
    match = np.full(len(c_imp), -1, dtype=np.int64)
    for i, c in enumerate(c_imp):
        cands = [j for _, j, _ in kd.find_range(Vector(c), CENTROID_TOL_CM)]
        if cands:
            match[i] = min(cands, key=lambda j: angles_deg(n_imp[i], n_auth[j]))
    ok_m = match >= 0
    r["unmatched_centroids"] = int(np.sum(~ok_m))
    r["authored_unmatched"] = int(len(c_auth) - np.unique(match[ok_m]).size)
    if r["unmatched_centroids"] or r["authored_unmatched"]:
        fail("%d imported triangles without an authored centroid, %d authored triangles unmatched" % (
            r["unmatched_centroids"], r["authored_unmatched"]))
    face_ang = angles_deg(n_imp[ok_m], n_auth[match[ok_m]])
    r["max_normal_angle_deg"] = round(float(face_ang.max()), 4) if face_ang.size else None
    if face_ang.size and face_ang.max() > NORMAL_TOL_DEG:
        fail("winding normal off by up to %.2f deg on %d triangles (mirrored or flipped?)" % (
            face_ang.max(), int(np.sum(face_ang > NORMAL_TOL_DEG))))
    corner = imp["corner_n_ue"][imp["start"][:, None] + np.arange(3)]
    loop_ang = angles_deg(corner[ok_m], n_auth[match[ok_m]][:, None, :])
    r["max_loop_normal_angle_deg"] = round(float(loop_ang.max()), 4) if loop_ang.size else None
    r["loop_normals_ok"] = bool(loop_ang.size == 0 or loop_ang.max() <= NORMAL_TOL_DEG)
    if not r["loop_normals_ok"]:
        fail("corner normals off by up to %.2f deg" % loop_ang.max())
    if slot_auth.size == len(c_auth):
        bad = int(np.sum(imp["mat"][ok_m] != slot_auth[match[ok_m]]))
        r["slot_index_mismatches"] = bad
        if bad:
            fail("%d triangles on the wrong slot" % bad)
    else:
        r["notes"].append("tris.json slot_index missing or wrong length; per-triangle slot not checked")
    r["ok"] = not r["fails"]
    return r, imp


def check_poses(manifest, sidecars, local_pts):
    out, fails = {}, []
    poses = manifest.get("poses", {})
    if "neutral" not in poses:
        fails.append("manifest has no neutral pose")
    for pname, pose in poses.items():
        legs = {l["id"]: l for l in pose.get("legs", [])}
        chel = {c["id"]: c for c in pose.get("chelicerae", [])}
        rows, max_err = [], 0.0
        for inst in pose.get("instances", []):
            iid, mesh = inst["id"], inst["mesh"]
            R, t = np.asarray(inst["rotation_cols"], float).T, np.asarray(inst["location"], float)
            orth, det = float(np.abs(R.T @ R - np.eye(3)).max()), float(np.linalg.det(R))
            row = {"id": iid, "mesh": mesh, "orth_err": orth, "det": round(det, 9), "joints": {}}
            if orth > ROT_TOL or abs(det - 1.0) > ROT_TOL:
                fails.append("%s %s: rotation_cols not proper (orth err %.2e, det %.6f)" % (pname, iid, orth, det))
            if mesh not in sidecars:
                fails.append("%s %s: unknown mesh %s" % (pname, iid, mesh))
                rows.append(row)
                continue
            if mesh in local_pts:
                w = local_pts[mesh] @ R.T + t
                row["world_min"], row["world_max"] = np.round(w.min(0), 3).tolist(), np.round(w.max(0), 3).tolist()
            prefix, _, part = iid.partition(".")
            targets = []
            if part in ("Upper", "Lower"):
                leg = legs.get(prefix)
                if leg is None:
                    fails.append("%s %s: no leg %s in the manifest" % (pname, iid, prefix))
                else:
                    targets = [("proximal", leg["hip"]), ("distal", leg["knee"])] if part == "Upper" else \
                              [("proximal", leg["knee"]), ("distal", leg["foot"])]
            elif prefix == "Chelicera":
                c = chel.get(part)
                if c is None:
                    fails.append("%s %s: no chelicera %s in the manifest" % (pname, iid, part))
                else:
                    targets = [("root", c["root"]), ("tip", c["tip"])]
            jl = sidecars[mesh].get("joints_local", {})
            for key, target in targets:
                if key not in jl:
                    fails.append("%s %s: %s has no joints_local.%s" % (pname, iid, mesh, key))
                    continue
                err = float(np.linalg.norm(R @ np.asarray(jl[key], float) + t - np.asarray(target, float)))
                row["joints"][key] = round(err, 4)
                max_err = max(max_err, err)
                if err > JOINT_TOL_CM:
                    fails.append("%s %s: joint %s off by %.3f cm" % (pname, iid, key, err))
            rows.append(row)
        out[pname] = {"instances": len(rows), "max_joint_err_cm": round(max_err, 4), "rows": rows}
    return out, fails


def run(args):
    export_dir = os.path.abspath(args.export_dir)
    report = {"export_dir": export_dir, "ok": False, "fails": [],
              "tolerances": {"bounds_cm": BOUNDS_TOL_CM, "centroid_cm": CENTROID_TOL_CM, "normal_deg": NORMAL_TOL_DEG,
                             "joint_cm": JOINT_TOL_CM, "rotation": ROT_TOL, "zero_area_cm2": ZERO_AREA_CM2}}
    mpath = os.path.join(export_dir, MANIFEST)
    if not os.path.isfile(mpath):
        report["fails"].append("manifest not found: %s" % mpath)
        return report
    manifest = json.load(open(mpath))
    meshes, sidecars, local_pts = {}, {}, {}
    for name in manifest.get("meshes", {}):
        try:
            sidecars[name] = json.load(open(os.path.join(export_dir, name + ".json")))
            res, imp = check_mesh(export_dir, name)
            local_pts[name] = imp["co_ue"]
            for k in ("tris", "slots", "bounds_min", "bounds_max", "joints_local"):
                if k in manifest["meshes"][name] and manifest["meshes"][name][k] != sidecars[name].get(k):
                    res["fails"].append("manifest meshes.%s.%s differs from the sidecar" % (name, k))
                    res["ok"] = False
        except (OSError, ValueError, KeyError, RuntimeError) as e:
            res = {"name": name, "ok": False, "fails": ["%s: %s" % (type(e).__name__, e)], "notes": []}
        meshes[name] = res
        print("%-44s %s  tris %s  bounds %s  slots %s  unmatched %s  maxN %s  loopN %s  open %s" % (
            name, "OK  " if res["ok"] else "FAIL", res.get("tris"), res.get("bounds_max_diff"), res.get("slots"),
            res.get("unmatched_centroids"), res.get("max_normal_angle_deg"), res.get("max_loop_normal_angle_deg"),
            res.get("open_edges")))
        report["fails"] += ["%s: %s" % (name, f) for f in res["fails"]]
    if not meshes:
        report["fails"].append("manifest lists no meshes")
    report["meshes"] = meshes
    report["poses"], pose_fails = check_poses(manifest, sidecars, local_pts)
    report["fails"] += pose_fails
    report["totals"] = {"meshes": len(meshes), "meshes_ok": sum(1 for m in meshes.values() if m["ok"]),
                        "imported_tris": sum(m["tris"][0] for m in meshes.values() if m.get("tris")),
                        "instances": {p: v["instances"] for p, v in report["poses"].items()}}
    report["ok"] = not report["fails"]
    return report


def main():
    args = parse_args()
    try:
        report = run(args)
    except Exception:
        traceback.print_exc()
        report = {"ok": False, "fails": ["unexpected error: %s" % traceback.format_exc().strip().splitlines()[-1]]}
    path = args.report or os.path.join(os.path.dirname(os.path.abspath(args.export_dir)), "review", "roundtrip_report.json")
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as fh:
            json.dump(report, fh, indent=1)
        print("report: %s" % path)
    except OSError as e:
        print("could not write report %s: %s" % (path, e))
    if report["ok"]:
        print("ROUNDTRIP_OK")
    else:
        print("ROUNDTRIP_FAIL")
        for f in report["fails"]:
            print("  - " + f)
    sys.stdout.flush()
    sys.exit(0 if report["ok"] else 1)


if __name__ == "__main__":
    main()
