"""Screaming Turnip R01 - Phase B / B3: author the 16 Blender clips on the 17 export bones AND the two shape-key
channels (`Inhale`, `Scream`), audit every frame, save.

Phase B3: the B2b mesh carries relative shape keys `Inhale` / `Scream`; the parameter vectors carry their values
(`k_inhale`, `k_scream`). Every clip now writes TWO actions: `<Clip>` on the armature (bones, as Phase B) and
`<Clip>_Key` on the mesh's Key datablock (both channels keyed on every frame, LINEAR; clips that do not use a key key
it at 0 explicitly, so a hard cut never inherits a stale value). New clip `ROOT_AnticipateTired` (= Anticipate, but
starting from ROOT_RecoveryIdle f0) removes the B-2 leaf snap of the RecoveryIdle -> Anticipate hard cut.

Opens source/ScreamingTurnip_R01.blend (built by build_screaming_turnip.py) and, for every clip of
ANIMATION_MANIFEST.csv except the four HANDS_* rows (D-4, not Blender work):
  1. evaluates a Catmull-Rom spline (periodic for loops) through named key poses of the builder's parameter vector
     (build_screaming_turnip.PKEYS: body h/w scale + pivot + z offset + Y rotation, jaw, cheek scale/location,
     crown Y rotation + z, per-leaf tilt/fan) plus optional per-frame layers (breath, sway, shake),
  2. keys EVERY frame 0..N of every export bone except `root` (never keyed; identity asserted on every frame) into
     one action named exactly `<Clip>` (fake user),
  3. audits every frame: root identity, triangle-pair intersections (turnip_audit.intersections), Unreal FTransform
     composition deviation, bounds; the global envelope across all clips,
  4. checks loop seams (frame N == frame 0, velocity continuity) and the clip chain (Anticipate f0 == QuietIdle f0,
     Inhale f0 == Anticipate fN, ...; the two documented hard cuts QuietIdle / RecoveryIdle -> Anticipate reported),
then saves the .blend (no action assigned to the armature) and writes review/phaseB/anim_report.json and
export/anims/clips.json.

Phase B4 (size x3.0): the clips are the B3 clips verbatim (same keys, frames, loops, layers, shape-key curves); the pose
parameters stay in the 16 cm design frame and the builder's `bone_targets` multiplies their translations by
`unit()` (3.0 on the B4 blend). Lengths this script reports (envelope limits, planted offset, soil line) scale by the
same factor; the gates on chain / seam / playback deltas stay absolute (cm), i.e. 3x stricter relative to the asset.

Pose language: parameter vectors only (decision D-B1: no control armature - simpler and deterministic). Splining the
parameters (not the bone channels) keeps the rig contract on every interpolated frame: body X == Z scale, crown and
taproot exact counter-scale, jaw and crown rotate about Y only, cheeks scale/translate without rotation.
Loop convention: N+1 samples, frame N duplicates frame 0 (pose and slope); Unreal reads N+1 keys, length N/30 s.

Run (from the screaming_turnip_r01 folder):
  "$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/animate_screaming_turnip.py -- \
      [--clips A,B] [--no-audit] [--no-save] [--review phaseK]
Phase K: `-- --inject-stretch T,L [--review phaseK]` audits SRC_Tug / SRC_Cancel / SRC_Release with the runtime crown
offset (-T * a, 0, L * a) UE cm and writes review/<review>/inject_T_L.json; no actions written, no save.
Prints TURNIP_OK / TURNIP_FAIL <reason>; exits non-zero on failure.
"""
import json
import math
import os
import sys
import time
import traceback

import bpy
import numpy as np
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import build_screaming_turnip as BT  # noqa: E402
import turnip_audit  # noqa: E402

ROOT = os.path.dirname(HERE)
REVIEW = os.path.join(ROOT, "review", "phaseB4")      # Phase I / J / K: `-- --review phaseK` writes anim_report there
ANIMS = os.path.join(ROOT, "export", "anims")
BLEND = os.path.join(ROOT, "source", "ScreamingTurnip_R01.blend")
FPS = 30
ENVELOPE = (22.0, 14.0, 13.0)            # h (z), w (y), d (x) cm, design frame (x unit() in main)
PLANT_DZ = -0.6                          # planted body offset (design cm): SoilLine z 9.6 shows ~1.5 cm of shoulder
I = BT.PIDX


def P(spec):
    return BT.params_of(spec)


def with_(v, **kw):
    v = v.copy()
    for k, x in kw.items():
        v[I[k]] = x
    return v


def leaves(v, la=None, lb=None, lf=None, k=(1, 1, 1, 1, 1)):
    v = v.copy()
    for pre, val in (("la", la), ("lb", lb), ("lf", lf)):
        if val is None:
            continue
        vals = list(val) if isinstance(val, (list, tuple)) else [val] * 5
        for i in range(5):
            v[I["%s%d" % (pre, i + 1)]] = vals[i] * (k[i] if pre != "lf" else 1.0)
    return v


# ------------------------------------------------------------------ pose library
NEUTRAL = BT.NEUTRAL.copy()
PLANT = P({"bdz": PLANT_DZ})
GRIP = leaves(with_(PLANT, cr_dz=-0.35), la=-6.0, lb=-4.0)
# Phase J (PHASE_J_BRIEF.md D-J3): the walk-away pull. SRC_Tug is now a lean-and-stretch toward the puller on the
# mesh's -X (the Use side): crown head at f15 dx -36 +- 2 / dz +9 +- 2 cm (UE, root-relative) from SRC_Grip f6
# (0, 0, 31.8) -> (-36.0, 0, 42.3) = dx -36.0 / dz +10.5; the HarvestGrip sockets ride the crown (their horizontal
# travel is gameplay_numbers.k_StretchTravelCm). cr_dx / cr_dz are the design-cm values that put the crown head there
# under this body pose (solved; x unit() = 3 in bone_targets). The crown pitches -X (cr_y < 0, the sign of
# ROOT_AirborneLeafTrail's "crown pitched -X") 50 deg. The bulb stays planted (bdz = PLANT_DZ, the root never moves)
# and tilts toward the pull (brot -8 deg, bh 1.04 / bw 0.98); the taproot holds the base. Leaves la -12 / lb -7 (Phase I).
# Why dz 10.5 (not 9) and cr_y -50 / mid -46: the bulb's top ring (0.35 crown) and dimple (0.6 crown) follow the crown
# further than stem 3's emergence ring (0.5), so past ~25 cm of lean the dragged bulb top reaches stem 3 (the -X stalk);
# the sweep (PROGRESS Phase J) found 3-28 stem3-vs-bulb pairs on f10-f15 for dz 9-10 or a pitch that trails the
# travel; dz 10.5 + a pitch that leads it (-46 at f8) is 0 on every frame of Tug / Cancel / Release, as are -49 / dz 11.
# Was (Phase I, straight up): bh 1.06, bw 0.96, bdz PLANT_DZ, cr_dz 1.545, la -12, lb -7 (crown 31.8 -> 39.5 cm).
# Phase J Part 1d (maintainer: "2x-3x as a start"): shipped at 2x, crown head dx -72.0 / dz +14.0 at f15 (Part 1/1b/1c
# was -36.0 / +10.5 with cr_y -50, cr_dx -10.398, cr_dz 4.192 and the mid key cr_y -46, cr_dx -6.113, cr_dz 1.543); the lift
# scales less than the reach so the stalks run long and low. Pitch -60 (mid -50), the top of the brief's 50-60: at -55
# Release f3 grazes stem 3 on the bulb top (3 pairs) before the ease below; Tug / Cancel are clean at -55 and -60. The
# Part 1d bulb-top weights (0.03 ring / 0.06 dimple, builder) keep the dimple <= 9 cm x / 3 cm z (review/phaseJ/neck.json).
# Phase J Part 1e (maintainer: "go with 4x"): shipped at 4x, crown head dx -144.0 / dz +20.0 at f15. Part 1d (2x) was
# cr_dx -21.667, cr_dz 6.908 (mid -12.571 / 2.878): crown -72 / +14. The Part 1e bulb-top weights (0.01 ring / 0.03 dimple)
# keep the dimple <= 9 cm x / 3 cm z. Pitch -60 / mid -50 as 2x; the Tug / Cancel / Release sweep at -55 / -60, mid -50 /
# -55 was clean everywhere (with the REL_OVER ease).
# Phase K (PHASE_K_BRIEF.md D-K2): the stretch DISTANCE moves to a runtime crown offset (the ABP's ModifyBone, component
# space, (-TravelCm * a, 0, LiftCm * a), a bed tuner); the clips keep only the pose: the crown pitch, the trailing leaves,
# the bulb tilt. The brief says cr_dx = 0 / cr_dz = 0. DEV-K-1: with cr_dx 0 the 8 deg body tilt (brot) alone carries the
# crown head -2.05 cm in x at f15 (-1.01 at f8), and the brief's own readback (Part 3: f15 crown x within 0.05 of f0) would
# fail; so cr_dx is the small value that holds the crown head at x 0 (+0.6512 at STRAIN, +0.3289 at TUG_MID; design cm),
# with cr_dz -0.0915 / -0.0230 keeping the z that cr_dz 0 gives (33.87 / 33.39 cm UE). The travel is entirely the tuner's.
# Phase J 1e (4x) was cr_dx -44.249 / cr_dz 12.023 (mid -25.534 / 4.864): crown -144 / +20 authored.
STRAIN = leaves(P({"bh": 1.04, "bw": 0.98, "bdz": PLANT_DZ, "brot": -8.0, "cr_y": -60.0,
                   "cr_dx": 0.6512, "cr_dz": -0.0915}), la=-12.0, lb=-7.0)
# SRC_Tug mid key (f8): half the tilt, the pitch leading (-50); crown head held at x 0 (DEV-K-1).
# Was (Phase I) with_(STRAIN, bh=1.03, bw=0.98, cr_dz=0.74), la -10 / lb -6.
TUG_MID = leaves(with_(STRAIN, bh=1.02, bw=0.99, brot=-4.0, cr_y=-50.0, cr_dx=0.3289, cr_dz=-0.0230), la=-10, lb=-6)
# Part 1d preview only (`-- --variant 3x`: not shipped, saved to a scratch blend): crown dx -108 / dz +18, mid -60 / +9.9.
# Phase K: obsolete (the travel is a runtime tuner; audit it with --inject-stretch); kept for the Part 1d record.
STRAIN_3X = leaves(P({"bh": 1.04, "bw": 0.98, "bdz": PLANT_DZ, "brot": -8.0, "cr_y": -60.0,
                      "cr_dx": -32.913, "cr_dz": 9.783}), la=-12.0, lb=-7.0)
TUG_MID_3X = leaves(with_(STRAIN_3X, bh=1.02, bw=0.99, brot=-4.0, cr_y=-50.0, cr_dx=-19.04, cr_dz=4.05), la=-10, lb=-6)
REL_OVER = leaves(P({"bh": 1.10, "bw": 0.95, "cr_dz": -0.15}), la=14.0, lb=10.0)
REL_UNDER = leaves(P({"bh": 0.97, "bw": 1.02, "cr_dz": 0.05}), la=-5.0, lb=-3.0)
ANT = leaves(P({"bh": 0.90, "bw": 1.10, "cr_dz": 0.4, "cheek": {"s": (1.0, 1.10, 1.08), "pivot": BT.MOUTH_PIVOT}}),
             la=-8.0, lb=-5.0)
INHALE = P(BT.POSES["inhale"])
SCREAM = P(BT.POSES["scream"])
SCREAM_FAN = leaves(SCREAM, la=-9.0, lb=-20.0, lf=(15, 8, 0, -8, -15))     # flare up and out
SCREAM_RECOIL = leaves(SCREAM, la=6.0, lb=2.0, lf=(4, 2, 0, -2, -4))        # recoil back down
SQUASH = P(BT.POSES["recover"])
DROOP_K = (1.0, 0.62, 0.85, 0.62, 1.0)
TIRED = leaves(P({"bh": 0.985, "bw": 1.01, "cr_y": 3.0, "cr_dz": -0.2}), la=16.0, lb=24.0, k=DROOP_K)
AIR = leaves(P({"cr_y": -14.0}), la=6.0, lb=8.0)
IMPACT = P(BT.POSES["impact_squash"])
PLACE = P({"bh": 0.92, "bw": 1.04})


def tri_wave(t, period, phase):
    return math.sin(2 * math.pi * t / period + phase) - math.sin(phase)   # periodic, zero at t = 0


PHASES = (0.0, 1.3, 2.6, 3.9, 5.2)


def sway_layer(amp_a, amp_b, period, base_k=(1, 1, 1, 1, 1)):
    def f(t):
        d = np.zeros(len(BT.PKEYS))
        for i in range(5):
            d[I["la%d" % (i + 1)]] = amp_a * base_k[i] * tri_wave(t, period, PHASES[i])
            d[I["lb%d" % (i + 1)]] = amp_b * base_k[i] * tri_wave(t, period, PHASES[i] + 0.8)
        return d
    return f


class Clip:
    def __init__(self, name, end, loop, keys, layer=None, ease=(), note="", chain=None, sk_curve=None):
        self.name, self.end, self.loop, self.note = name, end, loop, note
        self.sk_curve = sk_curve or {}      # B3: {param: [(frame, value), ...]} replaces the splined value (linear)
        self.keys = sorted(keys, key=lambda k: k[0])
        self.layer = layer
        self.ease = set(ease)
        self.chain = chain or {}
        fr = [k[0] for k in self.keys]
        if loop and fr[-1] == end:
            raise ValueError("%s: loops are keyed on [0, N); frame N is frame 0" % name)
        self.F = np.array(fr, dtype=float)
        self.V = np.array([k[1] for k in self.keys], dtype=float)

    def _eval(self, t):
        F, A, n = self.F, self.V, len(self.F)
        if n == 1:
            return A[0].copy()
        if self.loop:
            Pd = float(self.end)
            t = t % Pd
            Fx = np.concatenate([F[-2:] - Pd, F, F[:2] + Pd])
            Ax = np.concatenate([A[-2:], A, A[:2]])
            off = 2
        else:
            t = min(max(t, F[0]), F[-1])
            Fx, Ax, off = F, A, 0
        i = int(np.searchsorted(Fx, t, side="right") - 1)
        i = min(max(i, off), off + n - (1 if self.loop else 2))
        t0, t1 = Fx[i], Fx[i + 1]

        def slope(j):
            fj = int(round(Fx[j] % self.end)) if self.loop else int(round(Fx[j]))
            if not self.loop and (j == 0 or j == n - 1):
                return np.zeros_like(A[0])
            if fj in self.ease:
                return np.zeros_like(A[0])
            return (Ax[j + 1] - Ax[j - 1]) / (Fx[j + 1] - Fx[j - 1])

        m0, m1 = slope(i), slope(i + 1)
        h = t1 - t0
        s = (t - t0) / h
        s2, s3 = s * s, s * s * s
        return ((2 * s3 - 3 * s2 + 1) * Ax[i] + (s3 - 2 * s2 + s) * h * m0 + (-2 * s3 + 3 * s2) * Ax[i + 1]
                + (s3 - s2) * h * m1)

    def sample(self, t):
        v = self._eval(t)
        if self.layer is not None:
            v = v + self.layer(t)
        for k, pts in self.sk_curve.items():
            v[I[k]] = float(np.interp(t, [p[0] for p in pts], [p[1] for p in pts]))
        return v


def scream_shake(t):
    """+-1.5 deg body about Y at 15 Hz (alternating frames at 30 fps) during the hold, enveloped to 0 at the ends."""
    d = np.zeros(len(BT.PKEYS))
    env = BT.smooth((t - 3.0) / 2.0) * (1.0 - BT.smooth((t - 13.0) / 3.0))
    d[I["brot"]] = 1.5 * math.cos(math.pi * t) * env
    return d


def quiet_layer(t):
    d = sway_layer(0.8, 1.5, 60.0)(t)
    d[I["bh"]] = 0.0075 * (1.0 - math.cos(2 * math.pi * t / 60.0))           # 1.000 .. 1.015
    return d


def tired_layer(t):
    d = sway_layer(0.6, 1.2, 60.0, DROOP_K)(t)
    d[I["bh"]] = 0.015 * math.sin(2 * math.pi * t / 60.0)                     # 0.97 .. 1.00 around 0.985
    return d


def air_layer(t):
    d = np.zeros(len(BT.PKEYS))
    for i in range(5):
        d[I["lb%d" % (i + 1)]] = 7.0 * tri_wave(t, 15.0, PHASES[i])            # flutter twice per loop
        d[I["la%d" % (i + 1)]] = 3.0 * tri_wave(t, 30.0, PHASES[i] + 0.5)
    return d


def settle_layer(t):
    d = np.zeros(len(BT.PKEYS))
    u = t / 12.0
    env = (1.0 - u) ** 1.5
    for i in range(5):
        k = DROOP_K[i]
        d[I["la%d" % (i + 1)]] = 12.0 * k * math.sin(2 * math.pi * 2 * u) * env
        d[I["lb%d" % (i + 1)]] = 9.0 * k * math.sin(2 * math.pi * 2 * u - 0.6) * env + 9.0 * k * math.sin(0.6) * env * (1 - u)
    return d


def build_clips(u=1.0):
    return [
        Clip("SRC_Idle", 60, True, [(0, PLANT), (30, PLANT)], layer=sway_layer(1.5, 3.0, 60.0),
             note="planted (body z %+.1f cm), gentle leaf sway, no mouth" % (PLANT_DZ * u)),
        Clip("SRC_Grip", 6, False, [(0, PLANT), (6, GRIP)], note="stalks compress at the HarvestGrip points",
             chain={"from": ("SRC_Idle", 0)}),
        Clip("SRC_Tug", 15, False, [(0, GRIP), (8, TUG_MID), (15, STRAIN)],
             note="Phase K: the pull's POSE only, scrubbed by the walk-away pull: crown pitched -60 deg toward -X (the Use "
                  "side), leaves trailing, bulb planted and tilted 8 deg toward -X at 1.04 h / 0.98 w; the crown head stays at "
                  "x 0 (z 31.8 -> 33.9 cm UE). The stretch distance is the runtime crown offset (-TravelCm * a, 0, "
                  "LiftCm * a) in component space, a bed tuner (default 146.2 / 20 cm); ends at full strain",
             chain={"from": ("SRC_Grip", 6)}),
        # Part 1d: ease (zero slope) at REL_OVER f2, so the 72 cm snap-back does not overshoot past neutral into +X at f3
        # (the spline overshoot pressed stem 3 into the bulb top: 3 pairs). Was no ease. Part 1e: still clean at 144 cm.
        Clip("SRC_Release", 6, False, [(0, STRAIN), (2, REL_OVER), (4, REL_UNDER), (6, NEUTRAL)], ease=(2,),
             note="elastic break-free from the strain pose (Phase K: the runtime offset is 0 by the release): crown springs back, leaves rebound, bulb "
                  "overshoots to 1.1 h, settles at neutral (== ROOT_QuietIdle f0); root never moves", chain={"from": ("SRC_Tug", 15)}),
        # Phase J Part 1c: the Tug's mirror, so SRC_Cancel played from 1 - a starts where SRC_Tug(a) is (PIE run measured a
        # 3.57 cm jump at a 0.586 with no mid key). TUG_MID at 7 * (1 - 8/15) = 49/15 = f3.267 (fractional key: the spline
        # takes it; every integer frame is still keyed). Crown mismatch Cancel(1 - a) vs Tug(a) over a 0.05..0.95: authored
        # spline <= 1.03 cm, as keyed at 30 fps (linear between keys, as played) <= 1.26 cm at a 0.07 and <= 0.89 from
        # a 0.2; 0.02 cm at a 0.59 (was 2.36; max 2.76 crown / 3.93 socket). The floor near a 0 is the Grip dip (Tug starts
        # at GRIP, Cancel ends at PLANT: 1.05 cm). Part 1d (2x): spline still <= 1.03; as keyed <= 1.13 from a 0.15,
        # peak 1.68 at a 0.07 (the 30 fps chord error doubles with the travel), 0.04 at a 0.59. Part 1e (4x): spline
        # <= 1.03; as keyed peaks 2.65 at a 0.07 and 2.24 at a 0.93 (the 7-key chord at both eased ends), <= 1.01 over
        # a 0.25..0.80, 0.10 at a 0.59.
        # review/phaseJ/cancel_match.json. Was [(0, STRAIN), (7, PLANT)].
        Clip("SRC_Cancel", 7, False, [(0, STRAIN), (49.0 / 15.0, TUG_MID), (7, PLANT)],
             note="full strain pose back to the planted rest (Phase K: the runtime offset shrinks with 1 - played alpha); "
                  "Part 1c: TUG_MID at f3.267 mirrors SRC_Tug's f8, so Cancel at 1 - a matches Tug at a (Part 1e 4x, as keyed: "
                  "<= 1.01 cm over a 0.25..0.80, peaks 2.65 cm at a 0.07 and 2.24 cm at a 0.93 (30 fps chord at the eased ends, "
                  "over the 1.05 cm Grip-dip floor); review/phaseJ/cancel_match.json)",
             chain={"from": ("SRC_Tug", 15)}),
        Clip("ROOT_QuietIdle", 60, True, [(0, NEUTRAL), (30, NEUTRAL)], layer=quiet_layer,
             note="closed pucker, breath 1.000..1.015 h, relaxed crown"),
        Clip("ROOT_Anticipate", 9, False, [(0, NEUTRAL), (9, ANT)],
             note="squash 0.9 h / 1.1 w, cheeks begin (1.1), crown lifts", chain={"from": ("ROOT_QuietIdle", 0)}),
        Clip("ROOT_AnticipateTired", 9, False, [(0, TIRED), (9, ANT)],
             note="B3 (B-2): ROOT_Anticipate from the tired pose - starts == ROOT_RecoveryIdle f0 (drooped crown), "
                  "ends == ROOT_Inhale f0; the presentation picks it after the recovery phase",
             chain={"from": ("ROOT_RecoveryIdle", 0)}),
        Clip("ROOT_Inhale", 36, False, [(0, ANT), (14, 0.35 * ANT + 0.65 * INHALE), (30, INHALE), (36, INHALE)],
             ease=(30,), note="cheeks to the full bellows, leaves rise, pursed aperture; holds the last 0.2 s",
             chain={"from": ("ROOT_Anticipate", 9)}),
        Clip("ROOT_Scream", 18, False, [(0, INHALE), (3, SCREAM), (7, SCREAM_FAN), (11, SCREAM_RECOIL),
                                        (15, SCREAM), (18, SCREAM)],
             layer=scream_shake, ease=(3, 15), note="snap to full gape by frame 3, leaves fan + recoil, +-1.5 deg 15 Hz shake",
             chain={"from": ("ROOT_Inhale", 36)}),
        Clip("ROOT_Recover", 30, False, [(0, SCREAM), (4, 0.45 * SCREAM + 0.55 * SQUASH), (8, SQUASH),
                                         (16, 0.4 * SQUASH + 0.6 * TIRED), (30, TIRED)], ease=(8,),
             sk_curve={"k_scream": RECOVER_SCREAM},
             note="deflate, overshoot squash 0.75 h / 1.25 w at 0.27 s, crown slumps; ends == RecoveryIdle f0",
             chain={"from": ("ROOT_Scream", 18), "to": ("ROOT_RecoveryIdle", 0)}),
        Clip("ROOT_RecoveryIdle", 60, True, [(0, TIRED), (30, TIRED)], layer=tired_layer,
             note="tired breathing 0.97..1.00 h, drooped leaves"),
        Clip("ROOT_AirborneLeafTrail", 30, True, [(0, AIR), (15, AIR)], layer=air_layer,
             note="crown pitched -X, leaves trail and flutter, face quiet; root never moves"),
        Clip("ROOT_ImpactSquash", 7, False, [(0, NEUTRAL), (2, IMPACT), (7, NEUTRAL)],
             note="squash 0.80 h / 1.20 w about the bulb centre, back to neutral"),
        Clip("ROOT_SettleRock", 12, False, [(0, NEUTRAL), (12, NEUTRAL)], layer=settle_layer,
             note="damped leaf recoil (2 oscillations), bulb still, ends neutral"),
        Clip("ROOT_PlaceSettle", 7, False, [(0, NEUTRAL), (3, PLACE), (7, NEUTRAL)],
             note="gentle set-down squash 0.92 h then neutral"),
    ]


# B3: the Scream key's teeth cross the lip roll for key values ~0.43..0.67 (measured: 3-5 tooth-vs-lip pairs at every jaw
# angle of the deflate; review/phaseB3/recover_band_grid.txt). The spline put Recover f4 at 0.45 (4 pairs), so the
# ease-out is authored to jump the band between two frames: >= 0.70 on f3, <= 0.30 on f4, eased at both ends, 0 from f8.
RECOVER_SCREAM = [(0, 1.0), (1, 0.94), (2, 0.82), (3, 0.70), (4, 0.30), (5, 0.15), (6, 0.07), (7, 0.02), (8, 0.0)]


# ------------------------------------------------------------------ chain table (from clip, frame) -> (to clip, frame)
CHAINS = [  # (a, fa, b, fb, hard_cut)
    ("ROOT_QuietIdle", 0, "ROOT_Anticipate", 0, False),
    ("ROOT_Anticipate", "N", "ROOT_Inhale", 0, False),
    ("ROOT_Inhale", "N", "ROOT_Scream", 0, False),
    ("ROOT_Scream", "N", "ROOT_Recover", 0, False),
    ("ROOT_Recover", "N", "ROOT_RecoveryIdle", 0, False),
    ("ROOT_RecoveryIdle", 0, "ROOT_AnticipateTired", 0, False),    # B3: gated (<= 0.1 cm / 1 deg)
    ("ROOT_AnticipateTired", "N", "ROOT_Inhale", 0, False),
    ("ROOT_RecoveryIdle", "any", "ROOT_AnticipateTired", 0, True),
    ("ROOT_RecoveryIdle", 0, "ROOT_Anticipate", 0, True),           # Phase B cut, kept for comparison
    ("ROOT_QuietIdle", "any", "ROOT_Anticipate", 0, True),
    ("ROOT_RecoveryIdle", "any", "ROOT_Anticipate", 0, True),
    ("SRC_Idle", 0, "SRC_Grip", 0, False),
    ("SRC_Grip", "N", "SRC_Tug", 0, False),
    ("SRC_Tug", "N", "SRC_Release", 0, False),
    ("SRC_Tug", "N", "SRC_Cancel", 0, False),
    ("SRC_Cancel", "N", "SRC_Idle", 0, False),
    ("SRC_Release", "N", "ROOT_QuietIdle", 0, False),
]


INJECTED = ("SRC_Tug", "SRC_Cancel", "SRC_Release")        # Phase K: pose-only clips, shown with the runtime crown offset
DEFAULT_STRETCH = (146.2, 20.0)       # Phase K: the bed's FMars_ScreamingTurnipBed_StretchSpec default (TravelCm, LiftCm), UE cm
SUBFRAME_CLIPS = {"ROOT_Inhale": 36, "ROOT_Scream": 6, "ROOT_Recover": 10}   # half-frame info audit (not gated)
SK_NAMES = tuple(BT.SHAPE_KEYS.values())          # ("Inhale", "Scream")
SK_PARAM = {nm: k for k, nm in BT.SHAPE_KEYS.items()}


def sk_values(ob):
    kb = ob.data.shape_keys.key_blocks
    return np.array([float(kb[n].value) for n in SK_NAMES])


def pose_snapshot(arm):
    out = {}
    for pb in arm.pose.bones:
        m = pb.matrix
        out[pb.name] = (np.array(m.translation), m.to_quaternion())
    out[SKV] = sk_values(bpy.data.objects[BT.MESH_NAME])
    return out


SKV = "__shape_keys__"


def snap_delta(a, b):
    """(max bone head delta cm, max bone rotation delta deg, max shape-key value delta)."""
    dh, dr = 0.0, 0.0
    for n in a:
        if n == SKV:
            continue
        dh = max(dh, float(np.linalg.norm(a[n][0] - b[n][0])))
        d = math.degrees(a[n][1].rotation_difference(b[n][1]).angle)
        dr = max(dr, min(d, 360 - d))
    dk = float(np.abs(a[SKV] - b[SKV]).max()) if SKV in a and SKV in b else 0.0
    return round(dh, 5), round(dr, 4), round(dk, 6)


def stem_gap(co, tris, tp, tl):
    """Phase I: per leaf, the max signed distance (cm, + = outside) of the stem's embedded base ring (the 4 lowest
    stem_root vertices) from the bulb surface. > 0 means the stem has pulled out of the bulb (a visible gap)."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    bt = tris[tp == BT.PART["bulb"]]
    bvh = BVHTree.FromPolygons([Vector(p) for p in co], [tuple(int(i) for i in t) for t in bt])
    out = []
    for leaf in range(1, 6):
        vs = np.unique(tris[(tp == BT.PART["stem_root"]) & (tl == leaf)].ravel())
        vs = vs[np.argsort(co[vs][:, 2])][:4]
        ds = []
        for i in vs:
            p = Vector(co[i])
            loc, nrm, _idx, d = bvh.find_nearest(p)
            ds.append(d if (p - loc).dot(nrm) > 0 else -d)
        out.append(max(ds))
    return out


def read_locals(arm, prevq):
    """Local channels of every non-root bone (quaternion hemisphere kept continuous frame to frame)."""
    out = {}
    for pb in arm.pose.bones:
        if pb.name == "root":
            continue
        q = pb.rotation_quaternion.copy()
        if pb.name in prevq and prevq[pb.name].dot(q) < 0:
            q.negate()
        prevq[pb.name] = q
        out[pb.name] = (list(q), list(pb.location), list(pb.scale))
    return out


LINEAR = bpy.types.Keyframe.bl_rna.properties["interpolation"].enum_items["LINEAR"].value


def key_action_name(name):
    return name + "_Key"


def assign(idblock, act):
    """Assign `act` (or None) to an ID's animation data, picking its first slot (Blender 4.4+ slotted actions)."""
    ad = idblock.animation_data or idblock.animation_data_create()
    ad.action = act
    if act is not None and getattr(ad, "action_slot", None) is None and len(getattr(act, "slots", [])):
        ad.action_slot = act.slots[0]


def write_key_action(key, name, skv):
    """`<Clip>_Key` on the mesh's Key datablock: `Inhale` and `Scream` values keyed on EVERY frame (LINEAR)."""
    an = key_action_name(name)
    old = bpy.data.actions.get(an)
    if old is not None:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(an)
    act.use_fake_user = True
    assign(key, act)
    nf = len(skv)
    for j, nm in enumerate(SK_NAMES):
        fc = act.fcurve_ensure_for_datablock(key, 'key_blocks["%s"].value' % nm, index=0, group_name="ShapeKeys")
        fc.keyframe_points.add(nf)
        co = []
        for f in range(nf):
            co += [float(f), float(skv[f][j])]
        fc.keyframe_points.foreach_set("co", co)
        fc.keyframe_points.foreach_set("interpolation", [LINEAR] * nf)
        fc.update()
    return act


def write_action(arm, name, frames):
    """One action named `name` (fake user), every non-root bone keyed on every frame, LINEAR keys."""
    old = bpy.data.actions.get(name)
    if old is not None:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    nf = len(frames)
    for bone in frames[0]:
        for ci, (path, n) in enumerate((("rotation_quaternion", 4), ("location", 3), ("scale", 3))):
            dp = 'pose.bones["%s"].%s' % (bone, path)
            for idx in range(n):
                fc = act.fcurve_ensure_for_datablock(arm, dp, index=idx, group_name=bone)
                fc.keyframe_points.add(nf)
                co = []
                for f in range(nf):
                    co += [float(f), float(frames[f][bone][ci][idx])]
                fc.keyframe_points.foreach_set("co", co)
                fc.keyframe_points.foreach_set("interpolation", [bpy.types.Keyframe.bl_rna.properties[
                    "interpolation"].enum_items["LINEAR"].value] * nf)
                fc.update()
    return act


def shape_profile(c, vals):
    """B3 shape-key contract per clip. vals: (N+1, 2) PLAYED values (Inhale, Scream) per frame."""
    ki, ks = vals[:, 0], vals[:, 1]
    n, fails = c.end, []
    tol = 1e-4

    def peak(x):
        m = float(x.max())
        fr = [int(f) for f in np.nonzero(np.abs(x - m) <= tol)[0]] if m > tol else []
        return {"max": round(m, 6), "frames_at_max": [fr[0], fr[-1]] if fr else []}

    peaks = {"Inhale": peak(ki), "Scream": peak(ks)}
    if c.name == "ROOT_Inhale":
        hold = range(n - 6, n + 1)          # the last 0.2 s
        if abs(ki[0]) > tol or any(abs(ki[f] - 1.0) > tol for f in hold) or np.any(np.diff(ki) < -tol):
            fails.append("%s Inhale ramp %s" % (c.name, np.round(ki, 4).tolist()))
        if np.abs(ks).max() > tol:
            fails.append("%s Scream not 0" % c.name)
    elif c.name == "ROOT_Scream":
        if abs(ks[0]) > tol or any(abs(ks[f] - 1.0) > tol for f in range(3, n + 1)):
            fails.append("%s Scream snap/hold %s" % (c.name, np.round(ks, 4).tolist()))
        if abs(ki[0] - 1.0) > tol or np.abs(ki[3:]).max() > tol:
            fails.append("%s Inhale hand-off %s" % (c.name, np.round(ki, 4).tolist()))
    elif c.name == "ROOT_Recover":
        z = [f for f in range(n + 1) if ks[f] <= tol]
        if abs(ks[0] - 1.0) > tol or not z or z[0] > 8 or np.any(np.diff(ks) > tol) or np.abs(ki).max() > tol:
            fails.append("%s Scream ease-out %s" % (c.name, np.round(ks, 4).tolist()))
        peaks["Scream"]["zero_from_frame"] = z[0] if z else None
    else:
        if np.abs(vals).max() > tol:
            fails.append("%s shape keys not 0 (%s)" % (c.name, np.abs(vals).max(0).round(4).tolist()))
    return {"peaks": peaks, "fails": fails,
            "per_frame": {"Inhale": np.round(ki, 4).tolist(), "Scream": np.round(ks, 4).tolist()}}


def inject_audit(arm, ob, T, L, review):
    """Phase K: the deformation gates on SRC_Tug / SRC_Cancel WITH the runtime crown offset the anim blueprint adds
    (ModifyBone, crown, component space, Add): (-T * a, 0, L * a) UE cm, a = f / 15 on SRC_Tug and 1 - f / 7 on SRC_Cancel
    (the bed drives the offset with the Control alpha while gripped and 1 - played alpha while the cancel plays).
    Blender world cm == UE cm in x / z (y flips; the offset has no y), the armature at the origin. The clip pose comes from
    the authored spline (== the exported action, audited to 1e-4 cm); the offset is added to the crown's armature-space
    matrix, so the stems, leaves and sockets follow as they do under the ABP. Gates: every intersection category 0,
    stem_gap <= 0, the neck (dimple <= 9 cm x / <= 3 cm z from SRC_Tug f0, ring below the dimple). Never saves."""
    from mathutils import Matrix, Vector
    clips = {c.name: c for c in build_clips(BT.unit(arm))}
    cg = ob.vertex_groups["crown"].index
    bulb_crown = [v.index for v in ob.data.vertices if any(g.group == cg and g.weight > 0 for g in v.groups)
                  and not any(ob.vertex_groups[g.group].name.startswith("leaf_") for g in v.groups)]
    dimple = [i for i in bulb_crown if abs(ob.data.vertices[i].co.x) < 1e-4 and abs(ob.data.vertices[i].co.y) < 1e-4]
    ring = [i for i in bulb_crown if i not in dimple]
    meas = json.load(open(os.path.join(ROOT, "review", "phaseB4", "measurements.json")))
    hg = Vector(meas["landmarks"]["sockets_blender_cm"]["HarvestGrip_R"])
    crinv = arm.data.bones["crown"].matrix_local.inverted()
    arm.animation_data.action = None
    assign(ob.data.shape_keys, None)
    ref = None
    out = {"T_cm": T, "L_cm": L, "offset": "(-T * a, 0, L * a) UE cm on the crown, component space", "clips": {},
           "fails": [], "release_info": []}
    # SRC_Release: the bed does not play it (Script: no k_Clip_Release); audited as if released from full strain with the
    # offset shrinking over its 6 frames (a = 1 - f / 6), so a future use starts from a known state.
    for name, n, alpha in (("SRC_Tug", 15, lambda f: f / 15.0), ("SRC_Cancel", 7, lambda f: 1.0 - f / 7.0),
                           ("SRC_Release", 6, lambda f: 1.0 - f / 6.0)):
        c = clips[name]
        rows = []
        for f in range(n + 1):
            a = alpha(f)
            BT.apply_params(arm, c.sample(float(f)))
            pb = arm.pose.bones["crown"]
            pb.matrix = Matrix.Translation(Vector((-T * a, 0.0, L * a))) @ pb.matrix
            bpy.context.view_layer.update()
            co, tris, tp, tl = turnip_audit.evaluated(ob)
            if ref is None:
                ref = co.copy()            # SRC_Tug f0, a 0: the neck's zero
            isect = {k: x for k, x in turnip_audit.intersections(ob, BT.PART).items()
                     if x and "(info)" not in k and "(sum)" not in k}
            gap = max(stem_gap(co, tris, tp, tl))
            dd = co[dimple[0]] - ref[dimple[0]]
            rmax = float(np.linalg.norm(co[ring] - ref[ring], axis=1).max())
            dn = float(np.linalg.norm(dd))
            crown = np.array(arm.matrix_world @ pb.head)
            sock = np.array(arm.matrix_world @ pb.matrix @ crinv @ hg)
            neck_ok = abs(dd[0]) <= 9.0 and dd[2] <= 3.0 and (rmax < dn or (rmax == 0.0 and dn == 0.0))
            row = {"f": f, "a": round(a, 4), "crown_ue_xz": [round(float(crown[0]), 3), round(float(crown[2]), 3)],
                   "socket_R_ue": [round(float(sock[0]), 3), round(float(-sock[1]), 3), round(float(sock[2]), 3)],
                   "isect": isect, "stem_gap": round(gap, 4), "dimple_d_xz": [round(float(dd[0]), 3), round(float(dd[2]), 3)],
                   "ring_max_d": round(rmax, 3), "neck_ok": bool(neck_ok)}
            rows.append(row)
            for why, bad in (("intersections %s" % isect, bool(isect)), ("stem_gap %.3f" % gap, gap > 0),
                             ("neck dimple %s ring %.2f" % (row["dimple_d_xz"], rmax), not neck_ok)):
                if bad:      # SRC_Release is info only: the bed never plays it, and its a = 1 - f / 6 is an assumption
                    out["fails" if name != "SRC_Release" else "release_info"].append("%s f%d (a %.2f): %s" % (name, f, a, why))
        full = rows[-1] if name == "SRC_Tug" else rows[0]
        out["clips"][name] = {"rows": rows, "stem_gap_max": max(r["stem_gap"] for r in rows),
                              "isect_frames": [r["f"] for r in rows if r["isect"]],
                              "dimple_d_at_full": full["dimple_d_xz"], "ring_max_d_at_full": full["ring_max_d"],
                              "crown_at_full": full["crown_ue_xz"], "socket_R_at_full": full["socket_R_ue"]}
    BT.apply_params(arm, NEUTRAL)
    os.makedirs(review, exist_ok=True)
    path = os.path.join(review, "inject_%g_%g.json" % (T, L))
    with open(path, "w") as fh:
        json.dump(out, fh, indent=1)
    tug = out["clips"]["SRC_Tug"]
    print("INJECT T %g L %g: fails %d; Tug stem_gap %.3f isect frames %s crown %s dimple %s ring %.2f; Cancel isect frames %s;"
          " Release isect frames %s" % (T, L, len(out["fails"]), tug["stem_gap_max"], tug["isect_frames"], tug["crown_at_full"],
                                        tug["dimple_d_at_full"], tug["ring_max_d_at_full"],
                                        out["clips"]["SRC_Cancel"]["isect_frames"], out["clips"]["SRC_Release"]["isect_frames"]))
    return out


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--inject-stretch" in argv:          # Phase K: audit only (no actions written, no save)
        T, L = (float(x) for x in argv[argv.index("--inject-stretch") + 1].split(","))
        review = os.path.join(ROOT, "review", argv[argv.index("--review") + 1]) if "--review" in argv else REVIEW
        arm = bpy.data.objects[BT.ARM_NAME]
        arm.animation_data_create()
        res = inject_audit(arm, bpy.data.objects[BT.MESH_NAME], T, L, review)
        if res["fails"]:
            print("TURNIP_FAIL inject %g,%g: %s" % (T, L, "; ".join(res["fails"][:6])))
            sys.exit(1)
        print("TURNIP_OK inject %g,%g" % (T, L))
        return
    only = argv[argv.index("--clips") + 1].split(",") if "--clips" in argv else None
    do_audit = "--no-audit" not in argv
    do_save = "--no-save" not in argv
    review = os.path.join(ROOT, "review", argv[argv.index("--review") + 1]) if "--review" in argv else REVIEW
    blend_out, variant = BLEND, argv[argv.index("--variant") + 1] if "--variant" in argv else None
    if variant == "3x":         # Part 1d preview: 3x poses, scratch blend, no export/anims/clips.json (frames unchanged)
        global STRAIN, TUG_MID
        STRAIN, TUG_MID = STRAIN_3X, TUG_MID_3X
        blend_out = os.path.join(ROOT, "source", "ScreamingTurnip_R01_phaseJ_3x_preview.blend")
    elif variant is not None:
        raise RuntimeError("unknown --variant %s" % variant)
    t_start = time.time()
    fails = []
    sc = bpy.context.scene
    sc.render.fps, sc.render.fps_base = FPS, 1.0
    arm = bpy.data.objects[BT.ARM_NAME]
    ob = bpy.data.objects[BT.MESH_NAME]
    arm.animation_data_create()
    arm.animation_data.action = None
    key = ob.data.shape_keys
    if key is None or any(n not in key.key_blocks for n in SK_NAMES):
        raise RuntimeError("mesh has no shape keys %s (B2b builder output expected)" % (SK_NAMES,))
    assign(key, None)
    U = BT.unit(arm)
    print("ANIM_UNIT", U)
    envelope = tuple(x * U for x in ENVELOPE)
    clips = build_clips(U)
    if only:
        clips = [c for c in clips if c.name in only]
    old = bpy.data.actions.get(BT.CLIP_ACTION)
    if old is not None:                       # Phase A scream-test action is superseded by the real clips
        bpy.data.actions.remove(old)

    snaps, report, clip_json = {}, {}, {}
    env_min, env_max = np.full(3, 1e9), np.full(3, -1e9)
    for c in clips:
        # pass A: evaluate the parameter splines with no action assigned (nothing can overwrite the pose)
        arm.animation_data.action = None
        assign(key, None)
        prevq, frames, authored, skv = {}, [], {}, []
        for f in range(c.end + 1):
            v = c.sample(float(f))
            BT.apply_params(arm, v)
            frames.append(read_locals(arm, prevq))
            authored[f] = pose_snapshot(arm)
            skv.append([float(v[I[SK_PARAM[n]]]) for n in SK_NAMES])
        skv = np.array(skv)
        if skv.min() < -1e-6 or skv.max() > 1 + 1e-6:
            fails.append("%s shape-key value outside [0, 1]: min %.4f max %.4f" % (c.name, skv.min(), skv.max()))
        # pass B: write the actions (armature + Key); pass C: play them back frame by frame and audit what the
        # ACTIONS produce
        write_action(arm, c.name, frames)
        write_key_action(key, c.name, skv)
        per = {"stem_gap_max_cm": -1e9, "stem_gap_frames": [], "root_max_dev": 0.0, "ue_dev_max_cm": 0.0, "isect_max": {}, "isect_frames": {}, "bounds": {},
               "action_vs_authored_max": [0.0, 0.0, 0.0]}
        snaps[c.name] = {}
        for f in range(c.end + 1):
            sc.frame_set(f)
            snaps[c.name][f] = pose_snapshot(arm)
            d = snap_delta(snaps[c.name][f], authored[f])
            per["action_vs_authored_max"] = [max(a_, b_) for a_, b_ in zip(per["action_vs_authored_max"], d)]
            if not do_audit:
                continue
            rm = arm.pose.bones["root"].matrix
            per["root_max_dev"] = max(per["root_max_dev"], float(np.abs(np.array(rm) - np.eye(4)).max()))
            co, tris, tp, tl = turnip_audit.evaluated(ob)
            g = max(stem_gap(co, tris, tp, tl))
            per["stem_gap_max_cm"] = round(max(per["stem_gap_max_cm"], g), 4)
            if g > 0:
                per["stem_gap_frames"].append(f)
            mn, mx = co.min(0), co.max(0)
            env_min, env_max = np.minimum(env_min, mn), np.maximum(env_max, mx)
            per["bounds"][f] = {"min": mn.round(3).tolist(), "max": mx.round(3).tolist()}
            isect = turnip_audit.intersections(ob, BT.PART)
            for k, x in isect.items():
                if "(info)" in k or "(sum)" in k:
                    continue
                if x > per["isect_max"].get(k, 0):
                    per["isect_max"][k] = x
                if x:
                    per["isect_frames"].setdefault(k, []).append(f)
            dev, _vi = turnip_audit.ue_composition_deviation(arm, ob)
            per["ue_dev_max_cm"] = max(per["ue_dev_max_cm"], dev)
        if do_audit and c.name in SUBFRAME_CLIPS:
            sub = {}
            for f in range(min(c.end, SUBFRAME_CLIPS[c.name])):
                sc.frame_set(f, subframe=0.5)
                isect = turnip_audit.intersections(ob, BT.PART)
                bad = {k: x for k, x in isect.items() if x and "(info)" not in k and "(sum)" not in k}
                if bad:
                    sub["%d.5" % f] = dict(bad, sk=[round(float(x), 3) for x in sk_values(ob)])
            per["subframe_isect_info"] = sub
            sc.frame_set(0)
        arm.animation_data.action = None
        assign(key, None)
        if per["action_vs_authored_max"][0] > 1e-4 or per["action_vs_authored_max"][1] > 0.01 or \
                per["action_vs_authored_max"][2] > 1e-5:
            fails.append("%s action playback != authored %s" % (c.name, per["action_vs_authored_max"]))
        # shape-key profile per clip (the B3 contract)
        played = np.array([snaps[c.name][f][SKV] for f in range(c.end + 1)])
        prof = shape_profile(c, played)
        per["shape_keys"] = prof
        fails += prof.pop("fails")
        # loop seam: pose (frame N vs 0) and velocity (N-1 -> N vs 0 -> 1)
        s0, sN = snaps[c.name][0], snaps[c.name][c.end]
        seam = {"pose_delta_cm_deg": snap_delta(s0, sN)}
        if c.loop:
            v_end = {n: sN[n][0] - snaps[c.name][c.end - 1][n][0] for n in s0}
            v_start = {n: snaps[c.name][1][n][0] - s0[n][0] for n in s0}
            seam["velocity_delta_cm_per_frame"] = round(max(float(np.linalg.norm(v_end[n] - v_start[n]))
                                                            for n in s0), 5)
            if seam["pose_delta_cm_deg"][0] > 1e-3 or seam["pose_delta_cm_deg"][1] > 0.01 or \
                    seam["pose_delta_cm_deg"][2] > 1e-6:
                fails.append("%s loop seam %s" % (c.name, seam))
        if do_audit:
            b = per["bounds"]
            mins = np.array([x["min"] for x in b.values()]).min(0)
            maxs = np.array([x["max"] for x in b.values()]).max(0)
            per["clip_bounds"] = {"min": mins.round(3).tolist(), "max": maxs.round(3).tolist(),
                                  "h_z": round(float(maxs[2] - mins[2]), 3), "w_y": round(float(maxs[1] - mins[1]), 3),
                                  "d_x": round(float(maxs[0] - mins[0]), 3)}
            del per["bounds"]
            if per["root_max_dev"] > 1e-6:
                fails.append("%s root moves %.2e" % (c.name, per["root_max_dev"]))
            if c.name.startswith("SRC_") and per["stem_gap_max_cm"] > 0:      # Phase I: gated on the pull clips
                fails.append("%s stem base out of the bulb %.3f cm (frames %s)" % (c.name, per["stem_gap_max_cm"],
                                                                                  per["stem_gap_frames"]))
            if per["ue_dev_max_cm"] > 1e-3:
                fails.append("%s Unreal composition deviation %.4f" % (c.name, per["ue_dev_max_cm"]))
            for k, x in per["isect_max"].items():
                allowed = 3 if (k == "outer_shell_self" and c.name in ("ROOT_Scream", "ROOT_Recover")) else 0
                if c.name in INJECTED and x > allowed:
                    # Phase K: these clips are the pull's pose only and never render without the runtime crown offset;
                    # alone (offset 0) the pitched crown lays the leaves on the bulb. Info here; gated below by the
                    # injected default (DEFAULT_STRETCH) and by the --inject-stretch sweep.
                    per.setdefault("standalone_isect_info", {})[k] = x
                    continue
                if x > allowed:
                    fails.append("%s %s max %d (frames %s)" % (c.name, k, x, per["isect_frames"].get(k)))
        per["seam"] = seam
        per["frames"] = [0, c.end]
        per["samples"] = c.end + 1
        report[c.name] = per
        clip_json[c.name] = {"fps": FPS, "frames": [0, c.end], "samples": c.end + 1, "loop": c.loop,
                             "duration_s": round(c.end / FPS, 4), "export_action": c.name,
                             "export_key_action": key_action_name(c.name), "note": c.note,
                             "chain": c.chain, "key_frames": [int(k) if k == int(k) else round(float(k), 4) for k in c.F],   # 1c: f3.267
                             "shape_keys": {n: [round(float(x), 6) for x in played[:, j]] for j, n in enumerate(SK_NAMES)},
                             "shape_key_peaks": prof["peaks"]}
        print("CLIP %-24s frames 0..%-3d loop %-5s stem_gap %.3f isect_max %s ue_dev %.6f seam %s sk_peaks %s" % (
            c.name, c.end, c.loop, per["stem_gap_max_cm"], json.dumps(per["isect_max"]), per["ue_dev_max_cm"], json.dumps(seam),
            json.dumps(prof["peaks"])))

    # ---- chain
    chain_rep = []
    if not only:
        for a, fa, b, fb, hard in CHAINS:
            sb = snaps[b][fb]
            if fa == "any":
                worst = max((snap_delta(snaps[a][f], sb) for f in snaps[a]), key=lambda x: (x[0], x[1]))
                d = worst
            else:
                f = max(snaps[a]) if fa == "N" else fa
                d = snap_delta(snaps[a][f], sb)
            row = {"from": "%s f%s" % (a, fa), "to": "%s f%d" % (b, fb), "max_head_delta_cm": d[0],
                   "max_rot_delta_deg": d[1], "max_shape_key_delta": d[2], "hard_cut": hard}
            chain_rep.append(row)
            print("CHAIN %-34s -> %-25s %8.4f cm %8.3f deg sk %.4f %s" % (row["from"], row["to"], d[0], d[1], d[2],
                                                                         "HARD CUT (reported)" if hard else ""))
            if not hard and (d[0] > 0.1 or d[1] > 1.0 or d[2] > 1e-3):
                fails.append("chain %s -> %s %s" % (row["from"], row["to"], d))

    if do_audit and not only and variant is None:          # Phase K: the pose clips gated with the shipped default offset
        inj = inject_audit(arm, ob, DEFAULT_STRETCH[0], DEFAULT_STRETCH[1], review)
        fails += ["injected default: " + f for f in inj["fails"]]
        arm.animation_data_create()
        arm.animation_data.action = None
        assign(key, None)

    env = None
    if do_audit:
        size = env_max - env_min
        env = {"min": env_min.round(3).tolist(), "max": env_max.round(3).tolist(),
               "h_z": round(float(size[2]), 3), "w_y": round(float(size[1]), 3), "d_x": round(float(size[0]), 3),
               "limit_h_w_d": list(envelope),
               "exceeds": {k: round(float(x - lim), 3) for k, x, lim in
                           (("h", size[2], envelope[0]), ("w", size[1], envelope[1]), ("d", size[0], envelope[2]))
                           if x > lim}}
        print("ENVELOPE", json.dumps(env))
    planted = None
    if not only or "SRC_Idle" in (only or []):
        BT.apply_params(arm, PLANT)
        co, tris, tp, tl = turnip_audit.evaluated(ob)
        l0 = co[list(ob["mouth_L0"])]
        bulb = co[np.unique(tris[np.isin(tp, [BT.PART["bulb"]])].ravel())]
        soil_z = BT.P["SOIL_Z"] * U
        planted = {"body_offset_z_cm": round(PLANT_DZ * U, 4), "seam_top_z": round(float(l0[:, 2].max()), 3),
                   "bulb_top_z": round(float(bulb[:, 2].max()), 3), "soil_line_z": round(soil_z, 4),
                   "shoulder_above_soil_cm": round(float(bulb[:, 2].max()) - soil_z, 3),
                   "taproot_tip_z": round(float(co[:, 2].min()), 3)}
        print("PLANTED", json.dumps(planted))
        if planted["seam_top_z"] >= soil_z:
            fails.append("planted seam above the soil line")
        BT.apply_params(arm, NEUTRAL)

    os.makedirs(review, exist_ok=True)
    os.makedirs(ANIMS, exist_ok=True)
    if not only:
        with open(os.path.join(review, "anim_report.json"), "w") as fh:
            json.dump({"clips": report, "chain": chain_rep, "envelope": env, "planted": planted,
                       "fails": fails, "seconds": round(time.time() - t_start, 1)}, fh, indent=1)
        if variant is None:
            with open(os.path.join(ANIMS, "clips.json"), "w") as fh:
                json.dump(clip_json, fh, indent=1)
    arm.animation_data.action = None
    assign(key, None)
    for n in SK_NAMES:
        key.key_blocks[n].value = 0.0
    sc.frame_set(0)
    if do_save:
        bpy.ops.wm.save_as_mainfile(filepath=blend_out)
    if fails:
        print("TURNIP_FAIL " + "; ".join(fails))
        sys.exit(1)
    print("TURNIP_OK (%d clips, %.0f s)" % (len(clips), time.time() - t_start))


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        print("TURNIP_FAIL exception")
        sys.exit(1)
