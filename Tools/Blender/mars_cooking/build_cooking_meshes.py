"""Builds the Mars cooking props and exports them as FBX. Re-runnable headless:

    blender -b --factory-startup --python build_cooking_meshes.py -- [--out <dir>] [--sheet <png>] [--cube [--save <blend>]]

A plain run builds and exports the PAN ONLY. Since 2026-10-07 MeatCube_Mars_SM is hand-authored: Stephen's
D:\Repo\Content\Cooking\CookingProps.blend (this builder's cube plus a geometry-nodes noise) is its source and
export\MeatCube_Mars_SM.fbx is exported from there. --cube regenerates the procedural cube and overwrites that FBX;
--save is only honoured with --cube, because saving a pan-only scene would replace his .blend.

MeatCube_Mars_SM  the imperfect wagyu cube. UV0 = one island per face (cooking_spec.face_uv); UV1 / UV2 carry the
                  raw -> cooked shape offset in Unreal local centimetres (UV1 = x, y; UV2.x = z), blended in by the
                  meat material's Shape value.
FryPan_Mars_SM    a lathed stand-in pan, pivot at the centre of the cooking surface, handle along +X. Slot 0 = Pan,
                  slot 1 = Handle. The pan material works in pan-local polar space, so any lathed pan fits it.
"""
import math
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cooking_spec as spec  # noqa: E402


def _args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"out": spec.EXPORT_DIR, "save": None, "sheet": None, "cube": False}
    i = 0
    while i < len(argv):
        key = argv[i].lstrip("-")
        if key == "cube":
            out["cube"] = True
        elif key in out and i + 1 < len(argv):
            out[key] = argv[i + 1]
            i += 1
        i += 1
    return out


# ---------------------------------------------------------------- shape functions
def _lumps(p, seed, freq):
    """Smooth pseudo-noise in -1..1 from a few fixed sinusoids (deterministic, no lattice artefacts)."""
    rng = np.random.default_rng(seed)
    total = np.zeros(len(p))
    amp_sum = 0.0
    for k in range(7):
        w = rng.normal(size=3)
        w = w / np.linalg.norm(w) * freq * (1.0 + 0.45 * k)
        amp = 1.0 / (1.0 + 0.6 * k)
        total += amp * np.sin(p @ w + rng.uniform(0.0, math.tau))
        amp_sum += amp
    return total / amp_sum


def _round_box(p, bevel):
    """Unit-cube surface points -> rounded box of edge radius `bevel`; returns (position, outward direction)."""
    q = np.clip(p, -(1.0 - bevel), 1.0 - bevel)
    d = p - q
    d /= np.linalg.norm(d, axis=1, keepdims=True)
    return q + bevel * d, d


def _cube_shapes(p):
    """Raw and cooked positions (cm, Blender axes) for unit-cube surface points p."""
    half = spec.CUBE_HALF_CM
    raw, d_raw = _round_box(p, spec.CUBE_BEVEL_RAW)
    raw = raw * half + d_raw * (_lumps(p, 11, 1.6) * spec.CUBE_LUMP_RAW_CM)[:, None]
    # a cut cube is never square: a little skew and unequal sides
    skew = np.array([[1.0, 0.018, 0.012], [-0.01, 0.975, 0.02], [0.006, -0.014, 1.02]])
    raw = raw @ skew.T

    cooked, d_ck = _round_box(p, spec.CUBE_BEVEL_COOKED)
    s = np.sort(np.abs(p), axis=1)
    puff = (1.0 - s[:, 0] ** 2) * (1.0 - s[:, 1] ** 2)           # 1 at a face centre, 0 on edges
    crust = _lumps(p, 23, 3.4) * 0.65 + _lumps(p, 31, 7.5) * 0.35
    cooked = cooked * half + d_ck * (puff * spec.CUBE_BULGE_COOKED_CM + crust * spec.CUBE_LUMP_COOKED_CM)[:, None]
    cooked = cooked @ skew.T
    return raw, cooked


# ---------------------------------------------------------------- mesh helpers
def _new_object(name, verts_cm, faces, slots=("Default",), face_slots=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata((np.asarray(verts_cm) * 0.01).tolist(), [], faces)
    for s in slots:
        mat = bpy.data.materials.get(s) or bpy.data.materials.new(s)
        mesh.materials.append(mat)
    if face_slots is not None:
        mesh.polygons.foreach_set("material_index", face_slots)
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _mark_sharp(mesh, degrees):
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(mesh)
    limit = math.radians(degrees)
    for e in bm.edges:
        if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > limit:
            e.smooth = False
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()


# ---------------------------------------------------------------- meat cube
def build_cube():
    grid = spec.cube_grid()
    n = len(grid)
    index = {}
    points, faces, loop_uv = [], [], []
    for f, (nrm, ua, va) in enumerate(spec.FACES):
        nrm, ua, va = np.array(nrm, float), np.array(ua, float), np.array(va, float)
        ids = np.zeros((n, n), int)
        for j, b in enumerate(grid):
            for i, a in enumerate(grid):
                p = nrm + a * ua + b * va
                key = tuple(np.round(p, 5))
                if key not in index:
                    index[key] = len(points)
                    points.append(p)
                ids[j, i] = index[key]
        outward = np.cross(ua, va) @ nrm > 0.0            # winding so the face normal points out
        for j in range(n - 1):
            for i in range(n - 1):
                corners = [(j, i), (j, i + 1), (j + 1, i + 1), (j + 1, i)]
                if not outward:
                    corners.reverse()
                faces.append([int(ids[c]) for c in corners])
                loop_uv.append([spec.face_uv(f, grid[c[1]], grid[c[0]]) for c in corners])
    p = np.array(points)
    raw, cooked = _cube_shapes(p)
    obj = _new_object("MeatCube_Mars_SM", raw, faces, slots=("Meat",))
    mesh = obj.data

    offset = cooked - raw                                  # cm, Blender axes
    offset_ue = offset * np.array([1.0, -1.0, 1.0])        # Unreal local (Y mirrored)
    uv0 = mesh.uv_layers.new(name="UVMap")
    uv1 = mesh.uv_layers.new(name="ShapeXY")
    uv2 = mesh.uv_layers.new(name="ShapeZ")
    li = 0
    for poly, uvs in zip(mesh.polygons, loop_uv):
        for k, vi in enumerate(poly.vertices):
            u, v = uvs[k]
            uv0.data[li].uv = (u, 1.0 - v)                 # the FBX import flips V back
            ox, oy, oz = offset_ue[vi]
            uv1.data[li].uv = (ox, 1.0 - oy)
            uv2.data[li].uv = (oz, 1.0)
            li += 1
    mesh.update()
    obj["cooking_offset_max_cm"] = float(np.abs(offset).max())
    return obj, raw, cooked


# ---------------------------------------------------------------- frying pan
def _bezier(p0, p1, p2, p3, count):
    t = np.linspace(0.0, 1.0, count)[:, None]
    return ((1 - t) ** 3) * p0 + 3 * ((1 - t) ** 2) * t * p1 + 3 * (1 - t) * (t ** 2) * p2 + (t ** 3) * p3


def _pan_profile():
    """(r, z) from the centre of the cooking surface, up the wall, over the rim and back under to the centre."""
    rb, rr, h, t = spec.PAN_BASE_R, spec.PAN_RIM_R, spec.PAN_HEIGHT, spec.PAN_THICK
    base = [(r, 0.0) for r in (0.0, 1.5, 3.0, 4.5, 6.0, 7.5, 8.6)]
    wall = _bezier(np.array([rb, 0.0]), np.array([rb + 3.1, 0.0]), np.array([rr - 0.7, h * 0.42]), np.array([rr, h]), 16)
    tan = np.gradient(wall, axis=0)
    tan /= np.linalg.norm(tan, axis=1, keepdims=True)
    outer = wall + np.stack([tan[:, 1], -tan[:, 0]], axis=1) * t
    rim = [(rr + 0.05, h + 0.09), (rr + 0.2, h + 0.11), (rr + 0.33, h + 0.04)]
    under = [(r, -t) for r in (8.6, 7.0, 5.0, 3.0, 1.5, 0.0)]
    return base + [tuple(x) for x in wall] + rim + [tuple(x) for x in outer[::-1][1:]] + under


def _lathe(profile, segments):
    verts, faces = [], []
    rings = []
    for r, z in profile:
        if r < 1e-6:
            rings.append([len(verts)])
            verts.append((0.0, 0.0, z))
        else:
            start = len(verts)
            for s in range(segments):
                a = math.tau * s / segments
                verts.append((r * math.cos(a), r * math.sin(a), z))
            rings.append(list(range(start, start + segments)))
    for a, b in zip(rings[:-1], rings[1:]):
        for s in range(segments):
            s2 = (s + 1) % segments
            if len(a) == 1:
                faces.append([a[0], b[s], b[s2]])
            elif len(b) == 1:
                faces.append([a[s], b[0], a[s2]])
            else:
                faces.append([a[s], b[s], b[s2], a[s2]])
    return verts, faces


def _sweep(stations, sides=14, power=2.6):
    """A capped loft of superellipse sections: stations = (centre xyz, half width, half height)."""
    verts, faces = [], []
    for c, hw, hh in stations:
        for k in range(sides):
            a = math.tau * k / sides
            ca, sa = math.cos(a), math.sin(a)
            y = hw * math.copysign(abs(ca) ** (2.0 / power), ca)
            z = hh * math.copysign(abs(sa) ** (2.0 / power), sa)
            verts.append((c[0], c[1] + y, c[2] + z))
    for i in range(len(stations) - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            a, b = i * sides, (i + 1) * sides
            faces.append([a + k, b + k, b + k2, a + k2])
    faces.append(list(range(sides - 1, -1, -1)))
    last = (len(stations) - 1) * sides
    faces.append(list(range(last, last + sides)))
    return verts, faces


def build_pan():
    rr, h = spec.PAN_RIM_R, spec.PAN_HEIGHT
    verts, faces = _lathe(_pan_profile(), spec.PAN_SEGMENTS)
    slots = [0] * len(faces)

    def add(part, slot):
        v, f = part
        base = len(verts)
        verts.extend(v)
        faces.extend([[base + i for i in face] for face in f])
        slots.extend([slot] * len(f))

    neck = [((rr - 0.2 + 1.05 * i, 0.0, h - 1.25 + 0.42 * i), 1.15 - 0.03 * i, 0.36) for i in range(7)]
    add(_sweep(neck, sides=12, power=4.0), 0)
    grip = []
    for i in range(13):
        t = i / 12.0
        swell = math.sin(math.pi * min(1.0, t * 1.15)) ** 0.35 if t > 0.0 else 0.0
        end = 0.35 + 0.65 * min(1.0, (1.0 - t) * 6.0) ** 0.5
        hw = (0.95 + 0.75 * swell) * end
        hh = (0.62 + 0.42 * swell) * end
        grip.append(((rr + 5.2 + 14.5 * t, 0.0, h + 1.2 + 2.6 * t), max(hw, 0.2), max(hh, 0.15)))
    add(_sweep(grip, sides=16, power=2.4), 1)

    obj = _new_object("FryPan_Mars_SM", np.array(verts), faces, slots=("Pan", "Handle"), face_slots=slots)
    mesh = obj.data
    uv = mesh.uv_layers.new(name="UVMap")
    span = rr + 22.0
    for loop in mesh.loops:
        co = mesh.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = (0.5 + co.x * 100.0 / (2.0 * span), 0.5 + co.y * 100.0 / (2.0 * span))
    _mark_sharp(mesh, 50.0)
    return obj


# ---------------------------------------------------------------- export + review sheet
def _export(obj, path):
    for o in bpy.context.scene.objects:
        o.select_set(o is obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, mesh_smooth_type="EDGE",
                             use_mesh_modifiers=True, add_leaf_bones=False, bake_anim=False, use_tspace=False,
                             apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y")


def _look_at(cam, eye, target):
    fwd = np.array(target, float) - np.array(eye, float)
    cam.location = eye
    cam.rotation_euler = (math.atan2(math.hypot(fwd[0], fwd[1]), -fwd[2]), 0.0, -math.atan2(fwd[0], fwd[1]))


def _sheet(path, cube, cooked_cm, pan):
    """Workbench review renders: <path> = the pan, <path>_cube = raw (left) and cooked (right) cube."""
    scene = bpy.context.scene
    ghost = cube.copy()
    ghost.data = cube.data.copy()
    ghost.name = "MeatCube_CookedPreview"
    scene.collection.objects.link(ghost)
    ghost.data.vertices.foreach_set("co", (cooked_cm * 0.01).ravel())
    ghost.data.update()
    k = spec.CUBE_HALF_CM / 4.0                    # the cube shot was framed for the 8 cm cube
    cube.location = (-0.06 * k, -2.0, 0.0)
    ghost.location = (0.06 * k, -2.0, 0.0)
    cam_data = bpy.data.cameras.new("SheetCam")
    cam_data.clip_start, cam_data.clip_end = 0.01, 100.0
    cam = bpy.data.objects.new("SheetCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "SINGLE"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 1400, 800
    stem, ext = os.path.splitext(path)
    for name, lens, eye, target in ((stem, 50, (0.1, -0.62, 0.5), (0.06, 0.0, 0.0)),
                                    (stem + "_cube", 85, (0.0, -2.0 - 0.56 * k, 0.26 * k), (0.0, -2.0, 0.0))):
        cam_data.lens = lens
        _look_at(cam, eye, target)
        scene.render.filepath = name + ext
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(ghost)
    bpy.data.objects.remove(cam)
    cube.location = (0.0, 0.0, 0.0)


def main():
    args = _args()
    os.makedirs(args["out"], exist_ok=True)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    cube, raw, cooked = build_cube()
    pan = build_pan()
    if args["cube"]:
        _export(cube, os.path.join(args["out"], "MeatCube_Mars_SM.fbx"))
    else:
        print("cube not exported: MeatCube_Mars_SM is hand-authored in CookingProps.blend (pass --cube to overwrite)")
    _export(pan, os.path.join(args["out"], "FryPan_Mars_SM.fbx"))
    if args["sheet"]:
        _sheet(args["sheet"], cube, cooked, pan)
    cube.location = (0.0, 0.0, 0.0)
    pan.location = (0.3, 0.0, 0.0)
    if args["save"] and not args["cube"]:
        print("--save ignored without --cube: it would replace the hand-authored cube in %s" % args["save"])
    elif args["save"]:
        os.makedirs(os.path.dirname(args["save"]), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=args["save"])
    print("cube verts %d tris %d  offset max %.3f cm  bounds %s%s" % (
        len(cube.data.vertices), sum(len(p.vertices) - 2 for p in cube.data.polygons),
        cube["cooking_offset_max_cm"], np.round(np.abs(raw).max(axis=0), 3), "" if args["cube"] else " (not exported)"))
    print("pan verts %d tris %d" % (len(pan.data.vertices), sum(len(p.vertices) - 2 for p in pan.data.polygons)))
    print("COOKING_MESHES_OK")


main()
