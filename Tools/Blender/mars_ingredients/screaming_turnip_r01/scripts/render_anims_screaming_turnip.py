"""Screaming Turnip R01 - Phase B clip renders from source/ScreamingTurnip_R01.blend (after animate_screaming_turnip.py).

Per clip (export/anims/clips.json): 8 frames evenly spaced over 0..N, front row + three-quarter row, 10 cm rulers,
EEVEE neutral three-light rig -> review/phaseB/clips/<Clip>_sheet.png (SRC_* clips show TurnipBed_R01 at the soil line).
Plus review/phaseB/clips/cycle_sheet.png: the chained vocal cycle QuietIdle -> Anticipate -> Inhale -> Scream ->
Recover -> RecoveryIdle sampled at 6 fps (every 5th frame; each clip's last frame is the next clip's frame 0),
front view, plus a three-quarter strip of the same frames.
--tag rNN copies the written sheets to review/phaseB3/iterations/rNN_<sheet>.png.
Phase B4: writes under review/phaseB4/clips/ (framing x unit(), see render_screaming_turnip). Phase B3:; each clip plays its armature action AND its Key action `<Clip>_Key`
(shape keys Inhale / Scream). Plus review/phaseB3/clips/shapekey_sheet.png: bones at rest, Inhale 0 / 0.5 / 1 and
Scream 0 / 0.5 / 1 (front, three-quarter, mouth close-up rows). --shapekey-only renders only that sheet.

Run (from the screaming_turnip_r01 folder):
  "$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/render_anims_screaming_turnip.py -- \
      [--clips A,B] [--no-cycle] [--res 300] [--tag rNN]
Phase I: [--out phaseI] writes under review/<out>/ (default review/phaseB4/clips/); [--views front,side,threequarter]
picks the clip-sheet rows; [--pull-chain] adds review/<out>/pull_chain_sheet.png (rows: SRC_Idle f0 -> SRC_Grip ->
SRC_Tug -> SRC_Release, then the same -> SRC_Cancel; side and three-quarter views each).
Phase J: [--ortho 34 --target -7,0,8.5] (design-frame units, x unit()) widen and re-centre the clip-sheet and pull-chain
framing so the 36 cm lean toward -X stays in frame (defaults: each view's own framing).
Phase K: [--inject-stretch T,L] poses SRC_Tug / SRC_Cancel from the authored spline plus the runtime crown offset
(-T * a, 0, L * a) UE cm (a = f / 15 on the Tug, 1 - f / 7 on the Cancel), as the bed's anim blueprint shows them; the
other clips play their actions.
Prints TURNIP_OK / TURNIP_FAIL.
"""
import json
import os
import shutil
import sys
import traceback

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import build_screaming_turnip as BT  # noqa: E402
import render_screaming_turnip as R  # noqa: E402

ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "review", "phaseB4", "clips")
ITER = os.path.join(ROOT, "review", "phaseB4", "iterations")
CYCLE = ("ROOT_QuietIdle", "ROOT_Anticipate", "ROOT_Inhale", "ROOT_Scream", "ROOT_Recover", "ROOT_RecoveryIdle")


def _assign(idb, act):
    ad = idb.animation_data or idb.animation_data_create()
    ad.action = act
    if act is not None and getattr(ad, "action_slot", None) is None and len(getattr(act, "slots", [])):
        ad.action_slot = act.slots[0]


def use(arm, act):
    _assign(arm, act)
    key = bpy.data.objects[BT.MESH_NAME].data.shape_keys
    kact = bpy.data.actions.get(act.name + "_Key") if act is not None else None
    if act is not None and kact is None:
        raise RuntimeError("no Key action for %s" % act.name)
    _assign(key, kact)
    if kact is None:
        for kb in key.key_blocks[1:]:
            kb.value = 0.0


def shapekey_sheet(sc, cam, arm, tmp):
    """Bones at rest; Inhale 0 / 0.5 / 1, Scream 0 / 0.5 / 1; rows front / three-quarter / mouth close-up."""
    use(arm, None)
    BT.apply_params(arm, BT.NEUTRAL)
    body = bpy.data.objects[BT.MESH_NAME]
    kb = body.data.shape_keys.key_blocks
    co = BT.turnip_audit.evaluated(body)[0]
    from mathutils import Vector
    tgt = Vector((0.0, 0.0, float(co[list(body["mouth_centre_l0"])].mean(0)[2])))
    cols = [("Inhale", 0.0), ("Inhale", 0.5), ("Inhale", 1.0), ("Scream", 0.0), ("Scream", 0.5), ("Scream", 1.0)]
    tiles = []
    for view in ("front", "threequarter", "mouth"):
        for nm, v in cols:
            for k in kb[1:]:
                k.value = 0.0
            kb[nm].value = v
            bpy.context.view_layer.update()
            tiles.append(R.shot(sc, cam, os.path.join(tmp, "sk_%s_%s_%03d.png" % (view, nm, int(v * 100))), view,
                                "%s %.1f (bones rest) %s" % (nm, v, view), tgt if view == "mouth" else None,
                                ortho_override=11.0 if view == "mouth" else None))
    for k in kb[1:]:
        k.value = 0.0
    return R.save_sheet(tiles, len(cols), os.path.join(OUT, "shapekey_sheet.png"))


INJ = {"SRC_Tug": (15, lambda f: f / 15.0), "SRC_Cancel": (7, lambda f: 1.0 - f / 7.0)}


def pose_frame(sc, arm, name, f, inject):
    """Phase K: set the frame; with --inject-stretch, the Tug / Cancel pose is the spline + the runtime crown offset."""
    if inject is None or name not in INJ:
        use(arm, bpy.data.actions[name])
        sc.frame_set(f)
        return
    import animate_screaming_turnip as A
    from mathutils import Matrix, Vector
    use(arm, None)
    clip = {c.name: c for c in A.build_clips(BT.unit(arm))}[name]
    a = INJ[name][1](f)
    BT.apply_params(arm, clip.sample(float(f)))
    pb = arm.pose.bones["crown"]
    pb.matrix = Matrix.Translation(Vector((-inject[0] * a, 0.0, inject[1] * a))) @ pb.matrix
    bpy.context.view_layer.update()


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    inject = tuple(float(x) for x in argv[argv.index("--inject-stretch") + 1].split(",")) \
        if "--inject-stretch" in argv else None
    arg = lambda k, d=None: argv[argv.index(k) + 1] if k in argv else d
    res = int(arg("--res", "300"))
    tag = arg("--tag")
    clips = json.load(open(os.path.join(ROOT, "export", "anims", "clips.json")))
    global OUT, ITER
    if arg("--out"):
        OUT = ITER = os.path.join(ROOT, "review", arg("--out"))
    views = tuple(arg("--views", "front,threequarter").split(","))
    ortho_o = float(arg("--ortho")) if arg("--ortho") else None                     # Phase J framing override
    from mathutils import Vector
    tgt_o = Vector([float(x) * BT.unit(bpy.data.objects[BT.ARM_NAME]) for x in arg("--target").split(",")])         if arg("--target") else None
    only = arg("--clips")
    names = only.split(",") if only else list(clips)
    sc = bpy.context.scene
    R.setup(sc, res)
    arm = bpy.data.objects[BT.ARM_NAME]
    arm.hide_render = True
    arm.animation_data_create()
    cam = bpy.data.objects["ReviewCam"]
    sc.camera = cam
    bed = bpy.data.objects[BT.BED_NAME]
    for n in (BT.BED_NAME, BT.BED_EMPTY_NAME, BT.COLL_NAME):
        bpy.data.objects[n].hide_render = True
    written = []
    tmp = os.path.join(OUT, "_frames")
    if "--no-shapekey" not in argv:
        written.append(shapekey_sheet(sc, cam, arm, tmp))
        print("SHEET", written[-1])
    if "--shapekey-only" in argv:
        names = []
    for name in names:
        info = clips[name]
        n = info["frames"][1]
        frames = sorted({round(i * n / 7.0) for i in range(8)})
        use(arm, bpy.data.actions[name])
        bed.hide_render = not name.startswith("SRC_")
        tiles = []
        for view in views:
            for f in frames:
                pose_frame(sc, arm, name, f, inject)
                tiles.append(R.shot(sc, cam, os.path.join(tmp, "%s_%s_%03d.png" % (name, view, f)), view,
                                    "%s f%d/%d %s" % (name, f, n, view), tgt_o, ortho_o))
        written.append(R.save_sheet(tiles, len(frames), os.path.join(OUT, "%s_sheet.png" % name)))
        print("SHEET", written[-1])
    if "--pull-chain" in argv:
        head = [("SRC_Idle", 0), ("SRC_Grip", 3), ("SRC_Tug", 0), ("SRC_Tug", 4), ("SRC_Tug", 8), ("SRC_Tug", 12),
                ("SRC_Tug", 15)]
        strips = [head + [("SRC_Release", 2), ("SRC_Release", 4), ("SRC_Release", 6)],
                  head + [("SRC_Cancel", 2), ("SRC_Cancel", 4), ("SRC_Cancel", 7)]]
        bed.hide_render = False
        tiles = []
        for si, seq in enumerate(strips):
            for view in ("side", "threequarter"):
                for name, f in seq:
                    pose_frame(sc, arm, name, f, inject)
                    tiles.append(R.shot(sc, cam, os.path.join(tmp, "pull_%d_%s_%s_%03d.png" % (si, view, name, f)), view,
                                        "%s f%d %s" % (name.replace("SRC_", ""), f, view), tgt_o, ortho_o))
        written.append(R.save_sheet(tiles, len(strips[0]), os.path.join(OUT, "pull_chain_sheet.png")))
        print("SHEET", written[-1], len(tiles), "frames")
    bed.hide_render = True
    if "--no-cycle" not in argv and not only and "--shapekey-only" not in argv:
        seq = []
        for k, name in enumerate(CYCLE):
            n = clips[name]["frames"][1]
            last = k == len(CYCLE) - 1
            for f in range(0, n + (1 if last else 0), 5):
                seq.append((name, f))
        for view in ("front", "threequarter"):
            tiles = []
            for name, f in seq:
                use(arm, bpy.data.actions[name])
                sc.frame_set(f)
                tiles.append(R.shot(sc, cam, os.path.join(tmp, "cycle_%s_%s_%03d.png" % (view, name, f)), view,
                                    "%s f%d" % (name.replace("ROOT_", ""), f)))
            written.append(R.save_sheet(tiles, 9, os.path.join(OUT, "cycle_sheet.png" if view == "front" else "cycle_sheet_%s.png" % view)))
            print("SHEET", written[-1], len(tiles), "frames")
    use(arm, None)
    if tag:
        os.makedirs(ITER, exist_ok=True)
        for p in written:
            shutil.copyfile(p, os.path.join(ITER, "%s_%s" % (tag, os.path.basename(p))))
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
