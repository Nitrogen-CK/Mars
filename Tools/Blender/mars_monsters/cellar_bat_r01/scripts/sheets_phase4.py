"""Cellar Bat R01 - Phase 4 sheets (system Python + Pillow, no Blender).

From review/phase4/_tiles and the rendered sequences, writes for every clip in export/anims/clips.json:
  review/phase4/<Clip>_sheet.png   4-up contact sheet: rows front / side / three-quarter / top, columns the sampled
                                   frames, labelled with frame numbers, markers and the audit result
  review/phase4/<Clip>_strip.png   every real-time frame (three-quarter) in one grid, for reading the motion
  review/phase4/<Clip>_half_strip.png   the half-speed sequence, where rendered
Run: python scripts/sheets_phase4.py [Clip,Clip]
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "review", "phase4")
TILES = os.path.join(OUT, "_tiles")
BG = (60, 60, 62)


def font(sz):
    for f in ("arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(f, sz)
        except OSError:
            pass
    return ImageFont.load_default()


def grid(images, cols, labels, title, tw, th):
    rows = (len(images) + cols - 1) // cols
    head = 34
    W, H = cols * tw + (cols + 1) * 4, rows * (th + 18) + head + 4
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    d.text((8, 6), title, fill=(235, 230, 220), font=font(18))
    for i, (im, lab) in enumerate(zip(images, labels)):
        r, c = divmod(i, cols)
        x, y = 4 + c * (tw + 4), head + r * (th + 18)
        if im is not None:
            sheet.paste(im.resize((tw, th)), (x, y + 16))
        d.text((x + 2, y), lab, fill=(240, 220, 160), font=font(13))
    return sheet


def main():
    clips = json.load(open(os.path.join(ROOT, "export", "anims", "clips.json")))
    rep = {}
    rp = os.path.join(OUT, "anim_report.json")
    if os.path.exists(rp):
        rep = json.load(open(rp)).get("clips", {})
    only = sys.argv[1].split(",") if len(sys.argv) > 1 else list(clips)
    for name in only:
        info = clips[name]
        fj = os.path.join(TILES, "%s_frames.json" % name)
        a = rep.get(name, {}).get("audit", {})
        bad = a.get("frames_with_cross_contact")
        audit = "audit: cross-part contact frames %s" % (bad if bad else "none")
        mk = info.get("markers", {})
        title = "%s  frames 0-%d (%d samples, 30 fps)%s  markers %s  |  %s" % (
            name, info["frames"][1], info["samples"], "  LOOP" if info["loop"] else "", mk or "-", audit)
        if os.path.exists(fj):
            meta = json.load(open(fj))
            ims, labs = [], []
            for v in meta["views"]:
                for f in meta["frames"]:
                    p = os.path.join(TILES, "%s_%s_%03d.png" % (name, v, f))
                    ims.append(Image.open(p).convert("RGB") if os.path.exists(p) else None)
                    tags = [k for k, mf in mk.items() if int(mf) == f]
                    labs.append("%s f%02d%s" % (v, f, (" " + ",".join(tags)) if tags else ""))
            grid(ims, len(meta["frames"]), labs, title, 240, 180).save(os.path.join(OUT, "%s_sheet.png" % name))
        for sub, step in ((name, 1.0), (name + "_half", 0.5)):
            d = os.path.join(OUT, sub)
            if not os.path.isdir(d):
                continue
            fs = sorted(f for f in os.listdir(d) if f.endswith(".png"))
            ims = [Image.open(os.path.join(d, f)).convert("RGB") for f in fs]
            labs = ["f%04.1f" % (i * step) for i in range(len(fs))]
            cols = 8 if len(fs) <= 32 else 10
            tw, th = (200, 150) if len(fs) <= 40 else (160, 120)
            grid(ims, cols, labs, "%s  %s  (three-quarter view, read left to right)" % (sub, title.split("|")[0]),
                 tw, th).save(os.path.join(OUT, "%s_strip.png" % sub))
        print("SHEET", name)


if __name__ == "__main__":
    main()
