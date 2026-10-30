"""Explainer diagrams for the two material-breakdown clips (drips; water), Pillow + numpy, deterministic, 30 fps.

    python -I render_diagrams.py --shot all --out D:/Repo/Content/Devlog/materials/diagrams
    python -I render_diagrams.py --shot drip_clock --out <root> --t0 10.0 --seconds 8
    python -I render_diagrams.py --shot drip_clock --out <root> --sync <footage shot.json> [--offset 3.0]
    python -I render_diagrams.py --shot fall_curve --out <root> --full          # force the full-frame variant
    python -I render_diagrams.py --shot slots_wrap --out <root> --inset         # force the inset variant

Shots (natural variant in brackets; --inset / --full force the other one into <shot>_inset / <shot>_full):
    drip_clock    [inset]  one strand's clock: bead, falls (real drag curve, live), splash, rings; 4 card lanes; playhead
    fall_curve    [inset]  drag fall vs free fall, dots sliding; DistanceAt (time -> where) then AgeAt (height -> when)
    slots_wrap    [full]   4 cards take turns (busy = fall + splash, never overlapping); the 3600 s wrap seam
    strand_trace  [inset]  trace up, trace down, length into custom data, then drops as a function of time
    wet_layers    [full]   puddle layers sliding in: stone, mask, darker, glossy, ripples, rings ('all' also renders
                           wet_layers_inset)
    ring_timing   [inset]  impact time -> ring radius (22 cm/s, 1.4 s life), 3 impacts, plus a top view of the rings

Inset frames are 800x450 RGBA (transparent outside a dark rounded panel); full frames are 1920x1080 RGB on #0b0b0f.
Every layout is authored in a 1600x900 logical space (text >= 40, strokes >= 6 logical: 20 px / 3 px in an inset,
48 px / 7 px full frame) and supersampled 2x.

Time: --t0 is the game time (s) at frame 0, so a diagram can be re-rendered in sync with frozen-time footage whose
shot.json records `frozen_t0` (--sync reads it; --offset adds the manifest's `in` point). --strand L,RATE,SEED,JITTER[,MODE]
sets the strand (defaults per shot below); give the footage strand's values when they are known. With --sync and no
--strand, the footage shot.json's `strand` (length_cm, rate, seed, jitter, mode) is used. MODE 1 (DropsWithThread) moves
the drop start y0 down the thread (14..44 cm, MarsDrip.ush), which changes the fall time; leaving it out assumes mode 0.
The full frames (wet_layers, slots_wrap) keep everything above y 660 of 900, so a 2-line bottom caption clears them. The clock itself is
Tools/Blender/mars_water/drip_reference.py (the plain-Python mirror of Shaders/Water/MarsDrip.ush), imported, not copied;
bead growth, LastDrop, the impact rings and the puddle shape are ported here line for line from the .ush files.

Each shot folder gets %05d.png, shot.json and _preview.mp4 (ffmpeg from imageio_ffmpeg, -threads 2). Single process.
"""
import argparse
import json
import math
import os
import re
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
MARS_WATER = os.path.join(REPO, "Tools", "Blender", "mars_water")
if MARS_WATER not in sys.path:
    sys.path.insert(0, MARS_WATER)
import drip_reference as ref  # noqa: E402
import water_spec as spec  # noqa: E402

K = spec.CONSTANTS
FPS = 30
LW, LH = 1600.0, 900.0                         # logical layout space
SS = 2                                         # supersampling
PANEL_ALPHA = 240                              # inset card opacity
BG = (11, 11, 15)
TEXT = (243, 239, 230)
ACCENT = (224, 168, 74)
SECOND = (74, 163, 224)
STONE = (78, 74, 70)
FONT_UI = r"C:\Windows\Fonts\bahnschrift.ttf"
FONT_CODE = r"C:\Windows\Fonts\consola.ttf"
FONT_CODE_B = r"C:\Windows\Fonts\consolab.ttf"

RING_SPEED = K["MARS_DRIP_RING_SPEED"]
RING_LIFE = K["MARS_DRIP_RING_LIFE"]
RING_LAMBDA = K["MARS_DRIP_RING_LAMBDA"]
SPLASH_S = K["MARS_DRIP_SPLASH_S"]
CROWN_S = K["MARS_DRIP_CROWN_S"]
TERMINAL = K["MARS_DRIP_TERMINAL"]
GRAVITY = K["MARS_DRIP_GRAVITY"]
WRAP = K["MARS_DRIP_WRAP"]
SLOTS = K["MARS_DRIP_SLOTS"]
# DripImpact_Mars_M / DripRingCard_Mars_M defaults (Tools/Blender/mars_water/unreal/mars_water_ue.py build_impact)
RING_WIDTH, RING_DECAY, RING_DIMPLE = 1.2, 0.8, 0.4


# ====================================================================== maths helpers
def clamp(x, a=0.0, b=1.0):
    return a if x < a else b if x > b else x


def smooth(x):
    x = clamp(x)
    return x * x * (3.0 - 2.0 * x)


def ramp(t, a, b):
    """0 before a, 1 after b, smoothstep between."""
    return smooth((t - a) / max(b - a, 1e-6))


def ease_out(x):
    x = clamp(x)
    return 1.0 - (1.0 - x) ** 3


def lerp(a, b, w):
    return a + (b - a) * w


def mix(c0, c1, w):
    return tuple(int(round(lerp(a, b, w))) for a, b in zip(c0, c1))


def rgba(c, a=1.0):
    return (c[0], c[1], c[2], int(round(255 * clamp(a))))


# ---------------------------------------------------------------- the clock (MarsDrip.ush, via drip_reference)
def make_clock(strand):
    """strand = (L, rate, seed, jitter[, mode]); mode 1 (DropsWithThread) hangs the bead 14..44 cm down a thread."""
    L, rate, seed, jitter = strand[:4]
    mode = strand[4] if len(strand) > 4 else 0.0
    return ref.Clock(L, rate, seed, jitter, mode)


MODE_NAMES = {0: "Drops", 1: "Thread", 2: "Stream", 3: "HangingBead", 4: "SittingBead"}   # EMars_DripMode


def last_drop(c, t):
    """MarsDrip_LastDrop (MarsDrip.ush:118-124)."""
    m = int(math.floor(t / c.p - c.seed))
    if c.release(m + 1) <= t:
        return m + 1
    if c.release(m) <= t:
        return m
    return m - 1


def bead_growth(c, t):
    """MarsDrip_BeadGrowth (MarsDrip.ush:127-140)."""
    if c.rate <= 0.0 or c.mode > 2.5:
        return 0.75 + 0.05 * math.sin(0.7 * t + 40.0 * c.seed)
    k = last_drop(c, t)
    kp, kn, skips = k, k + 1, 0
    for _ in range(3):
        if c.skipped(kp):
            kp -= 1
            skips += 1
    for _ in range(3):
        if c.skipped(kn):
            kn += 1
            skips += 1
    if skips >= 3:
        return 1.0
    tp, tn = c.release(kp), c.release(kn)
    return clamp((t - tp - 0.05) / max(tn - tp - 0.05, 1e-3))


def drops_in(c, t_a, t_b, pad=0.0):
    """Drop indices whose release .. busy end overlaps [t_a, t_b]."""
    k = int(math.floor((t_a - c.busy - pad) / c.p - c.seed)) - 2
    out = []
    while True:
        r = c.release(k)
        if r > t_b + pad:
            break
        if r + c.busy >= t_a - pad:
            out.append(k)
        k += 1
    return out


def drop_depth(c, a):
    """cm below the source of the drop's leading edge, age a (MarsWet.ush:149 plus the radius)."""
    return c.y0 + ref.distance_at(a) + c.radius


# ---------------------------------------------------------------- noise (MarsWet.ush:21-64), numpy uint32
def _h32(x):
    x = x ^ (x >> np.uint32(16))
    x = x * np.uint32(0x7feb352d)
    x = x ^ (x >> np.uint32(15))
    x = x * np.uint32(0x846ca68b)
    x = x ^ (x >> np.uint32(16))
    return x


def _u32(i):
    return (np.asarray(i, dtype=np.int64) & 0xFFFFFFFF).astype(np.uint32)


def hash21(ix, iy):
    qx = _u32(ix) + np.uint32(0x8000)
    qy = _u32(iy) + np.uint32(0x8000)
    return _h32((qx * np.uint32(1597334677)) ^ _h32(qy * np.uint32(3812015801))).astype(np.float64) / 4294967296.0


def value2(px, py):
    ix, iy = np.floor(px), np.floor(py)
    fx, fy = px - ix, py - iy
    ux, uy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    ix, iy = ix.astype(np.int64), iy.astype(np.int64)
    a, b = hash21(ix, iy), hash21(ix + 1, iy)
    c, d = hash21(ix, iy + 1), hash21(ix + 1, iy + 1)
    return (a + (b - a) * ux) * (1 - uy) + (c + (d - c) * ux) * uy


def value2_grad(px, py):
    ix, iy = np.floor(px), np.floor(py)
    fx, fy = px - ix, py - iy
    ux, uy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    dux, duy = 6 * fx * (1 - fx), 6 * fy * (1 - fy)
    ix, iy = ix.astype(np.int64), iy.astype(np.int64)
    a, b = hash21(ix, iy), hash21(ix + 1, iy)
    c, d = hash21(ix, iy + 1), hash21(ix + 1, iy + 1)
    v = a + (b - a) * ux + (c - a) * uy + (a - b - c + d) * ux * uy
    gx = dux * ((b - a) + (a - b - c + d) * uy)
    gy = duy * ((c - a) + (a - b - c + d) * ux)
    return v, gx, gy


def puddle_shape(px, py, wx, wy, seed, aspect01, facets=9, lobes=0.3, island_thr=0.62):
    """MarsWet_PuddleShape (MarsWet.ush:491-514): (deep, rim) masks. Defaults = PuddleWet/Gloss master defaults."""
    qx, qy = px, py * (1.0 + 0.8 * aspect01)
    s = np.sqrt(qx * qx + qy * qy)
    if facets > 2:
        facet = np.zeros_like(s)
        for i in range(min(int(facets), 12)):
            fr = (seed * 17.3 + i * 0.618) % 1.0
            ang = 6.2831853 * (i + 0.6 * fr) / facets
            k = 1.0 + 0.12 * ((seed * 31.1 + i * 0.37) % 1.0)
            facet = np.maximum(facet, (qx * math.cos(ang) + qy * math.sin(ang)) * k)
        s = s + (facet - s) * 0.65
    s = s + lobes * (value2(px * 1.7 + seed * 13.1, py * 1.7 + seed * 13.1) - 0.5) * 2.0
    s = s + 0.12 * (value2(wx * 0.02, wy * 0.02) - 0.5) * 2.0
    isl = value2(wx * 0.067 + seed * 5.0, wy * 0.067 + seed * 5.0)
    island = np.clip((isl - island_thr) / 0.08, 0, 1)
    island = island * island * (3 - 2 * island)

    def sstep(e0, e1, x):
        t = np.clip((x - e0) / (e1 - e0), 0, 1)
        return t * t * (3 - 2 * t)
    deep = sstep(0.92, 0.70, s) * (1 - island)
    rim = sstep(1.18, 0.88, s) * (1 - 0.5 * island)
    return deep, rim


def ring_slope(c, px, py, t, amp=1.0):
    """MarsWet_ImpactRings (MarsWet.ush:420-454) slope G for a Drops strand; returns gx, gy."""
    rr = np.sqrt(px * px + py * py)
    dx, dy = px / np.maximum(rr, 1e-3), py / np.maximum(rr, 1e-3)
    gx, gy = np.zeros_like(rr), np.zeros_like(rr)
    if not c.impact or amp <= 0:
        return gx, gy
    wd = max(RING_WIDTH, 0.1)
    k2 = 6.2831853 / RING_LAMBDA
    k0 = np.floor((t - c.tfall - rr / RING_SPEED) / c.p - c.seed).astype(np.int64)
    for i in (-1, 0, 1):
        kk = k0 + i
        for k in np.unique(kk):
            k = int(k)
            if c.skipped(k):
                continue
            age = t - c.impact_time(k)
            if age <= 0.0 or age > RING_LIFE:
                continue
            m = kk == k
            r = rr[m]
            u = r - RING_SPEED * age
            env = np.exp(-u * u / (wd * wd)) * math.exp(-age / RING_DECAY) * clamp(20.0 * age) / (1.0 + 0.08 * r)
            g = amp * env * (-k2 * np.sin(k2 * u) - (2.0 * u / (wd * wd)) * np.cos(k2 * u))
            if age < 0.12:
                g = g + RING_DIMPLE * amp * np.clip(1.0 - r / 2.0, 0, 1) * (1.0 - age / 0.12)
            gx[m] += g * dx[m]
            gy[m] += g * dy[m]
    return gx, gy


# ====================================================================== canvas
_FONTS = {}


def font(kind, size, weight="SemiBold"):
    key = (kind, int(size), weight)
    f = _FONTS.get(key)
    if f is None:
        if kind == "code":
            f = ImageFont.truetype(FONT_CODE_B if weight == "Bold" else FONT_CODE, int(size))
        else:
            f = ImageFont.truetype(FONT_UI, int(size))
            try:
                f.set_variation_by_name(weight)
            except Exception:
                pass
        _FONTS[key] = f
    return f


class Canvas:
    def __init__(self, inset):
        self.inset = inset
        self.out = (800, 450) if inset else (1920, 1080)
        self.k = self.out[0] * SS / LW
        size = (self.out[0] * SS, self.out[1] * SS)
        # Draw on RGB so ImageDraw blends (on an RGBA image it overwrites the alpha); an inset gets its alpha from the
        # panel mask at the end, so content and panel are one opaque-ish card over the footage.
        self.img = Image.new("RGB", size, BG)
        self.d = ImageDraw.Draw(self.img, "RGBA")
        self.mask = None
        if inset:
            self.mask = Image.new("L", size, 0)
            ImageDraw.Draw(self.mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=int(34 * self.k),
                                                        fill=PANEL_ALPHA)
            self.d.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=int(34 * self.k), outline=TEXT + (46,),
                                     width=max(int(4 * self.k), 2))

    def p(self, x, y):
        return (x * self.k, y * self.k)

    def px(self, v):
        return v * self.k

    def line(self, pts, col, w=6.0, a=1.0):
        if len(pts) < 2 or a <= 0.004:
            return
        self.d.line([self.p(*q) for q in pts], fill=rgba(col, a), width=max(int(round(w * self.k)), 1), joint="curve")

    def dashed(self, pts, col, w=6.0, a=1.0, dash=22.0, gap=16.0):
        """A dashed polyline (pattern in logical units, continuous across vertices)."""
        on, acc = True, 0.0
        cur = [pts[0]]
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            seg = math.hypot(x1 - x0, y1 - y0)
            pos = 0.0
            while seg - pos > 1e-6:
                left = (dash if on else gap) - acc
                step = min(left, seg - pos)
                pos += step
                acc += step
                q = (x0 + (x1 - x0) * pos / seg, y0 + (y1 - y0) * pos / seg)
                if on:
                    cur.append(q)
                if acc >= (dash if on else gap) - 1e-6:
                    if on and len(cur) > 1:
                        self.line(cur, col, w, a)
                    on, acc = not on, 0.0
                    cur = [q]
        if on and len(cur) > 1:
            self.line(cur, col, w, a)

    def circle(self, c, r, fill=None, outline=None, w=6.0, a=1.0):
        x, y = self.p(*c)
        rr = r * self.k
        self.d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=rgba(fill, a) if fill else None,
                       outline=rgba(outline, a) if outline else None, width=max(int(round(w * self.k)), 1))

    def ellipse(self, c, rx, ry, outline, w=6.0, a=1.0, fill=None):
        x, y = self.p(*c)
        self.d.ellipse((x - rx * self.k, y - ry * self.k, x + rx * self.k, y + ry * self.k),
                       outline=rgba(outline, a), fill=rgba(fill, a) if fill else None, width=max(int(round(w * self.k)), 1))

    def rect(self, box, fill=None, outline=None, w=6.0, a=1.0, r=0.0, fa=None):
        x0, y0 = self.p(box[0], box[1])
        x1, y1 = self.p(box[2], box[3])
        if x1 - x0 < 1 or y1 - y0 < 1:
            return
        kw = dict(fill=rgba(fill, a if fa is None else fa) if fill else None, outline=rgba(outline, a) if outline else None,
                  width=max(int(round(w * self.k)), 1))
        if r > 0:
            self.d.rounded_rectangle((x0, y0, x1, y1), radius=min(r * self.k, (x1 - x0) / 2, (y1 - y0) / 2), **kw)
        else:
            self.d.rectangle((x0, y0, x1, y1), **kw)

    def poly(self, pts, fill, a=1.0):
        self.d.polygon([self.p(*q) for q in pts], fill=rgba(fill, a))

    def text(self, xy, s, size=44, col=TEXT, a=1.0, kind="ui", weight="SemiBold", anchor="la"):
        if a <= 0.004:
            return
        f = font(kind, size * self.k, weight)
        x, y = self.p(*xy)
        if a >= 0.996:
            self.d.text((x, y), s, font=f, fill=rgba(col, 1.0), anchor=anchor)
            return
        # Pillow ignores the fill alpha for text: draw opaque on a layer, scale its alpha, composite
        l, t, r, b = self.d.textbbox((x, y), s, font=f, anchor=anchor)
        l, t = int(math.floor(l)) - 2, int(math.floor(t)) - 2
        layer = Image.new("RGBA", (int(math.ceil(r)) - l + 4, int(math.ceil(b)) - t + 4), (0, 0, 0, 0))
        ImageDraw.Draw(layer).text((x - l, y - t), s, font=f, fill=rgba(col, 1.0), anchor=anchor)
        layer.putalpha(layer.getchannel("A").point(lambda v: int(v * a)))
        self.img.paste(layer, (l, t), layer)

    def textw(self, s, size=44, kind="ui", weight="SemiBold"):
        return self.d.textlength(s, font=font(kind, size * self.k, weight)) / self.k

    def paste(self, im, box, a=1.0):
        """Paste a PIL RGB/RGBA image into logical box (x0, y0, x1, y1)."""
        x0, y0 = [int(round(v)) for v in self.p(box[0], box[1])]
        x1, y1 = [int(round(v)) for v in self.p(box[2], box[3])]
        im = im.convert("RGBA").resize((x1 - x0, y1 - y0), Image.BICUBIC)
        if a < 1.0:
            al = im.getchannel("A").point(lambda v: int(v * a))
            im.putalpha(al)
        self.img.paste(im, (x0, y0), im)

    def finish(self):
        im = self.img.resize(self.out, Image.LANCZOS)
        if not self.inset:
            return im
        im = im.convert("RGBA")
        im.putalpha(self.mask.resize(self.out, Image.LANCZOS))
        return im


def arrow_head(cv, tip, direction, col, size=18.0, a=1.0):
    dx, dy = direction
    n = math.hypot(dx, dy) or 1.0
    dx, dy = dx / n, dy / n
    bx, by = tip[0] - dx * size, tip[1] - dy * size
    cv.poly([tip, (bx - dy * size * 0.55, by + dx * size * 0.55), (bx + dy * size * 0.55, by - dx * size * 0.55)], col, a)


def title(cv, s, a=1.0, size=64):
    cv.text((60, 44), s, size, TEXT, a, weight="Bold")


def readout(cv, s, a=1.0):
    cv.text((1540, 52), s, 48, ACCENT, a, kind="code", anchor="ra")


def fmt_t(t):
    return "t = %.2f s" % (t % WRAP)


def stone_bar(cv, box, a=1.0):
    cv.rect(box, fill=STONE, a=a)
    x0, y0, x1, y1 = box
    x = x0 + 10
    while x < x1 - 10:
        cv.line([(x, y1 - 4), (min(x + (y1 - y0) - 8, x1 - 4), y0 + 4)], (52, 50, 48), 6, a)
        x += 46


def drop_shape(cv, x, y, v, r=13.0, a=1.0, col=TEXT):
    """A falling drop: round head (leading, down) with a streak trailing up, longer when faster."""
    tail = 6.0 + 48.0 * clamp(v / TERMINAL)
    cv.poly([(x - r * 0.75, y - r * 0.4), (x, y - r - tail), (x + r * 0.75, y - r * 0.4)], col, a * 0.75)
    cv.circle((x, y), r, fill=col, a=a)


# ====================================================================== shots
DEFAULT_STRAND = (350.0, 0.8, 0.3, 0.6)          # golden strand 1 of drip_reference (P = 1.25 s, fall 0.931 s)
SHOTS = {
    # name: (natural inset?, default seconds, default t0, default strand, description)
    "drip_clock": (True, 8.0, 10.0, DEFAULT_STRAND,
                   "One strand's drip clock: the bead swells, drops fall on the real drag curve (DistanceAt), splash, "
                   "rings; the 4 drop cards as lanes; a playhead at game time t0 + frame/30. Future events drawn dim."),
    "fall_curve": (True, 6.0, 0.0, DEFAULT_STRAND,
                   "Quadratic-drag fall (MarsDrip_DistanceAt, terminal 750 cm/s) vs free fall for a 350 cm strand at half "
                   "speed, then the exact inverse (MarsDrip_AgeAt): height -> landing time."),
    "slots_wrap": (False, 6.0, 20.0, (1200.0, 2.0, 0.37, 1.0),
                   "Drop k on card k mod 4: each card's busy span (fall + 0.28 s splash) ends before its next release "
                   "(a 12 m strand asked for 2 /s is slowed to 1.29 /s by the slot cap); then the 3600 s wrap seam."),
    "strand_trace": (True, 6.0, 1.0, DEFAULT_STRAND,
                     "AMars_DripLeak: trace up to the ceiling, trace down to the floor, the length into the cards' custom "
                     "data, the 6 cards at the impact, then drops as a function of game time."),
    "wet_layers": (False, 6.0, 1.0, DEFAULT_STRAND,
                   "The puddle as stacked layers: stone, the shape masks (MarsWet_PuddleShape), darker albedo "
                   "(PuddleWet), lower roughness (PuddleGloss), drifting micro-ripple normals, impact rings."),
    "ring_timing": (True, 5.5, 3.0, (300.0, 0.6, 0.42, 0.5),
                    "Impact time -> ring radius: each ring starts at its drop's impact (release + fall time) and runs "
                    "out at 22 cm/s for 1.4 s; 3 impacts, plus a top view of MarsWet_ImpactRings."),
}


# ---------------------------------------------------------------- fall_curve
def draw_fall_curve(cv, t, ctx):
    c = ctx["clock"]
    L = abs(c.length)
    x0, x1, y0, y1 = 230.0, 1020.0, 200.0, 800.0
    tmax = 1.0 if c.tfall < 0.95 else math.ceil(c.tfall * 2.0 + 0.2) / 2.0
    X = lambda s: x0 + s / tmax * (x1 - x0)
    Y = lambda d: y0 + d / L * (y1 - y0)
    start = c.y0 + c.radius
    t_free = math.sqrt(2.0 * (L - start) / GRAVITY)
    fade = ramp(t, 0.0, 0.4)
    inverse = ramp(t, 2.6, 3.0)
    title(cv, "Falling with drag", fade)

    # axes: time along the top, depth down
    cv.line([(x0, y0), (x1 + 20, y0)], TEXT, 6, 0.55 * fade)
    arrow_head(cv, (x1 + 34, y0), (1, 0), TEXT, 18, 0.55 * fade)
    cv.line([(x0, y0), (x0, y1)], TEXT, 6, 0.55 * fade)
    s = 0.0
    while s <= tmax + 1e-6:
        cv.line([(X(s), y0 - 12), (X(s), y0)], TEXT, 6, 0.55 * fade)
        cv.text((X(s), y0 - 20), ("%g s" % s), 40, TEXT, 0.75 * fade, anchor="ms")
        s += 0.5
    for d in range(100, int(L) - 30, 100):
        cv.line([(x0 - 12, Y(d)), (x0, Y(d))], TEXT, 6, 0.55 * fade)
        cv.text((x0 - 22, Y(d)), "%d" % d, 40, TEXT, 0.75 * fade, anchor="rm")
    cv.text((x0 - 22, y0 + 4), "0 cm", 40, TEXT, 0.75 * fade, anchor="rt")
    cv.line([(x0, y1), (x1, y1)], ACCENT, 6, 0.8 * fade)
    cv.text((x0 - 22, y1), "floor", 40, ACCENT, fade, anchor="rm")

    # curves (faint whole, bright up to now)
    n = 80
    drag = [(X(a), Y(drop_depth(c, a))) for a in np.linspace(0, c.tfall, n)]
    free = [(X(a), Y(start + 0.5 * GRAVITY * a * a)) for a in np.linspace(0, t_free, n)]
    cv.line(drag, ACCENT, 6, 0.25 * fade)
    cv.dashed(free, SECOND, 6, 0.3 * fade)
    a_now = clamp((t - 0.4) * 0.5, 0.0, 1.2)       # half speed
    a_d = min(a_now, c.tfall)
    a_f = min(a_now, t_free)
    if a_now > 0:
        cv.line([(X(a), Y(drop_depth(c, a))) for a in np.linspace(0, a_d, max(int(n * a_d / c.tfall), 2))], ACCENT, 8, fade)
        cv.dashed([(X(a), Y(start + 0.5 * GRAVITY * a * a)) for a in np.linspace(0, a_f, max(int(n * a_f / t_free), 2))],
                  SECOND, 8, fade)
    dot_a = 1.0 - 0.6 * inverse
    cv.circle((X(a_f), Y(start + 0.5 * GRAVITY * a_f * a_f)), 15, fill=SECOND, a=fade * dot_a)
    cv.circle((X(a_d), Y(drop_depth(c, a_d))), 17, fill=ACCENT, a=fade * dot_a)
    if a_now >= t_free:
        cv.text((X(t_free) - 16, y1 + 18), "%.2f s" % t_free, 40, SECOND, ramp(a_now, t_free, t_free + 0.08) * (1 - inverse),
                anchor="rt")
    if a_now >= c.tfall:
        cv.text((X(c.tfall) + 16, y1 + 18), "%.2f s" % c.tfall, 40, ACCENT,
                ramp(a_now, c.tfall, c.tfall + 0.08) * (1 - inverse), anchor="lt")
    if 0.4 < t < 2.6:
        cv.text((x1, y0 + 30), "half speed", 40, TEXT, 0.6 * fade * (1 - ramp(t, 2.3, 2.6)), anchor="rt")
        cv.line([(X(a_d), y0), (X(a_d), Y(drop_depth(c, a_d)))], TEXT, 6, 0.35 * fade * (1 - inverse))

    # inverse: given a height, when does it land
    if inverse > 0:
        w = ease_out((t - 2.8) / 2.2)
        depth = lerp(0.3 * L, L, w)
        age = ref.age_at(depth - start) if depth > start else 0.0
        xa, ya = X(age), Y(depth)
        cv.dashed([(x0, ya), (xa, ya)], TEXT, 6, 0.8 * inverse)
        cv.dashed([(xa, ya), (xa, y0)], TEXT, 6, 0.8 * inverse)
        arrow_head(cv, (xa, y0 + 2), (0, -1), TEXT, 20, 0.8 * inverse)
        cv.circle((xa, ya), 17, fill=ACCENT, a=inverse)
        cv.circle((xa, y0), 12, fill=TEXT, a=inverse)

    # legend + the phase panel
    lx = 1100.0
    cv.line([(lx, 230), (lx + 70, 230)], ACCENT, 8, fade)
    cv.text((lx + 90, 230), "with drag", 46, TEXT, fade, anchor="lm")
    cv.dashed([(lx, 300), (lx + 70, 300)], SECOND, 8, fade, dash=20, gap=12)
    cv.text((lx + 90, 300), "no air", 46, TEXT, fade, anchor="lm")
    fwd = fade * (1 - inverse)
    cv.text((lx, 400), "DistanceAt(t)", 48, ACCENT, fwd, kind="code", weight="Bold")
    cv.text((lx, 470), "given a time:", 44, TEXT, 0.75 * fwd)
    cv.text((lx, 524), "where is the drop?", 44, TEXT, fwd)
    cv.text((lx, 400), "AgeAt(y)", 48, ACCENT, inverse, kind="code", weight="Bold")
    cv.text((lx, 470), "given a height:", 44, TEXT, 0.75 * inverse)
    cv.text((lx, 524), "when does it land?", 44, TEXT, inverse)
    if inverse > 0:
        w = ease_out((t - 2.8) / 2.2)
        depth = lerp(0.3 * L, L, w)
        age = ref.age_at(depth - start)
        cv.text((lx, 620), "%3.0f cm -> %.2f s" % (depth, age), 44, TEXT, inverse, kind="code")
    else:
        cv.text((lx, 620), "%.2f s -> %3.0f cm" % (a_d, drop_depth(c, a_d)), 44, TEXT, fwd, kind="code")
    cv.text((lx, 730), "top speed", 40, TEXT, 0.7 * fade)
    cv.text((lx, 776), "%.0f cm/s" % TERMINAL, 50, TEXT, fade, weight="Bold")


# ---------------------------------------------------------------- drip_clock
def draw_strand_column(cv, c, T, sx, top, floor, a=1.0, bead_px=30.0, labels=True):
    """Side view of one strand at game time T: bead at the source, falling drops, crown splash, rings at the floor."""
    L = abs(c.length)
    pxcm = (floor - top) / L
    g = bead_growth(c, T)
    rb = bead_px * (0.35 + 0.65 * g ** (1.0 / 3.0))
    e = 1.0 + 0.6 * smooth((g - 0.7) / 0.3)
    btop = top
    if 0.5 < c.mode < 1.5:                          # DropsWithThread: the bead hangs at the thread tip, y0 below
        btop = top + max(c.y0 * pxcm - 2 * rb * e, 0.0)
        cv.line([(sx, top), (sx, btop + rb)], TEXT, 6, 0.55 * a)
    cv.d.ellipse((cv.px(sx - rb), cv.px(btop), cv.px(sx + rb), cv.px(btop + 2 * rb * e)), fill=rgba(TEXT, 0.9 * a))
    for k in drops_in(c, T - RING_LIFE - c.tfall, T):
        if c.skipped(k):
            continue
        age = T - c.release(k)
        if 0 <= age < c.tfall:
            y = top + drop_depth(c, age) * pxcm
            drop_shape(cv, sx, y - 13, ref.speed_at(age), 13, a)
        ia = T - c.impact_time(k)
        if 0 <= ia < CROWN_S:                       # floor crown (MarsWet.ush:172, 298-327)
            u = ia / CROWN_S
            for j in range(-3, 4):
                ang = math.radians(90 + j * 22)
                r0, r1 = 10 + 30 * u, 26 + 50 * u
                cv.line([(sx + math.cos(ang) * r0, floor - math.sin(ang) * r0 * 0.9),
                         (sx + math.cos(ang) * r1, floor - math.sin(ang) * r1 * 0.9)], ACCENT, 6, a * (1 - u))
        if 0 < ia <= RING_LIFE:                     # rings at 22 cm/s (MarsWet.ush:441)
            # same cm scale as the strand, but a short strand's 31 cm ring is kept inside the column (side view only)
            rx = RING_SPEED * ia * min(pxcm, 190.0 / (RING_SPEED * RING_LIFE))
            env = math.exp(-ia / RING_DECAY) * clamp(20.0 * ia)
            cv.ellipse((sx, floor), max(rx, 2.0), max(rx * 0.28, 1.0), SECOND, 6, a * clamp(env * 1.4))
    if labels:
        cv.text((sx + 48, btop + 26), "bead", 40, TEXT, 0.8 * a, anchor="lm")
        cv.text((sx + 70, floor - 34), "rings", 40, SECOND, a, anchor="lm")


def draw_drip_clock(cv, t, ctx):
    c = ctx["clock"]
    T = ctx["t0"] + t
    L = abs(c.length)
    title(cv, "One strand, four cards")
    readout(cv, fmt_t(T))

    # strand column
    sx, top, floor = 230.0, 175.0, 820.0
    stone_bar(cv, (90, 140, 450, top))
    stone_bar(cv, (90, floor, 450, floor + 28))
    draw_strand_column(cv, c, T, sx, top, floor)

    # plot + lanes
    px0, px1 = 640.0, 1540.0
    back, ahead = 3.4, 1.6
    ta, tb = T - back, T + ahead
    X = lambda s: px0 + (s - ta) / (tb - ta) * (px1 - px0)
    py0, py1 = 160.0, 500.0
    Y = lambda d: py0 + d / L * (py1 - py0)
    xp = X(T)
    cv.line([(px0, py0), (px1, py0)], TEXT, 6, 0.25)
    cv.line([(px0, py1), (px1, py1)], ACCENT, 6, 0.6)
    cv.text((px0 - 18, py0), "source", 40, TEXT, 0.75, anchor="rm")
    cv.text((px0 - 18, py1), "floor", 40, ACCENT, 1.0, anchor="rm")
    lane_top, lane_h, lane_step = 560.0, 46.0, 60.0
    for s in range(SLOTS):
        y = lane_top + s * lane_step
        cv.rect((px0, y, px1, y + lane_h), fill=TEXT, fa=0.05, r=10)
        cv.text((px0 - 18, y + lane_h / 2), "card %d" % (s + 1), 40, TEXT, 0.8, anchor="rm")

    def clipx(v):
        return min(max(v, px0), px1)

    for k in drops_in(c, ta, tb):
        r = c.release(k)
        imp = c.impact_time(k)
        s = k % SLOTS
        y = lane_top + s * lane_step
        if c.skipped(k):
            if px0 <= X(r) <= px1:
                cv.circle((X(r), y + lane_h / 2), 12, outline=TEXT, w=6, a=0.45)
            continue
        for part, (a0, a1, col) in enumerate(((r, imp, SECOND), (imp, imp + SPLASH_S, ACCENT))):
            # past part bright, future part dim
            for b0, b1, al in ((a0, min(a1, T), 0.95), (max(a0, T), a1, 0.3)):
                if b1 > b0:
                    x_a, x_b = clipx(X(b0)), clipx(X(b1))
                    if x_b - x_a > 1:
                        cv.rect((x_a, y + 4, x_b, y + lane_h - 4), fill=col, fa=al, r=8)
        # the fall on the plot
        pts_past, pts_fut = [], []
        for a in np.linspace(0.0, c.tfall, 40):
            tt = r + a
            if ta <= tt <= tb:
                (pts_past if tt <= T else pts_fut).append((X(tt), Y(drop_depth(c, a))))
        if pts_past and pts_fut:
            pts_fut.insert(0, pts_past[-1])
        cv.line(pts_past, SECOND, 7, 0.95)
        if len(pts_fut) > 1:
            cv.dashed(pts_fut, TEXT, 6, 0.3)
        if ta <= imp <= tb:
            cv.circle((X(imp), py1), 13, fill=ACCENT, a=0.95 if imp <= T else 0.3)
        if r <= T < imp:
            cv.circle((xp, Y(drop_depth(c, T - r))), 15, fill=TEXT)

    # time ticks
    s = math.ceil(ta)
    while s <= tb:
        x = X(s)
        if px0 + 30 <= x <= px1 - 30:
            cv.line([(x, 806), (x, 822)], TEXT, 6, 0.5)
            cv.text((x, 832), "%d s" % (s % WRAP), 40, TEXT, 0.6, anchor="mt")
        s += 1
    # playhead
    cv.line([(xp, py0 - 30), (xp, 806)], TEXT, 6, 0.9)
    cv.text((xp, py0 - 38), "now", 40, TEXT, 0.9, anchor="ms")


# ---------------------------------------------------------------- slots_wrap
def draw_lanes(cv, c, ta, tb, T, x0, x1, lane_top, lane_h, lane_step, a=1.0, label_k=False):
    X = lambda s: x0 + (s - ta) / (tb - ta) * (x1 - x0)

    def clipx(v):
        return min(max(v, x0), x1)
    for k in drops_in(c, ta, tb, pad=c.p * 4):
        r = c.release(k)
        imp = c.impact_time(k)
        s = k % SLOTS
        y = lane_top + s * lane_step
        if ta <= r <= tb:
            if c.skipped(k):
                cv.circle((X(r), 214), 12, outline=TEXT, w=6, a=0.5 * a)
            else:
                cv.line([(X(r), 196), (X(r), 232)], ACCENT, 7, (0.95 if r <= T else 0.35) * a)
        if c.skipped(k):
            if ta <= r <= tb:
                cv.circle((X(r), y + lane_h / 2), 14, outline=TEXT, w=6, a=0.4 * a)
            continue
        for a0, a1, col in ((r, imp, SECOND), (imp, imp + SPLASH_S, ACCENT)):
            for b0, b1, al in ((a0, min(a1, T), 0.95), (max(a0, T), a1, 0.32)):
                if b1 > b0:
                    xa, xb = clipx(X(b0)), clipx(X(b1))
                    if xb - xa > 1:
                        cv.rect((xa, y + 5, xb, y + lane_h - 5), fill=col, fa=al * a, r=10)
        # free gap until this card's next drop (k + 4)
        nxt = c.release(k + SLOTS)
        g0, g1 = clipx(X(imp + SPLASH_S)), clipx(X(nxt))
        if g1 - g0 > 20:
            cv.dashed([(g0 + 8, y + lane_h / 2), (g1 - 8, y + lane_h / 2)], TEXT, 6, 0.35 * a, dash=8, gap=14)
        if label_k:
            xa, xb = clipx(X(r)), clipx(X(imp))
            if xb - xa > 130:
                xm = (xa + xb) / 2
                past = xm <= X(T)
                cv.text((xm, y + lane_h / 2), "#%d" % (k % c.n), 40, BG if past else TEXT, a if past else 0.75 * a,
                        weight="Bold", anchor="mm")
    return X


def draw_slots_wrap(cv, t, ctx):
    c = ctx["clock"]
    title(cv, "Four cards take turns")
    cv.text((60, 128), "%.0f m fall, asked %.1f drops/s: the clock gives %.2f/s"
            % (abs(c.length) / 100.0, c.rate, 1.0 / c.p), 44, TEXT, 0.7)
    x0, x1 = 280.0, 1540.0
    lane_top, lane_h, lane_step = 250.0, 62.0, 76.0      # everything above y 660: a 2-line bottom caption has the rest
    fade_a = 1.0 - ramp(t, 2.9, 3.15)            # dip to the panel colour between the two views, no overlap
    seam = ramp(t, 3.15, 3.4)
    cv.text((x0 - 22, 214), "releases", 40, TEXT, 0.8, anchor="rm")
    for s in range(SLOTS):
        y = lane_top + s * lane_step
        cv.rect((x0, y, x1, y + lane_h), fill=TEXT, fa=0.05, r=12)
        cv.text((x0 - 22, y + lane_h / 2), "card %d" % (s + 1), 46, TEXT, 0.85, anchor="rm")

    if fade_a > 0.0:
        a = fade_a
        T = ctx["t0"] + t
        ta, tb = T - 8.0, T + 2.0
        X = draw_lanes(cv, c, ta, tb, T, x0, x1, lane_top, lane_h, lane_step, a)
        s = math.ceil(ta)
        while s <= tb:
            if x0 + 20 <= X(s) <= x1 - 20 and int(s) % 2 == 0:
                cv.text((X(s), 552), "%d s" % s, 40, TEXT, 0.55 * a, anchor="mt")
            s += 1
        cv.line([(X(T), 180), (X(T), 546)], TEXT, 6, 0.9 * a)
        # legend
        lx, ly = 280.0, 636.0
        cv.rect((lx, ly - 18, lx + 60, ly + 18), fill=SECOND, a=a, r=8)
        cv.text((lx + 76, ly), "falling", 44, TEXT, a, anchor="lm")
        cv.rect((lx + 280, ly - 18, lx + 340, ly + 18), fill=ACCENT, a=a, r=8)
        cv.text((lx + 356, ly), "splash", 44, TEXT, a, anchor="lm")
        cv.dashed([(lx + 560, ly), (lx + 640, ly)], TEXT, 6, 0.5 * a, dash=8, gap=14)
        cv.text((lx + 656, ly), "card free", 44, TEXT, a, anchor="lm")
    if seam > 0.0:
        a = seam
        T = WRAP - 2.2 + max(t - 3.15, 0.0) * 1.3
        ta, tb = T - 6.0, T + 3.0
        X = draw_lanes(cv, c, ta, tb, T, x0, x1, lane_top, lane_h, lane_step, a, label_k=True)
        s = math.ceil(ta)
        while s <= tb:
            if x0 + 40 <= X(s) <= x1 - 40 and abs(s - WRAP) > 1.5 and int(s) % 2 == 0:
                cv.text((X(s), 552), "%d s" % (s % WRAP), 40, TEXT, 0.55 * a, anchor="mt")
            s += 1
        xs = X(WRAP)
        cv.dashed([(xs, 170), (xs, 546)], ACCENT, 7, a, dash=18, gap=12)
        cv.text((xs, 552), "3600 s = 0 s", 42, ACCENT, a, weight="Bold", anchor="mt")
        cv.line([(X(T), 180), (X(T), 546)], TEXT, 6, 0.9 * a)
        cv.text((280, 636), "One loop = 3600 s = %d drops, a multiple of 4" % c.n, 44, TEXT, a, anchor="lm")


# ---------------------------------------------------------------- strand_trace
def draw_strand_trace(cv, t, ctx):
    c = ctx["clock"]
    L = abs(c.length)
    T = ctx["t0"] + t                 # the clock runs in real time
    t = t / 0.8                       # the choreography below is authored 25 % slow
    sx = 470.0
    ceil_y, floor_y = 205.0, 790.0
    start_y = 470.0
    phases = (("1  Trace up to the ceiling", 0.0, 1.6), ("2  Trace down to the floor", 1.6, 2.6),
              ("3  Pack it into custom data", 2.6, 3.8), ("4  Drops are a function of time", 3.8, 99.0))
    for name, p0, p1 in phases:
        a = ramp(t, p0, p0 + 0.15) * (1.0 - ramp(t, p1 - 0.15, p1))     # out, then the next one in: no overlap
        if a > 0:
            title(cv, name, a, 60)
    stone_bar(cv, (80, 150, 940, ceil_y))
    stone_bar(cv, (80, floor_y, 940, 850))

    # 1: trace up, the source snaps under the ceiling
    up = ease_out((t - 0.3) / 0.8)
    if t > 0.3:
        yt = lerp(start_y, ceil_y, up)
        cv.dashed([(sx, start_y), (sx, yt)], ACCENT, 7, 1.0 - ramp(t, 1.6, 1.9))
        if up >= 1.0:
            cv.circle((sx, ceil_y), 12, fill=ACCENT, a=1.0 - ramp(t, 1.6, 2.0))
    snap = ease_out((t - 1.2) / 0.35)
    icon_y = lerp(start_y, ceil_y + 16, snap)
    icon_a = 1.0 - 0.75 * ramp(t, 3.8, 4.2)
    d = 20.0
    cv.poly([(sx, icon_y - d), (sx + d, icon_y), (sx, icon_y + d), (sx - d, icon_y)], ACCENT, icon_a)
    cv.text((sx - 36, icon_y), "leak", 44, ACCENT, icon_a, anchor="rm")

    # 2: trace down, measure L
    down = ease_out((t - 1.7) / 0.8)
    if t > 1.7:
        yb = lerp(ceil_y + 16, floor_y, down)
        cv.dashed([(sx, ceil_y + 36), (sx, yb)], SECOND, 7, 1.0 - 0.75 * ramp(t, 3.8, 4.2))
        if down >= 1.0:
            cv.circle((sx, floor_y), 12, fill=SECOND, a=1.0 - ramp(t, 3.8, 4.2))
    dim = ramp(t, 2.4, 2.7)
    if dim > 0:
        dx = 620.0
        cv.line([(dx, ceil_y + 2), (dx, floor_y - 2)], TEXT, 6, 0.8 * dim)
        arrow_head(cv, (dx, ceil_y + 2), (0, -1), TEXT, 20, 0.8 * dim)
        arrow_head(cv, (dx, floor_y - 2), (0, 1), TEXT, 20, 0.8 * dim)
        cv.text((dx + 24, (ceil_y + floor_y) / 2 - 30), "L =", 44, TEXT, dim, anchor="lm")
        cv.text((dx + 24, (ceil_y + floor_y) / 2 + 26), "%.0f cm" % L, 52, TEXT, dim, weight="Bold", anchor="lm")

    # side notes for phases 1 and 2 (Mars_DripLeak.as Trace_Strand: AttachUp, then the surface classification)
    for lines, p0, p1 in ((("The strand hangs from", "whatever ceiling it finds"), 0.3, 1.6),
                          (("The hit also says", "floor, water or slope"), 1.9, 2.6)):
        a = ramp(t, p0, p0 + 0.3) * (1.0 - ramp(t, p1 - 0.1, p1 + 0.15))
        for i, ln in enumerate(lines):
            cv.text((1010, 420 + i * 58), ln, 44, ACCENT if i else TEXT, a)

    # 3: custom data rows (Mars_DripLeak.as Lay_Strand)
    rows = (("Length", "%.1f" % c.length), ("Rate", "%.2f" % c.rate), ("Seed", "%.2f" % c.seed),
            ("Jitter", "%.2f" % c.jitter), ("Mode", MODE_NAMES.get(int(round(c.mode)), "%g" % c.mode)), ("Slot", "0..5"), ("DropScale", "1.0"), ("Surface", "Floor"))
    tx0, tx1, ty0, rh = 1000.0, 1550.0, 178.0, 76.0
    for i, (k, v) in enumerate(rows):
        a = ease_out((t - 2.75 - 0.1 * i) / 0.3)
        if a <= 0:
            continue
        off = (1 - a) * 40
        y = ty0 + i * rh
        hi = 1.0 if i == 0 else 0.0
        cv.rect((tx0 + off, y, tx1 + off, y + rh - 10), fill=ACCENT if hi else TEXT, fa=(0.16 if hi else 0.06) * a, r=10)
        cv.text((tx0 + 20 + off, y + (rh - 10) / 2), k, 40, TEXT, 0.8 * a, anchor="lm")
        cv.text((tx1 - 20 + off, y + (rh - 10) / 2), v, 44, ACCENT if hi else TEXT, a, kind="code", anchor="rm")
    # the 6 cards waiting at the impact
    cards = ramp(t, 3.0, 3.3) * (1.0 - 0.8 * ramp(t, 4.2, 4.8))
    if cards > 0:
        for i in range(6):
            x = sx - 75 + i * 30
            cv.rect((x - 11, floor_y - 30, x + 11, floor_y - 8), fill=SECOND if i < 4 else (ACCENT if i == 4 else TEXT),
                    a=cards, r=4)
        cv.text((sx - 100, floor_y - 19), "6 cards", 40, TEXT, cards, anchor="rm")

    # 4: drops as a function of time along the traced strand
    live = ramp(t, 3.8, 4.2)
    if live > 0:
        draw_strand_column(cv, c, T, sx, ceil_y, floor_y, live, bead_px=26.0, labels=False)
        cv.text((60, 876), "y = Y0 + DistanceAt(t - release)", 40, ACCENT, live, kind="code", anchor="ls")
        readout(cv, fmt_t(T), live)


# ---------------------------------------------------------------- ring_timing
def ring_topview(c, T, n):
    lin = (np.arange(n) + 0.5) / n * 60.0 - 30.0
    px, py = np.meshgrid(lin, -lin)
    gx, gy = ring_slope(c, px, py, T)
    nz = 1.0 / np.sqrt(gx * gx + gy * gy + 1.0)
    nx, ny = -gx * nz, -gy * nz
    lx, ly, lz = -0.45, 0.55, 0.70
    shade = np.clip(nx * lx + ny * ly + nz * lz, 0, 1)
    op = np.clip(np.sqrt(gx * gx + gy * gy) * 2.0, 0, 1)                # display gain (the card's RingAlphaGain is 0.8)
    base = np.array([14, 26, 38], np.float64)
    hi = np.array(SECOND, np.float64)
    spec = np.clip((shade - 0.75) / 0.25, 0, 1) ** 2
    col = base[None, None, :] * (1 - op[..., None]) + (hi * (0.35 + 0.65 * shade[..., None])) * op[..., None]
    col = col + spec[..., None] * op[..., None] * (np.array(TEXT) - col)
    rr = np.sqrt(px * px + py * py)
    col[rr > 30.0] = BG
    return Image.fromarray(np.clip(col, 0, 255).astype(np.uint8), "RGB")


def draw_ring_timing(cv, t, ctx):
    c = ctx["clock"]
    t0, S = ctx["t0"], ctx["seconds"]
    T = t0 + t
    title(cv, "Rings keyed to landings")
    readout(cv, fmt_t(T))
    x0, x1, y0, y1 = 200.0, 1040.0, 210.0, 790.0
    rmax = 32.0
    X = lambda s: x0 + (s - t0) / S * (x1 - x0)
    Y = lambda r: y1 - r / rmax * (y1 - y0)
    cv.line([(x0, y1), (x1, y1)], TEXT, 6, 0.6)
    cv.line([(x0, y1), (x0, y0 - 10)], TEXT, 6, 0.6)
    cv.text((x0 - 18, y0 - 46), "ring radius", 40, TEXT, 0.75, anchor="ls")
    for r in (10, 20, 30):
        cv.line([(x0 - 12, Y(r)), (x0, Y(r))], TEXT, 6, 0.6)
        cv.line([(x0, Y(r)), (x1, Y(r))], TEXT, 6, 0.06)
        cv.text((x0 - 22, Y(r)), "%d cm" % r, 40, TEXT, 0.7, anchor="rm")
    s = math.ceil(t0)
    while s <= t0 + S + 1e-6:
        cv.line([(X(s), y1), (X(s), y1 + 12)], TEXT, 6, 0.6)
        cv.text((X(s), y1 + 22), "%d s" % (s % WRAP), 40, TEXT, 0.6, anchor="mt")
        s += 1
    impacts = [k for k in drops_in(c, t0 - RING_LIFE, t0 + S) if not c.skipped(k)
               and t0 - RING_LIFE < c.impact_time(k) <= t0 + S]
    first = True
    for k in impacts:
        ti = c.impact_time(k)
        ts = np.linspace(ti, ti + RING_LIFE, 50)
        pts = [(X(s), Y(RING_SPEED * (s - ti))) for s in ts if t0 <= s <= t0 + S]
        if len(pts) < 2:
            continue
        past = [(X(s), Y(RING_SPEED * (s - ti))) for s in ts if t0 <= s <= min(T, t0 + S)]
        cv.dashed(pts, TEXT, 6, 0.22)
        if len(past) > 1:
            # brightness follows the ring envelope exp(-age / Decay)
            for (pa, pb), s in zip(zip(past, past[1:]), ts):
                env = math.exp(-(s - ti) / RING_DECAY)
                cv.line([pa, pb], SECOND, 8, 0.35 + 0.65 * env)
        on = T >= ti
        if t0 <= ti <= t0 + S:
            xi = X(ti)
            cv.poly([(xi, y1 - 16), (xi + 14, y1), (xi, y1 + 16), (xi - 14, y1)], ACCENT, 1.0 if on else 0.35)
            if first and on:
                cv.text((xi + 30, y1 - 22), "lands", 40, ACCENT, ramp(T, ti, ti + 0.2), anchor="ls")
                cv.text((X(ti + 0.62) + 26, Y(RING_SPEED * 0.62)), "%g cm/s" % RING_SPEED, 40, SECOND,
                        ramp(T, ti + 0.3, ti + 0.6), anchor="lm")
                if ti + RING_LIFE <= t0 + S:
                    cv.text((X(ti + RING_LIFE) + 18, Y(RING_SPEED * RING_LIFE)), "gone at %g s" % RING_LIFE, 40, TEXT,
                            0.8 * ramp(T, ti + RING_LIFE - 0.2, ti + RING_LIFE), anchor="lm")
                first = False
            elif first:
                first = False
        if ti <= T <= ti + RING_LIFE:
            cv.circle((X(T), Y(RING_SPEED * (T - ti))), 15, fill=TEXT)
    cv.line([(X(T), y0 - 10), (X(T), y1)], TEXT, 6, 0.85)
    # top view
    box = (1110.0, 230.0, 1530.0, 650.0)
    n = int(round((box[2] - box[0]) * cv.k / SS))
    im = ring_topview(c, T, max(n, 64))
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, im.size[0] - 1, im.size[1] - 1), fill=255)
    im = im.convert("RGBA")
    im.putalpha(mask)
    cv.paste(im, box)
    cv.circle(((box[0] + box[2]) / 2, (box[1] + box[3]) / 2), (box[2] - box[0]) / 2, outline=TEXT, w=6, a=0.3)
    cv.text(((box[0] + box[2]) / 2, 690), "top view, 60 cm", 40, TEXT, 0.75, anchor="mt")


# ---------------------------------------------------------------- wet_layers
class WetScene:
    """A 140 cm stone patch with one puddle, every layer as numpy fields. Puddle maths = MarsWet.ush; values = the
    PuddleWet / PuddleGloss master defaults and the CisternDrip wetness (Mars_DripLeak.as ApplyPreset)."""
    EXTENT = 120.0
    PUDDLE = 110.0
    WETNESS = 0.85                       # CisternDrip preset
    DEEP_DARKEN, RIM_DARKEN = 0.6, 0.45  # PuddleWet_Mars_M
    TINT = np.array([0.010, 0.009, 0.007])
    DEEP_OP, RIM_OP = 0.95, 0.5          # PuddleGloss_Mars_M
    DEEP_R, RIM_R = 0.03, 0.35
    MICRO = 0.03
    STONE_R = 0.75                       # illustrative bare-stone roughness (not a Mars value)

    def __init__(self, n, clock):
        self.n = n
        self.c = clock
        lin = (np.arange(n) + 0.5) / n * self.EXTENT - self.EXTENT / 2
        self.wx, self.wy = np.meshgrid(lin, -lin)
        wx, wy = self.wx, self.wy
        # flagstones 35 cm, offset rows, joints 1.6 cm
        cell = 35.0
        row = np.floor(wy / cell)
        sx = wx / cell + 0.5 * (row % 2)
        col = np.floor(sx)
        fx, fy = sx - col, wy / cell - row
        edge = np.minimum(np.minimum(fx, 1 - fx), np.minimum(fy, 1 - fy)) * cell
        joint = np.clip(edge / 1.6, 0, 1)
        joint = joint * joint * (3 - 2 * joint)
        tone = 0.78 + 0.44 * hash21(col.astype(np.int64), row.astype(np.int64))
        fb = 0.5 * value2(wx * 0.11, wy * 0.11) + 0.3 * value2(wx * 0.31 + 7, wy * 0.31) + 0.2 * value2(wx * 0.9, wy * 0.9 + 3)
        base = np.array([0.30, 0.28, 0.255])
        self.albedo = base[None, None, :] * (tone * (0.8 + 0.4 * fb))[..., None]
        self.albedo = self.albedo * (0.45 + 0.55 * joint)[..., None]
        h = 1.6 * joint + 0.5 * fb
        d = self.EXTENT / n
        hy, hx = np.gradient(h, d)
        self.stone_n = self._norm(-hx * 2.0, hy * 2.0)
        # puddle masks (P in [-1, 1] over the puddle quad)
        half = self.PUDDLE / 2
        self.deep, self.rim = puddle_shape(wx / half, wy / half, wx - 300.0, wy + 800.0, 0.55, 0.4)
        out = (np.abs(wx) > half) | (np.abs(wy) > half)
        self.deep[out] = 0
        self.rim[out] = 0
        self.wet_op = np.maximum(self.deep * self.DEEP_DARKEN, self.rim * self.RIM_DARKEN) * self.WETNESS
        self.gloss_op = np.maximum(self.deep * self.DEEP_OP, self.rim * self.RIM_OP) * self.WETNESS
        self.puddle_r = self.RIM_R + (self.DEEP_R - self.RIM_R) * self.deep
        wsum = max(self.deep.sum(), 1e-6)
        self.hit = (float((self.wx * self.deep).sum() / wsum), float((self.wy * self.deep).sum() / wsum))
        self.light = np.array([self.hit[0] - 14.0, self.hit[1] + 12.0, 70.0])
        self.lcol = np.array([1.0, 0.78, 0.52])

    @staticmethod
    def _norm(gx, gy):
        nz = 1.0 / np.sqrt(gx * gx + gy * gy + 1.0)
        return np.stack([gx * nz, gy * nz, nz], -1)

    def micro(self, T):
        _, gx, gy = value2_grad(self.wx / 9.0 + T * 0.11, self.wy / 9.0 - T * 0.07)
        return self.MICRO * gx * self.deep, self.MICRO * gy * self.deep

    def rings(self, T):
        gx, gy = ring_slope(self.c, self.wx - self.hit[0], self.wy - self.hit[1], T)
        return gx, gy, np.clip(np.sqrt(gx * gx + gy * gy) * 0.6, 0, 1)

    def shade(self, albedo, n, rough):
        p = np.stack([self.wx, self.wy, np.zeros_like(self.wx)], -1)
        lv = self.light[None, None, :] - p
        dist = np.linalg.norm(lv, axis=-1)
        l = lv / dist[..., None]
        v = np.array([0.0, 0.0, 1.0])
        h = l + v[None, None, :]
        h = h / np.linalg.norm(h, axis=-1)[..., None]
        ndl = np.clip(np.sum(n * l, -1), 0, 1)
        ndh = np.clip(np.sum(n * h, -1), 0, 1)
        falloff = (70.0 / dist) ** 2
        alpha = np.clip(rough, 0.03, 1) ** 2 + 8.0 / (2 * 70.0)      # an 8 cm lamp (README lighting rule)
        a2 = alpha * alpha
        dd = a2 / (math.pi * (ndh * ndh * (a2 - 1) + 1) ** 2)
        spec = 0.024 * dd * ndl * 0.25                               # Specular 0.3 -> F0 0.024
        lin = albedo * (ndl * falloff)[..., None] * self.lcol * 0.75 + albedo * np.array([0.04, 0.05, 0.07])
        lin = lin + (spec * falloff)[..., None] * self.lcol * 2.5
        return (np.clip(lin, 0, 1) ** (1 / 2.2) * 255).astype(np.uint8)

    def state(self, i, T):
        """The composite with layers 0..i applied (0 stone, 1 mask overlay, 2 darker, 3 glossy, 4 ripples, 5 rings)."""
        albedo = self.albedo
        n = self.stone_n
        rough = np.full(self.deep.shape, self.STONE_R)
        if i >= 2:
            albedo = albedo + (self.TINT[None, None, :] - albedo) * self.wet_op[..., None]
        if i >= 3:
            gx = np.zeros_like(self.deep)
            gy = np.zeros_like(self.deep)
            if i >= 4:
                mx, my = self.micro(T)
                gx, gy = gx + mx, gy + my
            pn = self._norm(-gx, -gy)
            n = n + (pn - n) * self.gloss_op[..., None]
            rough = rough + (self.puddle_r - rough) * self.gloss_op
            if i >= 5:
                rx, ry, rop = self.rings(T)
                rn = self._norm(-rx - gx, -ry - gy)
                n = n + (rn - n) * rop[..., None]
                rough = rough + (0.03 - rough) * rop
            n = n / np.linalg.norm(n, axis=-1)[..., None]
        img = self.shade(albedo, n, rough)
        if i == 1:
            ov = np.array(SECOND, np.float64)
            w = np.clip(self.deep * 0.6 + (self.rim - self.deep).clip(0) * 0.3, 0, 1)[..., None]
            img = (img * (1 - w) + ov * w).astype(np.uint8)
        return Image.fromarray(img, "RGB")

    def thumbs(self, T, size):
        def im(a):
            return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB").resize((size, size), Image.BILINEAR)
        alb = (np.clip(self.albedo * 2.2, 0, 1) ** (1 / 2.2)) * 255
        mask = np.stack([self.deep * 0.6 + self.rim * 0.4] * 3, -1) * 255
        wet_alb = self.albedo + (self.TINT[None, None, :] - self.albedo) * self.wet_op[..., None]
        dark = (np.clip(wet_alb * 2.2, 0, 1) ** (1 / 2.2)) * 255
        rough = self.STONE_R + (self.puddle_r - self.STONE_R) * self.gloss_op
        rimg = np.stack([rough] * 3, -1) * 255
        mx, my = self.micro(T)
        sc = 1.0 / max(np.abs(mx).max(), np.abs(my).max(), 1e-6)   # contrast-stretched for the thumbnail
        nmap = np.stack([0.5 + 0.5 * mx * sc * 0.9, 0.5 + 0.5 * my * sc * 0.9, np.ones_like(mx)], -1) * 255
        # the rings icon: one ring 0.45 s after a landing, 40 cm across (an icon, not this frame's timing)
        k = last_drop(self.c, T)
        while self.c.skipped(k):
            k -= 1
        lin = (np.arange(size) + 0.5) / size * 40.0 - 20.0
        qx, qy = np.meshgrid(lin, -lin)
        rx, ry = ring_slope(self.c, qx, qy, self.c.impact_time(k) + 0.45)
        rs = 1.0 / max(np.abs(rx).max(), np.abs(ry).max(), 1e-3)
        rmap = np.stack([0.5 + 0.5 * rx * rs, 0.5 + 0.5 * ry * rs, np.ones_like(rx)], -1) * 255
        rimg_ = Image.fromarray(np.clip(rmap, 0, 255).astype(np.uint8), "RGB")
        return [im(alb), im(mask), im(dark), im(rimg), im(nmap), rimg_]


WET_CARDS = (("Stone", "the floor as built"), ("Mask", "deep core + damp rim"), ("Darker", "up to 60 % darker"),
             ("Glossy", "roughness 0.35 -> 0.03"), ("Ripples", "slow drifting normals"), ("Rings", "keyed to each landing"))
WET_T = [0.4 + 0.8 * i for i in range(6)]


def draw_wet_layers(cv, t, ctx):
    scene = ctx.get("scene")
    if scene is None:
        n = int(round(740 * cv.k / SS))
        scene = ctx["scene"] = WetScene(n, ctx["clock"])
    T = ctx["t0"] + t
    title(cv, "Wet stone, layer by layer")
    full = not cv.inset              # full frame: everything above y 660 (logical) so a 2-line bottom caption has the rest
    box = (60.0, 124.0, 590.0, 654.0) if full else (60.0, 140.0, 800.0, 880.0)
    cur = 0
    for i, ti in enumerate(WET_T):
        if t >= ti:
            cur = i
    w = ramp(t, WET_T[cur], WET_T[cur] + 0.4)
    img = scene.state(cur, T)
    if cur > 0 and w < 1.0:
        prev = scene.state(cur - 1, T)
        img = Image.blend(prev, img, w)
    cv.paste(img, box)
    cv.rect(box, outline=TEXT, w=6, a=0.25)
    th = 66.0 if full else 90.0
    tsize = max(int(round(th * cv.k / SS)), 24)
    thumbs = scene.thumbs(T, tsize)
    if full:
        cx0, cx1, cy0, ch, cstep = 650.0, 1540.0, 124.0, 82.0, 88.0
    else:
        cx0, cx1, cy0, ch, cstep = 860.0, 1540.0, 140.0, 116.0, 124.0
    pad = (ch - th) / 2.0
    for i, (label, detail) in enumerate(WET_CARDS):
        a = ease_out((t - WET_T[i]) / 0.4)
        if a <= 0:
            continue
        off = (1 - a) * 520
        y = cy0 + i * cstep
        active = i == cur
        cv.rect((cx0 + off, y, cx1 + off, y + ch), fill=TEXT, fa=0.07 * a, outline=ACCENT if active else TEXT,
                w=6, a=(1.0 if active else 0.18) * a, r=14)
        cv.paste(thumbs[i], (cx0 + pad + off, y + pad, cx0 + pad + th + off, y + pad + th), a)
        tx = cx0 + 2 * pad + th + 8 + off
        if full:                     # one line per card: label, then the detail after it
            cv.text((tx, y + ch / 2), label, 48, ACCENT if active else TEXT, a, weight="Bold", anchor="lm")
            cv.text((tx + 230, y + ch / 2), detail, 42, TEXT, 0.78 * a, anchor="lm")
        else:
            cv.text((tx, y + 12), label, 48, ACCENT if active else TEXT, a, weight="Bold")
            cv.text((tx, y + 66), detail, 40, TEXT, 0.72 * a)


DRAW = {"drip_clock": draw_drip_clock, "fall_curve": draw_fall_curve, "slots_wrap": draw_slots_wrap,
        "strand_trace": draw_strand_trace, "wet_layers": draw_wet_layers, "ring_timing": draw_ring_timing}


# ====================================================================== driver
def ffmpeg_exe():
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def render(shot, out_root, inset=None, t0=None, seconds=None, strand=None, frames=None, cli=""):
    nat_inset, d_sec, d_t0, d_strand, desc = SHOTS[shot]
    use_inset = nat_inset if inset is None else inset
    folder = shot if use_inset == nat_inset else shot + ("_inset" if use_inset else "_full")
    out = os.path.join(out_root, folder)
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if re.fullmatch(r"\d{5}\.png", f):
            os.remove(os.path.join(out, f))
    sec = d_sec if seconds is None else seconds
    t_0 = d_t0 if t0 is None else t0
    st = d_strand if strand is None else strand
    ctx = {"clock": make_clock(st), "t0": t_0, "seconds": sec}
    n = int(round(sec * FPS)) if frames is None else frames
    for f in range(n):
        cv = Canvas(use_inset)
        DRAW[shot](cv, f / FPS, ctx)
        cv.finish().save(os.path.join(out, "%05d.png" % f), compress_level=3)
    c = ctx["clock"]
    meta = {"fps": FPS, "frames": n, "real_seconds_covered": sec, "description": desc,
            "source": "Tools/Devlog/footage/diagrams/render_diagrams.py", "size": list(Canvas(use_inset).out),
            "transparent": use_inset, "variant": "inset" if use_inset else "full", "t0": t_0,
            "strand": {"length": st[0], "rate": st[1], "seed": st[2], "jitter": st[3],
                       "mode": st[4] if len(st) > 4 else 0.0, "period": c.p, "fall_seconds": c.tfall,
                       "drops_per_wrap": c.n},
            "cli": cli or "python -I render_diagrams.py --shot %s --out <root>%s --t0 %g --seconds %g --strand %s"
            % (shot, " --inset" if use_inset and not nat_inset else (" --full" if not use_inset and nat_inset else ""),
               t_0, sec, ",".join("%.9g" % v for v in st))}
    with open(os.path.join(out, "shot.json"), "w") as fh:
        json.dump(meta, fh, indent=2)
    prev = os.path.join(out, "_preview.mp4")
    subprocess.run([ffmpeg_exe(), "-y", "-loglevel", "error", "-threads", "2", "-framerate", str(FPS),
                    "-i", os.path.join(out, "%05d.png"), "-c:v", "libx264", "-crf", "23", "-pix_fmt", "yuv420p",
                    "-threads", "2", prev], check=True)
    print("SHOT %s -> %s (%d frames, %s)" % (shot, out, n, "inset" if use_inset else "full"))
    return out


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--shot", required=True, help="|".join(SHOTS) + "|all")
    ap.add_argument("--out", required=True, help="diagram root, e.g. D:/Repo/Content/Devlog/materials/diagrams")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--inset", action="store_true", help="force the 800x450 transparent inset variant")
    g.add_argument("--full", action="store_true", help="force the 1920x1080 full-frame variant")
    ap.add_argument("--t0", type=float, default=None, help="game time (s) at frame 0")
    ap.add_argument("--sync", default=None, help="footage shot.json: t0 = its frozen_t0 (+ --offset)")
    ap.add_argument("--offset", type=float, default=0.0, help="seconds added to the synced t0 (the manifest's in point)")
    ap.add_argument("--seconds", type=float, default=None)
    ap.add_argument("--strand", default=None, help="L,RATE,SEED,JITTER[,MODE] (cm, drops/s, 0..1, 0..1, EMars_DripMode)")
    ap.add_argument("--frames", type=int, default=None, help="render only the first N frames (checks)")
    a = ap.parse_args(argv)
    t0 = a.t0
    if a.sync:
        with open(a.sync) as fh:
            js = json.load(fh)
        t0 = float(js["frozen_t0"]) + a.offset
    strand = tuple(float(v) for v in a.strand.split(",")) if a.strand else None
    if a.sync and strand is None and isinstance(js.get("strand"), dict):
        fs = js["strand"]            # the footage strand (DripLeak CachedStrands entry), mode included
        strand = (fs["length_cm"], fs["rate"], fs["seed"], fs["jitter"], fs.get("mode", 0.0))
        print("strand from %s: %s" % (a.sync, ",".join("%.9g" % v for v in strand)))
    inset = True if a.inset else (False if a.full else None)
    cli = "python -I render_diagrams.py " + " ".join(argv)
    shots = list(SHOTS) if a.shot == "all" else [a.shot]
    for s in shots:
        render(s, a.out, inset, t0, a.seconds, strand, a.frames, cli)
        if a.shot == "all" and s == "wet_layers" and inset is None:
            render(s, a.out, True, t0, a.seconds, strand, a.frames, cli)


if __name__ == "__main__":
    main(sys.argv[1:])
