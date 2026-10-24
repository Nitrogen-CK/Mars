"""CCS21--42: separate low-poly mechanism skins, with no gameplay hookup.

Neutral wheels face -Y. Their source actor rotates around local +X, so the
attachment adapter is +90 degrees about Z (mesh -Y becomes actor +X).
Those axis/adapter flags describe neutral Blender space only. Legacy Unreal FBX
import reflects Y: the imported mesh faces +Y and needs yaw -90deg for actor +X.
The importer writes the native adapter into Unreal metadata. Do not rotate grips.
"""

from math import cos, sin, pi, sqrt


OWNED_IDS = {f"CCS{i:02d}" for i in range(21, 43)}


def _point(center, u, v, depth, axis):
    x, y, z = center
    if axis == "Y":
        return x + u, y + depth, z + v
    if axis == "X":
        return x + depth, y + u, z + v
    return x + u, y + v, z + depth


def _ring(b, name, center, rx, ry, tube, depth, mat, axis="Y", segments=16):
    """Closed elliptical annulus with an eight-sided broad bevel section.

    rx/ry describe the centerline; tube is the in-plane half thickness.
    There are no center caps: every ring retains a real through-opening.
    """
    cut = min(tube * 0.35, depth * 0.18)
    section = ((tube - cut, -depth / 2), (tube, -depth / 2 + cut),
               (tube, depth / 2 - cut), (tube - cut, depth / 2),
               (-tube + cut, depth / 2), (-tube, depth / 2 - cut),
               (-tube, -depth / 2 + cut), (-tube + cut, -depth / 2))
    verts = []
    for i in range(segments):
        t = 2 * pi * i / segments
        nx, ny = cos(t) / rx, sin(t) / ry
        length = sqrt(nx * nx + ny * ny)
        nx, ny = nx / length, ny / length
        for radial, axial in section:
            verts.append(_point(center, rx * cos(t) + nx * radial,
                                ry * sin(t) + ny * radial, axial, axis))
    faces = []
    for i in range(segments):
        for j in range(8):
            faces.append((i * 8 + j, ((i + 1) % segments) * 8 + j,
                          ((i + 1) % segments) * 8 + (j + 1) % 8,
                          i * 8 + (j + 1) % 8))
    # _point's X/Z bases preserve orientation, Y's basis reverses it.
    if axis == "Y":
        faces = [tuple(reversed(f)) for f in faces]
    return b.mesh(name, verts, faces, mat)


def _prism_xz(b, name, outline, y0, y1, mat):
    """Solid polygon in the front plane, extruded through depth."""
    n = len(outline)
    verts = [(x, y, z) for y in (y0, y1) for x, z in outline]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    faces.extend((i + n, (i + 1) % n + n, (i + 1) % n, i)
                 for i in range(n))
    return b.mesh(name, verts, faces, mat)


def _bolt(b, name, x, y, z, radius=0.018, depth=0.018, axis="Y", mat=None):
    b.cyl(name, (x, y, z), radius, depth, mat, axis=axis, sides=6)


def _channel(b, name, length, width, height, mat, vertical=False):
    """Open U channel: no cap across its functional opening."""
    wall = min(width * 0.18, 0.045)
    if vertical:
        # Opens toward +X, accepting the separate gate leaf edge.
        b.box(name + "_web", (-width / 2 + wall / 2, 0, length / 2),
              (wall, height, length), mat, bevel=0.004)
        for side in (-1, 1):
            b.box(name + "_lip", (0, side * (height - wall) / 2, length / 2),
                  (width, wall, length), mat, bevel=0.004)
    else:
        b.box(name + "_bed", (0, 0, wall / 2), (length, width, wall), mat)
        for side in (-1, 1):
            b.box(name + "_rail", (0, side * (width - wall) / 2, height / 2),
                  (length, wall, height), mat, bevel=0.008)


def _axis_flags(b, moving=False):
    b.flag("axis", "+X")
    b.flag("mesh_axis", "-Y")
    b.flag("mesh_adapter", "+90deg about Z: mesh -Y -> actor +X; preserve source Grip_L/Grip_R")
    b.flag("moving_part", moving)


def build(b, part):
    """Build only the catalog mechanism family into the current collection."""
    ident = b.id
    if ident not in OWNED_IDS:
        raise ValueError(f"mechanisms does not own {ident}")
    w, d, h = b.size
    iron = b.material("TX09")
    stone = b.material("TX01")
    b.flag("moving_part", False)

    if ident == "CCS21":
        # 50cm outside diameter, 5cm depth. Spokes terminate under the rim.
        _axis_flags(b, True)
        radius = w / 2
        _ring(b, "handwheel_open_rim", (0, 0, 0), radius - 0.022,
              h / 2 - 0.022, 0.022, d, iron, segments=16)
        b.cyl("wheel_hub", (0, 0, 0), 0.061, d, iron, axis="Y")
        for i in range(5):
            a = pi / 2 + 2 * pi * i / 5
            # Rectangular broad spokes, with deliberately quiet planar faces.
            width = 0.018
            near, far = 0.045, radius - 0.023
            ux, uz = cos(a), sin(a)
            vx, vz = -uz * width, ux * width
            p = [(near * ux + vx, near * uz + vz),
                 (near * ux - vx, near * uz - vz),
                 (far * ux - vx, far * uz - vz),
                 (far * ux + vx, far * uz + vz)]
            _prism_xz(b, "wheel_spoke", p, -d * 0.32, d * 0.32, iron)

    elif ident == "CCS22":
        _axis_flags(b, True)
        b.cyl("continuous_axle", (0, 0, 0), w * 0.28, d, iron, axis="Y")
        b.cyl("axle_collar", (0, -d * 0.29, 0), w / 2, d * 0.1, iron, axis="Y")
        b.cyl("axle_end", (0, -d * 0.44, 0), w * 0.34, d * 0.12, iron, axis="Y")

    elif ident == "CCS23":
        _axis_flags(b)
        # Pedestal envelope remains a presentation shell; attachment is fitted later.
        b.box("pedestal_foot", (0, 0, -h * 0.42), (w, d, h * 0.16), stone, bevel=0.035)
        profile = [(-w * 0.38, -h * 0.35), (w * 0.38, -h * 0.35),
                   (w * 0.26, -h * 0.12), (w * 0.26, h * 0.35),
                   (w * 0.1, h * 0.5), (-w * 0.26, h * 0.42),
                   (-w * 0.26, -h * 0.12)]
        _prism_xz(b, "shouldered_stone_housing", profile, -d * 0.24, d * 0.24, stone)
        _ring(b, "open_axle_socket", (0, -d * 0.3, h * 0.13),
              0.12, 0.12, 0.035, d * 0.16, iron)

    elif ident == "CCS24":
        _axis_flags(b)
        b.flag("hookup", "static cosmetic drum; no added mover")
        b.cyl("drum_barrel", (0, 0, 0), w * 0.4, d * 0.86, iron, axis="Y", sides=16)
        for side in (-1, 1):
            b.cyl("drum_flange", (0, side * d * 0.455, 0), w / 2,
                  d * 0.09, iron, axis="Y", sides=16)
            b.cyl("drum_hub", (0, side * d * 0.485, 0), w * 0.14,
                  d * 0.03, iron, axis="Y")
        for y in (-0.2 * d, 0, 0.2 * d):
            _ring(b, "broad_chain_groove_ridge", (0, y, 0), w * 0.4,
                  w * 0.4, 0.013, 0.025, iron)

    elif ident == "CCS25":
        _axis_flags(b)
        b.box("bearing_foot", (0, 0, -h * 0.4), (w, d, h * 0.2), iron)
        _ring(b, "bearing_open_bore", (0, 0, h * 0.08), w * 0.31,
              w * 0.31, w * 0.14, d * 0.82, iron, segments=12)
        for side in (-1, 1):
            b.box("bearing_bolted_lug", (side * w * 0.37, 0, -h * 0.16),
                  (w * 0.22, d * 0.85, h * 0.32), iron, bevel=0.008)
            _bolt(b, "bearing_lug_bolt", side * w * 0.37, 0, 0,
                  radius=w * 0.06, axis="Z", mat=iron)

    elif ident == "CCS26":
        outline = [(-w / 2, 0), (w / 2, 0), (w / 2, h * 0.7),
                   (w * 0.16, h), (-w * 0.18, h), (-w / 2, h * 0.7)]
        _prism_xz(b, "closed_pawl_cover", outline, -d * 0.45, d * 0.45, iron)
        b.box("cover_bottom_band", (0, 0, h * 0.08), (w, d, h * 0.16), iron)
        for side in (-1, 1):
            _bolt(b, "pawl_cover_fastener", side * w * 0.36, -d / 2, h * 0.12, mat=iron)

    elif ident == "CCS27":
        _ring(b, "closed_oval_open_center_link", (0, 0, h / 2),
              w / 2 - h / 2, d / 2 - h / 2, h / 2, h, iron,
              axis="Z", segments=16)
        b.flag("instancing", "alternate link planes by 90deg around chain tangent")

    elif ident == "CCS28":
        b.box("guide_base", (0, 0, h * 0.07), (w, d, h * 0.14), iron)
        # Vertical sheave from CS07: floor chain turns upward between cheeks.
        b.cyl("guide_sheave", (0, 0, h * 0.55), h * 0.34, d * 0.22,
              iron, axis="Y", sides=16)
        for y in (-d * 0.14, d * 0.14):
            _ring(b, "sheave_chain_retaining_rim", (0, y, h * 0.55),
                  h * 0.34, h * 0.34, h * 0.055, d * 0.06, iron)
        b.cyl("guide_axle", (0, 0, h * 0.55), w * 0.055, d * 0.9,
              iron, axis="Y")
        for side in (-1, 1):
            b.box("guide_bracket", (0, side * d * 0.34, h * 0.43),
                  (w * 0.34, d * 0.12, h * 0.58), iron)
            _bolt(b, "guide_bracket_pin_cap", 0, side * d * 0.47,
                  h * 0.55, radius=w * 0.075, mat=iron)

    elif ident == "CCS29":
        _channel(b, "open_floor_chain_route", w, d, h, iron)
        for x in (-w * 0.44, 0, w * 0.44):
            for side in (-1, 1):
                b.box("rail_fastener_clip", (x, side * d * 0.41, h * 0.55),
                      (0.07, d * 0.18, h * 0.9), iron, bevel=0.005)
        b.flag("route", "continuous open channel; chain links instanced separately")

    elif ident == "CCS30":
        b.box("anchor_plate", (0, 0, h * 0.07), (w, d, h * 0.14), iron)
        for y in (-d * 0.25, d * 0.25):
            _ring(b, "anchor_open_eye", (0, y, h * 0.55), w * 0.31,
                  h * 0.29, w * 0.1, d * 0.17, iron)
            b.box("anchor_eye_foot", (0, y, h * 0.2), (w * 0.55, d * 0.17, h * 0.2), iron)
        b.cyl("removable_anchor_pin", (0, 0, h * 0.55), w * 0.07, d, iron, axis="Y")
        for side in (-1, 1):
            for x in (-w * 0.37, w * 0.37):
                _bolt(b, "anchor_fixing", x, side * d * 0.3, h * 0.15, axis="Z", mat=iron)

    elif ident == "CCS31":
        # Four-sided frame and hollow liner leave a clear chain aperture.
        t = w * 0.16
        for x in (-w / 2 + t / 2, w / 2 - t / 2):
            b.box("fairlead_side_plate", (x, 0, h / 2), (t, d * 0.36, h), iron)
        for z in (t / 2, h - t / 2):
            b.box("fairlead_cross_plate", (0, 0, z), (w - 2 * t, d * 0.36, t), iron)
        _ring(b, "open_wall_chain_throat", (0, -d * 0.2, h / 2),
              w * 0.31, h * 0.31, w * 0.06, d * 0.6, iron, segments=12)
        for x in (-w * 0.36, w * 0.36):
            for z in (h * 0.12, h * 0.88):
                _bolt(b, "fairlead_corner_bolt", x, -d * 0.22, z, mat=iron)

    elif ident == "CCS32":
        b.box("ceiling_mount_plate", (0, 0, h * 0.92), (w, d, h * 0.16), iron)
        b.box("hanger_fixed_stem", (0, 0, h * 0.59), (w * 0.24, d * 0.3, h * 0.5), iron)
        _ring(b, "hanger_closed_eye", (0, 0, h * 0.21), w * 0.34,
              h * 0.16, w * 0.12, d * 0.24, iron)
        for x in (-w * 0.33, w * 0.33):
            _bolt(b, "hanger_plate_fixing", x, 0, h * 0.83, axis="Z", mat=iron)

    elif ident == "CCS33":
        b.flag("moving_part", True)
        b.flag("axis", "+Z")
        b.flag("travel_m", 2.2)
        b.flag("clear_opening_m", "2.0 x 2.2")
        # Base is the existing moving-node origin, with no static frame geometry.
        for i in range(9):
            x = -w / 2 + 0.045 + i * (w - 0.09) / 8
            b.box("gate_vertical_bar", (x, 0, h / 2), (0.09, d * 0.65, h), iron, bevel=0.012)
        for z in (h * 0.17, h * 0.83):
            b.box("gate_cross_rail", (0, 0, z), (w, d, 0.13), iron, bevel=0.012)
            for i in range(9):
                x = -w / 2 + 0.045 + i * (w - 0.09) / 8
                _bolt(b, "gate_cross_rail_rivet", x, -d * 0.5, z,
                      radius=0.022, depth=0.012, mat=iron)

    elif ident == "CCS34":
        # One post, instanced beside the opening; no inward-projecting capital.
        for i in range(4):
            b.box("gate_post_stone_course", (0, 0, (i + 0.5) * h / 4),
                  (w, d, h / 4 - 0.006), stone, bevel=0.012)
        b.box("static_guide_mount_strip", (0, -d * 0.505, h / 2),
              (w * 0.5, 0.012, h * 0.92), iron, bevel=0.003)
        b.flag("placement", "post inner face at opening edge +/-1.0m; no inward cap")

    elif ident == "CCS35":
        for i in range(4):
            b.box("lintel_stone", (-w / 2 + (i + 0.5) * w / 4, 0, h / 2),
                  (w / 4 - 0.005, d, h), stone, bevel=0.012)
        b.flag("placement", "static above clear opening z=2.2m; offset in depth to keep leaf travel clear")

    elif ident == "CCS36":
        _channel(b, "full_travel_gate_guide", h, w, d, iron, vertical=True)
        for z in (h * 0.08, h * 0.36, h * 0.64, h * 0.92):
            b.box("guide_wall_fixing", (-w * 0.48, 0, z),
                  (w * 0.12, d, 0.07), iron, bevel=0.004)
        b.flag("placement", "static; mouth +X; mirror for opposite jamb outside clear width")
        b.flag("travel_m", 2.2)

    elif ident == "CCS37":
        # Open at top/bottom through the entire 2m leaf width: no parked-leaf cap.
        for side in (-1, 1):
            b.box("hood_side_cheek", (side * (w / 2 - 0.085), 0, h / 2),
                  (0.17, d, h), stone, bevel=0.025)
            for z in (h * 0.25, h * 0.84):
                b.box("hood_long_outer_rail", (0, side * (d / 2 - 0.04), z),
                      (w - 0.34, 0.08, 0.11), iron, bevel=0.01)
        b.flag("pocket", "open vertical slot: minimum width 2.06m; all rails outside leaf depth")

    elif ident == "CCS38":
        b.box("stop_shoe_base", (0, 0, h * 0.12), (w, d, h * 0.24), iron)
        profile = [(-w / 2, h * 0.24), (w / 2, h * 0.24),
                   (-w * 0.18, h), (-w / 2, h)]
        _prism_xz(b, "stop_shoe_wedge", profile, -d * 0.33, d * 0.33, iron)
        for y in (-d * 0.38, d * 0.38):
            _bolt(b, "stop_shoe_fixing", -w * 0.32, y, h * 0.28, axis="Z", mat=iron)
        b.flag("placement", "outside clear walk strip at jamb; no central threshold")

    elif ident == "CCS39":
        b.box("closed_counterweight_case", (0, 0, h / 2),
              (w * 0.86, d * 0.86, h * 0.9), iron, bevel=0.02)
        for z in (h * 0.07, h * 0.22, h * 0.78, h * 0.93):
            b.box("case_reinforcing_band", (0, 0, z), (w, d, h * 0.055), iron)
            for x in (-w * 0.32, w * 0.32):
                _bolt(b, "case_band_bolt", x, -d * 0.51, z, mat=iron)
        for x in (-w * 0.2, w * 0.2):
            b.box("case_front_seam", (x, -d * 0.437, h / 2),
                  (0.014, 0.008, h * 0.48), iron, bevel=0.002)
        b.flag("hookup", "closed static cosmetic case; no moving counterweight")

    elif ident == "CCS40":
        b.flag("moving_part", True)
        b.flag("axis", "+X; fit existing measured hinge")
        b.flag("compatibility", "existing shortcut lever skin only; no added control")
        _ring(b, "lever_open_hinge_eye", (0, 0, h * 0.09), w * 0.3,
              h * 0.055, w * 0.18, w * 0.6, iron, axis="X", segments=12)
        b.rod("lever_shank_lower", (0, 0, h * 0.12),
              (0, -d * 0.25, h * 0.48), w * 0.18, iron)
        b.rod("lever_shank_upper", (0, -d * 0.25, h * 0.48),
              (0, -d * 0.32, h * 0.7), w * 0.16, iron)
        b.cone("broad_lever_grip", (0, -d * 0.3, h * 0.8),
               w * 0.4, w * 0.32, h * 0.4, iron, sides=8)

    elif ident == "CCS41":
        b.box("lever_mount_foot", (0, 0, h * 0.08), (w, d, h * 0.16), stone)
        # Paired cheeks accept the separate lever eye and a transverse hinge pin.
        for x in (-w * 0.3, w * 0.3):
            b.box("hinge_cheek_foot", (x, 0, h * 0.3), (w * 0.2, d * 0.72, h * 0.3), iron)
            _ring(b, "hinge_cheek_open_bore", (x, 0, h * 0.67),
                  d * 0.29, h * 0.22, w * 0.055, w * 0.2,
                  iron, axis="X", segments=12)
        for x in (-w * 0.36, w * 0.36):
            for y in (-d * 0.35, d * 0.35):
                _bolt(b, "lever_base_fixing", x, y, h * 0.17, axis="Z", mat=iron)
        b.flag("axis", "+X; fit existing measured hinge")

    elif ident == "CCS42":
        # Loose kit pieces have separate silhouettes; core may merge the collection.
        b.cyl("short_hinge_pin", (-w * 0.27, 0, h * 0.32), w * 0.08,
              d * 0.85, iron, axis="Y", sides=8)
        b.cyl("broad_bolt_shank", (w * 0.28, -d * 0.24, h * 0.38),
              w * 0.06, h * 0.5, iron, sides=8)
        b.cyl("broad_bolt_head", (w * 0.28, -d * 0.24, h * 0.67),
              w * 0.16, h * 0.13, iron, sides=6)
        b.cyl("axle_end_cap", (w * 0.27, d * 0.27, h * 0.3),
              w * 0.16, h * 0.32, iron, sides=8)
        _ring(b, "open_pin_washer", (-w * 0.27, d * 0.25, h * 0.77),
              w * 0.12, w * 0.12, w * 0.035, h * 0.06, iron, axis="Z", segments=12)
        b.box("plain_fastening_strap", (0, 0, h * 0.055),
              (w, d * 0.28, h * 0.11), iron, bevel=0.004)
