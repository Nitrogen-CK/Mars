"""Screaming Turnip R01 - Phase B2b shape-key route proof (export side).

Opens source/ScreamingTurnip_R01.blend (builder output, shape keys `Inhale` and `Scream` on the body), keys ONE shape key
(default `Scream`) 0 -> 1 -> 0 over frames 0..10 (peak at frame 5, linear), bones at rest on every frame, and exports it
with the Phase B clip recipe (export_screaming_turnip.CLIP verbatim: bake_anim, all bones, no NLA, one action, force
start/end keys, step 1, simplify 0, use_mesh_modifiers False) EXCEPT use_triangles=False (see main) to
  export/validation/ScreamingTurnip_R01_ShapeKeyTest_Mars_ANIM.fbx        (the single test clip; Phase C does not read it)
and the readback expectations to
  review/phaseB2b/shapekey_test_expected.json   (key value per frame, evaluated vertex positions at frames 0 / 5 / 10)
The armature object is renamed `Armature` for the export and renamed back; the .blend is never saved.
validate_roundtrip.py --shapekey-test re-imports the clip in a fresh scene and checks it.

Run (from the screaming_turnip_r01 folder):
  "$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/shapekey_test_screaming_turnip.py [-- --key Scream]
Prints TURNIP_OK / TURNIP_FAIL.
"""
import json
import os
import sys
import traceback

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import build_screaming_turnip as BT  # noqa: E402
import export_screaming_turnip as EX  # noqa: E402

ROOT = os.path.dirname(HERE)
FBX = os.path.join(ROOT, "export", "validation", "ScreamingTurnip_R01_ShapeKeyTest_Mars_ANIM.fbx")
EXPECT = os.path.join(ROOT, "review", "phaseB2b", "shapekey_test_expected.json")
FRAMES = (0, 10)
PEAK = 5


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    key = argv[argv.index("--key") + 1] if "--key" in argv else "Scream"
    # The Phase B recipe has use_triangles=True; with it the exporter converts the mesh to a temporary copy whose Key
    # is not animated, so every baked shape-key value is the copy's static value (0.0) - measured, see PROGRESS B2b.
    # The mesh is already all triangles (builder `triangulate`), so use_triangles=False writes the same polygons and
    # exports the original mesh, whose Key the bake samples. --recipe-verbatim reproduces the failing export.
    clip = dict(EX.CLIP) if "--recipe-verbatim" in argv else dict(EX.CLIP, use_triangles=False)
    sc = bpy.context.scene
    arm = bpy.data.objects[BT.ARM_NAME]
    body = bpy.data.objects[BT.MESH_NAME]
    sk = body.data.shape_keys
    if sk is None or key not in sk.key_blocks:
        print("TURNIP_FAIL no shape key %s" % key)
        sys.exit(1)
    names = [kb.name for kb in sk.key_blocks]
    BT.apply_params(arm, BT.NEUTRAL)
    for kb in sk.key_blocks:
        kb.value = 0.0
    # bones: rest on every frame (one action on the armature, as every clip has)
    arm.animation_data_create()
    act = bpy.data.actions.new("ScreamingTurnip_R01_ShapeKeyTest")
    arm.animation_data.action = act
    if getattr(arm.animation_data, "action_slot", None) is None and len(getattr(act, "slots", [])):
        arm.animation_data.action_slot = act.slots[0]
    for f in range(FRAMES[0], FRAMES[1] + 1):
        BT.key_pose(arm, f)
    # the shape key: 0 at 0, 1 at PEAK, 0 at 10, linear
    kb = sk.key_blocks[key]
    for f, v in ((FRAMES[0], 0.0), (PEAK, 1.0), (FRAMES[1], 0.0)):
        kb.value = v
        kb.keyframe_insert("value", frame=f)
    try:
        for layer in sk.animation_data.action.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    for fc in cb.fcurves:
                        for k in fc.keyframe_points:
                            k.interpolation = "LINEAR"
    except AttributeError:
        for fc in sk.animation_data.action.fcurves:
            for k in fc.keyframe_points:
                k.interpolation = "LINEAR"
    sc.frame_start, sc.frame_end = FRAMES
    exp = {"file": os.path.relpath(FBX, ROOT).replace("\\", "/"), "key": key, "shape_keys": names,
           "frames": list(range(FRAMES[0], FRAMES[1] + 1)), "peak": PEAK, "value": {}, "verts": {}}
    for f in range(FRAMES[0], FRAMES[1] + 1):
        sc.frame_set(f)
        exp["value"][str(f)] = round(float(kb.value), 6)
        if f in (FRAMES[0], PEAK, FRAMES[1]):
            co = BT.turnip_audit.evaluated(body)[0]
            exp["verts"][str(f)] = {"bounds": [co.min(0).round(4).tolist(), co.max(0).round(4).tolist()],
                                    "co": co.round(5).tolist()}
    # export: the Phase B clip recipe verbatim
    os.makedirs(os.path.dirname(FBX), exist_ok=True)
    old = arm.name
    arm.name = "Armature"
    try:
        EX.select_only([arm, body])
        if any(len(p.vertices) != 3 for p in body.data.polygons):
            raise RuntimeError("body mesh is not all triangles: use_triangles=False would change the polygons")
        bpy.ops.export_scene.fbx(filepath=FBX, **clip)
    finally:
        arm.name = old
    exp["export_settings"] = EX.jsonable(clip)
    exp["fbx_header"] = EX.fbx_header(FBX)
    exp["bytes"] = os.path.getsize(FBX)
    with open(EXPECT, "w") as fh:
        json.dump(exp, fh)
    print("SHAPEKEY_EXPORT", json.dumps({"file": exp["file"], "bytes": exp["bytes"], "key": key, "keys": names,
                                         "value": exp["value"], "header": exp["fbx_header"]}))
    print("TURNIP_OK")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        print("TURNIP_FAIL exception")
        sys.exit(1)
