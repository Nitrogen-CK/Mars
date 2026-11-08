"""Pantry Rat R02 - model geometry (faceted, flat-shaded) built from the sheet-02 profiles.

Frame (unchanged from R01): 1 BU = 1 cm, rat faces +X, up +Z, rat LEFT (*_l) = Blender +Y, root at the origin.
Sheet-02 calibration (review/sheet_crops/sheet02_measure.json, PROGRESS.md "Calibration"): side view 6.6 px/cm, floor at
sheet y 438, sheet x 675.5 == world x 0; top / underside 5.55 / 5.5 px/cm. Every profile number below was read off those
crops in cm.

build() -> dict(parts={name: MB}, full=MB, land={landmark: Vector}, info={...}). Left-side parts are mirrored into `full`.
Weights are not assigned here (R5 skins to the frozen 26-bone rig).
"""
import math

from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

import rat_common as rc
from rat_common import MB, PAL, PART, X, Y, Z, nrm, lerp, smooth

S = 1.0  # global uniform scale knob (1.0 = back top 35 cm, sheet-02 drawn proportions)

P = {
    # one loft from the rump to the snout end: (x, z_top, z_bot, half width, z of max width, n_top, n_bot)
    # superellipse cross-sections: |y/hw|^n + |dz/r|^n = 1, r = z_top - z_w above, z_w - z_bot below
    "LOFT": [
        (-29.0, 22.4, 15.4, 4.2, 19.0, 2.0, 2.0),
        (-28.0, 25.8, 11.6, 7.4, 18.2, 2.0, 2.2),
        (-26.2, 28.6, 9.0, 10.2, 17.2, 2.1, 2.5),
        (-23.6, 31.3, 7.4, 12.6, 16.6, 2.2, 2.8),
        (-20.0, 33.4, 6.4, 14.3, 15.8, 2.2, 3.0),
        (-16.0, 34.7, 5.9, 15.1, 15.6, 2.2, 3.0),
        (-11.0, 35.2, 5.8, 15.5, 15.8, 2.2, 3.0),
        (-6.0, 35.1, 6.0, 15.5, 16.0, 2.2, 3.0),
        (-1.5, 34.4, 6.6, 15.0, 16.6, 2.2, 3.0),
        (2.5, 34.0, 8.0, 13.9, 17.6, 2.2, 2.8),
        (5.6, 33.4, 9.0, 12.9, 18.2, 2.2, 2.6),
        (8.2, 32.8, 9.8, 12.6, 18.2, 2.2, 2.4),
        (11.0, 32.0, 10.2, 12.6, 18.0, 2.3, 2.4),
        (14.0, 30.2, 10.8, 12.0, 17.8, 2.4, 2.5),
        (17.0, 27.8, 12.2, 10.4, 17.8, 2.7, 2.6),
        (19.6, 25.6, 12.9, 8.2, 18.0, 3.1, 2.6),
        (22.2, 23.6, 13.2, 6.5, 17.8, 3.5, 2.6),
        (24.6, 21.5, 13.3, 5.0, 17.4, 3.8, 2.6),
        (26.6, 20.2, 13.4, 4.2, 16.9, 3.8, 2.6),
    ],
    "LOFT_CAPS": ((-29.9, 19.2), (27.0, 16.8)),
    "LOFT_SIDES": 20,
    "HEAD_X": 10.0,          # loft vertices with x >= HEAD_X are tagged head (colour split for the belly below)
    # nose block (pink): x range, z range, half width
    "NOSE": {"x0": 25.8, "x1": 30.0, "z0": 12.2, "z1": 18.6, "hw": 4.5},
    # lower jaw (split for the carry): stations (x, z_bot, z_top, half width); hinge near x 13.5
    "JAW": [(13.0, 10.6, 15.2, 7.0), (17.0, 10.8, 13.9, 6.0), (21.0, 11.0, 13.7, 5.0), (25.0, 11.3, 13.4, 4.0), (27.4, 11.8, 13.0, 3.0)],
    # ears: centre, width (along the ear's side axis), height (along up), facing normal, up hint (left side)
    "EAR_C": (7.2, 14.0, 30.2), "EAR_W": 10.6, "EAR_H": 12.8, "EAR_N": (0.74, 0.58, 0.24), "EAR_UP": (-0.22, 0.62, 0.76),
    # eye patch (left): centre direction from the head axis point, radii along forward / up
    # flat facet: the head surface within EYE_FLAT of the eye centre is pressed onto the eye plane (normal EYE_N), the
    # patch is a planar polygon EYE_OFF proud of that plane
    "EYE_AXIS": (17.6, 0.0, 20.0), "EYE_DIR": (0.42, 1.0, 0.10), "EYE_N": (0.64, 0.75, 0.16), "EYE_SINK": 0.45,
    "EYE_FLAT": 6.6, "EYE_FADE": 1.8, "EYE_RS": 3.6, "EYE_RU": 4.7, "EYE_OFF": 0.2, "EYE_LEAN": -16.0,   # R7: 1.3x taller than wide, top toward the ears
    # limbs (left): upper-limb mass centre + radii (x, y, z); joint chain shoulder/hip, elbow/knee, wrist/heel, toe tip
    # R3: shoulder / hip, elbow / knee (elbow points back, knee forward), wrist / heel, toe tip; stance |y| from the
    # sheet underside (fore paws 11, hind 11.8)
    "FORE_MASS": ((6.4, 10.0, 11.0), (5.0, 4.0, 6.2)),
    "HIND_MASS": ((-17.6, 10.6, 11.8), (7.2, 4.6, 7.8)),
    "FORE": ((6.8, 10.0, 12.5), (5.4, 10.8, 6.6), (8.8, 11.0, 2.0), (13.2, 11.0, 0.0)),
    "HIND": ((-16.5, 10.8, 13.0), (-12.6, 12.0, 6.4), (-22.0, 11.8, 2.3), (-13.4, 11.8, 0.0)),
    "KNOB_R": {"fore": (2.2, 1.55), "hind": (2.6, 1.75)},     # elbow / knee, wrist / heel
    "SHIN_R": {"fore": (1.85, 1.35), "hind": (2.1, 1.45)},
    "PAW_HW": {"fore": 2.3, "hind": 2.5},
    "TOES": {"fore": 4, "hind": 5},
    "TOE_R": {"fore": (1.15, 0.78, 0.78), "hind": (1.2, 0.72, 0.8)},
    # tail control points (side view: back, droop, curl forward)
    "TAIL": [(-27.6, 0.0, 16.6), (-32.0, 0.0, 15.8), (-36.5, 0.0, 13.4), (-40.5, 0.0, 11.0), (-43.2, 0.0, 8.4),
             (-44.2, 0.0, 6.0), (-43.4, 0.0, 3.9), (-41.2, 0.0, 2.9), (-39.0, 0.0, 3.4)],
    "TAIL_BONE_IDX": (0, 2, 4, 6, 8),
    "TAIL_R": (2.5, 0.55),
    # spoon (local: handle end at 0 along +X, bowl concave side +Z); placed by its handle end and bowl centre targets
    "SPOON_HANDLE": 23.0, "SPOON_NECK": 2.4, "SPOON_BOWL_HL": 6.4, "SPOON_BOWL_HW": 5.2,
    "SPOON_END": (-16.0, -15.0, 9.0), "SPOON_BOWL": (-1.6, -7.0, 33.5), "SPOON_CONCAVE": (0.62, -0.74, 0.25),
    "SPOON_GAP": 0.8,   # R5: room for the leather cuffs under the handle
    # harness (R4): girth round the mid-body + one diagonal chest strap (bandolier) from over the right shoulder, across
    # the chest, under the left foreleg and back over the withers; both hug the torso (inner face BAND_EMBED inside)
    "BAND_X": None, "BAND_W": 3.0, "BAND_T": 0.5, "BAND_EMBED": 0.05,   # BAND_X None: at the spoon flank contact (R5)
    "STRAP_PTS": ((-6.0, -15.0, 27.5), (5.0, 0.0, 10.0), (-10.0, 15.4, 18.0)),   # right flank (cuff), chest front, left flank (girth)
    "STRAP_W": 2.6, "STRAP_ON_HANDLE": 0.82,
    # cream belly sector half-angle (deg from straight down) along x: chest -> rump; clean loop along mesh edges
    "BELLY_SECTOR": ((-25.5, 0.0), (-23.0, 38.0), (-18.0, 56.0), (0.0, 56.0), (5.0, 42.0), (9.5, 0.0)),
}


def sv(p):
    return Vector(p) * S


# ---------------------------------------------------------------- loft
def section(st, sides, k):
    x, zt, zb, hw, zw, nt, nb = st
    off = (math.pi / sides) * (k % 2)
    out = []
    for j in range(sides):
        th = 2 * math.pi * j / sides + off           # 0 = top, pi = bottom
        c, s = math.cos(th), math.sin(th)
        n = nt if c >= 0 else nb
        r = (zt - zw) if c >= 0 else (zw - zb)
        yy = hw * math.copysign(abs(s) ** (2.0 / n), s)
        zz = zw + r * math.copysign(abs(c) ** (2.0 / n), c)
        out.append(Vector((x, yy, zz)))
    return out


def loft_axis(x):
    L = P["LOFT"]
    if x <= L[0][0]:
        return Vector((x, 0, L[0][4]))
    for a, b in zip(L, L[1:]):
        if a[0] <= x <= b[0]:
            t = (x - a[0]) / (b[0] - a[0])
            return Vector((x, 0, lerp(a[4], b[4], t)))
    return Vector((x, 0, L[-1][4]))


def loft_at(x):
    """Interpolated station (for surface queries)."""
    L = P["LOFT"]
    x = max(L[0][0], min(L[-1][0], x))
    for a, b in zip(L, L[1:]):
        if a[0] <= x <= b[0]:
            t = (x - a[0]) / (b[0] - a[0])
            return tuple(lerp(u, v, t) for u, v in zip(a, b))
    return L[-1]


def belly_halfangle(x):
    """Half-angle (deg, from straight down) of the cream belly sector at loft station x: chest (x 9) to the rump
    under the tail root (x -25); 0 outside. Cream never reaches the jaw or the mouth line."""
    T = P["BELLY_SECTOR"]
    if x <= T[0][0] or x >= T[-1][0]:
        return 0.0
    for (x0, w0), (x1, w1) in zip(T, T[1:]):
        if x0 <= x <= x1:
            return lerp(w0, w1, (x - x0) / (x1 - x0))
    return 0.0


def build_loft():
    mb = MB("Loft")
    L, sides = P["LOFT"], P["LOFT_SIDES"]
    loops, theta = [], {}
    for k, st in enumerate(L):
        ring = []
        off = (math.pi / sides) * (k % 2)
        for j, p in enumerate(section(st, sides, k)):
            vi = mb.vert(p)
            theta[vi] = (2 * math.pi * j / sides + off, st[0])
            ring.append(vi)
        loops.append(ring)
    faces = []
    for k, (a, b) in enumerate(zip(loops, loops[1:])):
        for j in range(sides):
            j1 = (j + 1) % sides
            if k % 2 == 0:
                faces += [(a[j], a[j1], b[j]), (b[j], a[j1], b[j1])]
            else:
                faces += [(a[j], b[j1], b[j]), (a[j], a[j1], b[j1])]
    (xb, zb), (xf, zf) = P["LOFT_CAPS"]
    cb = mb.vert((xb, 0, zb))
    cf = mb.vert((xf, 0, zf))
    for j in range(sides):
        faces.append((loops[0][(j + 1) % sides], loops[0][j], cb))
        faces.append((loops[-1][j], loops[-1][(j + 1) % sides], cf))

    def in_belly(vi):
        if vi not in theta:
            return False
        th, x = theta[vi]
        w = belly_halfangle(x)
        return w > 0 and abs(th - math.pi) <= math.radians(w) + 1e-6
    nb = 0
    for f in faces:
        c = sum((mb.v[i] for i in f), Vector()) / 3
        part = PART["head"] if c.x >= P["HEAD_X"] else PART["torso"]
        if all(in_belly(i) for i in f):
            mb.face(f, "Belly", PAL["Belly"], part, 0.04)
            nb += 1
        else:
            mb.face(f, "Body", PAL["Body"], part, 0.05)
    mb.belly_faces = nb
    return mb


def build_nose():
    """Pink nose block: buried back ring, side band, a flat front disc with two dented nostrils (closed solid)."""
    mb = MB("Nose")
    N = P["NOSE"]
    x0, x1, z0, z1, hw = N["x0"], N["x1"], N["z0"], N["z1"], N["hw"]
    zc, rz = (z0 + z1) / 2, (z1 - z0) / 2
    K = 8
    ang = [2 * math.pi * i / K + math.pi / K for i in range(K)]
    # rounded profile: back ring (buried) -> widest ring 1 cm behind the face -> bevel ring -> flat disc
    back = [mb.vert((x0, hw * 0.92 * math.cos(a), zc + rz * 0.92 * math.sin(a))) for a in ang]
    mid = [mb.vert((x1 - 1.0, hw * math.cos(a), zc + rz * math.sin(a))) for a in ang]
    front = [mb.vert((x1 - 0.15, hw * 0.80 * math.cos(a), zc + rz * 0.80 * math.sin(a))) for a in ang]
    ring2 = [mb.vert((x1 + 0.22, hw * 0.65 * math.cos(a + math.pi / K), zc + rz * 0.65 * math.sin(a + math.pi / K)))
             for a in ang]   # R7: one more (staggered) ring rounds the dome's front face
    inner = [mb.vert((x1 + 0.5, hw * 0.46 * math.cos(a), zc + rz * 0.46 * math.sin(a))) for a in ang]
    nost = [mb.vert((x1 - 0.2, sy * hw * 0.46, zc - 0.2)) for sy in (1, -1)]
    cb = mb.vert((x0 - 0.4, 0, zc))
    cf = mb.vert((x1 + 0.7, 0, zc + 0.3))   # dome apex
    pink, dark = PAL["Pink"], tuple(c * 0.62 for c in PAL["Pink"])
    pf = PART["nose"]
    for i in range(K):
        i1 = (i + 1) % K
        mb.face((back[i1], back[i], cb), "Pink", pink, pf, 0.03)
        mb.face((back[i], back[i1], mid[i1]), "Pink", pink, pf, 0.03)
        mb.face((back[i], mid[i1], mid[i]), "Pink", pink, pf, 0.03)
        mb.face((mid[i], mid[i1], front[i1]), "Pink", pink, pf, 0.03)
        mb.face((mid[i], front[i1], front[i]), "Pink", pink, pf, 0.03)
        mb.face((front[i], front[i1], ring2[i]), "Pink", pink, pf, 0.03)
        mb.face((ring2[i], front[i1], ring2[i1]), "Pink", pink, pf, 0.03)
        mb.face((ring2[i], ring2[i1], inner[i1]), "Pink", pink, pf, 0.03)
        mb.face((ring2[i], inner[i1], inner[i]), "Pink", pink, pf, 0.03)
    # inner disc: fan to the centre, except the two nostril pits (left: around angle 0, right: around pi)
    for i in range(K):
        i1 = (i + 1) % K
        am = ang[i] + math.pi / K
        c = math.cos(am)
        if abs(c) > 0.85:
            n = nost[0] if c > 0 else nost[1]
            mb.face((inner[i], inner[i1], n), "Pink", dark, pf, 0.0)
            mb.face((inner[i1], cf, n), "Pink", dark, pf, 0.0)
            mb.face((cf, inner[i], n), "Pink", dark, pf, 0.0)
        else:
            mb.face((inner[i], inner[i1], cf), "Pink", pink, pf, 0.03)
    return mb


def build_jaw():
    """Lower jaw wedge under the snout (separate solid; rotates about the hinge for the carry)."""
    mb = MB("Jaw")
    pts = []
    for (x, zb, zt, hw) in P["JAW"]:
        for k in range(6):
            a = math.pi * k / 5
            pts.append(Vector((x, hw * math.cos(a), zb + (zt - zb) * 0.25 * (1 - math.sin(a)))))
            pts.append(Vector((x, hw * 0.9 * math.cos(a), zt)))
    x, zb, zt, hw = P["JAW"][-1]
    pts.append(Vector((x + 1.0, 0.0, zb + 0.5)))

    def colfn(n, c):
        return "Body", PAL["Body"]
    rc.hull(mb, pts, None, "Body", PAL["Body"], PART["jaw"], 0.05, colfn=colfn)
    return mb


# ---------------------------------------------------------------- ears
def ear_frame(side=1):
    s = Vector((1, side, 1))
    n = nrm(Vector(P["EAR_N"]) * s)
    up = Vector(P["EAR_UP"]) * s
    up = nrm(up - n * up.dot(n))
    sd = n.cross(up)
    c = Vector(P["EAR_C"]) * s
    return c, n, up, sd


EAR_OUTLINE = [(-0.50, -0.55), (-0.62, -0.05), (-0.46, 0.38), (-0.12, 0.50), (0.30, 0.44), (0.56, 0.12),
               (0.52, -0.30), (0.16, -0.55)]   # angular shield (side, up) in units of (width, height), base at the bottom


def build_ear(side=1):
    mb = MB("Ear")
    c, n, up, sd = ear_frame(side)
    W, H = P["EAR_W"], P["EAR_H"]
    K = len(EAR_OUTLINE)
    rim = [mb.vert(c + sd * (u * W) + up * (v * H)) for u, v in EAR_OUTLINE]
    inner = [mb.vert(c + sd * (u * W * 0.62) + up * (v * H * 0.62 - 0.06 * H) - n * 0.5) for u, v in EAR_OUTLINE]
    back = [mb.vert(c + sd * (u * W * 0.8) + up * (v * H * 0.8) - n * 1.5) for u, v in EAR_OUTLINE]
    cf = mb.vert(c - up * 0.06 * H - n * 1.0)
    cb = mb.vert(c - n * 2.2)
    pin = tuple(x * 0.84 for x in PAL["Pink"])
    for i in range(K):
        i1 = (i + 1) % K
        mb.face((rim[i], rim[i1], inner[i1]), "Pink", PAL["Pink"], PART["ear"], 0.04)
        mb.face((rim[i], inner[i1], inner[i]), "Pink", PAL["Pink"], PART["ear"], 0.04)
        mb.face((inner[i], inner[i1], cf), "Pink", pin, PART["ear"], 0.04)
        mb.face((rim[i1], rim[i], back[i]), "Pink", PAL["Pink"], PART["ear"], 0.04)
        mb.face((rim[i1], back[i], back[i1]), "Pink", PAL["Pink"], PART["ear"], 0.04)
        mb.face((back[i1], back[i], cb), "Pink", PAL["Pink"], PART["ear"], 0.04)
    if side < 0:
        mb.f = [f[::-1] for f in mb.f]
    return mb


# ---------------------------------------------------------------- limbs
def ellipsoid_pts(c, r, nu=6, nv=4, rot=0.0):
    c, out = Vector(c), []
    for i in range(1, nv):
        ph = math.pi * i / nv - math.pi / 2
        for j in range(nu):
            th = 2 * math.pi * j / nu + rot + (math.pi / nu) * (i % 2)
            out.append(c + Vector((r[0] * math.cos(ph) * math.cos(th), r[1] * math.cos(ph) * math.sin(th),
                                   r[2] * math.sin(ph))))
    out += [c + Vector((0, 0, r[2])), c - Vector((0, 0, r[2]))]
    return out


def build_leg(kind):
    """Three readable segments (sheet 03 "LEG (SIDE) - STRUCTURE"): a chunky upper limb (shoulder / haunch mass tapering
    to a knee or elbow knob), a narrower lower limb ending in a heel / wrist knob, and a small pink paw with
    P["TOES"][kind] separate toes fanned across its front."""
    mb = MB("Leg")
    fore = kind == "fore"
    mass = P["FORE_MASS"] if fore else P["HIND_MASS"]
    a, b, c, d = [Vector(p) for p in (P["FORE"] if fore else P["HIND"])]
    rk = P["KNOB_R"][kind]
    # upper limb: the flank mass plus a ring just above the knee, so the segment tapers into the joint
    pts = ellipsoid_pts(mass[0], mass[1], 7, 4, 0.3)
    e1, e2 = rc.ring_frame(b - a)
    pts += [b + (b - a).normalized() * -1.2 + (e1 * math.cos(t) + e2 * math.sin(t)) * rk[0] * 1.05
            for t in (0.3, 1.9, 3.5, 5.1)]
    rc.hull(mb, pts, None, "Body", PAL["Body"], PART["leg_upper"], 0.05)
    rc.hull(mb, ellipsoid_pts(b, (rk[0], rk[0] * 0.92, rk[0]), 6, 3, 0.2), None, "Body", PAL["Body"],
            PART["leg_upper"], 0.05)
    # lower limb: knee / elbow -> heel / wrist, hexagonal, tapering, with a heel / wrist knob
    r0, r1 = P["SHIN_R"][kind]
    seg = [b.lerp(c, t) for t in (0.0, 0.5, 1.0)]
    rc.tube(mb, seg, [lerp(r0, r1, t) for t in (0.0, 0.5, 1.0)], [None] * 3, "Body", PAL["Body"], PART["leg_lower"],
            sides=6, ref=X, jitter=0.04)
    rc.hull(mb, ellipsoid_pts(c + Vector((0, 0, 0.2)), (rk[1], rk[1] * 0.9, rk[1]), 6, 3, 0.4), None, "Body",
            PAL["Body"], PART["leg_lower"], 0.05)
    # paw: a low pink pad from the heel / wrist to the toe roots
    fw = P["PAW_HW"][kind]
    x0, x1 = c.x - (0.8 if fore else 1.4), d.x - 1.6
    yc = lerp(c.y, d.y, 0.5)
    paw = []
    for (fx, wf, h) in ((x0, 0.7, 2.1), (lerp(x0, x1, 0.5), 0.95, 2.0), (x1, 1.0, 1.5)):
        for sy in (-1, 1):
            for z in (0.0, h):
                paw.append(Vector((fx, yc + sy * fw * wf, z)))
    paw.append(Vector((lerp(x0, x1, 0.3), yc, 2.3)))
    rc.hull(mb, paw, None, "Pink", PAL["Pink"], PART["foot"], 0.04)
    # toes: a fan of small rounded solids; the middle toes reach furthest, hind outer toe (dewclaw) set back
    n = P["TOES"][kind]
    tr = P["TOE_R"][kind]
    for k in range(n):
        u = (k / (n - 1)) * 2 - 1                    # -1 .. 1 across the paw
        reach = 1.0 - 0.35 * u * u
        tc = Vector((x1 + 0.2 + 1.3 * reach, yc + u * fw * 0.92, tr[2]))
        if not fore and k == 0:
            tc = Vector((x1 - 0.9, yc + u * fw * 1.05, tr[2]))
        rc.hull(mb, ellipsoid_pts(tc, tr, 5, 3, 0.0), None, "Pink", PAL["Pink"], PART["foot"], 0.03)
    return mb


# ---------------------------------------------------------------- tail
def catmull(pts, n_per):
    pts = [Vector(p) for p in pts]
    out = []
    for i in range(len(pts) - 1):
        p0, p1, p2, p3 = pts[max(0, i - 1)], pts[i], pts[i + 1], pts[min(len(pts) - 1, i + 2)]
        for k in range(n_per):
            t = k / n_per
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
                              (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    return out


def tail_bone_points():
    T = [Vector(p) for p in P["TAIL"]]
    return [T[i] for i in P["TAIL_BONE_IDX"]]


def build_tail():
    mb = MB("Tail")
    pts = catmull(P["TAIL"], 2)
    L = [0.0]
    for a, b in zip(pts, pts[1:]):
        L.append(L[-1] + (b - a).length)
    tot = L[-1]
    bp = tail_bone_points()
    jl = [L[min(range(len(pts)), key=lambda i: (pts[i] - q).length)] for q in bp]
    radii = []
    for s in L:
        r = lerp(P["TAIL_R"][0], P["TAIL_R"][1], (s / tot) ** 0.8)
        if min(abs(s - jl[i]) for i in range(1, 4)) < 1.0:
            r *= 0.84
        radii.append(r)
    rc.tube(mb, pts, radii, [None] * len(pts), "Pink", PAL["Pink"], PART["tail"], sides=7, ref=Z, jitter=0.04)
    return mb, tot


# ---------------------------------------------------------------- spoon
def spoon_local_mb():
    mb = MB("Spoon")
    LH, LN, BL, BW = P["SPOON_HANDLE"], P["SPOON_NECK"], P["SPOON_BOWL_HL"], P["SPOON_BOWL_HW"]
    xs = [0.0, 1.0, LH * 0.35, LH * 0.7, LH, LH + LN]
    hw = [1.55, 1.85, 1.8, 1.6, 1.35, 1.9]
    rc.tube(mb, [Vector((x, 0, 0)) for x in xs], hw, [None] * len(xs), "Wood", PAL["Wood"], PART["spoon"], sides=6,
            ref=Y, jitter=0.06, flat=0.5, stagger=False)
    cx = LH + LN + BL - 0.7
    K = 12
    rim, inn, und = [], [], []
    for i in range(K):
        a = 2 * math.pi * i / K
        ca, sa = math.cos(a), math.sin(a)
        ex = BL * ca * (1.0 if ca > 0 else 0.9)
        rim.append(mb.vert((cx + ex, BW * sa, 1.0)))
        inn.append(mb.vert((cx + ex * 0.8, BW * 0.8 * sa, 0.6)))
        und.append(mb.vert((cx + ex * 0.86, BW * 0.86 * sa, -1.8)))
    cin = mb.vert((cx, 0, -1.6))
    cun = mb.vert((cx, 0, -2.8))
    wood, wood_in = PAL["Wood"], tuple(x * 0.82 for x in PAL["Wood"])
    for i in range(K):
        i1 = (i + 1) % K
        mb.face((rim[i], rim[i1], inn[i1]), "Wood", wood, PART["spoon"], 0.06)
        mb.face((rim[i], inn[i1], inn[i]), "Wood", wood, PART["spoon"], 0.06)
        mb.face((inn[i], inn[i1], cin), "Wood", wood_in, PART["spoon"], 0.06)
        mb.face((rim[i1], rim[i], und[i]), "Wood", wood, PART["spoon"], 0.06)
        mb.face((rim[i1], und[i], und[i1]), "Wood", wood, PART["spoon"], 0.06)
        mb.face((und[i1], und[i], cun), "Wood", wood, PART["spoon"], 0.06)
    return mb, cx


def mb_tree(mbs, parts=None):
    vs, fs = [], []
    for mb in mbs:
        off = len(vs)
        vs.extend(mb.v)
        for f, pt in zip(mb.f, mb.fp):
            if parts is None or pt in parts:
                fs.append(tuple(i + off for i in f))
    return BVHTree.FromPolygons(vs, fs, all_triangles=False, epsilon=0.0)


def spoon_place(body_tree, spoon_local, bowl_cx):
    """Frame from the handle-end and bowl-centre targets, then slid out along the contact normal until the whole
    spoon clears the body by SPOON_GAP (a straight spoon tangent to the round flank, handle end standing off)."""
    E, B = Vector(P["SPOON_END"]), Vector(P["SPOON_BOWL"])
    d = nrm(B - E)
    up = Vector(P["SPOON_CONCAVE"])
    up = nrm(up - d * up.dot(d))
    side = up.cross(d)
    R = Matrix((d, side, up)).transposed()
    scale = (B - E).length / bowl_cx

    def frame(off):
        M = R.to_4x4()
        M.translation = E + off
        return M

    def clear(M):
        worst = 1e9
        for p in spoon_local.v:
            q = M @ p
            loc, n, _, dist = body_tree.find_nearest(q)
            worst = min(worst, dist if (q - loc).dot(n) >= 0 else -dist)
        return worst
    out = nrm(Vector((0, -0.3, 1.0)) - d * Vector((0, -0.3, 1.0)).dot(d))
    lo, hi = -3.0, 12.0
    for _ in range(30):
        mid = 0.5 * (lo + hi)
        if clear(frame(out * mid)) >= P["SPOON_GAP"]:
            hi = mid
        else:
            lo = mid
    M = frame(out * hi)
    best = (1e9, None, None)
    for p in spoon_local.v:
        q = M @ p
        loc, n, _, dist = body_tree.find_nearest(q)
        sd = dist if (q - loc).dot(n) >= 0 else -dist
        if sd < best[0]:
            best = (sd, tuple(round(c, 2) for c in q), tuple(round(c, 2) for c in loc))
    return M, {"slide_out_cm": hi, "binding_contact_spoon_body": best[1:], "clearance": clear(M), "length_target_vs_model": (B - E).length / bowl_cx,
               "handle_end": tuple(M @ Vector((0, 0, 0))), "bowl_centre": tuple(M @ Vector((bowl_cx, 0, 0)))}


def build_ring_strap(body_tree, spoon_tree, centre, u, v, W, part, name, N=40, arc=None):
    """Leather strap round the torso in the plane (centre, u, v): per ray, inner face BAND_EMBED inside the widest of
    three hits across the strap width (width axis = u x v), lifted radially where it would cut the spoon.
    arc=(a0, a1): an open strap over that angle range (radians from u toward v), capped at both ends."""
    closed = arc is None
    mb = MB(name)
    T = P["BAND_T"]
    wax = u.cross(v).normalized()
    meta = []
    for i in range(N):
        ph = 2 * math.pi * i / N if closed else lerp(arc[0], arc[1], i / (N - 1))
        dirv = (u * math.cos(ph) + v * math.sin(ph)).normalized()
        best = None
        for dx in (-W / 2, 0.0, W / 2):
            o = centre + wax * dx
            loc, n, _, _ = body_tree.ray_cast(o + dirv * 60.0, -dirv, 200.0)
            if loc is None:
                continue
            r_ = (loc - o).dot(dirv)
            best = r_ if best is None else max(best, r_)
        base = centre + dirv * (best - P["BAND_EMBED"])
        meta.append([base, dirv, 0.0])
    if spoon_tree is not None:
        # lift each ray until the strap segments on both sides of it (sampled along the chord, across the width and
        # through the thickness) clear the spoon by 0.3 cm
        def seg_hits(i, li):
            b0, d0, _ = meta[i]
            hit = False
            for nb in ((i + 1) % N, (i - 1) % N):
                if not closed and abs(nb - i) != 1:
                    continue
                b1, d1, l1 = meta[nb]
                for t in (0.0, 0.125, 0.25, 0.375, 0.5):
                    for dw in (-W / 2, -W / 4, 0.0, W / 4, W / 2):
                        for dt in (0.0, T):
                            q = (b0 + d0 * (li + dt)).lerp(b1 + d1 * (max(l1, li) + dt), t) + wax * dw
                            l2, n2, _, d2 = spoon_tree.find_nearest(q)
                            if l2 is not None and (d2 < 0.3 or (d2 < 2.0 and (q - l2).dot(n2) < 0)):
                                return True
            return hit
        for _ in range(3):
            for i in range(N):
                for _k in range(40):
                    if not seg_hits(i, meta[i][2]):
                        break
                    meta[i][2] += 0.25
    lifts = [m[2] for m in meta]
    sm = [max(lifts[(i + k) % N] * (1 - abs(k) / 3.0) for k in range(-2, 3)) for i in range(N)]
    sm = [max(a_, b_) for a_, b_ in zip(sm, lifts)]
    rings = []
    for i, (base, n, _) in enumerate(meta):
        p_in = base + n * sm[i]
        p_out = p_in + n * T
        rings.append([mb.vert(p_in - wax * (W / 2)), mb.vert(p_out - wax * (W / 2)), mb.vert(p_out + wax * (W / 2)),
                      mb.vert(p_in + wax * (W / 2))])
    for i in range(N if closed else N - 1):
        a, b = rings[i], rings[(i + 1) % N]
        for j in range(4):
            j1 = (j + 1) % 4
            mb.face((a[j], a[j1], b[j1]), "Harness", PAL["Harness"], part, 0.04)
            mb.face((a[j], b[j1], b[j]), "Harness", PAL["Harness"], part, 0.04)
    if not closed:
        r0, r1 = rings[0], rings[-1]
        mb.face((r0[0], r0[2], r0[1]), "Harness", PAL["Harness"], part, 0.04)
        mb.face((r0[0], r0[3], r0[2]), "Harness", PAL["Harness"], part, 0.04)
        mb.face((r1[0], r1[1], r1[2]), "Harness", PAL["Harness"], part, 0.04)
        mb.face((r1[0], r1[2], r1[3]), "Harness", PAL["Harness"], part, 0.04)
    return mb, max(sm), [m[0] for m in meta]


def build_band(body_tree, spoon_tree, bxp=None):
    bxp = P["BAND_X"] if bxp is None else bxp
    zc = loft_at(bxp)[4]
    mb, lift, _ = build_ring_strap(body_tree, spoon_tree, Vector((bxp, 0.0, zc)), Y, Z, P["BAND_W"], PART["band"],
                                   "Band")
    return mb, lift


def build_chest_strap(body_tree, spoon_tree, spoon_M=None):
    """Breast strap: an open arc hugging the torso from the spoon cuff high on the right flank, diagonally down round
    the front of the chest under the neck, to the girth low on the left flank (sheet 02 side / hero: the strap runs
    from the spoon forward across the shoulder into the chest)."""
    R_, F_, L_ = (Vector(p) for p in P["STRAP_PTS"])
    if spoon_M is not None:   # the strap leaves the handle at STRAP_ON_HANDLE along it, just under its back face
        R_ = spoon_M @ Vector((P["SPOON_HANDLE"] * P["STRAP_ON_HANDLE"], 0.0, -1.2))
    centre = (R_ + L_) / 2
    n = (R_ - centre).cross(F_ - centre).normalized()
    u = (R_ - centre).normalized()
    v = n.cross(u)
    if v.dot(F_ - centre) < 0:
        v, n = -v, -n
    aL = math.atan2((L_ - centre).dot(v), (L_ - centre).dot(u))
    if aL < 0:
        aL += 2 * math.pi
    mb, lift, pts = build_ring_strap(body_tree, spoon_tree, centre, u, v, P["STRAP_W"], PART["strap"], "ChestStrap",
                                     N=26, arc=(0.0, aL))
    return mb, lift, {"plane_normal": tuple(round(c, 3) for c in n), "centre": tuple(round(c, 2) for c in centre),
                      "arc_deg": round(math.degrees(aL), 1)}


def add_cuff(spoon_local, s_along, hw):
    """Leather sleeve round the handle at s_along (spoon-local x)."""
    xs = [s_along - 1.4, s_along - 0.45, s_along + 0.45, s_along + 1.4]
    rc.tube(spoon_local, [Vector((x, 0, 0)) for x in xs], [hw + 0.4] * 4, [None] * 4, "Harness", PAL["Harness"],
            PART["cuff"], sides=8, ref=Y, jitter=0.03, flat=0.62, stagger=False)


def spoon_param_nearest(spoon_M, pts):
    """Spoon-local x of the handle point nearest to any of pts (where a strap crosses the handle)."""
    Mi = spoon_M.inverted()
    best = None
    for p in pts:
        q = Mi @ p
        d = Vector((0, q.y, q.z)).length
        if 0.0 < q.x < P["SPOON_HANDLE"] and (best is None or d < best[0]):
            best = (d, q.x)
    return best


# ---------------------------------------------------------------- eye facets + patches (R01 UV convention, verbatim)
def eye_plane(head_tree, side):
    ax = Vector(P["EYE_AXIS"])
    dirv = nrm(Vector(P["EYE_DIR"]) * Vector((1, side, 1)))
    Pc, _, _, _ = head_tree.ray_cast(ax + dirv * 40.0, -dirv, 200.0)
    N = nrm(Vector(P["EYE_N"]) * Vector((1, side, 1)))
    return Pc - N * P["EYE_SINK"], N


def flatten_eye(mb, C, N):
    """Press the head vertices near the eye onto the eye plane: a flat facet the patch lies on."""
    moved = 0
    for i, v in enumerate(mb.v):
        if v.x < P["HEAD_X"]:
            continue
        d = (v - C).dot(N)
        r = ((v - C) - N * d).length
        if -2.5 < d and r < P["EYE_FLAT"] + P["EYE_FADE"]:
            w = 1.0 if r <= P["EYE_FLAT"] else 1.0 - smooth((r - P["EYE_FLAT"]) / P["EYE_FADE"])
            if d > 0 or r <= P["EYE_FLAT"]:
                mb.v[i] = v - N * d * w
                moved += 1
    return moved


def build_eye_patch(C, N, side):
    mb = MB("EyePatch")
    eu = nrm(Z - N * N.dot(Z))
    ef = nrm(X - N * N.dot(X) - eu * eu.dot(X))
    rs, ru, off = P["EYE_RS"], P["EYE_RU"], P["EYE_OFF"]
    K = 10   # R7: upright almond / oval (taller than wide, soft points top and bottom), its top leaning back toward the
    # ears by EYE_LEAN (negative = top toward -forward)
    st = []
    lean = math.radians(P["EYE_LEAN"])
    for k in range(K):
        a = 2 * math.pi * k / K + math.pi / 2
        s0 = rs * math.cos(a) * (0.7 + 0.3 * abs(math.cos(a)))
        t0 = ru * math.sin(a)
        st.append((s0 * math.cos(lean) + t0 * math.sin(lean), -s0 * math.sin(lean) + t0 * math.cos(lean)))
    smax = max(abs(s_) for s_, _ in st)
    tmax = max(abs(t) for _, t in st)

    def uv(s_, t):
        f = s_ / smax   # +1 front edge, -1 back edge
        u = 0.25 + 0.25 * f if side > 0 else 0.75 - 0.25 * f
        return (u, 0.5 + 0.5 * t / tmax)
    O = C + N * off
    ids = [mb.vert(O + ef * s_ + eu * t) for s_, t in st]
    cen = mb.vert(O)
    uvs = [uv(s_, t) for s_, t in st]
    for k in range(K):
        k1 = (k + 1) % K
        tri, tuv = [ids[k], ids[k1], cen], [uvs[k], uvs[k1], uv(0, 0)]
        a, b, c = (mb.v[i] for i in tri)
        if (b - a).cross(c - a).dot(N) < 0:
            tri, tuv = tri[::-1], tuv[::-1]
        mb.face(tri, "EyePatch", PAL["EyePatch"], PART["eyepatch"], 0.0, uv=tuv)
    return mb


# ---------------------------------------------------------------- assembly
def build():
    loft = build_loft()
    head_tree0 = mb_tree([loft], parts={PART["head"]})
    eyes = {sd: eye_plane(head_tree0, sd) for sd in (1, -1)}
    flat_moved = {sd: flatten_eye(loft, *eyes[sd]) for sd in (1, -1)}
    nose = build_nose()
    jaw = build_jaw()
    ear_l = build_ear(1)
    legs = {k: build_leg(k) for k in ("fore", "hind")}
    tail, tail_len = build_tail()
    for mb in (loft, nose, jaw, ear_l, legs["fore"], legs["hind"], tail):
        rc.orient_closed_islands(mb)
    body_tree = mb_tree([loft, legs["hind"], legs["fore"]], parts={PART["torso"], PART["head"], PART["leg_upper"]})
    # mirrored copies for the spoon solve (the spoon lies on the RIGHT flank, -Y)
    legs_r = {k: MB("R")for k in legs}
    for k in legs:
        legs_r[k].extend(legs[k], mirror=True)
    body_tree_full = mb_tree([loft, legs["hind"], legs["fore"], legs_r["hind"], legs_r["fore"]],
                             parts={PART["torso"], PART["head"], PART["leg_upper"]})
    spoon_local, bowl_cx = spoon_local_mb()
    rc.orient_closed_islands(spoon_local)
    spoon_M, spoon_info = spoon_place(body_tree_full, spoon_local, bowl_cx)
    spoon = MB("Spoon")
    spoon.extend(spoon_local)
    spoon.transform(spoon_M)
    spoon_tree = BVHTree.FromPolygons(spoon.v, spoon.f, all_triangles=False)
    torso_tree = mb_tree([loft], parts={PART["torso"]})
    # the girth crosses the handle where the handle touches the flank (the binding contact of the spoon solve), so
    # it straps the spoon down instead of tenting over it
    band_x = spoon_info["binding_contact_spoon_body"][0][0] if P["BAND_X"] is None else P["BAND_X"]
    band, band_lift = build_band(torso_tree, spoon_tree, band_x)
    rc.orient_closed_islands(band)
    loft_tree = mb_tree([loft], parts={PART["torso"], PART["head"]})
    strap, strap_lift, strap_info = build_chest_strap(loft_tree, spoon_tree, spoon_M)
    rc.orient_closed_islands(strap)
    # cuffs: where the girth and the chest strap cross the handle (the spoon is strapped there), plus one at the neck
    cuffs = {}
    for nm, mbx in (("girth", band), ("strap", strap)):
        hit = spoon_param_nearest(spoon_M, mbx.v)
        cuffs[nm] = None if hit is None else {"along_cm": round(hit[1], 2), "dist_cm": round(hit[0], 2)}
    cuff_mb = MB("Cuffs")
    for nm, c in cuffs.items():
        if c and c["dist_cm"] < 3.5:
            add_cuff(cuff_mb, c["along_cm"], 1.8)
    add_cuff(cuff_mb, P["SPOON_HANDLE"] * 0.93, 1.5)
    rc.orient_closed_islands(cuff_mb)
    cuff_mb.transform(spoon_M)
    patch_l = build_eye_patch(*eyes[1], 1)
    patch_r = build_eye_patch(*eyes[-1], -1)
    pc_l, pc_r = eyes[1][0], eyes[-1][0]
    parts = {"Loft": loft, "Nose": nose, "Jaw": jaw, "Ear_L": ear_l, "Leg_Fore_L": legs["fore"], "Leg_Hind_L": legs["hind"],
             "Tail": tail, "Spoon": spoon, "Cuffs": cuff_mb, "Band": band, "ChestStrap": strap, "EyePatch_L": patch_l, "EyePatch_R": patch_r}
    mirrored = ("Ear_L", "Leg_Fore_L", "Leg_Hind_L")
    full = MB("PantryRat_R02_Body")
    tri_part = {}
    for name, mb in parts.items():
        n0 = len(full.f)
        full.extend(mb)
        if name in mirrored:
            full.extend(mb, mirror=True)
        tri_part[name] = sum(len(f) - 2 for f in full.f[n0:])
    rc.orient_closed_islands(full, skip_parts=(PART["eyepatch"],))
    if S != 1.0:
        full.transform(Matrix.Scale(S, 4))
    land = {"eye_l": pc_l * S, "eye_r": pc_r * S, "spoon_end": Vector(spoon_info["handle_end"]) * S,
            "spoon_bowl": Vector(spoon_info["bowl_centre"]) * S}
    info = {"tris_per_part_source": tri_part, "spoon": spoon_info, "band_max_lift": band_lift,
            "tail_length_cm": tail_len * S, "scale": S, "eye_flat_verts_moved": flat_moved,
            "strap": strap_info, "band_x": band_x, "strap_max_lift": strap_lift, "cuffs": cuffs, "belly_faces": loft.belly_faces,
            "spoon_M": [list(r) for r in spoon_M],
            "eye_plane": {str(k): [tuple(round(c, 3) for c in v[0]), tuple(round(c, 3) for c in v[1])]
                          for k, v in eyes.items()}}
    return {"parts": parts, "full": full, "land": land, "info": info}
