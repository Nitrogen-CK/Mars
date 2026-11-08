"""Pantry Rat R02 - measure sheet 02 panels (pixel bboxes per colour class) and write the crops once.

blender -b --factory-startup --python scripts/sheet_measure.py
Writes review/sheet_crops/<view>.png and review/sheet_crops/sheet02_measure.json. Sheet px origin top-left (1536x1024).
"""
import json, os, sys
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
REPO = os.path.abspath(os.path.join(ROOT, "..", "..", "..", ".."))
SHEET = os.path.join(REPO, "docs", "art", "pantry-rat-dens-production-r01", "02-rat-model-turnaround.png")
OUT = os.path.join(ROOT, "review", "sheet_crops")
# panel boxes (x0, y0, x1, y1) in sheet px, top-left origin; titles excluded
PANELS = {"front": (22, 142, 352, 452), "right": (366, 142, 894, 452), "rear": (906, 142, 1204, 452),
          "hero": (16, 545, 634, 998), "top": (646, 545, 906, 998), "underside": (916, 545, 1208, 998)}
CLASSES = {  # sRGB reference colours (sampled by eye, refined by the swatch sampler below)
    "body": (0.33, 0.25, 0.31), "pink": (0.86, 0.47, 0.52), "wood": (0.66, 0.40, 0.22),
    "amber": (0.98, 0.72, 0.08), "belly": (0.90, 0.83, 0.74)}
SWATCH = {"body": (1279, 194), "pink": (1279, 279), "amber": (1279, 358), "wood": (1279, 446), "belly": (1279, 530)}


def load(path):
    im = bpy.data.images.load(path, check_existing=False)
    im.colorspace_settings.name = "sRGB"
    w, h = im.size
    px = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]  # top-left origin
    bpy.data.images.remove(im)
    return px


def save(px, path):
    h, w = px.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=False)
    img.pixels.foreach_set(np.ascontiguousarray(px[::-1]).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def main():
    os.makedirs(OUT, exist_ok=True)
    px = load(SHEET)
    H, W = px.shape[:2]
    res = {"sheet": SHEET, "size": [W, H], "panels": PANELS, "swatch_srgb": {}, "bbox": {}}
    # swatches: median of a 20 px disc
    for k, (x, y) in SWATCH.items():
        patch = px[y - 10:y + 10, x - 10:x + 10, :3].reshape(-1, 3)
        med = np.median(patch, axis=0)
        res["swatch_srgb"][k] = [round(float(c), 4) for c in med]
        res["swatch_hex"] = res.get("swatch_hex", {})
        res["swatch_hex"][k] = "#%02X%02X%02X" % tuple(int(round(c * 255)) for c in med)
        CLASSES[k] = tuple(float(c) for c in med)
    # drawing samples (5x5 median): strap leather, eye rim, amber iris, belly (underside), body facets (side, lit / shade)
    DRAW = {"harness_strap_side": (666, 269), "harness_girth_top": (720, 760), "eye_rim_side": (812, 307),
            "amber_iris_side": (799, 306), "belly_underside": (1064, 680), "body_side_lit": (560, 300),
            "body_side_shade": (560, 400), "pink_ear_side": (720, 260)}
    res["drawing_samples"] = {}
    for k, (x, y) in DRAW.items():
        med = np.median(px[y - 2:y + 3, x - 2:x + 3, :3].reshape(-1, 3), axis=0)
        res["drawing_samples"][k] = "#%02X%02X%02X" % tuple(int(round(c * 255)) for c in med)
    print("DRAW", res["drawing_samples"])
    bg = np.median(px[150:160, 1250:1500, :3].reshape(-1, 3), axis=0)
    res["bg_srgb"] = [round(float(c), 4) for c in bg]
    for name, (x0, y0, x1, y1) in PANELS.items():
        crop = px[y0:y1, x0:x1].copy()
        save(crop, os.path.join(OUT, name + ".png"))
        rgb = crop[..., :3]
        out = {}
        d_bg = np.linalg.norm(rgb - bg, axis=-1)
        fg = d_bg > 0.10
        sat = rgb.max(-1) - rgb.min(-1)
        for k, c in CLASSES.items():
            d = np.linalg.norm(rgb - np.array(c), axis=-1)
            m = (d < (0.10 if k != "belly" else 0.05)) & (fg if k != "belly" else (d_bg > 0.04))
            if k == "body":
                m = d < 0.12
            ys, xs = np.nonzero(m)
            if len(xs) < 20:
                out[k] = None
                continue
            # robust bbox: 0.3 / 99.7 percentiles
            out[k] = {"x": [int(np.percentile(xs, 0.3)) + x0, int(np.percentile(xs, 99.7)) + x0],
                      "y": [int(np.percentile(ys, 0.3)) + y0, int(np.percentile(ys, 99.7)) + y0], "n": int(len(xs))}
        # silhouette (rat only: coloured or dark; excludes the light grey floor shadow)
        sil = (sat > 0.12) | (rgb.max(-1) < 0.55)
        ys, xs = np.nonzero(sil)
        out["silhouette"] = {"x": [int(xs.min()) + x0, int(xs.max()) + x0], "y": [int(ys.min()) + y0, int(ys.max()) + y0]}
        # column profile (top/bottom of the silhouette every 10 px)
        prof = []
        for cx in range(0, x1 - x0, 10):
            col = np.nonzero(sil[:, cx])[0]
            prof.append([cx + x0, int(col.min()) + y0 if len(col) else None, int(col.max()) + y0 if len(col) else None])
        out["col_profile"] = prof
        res["bbox"][name] = out
    with open(os.path.join(OUT, "sheet02_measure.json"), "w") as fh:
        json.dump(res, fh, indent=1)
    print("SWATCH", res["swatch_hex"], "BG", res["bg_srgb"])
    for name, o in res["bbox"].items():
        print("PANEL", name, {k: (v if k != "col_profile" else "..") for k, v in o.items()})
    print("PANTRY_RAT_OK")


try:
    main()
except Exception:
    import traceback
    traceback.print_exc()
    print("PANTRY_RAT_FAIL")
    sys.exit(1)
