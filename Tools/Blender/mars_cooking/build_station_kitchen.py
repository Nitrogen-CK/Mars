"""Mars cooking "kitchen" dressing (station_spec.STATIONS["kitchen"]): things that hang from a pot rack, the rack's
wrought iron, and the monster-mouth oven of the crypt kitchen, as a re-runnable headless Blender 5.2 build.

Builds from fixed seeds (the scene is rebuilt from nothing every run):
  A. hanging props - the ORIGIN is the hang point (inside top of the ring / loop that goes over a hook), the mesh hangs
     below it toward -Z centred on x = 0, y = 0, broad sides facing -Y / +Y. No sockets, no collision.
       HangPan_Mars_SM       Copper/Iron   copper skillet (bowl 30 x 5) on an iron strap handle + ring, cooking side -Y
       HangSaucepan_Mars_SM  Copper/Iron   copper saucepan (20 x 11) on a long straight iron handle + ring, opening -Y
       HangLadle_Mars_SM     Iron/Copper   iron ladle, crook at the top, copper bowl (10) at the bottom
       GarlicBraid_Mars_SM   Garlic/Rope   plaited stalks, 10 faceted bulbs alternating left / right / front
       HerbBundle_Mars_SM    Leaf/Rope     bound stems, leaf sprays fanning downward (green + dried brown)
  B. rack iron (Iron only, no sockets, no collision)
       RackBar_Mars_SM       hand-forged bar exactly x -50 .. 50, section ~2.4, origin on its axis
       RackHook_Mars_SM      S-hook in the YZ plane: wraps a bar through the origin (clearance radius 1.6), the lower
                             cradle is exactly (0, 0, -9) (sidecar hook_drop_cm)
       RackBracket_Mars_SM   wall bracket: origin = the bar axis point it holds, wall plane y = +16
  C. FurnaceMaw_Mars_SM      Stone/Iron/Ember/Wood   the monster-mouth oven built into a 40 cm wall (see build_furnace)

Run:
  blender -b --factory-startup --python build_station_kitchen.py -- [--export] [--save] [--sheets] [--only A,B,..]
    --export   FBX + JSON sidecar per prop into station_spec.KITCHEN_EXPORT_DIR (never export/stations), each prop as
               soon as its checks pass, then a re-import check of each
    --sheets   review sheets into station_spec.KITCHEN_REVIEW_DIR (one per prop, the rack line-up, the furnace)
    --save     station_spec.BLEND_DIR/Station_Kitchen.blend
    --only     debug: build only the named props (comma separated, e.g. HangPan,RackHook); the run then ends with
               STATION_KITCHEN_PARTIAL instead of OK
Prints STATION_KITCHEN_OK when every check passed (STATION_KITCHEN_FAIL + the reasons otherwise).

All builder geometry is in CENTIMETRES, Blender axes (Z up). Unreal local = (x, -y, z); sidecars carry Unreal cm.
"""
import json
import math
import os
import sys
import time

import bmesh
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import station_common as sc  # noqa: E402

fc = sc.fc
spec = sc.spec
# this builder writes ONLY into the kitchen folders (module attributes are read at call time by the helpers)
spec.EXPORT_DIR = spec.KITCHEN_EXPORT_DIR
spec.REVIEW_DIR = spec.KITCHEN_REVIEW_DIR
sc.food_spec.EXPORT_DIR = spec.KITCHEN_EXPORT_DIR
sc.food_spec.REVIEW_DIR = spec.KITCHEN_REVIEW_DIR

X = np.array([1.0, 0.0, 0.0])
Y = np.array([0.0, 1.0, 0.0])
Z = np.array([0.0, 0.0, 1.0])

HOOK_DROP = spec.PROPS["RackHook"]["hook_drop_cm"]              # 9: bar axis -> the lower cradle
BAR_CLEAR = spec.PROPS["RackHook"]["bar_clearance_radius_cm"]   # 1.6: nothing of a hook / cradle inside this radius
WALL_Y = spec.PROPS["RackBracket"]["wall_plane_y_cm"]           # 16
RING_IN = 1.5                                                   # hang ring inner radius (the hole a hook goes through)
RING_HN, RING_HB = 0.27, 0.5                                    # ring strap half sizes (radial, along Y)
HANG_NAMES = ("HangPan", "HangSaucepan", "HangLadle", "GarlicBraid", "HerbBundle")
RACK_NAMES = ("RackBar", "RackHook", "RackBracket")
ALL_NAMES = HANG_NAMES + RACK_NAMES + ("FurnaceMaw",)


def P(name):
    return sc.palette(name)


def ue(p):
    p = np.asarray(p, float)
    return [round(float(p[0]), 3), round(float(-p[1]), 3), round(float(p[2]), 3)]


def _n(v):
    v = np.asarray(v, float)
    return v / max(float(np.linalg.norm(v)), 1e-12)


def lerp(a, b, t):
    return np.asarray(a, float) * (1.0 - t) + np.asarray(b, float) * t


# ================================================================ geometry helpers (cm)
def axis_frame(axis):
    a = _n(axis)
    helper = Z if abs(a[2]) < 0.9 else X
    u = _n(np.cross(helper, a))
    w = np.cross(a, u)
    return u, w, a


def place_on_axis(v_local, origin, axis, phase_deg=0.0):
    """Local (x, y, z) with z along axis -> world; phase spins the local XY about the axis first."""
    v = np.asarray(v_local, float)
    a = math.radians(phase_deg)
    r = np.array([[math.cos(a), -math.sin(a), 0.0], [math.sin(a), math.cos(a), 0.0], [0.0, 0.0, 1.0]])
    v = v @ r.T
    u, w, ax = axis_frame(axis)
    return np.asarray(origin, float) + v[:, 0:1] * u + v[:, 1:2] * w + v[:, 2:3] * ax


def rivet(center, normal, rng, r=0.55, h=0.38, segments=5):
    """A faceted dome rivet head; its base sinks into the surface."""
    v, f = fc.lathe([(0.0, h), (0.65 * r, 0.75 * h), (r, 0.05), (0.0, -0.25)], segments)
    return place_on_axis(v, center, normal, rng.uniform(0, 60)), f


def newell(pts):
    n = np.zeros(3)
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        n += np.array([(a[1] - b[1]) * (a[2] + b[2]), (a[2] - b[2]) * (a[0] + b[0]), (a[0] - b[0]) * (a[1] + b[1])])
    ln = np.linalg.norm(n)
    return n / ln if ln > 1e-12 else n


def hull(points, dissolve_deg=0.3):
    """Convex hull (bmesh) of cm points -> (verts, faces) with exactly coplanar triangles merged into facets."""
    bm = bmesh.new()
    for p in np.asarray(points, float):
        bm.verts.new(p.tolist())
    res = bmesh.ops.convex_hull(bm, input=bm.verts[:])
    junk = [g for g in res.get("geom_interior", []) + res.get("geom_unused", []) if isinstance(g, bmesh.types.BMVert)]
    junk = [g for g in junk if g.is_valid]
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


def bezier(p0, p1, p2, p3, n):
    """n + 1 points of a cubic Bezier."""
    p0, p1, p2, p3 = (np.asarray(p, float) for p in (p0, p1, p2, p3))
    t = np.linspace(0.0, 1.0, n + 1)[:, None]
    return ((1 - t) ** 3) * p0 + 3 * ((1 - t) ** 2) * t * p1 + 3 * (1 - t) * (t ** 2) * p2 + (t ** 3) * p3


def arc_pts(center, radius, a0_deg, a1_deg, n, e1, e2):
    """n + 1 points of an arc in the plane (e1, e2) + their outward radial normals."""
    c, e1, e2 = (np.asarray(x, float) for x in (center, e1, e2))
    ang = np.radians(np.linspace(a0_deg, a1_deg, n + 1))
    nrm = np.outer(np.cos(ang), e1) + np.outer(np.sin(ang), e2)
    return c + nrm * radius, nrm


def path_normals(pts, binormal):
    """Normals of a path lying in the plane normal to binormal (to the left of travel seen against the binormal)."""
    pts = np.asarray(pts, float)
    b = _n(binormal)
    out = []
    for i in range(len(pts)):
        t = _n(pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)])
        out.append(_n(np.cross(b, t)))
    return np.array(out)


def strap(pts, normals, binormal, hn, hb, closed=False, cap=True):
    """A rectangular-section bar through pts: half size hn along each point's normal, hb along binormal (scalars or
    one value per point). closed joins the last ring to the first (a hoop)."""
    pts = np.asarray(pts, float)
    n = len(pts)
    hn = np.broadcast_to(np.asarray(hn, float), (n,))
    hb = np.broadcast_to(np.asarray(hb, float), (n,))
    b = _n(binormal)
    rings = []
    for p, nr, a, c in zip(pts, np.asarray(normals, float), hn, hb):
        nr = _n(nr)
        rings.append(np.array([p + nr * a + b * c, p - nr * a + b * c, p - nr * a - b * c, p + nr * a - b * c]))
    if closed:
        rings.append(rings[0])
        return fc.loft(rings, close_start=False, close_end=False)
    return fc.loft(rings, close_start=cap, close_end=cap)


def hang_ring(r_in=RING_IN, hn=RING_HN, hb=RING_HB, segments=12):
    """The forged ring a hook goes through: a hoop in the XZ plane whose INSIDE TOP is exactly the origin."""
    pts, nrm = arc_pts((0.0, 0.0, -r_in), r_in + hn, 90.0, 450.0, segments, X, Z)
    return strap(pts[:-1], nrm[:-1], Y, hn, hb, closed=True)


def rope_loop(r_in, hn, hb, tail_z, rng, segments=12):
    """A twine loop in the XZ plane whose inside top is the origin; both tails run down to (0, 0, tail_z)."""
    pts, nrm = arc_pts((0.0, 0.0, -r_in), r_in + hn, -45.0, 225.0, segments, X, Z)
    lo = np.array([[0.32, 0.0, tail_z]])
    pts = np.concatenate([lo, pts, lo * np.array([-1.0, 1.0, 1.0])])
    nrm = np.concatenate([[X], nrm, [-X]])
    pts[1:-1, 1] += rng.uniform(-0.08, 0.08, len(pts) - 2)
    return strap(pts, nrm, Y, hn, hb)


def y_lathe(profile_rd, segments, origin, rng=None, jitter=0.0, phase_deg=0.0):
    """Revolve an (r, d) profile about +Y (d = depth along +Y from origin); hammer jitter (cm) on every non-pole
    vertex. Face order as fc.lathe: one band per consecutive profile pair, segments faces each."""
    v, f = fc.lathe([(r, d) for r, d in profile_rd], segments)
    if jitter and rng is not None:
        rr = np.hypot(v[:, 0], v[:, 1])
        m = rr > 1e-6
        k = 1.0 + rng.uniform(-jitter, jitter, int(m.sum())) / rr[m]
        v[m, 0] *= k
        v[m, 1] *= k
        v[m, 2] += rng.uniform(-jitter, jitter, int(m.sum())) * 0.6
    return place_on_axis(v, origin, Y, phase_deg), f


def band_tags(band_names, segments):
    out = []
    for name in band_names:
        out += [name] * segments
    return out


class Parts:
    """Accumulates (verts, faces) with a slot index, a tag and a group id per face, then builds one flat object."""

    def __init__(self, slots):
        self.slots = tuple(slots)
        self.v, self.f, self.slot, self.tag, self.group, self.island = [], [], [], [], [], []
        self.base = 0
        self.next_group = 0
        self.n_islands = 0

    def add(self, vf, slot, tag, group=None):
        verts, faces = np.asarray(vf[0], float), vf[1]
        tags = [tag] * len(faces) if isinstance(tag, str) else list(tag)
        assert len(tags) == len(faces), (len(tags), len(faces))
        if group is None:
            group = self.next_group
            self.next_group += 1
        self.v.append(verts)
        self.f.extend([[self.base + int(i) for i in face] for face in faces])
        self.slot.extend([self.slots.index(slot)] * len(faces))
        self.tag.extend(tags)
        self.group.extend([group] * len(faces))
        self.island.extend([self.n_islands] * len(faces))
        self.n_islands += 1
        self.base += len(verts)
        return group

    def build(self, name):
        obj = sc.new_object(name, np.concatenate(self.v), self.f, slots=self.slots, face_slots=self.slot)
        if len(obj.data.polygons) != len(self.f):
            raise RuntimeError("%s: mesh.validate dropped faces (%d -> %d)" % (name, len(self.f), len(obj.data.polygons)))
        return obj


def paint_tags(obj, parts, fn, variation=0.07, seed=5, cavity_darken=0.35):
    """fn(tag, group, face_centre_cm, face_normal) -> linear rgb, per face."""
    centres = fc.face_centers_cm(obj)
    normals = fc.face_normals(obj)
    rgb = [fn(t, g, centres[i], normals[i]) for i, (t, g) in enumerate(zip(parts.tag, parts.group))]
    fc.paint(obj, np.array(rgb), variation=variation, seed=seed, cavity_darken=cavity_darken)


# ================================================================ A. hanging props
def copper_fn(seed):
    """Tag painter shared by the copper pans: hammered copper, a worn bright rim, a sooted underside, dark iron."""
    rng = np.random.default_rng(seed)
    copper, bright, soot, iron = P("Copper"), P("CopperBright"), P("CopperSoot"), P("Iron")

    def fn(tag, group, c, n):
        k = rng.uniform()
        if tag == "floor":
            return lerp(copper * 0.78, bright, 0.25 if k > 0.72 else 0.0) * rng.uniform(0.9, 1.08)
        if tag == "wall_in":
            return lerp(copper, bright, 0.4 if k > 0.7 else 0.08) * rng.uniform(0.92, 1.08)
        if tag == "rim":
            return bright * rng.uniform(0.92, 1.1)
        if tag == "wall_out":
            return lerp(copper * 0.8, soot, 0.5 if k > 0.6 else 0.22)
        if tag == "under":
            return lerp(soot, copper * 0.5, 0.18 if k > 0.75 else 0.0) * rng.uniform(0.8, 1.15)
        if tag == "rivet":
            return iron * 2.6
        if tag == "ring":
            return iron * 1.5
        if tag == "plate":
            return iron * 1.25
        return iron * rng.uniform(1.0, 1.5)          # handle

    return fn


def build_hang_pan():
    rng = np.random.default_rng(7101)
    parts = Parts(("Copper", "Iron"))
    cz = -40.0                                                 # pan centre: the rim top is 25 under the hang point
    prof = [(0.0, 4.5), (5.0, 4.58), (9.4, 4.5), (12.3, 4.2), (13.9, 2.2), (15.0, 0.0), (15.65, 0.12), (14.7, 2.4),
            (13.0, 4.8), (9.4, 5.0), (5.0, 5.06), (0.0, 5.0)]
    bands = ["floor", "floor", "floor", "wall_in", "wall_in", "rim", "wall_out", "wall_out", "under", "under", "under"]
    segs = 16
    v, f = y_lathe(prof, segs, (0.0, -2.5, cz), rng, jitter=0.13, phase_deg=11.25)
    parts.add((v, f), "Copper", band_tags(bands, segs))
    # the iron strap handle, 22 long, from the ring down onto the wall by the rim, and its riveted foot
    pts = np.array([(0.0, 0.0, -3.25), (0.0, -0.15, -7.0), (0.0, -0.75, -15.5), (0.0, -1.45, -22.5), (0.0, -1.8, -25.6)])
    pts[1:4, 0] += rng.uniform(-0.12, 0.12, 3)
    parts.add(strap(pts, [Y] * 5, X, [0.24, 0.22, 0.2, 0.24, 0.3], [0.85, 0.95, 1.15, 1.3, 1.9]), "Iron", "handle")
    foot = sc.box((0.0, -1.2, -25.45), (5.2, 3.2, 0.75))[0] + rng.uniform(-0.1, 0.1, (8, 3))
    parts.add(hull(foot), "Iron", "plate")
    for sx in (-1.7, 1.7):
        parts.add(rivet((sx, -1.9, -24.9), (0.0, -0.8, 0.6), rng, r=0.5, h=0.34), "Iron", "rivet")
    parts.add(hang_ring(), "Iron", "ring")
    obj = parts.build("HangPan_Mars_SM")
    paint_tags(obj, parts, copper_fn(11), seed=3)
    return obj, dict(bowl_inner_diameter_cm=30.0, bowl_depth_cm=4.5, handle_length_cm=22.35, pan_centre_cm=ue((0, 0, cz)),
                     cooking_side="Blender -Y (Unreal +Y)")


def build_hang_saucepan():
    rng = np.random.default_rng(7102)
    parts = Parts(("Copper", "Iron"))
    cz = -37.3                                                 # pan axis height: its lowest wall point is at z = -48
    prof = [(0.0, 10.5), (5.6, 10.55), (9.2, 10.4), (9.85, 9.5), (10.0, 5.2), (10.0, 0.0), (10.7, 0.1), (10.6, 0.8),
            (10.38, 1.0), (10.4, 5.6), (10.42, 9.8), (9.6, 10.95), (5.6, 11.08), (0.0, 11.0)]
    bands = ["floor", "floor", "wall_in", "wall_in", "wall_in", "rim", "rim", "rim", "wall_out", "wall_out", "under",
             "under", "under"]
    segs = 14
    v, f = y_lathe(prof, segs, (0.0, -5.5, cz), rng, jitter=0.11, phase_deg=0.0)
    parts.add((v, f), "Copper", band_tags(bands, segs))
    top = cz + 10.4                                            # the wall's top line
    pts = np.array([(0.0, 0.0, -3.25), (0.0, -0.3, -8.0), (0.0, -1.3, -17.5), (0.0, -2.35, -24.5), (0.0, -2.7, top + 0.05)])
    pts[1:4, 0] += rng.uniform(-0.1, 0.1, 3)
    parts.add(strap(pts, [Y] * 5, X, [0.26, 0.26, 0.28, 0.3, 0.34], [0.8, 0.85, 0.95, 1.05, 1.5]), "Iron", "handle")
    plate = sc.box((0.0, -2.2, top + 0.15), (4.4, 5.4, 0.7))[0] + rng.uniform(-0.1, 0.1, (8, 3))
    parts.add(hull(plate), "Iron", "plate")
    for sx, sy in ((-1.45, -3.9), (1.45, -3.9), (0.0, -0.4)):
        parts.add(rivet((sx, sy, top + 0.5), (0.0, 0.0, 1.0), rng, r=0.5, h=0.34), "Iron", "rivet")
    parts.add(hang_ring(), "Iron", "ring")
    obj = parts.build("HangSaucepan_Mars_SM")
    paint_tags(obj, parts, copper_fn(12), seed=4)
    return obj, dict(inner_diameter_cm=20.0, depth_cm=10.5, pan_axis_cm=ue((0, 0, cz)), opening_side="Blender -Y (Unreal +Y)")


def build_hang_ladle():
    rng = np.random.default_rng(7103)
    parts = Parts(("Iron", "Copper"))
    r_in, hn = 1.3, 0.27
    rc = r_in + hn
    crook, crook_n = arc_pts((0.0, 0.0, -r_in), rc, -45.0, 180.0, 10, X, Z)      # a vertex at 90 deg: inside top = origin
    assert abs(crook[np.argmax(crook[:, 2])][0]) < 1e-9
    bend = bezier(crook[-1], crook[-1] + np.array([0.0, 0.0, -3.0]), (0.0, 0.0, -5.0), (0.0, 0.0, -9.5), 5)[1:]
    shaft = np.array([(0.0, 0.0, -20.0), (0.0, -0.25, -30.0), (0.0, -1.0, -35.5), (0.0, -1.75, -38.6)])
    pts = np.concatenate([crook, bend, shaft])
    nrm = np.concatenate([crook_n, path_normals(np.concatenate([crook[-1:], bend]), Y)[1:], [-X] * len(shaft)])
    for i in range(len(crook), len(pts)):                    # keep one side of the section through the bend
        if np.dot(nrm[i], nrm[i - 1]) < 0:
            nrm[i] = -nrm[i]
    k = len(pts)
    hn_arr = np.concatenate([[0.16], np.full(len(crook) - 1, hn), np.linspace(hn, 0.55, len(bend)), [0.62, 0.66, 0.6, 0.5]])
    hb_arr = np.concatenate([[0.2], np.full(len(crook) - 1, 0.32), np.linspace(0.32, 0.24, len(bend)), [0.22, 0.2, 0.2, 0.2]])
    assert len(hn_arr) == k and len(hb_arr) == k
    pts[len(crook):, 0] += np.concatenate([np.zeros(len(bend)), rng.uniform(-0.1, 0.1, 2), [0.0, 0.0]])
    parts.add(strap(pts, nrm, Y, hn_arr, hb_arr), "Iron", "handle")
    # the copper bowl, opening -Y, its rim top under the shaft end
    cz = -43.0
    prof = [(0.0, 3.55), (2.4, 3.4), (4.0, 2.35), (4.7, 0.0), (5.0, 0.05), (4.4, 2.6), (2.7, 3.95), (0.0, 4.2)]
    bands = ["floor", "wall_in", "wall_in", "rim", "wall_out", "under", "under"]
    v, f = y_lathe(prof, 10, (0.0, -2.1, cz), rng, jitter=0.07, phase_deg=18.0)
    parts.add((v, f), "Copper", band_tags(bands, 10))
    tab = sc.box((0.0, -1.2, cz + 4.75), (1.9, 2.3, 0.5))[0] + rng.uniform(-0.06, 0.06, (8, 3))
    parts.add(hull(tab), "Iron", "plate")
    parts.add(rivet((0.0, -0.9, cz + 5.0), (0.0, 0.0, 1.0), rng, r=0.4, h=0.3), "Iron", "rivet")
    obj = parts.build("HangLadle_Mars_SM")
    paint_tags(obj, parts, copper_fn(13), seed=5)
    return obj, dict(bowl_diameter_cm=10.0, bowl_centre_cm=ue((0, 0, cz)), hook_inner_radius_cm=r_in)


def garlic_bulb(parts, centre, neck_dir, scale, rng, group):
    """One faceted bulb: 4 cloves (8 segments, alternate groove / bulge), a papery neck twisting to a tip, a root
    tuft. Local z runs root -> neck."""
    segs = 8
    prof = [(0.0, -2.5), (1.35, -2.4), (2.8, -1.45), (3.25, 0.0), (2.7, 1.5), (1.35, 2.65), (0.62, 3.6), (0.42, 5.6),
            (0.0, 5.9)]
    v, f = fc.lathe(prof, segs)
    ring_of = np.concatenate([[0], np.repeat(np.arange(1, len(prof) - 1), segs), [len(prof) - 1]])
    seg_of = np.concatenate([[0], np.tile(np.arange(segs), len(prof) - 2), [0]])
    groove = (seg_of % 2 == 0)
    for row, k in ((1, 0.9), (2, 0.78), (3, 0.76), (4, 0.78), (5, 0.86)):
        m = (ring_of == row) & groove
        v[m, 0:2] *= k
    body = (ring_of >= 1) & (ring_of <= 5)
    v[body] *= (1.0 + rng.uniform(-0.05, 0.05, (int(body.sum()), 1)))
    neck = ring_of >= 6
    v[neck, 0:2] += rng.uniform(-0.22, 0.22, (int(neck.sum()), 2))
    v[ring_of >= 7, 0:2] += rng.uniform(-0.5, 0.5, 2)             # the tip leans
    tags = band_tags(["root", "belly_lo", "belly", "belly", "shoulder", "neck", "tip", "tip"], segs)
    parts.add((place_on_axis(v * scale, centre, neck_dir, rng.uniform(0, 360)), f), "Garlic", tags, group)
    # root tuft: a small jagged star under the root
    tv, tf = fc.lathe([(0.0, -0.95), (0.95, -0.05), (0.0, 0.35)], 6)
    tv[1:-1] *= (1.0 + rng.uniform(-0.45, 0.25, (6, 1)))
    root = np.asarray(centre, float) - _n(neck_dir) * 2.5 * scale
    parts.add((place_on_axis(tv * scale, root, neck_dir, rng.uniform(0, 360)), tf), "Garlic", "tuft", group)


def build_garlic_braid():
    rng = np.random.default_rng(7104)
    parts = Parts(("Garlic", "Rope"))
    parts.add(rope_loop(1.4, 0.26, 0.42, -4.6, rng), "Rope", "loop")
    lean = 0.03                                                 # the plait leans back so the bulbs' weight hangs centred

    def spine(z):
        return np.array([0.0, lean * (-z - 5.0) if z < -5.0 else 0.0, z])

    # the knot under the loop
    kv, kf = fc.lathe([(0.0, -3.7), (1.05, -4.0), (1.55, -4.7), (1.25, -5.4), (1.6, -6.0), (1.0, -6.8), (0.0, -7.0)], 7)
    kv[:, 0:2] += rng.uniform(-0.1, 0.1, (len(kv), 2))
    parts.add((kv, kf), "Rope", "knot")
    # three plaited stalks
    z0, z1, n = -5.2, -59.0, 25
    for i in range(3):
        rings = []
        for k in range(n + 1):
            z = z0 + (z1 - z0) * k / n
            t = (z0 - z) / 11.5 * math.tau + i * math.tau / 3.0
            fade = min(1.0, k / 2.0)
            c = spine(z) + np.array([1.05 * math.sin(t) * fade, 0.55 * math.sin(2.0 * t) * fade, 0.0])
            r = 0.9 - 0.3 * k / n
            rings.append(fc.ring(c, r, r, 3, X, Y, phase=t * 0.5 + i))
        v, f = fc.loft(rings)
        parts.add((v, f), "Rope", "stalk")
    # the bulbs: left / right / front, working down
    sides = ((-1.0, 0.25), (1.0, 0.25), (0.0, -1.0))
    n_bulbs = spec.PROPS["GarlicBraid"]["bulbs"]
    for i in range(n_bulbs):
        z = -13.2 - i * 4.95 + rng.uniform(-0.5, 0.5)
        d = np.array([sides[i % 3][0], sides[i % 3][1], 0.0])
        a = math.radians(rng.uniform(-16.0, 16.0))
        d = _n(np.array([d[0] * math.cos(a) - d[1] * math.sin(a), d[0] * math.sin(a) + d[1] * math.cos(a), 0.0]))
        scale = rng.uniform(0.9, 1.06)
        off = (2.75 if i % 3 == 2 else 3.2) * scale
        centre = spine(z) + d * off
        neck = _n(-d * rng.uniform(0.45, 0.65) + Z * rng.uniform(0.75, 0.95))
        garlic_bulb(parts, centre, neck, scale, rng, parts.next_group)
        parts.next_group += 1
    obj = parts.build("GarlicBraid_Mars_SM")
    cream, streak, rope = P("Garlic"), P("GarlicStreak"), P("Rope")
    paper = fc.srgb(204, 178, 132)
    prng = np.random.default_rng(31)
    tone = {g: prng.uniform(0.9, 1.05) for g in set(parts.group)}
    blush = {g: prng.uniform(0.0, 1.0) for g in set(parts.group)}

    def fn(tag, g, c, nrm):
        k = prng.uniform()
        if tag in ("belly", "belly_lo", "shoulder"):
            col = cream * tone[g]
            s = (0.5 if k > 0.72 else 0.1) * (0.4 + 0.9 * blush[g])
            col = lerp(col, streak, min(s, 0.6))
            return col * (0.9 if tag == "belly_lo" else 1.0)
        if tag == "root":
            return lerp(cream, paper, 0.6) * 0.8
        if tag == "tuft":
            return fc.srgb(112, 84, 52) * prng.uniform(0.7, 1.1)
        if tag == "neck":
            return lerp(cream, paper, 0.55) * tone[g]
        if tag == "tip":
            return paper * prng.uniform(0.75, 1.0)
        if tag == "stalk":
            return lerp(rope, paper, 0.35) * prng.uniform(0.7, 1.0)
        return rope * (0.75 if tag == "knot" else 0.9)

    paint_tags(obj, parts, fn, variation=0.05, seed=6, cavity_darken=0.4)
    return obj, dict(bulbs=n_bulbs, bulb_diameter_cm=6.5, plait_lean="the plait leans 3 % toward Blender +Y")


def leaf(base, direction, up, length, width, rng):
    """A faceted folded leaf: 4 outline points + a raised midrib point + an underside point (8 tris, closed)."""
    d = _n(direction)
    s = _n(np.cross(d, up))
    nrm = _n(np.cross(s, d))
    base = np.asarray(base, float)
    curl = rng.uniform(-0.18, 0.1) * length
    tip = base + d * length + nrm * curl
    mid = base + d * length * rng.uniform(0.36, 0.5) + nrm * curl * 0.35
    left = mid + s * width * 0.5 - nrm * 0.16 * width
    right = mid - s * width * 0.5 - nrm * 0.16 * width
    top = mid + nrm * 0.16 * width + d * 0.08 * length
    bottom = mid - nrm * 0.3 * width
    v = np.array([base, left, tip, right, top, bottom])
    f = [[0, 1, 4], [1, 2, 4], [2, 3, 4], [3, 0, 4], [0, 5, 1], [1, 5, 2], [2, 5, 3], [3, 5, 0]]
    return v, f


def build_herb_bundle():
    rng = np.random.default_rng(7105)
    parts = Parts(("Leaf", "Rope"))
    parts.add(rope_loop(1.4, 0.26, 0.42, -4.8, rng), "Rope", "loop")
    # the binding: three turns of twine round the stems
    bv, bf = fc.lathe([(0.0, -5.0), (1.35, -5.2), (1.85, -5.7), (1.5, -6.3), (1.9, -6.9), (1.5, -7.5), (1.85, -8.1),
                       (1.3, -8.6), (0.0, -8.8)], 8)
    bv[:, 0:2] += rng.uniform(-0.09, 0.09, (len(bv), 2))
    bv[:, 2] += 0.22 * np.sin(np.arctan2(bv[:, 1], bv[:, 0]))          # the turns sit a little skew
    parts.add((bv, bf), "Rope", "binding")
    n_stems = 11
    leaves = 0
    for i in range(n_stems):
        phi = (i / (n_stems - 1) - 0.5) * 2.0                              # -1 .. 1 across the fan
        g = parts.next_group
        parts.next_group += 1
        top = np.array([0.55 * phi + rng.uniform(-0.3, 0.3), rng.uniform(-0.55, 0.55), -3.6 - rng.uniform(0.0, 1.2)])
        neck = np.array([0.7 * phi + rng.uniform(-0.2, 0.2), top[1] * 1.1, -8.8])
        end = np.array([6.4 * math.sin(phi * 1.1) + rng.uniform(-0.6, 0.6), rng.uniform(-3.4, 3.4),
                        -34.6 + 5.5 * abs(phi) ** 1.5 + rng.uniform(-1.6, 0.6)])
        ctrl = neck + np.array([0.0, 0.0, (end[2] - neck[2]) * 0.55]) + np.array([end[0] * 0.12, end[1] * 0.12, 0.0])
        t = np.linspace(0.0, 1.0, 5)[:, None]
        curve = ((1 - t) ** 2) * neck + 2 * (1 - t) * t * ctrl + (t ** 2) * end
        path = np.concatenate([[top], curve])
        radii = np.linspace(0.3, 0.14, len(path))
        rings = [fc.ring(p, r, r, 3, X, Y, phase=rng.uniform(0, 2)) for p, r in zip(path, radii)]
        parts.add(fc.loft(rings), "Leaf", "stem", g)
        # leaves along the lower part of the stem, spiralling round it, pointing down and out
        n_leaves = 8
        spin = rng.uniform(0, math.tau)
        for k in range(n_leaves):
            u = 0.2 + 0.8 * k / (n_leaves - 1)
            p = ((1 - u) ** 2) * neck + 2 * (1 - u) * u * ctrl + (u ** 2) * end
            tan = _n(2 * (1 - u) * (ctrl - neck) + 2 * u * (end - ctrl))
            e1, e2, _ = axis_frame(tan)
            a = spin + k * 2.4
            side = e1 * math.cos(a) + e2 * math.sin(a)
            side[1] *= 0.6                                                # keep the spray flatter front to back
            out = np.array([p[0], p[1] * 0.5, 0.0]) * 0.03
            d = _n(tan * rng.uniform(0.75, 1.0) + _n(side) * rng.uniform(0.5, 0.85) + out)
            last = k == n_leaves - 1
            if last:
                d = _n(tan + _n(side) * 0.15)
            length = rng.uniform(4.3, 6.2) * (0.8 + 0.25 * u)
            width = rng.uniform(1.7, 2.5) * (0.85 + 0.2 * u)
            parts.add(leaf(p, d, np.cross(d, side) + Y * 0.3, length, width, rng), "Leaf", "leaf", g)
            leaves += 1
    obj = parts.build("HerbBundle_Mars_SM")
    green, dry, rope = P("Leaf"), P("LeafDry"), P("Rope")
    prng = np.random.default_rng(41)
    stem_dry = {g: (prng.uniform(0.55, 1.0) if prng.uniform() < 0.4 else prng.uniform(0.0, 0.3)) for g in set(parts.group)}

    def fn(tag, g, c, nrm):
        if tag == "leaf":
            k = float(np.clip(stem_dry[g] + prng.uniform(-0.25, 0.25), 0.0, 1.0))
            col = lerp(green, dry, k) * prng.uniform(0.8, 1.2)
            return col * (1.0 if nrm[1] < 0.2 or nrm[2] > 0 else 0.8)
        if tag == "stem":
            return lerp(green * 0.55, dry * 0.6, 0.5 + 0.5 * stem_dry[g])
        return rope * (0.8 if tag == "binding" else 0.9) * prng.uniform(0.85, 1.1)

    paint_tags(obj, parts, fn, variation=0.06, seed=8, cavity_darken=0.3)
    return obj, dict(stems=n_stems, leaves=leaves)


# ================================================================ B. rack iron
def iron_fn(seed, base=1.25):
    rng = np.random.default_rng(seed)
    iron = P("Iron")

    def fn(tag, group, c, n):
        if tag == "rivet":
            return iron * 2.8
        if tag == "plate":
            return iron * rng.uniform(0.95, 1.3)
        k = rng.uniform()
        return iron * base * (1.45 if k > 0.8 else rng.uniform(0.85, 1.15))        # the odd bright hammer flat

    return fn


def build_rack_bar():
    rng = np.random.default_rng(7201)
    parts = Parts(("Iron",))
    h, c = 1.2, 0.8                                           # 2.4 across the flats, corners knocked off (reach 1.44)
    section = np.array([(h, c), (c, h), (-c, h), (-h, c), (-h, -c), (-c, -h), (c, -h), (h, -c)])
    xs = [-50.0, -39.0, -28.5, -16.0, -4.5, 7.5, 19.0, 31.0, 41.5, 50.0]
    rings = []
    for x in xs:
        a = math.radians(rng.uniform(-5.0, 5.0))
        rot = np.array([[math.cos(a), -math.sin(a)], [math.sin(a), math.cos(a)]])
        s = (section * rng.uniform(0.97, 1.03)) @ rot.T + rng.uniform(-0.06, 0.06, section.shape)
        rings.append(np.column_stack([np.full(8, x), s]))
    parts.add(fc.loft(rings), "Iron", "bar")
    obj = parts.build("RackBar_Mars_SM")
    paint_tags(obj, parts, iron_fn(21), variation=0.09, seed=9)
    v = fc.verts_cm(obj)
    reach = float(np.hypot(v[:, 1], v[:, 2]).max())
    return obj, dict(length_cm=100.0, x_range_cm=[-50.0, 50.0], section_cm=2.0 * h, corner_reach_cm=round(reach, 3),
                     scale_axis="X")


def build_rack_hook():
    rng = np.random.default_rng(7202)
    parts = Parts(("Iron",))
    hn = 0.4
    # top hook: wraps the bar (axis X through the origin) from the wall side over the top to the room side
    n_top = 9
    a0, a1 = -30.0, 180.0
    step = math.radians((a1 - a0) / n_top)
    r_in_top = BAR_CLEAR / math.cos(step * 0.5) + 0.03         # the chords between ring vertices stay outside 1.6
    top, top_n = arc_pts((0.0, 0.0, 0.0), r_in_top + hn, a0, a1, n_top, Y, Z)
    # lower hook: its cradle (inside bottom) is exactly (0, 0, -HOOK_DROP)
    r_in_lo = 1.3
    c_lo = np.array([0.0, 0.0, -HOOK_DROP + r_in_lo])
    lo, lo_n = arc_pts(c_lo, r_in_lo + hn, 0.0, -198.0, 11, Y, Z)        # step 18: vertex 5 sits at -90 deg
    assert abs(lo[5][1]) < 1e-9, lo[5]
    shank = bezier(top[-1], top[-1] + np.array([0.0, 0.0, -3.4]), lo[0] + np.array([0.0, 0.0, 3.0]), lo[0], 6)[1:-1]
    pts = np.concatenate([top, shank, lo])
    nrm = np.concatenate([top_n, -path_normals(np.concatenate([top[-1:], shank, lo[:1]]), X)[1:-1], lo_n])
    # the section's radial side flips where the S changes hand: keep the vertex order continuous instead
    cont = [nrm[0]]
    for i in range(1, len(pts)):
        cont.append(nrm[i] if np.dot(nrm[i], cont[-1]) >= 0 else -nrm[i])
    cont = np.array(cont)
    k = len(pts)
    hn_arr = np.full(k, hn)
    hb_arr = np.full(k, 0.46)
    hn_arr[0], hb_arr[0] = 0.2, 0.26                           # drawn-out tips
    hn_arr[-1], hb_arr[-1] = 0.2, 0.26
    # tips keep their INNER face on the arc (thin from the outside)
    pts[0] = pts[0] - top_n[0] * (hn - 0.2)
    pts[-1] = pts[-1] - lo_n[-1] * (hn - 0.2)
    hb_arr[1:-1] += rng.uniform(-0.05, 0.05, k - 2)
    parts.add(strap(pts, cont, X, hn_arr, hb_arr), "Iron", "hook")
    obj = parts.build("RackHook_Mars_SM")
    paint_tags(obj, parts, iron_fn(22, 1.35), variation=0.09, seed=10)
    return obj, dict(hook_drop_cm=HOOK_DROP, cradle_cm=ue((0, 0, -HOOK_DROP)), bar_clearance_radius_cm=BAR_CLEAR,
                     cradle_inner_radius_cm=r_in_lo, wire_cm=[2 * hn, 0.92],
                     frame="hangs on a bar along X through the origin; the S lies in the YZ plane, the lower hook "
                           "opens toward Blender -Y (the room)")


def build_rack_bracket():
    rng = np.random.default_rng(7203)
    parts = Parts(("Iron",))
    pw, ph = spec.PROPS["RackBracket"]["plate_cm"]             # 8 wide x 22 tall
    z_top, z_bot = 5.0, 5.0 - ph
    hx, ch = pw * 0.5, 1.1
    outline = [(-hx + ch, z_top), (hx - ch, z_top), (hx, z_top - ch), (hx, z_bot + ch), (hx - ch, z_bot),
               (-hx + ch, z_bot), (-hx, z_bot + ch), (-hx, z_top - ch)]
    front = WALL_Y - 0.9
    pts = [(x, WALL_Y, z) for x, z in outline]
    pts += [(x * 0.94 + rng.uniform(-0.08, 0.08), front + rng.uniform(-0.08, 0.05), z_bot + (z - z_bot) * 0.985 + 0.1)
            for x, z in outline]
    parts.add(hull(np.array(pts)), "Iron", "plate")
    for sx, sz in ((-2.5, z_top - 2.2), (2.5, z_top - 2.2), (-2.5, z_bot + 2.2), (2.5, z_bot + 2.2)):
        parts.add(rivet((sx, front, sz), (0.0, -1.0, 0.0), rng, r=0.62, h=0.45), "Iron", "rivet")
    # the arm: from the plate out under the bar, then up round its room side (an open cradle)
    hn = 0.45
    n_arc = 7
    a0, a1 = -90.0, -230.0
    step = math.radians(abs(a1 - a0) / n_arc)
    r_in = BAR_CLEAR / math.cos(step * 0.5) + 0.03
    rc = r_in + hn
    arc, arc_n = arc_pts((0.0, 0.0, 0.0), rc, a0, a1, n_arc, Y, Z)
    arm = np.array([(0.0, front + 0.3, -rc), (0.0, 9.5, -rc), (0.0, 4.0, -rc)])
    apts = np.concatenate([arm, arc])
    anrm = np.concatenate([[-Z] * 3, arc_n])
    hn_arr = np.concatenate([[0.62, 0.5, hn], np.full(n_arc + 1, hn)])
    hb_arr = np.concatenate([[1.05, 0.85, 0.8], np.full(n_arc + 1, 0.8)])
    hn_arr[-1], hb_arr[-1] = 0.22, 0.5
    apts[-1] = apts[-1] - arc_n[-1] * (hn - 0.22)
    apts[0, 2] -= 0.17                                          # the thicker root keeps the arm's top face level
    apts[1, 2] -= 0.05
    parts.add(strap(apts, anrm, X, hn_arr, hb_arr), "Iron", "arm")
    # the scroll brace: sweeps from the plate's foot up under the arm and curls back in a scroll
    arm_under = -rc - hn
    cs = np.array([0.0, 5.6, arm_under - 2.05])                # scroll centre
    rho0 = 1.75
    sweep = bezier((0.0, front + 0.2, z_bot + 2.6), (0.0, 9.5, z_bot + 1.2), (0.0, cs[1] - rho0, cs[2] - 6.5),
                   (0.0, cs[1] - rho0, cs[2]), 8)
    turns = np.radians(np.linspace(180.0, 180.0 - 430.0, 13))[1:]
    rho = np.linspace(rho0, 0.62, 13)[1:]
    scroll = cs + np.outer(np.cos(turns) * rho, Y) + np.outer(np.sin(turns) * rho, Z)
    bpts = np.concatenate([sweep, scroll])
    bn = path_normals(bpts, X)
    bhn = np.concatenate([np.linspace(0.42, 0.32, len(sweep)), np.linspace(0.32, 0.16, len(scroll))])
    bhb = np.concatenate([np.linspace(0.7, 0.6, len(sweep)), np.linspace(0.6, 0.45, len(scroll))])
    parts.add(strap(bpts, bn, X, bhn, bhb), "Iron", "brace")
    # a collar binding the scroll to the arm
    collar = sc.box((0.0, cs[1], -rc - 0.5), (2.1, 1.3, 2.0 * hn + 1.2))[0] + rng.uniform(-0.05, 0.05, (8, 3))
    parts.add(hull(collar), "Iron", "plate")
    obj = parts.build("RackBracket_Mars_SM")
    paint_tags(obj, parts, iron_fn(23), variation=0.09, seed=11)
    v = fc.verts_cm(obj)
    return obj, dict(wall_plane_y_cm=WALL_Y, wall_plane_unreal_y_cm=-WALL_Y, plate_cm=[pw, ph],
                     plate_z_range_cm=[z_bot, z_top], bar_clearance_radius_cm=BAR_CLEAR,
                     cradle="open at the top: the bar drops in from above; arm top face at z = %.2f" % (-r_in),
                     reach_room_side_cm=round(float(-v[:, 1].min()), 2))


# ================================================================ C. the furnace
# Frame: origin on the floor at the centre of the mouth, on the wall's ROOM-SIDE face plane (y = 0). The room is toward
# -Y, +Y goes into the 40 cm wall and on into the firebox. Everything 2D below is (x, z) seen from the room (x right,
# z up), polygons counter-clockwise.
FUR = spec.PROPS["FurnaceMaw"]
F_HALF_W = FUR["face_cm"][0] * 0.5            # 400
F_TOP = FUR["face_cm"][1]                     # 750
F_WALL = FUR["wall_thickness_cm"]             # 40: the reveal runs back to here, then the firebox
F_PROUD_MAX = FUR["max_protrusion_cm"]        # 60
F_FEATURE_X = 340.0                           # protruding features stay within |x| <= this
F_PLAIN_X, F_PLAIN_Z, F_FLUSH = 350.0, 720.0, 6.0      # plain strips: nothing beyond y = -6
M_HALF = FUR["mouth_width_cm"] * 0.5          # 210
M_APEX = FUR["mouth_apex_cm"]                 # 430
SILL = FUR["sill_top_cm"]                     # 45
M_SPRING = 140.0                              # short jambs, then the two-centred arch
M_RISE = M_APEX - M_SPRING
M_R = (M_RISE ** 2 + M_HALF ** 2) / (2.0 * M_HALF)     # 305.2: arc radius
M_CX = M_R - M_HALF                                    # 95.2: each arc's centre sits this far past the middle
M_APEX_DEG = math.degrees(math.atan2(M_RISE, M_CX))    # 71.8
LIP_BREAKS = (0.0, 11.5, 23.0, 34.5, 46.0, 58.0)       # voussoir joints (deg on each arc); 58 -> apex is the snout
KERB_FRONT = -44.5
COURSE_H = 50.0
FB = FUR["firebox_cm"]
FB_BACK = FB["back_y"]                        # 320
EYE_C = (175.0, 545.0)
EYE_TILT = 17.0                               # deg: outer corners up (angry)
EYE_DEPTH = 30.0                              # socket back plane y (the face blocks stand ~5 proud: ~35 recessed)
NOSTRIL_C = (35.0, 470.0)
UPPER_TEETH = ((28.0, 75.0), (78.0, 62.0), (125.0, 52.0), (168.0, 45.0))     # |x| on the soffit, length (x 2 sides)
LOWER_TEETH = ((-166.0, 40.0), (-112.0, 52.0), (-56.0, 43.0), (0.0, 36.0), (55.0, 45.0), (111.0, 55.0), (167.0, 38.0))
SOOT_SRGB = (15, 13, 13)
TOOTH_SRGB = (172, 160, 140)


def _n2(v):
    v = np.asarray(v, float)
    return v / max(float(np.hypot(v[0], v[1])), 1e-12)


def area2(p):
    p = np.asarray(p, float)
    return 0.5 * float(np.sum(p[:, 0] * np.roll(p[:, 1], -1) - np.roll(p[:, 0], -1) * p[:, 1]))


def ccw2(p):
    p = np.asarray(p, float)
    return p if area2(p) > 0 else p[::-1].copy()


def rot2(p, deg):
    a = math.radians(deg)
    r = np.array([[math.cos(a), -math.sin(a)], [math.sin(a), math.cos(a)]])
    return np.asarray(p, float) @ r.T


def inset_edges(p, d):
    """Offset each edge i (p[i] -> p[i + 1]) of a CCW polygon inward by d[i]; returns the new vertices."""
    p = np.asarray(p, float)
    n = len(p)
    d = np.broadcast_to(np.asarray(d, float), (n,))
    lines = []
    for i in range(n):
        e = _n2(p[(i + 1) % n] - p[i])
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


def clip_half(poly, a, b, keep_left, new_tag):
    """Sutherland-Hodgman against the line a -> b. poly = [(point, tag of the edge leaving it)]; the edge the clip
    creates gets new_tag."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    e = b - a

    def side(q):
        s = e[0] * (q[1] - a[1]) - e[1] * (q[0] - a[0])
        return s if keep_left else -s

    out = []
    n = len(poly)
    for i in range(n):
        cur, tag = poly[i]
        nxt = poly[(i + 1) % n][0]
        sc_, sn = side(cur), side(nxt)
        cin, nin = sc_ >= -1e-9, sn >= -1e-9
        if cin:
            out.append((cur, tag))
        if cin != nin:
            t = sc_ / (sc_ - sn)
            hit = cur + (nxt - cur) * t
            out.append((hit, new_tag if cin else tag))
    clean = []
    for i in range(len(out)):                       # drop zero-length edges (keep the tag of the real one)
        if np.linalg.norm(out[i][0] - out[(i + 1) % len(out)][0]) > 1e-6:
            clean.append(out[i])
    return clean


def tagged_area(poly):
    return area2(np.array([q for q, _ in poly])) if len(poly) >= 3 else 0.0


def subtract_convex(poly, hole, hole_tag):
    """poly minus a convex CCW hole, as disjoint CONVEX pieces (coplanar seams are tagged "seam")."""
    hole = ccw2(hole)
    pieces, rem = [], poly
    for i in range(len(hole)):
        a, b = hole[i], hole[(i + 1) % len(hole)]
        outside = clip_half(rem, a, b, False, hole_tag)
        if tagged_area(outside) > 4.0:
            pieces.append(outside)
        rem = clip_half(rem, a, b, True, "seam")
        if tagged_area(rem) < 1e-6:
            break
    return pieces


def subtract_all(poly_pts, holes):
    """[(pts, tags)] pieces of a CCW polygon minus every (hole, tag)."""
    pieces = [[(np.asarray(q, float), "outer") for q in ccw2(poly_pts)]]
    for hole, tag in holes:
        hole = ccw2(hole)
        nxt = []
        for pc in pieces:
            inter = pc
            for i in range(len(hole)):
                inter = clip_half(inter, hole[i], hole[(i + 1) % len(hole)], True, "seam")
                if len(inter) < 3:
                    break
            if tagged_area(inter) < 1e-6:
                nxt.append(pc)                      # this hole misses the piece: leave it whole
            else:
                nxt += subtract_convex(pc, hole, tag)
        pieces = nxt
    return [(np.array([q for q, _ in pc]), [t for _, t in pc]) for pc in pieces]


def point_in_poly(q, poly):
    x, z = q
    inside = False
    n = len(poly)
    for i in range(n):
        x0, z0 = poly[i]
        x1, z1 = poly[(i + 1) % n]
        if (z0 > z) != (z1 > z) and x < x0 + (z - z0) * (x1 - x0) / (z1 - z0):
            inside = not inside
    return inside


def arch_pt(a_deg, r=None, side=1.0):
    r = M_R if r is None else r
    a = math.radians(a_deg)
    return np.array([side * (-M_CX + r * math.cos(a)), M_SPRING + r * math.sin(a)])


def arch_z(x):
    """Height of the mouth's edge over x (the sill line outside the jambs)."""
    ax = abs(x)
    if ax >= M_HALF:
        return M_SPRING
    return M_SPRING + math.sqrt(max(M_R ** 2 - (ax + M_CX) ** 2, 0.0))


def mouth_outline(extra=0.0, floor=SILL):
    """The opening, CCW: sill line, right jamb, the right arc's voussoir joints, apex, left side."""
    r = M_R + extra
    apex = (0.0, M_SPRING + math.sqrt(r ** 2 - M_CX ** 2))
    pts = [(-M_HALF - extra, floor), (M_HALF + extra, floor)]
    pts += [tuple(arch_pt(a, r)) for a in LIP_BREAKS]
    pts.append(apex)
    pts += [tuple(arch_pt(a, r, -1.0)) for a in reversed(LIP_BREAKS)]
    return np.array(pts)


def eye_outline(side):
    """Slanted almond socket (about 92 x 44), sharper at the inner corner; side +1 = the eye at +x."""
    loc = np.array([(-48.0, -4.0), (-24.0, -19.0), (6.0, -22.0), (30.0, -13.0), (44.0, 3.0), (26.0, 17.0), (-2.0, 22.0),
                    (-28.0, 13.0)])
    p = rot2(loc, EYE_TILT) + np.array(EYE_C)
    if side < 0:
        p = (p * np.array([-1.0, 1.0]))[::-1]
    return p


def eye_frame(side, uv):
    """Eye-local (u along the eye toward the outer corner, v up) -> (x, z)."""
    p = rot2(np.asarray(uv, float), EYE_TILT) + np.array(EYE_C)
    return p * np.array([side, 1.0])


def nostril_outline(side):
    loc = np.array([(0.0, -18.0), (6.5, -8.0), (7.5, 6.0), (2.0, 18.0), (-5.5, 9.0), (-7.5, -6.0)]) * 1.25
    p = rot2(loc, 24.0) + np.array(NOSTRIL_C)
    if side < 0:
        p = (p * np.array([-1.0, 1.0]))[::-1]
    return p


def to3(p2, y):
    p2 = np.asarray(p2, float)
    y = np.broadcast_to(np.asarray(y, float), (len(p2),))
    return np.column_stack([p2[:, 0], y, p2[:, 1]])


def prism_block(parts, poly, y_front, rng, kind="wall", edge_tags=None, plain=False, ch=None, tilt=(0.0, 0.0),
                origin=None, y_back=1.0, chip_p=0.5, chip_cm=(3.0, 8.0), bump=0.5, group=None, slot="Stone"):
    """One chiselled block standing proud of the wall toward -Y: a convex (x, z) outline, chipped corners, a hand-cut
    chamfer with dropped chips and a fan-faceted face. Edge tags: outer (chamfer + side), hole (side only: the wall
    of a socket cut through the block), seam / hidden (no faces). plain = a coplanar piece of a block that was cut by
    a hole (no chips, no jitter, so the pieces of one block stay flush)."""
    p = ccw2(poly)
    n0 = len(p)
    tags0 = list(edge_tags) if edge_tags is not None else ["outer"] * n0
    if area2(np.asarray(poly, float)) < 0 and edge_tags is not None:
        raise ValueError("prism_block: tagged polygons must come in CCW")
    ch = rng.uniform(1.3, 2.4) if ch is None else ch
    pts, etag = [], []
    for i in range(n0):
        prv, cur, nxt = p[i - 1], p[i], p[(i + 1) % n0]
        l0, l1 = np.linalg.norm(prv - cur), np.linalg.norm(nxt - cur)
        if (not plain) and tags0[i - 1] == "outer" and tags0[i] == "outer" and rng.uniform() < chip_p:
            c = min(rng.uniform(*chip_cm), 0.3 * l0, 0.3 * l1)
            pts.append(cur + (prv - cur) / l0 * c)
            etag.append("chip")
            pts.append(cur + (nxt - cur) / l1 * c)
            etag.append(tags0[i])
        else:
            pts.append(cur)
            etag.append(tags0[i])
    pts = np.array(pts)
    n = len(pts)
    cen = pts.mean(axis=0)
    org = cen if origin is None else np.asarray(origin, float)
    d = [ch if t in ("outer", "chip") else 0.0 for t in etag]
    top = inset_edges(pts, d)
    if area2(top) <= 0.05 * area2(pts) or any(np.dot(top[(i + 1) % n] - top[i], pts[(i + 1) % n] - pts[i]) < 0
                                               for i in range(n)):
        top = cen + (pts - cen) * 0.8                # the chamfer swallowed a sliver: just shrink it

    def plane(q):
        return y_front + tilt[0] * (q[0] - org[0]) + tilt[1] * (q[1] - org[1])

    y_top = np.array([plane(q) for q in top])
    y_cen = plane(cen)
    if not plain:
        top = top + rng.uniform(-0.25, 0.25, top.shape) * (np.array(d)[:, None] > 0)
        y_top = y_top + rng.uniform(-0.2, 0.25, n)
        for i in range(n):
            if (etag[i - 1] == "chip" or etag[i] == "chip") and rng.uniform() < 0.45:
                y_top[i] += rng.uniform(0.5, 1.4) * ch
                top[i] += (cen - top[i]) * 0.06
        cen = cen + rng.uniform(-0.12, 0.12, 2) * np.ptp(pts, axis=0)
        y_cen = y_cen - rng.uniform(0.1, 1.0) * bump
    y_mid = np.minimum(y_top + 0.9 * ch, y_back - 0.2)
    verts = np.concatenate([to3(pts, y_back), to3(pts, y_mid), to3(top, y_top), [[cen[0], y_cen, cen[1]]]])
    faces, tags = [], []
    for i in range(n):
        j = (i + 1) % n
        t = etag[i]
        if t not in ("seam", "hidden"):
            sub = {"chip": "chipface", "hole": "holewall"}.get(t)
            faces.append([i, j, n + j, n + i])
            tags.append("%s/%s" % (kind, sub or "side"))
            faces.append([n + i, n + j, 2 * n + j, 2 * n + i])
            tags.append("%s/%s" % (kind, sub or "chamfer"))
        faces.append([2 * n + i, 2 * n + j, 3 * n])
        tags.append("%s/%s" % (kind, "face_plain" if plain else "face"))
    return parts.add((verts, faces), slot, tags, group)


def cut_block(parts, poly, y_front, rng, holes, kind, tilt=(0.0, 0.0), ch=None, **kw):
    """A block with convex holes cut through it: flush convex pieces that share one face plane, chamfer and group."""
    poly = ccw2(poly)
    g = parts.next_group
    parts.next_group += 1
    pieces = subtract_all(poly, holes)
    whole = len(pieces) == 1 and len(pieces[0][0]) == len(poly) and all(t == "outer" for t in pieces[0][1])
    if whole:
        prism_block(parts, poly, y_front, rng, kind=kind, tilt=tilt, ch=ch, group=g, **kw)
        return g, 1
    ch = rng.uniform(1.3, 2.4) if ch is None else ch
    org = poly.mean(axis=0)
    for pp, tt in pieces:
        prism_block(parts, pp, y_front, rng, kind=kind, edge_tags=tt, plain=True, ch=ch, tilt=tilt, origin=org, group=g,
                    **{k: v for k, v in kw.items() if k in ("y_back", "slot")})
    return g, len(pieces)


def fang(parts, root, axis, length, width, thick, y_c, rng, embed=12.0):
    """A big faceted triangular stone tooth: hexagonal section tapering from the gum to a chipped tip. root / axis are
    (x, z); the tooth is thick along Y round y_c."""
    a = _n2(axis)
    wdir = np.array([a[1], -a[0]])
    unit = np.array([(0.5, 0.0), (0.27, 0.5), (-0.27, 0.5), (-0.5, 0.0), (-0.27, -0.5), (0.27, -0.5)])
    bend = rng.uniform(-0.09, 0.09) * length
    y_tip = rng.uniform(-3.0, 3.0)
    cut = rng.uniform(-0.35, 0.35)                    # the chipped tip is cut on a slant
    rings = []
    for s, k in ((-embed, 1.0), (0.0, 1.0), (0.25 * length, 0.83), (0.53 * length, 0.56), (0.8 * length, 0.29),
                 (length, 0.085)):
        f = max(s, 0.0) / length
        c2 = np.asarray(root, float) + a * s + wdir * bend * f * f
        cy = y_c + y_tip * f
        kt = k ** 0.8
        ring = []
        for u, v in unit:
            jit = rng.uniform(-0.035, 0.035, 2) if 0.0 < s < length else np.zeros(2)
            along = cut * u * width * 0.5 if s >= length else 0.0
            q = c2 + wdir * (u + jit[0]) * width * k + a * along
            ring.append((q[0], cy + (v + jit[1]) * thick * kt, q[1]))
        rings.append(np.array(ring))
    v, f = fc.loft(rings)
    tags = ["tooth_root"] * 6 + ["tooth"] * 18 + ["tooth_tip"] * 6 + ["tooth_root", "tooth_tip"]
    return parts.add((v, f), "Stone", tags)


def chamber_ring(y, w, spring, crown, rng, rough):
    """One cross-section of the firebox (15 points, CCW seen from the room): floor, right wall, vault, left wall."""
    pts = [(-w, SILL), (-w / 3.0, SILL), (w / 3.0, SILL), (w, SILL), (w, SILL + (spring - SILL) * 0.5), (w, spring)]
    for k in range(1, 8):
        t = math.pi * k / 8.0
        pts.append((w * math.cos(t), spring + (crown - spring) * math.sin(t)))
    pts += [(-w, spring), (-w, SILL + (spring - SILL) * 0.5)]
    pts = np.array(pts)
    if rough:
        j = rng.uniform(-rough, rough, pts.shape)
        j[:4, 1] = 0.0                                # the floor stays level
        j[:4, 0] *= 0.3
        pts = pts + j
    return to3(pts, y)


CHAMBER_EDGE_TAGS = ["fb_floor"] * 3 + ["fb_wall"] * 2 + ["fb_vault"] * 8 + ["fb_wall"] * 2
CHAMBER_STATIONS = ((F_WALL, 220.0, 232.0, 448.0), (72.0, 209.0, 226.0, 418.0), (112.0, 203.0, 222.0, 404.0),
                    (165.0, 201.0, 220.0, 401.0), (218.0, 200.0, 220.0, 398.0), (270.0, 199.0, 218.0, 394.0),
                    (FB_BACK, 197.0, 214.0, 388.0))      # y, half width, vault spring z, crown z


def lump(center, size, rng, coarse=True, jitter=0.22):
    """A faceted coal: a lopsided octahedron (8 tris) or a jittered icosphere (20 tris)."""
    if coarse:
        v = np.array([[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]], float)
        f = [[0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4], [2, 0, 5], [1, 2, 5], [3, 1, 5], [0, 3, 5]]
        v = v + rng.uniform(-0.28, 0.28, v.shape)
    else:
        v, f = fc.icosphere(1.0, 1)
    v = v * (1.0 + rng.uniform(-jitter, jitter, (len(v), 1)))
    v = v * (np.asarray(size, float) * 0.5)
    a = rng.uniform(0, math.tau)
    r = np.array([[math.cos(a), -math.sin(a), 0.0], [math.sin(a), math.cos(a), 0.0], [0.0, 0.0, 1.0]])
    return v @ r.T + np.asarray(center, float), f


EMBER_C = (0.0, 150.0)                            # the heap's centre on the firebox floor (under SOCKET_Fire)
EMBER_HALF = (150.0, 100.0)                       # 300 x 200
EMBER_H = 25.0


def mound_h(x, y):
    u = (x - EMBER_C[0]) / EMBER_HALF[0]
    v = (y - EMBER_C[1]) / EMBER_HALF[1]
    return EMBER_H * 0.8 * max(0.0, 1.0 - u * u) * max(0.0, 1.0 - v * v)


def ember_heap(parts, rng):
    nx, ny = 10, 8
    verts = []
    for j in range(ny + 1):
        for i in range(nx + 1):
            x = EMBER_C[0] + EMBER_HALF[0] * (2.0 * i / nx - 1.0)
            y = EMBER_C[1] + EMBER_HALF[1] * (2.0 * j / ny - 1.0)
            edge = i in (0, nx) or j in (0, ny)
            if not edge:
                x += rng.uniform(-6.0, 6.0)
                y += rng.uniform(-6.0, 6.0)
            z = SILL - 1.5 if edge else SILL + mound_h(x, y) * rng.uniform(0.65, 1.0) + rng.uniform(0.0, 2.0)
            verts.append((x, y, z))
    faces = []
    for j in range(ny):
        for i in range(nx):
            a = j * (nx + 1) + i
            b, c, d = a + 1, a + nx + 2, a + nx + 1
            faces += [[a, b, c], [a, c, d]] if (i + j) % 2 else [[a, b, d], [b, c, d]]
    parts.add((np.array(verts), faces), "Ember", "mound")
    coals = clinkers = 0
    tries = 0
    placed = []
    while coals < 170 and tries < 40000:
        tries += 1
        u, v = rng.uniform(-1, 1), rng.uniform(-1, 1)
        if u * u + v * v > 1.0:
            continue
        x, y = EMBER_C[0] + u * (EMBER_HALF[0] - 12.0), EMBER_C[1] + v * (EMBER_HALF[1] - 10.0)
        sx = rng.uniform(13.0, 27.0)
        if any(math.hypot(x - q[0], y - q[1]) < 0.3 * (sx + q[2]) for q in placed):
            continue
        size = np.array([sx, sx * rng.uniform(0.7, 1.0), rng.uniform(7.0, 12.5)])
        placed.append((x, y, sx))
        z = SILL + mound_h(x, y) * 0.8 + size[2] * 0.14
        lv, lf = lump((x, y, z), size, rng, coarse=coals % 4 != 0)
        lv[:, 2] = np.minimum(lv[:, 2], SILL + EMBER_H)
        parts.add((lv, lf), "Ember", "coal")
        coals += 1
    while clinkers < 9:
        u, v = rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8)
        x, y = EMBER_C[0] + u * EMBER_HALF[0], EMBER_C[1] + v * EMBER_HALF[1]
        size = np.array([rng.uniform(10, 17), rng.uniform(8, 13), rng.uniform(5, 8)])
        lv, lf = lump((x, y, SILL + mound_h(x, y) * 0.85 + size[2] * 0.3), size, rng)
        lv[:, 2] = np.minimum(lv[:, 2], SILL + EMBER_H)
        parts.add((lv, lf), "Iron", "clinker")
        clinkers += 1
    return coals, clinkers


def charred_log(parts, p0, p1, r, rng):
    """A split, burnt log: a 6-sided jittered trunk in triangles so single facets can glow as cracks."""
    p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
    u, w, _ = axis_frame(p1 - p0)
    n_st, k = 6, 6
    verts = []
    for i in range(n_st):
        t = i / (n_st - 1)
        c = p0 + (p1 - p0) * t + u * rng.uniform(-1.5, 1.5) + w * rng.uniform(-1.5, 1.5)
        ang = np.arange(k) * math.tau / k + rng.uniform(-0.2, 0.2)
        rr = r * rng.uniform(0.86, 1.1) * (1.0 + rng.uniform(-0.12, 0.12, k))
        verts += list(c + np.outer(np.cos(ang) * rr, u) + np.outer(np.sin(ang) * rr, w))
    faces, tags = [], []
    for i in range(n_st - 1):
        for s in range(k):
            s2 = (s + 1) % k
            a, b, c2, d = i * k + s, i * k + s2, (i + 1) * k + s2, (i + 1) * k + s
            tri = [[a, b, c2], [a, c2, d]] if rng.uniform() < 0.5 else [[a, b, d], [b, c2, d]]
            glow = rng.uniform() < 0.24
            which = int(rng.uniform() < 0.5)
            for m, f in enumerate(tri):
                faces.append(f)
                tags.append("crack" if glow and m == which else "char")
    for ring_i, end in ((0, p0), (n_st - 1, p1)):
        ci = len(verts)
        verts.append(end + (p0 - p1) / np.linalg.norm(p1 - p0) * (1.5 if ring_i == 0 else -1.5))
        for s in range(k):
            faces.append([ring_i * k + s, ring_i * k + (s + 1) % k, ci])
            tags.append("log_end")
    return parts.add((np.array(verts), faces), "Wood", tags)


def fire_dog(parts, x, rng):
    """A wrought-iron andiron: a bar running back into the fire, an arched pair of feet and a scrolled upright at the
    front, a stub leg at the back."""
    y0, y1, zb = 64.0, 242.0, SILL + 24.0
    parts.add(strap([(x, y0 - 2.0, zb), (x, 150.0, zb - 0.8), (x, y1, zb)], [Z] * 3, X, 2.1, 2.1), "Iron", "dog")
    up = np.array([(x, y0, SILL + 16.0), (x, y0, zb + 24.0), (x, y0, SILL + 98.0)])
    curl, _ = arc_pts((x, y0 - 10.0, SILL + 98.0), 10.0, 0.0, 250.0, 9, Y, Z)
    pts = np.concatenate([up, curl[1:]])
    hn = np.concatenate([[2.4, 2.1, 2.0], np.linspace(2.0, 1.0, len(curl) - 1)])
    parts.add(strap(pts, path_normals(pts, X), X, hn, hn * 1.05), "Iron", "dog")
    feet = np.array([(x - 20.0, y0, SILL - 0.5), (x - 15.0, y0, SILL + 13.0), (x - 6.0, y0, SILL + 19.5),
                     (x + 6.0, y0, SILL + 19.5), (x + 15.0, y0, SILL + 13.0), (x + 20.0, y0, SILL - 0.5)])
    parts.add(strap(feet, path_normals(feet, Y), Y, 2.0, 2.1), "Iron", "dog")
    parts.add(strap([(x, y1 - 2.0, SILL - 0.5), (x, y1 - 2.0, zb)], [Y] * 2, X, 2.0, 2.0), "Iron", "dog")
    kv, kf = fc.icosphere(4.4, 1)
    kv = kv * (1.0 + rng.uniform(-0.12, 0.12, (len(kv), 1))) + np.array([x, y0, SILL + 56.0])
    parts.add((kv, kf), "Iron", "dog_knob")
    return zb + 2.1


def wall_courses(rng):
    """Coursed blocks: [(x0, x1, z0, z1)], courses 50 high, blocks 80..120 wide, staggered joints."""
    cells = []
    n_courses = int(round(F_TOP / COURSE_H))
    for c in range(n_courses):
        z0, z1 = c * COURSE_H, (c + 1) * COURSE_H
        x = -F_HALF_W
        first = True
        while x < F_HALF_W - 1e-6:
            rem = F_HALF_W - x
            if first and c % 2:
                w = rng.uniform(42.0, 62.0)                 # half-block start staggers the joints
            elif rem <= 125.0:
                w = rem
            elif rem < 165.0:
                w = rem * rng.uniform(0.45, 0.55)
            else:
                w = rng.uniform(80.0, 120.0)
            first = False
            cells.append((x, x + w, z0, z1))
            x += w
    return cells


def build_furnace():
    rng = np.random.default_rng(7301)
    parts = Parts(("Stone", "Iron", "Ember", "Wood"))
    info = dict(block_centre={}, soot_exempt=set())
    opening = mouth_outline()                       # the true opening (backing + reveal + lips follow it)
    eyes = {s: eye_outline(s) for s in (1.0, -1.0)}
    nostrils = {s: nostril_outline(s) for s in (1.0, -1.0)}
    block_holes = [(mouth_outline(12.0, -1.0), "hidden"), (eyes[1.0], "hole"), (eyes[-1.0], "hole")]
    back_holes = [(opening, "hole"), (eyes[1.0], "hole"), (eyes[-1.0], "hole")]

    # ---- 1. the coursed wall face: a mortar backing on the wall plane + one chiselled block per cell
    cells = wall_courses(rng)
    mortar_v, mortar_f = [], []
    n_blocks = 0
    for x0, x1, z0, z1 in cells:
        rect = np.array([(x0, z0), (x1, z0), (x1, z1), (x0, z1)])
        for pp, _ in subtract_all(rect, back_holes):
            base = len(mortar_v)
            mortar_v += list(to3(pp, 0.0))
            mortar_f.append(list(range(base, base + len(pp))))
        j = 0.6
        inner = np.array([(x0 + (j if x0 > -F_HALF_W else 0.0), z0 + (j if z0 > 0.0 else 0.0)),
                          (x1 - (j if x1 < F_HALF_W else 0.0), z0 + (j if z0 > 0.0 else 0.0)),
                          (x1 - (j if x1 < F_HALF_W else 0.0), z1 - (j if z1 < F_TOP else 0.0)),
                          (x0 + (j if x0 > -F_HALF_W else 0.0), z1 - (j if z1 < F_TOP else 0.0))])
        tilt = (rng.uniform(-0.006, 0.006), rng.uniform(-0.012, 0.012))
        g, n_pieces = cut_block(parts, inner, rng.uniform(-4.6, -2.3), rng, block_holes, "wall", tilt=tilt,
                                chip_p=0.5, chip_cm=(3.0, 9.0), bump=0.5)
        info["block_centre"][g] = inner.mean(axis=0)
        n_blocks += 1 if n_pieces else 0
    parts.add((np.array(mortar_v), mortar_f), "Stone", "mortar")

    # ---- 2. the lower jaw: the sill kerb (top exactly z = SILL, front about y = -45) and the jamb lips on its ends
    kerb_x = [-266.0, -194.0, -84.0, 28.0, 139.0, 266.0]      # joints fall between the lower teeth
    for a, b in zip(kerb_x[:-1], kerb_x[1:]):
        poly = np.array([(a + 0.5, 0.0), (b - 0.5, 0.0), (b - 0.5, SILL), (a + 0.5, SILL)])
        prism_block(parts, poly, KERB_FRONT + rng.uniform(0.0, 2.5), rng, kind="kerb", ch=rng.uniform(2.2, 3.4),
                    chip_p=0.45, chip_cm=(4.0, 9.0), bump=0.5, tilt=(0.0, rng.uniform(-0.02, 0.03)))
    for side in (1.0, -1.0):
        for z0, z1 in ((SILL, 93.0), (93.0, M_SPRING)):
            wdt = rng.uniform(48.0, 60.0)
            poly = np.array([(M_HALF, z0 + 0.5), (M_HALF + wdt, z0 + 0.5), (M_HALF + wdt + rng.uniform(-3, 3), z1 - 0.5),
                             (M_HALF, z1 - 0.5)]) * np.array([side, 1.0])
            prism_block(parts, poly, rng.uniform(-44.0, -38.0), rng, kind="lip", ch=rng.uniform(2.4, 3.4),
                        chip_p=0.5, chip_cm=(5.0, 12.0), bump=0.8)
        # ---- 3. the voussoir lips round the arch, 30..50 proud, ragged outer ends
        for a0, a1 in zip(LIP_BREAKS[:-1], LIP_BREAKS[1:]):
            t = rng.uniform(47.0, 62.0)
            # CCW either side: [inner, outer, outer, inner] = radial joint, outer end, radial joint, soffit
            poly = np.array([arch_pt(a0, M_R, side), arch_pt(a0, M_R + t, side), arch_pt(a1, M_R + t + rng.uniform(-4, 4), side),
                             arch_pt(a1, M_R, side)])
            if side < 0:
                poly = poly[::-1]
            assert area2(poly) > 0
            poly = inset_edges(poly, [0.5, 0.0, 0.5, 0.0])
            prism_block(parts, poly, rng.uniform(-48.0, -38.0), rng, kind="lip", ch=rng.uniform(2.6, 3.4), chip_p=0.55,
                        chip_cm=(5.0, 13.0), bump=0.8, tilt=(rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03)))
        # ---- 4. the snout: the two keystone blocks over the apex, each with an ember nostril slit cut into it
        k = LIP_BREAKS[-1]
        poly = np.array([(0.0, M_APEX), tuple(arch_pt(k, M_R)), tuple(arch_pt(k, M_R + 58.0)), (88.0, 497.0),
                         (47.0, 523.0), (0.0, 529.0)]) * np.array([side, 1.0])
        poly = ccw2(poly)
        y_snout = -48.0
        cut_block(parts, inset_edges(poly, 0.45), y_snout, rng, [(nostrils[side], "hole")], "lip", ch=3.2,
                  tilt=(0.0, 0.035))
        ns = nostrils[side]
        cap = np.concatenate([to3(ns, y_snout + 21.0), [[ns[:, 0].mean(), y_snout + 23.0, ns[:, 1].mean()]]])
        m = len(ns)
        parts.add((cap, [[i, (i + 1) % m, m] for i in range(m)]), "Ember", "nostril_glow")

    # ---- 5. teeth: 8 upper fangs hanging from the soffit, 7 lower ones standing on the sill
    tooth_tips = []
    for ax_, length in UPPER_TEETH:
        for side in (1.0, -1.0):
            root = np.array([side * ax_, arch_z(ax_)])
            inward = -(root - np.array([-M_CX * side, M_SPRING])) / M_R        # toward the arc's centre
            axis = _n2(inward * 0.45 + np.array([0.0, -1.0]) * 0.55 + np.array([rng.uniform(-0.05, 0.05), 0.0]))
            ln = float(np.clip(length * rng.uniform(0.97, 1.03), 45.0, 75.0))
            # thick 24..27 round y -19: the fang's front stays behind the lips' chamfered arris (lips stand >= 38 proud)
            fang(parts, root, axis, ln, rng.uniform(40.0, 48.0) * (0.85 + 0.15 * length / 75.0), rng.uniform(24.0, 27.0),
                 rng.uniform(-20.0, -18.0), rng, embed=9.0)
            tooth_tips.append(("upper", float(root[0]), ln))
    for x, height in LOWER_TEETH:
        ln = float(np.clip(height * rng.uniform(0.97, 1.03), 35.0, 55.0))
        axis = _n2((rng.uniform(-0.1, 0.1), 1.0))
        fang(parts, (x + rng.uniform(-4.0, 4.0), SILL), axis, ln, rng.uniform(36.0, 44.0) * (0.85 + 0.15 * height / 55.0),
             rng.uniform(24.0, 29.0), rng.uniform(-25.0, -20.0), rng, embed=5.0)
        tooth_tips.append(("lower", float(x), ln))
    info["teeth"] = tooth_tips

    # ---- 6. eyes: slanted almond sockets (dark walls, an Ember back, a slit pupil) under heavy overhanging brows
    for side in (1.0, -1.0):
        ol = eyes[side]
        c = ol.mean(axis=0)
        back = c + (ol - c) * 0.84
        m = len(ol)
        v = np.concatenate([to3(ol, 0.5), to3(back, EYE_DEPTH)])
        parts.add((v, [[i, (i + 1) % m, m + (i + 1) % m, m + i] for i in range(m)]), "Stone", "socket")
        cap = np.concatenate([to3(back, EYE_DEPTH), [[c[0], EYE_DEPTH + 2.0, c[1]]]])
        parts.add((cap, [[i, (i + 1) % m, m] for i in range(m)]), "Ember", "eye_glow")
        slit = eye_frame(side, [(-2.0, -18.0), (4.5, 0.0), (-2.0, 18.0), (-8.5, 0.0)])
        ridge = eye_frame(side, [(-2.0, -9.0), (-2.0, 9.0)])
        parts.add(hull(np.concatenate([to3(slit, EYE_DEPTH + 1.0), to3(ridge, EYE_DEPTH - 11.0)])), "Stone", "pupil")
        # the brow: two blocks slanting down toward the nose, their lower edge overhanging the socket
        brow = [[(-64.0, 3.0), (-6.0, 13.5), (-9.0, 53.0), (-54.0, 43.0)],
                [(-5.0, 13.5), (55.0, 24.0), (62.0, 61.0), (-8.0, 53.5)]]
        for bi, quad in enumerate(brow):
            poly = ccw2(eye_frame(side, quad))
            prism_block(parts, poly, -36.0 + 4.0 * bi + rng.uniform(-1.0, 1.0), rng, kind="brow", ch=rng.uniform(2.6, 3.6),
                        chip_p=0.5, chip_cm=(4.0, 10.0), bump=0.8, tilt=(0.0, 0.16), y_back=0.0)
        # a low cheek ridge under the eye
        cheek = ccw2(eye_frame(side, [(-40.0, -44.0), (40.0, -40.0), (50.0, -24.0), (-46.0, -27.0)]))
        prism_block(parts, cheek, -15.0, rng, kind="brow", ch=2.2, chip_p=0.5, chip_cm=(3.0, 7.0), bump=0.6,
                    tilt=(0.0, -0.2), y_back=0.0)

    # ---- 7. the crown: two segmented horns sweeping up and out from the brows, a crest of spikes between them
    horn_line = [(236.0, 606.0, 60.0, -40.0), (268.0, 643.0, 50.0, -34.0), (296.0, 680.0, 36.0, -26.0), (315.0, 716.0, 0.0, -18.0)]
    for side in (1.0, -1.0):
        for (xa, za, wa, ya), (xb, zb, wb, yb) in zip(horn_line[:-1], horn_line[1:]):
            d = _n2((xb - xa, zb - za))
            nrm = np.array([-d[1], d[0]])
            a, b = np.array([xa, za]) + d * 0.6, np.array([xb, zb]) - d * 0.6
            pts = [a - nrm * wa * 0.5, b - nrm * wb * 0.5, b + nrm * wb * 0.5, a + nrm * wa * 0.5] if wb > 0 else \
                  [a - nrm * wa * 0.5, b, a + nrm * wa * 0.5]
            poly = ccw2(np.array(pts) * np.array([side, 1.0]))
            prism_block(parts, poly, 0.5 * (ya + yb) + rng.uniform(-1.5, 1.5), rng, kind="horn", ch=rng.uniform(2.2, 3.2),
                        chip_p=0.4, chip_cm=(3.0, 8.0), bump=0.8, y_back=0.0)
    for x, z0, h, w, yf in ((0.0, 624.0, 92.0, 52.0, -32.0), (68.0, 630.0, 76.0, 46.0, -26.0), (-68.0, 630.0, 76.0, 46.0, -26.0),
                            (133.0, 640.0, 60.0, 40.0, -20.0), (-133.0, 640.0, 60.0, 40.0, -20.0)):
        lean = 0.12 * x / 133.0 * h
        poly = np.array([(x - w * 0.5, z0), (x + w * 0.5, z0), (x + w * 0.42 + lean * 0.3, z0 + 0.36 * h),
                         (x + lean + rng.uniform(-3, 3), z0 + h), (x - w * 0.42 + lean * 0.3, z0 + 0.36 * h)])
        prism_block(parts, poly, yf + rng.uniform(-1.5, 1.5), rng, kind="horn", ch=rng.uniform(2.2, 3.0), chip_p=0.35,
                    chip_cm=(3.0, 7.0), bump=0.8, y_back=0.0)
    # a furrowed forehead block between the brows
    prism_block(parts, np.array([(-34.0, 540.0), (34.0, 540.0), (52.0, 600.0), (0.0, 612.0), (-52.0, 600.0)]), -24.0, rng,
                kind="brow", ch=3.0, chip_p=0.4, chip_cm=(4.0, 9.0), bump=0.8, y_back=0.0)

    # ---- 8. the reveal through the wall and the firebox behind it (inward-facing shells, sealed from the room)
    # The reveal starts 1 cm INSIDE the lip / kerb stone at y = -2 and reaches the true opening at y = +4, so it overlaps
    # the blocks' soffit faces (which end at y = +1) instead of butting against them: no hairline to see through.
    m = len(opening)
    v = np.concatenate([to3(inset_edges(opening, -1.0), -2.0), to3(opening, 4.0), to3(opening, F_WALL)])
    tags = ["reveal_floor" if i == 0 else "reveal" for i in range(m)] * 2
    rf = [[r * m + i, r * m + (i + 1) % m, (r + 1) * m + (i + 1) % m, (r + 1) * m + i] for r in range(2) for i in range(m)]
    parts.add((v, rf), "Stone", tags)
    rings = [chamber_ring(y, w, sp, cr, rng, 0.0 if i == 0 else 5.5) for i, (y, w, sp, cr) in enumerate(CHAMBER_STATIONS)]
    info["chamber_front"] = rings[0][:, [0, 2]]
    cv, cf = fc.loft(rings, close_start=False, close_end=False)
    ctags = CHAMBER_EDGE_TAGS * (len(rings) - 1)
    kk = len(rings[0])
    base = len(cv)
    cv = np.concatenate([cv, [[0.0, FB_BACK + 6.0, 215.0]]])
    cf = cf + [[base - kk + i, base - kk + (i + 1) % kk, base] for i in range(kk)]
    ctags = ctags + ["fb_back"] * kk
    parts.add((cv, cf), "Stone", ctags)

    # ---- 9. the fire: an ember heap, two wrought-iron fire dogs, charred logs across them
    coals, clinkers = ember_heap(parts, rng)
    rest = max(fire_dog(parts, sx, rng) for sx in (-84.0, 84.0))
    # three logs across the dogs, two more on top leaving the middle open over SOCKET_Fire, one fallen at the back
    logs = [((-124.0, 101.0, rest + 13.5), (112.0, 94.0, rest + 14.0), 14.0),
            ((-108.0, 147.0, rest + 14.5), (128.0, 154.0, rest + 14.0), 15.0),
            ((-120.0, 197.0, rest + 13.0), (108.0, 190.0, rest + 13.0), 13.5),
            ((-98.0, 118.0, rest + 37.0), (104.0, 128.0, rest + 36.0), 11.5),
            ((-84.0, 180.0, rest + 36.5), (116.0, 172.0, rest + 37.5), 12.0),
            ((150.0, 214.0, SILL + 13.0), (58.0, 240.0, rest + 15.0), 11.0)]
    for p0, p1, r in logs:
        charred_log(parts, p0, p1, r, rng)
    info.update(n_blocks=n_blocks, coals=coals, clinkers=clinkers, logs=len(logs), opening=opening, eyes=eyes,
                log_top=max(max(p0[2], p1[2]) + r for p0, p1, r in logs))

    obj = parts.build("FurnaceMaw_Mars_SM")
    info["flipped"] = fix_normals(obj, parts)
    paint_furnace(obj, parts, info)
    info["parts"] = parts
    return obj, info


ROOM_FACING = ("mortar", "eye_glow", "nostril_glow")          # single faces: must face the room (-Y)
INWARD = ("socket", "reveal", "reveal_floor", "fb_floor", "fb_wall", "fb_vault", "fb_back")   # shells seen from inside


def fix_normals(obj, parts):
    """new_object winds every closed shell outward; the open shells and loose faces need their own rule: block
    faces and backing face the room, the reveal / firebox / sockets face inward, the ember mound faces up."""
    mesh = obj.data
    normals = fc.face_normals(obj)
    centres = fc.face_centers_cm(obj)
    tags = np.array(parts.tag)
    island = np.array(parts.island)
    flip = np.zeros(len(tags), bool)
    for isl in np.unique(island):
        idx = np.nonzero(island == isl)[0]
        t0 = tags[idx[0]]
        if t0 in ROOM_FACING:
            flip[idx] = normals[idx, 1] > 0.0
        elif t0 == "mound":
            flip[idx] = normals[idx, 2] < 0.0
        elif t0 in INWARD:
            c = centres[idx].mean(axis=0)
            wrong = np.einsum("ij,ij->i", normals[idx], centres[idx] - c) > 0.0
            flip[idx] = wrong.sum() * 2 > len(idx)
        else:
            faces = idx[[t.endswith("/face") or t.endswith("/face_plain") for t in tags[idx]]]
            if len(faces):
                flip[idx] = (normals[faces, 1] > 0.0).sum() * 2 > len(faces)
    for i in np.nonzero(flip)[0]:
        mesh.polygons[int(i)].flip()
    mesh.update()
    return int(flip.sum())


def soot_at(x, z):
    """0..1 soot on the wall face: thick over the arch, thinning upward and sideways."""
    ax = abs(x)
    if ax > 345.0:
        return 0.0
    d = z - arch_z(min(ax, M_HALF - 1.0))
    lateral = max(0.0, 1.0 - (ax / 345.0) ** 2)
    if ax > M_HALF:
        lateral *= max(0.0, 1.0 - (ax - M_HALF) / 150.0)
    up = max(0.0, 1.0 + d / 70.0) * 0.5 if d < 0 else max(0.0, 1.0 - d / 460.0)
    return float(np.clip(1.05 * up * lateral, 0.0, 1.0) ** 0.75 * 0.95)


def paint_furnace(obj, parts, info):
    stone, stone_l, chip = P("Stone"), P("StoneLight"), fc.srgb(84, 62, 50)
    iron, ember = P("Iron"), P("Ember")
    hot, deep = fc.srgb(255, 176, 64), fc.srgb(196, 52, 14)
    soot, tooth = fc.srgb(*SOOT_SRGB), fc.srgb(*TOOTH_SRGB)
    rng = np.random.default_rng(73)
    groups = sorted(set(parts.group))
    tone = {g: rng.uniform(0.8, 1.2) for g in groups}
    warm = {g: rng.uniform(0.0, 0.35) for g in groups}
    heat = {g: rng.uniform(0.0, 1.0) for g in groups}
    centres = fc.face_centers_cm(obj)
    normals = fc.face_normals(obj)
    rgb = []
    for i, (tag, g) in enumerate(zip(parts.tag, parts.group)):
        c, n = centres[i], normals[i]
        t = tone[g]
        jit = rng.uniform(0.93, 1.07)
        if "/" in tag:
            kind, sub = tag.split("/")
            if sub in ("face", "face_plain"):
                col = (stone * 0.3 + stone_l * 0.7) * t
                col = col * (1.0 - warm[g] * 0.3) + chip * warm[g] * 0.3
            elif sub == "side":
                col = stone * t
            elif sub == "chamfer":
                col = (stone_l * 0.5 + chip * 0.5) * t
            elif sub == "chipface":
                col = chip * t * 1.05
            else:                                     # holewall
                col = stone * 0.55
            if sub != "face_plain":
                col = col * jit
            ref = info["block_centre"].get(g, c[[0, 2]]) if sub == "face_plain" else c[[0, 2]]
            s = soot_at(ref[0], ref[1])
            if kind == "lip":
                s = min(max(s * 0.8, 0.25 + 0.35 * float(np.clip((c[2] - M_SPRING) / M_RISE, 0.0, 1.0))), 0.7)
                if sub == "side":
                    s = max(s, 0.82)
            elif kind == "kerb":
                s = 0.25 if n[2] > 0.5 else 0.1
            elif kind in ("brow", "horn"):
                col = col * 0.82
                s *= 0.7
            col = lerp(col, soot, s)
        elif tag == "mortar":
            col = lerp(stone * 0.32, soot, soot_at(c[0], c[2]))
        elif tag in ("tooth", "tooth_tip", "tooth_root"):
            k = {"tooth": 1.0, "tooth_tip": 1.18, "tooth_root": 0.55}[tag]
            col = tooth * k * rng.uniform(0.9, 1.08)
            if tag == "tooth_root":
                col = lerp(col, soot, 0.45)
            elif n[1] > 0.3:
                col = lerp(col, ember * 0.5, 0.22)        # the fire side of a fang catches the glow
        elif tag == "socket":
            col = lerp(stone * 0.4, ember, 0.12 + 0.2 * float(np.clip(c[1] / EYE_DEPTH, 0.0, 1.0)))
        elif tag == "eye_glow":
            col = lerp(ember, hot, rng.uniform(0.2, 0.7))
        elif tag == "nostril_glow":
            col = lerp(deep, ember, rng.uniform(0.3, 0.8))
        elif tag == "pupil":
            col = soot * 0.8
        elif tag in ("reveal", "reveal_floor"):
            col = lerp(stone * 0.7, soot, 0.55 + 0.4 * float(np.clip((c[2] - SILL) / (M_APEX - SILL), 0.0, 1.0))) * jit
            if tag == "reveal_floor":
                col = lerp(stone * 0.75, soot, 0.35)
        elif tag.startswith("fb_"):
            up = float(np.clip((c[2] - SILL) / 330.0, 0.0, 1.0))
            col = lerp(stone * 0.5, soot * 0.7, 0.25 + 0.75 * up) * rng.uniform(0.85, 1.15)
            if tag == "fb_back":
                col = col * 0.65
            glow = max(0.0, 1.0 - math.hypot(c[0] - EMBER_C[0], c[1] - EMBER_C[1]) / 330.0) * max(0.0, 1.0 - up * 1.6)
            col = col + ember * 0.05 * glow
        elif tag == "mound":
            k = max(0.0, 1.0 - math.hypot((c[0] - EMBER_C[0]) / EMBER_HALF[0], (c[1] - EMBER_C[1]) / EMBER_HALF[1]))
            col = lerp(deep * 0.3, ember * 0.8, k) * rng.uniform(0.8, 1.2)
        elif tag == "coal":
            k = heat[g]
            col = (lerp(deep, ember, k / 0.6) if k < 0.6 else lerp(ember, hot, (k - 0.6) / 0.4)) * rng.uniform(0.82, 1.1)
            if n[2] < -0.2:
                col = col * 0.6
        elif tag == "clinker":
            col = soot * rng.uniform(0.8, 1.6)
        elif tag == "char":
            col = fc.srgb(20, 16, 14) * rng.uniform(0.6, 1.5)
            if n[2] < -0.35:
                col = col + ember * 0.07                  # undersides catch the bed
        elif tag == "crack":
            col = lerp(deep, ember, rng.uniform(0.2, 1.0)) * rng.uniform(0.75, 1.05)
        elif tag == "log_end":
            col = lerp(fc.srgb(26, 20, 16), deep, rng.uniform(0.0, 0.45))
        elif tag == "dog_knob":
            col = iron * 1.7
        else:                                             # dog
            col = iron * rng.uniform(0.95, 1.4)
        rgb.append(col)
    fc.paint(obj, np.array(rgb), variation=0.0, seed=5, cavity_darken=0.35)


def finish_furnace(obj):
    for name, loc in FUR["sockets"].items():
        sc.add_socket(obj, name, loc)
    y0, y1 = -45.0, F_WALL

    def ubox(x0, x1, ya, yb, z0, z1):
        sc.box_ucx(obj, (0.5 * (x0 + x1), 0.5 * (ya + yb), 0.5 * (z0 + z1)), (x1 - x0, yb - ya, z1 - z0))

    ubox(-F_HALF_W, -M_HALF, y0, y1, 0.0, F_TOP)                 # left pier
    ubox(M_HALF, F_HALF_W, y0, y1, 0.0, F_TOP)                   # right pier
    ubox(-M_HALF, M_HALF, y0, y1, M_APEX, F_TOP)                 # lintel
    ubox(-M_HALF, M_HALF, y0, y1, 0.0, SILL)                     # sill
    ubox(-M_HALF, M_HALF, 0.0, y1, SILL, M_APEX)                 # mouth blocker: nothing walks into the fire
    v = fc.verts_cm(obj)
    return dict(frame="origin on the floor at the mouth centre on the wall's room-side face plane (Blender y = 0); the "
                      "room is Blender -Y (Unreal +Y), the firebox runs to Blender y = +%.0f (Unreal y = -%.0f)"
                      % (FB_BACK, FB_BACK),
                face_cm=[2 * F_HALF_W, F_TOP], wall_thickness_cm=F_WALL,
                max_protrusion_cm=round(float(-v[:, 1].min()), 2),
                mouth=dict(width_at_sill_cm=2 * M_HALF, sill_top_cm=SILL, jamb_top_cm=M_SPRING, apex_cm=M_APEX,
                           arc_radius_cm=round(M_R, 2), arc_centre_offset_cm=round(M_CX, 2)),
                teeth=dict(upper=2 * len(UPPER_TEETH), lower=len(LOWER_TEETH)),
                eyes=dict(centre_cm=[ue((EYE_C[0], 0.0, EYE_C[1])), ue((-EYE_C[0], 0.0, EYE_C[1]))], size_cm=[92.0, 44.0],
                          tilt_deg=EYE_TILT, glow_plane_blender_y_cm=EYE_DEPTH),
                nostrils_cm=[ue((NOSTRIL_C[0], -27.0, NOSTRIL_C[1])), ue((-NOSTRIL_C[0], -27.0, NOSTRIL_C[1]))],
                firebox=dict(floor_z_cm=SILL, inner_width_cm=[2 * CHAMBER_STATIONS[0][1], 2 * CHAMBER_STATIONS[-1][1]],
                             back_blender_y_cm=FB_BACK, vault_crown_cm=[CHAMBER_STATIONS[0][3], CHAMBER_STATIONS[-1][3]],
                             ember_heap_cm=[2 * EMBER_HALF[0], 2 * EMBER_HALF[1], EMBER_H],
                             ember_centre_cm=ue((EMBER_C[0], EMBER_C[1], SILL))),
                emissive_slot="Ember (eye backs, nostril slits, ember heap); log cracks are painted orange in Wood",
                ucx="left pier, right pier, lintel, sill, mouth blocker (y 0..40)",
                not_built="the wall's far face and the outside / back of the firebox (never seen from the room)")


def seal_check(obj, face_tags=None):
    """Rays from the room through every 10 cm of the face (straight and slanted): each must hit a FRONT face."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    mesh = obj.data
    verts = [v.co.copy() for v in mesh.vertices]
    polys = [tuple(p.vertices) for p in mesh.polygons]
    bvh = BVHTree.FromPolygons(verts, polys)
    dirs = [Vector(d).normalized() for d in ((0, 1, 0), (0.4, 1, 0), (-0.4, 1, 0), (0, 1, 0.35), (0, 1, -0.3),
                                              (0.7, 1, 0.2), (-0.7, 1, 0.2))]
    miss = back = total = 0
    worst = []
    for xi in range(-39, 40):
        for zi in range(1, 75):
            p = Vector((xi * 0.1 + 0.013, 0.0, zi * 0.1 + 0.017))
            for d in dirs:
                total += 1
                o = p - d * 3.0
                loc, nrm, idx, dist = bvh.ray_cast(o, d)
                if loc is None:
                    miss += 1
                    worst.append(("miss", round(p.x * 100), round(p.z * 100)))
                elif nrm.dot(d) > 1e-4:
                    # a ray that happens to lie IN a surface it skims (a firebox wall running almost along the ray)
                    # reports either side: it only counts when the rays 4 mm round it see a back face too
                    again = 0
                    for dx, dz in ((0.004, 0.0), (-0.004, 0.0), (0.0, 0.004), (0.0, -0.004)):
                        l2, n2, _, _ = bvh.ray_cast(o + Vector((dx, 0.0, dz)), d)
                        again += int(l2 is None or n2.dot(d) > 1e-4)
                    if again >= 3:
                        back += 1
                        worst.append(("back", round(p.x * 100), round(p.z * 100), [round(c * 100, 1) for c in loc],
                                      [round(c, 2) for c in d], face_tags[idx] if face_tags else idx))
    # crack probe: rays from the room aimed at the line where the lips / kerb meet the reveal (the opening outline at
    # y = +1), leaving outward through the wall - a hairline there would show the void behind the masonry
    outline = mouth_outline()
    for i in range(len(outline)):
        a, b = outline[i], outline[(i + 1) % len(outline)]
        e = _n2(b - a)
        out2 = np.array([e[1], -e[0]])                           # outward for a CCW outline
        for t in np.linspace(0.04, 0.96, 24):
            q = a + (b - a) * t
            for off in (-0.05, 0.0, 0.05):
                for yy in (0.95, 1.0, 1.05, 2.0, 4.0):
                    for k_out in (0.25, 0.8, 2.0):
                        tgt = Vector(((q[0] + out2[0] * off) * 0.01, yy * 0.01, (q[1] + out2[1] * off) * 0.01))
                        d = Vector((out2[0] * k_out, 1.0, out2[1] * k_out)).normalized()
                        o = tgt - d * (2.5 / d.y)
                        total += 1
                        loc, nrm, idx, dist = bvh.ray_cast(o, d)
                        if loc is None:
                            miss += 1
                            worst.append(("crack-miss", round(q[0]), round(q[1]), yy, k_out))
                        elif nrm.dot(d) > 1e-4:
                            back += 1
                            worst.append(("crack-back", round(q[0]), round(q[1]), yy, k_out,
                                          face_tags[idx] if face_tags else idx))
    return total, miss, back, worst[:12]


def check_furnace(obj, info, fails):
    v = fc.verts_cm(obj)
    lo, hi = v.min(axis=0), v.max(axis=0)
    if abs(lo[0] + F_HALF_W) > 1.0 or abs(hi[0] - F_HALF_W) > 1.0:
        fails.append("FurnaceMaw: x extent %.2f .. %.2f is not +-400 within 1 cm" % (lo[0], hi[0]))
    if abs(lo[2]) > 0.05 or abs(hi[2] - F_TOP) > 0.05:
        fails.append("FurnaceMaw: z extent %.2f .. %.2f is not 0 .. 750" % (lo[2], hi[2]))
    if lo[1] < -(F_PROUD_MAX + 0.5):
        fails.append("FurnaceMaw: protrudes to y %.2f (limit -60.5)" % lo[1])
    plain = (np.abs(v[:, 0]) > F_PLAIN_X) | (v[:, 2] > F_PLAIN_Z)
    if v[plain, 1].min() < -(F_FLUSH + 0.5):
        fails.append("FurnaceMaw: y %.2f inside the plain strips (|x| > 350 or z > 720; limit -6.5)" % v[plain, 1].min())
    proud = v[:, 1] < -(F_FLUSH + 0.5)
    if np.abs(v[proud, 0]).max() > F_FEATURE_X:
        fails.append("FurnaceMaw: a protruding feature reaches |x| %.1f > 340" % np.abs(v[proud, 0]).max())
    # every face block stays within y -6 .. 0 at its face (the wall kind only)
    parts = info["parts"]
    wall_faces = [f for f, t in zip(parts.f, parts.tag) if t.startswith("wall/")]
    all_v = np.concatenate(parts.v)
    wy = all_v[sorted({i for f in wall_faces for i in f}), 1]
    if wy.min() < -6.0:
        fails.append("FurnaceMaw: a wall block face at y %.2f < -6" % wy.min())
    if abs(hi[1] - (FB_BACK + 6.0)) > 12.0:
        fails.append("FurnaceMaw: firebox back at y %.1f, expected about %.0f" % (hi[1], FB_BACK))
    # the opening lies inside the firebox's front section (so the reveal lands in the chamber, never beside it)
    front = info["chamber_front"]
    outside = [tuple(np.round(q, 1)) for q in info["opening"] if not point_in_poly(q + np.array([0.0, 0.01]), front)
               and q[1] > SILL + 1.0]
    if outside:
        fails.append("FurnaceMaw: opening points outside the firebox front section %s" % outside)
    ups = [t for t in info["teeth"] if t[0] == "upper"]
    lows = [t for t in info["teeth"] if t[0] == "lower"]
    if len(ups) != 8 or len(lows) != 7:
        fails.append("FurnaceMaw: teeth %d upper / %d lower (want 8 / 7)" % (len(ups), len(lows)))
    if not all(45.0 <= t[2] <= 75.0 for t in ups) or not all(35.0 <= t[2] <= 55.0 for t in lows):
        fails.append("FurnaceMaw: tooth lengths off %s" % [round(t[2], 1) for t in info["teeth"]])
    if max(ups, key=lambda t: t[2])[1] ** 2 > 30.0 ** 2:
        fails.append("FurnaceMaw: the longest upper teeth are not the pair nearest the centre")
    # sill top exactly at SILL under the mouth: the kerb's top faces
    kerb = all_v[sorted({i for f, t in zip(parts.f, parts.tag) if t.startswith("kerb/") for i in f})]
    if abs(kerb[:, 2].max() - SILL) > 1e-6 or kerb[:, 1].min() < KERB_FRONT - 1.5 or kerb[:, 1].min() > -43.0:
        fails.append("FurnaceMaw: kerb top %.3f / front %.2f (want %.0f / about -45)" % (kerb[:, 2].max(), kerb[:, 1].min(), SILL))
    ucx = sc.children(obj, "UCX_")
    if len(ucx) != 5:
        fails.append("FurnaceMaw: %d UCX pieces (want 5)" % len(ucx))
    socks = {e.name[len("SOCKET_"):]: tuple(round(c * 100.0, 3) for c in e.location) for e in sc.children(obj, "SOCKET_")}
    for name, loc in FUR["sockets"].items():
        if name not in socks or max(abs(a - b) for a, b in zip(socks[name], loc)) > 1e-3:
            fails.append("FurnaceMaw: socket %s at %s, want %s" % (name, socks.get(name), loc))
    total, miss, back, worst = seal_check(obj, parts.tag)
    print("  seal check: %d rays from the room, %d missed, %d hit a back face %s" % (total, miss, back, worst if (miss or back) else ""))
    if miss or back:
        fails.append("FurnaceMaw: not sealed from the room side (%d rays missed, %d hit back faces) %s" % (miss, back, worst))
    info["seal"] = dict(rays=total, missed=miss, back_faces=back)
    print("  furnace: %d wall blocks, %d coals, %d clinkers, %d logs, %d faces flipped by the facing rules, min y %.2f, "
          "max y %.2f" % (info["n_blocks"], info["coals"], info["clinkers"], info["logs"], info["flipped"], lo[1], hi[1]))


# ================================================================ review renders
REVIEW_BG = (0.21, 0.215, 0.23)


def remove_object(o):
    mesh = o.data if o.type == "MESH" else None
    bpy.data.objects.remove(o, do_unlink=True)
    if mesh is not None and mesh.users == 0:
        bpy.data.meshes.remove(mesh)


def copy_mesh(obj, offset=(0.0, 0.0, 0.0), scale=(1.0, 1.0, 1.0), name=None):
    c = bpy.data.objects.new(name or (obj.name + "_Copy"), obj.data.copy())
    bpy.context.scene.collection.objects.link(c)
    fc.set_verts_cm(c, fc.verts_cm(c) * np.asarray(scale, float) + np.asarray(offset, float))
    return c


def painted_box(name, center, size, rgb):
    v, f = sc.box(center, size)
    o = fc.new_object(name, v, f, slots=("Stone",))
    fc.paint(o, np.repeat(np.asarray(rgb, float)[None, :], len(f), axis=0), variation=0.02, cavity_darken=0.0)
    return o


def ref_bar(origin, seg_cm=10.0, count=3, axis=0, thick=1.2):
    """A reference bar in alternating segments (default 3 x 10 cm = 30 cm) along X (axis 0) or Z (axis 2)."""
    out = []
    for k in range(count):
        rgb = fc.srgb(235, 235, 235) if k % 2 == 0 else fc.srgb(205, 40, 40)
        c = np.array(origin, float)
        c[axis] += seg_cm * (k + 0.5)
        size = [thick, thick, thick]
        size[axis] = seg_cm
        out.append(painted_box("_Bar%d" % k, c, size, rgb))
    return out


def render_view(objs, path, view, size=(900, 1200), margin=1.1, ortho=True, target_cm=None, half_cm=None, lens=50.0,
                eye_cm=None, shadows=False):
    """One workbench render of objs in place. The frame fits their bounds from direction `view` (camera sits at
    target + view * distance) unless half_cm (half extent of the longer image side) is given; eye_cm places a
    perspective camera explicitly."""
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
    cam_data = bpy.data.cameras.new("_KitchenCam")
    cam_data.clip_start, cam_data.clip_end = 0.02, 2000.0
    cam = bpy.data.objects.new("_KitchenCam", cam_data)
    scene.collection.objects.link(cam)
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    prev = (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
            scene.render.filepath, scene.display.shading.color_type, scene.display.shading.light,
            scene.display.shading.show_cavity, scene.render.film_transparent, tuple(scene.world.color),
            scene.display.shading.show_shadows, scene.display.shading.show_specular_highlight)
    try:
        for o in hidden:
            o.hide_render = True
        saved = [o.hide_render for o in objs]
        for o in objs:
            o.hide_render = False
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "VERTEX"
        scene.display.shading.show_cavity = True
        scene.render.film_transparent = False
        scene.world.color = REVIEW_BG
        scene.display.shading.show_shadows = bool(shadows)
        scene.display.shading.show_specular_highlight = False     # the highlight greys out every dark facet it faces
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
         scene.render.filepath, scene.display.shading.color_type, scene.display.shading.light,
         scene.display.shading.show_cavity, scene.render.film_transparent) = prev[:9]
        scene.world.color = prev[9]
        scene.display.shading.show_shadows = prev[10]
        scene.display.shading.show_specular_highlight = prev[11]
        bpy.data.objects.remove(cam)
        bpy.data.cameras.remove(cam_data)
    return path


PROP_VIEWS = (("iso", (1.0, -1.25, 0.55)), ("front", (0.0, -1.0, 0.0)), ("side", (1.0, 0.0, 0.0)))


def prop_sheet(obj, stem, size=(900, 1200), views=PROP_VIEWS):
    paths = [render_view([obj], os.path.join(spec.REVIEW_DIR, "%s_%s.png" % (stem, k)), v, size=size)
             for k, v in views]
    return fc.tile_images(paths, os.path.join(spec.REVIEW_DIR, "%s_sheet.png" % stem), cols=len(paths))


def lineup_sheet(built):
    """The five hanging props on RackHooks on a RackBar (scaled along X as the game does) between two brackets."""
    order = ("HangPan", "GarlicBraid", "HangSaucepan", "HerbBundle", "HangLadle")
    xs = (-58.0, -30.0, -4.0, 24.0, 46.0)
    half = 72.0
    tmp = [copy_mesh(built["RackBar"][0], scale=(half / 50.0, 1.0, 1.0))]
    for sx in (-1.0, 1.0):
        tmp.append(copy_mesh(built["RackBracket"][0], offset=(sx * (half - 5.0), 0.0, 0.0)))
    for name, x in zip(order, xs):
        tmp.append(copy_mesh(built["RackHook"][0], offset=(x, 0.0, 0.0)))
        tmp.append(copy_mesh(built[name][0], offset=(x, 0.0, -HOOK_DROP)))
    tmp += ref_bar((-15.0, 0.0, -78.0))
    tmp.append(painted_box("_Wall", (0.0, WALL_Y + 1.0, -32.0), (2.0 * half + 30.0, 2.0, 110.0), fc.srgb(134, 126, 116)))
    paths = [render_view(tmp, os.path.join(spec.REVIEW_DIR, "RackLineup_front.png"), (0.0, -1.0, 0.0), size=(1900, 1250)),
             render_view(tmp, os.path.join(spec.REVIEW_DIR, "RackLineup_iso.png"), (0.75, -1.0, 0.3), size=(1900, 1250)),
             render_view(tmp[:3] + tmp[3:5], os.path.join(spec.REVIEW_DIR, "RackLineup_hookclose.png"), (1.0, -0.35, 0.2),
                         size=(1900, 1250), target_cm=(xs[0], 0.0, -5.0), half_cm=22.0)]
    for o in tmp:
        remove_object(o)
    return fc.tile_images(paths, os.path.join(spec.REVIEW_DIR, "RackLineup_sheet.png"), cols=1)


def furnace_sheets(obj):
    """From the room side: front, three-quarter, a close view into the mouth and a close view of the face, with a
    150 cm box (the chef's height) standing in front of the left pier."""
    chef = painted_box("_Chef150", (-300.0, -110.0, 75.0), (45.0, 30.0, 150.0), fc.srgb(226, 222, 210))
    objs = [obj, chef]
    size = (1700, 1300)

    def path(name):
        return os.path.join(spec.REVIEW_DIR, "FurnaceMaw_%s.png" % name)

    paths = [render_view(objs, path("front"), (0.0, -1.0, 0.0), size=size, margin=1.04),
             render_view(objs, path("threequarter"), None, size=size, target_cm=(0.0, 0.0, 350.0),
                         eye_cm=(-640.0, -1000.0, 250.0), lens=30.0, shadows=True),
             render_view(objs, path("mouth"), None, size=size, target_cm=(0.0, 150.0, 185.0),
                         eye_cm=(0.0, -340.0, 150.0), lens=22.0),
             render_view(objs, path("face"), None, size=size, target_cm=(40.0, 0.0, 500.0),
                         eye_cm=(360.0, -560.0, 300.0), lens=34.0, shadows=True)]
    remove_object(chef)
    return [fc.tile_images(paths, os.path.join(spec.REVIEW_DIR, "FurnaceMaw_sheet.png"), cols=2)] + paths


# ================================================================ checks
def check_hanging(name, obj, fails):
    lo, hi = fc.bounds_cm(obj)
    c = 0.5 * (lo + hi)
    if hi[2] > 0.6:
        fails.append("%s: max z %.3f > 0.6 (the mesh must hang below the hang point)" % (name, hi[2]))
    if abs(c[0]) > 1.0 or abs(c[1]) > 1.5:
        fails.append("%s: not centred under the hang point (bbox centre x %.2f y %.2f)" % (name, c[0], c[1]))
    # the hang point itself: the inside top of the ring / loop is the origin (a vertex there, nothing just under it)
    v = fc.verts_cm(obj)
    near = np.linalg.norm(v[:, [0, 2]], axis=1) < 1e-4
    if not near.any():
        fails.append("%s: no ring / loop vertex at the hang point (x 0, z 0)" % name)
    hole = np.hypot(v[:, 0], v[:, 2] + 1.0) < 0.8             # a hook's wire needs this disc under the hang point
    if hole.any():
        fails.append("%s: geometry inside the ring hole under the hang point" % name)


def check_rack(name, obj, fails):
    v = fc.verts_cm(obj)
    lo, hi = v.min(axis=0), v.max(axis=0)
    if name == "RackBar":
        if abs(lo[0] + 50.0) > 1e-4 or abs(hi[0] - 50.0) > 1e-4:
            fails.append("RackBar: x extent %.4f .. %.4f is not exactly -50 .. 50" % (lo[0], hi[0]))
        reach = float(np.hypot(v[:, 1], v[:, 2]).max())
        if reach > BAR_CLEAR:
            fails.append("RackBar: section reaches %.3f > the hooks' clearance radius %.1f" % (reach, BAR_CLEAR))
        if max(abs(lo[1]), abs(hi[1]), abs(lo[2]), abs(hi[2])) > 1.45:
            fails.append("RackBar: section too fat %s %s" % (lo, hi))
    else:
        # nothing inside the bar's clearance radius round the X axis (vertices, edge midpoints, face centres)
        mesh = obj.data
        e = np.array([ed.vertices[:] for ed in mesh.edges])
        samples = np.concatenate([v, 0.5 * (v[e[:, 0]] + v[e[:, 1]]), fc.face_centers_cm(obj)])
        r = float(np.hypot(samples[:, 1], samples[:, 2]).min())
        if r < BAR_CLEAR - 1e-3:
            fails.append("%s: something %.3f cm from the bar axis (< clearance %.1f)" % (name, r, BAR_CLEAR))
        if abs(0.5 * (lo[0] + hi[0])) > 0.2:
            fails.append("%s: not centred on x (%.2f .. %.2f)" % (name, lo[0], hi[0]))
    if name == "RackHook":
        # the cradle: the lowest point of the lower hook's INNER surface on the plane y = 0 is exactly (0, 0, -9)
        on = np.abs(v[:, 1]) < 1e-6
        inner = v[on & (v[:, 2] < -4.0)]
        z_cradle = float(inner[:, 2].max()) if len(inner) else 99.0
        if abs(z_cradle + HOOK_DROP) > 1e-4:
            fails.append("RackHook: cradle at z %.4f, not %.1f" % (z_cradle, -HOOK_DROP))
        lower = v[v[:, 2] < -HOOK_DROP + 1.0]
        if len(lower) and float(lower[:, 2].min()) > -HOOK_DROP - 0.3:
            fails.append("RackHook: no iron under the cradle")
        if hi[2] < BAR_CLEAR:
            fails.append("RackHook: the top hook does not go over the bar")
    if name == "RackBracket":
        if abs(hi[1] - WALL_Y) > 1e-4:
            fails.append("RackBracket: back plate at y %.4f, not the wall plane %.1f" % (hi[1], WALL_Y))
        top_open = v[(v[:, 1] > -0.5) & (v[:, 1] < WALL_Y - 2.0) & (v[:, 2] > 0.0)]
        if len(top_open):
            fails.append("RackBracket: the cradle is not open at the top")


# ================================================================ main
BUILDERS = {"HangPan": build_hang_pan, "HangSaucepan": build_hang_saucepan, "HangLadle": build_hang_ladle,
            "GarlicBraid": build_garlic_braid, "HerbBundle": build_herb_bundle, "RackBar": build_rack_bar,
            "RackHook": build_rack_hook, "RackBracket": build_rack_bracket}


def reimport(path, want_ucx, want_sockets, fails):
    before = set(bpy.data.objects)
    rep = fc.reimport_check(path)
    for o in [o for o in bpy.data.objects if o not in before]:
        bpy.data.objects.remove(o, do_unlink=True)
    stem = os.path.splitext(os.path.basename(path))[0]
    meshes = [r for r in rep if not r["name"].startswith("UCX_")]
    ucx = [r for r in rep if r["name"].startswith("UCX_")]
    with open(os.path.splitext(path)[0] + ".json") as fh:
        meta = json.load(fh)
    problems = []
    if len(meshes) != 1:
        problems.append("meshes %s" % [r["name"] for r in meshes])
    for r in meshes:
        if r["uv_layers"][:1] != ["UVMap"]:
            problems.append("uv %s" % r["uv_layers"])
        if "Col" not in r["colors"]:
            problems.append("colors %s" % r["colors"])
        if not r["flat"]:
            problems.append("not flat")
        if r["tris"] != meta["tris"]:
            problems.append("tris %d != sidecar %d" % (r["tris"], meta["tris"]))
        if sorted(s.split(".")[0] for s in r["slots"] if s) != sorted(meta["slots"]):     # a re-import renames to X.001
            problems.append("slots %s != %s" % (r["slots"], meta["slots"]))
    if len(ucx) != want_ucx or meta["ucx_pieces"] != want_ucx or meta["ucx_problems"]:
        problems.append("ucx reimported %d / sidecar %d / want %d, problems %s" % (
            len(ucx), meta["ucx_pieces"], want_ucx, meta["ucx_problems"]))
    if set(meta["sockets"]) != set(want_sockets):
        problems.append("sidecar sockets %s != %s" % (sorted(meta["sockets"]), sorted(want_sockets)))
    print("REIMPORT %-22s %s ucx %d sockets %s -> %s" % (
        stem, json.dumps([{k: r[k] for k in ("tris", "uv_layers", "colors", "flat", "slots")} for r in meshes]),
        len(ucx), json.dumps({k: v["location_cm"] for k, v in meta["sockets"].items()}),
        "ok" if not problems else "FAIL " + "; ".join(problems)))
    if problems:
        fails.append("%s reimport: %s" % (stem, "; ".join(problems)))


def main():
    args = fc.cli_args({"export": False, "save": False, "sheets": False, "only": ""})
    t0 = time.time()
    fc.ensure_dirs()
    fc.clear_scene()
    bpy.context.scene.view_settings.view_transform = "Standard"
    only = [n for n in str(args["only"]).split(",") if n] if args["only"] else list(ALL_NAMES)
    unknown = [n for n in only if n not in ALL_NAMES]
    if unknown:
        raise SystemExit("unknown prop(s) %s; choose from %s" % (unknown, ALL_NAMES))
    fails = []
    built = {}            # key -> (obj, extra)
    exported = {}         # key -> fbx path
    furnace_info = None

    for key in ALL_NAMES:
        if key not in only:
            continue
        t1 = time.time()
        prop = spec.PROPS[key]
        before = len(fails)
        if key == "FurnaceMaw":
            obj, furnace_info = build_furnace()
            extra = finish_furnace(obj)
            check_furnace(obj, furnace_info, fails)
        else:
            obj, extra = BUILDERS[key]()
        fc.smart_uv(obj)
        extra = dict(dict(station="kitchen", builder="build_station_kitchen.py", pivot=prop["pivot"]), **extra)
        built[key] = (obj, extra)
        tris = fc.tri_count(obj)
        lo, hi = fc.bounds_cm(obj)
        print("%-22s tris %5d / %5d  bounds %s .. %s  size %s  (%.1fs)" % (
            obj.name, tris, prop["tris_max"], np.round(lo, 2), np.round(hi, 2), np.round(hi - lo, 1), time.time() - t1))
        if tris > prop["tris_max"]:
            fails.append("%s tris %d > %d" % (obj.name, tris, prop["tris_max"]))
        if tuple(m.name for m in obj.data.materials) != tuple(prop["slots"]):
            fails.append("%s slots %s != spec %s" % (obj.name, [m.name for m in obj.data.materials], prop["slots"]))
        used = {p.material_index for p in obj.data.polygons}
        if used != set(range(len(prop["slots"]))):
            fails.append("%s: a material slot has no faces (%s)" % (obj.name, sorted(used)))
        if key in HANG_NAMES:
            check_hanging(key, obj, fails)
            extra["drop_cm"] = round(float(-lo[2]), 2)
            extra["width_cm"] = round(float(hi[0] - lo[0]), 2)
            extra["hang_point"] = "origin = inside top of the ring / loop; the mesh hangs toward -Z"
        elif key in RACK_NAMES:
            check_rack(key, obj, fails)
        probs = sc.check_ucx(obj)
        if probs:
            fails.append("%s ucx %s" % (obj.name, probs))
        if key != "FurnaceMaw" and (sc.children(obj, "UCX_") or sc.children(obj, "SOCKET_")):
            fails.append("%s must have no UCX / sockets" % obj.name)
        ok = len(fails) == before
        if args["export"] and ok:
            exported[key] = sc.export_fbx(obj, extra=extra)
        elif args["export"]:
            print("  NOT exported (checks failed): %s" % key)

    sheets = []
    if args["sheets"]:
        for key in ALL_NAMES:
            if key not in built:
                continue
            if key == "FurnaceMaw":
                sheets += furnace_sheets(built[key][0])
            elif key == "RackBar":
                sheets.append(prop_sheet(built[key][0], key, size=(1500, 600),
                                         views=(("iso", (1.0, -1.25, 0.55)), ("front", (0.0, -1.0, 0.0)),
                                                ("end", (1.0, -0.25, 0.15)))))
            else:
                sheets.append(prop_sheet(built[key][0], key))
        if all(k in built for k in HANG_NAMES + RACK_NAMES):
            sheets.append(lineup_sheet(built))
        for m in list(bpy.data.materials):
            if m.users == 0:
                bpy.data.materials.remove(m)
    if args["save"]:
        sc.save_blend("kitchen")
        print("saved", os.path.join(spec.BLEND_DIR, spec.STATIONS["kitchen"][0]))

    # ---- re-import every FBX (after the save, so the blend stays clean) + read back the sidecars
    for key, path in exported.items():
        want_sockets = spec.PROPS[key]["sockets"]
        reimport(path, 5 if key == "FurnaceMaw" else 0, want_sockets, fails)
    print("\nsheets:", *sheets, sep="\n  ")
    print("exported:", *exported.values(), sep="\n  ")
    print("total %.1fs" % (time.time() - t0))
    if fails:
        print("STATION_KITCHEN_FAIL", *fails, sep="\n  ")
    elif len(only) != len(ALL_NAMES):
        print("STATION_KITCHEN_PARTIAL (only %s; not the full set)" % ",".join(only))
    else:
        print("STATION_KITCHEN_OK")


if __name__ == "__main__":
    main()
