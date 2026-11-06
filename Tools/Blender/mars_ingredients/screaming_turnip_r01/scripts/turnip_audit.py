"""Screaming Turnip R01 - mesh audits shared by the builder, the renderer and the validator (Phase A).

  evaluated(obj)              posed world vertices, triangles, per-triangle `part` and `leaf` tags
  intersections(obj, PART)    triangle-pair overlap counts between named part groups of the posed export mesh
                              (BVH overlap; pairs that share a vertex are adjacency, never counted)
  defect_audit(obj)           boundary / non-manifold edges, winding flips, inverted closed islands, zero-area tris
  weights_check(ob, bones)    max influences, normalisation, unweighted verts, non-bone groups, root-weighted verts
  ue_composition_deviation(arm, obj)
                              skins the mesh with the Unreal FTransform composition (rotation and per-axis scale
                              composed separately, no shear) from the same local bone transforms the FBX exporter
                              writes, and returns the max vertex distance to the Blender evaluated mesh (cm)
"""
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree


def evaluated(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    me.calc_loop_triangles()
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    mw = np.array(obj.matrix_world)
    co = co @ mw[:3, :3].T + mw[:3, 3]
    npoly = len(me.polygons)
    parts = np.zeros(npoly, dtype=np.int64)
    leaf = np.zeros(npoly, dtype=np.int64)
    if "part" in me.attributes:
        me.attributes["part"].data.foreach_get("value", parts)
    if "leaf" in me.attributes:
        me.attributes["leaf"].data.foreach_get("value", leaf)
    tris = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
    me.loop_triangles.foreach_get("vertices", tris)
    tpoly = np.empty(len(me.loop_triangles), dtype=np.int64)
    me.loop_triangles.foreach_get("polygon_index", tpoly)
    ev.to_mesh_clear()
    return co, tris.reshape(-1, 3), parts[tpoly], leaf[tpoly]


def _islands_of(tris, idx):
    parent = {}

    def find(a):
        while parent.setdefault(a, a) != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for i in idx:
        a, b, c = (int(x) for x in tris[i])
        ra = find(a)
        for v in (b, c):
            rv = find(v)
            if rv != ra:
                parent[rv] = ra
    return {int(i): find(int(tris[i][0])) for i in idx}


def intersections(obj, PART):
    co, tris, tp, tl = evaluated(obj)
    verts = [Vector(c) for c in co]
    cache = {}

    def get(key, mask):
        if key not in cache:
            idx = np.nonzero(mask)[0]
            t = BVHTree.FromPolygons(verts, [tuple(tris[i]) for i in idx], all_triangles=True,
                                     epsilon=0.0) if len(idx) else None
            cache[key] = (t, idx)
        return cache[key]

    def count(ka, ma, kb=None, mb=None, cross_island_only=False):
        same = kb is None
        ta, ia = get(ka, ma)
        tb, ib = (ta, ia) if same else get(kb, mb)
        if ta is None or tb is None:
            return 0
        isl = _islands_of(tris, ia) if cross_island_only else None
        n = 0
        for a, b in ta.overlap(tb):
            ga, gb = ia[a], ib[b]
            if same and ga >= gb:
                continue
            if set(tris[ga]) & set(tris[gb]):
                continue
            if isl is not None and isl[int(ga)] == isl[int(gb)]:
                continue
            n += 1
        return n

    P = lambda *names: np.isin(tp, [PART[n] for n in names])
    names = set(PART)
    mouth = P(*[n for n in ("lip", "cavity", "gum") if n in names])
    outer = P(*[n for n in ("bulb", "pad") if n in names])
    res = {
        "mouth_self (lip+cavity folding)": count("mouth", mouth),
        "teeth_vs_mouth": count("tooth", P("tooth"), "mouth", mouth),
        "teeth_vs_teeth": count("toothall", P("tooth", "tooth_root"), cross_island_only=True),
        "mouth_vs_outer_shell": count("mouth", mouth, "outer", outer),
        "outer_shell_self": count("outer", outer),
        "taproot_vs_bulb": count("tap", P("taproot"), "outer", outer),
    }
    lvl = 0
    for i in range(1, 6):
        for j in range(i + 1, 6):
            lvl += count("leaf%d" % i, (tl == i), "leaf%d" % j, (tl == j))
    res["leaf_vs_leaf"] = lvl
    if "pad" in names:
        res["pad_self (lip pad self-contact, info)"] = count("pad", P("pad"))
        res["teeth_vs_pad"] = count("toothp", P("tooth", "tooth_root"), "pad", P("pad"))
    res["leaf_vs_bulb"] = count("leafp", P("stem", "blade"), "body",
                                P(*[n for n in ("bulb", "pad", "lip", "cavity", "gum", "taproot", "tooth") if n in names]))
    res["attach_tooth_root (info)"] = count("troot", P("tooth_root"), "mouth", mouth)
    res["attach_stem_root (info)"] = count("sroot", P("stem_root"), "outer", outer)
    res["attach_taproot_root (info)"] = count("tproot", P("taproot_root"), "outer", outer)
    res["lip_teeth_vs_cavity (sum)"] = (res["mouth_self (lip+cavity folding)"] + res["teeth_vs_mouth"] +
                                        res["teeth_vs_teeth"])
    return res


def defect_audit(obj):
    me = obj.data
    nv = len(me.vertices)
    co = np.empty(nv * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    if any(len(p.vertices) != 3 for p in me.polygons):
        raise RuntimeError("audit expects a triangulated mesh")
    tris = np.array([tuple(p.vertices) for p in me.polygons], dtype=np.int64)
    a, b, c = co[tris[:, 0]], co[tris[:, 1]], co[tris[:, 2]]
    area = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
    edges = {}
    for f, (x, y, z) in enumerate(tris):
        for p, q in ((x, y), (y, z), (z, x)):
            edges.setdefault((min(p, q), max(p, q)), []).append((f, p < q))
    boundary, nm, wind = 0, 0, 0
    for lst in edges.values():
        if len(lst) == 1:
            boundary += 1
        elif len(lst) > 2:
            nm += 1
        elif lst[0][1] == lst[1][1]:
            wind += 1
    isl = _islands_of(tris, range(len(tris)))
    tri_isl = np.array([isl[i] for i in range(len(tris))])
    vol = np.einsum("ij,ij->i", a, np.cross(b, c)) / 6.0
    inverted = sum(1 for i in np.unique(tri_isl) if vol[tri_isl == i].sum() <= 0)
    return {"tris": int(len(tris)), "verts": nv, "islands": int(len(np.unique(tri_isl))),
            "boundary_edges (defect)": boundary, "edges_with_3plus_faces (defect)": nm,
            "winding_flips (defect)": wind, "inverted_islands (defect)": int(inverted),
            "zero_area_tris (<1e-6 cm2, defect)": int((area < 1e-6).sum()), "min_tri_area_cm2": float(area.min())}


def defects_total(a):
    return sum(v for k, v in a.items() if "(defect" in k)


def weights_check(ob, bone_names):
    gname = {g.index: g.name for g in ob.vertex_groups}
    maxinf, badsum, unweighted, rootw = 0, 0, 0, 0
    for v in ob.data.vertices:
        ws = [(gname[g.group], g.weight) for g in v.groups if g.weight > 0]
        maxinf = max(maxinf, len(ws))
        if not ws:
            unweighted += 1
        elif abs(sum(w for _, w in ws) - 1.0) > 1e-3:
            badsum += 1
        if any(n == "root" for n, _ in ws):
            rootw += 1
    stray = [g.name for g in ob.vertex_groups if g.name not in bone_names]
    return {"max_influences": maxinf, "unnormalized": badsum, "unweighted": unweighted, "non_bone_groups": stray,
            "root_weighted_verts": rootw}


def _ue_mul(local, parent):
    """Unreal FTransform composition (child local * parent component space): rotation and per-axis scale compose
    separately, translation goes through the parent's scale and rotation."""
    tl, rl, sl = local
    tp, rp, sp = parent
    s = Vector((sp.x * sl.x, sp.y * sl.y, sp.z * sl.z))
    r = rp @ rl
    t = tp + rp @ Vector((sp.x * tl.x, sp.y * tl.y, sp.z * tl.z))
    return t, r, s


def ue_composition_deviation(arm, obj):
    comp = {}
    for pb in arm.pose.bones:          # parents precede children in pose.bones
        m = pb.matrix if pb.parent is None else pb.parent.matrix.inverted() @ pb.matrix
        loc, rot, sc = m.decompose()
        comp[pb.name] = (loc, rot, sc) if pb.parent is None else _ue_mul((loc, rot, sc), comp[pb.parent.name])
    skin = {}
    for pb in arm.pose.bones:
        t, r, s = comp[pb.name]
        M = Matrix.Translation(t) @ r.to_matrix().to_4x4() @ Matrix.Diagonal((s.x, s.y, s.z, 1.0))
        skin[pb.name] = np.array(M @ pb.bone.matrix_local.inverted())
    me = obj.data
    gname = {g.index: g.name for g in obj.vertex_groups}
    rest = np.array([tuple(v.co) + (1.0,) for v in me.vertices])
    sk = me.shape_keys
    if sk is not None and sk.use_relative:          # B2b: morphs apply before skinning (Blender and Unreal alike)
        basis = np.array([tuple(d.co) for d in sk.key_blocks[0].data])
        for kb in sk.key_blocks[1:]:
            if kb.value != 0.0 and not kb.mute:
                kd = np.array([tuple(d.co) for d in kb.data])
                ref = np.array([tuple(d.co) for d in kb.relative_key.data])
                rest[:, :3] += kb.value * (kd - ref)
    out = np.zeros((len(me.vertices), 3))
    for v in me.vertices:
        acc = np.zeros(4)
        for g in v.groups:
            acc += g.weight * (skin[gname[g.group]] @ rest[v.index])
        out[v.index] = acc[:3]
    co, _t, _p, _l = evaluated(obj)
    d = np.linalg.norm(out - co, axis=1)
    return round(float(d.max()), 5), int(np.argmax(d))


def _hemi_dirs(n):
    import math
    out = []
    ga = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        z = 1 - (i + 0.5) / n
        r = math.sqrt(max(0.0, 1 - z * z))
        out.append((math.cos(ga * i) * r, math.sin(ga * i) * r, z))
    return out


def bake_cavity(obj, n_rays=32, max_dist=4.0, strength=0.85, floor=0.15):
    """Cellar Bat recipe: A of the `Col` corner attribute = 1 - strength * cos-weighted occlusion of each face in the
    REST (neutral) pose, object space, floor 0.15; RGB untouched. Deterministic (fixed ray set). Returns (min, mean)."""
    me = obj.data
    verts = [v.co.copy() for v in me.vertices]
    polys = [tuple(p.vertices) for p in me.polygons]
    bvh = BVHTree.FromPolygons(verts, polys, all_triangles=True)
    dirs = _hemi_dirs(n_rays)
    ca = me.color_attributes["Col"]
    col = np.empty(len(me.loops) * 4)
    ca.data.foreach_get("color_srgb", col)
    col = col.reshape(-1, 4)
    alist = []
    for p in me.polygons:
        n = p.normal.copy()
        c = p.center.copy()
        t1 = n.orthogonal().normalized()
        t2 = n.cross(t1)
        occ, wsum = 0.0, 0.0
        for dx, dy, dz in dirs:
            d = (t1 * dx + t2 * dy + n * dz).normalized()
            w = dz
            wsum += w
            hit = bvh.ray_cast(c + n * 0.02, d, max_dist)
            if hit[0] is not None and hit[2] != p.index:
                occ += w * (1.0 - hit[3] / max_dist) ** 0.5
        a = max(floor, 1.0 - strength * occ / wsum)
        alist.append(a)
        col[p.loop_start:p.loop_start + p.loop_total, 3] = a
    ca.data.foreach_set("color_srgb", col.ravel())
    return round(float(min(alist)), 3), round(float(np.mean(alist)), 3)


def overlap_where(obj, PART, parts_a, parts_b=None, leaf_pairs=False):
    """Centroids (cm, rounded) of overlapping triangle pairs between part groups (diagnostic)."""
    co, tris, tp, tl = evaluated(obj)
    verts = [Vector(c) for c in co]
    ma = np.isin(tp, [PART[n] for n in parts_a])
    mb = ma if parts_b is None else np.isin(tp, [PART[n] for n in parts_b])
    ia, ib = np.nonzero(ma)[0], np.nonzero(mb)[0]
    ta = BVHTree.FromPolygons(verts, [tuple(tris[i]) for i in ia], all_triangles=True, epsilon=0.0)
    tb = ta if parts_b is None else BVHTree.FromPolygons(verts, [tuple(tris[i]) for i in ib], all_triangles=True,
                                                        epsilon=0.0)
    out = []
    for a, b in ta.overlap(tb):
        ga, gb = ia[a], ib[b]
        if parts_b is None and ga >= gb:
            continue
        if set(tris[ga]) & set(tris[gb]):
            continue
        if leaf_pairs and (tl[ga] == tl[gb] or not tl[ga] or not tl[gb]):
            continue
        out.append((co[tris[ga]].mean(0).round(2).tolist(), int(tp[ga]), co[tris[gb]].mean(0).round(2).tolist(),
                    int(tp[gb]), int(tl[ga]), int(tl[gb])))
    return out
