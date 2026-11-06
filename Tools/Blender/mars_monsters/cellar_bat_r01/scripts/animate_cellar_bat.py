"""Cellar Bat R01 - Phase 4: author the 18 clips on the control rig, bake them to the export skeleton, audit them.

Opens source/CellarBat_R01.blend (built by build_cellar_bat.py), and for every clip of ANIMATION_LIST.csv:
  1. builds a control action `CellarBat_R01_<Clip>_Ctl` on `CellarBat_R01_Controls` (30 fps, frames 0..N),
  2. bakes it onto the 42 export bones with bake_cellar_bat.bake() into an export action named exactly `<Clip>`
     (the bake proves baked == live rig, root identity on every frame, no scale keys),
  3. audits every baked frame: cross-part triangle intersections (bat_audit.intersections on LOD0), loop seam
     (pose and tangent), foot contact drift against the perch bar, wing-tip landmarks at the flap keys,
then saves the .blend (rig constraints live again, export armature without an assigned action) and writes
review/phase4/anim_report.json + export/anims/clips.json (what the exporter / round trip read).

How a clip is made (no keyframe soups):
  POSE LIBRARY   parametric specs in the builder's pose language (build_cellar_bat.pose_rotations: body pitch/roll/bank,
                 spine/neck/head, per-wing elev/sweep/adduct/twist/roll/flex/wflex/fan/curl/thumb, legs, ears) plus the
                 rig sliders (fold, fan, ears, jaw, perch) and per-control offsets (`extra`: bone -> [(axis, deg)]),
                 and two captured rig poses read back from the Phase 3 pose actions (`Hang`, `Wrap`).
  KEYS           (frame, pose) pairs per clip; a pose = library pose + overrides.
  TIMING         every control channel (location xyz + quaternion wxyz of each control bone) is a Catmull-Rom spline
                 through the keys; loops are periodic splines (frame N == frame 0 in value AND slope); one-shots
                 ease in/out at the ends. Per-group time lags give overlap: fingers + fan (membrane drag) lag the
                 arm, ears and legs lag the body (`lags`).
  LAYERS         optional per-frame functions adding small rotations on top (breathing, tremble, wobble).
Loop convention (every loop): N+1 samples, frame N duplicates frame 0 (Hover/FlyForward 16 samples, Glide/Stun 31,
RoostIdle 61), as the CSV's sample_count; the importer reads N+1 keys and a length of N/30 s.

Run:
  blender -b --factory-startup source/CellarBat_R01.blend --python scripts/animate_cellar_bat.py -- \
      [--clips A,B] [--no-audit] [--no-save]
Prints CELLAR_BAT_OK / CELLAR_BAT_FAIL <reason>.
"""
import json
import math
import os
import sys
import time
import traceback

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import bake_cellar_bat  # noqa: E402
import bat_audit  # noqa: E402
import bat_rig  # noqa: E402
import build_cellar_bat as bcb  # noqa: E402   (pose language + PART; its main() is not run)

ROOT = os.path.dirname(HERE)
REVIEW = os.path.join(ROOT, "review", "phase4")
ANIM_OUT = os.path.join(ROOT, "export", "anims")
BLEND = os.path.join(ROOT, "source", "CellarBat_R01.blend")
FPS = 30
CTL_SUFFIX = "_Ctl"
POSE = "CellarBat_R01_Pose_"
BAR = Vector((3.0, 0.0, 18.75))     # perch bar centre (Blender cm), radius 1.0, along Y (build_cellar_bat)
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
CROSS = ("memb_l_body", "memb_r_body", "memb_l_legs", "memb_r_legs", "ribs_l_body", "ribs_r_body",
         "ribs_l_legs", "ribs_r_legs", "memb_l_memb_r", "ribs_l_ribs_r", "memb_opp_ribs")
TIP_BONES = ("finger_01b_l", "finger_01b_r", "finger_03b_l", "finger_03b_r", "wrist_l", "wrist_r")

# ------------------------------------------------------------------ pose library (builder pose language)
FLAP = {}  # filled below (hand_untwist needs the builder frame)
_FLAP = {   # Hover cycle keys 0/4/8/12 (15 == 0). Exaggerated from the Phase 3 test: higher V, deeper fold on recovery.
    "Up": {"wing": {"elev": 44, "sweep": -24, "flex": 30, "wflex": 26, "fan": 0.16, "curl": 8},
           "body": {"pitch": -4, "spine": -3, "head": 12}, "ear": {"base": 8, "splay": -10}, "leg": {"thigh": 10}},
    "Power": {"wing": {"elev": 2, "sweep": 12, "flex": 0, "wflex": 0, "fan": -0.04, "curl": 0, "twist": 8},
              "body": {"pitch": 0, "spine": 0, "head": 0}, "ear": {"base": 2, "splay": -10}, "leg": {"thigh": 2}},
    "Down": {"wing": {"elev": -50, "sweep": 26, "flex": 6, "wflex": 4, "fan": 0.04, "curl": -4, "twist": 36,
                      "roll": -10},
             "body": {"pitch": 5, "spine": 4, "head": -4}, "ear": {"base": -8, "splay": -10}, "leg": {"thigh": -6}},
    "Recover": {"wing": {"elev": 14, "sweep": 2, "flex": 62, "wflex": -36, "fan": 0.26, "curl": 12, "twist": 28,
                         "roll": -6},
                "body": {"pitch": 1, "spine": 1, "head": 2}, "ear": {"base": -2, "splay": -10}, "leg": {"thigh": 4}},
}
GLIDE = {"wing": {"elev": 6, "sweep": 4, "flex": 4, "wflex": 2, "fan": -0.06, "curl": 2, "twist": 4},
         "body": {"pitch": 6, "head": -4}, "ear": {"base": -6}, "leg": {"thigh": 18}}


def hand_untwist(k=0.8):
    """Turn the hand's fingers back toward the stroke plane (graded f1 > f4) about the span axis, so a twisted
    downstroke shows its hand membrane from the front while finger 4 / the inner panel keep the arm twist that clears
    the flank (searched: k 0.8 lifts the front-projected membrane area ~65% with zero cross-part contact)."""
    ex = {}
    for side, sfx in ((1, "_l"), (-1, "_r")):
        A_ = bcb.wing_frame(side)[0]
        for i, d in ((1, -30), (2, -24), (3, -14), (4, -4)):
            ex["finger_0%da%s" % (i, sfx)] = [(A_, d * k * side)]
        ex["wrist" + sfx] = [(A_, -6 * k * side)]
    return {"extra": ex}


def merge(*specs):
    """Deep-merge pose specs (later wins per key); `extra` lists are concatenated."""
    out = {}
    for s in specs:
        for k, v in (s or {}).items():
            if k == "extra":
                ex = out.setdefault("extra", {})
                for bn, lst in v.items():
                    ex[bn] = ex.get(bn, []) + list(lst)
            elif isinstance(v, dict):
                out[k] = dict(out.get(k, {}), **v)
            else:
                out[k] = v
    return out


def scale_spec(s, k):
    return {g: ({p: v * k for p, v in d.items()} if isinstance(d, dict) and g != "extra" else d) for g, d in s.items()}


# ------------------------------------------------------------------ control-space poses
CTRL = None
ARM = None
CH = []            # control bone names (fixed order)
DETAIL = False
LODS = []
BASES = {}         # captured rig poses: name -> {bone: np.array(7)}


def rest_pose():
    return {b: np.array([0, 0, 0, 1, 0, 0, 0], dtype=float) for b in CH}


def read_action_pose(name):
    bat_rig.use_action(CTRL, bpy.data.actions[POSE + name], 0)
    out = {}
    for b in CH:
        pb = CTRL.pose.bones[b]
        q = pb.rotation_quaternion
        out[b] = np.array([*pb.location, q.w, q.x, q.y, q.z], dtype=float)
    bat_rig.use_action(CTRL, None, 0)
    bat_rig.reset(CTRL)
    return out


def local_q(bone, q_world):
    r = ARM.data.bones[bone].matrix_local.to_quaternion()
    return r.inverted() @ q_world @ r


SLIDERS = bat_rig.SLIDERS


def make_pose(spec=None, base=None, sl=None):
    """spec: builder pose spec (+ `extra`); base: captured rig pose name or a control pose dict; sl: slider values.
    Spec rotations multiply on top of the base's control rotations (local)."""
    spec = spec or {}
    if base is None:
        pose = rest_pose()
    elif isinstance(base, str):
        pose = {b: v.copy() for b, v in BASES[base].items()}
    else:
        pose = {b: v.copy() for b, v in base.items()}
    rots = bcb.pose_rotations(spec)
    for bn, lst in spec.get("extra", {}).items():
        q = rots.get(bn, Quaternion())
        for axis, deg in lst:
            q = bcb.qaxis(Vector(axis), deg) @ q
        rots[bn] = q
    for bn, q in rots.items():
        if q.angle < 1e-9:
            continue
        c = "CTL_" + bn
        v = pose[c]
        qb = Quaternion(v[3:7])
        qn = qb @ local_q(bn, q)
        v[3:7] = (qn.w, qn.x, qn.y, qn.z)
    for k, val in (sl or {}).items():
        bn, ax, lo, hi = SLIDERS[k]
        pose[bn][ax] = val
    return pose


def apply_controls(pose):
    for b in CH:
        pb = CTRL.pose.bones[b]
        v = pose[b]
        pb.location = Vector(v[:3])
        q = Quaternion(v[3:7])
        q.normalize()
        pb.rotation_quaternion = q


# ------------------------------------------------------------------ timing: Catmull-Rom over keys, lags, layers
GROUPS = {
    "fingers": lambda b: b.startswith(("CTL_finger_", "CTL_thumb_", "CTL_fan_")),
    "ears": lambda b: b.startswith(("CTL_ear_")) or b == "CTL_ears",
    "legs": lambda b: b.startswith(("CTL_thigh_", "CTL_shin_", "CTL_foot_l", "CTL_foot_r")),
    "head": lambda b: b in ("CTL_head", "CTL_neck", "CTL_jaw", "CTL_jaw_open"),
}


class Clip:
    def __init__(self, name, end, loop, keys, lags=None, layer=None, markers=None, ease=None, note=""):
        self.name, self.end, self.loop, self.note = name, end, loop, note
        self.keys = sorted(keys, key=lambda k: k[0])
        self.lags = lags or {}
        self.layer = layer
        self.markers = markers or {}
        self.ease = set(ease or ())       # key frames held with zero slope
        self._prep()

    def _prep(self):
        fr = [k[0] for k in self.keys]
        if self.loop and fr[-1] == self.end:
            raise ValueError("%s: loops are keyed on [0, N); frame N is frame 0" % self.name)
        self.frames = np.array(fr, dtype=float)
        self.vals = {}
        for b in CH:
            arr = np.array([k[1][b] for k in self.keys], dtype=float)
            for i in range(1, len(arr)):           # quaternion hemisphere continuity
                if np.dot(arr[i, 3:], arr[i - 1, 3:]) < 0:
                    arr[i, 3:] *= -1
            if self.loop and len(arr) > 1 and np.dot(arr[0, 3:], arr[-1, 3:]) < 0:
                raise ValueError("%s: loop quaternion hemisphere wraps on %s" % (self.name, b))
            self.vals[b] = arr

    def _eval(self, arr, t):
        F, n = self.frames, len(self.frames)
        if n == 1:
            return arr[0].copy()
        if self.loop:
            P = float(self.end)
            t = t % P
            Fx = np.concatenate([F[-2:] - P, F, F[:2] + P])
            Ax = np.concatenate([arr[-2:], arr, arr[:2]])
            off = 2
        else:
            t = min(max(t, F[0]), F[-1])
            Fx, Ax, off = F, arr, 0
        i = int(np.searchsorted(Fx, t, side="right") - 1)
        i = min(max(i, off), off + n - (1 if self.loop else 2))
        t0, t1 = Fx[i], Fx[i + 1]
        p0, p1 = Ax[i], Ax[i + 1]

        def slope(j):
            if not self.loop and (j == 0 or j == n - 1):
                return np.zeros_like(arr[0])
            if not self.loop and int(Fx[j]) in self.ease:
                return np.zeros_like(arr[0])
            if self.loop and int(Fx[j] % self.end) in self.ease:
                return np.zeros_like(arr[0])
            return (Ax[j + 1] - Ax[j - 1]) / (Fx[j + 1] - Fx[j - 1])

        m0, m1 = slope(i), slope(i + 1)
        h = t1 - t0
        s = (t - t0) / h
        s2, s3 = s * s, s * s * s
        return ((2 * s3 - 3 * s2 + 1) * p0 + (s3 - 2 * s2 + s) * h * m0 + (-2 * s3 + 3 * s2) * p1
                + (s3 - s2) * h * m1)

    def sample(self, t):
        pose = {}
        for b in CH:
            lag = 0.0
            for g, test in GROUPS.items():
                if g in self.lags and test(b):
                    lag = self.lags[g]
                    break
            v = self._eval(self.vals[b], t - lag)
            q = v[3:7]
            v[3:7] = q / max(np.linalg.norm(q), 1e-12)
            pose[b] = v
        pose = fold_corrective(pose)
        if self.layer is not None:
            add = self.layer(t)
            if add:
                pose = make_pose(add.get("spec"), pose, None)
                for k, dv in add.get("sl", {}).items():
                    bn, ax, lo, hi = SLIDERS[k]
                    pose[bn][ax] = min(max(pose[bn][ax] + dv, lo), hi)
        return pose


def _smooth(a, b, x):
    x = min(max((x - a) / (b - a), 0.0), 1.0)
    return x * x * (3 - 2 * x)


FOLD_FIX = {"elev": 8.0, "sweep": 8.0, "adduct": -8.0}


def fold_corrective(pose):
    """The rig's fold slider interpolates Euler angles between the solved half fold (0.5) and wrap (1.0); between
    ~0.55 and ~0.70 the inner panel grazes the flank (5-8 triangle pairs, measured on the Wrap base). Every clip adds
    this corrective as a smooth function of the slider value itself (upper arm +8 elev, +8 sweep, -8 adduct, full
    weight on 0.55..0.70, zero below 0.48 and above 0.76), so it is continuous, loop-safe and absent outside the band."""
    spec = {}
    for side, key in (("l", "wing"), ("r", "wing_r")):
        f = pose[SLIDERS["fold_" + side][0]][SLIDERS["fold_" + side][1]]
        w = _smooth(0.48, 0.55, f) * (1.0 - _smooth(0.70, 0.76, f))
        spec[key] = {k: v * w for k, v in FOLD_FIX.items()}
    if max(abs(v) for d in spec.values() for v in d.values()) < 1e-6:
        return pose
    return make_pose(spec, pose, None)


# ------------------------------------------------------------------ clip definitions
def flap_keys(variant=None, base=None, wing_scale=None):
    """Keys 0/4/8/12 of the flap cycle (frame 15 == 0 by periodicity). variant: per-key overrides."""
    out = []
    for f, n in ((0, "Up"), (4, "Power"), (8, "Down"), (12, "Recover")):
        spec = merge(FLAP[n], (variant or {}).get("all"), (variant or {}).get(n))
        out.append((f, make_pose(spec, base, (variant or {}).get("sl"))))
    return out


def sinp(t, period, phase=0.0):
    return math.sin(2 * math.pi * (t / period + phase))


def bump(t, a, b):
    """Smooth 0 -> 1 -> 0 bump on [a, b] (zero value and slope outside)."""
    if t <= a or t >= b:
        return 0.0
    x = (t - a) / (b - a)
    return math.sin(math.pi * x) ** 2


HANG_SL = {"fold_l": 1.0, "fold_r": 1.0, "perch": 1.0}


def build_clips():
    FLAP.clear()
    FLAP.update(_FLAP)
    FLAP["Down"] = merge(_FLAP["Down"], hand_untwist(0.6))
    C = {}
    hover_lags = {"fingers": 1.5, "ears": 2.0, "legs": 2.5}

    # ---- Hover: the full beat in place
    C["Hover"] = Clip("Hover", 15, True, flap_keys(), lags=hover_lags, ease=(0, 8),
                      markers={"Wingbeat": 6}, note="flap keys 0 Up / 4 Power / 8 Down / 12 Recover / 15 = 0")
    # ---- FlyForward: body pitched forward, flatter downstroke, legs trailing
    ff = {"all": {"body": {"pitch": 24, "head": -16}, "leg": {"thigh": 30, "knee": 6}, "ear": {"base": -10}},
          "Up": {"wing": {"elev": 35, "sweep": -24}, "body": {"pitch": 20, "head": -2}, "leg": {"thigh": 34}},
          "Down": {"wing": {"elev": -38, "sweep": 22, "twist": 30}, "body": {"pitch": 28, "head": -18},
                   "leg": {"thigh": 26}},
          "Power": {"wing": {"sweep": 8}},
          "Recover": {"wing": {"flex": 56}}}
    C["FlyForward"] = Clip("FlyForward", 15, True, flap_keys(ff), lags=hover_lags, ease=(0, 8), markers={"Wingbeat": 6},
                           note="Hover cycle, body pitched +24 deg, downstroke -38 instead of -50")

    # ---- Glide: spread, subtle finger flex, one slow 1 s breath
    def glide_layer(t):
        b = sinp(t, 30)
        f = sinp(t, 30, 0.2)
        return {"spec": {"body": {"spine": 1.6 * b, "head": -0.8 * b},
                         "wing": {"elev": 2.0 * b, "curl": 3.0 * f, "wflex": 1.5 * f},
                         "ear": {"base": 1.5 * sinp(t, 30, 0.35)}}}
    C["Glide"] = Clip("Glide", 30, True, [(0, make_pose(GLIDE))], layer=glide_layer,
                      note="spread glide + 1 s breath (spine/wing elev) and finger flex, all sin(2 pi t/30)")

    # ---- Banks: one frame each, built ON Hover frame 0 (the additive reference) + the bank intent
    href = C["Hover"].sample(0.0)
    for name, s in (("BankLeft", 1), ("BankRight", -1)):
        inner, outer = ("wing", "wing_r") if s > 0 else ("wing_r", "wing")
        spec = {"body": {"bank": -25 * s},
                inner: {"elev": -30, "sweep": 10, "twist": 10},
                outer: {"elev": -4, "sweep": -8, "flex": -6},
                "extra": {"head": [(X, 12 * s)], "neck": [(X, 5 * s)]},
                "ear": {"base": 2, "splay": -10}}
        C[name] = Clip(name, 1, False, [(0, make_pose(spec, href))],   # one key held: frame 1 == frame 0
                       note="full pose = Hover frame 0 + body roll %+d deg toward the bat's own %s, inner wing -30, "
                            "outer -4 (raised by the roll), head counter-roll; additive reference = Hover frame 0. CSV says 0-0; padded to 2 identical samples because the Unreal FBX importer rejects a zero-length take" %
                            (-25 * s, "left" if s > 0 else "right"))

    # ---- RoostIdle: the Phase 3b hang, quiet breathing, one ear twitch, seamless 2 s loop
    hang = make_pose(None, "Hang")

    def roost_layer(t):
        b = sinp(t, 30)
        tw = bump(t, 34, 44)
        return {"spec": {"body": {"spine": 1.4 * b, "pitch": 0.6 * sinp(t, 60, 0.1), "head": -1.2 * b}},
                "sl": {"ear_twitch": 0.9 * tw}}
    C["RoostIdle"] = Clip("RoostIdle", 60, True, [(0, hang)], layer=roost_layer, ease=(0,),
                          note="Hang pose (fold 1, perch 1, feet IK on the bar); breath period 1 s; ear twitch 34-44")

    # ---- RoostAlert: partial unwrap, ears up, head turns toward +X
    alert = make_pose({"body": {"head": -18, "neck": -6}}, "Hang",
                      {"fold_l": 0.86, "fold_r": 0.9, "perch": 1.0, "ear_alert": 1.0})
    alert_peek = make_pose({"body": {"head": -24, "neck": -8}}, "Hang",
                           {"fold_l": 0.82, "fold_r": 0.88, "perch": 1.0, "ear_alert": 1.0})
    C["RoostAlert"] = Clip("RoostAlert", 18, False, [(0, hang), (4, make_pose({"body": {"head": -4}}, "Hang",
                                                                              dict(HANG_SL, ear_alert=0.6))),
                                                     (11, alert_peek), (18, alert)],
                           lags={"ears": 1.0, "fingers": 1.5}, ease=(4,),
                           note="fold 1 -> 0.82-0.90 (partial unwrap), ears alert, head lifts so the face points +X")

    # ---- Launch: feet release (root stays), body rotates from inverted to flight, wings into the first downstroke
    # intermediate attitudes as pelvis world rotations (pelvis rest = identity frame offset handled by local_q)
    q_hang = bcb.qaxis(Y, 30.0) @ bcb.qaxis(X, 180.0)
    q_dive = bcb.qaxis(Y, 75.0)
    D = q_dive @ q_hang.inverted()
    ax, ang = D.to_axis_angle()
    q_mid = Quaternion(ax, ang * 0.5) @ q_hang

    def body_q(q):
        return {"extra": {"pelvis": [(q.axis, math.degrees(q.angle))]}}
    rel = make_pose({"body": {"head": 10}}, "Hang", dict(HANG_SL, ear_alert=0.5))
    l0 = {b: v.copy() for b, v in BASES["Hang"].items()}      # the hang without its body inversion
    l0["CTL_pelvis"][3:7] = (1, 0, 0, 0)
    l0b = {b: v.copy() for b, v in l0.items()}                    # ... and with the wrap's legs, not the aimed hang legs
    for s_ in "lr":
        for bn in ("thigh_", "shin_", "foot_"):
            l0b["CTL_" + bn + s_] = BASES["Wrap"]["CTL_" + bn + s_].copy()   # the wrap's legs (spread -6)
    l0b[SLIDERS["perch"][0]][SLIDERS["perch"][1]] = 0.0                # feet free
    drop = make_pose(merge(body_q(q_mid), {"body": {"head": -10}}),
                     l0b, {"fold_l": 0.85, "fold_r": 0.85, "perch": 0.0, "ear_alert": -0.4})
    dive = make_pose(merge(body_q(q_dive), {"body": {"head": -40},
                                            "wing": {"elev": 10, "sweep": -16, "flex": 24, "wflex": 16, "fan": 0.25},
                                            "leg": {"thigh": 30, "knee": 10}, "ear": {"base": -12, "splay": -10}}),
                     None, {"ear_alert": -0.5})
    mid_open = make_pose(merge(body_q(q_mid.slerp(q_dive, 0.5)), {"body": {"head": -25}}), l0b,
                         {"fold_l": 0.45, "fold_r": 0.45, "ear_alert": -0.5})
    pull = make_pose(merge(FLAP["Up"], {"wing": {"elev": 36}, "body": {"pitch": 30, "head": -2},
                                        "leg": {"thigh": 12}}), None,
                     {"ear_alert": -0.3})
    first_down = make_pose(merge(FLAP["Down"], {"body": {"pitch": 7}}))
    C["Launch"] = Clip("Launch", 24, False, [(0, hang), (5, rel), (10, drop), (12, mid_open), (15, dive),
                                             (19, pull), (21, make_pose(merge(FLAP["Power"], {"body": {"pitch": 14}}))),
                                             (24, first_down)],
                       lags={"fingers": 1.5, "ears": 2.0, "legs": 1.5}, ease=(5,), markers={"ReleaseContact": 6},
                       note="feet on the bar until 5, perch off by 10; pelvis hang -> half-turn -> dive -> flight")

    # ---- Brake: cup wings forward, feet drop and reach
    cup = {"wing": {"elev": 20, "sweep": 24, "flex": 24, "wflex": 18, "fan": 0.08, "curl": 10, "twist": 10},
           "body": {"pitch": -26, "spine": -6, "head": 14}, "ear": {"base": 10}, "leg": {"thigh": -40, "knee": -18,
                                                                                         "foot": -20}}
    cup_hold = merge(cup, {"wing": {"elev": 16, "sweep": 20}, "body": {"pitch": -30}})
    C["Brake"] = Clip("Brake", 18, False, [(0, make_pose(FLAP["Up"])), (3, make_pose(FLAP["Power"])),
                                           (6, make_pose(FLAP["Down"])),
                                           (11, make_pose(cup, None, {"ear_alert": 0.6})),
                                           (14, make_pose(merge(cup_hold, {"wing": {"elev": 22}}), None,
                                                          {"ear_alert": 0.8})),
                                           (18, make_pose(cup_hold, None, {"ear_alert": 0.8}))],
                      lags={"fingers": 1.5, "ears": 2.0, "legs": 2.0}, ease=(6,), note="one braking beat, then wings cup forward")

    # ---- Perch: reach, grip (FootContact), rotate to hanging, wrap
    q_back = bcb.qaxis(Y, -70.0)
    D2 = q_hang @ q_back.inverted()
    ax2, ang2 = D2.to_axis_angle()
    q_mid2 = Quaternion(ax2, ang2 * 0.5) @ q_back
    reach = make_pose(merge(body_q(q_back), {"body": {"head": 10}, "wing": {"elev": 20, "sweep": 10, "flex": 20,
                                                                           "wflex": 14, "fan": 0.1},
                                             "leg": {"thigh": -30, "foot": -15}}),
                      l0b, {"ear_alert": 0.6, "perch": 0.0, "fold_l": 0.0, "fold_r": 0.0})
    swing = make_pose(merge(body_q(q_mid2), {"body": {"head": 14}}), l0b,
                      {"ear_alert": 0.3, "perch": 0.0, "fold_l": 0.75, "fold_r": 0.75})
    C["Perch"] = Clip("Perch", 24, False, [(0, make_pose(cup_hold, None, {"ear_alert": 0.8})), (5, reach),
                                           (7, make_pose(merge(body_q(q_back.slerp(q_mid2, 0.5)),
                                                               {"body": {"head": 12}}), l0b,
                                                         {"ear_alert": 0.4, "fold_l": 0.45, "fold_r": 0.45})),
                                           (9, swing),
                                           (12, make_pose({"body": {"head": 14}}, "Hang",
                                                          {"fold_l": 0.82, "fold_r": 0.82, "perch": 1.0})),
                                           (18, make_pose({"body": {"head": 6}}, "Hang",
                                                          {"fold_l": 0.95, "fold_r": 0.95, "perch": 1.0})),
                                           (24, hang)],
                      lags={"fingers": 0.5, "ears": 2.0}, ease=(12,), markers={"FootContact": 12},
                      note="brake -> pitch back with feet reaching (5) -> swing (9) -> feet on the bar at 12 "
                           "(perch 1, IK) -> wrap by 24 = RoostIdle frame 0")

    # ---- Screech: jaw open, ears back, wings braced; ScreechSound at 9
    brace = {"wing": {"elev": 18, "sweep": 6, "flex": 6, "wflex": 4, "fan": -0.12, "curl": -4},
             "body": {"pitch": -6, "spine": -4, "head": -10, "neck": -6}, "ear": {"base": -6}, "leg": {"thigh": 6}}
    C["Screech"] = Clip("Screech", 24, False, [
        (0, make_pose(FLAP["Up"])),
        (4, make_pose(merge(brace, {"body": {"head": 10, "pitch": 2}}), None, {"ear_alert": 0.4})),
        (9, make_pose(brace, None, {"jaw_open": 1.0, "ear_alert": -0.9})),
        (16, make_pose(merge(brace, {"body": {"head": -12}}), None, {"jaw_open": 0.9, "ear_alert": -1.0})),
        (21, make_pose(merge(FLAP["Power"], {"body": {"head": -2}}), None, {"jaw_open": 0.1, "ear_alert": -0.2})),
        (24, make_pose(FLAP["Up"]))],
        lags={"fingers": 1.5, "ears": 1.0}, markers={"ScreechSound": 9},
        layer=lambda t: {"spec": {"body": {"head": 1.2 * bump(t, 9, 17) * sinp(t, 2.5)},
                                  "wing": {"elev": 1.5 * bump(t, 9, 17) * sinp(t, 3.0)}}},
        note="anticipation dip 4, snap open 9, shudder 9-17, release by 24 (ends on Hover frame 0)")

    # ---- SwoopTelegraph: rear-up windup
    wind = {"wing": {"elev": 44, "sweep": -24, "flex": 36, "wflex": 30, "fan": 0.2, "curl": 10},
            "body": {"pitch": -24, "spine": -8, "head": 22, "neck": 8}, "ear": {"base": 12, "splay": -10},
            "leg": {"thigh": -10, "knee": -20}}
    C["SwoopTelegraph"] = Clip("SwoopTelegraph", 18, False, [
        (0, make_pose(FLAP["Up"])), (3, make_pose(FLAP["Power"])), (6, make_pose(FLAP["Down"])),
        (9, make_pose(FLAP["Recover"])),
        (13, make_pose(wind, None, {"ear_alert": 1.0, "jaw_open": 0.3})),
        (18, make_pose(merge(wind, {"wing": {"elev": 46}, "body": {"pitch": -28}}), None,
                       {"ear_alert": 1.0, "jaw_open": 0.35}))],
        lags={"fingers": 1.5, "ears": 1.5}, ease=(6, 13),
        layer=lambda t: {"spec": {"body": {"spine": 0.8 * bump(t, 13, 19) * sinp(t, 2.0)}}},
        note="one beat down, rear up with wings high, hold quivering")

    # ---- Swoop: tuck and extend, contact near 9
    tuck = {"wing": {"elev": -10, "sweep": -30, "flex": 50, "wflex": 30, "fan": 0.6, "curl": 12},
            "body": {"pitch": 40, "head": -20}, "ear": {"base": -30}, "leg": {"thigh": 30, "knee": 20}}
    strike = {"wing": {"elev": 20, "sweep": 6, "flex": 20, "wflex": 10, "fan": 0.2},
              "body": {"pitch": 10, "spine": -6, "head": -10, "neck": -10}, "ear": {"base": -14},
              "leg": {"thigh": -50, "knee": -10, "foot": -20}}
    C["Swoop"] = Clip("Swoop", 18, False, [
        (0, make_pose(merge(wind, {"wing": {"elev": 46}, "body": {"pitch": -28}}), None,
                      {"ear_alert": 1.0, "jaw_open": 0.35})),
        (2, make_pose(merge(tuck, {"wing": {"elev": 24, "flex": 40}, "body": {"pitch": 10}}), None,
                      {"ear_alert": -0.2, "jaw_open": 0.3})),
        (5, make_pose(tuck, None, {"ear_alert": -0.6, "jaw_open": 0.2})),
        (9, make_pose(strike, None, {"ear_alert": -0.8, "jaw_open": 1.0})),
        (14, make_pose(merge(FLAP["Power"], {"body": {"pitch": 6}}), None, {"jaw_open": 0.3})),
        (18, make_pose(merge(FLAP["Up"], {"body": {"pitch": 6}})))],
        lags={"fingers": 1.0, "ears": 1.5, "legs": 1.0}, ease=(9,), markers={"SwoopContact": 9},
        note="telegraph end -> tuck 5 -> feet/jaw strike 9 -> wings reopening into Hover frame 0 (pitched +6)")

    # ---- SwoopRecover: open and pull out
    C["SwoopRecover"] = Clip("SwoopRecover", 18, False, [
        (0, make_pose(merge(FLAP["Up"], {"body": {"pitch": 6}}))),
        (3, make_pose(merge(FLAP["Power"], {"body": {"pitch": 2}}))),
        (6, make_pose(merge(FLAP["Down"], {"wing": {"elev": -54}, "body": {"pitch": -2, "head": 4}}))),
        (10, make_pose(merge(FLAP["Recover"], {"body": {"pitch": -10}}))),
        (13, make_pose(FLAP["Up"])),
        (18, make_pose(FLAP["Up"]))],
        lags={"fingers": 1.5, "ears": 2.0, "legs": 2.5}, ease=(6,), note="one hard pull-out beat, ends on Hover frame 0")

    # ---- Hit: asymmetric recoil
    recoil = {"body": {"pitch": -14, "roll": 16, "spine": -6}, "extra": {"head": [(X, 18)], "neck": [(X, 8)]},
              "wing": {"elev": 38, "sweep": -26, "flex": 40, "wflex": 30, "fan": 0.25},
              "wing_r": {"elev": -30, "sweep": 26, "flex": 6, "wflex": 4, "fan": 0.04, "twist": 36, "roll": -10},
              "ear": {"base": -14}, "leg": {"thigh": 14, "knee": 10}}
    C["Hit"] = Clip("Hit", 12, False, [(0, make_pose(FLAP["Up"])),
                                       (2, make_pose(recoil, None, {"ear_alert": -1.0, "jaw_open": 0.5})),
                                       (6, make_pose(scale_spec(recoil, 0.45), None,
                                                     {"ear_alert": -0.5, "jaw_open": 0.2})),
                                       (12, make_pose(FLAP["Up"]))],
                lags={"fingers": 1.0, "ears": 1.5, "legs": 1.5},
                note="snap at 2 (left wing flung up, right dropped, body rolled), settles to Hover frame 0")

    # ---- Stun: unsteady hover with flattened ears (loop 30)
    stun_keys = []
    for f, n in ((0, "Up"), (8, "Power"), (15, "Down"), (23, "Recover")):
        stun_keys.append((f, make_pose(merge(scale_spec(FLAP[n], 0.7), {"ear": {"base": -20, "splay": -12}}), None,
                                       {"ear_alert": -0.55, "jaw_open": 0.15})))

    def stun_layer(t):
        return {"spec": {"body": {"bank": 10 * sinp(t, 30), "pitch": 6 * sinp(t, 15, 0.2), "head": 8 * sinp(t, 30, 0.3)},
                         "extra": {"head": [(X, -10 * sinp(t, 30, 0.1))]},
                         "wing_r": {"elev": -8 * sinp(t, 30)}, "wing": {"elev": 3 * sinp(t, 30)}}}
    C["Stun"] = Clip("Stun", 30, True, stun_keys, lags={"fingers": 2.0, "ears": 3.0, "legs": 3.0, "head": 2.0},
                     layer=stun_layer, note="half-rate weak flap, lopsided body wobble, ears flat")

    # ---- DeathFall: limp collapse
    limp = {"wing": {"elev": 35, "sweep": -24, "flex": 40, "wflex": 24, "fan": 0.3, "curl": 14},
            "wing_r": {"elev": 27, "sweep": -18, "flex": 46, "wflex": 24, "fan": 0.35, "curl": 16},
            "body": {"pitch": 50, "roll": 14, "spine": 8, "head": 30, "neck": 10},
            "ear": {"base": -30, "splay": -10}, "leg": {"thigh": 10, "knee": 24, "foot": 20}}
    C["DeathFall"] = Clip("DeathFall", 21, False, [
        (0, make_pose(FLAP["Up"])),
        (4, make_pose(merge(recoil, {"wing_r": {"elev": -12}}), None, {"ear_alert": -0.6, "jaw_open": 0.6})),
        (10, make_pose(scale_spec(limp, 0.7), None, {"ear_alert": -0.4, "jaw_open": 0.4})),
        (21, make_pose(limp, None, {"ear_alert": -0.4, "jaw_open": 0.35}))],
        lags={"fingers": 0.5, "ears": 2.5, "legs": 2.0, "head": 2.0}, note="hit jolt then wings go limp")

    # ---- DeathLand: impact and settle
    flat = {"body": {"pitch": 82, "roll": 10, "head": -10}, "extra": {"head": [(X, 30)]},
            "wing": {"elev": -12, "sweep": 44, "flex": 10, "wflex": 6, "fan": 0.1, "curl": 6, "twist": 36},
            "wing_r": {"elev": -8, "sweep": 38, "flex": 18, "wflex": 10, "fan": 0.2, "curl": 8, "twist": 36},
            "ear": {"base": -22}, "leg": {"thigh": 40, "knee": 20}}
    C["DeathLand"] = Clip("DeathLand", 18, False, [
        (0, C["DeathFall"].sample(21)),
        (3, make_pose(merge(flat, {"wing": {"elev": 4}, "wing_r": {"elev": 4}, "body": {"pitch": 74}}), None,
                      {"ear_alert": -0.5, "jaw_open": 0.5})),
        (7, make_pose(merge(flat, {"wing": {"elev": -16}, "wing_r": {"elev": -8}}), None,
                      {"ear_alert": -0.5, "jaw_open": 0.3})),
        (11, make_pose(merge(flat, {"wing": {"elev": -9}}), None, {"ear_alert": -0.5, "jaw_open": 0.32})),
        (18, make_pose(flat, None, {"ear_alert": -0.5, "jaw_open": 0.3}))],
        lags={"fingers": 1.5, "ears": 2.0, "head": 1.0}, ease=(18,),
        note="impact at 3, one bounce, settled belly-down with wings flat by 18")
    return C


# ------------------------------------------------------------------ authoring, bake, audit
CSV = [("RoostIdle", 60, True), ("RoostAlert", 18, False), ("Launch", 24, False), ("Hover", 15, True),
       ("FlyForward", 15, True), ("Glide", 30, True), ("BankLeft", 1, False), ("BankRight", 1, False),   # CSV 0-0, see BANK_PAD
       ("Brake", 18, False), ("Perch", 24, False), ("Screech", 24, False), ("SwoopTelegraph", 18, False),
       ("Swoop", 18, False), ("SwoopRecover", 18, False), ("Hit", 12, False), ("Stun", 30, True),
       ("DeathFall", 21, False), ("DeathLand", 18, False)]


BANK_PAD = "CSV says 0-0; padded to 2 identical samples because the Unreal FBX importer rejects a zero-length take"


def author(clip):
    name = "CellarBat_R01_%s%s" % (clip.name, CTL_SUFFIX)
    old = bpy.data.actions.get(name)
    if old is not None:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    CTRL.animation_data_create()
    CTRL.animation_data.action = act
    for f in range(clip.end + 1):
        apply_controls(clip.sample(float(f)))
        bat_rig.key_all(CTRL, f)
    act.use_frame_range = True
    act.frame_start, act.frame_end = 0, max(clip.end, 0)
    CTRL.animation_data.action = None
    bat_rig.reset(CTRL)
    return act


def foot_world():
    return {s: (ARM.matrix_world @ ARM.pose.bones["foot_" + s].tail) for s in "lr"}


def audit(clip, baked, lod0):
    sc = bpy.context.scene
    ARM.animation_data.action = baked
    if ARM.animation_data.action_slot is None and len(baked.slots):
        ARM.animation_data.action_slot = baked.slots[0]
    frames = {}
    mats = {}
    for f in range(clip.end + 1):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        r = bat_audit.intersections(lod0, bcb.PART)
        lod_cross = {}
        for li, lob in enumerate(LODS[1:], 1):
            rl = bat_audit.intersections(lob, bcb.PART)
            lod_cross["LOD%d" % li] = sum(rl[k] for k in CROSS)
        mats[f] = bat_rig.pose_matrices(ARM)
        tips = {b: [round(x, 4) for x in (ARM.matrix_world @ ARM.pose.bones[b].tail)] for b in TIP_BONES}
        fw = foot_world()
        frames[f] = {"cross": {k: r[k] for k in CROSS}, "cross_lod12": lod_cross, "self_l": r["memb_l_self"], "self_r": r["memb_r_self"],
                     "attach_memroot_body": r["attach_memroot_body"], "attach_ribroot_body": r["attach_ribroot_body"],
                     "tips": tips, "feet": {s: [round(x, 4) for x in v] for s, v in fw.items()},
                     "bar_dist_cm": round(min(((v - BAR) * Vector((1, 0, 1))).length - 1.0 for v in fw.values()), 3)}
    if DETAIL:
        bad = [f for f, d in frames.items() if sum(d["cross"].values())]
        for f in bad:
            sc.frame_set(f)
            bpy.context.view_layer.update()
            body = ("torso", "head", "face", "tuft", "ear", "ruff")
            print("  DETAIL %s f%02d %s ribs->%s memb->%s body<-%s legs<-%s" % (
                clip.name, f, {k: v for k, v in frames[f]["cross"].items() if v},
                bat_audit.overlap_detail(lod0, bcb.PART, ("rib_l", "rib_r"), body + ("leg",)),
                bat_audit.overlap_detail(lod0, bcb.PART, ("mem_l", "mem_r"), body + ("leg",)),
                bat_audit.overlap_detail(lod0, bcb.PART, body, ("rib_l", "rib_r", "mem_l", "mem_r")),
                bat_audit.overlap_detail(lod0, bcb.PART, ("leg",), ("rib_l", "rib_r", "mem_l", "mem_r"))))
    rep = {"frames_with_cross_contact": [f for f, d in frames.items() if sum(d["cross"].values())],
           "cross_worst": {k: max(d["cross"][k] for d in frames.values()) for k in CROSS},
           "cross_worst_LOD1": max(d["cross_lod12"]["LOD1"] for d in frames.values()),
           "cross_worst_LOD2": max(d["cross_lod12"]["LOD2"] for d in frames.values()),
           "pleat_self_max": [max(d["self_l"] for d in frames.values()), max(d["self_r"] for d in frames.values())],
           "per_frame": frames}
    if clip.loop:
        p0 = max((mats[0][b].translation - mats[clip.end][b].translation).length for b in mats[0])
        r0 = max(math.degrees(mats[0][b].to_quaternion().rotation_difference(mats[clip.end][b].to_quaternion()).angle)
                 for b in mats[0])
        v_in = {b: mats[clip.end][b].translation - mats[clip.end - 1][b].translation for b in mats[0]}
        v_out = {b: mats[1][b].translation - mats[0][b].translation for b in mats[0]}
        dv = max((v_in[b] - v_out[b]).length for b in mats[0])
        vmax = max(max(v.length for v in v_in.values()), 1e-9)
        # second difference elsewhere in the clip, for scale: the largest per-frame velocity change inside the loop
        acc = 0.0
        for f in range(1, clip.end):
            for b in mats[0]:
                a = (mats[f + 1][b].translation - mats[f][b].translation) - (mats[f][b].translation -
                                                                              mats[f - 1][b].translation)
                acc = max(acc, a.length)
        rep["loop_seam"] = {"pose_pos_err_cm": round(p0, 6), "pose_rot_err_deg": round(r0, 5),
                            "seam_velocity_change_cm_per_frame": round(dv, 4),
                            "max_velocity_change_inside_clip_cm_per_frame": round(acc, 4),
                            "seam_ok": p0 < 1e-3 and r0 < 0.01 and dv <= acc + 1e-6}
    return rep


def main():
    global CTRL, ARM, CH
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = argv[argv.index("--clips") + 1].split(",") if "--clips" in argv else None
    do_audit = "--no-audit" not in argv
    do_save = "--no-save" not in argv
    global DETAIL
    DETAIL = "--detail" in argv
    t0 = time.time()
    sc = bpy.context.scene
    sc.render.fps, sc.render.fps_base = FPS, 1.0
    meas = json.load(open(os.path.join(ROOT, "review", "phase3b", "measurements.json")))
    bcb.SPAN_K[0] = meas["span_k"]
    ARM = bpy.data.objects[bcb.ARM_NAME]
    CTRL = bpy.data.objects[bat_rig.CTRL_NAME]
    CH = [pb.name for pb in CTRL.pose.bones]
    for n in ("Hang", "Wrap"):
        BASES[n] = read_action_pose(n)
    clips = build_clips()
    if sorted(clips) != sorted(n for n, _, _ in CSV):
        raise RuntimeError("clip set %s" % sorted(clips))
    lod0 = bpy.data.objects[bcb.LOD_NAMES[0]]
    for n in bcb.LOD_NAMES:
        bpy.data.objects[n].hide_set(False)
        LODS.append(bpy.data.objects[n])
    os.makedirs(REVIEW, exist_ok=True)
    os.makedirs(ANIM_OUT, exist_ok=True)
    report_path = os.path.join(REVIEW, "anim_report.json")
    report = json.load(open(report_path)) if (only and os.path.exists(report_path)) else {"clips": {}}
    fails = []
    if "--keys" in argv:           # debug: audit each clip's key poses statically through the live rig
        bat_rig.mute(ARM, False)
        for name, end, loop in CSV:
            if only and name not in only:
                continue
            for f, kp in clips[name].keys:
                apply_controls(fold_corrective(kp))
                bpy.context.view_layer.update()
                r = bat_audit.intersections(lod0, bcb.PART)
                print("KEY %-15s f%02d %s" % (name, f, {k: v for k, v in r.items() if k in CROSS and v}))
        return
    for name, end, loop in CSV:
        if only and name not in only:
            continue
        clip = clips[name]
        if clip.end != end or clip.loop != loop:
            fails.append("%s range/loop differs from the CSV" % name)
        ctl = author(clip)
        baked, brep, ok = bake_cellar_bat.bake(ctl.name, name, 0, end)
        if not ok:
            fails.append("%s bake %s" % (name, json.dumps(brep)))
        entry = {"frames": [0, end], "samples": end + 1, "fps": FPS, "loop": loop, "markers": clip.markers,
                 "control_action": ctl.name, "export_action": baked.name, "bake": brep, "note": clip.note,
                 "keys": [int(k[0]) for k in clip.keys], "lags": clip.lags}
        if do_audit:
            a = audit(clip, baked, lod0)
            entry["audit"] = a
            print("AUDIT %-15s cross-frames %s worst %s LOD1 %d LOD2 %d pleat %s seam %s" % (
                name, a["frames_with_cross_contact"], {k: v for k, v in a["cross_worst"].items() if v},
                a["cross_worst_LOD1"], a["cross_worst_LOD2"], a["pleat_self_max"], a.get("loop_seam")))
        report["clips"][name] = entry
        print("CLIP %-15s keys %s bake %s/%s cm %s deg root %s" % (name, entry["keys"], brep["frame_count"],
                                                                   brep["max_head_err_cm"], brep["max_rot_err_deg"],
                                                                   brep["root_max_deviation"]))
        ARM.animation_data.action = None
    for ob in LODS[1:]:
        ob.hide_set(True)
    # leave the scene authorable: rig live, no action on either armature
    bat_rig.mute(ARM, False)
    if ARM.animation_data:
        ARM.animation_data.action = None
    bat_rig.use_action(CTRL, None, 0)
    bat_rig.reset(CTRL)
    sc.frame_set(0)
    report["blender"] = bpy.app.version_string
    report["seconds"] = round(time.time() - t0, 1)
    with open(report_path, "w") as fh:
        json.dump(report, fh, indent=1, default=lambda o: list(o))
    clips_json = {n: {k: v for k, v in e.items() if k != "audit"} for n, e in report["clips"].items()}
    with open(os.path.join(ANIM_OUT, "clips.json"), "w") as fh:
        json.dump(clips_json, fh, indent=1)
    if do_save:
        bpy.ops.wm.save_as_mainfile(filepath=BLEND)
        print("SAVED", BLEND)
    if fails:
        print("CELLAR_BAT_FAIL " + "; ".join(fails))
        sys.exit(1)
    print("CELLAR_BAT_OK %.1fs" % (time.time() - t0))


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        print("CELLAR_BAT_FAIL exception")
        sys.exit(1)
