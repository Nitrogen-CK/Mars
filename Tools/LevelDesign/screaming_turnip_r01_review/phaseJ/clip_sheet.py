"""Tile chosen frames of a capture_pie_movement_clip folder. python clip_sheet.py <frames dir> <out.png> <first> <last> <step>"""
import sys, glob
from PIL import Image, ImageDraw
d, out, a, b, st = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
fs = sorted(glob.glob(d + "/frame_*.png"))[a:b + 1:st]
tw, th = 660, 266
cols = 3
rows = (len(fs) + cols - 1) // cols
sheet = Image.new("RGB", (tw * cols, th * rows))
for n, f in enumerate(fs):
    im = Image.open(f).convert("RGB").resize((tw, th))
    ImageDraw.Draw(im).text((6, 4), f.replace("\\", "/").split("/")[-1], fill=(255, 255, 0))
    sheet.paste(im, ((n % cols) * tw, (n // cols) * th))
sheet.save(out); print(out, len(fs))
