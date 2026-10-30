"""Scene plumbing for the crypt making-of footage (devlog_crypt_shots.py): render setup, cameras, the reveal
geometry-nodes group, ground grid, lights, look materials, and the kit import (read-only).

Everything here runs inside Blender 5.2 (headless).  Nothing is ever saved into the kit's source tree: the
add-on is imported with sys.dont_write_bytecode, the library .blend is only appended from.
"""

import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

KIT_PARENT = r"C:\Users\Stephen\Documents\Houdini\Blender"
KIT_SRC = os.path.join(KIT_PARENT, "vns_trim_sheet")
LIB = os.path.join(KIT_PARENT, "kit_library_mise", "Crypt_Kit_Library.blend")
TEX = os.path.join(KIT_PARENT, "textures")
BG_HEX = "#15151a"


# ------------------------------------------------------------------ kit import (read-only)
def kit():
    """Import the vns_trim_sheet add-on package from its source folder without writing __pycache__ there."""
    sys.dont_write_bytecode = True
    if KIT_PARENT not in sys.path:
        sys.path.insert(0, KIT_PARENT)
    import vns_trim_sheet.assets.crypt  # noqa: F401
    import vns_trim_sheet.assets.geo  # noqa: F401
    return sys.modules["vns_trim_sheet.assets.crypt"], sys.modules["vns_trim_sheet.assets.geo"]


def append_materials(names):
    """Append materials (with their images) from the kit library; image paths come back absolute."""
    have = [n for n in names if bpy.data.materials.get(n) is None]
    if have:
        with bpy.data.libraries.load(LIB, link=False) as (src, dst):
            dst.materials = [n for n in have if n in src.materials]
    _abs_images()
    return [bpy.data.materials.get(n) for n in names]


def append_objects(names):
    """Append SM_* objects from the library (meshes + materials), not linked to a scene; returns {name: object}."""
    with bpy.data.libraries.load(LIB, link=False) as (src, dst):
        dst.objects = [n for n in names if n in src.objects]
    out = {}
    for ob in dst.objects:
        if ob is not None:
            out[ob.name] = ob
    _abs_images()
    return out


def library_object_names():
    with bpy.data.libraries.load(LIB, link=False) as (src, dst):
        return sorted(n for n in src.objects if n.startswith("SM_"))


def _abs_images():
    libdir = os.path.dirname(LIB)
    for im in bpy.data.images:
        fp = im.filepath
        if fp.startswith("//"):
            p = os.path.normpath(os.path.join(libdir, fp[2:].replace("\\", os.sep)))
            if os.path.isfile(p):
                im.filepath = p


# ------------------------------------------------------------------ colour
def srgb_to_lin(c):
    c = float(c)
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_lin(h, a=1.0):
    h = h.lstrip("#")
    return tuple(srgb_to_lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)) + (a,)


BG = hex_lin(BG_HEX)


# ------------------------------------------------------------------ scene / render
def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    w = bpy.data.worlds.new("DL_World")
    sc.world = w
    w.color = BG[:3]
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = BG
    bg.inputs["Strength"].default_value = 1.0
    return sc


def setup_output(sc, res):
    r = sc.render
    r.resolution_x, r.resolution_y = res
    r.resolution_percentage = 100
    r.film_transparent = False
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGB"
    r.image_settings.color_depth = "8"
    r.fps = 30
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0.0
    sc.view_settings.gamma = 1.0
    sc.display_settings.display_device = "sRGB"


def workbench(sc, color_type="SINGLE", single=(0.62, 0.62, 0.62)):
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.studio_light = "Default"
    sh.use_world_space_lighting = True     # light fixed in the world (lights the room face, -y) while cameras orbit
    sh.studiolight_rotate_z = 0.0
    sh.color_type = color_type
    sh.single_color = single
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.cavity_ridge_factor = 1.0
    sh.cavity_valley_factor = 1.0
    sh.curvature_ridge_factor = 1.0
    sh.curvature_valley_factor = 1.0
    sh.show_shadows = True
    sh.shadow_intensity = 0.55
    sh.show_specular_highlight = True
    sc.display.light_direction = (-0.45, -0.55, 0.70)
    sc.display.shadow_focus = 0.2
    sc.display.render_aa = "16"
    sc.world.color = BG[:3]


def eevee(sc, samples=24):
    sc.render.engine = "BLENDER_EEVEE"
    e = sc.eevee
    e.taa_render_samples = samples
    e.use_shadows = True
    try:
        e.use_raytracing = False
        e.use_fast_gi = True
    except AttributeError:
        pass


# ------------------------------------------------------------------ camera
def camera(sc, lens=40.0):
    cd = bpy.data.cameras.new("DL_Cam")
    cd.lens = lens
    cd.sensor_width = 36.0
    cd.clip_start = 0.05
    cd.clip_end = 2000.0
    cam = bpy.data.objects.new("DL_Cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam


def look_at(cam, eye, target):
    eye, target = Vector(eye), Vector(target)
    cam.location = eye
    cam.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()


def orbit_dir(az, el):
    """Unit vector from the target to the eye.  az 0 = in front (-y), positive az swings the camera to +x."""
    a, e = math.radians(az), math.radians(el)
    return Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))


def fit_distance(points, target, d, lens, aspect=16 / 9, fill=0.72, sensor=36.0):
    """Distance along unit direction d (target -> eye) at which every point fits in `fill` of the frame."""
    target = Vector(target)
    fwd = -Vector(d)
    right = fwd.cross(Vector((0, 0, 1)))
    if right.length < 1e-6:
        right = Vector((1, 0, 0))
    right.normalize()
    up = right.cross(fwd).normalized()
    tx = (sensor / 2.0) / lens * fill
    ty = tx / aspect

    def ok(dist):
        eye = target + Vector(d) * dist
        for p in points:
            v = Vector(p) - eye
            z = v.dot(fwd)
            if z <= 0.05:
                return False
            if abs(v.dot(right)) / z > tx or abs(v.dot(up)) / z > ty:
                return False
        return True
    lo, hi = 0.1, 10.0
    while not ok(hi):
        hi *= 2.0
    for _ in range(40):
        mid = 0.5 * (lo + hi)
        if ok(mid):
            hi = mid
        else:
            lo = mid
    return hi


def bbox_points(objs):
    pts = []
    for ob in objs:
        for c in ob.bound_box:
            pts.append(ob.matrix_world @ Vector(c))
    return pts


def bbox(objs):
    pts = bbox_points(objs)
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def box_corners(lo, hi):
    return [Vector((x, y, z)) for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]


def smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3.0 - 2.0 * t)


# ------------------------------------------------------------------ reveal geometry nodes
def reveal_group():
    """DL_Reveal: faces carry a float `reveal` (build step, or a part's base height).  Faces with reveal > Threshold
    are deleted (Invert: the ones <= Threshold); a face revealed less than Window ago is lifted by
    Drop * (1 - t^2) so blocks fall into place."""
    ng = bpy.data.node_groups.get("DL_Reveal")
    if ng is not None:
        return ng
    ng = bpy.data.node_groups.new("DL_Reveal", "GeometryNodeTree")
    it = ng.interface
    it.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    it.new_socket("Threshold", in_out="INPUT", socket_type="NodeSocketFloat")
    it.new_socket("Drop", in_out="INPUT", socket_type="NodeSocketFloat")
    it.new_socket("Window", in_out="INPUT", socket_type="NodeSocketFloat")
    it.new_socket("Invert", in_out="INPUT", socket_type="NodeSocketBool")
    it.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    N, L = ng.nodes, ng.links
    gi = N.new("NodeGroupInput")
    go = N.new("NodeGroupOutput")
    na = N.new("GeometryNodeInputNamedAttribute")
    na.data_type = "FLOAT"
    na.inputs["Name"].default_value = "reveal"
    # drop offset: Drop * (1 - t^2), t = clamp((Threshold - reveal) / Window)
    sub = N.new("ShaderNodeMath")
    sub.operation = "SUBTRACT"
    L.new(gi.outputs["Threshold"], sub.inputs[0])
    L.new(na.outputs["Attribute"], sub.inputs[1])
    div = N.new("ShaderNodeMath")
    div.operation = "DIVIDE"
    div.use_clamp = True
    L.new(sub.outputs[0], div.inputs[0])
    L.new(gi.outputs["Window"], div.inputs[1])
    sq = N.new("ShaderNodeMath")
    sq.operation = "MULTIPLY"
    L.new(div.outputs[0], sq.inputs[0])
    L.new(div.outputs[0], sq.inputs[1])
    one = N.new("ShaderNodeMath")
    one.operation = "SUBTRACT"
    one.inputs[0].default_value = 1.0
    L.new(sq.outputs[0], one.inputs[1])
    mul = N.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    L.new(one.outputs[0], mul.inputs[0])
    L.new(gi.outputs["Drop"], mul.inputs[1])
    cxyz = N.new("ShaderNodeCombineXYZ")
    L.new(mul.outputs[0], cxyz.inputs["Z"])
    sp = N.new("GeometryNodeSetPosition")
    L.new(gi.outputs["Geometry"], sp.inputs["Geometry"])
    L.new(cxyz.outputs[0], sp.inputs["Offset"])
    # visibility
    cmp = N.new("FunctionNodeCompare")
    cmp.data_type = "FLOAT"
    cmp.operation = "GREATER_THAN"
    L.new(na.outputs["Attribute"], cmp.inputs["A"])
    L.new(gi.outputs["Threshold"], cmp.inputs["B"])
    xor = N.new("FunctionNodeBooleanMath")
    xor.operation = "XOR"
    L.new(cmp.outputs["Result"], xor.inputs[0])
    L.new(gi.outputs["Invert"], xor.inputs[1])
    dg = N.new("GeometryNodeDeleteGeometry")
    dg.domain = "FACE"
    L.new(sp.outputs["Geometry"], dg.inputs["Geometry"])
    L.new(xor.outputs[0], dg.inputs["Selection"])
    L.new(dg.outputs["Geometry"], go.inputs["Geometry"])
    return ng


def add_reveal(ob, threshold=1e9, drop=0.0, window=1.0, invert=False):
    md = ob.modifiers.new("DL_Reveal", "NODES")
    md.node_group = reveal_group()
    set_reveal(ob, threshold, drop, window, invert)
    return md


def _sock(name):
    return reveal_group().interface.items_tree[name].identifier


def set_reveal(ob, threshold=None, drop=None, window=None, invert=None):
    md = ob.modifiers["DL_Reveal"]
    for name, v in (("Threshold", threshold), ("Drop", drop), ("Window", window), ("Invert", invert)):
        if v is not None:
            # Blender 5.x: modifier inputs are md.properties.inputs.<socket id>.value (no longer ID properties)
            getattr(md.properties.inputs, _sock(name)).value = v
    ob.update_tag()


def set_face_float(me, name, values):
    a = me.attributes.get(name)
    if a is not None:
        me.attributes.remove(a)
    a = me.attributes.new(name, "FLOAT", "FACE")
    a.data.foreach_set("value", np.asarray(values, np.float32))


def part_base_reveal(me, attr="trim_part"):
    """Per-face reveal = the min z of the face's part (trim_part), so a threshold climbing in metres lays the piece
    stone by stone; meshes without trim_part fall back to each face's own min z."""
    n = len(me.polygons)
    co = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    zs = co.reshape(-1, 3)[:, 2]
    fmin = np.array([min(zs[v] for v in p.vertices) for p in me.polygons], np.float32)
    a = me.attributes.get(attr)
    if a is None or a.domain != "FACE":
        return fmin
    parts = np.empty(n, np.int32)
    a.data.foreach_get("value", parts)
    out = np.empty(n, np.float32)
    fmax = np.array([max(zs[v] for v in p.vertices) for p in me.polygons], np.float32)
    for pid in np.unique(parts):
        m = parts == pid
        lo, hi = fmin[m].min(), fmax[m].max()
        # a stone appears when the climb reaches its base; a tall hidden core / membrane only near its top
        out[m] = lo if hi - lo < 1.2 else hi - 0.6
    return out


# ------------------------------------------------------------------ ground grid
def _mat(name, rgba, rough=0.9):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = rgba
    m.roughness = rough
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = rgba
    b.inputs["Roughness"].default_value = rough
    return m


WB_FLOOR_GAIN = 0.135   # Workbench "Default" studio light on an upward face seen at ~25 deg: shade / colour (measured)


def _wb(rgba):
    """Workbench colour that shades to `rgba` on the floor."""
    return tuple(min(1.0, c / WB_FLOOR_GAIN) for c in rgba[:3]) + (1.0,)


def _ground_mat(name, rgba, floor=False):
    """EEVEE: the floor is mostly unlit backdrop colour (emission) plus a faint diffuse, so its far edge melts into
    the #15151a backdrop while shadows still ground the subject; grid lines are pure emission.  Workbench: the
    diffuse_color is pre-divided by the studio light's floor shading so it renders at the same value."""
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = _wb(rgba)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = rgba
    em.inputs["Strength"].default_value = 0.85 if floor else 1.0
    if floor:
        df = nt.nodes.new("ShaderNodeBsdfDiffuse")
        df.inputs["Color"].default_value = (0.0035, 0.0035, 0.004, 1.0)
        add = nt.nodes.new("ShaderNodeAddShader")
        nt.links.new(em.outputs[0], add.inputs[0])
        nt.links.new(df.outputs[0], add.inputs[1])
        nt.links.new(add.outputs[0], out.inputs["Surface"])
    else:
        nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def ground(sc, extent=12.0, center=(0, 0), z=-0.402, size=400.0, cell=1.0, width=None):
    """A big dark floor and a 1 m grid of thin lines fading out in three rings, so the subject stands on a work
    plane.  Real geometry, so it renders the same in every Workbench colour mode and in EEVEE."""
    import bmesh
    cx, cy = center
    me = bpy.data.meshes.new("DL_Ground")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size / 2.0)
    bm.to_mesh(me)
    bm.free()
    floor = bpy.data.objects.new("DL_Ground", me)
    floor.location = (cx, cy, z)
    floor.data.materials.append(_ground_mat("DL_GroundMat", BG, floor=True))
    floor.color = _wb(BG)
    sc.collection.objects.link(floor)
    rings = [(extent, "#383843"), (extent * 1.8, "#2b2b34"), (extent * 3.0, "#22222a")]
    objs = [floor]
    inner = 0.0
    w = width if width is not None else 0.012 * max(1.0, extent / 12.0)
    for k, (ext, hexc) in enumerate(rings):
        bm = bmesh.new()
        n = int(ext / cell)

        def quad(a0, a1, b0, b1):
            if a1 - a0 > 1e-6 and b1 - b0 > 1e-6:
                vs = [bm.verts.new((a0, b0, 0)), bm.verts.new((a1, b0, 0)), bm.verts.new((a1, b1, 0)),
                      bm.verts.new((a0, b1, 0))]
                bm.faces.new(vs)
        for i in range(-n, n + 1):
            c = i * cell
            if abs(c) < inner - 1e-6:   # inside the previous ring: only the two outer stubs
                quad(c - w, c + w, -ext, -inner)
                quad(c - w, c + w, inner, ext)
                quad(-ext, -inner, c - w, c + w)
                quad(inner, ext, c - w, c + w)
            else:
                quad(c - w, c + w, -ext, ext)
                quad(-ext, ext, c - w, c + w)
        me = bpy.data.meshes.new("DL_Grid%d" % k)
        bm.to_mesh(me)
        bm.free()
        g = bpy.data.objects.new("DL_Grid%d" % k, me)
        g.location = (cx, cy, z + 0.003)
        rgba = hex_lin(hexc)
        g.data.materials.append(_ground_mat("DL_GridMat%d" % k, rgba))
        g.color = _wb(rgba)
        sc.collection.objects.link(g)
        objs.append(g)
        inner = ext
    return objs


# ------------------------------------------------------------------ lights (EEVEE)
def three_point(sc, target, radius, key_az=-40.0, energy=1.0):
    """Warm key sun from the camera's left, cool fill, rim from behind (suns: no falloff to tune per shot)."""
    target = Vector(target)
    out = []

    def sun(name, az, el, strength, col, angle=3.0):
        ld = bpy.data.lights.new(name, "SUN")
        ld.energy = strength * energy
        ld.color = col
        ld.angle = math.radians(angle)
        ob = bpy.data.objects.new(name, ld)
        d = orbit_dir(az, el)
        ob.location = target + d * radius
        ob.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(ob)
        out.append(ob)
        return ob
    sun("DL_Key", key_az, 42.0, 3.4, (1.0, 0.86, 0.70), 4.0)
    sun("DL_Fill", key_az + 95.0, 18.0, 0.8, (0.60, 0.70, 1.0), 12.0)
    sun("DL_Rim", key_az + 170.0, 35.0, 2.0, (0.85, 0.88, 1.0), 2.0)
    return out


def world_ambient(sc, strength_amb=0.45, amb_hex="#55586a"):
    """Camera rays see the #15151a backdrop; everything else is lit by a dim blue-grey ambient."""
    w = sc.world
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    lp = nt.nodes.new("ShaderNodeLightPath")
    bgc = nt.nodes.new("ShaderNodeBackground")
    bgc.inputs["Color"].default_value = BG
    bgc.inputs["Strength"].default_value = 1.0
    amb = nt.nodes.new("ShaderNodeBackground")
    amb.inputs["Color"].default_value = hex_lin(amb_hex)
    amb.inputs["Strength"].default_value = strength_amb
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
    nt.links.new(amb.outputs[0], mix.inputs[1])
    nt.links.new(bgc.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])


# ------------------------------------------------------------------ look materials
CAT_HEX = {"stone": "#d79a5c", "plain": "#5fb3b3", "core": "#3a2c4c", "surf": "#5a78d6", "glow": "#ffb32e",
           "flame": "#ff6a1e", "iron": "#8b98ad", "steel": "#b9c2cf", "wood": "#9a5a34", "plank": "#b06a3a",
           "bone": "#e8dcc0", "wax": "#e8dcc0"}


def category_material(cat):
    key = cat.split(":")[0].split("#")[0]
    name = "DL_CAT_" + key
    m = bpy.data.materials.get(name)
    if m is None:
        m = _mat(name, hex_lin(CAT_HEX.get(key, "#cc5577")), 0.8)
    return m


def strip_checker_image(manifest_rows, size=1024, cells_per_unit=16):
    """The atlas's strip layout as a UV checker: one hue per strip, square checker cells inside it and a dark line
    at every strip boundary - mapped faces show which strip they landed in and how they scale."""
    name = "DL_StripChecker"
    im = bpy.data.images.get(name)
    if im is not None:
        return im
    import colorsys
    img = np.zeros((size, size, 3), np.float32)
    xs = (np.arange(size) + 0.5) / size
    X, Y = np.meshgrid(xs, xs)
    for i, r in enumerate(manifest_rows):
        m = (Y >= r["v0"]) & (Y < r["v1"])
        hue = (0.08 + i * 0.618034) % 1.0
        c1 = np.array(colorsys.hsv_to_rgb(hue, 0.50, 0.95))
        c2 = np.array(colorsys.hsv_to_rgb(hue, 0.55, 0.60))
        h = max(r["v1"] - r["v0"], 1e-6)
        rows_n = max(1, int(round(h * cells_per_unit)))
        k = (np.floor(X * cells_per_unit) + np.floor((Y - r["v0"]) / h * rows_n)) % 2
        img[m] = np.where(k[m][:, None] > 0.5, c1, c2)
        edge = m & ((np.abs(Y - r["v0"]) < 2.0 / size) | (np.abs(Y - r["v1"]) < 2.0 / size))
        img[edge] = (0.05, 0.05, 0.06)
    lin = np.where(img <= 0.04045, img / 12.92, ((img + 0.055) / 1.055) ** 2.4)
    im = bpy.data.images.new(name, size, size, alpha=False, float_buffer=True)
    px = np.ones((size, size, 4), np.float32)
    px[..., :3] = lin
    im.pixels.foreach_set(px.ravel())
    im.pack()
    return im


def checker_material(image):
    name = "DL_CheckerMat"
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = image
    t.interpolation = "Closest"
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    nt.nodes.active = t
    m.diffuse_color = (0.8, 0.8, 0.8, 1.0)
    return m


def paint_wash_material(src, biome="Bellfold"):
    """A copy of an atlas / surface material with the v2.2 painterly wash the Unreal masters add (crypt_export
    PAINT_STOPS / PAINT_SCALARS, mise_mars_ue PAINT_WASH_HLSL): the paint mask, box-projected in object space at
    PaintMaskTile 6 m and turned PaintAngle 17 deg, through the biome's 5-key ramp, overlaid on the base colour at
    PaintStrength 0.35; the brush-stroke map at PaintNormalTile 2 m as a light relief."""
    name = src.name + "_Wash"
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    m = src.copy()
    m.name = name
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    base_link = bsdf.inputs["Base Color"].links[0] if bsdf.inputs["Base Color"].links else None
    stops = {"Bellfold": ((0.30, 0.24, 0.34), (0.55, 0.50, 0.46), (0.78, 0.74, 0.64))}[biome]
    pdir = os.path.join(TEX, "mise_paint")

    def img(fn):
        im = bpy.data.images.get(fn) or bpy.data.images.load(os.path.join(pdir, fn), check_existing=True)
        im.colorspace_settings.name = "Non-Color"
        return im
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1 / 6.0, 1 / 6.0, 1 / 6.0)
    mp.inputs["Rotation"].default_value = (0.0, 0.0, math.radians(17.0))
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    mk = nt.nodes.new("ShaderNodeTexImage")
    mk.image = img("T_Paint_Mask.png")
    mk.projection = "BOX"
    mk.projection_blend = 0.3
    nt.links.new(mp.outputs["Vector"], mk.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    sh, mid, hi = stops
    q1 = [0.5 * (a + c) for a, c in zip(sh, mid)]
    q3 = [0.5 * (a + c) for a, c in zip(mid, hi)]
    els[0].position, els[0].color = 0.0, (*sh, 1.0)
    els[1].position, els[1].color = 1.0, (*hi, 1.0)
    for t, c in ((0.25, q1), (0.5, mid), (0.75, q3)):
        e = els.new(t)
        e.color = (*c, 1.0)
    nt.links.new(mk.outputs["Color"], ramp.inputs["Fac"])
    ov = nt.nodes.new("ShaderNodeMix")
    ov.data_type = "RGBA"
    ov.blend_type = "OVERLAY"
    ov.inputs["Factor"].default_value = 0.35
    if base_link is not None:
        nt.links.new(base_link.from_socket, ov.inputs[6])
    else:
        ov.inputs[6].default_value = bsdf.inputs["Base Color"].default_value
    nt.links.new(ramp.outputs["Color"], ov.inputs[7])
    nt.links.new(ov.outputs[2], bsdf.inputs["Base Color"])
    mp2 = nt.nodes.new("ShaderNodeMapping")
    mp2.inputs["Scale"].default_value = (0.5, 0.5, 0.5)
    mp2.inputs["Rotation"].default_value = (0.0, 0.0, math.radians(17.0))
    nt.links.new(tc.outputs["Object"], mp2.inputs["Vector"])
    pn = nt.nodes.new("ShaderNodeTexImage")
    pn.image = img("T_Paint_Normal.png")
    pn.projection = "BOX"
    pn.projection_blend = 0.3
    nt.links.new(mp2.outputs["Vector"], pn.inputs["Vector"])
    bump = nt.nodes.new("ShaderNodeBump")       # box-projected strokes have no tangent frame: use them as relief
    bump.inputs["Strength"].default_value = 0.25
    bump.inputs["Distance"].default_value = 0.02
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(pn.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Red"], bump.inputs["Height"])
    if bsdf.inputs["Normal"].links:
        nt.links.new(bsdf.inputs["Normal"].links[0].from_socket, bump.inputs["Normal"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m


# ------------------------------------------------------------------ render / images
def render_to(sc, path):
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def save_image_rgb(arr, path):
    """arr: (H, W, 3) display values 0..1, row 0 = TOP.  Written through a Blender byte image (no PIL in Blender)."""
    h, w = arr.shape[:2]
    name = "DL_Out_%dx%d" % (w, h)
    im = bpy.data.images.get(name)
    if im is None or tuple(im.size) != (w, h):
        im = bpy.data.images.new(name, w, h, alpha=False)
    px = np.ones((h, w, 4), np.float32)
    px[..., :3] = np.clip(arr[::-1], 0.0, 1.0)
    im.pixels.foreach_set(px.ravel())
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
