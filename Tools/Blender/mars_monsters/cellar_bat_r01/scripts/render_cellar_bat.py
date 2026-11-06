"""Cellar Bat R01 - Phase 3 review renders from source/CellarBat_R01.blend (poses come from the control rig's pose
actions, so every picture is the rig's output).

Writes into review/phase3b/ (Phase 3b; Phase 3 sheets stay in review/phase3/):
  compare_sheet.png      concept crop (left) | EEVEE neutral render (right), same view, rows:
                         02 FRONT, SIDE, BACK, TOP, UNDERSIDE, THREE-QUARTER | 03 SPREAD, HALF FOLD, WRAPPED, HANG,
                         FACE | 04 UP, DOWN, RECOVER, BANK LEFT, BANK RIGHT
  ref_workbench_sheet.png  rulers (10 cm segments), Workbench: front, side, back, dorsal, ventral, three-quarter,
                         face close-up, wing-root close-up, wing-root back
  ref_eevee_sheet.png    the same views lit (EEVEE neutral key/fill/rim)
  palette_sheet.png      front + three-quarter + face: neutral rig (top row) vs amber key / teal fill (bottom row)
  wrap_sheet.png, hang_sheet.png   front, side, back, three-quarter (EEVEE) + front/side Workbench
  lod_poses_sheet.png    rows LOD0/LOD1/LOD2, columns Spread, Up, Down, Recover, Wrap, BankLeft, BankRight, Hang (EEVEE)
  flap_sheet.png         the 16-frame control-rig flap action, front + three-quarter (EEVEE)
  face_wingroot_sheet.png  face and wing-root close-ups in both lights
Run:
  blender -b --factory-startup source/CellarBat_R01.blend --python render_cellar_bat.py -- [--only a,b] [--tag rNN]
Prints CELLAR_BAT_OK / CELLAR_BAT_FAIL.
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
import bat_rig  # noqa: E402

ROOT = os.path.dirname(HERE)
REPO = os.path.abspath(os.path.join(ROOT, "..", "..", "..", ".."))
ART = os.path.join(REPO, "docs", "art", "flying-units-r01")
OUT = os.path.join(ROOT, "review", "phase3b")
TMP = os.path.join(OUT, "_tiles")
LOD_NAMES = ("CellarBat_R01_Body", "CellarBat_R01_Body_LOD1", "CellarBat_R01_Body_LOD2")
POSE = "CellarBat_R01_Pose_"
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
BG = (0.016, 0.014, 0.014)

# concept crops: (sheet, x0, y0, x1, y1) as fractions of the sheet (measured on the 1670 x 941 previews)
SHEETS = {"02": "02-model-turnaround-v2.png", "03": "03-wing-rig-and-expressions-v2.png", "04": "04-animation-poses.png"}


def fr(sheet, x0, y0, x1, y1, w=1670.0, h=941.0):
    return (sheet, x0 / w, y0 / h, x1 / w, y1 / h)


def nrm(v):
    return Vector(v).normalized()


def look(cam, eye, target, up):
    eye, target, up = Vector(eye), Vector(target), Vector(up)
    zc = nrm(eye - target)
    xc = nrm(up.cross(zc))
    yc = zc.cross(xc)
    m = Matrix((xc, yc, zc)).transposed().to_4x4()
    m.translation = eye
    cam.matrix_world = m


# ------------------------------------------------------------------ scene setup
def setup_world(scene):
    w = scene.world or bpy.data.worlds.new("World")
    scene.world = w
    w.use_nodes = True
    bgn = w.node_tree.nodes.get("Background")
    bgn.inputs["Color"].default_value = (*BG, 1.0)
    bgn.inputs["Strength"].default_value = 1.0
    w["ambient_note"] = "background = dark ambient; the sun rig carries the light"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0


LIGHTS = {}


def make_lights():
    for n in ("Key", "Fill", "Rim"):
        ld = bpy.data.lights.new("Review" + n, "SUN")
        ob = bpy.data.objects.new("Review" + n, ld)
        bpy.data.collections["Review"].objects.link(ob)
        LIGHTS[n] = ob


RIGS = {  # (colour, strength, angle deg, direction in camera frame: (right, up, toward camera))
    "warm": {"Key": ((1.0, 0.86, 0.7), 5.0, 22.0, (-0.7, 0.75, 0.75)),
             "Fill": ((0.8, 0.86, 1.0), 1.6, 45.0, (0.9, 0.05, 0.6)),
             "Rim": ((1.0, 0.8, 0.62), 4.5, 10.0, (0.35, 0.65, -0.9))},
    "neutral": {"Key": ((1.0, 0.95, 0.88), 5.5, 22.0, (-0.7, 0.75, 0.75)),
                "Fill": ((0.88, 0.92, 1.0), 2.0, 45.0, (0.9, 0.05, 0.6)),
                "Rim": ((1.0, 0.95, 0.9), 4.5, 10.0, (0.35, 0.65, -0.9))},
    "dungeon": {"Key": ((1.0, 0.6, 0.28), 6.0, 22.0, (-0.75, 0.6, 0.6)),
                "Fill": ((0.25, 0.62, 0.66), 2.4, 45.0, (0.9, 0.0, 0.5)),
                "Rim": ((0.35, 0.8, 0.85), 3.4, 10.0, (0.4, 0.5, -0.9))},
}


def place_lights(cam, rig):
    m = cam.matrix_world.to_3x3()
    right, up, back = m.col[0], m.col[1], m.col[2]
    for n, ob in LIGHTS.items():
        col, st, ang, (a, b, c) = RIGS[rig][n]
        to_light = (right * a + up * b + back * c).normalized()
        ob.data.color = col
        ob.data.energy = st
        ob.data.angle = math.radians(ang)
        ob.rotation_euler = to_light.to_track_quat("Z", "Y").to_euler()


def engine(scene, kind):
    if kind == "workbench":
        scene.render.engine = "BLENDER_WORKBENCH"
        sh = scene.display.shading
        sh.light = "STUDIO"
        sh.color_type = "VERTEX"
        sh.show_cavity = False
        sh.show_shadows = False
        sh.show_specular_highlight = False
        sh.background_type = "VIEWPORT"
        sh.background_color = (0.13, 0.13, 0.135)
        scene.display.render_aa = "8"
        scene.view_settings.exposure = 1.3
        for ob in LIGHTS.values():
            ob.hide_render = True
    else:
        scene.render.engine = "BLENDER_EEVEE"
        scene.eevee.taa_render_samples = 48
        scene.eevee.use_shadows = True
        scene.eevee.shadow_ray_count = 2
        scene.eevee.shadow_step_count = 6
        scene.view_settings.exposure = 0.5
        for ob in LIGHTS.values():
            ob.hide_render = False


def show_lod(lod):
    for i, n in enumerate(LOD_NAMES):
        ob = bpy.data.objects[n]
        ob.hide_render = i != lod
        ob.hide_viewport = i != lod


def set_pose(ctrl, name):
    act = bpy.data.actions.get(POSE + name) if name else None
    bat_rig.use_action(ctrl, act, 0)


def review(names_on):
    for ob in bpy.data.collections["Review"].objects:
        if ob.type in ("MESH", "FONT"):
            ob.hide_render = ob.name not in names_on


def shot(scene, cam, path, eye, target, up=Z, ortho=None, lens=50.0, rig="neutral"):
    cam.data.type = "ORTHO" if ortho else "PERSP"
    if ortho:
        cam.data.ortho_scale = ortho
    else:
        cam.data.lens = lens
    cam.data.clip_start, cam.data.clip_end = 1.0, 5000.0
    look(cam, eye, target, up)
    scene.camera = cam
    if scene.render.engine == "BLENDER_EEVEE":
        place_lights(cam, rig)
    scene.render.filepath = path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.render.render(write_still=True)
    return path


# ------------------------------------------------------------------ images
_IMG = {}


def load_px(path):
    if path not in _IMG:
        im = bpy.data.images.load(path, check_existing=False)
        w, h = im.size
        px = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
        bpy.data.images.remove(im)
        _IMG[path] = px
    return _IMG[path]


def resize(px, w, h):
    sh, sw = px.shape[:2]
    ys = (np.arange(h) + 0.5) * sh / h - 0.5
    xs = (np.arange(w) + 0.5) * sw / w - 0.5
    y0 = np.clip(np.floor(ys).astype(int), 0, sh - 1)
    x0 = np.clip(np.floor(xs).astype(int), 0, sw - 1)
    y1, x1 = np.clip(y0 + 1, 0, sh - 1), np.clip(x0 + 1, 0, sw - 1)
    fy, fx = (ys - np.floor(ys))[:, None, None], (xs - np.floor(xs))[None, :, None]
    a = px[y0][:, x0] * (1 - fx) + px[y0][:, x1] * fx
    b = px[y1][:, x0] * (1 - fx) + px[y1][:, x1] * fx
    return a * (1 - fy) + b * fy


def fit(px, w, h):
    sh, sw = px.shape[:2]
    k = min(w / sw, h / sh)
    nw, nh = max(1, int(sw * k)), max(1, int(sh * k))
    r = resize(px, nw, nh)
    out = np.zeros((h, w, 4), dtype=np.float32)
    out[..., :3] = BG[0] ** (1 / 2.2)
    out[..., 3] = 1.0
    y0, x0 = (h - nh) // 2, (w - nw) // 2
    out[y0:y0 + nh, x0:x0 + nw] = r
    return out


def concept(crop, w, h):
    sheet, fx0, fy0, fx1, fy1 = crop
    px = load_px(os.path.join(ART, SHEETS[sheet]))
    H, W = px.shape[:2]
    # Blender pixel rows run bottom-up
    r0, r1 = int(H * (1 - fy1)), int(H * (1 - fy0))
    c0, c1 = int(W * fx0), int(W * fx1)
    return fit(px[r0:r1, c0:c1], w, h)


def save_sheet(tiles, cols, out, tile_w, tile_h, gap=6):
    rows = (len(tiles) + cols - 1) // cols
    W, H = cols * tile_w + (cols - 1) * gap, rows * tile_h + (rows - 1) * gap
    sheet = np.zeros((H, W, 4), dtype=np.float32)
    sheet[..., :3] = 0.5
    sheet[..., 3] = 1.0
    for k, t in enumerate(tiles):
        if t is None:
            continue
        r, c = k // cols, k % cols
        y0 = H - (r + 1) * tile_h - r * gap
        x0 = c * (tile_w + gap)
        sheet[y0:y0 + tile_h, x0:x0 + tile_w] = t if t.shape[:2] == (tile_h, tile_w) else fit(t, tile_w, tile_h)
    img = bpy.data.images.new(os.path.basename(out), W, H, alpha=False)
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return out


def tile(path, w, h):
    return fit(load_px(path), w, h)


# ------------------------------------------------------------------ views
TGT = Vector((0.0, 0.0, -3.0))


def view_eye(d, dist, tgt=TGT):
    return tgt + nrm(d) * dist


COMPARE = [  # (name, pose, crop, eye dir, up, target, ortho or None, lens)
    ("front", "Spread", fr("02", 15, 120, 600, 400), (1, 0, 0.06), Z, TGT, 84.0, None),
    ("side", "Spread", fr("02", 640, 120, 1010, 400), (0.45, -1, 0.08), Z, TGT, 84.0, None),
    ("back", "Spread", fr("02", 1085, 120, 1660, 400), (-1, 0, 0.06), Z, TGT, 84.0, None),
    ("top", "Spread", fr("02", 25, 490, 575, 760), (0.02, 0, 1), X, TGT, 84.0, None),
    ("underside", "Spread", fr("02", 580, 490, 1110, 760), (0.02, 0, -1), X, TGT, 84.0, None),
    ("three_quarter", "Spread", fr("02", 1135, 490, 1650, 775), (1, -0.62, 0.22), Z, TGT, None, 125.0),
    ("spread_03", "Spread", fr("03", 25, 495, 565, 810), (1, -0.08, -0.05), Z, TGT, 86.0, None),
    ("half_fold_03", "HalfFold", fr("03", 575, 495, 910, 810), (1, -0.08, 0.0), Z, TGT, 64.0, None),
    ("wrapped_03", "Wrap", fr("03", 975, 495, 1165, 810), (1, -0.05, 0.02), Z, Vector((0, 0, -1.0)), 48.0, None),
    ("hang_03", "Hang", fr("03", 1225, 495, 1648, 810), (1, -0.05, 0.0), Z, Vector((0, 0, 1.0)), 50.0, None),
    ("face_03", "Spread", fr("03", 905, 80, 1230, 465), (1, -0.12, 0.08), Z, None, None, 60.0),
    ("up_04", "Up", fr("04", 15, 80, 430, 335, 1672), (1, -0.35, 0.12), Z, TGT, None, 120.0),
    ("down_04", "Down", fr("04", 840, 80, 1250, 335, 1672), (1, -0.35, 0.12), Z, TGT, None, 120.0),
    ("recover_04", "Recover", fr("04", 1250, 80, 1660, 335, 1672), (1, -0.35, 0.12), Z, TGT, None, 120.0),
    ("bank_left_04", "BankLeft", fr("04", 430, 355, 840, 595, 1672), (1, -0.25, 0.1), Z, TGT, None, 120.0),
    ("bank_right_04", "BankRight", fr("04", 840, 355, 1250, 595, 1672), (1, -0.25, 0.1), Z, TGT, None, 120.0),
]


def head_target():
    hb = bpy.data.objects["CellarBat_R01_Armature"].pose.bones["head"]
    return hb.head + Vector((3.0, 0.0, 1.2))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else None
    tag = argv[argv.index("--tag") + 1] if "--tag" in argv else None
    want = lambda k: only is None or k in only
    scene = bpy.context.scene
    setup_world(scene)
    make_lights()
    ctrl = bpy.data.objects["CellarBat_R01_Controls"]
    ctrl.hide_render = True
    bpy.data.objects["CellarBat_R01_Armature"].hide_render = True
    cam = bpy.data.objects["ReviewCam"]
    scene.render.image_settings.file_format = "PNG"
    rulers = ("Ruler_Y_80cm", "Ruler_Z_40cm", "Ruler_X_30cm", "Label")
    TW, TH = 720, 480
    scene.render.resolution_x, scene.render.resolution_y = TW, TH
    scene.render.resolution_percentage = 100
    show_lod(0)
    outs = []

    if want("compare"):
        engine(scene, "eevee")
        review(())
        tiles = []
        for name, pose, crop, d, up, tgt, ortho, lens in COMPARE:
            set_pose(ctrl, pose)
            if name.startswith("hang"):
                review(("PerchBar",))
            else:
                review(())
            if tgt is None:
                tgt = head_target()
                eye = tgt + nrm(d) * 70.0
            else:
                eye = view_eye(d, 260.0, tgt)
            p = shot(scene, cam, os.path.join(TMP, "cmp_%s.png" % name), eye, tgt, up, ortho=ortho, lens=lens or 50.0,
                     rig="warm")
            tiles += [concept(crop, TW, TH), tile(p, TW, TH)]
        outs.append(save_sheet(tiles, 4, os.path.join(OUT, "compare_sheet.png"), TW, TH))

    if want("ref"):
        views = [("front", (1, 0, 0), Z, 90.0), ("side", (0, -1, 0), Z, 90.0), ("back", (-1, 0, 0), Z, 90.0),
                 ("dorsal", (0, 0, 1), X, 90.0), ("ventral", (0, 0, -1), X, 90.0),
                 ("three_quarter", (1.0, -0.8, 0.45), Z, 92.0)]
        set_pose(ctrl, "Spread")
        for kind in ("workbench", "eevee"):
            engine(scene, kind)
            paths = []
            for vn, d, up, ow in views:
                review(rulers if vn not in ("side",) else ("Ruler_Z_40cm", "Ruler_X_30cm"))
                paths.append(shot(scene, cam, os.path.join(TMP, "ref_%s_%s.png" % (kind, vn)),
                                  view_eye(d, 300.0, Vector((0, 0, -4))), Vector((0, 0, -4)), up, ortho=ow))
            review(())
            H = head_target()
            paths.append(shot(scene, cam, os.path.join(TMP, "ref_%s_face.png" % kind), H + nrm((1, -0.35, 0.12)) * 62,
                              H, Z, lens=60.0))
            S = bpy.data.objects["CellarBat_R01_Armature"].pose.bones["upperarm_l"].head
            paths.append(shot(scene, cam, os.path.join(TMP, "ref_%s_wingroot.png" % kind),
                              S + nrm((0.7, 0.6, 0.5)) * 75, S + Vector((0, 4, -4)), Z, lens=55.0))
            paths.append(shot(scene, cam, os.path.join(TMP, "ref_%s_wingroot_back.png" % kind),
                              S + nrm((-0.8, 0.6, 0.3)) * 75, S + Vector((0, 4, -4)), Z, lens=55.0))
            outs.append(save_sheet([tile(p, TW, TH) for p in paths], 3,
                                   os.path.join(OUT, "ref_%s_sheet.png" % kind), TW, TH))

    if want("palette"):
        engine(scene, "eevee")
        review(())
        set_pose(ctrl, "Spread")
        paths = []
        for rig in ("neutral", "dungeon"):
            paths.append(shot(scene, cam, os.path.join(TMP, "pal_%s_front.png" % rig), view_eye((1, 0, 0.06), 260),
                              TGT, Z, ortho=84.0, rig=rig))
            paths.append(shot(scene, cam, os.path.join(TMP, "pal_%s_tq.png" % rig), view_eye((1, -0.62, 0.22), 260),
                              TGT, Z, lens=125.0, rig=rig))
            H = head_target()
            paths.append(shot(scene, cam, os.path.join(TMP, "pal_%s_face.png" % rig), H + nrm((1, -0.3, 0.1)) * 70,
                              H, Z, lens=60.0, rig=rig))
        outs.append(save_sheet([tile(p, TW, TH) for p in paths], 3, os.path.join(OUT, "palette_sheet.png"), TW, TH))

    for pose_name, sheet_name, tgt, ow in (("Wrap", "wrap", Vector((0, 0, -1.0)), 50.0),
                                           ("Hang", "hang", Vector((0, 0, 1.0)), 52.0)):
        if not want(sheet_name):
            continue
        set_pose(ctrl, pose_name)
        paths = []
        views = [("front", (1, 0, 0.03)), ("side", (0, -1, 0.03)), ("back", (-1, 0, 0.03)),
                 ("three_quarter", (1, -0.8, 0.3)), ("side_left", (0, 1, 0.03)), ("below", (0.5, -0.3, -1.0))]
        engine(scene, "eevee")
        for vn, d in views:
            review(("PerchBar",) if pose_name == "Hang" else ())
            paths.append(shot(scene, cam, os.path.join(TMP, "%s_%s.png" % (sheet_name, vn)), view_eye(d, 260.0, tgt),
                              tgt, Z, ortho=ow))
        engine(scene, "workbench")
        for vn, d in views[:2]:
            review(("PerchBar",) if pose_name == "Hang" else ())
            paths.append(shot(scene, cam, os.path.join(TMP, "%s_wb_%s.png" % (sheet_name, vn)),
                              view_eye(d, 260.0, tgt), tgt, Z, ortho=ow))
        outs.append(save_sheet([tile(p, TW, TH) for p in paths], 4, os.path.join(OUT, sheet_name + "_sheet.png"),
                               TW, TH))

    if want("lod"):
        engine(scene, "eevee")
        poses = ["Spread", "Up", "Down", "Recover", "Wrap", "BankLeft", "BankRight", "Hang"]
        paths = []
        sw, sh = 480, 360
        scene.render.resolution_x, scene.render.resolution_y = sw, sh
        for lod in range(3):
            show_lod(lod)
            for pn in poses:
                set_pose(ctrl, pn)
                review(("PerchBar",) if pn == "Hang" else ())
                tgt = Vector((0, 0, 3.0)) if pn == "Hang" else (Vector((0, 0, -3.5)) if pn == "Wrap" else TGT)
                ow = 50.0 if pn in ("Hang", "Wrap") else None
                paths.append(shot(scene, cam, os.path.join(TMP, "lod%d_%s.png" % (lod, pn)),
                                  view_eye((1, -0.7, 0.3), 260.0, tgt), tgt, Z, ortho=ow, lens=120.0))
        show_lod(0)
        outs.append(save_sheet([tile(p, sw, sh) for p in paths], len(poses), os.path.join(OUT, "lod_poses_sheet.png"),
                               sw, sh))
        scene.render.resolution_x, scene.render.resolution_y = TW, TH

    if want("flap"):
        engine(scene, "eevee")
        review(())
        sw, sh = 400, 300
        scene.render.resolution_x, scene.render.resolution_y = sw, sh
        bat_rig.use_action(ctrl, bpy.data.actions["CellarBat_R01_FlapTest_Ctl"], 0)
        paths = []
        for camn, d, ortho, lens in (("front", (1, 0, 0.05), 100.0, None), ("tq", (1, -0.8, 0.45), None, 120.0)):
            for f in range(16):
                scene.frame_set(f)
                paths.append(shot(scene, cam, os.path.join(TMP, "flap_%s_%02d.png" % (camn, f)), view_eye(d, 260.0),
                                  TGT, Z, ortho=ortho, lens=lens or 50.0))
        outs.append(save_sheet([tile(p, sw, sh) for p in paths], 8, os.path.join(OUT, "flap_sheet.png"), sw, sh))
        scene.render.resolution_x, scene.render.resolution_y = TW, TH

    if tag:
        it = os.path.join(OUT, "iterations")
        os.makedirs(it, exist_ok=True)
        for o in outs:
            shutil.copyfile(o, os.path.join(it, "%s_%s" % (tag, os.path.basename(o))))
    for o in outs:
        print("SHEET", o)
    print("CELLAR_BAT_OK")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        print("CELLAR_BAT_FAIL exception")
        sys.exit(1)
