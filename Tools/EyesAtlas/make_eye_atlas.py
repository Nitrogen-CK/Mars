"""Generate Eyes_Atlas_Mars_T.png, the eye-plate look's distance-field shape atlas.

Layout (a contract shared with Shaders/Looks/EyePlate.ush and the Eyes style/expression catalogs):
    1024 x 512, 8-bit single channel, 8 columns x 4 rows of 128 px cells,
    cell index = row * 8 + col, row 0 at the top.
Encoding (also a contract): value = clamp(0.5 + signedDistancePx / 32, 0, 1), positive inside,
so 0.5 is the shape's edge.

The cell table is APPEND-ONLY: a cell's index is what a style or expression stores, so a shape never moves
to another index and a retired one is left in place. Add new shapes in the blank cells (24-31).

Every shape is drawn for the plate's right half (U >= 0.5); the look mirrors U for the left half. So on an
asymmetric shape the cell's LEFT side is the inner edge (nearer the centre of the plate) and its RIGHT side
is the outer edge.

Each cell is rasterized as a binary mask at SUPERSAMPLE x resolution, run through an exact Euclidean distance
transform (inside and outside), and box-filtered back down, which keeps the 0.5 contour within a small
fraction of a pixel of the analytic edge. No scipy: the transform is the separable exact squared-EDT,
evaluated over a bounded window because any distance past the encoding's +/-16 px range clamps anyway.

Run:  python Tools/EyesAtlas/make_eye_atlas.py
The script ends with a self-check and exits non-zero if any of it fails.
"""

import math
import os
import sys

import numpy as np
from PIL import Image

# --------------------------------------------------------------------------------------------------------------------
# Contract constants
# --------------------------------------------------------------------------------------------------------------------

CELL_PX = 128
COLS = 8
ROWS = 4
ATLAS_W = CELL_PX * COLS
ATLAS_H = CELL_PX * ROWS
DISTANCE_SCALE_PX = 32.0
OUTPUT_NAME = "Eyes_Atlas_Mars_T.png"

# --------------------------------------------------------------------------------------------------------------------
# Generation constants
# --------------------------------------------------------------------------------------------------------------------

SUPERSAMPLE = 4
CELL_SS = CELL_PX * SUPERSAMPLE
# Distances past half the encoding range clamp to 0 or 1, so the transform only has to be exact up to a little
# beyond that; the window is in supersamples.
CLAMP_PX = 0.5 * DISTANCE_SCALE_PX
EDT_WINDOW_SS = int(math.ceil((CLAMP_PX + 2.0) * SUPERSAMPLE))
SIGNED_CLIP_PX = CLAMP_PX + 1.0

# Every shape stays within this many px of the cell centre on both axes (a centred 84 px square, tighter than the
# central 96 px): the self-check needs the 8 px border below 0.1, i.e. more than 12.8 px outside the shape.
SHAPE_LIMIT_PX = 42.0
MIN_STROKE_PX = 10.0
STROKE_R = 6.0

BORDER_PX = 8
BORDER_MAX = 0.1
ROUND_DOT_RADIUS_PX = 26.0
ROUND_DOT_TOLERANCE = 0.02

# --------------------------------------------------------------------------------------------------------------------
# Sample grid: cell-local pixel units, origin at the cell centre, x to the right, y UP.
# --------------------------------------------------------------------------------------------------------------------

_SS_COORDS = (np.arange(CELL_SS, dtype=np.float64) + 0.5) / SUPERSAMPLE - 0.5 * CELL_PX
X = np.tile(_SS_COORDS, (CELL_SS, 1))
Y = -np.tile(_SS_COORDS[:, None], (1, CELL_SS))


# --------------------------------------------------------------------------------------------------------------------
# Exact Euclidean distance transform (bounded window)
# --------------------------------------------------------------------------------------------------------------------

def edt_px(feature):
    """Distance in px from every sample to the nearest True sample of `feature`.

    Exact for every distance up to EDT_WINDOW_SS supersamples; anything further reads as at least that far
    (possibly inf), which the encoding clamps anyway. Separable: a 1-D squared-distance min along columns,
    then along rows, each restricted to offsets |k| <= window.
    """
    inf = np.float64(1e18)
    window = EDT_WINDOW_SS
    f = np.where(feature, 0.0, inf)

    rows = f.shape[0]
    padded = np.pad(f, ((window, window), (0, 0)), constant_values=inf)
    g = f.copy()
    for k in range(1, window + 1):
        k2 = float(k * k)
        np.minimum(g, padded[window + k:window + k + rows] + k2, out=g)
        np.minimum(g, padded[window - k:window - k + rows] + k2, out=g)

    cols = f.shape[1]
    padded = np.pad(g, ((0, 0), (window, window)), constant_values=inf)
    d = g.copy()
    for k in range(1, window + 1):
        k2 = float(k * k)
        np.minimum(d, padded[:, window + k:window + k + cols] + k2, out=d)
        np.minimum(d, padded[:, window - k:window - k + cols] + k2, out=d)

    return np.sqrt(d) / SUPERSAMPLE


def encode_cell(mask):
    """Supersampled boolean mask -> CELL_PX x CELL_PX float field in [0, 1] (0.5 = edge, positive inside)."""
    if not mask.any():
        return np.zeros((CELL_PX, CELL_PX), dtype=np.float64)

    half_sample_px = 0.5 / SUPERSAMPLE
    inside_depth = edt_px(~mask) - half_sample_px
    outside_depth = edt_px(mask) - half_sample_px
    signed = np.where(mask, inside_depth, -outside_depth)
    signed = np.clip(signed, -SIGNED_CLIP_PX, SIGNED_CLIP_PX)

    signed_px = signed.reshape(CELL_PX, SUPERSAMPLE, CELL_PX, SUPERSAMPLE).mean(axis=(1, 3))
    return np.clip(0.5 + signed_px / DISTANCE_SCALE_PX, 0.0, 1.0)


# --------------------------------------------------------------------------------------------------------------------
# Shape primitives (all return a boolean mask over the supersample grid)
# --------------------------------------------------------------------------------------------------------------------

def circle(cx, cy, r):
    return (X - cx) ** 2 + (Y - cy) ** 2 <= r * r


def ellipse(cx, cy, a, b):
    return ((X - cx) / a) ** 2 + ((Y - cy) / b) ** 2 <= 1.0


def box(cx, cy, half_w, half_h):
    return (np.abs(X - cx) <= half_w) & (np.abs(Y - cy) <= half_h)


def below_line(x0, y0, x1, y1):
    """Samples on or below the infinite line through (x0, y0) and (x1, y1)."""
    slope = (y1 - y0) / (x1 - x0)
    return Y <= y0 + (X - x0) * slope


def segment_distance(ax, ay, bx, by):
    px, py = X - ax, Y - ay
    dx, dy = bx - ax, by - ay
    h = np.clip((px * dx + py * dy) / (dx * dx + dy * dy), 0.0, 1.0)
    return np.hypot(px - dx * h, py - dy * h)


def stroke(points, r=STROKE_R):
    """A round-capped, round-jointed polyline of half-width r."""
    distance = np.full(X.shape, np.inf)
    for (ax, ay), (bx, by) in zip(points[:-1], points[1:]):
        np.minimum(distance, segment_distance(ax, ay, bx, by), out=distance)
    return distance <= r


def polygon(points):
    """Even-odd fill of a simple polygon."""
    inside = np.zeros(X.shape, dtype=bool)
    count = len(points)
    for i in range(count):
        x1, y1 = points[i]
        x2, y2 = points[(i + 1) % count]
        if y1 == y2:
            continue
        crosses = (y1 > Y) != (y2 > Y)
        x_at_y = x1 + (Y - y1) * (x2 - x1) / (y2 - y1)
        inside ^= crosses & (X < x_at_y)
    return inside


def astroid(cx, cy, radius, power):
    """A 4-point star: |x/R|^p + |y/R|^p <= 1 with p < 1 pinches the sides in toward the centre."""
    return (np.abs((X - cx) / radius) ** power + np.abs((Y - cy) / radius) ** power) <= 1.0


def dilate(mask, r):
    """Grow a mask by r px; used to round off points so no tip is thinner than 2r."""
    return mask | (edt_px(mask) <= r)


def round_cone(ax, ay, ar, bx, by, br, steps=256):
    """Convex hull of two circles: the union of circles swept from (a, ar) to (b, br)."""
    mask = np.zeros(X.shape, dtype=bool)
    for t in np.linspace(0.0, 1.0, steps):
        mask |= circle(ax + (bx - ax) * t, ay + (by - ay) * t, ar + (br - ar) * t)
    return mask


# --------------------------------------------------------------------------------------------------------------------
# The cell table. Index = row * 8 + col. Append-only.
# --------------------------------------------------------------------------------------------------------------------

OVAL_A = 22.0
OVAL_B = 38.0


def shape_blank():
    return np.zeros(X.shape, dtype=bool)


def shape_classic_oval():
    return ellipse(0.0, 0.0, OVAL_A, OVAL_B)


def shape_round_dot():
    return circle(0.0, 0.0, ROUND_DOT_RADIUS_PX)


def shape_square_pixel():
    return box(0.0, 0.0, 24.0, 24.0)


def shape_soft_star():
    return dilate(astroid(0.0, 0.0, 30.0, 0.55), 7.0)


def shape_tiny_slit():
    return stroke([(0.0, -28.0), (0.0, 28.0)])


def shape_heavy_lid():
    # The classic oval with its top shaved flat; same bottom, so a crossfade from the oval reads as a lid drop.
    return ellipse(0.0, 0.0, OVAL_A, OVAL_B) & (Y <= 14.0)


def shape_double_line():
    return stroke([(-14.0, -26.0), (-14.0, 26.0)]) | stroke([(14.0, -26.0), (14.0, 26.0)])


def shape_heart():
    scale = 30.0
    x = X / scale
    y = (Y + 3.75) / scale
    return (x * x + y * y - 1.0) ** 3 - x * x * y ** 3 <= 0.0


def shape_spiral():
    start_radius = 4.0
    pitch = 19.0
    turns = 1.7
    thetas = np.linspace(0.0, turns * 2.0 * math.pi, 400)
    radii = start_radius + pitch * thetas / (2.0 * math.pi)
    points = [(r * math.cos(t + math.pi * 0.5), r * math.sin(t + math.pi * 0.5)) for r, t in zip(radii, thetas)]
    return stroke(points, r=5.5)


def shape_candle():
    # Teardrop: round at the bottom, drawn up to a softened point.
    return round_cone(0.0, -12.0, 24.0, 0.0, 32.0, 5.0)


def shape_cracked():
    # A lightning bolt, top at the outer edge, striking down toward the inner edge.
    scale = 0.9
    raw = [(4.0, 36.0), (22.0, 36.0), (8.0, 6.0), (18.0, 6.0), (-14.0, -36.0), (-4.0, -2.0), (-14.0, -2.0)]
    points = [((x - 4.0) * scale, y * scale) for x, y in raw]
    return dilate(polygon(points), 5.0)


def shape_closed_line():
    return stroke([(-28.0, 0.0), (28.0, 0.0)])


def shape_happy_arc():
    centre_y = -21.0
    radius = 30.0
    angles = np.linspace(math.radians(25.0), math.radians(155.0), 200)
    points = [(radius * math.cos(a), centre_y + radius * math.sin(a)) for a in angles]
    return stroke(points)


def shape_sad():
    # Lid line high at the inner edge, falling to the outer edge.
    return ellipse(0.0, 0.0, OVAL_A, OVAL_B) & below_line(-OVAL_A, 20.0, OVAL_A, -2.0)


def shape_chevron():
    # '<' for the plate's right half; the mirrored left half reads '>'.
    return stroke([(18.0, 26.0), (-16.0, 0.0), (18.0, -26.0)])


def shape_angry():
    # Lid line low at the inner edge, rising to the outer edge.
    return ellipse(0.0, 0.0, OVAL_A, OVAL_B) & below_line(-OVAL_A, 0.0, OVAL_A, 24.0)


def shape_half_lid():
    return ellipse(0.0, 0.0, OVAL_A, OVAL_B) & (Y <= 0.0)


def shape_sparkle():
    big = dilate(astroid(-5.0, -5.0, 29.0, 0.42), 5.0)
    small = dilate(astroid(24.0, 24.0, 8.0, 0.45), 5.0)
    return big | small


def shape_wide():
    return circle(0.0, 0.0, 40.0)


def shape_x():
    return stroke([(-24.0, -24.0), (24.0, 24.0)]) | stroke([(-24.0, 24.0), (24.0, -24.0)])


def shape_tiny_dot():
    return circle(0.0, 0.0, 10.0)


def shape_ring():
    distance = np.hypot(X, Y)
    return (distance <= 32.0) & (distance >= 20.0)


def shape_wavy():
    xs = np.linspace(-30.0, 30.0, 200)
    points = [(x, -10.0 * math.sin(2.0 * math.pi * x / 60.0)) for x in xs]
    return stroke(points)


CELLS = [
    ("Blank", shape_blank),
    ("Classic Oval", shape_classic_oval),
    ("Round Dot", shape_round_dot),
    ("Square Pixel", shape_square_pixel),
    ("Soft Star", shape_soft_star),
    ("Tiny Slit", shape_tiny_slit),
    ("Heavy-Lid", shape_heavy_lid),
    ("Double-Line", shape_double_line),
    ("Heart", shape_heart),
    ("Spiral", shape_spiral),
    ("Candle", shape_candle),
    ("Cracked", shape_cracked),
    ("Closed", shape_closed_line),
    ("Happy", shape_happy_arc),
    ("Sad", shape_sad),
    ("Chevron", shape_chevron),
    ("Angry", shape_angry),
    ("Half-lid", shape_half_lid),
    ("Sparkle", shape_sparkle),
    ("Wide", shape_wide),
    ("X", shape_x),
    ("Tiny dot", shape_tiny_dot),
    ("Ring", shape_ring),
    ("Wavy", shape_wavy),
] + [("Blank", shape_blank)] * 8

ROUND_DOT_INDEX = 2

assert len(CELLS) == COLS * ROWS


# --------------------------------------------------------------------------------------------------------------------
# Build
# --------------------------------------------------------------------------------------------------------------------

def cell_origin(index):
    row, col = divmod(index, COLS)
    return row * CELL_PX, col * CELL_PX


def build_atlas():
    atlas = np.zeros((ATLAS_H, ATLAS_W), dtype=np.float64)
    shape_extents = {}
    for index, (name, make) in enumerate(CELLS):
        mask = make()
        if mask.any():
            shape_extents[index] = float(np.maximum(np.abs(X[mask]), np.abs(Y[mask])).max())
        top, left = cell_origin(index)
        atlas[top:top + CELL_PX, left:left + CELL_PX] = encode_cell(mask)
        print(f"  cell {index:2d}  {name}")
    return atlas, shape_extents


def quantize(atlas):
    return np.clip(np.rint(atlas * 255.0), 0, 255).astype(np.uint8)


# --------------------------------------------------------------------------------------------------------------------
# Self-check
# --------------------------------------------------------------------------------------------------------------------

def bilinear(image, px, py):
    """Sample a float image at continuous pixel coordinates where pixel i's centre sits at i + 0.5."""
    fx, fy = px - 0.5, py - 0.5
    x0, y0 = int(math.floor(fx)), int(math.floor(fy))
    tx, ty = fx - x0, fy - y0
    top = image[y0, x0] * (1.0 - tx) + image[y0, x0 + 1] * tx
    bottom = image[y0 + 1, x0] * (1.0 - tx) + image[y0 + 1, x0 + 1] * tx
    return top * (1.0 - ty) + bottom * ty


def self_check(path, shape_extents):
    failures = []

    with Image.open(path) as png:
        if png.size != (ATLAS_W, ATLAS_H) or png.mode != "L":
            failures.append(f"PNG is {png.size} mode {png.mode}, expected ({ATLAS_W}, {ATLAS_H}) mode L")
        stored = np.asarray(png, dtype=np.uint8)
    values = stored.astype(np.float64) / 255.0

    def cell(index):
        top, left = cell_origin(index)
        return values[top:top + CELL_PX, left:left + CELL_PX]

    blank_indices = [i for i, (_, make) in enumerate(CELLS) if make is shape_blank]
    for index in blank_indices:
        if cell(index).max() != 0.0:
            failures.append(f"blank cell {index} is not all 0 (max {cell(index).max():.4f})")

    dot = cell(ROUND_DOT_INDEX)
    centre = dot[CELL_PX // 2 - 1:CELL_PX // 2 + 1, CELL_PX // 2 - 1:CELL_PX // 2 + 1]
    if not np.all(centre == 1.0):
        failures.append(f"Round Dot centre is not 1.0-clamped: {centre.ravel().tolist()}")
    worst_edge_error = 0.0
    for step in range(16):
        angle = 2.0 * math.pi * step / 16.0
        px = 0.5 * CELL_PX + ROUND_DOT_RADIUS_PX * math.cos(angle)
        py = 0.5 * CELL_PX + ROUND_DOT_RADIUS_PX * math.sin(angle)
        error = abs(bilinear(dot, px, py) - 0.5)
        worst_edge_error = max(worst_edge_error, error)
    if worst_edge_error > ROUND_DOT_TOLERANCE:
        failures.append(f"Round Dot value at r={ROUND_DOT_RADIUS_PX} is off 0.5 by {worst_edge_error:.4f}")

    border = np.ones((CELL_PX, CELL_PX), dtype=bool)
    border[BORDER_PX:-BORDER_PX, BORDER_PX:-BORDER_PX] = False
    worst_border = 0.0
    for index in range(len(CELLS)):
        if index in blank_indices:
            continue
        border_max = cell(index)[border].max()
        worst_border = max(worst_border, border_max)
        if border_max >= BORDER_MAX:
            failures.append(f"cell {index} ({CELLS[index][0]}) border reaches {border_max:.4f}")

    # Supporting checks: every drawn cell has a solid core about a minimum stroke thick (half a pixel of slack for
    # where the pixel grid lands on the stroke's centre line), and stays inside the square the border check
    # depends on.
    min_core = 0.5 + (0.5 * MIN_STROKE_PX - 0.5) / DISTANCE_SCALE_PX
    for index in range(len(CELLS)):
        if index in blank_indices:
            continue
        if cell(index).max() < min_core:
            failures.append(f"cell {index} ({CELLS[index][0]}) has no core {MIN_STROKE_PX} px thick "
                            f"(max {cell(index).max():.4f})")
        if shape_extents.get(index, 0.0) > SHAPE_LIMIT_PX:
            failures.append(f"cell {index} ({CELLS[index][0]}) reaches {shape_extents[index]:.2f} px from the "
                            f"centre on an axis, past {SHAPE_LIMIT_PX}")

    print("Self-check:")
    print(f"  size/mode         {ATLAS_W}x{ATLAS_H} L")
    print(f"  blank cells       {blank_indices} all 0")
    print(f"  round dot centre  {centre.ravel().tolist()}")
    print(f"  round dot edge    worst |value - 0.5| at r={ROUND_DOT_RADIUS_PX} over 16 angles = "
          f"{worst_edge_error:.4f} (tolerance {ROUND_DOT_TOLERANCE})")
    print(f"  8 px border       worst non-blank value = {worst_border:.4f} (must be < {BORDER_MAX})")
    print(f"  shape extents     max {max(shape_extents.values()):.2f} px from centre on an axis "
          f"(limit {SHAPE_LIMIT_PX})")

    if failures:
        print("SELF-CHECK FAILED:")
        for failure in failures:
            print(f"  - {failure}")
        sys.exit(1)
    print("SELF-CHECK PASSED")


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(here, OUTPUT_NAME)
    print(f"Building {ATLAS_W}x{ATLAS_H} eye atlas ({COLS}x{ROWS} cells of {CELL_PX} px, x{SUPERSAMPLE} supersampled)")
    atlas, shape_extents = build_atlas()
    Image.fromarray(quantize(atlas)).convert("L").save(path)
    print(f"Wrote {path}")
    self_check(path, shape_extents)


if __name__ == "__main__":
    main()
