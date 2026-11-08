"""Pantry Rat R02 (copied from ../pantry_rat_r01/scripts/dither_uv_pantry_rat.py; R01 -> R02 names / paths, R02 review folders) - Phase 2 source fix: UV0 of every NON-EyePatch face becomes a dense box projection of the rest pose
(DITHER_CM_PER_UV cm per UV unit), so the BusterBlock dither CkUsf_IGN(UV * 512) < FadeAlpha reads as a fine per-pixel
speckle instead of the diagonal stripes the Phase 1 lightmap-packed UV0 produced (first Unreal capture,
review/phase2/unreal/iterations/close_Alpha05_with_mushroom_r01.png: each face's UV island was ~1/50 of the sheet, so
UV*512 advanced < 1 noise cell per screen pixel and IGN's linear structure showed as bands). The body slots are flat
colours; nothing else samples their UV0. EyePatch faces keep their Phase 1 UVs (U 0..0.5 = LEFT eye, 0.5..1 = RIGHT).

Run after build_pantry_rat.py (it saves the source) and before animate/export:
  blender -b --factory-startup source/PantryRat_R02.blend --python scripts/dither_uv_pantry_rat.py
Prints PANTRY_RAT_OK / PANTRY_RAT_FAIL <reason>.
"""
import json
import os
import sys
import traceback

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BLEND = os.path.join(ROOT, "source", "PantryRat_R02.blend")
MESH_NAME = "PantryRat_R02_Body"
DITHER_CM_PER_UV = 24.0        # 512 / 24 = 21 IGN cells per cm: >= 1 cell per pixel up to ~20 px/cm close-ups
AXIS_OFFSET = {0: (0.37, 0.11), 1: (0.73, 0.59), 2: (0.19, 0.83)}   # de-correlates the three projections


def main():
    ob = bpy.data.objects[MESH_NAME]
    me = ob.data
    uvl = me.uv_layers.get("UV0")
    if uvl is None:
        raise RuntimeError("no UV0")
    eye_idx = [i for i, m in enumerate(me.materials) if m and m.name == "EyePatch"]
    if len(eye_idx) != 1:
        raise RuntimeError("EyePatch slot %s" % eye_idx)
    eye = eye_idx[0]
    before = np.array([d.uv[:] for d in uvl.data])
    changed, kept = 0, 0
    for p in me.polygons:
        if p.material_index == eye:
            kept += 1
            continue
        n = p.normal
        ax = int(np.argmax(np.abs(np.array(n))))
        a, b = [(1, 2), (0, 2), (0, 1)][ax]
        oa, ob_ = AXIS_OFFSET[ax]
        for li in p.loop_indices:
            v = me.vertices[me.loops[li].vertex_index].co
            uvl.data[li].uv = (v[a] / DITHER_CM_PER_UV + oa, v[b] / DITHER_CM_PER_UV + ob_)
        changed += 1
    after = np.array([d.uv[:] for d in uvl.data])
    eye_loops = [li for p in me.polygons if p.material_index == eye for li in p.loop_indices]
    eye_same = bool(np.allclose(before[eye_loops], after[eye_loops]))
    rep = {"faces_reprojected": changed, "eyepatch_faces_kept": kept, "eyepatch_uv_unchanged": eye_same,
           "cm_per_uv": DITHER_CM_PER_UV, "ign_cells_per_cm": round(512.0 / DITHER_CM_PER_UV, 3),
           "uv_range_after": [after.min(0).round(3).tolist(), after.max(0).round(3).tolist()],
           "uv_range_before": [before.min(0).round(3).tolist(), before.max(0).round(3).tolist()]}
    print("DITHER_UV", json.dumps(rep))
    out = os.path.join(ROOT, "review", "round_06", "dither_uv_report.json")
    with open(out, "w") as fh:
        json.dump(rep, fh, indent=1)
    if not eye_same:
        print("PANTRY_RAT_FAIL eyepatch UVs changed")
        sys.exit(1)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=False)
    print("PANTRY_RAT_OK")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        print("PANTRY_RAT_FAIL exception")
        sys.exit(1)
