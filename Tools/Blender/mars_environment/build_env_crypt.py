"""Mars environment dressing kit, family "crypt" (ENV_KIT.md): the carved stone furniture of the six crypt concept frames.

Builds from fixed seeds, Blender 5.2 headless, slots EnvStone / EnvStoneDark / EnvGlowSpirit / EnvIron:
  Sarcophagus_A      concept 6: 240 x 120 x 130 on a two-step plinth of jointed stones (square joint ends, never chipped,
                     dark mortar fins cut 0.5 cm behind the stones' bottom chamfers, ray-cast checked for see-through
                     from the faces, 3 cm either side of each joint and from below at 30 degrees), framed chest with
                     corner posts, a 13 cm lid slab turned 9 degrees and slid 10 cm along +x and 6 cm toward the viewer
                     (one corner overhangs the cornice, the dark seating course in the chest mouth shows on the far
                     side); both long sides carry the relief (two hooded figures kneeling toward a sword-and-fleur:
                     cloak with tapered wedge folds, hood bowed 15 degrees, a lit face profile under a dark shadow
                     sliver, sleeve, two pressed palms with a V notch; the fleur is three solid teardrop petals over a
                     collar band), the ends are framed panels with a lozenge boss. SOCKET_LidEdge (a ledge-candle
                     snap point on the lid's front arris near the overhang). UCX.
  HoodedStatue_A     praying hooded mourner, 1.93 m on a 64 x 44 plinth: lofted robe with deep folds and a flared hem, a
                     belled capelet, an oval cowl lined in EnvStoneDark (one rule: every face touching the opening
                     above z 160) with a lit faceted face set in it, palms. Fitted inside 44 cm of depth. UCX.
  HoodedStatue_B     head bowed 18 degrees, hands on the pommel of a broadsword stood point-down in front. UCX.
  StatueNiche_A      pointed-arch wall niche 120 W x 280 H x 50 D: sill, coursed pilasters, imposts, voussoirs and a
                     tapered keystone, spandrels with crosses, a cornice; SOCKET_Statue on the niche floor. UCX
                     (sill, jambs, head; the recess stays open).
  CandleNiche_A      gothic recess 60 W x 90 H: a surround following the pointed arch on a 20 cm base stone, impost
                     blocks on the jambs at the springing, a candle ledge on one tapered corbel (34 -> 16 cm, nothing
                     below the frame); SOCKET_Candle mid-ledge, SOCKET_LedgeEdge on the ledge's front top edge. The
                     soot is a ragged flame tongue rising into the apex and wrapping the upper arch soffits.
  Urn_A / Urn_B / Urn_C / UrnBroken_A      faceted hand-turned lathe vessels (tall vase, squat amphora with handles,
                     lidded jar with an iron band, a broken base with one tall shard and a low side, five curved shell
                     shards spilled toward the low side, its neck).
  SigilDoor_A        concept 3: one quiet stone door panel inside a 9 cm border band recessed 5 cm, in an arched frame,
                     300 W x 450 H; the sigil (ring, two crescents, a bar running into the spear-diamond below, a
                     diamond and two flame teardrops above) is carved 4.5 cm deep and every groove floor is an
                     EnvGlowSpirit face; no joint crosses the glyph. UCX.
  FloorMedallion_A   concept 3: 4 m round inlay 3 cm proud: quartered border, a light ring, a dark field laid as a
                     regular 45-degree grid (~42 cm cells, square to the diamond, merged at the ring so no slivers), a
                     broad light diamond band round a dark diamond with a light centre, light cells at the cardinals.
  Rubble_A / Rubble_B / Rubble_C           broken masonry heap (squared blocks with fracture planes, chips), a
                     fallen ashlar (corner knocked off, a bite out of one arris, sunk 10 degrees, its corner leaning on
                     it), one fan-shaped spill of chips.
  Plinth_A           a chiselled pedestal for urns and lanterns: tapered octagonal shaft, step moulding, 2-4 cm chips
                     (SOCKET_Top). UCX.

Run (always absolute paths):
  "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup --python
      D:\\Repo\\Mars\\Tools\\Blender\\mars_environment\\build_env_crypt.py -- [--export] [--sheets] [--save] [--only <part>]
Prints ENV_CRYPT_OK when every check passed (ENV_CRYPT_FAIL + the reasons otherwise).

Frames: centimetres, Blender axes, Z up; wall pieces have their back plane at y = 0 and face -Y (Unreal +Y).
"""
import json
import math
import zlib
import os
import sys
import time

import bpy
import numpy as np
from mathutils import Vector, geometry

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import env_common as ec          # noqa: E402
import env_crypt_parts as cp     # noqa: E402

fc, sc, spec = ec.fc, ec.sc, ec.spec
FAMILY = "crypt"
X, Y, Z = cp.X, cp.Y, cp.Z

# ---------------------------------------------------------------- palette (linear)
STONE = ec.palette("EnvStone")
STONE_D = ec.palette("EnvStoneDark")
STONE_L = np.clip(STONE * 1.32, 0.0, 1.0)          # env_spec has no EnvStoneLight: the lit chiselled faces
IRON = ec.palette("EnvIron")
IRON_L = ec.palette("EnvIronLight")
GLOW = ec.palette("EnvGlowSpirit")

KIND = {
    "stone": STONE, "light": STONE_L * 1.04, "dark": STONE_D * 0.88, "mid": cp.lerp(STONE, STONE_D, 0.35),
    "fig": cp.lerp(STONE, STONE_L, 0.4), "hood": cp.lerp(STONE, STONE_L, 0.3), "recess": STONE_D * 0.42,
    "darkfield": STONE_D * 0.95,
    "face": STONE_D * 0.78, "groove": STONE_D * 0.62, "mouth": STONE_D * 0.36, "field": cp.lerp(STONE, STONE_D, 0.3),
    "iron": IRON, "ironl": IRON_L, "glow": GLOW,
}
SUB = {
    "top": 1.06, "chamfer": 1.13, "chip": 0.84, "side": 1.0, "bottom": 0.7, "chamfer0": 0.9,
    "rtop": 1.05, "rbevel": 1.13, "rside": 0.9, "rbottom": 0.7, "under": 0.86, "": 1.0,
}


def stone_painter(seed, tone_range=(0.9, 1.1), shade=0.1):
    """Colour per triangle from its "kind/sub" tag: kind base x sub multiplier x a per-group tone x a light-from-above
    value (top faces lighter, undersides darker: the hand-painted look of the concept frames)."""
    rng = np.random.default_rng(seed)
    tones = {}

    def fn(tag, group, c, n):
        kind, _, sub = tag.partition("/")
        if group not in tones:
            tones[group] = rng.uniform(*tone_range)
        base = KIND[kind]
        if kind == "glow":
            return base
        return base * SUB.get(sub, 1.0) * tones[group] * (1.0 + shade * float(n[2]))

    return fn


def ktags(kind, tags):
    return ["%s/%s" % (kind, t) for t in tags]


def add_block(P, outline, w0, w1, frame, rng, kind="stone", origin=(0.0, 0.0, 0.0), slot="EnvStone", group=None, **kw):
    v, f, t = cp.chisel_prism(outline, w0, w1, rng, **kw)
    return P.add_local(v, f, frame, origin, slot, ktags(kind, t), group)


def add_relief(P, outline, w0, h, frame, rng, kind="fig", origin=(0.0, 0.0, 0.0), group=None, **kw):
    v, f, t = cp.relief_layer(outline, w0, h, rng, **kw)
    return P.add_local(v, f, frame, origin, "EnvStone", ktags(kind, t), group)


def rect(u0, v0, u1, v1):
    return np.array([(u0, v0), (u1, v0), (u1, v1), (u0, v1)], float)


# kinds whose faces wear the EnvStoneDark slot: the stone master ignores vertex colour, so a recess back, a groove wall,
# the soot / shadow round a hood's brow, mortar and the dark inlay stones only read dark through the slot (faces are
# never dark: they are lit stone, "fig")
DARK_KINDS = ("dark", "recess", "mouth", "groove", "darkfield")


def build(P, name):
    """Parts.build after moving every EnvStone face of a DARK_KINDS tag onto EnvStoneDark (the slot is added only when
    a face uses it, so no mesh carries an unused slot)."""
    if "EnvStone" in P.slots:
        si = P.slots.index("EnvStone")
        dark = [i for i, (s, t) in enumerate(zip(P.slot, P.tag)) if s == si and t.partition("/")[0] in DARK_KINDS]
        if dark:
            if "EnvStoneDark" not in P.slots:
                P.slots = P.slots + ("EnvStoneDark",)
            di = P.slots.index("EnvStoneDark")
            for i in dark:
                P.slot[i] = di
    return P.build(name)


# ================================================================ Sarcophagus_A
JOINTS = {}               # mesh name -> [(axis, position, depth, a0, a1, sides)] checked by joint_ray_report
SARC_W, SARC_D = 240.0, 120.0
FIELD_Y = 32.0           # the carved long fields sit 10 cm behind the posts and rails (y = +-42)
FIELD_X = 94.0           # the end fields, 10 cm behind the end rails (x = +-104)
FIELD_V0, FIELD_V1 = 35.0, 93.0
Z_CORNICE = 107.0        # cornice top
Z_SEAT = 109.0           # top of the dark seating course under the lid (the lid's shadow line)
Z_LID = 122.0            # top of the 13 cm lid slab
SARC_H = 130.0           # ridge of the hipped lid top
LID_YAW = 9.0
LID_SHIFT = np.array([10.0, -6.0])        # slid toward +x and the viewer: one corner clearly overhangs the cornice
LID_HALF = (100.0, 44.0)
CORNICE_HALF = (107.0, 49.0)
# jointed courses: (block x ranges, half depth y, z0, z1, bottom chamfer) - the joints are closed by mortar fins
PLINTH_COURSES = (
    (((-120, -63), (-63, 1), (1, 57), (57, 120)), 60.0, 0.0, 11.0, 0.0),
    (((-112, -38), (-38, 36), (36, 112)), 52.0, 11.0, 22.0, 0.0),
)
CORNICE_COURSE = (((-107, -37), (-37, 35), (35, 107)), 49.0, 99.0, Z_CORNICE, 2.6)

# a hooded figure kneeling toward +u (cm, base v = 0): (name, outline, height above the field, bevel, kind)
FIGURE_BODY = [
    ("body", [(-22, 0), (19, 0), (21.6, 1.8), (22.2, 5.6), (20.2, 9.4), (15, 11.6), (11, 13.6), (10.6, 20), (10, 26),
              (8.6, 33), (8.6, 38), (9.5, 42), (9, 47), (4, 51), (-1, 50.5), (-5, 45.5), (-8.6, 40), (-11.5, 34),
              (-13, 31), (-15.5, 20), (-18.5, 10), (-22.5, 3.5)], 5.5, 1.4, "fig"),
    # robe folds: tapered wedges, wide at the hem and pinched toward the knee / hip, bevelled into the robe (their top
    # sinks back to the robe surface toward the narrow end: see FOLD_SINK)
    ("fold_back", [(-17.0, 2.0), (-10.6, 2.0), (-8.6, 26.0), (-10.4, 26.4)], 6.4, 0.7, "fig"),
    ("fold_mid", [(-7.4, 1.0), (-2.8, 1.0), (-2.0, 17.0), (-3.6, 17.4)], 6.3, 0.6, "fig"),
    ("fold_knee", [(5.0, 7.0), (19.6, 4.6), (19.4, 8.8), (6.2, 9.4)], 6.4, 0.6, "fig"),
    ("sleeve", [(-4, 31), (0.5, 23), (5, 19.5), (12.5, 21.2), (15.2, 23.4), (13.6, 28.6), (8, 28.2), (4.6, 31),
                (1.5, 34)], 9.0, 1.3, "hood"),
    # two palms pressed together, fingertips tilted 15 degrees further up than before, a 1 cm V notch between the tips:
    # the far palm sits lower in the relief and a little back, the near palm proud of it
    ("palm_far", [(12.0, 23.2), (14.6, 22.2), (17.4, 27.6), (18.4, 31.8), (17.0, 32.2), (15.0, 29.6), (12.4, 27.4)],
     9.6, 0.5, "fig"),
    ("palm_near", [(13.4, 22.6), (15.6, 22.0), (19.6, 27.0), (21.6, 31.4), (20.2, 32.2), (17.6, 29.4), (14.2, 27.2)],
     10.6, 0.5, "fig"),
]
# the head, drawn upright and then bowed 15 degrees toward the sword about the neck: the hood, a 1 cm shadow sliver
# along the hood's inner edge (set low, between hood and face) and the lit face profile (brow, nose, lips, chin)
# standing just under the hood rim
FIGURE_HEAD = [
    ("hood", [(-9, 29), (3, 31), (7.5, 35), (10.2, 38.4), (7.8, 40.2), (7.4, 44), (9.6, 46.2), (13.6, 46.6),
              (11.6, 50.6), (6, 54.2), (-1.5, 54.4), (-6.6, 51.2), (-9.6, 45.2), (-11.6, 38), (-12.6, 31.2)],
     8.6, 1.6, "hood"),
    ("shadow", [(9.6, 37.9), (7.0, 39.9), (6.6, 44.3), (9.3, 47.0), (13.4, 47.3), (12.4, 45.9), (9.6, 45.3),
                (9.3, 44.0), (9.3, 40.4), (10.4, 39.2)], 6.4, 0.25, "dark"),
    ("face", [(8.6, 39.8), (10.6, 39.0), (11.9, 40.1), (12.0, 41.4), (12.9, 42.8), (12.1, 44.6), (11.2, 45.7),
              (8.8, 45.6)], 7.6, 0.45, "fig"),
]
HEAD_BOW = (15.0, (0.0, 31.0))
PALM_TILT, PALM_WRIST = 12.0, (14.0, 23.0)      # the palms turn about the wrist so the fingertips point ~70 deg up
SWORD = [   # (name, outline, height above the field, bevel); drawn in this order, each layer a little higher in the stack
    ("pedestal", [(-7.5, 0), (7.5, 0), (6.2, 4.2), (-6.2, 4.2)], 3.6, 0.6),
    ("guard", [(-12, 24.0), (12, 24.0), (13.6, 25.8), (12, 27.6), (-12, 27.6), (-13.6, 25.8)], 4.6, 0.8),
    ("grip", [(-1.7, 27.3), (1.7, 27.3), (1.4, 32.4), (-1.4, 32.4)], 3.3, 0.4),
    # the fleur: three solid teardrop wedges 3 cm proud (a broad centre petal 9 x 21 cm, side petals ~7 cm wide curling
    # down and out to pointed tips) bound by a collar band over their roots; about a third of the figures' height
    ("petal_c", [(-2.6, 34.4), (2.6, 34.4), (4.0, 38.0), (4.6, 42.5), (4.0, 47.0), (2.4, 51.2), (0.0, 55.4),
                 (-2.4, 51.2), (-4.0, 47.0), (-4.6, 42.5), (-4.0, 38.0)], 3.0, 0.6),
    ("petal_l", [(-3.0, 33.4), (-4.4, 37.6), (-6.4, 41.6), (-9.0, 44.0), (-12.0, 44.4), (-14.4, 42.4), (-15.4, 39.0),
                 (-14.8, 35.4), (-13.6, 37.0), (-11.6, 37.8), (-9.6, 37.0), (-7.8, 34.6), (-6.0, 32.2)], 3.0, 0.6),
    ("band", [(-6.0, 31.8), (6.0, 31.8), (6.6, 33.4), (6.0, 35.0), (-6.0, 35.0), (-6.6, 33.4)], 3.7, 0.6),
]
SWORD_BLADE = (5.2, 24.4)    # the blade runs point down from the guard into the pedestal


def rot2(p, deg, about):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    q = np.asarray(p, float) - np.asarray(about, float)
    return np.column_stack([q[:, 0] * c - q[:, 1] * s, q[:, 0] * s + q[:, 1] * c]) + np.asarray(about, float)


def figure_relief(P, frame, w_field, u_off, facing, rng):
    """One kneeling figure on a carved field: every layer rises from just under the field (staggered so no two
    hidden bottoms are coplanar) to its own height. The head layers are bowed toward the sword."""
    g = P.new_group()
    deg, piv = HEAD_BOW
    layers = [(n, rot2(o, PALM_TILT, PALM_WRIST) if n.startswith("palm") else np.array(o, float), h, b, k)
              for n, o, h, b, k in FIGURE_BODY]
    layers += [(n, rot2(o, -deg, piv), h, b, k) for n, o, h, b, k in FIGURE_HEAD]
    for k, (name, o, h, bevel, kind) in enumerate(layers):
        if facing < 0:
            o = cp.mirror_u(o)
        o = o + np.array([u_off, FIELD_V0])
        w0 = w_field - 0.35 * (k + 1)
        lift = None
        if name.startswith("fold"):
            # a wedge fold: proud at its wide end (the hem / the knee), sinking back into the robe toward its pinch
            if name == "fold_knee":
                a = facing * o[:, 0]
                lo_, hi_ = float(a.min()), float(a.max())
                lift = lambda u, v, lo_=lo_, hi_=hi_: -0.85 * (hi_ - facing * u) / (hi_ - lo_)
            else:
                lo_, hi_ = float(o[:, 1].min()), float(o[:, 1].max())
                lift = lambda u, v, lo_=lo_, hi_=hi_: -0.9 * (v - lo_) / (hi_ - lo_)
        if name == "face":
            # the cheek plane falls from under the hood (7.6 cm) toward the profile edge (~5.8 cm at the nose), so an
            # oblique view sees a lit sloping cheek instead of the profile's side walls
            ub = float((facing * o[:, 0]).min()) + 1.0
            lift = lambda u, v, ub=ub: -0.55 * max(0.0, facing * u - ub)
        add_relief(P, o, w0, h + (w_field - w0), frame, rng, kind=kind, group=g, bevel=bevel,
                   jitter=0.1 if name in ("face", "shadow") else 0.22, lift=lift)


def sword_relief(P, frame, w_field, rng):
    g = P.new_group()
    k = 0
    for name, outline, h, bevel in SWORD:
        o = np.array(outline, float) + np.array([0.0, FIELD_V0])
        outs = [o, cp.mirror_u(o)] if name == "petal_l" else [o]
        for oo in outs:
            k += 1
            w0 = w_field - 0.35 * k
            lift = None
            if name == "petal_c":
                # a ridged petal: its flanks fall 1 cm toward the edges so the face breaks into two chiselled planes
                lift = lambda u, v: -0.25 * abs(u)
            add_relief(P, oo, w0, h + (w_field - w0), frame, rng, kind="fig", group=g, bevel=bevel, jitter=0.15,
                       lift=lift)
    # the blade: a ridged bar, point down into the pedestal
    k += 1
    w0 = w_field - 0.35 * k
    v, f = cp.ridge_bar(FIELD_V0 + SWORD_BLADE[0], FIELD_V0 + SWORD_BLADE[1], 0.9, 2.7, w0, 2.2 + (w_field - w0), 2.6 + (w_field - w0),
                        3.6 + (w_field - w0), 4.0 + (w_field - w0), nseg=2, tip=True)
    P.add_local(v, f, frame, (0, 0, 0), "EnvStone", "fig/rtop", g)


def end_panel_relief(P, frame, w_field, rng):
    g = P.new_group()
    bars = [rect(-18, FIELD_V0 + 3.5, 18, FIELD_V0 + 6.5), rect(-18, FIELD_V1 - 6.5, 18, FIELD_V1 - 3.5),
            rect(-18, FIELD_V0 + 6.5, -15, FIELD_V1 - 6.5), rect(15, FIELD_V0 + 6.5, 18, FIELD_V1 - 6.5)]
    for k, b in enumerate(bars):
        w0 = w_field - 0.35 * (k + 1)
        add_relief(P, b, w0, 2.6 + (w_field - w0), frame, rng, kind="fig", group=g, bevel=0.6, jitter=0.12)
    vc = 0.5 * (FIELD_V0 + FIELD_V1)
    boss = np.array([(0, vc - 15), (10, vc), (0, vc + 15), (-10, vc)])
    w0 = w_field - 0.35 * 5
    add_relief(P, boss, w0, 3.6 + (w_field - w0), frame, rng, kind="fig", group=g, bevel=3.2, jitter=0.2)
    cross = [rect(-1.2, vc - 6, 1.2, vc + 6), rect(-4.2, vc + 0.6, 4.2, vc + 3.0)]
    for k, c in enumerate(cross):
        w0 = w_field + 3.0 - 0.35 * (k + 1)
        add_relief(P, c, w0, 1.6 + (w_field + 3.0 - w0), frame, rng, kind="fig", group=g, bevel=0.4, jitter=0.08)


def joint_fin(P, x_j, y_half, z0, z1, ch_top=2.0, ch_bot=0.0):
    """Dark mortar filling the 4 mm joint between two stones of a course (wall to wall), from face to face (0.1 cm behind the outer
    faces) and from bottom to top (0.05 cm in), with its corners cut under the stones' chamfers so it never shows
    proud of them: no joint can be seen through."""
    yf = y_half - 0.2 - 0.1
    # under a bottom chamfer the fin is cut 0.5 cm behind the chamfer plane (it can never stand proud in the V the two
    # stones' chamfers make at the joint)
    cb = ch_bot + 0.7
    prof = [(-yf, z0 + 0.05), (yf, z0 + 0.05)] if ch_bot <= 0 else \
        [(-(yf - cb), z0 + 0.05), (yf - cb, z0 + 0.05), (yf, z0 + cb)]
    prof += [(yf, z1 - ch_top), (yf - ch_top + 0.1, z1 - 0.05), (-(yf - ch_top + 0.1), z1 - 0.05), (-yf, z1 - ch_top)]
    if ch_bot > 0:
        prof.append((-yf, z0 + cb))
    v, f = cp.prism2d(np.array(prof), x_j - 0.2, x_j + 0.2)
    P.add_local(v, f, "east", (0.0, 0.0, 0.0), "EnvStone", "dark/side")


def course(P, rng, spans, y_half, z0, z1, ch0, **kw):
    """A course of separately cut stones: chamfered on the outer faces, square on the joint-facing ends (a V notch
    there would open the joint through the course), with a mortar fin in every joint."""
    xs = [s[0] for s in spans] + [spans[-1][1]]
    for i, (x0, x1) in enumerate(spans):
        mask = (1.0, 0.0 if i < len(spans) - 1 else 1.0, 1.0, 0.0 if i > 0 else 1.0)
        add_block(P, rect(x0, -y_half, x1, y_half), z0, z1, "up", rng, flat_top=True, joint=0.2, ch0=ch0,
                  edge_mask=mask, **kw)
    for x_j in xs[1:-1]:
        joint_fin(P, x_j, y_half, z0, z1, ch_top=2.0, ch_bot=ch0)
    return [("x", x_j, y_half, z0, z1, (-1.0, 1.0), ch0 > 0) for x_j in xs[1:-1]]


def lid_outline(hx, hy):
    o = rect(-hx, -hy, hx, hy)
    return cp.rot_z(np.column_stack([o, np.zeros(4)]), LID_YAW)[:, :2] + LID_SHIFT


def clip_to_rect(poly, x0, y0, x1, y1):
    r = rect(x0, y0, x1, y1)
    out = np.asarray(poly, float)
    for i in range(4):
        out = cp.clip_half(out, r[i], r[(i + 1) % 4], True)
    return out


def build_sarcophagus():
    rng = np.random.default_rng(101)
    P = cp.Parts(("EnvStone",))
    joints = []
    # plinth: two steps of separately cut blocks, mortar in the joints; the chest's foot moulding
    joints += course(P, rng, *PLINTH_COURSES[0], ch=(0.8, 1.6), chip_p=0.5)
    joints += course(P, rng, *PLINTH_COURSES[1], ch=(0.8, 1.5), chip_p=0.5)
    add_block(P, rect(-106, -46, 106, 46), 22, 29, "up", rng, flat_top=True, ch=(2.0, 2.6), ch_h=2.2, chip_p=0.3)
    # chest core: a cross so the corner posts and the end / long rails sit in its notches (no hidden overlaps)
    fy, fx = FIELD_Y, FIELD_X
    # (three convex blocks: a cross outline tessellates its caps into a zero-area sliver along the collinear notch edges)
    for core in (rect(-84, -fy, 84, fy), rect(84, -22, fx, 22), rect(-fx, -22, -84, 22)):
        add_block(P, core, 29, 99, "up", rng, kind="field", flat_top=True, ch=0.3, chip_p=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            xs = sorted((sx * 84, sx * 104))
            ys = sorted((sy * 22, sy * 42))
            add_block(P, rect(xs[0], ys[0], xs[1], ys[1]), 29, 99, "up", rng, flat_top=True, ch=(0.6, 1.0),
                      chip_p=0.85, chip_cm=(1.2, 2.4))
    for z0, z1 in ((29, 35), (93, 99)):
        for fr in ("front", "back"):
            add_block(P, rect(-84, z0, 84, z1), fy, 42, fr, rng, ch=(0.7, 1.2), chip_p=0.4)
        for fr in ("east", "west"):
            add_block(P, rect(-22, z0, 22, z1), fx, 104, fr, rng, ch=(0.7, 1.2), chip_p=0.4)
    # cornice (three stones, coved underside), the dark seating course and the lid: a thick slab and a hipped top,
    # pushed askew so one corner overhangs the cornice and the far corner bares its top
    joints += course(P, rng, *CORNICE_COURSE, ch=(0.8, 1.3), chip_p=0.4)
    cx, cy = CORNICE_HALF
    hx, hy = LID_HALF
    # the dark seating course fills the chest mouth inside a 6 cm cornice rim: where the slid lid leaves it (the far
    # side and the -x end) it reads as the dark gap of a disturbed lid
    seat = rect(-cx + 6.0, -cy + 6.0, cx - 6.0, cy - 6.0)
    add_block(P, seat, Z_CORNICE - 0.5, Z_SEAT, "up", rng, kind="dark", flat_top=True, ch=0.3, chip_p=0.0)
    add_block(P, lid_outline(hx, hy), Z_SEAT, Z_LID, "up", rng, flat_top=True, ch=(1.0, 1.8), ch0=1.2, chip_p=0.7,
              chip_cm=(1.5, 3.5))
    add_block(P, lid_outline(hx - 8.0, hy - 8.0), Z_LID, SARC_H, "up", rng, kind="light", ch=(30.0, 34.0), ch_h=6.8,
              chip_p=0.0, drop_p=0.25, drop_cm=(0.4, 1.2), jitter=0.3, dip=(0.1, 0.5))
    # the reliefs: both long sides, figures kneeling toward the sword; framed panels on the ends
    for fr in ("front", "back"):
        figure_relief(P, fr, fy, -47.0, +1, rng)
        figure_relief(P, fr, fy, 47.0, -1, rng)
        sword_relief(P, fr, fy, rng)
    for fr in ("east", "west"):
        end_panel_relief(P, fr, fx, rng)
    obj = build(P, "Sarcophagus_A_Mars_SM")
    JOINTS["Sarcophagus_A"] = joints
    # SOCKET_LidEdge (a candle socket; named apart from CandleNiche_A's SOCKET_Candle because socket empties share one
    # .blend namespace): the lid's front top arris, 12 cm in from its overhanging (+x) end, yawed with the lid, so a
    # CandleLedge (edge at y = 0, z = 0, ledge top toward +y) snaps on with its wax running down the lid's front face
    sk = cp.rot_z(np.array([(hx - 12.0, -hy, 0.0)]), LID_YAW)[0, :2] + LID_SHIFT
    sc.add_socket(obj, "LidEdge", (float(sk[0]), float(sk[1]), Z_LID), (0.0, 0.0, LID_YAW))
    # collision: plinth steps, foot, chest, cornice, lid slab, lid top
    sc.box_ucx(obj, (0, 0, 5.5), (240, 120, 11))
    sc.box_ucx(obj, (0, 0, 16.5), (224, 104, 11))
    sc.box_ucx(obj, (0, 0, 25.5), (212, 92, 7))
    sc.box_ucx(obj, (0, 0, 64.0), (208, 84, 70))
    sc.box_ucx(obj, (0, 0, 103.0), (214, 98, 8))
    lid = np.concatenate([np.column_stack([lid_outline(hx, hy), np.full(4, z)]) for z in (Z_CORNICE, Z_LID)])
    sc.add_ucx(obj, lid)
    top = np.concatenate([np.column_stack([lid_outline(hx - 8.0, hy - 8.0), np.full(4, Z_LID)]),
                          np.column_stack([lid_outline(hx - 38.0, 6.0), np.full(4, SARC_H)])])
    sc.add_ucx(obj, top)
    return obj, P


def joint_ray_report(obj, joints):
    """Ray-cast through every mortar joint: (axis, position, depth, a0, a1, sides). An "x" joint is a vertical joint at
    x = position through a course of half depth `depth` from z a0 to a1; a "z" joint is a horizontal joint at z =
    position in a wall piece `depth` deep, sampled for x in a0..a1. Rays run along y (from each listed side, at
    several heights / spans and off the joint centre) and, for x joints, steeply down through the top; each must hit
    the mesh inside the piece, or the joint shows daylight."""
    from mathutils.bvhtree import BVHTree
    v, t = cp.mesh_arrays(obj)
    tree = BVHTree.FromPolygons(v.tolist(), t.tolist(), all_triangles=True)
    bad = []
    for joint in joints:
        axis, pos, depth, a0, a1, sides = joint[:6]
        if axis == "x" and a0 > 1.0:
            # a joint over a chamfered underside (the cornice): rays from below at 30 degrees aimed into the joint's
            # bottom 4 cm, from both faces and off the joint centre; each must stop on the stones' skin (within 4 cm of
            # the face, at or under the course), never pass the joint and hit something deep behind it
            for sy in sides:
                d = Vector((0.0, -sy * math.cos(math.radians(30.0)), math.sin(math.radians(30.0))))
                for q in np.linspace(a0 + 0.1, a0 + 4.0, 9):
                    for dd in (-3.0, -1.5, -0.6, -0.15, -0.05, 0.0, 0.05, 0.15, 0.6, 1.5, 3.0):
                        aim = Vector((pos + dd, sy * (depth - 0.2), q))
                        o = aim - d * 40.0
                        hit = tree.ray_cast(o, d, 80.0)
                        ok = hit[0] is not None and abs(hit[0][1]) >= depth - 4.0 and hit[0][2] <= a1 + 0.5
                        if not ok:
                            bad.append((axis, round(pos + dd, 2), round(float(q), 2), "below%+d" % sy))
        for q in np.linspace(a0 + 0.15, a1 - 0.15, 11 if axis == "x" else 41):
            # off the joint by up to 3 cm too: a stone whose joint end lost its square corner (a bevel through the
            # course) shows daylight beside the mortar, not in it
            dds = (-3.0, -2.0, -1.2, -0.6, -0.18, -0.08, 0.0, 0.08, 0.18, 0.6, 1.2, 2.0, 3.0) if axis == "x" else                 (-0.18, -0.08, 0.0, 0.08, 0.18)
            for dd in dds:
                x, z = (pos + dd, q) if axis == "x" else (q, pos + dd)
                for sy in sides:
                    y0 = sy * (depth + 50.0) if axis == "x" else -(depth + 50.0)
                    hit = tree.ray_cast(Vector((x, y0, z)), Vector((0.0, -float(np.sign(y0)), 0.0)), 2.0 * depth + 100.0)
                    ok = hit[0] is not None and (abs(hit[0][1]) <= depth + 0.5 if axis == "x" else
                                                 -depth - 0.5 <= hit[0][1] <= 0.5)
                    if not ok:
                        bad.append((axis, round(x, 2), round(z, 2), "y%+d" % sy))
        if axis != "x":
            continue
        for y in np.linspace(-depth + 3.0, depth - 3.0, 9):
            for dx in (-0.12, 0.0, 0.12):
                d = Vector((0.0, -0.25 * float(np.sign(y)), -1.0)).normalized()
                o = Vector((pos + dx, y, a1 + 0.5)) - d * 0.5
                hit = tree.ray_cast(o, d, 30.0)
                if hit[0] is None or hit[0][2] < a0 - 0.5:
                    bad.append((axis, round(pos + dx, 2), round(float(y), 1), "down"))
    return bad


# ================================================================ HoodedStatue_A / _B
STATUE_SEG = 24
STATUE_PLINTH = (64.0, 44.0, 14.0)    # 44 deep: sits in StatueNiche_A's 47 cm recess with ~1.5 cm of air each side
STATUE_DEPTH = 44.0                   # the whole statue (hem, hands, sword) stays inside this depth
BODY_ROWS = [   # z, rx, ry, cy (y offset of the ring centre), pleat amplitude; the hem flares onto the plinth
    (14.0, 26.6, 18.0, 1.5, 1.0), (18.0, 27.2, 18.4, 1.5, 1.0), (25.0, 25.8, 17.4, 1.5, 0.95),
    (45.0, 23.6, 16.2, 1.8, 0.8), (70.0, 21.8, 15.8, 2.0, 0.6), (95.0, 20.0, 14.4, 2.2, 0.42),
    (108.0, 19.0, 13.6, 2.4, 0.26), (122.0, 19.6, 13.8, 2.2, 0.12), (136.0, 20.8, 13.6, 2.2, 0.05),
    (145.0, 21.4, 12.8, 2.4, 0.0), (151.0, 19.0, 12.2, 2.4, 0.0)]
# deep vertical robe folds (ring segment, ridge cm) below the knees, fading out by z 95
ROBE_FOLDS = ((2, 4.2), (5, 3.6), (19, 3.8), (22, 4.4))
# hood rings (z, rx, ry, cy) before statue B's bow: the bottom ring flares onto the shoulders (drape), the brow rings
# lean forward over the face, the crown peaks toward the back
HOOD_ROWS = [(155.0, 19.5, 14.6, 2.0), (158.5, 16.6, 13.4, 1.6), (162.0, 14.6, 13.0, 1.0), (166.0, 13.8, 13.4, 0.4),
             (170.0, 13.6, 13.8, -0.2), (174.0, 13.4, 13.9, -0.6), (178.0, 13.0, 13.8, -0.9), (182.0, 12.0, 13.0, -0.8),
             (186.0, 9.6, 11.2, 0.6), (189.5, 6.0, 8.0, 2.6)]
HOOD_APEX = {"A": (0.0, 7.6, 193.0), "B": (0.0, 3.0, 191.0)}
# the cowl opening per hood ring: z -> (depth as a fraction of the ring radius, half width in degrees): an oval
FACE_ROWS = {158.5: (0.30, 30.0), 162.0: (0.62, 40.0), 166.0: (0.74, 44.0), 170.0: (0.78, 46.0), 174.0: (0.78, 46.0),
             178.0: (0.72, 42.0), 182.0: (0.52, 32.0), 186.0: (0.20, 16.0)}
FACE_Z = 169.5           # centre of the face mask
FACE_ROW = 170.0         # the ring whose recess back seats the mask
COWL_DARK_Z = 160.0      # cowl faces (any recessed corner) whose row centre is above this wear EnvStoneDark
# statue B bows its head: the hood stack and the face pitch forward (deg) about a pivot (y, z) at the neck
BOW = {"A": None, "B": (18.0, 2.0, 153.0)}      # 18 deg: the lower face still shows under the brow at eye height
SLEEVE = {
    "A": ([(17.0, 1.5, 145.0), (19.6, -2.0, 128.0), (19.0, -6.0, 117.5), (12.0, -13.5, 122.0), (6.4, -16.5, 127.0)],
          [6.0, 6.6, 7.0, 7.5, 8.2]),
    "B": ([(17.0, 1.5, 145.0), (20.0, -1.0, 128.0), (19.6, -4.0, 114.0), (12.0, -12.5, 106.0), (6.2, -16.6, 104.0)],
          [6.0, 6.6, 7.0, 7.5, 7.8]),
}
SWORD_Y = -19.0
STATUE_FIT = {}          # kind -> (figure depth before the fit, y compression) for the report


def face_weight(dphi_deg, half_deg):
    h = half_deg
    return float(np.interp(abs(dphi_deg), [0.0, 0.6 * h, h, 1.2 * h], [1.0, 0.97, 0.55, 0.0]))


def bow(kind, pts):
    """Statue B's bowed head: pitch points forward (toward -y) about the neck pivot."""
    b = BOW[kind]
    if b is None:
        return np.asarray(pts, float)
    deg, py, pz = b
    return cp.rot_axis(pts, X, deg, about=(0.0, py, pz))


def statue_rings(kind, rng):
    rows = [(z, rx, ry, cy, amp) for z, rx, ry, cy, amp in BODY_ROWS]
    rows += [(z, rx, ry, cy, 0.0) for z, rx, ry, cy in HOOD_ROWS]
    n_body = len(BODY_ROWS)
    S = STATUE_SEG
    rings, recessed = [], []
    for k, (z, rx, ry, cy, amp) in enumerate(rows):
        ring, rec = [], []
        fold_w = float(np.interp(z, [25.0, 105.0], [1.0, 0.0])) if k < n_body else 0.0
        for s in range(S):
            phi = math.tau * s / S
            dphi = math.degrees(min(phi, math.tau - phi))
            pleat = (1.0 if s % 2 == 0 else -0.65) * (1.0 if dphi > 25.0 or k < 3 else 0.7)
            f = 1.0 + 0.075 * amp * pleat + rng.uniform(-0.016, 0.016)
            dd, half = FACE_ROWS.get(z, (0.0, 1.0)) if k >= n_body else (0.0, 1.0)
            d = dd * face_weight(dphi, half)
            if d > 0.12:
                f = 1.0                 # the cowl lining is cut clean (no hand jitter): one quiet dark hollow
            f *= 1.0 - d
            fold = 0.0
            for fs, amp_cm in ROBE_FOLDS:
                ds = min((s - fs) % S, (fs - s) % S)
                fold += amp_cm * (1.0 if ds == 0 else (-0.45 if ds == 1 else 0.0))
            fold *= fold_w
            zz = z
            if 0 < k < n_body - 1 and amp > 0.3:
                zz = z + rng.uniform(-0.6, 0.6)
            if k == 1:
                zz = z + rng.uniform(-1.6, 1.6)          # the uneven hem
            sx, sy = math.sin(phi), -math.cos(phi)
            ring.append((rx * f * sx + fold * sx, cy + ry * f * sy + fold * sy, zz))
            rec.append(d > 0.12)
        ring = np.array(ring)
        if k >= n_body:
            ring = bow(kind, ring)
        rings.append(ring)
        recessed.append(rec)
    return rows, rings, recessed


def face_mask(kind, rows, rings):
    """A faceted mourner's face set in the cowl: a cheek-jaw-chin block, a brow-forehead block (the crease between
    them is the eyes) and a nose wedge, about 13 x 17 cm, its front 5 cm inside the hood's front. Light stone."""
    kf = [r[0] for r in rows].index(FACE_ROW)
    z, rx, ry, cy, _ = rows[kf]
    dd, _ = FACE_ROWS[FACE_ROW]
    y_back = cy - ry * (1.0 - dd)
    o = np.array([0.0, y_back - 0.7, FACE_Z])
    lower = [(sx * 5.6, -1.2, 0.5) for sx in (1, -1)] + [(sx * 5.8, 1.2, 1.0) for sx in (1, -1)] + \
            [(sx * 4.6, -1.7, -3.5) for sx in (1, -1)] + [(sx * 2.6, -2.1, -7.2) for sx in (1, -1)] + \
            [(0.0, -2.6, -8.6)] + [(sx * 2.0, -0.6, -8.9) for sx in (1, -1)] + \
            [(sx * 6.0, 3.6, 1.6) for sx in (1, -1)] + [(sx * 5.0, 3.6, -7.0) for sx in (1, -1)] + [(0.0, 3.6, -9.2)]
    brow = [(sx * 6.2, -0.8, 2.2) for sx in (1, -1)] + [(sx * 4.6, -2.0, 2.9) for sx in (1, -1)] + \
           [(0.0, -2.1, 3.1)] + [(sx * 5.2, -0.7, 8.0) for sx in (1, -1)] + [(0.0, -1.1, 8.6)] + \
           [(sx * 6.4, 3.6, 2.0) for sx in (1, -1)] + [(sx * 5.4, 3.6, 8.6) for sx in (1, -1)]
    nose = [(0.0, -4.4, -2.4), (0.0, -2.7, 2.8), (1.5, -2.0, -2.7), (-1.5, -2.0, -2.7), (1.0, -1.0, 2.6),
            (-1.0, -1.0, 2.6), (0.0, -2.2, -3.3)]
    out = []
    for pts in (lower, brow, nose):
        v, f = cp.hull(np.array(pts, float) + o)
        out.append((bow(kind, v), f))
    return out


def praying_hands(P, rng):
    """Two flattened palms pressed together, fingertips up and 15 degrees forward, a shallow groove between them."""
    for sx in (1.0, -1.0):
        pts = [(0.9, -2.1, 0.0), (-0.3, -1.2, 0.0), (-0.3, 2.0, 0.0), (3.5, 2.0, 0.0), (3.6, -1.6, 0.0),
               (0.8, -1.9, 8.0), (-0.3, -1.0, 8.0), (-0.3, 1.8, 8.0), (3.3, 1.6, 8.0), (3.4, -1.4, 8.0),
               (0.7, -0.8, 13.0), (-0.3, -0.4, 13.0), (-0.3, 0.7, 13.0), (2.6, 0.6, 13.0), (2.6, -0.7, 13.0)]
        p = np.array(pts) * np.array([sx, 1.0, 1.0]) + rng.uniform(-0.08, 0.08, (len(pts), 3))
        p[:5, 2] -= 0.0 if sx > 0 else 0.6               # wrists end at different depths in the sleeves
        p = cp.rot_axis(p, X, 15.0) + np.array([0.0, -17.6, 123.0])
        v, f = cp.hull(p)
        P.add(v, f, "EnvStone", "fig/chamfer")


def build_statue(kind):
    rng = np.random.default_rng(201 if kind == "A" else 202)
    P = cp.Parts(("EnvStone",))
    pw, pd, ph = STATUE_PLINTH
    add_block(P, rect(-pw / 2, -pd / 2, pw / 2, pd / 2), 0, ph, "up", rng, flat_top=True, ch=(1.2, 2.0), ch0=1.0,
              chip_p=0.6, chip_cm=(1.5, 3.0))
    rows, rings, recessed = statue_rings(kind, rng)
    S = STATUE_SEG
    apex = bow(kind, np.array([HOOD_APEX[kind]]))[0]
    verts = np.concatenate(rings + [apex[None, :]])
    faces, tags = [], []
    faces.append(list(range(S - 1, -1, -1)))
    tags.append("stone/bottom")
    n_body = len(BODY_ROWS)
    for k in range(len(rings) - 1):
        a, b = k * S, (k + 1) * S
        zc = 0.5 * (rows[k][0] + rows[k + 1][0])
        for s in range(S):
            s2 = (s + 1) % S
            faces.append([a + s, a + s2, b + s2, b + s])
            rec = recessed[k][s] + recessed[k][s2] + recessed[k + 1][s] + recessed[k + 1][s2]
            if rec >= 1:
                # one rule for the whole cowl lining: every face touching the opening above the chin line is the dark
                # recess (one clean dark oval round the face, no light/dark sawtooth along the rim); below it, mid
                tags.append("recess/side" if zc >= COWL_DARK_Z else "mid/side")
            elif k >= n_body - 1:
                tags.append("hood/side")
            elif k < 2:
                tags.append("stone/chip")
            else:
                tags.append("fig/side")
    top = (len(rings) - 1) * S
    ai = len(verts) - 1
    for s in range(S):
        faces.append([top + s, top + (s + 1) % S, ai])
        tags.append("hood/top")
    P.add(verts, faces, "EnvStone", tags)
    # the face in the cowl (light stone; the shadow is the dark rim band and soot above it)
    g = P.new_group()
    for v, f in face_mask(kind, rows, rings):
        nz = [cp.newell(v[ff])[2] for ff in f]
        P.add(v, f, "EnvStone", ["fig/top" if n > 0.55 else "fig/side" for n in nz], g)
    # capelet over the shoulders: the inner rim tucks under the hood's drape, the shoulders fall ~35 degrees and roll
    # over a rounded edge and the cape bells out below them, the hem dips at the back and rises at the front
    cap = []
    for z, rx, ry, cy, low in ((158.8, 15.6, 12.4, 2.0, 0.0), (156.6, 19.4, 13.8, 2.2, 0.0), (153.4, 22.2, 15.2, 2.4, 0.0),
                               (149.0, 23.8, 16.0, 2.4, 0.2), (142.0, 24.6, 16.6, 2.4, 0.5),
                               (134.0, 25.0, 17.0, 2.2, 0.8), (127.0, 24.8, 17.0, 2.0, 1.0)):
        ring = []
        for s in range(S):
            phi = math.tau * s / S
            dphi = math.degrees(min(phi, math.tau - phi))
            pleat = (1.0 if s % 2 else -0.5) * low
            f = 1.0 + 0.04 * pleat + rng.uniform(-0.01, 0.01)
            zz = z + low * (9.0 * max(0.0, 1.0 - dphi / 70.0)) + (rng.uniform(-1.2, 1.2) if low >= 1.0 else 0.0)
            ring.append((rx * f * math.sin(phi), cy - ry * f * math.cos(phi), zz))
        cap.append(np.array(ring))
    v, f = fc.loft(cap[::-1])
    P.add(v, f, "EnvStone", ["hood/side"] * (len(f) - 2) + ["hood/bottom", "hood/top"])
    # bell sleeves meeting in front; praying hands (A) or two fists on a sword's pommel (B)
    path, radii = SLEEVE[kind]
    for sx in (1.0, -1.0):
        pts = np.array(path) * np.array([sx, 1.0, 1.0])
        v, f = cp.tube(pts, radii, sides=7, phase=0.3)
        P.add(v, f, "EnvStone", ["hood/side"] * (len(f) - 2) + ["hood/chamfer", "recess/side"])
    if kind == "A":
        praying_hands(P, rng)
    else:
        sword_parts(P, rng)
    # fit the figure (everything but the plinth, P.v[0]) inside STATUE_DEPTH: centre it over the plinth in y and, when
    # the sleeves / sword still reach past the depth, compress it a few percent in y (the niche recess is 47 deep)
    body = np.concatenate(P.v[1:])
    ylo, yhi = float(body[:, 1].min()), float(body[:, 1].max())
    yc = 0.5 * (ylo + yhi)
    k = min(1.0, (STATUE_DEPTH - 0.4) / (yhi - ylo))
    STATUE_FIT[kind] = (round(yhi - ylo, 1), round(k, 3))
    P.v = [P.v[0]] + [np.column_stack([v[:, 0], (v[:, 1] - yc) * k, v[:, 2]]) for v in P.v[1:]]
    rings = [np.column_stack([r[:, 0], (r[:, 1] - yc) * k, r[:, 2]]) for r in rings]
    cap = [np.column_stack([r[:, 0], (r[:, 1] - yc) * k, r[:, 2]]) for r in cap]
    apex = np.array([apex[0], (apex[1] - yc) * k, apex[2]])
    path = [(p[0], (p[1] - yc) * k, p[2]) for p in path]
    # pivot: the XY centre of the whole footprint
    allv = np.concatenate(P.v)
    shift = np.array([0.5 * (allv[:, 0].min() + allv[:, 0].max()), 0.5 * (allv[:, 1].min() + allv[:, 1].max()), 0.0])
    P.v = [v - shift for v in P.v]
    obj = build(P, "HoodedStatue_%s_Mars_SM" % kind)
    sc.box_ucx(obj, tuple(np.array([0, 0, ph / 2]) - shift), (pw, pd, ph))
    low = np.concatenate([r for r, row in zip(rings, rows) if row[0] <= 108.0])
    sc.add_ucx(obj, low - shift)
    up = np.concatenate([r for r, row in zip(rings, rows) if row[0] >= 108.0] + [apex[None, :]] +
                        [np.array(path) * np.array([sx, 1.0, 1.0]) for sx in (1.0, -1.0)] + cap)
    up = np.concatenate([up, up + np.array([0.0, -6.0, 0.0])])
    up = up[(up[:, 1] > -22.0)]
    sc.add_ucx(obj, up - shift)
    if kind == "B":
        sc.box_ucx(obj, tuple(np.array([0.0, (SWORD_Y - yc) * k, (ph + 104.0) / 2]) - shift), (36.0, 7.0 * k, 104.0 - ph))
    return obj, P


def sword_parts(P, rng):
    """Statue B's broadsword, point down on the plinth: a ridged blade 9 cm wide under the guard, a 34 cm cross guard
    with flared ends, a wrapped grip, a big faceted pommel, and the two fists over it."""
    yc = SWORD_Y
    rings = []
    for z, hw, t in ((17.0, 3.0, 1.0), (50.0, 3.8, 1.25), (80.5, 4.5, 1.4)):
        rings.append(np.array([(hw, yc, z), (0.0, yc - t, z), (-hw, yc, z), (0.0, yc + t, z)]))
    v = np.concatenate([[(0.0, yc, STATUE_PLINTH[2] - 0.3)]] + rings)
    f = [[0, 1 + (s + 1) % 4, 1 + s] for s in range(4)]
    for i in range(len(rings) - 1):
        a, b = 1 + 4 * i, 1 + 4 * (i + 1)
        f += [[a + s, a + (s + 1) % 4, b + (s + 1) % 4, b + s] for s in range(4)]
    f.append([9, 10, 11, 12])
    P.add(v, f, "EnvStone", "fig/chamfer")
    guard = [(-14.5, 80.0), (14.5, 80.0), (16.6, 78.8), (17.4, 82.4), (16.6, 86.0), (14.5, 85.0), (-14.5, 85.0),
             (-16.6, 86.0), (-17.4, 82.4), (-16.6, 78.8)]
    add_block(P, guard, -yc - 2.5, -yc + 2.5, "front", rng, kind="fig", ch=(0.5, 0.8), chip_p=0.3, chip_cm=(0.4, 0.9))
    v, f = cp.tube(np.array([(0.0, yc, 84.6), (0.0, yc, 96.4)]), [1.9, 1.7], sides=6)
    P.add(v, f, "EnvStone", "fig/side")
    for zb in (88.0, 92.0):
        v, f = cp.tube(np.array([(0.0, yc, zb), (0.0, yc, zb + 1.2)]), [2.25, 2.25], sides=6, phase=0.4)
        P.add(v, f, "EnvStone", "fig/chamfer")
    oct_ = np.array([(3.6, 0, 0), (-3.6, 0, 0), (0, 3.3, 0), (0, -3.3, 0), (0, 0, 3.2), (0, 0, -3.2)])
    P.add(*cp.hull(oct_ + np.array([0.0, yc, 99.6])), "EnvStone", "fig/chamfer")
    for sx in (1.0, -1.0):
        pts = []
        for dx in (-2.8, 2.8):
            for dy in (-2.8, 2.8):
                for dz in (-3.0, 3.0):
                    pts.append((sx * 3.6 + dx + rng.uniform(-0.4, 0.4), yc + dy + rng.uniform(-0.4, 0.4),
                                104.0 + dz + rng.uniform(-0.4, 0.4)))
        P.add(*cp.hull(np.array(pts)), "EnvStone", "fig/top")


# ================================================================ StatueNiche_A
NICHE_W, NICHE_H, NICHE_D = 120.0, 280.0, 50.0
N_SILL = 22.0
N_HALF = 46.0             # half the opening
N_SPRING = 184.0          # arch springing (top of the imposts)
N_R = 70.0                # intrados radius; the arcs' centres sit at x = -+(N_R - N_HALF)
N_RING = 14.0
N_CORNICE = 266.0
N_BACK = 3.0              # the back panel: its front is the recess back (47 cm deep recess)
N_SOCKET = (0.0, -(N_BACK + NICHE_D) / 2.0, N_SILL)


def niche_arc_pt(theta_deg, r, side=1.0):
    c = -(N_R - N_HALF)
    a = math.radians(theta_deg)
    return np.array([side * (c + r * math.cos(a)), N_SPRING + r * math.sin(a)])


def niche_apex_deg():
    return math.degrees(math.acos((N_R - N_HALF) / N_R))


def build_statue_niche():
    rng = np.random.default_rng(303)
    P = cp.Parts(("EnvStone",))
    D = NICHE_D
    # sill (the niche floor the statue stands on)
    add_block(P, rect(-60, -D, 60, 0), 0, N_SILL, "up", rng, flat_top=True, ch=(1.0, 1.8), chip_p=0.5)
    # coursed pilasters and imposts
    for sx in (-1, 1):
        x0, x1 = sorted((sx * N_HALF, sx * 60.0))
        for z0, z1 in ((N_SILL, 80.0), (80.0, 131.0), (131.0, 174.0)):
            add_block(P, rect(x0, z0, x1, z1), 0, D - 4.0, "front", rng, ch=(0.9, 1.6), chip_p=0.5)
        # the impost overhangs the opening by 3 cm but stops at the back panel's front (no hidden coplanar backs)
        imp = np.array([(N_HALF - 3.0, -D), (60.0, -D), (60.0, 0.0), (N_HALF, 0.0), (N_HALF, -N_BACK),
                        (N_HALF - 3.0, -N_BACK)]) * np.array([sx, 1.0])
        add_block(P, imp, 174.0, N_SPRING, "up", rng, flat_top=True, ch=(0.8, 1.2), ch0=2.2, chip_p=0.4)
    # back panel = the recess back, its top follows the intrados
    apex = niche_apex_deg()
    thetas = [0.0, 15.0, 30.0, 44.0, 56.0, 66.0]
    intr = [niche_arc_pt(t, N_R) for t in thetas] + [np.array([0.0, N_SPRING + math.sqrt(N_R ** 2 - (N_R - N_HALF) ** 2)])]
    back = [(-N_HALF, N_SILL), (N_HALF, N_SILL)] + [tuple(p) for p in intr] + \
           [tuple(p * np.array([-1.0, 1.0])) for p in intr[-2::-1]]
    add_block(P, back, 0, N_BACK, "front", rng, kind="dark", flat_top=True, ch=0.2, chip_p=0.0)
    # voussoirs (four a side) and a tapered keystone that continues the arch ring up to the cornice, 2 cm proud
    for sx in (-1.0, 1.0):
        for t0, t1 in zip(thetas[:-1], thetas[1:]):
            q = [niche_arc_pt(t0, N_R, sx), niche_arc_pt(t0, N_R + N_RING, sx), niche_arc_pt(t1, N_R + N_RING, sx),
                 niche_arc_pt(t1, N_R, sx)]
            add_block(P, q, 0, D, "front", rng, ch=(1.0, 1.6), chip_p=0.5)
    apex_in = intr[-1]
    apex_out = np.array([0.0, N_SPRING + math.sqrt((N_R + N_RING) ** 2 - (N_R - N_HALF) ** 2)])
    ke = niche_arc_pt(thetas[-1], N_R + N_RING)
    ki = niche_arc_pt(thetas[-1], N_R)
    key = [(-ki[0], ki[1]), tuple(apex_in), tuple(ki), tuple(ke), (0.0, N_CORNICE), (-ke[0], ke[1])]
    add_block(P, key, 0, D + 2.0, "front", rng, kind="light", ch=(1.0, 1.6), chip_p=0.5, chip_cm=(0.8, 1.6))
    # spandrels (recessed behind the arch ring, either side of the keystone) with a raised cross each
    for sx in (-1.0, 1.0):
        sp = [(sx * 60.0, N_SPRING), (sx * 60.0, N_CORNICE), (0.0, N_CORNICE), (sx * ke[0], ke[1])]
        sp += [tuple(niche_arc_pt(t, N_R + N_RING, sx)) for t in thetas[-2:0:-1]]
        add_block(P, sp, 0, D - 6.0, "front", rng, kind="mid", ch=(0.8, 1.3), chip_p=0.3)
        cx, cz = sx * 51.0, 238.0
        for k, r in enumerate((rect(cx - 1.5, cz - 10, cx + 1.5, cz + 10), rect(cx - 6, cz + 1.5, cx + 6, cz + 4.5))):
            w0 = D - 6.0 - 0.35 * (k + 1)
            add_relief(P, r, w0, 2.8 + (D - 6.0 - w0), "front", rng, kind="fig", bevel=0.6, jitter=0.1)
    # cornice: two stones across the top
    for x0, x1 in ((-60, -2), (-2, 60)):
        add_block(P, rect(x0, -D, x1, 0), N_CORNICE, NICHE_H, "up", rng, ch=(1.0, 1.6), ch0=2.4, chip_p=0.5,
                  joint=0.0)
    obj = build(P, "StatueNiche_A_Mars_SM")
    sc.add_socket(obj, "Statue", N_SOCKET)
    # collision: the sill, the two jambs (pilasters and arch haunches) and the head above the arch's apex; the recess
    # stays open (the statue on SOCKET_Statue brings its own)
    sc.box_ucx(obj, (0.0, -D / 2, N_SILL / 2), (120.0, D, N_SILL))
    for sx in (-1.0, 1.0):
        sc.box_ucx(obj, (sx * (60.0 + N_HALF) / 2, -D / 2, (N_SILL + N_CORNICE) / 2), (60.0 - N_HALF, D, N_CORNICE - N_SILL))
    sc.box_ucx(obj, (0.0, -D / 2, (apex_out[1] + NICHE_H) / 2), (120.0, D, NICHE_H - apex_out[1]))
    return obj, P


# ================================================================ CandleNiche_A
CN_W, CN_H, CN_D = 60.0, 90.0, 24.0
CN_BACK = 8.0             # the recess back's front: a 16 cm deep recess
CN_SILL = 20.0            # top of the sill stone under the opening
CN_FLOOR = 20.4           # top of the candle ledge (the recess floor the candles stand on)
CN_HALF, CN_SPRING, CN_APEX = 20.0, 50.0, 82.0          # the pointed opening (two-centred, centres 15.6 cm off axis)
CN_OUT_HALF, CN_OUT_APEX = 30.0, 90.0                   # the outline follows the arch with a 10 cm border
CN_SOCKET = (0.0, -(CN_BACK + CN_D) / 2.0, CN_FLOOR)
CN_LEDGE_EDGE = (0.0, -(CN_D + 8.0), CN_FLOOR)


def pointed_arc(half, apex, spring=CN_SPRING):
    """(centre offset c, radius r, end angle deg) of a two-centred pointed arch of half width `half` (at the spring
    line) rising to `apex`: the right arc is centred at (-c, spring)."""
    h = apex - spring
    s = h * h / half                    # r + c
    r = 0.5 * (s + half)
    c = r - half
    return c, r, math.degrees(math.acos(c / r))


def cn_arc_pt(half, apex, t, sx=1.0):
    c, r, amax = pointed_arc(half, apex)
    a = math.radians(t * amax)
    return np.array([sx * (-c + r * math.cos(a)), CN_SPRING + r * math.sin(a)])


def split_convex_by_polyline(poly, line):
    """A convex CCW polygon cut by a polyline that runs left to right across it (first and last points outside, x
    increasing, entering and leaving once): (upper piece, lower piece), both CCW."""
    poly = cp.ccw2(poly)
    n = len(poly)
    line = np.asarray(line, float)
    hits = []
    for k in range(len(line) - 1):
        p0, p1 = line[k], line[k + 1]
        for i in range(n):
            q0, q1 = poly[i], poly[(i + 1) % n]
            r = geometry.intersect_line_line_2d(Vector(p0), Vector(p1), Vector(q0), Vector(q1))
            if r is not None:
                hits.append((k + float(np.linalg.norm(np.array(r) - p0) / max(np.linalg.norm(p1 - p0), 1e-9)), i,
                             np.array(r)))
    hits.sort(key=lambda h: h[0])
    (te, ie, pe), (tx, ix, px) = hits[0], hits[-1]
    inner = [line[k] for k in range(len(line)) if te < k < tx]
    upper = [pe] + inner + [px] + [poly[(ix + 1 + m) % n] for m in range((ie - ix) % n)]
    lower = [px] + inner[::-1] + [pe] + [poly[(ie + 1 + m) % n] for m in range((ix - ie) % n)]
    return np.array(upper), np.array(lower)


# the soot's lower edge: a ragged flame tongue, ~8 cm wide just above the candle flames (z ~40), widening up into the
# apex and running out under the arch stones at the sides (left to right, x increasing)
CN_SOOT_EDGE = [(-40.0, 66.0), (-14.0, 63.6), (-11.6, 61.0), (-9.6, 56.4), (-7.8, 53.8), (-6.4, 48.6), (-4.6, 45.2),
                (-3.8, 41.6), (-1.2, 38.8), (0.6, 40.4), (3.4, 41.2), (4.4, 45.6), (6.4, 48.0), (7.6, 53.0),
                (9.8, 55.6), (11.0, 60.2), (14.2, 62.8), (40.0, 67.0)]


def add_block_soffit(P, outline, w0, w1, frame, rng, centre, **kw):
    """add_block for an arch stone whose intrados (the side faces turned toward the arch centre) wears the dark soot
    slot, so the soot wraps the arch instead of stopping on the recess back."""
    v, f, t = cp.chisel_prism(outline, w0, w1, rng, **kw)
    vw = cp.to_world(v, frame)
    tags = []
    for face, tag in zip(f, t):
        p = vw[face]
        n = cp.newell(p)
        c = p.mean(axis=0)
        to_c = np.array([centre[0] - c[0], 0.0, centre[1] - c[2]])
        if tag in ("side", "chip") and abs(n[1]) < 0.3 and np.dot(n, cp._n(to_c)) > 0.5:
            tags.append("dark/side")
        else:
            tags.append("stone/" + tag)
    return P.add(vw, f, "EnvStone", tags)


def build_candle_niche():
    """A tall pointed recess in a stone surround whose outline follows the arch with a 10 cm border, proud impost
    blocks on the jambs at the springing line, a candle ledge on a tapered corbel cut into a 20 cm base stone (nothing
    hangs below the frame). The recess walls and back are stone (the candles light them); the soot is a ragged flame
    tongue rising from just above the flames into the apex, and wraps the upper arch stones' soffits (EnvStoneDark)."""
    rng = np.random.default_rng(404)
    P = cp.Parts(("EnvStone",))
    H, D = CN_HALF, CN_D
    # the base stone under the opening (z 0..20, the frame's foot), and the jamb stones (to the springing line)
    add_block(P, rect(-CN_OUT_HALF, 0.0, CN_OUT_HALF, CN_SILL), 0, D, "front", rng, ch=(0.8, 1.4), chip_p=0.5,
              chip_cm=(1.0, 2.2))
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * H, sx * CN_OUT_HALF))
        for z0, z1 in ((CN_SILL, 35.0), (35.0, CN_SPRING)):
            add_block(P, rect(x0, z0, x1, z1), 0, D, "front", rng, ch=(0.8, 1.4), chip_p=0.5, chip_cm=(0.8, 2.0))
    # the arch: three voussoirs a side and a pointed keystone (1 cm proud), between the intrados and the outer arch;
    # the upper two voussoirs and the keystone carry soot on their soffits
    c_, _, _ = pointed_arc(H, CN_APEX)
    cuts = (0.0, 0.3, 0.58, 0.82)
    for sx in (-1.0, 1.0):
        for j, (t0, t1) in enumerate(zip(cuts[:-1], cuts[1:])):
            q = [cn_arc_pt(H, CN_APEX, t0, sx), cn_arc_pt(CN_OUT_HALF, CN_OUT_APEX, t0, sx),
                 cn_arc_pt(CN_OUT_HALF, CN_OUT_APEX, t1, sx), cn_arc_pt(H, CN_APEX, t1, sx)]
            if j == 0:
                add_block(P, q, 0, D, "front", rng, ch=(0.8, 1.3), chip_p=0.4, chip_cm=(0.8, 1.8))
            else:
                add_block_soffit(P, q, 0, D, "front", rng, (-sx * c_, CN_SPRING), ch=(0.8, 1.3), chip_p=0.4,
                                 chip_cm=(0.8, 1.8))
    key = [cn_arc_pt(H, CN_APEX, cuts[-1], 1.0), (0.0, CN_APEX), cn_arc_pt(H, CN_APEX, cuts[-1], -1.0),
           cn_arc_pt(CN_OUT_HALF, CN_OUT_APEX, cuts[-1], -1.0), (0.0, CN_OUT_APEX),
           cn_arc_pt(CN_OUT_HALF, CN_OUT_APEX, cuts[-1], 1.0)]
    add_block_soffit(P, np.array(key), 0, D + 1.0, "front", rng, (0.0, CN_SPRING), ch=(0.8, 1.2), chip_p=0.3,
                     chip_cm=(0.6, 1.2))
    # the recess back: stone below the ragged soot tongue, the soot above it (both follow the arch stones' inner
    # chords, so they fit them without overlap)
    inner = [cn_arc_pt(H, CN_APEX, t) for t in cuts] + [np.array([0.0, CN_APEX])]
    m = np.array([-1.0, 1.0])
    back = [(-H, CN_SILL), (H, CN_SILL)] + [tuple(p) for p in inner] + [tuple(p * m) for p in inner[-2::-1]]
    # grown 1.5 cm under the stones (its back 3 mm off the wall plane) so the stones' chipped corners never open a
    # hole through to the wall
    back = cp.offset_poly(cp.ccw2(np.array(back)), -1.5, miter=2.0)
    soot, low = split_convex_by_polyline(back, CN_SOOT_EDGE)
    add_block(P, low, 0.3, CN_BACK, "front", rng, kind="mid", flat_top=True, ch=0.3, chip_p=0.0)
    add_block(P, soot, 0.3, CN_BACK, "front", rng, kind="dark", flat_top=True, ch=0.3, chip_p=0.0)
    # an impost block on each jamb at the springing line, 2.2 cm proud, past the outer edge and 1.5 cm into the
    # opening (so its inner end is never coplanar with the jamb's reveal); the opening itself stays clear
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * (H - 1.5), sx * (CN_OUT_HALF + 0.8)))
        add_block(P, rect(x0, CN_SPRING - 4.0, x1, CN_SPRING + 0.6), D - 5.0, D + 2.2, "front", rng,
                  kind="light", ch=(0.6, 1.0), chip_p=0.4, chip_cm=(0.6, 1.4))
    # the candle ledge, and one tapered corbel under it: 34 cm wide under the ledge narrowing to 16 cm, its foot 3 mm
    # over the base stone's underside (flush to the eye, never coplanar), its back buried in the base stone
    add_block(P, rect(-24.0, -(D + 8.0), 24.0, -(CN_BACK + 0.2)), 14.5, CN_FLOOR, "up", rng, kind="light",
              flat_top=True, ch=(0.6, 1.0), ch0=2.0, chip_p=0.5, chip_cm=(0.8, 1.8))
    yb = -(D - 3.0)
    cor = [(sx * 17.0, yb, 14.8) for sx in (1, -1)] + [(sx * 16.4, -(D + 5.8), 14.8) for sx in (1, -1)] + \
          [(sx * 15.6, -(D + 5.4), 11.6) for sx in (1, -1)] + [(sx * 11.6, -(D + 3.4), 5.6) for sx in (1, -1)] + \
          [(sx * 8.0, -(D + 1.6), 0.3) for sx in (1, -1)] + [(sx * 8.0, yb, 0.3) for sx in (1, -1)]
    cor = np.array(cor, float) + rng.uniform(-0.2, 0.2, (len(cor), 3)) * np.array([1.0, 0.0, 0.0])
    v, f = cp.hull(cor)
    nz = [cp.newell(v[ff])[2] for ff in f]
    P.add(v, f, "EnvStone", ["stone/top" if n > 0.5 else ("stone/under" if n < -0.2 else "stone/side") for n in nz])
    obj = build(P, "CandleNiche_A_Mars_SM")
    sc.add_socket(obj, "Candle", CN_SOCKET)
    # the ledge's front top edge, for a CandleLedge_A / _B (their edge at y = 0, z = 0, ledge top toward +y)
    sc.add_socket(obj, "LedgeEdge", CN_LEDGE_EDGE)
    return obj, P


# ================================================================ urns
def lathe_tags(profile, segments, band_tags):
    """fc.lathe face order: one band of `segments` faces per consecutive profile pair."""
    out = []
    for t in band_tags:
        out += [t] * segments
    assert len(band_tags) == len(profile) - 1
    return out


def body_r(profile, z):
    outer = [(r, zz) for r, zz in profile]
    zs = [p[1] for p in outer]
    rs = [p[0] for p in outer]
    return float(np.interp(z, zs, rs))


URN_A = [(0, 0), (11.5, 0), (12.5, 1.2), (12.5, 4.0), (10.5, 5.5), (8.0, 7.5), (8.0, 10.0), (11.5, 12.5),
         (16.0, 19.0), (18.6, 28.0), (18.8, 36.0), (17.0, 44.0), (13.0, 50.5), (9.0, 54.5), (8.0, 57.0), (8.0, 62.0),
         (10.5, 64.5), (13.2, 67.0), (13.4, 70.0), (10.8, 70.0), (7.2, 68.8), (6.6, 64.0), (0, 63.0)]
URN_A_TAGS = (["dark/bottom", "stone/chamfer", "stone/side", "stone/chip", "stone/chip", "stone/side", "stone/chamfer"]
              + ["stone/side"] * 5 + ["stone/chip", "stone/side", "stone/side", "stone/chamfer", "stone/chamfer",
                                      "light/top", "light/top", "mouth/side", "mouth/side", "mouth/bottom"])
URN_B = [(0, 0), (10.0, 0), (11.0, 1.5), (10.5, 3.5), (9.0, 5.0), (12.0, 7.5), (18.5, 13.0), (22.5, 20.0),
         (23.5, 27.0), (22.0, 33.5), (18.0, 39.0), (12.0, 42.5), (8.5, 44.5), (7.8, 48.5), (9.0, 51.0), (11.2, 53.0),
         (11.4, 55.0), (9.0, 55.0), (6.4, 53.5), (6.0, 50.0), (0, 49.0)]
URN_B_TAGS = (["dark/bottom", "stone/chamfer", "stone/side", "stone/chip", "stone/chamfer"] + ["stone/side"] * 6
              + ["stone/chip", "stone/side", "stone/chamfer", "stone/chamfer", "light/top", "light/top",
                 "mouth/side", "mouth/side", "mouth/bottom"])
URN_C = [(0, 0), (12.0, 0), (13.2, 1.5), (12.6, 4.0), (14.5, 8.0), (17.0, 14.0), (17.6, 21.0), (16.5, 28.0),
         (13.6, 32.5), (11.5, 34.5), (12.6, 35.5), (12.6, 37.0), (0, 37.0)]
URN_C_TAGS = (["dark/bottom", "stone/chamfer", "stone/side", "stone/chip"] + ["stone/side"] * 4
              + ["stone/chip", "stone/chamfer", "stone/side", "light/top"])
URN_C_LID = [(0, 36.8), (13.3, 36.8), (13.5, 38.2), (12.0, 39.6), (8.0, 41.6), (4.0, 42.4), (3.0, 43.0), (4.2, 44.0),
             (3.6, 45.0), (0, 45.0)]
URN_C_LID_TAGS = ["dark/bottom", "stone/chamfer", "light/chamfer", "light/top", "light/top", "stone/chip",
                  "light/chamfer", "light/chamfer", "light/top"]


def add_lathe(P, profile, tags, segments, rng, jitter=0.3, phase=None, slot="EnvStone", offset=(0.0, 0.0, 0.0)):
    v, f = fc.lathe(profile, segments, twist_seed=int(rng.integers(1, 1 << 30)), jitter=jitter)
    ph = rng.uniform(0, 360.0 / segments) if phase is None else phase
    v = cp.rot_z(v, ph) + np.asarray(offset, float)
    P.add(v, f, slot, lathe_tags(profile, segments, tags))


def add_band(P, profile, z0, z1, proud, segments, rng, kind="light", slot="EnvStone"):
    """A raised ring round a lathe body between z0 and z1 (inner face sunk into the body)."""
    r0, r1 = body_r(profile[:len(profile) // 2 + 3], z0), body_r(profile[:len(profile) // 2 + 3], z1)
    prof = [(r0 - 1.5, z0), (r0 + proud * 0.6, z0), (max(r0, r1) + proud, (z0 + z1) * 0.5),
            (r1 + proud * 0.6, z1), (r1 - 1.5, z1)]
    v, f = cp.lathe_closed(prof, segments, phase_deg=rng.uniform(0, 30))
    P.add(v, f, slot, ["%s/chamfer" % kind] * len(f))


def outer_profile(profile):
    """The outer wall of a closed lathe profile (up to its widest top point, before it turns into the mouth)."""
    zmax = max(p[1] for p in profile)
    k = [i for i, p in enumerate(profile) if p[1] >= zmax - 1e-6][0]
    return profile[:k + 1]


def lean(P, deg, toward_deg):
    """Hand-turned, not machined: shear the vessel so its top leans `deg` toward a heading (the base stays flat on
    z = 0), then re-centre the footprint."""
    t = math.tan(math.radians(deg))
    d = np.array([math.cos(math.radians(toward_deg)), math.sin(math.radians(toward_deg)), 0.0])
    P.v = [v + np.outer(v[:, 2] * t, d) for v in P.v]
    allv = np.concatenate(P.v)
    c = 0.5 * (allv.min(axis=0) + allv.max(axis=0))
    P.v = [v - np.array([c[0], c[1], 0.0]) for v in P.v]


def build_urn_a():
    rng = np.random.default_rng(501)
    P = cp.Parts(("EnvStone",))
    add_lathe(P, URN_A, URN_A_TAGS, 10, rng, jitter=0.9)
    op = outer_profile(URN_A)
    for z0, z1 in ((41.5, 45.0), (13.0, 15.5)):
        r0, r1 = body_r(op, z0), body_r(op, z1)
        prof = [(r0 - 1.6, z0), (r0 + 0.7, z0), (max(r0, r1) + 1.3, (z0 + z1) * 0.5), (r1 + 0.7, z1), (r1 - 1.6, z1)]
        v, f = cp.lathe_closed(prof, 10, phase_deg=rng.uniform(0, 36))
        P.add(v, f, "EnvStone", "light/chamfer")
    lean(P, 1.6, 30.0)
    return build(P, "Urn_A_Mars_SM"), P


def build_urn_b():
    rng = np.random.default_rng(502)
    P = cp.Parts(("EnvStone",))
    add_lathe(P, URN_B, URN_B_TAGS, 10, rng, jitter=0.85)
    for sx in (1.0, -1.0):
        pts = np.array([(7.0, 0, 49.5), (12.0, 0, 52.3), (16.8, 0, 50.4), (19.2, 0, 45.0), (19.0, 0, 40.0),
                        (17.6, 0, 36.6)]) * np.array([sx, 1.0, 1.0])
        tng = np.gradient(pts, axis=0)
        nrm = np.array([cp._n(np.cross(Y, t)) for t in tng])
        v, f = cp.strap(pts, nrm, Y, 1.25, 2.1)
        P.add(v, f, "EnvStone", "light/chamfer")
    r0 = body_r(outer_profile(URN_B), 33.5)
    v, f = cp.lathe_closed([(r0 - 1.6, 32.0), (r0 + 0.6, 32.0), (r0 + 1.1, 33.5), (r0 + 0.4, 35.0), (r0 - 2.2, 35.0)],
                           10, phase_deg=rng.uniform(0, 36))
    P.add(v, f, "EnvStone", "light/chamfer")
    lean(P, 1.2, 200.0)
    return build(P, "Urn_B_Mars_SM"), P


def build_urn_c():
    rng = np.random.default_rng(503)
    P = cp.Parts(("EnvStone", "EnvIron"))
    add_lathe(P, URN_C, URN_C_TAGS, 9, rng, jitter=0.6)
    add_lathe(P, URN_C_LID, URN_C_LID_TAGS, 9, rng, jitter=0.2)
    op = outer_profile(URN_C)
    z0, z1 = 24.0, 27.0
    r0, r1 = body_r(op, z0), body_r(op, z1)
    v, f = cp.lathe_closed([(r0 - 1.4, z0), (r0 + 1.0, z0), (r1 + 1.0, z1), (r1 - 1.4, z1)], 18)
    P.add(v, f, "EnvIron", "iron/side")
    for k in range(4):
        a = math.radians(45.0 + 90.0 * k)
        rr = 0.5 * (r0 + r1) + 0.6
        d = np.array([math.cos(a), math.sin(a), 0.0])
        rv, rf = fc.lathe([(0.0, 0.7), (0.6, 0.45), (0.9, 0.05), (0.0, -0.5)], 5)
        rv = cp.to_world(rv, (cp._n(np.cross(Z, d)), Z, d), d * rr + np.array([0, 0, 0.5 * (z0 + z1)]))
        P.add(rv, rf, "EnvIron", "ironl/top")
    return build(P, "Urn_C_Mars_SM"), P


def build_urn_broken():
    """A hollow vase base broken off unevenly (one tall shard standing, the far side broken low), two big and three
    small shards round it, and its neck lying on its side."""
    rng = np.random.default_rng(504)
    P = cp.Parts(("EnvStone",))
    S = 12
    prof = [(11.5, 0.0), (12.5, 1.2), (12.5, 4.0), (10.5, 5.5), (8.6, 7.5), (9.0, 10.0), (12.0, 12.5), (16.0, 19.0),
            (18.6, 28.0), (18.8, 36.0), (17.0, 44.0)]
    foot = [p for p in prof if p[1] <= 12.5]

    def R(z):
        return float(np.interp(z, [p[1] for p in prof], [p[0] for p in prof]))

    # the break line round the rim: one tall shard standing to 40 cm, the far side broken low (16 cm, 40 % of it)
    brk = np.array([30.0, 40.5, 33.0, 27.0, 23.5, 19.0, 16.5, 16.0, 18.5, 22.0, 25.5, 28.0]) + rng.uniform(-0.6, 0.6, S)
    phase = rng.uniform(0, math.tau)
    ang = phase + math.tau * np.arange(S) / S
    ca, sa_ = np.cos(ang), np.sin(ang)

    def ring(rs, zs):
        rs, zs = np.broadcast_to(rs, (S,)), np.broadcast_to(zs, (S,))
        return np.column_stack([rs * ca, rs * sa_, zs])

    rings = [np.array([(0.0, 0.0, 0.0)])]
    rings += [ring(r, z) for r, z in foot]
    for j in (1, 2, 3, 4):                         # the outer wall, each column rising to its own break height
        zs = 12.5 + (brk - 12.5) * j / 4.0
        rings.append(ring(np.array([R(z) for z in zs]) + rng.uniform(-0.4, 0.4, S), zs))
    zt = brk - rng.uniform(0.5, 1.6, S)            # the broken rim slopes into the bowl
    rings.append(ring(np.array([R(z) for z in zt]) - 2.2, zt))
    for j in (3, 2, 1):                            # the inner wall, 2.2 cm in
        zs = 12.5 + (zt - 12.5) * j / 4.0 + 0.8 * (1 - j / 4.0)
        rings.append(ring(np.array([R(z) for z in zs]) - 2.2, zs))
    rings.append(np.array([(0.0, 0.0, 12.9)]))
    verts = np.concatenate(rings)
    starts = np.cumsum([0] + [len(r) for r in rings])
    faces, tags = [], []
    names = (["dark/bottom", "stone/chamfer", "stone/side", "stone/chip", "stone/chip", "stone/side", "stone/side"]
             + ["stone/side"] * 4 + ["light/chip"] + ["mouth/side"] * 3 + ["mouth/bottom"])
    assert len(names) == len(rings) - 1
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        sa, sb = starts[i], starts[i + 1]
        for s in range(S):
            s2 = (s + 1) % S
            if len(a) == 1:
                faces.append([sa, sb + s2, sb + s])
            elif len(b) == 1:
                faces.append([sa + s, sa + s2, sb])
            else:
                faces.append([sa + s, sa + s2, sb + s2, sb + s])
            tags.append(names[i])
    P.add(verts, faces, "EnvStone", tags)
    # shards: five curved shell pieces of the same wall (40-58 degrees of the body, 10-17 cm), lying close round the
    # base (inner edges at the foot), two of them convex side up: the footprint stays ~55 x 55 cm
    # (they spilled toward the side that broke low, so the pile reads as one pot, not a ring of petals)
    low = math.degrees(phase) + 360.0 * 7.0 / 12.0
    shards = ((-62.0, 18.5, 15.0, 52.0, False), (-24.0, 22.5, 12.0, 44.0, True), (6.0, 17.5, 17.0, 58.0, False),
              (38.0, 22.0, 10.0, 40.0, True), (74.0, 18.0, 13.0, 48.0, False))
    for k, (off, dist, height, span, up) in enumerate(shards):
        sv, sf = shard(span, height, rng)
        sv = cp.rot_axis(sv, Y, -90.0 if up else 90.0)   # the outer (convex, +x) face turns up or down
        sv = cp.rot_z(sv, rng.uniform(0.0, 360.0))
        a = math.radians(low + off)
        sv = sv - np.array([sv[:, 0].mean(), sv[:, 1].mean(), 0.0]) + np.array([dist * math.cos(a),
                                                                               dist * math.sin(a), 0.0])
        sv[:, 2] -= sv[:, 2].min()
        P.add(sv, sf, "EnvStone", ["stone/side"] * len(sf))
    # the broken-off neck and lip, on its side, its broken end against the bowl
    neck = [(8.6, 0.0), (8.2, 2.5), (8.0, 6.0), (10.5, 8.5), (13.2, 11.0), (13.4, 14.0), (10.8, 14.0), (7.2, 12.8),
            (6.4, 8.0), (6.4, 2.0), (7.0, 0.6)]
    nv, nf = cp.lathe_closed(neck, 10, phase_deg=rng.uniform(0, 36), jitter=0.3, rng=rng)
    nv = cp.rot_axis(nv, Y, 90.0 + rng.uniform(-8, 8))
    nv[:, 0] -= nv[:, 0].min()                        # the broken end (lathe z = 0) at x = 0, the lip toward +x
    th = low + 180.0 + 35.0
    nv = cp.rot_z(nv, th) + np.array([14.0 * math.cos(math.radians(th)), 14.0 * math.sin(math.radians(th)), 0.0])
    nv[:, 2] -= nv[:, 2].min()
    P.add(nv, nf, "EnvStone", "light/side")
    obj = build(P, "UrnBroken_A_Mars_SM")
    v = fc.verts_cm(obj)
    lo, hi = v.min(axis=0), v.max(axis=0)
    fc.set_verts_cm(obj, v - np.array([(lo[0] + hi[0]) * 0.5, (lo[1] + hi[1]) * 0.5, lo[2]]))
    return obj, P


def shard(span_deg, height, rng, r=18.4, t=2.2):
    """A closed curved wall fragment: a 3 x 3 patch of the outer surface and its inner offset, jagged edges."""
    us = np.linspace(-0.5, 0.5, 3) * math.radians(span_deg)
    vs = np.linspace(0.0, height, 3)
    outer, inner = [], []
    for j, z in enumerate(vs):
        for i, a in enumerate(us):
            edge = i in (0, 2) or j in (0, 2)
            jr = rng.uniform(-1.5, 1.5) if edge else 0.0
            ja = rng.uniform(-0.06, 0.06) if edge else 0.0
            aa = a + ja
            zz = z + jr
            outer.append((r * math.cos(aa), r * math.sin(aa), zz))
            inner.append(((r - t) * math.cos(aa), (r - t) * math.sin(aa), zz))
    v = np.array(outer + inner)
    v[:, 0] -= r - t * 0.5
    v[:, 2] -= height * 0.5
    f = []
    for j in range(2):
        for i in range(2):
            a = j * 3 + i
            f.append([a, a + 1, a + 4, a + 3])
            f.append([9 + a, 9 + a + 3, 9 + a + 4, 9 + a + 1])
    rim = [0, 1, 2, 5, 8, 7, 6, 3]
    for k in range(8):
        p, q = rim[k], rim[(k + 1) % 8]
        f.append([q, p, 9 + p, 9 + q])
    return v, f


# ================================================================ SigilDoor_A
DOOR_W, DOOR_H = 300.0, 450.0
D_OPEN = 116.0            # half the opening (pilaster inner faces)
D_SPRING = 290.0          # arch centre / springing
D_RING = 150.0            # extrados radius
D_KEY = 160.0
D_SLAB_FRONT = 22.0
D_GROOVE = 4.5
SIGIL_C = (0.0, 192.0)
D_BORDER = 9.0            # the recessed border band round the panel, inside the frame
D_BORDER_FRONT = 17.0     # its face: 5 cm behind the panel's face, 5 mm behind the groove floors


def sigil_shapes():
    """The sigil as (front polygon, floor polygon) pairs in the slab's (x, z) plane + the annular ring."""
    shapes = []

    def taper(poly, d_front=-0.6, d_floor=0.6):
        p = cp.ccw2(poly)
        return cp.offset_poly(p, d_front, miter=2.0), cp.offset_poly(p, d_floor, miter=2.0)

    cx, cz = SIGIL_C
    # crescents, backs to the ring, horns outward
    r1, c1 = 62.3, cx - 126.3
    r2, c2 = 140.2, cx - 222.2
    a1 = math.degrees(math.atan2(52.0, -92.0 - c1))
    a2 = math.degrees(math.atan2(52.0, -92.0 - c2))
    outer = cp.arc((c1, cz), r1, -a1, a1, 14)
    inner = cp.arc((c2, cz), r2, a2, -a2, 8)[1:-1]
    left = np.concatenate([outer, inner])
    shapes.append(taper(left))
    shapes.append(taper(cp.mirror_u(left)))
    # the bar through the ring and the diamonds
    shapes.append(taper(rect(-3.4, 66.0, 3.4, 276.0)))          # runs into the bottom diamond: one spear point
    for zc, hw, hh in ((298.0, 12.0, 25.0), (345.0, 8.0, 14.0), (66.0, 12.0, 22.0)):
        shapes.append(taper([(0, zc - hh), (hw, zc), (0, zc + hh), (-hw, zc)]))
    # the two flame marks over the crescents: teardrops ~13 x 28 cm, a rounded base and a pointed tip leaning 22 degrees
    # outward, 35 cm either side of the bar, level with the spear-diamond's lower point
    base = [(6.5 * math.cos(math.radians(t)), -5.5 + 6.5 * math.sin(math.radians(t)))
            for t in (25.0, 0.0, -30.0, -60.0, -90.0, -120.0, -150.0, -180.0, 155.0)]
    drop = np.array([(0.0, 16.5), (2.6, 10.0), (5.0, 4.0)] + base + [(-4.6, 4.6), (-2.4, 10.4)])
    drop = drop - np.array([0.0, 2.2])                  # centre the 28 cm teardrop on its anchor
    for sx in (1.0, -1.0):
        a_ = math.radians(-sx * 22.0)
        sl = (drop * np.array([sx, 1.0])) @ np.array([[math.cos(a_), -math.sin(a_)], [math.sin(a_), math.cos(a_)]]).T
        shapes.append(taper(sl + np.array([sx * 35.0, 274.0])))
    return shapes


def annulus_cutter(c, r_out, r_in, taper, w_front, w_floor, n=40):
    """A closed annular prism (the ring groove): outer / inner walls tapered by `taper` toward the floor."""
    t = np.linspace(0.0, math.tau, n, endpoint=False)
    cs = np.column_stack([np.cos(t), np.sin(t)])
    rings = [(r_out + taper, w_front), (r_out - taper, w_floor), (r_in + taper, w_floor), (r_in - taper, w_front)]
    verts = np.concatenate([np.column_stack([np.asarray(c) + cs * r, np.full(n, w)]) for r, w in rings])
    faces = []
    for k in range(4):
        a, b = k * n, ((k + 1) % 4) * n
        for i in range(n):
            j = (i + 1) % n
            faces.append([a + i, a + j, b + j, b + i])
    return verts, faces


def build_sigil_door():
    rng = np.random.default_rng(606)
    P = cp.Parts(("EnvStone", "EnvGlowSpirit"))
    # threshold
    for x0, x1 in ((-150, -52), (-52, 48), (48, 150)):
        add_block(P, rect(x0 + 0.2, -50, x1 - 0.2, 0), 0, 12, "up", rng, flat_top=True, ch=(1.0, 1.8), chip_p=0.5)
    # pilasters: bases, coursed shafts, capitals
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * 113.0, sx * 150.0))
        add_block(P, rect(x0, -46, x1, 0), 12, 40, "up", rng, flat_top=True, ch=(1.6, 2.6), chip_p=0.5)
        s0, s1 = sorted((sx * D_OPEN, sx * 147.0))
        for z0, z1 in ((40, 102), (102, 161), (161, 217), (217, 268)):
            add_block(P, rect(s0, z0, s1, z1), 0, 42, "front", rng, ch=(1.0, 1.8), chip_p=0.5, chip_cm=(1.2, 3.0))
        c0, c1 = sorted((sx * 112.0, sx * 150.0))
        add_block(P, rect(c0, -47, c1, 0), 268, D_SPRING, "up", rng, flat_top=True, ch=(1.0, 1.6), ch0=3.6,
                  chip_p=0.5)
    # the round arch: eleven voussoirs, the keystone proud
    n_v = 11
    step = 180.0 / n_v
    for k in range(n_v):
        a0, a1 = k * step, (k + 1) * step
        ro = D_KEY if k == n_v // 2 else D_RING
        pts = [cp.arc((0.0, D_SPRING), D_OPEN, a0, a1, 1), cp.arc((0.0, D_SPRING), ro, a1, a0, 2)]
        q = np.concatenate(pts)
        depth = 48.0 if k == n_v // 2 else 42.0
        add_block(P, q, 0, depth, "front", rng, kind="light" if k == n_v // 2 else "stone", ch=(1.0, 1.8),
                  chip_p=0.5, chip_cm=(1.2, 3.0))
    # the slab: one quiet stone panel (concept 3) inside a border band recessed 5 cm behind it, 9 cm wide all round
    # inside the frame; no joint crosses the glyph. The sigil is one exact boolean of the panel; groove floors are
    # EnvGlowSpirit faces 5 mm in front of the border slab's face (which runs on behind the panel)
    rs = D_OPEN + 1.5
    slab = np.array([(-rs, 12.3), (rs, 12.3)] + [tuple(p) for p in cp.arc((0.0, D_SPRING), rs, 0.0, 180.0, n_v)])
    add_block(P, slab, 0.3, D_BORDER_FRONT, "front", rng, kind="mid", flat_top=True, ch=0.6, chip_p=0.0)
    w_out, w_floor = D_SLAB_FRONT + 6.0, D_SLAB_FRONT - D_GROOVE
    shapes = sigil_shapes()
    cutters = []
    for front, floor in shapes:
        v, f = cp.taper_prism2d(front, floor, w_out, w_floor)
        cutters.append((cp.to_world(v, "front"), f))
    v, f = annulus_cutter(SIGIL_C, 54.0, 47.0, 0.6, w_out, w_floor)
    cutters.append((cp.to_world(v, "front"), f))
    fronts = [cp.ccw2(cp.offset_poly(cp.ccw2(fr), -0.7, miter=2.0)) for fr, _ in shapes]

    def in_groove(x, z):
        r = math.hypot(x - SIGIL_C[0], z - SIGIL_C[1])
        if 47.0 - 1.4 < r < 54.0 + 1.4:
            return True
        pt = Vector((x, z, 0.0))
        return any(geometry.intersect_point_tri_2d(pt, *[Vector((q[0], q[1], 0.0)) for q in fr[list(t)]])
                   for fr in fronts for t in cp.tess(fr))

    rp = D_OPEN - D_BORDER
    panel = np.array([(-rp, 12.3 + D_BORDER), (rp, 12.3 + D_BORDER)] +
                     [tuple(p) for p in cp.arc((0.0, D_SPRING), rp, 0.0, 180.0, n_v)])
    cv, cf, _ = cp.chisel_prism(panel, D_BORDER_FRONT - 1.0, D_SLAB_FRONT, rng, ch=(1.2, 1.8), ch_h=1.6,
                                chip_p=0.35, chip_cm=(1.5, 3.0), flat_top=True)
    v, f = cp.boolean_mesh((cp.to_world(cv, "front"), cf), cutters)
    tags, slots = [], []
    for tri in f:
        p = v[tri]
        cen = p.mean(axis=0)
        n = cp.newell(p)
        if n[1] < -0.999 and abs(cen[1] + w_floor) < 0.05:
            tags.append("glow/top")
            slots.append("EnvGlowSpirit")
            continue
        slots.append("EnvStone")
        if -D_SLAB_FRONT + 0.05 < cen[1] < -w_floor - 0.02 and abs(n[1]) < 0.995 and in_groove(cen[0], cen[2]):
            tags.append("groove/side")
        elif n[1] < -0.999:
            tags.append("stone/top")
        elif n[1] < -0.2:
            tags.append("stone/chamfer")
        else:
            tags.append("stone/side")
    P.add(v, f, slots, tags)
    obj = build(P, "SigilDoor_A_Mars_SM")
    sc.box_ucx(obj, (0, -25, 6), (300, 50, 12))
    for sx in (-1.0, 1.0):
        sc.box_ucx(obj, (sx * 131.0, -23.5, (12 + D_SPRING) / 2), (38, 47, D_SPRING - 12))
    sp = np.array([(x, y, z) for x, z in slab for y in (-0.3, -D_SLAB_FRONT)])     # the slab, joints and all
    sc.add_ucx(obj, sp)
    for a0, a1 in ((0.0, 60.0), (60.0, 120.0), (120.0, 180.0)):
        pts = []
        for r in (D_OPEN, D_RING + (8.0 if 60.0 <= a0 < 120.0 else 0.0)):
            for p in cp.arc((0.0, D_SPRING), r, a0, a1, 4):
                for y in (0.0, -42.0):
                    pts.append((p[0], y, p[1]))
        sc.add_ucx(obj, np.array(pts))
    return obj, P


# ================================================================ FloorMedallion_A
M_R = 200.0
M_BORDER_IN = 181.0
M_RING = (167.0, 180.5)
M_FIELD = 166.5
DI_OUT = 118.0            # the light diamond band's outer tips (on the cardinal axes)
DI_IN = 53.0              # its inner tips: a band ~46 cm wide measured square to its sides
DI_C = 14.0               # the small light centre diamond


def sector(r0, r1, a0, a1, n=2):
    o = cp.arc((0.0, 0.0), r1, a0, a1, n)
    i = cp.arc((0.0, 0.0), r0, a1, a0, n)
    return np.concatenate([o, i])


def field_grid_tiles():
    """The dark field between the diamond band and the ring: a regular grid turned 45 degrees (square to the diamond's
    edges, four cells along each of its sides, ~42 cm), clipped by the ring; the cell at each cardinal point (its inner
    tip on the band's tip) is a light stone. A clipped piece under ~600 cm2 merges into its inward neighbour (the union
    of two cells sharing a side is still a rectangle), so no sliver sits at the ring."""
    h = DI_OUT / math.sqrt(2.0)                       # the diamond's half side in the turned (s, t) frame
    c = h / 2.0
    L = [-2.0 * h + c * k for k in range(9)]          # 8 cells a side, -2h .. 2h
    nC = len(L) - 1
    circle = cp.arc((0.0, 0.0), M_FIELD, 0.0, 360.0, 96)[:-1]
    r2 = 1.0 / math.sqrt(2.0)

    def to_xy(rect_st):
        s0, s1, t0, t1 = rect_st
        st = np.array([(s0, t0), (s1, t0), (s1, t1), (s0, t1)])
        return np.column_stack([(st[:, 0] - st[:, 1]) * r2, (st[:, 0] + st[:, 1]) * r2])

    def clipped(rect_st):
        poly = to_xy(rect_st)
        for i in range(len(circle)):
            poly = cp.clip_half(poly, circle[i], circle[(i + 1) % len(circle)], True)
            if len(poly) < 3:
                return None
        return poly if abs(cp.area2(poly)) > 1.0 else None

    card = {(1, 1), (1, nC - 2), (nC - 2, 1), (nC - 2, nC - 2)}
    owner = {}
    rects = {}
    for i in range(nC):
        for j in range(nC):
            if 2 <= i < nC - 2 and 2 <= j < nC - 2:
                continue                              # inside the diamond band
            if clipped((L[i], L[i + 1], L[j], L[j + 1])) is None:
                continue
            owner[(i, j)] = (i, j)
            rects[(i, j)] = [L[i], L[i + 1], L[j], L[j + 1]]

    def area(key):
        poly = clipped(tuple(rects[key]))
        return 0.0 if poly is None else abs(cp.area2(poly))

    for key in sorted(list(rects), key=lambda k: -max(abs(k[0] - 3.5), abs(k[1] - 3.5))):
        if key not in rects or key in card or area(key) >= 600.0:
            continue
        i, j = key
        si, sj = (1 if i < 3.5 else -1), (1 if j < 3.5 else -1)
        steps = [(si, 0), (0, sj)] if abs(i - 3.5) >= abs(j - 3.5) else [(0, sj), (si, 0)]
        for di, dj in steps:
            nb = owner.get((i + di, j + dj))
            if nb is None or nb in card or nb not in rects:
                continue
            a_, b_ = rects[key], rects[nb]
            share = (abs(a_[2] - b_[2]) < 1e-6 and abs(a_[3] - b_[3]) < 1e-6 and
                     (abs(a_[1] - b_[0]) < 1e-6 or abs(a_[0] - b_[1]) < 1e-6)) or \
                    (abs(a_[0] - b_[0]) < 1e-6 and abs(a_[1] - b_[1]) < 1e-6 and
                     (abs(a_[3] - b_[2]) < 1e-6 or abs(a_[2] - b_[3]) < 1e-6))
            if not share:
                continue
            rects[nb] = [min(a_[0], b_[0]), max(a_[1], b_[1]), min(a_[2], b_[2]), max(a_[3], b_[3])]
            for k_, v_ in owner.items():
                if v_ == key:
                    owner[k_] = nb
            del rects[key]
            break
    tiles = []
    for key, rc in rects.items():
        poly = clipped(tuple(rc))
        if poly is not None:
            tiles.append((poly, "light" if key in card else "darkfield", False))
    return tiles


def medallion_tiles(rng):
    """(polygon, kind, flat) for every inlay stone, after concept 3: a quartered border, a light ring, a dark field,
    a broad light diamond band round a dark diamond with a small light centre, a light diamond at each cardinal point
    (the dark field is a regular 45-degree grid: field_grid_tiles)."""
    tiles = []
    # quartered border: four light key stones at the cardinal points, dark stones between
    key = 14.0
    rest = (90.0 - key) / 6.0
    for q in range(4):
        base = 90.0 * q
        tiles.append((sector(M_BORDER_IN, M_R, base - key / 2, base + key / 2), "light", False))
        for k in range(6):
            a0 = base + key / 2 + k * rest
            tiles.append((sector(M_BORDER_IN, M_R, a0, a0 + rest), "dark" if k % 2 == 0 else "mid", False))
    # the ring
    for k in range(20):
        tiles.append((sector(M_RING[0], M_RING[1], k * 18.0 + 4.0, (k + 1) * 18.0 + 4.0), "light", False))
    tiles += field_grid_tiles()
    for q in range(4):
        rot = 90.0 * q

        def R(p):
            return cp.rot_z(np.column_stack([np.asarray(p, float), np.zeros(len(p))]), rot)[:, :2]

        # the light diamond band (two stones a side) and the dark inner diamond (planar, it is walked on)
        band = np.array([(DI_IN, 0.0), (DI_OUT, 0.0), (0.0, DI_OUT), (0.0, DI_IN)])
        mid = 0.5 * (DI_IN + DI_OUT) * 0.5
        off = rng.uniform(-14.0, 14.0)              # the joint square across the band, off its middle
        for half in cp.split_by_line(band, (mid + off, mid - off), (mid + off + 30.0, mid - off + 30.0)):
            if len(half) >= 3:
                tiles.append((R(half), "light", False))
        tiles.append((R(np.array([(DI_C, 0.0), (DI_IN, 0.0), (0.0, DI_IN), (0.0, DI_C)])), "dark", True))
    tiles.append((np.array([(DI_C, 0.0), (0.0, DI_C), (-DI_C, 0.0), (0.0, -DI_C)]), "light", True))
    return tiles


def build_medallion():
    rng = np.random.default_rng(707)
    P = cp.Parts(("EnvStone",))
    for poly, kind, flat in medallion_tiles(rng):
        poly = cp.ccw2(poly)
        if cp.area2(poly) < 5.0:
            continue
        add_block(P, poly, 0.0, 3.0, "up", rng, kind=kind, ch=(0.5, 0.8), ch_h=0.7, chip_p=0.25, chip_cm=(0.5, 1.4),
                  drop_p=0.0 if flat else 0.15, drop_cm=(0.15, 0.4), jitter=0.0 if flat else 0.08,
                  dip=(0.0, 0.15), joint=0.4, flat_top=flat)
    obj = build(P, "FloorMedallion_A_Mars_SM")
    return obj, P


# ================================================================ Plinth_A
PLINTH_H = 88.0


def build_plinth():
    """A pedestal for urns and lanterns: a chipped base, an octagonal shaft tapering 2 cm toward the top with a lozenge
    boss on four faces, a step moulding under a cap stone set a degree off square, all cut like the sarcophagus plinth
    (2-4 cm chips on the base and cap)."""
    rng = np.random.default_rng(808)
    P = cp.Parts(("EnvStone",))
    base = rect(-25, -25, 25, 25) + rng.uniform(-0.5, 0.5, (4, 2))
    add_block(P, base, 0, 12, "up", rng, flat_top=True, ch=(1.2, 2.0), ch0=0.8, chip_p=0.75, chip_cm=(2.0, 4.0))
    h, c = 18.0, 6.0
    octa = [(-h + c, -h), (h - c, -h), (h, -h + c), (h, h - c), (h - c, h), (-h + c, h), (-h, h - c), (-h, -h + c)]
    add_block(P, octa, 11.5, 76, "up", rng, flat_top=True, ch=(1.0, 1.8), ch0=0.0, chip_p=0.6, chip_cm=(1.5, 2.5))
    # taper: the shaft narrows 2 cm (1 cm a side) from its foot to its head
    sv = P.v[-1]
    k = 1.0 - np.clip((sv[:, 2] - 12.0) / 64.0, 0.0, 1.0) * (1.0 / h)
    P.v[-1] = np.column_stack([sv[:, 0] * k, sv[:, 1] * k, sv[:, 2]])
    # the step moulding: an octagon 2.5 cm proud of the shaft head, its top hidden in the cap
    hm, cm_ = h + 1.5, c + 0.6
    mould = [(-hm + cm_, -hm), (hm - cm_, -hm), (hm, -hm + cm_), (hm, hm - cm_), (hm - cm_, hm), (-hm + cm_, hm),
             (-hm, hm - cm_), (-hm, -hm + cm_)]
    add_block(P, mould, 72.0, 76.4, "up", rng, flat_top=True, ch=(0.6, 1.0), ch0=0.8, chip_p=0.4, chip_cm=(1.0, 2.0))
    cap = cp.rot_z(np.column_stack([rect(-24, -24, 24, 24) + rng.uniform(-0.4, 0.4, (4, 2)), np.zeros(4)]), 1.2)[:, :2]
    add_block(P, cap, 76, PLINTH_H, "up", rng, kind="light", flat_top=True, ch=(1.2, 2.0), ch0=3.2, chip_p=0.75,
              chip_cm=(2.0, 4.0))
    for fr in ("front", "back", "east", "west"):
        boss = np.array([(0, 32), (7.5, 44), (0, 56), (-7.5, 44)])
        # sunk 0.8 cm into the tapered face so its foot never stands off it
        add_relief(P, boss, h - 1.35, 2.4 + 0.35, fr, rng, kind="fig", bevel=1.6, jitter=0.12)
    obj = build(P, "Plinth_A_Mars_SM")
    sc.add_socket(obj, "Top", (0.0, 0.0, PLINTH_H))
    sc.box_ucx(obj, (0.0, 0.0, 6.0), (50.0, 50.0, 12.0))
    sc.box_ucx(obj, (0.0, 0.0, 44.0), (36.0, 36.0, 64.0))
    sc.add_ucx(obj, np.concatenate([np.column_stack([cap, np.full(4, z)]) for z in (76.0, PLINTH_H)]))
    return obj, P


# ================================================================ rubble
def chunk_points(size, rng, cuts=1):
    """Corner-chipped, plane-broken box points (cm, centred) for a chunky convex rubble stone."""
    sx, sy, sz = np.asarray(size, float) * 0.5
    pts = []
    for cx in (-1, 1):
        for cy in (-1, 1):
            for cz in (-1, 1):
                c = np.array([cx * sx, cy * sy, cz * sz])
                if rng.uniform() < 0.7:
                    for ax in range(3):
                        q = c.copy()
                        q[ax] -= np.sign(c[ax]) * rng.uniform(0.12, 0.38) * 2.0 * [sx, sy, sz][ax]
                        pts.append(q)
                else:
                    pts.append(c * rng.uniform(0.9, 1.0))
    pts = np.array(pts) + rng.uniform(-0.04, 0.04, (len(pts), 3)) * np.array([sx, sy, sz])
    for _ in range(cuts):
        nrm = cp._n(rng.normal(size=3))
        d = rng.uniform(0.35, 0.75) * float(np.abs(pts @ nrm).max())
        h = pts @ nrm
        over = h > d
        pts[over] -= np.outer(h[over] - d, nrm)
    return pts


def ashlar_points(size, rng, cuts=1, chamfer=(0.8, 2.0), depth=(0.66, 0.84)):
    """Broken masonry: a squared block (straight arrises, every edge chamfered, each face exactly planar) with one or
    two fracture planes cut through a corner or an edge."""
    sx, sy, sz = np.asarray(size, float) * 0.5
    pts = []
    for cx in (-1, 1):
        for cy in (-1, 1):
            for cz in (-1, 1):
                c = np.array([cx * sx, cy * sy, cz * sz])
                d = rng.uniform(*chamfer, 3) * np.array([-cx, -cy, -cz])
                pts += [c + np.array([d[0], d[1], 0.0]), c + np.array([0.0, d[1], d[2]]), c + np.array([d[0], 0.0, d[2]])]
    pts = np.array(pts)
    for _ in range(cuts):
        nrm = cp._n(np.array([rng.choice((-1, 1)) * rng.uniform(0.4, 1.0) for _ in range(3)]))
        d = rng.uniform(*depth) * float((pts @ nrm).max())
        h = pts @ nrm
        over = h > d
        pts[over] -= np.outer(h[over] - d, nrm)
    return pts


def drop_onto(v, xy, placed, sink=0.5):
    """Translate chunk verts v (any z) to xy and lower it until it rests on the floor or on the placed geometry
    (sampled under its vertices), then sink it a little so it touches without a gap."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    v = v - np.array([v[:, 0].mean(), v[:, 1].mean(), v[:, 2].min()]) + np.array([xy[0], xy[1], 0.0])
    lift = 0.0
    if placed:
        pv = np.concatenate([p[0] for p in placed])
        pf, base = [], 0
        for vv, ff in placed:
            pf += [[base + i for i in face] for face in ff]
            base += len(vv)
        tree = BVHTree.FromPolygons(pv.tolist(), pf)
        z0 = v[:, 2].min()
        lifts = []
        for p in v:
            hit = tree.ray_cast(Vector((p[0], p[1], 500.0)), Vector((0.0, 0.0, -1.0)))
            lifts.append(max(hit[0][2] - (p[2] - z0), 0.0) if hit[0] is not None else 0.0)
        # settle into the heap: rest on the 60th percentile of the support under it and sink a fifth of its height
        # (chunks interpenetrate like a real heap instead of balancing on one high corner and stacking into a tower)
        lift = float(np.percentile(lifts, 60))
        if lift > 0.0:
            lift = max(lift - max(sink, 0.2 * float(np.ptp(v[:, 2]))), 0.0)
    v[:, 2] += lift
    return v


RUB_TILT = 10.0           # Rubble_B's fallen ashlar: degrees its -x end is sunk


def broken_ashlar(rng):
    """Rubble_B's fallen ashlar (60 x 40 x 30): worn 2-3 cm chamfers on its intact edges, one top corner knocked off by a
    35-degree fracture plane, a ~9 cm bite out of its front top edge, tilted RUB_TILT degrees so its -x end is sunk
    into the floor (cut flat at z = 0). Returns (verts, tris, tags, the knocked-off corner piece's points)."""
    pts = ashlar_points((60.0, 40.0, 30.0), rng, cuts=0, chamfer=(2.0, 3.0))
    n = cp._n(np.array([0.45, 0.33, 0.83]))                 # 33-35 degrees off vertical, over the +x +y top corner
    d = float(np.array([30.0, 20.0, 15.0]) @ n) - 10.0
    v, f = cp.clip_hull(pts, n, d)
    corner = np.concatenate([pts[(pts @ n) > d], v[np.abs(v @ n - d) < 1e-6]])
    # the bite out of the front top edge (y = -20, z = 15): a jagged convex notch ~20 cm long, ~9 cm into both faces
    sec = np.array([(-26.0, 21.0), (-8.5, 19.0), (-13.0, 10.5), (-23.5, 6.0)])
    bite = []
    edge = np.array([-20.0, 15.0])                  # the arris the bite is taken from: its ends taper into it
    for x, k in ((-21.0, 0.12), (-13.0, 1.0), (1.5, 0.9), (9.0, 0.12)):
        q = edge + (sec - edge) * k
        bite += [(x, y, z) for y, z in q]
    bite = np.array(bite)
    sink = np.array([0.0, 0.0, -5.0 - float(cp.rot_axis(v, Y, -RUB_TILT)[:, 2].min())])    # low end 5 cm under the floor
    tilt = lambda p: cp.rot_axis(p, Y, -RUB_TILT) + sink
    v, bite_w, n_w = tilt(v), tilt(bite), cp.rot_axis(n[None, :], Y, -RUB_TILT)[0]
    floor = sc.box((0.0, 0.0, -40.0), (200.0, 200.0, 80.0))
    bv, bf = cp.hull(bite_w, dissolve_deg=0.0)
    v2, f2 = cp.boolean_mesh((v, f), [(bv, bf), (np.asarray(floor[0], float), floor[1])])
    planes = [(cp.newell(bv[ff]), float(cp.newell(bv[ff]) @ bv[ff[0]])) for ff in bf]
    tags = []
    for tri in f2:
        p = v2[tri]
        c = p.mean(axis=0)
        nn = cp.newell(p)
        if nn[2] < -0.99 and c[2] < 0.05:
            tags.append("stone/bottom")
        elif float(nn @ n_w) > 0.995 or all(float(pn @ c) <= pd + 0.1 for pn, pd in planes):
            tags.append("light/chip")                   # fresh fracture faces
        else:
            tags.append("stone/side")
    return v2, f2, tags, corner


def build_rubble(name, recipe, seed, hero=False):
    rng = np.random.default_rng(seed)
    P = cp.Parts(("EnvStone",))
    placed = []
    for k_, (size, xy, cuts, tilt) in enumerate(recipe):
        L = max(size)
        if hero and k_ == 0:
            v, f, tags, corner = broken_ashlar(rng)
            v = drop_onto(v, xy, placed)
            placed.append((v, f))
            P.add(v, f, "EnvStone", tags)
            # the knocked-off corner, fallen and leaning against the block's raised (+x) end, fracture face up
            cv, cf = cp.hull(cp.rot_axis(corner - corner.mean(axis=0), X, 150.0), dissolve_deg=1.0)
            cv = cp.rot_axis(cv, Y, -28.0)
            cv = drop_onto(cv, (float(v[:, 0].max()) + 4.0, 4.0), placed, sink=1.0)
            placed.append((cv, cf))
            P.add(cv, cf, "EnvStone", "light/side")
            continue
        if L >= 12.0:          # broken masonry (~60% of the chunks): squared 1 : 0.6 : 0.4 blocks with fractures
            dims = size if L >= 50.0 else (L, 0.6 * L, 0.4 * L)
            pts = ashlar_points(dims, rng, cuts, chamfer=(0.04 * min(dims), 0.09 * min(dims)),
                                depth=(0.8, 0.88) if L >= 50.0 else (0.66, 0.84))
            tilt = min(tilt, 8.0)
        else:                  # chips: chunky convex hulls
            pts = chunk_points(size, rng, cuts)
        pts = cp.rot_axis(pts, cp._n(rng.normal(size=3) * np.array([1, 1, 0.1])), tilt * rng.uniform(-1, 1))
        pts = cp.rot_z(pts, rng.uniform(0, 360))
        v, f = cp.hull(pts, dissolve_deg=1.0)
        v = drop_onto(v, xy, placed)
        placed.append((v, f))
        kind = "light" if rng.uniform() < 0.25 else ("mid" if rng.uniform() < 0.3 else "stone")
        P.add(v, f, "EnvStone", "%s/side" % kind)
    obj = build(P, name)
    v = fc.verts_cm(obj)
    lo, hi = v.min(axis=0), v.max(axis=0)
    fc.set_verts_cm(obj, v - np.array([(lo[0] + hi[0]) * 0.5, (lo[1] + hi[1]) * 0.5, lo[2]]))
    return obj, P


RUBBLE = {
    "Rubble_A": ([((36, 27, 21), (-14, -6), 1, 10), ((31, 24, 18), (16, 8), 1, 12), ((24, 19, 15), (-4, 18), 1, 15),
                  ((22, 17, 13), (2, -16), 2, 25), ((19, 15, 12), (-28, 14), 1, 20), ((17, 13, 11), (30, -12), 1, 25),
                  ((15, 12, 9), (0, 2), 2, 30), ((13, 10, 8), (-32, -16), 1, 30), ((11, 9, 7), (-8, 6), 1, 35),
                  ((10, 8, 6), (34, 18), 1, 30), ((9, 7, 5), (10, -26), 1, 30), ((8, 6, 5), (-18, 28), 1, 30)], 911),
    "Rubble_B": ([((60, 40, 30), (0, 0), 1, 3), ((19, 15, 13), (30, 30), 1, 20), ((16, 13, 11), (-42, -6), 1, 25),
                  ((13, 11, 9), (12, -27), 1, 30), ((11, 9, 8), (-14, 26), 2, 30), ((10, 8, 7), (46, -14), 1, 30),
                  ((9, 7, 5), (-34, 20), 1, 35), ((8, 7, 5), (28, 24), 1, 35), ((7, 6, 4), (-48, 10), 1, 40)], 912),
    # one fan-shaped spill of chips: dense at the -x end, thinning and spreading over ~90 cm
    "Rubble_C": ([((18, 14, 7), (-40, -2), 1, 10), ((15, 13, 6), (-30, 9), 1, 12), ((14, 10, 5), (-29, -12), 1, 14),
                  ((12, 10, 5), (-44, 12), 1, 15), ((12, 9, 5), (-19, 1), 1, 15), ((10, 8, 4), (-10, -13), 1, 18),
                  ((11, 9, 4), (-7, 13), 1, 15), ((9, 7, 4), (3, -2), 1, 18), ((8, 7, 3), (14, 17), 1, 20),
                  ((8, 6, 3), (17, -18), 1, 20), ((7, 6, 3), (29, 6), 1, 20), ((7, 5, 3), (36, -25), 1, 20),
                  ((6, 5, 3), (45, 23), 1, 20), ((6, 5, 3), (50, -6), 1, 20)], 913),
}


# ================================================================ table of meshes
# name -> (builder, TRIS category, pivot rule, expected (x, y, z) cm or None, sockets, ucx wanted)
MESHES = {
    "Sarcophagus_A": (build_sarcophagus, "furniture", "floor", (240, 120, SARC_H), ("LidEdge",), True),
    "HoodedStatue_A": (lambda: build_statue("A"), "furniture", "floor", (None, None, 193), (), True),
    "HoodedStatue_B": (lambda: build_statue("B"), "furniture", "floor", (None, None, None), (), True),
    "StatueNiche_A": (build_statue_niche, "furniture", "wall", (120, 50, 280), ("Statue",), True),
    "CandleNiche_A": (build_candle_niche, "prop", "wall", (60, None, 90), ("Candle", "LedgeEdge"), False),
    "Urn_A": (build_urn_a, "prop", "floor", (None, None, 70), (), False),
    "Urn_B": (build_urn_b, "prop", "floor", (None, None, 55), (), False),
    "Urn_C": (build_urn_c, "prop", "floor", (None, None, 45), (), False),
    "UrnBroken_A": (build_urn_broken, "prop", "floor", None, (), False),
    "SigilDoor_A": (build_sigil_door, "furniture", "wall", (300, None, 450), (), True),
    "FloorMedallion_A": (build_medallion, "furniture", "floor", (400, 400, 3), (), False),
    "Rubble_A": (lambda: build_rubble("Rubble_A_Mars_SM", *RUBBLE["Rubble_A"]), "cluster", "floor", None, (), False),
    "Rubble_B": (lambda: build_rubble("Rubble_B_Mars_SM", *RUBBLE["Rubble_B"], hero=True), "cluster", "floor", None, (),
                 False),
    "Rubble_C": (lambda: build_rubble("Rubble_C_Mars_SM", *RUBBLE["Rubble_C"]), "cluster", "floor", None, (), False),
    "Plinth_A": (build_plinth, "prop", "floor", (None, None, PLINTH_H), ("Top",), True),
}


# ================================================================ checks
def check_mesh(name, obj, parts, fails, infos):
    _, cat, rule, dims, sockets, want_ucx = MESHES[name]
    probs = []
    tris = fc.tri_count(obj)
    budget = spec.TRIS[cat]
    if tris > budget:
        probs.append("tris %d > %s budget %d" % (tris, cat, budget))
    slots = [m.name for m in obj.data.materials]
    used = sorted({int(p.material_index) for p in obj.data.polygons})
    for s in slots:
        if s not in spec.SLOTS:
            probs.append("slot %s not in env_spec" % s)
    if len(used) != len(slots):
        probs.append("unused slots %s" % [slots[i] for i in range(len(slots)) if i not in used])
    if "Col" not in obj.data.color_attributes:
        probs.append("no Col")
    if "UVMap" not in obj.data.uv_layers:
        probs.append("no UVMap")
    if any(p.use_smooth for p in obj.data.polygons):
        probs.append("smooth faces")
    # a zero-area triangle has no normal of its own: the FBX gives its corners a flipped split normal (not flat)
    degen = [p.index for p in obj.data.polygons if p.area * 1e4 < 1e-3]
    if degen:
        probs.append("degenerate triangles %s" % degen[:6])
    lo, hi = fc.bounds_cm(obj)
    size = hi - lo
    if abs(lo[2]) > 0.01:
        probs.append("min z %.3f != 0" % lo[2])
    if rule == "floor":
        # env_spec: the XY centre of the FOOTPRINT: the bounds of the lower half (what stands on the floor), so the
        # overhang of a slid lid does not move it
        vv = fc.verts_cm(obj)
        foot = vv[vv[:, 2] < 0.5 * hi[2]]
        c = 0.5 * (foot.min(axis=0) + foot.max(axis=0))
        if abs(c[0]) > 1.0 or abs(c[1]) > 1.0:
            probs.append("footprint not centred (%.2f, %.2f)" % (c[0], c[1]))
    else:
        if abs(hi[1]) > 0.01:
            probs.append("back plane max y %.3f != 0" % hi[1])
        if abs(0.5 * (lo[0] + hi[0])) > 1.0:
            probs.append("not centred in x (%.2f)" % (0.5 * (lo[0] + hi[0])))
    if dims:
        for ax, want in enumerate(dims):
            if want is not None and abs(size[ax] - want) > 0.05 * want + 0.5:
                probs.append("size %s %.1f (want %.0f)" % ("xyz"[ax], size[ax], want))
    isl = cp.island_report(obj)
    open_ = [k for k, n, closed, vol in isl if not closed]
    inv = [k for k, n, closed, vol in isl if vol <= 0.0]
    if open_:
        probs.append("open islands %s" % open_[:6])
    if inv:
        probs.append("inverted islands %s" % inv[:6])
    zf = cp.zfight_report(obj)
    if zf:
        probs.append("coplanar overlaps %s" % [(parts.tag[a], parts.tag[b], ar, c) for a, b, ar, c in zf[:3]])
    fl = cp.floating_report(obj, cp.ground_floor if rule == "floor" else cp.ground_wall)
    if fl:
        probs.append("floating islands %s" % fl[:4])
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
    if name in JOINTS:
        bad = joint_ray_report(obj, JOINTS[name])
        if bad:
            probs.append("see-through joints %d rays, e.g. %s" % (len(bad), bad[:4]))
    infos[name] = {"tris": tris, "budget": budget, "size_cm": [round(float(x), 1) for x in size], "slots": slots,
                   "sockets": have, "ucx": len(ucx), "islands": len(isl)}
    print("CHECK %-18s tris %5d / %-5d size %s slots %s sockets %s ucx %d islands %d %s" % (
        name, tris, budget, infos[name]["size_cm"], slots, have, len(ucx), len(isl),
        "ok" if not probs else "FAIL " + "; ".join(probs)))
    for p in probs:
        fails.append("%s: %s" % (name, p))


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
            if r["uv_layers"][:1] != ["UVMap"]:
                probs.append("uv %s" % r["uv_layers"])
            if "Col" not in r["colors"]:
                probs.append("colors %s" % r["colors"])
            if not r["flat"]:
                probs.append("not flat")
        print("REIMPORT %s %s" % (name, "ok" if not probs else "FAIL " + "; ".join(probs)))
        for p in probs:
            fails.append("%s reimport: %s" % (name, p))


# ================================================================ review sheets
def sheet_row(objs, stem, views=(("iso", (1.0, -1.25, 0.6)), ("front", (0.0, -1.0, 0.0))), size=(1800, 900),
              gap=0.18, chef=True):
    """Copies laid out left to right on a common floor (gap x the widest piece), a 150 cm chef box at the left end,
    rendered from each view; tiled into REVIEW_DIR/<stem>_sheet.png."""
    copies, x = [], 0.0
    widths = [float(np.ptp(fc.verts_cm(o)[:, 0])) for o in objs]
    pad = max(widths) * gap
    if chef:
        copies.append(cp.painted_box("_Chef150", (x + 22.5, 0.0, 75.0), (45.0, 30.0, 150.0), fc.srgb(226, 222, 210)))
        x += 45.0 + pad
    for o, w in zip(objs, widths):
        v = fc.verts_cm(o)
        c = cp.copy_mesh(o, offset=(x - v[:, 0].min(), 0.0, 0.0))
        copies.append(c)
        x += w + pad
    paths = [cp.render_view(copies, os.path.join(spec.REVIEW_DIR, "%s_%s.png" % (stem, k)), d, size=size)
             for k, d in views]
    for c in copies:
        cp.remove_object(c)
    return fc.tile_images(paths, os.path.join(spec.REVIEW_DIR, "%s_sheet.png" % stem), cols=1)


def render_sheets(built):
    rd = spec.REVIEW_DIR
    out = []
    # the env_common contact sheets per group
    groups = (("crypt_furniture", ["Sarcophagus_A", "HoodedStatue_A", "HoodedStatue_B", "StatueNiche_A"]),
              ("crypt_walls", ["SigilDoor_A", "StatueNiche_A", "CandleNiche_A"]),
              ("crypt_urns", ["Urn_A", "Urn_B", "Urn_C", "UrnBroken_A", "Plinth_A"]),
              ("crypt_rubble", ["Rubble_A", "Rubble_B", "Rubble_C"]),
              ("crypt_medallion", ["FloorMedallion_A"]))
    for stem, names in groups:
        objs = [built[n][0] for n in names if n in built]
        if objs:
            out.append(ec.review(objs, stem))
    # scale line-ups next to a 150 cm chef box
    for stem, names in (("crypt_lineup", ["SigilDoor_A", "StatueNiche_A", "Sarcophagus_A", "HoodedStatue_A",
                                          "HoodedStatue_B", "CandleNiche_A", "Plinth_A", "Urn_A", "Urn_B", "Urn_C",
                                          "UrnBroken_A", "Rubble_A", "Rubble_B", "Rubble_C"]),):
        objs = [built[n][0] for n in names if n in built]
        if objs:
            out.append(sheet_row(objs, stem, size=(2400, 900)))
    # hero close-ups
    if "Sarcophagus_A" in built:
        o = built["Sarcophagus_A"][0]
        paths = [cp.render_view([o], os.path.join(rd, "crypt_sarcophagus_iso.png"), None, size=(1600, 1000),
                                target_cm=(0, 0, 55), eye_cm=(260, -330, 190), lens=35, ortho=False),
                 cp.render_view([o], os.path.join(rd, "crypt_sarcophagus_relief.png"), (0.0, -1.0, 0.0),
                                size=(1600, 1000), target_cm=(0, -40, 64), half_cm=95),
                 cp.render_view([o], os.path.join(rd, "crypt_sarcophagus_figure.png"), None, size=(1600, 1000),
                                target_cm=(-40, -36, 64), eye_cm=(-5, -150, 85), lens=40, ortho=False),
                 cp.render_view([o], os.path.join(rd, "crypt_sarcophagus_end.png"), None, size=(1600, 1000),
                                target_cm=(60, 0, 62), eye_cm=(330, -170, 140), lens=40, ortho=False)]
        out.append(fc.tile_images(paths, os.path.join(rd, "crypt_sarcophagus_close_sheet.png"), cols=2))
    if "HoodedStatue_A" in built and "StatueNiche_A" in built:
        tmp = []
        for k, (n, x) in enumerate((("HoodedStatue_A", -70.0), ("HoodedStatue_B", 70.0))):
            if n in built:
                tmp.append(cp.copy_mesh(built[n][0], offset=(x, 0.0, 0.0)))
        niche = cp.copy_mesh(built["StatueNiche_A"][0], offset=(260.0, 60.0, 0.0))
        st = cp.copy_mesh(built["HoodedStatue_A"][0], offset=np.array(N_SOCKET) + np.array([260.0, 60.0, 0.0]))
        paths = [cp.render_view(tmp, os.path.join(rd, "crypt_statues_hoods.png"), None, size=(1600, 1000),
                                target_cm=(0, 0, 160), eye_cm=(50, -300, 150), lens=55, ortho=False),
                 cp.render_view(tmp, os.path.join(rd, "crypt_statues_front.png"), (0.0, -1.0, 0.0), size=(1600, 1000)),
                 cp.render_view(tmp, os.path.join(rd, "crypt_statues_side.png"), (1.0, -0.2, 0.05), size=(1600, 1000)),
                 cp.render_view([niche, st], os.path.join(rd, "crypt_niche_statue.png"), None, size=(1600, 1000),
                                target_cm=(260, 30, 140), eye_cm=(420, -380, 210), lens=35, ortho=False)]
        for o in tmp + [niche, st]:
            cp.remove_object(o)
        out.append(fc.tile_images(paths, os.path.join(rd, "crypt_statues_close_sheet.png"), cols=2))
    if "SigilDoor_A" in built:
        o = built["SigilDoor_A"][0]
        paths = [cp.render_view([o], os.path.join(rd, "crypt_sigil_front.png"), (0.0, -1.0, 0.0), size=(1000, 1400)),
                 cp.render_view([o], os.path.join(rd, "crypt_sigil_close.png"), None, size=(1000, 1400),
                                target_cm=(0, -20, 200), eye_cm=(140, -260, 120), lens=35, ortho=False)]
        out.append(fc.tile_images(paths, os.path.join(rd, "crypt_sigil_close_sheet.png"), cols=2))
    if "CandleNiche_A" in built:
        o = built["CandleNiche_A"][0]
        paths = [cp.render_view([o], os.path.join(rd, "crypt_candleniche_front.png"), (0.0, -1.0, 0.0),
                                size=(1000, 1200)),
                 cp.render_view([o], os.path.join(rd, "crypt_candleniche_iso.png"), (0.8, -1.0, 0.35),
                                size=(1000, 1200))]
        out.append(fc.tile_images(paths, os.path.join(rd, "crypt_candleniche_sheet.png"), cols=2))
    if "FloorMedallion_A" in built:
        o = built["FloorMedallion_A"][0]
        paths = [cp.render_view([o], os.path.join(rd, "crypt_medallion_top.png"), (0.0, -0.001, 1.0),
                                size=(1200, 1200)),
                 cp.render_view([o], os.path.join(rd, "crypt_medallion_low.png"), None, size=(1200, 1200),
                                target_cm=(0, 0, 0), eye_cm=(120, -420, 160), lens=30, ortho=False)]
        out.append(fc.tile_images(paths, os.path.join(rd, "crypt_medallion_close_sheet.png"), cols=2))
    for m in list(bpy.data.materials):
        if m.users == 0:
            bpy.data.materials.remove(m)
    return out


# ================================================================ main
def finish(name, obj, parts):
    glow = "EnvGlowSpirit" in parts.slots
    cp.paint_parts(obj, parts, stone_painter(zlib.crc32(name.encode()) % 1000 + 17), glow_slot="EnvGlowSpirit" if glow else None,
                   glow_rgb=GLOW)
    fc.smart_uv(obj)


def main():
    args = fc.cli_args({"export": False, "save": False, "sheets": False, "only": ""})
    t0 = time.time()
    fc.ensure_dirs()
    fc.clear_scene()
    bpy.context.scene.view_settings.view_transform = "Standard"
    fails, infos, built = [], {}, {}
    only = args["only"] if isinstance(args["only"], str) else ""
    for name, row in MESHES.items():
        if only and only.lower() not in name.lower():
            continue
        t1 = time.time()
        obj, parts = row[0]()
        finish(name, obj, parts)
        built[name] = (obj, parts)
        check_mesh(name, obj, parts, fails, infos)
        print("  built %s in %.1fs" % (name, time.time() - t1))
    paths = []
    if args["export"]:
        for name, (obj, parts) in built.items():
            extra = {"pivot": MESHES[name][2], "tris_category": MESHES[name][1]}
            if name == "SigilDoor_A":
                extra["glow_note"] = "groove floors are EnvGlowSpirit faces (Col = the glow colour, A = 1)"
            if name == "StatueNiche_A":
                extra["fits"] = "HoodedStatue_A / _B on SOCKET_Statue (recess 92 W x 45 D, apex z %.1f)" % (
                    N_SPRING + math.sqrt(N_R ** 2 - (N_R - N_HALF) ** 2))
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
        print("  %-18s tris %5d  size %s  slots %s  sockets %s  ucx %d" % (name, i["tris"], i["size_cm"], i["slots"],
                                                                         i["sockets"], i["ucx"]))
    print("\nsheets:", *sheets, sep="\n  ")
    print("total %.1fs" % (time.time() - t0))
    if fails:
        print("ENV_CRYPT_FAIL", *fails, sep="\n  ")
    else:
        print("ENV_CRYPT_OK")


main()
