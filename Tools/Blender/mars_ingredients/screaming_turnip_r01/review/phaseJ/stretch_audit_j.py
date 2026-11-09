"""Phase J Part 1d: stretch numbers of the blend it opens (SRC_Tug f0 vs f15): crown + HarvestGrip travel, the bulb-top neck
(dimple / ring displacement), stem lengths (base ring -> blade ring, and emergence ring -> blade ring) as multiples of
f0, plus the variant's anim_report (intersections, stem_gap) when given.
Run: "$B" -b --factory-startup <blend> --python review/phaseJ/stretch_audit_j.py -- <label> <out.json> [<anim_report.json>]"""
import sys, json
ROOT = "D:/Repositories/CkRepos/Orion/Tools/Blender/mars_ingredients/screaming_turnip_r01"
sys.path.insert(0, ROOT + "/scripts")
import bpy, numpy as np
from mathutils import Vector
import build_screaming_turnip as BT
import turnip_audit
argv = sys.argv[sys.argv.index("--") + 1:]
label, out_path = argv[0], argv[1]
TO_UE = np.array([1.0, -1.0, 1.0])
arm = bpy.data.objects[BT.ARM_NAME]; ob = bpy.data.objects[BT.MESH_NAME]
sc = bpy.context.scene
act = bpy.data.actions["SRC_Tug"]
arm.animation_data_create(); arm.animation_data.action = act
if arm.animation_data.action_slot is None:
    arm.animation_data.action_slot = act.slots[0]
meas = json.load(open(ROOT + "/review/phaseB4/measurements.json"))
hg = Vector(meas["landmarks"]["sockets_blender_cm"]["HarvestGrip_R"])
crinv = arm.data.bones["crown"].matrix_local.inverted()
cg = ob.vertex_groups["crown"].index
bulb_crown = [v.index for v in ob.data.vertices if any(g.group == cg and g.weight > 0 for g in v.groups)
              and not any(ob.vertex_groups[g.group].name.startswith("leaf_") for g in v.groups)]
dimple = [i for i in bulb_crown if abs(ob.data.vertices[i].co.x) < 1e-4 and abs(ob.data.vertices[i].co.y) < 1e-4]
ring = [i for i in bulb_crown if i not in dimple]


def frame(f):
    sc.frame_set(f)
    co, tris, tp, tl = turnip_audit.evaluated(ob)
    crown = np.array(arm.pose.bones["crown"].head) * TO_UE
    sock = np.array(arm.pose.bones["crown"].matrix @ crinv @ hg) * TO_UE
    stems = {}
    for leaf in range(1, 6):
        sr = np.unique(tris[(tp == BT.PART["stem_root"]) & (tl == leaf)].ravel())
        sr = sr[np.argsort(co[sr][:, 2])] if f == 0 else stems_idx[leaf][0]
        b1 = np.array(arm.pose.bones["leaf_%02d_b" % leaf].head)
        stems[leaf] = (sr, co[sr[:4]].mean(0), co[sr[-4:]].mean(0), b1)
    return co, crown, sock, stems


stems_idx = {}
co0, c0, s0, st0 = frame(0)
stems_idx = {k: (v[0],) for k, v in st0.items()}
co0, c0, s0, st0 = frame(0)
co1, c1, s1, st1 = frame(15)
out = {"label": label, "frame_map": "UE cm root-relative; SRC_Tug f0 (== SRC_Grip f6) vs f15",
       "crown_d": (c1 - c0).round(3).tolist(), "socket_HG_R_d": (s1 - s0).round(3).tolist(),
       "socket_horizontal_travel": round(float(np.hypot(*(s1 - s0)[:2])), 3),
       "neck": {"dimple_d": ((co1[dimple[0]] - co0[dimple[0]]) * TO_UE).round(3).tolist(),
                "ring_max_d": round(float(np.linalg.norm((co1[ring] - co0[ring]), axis=1).max()), 3),
                "target": "dimple <= 9 cm x, <= 3 cm z; ring below the dimple"},
       "stems": {}}
for leaf in range(1, 6):
    _, a0, e0, b0 = st0[leaf]; _, a1, e1, b1 = st1[leaf]
    out["stems"]["leaf_%d" % leaf] = {
        "base_to_blade_cm": [round(float(np.linalg.norm(b0 - a0)), 2), round(float(np.linalg.norm(b1 - a1)), 2)],
        "base_to_blade_x": round(float(np.linalg.norm(b1 - a1) / np.linalg.norm(b0 - a0)), 2),
        "emergence_to_blade_cm": [round(float(np.linalg.norm(b0 - e0)), 2), round(float(np.linalg.norm(b1 - e1)), 2)],
        "emergence_to_blade_x": round(float(np.linalg.norm(b1 - e1) / np.linalg.norm(b0 - e0)), 2)}
n = out["neck"]
out["neck"]["pass"] = bool(abs(n["dimple_d"][0]) <= 9 and n["dimple_d"][2] <= 3 and n["ring_max_d"] < np.linalg.norm(n["dimple_d"]))
if len(argv) > 2:
    r = json.load(open(argv[2]))
    out["anim_report"] = {"fails": r["fails"], "envelope": r["envelope"],
                          "SRC": {c: {"stem_gap_max_cm": r["clips"][c]["stem_gap_max_cm"], "isect_max": r["clips"][c]["isect_max"]}
                                  for c in ("SRC_Tug", "SRC_Cancel", "SRC_Release")}}
arm.animation_data.action = None
json.dump(out, open(out_path, "w"), indent=1)
print("STRETCH", json.dumps({k: out[k] for k in ("crown_d", "socket_horizontal_travel", "neck")}))
print("STEMS", json.dumps({k: (v["base_to_blade_x"], v["emergence_to_blade_x"]) for k, v in out["stems"].items()}))
print("TURNIP_OK stretch")
