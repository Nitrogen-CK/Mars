"""Phase I Part 1b: prove a rebuilt blend's geometry equals a reference blend's; only skin weights may differ.

Opened on the NEW blend; reads the reference blend's datablocks with bpy.data.libraries.load (no scene change).
Compares: body vertex count, triangle count, polygon vertex lists, material indices, rest vertex positions, every
shape-key block's positions, vertex colours, bones (names, parents, heads, tails, rolls), the three statics' vertices,
and reports the vertex-group weight differences (which vertices, which groups). Writes review/phaseI/rebuild_compare.json.
Run: "$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/compare_rebuild_screaming_turnip.py -- \
         --ref source/ScreamingTurnip_R01_phaseH.blend
Prints TURNIP_OK / TURNIP_FAIL (geometry tolerance 1e-3 cm).
"""
import json
import os
import sys
import traceback

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_screaming_turnip as BT  # noqa: E402

ROOT = os.path.dirname(HERE)
TOL = 1e-3


def mesh_facts(me):
    n = len(me.vertices)
    co = np.empty(n * 3); me.vertices.foreach_get("co", co)
    polys = [tuple(p.vertices) for p in me.polygons]
    mats = [p.material_index for p in me.polygons]
    keys = {}
    if me.shape_keys:
        for kb in me.shape_keys.key_blocks:
            k = np.empty(n * 3); kb.data.foreach_get("co", k)
            keys[kb.name] = k.reshape(-1, 3)
    cols = {}
    for ca in me.color_attributes:
        d = np.empty(len(ca.data) * 4); ca.data.foreach_get("color", d)
        cols[ca.name] = d
    return co.reshape(-1, 3), polys, mats, keys, cols


def weights(ob):
    names = [g.name for g in ob.vertex_groups]
    out = []
    for v in ob.data.vertices:
        out.append({names[g.group]: round(g.weight, 6) for g in v.groups if g.weight > 0})
    return out


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    ref = os.path.join(ROOT, argv[argv.index("--ref") + 1])
    new_ob = bpy.data.objects[BT.MESH_NAME]
    new_arm = bpy.data.objects[BT.ARM_NAME]
    with bpy.data.libraries.load(ref, link=False) as (src, dst):
        names = list(src.objects)
        dst.objects = list(src.objects)
    refs = {n: o for n, o in zip(names, dst.objects) if o is not None}     # loaded copies are renamed .001
    ref_ob = refs[BT.MESH_NAME]
    fails, rep = [], {}
    A = mesh_facts(new_ob.data)
    Rf = mesh_facts(ref_ob.data)
    rep["verts"] = [len(A[0]), len(Rf[0])]
    new_ob.data.calc_loop_triangles(); ref_ob.data.calc_loop_triangles()
    rep["tris"] = [len(new_ob.data.loop_triangles), len(ref_ob.data.loop_triangles)]
    if rep["verts"][0] != rep["verts"][1] or rep["tris"][0] != rep["tris"][1]:
        fails.append("counts %s %s" % (rep["verts"], rep["tris"]))
    rep["polygons_identical"] = A[1] == Rf[1]
    rep["material_indices_identical"] = A[2] == Rf[2]
    if not (rep["polygons_identical"] and rep["material_indices_identical"]):
        fails.append("topology / material indices differ")
    rep["rest_vertex_max_cm"] = float(np.abs(A[0] - Rf[0]).max())
    rep["shape_keys"] = {"new": list(A[3]), "ref": list(Rf[3])}
    if list(A[3]) != list(Rf[3]):
        fails.append("shape key names %s" % rep["shape_keys"])
    rep["shape_key_block_max_cm"] = {k: float(np.abs(A[3][k] - Rf[3][k]).max()) for k in A[3] if k in Rf[3]}
    rep["shape_key_offset_max_cm"] = {k: float(np.abs((A[3][k] - A[3]["Basis"]) - (Rf[3][k] - Rf[3]["Basis"])).max())
                                      for k in A[3] if k in Rf[3]}
    rep["vertex_colour_max"] = {k: float(np.abs(A[4][k] - Rf[4][k]).max()) for k in A[4] if k in Rf[4]}
    for k, x in [("rest", rep["rest_vertex_max_cm"])] + list(rep["shape_key_block_max_cm"].items()):
        if x > TOL:
            fails.append("%s vertices differ by %.6f cm" % (k, x))
    if any(x > 1e-6 for x in rep["vertex_colour_max"].values()):
        fails.append("vertex colours differ %s" % rep["vertex_colour_max"])
    # bones
    ref_arm = refs[BT.ARM_NAME]
    bd = {}
    for b in new_arm.data.bones:
        r = ref_arm.data.bones[b.name]
        bd[b.name] = max(float((b.head_local - r.head_local).length), float((b.tail_local - r.tail_local).length),
                         float(np.abs(np.array(b.matrix_local) - np.array(r.matrix_local)).max()))
        if (b.parent.name if b.parent else None) != (r.parent.name if r.parent else None):
            fails.append("bone parent %s" % b.name)
    rep["bones"] = [len(new_arm.data.bones), len(ref_arm.data.bones)]
    rep["bone_max_delta"] = max(bd.values())
    if rep["bones"][0] != rep["bones"][1] or rep["bone_max_delta"] > TOL:
        fails.append("bones %s %s" % (rep["bones"], rep["bone_max_delta"]))
    # statics
    rep["statics_max_cm"] = {}
    for n in (BT.BED_NAME, BT.BED_EMPTY_NAME, BT.COLL_NAME):
        a, r = bpy.data.objects[n], refs[n]
        if len(a.data.vertices) != len(r.data.vertices):
            fails.append("%s vert count" % n); continue
        ca = np.array([v.co for v in a.data.vertices]); cr = np.array([v.co for v in r.data.vertices])
        rep["statics_max_cm"][n] = float(np.abs(ca - cr).max())
        if rep["statics_max_cm"][n] > TOL or (a.location - r.location).length > TOL:
            fails.append("%s geometry" % n)
    # custom landmark props (sockets live in measurements; mesh id props compared here)
    rep["id_props_identical"] = {k: (list(new_ob[k]) if hasattr(new_ob[k], "__len__") else new_ob[k]) ==
                                 (list(ref_ob[k]) if hasattr(ref_ob[k], "__len__") else ref_ob[k])
                                 for k in new_ob.keys() if k in ref_ob.keys() and not k.startswith("_")}
    # weights
    wa, wr = weights(new_ob), weights(ref_ob)
    changed = [i for i in range(len(wa)) if wa[i] != wr[i]]
    parts = {}
    me = new_ob.data
    pv = np.zeros(len(me.polygons), dtype=np.int64)
    me.attributes["part"].data.foreach_get("value", pv)
    inv = {v: k for k, v in BT.PART.items()}
    vpart = {}
    for p, pid in zip(me.polygons, pv):
        for v in p.vertices:
            vpart.setdefault(v, set()).add(inv[int(pid)])
    for i in changed:
        key = "+".join(sorted(vpart.get(i, {"?"})))
        parts[key] = parts.get(key, 0) + 1
    rep["weights_changed_vertices"] = len(changed)
    rep["weights_changed_by_part"] = parts
    rep["weights_examples"] = [{"v": i, "new": wa[i], "ref": wr[i]} for i in changed[:12]]
    rep["fails"] = fails
    out = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join("review", "phaseI", "rebuild_compare.json")
    with open(os.path.join(ROOT, out), "w") as fh:          # Phase J: --out review/phaseJ/rebuild_compare.json
        json.dump(rep, fh, indent=1, default=str)
    print("COMPARE", json.dumps({k: v for k, v in rep.items() if k != "weights_examples"}, default=str))
    if fails:
        print("TURNIP_FAIL " + "; ".join(fails)); sys.exit(1)
    print("TURNIP_OK")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc(); print("TURNIP_FAIL exception"); sys.exit(1)
