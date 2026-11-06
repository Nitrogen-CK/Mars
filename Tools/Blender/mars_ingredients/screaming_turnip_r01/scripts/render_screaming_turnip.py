"""Screaming Turnip R01 - Phase A review renders from source/ScreamingTurnip_R01.blend.

Poses come from build_screaming_turnip.POSES applied to the export bones (one source of truth). Per pose writes
review/phaseA/<pose>/<pose>_{front,side,threequarter,mouth}.png (EEVEE, neutral key/fill/rim on a sheet-beige
background, 10 cm rulers in 1 cm alternating segments placed beside the turnip in every view) and the contact sheet
review/phaseA/<pose>/<pose>_sheet.png (front | side | three-quarter | mouth close-up). Also
review/phaseA/poses_overview.png (rows = poses, columns = front, three-quarter) and, with --planted,
review/phaseA/planted/planted_{front,threequarter}.png (neutral turnip in TurnipBed_R01, plus TurnipBedEmpty_R01).
--tag rNN copies every written sheet to review/phaseA/iterations/rNN_<sheet>.png.

Phase B4: the asset is SCALE (3.0) x the design frame. Framing (targets, ortho scales, camera distance, ruler offsets)
multiplies by U = build_screaming_turnip.unit() read off the opened blend (1.0 on a design-frame blend), so the
sheets frame the same; the rulers stay 10 cm (a length reference). The first-person mock keeps its 45 cm hand distance
and 90 deg FOV (a world fact, not scaled) and reports the turnip's frame fraction (--fp writes fp_mock/fp_fraction.json).

Run (from the screaming_turnip_r01 folder):
  "$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/render_screaming_turnip.py -- \
      [--poses neutral,scream] [--tag r01] [--planted] [--res 560]
Prints TURNIP_OK / TURNIP_FAIL.
"""
import math
import os
import shutil
import sys
import traceback

import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import build_screaming_turnip as BT  # noqa: E402

ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "review", "phaseB4")
ITER = os.path.join(OUT, "iterations")
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
BG = (0.93, 0.89, 0.83)     # linear-ish beige close to the production sheets
U = [1.0]                   # B4: design -> world length factor of the opened blend (set in setup())


def nrm(v):
    return Vector(v).normalized()


def look(cam, eye, target, up=Z):
    eye, target, up = Vector(eye), Vector(target), Vector(up)
    zc = nrm(eye - target)
    xc = nrm(up.cross(zc))
    yc = zc.cross(xc)
    m = Matrix((xc, yc, zc)).transposed().to_4x4()
    m.translation = eye
    cam.matrix_world = m


LIGHTS = {}
RIGS = {
    # EEVEE three-light review rig: warm key / neutral fill / rim
    "neutral": {"Key": ((1.0, 0.92, 0.82), 3.6, 14.0, (-0.75, 0.75, 0.55)),
                "Fill": ((0.95, 0.96, 1.0), 0.7, 50.0, (0.9, 0.1, 0.6)),
                "Rim": ((1.0, 0.97, 0.92), 2.4, 10.0, (0.3, 0.7, -0.9))},
    # game lighting: amber key (lantern / torch) and teal fill (cellar ambient), cool rim
    "game": {"Key": ((1.0, 0.62, 0.30), 3.6, 14.0, (-0.75, 0.75, 0.55)),
             "Fill": ((0.30, 0.68, 0.74), 1.5, 50.0, (0.9, 0.1, 0.6)),
             "Rim": ((0.75, 0.9, 1.0), 1.8, 10.0, (0.3, 0.7, -0.9))},
}
RIG = dict(RIGS["neutral"])


def setup(scene, res):
    U[0] = BT.unit()
    print("RENDER_UNIT", U[0])
    w = scene.world or bpy.data.worlds.new("World")
    scene.world = w
    w.use_nodes = True
    bgn = w.node_tree.nodes.get("Background")
    bgn.inputs["Color"].default_value = (*BG, 1.0)
    bgn.inputs["Strength"].default_value = 0.25
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 32
    scene.eevee.use_shadows = True
    scene.render.resolution_x = scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    for n in RIG:
        ld = bpy.data.lights.new("Review" + n, "SUN")
        ob = bpy.data.objects.new("Review" + n, ld)
        bpy.data.collections["Review"].objects.link(ob)
        LIGHTS[n] = ob


def place_lights(cam):
    m = cam.matrix_world.to_3x3()
    right, up, back = m.col[0], m.col[1], m.col[2]
    for n, ob in LIGHTS.items():
        col, st, ang, (a, b, c) = RIG[n]
        to_light = (right * a + up * b + back * c).normalized()
        ob.data.color = col
        ob.data.energy = st
        ob.data.angle = math.radians(ang)
        ob.rotation_euler = to_light.to_track_quat("Z", "Y").to_euler()


def place_review(cam, ortho, label, ruler_base):
    """Vertical 10 cm ruler at the camera's right of the subject, horizontal one under it; label bottom-left."""
    m = cam.matrix_world.to_3x3()
    right = Vector(m.col[0])
    right.z = 0
    right = right.normalized()
    rv = bpy.data.objects["Ruler_10cm_V"]
    rh = bpy.data.objects["Ruler_10cm_H"]
    rv.matrix_world = Matrix.Translation(ruler_base + right * 7.5 * U[0]) @ \
        right.to_track_quat("X", "Z").to_matrix().to_4x4()
    # horizontal: rotate the Z-built ruler so it runs along `right`
    rot = Z.rotation_difference(right).to_matrix().to_4x4()
    rh.matrix_world = Matrix.Translation(ruler_base - right * 5.0 + Vector((0, 0, -0.8 * U[0]))) @ rot
    txt = bpy.data.objects["Label"]
    txt.data.body = label
    txt.data.size = ortho * 0.035
    loc = cam.matrix_world @ Vector((-ortho * 0.47, -ortho * 0.47, -30.0 * U[0]))
    txt.matrix_world = Matrix.Translation(loc) @ cam.matrix_world.to_quaternion().to_matrix().to_4x4()
    for o in (rv, rh, txt):
        o.hide_render = False


VIEWS = {  # name: (eye direction, target, ortho scale)
    "front": ((1, 0, 0.0), Vector((0, 0, 8.5)), 25.0),
    "side": ((0, 1, 0.0), Vector((0, 0, 8.5)), 25.0),
    "threequarter": ((1, -0.8, 0.32), Vector((0, 0, 8.5)), 25.0),
    "mouth": ((1, 0, 0.05), None, 9.0),
    # Phase B2 mouth-region crops (ortho scale set per pose to the concept crop's cm framing)
    "m_front": ((1, 0, 0.0), None, 9.0),
    "m_threequarter": ((1, -0.8, 0.32), None, 9.0),
    "m_side": ((0, -1, 0.0), None, 9.0),
}
MOUTH_ORTHO = {"neutral": 9.2, "inhale": 12.0, "scream": 10.5}     # cm across the tile, = the concept crop (B2)


def shot(scene, cam, path, view, label, target=None, ortho_override=None):
    d, tgt, ortho = VIEWS[view]
    ortho = (ortho_override or ortho) * U[0]            # B4: design-frame framing x U
    tgt = target if target is not None else (tgt * U[0] if tgt is not None else tgt)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    cam.data.clip_start, cam.data.clip_end = 1.0, 500.0 * U[0]
    look(cam, tgt + nrm(d) * 80.0 * U[0], tgt)
    place_lights(cam)
    if view == "mouth" or view.startswith("m_"):
        for n in ("Ruler_10cm_V", "Ruler_10cm_H"):
            bpy.data.objects[n].hide_render = True
        txt = bpy.data.objects["Label"]
        txt.data.body = label
        txt.data.size = ortho * 0.04
        txt.matrix_world = Matrix.Translation(cam.matrix_world @ Vector((-ortho * 0.47, -ortho * 0.47, -30.0 * U[0]))) @ \
            cam.matrix_world.to_quaternion().to_matrix().to_4x4()
    else:
        place_review(cam, ortho, label, Vector((0, 0, 0)))
    scene.render.filepath = path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.render.render(write_still=True)
    return path


def fp_shot(scene, cam, path, label, eye_z):
    """First-person scale mock: perspective camera, 90 deg horizontal FOV, 45 cm in front of the turnip's bulb
    centre at its height (hand distance), 16:9, 10 cm ruler standing beside the bulb."""
    cam.data.type = "PERSP"
    cam.data.sensor_fit = "HORIZONTAL"
    cam.data.angle = math.radians(90.0)
    cam.data.clip_start, cam.data.clip_end = 1.0, 2000.0
    tgt = Vector((0.0, 0.0, eye_z))
    look(cam, tgt + X * 45.0, tgt)
    place_lights(cam)
    rv = bpy.data.objects["Ruler_10cm_V"]
    rv.matrix_world = Matrix.Translation(Vector((0.0, -7.5 * U[0], eye_z - 5.0)))   # beside the bulb, 10 cm long
    rv.hide_render = False
    bpy.data.objects["Ruler_10cm_H"].hide_render = True
    txt = bpy.data.objects["Label"]
    txt.data.body = label
    txt.data.size = 1.6
    txt.matrix_world = Matrix.Translation(cam.matrix_world @ Vector((-20.0, -10.0, -25.0))) @         cam.matrix_world.to_quaternion().to_matrix().to_4x4()
    rx, ry = scene.render.resolution_x, scene.render.resolution_y
    scene.render.resolution_x, scene.render.resolution_y = 960, 540
    scene.render.filepath = path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.render.render(write_still=True)
    scene.render.resolution_x, scene.render.resolution_y = rx, ry
    return path


def fp_fraction(scene, cam, path, eye_z):
    """B4: how much of the 90 deg / 45 cm first-person frame the turnip covers. Renders the posed body alone on a
    transparent film (rulers, label, statics hidden) and counts alpha > 0.5 pixels; also the alpha bounding box."""
    hide = {}
    for n in ("Ruler_10cm_V", "Ruler_10cm_H", "Label"):
        o = bpy.data.objects[n]
        hide[n] = o.hide_render
        o.hide_render = True
    ft = scene.render.film_transparent
    scene.render.film_transparent = True
    cam.data.type = "PERSP"
    cam.data.sensor_fit = "HORIZONTAL"
    cam.data.angle = math.radians(90.0)
    cam.data.clip_start, cam.data.clip_end = 1.0, 2000.0
    tgt = Vector((0.0, 0.0, eye_z))
    look(cam, tgt + X * 45.0, tgt)
    rx, ry = scene.render.resolution_x, scene.render.resolution_y
    scene.render.resolution_x, scene.render.resolution_y = 960, 540
    scene.render.filepath = path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.render.render(write_still=True)
    scene.render.resolution_x, scene.render.resolution_y = rx, ry
    scene.render.film_transparent = ft
    for n, h in hide.items():
        bpy.data.objects[n].hide_render = h
    a = load_px(path)[..., 3] > 0.5
    ys, xs = np.nonzero(a)
    return {"area_fraction": round(float(a.mean()), 4),
            "bbox_width_fraction": round(float((xs.max() - xs.min() + 1) / a.shape[1]), 4) if len(xs) else 0.0,
            "bbox_height_fraction": round(float((ys.max() - ys.min() + 1) / a.shape[0]), 4) if len(ys) else 0.0,
            "frame_px": [int(a.shape[1]), int(a.shape[0])], "camera": "perspective, 90 deg horizontal FOV, 16:9, eye "
            "45 cm in front of the bulb centre at its height (z %.2f)" % eye_z}


def use_rig(name):
    RIG.clear()
    RIG.update(RIGS[name])


def load_px(path):
    im = bpy.data.images.load(path, check_existing=False)
    w, h = im.size
    px = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bpy.data.images.remove(im)
    return px


def save_sheet(paths, cols, out, gap=8):
    tiles = [load_px(p) for p in paths]
    th, tw = tiles[0].shape[:2]
    rows = (len(tiles) + cols - 1) // cols
    W, H = cols * tw + (cols - 1) * gap, rows * th + (rows - 1) * gap
    sheet = np.ones((H, W, 4), dtype=np.float32) * 0.35
    sheet[..., 3] = 1.0
    for k, t in enumerate(tiles):
        r, c = k // cols, k % cols
        y0 = H - (r + 1) * th - r * gap
        x0 = c * (tw + gap)
        sheet[y0:y0 + th, x0:x0 + tw] = t
    img = bpy.data.images.new(os.path.basename(out), W, H, alpha=False)
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return out


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    arg = lambda k, d=None: argv[argv.index(k) + 1] if k in argv else d
    poses = arg("--poses", ",".join(BT.POSE_ORDER)).split(",")
    if poses == ["none"]:
        poses = []
    tag = arg("--tag")
    res = int(arg("--res", "560"))
    global OUT, ITER
    if arg("--out"):                 # B4: e.g. the B3 blend's first-person reference into its own folder
        OUT = os.path.join(ROOT, arg("--out"))
        ITER = os.path.join(OUT, "iterations")
    scene = bpy.context.scene
    setup(scene, res)
    arm = bpy.data.objects[BT.ARM_NAME]
    arm.hide_render = True
    cam = bpy.data.objects["ReviewCam"]
    scene.camera = cam
    for n in (BT.BED_NAME, BT.BED_EMPTY_NAME, BT.COLL_NAME):
        bpy.data.objects[n].hide_render = True
    written = []
    overview = []
    for pose in poses:
        BT.apply_pose(arm, BT.POSES[pose])
        paths = []
        for view in ("front", "side", "threequarter", "mouth"):
            tgt = None
            if view == "mouth" or view.startswith("m_"):
                body = bpy.data.objects[BT.MESH_NAME]
                co = BT.turnip_audit.evaluated(body)[0]
                idx = list(body["mouth_centre_l0"])
                c = co[idx].mean(0)
                tgt = Vector((0.0, 0.0, float(c[2])))
            p = shot(scene, cam, os.path.join(OUT, pose, "%s_%s.png" % (pose, view)), view,
                     "%s / %s" % (pose, view), tgt)
            paths.append(p)
        sheet = save_sheet(paths, 4, os.path.join(OUT, pose, "%s_sheet.png" % pose))
        written.append(sheet)
        overview += [paths[0], paths[2], paths[3]]
        print("SHEET", sheet)
    if len(poses) > 1:
        ov = save_sheet(overview, 3, os.path.join(OUT, "poses_overview.png"))
        written.append(ov)
    if "--planted" in argv:
        BT.apply_pose(arm, {})
        bed, bede = bpy.data.objects[BT.BED_NAME], bpy.data.objects[BT.BED_EMPTY_NAME]
        bed.hide_render = False
        pp = []
        for view in ("front", "threequarter"):
            pp.append(shot(scene, cam, os.path.join(OUT, "planted", "planted_%s.png" % view), view,
                           "planted / %s (TurnipBed_R01 at SoilLine z %.1f)" % (view, BT.P["SOIL_Z"] * U[0])))
        bed.hide_render = True
        bede.hide_render = False
        body = bpy.data.objects[BT.MESH_NAME]
        body.hide_render = True
        pp.append(shot(scene, cam, os.path.join(OUT, "planted", "empty_bed_threequarter.png"), "threequarter",
                       "TurnipBedEmpty_R01 / threequarter"))
        body.hide_render = False
        bede.hide_render = True
        written.append(save_sheet(pp, 3, os.path.join(OUT, "planted", "planted_sheet.png")))
    if "--mouth" in argv:            # B2: mouth-region crops, neutral light, per pose front / three-quarter / side
        body = bpy.data.objects[BT.MESH_NAME]
        for pose in ("neutral", "inhale", "scream"):
            BT.apply_pose(arm, BT.POSES[pose])
            co = BT.turnip_audit.evaluated(body)[0]
            c = Vector(co[list(body["mouth_centre_l0"])].mean(0))
            if pose == "inhale":
                c.z += 0.3 * U[0]
            for view in ("m_front", "m_threequarter", "m_side"):
                tgt = c - X * 1.6 * U[0] if view == "m_side" else c.copy()
                if view == "m_side":
                    tgt.x = c.x - (0.30 if pose != "scream" else 0.12) * MOUTH_ORTHO[pose] * U[0]
                p = shot(scene, cam, os.path.join(OUT, "mouth", "%s_%s.png" % (pose, view)), view,
                         "%s / %s" % (pose, view[2:]), tgt, MOUTH_ORTHO[pose])
                print("MOUTH", p)
        BT.apply_pose(arm, {})
    if "--compare" in argv:
        rows = []
        for pose in ("neutral", "inhale", "scream"):
            BT.apply_pose(arm, BT.POSES[pose])
            for rig in ("neutral", "game"):
                use_rig(rig)
                for view in ("front", "threequarter"):
                    rows.append(shot(scene, cam, os.path.join(OUT, "lighting", "%s_%s_%s.png" % (pose, rig, view)),
                                     view, "%s / %s light / %s" % (pose, rig, view)))
        use_rig("neutral")
        written.append(save_sheet(rows, 4, os.path.join(OUT, "lighting", "lighting_compare.png")))
    if "--fp" in argv:
        fps = []
        for pose in ("neutral", "inhale", "scream"):
            BT.apply_pose(arm, BT.POSES[pose])
            for rig in ("neutral", "game"):
                use_rig(rig)
                fps.append(fp_shot(scene, cam, os.path.join(OUT, "fp_mock", "fp_%s_%s.png" % (pose, rig)),
                                   "first-person mock / %s / %s light / 90 deg FOV, 45 cm, 10 cm ruler" % (pose, rig),
                                   BT.ZC * U[0]))
        use_rig("neutral")
        written.append(save_sheet(fps, 2, os.path.join(OUT, "fp_mock", "fp_sheet.png")))
        frac = {"unit": U[0]}
        for pose in ("neutral", "inhale", "scream"):
            BT.apply_pose(arm, BT.POSES[pose])
            frac[pose] = fp_fraction(scene, cam, os.path.join(OUT, "fp_mock", "fp_alpha_%s.png" % pose), BT.ZC * U[0])
        BT.apply_pose(arm, {})
        import json
        with open(os.path.join(OUT, "fp_mock", "fp_fraction.json"), "w") as fh:
            json.dump(frac, fh, indent=1)
        print("FP_FRACTION", json.dumps(frac))
    if tag:
        os.makedirs(ITER, exist_ok=True)
        for p in written:
            dst = os.path.join(ITER, "%s_%s" % (tag, os.path.basename(p)))
            shutil.copyfile(p, dst)
            print("ITER", dst)
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
