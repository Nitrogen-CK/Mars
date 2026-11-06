"""Cellar Bat R01 - Phase 4 motion review renders (the BAKED export actions, rig constraints muted, i.e. exactly what
the clip FBX carries).

For every clip (default: all 18) into review/phase4/:
  _tiles/<Clip>_<view>_<frame>.png   contact-sheet tiles: views front / side / three-quarter / top at up to 8 frames
                                     (always 0 and N, plus markers/keys spread between)
  <Clip>/frame_###.png               real-time sequence, three-quarter view, every frame 0..N (30 fps)
  <Clip>_half/frame_###.png          half-speed sequence (steps of 0.5 frame) for Hover, Launch, Perch, Swoop, RoostIdle
The sheets themselves (`<Clip>_sheet.png`, labelled) and the review strips (`<Clip>_strip.png`) are composed by
sheets_phase4.py (Pillow) from these tiles/frames.
Fixed camera per view for every clip (the root never moves, so any drift would show). The perch bar is shown for
RoostIdle, RoostAlert, Launch and Perch.

Run:
  blender -b --factory-startup source/CellarBat_R01.blend --python scripts/render_anims_cellar_bat.py -- \
      [--clips A,B] [--no-seq] [--no-sheet] [--res 400x300]
Prints CELLAR_BAT_OK / CELLAR_BAT_FAIL.
"""
import json
import os
import sys
import traceback

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import bat_rig  # noqa: E402
import render_cellar_bat as R  # noqa: E402

ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "review", "phase4")
TILES = os.path.join(OUT, "_tiles")
ARM = "CellarBat_R01_Armature"
HALF = ("Hover", "Launch", "Perch", "Swoop", "RoostIdle")
PERCH_CLIPS = ("RoostIdle", "RoostAlert", "Launch", "Perch")
TGT = Vector((0.0, 0.0, 2.0))
VIEWS = {  # name: (eye direction, up, ortho scale or None, lens)
    "front": ((1, 0, 0.05), (0, 0, 1), 104.0, None),
    "side": ((0.0, 1, 0.05), (0, 0, 1), 104.0, None),
    "tq": ((1, -0.8, 0.45), (0, 0, 1), None, 105.0),
    "top": ((0.02, 0, 1), (1, 0, 0), 104.0, None),
}
SEQ_VIEW = "tq"


def pick_frames(n, markers, keys, k=8):
    if n == 0:
        return [0]
    want = {0, n} | {int(v) for v in markers.values()}
    cand = sorted(set(int(x) for x in keys) | want)
    while len(cand) > k:          # drop the key nearest its neighbour (never 0, N or a marker)
        best, bi = None, None
        for i in range(1, len(cand) - 1):
            if cand[i] in want:
                continue
            gap = min(cand[i] - cand[i - 1], cand[i + 1] - cand[i])
            if best is None or gap < best:
                best, bi = gap, i
        if bi is None:
            break
        cand.pop(bi)
    i = 0
    while len(cand) < min(k, n + 1):  # fill the widest gaps
        gaps = [(cand[j + 1] - cand[j], j) for j in range(len(cand) - 1)]
        g, j = max(gaps)
        if g < 2:
            break
        cand.insert(j + 1, cand[j] + g // 2)
        i += 1
    return cand


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    clips_info = json.load(open(os.path.join(ROOT, "export", "anims", "clips.json")))
    only = argv[argv.index("--clips") + 1].split(",") if "--clips" in argv else list(clips_info)
    res = argv[argv.index("--res") + 1] if "--res" in argv else "400x300"
    rw, rh = (int(x) for x in res.split("x"))
    do_seq, do_sheet = "--no-seq" not in argv, "--no-sheet" not in argv
    sc = bpy.context.scene
    R.setup_world(sc)
    R.make_lights()
    R.engine(sc, "eevee")
    sc.eevee.taa_render_samples = 16
    sc.render.image_settings.file_format = "PNG"
    sc.render.resolution_x, sc.render.resolution_y = rw, rh
    sc.render.resolution_percentage = 100
    sc.render.fps, sc.render.fps_base = 30, 1.0
    cam = bpy.data.objects["ReviewCam"]
    ctrl = bpy.data.objects[bat_rig.CTRL_NAME]
    ctrl.hide_render = True
    arm = bpy.data.objects[ARM]
    arm.hide_render = True
    R.show_lod(0)
    bat_rig.use_action(ctrl, None, 0)
    bat_rig.reset(ctrl)
    bat_rig.mute(arm, True)
    arm.animation_data_create()
    done = []
    for name in only:
        info = clips_info[name]
        act = bpy.data.actions[info["export_action"]]
        arm.animation_data.action = act
        if arm.animation_data.action_slot is None and len(act.slots):
            arm.animation_data.action_slot = act.slots[0]
        R.review(("PerchBar",) if name in PERCH_CLIPS else ())
        n = info["frames"][1]

        def shot(view, f, path):
            d, up, ortho, lens = VIEWS[view]
            fi = int(f)
            sc.frame_set(fi, subframe=float(f) - fi)
            R.shot(sc, cam, path, R.view_eye(d, 300.0, TGT), TGT, Vector(up), ortho=ortho, lens=lens or 50.0)

        if do_sheet:
            frames = pick_frames(n, info.get("markers", {}), info.get("keys", []))
            for v in VIEWS:
                for f in frames:
                    shot(v, f, os.path.join(TILES, "%s_%s_%03d.png" % (name, v, f)))
            with open(os.path.join(TILES, "%s_frames.json" % name), "w") as fh:
                json.dump({"frames": frames, "views": list(VIEWS)}, fh)
        if do_seq:
            d = os.path.join(OUT, name)
            os.makedirs(d, exist_ok=True)
            for f in range(n + 1):
                shot(SEQ_VIEW, f, os.path.join(d, "frame_%03d.png" % f))
            if name in HALF:
                d = os.path.join(OUT, name + "_half")
                os.makedirs(d, exist_ok=True)
                for i in range(2 * n + 1):
                    shot(SEQ_VIEW, i * 0.5, os.path.join(d, "frame_%03d.png" % i))
        done.append(name)
        print("RENDERED", name)
    arm.animation_data.action = None
    print("CELLAR_BAT_OK", done)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        print("CELLAR_BAT_FAIL exception")
        sys.exit(1)
