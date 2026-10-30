"""Mars environment dressing kit, family "pipes" (ENV_KIT.md, env_spec.FAMILIES["pipes"]): the rusty sewer pipe set of
concept 2 and the iron gate of concept 5, rebuilt from fixed seeds by headless Blender 5.2.

  chain pieces (pipe radius 22 cm, 16-sided rings, vertex 0 on local +Y; pivot = the inlet at the start of the axis,
  the run enters along +X; every port ring is exact so pieces snap seamlessly; any piece may roll about its local X in
  22.5 deg steps without opening the seam)
    Pipe_50cm / _1m / _2m / _4m   heavy riveted lap bands (11 wide, 3.5 proud) every metre (at 50, 150, ...; the
                                  50 cm make-up at 25), a riveted seam strip on the top-back facet, dents, jitter
    PipeElbow90                   lobster-back elbow, 4 welded gores, in +X at the origin, out +Z at (50, 0, 50)
    PipeElbow45                   2 welded gores, out along (1, 0, 1)/sqrt2
    PipeTee                       straight r 25 drum + r 25 branch saddle, run 0..100 along +X, branch +Z at (50, 0, 50)
    ValveGate_A                   hard-stepped cast gate valve, 50 cm inline, baked bolted port joints (no PipeFlange at
                                  its ports); 8-sided drum, stout bonnet, gland and brass stem toward -Y (the room side
                                  of a pipe on a wall), SOCKET_Wheel on the stem 49 cm off the axis (socket +X = -Y, the spin axis)
    PipeCap / PipeSpout_A         run ends: a complete bolted blind joint (no PipeFlange at it); a broken open end, top
                                  torn back, lip drooping into a pour tongue with SOCKET_Drip
  overlays (advance 0: place at any port frame, the pipe passes through)
    PipeFlange                    a bolted flange pair centred on the joint plane x = 0
    PipeCollar                    a wall / floor plate (plate in the YZ plane, back sunk 1.5 cm behind x = 0, the pipe
                                  leaves along +X); end a run into a wall or floor by turning it 180 deg about local Z
  others
    PipeBracket                   wall strap, back at y = 0, holds the pipe axis at (0, -32, 0) parallel to the wall
    ValveWheel_A                  the 8-spoke wheel, diameter 90, hub pivot, spins about X
    DrainGrate_A                  1 x 0.5 m floor grate; frame 1.5 cm proud, chamfered over 6 cm to z 0, dark sump
    WallGrate_A                   1.2 x 0.9 m arched culvert grate, back at y = 0, dark void plate behind the bars
    StoneBasin_A                  ashlar trough ~1.95 x 1.0 x 0.6 m (plinth, two pillowed courses, coping with a pour
                                  notch at x 34 on the back), SOCKET_Water at the water line (z 47)
    Portcullis_A / _B             iron leaf 240 W x 300 H (square head) / 330 at the crown (the kit portal's segmental
                                  arch); spike tips at z = 0, leaf mid-plane y = 0

Every sidecar carries extra["connect"] (Unreal local cm and FRotator pitch / yaw / roll): the port frames a next piece's
pivot snaps to (next.transform = this.transform * port), overlay / mount rules, the wall offset, the water line, the
opening. Pipes_Connect.json (export folder, not a mesh sidecar) holds all ports plus the review chain's transforms.

Run (always absolute paths):
  "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup --python
      D:\\Repo\\Mars\\Tools\\Blender\\mars_environment\\build_env_pipes.py -- [--export] [--sheets] [--save] [--only <part>]
Prints ENV_PIPES_OK (or ENV_PIPES_FAIL and the reasons; ENV_PIPES_PARTIAL with --only).
"""
import json
import math
import os
import sys
import time

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import env_common as ec          # noqa: E402
import env_pipes_parts as pp     # noqa: E402

fc, sc, spec = ec.fc, ec.sc, ec.spec
X, Y, Z = pp.X, pp.Y, pp.Z
I3 = np.eye(3)
FAMILY = "pipes"

R = 22.0                       # pipe outer radius (ENV_KIT)
SIDES = 16                     # pipe ring sides; vertex 0 on local +Y, vertex 4 on +Z
NECK = 14.0                    # plain neck at every fitting port (a flange overlay spans +-6.5)
BEND_R = 36.0                  # elbow centreline radius -> PipeElbow90 out at (50, 0, 50)
BEAD = 3.5                     # weld bead half width at a gore joint (tapered on the bend's inner side)
BEAD_TOP = 1.0                 # half width of the bead's flat top band
BEAD_H = 1.8                   # bead height proud of the pipe
VALVE_L = 50.0
WALL_OFFSET = 32.0             # PipeBracket: pipe axis to wall
WHEEL_DEPTH = 49.0             # ValveGate_A: SOCKET_Wheel distance from the pipe axis toward -Y (about one pipe
                               # diameter in front of the pipe, clear of the 33 cm flanges)
SLOT_ORDER = ("EnvRust", "EnvIron", "EnvBrass", "EnvStone", "EnvStoneDark")
UCX_NOTE = ("ENV_KIT names no collision for the pipes family; UCX is given to the pieces a player must not walk "
            "through (runs, fittings, valve, wheel, basin, portcullis) and left off the flush / overlay pieces")


def P(name):
    return ec.palette(name)


# ================================================================ shared bits
def pipe_ring(x, radius=R, jitter=0.0, rng=None, dent=None, keep=()):
    """Canonical 16-sided ring at x. jitter moves every vertex radially except `keep`; dent = (k0, depth) pushes
    vertex k0 in by depth and its two neighbours by 0.6 depth."""
    r = np.full(SIDES, float(radius))
    if jitter:
        r += rng.uniform(-jitter, jitter, SIDES)
        for k in keep:
            r[k % SIDES] = radius
    if dent is not None:
        k0, depth = dent
        r[k0 % SIDES] -= depth
        r[(k0 - 1) % SIDES] -= depth * 0.6
        r[(k0 + 1) % SIDES] -= depth * 0.6
    return pp.ring_points((x, 0.0, 0.0), X, Y, r, SIDES)


BAND_HW = 5.5                  # lap band half width (11 cm band)
BAND_R = 25.5                  # lap band outer radius (3.5 cm proud)
SEAM_K = (2, 3)                # the seam strip sits on the facet between ring vertices 2 and 3 (top-back, 56.25 deg)
SEAM_PITCH = 27.0              # seam rivet spacing (cm): big, readable rivets, not noise
DENT_K = (0, 7, 8, 9, 15)      # dents only on side vertices: the top (4) and bottom (12) silhouettes stay straight


def lap_band(parts, origin, axis, rng, rivets=8, ref=Y, r_in=20.6, r_out=BAND_R, hw=BAND_HW):
    """A heavy riveted lap band round the pipe (11 wide, 3.5 cm proud, 1.2 cm chamfers) at origin, about axis."""
    BAND_R_ = r_out
    prof = [(r_in, -hw), (BAND_R_ - 1.2, -hw), (BAND_R_, -hw + 1.2), (BAND_R_, hw - 1.2),
            (BAND_R_ - 1.2, hw), (r_in, hw)]
    tags = []
    for t in ("rust_band", "rust_edge", "rust_band", "rust_edge", "rust_band", "rust_band"):
        tags += [t] * SIDES
    parts.add(pp.revolve(prof, SIDES, origin=origin, axis=axis, ref=ref, closed=True, jitter=0.15, rng=rng),
              "EnvRust", tags)
    face_r = BAND_R_ * math.cos(math.pi / SIDES)
    ax = pp._n(axis)
    u = pp._n(np.asarray(ref, float) - np.dot(ref, ax) * ax)
    w = np.cross(ax, u)
    for k in range(rivets):
        a = math.radians((k + 0.25) * 360.0 / rivets)          # face centres of the 16-sided band
        d = math.cos(a) * u + math.sin(a) * w
        parts.add(pp.rivet(np.asarray(origin, float) + d * face_r, d, 2.2, 1.8, rng), "EnvRust", "rivet")


def seam_strip(parts, x0, x1, rng, skip=()):
    """A longitudinal seam plate (4 wide, 0.8 proud) on the top-back facet (ring vertices 2..3) from x0 to x1, with a
    rivet row every ~SEAM_PITCH cm that skips the x spans in `skip` (under the lap bands)."""
    a = math.radians(22.5 * (SEAM_K[0] + 0.5))
    d = math.cos(a) * Y + math.sin(a) * Z
    g = -math.sin(a) * Y + math.cos(a) * Z
    ap = R * math.cos(math.pi / SIDES)
    Rf = np.column_stack([X, g, d])
    parts.add(pp.obox(0.5 * (x0 + x1) * X + d * (ap + 0.2), (x1 - x0, 4.0, 1.2), Rf), "EnvRust", "rust_edge")
    n = max(1, int((x1 - x0 - 6.0) // SEAM_PITCH))
    for i in range(n + 1):
        x = x0 + 3.0 + (x1 - x0 - 6.0) * i / max(n, 1) + rng.uniform(-0.6, 0.6)
        if any(lo - 2.5 <= x <= hi + 2.5 for lo, hi in skip):
            continue
        parts.add(pp.rivet(x * X + d * (ap + 0.8), d, 1.0, 0.8, rng), "EnvRust", "rivet")


def flange_bolts(parts, x_face, radius, count, rng, phase_deg=22.5, normal=X, rc=2.5, h=2.3, stud=False):
    for k in range(count):
        a = math.radians(phase_deg + 360.0 * k / count)
        c = np.array([x_face, radius * math.cos(a), radius * math.sin(a)])
        parts.add(pp.head(c, normal, rc, h, rng=rng), "EnvIron", "bolt")
        if stud:
            o = c + np.asarray(normal, float) * (h - 0.2)
            prof = [(0.0, -0.3), (1.1, -0.3), (1.1, 1.5), (0.75, 2.0), (0.0, 2.0)]
            parts.add(pp.revolve(prof, 6, origin=o, axis=normal), "EnvIron", "bolt")


def hull_ring(center, t, radius, sides=12, u=Y):
    return pp.ring_points(center, t, u, radius, sides)


def loft_closed(rings):
    """Quads between consecutive rings and from the last back to the first (a closed profile swept round a loop)."""
    k = len(rings[0])
    verts = np.concatenate([np.asarray(r, float) for r in rings])
    faces = []
    m = len(rings)
    for i in range(m):
        a, b = i * k, ((i + 1) % m) * k
        for s in range(k):
            s2 = (s + 1) % k
            faces.append([a + s, a + s2, b + s2, b + s])
    return verts, faces


def port(loc, R3):
    return (np.asarray(loc, float), np.asarray(R3, float))


# ================================================================ chain pieces
def pipe_name(length):
    return ("Pipe_%dm" % int(round(length / 100.0))) if length >= 100.0 else ("Pipe_%dcm" % int(round(length)))


def build_pipe(length, seed):
    rng = np.random.default_rng(seed)
    name = pipe_name(length) + "_Mars_SM"
    parts = pp.Parts(name, SLOT_ORDER)
    if length >= 100.0:
        bands = [50.0 + 100.0 * i for i in range(int(round(length / 100.0)))]
    else:
        bands = [0.5 * length]
    fixed = {0.0, 9.0, length - 9.0, length}
    for b in bands:
        fixed |= {b - BAND_HW, b + BAND_HW, b - BAND_HW - 4.0, b + BAND_HW + 4.0}   # + a narrow run-down strip
    xs = sorted(fixed)
    rings_x = []
    for a, b in zip(xs[:-1], xs[1:]):
        rings_x.append((a, True))
        gap = b - a
        if gap > 30.0:
            n = int(gap // 22.0)
            for i in range(1, n + 1):
                rings_x.append((a + gap * i / (n + 1) + rng.uniform(-2.0, 2.0), False))
    rings_x.append((xs[-1], True))
    free = [i for i, (_, fx) in enumerate(rings_x) if not fx]
    dents = {}
    if free:
        for i in rng.choice(free, size=min(len(free), max(1, int(length // 120))), replace=False):
            k0 = int(rng.choice(DENT_K))
            dents[int(i)] = (k0, rng.uniform(2.0, 3.0))
    # a dent also sinks its free neighbour rings a little, so it reads as a dent rather than a crease
    soft = {}
    for i, (k0, dep) in dents.items():
        for j in (i - 1, i + 1):
            if j in free and j not in dents:
                soft[j] = (k0, dep * 0.4)
    rings = [pipe_ring(x, jitter=0.0 if fx else 0.8, rng=rng, dent=dents.get(i, soft.get(i)), keep=SEAM_K)
             for i, (x, fx) in enumerate(rings_x)]
    parts.add(pp.sweep(rings), "EnvRust", "rust")
    for b in bands:
        lap_band(parts, (b, 0.0, 0.0), X, rng)
    seam_strip(parts, 4.0, length - 4.0, rng, skip=[(b - BAND_HW, b + BAND_HW) for b in bands])
    info = dict(kind="straight", advance=length, ports={"in": port((0, 0, 0), I3), "out": port((length, 0, 0), I3)},
                ucx=[np.concatenate([hull_ring((0, 0, 0), X, 22.4), hull_ring((length, 0, 0), X, 22.4)])],
                seal=("in", "out"),
                extra={"length_cm": length, "lap_bands_x_cm": bands,
                       "seam": "riveted seam strip on the top-back facet (Unreal local up and -Y); roll the piece "
                               "about X in 22.5 deg steps to move it"})
    return parts, info


ELBOW_BAND_HW = 5.0            # riveted lap band at an elbow's end joints: 5 cm into the neck (clear of a flange
                               # overlay's bolt heads, x <= 8.9), up to 5 cm into the gore (tapered on the inner side)
FLANGE_ZONE = 9.0              # a PipeFlange overlay (plates + bolt heads) reaches 8.9 cm from a port


def elbow_rings(angle_deg, n_gores, rng):
    """Rings of a lobster-back elbow. Every joint ring is the mitre ellipse slid along its own gore's axis (in-side
    rings along d_in, out-side rings along d_out), so the rings stay parallel to the mitre plane. Interior joints carry a
    weld bead (half width BEAD, its flat top band BEAD_TOP), the two end joints a riveted lap band (ELBOW_BAND_HW). Both
    taper per vertex on the short inner side of the bend, where a gore is only ~5.6 cm long, so neighbouring beads and
    bands never cross. Returns rings, centres, end_dir, p_end, per-ring-gap tags and the band rivet frames."""
    C = np.array([NECK, 0.0, BEND_R])
    th = np.radians(np.linspace(0.0, angle_deg, n_gores + 1))
    V = C[None, :] + BEND_R * np.column_stack([np.sin(th), np.zeros_like(th), -np.cos(th)])
    a = math.radians(angle_deg)
    end_dir = np.array([math.cos(a), 0.0, math.sin(a)])
    p_end = V[-1] + NECK * end_dir
    n = len(V) - 1
    dirs_in = [X] + [pp._n(V[j] - V[j - 1]) for j in range(1, n + 1)]
    dirs_out = [pp._n(V[j + 1] - V[j]) for j in range(n)] + [end_dir]
    ts = [pp._n(di + do) for di, do in zip(dirs_in, dirs_out)]
    rings = [pipe_ring(0.0)]
    centres = [np.zeros(3)]
    tags = []
    rivets = []
    for j in range(n + 1):
        d_in, d_out, t = dirs_in[j], dirs_out[j], ts[j]
        stretch = 1.0 / float(np.dot(t, d_out))

        def m(r):
            return pp.ring_points(V[j], t, Y, r, SIDES, stretch=stretch)
        m0 = m(R)
        # room along the gore on each side of this joint, per vertex (half of it; the next joint takes the other half)
        if j == 0:
            lim_in = np.full(SIDES, NECK - FLANGE_ZONE)
        else:
            s_in = (m0 - V[j - 1]) @ ts[j - 1] / float(np.dot(d_in, ts[j - 1]))
            lim_in = 0.5 * s_in - 0.4
        if j == n:
            lim_out = np.full(SIDES, NECK - FLANGE_ZONE)
        else:
            s_out = (V[j + 1] - m0) @ ts[j + 1] / float(np.dot(d_out, ts[j + 1]))
            lim_out = 0.5 * s_out - 0.4
        end = j in (0, n)
        hw = ELBOW_BAND_HW if end else BEAD
        oi = np.minimum(hw, lim_in)[:, None]
        oo = np.minimum(hw, lim_out)[:, None]
        if end:
            BR, CH = BAND_R, 1.2
            rr = BR + rng.uniform(-0.15, 0.15, SIDES)
            mt, mc = m(rr), m(rr - CH)
            seq = [m0 - oi * d_in, mc - oi * d_in, mt - (oi - CH) * d_in, mt + (oo - CH) * d_out, mc + oo * d_out,
                   m0 + oo * d_out]
            tags += ["rust", "rust_band", "rust_edge", "rust_band", "rust_edge", "rust_band"]
            top_a, top_b = mt - (oi - CH) * d_in, mt + (oo - CH) * d_out
            for f in (0, 3, 5, 8, 11, 13):
                f2 = (f + 1) % SIDES
                c = 0.25 * (top_a[f] + top_a[f2] + top_b[f] + top_b[f2])
                rad = c - V[j]
                rad = pp._n(rad - np.dot(rad, t) * t)
                rivets.append((c, rad))
        else:
            rb = R + BEAD_H + rng.uniform(-0.2, 0.2, SIDES)
            m1 = m(rb)
            ti = np.minimum(BEAD_TOP, 0.4 * oi)
            to = np.minimum(BEAD_TOP, 0.4 * oo)
            seq = [m0 - oi * d_in, m1 - ti * d_in, m1, m1 + to * d_out, m0 + oo * d_out]
            tags += ["rust"] + ["weld"] * 4
        rings += seq
        centres.append(V[j])
    rings.append(pp.ring_points(p_end, end_dir, Y, R, SIDES))
    tags += ["rust"]
    centres.append(p_end)
    return rings, centres, end_dir, p_end, tags, rivets


def build_elbow(angle_deg, n_gores, seed):
    rng = np.random.default_rng(seed)
    name = "PipeElbow%d_Mars_SM" % int(angle_deg)
    parts = pp.Parts(name, SLOT_ORDER)
    rings, centres, end_dir, p_end, band_tags, rivets = elbow_rings(angle_deg, n_gores, rng)
    tags = []
    for t in band_tags:
        tags += [t] * SIDES
    tags += ["rust", "rust"]
    parts.add(pp.sweep(rings), "EnvRust", tags)
    for c, d in rivets:
        parts.add(pp.rivet(c, d, 2.2, 1.8, rng), "EnvRust", "rivet")
    R_out = pp.rot_y(-angle_deg)
    # UCX: one convex piece per gore (the first and last include the necks)
    V = centres[1:-1]
    ucx = []
    for g in range(n_gores):
        d = pp._n(V[g + 1] - V[g])
        hp = [hull_ring(V[g], d, 23.2, 10), hull_ring(V[g + 1], d, 23.2, 10)]
        if g == 0:
            hp.append(hull_ring((0, 0, 0), X, 23.2, 10))
        if g == n_gores - 1:
            hp.append(hull_ring(p_end, end_dir, 23.2, 10))
        ucx.append(np.concatenate(hp))
    info = dict(kind="elbow", ports={"in": port((0, 0, 0), I3), "out": port(p_end, R_out)}, ucx=ucx, seal=("in", "out"),
                extra={"bend_deg": angle_deg, "gores": n_gores, "centreline_radius_cm": BEND_R, "neck_cm": NECK,
                       "offset_cm": pp.ue_vec(p_end)})
    return parts, info


def build_tee(seed):
    """A cast tee read as two cylinders meeting: a straight drum r 25 (x 12..88) with hard 45 deg steps down to the
    r 22 necks, and a branch saddle r 25 (z 0..30, the lower part buried in the drum) stepping down to the branch neck.
    A riveted lap band round the drum each side of the saddle; the ports take PipeFlange overlays (9 cm plain necks)."""
    rng = np.random.default_rng(seed)
    parts = pp.Parts("PipeTee_Mars_SM", SLOT_ORDER)
    run = [pipe_ring(0.0), pipe_ring(9.0), pipe_ring(91.0), pipe_ring(100.0)]
    parts.add(pp.sweep(run), "EnvRust", "rust")
    TR = 25.0
    drum = [(0.0, 8.8), (21.8, 8.8), (TR, 12.0), (TR, 36.0), (TR, 64.0), (TR, 88.0), (21.8, 91.2), (0.0, 91.2)]
    dtags = []
    for i in range(len(drum) - 1):
        dtags += ["rust_edge" if i in (1, 5) else "rust"] * SIDES
    parts.add(pp.revolve(drum, SIDES, axis=X, ref=Y, jitter=0.25, rng=rng, keep_rings=(1, 2, 5, 6)), "EnvRust",
              dtags)
    O = np.array([50.0, 0.0, 0.0])
    br = [pp.ring_points(O + Z * z, Z, Y, R, SIDES) for z in (6.0, 30.0, 40.0, 50.0)]
    parts.add(pp.sweep(br), "EnvRust", "rust")
    saddle = [(0.0, 0.0), (TR, 0.0), (TR, 30.0), (R - 0.2, 33.2), (0.0, 33.2)]
    stags = []
    for i in range(len(saddle) - 1):
        stags += ["rust_edge" if i == 2 else "rust"] * SIDES
    parts.add(pp.revolve(saddle, SIDES, origin=O, axis=Z, ref=Y, keep_rings=(1, 2, 3)), "EnvRust", stags)
    # a cast drain plug under the drum and a 10 cm hex boss (2 cm proud) on its front facet (the room side, -Y)
    ap = TR * math.cos(math.pi / SIDES)
    for adeg, rc, h, sides, slot, tag in ((258.75, 4.2, 3.0, 6, "EnvIron", "bolt"),
                                          (191.25, 5.8, 2.0, 6, "EnvRust", "rust_edge")):
        a = math.radians(adeg)
        d = math.cos(a) * Y + math.sin(a) * Z
        parts.add(pp.head(O + d * ap, d, rc, h, sides=sides, rng=rng, sink=0.6, chamfer=0.35), slot, tag)
    # the run's language: a riveted lap band round the drum on each side of the branch saddle (x 25..75)
    for xb in (18.6, 81.4):
        lap_band(parts, (xb, 0.0, 0.0), X, rng, rivets=8, r_in=24.4, r_out=28.5, hw=5.0)
    ucx = [np.concatenate([hull_ring((0, 0, 0), X, 22.4), hull_ring((100, 0, 0), X, 22.4),
                           hull_ring((12, 0, 0), X, 28.6), hull_ring((88, 0, 0), X, 28.6)]),
           np.concatenate([hull_ring(O + Z * 24.0, Z, 25.5), hull_ring(O + Z * 30.0, Z, 25.5),
                           hull_ring(O + Z * 50.0, Z, 22.4)])]
    info = dict(kind="tee", ports={"in": port((0, 0, 0), I3), "out": port((100, 0, 0), I3),
                                   "branch": port((50, 0, 50), pp.rot_y(-90))},
                ucx=ucx, seal=("in", "out", "branch"), extra={"run_cm": 100.0, "branch_cm": 50.0, "neck_cm": 9.0})
    return parts, info


def flange_hoop(parts, origin, axis, s0, s1, r_out, rng, tags=("rust", "rust_edge", "rust_edge", "rust_edge", "rust",
                                                                 "rust"), r_in=21.0, ch=0.8, jitter=0.2):
    prof = [(r_in, s0), (r_out - ch, s0), (r_out, s0 + ch), (r_out, s1 - ch), (r_out - ch, s1), (r_in, s1)]
    t = []
    for x in tags:
        t += [x] * SIDES
    parts.add(pp.revolve(prof, SIDES, origin=origin, axis=axis, ref=Y, closed=True, jitter=jitter, rng=rng),
              "EnvRust", t)


def baked_joint(parts, x_port, sgn, rng):
    """A complete bolted flange joint just inside a port (the valve's ends): the pipe-side plate (s 2.5..6.0, r 31), a
    gasket, the cast body flange (s 6.8..10.8, r 32), 8 bolts through both - hex heads on the body side, nuts on the
    pipe side, all inside the port plane (s >= 0). s = distance from the port into the body."""
    o = np.array([x_port, 0.0, 0.0])
    ax = X * sgn
    flange_hoop(parts, o, ax, 2.5, 6.0, 31.0, rng)
    gasket = [(20.4, 5.9), (29.6, 5.9), (29.6, 6.9), (20.4, 6.9)]
    parts.add(pp.revolve(gasket, SIDES, origin=o, axis=ax, ref=Y, closed=True), "EnvIron", "gasket")
    flange_hoop(parts, o, ax, 6.8, 10.8, 32.0, rng)
    for k in range(8):
        a = math.radians(22.5 + 45.0 * k)
        c = np.array([0.0, 28.0 * math.cos(a), 28.0 * math.sin(a)])
        parts.add(pp.head(o + c + ax * 10.8, ax, 2.3, 2.0, rng=rng), "EnvIron", "bolt")
        parts.add(pp.head(o + c + ax * 2.5, -ax, 2.3, 2.0, rng=rng), "EnvIron", "bolt")


def build_valve(seed):
    """Hard-stepped cast gate valve, 50 cm inline: baked bolted port joints, an 8-sided drum (circumradius 28, flats
    on +Z / -Y) with flat 45 deg shoulders, a short stout 8-sided bonnet (18 across) to a bolted bonnet flange pair,
    a stubby gland cap with a brass gland nut, and the square brass stem toward -Y to SOCKET_Wheel at 49 cm."""
    rng = np.random.default_rng(seed)
    parts = pp.Parts("ValveGate_A_Mars_SM", SLOT_ORDER)
    core = [pipe_ring(0.0), pipe_ring(2.6), pipe_ring(VALVE_L - 2.6), pipe_ring(VALVE_L)]
    parts.add(pp.sweep(core), "EnvRust", "rust")
    baked_joint(parts, 0.0, 1.0, rng)
    baked_joint(parts, VALVE_L, -1.0, rng)
    DR = 28.0
    drum = [(0.0, 11.6), (22.8, 11.6), (DR, 16.8), (DR, VALVE_L - 16.8), (22.8, VALVE_L - 11.6), (0.0, VALVE_L - 11.6)]
    dtags = []
    for i in range(len(drum) - 1):
        dtags += ["rust_edge" if i in (1, 3) else "rust"] * 8
    parts.add(pp.revolve(drum, 8, axis=X, ref=Y, phase_deg=22.5), "EnvRust", dtags)
    O = np.array([VALVE_L * 0.5, 0.0, 0.0])
    A = -Y
    # a short, stout bonnet straight off the drum's front flat (concept 2: the bonnet shows between pipe and wheel).
    # 8-sided, flats on X / Z; its X extent stays <= 13.4 so it clears the baked body flanges (x <= 10.8, >= 39.2)
    bon = [(0.0, 20.0), (9.8, 20.0), (9.8, 30.2), (0.0, 30.2)]       # 18 across flats
    parts.add(pp.revolve(bon, 8, origin=O, axis=A, ref=X, phase_deg=22.5, jitter=0.15, rng=rng,
                         keep_rings=(0, 3)), "EnvRust", ["rust_dark"] * 8 + ["rust"] * 8 + ["rust"] * 8)
    BF = 14.5                                                  # bonnet flange circumradius (apothem 13.4)
    nf = [(0.0, 28.4), (BF - 0.9, 28.4), (BF, 29.3), (BF, 31.4), (BF - 0.9, 32.3), (0.0, 32.3)]
    bf = [(0.0, 33.1), (BF - 0.6, 33.1), (BF, 33.7), (BF, 36.0), (BF - 0.7, 36.7), (0.0, 36.7)]
    ftags = []
    for t in ("rust_dark", "rust_edge", "rust_edge", "rust_edge", "rust"):
        ftags += [t] * 8
    parts.add(pp.revolve(nf, 8, origin=O, axis=A, ref=X, phase_deg=22.5), "EnvRust", ftags)
    parts.add(pp.revolve(bf, 8, origin=O, axis=A, ref=X, phase_deg=22.5), "EnvRust", ftags)
    gk = [(0.0, 32.2), (12.6, 32.2), (12.6, 33.2), (0.0, 33.2)]
    parts.add(pp.revolve(gk, 8, origin=O, axis=A, ref=X, phase_deg=22.5), "EnvIron", "gasket")
    for k in range(6):
        a = math.radians(30.0 + 60.0 * k)
        c = O + 11.0 * (math.cos(a) * X + math.sin(a) * Z)
        parts.add(pp.head(c + A * 36.7, A, 1.6, 1.8, rng=rng), "EnvIron", "bolt")
        parts.add(pp.head(c + A * 28.4, -A, 1.6, 1.5, rng=rng), "EnvIron", "bolt")
    # stubby packing gland: a tapered 8-sided cap, a brass gland nut, then the square brass stem to the wheel hub
    cap = [(0.0, 36.3), (8.6, 36.3), (8.6, 37.6), (7.0, 39.2), (0.0, 39.2)]
    parts.add(pp.revolve(cap, 8, origin=O, axis=A, ref=X, phase_deg=22.5), "EnvRust", "rust_edge")
    parts.add(pp.revolve([(0.0, 38.8), (6.0, 38.8), (6.0, 40.0), (4.9, 40.6), (0.0, 40.6)], 6, origin=O, axis=A,
                         ref=X, phase_deg=30.0), "EnvBrass", "brass")
    stem = [(0.0, 40.2), (3.2, 40.2), (3.2, WHEEL_DEPTH + 1.0), (0.0, WHEEL_DEPTH + 1.0)]
    parts.add(pp.revolve(stem, 4, origin=O, axis=A, ref=X, phase_deg=45.0), "EnvBrass", "brass")
    # drain plug under the drum's bottom flat, a brass name plate with four rivets on its top flat
    ap = DR * math.cos(math.radians(22.5))
    parts.add(pp.head(O - Z * ap, -Z, 4.0, 3.0, rng=rng), "EnvIron", "bolt")
    parts.add(pp.obox(O + Z * (ap + 0.35), (13.0, 9.0, 1.4)), "EnvBrass", "brass")
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            parts.add(pp.rivet(O + np.array([sx * 5.2, sy * 3.2, ap + 1.05]), Z, 0.7, 0.5, rng), "EnvBrass", "brass")
    sock = O + A * WHEEL_DEPTH
    ucx = [np.concatenate([hull_ring((0, 0, 0), X, 22.4), hull_ring((VALVE_L, 0, 0), X, 22.4),
                           hull_ring((6.8, 0, 0), X, 32.4), hull_ring((VALVE_L - 6.8, 0, 0), X, 32.4)]),
           np.concatenate([pp.ring_points(O + A * 20.0, A, X, 14.6, 8), pp.ring_points(O + A * 36.7, A, X, 14.6, 8),
                           pp.ring_points(O + A * 41.4, A, X, 6.5, 8)])]
    info = dict(kind="valve", advance=VALVE_L,
                ports={"in": port((0, 0, 0), I3), "out": port((VALVE_L, 0, 0), I3)},
                sockets=[("Wheel", sock, (0.0, 0.0, -90.0))], ucx=ucx, seal=("in", "out"),
                extra={"length_cm": VALVE_L, "stem_dir_local": pp.ue_vec(A),
                       "port_joints": "both ports carry a complete baked bolted flange joint (x 2.5..10.8 from each "
                                      "port): never place PipeFlange at a ValveGate_A port",
                       "wheel": {"socket": "SOCKET_Wheel", "mesh": "ValveWheel_A_Mars_SM",
                                 "location_cm": pp.ue_vec(sock),
                                 "rotation_pyr_deg": pp.ue_rotator(pp.rot_z(-90.0)),
                                 "spin_axis": "socket +X (= the stem, Unreal +Y)"}})
    return parts, info


def build_cap(seed):
    """A complete bolted blind joint: the pipe-side mating plate (x 2.4..6.6, r 32), a gasket, the blind flange
    (x 7.4..13.2, r 33) with its dome; hex heads behind the mating plate, nuts with stud tips on the blind face."""
    rng = np.random.default_rng(seed)
    parts = pp.Parts("PipeCap_Mars_SM", SLOT_ORDER)
    prof = [(0.0, 0.0), (R, 0.0), (R, 7.4), (32.2, 7.4), (33.0, 8.2), (33.0, 12.4), (32.2, 13.2), (24.5, 13.2),
            (23.6, 15.9), (20.5, 18.7), (14.0, 20.9), (6.5, 22.0), (0.0, 22.3)]
    tags = []
    for i in range(len(prof) - 1):
        tags += ["rust_edge" if i in (3, 4, 5) else "rust"] * SIDES
    parts.add(pp.revolve(prof, SIDES, axis=X, ref=Y, jitter=0.3, rng=rng, keep_rings=(1, 2)), "EnvRust", tags)
    flange_hoop(parts, np.zeros(3), X, 2.4, 6.6, 32.0, rng)
    gasket = [(20.4, 6.5), (30.4, 6.5), (30.4, 7.5), (20.4, 7.5)]
    parts.add(pp.revolve(gasket, SIDES, axis=X, ref=Y, closed=True), "EnvIron", "gasket")
    flange_bolts(parts, 13.2, 28.4, 8, rng, normal=X, rc=2.3, h=2.0, stud=True)
    flange_bolts(parts, 2.4, 28.4, 8, rng, normal=-X, rc=2.3, h=1.9)
    parts.add(pp.head((22.0, 0.0, 0.0), X, 5.0, 3.2, rng=rng), "EnvIron", "bolt")
    ucx = [np.concatenate([hull_ring((0, 0, 0), X, 22.4), hull_ring((2.4, 0, 0), X, 33.4),
                           hull_ring((13.2, 0, 0), X, 33.4), hull_ring((25.0, 0, 0), X, 6.0)])]
    info = dict(kind="end", ports={"in": port((0, 0, 0), I3)}, ucx=ucx, seal=("in",),
                extra={"blind_flange_radius_cm": 33.0, "reach_cm": 25.2,
                       "flange": "the cap is a complete bolted blind joint (mating plate, gasket, blind flange): never "
                                 "place PipeFlange at a cap port"})
    return parts, info


# PipeSpout_A mouth, per ring vertex (0 = +Y, 4 = top, 8 = -Y, 12 = bottom): a roughly square break at x ~46 whose
# upper half is torn into teeth (0, 2-3 flat-topped, 5, 7) and three notches (1, 4, 6; 6, 9 and 5 cm deep); the
# bottom runs out past the break into a rounded spatula tongue (vertices 11..13, ~12 cm wide, ~7 cm long)
SPOUT_MOUTH_X = (45.5, 39.5, 46.5, 45.5, 37.0, 45.0, 40.5, 46.5, 47.5, 47.5, 48.5, 53.4, 54.0, 53.4, 48.0, 47.0)
SPOUT_DROOP = (0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 4.2, 5.0, 4.2, 1.0, 0.0)
SPOUT_BREAK_X = 45.5                     # where the tongue starts to bend down
SPOUT_PINCH = {11: 5.5, 13: -5.5}        # deg: the tongue's side vertices pulled toward the bottom (12 cm, not 17)


def build_spout(seed):
    """A broken open pipe end: a roughly square break whose upper half is torn into teeth and three notches 5..9 cm deep
    (each tooth face a flat chiselled facet); past the break the bottom runs out into a rounded spatula tongue ~12 cm
    wide that bends 5 cm down and keeps the full wall thickness (the RI ring) to its tip; SOCKET_Drip under the tip."""
    rng = np.random.default_rng(seed)
    parts = pp.Parts("PipeSpout_A_Mars_SM", SLOT_ORDER)
    RI = 19.4
    a = np.arange(SIDES) * math.tau / SIDES
    for k, d in SPOUT_PINCH.items():
        a[k] += math.radians(d)
    down = np.maximum(0.0, -np.sin(a))                    # 1 at vertex 12 (the bottom)
    xm = np.array(SPOUT_MOUTH_X) + rng.uniform(-0.5, 0.5, SIDES)
    droop = np.array(SPOUT_DROOP)
    tongue = droop > 0.0
    flare = 1.5 * down ** 2 * tongue
    # the bend ring: just behind the break for the tongue, 60 % of the way to a tooth / notch elsewhere
    xb = np.where(tongue, SPOUT_BREAK_X, 25.0 + 0.6 * (xm - 25.0))

    def ring(x, r, bend):
        rr = r + flare * bend
        return np.column_stack([x, rr * np.cos(a), rr * np.sin(a) - droop * bend])
    rings = [pipe_ring(0.0), pipe_ring(9.0), pipe_ring(25.0, jitter=0.6, rng=rng), ring(xb, R, 0.0),
             ring(xm, R, 1.0), ring(xm - 0.9, RI, 1.0), ring(xb - 0.9, RI, 0.0),
             pp.ring_points((19.0, 0, 0), X, Y, RI + rng.uniform(-0.2, 0.2, SIDES), SIDES),
             pp.ring_points((5.0, 0, 0), X, Y, RI, SIDES)]
    tags = ["rust"] * (4 * SIDES) + ["torn"] * SIDES + ["inner"] * (3 * SIDES) + ["rust", "inner"]

    def mouth(r, dx):
        return ring(xm - dx, r, 1.0)
    parts.add(pp.sweep(rings), "EnvRust", tags)
    lap_band(parts, (19.0, 0.0, 0.0), X, rng)          # clear of a PipeCollar sleeve (x <= 12)
    tip = mouth(R, 0.0)[SIDES * 3 // 4]
    drip = tip + np.array([0.0, 0.0, -0.4])
    ucx = [np.concatenate([hull_ring((0, 0, 0), X, 22.4), hull_ring((30.0, 0, 0), X, 22.4)])]
    info = dict(kind="end", ports={"in": port((0, 0, 0), I3)}, sockets=[("Drip", drip, (0.0, 0.0, 0.0))], ucx=ucx,
                seal=("in",), extra={"drip": {"socket": "SOCKET_Drip", "location_cm": pp.ue_vec(drip),
                                              "falls": "-Z (world) from the lip tip; the lip is the pipe's local -Z "
                                                       "side, so keep the spout's up roughly +Z"},
                                     "mouth_x_cm": [round(float(xm.min()), 2), round(float(xm.max()), 2)]})
    return parts, info


# ================================================================ overlays + supports
def build_flange(seed):
    rng = np.random.default_rng(seed)
    parts = pp.Parts("PipeFlange_Mars_SM", SLOT_ORDER)
    plate = [(21.0, 0.6), (32.2, 0.6), (33.2, 1.5), (33.2, 5.6), (32.2, 6.5), (21.0, 6.5)]
    ptags = ["rust", "rust_edge", "rust_edge", "rust_edge", "rust", "rust"]
    for sgn in (1.0, -1.0):
        prof = [(r, sgn * s) for r, s in plate]
        tags = []
        for t in ptags:
            tags += [t] * SIDES
        parts.add(pp.revolve(prof, SIDES, axis=X, ref=Y, closed=True, jitter=0.25, rng=rng), "EnvRust", tags)
    gasket = [(20.2, -0.9), (30.6, -0.9), (30.6, 0.9), (20.2, 0.9)]
    parts.add(pp.revolve(gasket, SIDES, axis=X, ref=Y, closed=True), "EnvIron", "gasket")
    flange_bolts(parts, 6.5, 28.0, 8, rng, normal=X, rc=2.6, h=2.4)
    flange_bolts(parts, -6.5, 28.0, 8, rng, normal=-X, rc=2.6, h=2.2, stud=True)
    ucx = [np.concatenate([hull_ring((-6.5, 0, 0), X, 33.5, 12), hull_ring((6.5, 0, 0), X, 33.5, 12)])]
    info = dict(kind="overlay", ports={"joint": port((0, 0, 0), I3)}, ucx=ucx, seal=(),
                extra={"advance_cm": 0.0, "plate_radius_cm": 33.2, "thickness_cm": 13.0,
                       "place": "at any port frame of a run (same location + rotation): the joint plane is x = 0, "
                                "the plates span x -6.5..6.5 and the straights, elbows and tee have plain necks "
                                "(>= 9 cm); never at a PipeCap or ValveGate_A port (their joints are baked)",
                       "never_at": ["PipeCap_Mars_SM", "ValveGate_A_Mars_SM"]})
    return parts, info


def build_collar(seed):
    rng = np.random.default_rng(seed)
    parts = pp.Parts("PipeCollar_Mars_SM", SLOT_ORDER)
    plate = [(0.0, -1.5), (38.5, -1.5), (38.5, 1.4), (36.6, 3.2), (0.0, 3.2)]
    tags = ["rust_dark"] * 8 + ["rust_edge"] * 8 + ["rust_edge"] * 8 + ["rust"] * 8
    parts.add(pp.revolve(plate, 8, axis=X, ref=Y, phase_deg=22.5, jitter=0.5, rng=rng), "EnvRust", tags)
    sleeve = [(21.0, 2.4), (25.6, 2.4), (25.6, 10.6), (24.6, 12.0), (21.0, 12.0)]
    parts.add(pp.revolve(sleeve, SIDES, axis=X, ref=Y, closed=True, jitter=0.15, rng=rng), "EnvRust", "rust_band")
    face_r = 25.6 * math.cos(math.pi / SIDES)
    for k in range(8):
        a = math.radians((2 * k + 0.5) * 22.5)
        d = np.array([0.0, math.cos(a), math.sin(a)])
        parts.add(pp.rivet(np.array([7.0, 0, 0]) + d * face_r, d, 1.2, 0.9, rng), "EnvRust", "rivet")
    for k in range(4):
        a = math.radians(45.0 + 90.0 * k)
        parts.add(pp.head((3.2, 30.0 * math.cos(a), 30.0 * math.sin(a)), X, 2.8, 2.6, rng=rng), "EnvIron", "bolt")
    info = dict(kind="overlay", ports={"joint": port((0, 0, 0), I3)}, ucx=[], seal=(),
                extra={"advance_cm": 0.0, "wall_face_plane": "local x = 0 (the plate back is 1.5 cm inside the wall)",
                       "plate_across_flats_cm": round(2 * 38.5 * math.cos(math.pi / 8), 2),
                       "start_of_run": "place at the run's first pivot (same frame): the pipe leaves the wall along +X",
                       "end_of_run": "place at the last out port turned 180 deg about local Z (yaw 180), so +X points "
                                     "back along the pipe; the plate then lies on the wall / floor the run enters"})
    return parts, info


def build_bracket(seed):
    """Wall strap: a back plate, a solid stand-off (a 7 wide saddle block plus two 1.5 cm triangular gussets) and a
    clamp ring 3 cm radial x 9 wide round the pipe axis at (0, -32, 0), with bolted lugs on the far side."""
    rng = np.random.default_rng(seed)
    parts = pp.Parts("PipeBracket_Mars_SM", SLOT_ORDER)
    D = WALL_OFFSET
    to_world = np.column_stack([X, Z, -Y])                   # local (x, y=up, z=out of the wall) -> world
    plate = [(-8.0, -29.0), (-5.0, -32.0), (5.0, -32.0), (8.0, -29.0), (8.0, 29.0), (5.0, 32.0), (-5.0, 32.0),
             (-8.0, 29.0)]
    pv, pf = pp.prism(plate, 0.0, 2.5, to_world)
    pv[np.abs(pv[:, 1]) > 1.0] += rng.uniform(-0.15, 0.15, size=(int((np.abs(pv[:, 1]) > 1.0).sum()), 3)) * [1, 0, 1]
    parts.add((pv, pf), "EnvIron", "iron")
    for z in (-27.0, 27.0):
        parts.add(pp.head((0.0, -2.5, z), -Y, 2.6, 2.2, rng=rng), "EnvIron", "bolt")
    RI, RO, HW = 22.0, 25.0, 4.5
    ring = [(RI - 0.6, -HW), (RO - 0.7, -HW), (RO, -HW + 0.7), (RO, HW - 0.7), (RO - 0.7, HW), (RI - 0.6, HW)]
    parts.add(pp.revolve(ring, SIDES, origin=(0, -D, 0), axis=X, ref=Y, closed=True, jitter=0.12, rng=rng),
              "EnvIron", "iron")
    back = -D + RO * math.cos(math.pi / SIDES)                 # the ring's back facet (toward the wall)
    # saddle block: 7 wide (x), from the plate into the ring's back, 12 tall
    parts.add(pp.obox((0.0, 0.5 * (-2.0 + back - 0.8), 0.0), (7.0, abs(back - 0.8 + 2.0), 12.0)), "EnvIron", "iron")
    # gussets: 1.5 cm triangular plates above and below, plate -> ring
    for sz in (-1.0, 1.0):
        zr = 11.0
        yr = -D + math.sqrt(RO * RO - zr * zr) - 0.6
        tri = [(-2.2, sz * 5.0), (-2.2, sz * 22.0), (yr, sz * zr)]
        to_w = np.column_stack([Y, Z, X])                      # local (y, z, x)
        parts.add(pp.prism(tri, -0.75, 0.75, to_w), "EnvIron", "iron")
    lug_y = -D - RO - 1.6
    for z0, z1 in ((1.2, 5.2), (-5.2, -1.2)):
        parts.add(pp.obox((0.0, lug_y, 0.5 * (z0 + z1)), (7.0, 6.0, z1 - z0)), "EnvIron", "iron")
    parts.add(pp.head((0.0, lug_y - 0.5, 5.2), Z, 2.0, 1.8, rng=rng), "EnvIron", "bolt")
    parts.add(pp.head((0.0, lug_y - 0.5, -5.2), -Z, 2.0, 1.7, rng=rng), "EnvIron", "bolt")
    rod = [(0.0, -5.0), (0.9, -5.0), (0.9, 5.0), (0.0, 5.0)]
    parts.add(pp.revolve(rod, 6, origin=(0.0, lug_y - 0.5, 0.0), axis=Z), "EnvIron", "bolt")
    info = dict(kind="support", ports={}, ucx=[], seal=(),
                extra={"pipe_axis_cm": pp.ue_vec((0.0, -D, 0.0)), "pipe_axis_dir": [1.0, 0.0, 0.0],
                       "wall_offset_cm": D, "clamp_width_cm": 2 * HW,
                       "place": "back plane on the wall; the pipe axis runs along local X at Unreal (0, +32, 0) cm, so "
                                "a run along a wall keeps its axis 32 cm off the wall face; keep the clamp clear of "
                                "the lap bands (x 50 +- 5.5 per metre)"})
    return parts, info


def build_wheel(seed):
    """The concept 2 wheel, diameter 90: a heavy rim (r 36..45, 8 deep), 8 chunky spokes flaring from hw 3.5 at mid
    to 4.5 at hub and rim, a hub r 12 x 12 deep with a hex nut, rim bolts rc 2.6 that break the silhouette."""
    rng = np.random.default_rng(seed)
    parts = pp.Parts("ValveWheel_A_Mars_SM", SLOT_ORDER)
    rim = [(36.0, -3.0), (37.0, -4.0), (44.0, -4.0), (45.0, -3.0), (45.0, 3.0), (44.0, 4.0), (37.0, 4.0), (36.0, 3.0)]
    rtags = []
    for t in ("rust", "rust", "rust_edge", "rust_edge", "rust_edge", "rust", "rust", "rust_dark"):
        rtags += [t] * 24
    parts.add(pp.revolve(rim, 24, axis=X, ref=Y, closed=True, jitter=0.35, rng=rng), "EnvRust", rtags)
    for k in range(8):
        a = math.radians(45.0 * k + 22.5 + rng.uniform(-1.5, 1.5))
        e = np.array([0.0, math.cos(a), math.sin(a)])
        g = np.array([0.0, -math.sin(a), math.cos(a)])
        rings = []
        for r, hw, hd in ((10.5, 4.5, 3.4), (23.0, 3.5, 2.8), (36.6, 4.5, 3.4)):
            c = e * r + X * rng.uniform(-0.25, 0.25)
            sec = [(hw, 0.0), (hw * 0.55, hd), (-hw * 0.55, hd), (-hw, 0.0), (-hw * 0.55, -hd), (hw * 0.55, -hd)]
            rings.append(np.array([c + g * s0 + X * s1 for s0, s1 in sec]))
        parts.add(pp.sweep(rings), "EnvRust", "rust")
    hub = [(0.0, -6.0), (10.4, -6.0), (12.0, -4.4), (12.0, 4.4), (10.4, 6.0), (0.0, 6.0)]
    parts.add(pp.revolve(hub, 8, axis=X, ref=Y, phase_deg=22.5, jitter=0.2, rng=rng), "EnvRust", "rust_edge")
    back = [(0.0, -5.8), (6.4, -5.8), (6.4, -7.4), (0.0, -7.4)]
    parts.add(pp.revolve(back, 6, axis=X, ref=Y), "EnvRust", "rust_dark")
    parts.add(pp.head((6.0, 0.0, 0.0), X, 6.0, 4.0, rng=rng), "EnvIron", "bolt")
    for k in range(8):
        a = math.radians(45.0 * k + 22.5)
        parts.add(pp.head((4.0, 40.5 * math.cos(a), 40.5 * math.sin(a)), X, 2.6, 2.2, rng=rng), "EnvIron", "bolt")
        b = a + math.radians(22.5)
        parts.add(pp.rivet(np.array([4.0, 40.5 * math.cos(b), 40.5 * math.sin(b)]), X, 1.5, 1.1, rng), "EnvRust",
                  "rivet")
    ucx = [np.concatenate([hull_ring((-4.0, 0, 0), X, 45.2, 16), hull_ring((4.0, 0, 0), X, 45.2, 16),
                           hull_ring((10.0, 0, 0), X, 6.0, 6), hull_ring((-7.4, 0, 0), X, 6.4, 6)])]
    info = dict(kind="mount", ports={}, ucx=ucx, seal=(),
                extra={"mount": "ValveGate_A_Mars_SM SOCKET_Wheel (the wheel's +X along the stem)",
                       "spin_axis": [1.0, 0.0, 0.0], "diameter_cm": 90.0, "hub_depth_cm": 12.0, "spokes": 8})
    return parts, info


# ================================================================ water + grates + gate
DRAIN_FRAME = 9.5              # DrainGrate_A frame width
DRAIN_CHAMFER = 6.0            # outer chamfer run, z 0 -> 1.5
DRAIN_BOLT = 7.75              # corner bolt inset from the outer edge (on the 3.5 cm flat top)
def build_drain(seed):
    """1 x 0.5 m floor grate: a 9.5 cm iron frame, its top 1.5 cm proud, chamfered over 6 cm down to z = 0 at the outer
    edge so it sits into the floor; 4 x 1.2 cm bars at 9 cm pitch on two cross bars, 4 corner bolts sunk to the frame
    top (heads 2.5 mm proud, clear of z-fighting), a dark sump plate under the bars."""
    rng = np.random.default_rng(seed)
    parts = pp.Parts("DrainGrate_A_Mars_SM", SLOT_ORDER)
    HX, HY, FW = 50.0, 25.0, DRAIN_FRAME
    prof = [(0.0, 0.0), (0.0, 0.12), (DRAIN_CHAMFER, 1.5), (FW, 1.5), (FW, 0.0)]
    rings = []
    for i, (d, z) in enumerate(prof):
        j = rng.uniform(-0.2, 0.2, (4, 2)) if i == 2 else np.zeros((4, 2))
        rings.append(np.array([[HX - d + j[0, 0], -(HY - d) + j[0, 1], z], [HX - d + j[1, 0], HY - d + j[1, 1], z],
                               [-(HX - d) + j[2, 0], HY - d + j[2, 1], z],
                               [-(HX - d) + j[3, 0], -(HY - d) + j[3, 1], z]]))
    ftags = ["iron_light", "iron_light", "iron", "iron_dark", "iron_dark"]
    tags = []
    for t in ftags:
        tags += [t] * 4
    parts.add(loft_closed(rings), "EnvIron", tags)
    ix, iy = HX - FW, HY - FW
    parts.add(pp.obox((0.0, 0.0, 0.125), (2 * ix - 0.2, 2 * iy - 0.2, 0.25)), "EnvIron", "void")
    to_world = np.column_stack([X, Z, -Y])
    nb = int((2 * ix - 6.0) // 9.0) + 1
    x0 = -0.5 * 9.0 * (nb - 1)
    for i in range(nb):
        x = x0 + 9.0 * i + rng.uniform(-0.3, 0.3)
        sec = [(x - 2.0, 0.25), (x + 2.0, 0.25), (x + 1.7, 1.45), (x - 1.7, 1.45)]
        v, f = pp.prism(sec, -(iy - 0.05), iy - 0.05, to_world)
        parts.add((v, f), "EnvIron", "iron")
    to_world_x = np.column_stack([Y, Z, X])
    for y in (-8.5, 8.5):
        sec = [(y - 1.3, 0.55), (y + 1.3, 0.55), (y + 1.3, 1.15), (y - 1.3, 1.15)]
        parts.add(pp.prism(sec, -(ix - 0.05), ix - 0.05, to_world_x), "EnvIron", "iron_dark")
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            parts.add(pp.head((sx * (HX - DRAIN_BOLT), sy * (HY - DRAIN_BOLT), 1.5 - 0.5), Z, 1.4, 0.75,
                              rng=rng, sink=0.3), "EnvIron", "bolt")
    info = dict(kind="floor", ports={}, ucx=[], seal=(),
                extra={"footprint_cm": [100.0, 50.0], "top_z_cm": 1.5, "bolt_top_z_cm": 1.75,
                       "outer_chamfer_cm": DRAIN_CHAMFER, "opening_cm": [2 * ix, 2 * iy],
                       "bars": {"count": nb, "pitch_cm": 9.0, "width_cm": 4.0, "height_cm": 1.2},
                       "note": "frame 1.5 cm proud, chamfered over 6 cm to z = 0 at the outer edge, corner bolts "
                               "flush (2.5 mm proud); a dark sump plate under the bars reads as the drain's depth on a "
                               "solid kit floor (a top exactly at z 0 would z-fight the floor slab)"})
    return parts, info


def wall_grate_outline():
    """Frame centreline (x, z): bottom 3.5, sides x +-56.5 up to the spring at z 60, a segmental arch to z 86.5."""
    hw, z0, zs, apex = 56.5, 3.5, 60.0, 86.5
    s = apex - zs
    rad = (hw * hw + s * s) / (2.0 * s)
    zc = apex - rad
    a0 = math.atan2(zs - zc, hw)
    arch = [(rad * math.cos(t), zc + rad * math.sin(t)) for t in np.linspace(a0, math.pi - a0, 9)]
    pts = [(-hw, z0), (hw, z0)] + arch
    return np.array(pts), rad, zc


def build_wall_grate(seed):
    rng = np.random.default_rng(seed)
    parts = pp.Parts("WallGrate_A_Mars_SM", SLOT_ORDER)
    outline, rad, zc = wall_grate_outline()
    y_mid = -2.4
    pts = np.column_stack([outline[:, 0], np.full(len(outline), y_mid), outline[:, 1]])
    pts[2:, [0, 2]] += rng.uniform(-0.3, 0.3, size=(len(pts) - 2, 2))
    parts.add(pp.bar(pts, pp.polyline_normals(pts, Y, closed=True), Y, 3.5, 2.0, closed=True), "EnvIron", "iron")
    # dark void plate behind the bars (back on the wall plane)
    inner = []
    for x, z in outline[2:]:
        d = np.array([x, z - zc])
        d = d / np.linalg.norm(d)
        inner.append((x - d[0] * 2.5, z - d[1] * 2.5))
    inner = [(-54.0, 6.0), (54.0, 6.0)] + [(x, z) for x, z in inner if abs(x) <= 54.0]
    to_world = np.column_stack([X, Z, -Y])
    parts.add(pp.prism(np.array(inner), 0.0, 0.8, to_world), "EnvIron", "void")
    bar_x = [-48.0 + 12.0 * i for i in range(9)]
    for i, x in enumerate(bar_x):
        top = zc + math.sqrt(rad * rad - x * x) - 1.2
        lean = rng.uniform(-0.7, 0.7)
        bend = rng.uniform(1.5, 3.0) if i == 6 else rng.uniform(-0.3, 0.3)
        rings = [pp.ring_points((x, -2.4, 2.5), Z, X, 2.0, 6),
                 pp.ring_points((x + lean * 0.5 + bend, -2.4 - abs(bend) * 0.5, 0.5 * (2.5 + top)), Z, X, 2.0, 6),
                 pp.ring_points((x + lean, -2.4, top), Z, X, 2.0, 6)]
        parts.add(pp.sweep(rings), "EnvIron", "iron")
    for zs in (26.0, 50.0):
        v, f = pp.obox((0.0, -4.8, zs + rng.uniform(-0.4, 0.4)), (110.0, 1.8, 5.2))
        parts.add((v, f), "EnvIron", "iron_light")
        for x in bar_x:
            parts.add(pp.rivet((x + rng.uniform(-0.3, 0.3), -5.7, zs), -Y, 1.1, 0.8, rng), "EnvIron", "rivet_iron")
    for x, z in ((-56.5, 18.0), (56.5, 18.0), (-56.5, 44.0), (56.5, 44.0), (-30.0, None), (30.0, None)):
        if z is None:
            z = zc + math.sqrt(rad * rad - x * x)
        parts.add(pp.head((x, -4.4, z), -Y, 1.8, 1.5, rng=rng), "EnvIron", "bolt")
    ucx = [pp.obox((0.0, -3.25, 45.0), (120.0, 6.5, 90.0))[0]]
    info = dict(kind="wall", ports={}, ucx=ucx, seal=(),
                extra={"size_cm": [120.0, 90.0], "opening": "segmental arch, spring 60, apex 90",
                       "note": "back on the wall plane (y 0); a dark void plate behind the bars reads as the culvert; "
                               "one box UCX 120 x 6.5 x 90 so it can close a real opening"})
    return parts, info


# Stone trough of concept 2: a 12 cm plinth 6 proud of the walls, two wall courses (20 + 18) with pillowed outer faces
# and staggered joints, a 10 cm coping that overhangs 4 cm past the pillows outside and 2 cm inside, with a pour notch
# (20 wide, 6 deep) in the back (+y, wall side) coping at x = POUR_X.
BASIN = dict(wall_x=88.0, wall_y=41.0, in_x=70.0, in_y=24.0, plinth=12.0, plinth_x=94.0, plinth_y=47.0,
             courses=(12.0, 32.0, 50.0), cope_top=60.0, cope_x=95.0, cope_y=48.0, floor=18.0, water=47.0,
             pour_x=34.0, notch_w=22.0, notch_d=8.0)
BASIN_CHIPPED = {(-1, -1): 6.0, (1, 1): 5.2}     # coping outer corners (sx, sy) bitten 4..6 cm (2 of the 4)


def build_basin(seed):
    rng = np.random.default_rng(seed)
    parts = pp.Parts("StoneBasin_A_Mars_SM", SLOT_ORDER)
    b = BASIN
    WX, WY, IX, IY = b["wall_x"], b["wall_y"], b["in_x"], b["in_y"]

    def tag_faces(v, f, wet_inner=True, wet_top=False):
        slots, tags = [], []
        for face in f:
            P3 = v[face]
            n = pp.newell(P3)
            c = P3.mean(axis=0)
            kind = "top" if n[2] > 0.8 else "bottom" if n[2] < -0.8 else "chamfer" if n[2] > 0.3 else "side"
            inside = abs(c[0]) <= IX + 1.0 and abs(c[1]) <= IY + 1.0
            inward = (abs(abs(c[1]) - IY) < 1.5 and n[1] * -np.sign(c[1]) > 0.7) or \
                     (abs(abs(c[0]) - IX) < 1.5 and n[0] * -np.sign(c[0]) > 0.7)
            wet = (wet_inner and inside and inward and c[2] < b["courses"][2] + 0.5) or \
                  (wet_top and n[2] > 0.3)
            slots.append("EnvStoneDark" if wet else "EnvStone")
            tags.append(("wet_" if wet else "stone_") + kind)
        return slots, tags

    def block(x0, x1, y0, y1, z0, z1, push=(1.5, 3.0), chamfer=(0.6, 1.4), bites=None, wet_top=False, outer=None):
        if outer is None:
            outer = []
            if x1 >= WX - 0.01:
                outer.append("+x")
            if x0 <= -WX + 0.01:
                outer.append("-x")
            if y1 >= WY - 0.01:
                outer.append("+y")
            if y0 <= -WY + 0.01:
                outer.append("-y")
        v, f = pp.ashlar(x0, x1, y0, y1, z0, z1, rng, outer=outer, push=push, chamfer=chamfer, bites=bites)
        slots, tags = tag_faces(v, f, wet_top=wet_top)
        parts.add((v, f), slots, tags)

    def bite_set(corners, lo=3.0, hi=5.0, p=0.75):
        return {c: rng.uniform(lo, hi) for c in corners if rng.uniform() < p}

    # plinth: three blocks, pillowed outer faces, big bites off the outer top corners
    PX, PY, PH = b["plinth_x"], b["plinth_y"], b["plinth"]
    xs = [-PX, -30.0 + rng.uniform(-3, 3), 32.0 + rng.uniform(-3, 3), PX]
    for i, (x0, x1) in enumerate(zip(xs[:-1], xs[1:])):
        outer = ["+y", "-y"] + (["-x"] if i == 0 else []) + (["+x"] if i == 2 else [])
        corners = ([0, 3] if i == 0 else []) + ([1, 2] if i == 2 else [])
        top = PH + rng.uniform(-0.4, 0.4, 4)
        block(x0, x1, -PY, PY, 0.0, top, push=(1.0, 2.2), chamfer=(1.0, 2.0), bites=bite_set(corners, p=1.0),
              outer=outer)
    # inner floor: two slabs (wet top), 0.4 into the walls, bottom 0.4 into the plinth
    xm = 4.0 + rng.uniform(-6, 6)
    for x0, x1 in ((-IX - 0.4, xm), (xm, IX + 0.4)):
        block(x0, x1, -IY - 0.4, IY + 0.4, PH - 0.4, b["floor"] + rng.uniform(-0.3, 0.3, 4), push=(0, 0),
              chamfer=(0.4, 0.8), wet_top=True, outer=[])
    c1, c2, c3 = b["courses"]
    # course 1: long walls run the full length, end walls sit between them
    for sy, cuts in ((-1.0, [-30.0, 34.0]), (1.0, [-46.0, 8.0])):
        xs = [-WX] + [c + rng.uniform(-3, 3) for c in cuts] + [WX]
        y0, y1 = (-WY, -IY) if sy < 0 else (IY, WY)
        for x0, x1 in zip(xs[:-1], xs[1:]):
            block(x0, x1, y0, y1, c1, c2 + rng.uniform(0.0, 0.6, 4))
    for sx in (-1.0, 1.0):
        x0, x1 = (-WX, -IX) if sx < 0 else (IX, WX)
        block(x0, x1, -IY, IY, c1, c2 + rng.uniform(0.0, 0.6, 4))
    # course 2: the end walls run through (bond), the long walls sit between them, one joint each
    for sy, cut in ((-1.0, 5.0), (1.0, -20.0)):
        xs = [-IX, cut + rng.uniform(-3, 3), IX]
        y0, y1 = (-WY, -IY) if sy < 0 else (IY, WY)
        for x0, x1 in zip(xs[:-1], xs[1:]):
            block(x0, x1, y0, y1, c2, c3 + rng.uniform(0.0, 0.6, 4))
    for sx in (-1.0, 1.0):
        x0, x1 = (-WX, -IX) if sx < 0 else (IX, WX)
        block(x0, x1, -WY, WY, c2, c3 + rng.uniform(0.0, 0.6, 4))
    # coping: 10 cm, 4 past the pillows outside, 2 inside; joints clear of the wall joints; the pour notch block
    CX, CY, CT = b["cope_x"], b["cope_y"], b["cope_top"]
    ci_x, ci_y = IX - 2.0, IY - 2.0
    nx0, nx1 = b["pour_x"] - 0.5 * b["notch_w"], b["pour_x"] + 0.5 * b["notch_w"]
    cope_outer = {"-y": ["-y"], "+y": ["+y"]}
    for sy, cuts in ((-1.0, [-50.0, 22.0]), (1.0, [-58.0, nx0, nx1])):
        xs = [-CX] + cuts + [CX]
        y0, y1 = (-CY, -ci_y) if sy < 0 else (ci_y, CY)
        for x0, x1 in zip(xs[:-1], xs[1:]):
            notch = sy > 0 and abs(x0 - nx0) < 1e-6
            top = CT - (b["notch_d"] if notch else 0.0) + rng.uniform(-0.6, 0.6, 4)
            if notch:                                   # the notch floor falls 1 cm toward the basin
                top[[0, 1]] -= 1.0
            ends = [0, 1] if sy < 0 else [2, 3]
            if x0 <= -CX + 1e-6:
                ends = ends + ([3] if sy > 0 else [0])
            if x1 >= CX - 1e-6:
                ends = ends + ([2] if sy > 0 else [1])
            outer = cope_outer["+y" if sy > 0 else "-y"] + (["-x"] if x0 <= -CX + 1e-6 else []) + \
                (["+x"] if x1 >= CX - 1e-6 else [])
            bites = None
            if not notch:
                # small hand-cut bites on the inner block ends, the big chips on two of the outer corners only
                corner = {0: (-1, -1), 1: (1, -1), 2: (1, 1), 3: (-1, 1)}
                bites = {}
                for c in sorted(set(ends)):
                    sx_c, sy_c = corner[c]
                    is_outer = (x0 <= -CX + 1e-6 if sx_c < 0 else x1 >= CX - 1e-6) and sy_c == int(sy)
                    if is_outer:
                        if (sx_c, sy_c) in BASIN_CHIPPED:
                            bites[c] = BASIN_CHIPPED[(sx_c, sy_c)] + rng.uniform(-0.3, 0.3)
                    elif rng.uniform() < 0.5:
                        bites[c] = rng.uniform(2.5, 4.0)
            block(x0, x1, y0, y1, c3, top, push=(0.8, 1.6), chamfer=(1.0, 2.0), bites=bites, outer=outer,
                  wet_top=notch)
    for sx in (-1.0, 1.0):
        x0, x1 = (-CX, -ci_x) if sx < 0 else (ci_x, CX)
        block(x0, x1, -ci_y, ci_y, c3, CT + rng.uniform(-0.6, 0.6, 4), push=(0.8, 1.6), chamfer=(1.0, 2.0),
              outer=["+x" if sx > 0 else "-x"])
    water = np.array([0.0, 0.0, b["water"]])
    ucx = [pp.obox((0, 0, b["floor"] * 0.5), (2 * PX, 2 * PY, b["floor"]))[0]]
    for sy in (-1.0, 1.0):
        yc = sy * 0.5 * (CY + ci_y)
        ucx.append(pp.obox((0, yc, 0.5 * (c1 + CT)), (2 * CX, CY - ci_y, CT - c1))[0])
    for sx in (-1.0, 1.0):
        xc = sx * 0.5 * (CX + ci_x)
        ucx.append(pp.obox((xc, 0, 0.5 * (c1 + CT)), (CX - ci_x, 2 * ci_y, CT - c1))[0])
    info = dict(kind="floor", ports={}, sockets=[("Water", water, (0.0, 0.0, 0.0))], ucx=ucx, seal=(),
                extra={"water": {"socket": "SOCKET_Water", "z_cm": b["water"],
                                 "rect_cm": [[-IX, -IY], [IX, IY]], "floor_z_cm": b["floor"], "rim_z_cm": CT,
                                 "coping_inner_rect_cm": [[-ci_x, -ci_y], [ci_x, ci_y]]},
                       "pour_notch": {"x_cm": b["pour_x"], "width_cm": b["notch_w"], "depth_cm": b["notch_d"],
                                      "side": "back (Blender +y = Unreal -Y, the wall side)",
                                      "place": "put the spout's SOCKET_Drip over x = pour_x (Unreal local)"},
                       "footprint_cm": [2 * PX, 2 * PY],
                       "slots_note": "inner walls and floor wear EnvStoneDark (wet stone; the stone master ignores "
                                     "vertex colour)"})
    return parts, info


def portcullis_arch():
    """The kit portal head (crypt_spec: 2.4 x 3.0 clear + a segmental arch rising 30 cm in the lintel band):
    radius and centre height (cm) of the intrados."""
    c, s = 120.0, 30.0
    rad = (c * c + s * s) / (2.0 * s)
    return rad, 330.0 - rad


def build_portcullis(seed, arched=False):
    """Iron leaf: 9 diamond bars (10 x 10 square turned 45 deg) at 27.85 cm pitch, rails 12 tall and 5 thick each side
    (bottom rail at z 40, the middle one tilted 1 deg), pyramid spikes 12 x 12 x 22 under diamond collars, a top beam
    (straight at 300 for _A, following the kit portal's segmental arch to 330 for _B)."""
    rng = np.random.default_rng(seed)
    name = "Portcullis_B_Mars_SM" if arched else "Portcullis_A_Mars_SM"
    parts = pp.Parts(name, SLOT_ORDER)
    W, H = 240.0, 300.0
    rad, zc = portcullis_arch()

    def top_at(x):
        return zc + math.sqrt(rad * rad - x * x) if arched else H
    BR = 5.0 * math.sqrt(2.0)
    n_bars = 9
    xs = [-111.4 + 222.8 * i / (n_bars - 1) for i in range(n_bars)]
    rails = [(40.0, 0.0), (120.0, 1.0), (200.0, 0.0)]          # (z centre, tilt deg)
    if arched:
        rails.append((265.0, 0.0))

    def rail_z(zr, tilt, x):
        return zr + math.tan(math.radians(tilt)) * x
    bowed = {2: 2.6, 6: -2.2}
    thick = {1: 0.9, 4: -0.8, 7: 1.2}            # hand-forged: a few bars 1..2 cm fatter / thinner across
    short = {3: 1.6, 8: 1.1}                     # spikes worn 1..2 cm shorter (tip above z 0)
    snapped = 5 if not arched else 2             # one spike snapped off, flat broken tip
    for i, x in enumerate(xs):
        zt = top_at(x) - 8.0
        zs = [24.0] + [rail_z(z, t, x) for z, t in rails] + [zt]
        br = BR + thick.get(i, 0.0) * 0.5 * math.sqrt(2.0)
        rings = []
        for j, z in enumerate(zs):
            rings.append(pp.ring_points(np.array([x, 0.0, z]), Z, X, br, 4))
            if j + 1 < len(zs):
                zm = 0.5 * (z + zs[j + 1])
                off = np.array([rng.uniform(-0.5, 0.5), rng.uniform(-0.3, 0.3), 0.0])
                if i in bowed and j == 2:
                    off[0] += bowed[i]
                rings.append(pp.ring_points(np.array([x, 0.0, zm]) + off, Z, X, br, 4))
        parts.add(pp.sweep(rings), "EnvIron", "iron")
        collar = [pp.ring_points((x, 0.0, z), Z, X, 8.6 + max(0.0, thick.get(i, 0.0)) * 0.7, 4) for z in (21.0, 28.0)]
        parts.add(pp.sweep(collar), "EnvIron", "iron_light")
        tip = np.array([x + rng.uniform(-0.6, 0.6), rng.uniform(-0.4, 0.4), short.get(i, 0.0)])
        base = pp.ring_points((x, 0.0, 22.0), Z, X, 8.49, 4)
        if i == snapped:
            # snapped: the pyramid cut by a tilted break plane at ~9.5 cm, a flat 4-sided broken face
            hcut = 9.5
            f = (22.0 - hcut) / 22.0
            cut = tip[None, :] + (base - tip[None, :]) * f
            cut[:, 2] += np.array([1.4, 0.4, -1.0, -0.2])
            sv = np.concatenate([base, cut])
            parts.add((sv, [[3, 2, 1, 0], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]),
                      "EnvIron", ["spike"] + ["iron_dark"] + ["spike"] * 4)
        else:
            sv = np.concatenate([base, tip[None, :]])
            parts.add((sv, [[3, 2, 1, 0], [0, 1, 4], [1, 2, 4], [2, 3, 4], [3, 0, 4]]), "EnvIron", "spike")

    def rail(zr, tilt, y_in, y_out, half_h, x0=-W * 0.5, x1=W * 0.5):
        """A rail strap; its outer face is split at z -1.5 and at x +-2.6 round every rivet, so the facet under a
        rivet can carry a rust run-down; the sag is a smooth 5-knot wobble."""
        s = 1.0 if y_out > y_in else -1.0
        sec = [(y_in, -half_h), (y_out - s * 0.8, -half_h), (y_out, -half_h + 0.8), (y_out, -1.5),
               (y_out, half_h - 0.8), (y_out - s * 0.8, half_h), (y_in, half_h)]
        knots = np.linspace(x0, x1, 5)
        kz = np.concatenate([[0.0], rng.uniform(-0.4, 0.4, 3), [0.0]])
        xs_r = {float(x0), float(x1)}
        for xb in xs:
            for dx in (-2.6, 2.6):
                if x0 + 1.0 < xb + dx < x1 - 1.0:
                    xs_r.add(round(xb + dx, 4))
        rr = []
        for x in sorted(xs_r):
            dz = float(np.interp(x, knots, kz))
            rr.append(np.array([[x, yy, rail_z(zr, tilt, x) + zz + dz] for yy, zz in sec]))
        return pp.sweep(rr)
    for zr, tilt in rails:
        x_lim = W * 0.5
        if arched and zr + 6.0 > H:                               # a rail in the arch stops inside the head
            x_lim = math.sqrt(rad * rad - (zr + 6.0 + 12.0 - zc) ** 2)
        for sy in (-1.0, 1.0):
            parts.add(rail(zr, tilt, sy * 3.0, sy * 8.0, 6.0, -x_lim, x_lim), "EnvIron", "rail")
            for x in xs:
                if abs(x) < x_lim - 4.0:
                    parts.add(pp.rivet((x, sy * 8.0, rail_z(zr, tilt, x)), sy * Y, 2.0, 1.4, rng, sides=4), "EnvIron",
                              "rivet_iron")
    beam = [(-9.0, -7.0), (9.0, -7.0), (9.0, 6.0), (8.0, 7.0), (-8.0, 7.0), (-9.0, 6.0)]
    if not arched:
        rings = [np.array([[x, yy, 293.0 + zz] for yy, zz in beam]) for x in (-W * 0.5, 0.0, W * 0.5)]
        parts.add(pp.sweep(rings), "EnvIron", "iron_light")
        bolt_pts = [(x, 292.0) for x in xs]
    else:
        # arched beam: a 14 tall bar along the intrados, ends trimmed inside x +-120
        ang = math.asin((W * 0.5 - 4.0) / rad)
        th = np.linspace(-ang, ang, 11)
        mid = rad - 7.0
        pts = np.column_stack([mid * np.sin(th), np.zeros_like(th), zc + mid * np.cos(th)])
        nrm = np.column_stack([np.sin(th), np.zeros_like(th), np.cos(th)])
        parts.add(pp.bar(pts, nrm, Y, 7.0, 9.0, mitre=False), "EnvIron", "iron_light")
        bolt_pts = [(x, top_at(x) - 8.0) for x in xs]
    for x, z in bolt_pts:
        for sy in (-1.0, 1.0):
            parts.add(pp.head((x, sy * 9.0, z), sy * Y, 1.9, 1.5, rng=rng), "EnvIron", "bolt")
    if arched:
        outline = [(-W * 0.5, 0.0), (W * 0.5, 0.0)] + [(rad * math.sin(t), zc + rad * math.cos(t))
                                                       for t in np.linspace(math.asin(0.5 * W / rad),
                                                                            -math.asin(0.5 * W / rad), 9)]
        ucx = [np.array([[x, y, z] for x, z in outline for y in (-9.5, 9.5)])]
    else:
        ucx = [pp.obox((0.0, 0.0, H * 0.5), (W, 19.0, H))[0]]
    info = dict(kind="gate", ports={}, ucx=ucx, seal=(),
                extra={"opening_cm": [W, H], "leaf_plane": "y = 0 (leaf depth 18 cm)",
                       "head": ("segmental arch, chord 240, rise 30 (the kit portal's lintel band): top 330 at x 0, "
                                "300 at x +-120") if arched else "square, 300 (the kit portal's clear rectangle)",
                       "pivot": "bottom centre: spike tips on z = 0, x centred; raise along +Z to clear"})
    return parts, info


# ================================================================ registry
PIECES = [
    dict(key="Pipe_50cm", build=lambda: build_pipe(50.0, 1105), cat="prop", group="straights"),
    dict(key="Pipe_1m", build=lambda: build_pipe(100.0, 1101), cat="prop", group="straights"),
    dict(key="Pipe_2m", build=lambda: build_pipe(200.0, 1102), cat="prop", group="straights"),
    dict(key="Pipe_4m", build=lambda: build_pipe(400.0, 1104), cat="prop", group="straights"),
    dict(key="PipeElbow90", build=lambda: build_elbow(90.0, 4, 1201), cat="prop", group="fittings"),
    dict(key="PipeElbow45", build=lambda: build_elbow(45.0, 2, 1202), cat="prop", group="fittings"),
    dict(key="PipeTee", build=lambda: build_tee(1301), cat="prop", group="fittings"),
    dict(key="PipeFlange", build=lambda: build_flange(1401), cat="prop", group="joints"),
    dict(key="PipeCap", build=lambda: build_cap(1501), cat="prop", group="fittings"),
    dict(key="PipeCollar", build=lambda: build_collar(1601), cat="prop", group="joints"),
    dict(key="PipeBracket", build=lambda: build_bracket(1701), cat="prop", group="joints"),
    dict(key="ValveGate_A", build=lambda: build_valve(1801), cat="prop", group="valve"),
    dict(key="ValveWheel_A", build=lambda: build_wheel(1901), cat="prop", group="valve"),
    dict(key="PipeSpout_A", build=lambda: build_spout(2001), cat="prop", group="water"),
    dict(key="DrainGrate_A", build=lambda: build_drain(2101), cat="prop", group="water"),
    dict(key="WallGrate_A", build=lambda: build_wall_grate(2201), cat="prop", group="water"),
    dict(key="StoneBasin_A", build=lambda: build_basin(2301), cat="furniture", group="basin"),
    dict(key="Portcullis_A", build=lambda: build_portcullis(2401), cat="furniture", group="gate"),
    dict(key="Portcullis_B", build=lambda: build_portcullis(2402, arched=True), cat="furniture", group="gate"),
]
EXPECT_SOCKETS = {"ValveGate_A": {"Wheel"}, "PipeSpout_A": {"Drip"}, "StoneBasin_A": {"Water"}}


# ================================================================ paint
RUST_TARGET = ("rust", "weld", "rust_dark")
STREAK_SOURCE = ("rust_band", "rust_edge", "bolt", "rivet")
IRON_TAGS = ("iron", "iron_light", "iron_dark", "rail", "rivet_iron", "spike", "bolt")
PATCH_FRACTION = 0.17          # share of body facets in whole-facet dark pitting patches


def along_coord(key, c):
    """Distance along the run for the anisotropic rust noise (long patches along the pipe, short round it)."""
    if key.startswith("PipeElbow"):
        x, z = c[:, 0], c[:, 2]
        th = np.arctan2(x - NECK, BEND_R - z)
        return np.where(x < NECK, x, NECK + BEND_R * np.clip(th, 0.0, math.pi))
    return c[:, 0]


def streak_weights(centres, tags, src=STREAK_SOURCE, dst=RUST_TARGET, reach=15.0, hd_max=9.0):
    """Rust run-down: a `dst` facet within hd_max cm (horizontally) under a `src` facet (band, flange edge, bolt,
    rivet) takes up to 1, fading to 0 over `reach` cm of drop."""
    src = np.array([i for i, t in enumerate(tags) if t in src], int)
    dst = np.array([i for i, t in enumerate(tags) if t in dst], int)
    w = np.zeros(len(tags))
    if not len(src) or not len(dst):
        return w
    S, D = centres[src], centres[dst]
    for a in range(0, len(dst), 512):
        d = D[a:a + 512]
        dz = S[None, :, 2] - d[:, None, 2]
        hd = np.linalg.norm(S[None, :, :2] - d[:, None, :2], axis=2)
        ok = (dz > 0.5) & (dz < reach) & (hd < hd_max)
        val = np.where(ok, (1.0 - dz / reach) * np.sqrt(np.clip(1.0 - hd / hd_max, 0.0, 1.0)), 0.0)
        w[dst[a:a + 512]] = val.max(axis=1)
    return w


def paint_piece(obj, parts, seed, key=""):
    centres = fc.face_centers_cm(obj)
    normals = fc.face_normals(obj)
    al = along_coord(key, centres)
    q = centres.copy()
    if key.startswith("PipeElbow"):
        q = np.column_stack([al * 0.015, centres[:, 1] * 0.05, (centres[:, 0] + centres[:, 2]) * 0.035])
    else:
        q = np.column_stack([al * 0.015, centres[:, 1] * 0.05, centres[:, 2] * 0.05])
    k = fc.fbm(q + seed * 0.37, seed, octaves=3)
    # whole-facet pitting patches: a second, ~20 cm noise thresholded so ~17 % of the body facets fall in clusters of
    # a few adjacent facets (the noise is smooth at the facet scale, so neighbours fall in together, never speckles)
    kp = fc.fbm(centres * 0.055 + 11.3 + seed * 0.21, seed + 7, octaves=2)
    body = np.array([t in ("rust", "weld") for t in parts.tag])
    patch = np.zeros(len(parts.tag), bool)
    if body.sum() >= 12:
        patch = body & (kp >= np.quantile(kp[body], 1.0 - PATCH_FRACTION))
    streak = streak_weights(centres, parts.tag)
    gate = key.startswith("Portcullis")
    if gate:
        gstreak = streak_weights(centres, parts.tag, src=("rivet_iron",), dst=("rail",), reach=10.0, hd_max=4.5)
    rust, rd, ro = P("EnvRust"), P("EnvRustDark"), P("EnvRustOrange")
    iron, il = P("EnvIron"), P("EnvIronLight")
    brass = P("EnvBrass")
    stone, sd = P("EnvStone"), P("EnvStoneDark")
    pit = rd * 0.62                                        # almost black-red pitting
    rgb = np.empty((len(parts.tag), 3))
    for i, tag in enumerate(parts.tag):
        kk = float(k[i])
        nz = float(normals[i][2])
        z = float(centres[i][2])
        # mottled rust: the noise moves a facet up to 70 % of the way to the dark rust, 50 % to the orange
        t = max(-1.0, min(1.0, (kk - 0.5) / 0.15))
        c = pp.lerp(rust, rd, 0.7 * -t) if t < 0 else pp.lerp(rust, ro, 0.5 * t)
        # the normal gradient leads: tops catch fresh orange flaking, undersides go dark and wet-looking
        if nz > 0.2:
            c = pp.lerp(c, ro, 0.4 * float(fc.smoothstep(0.2, 0.9, nz)))
        elif nz < -0.1:
            s = float(fc.smoothstep(0.1, 0.8, -nz))
            c = pp.lerp(c, rd, 0.8 * s) * (1.0 - 0.15 * s)
        if patch[i]:
            c = pp.lerp(c, pit, 0.85)
        if tag in RUST_TARGET and streak[i] > 0.0 and not patch[i]:
            c = pp.lerp(c, ro, 0.45 * float(streak[i]))
        if tag == "rust":
            out = c
        elif tag == "rust_band":
            out = pp.lerp(c, rd, 0.5) * 0.92                # a step darker than the body: bands read at 10 m
        elif tag == "weld":
            out = pp.lerp(c, rd, 0.5)
        elif tag == "rust_edge":
            out = pp.lerp(pp.lerp(c, rd, 0.45) * 0.92, il, 0.1)     # flange rims: dark, a touch of worn iron
        elif tag == "rust_dark":
            out = pp.lerp(rd, c, 0.35)
        elif tag == "rivet":
            out = pp.lerp(ro, c, 0.45) * 1.06
        elif tag == "torn":
            out = pp.lerp(ro, il, 0.3) * 1.1                   # the raw torn edge: the jagged break reads
        elif tag == "inner":
            out = rd * 0.42
        elif tag == "bolt":
            out = pp.lerp(iron, il, 0.25 + 0.3 * kk)
        elif tag == "iron":
            out = pp.lerp(iron, il, 0.3 * kk) if nz > -0.3 else iron * 0.8
        elif tag in ("iron_light", "rail"):
            out = pp.lerp(iron, il, 0.4 + 0.25 * kk)
        elif tag == "iron_dark":
            out = iron * 0.7
        elif tag == "rivet_iron":
            out = il * 1.05
        elif tag == "spike":
            out = pp.lerp(iron, il, 0.5)
        elif tag == "gasket":
            out = rd * 0.3
        elif tag == "void":
            out = np.array([0.004, 0.0042, 0.0048])
        elif tag == "brass":
            out = pp.lerp(brass * 0.85, brass * 1.2, kk)
        elif tag.startswith("stone_"):
            tt = tag[6:]
            out = {"top": stone * 1.12, "chamfer": stone * 1.05, "side": stone, "chip": pp.lerp(stone, sd, 0.6),
                   "bottom": sd}[tt] * (0.9 + 0.2 * kk)
        elif tag.startswith("wet_"):
            tt = tag[4:]
            out = {"top": sd * 0.85, "chamfer": sd * 0.9, "side": sd * 0.8, "chip": sd * 0.65, "bottom": sd * 0.6}[tt]
        else:
            raise KeyError("%s: no paint for tag %r" % (obj.name, tag))
        if gate and tag in IRON_TAGS:
            ny = float(normals[i][1])
            # worn, lit faces: bar and rail faces toward +Z or the room (Blender -y) catch the light
            if tag in ("iron", "rail", "spike") and (nz > 0.5 or ny < -0.5):
                out = pp.lerp(out, il, 0.3)
            # rust-red run-down under every rail rivet
            if tag == "rail" and gstreak[i] > 0.0:
                out = pp.lerp(out, pp.lerp(rust, ro, 0.3), 0.75 * float(gstreak[i]))
            # wet, rusted foot of the leaf and rain-catching rail tops
            wet = 0.4 * float(fc.smoothstep(60.0, 5.0, z))
            if tag == "rail" and nz > 0.6:
                wet = max(wet, 0.4)
            out = pp.lerp(out, rd, wet)
        rgb[i] = out
    fc.paint(obj, rgb, variation=0.08, seed=seed)


# ================================================================ checks
def check_piece(key, obj, parts, info, fails):
    name = obj.name
    budget = spec.TRIS[next(p["cat"] for p in PIECES if p["key"] == key)]
    tris = fc.tri_count(obj)
    out = []
    if not name.endswith("_Mars_SM"):
        out.append("name")
    slots = [m.name for m in obj.data.materials]
    if any(s not in spec.SLOTS for s in slots):
        out.append("slots %s not all in env_spec.SLOTS" % slots)
    used = {p.material_index for p in obj.data.polygons}
    if used != set(range(len(slots))):
        out.append("a material slot has no faces")
    if any(p.use_smooth for p in obj.data.polygons):
        out.append("smooth faces")
    attr = obj.data.color_attributes.get("Col")
    if attr is None or attr.domain != "CORNER" or attr.data_type != "FLOAT_COLOR":
        out.append("Col missing / wrong")
    else:
        col = np.empty(len(attr.data) * 4)
        attr.data.foreach_get("color", col)
        col = col.reshape(-1, 4)
        if col.min() < 0.0 or col.max() > 1.0:
            out.append("Col out of 0..1")
    if not obj.data.uv_layers or obj.data.uv_layers[0].name != "UVMap":
        out.append("UV0 is not UVMap")
    if tris > budget:
        out.append("tris %d > %s budget %d" % (tris, next(p["cat"] for p in PIECES if p["key"] == key), budget))
    shell = pp.shell_problems(obj, parts.part)
    if shell:
        out.append("shells: %s" % shell[:4])
    floating = pp.floating_parts(obj, parts.part)
    if floating:
        tags = [parts.tag[parts.part.index(p)] for p in floating]
        out.append("floating parts %s (%s)" % (floating[:6], tags[:6]))
    v, polys = pp.mesh_polys(obj)
    same, opp = pp.coplanar_overlaps(v, polys, parts.part)
    if same:
        out.append("coplanar same-facing overlaps (z-fight) %s" % [(parts.tag[a], parts.tag[b]) for a, b in same[:5]])
        if os.environ.get("PIPES_DEBUG"):
            for a, b in same[:3]:
                for fi in (a, b):
                    P3 = v[polys[fi]]
                    print("   DEBUG face %d part %d tag %s centre %s normal %s" % (
                        fi, parts.part[fi], parts.tag[fi], np.round(P3.mean(axis=0), 3), np.round(pp.newell(P3), 4)))
    ucx = sc.children(obj, "UCX_")
    if len(ucx) != len(info["ucx"]):
        out.append("ucx %d != %d" % (len(ucx), len(info["ucx"])))
    probs = sc.check_ucx(obj)
    if probs:
        out.append("ucx %s" % probs)
    socks = {e.name[len("SOCKET_"):] for e in sc.children(obj, "SOCKET_")}
    if socks != EXPECT_SOCKETS.get(key, set()):
        out.append("sockets %s != %s" % (sorted(socks), sorted(EXPECT_SOCKETS.get(key, set()))))
    # port rings: every chain port is the exact canonical ring, and nothing reaches past it
    ring_err = {}
    for pname in info.get("seal", ()):
        loc, R3 = info["ports"][pname]
        if pname == "in":
            err, _ = pp.ring_match(v, loc, R3, R, SIDES)
            reach = float(-(v[:, 0]).min())
        else:
            err, reach = pp.ring_match(v, loc, R3, R, SIDES)
        ring_err[pname] = (err, reach)
        if err > 2e-3:
            out.append("port %s ring off by %.4f cm" % (pname, err))
        if reach > 2e-3:
            out.append("mesh reaches %.3f cm past port %s" % (reach, pname))
    out += piece_specific(key, v, info)
    print("%-22s tris %5d/%d  size %s  parts %d  back-to-back %d  ports %s  %s" % (
        name, tris, budget, np.round(v.max(axis=0) - v.min(axis=0), 1), parts.n, len(opp),
        {k: round(e[0], 5) for k, e in ring_err.items()}, "ok" if not out else "FAIL"))
    for o in out:
        fails.append("%s: %s" % (name, o))
    return not out


def piece_specific(key, v, info):
    lo, hi = v.min(axis=0), v.max(axis=0)
    out = []

    def near(a, b, tol, what):
        if abs(a - b) > tol:
            out.append("%s %.3f != %.3f" % (what, a, b))
    if key.startswith("Pipe_"):
        L = info["extra"]["length_cm"]
        near(lo[0], 0.0, 1e-3, "x min")
        near(hi[0], L, 1e-3, "x max")
        if max(abs(lo[1]), hi[1], abs(lo[2]), hi[2]) > BAND_R + 2.5:
            out.append("section too fat")
    elif key in ("PipeFlange",):
        near(0.5 * (lo[1] + hi[1]), 0.0, 0.8, "y centre")
        near(hi[1], 33.2 + 0.3, 1.0, "plate radius")
    elif key == "PipeCollar":
        near(lo[0], -1.5, 0.05, "plate back")
    elif key == "PipeBracket":
        near(hi[1], 0.0, 1e-3, "back plane y")
    elif key == "ValveWheel_A":
        near(hi[1] - lo[1], 90.0, 2.5, "wheel diameter")
        near(0.5 * (lo[1] + hi[1]), 0.0, 0.8, "hub y")
        near(0.5 * (lo[2] + hi[2]), 0.0, 0.8, "hub z")
    elif key == "DrainGrate_A":
        near(lo[2], 0.0, 1e-3, "min z")
        if hi[2] > 1.8:
            out.append("top %.2f > 1.8 (frame 1.5, bolts flush)" % hi[2])
        near(hi[0] - lo[0], 100.0, 0.6, "length")
        near(hi[1] - lo[1], 50.0, 0.6, "width")
    elif key == "WallGrate_A":
        near(hi[1], 0.0, 1e-3, "back plane y")
        near(lo[2], 0.0, 0.05, "min z")
        near(hi[0] - lo[0], 120.0, 1.5, "width")
        near(hi[2], 90.0, 1.0, "height")
    elif key == "StoneBasin_A":
        near(lo[2], 0.0, 1e-3, "min z")
        near(0.5 * (lo[0] + hi[0]), 0.0, 1.5, "x centre")
        near(0.5 * (lo[1] + hi[1]), 0.0, 1.5, "y centre")
        near(hi[2], BASIN["cope_top"], 1.0, "rim")
    elif key.startswith("Portcullis_"):
        near(lo[2], 0.0, 1e-3, "spike tips z")
        near(hi[2], 330.0 if key.endswith("_B") else 300.0, 0.05, "top")
        near(lo[0], -120.0, 1e-3, "x min")
        near(hi[0], 120.0, 1e-3, "x max")
    elif key == "ValveGate_A":
        if lo[1] > -WHEEL_DEPTH:
            out.append("stem does not reach the wheel hub")
    return out


# ================================================================ connect metadata
def connect_json(key, info):
    ports = {n: pp.port_json(loc, R3) for n, (loc, R3) in info["ports"].items()}
    d = {"kind": info["kind"], "pipe_radius_cm": R, "ring_sides": SIDES,
         "ring_phase": "port ring vertex 0 on the port's local +Y (Unreal -Y), vertex 4 on +Z",
         "ports": ports}
    if info["kind"] in ("straight", "elbow", "tee", "valve"):
        d["rule"] = ("in = this pivot. Snap the next piece's pivot to an out port: next.world = this.world * port "
                     "(location then rotation, Unreal local frame). Rolling a piece about its own +X in 22.5 deg "
                     "steps keeps the seam closed.")
    if info["kind"] == "end":
        d["rule"] = "ends a run: snap its pivot (in) to the last out port"
    if "advance" in info:
        d["advance_cm"] = info["advance"]
    d.update(info["extra"])
    return d


# ================================================================ review: chain + scene
def chain_transforms(built):
    """The review run: wall collar -> Pipe_1m -> flange -> Pipe_50cm -> valve (+ wheel) -> elbow down -> Pipe_1m ->
    floor collar, plus a bracket on the first pipe (the valve's port joints are baked, so the flange overlay sits on
    the straight-to-straight joint before it). Returns [(key, R, t)] in Blender cm."""
    H = 150.0
    out = []
    T = (I3, np.array([0.0, 0.0, H]))

    def at(port_name, key, T, roll=0.0):
        loc, R3 = built[key][2]["ports"][port_name]
        return (T[0] @ R3, T[0] @ loc + T[1])
    out.append(("PipeCollar", T[0], T[1]))
    out.append(("Pipe_1m", T[0], T[1]))
    T = at("out", "Pipe_1m", T)
    out.append(("PipeFlange", T[0], T[1]))
    out.append(("Pipe_50cm", T[0], T[1]))
    T = at("out", "Pipe_50cm", T)
    out.append(("ValveGate_A", T[0], T[1]))
    sock = built["ValveGate_A"][2]["sockets"][0]
    out.append(("ValveWheel_A", T[0] @ pp.rot_z(sock[2][2]), T[0] @ sock[1] + T[1]))
    T = at("out", "ValveGate_A", T)
    T = (T[0] @ pp.rot_x(180.0), T[1])
    out.append(("PipeElbow90", T[0], T[1]))
    T = at("out", "PipeElbow90", T)
    out.append(("Pipe_1m", T[0], T[1]))
    T = at("out", "Pipe_1m", T)
    out.append(("PipeCollar", T[0] @ pp.rot_z(180.0), T[1]))
    out.append(("PipeBracket", I3, np.array([24.0, WALL_OFFSET, H])))
    return out


def scene_transforms(built):
    """Concept 2 corner: a broken spout out of the back wall dribbles into the stone basin; a capped pipe on brackets
    runs along the wall above; a floor drain in front, the culvert grate to the side. Returns [(key, R, t)] and the
    drip / water points (Blender cm)."""
    wall_y = 60.0
    out = []
    bas_t = np.array([0.0, wall_y - BASIN["plinth_y"] - 7.0, 0.0])      # coping clear of the collar plate
    out.append(("StoneBasin_A", I3, bas_t))
    R_out = pp.frame(-Y, Z)                                    # a run leaving the back wall toward the room
    t0 = np.array([BASIN["pour_x"], wall_y, 91.0])                # the spout over the pour notch, a ~15 cm fall
    out.append(("PipeCollar", R_out, t0))
    out.append(("PipeSpout_A", R_out, t0))
    drip = R_out @ built["PipeSpout_A"][2]["sockets"][0][1] + t0
    water = built["StoneBasin_A"][2]["sockets"][0][1] + bas_t
    # a run along the wall above: Pipe_2m (x -210..-10) on two brackets, flange + cap at its end
    axis_y = wall_y - WALL_OFFSET
    out.append(("Pipe_2m", I3, np.array([-210.0, axis_y, 215.0])))
    for x in (-185.0, -35.0):                                   # clamps clear of the lap bands (x -160, -60)
        out.append(("PipeBracket", I3, np.array([x, wall_y, 215.0])))
    out.append(("PipeCap", I3, np.array([-10.0, axis_y, 215.0])))      # a complete blind joint: no flange overlay
    out.append(("DrainGrate_A", pp.rot_z(90.0), np.array([-125.0, -45.0, 0.0])))
    out.append(("WallGrate_A", I3, np.array([-165.0, wall_y, 0.0])))
    return out, drip, water


def place_copies(built, transforms):
    objs = []
    for key, R3, t in transforms:
        objs.append(pp.copy_mesh(built[key][0], R3, t, name="_asm_%s" % key))
    return objs


def assembly_coplanar(objs, names):
    """Same-facing coplanar overlaps between DIFFERENT placed pieces -> sorted piece-name pairs; and the count of
    back-to-back pairs (pipe end caps meeting at a joint, hidden)."""
    vs, polys, island = [], [], []
    base = 0
    for i, o in enumerate(objs):
        v, p = pp.mesh_polys(o)
        vs.append(v)
        polys += [[base + j for j in f] for f in p]
        island += [i] * len(p)
        base += len(v)
    same, opp = pp.coplanar_overlaps(np.concatenate(vs), polys, island)
    pairs = sorted({tuple(sorted((names[island[a]], names[island[b]]))) for a, b in same})
    return pairs, len(opp)


def render_chain(built, fails):
    T = chain_transforms(built)
    objs = place_copies(built, T)
    names = ["%s#%d" % (k, i) for i, (k, _, _) in enumerate(T)]
    same, n_opp = assembly_coplanar(objs, names)
    if same:
        fails.append("chain: coplanar same-facing overlaps between pieces %s" % same)
    names = [k for k, _, _ in T]
    # explicit seam proof: each joint's rings coincide in the world
    seams = []
    v_by = {i: fc.verts_cm(o) for i, o in enumerate(objs)}
    joints = [(1, "out", 3), (3, "out", 4), (4, "out", 6), (6, "out", 7)]
    for a, pname, b in joints:
        loc, R3 = built[names[a]][2]["ports"][pname]
        Wloc = T[a][1] @ loc + T[a][2]
        WR = T[a][1] @ R3
        ea, _ = pp.ring_match(v_by[a], Wloc, WR, R, SIDES)
        eb, _ = pp.ring_match(v_by[b], Wloc, WR, R, SIDES)
        seams.append((names[a], names[b], round(ea, 5), round(eb, 5)))
        if ea > 2e-3 or eb > 2e-3:
            fails.append("chain seam %s -> %s open (%.4f / %.4f cm)" % (names[a], names[b], ea, eb))
    print("chain seams", seams, "same-facing", same, "back-to-back", n_opp)
    refs = [pp.painted_box("_WallA", (-15.0, -40.0, 130.0), (30.0, 220.0, 260.0), fc.srgb(118, 112, 106)),
            pp.painted_box("_WallB", (140.0, 46.0, 130.0), (340.0, 28.0, 260.0), fc.srgb(126, 120, 112)),
            pp.painted_box("_Floor", (140.0, -40.0, -10.0), (340.0, 220.0, 20.0), fc.srgb(96, 92, 88)),
            pp.painted_box("_Chef150", (90.0, -95.0, 75.0), (45.0, 30.0, 150.0), fc.srgb(226, 222, 210))]
    paths = []
    rd = spec.REVIEW_DIR
    paths.append(pp.render_view(objs + refs, os.path.join(rd, "pipes_chain_iso.png"), None, size=(1400, 1050),
                                target_cm=(135.0, 0.0, 100.0), eye_cm=(420.0, -430.0, 270.0), lens=30.0,
                                shadows=True))
    paths.append(pp.render_view(objs + refs[:3], os.path.join(rd, "pipes_chain_front.png"), (0.0, -1.0, 0.0),
                                size=(1400, 1050), target_cm=(140.0, 0.0, 105.0), half_cm=190.0))
    paths.append(pp.render_view(objs, os.path.join(rd, "pipes_chain_top.png"), (0.0, -0.001, 1.0),
                                size=(1400, 1050), target_cm=(140.0, -20.0, 100.0), half_cm=170.0))
    paths.append(pp.render_view(objs + refs, os.path.join(rd, "pipes_chain_valve.png"), None, size=(1400, 1050),
                                target_cm=(190.0, -30.0, 140.0), eye_cm=(80.0, -240.0, 210.0), lens=40.0,
                                shadows=True))
    # the 10 m read: 1920 x 1080, 90 deg horizontal FOV (lens 18 on the 36 mm sensor), eye height 1.4 m
    far = pp.render_view(objs + refs, os.path.join(rd, "pipes_chain_10m.png"), None, size=(1920, 1080),
                         target_cm=(150.0, 0.0, 110.0), eye_cm=(150.0 + 300.0, -950.0, 140.0), lens=18.0,
                         shadows=True)
    for o in objs + refs:
        pp.remove_object(o)
    layout = [{"mesh": k + "_Mars_SM", "location_cm": pp.ue_vec(t), "rotation_pyr_deg": pp.ue_rotator(R3)}
              for k, R3, t in T]
    return [pp.sheet(paths, "pipes_chain", 2), pp.sheet([far], "pipes_read10m", 1)], layout, seams


def render_scene(built, fails):
    T, drip, water = scene_transforms(built)
    objs = place_copies(built, T)
    same, _ = assembly_coplanar(objs, ["%s#%d" % (k, i) for i, (k, _, _) in enumerate(T)])
    if same:
        fails.append("scene: coplanar same-facing overlaps %s" % same)
    b = BASIN
    wv = pp.painted_box("_Water", (water[0], water[1], water[2] - 0.5), (2 * b["in_x"] + 1.0, 2 * b["in_y"] + 1.0, 1.0),
                        fc.srgb(40, 120, 190))
    fall = pp.painted_box("_DripLine", (drip[0], drip[1], 0.5 * (drip[2] + water[2])), (0.8, 0.8, drip[2] - water[2]),
                          fc.srgb(110, 200, 255))
    refs = [pp.painted_box("_Wall", (0.0, 74.0, 130.0), (420.0, 28.0, 260.0), fc.srgb(126, 120, 112)),
            pp.painted_box("_Floor", (0.0, -40.0, -10.0), (420.0, 260.0, 20.0), fc.srgb(96, 92, 88)),
            pp.painted_box("_Chef150", (165.0, -30.0, 75.0), (45.0, 30.0, 150.0), fc.srgb(226, 222, 210))]
    rd = spec.REVIEW_DIR
    p1 = pp.render_view(objs + [wv, fall] + refs, os.path.join(rd, "pipes_scene_iso.png"), None, size=(1600, 1000),
                        target_cm=(-30.0, 0.0, 80.0), eye_cm=(240.0, -420.0, 240.0), lens=28.0, shadows=True)
    p2 = pp.render_view(objs + [wv, fall] + refs, os.path.join(rd, "pipes_scene_front.png"), (0.0, -1.0, 0.0),
                        size=(1600, 1000), target_cm=(-30.0, 0.0, 100.0), half_cm=230.0)
    for o in objs + [wv, fall] + refs:
        pp.remove_object(o)
    print("scene drip %s water %s fall %.1f cm" % (np.round(drip, 2), np.round(water, 2), drip[2] - water[2]))
    if drip[2] <= water[2]:
        fails.append("scene: SOCKET_Drip below the water line")
    elif not 12.0 <= drip[2] - water[2] <= 18.0:
        fails.append("scene: drip fall %.1f cm not ~15" % (drip[2] - water[2]))
    return pp.sheet([p1, p2], "pipes_scene", 1)


def render_family_sheets(built):
    sheets = []
    groups = {}
    for p in PIECES:
        if p["key"] in built:
            groups.setdefault(p["group"], []).append(p["key"])
    rd = spec.REVIEW_DIR
    if "straights" in groups:
        keys = groups.pop("straights")
        objs = [pp.copy_mesh(built[k][0], t=(0.0, 75.0 * i, 0.0), name="_asm_" + k) for i, k in enumerate(keys)]
        ps = [pp.render_view(objs, os.path.join(rd, "pipes_straights_iso.png"), (0.55, -1.0, 0.6), size=(1800, 800)),
              pp.render_view(objs, os.path.join(rd, "pipes_straights_close.png"), None, size=(1800, 800),
                             target_cm=(60.0, 0.0, 0.0), eye_cm=(150.0, -160.0, 70.0), lens=35.0)]
        for o in objs:
            pp.remove_object(o)
        sheets.append(pp.sheet(ps, "pipes_straights", 1))
    for g, keys in groups.items():
        copies = [pp.review_copy(built[k][0]) for k in keys]
        sheets.append(ec.review(copies, "pipes_%s" % g, views=("iso", "front", "top"), size=(1800, 700), gap=1.15))
        for c in copies:
            pp.remove_object(c)
    # hero close-ups
    if "ValveGate_A" in built and "ValveWheel_A" in built:
        T = [("ValveGate_A", I3, np.zeros(3)),
             ("ValveWheel_A", pp.rot_z(-90.0), built["ValveGate_A"][2]["sockets"][0][1])]
        objs = place_copies(built, T)
        ps = [pp.render_view(objs, os.path.join(rd, "pipes_valve_close_front.png"), (0.35, -1.0, 0.3), size=(1200, 1000)),
              pp.render_view(objs, os.path.join(rd, "pipes_valve_close_side.png"), (1.0, -0.15, 0.25), size=(1200, 1000)),
              pp.render_view(objs, os.path.join(rd, "pipes_valve_close_back.png"), (-0.6, 0.6, 0.5), size=(1200, 1000))]
        for o in objs:
            pp.remove_object(o)
        sheets.append(pp.sheet(ps, "pipes_valve_close", 3))
    for gk in ("Portcullis_A", "Portcullis_B"):
        if gk not in built:
            continue
        stem = "pipes_gate_close" if gk.endswith("_A") else "pipes_gateB_close"
        tag = stem.replace("_close", "")
        chef = pp.painted_box("_Chef150", (60.0, -60.0, 75.0), (45.0, 30.0, 150.0), fc.srgb(226, 222, 210))
        frame = [pp.painted_box("_JambL", (-135.0, 0.0, 165.0), (30.0, 60.0, 330.0), fc.srgb(118, 112, 106)),
                 pp.painted_box("_JambR", (135.0, 0.0, 165.0), (30.0, 60.0, 330.0), fc.srgb(118, 112, 106))]
        if gk.endswith("_A"):
            frame.append(pp.painted_box("_Lintel", (0.0, 0.0, 315.0), (300.0, 60.0, 30.0), fc.srgb(118, 112, 106)))
        else:                                   # the kit portal's segmental arch head (voussoir blocks)
            rad, zc = portcullis_arch()
            a0 = math.asin(120.0 / rad)
            for t0, t1 in zip(np.linspace(-a0, a0, 8)[:-1], np.linspace(-a0, a0, 8)[1:]):
                tm = 0.5 * (t0 + t1)
                c = np.array([(rad + 20.0) * math.sin(tm), 0.0, zc + (rad + 20.0) * math.cos(tm)])
                frame.append(pp.painted_box("_Vous", c, (2 * (rad + 20) * math.sin(0.5 * (t1 - t0)) - 1.0, 60.0, 40.0),
                                            fc.srgb(118, 112, 106), R=pp.rot_y(math.degrees(tm))))
        o = pp.copy_mesh(built[gk][0], name="_asm_" + gk)
        ps = [pp.render_view([o, chef] + frame, os.path.join(rd, tag + "_front.png"), (0.0, -1.0, 0.0),
                             size=(1000, 1100)),
              pp.render_view([o, chef], os.path.join(rd, tag + "_iso.png"), None, size=(1000, 1100),
                             target_cm=(0.0, 0.0, 120.0), eye_cm=(260.0, -380.0, 120.0), lens=35.0, shadows=True),
              pp.render_view([o], os.path.join(rd, tag + "_spikes.png"), None, size=(1000, 1100),
                             target_cm=(40.0, 0.0, 40.0), eye_cm=(140.0, -170.0, 30.0), lens=40.0)]
        for x in [o, chef] + frame:
            pp.remove_object(x)
        sheets.append(pp.sheet(ps, stem, 3))
    if "PipeTee" in built and "PipeElbow90" in built:
        T = [("PipeTee", I3, np.zeros(3)), ("PipeElbow90", I3, np.array([130.0, 0.0, 0.0])),
             ("PipeCap", I3, np.array([260.0, 0.0, 0.0])), ("PipeSpout_A", I3, np.array([340.0, 0.0, 0.0]))]
        objs = place_copies(built, T)
        ps = [pp.render_view(objs, os.path.join(rd, "pipes_fittings_close_iso.png"), None, size=(1800, 800),
                             target_cm=(200.0, 0.0, 20.0), eye_cm=(330.0, -420.0, 230.0), lens=35.0, shadows=True),
              pp.render_view(objs, os.path.join(rd, "pipes_fittings_close_front.png"), (0.0, -1.0, 0.0),
                             size=(1800, 800))]
        for o in objs:
            pp.remove_object(o)
        sheets.append(pp.sheet(ps, "pipes_fittings_close", 1))
    if "PipeSpout_A" in built:
        o = pp.copy_mesh(built["PipeSpout_A"][0], name="_asm_Spout")
        ps = [pp.render_view([o], os.path.join(rd, "pipes_spout_close_iso.png"), None, size=(1000, 900),
                             target_cm=(35.0, 0.0, -2.0), eye_cm=(150.0, -110.0, 75.0), lens=40.0, shadows=True),
              pp.render_view([o], os.path.join(rd, "pipes_spout_close_side.png"), (0.0, -1.0, 0.0), size=(1000, 900)),
              pp.render_view([o], os.path.join(rd, "pipes_spout_close_mouth.png"), None, size=(1000, 900),
                             target_cm=(40.0, 0.0, 0.0), eye_cm=(160.0, -40.0, 30.0), lens=40.0, shadows=True)]
        pp.remove_object(o)
        sheets.append(pp.sheet(ps, "pipes_spout_close", 3))
    if "StoneBasin_A" in built:
        o = pp.copy_mesh(built["StoneBasin_A"][0], name="_asm_Basin")
        ps = [pp.render_view([o], os.path.join(rd, "pipes_basin_close_iso.png"), None, size=(1300, 900),
                             target_cm=(0.0, 0.0, 25.0), eye_cm=(130.0, -200.0, 170.0), lens=35.0, shadows=True),
              pp.render_view([o], os.path.join(rd, "pipes_basin_close_low.png"), None, size=(1300, 900),
                             target_cm=(-40.0, 0.0, 30.0), eye_cm=(20.0, -190.0, 60.0), lens=35.0)]
        pp.remove_object(o)
        sheets.append(pp.sheet(ps, "pipes_basin_close", 2))
    return sheets


# ================================================================ reimport
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
        if sorted(s.split(".")[0] for s in r["slots"] if s) != sorted(meta["slots"]):
            problems.append("slots %s != %s" % (r["slots"], meta["slots"]))
    if len(ucx) != want_ucx or meta["ucx_pieces"] != want_ucx or meta["ucx_problems"]:
        problems.append("ucx reimported %d / sidecar %d / want %d %s" % (len(ucx), meta["ucx_pieces"], want_ucx,
                                                                         meta["ucx_problems"]))
    if set(meta["sockets"]) != set(want_sockets):
        problems.append("sockets %s != %s" % (sorted(meta["sockets"]), sorted(want_sockets)))
    if "connect" not in meta:
        problems.append("no connect block")
    print("REIMPORT %-24s ucx %d sockets %s %s" % (stem, len(ucx), sorted(meta["sockets"]),
                                                   "ok" if not problems else "FAIL " + "; ".join(problems)))
    if problems:
        fails.append("%s reimport: %s" % (stem, "; ".join(problems)))
    return meta


# ================================================================ main
def main():
    args = fc.cli_args({"export": False, "save": False, "sheets": False, "only": ""})
    t0 = time.time()
    fc.ensure_dirs()
    fc.clear_scene()
    bpy.context.scene.view_settings.view_transform = "Standard"
    only = str(args["only"]) if args["only"] else ""
    fails = []
    built = {}
    for p in PIECES:
        key = p["key"]
        if only and only.lower() not in key.lower():
            continue
        t1 = time.time()
        parts, info = p["build"]()
        obj = parts.build()
        paint_piece(obj, parts, seed=sum(map(ord, key)) % 997, key=key)
        fc.smart_uv(obj)
        for sname, loc, rot in info.get("sockets", ()):
            sc.add_socket(obj, sname, loc, rot)
        for hull in info["ucx"]:
            sc.add_ucx(obj, hull)
        ok = check_piece(key, obj, parts, info, fails)
        built[key] = (obj, parts, info, ok)
        print("   built %s in %.1fs" % (key, time.time() - t1))

    exported = {}
    connect_all = {}
    if args["export"]:
        for key, (obj, parts, info, ok) in built.items():
            cat = next(p["cat"] for p in PIECES if p["key"] == key)
            con = connect_json(key, info)
            connect_all[obj.name] = con
            if not ok:
                print("  NOT exported (checks failed): %s" % key)
                continue
            extra = {"category": cat, "tris_budget": spec.TRIS[cat], "builder": "build_env_pipes.py",
                     "connect": con, "collision": UCX_NOTE if not info["ucx"] else "%d convex UCX" % len(info["ucx"])}
            exported[key] = ec.export(obj, FAMILY, extra=extra)

    sheets, layout, seams = [], None, None
    if args["sheets"]:
        sheets += render_family_sheets({k: (v[0], v[1], v[2]) for k, v in built.items()})
        need = {"PipeCollar", "Pipe_1m", "Pipe_50cm", "PipeFlange", "ValveGate_A", "ValveWheel_A", "PipeElbow90", "PipeBracket"}
        b3 = {k: (v[0], v[1], v[2]) for k, v in built.items()}
        if need <= set(built):
            s, layout, seams = render_chain(b3, fails)
            sheets += s
        if {"StoneBasin_A", "PipeCollar", "PipeSpout_A", "Pipe_2m", "PipeBracket", "PipeFlange", "PipeCap",
                "DrainGrate_A", "WallGrate_A"} <= set(built):
            sheets.append(render_scene(b3, fails))
        for m in list(bpy.data.materials):
            if m.users == 0:
                bpy.data.materials.remove(m)
    if args["export"] and connect_all:
        data = {"family": FAMILY, "frame": "Unreal local cm (Blender y mirrored); rotations are FRotator "
                                           "(pitch, yaw, roll) degrees",
                "rule": "next.world = this.world * port; overlays (flange, collar) take a port frame unchanged",
                "pieces": connect_all}
        if layout:
            data["review_chain"] = {"order": "wall collar -> Pipe_1m -> flange -> valve (+ wheel on SOCKET_Wheel) -> "
                                             "elbow rolled 180 (down) -> Pipe_1m -> floor collar (yaw 180); "
                                             "bracket on the first pipe",
                                    "pieces": layout,
                                    "seams_max_err_cm": seams}
        print("connect json", sc.layout_json("Pipes_Connect", data))
    if args["save"]:
        ec.save_family_blend(FAMILY)
        print("saved", os.path.join(spec.BLEND_DIR, spec.FAMILIES[FAMILY][1]))
    for key, path in exported.items():
        info = built[key][2]
        reimport(path, len(info["ucx"]), EXPECT_SOCKETS.get(key, set()), fails)
    print("\nsheets:", *sheets, sep="\n  ")
    print("total %.1fs" % (time.time() - t0))
    if fails:
        print("ENV_PIPES_FAIL", *fails, sep="\n  ")
    elif only:
        print("ENV_PIPES_PARTIAL (only %r)" % only)
    else:
        print("ENV_PIPES_OK")


main()
