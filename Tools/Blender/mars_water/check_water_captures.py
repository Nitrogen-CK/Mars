"""Offline checks of the frozen-time captures mars_water_review writes (plain Python 3 + Pillow, run with -I):

    python -I check_water_captures.py ring  [UE_DIR]     # ring sync: flat before the impact, rings right after it
    python -I check_water_captures.py timing [UE_DIR]    # drop rows of the probe strand vs drip_reference predictions
    python -I check_water_captures.py sheet NAME [UE_DIR]  # contact sheet of ue/frozen/NAME_t*.png

ring   reads ring_n{-0.30,-0.05,+0.05,+0.30}.png (SCS_NORMAL from straight above the impact): against I-0.05 s, the
       frame round the impact must not change at I-0.30 s (< 0.5) and must change at I+0.05 s and I+0.30 s (> 1).
       Prints WATER_RING_SYNC_OK.
timing reads probe_t<T>.json + probe_t<T>.png (a narrow side camera on the probe strand, dark drops on a bright board):
       every predicted falling drop must have dark pixels within 1.5 px (+ the drop's own height) of its predicted head
       row in the strand's column. Prints WATER_TIMING_OK.
"""
import glob
import json
import os
import sys

UE_DIR = r"D:\Repo\Content\Water\export\review\ue"


def _img(path):
    from PIL import Image
    return Image.open(path).convert("RGB")


def ring(ue_dir):
    """Mean colour change, inside 12 % of the frame round the impact, of each normal capture against the one 0.05 s
    before the impact. Between two frames before the impact nothing moves; right after it the dimple and the first
    ring change the normals."""
    def region(name):
        im = _img(os.path.join(ue_dir, name))
        w, h = im.size
        r = int(0.12 * min(w, h))
        return [im.getpixel((x, y)) for y in range(h // 2 - r, h // 2 + r) for x in range(w // 2 - r, w // 2 + r)]

    def change(a, b):
        return sum(sum(abs(p - q) for p, q in zip(pa, pb)) / 3.0 for pa, pb in zip(a, b)) / len(a)

    base = region("ring_n-0.05.png")
    still = change(region("ring_n-0.30.png"), base)
    just, later = change(region("ring_n+0.05.png"), base), change(region("ring_n+0.30.png"), base)
    ok = still < 0.5 and just > 1.0 and later > 1.0
    print("normal change vs I-0.05 s: I-0.30 s %.3f, I+0.05 s %.3f, I+0.30 s %.3f" % (still, just, later))
    if ok:
        print("WATER_RING_SYNC_OK")
    return ok


def timing(ue_dir):
    paths = sorted(glob.glob(os.path.join(ue_dir, "probe_t*.json")))
    if not paths:
        print("no probe json")
        return False
    info = json.load(open(paths[-1]))
    im = _img(info["png"])
    w, h = im.size
    cx = w // 2
    dark = []
    for y in range(h):
        row = [sum(im.getpixel((x, y))) / 3.0 for x in range(cx - 4, cx + 5)]
        ref = sum(im.getpixel((cx + 40, y))) / 3.0
        dark.append(ref > 100 and min(row) < 0.97 * ref)
    ok = True
    tol = 1.5 + info["head_offset_px"] + 1.0
    for slot, k, row in info["expected_rows"]:
        # the drop's lowest dark row near the prediction is its leading edge; the streak trails above it
        r = int(round(row))
        rows = [y for y in range(max(r - 40, 0), min(r + 10, h)) if dark[y]]
        head = max(rows) if rows else None
        good = head is not None and abs(head - row) <= tol
        print("slot %d drop %d: predicted leading edge row %.1f, captured %s%s" % (
            slot, k, row, head, "" if good else "  MISMATCH"))
        ok = ok and good
    if ok and info["expected_rows"]:
        print("WATER_TIMING_OK")
    return ok


def sheet(name, ue_dir):
    from PIL import Image, ImageDraw
    frames = sorted(glob.glob(os.path.join(ue_dir, "frozen", "%s_t*.png" % name)))
    if not frames:
        return None
    ims = [_img(p) for p in frames]
    w, h = ims[0].size
    cols = 4
    rows = (len(ims) + cols - 1) // cols
    out = Image.new("RGB", (cols * w, rows * h), (0, 0, 0))
    d = ImageDraw.Draw(out)
    for i, (p, im) in enumerate(zip(frames, ims)):
        x, y = (i % cols) * w, (i // cols) * h
        out.paste(im, (x, y))
        d.text((x + 6, y + 6), os.path.basename(p).replace(".png", ""), fill=(255, 255, 255))
    path = os.path.join(ue_dir, "sheet_%s.png" % name)
    out.save(path)
    print("SHEET", path)
    return path


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "ring"
    if cmd == "sheet":
        sheet(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else UE_DIR)
    else:
        d = sys.argv[2] if len(sys.argv) > 2 else UE_DIR
        sys.exit(0 if (ring(d) if cmd == "ring" else timing(d)) else 1)
