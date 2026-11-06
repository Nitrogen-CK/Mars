"""Phase 3b side-by-sides (plain Python + Pillow, no Blender): concept crop | Phase 3 render | Phase 3b render, per row.
Run after render_cellar_bat.py:  python scripts/sidebyside_phase3b.py
Writes review/phase3b/sbs_wrap.png, sbs_hang.png, sbs_palette.png, sbs_ears.png."""
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.abspath(os.path.join(ROOT, "..", "..", "..", "..", "docs", "art", "flying-units-r01"))
P3, P3B = os.path.join(ROOT, "review", "phase3", "_tiles"), os.path.join(ROOT, "review", "phase3b", "_tiles")
W, H = 540, 480


def fit(im):
    im = im.convert("RGB")
    k = min(W / im.width, H / im.height)
    im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)
    out = Image.new("RGB", (W, H), (20, 19, 19))
    out.paste(im, ((W - im.width) // 2, (H - im.height) // 2))
    return out


def crop(sheet, box):
    return Image.open(os.path.join(ART, sheet)).crop(box)


def sheet(rows, out, labels=("concept", "Phase 3", "Phase 3b")):
    img = Image.new("RGB", (len(rows[0]) * (W + 6), len(rows) * (H + 6) + 26), (110, 110, 110))
    d = ImageDraw.Draw(img)
    for c, t in enumerate(labels[:len(rows[0])]):
        d.text((c * (W + 6) + 8, 6), t, fill=(255, 255, 255))
    for r, row in enumerate(rows):
        for c, im in enumerate(row):
            img.paste(fit(im) if im is not None else Image.new("RGB", (W, H)), (c * (W + 6), 26 + r * (H + 6)))
    img.save(os.path.join(ROOT, "review", "phase3b", out))
    print("SBS", out)


def t(d, n):
    p = os.path.join(d, n)
    return Image.open(p) if os.path.exists(p) else None


W3 = "03-wing-rig-and-expressions-v2.png"
wrap_c = crop(W3, (975, 495, 1165, 810))
hang_c = crop(W3, (1225, 495, 1648, 810))
sheet([[wrap_c, t(P3, "wrap_front.png"), t(P3B, "wrap_front.png")],
       [wrap_c, t(P3, "wrap_three_quarter.png"), t(P3B, "wrap_three_quarter.png")],
       [None, t(P3, "wrap_side.png"), t(P3B, "wrap_side.png")],
       [None, t(P3, "wrap_back.png"), t(P3B, "wrap_back.png")]], "sbs_wrap.png")
sheet([[hang_c, t(P3, "hang_front.png"), t(P3B, "hang_front.png")],
       [hang_c, t(P3, "hang_three_quarter.png"), t(P3B, "hang_three_quarter.png")],
       [None, t(P3, "hang_side.png"), t(P3B, "hang_side.png")],
       [None, t(P3, "hang_back.png"), t(P3B, "hang_back.png")]], "sbs_hang.png")
front_c = crop("02-model-turnaround-v2.png", (15, 120, 600, 400))
tq_c = crop("02-model-turnaround-v2.png", (1135, 490, 1650, 775))
sheet([[front_c, t(P3, "pal_neutral_front.png"), t(P3B, "pal_neutral_front.png")],
       [front_c, t(P3, "pal_dungeon_front.png"), t(P3B, "pal_dungeon_front.png")],
       [tq_c, t(P3, "pal_neutral_tq.png"), t(P3B, "pal_neutral_tq.png")],
       [tq_c, t(P3, "cmp_front.png"), t(P3B, "cmp_front.png")]], "sbs_palette.png")
face_c = crop(W3, (905, 80, 1230, 465))
side_c = crop("02-model-turnaround-v2.png", (640, 120, 1010, 400))
sheet([[face_c, t(P3, "cmp_face_03.png"), t(P3B, "cmp_face_03.png")],
       [face_c, t(P3, "pal_neutral_face.png"), t(P3B, "pal_neutral_face.png")],
       [side_c, t(P3, "cmp_side.png"), t(P3B, "cmp_side.png")],
       [side_c, t(P3, "ref_eevee_wingroot.png"), t(P3B, "ref_eevee_wingroot.png")]], "sbs_ears.png")
