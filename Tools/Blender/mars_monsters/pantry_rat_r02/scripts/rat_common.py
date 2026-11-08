"""Pantry Rat R02 - shared helpers (copied from ../pantry_rat_r01/scripts/rat_common.py; R02 palette from the sheet-02 swatches): mesh builder (MB), materials, posing (FK / aim / 2-bone IK), audits.

Patterned after cellar_bat_r01/scripts (MB mesh builder, bat_audit BVH overlap), with the rat's own part tags.
Frame: 1 BU = 1 cm, rat faces +X, up +Z, rat LEFT (*_l) = Blender +Y. Blender (x, y, z) == Unreal (x, -y, z).
"""
import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))

SLOTS = ("Body", "Pink", "Belly", "Wood", "Harness", "EyePatch")
PROP_SLOTS = ("Prop",)

PART = {"torso": 0, "head": 1, "nose": 2, "ear": 3, "eyepatch": 4, "leg_upper": 5, "leg_lower": 6, "foot": 7,
        "tail": 8, "spoon": 9, "cuff": 10, "band": 11, "jaw": 12, "strap": 13}  # R02 adds jaw, strap
PART_NAMES = {v: k for k, v in PART.items()}


def hexcol(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def srgb_to_lin(c):
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


PAL = {
    # R02: Body / Pink / Belly / Wood = median of the sheet-02 palette swatch discs (review/sheet_crops/sheet02_measure.json);
    # Harness / EyePatch / Amber sampled from the sheet drawings (strap, patch, iris) - see PROGRESS.md palette table
    "Body": hexcol("#694B59"), "Pink": hexcol("#EE8082"), "Belly": hexcol("#EDC9AA"), "Wood": hexcol("#A76038"),
    # R4: Harness = median of the sheet strap pixels; EyePatch = near-Body (R2e planner ruling)
    "Harness": hexcol("#9A5B44"), "EyePatch": hexcol("#5A3F4D"), "Amber": hexcol("#FEC534"),
    "rind": hexcol("#D9842B"), "flesh": hexcol("#F2E6C8"),
    "stone": hexcol("#7C7A80"), "stone_d": hexcol("#66646B"), "void": hexcol("#050405"), "plate": hexcol("#0B090A"),
    "floor": hexcol("#3A3633"), "floor2": hexcol("#332F2C"), "crate": hexcol("#8A5A32"), "pack": hexcol("#6B4026"),
    "mush_cap": hexcol("#A0603A"), "mush_stem": hexcol("#E8D9BC"), "bulky": hexcol("#8F9A5A"),
    "chef": hexcol("#D8D2C4"), "route_a": hexcol("#E8E2D0"), "route_b": hexcol("#C9B27A"), "marker": hexcol("#4FB3A6"),
    "ruler_a": hexcol("#EDEDED"), "ruler_b": hexcol("#1A1A1A"), "wall": hexcol("#3E4A52"),
}


def V(*a):
    return Vector(a[0]) if len(a) == 1 else Vector(a)


def nrm(v):
    v = Vector(v)
    return v.normalized() if v.length > 1e-12 else v


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def hrand(seed):
    return (math.sin(seed * 12.9898 + 78.233) * 43758.5453) % 1.0


def norm_w(w, maxinf=4):
    items = sorted(((k, v) for k, v in w.items() if v > 1e-4), key=lambda kv: -kv[1])[:maxinf]
    s = sum(v for _, v in items)
    return {k: v / s for k, v in items} if s > 0 else {"root": 1.0}


def blend_w(*pairs):
    out = {}
    for f, w in pairs:
        for k, v in w.items():
            out[k] = out.get(k, 0.0) + f * v
    return out


def facet_jitter(col, seed, amt=0.06):
    k = 1.0 + (hrand(seed) - 0.5) * 2 * amt
    return tuple(min(1.0, c * k) for c in col)


def mirror_name(n):
    return n[:-2] + "_r" if n.endswith("_l") else n


MATS = {}


class MB:
    """Polygon soup with per-vertex weight dicts, per-face slot / colour / part tag (as the cellar bat's MB)."""

    def __init__(self, name, slots=SLOTS):
        self.name = name
        self.slots = slots
        self.v, self.w, self.f, self.fm, self.fc, self.fp, self.fuv = [], [], [], [], [], [], []

    def vert(self, p, w=None):
        self.v.append(Vector(p))
        self.w.append(norm_w(w) if w else {})
        return len(self.v) - 1

    def face(self, idx, mat, col, part, jitter=0.0, uv=None):
        self.f.append(list(idx))
        self.fm.append(self.slots.index(mat))
        c = facet_jitter(col, len(self.f) * 1.37 + len(self.v) * 0.11, jitter) if jitter else col
        self.fc.append(c)
        self.fp.append(part)
        self.fuv.append(uv)

    def extend(self, other, mirror=False):
        off = len(self.v)
        for p, w in zip(other.v, other.w):
            if mirror:
                p = Vector((p.x, -p.y, p.z))
                w = {mirror_name(k): x for k, x in w.items()}
            self.v.append(Vector(p))
            self.w.append(dict(w))
        for f, m, c, pt, uv in zip(other.f, other.fm, other.fc, other.fp, other.fuv):
            idx = [i + off for i in f]
            if mirror:
                idx = idx[::-1]
                uv = uv[::-1] if uv else None
            self.f.append(idx)
            self.fm.append(m)
            self.fc.append(c)
            self.fp.append(pt)
            self.fuv.append(uv)

    def transform(self, M, start=0):
        for i in range(start, len(self.v)):
            self.v[i] = M @ self.v[i]

    def to_object(self, name, coll, groups=True):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(p) for p in self.v], [], self.f)
        me.update()
        for s in self.slots:
            me.materials.append(MATS[s])
        me.polygons.foreach_set("material_index", self.fm)
        attr = me.attributes.new("part", "INT", "FACE")
        attr.data.foreach_set("value", self.fp)
        col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
        cols = []
        for poly in me.polygons:
            c = self.fc[poly.index]
            cols.extend([c[0], c[1], c[2], 1.0] * poly.loop_total)
        col.data.foreach_set("color_srgb", cols)
        me.color_attributes.active_color = col
        me.color_attributes.render_color_index = 0
        me.shade_flat()
        ob = bpy.data.objects.new(name, me)
        coll.objects.link(ob)
        if groups:
            names = sorted({k for w in self.w for k in w})
            vg = {n: ob.vertex_groups.new(name=n) for n in names}
            for i, w in enumerate(self.w):
                for k, x in w.items():
                    vg[k].add([i], x, "REPLACE")
        return ob


def orient_closed_islands(mb, skip_parts=()):
    """Flip any closed island with negative signed volume (deterministic). Returns flip count."""
    nv = len(mb.v)
    parent = list(range(nv))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for f in mb.f:
        r0 = find(f[0])
        for i in f[1:]:
            ri = find(i)
            if ri != r0:
                parent[ri] = r0
    vol, isl = {}, {}
    for fi, f in enumerate(mb.f):
        if mb.fp[fi] in skip_parts:
            continue
        r = find(f[0])
        p0 = mb.v[f[0]]
        for a, b in zip(f[1:-1], f[2:]):
            vol[r] = vol.get(r, 0.0) + p0.dot(mb.v[a].cross(mb.v[b])) / 6.0
        isl.setdefault(r, []).append(fi)
    flips = 0
    for r, v in vol.items():
        if v < 0:
            flips += 1
            for fi in isl[r]:
                mb.f[fi] = mb.f[fi][::-1]
                if mb.fuv[fi]:
                    mb.fuv[fi] = mb.fuv[fi][::-1]
    return flips


def hull(mb, pts, w, mat, col, part, jitter=0.05, colfn=None):
    """Closed convex solid of the points (outward normals). w: dict or callable(point) -> dict."""
    bm = bmesh.new()
    vs = [bm.verts.new(Vector(p)) for p in pts]
    bmesh.ops.convex_hull(bm, input=vs, use_existing_faces=False)
    for v in [v for v in bm.verts if not v.link_faces]:
        bm.verts.remove(v)
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="FIXED", ngon_method="BEAUTY")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.verts.index_update()
    ids = {}
    for v in bm.verts:
        ids[v.index] = mb.vert(v.co, w(v.co) if callable(w) else w)
    for f in bm.faces:
        m, c = colfn(f.normal, f.calc_center_median()) if colfn else (mat, col)
        mb.face([ids[v.index] for v in f.verts], m, c, part, jitter)
    bm.free()


def ring_frame(axis, ref=None):
    a = nrm(axis)
    ref = Vector(ref) if ref is not None else (Z if abs(a.dot(Z)) < 0.9 else X)
    e1 = nrm(ref - a * ref.dot(a))
    e2 = a.cross(e1)
    return e1, e2


def tube(mb, pts, radii, ws, mat, col, part, sides=6, ref=None, jitter=0.04, flat=1.0, stagger=True, caps=True):
    """Closed faceted tube along a polyline (staggered rings -> triangle facets)."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    loops = []
    e1p = None
    for k in range(n):
        if k == 0:
            d = pts[1] - pts[0]
        elif k == n - 1:
            d = pts[-1] - pts[-2]
        else:
            d = nrm(pts[k + 1] - pts[k]) + nrm(pts[k] - pts[k - 1])
        a = nrm(d)
        if e1p is None:
            e1, e2 = ring_frame(a, ref)
        else:
            e1 = nrm(e1p - a * e1p.dot(a))
            e2 = a.cross(e1)
        e1p = e1
        off = (math.pi / sides) * (k % 2) if stagger else 0.0
        r = radii[k]
        loops.append([mb.vert(pts[k] + (e1 * math.cos(2 * math.pi * j / sides + off) +
                                         e2 * flat * math.sin(2 * math.pi * j / sides + off)) * r, ws[k])
                      for j in range(sides)])
    for k, (a, b) in enumerate(zip(loops, loops[1:])):
        for j in range(sides):
            j1 = (j + 1) % sides
            if not stagger:
                mb.face((a[j], a[j1], b[j1], b[j]), mat, col, part, jitter)
            elif k % 2 == 0:   # b shifted +half: b[j] between a[j], a[j1]
                mb.face((a[j], a[j1], b[j]), mat, col, part, jitter)
                mb.face((b[j], a[j1], b[j1]), mat, col, part, jitter)
            else:              # a shifted +half: a[j] between b[j], b[j1]
                mb.face((a[j], b[j1], b[j]), mat, col, part, jitter)
                mb.face((a[j], a[j1], b[j1]), mat, col, part, jitter)
    if caps:
        c0 = mb.vert(pts[0] - nrm(pts[1] - pts[0]) * radii[0] * 0.45, ws[0])
        for j in range(sides):
            mb.face((loops[0][(j + 1) % sides], loops[0][j], c0), mat, col, part, jitter)
        c1 = mb.vert(pts[-1] + nrm(pts[-1] - pts[-2]) * radii[-1] * 0.45, ws[-1])
        for j in range(sides):
            mb.face((loops[-1][j], loops[-1][(j + 1) % sides], c1), mat, col, part, jitter)
    return loops


def box(mb, c, size, mat, col, part, R=None, jitter=0.0, w=None):
    """Axis box (optionally rotated by 3x3 R) centred at c; 12 triangles."""
    hx, hy, hz = (s * 0.5 for s in size)
    R = R or Matrix.Identity(3)
    corners = [Vector(c) + R @ Vector((sx * hx, sy * hy, sz * hz))
               for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    ids = [mb.vert(p, w) for p in corners]
    quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    for q in quads:
        a, b, cc, d = (ids[i] for i in q)
        mb.face((a, b, cc), mat, col, part, jitter)
        mb.face((a, cc, d), mat, col, part, jitter)


# ---------------------------------------------------------------- materials
def make_material(name, col_srgb, rough=0.8, eye_preview=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    lin = srgb_to_lin(col_srgb)
    m.diffuse_color = (*lin, 1.0)
    m.roughness = rough
    m.metallic = 0.0
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Specular IOR Level"].default_value = 0.25
    if eye_preview:
        # Review-only preview of the EyePlate.ush half mapping: U < 0.5 is the LEFT eye and mirrors U; each half is
        # one eye cell over [0,1]. Draws an amber oval with an outer-top highlight so a wrong half shows as 4 eyes or
        # inward-facing highlights. The Unreal material is MarsEyePlate; this node tree is never exported as logic.
        bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
        tc = nt.nodes.new("ShaderNodeUVMap")
        tc.uv_map = "UV0"
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["UV"], sep.inputs["Vector"])

        def math_node(op, a, b=None, val=None):
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

        u, v = sep.outputs["X"], sep.outputs["Y"]
        u2 = math_node("FRACT", math_node("MULTIPLY", u, 2.0))
        is_left = math_node("LESS_THAN", u, 0.5)
        # ex = is_left ? 1 - u2 : u2  ==  u2 + is_left * (1 - 2 u2)
        ex = math_node("ADD", u2, math_node("MULTIPLY", is_left, math_node("SUBTRACT", 1.0, math_node("MULTIPLY", u2, 2.0))))
        dx = math_node("DIVIDE", math_node("SUBTRACT", ex, 0.5), 0.40)
        dy = math_node("DIVIDE", math_node("SUBTRACT", v, 0.5), 0.40)
        r2 = math_node("ADD", math_node("MULTIPLY", dx, dx), math_node("MULTIPLY", dy, dy))
        oval = math_node("LESS_THAN", r2, 1.0)
        hx = math_node("SUBTRACT", ex, 0.6)
        hy = math_node("SUBTRACT", v, 0.64)
        h2 = math_node("ADD", math_node("MULTIPLY", hx, hx), math_node("MULTIPLY", hy, hy))
        hl = math_node("LESS_THAN", h2, 0.004)
        mask = math_node("ADD", math_node("MULTIPLY", oval, 1.0), math_node("MULTIPLY", hl, 1.5))
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (1.0, 0.45, 0.04, 1.0)
        strength = math_node("MULTIPLY", mask, 1.1)
        nt.links.new(strength, em.inputs["Strength"])
        add = nt.nodes.new("ShaderNodeAddShader")
        nt.links.new(bsdf.outputs["BSDF"], add.inputs[0])
        nt.links.new(em.outputs["Emission"], add.inputs[1])
        nt.links.new(add.outputs["Shader"], out.inputs["Surface"])
    else:
        ca = nt.nodes.new("ShaderNodeVertexColor")
        ca.layer_name = "Col"
        nt.links.new(ca.outputs["Color"], bsdf.inputs["Base Color"])
        nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    m["mars_flat_srgb"] = list(col_srgb)
    return m


# ---------------------------------------------------------------- posing
def inherited(pb):
    """Armature-space matrix the bone would have with an identity pose basis."""
    if pb.parent is None:
        return pb.bone.matrix_local.copy()
    par = pb.parent
    return par.matrix @ (par.bone.matrix_local.inverted() @ pb.bone.matrix_local)


def set_world_rot(pb, q, loc_delta=None):
    """Rotate the bone (and its children) by armature-space quaternion q about its head; optional armature-space
    head translation. Parent must already be posed (view layer updated)."""
    m = inherited(pb)
    qi = m.to_quaternion()
    pb.rotation_quaternion = qi.inverted() @ q @ qi
    if loc_delta is not None:
        pb.location = m.to_3x3().inverted() @ Vector(loc_delta)
    else:
        pb.location = (0, 0, 0)


def aim(pb, target, up_world=None):
    """Point the bone's Y axis at target (armature space), minimal twist; optional up hint for the bone Z axis."""
    m = inherited(pb)
    head = m.translation
    d_cur = (m.to_3x3() @ Vector((0, 1, 0))).normalized()
    d_new = (Vector(target) - head).normalized()
    rw = d_cur.rotation_difference(d_new)
    if up_world is not None:
        zc = rw @ (m.to_3x3() @ Vector((0, 0, 1)))
        zc = (zc - d_new * zc.dot(d_new))
        zt = Vector(up_world) - d_new * Vector(up_world).dot(d_new)
        if zc.length > 1e-6 and zt.length > 1e-6:
            zc.normalize()
            zt.normalize()
            ang = math.atan2(zc.cross(zt).dot(d_new), zc.dot(zt))
            rw = Quaternion(d_new, ang) @ rw
    qi = m.to_quaternion()
    pb.rotation_quaternion = qi.inverted() @ rw @ qi
    pb.location = (0, 0, 0)


def ik2(hip, ankle, l1, l2, pole):
    hip, ankle, pole = Vector(hip), Vector(ankle), Vector(pole)
    dv = ankle - hip
    d = min(dv.length, (l1 + l2) * 0.999)
    d = max(d, abs(l1 - l2) * 1.001 + 1e-3)
    u = dv.normalized()
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(0.0, l1 * l1 - a * a))
    p = pole - u * pole.dot(u)
    p = p.normalized() if p.length > 1e-6 else ring_frame(u)[0]
    knee = hip + u * a + p * h
    return knee, hip + u * d


def bone_delta(arm, name):
    pb = arm.pose.bones[name]
    return pb.matrix @ pb.bone.matrix_local.inverted()


# ---------------------------------------------------------------- audits
def evaluated_tris(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    me.calc_loop_triangles()
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    mw = np.array(obj.matrix_world)
    co = co @ mw[:3, :3].T + mw[:3, 3]
    if "part" in me.attributes:
        parts = np.empty(len(me.polygons), dtype=np.int64)
        me.attributes["part"].data.foreach_get("value", parts)
    else:
        parts = np.zeros(len(me.polygons), dtype=np.int64)
    tris = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
    me.loop_triangles.foreach_get("vertices", tris)
    tpoly = np.empty(len(me.loop_triangles), dtype=np.int64)
    me.loop_triangles.foreach_get("polygon_index", tpoly)
    ev.to_mesh_clear()
    return co, tris.reshape(-1, 3), parts[tpoly]


class Soup:
    """World-space triangle soup of one or more objects with part tags; groups -> BVH trees."""

    def __init__(self, co, tris, tp):
        self.co, self.tris, self.tp = co, tris, tp
        self.verts = [Vector(c) for c in co]
        self._trees = {}

    def mask(self, parts):
        return np.isin(self.tp, list(parts))

    def tree(self, key, parts):
        if key not in self._trees:
            idx = np.nonzero(self.mask(parts))[0]
            if len(idx) == 0:
                self._trees[key] = (None, idx)
            else:
                self._trees[key] = (BVHTree.FromPolygons(self.verts, [tuple(self.tris[i]) for i in idx],
                                                         all_triangles=True, epsilon=0.0), idx)
        return self._trees[key]

    def vert_ids(self, parts):
        return np.unique(self.tris[self.mask(parts)].ravel())


def overlap_count(ta, tb):
    if ta is None or tb is None:
        return 0
    return len(ta.overlap(tb))


def signed_clearance(points, tree):
    """Min signed distance of points to the tree's surface (negative = inside, by nearest-face normal)."""
    if tree is None or len(points) == 0:
        return None
    best = 1e9
    for p in points:
        p = Vector(p)
        loc, n, _, dist = tree.find_nearest(p)
        if loc is None:
            continue
        s = dist if (p - loc).dot(n) >= 0 else -dist
        best = min(best, s)
    return best


def min_distance_to(points, tree):
    """Unsigned min distance (penetration is reported separately by the triangle-overlap count)."""
    best = 1e9
    for p in points:
        loc, n, _, dist = tree.find_nearest(Vector(p))
        if loc is not None:
            best = min(best, dist)
    return best


def max_distance_to(points, tree):
    best = 0.0
    for p in points:
        loc, n, _, dist = tree.find_nearest(Vector(p))
        if loc is not None:
            best = max(best, dist)
    return best


def tree_from_world(objs):
    vs, fs = [], []
    for ob in objs:
        co, tris, _ = evaluated_tris(ob)
        off = len(vs)
        vs.extend(Vector(c) for c in co)
        fs.extend(tuple(int(i) + off for i in t) for t in tris)
    if not fs:
        return None, []
    return BVHTree.FromPolygons(vs, fs, all_triangles=True, epsilon=0.0), vs


# ---------------------------------------------------------------- 2D convex geometry (death-drop gap)
def hull2d(pts):
    pts = sorted(set((round(float(p[0]), 4), round(float(p[1]), 4)) for p in pts))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lo, hi = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(hi) >= 2 and cross(hi[-2], hi[-1], p) <= 0:
            hi.pop()
        hi.append(p)
    return lo[:-1] + hi[:-1]


def _seg_dist(p, a, b):
    ax, ay = b[0] - a[0], b[1] - a[1]
    t = ((p[0] - a[0]) * ax + (p[1] - a[1]) * ay) / max(ax * ax + ay * ay, 1e-12)
    t = max(0.0, min(1.0, t))
    return math.hypot(p[0] - a[0] - ax * t, p[1] - a[1] - ay * t)


def _inside(p, poly):
    n = len(poly)
    sgn = 0
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        c = (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
        if c != 0:
            s = 1 if c > 0 else -1
            if sgn == 0:
                sgn = s
            elif s != sgn:
                return False
    return True


def poly_gap(pa, pb):
    """Min distance between two convex polygons; 0 if they overlap."""
    if any(_inside(p, pb) for p in pa) or any(_inside(p, pa) for p in pb):
        return 0.0
    best = 1e9
    for P, Q in ((pa, pb), (pb, pa)):
        for p in P:
            for i in range(len(Q)):
                best = min(best, _seg_dist(p, Q[i], Q[(i + 1) % len(Q)]))
    return best
