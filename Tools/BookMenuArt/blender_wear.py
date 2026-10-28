"""Stage 2: turn BookMenu_Source.blend into the worn field cookbook (Blender/BookMenu_Worn.blend).

    blender -b Tools/BookMenuArt/Blender/BookMenu_Source.blend --python Tools/BookMenuArt/blender_wear.py

Rig contract (so the mesh still drops onto Anim_Book_Skeleton): bone rest data, actions, vertex count, weights and
shape-key deltas outside the turning sheet are untouched. Every edit is a rest-pose displacement that is a function of
POSITION (vertices duplicated along UV seams move together, so nothing cracks) and is added to every shape key too, so
morph deltas are preserved. Sizes below are millimetres at the final 25 cm page scale.

Why the pages get no out-of-plane wear: the turning sheet (PageB/PageC) rests ~0.6 mm above whichever top page
(PageA left / PageD right) it lies on, and lands on both. Cockling or curled corners on either would intersect it, so page
wear is in-plane only (outline wobble, blunted corners) and the paper's age comes from the stain textures.
"""

import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector, kdtree, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_common as bc  # noqa: E402

PAGE_WIDTH_CM = 25.0            # spine-to-fore-edge width of one page

SHEET_THICKNESS_MM = 0.8        # turning sheet (was 0.13 mm, two planes, no rim); must stay under the ~0.6 mm rest gap x2
SHEET_GUTTER_TAPER = 0.08       # fraction of page width over which the sheet thins back to the original at the spine

PAGE_EDGE_WOBBLE_MM = 0.45      # in-plane waviness of the fore-edge / head / tail outline of each page
PAGE_EDGE_WAVELENGTH_MM = 35.0
PAGE_CORNER_RADIUS_MM = 6.0     # blunted fore-edge corners

BLOCK_FORE_EDGE_CUTS = 3        # the fore-edge is single-row strips (~7.5 mm across the stack); split each row this often
BLOCK_RIDGE_MM = 0.7            # page-clump ridges across the block's fore-edge / head / tail
BLOCK_RIDGE_STACK_MM = 5.0      # ridge spacing across the stack (pages direction)
BLOCK_RIDGE_LENGTH_MM = 70.0    # how far a clump runs along the edge before it changes

COVER_BOW_MM = 0.9              # outward warp of each board
COVER_CORNER_FLARE_MM = 1.4     # fore-edge corners bent outward
COVER_CORNER_FLARE_RADIUS_MM = 30.0
COVER_CORNER_RADIUS_MM = 4.0    # blunted board corners
COVER_EDGE_WOBBLE_MM = 0.35

SEED = 11


def smoothstep(e0, e1, x):
    t = np.clip((np.asarray(x, dtype=np.float64) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def noise_at(points, offset):
    """Perlin noise in [-1, 1] at each row of points (N x 3, already frequency-scaled). The fractional nudge keeps
    integer-valued inputs off the lattice, where Perlin noise is always 0."""
    off = Vector(offset) + Vector((0.371, 0.619, 0.237))
    return np.array([noise.noise(Vector(p) + off) for p in points])


def slot_islands(bm, slot_index):
    faces = [f for f in bm.faces if f.material_index == slot_index]
    seen, islands = set(), []
    for f in faces:
        if f.index in seen:
            continue
        stack, island = [f], []
        while stack:
            c = stack.pop()
            if c.index in seen:
                continue
            seen.add(c.index)
            island.append(c)
            stack.extend(lf for e in c.edges for lf in e.link_faces
                         if lf.material_index == slot_index and lf.index not in seen)
        islands.append(island)
    return islands


def prepare_attributes(me):
    """Remember the authored corner normals and which faces are original, through every topology edit below."""
    normals = np.array([n.vector[:] for n in me.corner_normals]).ravel()
    me.attributes.new("_orig_normal", "FLOAT_VECTOR", "CORNER").data.foreach_set("vector", normals)
    me.attributes.new("_orig_face", "INT", "FACE").data.foreach_set("value", np.ones(len(me.polygons), int))


def densify_fore_edge(obj):
    """Rest pose: the block's fore-edge faces +Z near the top and is built from strips one quad wide across the stack
    (X) and 32 quads long (Y). Join each strip's triangle pairs into quads and split the rungs (the edges across the
    stack) so ridges have rows to live on. The strips' long edges are untouched, so seams with neighbouring strips stay
    vertex-matched; weights, UVs, colours and shape keys are interpolated onto the new vertices by BMesh."""
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    slot_index = bc.SLOT_NAMES.index("PagesBase")
    zmax = max(v.co.z for v in bm.verts)
    strips = [isl for isl in slot_islands(bm, slot_index)
              if sum(f.normal.z for f in isl) / len(isl) > 0.9
              and sum(f.calc_center_median().z for f in isl) / len(isl) > 0.75 * zmax]
    faces = [f for isl in strips for f in isl]
    joined = bmesh.ops.join_triangles(bm, faces=faces, cmp_seam=False, cmp_sharp=False, cmp_uvs=False,
                                      cmp_vcols=False, cmp_materials=True, angle_face_threshold=0.35,
                                      angle_shape_threshold=1.2)["faces"]
    region = {f for f in joined if f.is_valid} | {f for f in faces if f.is_valid}
    rungs = {e for f in region if len(f.verts) == 4 for e in f.edges
             if abs((e.verts[0].co - e.verts[1].co).x) > abs((e.verts[0].co - e.verts[1].co).y)}
    verts_before = len(bm.verts)
    bmesh.ops.subdivide_edges(bm, edges=list(rungs), cuts=BLOCK_FORE_EDGE_CUTS, use_grid_fill=True, smooth=0.0)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    added = len(bm.verts) - verts_before
    bm.to_mesh(me)
    bm.free()
    me.update()
    print(f"WEAR fore-edge: {len(strips)} strips, {len(rungs)} rungs split x{BLOCK_FORE_EDGE_CUTS}, +{added} verts")


class Book:
    def __init__(self):
        self.root, self.arm, self.obj = bc.get_rig()
        self.me = self.obj.data
        me = self.me
        n = len(me.vertices)
        self.co = np.empty(n * 3)
        me.vertices.foreach_get("co", self.co)
        self.co = self.co.reshape(n, 3)
        self.keys = list(me.shape_keys.key_blocks)
        self.key_co = []
        for kb in self.keys:
            a = np.empty(n * 3)
            kb.data.foreach_get("co", a)
            self.key_co.append(a.reshape(n, 3))
        if np.abs(self.key_co[0] - self.co).max() > 1e-5:
            raise RuntimeError("Basis shape key differs from mesh positions")
        self.orig = self.co.copy()

        self.vert_mat = np.full(n, -1)
        for p in me.polygons:
            for v in p.vertices:
                self.vert_mat[v] = p.material_index
        self.slot = {name: np.flatnonzero(self.vert_mat == i) for i, name in enumerate(bc.SLOT_NAMES)}

        self.vnormal = np.array([v.normal[:] for v in me.vertices])

        # Local units are centimetres at the original scale; mm at the final scale -> local.
        a = self.co[self.slot["PageA"]]
        self.page_width_local = a[:, 2].max() - a[:, 2].min()
        self.k = PAGE_WIDTH_CM / self.page_width_local
        self.mm = 1.0 / (10.0 * self.k)

    def displace(self, idx, delta):
        """Rest-pose displacement, mirrored into every shape key so morph deltas are unchanged."""
        self.co[idx] += delta
        for kc in self.key_co:
            kc[idx] += delta

    def write(self):
        self.me.vertices.foreach_set("co", self.co.ravel())
        for kb, kc in zip(self.keys, self.key_co):
            kb.data.foreach_set("co", kc.ravel())
        self.me.update()


def scale_book(book):
    book.root.scale = (bc.UE_ROOT_SCALE * book.k,) * 3
    book.root["ue_root_scale"] = bc.UE_ROOT_SCALE
    book.root["page_width_cm"] = PAGE_WIDTH_CM
    print(f"WEAR scale: page width {book.page_width_local:.2f} cm -> {PAGE_WIDTH_CM} cm (k={book.k:.4f})")


def thicken_sheet(book):
    """PageB and PageC are coincident 33x33 grids 0.02 local apart. Push them apart symmetrically about their mid
    surface along the PageC normal, recomputed per shape key so the curl keeps its thickness."""
    B, C = book.slot["PageB"], book.slot["PageC"]
    kd = kdtree.KDTree(len(C))
    for i in C:
        kd.insert(book.co[i], int(i))
    kd.balance()
    pair = np.array([kd.find(book.co[b])[1] for b in B])
    if len(set(pair.tolist())) != len(B):
        raise RuntimeError("PageB/PageC vertices do not pair 1:1")
    book.sheet_pairs = (B, pair)

    z = book.co[C, 2]
    d = (book.co[pair, 2] - z.min()) / (z.max() - z.min())
    half_orig = np.linalg.norm(book.co[pair] - book.co[B], axis=1) / 2
    half = half_orig + (SHEET_THICKNESS_MM * book.mm / 2 - half_orig) * smoothstep(0.0, SHEET_GUTTER_TAPER, d)

    tmp = book.me.copy()
    try:
        for kc in [book.co] + book.key_co:
            tmp.vertices.foreach_set("co", kc.ravel())
            tmp.update()
            nrm = np.array([tmp.vertex_normals[int(i)].vector[:] for i in pair])
            mid = (kc[pair] + kc[B]) / 2
            side = np.einsum("ij,ij->i", kc[pair] - kc[B], nrm)
            if (side <= 0).any():
                raise RuntimeError("PageC is not on its normal side of PageB")
            kc[pair] = mid + nrm * half[:, None]
            kc[B] = mid - nrm * half[:, None]
    finally:
        bpy.data.meshes.remove(tmp)
    print(f"WEAR sheet: thickness {SHEET_THICKNESS_MM} mm ({2 * half.max():.4f} local), gutter {2 * half.min():.4f} local")


def page_outline(book, idx, seed):
    """In-plane only (rest pose: pages lie in YZ, spine at min Z). Fore-edge, head and tail wobble; fore-edge corners
    are blunted. The spine edge is left alone (it disappears into the gutter)."""
    p = book.co[idx]
    y, z = p[:, 1], p[:, 2]
    ymax, zmin, zmax = np.abs(y).max(), z.min(), z.max()
    eps = 1e-3
    wav = PAGE_EDGE_WAVELENGTH_MM * book.mm
    amp = PAGE_EDGE_WOBBLE_MM * book.mm
    delta = np.zeros_like(p)

    fore = z > zmax - eps
    delta[fore, 2] += amp * noise_at(np.c_[np.zeros(fore.sum()), y[fore] / wav, np.zeros(fore.sum())], (seed, 0, 0))
    ends = (np.abs(y) > ymax - eps) & (z > zmin + eps)
    delta[ends, 1] += np.sign(y[ends]) * amp * noise_at(np.c_[z[ends] / wav, np.sign(y[ends]) * 3.0, np.zeros(ends.sum())], (0, seed, 0))

    r = PAGE_CORNER_RADIUS_MM * book.mm
    for sy in (-1.0, 1.0):
        center = np.array([sy * (ymax - r), zmax - r])
        rel = np.c_[y, z] - center
        in_corner = (sy * rel[:, 0] > 0) & (rel[:, 1] > 0)
        dist = np.linalg.norm(rel, axis=1)
        pull = in_corner & (dist > r)
        delta[pull, 1:] += (center + rel[pull] * (r / dist[pull])[:, None]) - np.c_[y, z][pull]
    book.displace(idx, delta)
    return int(fore.sum() + ends.sum())


def block_ridges(book):
    """Uneven page clumps on the block's fore-edge, head and tail. Ridges vary fast across the stack (rest X) and slowly
    along the edge; weight is zero on island boundaries (UV seams, where the block meets the pages) and ramps in over
    three rings, so seams and the page/block junction stay closed."""
    idx = book.slot["PagesBase"]
    slot_index = bc.SLOT_NAMES.index("PagesBase")
    # Weld seam twins (the block is ~30 islands split along UV seams) so only real open edges count as boundary.
    keys = np.round(book.co[idx] * 1000).astype(np.int64)
    uniq, inv = np.unique(keys, axis=0, return_inverse=True)
    inv = inv.ravel()
    wid = np.full(len(book.co), -1)
    wid[idx] = inv
    count, adj = {}, [set() for _ in range(len(uniq))]
    for poly in book.me.polygons:
        if poly.material_index != slot_index:
            continue
        ws = [wid[v] for v in poly.vertices]
        for a, b in zip(ws, ws[1:] + ws[:1]):
            if a != b:
                e = (min(a, b), max(a, b))
                count[e] = count.get(e, 0) + 1
                adj[a].add(b)
                adj[b].add(a)
    hops = np.full(len(uniq), 99)
    frontier = sorted({a for e, c in count.items() if c == 1 for a in e})
    hops[frontier] = 0
    ring = 0
    while frontier and ring < 4:
        ring += 1
        nxt = []
        for v in frontier:
            for nb in adj[v]:
                if hops[nb] > ring:
                    hops[nb] = ring
                    nxt.append(nb)
        frontier = nxt
    pos = uniq / 1000.0
    ymax = np.abs(pos[:, 1]).max()
    # The strip ends meet the head/tail sides along a line the split rungs no longer share; pin it to avoid T-cracks.
    w = smoothstep(0.0, 3.0, hops) * (np.abs(pos[:, 1]) < ymax - 1e-3)

    normal = np.zeros((len(uniq), 3))
    np.add.at(normal, inv, book.vnormal[idx])
    normal /= np.maximum(np.linalg.norm(normal, axis=1, keepdims=True), 1e-9)

    scaled = np.c_[pos[:, 0] / (BLOCK_RIDGE_STACK_MM * book.mm), pos[:, 1] / (BLOCK_RIDGE_LENGTH_MM * book.mm),
                   pos[:, 2] / (BLOCK_RIDGE_LENGTH_MM * book.mm)]
    ridge = 0.65 * noise_at(scaled, (SEED, 5, 9)) + 0.35 * noise_at(scaled * 2.3, (2, SEED, 4))
    amount = BLOCK_RIDGE_MM * book.mm * (ridge - 0.25) * w   # biased inward: clumps recess more than they bulge
    book.displace(idx, (normal * amount[:, None])[inv])
    print(f"WEAR block: {int((w > 0).sum())}/{len(uniq)} welded verts ridged, "
          f"max {np.abs(amount).max() / book.mm:.2f} mm")


def cover_wear(book):
    """Rest pose: boards in YZ at x = +-6.45, spine curled at the bottom (low Z), fore-edge at max Z. Outer, inner and
    edge faces of a board share (y, z) and the sign of x, so they move together and the board keeps its thickness."""
    idx = book.slot["Cover"]
    p = book.co[idx]
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    side = np.sign(x)
    ymax, zmax = np.abs(y).max(), z.max()
    # How much a vertex rides the board bones (vs the hinge Edge_* / spine Back_* bones): spine and hinge stay put.
    groups = {g.index: g.name for g in book.obj.vertex_groups}
    board = np.array([sum(g.weight for g in book.me.vertices[int(i)].groups
                          if groups[g.group] in ("Cover_L", "Cover_R")) for i in idx])
    z_hinge = z[board > 0.5].min()
    delta = np.zeros_like(p)

    tz = np.clip((z - z_hinge) / (zmax - z_hinge), 0, 1)
    bow = np.cos(0.5 * np.pi * y / ymax) * np.sin(np.pi * tz)
    bow *= 0.75 + 0.25 * noise_at(np.c_[y, z, side * 4] / (60 * book.mm), (SEED, 1, 1))
    delta[:, 0] += side * COVER_BOW_MM * book.mm * bow * board

    rf = COVER_CORNER_FLARE_RADIUS_MM * book.mm
    for sy in (-1.0, 1.0):
        d = np.where(np.sign(y) == sy, np.hypot(np.abs(y) - ymax, z - zmax), np.inf)
        fall = np.clip(1 - d / rf, 0, 1) ** 2
        vary = 0.6 + 0.4 * noise_at(np.c_[side * 7, np.full_like(y, sy * 7), np.zeros_like(y)], (SEED, 2, 3))
        delta[:, 0] += side * COVER_CORNER_FLARE_MM * book.mm * fall * vary * board

    amp, wav = COVER_EDGE_WOBBLE_MM * book.mm, PAGE_EDGE_WAVELENGTH_MM * book.mm
    edge_band = 3.0 * book.mm                             # outer rim of the board, where the bevel verts live
    fore = smoothstep(zmax - edge_band, zmax, z)
    delta[:, 2] += fore * amp * noise_at(np.c_[y / wav, side * 5, np.zeros_like(y)], (SEED, 3, 0))
    ends = smoothstep(ymax - edge_band, ymax, np.abs(y)) * board
    delta[:, 1] += np.sign(y) * ends * amp * noise_at(np.c_[z / wav, side * 5 + np.sign(y) * 11, np.zeros_like(y)], (0, SEED, 3))

    r = COVER_CORNER_RADIUS_MM * book.mm
    yz = np.c_[y + delta[:, 1], z + delta[:, 2]]
    for sy in (-1.0, 1.0):
        center = np.array([sy * (ymax - r), zmax - r])
        rel = yz - center
        in_corner = (sy * rel[:, 0] > 0) & (rel[:, 1] > 0)
        dist = np.linalg.norm(rel, axis=1)
        pull = in_corner & (dist > r)
        delta[pull, 1:] += (center + rel[pull] * (r / dist[pull])[:, None]) - yz[pull]
    book.displace(idx, delta)
    print(f"WEAR cover: max move {np.linalg.norm(delta, axis=1).max() / book.mm:.2f} mm over {len(idx)} verts")


def add_sheet_rim(book):
    """Close the turning sheet with a rim between PageC's boundary loop and its PageB twins. No new vertices, so no new
    weights or shape-key data. Rim faces take the PagesBase slot (page-edge material); their UV2 lands in the empty top
    band of the pages' UV2 layout so they never pick up a stain island."""
    B, C = book.sheet_pairs
    c_to_b = dict(zip(C.tolist(), B.tolist()))
    me = book.me
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    orig_flag = bm.faces.layers.int["_orig_face"]
    uv ={name: bm.loops.layers.uv[name] for name in (bc.UV_BASE, bc.UV_LIGHTMAP, bc.UV_UNIQUE)}
    color = bm.loops.layers.color.get("Attribute")
    page_c = bc.SLOT_NAMES.index("PageC")

    c_set = set(C.tolist())
    zs = book.co[C, 2]
    ys = book.co[C, 1]
    zmin, zmax, ymax = zs.min(), zs.max(), np.abs(ys).max()
    perimeter = 2 * (zmax - zmin) + 4 * ymax

    def along(v):  # 0..1 around the sheet outline, for the strip UVs
        y, z = v.co.y, v.co.z
        if z > zmax - 1e-3:
            return (2 * (zmax - zmin) + (y + ymax)) / perimeter * 0.5
        return ((z - zmin) + (0 if y < 0 else (zmax - zmin) + 2 * ymax)) / perimeter

    rim_faces = []
    for e in bm.edges:
        if not e.is_boundary or e.verts[0].index not in c_set or e.verts[1].index not in c_set:
            continue
        f = e.link_faces[0]
        if f.material_index != page_c:
            continue
        a, b = e.verts
        loop = next(l for l in f.loops if l.vert == a)
        c1, c2 = (a, b) if loop.link_loop_next.vert == b else (b, a)
        b1, b2 = bm.verts[c_to_b[c1.index]], bm.verts[c_to_b[c2.index]]
        face = bm.faces.new((c2, c1, b1, b2))
        face.material_index = bc.SLOT_NAMES.index("PagesBase")
        face.smooth = True
        face[orig_flag] = 0
        rim_faces.append(face)
        for l in face.loops:
            s = along(l.vert)
            inner = l.vert.index in c_set
            # The page-side texture's fibre streaks run along V: run the rim along V too, or it reads as a dashed ladder.
            l[uv[bc.UV_BASE]].uv = (0.5 + (0.004 if inner else 0.0), s)
            l[uv[bc.UV_LIGHTMAP]].uv = (0.97 + 0.02 * s, 0.002 if inner else 0.0)
            l[uv[bc.UV_UNIQUE]].uv = (0.02 + 0.6 * s, 0.99 if inner else 0.985)
            if color is not None:
                donor = next(dl for dl in l.vert.link_loops if dl.face is not face)
                l[color] = donor[color]
    center = Vector((0.0, 0.0, (zmin + zmax) / 2))
    for f in rim_faces:
        f.normal_update()
        out = f.calc_center_median() - center
        out.x = 0.0
        if f.normal.dot(out) <= 0:
            raise RuntimeError("Rim face points into the sheet")
        for e in f.edges:
            if all(lf in rim_faces for lf in e.link_faces) and e.calc_face_angle(0.0) > 0.6:
                e.smooth = False
            elif any(lf not in rim_faces for lf in e.link_faces):
                e.smooth = False
    bm.to_mesh(me)
    bm.free()
    me.update()
    print(f"WEAR rim: {len(rim_faces)} faces")


def rebuild_normals(book):
    """Keep the authored custom normals wherever a corner's vertex did not move and its face is original; use fresh
    normals (respecting sharp edges) for moved geometry and the rim, so displacement actually shades."""
    me = book.me
    moved = np.linalg.norm(book.co - book.orig, axis=1) > 1e-6
    corner_vert = np.empty(len(me.loops), int)
    me.loops.foreach_get("vertex_index", corner_vert)
    corner_face = np.repeat(np.arange(len(me.polygons)), [p.loop_total for p in me.polygons])
    # polygons are contiguous in corner order
    starts = np.array([p.loop_start for p in me.polygons])
    if not (np.diff(starts) > 0).all():
        raise RuntimeError("Unexpected corner order")
    orig_face = np.empty(len(me.polygons), int)
    me.attributes["_orig_face"].data.foreach_get("value", orig_face)
    keep = (~moved[corner_vert]) & (orig_face[corner_face] == 1)

    saved = np.empty(len(me.loops) * 3)
    me.attributes["_orig_normal"].data.foreach_get("vector", saved)
    saved = saved.reshape(-1, 3)
    if "custom_normal" in me.attributes:
        me.attributes.remove(me.attributes["custom_normal"])
    fresh =np.array([n.vector[:] for n in me.corner_normals])
    final = np.where(keep[:, None], saved, fresh)
    me.normals_split_custom_set([tuple(n) for n in final])
    me.attributes.remove(me.attributes["_orig_normal"])
    me.attributes.remove(me.attributes["_orig_face"])
    print(f"WEAR normals: kept {int(keep.sum())}/{len(keep)} authored corner normals")


def main():
    _, _, obj = bc.get_rig()
    prepare_attributes(obj.data)
    densify_fore_edge(obj)
    book = Book()
    scale_book(book)
    thicken_sheet(book)
    edges = [page_outline(book, book.slot["PageA"], SEED + 1), page_outline(book, book.slot["PageD"], SEED + 2),
             page_outline(book, np.concatenate(book.sheet_pairs), SEED + 3)]
    print(f"WEAR pages: outline verts moved A/D/sheet = {edges}")
    block_ridges(book)
    cover_wear(book)
    book.write()
    add_sheet_rim(book)
    rebuild_normals(book)
    bpy.ops.wm.save_as_mainfile(filepath=bc.WORN_BLEND)
    print(f"WEAR ok: {bc.WORN_BLEND}")


main()
