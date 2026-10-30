"""Private helpers for build_env_crypt.py (Blender 5.2, headless). Build-free: importing this module builds nothing.

Geometry is in CENTIMETRES, Blender axes, Z up. A wall piece's front faces Blender -Y (Unreal +Y).

  Parts              accumulates closed shells (verts, faces) with a slot, a tag and a group per face; triangulates
                     every face itself (quads on the shorter diagonal, n-gons by tessellation) so the review shows
                     exactly the triangles the FBX carries, then builds one flat-shaded object through env_common
  FRAMES             right-handed (U, V, W) frames: U = right as a viewer facing the face sees it, V = up, W = the
                     face's outward normal. "up" (floor slabs), "front" (-Y faces), "back", "east" (+X), "west" (-X)
  chisel_prism       a chiselled stone block: an outline (u, v) extruded along W, chipped corners, a hand-cut chamfer
                     at the W end with dropped chips and a fan-faceted face (or a flat support face)
  relief_layer       an extruded, bevelled relief silhouette (concave outlines allowed) sitting on a carved field
  hull / strap / ridge_bar / boolean_mesh      convex hulls, swept bars, a ridged blade, exact booleans
  checks             islands (closed, outward), coplanar same-facing overlaps (z-fighting), floating parts, pivots
  render_view        one workbench render (ortho or perspective) of objects in place, for the close-up sheets
"""
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Vector, geometry
from mathutils.bvhtree import BVHTree

import env_common as ec

fc, sc, spec = ec.fc, ec.sc, ec.spec

X = np.array([1.0, 0.0, 0.0])
Y = np.array([0.0, 1.0, 0.0])
Z = np.array([0.0, 0.0, 1.0])

FRAMES = {
    "up": (X, Y, Z),
    "down": (X, -Y, -Z),
    "front": (X, Z, -Y),
    "back": (-X, Z, Y),
    "east": (Y, Z, X),
    "west": (-Y, Z, -X),
}


def _n(v):
    v = np.asarray(v, float)
    return v / max(float(np.linalg.norm(v)), 1e-12)


def lerp(a, b, t):
    return np.asarray(a, float) * (1.0 - t) + np.asarray(b, float) * t


def to_world(local, frame="up", origin=(0.0, 0.0, 0.0)):
    """(n, 3) local (u, v, w) -> world cm in a FRAMES entry (or an explicit (U, V, W) tuple)."""
    U, V, W = FRAMES[frame] if isinstance(frame, str) else frame
    loc = np.asarray(local, float)
    return np.asarray(origin, float) + loc[:, 0:1] * U + loc[:, 1:2] * V + loc[:, 2:3] * W


def rot_z(v, deg, about=(0.0, 0.0)):
    a = math.radians(deg)
    r = np.array([[math.cos(a), -math.sin(a), 0.0], [math.sin(a), math.cos(a), 0.0], [0.0, 0.0, 1.0]])
    c = np.array([about[0], about[1], 0.0])
    return (np.asarray(v, float) - c) @ r.T + c


def rot_axis(v, axis, deg, about=(0.0, 0.0, 0.0)):
    """Rodrigues rotation of points v about an axis through `about`."""
    k = _n(axis)
    a = math.radians(deg)
    p = np.asarray(v, float) - np.asarray(about, float)
    out = p * math.cos(a) + np.cross(k, p) * math.sin(a) + np.outer(p @ k, k) * (1.0 - math.cos(a))
    return out + np.asarray(about, float)


# ================================================================ 2D polygons
def area2(p):
    p = np.asarray(p, float)
    return 0.5 * float(np.sum(p[:, 0] * np.roll(p[:, 1], -1) - np.roll(p[:, 0], -1) * p[:, 1]))


def ccw2(p):
    p = np.asarray(p, float)
    return p.copy() if area2(p) > 0 else p[::-1].copy()


def mirror_u(p):
    """Mirror a 2D outline across u = 0, keeping it CCW."""
    q = np.asarray(p, float) * np.array([-1.0, 1.0])
    return q[::-1].copy()


def is_convex(p):
    p = ccw2(p)
    n = len(p)
    for i in range(n):
        a, b, c = p[i - 1], p[i], p[(i + 1) % n]
        if (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]) < -1e-9:
            return False
    return True


def inset_edges(p, d):
    """Offset each edge i (p[i] -> p[i + 1]) of a CCW polygon inward by d[i] (exact for convex outlines)."""
    p = np.asarray(p, float)
    n = len(p)
    d = np.broadcast_to(np.asarray(d, float), (n,))
    lines = []
    for i in range(n):
        e = p[(i + 1) % n] - p[i]
        e = e / max(np.hypot(*e), 1e-12)
        lines.append((p[i] + np.array([-e[1], e[0]]) * d[i], e))
    out = []
    for i in range(n):
        (p1, d1), (p2, d2) = lines[i - 1], lines[i]
        m = np.array([d1, -d2]).T
        if abs(np.linalg.det(m)) < 1e-7:
            out.append(p2)
        else:
            out.append(p1 + d1 * np.linalg.solve(m, p2 - p1)[0])
    return np.array(out)


def offset_poly(p, d, miter=2.2):
    """Move every vertex of a CCW polygon inward along its corner bisector so both edges move by about d (the miter is
    clamped to miter * d at sharp corners). Works on concave outlines while d is small next to the features."""
    p = np.asarray(p, float)
    n = len(p)
    out = []
    for i in range(n):
        e0 = p[i] - p[i - 1]
        e1 = p[(i + 1) % n] - p[i]
        e0 = e0 / max(np.hypot(*e0), 1e-12)
        e1 = e1 / max(np.hypot(*e1), 1e-12)
        n0 = np.array([-e0[1], e0[0]])
        n1 = np.array([-e1[1], e1[0]])
        b = n0 + n1
        bl = np.hypot(*b)
        if bl < 1e-6:
            b = n0
        else:
            b = b / bl
        cosh = max(float(np.dot(b, n0)), 1.0 / miter)
        out.append(p[i] + b * d / cosh)
    return np.array(out)


def segments_cross(p):
    """True when a closed 2D polygon self-intersects (non-adjacent edges cross)."""
    p = np.asarray(p, float)
    n = len(p)

    def orient(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])

    for i in range(n):
        a, b = p[i], p[(i + 1) % n]
        for j in range(i + 2, n):
            if i == 0 and j == n - 1:
                continue
            c, d = p[j], p[(j + 1) % n]
            if (orient(a, b, c) * orient(a, b, d) < 0) and (orient(c, d, a) * orient(c, d, b) < 0):
                return True
    return False


def tess(poly2d):
    """Triangles (index triples into poly2d) of a simple polygon, wound CCW in 2D."""
    pts = [Vector((float(x), float(y), 0.0)) for x, y in np.asarray(poly2d, float)]
    out = []
    p = np.asarray(poly2d, float)
    for a, b, c in geometry.tessellate_polygon([pts]):
        if (p[b, 0] - p[a, 0]) * (p[c, 1] - p[a, 1]) - (p[b, 1] - p[a, 1]) * (p[c, 0] - p[a, 0]) < 0:
            b, c = c, b
        out.append([a, b, c])
    return out


def clip_half(poly, a, b, keep_left):
    """Sutherland-Hodgman of a 2D polygon against the line a -> b (keep the left side, or the right)."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    e = b - a

    def side(q):
        s = e[0] * (q[1] - a[1]) - e[1] * (q[0] - a[0])
        return s if keep_left else -s

    out = []
    n = len(poly)
    for i in range(n):
        cur, nxt = np.asarray(poly[i], float), np.asarray(poly[(i + 1) % n], float)
        sc_, sn = side(cur), side(nxt)
        if sc_ >= -1e-9:
            out.append(cur)
        if (sc_ >= -1e-9) != (sn >= -1e-9):
            out.append(cur + (nxt - cur) * (sc_ / (sc_ - sn)))
    clean = []
    for i in range(len(out)):
        if np.linalg.norm(out[i] - out[(i + 1) % len(out)]) > 1e-6:
            clean.append(out[i])
    return np.array(clean) if clean else np.zeros((0, 2))


def split_by_line(poly, a, b):
    """A convex polygon cut by the line a -> b: (left piece, right piece); a side may be empty."""
    return clip_half(poly, a, b, True), clip_half(poly, a, b, False)


def subtract_convex(poly, hole):
    """A convex polygon minus a convex CCW hole -> convex pieces (empty slivers dropped)."""
    hole = ccw2(hole)
    pieces, rem = [], np.asarray(poly, float)
    for i in range(len(hole)):
        a, b = hole[i], hole[(i + 1) % len(hole)]
        outside = clip_half(rem, a, b, False)
        if len(outside) >= 3 and area2(outside) > 2.0:
            pieces.append(outside)
        rem = clip_half(rem, a, b, True)
        if len(rem) < 3 or area2(rem) < 1e-6:
            break
    return pieces


def arc(center, r, a0_deg, a1_deg, n):
    t = np.radians(np.linspace(a0_deg, a1_deg, n + 1))
    return np.column_stack([center[0] + r * np.cos(t), center[1] + r * np.sin(t)])


# ================================================================ parts
class Parts:
    """Closed shells with a slot, a tag, a group and an island id per triangle. Faces are triangulated on add."""

    def __init__(self, slots):
        self.slots = tuple(slots)
        self.v, self.f, self.slot, self.tag, self.group, self.island = [], [], [], [], [], []
        self.base = 0
        self.next_group = 0
        self.n_islands = 0

    def new_group(self):
        self.next_group += 1
        return self.next_group - 1

    def add(self, verts, faces, slot, tag, group=None):
        """slot is one slot name, or one per face (a boolean-carved shell whose groove floors glow)."""
        verts = np.asarray(verts, float)
        tags = [tag] * len(faces) if isinstance(tag, str) else list(tag)
        assert len(tags) == len(faces), (len(tags), len(faces))
        fslots = [slot] * len(faces) if isinstance(slot, str) else list(slot)
        assert len(fslots) == len(faces), (len(fslots), len(faces))
        if group is None:
            group = self.new_group()
        tris, ttags = triangulate_faces(verts, faces, list(zip(tags, fslots)))
        self.v.append(verts)
        self.f.extend([[self.base + int(i) for i in t] for t in tris])
        self.slot.extend([self.slots.index(s) for _, s in ttags])
        ttags = [t for t, _ in ttags]
        self.tag.extend(ttags)
        self.group.extend([group] * len(tris))
        self.island.extend([self.n_islands] * len(tris))
        self.n_islands += 1
        self.base += len(verts)
        return group

    def add_local(self, local, faces, frame, origin, slot, tag, group=None):
        return self.add(to_world(local, frame, origin), faces, slot, tag, group)

    def build(self, name):
        verts = np.concatenate(self.v)
        obj = ec.new_object(name, verts, self.f, slots=self.slots, face_slots=self.slot)
        if len(obj.data.polygons) != len(self.f):
            raise RuntimeError("%s: mesh.validate dropped faces (%d -> %d)" % (name, len(self.f), len(obj.data.polygons)))
        fix_inverted_islands(obj)
        return obj

    def tris(self):
        return sum(1 for _ in self.f)


def fix_inverted_islands(obj):
    """bmesh's recalc_face_normals (run by fc.new_object) misjudges some wide, thin closed shells (a 3 cm floor tile
    with a long arc side) and winds them inward; the signed volume is the reliable test, so flip any closed island
    whose volume is negative. Face order and material indices are kept."""
    import bmesh
    v, t = mesh_arrays(obj)
    lab, n = islands(obj)
    vol = np.zeros(n)
    np.add.at(vol, lab, np.einsum("ij,ij->i", v[t[:, 0]], np.cross(v[t[:, 1]], v[t[:, 2]])))
    bad = set(np.nonzero(vol < 0.0)[0].tolist())
    if not bad:
        return 0
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.reverse_faces(bm, faces=[bm.faces[i] for i in range(len(bm.faces)) if int(lab[i]) in bad])
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return len(bad)


def triangulate_faces(verts, faces, tags):
    """Quads split on the shorter diagonal, n-gons tessellated in their best-fit plane (winding kept)."""
    out, otags = [], []
    for face, tag in zip(faces, tags):
        face = [int(i) for i in face]
        if len(face) == 3:
            out.append(face)
            otags.append(tag)
        elif len(face) == 4:
            a, b, c, d = face
            if np.linalg.norm(verts[a] - verts[c]) <= np.linalg.norm(verts[b] - verts[d]):
                out += [[a, b, c], [a, c, d]]
            else:
                out += [[a, b, d], [b, c, d]]
            otags += [tag, tag]
        else:
            pts = verts[face]
            nrm = newell(pts)
            u = _n(np.cross(nrm, X if abs(nrm[0]) < 0.9 else Y))
            w = np.cross(nrm, u)
            p2 = np.column_stack([pts @ u, pts @ w])          # (u, w, normal) is right-handed: the face is CCW here
            for t in tess(p2):
                out.append([face[k] for k in t])
                otags.append(tag)
    return out, otags


def newell(pts):
    n = np.zeros(3)
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        n += np.array([(a[1] - b[1]) * (a[2] + b[2]), (a[2] - b[2]) * (a[0] + b[0]), (a[0] - b[0]) * (a[1] + b[1])])
    ln = np.linalg.norm(n)
    return n / ln if ln > 1e-12 else n


# ================================================================ primitives (local u, v, w unless said otherwise)
def _valid_inset(src, dst):
    n = len(src)
    if area2(dst) <= 0.02 * area2(src) or segments_cross(dst):
        return False
    return all(np.dot(dst[(i + 1) % n] - dst[i], src[(i + 1) % n] - src[i]) > 0 for i in range(n))


def safe_inset(pts, d_edge, convex):
    """The polygon moved inward by d per edge; when that folds a short (chip) edge, an anisotropic shrink about the
    bounding-box centre that moves the long sides in by the mean d instead (never folds)."""
    out = inset_edges(pts, d_edge) if convex else offset_poly(pts, float(np.mean(d_edge)))
    if _valid_inset(pts, out):
        return out
    if convex:
        # a short chip edge folded: halve the inset of the edges that reversed (a few times) before giving up on the
        # per-edge insets, so masked (0) joint ends stay square instead of falling back to the uniform shrink below
        d = np.broadcast_to(np.asarray(d_edge, float), (len(pts),)).copy()
        n = len(pts)
        for _ in range(6):
            bad = [i for i in range(n) if np.dot(out[(i + 1) % n] - out[i], pts[(i + 1) % n] - pts[i]) <= 0]
            if not bad:
                break
            for i in bad:
                d[i] *= 0.5
                d[i - 1] = min(d[i - 1], max(d[i - 1] * 0.75, 0.0))
                d[(i + 1) % n] = min(d[(i + 1) % n], max(d[(i + 1) % n] * 0.75, 0.0))
            out = inset_edges(pts, d)
            if _valid_inset(pts, out):
                return out
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    c, half = 0.5 * (lo + hi), np.maximum(0.5 * (hi - lo), 1e-6)
    d = float(np.mean(d_edge))
    k = np.clip(1.0 - d / half, 0.1, 1.0)
    return c + (pts - c) * k


def chisel_prism(outline, w0, w1, rng, ch=(0.7, 1.5), ch_h=None, ch0=0.0, chip_p=0.45, chip_cm=(0.8, 2.6),
                 drop_p=0.3, drop_cm=(0.3, 0.9), jitter=0.15, dip=(0.05, 0.45), flat_top=False, joint=0.0,
                 edge_mask=None):
    """A chiselled stone block: the (u, v) outline extruded along w from w0 to w1 (a closed shell).

    Convex corners are chipped at random (vertical chip faces), the w1 end gets a hand-cut chamfer (inset ch, height
    ch_h, per edge) with dropped chips, and the w1 face is a fan to a dipped, off-centre vertex (convex outlines) or a
    tessellated face (concave ones). flat_top keeps the w1 face exactly on its plane (a face something rests on).
    ch0 > 0 chamfers the w0 end too. joint shrinks the outline first (half a mortar joint). edge_mask (one factor per
    outline edge i = outline[i] -> outline[i + 1], convex outlines) scales the chamfers of that edge: 0 keeps a joint-
    facing end square so two neighbouring stones close their joint instead of opening a V notch through the course.
    Returns (local verts, faces, tags) with tags bottom / chamfer0 / side / chip / chamfer / top."""
    p = ccw2(outline)
    em = None
    if edge_mask is not None:
        em = np.asarray(edge_mask, float)
        if area2(np.asarray(outline, float)) < 0:
            m_ = len(em)
            em = np.array([em[(m_ - 2 - k) % m_] for k in range(m_)])
    if joint:
        p = inset_edges(p, joint) if is_convex(p) else offset_poly(p, joint)
    n0 = len(p)
    pts, chipe, efac = [], [], []
    for i in range(n0):
        prv, cur, nxt = p[i - 1], p[i], p[(i + 1) % n0]
        l0, l1 = np.linalg.norm(prv - cur), np.linalg.norm(nxt - cur)
        convex = (cur[0] - prv[0]) * (nxt[1] - cur[1]) - (cur[1] - prv[1]) * (nxt[0] - cur[0]) > 1e-9
        f_in = 1.0 if em is None else float(em[i - 1])
        f_out = 1.0 if em is None else float(em[i])
        # a corner on a joint-facing (masked 0) edge is never chipped: a chip there opens a V notch through the joint
        joint_corner = em is not None and min(f_in, f_out) <= 0.0
        if convex and chip_p > 0 and rng.uniform() < chip_p and not joint_corner:
            c = min(rng.uniform(*chip_cm), 0.3 * l0, 0.3 * l1)
            pts.append(cur + (prv - cur) / l0 * c)
            chipe.append(True)
            efac.append(min(f_in, f_out))
            pts.append(cur + (nxt - cur) / l1 * c)
            chipe.append(False)
            efac.append(f_out)
        else:
            pts.append(cur)
            chipe.append(False)
            efac.append(f_out)
    pts = np.array(pts)
    efac = np.array(efac)
    n = len(pts)
    convex_all = is_convex(pts)
    if isinstance(ch, (tuple, list)):
        d_edge = rng.uniform(ch[0], ch[1], n)
    else:
        d_edge = np.full(n, float(ch))
    d_edge = d_edge * efac
    top = safe_inset(pts, d_edge, convex_all)
    d_vert = 0.5 * (d_edge + np.roll(d_edge, 1))
    if ch_h is None:
        hgt = np.minimum(d_vert, 0.45 * (w1 - w0))
    else:
        hgt = np.minimum(np.full(n, float(ch_h)) * (d_vert / max(float(np.mean(d_vert)), 1e-9)), (w1 - w0) - 0.3)
    cen = top.mean(axis=0)
    wt = np.full(n, float(w1))
    dropped = np.zeros(n, bool)
    if not flat_top:
        top = top + rng.uniform(-jitter, jitter, top.shape)
        wt += rng.uniform(-jitter * 0.6, 0.0, n)
        dropped = rng.uniform(size=n) < drop_p
        wt[dropped] -= rng.uniform(*drop_cm, int(dropped.sum()))
        top[dropped] += (cen - top[dropped]) * 0.05
    wm = w1 - hgt + (rng.uniform(-0.1, 0.1, n) if not flat_top else 0.0)
    wm = np.minimum(wm, wt - 0.15)
    rings = []
    if ch0 > 0:
        b0 = safe_inset(pts, float(ch0) * efac, convex_all)
        rings.append((b0, np.full(n, float(w0))))
        rings.append((pts, np.full(n, float(w0 + min(ch0, 0.4 * (w1 - w0))))))
    else:
        rings.append((pts, np.full(n, float(w0))))
    rings.append((pts, wm))
    rings.append((top, wt))
    verts = np.concatenate([np.column_stack([r2, w]) for r2, w in rings])
    faces, tags = [], []
    # bottom (w0) face, facing -w
    for t in tess(rings[0][0]):
        faces.append([t[0], t[2], t[1]])
        tags.append("bottom")
    for k in range(len(rings) - 1):
        a, b = k * n, (k + 1) * n
        last = k == len(rings) - 2
        for i in range(n):
            j = (i + 1) % n
            faces.append([a + i, a + j, b + j, b + i])
            if ch0 > 0 and k == 0:
                tags.append("chamfer0")
            elif last:
                tags.append("chip" if (chipe[i] or dropped[i] or dropped[j]) else "chamfer")
            else:
                tags.append("chip" if chipe[i] else "side")
    tb = (len(rings) - 1) * n
    if convex_all:
        c3 = np.array([cen[0], cen[1], w1])
        if not flat_top:
            c3[:2] += rng.uniform(0.0, 0.3) * (top[int(rng.integers(n))] - cen)     # stays inside the convex face
            c3[2] -= rng.uniform(*dip)
        verts = np.concatenate([verts, [c3]])
        ci = len(verts) - 1
        for i in range(n):
            faces.append([tb + i, tb + (i + 1) % n, ci])
            tags.append("top")
    else:
        for t in tess(top):
            faces.append([tb + t[0], tb + t[1], tb + t[2]])
            tags.append("top")
    return verts, faces, tags


def relief_layer(outline, w0, h, rng, bevel=1.2, jitter=0.25, lift=None, check=True):
    """An extruded relief silhouette (concave allowed): side wall from w0 to w0 + h - bevel, a bevel ring offset inward
    by bevel up to w0 + h (+ jitter, + lift(u, v) per top vertex), a tessellated top. Closed (bottom cap at w0).
    Tags rbottom / rside / rbevel / rtop."""
    p = ccw2(outline)
    n = len(p)
    top = offset_poly(p, bevel)
    if check and (area2(top) <= 0 or segments_cross(top)):
        raise ValueError("relief_layer: the bevel offset folds the outline (bevel %.2f): %s" % (bevel, p.round(1).tolist()))
    wm = np.full(n, w0 + h - bevel) + rng.uniform(-0.12, 0.12, n)
    wt = np.full(n, w0 + h) + rng.uniform(-jitter, jitter, n)
    if lift is not None:
        wt += np.array([lift(u, v) for u, v in top])
    wm = np.minimum(wm, wt - 0.2)
    verts = np.concatenate([np.column_stack([p, np.full(n, float(w0))]), np.column_stack([p, wm]),
                            np.column_stack([top, wt])])
    faces, tags = [], []
    for t in tess(p):
        faces.append([t[0], t[2], t[1]])
        tags.append("rbottom")
    for k, tag in ((0, "rside"), (1, "rbevel")):
        a, b = k * n, (k + 1) * n
        for i in range(n):
            j = (i + 1) % n
            faces.append([a + i, a + j, b + j, b + i])
            tags.append(tag)
    for t in tess(top):
        faces.append([2 * n + t[0], 2 * n + t[1], 2 * n + t[2]])
        tags.append("rtop")
    return verts, faces, tags


def ridge_bar(v0, v1, hw0, hw1, w0, edge0, edge1, ridge0, ridge1, nseg=1, tip=False):
    """A ridged blade in local (u, v, w) along v from v0 to v1: half width hw, edge thickness above w0, a centre ridge.
    tip=True closes v0 to a point (the blade's point)."""
    rings = []
    for k in range(nseg + 1):
        t = k / nseg
        v = v0 + (v1 - v0) * t
        hw = hw0 + (hw1 - hw0) * t
        e = edge0 + (edge1 - edge0) * t
        r = ridge0 + (ridge1 - ridge0) * t
        rings.append(np.array([(hw, v, w0), (hw, v, w0 + e), (0.0, v, w0 + r), (-hw, v, w0 + e), (-hw, v, w0)]))
    if tip:
        tip_pt = np.array([(0.0, v0 - (hw0 * 1.6), w0 + edge0 * 0.6)])
        verts = np.concatenate([tip_pt] + rings)
        faces = []
        for s in range(5):
            faces.append([0, 1 + (s + 1) % 5, 1 + s])
        k = 5
        for i in range(len(rings) - 1):
            a, b = 1 + i * k, 1 + (i + 1) * k
            for s in range(k):
                s2 = (s + 1) % k
                faces.append([a + s, a + s2, b + s2, b + s])
        last = 1 + (len(rings) - 1) * k
        faces.append(list(range(last, last + k)))
        return verts, faces
    return fc.loft(rings)


def hull(points, dissolve_deg=0.5):
    """Convex hull (bmesh) of cm points -> (verts, faces) with coplanar triangles merged into facets, wound outward."""
    bm = bmesh.new()
    for p in np.asarray(points, float):
        bm.verts.new(p.tolist())
    res = bmesh.ops.convex_hull(bm, input=bm.verts[:])
    junk = [g for g in res.get("geom_interior", []) + res.get("geom_unused", []) if isinstance(g, bmesh.types.BMVert)]
    junk = list({id(g): g for g in junk if g.is_valid}.values())
    if junk:
        bmesh.ops.delete(bm, geom=junk, context="VERTS")
    if dissolve_deg:
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(dissolve_deg), verts=bm.verts[:], edges=bm.edges[:])
    bm.verts.index_update()
    v = np.array([x.co[:] for x in bm.verts], float)
    f = [[x.index for x in face.verts] for face in bm.faces]
    bm.free()
    centre = v.mean(axis=0)
    out = []
    for face in f:
        if np.dot(newell(v[face]), v[face].mean(axis=0) - centre) < 0:
            face = face[::-1]
        out.append(face)
    return v, out


def path_frames(pts, up=Z):
    """Per-point (tangent, side, normal) frames along a 3D path (parallel-transport-ish from an up hint)."""
    pts = np.asarray(pts, float)
    out = []
    for i in range(len(pts)):
        t = _n(pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)])
        s = np.cross(t, up)
        if np.linalg.norm(s) < 1e-6:
            s = np.cross(t, X)
        s = _n(s)
        nrm = np.cross(s, t)
        out.append((t, s, nrm))
    return out


def tube(pts, radii, sides=6, up=Z, phase=0.0, scale_n=1.0):
    """A faceted tube (closed) through 3D points with one radius per point (an ellipse when scale_n != 1)."""
    pts = np.asarray(pts, float)
    radii = np.broadcast_to(np.asarray(radii, float), (len(pts),))
    rings = []
    for p, r, (t, s, nrm) in zip(pts, radii, path_frames(pts, up)):
        rings.append(fc.ring(p, r, r * scale_n, sides, s, nrm, phase))
    return fc.loft(rings)


def strap(pts, normals, binormal, hn, hb):
    """A rectangular-section bar through pts (half size hn along each normal, hb along the binormal), capped."""
    pts = np.asarray(pts, float)
    b = _n(binormal)
    rings = []
    for p, nr in zip(pts, np.asarray(normals, float)):
        nr = _n(nr)
        rings.append(np.array([p + nr * hn + b * hb, p - nr * hn + b * hb, p - nr * hn - b * hb, p + nr * hn - b * hb]))
    return fc.loft(rings)


def lathe_closed(profile, segments, phase_deg=0.0, jitter=0.0, rng=None):
    """Revolve a CLOSED (r, z) polygon about Z (a hoop / band)."""
    m = len(profile)
    verts = []
    for r, z in profile:
        for s in range(segments):
            a = math.radians(phase_deg) + math.tau * s / segments
            rr = r + (rng.uniform(-jitter, jitter) if (jitter and rng is not None) else 0.0)
            verts.append((rr * math.cos(a), rr * math.sin(a), z))
    faces = []
    for i in range(m):
        i2 = (i + 1) % m
        for s in range(segments):
            s2 = (s + 1) % segments
            faces.append([i * segments + s, i2 * segments + s, i2 * segments + s2, i * segments + s2])
    return np.array(verts, float), faces


def prism2d(poly2d, w0, w1):
    """A straight closed prism of a (u, v) polygon (concave allowed) from w0 to w1 in local coordinates."""
    p = ccw2(poly2d)
    n = len(p)
    verts = np.concatenate([np.column_stack([p, np.full(n, float(w0))]), np.column_stack([p, np.full(n, float(w1))])])
    faces = [[t[0], t[2], t[1]] for t in tess(p)]
    faces += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
    faces += [[n + t[0], n + t[1], n + t[2]] for t in tess(p)]
    return verts, faces


def taper_prism2d(poly_front, poly_floor, w_front, w_floor):
    """A closed frustum between two (u, v) polygons with the same vertex count (a tapered groove cutter)."""
    a, b = np.asarray(poly_front, float), np.asarray(poly_floor, float)
    if area2(a) < 0:
        a, b = a[::-1].copy(), b[::-1].copy()
    n = len(a)
    verts = np.concatenate([np.column_stack([a, np.full(n, float(w_front))]), np.column_stack([b, np.full(n, float(w_floor))])])
    faces = [[t[0], t[2], t[1]] for t in tess(a)]
    faces += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
    faces += [[n + t[0], n + t[1], n + t[2]] for t in tess(b)]
    return verts, faces


def clip_hull(points, normal, d, dissolve_deg=0.5):
    """The convex hull of points clipped by the half-space normal . p <= d (exact: the kept vertices plus every hull
    edge's crossing of the plane, hulled again)."""
    v, f = hull(points, dissolve_deg=0.0)
    nrm = _n(normal)
    h = v @ nrm - d
    keep = [p for p, hh in zip(v, h) if hh <= 1e-9]
    edges = set()
    for face in f:
        for i in range(len(face)):
            a, b = face[i], face[(i + 1) % len(face)]
            edges.add((min(a, b), max(a, b)))
    for a, b in edges:
        if (h[a] > 1e-9) != (h[b] > 1e-9):
            t = h[a] / (h[a] - h[b])
            keep.append(v[a] + (v[b] - v[a]) * t)
    return hull(np.array(keep), dissolve_deg=dissolve_deg)


# ================================================================ exact booleans
def _temp_object(name, verts_cm, faces):
    me = bpy.data.meshes.new(name)
    me.from_pydata((np.asarray(verts_cm, float) * 0.01).tolist(), [], [[int(i) for i in f] for f in faces])
    me.validate(verbose=False)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-7)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def boolean_mesh(base, cutters, operation="DIFFERENCE"):
    """Exact boolean of a closed (verts, faces) base with closed cutters (applied one after another).
    Returns (verts cm, triangle faces)."""
    a = _temp_object("_BoolBase", *base)
    temps = [a]
    try:
        for k, cut in enumerate(cutters):
            c = _temp_object("_BoolCut%d" % k, *cut)
            c.hide_render = True
            temps.append(c)
            m = a.modifiers.new("b%d" % k, "BOOLEAN")
            m.operation = operation
            m.solver = "EXACT"
            m.object = c
        dg = bpy.context.evaluated_depsgraph_get()
        dg.update()
        me = bpy.data.meshes.new_from_object(a.evaluated_get(dg))
        bm = bmesh.new()
        bm.from_mesh(me)
        # the exact solver leaves sub-millimetre slivers where a cutter grazes a chamfer: collapse edges under 0.6 mm
        # (keeps the shell closed; nothing that small reads)
        bmesh.ops.dissolve_degenerate(bm, dist=6e-4, edges=bm.edges[:])
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
        bmesh.ops.dissolve_degenerate(bm, dist=6e-4, edges=bm.edges[:])
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
        bm.verts.index_update()
        v = np.array([x.co[:] for x in bm.verts], float) * 100.0
        f = [[x.index for x in face.verts] for face in bm.faces]
        bm.free()
        bpy.data.meshes.remove(me)
    finally:
        for o in temps:
            me = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if me.users == 0:
                bpy.data.meshes.remove(me)
    return v, f


# ================================================================ painting
def paint_parts(obj, parts, colour_fn, jitter=0.06, seed=5, cavity_darken=0.35, glow_slot=None, glow_rgb=None):
    """colour_fn(tag, group, centre_cm, normal) -> linear rgb per triangle. The hand-painted variation is one value / hue
    jitter per FACET (coplanar triangles of one island share it) so a flat face never shows its triangulation. Faces
    of glow_slot are written flat with glow_rgb and A = 1 after the cavity pass."""
    centres = fc.face_centers_cm(obj)
    normals = fc.face_normals(obj)
    rng = np.random.default_rng(seed)
    keys = {}
    rgb = np.zeros((len(parts.tag), 3))
    for i, (t, g, isl) in enumerate(zip(parts.tag, parts.group, parts.island)):
        nk = tuple(np.round(normals[i] * 30.0).astype(int))
        dk = int(round(float(np.dot(normals[i], centres[i])) / 0.4))
        key = (isl, nk, dk)
        if key not in keys:
            keys[key] = (rng.uniform(-jitter, jitter), rng.uniform(-jitter * 0.5, jitter * 0.5))
        val, hue = keys[key]
        c = np.asarray(colour_fn(t, g, centres[i], normals[i]), float)
        rgb[i] = c * (1.0 + val) * np.array([1.0 + hue, 1.0, 1.0 - hue])
    fc.paint(obj, rgb, variation=0.0, cavity_darken=cavity_darken)
    if glow_slot is not None:
        mesh = obj.data
        attr = mesh.color_attributes["Col"]
        col = np.empty(len(mesh.loops) * 4)
        attr.data.foreach_get("color", col)
        col = col.reshape(-1, 4)
        slots = np.empty(len(mesh.polygons), np.int64)
        mesh.polygons.foreach_get("material_index", slots)
        gi = list(parts.slots).index(glow_slot)
        for p in mesh.polygons:
            if slots[p.index] == gi:
                col[p.loop_start:p.loop_start + p.loop_total, :3] = glow_rgb
                col[p.loop_start:p.loop_start + p.loop_total, 3] = 1.0
        attr.data.foreach_set("color", col.ravel())
        mesh.update()


# ================================================================ checks
def mesh_arrays(obj):
    v = fc.verts_cm(obj)
    mesh = obj.data
    t = np.array([list(p.vertices) for p in mesh.polygons], np.int64)
    return v, t


def islands(obj):
    """Per-face island label (faces connected through shared vertices) and the island count."""
    v, t = mesh_arrays(obj)
    parent = list(range(len(v)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for tri in t:
        r0 = find(int(tri[0]))
        for x in tri[1:]:
            r = find(int(x))
            if r != r0:
                parent[r] = r0
    roots = np.array([find(int(tri[0])) for tri in t])
    _, lab = np.unique(roots, return_inverse=True)
    return lab.ravel(), int(lab.max()) + 1


def island_report(obj):
    """[(island, tris, closed, volume_cm3)] - every island must be a closed shell wound outward."""
    v, t = mesh_arrays(obj)
    lab, n = islands(obj)
    out = []
    for k in range(n):
        tk = t[lab == k]
        e = np.concatenate([tk[:, [0, 1]], tk[:, [1, 2]], tk[:, [2, 0]]])
        _, cnt = np.unique(np.sort(e, axis=1), axis=0, return_counts=True)
        closed = bool(np.all(cnt == 2))
        a, b, c = v[tk[:, 0]], v[tk[:, 1]], v[tk[:, 2]]
        vol = float(np.einsum("ij,ij->i", a, np.cross(b, c)).sum() / 6.0)
        out.append((k, len(tk), closed, vol))
    return out


def _tri_overlap_2d(a, b):
    """Area of the intersection of two 2D triangles (convex clip)."""
    poly = [np.asarray(p, float) for p in a]
    if area2(np.array(b)) < 0:
        b = b[::-1]
    for i in range(3):
        if len(poly) < 3:
            return 0.0
        poly = list(clip_half(poly, b[i], b[(i + 1) % 3], True))
    return abs(area2(np.array(poly))) if len(poly) >= 3 else 0.0


def zfight_report(obj, tol_d=0.2, tol_n=0.9995, min_area=0.05, max_report=8):
    """Pairs of triangles from DIFFERENT islands that lie on the same plane (within tol_d cm), face the same way and
    overlap by more than min_area cm2: the coplanar overlaps that z-fight in the engine."""
    v, t = mesh_arrays(obj)
    lab, n = islands(obj)
    a, b, c = v[t[:, 0]], v[t[:, 1]], v[t[:, 2]]
    nrm = np.cross(b - a, c - a)
    ln = np.linalg.norm(nrm, axis=1)
    ok = ln > 1e-9
    nrm = nrm / np.maximum(ln, 1e-12)[:, None]
    cen = (a + b + c) / 3.0
    d = np.einsum("ij,ij->i", nrm, cen)
    lo = np.array([v[np.unique(t[lab == k])].min(axis=0) for k in range(n)])
    hi = np.array([v[np.unique(t[lab == k])].max(axis=0) for k in range(n)])
    hits = []
    idx = [np.nonzero((lab == k) & ok)[0] for k in range(n)]
    for i in range(n):
        for j in range(i + 1, n):
            if np.any(lo[i] > hi[j] + tol_d) or np.any(lo[j] > hi[i] + tol_d):
                continue
            fi, fj = idx[i], idx[j]
            if not len(fi) or not len(fj):
                continue
            dots = nrm[fi] @ nrm[fj].T
            dd = np.abs(d[fi][:, None] - d[fj][None, :])
            cand = np.argwhere((dots > tol_n) & (dd < tol_d))
            for p, q in cand:
                fa, fb = fi[p], fj[q]
                nn = nrm[fa]
                # truly coplanar: every vertex of each triangle within tol_d of the other's plane
                if (np.abs((v[t[fb]] - cen[fa]) @ nn).max() > tol_d or
                        np.abs((v[t[fa]] - cen[fb]) @ nrm[fb]).max() > tol_d):
                    continue
                u = _n(np.cross(nn, X if abs(nn[0]) < 0.9 else Y))
                w = np.cross(nn, u)
                ta = [(v[k] @ u, v[k] @ w) for k in t[fa]]
                tb = [(v[k] @ u, v[k] @ w) for k in t[fb]]
                ar = _tri_overlap_2d(ta, tb)
                if ar > min_area:
                    hits.append((int(fa), int(fb), round(ar, 3), cen[fa].round(1).tolist() + nrm[fa].round(2).tolist()
                                 + cen[fb].round(1).tolist() + nrm[fb].round(2).tolist()))
                    if len(hits) >= max_report:
                        return hits
    return hits


def floating_report(obj, grounded_fn, touch=0.08):
    """Islands that neither rest on the ground (grounded_fn(island verts) True) nor touch / intersect an island that
    does (transitively). Returns [(island, bbox centre)]."""
    v, t = mesh_arrays(obj)
    lab, n = islands(obj)
    trees, vs, lo, hi = [], [], [], []
    for k in range(n):
        tk = t[lab == k]
        used = np.unique(tk)
        remap = {int(x): i for i, x in enumerate(used)}
        vk = v[used]
        trees.append(BVHTree.FromPolygons(vk.tolist(), [[remap[int(x)] for x in tri] for tri in tk], all_triangles=True))
        vs.append(vk)
        lo.append(vk.min(axis=0))
        hi.append(vk.max(axis=0))
    adj = [set() for _ in range(n)]
    for i in range(n):
        for j in range(i + 1, n):
            if np.any(lo[i] > hi[j] + touch) or np.any(lo[j] > hi[i] + touch):
                continue
            contact = bool(trees[i].overlap(trees[j]))
            if not contact:
                for src, tree in ((vs[i], trees[j]), (vs[j], trees[i])):
                    for p in src:
                        hit = tree.find_nearest(Vector(p.tolist()))
                        if hit[0] is None:
                            continue
                        # touching, or inside the other (closed, outward) shell
                        if hit[3] < touch or np.dot(p - np.array(hit[0]), np.array(hit[1])) < 0.0:
                            contact = True
                            break
                    if contact:
                        break
            if contact:
                adj[i].add(j)
                adj[j].add(i)
    seen = set(k for k in range(n) if grounded_fn(vs[k]))
    stack = list(seen)
    while stack:
        k = stack.pop()
        for m in adj[k]:
            if m not in seen:
                seen.add(m)
                stack.append(m)
    return [(k, ((lo[k] + hi[k]) * 0.5).round(1).tolist()) for k in range(n) if k not in seen]


def ground_floor(vk):
    return float(vk[:, 2].min()) < 0.08


def ground_wall(vk):
    return float(vk[:, 2].min()) < 0.08 or float(vk[:, 1].max()) > -0.08


# ================================================================ review renders
REVIEW_BG = (0.21, 0.215, 0.23)


def remove_object(o):
    for ch in [c for c in bpy.data.objects if c.parent is o]:
        remove_object(ch)
    mesh = o.data if o.type == "MESH" else None
    bpy.data.objects.remove(o, do_unlink=True)
    if mesh is not None and mesh.users == 0:
        bpy.data.meshes.remove(mesh)


def copy_mesh(obj, offset=(0.0, 0.0, 0.0), rot_deg=0.0, name=None):
    c = bpy.data.objects.new(name or (obj.name + "_Copy"), obj.data.copy())
    bpy.context.scene.collection.objects.link(c)
    v = fc.verts_cm(c)
    if rot_deg:
        v = rot_z(v, rot_deg)
    fc.set_verts_cm(c, v + np.asarray(offset, float))
    return c


def painted_box(name, center, size, rgb):
    v, f = sc.box(center, size)
    o = fc.new_object(name, v, f, slots=("EnvStone",))
    fc.paint(o, np.repeat(np.asarray(rgb, float)[None, :], len(f), axis=0), variation=0.0, cavity_darken=0.0)
    return o


def render_view(objs, path, view, size=(1600, 1000), margin=1.08, ortho=True, target_cm=None, half_cm=None, lens=50.0,
                eye_cm=None, shadows=True):
    """One workbench render of objs in place (vertex colours, cavity). The frame fits their bounds from direction
    `view` unless half_cm (half the longer image side, cm) is given; eye_cm places a perspective camera."""
    scene = bpy.context.scene
    objs = list(objs)
    hidden = [o for o in scene.objects if o not in objs and o.type == "MESH"]
    hidden_state = [o.hide_render for o in hidden]
    pts = np.concatenate([fc.verts_cm(o) + np.asarray(o.location, float) * 100.0 for o in objs])
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    target = 0.5 * (lo + hi) if target_cm is None else np.asarray(target_cm, float)
    if eye_cm is not None:
        view = np.asarray(eye_cm, float) - target
    d = _n(view)
    right = _n(np.cross(Z, d)) if abs(d[2]) < 0.999 else X
    up = np.cross(d, right)
    w, h = size
    long_side = float(max(w, h))
    if half_cm is None:
        rel = pts - target
        hw, hh = np.abs(rel @ right).max(), np.abs(rel @ up).max()
        half_cm = max(hw * long_side / w, hh * long_side / h) * margin
    cam_data = bpy.data.cameras.new("_CryptCam")
    cam_data.clip_start, cam_data.clip_end = 0.02, 3000.0
    cam = bpy.data.objects.new("_CryptCam", cam_data)
    scene.collection.objects.link(cam)
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    sh = scene.display.shading
    prev = (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
            scene.render.filepath, sh.color_type, sh.light, sh.show_cavity, scene.render.film_transparent,
            tuple(scene.world.color), sh.show_shadows, sh.show_specular_highlight)
    try:
        for o in hidden:
            o.hide_render = True
        saved = [o.hide_render for o in objs]
        for o in objs:
            o.hide_render = False
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        sh.light = "STUDIO"
        sh.color_type = "VERTEX"
        sh.show_cavity = True
        scene.render.film_transparent = False
        scene.world.color = REVIEW_BG
        sh.show_shadows = bool(shadows)
        sh.show_specular_highlight = False
        scene.render.resolution_x, scene.render.resolution_y = size
        scene.render.resolution_percentage = 100
        if ortho and eye_cm is None:
            cam_data.type = "ORTHO"
            cam_data.ortho_scale = 2.0 * half_cm * 0.01
            dist = float(np.linalg.norm(hi - lo)) * 0.02 + 5.0
            eye = target * 0.01 + d * dist
        elif eye_cm is not None:
            cam_data.lens = lens
            eye = np.asarray(eye_cm, float) * 0.01
        else:
            cam_data.lens = lens
            eye = target * 0.01 + d * (half_cm * 0.01 / (18.0 / lens))
        fc._look_at(cam, tuple(eye), tuple(target * 0.01))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        for o, hr in zip(objs, saved):
            o.hide_render = hr
    finally:
        for o, hr in zip(hidden, hidden_state):
            o.hide_render = hr
        (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
         scene.render.filepath, sh.color_type, sh.light, sh.show_cavity, scene.render.film_transparent) = prev[:9]
        scene.world.color = prev[9]
        sh.show_shadows = prev[10]
        sh.show_specular_highlight = prev[11]
        bpy.data.objects.remove(cam)
        bpy.data.cameras.remove(cam_data)
    return path
