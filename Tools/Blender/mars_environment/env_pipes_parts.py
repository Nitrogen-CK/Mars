"""Private geometry / check / render helpers for build_env_pipes.py (Blender 5.2, headless). Build-free: importing this
module builds nothing. Everything is in CENTIMETRES, Blender axes (Z up); Unreal local = (x, -y, z).

Contents
  vectors + frames      rot_x / rot_y / rot_z (degrees), frame(fwd, up), xf(), Unreal rotator conversion
  primitives            revolve (lathe about any axis with an explicit reference direction, so port rings line up),
                        sweep (tube through ring specs, mitred elbows), hex / rivet heads, prisms, oriented boxes,
                        rectangular bars with mitred corners, chiselled stone blocks
  Parts                 per-face slot / tag / part bookkeeping -> one flat-shaded object (env_common.new_object)
  checks                closed + outward shells per part, attachment graph (no floating parts), same-facing coplanar
                        overlaps (z-fighting), port ring matching
  renders               render_view (workbench, in place, ortho or perspective), review_copy
"""
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils.bvhtree import BVHTree

import env_common as ec

fc = ec.fc
sc = ec.sc
spec = ec.spec

X = np.array([1.0, 0.0, 0.0])
Y = np.array([0.0, 1.0, 0.0])
Z = np.array([0.0, 0.0, 1.0])
MIRROR = np.diag([1.0, -1.0, 1.0])               # Blender <-> Unreal local axes
REVIEW_BG = (0.21, 0.215, 0.23)


# ================================================================ vectors + frames
def _n(v):
    v = np.asarray(v, float)
    return v / max(float(np.linalg.norm(v)), 1e-12)


def lerp(a, b, t):
    return np.asarray(a, float) * (1.0 - t) + np.asarray(b, float) * t


def rot_x(deg):
    a = math.radians(deg)
    return np.array([[1.0, 0.0, 0.0], [0.0, math.cos(a), -math.sin(a)], [0.0, math.sin(a), math.cos(a)]])


def rot_y(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), 0.0, math.sin(a)], [0.0, 1.0, 0.0], [-math.sin(a), 0.0, math.cos(a)]])


def rot_z(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), -math.sin(a), 0.0], [math.sin(a), math.cos(a), 0.0], [0.0, 0.0, 1.0]])


def frame(fwd, up):
    """3x3 rotation whose columns are the local X (fwd), Y (= up x fwd) and Z (up) axes."""
    x = _n(fwd)
    z = _n(np.asarray(up, float) - np.dot(up, x) * x)
    return np.column_stack([x, np.cross(z, x), z])


def xf(v, R=None, t=None):
    v = np.asarray(v, float)
    if R is not None:
        v = v @ np.asarray(R, float).T
    if t is not None:
        v = v + np.asarray(t, float)
    return v


def ue_vec(v):
    return [round(float(c), 4) + 0.0 for c in np.asarray(v, float) * np.array([1.0, -1.0, 1.0])]


def ue_matrix(R):
    """A Blender rotation (columns = local axes) as the same rotation in Unreal's mirrored-Y frame."""
    return MIRROR @ np.asarray(R, float) @ MIRROR


def ue_rotator(R):
    """Unreal FRotator (pitch, yaw, roll degrees) of a Blender rotation matrix, per FMatrix::Rotator()."""
    m = ue_matrix(R)
    xa, ya, za = m[:, 0], m[:, 1], m[:, 2]
    pitch = math.degrees(math.atan2(xa[2], math.hypot(xa[0], xa[1])))
    yaw = math.degrees(math.atan2(xa[1], xa[0]))
    sy = np.array([-math.sin(math.radians(yaw)), math.cos(math.radians(yaw)), 0.0])
    roll = math.degrees(math.atan2(float(np.dot(za, sy)), float(np.dot(ya, sy))))
    return [round(pitch, 4) + 0.0, round(yaw, 4) + 0.0, round(roll, 4) + 0.0]


def ue_rotation_matrix(pitch, yaw, roll):
    """Unreal FRotationMatrix as columns = local axes (Unreal frame)."""
    p, y, r = (math.radians(a) for a in (pitch, yaw, roll))
    cp, sp, cy, sy, cr, sr = math.cos(p), math.sin(p), math.cos(y), math.sin(y), math.cos(r), math.sin(r)
    xa = [cp * cy, cp * sy, sp]
    ya = [sr * sp * cy - cr * sy, sr * sp * sy + cr * cy, -sr * cp]
    za = [-(cr * sp * cy + sr * sy), cy * sr - cr * sp * sy, cr * cp]
    return np.column_stack([xa, ya, za])


def port_json(loc, R, note=None):
    """A connection frame for the sidecar, in Unreal local cm: where the NEXT piece's pivot goes and how it turns
    (its +X = forward = the direction the run continues, its +Z = up)."""
    m = ue_matrix(R)
    out = {"location_cm": ue_vec(loc), "rotation_pyr_deg": ue_rotator(R),
           "forward": ue_vec(R[:, 0]), "up": ue_vec(R[:, 2])}
    if note:
        out["note"] = note
    assert np.allclose(ue_rotation_matrix(*out["rotation_pyr_deg"]), m, atol=1e-4), (out, m)
    return out


# ================================================================ primitives
def revolve(profile, segments, origin=(0.0, 0.0, 0.0), axis=X, ref=None, phase_deg=0.0, closed=False,
            jitter=0.0, rng=None, keep_rings=()):
    """Revolve an (r, s) profile about `axis` through `origin` (s = distance along the axis). Ring vertex k sits at
    angle phase + k * 360 / segments measured from `ref` toward axis x ref, so a ring about +X with ref +Y puts vertex 0
    on +Y and vertex segments/4 on +Z (the canonical pipe ring). r == 0 rows are poles (open profiles). closed joins the
    last profile point back to the first (a hoop). jitter (cm) moves every ring vertex radially at random, except the
    profile rows listed in keep_rings (port rings must stay exact)."""
    axis = _n(axis)
    if ref is None:
        ref = Y if abs(axis[1]) < 0.9 else X
    u = _n(np.asarray(ref, float) - np.dot(ref, axis) * axis)
    w = np.cross(axis, u)
    o = np.asarray(origin, float)
    verts, rings = [], []
    for i, (r, s) in enumerate(profile):
        if r < 1e-9 and not closed:
            rings.append([len(verts)])
            verts.append(o + axis * s)
            continue
        start = len(verts)
        for k in range(segments):
            a = math.radians(phase_deg) + math.tau * k / segments
            rr = r
            if jitter and rng is not None and i not in keep_rings:
                rr = r + rng.uniform(-jitter, jitter)
            verts.append(o + axis * s + rr * (math.cos(a) * u + math.sin(a) * w))
        rings.append(list(range(start, start + segments)))
    pairs = list(zip(rings[:-1], rings[1:]))
    if closed:
        pairs.append((rings[-1], rings[0]))
    faces = []
    for a, b in pairs:
        for k in range(segments):
            k2 = (k + 1) % segments
            if len(a) == 1:
                faces.append([a[0], b[k2], b[k]])
            elif len(b) == 1:
                faces.append([a[k], a[k2], b[0]])
            else:
                faces.append([a[k], a[k2], b[k2], b[k]])
    return np.array(verts, float), faces


def ring_points(center, t, u_ref, radius, sides, phase_deg=0.0, stretch=1.0):
    """Ring about the unit tangent t: vertex k at angle phase + k*360/sides from u (u_ref made perpendicular to t)
    toward w = t x u. stretch scales the w half-axis (a mitre ring cut by the bisector plane of a bend whose binormal
    is u)."""
    t = _n(t)
    u = _n(np.asarray(u_ref, float) - np.dot(u_ref, t) * t)
    w = np.cross(t, u)
    a = np.radians(phase_deg) + np.arange(sides) * math.tau / sides
    rr = np.broadcast_to(np.asarray(radius, float), (sides,))
    return (np.asarray(center, float)[None, :] + (rr * np.cos(a))[:, None] * u[None, :]
            + (rr * np.sin(a) * stretch)[:, None] * w[None, :])


def sweep(rings, cap_start=True, cap_end=True):
    """Skin consecutive rings (same vertex count, same angular order) into a tube; caps are n-gons."""
    k = len(rings[0])
    verts = np.concatenate([np.asarray(r, float) for r in rings])
    faces = []
    for i in range(len(rings) - 1):
        a, b = i * k, (i + 1) * k
        for s in range(k):
            s2 = (s + 1) % k
            faces.append([a + s, a + s2, b + s2, b + s])
    if cap_start:
        faces.append(list(range(k - 1, -1, -1)))
    if cap_end:
        last = (len(rings) - 1) * k
        faces.append(list(range(last, last + k)))
    return verts, faces


def head(center, normal, rc, h, sides=6, sink=0.35, chamfer=0.3, rng=None, ref=None):
    """A hex bolt head / nut (sides 6) or a square nut (4): a prism of circumradius rc and height h on a surface along
    normal, chamfered top, its base sunk `sink` into the surface. 36 tris for a hex."""
    prof = [(0.0, -sink), (rc, -sink), (rc, h * (1.0 - chamfer)), (rc * 0.74, h), (0.0, h)]
    phase = rng.uniform(0.0, 60.0) if rng is not None else 0.0
    return revolve(prof, sides, origin=center, axis=normal, ref=ref, phase_deg=phase)


def rivet(center, normal, r, h, rng=None, sides=5, sink=0.3):
    """A faceted dome rivet (5 sides: 20 tris; 4 sides with sides=4 and a pyramid profile: 8 tris)."""
    if sides <= 4:
        prof = [(0.0, -sink), (r, -sink), (r, 0.12), (0.0, h)]
    else:
        prof = [(0.0, -sink), (r, -sink), (r, 0.1), (0.65 * r, 0.75 * h), (0.0, h)]
    phase = rng.uniform(0.0, 90.0) if rng is not None else 0.0
    return revolve(prof, sides, origin=center, axis=normal, phase_deg=phase)


def prism(poly2d, z0, z1, R=None, t=None):
    """Extrude a CCW 2D polygon (x, y) from z0 to z1 (local), then rotate / translate. Closed, outward."""
    p = np.asarray(poly2d, float)
    area = 0.5 * np.sum(p[:, 0] * np.roll(p[:, 1], -1) - np.roll(p[:, 0], -1) * p[:, 1])
    if area < 0:
        p = p[::-1]
    n = len(p)
    v = np.concatenate([np.column_stack([p, np.full(n, z0)]), np.column_stack([p, np.full(n, z1)])])
    faces = [list(range(n))[::-1], list(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
    return xf(v, R, t), faces


def obox(center, size, R=None):
    """Oriented box: size along the local axes of R (columns)."""
    v, f = sc.box((0.0, 0.0, 0.0), size)
    return xf(v, R, center), f


def bar(points, normals, binormal, hn, hb, closed=False, cap=True, mitre=True):
    """Rectangular bar through points (half size hn along each point's in-plane normal, hb along binormal). With mitre,
    interior corners are widened by 1 / cos(half turn) so the bar keeps its width round bends (polyline in the plane
    normal to binormal)."""
    pts = np.asarray(points, float)
    n = len(pts)
    b = _n(binormal)
    hn = np.broadcast_to(np.asarray(hn, float), (n,)).copy()
    hb = np.broadcast_to(np.asarray(hb, float), (n,))
    nrm = np.array([_n(x) for x in normals])
    if mitre:
        for i in range(n):
            if not closed and (i == 0 or i == n - 1):
                continue
            d0 = _n(pts[i] - pts[i - 1])
            d1 = _n(pts[(i + 1) % n] - pts[i])
            c = float(np.dot(_n(d0 + d1), d1))
            hn[i] = hn[i] / max(c, 0.2)
    rings = []
    for p, nr, a, c in zip(pts, nrm, hn, hb):
        rings.append(np.array([p + nr * a + b * c, p - nr * a + b * c, p - nr * a - b * c, p + nr * a - b * c]))
    if closed:
        verts = np.concatenate(rings)
        faces = []
        for i in range(n):
            a, b2 = i * 4, ((i + 1) % n) * 4
            for s in range(4):
                s2 = (s + 1) % 4
                faces.append([a + s, a + s2, b2 + s2, b2 + s])
        return verts, faces
    return fc.loft(rings, close_start=cap, close_end=cap)


def polyline_normals(pts, binormal, closed=False):
    """In-plane normals (binormal x tangent) of a polyline, bisected at the vertices."""
    pts = np.asarray(pts, float)
    n = len(pts)
    b = _n(binormal)
    out = []
    for i in range(n):
        if closed:
            t = _n(_n(pts[i] - pts[i - 1]) + _n(pts[(i + 1) % n] - pts[i]))
        else:
            t = _n(pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])
        out.append(_n(np.cross(b, t)))
    return np.array(out)


def hull(points, dissolve_deg=0.3):
    """Convex hull (bmesh) of cm points -> (verts, faces) with exactly coplanar triangles merged into facets, every
    face wound outward (after build_station_kitchen.hull)."""
    bm = bmesh.new()
    pts = np.unique(np.round(np.asarray(points, float), 4), axis=0)
    for p in pts:
        bm.verts.new(p.tolist())
    res = bmesh.ops.convex_hull(bm, input=bm.verts[:])
    junk = {g for g in res.get("geom_interior", []) + res.get("geom_unused", []) if isinstance(g, bmesh.types.BMVert)}
    junk = [g for g in junk if g.is_valid]
    if junk:
        bmesh.ops.delete(bm, geom=junk, context="VERTS")
    loose = [x for x in bm.verts if not x.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    if dissolve_deg:
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(dissolve_deg), verts=list(bm.verts), edges=list(bm.edges))
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


def ashlar(x0, x1, y0, y1, z0, z1, rng, outer=(), push=(1.5, 3.0), chamfer=(0.6, 1.4), bites=None, inset=2.5,
           mids=None):
    """One dressed masonry block as the convex hull of hand-cut points: footprint [x0, x1] x [y0, y1], bottom z0 flat,
    top z1 (a float or 4 corner heights in the order (x0,y0), (x1,y0), (x1,y1), (x0,y1)), chamfered top edges of random
    width, `bites` {corner index: size cm} cutting a big chip off a top corner, and every face named in `outer`
    ("+x", "-x", "+y", "-y") PILLOWED: its border stays on the face plane, a ring inset by `inset` is pushed out by a
    random amount in `push` (each corner its own, so the face splits into tilted planes) and `mids` extra interior
    points (default 1, 2 on long faces) push out a touch further. Returns (verts, faces)."""
    zt = np.broadcast_to(np.asarray(z1, float), (4,)).copy()
    cs = [(x0, y0, 1.0, 1.0), (x1, y0, -1.0, 1.0), (x1, y1, -1.0, -1.0), (x0, y1, 1.0, -1.0)]
    bites = bites or {}
    pts = []
    chs = rng.uniform(chamfer[0], chamfer[1], 4)
    for i, (cx, cy, ix, iy) in enumerate(cs):
        ch, t = chs[i], zt[i]
        pts.append((cx, cy, z0))
        if i in bites:
            b = bites[i]
            pts += [(cx + ix * b, cy + iy * ch, t), (cx + ix * ch, cy + iy * b, t),
                    (cx, cy + iy * b, t - ch), (cx + ix * b, cy, t - ch), (cx, cy, t - b)]
        else:
            pts += [(cx + ix * ch, cy + iy * ch, t), (cx, cy, t - ch)]
    ztop = float(zt.min() - chs.max())
    for face in outer:
        ax = 0 if face[1] == "x" else 1
        sgn = 1.0 if face[0] == "+" else -1.0
        plane = (x1 if sgn > 0 else x0) if ax == 0 else (y1 if sgn > 0 else y0)
        a0, a1 = (y0, y1) if ax == 0 else (x0, x1)
        h0, h1 = z0 + inset, ztop - inset
        if h1 <= h0 + 0.5 or a1 - a0 <= 2 * inset + 0.5:
            continue
        # the two face corners (in face coords a = along, h = up) and the height of the face's top border at each
        # (the top chamfer, or a corner bite's lowest point), so the inset ring's top edge runs parallel to it
        corner_ids = {("x", -1): (0, 3), ("x", 1): (1, 2), ("y", -1): (0, 1), ("y", 1): (3, 2)}[(face[1], int(sgn))]
        tops = []
        for c in corner_ids:
            tb = zt[c] - chs[c]
            if c in bites:
                tb = min(tb, zt[c] - bites[c])
            tops.append(tb)
        # corner_ids are ordered by increasing `a` (x for y faces, y for x faces)
        # PILLOW, hand-cut as chisel planes: per-EDGE insets keep each border band a planar trapezoid (its inset edge
        # parallel to the border edge), one push for the whole ring, and a single lifted centre vertex makes the
        # middle a 4-triangle fan instead of long crossing diagonals
        e_l, e_r, e_b, e_t = inset * rng.uniform(0.75, 1.35, 4)
        p = rng.uniform(push[0], push[1])
        la, lb = a0 + e_l, a1 - e_r

        def top_h(av):
            return float(np.interp(av, [a0, a1], tops)) - e_t
        ring = [(la, z0 + e_b), (lb, z0 + e_b), (lb, top_h(lb)), (la, top_h(la))]
        if min(ring[2][1], ring[3][1]) <= z0 + e_b + 0.5:
            continue
        for av, h in ring:
            q = [0.0, 0.0, h]
            q[ax] = plane + sgn * p
            q[1 - ax] = av
            pts.append(tuple(q))
        fa = rng.uniform(0.38, 0.62)
        av = la + (lb - la) * fa
        hb, ht = z0 + e_b, top_h(av)
        h = hb + (ht - hb) * rng.uniform(0.4, 0.6)
        q = [0.0, 0.0, h]
        q[ax] = plane + sgn * (p + rng.uniform(0.8, 1.6))
        q[1 - ax] = av
        pts.append(tuple(q))
    return hull(pts)


# ---------------------------------------------------------------- chiselled stone (after build_station_hearth)
def ccw(poly):
    p = np.asarray(poly, float)
    area = 0.5 * np.sum(p[:, 0] * np.roll(p[:, 1], -1) - np.roll(p[:, 0], -1) * p[:, 1])
    return p if area > 0 else p[::-1].copy()


def inset_convex(poly, d):
    """Offset every edge of a convex polygon inward by d; None if an edge flips."""
    p = ccw(poly)
    n = len(p)
    lines = []
    for i in range(n):
        e = _n(p[(i + 1) % n] - p[i])
        lines.append((p[i] + np.array([-e[1], e[0]]) * d, e))
    out = []
    for i in range(n):
        (p1, d1), (p2, d2) = lines[i - 1], lines[i]
        m = np.array([d1, -d2]).T
        if abs(np.linalg.det(m)) < 1e-9:
            out.append(p2)
        else:
            tt = np.linalg.solve(m, p2 - p1)[0]
            out.append(p1 + d1 * tt)
    out = np.array(out)
    for i in range(n):
        if np.dot(out[(i + 1) % n] - out[i], p[(i + 1) % n] - p[i]) <= 0.0:
            return None
    return out


def stone_block(poly, z0, z1, rng, scale=1.0, chip_p=0.6, drop_p=0.4):
    """One chiselled block: a convex prism (CCW footprint poly) with chipped vertical corners, a hand-cut top chamfer
    with dropped chips and a fan-faceted top whose centre sits a touch off the plane. Returns (verts, faces, tags) with
    tags bottom / side / chip / chamfer / top and the index of the footprint edge each side face sits on (-1 else)."""
    p = ccw(poly)
    n0 = len(p)
    pts, pair, edge_of = [], [], []
    for i in range(n0):
        prv, cur, nxt = p[i - 1], p[i], p[(i + 1) % n0]
        l0, l1 = np.linalg.norm(prv - cur), np.linalg.norm(nxt - cur)
        if rng.uniform() < chip_p:
            c = min(rng.uniform(0.7, 2.3) * scale, 0.3 * l0, 0.3 * l1)
            pts.append(cur + (prv - cur) / l0 * c)
            pts.append(cur + (nxt - cur) / l1 * c)
            pair += [i, i]
            edge_of += [-1, i]
        else:
            pts.append(cur)
            pair.append(-1)
            edge_of.append(i)
    pts = np.array(pts)
    n = len(pts)
    centroid = pts.mean(axis=0)
    ch = rng.uniform(0.45, 0.85) * scale
    top = inset_convex(pts, ch)
    if top is None:
        top = centroid + (pts - centroid) * 0.93
    top = top + rng.uniform(-0.1, 0.1, size=top.shape) * scale
    zt = z1 + rng.uniform(-0.12, 0.0, n) * scale
    dropped = rng.uniform(size=n) < drop_p
    zt[dropped] -= rng.uniform(0.35, 1.1, int(dropped.sum())) * scale
    top[dropped] += (centroid - top[dropped]) * 0.05
    mid = pts + rng.uniform(-0.12, 0.12, size=pts.shape) * scale * 0.5
    zm = z1 - ch + rng.uniform(-0.1, 0.1, n) * scale
    verts = np.concatenate([np.column_stack([pts, np.full(n, z0)]), np.column_stack([mid, zm]),
                            np.column_stack([top, zt]),
                            [[centroid[0] + rng.uniform(-2, 2) * scale, centroid[1] + rng.uniform(-2, 2) * scale,
                              z1 - rng.uniform(0.05, 0.4) * scale]]])
    faces, tags, edges = [list(range(n))[::-1]], ["bottom"], [-1]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
        is_chip = pair[i] >= 0 and pair[i] == pair[j]
        tags.append("chip" if is_chip else "side")
        edges.append(-1 if is_chip else edge_of[i])
        faces.append([n + i, n + j, 2 * n + j, 2 * n + i])
        tags.append("chip" if dropped[i] or dropped[j] else "chamfer")
        edges.append(-1 if is_chip else edge_of[i])
        faces.append([2 * n + i, 2 * n + j, 3 * n])
        tags.append("top")
        edges.append(-1)
    return verts, faces, tags, edges


# ================================================================ Parts
class Parts:
    """Accumulates closed shells ("parts") with a slot name, a tag and a part id per face; builds one object whose
    material slots are the used slots in `slot_order`."""

    def __init__(self, name, slot_order):
        self.name = name
        self.slot_order = tuple(slot_order)
        self.v, self.f, self.slot, self.tag, self.part = [], [], [], [], []
        self.base = 0
        self.n = 0
        self.info = {}

    def add(self, vf, slot, tag, part=None):
        verts, faces = np.asarray(vf[0], float), vf[1]
        slots = [slot] * len(faces) if isinstance(slot, str) else list(slot)
        tags = [tag] * len(faces) if isinstance(tag, str) else list(tag)
        assert len(tags) == len(faces) and len(slots) == len(faces), (self.name, len(tags), len(slots), len(faces))
        if part is None:
            part = self.n
            self.n += 1
        self.v.append(verts)
        self.f.extend([[self.base + int(i) for i in face] for face in faces])
        self.slot.extend(slots)
        self.tag.extend(tags)
        self.part.extend([part] * len(faces))
        self.base += len(verts)
        return part

    def verts(self):
        return np.concatenate(self.v)

    def build(self):
        used = [s for s in self.slot_order if s in set(self.slot)]
        extra = sorted(set(self.slot) - set(used))
        if extra:
            raise ValueError("%s: slots %s not in the family order %s" % (self.name, extra, self.slot_order))
        obj = ec.new_object(self.name, self.verts(), self.f, slots=used, face_slots=[used.index(s) for s in self.slot])
        if len(obj.data.polygons) != len(self.f):
            raise RuntimeError("%s: mesh.validate dropped faces (%d -> %d)" % (self.name, len(self.f),
                                                                                len(obj.data.polygons)))
        return obj


def paint_parts(obj, parts, fn, variation=0.06, seed=5, cavity_darken=0.35):
    """fn(tag, part, centre_cm, normal) -> linear rgb, per face; fc.paint writes "Col" (A = cavity)."""
    centres = fc.face_centers_cm(obj)
    normals = fc.face_normals(obj)
    rgb = np.array([fn(t, p, centres[i], normals[i]) for i, (t, p) in enumerate(zip(parts.tag, parts.part))])
    fc.paint(obj, rgb, variation=variation, seed=seed, cavity_darken=cavity_darken)


# ================================================================ checks
def mesh_polys(obj):
    v = fc.verts_cm(obj)
    polys = [list(p.vertices) for p in obj.data.polygons]
    return v, polys


def newell(pts):
    n = np.zeros(3)
    m = len(pts)
    for i in range(m):
        a, b = pts[i], pts[(i + 1) % m]
        n += np.array([(a[1] - b[1]) * (a[2] + b[2]), (a[2] - b[2]) * (a[0] + b[0]), (a[0] - b[0]) * (a[1] + b[1])])
    ln = np.linalg.norm(n)
    return n / ln if ln > 1e-12 else n


def shell_problems(obj, part_ids):
    """Every part must be a closed, consistently wound shell with positive volume (outward normals)."""
    v, polys = mesh_polys(obj)
    by_part = {}
    for fi, p in enumerate(part_ids):
        by_part.setdefault(p, []).append(fi)
    bad = []
    for p, fis in by_part.items():
        directed = {}
        vol = 0.0
        for fi in fis:
            poly = polys[fi]
            for i in range(len(poly)):
                e = (poly[i], poly[(i + 1) % len(poly)])
                directed[e] = directed.get(e, 0) + 1
            p0 = v[poly[0]]
            for i in range(1, len(poly) - 1):
                vol += float(np.dot(p0, np.cross(v[poly[i]], v[poly[i + 1]]))) / 6.0
        open_edges = sum(1 for e, c in directed.items() if c != 1 or directed.get((e[1], e[0]), 0) != 1)
        if open_edges:
            bad.append("part %d: %d open / inconsistent edges" % (p, open_edges))
        elif vol <= 0.0:
            bad.append("part %d: volume %.3f <= 0 (inverted)" % (p, vol))
    return bad


def _bvh(v, polys):
    return BVHTree.FromPolygons([tuple(x) for x in v], polys, all_triangles=False)


def floating_parts(obj, part_ids, tol=0.35):
    """Parts not connected (touching within tol, or a vertex inside) to the biggest part through other parts."""
    v, polys = mesh_polys(obj)
    by_part = {}
    for fi, p in enumerate(part_ids):
        by_part.setdefault(p, []).append(fi)
    keys = sorted(by_part)
    data = {}
    for p in keys:
        vi = sorted({i for fi in by_part[p] for i in polys[fi]})
        remap = {g: k for k, g in enumerate(vi)}
        pv = v[vi]
        pp = [[remap[i] for i in polys[fi]] for fi in by_part[p]]
        data[p] = (pv, _bvh(pv, pp), pv.min(axis=0) - tol, pv.max(axis=0) + tol)

    def touches(a, b):
        va, _, lo_a, hi_a = data[a]
        vb, tb, lo_b, hi_b = data[b]
        if np.any(hi_a < lo_b) or np.any(hi_b < lo_a):
            return False
        for co in va:
            if np.any(co < lo_b) or np.any(co > hi_b):
                continue
            hit = tb.find_nearest(tuple(co))
            if hit[0] is None:
                continue
            loc, nrm, _, dist = hit
            if dist <= tol or np.dot(co - np.array(loc), np.array(nrm)) < 0.0:
                return True
        return False

    root = max(keys, key=lambda p: len(by_part[p]))
    seen = {root}
    todo = [root]
    while todo:
        a = todo.pop()
        for b in keys:
            if b not in seen and (touches(a, b) or touches(b, a)):
                seen.add(b)
                todo.append(b)
    return [p for p in keys if p not in seen]


def _hull2d(pts):
    pts = sorted(set(map(tuple, np.round(pts, 6))))
    if len(pts) <= 2:
        return np.array(pts)

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return np.array(lower[:-1] + upper[:-1])


def _overlap2d(a, b, margin):
    for poly in (a, b):
        m = len(poly)
        for i in range(m):
            e = poly[(i + 1) % m] - poly[i]
            ax = np.array([-e[1], e[0]])
            ln = np.linalg.norm(ax)
            if ln < 1e-9:
                continue
            ax /= ln
            pa, pb = a @ ax, b @ ax
            if pa.max() <= pb.min() + margin or pb.max() <= pa.min() + margin:
                return False
    return True


def coplanar_overlaps(v, polys, island, dist=0.2, cos_tol=0.9995, margin=0.05, max_report=12):
    """Pairs of faces from DIFFERENT islands that lie in one plane (within dist cm) and overlap by more than margin.
    Returns (same_facing, opposite_facing): same-facing pairs z-fight; opposite-facing pairs are back-to-back faces
    hidden inside touching solids (reported, not failed)."""
    rows = []
    buckets = {}
    for fi, poly in enumerate(polys):
        P = v[poly]
        n = newell(P)
        if not np.any(n):
            continue
        d = float(np.dot(n, P.mean(axis=0)))
        rows.append((fi, n, d, P))
        key = (tuple(np.round(n * 4).astype(int)), int(math.floor(d / 2.0)))
        buckets.setdefault(key, []).append(len(rows) - 1)
    same, opp = [], []
    for ri, (fi, n, d, P) in enumerate(rows):
        nk = tuple(np.round(n * 4).astype(int))
        dk = int(math.floor(d / 2.0))
        for sign, key_n, key_d in ((1, nk, dk), (-1, tuple(np.round(-n * 4).astype(int)), int(math.floor(-d / 2.0)))):
            for dd in (-3, -2, -1, 0, 1, 2, 3):
                for rj in buckets.get((key_n, key_d + dd), ()):
                    if rj <= ri and sign == 1:
                        continue
                    if sign == -1 and rj <= ri:
                        continue
                    fj, n2, d2, P2 = rows[rj]
                    if island[fi] == island[fj]:
                        continue
                    if float(np.dot(n, n2)) * sign < cos_tol:
                        continue
                    if abs(d - sign * d2) > dist + 8.0:
                        continue
                    if np.abs(P2 @ n - d).max() > dist or np.abs(P @ n2 - d2).max() > dist:
                        continue
                    e1 = _n(np.cross(n, X if abs(n[0]) < 0.9 else Y))
                    e2 = np.cross(n, e1)
                    a = _hull2d(np.column_stack([P @ e1, P @ e2]))
                    b = _hull2d(np.column_stack([P2 @ e1, P2 @ e2]))
                    if len(a) < 3 or len(b) < 3:
                        continue
                    if _overlap2d(a, b, margin):
                        (same if sign == 1 else opp).append((fi, fj))
    return same, opp


def ring_match(v, loc, R, radius, sides, phase_deg=0.0, tol=2e-3):
    """Max distance from each canonical port-ring point (local x 0, radius r, vertex k at k*360/sides from +Y toward
    +Z) to the nearest mesh vertex, after moving the mesh into the port's frame; and how far the mesh reaches past
    the port plane (local +x)."""
    local = (np.asarray(v, float) - np.asarray(loc, float)) @ np.asarray(R, float)
    a = math.radians(phase_deg) + np.arange(sides) * math.tau / sides
    want = np.column_stack([np.zeros(sides), radius * np.cos(a), radius * np.sin(a)])
    err = max(float(np.linalg.norm(local - w, axis=1).min()) for w in want)
    return err, float(local[:, 0].max())


# ================================================================ renders
def remove_object(o):
    mesh = o.data if o.type == "MESH" else None
    for c in list(o.children):
        remove_object(c)
    bpy.data.objects.remove(o, do_unlink=True)
    if mesh is not None and mesh.users == 0:
        bpy.data.meshes.remove(mesh)


def copy_mesh(obj, R=None, t=None, name=None):
    """An unparented copy of obj's mesh with the vertices moved (R, t in cm) - for assemblies and review sheets."""
    c = bpy.data.objects.new(name or (obj.name + "_Copy"), obj.data.copy())
    bpy.context.scene.collection.objects.link(c)
    fc.set_verts_cm(c, xf(fc.verts_cm(c), R, t))
    return c


def painted_box(name, center, size, rgb, R=None):
    v, f = obox(center, size, R)
    o = fc.new_object(name, v, f, slots=("EnvStone",))
    fc.paint(o, np.repeat(np.asarray(rgb, float)[None, :], len(f), axis=0), variation=0.02, cavity_darken=0.0)
    return o


def review_copy(obj):
    """Unparented copy re-centred so fc.review_sheet's framing (aim at 0.45 x the largest extent) fits any pivot."""
    c = copy_mesh(obj, name=obj.name.replace("_Mars_SM", "") + "_Review")
    v = fc.verts_cm(c)
    lo, hi = v.min(axis=0), v.max(axis=0)
    ext = float((hi - lo).max())
    fc.set_verts_cm(c, v - np.array([(lo[0] + hi[0]) * 0.5, (lo[1] + hi[1]) * 0.5, (lo[2] + hi[2]) * 0.5 - 0.45 * ext]))
    return c


def render_view(objs, path, view, size=(1200, 900), margin=1.08, ortho=True, target_cm=None, half_cm=None, lens=50.0,
                eye_cm=None, shadows=False):
    """One workbench render of objs where they stand (vertex colours + cavity). The frame fits their bounds seen from
    direction `view` unless half_cm (half extent of the longer image side) is given; eye_cm places a perspective camera
    explicitly."""
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
    cam_data = bpy.data.cameras.new("_PipesCam")
    cam_data.clip_start, cam_data.clip_end = 0.02, 2000.0
    cam = bpy.data.objects.new("_PipesCam", cam_data)
    scene.collection.objects.link(cam)
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    sh = scene.display.shading
    prev = (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
            scene.render.filepath, sh.color_type, sh.light, sh.show_cavity, scene.render.film_transparent,
            tuple(scene.world.color), sh.show_shadows, sh.show_specular_highlight)
    saved = [o.hide_render for o in objs]
    try:
        for o in hidden:
            o.hide_render = True
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
    finally:
        for o, hr in zip(objs, saved):
            o.hide_render = hr
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


def sheet(paths, stem, cols):
    return fc.tile_images(paths, os.path.join(spec.REVIEW_DIR, "%s_sheet.png" % stem), cols=cols)
