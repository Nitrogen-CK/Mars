"""Editor side of the Mars FLAME effect (Flame_Mars_NS): builds the three Niagara sprite materials and one instance of
each under /Game/Mars/Fx/Flame/Materials. Runs INSIDE a Mars editor (through Monolith: mars_flame_niagara calls it, or
env_drive.py --module mars_flame_ue --alias mf --call "mf.build_materials()").

    FlameCard_Mars_M     THE flame: one unlit translucent card per flame on a static mesh (the engine Plane rolled upright
                         on the flame node), a procedural billboard about Z in the vertex shader whose base is pinned at
                         the node and whose tip bends by Lean (custom primitive data 2-4 + 5 enclosed) and the flicker;
                         the sprite's teardrop + erosion in the pixel shader; Phase CPD 0, Intensity CPD 1, Height /
                         Width CPD 6 / 7
    FlameSprite_Mars_M   unlit additive sprite (unused by Flame_Mars_NS since the card; kept for a particle flame): teardrop SDF (CkUsf_SdfEdgeAA) eroded by scrolling value noise, per-sprite
                         flicker from the dynamic parameter's phase, colour ramp white-hot -> particle colour -> dark red
    EmberSprite_Mars_M   unlit additive point through EyeAdaptationInverse, orange -> black by age
    FlameGlow_Mars_M     unlit additive radial glow in the particle colour, cross-faded on age

Dynamic parameter contract (Niagara "Dynamic Material Parameters", slot 0, written by the Mars*Update modules):
x = per-particle phase, y = normalized age, z = Intensity (0..1), w = Enclosed. Particle colour rgb = the user Colour.
Masters are rebuilt IN PLACE (emptied and refilled), never replaced: replacing a master asserts in the renderer while
instances of it are on screen. Instance values an artist edited survive a rebuild.
"""
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
ENV_DIR = os.path.dirname(HERE)
COOKING_UE = os.path.join(os.path.dirname(ENV_DIR), "mars_cooking", "unreal")
for _p in (HERE, ENV_DIR, COOKING_UE):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import mars_cooking_ue as mc     # noqa: E402  (_Graph, _asset, _tools)
import mars_flame_hlsl as hlsl   # noqa: E402
import importlib                 # noqa: E402
hlsl = importlib.reload(hlsl)    # a reload of this module refreshes its HLSL bodies too (the editor caches modules)

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary
FLOAT1 = unreal.CustomMaterialOutputType.CMOT_FLOAT1
FLOAT3 = unreal.CustomMaterialOutputType.CMOT_FLOAT3

FX_FOLDER = "/Game/Mars/Fx/Flame"
F_MAT = FX_FOLDER + "/Materials"
MASTERS = ("FlameCard_Mars_M", "FlameSprite_Mars_M", "EmberSprite_Mars_M", "FlameGlow_Mars_M")
INSTANCES = {m: m[:-2] + "_MI" for m in MASTERS}
CKUSF_INCLUDE = "/CkUsf/Common.ush"


def _log(msg):
    unreal.log("[flame] %s" % msg)


def _warn(msg):
    unreal.log_warning("[flame] %s" % msg)


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


def _sprite_props(m):
    m.set_editor_property("shading_model", unreal.MaterialShadingModel.MSM_UNLIT)
    m.set_editor_property("blend_mode", unreal.BlendMode.BLEND_ADDITIVE)
    m.set_editor_property("two_sided", True)
    m.set_editor_property("used_with_niagara_sprites", True)
    m.set_editor_property("used_with_particle_sprites", True)


def _particle_head(g, x, y):
    """UV0, the dynamic parameter (slot 0), the particle colour: the shared head of the three graphs. The dynamic
    parameter node's first output is the scalar Phase: the Custom nodes take its RGBA output (the full float4)."""
    uv = g.expr(unreal.MaterialExpressionTextureCoordinate, x, y)
    dyn = g.expr(unreal.MaterialExpressionDynamicParameter, x, y + 150)
    dyn.set_editor_property("parameter_index", 0)
    dyn.set_editor_property("param_names", ["Phase", "Age", "Intensity", "Enclosed"])
    dyn.set_editor_property("default_value", unreal.LinearColor(0.0, 0.0, 1.0, 0.0))
    pc = g.expr(unreal.MaterialExpressionParticleColor, x, y + 330)
    return uv, dyn, pc


def _finish(g, emissive):
    g.finish({"EmissiveColor": (emissive, "")}, 400, -300)


def build_flame_sprite():
    m = _master("FlameSprite_Mars_M")
    _sprite_props(m)
    g = mc._Graph(m, -2600)
    g.group("Flame")
    flicker = g.scalar("Flicker", 0.22, 0.0, 1.0, "How far each tongue's brightness swings round its mean.")
    softness = g.scalar("Edge Softness", 0.25, 0.01, 1.0, "The haze outside the hard edge, in sprite half-widths.")
    core = g.vector("Core Color", (1.0, 0.93, 0.78, 1.0), "White-hot: the foot of a young tongue.")
    tip = g.vector("Tip Color", (0.55, 0.08, 0.01, 1.0), "Dark red: the tip of an old tongue.")
    g.group("Erosion")
    scale = g.scalar("Noise Scale", 3.0, 0.5, 12.0, "Cells across the sprite.")
    speed = g.scalar("Noise Speed", 1.6, 0.0, 6.0, "How fast the erosion scrolls up the tongue.")
    uv, dyn, pc = _particle_head(g, -1500, -700)
    time = g.expr(unreal.MaterialExpressionTime, -1500, -250)
    noise = g.custom("Erosion Noise", hlsl.NOISE_HLSL, [("UV", uv, ""), ("Time", time, ""), ("Scale", scale, ""), ("Speed", speed, "")],
                     -1000, -300, out=FLOAT1)
    col = g.custom("Flame Sprite", hlsl.FLAME_SPRITE_HLSL,
                   [("UV", uv, ""), ("Dyn", dyn, "RGBA"), ("PC", pc, ""), ("Noise", noise, ""), ("Time", time, ""),
                    ("Flicker", flicker, ""), ("Softness", softness, ""), ("Core", core, ""), ("Tip", tip, "")],
                   -400, -500, out=FLOAT3)
    col.set_editor_property("include_file_paths", [CKUSF_INCLUDE])
    _finish(g, col)
    return m


def build_ember_sprite():
    m = _master("EmberSprite_Mars_M")
    _sprite_props(m)
    g = mc._Graph(m, -2200)
    g.group("Ember")
    strength = g.scalar("Strength", 0.35, 0.0, 4.0, "Emissive strength before EyeAdaptationInverse: keep it low, an ember "
                                                   "is exposure-independent and blooms in a dark room.")
    uv, dyn, pc = _particle_head(g, -1500, -700)
    col = g.custom("Ember Sprite", hlsl.EMBER_SPRITE_HLSL, [("UV", uv, ""), ("Dyn", dyn, "RGBA"), ("PC", pc, ""), ("Strength", strength, "")],
                   -800, -500, out=FLOAT3)
    eye = g.expr(unreal.MaterialExpressionEyeAdaptationInverse, -400, -500)
    if not any(MEL.connect_material_expressions(col, "", eye, n) for n in ("LightValue", "LightValueInput", "Light Value")):
        _warn("EmberSprite_Mars_M: could not connect the ember to EyeAdaptationInverse; wiring it straight")
        eye = col
    _finish(g, eye)
    return m


def build_flame_glow():
    m = _master("FlameGlow_Mars_M")
    _sprite_props(m)
    g = mc._Graph(m, -2200)
    g.group("Glow")
    strength = g.scalar("Strength", 0.25, 0.0, 10.0, "Emissive strength of the glow's centre (low: it is additive over the card).")
    falloff = g.scalar("Falloff", 2.2, 0.5, 8.0, "Higher keeps the glow nearer the flame.")
    uv, dyn, pc = _particle_head(g, -1500, -700)
    col = g.custom("Flame Glow", hlsl.FLAME_GLOW_HLSL, [("UV", uv, ""), ("Dyn", dyn, "RGBA"), ("PC", pc, ""), ("Strength", strength, ""),
                                                        ("Falloff", falloff, "")], -800, -500, out=FLOAT3)
    _finish(g, col)
    return m


def build_flame_card():
    m = _master("FlameCard_Mars_M")
    m.set_editor_property("shading_model", unreal.MaterialShadingModel.MSM_UNLIT)
    # translucent: a solid-looking flame against a bright sky or a lit wall, soft edges, and no velocity written (a masked
    # card's moving vertices smeared under motion blur)
    m.set_editor_property("blend_mode", unreal.BlendMode.BLEND_TRANSLUCENT)
    m.set_editor_property("two_sided", True)
    for prop, value in (("output_translucent_velocity", False), ("translucency_pass", unreal.MaterialTranslucencyPass.MTP_AFTER_DOF)):
        try:
            m.set_editor_property(prop, value)
        except Exception:
            pass
    g = mc._Graph(m, -3000)
    g.group("Flame")
    colour = g.vector("Colour", (1.0, 0.55, 0.25, 1.0), "The flame's body colour (the dressing sets the light's colour here).")
    core = g.vector("Core Color", (1.0, 0.93, 0.78, 1.0), "White-hot: the foot of the flame.")
    tip = g.vector("Tip Color", (0.55, 0.08, 0.01, 1.0), "Dark red: the tip.")
    strength = g.scalar("Strength", 1.6, 0.0, 10.0, "Brightness on screen (exposure-independent: 1 is about white, the core blooms above about 2).")
    exposure = g.scalar("Exposure Independence", 1.0, 0.0, 1.0, "1: the flame looks equally bright in daylight and in a dark crypt (through EyeAdaptationInverse); 0: it follows the scene's exposure like any emissive.")
    feather = g.scalar("Edge Feather", 0.05, 0.0, 0.5, "How soft the flame's outline is, in card half-widths.")
    softness = g.scalar("Edge Softness", 0.3, 0.01, 1.0, "How far in from the edge the flame darkens, in card half-widths.")
    g.group("Flicker")
    speed = g.scalar("Flicker Speed", 1.8, 0.0, 4.0, "How fast the flame dances.")
    amount = g.scalar("Flicker Amount", 0.18, 0.0, 1.0, "How far the brightness swings round its mean.")
    g.group("Erosion")
    scale = g.scalar("Noise Scale", 2.6, 0.5, 12.0, "Coarse cells across the card: the body's warp and erosion.")
    nspeed = g.scalar("Noise Speed", 4.5, 0.0, 12.0, "How fast the coarse noise scrolls up the flame.")
    dscale = g.scalar("Detail Scale", 7.0, 1.0, 24.0, "Fine cells across the card: the licking edge and the torn tip.")
    dspeed = g.scalar("Detail Speed", 9.0, 0.0, 24.0, "How fast the fine noise scrolls up the flame.")
    warp = g.scalar("Warp", 0.3, 0.0, 1.0, "How far the upper flame wavers side to side.")
    erode = g.scalar("Erode", 0.55, 0.0, 1.5, "How deep the noise eats into the edge.")
    tear = g.scalar("Tear", 0.38, 0.0, 1.0, "Above mid-height, fine noise below this is cut out: the top tears into licks.")
    g.group("Motion")
    wave_amount = g.scalar("Trail Ripple", 0.35, 0.0, 1.0, "How far the ripple travelling up a trailing flame swings, as "
                                                          "a share of the trail.")
    wave_cycles = g.scalar("Trail Ripple Cycles", 1.3, 0.25, 4.0, "Ripple waves along the flame's height.")
    wave_speed = g.scalar("Trail Ripple Speed", 11.0, 0.0, 30.0, "How fast the ripple travels up the flame (radians/s).")
    exaggerate = g.scalar("Toward Camera Bend", 0.4, 0.0, 3.0, "How much of a lean straight at the camera shows as an outward "
                                                                "bend on screen (first person squashes depth, so it would "
                                                                "otherwise vanish).")
    g.group("Per Flame (Custom Primitive Data)")
    phase = g.scalar("Phase", 0.0, 0.0, 1.0, "Custom primitive data 0: this flame's random phase.")
    phase.set_editor_property("use_custom_primitive_data", True)
    phase.set_editor_property("primitive_data_index", 0)
    intensity = g.scalar("Intensity", 1.0, 0.0, 1.0, "Custom primitive data 1: the kernel's brightness, 0 dark.")
    intensity.set_editor_property("use_custom_primitive_data", True)
    intensity.set_editor_property("primitive_data_index", 1)
    lean = g.vector("Lean", (0.0, 0.0, 0.0, 0.0), "Custom primitive data 2-5: where the tip is pushed, world cm (xyz); "
                    "w = 1 behind glass (a smaller bend).", ("X", "Y", "Z", "Enclosed"), cpd=2)
    height = g.scalar("Height", 100.0, 1.0, 200.0, "Custom primitive data 6: the flame's height, cm.")
    height.set_editor_property("use_custom_primitive_data", True)
    height.set_editor_property("primitive_data_index", 6)
    width = g.scalar("Width", 62.0, 1.0, 200.0, "Custom primitive data 7: the flame's width, cm.")
    width.set_editor_property("use_custom_primitive_data", True)
    width.set_editor_property("primitive_data_index", 7)

    x, y = -1500, -900
    uv = g.expr(unreal.MaterialExpressionTextureCoordinate, x, y)
    time = g.expr(unreal.MaterialExpressionTime, x, y + 120)
    wp = g.expr(unreal.MaterialExpressionWorldPosition, x, y + 240)
    wp.set_editor_property("world_position_shader_offset", unreal.WorldPositionIncludedOffsets.WPT_EXCLUDE_ALL_SHADER_OFFSETS)
    obj = g.expr(unreal.MaterialExpressionObjectPositionWS, x, y + 360)
    cam = g.expr(unreal.MaterialExpressionCameraPositionWS, x, y + 600)
    flicker = g.custom("Flicker", hlsl.FLAME_CARD_FLICKER_HLSL, [("Time", time, ""), ("Speed", speed, ""), ("Phase", phase, ""),
                                                                 ("Amount", amount, "")], -1000, y, out=FLOAT3)
    puv = g.custom("Phased UV", hlsl.PHASED_UV_HLSL, [("UV", uv, ""), ("Phase", phase, "")], -1250, y + 300,
                   out=unreal.CustomMaterialOutputType.CMOT_FLOAT2)
    noise = g.custom("Erosion Noise", hlsl.NOISE_HLSL, [("UV", puv, ""), ("Time", time, ""), ("Scale", scale, ""), ("Speed", nspeed, "")],
                     -1000, y + 300, out=FLOAT1)
    detail = g.custom("Detail Noise", hlsl.NOISE_HLSL, [("UV", puv, ""), ("Time", time, ""), ("Scale", dscale, ""), ("Speed", dspeed, "")],
                      -1000, y + 420, out=FLOAT1)
    view_fwd = g.custom("View Forward", hlsl.VIEW_FORWARD_HLSL, [], -1000, y + 700, out=FLOAT3)
    # a vector parameter's first pin is RGB: Lean takes the RGBA output for its w (enclosed)
    vs = g.custom("Flame Card VS", hlsl.FLAME_CARD_VS_HLSL,
                  [("UV", uv, ""), ("WP", wp, ""), ("ObjPos", obj, ""), ("Cam", cam, ""), ("ViewFwd", view_fwd, ""),
                   ("Height", height, ""), ("Width", width, ""), ("Exaggerate", exaggerate, ""), ("Time", time, ""),
                   ("Phase", phase, ""), ("WaveAmount", wave_amount, ""), ("WaveCycles", wave_cycles, ""),
                   ("WaveSpeed", wave_speed, ""), ("Lean", lean, "RGBA"),
                   ("Flicker", flicker, "")], -400, y + 500, out=FLOAT3)
    ps = g.custom("Flame Card PS", hlsl.FLAME_CARD_PS_HLSL,
                  [("UV", uv, ""), ("Noise", noise, ""), ("Detail", detail, ""), ("Flicker", flicker, ""), ("Intensity", intensity, ""),
                   ("Softness", softness, ""), ("Strength", strength, ""), ("Core", core, ""), ("Tip", tip, ""), ("Colour", colour, ""),
                   ("Warp", warp, ""), ("Erode", erode, ""), ("Tear", tear, ""), ("Feather", feather, "")],
                  -400, y, out=FLOAT3, extra=(("Mask", FLOAT1),))
    eye = g.expr(unreal.MaterialExpressionEyeAdaptationInverse, -150, y - 200)
    if not any(MEL.connect_material_expressions(ps, "", eye, n) for n in ("LightValue", "LightValueInput", "Light Value")):
        _warn("FlameCard_Mars_M: could not connect the flame to EyeAdaptationInverse; it will follow the scene exposure")
        eye = ps
    emissive = g.custom("Exposure Blend", "return lerp(Scene, Adapted, saturate(K));",
                        [("Scene", ps, ""), ("Adapted", eye, ""), ("K", exposure, "")], 50, y - 200, out=FLOAT3)
    ps.set_editor_property("include_file_paths", [CKUSF_INCLUDE])
    g.finish({"EmissiveColor": (emissive, ""), "Opacity": (ps, "Mask"), "WorldPositionOffset": (vs, "")}, 300, y + 200)
    return m


CARD_MESH_FOLDER = FX_FOLDER + "/Meshes"
CARD_MESH = "FlameCard_Mars_SM"
CARD_ROWS = 48


CARD_OBJ = os.path.join(r"D:\Repo\Mars\Saved\FlameFx", CARD_MESH + ".obj")


def write_card_obj(path=CARD_OBJ, rows=CARD_ROWS):
    """The strip as an OBJ file (plain text): 2 columns of vertices by rows + 1, 100 x 100 cm, centred, in the OBJ's
    X / Y plane, UV u across and v up (OBJ convention: v = 1 at the tip row). Returns the path."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    lines = ["# FlameCard_Mars_SM: the flame card strip (mars_flame_ue.write_card_obj)", "o FlameCard"]
    for r in range(rows + 1):
        t = r / float(rows)                                    # 0 at the tip row .. 1 at the foot row
        for c in range(2):
            lines.append("v %.4f %.4f 0.0" % (-50.0 + 100.0 * c, 50.0 - 100.0 * t))
    for r in range(rows + 1):
        t = r / float(rows)
        for c in range(2):
            lines.append("vt %.6f %.6f" % (float(c), 1.0 - t))
    lines.append("vn 0 0 1")
    lines.append("usemtl Flame")
    for r in range(rows):
        a0, b0 = r * 2 + 1, r * 2 + 2                          # OBJ indices are 1-based
        a1, b1 = a0 + 2, b0 + 2
        lines.append("f %d/%d/1 %d/%d/1 %d/%d/1" % (a0, a0, a1, a1, b0, b0))
        lines.append("f %d/%d/1 %d/%d/1 %d/%d/1" % (b0, b0, a1, a1, b1, b1))
    with open(path, "w") as fh:
        fh.write("\n".join(lines) + "\n")
    return path


def build_card_mesh(rows=CARD_ROWS):
    """FlameCard_Mars_SM: the strip imported from its OBJ as a NEW asset (an existing one is deleted first, never rebuilt
    in place: rebuilding a live mesh's geometry from Python crashed the interactive editor, 2026-10-30). Run it in the
    hidden editor (9317), never in one someone is using. Only its UVs matter to the shader (UV.y 0 at the tip .. 1 at the
    foot, checked after the import and reported); its extent sizes the bounds. One slot, FlameCard_Mars_MI."""
    if mc._in_pie():
        raise RuntimeError("stop PIE before importing")
    path = "%s/%s" % (CARD_MESH_FOLDER, CARD_MESH)
    if EAL.does_asset_exist(path):
        EAL.delete_asset(path)
    obj = write_card_obj(rows=rows)
    task = mc._task(obj, CARD_MESH_FOLDER, CARD_MESH)
    mc._tools().import_asset_tasks([task])
    mesh = mc._asset(CARD_MESH_FOLDER, CARD_MESH)
    if mesh is None:
        raise RuntimeError("the card OBJ did not import to %s" % path)
    mi = mc._asset(F_MAT, INSTANCES["FlameCard_Mars_M"])
    mesh.set_material(0, mi)
    mesh.set_editor_property("allow_cpu_access", False)
    EAL.save_loaded_asset(mesh)
    sme = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
    report = {"path": path, "verts": sme.get_number_verts(mesh, 0), "bounds": str(mesh.get_bounds().box_extent)}
    # which end of the strip is UV.y 0: the tip (+Y in the OBJ) is what the shader expects
    try:
        smd = mesh.get_static_mesh_description(0)
        top = None
        for i in range(smd.get_vertex_instance_count()):
            vi = unreal.VertexInstanceID(i)
            pos = smd.get_vertex_position(smd.get_vertex_instance_vertex(vi))
            uv = smd.get_vertex_instance_uv(vi, 0)
            if top is None or pos.z > top[0] or pos.y > top[1]:
                top = (pos.z, pos.y, uv.y)
        report["uv_y_at_top"] = top[2] if top else None
    except Exception as exc:
        report["uv_check"] = "skipped: %s" % exc
    _log("card mesh: %s" % report)
    return report


def build_materials():
    """The three masters (in place) and one instance of each; instance values an artist changed survive a rebuild."""
    made = []
    for build, master in ((build_flame_card, "FlameCard_Mars_M"), (build_flame_sprite, "FlameSprite_Mars_M"),
                          (build_ember_sprite, "EmberSprite_Mars_M"), (build_flame_glow, "FlameGlow_Mars_M")):
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
    _log("flame materials: %s" % made)
    return made


def instance_path(master):
    inst = INSTANCES[master]
    return "%s/%s.%s" % (F_MAT, inst, inst)
