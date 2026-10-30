"""Editor side of the Mars environment DRESSING kit (Tools/Blender/mars_environment): imports the family FBXs from
D:\\Repo\\Content\\Environment\\Dressing\\export into /Game/Mars/Environment/Dressing/Meshes/<Family>, builds the dressing
masters and one instance per env_spec slot, and binds every mesh slot to <Slot>_Mars_MI.

    import sys, importlib
    sys.path.insert(0, r"D:\\Repo\\Mars\\Tools\\Blender\\mars_environment\\unreal")
    import mars_env_ue as me; importlib.reload(me)
    me.run_all()                 # build_materials, import_meshes, assign_slots

Masters (rebuilt IN PLACE: the same UMaterial is emptied and refilled, never replaced, because replacing a master while
instances of it are on screen asserts in the renderer):
  EnvPaint_Mars_M    opaque lit; the painted vertex colour (RGB albedo, A cavity) x Tint, plus the kit's BREAKUP so many
                     copies never repeat: a hue / value jitter per instance (PerInstanceRandom) and per placed actor
                     (object-position hash), world-space grime patches, moss on up-facing faces, wetness (darker,
                     glossier). Works on static meshes, instanced static meshes and spline meshes.
  EnvFoliage_Mars_M  two-sided foliage; the same colour model with a per-leaf jitter from UV1.u ("EnvData" id) and a
                     wind sway (world position offset) weighted by UV1.v (0 at the attachment, 1 at the tip).
Both masters read four "Env Data" floats (group Env Data): PerInstanceCustomData slot i, whose default is the Custom
Primitive Data scalar "Env Data i" (CPD index i). Every slot is ZERO-NEUTRAL, because a primitive without custom data
reads 0 for both (the CPD buffer is zero-filled, PrimitiveUniformShaderParametersBuilder.h), so every prop placed
before the vine generator, and any merge bake that drops per-instance data, looks exactly as it did:
  EnvPaint_Mars_M    0 VarSeed (hue/value shift)  1 MossAdd (moss x (1 + v))  2 WetAdd (wetness + v)  3 reserved
  EnvFoliage_Mars_M  0 VarSeed (+ the UV1 id)     1 Dryness (lerp to Dry Color)  2 WindAdd (strength x (1 + v))
                     3 LengthAdd (strength x lerp(1, 1 + v, Length Sway): v = length / 100 cm - 1, so a 3 m strand sways
                       three times as far as a 1 m one)
Stone slots are children of the kit's own StoneWall_<Biome>_Mars_MI (so a prop wears exactly the wall's texture and
paint wash); glow slots are children of Emissive_Mars_M; the flame slot is a child of the candle set's CandleFlame_Mars_M.
Instance values an artist edits survive a rerun (presets are only written when an instance is created, unless
force=True).
"""
import glob
import json
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
ENV_DIR = os.path.dirname(HERE)
COOKING_UE = os.path.join(os.path.dirname(ENV_DIR), "mars_cooking", "unreal")
for _p in (HERE, ENV_DIR, COOKING_UE):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import env_spec as spec          # noqa: E402  (plain python, no bpy)
import mars_cooking_ue as mc     # noqa: E402  (_Graph, _task, _asset, _tools, _in_pie)

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary
FLOAT1 = unreal.CustomMaterialOutputType.CMOT_FLOAT1
FLOAT3 = unreal.CustomMaterialOutputType.CMOT_FLOAT3

PAINT_MASTER, FOLIAGE_MASTER = "EnvPaint_Mars_M", "EnvFoliage_Mars_M"
KIT_MATERIALS = "/Game/Mars/Environment/Materials"
EMISSIVE = KIT_MATERIALS + "/Emissive_Mars_M"
CANDLE_FLAME = "/Game/Mars/Gameplay/Cooking/Candles/Materials/CandleFlame_Mars_M"
BIOMES = ("Bellfold", "Spillring", "Rootstep")


def _log(msg):
    unreal.log("[env] %s" % msg)


def _warn(msg):
    unreal.log_warning("[env] %s" % msg)


def _load(path):
    """Asset by package path (does_asset_exist lags after a replace, so fall back to load_object)."""
    name = path.rsplit("/", 1)[-1]
    obj = unreal.find_object(None, "%s.%s" % (path, name))
    if obj is None and EAL.does_asset_exist(path):
        obj = EAL.load_asset(path)
    return obj


# ------------------------------------------------------------------ HLSL
# A repeatable 0..1 number per instance and per placed actor, then the painted colour jittered in value and hue.
VARIATION_HLSL = """float h = frac(sin(dot(floor(ObjPos * 0.01), float3(12.9898, 78.233, 37.719))) * 43758.5453);
float r = frac(h + Rand * 7.137 + Extra * 3.31);
float v = r * 2.0 - 1.0;
float hv = frac(r * 13.17 + 0.37) * 2.0 - 1.0;
float3 c = Col * Tint.rgb;
c *= lerp(1.0, Alpha, Cavity);
c *= 1.0 + v * ValueVar;
c *= float3(1.0 + hv * HueVar, 1.0 + hv * HueVar * 0.25, 1.0 - hv * HueVar);
return max(c, 0.0);"""

# fbm value noise in world space (metres / scale), no textures. Used for grime patches and moss breakup. Each call
# declares its own names (suffix) so two noises can live in one custom node.
def _noise(src, out):
    return """float3 q_{o} = {src};
float {o} = 0.0, amp_{o} = 0.5;
[unroll] for (int oct_{o} = 0; oct_{o} < 3; oct_{o}++)
{{
    float3 i_{o} = floor(q_{o});
    float3 f_{o} = frac(q_{o});
    f_{o} = f_{o} * f_{o} * (3.0 - 2.0 * f_{o});
    float s_{o} = 0.0;
    [unroll] for (int c_{o} = 0; c_{o} < 8; c_{o}++)
    {{
        float3 k_{o} = float3(c_{o} & 1, (c_{o} >> 1) & 1, (c_{o} >> 2) & 1);
        float h_{o} = frac(sin(dot(i_{o} + k_{o}, float3(127.1, 311.7, 74.7))) * 43758.5453);
        float3 w_{o} = lerp(1.0 - f_{o}, f_{o}, k_{o});
        s_{o} += h_{o} * w_{o}.x * w_{o}.y * w_{o}.z;
    }}
    {o} += s_{o} * amp_{o};
    amp_{o} *= 0.5;
    q_{o} = q_{o} * 2.03 + 17.1;
}}
{o} /= 0.875;
""".format(src=src, o=out)


# grime patches, moss on top faces, wetness -> albedo (Rough = roughness, the custom node's second output)
LAYERS_HLSL = (_noise("WP * 0.01 / max(GrimeScale, 0.05)", "ng") + _noise("WP * 0.01 / max(MossScale, 0.05) + 31.7", "nm") +
               """float grime = saturate((ng - (1.0 - GrimeAmount)) * 3.0);
float3 c = lerp(Base, Base * GrimeColor.rgb, grime);
float up = saturate((N.z - (1.0 - MossFacing)) / max(MossFacing, 0.05));
float moss = saturate((up * nm - (1.0 - MossAmount)) * 4.0) * step(0.001, MossAmount);
c = lerp(c, MossColor.rgb * (0.75 + 0.5 * nm), moss);
float wet = saturate(Wetness);
c *= lerp(1.0, 0.5, wet);
Rough = lerp(lerp(Roughness, 0.95, moss), 0.1, wet * (1.0 - moss * 0.6));
return c;""")

# leaves: sway along the wind direction plus a flutter, weighted by flex^2, out of step per leaf and per place
WIND_HLSL = """float f = saturate(Flex);
float ph = Id * 6.2831 + dot(WP, float3(0.0071, 0.0053, 0.0029)) + Rand * 4.1;
float t = Time * Speed;
float sway = sin(t + ph) * 0.65 + sin(t * 2.31 + ph * 1.7) * 0.35;
float flutter = sin(t * 7.9 + ph * 3.3) * Flutter;
float3 d = normalize(float3(Dir.x, Dir.y, 0.0) + 1e-4);
return (d * sway + float3(-d.y, d.x, 0.0) * flutter + float3(0.0, 0.0, -abs(sway) * 0.25)) * Strength * f * f;"""


# ------------------------------------------------------------------ masters
def _master(name):
    """The master at UE_MATERIALS, emptied in place if it exists (delete_all_material_expressions skips nodes: loop)."""
    m = _load("%s/%s" % (spec.UE_MATERIALS, name))
    if m is None:
        return mc._tools().create_asset(name, spec.UE_MATERIALS, unreal.Material, unreal.MaterialFactoryNew())
    for _ in range(16):
        if MEL.get_num_material_expressions(m) == 0:
            break
        MEL.delete_all_material_expressions(m)
    return m


def _usage(m):
    for prop in ("used_with_instanced_static_meshes", "used_with_spline_meshes", "used_with_static_lighting"):
        try:
            m.set_editor_property(prop, True)
        except Exception:
            pass


def _uv1(g, x, y):
    uv = g.expr(unreal.MaterialExpressionTextureCoordinate, x, y)
    uv.set_editor_property("coordinate_index", 1)
    masks = []
    for i, ch in enumerate("rg"):
        mk = g.expr(unreal.MaterialExpressionComponentMask, x + 220, y + i * 120)
        for c in "rgba":
            mk.set_editor_property(c, c == ch)
        g.link(uv, "", mk, "")
        masks.append(mk)
    return masks


def _surface_params(g, rough, spec_, metal):
    g.group("Surface")
    tint = g.vector("Tint", (1.0, 1.0, 1.0, 1.0), "Multiplies the painted vertex colour.")
    cavity = g.scalar("Cavity AO", 0.55, 0.0, 1.0, "How far the painted cavity (vertex alpha) darkens the colour.")
    r = g.scalar("Roughness", rough, 0.0, 1.0)
    s = g.scalar("Specular", spec_, 0.0, 1.0)
    mt = g.scalar("Metallic", metal, 0.0, 1.0)
    g.group("Variation")
    hue = g.scalar("Hue Variation", 0.05, 0.0, 0.3, "Warm/cool shift per instance and per placed actor.")
    val = g.scalar("Value Variation", 0.14, 0.0, 0.5, "Brighter/darker per instance and per placed actor.")
    return tint, cavity, r, s, mt, hue, val


ENV_DATA_DESC = {
    PAINT_MASTER: ("VarSeed: shifts the per-instance hue / value pick (0 = none).",
                   "MossAdd: moss amount x (1 + this); MossScale - 1 (0 = as authored).",
                   "WetAdd: added to Wetness (0 = none).",
                   "Reserved (0)."),
    FOLIAGE_MASTER: ("VarSeed: added to the UV1 leaf id for the colour pick and the wind phase (0 = none).",
                     "Dryness: blend toward Dry Color (0 = green).",
                     "WindAdd: wind strength x (1 + this); WindWeight - 1 (0 = as authored).",
                     "LengthAdd: length / 100 cm - 1 of a stretched strand card; scales the sway by Length Sway "
                     "(0 = a 100 cm card)."),
}


def _env_data(g, master, x, y):
    """Four zero-neutral data floats: PerInstanceCustomData(i) with its default from the CPD scalar 'Env Data i'."""
    g.group("Env Data")
    outs = []
    for i in range(4):
        p = g.scalar("Env Data %d" % i, 0.0, -1.0, 4.0, ENV_DATA_DESC[master][i])
        p.set_editor_property("use_custom_primitive_data", True)
        p.set_editor_property("primitive_data_index", i)
        pic = g.expr(unreal.MaterialExpressionPerInstanceCustomData, x, y + i * 110)
        pic.set_editor_property("data_index", i)
        pic.set_editor_property("const_default_value", 0.0)
        g.link(p, "", pic, "DefaultValue")
        outs.append(pic)
    return outs


def build_paint_master():
    m = _master(PAINT_MASTER)
    m.set_editor_property("shading_model", unreal.MaterialShadingModel.MSM_DEFAULT_LIT)
    m.set_editor_property("two_sided", False)
    _usage(m)
    g = mc._Graph(m, -3200)
    tint, cavity, rough, spec_, metal, hue, val = _surface_params(g, 0.7, 0.45, 0.0)
    g.group("Grime")
    gamt = g.scalar("Grime Amount", 0.3, 0.0, 1.0, "Share of the surface under darker world-space grime patches.")
    gscale = g.scalar("Grime Scale", 0.8, 0.05, 10.0, "Grime patch size in metres.")
    gcol = g.vector("Grime Color", (0.55, 0.5, 0.46, 1.0), "Multiplies the colour under grime.")
    g.group("Moss")
    mamt = g.scalar("Moss Amount", 0.0, 0.0, 1.0, "Moss on up-facing faces (0 = none).")
    mcol = g.vector("Moss Color", (0.075, 0.105, 0.03, 1.0), "Linear moss colour.")
    mscale = g.scalar("Moss Scale", 0.5, 0.05, 10.0, "Moss patch size in metres.")
    mface = g.scalar("Moss Facing", 0.45, 0.05, 1.0, "How far from straight up a face may tilt and still grow moss.")
    g.group("Wet")
    wet = g.scalar("Wetness", 0.0, 0.0, 1.0, "Darker and glossier (puddle splash zones, leaking walls).")

    d0, d1, d2, _d3 = _env_data(g, PAINT_MASTER, -2300, -200)
    vc = g.expr(unreal.MaterialExpressionVertexColor, -1900, -1100)
    rand = g.expr(unreal.MaterialExpressionPerInstanceRandom, -1900, -900)
    pos = g.expr(unreal.MaterialExpressionObjectPositionWS, -1900, -800)
    base = g.custom("Painted Colour + Variation", VARIATION_HLSL,
                    [("Col", vc, ""), ("Alpha", vc, "A"), ("Tint", tint, ""), ("Cavity", cavity, ""), ("Rand", rand, ""),
                     ("ObjPos", pos, ""), ("Extra", d0, ""), ("HueVar", hue, ""), ("ValueVar", val, "")],
                    -1500, -1000, out=FLOAT3)
    moss_eff = g.custom("Moss x Env Data", "return saturate(Moss * (1.0 + D1));", [("Moss", mamt, ""), ("D1", d1, "")],
                        -1500, -300, out=FLOAT1)
    wet_eff = g.custom("Wet + Env Data", "return saturate(Wet + D2);", [("Wet", wet, ""), ("D2", d2, "")],
                       -1500, -200, out=FLOAT1)
    wp = g.expr(unreal.MaterialExpressionWorldPosition, -1900, -500)
    nrm = g.expr(unreal.MaterialExpressionVertexNormalWS, -1900, -400)
    layers = g.custom("Grime / Moss / Wet", LAYERS_HLSL,
                      [("Base", base, ""), ("WP", wp, ""), ("N", nrm, ""), ("GrimeAmount", gamt, ""), ("GrimeScale", gscale, ""),
                       ("GrimeColor", gcol, ""), ("MossAmount", moss_eff, ""), ("MossColor", mcol, ""), ("MossScale", mscale, ""),
                       ("MossFacing", mface, ""), ("Wetness", wet_eff, ""), ("Roughness", rough, "")],
                      -1000, -800, out=FLOAT3, extra=[("Rough", FLOAT1)])
    g.finish({"BaseColor": (layers, ""), "Roughness": (layers, "Rough"), "Specular": (spec_, ""), "Metallic": (metal, "")},
             -300, -800)
    return m


def build_foliage_master():
    m = _master(FOLIAGE_MASTER)
    m.set_editor_property("shading_model", unreal.MaterialShadingModel.MSM_TWO_SIDED_FOLIAGE)
    m.set_editor_property("two_sided", True)
    _usage(m)
    g = mc._Graph(m, -3200)
    tint, cavity, rough, spec_, metal, hue, val = _surface_params(g, 0.6, 0.35, 0.0)
    g.group("Backlight")
    sss = g.vector("Subsurface Color", (0.09, 0.13, 0.03, 1.0), "Light through the leaf from behind.")
    g.group("Wind")
    strength = g.scalar("Wind Strength", 1.5, 0.0, 20.0, "Tip sway in cm.")
    speed = g.scalar("Wind Speed", 1.1, 0.0, 6.0)
    flutter = g.scalar("Flutter", 0.35, 0.0, 2.0, "Sideways flutter relative to the sway.")
    wdir = g.vector("Wind Direction", (1.0, 0.35, 0.0, 0.0), "World XY direction of the draught.")
    sway = g.scalar("Length Sway", 1.0, 0.0, 1.0, "How far a stretched strand's length (Env Data 3) scales its sway.")
    g.group("Dry")
    dry = g.vector("Dry Color", (0.12, 0.07, 0.03, 1.0), "Where Env Data 1 (Dryness) blends the leaf to, at its luminance.")

    d0, d1, d2, d3 = _env_data(g, FOLIAGE_MASTER, -2300, -200)
    vc = g.expr(unreal.MaterialExpressionVertexColor, -1900, -1100)
    rand = g.expr(unreal.MaterialExpressionPerInstanceRandom, -1900, -900)
    pos = g.expr(unreal.MaterialExpressionObjectPositionWS, -1900, -800)
    u, v = _uv1(g, -1900, -650)
    uid = g.custom("Leaf Id + Env Data", "return U + D0;", [("U", u, ""), ("D0", d0, "")], -1600, -700, out=FLOAT1)
    base = g.custom("Leaf Colour + Variation", VARIATION_HLSL,
                    [("Col", vc, ""), ("Alpha", vc, "A"), ("Tint", tint, ""), ("Cavity", cavity, ""), ("Rand", rand, ""),
                     ("ObjPos", pos, ""), ("Extra", uid, ""), ("HueVar", hue, ""), ("ValueVar", val, "")],
                    -1300, -1000, out=FLOAT3)
    dried = g.custom("Dryness", "float l = dot(Base, float3(0.2126, 0.7152, 0.0722));\n"
                                "return lerp(Base, Dry.rgb * (l / 0.06), saturate(D1));",
                     [("Base", base, ""), ("Dry", dry, ""), ("D1", d1, "")], -1000, -1000, out=FLOAT3)
    strength_eff = g.custom("Wind x Env Data", "return Strength * max(1.0 + D2, 0.0) * lerp(1.0, max(1.0 + D3, 0.0), Sway);",
                            [("Strength", strength, ""), ("D2", d2, ""), ("D3", d3, ""), ("Sway", sway, "")],
                            -1300, -200, out=FLOAT1)
    wp = g.expr(unreal.MaterialExpressionWorldPosition, -1900, -350)
    wp.set_editor_property("world_position_shader_offset", unreal.WorldPositionIncludedOffsets.WPT_EXCLUDE_ALL_SHADER_OFFSETS)
    time = g.expr(unreal.MaterialExpressionTime, -1900, -250)
    wind = g.custom("Wind", WIND_HLSL,
                    [("Flex", v, ""), ("Id", uid, ""), ("WP", wp, ""), ("Rand", rand, ""), ("Time", time, ""), ("Speed", speed, ""),
                     ("Flutter", flutter, ""), ("Dir", wdir, ""), ("Strength", strength_eff, "")], -1000, -300, out=FLOAT3)
    g.finish({"BaseColor": (dried, ""), "Roughness": (rough, ""), "Specular": (spec_, ""), "SubsurfaceColor": (sss, ""),
              "WorldPositionOffset": (wind, "")}, -300, -800)
    return m


# ------------------------------------------------------------------ instances
# slot -> (parent asset path or master name, scalar presets, vector presets)
def _instance_table():
    paint = "%s/%s" % (spec.UE_MATERIALS, PAINT_MASTER)
    foliage = "%s/%s" % (spec.UE_MATERIALS, FOLIAGE_MASTER)
    wall = KIT_MATERIALS + "/Instances/StoneWall_%s_Mars_MI"
    rows = {
        "EnvBone": (paint, {"Roughness": 0.62, "Specular": 0.45, "Grime Amount": 0.35}, {}),
        "EnvWood": (paint, {"Roughness": 0.78, "Grime Amount": 0.3, "Moss Amount": 0.12}, {}),
        "EnvIron": (paint, {"Roughness": 0.55, "Metallic": 0.35, "Specular": 0.5, "Grime Amount": 0.25}, {}),
        # Tint 2026-10-24 (vignettes): (1, 1.45, 1.8) took the red out but turned the rust olive-green under the sewer's
        # blue key; (1, 1.15, 1.05) keeps it rust-orange in warm light and brown (not khaki) in cold light.
        "EnvRust": (paint, {"Roughness": 0.82, "Metallic": 0.12, "Grime Amount": 0.35, "Hue Variation": 0.08},
                    {"Tint": (1.0, 1.15, 1.05, 1.0)}),
        "EnvBrass": (paint, {"Roughness": 0.4, "Metallic": 0.7, "Grime Amount": 0.3}, {}),
        "EnvCanvas": (paint, {"Roughness": 0.92, "Specular": 0.3, "Grime Amount": 0.4}, {}),
        "EnvCloth": (paint, {"Roughness": 0.85, "Specular": 0.35, "Grime Amount": 0.25}, {}),
        "EnvGold": (paint, {"Roughness": 0.35, "Metallic": 0.75, "Grime Amount": 0.2}, {}),
        "EnvWax": (paint, {"Roughness": 0.45, "Specular": 0.45, "Grime Amount": 0.1, "Value Variation": 0.06}, {}),
        "EnvBark": (paint, {"Roughness": 0.85, "Grime Amount": 0.25, "Moss Amount": 0.35}, {}),
        "EnvMoss": (paint, {"Roughness": 0.95, "Specular": 0.3, "Grime Amount": 0.15, "Hue Variation": 0.1}, {}),
        "EnvLeaf": (foliage, {"Roughness": 0.55}, {}),
        "EnvLeafDry": (foliage, {"Roughness": 0.72, "Wind Strength": 0.4, "Hue Variation": 0.1},
                       {"Subsurface Color": (0.16, 0.07, 0.02, 1.0)}),
        "EnvStrand": (foliage, {"Roughness": 0.9, "Wind Strength": 3.0, "Flutter": 0.15},
                      {"Subsurface Color": (0.06, 0.08, 0.03, 1.0)}),
        "EnvGlowWarm": (EMISSIVE, {"Strength": 8.0}, {"Color": (1.0, 0.72, 0.41, 1.0)}),
        "EnvGlowSpirit": (EMISSIVE, {"Strength": 10.0}, {"Color": (0.35, 0.66, 1.0, 1.0)}),
        "EnvFlame": (CANDLE_FLAME, {}, {}),
        "EnvStone": (wall % "Bellfold", {}, {}),
        "EnvStoneDark": (wall % "Bellfold", {}, {"Tint": (0.55, 0.53, 0.52, 1.0)}),
    }
    for biome in BIOMES[1:]:                     # biome swaps for the stone slots (assign per placement)
        rows["EnvStone_%s" % biome] = (wall % biome, {}, {})
        rows["EnvStoneDark_%s" % biome] = (wall % biome, {}, {"Tint": (0.55, 0.53, 0.52, 1.0)})
    return rows


def _instance(name, parent_path, scalars, vectors, force=False):
    path = "%s/%s" % (spec.UE_INSTANCES, name)
    mi = _load(path)
    created = mi is None
    if created:
        mi = mc._tools().create_asset(name, spec.UE_INSTANCES, unreal.MaterialInstanceConstant,
                                      unreal.MaterialInstanceConstantFactoryNew())
    parent = _load(parent_path)
    if parent is None:
        _warn("%s: parent %s is missing" % (name, parent_path))
        return mi
    MEL.set_material_instance_parent(mi, parent)
    if created or force:
        for k, v in scalars.items():
            MEL.set_material_instance_scalar_parameter_value(mi, k, v)
        for k, v in vectors.items():
            MEL.set_material_instance_vector_parameter_value(mi, k, unreal.LinearColor(*v))
    MEL.update_material_instance(mi)
    EAL.save_loaded_asset(mi)
    return mi


def build_materials(force_presets=False):
    """Both masters in place, then one instance per slot (and the stone biome swaps)."""
    made = []
    for build, name in ((build_paint_master, PAINT_MASTER), (build_foliage_master, FOLIAGE_MASTER)):
        m = build()
        stats = MEL.get_statistics(m)
        made.append((name, MEL.get_num_material_expressions(m), stats.num_pixel_shader_instructions))
    rows = _instance_table()
    for slot, (parent, scalars, vectors) in rows.items():
        _instance("%s_Mars_MI" % slot, parent, scalars, vectors, force=force_presets)
    _log("dressing materials: %s, %d instances" % (made, len(rows)))
    return {"masters": made, "instances": sorted("%s_Mars_MI" % s for s in rows)}


# ------------------------------------------------------------------ meshes
def read_metas(only=None):
    metas = []
    for p in sorted(glob.glob(os.path.join(spec.EXPORT_DIR, "*_Mars_SM.json"))):
        try:
            with open(p) as fh:
                meta = json.load(fh)
        except Exception as exc:
            _warn("%s unreadable: %s" % (p, exc))
            continue
        if "env_family" not in meta:
            continue
        if only and not any(o.lower() in meta["name"].lower() or o == meta["env_family"] for o in only):
            continue
        meta["_fbx"] = os.path.splitext(p)[0] + ".fbx"
        metas.append(meta)
    return metas


def import_meshes(only=None):
    """Legacy FBX import (Interchange off for the batch: it drops UCX): authored normals, vertex colours replaced, no
    lightmap UV generation (UV1 is data), UCX hulls kept one per piece, sockets from SOCKET_ empties. A mesh exported
    without UCX gets no simple collision at all (scatter, cards, foliage)."""
    if mc._in_pie():
        raise RuntimeError("stop PIE before importing (assets imported during PIE vanish)")
    metas = [m for m in read_metas(only) if os.path.isfile(m["_fbx"])]
    if not metas:
        _warn("no dressing FBX in %s" % spec.EXPORT_DIR)
        return []
    tasks = []
    for meta in metas:
        task = mc._task(meta["_fbx"], meta["ue_folder"], meta["name"])
        opts = unreal.FbxImportUI()
        opts.import_mesh = True
        opts.import_as_skeletal = False
        opts.import_materials = False
        opts.import_textures = False
        sm = opts.static_mesh_import_data
        sm.combine_meshes = True
        sm.generate_lightmap_u_vs = False
        sm.auto_generate_collision = False
        sm.set_editor_property("normal_import_method", unreal.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS)
        for prop, value in (("vertex_color_import_option", unreal.VertexColorImportOption.REPLACE), ("build_nanite", False),
                            ("remove_degenerates", True), ("one_convex_hull_per_ucx", True)):
            try:
                sm.set_editor_property(prop, value)
            except Exception:
                pass
        task.options = opts
        tasks.append(task)
    cvar = "Interchange.FeatureFlags.Import.FBX"
    was = unreal.SystemLibrary.get_console_variable_bool_value(cvar)
    unreal.SystemLibrary.execute_console_command(None, "%s 0" % cvar)
    try:
        mc._tools().import_asset_tasks(tasks)
    finally:
        unreal.SystemLibrary.execute_console_command(None, "%s %d" % (cvar, 1 if was else 0))
    sme = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
    reports = []
    for meta in metas:
        mesh = _load("%s/%s" % (meta["ue_folder"], meta["name"]))
        if mesh is None:
            _warn("mesh %s did not import" % meta["name"])
            continue
        if not meta.get("ucx_pieces"):
            try:
                sme.remove_collisions(mesh)
            except Exception as exc:
                _warn("%s: remove_collisions failed: %s" % (meta["name"], exc))
        reports.append({"name": meta["name"], "folder": meta["ue_folder"], "uv_channels": sme.get_num_uv_channels(mesh, 0),
                        "collision_prims": sme.get_simple_collision_count(mesh),
                        "sockets": _socket_count(mesh, meta)})
        EAL.save_loaded_asset(mesh)
    _log("%d of %d dressing meshes imported" % (len(reports), len(metas)))
    return reports


def _socket_count(mesh, meta):
    """StaticMesh.Sockets is protected from Python: count the sidecar's sockets the mesh can find by name."""
    found = 0
    for name in (meta.get("sockets") or {}):
        try:
            if mesh.find_socket(name) is not None:
                found += 1
        except Exception:
            pass
    return found


def assign_slots(only=None):
    """Bind every mesh slot to <Slot>_Mars_MI in UE_INSTANCES."""
    n, missing = 0, set()
    for meta in read_metas(only):
        mesh = _load("%s/%s" % (meta["ue_folder"], meta["name"]))
        if mesh is None:
            continue
        for i, sm in enumerate(mesh.get_editor_property("static_materials")):
            slot = str(sm.get_editor_property("material_slot_name")).split(".")[0]
            mi = _load("%s/%s_Mars_MI" % (spec.UE_INSTANCES, slot))
            if mi is None:
                missing.add(slot)
                continue
            mesh.set_material(i, mi)
            n += 1
        EAL.save_loaded_asset(mesh)
    if missing:
        _warn("no instance for slots %s" % sorted(missing))
    _log("%d dressing slots assigned" % n)
    return {"assigned": n, "missing": sorted(missing)}


def run_all(only=None):
    mats = build_materials()
    meshes = import_meshes(only)
    slots = assign_slots(only)
    return {"materials": mats, "meshes": meshes, "slots": slots}


# ------------------------------------------------------------------ reflections
# Authored crypt cubemaps (build_env_hdr.py). Mars renders with r.ReflectionMethod=0, so every wet floor, puddle, water
# surface and metal shines only through reflection captures. A SPECIFIED-cubemap capture reflects the same in the
# editor, PIE and cooked builds, with no capture build; captured-scene captures stayed black in the hidden editor.
HDRS = {"warm": "CryptWarm_Mars_HDR", "cold": "CryptCold_Mars_HDR"}
HDR_DIR = os.path.join(spec.EXPORT_DIR, "textures")


def import_hdrs():
    """Import (or re-import in place) the two lat-long HDRs as TextureCubes into UE_TEXTURES."""
    if mc._in_pie():
        raise RuntimeError("stop PIE before importing")
    tasks = []
    for name in HDRS.values():
        src = os.path.join(HDR_DIR, name + ".hdr")
        if not os.path.isfile(src):
            _warn("%s missing: run build_env_hdr.py" % src)
            continue
        tasks.append(mc._task(src, spec.UE_TEXTURES, name))
    if tasks:
        mc._tools().import_asset_tasks(tasks)
    out = {}
    for kind, name in HDRS.items():
        tex = _load("%s/%s" % (spec.UE_TEXTURES, name))
        out[kind] = type(tex).__name__ if tex else None
        if tex:
            EAL.save_loaded_asset(tex)
    _log("crypt cubemaps: %s" % out)
    return out


def place_reflection(loc, radius=1200.0, kind="warm", label="Reflections", folder="Dressing/Rig", brightness=1.0):
    """A sphere reflection capture on one of the crypt cubemaps. Box captures size their influence from the actor
    scale in CENTIMETRES (a unit box x scale, minus box_transition_distance), which is easy to get wrong; prefer this."""
    eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    a = eas.spawn_actor_from_class(unreal.SphereReflectionCapture, unreal.Vector(*loc))
    a.set_actor_label(label)
    a.set_folder_path(folder)
    set_reflection(a, kind, radius, brightness)
    return a


def set_reflection(actor, kind="warm", radius=None, brightness=1.0):
    """Point an existing reflection capture at a crypt cubemap (and, for sphere captures, set its radius)."""
    c = actor.get_component_by_class(unreal.ReflectionCaptureComponent)
    c.set_editor_property("reflection_source_type", unreal.ReflectionSourceType.SPECIFIED_CUBEMAP)
    c.set_editor_property("cubemap", _load("%s/%s" % (spec.UE_TEXTURES, HDRS[kind])))
    c.set_editor_property("brightness", brightness)
    if radius is not None and isinstance(c, unreal.SphereReflectionCaptureComponent):
        c.set_editor_property("influence_radius", radius)
    return actor
