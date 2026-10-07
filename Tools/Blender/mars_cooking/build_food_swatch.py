"""The vertex-colour calibration swatch for the food lookdev map. Re-runnable headless:

    blender -b --factory-startup --python build_food_swatch.py -- [--export] [--sheets]

ColorSwatch_Mars_SM  a 15 x 3 x 1 cm bar of five slabs painted (linear) 18 % grey, 50 % grey, red, green, blue with
                     no facet jitter and no cavity darkening. mars_food_ue places it next to engine planes of known
                     grey; the capture shows whether the Unreal master's "Vertex Colour sRGB" switch is right.
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import food_common as fc  # noqa: E402

spec = fc.spec
PATCHES = ((0.18, 0.18, 0.18), (0.5, 0.5, 0.5), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))
PATCH_W, DEPTH, HEIGHT = 3.0, 3.0, 1.0


def _box(x0, x1, y0, y1, z0, z1):
    v = np.array([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                  (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], float)
    f = [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
    return v, f


def build():
    parts, colors = [], []
    x = -PATCH_W * len(PATCHES) * 0.5
    for rgb in PATCHES:
        v, f = _box(x, x + PATCH_W, -DEPTH * 0.5, DEPTH * 0.5, 0.0, HEIGHT)
        parts.append((v, f, 0))
        colors.extend([rgb] * len(f))
        x += PATCH_W
    verts, faces, slots = fc.merge(parts)
    obj = fc.new_object("ColorSwatch_Mars_SM", verts, faces, slots=("Stone",), face_slots=slots)
    fc.paint(obj, np.array(colors), alpha=np.ones(len(obj.data.vertices)), variation=0.0, cavity_darken=0.0)
    fc.smart_uv(obj)
    return obj


def main():
    args = fc.cli_args({"export": False, "sheets": False})
    fc.ensure_dirs()
    fc.clear_scene()
    obj = build()
    if args["export"]:
        fbx = fc.export_fbx(obj, extra={"patches_linear": [list(p) for p in PATCHES]})
        print("REIMPORT", fc.reimport_check(fbx))
    if args["sheets"]:
        print("sheet", fc.review_sheet([obj], "ColorSwatch", views=("iso", "top")))
    print("FOOD_SWATCH_OK")


main()
