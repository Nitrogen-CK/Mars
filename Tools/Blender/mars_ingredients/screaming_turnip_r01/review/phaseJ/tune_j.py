"""Phase J scratch tuner: solve cr_dx / cr_dz for the crown-head target, report sockets, stem_gap, intersections."""
import sys, json
sys.path.insert(0, "D:/Repositories/CkRepos/Orion/Tools/Blender/mars_ingredients/screaming_turnip_r01/scripts")
import bpy, numpy as np
from mathutils import Vector
import build_screaming_turnip as BT
import animate_screaming_turnip as A
import turnip_audit
TO_UE = np.array([1.0, -1.0, 1.0])
arm = bpy.data.objects[BT.ARM_NAME]; ob = bpy.data.objects[BT.MESH_NAME]
arm.animation_data_create(); arm.animation_data.action = None
A.assign(ob.data.shape_keys, None)
meas = json.load(open("D:/Repositories/CkRepos/Orion/Tools/Blender/mars_ingredients/screaming_turnip_r01/review/phaseB4/measurements.json"))
hg = {n: Vector(meas["landmarks"]["sockets_blender_cm"][n]) for n in ("HarvestGrip_R", "HarvestGrip_L")}
crinv = arm.data.bones["crown"].matrix_local.inverted()

def measure(v, audit=False):
    BT.apply_params(arm, v)
    c = np.array(arm.matrix_world @ arm.pose.bones["crown"].head) * TO_UE
    M = arm.matrix_world @ arm.pose.bones["crown"].matrix @ crinv
    s = {n: np.array(M @ p) * TO_UE for n, p in hg.items()}
    out = {"crown": c.round(3).tolist(), "HG_R": s["HarvestGrip_R"].round(3).tolist(), "HG_L": s["HarvestGrip_L"].round(3).tolist()}
    if audit:
        co, tris, tp, tl = turnip_audit.evaluated(ob)
        out["stem_gap"] = [round(x, 3) for x in A.stem_gap(co, tris, tp, tl)]
        isx = turnip_audit.intersections(ob, BT.PART)
        out["isect"] = {k: x for k, x in isx.items() if x and "(info)" not in k and "(sum)" not in k}
        out["lvb"] = lvb_breakdown(ob)
        out["ext"] = [round(float(x), 2) for x in list(co.min(0)) + list(co.max(0))]
    return out

def lvb_breakdown(obj):
    from mathutils.bvhtree import BVHTree
    co, tris, tp, tl = turnip_audit.evaluated(obj)
    verts = [Vector(c) for c in co]
    P = BT.PART
    body = np.nonzero(np.isin(tp, [P[n] for n in ("bulb", "pad", "lip", "cavity", "gum", "taproot", "tooth")]))[0]
    tb = BVHTree.FromPolygons(verts, [tuple(tris[i]) for i in body], all_triangles=True, epsilon=0.0)
    res = {}
    for part in ("stem", "blade"):
        idx = np.nonzero(tp == P[part])[0]
        ta = BVHTree.FromPolygons(verts, [tuple(tris[i]) for i in idx], all_triangles=True, epsilon=0.0)
        for a, b in ta.overlap(tb):
            ga, gb = idx[a], body[b]
            if set(tris[ga]) & set(tris[gb]):
                continue
            k = "%s%d/z%.0f" % (part, tl[ga], co[tris[ga]].mean(0)[2])
            res[k] = res.get(k, 0) + 1
    return res

def solve(base, target):
    """crown head is affine in (cr_dx, cr_dz) given the rest of the pose: two probes + base."""
    I = BT.PIDX
    def at(dx, dz):
        v = base.copy(); v[I["cr_dx"]] = dx; v[I["cr_dz"]] = dz
        return np.array(measure(v)["crown"])
    p0 = at(0, 0); px = at(1, 0) - p0; pz = at(0, 1) - p0
    J = np.array([[px[0], pz[0]], [px[2], pz[2]]])
    sol = np.linalg.solve(J, np.array([target[0] - p0[0], target[1] - p0[2]]))
    return sol

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:]
    cfg = json.loads(argv[0])
    grip = measure(A.GRIP, True)
    print("GRIP", json.dumps(grip))
    g0 = grip["crown"]
    for name, spec in cfg.items():
        spec = dict(spec)
        la, lb = spec.pop("la"), spec.pop("lb")
        tgt = spec.pop("target")       # (dx, dz) from grip crown
        base = A.leaves(A.P(dict(spec, bdz=A.PLANT_DZ)), la=la, lb=lb)
        dx, dz = solve(base, (g0[0] + tgt[0], g0[2] + tgt[1]))
        v = base.copy(); v[BT.PIDX["cr_dx"]] = dx; v[BT.PIDX["cr_dz"]] = dz
        m = measure(v, True)
        m["d_crown"] = [round(m["crown"][0] - g0[0], 3), round(m["crown"][2] - g0[2], 3)]
        m["d_HG_R_x"] = round(m["HG_R"][0] - grip["HG_R"][0], 3)
        print("POSE", name, "cr_dx %.4f cr_dz %.4f" % (dx, dz), json.dumps(m))
    print("TURNIP_OK tune")
