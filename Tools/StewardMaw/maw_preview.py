"""numpy mirror of Shaders/Looks/StewardMaw.ush: draws the steward's face plate (burning eyes, needle teeth, the throat,
ichor strands) as the victim's view sees it, a sheet of frames through the devour scene, without an editor. Keep it in
step with the .ush when the shapes change. Needs numpy and Pillow, and the eye atlas PNG next door, which is not in the
repo: run Tools/EyesAtlas/make_eye_atlas.py first.

    python maw_preview.py out.png
"""
import os
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ATLAS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "EyesAtlas", "Eyes_Atlas_Mars_T.png")
ATLAS = np.array(Image.open(ATLAS_PATH).convert("L"), dtype=np.float64) / 255.0
COLS, ROWS = 8.0, 4.0

# look parameters (the .ush defaults)
REST_CELL, EVIL_CELL = 1.0, 24.0
EYE_SIZE, EYE_SPREAD, EYE_HEIGHT = 0.50, 0.30, -0.21
MOUTH_HEIGHT, MOUTH_WIDTH = 0.21, 0.70
GLOW, PAD = 0.35, 0.02
COLOR = np.array([1.0, 0.9, 0.72])
FIRE = np.array([1.0, 0.36, 0.05])
FLESH = np.array([0.42, 0.03, 0.02])

# the .ush defines
CURL, CLENCH, JAW_DROP, JAW_LIFT, JAW_NARROW, JAW_RISE = 0.30, 0.15, 0.85, 0.28, 0.72, 0.16
TEETH, LOW_TEETH, BACK_TEETH = 15.0, 14.0, 19.0
TOOTH_LEN, LOW_TOOTH_LEN, BACK_TOOTH_LEN = 0.40, 0.36, 0.20
TOOTH_HALF, TOOTH_TAPER, TOOTH_LEAN = 0.44, 0.75, 0.55
FANG_AT, FANG_LEN = 0.52, 0.45
STRANDS = 5
STRAND_WIDTH = 0.045


def saturate(x):
    return np.clip(x, 0.0, 1.0)


def lerp(a, b, t):
    return a + (b - a) * t


def smoothstep(a, b, x):
    t = saturate((x - a) / (b - a))
    return t * t * (3.0 - 2.0 * t)


def frac(x):
    return x - np.floor(x)


def hash21(x, y):
    p3x, p3y, p3z = frac(x * 0.1031), frac(y * 0.1031), frac(x * 0.1031)
    d = p3x * (p3y + 33.33) + p3y * (p3z + 33.33) + p3z * (p3x + 33.33)
    p3x, p3y, p3z = p3x + d, p3y + d, p3z + d
    return frac((p3x + p3y) * p3z)


def vnoise(x, y):
    ix, iy = np.floor(x), np.floor(y)
    fx, fy = x - ix, y - iy
    ux, uy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = hash21(ix, iy), hash21(ix + 1, iy)
    c, d = hash21(ix, iy + 1), hash21(ix + 1, iy + 1)
    return lerp(lerp(a, b, ux), lerp(c, d, ux), uy)


def fbm(x, y):
    v, amp = 0.0, 0.5
    for _ in range(5):
        v = v + amp * vnoise(x, y)
        x, y, amp = x * 2, y * 2, amp * 0.5
    return v


def sample_cell(cell, u, v):
    cx, cy = np.fmod(cell, COLS), np.floor(cell / COLS)
    u = (cx + np.clip(u, PAD, 1.0 - PAD)) / COLS
    v = (cy + np.clip(v, PAD, 1.0 - PAD)) / ROWS
    h, w = ATLAS.shape
    x = np.clip(u * w - 0.5, 0, w - 1.001)
    y = np.clip(v * h - 0.5, 0, h - 1.001)
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = x - x0, y - y0
    return (ATLAS[y0, x0] * (1 - fx) * (1 - fy) + ATLAS[y0, x0 + 1] * fx * (1 - fy)
            + ATLAS[y0 + 1, x0] * (1 - fx) * fy + ATLAS[y0 + 1, x0 + 1] * fx * fy)


def edge(d, px):
    """CkUsf_SdfEdgeAA stand-in: 1 inside (d < 0), one pixel of ramp."""
    return saturate(0.5 - d / px)


def profile(mx):
    return np.power(saturate(1.0 - mx * mx), 0.6)


def tooth_row(mx, dist, count, offset, length, seed, split):
    """One row of needle teeth hanging off a gum line. dist: how far past the gum line (M units, + into the mouth).
    Returns (signed distance: negative inside, 0..1 along the tooth, -1..1 across it)."""
    q = (mx * 0.5 + 0.5) * count + offset
    i = np.floor(q)
    u = q - i - 0.5
    cw = 2.0 / count
    xc = ((i + 0.5 - offset) / count) * 2.0 - 1.0
    h = hash21(i, seed)
    h2 = hash21(i, seed + 7.0)
    fang = saturate(1.0 - np.abs(np.abs(xc) - FANG_AT) * count * 0.5)
    ln = length * (0.55 + 0.45 * h + FANG_LEN * fang) * np.sqrt(profile(xc)) * split
    t = dist / np.maximum(ln, 1e-4)
    half = cw * TOOTH_HALF * (0.8 + 0.2 * h2) * np.power(saturate(1.0 - t), TOOTH_TAPER)
    across = u * cw - (h2 - 0.5) * TOOTH_LEAN * cw * t * t
    d = np.maximum(np.maximum(np.abs(across) - half, -dist), dist - ln)
    return d, saturate(t), across / np.maximum(half, 1e-4)


def tooth_color(t, across):
    stain = np.array([0.42, 0.17, 0.07])
    body = lerp(stain[:, None, None], COLOR[:, None, None], smoothstep(0.0, 0.5, t))
    return body * (1.0 - 0.45 * across * across)


def maw(X, Y, strength, eye_open, evil, mouth, jaw, zoom, heat=0.0, shake=0.0, tilt=0.0, time=0.0, width=640):
    px = 2.0 / width / max(zoom, 0.01)
    # the shudder, the cocked head, then the swell about the mouth
    sx = X + shake * (vnoise(time * 31.0, 0.5) - 0.5) * 2.0
    sy = Y + shake * (vnoise(time * 37.0, 5.5) - 0.5) * 2.0
    c, s = np.cos(tilt), np.sin(tilt)
    px_, py_ = sx * c - sy * s, sx * s + sy * c
    py_ = py_ + JAW_RISE * jaw
    pivot = MOUTH_HEIGHT + jaw * (JAW_DROP - JAW_LIFT) * 0.5 * MOUTH_WIDTH * lerp(1.0, JAW_NARROW, jaw)
    px_ = px_ / max(zoom, 0.01)
    py_ = (py_ - pivot) / max(zoom, 0.01) + pivot

    col = np.zeros((3,) + X.shape)

    # --- mouth, in units of its half width
    split = saturate(mouth)
    wd = MOUTH_WIDTH * lerp(1.0, JAW_NARROW, jaw)
    mx, my = px_ / wd, (py_ - MOUTH_HEIGHT) / wd
    mpx = px / wd
    ax = np.abs(mx)
    w = profile(mx)
    bite = -CURL * mx * mx
    top = bite - (CLENCH + jaw * JAW_LIFT) * w * split
    bot = bite + (CLENCH + jaw * JAW_DROP) * w * split
    past = ax - 1.0
    opened = 1.0 if split > 0.001 else 0.0
    inside = edge(np.maximum(np.maximum(top - my, my - bot), past), mpx) * opened

    # the throat: wet red by the gums, falling to black
    depth = np.minimum(my - top, bot - my)
    col = lerp(col, FLESH[:, None, None] * 0.55 * np.exp(-np.maximum(depth, 0.0) / 0.07), inside)

    # the back row, dim
    d_bu, t_bu, a_bu = tooth_row(mx, my - top, BACK_TEETH, 0.37, BACK_TOOTH_LEN, 31.0, split)
    d_bl, t_bl, a_bl = tooth_row(mx, bot - my, BACK_TEETH, 0.81, BACK_TOOTH_LEN, 47.0, split)
    back = saturate(edge(np.maximum(d_bu, my - bot), mpx) + edge(np.maximum(d_bl, top - my), mpx)) * inside
    col = lerp(col, tooth_color(np.minimum(t_bu, t_bl) * 0 + 0.6, a_bu * 0) * 0.22, back)

    # the front rows: the lower stops an outline short of the upper needles lying over it
    d_u, t_u, a_u = tooth_row(mx, my - top, TEETH, 0.0, TOOTH_LEN, 3.0, split)
    d_l, t_l, a_l = tooth_row(mx, bot - my, LOW_TEETH, 0.5, LOW_TOOTH_LEN, 13.0, split)
    d_u = np.maximum(np.maximum(d_u, my - bot), past)
    d_l = np.maximum(np.maximum(d_l, top - my), past)
    outline = 0.012
    lower = edge(np.maximum(d_l, outline - d_u), mpx) * opened
    upper = edge(d_u, mpx) * opened
    col = lerp(col, tooth_color(t_l, a_l) * 0.85, lower)
    col = lerp(col, tooth_color(t_u, a_u), upper)

    # ichor: strands between the jaws that stretch thin as they open, then part and hang
    span = np.maximum(bot - top, 1e-4)
    st = (my - top) / span
    strands = np.zeros_like(X)
    shine = np.zeros_like(X)
    for j in range(STRANDS):
        h = hash21(j + 1.0, 91.0)
        h2 = hash21(j + 1.0, 57.0)
        xj = -0.78 + 1.56 * (j + h) / STRANDS + (0.10 * (h2 - 0.5) + 0.02 * np.sin(time * 2.3 + j * 1.7)) * np.sin(3.14159 * st)
        th = STRAND_WIDTH * (0.5 + h2) * (0.22 + 0.78 * (2.0 * st - 1.0) ** 4) / (1.0 + 1.5 * jaw)
        parted = saturate((jaw - (0.35 + 0.6 * h)) * 2.5)
        keep = lerp(0.5, 0.10 + 0.25 * h2, parted)                 # the share of each end still hanging
        end = np.minimum(st, 1.0 - st)
        dj = np.maximum(np.abs(mx - xj) - th, (end - keep) * span)
        m = edge(dj, mpx)
        strands = np.maximum(strands, m)
        shine = np.maximum(shine, m * smoothstep(th * 0.6, 0.0, np.abs(mx - xj - th * 0.35)))
    strands = strands * inside * smoothstep(0.02, 0.12, jaw)
    col = lerp(col, FLESH[:, None, None] * 0.30 + (COLOR[:, None, None] * 0.45) * shine, strands)

    # --- eyes: one atlas cell each, the left one mirrored; they catch fire with Heat
    side = np.where(px_ < 0.0, 7.0, 0.0)
    eu = (np.abs(px_) - EYE_SPREAD) / EYE_SIZE + 0.5
    ev = (py_ - EYE_HEIGHT) / EYE_SIZE + 0.5
    ev = (ev - 0.5) / max(eye_open, 0.04) + 0.5
    lick = fbm(eu * 4.0 + side, ev * 2.6 + time * 2.4)
    lick2 = fbm(eu * 7.0 + side + 3.0, ev * 4.0 + time * 3.7)
    rise = smoothstep(0.80, 0.15, ev) * heat
    fu = eu + (lick2 - 0.5) * 0.16 * rise
    fv = ev + lick * 0.34 * rise
    ins = ((eu > 0) & (eu < 1) & (ev > 0) & (ev < 1)).astype(np.float64) * (1.0 if eye_open > 0.001 else 0.0)
    field = lerp(sample_cell(REST_CELL, fu, fv), sample_cell(EVIL_CELL, fu, fv), saturate(evil)) * ins
    field_px = (px / EYE_SIZE) * 128.0 / 32.0
    core = saturate(0.5 + (field - 0.5) / max(field_px, 1e-6))
    glow = smoothstep(0.25, 0.5, field) * GLOW
    calm = COLOR[:, None, None] * saturate(core + glow)
    # white-hot heart, orange body, red rim, and a halo that reaches past the shape
    deep = saturate((field - 0.5) / 0.22)
    hot = (lerp(np.array([0.9, 0.10, 0.02])[:, None, None], FIRE[:, None, None] * 1.6, smoothstep(0.0, 0.45, deep))
           + np.array([1.0, 0.85, 0.5])[:, None, None] * 1.6 * smoothstep(0.35, 1.0, deep))
    flick = 0.82 + 0.36 * vnoise(time * 11.0, side + 2.0)
    burning = hot * core * flick + FIRE[:, None, None] * smoothstep(0.12, 0.5, field) * (1.0 - core) * 0.9 * flick
    col += lerp(calm, burning, saturate(heat))

    return strength * col


def render(width=640, height=360, bloom=True, **k):
    xs = (np.arange(width) + 0.5) / width * 2.0 - 1.0
    ys = ((np.arange(height) + 0.5) / height * 2.0 - 1.0) * height / width
    X, Y = np.meshgrid(xs, ys)
    v = maw(X, Y, width=width, **k)
    img = np.moveaxis(v, 0, -1)
    if bloom:
        hi = np.clip(img - 0.8, 0, None)
        b = Image.fromarray((np.clip(hi / 3.0, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(width / 60.0))
        img = img + np.asarray(b, dtype=np.float64) / 255.0 * 3.0 * 0.5
    img = 1.0 - np.exp(-img * 1.6)                     # a filmic-ish shoulder
    return Image.fromarray((np.clip(img, 0, 1) ** (1 / 1.0) * 255).astype(np.uint8))


FRAMES = [
    ("eyes open", dict(strength=1, eye_open=1, evil=0, mouth=0, jaw=0, zoom=1.0, heat=0.0, time=0.2)),
    ("grin splits, eyes smoulder", dict(strength=1, eye_open=0.9, evil=0, mouth=0.4, jaw=0, zoom=1.03, heat=0.3, tilt=-0.03, time=0.7)),
    ("grin", dict(strength=1, eye_open=0.8, evil=0, mouth=1, jaw=0, zoom=1.08, heat=0.7, tilt=-0.09, time=1.3)),
    ("bite 0.15", dict(strength=1, eye_open=1, evil=0.6, mouth=1, jaw=0.35, zoom=1.08, heat=0.9, tilt=-0.04, shake=0.004, time=1.6)),
    ("bite 0.3: the maw", dict(strength=1, eye_open=1, evil=1, mouth=1, jaw=1.0, zoom=1.1, heat=1, shake=0.008, time=1.8)),
    ("bite 0.6: lunge", dict(strength=1, eye_open=1, evil=1, mouth=1, jaw=1.0, zoom=1.7, heat=1, shake=0.012, time=2.0)),
    ("into the throat", dict(strength=1, eye_open=1, evil=1, mouth=1, jaw=1.0, zoom=3.0, heat=1, shake=0.015, time=2.1)),
    ("snap", dict(strength=1, eye_open=1, evil=1, mouth=1, jaw=0.15, zoom=3.4, heat=1, shake=0.02, time=2.2)),
]

if __name__ == "__main__":
    out = sys.argv[1]
    W, H = 640, 360
    sheet = Image.new("RGB", (W * 4, H * 2), (40, 0, 0))
    for i, (name, k) in enumerate(FRAMES):
        sheet.paste(render(W, H, **k), ((i % 4) * W, (i // 4) * H))
    d = ImageDraw.Draw(sheet)
    for i in range(1, 4):
        d.line((i * W, 0, i * W, H * 2), fill=(70, 70, 70))
    d.line((0, H, W * 4, H), fill=(70, 70, 70))
    for i, (name, _) in enumerate(FRAMES):
        d.text(((i % 4) * W + 6, (i // 4) * H + 4), name, fill=(150, 150, 150))
    sheet.save(out)
    print("PROTO_OK", out)
