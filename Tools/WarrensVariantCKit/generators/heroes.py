"""Separate Warrens hero skins. Metres, Z up, neutral front -Y.

The source 22m tower is assembled from H06 modules by the placement driver;
this module never invents an entire tower, a mover, collision or gameplay.
"""

from math import cos, sin, pi


OWNED_SOURCE_IDS = {f"H{i:02d}" for i in range(1, 13)} | {"H14", "H15", "H15_Lid"}
OWNED = OWNED_SOURCE_IDS


def _radial_point(radius, angle, along, axis, center):
    x, y, z = center
    if axis == "Y":
        return x + radius * cos(angle), y + along, z + radius * sin(angle)
    return x + radius * cos(angle), y + radius * sin(angle), z + along


def _profile_ring(b, name, profile, mat, axis="Z", center=(0, 0, 0), sides=12):
    """Revolve a closed radius/axis profile, preserving its real open bore."""
    verts = [_radial_point(r, 2 * pi * i / sides, z, axis, center)
             for r, z in profile for i in range(sides)]
    faces = []
    for k in range(len(profile)):
        a, c = k * sides, ((k + 1) % len(profile)) * sides
        for i in range(sides):
            j = (i + 1) % sides
            face = (a + i, a + j, c + j, c + i)
            faces.append(tuple(reversed(face)) if axis == "Y" else face)
    return b.mesh(name, verts, faces, mat)


def _annulus(b, name, radius, bore, depth, mat, axis="Z", center=(0, 0, 0), sides=12):
    return _profile_ring(b, name, [(radius, -depth / 2), (radius, depth / 2),
                                  (bore, depth / 2), (bore, -depth / 2)],
                         mat, axis, center, sides)


def _prism(b, name, outline, y0, y1, mat):
    """Extrude an XZ polygon through Y; no Boolean dependencies."""
    n = len(outline)
    verts = [(x, y, z) for y in (y0, y1) for x, z in outline]
    faces = [tuple(range(n)), tuple(reversed(range(n, n * 2)))]
    faces += [(i + n, (i + 1) % n + n, (i + 1) % n, i) for i in range(n)]
    return b.mesh(name, verts, faces, mat)


def _beam(b, name, start, end, thickness, mat):
    """Square timber between endpoints, with its local ends perpendicular."""
    vx, vy, vz = (end[k] - start[k] for k in range(3))
    length = (vx * vx + vy * vy + vz * vz) ** 0.5
    direction = (vx / length, vy / length, vz / length)
    guide = (0, 1, 0) if abs(direction[1]) < .9 else (1, 0, 0)
    side = (direction[1] * guide[2] - direction[2] * guide[1],
            direction[2] * guide[0] - direction[0] * guide[2],
            direction[0] * guide[1] - direction[1] * guide[0])
    norm = sum(v * v for v in side) ** .5
    side = tuple(v / norm for v in side)
    up = (direction[1] * side[2] - direction[2] * side[1],
          direction[2] * side[0] - direction[0] * side[2],
          direction[0] * side[1] - direction[1] * side[0])
    verts = [tuple(p[k] + thickness / 2 * (a * side[k] + c * up[k]) for k in range(3))
             for p in (start, end) for a, c in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    faces = [(3, 2, 1, 0), (4, 5, 6, 7)]
    faces += [(i, (i + 1) % 4, (i + 1) % 4 + 4, i + 4) for i in range(4)]
    return b.mesh(name, verts, faces, mat)


def _bell(b, w, d, h, mat):
    """Watertight bell wall, with a hollow cavity open below its annular lip."""
    sides = 12
    outer = [(1.0, 0), (.99, .075), (.86, .13), (.73, .34),
             (.62, .66), (.48, .86), (.29, .96), (.2, 1.0)]
    inner = [(.89, .025), (.88, .075), (.76, .13), (.63, .34),
             (.52, .66), (.38, .84), (.21, .9)]
    verts = [(cos(2 * pi * i / sides) * w / 2 * r,
              sin(2 * pi * i / sides) * d / 2 * r, z * h)
             for r, z in outer + inner for i in range(sides)]
    faces = []
    for start, count, inside in ((0, len(outer), False), (len(outer), len(inner), True)):
        for k in range(start, start + count - 1):
            for i in range(sides):
                j = (i + 1) % sides
                f = (k * sides + i, k * sides + j, (k + 1) * sides + j, (k + 1) * sides + i)
                faces.append(tuple(reversed(f)) if inside else f)
    offset = len(outer) * sides
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((i, offset + i, offset + j, j))
    faces.append(tuple(range((len(outer) - 1) * sides, len(outer) * sides)))
    faces.append(tuple(reversed(range((len(outer) + len(inner) - 1) * sides,
                                      (len(outer) + len(inner)) * sides))))
    b.mesh("hollow_landmark_bell_shell", verts, faces, mat)


def _hoist_frame(b, w, d, h, wood, iron):
    leg = min(w, d) * .14
    for x in (-w * .37, w * .37):
        for y in (-d * .37, d * .37):
            b.box("hoist_leg", (x, y, h * .48), (leg, leg, h * .96), wood, bevel=.022)
            b.box("hoist_foot_band", (x, y, h * .035), (leg * 1.16, leg * 1.16, h * .07), iron)
            b.box("hoist_shoulder_band", (x, y, h * .91), (leg * 1.1, leg * 1.1, h * .035), iron)
    for y in (-d * .37, d * .37):
        b.box("hoist_header", (0, y, h * .965), (w, leg, h * .07), wood)
        for side in (-1, 1):
            _beam(b, "hoist_upper_knee_brace", (side * w * .35, y, h * .78),
                  (side * w * .12, y, h * .93), leg * .65, wood)
    for x in (-w * .37, w * .37):
        b.box("hoist_depth_tie", (x, 0, h * .93), (leg, d, leg), wood)
        for side in (-1, 1):
            _beam(b, "hoist_side_knee_brace", (x, side * d * .35, h * .79),
                  (x, side * d * .12, h * .92), leg * .62, wood)
    b.flag("open_load_space", True)
    b.flag("separate_parts", "H02 pulley; H03 drum; H04 hook; H05 cage; no baked ropes")


def _crown(b, w, d, h, stone, brass):
    # Four corner piers and four open arches; no solid central roof/floor cap.
    p = min(w, d) * .13
    for x in (-w * .435, w * .435):
        for y in (-d * .435, d * .435):
            for k in range(5):
                b.box("crown_corner_pier_course", (x, y, h * (k + .5) / 5),
                      (p, p, h / 5 - .009), stone, bevel=.025)
            b.box("crown_pier_cap", (x, y, h * .94), (p * 1.05, p * 1.05, h * .12), stone)
    spring = h * .67
    # Arch strips are wedges between sampled inner/outer semicircles.
    rx, rz, thick = w * .37, h * .22, h * .085
    for y in (-d * .435, d * .435):
        for i in range(8):
            a, c = pi * i / 8, pi * (i + 1) / 8
            pts = [(rx * cos(a), spring + rz * sin(a)),
                   ((rx + thick) * cos(a), spring + (rz + thick) * sin(a)),
                   ((rx + thick) * cos(c), spring + (rz + thick) * sin(c)),
                   (rx * cos(c), spring + rz * sin(c))]
            _prism(b, "crown_front_arch_voussoir", pts, y - p * .45, y + p * .45, stone)
    # Side arches use directly rotated vertex coordinates, without object transforms.
    for x in (-w * .435, w * .435):
        for i in range(8):
            a, c = pi * i / 8, pi * (i + 1) / 8
            yz = [(d * .37 * cos(a), spring + rz * sin(a)),
                  ((d * .37 + thick) * cos(a), spring + (rz + thick) * sin(a)),
                  ((d * .37 + thick) * cos(c), spring + (rz + thick) * sin(c)),
                  (d * .37 * cos(c), spring + rz * sin(c))]
            verts = [(xx, y, z) for xx in (x - p * .45, x + p * .45) for y, z in yz]
            b.mesh("crown_side_arch_voussoir", verts,
                   [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5),
                    (2, 3, 7, 6), (3, 0, 4, 7)], stone)
    for y in (-d * .435, d * .435):
        b.box("crown_quiet_brass_tie", (0, y, h * .965), (w * .72, p * .35, .035), brass)
    b.flag("clear_apertures", "four open sides; no central roof or floor")
    b.flag("module_only", "4m crown; 22m tower assembly belongs to placement driver")


def _mourner(b, w, d, h, stone, bone):
    b.box("mourner_plinth", (0, 0, h * .035), (w, d, h * .07), stone, bevel=.035)
    b.box("mourner_upper_base", (0, 0, h * .09), (w * .79, d * .82, h * .045), stone)
    for side in (-1, 1):
        # Broad split robe planes create an asymmetric pointed hem and real center gap.
        outline = [(side * w * .055, h * .15), (side * w * .36, h * .28),
                   (side * w * .34, h * .71), (side * w * .14, h * .84),
                   (side * w * .075, h * .74)]
        if side < 0:
            outline.reverse()
        _prism(b, "mourner_split_robe", outline, -d * .25, d * .28, stone)
        b.box("mourner_foot", (side * w * .16, -d * .02, h * .15),
              (w * .16, d * .35, h * .1), bone)
        b.cone("mourner_lower_fold", (side * w * .14, d * .08, h * .28),
               w * .09, w * .045, h * .25, stone, sides=5)
    # Open faceless hood consists of a rear plane and two sloping cheeks.
    b.mesh("mourner_hood", [(-w * .12, d * .04, h * .77), (w * .12, d * .04, h * .77),
                            (-w * .08, d * .12, h * .94), (w * .08, d * .12, h * .94),
                            (0, -d * .1, h), (-w * .12, -d * .28, h * .84),
                            (w * .12, -d * .28, h * .84), (0, -d * .29, h * .94)],
           [(0, 1, 3, 2), (2, 3, 4), (0, 2, 4, 7, 5), (1, 6, 7, 4, 3)], bone)
    b.flag("silhouette", "faceless bowed hood; separated robe halves; no face or glyph")


def build(b, part):
    source = part.get("source_id", "")
    if source not in OWNED_SOURCE_IDS:
        raise ValueError(f"heroes does not own {source or b.id}")
    w, d, h = b.size
    first, second = b.mat(0), b.mat(1)
    b.flag("moving_part", False)
    b.flag("source_id", source)

    if source == "H01":
        _hoist_frame(b, w, d, h, first, second)
        b.flag("source_sockets_m", {"pulley_axle": [0, 0, h * .87], "drum_axle": [0, 0, h * .1]})

    elif source == "H02":
        radius = min(w, h) / 2
        _annulus(b, "pulley_outer_wood_sheave", radius, radius * .64, d * .57,
                 first, "Y", sides=12)
        for side in (-1, 1):
            _annulus(b, "pulley_rope_retaining_rim", radius, radius * .82, d * .14,
                     second, "Y", (0, side * d * .4, 0), 12)
        b.cyl("pulley_hub", (0, 0, 0), radius * .18, d, second, axis="Y", sides=12)
        for i in range(6):
            a = 2 * pi * i / 6
            _beam(b, "pulley_broad_spoke", (0, 0, 0),
                  (radius * .8 * cos(a), 0, radius * .8 * sin(a)), radius * .11, first)
        b.flag("axis", "Y")
        b.flag("pivot_contract", "axle center; preserve Y rotation; no static bracket baked")
        b.flag("source_sockets_m", {"axle_center": [0, 0, 0],
                                    "rope_left": [-radius * .83, 0, 0],
                                    "rope_right": [radius * .83, 0, 0]})

    elif source == "H03":
        radius = min(w, h) / 2
        b.cyl("wood_rope_drum", (0, 0, 0), radius * .73, d * .78, first, axis="Y", sides=12)
        for side in (-1, 1):
            _annulus(b, "drum_flange", radius, radius * .2, d * .1,
                     second, "Y", (0, side * d * .41, 0), 12)
            b.cyl("drum_axle_end", (0, side * d * .46, 0), radius * .17, d * .08,
                  second, axis="Y", sides=10)
        for i in range(5):
            _annulus(b, "rope_slot_ridge", radius * .75, radius * .71, d * .04,
                     first, "Y", (0, (i - 2) * d * .12, 0), 12)
        b.flag("axis", "Y")
        b.flag("pivot_contract", "axle center; cosmetic until an existing owner supplies motion")
        b.flag("source_sockets_m", {"axle_center": [0, 0, 0], "rope_tangent": [0, 0, radius * .75]})

    elif source == "H04":
        # Solid J profile, with an open throat between the right tip and upper stem.
        outline = [(-w * .19, h * .81), (-w * .2, h * .38), (-w * .39, h * .25),
                   (-w * .38, h * .1), (-w * .21, 0), (w * .16, 0),
                   (w * .42, h * .14), (w * .48, h * .35), (w * .3, h * .49),
                   (w * .28, h * .27), (w * .12, h * .16), (-w * .09, h * .17),
                   (-w * .19, h * .27), (-w * .01, h * .38), (w * .02, h * .81)]
        _prism(b, "open_J_hook", outline, -d / 2, d / 2, first)
        _annulus(b, "hook_suspension_eye", w * .19, w * .09, d * .7,
                 first, "Y", (-w * .08, 0, h * .89), 10)
        b.flag("open_throat", True)
        b.flag("source_sockets_m", {"suspension_eye": [-w * .08, 0, h * .89],
                                    "hook_load": [0, 0, h * .16]})

    elif source == "H05":
        b.box("cage_wood_floor", (0, 0, h * .04), (w, d, h * .08), first)
        for z in (h * .1, h * .7):
            for side in (-1, 1):
                b.box("cage_front_back_rail", (0, side * d * .46, z), (w, d * .08, h * .07), first)
                b.box("cage_side_rail", (side * w * .46, 0, z), (w * .08, d, h * .07), first)
        for side in (-1, 1):
            for i in range(5):
                t = -.44 + i * .22
                b.box("cage_front_back_bar", (w * t, side * d * .46, h * .4),
                      (w * .035, d * .045, h * .62), second, bevel=.008)
                if i not in (0, 4):
                    b.box("cage_side_bar", (side * w * .46, d * t, h * .4),
                          (w * .045, d * .035, h * .62), second, bevel=.008)
        for x in (-w * .43, w * .43):
            for y in (-d * .43, d * .43):
                _beam(b, "cage_suspension_brace", (x, y, h * .72), (0, 0, h * .94), w * .045, first)
        _annulus(b, "cage_top_eye", w * .055, w * .027, d * .06,
                 second, "Y", (0, 0, h * .95), 10)
        b.flag("open_cage", True)
        b.flag("cosmetic_only", "no elevator behavior or physics")
        b.flag("source_sockets_m", {"suspension_eye": [0, 0, h * .95]})

    elif source == "H06":
        _crown(b, w, d, h, first, second)
        b.flag("source_sockets_m", {"aperture_center": [0, 0, h * .48], "yoke_axle": [0, 0, h * .84]})

    elif source == "H07":
        _bell(b, w, d, h, first)
        b.flag("hollow_open_mouth", True)
        b.flag("separate_parts", "H08 yoke and H09 clapper are not joined to this shell")
        b.flag("pivot_contract", "bottom lip center; assembly adapter must retain separate yoke axle")
        b.flag("source_sockets_m", {"crown_attachment": [0, 0, h],
                                    "clapper_hinge": [0, 0, h * .9], "mouth_center": [0, 0, 0]})

    elif source == "H08":
        # Front elevation XZ; the declared source axle remains local Y.
        outline = [(-w / 2, -h * .5), (-w * .4, -h * .5), (-w * .32, h * .14),
                   (w * .32, h * .14), (w * .4, -h * .5), (w / 2, -h * .5),
                   (w * .42, h * .5), (-w * .42, h * .5)]
        _prism(b, "bowed_timber_yoke", outline, -d * .35, d * .35, first)
        for x in (-w * .4, w * .4):
            b.box("yoke_axle_strap", (x, 0, 0), (w * .075, d * .8, h * .7), second)
        b.cyl("single_continuous_yoke_axle", (0, 0, 0), h * .12, d, second, axis="Y", sides=10)
        b.box("yoke_center_axle_saddle", (0, 0, h * .11), (w * .12, d * .4, h * .3), second)
        b.flag("axis", "Y")
        b.flag("pivot_contract", "yoke axle center; symmetric vertical bounds retain axle after finish")
        b.flag("authored_axle_z_fraction_of_bounds", .5)
        b.flag("source_sockets_m", {"axle_center": [0, 0, 0],
                                    "axle_front": [0, -d / 2, 0], "axle_back": [0, d / 2, 0],
                                    "bell_attachment": [0, 0, -h * .14]})

    elif source == "H09":
        # Overall top is Z=0; hinge center sits one eye radius below that.
        # Exact -h..0 bounds keep the adapter valid after bottom-center finish.
        _annulus(b, "clapper_open_hinge_eye", w * .32, w * .15, d * .45,
                 first, "Y", (0, 0, -w * .32), 12)
        b.rod("clapper_shank", (0, 0, -w * .56), (0, 0, -h * .75), w * .12, first, sides=8)
        b.cone("clapper_strike_lower", (0, 0, -h * .91), w * .27, w * .5, h * .18, first, sides=8)
        b.cone("clapper_strike_upper", (0, 0, -h * .745), w * .5, w * .15, h * .15, first, sides=8)
        b.flag("axis", "Y")
        b.flag("pivot_contract", "top hinge; align final flags.sockets_m.hinge_center to existing hinge node")
        b.flag("no_simulation", True)
        b.flag("source_sockets_m", {"hinge_center": [0, 0, -w * .32],
                                    "strike_center": [0, 0, -h * .84]})

    elif source == "H10":
        # Built as a blunt brow/cheek/jaw assembly. The eyes are recessed voids.
        brow = [(-w * .49, h * .61), (-w * .34, h * .91), (0, h),
                (w * .34, h * .91), (w * .49, h * .61), (w * .25, h * .65),
                (0, h * .57), (-w * .25, h * .65)]
        _prism(b, "skull_brow", brow, -d * .34, d * .42, first)
        for side in (-1, 1):
            pts = [(side * w * .45, h * .63), (side * w * .48, h * .26),
                   (side * w * .27, h * .16), (side * w * .2, h * .43)]
            if side < 0:
                pts.reverse()
            _prism(b, "skull_blunt_cheek", pts, -d * .38, d * .3, first)
        b.box("skull_backing", (0, d * .34, h * .58), (w * .7, d * .18, h * .58), first)
        b.box("skull_blunt_jaw", (0, -d * .1, h * .12), (w * .48, d * .65, h * .24), first)
        _prism(b, "skull_nasal_bridge", [(-w * .07, h * .44), (w * .07, h * .44),
                                         (0, h * .65)], -d * .5, -d * .16, first)
        b.flag("stylized_skull", "blunt eye hollows; no teeth field or glyph")

    elif source == "H11":
        # Horizontal mill, as MODEL06: separate broad stone rings around an open axle bore.
        radius = min(w, d) * .48
        _profile_ring(b, "octagonal_grinding_drum", [(radius * .95, h * .12),
                      (radius, h * .2), (radius, h * .7), (radius * .95, h * .78),
                      (radius * .17, h * .78), (radius * .17, h * .12)], first, sides=8)
        for z in (h * .18, h * .69):
            _annulus(b, "mill_wood_binding_band", radius * 1.02, radius * .96,
                     h * .06, second, center=(0, 0, z), sides=8)
        for i in range(8):
            a = 2 * pi * i / 8
            b.box("mill_vertical_timber_clamp", (radius * .92 * cos(a), radius * .92 * sin(a), h * .43),
                  (w * .055, d * .055, h * .76), second)
        b.flag("axis", "Z")
        b.flag("open_axle_bore", True)
        b.flag("separate_parts", "central axle and chute are separate attachment parts; not baked")
        b.flag("source_sockets_m", {"bore_bottom": [0, 0, h * .12], "bore_top": [0, 0, h * .78]})

    elif source == "H12":
        # Open sloping trough runs along X. No hopper or new walkable surface.
        floor = [(-w / 2, h * .82), (w / 2, h * .08), (w / 2, h * .18), (-w / 2, h * .92)]
        _prism(b, "chute_sloping_bed", floor, -d * .4, d * .4, first)
        wall = [(-w / 2, h * .82), (w / 2, h * .08), (w / 2, h * .35), (-w / 2, h)]
        for side in (-1, 1):
            y = side * d * .45
            _prism(b, "chute_open_sidewall", wall, y - d * .05, y + d * .05, first)
        salt = [(-w * .44, h * .895), (w * .44, h * .244),
                (w * .44, h * .259), (-w * .44, h * .91)]
        _prism(b, "chute_thin_coarse_salt_insert", salt, -d * .31, d * .31, second)
        b.box("chute_support_foot", (-w * .22, 0, h * .04), (w * .2, d * .68, h * .08), first)
        _beam(b, "chute_under_support", (-w * .22, 0, h * .08), (-w * .22, 0, h * .64), d * .18, first)
        b.flag("open_channel", True)
        b.flag("source_sockets_m", {"inlet": [-w / 2, 0, h * .94], "outlet": [w / 2, 0, h * .21]})

    elif source == "H14":
        _mourner(b, w, d, h, first, second)

    elif source == "H15":
        b.box("tomb_bottom_slab", (0, 0, h * .09), (w, d, h * .18), first, bevel=.025)
        for side in (-1, 1):
            b.box("tomb_long_wall", (0, side * d * .43, h * .55),
                  (w * .92, d * .14, h * .74), first, bevel=.02)
            b.box("tomb_end_wall", (side * w * .45, 0, h * .55),
                  (w * .1, d * .78, h * .74), first, bevel=.02)
            b.box("tomb_long_open_rim", (0, side * d * .43, h * .96),
                  (w, d * .14, h * .08), first, bevel=.018)
            b.box("tomb_end_open_rim", (side * w * .46, 0, h * .96),
                  (w * .08, d * .72, h * .08), first, bevel=.018)
            for x in (-w * .39, w * .39):
                b.box("tomb_corner_pilaster", (x, side * d * .44, h * .5),
                      (w * .07, d * .13, h * .75), first)
                b.box("tomb_quiet_corner_tab", (x, side * d * .51, h * .78),
                      (w * .035, d * .025, h * .08), second, bevel=.004)
        b.flag("open_interior", True)
        b.flag("separate_lid_source_id", "H15_Lid")
        b.flag("source_sockets_m", {"lid_seat": [0, 0, h]})

    elif source == "H15_Lid":
        b.box("tomb_lid_slab", (0, 0, h * .34), (w, d, h * .68), first, bevel=.025)
        # Broad beveled raised plane, without handles/glyphs/new interactions.
        b.box("tomb_lid_raised_face", (0, 0, h * .78), (w * .93, d * .86, h * .44), first, bevel=.035)
        b.flag("separate_part", "H15 sarcophagus lid; position closed or leaned only per source recipe")
        b.flag("production_pivot", "bottom center")
        b.flag("source_sockets_m", {"underside_center": [0, 0, 0]})
