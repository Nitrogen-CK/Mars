"""Pantry Rat R01 - Phase 1 review renders (called by build_pantry_rat.py inside the same headless process, so every
picture is the built source in the audited pose).

review/phase1/
  views/      front, right, rear, top, underside, hero_tq (right-front), tq_left (Workbench, ortho + 10 cm rulers),
              hero_eevee, eyes_closeup_eevee (EyePlate half-mapping preview on the head patches)
  views_sheet.png, compare_02.png (sheet 02 crop | render, per view)
  poses/<pose>_{side,front,tq}.png + poses/sheet_<group>.png
  den/        portal_front_empty (EEVEE eyes), portal_front_rat (den_crouch at the opening), grazing_left/right
              (75 deg off the portal axis at rat eye height), cutaway (section through the den centre line)
  court/      rummage, rear_rummage, carry, drag_carry, death_drop, topdown
  iterations/ every run's views/compare sheets, tagged
"""
import math
import os
import shutil

import bpy
import numpy as np
from mathutils import Matrix, Vector

import rat_common as rc

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
BG = (0.07, 0.07, 0.078)
RES = (1000, 760)


def nrm(v):
    return Vector(v).normalized()


def look(cam, eye, target, up):
    eye, target, up = Vector(eye), Vector(target), Vector(up)
    zc = nrm(eye - target)
    xc = up.cross(zc)
    if xc.length < 1e-6:
        xc = Y.cross(zc)
    xc.normalize()
    yc = zc.cross(xc)
    m = Matrix((xc, yc, zc)).transposed().to_4x4()
    m.translation = eye
    cam.matrix_world = m


LIGHTS = {}


def make_lights(coll):
    for n, (col, st, ang) in {"Key": ((1.0, 0.95, 0.88), 4.0, 25.0), "Fill": ((0.85, 0.9, 1.0), 1.4, 45.0),
                              "Rim": ((1.0, 0.92, 0.85), 3.0, 12.0)}.items():
        ld = bpy.data.lights.new("Review" + n, "SUN")
        ld.color, ld.energy, ld.angle = col, st, math.radians(ang)
        ob = bpy.data.objects.new("Review" + n, ld)
        coll.objects.link(ob)
        LIGHTS[n] = ob


def place_lights(cam):
    m = cam.matrix_world.to_3x3()
    right, up, back = m.col[0], m.col[1], m.col[2]
    for n, (a, b, c) in {"Key": (-0.7, 0.8, 0.7), "Fill": (0.9, 0.1, 0.6), "Rim": (0.3, 0.7, -0.9)}.items():
        d = (right * a + up * b + back * c).normalized()
        LIGHTS[n].rotation_euler = d.to_track_quat("Z", "Y").to_euler()


def setup(scene):
    w = scene.world or bpy.data.worlds.new("World")
    scene.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (*BG, 1.0)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.resolution_x, scene.render.resolution_y = RES
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"


def engine(scene, kind):
    if kind == "wb":
        scene.render.engine = "BLENDER_WORKBENCH"
        sh = scene.display.shading
        sh.light = "STUDIO"
        sh.color_type = "VERTEX"
        sh.show_cavity = False
        sh.show_shadows = True
        sh.shadow_intensity = 0.45
        sh.show_specular_highlight = False
        sh.background_type = "VIEWPORT"
        sh.background_color = BG
        scene.display.render_aa = "8"
        scene.view_settings.exposure = 0.0
        for ob in LIGHTS.values():
            ob.hide_render = True
    else:
        scene.render.engine = "BLENDER_EEVEE"
        scene.eevee.taa_render_samples = 32
        scene.view_settings.exposure = 0.3
        for ob in LIGHTS.values():
            ob.hide_render = False


def visible(names_on, rat=True):
    for ob in bpy.data.objects:
        if ob.type == "LIGHT" or ob.type == "CAMERA":
            continue
        coll = ob.users_collection[0].name if ob.users_collection else ""
        if coll == "Export":
            ob.hide_render = not rat
        elif coll in ("Props", "Review"):
            ob.hide_render = ob.name not in names_on
        elif coll == "Authoring":
            ob.hide_render = True


def world_pts(objs):
    pts = []
    for ob in objs:
        if ob.type != "MESH" or ob.hide_render:
            continue
        co, _, _ = rc.evaluated_tris(ob)
        pts.append(co)
    return np.concatenate(pts) if pts else np.zeros((1, 3))


def frame_ortho(cam, d, up, pts, margin=1.12, dist=600.0):
    d, up = nrm(d), Vector(up)
    xc = nrm(up.cross(-d)) if up.cross(-d).length > 1e-6 else nrm(Y.cross(-d))
    yc = (-d).cross(xc)
    c = Vector(pts.mean(axis=0))
    px = (pts - np.array(c)) @ np.array(xc)
    py = (pts - np.array(c)) @ np.array(yc)
    cx, cy = 0.5 * (px.max() + px.min()), 0.5 * (py.max() + py.min())
    c = c + xc * cx + yc * cy
    w, h = px.max() - px.min(), py.max() - py.min()
    asp = RES[0] / RES[1]
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(w, h * asp) * margin
    cam.data.clip_start, cam.data.clip_end = 1.0, 5000.0
    look(cam, c - d * dist, c, up)


def frame_persp(cam, d, up, pts, lens=50.0, margin=1.1):
    d = nrm(d)
    c = Vector(pts.mean(axis=0))
    c = Vector((pts.max(axis=0) + pts.min(axis=0)) / 2)
    r = float(np.linalg.norm(pts - np.array(c), axis=1).max())
    fov = 2 * math.atan(18.0 / lens) * (RES[1] / RES[0])
    dist = r / math.sin(fov / 2) * margin
    cam.data.type = "PERSP"
    cam.data.lens = lens
    cam.data.clip_start, cam.data.clip_end = 1.0, 5000.0
    look(cam, c - d * dist, c, up)


def render(scene, cam, path):
    scene.camera = cam
    if scene.render.engine == "BLENDER_EEVEE":
        place_lights(cam)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


# ------------------------------------------------------------------ images (cellar bat sheet helpers)
def load_px(path):
    im = bpy.data.images.load(path, check_existing=False)
    w, h = im.size
    px = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bpy.data.images.remove(im)
    return px


def resize(px, w, h):
    sh, sw = px.shape[:2]
    ys = np.clip(((np.arange(h) + 0.5) * sh / h).astype(int), 0, sh - 1)
    xs = np.clip(((np.arange(w) + 0.5) * sw / w).astype(int), 0, sw - 1)
    return px[ys][:, xs]


def fit(px, w, h, bg=0.12):
    sh, sw = px.shape[:2]
    k = min(w / sw, h / sh)
    nw, nh = max(1, int(sw * k)), max(1, int(sh * k))
    r = resize(px, nw, nh)
    out = np.zeros((h, w, 4), dtype=np.float32)
    out[..., :3] = bg
    out[..., 3] = 1.0
    y0, x0 = (h - nh) // 2, (w - nw) // 2
    out[y0:y0 + nh, x0:x0 + nw] = r
    return out


def save_sheet(tiles, cols, out, tw, th, gap=6):
    rows = (len(tiles) + cols - 1) // cols
    W, H = cols * tw + (cols - 1) * gap, rows * th + (rows - 1) * gap
    sheet = np.zeros((H, W, 4), dtype=np.float32)
    sheet[..., :3] = 0.45
    sheet[..., 3] = 1.0
    for k, t in enumerate(tiles):
        if t is None:
            continue
        r, c = k // cols, k % cols
        y0 = H - (r + 1) * th - r * gap
        x0 = c * (tw + gap)
        sheet[y0:y0 + th, x0:x0 + tw] = fit(t, tw, th)
    img = bpy.data.images.new(os.path.basename(out), W, H, alpha=False)
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return out


def concept(path, x0, y0, x1, y1):
    px = load_px(path)
    H, W = px.shape[:2]
    r0, r1 = int(H * (1 - y1 / 1024.0)), int(H * (1 - y0 / 1024.0))
    c0, c1 = int(W * x0 / 1536.0), int(W * x1 / 1536.0)
    return px[r0:r1, c0:c1]


# ------------------------------------------------------------------ main
def render_all(G, arm, body, poses, M, views_only=False, tag=None, objs=None, reach=None):
    scene = bpy.context.scene
    setup(scene)
    review = bpy.data.collections["Review"]
    make_lights(review)
    cam = bpy.data.objects["ReviewCam"]
    OUT = G["REVIEW"]
    ITER = os.path.join(OUT, "iterations")
    os.makedirs(ITER, exist_ok=True)
    apply_pose = G["apply_pose"]
    rulers = ["Ruler_X_80", "Ruler_Z_70", "Ruler_Y_40"]
    label = [o.name for o in review.objects if o.name.startswith("Label_")]
    written = []

    def rat_pts():
        return world_pts([body])

    # ---------------- views (neutral)
    arm.matrix_world = Matrix.Identity(4)
    apply_pose(arm, {})
    engine(scene, "wb")
    V = os.path.join(OUT, "views")
    views = {
        "front": ((-1, 0, 0), Z, True), "right": ((0, 1, 0), Z, True), "rear": ((1, 0, 0), Z, True),
        "top": ((0, 0, -1), X, False), "underside": ((0, 0, 1), X, False),
    }
    for name, (d, up, with_rulers) in views.items():
        visible(set(rulers + label) if with_rulers else {"Ruler_X_80"} if name == "top" else set())
        pts = rat_pts()
        if with_rulers:
            pts = np.concatenate([pts, world_pts([bpy.data.objects[r] for r in rulers])])
        frame_ortho(cam, d, up, pts, 1.08)
        written.append(render(scene, cam, os.path.join(V, name + ".png")))
    visible({"Ruler_X_80", "Ruler_Z_70"})
    frame_persp(cam, (-0.72, 0.62, -0.30), Z, rat_pts(), 50.0, 1.05)
    written.append(render(scene, cam, os.path.join(V, "hero_tq.png")))
    frame_persp(cam, (-0.72, -0.62, -0.30), Z, rat_pts(), 50.0, 1.05)
    written.append(render(scene, cam, os.path.join(V, "tq_left.png")))
    engine(scene, "eevee")
    visible(set())
    frame_persp(cam, (-0.72, 0.62, -0.30), Z, rat_pts(), 50.0, 1.05)
    written.append(render(scene, cam, os.path.join(V, "hero_eevee.png")))
    # eyes close-up: head from the front-above
    hb = arm.pose.bones["head"]
    hc = (hb.head + hb.tail) * 0.5
    cam.data.type = "PERSP"
    cam.data.lens = 60.0
    look(cam, hc + Vector((70.0, 0.0, 14.0)), hc + Vector((0, 0, 1.0)), Z)
    written.append(render(scene, cam, os.path.join(V, "eyes_closeup_eevee.png")))
    look(cam, hc + Vector((52.0, 48.0, 10.0)), hc, Z)
    written.append(render(scene, cam, os.path.join(V, "eyes_left_side_eevee.png")))
    engine(scene, "wb")
    # sheets
    T = lambda n: load_px(os.path.join(V, n + ".png"))
    vs = save_sheet([T(n) for n in ("front", "right", "rear", "top", "underside", "hero_tq")], 3,
                    os.path.join(OUT, "views_sheet.png"), 800, 608)
    s02 = os.path.join(G["ROOT"], "..", "..", "..", "..", "docs", "art", "pantry-rat-dens-production-r01",
                       "02-rat-model-turnaround.png")
    s02 = os.path.abspath(s02)
    crops = {"front": (20, 100, 355, 450), "right": (360, 100, 895, 450), "rear": (900, 100, 1200, 450),
             "hero_tq": (0, 500, 640, 1000), "top": (640, 500, 910, 1000), "underside": (910, 500, 1210, 1000)}
    tiles = []
    for n in ("front", "right", "rear", "hero_tq", "top", "underside"):
        tiles += [concept(s02, *crops[n]), T(n)]
    cs = save_sheet(tiles, 4, os.path.join(OUT, "compare_02.png"), 640, 486)
    if tag:
        shutil.copy(vs, os.path.join(ITER, "views_sheet_%s.png" % tag))
        shutil.copy(cs, os.path.join(ITER, "compare_02_%s.png" % tag))
        shutil.copy(os.path.join(V, "hero_eevee.png"), os.path.join(ITER, "hero_eevee_%s.png" % tag))
    if views_only:
        return written

    # ---------------- poses
    PZ = os.path.join(OUT, "poses")
    groups = {"locomotion": ["neutral", "crouch", "stretch", "bound_apex", "rear_up"],
              "carry": ["jaw_carry", "look_back"], "death": ["topple_left", "topple_right", "dead_back"],
              "den": ["den_crouch"]}
    carry_props = {"jaw_carry": {"Mushroom_Carry"}, "look_back": {"Mushroom_Carry"}}
    for g, names in groups.items():
        tiles = []
        for n in names:
            apply_pose(arm, poses[n])
            visible(carry_props.get(n, set()))
            pts = np.concatenate([rat_pts()] + ([world_pts([objs["mush_carry"]])] if n in carry_props else []))
            frame_ortho(cam, (0, 1, 0), Z, pts, 1.1)
            p1 = render(scene, cam, os.path.join(PZ, "%s_side.png" % n))
            frame_ortho(cam, (-1, 0, 0), Z, pts, 1.1)
            p2 = render(scene, cam, os.path.join(PZ, "%s_front.png" % n))
            frame_persp(cam, (-0.72, 0.62, -0.32), Z, pts, 50.0, 1.05)
            p3 = render(scene, cam, os.path.join(PZ, "%s_tq.png" % n))
            written += [p1, p2, p3]
            tiles += [load_px(p1), load_px(p2), load_px(p3)]
        save_sheet(tiles, 3, os.path.join(PZ, "sheet_%s.png" % g), 640, 486)
        if tag:
            shutil.copy(os.path.join(PZ, "sheet_%s.png" % g), os.path.join(ITER, "poses_%s_%s.png" % (g, tag)))

    # ---------------- den
    D = os.path.join(OUT, "den")
    den = objs["den_root"]
    den_names = {"Den_StoneArch_Shell", "Den_Recess", "Den_BackPlane", "Den_EyePlate", "Den_Wall", "Court_Floor"}
    dm = den.matrix_world
    open_c = dm @ Vector((0.0, 0.0, 25.0))      # opening centre at rat eye height
    out_dir = (dm.to_3x3() @ X).normalized()     # portal axis, pointing out of the den into the court
    engine(scene, "eevee")
    visible(den_names, rat=False)
    cam.data.type = "PERSP"
    cam.data.lens = 35.0
    look(cam, open_c + out_dir * 230.0 + Vector((0, 0, 12.0)), open_c + Vector((0, 0, 4.0)), Z)
    written.append(render(scene, cam, os.path.join(D, "portal_front_empty.png")))
    for side, sgn in (("left", 1), ("right", -1)):
        a = math.radians(75.0 * sgn)
        dvec = Matrix.Rotation(a, 3, "Z") @ out_dir
        look(cam, open_c + dvec * 170.0, open_c, Z)
        written.append(render(scene, cam, os.path.join(D, "grazing_%s.png" % side)))
    # den_crouch at the opening (rat facing into the den, chest in the portal plane)
    apply_pose(arm, poses["den_crouch"])
    place = Matrix.Translation(dm @ Vector((10.0, 0.0, 0.0))) @ dm.to_3x3().to_4x4() @ Matrix.Rotation(math.pi, 4, "Z")
    arm.matrix_world = place
    bpy.context.view_layer.update()
    visible(den_names, rat=True)
    look(cam, open_c + out_dir * 230.0 + Vector((0, 0, 12.0)), open_c + Vector((0, 0, 4.0)), Z)
    written.append(render(scene, cam, os.path.join(D, "portal_front_rat.png")))
    engine(scene, "wb")
    # cutaway: section through the den centre line (near clip at the portal axis plane)
    side_dir = (dm.to_3x3() @ Y).normalized()
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 190.0
    tgt = dm @ Vector((-15.0, 0.0, 40.0))
    look(cam, tgt - side_dir * 300.0, tgt, Z)
    cam.data.clip_start = 300.0
    visible(den_names - {"Den_Wall"}, rat=True)
    written.append(render(scene, cam, os.path.join(D, "cutaway.png")))
    cam.data.clip_start = 1.0
    arm.matrix_world = Matrix.Identity(4)
    bpy.context.view_layer.update()

    # ---------------- court
    C = os.path.join(OUT, "court")
    court_base = {"Court_Floor", "Backpack_Proxy", "Mushroom_AtPocket2", "Crate_1", "Crate_2", "Chef_Capsule_r39_hh75",
                  "Den_StoneArch_Shell", "Den_Recess", "Den_BackPlane", "Den_EyePlate", "Den_Wall",
                  "Cheese_MonksRind"}
    for label_, key in (("rummage", "rummage"), ("rear_rummage", "rear_rummage")):
        r = reach[key]
        apply_pose(arm, poses[key])
        arm.matrix_world = Matrix.Translation(Vector(r["rat_placement_world"])) @ Matrix.Rotation(math.pi, 4, "Z")
        bpy.context.view_layer.update()
        visible(court_base)
        pts = np.concatenate([rat_pts(), np.array([r["pocket_world"]])])
        c = Vector(pts.mean(axis=0))
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 150.0
        look(cam, c + Vector((0, -400.0, 20.0)), c + Vector((0, 0, 20.0)), Z)
        written.append(render(scene, cam, os.path.join(C, label_ + "_side.png")))
        cam.data.type = "PERSP"
        cam.data.lens = 40.0
        look(cam, c + Vector((150.0, -150.0, 70.0)), c + Vector((-20, 0, 25.0)), Z)
        written.append(render(scene, cam, os.path.join(C, label_ + ".png")))
    # carry / drag / death in the open court
    spot = Matrix.Translation(Vector((150.0, -200.0, 0.0)))
    for label_, pose_name, extra in (("carry", "jaw_carry", {"Mushroom_Carry"}),
                                     ("drag_carry", "drag_carry", {"Bulky_Proxy_30x30x25"})):
        apply_pose(arm, poses[pose_name])
        arm.matrix_world = spot
        bpy.context.view_layer.update()
        visible(court_base | extra)
        pts = np.concatenate([rat_pts(), world_pts([objs["mush_carry"] if "Mushroom_Carry" in extra else objs["bulky"]])])
        frame_ortho(cam, (0, 1, 0), Z, pts, 1.15)
        written.append(render(scene, cam, os.path.join(C, label_ + "_side.png")))
        frame_persp(cam, (-0.7, 0.62, -0.35), Z, pts, 50.0, 1.05)
        written.append(render(scene, cam, os.path.join(C, label_ + ".png")))
    apply_pose(arm, poses["dead_back"])
    arm.matrix_world = spot
    mf = objs["mush_floor"]
    rest_m = mf.matrix_world.copy()
    mf.matrix_world = spot @ rest_m
    bpy.context.view_layer.update()
    visible(court_base | {"Mushroom_Dropped"})
    pts = np.concatenate([rat_pts(), world_pts([mf])])
    frame_persp(cam, (-0.55, 0.65, -0.52), Z, pts, 50.0, 1.05)
    written.append(render(scene, cam, os.path.join(C, "death_drop.png")))
    frame_ortho(cam, (0, 0, -1), X, pts, 1.2)
    written.append(render(scene, cam, os.path.join(C, "death_drop_top.png")))
    mf.matrix_world = rest_m
    # top-down court with both flee routes and a loaded rat on route A
    apply_pose(arm, poses["jaw_carry"])
    arm.matrix_world = Matrix.Translation(Vector((15.0, -105.0, 0.0)))
    bpy.context.view_layer.update()
    visible(court_base | {"Mushroom_Carry", "Route_Loop_A", "Route_FigureEight_B"})
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 860.0
    look(cam, Vector((0, 0, 900.0)), Vector((0, 0, 0)), Y)
    written.append(render(scene, cam, os.path.join(C, "topdown.png")))
    arm.matrix_world = Matrix.Identity(4)
    bpy.context.view_layer.update()
    tiles = [load_px(os.path.join(C, n + ".png")) for n in
             ("rummage", "rear_rummage", "carry", "drag_carry", "death_drop", "topdown")]
    save_sheet(tiles, 3, os.path.join(C, "sheet_court.png"), 640, 486)
    dtiles = [load_px(os.path.join(D, n + ".png")) for n in
              ("portal_front_empty", "portal_front_rat", "grazing_left", "grazing_right", "cutaway")]
    save_sheet(dtiles, 3, os.path.join(D, "sheet_den.png"), 640, 486)
    M["renders"] = sorted(os.path.relpath(p, OUT).replace("\\", "/") for p in written)
    return written
