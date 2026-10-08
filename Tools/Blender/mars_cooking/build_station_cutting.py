"""Mars cooking station props, station "cutting" (station_spec.STATIONS): the dicing / prep table set.

Builds from fixed seeds, in Blender 5.2 headless:
  PrepTable_Mars_SM     Wood / Stone / Iron   plank top on chiselled stone block piers, wood apron, lower shelf, iron
                                              bands round the pier heads, iron brackets on the apron. Pivot: floor
                                              contact, XY centre. Top at exactly 70 cm (nothing rises above it).
  CuttingBoard_Mars_SM  Wood                  50 x 90 x 4 end-grain block board, hand-cut chamfer, shallow V juice
                                              groove 9 cm in from every edge, three shallow knife scores along X.
                                              Pivot: centre of the underside. The outer 8 cm band of the top is flat.
  PrepBowl_Mars_SM      Stone                 thick stone bowl (30 across, 12 tall), chiselled outside, smooth-faceted
                                              inside. Pivot: centre of the inner floor (base at z = -3).
  PrepTray_Mars_SM      Wood / Rope           shallow plank tray, corner posts lashed with rope. Pivot: centre of the
                                              inner floor (base at z = -1.5).

Axes: geometry is built in Blender cm (station_common). The station frame the entity scripts use is the UNREAL frame
(X forward from the operator, Y right, Z up); Unreal y = -Blender y. station_spec's socket y values for the table are
read as Unreal station-frame values ("Input" is on the operator's LEFT = Unreal -Y), so they are placed mirrored in
Blender and the sidecars (which mirror Y) read exactly the spec numbers.

Run (the scene is rebuilt from nothing every time; always absolute paths):
  blender -b --factory-startup --python build_station_cutting.py -- [--export] [--save] [--sheets]
    --export   FBX + JSON sidecar per prop into station_spec.EXPORT_DIR, CuttingStation_Layout.json, then every FBX is
               re-imported in its own fresh factory-startup Blender (food_common.reimport_check) and verified
    --sheets   review sheets into station_spec.REVIEW_DIR (one per prop + CuttingStation_Assembled)
    --save     station_spec.BLEND_DIR/Station_Cutting.blend
Prints STATION_CUTTING_OK when every check passed (STATION_CUTTING_FAIL + the reasons otherwise).
"""
import json
import math
import os
import subprocess
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
STATION = "cutting"
PROPS = {k: v for k, v in spec.PROPS.items() if v["builder"] == STATION}
FOOD_EXPORT_DIR = os.path.join(spec.base.EXPORT_DIR, "food")

# ---------------------------------------------------------------- layout (cm)
TABLE_D, TABLE_W, TABLE_H = PROPS["PrepTable"]["size_cm"]            # 80 x 160 x 70
TOP_T = 5.0                                                          # plank thickness: planks span z 65..70
BOARD_D, BOARD_W, BOARD_T = PROPS["CuttingBoard"]["size_cm"]         # 50 x 90 x 4
BOARD_FLAT_BAND = 8.0                                                # outer band of the board top that stays flat
GROOVE_INSET, GROOVE_DEPTH = 9.0, 0.3
SCORE_DEPTH = 0.25
BOWL = PROPS["PrepBowl"]
BOWL_FLOOR = BOWL["floor_cm"]                                        # 3: base at z = -3 under the pivot
BOWL_SEG = 20
TRAY_D, TRAY_W, TRAY_H = PROPS["PrepTray"]["size_cm"]                # 26 x 30 x 8
TRAY_FLOOR = 1.5                                                     # floor plank thickness: base at z = -1.5

# ---------------------------------------------------------------- colours (linear)
WOOD = sc.palette("Wood")
WOOD_DARK = sc.palette("WoodDark")
STONE = sc.palette("Stone")
STONE_LIGHT = sc.palette("StoneLight")
IRON = sc.palette("Iron")
ROPE = sc.palette("Rope")
CHIP = fc.srgb(84, 62, 50)                                           # warm chipped stone (station_spec palette note)


def lerp(a, b, t):
    return np.asarray(a, float) * (1.0 - t) + np.asarray(b, float) * t


# ---------------------------------------------------------------- mesh assembly
class Parts:
    """Collects (verts, faces, slot, per-face rgb) parts into one mesh."""

    def __init__(self):
        self.v, self.f, self.s, self.c, self.n = [], [], [], [], 0

    def add(self, v, faces, slot, rgb):
        v = np.asarray(v, float)
        rgb = np.asarray(rgb, float)
        if rgb.ndim == 1:
            rgb = np.tile(rgb, (len(faces), 1))
        assert len(rgb) == len(faces)
        self.v.append(v)
        self.f += [[self.n + int(i) for i in f] for f in faces]
        self.s += [slot] * len(faces)
        self.c.append(rgb)
        self.n += len(v)

    def verts(self):
        return np.concatenate(self.v)

    def build(self, name, slots, verts=None):
        obj = sc.new_object(name, self.verts() if verts is None else verts, self.f, slots, face_slots=self.s)
        assert len(obj.data.polygons) == len(self.f), "%s lost faces in validate (%d -> %d)" % (
            name, len(self.f), len(obj.data.polygons))
        return obj, np.concatenate(self.c)


def poly_normal(pts):
    pts = np.asarray(pts, float)
    n = np.zeros(3)
    for a, b in zip(pts, np.roll(pts, -1, axis=0)):
        n += np.array([(a[1] - b[1]) * (a[2] + b[2]), (a[2] - b[2]) * (a[0] + b[0]), (a[0] - b[0]) * (a[1] + b[1])])
    return n / (np.linalg.norm(n) + 1e-12)


def hull(points, merge_coplanar=True):
    """Convex hull (bmesh) of points -> (verts, polygon faces); coplanar triangles merged so a flat face paints as one."""
    bm = bmesh.new()
    for p in points:
        bm.verts.new(tuple(p))
    bm.verts.ensure_lookup_table()
    res = bmesh.ops.convex_hull(bm, input=bm.verts[:])
    for geom in (res.get("geom_interior", []), res.get("geom_unused", [])):
        bmesh.ops.delete(bm, geom=[g for g in geom if isinstance(g, bmesh.types.BMVert)], context="VERTS")
    if merge_coplanar:
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.3), use_dissolve_boundaries=False,
                                 verts=bm.verts[:], edges=bm.edges[:])
    bm.verts.ensure_lookup_table()
    bm.verts.index_update()
    v = np.array([x.co[:] for x in bm.verts], float)
    f = [[x.index for x in face.verts] for face in bm.faces]
    bm.free()
    return v, f


def rot_z(v, deg, about):
    a = math.radians(deg)
    r = np.array([[math.cos(a), -math.sin(a), 0.0], [math.sin(a), math.cos(a), 0.0], [0.0, 0.0, 1.0]])
    about = np.asarray(about, float)
    return (np.asarray(v, float) - about) @ r.T + about


# ---------------------------------------------------------------- sockets (unique-name workaround)
def add_socket(obj, name, location_cm):
    """sc.add_socket + the intended name kept on the empty. Blender object names are unique, so the bowl's and the
    tray's SOCKET_Contents cannot both hold the clean name; claim_socket_names() hands it to whichever prop is being
    exported (the FBX and station_common.socket_table both read the object name)."""
    e = sc.add_socket(obj, name, location_cm)
    e["socket_name"] = "SOCKET_" + name
    return e


def socket_name(e):
    return e.get("socket_name", e.name)


def claim_socket_names(obj):
    for e in sc.children(obj, "SOCKET_"):
        clean = socket_name(e)
        other = bpy.data.objects.get(clean)
        if other is not None and other is not e:
            other.name = clean + "__" + (other.parent.name if other.parent else "parked")
        e.name = clean


# ---------------------------------------------------------------- primitives (cm)
P_BOTTOM, P_SIDE, P_CHAMF, P_TOP, P_END = range(5)


def plank(axis, cu, z0, s0, s1, w, t, rng, segs=4, chamfer=(0.4, 1.0), wobble=0.2, end_skew=0.6):
    """A hand-cut plank lofted along axis ("x" or "y") from s0 to s1; cross-section width w (across, centred on cu)
    and thickness t from z0 up, top edges chamfered by random amounts. The top face stays exactly at z0 + t; the
    sides wobble on interior rings; the end caps keep their bottom edge at s0 / s1 and lean the top in (hand-cut).
    -> (verts, faces, per-face kind P_*)."""
    ss = np.linspace(s0, s1, segs + 1)
    c1, c2 = rng.uniform(*chamfer, 2)
    rings = []
    for i, s in enumerate(ss):
        du0, du1 = rng.uniform(-wobble, wobble, 2) if 0 < i < segs else (0.0, 0.0)
        k1, k2 = c1 * rng.uniform(0.75, 1.25), c2 * rng.uniform(0.75, 1.25)
        prof = [(-w / 2 + du0, 0.0), (w / 2 + du1, 0.0), (w / 2 + du1, t - k2), (w / 2 + du1 - k2, t),
                (-w / 2 + du0 + k1, t), (-w / 2 + du0, t - k1)]
        sv = np.full(6, s)
        if i == 0:
            sv[2:] += rng.uniform(0.0, end_skew, 4)
        elif i == segs:
            sv[2:] -= rng.uniform(0.0, end_skew, 4)
        ring = [((cu + u, sv[j], z0 + v) if axis == "y" else (sv[j], cu + u, z0 + v)) for j, (u, v) in enumerate(prof)]
        rings.append(ring)
    v, f = fc.loft(rings)
    kinds = [P_BOTTOM, P_SIDE, P_CHAMF, P_TOP, P_CHAMF, P_SIDE] * segs + [P_END, P_END]
    return v, f, kinds


def plank_rgb(kinds, tone, rng):
    base = WOOD * tone
    out = []
    for k in kinds:
        if k == P_TOP:
            out.append(base * rng.uniform(0.88, 1.1))
        elif k == P_CHAMF:
            out.append(base * 1.14)                                   # worn, lighter edges
        elif k == P_SIDE:
            out.append(base * 0.9)
        elif k == P_END:
            out.append(WOOD_DARK * tone)                              # end grain
        else:
            out.append(WOOD_DARK * 0.85)                              # underside
    return np.array(out)


def stone_block(center, size, rng, chip=(0.5, 1.3), big_p=0.35, big=(1.6, 3.6), yaw_deg=1.2, bulge=(0.5, 1.1)):
    """A chiselled stone block: every corner cut back by its own random amounts along each axis (convex hull), a few
    corners knocked off hard, a slight yaw. -> (verts, faces, per-face is_chip)."""
    c = np.asarray(center, float)
    s = np.asarray(size, float)
    h = s * 0.5
    pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                e = rng.uniform(*chip, 3)
                if rng.uniform() < big_p:
                    e = e + rng.uniform(*big) * rng.uniform(0.6, 1.0, 3)
                e = np.minimum(e, 0.4 * s)
                corner = np.array([sx * h[0], sy * h[1], sz * h[2]])
                for ax in range(3):
                    p = corner.copy()
                    p[ax] -= math.copysign(e[ax], corner[ax])
                    pts.append(p)
    if bulge:                                       # chiselled vertical faces: an off-centre ridge point per face
        for ax in (0, 1):
            other = 1 - ax
            for sgn in (-1, 1):
                p = np.zeros(3)
                p[ax] = sgn * (h[ax] + rng.uniform(*bulge))
                p[other] = rng.choice((-1, 1)) * rng.uniform(0.3, 0.6) * h[other]
                p[2] = rng.choice((-1, 1)) * rng.uniform(0.15, 0.5) * h[2]
                pts.append(p)
    v, f = hull(np.array(pts))
    is_chip = []
    for face in f:
        n = poly_normal(v[face])
        is_chip.append(np.abs(n).max() < 0.985)
    if yaw_deg:
        v = rot_z(v, rng.uniform(-yaw_deg, yaw_deg), (0.0, 0.0, 0.0))
    return v + c, f, np.array(is_chip)


def stone_rgb(v, f, is_chip, rng, shade=1.0):
    base = lerp(STONE, STONE_LIGHT, rng.uniform(0.1, 0.7)) * shade
    centre = v.mean(axis=0)
    out = []
    for face, chip in zip(f, is_chip):
        n = poly_normal(v[face])
        if np.dot(n, v[face].mean(axis=0) - centre) < 0:
            n = -n
        if chip:
            out.append(lerp(base, CHIP, rng.uniform(0.55, 0.8)))
        elif n[2] > 0.95:
            out.append(lerp(base, STONE_LIGHT, 0.35))
        elif n[2] < -0.95:
            out.append(base * 0.7)
        else:
            out.append(base * rng.uniform(0.9, 1.08))
    return np.array(out)


def rect_frame(cx, cy, hx, hy, t, z0, z1):
    """A rectangular band (inner half extents hx, hy, thickness t) between z0 and z1 -> (verts, faces)."""
    v = []
    for z in (z0, z1):
        for e in (0.0, t):
            for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                v.append((cx + sx * (hx + e), cy + sy * (hy + e), z))
    v = np.array(v)

    def idx(zi, ri, k):
        return zi * 8 + ri * 4 + (k % 4)

    f = []
    for k in range(4):
        f.append([idx(1, 0, k), idx(1, 1, k), idx(1, 1, k + 1), idx(1, 0, k + 1)])     # top
        f.append([idx(0, 0, k), idx(0, 0, k + 1), idx(0, 1, k + 1), idx(0, 1, k)])     # bottom
        f.append([idx(0, 1, k), idx(0, 1, k + 1), idx(1, 1, k + 1), idx(1, 1, k)])     # outer
        f.append([idx(0, 0, k), idx(1, 0, k), idx(1, 0, k + 1), idx(0, 0, k + 1)])     # inner
    return v, f


def pyramid(base_center, normal, half, height, spin=0.0):
    """A faceted rivet head: square base (half size) on a surface, apex along normal -> (verts, faces)."""
    n = np.asarray(normal, float)
    n /= np.linalg.norm(n)
    helper = np.array([0.0, 0.0, 1.0]) if abs(n[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    u = np.cross(n, helper)
    u /= np.linalg.norm(u)
    w = np.cross(n, u)
    c = np.asarray(base_center, float)
    base = [c + half * (math.cos(spin + k * math.pi / 2) * u + math.sin(spin + k * math.pi / 2) * w) for k in range(4)]
    v = np.array(base + [c + n * height])
    f = [[3, 2, 1, 0]] + [[k, (k + 1) % 4, 4] for k in range(4)]
    return v, f


def square_wrap(center, half, tube, z, corner=0.5, sides=4):
    """One rope turn hugging a square post (half size `half`): an octagonal loop of a `sides`-sided tube whose
    outside sits 2 * tube beyond the post faces -> (verts, faces)."""
    cx, cy = center
    a = half + tube
    c = min(corner, a * 0.6)
    path = [(a, -a + c), (a, a - c), (a - c, a), (-a + c, a), (-a, a - c), (-a, -a + c), (-a + c, -a), (a - c, -a)]
    rings = []
    for px, py in path:
        u = np.array([px, py, 0.0])
        u /= np.linalg.norm(u)
        rings.append(fc.ring((cx + px, cy + py, z), tube, tube, sides, u, (0.0, 0.0, 1.0), math.pi / sides))
    rings.append(rings[0])
    return fc.loft(rings, close_start=False, close_end=False)


def chamfer_post(center, size, z0, z1, top_inset):
    """A square post from z0 to z1 with a pyramidal chamfer on top -> (verts, faces)."""
    cx, cy = center
    hx, hy = size[0] / 2, size[1] / 2
    zc = z1 - top_inset
    v = []
    for z, ix in ((z0, 0.0), (zc, 0.0), (z1, top_inset)):
        for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            v.append((cx + sx * (hx - ix), cy + sy * (hy - ix), z))
    v = np.array(v)
    f = [[3, 2, 1, 0], [8, 9, 10, 11]]
    for ring in (0, 4):
        for k in range(4):
            f.append([ring + k, ring + (k + 1) % 4, ring + 4 + (k + 1) % 4, ring + 4 + k])
    return v, f


# ---------------------------------------------------------------- PrepTable
PIER_Y = 63.0                     # pier centre (Blender +-Y)
PIER_D, PIER_W = 66.0, 26.0       # upper courses: depth (X) x width (Y)
PLINTH_D, PLINTH_W, PLINTH_H = 70.0, 30.0, 12.0
TOP_Z0 = TABLE_H - TOP_T          # 65: plank undersides / pier tops
BAND_Z = (53.0, 57.0)             # iron band round each pier head
APRON_X = 31.0                    # apron centre (+-X), set back from the pier face (33)
APRON_T, APRON_H = 2.5, 9.5


def build_table(seed=8101):
    rng = np.random.default_rng(seed)
    parts = Parts()
    # ---- plank top: 6 planks along Y across the 80 cm depth, 0.5 cm gaps, top exactly at 70
    n_planks, gap = 6, 0.5
    p = rng.uniform(0.82, 1.18, n_planks)
    widths = p / p.sum() * (TABLE_D - gap * (n_planks - 1))
    x = -TABLE_D / 2
    plank_x = []
    for i, w in enumerate(widths):
        cu = x + w / 2
        e0, e1 = (0.0, 0.0) if i == 2 else rng.uniform(0.0, 1.6, 2)          # ragged plank ends (plank 2 spans 160)
        v, f, kinds = plank("y", cu, TOP_Z0, -TABLE_W / 2 + e0, TABLE_W / 2 - e1, w, TOP_T, rng, segs=5, wobble=0.18,
                            end_skew=0.9)
        v[:, 0] = np.clip(v[:, 0], -TABLE_D / 2, TABLE_D / 2)
        parts.add(v, f, 0, plank_rgb(kinds, rng.uniform(0.78, 1.18), rng))
        plank_x.append((x, x + w))
        x += w + gap
    # ---- stone piers: a plinth course and three courses of chiselled blocks (alternating 2 / 3 per course)
    courses = [(PLINTH_H, 2, PLINTH_D, PLINTH_W)] + [((TOP_Z0 - PLINTH_H) / 4.0, n, PIER_D, PIER_W)
                                                     for n in (3, 2, 4, 3)]
    for sy in (-1, 1):
        cy = sy * PIER_Y
        z = 0.0
        for ci, (h, n, d, wy) in enumerate(courses):
            top_course = ci == len(courses) - 1
            joint = 0.5
            cuts = np.linspace(-d / 2, d / 2, n + 1)
            cuts[1:-1] += rng.uniform(-2.5, 2.5, n - 1)
            for k in range(n):
                x0, x1 = cuts[k] + (joint / 2 if k else 0.0), cuts[k + 1] - (joint / 2 if k < n - 1 else 0.0)
                v, f, chip = stone_block(((x0 + x1) / 2, cy, z + h / 2), (x1 - x0, wy, h), rng,
                                         yaw_deg=0.0 if top_course else 1.2,
                                         big_p=0.15 if top_course else 0.35,
                                         bulge=None if top_course else (0.25, 0.6))
                parts.add(v, f, 1, stone_rgb(v, f, chip, rng))
            z += h
        # dark core behind the joints
        v, f = sc.box((0.0, cy, TOP_Z0 / 2), (PIER_D - 5.0, PIER_W - 5.0, TOP_Z0 - 0.4))
        parts.add(v, f, 1, STONE * 0.45)
        # iron band round the pier head (the top course is unyawed so the band hugs it) + rivets
        v, f = rect_frame(0.0, cy, PIER_D / 2 + 0.15, PIER_W / 2 + 0.15, 0.6, *BAND_Z)
        parts.add(v, f, 2, IRON)
        zr = (BAND_Z[0] + BAND_Z[1]) / 2
        ox, oy = PIER_D / 2 + 0.75, PIER_W / 2 + 0.75
        for sx in (-1, 1):
            for yy in (-8.0, 8.0):
                v, f = pyramid((sx * ox, cy + yy, zr), (sx, 0, 0), 0.6, 0.45, spin=math.pi / 4)
                parts.add(v, f, 2, IRON * 1.25)
        for xx in (-22.0, 0.0, 22.0):
            for s2 in (-1, 1):
                v, f = pyramid((xx, cy + s2 * oy, zr), (0, s2, 0), 0.6, 0.45, spin=math.pi / 4)
                parts.add(v, f, 2, IRON * 1.25)
    # ---- wood apron front and back between the piers (top tucked 0.3 into the planks, ends 1 cm into the piers)
    apron_y = PIER_Y - PIER_W / 2 + 1.0                                  # 51
    for sx in (-1, 1):
        v, f, kinds = plank("y", 0.0, 0.0, -apron_y, apron_y, APRON_H, APRON_T, rng, segs=3, wobble=0.1, end_skew=0.3)
        # the plank function lays the board flat; stand it on edge: (u, s, v) -> x = APRON_X + v', z = 56 + u'
        u = v[:, 0].copy()
        t = v[:, 2].copy()
        v[:, 0] = sx * (APRON_X - APRON_T / 2 + t)
        v[:, 2] = (TOP_Z0 + 0.3 - APRON_H / 2) + u
        parts.add(v, f, 0, plank_rgb(kinds, rng.uniform(0.8, 0.95), rng))
        # iron brackets near the piers, two rivets each
        for sy in (-1, 1):
            face_x = sx * (APRON_X + APRON_T / 2)
            v, f = sc.box((face_x + sx * 0.15, sy * 45.5, TOP_Z0 - 4.0), (0.5, 5.0, 7.0))
            parts.add(v, f, 2, IRON)
            for zz in (TOP_Z0 - 6.2, TOP_Z0 - 1.8):
                v, f = pyramid((face_x + sx * 0.4, sy * 45.5, zz), (sx, 0, 0), 0.55, 0.4, spin=math.pi / 4)
                parts.add(v, f, 2, IRON * 1.25)
    # ---- lower shelf: three planks along Y between the piers
    shelf_y = PIER_Y - PIER_W / 2 + 1.5
    xs = [(-28.0, -9.8), (-9.4, 9.0), (9.4, 28.0)]
    for x0, x1 in xs:
        v, f, kinds = plank("y", (x0 + x1) / 2, 15.5, -shelf_y, shelf_y, x1 - x0, 2.5, rng, segs=3, wobble=0.15,
                            end_skew=0.3)
        parts.add(v, f, 0, plank_rgb(kinds, rng.uniform(0.78, 0.95), rng))
    obj, rgb = parts.build("PrepTable_Mars_SM", ("Wood", "Stone", "Iron"))
    fc.paint(obj, rgb, variation=0.05, seed=seed, cavity_darken=0.3)
    fc.smart_uv(obj)
    # sockets: the spec values are Unreal station-frame cm; Blender y is mirrored so the sidecar reads them as given
    for name, loc in PROPS["PrepTable"]["sockets"].items():
        add_socket(obj, name, (loc[0], -loc[1], loc[2]))
    # collision: the top slab + the pier boxes (plinth and upper courses)
    sc.box_ucx(obj, (0.0, 0.0, TOP_Z0 + TOP_T / 2), (TABLE_D, TABLE_W, TOP_T))
    for sy in (-1, 1):
        sc.box_ucx(obj, (0.0, sy * PIER_Y, PLINTH_H / 2), (PLINTH_D, PLINTH_W, PLINTH_H))
        sc.box_ucx(obj, (0.0, sy * PIER_Y, (PLINTH_H + TOP_Z0) / 2), (PIER_D, PIER_W, TOP_Z0 - PLINTH_H))
    extra = {"pivot": "floor contact, XY centre", "table_top_height_cm": TABLE_H, "table_top_thickness_cm": TOP_T,
             "nominal_size_cm": [TABLE_D, TABLE_W, TABLE_H],
             "width_note": "160 wide (the blockout table is 140): the extra 10 cm each side makes room for the input "
                           "bowl (SOCKET_Input, left) and the output tray (SOCKET_Output, right) beside the 90 cm board",
             "pier_centres_cm": [[0.0, -PIER_Y, 0.0], [0.0, PIER_Y, 0.0]],
             "pier_size_cm": [PIER_D, PIER_W, TOP_Z0], "plinth_size_cm": [PLINTH_D, PLINTH_W, PLINTH_H],
             "shelf_top_cm": 18.0, "knee_clearance_y_cm": [-(PIER_Y - PLINTH_W / 2), PIER_Y - PLINTH_W / 2]}
    return obj, extra


# ---------------------------------------------------------------- CuttingBoard
BOARD_XS = [-24.2, -16.6, -16.0, -15.4, -7.7, 0.0, 7.7, 15.4, 16.0, 16.6, 24.2]
BOARD_YS = [-44.2, -36.6, -36.0, -35.4, -16.35, -16.0, -15.65, 3.65, 4.0, 4.35, 16.65, 17.0, 17.35,
            35.4, 36.0, 36.6, 44.2]
# knife scores along X (the cleaver blade runs along X): y line -> {x line: depth}
BOARD_SCORES = {-16.0: {-7.7: 0.18, 0.0: SCORE_DEPTH}, 4.0: {0.0: 0.2, 7.7: SCORE_DEPTH},
                17.0: {-7.7: 0.15, 0.0: 0.22, 7.7: 0.12}}


def build_board(seed=8201):
    rng = np.random.default_rng(seed)
    hx, hy, T = BOARD_D / 2, BOARD_W / 2, BOARD_T
    xs, ys = BOARD_XS, BOARD_YS
    nx, ny = len(xs), len(ys)
    gx, gy = hx - GROOVE_INSET, hy - GROOVE_INSET                     # 16, 36: the groove centre lines
    grid = np.zeros((nx, ny, 3))
    for i, x in enumerate(xs):
        for j, y in enumerate(ys):
            z = T
            on_gx = abs(abs(x) - gx) < 1e-6 and abs(y) <= gy + 1e-6
            on_gy = abs(abs(y) - gy) < 1e-6 and abs(x) <= gx + 1e-6
            if on_gx or on_gy:
                z -= GROOVE_DEPTH
            for sy_, row in BOARD_SCORES.items():
                if abs(y - sy_) < 1e-6 and x in row:
                    z -= row[x]
            grid[i, j] = (x, y, z)
    # hand-cut chamfer: the top's outline is inset by a random 0.5..1.1 cm per vertex
    for i in range(nx):
        for j in range(ny):
            if i in (0, nx - 1):
                grid[i, j, 0] = math.copysign(hx - rng.uniform(0.5, 1.1), xs[i])
            if j in (0, ny - 1):
                grid[i, j, 1] = math.copysign(hy - rng.uniform(0.5, 1.1), ys[j])
    verts = list(grid.reshape(-1, 3))

    def gi(i, j):
        return i * ny + j

    faces, rgb = [], []
    # end-grain blocks: wide cells take a checker of two tones, the narrow groove / score cells their own stain
    wide_x = [i for i in range(nx - 1) if xs[i + 1] - xs[i] > 2.0]
    wide_y = [j for j in range(ny - 1) if ys[j + 1] - ys[j] > 2.0]
    for i in range(nx - 1):
        for j in range(ny - 1):
            faces.append([gi(i, j), gi(i + 1, j), gi(i + 1, j + 1), gi(i, j + 1)])
            zc = grid[[i, i + 1, i + 1, i], [j, j, j + 1, j + 1], 2]
            cx_, cy_ = 0.5 * (xs[i] + xs[i + 1]), 0.5 * (ys[j] + ys[j + 1])
            groove = (zc.min() < T - 1e-6) and (abs(abs(cx_) - gx) < 1.0 or abs(abs(cy_) - gy) < 1.0)
            if groove:
                rgb.append(lerp(WOOD, WOOD_DARK, 0.6))
            elif zc.min() < T - 1e-6:
                rgb.append(lerp(WOOD, WOOD_DARK, 0.35) * 0.92)                  # knife score
            elif i in wide_x and j in wide_y:
                rgb.append(lerp(WOOD, WOOD_DARK, rng.uniform(0.05, 0.3)) * rng.uniform(0.94, 1.08))
            else:
                rgb.append(lerp(WOOD, WOOD_DARK, 0.25))
    # boundary loop of the top grid, counter-clockwise from (-x, -y)
    loop = [(i, 0) for i in range(nx)] + [(nx - 1, j) for j in range(1, ny)] + \
           [(i, ny - 1) for i in range(nx - 2, -1, -1)] + [(0, j) for j in range(ny - 2, 0, -1)]
    side_top, side_bot = [], []
    for (i, j) in loop:
        x, y = grid[i, j, 0], grid[i, j, 1]
        corner = i in (0, nx - 1) and j in (0, ny - 1)
        ex = math.copysign(hx, xs[i]) if i in (0, nx - 1) else x
        ey = math.copysign(hy, ys[j]) if j in (0, ny - 1) else y
        if not corner:                                                         # hand-cut: edges dip in a little
            if i in (0, nx - 1):
                ex -= math.copysign(rng.uniform(0.0, 0.25), ex)
            else:
                ey -= math.copysign(rng.uniform(0.0, 0.25), ey)
        side_top.append(len(verts))
        verts.append((ex, ey, T - rng.uniform(0.45, 0.85)))
        side_bot.append(len(verts))
        verts.append((ex, ey, 0.0))
    m = len(loop)
    for k in range(m):
        k2 = (k + 1) % m
        a, b = gi(*loop[k]), gi(*loop[k2])
        faces.append([a, side_top[k], side_top[k2], b])
        rgb.append(WOOD * 1.12)                                                # worn chamfer
        faces.append([side_top[k], side_bot[k], side_bot[k2], side_top[k2]])
        mid = 0.5 * (np.asarray(verts[side_top[k]]) + np.asarray(verts[side_top[k2]]))
        end_grain = abs(abs(mid[1]) - hy) < 0.5 and abs(mid[0]) < hx - 0.3
        rgb.append(WOOD_DARK * 1.05 if end_grain else WOOD * 0.92)
    faces.append(side_bot[::-1])
    rgb.append(WOOD_DARK * 0.85)
    verts = np.array(verts)
    obj = sc.new_object("CuttingBoard_Mars_SM", verts, faces, ("Wood",), face_slots=[0] * len(faces))
    assert len(obj.data.polygons) == len(faces)
    fc.paint(obj, np.array(rgb), variation=0.05, seed=seed, cavity_darken=0.3)
    fc.smart_uv(obj)
    sc.box_ucx(obj, (0.0, 0.0, T / 2), (BOARD_D, BOARD_W, T))
    extra = {"pivot": "centre of the underside", "board_thickness_cm": T, "nominal_size_cm": [BOARD_D, BOARD_W, T],
             "top_z_cm": T, "flat_edge_band_cm": BOARD_FLAT_BAND, "juice_groove_inset_cm": GROOVE_INSET,
             "juice_groove_depth_cm": GROOVE_DEPTH, "knife_score_max_depth_cm": SCORE_DEPTH,
             "knife_score_y_cm": [-y for y in BOARD_SCORES]}                    # Unreal local y
    return obj, extra


def board_checks(obj):
    """The top's outer 8 cm band is flat at z = 4 (the chamfer ring excepted); groove / scores shallower than 0.4."""
    v = fc.verts_cm(obj)
    hx, hy = BOARD_D / 2, BOARD_W / 2
    top = v[v[:, 2] > BOARD_T - 0.42]
    inset = np.minimum(hx - np.abs(top[:, 0]), hy - np.abs(top[:, 1]))
    band = top[inset < BOARD_FLAT_BAND]
    fails = []
    if np.abs(band[:, 2] - BOARD_T).max() > 1e-4:
        fails.append("board: outer %.0f cm band not flat (min z %.3f)" % (BOARD_FLAT_BAND, band[:, 2].min()))
    deepest = BOARD_T - top[:, 2].min()
    if deepest >= 0.4:
        fails.append("board: groove / score depth %.2f >= 0.4" % deepest)
    lo, hi = v.min(axis=0), v.max(axis=0)
    if np.abs((hi - lo) - np.array([BOARD_D, BOARD_W, BOARD_T])).max() > 1e-3 or abs(lo[2]) > 1e-4:
        fails.append("board: bounds %s..%s" % (lo.round(3), hi.round(3)))
    print("board: top band (<%.0f cm in) %d verts all at z=%.3f; deepest cut %.2f cm; bounds %s" % (
        BOARD_FLAT_BAND, len(band), band[:, 2].min(), deepest, (hi - lo).round(3)))
    return fails


# ---------------------------------------------------------------- PrepBowl
# (r, z) from the base pole up the outside, over the rim, down the inside to the floor pole (pivot = floor centre)
BOWL_PROFILE = [
    (0.0, -3.0), (9.6, -3.0),                                              # 0-1  flat base
    (10.5, -2.4), (11.8, -1.4), (13.3, 0.2), (14.4, 2.4), (14.9, 5.0), (15.0, 7.3),   # 2-7 foot + belly
    (14.6, 8.5), (13.9, 9.0),                                              # 8-9  rim chamfer, rim top outer
    (12.5, 9.0),                                                           # 10   rim inner edge
    (12.35, 6.2), (12.0, 3.8), (11.3, 1.8), (10.2, 0.6),                   # 11-14 inner wall + fillet
    (8.5, 0.0), (0.0, 0.0)]                                                # 15-16 flat floor, pole
BOWL_OUTER_ROWS = range(1, 10)
BOWL_INNER_ROWS = range(10, 16)
B_BASE, B_OUTER, B_RIMCH, B_RIM, B_INNER, B_FLOOR = range(6)


def bowl_band(i):
    """Band tag of the faces between profile rows i and i + 1."""
    if i == 0:
        return B_BASE
    if i <= 6:
        return B_OUTER
    if i == 7:
        return B_RIMCH
    if i in (8, 9):
        return B_RIM
    if i <= 13:
        return B_INNER
    return B_FLOOR


def build_bowl(seed=8301):
    rng = np.random.default_rng(seed)
    seg = math.tau / BOWL_SEG
    col_shift = rng.uniform(-0.22, 0.22, BOWL_SEG) * seg                   # chisel columns lean (outside only)
    col_cut = rng.uniform(-0.9, 0.0, BOWL_SEG)                             # each column's chisel plane depth
    chips = rng.choice(BOWL_SEG, 3, replace=False)
    verts, rings, rows, cols = [], [], [], []
    for i, (r, z) in enumerate(BOWL_PROFILE):
        if r < 1e-6:
            rings.append([len(verts)])
            verts.append((0.0, 0.0, z))
            rows.append(i)
            cols.append(-1)
            continue
        ring = []
        for s in range(BOWL_SEG):
            a = s * seg
            rr, zz = r, z
            if i in BOWL_OUTER_ROWS:
                a += col_shift[s]
                if 2 <= i <= 7:
                    rr += col_cut[s] + rng.uniform(-0.3, 0.3)
                    zz += rng.uniform(-0.2, 0.2)
                if i in (8, 9) and s in chips:                              # rim chips
                    rr -= rng.uniform(0.25, 0.5)
                    zz -= rng.uniform(0.35, 0.7)
                rr = min(rr, 15.0)
            ring.append(len(verts))
            verts.append((rr * math.cos(a), rr * math.sin(a), zz))
            rows.append(i)
            cols.append(s)
        rings.append(ring)
    faces, bands, fcols = [], [], []
    for i, (ra, rb) in enumerate(zip(rings[:-1], rings[1:])):
        for s in range(BOWL_SEG):
            s2 = (s + 1) % BOWL_SEG
            if len(ra) == 1:
                faces.append([ra[0], rb[s], rb[s2]])
            elif len(rb) == 1:
                faces.append([ra[s], rb[0], ra[s2]])
            else:
                faces.append([ra[s], rb[s], rb[s2], ra[s2]])
            bands.append(bowl_band(i))
            fcols.append(s)
    v = np.array(verts)
    rows, cols = np.array(rows), np.array(cols)
    # colour: dark basalt outside with lighter chiselled facets, worn lighter rim and inside, warm chips
    obj = sc.new_object("PrepBowl_Mars_SM", v, faces, ("Stone",), face_slots=[0] * len(faces))
    assert len(obj.data.polygons) == len(faces)
    centres = fc.face_centers_cm(obj)
    patch = fc.smoothstep(0.35, 0.7, fc.fbm(centres * 0.2, seed))
    rgb = []
    for k, (b, s) in enumerate(zip(bands, fcols)):
        if b == B_BASE:
            rgb.append(STONE * 0.7)
        elif b == B_OUTER:
            rgb.append(lerp(STONE, STONE_LIGHT, 0.45 * patch[k]) * rng.uniform(0.9, 1.1))
        elif b in (B_RIMCH, B_RIM):
            c = lerp(STONE, STONE_LIGHT, 0.75)
            rgb.append(lerp(c, CHIP, 0.65) if s in chips or (s - 1) % BOWL_SEG in chips else c)
        elif b == B_INNER:
            rgb.append(lerp(STONE, STONE_LIGHT, 0.6) * rng.uniform(0.95, 1.04))
        else:
            rgb.append(lerp(STONE, STONE_LIGHT, 0.5))
    rgb = np.array(rgb)
    # chip faces keyed on the chip columns of the outer rim rows
    fc.paint(obj, rgb, variation=0.05, seed=seed, cavity_darken=0.35)
    fc.smart_uv(obj)
    for name, loc in PROPS["PrepBowl"]["sockets"].items():
        add_socket(obj, name, loc)
    line = bowl_support_line()
    pieces, pad = 12, math.radians(1.5)
    r_out, z0, z1 = 15.0, 0.0, 9.0
    for k in range(pieces):
        a0, a1 = math.tau * k / pieces - pad, math.tau * (k + 1) / pieces + pad
        h, am = 0.5 * (a1 - a0), 0.5 * (a0 + a1)
        pts = []
        for z in (z0, z1):
            ri = (line[0] + line[1] * z) / math.cos(h)              # the chord's nearest point sits on the support line
            for a in (a0, a1):
                pts.append((ri * math.cos(a), ri * math.sin(a), z))
                pts.append((r_out * math.cos(a), r_out * math.sin(a), z))
            pts.append((r_out * math.cos(am), r_out * math.sin(am), z))
        sc.add_ucx(obj, np.array(pts))
    # floor disc: a 12-gon frustum from the base up to the floor plane
    pts = []
    for z, r in ((-BOWL_FLOOR, 9.6), (0.0, 14.4)):
        for k in range(12):
            a = math.tau * k / 12
            pts.append((r * math.cos(a), r * math.sin(a), z))
    sc.add_ucx(obj, np.array(pts))
    # usable inner radius 1 cm above the floor (polygon flats, i.e. the smallest radius at that height)
    r1 = bowl_cavity_r(1.0) * math.cos(math.pi / BOWL_SEG)
    extra = {"pivot": "centre of the inner floor", "bowl_floor_cm": BOWL_FLOOR, "base_z_cm": -BOWL_FLOOR,
             "bowl_inner_radius_cm": round(r1, 2), "bowl_rim_inner_radius_cm": 12.5,
             "bowl_floor_flat_radius_cm": round(8.5 * math.cos(math.pi / BOWL_SEG), 2), "bowl_rim_z_cm": 9.0,
             "outer_diameter_cm": 30.0, "height_cm": 12.0,
             "ucx_wall_inner_line_cm": {"r_at_floor": round(line[0], 3), "dr_dz": round(line[1], 4)},
             "ucx_wedge_pad_deg": 1.5}
    return obj, extra


def bowl_cavity_r(z):
    """Inner circumradius of the bowl cavity at height z (piecewise linear over the inner profile rows)."""
    inner = sorted((BOWL_PROFILE[i][1], BOWL_PROFILE[i][0]) for i in BOWL_INNER_ROWS)
    zs, rs = zip(*inner)
    return float(np.interp(z, zs, rs))


def bowl_support_line():
    """(r0, dr/dz): the extension of an inner wall edge that stays at or outside every inner profile point (a
    supporting line of the convex cavity), the one with the smallest worst-case gap. The wedges' inner faces lie on it."""
    inner = [BOWL_PROFILE[i] for i in BOWL_INNER_ROWS]
    best = None
    for (ra, za), (rb, zb) in zip(inner[:-1], inner[1:]):
        if abs(za - zb) < 1e-6:
            continue
        k = (ra - rb) / (za - zb)
        r0 = ra - k * za
        gaps = [r0 + k * z - r for r, z in inner]
        if min(gaps) < -1e-6:
            continue
        worst = max(gaps)
        if best is None or worst < best[2]:
            best = (r0, k, worst)
    assert best is not None
    return best[0], best[1]


def bowl_checks(obj, items):
    """Every wedge's inner face lies at or outside the cavity (ray-cast against the real mesh), neighbours overlap,
    and the test items rest inside the cavity."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    fails = []
    v = fc.verts_cm(obj)
    tris = [list(p.vertices) for p in obj.data.polygons]
    bvh = BVHTree.FromPolygons([tuple(x) for x in v], tris)
    worst = 1e9
    wedges = [o for o in sc.children(obj, "UCX_")][:12]
    for piece in wedges:
        pv = np.array([x.co[:] for x in piece.data.vertices]) * 100.0
        for p in piece.data.polygons:
            n = np.array(p.normal[:])
            c = np.array(p.center[:]) * 100.0
            radial = np.array([c[0], c[1], 0.0])
            if np.dot(n, radial / (np.linalg.norm(radial) + 1e-9)) > -0.5:
                continue                                                   # not an inner face
            fv = pv[list(p.vertices)]
            samples = []
            for t in range(1, len(fv) - 1):                                # fan triangles, barycentric grid
                for a in np.linspace(0.0, 1.0, 9):
                    for b in np.linspace(0.0, 1.0 - a, 9):
                        samples.append(fv[0] * (1 - a - b) + fv[t] * a + fv[t + 1] * b)
            for q in samples:
                if q[2] < 0.05 or q[2] > 8.95:
                    continue
                d = np.array([q[0], q[1], 0.0])
                rq = np.linalg.norm(d)
                hit = bvh.ray_cast(Vector((0.0, 0.0, q[2])), Vector(tuple(d / rq)))
                if hit[0] is None:
                    continue
                worst = min(worst, rq - hit[3])
    print("bowl: wedge inner faces vs the cavity: min clearance %.3f cm (>= 0 means at or outside)" % worst)
    if worst < -1e-3:
        fails.append("bowl: a wedge's inner face is inside the cavity by %.3f cm" % -worst)
    # neighbours: angular overlap at the inner radius (no gap)
    line = bowl_support_line()
    overlap_cm = line[0] * 2 * math.radians(1.5)
    print("bowl: neighbouring wedges overlap by 3.0 deg (%.2f cm at the inner face), gap 0 (limit 2 cm)" % overlap_cm)
    # the floor disc meets the wedges: its top flats reach past the wedges' inner bottom edge
    if 14.4 * math.cos(math.pi / 12) < line[0]:
        fails.append("bowl: floor disc does not reach the wedges")
    for name, iv in items.items():
        for yaw in (0.0, 90.0):
            q = rot_z(iv, yaw, (0, 0, 0))
            r = np.hypot(q[:, 0], q[:, 1])
            cav = np.array([bowl_cavity_r(max(z, 0.0)) for z in q[:, 2]]) * math.cos(math.pi / BOWL_SEG)
            col = line[0] + line[1] * np.clip(q[:, 2], 0, 9)
            margin, cmargin = float((cav - r).min()), float((col - r).min())
            print("bowl: %s (yaw %.0f) on the floor: min clearance to the inner wall %.2f cm, to the collision %.2f cm,"
                  " top z %.2f (rim 9)" % (name, yaw, margin, cmargin, q[:, 2].max()))
            if margin < 0 or cmargin < 0 or q[:, 2].min() < -1e-3:
                fails.append("bowl: %s does not rest inside" % name)
    return fails


# ---------------------------------------------------------------- PrepTray
POST = 2.6
WALL_T = 1.6
ROPE_R = 0.32                      # rope tube "radius" (square section of half size ROPE_R / sqrt 2)
ROPE_OUT = ROPE_R * (1.0 + 0.5 ** 0.5)      # how far a lashing stands proud of the post faces
WALL_IN = 0.5                      # wall outer faces sit this far in from the post faces


def build_tray(seed=8401):
    rng = np.random.default_rng(seed)
    parts = Parts()
    hx, hy = TRAY_D / 2, TRAY_W / 2                                         # 13, 15
    zb, zt = -TRAY_FLOOR, TRAY_H - TRAY_FLOOR                               # -1.5, 6.5
    # the lashings are the outermost thing: the posts sit in so the rope's outside meets the 26 x 30 footprint
    post_out_x, post_out_y = hx - ROPE_OUT, hy - ROPE_OUT
    px, py = post_out_x - POST / 2, post_out_y - POST / 2
    wall_out_x, wall_out_y = post_out_x - WALL_IN, post_out_y - WALL_IN
    inner_x, inner_y = wall_out_x - WALL_T, wall_out_y - WALL_T
    # corner posts with pyramidal tops
    for sx in (-1, 1):
        for sy in (-1, 1):
            v, f = chamfer_post((sx * px, sy * py), (POST, POST), zb, zt, 0.5)
            parts.add(v, f, 0, [WOOD_DARK * 0.95] * 2 + [WOOD * 0.85] * 8)
    # walls: long walls along Y (x = +-), short walls along X (y = +-); ends buried in the posts
    wall_top = zt - 0.9
    for sx in (-1, 1):
        v, f, kinds = plank("y", 0.0, 0.0, -(py + 0.1), py + 0.1, wall_top - zb, WALL_T, rng, segs=2, wobble=0.08,
                            end_skew=0.0, chamfer=(0.2, 0.45))
        u, t = v[:, 0].copy(), v[:, 2].copy()
        v[:, 0] = sx * (wall_out_x - t)
        v[:, 2] = np.clip(zb + (wall_top - zb) / 2 + u, zb, wall_top)
        parts.add(v, f, 0, plank_rgb(kinds, rng.uniform(0.92, 1.08), rng))
    for sy in (-1, 1):
        v, f, kinds = plank("x", 0.0, 0.0, -(px + 0.1), px + 0.1, wall_top - zb - 0.2, WALL_T, rng, segs=2,
                            wobble=0.08, end_skew=0.0, chamfer=(0.2, 0.45))
        u, t = v[:, 1].copy(), v[:, 2].copy()
        v[:, 1] = sy * (wall_out_y - t)
        v[:, 2] = np.clip(zb + (wall_top - zb - 0.2) / 2 + u, zb, wall_top - 0.2)
        parts.add(v, f, 0, plank_rgb(kinds, rng.uniform(0.92, 1.08), rng))
    # floor: three planks along Y, top exactly at the pivot (z = 0), edges tucked under the walls; lifted 0.05 off
    # the base plane so their undersides are not coplanar with the walls'
    fx = np.linspace(-inner_x - 0.4, inner_x + 0.4, 4)
    for k in range(3):
        x0, x1 = fx[k] + (0.15 if k else 0.0), fx[k + 1] - (0.15 if k < 2 else 0.0)
        v, f, kinds = plank("y", (x0 + x1) / 2, zb + 0.05, -(inner_y + 0.6), inner_y + 0.6, x1 - x0,
                            TRAY_FLOOR - 0.05, rng, segs=2, wobble=0.06, end_skew=0.0, chamfer=(0.15, 0.3))
        parts.add(v, f, 0, plank_rgb(kinds, rng.uniform(0.8, 0.92), rng))
    # rope lashings: three turns hugging each corner post
    for sx in (-1, 1):
        for sy in (-1, 1):
            for z in (0.9, 2.5, 4.1):
                v, f = square_wrap((sx * px, sy * py), POST / 2, ROPE_R, z + rng.uniform(-0.15, 0.15))
                parts.add(v, f, 1, ROPE * rng.uniform(0.88, 1.08))
    obj, rgb = parts.build("PrepTray_Mars_SM", ("Wood", "Rope"))
    fc.paint(obj, rgb, variation=0.05, seed=seed, cavity_darken=0.3)
    fc.smart_uv(obj)
    for name, loc in PROPS["PrepTray"]["sockets"].items():
        add_socket(obj, name, loc)
    sc.box_ucx(obj, (0.0, 0.0, zb / 2), (TRAY_D, TRAY_W, TRAY_FLOOR))
    wall_x0 = inner_x
    for sx in (-1, 1):
        sc.box_ucx(obj, (sx * (wall_x0 + hx) / 2, 0.0, (zb + zt) / 2), (hx - wall_x0, TRAY_W, zt - zb))
    for sy in (-1, 1):
        sc.box_ucx(obj, (0.0, sy * (inner_y + hy) / 2, (zb + zt) / 2), (TRAY_D, hy - inner_y, zt - zb))
    extra = {"pivot": "centre of the inner floor", "tray_floor_cm": TRAY_FLOOR, "base_z_cm": -TRAY_FLOOR,
             "tray_inner_size_cm": [round(2 * inner_x, 2), round(2 * inner_y, 2)], "tray_wall_top_cm": round(wall_top, 2),
             "nominal_size_cm": [TRAY_D, TRAY_W, TRAY_H]}
    return obj, extra


# ---------------------------------------------------------------- layout
def station_layout(extras):
    """Station-frame placements in UNREAL cm (X forward from the operator, Y right, Z up; table centre on the floor
    at the origin)."""
    sock = {k: list(v) for k, v in PROPS["PrepTable"]["sockets"].items()}
    bowl_z = TABLE_H + BOWL_FLOOR
    tray_z = TABLE_H + TRAY_FLOOR
    return {
        "station": STATION,
        "frame": "Unreal station-local cm: X forward (operator at -X looking +X), Y right, Z up; the table's floor "
                 "centre is the origin. Blender builds mirror Y (Unreal y = -Blender y).",
        "table": {"mesh": "PrepTable_Mars_SM", "location_cm": [0.0, 0.0, 0.0], "rotation_deg": [0.0, 0.0, 0.0],
                  "size_cm": [TABLE_D, TABLE_W, TABLE_H], "top_z_cm": TABLE_H,
                  "width_note": extras["PrepTable"]["width_note"]},
        "board": {"mesh": "CuttingBoard_Mars_SM", "socket": "Board", "location_cm": sock["Board"],
                  "rotation_deg": [0.0, 0.0, 0.0], "top_z_cm": TABLE_H + BOARD_T,
                  "note": "swaps 1:1 with the blockout board (BoardX -5, 50 x 90 x 4, pivot at the underside centre); "
                          "the left glove's grip (-5, -39, 76.5) is over the flat outer band"},
        "input_bowl": {"mesh": "PrepBowl_Mars_SM", "socket": "Input", "side": "left (-Y)",
                       "socket_location_cm": sock["Input"],
                       "location_cm": [sock["Input"][0], sock["Input"][1], bowl_z], "rotation_deg": [0.0, 0.0, 0.0],
                       "pivot_above_base_cm": BOWL_FLOOR,
                       "note": "the pivot is the inner floor: placement z = table top 70 + bowl floor 3 = %.1f" % bowl_z},
        "output_tray": {"mesh": "PrepTray_Mars_SM", "socket": "Output", "side": "right (+Y)",
                        "socket_location_cm": sock["Output"],
                        "location_cm": [sock["Output"][0], sock["Output"][1], tray_z], "rotation_deg": [0.0, 0.0, 0.0],
                        "pivot_above_base_cm": TRAY_FLOOR,
                        "note": "the pivot is the inner floor: placement z = table top 70 + tray floor 1.5 = %.1f" % tray_z},
        "stove_socket_cm": sock["Stove"],
        "clearances_cm": {"board_to_bowl": round(abs(sock["Input"][1]) - 15.0 - BOARD_W / 2, 2),
                          "board_to_tray": round(abs(sock["Output"][1]) - TRAY_W / 2 - BOARD_W / 2, 2),
                          "bowl_to_table_edge": round(TABLE_W / 2 - abs(sock["Input"][1]) - 15.0, 2),
                          "tray_to_table_edge": round(TABLE_W / 2 - abs(sock["Output"][1]) - TRAY_W / 2, 2)},
        "blockout": {"table_size_cm": [80.0, 140.0, 70.0],
                     "change": "TableWidth 140 -> 160 in Mars_DicingStation_EntityScript (probe extent follows)"},
    }


# ---------------------------------------------------------------- review renders
def import_food(name):
    """Import a food FBX, return its vertices in cm about its pivot (world space after the importer's axis fix) plus
    corner colours, then delete it."""
    path = os.path.join(FOOD_EXPORT_DIR, name + ".fbx")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    mesh_obj = next(o for o in new if o.type == "MESH" and not o.name.startswith("UCX_"))
    out = mesh_payload(mesh_obj)
    for o in new:
        data = o.data if o.type == "MESH" else None
        bpy.data.objects.remove(o, do_unlink=True)
        if data is not None and data.users == 0:
            bpy.data.meshes.remove(data)
    return out


def mesh_payload(obj):
    """World-space verts (cm), polygons and corner colours of a mesh object."""
    me = obj.data
    mw = np.array(obj.matrix_world)
    v = fc.verts_cm(obj) * 0.01
    v = (np.c_[v, np.ones(len(v))] @ mw.T)[:, :3] * 100.0
    faces = [list(p.vertices) for p in me.polygons]
    attr = me.color_attributes.get("Col") or (me.color_attributes[0] if len(me.color_attributes) else None)
    n_loops = len(me.loops)
    if attr is None:
        cols = np.full((n_loops, 4), 0.5)
    else:
        raw = np.empty(len(attr.data) * 4)
        attr.data.foreach_get("color", raw)
        raw = raw.reshape(-1, 4)
        if attr.domain == "CORNER":
            cols = raw
        else:
            lv = np.empty(n_loops, dtype=np.int64)
            me.loops.foreach_get("vertex_index", lv)
            cols = raw[lv]
    return {"verts": v, "faces": faces, "cols": cols}


def assembled_object(placements):
    """One temporary mesh of payloads placed at (location cm, yaw deg) -> object (flat, Col corner colours)."""
    verts, faces, cols, base = [], [], [], 0
    for pay, loc, yaw in placements:
        v = rot_z(pay["verts"], yaw, (0, 0, 0)) + np.asarray(loc, float)
        verts.append(v)
        faces += [[base + i for i in f] for f in pay["faces"]]
        cols.append(pay["cols"])
        base += len(v)
    me = bpy.data.meshes.new("_Assembly")
    me.from_pydata((np.concatenate(verts) * 0.01).tolist(), [], faces)
    me.update()
    me.polygons.foreach_set("use_smooth", [False] * len(me.polygons))
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    attr.data.foreach_set("color", np.concatenate(cols).ravel())
    me.color_attributes.active_color_index = 0
    me.color_attributes.render_color_index = 0
    obj = bpy.data.objects.new("_Assembly", me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


REVIEW_SIZE = (1800, 1000)          # taller than the helper's default 700 so the iso view is not cropped


def render_sheets(objs, food):
    """One sheet per prop (table, board and tray turned 90 deg so the "front" view is the operator's view) and the
    assembled station (also turned, so the input bowl shows on the left as the operator sees it)."""
    sheets = []
    turn = {"PrepTable_Mars_SM": 90.0, "CuttingBoard_Mars_SM": 90.0, "PrepTray_Mars_SM": 90.0}
    by = {o.name: mesh_payload(o) for o in objs}
    for obj in objs:
        tmp = framed_copy([(by[obj.name], (0, 0, 0), turn.get(obj.name, 0.0))])
        try:
            sheets.append(fc.review_sheet([tmp], obj.name.replace("_Mars_SM", ""), views=spec.REVIEW_VIEWS,
                                          size=REVIEW_SIZE))
        finally:
            remove_object(tmp)
    lay = station_layout({"PrepTable": {"width_note": ""}})

    def bl(p):                                     # Unreal station cm -> Blender cm
        return (p[0], -p[1], p[2])

    placements = [(by["PrepTable_Mars_SM"], (0, 0, 0), 0.0),
                  (by["CuttingBoard_Mars_SM"], bl(lay["board"]["location_cm"]), 0.0),
                  (by["PrepBowl_Mars_SM"], bl(lay["input_bowl"]["location_cm"]), 0.0),
                  (by["PrepTray_Mars_SM"], bl(lay["output_tray"]["location_cm"]), 0.0)]
    if "HerbPile_Mars_SM" in food:                 # scale reference only: on the board top at the pile node (yaw 90)
        placements.append((food["HerbPile_Mars_SM"], (0.0, 0.0, TABLE_H + BOARD_T), -90.0))
    if "Mushroom_Mars_SM" in food:                 # in the input bowl, on its floor
        placements.append((food["Mushroom_Mars_SM"], bl(lay["input_bowl"]["location_cm"]), 0.0))
    turned = [(p, rot_z(np.asarray(loc, float)[None], 90.0, (0, 0, 0))[0], yaw + 90.0) for p, loc, yaw in placements]
    asm = framed_copy(turned)
    try:
        sheets.append(fc.review_sheet([asm], "CuttingStation_Assembled", views=spec.REVIEW_VIEWS,
                                      size=REVIEW_SIZE))
    finally:
        remove_object(asm)
    return sheets


def framed_copy(placements):
    """A temporary render copy, lifted so its middle sits where fc.review_sheet aims (0.45 x its longest extent above
    z = 0): the helper frames on the longest extent, which leaves flat props low in the frame (there is no ground in
    the shot, so the lift is invisible)."""
    obj = assembled_object(placements)
    v = fc.verts_cm(obj)
    lo, hi = v.min(axis=0), v.max(axis=0)
    v[:, 2] += 0.45 * float((hi - lo).max()) - 0.5 * (lo[2] + hi[2])
    fc.set_verts_cm(obj, v)
    return obj


def remove_object(obj):
    me = obj.data
    bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.meshes.remove(me)


# ---------------------------------------------------------------- verification
def verify(objs, extras):
    fails = []
    print("\n%-22s %5s %6s %-26s %-10s %s" % ("mesh", "tris", "max", "size (x, y, z) cm", "min z", "ucx / sockets"))
    for obj in objs:
        key = obj.name.replace("_Mars_SM", "")
        tris = fc.tri_count(obj)
        lo, hi = fc.bounds_cm(obj)
        tmax = PROPS[key]["tris_max"]
        n_ucx = len(sc.children(obj, "UCX_"))
        socks = sorted(socket_name(e) for e in sc.children(obj, "SOCKET_"))
        print("%-22s %5d %6d %-26s %-10.3f %d / %s" % (key, tris, tmax, str(tuple((hi - lo).round(2))), lo[2], n_ucx,
                                                       socks))
        if tris > tmax:
            fails.append("%s tris %d > %d" % (key, tris, tmax))
        if not fc._is_flat(obj.data):
            fails.append("%s not flat" % key)
        if fc.spec.COLOR_ATTR not in obj.data.color_attributes:
            fails.append("%s missing Col" % key)
        if [u.name for u in obj.data.uv_layers] != ["UVMap"]:
            fails.append("%s uv layers" % key)
        probs = sc.check_ucx(obj)
        if probs:
            fails.append("%s ucx %s" % (key, probs))
        want = set("SOCKET_" + s for s in PROPS[key].get("sockets", {}) or {})
        if want != set(socks):
            fails.append("%s sockets %s != %s" % (key, socks, sorted(want)))
    t = next(o for o in objs if o.name.startswith("PrepTable"))
    lo, hi = fc.bounds_cm(t)
    if np.abs(hi - lo - np.array([TABLE_D, TABLE_W, TABLE_H])).max() > 0.05 or abs(lo[2]) > 1e-4:
        fails.append("table bounds %s..%s" % (lo.round(2), hi.round(2)))
    top_band = fc.verts_cm(t)
    print("table: top z max %.4f, bounds x %.2f..%.2f y %.2f..%.2f" % (top_band[:, 2].max(), lo[0], hi[0], lo[1], hi[1]))
    tr = next(o for o in objs if o.name.startswith("PrepTray"))
    lo, hi = fc.bounds_cm(tr)
    if np.abs(hi - lo - np.array([TRAY_D, TRAY_W, TRAY_H])).max() > 0.15 or abs(lo[2] + TRAY_FLOOR) > 1e-3:
        fails.append("tray bounds %s..%s" % (lo.round(2), hi.round(2)))
    bw = next(o for o in objs if o.name.startswith("PrepBowl"))
    lo, hi = fc.bounds_cm(bw)
    print("bowl: bounds %s..%s (outer diameter %.2f, height %.2f)" % (lo.round(2), hi.round(2), max(hi[0] - lo[0], hi[1] - lo[1]),
                                                                       hi[2] - lo[2]))
    if max(hi[0] - lo[0], hi[1] - lo[1]) > 30.0 + 1e-3 or abs(hi[2] - 9.0) > 1e-3 or abs(lo[2] + BOWL_FLOOR) > 1e-3:
        fails.append("bowl bounds %s..%s" % (lo.round(2), hi.round(2)))
    print("tray: bounds %s..%s" % tuple(b.round(2) for b in fc.bounds_cm(tr)))
    return fails


def reimport_fresh(paths, expected):
    fails = []
    for path in paths:
        cmd = [bpy.app.binary_path, "-b", "--factory-startup", "--python", os.path.abspath(__file__), "--",
               "--reimport", path]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        line = next((ln for ln in res.stdout.splitlines() if ln.startswith("REIMPORT_JSON ")), None)
        if line is None:
            fails.append("reimport failed for %s" % path)
            print(res.stdout[-2000:], res.stderr[-2000:])
            continue
        rep = json.loads(line[len("REIMPORT_JSON "):])
        name = os.path.splitext(os.path.basename(path))[0]
        want = expected[name]
        meshes = [r for r in rep["meshes"] if not r["name"].startswith("UCX_")]
        ucx = [r for r in rep["meshes"] if r["name"].startswith("UCX_")]
        problems = []
        if len(meshes) != 1:
            problems.append("%d render meshes" % len(meshes))
        else:
            r = meshes[0]
            if r["tris"] != want["tris"]:
                problems.append("tris %d != %d" % (r["tris"], want["tris"]))
            if r["uv_layers"] != ["UVMap"]:
                problems.append("uv %s" % r["uv_layers"])
            if "Col" not in r["colors"]:
                problems.append("colors %s" % r["colors"])
            if not r["flat"]:
                problems.append("not flat")
        if len(ucx) != want["ucx"]:
            problems.append("ucx %d != %d" % (len(ucx), want["ucx"]))
        if sorted(rep["sockets"]) != sorted(want["sockets"]):
            problems.append("sockets %s" % rep["sockets"])
        m = meshes[0] if meshes else {}
        print("REIMPORT %-22s tris %s uv %s colors %s flat %s ucx %d sockets %s -> %s" % (
            name, m.get("tris"), m.get("uv_layers"), m.get("colors"), m.get("flat"), len(ucx), rep["sockets"],
            "ok" if not problems else "FAIL " + "; ".join(problems)))
        if problems:
            fails.append("%s reimport: %s" % (name, "; ".join(problems)))
    return fails


def _reimport_child(path):
    before = set(bpy.data.objects)
    meshes = fc.reimport_check(path)
    sockets = [o.name for o in bpy.data.objects if o not in before and o.type == "EMPTY" and o.name.startswith("SOCKET_")]
    print("REIMPORT_JSON " + json.dumps({"meshes": meshes, "sockets": sockets}))


# ---------------------------------------------------------------- main
def _organise_for_save(objs):
    scene = bpy.context.scene
    for obj in objs:
        cname = obj.name.replace("_Mars_SM", "")
        coll = bpy.data.collections.get(cname) or bpy.data.collections.new(cname)
        if coll.name not in scene.collection.children:
            scene.collection.children.link(coll)
        for o in [obj] + sc.children(obj, "SOCKET_") + sc.children(obj, "UCX_"):
            for c in list(o.users_collection):
                c.objects.unlink(o)
            coll.objects.link(o)
    for m in list(bpy.data.materials):
        if m.users == 0:
            bpy.data.materials.remove(m)


def main():
    args = fc.cli_args({"export": False, "save": False, "sheets": False, "reimport": ""})
    if args["reimport"]:
        _reimport_child(args["reimport"])
        return
    t0 = time.time()
    fc.ensure_dirs()
    fc.clear_scene()
    bpy.context.scene.view_settings.view_transform = "Standard"

    table, table_x = build_table()
    board, board_x = build_board()
    bowl, bowl_x = build_bowl()
    tray, tray_x = build_tray()
    objs = [table, board, bowl, tray]
    extras = {"PrepTable": table_x, "CuttingBoard": board_x, "PrepBowl": bowl_x, "PrepTray": tray_x}
    print("built in %.1fs" % (time.time() - t0))

    fails = verify(objs, extras)
    fails += board_checks(board)
    food = {}
    for name in ("HerbPile_Mars_SM", "Mushroom_Mars_SM"):
        if os.path.exists(os.path.join(FOOD_EXPORT_DIR, name + ".fbx")):
            food[name] = import_food(name)
    items = {k: v["verts"] for k, v in food.items()}
    for k, iv in items.items():
        print("food %s: size %s min z %.3f" % (k, np.ptp(iv, axis=0).round(2), iv[:, 2].min()))
    fails += bowl_checks(bowl, items)

    exported = []
    if args["export"]:
        for obj in objs:
            key = obj.name.replace("_Mars_SM", "")
            extra = dict(extras[key], station=STATION, spec_key=key)
            claim_socket_names(obj)
            path = sc.export_fbx(obj, extra=extra)
            meta = json.load(open(os.path.splitext(path)[0] + ".json"))
            if meta["ucx_problems"]:
                fails.append("%s ucx_problems %s" % (key, meta["ucx_problems"]))
            exported.append((path, obj))
        lay = station_layout(extras)
        print("layout ->", sc.layout_json("CuttingStation_Layout", lay))
    sheets = []
    if args["sheets"]:
        sheets = render_sheets(objs, food)
    if args["save"]:
        _organise_for_save(objs)
        sc.save_blend(STATION)
        print("saved", os.path.join(spec.BLEND_DIR, spec.STATIONS[STATION][0]))
    if exported:
        expected = {o.name: {"tris": fc.tri_count(o), "ucx": len(sc.children(o, "UCX_")),
                             "sockets": [socket_name(e) for e in sc.children(o, "SOCKET_")]} for _, o in exported}
        fails += reimport_fresh([p for p, _ in exported], expected)
        print("\nsidecars:")
        for p, _ in exported:
            meta = json.load(open(os.path.splitext(p)[0] + ".json"))
            print("  %-22s tris %4d  bounds %s..%s  ucx %d  sockets %s" % (
                meta["name"], meta["tris"], [round(x, 2) for x in meta["bounds_min_cm"]],
                [round(x, 2) for x in meta["bounds_max_cm"]], meta["ucx_pieces"],
                {k: s["location_cm"] for k, s in meta["sockets"].items()}))
    print("\nsheets:", *sheets, sep="\n  ")
    print("total %.1fs" % (time.time() - t0))
    if fails:
        print("STATION_CUTTING_FAIL", *fails, sep="\n  ")
    else:
        print("STATION_CUTTING_OK")


main()
