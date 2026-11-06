"""Cellar Bat R01 - mesh audits shared by the builder, the renderer and the validator (Phase 3).

  evaluated_tris(obj)        posed world triangles + per-triangle `part` tag
  intersections(obj, PART)   triangle-pair overlap counts between named part groups (BVH overlap of the posed mesh)
  defect_audit(obj)          duplicate verts, zero-area/sliver tris, winding, inverted closed islands, non-manifold edges
                             split into intentional membrane boundary vs defects
  uv_overlap(obj)            rasterised UV0 overlap (pixels covered by more than one triangle) and out-of-range UVs
  render_verts(obj)          unique (vertex, face normal, uv, colour) corners = what a GPU / Unreal counts
  bake_cavity(obj)           ray-cast occlusion per face -> alpha of the `Col` colour attribute (A = cavity/occlusion)
"""
import math

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def evaluated_tris(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    me.calc_loop_triangles()
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    mw = np.array(obj.matrix_world)
    co = co @ mw[:3, :3].T + mw[:3, 3]
    parts = np.empty(len(me.polygons), dtype=np.int64)
    me.attributes["part"].data.foreach_get("value", parts)
    tris = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
    me.loop_triangles.foreach_get("vertices", tris)
    tpoly = np.empty(len(me.loop_triangles), dtype=np.int64)
    me.loop_triangles.foreach_get("polygon_index", tpoly)
    ev.to_mesh_clear()
    return co, tris.reshape(-1, 3), parts[tpoly]


def intersections(obj, PART):
    co, tris, tp = evaluated_tris(obj)
    verts = [Vector(c) for c in co]

    def tree(mask):
        idx = np.nonzero(mask)[0]
        if len(idx) == 0:
            return None, idx
        return BVHTree.FromPolygons(verts, [tuple(tris[i]) for i in idx], all_triangles=True, epsilon=0.0), idx

    cache = {}

    def get(mask_key, mask):
        if mask_key not in cache:
            cache[mask_key] = tree(mask)
        return cache[mask_key]

    def count(ka, ma, kb=None, mb_=None, same=False):
        ta, ia = get(ka, ma)
        tb, ib = (ta, ia) if same else get(kb, mb_)
        if ta is None or tb is None:
            return 0
        n = 0
        for a, b in ta.overlap(tb):
            ga, gb = ia[a], ib[b]
            if same and (ga >= gb or set(tris[ga]) & set(tris[gb])):
                continue
            n += 1
        return n

    bodyp = [PART[k] for k in ("torso", "head", "face", "tuft", "ear", "ruff")]
    body = np.isin(tp, bodyp)
    res = {}
    for s in "lr":
        mem, root, rib = PART["mem_" + s], PART["memroot_" + s], PART["rib_" + s]
        res["memb_%s_body" % s] = count("body", body, "mem" + s, tp == mem)
        res["memb_%s_legs" % s] = count("mem" + s, tp == mem, "legs", tp == PART["leg"])
        res["memb_%s_self" % s] = count("memall" + s, (tp == mem) | (tp == root), same=True)
        res["ribs_%s_body" % s] = count("rib" + s, tp == rib, "body", body)
        res["ribs_%s_legs" % s] = count("rib" + s, tp == rib, "legs", tp == PART["leg"])
    res["memb_l_memb_r"] = count("memalll", (tp == PART["mem_l"]) | (tp == PART["memroot_l"]),
                                 "memallr", (tp == PART["mem_r"]) | (tp == PART["memroot_r"]))
    res["ribs_l_ribs_r"] = count("ribl", tp == PART["rib_l"], "ribr", tp == PART["rib_r"])
    res["memb_opp_ribs"] = (count("meml", tp == PART["mem_l"], "ribr", tp == PART["rib_r"]) +
                            count("memr", tp == PART["mem_r"], "ribl", tp == PART["rib_l"]))
    res["attach_memroot_body"] = (count("rootl", tp == PART["memroot_l"], "body", body) +
                                  count("rootr", tp == PART["memroot_r"], "body", body))
    res["attach_ribroot_body"] = (count("rrl", tp == PART["ribroot_l"], "body", body) +
                                  count("rrr", tp == PART["ribroot_r"], "body", body))
    return res


def _islands(nv, tris):
    parent = list(range(nv))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for a, b, c in tris:
        ra, rb, rc = find(a), find(b), find(c)
        if ra != rb:
            parent[ra] = rb
        rb = find(b)
        if rc != rb:
            parent[rc] = rb
    return np.array([find(i) for i in range(nv)])


def defect_audit(obj, membrane_slot=1):
    me = obj.data
    nv = len(me.vertices)
    co = np.empty(nv * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    if any(len(p.vertices) != 3 for p in me.polygons):
        raise RuntimeError("audit expects a triangulated mesh")
    tris = np.array([tuple(p.vertices) for p in me.polygons], dtype=np.int64)
    mat = np.array([p.material_index for p in me.polygons])
    a, b, c = co[tris[:, 0]], co[tris[:, 1]], co[tris[:, 2]]
    cr = np.cross(b - a, c - a)
    area = 0.5 * np.linalg.norm(cr, axis=1)

    def ang(p, q, r):
        u, v = q - p, r - p
        cosv = (u * v).sum(1) / np.maximum(np.linalg.norm(u, axis=1) * np.linalg.norm(v, axis=1), 1e-12)
        return np.degrees(np.arccos(np.clip(cosv, -1, 1)))

    min_ang = np.minimum(np.minimum(ang(a, b, c), ang(b, c, a)), ang(c, a, b))
    edges = {}
    for f, (x, y, z) in enumerate(tris):
        for p, q in ((x, y), (y, z), (z, x)):
            edges.setdefault((min(p, q), max(p, q)), []).append((f, p < q))
    isl = _islands(nv, tris)
    tri_isl = isl[tris[:, 0]]
    b_mem, b_other, nm_gt2, wind_bad, wind_bad_mem = 0, 0, 0, 0, 0
    open_islands = set()
    for key, lst in edges.items():
        if len(lst) == 1:
            open_islands.add(int(isl[key[0]]))
            if mat[lst[0][0]] == membrane_slot:
                b_mem += 1
            else:
                b_other += 1
        elif len(lst) > 2:
            nm_gt2 += 1
        elif lst[0][1] == lst[1][1]:
            wind_bad += 1
            if mat[lst[0][0]] == membrane_slot:
                wind_bad_mem += 1
    # closed islands: signed volume must be positive (outward normals)
    vol = np.einsum("ij,ij->i", a, np.cross(b, c)) / 6.0
    island_ids = np.unique(tri_isl)
    inverted, closed, open_solid, open_mem = 0, 0, 0, 0
    for iid in island_ids:
        sel = tri_isl == iid
        is_mem = bool((mat[sel] == membrane_slot).all())
        if int(iid) in open_islands:
            if is_mem:
                open_mem += 1
            else:
                open_solid += 1
            continue
        closed += 1
        if vol[sel].sum() <= 0:
            inverted += 1
    # duplicates: coincident vertices (1e-4 cm) inside one island vs across islands
    key = np.round(co / 1e-4).astype(np.int64)
    order = np.lexsort(key.T[::-1])
    ks = key[order]
    same = np.all(ks[1:] == ks[:-1], axis=1)
    dup_same, dup_cross = 0, 0
    for i in np.nonzero(same)[0]:
        if isl[order[i]] == isl[order[i + 1]]:
            dup_same += 1
        else:
            dup_cross += 1
    return {
        "tris": int(len(tris)), "verts": int(nv), "islands": int(len(island_ids)), "closed_islands": int(closed),
        "open_membrane_islands": int(open_mem), "open_non_membrane_islands (defect)": int(open_solid),
        "membrane_boundary_edges (intentional)": int(b_mem), "boundary_edges_non_membrane (defect)": int(b_other),
        "edges_with_3plus_faces (defect)": int(nm_gt2), "winding_flips (defect)": int(wind_bad),
        "inverted_closed_islands (defect)": int(inverted), "zero_area_tris (<1e-6 cm2, defect)": int((area < 1e-6).sum()),
        "duplicate_verts_same_island (defect)": int(dup_same), "coincident_verts_across_islands (info)": int(dup_cross),
        "sliver_tris_min_angle_lt_2deg (info)": int((min_ang < 2.0).sum()),
        "min_tri_area_cm2": float(area.min()), "min_angle_deg": float(min_ang.min()),
    }


def defects_total(a):
    return sum(v for k, v in a.items() if "(defect" in k)


def uv_overlap(obj, res=1024, uv_name=None):
    me = obj.data
    uvl = me.uv_layers[uv_name] if uv_name else me.uv_layers.active
    if uvl is None:
        return {"uv0": False}
    uv = np.empty(len(me.loops) * 2)
    uvl.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    loops = np.array([tuple(p.loop_indices) for p in me.polygons], dtype=np.int64)
    T = uv[loops]                                    # (nt, 3, 2)
    oob = int(((uv < -1e-6) | (uv > 1 + 1e-6)).any(axis=1).sum())
    cover = np.zeros((res, res), dtype=np.int16)
    degenerate = 0
    for t in T:
        p = t * res
        cen = p.mean(0)
        e = (p[1, 0] - p[0, 0]) * (p[2, 1] - p[0, 1]) - (p[1, 1] - p[0, 1]) * (p[2, 0] - p[0, 0])
        if abs(e) < 1e-9:
            degenerate += 1
            continue
        # inset by ~0.6 px so shared edges never double-count
        d = p - cen
        ln = np.linalg.norm(d, axis=1, keepdims=True)
        p = cen + d * np.maximum(0.0, 1.0 - 0.6 / np.maximum(ln, 1e-9))
        x0, y0 = np.floor(p.min(0)).astype(int)
        x1, y1 = np.ceil(p.max(0)).astype(int)
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, res - 1), min(y1, res - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        (ax, ay), (bx, by), (cx, cy) = p
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-12:
            continue
        l1 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
        l2 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
        inside = (l1 >= 0) & (l2 >= 0) & (1 - l1 - l2 >= 0)
        cover[y0:y1 + 1, x0:x1 + 1] += inside.astype(np.int16)
    used = int((cover > 0).sum())
    return {"uv0": True, "uv_layer": uvl.name, "overlap_px": int((cover > 1).sum()), "covered_px": used,
            "coverage_pct": round(100.0 * used / (res * res), 2), "raster": res, "out_of_range_loops": oob,
            "degenerate_uv_tris": degenerate}


def render_verts(obj):
    me = obj.data
    nl = len(me.loops)
    vi = np.empty(nl, dtype=np.int64)
    me.loops.foreach_get("vertex_index", vi)
    pidx = np.empty(nl, dtype=np.int64)
    for p in me.polygons:
        pidx[p.loop_start:p.loop_start + p.loop_total] = p.index
    pn = np.empty(len(me.polygons) * 3)
    me.polygons.foreach_get("normal", pn)
    pn = pn.reshape(-1, 3)
    smooth = np.empty(len(me.polygons), dtype=bool)
    me.polygons.foreach_get("use_smooth", smooth)
    nrm = np.where(smooth[pidx][:, None], 0.0, pn[pidx])
    cols = [vi[:, None].astype(np.float64), np.round(nrm, 4)]
    if me.uv_layers.active:
        uv = np.empty(nl * 2)
        me.uv_layers.active.data.foreach_get("uv", uv)
        cols.append(np.round(uv.reshape(-1, 2), 5))
    ca = me.color_attributes.get("Col")
    if ca is not None and ca.domain == "CORNER":
        c = np.empty(nl * 4)
        ca.data.foreach_get("color", c)
        cols.append(np.round(c.reshape(-1, 4), 4))
    key = np.hstack(cols)
    return int(len(np.unique(key, axis=0)))


def _hemi_dirs(n):
    out = []
    ga = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        z = 1 - (i + 0.5) / n          # uniform in z over the hemisphere -> cos-weighted after weighting
        r = math.sqrt(max(0.0, 1 - z * z))
        out.append((math.cos(ga * i) * r, math.sin(ga * i) * r, z))
    return out


def bake_cavity(obj, n_rays=24, max_dist=4.0, strength=0.85, floor=0.15):
    """A of the `Col` corner attribute = 1 - strength * cos-weighted occlusion of the face (rest pose, object space).
    Deterministic (fixed ray set). Returns (min A, mean A)."""
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


def overlap_detail(obj, PART, parts_a, parts_b):
    """Which bones own the triangles of group A that overlap group B: {dominant bone: triangle count}."""
    co, tris, tp = evaluated_tris(obj)
    verts = [Vector(c) for c in co]
    ia = np.nonzero(np.isin(tp, [PART[p] for p in parts_a]))[0]
    ib = np.nonzero(np.isin(tp, [PART[p] for p in parts_b]))[0]
    if not len(ia) or not len(ib):
        return {}
    ta = BVHTree.FromPolygons(verts, [tuple(tris[i]) for i in ia], all_triangles=True)
    tb = BVHTree.FromPolygons(verts, [tuple(tris[i]) for i in ib], all_triangles=True)
    hit = {ia[a] for a, b in ta.overlap(tb)}
    gname = {g.index: g.name for g in obj.vertex_groups}
    out = {}
    for t in hit:
        v = obj.data.vertices[int(tris[t][0])]
        g = max(v.groups, key=lambda g: g.weight)
        out[gname[g.group]] = out.get(gname[g.group], 0) + 1
    return dict(sorted(out.items(), key=lambda kv: -kv[1]))
