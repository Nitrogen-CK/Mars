"""The pan showcase, beat 3 ("Cut first, then cook"): the meat slab cut into four on a board, and the four pieces as FBX.

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup --python devlog_pan_cut.py -- [--draft] [--export] [--no-render]

Headless Blender 5.2, the look of dl_scene.py (#15151a backdrop, grid floor, three-point EEVEE). Imports
MeatSlab_Mars_SM.fbx (vertex colours = albedo, as the food master reads them), splits it with two clean planar cuts
(no cleaver): x = 0 then y = 0 (the bench's 90-degree turn), four pieces. Each cut is a thin streak of light sweeping
down through the meat; the parts then separate a few cm with a small hop and settle. 150 frames at 30 fps.

Output: D:/Repo/Content/Devlog/pan_showcase/bench_cut/%05d.png (1920x1080, or 960x540 every 10th frame with --draft
into the session scratchpad) + shot.json + _preview.mp4 (the host writes the mp4; Blender has no ffmpeg here).

--export also writes SlabPiece_A..D_Mars_SM.fbx (+ .json) into D:/Repo/Content/Devlog/pan_showcase/_pieces/: pivot at
each piece's base centre, the slab's local axes kept (long axis +X), UV0 and the vertex colours kept from the slab,
each cut face filled with a flat cap on a third slot "Cut" painted the slab's cut-lean colour C(212, 36, 56) with
planar UV0 at the slab's UV scale (37 cm per unit), as the bench's runtime cut and build_food_meats.slab_parity_half do.
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import dl_scene as dl  # noqa: E402

SLAB_FBX = r"D:\Repo\Content\Cooking\export\food\MeatSlab_Mars_SM.fbx"
OUT = r"D:\Repo\Content\Devlog\pan_showcase\bench_cut"
PIECES = r"D:\Repo\Content\Devlog\pan_showcase\_pieces"
DRAFT_OUT = (r"C:\Users\Stephen\AppData\Local\Temp\claude\D--Repo-Mars\5f3efb8e-b134-46b6-83b7-6ce0a5233bff"
             r"\scratchpad\pan_agent\drafts\bench_cut")
FRAMES = 150
COL = "Col"
LEAN_CUT = (212, 36, 56)          # the slab's cut-lean paint (sRGB 8-bit), FOOD_LIBRARY.md "Cap colour = flesh"
UV_SPAN = 0.37                    # the slab's UVs span about 37 cm (Food def Visuals.Cap.Set_CmPerUVUnit(37))

# timeline (frames): whole slab, cut 1 sweeps across x = 0, halves part; cut 2 sweeps across y = 0, quarters part
CUT1 = (24, 36)                   # sheet top -> below the board
PART1 = (36, 54)
CUT2 = (66, 78)
PART2 = (78, 96)
GAP = 0.024                       # m each part moves away from its cut (so a 4.8 cm gap)
HOP = 0.006                       # m peak of the small hop
TIP = 5.0                         # deg peak tip about the cut edge while it hops


def lin(c):
    return dl.srgb_to_lin(c / 255.0)


def import_slab():
    bpy.ops.import_scene.fbx(filepath=SLAB_FBX, colors_type="LINEAR")
    obs = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    ob = obs[0]
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob


def split(ob, name, keep_axis, keep_sign):
    """A copy of ob cut by the plane <axis> = 0, keeping the side of keep_sign, the cut filled with a flat cap on the
    "Cut" slot (lean paint, planar UV0)."""
    me = ob.data.copy()
    me.name = name
    new = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(new)
    if "Cut" not in [m.name for m in me.materials if m]:
        me.materials.append(bpy.data.materials.get("Cut") or bpy.data.materials.new("Cut"))
    cut_slot = [m.name if m else "" for m in me.materials].index("Cut")
    bm = bmesh.new()
    bm.from_mesh(me)
    n = Vector((1.0, 0.0, 0.0)) if keep_axis == 0 else Vector((0.0, 1.0, 0.0))
    res = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0.0, 0.0, 0.0),
                                 plane_no=n, clear_outer=(keep_sign < 0), clear_inner=(keep_sign > 0))
    ring = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=False, edges=ring)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    col_l = bm.loops.layers.float_color.get(COL) or (bm.loops.layers.float_color[0] if bm.loops.layers.float_color else None)
    uv_l = bm.loops.layers.uv.get("UVMap") or (bm.loops.layers.uv[0] if bm.loops.layers.uv else None)
    lean = (lin(LEAN_CUT[0]), lin(LEAN_CUT[1]), lin(LEAN_CUT[2]), 1.0)
    for f in bm.faces:
        c = f.calc_center_median()
        if abs(c[keep_axis]) < 1e-5 and abs(abs(f.normal[keep_axis]) - 1.0) < 1e-3:
            f.material_index = cut_slot
            f.smooth = False
            for lp in f.loops:
                if col_l is not None:
                    lp[col_l] = lean
                if uv_l is not None:
                    other = lp.vert.co.y if keep_axis == 0 else lp.vert.co.x
                    lp[uv_l].uv = (0.5 + other / UV_SPAN, lp.vert.co.z / UV_SPAN)
    bm.to_mesh(me)
    bm.free()
    me.update()
    return new


def recentre(ob):
    """Move the origin to the base centre (x, y bounds centre, z min); returns the old->new offset (m)."""
    vs = [v.co for v in ob.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    piv = Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, lo.z))
    for v in ob.data.vertices:
        v.co -= piv
    ob.location = piv
    return piv, (hi - lo)


def meat_material():
    """Vertex colour albedo (the paint the food master reads), a wet sheen; the cap slot shares it (its paint is lean)."""
    m = bpy.data.materials.new("DL_Meat")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = COL
    nt.links.new(attr.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.38
    try:
        b.inputs["Coat Weight"].default_value = 0.25
        b.inputs["Coat Roughness"].default_value = 0.15
    except KeyError:
        pass
    return m


def board_material():
    m = dl._mat("DL_Board", (0.13, 0.068, 0.034, 1.0), 0.72)
    return m


def sheet_material():
    m = bpy.data.materials.new("DL_CutSheet")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (1.0, 0.92, 0.80, 1.0)
    em.inputs["Strength"].default_value = 6.0
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def box(name, size, loc, mat):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    me.materials.append(mat)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def ease(u):
    u = min(max(u, 0.0), 1.0)
    return u * u * (3.0 - 2.0 * u)


def part_pose(f, span, d):
    """(offset vector, tip deg) of a part that moves along unit d during frames span."""
    u = (f - span[0]) / float(span[1] - span[0])
    if u <= 0.0:
        return Vector((0, 0, 0)), 0.0
    e = ease(u)
    hop = math.sin(math.pi * min(u, 1.0)) * HOP
    tip = math.sin(math.pi * min(u, 1.0)) * TIP
    return Vector((d.x * GAP * e, d.y * GAP * e, hop)), tip


def key_vis(ob, ranges):
    """hide_render / hide_viewport keyed on: visible only on frames in any [a, b)."""
    for f in range(0, FRAMES + 1):
        vis = any(a <= f < b for a, b in ranges)
        ob.hide_render = not vis
        ob.keyframe_insert("hide_render", frame=f)


def build(draft):
    sc = dl.fresh()
    res = (960, 540) if draft else (1920, 1080)
    dl.setup_output(sc, res)
    dl.eevee(sc, samples=32 if not draft else 16)
    slab = import_slab()
    slab.name = "Slab"
    for k in range(len(slab.data.materials)):
        slab.data.materials[k] = None
    meat = meat_material()
    # parts: halves (x), then quarters (x then y); every part's material slots all wear the meat look
    halves = {s: split(slab, "Half_%s" % ("P" if s > 0 else "N"), 0, s) for s in (1, -1)}
    quarters = {}
    names = {(-1, -1): "A", (1, -1): "B", (-1, 1): "C", (1, 1): "D"}
    for (sx, sy), letter in names.items():
        quarters[(sx, sy)] = split(halves[sx], "SlabPiece_%s_Mars_SM" % letter, 1, sy)
    for ob in [slab] + list(halves.values()) + list(quarters.values()):
        me = ob.data
        while len(me.materials) < 3:
            me.materials.append(None)
        for k in range(len(me.materials)):      # every slot (the cap included: its paint is lean) wears the meat look
            me.materials[k] = meat
        ob["_slots"] = len(me.materials)
    return sc, slab, halves, quarters, meat


def export_pieces(quarters):
    os.makedirs(PIECES, exist_ok=True)
    out = {}
    for key, ob in quarters.items():
        dup = ob.copy()
        dup.data = ob.data.copy()
        name = ob.name
        ob.name = name + "_anim"
        dup.name = dup.data.name = name
        bpy.context.scene.collection.objects.link(dup)
        dup.location = (0, 0, 0)
        dup.rotation_euler = (0, 0, 0)
        dup.animation_data_clear()
        dup.hide_render = False
        # slot names for the importer: Flesh, Skin, Cut (the cap); every slot gets MeatSlab_Mars_MI in Unreal
        while len(dup.data.materials) < 3:
            dup.data.materials.append(None)
        for k, nm in enumerate(("Flesh", "Skin", "Cut")):
            dup.data.materials[k] = bpy.data.materials.get(nm) or bpy.data.materials.new(nm)
        piv, size = recentre(dup)
        dup.location = (0, 0, 0)
        for o in bpy.context.scene.objects:
            o.select_set(o is dup)
        bpy.context.view_layer.objects.active = dup
        dup.data.uv_layers.active = dup.data.uv_layers[0]
        path = os.path.join(PIECES, name + ".fbx")
        bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, mesh_smooth_type="EDGE",
                                 use_mesh_modifiers=True, add_leaf_bones=False, bake_anim=False, use_tspace=False,
                                 apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y",
                                 use_triangles=True, colors_type="LINEAR")
        caps = sum(1 for p in dup.data.polygons if p.material_index == 2)
        meta = {"name": name, "fbx": path, "pivot_in_slab_cm": [round(v * 100.0, 3) for v in piv],
                "size_cm": [round(v * 100.0, 3) for v in size], "tris": len(dup.data.polygons), "cap_faces": caps,
                "slots": ["Flesh", "Skin", "Cut"], "source": SLAB_FBX,
                "note": "devlog stand-in for a bench-cut slab quarter (cut x = 0 then y = 0); not a game food"}
        with open(os.path.splitext(path)[0] + ".json", "w") as fh:
            json.dump(meta, fh, indent=1)
        out[name] = meta
        bpy.data.objects.remove(dup)
        ob.name = name
        print("PIECE %s size %s cm tris %d caps %d" % (name, meta["size_cm"], meta["tris"], caps))
    return out


def stage(sc, slab, halves, quarters):
    # board under the slab (top at z 0), on the stage floor
    board = box("DL_CutBoard", (0.56, 0.38, 0.03), (0, 0, -0.015), board_material())
    dl.ground(sc, extent=3.0, z=-0.75, size=60.0, cell=0.5)
    box("DL_Bench", (0.9, 0.6, 0.72), (0, 0, -0.03 - 0.36), dl._mat("DL_BenchMat", (0.018, 0.017, 0.017, 1.0), 0.7))
    dl.world_ambient(sc, strength_amb=0.35)
    cam = dl.camera(sc, lens=55.0)
    target = Vector((0.0, -0.01, 0.045))
    dl.three_point(sc, target, 3.0, key_az=-40.0, energy=0.72)
    lo, hi = Vector((-0.23, -0.14, 0.0)), Vector((0.23, 0.14, 0.125))
    pts = dl.box_corners(lo, hi)

    def cam_at(f):
        u = f / float(FRAMES - 1)
        az = 28.0 - 8.0 * u
        d = dl.orbit_dir(az, 34.0)
        dist = dl.fit_distance(pts, target, d, cam.data.lens, fill=0.70) * (1.0 - 0.06 * dl.smooth(u))
        return target + d * dist

    # the two cuts: a thin streak of light (3 mm) the length of the cut sweeping down through the meat
    sheet_m = sheet_material()
    s1 = box("DL_Sheet1", (0.003, 0.30, 0.003), (0, 0, 0.3), sheet_m)
    s2 = box("DL_Sheet2", (0.50, 0.003, 0.003), (0, 0, 0.3), sheet_m)
    for f in range(0, FRAMES + 1):
        sc.frame_set(f)
        cam.location = cam_at(f)
        dl.look_at(cam, cam.location, target)
        cam.keyframe_insert("location", frame=f)
        cam.keyframe_insert("rotation_euler", frame=f)
        for s, (a, b) in ((s1, CUT1), (s2, CUT2)):
            u = (f - a) / float(b - a)
            z = 0.15 - 0.16 * ease(u) if 0.0 <= u <= 1.0 else 0.6
            s.location = (0, 0, z)
            s.keyframe_insert("location", frame=f)
        for sx, ob in halves.items():
            off, tip = part_pose(f, PART1, Vector((sx, 0, 0)))
            ob.location = off
            ob.rotation_euler = (0.0, -math.radians(tip) * sx, 0.0)
            ob.keyframe_insert("location", frame=f)
            ob.keyframe_insert("rotation_euler", frame=f)
        for (sx, sy), ob in quarters.items():
            off1, _ = part_pose(f, PART1, Vector((sx, 0, 0)))
            off1.z = 0.0
            off2, tip = part_pose(f, PART2, Vector((0, sy, 0)))
            ob.location = off1 + off2
            ob.rotation_euler = (math.radians(tip) * sy, 0.0, 0.0)
            ob.keyframe_insert("location", frame=f)
            ob.keyframe_insert("rotation_euler", frame=f)
    # the sheets only show while they sweep
    key_vis(s1, [CUT1])
    key_vis(s2, [CUT2])
    key_vis(slab, [(0, PART1[0])])
    for ob in halves.values():
        key_vis(ob, [(PART1[0], PART2[0])])
    for ob in quarters.values():
        key_vis(ob, [(PART2[0], FRAMES + 1)])
    return cam


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    draft = "--draft" in argv
    sc, slab, halves, quarters, meat = build(draft)
    if "--export" in argv:
        export_pieces(quarters)
    if "--no-render" in argv:
        print("DEVLOG_PAN_CUT_OK (no render)")
        return
    stage(sc, slab, halves, quarters)
    out = DRAFT_OUT if draft else OUT
    os.makedirs(out, exist_ok=True)
    frames = range(0, FRAMES, 10) if draft else range(FRAMES)
    sc.frame_start, sc.frame_end = 0, FRAMES - 1
    for k, f in enumerate(frames):
        sc.frame_set(f)
        dl.render_to(sc, os.path.join(out, "%05d.png" % k))
    shot = {"fps": 3 if draft else 30, "frames": len(frames), "real_seconds_covered": FRAMES / 30.0,
            "description": "Beat 3 bench insert: MeatSlab_Mars_SM (vertex-colour albedo) on a board, two clean planar "
                           "cuts (x = 0 at frames %d-%d, y = 0 at %d-%d) shown as a sweeping streak of light, the parts "
                           "parting %.1f cm with a %.1f cm hop; four pieces from frame %d." % (
                               CUT1[0], CUT1[1], CUT2[0], CUT2[1], GAP * 200.0, HOP * 100.0, PART2[1]),
            "source": "Tools/Devlog/footage/blender/devlog_pan_cut.py%s" % (" --draft" if draft else ""),
            "visible": [[0.0, 0.8, "whole slab on the board"], [0.8, 1.8, "cut 1, halves part"],
                        [2.2, 3.2, "cut 2, quarters part"], [3.2, 5.0, "four pieces, slow push"]]}
    with open(os.path.join(out, "shot.json"), "w") as fh:
        json.dump(shot, fh, indent=1)
    print("DEVLOG_PAN_CUT_OK %s %d frames" % (out, len(frames)))


main()
