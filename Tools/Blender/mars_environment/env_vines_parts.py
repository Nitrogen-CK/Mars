"""Part generators for the vine family (build_env_vines.py): plain numpy, centimetres, Blender axes (Z up), no bpy.
Every generator returns a Part: verts (n, 3), faces (lists of vertex indices), and per-face / per-corner data the
builder paints and writes into UV1 "EnvData". The vine and root generator (Script/WorldObjects/Dressing/Vines) consumes
these meshes:

  bark_tube       VineBark_A / B, VineStemIvy: an open tube along +X from x = 0 to 100, radius 50, its end rings an
                  identical ridged profile so spline segments and chords meet seamlessly whichever variant follows.
  tip             VineTip: base ring (the same profile) at x = 0, point at x = 100.
  knot            VineKnot_A / B: a lumpy faceted ball of radius ~50 about the origin.
  leaf_cluster    VineLeaves_A / B / C: 3 / 5 / 7 folded ivy leaves fanning toward +X, faces toward +Z, petiole base at
                  the origin.
  moss_strand     VineMossStrand_A / B / C: two crossed jagged ribbons hanging from the origin to z = -100.
  rootlet         VineRootlet_A / B: a 3-sided hair root from the origin to z = -100 with 2 - 3 side hairs.
  cobweb_strand   VineCobweb_A: a sagging fan of thin threads below the origin, 100 wide, 100 deep.
  hero_root_*     HeroRoot_Top / Mid / Flare: SDF twin-strand rope modules (surface nets + decimate), canonical joint
                  loops at module ends so stacked modules meet.
"""
import math

import numpy as np

TAU = math.tau


class Part:
    """Geometry plus data: face_ids (u of EnvData per face), vflex (v of EnvData per vertex), face_tone (a paint key
    per face)."""

    def __init__(self):
        self.verts = np.zeros((0, 3))
        self.faces = []
        self.face_ids = []
        self.face_tone = []
        self.vflex = np.zeros(0)

    def add(self, verts, faces, ident=0.0, tone=0, flex=None):
        base = len(self.verts)
        verts = np.asarray(verts, float)
        self.verts = np.vstack([self.verts, verts]) if len(self.verts) else verts.copy()
        fl = np.zeros(len(verts)) if flex is None else np.asarray(flex, float)
        self.vflex = np.concatenate([self.vflex, fl])
        for f in faces:
            self.faces.append([base + int(i) for i in f])
            self.face_ids.append(float(ident))
            self.face_tone.append(tone)
        return base

    def tris(self):
        return sum(len(f) - 2 for f in self.faces)


def _n(v):
    v = np.asarray(v, float)
    n = np.linalg.norm(v, axis=-1, keepdims=True)
    return v / np.maximum(n, 1e-12)


def rotate(v, axis, deg):
    """Rodrigues rotation of points v (n, 3) about a unit axis through the origin."""
    a = _n(np.asarray(axis, float))
    t = math.radians(deg)
    v = np.asarray(v, float)
    return (v * math.cos(t) + np.cross(a, v) * math.sin(t) + np.outer(v @ a, a) * (1.0 - math.cos(t)))


# ---------------------------------------------------------------- bark tubes
def ring_profile(sides, ridge, seed):
    """Radius factor per side for the shared end ring: bark ridges, a fixed hand-cut irregularity."""
    rng = np.random.default_rng(seed)
    k = np.arange(sides)
    g = 0.6 * np.cos(k * TAU * 2.0 / sides + 0.4) + rng.uniform(-0.6, 0.6, sides)
    g = g / max(np.abs(g).max(), 1e-6)
    return 1.0 + ridge * g


def bark_tube(sides=9, rings=6, ridge=0.08, bulge=0.0, seed=11, interior_jitter=0.03, twist_deg=10.0):
    """Open tube along +X (0 .. 100), radius 50. The end rings share ring_profile(sides, ridge, END_SEED) exactly and
    sit at the same angles; interior rings add jitter, a seeded twist of the ridge pattern and an optional knot bulge
    (B), all faded to zero at both ends. Faces are quads; tone 0 = ridge, 1 = groove (the low sides)."""
    prof = ring_profile(sides, ridge, END_SEED)
    rng = np.random.default_rng(seed)
    verts, faces, tones = [], [], []
    for r in range(rings):
        x = 100.0 * r / (rings - 1)
        fade = math.sin(math.pi * r / (rings - 1))
        twist = math.radians(twist_deg) * fade * (1.0 if seed % 2 else -1.0)
        jit = rng.uniform(-interior_jitter, interior_jitter, sides) * fade
        bump = bulge * math.exp(-((x - 52.0) / 16.0) ** 2)
        for k in range(sides):
            a = TAU * k / sides + twist
            rad = 50.0 * (prof[k] + jit[k] + bump * (0.6 + 0.4 * math.cos(a - 1.1)))
            verts.append((x, rad * math.cos(a), rad * math.sin(a)))
    for r in range(rings - 1):
        for k in range(sides):
            a, b = r * sides + k, r * sides + (k + 1) % sides
            c, d = a + sides, b + sides
            faces.append([a, c, d, b])
            tones.append(1 if prof[k] + prof[(k + 1) % sides] < 2.0 else 0)
    p = Part()
    p.add(np.array(verts), faces)
    p.face_tone = tones
    return p


END_SEED = 9301


def tip(sides=9, rings=3, ridge=0.08, seed=5):
    """Root tip: the shared end ring (radius 50) at x = 0 narrowing to a point at x = 100, slightly bent."""
    prof = ring_profile(sides, ridge, END_SEED)
    rng = np.random.default_rng(seed)
    verts, faces, tones = [], [], []
    for r in range(rings):
        t = r / rings
        x = 100.0 * t
        rad = 50.0 * (1.0 - t) ** 0.8
        bend = 6.0 * t * t
        jit = rng.uniform(-0.06, 0.06, sides) * (0.0 if r == 0 else 1.0)
        for k in range(sides):
            a = TAU * k / sides
            rr = rad * (prof[k] + jit[k])
            verts.append((x, rr * math.cos(a), rr * math.sin(a) - bend))
    apex = len(verts)
    verts.append((100.0, rng.uniform(-3, 3), -8.0))
    for r in range(rings - 1):
        for k in range(sides):
            a, b = r * sides + k, r * sides + (k + 1) % sides
            faces.append([a, a + sides, b + sides, b])
            tones.append(0)
    for k in range(sides):
        a, b = (rings - 1) * sides + k, (rings - 1) * sides + (k + 1) % sides
        faces.append([a, apex, b])
        tones.append(1)
    p = Part()
    p.add(np.array(verts), faces)
    p.face_tone = tones
    return p


# ---------------------------------------------------------------- knots
def icosphere(subdiv=1):
    t = (1.0 + 5 ** 0.5) / 2.0
    v = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t),
         (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    f = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6),
         (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10),
         (8, 6, 7), (9, 8, 1)]
    verts = [np.array(x, float) / np.linalg.norm(x) for x in v]
    faces = [list(x) for x in f]
    for _ in range(subdiv):
        cache = {}
        nf = []

        def mid(a, b):
            key = (min(a, b), max(a, b))
            if key not in cache:
                m = verts[a] + verts[b]
                verts.append(m / np.linalg.norm(m))
                cache[key] = len(verts) - 1
            return cache[key]
        for a, b, c in faces:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            nf += [[a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]]
        faces = nf
    return np.array(verts), faces


def knot(seed, lumps=3, flat=0.75):
    """A burl: an icosphere (80 tris) pushed out by a few seeded lumps, flattened toward the stem (-Z of the knot
    frame sits on the root), radius ~50."""
    rng = np.random.default_rng(seed)
    v, f = icosphere(1)
    centres = _n(rng.normal(size=(lumps, 3)) + np.array([0, 0, 0.8]))
    amp = rng.uniform(0.18, 0.32, lumps)
    r = np.ones(len(v))
    for c, a in zip(centres, amp):
        r += a * np.exp(-((1.0 - v @ c) / 0.35) ** 2)
    r *= 1.0 + rng.uniform(-0.06, 0.06, len(v))
    pts = v * r[:, None] * 50.0 / r.max()
    pts[:, 2] = np.where(pts[:, 2] < 0.0, pts[:, 2] * flat, pts[:, 2])
    p = Part()
    p.add(pts, f)
    p.face_tone = [0 if pts[list(ff)].mean(axis=0)[2] > 0 else 1 for ff in f]
    return p


# ---------------------------------------------------------------- leaves
# ivy outlines (x along the midrib 0 base .. 1 tip, y lateral, half width 0.5), counter-clockwise from the tip
# (same shapes as the organic family's dry leaves, copied: builders never import each other)
LEAF_TEMPLATES = {
    8: np.array([[1.00, 0.00], [0.58, 0.10], [0.46, 0.50], [0.07, 0.38], [0.16, 0.00], [0.07, -0.38], [0.46, -0.50],
                 [0.58, -0.10]]),
    6: np.array([[1.00, 0.00], [0.47, 0.48], [0.05, 0.34], [0.17, 0.00], [0.05, -0.34], [0.47, -0.48]]),
    4: np.array([[1.00, 0.00], [0.42, 0.42], [0.10, 0.00], [0.42, -0.42]]),
}
LEAF_CENTRE = 0.42


def leaf_blade(rng, kind, length, fold_deg=(4.0, 10.0)):
    """One ivy leaf in its own frame: fan centre on the midrib at LEAF_CENTRE, the blade's base notch at the origin side
    (x = 0), tip at +x, visible side +z, a V-fold along the midrib and a droop at the tip. Returns (verts, faces)."""
    tpl = LEAF_TEMPLATES[kind]
    p = tpl + rng.uniform(-0.025, 0.025, tpl.shape)
    p[0] = tpl[0] + np.array([rng.uniform(-0.03, 0.02), rng.uniform(-0.05, 0.05)])
    width = rng.uniform(0.9, 1.08)
    x = p[:, 0] * length
    y = p[:, 1] * length * width
    fold = math.tan(math.radians(rng.uniform(*fold_deg)))
    tipw = np.clip((p[:, 0] - LEAF_CENTRE) / (1.0 - LEAF_CENTRE), 0.0, 1.0)
    z = np.abs(y) * fold - 0.06 * length * tipw ** 2
    centre = np.array([[LEAF_CENTRE * length, 0.0, 0.0]])
    verts = np.vstack([centre, np.column_stack([x, y, z])])
    n = len(tpl)
    faces = [[0, 1 + i, 1 + (i + 1) % n] for i in range(n)]
    return verts, faces


def leaf_cluster(seed, count, span):
    """count leaves fanning toward +X over about span cm: a terminal leaf on the axis and pairs alternating left and
    right, each on a one-triangle petiole from the origin, blades facing +Z (lifted a little, tilted outward). Per face:
    id = leaf index / count (u of EnvData), corner flex = distance from the origin / max (v)."""
    rng = np.random.default_rng(seed)
    p = Part()
    kinds = ([8, 8, 6, 8, 6, 6, 6] if count >= 7 else [8, 8, 6, 6, 6] if count >= 5 else [8, 6, 6])[:count]
    for i in range(count):
        if i == 0:
            yaw, reach, length = rng.uniform(-8, 8), span * 0.42, span * 0.58
        else:
            side = 1.0 if i % 2 else -1.0
            row = (i + 1) // 2
            yaw = side * (38.0 + 14.0 * row + rng.uniform(-8, 8))
            reach = span * (0.32 - 0.05 * row) * rng.uniform(0.85, 1.1)
            length = span * (0.5 - 0.06 * row) * rng.uniform(0.85, 1.05)
        bv, bf = leaf_blade(rng, kinds[i], length)
        roll = rng.uniform(-8, 8)
        bv = rotate(bv, (1, 0, 0), roll)
        bv = rotate(bv, (0, 1, 0), -rng.uniform(2, 8))          # blade tilted up from the petiole
        d = np.array([math.cos(math.radians(yaw)), math.sin(math.radians(yaw)), 0.0])
        base = d * reach + np.array([0, 0, rng.uniform(0.4, 1.4)])
        bv = rotate(bv, (0, 0, 1), yaw) + base
        ident = (i + 0.5) / count
        p.add(bv, bf, ident=ident, tone=i % 3)
        # petiole: a sliver triangle from the origin to the blade base
        side = np.array([-d[1], d[0], 0.0]) * 0.18
        pv = np.array([np.zeros(3), base - side, base + side])
        p.add(pv, [[0, 1, 2]], ident=ident, tone=3)
    r = np.linalg.norm(p.verts, axis=1)
    p.vflex = r / max(r.max(), 1e-6)
    return p


# ---------------------------------------------------------------- hanging cards
def moss_strand(seed, rows=12, width=(3.0, 6.0)):
    """Two crossed jagged ribbons hanging from the origin to z = -100: width tapering from width[1] at the top to
    width[0] x 0.4 at the tip, alternating ragged edges, a slow sway and twist. Corner flex = depth / 100."""
    rng = np.random.default_rng(seed)
    p = Part()
    for ribbon in range(2):
        yaw = rng.uniform(0, 180) + 90.0 * ribbon
        verts = []
        phase = rng.uniform(0, TAU)
        for r in range(rows + 1):
            t = r / rows
            z = -100.0 * t
            w = (width[1] * (1.0 - t) + width[0] * 0.4 * t) * rng.uniform(0.7, 1.25) * 0.5
            rag = (1.0 if r % 2 else 0.55)
            sway = np.array([2.2 * math.sin(t * 5.0 + phase), 2.2 * math.cos(t * 4.0 + phase), 0.0]) * t
            a = math.radians(yaw + 25.0 * t * (1.0 if seed % 2 else -1.0))
            d = np.array([math.cos(a), math.sin(a), 0.0])
            c = np.array([0.0, 0.0, z]) + sway
            verts.append(c - d * w * rag)
            verts.append(c + d * w * (1.55 - rag))
        faces = [[2 * r, 2 * r + 2, 2 * r + 3, 2 * r + 1] for r in range(rows)]
        v = np.array(verts)
        p.add(v, faces, ident=rng.uniform(0.05, 0.95), tone=ribbon, flex=np.clip(-v[:, 2] / 100.0, 0.0, 1.0))
    return p


def rootlet(seed, segs=8, radius=0.5, hairs=3):
    """A 3-sided hair root from the origin to z = -100, wavy, with side hairs (one-triangle slivers)."""
    rng = np.random.default_rng(seed)
    p = Part()
    pts = []
    phase = rng.uniform(0, TAU)
    for s in range(segs + 1):
        t = s / segs
        pts.append(np.array([3.0 * math.sin(t * 6.0 + phase) * t, 2.0 * math.cos(t * 5.0 + phase) * t, -100.0 * t]))
    verts = []
    for s, c in enumerate(pts):
        r = radius * (1.0 - 0.6 * s / segs)
        for k in range(3):
            a = TAU * k / 3 + s * 0.5
            verts.append(c + np.array([r * math.cos(a), r * math.sin(a), 0.0]))
    faces = []
    for s in range(segs):
        for k in range(3):
            a, b = s * 3 + k, s * 3 + (k + 1) % 3
            faces.append([a, a + 3, b + 3, b])
    v = np.array(verts)
    p.add(v, faces, ident=rng.uniform(0.05, 0.95), tone=0, flex=np.clip(-v[:, 2] / 100.0, 0.0, 1.0))
    for h in range(hairs):
        s = rng.integers(2, segs - 1)
        c = pts[s]
        d = _n(np.array([rng.uniform(-1, 1), rng.uniform(-1, 1), -0.8]))
        L = rng.uniform(8.0, 18.0)
        side = _n(np.cross(d, [0, 0, 1])) * 0.25
        hv = np.array([c - side, c + side, c + d * L])
        p.add(hv, [[0, 1, 2]], ident=rng.uniform(0.05, 0.95), tone=1, flex=np.clip(-hv[:, 2] / 100.0, 0.0, 1.0))
    return p


def _thread(a, b, sag, width, segs):
    """A thin flat thread from a to b sagging by sag (cm) in -Z at the middle: (verts, faces)."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    d = _n(b - a)
    side = _n(np.cross(d, [0.0, -1.0, 0.0]))
    if np.linalg.norm(side) < 1e-6:
        side = np.array([1.0, 0.0, 0.0])
    side = side * width * 0.5
    verts = []
    for s in range(segs + 1):
        t = s / segs
        c = a + (b - a) * t - np.array([0, 0, sag * 4.0 * t * (1.0 - t)])
        verts += [c - side, c + side]
    faces = [[2 * s, 2 * s + 2, 2 * s + 3, 2 * s + 1] for s in range(segs)]
    return np.array(verts), faces


def cobweb_strand(seed):
    """A sagging fan hanging below the origin in the XZ plane (faces along Y): 7 radial threads from the hub out to a
    100-wide, 100-deep fan, three sagging cross threads, and one loose strand. Corner flex = sag weight (0 at the hub
    and the anchor ends, 1 at the middle of a cross thread)."""
    rng = np.random.default_rng(seed)
    p = Part()
    spokes = []
    for i in range(7):
        a = math.radians(-70.0 + 140.0 * i / 6 + rng.uniform(-6, 6))
        L = rng.uniform(70.0, 100.0)
        spokes.append(np.array([math.sin(a) * L * 0.5 / 0.94, rng.uniform(-3, 3), -math.cos(a) * L]))
    for i, s in enumerate(spokes):
        v, f = _thread((0, 0, 0), s, rng.uniform(1.0, 3.0), 0.35, 2)
        p.add(v, f, ident=(i + 0.5) / 12.0, tone=0, flex=np.clip(np.linalg.norm(v, axis=1) / 100.0, 0, 1) * 0.3)
    for ring, frac in enumerate((0.35, 0.6, 0.85)):
        for i in range(6):
            a, b = spokes[i] * frac, spokes[i + 1] * frac
            v, f = _thread(a, b, rng.uniform(3.0, 7.0) * frac, 0.25, 2)
            flex = np.array([0.0, 0.0, 1.0, 1.0, 0.0, 0.0])
            p.add(v, f, ident=(7 + ring + 0.5) / 12.0, tone=1, flex=flex)
    v, f = _thread(spokes[3] * 0.6, spokes[3] * 0.6 + np.array([rng.uniform(-8, 8), 0, -38.0]), 0.0, 0.3, 2)
    p.add(v, f, ident=11.5 / 12.0, tone=1, flex=np.array([0.3, 0.3, 0.7, 0.7, 1.0, 1.0]))
    # normalise the depth to exactly 100 cm (the generator scales a card's z to its traced length)
    p.verts[:, 2] *= 100.0 / max(-p.verts[:, 2].min(), 1e-6)
    return p


# ---------------------------------------------------------------- hero roots (SDF twin rope)
def sd_capsule_chain(x, y, z, pts, radii):
    """Signed distance to a chain of capsules through pts (n, 3) with per-point radii (smooth union by min)."""
    d = np.full(x.shape, 1e9)
    P = np.stack([x, y, z], axis=-1)
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        ab = b - a
        t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-9), 0.0, 1.0)
        c = a + t[..., None] * ab
        r = radii[i] + (radii[i + 1] - radii[i]) * t
        d = np.minimum(d, np.linalg.norm(P - c, axis=-1) - r)
    return d


def strand_centres(z0, z1, radius, offset, turns, phase, samples, wander=None):
    """The two rope strands' centre lines from z0 down to z1: helices of the given offset with turns full turns, plus an
    optional wander(z) -> (dx, dy). Returns two (samples, 3) arrays."""
    out = []
    for k in range(2):
        pts = []
        for s in range(samples):
            t = s / (samples - 1)
            z = z0 + (z1 - z0) * t
            a = phase + TAU * turns * t + math.pi * k
            dx, dy = wander(z) if wander else (0.0, 0.0)
            pts.append((offset * math.cos(a) + dx, offset * math.sin(a) + dy, z))
        out.append(np.array(pts))
    return out
