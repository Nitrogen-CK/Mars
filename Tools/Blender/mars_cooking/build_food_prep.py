"""Prep variants of the Mars food library (Blender 5.2, headless): <Name>_Prep_Mars_SM, the hero rebuilt to the game's
runtime-mesh contract (CkFoundation CkRuntimeMesh import: food_spec "prep variants", food_common.check_runtime_mesh).

    blender -b --factory-startup --python build_food_prep.py -- --export --save --sheets [--only Puffer,Tentacle]

Runs after build_food_meats.py / build_food_produce.py (it reads their exported hero FBX) and before the fryer's
--batter pass (which batters every <Name>_Prep_Mars_SM it finds into <Name>_Prep_Battered_Mars_SM).

For every food_spec.INGREDIENTS entry with a "prep" dict:
  1. import the hero <Name>_Mars_SM.fbx (what Unreal imports), split it into closed shells; the largest is the body;
  2. shells "union": Exact boolean union of every other shell (horns, spikes, bone, knuckle) into the body;
     shells "drop": the other shells are left out (their colour is still painted onto the body where they sat);
  3. Decimate (collapse) to food_spec.PREP_TRI_BUDGET triangles: flat shaded + per-facet colour = 3 render vertices
     per triangle, so the budget keeps the mesh under the 2048 render-vertex import ceiling;
  4. per face: slot and colour from the hero surface seen along the face normal (ray from just outside, nearest
     point as the fallback), alpha = the prep mesh's own cavity (food_spec vertex-colour contract);
  5. a fresh UV0 atlas and <Name>_Prep_Mask_Mars_T.png transferred texel by texel from the hero's mask (nearest
     hero point -> its UV0 -> bilinear sample), so the prep material instance reads the same masks;
  6. export in the hero's own frame (no re-centring) and FAIL unless the exported FBX passes
     food_common.check_runtime_mesh (one closed solid, <= 2048 render verts, <= 4096 tris, ...).
The sidecar carries a "prep" block (what was merged / dropped, tri counts) and a "runtime_mesh" block (the checker's
numbers). Heroes with cpu_access but no prep entry (MeatSlab, HerbPile) are measured and reported, not rebuilt.
Prints FOOD_PREP_OK.
"""
import json
import os
import re
import sys
import time

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import food_common as fc  # noqa: E402

spec = fc.spec
BLEND_PATH = os.path.join(spec.BLEND_DIR, spec.CATEGORIES["prep"][0])
RAY_OFFSET_CM = 0.6           # colour / slot transfer ray starts this far outside the prep face
RETRY_STEP = 24               # fewer tris per retry when a decimated union self-intersects
RETRIES = 6
FEATURE_COLOUR = (0.16, 0.32)  # sqrt-RGB distance from the body colour: smoothstep -> feature weight 0..1
FEATURE_FACTOR = 8.0          # a full feature vertex collapses at 1 / FEATURE_FACTOR of the plain skin's weight
FEATURE_MAX_SHARE = 0.25      # more "feature" than this is a paint region, not a detail: no weighting

T0 = time.time()


def log(msg):
    print("[prep %6.1fs] %s" % (time.time() - T0, msg))
    sys.stdout.flush()


def remove_object(obj):
    mesh = obj.data if obj.type == "MESH" else None
    bpy.data.objects.remove(obj, do_unlink=True)
    if mesh is not None and mesh.users == 0:
        bpy.data.meshes.remove(mesh)


# ================================================================ hero
def import_hero(name):
    """The exported hero FBX as an object (identity transform) + arrays: verts cm, tris, tri loops, slot per tri,
    loop colours, loop UV0."""
    path = os.path.join(spec.EXPORT_DIR, spec.mesh_name(name) + ".fbx")
    if not os.path.exists(path):
        raise FileNotFoundError("%s: run its builder with --export first" % path)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, colors_type="LINEAR")
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    for o in new:
        if o not in meshes:
            bpy.data.objects.remove(o)
    if len(meshes) != 1:
        raise RuntimeError("%s: %d meshes" % (path, len(meshes)))
    hero = meshes[0]
    hero.data.transform(hero.matrix_world)
    hero.matrix_world.identity()
    hero.name = "%s_Hero" % name
    me = hero.data
    me.calc_loop_triangles()
    n = len(me.vertices)
    co = np.empty(n * 3)
    me.vertices.foreach_get("co", co)
    lt = me.loop_triangles
    tris = np.empty(len(lt) * 3, np.int64)
    lt.foreach_get("vertices", tris)
    tl = np.empty(len(lt) * 3, np.int64)
    lt.foreach_get("loops", tl)
    mat = np.empty(len(lt), np.int64)
    lt.foreach_get("material_index", mat)
    slots = [re.sub(r"\.\d+$", "", m.name) if m else "Flesh" for m in me.materials]
    attr = me.color_attributes[0]
    col = np.empty(len(attr.data) * 4, np.float32)
    attr.data.foreach_get("color", col)
    col = col.reshape(-1, 4)
    if attr.domain != "CORNER":
        lv = np.empty(len(me.loops), np.int64)
        me.loops.foreach_get("vertex_index", lv)
        col = col[lv]
    uvl = me.uv_layers.get("UVMap") or me.uv_layers[0]
    uv = np.empty(len(me.loops) * 2)
    uvl.data.foreach_get("uv", uv)
    return hero, dict(path=path, verts=co.reshape(n, 3) * 100.0, tris=tris.reshape(-1, 3), loops=tl.reshape(-1, 3),
                      slot=np.array([slots[min(i, len(slots) - 1)] for i in mat]), slots=slots, col=col,
                      uv=uv.reshape(-1, 2))


def shells_of(verts, tris):
    """Closed shells over position-welded vertices -> list of tri index arrays, largest (most tris) first."""
    keys = np.round(verts / fc.RUNTIME_WELD_CM).astype(np.int64)
    _, weld = np.unique(keys, axis=0, return_inverse=True)
    weld = np.asarray(weld).ravel()
    parent = list(range(int(weld.max()) + 1))
    t = weld[tris]
    for tri in t.tolist():
        r0 = fc._uf_find(parent, tri[0])
        for v in tri[1:]:
            r = fc._uf_find(parent, v)
            if r != r0:
                parent[r] = r0
    root = np.array([fc._uf_find(parent, tri[0]) for tri in t.tolist()])
    groups = [np.where(root == r)[0] for r in np.unique(root)]
    return sorted(groups, key=len, reverse=True)


def sub_mesh(verts, tris, idx):
    used = np.unique(tris[idx])
    remap = -np.ones(len(verts), np.int64)
    remap[used] = np.arange(len(used))
    return verts[used], remap[tris[idx]]


# ================================================================ geometry ops (evaluated modifiers)
def _mesh_object(name, verts_cm, tris):
    me = bpy.data.meshes.new(name)
    me.from_pydata((np.asarray(verts_cm) * 0.01).tolist(), [], np.asarray(tris).tolist())
    me.validate(verbose=False)
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _evaluated_arrays(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), preserve_all_data_layers=False, depsgraph=dg)
    me.calc_loop_triangles()
    n = len(me.vertices)
    co = np.empty(n * 3)
    me.vertices.foreach_get("co", co)
    t = np.empty(len(me.loop_triangles) * 3, np.int64)
    me.loop_triangles.foreach_get("vertices", t)
    bpy.data.meshes.remove(me)
    v, t = co.reshape(n, 3) * 100.0, t.reshape(-1, 3)
    used = np.unique(t)
    remap = -np.ones(len(v), np.int64)
    remap[used] = np.arange(len(used))
    return v[used], remap[t]


def boolean_union(body, others):
    """Exact union of body (verts, tris) with the closed shells in others [(verts, tris)] -> (verts, tris)."""
    b = _mesh_object("_PrepBody", *body)
    ov, ot, base = [], [], 0
    for v, t in others:
        ov.append(v)
        ot.append(t + base)
        base += len(v)
    o = _mesh_object("_PrepShells", np.concatenate(ov), np.concatenate(ot))
    try:
        mod = b.modifiers.new("PrepUnion", "BOOLEAN")
        mod.operation = "UNION"
        mod.solver = "EXACT"
        mod.operand_type = "OBJECT"
        mod.object = o
        mod.use_self = True                 # bone shaft and knuckle lobes overlap each other too
        return _evaluated_arrays(b)
    finally:
        remove_object(b)
        remove_object(o)


def decimate(verts, tris, target, weights=None, factor=FEATURE_FACTOR):
    """Collapse to target tris. weights (per vertex 0..1) make those vertices costlier to collapse, so painted
    features (eyes, mouth, teeth) keep their triangles while the plain skin takes the reduction."""
    if len(tris) <= target:
        return verts, tris, 1.0
    obj = _mesh_object("_PrepDecimate", verts, tris)
    try:
        ratio = target / len(tris)
        dec = obj.modifiers.new("PrepFacets", "DECIMATE")
        dec.decimate_type = "COLLAPSE"
        dec.ratio = ratio
        dec.use_collapse_triangulate = True
        if weights is not None and np.any(weights > 0):
            # Blender's Decimate vertex group says what MAY be decimated: plain skin 1, a full feature 1 - 1/factor
            vg = obj.vertex_groups.new(name="Decimatable")
            for i, w in enumerate(weights):
                vg.add([i], float(1.0 - w * (1.0 - 1.0 / factor)), "REPLACE")
            dec.vertex_group = vg.name
            dec.vertex_group_factor = 1.0
        v, t = _evaluated_arrays(obj)
        return v, t, ratio
    finally:
        remove_object(obj)


# ================================================================ transfer from the hero
def tri_areas(v, t):
    return 0.5 * np.linalg.norm(np.cross(v[t[:, 1]] - v[t[:, 0]], v[t[:, 2]] - v[t[:, 0]]), axis=1)


def barycentric(p, a, b, c):
    v0, v1, v2 = b - a, c - a, p - a
    d00, d01, d11 = (v0 * v0).sum(-1), (v0 * v1).sum(-1), (v1 * v1).sum(-1)
    d20, d21 = (v2 * v0).sum(-1), (v2 * v1).sum(-1)
    den = d00 * d11 - d01 * d01
    den = np.where(np.abs(den) < 1e-12, 1e-12, den)
    wb = np.clip((d11 * d20 - d01 * d21) / den, 0.0, 1.0)
    wc = np.clip((d00 * d21 - d01 * d20) / den, 0.0, 1.0)
    wa = np.clip(1.0 - wb - wc, 0.0, 1.0)
    s = wa + wb + wc
    return np.stack([wa / s, wb / s, wc / s], -1)


def transfer_faces(prep, hero_bvh, H):
    """Per prep face: the hero triangle seen along the face normal from just outside (nearest as the fallback)."""
    centres = fc.face_centers_cm(prep)
    normals = fc.face_normals(prep)
    hit_tri = np.empty(len(centres), np.int64)
    by_ray = 0
    for i, (c, n) in enumerate(zip(centres, normals)):
        o = Vector(c + n * RAY_OFFSET_CM)
        loc, _nrm, idx, _d = hero_bvh.ray_cast(o, Vector(-n), RAY_OFFSET_CM * 2.5)
        if idx is None:
            idx = hero_bvh.find_nearest(Vector(c))[2]
        else:
            by_ray += 1
        hit_tri[i] = idx
    rgb = H["col"][H["loops"][hit_tri]][:, :, :3].mean(axis=1)
    return hit_tri, rgb, by_ray


def transfer_mask(prep, hero_bvh, H, hero_mask_path, out_name):
    """<out_name>_Mask_Mars_T.png over the prep UV0: per texel, the hero mask at the nearest hero surface point."""
    img = bpy.data.images.load(hero_mask_path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    src = px.reshape(h, w, 4)                    # bottom-up rows, like the bake fields

    def sample(uv):
        x = np.clip(uv[:, 0] * w - 0.5, 0, w - 1.001)
        y = np.clip(uv[:, 1] * h - 0.5, 0, h - 1.001)
        x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
        fx, fy = (x - x0)[:, None], (y - y0)[:, None]
        return (src[y0, x0] * (1 - fx) * (1 - fy) + src[y0, x0 + 1] * fx * (1 - fy)
                + src[y0 + 1, x0] * (1 - fx) * fy + src[y0 + 1, x0 + 1] * fx * fy)

    def masks(fields):
        p = fields["position_cm"]
        hh, ww = p.shape[:2]
        cover = (fields["coverage"] > 0.5) & (np.linalg.norm(fields["normal"] + 1.0, axis=-1) > 1e-3)
        out = np.zeros((hh, ww, 4), np.float32)
        out[..., 1:3] = 0.5
        pts = p[cover]
        face = np.empty(len(pts), np.int64)
        near = np.empty((len(pts), 3))
        for i, q in enumerate(pts):
            loc, _n, idx, _d = hero_bvh.find_nearest(Vector(q))
            face[i] = idx
            near[i] = loc[:]
        tv = H["verts"][H["tris"][face]]
        wts = barycentric(near, tv[:, 0], tv[:, 1], tv[:, 2])
        uv = (H["uv"][H["loops"][face]] * wts[..., None]).sum(axis=1)
        out[cover] = sample(uv)
        return out

    path, _fields = fc.bake_masks(prep, masks, name=out_name)
    return path


# ================================================================ one prep mesh
def build_prep(name, info):
    cfg = info["prep"]
    hero, H = import_hero(name)
    groups = shells_of(H["verts"], H["tris"])
    body_idx, other = groups[0], groups[1:]

    def describe(idx):
        slots = sorted(set(H["slot"][idx].tolist()))
        v = H["verts"][np.unique(H["tris"][idx])]
        return dict(tris=int(len(idx)), slots=slots, centre_cm=(v.mean(0) * fc.UE_MIRROR).round(2).tolist(),
                    size_cm=round(float(np.ptp(v, axis=0).max()), 2))
    shells_info = [describe(g) for g in other]
    body = sub_mesh(H["verts"], H["tris"], body_idx)
    policy = cfg.get("shells", "union")
    merged, dropped = [], []
    if other and policy == "union":
        v, t = boolean_union(body, [sub_mesh(H["verts"], H["tris"], g) for g in other])
        merged = shells_info
    else:
        v, t = body
        dropped = shells_info
    solid_tris = len(t)
    log("%s: hero %d tris, %d shells -> %s, solid %d tris" % (name, len(H["tris"]), len(other), policy, solid_tris))

    # painted features (eyes, mouth, teeth, sucker rims): hero faces whose colour stands off the body's own colour
    hero_bvh = BVHTree.FromPolygons(H["verts"].tolist(), H["tris"].tolist(), all_triangles=True)
    tri_rgb = H["col"][H["loops"]][:, :, :3].mean(axis=1)
    body_slot = max(set(H["slot"][body_idx].tolist()), key=lambda x: int((H["slot"][body_idx] == x).sum()))
    ref = np.median(tri_rgb[body_idx][H["slot"][body_idx] == body_slot], axis=0)
    feat_tri = fc.smoothstep(FEATURE_COLOUR[0], FEATURE_COLOUR[1],
                             np.linalg.norm(np.sqrt(np.clip(tri_rgb, 0, 1)) - np.sqrt(ref), axis=1))
    feat_tri[H["slot"] != body_slot] = 0.0          # horns / bone are geometry, not paint: plain collapse
    weights = np.array([feat_tri[hero_bvh.find_nearest(Vector(p))[2]] for p in v])
    share = float((weights > 0.5).mean())
    if share > FEATURE_MAX_SHARE or not cfg.get("protect_features", True):
        log("%s: %.0f%% of the solid reads as 'feature' colour (a second paint region, e.g. the mushroom stem): "
            "plain decimation" % (name, share * 100))
        weights = np.zeros(len(v))
    log("%s: %d of %d solid verts weighted as painted features" % (name, int((weights > 0.5).sum()), len(v)))

    budget = int(cfg.get("tri_budget", spec.PREP_TRI_BUDGET))
    attempt, rep = None, None
    tries = [(budget - k * RETRY_STEP, weights) for k in range(RETRIES)]
    if np.any(weights > 0):                       # a weighted collapse can fold thin rims: unweighted as the fallback
        tries += [(budget - k * RETRY_STEP, None) for k in range(RETRIES)]
    for target, w in tries:
        dv, dt, ratio = decimate(v, t, target, w)
        if w is None and np.any(weights > 0):
            weights = np.zeros(len(v))
        rep = fc.topology_report(dv, dt)
        log("%s: decimate to %d -> %d tris, %s" % (name, target, len(dt), json.dumps(
            {k_: rep[k_] for k_ in ("components", "closed", "single_solid", "self_intersections", "degenerate_tris",
                                    "bowtie_verts", "volume_cm3")})))
        if rep["single_solid"] and rep["degenerate_tris"] == 0 and len(dt) * 3 <= fc.RUNTIME_MAX_RENDER_VERTS:
            attempt = (dv, dt, ratio, target)
            break
    if attempt is None:
        raise fc.RuntimeMeshError("%s_Prep: no decimation of the %d-tri solid passed the topology check (%s)" % (
            name, solid_tris, rep))
    dv, dt, ratio, target = attempt

    # ---- the prep object: faceted, slots + colours from the hero, own cavity in A
    prep_name = spec.mesh_name(name, spec.PREP_STAGE)
    old = bpy.data.objects.get(prep_name)
    if old is not None:
        remove_object(old)
    tmp = fc.new_object("_PrepProbe", dv, dt, slots=tuple(H["slots"]), face_slots=[0] * len(dt))
    hit_tri, rgb, by_ray = transfer_faces(tmp, hero_bvh, H)
    remove_object(tmp)
    face_slot_names = H["slot"][hit_tri]
    slots = [s for s in H["slots"] if s in set(face_slot_names.tolist())]
    prep = fc.new_object(prep_name, dv, dt, slots=tuple(slots), face_slots=[slots.index(s) for s in face_slot_names])
    if len(prep.data.polygons) != len(dt):
        raise RuntimeError("%s: mesh.validate changed the face count" % prep_name)
    fc.paint(prep, rgb, variation=0.0, cavity_darken=0.0)          # hero colours already carry jitter + crevices
    fc.smart_uv(prep)

    lo_h, hi_h = H["verts"].min(0), H["verts"].max(0)
    lo_p, hi_p = fc.bounds_cm(prep)
    frame_note = dict(frame="hero", pivot_shift_cm=[0.0, 0.0, 0.0],
                      hero_bounds_min_cm=np.minimum(lo_h * fc.UE_MIRROR, hi_h * fc.UE_MIRROR).round(3).tolist(),
                      hero_bounds_max_cm=np.maximum(lo_h * fc.UE_MIRROR, hi_h * fc.UE_MIRROR).round(3).tolist(),
                      bounds_delta_cm=round(float(np.abs(np.r_[lo_p - lo_h, hi_p - hi_h]).max()), 3))
    prep_block = dict(hero=spec.mesh_name(name), shells=policy, hero_tris=int(len(H["tris"])),
                      hero_shells=1 + len(other), body_tris=int(len(body_idx)), solid_tris=int(solid_tris),
                      merged=merged, dropped=dropped, tri_budget=budget, decimate_target=target,
                      decimate_ratio=round(float(ratio), 4), feature_verts=int((weights > 0.5).sum()),
                      faces_by_ray=int(by_ray), faces_total=int(len(dt)),
                      colour_source="hero surface along the face normal (nearest point as fallback)",
                      morph="none: the runtime slicer projects every UV layer on its cut caps")
    stats = dict(name=prep_name, tris=fc.tri_count(prep), prep=prep_block, **frame_note)
    return hero, H, hero_bvh, prep, stats


def export_prep(name, hero, H, hero_bvh, prep, stats, bake=True):
    hero_mask = os.path.join(spec.EXPORT_DIR, "%s_Mask_Mars_T.png" % name)
    stem = "%s_%s" % (name, spec.PREP_STAGE)
    if bake and os.path.exists(hero_mask):
        t0 = time.time()
        stats["mask"] = transfer_mask(prep, hero_bvh, H, hero_mask, spec.mesh_name(name, spec.PREP_STAGE))
        log("%s mask %s (%.1fs)" % (stem, stats["mask"], time.time() - t0))
    else:
        stats["mask"] = None
        log("%s: no mask (%s)" % (stem, "--nobake" if not bake else "hero mask missing"))
    info = spec.INGREDIENTS[name]
    extra = {"category": info["category"], "builder": os.path.basename(__file__), "size_spec_cm": info["size_cm"],
             "cpu_access": bool(info["prep"].get("cpu_access", True)), "prep": stats["prep"],
             "rest_pose": "the hero's own frame and pivot (centred XY, base z = 0 as authored)"}
    for k in ("frame", "pivot_shift_cm", "hero_bounds_min_cm", "hero_bounds_max_cm", "bounds_delta_cm"):
        extra[k] = stats[k]
    fbx = fc.export_fbx(prep, extra=extra)
    rep = fc.check_runtime_mesh(fbx)                   # raises: a prep mesh that the game would reject fails the build
    side = os.path.splitext(fbx)[0] + ".json"
    with open(side) as fh:
        meta = json.load(fh)
    meta["runtime_mesh"] = {k: v for k, v in rep.items() if k not in ("name",)}
    with open(side, "w") as fh:
        json.dump(meta, fh, indent=2)
    stats["fbx"] = fbx
    stats["runtime_mesh"] = rep
    return stats


def report_existing(names):
    """Heroes the game slices whole (cpu_access, no prep entry) and the authored cuts: measured, never rebuilt."""
    out = {}
    for n in names:
        path = os.path.join(spec.EXPORT_DIR, n + ".fbx")
        if os.path.exists(path):
            rep = fc.runtime_mesh_report(path)
            out[n] = {k: rep[k] for k in ("tris", "render_verts", "closed", "single_solid", "components", "ok",
                                          "problems")}
    return out


# ================================================================ main
def main():
    args = fc.cli_args({"export": False, "save": False, "sheets": False, "only": "", "nobake": False})
    fc.ensure_dirs()
    fc.clear_scene()
    names = [n for n, info in spec.INGREDIENTS.items() if info.get("prep")]
    if args["only"]:
        want = [n.strip() for n in str(args["only"]).split(",") if n.strip()]
        bad = [n for n in want if n not in names]
        if bad:
            raise SystemExit("no prep entry for %s (have %s)" % (bad, ", ".join(names)))
        names = want
    summary, keep = {}, []
    for name in names:
        hero, H, hero_bvh, prep, stats = build_prep(name, spec.INGREDIENTS[name])
        if args["export"]:
            stats = export_prep(name, hero, H, hero_bvh, prep, stats, bake=not args["nobake"])
        else:
            rep = fc.topology_report(fc.verts_cm(prep), np.array([list(p.vertices) for p in prep.data.polygons]))
            stats["topology"] = rep
        if args["sheets"]:
            stats["sheet"] = fc.review_sheet([hero, prep], "%s_%s" % (name, spec.PREP_STAGE),
                                             views=("iso", "front", "side", "top"), color="VERTEX", size=(1600, 800))
            log("sheet %s" % stats["sheet"])
        summary[name] = {k: v for k, v in stats.items() if k != "runtime_mesh"}
        if "runtime_mesh" in stats:
            summary[name]["runtime_mesh"] = {k: stats["runtime_mesh"][k] for k in (
                "tris", "render_verts", "closed", "single_solid", "components", "self_intersections", "ok")}
        keep.append(prep)
        remove_object(hero)
    if args["sheets"] and len(keep) > 1:
        summary["_sheet_all"] = fc.review_sheet(keep, "Prep_All", views=("iso", "top"), color="VERTEX", size=(2000, 700))
        log("sheet %s" % summary["_sheet_all"])
    if not args["only"]:
        existing = [spec.mesh_name(n) for n, i in spec.INGREDIENTS.items() if i.get("cpu_access") and not i.get("prep")]
        existing += [spec.mesh_name(n, c) for n, i in spec.INGREDIENTS.items() for c in i.get("cuts") or ()]
        summary["_existing"] = report_existing(existing)
    if args["save"]:
        if args["only"]:
            log("--save refused with --only: Food_Prep.blend must hold every prep mesh")
        else:
            for o in list(bpy.data.objects):
                if o not in keep:
                    remove_object(o)
            for i, o in enumerate(keep):
                o.location = (0.3 * (i - (len(keep) - 1) * 0.5), 0.0, 0.0)     # object transforms only
            bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
            fc.save_blend(BLEND_PATH)
            summary["_blend"] = BLEND_PATH
    print("PREP_SUMMARY " + json.dumps(summary, default=str))
    print("FOOD_PREP_OK")


if __name__ == "__main__":
    main()
