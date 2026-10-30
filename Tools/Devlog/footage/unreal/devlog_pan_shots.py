"""The pan showcase footage (Tools/Devlog/episodes/pan_showcase): a kernel replay on the devlog stage's cooking bay.

Editor side (a hidden MarsEditor on 9317 through Monolith; never Stephen's 9316). The host runner is run_pan.py:

    python run_pan.py --shot all --draft         # 960x540, every 10th frame, into the session scratchpad drafts/
    python run_pan.py --shot sear_flip           # 1920x1080 (rendered at 2x, the host downsamples) @ 30 fps
    python run_pan.py --import-pieces            # SlabPiece_A..D_Mars_SM -> /Game/Mars/Devlog/Pieces (MeatSlab_Mars_MI)

Shooting method A ("kernel replay", STORYBOARD_PROPOSAL.md): nothing here runs the game. Each shot is a scripted motion of
its pieces (drops, flips, a toss) in the hero pan's own frame, and a per-frame replay of what the searing kernel and the
station's dressing would write for that motion, with their own numbers (cited at each constant below):

  kernel  Script/ECS/Searing/   the face on the pan = the local axis pointing most downward; it sears dt / SecondsPerFace
                                toward 1 (never past it) while the piece rests on the hot pan; the aggregate sizzle is on
                                while any cooking piece rests on a face below 1.
  display Script/Common/Mars_CookState.as (Make_DisplayParams): Penetration = min(1, sum of sears), Shape = sum / 6; the
                                14-float CPD block, per piece (face values are never averaged across pieces).
  station Script/WorldObjects/Stations/Mars_SearingStation_EntityScript.as: per piece its own pool slot (footprint radius
                                h * sqrt2 * 0.9 by the face it lies on, shrinking with lift over PoolLiftFadeCm), a trail
                                lagging by TrailLagSeconds, the sizzle ramp (rise 2 / fall 1 per s, 0.4 over a seared
                                face), the fond (start 0.1, +0.02 / s while sizzling), the oil coat (0.7 on the hot pan,
                                1 / s), the shared pool scalars from the largest piece on the pan.

Every frame: pieces' transforms + Custom Primitive Data, the hero pan's MaterialInstanceDynamic (a transient MID over
DevlogPanA_Mars_MI; the instance itself is never written), then a SceneCapture2D frame at frozen material time
t0 + i / 30. The test in the session (2026-10-25) showed all three reach the renderer inside one call, so a frame is
set + capture in the same call (the stage stills' tick was for the MIC edit). Nothing is saved: the map is never saved,
the spawned pieces and the MID are undone by finish().
"""
import json
import math
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import devlog_unreal_shots as ds  # noqa: E402
import mars_devlog_stage_ue as st  # noqa: E402

OUT = r"D:\Repo\Content\Devlog\pan_showcase"
SCRATCH = r"C:\Users\Stephen\AppData\Local\Temp\claude\D--Repo-Mars\5f3efb8e-b134-46b6-83b7-6ce0a5233bff\scratchpad\pan_agent"
DRAFT_ROOT = os.path.join(SCRATCH, "drafts")
RAW_ROOT = os.path.join(SCRATCH, "raw")
PIECES_SRC = os.path.join(OUT, "_pieces")
PIECES_DST = "/Game/Mars/Devlog/Pieces"
SLAB_MI = "/Game/Mars/Gameplay/Cooking/Food/Materials/Instances/MeatSlab_Mars_MI"
FPS = 30.0
DT = 1.0 / FPS
DRAFT_STEP = 10
TAG = "DevlogPan"

# ---------------------------------------------------------------- the kernel's and the station's numbers
SECONDS_PER_FACE = 3.0        # Mars_Searing_Feature.as:74  FMars_Searing_CookSpec.SecondsPerFace
SEAR_CAP = 1.0                # Mars_Searing_Processor_Tick.as:245  Math::Min(1.0f, Before + dt / SecondsPerFace)
MAX_PIECES = 6                # Mars_Searing_Feature.as:60  FMars_Searing_SupplySpec.MaxPieces
POOL_SLOTS = 6                # Mars_SearingStation_EntityScript.as:148  k_PoolSlots
PAN_RADIUS = 34.0 / 2.5       # Feature.as:124 LossSpec.PanRadius 34 uu on a PanScale 2.5 pan (EntityScript.as:102)
PAN_RIM_RADIUS = 14.5         # EntityScript.as:103  PanRimRadius (pan mesh cm): a piece over it keeps a closing pool
FOOTPRINT_PER_HALF = math.sqrt(2.0) * 0.9   # EntityScript.as:110
POOL_RADIUS_PER_HALF = 1.1    # EntityScript.as:111..115: Pool Radius / Margin / Blend / Simmer Width / Contact Softness
POOL_MARGIN_PER_HALF = 0.6
POOL_BLEND_PER_HALF = 0.5
SIMMER_WIDTH_PER_HALF = 0.4
CONTACT_SOFT_PER_HALF = 0.4
SIZZLE_FULL = 1.0             # EntityScript.as:136..142
SIZZLE_SEARED_FACE = 0.4
SIZZLE_RISE = 2.0
SIZZLE_FALL = 1.0
FOND_START = 0.1
FOND_RATE = 0.02
TRAIL_LAG = 0.25              # EntityScript.as:143  TrailLagSeconds
POOL_LIFT_FADE_CM = 4.0       # EntityScript.as:145  PoolLiftFadeCm (art cm = the pan mesh's cm)
OIL_COAT_ON_PAN = 0.7         # EntityScript.as:149..152
OIL_COAT_OFF_PAN = 0.3
OIL_COAT_RATE = 1.0
CONTACT_EPS = 0.05            # cm: a piece whose underside is this close to the cooking surface rests on it
FACES = ("+X", "-X", "+Y", "-Y", "+Z", "-Z")   # EMars_FoodPiece_Face order (CPD 0..5)
NORMALS = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))

# the stage look kept as approved (PAN_LOOK: Oil Amount 0.9, Seasoning 0.2, Oil Opacity 0.5 ...); only the driven group
# and the pool scalars are the station's
PAN_SURFACE_Z = st.HOB + st.PAN_Z

# meshes: key -> (asset path, actor scale, material override or None)
MESHES = {
    "cube": (st.CUBE, 1.0, None),
    "A": (PIECES_DST + "/SlabPiece_A_Mars_SM", None, SLAB_MI),
    "B": (PIECES_DST + "/SlabPiece_B_Mars_SM", None, SLAB_MI),
    "C": (PIECES_DST + "/SlabPiece_C_Mars_SM", None, SLAB_MI),
    "D": (PIECES_DST + "/SlabPiece_D_Mars_SM", None, SLAB_MI),
}
# slab pieces come off a 37 cm slab; on the stage pan (the station's PanScale 2.5 pan at scale 1) they stand at 1 / 2.5
PIECE_SCALE = 0.4


# ====================================================================================== small maths (pure python)
def _mm(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def _mv(m, v):
    return tuple(sum(m[i][k] * v[k] for k in range(3)) for i in range(3))


def rz(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[c, -s, 0.0], [s, c, 0.0], [0.0, 0.0, 1.0]]


def rx(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[1.0, 0.0, 0.0], [0.0, c, -s], [0.0, s, c]]


def ry(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[c, 0.0, s], [0.0, 1.0, 0.0], [-s, 0.0, c]]


def _quat(m):
    """Rotation matrix -> (x, y, z, w) (standard; FQuat rotates vectors with the same maths)."""
    tr = m[0][0] + m[1][1] + m[2][2]
    if tr > 0:
        s = math.sqrt(tr + 1.0) * 2
        return ((m[2][1] - m[1][2]) / s, (m[0][2] - m[2][0]) / s, (m[1][0] - m[0][1]) / s, 0.25 * s)
    if m[0][0] > m[1][1] and m[0][0] > m[2][2]:
        s = math.sqrt(1.0 + m[0][0] - m[1][1] - m[2][2]) * 2
        return (0.25 * s, (m[0][1] + m[1][0]) / s, (m[0][2] + m[2][0]) / s, (m[2][1] - m[1][2]) / s)
    if m[1][1] > m[2][2]:
        s = math.sqrt(1.0 + m[1][1] - m[0][0] - m[2][2]) * 2
        return ((m[0][1] + m[1][0]) / s, 0.25 * s, (m[1][2] + m[2][1]) / s, (m[0][2] - m[2][0]) / s)
    s = math.sqrt(1.0 + m[2][2] - m[0][0] - m[1][1]) * 2
    return ((m[0][2] + m[2][0]) / s, (m[1][2] + m[2][1]) / s, 0.25 * s, (m[1][0] - m[0][1]) / s)


def ease(u):
    u = min(max(u, 0.0), 1.0)
    return 0.5 - 0.5 * math.cos(math.pi * u)


def smooth(u):
    u = min(max(u, 0.0), 1.0)
    return u * u * (3.0 - 2.0 * u)


def half_z(m, half):
    """World half height of a box of half extents `half` under rotation m (utils_foodpiece::Get_WorldHalfExtentZ)."""
    return abs(m[2][0]) * half[0] + abs(m[2][1]) * half[1] + abs(m[2][2]) * half[2]


def down_face(m):
    """utils_foodpiece::Get_DownFace: the local axis normal pointing most downward after the rotation."""
    best, idx = 2.0, 5
    for k, n in enumerate(NORMALS):
        z = _mv(m, n)[2]
        if z < best:
            best, idx = z, k
    return idx


def footprint_half(half, face):
    """utils_searing::Get_FootprintHalf (Mars_Searing_Utils.as:128): the mean of the two half extents across the pan."""
    ax = face // 2
    a, b = [half[i] for i in range(3) if i != ax]
    return (a + b) * 0.5


def finterp_const(cur, target, dt, rate):
    step = rate * dt
    d = target - cur
    return target if abs(d) <= step else cur + math.copysign(step, d)


# ====================================================================================== motion
class Track:
    """A piece's motion in the pan's frame: key poses (t, x, y, yaw, flip_x, flip_y) joined by moves. The centre rests on
    the pan (its underside on the cooking surface) unless a move lifts it: 'drop' falls from `height` (cm, underside)
    under gravity with a small settle bounce; 'hop' carries it along an arc of peak `height` while it turns."""

    def __init__(self, t, x, y, yaw, flip_x=0.0, flip_y=0.0):
        self.keys = [dict(t=t, x=x, y=y, yaw=yaw, fx=flip_x, fy=flip_y, kind="rest")]

    def drop(self, t_land, from_xy=None, height=16.0, spin=12.0, wobble=3.0):
        k = self.keys[0]
        fall = math.sqrt(2.0 * height / 981.0)
        self.drop_spec = dict(t_land=t_land, fall=fall, height=height, spin=spin, wobble=wobble,
                              from_xy=from_xy or (k["x"], k["y"]))
        return self

    def move(self, t0, t1, x, y, yaw=None, flip_x=None, flip_y=None, height=1.5, lead=None, turn=(0.0, 1.0)):
        """A hop to (x, y). lead (deg, pan frame): the move runs along that direction first and sideways last (a toss
        arcs out before it drifts in); turn: the share of the hop over which the piece turns."""
        k = self.keys[-1]
        self.keys.append(dict(t=t0, x=k["x"], y=k["y"], yaw=k["yaw"], fx=k["fx"], fy=k["fy"], kind="rest"))
        self.keys.append(dict(t=t1, x=x, y=y, yaw=k["yaw"] if yaw is None else yaw, fx=k["fx"] if flip_x is None else flip_x,
                              fy=k["fy"] if flip_y is None else flip_y, kind="hop", height=height, lead=lead, turn=turn))
        return self

    def pose(self, t, half):
        """(x, y, centre z above the cooking surface, rotation matrix in the pan frame, visible)."""
        d = getattr(self, "drop_spec", None)
        if d is not None and t < d["t_land"] + 0.35:
            k = self.keys[0]
            t0 = d["t_land"] - d["fall"]
            if t < t0 - 0.0:
                return None
            m = _mm(rz(k["yaw"] - d["spin"] * max(0.0, 1.0 - (t - t0) / d["fall"])), _mm(rx(k["fx"]), ry(k["fy"])))
            if t < d["t_land"]:
                u = (t - t0) / d["fall"]
                lift = d["height"] - 0.5 * 981.0 * (t - t0) ** 2
                x = d["from_xy"][0] + (k["x"] - d["from_xy"][0]) * u
                y = d["from_xy"][1] + (k["y"] - d["from_xy"][1]) * u
                return x, y, half_z(m, half) + max(lift, 0.0), m, True
            # settle: a bounce of restitution 0.15 (PieceSpec.Restitution, Feature.as:95) and a decaying rock
            s = t - d["t_land"]
            vb = 0.15 * math.sqrt(2.0 * 981.0 * d["height"])
            tb = 2.0 * vb / 981.0
            lift = max(0.0, vb * s - 0.5 * 981.0 * s * s) if s < tb else 0.0
            rock = d["wobble"] * math.exp(-s / 0.08) * math.sin(2.0 * math.pi * s / 0.16)
            m = _mm(rz(k["yaw"]), _mm(rx(k["fx"] + rock), ry(k["fy"])))
            return k["x"], k["y"], half_z(m, half) + lift, m, True
        prev = self.keys[0]
        for k in self.keys[1:]:
            if t < k["t"]:
                if k["kind"] == "hop":
                    u = (t - prev["t"]) / (k["t"] - prev["t"])
                    a, b = k.get("turn", (0.0, 1.0))
                    e = ease((u - a) / max(1e-6, b - a))
                    m = _mm(rz(prev["yaw"] + (k["yaw"] - prev["yaw"]) * e),
                            _mm(rx(prev["fx"] + (k["fx"] - prev["fx"]) * e), ry(prev["fy"] + (k["fy"] - prev["fy"]) * e)))
                    lift = k["height"] * math.sin(math.pi * u)
                    dx, dy = k["x"] - prev["x"], k["y"] - prev["y"]
                    if k.get("lead") is None:
                        px, py = prev["x"] + dx * ease(u), prev["y"] + dy * ease(u)
                    else:
                        lx, ly = math.cos(math.radians(k["lead"])), math.sin(math.radians(k["lead"]))
                        along = dx * lx + dy * ly
                        ox, oy = dx - along * lx, dy - along * ly
                        eo, ei = 1.0 - (1.0 - u) ** 3, u ** 3
                        px, py = prev["x"] + along * lx * eo + ox * ei, prev["y"] + along * ly * eo + oy * ei
                    return px, py, half_z(m, half) + lift, m, True
                break
            prev = k
        m = _mm(rz(prev["yaw"]), _mm(rx(prev["fx"]), ry(prev["fy"])))
        return prev["x"], prev["y"], half_z(m, half), m, True


class Piece:
    def __init__(self, label, mesh, track, sear=None, oil=0.0, char_cap=None, glaze=0.0):
        self.label, self.mesh, self.track = label, mesh, track
        self.sear0 = list(sear or [0.0] * 6)
        self.oil0 = oil
        self.char_cap = char_cap      # None = the kernel's clamp at 1; a number lets the down face run past it (beat 5)
        self.glaze = glaze


# ====================================================================================== the replay
def simulate(shot, frames):
    """Per-frame state of a shot's pieces and pan: the kernel's tick, then the station's dressing, at dt = 1 / 30."""
    pieces = shot["pieces"]
    dims = shot["_dims"]
    sear = {p.label: list(p.sear0) for p in pieces}
    oil = {p.label: p.oil0 for p in pieces}
    trail = {}
    foot = {}
    landed = set()
    ramp = shot.get("sizzle0", 0.0)
    fond = shot.get("fond0", FOND_START)
    pool_half = shot.get("pool_half0")
    if pool_half is None and pieces:             # the shared pool look starts on the first piece's size (no jump)
        p0 = pieces[0]
        pool_half = footprint_half(dims[p0.mesh]["half"], down_face(p0.track.pose(1e3, dims[p0.mesh]["half"])[3]))
    hot = shot.get("hot", True)
    out = []
    for i in range(frames):
        t = i * DT
        rows = []
        any_sizzling, any_seared_down = False, False
        for p in pieces:
            half = dims[p.mesh]["half"]
            pose = p.track.pose(t, half)
            if pose is None:
                rows.append(None)
                continue
            x, y, zc, m, vis = pose
            underside = zc - half_z(m, half)
            r = math.hypot(x, y)
            on = underside <= CONTACT_EPS and r <= PAN_RADIUS
            face = down_face(m)
            # kernel: Advance_Sear (Tick.as:235) -- hot, cooking, on the pan: the down face sears toward 1
            if hot and on:
                cap = p.char_cap if p.char_cap is not None else SEAR_CAP
                sear[p.label][face] = min(cap, max(sear[p.label][face], 0.0) + DT / SECONDS_PER_FACE) \
                    if sear[p.label][face] < cap else sear[p.label][face]
            if hot and on and sear[p.label][face] < 1.0:
                any_sizzling = True                    # Broadcast_SizzleEdge (Tick.as:320)
            if hot and on and sear[p.label][face] >= 1.0:
                any_seared_down = True                 # Get_IsAnySearedFaceOnPan
            # station: Advance_Pools (EntityScript.as:554) -- footprint while on, a closing pool while hovering
            h = footprint_half(half, face)
            if on:
                foot[p.label] = (x, y)
                landed.add(p.label)
                lift = 0.0
                pooled = True
            elif r <= PAN_RIM_RADIUS:
                if p.label not in landed:
                    foot[p.label] = (x, y)             # coming down for the first time: the pool forms under it
                lift = min(max(underside / POOL_LIFT_FADE_CM, 0.0), 1.0)   # it keeps where it lifted off
                pooled = True
            else:
                lift, pooled = 1.0, False
            if pooled and p.label not in trail:
                trail[p.label] = foot[p.label]
            if pooled:
                a = 1.0 - math.exp(-DT / TRAIL_LAG)
                tx, ty = trail[p.label]
                fx, fy = foot[p.label]
                trail[p.label] = (tx + (fx - tx) * a, ty + (fy - ty) * a)
            # Make_PieceLook: the oil coat layered by the pan's heat (EntityScript.as:823)
            oil[p.label] = finterp_const(oil[p.label], OIL_COAT_ON_PAN if (hot and on) else OIL_COAT_OFF_PAN, DT,
                                         OIL_COAT_RATE)
            s = sear[p.label]
            total = sum(s)
            disp = dict(xy=(s[0], s[1], s[2], s[3]),
                        z=(s[4], s[5], min(1.0, total), oil[p.label]),             # Make_DisplayParams (CookState.as:60)
                        fin=(p.glaze, total / 6.0, 0.0, 0.0))
            rows.append(dict(label=p.label, mesh=p.mesh, x=x, y=y, zc=zc, m=m, on=on, face=FACES[face], h=h,
                             pooled=pooled, lift=lift, foot=foot.get(p.label), trail=trail.get(p.label), cpd=disp,
                             sear=[round(v, 4) for v in s]))
        # station: Advance_Sizzle (EntityScript.as:724)
        target = SIZZLE_FULL if any_sizzling else (SIZZLE_SEARED_FACE if any_seared_down else 0.0)
        ramp = finterp_const(ramp, target, DT, SIZZLE_RISE if target > ramp else SIZZLE_FALL)
        if any_sizzling:
            fond = min(1.0, fond + FOND_RATE * DT)
        hs = [r["h"] for r in rows if r and r["pooled"]]
        if hs:
            pool_half = max(hs)                        # Advance_PoolHalf: the largest piece on the pan
        out.append(dict(t=t, rows=rows, sizzle=ramp, fond=fond, pool_half=pool_half, sizzling=any_sizzling))
    return out


# ====================================================================================== shots
STAGE_CAM_AZ = st.CAM_AZ


def _cam_dir_local(az_offset):
    """Pan-local azimuth (deg) of the camera of a stage preset whose az is az_offset."""
    return STAGE_CAM_AZ + az_offset - st.PAN_A[2]


SHOTS = {}


def _shot(name, **kw):
    SHOTS[name] = kw
    return kw


def build_shots(use_slab=True):
    SHOTS.clear()
    # -- 1. oil_land: the oil macro; the cube drops in at 1.5 s (lands flat, settles), its pool forms, beads start
    t1 = Track(0.0, 0.0, 0.0, 18.0).drop(1.5, from_xy=(-1.2, -2.0), height=16.0, spin=14.0, wobble=2.5)
    _shot("oil_land", frames=180, preset="cook_oil_macro", t0=12.0,
          pieces=[Piece("cube", "cube", t1)],
          description="Oil macro (cook_oil_macro framing, EV -1.6): the empty hot pan, then the lookdev meat cube drops in "
                      "from above, lands flat at 1.50 s with a small settle; its oil pool forms as it comes down (the "
                      "station's pool closes with lift over PoolLiftFadeCm 4 cm), the oil coat ramps to 0.7, the sizzle "
                      "ramp rises 2/s from 0 to 1 by 2.0 s (simmer beads), the -Z face sears from 1.5 s and is done at "
                      "4.5 s, then the ramp falls 1/s to the seared-face hiss 0.4.",
          visible=[(0.0, 1.3, "empty oil film"), (1.3, 1.6, "cube drops in from the top"),
                   (1.6, 6.0, "cube centre-frame, pool + beads around it")])
    # -- 2. sear_flip: top-down 60; -Z sears 0 -> 1 in 3 s; flip at 3.6 s (90 deg about X, hop); -Y sears
    cam_local = _cam_dir_local(st.SHOTS["cook_top60"]["az"])
    yaw = cam_local - 90.0          # after the flip the seared -Z face looks at the camera
    t2 = Track(0.0, 0.0, 0.0, yaw).move(3.6, 4.0, -2.2 * math.cos(math.radians(yaw + 90.0)),
                                         -2.2 * math.sin(math.radians(yaw + 90.0)), flip_x=90.0, height=1.6)
    _shot("sear_flip", frames=270, preset="cook_top60", t0=20.0, cam=dict(focus=(0.0, 0.0), half=(4.5, 4.5, 2.5), fill=0.8),
          pieces=[Piece("cube", "cube", t2)],
          description="Top-down 60 deg on the hero pan, the lookdev cube: its -Z face sears 0 -> 1 over 3.0 s "
                      "(SecondsPerFace), Penetration = capped sum and Shape = mean as Make_DisplayParams writes them; the "
                      "sizzle ramp falls to 0.4 once the down face is seared (3.0 s); at 3.6 s a scripted flip (90 deg "
                      "about X over 0.4 s, 1.6 cm hop, 2.2 cm roll) brings the seared face up on the camera side; the pool "
                      "closes with the lift and re-forms at the new footprint, the trail lagging 0.25 s; -Y sears from "
                      "4.0 s and is done at 7.0 s; the fond grows at 0.02/s.",
          visible=[(0.0, 3.6, "cube centre-frame searing"), (3.6, 4.0, "flip"), (4.0, 9.0, "seared face on the near side")])
    kind = ["A", "B", "C", "D", "A"] if use_slab else ["cube"] * 5
    lay = FIVE_LAYOUT_SLAB if use_slab else FIVE_LAYOUT_CUBE
    pieces = []
    th = lay["rotate"]
    cam34 = math.radians(_cam_dir_local(st.SHOTS["cook_34"]["az"]))

    def _r(x, y):
        c, s_ = math.cos(math.radians(th)), math.sin(math.radians(th))
        return c * x - s_ * y, s_ * x + c * y
    for k, (x0, y0, yaw0) in enumerate(lay["start"]):
        x, y = _r(x0, y0)
        tr = Track(0.0, x, y, yaw0 + th).drop(lay["admit"][k], from_xy=(x - 1.5 * math.cos(cam34), y - 1.5 * math.sin(cam34)),
                                              height=14.0, spin=10.0, wobble=2.0)
        if k in lay["moves"]:
            mx, my, myaw, mfx = lay["moves"][k]
            mx, my = _r(mx, my)
            tr.move(lay["toss"][0], lay["toss"][1], mx, my, yaw=myaw + th, flip_x=mfx, height=2.4, lead=th,
                    turn=lay["turn"])
        pieces.append(Piece("p%d" % k, kind[k], tr))
    _shot("five_pieces", frames=330, preset="cook_34", t0=30.0, cam=dict(focus=(0.0, 0.0), half=(10.0, 10.0, 3.0),
                                                                          fill=lay.get("fill", 0.62)),
          pieces=pieces,
          description="Three-quarter 30 deg on the hero pan: five %s admitted one by one (landing at %s s), each filling its own Meat Footprint / Oil Trail slot (k_PoolSlots 6, MaxPieces 6) with "
                      "its own footprint radius and its own sear ledger; at %.2f s a scripted toss hops two pieces "
                      "(2.4 cm) %s and turns them a quarter over, their pools close with the lift and re-form at the "
                      "new footprints while the trails lag 0.25 s." % (
                          "slab pieces (SlabPiece_A..D, A twice)" if use_slab else "lookdev cubes",
                          ", ".join("%.2f" % v for v in lay["admit"]), lay["toss"][0], lay["note"]),
          visible=[(0.0, 2.8, "pieces dropping in one by one"), (2.8, 5.3, "five pieces in the pan"),
                   (5.3, 5.8, "toss"), (5.8, 11.0, "five pieces, two moved")])
    # -- 5. char_fond: one piece left on its face past 1.0 to 1.4, then turned over to show it
    mesh5 = "B" if use_slab else "cube"
    t5 = Track(0.0, 0.0, 0.0, CHAR_YAW).move(CHAR_FLIP[0], CHAR_FLIP[1], 0.0, 0.0, flip_x=180.0, height=3.0)
    _shot("char_fond", frames=210, preset="cook_top60", t0=40.0,
          cam=dict(focus=(0.0, 0.0), half=(6.0, 6.0, 3.0), fill=0.78),
          pieces=[Piece("char", mesh5, t5, sear=[0, 0, 0, 0, 0, 0.9], oil=0.7, char_cap=CHAR_CAP)],
          sizzle0=1.0, fond0=CHAR_FOND[0], fond_override=CHAR_FOND,
          description="Top-down 60, tighter: one %s left on its -Z face; the kernel would clamp the sear at 1.0 "
                      "(Tick.as:245), here the face runs on at the same 1/3 per s to %.2f (the material's char range, "
                      "GUIDELINE.md: > 1.25 chars) while the fond builds around it (pushed %.2f -> %.2f over the shot for "
                      "the look; the station's real rate is 0.02/s from 0.1); the sizzle sits at the seared-face hiss "
                      "0.4; at %.1f s it is turned over (180 deg about X, 3 cm hop) to show the charred face." % (
                          "slab piece (SlabPiece_B)" if use_slab else "lookdev cube", CHAR_CAP, CHAR_FOND[0], CHAR_FOND[1],
                          CHAR_FLIP[0]),
          visible=[(0.0, CHAR_FLIP[0], "piece centre-frame, fond darkening around it"),
                   (CHAR_FLIP[0], 7.0, "charred face turned up")])
    # -- 6. ready_lineup: raw / half / seared / charred side by side, slow push
    lp = []
    kinds = ["A", "B", "C", "D"] if use_slab else ["cube"] * 4
    cam_local = _cam_dir_local(st.SHOTS["cook_34"]["az"])
    row = math.radians(cam_local - 90.0)        # +k runs screen-right: raw on the left
    for k, (state, sear, glaze) in enumerate(LINEUP):
        off = (k - 1.5) * LINEUP_SPACING
        x, y = off * math.cos(row), off * math.sin(row)
        lp.append(Piece("l%d" % k, kinds[k], Track(0.0, x, y, cam_local + LINEUP_YAW), sear=sear, oil=0.7, glaze=glaze))
    _shot("ready_lineup", frames=180, preset="cook_34", t0=50.0, hot=False, fixed_sizzle=0.4, fond0=0.35,
          cam=dict(focus=(0.0, 0.0), half=(11.0, 5.0, 3.0), fill=0.6, push=(1.0, 0.86)),
          pieces=lp,
          description="Three-quarter 30 deg, slow push (distance x1.0 -> x0.86, eased): four %s side by side in the pan, "
                      "left to right raw (all 0), half (+Z and -Z seared), seared (all six 1.0, Penetration 1, Shape 1, "
                      "Glaze 0.35 as the approved seared still) and charred (top 1.9, sides 1.6); the pan off the heat "
                      "(the cook ledger frozen), sizzle held at the 0.4 hiss, fond 0.35." % (
                          "slab pieces" if use_slab else "lookdev cubes"),
          visible=[(0.0, 6.0, "four pieces in a row across the pan, raw left to charred right")])
    # -- stills: title (a blurred oil macro: the cube seared, sizzle 1) and end card (the lineup)
    _shot("title_still", frames=1, preset="cook_oil_macro", t0=14.0, still=True, sizzle0=1.0, fixed_sizzle=1.0,
          pieces=[Piece("cube", "cube", Track(0.0, 0.0, 0.0, 18.0), sear=[0.3, 0.3, 0.3, 0.3, 0.0, 1.0], oil=0.7)],
          description="Title background: the oil macro, the cube on its seared face, sizzle 1 (the kit blurs it).")
    _shot("end_still", frames=1, preset="cook_34", t0=52.0, still=True, hot=False, fixed_sizzle=0.4, fond0=0.35,
          cam=dict(focus=(0.0, 0.0), half=(11.0, 5.0, 3.0), fill=0.6, push=(0.9, 0.9)), pieces=lp,
          description="End card background: the ready lineup, three-quarter view.")
    return sorted(SHOTS)


# layouts (pan-local cm, yaw deg), drawn with the toss along +x and turned by `rotate` (-62 deg: +x is screen-right in
# cook_34); moves: piece index -> (x, y, yaw, flip_x) after the toss. Five 4.4 cm cubes on the pan's 9.5 cm flat base
# (cooking_spec.PAN_BASE_R) leave no 6-8 cm lane: the two tossed cubes travel 5.6 cm on an arc (along the toss first),
# turning a quarter over late in the hop once they clear their neighbours (checked: no overlap at a 0.2 cm gap, corners
# inside r 8.9, paths clear).
FIVE_LAYOUT_CUBE = {"start": [(-5.0, 2.6, 4.0), (-5.0, -2.6, -3.0), (0.3, 0.0, 2.0), (0.2, 4.85, -4.0), (0.2, -4.85, 5.0)],
                    "admit": [0.25, 0.85, 1.45, 2.05, 2.65],
                    "moves": {3: (5.4, 2.75, 12.0, 90.0), 4: (5.4, -2.75, -10.0, 90.0)},
                    "toss": (5.4, 5.85), "turn": (0.5, 1.0), "rotate": -62.0, "fill": 0.9,
                    "note": "5.6 cm screen-right on an arc"}
FIVE_LAYOUT_SLAB = FIVE_LAYOUT_CUBE   # slab pieces at 0.4 scale (7.3 x 4.0 x 4.8 cm) find no five-piece layout with a toss
# Slab pieces (SlabPiece_A..D on MeatSlab_Mars_MI) do not read their cook state in the pan (look test 2026-10-25: an
# all-seared piece stays red with a pale fat top, as the 2026-10-10 parity sheet found), so beats 4-7 use the cube.
USE_SLAB_PIECES = False
CHAR_YAW = 30.0
CHAR_CAP = 1.9          # 1.4 read as a plain crust in the draft; the material's burnt end is 2 (Mars_CookState.as:2)
CHAR_FLIP = (4.0, 4.6)
CHAR_FOND = (0.3, 0.9)
LINEUP = [("raw", [0, 0, 0, 0, 0, 0], 0.0),
          ("half", [0.05, 0.05, 0.05, 0.05, 1.0, 1.0], 0.0),
          ("seared", [1, 1, 1, 1, 1, 1], 0.35),
          ("charred", [1.6, 1.6, 1.6, 1.6, 1.9, 1.6], 0.35)]
LINEUP_SPACING = 4.65
LINEUP_YAW = 0.0


# ====================================================================================== editor state
_STATE = {}


def _eas():
    return unreal.get_editor_subsystem(unreal.EditorActorSubsystem)


def _load(path):
    return st._load(path)


def mesh_dims(key):
    """Half extents and centre offset (pivot -> bounds centre) of a mesh at its actor scale, cm."""
    path, scale, _ = MESHES[key]
    m = _load(path)
    if m is None:
        raise RuntimeError("missing mesh %s" % path)
    s = scale if scale is not None else PIECE_SCALE
    b = m.get_bounding_box()
    half = ((b.max.x - b.min.x) * 0.5 * s, (b.max.y - b.min.y) * 0.5 * s, (b.max.z - b.min.z) * 0.5 * s)
    centre = ((b.max.x + b.min.x) * 0.5 * s, (b.max.y + b.min.y) * 0.5 * s, (b.max.z + b.min.z) * 0.5 * s)
    return {"half": half, "centre": centre, "scale": s}


def pan_mid():
    comp = st._smc(st._pan_a())
    m = comp.get_material(0)
    if isinstance(m, unreal.MaterialInstanceDynamic):
        return m
    return comp.create_dynamic_material_instance(0, st.mat("DevlogPanA_Mars_MI"), "DevlogPanShowcaseMID")


def _spawn_piece(key, label):
    path, _, mi = MESHES[key]
    a = _eas().spawn_actor_from_object(_load(path), unreal.Vector(st.BAYS["cooking"]["origin"][0], 0.0, 20.0))
    a.set_actor_label("PanShowcase_%s" % label)
    a.set_folder_path("DevlogStage/PanShowcase")
    a.set_editor_property("tags", [unreal.Name(TAG)])
    c = st._smc(a)
    c.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
    s = mesh_dims(key)["scale"]
    a.set_actor_scale3d(unreal.Vector(s, s, s))
    if mi:
        mat = _load(mi)
        for k in range(c.get_num_materials()):
            c.set_material(k, mat)
    return a


def clear_pieces():
    doomed = [a for a in _eas().get_all_level_actors() if TAG in [str(t) for t in a.get_editor_property("tags")]]
    if doomed:
        _eas().destroy_actors(doomed)
    return len(doomed)


def _use_slab():
    return USE_SLAB_PIECES and all(_load(MESHES[k][0]) is not None for k in "ABCD")


def _ready(name):
    build_shots(_use_slab())
    s = SHOTS[name]
    s["_dims"] = {p.mesh: mesh_dims(p.mesh) for p in s["pieces"]}
    return s


def camera(name, i):
    """The shot's camera for frame i: the stage preset (resolved with the rig on the pan), optionally re-framed on a
    pan-local box and pushed."""
    s = SHOTS[name]
    base = _STATE.get("cam_" + name)
    if base is None:
        r = st.resolve(s["preset"])          # the preset's own arrangement (the macro aims at cube 0), then empty
        st.arrange("empty")
        cam = s.get("cam", {})
        eye, target = r["eye"], r["target"]
        if "focus" in cam:
            fx, fy = st._pan_world(st.PAN_A, cam["focus"])
            centre = (fx, fy, PAN_SURFACE_Z + cam["half"][2])
            eye, target = st.frame(centre, cam["half"], STAGE_CAM_AZ + st.SHOTS[s["preset"]]["az"],
                                   st.SHOTS[s["preset"]]["elev"], r["fov"], cam.get("fill", 0.7))
        elif "fill" in cam:
            c, h = st.cooking_subject("panA")
            eye, target = st.frame(c, h, STAGE_CAM_AZ + st.SHOTS[s["preset"]]["az"], st.SHOTS[s["preset"]]["elev"],
                                   r["fov"], cam["fill"], st.SHOTS[s["preset"]].get("fill_w", 0.86))
        base = dict(r, eye=list(eye), target=list(target))
        _STATE["cam_" + name] = base
    push = s.get("cam", {}).get("push")
    eye, target = base["eye"], base["target"]
    if push:
        u = ease(i / max(1.0, s["frames"] - 1.0))
        k = push[0] + (push[1] - push[0]) * u
        eye = [t + (e - t) * k for e, t in zip(eye, target)]
    return {"eye": list(eye), "target": list(target), "fov": base["fov"], "ev": base["ev"], "fog_start": base["fog_start"],
            "preset": base["preset"]}


def prepare(name):
    """Open the stage, empty the hero pan (stage cubes parked), fit the rig, put a MID on pan A, spawn the pieces."""
    st.open_stage()
    s = _ready(name)
    _STATE.pop("cam_" + name, None)
    cam = camera(name, 0)              # resolve() arranges 'empty' and fits the rig for this camera
    st.set_fog(start=cam["fog_start"], ev=cam["ev"])
    pan_mid()
    clear_pieces()
    acts = {}
    for p in s["pieces"]:
        acts[p.label] = _spawn_piece(p.mesh, p.label)
    return {"pieces": list(acts), "use_slab": _use_slab(), "camera": cam, "dims": s["_dims"]}


def _actors():
    out = {}
    for a in _eas().get_all_level_actors():
        if TAG in [str(t) for t in a.get_editor_property("tags")]:
            out[a.get_actor_label().replace("PanShowcase_", "")] = a
    return out


def apply_frame(name, state, acts, mid):
    s = SHOTS[name]
    dims = s["_dims"]
    pan_yaw = st.PAN_A[2]
    slot = 0
    for p, row in zip(s["pieces"], state["rows"]):
        a = acts[p.label]
        if row is None:
            a.set_actor_location(unreal.Vector(st.BAYS["cooking"]["origin"][0], 0.0, 20.0), False, False)
            st._smc(a).set_visibility(False)
            continue
        st._smc(a).set_visibility(True)
        d = dims[p.mesh]
        mw = _mm(rz(pan_yaw), row["m"])
        cx, cy = st._pan_world(st.PAN_A, (row["x"], row["y"]))
        coff = _mv(mw, d["centre"])
        loc = (cx - coff[0], cy - coff[1], PAN_SURFACE_Z + row["zc"] - coff[2])
        q = _quat(mw)
        a.set_actor_location_and_rotation(unreal.Vector(*loc), unreal.Quat(q[0], q[1], q[2], q[3]).rotator(), False, False)
        st._set_cpd(a, row["cpd"]["xy"], row["cpd"]["z"], row["cpd"]["fin"])
        if row["pooled"] and slot < POOL_SLOTS:
            nm = "Meat Footprint" + ("" if slot == 0 else " %d" % slot)
            tn = "Oil Trail" + ("" if slot == 0 else " %d" % slot)
            radius = row["h"] * FOOTPRINT_PER_HALF * (1.0 - row["lift"])
            mid.set_vector_parameter_value(nm, unreal.LinearColor(row["foot"][0], row["foot"][1], radius, 0.0))
            mid.set_vector_parameter_value(tn, unreal.LinearColor(row["trail"][0], row["trail"][1], 0.0, 0.0))
            slot += 1
    while slot < POOL_SLOTS:
        nm = "Meat Footprint" + ("" if slot == 0 else " %d" % slot)
        mid.set_vector_parameter_value(nm, unreal.LinearColor(0.0, 0.0, 0.0, 0.0))
        slot += 1
    sizzle = s.get("fixed_sizzle", state["sizzle"])
    fond = state["fond"]
    fo = s.get("fond_override")
    if fo:
        fond = fo[0] + (fo[1] - fo[0]) * smooth(state["t"] / max(DT, (s["frames"] - 1) * DT))
    mid.set_scalar_parameter_value("Oil Amount", st.PAN_LOOK["Oil Amount"])
    mid.set_scalar_parameter_value("Sizzle", float(sizzle))
    mid.set_scalar_parameter_value("Fond", float(fond))
    h = state["pool_half"]
    if h:
        mid.set_scalar_parameter_value("Pool Radius", POOL_RADIUS_PER_HALF * h)
        mid.set_scalar_parameter_value("Pool Margin", POOL_MARGIN_PER_HALF * h)
        mid.set_scalar_parameter_value("Pool Blend", POOL_BLEND_PER_HALF * h)
        mid.set_scalar_parameter_value("Simmer Width", SIMMER_WIDTH_PER_HALF * h)
        mid.set_scalar_parameter_value("Contact Softness", CONTACT_SOFT_PER_HALF * h)
    return {"sizzle": sizzle, "fond": fond}


def indices(name, draft):
    n = SHOTS[name]["frames"]
    return list(range(0, n, DRAFT_STEP)) if draft else list(range(n))


def out_dir(name, draft):
    return os.path.join(DRAFT_ROOT, name) if draft else os.path.join(OUT, name)


def shoot(name, draft=False, start=0, end=None):
    """Frames [start, end) of the shot's written sequence. Full frames render at 2x into the scratch raw folder (the
    host downsamples them into the shot folder); drafts render 960x540 straight into the draft folder."""
    s = _ready(name)
    states = simulate(s, s["frames"])
    idx = indices(name, draft)
    end = len(idx) if end is None else min(end, len(idx))
    dst = out_dir(name, draft) if draft else os.path.join(RAW_ROOT, name)
    os.makedirs(dst, exist_ok=True)
    acts = _actors()
    mid = pan_mid()
    cam0 = camera(name, 0)
    look = st._bay_look("cooking", cam0["preset"], cam0["ev"])
    size = st.DRAFT if draft else (st.FULL[0] * st.SUPERSAMPLE, st.FULL[1] * st.SUPERSAMPLE)
    rig = st.StageRig(size, look)
    written = []
    try:
        for k in range(start, end):
            i = idx[k]
            apply_frame(name, states[i], acts, mid)
            c = camera(name, i)
            written.append(rig.frame(c["eye"], c["target"], c["fov"], dst, "%05d.png" % k, s["t0"] + i / FPS))
    finally:
        rig.close()
    return {"written": len(written), "last": written[-1] if written else None, "dir": dst}


def finish(name=None):
    """Restore the stage: pieces destroyed, pan A back on its instance, the trio re-arranged, fog and time restored."""
    n = clear_pieces()
    comp = st._smc(st._pan_a())
    comp.set_material(0, st.mat("DevlogPanA_Mars_MI"))
    st.arrange(st.COOK_DEFAULT)
    st.set_fog()
    ds._cvar("r.Test.OverrideTimeMaterialExpressions -1")
    _STATE.clear()
    return {"destroyed": n}


def ledger(name, every=15):
    """The replayed numbers (for shot.json and checks): every `every` frames, each piece's face, sears, pool radius."""
    s = _ready(name)
    out = []
    for i, stt in enumerate(simulate(s, s["frames"])):
        if i % every and i != s["frames"] - 1:
            continue
        out.append({"t": round(stt["t"], 3), "sizzle": round(stt["sizzle"], 3), "fond": round(stt["fond"], 4),
                    "pieces": [None if r is None else {"id": r["label"], "on": r["on"], "face": r["face"],
                                                        "sear": r["sear"], "pen": round(r["cpd"]["z"][2], 3),
                                                        "shape": round(r["cpd"]["fin"][1], 3), "oil": round(r["cpd"]["z"][3], 3),
                                                        "lift": round(r["lift"], 3),
                                                        "radius": round(r["h"] * FOOTPRINT_PER_HALF * (1 - r["lift"]), 3),
                                                        "foot": [round(v, 2) for v in r["foot"]] if r["foot"] else None,
                                                        "trail": [round(v, 2) for v in r["trail"]] if r["trail"] else None}
                               for r in stt["rows"]]})
    return out


def info(name, draft=False):
    s = _ready(name)
    idx = indices(name, draft)
    cam = camera(name, 0)
    return {"name": name, "out_dir": out_dir(name, draft), "raw_dir": os.path.join(RAW_ROOT, name),
            "fps": FPS / DRAFT_STEP if draft else FPS, "frames_written": len(idx),
            "real_seconds_covered": s["frames"] / FPS, "description": s["description"],
            "extra": {"map": st.MAP, "preset": s["preset"], "frozen_t0": s["t0"],
                      "frozen_time": "frame i is rendered at r.Test.OverrideTimeMaterialExpressions = t0 + i / 30",
                      "pieces": "slab" if _use_slab() else "cubes",
                      "piece_meshes": sorted({MESHES[p.mesh][0] for p in s["pieces"]}),
                      "piece_scale": {p.mesh: s["_dims"][p.mesh]["scale"] for p in s["pieces"]},
                      "size": list(st.DRAFT if draft else st.FULL),
                      "supersample": 1 if draft else st.SUPERSAMPLE, "draft": bool(draft), "camera_first": cam,
                      "camera_last": camera(name, s["frames"] - 1), "visible": s.get("visible", []),
                      "kernel": {"SecondsPerFace": SECONDS_PER_FACE, "SearCap": SEAR_CAP, "MaxPieces": MAX_PIECES,
                                 "k_PoolSlots": POOL_SLOTS, "FootprintPerHalf": FOOTPRINT_PER_HALF,
                                 "TrailLagSeconds": TRAIL_LAG, "PoolLiftFadeCm": POOL_LIFT_FADE_CM,
                                 "SizzleRise": SIZZLE_RISE, "SizzleFall": SIZZLE_FALL, "SizzleSearedFace": SIZZLE_SEARED_FACE,
                                 "FondStart": FOND_START, "FondRate": FOND_RATE, "OilCoatOnPan": OIL_COAT_ON_PAN},
                      "overrides": {k: s[k] for k in ("fond_override", "fixed_sizzle", "hot") if k in s},
                      "ledger": ledger(name)}}


# ====================================================================================== slab pieces
def import_pieces():
    """SlabPiece_A..D_Mars_SM.fbx (devlog_pan_cut.py --export) -> /Game/Mars/Devlog/Pieces, the legacy FBX importer as
    mars_food_ue / mars_cook_parity use it (normals, vertex colours replace, degenerates kept), every slot on
    MeatSlab_Mars_MI (the game's slab instance on Food_Mars_M: the cap slot 2 too), saved."""
    done = {}
    mi = _load(SLAB_MI)
    for letter in "ABCD":
        name = "SlabPiece_%s_Mars_SM" % letter
        task = unreal.AssetImportTask()
        task.filename = os.path.join(PIECES_SRC, name + ".fbx")
        task.destination_path = PIECES_DST
        task.destination_name = name
        task.replace_existing = True
        task.automated = True
        task.save = True
        opts = unreal.FbxImportUI()
        opts.import_mesh = True
        opts.import_as_skeletal = False
        opts.import_materials = False
        opts.import_textures = False
        sm = opts.static_mesh_import_data
        sm.combine_meshes = True
        sm.generate_lightmap_u_vs = False
        sm.auto_generate_collision = False
        sm.set_editor_property("normal_import_method", unreal.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS)
        sm.set_editor_property("vertex_color_import_option", unreal.VertexColorImportOption.REPLACE)
        for prop, val in (("build_nanite", False), ("remove_degenerates", False)):
            try:
                sm.set_editor_property(prop, val)
            except Exception:
                pass
        task.options = opts
        cvar = "Interchange.FeatureFlags.Import.FBX"
        was = unreal.SystemLibrary.get_console_variable_bool_value(cvar)
        unreal.SystemLibrary.execute_console_command(None, "%s 0" % cvar)
        try:
            unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
        finally:
            unreal.SystemLibrary.execute_console_command(None, "%s %d" % (cvar, 1 if was else 0))
        st._CACHE.pop("%s/%s" % (PIECES_DST, name), None)
        mesh = unreal.EditorAssetLibrary.load_asset("%s/%s" % (PIECES_DST, name))
        if mesh is None:
            raise RuntimeError("import of %s failed" % name)
        n = len(mesh.get_editor_property("static_materials"))
        for k in range(n):
            mesh.set_material(k, mi)
        unreal.EditorAssetLibrary.save_loaded_asset(mesh)
        b = mesh.get_bounding_box()
        done[name] = {"slots": n, "bounds_min": [round(b.min.x, 2), round(b.min.y, 2), round(b.min.z, 2)],
                      "bounds_max": [round(b.max.x, 2), round(b.max.y, 2), round(b.max.z, 2)]}
    return done


def look_test(kind="slab", out_name=None):
    """A draft still of four pieces (raw / -Z seared and turned up / all seared / charred top) in the pan, cook_34-ish
    framing: does this piece read its cook state? kind = slab | cube."""
    build_shots(kind == "slab")
    name = "ready_lineup"
    s = SHOTS[name]
    if kind != "slab":
        for p in s["pieces"]:
            p.mesh = "cube"
    s["_dims"] = {p.mesh: mesh_dims(p.mesh) for p in s["pieces"]}
    st.open_stage()
    _STATE.pop("cam_" + name, None)
    cam = camera(name, 0)
    st.set_fog(start=cam["fog_start"], ev=cam["ev"])
    mid = pan_mid()
    clear_pieces()
    for p in s["pieces"]:
        _spawn_piece(p.mesh, p.label)
    acts = _actors()
    states = simulate(s, 1)
    apply_frame(name, states[0], acts, mid)
    look = st._bay_look("cooking", cam["preset"], cam["ev"])
    rig = st.StageRig(st.DRAFT, look)
    try:
        f = rig.frame(cam["eye"], cam["target"], cam["fov"], os.path.join(SCRATCH, "test"), (out_name or "look_%s" % kind) + ".png",
                      12.0)
    finally:
        rig.close()
        finish()
    return f
