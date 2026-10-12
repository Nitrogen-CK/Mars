"""Mars crawler pieces: the rigid parts the Room 5 spider crawler wears (UMars_Crawler_EntityScript's look) and the
measured layout of its rig, cut from the low-poly spider at SOURCE_FBX, as a re-runnable headless Blender 5.2 build.

The source is one mesh in twelve islands: the head (cephalothorax with two fangs and two pedipalps fused on), the
abdomen, four eyes and six legs (each leg one island: a thin coxa/femur rising to a raised knee, then a thick tibia that
drops to a pointed claw). The spider faces -Y, Z up, metres, standing on z = 0.

The model keeps its own proportions: everything is scaled UNIFORMLY by one factor, the one that makes the body (head +
abdomen) BODY_LENGTH_CM long, and the rig is measured from the model, never the model stretched to a rig. Per leg the
build measures the hip (the root of the coxa, under the head), the knee (the middle of the cross section where the thin
femur meets the thick tibia) and the claw tip, in the body's frame (Unreal cm: +X forward, +Y right, +Z up, the origin at
the body's bounds centre). The body's centre stands `clearance` above the ground the claws rest on; that height becomes
the crawler's surface clearance, and each rest foot is its claw tip dropped onto that ground. The build prints the
numbers Script/ECS/Crawler/Mars_Crawler_Assets.as carries (Mars_SpiderRig6) as SPIDER_RIG {...}.

Pieces (Blender metres at the origin, Unreal cm after the FBX import, Unreal local = (x, -y, z)):

  Crawler_Body_Mars_SM            head minus fangs and pedipalps (the rig has neither), plus the abdomen and the four
                                  eyes; front along +X, centred on its bounds (the body hurtbox is that box, centred).
  Crawler_LegUpper<Pair>_Mars_SM  the right <Pair> leg's thin part, hip to the knee cut. Pair: Front, Mid, Back.
  Crawler_LegLower<Pair>_Mars_SM  the same leg's thick part from the knee cut to the claw tip.
  Crawler_Foot_Mars_SM            a copy of the mid claw's last FOOT_FRACTION, shrunk by FOOT_SHRINK so it nests inside
                                  the lower segment's tip, point down (-Z), centred (the foot part's rotation is the
                                  gait's, not the leg's, so only a part pointing down reads the same on every leg).
  Crawler_Fang_Mars_SM            the right fang, its pivot at its ROOT, root to tip along +X, its front face +Z.

A segment piece's pivot is the midpoint of its two joints and its +X runs from the hip end to the foot end, the rig's
convention (CkProceduralAnimation: a segment's transform is the joint midpoint, +X hip to foot, +Y toward the leg's
pole); its +Y (Unreal) is the knee's convex side. The joint-to-joint span is the rig's segment length, so the joints
meet; the knuckles reach past them. A left leg wears its right twin's pieces (the leg is near-symmetric about its own
plane): nothing is mirrored.

One material slot, "Crawler" (Unreal binds Crawler_Mars_MI by the Send to Unreal slot pattern), UV0 the source atlas
(the eyes are in it). Cut caps take their UVs from the surface they close. Smooth shading with edges sharper than
SHARP_DEG split.

Run:
  blender -b --factory-startup --python build_crawler_pieces.py -- [--export] [--sheets] [--save] [--debug]
    --export   one FBX per piece + a .json sidecar (bounds, half extents) into EXPORT_DIR, then a re-import check
    --sheets   review renders into REVIEW_DIR: every piece, and the pieces posed on the measured rig at rest
    --save     BLEND_FILE (the pieces at the origin + the posed preview)
    --debug    renders of the cut classification (head appendages, the knee planes) into REVIEW_DIR
Prints CRAWLER_PIECES_OK when every check passed (CRAWLER_PIECES_FAIL + the reasons otherwise).
"""
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

# ---------------------------------------------------------------- locations
SOURCE_DIR = r"D:\Repo\Content\Monsters\Crawler"            # off-repo source art, like D:\Repo\Content\Cooking
SOURCE_FBX = SOURCE_DIR + r"\source\spider+3d+model.fbx"     # the downloaded spider (texture in the sibling .fbm)
EXPORT_DIR = SOURCE_DIR + r"\export"
REVIEW_DIR = EXPORT_DIR + r"\review"
BLEND_FILE = SOURCE_DIR + r"\Crawler_Pieces.blend"
UE_MESH_FOLDER = "/Game/Mars/Gameplay/Monsters/Crawler/Meshes"

# ---------------------------------------------------------------- scale and rig
BODY_LENGTH_CM = 198.0                          # head + abdomen, nose to tail: the one number the scale is chosen by (1.8x the
                                                # first 110 cm cut, 2026-10-12)
TARGET_REACH_FRACTION = 0.8                     # Mars_CrawlerGait: a rest foot must lie this share of the reach from its hip
LEG_PAIRS = ("Front", "Mid", "Back")
# the fang pose at rest (Mars_Crawler_EntityScript FangRest*), for the preview only
FANG_REST_SPREAD, FANG_REST_DROOP = 10.0, 62.0

# ---------------------------------------------------------------- the cut (source metres)
SPIDER_CENTRE = np.array([0.0, -0.1])           # roughly where the legs radiate from, seen from above
FANG_TOP_Z = 0.25                               # a fang is what hangs below this, beside the mouth, in front
FANG_X = (0.036, 0.11)                          # |x| band the fangs hang in (the mouth's small teeth lie inside it)
FANG_FRONT_Y = -0.36
PALP_OUTER_X = 0.165                            # a pedipalp is anything this far out from the head's centreline ...
PALP_LOW_Z, PALP_LOW_X = 0.125, 0.05            # ... or under the head's floor, off the centreline
PALP_FRONT_Y = -0.15
PALP_ROOT = (0.11, -0.22, 0.11)                 # the pedipalp's ball joint under the head (|x|, y, z)
PALP_ROOT_CLEAR = 0.02                          # the arm is cut this far out from its ball joint, across the arm (closer leaks into the head)
KNEE_R = 0.30                                   # where the thin femur meets the thick tibia, along each leg's radial
KNEE_BAND = 0.015
FOOT_FRACTION = 0.22                            # the claw's last share of the lower segment's length
FOOT_SHRINK = 0.8
SHARP_DEG = 35.0
OPEN_EDGES_MAX = 2                              # the source's fang root carries one sliver edge no fill closes (2 mm, hidden
                                                # under the head); anything more is a cap that failed
SLOT = "Crawler"
TRIS_MAX = {"Body": 6000, "LegUpper": 800, "LegLower": 1200, "Foot": 400, "Fang": 600}

PIECES = ("Body",) + tuple("Leg%s%s" % (seg, pair) for pair in LEG_PAIRS for seg in ("Upper", "Lower")) + ("Foot", "Fang")


def tris_max(part):
    return TRIS_MAX[next(k for k in TRIS_MAX if part.startswith(k))]


def piece_name(part):
    return "Crawler_%s_Mars_SM" % part


# ---------------------------------------------------------------- CLI / scene
def cli_args(defaults):
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = dict(defaults)
    for a in argv:
        out[a.lstrip("-")] = True
    return out


def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.cameras):
        for d in list(coll):
            if d.users == 0:
                coll.remove(d)


def _n(v):
    v = np.asarray(v, float)
    return v / max(float(np.linalg.norm(v)), 1e-12)


# ---------------------------------------------------------------- source
def import_source():
    """The spider as one bmesh in source metres (its object transform applied), the source image, and its UV layer."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=SOURCE_FBX)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    if len(meshes) != 1:
        raise RuntimeError("expected one mesh in %s, got %d" % (SOURCE_FBX, len(meshes)))
    src = meshes[0]
    image = None
    for m in src.data.materials:
        if m is not None and m.node_tree is not None:
            for node in m.node_tree.nodes:
                if node.type == "TEX_IMAGE" and node.image is not None:
                    image = node.image
    bm = bmesh.new()
    bm.from_mesh(src.data)
    bmesh.ops.transform(bm, matrix=src.matrix_world, verts=bm.verts[:])
    for o in new:
        data = o.data if o.type == "MESH" else None
        bpy.data.objects.remove(o, do_unlink=True)
        if data is not None and data.users == 0:
            bpy.data.meshes.remove(data)
    if image is None:
        raise RuntimeError("the source has no base colour image")
    return bm, image


def islands(bm):
    """Face islands (connected through shared vertices), largest first: lists of face indices."""
    bm.faces.ensure_lookup_table()
    seen = set()
    out = []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, island = [f], []
        seen.add(f.index)
        while stack:
            x = stack.pop()
            island.append(x.index)
            for v in x.verts:
                for g in v.link_faces:
                    if g.index not in seen:
                        seen.add(g.index)
                        stack.append(g)
        out.append(island)
    return sorted(out, key=len, reverse=True)


def face_centres(bm):
    bm.faces.ensure_lookup_table()
    return np.array([f.calc_center_median()[:] for f in bm.faces])


def grow(bm, seeds, allowed):
    """Faces reachable from the seed faces through shared edges, staying on faces allowed[i]."""
    bm.faces.ensure_lookup_table()
    out = set(i for i in seeds if allowed[i])
    stack = list(out)
    while stack:
        f = bm.faces[stack.pop()]
        for e in f.edges:
            for g in e.link_faces:
                if g.index not in out and allowed[g.index]:
                    out.add(g.index)
                    stack.append(g.index)
    return out


def close(bm, faces, allowed, passes=3):
    """faces plus the allowed faces that sit mostly inside them (two or more edge neighbours in the set): a face whose
    centre fell just outside a classification rule would otherwise stay behind as a speck on one piece and a hole in
    the other."""
    bm.faces.ensure_lookup_table()
    out = set(faces)
    for _ in range(passes):
        add = set()
        for i in out:
            for e in bm.faces[i].edges:
                for g in e.link_faces:
                    if g.index in out or g.index in add or not allowed[g.index]:
                        continue
                    inside = sum(1 for ge in g.edges for h in ge.link_faces if h is not g and h.index in out)
                    if inside >= 2:
                        add.add(g.index)
        if not add:
            break
        out |= add
    return out


def drop_specks(bm, min_faces=20):
    """Delete face islands smaller than min_faces (fragments a cut left behind)."""
    bm.faces.ensure_lookup_table()
    small = [i for i in islands(bm) if len(i) < min_faces]
    bm.faces.ensure_lookup_table()
    doomed = [bm.faces[i] for isl in small for i in isl]
    if doomed:
        bmesh.ops.delete(bm, geom=doomed, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    return len(small)


def extract(bm, faces):
    """A new bmesh holding only `faces` of bm (UVs and every layer kept)."""
    keep = set(faces)
    out = bm.copy()
    out.faces.ensure_lookup_table()
    bmesh.ops.delete(out, geom=[f for f in out.faces if f.index not in keep], context="FACES")
    bmesh.ops.delete(out, geom=[v for v in out.verts if not v.link_faces], context="VERTS")
    return out


def cap_holes(bm):
    """Close every open boundary with n-gon caps (triangulated); a cap corner takes the UV of the surface it closes."""
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=2e-4)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges[:])
    bmesh.ops.delete(bm, geom=[e for e in bm.edges if not e.link_faces], context="EDGES")
    uv = bm.loops.layers.uv.active
    border_uv = {}
    for e in bm.edges:
        if e.is_boundary:
            for v in e.verts:
                for lp in v.link_loops:
                    border_uv.setdefault(v.index, lp[uv].uv.copy())
    boundary = [e for e in bm.edges if e.is_boundary]
    if not boundary:
        return 0
    before = set(bm.faces)
    bmesh.ops.holes_fill(bm, edges=boundary, sides=0)
    left = [e for e in bm.edges if e.is_boundary]
    if left:                                            # a boundary through a shared corner holes_fill cannot walk
        bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=False, edges=left)
    caps = [f for f in bm.faces if f not in before]
    for loop in boundary_loops(bm):                     # what both left: tiny holes through a shared corner
        try:
            bm.faces.new(loop)
        except ValueError:
            pass
    if caps:
        res = bmesh.ops.triangulate(bm, faces=caps, quad_method="BEAUTY", ngon_method="BEAUTY")
        caps = res["faces"]
    bm.verts.index_update()
    for f in caps:
        for lp in f.loops:
            got = border_uv.get(lp.vert.index)
            if got is None:
                for g in lp.vert.link_loops:
                    if g.face not in caps:
                        got = g[uv].uv.copy()
                        break
            if got is not None:
                lp[uv].uv = got
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return len(caps)


def boundary_loops(bm):
    """The open boundaries as vertex rings, walked edge by edge (a corner shared by two rings is left to either)."""
    edges = {e for e in bm.edges if e.is_boundary}
    loops = []
    while edges:
        e = edges.pop()
        ring = [e.verts[0], e.verts[1]]
        while True:
            nxt = next((x for x in ring[-1].link_edges if x in edges), None)
            if nxt is None:
                break
            edges.discard(nxt)
            v = nxt.other_vert(ring[-1])
            if v is ring[0]:
                break
            ring.append(v)
        if len(ring) >= 3:
            loops.append(ring)
    return loops


def cut(bm, plane_co, plane_no, keep_positive):
    """bm cut by a plane, keeping the side the normal points to (or the other), capped."""
    out = bm.copy()
    geom = out.verts[:] + out.edges[:] + out.faces[:]
    bmesh.ops.bisect_plane(out, geom=geom, dist=1e-6, plane_co=Vector(plane_co), plane_no=Vector(plane_no),
                           clear_inner=keep_positive, clear_outer=not keep_positive)
    bmesh.ops.delete(out, geom=[v for v in out.verts if not v.link_faces], context="VERTS")
    cap_holes(out)
    return out


def verts_of(bm):
    return np.array([v.co[:] for v in bm.verts])


# ---------------------------------------------------------------- classification
def classify(bm):
    """{name: face-index list} for the head's parts, the abdomen, the eyes and the six legs."""
    isl = islands(bm)
    if len(isl) != 12:
        raise RuntimeError("expected 12 islands in the spider, got %d" % len(isl))
    centres = face_centres(bm)
    head, abdomen = isl[0], isl[1]
    rest = isl[2:]
    legs = [i for i in rest if len(i) > 200]
    eyes = [i for i in rest if len(i) <= 200]
    if len(legs) != 6 or len(eyes) != 4:
        raise RuntimeError("expected 6 legs and 4 eyes, got %d and %d" % (len(legs), len(eyes)))
    if centres[abdomen][:, 1].mean() < centres[head][:, 1].mean():
        raise RuntimeError("the abdomen should lie behind (+Y of) the head")
    head_set = np.zeros(len(bm.faces), bool)
    head_set[head] = True
    bm.verts.ensure_lookup_table()
    vco = verts_of(bm)
    head_verts = sorted({v.index for i in head for v in bm.faces[i].verts})
    hv = vco[head_verts]
    out = {"abdomen": abdomen, "eyes": [f for e in eyes for f in e], "legs": legs}
    taken = set()
    for side, key in ((-1.0, "R"), (1.0, "L")):              # the spider's right is -X (it faces -Y)
        sx = side * centres[:, 0]
        # fang: hangs below FANG_TOP_Z in the |x| band, in front
        allowed = head_set & (centres[:, 2] < FANG_TOP_Z) & (sx > FANG_X[0]) & (sx < FANG_X[1]) & (centres[:, 1] < FANG_FRONT_Y)
        m = (side * hv[:, 0] > FANG_X[0]) & (side * hv[:, 0] < FANG_X[1]) & (hv[:, 1] < FANG_FRONT_Y)
        tip = head_verts[int(np.flatnonzero(m)[np.argmin(hv[m, 2])])]
        seeds = [f.index for f in bm.verts[tip].link_faces]
        out["fang_" + key] = sorted(grow(bm, seeds, allowed))
        # pedipalp: its forearm is what lies out past the head's side (or under its floor) in front of the middle; its
        # upper arm runs back under the head to a ball joint, and is whatever lies beyond a plane just outside that
        # joint, across the arm, still connected to the forearm
        allowed = head_set & (centres[:, 1] < PALP_FRONT_Y) & ((sx > PALP_OUTER_X) | ((centres[:, 2] < PALP_LOW_Z) & (sx > PALP_LOW_X)))
        m = side * hv[:, 0] > 0.2
        tip = head_verts[int(np.flatnonzero(m)[np.argmin(hv[m, 2])])]
        seeds = [f.index for f in bm.verts[tip].link_faces]
        forearm = sorted(grow(bm, seeds, allowed))
        root = np.array([side * PALP_ROOT[0], PALP_ROOT[1], PALP_ROOT[2]])
        elbow = centres[forearm][np.argmin(np.linalg.norm(centres[forearm] - root, axis=1))]
        arm = _n(elbow - root)
        allowed = head_set & ((centres - (root + arm * PALP_ROOT_CLEAR)) @ arm > 0.0) & (sx > PALP_LOW_X) & (centres[:, 1] < -0.12)
        out["palp_" + key] = sorted(close(bm, grow(bm, forearm, allowed), head_set))
        out["fang_" + key] = sorted(close(bm, out["fang_" + key], head_set))
        taken |= set(out["fang_" + key]) | set(out["palp_" + key])
    out["head"] = [i for i in head if i not in taken]
    return out


def leg_axes(bm, faces):
    """Hip root, knee and claw tip of one leg island (source metres), and its radial direction seen from above."""
    bm.faces.ensure_lookup_table()
    idx = sorted({v.index for i in faces for v in bm.faces[i].verts})
    bm.verts.ensure_lookup_table()
    co = np.array([bm.verts[i].co[:] for i in idx])
    zmin = co[:, 2].min()
    tip = co[co[:, 2] < zmin + 0.005].mean(axis=0)
    d = _n(tip[:2] - SPIDER_CENTRE)
    r = (co[:, :2] - SPIDER_CENTRE) @ d
    root = co[r < r.min() + 0.02].mean(axis=0)
    knee = co[np.abs(r - KNEE_R) < KNEE_BAND].mean(axis=0)
    return root, knee, tip, d


def right_legs(bm, legs):
    """The spider's right legs (-X) by pair, front to back: {pair: face list}."""
    right = []
    for faces in legs:
        root, knee, tip, d = leg_axes(bm, faces)
        if tip[0] < 0.0:
            right.append((tip[1], faces))                 # front is -Y
    if len(right) != 3:
        raise RuntimeError("expected 3 right legs, got %d" % len(right))
    right.sort(key=lambda t: t[0])
    return {pair: faces for pair, (_, faces) in zip(LEG_PAIRS, right)}


# ---------------------------------------------------------------- frames
def frame_points(bm, centre, ex, ey, scale_xyz):
    """Re-express bm in the frame (ex, ey, ex x ey) about centre, scaled per axis (to cm)."""
    ex, ey = _n(ex), _n(ey)
    ez = np.cross(ex, ey)
    rot = np.array([ex, ey, ez])                       # rows: world -> local
    for v in bm.verts:
        p = rot @ (np.array(v.co[:]) - centre)
        v.co = Vector((p * np.asarray(scale_xyz, float)).tolist())


def centre_bounds(bm):
    co = verts_of(bm)
    c = 0.5 * (co.min(axis=0) + co.max(axis=0))
    for v in bm.verts:
        v.co = Vector((np.array(v.co[:]) - c).tolist())


def convex_side(root, knee, tip):
    """The knee's offset from the root-to-tip line: the side the leg bends toward (its pole side)."""
    e = _n(tip - root)
    w = (knee - root) - np.dot(knee - root, e) * e
    return _n(w)


def perp(v, axis):
    return _n(v - np.dot(v, axis) * axis)


# ---------------------------------------------------------------- pieces
class Frame:
    """Source metres -> the body's frame in Unreal cm (+X forward = source -Y, +Y right = source -X, +Z up), about the
    body's bounds centre, scaled by `scale` (cm per source metre)."""

    def __init__(self, centre, scale):
        self.centre = np.asarray(centre, float)
        self.scale = float(scale)

    def ue(self, p):
        q = (np.asarray(p, float) - self.centre) * self.scale
        return np.array([-q[1], -q[0], q[2]])


def build_pieces(bm, parts, debug=False):
    """(pieces {part: bmesh in cm}, rig {...} in the body's Unreal frame)."""
    pieces = {}
    # body: head (minus fangs and pedipalps) + abdomen + eyes; the scale is set by its length
    body = extract(bm, parts["head"] + parts["abdomen"] + parts["eyes"])
    specks = drop_specks(body)
    caps = cap_holes(body)
    co = verts_of(body)
    lo, hi = co.min(axis=0), co.max(axis=0)
    centre = 0.5 * (lo + hi)
    scale = BODY_LENGTH_CM / float(hi[1] - lo[1])
    frame = Frame(centre, scale)
    clearance = float(centre[2] * scale)            # the body centre over the ground the claws stand on (z = 0)
    frame_points(body, centre, (0.0, -1.0, 0.0), (1.0, 0.0, 0.0), (scale, scale, scale))
    pieces["Body"] = body
    print("body: %d specks dropped, %d caps; scale %.2f cm per source m, clearance %.2f cm" % (specks, caps, scale, clearance))

    rig = {"scale": round(scale, 3), "clearance": round(clearance, 2), "legs": {}}
    legs = right_legs(bm, parts["legs"])
    mid_lower = None
    for pair in LEG_PAIRS:
        faces = legs[pair]
        leg = extract(bm, faces)
        root, knee, tip, _ = leg_axes(bm, faces)
        up_axis, low_axis = _n(knee - root), _n(tip - knee)
        knee_no = _n(up_axis + low_axis)
        pole_side = convex_side(root, knee, tip)
        upper = cut(leg, knee, knee_no, keep_positive=False)
        lower = cut(leg, knee, knee_no, keep_positive=True)
        if debug:
            debug_leg(leg, knee, knee_no, pair)
        if pair == "Mid":
            mid_lower = (lower.copy(), tip, low_axis, pole_side)
        # segment frame: pivot at the joint midpoint, +X hip to foot, +Y (Unreal) toward the pole = -Y in Blender
        frame_points(upper, 0.5 * (root + knee), up_axis, -perp(pole_side, up_axis), (scale, scale, scale))
        frame_points(lower, 0.5 * (knee + tip), low_axis, -perp(pole_side, low_axis), (scale, scale, scale))
        pieces["LegUpper" + pair] = upper
        pieces["LegLower" + pair] = lower
        hip, knee_ue, tip_ue = frame.ue(root), frame.ue(knee), frame.ue(tip)
        foot = np.array([tip_ue[0], tip_ue[1], -clearance])
        # the pole: as far past the measured knee as the knee stands off the hip-to-foot midpoint (outward and up), so
        # the rig's knee bends in the model's leg plane
        pole = knee_ue + (knee_ue - 0.5 * (hip + foot))
        rig["legs"][pair] = {"hip": [round(float(x), 2) for x in hip], "knee": [round(float(x), 2) for x in knee_ue],
                             "foot": [round(float(x), 2) for x in foot], "pole": [round(float(x), 2) for x in pole],
                             "upper": round(float(np.linalg.norm(knee - root) * scale), 2),
                             "lower": round(float(np.linalg.norm(tip - knee) * scale), 2)}
        print("leg %-5s hip %s knee %s foot %s  upper %.2f lower %.2f cm" % (
            pair, np.round(hip, 1), np.round(knee_ue, 1), np.round(foot, 1), rig["legs"][pair]["upper"], rig["legs"][pair]["lower"]))

    # foot: the mid claw's tip, point down (-Z), shrunk to nest in the lower segment's tip
    lower, tip, low_axis, pole_side = mid_lower
    lower_len = float(np.max(verts_of(lower) @ low_axis) - np.min(verts_of(lower) @ low_axis))
    foot = cut(lower, tip - low_axis * lower_len * FOOT_FRACTION, low_axis, keep_positive=True)
    lower.free()
    fx = perp(pole_side, low_axis)
    frame_points(foot, tip, fx, np.cross(-low_axis, fx), (scale * FOOT_SHRINK,) * 3)
    centre_bounds(foot)
    pieces["Foot"] = foot

    # fang: the right one, pivot at its root, root to tip along +X, its front face (-Y) up (+Z)
    fang = extract(bm, parts["fang_R"])
    border = [v for v in fang.verts if any(e.is_boundary for e in v.link_edges)]
    fco = verts_of(fang)
    fang_tip = fco[np.argmin(fco[:, 2])]
    fang_root = np.array([v.co[:] for v in border]).mean(axis=0) if border else fco[np.argmax(fco[:, 2])]
    cap_holes(fang)
    fx = _n(fang_tip - fang_root)
    fz = perp(np.array([0.0, -1.0, 0.0]), fx)
    frame_points(fang, fang_root, fx, np.cross(fz, fx), (scale, scale, scale))
    pieces["Fang"] = fang
    rig["fang_root"] = [round(float(x), 2) for x in frame.ue(fang_root)]
    rig["fang_length"] = round(float(np.linalg.norm(fang_tip - fang_root) * scale), 2)
    print("fang: root %s length %.2f cm" % (rig["fang_root"], rig["fang_length"]))
    return pieces, rig


# ---------------------------------------------------------------- objects
def material(image):
    mat = bpy.data.materials.get(SLOT) or bpy.data.materials.new(SLOT)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None) or nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    if bsdf is not None:
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def to_object(name, bm, mat):
    """A mesh object at the origin (cm geometry -> metres), one slot, UV0 named UVMap, smooth with sharp edges."""
    for v in bm.verts:
        v.co = v.co * 0.01
    bm.normal_update()
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for attr in [a.name for a in mesh.attributes if a.name in ("custom_normal", "sharp_face", "sharp_edge")]:
        mesh.attributes.remove(mesh.attributes[attr])
    if mesh.uv_layers:
        mesh.uv_layers[0].name = "UVMap"
        while len(mesh.uv_layers) > 1:
            mesh.uv_layers.remove(mesh.uv_layers[1])
    mesh.materials.clear()
    mesh.materials.append(mat)
    mesh.polygons.foreach_set("material_index", [0] * len(mesh.polygons))
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    bm2 = bmesh.new()
    bm2.from_mesh(mesh)
    sharp = []
    for e in bm2.edges:
        sharp.append(len(e.link_faces) != 2 or e.calc_face_angle(0.0) > math.radians(SHARP_DEG))
    bm2.free()
    attr = mesh.attributes.new("sharp_edge", "BOOLEAN", "EDGE")
    attr.data.foreach_set("value", sharp)
    mesh.validate(verbose=False)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def bounds_cm(obj):
    n = len(obj.data.vertices)
    co = np.empty(n * 3)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(n, 3) * 100.0
    return co.min(axis=0), co.max(axis=0)


def tri_count(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def open_edges(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    n = sum(1 for e in bm.edges if e.is_boundary)
    bm.free()
    return n


def ue_half_extents(obj):
    lo, hi = bounds_cm(obj)
    return [round(float(x), 3) for x in (hi - lo) * 0.5]


# ---------------------------------------------------------------- export
def export_fbx(obj):
    os.makedirs(EXPORT_DIR, exist_ok=True)
    path = os.path.join(EXPORT_DIR, obj.name + ".fbx")
    with bpy.context.temp_override(selected_objects=[obj], active_object=obj, object=obj):
        bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, mesh_smooth_type="EDGE",
                                 use_mesh_modifiers=True, add_leaf_bones=False, bake_anim=False, use_tspace=False,
                                 apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y",
                                 use_triangles=True, path_mode="STRIP")
    lo, hi = bounds_cm(obj)
    meta = {"name": obj.name, "builder": "Tools/Blender/mars_monsters/build_crawler_pieces.py",
            "source": SOURCE_FBX.replace("\\", "/"), "ue_folder": UE_MESH_FOLDER, "slots": [SLOT],
            "tris": tri_count(obj), "bounds_min_cm_ue": [round(float(lo[0]), 3), round(float(-hi[1]), 3), round(float(lo[2]), 3)],
            "bounds_max_cm_ue": [round(float(hi[0]), 3), round(float(-lo[1]), 3), round(float(hi[2]), 3)],
            "half_extents_cm": ue_half_extents(obj)}
    with open(os.path.splitext(path)[0] + ".json", "w") as fh:
        json.dump(meta, fh, indent=1)
    print("exported %-26s tris %5d  half extents %s" % (obj.name, meta["tris"], meta["half_extents_cm"]))
    return path


def reimport_check(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    rep = []
    for o in new:
        if o.type == "MESH":
            o.data.transform(o.matrix_world)
            lo, hi = bounds_cm(o)
            rep.append({"name": o.name, "tris": tri_count(o), "uv": [u.name for u in o.data.uv_layers],
                        "slots": [m.name if m else None for m in o.data.materials],
                        "size_cm": [round(float(x), 2) for x in hi - lo]})
    for o in new:
        data = o.data if o.type == "MESH" else None
        bpy.data.objects.remove(o, do_unlink=True)
        if data is not None and data.users == 0:
            bpy.data.meshes.remove(data)
    return rep


# ---------------------------------------------------------------- the measured rig at rest (Unreal cm -> Blender m)
MIRROR = np.diag([1.0, -1.0, 1.0])


def ue_matrix(rot_cols, loc_cm):
    """A Blender world matrix for a part Unreal places with rotation columns (X, Y, Z) at loc (Unreal cm)."""
    r = MIRROR @ np.column_stack(rot_cols) @ MIRROR
    t = MIRROR @ np.asarray(loc_cm, float) * 0.01
    m = Matrix.Identity(4)
    for i in range(3):
        for j in range(3):
            m[i][j] = r[i, j]
        m[i][3] = t[i]
    return m


def make_from_xy(x, y):
    x = _n(x)
    z = _n(np.cross(x, y))
    y = np.cross(z, x)
    return x, y, z


def rig_legs(rig):
    """The six legs in rig order (front right, mid right, back right, back left, mid left, front left): (pair, hip,
    foot, pole, upper, lower), the left ones mirrored."""
    out = []
    order = [(p, 1.0) for p in LEG_PAIRS] + [(p, -1.0) for p in reversed(LEG_PAIRS)]
    for pair, side in order:
        leg = rig["legs"][pair]
        m = np.array([1.0, side, 1.0])
        hip, foot, pole = np.array(leg["hip"]) * m, np.array(leg["foot"]) * m, np.array(leg["pole"]) * m
        out.append((pair, hip, foot, pole, leg["upper"], leg["lower"]))
    return out


def two_bone_knee(hip, foot, pole, upper, lower):
    d = foot - hip
    dl = float(np.linalg.norm(d))
    e = d / dl
    along = (upper ** 2 - lower ** 2 + dl ** 2) / (2.0 * dl)
    h = math.sqrt(max(0.0, upper ** 2 - along ** 2))
    return hip + e * along + perp(pole - hip, e) * h


def pose_preview(objs, rig):
    """Copies of the pieces on the measured rig at rest (the body's centre `clearance` over the ground)."""
    out = []
    lift = np.array([0.0, 0.0, rig["clearance"]])

    def place(src, rot_cols, loc):
        c = bpy.data.objects.new(src.name + "_Pose", src.data)
        bpy.context.scene.collection.objects.link(c)
        c.matrix_world = ue_matrix(rot_cols, np.asarray(loc) + lift)
        out.append(c)

    ident = (np.array([1.0, 0, 0]), np.array([0, 1.0, 0]), np.array([0, 0, 1.0]))
    place(objs["Body"], ident, (0.0, 0.0, 0.0))
    for pair, hip, foot, pole, upper, lower in rig_legs(rig):
        knee = two_bone_knee(hip, foot, pole, upper, lower)
        for a, b, key in ((hip, knee, "LegUpper" + pair), (knee, foot, "LegLower" + pair)):
            x = _n(b - a)
            place(objs[key], make_from_xy(x, perp(pole - a, x)), 0.5 * (a + b))
        place(objs["Foot"], ident, foot)
    for side in (1.0, -1.0):
        root = np.array(rig["fang_root"]) * np.array([1.0, side, 1.0])
        p, y = math.radians(-FANG_REST_DROOP), math.radians(FANG_REST_SPREAD * side)
        x = np.array([math.cos(p) * math.cos(y), math.cos(p) * math.sin(y), math.sin(p)])
        yy = np.array([-math.sin(y), math.cos(y), 0.0])
        z = np.array([-math.sin(p) * math.cos(y), -math.sin(p) * math.sin(y), math.cos(p)])
        place(objs["Fang"], (x, yy, z), root)
    return out


def check_rig(rig):
    fails = []
    for pair, hip, foot, pole, upper, lower in rig_legs(rig)[:3]:
        reach = upper + lower
        dist = float(np.linalg.norm(foot - hip))
        knee = two_bone_knee(hip, foot, pole, upper, lower)
        measured = np.array(rig["legs"][pair]["knee"])
        print("rig %-5s reach %.1f  rest foot %.1f from the hip (%.2f of reach)  IK knee %s vs measured %s (%.1f cm)" % (
            pair, reach, dist, dist / reach, np.round(knee, 1), np.round(measured, 1), np.linalg.norm(knee - measured)))
        if dist > TARGET_REACH_FRACTION * reach:
            fails.append("%s rest foot %.1f cm from its hip > %.2f of its %.1f cm reach" % (pair, dist, TARGET_REACH_FRACTION, reach))
    return fails


# ---------------------------------------------------------------- review renders
def _look_at(cam, eye, target):
    f = np.array(target, float) - np.array(eye, float)
    cam.location = eye
    cam.rotation_euler = (math.atan2(math.hypot(f[0], f[1]), -f[2]), 0.0, -math.atan2(f[0], f[1]))


def render(objs, path, view, target_m, half_width_m, size=(1200, 900), color="TEXTURE"):
    scene = bpy.context.scene
    others = [o for o in scene.objects if o.type == "MESH" and o not in objs]
    state = [o.hide_render for o in others]
    cam_data = bpy.data.cameras.new("_ReviewCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = half_width_m * 2.0
    cam_data.clip_start, cam_data.clip_end = 0.01, 100.0
    cam = bpy.data.objects.new("_ReviewCam", cam_data)
    scene.collection.objects.link(cam)
    prev = (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y, scene.render.filepath,
            scene.display.shading.color_type, scene.display.shading.light, scene.display.shading.show_cavity)
    try:
        for o in others:
            o.hide_render = True
        for o in objs:
            o.hide_render = False
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = color
        scene.display.shading.show_cavity = True
        scene.render.resolution_x, scene.render.resolution_y = size
        scene.render.resolution_percentage = 100
        d = _n(view)
        _look_at(cam, tuple(np.asarray(target_m) + d * 10.0), tuple(target_m))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
    finally:
        for o, s in zip(others, state):
            o.hide_render = s
        (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y, scene.render.filepath,
         scene.display.shading.color_type, scene.display.shading.light, scene.display.shading.show_cavity) = prev
        bpy.data.objects.remove(cam)
        bpy.data.cameras.remove(cam_data)
    return path


def tile_images(paths, out_path, cols=2):
    imgs = [bpy.data.images.load(p) for p in paths]
    w, h = imgs[0].size
    rows = (len(imgs) + cols - 1) // cols
    sheet = np.zeros((rows * h, cols * w, 4), np.float32)
    for i, img in enumerate(imgs):
        px = np.empty(w * h * 4, np.float32)
        img.pixels.foreach_get(px)
        r, c = divmod(i, cols)
        r = rows - 1 - r
        sheet[r * h:(r + 1) * h, c * w:(c + 1) * w] = px.reshape(h, w, 4)
        bpy.data.images.remove(img)
    out = bpy.data.images.new(os.path.basename(out_path), cols * w, rows * h, alpha=True)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = out_path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    return out_path


VIEWS = {"iso": (1.0, -1.0, 0.7), "front": (1.0, 0.0, 0.08), "side": (0.0, -1.0, 0.08), "top": (0.0, -0.001, 1.0)}


def render_sheets(objs, posed):
    os.makedirs(REVIEW_DIR, exist_ok=True)
    sheets = []
    for part in PIECES:
        o = objs[part]
        lo, hi = bounds_cm(o)
        half = float((hi - lo).max()) * 0.01 * 0.65
        paths = [render([o], os.path.join(REVIEW_DIR, "%s_%s.png" % (part, k)), v, (0.0, 0.0, 0.0), half, size=(700, 600))
                 for k, v in VIEWS.items()]
        sheets.append(tile_images(paths, os.path.join(REVIEW_DIR, "%s_sheet.png" % part)))
    target = (0.0, 0.0, 0.35)
    paths = [render(posed, os.path.join(REVIEW_DIR, "Rig6_%s.png" % k), v, target, 1.0) for k, v in VIEWS.items()]
    sheets.append(tile_images(paths, os.path.join(REVIEW_DIR, "Rig6_sheet.png")))
    head = (0.45, 0.0, 0.35)
    paths = [render(posed, os.path.join(REVIEW_DIR, "Rig6_head_%s.png" % k), v, head, 0.5)
             for k, v in (("iso", (1.0, -0.8, 0.5)), ("low", (1.0, 0.6, -0.15)))]
    sheets.append(tile_images(paths, os.path.join(REVIEW_DIR, "Rig6_head_sheet.png")))
    return sheets


def debug_leg(leg, knee, knee_no, pair):
    """The source leg coloured by the side of the knee plane it falls on."""
    os.makedirs(REVIEW_DIR, exist_ok=True)
    tmp = leg.copy()
    mesh = bpy.data.meshes.new("_DebugLeg")
    tmp.to_mesh(mesh)
    tmp.free()
    col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    for poly in mesh.polygons:
        c = np.mean([mesh.vertices[i].co[:] for i in poly.vertices], axis=0)
        rgb = (0.9, 0.3, 0.2, 1.0) if np.dot(c - knee, knee_no) > 0.0 else (0.2, 0.5, 0.9, 1.0)
        for li in poly.loop_indices:
            col.data[li].color = rgb
    o = bpy.data.objects.new("_DebugLeg", mesh)
    bpy.context.scene.collection.objects.link(o)
    lo, hi = bounds_cm(o)
    c = 0.005 * (lo + hi)
    for k, v in (("side", (0.2, -1.0, 0.1)), ("front", (1.0, 0.0, 0.1))):
        render([o], os.path.join(REVIEW_DIR, "debug_leg_%s_%s.png" % (pair, k)), v, tuple(c), 0.35, color="VERTEX")
    bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.meshes.remove(mesh)


def debug_head(bm, parts):
    os.makedirs(REVIEW_DIR, exist_ok=True)
    tmp = extract(bm, parts["head"] + parts["fang_R"] + parts["fang_L"] + parts["palp_R"] + parts["palp_L"])
    mesh = bpy.data.meshes.new("_DebugHead")
    tmp.to_mesh(mesh)
    tmp.free()
    col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    centres = face_centres(bm)
    tag = {}
    for key, rgb in (("fang_R", (0.95, 0.9, 0.2, 1)), ("fang_L", (0.95, 0.6, 0.1, 1)), ("palp_R", (0.2, 0.8, 0.3, 1)),
                     ("palp_L", (0.2, 0.6, 0.9, 1))):
        for i in parts[key]:
            tag[tuple(np.round(centres[i], 6))] = rgb
    for poly in mesh.polygons:
        c = tuple(np.round(np.mean([mesh.vertices[i].co[:] for i in poly.vertices], axis=0), 6))
        rgb = tag.get(c, (0.5, 0.5, 0.5, 1.0))
        for li in poly.loop_indices:
            col.data[li].color = rgb
    o = bpy.data.objects.new("_DebugHead", mesh)
    bpy.context.scene.collection.objects.link(o)
    for k, v in (("front", (0.0, -1.0, 0.0)), ("under", (0.0, -0.2, -1.0)), ("iso", (0.8, -1.0, 0.2))):
        render([o], os.path.join(REVIEW_DIR, "debug_head_%s.png" % k), v, (0.0, -0.25, 0.2), 0.36, color="VERTEX")
    bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.meshes.remove(mesh)


# ---------------------------------------------------------------- main
def main():
    args = cli_args({"export": False, "sheets": False, "save": False, "debug": False})
    clear_scene()
    bpy.context.scene.view_settings.view_transform = "Standard"
    fails = []

    src, image = import_source()
    parts = classify(src)
    for key in ("fang_R", "fang_L", "palp_R", "palp_L"):
        print("%-7s %4d faces" % (key, len(parts[key])))
        if not 20 <= len(parts[key]) <= 600:
            fails.append("%s has %d faces" % (key, len(parts[key])))
    if args["debug"]:
        debug_head(src, parts)
    bms, rig = build_pieces(src, parts, debug=args["debug"])
    src.free()
    fails += check_rig(rig)

    mat = material(image)
    objs = {part: to_object(piece_name(part), bms[part], mat) for part in PIECES}
    report = {}
    for part, o in objs.items():
        lo, hi = bounds_cm(o)
        tris = tri_count(o)
        holes = open_edges(o)
        report[part] = {"tris": tris, "min_cm_ue": [round(float(lo[0]), 2), round(float(-hi[1]), 2), round(float(lo[2]), 2)],
                        "max_cm_ue": [round(float(hi[0]), 2), round(float(-lo[1]), 2), round(float(hi[2]), 2)]}
        print("%-32s tris %5d  min %s  max %s  open edges %d" % (o.name, tris, np.round(lo, 1), np.round(hi, 1), holes))
        if part in ("Body", "Foot") and np.abs(0.5 * (lo + hi)).max() > 0.01:
            fails.append("%s is not centred on its bounds" % o.name)
        if holes > OPEN_EDGES_MAX:
            fails.append("%s has %d open edges" % (o.name, holes))
        if tris > tris_max(part):
            fails.append("%s has %d tris > %d" % (o.name, tris, tris_max(part)))
        if not o.data.uv_layers or o.data.uv_layers[0].name != "UVMap":
            fails.append("%s has no UVMap" % o.name)
    rig["pieces"] = report
    print("SPIDER_RIG " + json.dumps(rig))

    exported = [export_fbx(objs[p]) for p in PIECES] if args["export"] else []
    if args["export"]:
        with open(os.path.join(EXPORT_DIR, "Crawler_SpiderRig.json"), "w") as fh:
            json.dump(rig, fh, indent=1)
    posed = pose_preview(objs, rig) if (args["sheets"] or args["save"]) else []
    sheets = render_sheets(objs, posed) if args["sheets"] else []
    if args["save"]:
        os.makedirs(SOURCE_DIR, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=BLEND_FILE, copy=False)
        print("saved", BLEND_FILE)
    for path in exported:
        for r in reimport_check(path):
            print("reimport %-32s tris %5d uv %s slots %s size %s" % (r["name"], r["tris"], r["uv"], r["slots"], r["size_cm"]))
            if r["uv"][:1] != ["UVMap"] or [str(m).split(".")[0] for m in r["slots"]] != [SLOT]:
                fails.append("reimport %s: uv %s slots %s" % (r["name"], r["uv"], r["slots"]))
    if sheets:
        print("sheets:", *sheets, sep="\n  ")
    if fails:
        print("CRAWLER_PIECES_FAIL", *fails, sep="\n  ")
    else:
        print("CRAWLER_PIECES_OK")


if __name__ == "__main__":
    main()
