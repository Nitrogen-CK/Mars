"""Low polygon stone, cavern and structural timber family for Chain Crossing.

Family geometry is local, in metres. Floor carriers have their top at zero;
all other modules are authored from their contact base upward.
"""
import math


OWNED = {f"CCS{i:02d}" for i in (*range(1, 21), *range(43, 51), 86, 87, 88)}


def _profile(b, name, points, depth, mat=None, y=0):
    """Extrude a counterclockwise X/Z silhouette, keeping planar end joints."""
    n = len(points)
    verts = [(x, y - depth / 2, z) for x, z in points]
    verts += [(x, y + depth / 2, z) for x, z in points]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    faces += [(i + n, (i + 1) % n + n, (i + 1) % n, i) for i in range(n)]
    return b.mesh(name, verts, faces, mat)


def _stone(b, name, loc, size, mat=None, bevel=None):
    return b.box(name, loc, size, mat, bevel=min(size) * .11 if bevel is None else bevel)


def _block_courses(b, width, depth, height, rows=5, cols=3, z0=0, y=0):
    """Broad bevel blocks; end faces remain at the modular envelope."""
    rh = height / rows
    gap = min(.016, rh * .035)
    for row in range(rows):
        # Alternate long/short bonds without changing module end faces.
        cuts = [-width / 2]
        cuts += [-width / 2 + width * (i + (.45 if row % 2 else 0)) / cols
                 for i in range(1, cols)]
        cuts += [width / 2]
        for j, (a, z) in enumerate(zip(cuts[:-1], cuts[1:])):
            _stone(b, f"masonry_{row}_{j}", ((a + z) / 2, y, z0 + (row + .5) * rh),
                   (z - a - gap, depth, rh - gap))


def _clip(poly, axis, value, positive):
    if not poly:
        return []
    result = []
    previous = poly[-1]
    dp = (previous[axis] - value) * positive
    for current in poly:
        dc = (current[axis] - value) * positive
        if (dc >= 0) != (dp >= 0):
            t = dp / (dp - dc)
            result.append(tuple(previous[k] + t * (current[k] - previous[k]) for k in range(2)))
        if dc >= 0:
            result.append(current)
        previous, dp = current, dc
    return result


def _beveled_slab(b, name, polygon, z0, z1):
    """Small top chamfer, with exact flat top and full module footprint below it."""
    n = len(polygon)
    cx = sum(p[0] for p in polygon) / n
    cy = sum(p[1] for p in polygon) / n
    bevel = min(.018, (z1 - z0) * .16)
    inner = []
    for x, y in polygon:
        length = math.hypot(x - cx, y - cy)
        scale = max(.7, 1 - bevel / max(length, .001))
        inner.append((cx + (x - cx) * scale, cy + (y - cy) * scale))
    verts = [(x, y, z0) for x, y in polygon]
    verts += [(x, y, z1 - bevel) for x, y in polygon]
    verts += [(x, y, z1) for x, y in inner]
    faces = [tuple(reversed(range(n))), tuple(range(2 * n, 3 * n))]
    for layer in range(2):
        for i in range(n):
            j = (i + 1) % n
            faces.append((layer * n + i, layer * n + j, (layer + 1) * n + j, (layer + 1) * n + i))
    return b.mesh(name, verts, faces)


def _paving(b, w, d, h, angled=False, border=False):
    """Flagstones clipped to the closure silhouette, always planar at Z=0."""
    polygon = [(-w / 2, -d / 2), (w / 2, -d / 2),
               (w / 2, d * (.12 if angled else .5)),
               (-w / 2, d / 2)]
    # Continuous backing prevents seams revealing a hole through the carrier.
    b.extrude("paving_buried_substrate", polygon, -h, -min(.018, h * .3))
    nx, ny = max(2, round(w / .72)), max(2, round(d / .72))
    seam = .008
    for ix in range(nx):
        for iy in range(ny):
            xa = -w / 2 + ix * w / nx + (seam if ix else 0)
            xb = -w / 2 + (ix + 1) * w / nx - (seam if ix < nx - 1 else 0)
            ya = -d / 2 + iy * d / ny + (seam if iy else 0)
            yb = -d / 2 + (iy + 1) * d / ny - (seam if iy < ny - 1 else 0)
            p = _clip(_clip(_clip(_clip(polygon, 0, xa, 1), 0, xb, -1), 1, ya, 1), 1, yb, -1)
            if len(p) >= 3:
                _beveled_slab(b, f"wearing_flag_{ix}_{iy}", p, -h * .72, 0)
    if border:
        # Edge stone joints live below the same walking plane.
        for x in (-w / 2 + .09, w / 2 - .09):
            limit = d * (.56 if angled and x > 0 else 1)
            _stone(b, "deck_edge_band", (x, -d / 2 + limit / 2, -h * .48),
                   (.18, limit, h * .96), bevel=min(.025, h * .1))
    b.flag("axis", "walking plane Z=0; thickness below")


def _ring(b, name, w, d, z0, z1, thickness, mat=None, chamfer=.08):
    """Closed octagonal annulus; real open center and four straight contact sides."""
    def perimeter(a, c, k):
        return [(-a / 2 + k, -c / 2), (a / 2 - k, -c / 2),
                (a / 2, -c / 2 + k), (a / 2, c / 2 - k),
                (a / 2 - k, c / 2), (-a / 2 + k, c / 2),
                (-a / 2, c / 2 - k), (-a / 2, -c / 2 + k)]
    outer = perimeter(w, d, min(chamfer, min(w, d) * .2))
    inner = perimeter(w - 2 * thickness, d - 2 * thickness, min(chamfer * .6, thickness * .4))
    v = [(x, y, z) for z in (z0, z1) for p in (outer, inner) for x, y in p]
    f = []
    for i in range(8):
        j = (i + 1) % 8
        f += [(i, j, 16 + j, 16 + i), (8 + j, 8 + i, 24 + i, 24 + j),
              (16 + i, 16 + j, 24 + j, 24 + i), (j, i, 8 + i, 8 + j)]
    return b.mesh(name, v, f, mat)


def _arch(b, w, d, h, shallow=False):
    thickness = w * (.12 if not shallow else .10)
    spring = 0 if shallow else h * .58
    rise = h - spring
    inner_rise = max(.02, rise - thickness)
    if not shallow:
        for x in (-w / 2 + thickness / 2, w / 2 - thickness / 2):
            for row in range(4):
                _stone(b, "arch_jamb", (x, 0, (row + .5) * spring / 4),
                       (thickness * (1.1 if row in (0, 3) else 1), d, spring / 4 - .008))
    n = 9
    for i in range(n):
        a, c = math.pi * i / n + .004, math.pi * (i + 1) / n - .004
        # Radial blocks form an actual opening rather than a closed arch silhouette.
        p = [(w / 2 * math.cos(a), spring + rise * math.sin(a)),
             (w / 2 * math.cos(c), spring + rise * math.sin(c)),
             ((w / 2 - thickness) * math.cos(c), spring + inner_rise * math.sin(c)),
             ((w / 2 - thickness) * math.cos(a), spring + inner_rise * math.sin(a))]
        _profile(b, f"voussoir_{i}", p, d)


def _vault(b, w, d, h):
    """Thin groin-vault shell: faceted crown with four unobstructed open sides."""
    n = 4
    t = h * .23
    verts = []
    for layer in range(2):
        for iy in range(n + 1):
            y = -d / 2 + d * iy / n
            for ix in range(n + 1):
                x = -w / 2 + w * ix / n
                edge = max(abs(2 * x / w), abs(2 * y / d))
                z = (h - t) * (1 - edge * edge) + layer * t
                verts.append((x, y, z))
    stride = (n + 1) ** 2
    faces = []
    for iy in range(n):
        for ix in range(n):
            a = iy * (n + 1) + ix
            q = (a, a + 1, a + n + 2, a + n + 1)
            # A groin crosses each diagonal cell, making its four corners
            # nonplanar. Reversed quads can tessellate onto opposite diagonals
            # at export, so the thin top then cuts through the underside.
            # Explicit matching triangles retain the groin and shell thickness.
            same_quadrant = (ix + .5 - n / 2) * (iy + .5 - n / 2) >= 0
            triangles = ((q[0], q[1], q[2]), (q[0], q[2], q[3])) if same_quadrant else (
                (q[0], q[1], q[3]), (q[1], q[2], q[3]))
            for triangle in triangles:
                faces += [tuple(reversed(triangle)), tuple(v + stride for v in triangle)]
    boundary = list(range(n + 1))
    boundary += [(iy + 1) * (n + 1) + n for iy in range(n)]
    boundary += [n * (n + 1) + ix for ix in reversed(range(n))]
    boundary += [iy * (n + 1) for iy in reversed(range(1, n))]
    for a, c in zip(boundary, boundary[1:] + boundary[:1]):
        faces.append((a, c, c + stride, a + stride))
    b.mesh("groin_vault_open_shell", verts, faces)
    # Keep the rib end caps inside the module; outboard cylinder corners would
    # make envelope fitting shrink the shell itself and leave tile-to-tile gaps.
    corner = min(w, d) * .07
    for x in (-w / 2 + corner / 2, w / 2 - corner / 2):
        for y in (-d / 2 + corner / 2, d / 2 - corner / 2):
            b.box("vault_corner_springer", (x, y, .01), (corner, corner, .14), bevel=.012)
    # Cross ribs follow and penetrate the intrados by a small deliberate amount
    # so their top faces do not float visibly below the shell.
    for sign in ((-1, 1) if b.part.get('vault_ribs', False) else ()):
        for i in range(4):
            a, c = -1 + i / 2, -1 + (i + 1) / 2
            u, v = a * (1 - corner / min(w, d)), c * (1 - corner / min(w, d))
            pa = (u * w / 2, sign * u * d / 2, (h - t) * (1 - u * u) - .025)
            pc = (v * w / 2, sign * v * d / 2, (h - t) * (1 - v * v) - .025)
            b.rod("vault_groin_rib", pa, pc, min(.055, h * .17), sides=4)


def _rock(b, name, w, d, h, center=(0, 0, 0), wedge=False, inverted=False):
    """Three broad polygon rings and a cap; never apex spikes or noisy ico rock."""
    n = 7
    verts = []
    for ring, (z, scale) in enumerate(((0, .86), (.38, 1), (1, .61))):
        for i in range(n):
            angle = 2 * math.pi * i / n
            rough = b.rng.uniform(.88, 1.08)
            x = math.cos(angle) * w / 2 * scale * rough
            y = math.sin(angle) * d / 2 * scale * b.rng.uniform(.88, 1.06)
            zz = z * h
            if ring == 2:
                # Cap spans several broad vertices; sloping wedge stays chunky.
                zz *= (.55 + .45 * (x / w + .5)) if wedge else b.rng.uniform(.84, 1)
                x -= w * .12
            if inverted:
                zz = h - zz
            verts.append((x + center[0], y + center[1], zz + center[2]))
    faces = [tuple(reversed(range(n))), tuple(range(2 * n, 3 * n))]
    for row in range(2):
        for i in range(n):
            j = (i + 1) % n
            a, c = row * n + i, row * n + j
            # A few split broad quads emphasize mineral planes without microfacets.
            faces += [(a, c, c + n), (a, c + n, a + n)]
    if inverted:
        faces = [tuple(reversed(f)) for f in faces]
    return b.mesh(name, verts, faces)


def _cave_panel(b, name, w, d, h, wet=False):
    """Faceted closed skin with exactly flat rear, horizontal top/base join planes."""
    nx, nz = 5, 4
    verts = []
    for iz in range(nz + 1):
        for ix in range(nx + 1):
            x = -w / 2 + w * ix / nx
            z = h * iz / nz
            if ix not in (0, nx) and iz not in (0, nz):
                x += b.rng.uniform(-.065, .065) * w
                z += b.rng.uniform(-.035, .035) * h
            y = -d / 2 + b.rng.uniform(0, .48) * d
            verts.append((x, y, z))
    faces = []
    for iz in range(nz):
        for ix in range(nx):
            a = iz * (nx + 1) + ix
            faces += [(a, a + 1, a + nx + 2), (a, a + nx + 2, a + nx + 1)]
    # Trace front boundary counterclockwise in X/Z and stitch to planar rear.
    boundary = list(range(nx + 1))
    boundary += [(iz + 1) * (nx + 1) + nx for iz in range(nz)]
    boundary += [nz * (nx + 1) + ix for ix in reversed(range(nx))]
    boundary += [iz * (nx + 1) for iz in reversed(range(1, nz))]
    start = len(verts)
    verts += [(verts[i][0], d / 2, verts[i][2]) for i in boundary]
    faces.append(tuple(reversed(range(start, len(verts)))))
    for j, a in enumerate(boundary):
        k = (j + 1) % len(boundary)
        faces.append((boundary[k], a, start + j, start + k))
    obj = b.mesh(name, verts, faces, "TX04" if wet else None)
    if wet:
        # A separate thin low skirt follows broad frontal planes, not amber grunge.
        wet_vertices = []
        for iz in (0, 1):
            for ix in range(nx + 1):
                src = verts[iz * (nx + 1) + ix]
                wet_vertices.append((src[0], src[1] - .006, src[2]))
        b.mesh("waterline_facing", wet_vertices,
               [(ix, ix + 1, nx + 2 + ix, nx + 1 + ix) for ix in range(nx)], "TX17")
    return obj


def _timber(b, w, d, h, diagonal=False):
    if diagonal:
        # Parallel long edges, flat square-cut joints and broad corner chamfers.
        t = min(w, h) * .18
        p = [(-w / 2, 0), (-w / 2 + t, 0), (w / 2, h - t),
             (w / 2, h), (w / 2 - t, h), (-w / 2, t)]
        _profile(b, "diagonal_hewn_timber", p, d, "TX08")
        b.flag('source_sockets_m',{'post_end':[-w/2,0,t/2],'header_end':[w/2-t/2,0,h]})
        for x, z in ((-w * .39, h * .11), (w * .39, h * .89)):
            strap = b.box("brace_front_strap", (x, -d * .54, z), (t * .9, .035, t * 1.5), "TX09", bevel=.015)
            strap.rotation_euler[1] = math.radians(-45)
            for dz in (-t * .25, t * .25):
                b.cyl("brace_strap_pin", (x, -d * .64, z + dz), t * .09, .035, "TX09", axis="Y", sides=8)
    else:
        _stone(b, "hewn_flat_joint_beam", (0, 0, h / 2), (w, d, h), "TX08", bevel=min(d, h) * .1)
        # Long shallow facets suggest hewing rather than a smooth rectangular log.
        for y in (-d * .35, d * .25):
            b.extrude("timber_hewn_top_facet", [(-w * .46, y - .016), (w * .43, y),
                      (w * .40, y + .025), (-w * .44, y + .035)], h - .014, h, "TX08")
    b.flag("axis", "flat structural end joints")


def build(b, part):
    if b.id not in OWNED:
        raise ValueError(f"architecture does not own {b.id}")
    n = int(b.id[3:])
    w, d, h = b.size
    if n in (1, 2, 13, 14):
        _paving(b, w, d, h, angled=n == 2, border=n in (1, 2))
    elif n == 3:
        # Chamfered side stones hang below the deck contact plane.
        for i in range(3):
            _stone(b, "fascia_stone", (-w / 2 + (i + .5) * w / 3, 0, -h / 2),
                   (w / 3 - .008, d, h), bevel=min(d * .18, .04))
    elif n == 4:
        _arch(b, w, d, h, shallow=True)
    elif n == 5:
        _block_courses(b, w * .8, d * .76, h, rows=5, cols=3, y=d * .12)
        for x in (-w * .4, w * .4):
            _rock(b, "abutment_rock_interface", w * .3, d, h * .78, (x, 0, 0), wedge=True)
        _stone(b, "abutment_coping", (0, 0, h * .94), (w, d, h * .12))
    elif n == 6:
        # Three exposed sides leave the rear open against the retained support.
        for row in range(5):
            z = (row + .5) * h / 5
            _stone(b, "pier_front_half_shell", (0, -d * .38, z), (w, d * .24, h / 5 - .012))
            for x in (-w * .38, w * .38):
                _stone(b, "pier_return_half_shell", (x, d * .08, z), (w * .24, d * .7, h / 5 - .012))
    elif n == 7:
        _ring(b, "wet_pier_collar", w, d, 0, h, min(w, d) * .13, chamfer=min(w, d) * .16)
    elif n == 8:
        for i in range(3):
            x = -w / 2 + (i + .5) * w / 3
            _stone(b, "coping_rolled_cap", (x, 0, h * .72), (w / 3 - .008, d, h * .56))
            _stone(b, "coping_neck", (x, d * .06, h * .24), (w / 3 - .008, d * .76, h * .48))
    elif n in (9, 12, 16):
        _stone(b, "post_plinth", (0, 0, h * .08), (w, d, h * .16))
        _block_courses(b, w * .8, d * .8, h * .74, rows=4, cols=1, z0=h * .16)
        _stone(b, "post_crown", (0, 0, h * .95), (w, d, h * .1))
        if n == 12:
            b.box("terminal_anchor_plate", (0, -d * .43, h * .68), (w * .65, d * .12, h * .25), "TX09", bevel=.018)
            b.torus("fixed_rail_anchor_eye", (0, -d * .62, h * .68), w * .19, w * .045, "TX09", axis="Y", major_segments=8)
    elif n == 10:
        _stone(b, "broad_post_cap", (0, 0, h * .67), (w, d, h * .66), bevel=h * .2)
        _stone(b, "cap_register", (0, 0, h * .17), (w * .78, d * .78, h * .34))
    elif n == 11:
        # Fixed safety infill, deliberately straight and distinct from control chains.
        for z in (h * .13, h * .89):
            b.box("fixed_iron_horizontal", (0, 0, z), (w, d * .5, h * .09), bevel=.014)
        for i in range(7):
            x = -w / 2 + i * w / 6
            b.box("fixed_rail_upright", (x, 0, h * .5), (d * .45, d * .65, h), bevel=.012)
    elif n == 15:
        _block_courses(b, w, d, h, rows=5, cols=3)
    elif n == 17:
        _arch(b, w, d, h)
    elif n == 18:
        _vault(b, w, d, h)
    elif n == 19:
        p = [(-w / 2, .02 * h), (-.24 * w, 0), (.05 * w, .045 * h), (.42 * w, .02 * h),
             (w / 2, .3 * h), (.44 * w, .55 * h), (w / 2, .91 * h), (.31 * w, h),
             (.08 * w, .97 * h), (-.2 * w, h), (-w / 2, .92 * h), (-.46 * w, .59 * h)]
        _profile(b, "chipped_shallow_plaster", p, d)
    elif n == 20:
        # Profiled nosing/rebate; the contact top stays flush at zero.
        p = [(-d / 2, -h), (d / 2, -h), (d / 2, 0), (-d / 2, 0),
             (-d / 2, -h * .2), (-d * .12, -h * .28), (-d * .12, -h * .63),
             (-d / 2, -h * .72)]
        # XZ profile helper rotated so its extrusion becomes the threshold width.
        ob = _profile(b, "rebated_threshold_fascia", p, w)
        ob.rotation_euler[2] = math.pi / 2
    elif n in (43, 44):
        _rock(b, "broad_bank_rock" if n == 43 else "asymmetric_seam_wedge", w, d, h, wedge=n == 44)
    elif n in (45, 48, 49):
        _cave_panel(b, "wet_bank_skin" if n == 48 else "broad_cave_face", w, d, h, wet=n == 48)
    elif n == 46:
        # Two perpendicular flat-backed returns form a true concave corner.
        thickness = min(w, d) * .22
        _cave_panel(b, "corner_back_return", w, thickness, h).location.y = d / 2 - thickness / 2
        side = _cave_panel(b, "corner_side_return", d - thickness, thickness, h)
        side.rotation_euler[2] = -math.pi / 2
        side.location.x = -w / 2 + thickness / 2
        side.location.y = -thickness / 2
    elif n == 47:
        _rock(b, "broad_underside_roof_cap", w, d, h, inverted=True)
    elif n == 50:
        for i in range(7):
            rw = w * b.rng.uniform(.14, .22)
            rd = d * b.rng.uniform(.65, 1)
            rh = h * b.rng.uniform(.5, 1)
            _rock(b, f"toe_rock_{i}", rw, rd, rh,
                  (-w * .43 + i * w * .14, b.rng.uniform(-.08, .08) * d, 0), wedge=i % 2 == 0)
    elif n in (86, 87):
        _timber(b, w, d, h, diagonal=n == 87)
    elif n == 88:
        # Shallow recess and real iron gaps, entirely below the retained floor.
        rim = min(w, d) * .15
        _ring(b, "recessed_drain_stone_rim", w, d, -h, 0, rim, "TX01", chamfer=.035)
        _ring(b, "iron_grille_frame", w - 2 * rim, d - 2 * rim, -h * .35, -.008,
              min(w, d) * .055, "TX09", chamfer=.015)
        inner_w, inner_d = w - 2 * rim, d - 2 * rim
        for i in range(5):
            x = -inner_w / 2 + (i + 1) * inner_w / 6
            b.box("grille_bar", (x, 0, -h * .19), (w * .035, inner_d * .93, h * .22), "TX09", bevel=.006)
        b.box("shallow_drain_recess", (0, 0, -h + .009), (w - rim, d - rim, .018), "TX17", bevel=0)
        for x in (-inner_w * .39, inner_w * .39):
            for y in (-inner_d * .39, inner_d * .39):
                b.cyl("grille_frame_pin", (x, y, -.006), w * .014, .009, "TX09", sides=8)
        b.flag("axis", "flush rim Z=0; shallow recessed grille below floor")
