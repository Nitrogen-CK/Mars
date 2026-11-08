"""Pantry Rat R01 - Phase 2: author the 34 clips of ANIMATION_MANIFEST.csv on the 26 export bones, bake every frame,
audit every frame, save the source and write review/phase2/anim_report.json + export/anims/clips.json.

How a clip is made (Phase 1 pose language, no keyframe soups):
  KEY POSES   specs for build_pantry_rat.apply_pose (armature-space rotations per bone, body/bone offsets, foot IK
              targets) - either a Phase 1 resolved pose (text block PantryRat_R01_PoseDefs.json, incl. its spoon fixes)
              or one built here from the same vocabulary. Every key is audited once; a key whose spoon/harness/head
              collides is closed by the Phase 1 strapped-spoon search (slide / lift / pitch of spoon_prop) - in the source.
  TIMING      every bone channel (location xyz + quaternion wxyz, bone-local) is a cubic Hermite spline through the
              keys: Catmull-Rom tangents inside, periodic for loops (frame N == frame 0 in value AND slope), zero slope
              at the ends of one-shots (ease in / out).
  CONTACTS    the four paws are re-solved every frame (2-bone IK, pole from the splined knee) onto the splined
              armature-space ankle / toe / sole-up of the keys, so a paw that is planted in two keys stays planted
              between them ("ik" clips); falls (topples) use the splined channels directly ("fk").
  ROOT        never keyed (identity on every frame); no scale keys anywhere; body travel is the `body` bone only.
Loops and one-shots alike export frames 0..N (N+1 samples), N = round_half_up(seconds * 30).

Run (from this folder's parent):
  blender -b --factory-startup source/PantryRat_R01.blend --python scripts/animate_pantry_rat.py -- \
      [--clips A,B] [--no-save] [--render] [--render-only] [--sheet-tag rNN]
Prints PANTRY_RAT_OK / PANTRY_RAT_FAIL <reason>; exits non-zero on failure.
"""
import copy
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
import rat_common as rc  # noqa: E402
import build_pantry_rat as B  # noqa: E402   (pose language; its main() is not run)

ROOT = os.path.dirname(HERE)
REVIEW = os.path.join(ROOT, "review", "phase2")
ANIM_OUT = os.path.join(ROOT, "export", "anims")
BLEND = os.path.join(ROOT, "source", "PantryRat_R01.blend")
FPS = 30
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
ARM = None
BODY = None
LOG = []


def log(*a):
    s = " ".join(str(x) for x in a)
    print(s)
    LOG.append(s)


def q_frames(sec):
    """Integer 30 Hz intervals, nearest, half-up."""
    return int(math.floor(sec * FPS + 0.5 + 1e-9))


# ------------------------------------------------------------------ manifest
MANIFEST_CSV = os.path.abspath(os.path.join(ROOT, "..", "..", "..", "..", "docs", "art",
                                            "pantry-rat-dens-production-r01", "ANIMATION_MANIFEST.csv"))


def read_manifest():
    import csv
    with open(MANIFEST_CSV, newline="", encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))
    out = {}
    for r in rows:
        # the csv is rewritten by this phase with the quantised seconds + frames/samples columns; read the
        # authored seconds back from `proposedSeconds` when present
        sec = float(r.get("proposedSeconds") or r["durationSeconds"])
        out[r["name"]] = {"seconds_proposed": sec, "loop": r["loop"].strip().lower() == "true", "state": r["state"],
                          "pose": r["pose"], "cues": r["cues"], "row": r}
    return rows, out


# ------------------------------------------------------------------ spec vocabulary
def planted():
    return B.planted()


def foot(key, d_ank=(0, 0, 0), d_toe=None, frame="world", up=None):
    kind, sfx = key.split("_")
    side = 1 if sfx == "l" else -1
    a, b, c, d = B.leg_rest(kind, side)
    da = Vector(d_ank)
    dt = Vector(d_toe) if d_toe is not None else da
    return (frame, c + da, d + dt, Z if up is None else Vector(up))


def merge(*specs):
    """Deep-merge apply_pose specs: rot lists concatenate per bone, loc vectors add per bone, feet / aim_dir /
    orbit / orbit_frame update per key, anything else replaces."""
    out = {}
    for s in specs:
        if not s:
            continue
        s = copy.deepcopy(s)
        for k, v in s.items():
            if k == "rot":
                r = out.setdefault("rot", {})
                for bn, lst in v.items():
                    r[bn] = list(r.get(bn, [])) + [tuple(x) for x in lst]
            elif k == "loc":
                l_ = out.setdefault("loc", {})
                for bn, vec in v.items():
                    l_[bn] = tuple(Vector(l_.get(bn, (0, 0, 0))) + Vector(vec))
            elif k in ("feet", "aim_dir", "orbit", "orbit_frame"):
                out.setdefault(k, {}).update(v)
            else:
                out[k] = v
    out.setdefault("feet", {})
    return out


def R(**bones):
    """R(neck=[("Y", 5)], ...) -> {"rot": {...}}"""
    return {"rot": {b.replace("__", "_"): v for b, v in bones.items()}}


def L(**bones):
    return {"loc": {b: v for b, v in bones.items()}}


def FEET(**f):
    return {"feet": {k: v for k, v in f.items()}}


def ears(pitch=0.0, splay=0.0, l_extra=None, r_extra=None):
    """Ears back (pitch < 0) / forward (> 0) and splayed outward (splay > 0)."""
    rl = [("Y", pitch), ("X", splay)] + list(l_extra or [])
    rr = [("Y", pitch), ("X", -splay)] + list(r_extra or [])
    return {"rot": {"ear_l": rl, "ear_r": rr}}


def tail(yaw=(0, 0, 0, 0), lift=(0, 0, 0, 0)):
    """Per-segment yaw (+ = tip to rat RIGHT, -Y) and lift (+ = up)."""
    r = {}
    for i, (yw, lf) in enumerate(zip(yaw, lift)):
        lst = []
        if lf:
            lst.append(("Y", lf))
        if yw:
            lst.append(("Z", yw))
        if lst:
            r["tail_0%d" % (i + 1)] = lst
    return {"rot": r}


def mirror_spec(spec):
    """Left/right mirror of a pose spec across the Blender XZ plane. The spoon is asymmetric: its entries are dropped
    (the key's spoon fit is re-solved)."""
    def sw(n):
        return n[:-2] + "_r" if n.endswith("_l") else (n[:-2] + "_l" if n.endswith("_r") else n)

    def ax(a, deg):
        if isinstance(a, str):
            return (a, -deg) if a in ("X", "Z") else (a, deg)
        v = Vector(a)
        return ((v.x, -v.y, v.z), -deg)

    def mv(v):
        v = Vector(v)
        return Vector((v.x, -v.y, v.z))
    out = {}
    for k, v in spec.items():
        if k == "rot":
            out[k] = {sw(b): [ax(a, d) for a, d in lst] for b, lst in v.items() if b != "spoon_prop"}
        elif k == "loc":
            out[k] = {sw(b): tuple(mv(x)) for b, x in v.items() if b != "spoon_prop"}
        elif k == "orbit":
            out[k] = {}
            for b, (a, d, piv) in v.items():
                if b == "spoon_prop":
                    continue
                a2, d2 = ax(a, d)
                out[k][sw(b)] = (a2, d2, tuple(mv(piv)))
        elif k == "orbit_frame":
            out[k] = {sw(b): x for b, x in v.items() if b != "spoon_prop"}
        elif k == "aim_dir":
            out[k] = {sw(b): tuple(mv(x)) for b, x in v.items()}
        elif k == "feet":
            out[k] = {}
            for fk, (fr, ank, toe, up) in v.items():
                out[k][sw(fk)] = (sw(fr) if isinstance(fr, str) else fr, None if ank is None else mv(ank),
                                  None if toe is None else mv(toe), None if up is None else mv(up))
        elif k == "_fix":
            continue
        else:
            out[k] = copy.deepcopy(v)
    return out


POSEDEFS = {}


def phase1(name):
    """A Phase 1 resolved pose (with its spoon fix) as a fresh spec."""
    s = copy.deepcopy(POSEDEFS[name])
    s.pop("_fix", None)
    if "feet" in s:
        s["feet"] = {k: tuple(v) for k, v in s["feet"].items()}
    return s


def strip_spoon(spec):
    s = copy.deepcopy(spec)
    for k in ("rot", "loc", "orbit", "orbit_frame"):
        if k in s:
            s[k].pop("spoon_prop", None)
    return s


# ------------------------------------------------------------------ clip library
NEU = {"feet": planted()}
CROUCH = None
LOADED_HEAD = R(neck=[("Y", -5.0)], head=[("Y", -9.0)], tail_01=[("Y", -6.0)])
JAW_OPEN = 20.0


def bound_keys(n, loaded=False, lift=7.5):
    """Low bound, visual arc only: crouch -> push -> low bound (apex) -> forefeet land -> hind gather -> settle.
    Local stance slides backward at a constant rate (the mover carries the rat forward; frame N == frame 0)."""
    s = n / 12.0

    def t(f):
        return int(round(f * s))
    head = merge(LOADED_HEAD, R(neck=[("Y", -3.0)], head=[("Y", -3.0)])) if loaded else {}
    k = 0.8 if loaded else 1.0     # loaded: flatter body pitch so the item stays clear of the forelegs
    ear_back = ears(-30.0 if not loaded else -38.0, 6.0)
    keys = []
    # f0 crouch / gathered: hind under the body (stance), fore pushing off behind the chest
    keys.append((t(0), merge(L(body=(-0.4, 0, -2.6), chest=(-1.4, 0, 0), pelvis=(1.0, 0, 0)),
                             R(body=[("Y", 3.0 * k)], neck=[("Y", 4.0)], head=[("Y", 2.0)]),
                             ear_back, tail(lift=(4, -4, -2, 0)), head,
                             FEET(fore_l=foot("fore_l", (-4.0, 0, 0.6), (-4.0, 0, 1.6)),
                                  fore_r=foot("fore_r", (-3.0, 0, 0.0)),
                                  hind_l=foot("hind_l", (1.4, 0, 0)), hind_r=foot("hind_r", (0.6, 0, 0))))))
    # f3 push: hind extended back still on the floor, fore swinging forward
    keys.append((t(3), merge(L(body=(0.6, 0, 1.6), chest=(2.4, 0, 0), pelvis=(-1.0, 0, 0)),
                             R(body=[("Y", -9.0 * k)], head=[("Y", 5.0 * k)]), ear_back,
                             tail(lift=(2, -4, -4, 2)), head,
                             FEET(fore_l=foot("fore_l", (3.0, 0, 3.6)), fore_r=foot("fore_r", (2.0, 0, 3.0)),
                                  hind_l=foot("hind_l", (-4.5, 0, 0)), hind_r=foot("hind_r", (-5.0, 0, 0.0))))))
    # f5 apex: <= 8 cm lift, all paws off the floor, fore reaching, hind trailing
    keys.append((t(5), merge(L(body=(0.4, 0, lift), chest=(3.2, 0, 0.4), pelvis=(-1.6, 0, 0)),
                             R(body=[("Y", -3.0 * k)], head=[("Y", 2.0 * k)]), ear_back,
                             tail(lift=(8, 4, 2, 4)), head,
                             FEET(fore_l=foot("fore_l", (6.5, 0, 4.0), (6.5, 0, 3.2)),
                                  fore_r=foot("fore_r", (5.5, 0, 4.4), (5.5, 0, 3.6)),
                                  hind_l=foot("hind_l", (-5.0, 0, 4.2), (-4.0, 0, 3.0)),
                                  hind_r=foot("hind_r", (-5.6, 0, 3.6), (-4.6, 0, 2.6))))))
    # f7 fore land (stance starts at +6), hind swinging under
    keys.append((t(7), merge(L(body=(0.2, 0, 1.0), chest=(1.0, 0, 0)), R(body=[("Y", 8.0 * k)], head=[("Y", -5.0 * k)]),
                             ear_back,
                             tail(lift=(2, 2, 4, 4)), head,
                             FEET(fore_l=foot("fore_l", (4.2, 0, 0)), fore_r=foot("fore_r", (3.6, 0, 0)),
                                  hind_l=foot("hind_l", (0.0, 0, 4.6), (0.5, 0, 3.6)),
                                  hind_r=foot("hind_r", (-0.6, 0, 4.2), (0.0, 0, 3.2))))))
    # f10 hind gather (stance starts at +5.5), fore sliding back
    keys.append((t(10), merge(L(body=(-0.2, 0, -1.8), chest=(-1.2, 0, 0), pelvis=(1.4, 0, 0)),
                              R(body=[("Y", 4.0 * k)], neck=[("Y", 2.0)]), ear_back,
                              tail(lift=(4, -2, -2, 2)), head,
                              FEET(fore_l=foot("fore_l", (-0.6, 0, 0)), fore_r=foot("fore_r", (-1.2, 0, 0)),
                                   hind_l=foot("hind_l", (4.5, 0, 0)), hind_r=foot("hind_r", (3.8, 0, 0))))))
    return keys


def turn_keys(n, side, loaded=False, big=False):
    """In-place turn: the front leads, the hips lag, paws step in sequence; the clip starts and ends in the neutral
    facing (the actor's yaw is SurfaceMotion's, never keyed here)."""
    sg = 1.0 if side == "L" else -1.0
    near, far = ("l", "r") if side == "L" else ("r", "l")
    lead = 1.6 if big else 1.0
    hk = 0.55 if loaded else 1.0      # loaded: smaller head lead so the item swings less
    base = merge(NEU, LOADED_HEAD) if loaded else NEU
    lo = L(body=(0, 0, -1.6 if big else -0.8))
    t = lambda f: int(round(f * n / 9.0))
    keys = [(0, base)]
    keys.append((t(3), merge(base, lo, R(body=[("Z", sg * 10 * lead)], chest=[("Z", sg * 2 * lead)],
                                        neck=[("Z", sg * 14 * lead * hk)], head=[("Z", sg * 12 * lead * hk)]),
                             tail(yaw=(-sg * 0, sg * 10 * lead, sg * 12 * lead, sg * 8)), ears(-10, 4),
                             FEET(**{"fore_" + near: foot("fore_" + near, (1.0, sg * 2.0, 3.0)),
                                     "hind_" + far: foot("hind_" + far, (-0.5, sg * 1.0, 2.6))}))))
    keys.append((t(6), merge(base, lo, R(body=[("Z", sg * 5 * lead)], neck=[("Z", sg * 6 * lead * hk)],
                                        head=[("Z", sg * 4 * lead * hk)]),
                             tail(yaw=(sg * 4, sg * 6, sg * 4, -sg * 2)), ears(-6, 2),
                             FEET(**{"fore_" + far: foot("fore_" + far, (1.0, sg * 1.5, 2.8)),
                                     "hind_" + near: foot("hind_" + near, (-0.5, sg * 1.5, 2.6))}))))
    keys.append((n, base))
    return keys


def build_clips():
    global CROUCH
    CROUCH = phase1("crouch")
    crouch = CROUCH
    stretch = phase1("stretch")
    rear_up = phase1("rear_up")
    jaw_carry = phase1("jaw_carry")
    look_back = phase1("look_back")
    top_l = phase1("topple_left")
    top_r = phase1("topple_right")
    dead = phase1("dead_back")
    den = phase1("den_crouch")
    rummage = phase1("rummage")
    C = {}

    # ---- idle / observe
    C["IdleBreath"] = dict(keys=[
        (0, merge(NEU, tail(yaw=(0, 3, 4, 2)))),
        (20, merge(NEU, L(body=(0, 0, 0.35)), R(chest=[("Y", -1.2)], head=[("Y", 1.0)]), tail(yaw=(0, -2, -3, -2)),
                   ears(2, 0))),
        (40, merge(NEU, L(body=(0, 0, 0.12)), R(chest=[("Y", -0.4)], head=[("Y", -0.6)]), tail(yaw=(0, 1, -3, -4)),
                   ears(-2, 0)))])
    sg = merge(NEU, L(body=(0.6, 0, -1.4)), R(chest=[("Y", 5.0)], neck=[("Y", 14.0)], head=[("Y", 14.0)]),
               ears(-8, 4), tail(lift=(2, 0, 0, 0)))
    C["SniffGround"] = dict(keys=[
        (0, merge(sg, R(head=[("Z", 4.0)]))), (6, merge(sg, R(head=[("Y", 3.0), ("Z", -2.0)]))),
        (12, merge(sg, R(head=[("Z", -4.0)]))), (18, merge(sg, R(head=[("Y", 2.0), ("Z", 1.0)]))),
        (24, merge(sg, R(head=[("Z", 3.0)]), L(body=(0, 0, 0.2)))), (30, merge(sg, R(head=[("Y", 3.0), ("Z", 1.0)])))])
    sa = merge(NEU, L(body=(0, 0, 0.6)), R(chest=[("Y", -3.0)], neck=[("Y", -12.0)], head=[("Y", -14.0)]),
               ears(10, 8))
    C["SniffAir"] = dict(keys=[
        (0, merge(sa, R(head=[("Z", 6.0)]))), (8, merge(sa, R(head=[("Y", -3.0)]), ears(4, 0, [("Y", 8)]))),
        (15, merge(sa, R(head=[("Z", -6.0)]))), (22, merge(sa, R(head=[("Y", -3.0)]), ears(4, 0, None, [("Y", 8)])))])
    st_l, st_r = stretch["feet"]["fore_l"], stretch["feet"]["fore_r"]
    half = lambda f, dz: (f[0], Vector(f[1]) - Vector((4.5, 0, -dz)), Vector(f[2]) - Vector((4.5, 0, -dz)), f[3])
    C["StretchAttend"] = dict(keys=[
        (0, NEU),
        (5, merge(strip_spoon(stretch), L(body=(-1.2, 0, 1.2)), FEET(fore_l=half(st_l, 2.8), fore_r=half(st_r, 2.2)))),
        (10, merge(stretch, R(head=[("Z", 4.0)]))),
        (18, merge(stretch, R(head=[("Y", 3.0), ("Z", -4.0)]), ears(6, 0))),
        (24, merge(strip_spoon(stretch), L(body=(-1.2, 0, 1.2)), FEET(fore_l=half(st_l, 2.8), fore_r=half(st_r, 2.2)))),
        (30, NEU)])
    mid_rear = B.rear_pose(30.0, 8.0, tuck=True)
    C["RearUp"] = dict(keys=[(0, NEU), (4, mid_rear), (8, rear_up)])
    C["RearObserve"] = dict(keys=[
        (0, rear_up), (9, merge(rear_up, R(neck=[("Z", 12.0)], head=[("Y", -4.0)]), ears(4, 6))),
        (18, merge(rear_up, R(head=[("Y", 3.0)]))),
        (27, merge(rear_up, R(neck=[("Z", -12.0)], head=[("Y", -3.0)]), ears(4, 6)))])
    C["RearDown"] = dict(keys=[(0, rear_up), (4, mid_rear), (8, NEU)])

    # ---- move burst
    bk = bound_keys(12)
    fs = bk[0][1]["feet"]
    C["BoundStart"] = dict(keys=[(0, NEU), (2, merge(NEU, L(body=(-0.2, 0, -1.2)), R(body=[("Y", 1.5)]),
                                                     FEET(fore_l=foot("fore_l", (-2.0, 0, 2.2)),
                                                          fore_r=foot("fore_r", (-1.5, 0, 2.0)),
                                                          hind_l=foot("hind_l", (0.7, 0, 1.2)),
                                                          hind_r=foot("hind_r", (0.3, 0, 1.0))))),
                                 (5, bk[0][1])])
    C["BoundCycle"] = dict(keys=bk, locomotion=True)
    squash = merge(NEU, L(body=(0.6, 0, -3.4)), R(chest=[("Y", 6.0)], neck=[("Y", 4.0)], head=[("Y", -2.0)]),
                   ears(-24, 6), tail(lift=(-14, -10, -6, 6)))
    C["BoundStop"] = dict(keys=[(0, bk[0][1]), (2, squash), (5, NEU)], locomotion=True)   # braking slide = mover
    C["TurnLeft90"] = dict(keys=turn_keys(q_frames(0.3), "L"), locomotion=True)
    C["TurnRight90"] = dict(keys=turn_keys(q_frames(0.3), "R"), locomotion=True)
    C["Turn180"] = dict(keys=turn_keys(q_frames(0.45), "L", big=True), locomotion=True)

    # ---- threat
    startle = merge(NEU, L(body=(-1.4, 0, -2.4)), R(chest=[("Y", 4.0)], neck=[("Y", -4.0)], head=[("Y", -6.0)]),
                    ears(-52, 10), tail(lift=(10, 6, 4, 2)))
    C["Startle"] = dict(keys=[(0, NEU), (3, merge(startle, L(body=(0, 0, -0.4)))), (9, merge(startle, ears(4, 0)))])
    back = merge(NEU, L(body=(-2.4, 0, -1.0)), R(neck=[("Y", -3.0)], head=[("Y", -2.0)]), ears(-16, 8))
    C["Backstep"] = dict(keys=[
        (0, NEU),
        (3, merge(back, FEET(fore_l=foot("fore_l", (-2.0, 0, 3.0)), hind_r=foot("hind_r", (-2.0, 0, 2.6))))),
        (6, merge(back, L(body=(-0.8, 0, 0)), FEET(fore_l=foot("fore_l", (-3.0, 0, 0)), hind_r=foot("hind_r", (-3.0, 0, 0)),
                                                    fore_r=foot("fore_r", (-2.0, 0, 3.0)),
                                                    hind_l=foot("hind_l", (-2.0, 0, 2.6))))),
        (11, NEU)], locomotion=True)
    gw = merge(NEU, L(body=(-0.4, 0, -1.0)), R(chest=[("Y", 2.0)]), ears(4, 4))
    C["GuardedWatch"] = dict(keys=[
        (0, merge(gw, R(neck=[("Z", 10.0)], head=[("Z", 8.0)]), tail(yaw=(0, 2, 3, 2)))),
        (15, merge(gw, R(neck=[("Z", 4.0)], head=[("Z", -10.0), ("Y", -3.0)]), ears(8, 6), tail(yaw=(0, -2, -2, 0)))),
        (30, merge(gw, R(neck=[("Z", 12.0)], head=[("Z", 6.0), ("Y", 3.0)]), ears(-6, 4), tail(yaw=(0, 1, -2, -3))))])

    # ---- den (low through the 60 x 60 portal)
    den_low = merge(den, R(neck=[("Y", 6.0)], head=[("Y", 4.0)]))
    C["DenEmerge"] = dict(keys=[
        (0, merge(den_low, L(body=(0, 0, -0.4)))),
        (10, merge(den, R(head=[("Y", -4.0), ("Z", 6.0)]),
                   FEET(fore_l=foot("fore_l", (2.0, 0, 2.6)), hind_r=foot("hind_r", (1.0, 0, 2.2))))),
        (18, merge(den, R(head=[("Z", -6.0)]),
                   FEET(fore_r=foot("fore_r", (2.0, 0, 2.6)), hind_l=foot("hind_l", (1.0, 0, 2.2))))),
        (30, merge(crouch, ears(0, 0)))], locomotion=True, den=True)
    C["DenEnter"] = dict(keys=[
        (0, NEU),
        (8, merge(crouch, R(neck=[("Y", 6.0)]))),
        (16, merge(den_low, FEET(fore_l=foot("fore_l", (2.0, 0, 2.6)), hind_r=foot("hind_r", (1.0, 0, 2.2))))),
        (24, merge(den_low, FEET(fore_r=foot("fore_r", (2.0, 0, 2.6)), hind_l=foot("hind_l", (1.0, 0, 2.2))),
                   tail(lift=(-4, -2, 0, 0)))),
        (30, merge(den_low, tail(lift=(-6, -4, 0, 0))))], locomotion=True, den=True)

    # ---- claim
    insp = merge(NEU, L(body=(1.2, 0, 0.4), chest=(1.6, 0, 0)), R(neck=[("Y", -8.0)], head=[("Y", -4.0)]), ears(10, 6))
    C["InspectSlot"] = dict(keys=[(0, NEU), (5, insp), (8, merge(insp, R(head=[("Y", 3.0), ("Z", 3.0)]))),
                                  (12, merge(insp, R(head=[("Z", -2.0)])))])
    rf = rummage["feet"]

    def tug(spec, side, dx, dz):
        f = spec["feet"]["fore_" + side]
        return {"feet": {"fore_" + side: (f[0], Vector(f[1]) + Vector((dx, 0, dz)), Vector(f[2]) + Vector((dx, 0, dz)),
                                          f[3])}}
    C["Rummage"] = dict(keys=[
        (0, rummage),
        (12, merge(rummage, tug(rummage, "l", -5.0, -3.0), L(body=(-1.2, 0, 0)), R(head=[("Y", 6.0), ("Z", 5.0)]),
                   ears(-8, 4))),
        (24, merge(rummage, R(head=[("Y", -2.0)]))),
        (36, merge(rummage, tug(rummage, "r", -5.0, -3.0), L(body=(-1.2, 0, 0)), R(head=[("Y", 6.0), ("Z", -5.0)]),
                   ears(-8, 4)))])
    C["Snatch"] = dict(keys=[
        (0, merge(rummage, R(jaw=[("Y", JAW_OPEN)]))),
        (2, merge(rummage, L(body=(-0.8, 0, 0)), R(neck=[("Y", -3.0)], head=[("Y", -4.0)]), ears(-14, 6))),
        (5, merge(B.rear_pose(18.0, 4.0, tuck=False), LOADED_HEAD, L(body=(-2.0, 0, 0)),
                  FEET(fore_l=foot("fore_l", (-1.0, 0, 3.0)), fore_r=foot("fore_r", (-0.6, 0, 2.6)),
                       hind_l=foot("hind_l", (-2.2, 0, 2.4))))),
        (8, merge(jaw_carry, FEET(hind_l=foot("hind_l", (-2.4, 0, 0)))))], carry_from=2)

    # ---- loaded
    C["LoadedIdle"] = dict(keys=[
        (0, jaw_carry), (12, merge(jaw_carry, L(body=(0, 0, 0.3)), R(chest=[("Y", -1.0)], neck=[("Z", 5.0)]),
                                   tail(yaw=(0, -3, -3, -2)))),
        (24, merge(jaw_carry, R(neck=[("Z", -5.0)]), tail(yaw=(0, 3, 3, 2))))], carry_from=0)
    C["LoadedBound"] = dict(keys=bound_keys(q_frames(0.45), loaded=True, lift=6.0), locomotion=True, carry_from=0)
    C["LoadedTurnLeft"] = dict(keys=turn_keys(q_frames(0.35), "L", loaded=True), locomotion=True, carry_from=0)
    C["LoadedTurnRight"] = dict(keys=turn_keys(q_frames(0.35), "R", loaded=True), locomotion=True, carry_from=0)
    C["LoadedLookBack"] = dict(keys=[(0, jaw_carry), (6, look_back), (10, merge(look_back, R(neck=[("Z", 2.0)]))),
                                     (15, jaw_carry)], carry_from=0)
    lc = merge(jaw_carry, L(body=(-0.8, 0, -2.4)), R(chest=[("Y", 3.0)]), ears(-36, 8), tail(lift=(6, 4, 2, 0)))
    C["LoadedCornered"] = dict(keys=[
        (0, merge(lc, R(neck=[("Z", 12.0)]))), (8, merge(lc, R(neck=[("Z", -4.0)], head=[("Y", -3.0)]))),
        (16, merge(lc, R(neck=[("Z", -12.0)]))), (20, merge(lc, R(neck=[("Z", 2.0)])))], carry_from=0)

    # ---- dying
    hit = merge(NEU, L(body=(-1.0, 0, -3.0)), R(chest=[("Y", 6.0)], neck=[("Y", 4.0)], head=[("Y", 8.0), ("X", 6.0)]),
                ears(-40, 12), tail(lift=(10, 8, 4, 0)))
    C["HitReact"] = dict(keys=[(0, NEU), (2, hit), (4, merge(hit, L(body=(0.4, 0, 1.2)), ears(10, 0)))])
    C["MouthRelease"] = dict(keys=[(0, jaw_carry),
                                   (3, merge(jaw_carry, R(jaw=[("Y", JAW_OPEN + 4)], head=[("Y", 6.0)]))),
                                   (6, merge(jaw_carry, R(jaw=[("Y", JAW_OPEN)], head=[("Y", 3.0)])))],
                             carry_from=0, carry_until=2)

    def topple_keys(final, sgn):
        tuck = {}
        for kind, fx in (("fore", 1.0), ("hind", -1.0)):
            for sd, sfx in ((1, "l"), (-1, "r")):
                tuck[kind + "_" + sfx] = foot(kind + "_" + sfx, (fx, sd * 1.5, 3.5), frame="body")
        hop = merge(NEU, L(body=(0, 0, 5.0)), R(body=[("X", -14.0 * sgn), ("Y", -5.0)], head=[("Y", -8.0)]),
                    ears(-30, 14), tail(lift=(10, 6, 6, 4)), {"feet": tuck})
        mid = merge(strip_spoon(final), L(body=(0, 0, 6.0)), R(body=[("X", 42.0 * sgn)]), ears(-36, 16),
                    tail(lift=(14, 10, 6, 0)))
        # ears swing forward on the impact (the upper ear reached the bowl on the rebound)
        over = merge(strip_spoon(final), L(body=(0, 0, 0.8)), ears(14, 0))
        bounce = merge(strip_spoon(final), R(body=[("X", 5.0 * sgn)]), L(body=(0, 0, 1.8)), ears(8, 0))
        fin = dict(copy.deepcopy(final), _keep_spoon=True)
        for k_ in (mid, over, bounce):
            k_.pop("_keep_spoon", None)
        return [(0, NEU), (4, hop), (10, mid), (15, over), (19, bounce), (24, fin)]
    C["DeathToppleLeft"] = dict(keys=topple_keys(top_l, 1.0), ik=False)
    C["DeathToppleRight"] = dict(keys=topple_keys(top_r, -1.0), ik=False)
    C["DeadHold"] = dict(keys=[(0, dict(dead, _keep_spoon=True))], ik=False)

    # ---- additive banks (full poses relative to IdleBreath frame 0; start and end on it)
    ib0 = C["IdleBreath"]["keys"][0][1]
    C["EarFlick"] = dict(keys=[(0, ib0), (3, merge(ib0, R(ear_l=[("Y", -34.0), ("X", 22.0)]))),
                               (5, merge(ib0, R(ear_l=[("Y", 8.0)], ear_r=[("Y", 10.0), ("X", -8.0)]))),
                               (8, merge(ib0, R(ear_l=[("Y", -6.0)], ear_r=[("Y", 4.0)]))), (12, ib0)],
                         additive=True)
    C["TailSettle"] = dict(keys=[(0, ib0), (4, merge(ib0, tail(yaw=(8, 12, 10, 6), lift=(4, 2, 0, 0)))),
                                 (9, merge(ib0, tail(yaw=(-5, -8, -8, -4)))), (14, merge(ib0, tail(yaw=(3, 4, 4, 2)))),
                                 (19, merge(ib0, tail(yaw=(-1, -2, -1, 0)))), (24, ib0)], additive=True)
    return C


# ------------------------------------------------------------------ evaluation
NONROOT = []
FOOTS = ("fore_l", "fore_r", "hind_l", "hind_r")


def legs(key):
    kind, sfx = key.split("_")
    return [ARM.pose.bones["%s_%s_%s" % (kind, p, sfx)] for p in ("upper", "lower", "foot")]


def capture_key():
    ch = {}
    for n in NONROOT:
        pb = ARM.pose.bones[n]
        q = pb.rotation_quaternion
        ch[n] = np.array([*pb.location, q.w, q.x, q.y, q.z])
    ft = {}
    for k in FOOTS:
        up_, lo_, fo_ = legs(k)
        ft[k] = np.concatenate([np.array(lo_.tail), np.array(fo_.tail), np.array(fo_.z_axis)])
    return ch, ft


def grounded_key(ft, k):
    """A key whose paw rests on the floor gets a zero-slope foot target (touch-down / lift-off without sliding)."""
    kind = k.split("_")[0]
    return ft[k][2] <= REST_ANK_Z[kind] + 0.05 and ft[k][5] <= REST_TOE_Z[kind] + 0.6


def hermite(ts, vals, t, loop, n, zero=None):
    """Cubic Hermite through (ts, vals); Catmull-Rom tangents; periodic when loop (vals[last] is not repeated: the
    curve wraps to vals[0] at t = n), clamped (zero slope) at the ends otherwise."""
    ts = list(ts)
    vals = [np.asarray(v, dtype=float) for v in vals]
    if len(ts) == 1:
        return vals[0].copy()
    if loop:
        T = ts + [n]
        V = vals + [vals[0]]
    else:
        T, V = ts, vals
    m = len(T)

    def tangent(i):
        if zero is not None and zero[i % len(zero)]:
            return np.zeros_like(V[i])
        if loop:
            ip = i - 1 if i > 0 else m - 2
            tp = T[ip] - (n if i == 0 else 0)
            inx = i + 1 if i < m - 1 else 1
            tn = T[inx] + (n if i == m - 1 else 0)
            return (V[inx] - V[ip]) / (tn - tp)
        if i == 0 or i == m - 1:
            return np.zeros_like(V[i])
        return (V[i + 1] - V[i - 1]) / (T[i + 1] - T[i - 1])
    if t <= T[0]:
        return V[0].copy()
    if t >= T[-1]:
        return V[-1].copy()
    for i in range(m - 1):
        if T[i] <= t <= T[i + 1]:
            h = T[i + 1] - T[i]
            s = (t - T[i]) / h
            h00 = 2 * s ** 3 - 3 * s ** 2 + 1
            h10 = s ** 3 - 2 * s ** 2 + s
            h01 = -2 * s ** 3 + 3 * s ** 2
            h11 = s ** 3 - s ** 2
            return h00 * V[i] + h10 * h * tangent(i) + h01 * V[i + 1] + h11 * h * tangent(i + 1)
    return V[-1].copy()


def align_quats(chs):
    """Keep each bone's key quaternions in one hemisphere (key to key)."""
    for n in NONROOT:
        for i in range(1, len(chs)):
            if np.dot(chs[i][n][3:], chs[i - 1][n][3:]) < 0:
                chs[i][n][3:] *= -1


def set_channels(vals):
    for n in NONROOT:
        v = vals[n]
        pb = ARM.pose.bones[n]
        pb.location = Vector(v[:3])
        q = Quaternion(v[3:]).normalized()
        pb.rotation_quaternion = q
        pb.scale = (1, 1, 1)
    r = ARM.pose.bones["root"]
    r.location, r.rotation_quaternion, r.scale = (0, 0, 0), Quaternion(), (1, 1, 1)
    bpy.context.view_layer.update()


def solve_feet(ft):
    for k in FOOTS:
        up_, lo_, fo_ = legs(k)
        ank, toe, upv = Vector(ft[k][0:3]), Vector(ft[k][3:6]), Vector(ft[k][6:9])
        hip = up_.head.copy()
        knee_fk = up_.tail.copy()
        l1, l2 = up_.bone.length, lo_.bone.length
        knee, a2 = rc.ik2(hip, ank, l1, l2, knee_fk - hip)
        rc.aim(up_, knee)
        bpy.context.view_layer.update()
        rc.aim(lo_, a2)
        bpy.context.view_layer.update()
        rc.aim(fo_, toe, upv)
        bpy.context.view_layer.update()


def eval_frame(clip, f):
    vals = {n: hermite(clip["kt"], [c[n] for c in clip["kch"]], f, clip["loop"], clip["n"]) for n in NONROOT}
    set_channels(vals)
    if clip.get("ik", True):
        ft = {k: hermite(clip["kt"], [x[k] for x in clip["kft"]], f, clip["loop"], clip["n"], clip["kgr"][k])
              for k in FOOTS}
        for k in FOOTS:   # floor contact: a splined paw never dips under its rest (grounded) ankle / toe height
            kind = k.split("_")[0]
            ft[k][2] = max(ft[k][2], REST_ANK_Z[kind])
            ft[k][5] = max(ft[k][5], REST_TOE_Z[kind])
        solve_feet(ft)
    B.tail_floor_guard(ARM)
    bpy.context.view_layer.update()


# ------------------------------------------------------------------ key audit + spoon fix (Phase 1 search)
CARRY = None


def key_bad(a, carry):
    bad = B.pose_ok(a, carry)
    if carry and a.get("carry_proxy_vs_legs_tris", 0):
        bad.append("carry-proxy-legs")
    return bad


SPOON_KEYS = ("rot", "loc", "orbit", "orbit_frame")


def has_own_spoon(spec):
    return any("spoon_prop" in spec.get(k, {}) for k in SPOON_KEYS)


def with_spoon(spec, fx):
    """The strapped spoon's slide (about the chest axis) / lift (along its up) / pitch, as Phase 1 fix_spoon."""
    if fx is None or spec.get("_keep_spoon"):
        return spec
    p2 = strip_spoon(spec)
    lift, ang, pit = fx
    p2.setdefault("orbit", {})["spoon_prop"] = ("X", ang, (0.0, 0.0, 22.0))
    p2.setdefault("orbit_frame", {})["spoon_prop"] = "chest"
    axis = tuple(ARM.data.bones["spoon_prop"].matrix_local.to_3x3().col[1].cross(Z).normalized())
    p2.setdefault("rot", {})["spoon_prop"] = [(axis, pit)] if pit else []
    sp_up = ARM.data.bones["spoon_prop"].matrix_local.to_3x3().col[2]
    p2.setdefault("loc", {})["spoon_prop"] = tuple(sp_up * lift)
    return p2


SPOON_BAD = ("spoon-torso", "head-spoon")


def build_keys(clip, fx, proxies):
    keys = clip["keys"]
    if clip["loop"] and len(keys) > 1 and keys[-1][0] == clip["n"]:
        keys = keys[:-1]     # periodic: frame N is frame 0
    kt, kch, kft = [], [], []
    for f, spec in keys:
        apply(with_spoon(merge(spec), fx) if not spec.get("_keep_spoon") else spec)
        ch, ft = capture_key()
        kt.append(f)
        kch.append(ch)
        kft.append(ft)
    align_quats(kch)
    kgr = {k: [grounded_key(ft, k) for ft in kft] for k in FOOTS}
    clip.update(kt=kt, kch=kch, kft=kft, kgr=kgr)


def spoon_trouble(clip, proxies):
    """Spoon/head collisions at every key and at every frame between keys (all frames of short clips)."""
    n = clip["n"]
    test = sorted(set(range(0, n + 1))) if n <= 30 else sorted(set(clip["kt"]) | {
        (a + b) // 2 for a, b in zip(clip["kt"], clip["kt"][1:] + [n])} | {n})
    bad = []
    for f in test:
        eval_frame(clip, f)
        carry = clip.get("carry_from", 10 ** 6) <= f <= clip.get("carry_until", n)
        a = B.audit_pose(BODY, proxies if carry else ())
        b = [x for x in key_bad(a, carry) if x in SPOON_BAD]
        if b:
            bad.append((f, b, a["spoon_vs_torso_tris"] + a["head_vs_spoon_tris"]))
    return bad


def fit_spoon(clip, proxies):
    """One strap setting for the whole clip (a strapped spoon does not jitter key to key): no change if the clip is
    clean, else the cheapest slide / lift / pitch (Phase 1 search order) that clears the spoon at every tested frame."""
    build_keys(clip, None, proxies)
    bad0 = spoon_trouble(clip, proxies)
    if not bad0:
        return None, bad0, []
    cands = []
    for lift in (0.0, 0.3, 0.6, 1.0, 1.5, 2.0, 2.5, 3.0):
        for ang in (0.0, -3.0, 3.0, -6.0, 6.0, -10.0, 10.0):
            for pit in (0.0, -3.0, 3.0, -6.0, 6.0):
                if lift or ang or pit:
                    cands.append((abs(lift) * 2 + abs(ang) * 0.3 + abs(pit) * 0.3, (lift, ang, pit)))
    cands.sort()
    best = None
    for cost, fx in cands:
        build_keys(clip, fx, proxies)
        bad = spoon_trouble(clip, proxies)
        if not bad:
            return fx, bad0, []
        sc = sum(b[2] for b in bad)
        if best is None or sc < best[0]:
            best = (sc, fx, bad)
    build_keys(clip, best[1], proxies)
    return best[1], bad0, best[2]


def apply(spec):
    B.apply_pose(ARM, spec)


# ------------------------------------------------------------------ audits per baked frame
DEN_HW, DEN_SPRING = 30.0, 30.0
REST_ANK_Z = {"fore": 2.3, "hind": 2.6}
REST_TOE_Z = {"fore": 0.9, "hind": 0.9}


def portal_clear(co):
    y, z = co[:, 1], co[:, 2]
    c = np.where(z <= DEN_SPRING, DEN_HW - np.abs(y), DEN_HW - np.hypot(y, z - DEN_SPRING))
    i = int(np.argmin(c))
    return float(c[i]), (round(float(y[i]), 2), round(float(z[i]), 2))


def landmarks():
    out = {}
    for n in ("body", "chest", "head", "jaw", "fore_foot_l", "hind_foot_r", "tail_04", "spoon_prop"):
        out[n] = [round(x, 4) for x in (ARM.matrix_world @ ARM.pose.bones[n].head)]
    return out


def bake_and_audit(name, clip, proxies):
    n = clip["n"]
    act = bpy.data.actions.get(name)
    if act is not None:
        bpy.data.actions.remove(act)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ARM.animation_data_create()
    ARM.animation_data.action = act
    frames = []
    per = []
    feet_hist = {k: [] for k in FOOTS}
    carry_frames = range(clip.get("carry_from", 10 ** 6), clip.get("carry_until", n) + 1)
    for f in range(n + 1):
        eval_frame(clip, f)
        for pb in ARM.pose.bones:
            if pb.name == "root":
                continue
            pb.keyframe_insert("location", frame=f, group=pb.name)
            pb.keyframe_insert("rotation_quaternion", frame=f, group=pb.name)
        cap = {pb.name: (np.array(pb.location), np.array(pb.rotation_quaternion)) for pb in ARM.pose.bones}
        frames.append(cap)
        carry = f in carry_frames
        a = B.audit_pose(BODY, proxies if carry else ())
        bad = key_bad(a, carry)
        co, _, _ = rc.evaluated_tris(BODY)
        rec = {"f": f, "bad": bad, "spoon_torso_tris": a["spoon_vs_torso_tris"],
               "spoon_clear": a["spoon_vs_torso_clear_cm"], "harness_clear": a["harness_vs_torso_clear_cm"],
               "head_spoon_tris": a["head_vs_spoon_tris"], "below_floor": a["below_floor_verts"],
               "min_z": a["min_z_cm"], "patch_detach": a["eye_patch_detach_cm"], "height": a["height_cm"],
               "legs_torso_tris": a["legs_vs_torso_tris"], "lift_body_min_z": a["body_min_z_cm"],
               "below_parts": a["below_floor_parts"]}
        if carry:
            rec.update({"carry_chest_tris": a["carry_proxy_vs_chest_tris"], "carry_spoon_tris": a["carry_proxy_vs_spoon_tris"],
                        "carry_legs_tris": a.get("carry_proxy_vs_legs_tris"),
                        "carry_chest_clear": a["carry_proxy_vs_chest_clear_cm"],
                        "carry_spoon_clear": a["carry_proxy_vs_spoon_clear_cm"], "carry_min_z": a.get("carry_proxy_min_z_cm")})
        if clip.get("den"):
            pc, pt = portal_clear(co)
            rec["portal_clear"], rec["portal_pt"] = round(pc, 3), pt
            rec["y_extent"] = round(float(co[:, 1].max() - co[:, 1].min()), 3)
            rec["z_max"] = round(float(co[:, 2].max()), 3)
        rec["lm"] = landmarks()
        per.append(rec)
        for k in FOOTS:
            up_, lo_, fo_ = legs(k)
            feet_hist[k].append((np.array(lo_.tail), np.array(fo_.tail)))
    for fc in rc_fcurves(act):
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    ARM.animation_data.action = None
    # loop seam: pose (frame N vs 0) and smoothness: the second difference across the seam (f[N-1], f[N]=f[0], f[1])
    # must be no larger than the largest second difference inside the clip (a kink would stand out), bone-local
    seam = None
    if clip["loop"] and n >= 3:
        def vec(fr):
            out = []
            for b in sorted(fr):
                l_, q_ = fr[b]
                out.append(l_)
                out.append(q_)
            return out

        def unify(cur, ref):
            return [c if (i % 2 == 0 or np.dot(c, r) >= 0) else -c for i, (c, r) in enumerate(zip(cur, ref))]
        F = [vec(fr) for fr in frames]
        for i in range(1, len(F)):
            F[i] = unify(F[i], F[i - 1])
        F[n] = unify(F[n], F[0])
        dp = max(float(np.abs(a - b).max()) for a, b in zip(F[0], F[n]))
        sd = lambda a, b, c: max(float(np.abs(x - 2 * y + z).max()) for x, y, z in zip(a, b, c))
        seam_sd = sd(F[n - 1], unify(F[0], F[n - 1]), unify(F[1], F[n - 1]))
        inner = max(sd(F[i - 1], F[i], F[i + 1]) for i in range(1, n))
        seam = {"pose_max": round(dp, 7), "seam_second_diff": round(seam_sd, 6), "interior_max_second_diff": round(inner, 6)}
    # contacts: grounded = ankle within 0.4 cm of its rest height; drift = horizontal travel of the ankle over each
    # contiguous grounded run (locomotion: the stance slide that the mover cancels, reported as cm/s)
    contacts = {}
    for k in FOOTS:
        kind = k.split("_")[0]
        runs, cur = [], []
        for f, (ank, toe) in enumerate(feet_hist[k]):
            if ank[2] <= REST_ANK_Z[kind] + 0.15 and toe[2] <= 1.2:
                cur.append((f, ank))
            else:
                if len(cur) > 1:
                    runs.append(cur)
                cur = []
        if len(cur) > 1:
            runs.append(cur)
        worst, speeds = 0.0, []
        for r in runs:
            p0 = r[0][1]
            d = max(float(np.hypot(*(p[1][:2] - p0[:2]))) for p in r)
            worst = max(worst, d)
            span = r[-1][0] - r[0][0]
            if span > 0:
                speeds.append(round(float(np.hypot(*(r[-1][1][:2] - r[0][1][:2]))) / span * FPS, 1))
        contacts[k] = {"grounded_runs": [[r[0][0], r[-1][0]] for r in runs], "max_drift_cm": round(worst, 3),
                       "run_speeds_cm_s": speeds}
    return act, per, seam, contacts


def rc_fcurves(action):
    out = []
    try:
        for layer in action.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    out.extend(cb.fcurves)
    except AttributeError:
        pass
    if not out and hasattr(action, "fcurves"):
        out = list(action.fcurves)
    return out


# ------------------------------------------------------------------ renders (contact sheets)
SHEET_VIEWS = {
    "side": ((0, 1, 0), Z), "front": ((-1, 0, 0), Z), "tq": ((-0.70, 0.62, -0.36), Z),
}
EXTRA_VIEWS = {}
for c_ in ("TurnLeft90", "TurnRight90", "Turn180", "Startle", "Backstep", "RearUp", "RearObserve", "RearDown"):
    EXTRA_VIEWS[c_] = "front"
for c_ in ("Snatch", "LoadedIdle", "LoadedBound", "LoadedTurnLeft", "LoadedTurnRight", "LoadedLookBack",
           "LoadedCornered", "DeathToppleLeft", "DeathToppleRight", "DeadHold"):
    EXTRA_VIEWS[c_] = "tq"


def render_sheets(clips, tag=None):
    import rat_render as rr
    scene = bpy.context.scene
    rr.setup(scene)
    rr.RES = (640, 480)
    scene.render.resolution_x, scene.render.resolution_y = rr.RES
    rr.make_lights(bpy.data.collections["Review"])
    rr.engine(scene, "wb")
    cam = bpy.data.objects["ReviewCam"]
    out = {}
    tmp = os.path.join(REVIEW, "clips", "_frames")
    os.makedirs(tmp, exist_ok=True)
    for name, clip in clips.items():
        act = bpy.data.actions[name]
        ARM.animation_data_create()
        ARM.animation_data.action = act
        if ARM.animation_data.action_slot is None and len(act.slots):
            ARM.animation_data.action_slot = act.slots[0]
        n = clip["n"]
        step = 2 if n <= 16 else (3 if n <= 36 else 4)
        fl = list(range(0, n + 1, step))
        if fl[-1] != n:
            fl.append(n)
        carry_rng = range(clip.get("carry_from", 10 ** 6), clip.get("carry_until", n) + 1)
        views = ["side"] + ([EXTRA_VIEWS[name]] if name in EXTRA_VIEWS else [])
        out[name] = {"frames": fl, "views": {}}
        for v in views:
            d, up = SHEET_VIEWS[v]
            pts = []
            for f in fl:
                scene.frame_set(f)
                rr.visible({"Mushroom_Carry"} if f in carry_rng else set())
                pts.append(rr.world_pts([BODY] + ([bpy.data.objects["Mushroom_Carry"]] if f in carry_rng else [])))
            allp = np.concatenate(pts + [np.array([[0, 0, 0.0]])])
            tiles = []
            for f in fl:
                scene.frame_set(f)
                rr.visible({"Mushroom_Carry"} if f in carry_rng else set())
                if v == "tq":
                    rr.frame_persp(cam, d, up, allp, 50.0, 1.02)
                else:
                    rr.frame_ortho(cam, d, up, allp, 1.06)
                p = rr.render(scene, cam, os.path.join(tmp, "%s_%s_%03d.png" % (name, v, f)))
                tiles.append(rr.load_px(p))
            cols = min(len(tiles), 5)
            sheet = os.path.join(REVIEW, "clips", "%s_sheet.png" % name if v == "side" else "%s_%s_sheet.png" % (name, v))
            rr.save_sheet(tiles, cols, sheet, 420, 315, gap=4)
            if tag:
                it = os.path.join(REVIEW, "clips", "iterations")
                os.makedirs(it, exist_ok=True)
                import shutil
                shutil.copy(sheet, os.path.join(it, os.path.basename(sheet).replace(".png", "_%s.png" % tag)))
            out[name]["views"][v] = os.path.relpath(sheet, ROOT).replace("\\", "/")
        ARM.animation_data.action = None
    rr.visible(set())
    return out


# ------------------------------------------------------------------ main
def main():
    global ARM, BODY, NONROOT, POSEDEFS
    t0 = time.time()
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = argv[argv.index("--clips") + 1].split(",") if "--clips" in argv else None
    do_save = "--no-save" not in argv
    do_render = "--render" in argv or "--render-only" in argv
    render_only = "--render-only" in argv
    tag = argv[argv.index("--sheet-tag") + 1] if "--sheet-tag" in argv else None
    os.makedirs(REVIEW, exist_ok=True)
    os.makedirs(ANIM_OUT, exist_ok=True)
    sc = bpy.context.scene
    sc.render.fps, sc.render.fps_base = FPS, 1.0
    ARM = bpy.data.objects[B.ARM_NAME]
    BODY = bpy.data.objects[B.MESH_NAME]
    ARM.matrix_world = Matrix.Identity(4)
    NONROOT = [pb.name for pb in ARM.pose.bones if pb.name != "root"]
    for pb in ARM.pose.bones:
        pb.rotation_mode = "QUATERNION"
    POSEDEFS = json.loads(bpy.data.texts["PantryRat_R01_PoseDefs.json"].as_string())
    rows, man = read_manifest()
    lib = build_clips()
    fails = []
    missing = sorted(set(man) - set(lib))
    extra = sorted(set(lib) - set(man))
    if missing or extra:
        fails.append("clip set missing %s extra %s" % (missing, extra))
    names = [r["name"] for r in rows if r["name"] in lib]
    if only:
        names = [n for n in names if n in only]
    proxies = (bpy.data.objects["Mushroom_Carry"],)
    rep_path = os.path.join(REVIEW, "anim_report.json")
    report = json.load(open(rep_path)) if os.path.exists(rep_path) else {"clips": {}}
    clips_json_path = os.path.join(ANIM_OUT, "clips.json")
    clips_json = json.load(open(clips_json_path)) if os.path.exists(clips_json_path) else {}
    clips = {}
    for name in names:
        spec = lib[name]
        m = man[name]
        n = q_frames(m["seconds_proposed"])
        clip = dict(spec, n=n, loop=m["loop"])
        if clip["keys"][-1][0] > n:
            fails.append("%s key beyond frame %d" % (name, n))
        clips[name] = clip
    if not render_only:
        for name, clip in clips.items():
            t1 = time.time()
            fx, bad0, left = fit_spoon(clip, proxies)
            kfix = {"strap_fit": None if fx is None else {"spoon_lift_cm": fx[0], "spoon_slide_deg": fx[1],
                                                          "spoon_pitch_deg": fx[2]},
                    "before": [[f, b] for f, b, _ in bad0], "unresolved": [[f, b] for f, b, _ in left]}
            if fx is not None or bad0:
                log("STRAPFIT %s %s" % (name, json.dumps(kfix)))
            kt = clip["kt"]
            act, per, seam, contacts = bake_and_audit(name, clip, proxies)
            bad_frames = [(r["f"], r["bad"]) for r in per if r["bad"]]
            worst = {k: (min if k in ("spoon_clear", "harness_clear", "carry_chest_clear", "carry_spoon_clear",
                                      "portal_clear", "min_z") else max)(r[k] for r in per if k in r and r[k] != "n/a")
                     for k in ("spoon_torso_tris", "spoon_clear", "harness_clear", "head_spoon_tris", "below_floor",
                               "patch_detach", "legs_torso_tris", "carry_chest_tris", "carry_spoon_tris",
                               "carry_legs_tris", "carry_chest_clear", "carry_spoon_clear", "portal_clear", "min_z",
                               "height", "y_extent", "z_max") if any(k in r and r[k] != "n/a" for r in per)}
            loop_ok = seam is None or (seam["pose_max"] < 1e-5 and
                                       seam["seam_second_diff"] <= 1.05 * seam["interior_max_second_diff"] + 1e-4)
            static_drift = 0.0 if clip.get("locomotion") or not clip.get("ik", True) else \
                max(c["max_drift_cm"] for c in contacts.values())
            entry = {"frames": clip["n"], "samples": clip["n"] + 1, "seconds": round(clip["n"] / FPS, 4),
                     "seconds_proposed": man[name]["seconds_proposed"], "loop": clip["loop"],
                     "additive": bool(clip.get("additive")), "keys": kt, "key_spoon_fixes": kfix,
                     "ik_feet": clip.get("ik", True), "locomotion": bool(clip.get("locomotion")),
                     "carry_frames": [clip["carry_from"], clip.get("carry_until", clip["n"])] if "carry_from" in clip else None,
                     "seam": seam, "loop_seam_ok": loop_ok, "worst": worst, "bad_frames": bad_frames,
                     "contacts": contacts, "static_contact_drift_cm": round(static_drift, 3),
                     "landmarks": {str(r["f"]): r["lm"] for r in per}, "per_frame": [{k: v for k, v in r.items() if k != "lm"}
                                                                                     for r in per],
                     "seconds_to_author": round(time.time() - t1, 1)}
            if clip.get("additive"):
                ib = report["clips"].get("IdleBreath") if name != "IdleBreath" else None
                entry["additive_reference"] = {"clip": "IdleBreath", "frame": 0}
            report["clips"][name] = entry
            clips_json[name] = {"fps": FPS, "frames": [0, clip["n"]], "samples": clip["n"] + 1, "loop": clip["loop"],
                                "additive": bool(clip.get("additive")), "export_action": name,
                                "seconds": round(clip["n"] / FPS, 6)}
            if bad_frames:
                fails.append("%s bad frames %s" % (name, bad_frames[:4]))
            if not loop_ok:
                fails.append("%s seam %s" % (name, seam))
            if static_drift > 0.3:
                fails.append("%s planted drift %.2f" % (name, static_drift))
            log("CLIP %-17s n=%3d loop=%s seam=%s bad=%d worst=%s drift=%.3f t=%.1fs" % (
                name, clip["n"], clip["loop"], seam, len(bad_frames),
                json.dumps({k: worst[k] for k in ("spoon_torso_tris", "harness_clear", "below_floor", "head_spoon_tris")
                            if k in worst}), static_drift, time.time() - t1))
        # additive banks start and end on IdleBreath frame 0
        if "IdleBreath" in report["clips"]:
            ref = report["clips"]["IdleBreath"]["landmarks"]["0"]
            for nm in ("EarFlick", "TailSettle"):
                if nm in report["clips"]:
                    e = report["clips"][nm]
                    d0 = max(max(abs(a - b) for a, b in zip(ref[k], e["landmarks"]["0"][k])) for k in ref)
                    dN = max(max(abs(a - b) for a, b in zip(ref[k], e["landmarks"][str(e["frames"])][k])) for k in ref)
                    e["vs_idlebreath_f0_cm"] = {"first": round(d0, 6), "last": round(dN, 6)}
                    if max(d0, dN) > 1e-3:
                        fails.append("%s not on IdleBreath f0 (%.4f/%.4f)" % (nm, d0, dN))
    if do_render:
        sheets = render_sheets(clips, tag)
        for k, v in sheets.items():
            report["clips"].setdefault(k, {})["sheets"] = v
    report["fps"] = FPS
    report["frame_convention"] = "frames 0..N, N+1 samples, N = round_half_up(seconds * 30); loops: frame N == frame 0"
    report["elapsed_s"] = round(time.time() - t0, 1)
    report["log"] = LOG[-400:]
    with open(rep_path, "w") as fh:
        json.dump(report, fh, indent=1, default=lambda o: o.tolist() if hasattr(o, "tolist") else str(o))
    with open(clips_json_path, "w") as fh:
        json.dump(clips_json, fh, indent=1)
    if not render_only and do_save:
        ARM.animation_data.action = None
        B.apply_pose(ARM, {})
        bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=False)
        log("SAVED", BLEND)
    if fails:
        print("PANTRY_RAT_FAIL " + " | ".join(fails))
        sys.exit(1)
    print("PANTRY_RAT_OK")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        print("PANTRY_RAT_FAIL exception")
        sys.exit(1)
