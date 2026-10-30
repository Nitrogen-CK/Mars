"""Editor side of the Mars FLAME effect (Flame_Mars_NS): builds the three Niagara sprite materials and one instance of
each under /Game/Mars/Fx/Flame/Materials. Runs INSIDE a Mars editor (through Monolith: mars_flame_niagara calls it, or
env_drive.py --module mars_flame_ue --alias mf --call "mf.build_materials()").

    FlameSprite_Mars_M   unlit additive sprite: teardrop SDF (CkUsf_SdfEdgeAA) eroded by scrolling value noise, per-sprite
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

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary
FLOAT1 = unreal.CustomMaterialOutputType.CMOT_FLOAT1
FLOAT3 = unreal.CustomMaterialOutputType.CMOT_FLOAT3

FX_FOLDER = "/Game/Mars/Fx/Flame"
F_MAT = FX_FOLDER + "/Materials"
MASTERS = ("FlameSprite_Mars_M", "EmberSprite_Mars_M", "FlameGlow_Mars_M")
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
    """UV0, the dynamic parameter (slot 0), the particle colour: the shared head of the three graphs."""
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
                   [("UV", uv, ""), ("Dyn", dyn, ""), ("PC", pc, ""), ("Noise", noise, ""), ("Time", time, ""),
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
    col = g.custom("Ember Sprite", hlsl.EMBER_SPRITE_HLSL, [("UV", uv, ""), ("Dyn", dyn, ""), ("PC", pc, ""), ("Strength", strength, "")],
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
    strength = g.scalar("Strength", 0.8, 0.0, 10.0, "Emissive strength of the glow's centre.")
    falloff = g.scalar("Falloff", 2.2, 0.5, 8.0, "Higher keeps the glow nearer the flame.")
    uv, dyn, pc = _particle_head(g, -1500, -700)
    col = g.custom("Flame Glow", hlsl.FLAME_GLOW_HLSL, [("UV", uv, ""), ("Dyn", dyn, ""), ("PC", pc, ""), ("Strength", strength, ""),
                                                        ("Falloff", falloff, "")], -800, -500, out=FLOAT3)
    _finish(g, col)
    return m


def build_materials():
    """The three masters (in place) and one instance of each; instance values an artist changed survive a rebuild."""
    made = []
    for build, master in ((build_flame_sprite, "FlameSprite_Mars_M"), (build_ember_sprite, "EmberSprite_Mars_M"),
                          (build_flame_glow, "FlameGlow_Mars_M")):
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
