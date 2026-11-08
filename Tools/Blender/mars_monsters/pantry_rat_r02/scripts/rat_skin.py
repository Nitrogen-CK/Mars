"""Pantry Rat R02 - rest bone layout for the frozen 26-bone rig (../RIG_R01.json names / parents) on the R02 body, and
the skin weights (max 3 influences, normalised) of the R02 mesh built by rat_model.build().

Bone rest POSITIONS follow the R02 proportions; names, parents and roles are R01's. Weights are assigned per part tag
(rat_common.PART) and position:
  loft (torso + head)  hat functions along the spine: pelvis / body / chest / neck / head centres
  jaw                  100 % jaw            nose, eye patches   100 % head        ears   100 % ear_l / ear_r
  legs                 upper limb: upper bone, blending to the parent (chest / pelvis) at the top and to the lower bone at
                       the knee / elbow knob; lower limb: lower bone, blending to the upper at the knee and to the foot at
                       the heel / wrist; paw + toes: 100 % foot
  tail                 by arc position: nearest segment, blended 50/50 across 1.6 cm at each joint; the root blends pelvis
  spoon + cuffs        100 % spoon_prop (rigid)
  girth + chest strap  the spine weights of the torso point under them, blending to spoon_prop where they ride over
                       the handle (within 2.5 cm of the spoon)
"""
import math

from mathutils import Vector
from mathutils.bvhtree import BVHTree

import rat_common as rc
import rat_model as rm
from rat_common import PART, X, Y, Z, nrm, smooth

BONE_PARENTS = [
    ("root", None), ("body", "root"), ("pelvis", "body"), ("chest", "body"), ("neck", "chest"), ("head", "neck"),
    ("jaw", "head"), ("ear_l", "head"), ("ear_r", "head"),
    ("fore_upper_l", "chest"), ("fore_lower_l", "fore_upper_l"), ("fore_foot_l", "fore_lower_l"),
    ("fore_upper_r", "chest"), ("fore_lower_r", "fore_upper_r"), ("fore_foot_r", "fore_lower_r"),
    ("hind_upper_l", "pelvis"), ("hind_lower_l", "hind_upper_l"), ("hind_foot_l", "hind_lower_l"),
    ("hind_upper_r", "pelvis"), ("hind_lower_r", "hind_upper_r"), ("hind_foot_r", "hind_lower_r"),
    ("tail_01", "pelvis"), ("tail_02", "tail_01"), ("tail_03", "tail_02"), ("tail_04", "tail_03"),
    ("spoon_prop", "chest"),
]

SPINE_Z = 20.0
SPINE = [("pelvis", -14.0), ("body", -3.0), ("chest", 4.0), ("neck", 11.0), ("head", 15.0)]


def bone_layout(spoon_M):
    P = rm.P
    F, Hd = P["FORE"], P["HIND"]
    tb = rm.tail_bone_points()
    L = {
        "root": ((0, 0, 0), (0, 10, 0), None),
        "body": ((-3.0, 0, SPINE_Z), (3.0, 0, SPINE_Z), Z),
        "pelvis": ((-3.0, 0, SPINE_Z), (-15.0, 0, 18.0), Z),
        "chest": ((3.0, 0, SPINE_Z), (8.5, 0, 21.5), Z),
        "neck": ((8.5, 0, 21.5), (12.5, 0, 22.0), Z),
        "head": ((12.5, 0, 22.0), (28.5, 0, 17.0), Z),
        "jaw": ((13.5, 0, 14.4), (27.4, 0, 12.4), Z),
        "tail_01": (tuple(tb[0]), tuple(tb[1]), Z), "tail_02": (tuple(tb[1]), tuple(tb[2]), Z),
        "tail_03": (tuple(tb[2]), tuple(tb[3]), Z), "tail_04": (tuple(tb[3]), tuple(tb[4]), Z),
    }
    for side, sfx in ((1, "_l"), (-1, "_r")):
        s = Vector((1, side, 1))
        c, n, up, sd = rm.ear_frame(side)
        base = c - up * P["EAR_H"] * 0.42
        L["ear" + sfx] = (tuple(base), tuple(c + up * P["EAR_H"] * 0.5), n)
        for kind, ch in (("fore", F), ("hind", Hd)):
            a, b, cc, d = [Vector(p) * s for p in ch]
            L[kind + "_upper" + sfx] = (tuple(a), tuple(b), X)
            L[kind + "_lower" + sfx] = (tuple(b), tuple(cc), X)
            L[kind + "_foot" + sfx] = (tuple(cc), tuple(d), Z)
    R3 = spoon_M.to_3x3()
    h = spoon_M.translation + R3.col[0] * 9.0
    L["spoon_prop"] = (tuple(h), tuple(h + R3.col[0] * 8.0), R3.col[2])
    return L


def spine_w(x):
    if x <= SPINE[0][1]:
        return {SPINE[0][0]: 1.0}
    if x >= SPINE[-1][1]:
        return {SPINE[-1][0]: 1.0}
    for (n0, x0), (n1, x1) in zip(SPINE, SPINE[1:]):
        if x0 <= x <= x1:
            t = smooth((x - x0) / (x1 - x0))
            return {n0: 1.0 - t, n1: t}
    return {"body": 1.0}


def seg_t(p, a, b):
    d = b - a
    return (p - a).dot(d) / d.length_squared


def leg_w(p, kind, side):
    sfx = "_l" if side > 0 else "_r"
    s = Vector((1, side, 1))
    a, b, c, d = [Vector(q) * s for q in (rm.P["FORE"] if kind == "fore" else rm.P["HIND"])]
    up, lo, ft = kind + "_upper" + sfx, kind + "_lower" + sfx, kind + "_foot" + sfx
    parent = "chest" if kind == "fore" else "pelvis"
    return a, b, c, d, up, lo, ft, parent


def assign(full, spoon_mb_world):
    """Fill full.w (list of weight dicts, one per vertex) in place. Returns a summary."""
    P = rm.P
    nv = len(full.v)
    vparts = [set() for _ in range(nv)]
    for f, pt in zip(full.f, full.fp):
        for i in f:
            vparts[i].add(pt)
    spoon_tree = BVHTree.FromPolygons(spoon_mb_world.v, spoon_mb_world.f, all_triangles=False)
    tail_pts = rm.catmull(P["TAIL"], 2)
    tb = rm.tail_bone_points()
    tnames = ["tail_01", "tail_02", "tail_03", "tail_04"]
    counts = {}
    straps = []
    for i, p in enumerate(full.v):
        ps = vparts[i]
        pt = min(ps) if ps else PART["torso"]
        if PART["jaw"] in ps:
            w = {"jaw": 1.0}
        elif ps & {PART["nose"], PART["eyepatch"]}:
            w = {"head": 1.0}
        elif PART["ear"] in ps:
            w = {"ear_l" if p.y > 0 else "ear_r": 1.0}
        elif ps & {PART["spoon"], PART["cuff"]}:
            w = {"spoon_prop": 1.0}
        elif ps & {PART["leg_upper"], PART["leg_lower"], PART["foot"]}:
            kind = "fore" if p.x > -5.0 else "hind"
            side = 1 if p.y > 0 else -1
            a, b, c, d, up, lo, ft, parent = leg_w(p, kind, side)
            if PART["foot"] in ps:
                w = {ft: 1.0}
            elif PART["leg_lower"] in ps:
                t = seg_t(p, b, c)
                w = {lo: 1.0, up: 0.45 * (1 - smooth(t / 0.25)), ft: 0.4 * smooth((t - 0.75) / 0.25)}
            else:
                t = seg_t(p, a, b)
                w = {up: 1.0, parent: 0.55 * (1 - smooth((t + 0.1) / 0.45)), lo: 0.45 * smooth((t - 0.8) / 0.25)}
        elif PART["tail"] in ps:
            k = min(range(len(tail_pts)), key=lambda j: (tail_pts[j] - p).length)
            q = tail_pts[k]
            # segment by the nearest bone joint ordering along the curve
            dj = [(q - j_).length for j_ in tb]
            seg = 0
            for s_ in range(4):
                a_, b_ = tb[s_], tb[s_ + 1]
                t = seg_t(q, a_, b_)
                if -0.05 <= t <= 1.05:
                    seg = s_
                    break
            else:
                seg = min(3, max(0, dj.index(min(dj)) - 1))
            w = {tnames[seg]: 1.0}
            for jn in range(1, 4):
                dd = (q - tb[jn]).length
                if dd < 1.6:
                    f = 0.5 * (1 - dd / 1.6)
                    other = tnames[jn - 1] if seg >= jn else tnames[jn]
                    w = rc.blend_w((1 - f, w), (f, {other: 1.0}))
            if (q - tb[0]).length < 2.0:
                w = rc.blend_w((0.6, w), (0.4, {"pelvis": 1.0}))
        elif ps & {PART["band"], PART["strap"]}:
            straps.append(i)
            continue
        else:   # loft: torso + head
            w = spine_w(p.x)
        full.w[i] = rc.norm_w(w, 3)
        counts[rc.PART_NAMES.get(pt, str(pt))] = counts.get(rc.PART_NAMES.get(pt, str(pt)), 0) + 1
    # straps copy the weights of the nearest loft vertex (so they ride the surface they hug), then blend to spoon_prop
    # where they pass over the handle
    # straps take the barycentric blend of the weights of the loft triangle under them (so they ride the surface
    # they hug), then blend to spoon_prop where they pass over the handle
    from mathutils.geometry import barycentric_transform
    loft_f = [f for f, pt in zip(full.f, full.fp) if pt in (PART["torso"], PART["head"])]
    tris = []
    for f in loft_f:
        for a_, b_ in zip(f[1:-1], f[2:]):
            tris.append((f[0], a_, b_))
    tree = BVHTree.FromPolygons(full.v, tris, all_triangles=True)
    for i in straps:
        p = full.v[i]
        loc, n, ti, _ = tree.find_nearest(p)
        a_, b_, c_ = tris[ti]
        A, B, C = full.v[a_], full.v[b_], full.v[c_]
        bc = barycentric_transform(loc, A, B, C, Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
        w = rc.blend_w((max(0.0, bc.x), full.w[a_]), (max(0.0, bc.y), full.w[b_]), (max(0.0, bc.z), full.w[c_]))
        loc2, n2, _, dist = spoon_tree.find_nearest(p)
        if loc2 is not None and dist < 2.5:
            f = 1.0 - smooth(dist / 2.5)
            w = rc.blend_w((1 - f, w), (f, {"spoon_prop": 1.0}))
        full.w[i] = rc.norm_w(w, 3)
        counts["strap/band"] = counts.get("strap/band", 0) + 1
    return {"verts_by_part": counts}
