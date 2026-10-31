"""Editor side of the Mars POTION: a round-bottom flask (glass + cork) and the liquid inside it, under
/Game/Mars/Gameplay/Items/Potion. Runs INSIDE a Mars editor (a hidden one: the meshes are imported from OBJ files, and a
live mesh is never rebuilt in an editor someone is using):

    python env_drive.py --port 9318 --module mars_potion_ue --alias mp --call "mp.run_all()"

    PotionFlask_Mars_SM    the item's Presentation mesh: slot 0 the glass (a closed shell with a wall, so the far wall
                           shows through the near one), slot 1 the cork; pivot at its flat base; one convex hull
    PotionLiquid_Mars_SM   the liquid: the body's sphere and the neck as one closed solid, pivot at the sphere's centre
                           (the shader cuts it with a plane about that centre); the entity script hangs it
                           BODY_CENTRE_CM over the flask's pivot
    PotionLiquid_Mars_M    masked, two-sided, lit, world-space normals: the HL:Alyx liquid (mars_potion_hlsl)
    PotionGlass_Mars_M     translucent lit glass, fresnel opacity
    PotionCork_Mars_M      opaque speckled cork
    and one instance of each master (*_MI): tune those, a rebuild keeps their values.

Liquid contract (custom primitive data, written by UMars_Potion_EntityScript every tick): 0-2 the surface normal (world,
unit), 3 the level (the plane's distance from the sphere's centre in radii, -1 empty .. 1 full), 4 Slosh (0..1, ripple
energy), 5 Phase (0..1, per potion). "Radius" on the instance is the sphere's local radius, LIQUID_RADIUS_CM.
Masters are rebuilt IN PLACE (emptied and refilled), never replaced (see mars_flame_ue).
"""
import math
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
ENV_DIR = os.path.dirname(HERE)
COOKING_UE = os.path.join(os.path.dirname(ENV_DIR), "mars_cooking", "unreal")
for _p in (HERE, ENV_DIR, COOKING_UE):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import mars_cooking_ue as mc     # noqa: E402  (_Graph, _asset, _tools, _task, _in_pie, capture)
import mars_potion_hlsl as hlsl  # noqa: E402
import importlib                 # noqa: E402
hlsl = importlib.reload(hlsl)

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary
FLOAT1 = unreal.CustomMaterialOutputType.CMOT_FLOAT1
FLOAT3 = unreal.CustomMaterialOutputType.CMOT_FLOAT3

FOLDER = "/Game/Mars/Gameplay/Items/Potion"
F_MAT = FOLDER + "/Materials"
F_MESH = FOLDER + "/Meshes"
FLASK = "PotionFlask_Mars_SM"
LIQUID = "PotionLiquid_Mars_SM"
MASTERS = ("PotionLiquid_Mars_M", "PotionGlass_Mars_M", "PotionCork_Mars_M")
INSTANCES = {m: m[:-2] + "_MI" for m in MASTERS}
OBJ_DIR = r"D:\Repo\Mars\Saved\PotionFx"

# ------------------------------------------------------------------ the flask's profile (cm, r out from the axis, z up)
# The body is a sphere of BODY_RADIUS_CM centred BODY_CENTRE_CM over the flat base; the neck rises from its shoulder to the
# lip; the glass is GLASS_CM thick. The liquid's sphere sits just inside the glass's inner wall. Keep these in step with
# constants_potion in Script/WorldObjects/Items/Mars_Potion_EntityScript.as.
BODY_RADIUS_CM = 4.6
BODY_CENTRE_CM = 4.05
GLASS_CM = 0.2
NECK_OUTER_CM = 1.35
NECK_INNER_CM = 1.15
NECK_TOP_CM = 12.4
LIP_TOP_CM = 13.1
INNER_FLOOR_CM = 0.3
LIQUID_RADIUS_CM = BODY_RADIUS_CM - GLASS_CM - 0.04
LIQUID_FLOOR_CM = INNER_FLOOR_CM + 0.04
CORK_BOTTOM_CM = 11.4
SEGMENTS = 48


def _log(msg):
    unreal.log("[potion] %s" % msg)


def _warn(msg):
    unreal.log_warning("[potion] %s" % msg)


def _arc(radius, centre_z, psi0, psi1, steps):
    """Points on a sphere's profile, psi the polar angle from its bottom (0) to its top (pi)."""
    return [(radius * math.sin(psi0 + (psi1 - psi0) * i / steps), centre_z - radius * math.cos(psi0 + (psi1 - psi0) * i / steps))
            for i in range(steps + 1)]


def glass_strips():
    """The glass shell: outside from the base's centre up to the lip, inside from the lip down to the floor's centre.
    Each strip is smooth; strips meet at hard edges."""
    R, C = BODY_RADIUS_CM, BODY_CENTRE_CM
    Ri = R - GLASS_CM
    base_r = math.sqrt(R * R - C * C)
    psi_base = math.acos(C / R)
    psi_shoulder = math.pi - math.asin(NECK_OUTER_CM / R)
    shoulder_z = C + math.sqrt(R * R - NECK_OUTER_CM ** 2)
    psi_inner_shoulder = math.pi - math.asin(NECK_INNER_CM / Ri)
    inner_shoulder_z = C + math.sqrt(Ri * Ri - NECK_INNER_CM ** 2)
    psi_floor = math.acos((C - INNER_FLOOR_CM) / Ri)
    floor_r = math.sqrt(Ri * Ri - (C - INNER_FLOOR_CM) ** 2)
    return [
        [(0.0, 0.0), (base_r * 0.5, 0.0), (base_r, 0.0)],
        _arc(R, C, psi_base, psi_shoulder, 28),
        [(NECK_OUTER_CM, shoulder_z), (NECK_OUTER_CM, (shoulder_z + NECK_TOP_CM) * 0.5), (NECK_OUTER_CM, NECK_TOP_CM)],
        [(NECK_OUTER_CM, NECK_TOP_CM), (1.62, 12.5), (1.74, 12.72), (1.72, 12.94), (1.58, 13.08), (1.4, LIP_TOP_CM),
         (NECK_INNER_CM, LIP_TOP_CM)],
        [(NECK_INNER_CM, LIP_TOP_CM), (NECK_INNER_CM, (LIP_TOP_CM + inner_shoulder_z) * 0.5), (NECK_INNER_CM, inner_shoulder_z)],
        _arc(Ri, C, psi_inner_shoulder, psi_floor, 28),
        [(floor_r, INNER_FLOOR_CM), (floor_r * 0.5, INNER_FLOOR_CM), (0.0, INNER_FLOOR_CM)],
    ]


def cork_strips():
    return [
        [(0.0, CORK_BOTTOM_CM), (1.08, CORK_BOTTOM_CM)],
        [(1.08, CORK_BOTTOM_CM), (1.13, LIP_TOP_CM)],
        [(1.13, LIP_TOP_CM), (1.3, LIP_TOP_CM)],
        [(1.3, LIP_TOP_CM), (1.3, 14.0), (1.3, 14.7)],
        [(1.3, 14.7), (1.27, 14.86), (1.2, 14.96), (1.1, 15.0)],
        [(1.1, 15.0), (0.55, 15.02), (0.0, 15.02)],
    ]


def liquid_strips():
    """The liquid about the sphere's centre (z 0 there): floor, sphere, neck up to the cork, cap."""
    R = LIQUID_RADIUS_CM
    neck = NECK_INNER_CM - 0.04
    floor_z = LIQUID_FLOOR_CM - BODY_CENTRE_CM
    floor_r = math.sqrt(R * R - floor_z * floor_z)
    psi_floor = math.acos(-floor_z / R)
    psi_shoulder = math.pi - math.asin(neck / R)
    shoulder_z = math.sqrt(R * R - neck * neck)
    top_z = CORK_BOTTOM_CM - BODY_CENTRE_CM
    return [
        [(0.0, floor_z), (floor_r * 0.5, floor_z), (floor_r, floor_z)],
        _arc(R, 0.0, psi_floor, psi_shoulder, 32),
        [(neck, shoulder_z), (neck, (shoulder_z + top_z) * 0.5), (neck, top_z)],
        [(neck, top_z), (neck * 0.5, top_z), (0.0, top_z)],
    ]


def _lathe(strips, segments, verts, uvs, norms, faces, material):
    """Appends the solid of revolution of strips to the OBJ lists (1-based indices on write). The 2D normal of a strip
    walked in order is (dz, -dr): outward for a profile walked up the outside, inward for one walked down the inside."""
    for strip in strips:
        n2 = []
        for i, (r, z) in enumerate(strip):
            acc = [0.0, 0.0]
            for a, b in ((i - 1, i), (i, i + 1)):
                if 0 <= a and b < len(strip):
                    dr, dz = strip[b][0] - strip[a][0], strip[b][1] - strip[a][1]
                    ln = math.hypot(dr, dz) or 1.0
                    acc[0] += dz / ln
                    acc[1] += -dr / ln
            ln = math.hypot(*acc) or 1.0
            n2.append((acc[0] / ln, acc[1] / ln))
        length = sum(math.hypot(strip[i + 1][0] - strip[i][0], strip[i + 1][1] - strip[i][1]) for i in range(len(strip) - 1)) or 1.0
        base = len(verts)
        run = 0.0
        for i, (r, z) in enumerate(strip):
            if i:
                run += math.hypot(r - strip[i - 1][0], z - strip[i - 1][1])
            for j in range(segments + 1):
                th = 2.0 * math.pi * j / segments
                c, s = math.cos(th), math.sin(th)
                verts.append((r * c, r * s, z))
                norms.append((n2[i][0] * c, n2[i][0] * s, n2[i][1]))
                uvs.append((j / float(segments), run / length))
        cols = segments + 1
        for i in range(len(strip) - 1):
            for j in range(segments):
                a, b = base + i * cols + j, base + i * cols + j + 1
                c_, d = base + (i + 1) * cols + j + 1, base + (i + 1) * cols + j
                for tri in ((a, b, c_), (a, c_, d)):
                    p = [verts[k] for k in tri]
                    e1 = [p[1][q] - p[0][q] for q in range(3)]
                    e2 = [p[2][q] - p[0][q] for q in range(3)]
                    gn = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
                    if math.sqrt(sum(g * g for g in gn)) < 1e-9:
                        continue                                   # collapsed on the axis
                    vn = [sum(norms[k][q] for k in tri) for q in range(3)]
                    if sum(gn[q] * vn[q] for q in range(3)) < 0.0:
                        tri = (tri[0], tri[2], tri[1])
                    faces.append((material, tri))


def write_obj(path, parts, segments=SEGMENTS):
    """parts: [(material slot name, strips)]. Z up, cm."""
    verts, uvs, norms, faces = [], [], [], []
    for material, strips in parts:
        _lathe(strips, segments, verts, uvs, norms, faces, material)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    lines = ["# %s (mars_potion_ue.write_obj)" % os.path.basename(path), "o %s" % os.path.splitext(os.path.basename(path))[0]]
    lines += ["v %.5f %.5f %.5f" % v for v in verts]
    lines += ["vt %.5f %.5f" % t for t in uvs]
    lines += ["vn %.5f %.5f %.5f" % n for n in norms]
    current = None
    for material, tri in faces:
        if material != current:
            lines.append("usemtl %s" % material)
            current = material
        lines.append("f " + " ".join("%d/%d/%d" % (k + 1, k + 1, k + 1) for k in tri))
    with open(path, "w") as fh:
        fh.write("\n".join(lines) + "\n")
    return {"path": path, "verts": len(verts), "tris": len(faces)}


# ------------------------------------------------------------------ materials
def _master(name):
    """The master at F_MAT, emptied in place if it exists (delete_all_material_expressions skips nodes: loop to 0)."""
    m = mc._asset(F_MAT, name)
    if m is None:
        return mc._tools().create_asset(name, F_MAT, unreal.Material, unreal.MaterialFactoryNew())
    for _ in range(8):
        if MEL.get_num_material_expressions(m) == 0:
            break
        MEL.delete_all_material_expressions(m)
    return m


def _const3(g, v, x, y):
    c = g.expr(unreal.MaterialExpressionConstant3Vector, x, y)
    c.set_editor_property("constant", unreal.LinearColor(v[0], v[1], v[2], 1.0))
    return c


def _cpd_scalar(g, name, value, index, desc):
    e = g.scalar(name, value, 0.0, 1.0, desc)
    e.set_editor_property("use_custom_primitive_data", True)
    e.set_editor_property("primitive_data_index", index)
    return e


def build_liquid():
    m = _master("PotionLiquid_Mars_M")
    m.set_editor_property("shading_model", unreal.MaterialShadingModel.MSM_DEFAULT_LIT)
    m.set_editor_property("blend_mode", unreal.BlendMode.BLEND_MASKED)
    m.set_editor_property("two_sided", True)
    m.set_editor_property("tangent_space_normal", False)
    m.set_editor_property("opacity_mask_clip_value", 0.5)
    g = mc._Graph(m, -3200)
    g.group("Liquid")
    liquid = g.vector("Liquid Color", (0.3, 1.0, 0.42, 1.0), "The liquid where it is thin: the edge of the volume.")
    deep = g.vector("Deep Color", (0.01, 0.16, 0.05, 1.0), "The liquid where it is thick: the middle of the flask.")
    density = g.scalar("Density", 2.6, 0.0, 8.0, "How fast the colour goes from Liquid to Deep with the depth looked "
                                                  "through (per radius).")
    glow = g.scalar("Glow", 0.9, 0.0, 10.0, "Emissive strength: the potion's own light (it still takes the scene's).")
    rim = g.scalar("Rim Light", 1.4, 0.0, 4.0, "Light through the thin edge of the volume.")
    rough = g.scalar("Roughness", 0.06, 0.0, 1.0, "Wall and surface roughness: low for a glossy liquid.")
    g.group("Surface")
    surface = g.vector("Surface Color", (0.45, 0.95, 0.55, 1.0), "The top of the liquid, mixed over the depth colour.")
    surface_mix = g.scalar("Surface Mix", 0.2, 0.0, 1.0, "How much of the top is Surface Color (0: only the depth under it).")
    foam = g.vector("Foam Color", (0.8, 1.0, 0.78, 1.0), "The line where the liquid meets the glass (and the motes).")
    foam_w = g.scalar("Foam Width", 0.035, 0.0, 0.3, "The meniscus line's width, in radii.")
    g.group("Ripples")
    rip_amt = g.scalar("Ripple Amount", 0.06, 0.0, 0.3, "Ripple height at full slosh, in radii.")
    rip_scale = g.scalar("Ripple Scale", 2.2, 0.2, 8.0, "Waves across the surface.")
    rip_speed = g.scalar("Ripple Speed", 3.5, 0.0, 12.0, "How fast the waves travel (radians/s).")
    g.group("Motes")
    mote_amt = g.scalar("Mote Amount", 0.6, 0.0, 4.0, "Brightness of the sparks rising through the liquid (0: none).")
    mote_scale = g.scalar("Mote Scale", 2.6, 0.5, 10.0, "Cells per radius: more, smaller motes.")
    mote_speed = g.scalar("Mote Speed", 0.35, 0.0, 3.0, "How fast the motes rise (cells per second).")
    g.group("Shape")
    radius = g.scalar("Radius", LIQUID_RADIUS_CM, 0.1, 50.0, "The liquid sphere's local radius, cm (the mesh's).")
    g.group("Per Potion (Custom Primitive Data)")
    surf = g.vector("Surface", (0.0, 0.0, 1.0, 0.0), "Custom primitive data 0-3: the surface normal (world) and the "
                    "level (radii from the centre).", ("Nx", "Ny", "Nz", "Level"), cpd=0)
    slosh = _cpd_scalar(g, "Slosh", 0.0, 4, "Custom primitive data 4: ripple energy, 0 still.")
    phase = _cpd_scalar(g, "Phase", 0.0, 5, "Custom primitive data 5: this potion's random phase.")

    x, y = -1900, -900
    # D: the local position from the vertex shader (before the first-person transform), as a world vector
    wp = g.expr(unreal.MaterialExpressionWorldPosition, x, y)
    wp.set_editor_property("world_position_shader_offset", unreal.WorldPositionIncludedOffsets.WPT_EXCLUDE_ALL_SHADER_OFFSETS)
    lp = g.expr(unreal.MaterialExpressionTransformPosition, x + 260, y)
    lp.set_editor_property("transform_source_type", unreal.MaterialPositionTransformSource.TRANSFORMPOSSOURCE_WORLD)
    lp.set_editor_property("transform_type", unreal.MaterialPositionTransformSource.TRANSFORMPOSSOURCE_LOCAL)
    g.link(wp, "", lp, "")
    vi = g.expr(unreal.MaterialExpressionVertexInterpolator, x + 520, y)
    g.link(lp, "", vi, "VS")
    d = g.expr(unreal.MaterialExpressionTransform, x + 780, y)
    d.set_editor_property("transform_source_type", unreal.MaterialVectorCoordTransformSource.TRANSFORMSOURCE_LOCAL)
    d.set_editor_property("transform_type", unreal.MaterialVectorCoordTransform.TRANSFORM_WORLD)
    g.link(vi, "", d, "")
    # CamRel: the camera relative to the sphere's centre (the pivot)
    pivot = g.expr(unreal.MaterialExpressionTransformPosition, x + 260, y + 200)
    pivot.set_editor_property("transform_source_type", unreal.MaterialPositionTransformSource.TRANSFORMPOSSOURCE_LOCAL)
    pivot.set_editor_property("transform_type", unreal.MaterialPositionTransformSource.TRANSFORMPOSSOURCE_WORLD)
    g.link(_const3(g, (0.0, 0.0, 0.0), x, y + 200), "", pivot, "")
    cam = g.expr(unreal.MaterialExpressionCameraPositionWS, x + 260, y + 340)
    camrel = g.expr(unreal.MaterialExpressionSubtract, x + 520, y + 260)
    g.link(cam, "", camrel, "A")
    g.link(pivot, "", camrel, "B")
    unit = g.expr(unreal.MaterialExpressionTransform, x + 260, y + 460)
    unit.set_editor_property("transform_source_type", unreal.MaterialVectorCoordTransformSource.TRANSFORMSOURCE_LOCAL)
    unit.set_editor_property("transform_type", unreal.MaterialVectorCoordTransform.TRANSFORM_WORLD)
    g.link(_const3(g, (1.0, 0.0, 0.0), x, y + 460), "", unit, "")
    time = g.expr(unreal.MaterialExpressionTime, x + 520, y + 560)
    sign = g.expr(unreal.MaterialExpressionTwoSidedSign, x + 520, y + 660)
    nw = g.expr(unreal.MaterialExpressionVertexNormalWS, x + 520, y + 760)

    ps = g.custom("Liquid", hlsl.LIQUID_PS,
                  [("D", d, ""), ("CamRel", camrel, ""), ("Unit", unit, ""), ("Radius", radius, ""), ("Surface", surf, "RGBA"),
                   ("Slosh", slosh, ""), ("Phase", phase, ""), ("Time", time, ""), ("Sign", sign, ""), ("Nw", nw, ""),
                   ("LiquidColor", liquid, ""), ("DeepColor", deep, ""), ("Density", density, ""), ("Glow", glow, ""),
                   ("RimLight", rim, ""), ("Roughness", rough, ""), ("SurfaceColor", surface, ""), ("SurfaceMix", surface_mix, ""),
                   ("FoamColor", foam, ""), ("FoamWidth", foam_w, ""), ("RippleAmount", rip_amt, ""), ("RippleScale", rip_scale, ""),
                   ("RippleSpeed", rip_speed, ""), ("MoteAmount", mote_amt, ""), ("MoteScale", mote_scale, ""),
                   ("MoteSpeed", mote_speed, "")],
                  -600, y, out=FLOAT3,
                  extra=(("OutNormal", FLOAT3), ("OutEmissive", FLOAT3), ("OutMask", FLOAT1), ("OutRough", FLOAT1)))
    g.finish({"BaseColor": (ps, ""), "Normal": (ps, "OutNormal"), "EmissiveColor": (ps, "OutEmissive"),
              "OpacityMask": (ps, "OutMask"), "Roughness": (ps, "OutRough")}, -200, y)
    return m


def build_glass():
    m = _master("PotionGlass_Mars_M")
    m.set_editor_property("shading_model", unreal.MaterialShadingModel.MSM_DEFAULT_LIT)
    m.set_editor_property("blend_mode", unreal.BlendMode.BLEND_TRANSLUCENT)
    m.set_editor_property("translucency_lighting_mode", unreal.TranslucencyLightingMode.TLM_SURFACE_PER_PIXEL_LIGHTING)
    for prop, value in (("output_translucent_velocity", False),):
        try:
            m.set_editor_property(prop, value)
        except Exception:
            pass
    g = mc._Graph(m, -1800)
    g.group("Glass")
    tint = g.vector("Tint", (0.9, 0.97, 1.0, 1.0), "The glass's colour.")
    lo = g.scalar("Opacity Facing", 0.06, 0.0, 1.0, "Opacity where the glass faces the camera.")
    hi = g.scalar("Opacity Edge", 0.35, 0.0, 1.0, "Opacity at the silhouette, where the light skims the glass.")
    exponent = g.scalar("Fresnel Exponent", 4.0, 0.5, 10.0, "How fast the edge opacity falls off toward the facing.")
    rough = g.scalar("Roughness", 0.04, 0.0, 1.0, "Low: sharp highlights.")
    spec = g.scalar("Specular", 0.8, 0.0, 1.0, "Highlight strength.")
    x, y = -900, -600
    fres = g.custom("Fresnel", "return pow(1.0 - saturate(abs(dot(normalize(N), normalize(V)))), E);",
                    [("N", g.expr(unreal.MaterialExpressionPixelNormalWS, x - 300, y), ""),
                     ("V", g.expr(unreal.MaterialExpressionCameraVectorWS, x - 300, y + 120), ""),
                     ("E", exponent, "")], x, y, out=FLOAT1)
    opacity = g.custom("Opacity", "return lerp(Lo, Hi, F);", [("Lo", lo, ""), ("Hi", hi, ""), ("F", fres, "")], x + 250, y, out=FLOAT1)
    g.finish({"BaseColor": (tint, ""), "Opacity": (opacity, ""), "Roughness": (rough, ""), "Specular": (spec, "")}, -200, y)
    return m


def build_cork():
    m = _master("PotionCork_Mars_M")
    m.set_editor_property("shading_model", unreal.MaterialShadingModel.MSM_DEFAULT_LIT)
    m.set_editor_property("blend_mode", unreal.BlendMode.BLEND_OPAQUE)
    g = mc._Graph(m, -1800)
    g.group("Cork")
    dark = g.vector("Dark", (0.24, 0.13, 0.06, 1.0), "Cork between the grains.")
    light = g.vector("Light", (0.55, 0.36, 0.2, 1.0), "Cork on the grains.")
    scale = g.scalar("Grain Scale", 2.5, 0.2, 10.0, "Grains per cm.")
    rough = g.scalar("Roughness", 0.85, 0.0, 1.0, "")
    x, y = -900, -600
    wp = g.expr(unreal.MaterialExpressionWorldPosition, x - 600, y)
    wp.set_editor_property("world_position_shader_offset", unreal.WorldPositionIncludedOffsets.WPT_EXCLUDE_ALL_SHADER_OFFSETS)
    lp = g.expr(unreal.MaterialExpressionTransformPosition, x - 340, y)
    lp.set_editor_property("transform_source_type", unreal.MaterialPositionTransformSource.TRANSFORMPOSSOURCE_WORLD)
    lp.set_editor_property("transform_type", unreal.MaterialPositionTransformSource.TRANSFORMPOSSOURCE_LOCAL)
    g.link(wp, "", lp, "")
    col = g.custom("Cork", hlsl.CORK_PS, [("P", lp, ""), ("Scale", scale, ""), ("Dark", dark, ""), ("Light", light, "")], x, y, out=FLOAT3)
    g.finish({"BaseColor": (col, ""), "Roughness": (rough, "")}, -200, y)
    return m


def build_materials():
    """The three masters (in place) and one instance of each; instance values an artist changed survive a rebuild."""
    made = []
    for build, master in ((build_liquid, "PotionLiquid_Mars_M"), (build_glass, "PotionGlass_Mars_M"), (build_cork, "PotionCork_Mars_M")):
        m = build()
        inst = INSTANCES[master]
        mi = mc._asset(F_MAT, inst)
        if mi is None:
            mi = mc._tools().create_asset(inst, F_MAT, unreal.MaterialInstanceConstant, unreal.MaterialInstanceConstantFactoryNew())
        MEL.set_material_instance_parent(mi, m)
        MEL.update_material_instance(mi)
        EAL.save_loaded_asset(mi)
        stats = MEL.get_statistics(m)
        made.append((master, MEL.get_num_material_expressions(m), stats.num_pixel_shader_instructions))
    _log("potion materials: %s" % made)
    return made


# ------------------------------------------------------------------ meshes
def _import(obj, name, slots):
    """A NEW asset from obj (an existing one is deleted first: a live mesh is never rebuilt in place); slots: material
    instance name per slot, in the OBJ's usemtl order. Materials the importer made from the usemtl names are deleted."""
    path = "%s/%s" % (F_MESH, name)
    if EAL.does_asset_exist(path):
        EAL.delete_asset(path)
    before = set(EAL.list_assets(FOLDER, recursive=True, include_folder=False))
    mc._tools().import_asset_tasks([mc._task(obj, F_MESH, name)])
    mesh = mc._asset(F_MESH, name)
    if mesh is None:
        raise RuntimeError("%s did not import to %s" % (obj, path))
    for i, inst in enumerate(slots):
        mesh.set_material(i, mc._asset(F_MAT, inst))
    stray = [p for p in set(EAL.list_assets(FOLDER, recursive=True, include_folder=False)) - before
             if not p.split(".")[0].endswith(name)]
    for p in stray:
        EAL.delete_asset(p.split(".")[0])
    nanite = mesh.get_editor_property("nanite_settings")
    nanite.set_editor_property("enabled", False)
    mesh.set_editor_property("nanite_settings", nanite)
    return mesh, stray


def build_meshes():
    if mc._in_pie():
        raise RuntimeError("stop PIE before importing")
    flask_obj = os.path.join(OBJ_DIR, FLASK + ".obj")
    liquid_obj = os.path.join(OBJ_DIR, LIQUID + ".obj")
    report = {"flask_obj": write_obj(flask_obj, [("Glass", glass_strips()), ("Cork", cork_strips())]),
              "liquid_obj": write_obj(liquid_obj, [("Liquid", liquid_strips())])}
    sme = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)

    flask, stray = _import(flask_obj, FLASK, (INSTANCES["PotionGlass_Mars_M"], INSTANCES["PotionCork_Mars_M"]))
    sme.remove_collisions(flask)
    sme.set_convex_decomposition_collisions(flask, 1, 32, 100000)
    EAL.save_loaded_asset(flask)
    liquid, stray2 = _import(liquid_obj, LIQUID, (INSTANCES["PotionLiquid_Mars_M"],))
    sme.remove_collisions(liquid)
    EAL.save_loaded_asset(liquid)

    for mesh, key in ((flask, "flask"), (liquid, "liquid")):
        b = mesh.get_bounds()
        report[key] = {"verts": sme.get_number_verts(mesh, 0), "slots": sme.get_number_materials(mesh),
                       "origin": str(b.origin), "extent": str(b.box_extent)}
    report["stray_deleted"] = stray + stray2
    _log("potion meshes: %s" % report)
    return report


def run_all():
    return {"materials": build_materials(), "meshes": build_meshes()}


def asset_path(folder, name):
    return "%s/%s.%s" % (folder, name, name)


# ------------------------------------------------------------------ lookdev
LOOKDEV_MAP = "/Game/Mars/Maps/PotionLookdev_Mars_MAP"
LOOKDEV_HDR = "/Game/Mars/Gameplay/Cooking/Textures/CookingStudio_Mars_HDR"   # the cooking lookdev's studio map
LOOKDEV_TAG = "MarsPotionLookdev"
EXPOSURE_BIAS = 0.2


def level_for_fill(fill):
    """The plane's distance from the sphere's centre, in radii, that leaves fill (0..1) of the sphere's volume under it:
    a cap of height x (radii) holds x^2 (3 - x) / 4 of the sphere. Bisection (the same as utils in the entity script)."""
    lo, hi = 0.0, 2.0
    target = min(max(fill, 0.0), 1.0)
    for _ in range(40):
        mid = 0.5 * (lo + hi)
        if mid * mid * (3.0 - mid) / 4.0 < target:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi) - 1.0


# (label, location cm, rotation (pitch, yaw, roll), surface normal tilt (x, y), fill)
LOOKDEV_POSES = (
    ("upright", (-36.0, 60.0, 0.0), (0.0, 0.0, 0.0), (0.0, 0.0), 0.5),
    ("tipped", (-12.0, 60.0, 4.0), (0.0, 0.0, 50.0), (0.0, 0.0), 0.5),
    ("slosh", (12.0, 60.0, 0.0), (0.0, 0.0, 0.0), (0.0, 0.35), 0.5),
    ("full", (36.0, 60.0, 0.0), (0.0, 0.0, 0.0), (0.0, 0.0), 0.8),
    ("side", (60.0, 60.0, 4.7), (90.0, 0.0, 0.0), (0.0, 0.0), 0.35),
)

SHOTS = {
    "potion_row": ((12.0, 14.0, 16.0), (12.0, 60.0, 6.0), 70),
    "potion_upright": ((-36.0, 36.0, 10.0), (-36.0, 60.0, 6.0), 40),
    "potion_tipped": ((-12.0, 36.0, 12.0), (-12.0, 60.0, 6.0), 40),
    "potion_slosh": ((12.0, 36.0, 12.0), (12.0, 60.0, 6.0), 40),
    "potion_full_top": ((36.0, 44.0, 26.0), (36.0, 60.0, 6.0), 40),
    "potion_side": ((60.0, 38.0, 14.0), (60.0, 60.0, 5.0), 40),
}


def _spawn(cls, loc, rot):
    eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    return eas.spawn_actor_from_class(cls, unreal.Vector(*loc), unreal.Rotator(pitch=rot[0], yaw=rot[1], roll=rot[2]))


def _try(obj, prop, value):
    try:
        obj.set_editor_property(prop, value)
    except Exception as exc:
        _warn("%s.%s: %s" % (obj.get_name(), prop, exc))


def _rig():
    """The cooking lookdev's studio: a dark counter, a warm key and a fill, the studio HDR as sky light and reflection,
    manual exposure. (Never duplicate a map asset to get this: duplicate_asset loads the copy, and loading it as the
    level then dies on 'Old level package not cleaned up', 2026-10-30.)"""
    hdr = mc._load(LOOKDEV_HDR)
    counter = _spawn(unreal.StaticMeshActor, (0.0, 60.0, 0.0), (0.0, 0.0, 0.0))
    counter.static_mesh_component.set_static_mesh(mc._load("/Engine/BasicShapes/Plane.Plane"))
    counter.set_actor_scale3d(unreal.Vector(3.0, 1.5, 1.0))
    counter.set_actor_label("Counter")
    key = _spawn(unreal.DirectionalLight, (0.0, 0.0, 300.0), (-55.0, -115.0, 0.0))
    kc = key.get_component_by_class(unreal.DirectionalLightComponent)
    _try(kc, "intensity", 4.0)
    _try(kc, "light_color", unreal.Color(r=255, g=232, b=200, a=255))
    _try(kc, "light_source_angle", 3.0)
    fill = _spawn(unreal.DirectionalLight, (0.0, 0.0, 300.0), (-30.0, 60.0, 0.0))
    fc = fill.get_component_by_class(unreal.DirectionalLightComponent)
    _try(fc, "intensity", 1.2)
    _try(fc, "cast_shadows", False)
    sky = _spawn(unreal.SkyLight, (0.0, 0.0, 200.0), (0.0, 0.0, 0.0))
    sc = sky.get_component_by_class(unreal.SkyLightComponent)
    _try(sc, "source_type", unreal.SkyLightSourceType.SLS_SPECIFIED_CUBEMAP)
    _try(sc, "cubemap", hdr)
    _try(sc, "intensity", 0.4)
    cap = _spawn(unreal.SphereReflectionCapture, (12.0, 50.0, 14.0), (0.0, 0.0, 0.0))
    cc = cap.get_component_by_class(unreal.SphereReflectionCaptureComponent)
    _try(cc, "reflection_source_type", unreal.ReflectionSourceType.SPECIFIED_CUBEMAP)
    _try(cc, "cubemap", hdr)
    _try(cc, "influence_radius", 400.0)
    ppv = _spawn(unreal.PostProcessVolume, (0.0, 0.0, 0.0), (0.0, 0.0, 0.0))
    _try(ppv, "unbound", True)
    s = ppv.get_editor_property("settings")
    for k, v in (("override_auto_exposure_method", True), ("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL),
                 ("override_auto_exposure_bias", True), ("auto_exposure_bias", EXPOSURE_BIAS),
                 ("override_bloom_intensity", True), ("bloom_intensity", 0.6)):
        _try(s, k, v)
    ppv.set_editor_property("settings", s)


def build_lookdev():
    """PotionLookdev_Mars_MAP: the studio rig and one flask per LOOKDEV_POSES entry, its liquid written the way the
    entity script writes it. Rebuilt from scratch on every call; saves the map."""
    if mc._in_pie():
        raise RuntimeError("stop PIE first")
    les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
    eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    if EAL.does_asset_exist(LOOKDEV_MAP):
        les.load_level(LOOKDEV_MAP)
        eas.destroy_actors([a for a in eas.get_all_level_actors() if not isinstance(a, (unreal.WorldSettings, unreal.Brush))])
    else:
        les.new_level(LOOKDEV_MAP)
    _rig()
    flask = mc._asset(F_MESH, FLASK)
    liquid = mc._asset(F_MESH, LIQUID)
    made = []
    for label, loc, rot, tilt, fill in LOOKDEV_POSES:
        fa = _spawn(unreal.StaticMeshActor, loc, rot)
        fa.static_mesh_component.set_static_mesh(flask)
        fa.set_actor_label("Potion_%s" % label)
        fa.tags = [unreal.Name(LOOKDEV_TAG)]
        xf = fa.get_actor_transform()
        centre = unreal.MathLibrary.transform_location(xf, unreal.Vector(0.0, 0.0, BODY_CENTRE_CM))
        la = _spawn(unreal.StaticMeshActor, (centre.x, centre.y, centre.z), rot)
        la.static_mesh_component.set_static_mesh(liquid)
        la.static_mesh_component.set_cast_shadow(False)
        la.set_actor_label("PotionLiquid_%s" % label)
        la.tags = [unreal.Name(LOOKDEV_TAG)]
        n = unreal.Vector(tilt[0], tilt[1], 1.0)
        n = n.normal()
        c = la.static_mesh_component
        for i, v in enumerate((n.x, n.y, n.z, level_for_fill(fill), 0.6 if label == "slosh" else 0.0, 0.37 * len(made))):
            c.set_custom_primitive_data_float(i, v)
        made.append(label)
    les.save_current_level()
    return made


def capture_lookdev(out_dir=r"D:\Repo\Mars\Saved\PotionFx\shots", shots=None):
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    if not world.get_path_name().startswith(LOOKDEV_MAP):
        unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).load_level(LOOKDEV_MAP)
    saved = dict(mc.SHOTS)
    try:
        mc.SHOTS.clear()
        mc.SHOTS.update(SHOTS)
        mc.capture(out_dir, shots=shots or list(SHOTS))
    finally:
        mc.SHOTS.clear()
        mc.SHOTS.update(saved)
    return out_dir
