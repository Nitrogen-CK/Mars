"""Pantry Rat R02 - R5 review: the sheet-04/05/06/03 behaviour poses rendered from the baked clips beside the matching
sheet crops, and a BoundCycle / LoadedBound contact sheet beside the sheet-04 locomotion row.

  blender -b --factory-startup source/PantryRat_R02.blend --python scripts/pose_compare.py -- --out review/round_05

Writes <out>/poses/<shot>.png (render), <out>/pose_set.png (rows of sheet crop | render), <out>/boundcycle_contact.png
(sheet row on top; every frame of BoundCycle, then LoadedBound, side view, below), <out>/pose_shots.json.
Same palette materials / lights / sheet background as compare_sheet.py. Cameras here are framed per shot (poses
travel), not the fixed turnaround cameras.
"""
import json
import math
import os
import sys
import traceback

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import compare_sheet as cs  # noqa: E402  (helpers only; its main() does not run on import)
import rat_common as rc  # noqa: E402

ROOT = os.path.dirname(HERE)
DOCS = os.path.abspath(os.path.join(ROOT, "..", "..", "..", "..", "docs", "art", "pantry-rat-dens-production-r01"))
ARM, BODY = "PantryRat_R02_Armature", "PantryRat_R02_Body"

# shot: (sheet file, crop x0 y0 x1 y1 in sheet px, clip, frame, view az deg from the rat's right side toward its front,
#        elevation deg, mushroom shown)
SHOTS = [
    ("sniff", "04-curiosity-and-bound-poses.png", (25, 700, 365, 890), "SniffGround", 18, 35, 12, False),
    ("stretch_check", "04-curiosity-and-bound-poses.png", (370, 700, 765, 890), "StretchAttend", 15, 20, 10, False),
    ("rear_observe", "04-curiosity-and-bound-poses.png", (770, 690, 1095, 890), "RearObserve", 0, 30, 8, False),
    ("startle_backstep", "04-curiosity-and-bound-poses.png", (1105, 690, 1525, 890), "Startle", 9, 25, 10, False),
    ("loaded_bound", "05-claim-and-loaded-flee-poses.png", (15, 440, 510, 710), "LoadedBound", 6, 10, 6, True),
    ("brake_look_back", "05-claim-and-loaded-flee-poses.png", (520, 440, 1020, 710), "LoadedLookBack", 8, 30, 8, True),
    ("carry_mushroom", "03-rig-construction-and-eyes.png", (540, 520, 1030, 765), "LoadedIdle", 0, 8, 6, True),
    ("snatch", "05-claim-and-loaded-flee-poses.png", (1025, 90, 1520, 410), "Snatch", 8, 25, 8, True),
    ("topple", "06-weapon-hit-and-x-eyes.png", (940, 90, 1215, 345), "DeathToppleLeft", 16, 30, 12, False),
    ("dead_x_hold", "06-weapon-hit-and-x-eyes.png", (1030, 395, 1510, 700), "DeadHold", 0, 30, 15, False),
]
BOUND_ROW = ("04-curiosity-and-bound-poses.png", (370, 140, 1530, 300))


def crop(sheet, box):
    px = cs.load_px(os.path.join(DOCS, sheet))
    H, W = px.shape[:2]
    x0, y0, x1, y1 = box
    return px[y0:y1, x0:x1]


def setup():
    sc = bpy.context.scene
    for ob in bpy.data.objects:
        ob.hide_render = ob.name not in (ARM, BODY)
    w = sc.world or bpy.data.worlds.new("World")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (*rc.srgb_to_lin(cs.SHEET_BG), 1.0)
    bg.inputs["Strength"].default_value = 0.55
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.engine = "BLENDER_EEVEE"
    sc.eevee.taa_render_samples = 32
    sc.render.image_settings.file_format = "PNG"
    sc.render.film_transparent = False
    floor = cs.make_floor(sc)
    floor.scale = (4, 4, 1)
    cs.make_lights(sc)
    camd = bpy.data.cameras.new("PoseCam")
    cam = bpy.data.objects.new("PoseCam", camd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    return sc, cam, floor


def set_clip(arm, clip, frame):
    act = bpy.data.actions[clip]
    arm.animation_data_create()
    arm.animation_data.action = act
    try:
        if arm.animation_data.action_slot is None and len(act.slots):
            arm.animation_data.action_slot = act.slots[0]
    except AttributeError:
        pass
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()


def frame_cam(cam, pts, az, el, res, lens=50.0, margin=1.12):
    c = Vector((pts.max(axis=0) + pts.min(axis=0)) / 2)
    a, e = math.radians(az), math.radians(el)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    cam.data.type = "PERSP"
    cam.data.lens = lens
    cam.data.shift_x = cam.data.shift_y = 0.0
    cam.data.clip_start, cam.data.clip_end = 1.0, 5000.0
    r = float(np.linalg.norm(pts - np.array(c), axis=1).max())
    fov = 2 * math.atan(18.0 / lens) * min(1.0, res[1] / res[0])
    dist = r / math.sin(fov / 2) * margin
    sc = bpy.context.scene
    sub = [Vector(p) for p in pts[::7]]
    for _ in range(4):   # fill ~85 % of the frame: rescale the distance, recentre with the lens shift
        cs.look(cam, c + d * dist, c, (0, 0, 1))
        bpy.context.view_layer.update()
        uv = np.array([tuple(cs.world_to_camera_view(sc, cam, q))[:2] for q in sub])
        ext = max(uv[:, 0].max() - uv[:, 0].min(), uv[:, 1].max() - uv[:, 1].min())
        dist *= ext / 0.85
        cam.data.shift_x += ((uv[:, 0].max() + uv[:, 0].min()) / 2 - 0.5) * (1.0 if res[0] >= res[1] else res[0] / res[1])
        cam.data.shift_y += ((uv[:, 1].max() + uv[:, 1].min()) / 2 - 0.5) * (res[1] / res[0] if res[0] >= res[1] else 1.0)
    cs.look(cam, c + d * dist, c, (0, 0, 1))


def frame_side(cam, xmin, xmax, zmax, res):
    cam.data.type = "ORTHO"
    w = xmax - xmin
    cam.data.ortho_scale = max(w, zmax * res[0] / res[1]) * 1.08
    c = Vector(((xmin + xmax) / 2, 0, zmax / 2 - 2))
    cs.look(cam, c - Vector((0, 1, 0)) * 600, c, (0, 0, 1))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = os.path.abspath(argv[argv.index("--out") + 1]) if "--out" in argv else os.path.join(ROOT, "review", "round_05")
    os.makedirs(os.path.join(out, "poses"), exist_ok=True)
    sc, cam, floor = setup()
    arm, body = bpy.data.objects[ARM], bpy.data.objects[BODY]
    mush = bpy.data.objects.get("Mushroom_Carry")
    rows, info = [], {}
    for name, sheet, box, clip, f, az, el, show_mush in SHOTS:
        set_clip(arm, clip, f)
        if mush:
            mush.hide_render = not show_mush
        pts = rc.evaluated_tris(body)[0]
        if show_mush and mush:
            pts = np.concatenate([pts, rc.evaluated_tris(mush)[0]])
        cr = crop(sheet, box)
        res = (int(cr.shape[1] * 2), int(cr.shape[0] * 2))
        sc.render.resolution_x, sc.render.resolution_y = res
        frame_cam(cam, pts, az, el, res)
        path = os.path.join(out, "poses", name + ".png")
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        rows.append([cs.upsample(cr, 2), cs.load_px(path)])
        info[name] = {"sheet": sheet, "crop": box, "clip": clip, "frame": f, "view_az_el": [az, el],
                      "mushroom": show_mush, "render": os.path.relpath(path, ROOT).replace("\\", "/")}
    cs.save_px(cs.sheet(rows, 700, 420), os.path.join(out, "pose_set.png"))
    # bound contact sheets (side view, fixed ortho camera per clip; the body travels on the `body` bone only)
    if mush:
        mush.hide_render = True
    strips = [[cs.upsample(crop(*BOUND_ROW), 1)]]
    for clip, mushroom in (("BoundCycle", False), ("LoadedBound", True)):
        act = bpy.data.actions[clip]
        n = int(round(act.frame_range[1]))
        if mush:
            mush.hide_render = not mushroom
        allp = []
        for f in range(n + 1):
            set_clip(arm, clip, f)
            allp.append(rc.evaluated_tris(body)[0])
        allp = np.concatenate(allp)
        res = (520, 300)
        sc.render.resolution_x, sc.render.resolution_y = res
        tiles = []
        for f in range(n + 1):
            set_clip(arm, clip, f)
            frame_side(cam, float(allp[:, 0].min()) - 4, float(allp[:, 0].max()) + 12, float(allp[:, 2].max()) + 4, res)
            path = os.path.join(out, "poses", "%s_f%02d.png" % (clip, f))
            sc.render.filepath = path
            bpy.ops.render.render(write_still=True)
            tiles.append(cs.load_px(path))
        cols = 7
        for k in range(0, len(tiles), cols):
            strips.append(tiles[k:k + cols])
        info[clip + "_contact"] = {"frames": n + 1, "view": "side ortho, fixed per clip"}
    # the sheet row is one wide tile; frame strips are 7 per row
    W = 7 * 360 + 6 * 6
    top = cs.fit(strips[0][0], W, 230)
    body_rows = cs.sheet(strips[1:], 360, 208)
    canvas = np.full((230 + 6 + body_rows.shape[0], max(W, body_rows.shape[1]), 4), 0.18, dtype=np.float32)
    canvas[..., 3] = 1
    canvas[:230, :W] = top
    canvas[236:236 + body_rows.shape[0], :body_rows.shape[1]] = body_rows
    cs.save_px(canvas, os.path.join(out, "boundcycle_contact.png"))
    with open(os.path.join(out, "pose_shots.json"), "w") as fh:
        json.dump(info, fh, indent=1)
    print("PANTRY_RAT_OK")


try:
    main()
except Exception:
    traceback.print_exc()
    print("PANTRY_RAT_FAIL")
    sys.exit(1)
