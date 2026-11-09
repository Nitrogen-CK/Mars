"""Phase J scratch: sweep STRAIN variants; audit every frame of SRC_Tug / Cancel / Release (leaf_vs_bulb, all isect, stem_gap)."""
import sys, json, time
sys.path.insert(0, "D:/Repositories/CkRepos/Orion/Tools/Blender/mars_ingredients/screaming_turnip_r01/scripts")
import bpy, numpy as np
import build_screaming_turnip as BT
import animate_screaming_turnip as A
import turnip_audit
arm = bpy.data.objects[BT.ARM_NAME]; ob = bpy.data.objects[BT.MESH_NAME]
arm.animation_data_create(); arm.animation_data.action = None
A.assign(ob.data.shape_keys, None)
I = BT.PIDX

sys.path.insert(0, "C:/Users/Adam/AppData/Local/Temp/claude/a4fa63a51a3851ec/eba07880-c480-4a76-9133-a9f9d7dbb38f/scratchpad")
import tune_j as TJ
G0 = TJ.measure(A.GRIP)["crown"]

def mk(d, base=None):
    d = dict(d)
    tgt = d.pop("target", None)
    if tgt is not None:
        probe = mk(d, base)
        dx, dz = TJ.solve(probe, (G0[0] + tgt[0], G0[2] + tgt[1]))
        d["cr_dx"], d["cr_dz"] = round(float(dx), 3), round(float(dz), 3)
        print("SOLVED", json.dumps(d), flush=True)
    la = d.pop("la", -12.0); lb = d.pop("lb", -7.0)
    if base is None:
        return A.leaves(A.P(dict(d, bdz=A.PLANT_DZ)), la=la, lb=lb)
    return A.leaves(A.with_(base, **d), la=la, lb=lb)

def who(co, tris, tp, tl):
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    verts = [Vector(c) for c in co]
    P = BT.PART; inv = {v: k for k, v in P.items()}
    body = np.nonzero(np.isin(tp, [P[n] for n in ("bulb", "pad", "lip", "cavity", "gum", "taproot", "tooth")]))[0]
    tb = BVHTree.FromPolygons(verts, [tuple(tris[i]) for i in body], all_triangles=True, epsilon=0.0)
    idx = np.nonzero(np.isin(tp, [P["stem"], P["blade"]]))[0]
    ta = BVHTree.FromPolygons(verts, [tuple(tris[i]) for i in idx], all_triangles=True, epsilon=0.0)
    r = {}
    for a, b in ta.overlap(tb):
        ga, gb = idx[a], body[b]
        if set(tris[ga]) & set(tris[gb]):
            continue
        k = "%s%d@%s(%.0f,%.0f)" % (inv[tp[ga]], tl[ga], inv[tp[gb]], co[tris[gb]].mean(0)[0], co[tris[gb]].mean(0)[2])
        r[k] = r.get(k, 0) + 1
    return r

def run(strain, mid):
    clips = [A.Clip("SRC_Tug", 15, False, [(0, A.GRIP), (8, mid), (15, strain)]),
             A.Clip("SRC_Release", 6, False, [(0, strain), (2, A.REL_OVER), (4, A.REL_UNDER), (6, A.NEUTRAL)]),
             A.Clip("SRC_Cancel", 7, False, [(0, strain), (7, A.PLANT)])]
    res = {}
    for c in clips:
        bad = {}; gap = -9
        for f in range(c.end + 1):
            BT.apply_params(arm, c.sample(float(f)))
            co, tris, tp, tl = turnip_audit.evaluated(ob)
            gap = max(gap, max(A.stem_gap(co, tris, tp, tl)))
            isx = turnip_audit.intersections(ob, BT.PART)
            if isx.get("leaf_vs_bulb"):
                bad.setdefault("who", {})[f] = who(co, tris, tp, tl)
            for k, x in isx.items():
                if x and "(info)" not in k and "(sum)" not in k:
                    bad.setdefault(k, {})[f] = x
        res[c.name] = {"gap": round(gap, 3), "bad": bad}
    return res

argv = sys.argv[sys.argv.index("--") + 1:]
for line in json.loads(argv[0]):
    name, s, m = line
    st = mk(s); md = mk(m, st)
    t = time.time()
    print("SWEEP", name, json.dumps(run(st, md)), "%.0fs" % (time.time() - t), flush=True)
print("TURNIP_OK sweep")
