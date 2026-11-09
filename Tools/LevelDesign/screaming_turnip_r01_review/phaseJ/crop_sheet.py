"""Crop the PIE viewport out of editor-window Shot captures (2576x1408: viewport at about x 12..1990, y 152..948) and tile them.
    python crop_sheet.py <capture dir> <out.png> <label> [<label> ...]"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw
d, out, labels = Path(sys.argv[1]), sys.argv[2], sys.argv[3:]
BOX = (12, 152, 1990, 948)
tiles = []
for lab in labels:
    im = Image.open(d / (lab + ".png")).convert("RGB")
    s = im.size[0] / 2576.0
    c = im.crop(tuple(int(v * s) for v in BOX)).resize((989, 398))
    ImageDraw.Draw(c).text((8, 6), lab, fill=(255, 255, 0))
    tiles.append(c)
cols = 2
rows = (len(tiles) + 1) // 2
sheet = Image.new("RGB", (989 * cols, 398 * rows), (0, 0, 0))
for n, c in enumerate(tiles):
    sheet.paste(c, ((n % cols) * 989, (n // cols) * 398))
sheet.save(out)
print(out)
