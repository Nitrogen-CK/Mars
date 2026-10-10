"""Mars candles: the fixed set of candle props built with candle_gen (the SDF candle generator), as a re-runnable
headless Blender 5.2 build. The scene is rebuilt from nothing every run, from fixed seeds.

  CandleSingle_A_Mars_SM    1  a short, burnt-down stub in its own puddle
  CandleSingle_B_Mars_SM    1  a medium candle
  CandleSingle_C_Mars_SM    1  a tall pillar
  CandleCluster_A_Mars_SM   3  a loose trio (separate candles, shared puddle)
  CandleCluster_B_Mars_SM   4  a tight clump fused into one mass
  CandleCluster_C_Mars_SM   5  tall and short together
  CandleCluster_D_Mars_SM   5  a mostly melted, low group
  CandleCluster_E_Mars_SM   7  a wide, puddled group
  CandleCluster_F_Mars_SM   9  a big shrine cluster (mixed colours)

Every mesh: slots Wax / Wick / Flame, "Col" vertex colours, UV0 "UVMap" + UV1 "CandleData" (candle id, glow / flame
height; see candle_gen's docstring), a SOCKET_Flame_NN empty per flame, no collision. Singles <= 600 tris, clusters
<= 3500 (the nine-candle one <= 5000).

Run:
  blender -b --factory-startup --python build_candles.py -- [--export] [--save] [--sheets] [--only <name part>]
    --export   FBX + JSON sidecar per variant into D:\\Repo\\Content\\Cooking\\export\\candles, then a re-import check
    --sheets   review sheets into its review subfolder: one per variant (iso / front / top), the line-up of all nine
               with a 30 cm bar, and the parameter sweep (height_variation, blend_cm, melt at one seed)
    --save     D:\\Repo\\Content\\Cooking\\candles\\Candles.blend
Prints CANDLES_OK when every check passed (CANDLES_FAIL + the reasons otherwise).
"""
import json
import math
import os
import sys
import time

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import candle_gen as cg          # noqa: E402
import food_common as fc         # noqa: E402
import food_spec                 # noqa: E402

# the food helpers read these module attributes at call time (ensure_dirs, review_sheet): point them at the candles
food_spec.BLEND_DIR = cg.BLEND_DIR
food_spec.EXPORT_DIR = cg.EXPORT_DIR
food_spec.REVIEW_DIR = cg.REVIEW_DIR
BLEND_FILE = os.path.join(cg.BLEND_DIR, "Candles.blend")

P = cg.CandleParams
VARIANTS = (
    # name, tris budget, params
    ("CandleSingle_A_Mars_SM", 600, P(seed=101, count=1, radius_min_cm=3.3, radius_max_cm=3.3, height_min_cm=5.5,
                                      height_max_cm=5.5, blend_cm=1.4, melt=0.9, palette="cream", lean=0.3,
                                      voxel_cm=0.3, target_tris=600)),
    ("CandleSingle_B_Mars_SM", 600, P(seed=102, count=1, radius_min_cm=2.6, radius_max_cm=2.6, height_min_cm=13.0,
                                      height_max_cm=13.0, blend_cm=1.2, melt=0.6, palette="tallow", lean=0.5,
                                      voxel_cm=0.3, target_tris=600)),
    ("CandleSingle_C_Mars_SM", 600, P(seed=103, count=1, radius_min_cm=2.2, radius_max_cm=2.2, height_min_cm=27.0,
                                      height_max_cm=27.0, blend_cm=1.0, melt=0.4, palette="cream", lean=0.6,
                                      voxel_cm=0.3, target_tris=600)),
    ("CandleCluster_A_Mars_SM", 3500, P(seed=211, count=3, radius_min_cm=2.0, radius_max_cm=3.2, height_min_cm=8.0,
                                        height_max_cm=19.0, height_variation=0.8, spread_cm=3.2, blend_cm=1.5,
                                        melt=0.5, palette="cream", target_tris=2200)),
    ("CandleCluster_B_Mars_SM", 3500, P(seed=222, count=4, radius_min_cm=2.2, radius_max_cm=3.6, height_min_cm=9.0,
                                        height_max_cm=17.0, height_variation=0.7, spread_cm=-0.5, blend_cm=2.6,
                                        blend_top=0.35, melt=0.6, palette="tallow", target_tris=2800)),
    ("CandleCluster_C_Mars_SM", 3500, P(seed=233, count=5, radius_min_cm=1.5, radius_max_cm=3.4, height_min_cm=4.5,
                                        height_max_cm=30.0, height_variation=1.0, spread_cm=0.3, blend_cm=1.6,
                                        melt=0.45, palette="mixed", accent_chance=0.25, target_tris=3200)),
    ("CandleCluster_D_Mars_SM", 3500, P(seed=244, count=5, radius_min_cm=2.4, radius_max_cm=4.4, height_min_cm=4.0,
                                        height_max_cm=9.5, height_variation=0.9, spread_cm=0.9, blend_cm=1.4,
                                        melt=0.9, palette="tallow", lean=0.3, target_tris=3000)),
    ("CandleCluster_E_Mars_SM", 3500, P(seed=255, count=7, radius_min_cm=1.6, radius_max_cm=3.6, height_min_cm=5.0,
                                        height_max_cm=18.0, height_variation=0.85, spread_cm=2.6, blend_cm=2.0,
                                        blend_top=0.4, melt=0.85, palette="cream", target_tris=3450)),
    ("CandleCluster_F_Mars_SM", 5000, P(seed=266, count=9, radius_min_cm=1.4, radius_max_cm=4.2, height_min_cm=5.0,
                                        height_max_cm=30.0, height_variation=1.0, spread_cm=0.35, blend_cm=2.0,
                                        melt=0.6, palette="mixed", accent_chance=0.3, target_tris=4900)),
)
SWEEP_BASE = P(seed=5, count=5, radius_min_cm=1.8, radius_max_cm=3.4, height_min_cm=6.0, height_max_cm=26.0,
               height_variation=0.8, spread_cm=0.3, blend_cm=1.5, melt=0.5, palette="mixed", accent_chance=0.25,
               target_tris=3000)
SWEEP = (("height_variation", (0.0, 0.5, 1.0)), ("blend_cm", (0.0, 1.5, 4.0)), ("melt", (0.0, 0.5, 1.0)))

BACKGROUND = (0.035, 0.032, 0.04)
VIEWS = {"iso": (0.85, -1.0, 0.62), "front": (0.0, -1.0, 0.1), "top": (0.0, -0.001, 1.0), "low": (0.5, -1.0, 0.3)}


def broadside(info, skew=0.0, elevation=0.1):
    """A view direction (camera offset from the target) that looks at the cluster across its long axis, so the
    candles stand side by side instead of behind each other. skew turns it toward an iso view."""
    pts = np.array([[c["base_cm"][0], -c["base_cm"][1]] for c in info["candles"]])
    if len(pts) < 2:
        return (skew, -1.0, elevation)
    w, v = np.linalg.eigh(np.cov((pts - pts.mean(axis=0)).T))
    along = v[:, np.argmax(w)]
    across = np.array([along[1], -along[0]])
    if across[1] > 0.0:
        across, along = -across, -along
    d = across + skew * along
    return (float(d[0]), float(d[1]), elevation * float(np.linalg.norm(d)))


# ================================================================ checks
def check_variant(obj, info, budget, params):
    """Problems with a generated candle against the mesh contract (empty list = fine)."""
    fails = []
    mesh = obj.data
    name = obj.name
    tris = fc.tri_count(obj)
    if tris > budget:
        fails.append("%s tris %d > %d" % (name, tris, budget))
    if any(len(pl.vertices) != 3 for pl in mesh.polygons):
        fails.append("%s is not all triangles" % name)
    slots = [m.name for m in mesh.materials]
    if slots != list(cg.SLOTS):
        fails.append("%s slots %s" % (name, slots))
    uvs = [u.name for u in mesh.uv_layers]
    if uvs != ["UVMap", cg.DATA_UV]:
        fails.append("%s uv layers %s" % (name, uvs))
    if cg.COLOR_ATTR not in mesh.color_attributes:
        fails.append("%s has no Col" % name)
    if not fc._is_flat(mesh):
        fails.append("%s is not flat shaded" % name)
    v = fc.verts_cm(obj)
    if abs(v[:, 2].min()) > 1e-4:
        fails.append("%s lowest point z %.4f" % (name, v[:, 2].min()))
    low = v[v[:, 2] < 0.05]
    if len(low) < 3 or np.abs(low[:, 2]).max() > 1e-4:
        fails.append("%s underside is not flat on z = 0" % name)
    table = info["candles"]
    if len(table) != params.count:
        fails.append("%s candle table %d != %d" % (name, len(table), params.count))
    socks = [e.get("candle_socket") for e in cg.sockets_of(obj)]
    if socks != ["Flame_%02d" % k for k in range(params.count)]:
        fails.append("%s sockets %s" % (name, socks))
    # colours: wick near black, flame white
    col = np.empty(len(mesh.loops) * 4)
    mesh.color_attributes[cg.COLOR_ATTR].data.foreach_get("color", col)
    col = col.reshape(-1, 4)
    mat = np.empty(len(mesh.polygons), np.int32)
    mesh.polygons.foreach_get("material_index", mat)
    loop_mat = np.repeat(mat, 3)
    if col[loop_mat == cg.WICK, :3].max() > 0.05:
        fails.append("%s wick is not near black" % name)
    if col[loop_mat == cg.FLAME, :3].min() < 0.999:
        fails.append("%s flame is not white" % name)
    # the data channel
    ranges = cg.data_ranges(mesh)
    ids = sorted(c["id"] for c in table)
    uv = np.empty(len(mesh.loops) * 2)
    mesh.uv_layers[1].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    seen = np.unique(np.round(uv[:, 0], 5))
    if not all(np.abs(np.array(ids) - s).min() < 2e-5 for s in seen):
        fails.append("%s data ids %s are not the candle ids %s" % (name, seen, ids))
    for slot_id, slot in ((cg.WAX, "Wax"), (cg.WICK, "Wick"), (cg.FLAME, "Flame")):
        got = np.unique(np.round(uv[loop_mat == slot_id, 0], 5))
        if len(got) != params.count:
            fails.append("%s %s carries %d ids for %d candles" % (name, slot, len(got), params.count))
    r = ranges
    if abs(r["Flame"]["value"][0]) > 1e-5 or abs(r["Flame"]["value"][1] - 1.0) > 1e-5:
        fails.append("%s flame height range %s" % (name, r["Flame"]["value"]))
    if abs(r["Wick"]["value"][0]) > 1e-6 or abs(r["Wick"]["value"][1]) > 1e-6:
        fails.append("%s wick value range %s" % (name, r["Wick"]["value"]))
    if r["Wax"]["value"][0] < -1e-6 or r["Wax"]["value"][1] > 1.0 + 1e-6 or r["Wax"]["value"][1] < 0.98:
        fails.append("%s wax glow range %s" % (name, r["Wax"]["value"]))
    for c in table:
        if not (1.6 - 1e-6 <= c["flame_width_cm"] <= 2.4 + 1e-6 and 4.0 - 1e-6 <= c["flame_height_cm"] <= 6.5 + 1e-6):
            fails.append("%s flame %d size %.2f x %.2f" % (name, c["index"], c["flame_width_cm"], c["flame_height_cm"]))
    # every flame base stands above the wax at its candle (a wick buried by a neighbour would hide the flame)
    for c in table:
        if c["flame_base_cm"][2] < c["wax_top_cm"] + 0.5:
            fails.append("%s flame %d base %.2f is in the wax (top %.2f)" % (name, c["index"], c["flame_base_cm"][2],
                                                                           c["wax_top_cm"]))
    open_edges = open_edge_count(mesh)
    lo, hi = fc.bounds_cm(obj)
    print("  %-26s tris %4d / %4d  candles %d  size %5.1f x %5.1f x %5.1f cm  open/non-manifold edges %d" % (
        name, tris, budget, params.count, hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2], open_edges))
    for slot in ("Wax", "Wick", "Flame"):
        print("      %-5s tris %4d  id %.4f .. %.4f   value %.4f .. %.4f" % (
            slot, r[slot]["tris"], r[slot]["id"][0], r[slot]["id"][1], r[slot]["value"][0], r[slot]["value"][1]))
    if open_edges and params.closed_base:
        fails.append("%s has %d open / non-manifold edges" % (name, open_edges))
    return fails


def open_edge_count(mesh):
    """Edges that do not have exactly two faces (0 for a set of closed shells)."""
    tri = np.empty(len(mesh.polygons) * 3, np.int64)
    mesh.polygons.foreach_get("vertices", tri)
    tri = tri.reshape(-1, 3)
    e = np.concatenate([tri[:, [0, 1]], tri[:, [1, 2]], tri[:, [2, 0]]])
    e.sort(axis=1)
    _, counts = np.unique(e, axis=0, return_counts=True)
    return int((counts != 2).sum())


def reimport(path, count):
    """Import the FBX, report what Unreal will get, remove it again. Returns (report dict, problems)."""
    stem = os.path.splitext(os.path.basename(path))[0]
    parked = []
    for o in list(bpy.data.objects):                           # names are unique per file: move the originals aside
        if o.name == stem or o.name.startswith("SOCKET_Flame_"):
            parked.append((o, o.name))
            o.name = "_parked_" + o.name
    before = set(bpy.data.objects)
    before_mesh = set(bpy.data.meshes)
    before_mat = set(bpy.data.materials)
    bpy.ops.import_scene.fbx(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    empties = sorted(o.name for o in new if o.type == "EMPTY")
    fails = []
    rep = {}
    if len(meshes) != 1:
        fails.append("reimport %s: %d meshes" % (stem, len(meshes)))
    else:
        o = meshes[0]
        m = o.data
        rep = {"name": o.name, "tris": fc.tri_count(o), "uv_layers": [u.name for u in m.uv_layers],
               "colors": [c.name for c in m.color_attributes], "flat": fc._is_flat(m),
               "slots": [mt.name.split(".")[0] if mt else None for mt in m.materials],
               "ranges": cg.data_ranges(m), "sockets": empties}
        print("  reimport %-26s tris %4d  uv %s  colors %s  flat %s  slots %s  empties %d" % (
            o.name, rep["tris"], rep["uv_layers"], rep["colors"], rep["flat"], rep["slots"], len(empties)))
        for slot, r in rep["ranges"].items():
            print("      %-5s tris %4d  UV1 id %.4f .. %.4f   value (1 - v) %.4f .. %.4f" % (
                slot, r["tris"], r["id"][0], r["id"][1], r["value"][0], r["value"][1]))
        if len(m.uv_layers) != 2 or rep["uv_layers"] != ["UVMap", cg.DATA_UV]:
            fails.append("reimport %s: uv layers %s" % (stem, rep["uv_layers"]))
        if cg.COLOR_ATTR not in rep["colors"]:
            fails.append("reimport %s: colours %s" % (stem, rep["colors"]))
        if not rep["flat"]:
            fails.append("reimport %s: not flat" % stem)
        if rep["slots"] != list(cg.SLOTS):
            fails.append("reimport %s: slots %s" % (stem, rep["slots"]))
        if o.name != stem:
            fails.append("reimport %s: mesh object is named %s" % (stem, o.name))
        r = rep["ranges"]
        if r:
            if abs(r["Flame"]["value"][0]) > 1e-4 or abs(r["Flame"]["value"][1] - 1.0) > 1e-4:
                fails.append("reimport %s: flame height %s" % (stem, r["Flame"]["value"]))
            if abs(r["Wick"]["value"][1]) > 1e-4:
                fails.append("reimport %s: wick value %s" % (stem, r["Wick"]["value"]))
            if r["Wax"]["value"][1] < 0.98 or r["Wax"]["value"][0] < -1e-4:
                fails.append("reimport %s: wax glow %s" % (stem, r["Wax"]["value"]))
    want = ["SOCKET_Flame_%02d" % k for k in range(count)]
    if empties != want:
        fails.append("reimport %s: socket empties %s" % (stem, empties))
    for o in new:
        data = o.data if o.type == "MESH" else None
        bpy.data.objects.remove(o, do_unlink=True)
    for m in [m for m in bpy.data.meshes if m not in before_mesh]:
        bpy.data.meshes.remove(m)
    for m in [m for m in bpy.data.materials if m not in before_mat]:
        bpy.data.materials.remove(m)
    for o, name in parked:
        o.name = name
    return rep, fails


# ================================================================ review renders
def world_bounds(objs):
    lo, hi = np.full(3, 1e9), np.full(3, -1e9)
    for o in objs:
        v = fc.verts_cm(o) * 0.01 + np.array(o.location)
        lo, hi = np.minimum(lo, v.min(axis=0)), np.maximum(hi, v.max(axis=0))
    return lo, hi


def label_object(text, size):
    curve = bpy.data.curves.new("_Label", "FONT")
    curve.body = text
    curve.size = size
    obj = bpy.data.objects.new("_Label", curve)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def world_points(objs):
    return np.concatenate([fc.verts_cm(o) * 0.01 + np.array(o.location) for o in objs])


def render(objs, path, view, size=(800, 800), frame_points=None, label=None, margin=1.08):
    """One workbench render of objs (in place) through an orthographic camera fitted to frame_points (metres,
    (n, 3); default = the objects' own vertices). Every other mesh is hidden. An optional text label sits in the
    lower left corner."""
    scene = bpy.context.scene
    shading = scene.display.shading
    hidden = [o for o in scene.objects if o not in objs and o.type in {"MESH", "FONT"}]
    hidden_state = [o.hide_render for o in hidden]
    cam_data = bpy.data.cameras.new("_ReviewCam")
    cam_data.type = "ORTHO"
    cam_data.clip_start, cam_data.clip_end = 0.01, 100.0
    cam = bpy.data.objects.new("_ReviewCam", cam_data)
    scene.collection.objects.link(cam)
    if scene.world is None:
        scene.world = bpy.data.worlds.new("_ReviewWorld")
    prev = (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
            scene.render.filepath, shading.color_type, shading.light, shading.show_cavity, shading.show_shadows,
            scene.render.film_transparent, tuple(scene.world.color))
    text = None
    try:
        for o in hidden:
            o.hide_render = True
        for o in objs:
            o.hide_render = False
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        shading.light = "STUDIO"
        shading.color_type = "VERTEX"
        shading.show_cavity = True
        shading.show_shadows = False
        scene.render.film_transparent = False
        scene.world.color = BACKGROUND
        scene.render.resolution_x, scene.render.resolution_y = size
        scene.render.resolution_percentage = 100
        lo, hi = world_bounds(objs)
        centre = 0.5 * (np.asarray(lo) + np.asarray(hi))
        d = np.array(VIEWS[view] if isinstance(view, str) else view, float)
        d /= np.linalg.norm(d)
        fc._look_at(cam, tuple(centre + d * 20.0), tuple(centre))
        bpy.context.view_layer.update()
        mw = np.array(cam.matrix_world)
        right, up = mw[:3, 0], mw[:3, 1]
        pts = (frame_points if frame_points is not None else world_points(objs)) - centre
        pr, pu = pts @ right, pts @ up
        shift = right * 0.5 * (pr.min() + pr.max()) + up * 0.5 * (pu.min() + pu.max())     # centre what is seen
        w, h = pr.max() - pr.min(), pu.max() - pu.min()
        aspect = size[0] / size[1]
        scale = max(w, h * aspect) * margin                    # ortho_scale = the frame's width
        if label:
            scale = max(w, (h / 0.88) * aspect) * margin
            shift = shift - up * 0.05 * (scale / aspect)
        cam.location = tuple(np.array(cam.location) + shift)
        cam_data.ortho_scale = scale
        if label:
            text = label_object(label, (scale / aspect) * 0.036)
            text.rotation_euler = cam.rotation_euler
            text.location = tuple(centre + shift + d * 10.0 - right * scale * 0.48 - up * (scale / aspect) * 0.47)
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
    finally:
        for o, hr in zip(hidden, hidden_state):
            o.hide_render = hr
        (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
         scene.render.filepath, shading.color_type, shading.light, shading.show_cavity, shading.show_shadows,
         scene.render.film_transparent) = prev[:10]
        scene.world.color = prev[10]
        bpy.data.objects.remove(cam)
        bpy.data.cameras.remove(cam_data)
        if text is not None:
            curve = text.data
            bpy.data.objects.remove(text)
            bpy.data.curves.remove(curve)
    return path


def painted_box(name, centre_cm, size_cm, rgb):
    """A plain box mesh with a flat "Col" (review furniture: the scale bar)."""
    c = np.asarray(centre_cm, float)
    hx, hy, hz = np.asarray(size_cm, float) * 0.5
    v = np.array([[-hx, -hy, -hz], [hx, -hy, -hz], [hx, hy, -hz], [-hx, hy, -hz],
                  [-hx, -hy, hz], [hx, -hy, hz], [hx, hy, hz], [-hx, hy, hz]]) + c
    f = [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata((v * 0.01).tolist(), [], f)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    fc.paint(obj, np.repeat(np.asarray(rgb, float)[None, :], len(f), axis=0), variation=0.0, cavity_darken=0.0)
    return obj


def scale_bar(origin_cm):
    """30 cm bar in three alternating 10 cm segments."""
    out = []
    for k in range(3):
        rgb = fc.srgb(235, 235, 235) if k % 2 == 0 else fc.srgb(205, 45, 45)
        out.append(painted_box("_Bar%d" % k, (origin_cm[0] + 5.0 + 10.0 * k, origin_cm[1], origin_cm[2] + 0.75),
                               (10.0, 1.5, 1.5), rgb))
    return out


def remove(objs):
    for o in objs:
        data = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if data is not None and data.users == 0:
            (bpy.data.meshes if isinstance(data, bpy.types.Mesh) else bpy.data.curves).remove(data)


def render_sheets(built):
    sheets = []
    os.makedirs(cg.REVIEW_DIR, exist_ok=True)
    # one sheet per variant: iso / front / top
    for obj, info, budget, params in built:
        stem = obj.name.replace(cg.SUFFIX, "")
        label = "%s   %d candle%s   %d tris" % (stem, params.count, "" if params.count == 1 else "s", info["tris"])
        views = (("iso", broadside(info, 0.7, 0.62)), ("front", broadside(info, 0.0, 0.1)), ("top", "top"))
        paths = [render([obj], os.path.join(cg.REVIEW_DIR, "%s_%s.png" % (stem, key)), view, size=(900, 900),
                        label=label if key == "iso" else key)
                 for key, view in views]
        sheets.append(fc.tile_images(paths, os.path.join(cg.REVIEW_DIR, "%s_sheet.png" % stem), cols=3))
        for pth in paths:
            os.remove(pth)
    # the line-up of every variant with a 30 cm bar
    saved = [tuple(o.location) for o, *_ in built]
    try:
        x = 0.0
        depth = 0.0
        for obj, *_ in built:
            lo, hi = fc.bounds_cm(obj)
            obj.location = ((x - lo[0]) * 0.01, 0.0, 0.0)
            x += (hi[0] - lo[0]) + 7.0
            depth = max(depth, -lo[1])
        bar = scale_bar((0.0, -(depth + 8.0), 0.0))
        objs = [o for o, *_ in built] + bar
        paths = [render(objs, os.path.join(cg.REVIEW_DIR, "Candles_Lineup_%s.png" % view), view, size=(3600, 900),
                        label="all nine variants, bar = 30 cm" if view == "low" else None, margin=1.04)
                 for view in ("low", "top")]
        sheets.append(fc.tile_images(paths, os.path.join(cg.REVIEW_DIR, "Candles_Lineup_sheet.png"), cols=1))
        for pth in paths:
            os.remove(pth)
        remove(bar)
    finally:
        for (obj, *_), loc in zip(built, saved):
            obj.location = loc
    sheets.append(render_data_sheet(built))
    sheets += render_sweep()
    return sheets


def render_data_sheet(built):
    """The UV1 "CandleData" channel painted onto the mesh, as Unreal reads it: left = v (wax glow / flame height,
    black 0 -> orange -> white 1), right = u (the candle id as a hue). Shown on the biggest clusters built."""
    import colorsys
    picks = sorted(built, key=lambda b: -b[3].count)[:2]
    paths = []
    for obj, info, budget, params in picks:
        mesh = obj.data
        stem = obj.name.replace(cg.SUFFIX, "")
        attr = mesh.color_attributes[cg.COLOR_ATTR]
        keep = np.empty(len(mesh.loops) * 4)
        attr.data.foreach_get("color", keep)
        uv = np.empty(len(mesh.loops) * 2)
        mesh.uv_layers[cg.DATA_UV].data.foreach_get("uv", uv)
        uv = uv.reshape(-1, 2)
        ident, value = uv[:, 0], 1.0 - uv[:, 1]
        heat = np.stack([np.clip(value * 2.2, 0.0, 1.0), np.clip(value * 1.6 - 0.35, 0.0, 1.0),
                         np.clip(value * 3.0 - 2.0, 0.0, 1.0), np.ones(len(value))], axis=1)
        heat[:, :3] = heat[:, :3] * 0.96 + 0.04
        hue = np.array([colorsys.hsv_to_rgb(float(u), 0.75, 0.9) + (1.0,) for u in ident])
        view = broadside(info, 0.7, 0.62)
        try:
            for key, colours, label in (("value", heat, "%s  UV1.v: wax glow / flame height (0 black .. 1 white)" % stem),
                                        ("id", hue, "%s  UV1.u: candle id (hue)" % stem)):
                attr.data.foreach_set("color", colours.ravel())
                mesh.update()
                paths.append(render([obj], os.path.join(cg.REVIEW_DIR, "_data_%s_%s.png" % (stem, key)), view,
                                    size=(1100, 1000), label=label))
        finally:
            attr.data.foreach_set("color", keep)
            mesh.update()
    out = fc.tile_images(paths, os.path.join(cg.REVIEW_DIR, "Candles_DataChannel_sheet.png"), cols=2)
    for pth in paths:
        os.remove(pth)
    return out


def render_sweep():
    """The tool's controls at one seed: a row per control, three values each (everything else at SWEEP_BASE)."""
    from dataclasses import replace
    cells = []
    for row, (key, values) in enumerate(SWEEP):
        for col, value in enumerate(values):
            params = replace(SWEEP_BASE, **{key: value})
            obj, info = cg.generate(params, name="_Sweep_%d_%d" % (row, col))
            cells.append((obj, "%s = %g   (%d tris)" % (key, value, info["tris"])))
    everything = world_points([o for o, _ in cells])           # one frame for all cells, so sizes compare
    out = []
    info = cg.info_of(cells[0][0])                              # the layout is the same in every cell
    for stem, view in (("Candles_ParameterSweep", broadside(info, 0.55, 0.5)),
                       ("Candles_ParameterSweep_front", broadside(info, 0.0, 0.08))):
        paths = [render([obj], os.path.join(cg.REVIEW_DIR, "_sweep_%s_%d.png" % (stem[-5:], k)), view, size=(900, 800),
                        frame_points=everything, label=label) for k, (obj, label) in enumerate(cells)]
        out.append(fc.tile_images(paths, os.path.join(cg.REVIEW_DIR, "%s_sheet.png" % stem), cols=3))
        for pth in paths:
            os.remove(pth)
    for obj, _ in cells:
        cg.remove_candle(obj)
    return out


# ================================================================ main
def main():
    args = fc.cli_args({"export": False, "save": False, "sheets": False, "only": ""})
    t0 = time.time()
    for d in (cg.BLEND_DIR, cg.EXPORT_DIR, cg.REVIEW_DIR):
        os.makedirs(d, exist_ok=True)
    fc.clear_scene()
    bpy.context.scene.view_settings.view_transform = "Standard"
    fails = []
    built = []
    variants = [v for v in VARIANTS if not args["only"] or str(args["only"]) in v[0]]
    names = [v[0] for v in VARIANTS]
    if len(set(names)) != 9 or not all(n.endswith(cg.SUFFIX) for n in names):
        fails.append("variant names %s" % names)

    for name, budget, params in variants:
        obj, info = cg.generate(params, name=name)
        built.append((obj, info, budget, params))
    print("\nchecks:")
    for obj, info, budget, params in built:
        fails += check_variant(obj, info, budget, params)

    # the same parameters give the same mesh (the tool is deterministic per seed)
    name, budget, params = variants[0]
    again, info2 = cg.generate(params, name="_Repeat")
    if info2["tris"] != built[0][1]["tris"] or not np.allclose(fc.verts_cm(again), fc.verts_cm(built[0][0]), atol=1e-4):
        fails.append("%s is not reproducible from its seed" % name)
    cg.remove_candle(again)

    exported = []
    if args["export"]:
        print("\nexport:")
        for obj, info, budget, params in built:
            exported.append((cg.export_candle(obj, cg.EXPORT_DIR), params))
    sheets = []
    if args["sheets"]:
        sheets = render_sheets(built)
    if args["save"]:
        x = 0.0
        for obj, *_ in built:                                  # laid out in a row in the saved file only
            lo, hi = fc.bounds_cm(obj)
            obj.location = ((x - lo[0]) * 0.01, 0.0, 0.0)
            x += (hi[0] - lo[0]) + 8.0
        for coll in (bpy.data.materials, bpy.data.meshes, bpy.data.curves, bpy.data.cameras):
            for d in list(coll):
                if d.users == 0:
                    coll.remove(d)
        fc.save_blend(BLEND_FILE)
        print("saved", BLEND_FILE)
        for obj, *_ in built:
            obj.location = (0.0, 0.0, 0.0)

    # ---- re-import every FBX (after the save, so the blend stays clean) + read back the sidecars
    if exported:
        print("\nre-import:")
    for path, params in exported:
        rep, problems = reimport(path, params.count)
        fails += problems
        stem = os.path.splitext(os.path.basename(path))[0]
        with open(os.path.splitext(path)[0] + ".json") as fh:
            meta = json.load(fh)
        if rep and rep["tris"] != meta["tris"]:
            fails.append("%s: reimported tris %d != sidecar %d" % (stem, rep["tris"], meta["tris"]))
        if len(meta["candles"]) != params.count or sorted(meta["sockets"]) != ["Flame_%02d" % k for k in range(params.count)]:
            fails.append("%s: sidecar candles %d sockets %s" % (stem, len(meta["candles"]), sorted(meta["sockets"])))
        for c in meta["candles"]:
            need = {"id", "base_cm", "radius_cm", "height_cm", "flame_socket", "flame_center_cm"}
            if not need <= set(c):
                fails.append("%s: sidecar candle %s lacks %s" % (stem, c.get("index"), sorted(need - set(c))))
            elif c["flame_center_cm"] != meta["sockets"][c["flame_socket"]]["location_cm"]:
                fails.append("%s: candle %d flame centre is not its socket" % (stem, c["index"]))
        print("      sidecar: tris %d  candles %s" % (meta["tris"], ", ".join(
            "%s id %.3f r %.1f h %.1f" % (c["flame_socket"], c["id"], c["radius_cm"], c["height_cm"])
            for c in meta["candles"])))

    print("\nsheets:", *sheets, sep="\n  ")
    print("total %.1fs" % (time.time() - t0))
    if fails:
        print("CANDLES_FAIL", *fails, sep="\n  ")
    else:
        print("CANDLES_OK")


main()
