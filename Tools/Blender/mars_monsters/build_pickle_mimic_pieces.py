"""Mars pickle mimic pieces: the rigid static meshes the pickle-jar mimic is drawn with, built procedurally (numpy
geometry, fixed seeds) as a re-runnable headless Blender 5.2 build, the way build_centipede_pieces.py builds the centipede.

The look is Stephen's concept (2026-10-31): a faceted low-poly glass pickle jar on four blocky wooden legs, two wooden
hoops with blocky clasps round it, a mouth like a treasure chest's (2026-11-02, Stephen: "the top be a band with the teeth
on it"): a solid wooden jaw band round the jar's top with square bone teeth along it and a deep hinged wooden lid whose
skirt meets the band, its own teeth hanging inside, so that shut the eyes and the inside of the mouth are hidden; a black
eye cavity with two glowing oval eyes inside the band that rises when the lid lifts, a red cloth bow tied at each side. The brine and the pickles in it are NOT modelled: the jar's liquid is a plain cylinder that wears the pickle
brine shader's Pickle Jar instance (mars_potion_ue / mars_potion_hlsl), which traces the pickles inside it. A pre-fractured
copy of the glass (ten shards that fit together exactly) is the death's shatter.

Every piece is authored in UNREAL cm in its own frame (+X the face's direction, +Y right, +Z up) and converted on the way
into Blender (metres, Blender local = (x, -y, z) / 100), so the FBX lands in Unreal in the contract's numbers. The body
frame's origin is the jar's base centre; standing, it rides CLEARANCE over the ground. Pieces (Unreal cm; the numbers are
the gameplay rig's contract, utils_pickle_mimic):

  PickleMimic_Glass_Mars_SM      the jar: a 12-sided glass shell (a facet faces +X), base z 0, wall r 30 from z 3 to 50, a
                                 shoulder up to its open top at z 55 (inside the jaw band), 1.6 thick; SOCKET_LiquidCentre.
  PickleMimic_Liquid_Mars_SM     the brine: a 32-sided cylinder r LIQUID_RADIUS, half height LIQUID_HALF, pivot at its
                                 middle (LIQUID_CENTRE over the base); wears PickleMimicBrine_Mars_MI.
  PickleMimic_Frame_Mars_SM      the wooden hoops (z 7..16 and 40..49) with their clasps and the hinge knuckles at the
                                 back; SOCKET_Hinge.
  PickleMimic_Mouth_Mars_SM      the lower jaw: the opaque wooden band round the jar's top (z BAND_Z0..BAND_Z1, red inside)
                                 with its clasps and the hasp's staple, the gum floor over the glass's open top, a gum
                                 ledge and the seven big bevelled teeth standing on it along the band.
  PickleMimic_Face_Mars_SM       the black eye cavity (a dome, pivot at its base centre, FACE_BASE over the jar base) and
                                 the two oval eyes on its front (slot PickleMimicEye: the glow); it rises FACE_RISE when the
                                 lid is wide open.
  PickleMimic_Lid_Mars_SM        pivot at the hinge (HINGE), +X toward the front: the upper jaw, a deep wooden cap (the
                                 band's radius about (LID_CENTRE_X, 0)) whose skirt meets the band at the seam (body z
                                 BAND_Z1) when shut, red inside, its knob, clasps, hinge leaf and the hasp hanging over the
                                 seam at the front, and six big bevelled teeth hanging from its ceiling between the band's.
  PickleMimic_Bow_Mars_SM        the red bow on the jar's right side at the top hoop (the left one is the same mesh turned
                                 180 degrees about Z).
  There are no legs (Stephen 2026-10-31: "it just needs to be the foot that can be magically floating and moving up and
  down"): four feet float round the jar's base, each where the gait puts its foot point, planted or lifting.
  PickleMimic_Foot_Mars_SM       pivot at the sole's centre (the foot point), +Z up, +X forward: the concept's block leg as
                                 a floating foot, a tapered block FOOT_HEIGHT tall, its sole notched into two toes.
  PickleMimic_Shard00..09_Mars_SM the glass in pieces, each authored in the jar's frame (pivot at the jar's base centre), so
                                 all ten at the jar's transform are the jar; Shard00 is the base.

Material slots (Unreal binds <Slot>_Mars_MI): PickleMimicGlass, PickleMimicBrine, PickleMimicWood, PickleMimicWoodDark,
PickleMimicBone, PickleMimicGum, PickleMimicVoid, PickleMimicEye, PickleMimicCloth. Flat shading everywhere, light
deterministic jitter on wood and teeth, glass crisp. UV0 "UVMap" is a cube projection (the masters read none).

Run:
  blender -b --factory-startup --python build_pickle_mimic_pieces.py -- [--export] [--sheets] [--save]
    --export   one FBX (+ SOCKET_ empties) and a .json sidecar per piece into EXPORT_DIR, the rest layout JSON, then a
               re-import check of every FBX
    --sheets   review renders into REVIEW_DIR: every piece alone (front / side / top / iso), the assembled mimic standing,
               disguised and biting (workbench layout sheet) and EEVEE hero renders (3/4 bite, disguise, shatter)
    --save     BLEND_FILE (the pieces at the origin + the posed previews)
Prints PICKLE_MIMIC_PIECES_OK when every check passed (PICKLE_MIMIC_PIECES_FAIL + the reasons otherwise).
"""
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix

# ---------------------------------------------------------------- locations
SOURCE_DIR = r"D:\Repo\Content\Monsters\PickleMimic"        # off-repo art, like D:\Repo\Content\Monsters\Centipede
EXPORT_DIR = SOURCE_DIR + r"\export"
REVIEW_DIR = EXPORT_DIR + r"\review"
BLEND_FILE = SOURCE_DIR + r"\PickleMimic_Pieces.blend"
UE_MESH_FOLDER = "/Game/Mars/Gameplay/Monsters/PickleMimic/Meshes"
BUILDER = "Tools/Blender/mars_monsters/build_pickle_mimic_pieces.py"

# ---------------------------------------------------------------- palette (linear rgb, roughness, metallic, emissive)
# sampled from the concept (sRGB picks converted to linear); mars_pickle_mimic_ue.py carries the same numbers. The glass
# and the brine only preview here: Unreal gives the glass its own translucent master and the brine the brine shader.
PALETTE = {
    "PickleMimicGlass":    ((0.78, 0.90, 0.84), 0.05, 0.0, 0.0),
    "PickleMimicBrine":    ((0.42, 0.58, 0.10), 0.20, 0.0, 0.0),
    "PickleMimicWood":     ((0.46, 0.16, 0.045), 0.80, 0.0, 0.0),
    "PickleMimicWoodDark": ((0.25, 0.085, 0.025), 0.80, 0.0, 0.0),
    "PickleMimicBone":     ((0.87, 0.76, 0.60), 0.55, 0.0, 0.0),
    "PickleMimicGum":      ((0.26, 0.014, 0.018), 0.60, 0.0, 0.0),
    "PickleMimicVoid":     ((0.004, 0.003, 0.003), 1.00, 0.0, 0.0),
    "PickleMimicEye":      ((1.00, 0.86, 0.45), 0.40, 0.0, 5.0),
    "PickleMimicCloth":    ((0.60, 0.016, 0.022), 0.85, 0.0, 0.0),
}
SLOTS = tuple(PALETTE)
PREVIEW_ALPHA = {"PickleMimicGlass": 0.18, "PickleMimicBrine": 0.55}

SHARD_COUNT = 10
SHARDS = tuple("Shard%02d" % k for k in range(SHARD_COUNT))
PIECES = ("Glass", "Liquid", "Frame", "Mouth", "Face", "Lid", "Bow", "Foot") + SHARDS
TRIS_MAX = {"Glass": 600, "Liquid": 300, "Frame": 2500, "Mouth": 1200, "Face": 600, "Lid": 2000, "Bow": 400,
            "Foot": 300}
TRIS_MAX.update({s: 1200 for s in SHARDS})
SEEDS = {"Glass": 8101, "Liquid": 8151, "Frame": 8201, "Mouth": 8301, "Face": 8401, "Lid": 8501, "Bow": 8601,
         "Foot": 8701}
SEEDS.update({s: 8901 for s in SHARDS})          # one fracture for all ten (build_shards runs once)

# ---------------------------------------------------------------- the body (Unreal cm; origin = the jar's base centre)
CLEARANCE = 30.0                        # the jar's base over the ground standing (SurfaceMotion clearance)
TUCK_DROP = 19.0                        # disguised: the walker body sinks this far (the base 11 over the ground)
JAR_SIDES = 12
JAR_PHASE = math.pi / JAR_SIDES         # a facet centred on +X (the face)
GLASS_T = 1.6
# the glass profile (r = the 12-gon's circumradius, z): outside from the base up to the lip, inside from the lip down
GLASS_TOP = 55.0                        # the glass's open top, hidden inside the jaw band
GLASS_OUT = [(27.0, 0.0), (30.0, 3.0), (30.0, 50.0), (28.5, 53.0), (27.5, GLASS_TOP)]
GLASS_IN = [(25.9, GLASS_TOP), (26.9, 52.6), (28.4, 50.0), (28.4, 3.0), (26.6, 2.0)]
# the wall's rows for the shards (outer, inner), from the foot's top (z 3) to the glass's top
WALL_ROWS = [((30.0, 3.0), (28.4, 3.0))] + \
    [((30.0, 3.0 + 47.0 * k / 6.0), (28.4, 3.0 + 47.0 * k / 6.0)) for k in range(1, 7)] + \
    [((28.5, 53.0), (26.9, 52.6)), ((27.5, GLASS_TOP), (25.9, GLASS_TOP))]
WALL_COLUMNS = JAR_SIDES * 4            # each facet split in four (the splits lie on the flat facet)
# the brine cylinder: inside the glass's inner apothem (28.4 cos 15 = 27.4), floor to under the shoulder
LIQUID_RADIUS = 27.0
LIQUID_FLOOR, LIQUID_TOP = 2.2, 49.0
LIQUID_HALF = 0.5 * (LIQUID_TOP - LIQUID_FLOOR)
LIQUID_CENTRE = 0.5 * (LIQUID_TOP + LIQUID_FLOOR)
BRINE_SURFACE = 45.0                    # the concept's fill: brine nearly up to the top hoop
HOOPS = ((7.0, 16.0), (40.0, 49.0))
HOOP_IN, HOOP_OUT = 30.2, 32.6
# the mouth, a chest's: the lower jaw is a wooden band round the jar's top (12-gon circumradii, like the hoops), its
# inside lined red, a gum floor over the glass's open top and a gum ledge the band's teeth stand on; the lid is a deep cap
# of the same radius whose skirt sits on the band (the seam at BAND_Z1), red inside, its teeth hanging from its ceiling
BAND_Z0, BAND_Z1 = 51.0, 64.0
BAND_IN, BAND_OUT = 30.4, 32.6
MOUTH_FLOOR = (55.2, 56.4)              # the gum floor's underside and top (over the glass's top, z 55)
LEDGE = (21.0, 58.0)                    # the teeth's gum ledge: inner radius and top
LID_SKIRT = 8.0                         # the lid's skirt, closed body z BAND_Z1 .. + LID_SKIRT
LID_CEILING = 7.5                       # the lid's inside ceiling over the seam (lid frame z)
LID_CROWN = 12.4                        # the lid's top over the seam
TOOTH_RING = 25.5
TOOTH_HALF = (3.4, 3.6, 4.0)            # radial, tangential, vertical: big bevelled cubes like the concept's
TOOTH_BEVEL = 1.1
RIM_TEETH_DEG = [-135.0 + 45.0 * k for k in range(7)]
LID_TEETH_DEG = [-112.5 + 45.0 * k for k in range(6)]
HINGE = np.array([-33.4, 0.0, BAND_Z1])  # just behind the band's back facet (apothem 31.5), on the seam
LID_CENTRE_X = 33.4                     # the lid's centre in its own frame (over the jar's axis when closed)
LID_RADIUS = BAND_OUT
LID_OPEN_DEG = 80.0                     # LidOpen 1
FACE_BASE = MOUTH_FLOOR[1]              # the eye dome stands on the mouth's floor; its eyes sit just over the band's rim
FACE_RISE = 10.0
FACE_EYE_Z = 9.0                        # the eyes' centres over the dome's base (body z 65.4: just over the band's rim)
# the feet, front-right built (the others mirror X and/or Y): on the diagonal just outside the jar's base, on the ground,
# each turned to face out along its diagonal (its +X)
LEG_FOOT = np.array([28.28, 28.28, -CLEARANCE])
FOOT_HEIGHT = 16.0
LEGS = (("FR", 1.0, 1.0), ("FL", 1.0, -1.0), ("BR", -1.0, 1.0), ("BL", -1.0, -1.0))

MIRROR = np.diag([1.0, -1.0, 1.0])


def piece_name(part):
    return "PickleMimic_%s_Mars_SM" % part


# ---------------------------------------------------------------- CLI / scene
def cli_args(defaults):
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = dict(defaults)
    for a in argv:
        out[a.lstrip("-")] = True
    return out


def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.cameras, bpy.data.lights):
        for d in list(coll):
            if d.users == 0:
                coll.remove(d)


def _n(v):
    v = np.asarray(v, float)
    return v / max(float(np.linalg.norm(v)), 1e-12)


def perp(v, axis):
    axis = _n(axis)
    return _n(np.asarray(v, float) - np.dot(v, axis) * axis)


# ---------------------------------------------------------------- geometry accumulator (Unreal cm)
class Geo:
    """Vertices (Unreal cm), faces (consistently wound per shell; shells are turned outward by signed volume at the end)
    and one slot per face."""

    def __init__(self):
        self.v, self.f, self.s = [], [], []

    def add(self, mesh, slot=None):
        verts, faces, slots = mesh
        base = len(self.v)
        self.v.extend(np.asarray(verts, float).tolist())
        for i, face in enumerate(faces):
            self.f.append([base + int(j) for j in face])
            self.s.append(slot if slot is not None else slots[i])
        return base


def _size(s):
    return (float(s), float(s)) if np.isscalar(s) else (float(s[0]), float(s[1]))


def rings_mesh(rings, sides, closed=False, slot="PickleMimicWood", band_slots=None, cap_slots=None, phase=0.0,
               jitter=0.0, rng=None):
    """A shell of rings. rings: [(centre, Y, Z, size)] with size r or (ry, rz) along the ring's Y and Z (a 0 size is a
    pole). Ring vertex j sits at angle 2 pi j / sides + phase from Y toward Z. jitter: cm (scalar or per ring)."""
    verts, faces, slots, idx = [], [], [], []
    jit = [jitter] * len(rings) if np.isscalar(jitter) else list(jitter)
    for k, (c, Y, Z, size) in enumerate(rings):
        ry, rz = _size(size)
        c, Y, Z = (np.asarray(a, float) for a in (c, Y, Z))
        if ry <= 1e-9 and rz <= 1e-9:
            p = c.copy()
            if jit[k] and rng is not None:
                p = p + np.clip(rng.normal(0.0, jit[k], 3), -2.0 * jit[k], 2.0 * jit[k])
            idx.append(len(verts))
            verts.append(p)
            continue
        ring = []
        for j in range(sides):
            a = 2.0 * math.pi * j / sides + phase
            p = c + ry * math.cos(a) * Y + rz * math.sin(a) * Z
            if jit[k] and rng is not None:
                p = p + np.clip(rng.normal(0.0, jit[k], 3), -2.0 * jit[k], 2.0 * jit[k])
            ring.append(len(verts))
            verts.append(p)
        idx.append(ring)
    n = len(rings)
    pairs = [(k, k + 1) for k in range(n - 1)] + ([(n - 1, 0)] if closed else [])
    for b, (k0, k1) in enumerate(pairs):
        sl = band_slots[b] if band_slots is not None else slot
        A, B = idx[k0], idx[k1]
        if isinstance(A, int) and isinstance(B, int):
            continue
        if isinstance(A, int):
            for j in range(sides):
                faces.append([A, B[(j + 1) % sides], B[j]])
                slots.append(sl)
        elif isinstance(B, int):
            for j in range(sides):
                faces.append([A[j], A[(j + 1) % sides], B])
                slots.append(sl)
        else:
            for j in range(sides):
                j1 = (j + 1) % sides
                faces.append([A[j], A[j1], B[j1], B[j]])
                slots.append(sl)
    if not closed:
        cs = cap_slots or (slot, slot)
        if not isinstance(idx[0], int):
            faces.append(list(reversed(idx[0])))
            slots.append(cs[0])
        if not isinstance(idx[-1], int):
            faces.append(list(idx[-1]))
            slots.append(cs[1])
    return np.array(verts), faces, slots


def axis_frame(T, up=(0.0, 0.0, 1.0)):
    """(Y, Z) perpendicular to T with Y x Z = T and Z as close to `up` as possible."""
    T = _n(T)
    up = np.asarray(up, float)
    if abs(np.dot(_n(up), T)) > 0.98:
        up = np.array([1.0, 0.0, 0.0]) if abs(T[0]) < 0.9 else np.array([0.0, 1.0, 0.0])
    Z = perp(up, T)
    Y = np.cross(Z, T)
    return Y, Z


# Round the jar's vertical axis: Y' = -Y, Z' = +X (axis_frame of +Z), so a ring's angle a points at
# (sin a, -cos a): a = pi / 2 is +X. VERT_PHASE turns the 12-gon so a facet is centred on +X.
VERT_Y, VERT_Z = axis_frame((0.0, 0.0, 1.0))
VERT_PHASE = JAR_PHASE


def vert_dir(deg):
    """The horizontal unit vector at deg degrees from +X toward +Y (the body's bearings)."""
    a = math.radians(deg)
    return np.array([math.cos(a), math.sin(a), 0.0])


def vrevolve(profile, sides, centre=(0.0, 0.0, 0.0), phase=None, **kw):
    """Rings round a vertical axis through centre for profile [(r, z)] (r the polygon's circumradius)."""
    c = np.asarray(centre, float)
    rings = [(c + np.array([0.0, 0.0, z]), VERT_Y, VERT_Z, r) for r, z in profile]
    return rings_mesh(rings, sides, phase=VERT_PHASE if phase is None else phase, **kw)


def sweep(points, sizes, sides, up=(0.0, 0.0, 1.0), **kw):
    P = np.asarray(points, float)
    rings = []
    Z = None
    for k in range(len(P)):
        T = P[1] - P[0] if k == 0 else (P[-1] - P[-2] if k == len(P) - 1 else _n(P[k + 1] - P[k]) + _n(P[k] - P[k - 1]))
        T = _n(T)
        if Z is None:
            Y, Z = axis_frame(T, up)
        else:
            Z = perp(Z, T)
            Y = np.cross(Z, T)
        rings.append((P[k], Y, Z, sizes[k]))
    return rings_mesh(rings, sides, **kw)


BOX_FACES = [[0, 4, 6, 2], [1, 3, 7, 5], [0, 1, 5, 4], [2, 6, 7, 3], [0, 2, 3, 1], [4, 5, 7, 6]]


def hexa(corners):
    """A hexahedron from 8 corners indexed (x > 0) + 2 (y > 0) + 4 (z > 0) of its own box."""
    return np.asarray(corners, float), [list(f) for f in BOX_FACES], [None] * 6


def box(center, half, R=None):
    c = np.asarray(center, float)
    h = np.asarray(half, float)
    R = np.eye(3) if R is None else np.asarray(R, float)
    corners = [c + R @ (h * np.array([1.0 if i & 1 else -1.0, 1.0 if i & 2 else -1.0, 1.0 if i & 4 else -1.0]))
               for i in range(8)]
    return hexa(corners)


def bevel_box(center, half, R=None, bevel=0.6, jitter=0.0, rng=None):
    """A box with chamfered vertical edges (an octagonal prism): the blocky wood and the teeth."""
    c = np.asarray(center, float)
    hx, hy, hz = (float(x) for x in half)
    R = np.eye(3) if R is None else np.asarray(R, float)
    b = min(bevel, hx * 0.45, hy * 0.45)
    outline = [(hx, -hy + b), (hx, hy - b), (hx - b, hy), (-hx + b, hy), (-hx, hy - b), (-hx, -hy + b), (-hx + b, -hy),
               (hx - b, -hy)]
    verts = []
    for z in (-hz, hz):
        for x, y in outline:
            p = c + R @ np.array([x, y, z])
            if jitter and rng is not None:
                p = p + np.clip(rng.normal(0.0, jitter, 3), -2.0 * jitter, 2.0 * jitter)
            verts.append(p)
    n = len(outline)
    faces = [list(range(n - 1, -1, -1)), list(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, j + n, i + n])
    return np.array(verts), faces, [None] * len(faces)


def radial_frame(deg):
    """Rotation columns (radial out, tangential (toward +deg), up) at bearing deg."""
    r = vert_dir(deg)
    t = vert_dir(deg + 90.0)
    return np.column_stack([r, t, np.array([0.0, 0.0, 1.0])])


def poly_point(r, deg_index_frac):
    """A point on the jar's 12-gon of circumradius r at a fractional corner index (corner k at angle
    JAR_PHASE + 2 pi k / 12 in ring angles); between corners it runs straight along the facet."""
    k0 = int(math.floor(deg_index_frac))
    t = deg_index_frac - k0

    def corner(k):
        a = 2.0 * math.pi * k / JAR_SIDES + VERT_PHASE
        return r * math.cos(a) * VERT_Y + r * math.sin(a) * VERT_Z
    return corner(k0) * (1.0 - t) + corner(k0 + 1) * t


# ---------------------------------------------------------------- pieces
def build_glass(rng):
    g = Geo()
    prof = [(0.0, 0.0)] + GLASS_OUT + GLASS_IN + [(0.0, 2.0)]
    g.add(vrevolve(prof, JAR_SIDES), "PickleMimicGlass")
    return g, {"LiquidCentre": [0.0, 0.0, LIQUID_CENTRE]}


def build_liquid(rng):
    g = Geo()
    h = LIQUID_HALF
    g.add(vrevolve([(0.0, -h), (LIQUID_RADIUS, -h), (LIQUID_RADIUS, h), (0.0, h)], 32, phase=0.0), "PickleMimicBrine")
    return g, {}


def hoop(g, z0, z1, rng):
    c = 0.8
    prof = [(HOOP_IN, z0), (HOOP_OUT - c, z0), (HOOP_OUT, z0 + c), (HOOP_OUT, z1 - c), (HOOP_OUT - c, z1), (HOOP_IN, z1)]
    g.add(vrevolve(prof, JAR_SIDES, closed=True, jitter=0.25, rng=rng), "PickleMimicWood")


def clasp(g, deg, z0, z1, rng):
    apo = HOOP_OUT * math.cos(math.pi / JAR_SIDES)
    c = vert_dir(deg) * (apo + 1.2) + np.array([0.0, 0.0, 0.5 * (z0 + z1)])
    g.add(bevel_box(c, (1.8, 4.0, 0.5 * (z1 - z0) + 2.2), radial_frame(deg), bevel=0.7, jitter=0.15, rng=rng),
          "PickleMimicWoodDark")
    # the clasp's peg
    g.add(bevel_box(c + vert_dir(deg) * 2.2, (0.9, 1.6, 1.6), radial_frame(deg), bevel=0.4), "PickleMimicWood")


def build_frame(rng):
    g = Geo()
    for z0, z1 in HOOPS:
        hoop(g, z0, z1, rng)
    for deg in (30.0, -30.0, 150.0, -150.0):
        clasp(g, deg, *HOOPS[1], rng)
    for deg in (0.0, 90.0, -90.0, 180.0):
        clasp(g, deg, *HOOPS[0], rng)
    sockets = {}
    # the hinge knuckles on the band's back, either side of the lid's leaf
    for side in (1.0, -1.0):
        g.add(bevel_box(HINGE + np.array([0.6, 7.0 * side, -1.8]), (2.6, 2.8, 2.6), bevel=0.8), "PickleMimicWoodDark")
    g.add(sweep([HINGE + np.array([0.0, -10.5, 0.0]), HINGE + np.array([0.0, 10.5, 0.0])], [1.1, 1.1], 6,
                up=(0.0, 0.0, 1.0)), "PickleMimicWoodDark")
    sockets["Hinge"] = HINGE.tolist()
    return g, sockets


def hull(points):
    """The convex hull of points (Unreal cm) as (verts, faces, slots)."""
    bm = bmesh.new()
    for p in points:
        bm.verts.new(tuple(float(x) for x in p))
    res = bmesh.ops.convex_hull(bm, input=bm.verts[:])
    for v in res.get("geom_interior", []) + res.get("geom_unused", []):
        if isinstance(v, bmesh.types.BMVert) and v.is_valid:
            bm.verts.remove(v)
    bm.verts.index_update()
    verts = [np.array(v.co[:]) for v in bm.verts]
    faces = [[v.index for v in f.verts] for f in bm.faces]
    bm.free()
    return np.array(verts), faces, [None] * len(faces)


def bevel_cube(centre, half, R, bevel, tip_sign=0.0, tip_shrink=1.0):
    """A cube with every edge chamfered by `bevel` (the hull of its three inset boxes); the face toward tip_sign * Z is
    shrunk by tip_shrink (a tooth's tip)."""
    hx, hy, hz = half
    pts = []
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            for sz in (-1.0, 1.0):
                s = tip_shrink if (tip_sign and sz == tip_sign) else 1.0
                for p in ((hx * s, (hy - bevel) * s, hz - bevel), ((hx - bevel) * s, hy * s, hz - bevel),
                          ((hx - bevel) * s, (hy - bevel) * s, hz)):
                    pts.append(np.asarray(centre, float) + R @ (np.array(p) * np.array([sx, sy, sz])))
    return hull(pts)


def tooth(g, centre, deg, rng, down=False):
    """A big square bone tooth: a bevelled cube, a little skewed and narrower at its tip (up, or down when it hangs)."""
    R = radial_frame(deg)
    lean = rng.normal(0.0, 0.05, 2)
    R = R @ np.array([[1.0, 0.0, lean[0]], [0.0, 1.0, lean[1]], [0.0, 0.0, 1.0]])
    hx, hy, hz = TOOTH_HALF
    hz *= 0.92 + 0.16 * rng.random()
    g.add(bevel_cube(centre, (hx, hy, hz), R, TOOTH_BEVEL, tip_sign=-1.0 if down else 1.0, tip_shrink=0.82),
          "PickleMimicBone")
    return hz


def band_clasp(g, deg, z0, z1, centre=(0.0, 0.0, 0.0)):
    """A dark wooden plate across a band at bearing deg (round centre), z0..z1, with a peg."""
    apo = BAND_OUT * math.cos(math.pi / JAR_SIDES)
    c = np.asarray(centre, float) + vert_dir(deg) * (apo + 0.9) + np.array([0.0, 0.0, 0.5 * (z0 + z1)])
    g.add(bevel_box(c, (1.2, 3.4, 0.5 * (z1 - z0)), radial_frame(deg), bevel=0.6), "PickleMimicWoodDark")
    g.add(bevel_box(c + vert_dir(deg) * 1.6, (0.8, 1.3, 1.3), radial_frame(deg), bevel=0.35), "PickleMimicWood")


def build_mouth(rng):
    """The lower jaw: the band (wood outside, gum inside), the gum floor over the glass's top, the ledge and its teeth."""
    g = Geo()
    c = 0.8
    prof = [(BAND_IN, BAND_Z0), (BAND_OUT - c, BAND_Z0), (BAND_OUT, BAND_Z0 + c), (BAND_OUT, BAND_Z1 - c),
            (BAND_OUT - c, BAND_Z1), (BAND_IN, BAND_Z1)]
    wood = "PickleMimicWood"
    g.add(vrevolve(prof, JAR_SIDES, closed=True, jitter=[0.0, 0.2, 0.2, 0.2, 0.2, 0.0], rng=rng,
                   band_slots=[wood] * 5 + ["PickleMimicGum"]))
    f0, f1 = MOUTH_FLOOR
    g.add(vrevolve([(0.0, f0), (BAND_IN - 0.1, f0), (BAND_IN - 0.1, f1), (0.0, f1)], JAR_SIDES), "PickleMimicGum")
    r_in, top = LEDGE
    g.add(vrevolve([(r_in, f1 - 0.2), (BAND_IN - 0.1, f1 - 0.2), (BAND_IN - 0.1, top), (r_in + 1.2, top + 0.3),
                    (r_in, top - 0.6)], JAR_SIDES, closed=True, jitter=0.15, rng=rng), "PickleMimicGum")
    for deg in RIM_TEETH_DEG:
        # standing on the ledge, their tips over the band's rim (inside the shut lid's skirt)
        tooth(g, vert_dir(deg) * TOOTH_RING + np.array([0.0, 0.0, top - 0.3 + TOOTH_HALF[2]]), deg, rng)
    for deg in (50.0, -50.0, 130.0, -130.0):
        band_clasp(g, deg, BAND_Z0 - 0.6, BAND_Z1 - 1.0)
    # the hasp's staple under the lid's latch, at the front
    g.add(bevel_box(vert_dir(0.0) * (BAND_OUT * math.cos(math.pi / JAR_SIDES) + 0.9) + np.array([0.0, 0.0, 57.5]),
                    (0.9, 2.2, 1.6), radial_frame(0.0), bevel=0.4), "PickleMimicWoodDark")
    return g, {}


def build_face(rng):
    g = Geo()
    prof = [(0.0, 0.0), (12.5, 0.0), (13.2, 5.0), (12.7, 9.5), (9.5, 13.0), (0.0, 14.0)]
    g.add(vrevolve(prof, 10, phase=0.0, jitter=[0.0, 0.0, 0.3, 0.3, 0.2, 0.0], rng=rng), "PickleMimicVoid")
    for side in (1.0, -1.0):
        deg = 20.0 * side
        n = vert_dir(deg)
        c = n * 12.4 + np.array([0.0, 0.0, FACE_EYE_Z])
        ry, rz = 1.9, 3.1
        pts = [c - n * 0.6, c + n * 0.9, c + n * 1.25]
        g.add(sweep(pts, [(ry, rz), (ry, rz), (ry * 0.78, rz * 0.82)], 10, up=(0.0, 0.0, 1.0)), "PickleMimicEye")
    return g, {}


def build_lid(rng):
    """The upper jaw, in the hinge's frame (z 0 the seam): a cap of the band's radius, its skirt down to the seam, red
    inside under a ceiling at LID_CEILING, a crowned top, the knob, clasps on the skirt, the hinge leaf at the back and the
    hasp's latch hanging over the seam at the front; its teeth hang from the ceiling."""
    g = Geo()
    centre = np.array([LID_CENTRE_X, 0.0, 0.0])
    c = 0.8
    wood, gum = "PickleMimicWood", "PickleMimicGum"
    prof = [(0.0, LID_CEILING), (BAND_IN, LID_CEILING), (BAND_IN, 0.0), (BAND_OUT - c, 0.0), (BAND_OUT, c),
            (BAND_OUT, LID_SKIRT + 1.0), (BAND_OUT - 1.6, LID_SKIRT + 2.6), (22.0, LID_CROWN - 0.6), (8.0, LID_CROWN),
            (0.0, LID_CROWN)]
    g.add(vrevolve(prof, JAR_SIDES, centre=centre, rng=rng,
                   jitter=[0.0, 0.0, 0.0, 0.2, 0.2, 0.2, 0.3, 0.4, 0.3, 0.0],
                   band_slots=[gum, gum] + [wood] * 7))
    # the knob: an octagonal prism on the crown
    g.add(vrevolve([(0.0, LID_CROWN - 0.5), (5.2, LID_CROWN - 0.5), (5.2, LID_CROWN + 2.3), (4.2, LID_CROWN + 3.3),
                    (0.0, LID_CROWN + 3.3)], 8, centre=centre, phase=math.pi / 8.0), "PickleMimicWoodDark")
    # the hinge leaf between the band's knuckles
    g.add(bevel_box(np.array([0.6, 0.0, 1.8]), (2.4, 4.0, 2.6), bevel=0.6), "PickleMimicWoodDark")
    for deg in (50.0, -50.0, 130.0, -130.0):
        band_clasp(g, deg, 0.8, LID_SKIRT + 0.6, centre)
    # the hasp: a latch plate hanging from the skirt's front down over the seam onto the band's staple
    apo = BAND_OUT * math.cos(math.pi / JAR_SIDES)
    g.add(bevel_box(centre + vert_dir(0.0) * (apo + 0.8) + np.array([0.0, 0.0, 1.6]), (0.8, 3.6, 5.6),
                    radial_frame(0.0), bevel=0.5), "PickleMimicWoodDark")
    for deg in LID_TEETH_DEG:
        tooth(g, centre + vert_dir(deg) * TOOTH_RING + np.array([0.0, 0.0, LID_CEILING + 0.3 - TOOTH_HALF[2]]), deg,
              rng, down=True)
    return g, {}


def lobe(knot, d, length, w0, w1, thick, side_n):
    """A flat bow lobe / tail from the knot along d: narrow at the knot, w1 wide at its far end, its flat facing side_n."""
    d = _n(d)
    n = _n(side_n)
    w = _n(np.cross(d, n))
    corners = []
    for i in range(8):
        far = bool(i & 1)
        sn = 1.0 if i & 2 else -1.0
        sw = 1.0 if i & 4 else -1.0
        base = knot + d * (length if far else 1.0)
        half_w = w1 if far else w0
        corners.append(base + n * (thick * sn) + w * (half_w * sw))
    return hexa(corners)


def build_bow(rng):
    g = Geo()
    knot = np.array([0.0, 34.0, 44.5])
    out = np.array([0.0, 1.0, 0.0])
    g.add(bevel_box(knot, (3.4, 2.4, 3.6), bevel=0.8, jitter=0.15, rng=rng), "PickleMimicCloth")
    for d, length, w1 in (((1.0, 0.25, 0.75), 15.0, 6.5), ((-1.0, 0.25, 0.75), 15.0, 6.5)):
        g.add(lobe(knot, d, length, 2.4, w1, 1.4, out + np.array([0.0, 0.0, 0.3])), "PickleMimicCloth")
    for d, length in (((0.32, 0.1, -1.0), 22.0), ((-0.28, 0.14, -1.0), 19.0)):
        g.add(lobe(knot, d, length, 2.4, 3.2, 0.7, out), "PickleMimicCloth")
    return g, {}


def build_foot(rng):
    """The concept's block leg, as a floating foot: a bevelled block narrowing upward, its sole split into two toes by a
    notch across the front (a slot along X, open at the front, 3.6 wide and 6 high). Pivot at the sole's centre."""
    g = Geo()
    I = np.eye(3)
    top = FOOT_HEIGHT
    pts = []
    for z, hx, hy in ((6.0, 9.0, 9.0), (top, 7.0, 7.0)):
        for sx in (-1.0, 1.0):
            for sy in (-1.0, 1.0):
                b = 1.6
                pts += [(sx * hx, sy * (hy - b), z), (sx * (hx - b), sy * hy, z)]
    pts = [np.array(p) + np.clip(rng.normal(0.0, 0.15, 3), -0.3, 0.3) * np.array([1.0, 1.0, 0.0]) for p in pts]
    g.add(hull(pts), "PickleMimicWood")
    # a darker cap on top: the stump the foot would have hung from
    g.add(bevel_box((0.0, 0.0, top + 0.6), (6.2, 6.2, 0.8), bevel=1.2), "PickleMimicWoodDark")
    # two toes, the notch between them (the front half slotted, the back half solid so the toes join)
    for side in (1.0, -1.0):
        g.add(bevel_cube((0.0, side * 5.4, 3.05), (9.0, 3.6, 3.05), I, 1.0), "PickleMimicWood")
    g.add(bevel_cube((-4.5, 0.0, 3.05), (4.5, 3.2, 3.05), I, 0.7), "PickleMimicWood")
    return g, {}


def build_shards(rng):
    """The glass in SHARD_COUNT pieces that fit together exactly: the base (everything under z 3) and the wall split by a
    noisy Voronoi of the wall's cells (rows WALL_ROWS x WALL_COLUMNS) round SHARD_COUNT - 1 seeds. Each wall shard is
    its cells' outer and inner faces closed by walls along its boundary (the cracks), so it is a solid of its own."""
    shards = [Geo() for _ in range(SHARD_COUNT)]
    shards[0].add(vrevolve([(0.0, 0.0), GLASS_OUT[0], GLASS_OUT[1], (28.4, 3.0), GLASS_IN[-1], (0.0, 2.0)], JAR_SIDES),
                  "PickleMimicGlass")
    rows, cols = len(WALL_ROWS), WALL_COLUMNS

    def point(k, u, layer):
        r, z = WALL_ROWS[k][layer]
        return poly_point(r, u * JAR_SIDES / cols) + np.array([0.0, 0.0, z])

    centres = np.array([[(point(k, u, 0) + point(k + 1, u + 1, 0)) * 0.5 for u in range(cols)] for k in range(rows - 1)])
    flat = centres.reshape(-1, 3)
    # seeds spread round the jar: one per sector of 360/9 degrees at a random height, nudged
    seeds = []
    count = SHARD_COUNT - 1
    for s in range(count):
        u = (s + 0.3 + 0.4 * rng.random()) * cols / count
        k = rng.uniform(1.0, rows - 2.0)
        seeds.append(point(int(k), int(u) % cols, 0))
    seeds = np.array(seeds)
    noise = rng.normal(0.0, 3.5, (flat.shape[0], count))
    dist = np.linalg.norm(flat[:, None, :] - seeds[None, :, :], axis=2) + noise
    owner = (np.argmin(dist, axis=1) + 1).reshape(rows - 1, cols)
    # no shard may touch itself only corner to corner (four crack walls on one edge): the off-diagonal cell joins it
    for _ in range(8):
        changed = False
        for k in range(rows - 2):
            for u in range(cols):
                u1 = (u + 1) % cols
                a, b, c, d = owner[k, u], owner[k, u1], owner[k + 1, u], owner[k + 1, u1]
                if a == d and b != a and c != a:
                    owner[k, u1] = a
                    changed = True
                elif b == c and a != b and d != b:
                    owner[k, u] = b
                    changed = True
        if not changed:
            break

    def own(k, u):
        if k < 0 or k >= rows - 1:
            return -1
        return owner[k, u % cols]

    for s in range(1, SHARD_COUNT):
        verts, faces, key = [], [], {}

        def vid(k, u, layer):
            kk = (k, u % cols, layer)
            if kk not in key:
                key[kk] = len(verts)
                verts.append(point(k, u % cols, layer))
            return key[kk]

        for k in range(rows - 1):
            for u in range(cols):
                if owner[k, u] != s:
                    continue
                loop = [(k, u), (k, u + 1), (k + 1, u + 1), (k + 1, u)]
                faces.append([vid(a, b, 0) for a, b in loop])
                faces.append([vid(a, b, 1) for a, b in reversed(loop)])
                # boundary edges of this cell in the outer loop's direction: (A, B) -> wall [B, A, A', B']
                neighbours = [(k - 1, u), (k, u + 1), (k + 1, u), (k, u - 1)]
                for e in range(4):
                    if own(*neighbours[e]) == s:
                        continue
                    A, B = loop[e], loop[(e + 1) % 4]
                    faces.append([vid(*B, 0), vid(*A, 0), vid(*A, 1), vid(*B, 1)])
        shards[s].add((np.array(verts), faces, [None] * len(faces)), "PickleMimicGlass")
    return shards


BUILDERS = {"Glass": build_glass, "Liquid": build_liquid, "Frame": build_frame, "Mouth": build_mouth,
            "Face": build_face, "Lid": build_lid, "Bow": build_bow, "Foot": build_foot}


# ---------------------------------------------------------------- materials / objects
def material(slot):
    rgb, rough, metal, emis = PALETTE[slot]
    alpha = PREVIEW_ALPHA.get(slot, 1.0)
    mat = bpy.data.materials.get(slot) or bpy.data.materials.new(slot)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    mat.diffuse_color = (rgb[0], rgb[1], rgb[2], alpha)
    mat.roughness = rough
    mat.metallic = metal
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Alpha"].default_value = alpha
        if emis > 0.0:
            bsdf.inputs["Emission Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
            bsdf.inputs["Emission Strength"].default_value = emis
    if alpha < 1.0:
        for prop, value in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
            try:
                setattr(mat, prop, value)
            except (AttributeError, TypeError):
                pass
        try:
            mat.use_backface_culling = False
        except AttributeError:
            pass
    return mat


def _islands(bm):
    bm.faces.ensure_lookup_table()
    seen, out = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, isl = [f], []
        seen.add(f.index)
        while stack:
            x = stack.pop()
            isl.append(x)
            for e in x.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index)
                        stack.append(g)
        out.append(isl)
    return out


def to_object(name, geo):
    """A flat-shaded mesh object at the origin: Unreal cm -> Blender metres (y mirrored, faces reversed), triangulated,
    every shell turned outward by its signed volume, the used slots in SLOTS order, a cube-projected UVMap."""
    v = np.asarray(geo.v, float) * np.array([1.0, -1.0, 1.0]) * 0.01
    faces = [list(reversed(f)) for f in geo.f]
    used = [s for s in SLOTS if s in set(geo.s)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(v.tolist(), [], faces)
    for s in used:
        mesh.materials.append(material(s))
    mesh.polygons.foreach_set("material_index", [used.index(s) for s in geo.s])
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    flipped = 0
    for isl in _islands(bm):
        vol = sum(f.verts[0].co.dot(f.verts[1].co.cross(f.verts[2].co)) for f in isl) / 6.0
        if vol < 0.0:
            bmesh.ops.reverse_faces(bm, faces=isl)
            flipped += 1
    bm.to_mesh(mesh)
    bm.free()
    mesh.polygons.foreach_set("use_smooth", [False] * len(mesh.polygons))
    uv = mesh.uv_layers.new(name="UVMap")
    nl = len(mesh.loops)
    lv = np.empty(nl, np.int64)
    mesh.loops.foreach_get("vertex_index", lv)
    co = np.empty(len(mesh.vertices) * 3)
    mesh.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    pn = np.empty(len(mesh.polygons) * 3)
    mesh.polygons.foreach_get("normal", pn)
    pn = np.abs(pn.reshape(-1, 3))
    lt = np.empty(len(mesh.polygons), np.int64)
    mesh.polygons.foreach_get("loop_total", lt)
    dom = np.repeat(np.argmax(pn, axis=1), lt)
    p = co[lv]
    u = np.where(dom == 0, p[:, 1], p[:, 0])
    w = np.where(dom == 2, p[:, 1], p[:, 2])
    uv.data.foreach_set("uv", np.stack([u, w], axis=1).ravel())
    mesh.validate(verbose=False)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj["flipped_shells"] = flipped
    return obj


def add_sockets(obj, sockets):
    for name, loc in sockets.items():
        e = bpy.data.objects.new("SOCKET_%s" % name, None)
        e.empty_display_type = "ARROWS"
        e.empty_display_size = 0.05
        e.location = tuple((np.asarray(loc, float) * np.array([1.0, -1.0, 1.0]) * 0.01).tolist())
        e.parent = obj
        bpy.context.scene.collection.objects.link(e)


def socket_children(obj):
    return [o for o in bpy.data.objects if o.parent is obj and o.name.startswith("SOCKET_")]


def bounds_cm(obj):
    n = len(obj.data.vertices)
    co = np.empty(n * 3)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(n, 3) * 100.0
    return co.min(axis=0), co.max(axis=0)


def ue_bounds(obj):
    lo, hi = bounds_cm(obj)
    return np.array([lo[0], -hi[1], lo[2]]), np.array([hi[0], -lo[1], hi[2]])


def ue_verts(obj):
    n = len(obj.data.vertices)
    co = np.empty(n * 3)
    obj.data.vertices.foreach_get("co", co)
    return co.reshape(n, 3) * 100.0 * np.array([1.0, -1.0, 1.0])


def tri_count(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def mesh_health(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    open_e = sum(1 for e in bm.edges if e.is_boundary)
    nonman = sum(1 for e in bm.edges if len(e.link_faces) > 2)
    flipped = sum(1 for e in bm.edges if len(e.link_faces) == 2 and not e.is_contiguous)
    degenerate = sum(1 for f in bm.faces if f.calc_area() < 1e-8)
    bm.free()
    return {"open": open_e, "nonmanifold": nonman, "inconsistent": flipped, "degenerate": degenerate}


def volume_cm3(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    vol = sum(f.verts[0].co.dot(f.verts[1].co.cross(f.verts[2].co)) for f in bm.faces) / 6.0
    bm.free()
    return vol * 1e6


# ---------------------------------------------------------------- export
def export_fbx(obj, sockets):
    os.makedirs(EXPORT_DIR, exist_ok=True)
    path = os.path.join(EXPORT_DIR, obj.name + ".fbx")
    group = [obj] + socket_children(obj)
    for o in bpy.context.scene.objects:
        o.select_set(o in group)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH", "EMPTY"}, mesh_smooth_type="EDGE",
                             use_mesh_modifiers=True, add_leaf_bones=False, bake_anim=False, use_tspace=False,
                             apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y",
                             use_triangles=True, path_mode="STRIP")
    lo, hi = ue_bounds(obj)
    meta = {"name": obj.name, "builder": BUILDER, "ue_folder": UE_MESH_FOLDER,
            "slots": [m.name for m in obj.data.materials], "tris": tri_count(obj),
            "bounds_cm": {"min": [round(float(x), 3) for x in lo], "max": [round(float(x), 3) for x in hi]},
            "half_extents_cm": [round(float(x), 3) for x in (hi - lo) * 0.5],
            "centre_cm": [round(float(x), 3) for x in (hi + lo) * 0.5],
            "sockets": {k: [round(float(x), 3) for x in v] for k, v in sockets.items()},
            "frame": "Unreal local cm: +X the face's direction, +Y right, +Z up"}
    with open(os.path.splitext(path)[0] + ".json", "w") as fh:
        json.dump(meta, fh, indent=1)
    print("exported %-32s tris %5d  bounds %s .. %s  sockets %s" % (obj.name, meta["tris"], meta["bounds_cm"]["min"],
                                                                    meta["bounds_cm"]["max"], sorted(sockets)))
    return path


def _base(name):
    if len(name) > 4 and name[-4] == "." and name[-3:].isdigit():
        return name[:-4]
    return name


def reimport_check(path, obj, sockets):
    """Import the FBX and compare it with the source object: tris, slots, bounds, socket names and places."""
    fails = []
    before = set(bpy.data.objects)
    mats_before = set(bpy.data.materials)
    bpy.ops.import_scene.fbx(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    empties = [o for o in new if o.type == "EMPTY"]
    name = obj.name
    if len(meshes) != 1:
        fails.append("%s reimport: %d meshes" % (name, len(meshes)))
    else:
        m = meshes[0]
        co = np.array([(m.matrix_world @ vv.co)[:] for vv in m.data.vertices]) * 100.0
        lo, hi = co.min(axis=0), co.max(axis=0)
        slo, shi = bounds_cm(obj)
        m.data.calc_loop_triangles()
        tris = len(m.data.loop_triangles)
        slots = [_base(mm.name) if mm else None for mm in m.data.materials]
        want = [mm.name for mm in obj.data.materials]
        got_s = {}
        for e in empties:
            loc = np.array(e.matrix_world.translation[:]) * 100.0
            got_s[_base(e.name)[len("SOCKET_"):]] = loc * np.array([1.0, -1.0, 1.0])
        bad_s = [k for k, v in sockets.items() if k not in got_s or np.abs(got_s[k] - np.asarray(v)).max() > 0.05]
        size_err = float(np.abs(np.concatenate([lo - slo, hi - shi])).max())
        if tris != tri_count(obj):
            fails.append("%s reimport tris %d != %d" % (name, tris, tri_count(obj)))
        if slots != want:
            fails.append("%s reimport slots %s != %s" % (name, slots, want))
        if size_err > 0.05:
            fails.append("%s reimport bounds off by %.3f cm" % (name, size_err))
        if bad_s or len(got_s) != len(sockets):
            fails.append("%s reimport sockets %s (want %s)" % (name, sorted(got_s), sorted(sockets)))
        if not m.data.uv_layers or m.data.uv_layers[0].name != "UVMap":
            fails.append("%s reimport has no UVMap" % name)
    for o in new:
        data = o.data if o.type == "MESH" else None
        bpy.data.objects.remove(o, do_unlink=True)
        if data is not None and data.users == 0:
            bpy.data.meshes.remove(data)
    for mm in list(bpy.data.materials):
        if mm not in mats_before and mm.users == 0:
            bpy.data.materials.remove(mm)
    return fails


# ---------------------------------------------------------------- the rest layouts (Unreal cm -> Blender matrices)
def ue_matrix(rot_cols, loc_cm):
    """A Blender world matrix for a part Unreal places with rotation columns (X, Y, Z) at loc (Unreal cm)."""
    r = MIRROR @ np.column_stack(rot_cols) @ MIRROR
    t = MIRROR @ np.asarray(loc_cm, float) * 0.01
    m = Matrix.Identity(4)
    for i in range(3):
        for j in range(3):
            m[i][j] = r[i, j]
        m[i][3] = t[i]
    return m


def foot_point(sx, sy, drop=0.0, lift=0.0):
    """The foot (sx, sy) in the body frame: the body sunk `drop` toward the ground, the foot lifted `lift` off it."""
    return LEG_FOOT * np.array([sx, sy, 1.0]) + np.array([0.0, 0.0, drop + lift])


def rot_pitch(deg):
    a = math.radians(deg)
    return (np.array([math.cos(a), 0.0, math.sin(a)]), np.array([0.0, 1.0, 0.0]), np.array([-math.sin(a), 0.0, math.cos(a)]))


def rot_yaw(deg):
    a = math.radians(deg)
    return (np.array([math.cos(a), math.sin(a), 0.0]), np.array([-math.sin(a), math.cos(a), 0.0]), np.array([0.0, 0.0, 1.0]))


I3 = (np.array([1.0, 0, 0]), np.array([0, 1.0, 0]), np.array([0, 0, 1.0]))


def layout(lid_open=0.0, drop=0.0, shatter=0.0, lift=0.0):
    """[(part, rotation columns, location)] of the whole mimic in the body frame (the ground at z = -CLEARANCE): its
    body sunk `drop`, the lid lifted lid_open (0..1, LID_OPEN_DEG at 1) with the face risen as much, and the glass
    either whole or (shatter > 0) as its shards pushed out from the axis by `shatter` cm; the front-right / back-left pair
    of feet lifted `lift` (mid-trot)."""
    body = np.array([0.0, 0.0, -drop])
    out = []
    if shatter > 0.0:
        for s in SHARDS:
            out.append((s, I3, body))
    else:
        out.append(("Glass", I3, body))
        out.append(("Liquid", I3, body + np.array([0.0, 0.0, LIQUID_CENTRE])))
    out.append(("Frame", I3, body))
    out.append(("Mouth", I3, body))
    out.append(("Face", I3, body + np.array([0.0, 0.0, FACE_BASE + FACE_RISE * lid_open])))
    out.append(("Lid", rot_pitch(LID_OPEN_DEG * lid_open), body + HINGE))
    out.append(("Bow", I3, body))
    out.append(("Bow", rot_yaw(180.0), body))
    for name, sx, sy in LEGS:
        yaw = rot_yaw(math.degrees(math.atan2(sy, sx)))
        out.append(("Foot", yaw, body + foot_point(sx, sy, drop, lift if name in ("FR", "BL") else 0.0)))
    return out


def pose(objs, name, lid_open=0.0, drop=0.0, shatter=0.0, offset=(0.0, 0.0, 0.0), step=0.0):
    lift = np.array([0.0, 0.0, CLEARANCE]) + np.asarray(offset, float)
    posed = []
    for i, (part, rot, loc) in enumerate(layout(lid_open, drop, shatter, step)):
        src = objs[part]
        c = bpy.data.objects.new("%s_%s_%02d" % (name, part, i), src.data)
        bpy.context.scene.collection.objects.link(c)
        m = ue_matrix(rot, np.asarray(loc) + lift)
        if part in SHARDS and shatter > 0.0:
            lo, hi = ue_bounds(src)
            cen = 0.5 * (lo + hi)
            push = _n(np.array([cen[0], cen[1], 0.0])) * shatter + np.array([0.0, 0.0, 0.2 * shatter])
            m = ue_matrix(I3, np.asarray(loc) + lift + push)
        c.matrix_world = m
        posed.append(c)
    return posed


def preview_pickles(name, drop=0.0, offset=(0.0, 0.0, 0.0)):
    """Preview only (never exported): green faceted pickles standing in the jar, as the brine shader draws them."""
    g = Geo()
    rng = np.random.default_rng(9001)
    base = np.array([0.0, 0.0, CLEARANCE - drop + LIQUID_FLOOR]) + np.asarray(offset, float)
    spots = [(0.0, 0.0)] + [(17.0 * math.cos(2.0 * math.pi * k / 7 + 0.3), 17.0 * math.sin(2.0 * math.pi * k / 7 + 0.3))
                            for k in range(7)]
    for x, y in spots:
        L = 36.0 + 8.0 * rng.random()
        r = 5.5 + 1.0 * rng.random()
        c = base + np.array([x, y, 0.0])
        g.add(sweep([c, c + np.array([0, 0, 2.5]), c + np.array([0, 0, 0.5 * L]), c + np.array([0, 0, L - 2.5]),
                     c + np.array([0, 0, L])], [r * 0.6, r, r * 1.08, r, r * 0.6], 7, up=(1.0, 0.0, 0.0)),
              "PickleMimicBrine")
    PALETTE["_PreviewPickle"] = ((0.16, 0.36, 0.03), 0.4, 0.0, 0.0)
    obj = to_object("%s_PreviewPickles" % name, g)
    obj.data.materials[0] = material("_PreviewPickle")
    del PALETTE["_PreviewPickle"]
    return obj


# ---------------------------------------------------------------- review renders
def _look_at(cam, eye, target):
    f = np.array(target, float) - np.array(eye, float)
    cam.location = eye
    cam.rotation_euler = (math.atan2(math.hypot(f[0], f[1]), -f[2]), 0.0, -math.atan2(f[0], f[1]))


def _ue_to_bl(v):
    v = np.asarray(v, float)
    return np.array([v[0], -v[1], v[2]])


def render_workbench(objs, path, view_ue, target_ue_cm, half_width_cm, size=(700, 600)):
    scene = bpy.context.scene
    others = [o for o in scene.objects if o.type == "MESH" and o not in objs]
    state = [o.hide_render for o in others]
    cam_data = bpy.data.cameras.new("_ReviewCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = half_width_cm * 0.02
    cam_data.clip_start, cam_data.clip_end = 0.01, 200.0
    cam = bpy.data.objects.new("_ReviewCam", cam_data)
    scene.collection.objects.link(cam)
    try:
        for o in others:
            o.hide_render = True
        for o in objs:
            o.hide_render = False
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "MATERIAL"
        scene.display.shading.show_cavity = False
        scene.display.shading.show_object_outline = False
        scene.render.resolution_x, scene.render.resolution_y = size
        scene.render.resolution_percentage = 100
        scene.render.film_transparent = False
        d = _n(_ue_to_bl(view_ue))
        t = _ue_to_bl(target_ue_cm) * 0.01
        _look_at(cam, tuple(t + d * 30.0), tuple(t))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
    finally:
        for o, s in zip(others, state):
            o.hide_render = s
        bpy.data.objects.remove(cam)
        bpy.data.cameras.remove(cam_data)
    return path


def tile_images(paths, out_path, cols=2):
    imgs = [bpy.data.images.load(p) for p in paths]
    w, h = imgs[0].size
    rows = (len(imgs) + cols - 1) // cols
    sheet = np.zeros((rows * h, cols * w, 4), np.float32)
    for i, img in enumerate(imgs):
        px = np.empty(w * h * 4, np.float32)
        img.pixels.foreach_get(px)
        r, c = divmod(i, cols)
        r = rows - 1 - r
        sheet[r * h:(r + 1) * h, c * w:(c + 1) * w] = px.reshape(h, w, 4)
        bpy.data.images.remove(img)
    out = bpy.data.images.new(os.path.basename(out_path), cols * w, rows * h, alpha=True)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = out_path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    for p in paths:
        try:
            os.remove(p)
        except OSError:
            pass
    return out_path


PIECE_VIEWS = (("front", (1.0, 0.0, 0.0)), ("side", (0.0, 1.0, 0.0)), ("top", (0.0, 0.001, 1.0)),
               ("iso", (0.9, 0.8, 0.6)))


def render_piece_sheets(objs):
    """One sheet per piece (the ten shards on one sheet, assembled)."""
    os.makedirs(REVIEW_DIR, exist_ok=True)
    out = []
    for part in PIECES:
        if part in SHARDS:
            continue
        o = objs[part]
        lo, hi = ue_bounds(o)
        c = 0.5 * (lo + hi)
        half = float((hi - lo).max()) * 0.62
        paths = [render_workbench([o], os.path.join(REVIEW_DIR, "_%s_%s.png" % (part, k)), v, c, half)
                 for k, v in PIECE_VIEWS]
        out.append(tile_images(paths, os.path.join(REVIEW_DIR, "PickleMimic_%s_sheet.png" % part)))
    return out


def render_layout_sheet(groups):
    """Standing (lid shut), biting (lid wide), disguised (tucked) and shattered, each from the front-left 3/4 and the
    side: a 4 x 2 sheet."""
    paths = []
    for key, objs in groups:
        for view_key, v in (("iso", (0.85, -0.75, 0.45)), ("side", (0.0, -1.0, 0.05))):
            paths.append(render_workbench(objs, os.path.join(REVIEW_DIR, "_Assembled_%s_%s.png" % (key, view_key)), v,
                                          (0.0, 0.0, 55.0), 95.0, size=(700, 700)))
    return tile_images(paths, os.path.join(REVIEW_DIR, "PickleMimic_Assembled_layout_sheet.png"), cols=2)


def _set_engine(scene):
    for name in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = name
            return name
        except TypeError:
            continue
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    return "CYCLES"


def render_hero(shots):
    """EEVEE renders on a dark brown floor and backdrop with a warm key, as in the concept's action sheet: shots =
    [(key, objects, eye (Blender m), target (Blender m))]."""
    scene = bpy.context.scene
    made = []
    world = bpy.data.worlds.new("_MimicWorld")
    try:
        world.use_nodes = True
    except Exception:
        pass
    bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
    if bg is not None:
        bg.inputs["Color"].default_value = (0.030, 0.018, 0.011, 1.0)
        bg.inputs["Strength"].default_value = 1.0
    prev_world = scene.world
    scene.world = world
    floor_mat = bpy.data.materials.new("_Floor")
    try:
        floor_mat.use_nodes = True
    except Exception:
        pass
    fb = next((n for n in floor_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if fb is not None:
        fb.inputs["Base Color"].default_value = (0.07, 0.04, 0.022, 1.0)
        fb.inputs["Roughness"].default_value = 0.9
    fm = bpy.data.meshes.new("_Floor")
    s = 40.0
    fm.from_pydata([(-s, -s, 0.0), (s, -s, 0.0), (s, s, 0.0), (-s, s, 0.0)], [], [(0, 1, 2, 3)])
    fm.materials.append(floor_mat)
    floor = bpy.data.objects.new("_Floor", fm)
    scene.collection.objects.link(floor)
    made.append(floor)

    def light(name, kind, energy, color, rot_deg, angle=None, loc=(0.0, 0.0, 10.0)):
        ld = bpy.data.lights.new(name, kind)
        ld.energy = energy
        ld.color = color
        if angle is not None:
            ld.angle = math.radians(angle)
        lo = bpy.data.objects.new(name, ld)
        lo.location = loc
        lo.rotation_euler = tuple(math.radians(a) for a in rot_deg)
        scene.collection.objects.link(lo)
        made.append(lo)
        return lo

    light("_Key", "SUN", 3.4, (1.0, 0.80, 0.60), (50.0, 0.0, 120.0), angle=6.0)
    light("_Rim", "SUN", 1.8, (1.0, 0.60, 0.35), (60.0, 0.0, -70.0), angle=10.0)
    light("_Fill", "SUN", 0.4, (0.55, 0.48, 0.42), (70.0, 0.0, 40.0), angle=30.0)

    cam_data = bpy.data.cameras.new("_HeroCam")
    cam_data.lens = 40.0
    cam_data.clip_start, cam_data.clip_end = 0.05, 200.0
    cam = bpy.data.objects.new("_HeroCam", cam_data)
    scene.collection.objects.link(cam)
    made.append(cam)
    prev = (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
            scene.render.filepath, scene.view_settings.view_transform)
    every = {o for _, objs, _, _ in shots for o in objs}
    hidden = [o for o in scene.objects if o.type == "MESH" and o is not floor]
    state = [o.hide_render for o in hidden]
    paths = []
    try:
        scene.camera = cam
        engine = _set_engine(scene)
        if engine.startswith("BLENDER_EEVEE"):
            try:
                scene.eevee.taa_render_samples = 48
            except AttributeError:
                pass
        scene.view_settings.view_transform = "Standard"
        scene.render.resolution_x, scene.render.resolution_y = 1400, 1000
        scene.render.resolution_percentage = 100
        scene.render.film_transparent = False
        for key, objs, eye, target in shots:
            for o in hidden:
                o.hide_render = o not in objs
            _look_at(cam, eye, target)
            path = os.path.join(REVIEW_DIR, "PickleMimic_Hero_%s.png" % key)
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            paths.append(path)
        print("hero renders with", engine, "of", len(every), "objects")
    finally:
        for o, s_ in zip(hidden, state):
            o.hide_render = s_
        (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
         scene.render.filepath, scene.view_settings.view_transform) = prev
        scene.world = prev_world
    return paths, made


# ---------------------------------------------------------------- checks
def contract_checks(objs):
    """The rig's numbers, read back off the built meshes (Unreal cm)."""
    fails = []

    def near(a, b, tol):
        return abs(float(a) - float(b)) <= tol

    lo, hi = ue_bounds(objs["Glass"])
    if not (near(lo[2], 0.0, 0.01) and near(hi[2], GLASS_TOP, 0.01) and near(hi[0], 30.0 * math.cos(math.pi / 12), 0.05)):
        fails.append("Glass z %.2f..%.2f, front face at x %.2f (want 0..%.0f, %.2f)" % (lo[2], hi[2], hi[0], GLASS_TOP,
                                                                                       30.0 * math.cos(math.pi / 12)))
    # the band hides the glass's top: every glass vertex at or over the band's foot lies inside the band
    gv = ue_verts(objs["Glass"])
    band_inner = BAND_IN * math.cos(math.pi / JAR_SIDES)
    over = gv[gv[:, 2] >= BAND_Z0 - 1e-6]
    if over.size and np.linalg.norm(over[:, :2], axis=1).max() > band_inner - 0.2:
        fails.append("the glass reaches r %.2f inside the band (its inner face at %.2f)"
                     % (np.linalg.norm(over[:, :2], axis=1).max(), band_inner))
    if GLASS_TOP > MOUTH_FLOOR[0] - 0.1:
        fails.append("the glass's top %.1f pokes through the mouth's floor %.1f" % (GLASS_TOP, MOUTH_FLOOR[0]))
    if abs(HINGE[2] - BAND_Z1) > 1e-6:
        fails.append("the hinge (z %.1f) is not on the seam (z %.1f): the shut lid would not sit on the band"
                     % (HINGE[2], BAND_Z1))
    lo, hi = ue_bounds(objs["Liquid"])
    if not (near(hi[2], LIQUID_HALF, 0.01) and near(lo[2], -LIQUID_HALF, 0.01) and near(hi[0], LIQUID_RADIUS, 0.05)):
        fails.append("Liquid z %.2f..%.2f r %.2f (want +-%.2f, r %.1f)" % (lo[2], hi[2], hi[0], LIQUID_HALF,
                                                                           LIQUID_RADIUS))
    if LIQUID_RADIUS >= 28.4 * math.cos(math.pi / JAR_SIDES) - 0.2:
        fails.append("the liquid's radius %.2f does not clear the glass's inner facets" % LIQUID_RADIUS)
    # the shards are the glass: their volumes add up to the glass's, and none pokes out of it
    vg = volume_cm3(objs["Glass"])
    vs = sum(volume_cm3(objs[s]) for s in SHARDS)
    if abs(vs - vg) > 0.01 * abs(vg):
        fails.append("the shards' volume %.0f cm3 != the glass's %.0f" % (vs, vg))
    glo, ghi = ue_bounds(objs["Glass"])
    for s in SHARDS:
        lo, hi = ue_bounds(objs[s])
        if (lo < glo - 0.05).any() or (hi > ghi + 0.05).any():
            fails.append("%s pokes out of the glass (%s .. %s)" % (s, np.round(lo, 2), np.round(hi, 2)))
    # the face dome clears the shut lid's ceiling, and its eyes sit over the band's rim (a peek shows them)
    lo, hi = ue_bounds(objs["Face"])
    ceiling = HINGE[2] + LID_CEILING
    if FACE_BASE + hi[2] > ceiling - 0.3:
        fails.append("the face dome's top %.1f reaches the shut lid's ceiling %.1f" % (FACE_BASE + hi[2], ceiling))
    if FACE_BASE + FACE_EYE_Z < BAND_Z1:
        fails.append("the eyes (z %.1f) sit under the band's rim (z %.1f)" % (FACE_BASE + FACE_EYE_Z, BAND_Z1))
    # the teeth: the band's stand on the ledge and stop under the shut lid's ceiling; the lid's hang to below the seam
    # and stop over the ledge; both rings clear the band's inside and the dome
    low_top = LEDGE[1] - 0.3 + 2.0 * TOOTH_HALF[2]
    lid_bottom = HINGE[2] + LID_CEILING + 0.3 - 2.0 * TOOTH_HALF[2]
    if low_top > ceiling - 0.5 or lid_bottom < LEDGE[1] + 0.5 or lid_bottom > BAND_Z1:
        fails.append("the teeth do not close: the band's reach z %.1f (ceiling %.1f), the lid's down to z %.1f (ledge %.1f,"
                     " seam %.1f)" % (low_top, ceiling, lid_bottom, LEDGE[1], BAND_Z1))
    reach = math.hypot(TOOTH_RING + TOOTH_HALF[0], TOOTH_HALF[1])
    if reach > band_inner - 0.2 or TOOTH_RING - TOOTH_HALF[0] < hi[0] + 1.0:
        fails.append("the tooth ring (r %.1f .. %.1f) does not fit between the dome (r %.1f) and the band (%.1f)"
                     % (TOOTH_RING - TOOTH_HALF[0], reach, hi[0], band_inner))
    eyes = ue_verts(objs["Face"])
    if FACE_BASE + FACE_RISE + eyes[:, 2].min() < 0.0:
        fails.append("Face has no vertices")
    # teeth interleave: lid teeth sit between rim teeth (at least 2 x the half width apart round the ring)
    gap = min(abs(((a - b + 180.0) % 360.0) - 180.0) for a in RIM_TEETH_DEG for b in LID_TEETH_DEG)
    arc = math.radians(gap) * TOOTH_RING
    if arc < 2.0 * 2.3 + 0.4:
        fails.append("the lid's and the rim's teeth are only %.1f cm apart round the ring" % arc)
    lo, hi = ue_bounds(objs["Lid"])
    if not (lo[0] > -2.5 and lo[2] >= -4.5 and hi[2] > LID_CROWN + 2.0):
        fails.append("Lid x from %.1f, z %.1f .. %.1f (want x > -2.5, z >= -4.5, knob over %.1f)"
                     % (lo[0], lo[2], hi[2], LID_CROWN + 2.0))
    lo, hi = ue_bounds(objs["Foot"])
    if not (near(lo[2], 0.0, 0.01) and FOOT_HEIGHT <= hi[2] <= FOOT_HEIGHT + 1.6):
        fails.append("Foot z %.2f..%.2f (want 0..%.1f + its cap)" % (lo[2], hi[2], FOOT_HEIGHT))
    # tucked, the jar sits low between its feet: no foot may cut into the glass, nor reach up to the bottom hoop
    inner = float(np.linalg.norm(LEG_FOOT[:2])) + float(lo[0])
    if inner < 30.3:
        fails.append("the feet's inner faces reach r %.1f, into the glass (r 30)" % inner)
    if hi[2] - (CLEARANCE - TUCK_DROP) > HOOPS[0][0]:
        fails.append("a tucked foot's top (body z %.1f) reaches the bottom hoop (z %.1f)" % (hi[2] - (CLEARANCE - TUCK_DROP),
                                                                                         HOOPS[0][0]))
    return fails


# ---------------------------------------------------------------- main
def main():
    args = cli_args({"export": False, "sheets": False, "save": False})
    clear_scene()
    bpy.context.scene.view_settings.view_transform = "Standard"
    fails = []
    objs, sockets, report = {}, {}, {}
    geos = {p: BUILDERS[p](np.random.default_rng(SEEDS[p])) for p in BUILDERS}
    shard_geos = build_shards(np.random.default_rng(SEEDS[SHARDS[0]]))
    for k, s in enumerate(SHARDS):
        geos[s] = (shard_geos[k], {})
    for part in PIECES:
        geo, sock = geos[part]
        o = to_object(piece_name(part), geo)
        add_sockets(o, sock)
        objs[part], sockets[part] = o, sock
        lo, hi = ue_bounds(o)
        tris = tri_count(o)
        health = mesh_health(o)
        report[part] = {"tris": tris, "min": np.round(lo, 2).tolist(), "max": np.round(hi, 2).tolist(),
                        "half_extents": np.round((hi - lo) * 0.5, 2).tolist(),
                        "centre": np.round((hi + lo) * 0.5, 2).tolist(),
                        "slots": [m.name for m in o.data.materials], "sockets": sock}
        print("%-32s tris %5d  min %s  max %s  slots %s  health %s  flipped shells %d" % (
            o.name, tris, np.round(lo, 1).tolist(), np.round(hi, 1).tolist(), report[part]["slots"], health,
            o["flipped_shells"]))
        if tris > TRIS_MAX[part]:
            fails.append("%s has %d tris > %d" % (o.name, tris, TRIS_MAX[part]))
        if health["open"] or health["nonmanifold"] or health["inconsistent"]:
            fails.append("%s mesh health %s" % (o.name, health))
        if health["degenerate"]:
            fails.append("%s has %d degenerate faces" % (o.name, health["degenerate"]))
    fails += contract_checks(objs)

    exported = []
    if args["export"]:
        exported = [(export_fbx(objs[p], sockets[p]), p) for p in PIECES]
        lay = {"builder": BUILDER, "frame": "Unreal cm; the jar's base centre at the origin; ground at z = -clearance",
               "clearance": CLEARANCE, "tuck_drop": TUCK_DROP, "hinge": HINGE.tolist(), "lid_open_deg": LID_OPEN_DEG,
               "face_base": FACE_BASE, "face_rise": FACE_RISE, "liquid_centre": LIQUID_CENTRE,
               "liquid_radius": LIQUID_RADIUS, "liquid_half": LIQUID_HALF,
               "brine_level": (BRINE_SURFACE - LIQUID_CENTRE) / LIQUID_HALF, "foot_height": FOOT_HEIGHT,
               "foot": LEG_FOOT.tolist(),
               "shard_centres": {s: report[s]["centre"] for s in SHARDS}, "pieces": report}
        with open(os.path.join(EXPORT_DIR, "PickleMimic_RestLayout.json"), "w") as fh:
            json.dump(lay, fh, indent=1)
    sheets = []
    if args["sheets"] or args["save"]:
        standing = pose(objs, "Stand") + [preview_pickles("Stand")]
        biting = pose(objs, "Bite", lid_open=1.0, step=10.0) + [preview_pickles("Bite")]
        disguised = pose(objs, "Tuck", drop=TUCK_DROP) + [preview_pickles("Tuck", drop=TUCK_DROP)]
        shattered = pose(objs, "Shatter", drop=TUCK_DROP, lid_open=0.35, shatter=14.0)
        if args["sheets"]:
            sheets = render_piece_sheets(objs)
            sheets.append(render_layout_sheet((("stand", standing), ("bite", biting), ("tuck", disguised),
                                               ("shatter", shattered))))
            hero, _ = render_hero((("bite_3q", biting, (2.05, 1.55, 1.35), (0.0, 0.0, 0.62)),
                                   ("disguise", disguised, (2.1, 1.2, 1.1), (0.0, 0.0, 0.45)),
                                   ("stand_side", standing, (0.3, 2.4, 1.0), (0.0, 0.0, 0.6)),
                                   ("shatter", shattered, (2.0, 1.6, 1.3), (0.0, 0.0, 0.4))))
            sheets += hero
    if args["save"]:
        os.makedirs(SOURCE_DIR, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=BLEND_FILE, copy=False)
        print("saved", BLEND_FILE)
    for path, part in exported:
        fails += reimport_check(path, objs[part], sockets[part])
    print("PICKLE_MIMIC_REPORT " + json.dumps({p: {k: v for k, v in r.items() if k != "sockets"} for p, r in report.items()}))
    if sheets:
        print("sheets:", *sheets, sep="\n  ")
    if fails:
        print("PICKLE_MIMIC_PIECES_FAIL", *fails, sep="\n  ")
    else:
        print("PICKLE_MIMIC_PIECES_OK")


if __name__ == "__main__":
    main()
