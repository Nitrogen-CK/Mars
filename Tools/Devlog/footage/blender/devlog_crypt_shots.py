"""Blender footage for the Mise en Monstre crypt-kit making-of devlog (Tools/Devlog/CONTRACT.md).

The kit was never screen-recorded: it is built by procedural Python (the off-repo vns_trim_sheet add-on), so the
build is REPLAYED here step by step and a frame is rendered after each step.

Run (headless, Blender 5.2; one process, shots run one after another in it):
    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup ^
        --python D:\\Repo\\Mars\\Tools\\Devlog\\footage\\blender\\devlog_crypt_shots.py -- ^
        --shot all --out D:\\Repo\\Content\\Devlog\\mise_crypt\\blender [--draft] [--sample N]
  --shot   one of SHOTS below, a comma list, or all
  --draft  960x540, every 4th frame (frames renumbered), EEVEE 8 samples
  --sample N   render only N evenly spaced frames plus every stage start, named by their true frame index (checks)
Each shot writes <out>/<shot>/%05d.png (1920x1080, 30 fps), shot.json and _preview.mp4 (ffmpeg from imageio_ffmpeg).

How the replay works (details in dl_replay.py)
  * Piece builds: crypt.build_piece(pid) runs unchanged; `geo.Builder.emit` (the one call every primitive ends in)
    is wrapped for the build and records the running face count, so each face of the finished mesh knows which
    primitive made it (FACE attribute `reveal`).  A geometry-nodes modifier (DL_Reveal) deletes faces above a
    threshold and drops the newest blocks in; the threshold advances `fpp` frames per primitive.
  * The blockout is the same build with Builder.box / prism / chunk / lathe / rock forced to bevel 0 and the RNG
    proxied so tilt / vertex-wobble draws return 0 while the random sequence stays identical (same courses, same
    emit order).  A second threshold sweep then swaps blockout primitives for finished ones in build order.
  * Face categories: the unmapped finished build's TRIMCAT_<cat> slots, recoloured one flat colour per category.
    UV trim mapping: trimmap.map_object onto M_Trim_MISE_ATLAS (appended from Crypt_Kit_Library.blend), shown with a
    checker that paints each atlas strip its own hue.  Then the real atlas material in EEVEE.
  * Atlas: builder._generate's strip loop re-run at 256 px/m with mise_paint.mortar_bed / block wrapped to snapshot
    the canvas after every mortar bed and every stone, then the map passes (height, normal, AO, cavity, paint pass).
  * pier_family / kit_lineup / room_assembly use the finished library meshes (SM_*); the room is
    crypt_rooms.plan_room(16 x 16 octagon, 2 tiers, ornament 2) placed in category order.

Stage boundaries per shot are written into shot.json ("stages": [{name, start, end}]) and
Tools/Devlog/episodes/mise_crypt_making_of/BLENDER_SHOTS.md.
"""

import json
import math
import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import dl_replay as R  # noqa: E402
import dl_scene as ds  # noqa: E402

ATLAS_MATS = ["M_Trim_MISE_ATLAS", "M_Surf_StoneWall", "M_Surf_StoneFloor", "M_Surf_PlainStone"]
FFMPEG = r"C:\Users\Stephen\AppData\Local\Programs\Python\Python310\lib\site-packages\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe"
SCRIPT = "Tools/Devlog/footage/blender/devlog_crypt_shots.py"


class Ctx:
    def __init__(self, draft):
        self.draft = draft
        self.res = (960, 540) if draft else (1920, 1080)
        self.samples = 8 if draft else 24


class Shot:
    """frames: [(stage, fn)]; fn() puts the scene in that frame's state and returns a render callable(path)."""

    def __init__(self, sc):
        self.sc = sc
        self.frames = []
        self.meta = {}

    def add(self, stage, fn, n=1):
        for i in range(n):
            self.frames.append((stage, (lambda i=i, n=n: fn(i, n))))


def render3d(sc):
    return lambda path: ds.render_to(sc, path)


# ------------------------------------------------------------------ piece builds (wall4m / ossuary4m / portal6m)
def _piece_objects(pid):
    ds.append_materials(ATLAS_MATS)
    raw, marks = R.build(pid, raw=True, do_map=False)
    cat, marks_c = R.build(pid, raw=False, do_map=False, name="DL_CAT_" + pid)
    fin, marks_f = R.build(pid, raw=False, do_map=True)
    assert len(marks) == len(marks_c) == len(marks_f), (len(marks), len(marks_c), len(marks_f))
    for slot in cat.material_slots:
        nm = slot.material.name if slot.material else "stone"
        key = "surf" if nm.startswith("M_Surf") else nm.replace("TRIMCAT_", "")
        slot.material = ds.category_material(key)
    chk = fin.copy()
    chk.data = fin.data.copy()
    chk.name = "DL_CHK_" + pid
    bpy.context.scene.collection.objects.link(chk)
    import vns_trim_sheet.sheets as sheets
    rows = sheets.layout(sheets.SHEETS["MISE_ATLAS"], 64, 1)[2]
    cm = ds.checker_material(ds.strip_checker_image(rows))
    for i in range(len(chk.data.materials)):
        chk.data.materials[i] = cm
    secs = sum(o.get("dl_build_seconds", 0.0) for o in (fin,))
    return raw, cat, fin, chk, marks, secs


def _frame_piece(sc, cam, fin, az, el, lens, drop, fill=0.84):
    lo, hi = ds.bbox([fin])
    lo = Vector((lo.x, lo.y, max(lo.z, 0.0)))
    tgt = (lo + hi) * 0.5
    d = ds.orbit_dir(az, el)
    dist = ds.fit_distance(ds.box_corners(lo, hi), tgt, d, lens, fill=fill)
    return tgt, dist


def piece_shot(sc, ctx, pid, fpp=4, hold=12, bevel=30, look=36, textured=48, az=-35.0, el=25.0, lens=40.0,
               drop=0.6, window=1.6, desc=""):
    S = Shot(sc)
    raw, cat, fin, chk, marks, secs = _piece_objects(pid)
    n = len(marks)
    cam = ds.camera(sc, lens)
    tgt, dist = _frame_piece(sc, cam, fin, az, el, lens, drop)
    ds.look_at(cam, tgt + ds.orbit_dir(az, el) * dist, tgt)
    lo, hi = ds.bbox([fin])
    ds.ground(sc, extent=max(6.0, (hi - lo).length * 1.2), center=(round(tgt.x), round(tgt.y)), z=-0.003)
    ds.three_point(sc, tgt, 20.0, key_az=az - 40.0)
    ds.world_ambient(sc)
    for o in (raw, cat, fin, chk):
        ds.add_reveal(o, threshold=1e9, drop=0.0, window=window)

    def show(*vis):
        for o in (raw, cat, fin, chk):
            o.hide_render = o not in vis

    for o in (raw, cat, fin, chk):
        o.color = (0.66, 0.66, 0.66, 1.0)

    def wb(ct):
        ds.workbench(sc, ct)

    def f_intro(i, k):
        wb("OBJECT")
        show(raw)
        ds.set_reveal(raw, threshold=-1.0, drop=drop, window=window, invert=False)
        return render3d(sc)

    def f_build(i, k):
        wb("OBJECT")
        show(raw)
        ds.set_reveal(raw, threshold=i / float(fpp), drop=drop, window=window, invert=False)
        return render3d(sc)

    def f_hold_raw(i, k):
        wb("OBJECT")
        show(raw)
        ds.set_reveal(raw, threshold=1e9, drop=0.0, invert=False)
        return render3d(sc)

    def f_bevel(i, k):
        wb("OBJECT")
        show(raw, cat)
        t = -0.5 + (n + 0.5) * (i + 1) / float(k)
        ds.set_reveal(raw, threshold=t, drop=0.0, invert=True)
        ds.set_reveal(cat, threshold=t, drop=0.0, invert=False)
        return render3d(sc)

    def f_hold_fin(i, k):
        wb("OBJECT")
        show(cat)
        ds.set_reveal(cat, threshold=1e9, drop=0.0, invert=False)
        return render3d(sc)

    def f_cats(i, k):
        wb("MATERIAL")
        show(cat)
        ds.set_reveal(cat, threshold=1e9, drop=0.0, invert=False)
        return render3d(sc)

    def f_checker(i, k):
        wb("TEXTURE")
        show(chk)
        ds.set_reveal(chk, threshold=1e9, drop=0.0, invert=False)
        return render3d(sc)

    def f_tex(i, k):
        ds.eevee(sc, ctx.samples)
        show(fin)
        ds.set_reveal(fin, threshold=1e9, drop=0.0, invert=False)
        return render3d(sc)

    S.add("intro", f_intro, 6)
    S.add("blockout_build", f_build, n * fpp + int(math.ceil(window * fpp)) + 2)
    S.add("blockout_done", f_hold_raw, hold)
    S.add("bevel_wobble", f_bevel, bevel)
    S.add("finished_geometry", f_hold_fin, hold)
    S.add("face_categories", f_cats, look)
    S.add("uv_trim_checker", f_checker, look)
    S.add("atlas_material", f_tex, textured)
    S.meta = {"description": desc or ("%s replayed primitive by primitive (%d primitives, %d frames each), then "
                                      "bevel/wobble, face categories, UV trim checker, MISE atlas (EEVEE)" % (pid, n, fpp)),
              "real_seconds_covered": round(secs, 4), "steps": n, "frames_per_step": fpp,
              "piece": pid, "camera": {"az": az, "el": el, "lens": lens}}
    return S


def shot_wall4m_build(sc, ctx):
    return piece_shot(sc, ctx, "crypt_wall_4m", fpp=4)


def shot_ossuary4m_build(sc, ctx):
    return piece_shot(sc, ctx, "crypt_wall_ossuary_4m", fpp=3, hold=8, bevel=24, look=24, textured=36)


def shot_portal6m_build(sc, ctx):
    return piece_shot(sc, ctx, "crypt_portal_6m", fpp=3, hold=8, bevel=24, look=24, textured=36, az=-30.0)


# ------------------------------------------------------------------ raw vs painted (wipe pairs)
def compare_shot(sc, ctx, pid, painted, frames=90, az0=-55.0, az1=-20.0, el=22.0, lens=45.0):
    S = Shot(sc)
    ds.append_materials(ATLAS_MATS)
    fin, marks = R.build(pid, raw=False, do_map=True)
    fin.color = (0.66, 0.66, 0.66, 1.0)
    if painted:
        for i, m in enumerate(fin.data.materials):
            if m is not None and (m.name.startswith("M_Trim") or m.name.startswith("M_Surf")):
                fin.data.materials[i] = ds.paint_wash_material(m)
    cam = ds.camera(sc, lens)
    lo, hi = ds.bbox([fin])
    lo = Vector((lo.x, lo.y, max(lo.z, 0.0)))
    tgt = (lo + hi) * 0.5
    dist = max(ds.fit_distance(ds.box_corners(lo, hi), tgt, ds.orbit_dir(a, el), lens, fill=0.84)
               for a in (az0, (az0 + az1) / 2, az1))
    ds.ground(sc, extent=max(6.0, (hi - lo).length * 1.2), center=(round(tgt.x), round(tgt.y)), z=-0.003)
    ds.three_point(sc, tgt, 20.0, key_az=az0 - 30.0)
    ds.world_ambient(sc)

    def f(i, k):
        a = az0 + (az1 - az0) * ds.smooth(i / float(k - 1))
        ds.look_at(cam, tgt + ds.orbit_dir(a, el) * dist, tgt)
        if painted:
            ds.eevee(sc, ctx.samples)
        else:
            ds.workbench(sc, "OBJECT")
        return render3d(sc)
    S.add("painted" if painted else "raw", f, frames)
    S.meta = {"description": "%s, %s, slow 35 deg orbit (pair with the %s shot for a wipe; identical camera)" % (
        pid, "MISE atlas + paint wash (EEVEE)" if painted else "untextured flat grey (Workbench)",
        "raw" if painted else "painted"), "real_seconds_covered": round(fin.get("dl_build_seconds", 0.0), 4),
        "steps": len(marks), "piece": pid, "camera": {"az": [az0, az1], "el": el, "lens": lens}}
    return S


def shot_wall_raw(sc, ctx):
    return compare_shot(sc, ctx, "crypt_wall_4m", False)


def shot_wall_painted(sc, ctx):
    return compare_shot(sc, ctx, "crypt_wall_4m", True)


def shot_ossuary_raw(sc, ctx):
    return compare_shot(sc, ctx, "crypt_wall_ossuary_4m", False)


def shot_ossuary_painted(sc, ctx):
    return compare_shot(sc, ctx, "crypt_wall_ossuary_4m", True)


# ------------------------------------------------------------------ pier family (library meshes)
PIER_FAMILY = [["crypt_pier_h3m5", "crypt_pier_h4m", "crypt_pier_h7m5", "crypt_pier_h11m5", "crypt_pier_h15m5"],
               ["crypt_halfcol_h3m5", "crypt_halfcol_h7m5", "crypt_halfcol_h11m5", "crypt_halfcol_h15m5"],
               ["crypt_vertexcol_h3m5", "crypt_vertexcol_h7m5", "crypt_vertexcol_h11m5", "crypt_vertexcol_h15m5"]]


def _link_library(names):
    obs = ds.append_objects(["SM_" + n for n in names])
    out = []
    for n in names:
        ob = obs.get("SM_" + n)
        if ob is None:
            print("missing in library:", n)
            continue
        ob.parent = None
        ob.location = (0, 0, 0)
        ob.rotation_euler = (0, 0, 0)
        bpy.context.scene.collection.objects.link(ob)
        out.append(ob)
    return out


def shot_pier_family(sc, ctx, frames=240):
    S = Shot(sc)
    names = [n for g in PIER_FAMILY for n in g]
    obs = _link_library(names)
    x = 0.0
    gi = {n: k for k, g in enumerate(PIER_FAMILY) for n in g}
    prev_g = None
    for ob in obs:
        g = gi[ob["vns_piece"]] if "vns_piece" in ob else 0
        w = ob.dimensions.x
        if prev_g is not None:
            x += 1.0 + (1.6 if g != prev_g else 0.0)
        ob.location = (x + w / 2.0, 0.0, 0.0)
        x += w
        prev_g = g
    for ob in obs:
        ob.location.x -= x / 2.0
    bpy.context.view_layer.update()
    lo, hi = ds.bbox(obs)          # before the reveal modifiers (an empty evaluated mesh has an empty bound box)
    for ob in obs:
        me = ob.data
        ds.set_face_float(me, "reveal", ds.part_base_reveal(me))
        ds.add_reveal(ob, threshold=-10.0, drop=0.5, window=0.9)
    lens, el = 40.0, 16.0
    az0, az1 = -28.0, 12.0
    cam = ds.camera(sc, lens)
    ds.ground(sc, extent=24.0, z=-0.003)
    ds.three_point(sc, Vector((0, 0, hi.z * 0.5)), 40.0, key_az=-70.0)
    ds.world_ambient(sc)
    stagger, rise = 13, 20
    heights = [o.dimensions.z for o in obs]
    boxes = [(Vector((o.location.x - o.dimensions.x / 2, -0.7, 0.0)), Vector((o.location.x + o.dimensions.x / 2, 0.7, h)))
             for o, h in zip(obs, heights)]
    n = len(obs)
    build_end = (n - 1) * stagger + rise + 4
    # the camera follows the family as it grows: per frame, frame every column started so far (the newest at full
    # height), then low-pass the target / distance both ways so the pull-back is smooth
    raw_t, raw_d = [], []
    for i in range(frames):
        a = az0 + (az1 - az0) * (i / float(frames - 1))
        upto = max(2, min(n - 1, i // stagger))
        lo_ = Vector((min(bx[0].x for bx in boxes[:upto + 1]), -0.7, 0.0))
        hi_ = Vector((max(bx[1].x for bx in boxes[:upto + 1]), 0.7, max(bx[1].z for bx in boxes[:upto + 1])))
        t = (lo_ + hi_) * 0.5
        raw_t.append(t)
        raw_d.append(ds.fit_distance(ds.box_corners(lo_, hi_), t, ds.orbit_dir(a, el), lens, fill=0.82))

    def lowpass(vals, k=0.07):
        out = list(vals)
        for _ in range(2):
            for i in range(1, len(out)):
                out[i] = out[i - 1] + (out[i] - out[i - 1]) * k
            for i in range(len(out) - 2, -1, -1):
                out[i] = out[i + 1] + (out[i] - out[i + 1]) * k
        return out
    tx = lowpass([v.x for v in raw_t])
    tz = lowpass([v.z for v in raw_t])
    dd = lowpass(raw_d)
    # never closer than the raw fit (the smoothing must not crop the newest column)
    dd = [max(d, r * 0.97) for d, r in zip(dd, raw_d)]

    def f(i, k):
        a = az0 + (az1 - az0) * (i / float(k - 1))
        tgt = Vector((tx[i], 0.0, tz[i]))
        ds.look_at(cam, tgt + ds.orbit_dir(a, el) * dd[i], tgt)
        for j, ob in enumerate(obs):
            t = (i - j * stagger) / float(rise)
            thr = -0.45 + (heights[j] + 0.5) * max(0.0, min(1.0, t)) if t > 0 else -10.0
            ds.set_reveal(ob, threshold=thr if t < 1.2 else 1e9)
        ds.eevee(sc, ctx.samples)
        return render3d(sc)
    gname = {0: "piers", 1: "half_columns", 2: "vertex_columns"}
    for i in range(frames):
        j = min(n - 1, i // stagger)
        stage = gname[gi[obs[j]["vns_piece"]]] if i < build_end else "orbit"
        S.frames.append((stage, (lambda i=i: f(i, frames))))
    S.meta = {"description": "pier family from Crypt_Kit_Library.blend: piers 3.5/4/7.5/11.5/15.5 m, half columns and "
                             "vertex columns 3.5-15.5 m, each laid course by course, slow orbit (EEVEE)",
              "real_seconds_covered": 0.0, "steps": len(obs), "pieces": names}
    return S


# ------------------------------------------------------------------ kit lineup
GROUP_ORDER = ["wall", "portal", "support", "floor", "stair", "gallery", "platform", "landmark", "box", "chain", "camp"]


def shot_kit_lineup(sc, ctx, frames=300):
    S = Shot(sc)
    names = [n[3:] for n in ds.library_object_names()]
    obs = _link_library(names)
    # one section per group along +x (wall, portal, support ... camp); inside a section the pieces stand in three
    # rows by height (low in front, tall at the back) so nothing hides behind a taller piece
    groups = {}
    for ob in obs:
        groups.setdefault(ob.get("vns_group", "zz"), []).append(ob)
    order = [g for g in GROUP_ORDER if g in groups] + sorted(g for g in groups if g not in GROUP_ORDER)
    row_y = {0: 0.0, 1: 5.0, 2: 11.0}
    gap, x = 0.8, 0.0
    sections = []
    for g in order:
        rows = {0: [], 1: [], 2: []}
        for ob in sorted(groups[g], key=lambda o: (o.dimensions.z, o.name)):
            h = ob.dimensions.z
            rows[0 if h <= 1.6 else (1 if h <= 4.6 else 2)].append(ob)
        width = 0.0
        for k, v in rows.items():
            xx = x
            for o in v:
                bb = [Vector(c) for c in o.bound_box]
                mnx, mny, mxy = min(c.x for c in bb), min(c.y for c in bb), max(c.y for c in bb)
                o.location = (xx - mnx, row_y[k] - (mny + mxy) / 2.0, 0.0)
                xx += o.dimensions.x + gap
            width = max(width, xx - x - gap)
        sections.append((g, x, x + width))
        x += width + 3.0
    L = x - 3.0
    for ob in obs:
        ob.location.x -= L / 2.0
    bpy.context.view_layer.update()
    lo, hi = ds.bbox(obs)
    lens, el, az = 35.0, 13.0, -24.0
    cam = ds.camera(sc, lens)
    ds.ground(sc, extent=max(30.0, L * 0.55), z=-0.003, cell=2.0, width=0.025)
    ds.three_point(sc, Vector((0, 0, 0)), 80.0, key_az=-60.0)
    ds.world_ambient(sc, 0.5)
    d = ds.orbit_dir(az, el)
    win = 22.0           # metres of lineup in frame
    tz = 2.6
    yc = (lo.y + hi.y) * 0.5
    dist = ds.fit_distance(ds.box_corners(Vector((-win / 2, lo.y, 0)), Vector((win / 2, hi.y, 7.5))),
                           Vector((0, yc, tz)), d, lens, fill=0.98)
    x0, x1 = lo.x + win * 0.42, hi.x - win * 0.42

    def f(i, k):
        t = i / float(k - 1)
        x = x0 + (x1 - x0) * t
        tgt = Vector((x, yc, tz))
        ds.look_at(cam, tgt + d * dist, tgt)
        ds.eevee(sc, ctx.samples)
        return render3d(sc)
    for i in range(frames):
        t = i / float(frames - 1)
        xc = x0 + (x1 - x0) * t + L / 2.0
        g = next((g for g, a0, a1 in sections if xc <= a1 + 1.5), sections[-1][0])
        S.frames.append(("dolly_" + g, (lambda i=i: f(i, frames))))
    secs = []
    for g, a0, a1 in sections:      # frame at which each group section's centre passes the frame centre
        xc = (a0 + a1) / 2.0 - L / 2.0
        secs.append({"group": g, "frame": int(round(max(0.0, min(1.0, (xc - x0) / (x1 - x0))) * (frames - 1)))})
    S.meta = {"description": "all %d SM_* pieces of Crypt_Kit_Library.blend, one section per group (wall, portal, "
                             "support, floor, stair, gallery, platform, landmark, box, chain, camp), three rows by "
                             "height inside a section, lateral dolly, EEVEE" % len(obs),
              "real_seconds_covered": 0.0, "steps": len(obs), "lineup_length_m": round(L, 1), "group_frames": secs}
    return S


# ------------------------------------------------------------------ room assembly
ORNAMENT_HINTS = ("capital_fork", "keystone", "spout", "corbel", "finial", "frieze", "rose_pan", "spatula",
                  "roundel")


def shot_room_assembly(sc, ctx, stagger=3, fall=9, orbit=80, hold=14):
    S = Shot(sc)
    kc, _ = ds.kit()
    from vns_trim_sheet.assets import crypt_rooms as cr, crypt_spec as cs
    args = dict(width=16, length=16, levels=1, tiers=2, shape="octagon")
    t0 = time.perf_counter()
    room = cr.plan_room(ornament=2, **args)
    plan_secs = time.perf_counter() - t0
    plain = cr.plan_room(**args)
    key = lambda p: (p["piece"], p["x"], p["y"], p["z"], p["rot"])
    plain_keys = {key(p) for p in plain["placements"]}
    pl = [p for p in room["placements"] if not p["piece"].startswith("crypt_roof")]
    W = 16.0
    cx, cy = 0.0, W / 2.0

    def order(p):
        g = cs.SPEC[p["piece"]][0] if p["piece"] in cs.SPEC else "box"
        orn = key(p) not in plain_keys or any(h in p["piece"] for h in ORNAMENT_HINTS)
        if g == "floor":
            k = 0
        elif orn:
            k = 6
        elif g in ("wall", "portal"):
            k = 1 if p["z"] < 3.0 else 2
        elif g == "support" and "rib" in p["piece"]:
            k = 4
        elif g == "support":
            k = 3
        else:
            k = 5
        ang = (math.degrees(math.atan2(p["x"] - cx, p["y"] - cy)) + 360.0) % 360.0   # 0 = north, clockwise
        return (k, p["z"], ang)
    pl.sort(key=order)
    kinds = [order(p)[0] for p in pl]
    meshes = sorted({p["mesh"] for p in pl})
    with bpy.data.libraries.load(ds.LIB, link=False) as (src, dst):
        dst.meshes = [m for m in meshes if m in src.meshes]
    ds._abs_images()
    obs = []
    for j, p in enumerate(pl):
        me = bpy.data.meshes.get(p["mesh"])
        if me is None:
            print("room: missing mesh", p["mesh"])
            continue
        ob = bpy.data.objects.new("DL_P%03d_%s" % (j, p["piece"]), me)
        ob.location = (p["x"], p["y"], p["z"])
        ob.rotation_euler = (0.0, 0.0, math.radians(p["rot"]))
        if "scale" in p:
            ob.scale = p["scale"]
        sc.collection.objects.link(ob)
        ob["dl_home"] = list(ob.location)
        ob["dl_kind"] = kinds[j]
        obs.append(ob)
    bpy.context.view_layer.update()
    lo, hi = ds.bbox(obs)
    lens, el = 35.0, 50.0
    tgt = Vector((cx, cy, 1.6))
    az0 = -32.0
    pts = ds.box_corners(Vector((lo.x, lo.y, 0.0)), hi)
    dist = max(ds.fit_distance(pts, tgt, ds.orbit_dir(a, el), lens, fill=0.86) for a in (az0, az0 + 30, az0 + 60))
    cam = ds.camera(sc, lens)
    ds.ground(sc, extent=16.0, center=(0, 8), z=-0.41)
    ds.three_point(sc, tgt, 60.0, key_az=-75.0)
    ds.world_ambient(sc, 0.55)
    n = len(obs)
    t_end = (n - 1) * stagger + fall + 2
    drop_h = 3.0

    def place(i):
        for j, ob in enumerate(obs):
            t = (i - j * stagger) / float(fall)
            home = Vector(ob["dl_home"])
            if t <= 0:
                ob.hide_render = True
                continue
            ob.hide_render = False
            tt = min(1.0, t)
            ob.location = home + Vector((0, 0, drop_h * (1.0 - tt * tt)))

    def f_build(i, k):
        ds.look_at(cam, tgt + ds.orbit_dir(az0, el) * dist, tgt)
        place(i)
        ds.eevee(sc, ctx.samples)
        return render3d(sc)

    def f_hold(i, k):
        place(10 ** 6)
        ds.look_at(cam, tgt + ds.orbit_dir(az0, el) * dist, tgt)
        ds.eevee(sc, ctx.samples)
        return render3d(sc)

    def f_orbit(i, k):
        place(10 ** 6)
        a = az0 + 60.0 * ds.smooth(i / float(k - 1))
        ds.look_at(cam, tgt + ds.orbit_dir(a, el) * dist, tgt)
        ds.eevee(sc, ctx.samples)
        return render3d(sc)
    names = {0: "floor", 1: "walls_ground_tier", 2: "walls_upper_tier", 3: "columns_and_pier", 4: "vault_ribs",
             5: "boxes_and_props", 6: "ornament"}
    for i in range(t_end):
        # the stage of a frame = the kind of the newest piece in the air
        j = min(n - 1, max(0, i // stagger))
        S.frames.append((names[kinds[j]], (lambda i=i: f_build(i, t_end))))
    S.add("complete", f_hold, hold)
    S.add("orbit", f_orbit, orbit)
    S.meta = {"description": "crypt_rooms.plan_room(16 x 16 octagon, 2 tiers, ornament 2): %d library pieces dropped in "
                             "category order (floor, ground-tier walls, upper tier, columns and pier, vault ribs, "
                             "boxes, carved ornament; the roof slab is left out so the camera sees in), then a 60 deg "
                             "orbit (EEVEE)" % n,
              "real_seconds_covered": round(plan_secs, 4), "steps": n, "room": room["name"],
              "placements": len(room["placements"])}
    return S


# ------------------------------------------------------------------ atlas paint
def shot_atlas_paint(sc, ctx, per_snap=2, hold=10, xfade=8, stage_len=26, final_len=40):
    import numpy as np
    S = Shot(sc)
    A = R.atlas_replay()
    W, H = ctx.res
    bg = np.array(R.ds_hex(ds.BG_HEX), np.float32)
    side = int(round(H * 0.95))
    x0, y0 = (W - side) // 2, (H - side) // 2

    def resize(img):
        a = img.astype(np.float32) / 255.0
        n = a.shape[0]
        idx = (np.arange(side) * n / side).astype(np.int32)
        return a[idx][:, idx]

    def frame_of(img):
        out = np.empty((H, W, 3), np.float32)
        out[:] = bg
        out[y0:y0 + side, x0:x0 + side] = resize(img)
        return out

    def still(img):
        return lambda path: ds.save_image_rgb(frame_of(img), path)

    def blend(a, b, t):
        return lambda path: ds.save_image_rgb(frame_of(a) * (1 - t) + frame_of(b) * t, path)

    snaps = A["snaps"]
    for label, strip, img in snaps:
        stage = "strip_" + (strip or "canvas")
        for _ in range(per_snap):
            S.frames.append((stage, (lambda img=img: still(img))))
    last = snaps[-1][2]
    for _ in range(hold):
        S.frames.append(("authored_colour", (lambda: still(last))))
    seq = [("height", A["stages"]["height"]), ("normal", A["stages"]["normal"]), ("ao", A["stages"]["ao"]),
           ("cavity", A["stages"]["cavity"]), ("paint_pass_final", A["stages"]["final"])]
    prev = last
    for name, img in seq:
        n = final_len if name == "paint_pass_final" else stage_len
        for i in range(n):
            if i < xfade:
                t = ds.smooth((i + 1) / float(xfade))
                S.frames.append((name, (lambda a=prev, b=img, t=t: blend(a, b, t))))
            else:
                S.frames.append((name, (lambda img=img: still(img))))
        prev = img
    S.meta = {"description": "MISE_ATLAS (Bellfold) regenerated at 256 px/m: mortar bed and every stone painted in "
                             "strip order (%d snapshots), then height, normal (DirectX), horizon AO, cavity and the "
                             "paint pass = the shipped BaseColor" % len(snaps),
              "real_seconds_covered": round(A["seconds"], 2), "steps": len(snaps),
              "strips": [r["id"] for r in A["rows"]]}
    return S


SHOTS = {
    "wall4m_build": shot_wall4m_build,
    "ossuary4m_build": shot_ossuary4m_build,
    "portal6m_build": shot_portal6m_build,
    "pier_family": shot_pier_family,
    "atlas_paint": shot_atlas_paint,
    "kit_lineup": shot_kit_lineup,
    "room_assembly": shot_room_assembly,
    "wall_raw": shot_wall_raw,
    "wall_painted": shot_wall_painted,
    "ossuary_raw": shot_ossuary_raw,
    "ossuary_painted": shot_ossuary_painted,
}


# ------------------------------------------------------------------ driver
def preview(folder):
    if not os.path.isfile(FFMPEG):
        print("no ffmpeg at", FFMPEG)
        return
    cmd = [FFMPEG, "-y", "-loglevel", "error", "-framerate", "30", "-i", os.path.join(folder, "%05d.png"),
           "-c:v", "libx264", "-crf", "23", "-pix_fmt", "yuv420p", "-threads", "4",
           os.path.join(folder, "_preview.mp4")]
    subprocess.run(cmd, check=False)


def run(name, out_root, draft=False, sample=0):
    ctx = Ctx(draft)
    sc = ds.fresh()
    ds.setup_output(sc, ctx.res)
    t0 = time.perf_counter()
    shot = SHOTS[name](sc, ctx)
    frames = shot.frames
    total = len(frames)
    stages = []
    for i, (st, _) in enumerate(frames):
        if not stages or stages[-1]["name"] != st:
            if stages:
                stages[-1]["end"] = i - 1
            stages.append({"name": st, "start": i})
    stages[-1]["end"] = total - 1
    if sample:
        pick = sorted({int(round(k * (total - 1) / max(1, sample - 1))) for k in range(sample)} |
                      {s["start"] for s in stages} | {total - 1})
    elif draft:
        pick = list(range(0, total, 4))
    else:
        pick = list(range(total))
    out = os.path.join(out_root, name)
    if os.path.isdir(out):
        for fn in os.listdir(out):
            if fn.endswith(".png") or fn in ("_preview.mp4", "shot.json"):
                os.remove(os.path.join(out, fn))
    os.makedirs(out, exist_ok=True)
    tr = time.perf_counter()
    for k, i in enumerate(pick):
        rfn = frames[i][1]()
        idx = i if sample else k
        rfn(os.path.join(out, "%05d.png" % idx))
        if k % 25 == 0:
            print("[%s] frame %d/%d (%.1fs)" % (name, k + 1, len(pick), time.perf_counter() - tr), flush=True)
    meta = {"fps": 30, "frames": len(pick), "real_seconds_covered": shot.meta.get("real_seconds_covered", 0.0),
            "description": shot.meta.get("description", ""), "source": SCRIPT + " --shot " + name}
    if draft or sample:
        meta["draft"] = True
        meta["sampled_from"] = total
    meta["stages"] = stages if not draft else [dict(s, start=s["start"] // 4, end=s["end"] // 4) for s in stages]
    for k, v in shot.meta.items():
        if k not in meta:
            meta[k] = v
    meta["render_seconds"] = round(time.perf_counter() - t0, 1)
    with open(os.path.join(out, "shot.json"), "w") as fh:
        json.dump(meta, fh, indent=2)
    if not sample:
        preview(out)
    print("SHOT_OK %s frames=%d of %d  %.1fs" % (name, len(pick), total, time.perf_counter() - t0), flush=True)
    return meta


def main(argv):
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--shot", default="all")
    ap.add_argument("--out", default=r"D:\Repo\Content\Devlog\mise_crypt\blender")
    ap.add_argument("--draft", action="store_true")
    ap.add_argument("--sample", type=int, default=0)
    a = ap.parse_args(argv)
    names = list(SHOTS) if a.shot == "all" else a.shot.split(",")
    for n in names:
        if n not in SHOTS:
            raise SystemExit("unknown shot %s (have %s)" % (n, ", ".join(SHOTS)))
    done = []
    for n in names:
        try:
            done.append((n, run(n, a.out, a.draft, a.sample)["frames"]))
        except Exception:
            import traceback
            traceback.print_exc()
            done.append((n, "FAILED"))
    print("ALL_DONE", done)


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
