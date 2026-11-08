"""Pantry Rat R02 - compare harness: build the current model, render the six sheet-02 cameras, set each beside the
sheet crop, overlay both silhouettes, measure.

  blender -b --factory-startup --python scripts/compare_sheet.py -- --round 01 [--calibrate-hero] [--no-save]

Writes review/round_NN/{front,right,rear,hero,top,underside}.png (EEVEE renders), mask_<view>.png, compare_<view>.png
(sheet crop | render | overlay), compare_02.png (all six), metrics.json; saves source/PantryRat_R02.blend.
Overlay tile: render at 45 % with the SHEET silhouette edge in red and the MODEL silhouette edge in cyan.
Cameras: fixed transforms derived from the sheet-02 calibration below (never refit to the model), so rounds diff.
Refuses to overwrite an existing round folder. Prints PANTRY_RAT_OK / PANTRY_RAT_FAIL.
"""
import json
import math
import os
import sys
import time
import traceback

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import rat_common as rc  # noqa: E402
import rat_model as rm  # noqa: E402
from rat_common import PAL, PART  # noqa: E402

ROOT = os.path.dirname(HERE)
CROPS = os.path.join(ROOT, "review", "sheet_crops")
BLEND = os.path.join(ROOT, "source", "PantryRat_R02.blend")
SHEET_BG = (0.9961, 0.9765, 0.9451)
UPS = 2  # render resolution = crop size x UPS

# ---------------------------------------------------------------- sheet-02 calibration (sheet px, top-left origin)
# Panels as cropped by sheet_measure.py. Side: 6.6 px/cm (back top 205 -> floor 438 = 35 cm), x0 = 675.5 (centre between
# nose 871 and rump 480). Front / rear 6.66 / 6.6 px/cm (whole-silhouette height ratio vs the side), floor 440, body
# centre columns 198 / 1048. Top / underside 5.55 / 5.5 px/cm (nose-to-rump 324 / 322 px vs the side's 59.2 cm),
# nose row 548, centre columns 775.5 / 1062.5. World nose x = +29.6.
PANELS = {"front": (22, 142, 352, 452), "right": (366, 142, 894, 452), "rear": (906, 142, 1204, 452),
          "hero": (16, 545, 634, 998), "top": (646, 545, 906, 998), "underside": (916, 545, 1208, 998)}
NOSE_X = 29.6


def ortho_views():
    v = {}
    x0, y0, x1, y1 = PANELS["right"]
    s = 6.6
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    v["right"] = dict(d=(0, 1, 0), up=(0, 0, 1), c=((cx - 675.5) / s, 0.0, (438 - cy) / s), scale=max(x1 - x0, y1 - y0) / s)
    x0, y0, x1, y1 = PANELS["front"]
    s = 6.66
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    v["front"] = dict(d=(-1, 0, 0), up=(0, 0, 1), c=(0.0, (cx - 198) / s, (440 - cy) / s), scale=max(x1 - x0, y1 - y0) / s)
    x0, y0, x1, y1 = PANELS["rear"]
    s = 6.6
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    v["rear"] = dict(d=(1, 0, 0), up=(0, 0, 1), c=(0.0, -(cx - 1048) / s, (440 - cy) / s), scale=max(x1 - x0, y1 - y0) / s)
    x0, y0, x1, y1 = PANELS["top"]
    s = 5.55
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    v["top"] = dict(d=(0, 0, -1), up=(1, 0, 0), c=(NOSE_X - (cy - 548) / s, -(cx - 775.5) / s, 0.0),
                    scale=max(x1 - x0, y1 - y0) / s)
    x0, y0, x1, y1 = PANELS["underside"]
    s = 5.5
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    v["underside"] = dict(d=(0, 0, 1), up=(1, 0, 0), c=(NOSE_X - (cy - 548) / s, (cx - 1062.5) / s, 0.0),
                          scale=max(x1 - x0, y1 - y0) / s)
    return v


# Hero (perspective): az = camera azimuth from the rat's right side toward its front, el = elevation; target, distance,
# lens and shift fitted ONCE (--calibrate-hero on the round-01 model) to the sheet hero silhouette bbox, then frozen here.
HERO = dict(az=31.6672, el=2.6971, target=(0.0, 0.0, 18.0), dist=111.994, lens=50.0, shift=(-0.052231, 0.011748))
# ^ frozen from `--round 01 --calibrate-hero` (round-01 model, 6 landmarks, rms 22.7 crop px; PROGRESS.md "Calibration")


def look(cam, eye, target, up):
    eye, target, up = Vector(eye), Vector(target), Vector(up)
    zc = (eye - target).normalized()
    xc = up.cross(zc).normalized()
    yc = zc.cross(xc)
    m = Matrix((xc, yc, zc)).transposed().to_4x4()
    m.translation = eye
    cam.matrix_world = m


def hero_eye():
    az, el = math.radians(HERO["az"]), math.radians(HERO["el"])
    d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    return Vector(HERO["target"]) + d * HERO["dist"]


# ---------------------------------------------------------------- images
def load_px(path):
    im = bpy.data.images.load(path, check_existing=False)
    w, h = im.size
    px = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1].copy()   # top-left origin
    bpy.data.images.remove(im)
    return px


def save_px(px, path):
    h, w = px.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=False)
    out = np.ones((h, w, 4), dtype=np.float32)
    out[..., :3] = px[..., :3]
    img.pixels.foreach_set(np.ascontiguousarray(out[::-1]).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def upsample(px, k):
    return px.repeat(k, axis=0).repeat(k, axis=1)


def sheet_mask(rgb):
    """Rat pixels of a sheet crop: saturated or dark (the cream ground and the grey floor shadow are neither), then a
    3x3 opening so isolated contact-shadow specks drop out."""
    sat = rgb.max(-1) - rgb.min(-1)
    m = (sat > 0.14) | (rgb.max(-1) < 0.56)   # contact shadow measured sat <= 0.119, max >= 0.676
    e = m.copy()
    e[1:-1, 1:-1] = m[1:-1, 1:-1] & m[:-2, 1:-1] & m[2:, 1:-1] & m[1:-1, :-2] & m[1:-1, 2:]
    d = e.copy()
    d[1:-1, 1:-1] = e[1:-1, 1:-1] | e[:-2, 1:-1] | e[2:, 1:-1] | e[1:-1, :-2] | e[1:-1, 2:]
    return d


def edge(m):
    e = np.zeros_like(m)
    e[1:-1, 1:-1] = m[1:-1, 1:-1] & ~(m[:-2, 1:-1] & m[2:, 1:-1] & m[1:-1, :-2] & m[1:-1, 2:])
    # thicken to 2 px
    t = e.copy()
    t[1:, :] |= e[:-1, :]
    t[:, 1:] |= e[:, :-1]
    return t


def resize(px, w, h):
    sh, sw = px.shape[:2]
    ys = np.clip(((np.arange(h) + 0.5) * sh / h).astype(int), 0, sh - 1)
    xs = np.clip(((np.arange(w) + 0.5) * sw / w).astype(int), 0, sw - 1)
    return px[ys][:, xs]


def fit(px, w, h, bg=0.3):
    sh, sw = px.shape[:2]
    k = min(w / sw, h / sh)
    nw, nh = max(1, int(sw * k)), max(1, int(sh * k))
    out = np.full((h, w, 4), bg, dtype=np.float32)
    out[..., 3] = 1
    y0, x0 = (h - nh) // 2, (w - nw) // 2
    out[y0:y0 + nh, x0:x0 + nw] = resize(px, nw, nh)
    return out


def sheet(rows, tw, th, gap=6):
    cols = max(len(r) for r in rows)
    W, H = cols * tw + (cols - 1) * gap, len(rows) * th + (len(rows) - 1) * gap
    out = np.full((H, W, 4), 0.18, dtype=np.float32)
    out[..., 3] = 1
    for r, row in enumerate(rows):
        for c, t in enumerate(row):
            y0, x0 = r * (th + gap), c * (tw + gap)
            out[y0:y0 + th, x0:x0 + tw] = fit(t, tw, th)
    return out


# ---------------------------------------------------------------- scene
def reset_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights, bpy.data.collections):
        for d in list(coll):
            coll.remove(d)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.scale_length = 0.01
    sc.unit_settings.length_unit = "CENTIMETERS"
    sc.render.fps = 30
    rc.MATS.clear()
    for s in rc.SLOTS:
        rc.MATS[s] = rc.make_material(s, PAL[s], 0.85 if s not in ("Wood", "Harness") else 0.6,
                                      eye_preview=(s == "EyePatch"))
    w = sc.world or bpy.data.worlds.new("World")
    sc.world = w
    w.use_nodes = True
    bgn = w.node_tree.nodes["Background"]
    bgn.inputs["Color"].default_value = (*rc.srgb_to_lin(SHEET_BG), 1.0)
    bgn.inputs["Strength"].default_value = 0.55
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0.0
    sc.render.engine = "BLENDER_EEVEE"
    sc.eevee.taa_render_samples = 32
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    return sc


def make_floor(sc):
    me = bpy.data.meshes.new("ReviewFloor")
    s = 150.0
    me.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    ob = bpy.data.objects.new("ReviewFloor", me)
    sc.collection.objects.link(ob)
    m = bpy.data.materials.new("FloorGrid10cm")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.9
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])

    def mnode(op, a, b=None):
        n = nt.nodes.new("ShaderNodeMath")
        n.operation = op
        for i, x in enumerate((a, b)):
            if x is None:
                continue
            if isinstance(x, (int, float)):
                n.inputs[i].default_value = x
            else:
                nt.links.new(x, n.inputs[i])
        return n.outputs[0]

    def line(c):
        f = mnode("FRACT", mnode("DIVIDE", mnode("ADD", c, 0.15), 10.0))
        return mnode("LESS_THAN", f, 0.03)
    g = mnode("MAXIMUM", line(sep.outputs["X"]), line(sep.outputs["Y"]))
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = (*rc.srgb_to_lin((0.62, 0.62, 0.62)), 1)
    mix.inputs["B"].default_value = (*rc.srgb_to_lin((0.36, 0.36, 0.36)), 1)
    nt.links.new(g, mix.inputs["Factor"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    me.materials.append(m)
    return ob


def make_lights(sc):
    # neutral three-point, fixed in world space (key front-right-above, fill left, rim behind) + a weak underside fill
    for name, (d, e, ang) in {"Key": ((0.55, -0.6, 0.85), 3.2, 20), "Fill": ((-0.3, 0.8, 0.5), 1.1, 40),
                              "Rim": ((-0.9, 0.2, 0.5), 1.8, 15), "Under": ((0.1, -0.2, -1.0), 0.6, 40)}.items():
        ld = bpy.data.lights.new("L_" + name, "SUN")
        ld.energy, ld.angle = e, math.radians(ang)
        ob = bpy.data.objects.new("L_" + name, ld)
        sc.collection.objects.link(ob)
        ob.rotation_euler = Vector(d).normalized().to_track_quat("Z", "Y").to_euler()


def build_rat(sc):
    res = rm.build()
    full = res["full"]
    coll = sc.collection
    ob = full.to_object("PantryRat_R02_Body", coll, groups=False)
    me = ob.data
    if "UV0" not in me.uv_layers:
        me.uv_layers.new(name="UV0")
    uvl = me.uv_layers["UV0"]
    for poly in me.polygons:
        uv = full.fuv[poly.index]
        if uv:
            for k, li in enumerate(poly.loop_indices):
                uvl.data[li].uv = uv[k]
    return ob, res


# ---------------------------------------------------------------- measurements
def measure(ob, res):
    me = ob.data
    co = np.array([v.co[:] for v in me.vertices])
    parts = np.empty(len(me.polygons), dtype=np.int64)
    me.attributes["part"].data.foreach_get("value", parts)
    vpart = {}
    for p in me.polygons:
        for i in p.vertices:
            vpart.setdefault(i, set()).add(int(parts[p.index]))
    torso = np.array([i for i, s in vpart.items() if PART["torso"] in s])
    head = np.array([i for i, s in vpart.items() if PART["head"] in s])
    T = co[torso]
    sh_x = rm.P["FORE"][0][0] * rm.S
    band = T[np.abs(T[:, 0] - sh_x) <= 3.0]
    me.calc_loop_triangles()
    tail_root_x = rm.P["TAIL"][0][0] * rm.S
    loft_ids = np.array([i for i, s in vpart.items() if (PART["torso"] in s or PART["head"] in s)])
    L = co[loft_ids]
    out = {
        "back_top_cm (torso max z)": float(T[:, 2].max()),
        "withers_cm (torso max z, shoulder joint x %.1f +-3)" % sh_x: float(band[:, 2].max()),
        "nose_to_tail_tip_cm (mesh X extent)": float(co[:, 0].max() - co[:, 0].min()),
        "nose_to_rump_cm (loft X extent, tail excluded)": float(L[:, 0].max() - L[:, 0].min()),
        "trunk_cm (rump to neck x=7.0, head and tail excluded)": float(7.0 * rm.S - L[:, 0].min()),
        "body_width_cm (torso Y extent)": float(T[:, 1].max() - T[:, 1].min()),
        "width_all_cm (incl. legs, ears, spoon)": float(co[:, 1].max() - co[:, 1].min()),
        "height_incl_spoon_cm": float(co[:, 2].max()),
        "belly_min_z_cm": float(T[:, 2].min()),
        "head_length_cm (x 7.0 to nose)": float(co[:, 0].max() - 7.0 * rm.S),
        "tail_length_cm (along the curve)": res["info"]["tail_length_cm"],
        "tail_root_x": tail_root_x,
        "tris": len(me.loop_triangles), "verts": len(me.vertices),
        "influences": "n/a until R5 (not skinned)",
        "tris_per_part_source": res["info"]["tris_per_part_source"],
        "tris_per_slot": {s: int(sum(1 for p in me.polygons if p.material_index == i) +
                                 sum(len(p.vertices) - 3 for p in me.polygons if p.material_index == i))
                          for i, s in enumerate(rc.SLOTS)},
        "spoon": res["info"]["spoon"], "band_max_lift_cm": res["info"]["band_max_lift"],
    }
    # den proxy (neutral, standing): 2D distance of the rat's YZ hull to the 60 x 60 arch outline (30 cm jambs + r 30
    # head). The R5 audit measures the crouched den clip against the R01 den mesh; this is a standing upper bound check.
    pts = co[:, 1:3]
    arch = []
    for k in range(200):
        t = k / 199
        if t < 0.25:
            arch.append((-30.0, 30.0 * t / 0.25))
        elif t < 0.75:
            a = math.pi * (1 - (t - 0.25) / 0.5)
            arch.append((30.0 * math.cos(a), 30.0 + 30.0 * math.sin(a)))
        else:
            arch.append((30.0, 30.0 * (1 - (t - 0.75) / 0.25)))
    arch = np.array(arch)
    d = np.sqrt(((pts[:, None, :] - arch[None, :, :]) ** 2).sum(-1)).min()
    out["den_arch_clearance_standing_cm (proxy, not the R5 audit)"] = float(d)
    # rest-pose interpenetration of the parts that must stay apart (BVH triangle-pair overlaps / unsigned min distance)
    from mathutils.bvhtree import BVHTree
    tri_v = [tuple(t.vertices) for t in me.loop_triangles]
    tri_p = [int(parts[t.polygon_index]) for t in me.loop_triangles]
    verts = [v.co.copy() for v in me.vertices]

    def tree(tags):
        fs = [f for f, p in zip(tri_v, tri_p) if p in tags]
        return BVHTree.FromPolygons(verts, fs, all_triangles=True), sorted({i for f in fs for i in f})
    pairs = {"spoon-ears": ((PART["spoon"],), (PART["ear"],)), "spoon-head": ((PART["spoon"],), (PART["head"],)),
             "spoon-torso": ((PART["spoon"],), (PART["torso"],)), "ears-head": ((PART["ear"],), (PART["head"],)),
             "jaw-nose": ((PART["jaw"],), (PART["nose"],)),
             "strap-spoon": ((PART["strap"],), (PART["spoon"],)), "girth-spoon": ((PART["band"],), (PART["spoon"],)),
             "strap-legs": ((PART["strap"],), (PART["leg_upper"],))}
    ov = {}
    for k, (ta, tb) in pairs.items():
        A, ia = tree(ta)
        B, ib = tree(tb)
        dmin = min(B.find_nearest(verts[i])[3] for i in ia)
        ov[k] = {"overlap_tris": len(A.overlap(B)), "min_dist_cm": round(float(dmin), 3)}
    out["rest_contacts"] = ov
    # eye patch UVs (the frozen R01 convention): LEFT (+Y) U in [0, 0.5] back -> front, RIGHT (-Y) U in [0.5, 1]
    # front -> back, V 0..1 (up)
    uvl = me.uv_layers["UV0"]
    eu = {"left_+Y": [], "right_-Y": []}
    for poly in me.polygons:
        if parts[poly.index] != PART["eyepatch"]:
            continue
        for li, vi in zip(poly.loop_indices, poly.vertices):
            co_ = me.vertices[vi].co
            eu["left_+Y" if co_.y > 0 else "right_-Y"].append((uvl.data[li].uv[0], uvl.data[li].uv[1], co_.x, co_.z))
    uvr = {}
    for k, l in eu.items():
        a_ = np.array(l)
        u, v, x, z = a_[:, 0], a_[:, 1], a_[:, 2], a_[:, 3]
        # direction check: corr(U, x) must be + on the left (front = high U) and - on the right (front = low U)
        cu = float(np.corrcoef(u, x)[0, 1])
        cv = float(np.corrcoef(v, z)[0, 1])
        uvr[k] = {"u": [round(float(u.min()), 4), round(float(u.max()), 4)], "v": [round(float(v.min()), 4),
                  round(float(v.max()), 4)], "corr_u_x": round(cu, 3), "corr_v_z": round(cv, 3), "loops": len(l)}
    L_, R_ = uvr["left_+Y"], uvr["right_-Y"]
    uvr["convention_holds"] = bool(L_["u"][0] >= -1e-4 and L_["u"][1] <= 0.5 + 1e-4 and R_["u"][0] >= 0.5 - 1e-4 and
                                   R_["u"][1] <= 1 + 1e-4 and L_["v"][0] >= -1e-4 and L_["v"][1] <= 1 + 1e-4 and
                                   L_["corr_u_x"] > 0.9 and R_["corr_u_x"] < -0.9 and L_["corr_v_z"] > 0.9 and
                                   R_["corr_v_z"] > 0.9)
    out["eye_patch_uv"] = uvr
    out["harness"] = {"strap": res["info"].get("strap"), "strap_max_lift_cm": res["info"].get("strap_max_lift"),
                      "cuffs": res["info"].get("cuffs"), "belly_faces": res["info"].get("belly_faces")}
    return out


# ---------------------------------------------------------------- render
def set_cam_ortho(cam, v, res):
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = v["scale"]
    cam.data.shift_x = cam.data.shift_y = 0.0
    cam.data.clip_start, cam.data.clip_end = 1.0, 3000.0
    c = Vector(v["c"])
    look(cam, c - Vector(v["d"]) * 800.0, c, v["up"])


def set_cam_hero(cam):
    cam.data.type = "PERSP"
    cam.data.lens = HERO["lens"]
    cam.data.sensor_fit = "AUTO"
    cam.data.sensor_width = 36.0
    cam.data.shift_x, cam.data.shift_y = HERO["shift"]
    cam.data.clip_start, cam.data.clip_end = 1.0, 3000.0
    look(cam, hero_eye(), HERO["target"], (0, 0, 1))


# hero landmarks read off the sheet-02 hero panel (sheet px): nose tip, near (right) eye, far (left) eye, near fore
# toes, near hind toes, far fore toes
HERO_SHEET_LM = {"nose": (591, 824), "eye_r": (472, 773), "eye_l": (559, 768), "fore_toe_r": (407, 913),
                 "hind_toe_r": (184, 913), "fore_toe_l": (481, 908)}


def hero_model_lm(res):
    F, Hd = rm.P["FORE"], rm.P["HIND"]
    s = rm.S
    nz = (rm.P["NOSE"]["z0"] + rm.P["NOSE"]["z1"]) / 2
    return {"nose": Vector((rm.P["NOSE"]["x1"], 0, nz)) * s, "eye_r": res["land"]["eye_r"], "eye_l": res["land"]["eye_l"],
            "fore_toe_r": Vector((F[3][0], -F[3][1], 0.6)) * s, "hind_toe_r": Vector((Hd[3][0], -Hd[3][1], 0.6)) * s,
            "fore_toe_l": Vector((F[3][0], F[3][1], 0.6)) * s}


def calibrate_hero(sc, cam, res):
    """Fit az / el / dist / shift (lens 50, target fixed) so six model landmarks project onto the sheet hero landmarks
    (Gauss-Newton on the image-space residual). Run once on the round-01 model, then freeze HERO."""
    x0, y0, x1, y1 = PANELS["hero"]
    W, H = x1 - x0, y1 - y0
    sc.render.resolution_x, sc.render.resolution_y = W * UPS, H * UPS
    lm = hero_model_lm(res)
    keys = list(HERO_SHEET_LM)
    tgt = np.array([((HERO_SHEET_LM[k][0] - x0) / W, 1 - (HERO_SHEET_LM[k][1] - y0) / H) for k in keys])

    def resid(q):
        HERO["az"], HERO["el"], HERO["dist"], HERO["shift"] = q[0], q[1], q[2], (q[3], q[4])
        set_cam_hero(cam)
        bpy.context.view_layer.update()
        p = np.array([tuple(world_to_camera_view(sc, cam, lm[k]))[:2] for k in keys])
        return (p - tgt).ravel()
    q = np.array([40.0, 10.0, 190.0, 0.0, 0.0])
    for it in range(30):
        r0 = resid(q)
        J = np.zeros((len(r0), len(q)))
        for k, h in enumerate((0.2, 0.2, 1.0, 0.002, 0.002)):
            dq = q.copy()
            dq[k] += h
            J[:, k] = (resid(dq) - r0) / h
        step = np.linalg.lstsq(J, -r0, rcond=None)[0]
        q = q + step * 0.8
    r = resid(q)
    print("HERO_CALIBRATED", json.dumps({k: (list(v) if isinstance(v, tuple) else v) for k, v in HERO.items()}),
          "rms_px", round(float(np.sqrt((((r.reshape(-1, 2)) * np.array([W, H])) ** 2).sum(1).mean())), 2),
          "per_landmark_px", {k: [round(float(a * W), 1), round(float(b * H), 1)] for k, (a, b) in zip(keys, r.reshape(-1, 2))})


def render_view(sc, cam, name, floor, out_dir):
    x0, y0, x1, y1 = PANELS[name]
    sc.render.resolution_x, sc.render.resolution_y = (x1 - x0) * UPS, (y1 - y0) * UPS
    sc.render.resolution_percentage = 100
    sc.camera = cam
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.film_transparent = False
    floor.hide_render = name == "underside"
    path = os.path.join(out_dir, name + ".png")
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    # silhouette mask: rat only, transparent film, floor hidden
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "FLAT"
    sc.display.shading.color_type = "SINGLE"
    sc.display.render_aa = "OFF"
    sc.render.film_transparent = True
    floor.hide_render = True
    mpath = os.path.join(out_dir, "mask_" + name + ".png")
    sc.render.filepath = mpath
    bpy.ops.render.render(write_still=True)
    sc.render.film_transparent = False
    floor.hide_render = False
    return path, mpath


def main():
    t0 = time.time()
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    rnd = argv[argv.index("--round") + 1] if "--round" in argv else None
    calib = "--calibrate-hero" in argv
    if not rnd:
        raise SystemExit("--round NN required")
    out_dir = os.path.join(ROOT, "review", "round_%s" % rnd)
    if "--out" in argv:   # harness debugging only (scratch folder outside review/)
        out_dir = os.path.abspath(argv[argv.index("--out") + 1])
    if os.path.exists(out_dir) and os.listdir(out_dir):
        raise SystemExit("round folder %s exists and is not empty (never overwrite an earlier round)" % out_dir)
    os.makedirs(out_dir, exist_ok=True)
    sc = reset_scene()
    floor = make_floor(sc)
    make_lights(sc)
    ob, res = build_rat(sc)
    camd = bpy.data.cameras.new("ReviewCam")
    cam = bpy.data.objects.new("ReviewCam", camd)
    sc.collection.objects.link(cam)
    if calib:
        calibrate_hero(sc, cam, res)
    M = measure(ob, res)
    print("MEASURE", json.dumps(M, default=str))
    views = ortho_views()
    metrics = {"round": rnd, "measure": M, "iou": {}, "hero_camera": {k: (list(v) if isinstance(v, tuple) else v)
                                                                       for k, v in HERO.items()},
               "ortho_cameras": views, "params": {k: v for k, v in rm.P.items()}, "scale": rm.S}
    rows = []
    for name in ("front", "right", "rear", "hero", "top", "underside"):
        if name == "hero":
            set_cam_hero(cam)
        else:
            set_cam_ortho(cam, views[name], None)
        path, mpath = render_view(sc, cam, name, floor, out_dir)
        crop = load_px(os.path.join(CROPS, name + ".png"))
        sm = upsample(sheet_mask(crop[..., :3]), UPS)
        rimg = load_px(path)
        mm = load_px(mpath)[..., 3] > 0.5
        h, w = min(sm.shape[0], mm.shape[0]), min(sm.shape[1], mm.shape[1])
        sm, mm = sm[:h, :w], mm[:h, :w]
        inter, uni = (sm & mm).sum(), (sm | mm).sum()
        metrics["iou"][name] = {"iou": round(float(inter / max(uni, 1)), 4),
                                "sheet_px": int(sm.sum()), "model_px": int(mm.sum()),
                                "model_only_px": int((mm & ~sm).sum()), "sheet_only_px": int((sm & ~mm).sum())}
        ov = rimg[:h, :w].copy()
        ov[..., :3] = ov[..., :3] * 0.45 + 0.3
        es, em = edge(sm), edge(mm)
        ov[es, :3] = (1.0, 0.1, 0.1)
        ov[em, :3] = (0.1, 0.9, 1.0)
        cu = upsample(crop, UPS)[:h, :w]
        tri = sheet([[cu, rimg[:h, :w], ov]], w, h)
        save_px(tri, os.path.join(out_dir, "compare_%s.png" % name))
        rows.append([cu, rimg[:h, :w], ov])
    allrows = [rows[0] + rows[1], rows[2] + rows[3], rows[4] + rows[5]]
    save_px(sheet(allrows, 440, 330), os.path.join(out_dir, "compare_02.png"))
    metrics["seconds"] = round(time.time() - t0, 1)
    with open(os.path.join(out_dir, "metrics.json"), "w") as fh:
        json.dump(metrics, fh, indent=1, default=lambda o: list(o) if isinstance(o, (Vector, tuple)) else str(o))
    print("IOU", json.dumps(metrics["iou"]))
    if "--no-save" not in argv:
        os.makedirs(os.path.dirname(BLEND), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=BLEND, check_existing=False)
    print("PANTRY_RAT_OK round %s %.1fs" % (rnd, time.time() - t0))


if __name__ == "__main__" and "compare_sheet.py" in " ".join(sys.argv):
  try:
    main()
  except SystemExit as e:
    print("PANTRY_RAT_FAIL", e)
    sys.exit(1)
  except Exception:
    traceback.print_exc()
    print("PANTRY_RAT_FAIL")
    sys.exit(1)
