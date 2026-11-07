"""Tiles the eye-variant captures (mars_eye_variants.capture_all) into one labelled sheet on the host (editor Python has
no PIL): python mars_eye_variants_sheet.py [--cols 5] -> Saved/Screenshots/EyeVariants/eye_variants_sheet.png."""
import argparse
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
SHOT_DIR = r"D:\Repo\Mars\Saved\Screenshots\EyeVariants"


def names():
    # mars_eye_variants imports unreal at module level; read its VARIANTS table without importing it.
    src = open(os.path.join(HERE, "mars_eye_variants.py"), encoding="utf-8").read()
    start = src.index("VARIANTS = [")
    end = src.index("\n]\n", start)
    block = src[start:end]
    import re
    return re.findall(r'^\s*\("([^"]+)",', block, re.M)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cols", type=int, default=5)
    ap.add_argument("--tile", type=int, default=420)
    args = ap.parse_args()
    labels = names()
    tiles = [os.path.join(SHOT_DIR, "variant_%02d.png" % i) for i in range(len(labels))]
    tiles = [(l, p) for l, p in zip(labels, tiles) if os.path.exists(p)]
    cols = args.cols
    rows = (len(tiles) + cols - 1) // cols
    t, pad, cap = args.tile, 14, 34
    sheet = Image.new("RGB", (cols * (t + pad) + pad, rows * (t + pad + cap) + pad), (24, 30, 34))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 20)
    except OSError:
        font = ImageFont.load_default()
    for i, (label, path) in enumerate(tiles):
        img = Image.open(path).convert("RGB")
        w, h = img.size
        s = min(w, h)
        img = img.crop(((w - s) // 2, (h - s) // 2, (w - s) // 2 + s, (h - s) // 2 + s)).resize((t, t), Image.LANCZOS)
        x = pad + (i % cols) * (t + pad)
        y = pad + (i // cols) * (t + pad + cap)
        sheet.paste(img, (x, y))
        draw.text((x + 6, y + t + 6), label, fill=(235, 235, 235), font=font)
    out = os.path.join(SHOT_DIR, "eye_variants_sheet.png")
    sheet.save(out)
    print(out)


if __name__ == "__main__":
    main()
