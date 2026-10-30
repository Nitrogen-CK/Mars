"""Mars environment dressing, family "bones" (Blender 5.2, headless). Builds every bones mesh of ENV_KIT.md from fixed
seeds, checks each one, exports FBX + sidecar, writes the review sheets and saves Dressing_Bones.blend.

  "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup --python
      D:\\Repo\\Mars\\Tools\\Blender\\mars_environment\\build_env_bones.py -- --export --sheets --save [--only <part>]

Meshes (all <Name>_Mars_SM, slots EnvBone / EnvStone):
  singles  Skull_A (cut jaw, closed 2 deg), Skull_B (jawless), Skull_C (a chiselled break in the crown, dark floor),
           Jaw_A, Femur_A, Femur_B, Humerus_A, Rib_A, BoneShards_A. Every bone is hand-cut like the packed skull
           (env_bones_parts make_cut_*): 8-sided prism dome, flat face plane, inset pentagon orbits, triangular nasal
           notch, a 2.5 cm tooth band cut by slits, zygomatic wedges, a brow bar; 6-sided faceted shafts with hull
           knobs (double condyles); a 5-sided rib band lying flat
  heaps    SkullStack_A, BonePile_A, BonePile_B, BoneScatter_A, BoneScatter_B (dropped and settled; bones never pass
           through a skull's face, >= 60 % of the skulls face -y, faces tipped up 0-20 deg, long bones pitch <= 25
           deg, ribs lie flat and never stand > 8 cm; scatters are Poisson-disc spread, one bone at most leans)
  fills    OssuaryFill_A (100 x 45 x 35, kit wall bays), OssuaryFill_B / OssuaryFill_B2 (134 x 45 x 35, two seeds
           for the OssuaryShelf_A bay), OssuaryFill_Niche (75 x 50 x 25): crammed rows of packed skulls (yaw / roll /
           nod / scale / depth jitter, a skull turned along the row or a heap of bone ends in some slots, one jaw per
           row), hand-cut long-bone lanes between them, rows of bone ends, a lane of bones over the top; hidden
           bone beds behind; back at y = 0, pivot at the bottom centre of the back edge
  stone    OssuaryShelf_A (2 m bay unit: two 32 cm cross + gothic-niche posts, plinth + three hand-set slabs with
           faceted chamfers and a broken lip corner = four bays, flat chamfered cornice, SOCKET_Bay_<row>1 where a
           35 D fill's front lands 2 cm behind the slab lip)
           OssuaryPier_A (freestanding hero block from concept 1: on each long face two wide bays per tier (three
           tiers) either side of one centre post with the skull niche and the cross, end posts with a niche and a
           cross; crammed packed-skull fills (front-only LOD) with long-bone lanes; a heaped crown of skulls and bone
           on a lumpy bone mound, the eave skulls' chins over the slab edge; carved end panels with a raised cross)

The geometry library (hand-cut skulls, jaw and bones, the packed skull and its front LOD, culling, placement,
chiselled stone, checks) is env_bones_parts.py. Never import this file: it builds on import.
"""
import math
import os
import sys
import time
import zlib

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import env_common as ec  # noqa: E402
import env_bones_parts as bp  # noqa: E402

fc, sc, spec = ec.fc, ec.sc, ec.spec
FAMILY = "bones"

BONE = ec.palette("EnvBone")
BONE_D = ec.palette("EnvBoneDark")
BONE_L = ec.palette("EnvBoneLight")
STONE = ec.palette("EnvStone")
STONE_D = ec.palette("EnvStoneDark")
STONE_L = np.clip(STONE * 1.3, 0.0, 1.0)

LONG_KINDS = ("Femur", "Tibia", "Humerus", "FemurB")
SKULL_KINDS = ("A", "B", "C", "J")
SKULL_TAGS = ("bone", "socket", "nasal", "brow", "crack", "hole", "tooth", "teethband", "jaw", "face", "cheek",
              "toothgap")
DARK_ALPHA = {"socket": 0.0, "nasal": 0.0, "toothgap": 0.0, "hole": 0.0, "backing": 0.0, "marrow": 0.2,
              "heapcore": 0.5, "bedtop": 0.3}


# ================================================================ part library (cached, rested: xy centred, z 0)
# Every bone is hand-cut (env_bones_parts make_cut_*): A / B / C loose skulls (8-sided prism dome, flat face, pentagon
# orbits, nasal notch, slit teeth, zygomas; A carries the cut jaw), J the jaw alone, the long bones and the rib.
# P is the packed skull, PF its front-only LOD (rows seen only from the front), PJ a packed skull with a jaw.
_LIB = {}


def _bone_lod(lod):
    return "lite" if lod in ("lite", "micro", "nano") else ("full" if lod == "full" else "mid")


def lib(kind, lod="full", seed=1, open_deg=2.0):
    if kind in ("P", "PF", "PJ"):
        key = (kind, seed % 3)
        if key not in _LIB:
            if kind == "P":
                p = bp.make_packed_skull(seed % 3)
            elif kind == "PF":
                p = bp.make_packed_front(seed % 3)
            else:
                sk = bp.make_packed_skull(seed % 3)
                jaw = bp.make_cut_jaw(seed % 3, open_deg=2.0).transformed(t=(0.0, 0.07, -0.5))
                p = bp.Piece("PackedJaw", sk.shells + jaw.shells, {"kind": "PJ"})
            _LIB[key] = p.rest()
        return _LIB[key]
    sl = "full" if lod == "full" else "mid"
    key = (kind, sl if kind in SKULL_KINDS else _bone_lod(lod), seed % 3, round(open_deg, 1))
    if key not in _LIB:
        if kind in ("A", "B", "C"):
            p = bp.make_cut_skull(kind, seed % 3, lod=sl, crack_seed=seed)
            if kind == "A":
                p = bp.Piece("Skull_A", p.shells + bp.make_cut_jaw(seed % 3, open_deg=open_deg).shells,
                             {"kind": "A"})
        elif kind == "J":
            p = bp.make_cut_jaw(seed % 3, open_deg=0.0)
        elif kind == "Rib":
            p = bp.make_cut_rib(_bone_lod(lod), seed=seed % 3)
        else:
            p = bp.make_cut_long_bone(kind, _bone_lod(lod), seed=seed % 3)
        _LIB[key] = p.rest()
    return _LIB[key]


def ext(piece):
    lo, hi = piece.bounds()
    return hi - lo


def diag(sx, sy, sz):
    return np.diag([float(sx), float(sy), float(sz)])


def shift_asm(asm, t):
    asm.shells = [(sh.transformed(t=t), g) for sh, g in asm.shells]


def asm_bounds(asm):
    v = np.concatenate([sh.v for sh, _ in asm.shells])
    return v.min(axis=0), v.max(axis=0)


def rest_floor(asm):
    """Floor prop pivot: XY centre of the footprint, lowest point z = 0."""
    lo, hi = asm_bounds(asm)
    shift_asm(asm, (-(lo[0] + hi[0]) * 0.5, -(lo[1] + hi[1]) * 0.5, -lo[2]))


def piece_frame(rested, placed, R):
    """(R, t) with placed = R @ rested + t (tracks a piece through drop / settle)."""
    t = placed.shells[0].v[0] - np.asarray(R, float) @ rested.shells[0].v[0]
    return np.asarray(R, float), t


class Stage:
    """Where pieces are dropped: a height field (fast drop estimate) plus the exact geometry placed so far (contact
    settle)."""

    def __init__(self, lo_xy, hi_xy, cell=0.6, floor=0.0, z_floor=0.0):
        self.hf = bp.HeightField(lo_xy, hi_xy, cell=cell, floor=floor)
        self.z_floor = z_floor
        self.V, self.T = [], []
        self._bvh = None

    def add_static(self, shells):
        for sh in shells:
            tris = [(f[0], f[i], f[i + 1]) for f in sh.f for i in range(1, len(f) - 1)]
            self.hf.add_tris(sh.v, tris)
            self._add_geo(sh.v, tris)

    def _add_geo(self, v, tris):
        base = sum(len(x) for x in self.V)
        self.V.append(np.asarray(v, float))
        self.T.extend([(a + base, b + base, c + base) for a, b, c in tris])
        self._bvh = None

    def bvh(self):
        if self._bvh is None and self.V:
            from mathutils import Vector
            from mathutils.bvhtree import BVHTree
            V = np.concatenate(self.V)
            self._bvh = BVHTree.FromPolygons([Vector(p) for p in V], self.T, epsilon=0.0)
        return self._bvh

    def add(self, piece):
        self.hf.add_piece(piece)
        for sh in piece.shells:
            self._add_geo(sh.v, [(f[0], f[i], f[i + 1]) for f in sh.f for i in range(1, len(f) - 1)])


def piece_bvh(piece):
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    V, T, base = [], [], 0
    for sh in piece.shells:
        V.append(sh.v)
        T.extend([(f[0] + base, f[i] + base, f[i + 1] + base) for f in sh.f for i in range(1, len(f) - 1)])
        base += len(sh.v)
    return BVHTree.FromPolygons([Vector(p) for p in np.concatenate(V)], T, epsilon=0.0)


def settle(stage, p, step=0.25, max_steps=40):
    """Lower a dropped piece until it really touches what is below it or the floor."""
    for _ in range(max_steps):
        low = p.bounds()[0][2]
        if low <= stage.z_floor + 0.02:
            return p
        b = stage.bvh()
        if b is not None and piece_bvh(p).overlap(b):
            return p
        p = p.transformed(t=(0.0, 0.0, -min(step, low - stage.z_floor)))
    return p


def drop_only(stage, piece, R, xy, box=None, sink=0.4):
    if box is not None:
        lo, hi = piece.transformed(R).bounds()
        hx, hy = (hi[0] - lo[0]) * 0.5, (hi[1] - lo[1]) * 0.5
        x = float(np.clip(xy[0], box[0] + hx, max(box[2] - hx, box[0] + hx)))
        y = float(np.clip(xy[1], box[1] + hy, max(box[3] - hy, box[1] + hy)))
        xy = (x, y)
    p = bp.drop(stage.hf, piece, R, xy, sink=sink, z_floor=stage.z_floor)
    return settle(stage, p)


def perch_score(stage, p):
    """How badly a dropped piece perches: mean gap over the lowest 40 % of its points to the surface under them."""
    pts = bp.sample_points(p)
    gap = np.sort(pts[:, 2] - stage.hf.at(pts))
    k = max(int(len(gap) * 0.4), 1)
    return float(np.mean(np.maximum(gap[:k], 0.0)))


def place(stage, piece, R, xy, box=None, sink=0.4):
    p = drop_only(stage, piece, R, xy, box=box, sink=sink)
    stage.add(p)
    return p


# ---------------------------------------------------------------- what a placed piece is (for the placement rules)
class SkullInfo:
    """A placed skull: an ellipsoid (centre, axes, radii) and its face direction (local -y)."""

    def __init__(self, rested, placed, R):
        Rm, t = piece_frame(rested, placed, R)
        lo, hi = rested.bounds()
        self.c = Rm @ ((lo + hi) * 0.5) + t
        # the skull's own axes (R may carry a scale: normalise its columns, keep the radii scaled)
        cols = [Rm[:, k] for k in range(3)]
        scl = np.array([np.linalg.norm(cc) for cc in cols])
        self.ax = np.stack([cc / s for cc, s in zip(cols, scl)], axis=1)
        self.r = (hi - lo) * 0.5 * scl * np.array([0.95, 0.9, 0.92])
        self.face = -self.ax[:, 1]

    def blocks_face(self, p, margin=0.0):
        """p lies in the box in front of the face (up to 9 cm out): a bone there hides the orbits from the front."""
        q = self.ax.T @ (np.asarray(p, float) - self.c)
        r = self.r + margin
        return (-(r[1] + 9.0) < q[1] < -0.2 * r[1] and abs(q[0]) < 0.85 * r[0] and -0.8 * r[2] < q[2] < 0.65 * r[2])

    def surface_gap(self, p):
        """Approximate distance (cm) from point p to the skull surface (negative inside) and whether p is in front
        of the face (the orbit / nose region)."""
        q = self.ax.T @ (np.asarray(p, float) - self.c)
        e = float(np.linalg.norm(q / self.r))
        gap = (e - 1.0) * float(np.min(self.r)) if e < 1.0 else (e - 1.0) * float(np.mean(self.r))
        front = q[1] < -0.25 * self.r[1] and q[2] > -0.75 * self.r[2]
        return gap, front


class BoneInfo:
    """A placed long bone: sample points along its axis and its shaft radius."""

    def __init__(self, rested, placed, R):
        Rm, t = piece_frame(rested, placed, R)
        lo, hi = rested.bounds()
        c = (lo + hi) * 0.5
        if rested.name == "Rib":
            # a curved rib: test points on the rib itself, not a straight axis through its bounds
            v = rested.verts()
            idx = np.linspace(0, len(v) - 1, 24).astype(int)
            self.rad = 0.6
            self.pts = (v[np.argsort(v[:, 0])][idx]) @ Rm.T + t
        else:
            self.rad = 0.5 * float(min(hi[1] - lo[1], hi[2] - lo[2])) * 0.75
            L = hi[0] - lo[0]
            xs = np.linspace(lo[0] + 0.12 * L, hi[0] - 0.12 * L, 9)
            self.pts = np.array([Rm @ np.array([x, c[1], c[2]]) + t for x in xs])
        d = self.pts[-1] - self.pts[0]
        self.pitch = math.degrees(math.asin(min(1.0, abs(d[2]) / max(np.linalg.norm(d), 1e-9))))


def bone_hits_skull(bone, skull, max_pen=1.5, face_clear=0.5):
    """The pile / scatter rule: a bone may touch a skull only shallowly (< max_pen cm), never its face (keeps
    face_clear cm off the orbit / nose region)."""
    for p in bone.pts:
        if skull.blocks_face(p, margin=bone.rad):
            return True
        gap, front = skull.surface_gap(p)
        surf = gap - bone.rad                    # bone surface to skull surface (negative = penetration)
        if front and surf < face_clear:
            return True
        if surf < -max_pen:
            return True
    return False


def fix_zfight(asm, rounds=4, push=0.35):
    """Near-coplanar same-facing faces of two interpenetrating bone pieces z-fight: push the later piece 3.5 mm along
    the shared normal (repeat until clean)."""
    pushes = {}
    for rnd in range(rounds):
        obj, tags, group, shell = asm.build("_ZF")
        zf = bp.zfight_report(obj, np.asarray(group))
        N = fc.face_normals(obj)
        bp.remove_object(obj)
        if not zf:
            return
        moved = set()
        bone_g = {int(gg) for sh, gg in asm.shells if sh.slot == "EnvBone"}
        bed_g = {int(gg) for sh, gg in asm.shells if any(t in ("backing", "heapcore", "bedtop") for t in sh.tags)}
        for a, b, _d in zf:
            # move a bone, never a bed / backing (pushing those just collides them with the next bone)
            cand = [int(x) for x in sorted((group[a], group[b]), key=lambda q: (int(q) in bed_g, -int(q)))
                    if int(x) in bone_g]
            if not cand:
                continue
            g = cand[0]
            if rnd >= rounds // 2:
                # the bone pushes did not settle it: step the hidden bed back from that face instead
                beds = [int(x) for x in (group[a], group[b]) if int(x) in bed_g]
                if beds and beds[0] not in moved:
                    gb = beds[0]
                    moved.add(gb)
                    nb = N[a] if group[a] == gb else N[b]
                    asm.shells = [(sh.transformed(t=-nb * 0.4) if gg == gb else sh, gg) for sh, gg in asm.shells]
                    continue
            if g in moved:
                continue
            moved.add(g)
            n = N[a] if group[a] == g else N[b]
            # a piece pushed again (it slid into a third one) goes further each time
            k = min(pushes.get(g, 0), 2)
            pushes[g] = k + 1
            asm.shells = [(sh.transformed(t=n * push * (1 + k)) if gg == g else sh, gg) for sh, gg in asm.shells]
    print("  fix_zfight: not converged, %d overlaps left" % len(zf))


class BoxEnv(bp.Env):
    """The surroundings of a mesh, exact: an infinite floor (z = 0) and / or back wall (y = 0) hide a ray only when it
    reaches them before it leaves the mesh's bounds."""

    def __init__(self, base, lo, hi, margin=0.5):
        super().__init__(base.name, floor=base.floor, wall=base.wall)
        self.lo = np.asarray(lo, float) - margin
        self.hi = np.asarray(hi, float) + margin

    def _exit(self, o, d):
        t = float("inf")
        for a in range(3):
            if d[a] > 1e-9:
                t = min(t, (self.hi[a] - o[a]) / d[a])
            elif d[a] < -1e-9:
                t = min(t, (self.lo[a] - o[a]) / d[a])
        return max(t, 0.0)

    def blocks(self, o, d):
        t_exit = None
        if self.floor and d[2] < -1e-6:
            t_exit = self._exit(o, d)
            if max(o[2], 0.0) / -d[2] < t_exit:
                return True
        if self.wall and d[1] > 1e-6:
            t_exit = self._exit(o, d) if t_exit is None else t_exit
            if max(-o[1], 0.0) / d[1] < t_exit:
                return True
        return False


def cull_repair(asm, env, n_dirs=72, rays=60000, seed=3):
    """asm.cull, then restore every culled face that a ray from outside reaches first."""
    from mathutils import Vector
    cap = {}
    asm.apply_keep = lambda keep: cap.__setitem__("k", np.array(keep, bool))
    try:
        asm.cull(env=env, n_dirs=n_dirs, samples=4)
    finally:
        del asm.apply_keep
    keep = cap["k"]
    bvh, V, F = asm.bvh()
    N = np.array([bp.newell(V[f]) for f in F])
    lo, hi = V.min(axis=0), V.max(axis=0)
    c = 0.5 * (lo + hi)
    Rr = float(np.linalg.norm(hi - lo)) * 0.75 + 5.0
    rng = np.random.default_rng(seed)
    restored = 0
    for _ in range(rays):
        o = c + bp._n(rng.normal(size=3)) * Rr
        if env is not None and not env.origin_ok(o):
            continue
        d = bp._n(lo + rng.uniform(size=3) * (hi - lo) - o)
        hit = bvh.ray_cast(Vector(o), Vector(d), 4 * Rr)
        if hit[0] is None:
            continue
        i = hit[2]
        if not keep[i] and float(np.dot(N[i], d)) < 0.0:
            keep[i] = True
            restored += 1
    asm.apply_keep(keep)
    return restored


# ================================================================ painting
def is_stone_tag(tag):
    return "/" in tag or tag in ("slab", "stone", "chip")


def face_colour(tag, n, tone):
    sub = tag.split("/")[-1]
    up, down = max(float(n[2]), 0.0), max(-float(n[2]), 0.0)
    if is_stone_tag(tag):
        if sub in ("holewall", "niche", "cross", "recess", "crack"):
            c = STONE_D * 0.72
        elif sub in ("chamfer", "chip"):
            c = bp.mix(STONE, STONE_L, 0.55)
        elif up > 0.7:
            c = bp.mix(STONE, STONE_L, 0.75)
        elif down > 0.5:
            c = STONE_D
        else:
            c = bp.mix(STONE, STONE_D, 0.12 + 0.2 * down)
        return c * (1.0 + 0.09 * tone)
    base = bp.mix(BONE, BONE_L, up * 0.5)
    base = bp.mix(base, BONE_D, down * 0.45)
    if tag in ("socket", "hole"):
        return BONE_D * 0.2
    if tag in ("nasal", "toothgap"):
        return BONE_D * 0.25
    if tag == "crack":
        return BONE_D * 0.45
    if tag == "marrow":
        return BONE_D * 0.35
    if tag == "backing":
        return BONE_D * 0.4
    if tag in ("heapcore", "bedtop"):
        # a bed / wedge top seen from a gallery reads as more bone in shadow, not a dark tray
        return bp.mix(BONE, BONE_D, 0.3) * (0.85 if tag == "heapcore" else 0.42)
    if tag == "tooth":
        return bp.mix(BONE_L, BONE, 0.2)
    if tag == "brow":
        return bp.mix(base, BONE_L, 0.55)
    if tag == "cheek":
        return bp.mix(base, BONE_L, 0.35)
    if tag == "face":
        return bp.mix(base, BONE_L, 0.15)
    if tag == "teethband":
        return bp.mix(BONE_L, BONE_D, 0.3)
    if tag == "knob":
        return bp.mix(base, BONE_L, 0.22)
    if tag == "break":
        return bp.mix(BONE_D, BONE, 0.35)
    if tag == "jaw":
        return bp.mix(base, BONE_D, 0.08)
    return base


def contact_openness(obj, group, slot_of_face, radius=1.5, floor_band=False):
    """Per vertex 0.3..1: how far (up to radius cm) a bone vertex is from another part (and from the floor when
    floor_band), so the crevices between bones and the floor-contact band darken and separate under candle light."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    mesh = obj.data
    V = fc.verts_cm(obj)
    F = [tuple(p.vertices) for p in mesh.polygons]
    bvh = BVHTree.FromPolygons([Vector(p) for p in V], F, epsilon=0.0)
    vg = np.full(len(V), -1)
    vbone = np.zeros(len(V), bool)
    for fi, f in enumerate(F):
        for v in f:
            vg[v] = group[fi]
            if slot_of_face[fi] == "EnvBone":
                vbone[v] = True
    out = np.ones(len(V))
    for i, p in enumerate(V):
        if not vbone[i]:
            continue
        d = radius
        for loc, nrm, idx, dist in bvh.find_nearest_range(Vector(p), radius):
            if group[idx] != vg[i]:
                d = min(d, dist)
        if floor_band:
            d = min(d, max(float(p[2]), 0.0))
        out[i] = 0.3 + 0.7 * (d / radius)
    return out


def paint_obj(obj, tags, group, seed, env=None, ao_radius=10.0, contact=False, floor_band=False, cavity_darken=0.32):
    """Col: per facet colour by tag + per-part value (+-14 %), warm / cool hue variation and one part in four stained
    30 % toward EnvBoneDark (old bone; a merged pile reads as many bones, ivory to ochre), A = cavity x ambient
    openness x contact openness; orbits, nose, tooth gaps, breaks and backing A = 0, marrow A ~0.2."""
    mesh = obj.data
    N = fc.face_normals(obj)
    rng = np.random.default_rng(seed)
    groups = sorted(set(int(g) for g in group))
    tone = {g: float(rng.uniform(-1.0, 1.0)) for g in groups}
    val = {g: float(rng.uniform(-0.14, 0.14)) for g in groups}
    hue = {g: float(rng.uniform(-1.0, 1.0)) for g in groups}
    stain = {g: (0.3 if rng.uniform() < 0.25 else 0.0) for g in groups}
    slot_of_face = [mesh.materials[p.material_index].name for p in mesh.polygons]
    cols = []
    for t, n, g, sl in zip(tags, N, group, slot_of_face):
        c = face_colour(t, n, tone[int(g)] * (0.35 if sl == "EnvBone" else 1.0))
        if sl == "EnvBone" and t not in DARK_ALPHA:
            h = hue[int(g)] * 0.045
            c = bp.mix(c, BONE_D, stain[int(g)])
            c = c * (1.0 + val[int(g)]) * np.array([1.0 + h, 1.0 + 0.2 * h, 1.0 - h])
        cols.append(c)
    cols = np.clip(np.array(cols), 0.0, 1.0)
    cav = fc.cavity(obj)
    ao = bp.vertex_ao(obj, env=env, radius=ao_radius)
    cav = np.clip(np.minimum(cav, 0.35 + 0.65 * ao) * (0.55 + 0.45 * ao), 0.0, 1.0)
    if contact:
        cav = np.minimum(cav, contact_openness(obj, np.asarray(group), slot_of_face, floor_band=floor_band))
    loops_v = np.empty(len(mesh.loops), dtype=np.int64)
    mesh.loops.foreach_get("vertex_index", loops_v)
    alpha = cav[loops_v].copy()
    for p, t in zip(mesh.polygons, tags):
        if t in DARK_ALPHA:
            alpha[p.loop_start:p.loop_start + p.loop_total] = DARK_ALPHA[t]
    fc.paint(obj, cols, alpha=alpha, variation=0.05, seed=seed, cavity_darken=cavity_darken)
    fc.smart_uv(obj)
    gid = {g: float(rng.uniform()) for g in groups}
    ec.write_data_uv(obj, [gid[int(g)] for g in group], np.zeros(len(group)))


# ================================================================ singles
def build_single(kind, seed, lod="full", open_deg=2.0):
    """One hand-cut part, its buried faces (shaft ends inside knobs, zygoma / brow / ramus roots) culled."""
    asm = bp.Asm(("EnvBone",))
    asm.add_piece(lib(kind, lod, seed=seed, open_deg=open_deg))
    cull_repair(asm, None, n_dirs=48, rays=20000)
    rest_floor(asm)
    return asm


SHARD_SEEDS = (5, 17, 29)
_SHARDS = {}


def shard_set(seed, lod="mid"):
    key = (seed, lod)
    if key not in _SHARDS:
        _SHARDS[key] = [p.rest() for p in bp.make_shards(seed=seed, lod=lod)]
    return _SHARDS[key]


def lay_flat(piece, rng, max_pitch=20.0):
    """A shard lying flat: random roll about its own long axis, then its longest axis levelled within max_pitch."""
    p = piece.transformed(bp.rot_x(rng.uniform(0.0, 360.0))).rest()
    v = p.verts() - p.verts().mean(axis=0)
    w, U = np.linalg.eigh(v.T @ v)
    ax = U[:, -1]
    pitch = math.degrees(math.asin(min(1.0, abs(ax[2]))))
    if pitch > max_pitch:
        horiz = bp._n(np.array([ax[0], ax[1], 0.0]) + 1e-6)
        p = p.transformed(bp.rot_between(ax if ax[2] >= 0 else -ax, horiz)).rest()
    return p


def build_shards(seed=5):
    asm = bp.Asm(("EnvBone",))
    rng = np.random.default_rng(seed)
    pieces = shard_set(SHARD_SEEDS[0], "full")
    st = Stage((-40, -30), (40, 30), cell=0.5)
    spots = [(-11.0, -2.5, 8.0), (10.0, 4.0, -14.0), (-6.0, 10.0, 70.0), (8.0, -9.5, -35.0)]
    for pc, (x, y, yaw) in zip(pieces, spots):
        p = lay_flat(pc, rng)
        asm.add_piece(place(st, p, bp.rot_z(yaw), (x, y), sink=0.25))
    rest_floor(asm)
    return asm


# ================================================================ heaps
def random_skull(rng, lod, weights=(0.35, 0.4, 0.25)):
    kind = rng.choice(["A", "B", "C"], p=list(weights))
    return lib(kind, lod, seed=int(rng.integers(1, 4)), open_deg=2.0)


def axis_pitch(p):
    """Pitch (deg) of a placed piece's principal axis: a long bone standing on end shows up here whatever its pose."""
    v = p.verts() - p.verts().mean(axis=0)
    w, U = np.linalg.eigh(v.T @ v)
    ax = U[:, -1]
    return math.degrees(math.asin(min(1.0, abs(float(ax[2])))))


def skull_faces_front(info, cone=60.0):
    """The skull's face points into the -y hemisphere within cone deg of -y (horizontally)."""
    f = info.face
    h = math.hypot(f[0], f[1])
    if h < 1e-6:
        return False
    return math.degrees(math.acos(max(-1.0, min(1.0, -f[1] / h)))) <= cone


def skull_pose(rng, front=True, outward=0.0):
    """Face toward -y within +-45 deg (front) or along `outward`, rolled +-10, face tipped up 0..20 deg."""
    yaw = rng.uniform(-45.0, 45.0) if front else outward + rng.uniform(-30.0, 30.0)
    return bp.rot_z(yaw) @ bp.rot_y(rng.uniform(-10.0, 10.0)) @ bp.rot_x(-rng.uniform(0.0, 20.0))


HEAP_STATS = {}


def heap(asm, rng, recipe, radius, shrink=0.55, ellipse=(1.0, 1.0), sink=0.6, max_pitch=25.0, tries=14,
         centre_w=0.03):
    """Drop the recipe's pieces onto the growing heap. Positions shrink toward the centre as it grows; long bones
    pitch to the surface under their ends (<= max_pitch) and the outer ring lies tangentially (a rounded mound, not
    spokes); skulls face outward from the pile centre within 60 deg of horizontal. A pose is rejected when a bone
    would pass through a skull (deeper than 1.5 cm) or touch its face. Each piece keeps the accepted pose that lies
    on the most points."""
    half = radius * 1.6 + 30.0
    st = Stage((-half, -half), (half, half), cell=0.7)
    skulls, bones = [], []
    n = len(recipe)
    stats = {"rejected": 0, "skipped": 0}
    for i, (kind, lod) in enumerate(recipe):
        best = None
        for attempt in range(tries * 2):
            if best is not None and attempt >= tries:
                break
            r = radius * (1.0 - shrink * i / max(n - 1, 1)) * math.sqrt(rng.uniform(0.0, 1.0))
            a = rng.uniform(0.0, math.tau)
            xy = (r * math.cos(a) * ellipse[0], r * math.sin(a) * ellipse[1])
            outward = math.degrees(math.atan2(xy[1], xy[0])) + 90.0
            rr = r / max(radius, 1e-6)
            info = None
            if kind in ("A", "B", "C"):
                pc = random_skull(rng, lod, weights={"A": (1, 0, 0), "B": (0, 1, 0), "C": (0, 0, 1)}[kind])
                # most skulls sit on the front half of the heap facing -y (the side the player walks past), face
                # tipped up; the rest face outward
                front = rng.uniform() < 0.8
                if front:
                    a = rng.uniform(-math.pi * 0.92, -math.pi * 0.08)
                    xy = (r * math.cos(a) * ellipse[0], r * math.sin(a) * ellipse[1])
                R = bp.tilt_to(st.hf, xy, 7.0, gain=0.5) @ skull_pose(rng, front, outward)
            elif kind == "J":
                pc = lib("J", lod, seed=2)
                R = bp.tilt_to(st.hf, xy, 6.0) @ bp.rot_z(rng.uniform(0.0, 360.0)) @ bp.rot_y(rng.uniform(-12, 12))
            else:
                pc = lib(kind, lod)
                s = rng.uniform(0.92, 1.05)
                yaw = outward + rng.uniform(-20.0, 20.0) if rr > 0.55 else rng.uniform(0.0, 360.0)
                roll = 0.0 if kind == "Rib" else rng.uniform(0.0, 360.0)      # ribs lie flat side down
                R = bp.bone_pose(st.hf, xy, yaw, ext(pc)[0] * s, roll,
                                 max_pitch=min(max_pitch, 12.0) if kind == "Rib" else max_pitch) @ diag(s, s, s)
            p = drop_only(st, pc, R, xy, sink=0.3 if kind == "Rib" else sink)
            bad = False
            if kind == "Rib" and (float(ext(p)[2]) > 6.0 or axis_pitch(p) > 15.0 or perch_score(st, p) > 1.2):
                bad = True
            if kind in LONG_KINDS and axis_pitch(p) > max_pitch + 3.0:
                bad = True
            if kind in ("A", "B", "C"):
                info = SkullInfo(pc, p, R)
                if abs(info.face[2]) > math.sin(math.radians(60.0)):
                    bad = True
                bad = bad or any(bone_hits_skull(b, info) for b in bones)
                # never bury an earlier skull's face under this one
                for sk in skulls:
                    gap, front = sk.surface_gap(info.c)
                    if front and gap < float(np.max(info.r)) + 1.0:
                        bad = True
            elif kind != "J":
                info = BoneInfo(pc, p, R)
                bad = info.pitch > max_pitch + 4.0 or any(bone_hits_skull(info, sk) for sk in skulls)
            if bad:
                stats["rejected"] += 1
                continue
            score = perch_score(st, p) + 0.3 * float(p.bounds()[0][2]) + centre_w * float(
                np.hypot(xy[0] / ellipse[0], xy[1] / ellipse[1]))
            if best is None or score < best[0]:
                best = (score, p, info)
        if best is None:
            stats["skipped"] += 1
            continue
        st.add(best[1])
        asm.add_piece(best[1])
        if isinstance(best[2], SkullInfo):
            skulls.append(best[2])
        elif isinstance(best[2], BoneInfo):
            bones.append(best[2])
    rest_floor(asm)
    fr = sum(1 for sk in skulls if skull_faces_front(sk)) / max(len(skulls), 1)
    HEAP_STATS["front"] = fr
    print("  heap: %d skulls (%.0f %% face -y within 60 deg), %d bones, %d poses rejected, %d pieces skipped" % (
        len(skulls), 100 * fr, len(bones), stats["rejected"], stats["skipped"]))
    return skulls, bones


def build_skull_stack(seed=21):
    """Three skulls cheek to cheek in a triangle, the fourth seated in the saddle between them facing -y (pitch <= 10,
    yaw within +-20), a jaw leaning on a base skull inside the ~43 cm footprint."""
    rng = np.random.default_rng(seed)
    asm = bp.Asm(("EnvBone",))
    st = Stage((-40, -40), (40, 40), cell=0.5)
    rows = [("A", (-8.2, -6.0), -16.0, 0.0, 3.0), ("B", (8.4, -6.4), 14.0, 2.0, 0.0), ("C", (0.3, 9.4), 172.0, -3.0, 0.0)]
    base = []
    for i, (kind, xy, yaw, roll, nod) in enumerate(rows):
        pc = lib(kind, "full", seed=11 + i, open_deg=3.0)
        p = pc.transformed(bp.rot_z(yaw) @ bp.rot_y(roll) @ bp.rot_x(nod))
        lo, hi = p.bounds()
        p = p.transformed(t=(xy[0] - (lo[0] + hi[0]) * 0.5, xy[1] - (lo[1] + hi[1]) * 0.5, -lo[2]))
        st.add(p)
        base.append(p)
        asm.add_piece(p)
    # the top skull nests in the saddle (centroid of the three), facing -y over the front pair
    pc = lib("B", "full", seed=14)
    R = bp.rot_z(rng.uniform(-12.0, 12.0)) @ bp.rot_x(-6.0) @ bp.rot_y(rng.uniform(-5.0, 5.0))
    cx = float(np.mean([0.5 * (b.bounds()[0][0] + b.bounds()[1][0]) for b in base]))
    cy = float(np.mean([0.5 * (b.bounds()[0][1] + b.bounds()[1][1]) for b in base]))
    asm.add_piece(place(st, pc, R, (cx, cy - 1.0), sink=1.2))
    # a loose jaw on the floor, tipped up against the right base skull's flank (slid in until it touches)
    jaw = lib("J", "mid", seed=3).transformed(bp.rot_z(-70.0) @ bp.rot_y(-34.0))
    lo, hi = jaw.bounds()
    jaw = jaw.transformed(t=(-lo[0], -(lo[1] + hi[1]) * 0.5 - 2.0, -lo[2]))
    target = piece_bvh(base[1])
    for x in np.arange(26.0, 0.0, -0.4):
        q = jaw.transformed(t=(x, 0.0, 0.0))
        if piece_bvh(q).overlap(target):
            break
    asm.add_piece(q)
    rest_floor(asm)
    return asm


def build_pile_a(seed=31):
    rng = np.random.default_rng(seed)
    asm = bp.Asm(("EnvBone",))
    base = [("Femur", "lite"), ("Tibia", "lite"), ("Femur", "lite"), ("Humerus", "lite"), ("Tibia", "lite"),
            ("FemurB", "lite"), ("Rib", "lite"), ("Humerus", "lite")]
    upper = ["Femur", "Tibia", "Humerus", "FemurB", "Rib", "Tibia", "Femur", "Humerus", "Rib"]
    rng.shuffle(upper)
    recipe = (base + [("B", "mid")] + [(k, "mid") for k in upper[:3]] + [("C", "mid")] +
              [(k, "mid") for k in upper[3:6]] + [("A", "mid"), ("J", "mid")] + [(k, "mid") for k in upper[6:]] +
              [("B", "mid")])
    heap(asm, rng, recipe, radius=45.0, shrink=0.6, sink=0.6, max_pitch=25.0)
    return asm


def build_pile_b(seed=41):
    rng = np.random.default_rng(seed)
    asm = bp.Asm(("EnvBone",))
    base = [("Femur", "lite"), ("Tibia", "lite"), ("Humerus", "lite"), ("FemurB", "lite"), ("Tibia", "lite"),
            ("Femur", "lite"), ("Rib", "lite"), ("Humerus", "lite"), ("Tibia", "lite")]
    upper = ["Femur", "Tibia", "Humerus", "FemurB", "Rib", "Rib", "Tibia", "Femur", "Humerus"]
    rng.shuffle(upper)
    recipe = (base + [(k, "mid") for k in upper[:3]] + [("B", "mid")] + [(k, "mid") for k in upper[3:6]] +
              [("C", "mid"), ("J", "mid")] + [(k, "mid") for k in upper[6:]] + [("A", "mid")])
    heap(asm, rng, recipe, radius=78.0, shrink=0.4, ellipse=(1.0, 0.5), sink=0.5, max_pitch=18.0, centre_w=0.014)
    return asm


def poisson_ellipse(rng, n, half, min_d, tries=4000, bias=1.25):
    """Up to n points in the ellipse half = (a, b), at least min_d apart, a little denser toward the centre."""
    pts = []
    for _ in range(tries):
        if len(pts) >= n:
            break
        r = rng.uniform() ** (0.5 * bias)
        a = rng.uniform(0.0, math.tau)
        p = (r * math.cos(a) * half[0], r * math.sin(a) * half[1])
        if all(math.hypot(p[0] - q[0], p[1] - q[1]) >= min_d for q in pts):
            pts.append(p)
    return pts


def scatter(asm, rng, recipe, half=(50.0, 50.0), min_d=12.0, sink=0.3):
    """A flat floor scatter: Poisson-disc spots in an ellipse (min_d apart, denser centre), each piece dropped onto
    z = 0 one at a time. A piece must lie on the floor clear of the others, except that ONE long bone may lean on
    another (<= 15 deg); never a jaw or a skull on a bone. Bones keep off skull faces. Shards lie flat, cycling
    through three shard variants."""
    st = Stage((-half[0] - 35, -half[1] - 35), (half[0] + 35, half[1] + 35), cell=0.6)
    spots = poisson_ellipse(rng, len(recipe) * 3, half, min_d)
    used = []
    skulls, bones = [], []
    leaned = 0
    shard_i = 0
    for kind, lod in recipe:
        placed = None
        order = [k for k in rng.permutation(len(spots)) if k not in used]
        for k in order:
            xy = spots[k]
            for _ in range(5):
                info = None
                if kind in ("A", "B", "C"):
                    pc = random_skull(rng, lod, weights={"A": (1, 0, 0), "B": (0, 1, 0), "C": (0, 0, 1)}[kind])
                    R = skull_pose(rng, True)
                elif kind == "J":
                    pc = lib("J", lod, seed=2)
                    R = bp.rot_z(rng.uniform(0, 360))
                elif kind == "Shard":
                    pcs = shard_set(SHARD_SEEDS[(shard_i // 4) % 3], "mid")
                    pc = lay_flat(pcs[shard_i % 4], rng)
                    R = bp.rot_z(rng.uniform(0, 360))
                else:
                    pc = lib(kind, lod)
                    s = rng.uniform(0.92, 1.05)
                    roll = 0.0 if kind == "Rib" else rng.uniform(0, 360)        # a rib lies flat side down
                    R = bp.bone_pose(st.hf, xy, rng.uniform(0, 360), ext(pc)[0] * s, roll,
                                     max_pitch=15) @ diag(s, s, s)
                p = drop_only(st, pc, R, xy, sink=sink)
                if kind in ("Rib", "Shard") and float(ext(p)[2]) > 8.0:
                    continue
                on_floor = p.bounds()[0][2] <= 0.05
                b = st.bvh()
                touching = b is not None and piece_bvh(p).overlap(b)
                long_bone = kind in LONG_KINDS
                if long_bone:
                    info = BoneInfo(pc, p, R)
                    if any(bone_hits_skull(info, sk) for sk in skulls):
                        continue
                if kind in ("A", "B", "C"):
                    info = SkullInfo(pc, p, R)
                    if any(bone_hits_skull(bb, info) for bb in bones):
                        continue
                if on_floor and not touching:
                    break
                if long_bone and leaned == 0 and info.pitch <= 15.0 and touching:
                    leaned += 1
                    break
            else:
                continue
            placed = (p, info)
            used.append(k)
            break
        if placed is None:
            print("  scatter: no spot for", kind)
            continue
        if kind == "Shard":
            shard_i += 1
        st.add(placed[0])
        asm.add_piece(placed[0])
        if isinstance(placed[1], SkullInfo):
            skulls.append(placed[1])
        elif isinstance(placed[1], BoneInfo):
            bones.append(placed[1])
    rest_floor(asm)


def build_scatter_a(seed=51):
    rng = np.random.default_rng(seed)
    asm = bp.Asm(("EnvBone",))
    recipe = [("Femur", "mid"), ("B", "mid"), ("Tibia", "mid"), ("Humerus", "mid"), ("Rib", "mid"),
              ("Rib", "mid"), ("FemurB", "mid"), ("J", "mid"), ("Shard", "mid"), ("Shard", "mid"),
              ("Shard", "mid")]
    scatter(asm, rng, recipe, half=(50.0, 44.0), min_d=14.0)
    return asm


def build_scatter_b(seed=61):
    rng = np.random.default_rng(seed)
    asm = bp.Asm(("EnvBone",))
    recipe = [("Tibia", "mid"), ("Femur", "mid"), ("C", "mid"), ("Humerus", "mid"), ("Rib", "mid"),
              ("Tibia", "mid"), ("Shard", "mid"), ("Shard", "mid"), ("Rib", "mid"), ("Humerus", "mid"),
              ("Shard", "mid"), ("Shard", "mid")]
    scatter(asm, rng, recipe, half=(50.0, 40.0), min_d=13.0)
    return asm


# ================================================================ packed ossuary fills (seeded rows)
PACKED_W = 14.6          # packed skull width / height / depth at scale 1 (variant 0)
PACKED_H = 14.9
PACKED_D = 14.6


def lane_layer(rng, W, D, z, lod, out, front=0.3, overhang=0.0, scale=1.0, kinds=LONG_KINDS):
    """Hand-cut long bones (lite: 6-sided shaft >= 4.5 cm, whole block knobs) end to end along X, knobs overlapping
    3-5.5 cm, laid flat (knobs spread in depth, roll +-25 deg), bottoms sunk 0.5 cm into the layer below. overhang > 0
    lets the first or last knob stick out past one side of the fill by that much (silhouette). Returns the top."""
    lens = {kd: ext(lib(kd, lod))[0] for kd in kinds}
    side = -1.0 if rng.uniform() < 0.5 else 1.0
    xs = -W * 0.5 - (overhang if side < 0 else 0.0)
    xe = W * 0.5 + (overhang if side > 0 else 0.0)
    x = xs
    tops = []
    k = 0
    below = pieces_bvh(out)
    while x < xe - 5.0:
        kd = kinds[int(rng.integers(0, len(kinds)))]
        s = rng.uniform(0.92, 1.04) * scale
        L = lens[kd] * s
        x0 = max(min(x, xe - L), xs)
        yaw = (180.0 if rng.uniform() < 0.5 else 0.0) + rng.uniform(-2.5, 2.5)
        roll = (180.0 if rng.uniform() < 0.5 else 0.0) + rng.uniform(-25.0, 25.0)
        R = bp.rot_z(yaw) @ bp.rot_x(roll) @ diag(s, s, s)
        p = lib(kd, lod, seed=k).transformed(R)
        lo, hi = p.bounds()
        # alternate the depth a little so overlapping ends never share a face plane
        y = -D + front + (0.45 if k % 2 else 0.0) - lo[1]
        y = min(y, -3.4 - hi[1])                     # never into the back plate
        p = p.transformed(t=(x0 - lo[0], y, z - 0.5 - lo[2]))
        p = settle_on(p, below)
        out.append(p)
        tops.append(p.bounds()[1][2])
        x = x0 + L - rng.uniform(3.0, 5.5)
        k += 1
    return float(np.median(tops)) - 0.3


def top_lanes(rng, W, D, z, lod, out):
    """The top of a fill seen from a gallery: a lane of long bones along X at the front and one at the back over the
    full packed skull domes of the row below, so the top view reads as bone back to y = 0."""
    t = lane_layer(rng, W, D, z, lod, out)
    lane_layer(rng, W - 4.0, D, z - 0.6, lod, out, front=D * 0.64, kinds=("Femur", "Tibia", "FemurB"))
    return t


def ends_layer(rng, W, D, z, out, r=(2.4, 2.8), front=0.3):
    """A row of long-bone ends facing out (concept 1's knob rows): constant-width 6-sided prisms 8 cm deep (no taper
    shows from above), alternating 5 mm in depth."""
    x = -W * 0.5
    tops = []
    k = 0
    while x < W * 0.5 - 1.0:
        rr = rng.uniform(*r)
        p = bp.make_bone_end(rng, r=rr, length=min(8.0, D - 1.0))
        lo, hi = p.bounds()
        w = hi[0] - lo[0]
        cx = min(x + w * 0.5, W * 0.5 - w * 0.5)
        p = p.transformed(t=(cx - (lo[0] + hi[0]) * 0.5, -D + front + (0.6 if k % 2 else 0.0) + 0.1 * (k % 3) - lo[1],
                             z - 0.5 - lo[2] + rng.uniform(0.0, 0.6)))
        out.append(p)
        tops.append(p.bounds()[1][2])
        x += w * 0.92
        k += 1
    return float(np.median(tops)) - 0.3


def ends_cluster(rng, x, D, z, s, out, front=0.3):
    """Five bone ends heaped in one skull's slot (a gap in a row filled with bone, concept 1)."""
    r = 2.45 * s
    for u, v in ((-0.95, 0.0), (0.95, 0.05), (-1.0, 1.45), (1.0, 1.42), (0.05, 2.8)):
        rr = r * rng.uniform(0.9, 1.08)
        p = bp.make_bone_end(rng, r=rr, length=8.0)
        lo, hi = p.bounds()
        p = p.transformed(t=(x + u * r * 1.05 - (lo[0] + hi[0]) * 0.5, -D + front + rng.uniform(0.0, 1.5) - lo[1],
                             z - 0.5 + v * r - lo[2]))
        out.append(p)


def skull_layer(rng, W, D, z, n, s, out, front=0.3, x_off=0.0, lod="PF", swaps=(1, 2), jaw=True, clusters=True):
    """n packed skulls in a row facing -y, crammed and hand-placed: yaw +-12, roll +-8, nod +-10 deg, scale 0.88-1.12,
    x jitter 1.5, drop 0-2, depth 0-2.5 cm. One or two slots (swaps) hold a crown-out skull or a heap of bone ends
    instead, one skull keeps its jaw. Returns the row top (median of the face-out skulls)."""
    pitch = W / n
    tops = []
    n_sw = int(rng.integers(swaps[0], swaps[1] + 1)) if swaps else 0
    n_sw = min(n_sw, max(n - 2, 0))
    order = [int(i) for i in rng.permutation(n)]
    swap_i = set(order[:n_sw])
    jaw_i = order[n_sw] if jaw else -1
    h_p = ext(lib("P", seed=0))[2]
    for i in range(n):
        x = x_off - W * 0.5 + (i + 0.5) * pitch + rng.uniform(-1.5, 1.5)
        si = s * rng.uniform(0.88, 1.12)
        v = int(rng.integers(0, 3))
        drop = rng.uniform(0.0, 2.0)
        if i in swap_i and clusters and rng.uniform() < 0.5:
            ends_cluster(rng, x, D, z, s, out, front)
            continue
        if i in swap_i:
            # a skull crammed in turned 35-50 deg, looking along the row (a full profile or a back reads as a stone)
            kind = "P"
            R = (bp.rot_z(rng.choice([-1.0, 1.0]) * rng.uniform(35.0, 50.0)) @ bp.rot_x(rng.uniform(-10.0, 10.0)) @
                 diag(si, si, si))
        else:
            kind = "PJ" if i == jaw_i else lod
            R = (bp.rot_z(rng.uniform(-12.0, 12.0)) @ bp.rot_y(rng.uniform(-8.0, 8.0)) @
                 bp.rot_x(rng.uniform(-10.0, 10.0)) @ diag(si, si, si))
        pc = lib(kind, seed=v)
        if kind == "PJ":
            drop += (ext(pc)[2] - h_p) * si * 0.6         # the jaw sinks into the layer below
        p = pc.transformed(R)
        lo, hi = p.bounds()
        p = p.transformed(t=(x - (lo[0] + hi[0]) * 0.5, -D + front + rng.uniform(0.0, 2.5) - lo[1],
                             z - 0.5 - drop - lo[2]))
        out.append(p)
        if kind in (lod, "P") and i not in swap_i:
            tops.append(p.bounds()[1][2])
    if not tops:
        tops = [z + PACKED_H * s]
    return float(np.median(tops)) - 0.6


def pieces_bvh(pieces):
    """One BVH over placed pieces (None when there are none)."""
    if not pieces:
        return None
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    V, T, base = [], [], 0
    for pc in pieces:
        for sh in pc.shells:
            V.append(sh.v)
            T.extend([(f[0] + base, f[i] + base, f[i + 1] + base) for f in sh.f for i in range(1, len(f) - 1)])
            base += len(sh.v)
    return BVHTree.FromPolygons([Vector(q) for q in np.concatenate(V)], T, epsilon=0.0)


def settle_on(p, bvh, step=0.3, max_drop=12.0):
    """Lower a laid piece until it touches what is under it (a lane bone over a gap in the row below)."""
    if bvh is None:
        return p
    drop = 0.0
    while drop < max_drop and not piece_bvh(p).overlap(bvh):
        p = p.transformed(t=(0.0, 0.0, -step))
        drop += step
    # a real 0.5 cm bite, not a grazing contact (a grazing facet z-fights)
    return p.transformed(t=(0.0, 0.0, -0.5)) if drop > 0.0 else p


def fill_skull_count(W, s0):
    w = PACKED_W * s0
    n = max(2, int(round((W - 0.1 * w) / (0.9 * w))))
    return n, W / (PACKED_W * (0.9 * n + 0.1))


def bed_piece(pts):
    """A hidden bone bed (hull): its top faces are painted as bone in shadow (bedtop), the rest dark (backing)."""
    v, f = bp.hull(np.array(pts), dissolve_deg=0.5)
    tags = ["bedtop" if bp.newell(v[ff])[2] > 0.7 else "backing" for ff in f]
    return bp.Piece("Bed", [bp.Shell(v, f, tags, "EnvBone", "block")])


def build_fill_pieces(W, H, D, seed, layers, s0=1.0, lane_lod="lite", backing=True, n=None, skull_lod="PF",
                      swaps=(1, 2), jaw=True, overhang=2.5, top_full=True, clusters=True, skull_beds=True,
                      lane_scale=1.0, lane_kinds=LONG_KINDS, lane_beds=True):
    """The pieces of a packed fill in its own frame: back at y = 0, front toward -y at y = -D, x centred, z 0 up to H.
    layers bottom to top: 'lane' (long bones laid crosswise), 'ends' (bone ends facing out), 'skulls' (a row; the top
    row uses the full packed skull, lower rows the front-only LOD), 'toplane' (three lanes front to back)."""
    rng = np.random.default_rng(seed)
    if n is None:
        n, s = fill_skull_count(W, s0)
    else:
        s = s0
    out = []
    bed_ids = set()

    def add_bed(za, zb, yf):
        """A hidden bed of bone behind the front pieces, added at once so the next layer settles onto it. Its front
        leans back ~25 deg (the packed tooth band leans 12), its top rises 0.6 cm to the back, it turns 0.5-1 deg:
        it never lies parallel to a bone facet."""
        if zb - za < 1.0:
            return
        yt, yb, y1 = yf, yf + (zb - za) * 0.47, -0.2
        x0, x1 = -W * 0.5 + 0.3, W * 0.5 - 0.3
        dy = math.tan(math.radians(rng.uniform(0.5, 1.0))) * rng.choice([-1.0, 1.0])
        pts = [(x, y + dy * x, z_ + (0.6 if (y == y1 and z_ == zb) else 0.0)) for x in (x0, x1)
               for (y, z_) in ((yt, zb), (yb, za), (y1, zb), (y1, za))]
        pts = [(x, min(y, -0.2), z_) for x, y, z_ in pts]
        bed_ids.add(len(out))
        out.append(bed_piece(pts))
    z = 0.0
    first_lane = True
    last_start = 0
    last_skulls = max(i for i, x in enumerate(layers) if x == "skulls")
    for li, layer in enumerate(layers):
        z_in = z
        last_start = len(out)
        if layer == "lane":
            z = lane_layer(rng, W, D, z, lane_lod, out, overhang=overhang if first_lane else 0.0, scale=lane_scale,
                           kinds=lane_kinds)
            first_lane = False
            if lane_beds:
                add_bed(z_in + 0.4, z + 0.8, -D + 3.2)
        elif layer == "toplane":
            z = top_lanes(rng, W, D, z, lane_lod, out)
        elif layer == "ends":
            z = ends_layer(rng, W, D, z, out)
            add_bed(z_in + 0.4, z + 0.8, -D + 3.2)
        else:
            lod = "P" if (top_full and li == last_skulls) else skull_lod
            z = skull_layer(rng, W, D, z, n, s, out, lod=lod, swaps=swaps, jaw=jaw, clusters=clusters)
            if skull_beds:
                # a low bed behind a skull row: it carries the skulls, the next layer rests on their crowns, and
                # from above it stays hidden under the domes
                add_bed(z_in + 0.4, z_in + 0.55 * (z - z_in), -D + 4.5 * s)
    lo = min(p.bounds()[0][2] for p in out)
    out = [p.transformed(t=(0.0, 0.0, -lo)) for p in out]
    top = max(p.bounds()[1][2] for p in out)
    k = H / top
    if not 0.86 <= k <= 1.145:
        print("  WARNING fill %s: z squeeze %.2f" % (seed, k))
    out = [p.transformed(diag(1.0, 1.0, k)) for p in out]
    top_med = float(np.median([p.bounds()[1][2] for i, p in enumerate(out) if i >= last_start and i not in bed_ids]))
    if backing:
        # the back plate stops 1 cm under the top layer (no dark band above the top bones)
        hb = min(H, top_med - 1.0)
        # the front leans back 3 deg so no axis-aligned bone facet lies on its plane
        pts = [(x, y, z_) for x in (-W * 0.5, W * 0.5) for (y, z_) in ((-3.0, 0.0), (-3.0 + hb * 0.05, hb),
                                                                         (0.0, 0.0), (0.0, hb))]
        v, f = bp.hull(np.array(pts), dissolve_deg=0.5)
        out.append(bp.Piece("Backing", [bp.Shell(v, f, "backing", "EnvBone", "block")]))
    return out, n, s


FILL_SPECS = {
    # name: (W, H, D, seed, layers, skull scale target)
    "OssuaryFill_A": (100.0, 45.0, 35.0, 101, ["lane", "skulls", "lane", "skulls"], 1.0),
    "OssuaryFill_B": (134.0, 45.0, 35.0, 121, ["lane", "skulls", "ends", "skulls", "toplane"], 1.1),
    "OssuaryFill_B2": (134.0, 45.0, 35.0, 131, ["ends", "skulls", "lane", "skulls", "toplane"], 1.1),
    "OssuaryFill_Niche": (75.0, 50.0, 25.0, 111, ["ends", "skulls", "lane", "skulls", "ends", "toplane"], 1.0),
}


def build_fill(name):
    W, H, D, seed, layers, s0 = FILL_SPECS[name]
    asm = bp.Asm(("EnvBone",))
    pieces, n, s = build_fill_pieces(W, H, D, seed, layers, s0=s0)
    print("  %s: %d skulls per row at scale %.2f" % (name, n, s))
    for p in pieces:
        asm.add_piece(p)
    lo, hi = asm_bounds(asm)
    shift_asm(asm, (-(lo[0] + hi[0]) * 0.5, -hi[1], -lo[2]))       # back y = 0, x centred, z 0
    return asm


# ================================================================ chiselled stone (shelf, pier)
def stone_box(asm, rng, center, size, flat=("-z",), tag="slab", group=None, **kw):
    v, f = bp.chisel_box(center, size, rng, flat=flat, **kw)
    return asm.add_vf(v, f, "EnvStone", tag, group=group)


def transform_shells(shells, R=None, t=None):
    return [(sh.transformed(R, t), g) for sh, g in shells]


def clip_new(asm, start, planes, cap_tag):
    """Clip the shells added since index start by each (point, outward normal) plane (chips, broken corners)."""
    new = []
    for sh, g in asm.shells[start:]:
        cur = sh
        for p0, n in planes:
            if cur is None:
                break
            cur = bp.clip_shell(cur, p0, n, cap_tag=cap_tag)
        if cur is not None and cur.f:
            new.append((cur, g))
    asm.shells = asm.shells[:start] + new


def arris_chip(rng, xe, sx, y_front, z0, z1, a):
    """A bevel cut along the front vertical arris at x = xe (sx = +1 right edge, -1 left): depth a at one end of the
    course tapering to a fraction at the other, so it reads as a broken corner, not a uniform chamfer."""
    top_deep = rng.uniform() < 0.5
    dt, db = (a, a * rng.uniform(0.0, 0.45)) if top_deep else (a * rng.uniform(0.0, 0.45), a)
    P1 = np.array([xe - sx * dt, y_front, z1])
    P2 = np.array([xe, y_front + dt, z1])
    P3 = np.array([xe - sx * db, y_front, z0])
    P4 = np.array([xe, y_front + db, z0])
    if dt < 0.3:
        P1, P2, P3 = P3, P4, P1 + np.array([sx * 0.3, 0.0, 0.0])
    n = np.cross(P2 - P1, P3 - P1)
    corner = np.array([xe, y_front, 0.5 * (z0 + z1)])
    if np.dot(corner - P1, n) < 0.0:
        n = -n
    return P1, n


def course(asm, rng, x0, x1, z0, z1, y_front, y_back, holes, kind="post", R=None, t=None, chips=(), rot=1.5,
           ch=None, keep_back=True):
    """One hand-cut stone course: carved front (holes), 1-2 broken front arrises (chips = list of +-1 sides with a
    depth), the whole course turned +-rot deg about z (the back stays on its plane when keep_back), then placed."""
    start = len(asm.shells)
    g = bp.carved_block(asm, x0, x1, z0, z1, y_front, y_back, holes, rng, kind=kind,
                        ch=ch if ch is not None else rng.uniform(1.3, 2.0))
    planes = []
    for sx, a in chips:
        xe = x1 if sx > 0 else x0
        planes.append(arris_chip(rng, xe, sx, y_front, z0, z1, a))
    if planes:
        clip_new(asm, start, planes, kind + "/chip")
    ang = rng.uniform(-rot, rot)
    if abs(ang) > 1e-3:
        Rz = bp.rot_z(ang)
        c = np.array([(x0 + x1) * 0.5, y_front, 0.0])            # the front face turns in place
        moved = transform_shells(asm.shells[start:], Rz, c - Rz @ c)
        if keep_back:
            ymax = max(float(sh.v[:, 1].max()) for sh, _ in moved)
            moved = transform_shells(moved, None, (0.0, y_back - ymax, 0.0))
        asm.shells[start:] = moved
    if R is not None or t is not None:
        asm.shells[start:] = transform_shells(asm.shells[start:], R, t)
    return g


def jitter_bounds(rng, bounds, amp=3.0):
    """Course boundaries with the inner joints moved +-amp cm (the first and last stay)."""
    b = list(bounds)
    for i in range(1, len(b) - 1):
        b[i] += rng.uniform(-amp, amp)
    return b


def crack_segments(cx, zj, sx, rng, below=9.0, above=8.0, w=1.1):
    """A crack across the course joint at zj: two convex parallelograms meeting at the joint (one per course), the
    groove ~1.1 cm wide. Returns (lower poly, upper poly) in (x, z)."""
    xa = cx + rng.uniform(-1.0, 1.0)
    xb = xa - sx * rng.uniform(0.5, 2.0)
    xc = xb + sx * rng.uniform(-1.5, 1.5)
    h = w * 0.5
    lower = np.array([(xa - h, zj - below), (xa + h, zj - below), (xb + h, zj), (xb - h, zj)])
    upper = np.array([(xb - h, zj), (xb + h, zj), (xc + h, zj + above), (xc - h, zj + above)])
    return lower, upper


def post_stack(asm, rng, cx, w, y_front, y_back, bounds, carves, R=None, t=None, cracks=(), niche_sizes=None,
               keep_back=True, chip2=0.6, chip_p=1.0):
    """A stone post of stacked courses carved on its front (toward -y in its frame): 'cross' = a recessed Latin cross,
    'niche' = a pointed gothic niche, 'deep' = the deep skull niche (niche_sizes = (width, height, depth)), None = plain.
    cracks = joint indices that get a V-groove crack running across them. Returns {course: niche info}."""
    info = {}
    n = len(bounds) - 1
    crack_holes = {i: [] for i in range(n)}
    crack_side = {}
    for j in cracks:
        sx = rng.choice([-1.0, 1.0])
        xcr = cx + sx * (w * 0.5 - rng.uniform(6.0, 7.0))
        lo_p, up_p = crack_segments(xcr, bounds[j], sx, rng)
        crack_holes[j - 1].append((lo_p, 1.0, "crack"))
        crack_holes[j].append((up_p, 1.0, "crack"))
        crack_side[j - 1] = crack_side[j] = sx
    for i in range(n):
        z0, z1 = bounds[i], bounds[i + 1]
        carve = carves[i]
        holes = list(crack_holes[i])
        hgt = z1 - z0
        if carve == "cross":
            ch_ = hgt * 0.62
            cz = z0 + hgt * 0.2
            span, bar = min(w * 0.52, 20.0), max(min(w * 0.15, 6.0), 4.0)
            for poly in bp.cross_holes(cx, cz, ch_, span, bar, cz + ch_ * 0.6):
                holes.append((poly, 3.2, "cross"))
        elif carve == "niche":
            nw = w * 0.5
            arch = nw * math.sin(math.radians(60.0))
            zb = z0 + hgt * 0.16
            jamb = max(hgt * 0.84 - arch - hgt * 0.12, nw * 0.5)
            holes.append((bp.gothic_arch(cx, zb, nw, jamb), 7.0, "niche"))
            info[i] = (zb, cx, nw, 7.0, zb + jamb + arch)
        elif carve == "deep":
            nw, nh, depth = niche_sizes
            arch = nw * math.sin(math.radians(60.0))
            zb = z0 + (hgt - nh) * 0.5
            holes.append((bp.gothic_arch(cx, zb, nw, nh - arch), depth, "niche"))
            info[i] = (zb, cx, nw, depth, zb + nh)
        # 1-2 chipped front arrises, never on the side a crack runs (the groove stays clean)
        sides = [-1.0, 1.0]
        if i in crack_side:
            sides = [s for s in sides if s != crack_side[i]]
        k = (1 if rng.uniform() < chip2 else 2) if rng.uniform() < chip_p else 0
        chips = [(s, rng.uniform(3.0, 6.0)) for s in rng.permutation(sides)[:min(k, len(sides))]]
        ww = w + rng.uniform(-0.8, 0.8)
        x0, x1 = cx - ww * 0.5 + rng.uniform(-0.3, 0.3), cx + ww * 0.5 + rng.uniform(-0.3, 0.3)
        course(asm, rng, x0, x1, z0, z1, y_front, y_back, holes, R=R, t=t, chips=chips, keep_back=keep_back)
    return info


def lipped_slab(asm, rng, x0, x1, y_back, y_lip, y_post, z0, z1, into=3.0, R=None, group=None, tilt=0.0):
    """A thick, hand-cut shelf slab between two post faces (x0, x1): its front lip stands ~5 cm proud of the posts,
    its top front edge is cut by 2-3 flat chamfer planes of different depth (deeper toward the ends, so each one
    shows), the lip bows 2-4 mm forward in the middle, the lip ends slant back into the posts. tilt turns the whole
    slab about its own length axis' centre (deg about Y)."""
    n_st = int(rng.integers(3, 5)) if x1 - x0 > 90.0 else 3
    xs = np.linspace(x0 + 1.5, x1 - 1.5, n_st)
    ends = (rng.uniform(2.4, 3.4), rng.uniform(2.4, 3.4))
    pts = []
    for i, x in enumerate(xs):
        t = i / (n_st - 1)
        if i in (0, n_st - 1):
            chm = ends[0] if i == 0 else ends[1]
            bow = 0.0
        else:
            chm = rng.uniform(1.0, 1.8)
            bow = rng.uniform(0.2, 0.4)
        del t
        yl = y_lip - bow
        pts += [(x, yl + chm, z1), (x, yl, z1 - chm * rng.uniform(0.7, 1.1)), (x, yl, z0)]
    for z in (z1, z0):
        pts += [(x1 + into, y_post, z), (x1 + into, y_back, z), (x0 - into, y_back, z), (x0 - into, y_post, z)]
    pts = np.array(pts) + np.concatenate([rng.uniform(-0.2, 0.2, (len(pts), 2)), np.zeros((len(pts), 1))], axis=1)
    if tilt:
        c = np.array([0.5 * (x0 + x1), 0.5 * (y_back + y_lip), 0.5 * (z0 + z1)])
        pts = (pts - c) @ bp.rot_y(tilt).T + c
    v, f = bp.hull(pts, dissolve_deg=0.5)
    if R is not None:
        v = v @ np.asarray(R, float).T
    return asm.add_vf(v, f, "EnvStone", "slab", group=group)


def broken_corners(asm, start, rng, corners, depth=(5.0, 8.0)):
    """Knock 1-2 corners off the shells added since start: corners = [(corner point, outward diagonal)]."""
    planes = []
    for c, d in corners:
        a = rng.uniform(*depth)
        d = bp._n(d)
        planes.append((np.asarray(c, float) - d * a * 0.6, d + rng.uniform(-0.15, 0.15, 3)))
    clip_new(asm, start, planes, "chip")


# ---- OssuaryShelf_A: 200 W x 260 H x ~71 D, back at y = 0
SH_W = 200.0
SH_POST_W = 32.0
SH_BAY_X = SH_W * 0.5 - SH_POST_W            # 68: posts' inner faces (bay 136 W)
SH_POST_FRONT = -66.0
SH_LIP = -71.0                               # slab lips 5 cm proud of the posts
SH_BACK = 8.0                                # back panel thickness (bay back at y = -8)
SH_FLOORS = (14.0, 74.0, 134.0, 194.0)       # bay floors: plinth + three slabs (four bays, 49-50 clear)
SH_SLAB_T = 11.0
SH_TOP = 244.0                               # posts' top = cornice underside
SH_CORNICE = (SH_TOP, SH_TOP + 16.0)
SH_FILL_D = 35.4                             # OssuaryFill_B / B2 depth
SH_SOCKET_Y = SH_LIP + 2.0 + SH_FILL_D       # -33.6: a fill's back here puts its front 2 cm behind the slab lip
SHELF_BAYS = []                              # (bay floor z at x = 0, slab tilt deg) per row, set by build_shelf


def build_shelf(seed=71):
    rng = np.random.default_rng(seed)
    asm = bp.Asm(("EnvStone",))
    for k, sgn in enumerate((-1.0, 1.0)):
        bounds = jitter_bounds(rng, (0.0, 24.0, 88.0, 148.0, 196.0, SH_TOP))
        post_stack(asm, rng, sgn * (SH_BAY_X + SH_POST_W * 0.5), SH_POST_W, SH_POST_FRONT, 0.0, bounds,
                   [None, "cross", None, "niche", None])
    span = 2.0 * SH_BAY_X + 8.0
    stone_box(asm, rng, (0.0, -SH_BACK * 0.5, SH_TOP * 0.5), (span, SH_BACK, SH_TOP), flat=("-z", "+y"))
    SHELF_BAYS.clear()
    for r, zt in enumerate(SH_FLOORS):
        # hand-set slabs: +-1 cm in height, +-0.6 deg along their length, one broken lip corner each
        dz = 0.0 if r == 0 else rng.uniform(-1.0, 1.0)
        tilt = 0.0 if r == 0 else rng.uniform(-0.6, 0.6)
        z0 = 0.0 if r == 0 else zt + dz - SH_SLAB_T
        start = len(asm.shells)
        lipped_slab(asm, rng, -SH_BAY_X, SH_BAY_X, -SH_BACK + 2.0, SH_LIP, SH_POST_FRONT, z0, zt + dz, tilt=tilt)
        sx = rng.choice([-1.0, 1.0])
        broken_corners(asm, start, rng, [((sx * (SH_BAY_X - 1.5), SH_LIP, zt + dz), (sx, -1.0, 0.7))],
                       depth=(4.0, 7.0))
        SHELF_BAYS.append((zt + dz, tilt))
    # flat chamfered cornice cap with a forward lip, two broken front corners
    z0, z1 = SH_CORNICE
    start = len(asm.shells)
    stone_box(asm, rng, (0.0, SH_LIP * 0.5, (z0 + z1) * 0.5), (SH_W + 4.0, -SH_LIP, z1 - z0), flat=("-z", "+y"),
              ch=(1.6, 2.4), chip_p=0.0)
    broken_corners(asm, start, rng, [((-(SH_W + 4.0) * 0.5, SH_LIP, z1), (-1.0, -1.0, 1.0)),
                                     (((SH_W + 4.0) * 0.5, SH_LIP, z0 + 3.0), (1.0, -1.0, -0.4))])
    return asm


def shelf_sockets():
    """[(name, location cm, rotation deg)] of the bay sockets: a fill's back edge on the bay floor at SH_SOCKET_Y,
    turned with its slab."""
    out = []
    for r, (zf, tilt) in enumerate(SHELF_BAYS):
        y = SH_SOCKET_Y
        # the slab turns about its own centre: the floor under the socket moves with it
        c = np.array([0.0, 0.5 * (-SH_BACK + 2.0 + SH_LIP), zf - (SH_SLAB_T * 0.5 if r else zf * 0.5)])
        p = bp.rot_y(tilt) @ (np.array([0.0, y, zf]) - c) + c
        out.append(("Bay_%d1" % (r + 1), p, (0.0, tilt, 0.0)))
    return out


def shelf_extras(obj):
    for name, loc, rot in shelf_sockets():
        sc.add_socket(obj, name, loc, rotation_deg=rot)
    for sgn in (-1.0, 1.0):
        cx = sgn * (SH_BAY_X + SH_POST_W * 0.5)
        sc.add_ucx(obj, bp.box_vf((cx, SH_POST_FRONT * 0.5, SH_TOP * 0.5), (SH_POST_W, -SH_POST_FRONT, SH_TOP))[0])
    sc.add_ucx(obj, bp.box_vf((0.0, -SH_BACK * 0.5, SH_TOP * 0.5), (2 * SH_BAY_X, SH_BACK, SH_TOP))[0])
    for r, (zt, tilt) in enumerate(SHELF_BAYS):
        z0 = 0.0 if r == 0 else zt - SH_SLAB_T
        sc.add_ucx(obj, bp.box_vf((0.0, SH_LIP * 0.5, (z0 + zt) * 0.5), (2 * SH_BAY_X, -SH_LIP, zt - z0))[0])
    z0, z1 = SH_CORNICE
    sc.add_ucx(obj, bp.box_vf((0.0, SH_LIP * 0.5, (z0 + z1) * 0.5), (SH_W, -SH_LIP, z1 - z0))[0])


# ---- OssuaryPier_A: ~226 x 147 x 293, freestanding (concept 1: wide skull bays, one centre post per long face)
PR_X = 110.0                                 # half length (end posts' outer faces)
PR_Y = 65.0                                  # half depth (posts' fronts)
PR_LIP = 70.0                                # slab lips, 5 cm proud
PR_END_W = 26.0                              # end posts (and the end cores behind them)
PR_MID_W = 30.0                              # the centre post with the skull niche and the cross
PR_END_D = 26.0                              # end posts' depth on the long faces (the end core fills between)
PR_SPINE = 44.0                              # spine half depth: the fills' backs
PR_FLOORS = (20.0, 95.0, 170.0)              # slab tops (plinth + two slabs); bays 64 clear
PR_SLAB_T = 13.0                             # chunky slabs; bays 62 clear
PR_TOP = 234.0
PR_TOPSLAB = (PR_TOP, PR_TOP + 14.0)
PR_RISE = 35.0                               # the centre posts rise above the top slab
PR_CAP = 6.0
PR_INNER = PR_X - PR_END_W                   # 84: end posts' inner faces
PR_BAY_W = PR_INNER - PR_MID_W * 0.5         # 69
PR_BAYS = (-(PR_MID_W * 0.5 + PR_BAY_W * 0.5), PR_MID_W * 0.5 + PR_BAY_W * 0.5)
PR_NICHE = (20.0, 32.0, 15.0)                # centre-post skull niche: width, height (arch included), depth
PR_FILL_D = PR_Y - PR_SPINE + 2.5            # bay fills stand 2 cm proud of the posts, 3 cm behind the lips


def face_R(face):
    return None if face < 0 else bp.rot_z(180.0)


def build_pier(seed=81):
    rng = np.random.default_rng(seed)
    asm = bp.Asm(("EnvBone", "EnvStone"))
    niches = []
    posts = ((-(PR_X - PR_END_W * 0.5), PR_END_W), (0.0, PR_MID_W), (PR_X - PR_END_W * 0.5, PR_END_W))
    for face in (-1.0, 1.0):
        R = face_R(face)
        for k, (cx, w) in enumerate(posts):
            lx = cx if R is None else -cx
            bounds = jitter_bounds(rng, (0.0, 26.0, 92.0, 170.0, PR_TOP))
            if k == 1:
                carves = [None, "cross", "deep", None]
                y_back = -PR_SPINE + 2.0
            else:
                carves = [None, "cross", "niche", None]
                y_back = -PR_Y + PR_END_D + 2.0
            info = post_stack(asm, rng, lx, w, -PR_Y, y_back, bounds, carves, R=R, niche_sizes=PR_NICHE,
                              keep_back=False, chip2=1.0, chip_p=1.0)
            if k == 1:
                niches.append((face, info[2]))
    # end cores: the short faces, a deep arched panel with a raised Latin cross standing in it
    for sgn in (-1.0, 1.0):
        R = bp.rot_z(90.0 * sgn)
        t = (sgn * (PR_INNER - 1.0), 0.0, 0.0)      # the end face stands 4 cm inside the end posts: never coplanar
        half = PR_Y - PR_END_D + 2.0
        bounds = jitter_bounds(rng, (0.0, 26.0, 205.0, PR_TOP), amp=2.0)
        panel = bp.gothic_arch(0.0, 42.0, 54.0, 150.0 - 54.0 * math.sin(math.radians(60.0)))
        for i in range(3):
            holes = [(panel, 9.0, "recess")] if i == 1 else []
            chips = [(rng.choice([-1.0, 1.0]), rng.uniform(3.0, 5.5))]
            course(asm, rng, -half, half, bounds[i], bounds[i + 1], -PR_END_W + 3.0, 0.0, holes, R=R, t=t,
                   chips=chips, rot=1.0, keep_back=False)
        # the raised cross on the recess floor, its front 3 cm behind the face
        y_floor = -PR_END_W + 3.0 + 9.0
        for cxz, size, dy in (((0.0, 70.0 + 42.0), (11.0, 7.5, 92.0), 0.0), ((0.0, 132.0), (46.0, 7.1, 11.0), 0.4)):
            c = np.array([cxz[0], y_floor - size[1] * 0.5 + 1.5 + dy, cxz[1]])
            v, f = bp.chisel_box(c, size, rng, ch=(0.8, 1.4), chip_p=0.15, chip=(1.0, 2.5), flat=("+y",),
                                 no_bulge=("-y",))
            v = v @ R.T + np.asarray(t)
            asm.add_vf(v, f, "EnvStone", "post/face")
    # spine core, plinths and lipped slabs in every bay on both faces
    stone_box(asm, rng, (0.0, 0.0, PR_TOP * 0.5), (2 * PR_INNER + 2.0, 2 * PR_SPINE, PR_TOP), flat=("-z",))
    for face in (-1.0, 1.0):
        R = face_R(face)
        # one plinth step along the whole face (it runs in front of the centre post too)
        lipped_slab(asm, rng, -PR_INNER, PR_INNER, -PR_SPINE + 1.0, -PR_LIP, -PR_Y, 0.0, PR_FLOORS[0], R=R)
        for bx in PR_BAYS:
            x0, x1 = bx - PR_BAY_W * 0.5, bx + PR_BAY_W * 0.5
            for zt in PR_FLOORS[1:]:
                start = len(asm.shells)
                lipped_slab(asm, rng, x0, x1, -PR_SPINE + 1.0, -PR_LIP, -PR_Y, zt - PR_SLAB_T, zt, R=R)
                if rng.uniform() < 0.5:
                    sx = rng.choice([-1.0, 1.0])
                    c = np.array([bx + sx * (PR_BAY_W * 0.5 - 1.5), -PR_LIP, zt])
                    d = np.array([sx, -1.0, 0.7])
                    if R is not None:
                        c, d = R @ c, R @ d
                    broken_corners(asm, start, rng, [(c, d)], depth=(4.0, 6.5))
    # top slab with two broken corners
    z0, z1 = PR_TOPSLAB
    start = len(asm.shells)
    top_g = stone_box(asm, rng, (0.0, 0.0, (z0 + z1) * 0.5), (2 * PR_X + 6.0, 2 * PR_Y + 8.0, z1 - z0),
                      flat=("-z", "+z"), ch=(1.4, 2.2), chip_p=0.0)
    broken_corners(asm, start, rng, [((-(PR_X + 3.0), -(PR_Y + 4.0), z1), (-1.0, -1.0, 0.9)),
                                     ((PR_X + 3.0, PR_Y + 4.0, z1), (1.0, 1.0, 0.9))])
    # the centre posts rise above the top slab: a block with one gothic niche and a chamfered flat cap stone
    for face in (-1.0, 1.0):
        R = face_R(face)
        course(asm, rng, -16.0, 16.0, z1 - 1.0, z1 + PR_RISE, -PR_Y, -PR_Y + 26.0,
               [(bp.gothic_arch(0.0, z1 + 8.0, 12.0, 21.0 - 12.0 * math.sin(math.radians(60.0))), 5.0, "niche")],
               R=R, chips=[(rng.choice([-1.0, 1.0]), rng.uniform(2.5, 4.0))], rot=1.0, keep_back=False)
        c = np.array([0.0, -PR_Y + 12.5, z1 + PR_RISE + PR_CAP * 0.5])
        v, f = bp.chisel_box(c, (40.0, 31.0, PR_CAP), rng, ch=(1.2, 1.8), chip_p=0.25, chip=(2.0, 3.5),
                             flat=("-z",))
        if R is not None:
            v = v @ R.T
        asm.add_vf(v, f, "EnvStone", "slab")
    # fills in every bay: three rows of three packed skulls (front-only LOD), a lane of long bones, crammed and
    # varied (a crown-out skull or a heap of bone ends in some slots)
    fill_n = 0
    for face in (-1.0, 1.0):
        R = face_R(face)
        for bx in PR_BAYS:
            for zf in PR_FLOORS:
                pieces, n, s = build_fill_pieces(PR_BAY_W - 1.0, 59.0, PR_FILL_D, 900 + fill_n,
                                                 ["skulls", "lane", "skulls"], s0=1.66, lane_lod="lite",
                                                 backing=False, n=3, skull_lod="PF", swaps=(0, 1), jaw=False,
                                                 overhang=0.0, top_full=False, clusters=False, skull_beds=True,
                                                 lane_scale=1.25, lane_kinds=("Femur", "Tibia"), lane_beds=True)
                fill_n += 1
                for p in pieces:
                    q = p.transformed(t=(bx, -PR_SPINE + 0.5, zf - 0.3))
                    if R is not None:
                        q = q.transformed(R)
                    asm.add_piece(q)
    # a skull in each centre-post niche, seated on a stone sill, its crown ~3.5 cm under the arch apex
    for face, (zb, nx, nw, depth, zt) in niches:
        R = face_R(face)
        pc = lib("PF", seed=1 if face < 0 else 2)        # seen only from the front, deep in its niche
        e = ext(pc)
        s = min((nw - 4.0) / e[0], 21.0 / e[2])
        sill_h = (zt - 3.5) - zb - e[2] * s
        c = np.array([0.0, -PR_Y + depth * 0.5 + 1.0, zb + sill_h * 0.5 - 0.5])
        v, f = bp.chisel_box(c, (nw + 1.0, depth, sill_h + 1.0), rng, ch=(0.6, 1.0), chip_p=0.0,
                             flat=("-z", "+z", "+y", "-x", "+x"))
        if R is not None:
            v = v @ R.T
        asm.add_vf(v, f, "EnvStone", "post/recess")
        p = pc.transformed(bp.rot_z(rng.uniform(-6.0, 6.0)) @ diag(s, s, s))
        lo, hi = p.bounds()
        # the chin overhangs the sill's front edge a little: sink 1.2 cm so the cranium base rests on the sill
        p = p.transformed(t=(-(lo[0] + hi[0]) * 0.5, -PR_Y + depth - 1.0 - hi[1], zb + sill_h - 1.2 - lo[2]))
        if R is not None:
            p = p.transformed(R)
        asm.add_piece(p)
    build_crown(asm, rng, top_g, z1)
    return asm


def build_crown(asm, rng, top_g, z1):
    """The heaped crown (concept 1): a lumpy faceted bone mound (ridge 40 cm) on the top slab, painted as bone in
    shadow; an eave row of packed skulls on both long faces whose chins overhang the slab edge by ~4.5 cm, nodding
    down; a ridge row of skulls back to back along the top; long bones laid on the hips."""
    L, Wd, Hh, ridge = 84.0, 50.0, 34.0, 50.0
    pts = [(-L, -Wd, z1 - 0.5), (L, -Wd, z1 - 0.5), (L, Wd, z1 - 0.5), (-L, Wd, z1 - 0.5),
           (-ridge, 0.0, z1 + Hh), (ridge, 0.0, z1 + Hh)]
    v, f = bp.hull(np.array(pts), dissolve_deg=0.5)
    core_g = asm.add_vf(v, f, "EnvBone", "heapcore")
    lump_g = []
    # a heap, not a hip roof: chunky faceted lumps of compacted bone sunk into the wedge (each its own value), the
    # ridge rising to ~40 cm
    def wedge_z(x, y):
        hz = Hh * (1.0 - abs(y) / Wd)
        if abs(x) > ridge:
            hz = min(hz, Hh * (L - abs(x)) / (L - ridge))
        return z1 + max(hz, 0.0)
    for i in range(12):
        x = rng.uniform(-L * 0.8, L * 0.8)
        y = rng.uniform(-Wd * 0.75, Wd * 0.75)
        r = rng.uniform(11.0, 17.0)
        c = np.array([x, y, wedge_z(x, y) - r * 0.45])
        lp = bp._ico_pts(c, (r * rng.uniform(1.0, 1.5), r, r * rng.uniform(0.6, 0.8)), rng, jit=0.12)
        lp[:, 2] = np.maximum(lp[:, 2], z1 + 0.5)
        lv, lf = bp.hull(lp, dissolve_deg=0.5)
        lump_g.append(asm.add_vf(lv, lf, "EnvBone", "heapcore"))
    st = Stage((-PR_X - 6, -PR_Y - 10), (PR_X + 6, PR_Y + 10), cell=0.8)
    st.add_static([sh for sh, g in asm.shells if g in (top_g, core_g) or g in lump_g])
    crown = []
    edge = PR_Y + 4.0

    def slope_z(y_abs):
        return z1 + Hh * max(0.0, 1.0 - y_abs / Wd)
    eave = [(-66.0, 1.34), (-37.0, 1.36), (34.0, 1.33), (63.0, 1.36)]
    upper = [(-46.0, 22.0, 1.27), (-6.0, 23.0, 1.24), (38.0, 22.0, 1.26)]
    for face in (-1.0, 1.0):
        for x, sc_ in eave:
            pc = lib("P", seed=int(rng.integers(0, 3)))
            yaw = (0.0 if face < 0 else 180.0) + rng.uniform(-10.0, 10.0)
            R = bp.rot_z(yaw) @ bp.rot_x(rng.uniform(6.0, 10.0)) @ diag(sc_, sc_, sc_)     # nod down
            p = pc.transformed(R)
            lo, hi = p.bounds()
            y_front = face * (edge + 4.5)
            ty = y_front - (lo[1] if face < 0 else hi[1])
            p = p.transformed(t=(x + rng.uniform(-1.5, 1.5) - (lo[0] + hi[0]) * 0.5, ty, 0.0))
            # seat it on the slab: the part over the slab rests 0.4 cm into it, the chin hangs past the edge
            v = p.verts()
            over = v[np.abs(v[:, 1]) < edge - 0.5]
            p = p.transformed(t=(0.0, 0.0, z1 - 0.4 - float(over[:, 2].min())))
            crown.append(p)
        for x, dist, sc_ in upper:
            pc = lib("P", seed=int(rng.integers(0, 3)))
            yaw = (0.0 if face < 0 else 180.0) + rng.uniform(-14.0, 14.0)
            R = bp.rot_z(yaw) @ bp.rot_x(rng.uniform(-4.0, 4.0)) @ diag(sc_, sc_, sc_)
            p = pc.transformed(R)
            lo, hi = p.bounds()
            ty = face * dist - (lo[1] if face < 0 else hi[1])
            xo = 0.0 if face < 0 else 6.0               # the two ridge rows interleave back to back
            p = p.transformed(t=(x + xo + rng.uniform(-1.5, 1.5) - (lo[0] + hi[0]) * 0.5, ty, 0.0))
            p = drop_only(st, p.transformed(t=(0.0, 0.0, -p.bounds()[0][2])).rest(), np.eye(3),
                          (x + xo, ty + (lo[1] + hi[1]) * 0.5), sink=1.0)
            crown.append(p)
    for p in crown:
        st.add(p)
    # long bones along the ridge and across both slopes so the wedge top reads as bone from the galleries
    spots = [(-62.0, 0.0), (64.0, 0.0)]
    for i, (x, y) in enumerate(spots):
        kd = LONG_KINDS[i % 4]
        Lb = ext(lib(kd, "lite"))[0]
        R = bp.bone_pose(st.hf, (x, y), rng.uniform(-8, 8) + (180.0 if i % 2 else 0.0), Lb * 1.1,
                         (180.0 if rng.uniform() < 0.5 else 0.0) + rng.uniform(-20, 20), 20.0) @ diag(1.1, 1.1, 1.1)
        crown.append(place(st, lib(kd, "lite", seed=i), R, (x, y + rng.uniform(-2, 2)), sink=0.8))
    for p in crown:
        asm.add_piece(p)


def pier_extras(obj):
    sc.add_ucx(obj, bp.box_vf((0.0, 0.0, PR_TOPSLAB[1] * 0.5), (2 * PR_X, 2 * PR_Y, PR_TOPSLAB[1]))[0])


# ================================================================ mesh table
# name: (builder, tris category, pivot rule, (size x, y, z) or None, sockets, ucx?, surroundings env)
MESHES = {
    "Skull_A": (lambda: build_single("A", 3, open_deg=2.0), "scatter", "floor", (15, 20.5, 20), (), False, bp.ENV_NONE),
    "Skull_B": (lambda: build_single("B", 4), "scatter", "floor", (15, 20.5, 16.3), (), False, bp.ENV_NONE),
    "Skull_C": (lambda: build_single("C", 5), "scatter", "floor", (15, 20.5, 16.3), (), False, bp.ENV_NONE),
    "Jaw_A": (lambda: build_single("J", 1), "scatter", "floor", (11.2, 10, 4.4), (), False, bp.ENV_NONE),
    "Femur_A": (lambda: build_single("Femur", 0), "scatter", "long", (45, None, None), (), False, bp.ENV_NONE),
    "Femur_B": (lambda: build_single("FemurB", 0), "scatter", "long", (38, None, None), (), False, bp.ENV_NONE),
    "Humerus_A": (lambda: build_single("Humerus", 0), "scatter", "long", (32, None, None), (), False, bp.ENV_NONE),
    "Rib_A": (lambda: build_single("Rib", 0), "scatter", "long", None, (), False, bp.ENV_NONE),
    "BoneShards_A": (build_shards, "scatter", "long", None, (), False, bp.ENV_FLOOR),
    "SkullStack_A": (build_skull_stack, "cluster", "floor", (43, 38, None), (), False, bp.ENV_FLOOR),
    "BonePile_A": (build_pile_a, "cluster", "floor", (80, 80, None), (), False, bp.ENV_FLOOR),
    "BonePile_B": (build_pile_b, "cluster", "floor", (120, None, None), (), False, bp.ENV_FLOOR),
    "BoneScatter_A": (build_scatter_a, "cluster", "floor", (100, None, None), (), False, bp.ENV_FLOOR),
    "BoneScatter_B": (build_scatter_b, "cluster", "floor", (100, None, None), (), False, bp.ENV_FLOOR),
    "OssuaryFill_A": (lambda: build_fill("OssuaryFill_A"), "cluster", "wall", (100, 35, 45), (), False, bp.ENV_WALL),
    "OssuaryFill_B": (lambda: build_fill("OssuaryFill_B"), "cluster", "wall", (134, 35, 45), (), False, bp.ENV_WALL),
    "OssuaryFill_B2": (lambda: build_fill("OssuaryFill_B2"), "cluster", "wall", (134, 35, 45), (), False, bp.ENV_WALL),
    "OssuaryFill_Niche": (lambda: build_fill("OssuaryFill_Niche"), "cluster", "wall", (75, 25, 50), (), False,
                          bp.ENV_WALL),
    "OssuaryShelf_A": (build_shelf, "furniture", "wall", (200, 70, 260), ("Bay_11", "Bay_21", "Bay_31", "Bay_41"),
                       True, bp.ENV_WALL),
    "OssuaryPier_A": (build_pier, "furniture", "floor", (220, 140, 295), (), True, bp.ENV_FLOOR),
}
EXTRAS = {"OssuaryShelf_A": shelf_extras, "OssuaryPier_A": pier_extras}
SINGLE = {"Skull_A", "Skull_B", "Skull_C", "Jaw_A", "Femur_A", "Femur_B", "Humerus_A", "Rib_A"}
CONTACT = {"SkullStack_A", "BonePile_A", "BonePile_B", "BoneScatter_A", "BoneScatter_B", "BoneShards_A",
           "OssuaryFill_A", "OssuaryFill_B", "OssuaryFill_B2", "OssuaryFill_Niche", "OssuaryPier_A"}
HEAPS = {"SkullStack_A", "BonePile_A", "BonePile_B", "BoneScatter_A", "BoneScatter_B"}
FILLS = {"OssuaryFill_A", "OssuaryFill_B", "OssuaryFill_B2", "OssuaryFill_Niche"}
NOTES = {
    "OssuaryFill_A": "the 100 W packed fill for kit wall bays and 100 cm niches (back at y = 0, pivot at the bottom "
                     "centre of the back edge); it does not fill an OssuaryShelf_A bay (use OssuaryFill_B / B2)",
    "OssuaryFill_B": "the OssuaryShelf_A bay fill (134 W x 45 H x 35 D): snap its pivot to SOCKET_Bay_<row>1, its "
                     "front lands 2 cm behind the slab lip; alternate with OssuaryFill_B2 so stacked bays differ",
    "OssuaryFill_B2": "second seed of OssuaryFill_B (same size and pivot): alternate with it on SOCKET_Bay_<row>1",
    "OssuaryFill_Niche": "fills a CryptWallOssuary4m_Mars_SM niche (75 W x 50 H x 25 D)",
    "OssuaryShelf_A": "bay clear 136 W x 49 H x 63 D (bay back y = -8 to the slab lip y = -71); SOCKET_Bay_<row>1 sits "
                      "on the bay floor at y = -33.6 (a 35 D fill's front 2 cm behind the lip), turned with its "
                      "slab (+-0.6 deg about Y)",
}


# ================================================================ build + check
MIN_FACE_AREA = 2e-3     # cm^2


def planarize(asm, cos_tol=0.99995):
    """Split every polygon whose fan triangles do not share one normal (a jittered quad, a warped n-gon) into those
    triangles: Unreal and the reimport check read flat shading from per-corner normals, which a warped polygon breaks.
    The triangle count does not change."""
    out = []
    split = dropped = 0
    for sh, g in asm.shells:
        F, T = [], []
        for f, t in zip(sh.f, sh.tags):
            if len(f) > 3:
                P = sh.v[f]
                n = bp.newell(P)
                tris = [(f[0], f[i], f[i + 1]) for i in range(1, len(f) - 1)]
                ok = True
                for a, b_, c in tris:
                    tn = np.cross(sh.v[b_] - sh.v[a], sh.v[c] - sh.v[a])
                    ln = np.linalg.norm(tn)
                    if ln > 1e-9 and float(np.dot(tn / ln, n)) < cos_tol:
                        ok = False
                        break
                if not ok:
                    F.extend([list(x) for x in tris])
                    T.extend([t] * len(tris))
                    split += 1
                    continue
            F.append(list(f))
            T.append(t)
        # drop zero-area slivers (collinear corners from clipping / fans): no visible surface, but their normal is
        # undefined, so the FBX re-import (and Unreal) reads them as a non-flat corner
        keep = [i for i, f in enumerate(F) if bp.polygon_area(sh.v[list(f)]) >= MIN_FACE_AREA]
        dropped += len(F) - len(keep)
        F = [F[i] for i in keep]
        T = [T[i] for i in keep]
        out.append((bp.Shell(sh.v, F, T, sh.slot, sh.kind), g))
    asm.shells = out
    if dropped:
        print("  planarize: dropped %d zero-area slivers" % dropped)
    return split


def make(name):
    builder, cat, rule, dims, sockets, want_ucx, env = MESHES[name]
    HEAP_STATS.clear()
    asm = builder()
    front = HEAP_STATS.get("front")
    if rule == "wall":
        lo, hi = asm_bounds(asm)
        shift_asm(asm, (-(lo[0] + hi[0]) * 0.5, 0.0, 0.0))
    multi = name not in SINGLE
    if multi:
        planarize(asm)          # split warped polygons first: the z-fight test must see the final triangle planes
        fix_zfight(asm, rounds=20)
        # the z-fight pushes can move a piece past the pivot planes: re-rest
        lo, hi = asm_bounds(asm)
        if rule == "wall":
            shift_asm(asm, (-(lo[0] + hi[0]) * 0.5, -hi[1], -lo[2]))
        else:
            rest_floor(asm)
        if name in FILLS and dims and asm_bounds(asm)[1][2] > dims[2]:
            # the pushes lifted a top bone past the fill height: squeeze back to the spec (the bay is 49 clear)
            k = dims[2] * 0.995 / asm_bounds(asm)[1][2]
            asm.shells = [(sh.transformed(diag(1.0, 1.0, k)), g) for sh, g in asm.shells]
            fix_zfight(asm, rounds=8)
            lo, hi = asm_bounds(asm)
            shift_asm(asm, (-(lo[0] + hi[0]) * 0.5, -hi[1], -lo[2]))
        env = BoxEnv(env, *asm_bounds(asm))
    roots = bp.root_floor if rule != "wall" else bp.root_floor_or_wall
    floating = bp.contact_report(asm, roots) if multi else []
    for i, g, t in floating[:3]:
        lo_, hi_ = asm.shells[i][0].v.min(axis=0), asm.shells[i][0].v.max(axis=0)
        print("  floating shell %d group %d tag %s bounds %s %s" % (i, g, t, lo_.round(1), hi_.round(1)))
    pre = asm.tris
    if multi:
        meta_restored = cull_repair(asm, env)
    planarize(asm)
    obj, tags, group, shell = asm.build(name + "_Mars_SM")
    seed = zlib.crc32(name.encode()) % 997 + 3
    paint_obj(obj, tags, group, seed, env=env if multi else None, ao_radius=14.0 if multi else 6.0,
              contact=name in CONTACT, floor_band=name in CONTACT and rule == "floor",
              cavity_darken=0.45 if name in HEAPS else 0.32)
    if name in EXTRAS:
        EXTRAS[name](obj)
    return obj, {"tags": tags, "group": group, "floating": floating, "pre_tris": pre, "env": env,
                 "restored": meta_restored if multi else 0, "front": front}


def check_mesh(name, obj, meta, fails, infos):
    _, cat, rule, dims, sockets, want_ucx, env = MESHES[name]
    probs = []
    mesh = obj.data
    tris = fc.tri_count(obj)
    budget = spec.TRIS[cat]
    if tris > budget:
        probs.append("tris %d > %s budget %d" % (tris, cat, budget))
    slots = [m.name for m in mesh.materials]
    for s in slots:
        if s not in spec.SLOTS:
            probs.append("slot %s not in env_spec" % s)
    used = {int(p.material_index) for p in mesh.polygons}
    if len(used) != len(slots):
        probs.append("unused slots")
    if spec.DATA_UV not in mesh.uv_layers or "UVMap" not in mesh.uv_layers or mesh.uv_layers[0].name != "UVMap":
        probs.append("uv layers %s" % [u.name for u in mesh.uv_layers])
    col = mesh.color_attributes.get("Col")
    if col is None or col.domain != "CORNER":
        probs.append("no Col corner colours")
    else:
        a = np.empty(len(mesh.loops) * 4)
        col.data.foreach_get("color", a)
        a = a.reshape(-1, 4)
        if a[:, 3].min() < 0.0 or a[:, 3].max() > 1.0 or a[:, 3].std() < 0.01:
            probs.append("cavity alpha flat or out of range")
        # the dark cuts (orbits, nose, tooth gaps) must carry A = 0
        for p, t in zip(mesh.polygons, meta["tags"]):
            if t in ("socket", "nasal", "toothgap") and a[p.loop_start:p.loop_start + p.loop_total, 3].max() > 0.01:
                probs.append("a %s face is not painted A = 0" % t)
                break
    if any(p.use_smooth for p in mesh.polygons):
        probs.append("smooth faces")
    lo, hi = fc.bounds_cm(obj)
    size = hi - lo
    if abs(lo[2]) > 0.01:
        probs.append("min z %.3f != 0" % lo[2])
    c = 0.5 * (lo + hi)
    if rule in ("floor", "long"):
        if abs(c[0]) > 0.05 or abs(c[1]) > 0.05:
            probs.append("footprint not centred (%.2f, %.2f)" % (c[0], c[1]))
        if rule == "long" and not (size[0] >= size[1] and size[0] >= size[2]):
            probs.append("not along +X %s" % size.round(1))
    else:
        if abs(hi[1]) > 0.01:
            probs.append("back plane max y %.3f != 0" % hi[1])
        if abs(c[0]) > 0.05:
            probs.append("not centred in x (%.2f)" % c[0])
    if dims:
        for ax, want in enumerate(dims):
            tol = 0.15 if (cat == "cluster" and rule == "floor") else 0.06      # heaps are "~" sizes
            if want is not None and abs(size[ax] - want) > tol * want + 0.6:
                probs.append("size %s %.1f (want %.0f)" % ("xyz"[ax], size[ax], want))
    if meta["floating"]:
        probs.append("floating parts %s" % meta["floating"][:5])
    zf = bp.zfight_report(obj, np.asarray(meta["group"]))
    if zf:
        C = fc.face_centers_cm(obj)
        probs.append("%d coplanar overlaps between parts, e.g. %s" % (
            len(zf), [(meta["tags"][a], meta["tags"][b], d, C[a].round(1).tolist()) for a, b, d in zf[:3]]))
    hits, back, ex = bp.seal_report(obj, env=meta.get("env", env), n=2500)
    if hits == 0 or back > max(2, 0.002 * hits):
        probs.append("seal: %d of %d outside rays hit a back face %s" % (back, hits, ex[:3]))
    have = sorted(e.name[len("SOCKET_"):] for e in sc.children(obj, "SOCKET_"))
    for s in sockets:
        if s not in have:
            probs.append("missing SOCKET_%s" % s)
    ucx = sc.children(obj, "UCX_")
    if want_ucx and not ucx:
        probs.append("no UCX")
    if not want_ucx and ucx:
        probs.append("UCX where ENV_KIT asks none")
    probs += sc.check_ucx(obj)
    by = {}
    for t, poly in zip(meta["tags"], mesh.polygons):
        k = "stone" if is_stone_tag(t) else ("skull" if t in SKULL_TAGS else "bones")
        by[k] = by.get(k, 0) + len(poly.vertices) - 2
    print("  tris by kind", by)
    if cat in ("furniture", "cluster"):
        th = {}
        for t, poly in zip(meta["tags"], mesh.polygons):
            th[t] = th.get(t, 0) + len(poly.vertices) - 2
        print("  tris by tag", dict(sorted(th.items(), key=lambda kv: -kv[1])))
    if meta.get("front") is not None and meta["front"] < 0.6:
        probs.append("only %.0f %% of the skulls face -y" % (100 * meta["front"]))
    infos[name] = {"tris": tris, "budget": budget, "cat": cat, "size_cm": [round(float(x), 1) for x in size],
                   "slots": slots, "sockets": have, "ucx": len(ucx), "pre": meta["pre_tris"], "seal": (back, hits),
                   "zfight": len(zf)}
    print("CHECK %-18s tris %5d (pre-cull %5d) / %-5d size %s slots %s sockets %s ucx %d seal %d/%d %s" % (
        name, tris, meta["pre_tris"], budget, infos[name]["size_cm"], slots, have, len(ucx), back, hits,
        "ok" if not probs else "FAIL " + "; ".join(probs)))
    for p in probs:
        fails.append("%s: %s" % (name, p))


def check_library(fails):
    """The part contract: every shell closed; packed skull ~80 tris, its front LOD ~60, the loose cut cranium
    120-220, the long bones' shafts >= 4.5 cm."""
    for v in range(3):
        for kind, lo_t, hi_t in (("P", 60, 90), ("PF", 40, 72)):
            p = lib(kind, seed=v)
            oe = sum(bp.open_edges(sh.f) for sh in p.shells)
            if oe or not lo_t <= p.tris <= hi_t:
                fails.append("%s skull variant %d: %d tris, %d open edges" % (kind, v, p.tris, oe))
            print("CHECK %s skull v%d tris %d open edges %d size %s" % (kind, v, p.tris, oe, ext(p).round(1)))
        for kind in ("B", "C"):
            for lod in ("full", "mid"):
                p = bp.make_cut_skull(kind, v, lod=lod)
                cran = p.shells[0]
                oe = sum(bp.open_edges(sh.f) for sh in p.shells)
                if oe or not 120 <= cran.tris <= 220:
                    fails.append("cut skull %s v%d %s: cranium %d tris, %d open edges" % (kind, v, lod, cran.tris, oe))
                if v == 0:
                    print("CHECK cut skull %s %s cranium tris %d (all %d) open edges %d" % (kind, lod, cran.tris,
                                                                                          p.tris, oe))
    for kd in LONG_KINDS:
        for lod in ("full", "lite"):
            p = bp.make_cut_long_bone(kd, lod)
            oe = sum(bp.open_edges(sh.f) for sh in p.shells)
            shaft = p.shells[0].v
            mid = shaft[np.abs(shaft[:, 0] - np.median(shaft[:, 0])) < 6.0]
            dia = 2.0 * float(np.max(np.linalg.norm(mid[:, 1:] - mid[:, 1:].mean(axis=0), axis=1))) if len(mid) else 0.0
            if oe or dia < 4.4:
                fails.append("cut %s %s: %d open edges, shaft %.1f cm" % (kd, lod, oe, dia))
            print("CHECK cut %s %s tris %d shaft %.1f cm open %d" % (kd, lod, p.tris, dia, oe))


def reimport(paths, fails):
    for path in paths:
        before = set(bpy.data.objects)
        rep = fc.reimport_check(path)
        for o in [o for o in bpy.data.objects if o not in before]:
            bpy.data.objects.remove(o, do_unlink=True)
        name = os.path.splitext(os.path.basename(path))[0]
        main = [r for r in rep if not r["name"].startswith("UCX_")]
        probs = []
        if len(main) != 1:
            probs.append("meshes %s" % [r["name"] for r in main])
        else:
            r = main[0]
            if r["uv_layers"][:2] != ["UVMap", spec.DATA_UV]:
                probs.append("uv %s" % r["uv_layers"])
            if "Col" not in r["colors"]:
                probs.append("colors %s" % r["colors"])
            if not r["flat"]:
                probs.append("not flat")
        print("REIMPORT %s %s" % (name, "ok" if not probs else "FAIL " + "; ".join(probs)))
        for p in probs:
            fails.append("%s reimport: %s" % (name, p))


# ================================================================ review sheets
def out(stem):
    return os.path.join(spec.REVIEW_DIR, stem)


def row_sheet(objs, stem, views, size=(1800, 800), gap=None):
    cps = bp.lineup(objs, gap_cm=gap)
    try:
        paths = [bp.render_view(cps, out("%s_%s.png" % (stem, k)), v, size=size) for k, v in views]
    finally:
        for c in cps:
            bp.remove_object(c)
    return bp.sheet(paths, out(stem + "_sheet.png"), 1)


def chef_proxy(x, y=0.0):
    """A 1.5 m scale stand-in for the player chef (40 x 25 x 150 cm)."""
    return bp.painted_box("_ChefProxy", (x, y, 75.0), (40.0, 25.0, 150.0), fc.srgb(70, 110, 150))


def packed_preview():
    """The three packed skull variants and a bone end as painted objects (review only)."""
    objs = []
    for v, kind in ((0, "P"), (1, "P"), (2, "P"), (0, "PF"), (1, "PJ")):
        asm = bp.Asm(("EnvBone",))
        asm.add_piece(lib(kind, seed=v))
        obj, tags, group, shell = asm.build("_Packed%s%d" % (kind, v))
        paint_obj(obj, tags, group, 7 + v, ao_radius=6.0)
        objs.append(obj)
    asm = bp.Asm(("EnvBone",))
    asm.add_piece(bp.make_bone_end(np.random.default_rng(4)).rest())
    obj, tags, group, shell = asm.build("_BoneEnd")
    paint_obj(obj, tags, group, 3, ao_radius=6.0)
    objs.append(obj)
    return objs


def render_sheets(built):
    sheets = []
    B = {n: o for n, (o, m) in built.items()}

    def have(*names):
        return all(n in B for n in names)

    if have("Skull_A", "Skull_B", "Skull_C", "Jaw_A"):
        objs = [B[n] for n in ("Skull_A", "Skull_B", "Skull_C", "Jaw_A")]
        sheets.append(ec.review(objs, "bones_skulls"))
        sheets.append(row_sheet(objs, "bones_skulls_close",
                                (("front", (0.0, -1.0, 0.08)), ("iso", (0.9, -1.3, 0.55)), ("side", (1.0, -0.05, 0.1)),
                                 ("low", (-0.5, -1.0, -0.05)), ("top", (0.15, -0.5, 1.0))), size=(1800, 700), gap=6.0))
        # the 5-10 m read: the loose skulls and a pile seen from the chef's eye (1.35 m) 6 m away
        if "BonePile_A" in B:
            cps = bp.lineup(objs[:3] + [B["BonePile_A"]], gap_cm=25.0)
            try:
                p1 = bp.render_view(cps, out("bones_distance_6m.png"), None, size=(1600, 700),
                                    eye_cm=(0.0, -600.0, 135.0), target_cm=(0.0, 0.0, 15.0), lens=50.0)
                p2 = bp.render_view(cps, out("bones_distance_10m.png"), None, size=(1600, 700),
                                    eye_cm=(150.0, -1000.0, 135.0), target_cm=(0.0, 0.0, 15.0), lens=70.0)
                sheets.append(bp.sheet([p1, p2], out("bones_distance_sheet.png"), 1))
            finally:
                for c in cps:
                    bp.remove_object(c)
    if any(n.startswith("Ossuary") for n in B):
        pk = packed_preview()
        try:
            sheets.append(row_sheet(pk, "bones_packed_close", (("front", (0.0, -1.0, 0.06)), ("iso", (0.8, -1.1, 0.5)),
                                                               ("side", (1.0, -0.1, 0.1))), size=(1800, 600), gap=5.0))
        finally:
            for o in pk:
                bp.remove_object(o)
    longs = [n for n in ("Femur_A", "Femur_B", "Humerus_A", "Rib_A", "BoneShards_A") if n in B]
    if longs:
        sheets.append(row_sheet([B[n] for n in longs], "bones_long",
                                (("iso", (0.5, -1.0, 0.9)), ("top", (0.0, -0.01, 1.0)), ("front", (0.0, -1.0, 0.1))),
                                size=(1800, 600), gap=8.0))
    heaps = [n for n in ("SkullStack_A", "BonePile_A", "BonePile_B", "BoneScatter_A", "BoneScatter_B") if n in B]
    if heaps:
        sheets.append(row_sheet([B[n] for n in heaps], "bones_piles",
                                (("iso", (1.0, -1.2, 0.8)), ("front", (0.0, -1.0, 0.15)), ("top", (0.0, -0.01, 1.0))),
                                size=(2000, 700), gap=15.0))
        for n in heaps:
            sheets.append(row_sheet([B[n]], "bones_%s_close" % n.lower(),
                                    (("iso", (1.0, -1.3, 0.75)), ("low", (-0.6, -1.0, 0.25))), size=(1400, 800)))
    fills = [n for n in ("OssuaryFill_A", "OssuaryFill_B", "OssuaryFill_B2", "OssuaryFill_Niche") if n in B]
    if fills:
        sheets.append(row_sheet([B[n] for n in fills], "bones_fills",
                                (("front", (0.0, -1.0, 0.12)), ("iso", (0.8, -1.2, 0.6)), ("top", (0.0, -0.4, 1.0))),
                                size=(2000, 700), gap=20.0))
    if "OssuaryShelf_A" in B:
        sh = B["OssuaryShelf_A"]
        sheets.append(row_sheet([sh], "bones_shelf",
                                (("front", (0.0, -1.0, 0.05)), ("iso", (1.0, -1.1, 0.45)), ("side", (1.0, 0.0, 0.1))),
                                size=(1500, 1300)))
        extra = []
        alt = [B.get("OssuaryFill_B"), B.get("OssuaryFill_B2")]
        alt = [f for f in alt if f is not None] or [B.get("OssuaryFill_A")]
        if alt[0] is not None:
            for i, e in enumerate(sorted(sc.children(sh, "SOCKET_"), key=lambda o: o.name)):
                R = bp.rot_y(math.degrees(e.rotation_euler[1]))
                extra.append(bp.copy_object(alt[i % len(alt)], offset=np.asarray(e.location) * 100.0, R=R,
                                            name="_Dress_" + e.name))
        cp = bp.copy_object(sh, name="_DressShelf")
        chef = chef_proxy(150.0, -95.0)
        objs = [cp, chef] + extra
        try:
            p1 = bp.render_view(objs, out("bones_shelf_dressed_front.png"), (0.0, -1.0, 0.05), size=(1600, 1200))
            p2 = bp.render_view(objs, out("bones_shelf_dressed_eye.png"), None, size=(1600, 1200),
                                eye_cm=(140.0, -330.0, 150.0), target_cm=(0.0, -30.0, 120.0), lens=28.0)
            p3 = bp.render_view(objs, out("bones_shelf_dressed_low.png"), None, size=(1600, 1200),
                                eye_cm=(-60.0, -260.0, 150.0), target_cm=(0.0, -40.0, 40.0), lens=28.0)
            p4 = bp.render_view(objs, out("bones_shelf_dressed_side.png"), (1.0, -0.25, 0.1), size=(1600, 1200))
            sheets.append(bp.sheet([p1, p2, p3, p4], out("bones_shelf_dressed_sheet.png"), 2))
        finally:
            for o in objs:
                bp.remove_object(o)
    if "OssuaryPier_A" in B:
        pr = B["OssuaryPier_A"]
        sheets.append(row_sheet([pr], "bones_pier",
                                (("iso", (1.0, -1.1, 0.55)), ("front", (0.0, -1.0, 0.05)), ("end", (1.0, 0.0, 0.08)),
                                 ("top", (0.0, -0.01, 1.0))), size=(1600, 1300)))
        cp = bp.copy_object(pr, name="_PierCopy")
        chef = chef_proxy(170.0, -110.0)
        try:
            p1 = bp.render_view([cp, chef], out("bones_pier_eye.png"), None, size=(1600, 1200),
                                eye_cm=(260.0, -420.0, 150.0), target_cm=(0.0, 0.0, 140.0), lens=28.0)
            p2 = bp.render_view([cp], out("bones_pier_bay.png"), None, size=(1600, 1200),
                                eye_cm=(-30.0, -200.0, 125.0), target_cm=(-45.0, -55.0, 120.0), lens=35.0)
            sheets.append(bp.sheet([p1, p2], out("bones_pier_close_sheet.png"), 2))
            p3 = bp.render_view([cp], out("bones_pier_endview.png"), None, size=(1600, 1200),
                                eye_cm=(420.0, -120.0, 150.0), target_cm=(110.0, 0.0, 130.0), lens=35.0)
            p4 = bp.render_view([cp], out("bones_pier_crown.png"), None, size=(1600, 1200),
                                eye_cm=(120.0, -260.0, 240.0), target_cm=(0.0, -20.0, 255.0), lens=35.0)
            p5 = bp.render_view([cp], out("bones_pier_gallery.png"), None, size=(1600, 1200),
                                eye_cm=(-250.0, -380.0, 560.0), target_cm=(0.0, 0.0, 200.0), lens=35.0)
            p6 = bp.render_view([cp], out("bones_pier_crown_top.png"), (0.0, -0.01, 1.0), size=(1600, 1200),
                                target_cm=(0.0, 0.0, 260.0), half_cm=130.0)
            sheets.append(bp.sheet([p3, p4, p5, p6], out("bones_pier_end_crown_sheet.png"), 2))
        finally:
            bp.remove_object(cp)
            bp.remove_object(chef)
    return sheets


# ================================================================ main
def main():
    args = fc.cli_args({"export": False, "save": False, "sheets": False, "only": ""})
    t0 = time.time()
    fc.ensure_dirs()
    fc.clear_scene()
    bpy.context.scene.view_settings.view_transform = "Standard"
    fails, infos, built = [], {}, {}
    only = args["only"] if isinstance(args["only"], str) else ""
    check_library(fails)
    for name in MESHES:
        if only and not any(o.lower() in name.lower() for o in only.split(",")):
            continue
        t1 = time.time()
        obj, meta = make(name)
        built[name] = (obj, meta)
        check_mesh(name, obj, meta, fails, infos)
        print("  built %s in %.1fs" % (name, time.time() - t1))
    paths = []
    if args["export"]:
        for name, (obj, meta) in built.items():
            extra = {"pivot": MESHES[name][2], "tris_category": MESHES[name][1],
                     "zfight_overlaps": infos.get(name, {}).get("zfight")}
            if name in NOTES:
                extra["fits"] = NOTES[name]
            paths.append(ec.export(obj, FAMILY, extra=extra))
        reimport(paths, fails)
    sheets = []
    if args["sheets"]:
        sheets = render_sheets(built)
    if args["save"]:
        ec.save_family_blend(FAMILY)
        print("saved", os.path.join(spec.BLEND_DIR, spec.FAMILIES[FAMILY][1]))
    print("\nTABLE")
    for name, i in infos.items():
        print("  %-18s tris %5d / %-5d (%s)  size %s  slots %s  sockets %s  ucx %d" % (
            name, i["tris"], i["budget"], i["cat"], i["size_cm"], i["slots"], i["sockets"], i["ucx"]))
    print("\nsheets:", *sheets, sep="\n  ")
    print("total %.1fs" % (time.time() - t0))
    if fails:
        print("ENV_BONES_FAIL", *fails, sep="\n  ")
    else:
        print("ENV_BONES_OK")


main()
