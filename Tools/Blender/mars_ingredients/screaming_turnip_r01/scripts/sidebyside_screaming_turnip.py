"""Screaming Turnip R01 - side-by-side sheets: concept crop beside the renders. System Python with Pillow (not Blender).

Phase B2 (default): the MOUTH REGION, three rows (neutral, inhale, scream), each row = concept crop (sheet 01 FRONT /
sheet 04 INHALE / sheet 04 SCREAM PEAK, cropped so the mouth fills ~60% of the tile) | render front | render
three-quarter | render side, from review/phaseB2b/mouth/<pose>_m_{front,threequarter,side}.png (render_screaming_turnip.py
--mouth; the render ortho scale matches the crop's cm framing). Writes review/phaseB2b/iterations/<tag>_mouth_sidebyside.png.

Phase B (--phaseB): concept crop | front | three-quarter of the whole turnip from review/phaseB/<pose>/ (kept as it was).

Run (from the screaming_turnip_r01 folder):  python scripts/sidebyside_screaming_turnip.py <tag> [--phaseB]
Prints TURNIP_OK / TURNIP_FAIL.
"""
import os
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("TURNIP_FAIL Pillow missing")
    sys.exit(1)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PKG = os.path.normpath(os.path.join(ROOT, "..", "..", "..", "..", "docs", "art", "screaming-turnip-production-r01"))
CROPS_B = {  # pose: (sheet, crop box on the 1536x1024 sheet)
    "neutral": ("01-model-turnaround.png", (150, 140, 470, 530)),
    "inhale": ("04-exaggerated-vocal-cycle.png", (990, 160, 1340, 510)),
    "scream": ("04-exaggerated-vocal-cycle.png", (80, 570, 520, 960)),
}
# B2 mouth-region crops: sheet 01 FRONT ~21 px/cm (bulb ~190 px) -> 190 px = 9.2 cm; sheet 04 INHALE ~21.7 px/cm -> 260 px = 12 cm;
# sheet 04 SCREAM PEAK ~28 px/cm -> 230 px = 8.2 cm (= MOUTH_ORTHO in render_screaming_turnip.py)
CROPS_B2 = {
    "neutral": ("01-model-turnaround.png", (259, 305, 449, 495)),
    "inhale": ("04-exaggerated-vocal-cycle.png", (1062, 255, 1322, 515)),
    "scream": ("04-exaggerated-vocal-cycle.png", (165, 661, 459, 955)),     # 10.5 cm (r09: our gape is larger)
}


def fit(im, H):
    w, h = im.size
    return im.resize((int(w * H / h), H), Image.LANCZOS)


def sheet_of(rows, H):
    W = max(r.size[0] for r in rows)
    sheet = Image.new("RGB", (W, len(rows) * (H + 8) - 8), (90, 90, 90))
    for i, r in enumerate(rows):
        sheet.paste(r, (0, i * (H + 8)))
    return sheet


def row_of(tiles, H, label):
    w = sum(t.size[0] for t in tiles) + 8 * (len(tiles) - 1)
    row = Image.new("RGB", (w, H), (90, 90, 90))
    x = 0
    for t in tiles:
        row.paste(t, (x, 0))
        x += t.size[0] + 8
    d = ImageDraw.Draw(row)
    d.rectangle((0, 0, 7 * len(label) + 8, 16), fill=(245, 240, 230))
    d.text((4, 3), label, fill=(20, 20, 20))
    return row


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    tag = args[0] if args else "latest"
    phase_b = "--phaseB" in sys.argv
    rows = []
    if phase_b:
        H, out = 420, os.path.join(ROOT, "review", "phaseB")
        for pose, (sheet, box) in CROPS_B.items():
            tiles = [fit(Image.open(os.path.join(PKG, sheet)).convert("RGB").crop(box), H)]
            for view in ("front", "threequarter"):
                p = os.path.join(out, pose, "%s_%s.png" % (pose, view))
                if not os.path.exists(p):
                    print("TURNIP_FAIL missing %s" % p)
                    sys.exit(1)
                tiles.append(fit(Image.open(p).convert("RGB"), H))
            rows.append(row_of(tiles, H, "concept: %s  |  render: front, three-quarter" % pose))
        dst = os.path.join(out, "iterations", "%s_sidebyside.png" % tag)
    else:
        H, out = 400, os.path.join(ROOT, "review", "phaseB2b")
        for pose, (sheet, box) in CROPS_B2.items():
            tiles = [fit(Image.open(os.path.join(PKG, sheet)).convert("RGB").crop(box), H)]
            for view in ("front", "threequarter", "side"):
                p = os.path.join(out, "mouth", "%s_m_%s.png" % (pose, view))
                if not os.path.exists(p):
                    print("TURNIP_FAIL missing %s" % p)
                    sys.exit(1)
                tiles.append(fit(Image.open(p).convert("RGB"), H))
            rows.append(row_of(tiles, H, "%s %s: concept | front | three-quarter | side" % (tag, pose)))
        dst = os.path.join(out, "iterations", "%s_mouth_sidebyside.png" % tag)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    sheet_of(rows, H).save(dst)
    print("SIDEBYSIDE", dst)
    print("TURNIP_OK")


if __name__ == "__main__":
    main()
