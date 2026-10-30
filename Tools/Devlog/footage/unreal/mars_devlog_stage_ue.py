"""DevlogStage_Mars_MAP: a curated dark-studio stage for Mise en Monstre devlog renders (Tools/Devlog/CONTRACT.md).

It matches the Blender making-of frames: a seamless dark backdrop (#15151a), a dark floor with a faint 1 m grid, a warm
key / cool rim / soft fill from spot lights with soft shadows, no sun, no sky light, no sky atmosphere, a height fog that
dissolves the far floor into the backdrop, manual exposure. Editor side (a hidden MarsEditor on 9317 through Monolith,
never Stephen's 9316); the host runner is run_stage.py:

    python run_stage.py --build                 # assets + map (idempotent), then the reflection build (second call)
    python run_stage.py --stills [--draft]      # review stills -> D:/Repo/Content/Devlog/stage_review/
    python run_stage.py --call "st.calibrate('turntable')"

Bays (one map, 300 m apart along X so no light, shadow or silhouette reaches a neighbour; every camera stands on the
bay's +Y side looking toward -Y, and the fog swallows anything farther than about 80 m):

    turntable  x 0        one kit piece (or a group) on the grid; subjects swap with set_subject(); spin rotates them
    cooking    x 30000    a dark stone counter at hob height, the hero pan with meat cubes, a second pan + food library meats
    room       x 60000    the crypt_octagon_hub plan as one HISM actor, upper tier and roof cut away, torches inside

Every actor carries the tag DevlogStage plus DevlogStage.<bay>; a rebuild destroys only what it rebuilds. Lights carry
DevlogStage.<bay>.<role> (key / rim / fill / practical). Lighting presets (neutral / warm / cool) re-colour and re-weigh
a bay's key / rim / fill and switch its practical lights; each bay has a default preset. Exposure is one stage EV
(STAGE_EV) for every bay: the bays are balanced with light, not with exposure, so the backdrop, the fog and the floor
read the same everywhere.

Shot presets live in SHOTS (named, per bay): subject, view azimuth / elevation, fov and frame fill; cameras are solved
from the subject's bounds (frame()) so the subject fills 60-80 % of the frame height. resolve(name) returns
{eye, target, fov, t, ...} for a later re-shoot; stills() writes them to stage_review/stage_shots.json too.
"""
import json
import math
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = r"D:\Repo\Mars"
CRYPT_KIT = r"C:\Users\Stephen\Documents\Houdini\Blender\export\crypt_kit"
for _p in (HERE, os.path.join(CRYPT_KIT, "unreal")):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import devlog_unreal_shots as ds  # noqa: E402  (capture rig, post settings, camera maths)

MAP = "/Game/Mars/Maps/DevlogStage_Mars_MAP"
ROOT = "/Game/Mars/Devlog"
F_MAT = ROOT + "/Materials"
TAG = "DevlogStage"
FOLDER = "DevlogStage"
REVIEW = r"D:\Repo\Content\Devlog\stage_review"
SCRATCH = r"C:\Users\Stephen\AppData\Local\Temp\claude\D--Repo-Mars\5f3efb8e-b134-46b6-83b7-6ce0a5233bff\scratchpad\stage_agent"
KIT = "/Game/Mars/Environment/Meshes"
COOK = "/Game/Mars/Gameplay/Cooking"
HDR = {"studio": COOK + "/Textures/CookingStudio_Mars_HDR",
       "warm": "/Game/Mars/Environment/Dressing/Textures/CryptWarm_Mars_HDR",
       "cold": "/Game/Mars/Environment/Dressing/Textures/CryptCold_Mars_HDR"}

FULL = (1920, 1080)
DRAFT = (960, 540)
SUPERSAMPLE = 2           # stills render at 2x and the host downsamples (the project runs r.AntiAliasingMethod=0)

# ---------------------------------------------------------------- look
STAGE_EV = 10.0           # exposure bias for every bay (capture and the map's unbound volume)
BACKDROP = (21, 21, 26)   # Blender backdrop #15151a as measured in the reference frames (8-bit sRGB)
FLOOR = (26, 25, 30)      # the Blender floor between grid lines
# toe 0.32 (UE default 0.55) opens the shadows toward the Blender Filmic frames: at 0.55 everything under ~0.1 crushes
LOOK = {"ev": STAGE_EV, "bloom": 0.12, "vignette": 0.22, "saturation": 0.95, "contrast": 1.0, "toe": 0.32}
FOG = {"density": 0.3, "falloff": 0.001, "start": 6000.0,
       # luminance of the fog (it IS the far backdrop): tuned so the far field reads BACKDROP at STAGE_EV
       "luminance": (0.105, 0.105, 0.124)}

# material defaults (display-referred through EyeAdaptationInverse: independent of the exposure)
BACKDROP_COLOR = (0.118, 0.118, 0.134)     # display-referred (EyeAdaptationInverse): about BACKDROP at toe 0.32
FLOOR_GLOW = (0.128, 0.124, 0.142)    # -> about (26, 25, 30) at toe 0.32 (measured)
LINE_GLOW = (0.26, 0.26, 0.29)
FLOOR_ALBEDO = 0.02
LINE_WIDTH = 0.018        # grid line width, in cells (1 m cells: 1.8 cm)

# lighting presets: key / rim / fill colour (linear-ish 0..1) and illuminance at the subject (lux), fill / rim as
# ratios of the key; practical = the bay's own torches / candles (scale on their authored intensity, 0 = off)
PRESETS = {
    "neutral": {"key": (1.0, 0.93, 0.84), "rim": (0.76, 0.84, 1.0), "fill": (0.86, 0.9, 1.0),
                "key_lux": 12.5, "rim_ratio": 1.4, "fill_ratio": 0.22, "practical": 0.0, "saturation": 0.92},
    "warm": {"key": (1.0, 0.8, 0.58), "rim": (0.6, 0.78, 1.0), "fill": (1.0, 0.78, 0.6),
             "key_lux": 9.0, "rim_ratio": 1.2, "fill_ratio": 0.18, "practical": 1.0, "saturation": 1.0},
    "cool": {"key": (0.84, 0.9, 1.0), "rim": (0.5, 0.75, 1.0), "fill": (0.68, 0.76, 0.92),
             "key_lux": 9.0, "rim_ratio": 1.6, "fill_ratio": 0.2, "practical": 0.0, "saturation": 0.95},
}

# ---------------------------------------------------------------- bays
BAYS = {
    "turntable": {"origin": (0.0, 0.0), "preset": "neutral", "hdr": "studio", "reflection": (1600.0, 0.3)},
    "cooking": {"origin": (30000.0, 0.0), "preset": "neutral", "hdr": "studio", "reflection": (400.0, 0.85),
                # bigger, softer sources than the kit bays (a 30 cm pan under a 70 cm rig radius), a higher fill
                "rig": {"key": (38.0, 50.0, 2.6, 0.32, True), "rim": (-150.0, 35.0, 2.4, 0.2, True),
                        "fill": (-60.0, 30.0, 2.4, 0.6, False)}, "key_scale": 0.9, "fill_scale": 1.6, "rim_scale": 0.6},
    "room": {"origin": (60000.0, 0.0), "preset": "warm", "hdr": "warm", "reflection": (2400.0, 0.5),
             "rig": {"key": (30.0, 62.0, 2.2, 0.03, True), "fill": (-50.0, 40.0, 2.4, 0.2, False)}, "key_scale": 1.3,
             "fill_scale": 2.2},
}
DEFAULT_BAYS = ("turntable", "cooking", "room")
FLOOR_CENTRE = (30000.0, 0.0)
FLOOR_SIZE_M = 2000.0
# a bay's key / rim / fill: (azimuth offset from the bay's camera direction, elevation, distance in subject radii,
# source radius in subject radii, cast shadows); the camera direction is +Y (yaw 90 from the subject)
RIG = {"key": (38.0, 42.0, 2.6, 0.06, True),          # camera-left, high
       "rim": (-155.0, 32.0, 2.4, 0.04, True),        # behind, camera-right
       "fill": (-55.0, 14.0, 2.6, 0.25, False)}       # camera-right, low, big and soft
CAM_AZ = 90.0


# ====================================================================================== editor helpers
def _eas():
    return unreal.get_editor_subsystem(unreal.EditorActorSubsystem)


def _les():
    return unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)


def _world():
    return unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()


def _cvar(cmd):
    unreal.SystemLibrary.execute_console_command(_world(), cmd)


_CACHE = {}


def _load(path):
    if path in _CACHE and _CACHE[path] is not None:
        return _CACHE[path]
    name = path.rsplit("/", 1)[-1]
    obj = unreal.find_object(None, "%s.%s" % (path, name))
    if obj is None and unreal.EditorAssetLibrary.does_asset_exist(path):
        obj = unreal.EditorAssetLibrary.load_asset(path)
    _CACHE[path] = obj
    return obj


def kit(name):
    """'Wall4m' -> Crypt/CryptWall4m_Mars_SM, 'Boxes/BoxStoneBlock1m' -> Boxes/BoxStoneBlock1m_Mars_SM."""
    p = "%s/%s_Mars_SM" % (KIT, name) if "/" in name else "%s/Crypt/Crypt%s_Mars_SM" % (KIT, name)
    m = _load(p)
    if m is None:
        raise RuntimeError("missing mesh %s" % p)
    return m


def dressing(name):
    """A dressing-kit mesh by short name (any family folder), or None."""
    for fam in ("Crypt", "Bones", "Pipes", "Clutter", "Organic", "Vines"):
        m = _load("/Game/Mars/Environment/Dressing/Meshes/%s/%s_Mars_SM" % (fam, name))
        if m is not None:
            return m
    return None


def _tags(bay, *extra):
    return [unreal.Name(TAG), unreal.Name("%s.%s" % (TAG, bay))] + [unreal.Name("%s.%s.%s" % (TAG, bay, e)) for e in extra]


def spawn(obj, loc, bay, label, rot=(0.0, 0.0, 0.0), scale=None, sub="", roles=()):
    """rot = (pitch, yaw, roll). Labels are Stage_<Bay>_<label>."""
    r = unreal.Rotator(roll=rot[2], pitch=rot[0], yaw=rot[1])
    if isinstance(obj, (type, unreal.Class)):
        a = _eas().spawn_actor_from_class(obj, unreal.Vector(*loc), r)
    else:
        a = _eas().spawn_actor_from_object(obj, unreal.Vector(*loc), r)
    if a is None:
        raise RuntimeError("could not spawn %s" % obj)
    if scale is not None:
        a.set_actor_scale3d(unreal.Vector(*((scale,) * 3 if isinstance(scale, (int, float)) else scale)))
    a.set_actor_label("Stage_%s_%s" % (bay.capitalize(), label))
    a.set_folder_path("%s/%s%s" % (FOLDER, bay.capitalize(), "/" + sub if sub else ""))
    a.set_editor_property("tags", _tags(bay, *roles))
    return a


def tagged(bay=None, role=None):
    want = TAG if bay is None else ("%s.%s" % (TAG, bay) if role is None else "%s.%s.%s" % (TAG, bay, role))
    return [a for a in _eas().get_all_level_actors() if want in [str(t) for t in a.get_editor_property("tags")]]


def by_label(label):
    for a in _eas().get_all_level_actors():
        if a.get_actor_label() == label:
            return a
    return None


def _smc(a):
    return a.get_component_by_class(unreal.StaticMeshComponent)


def _bounds_local(mesh):
    b = mesh.get_bounding_box()
    return (b.min.x, b.min.y, b.min.z), (b.max.x, b.max.y, b.max.z)


def _rotz(v, yaw):
    r = math.radians(yaw)
    return (v[0] * math.cos(r) - v[1] * math.sin(r), v[0] * math.sin(r) + v[1] * math.cos(r))


def _mesh_xy_centre(mesh, yaw=0.0):
    """Offset of the mesh's bounds centre (XY) from its pivot after a yaw."""
    lo, hi = _bounds_local(mesh)
    return _rotz(((lo[0] + hi[0]) * 0.5, (lo[1] + hi[1]) * 0.5), yaw)


def actor_bounds(actors):
    """(centre, half extents) of the visible static mesh content of `actors`, world space."""
    lo, hi = [1e18] * 3, [-1e18] * 3
    for a in actors:
        for c in a.get_components_by_class(unreal.PrimitiveComponent):
            if not c.is_visible() or isinstance(c, (unreal.BillboardComponent,)):
                continue
            try:
                o, e, _ = unreal.SystemLibrary.get_component_bounds(c)
            except Exception:
                continue
            if e.x > 1e5 or (e.x == 0 and e.y == 0 and e.z == 0):
                continue
            for k, (oo, ee) in enumerate(((o.x, e.x), (o.y, e.y), (o.z, e.z))):
                lo[k] = min(lo[k], oo - ee)
                hi[k] = max(hi[k], oo + ee)
    return tuple((l + h) * 0.5 for l, h in zip(lo, hi)), tuple((h - l) * 0.5 for l, h in zip(lo, hi))


# ====================================================================================== materials
MEL = unreal.MaterialEditingLibrary
EAL = unreal.EditorAssetLibrary


def _tools():
    return unreal.AssetToolsHelpers.get_asset_tools()


def _link(m, src, out, dst, pins):
    """Connect src.out into the first of `pins` that dst has (input names differ between engine versions)."""
    names = [str(n) for n in MEL.get_material_expression_input_names(dst)]
    for p in pins:
        if p in names or p == "":
            if MEL.connect_material_expressions(src, out, dst, p):
                return p
    for p in names:          # fallback: by position of the first candidate
        if any(c and c.lower().replace(" ", "") in p.lower().replace(" ", "") for c in pins):
            if MEL.connect_material_expressions(src, out, dst, p):
                return p
    raise RuntimeError("%s: no input %s on %s (has %s)" % (m.get_name(), pins, dst.get_name(), names))


def _material(name, rebuild=False):
    m = _load("%s/%s" % (F_MAT, name))
    if m is not None and not rebuild:
        return m, False
    if m is None:
        m = _tools().create_asset(name, F_MAT, unreal.Material, unreal.MaterialFactoryNew())
    else:
        MEL.delete_all_material_expressions(m)
    _CACHE["%s/%s" % (F_MAT, name)] = m
    return m, True


def _param(m, cls, name, value, x, y):
    e = MEL.create_material_expression(m, cls, x, y)
    e.set_editor_property("parameter_name", name)
    if cls is unreal.MaterialExpressionVectorParameter:
        e.set_editor_property("default_value", unreal.LinearColor(*(tuple(value) + (1.0,) * (4 - len(value)))))
    else:
        e.set_editor_property("default_value", float(value))
    return e


def _eai(m, src, x, y):
    """src * EyeAdaptationInverse: a display-referred colour that ignores the exposure."""
    e = MEL.create_material_expression(m, unreal.MaterialExpressionEyeAdaptationInverse, x, y)
    _link(m, src, "", e, ["LightValueInput", "Light Value", "LightValue", "Input"])
    return e


GRID_HLSL = r"""
float2 uv = UV * Cells;
float4 dd = float4(ddx(uv), ddy(uv));
float2 deriv = max(float2(length(dd.xz), length(dd.yw)), 1e-6);
float2 lw = float2(LineWidth, LineWidth);
float2 drawWidth = clamp(lw, deriv, 0.5);
float2 lineAA = deriv * 1.5;
float2 gridUV = 1.0 - abs(frac(uv) * 2.0 - 1.0);
float2 g2 = smoothstep(drawWidth + lineAA, drawWidth - lineAA, gridUV);
g2 *= saturate(lw / drawWidth);
g2 = lerp(g2, lw, saturate(deriv * 2.0 - 1.0));
return lerp(g2.x, 1.0, g2.y);
"""


def build_materials(rebuild=False):
    """DevlogBackdrop_Mars_M (unlit, two-sided), DevlogFloor_Mars_M (lit, anti-aliased 1 m grid on UV0), DevlogSurface_Mars_M
    (plain lit: probes, the counter) and their instances, under /Game/Mars/Devlog/Materials. Built once; rebuild=True
    regenerates the graphs (instances keep their overrides)."""
    made = []
    # --- backdrop
    m, fresh = _material("DevlogBackdrop_Mars_M", rebuild)
    if fresh:
        m.set_editor_property("shading_model", unreal.MaterialShadingModel.MSM_UNLIT)
        m.set_editor_property("two_sided", True)
        col = _param(m, unreal.MaterialExpressionVectorParameter, "Color", BACKDROP_COLOR, -900, 0)
        ea = _eai(m, col, -500, 0)
        MEL.connect_material_property(ea, "", unreal.MaterialProperty.MP_EMISSIVE_COLOR)
        MEL.recompile_material(m)
        EAL.save_loaded_asset(m)
        made.append(m.get_name())
    # --- floor
    m, fresh = _material("DevlogFloor_Mars_M", rebuild)
    if fresh:
        uv = MEL.create_material_expression(m, unreal.MaterialExpressionTextureCoordinate, -1400, 0)
        cells = _param(m, unreal.MaterialExpressionScalarParameter, "Cells", FLOOR_SIZE_M, -1400, 120)
        lw = _param(m, unreal.MaterialExpressionScalarParameter, "LineWidth", LINE_WIDTH, -1400, 240)
        cu = MEL.create_material_expression(m, unreal.MaterialExpressionCustom, -1100, 100)
        cu.set_editor_property("code", GRID_HLSL)
        cu.set_editor_property("output_type", unreal.CustomMaterialOutputType.CMOT_FLOAT1)
        cu.set_editor_property("description", "Grid")
        pins = []
        for pin in ("UV", "Cells", "LineWidth"):
            ci = unreal.CustomInput()
            ci.set_editor_property("input_name", pin)
            pins.append(ci)
        cu.set_editor_property("inputs", pins)
        MEL.connect_material_expressions(uv, "", cu, "UV")
        MEL.connect_material_expressions(cells, "", cu, "Cells")
        MEL.connect_material_expressions(lw, "", cu, "LineWidth")
        fa = _param(m, unreal.MaterialExpressionVectorParameter, "FloorAlbedo", (FLOOR_ALBEDO,) * 3, -1100, -400)
        la = _param(m, unreal.MaterialExpressionVectorParameter, "LineAlbedo", (0.06, 0.06, 0.07), -1100, -200)
        fg = _param(m, unreal.MaterialExpressionVectorParameter, "FloorGlow", FLOOR_GLOW, -1100, 400)
        lg = _param(m, unreal.MaterialExpressionVectorParameter, "LineGlow", LINE_GLOW, -1100, 600)
        bc = MEL.create_material_expression(m, unreal.MaterialExpressionLinearInterpolate, -700, -300)
        MEL.connect_material_expressions(fa, "", bc, "A")
        MEL.connect_material_expressions(la, "", bc, "B")
        MEL.connect_material_expressions(cu, "", bc, "Alpha")
        gl = MEL.create_material_expression(m, unreal.MaterialExpressionLinearInterpolate, -700, 450)
        MEL.connect_material_expressions(fg, "", gl, "A")
        MEL.connect_material_expressions(lg, "", gl, "B")
        MEL.connect_material_expressions(cu, "", gl, "Alpha")
        ea = _eai(m, gl, -450, 450)
        rough = _param(m, unreal.MaterialExpressionScalarParameter, "Roughness", 0.9, -700, 100)
        spec = _param(m, unreal.MaterialExpressionScalarParameter, "Specular", 0.0, -700, 220)
        MEL.connect_material_property(bc, "", unreal.MaterialProperty.MP_BASE_COLOR)
        MEL.connect_material_property(ea, "", unreal.MaterialProperty.MP_EMISSIVE_COLOR)
        MEL.connect_material_property(rough, "", unreal.MaterialProperty.MP_ROUGHNESS)
        MEL.connect_material_property(spec, "", unreal.MaterialProperty.MP_SPECULAR)
        MEL.recompile_material(m)
        EAL.save_loaded_asset(m)
        made.append(m.get_name())
    # --- plain lit surface
    m, fresh = _material("DevlogSurface_Mars_M", rebuild)
    if fresh:
        bc = _param(m, unreal.MaterialExpressionVectorParameter, "BaseColor", (0.18, 0.18, 0.18), -600, -200)
        me = _param(m, unreal.MaterialExpressionScalarParameter, "Metallic", 0.0, -600, 0)
        ro = _param(m, unreal.MaterialExpressionScalarParameter, "Roughness", 0.6, -600, 100)
        sp = _param(m, unreal.MaterialExpressionScalarParameter, "Specular", 0.5, -600, 200)
        MEL.connect_material_property(bc, "", unreal.MaterialProperty.MP_BASE_COLOR)
        MEL.connect_material_property(me, "", unreal.MaterialProperty.MP_METALLIC)
        MEL.connect_material_property(ro, "", unreal.MaterialProperty.MP_ROUGHNESS)
        MEL.connect_material_property(sp, "", unreal.MaterialProperty.MP_SPECULAR)
        MEL.recompile_material(m)
        EAL.save_loaded_asset(m)
        made.append(m.get_name())
    # --- instances (created once; their parameters are (re)set from the constants here every build)
    insts = {
        "DevlogBackdrop_Mars_MI": ("DevlogBackdrop_Mars_M", {}, {"Color": BACKDROP_COLOR}),
        "DevlogFloor_Mars_MI": ("DevlogFloor_Mars_M", {"Cells": FLOOR_SIZE_M, "LineWidth": LINE_WIDTH},
                                {"FloorGlow": FLOOR_GLOW, "LineGlow": LINE_GLOW, "FloorAlbedo": (FLOOR_ALBEDO,) * 3}),
        "DevlogGrey18_Mars_MI": ("DevlogSurface_Mars_M", {"Roughness": 0.7, "Specular": 0.5}, {"BaseColor": (0.18, 0.18, 0.18)}),
        "DevlogChrome_Mars_MI": ("DevlogSurface_Mars_M", {"Metallic": 1.0, "Roughness": 0.05}, {"BaseColor": (0.95, 0.95, 0.95)}),
        "DevlogCounter_Mars_MI": ("DevlogSurface_Mars_M", {"Roughness": 0.62, "Specular": 0.35},
                                  {"BaseColor": (0.05, 0.047, 0.045)}),
    }
    for name, (parent, scalars, vectors) in insts.items():
        mi = _load("%s/%s" % (F_MAT, name))
        if mi is None:
            mi = _tools().create_asset(name, F_MAT, unreal.MaterialInstanceConstant,
                                       unreal.MaterialInstanceConstantFactoryNew())
            _CACHE["%s/%s" % (F_MAT, name)] = mi
        MEL.set_material_instance_parent(mi, _load("%s/%s" % (F_MAT, parent)))
        for k, v in scalars.items():
            MEL.set_material_instance_scalar_parameter_value(mi, k, float(v))
        for k, v in vectors.items():
            MEL.set_material_instance_vector_parameter_value(mi, k, unreal.LinearColor(*(tuple(v) + (1.0,) * (4 - len(v)))))
        MEL.update_material_instance(mi)
        EAL.save_loaded_asset(mi)
    return made


def mat(name):
    return _load("%s/%s" % (F_MAT, name))


# ====================================================================================== environment (floor, backdrop, fog, grade)
def _post(look):
    """The stage grade on a PostProcessSettings: ds._post (manual exposure, bloom, vignette, saturation, contrast) plus
    no SSGI (the project default is screen-space GI), no Lumen reflections, no grain / fringe / flares, neutral local
    exposure."""
    s = ds._post(unreal.PostProcessSettings(), look)
    for k, v in (("override_dynamic_global_illumination_method", True),
                 ("dynamic_global_illumination_method", unreal.DynamicGlobalIlluminationMethod.NONE),
                 ("override_reflection_method", True), ("reflection_method", unreal.ReflectionMethod.NONE),
                 ("override_film_grain_intensity", True), ("film_grain_intensity", 0.0),
                 ("override_scene_fringe_intensity", True), ("scene_fringe_intensity", 0.0),
                 ("override_lens_flare_intensity", True), ("lens_flare_intensity", 0.0),
                 ("override_ambient_occlusion_intensity", True), ("ambient_occlusion_intensity", 0.4),
                 ("override_local_exposure_highlight_contrast_scale", True), ("local_exposure_highlight_contrast_scale", 1.0),
                 ("override_local_exposure_shadow_contrast_scale", True), ("local_exposure_shadow_contrast_scale", 1.0),
                 ("override_local_exposure_detail_strength", True), ("local_exposure_detail_strength", 1.0),
                 ("override_film_toe", True), ("film_toe", float(look.get("toe", 0.55))),
                 ("override_film_slope", True), ("film_slope", float(look.get("slope", 0.88))),
                 ("override_film_shoulder", True), ("film_shoulder", float(look.get("shoulder", 0.26))),
                 ("override_film_black_clip", True), ("film_black_clip", float(look.get("black_clip", 0.0)))):
        try:
            s.set_editor_property(k, v)
        except Exception as exc:
            unreal.log_warning("[stage] post %s: %s" % (k, exc))
    return s


def fog_actor():
    for a in tagged("env"):
        if isinstance(a, unreal.ExponentialHeightFog):
            return a
    return None


def set_fog(start=None, density=None, luminance=None, ev=None):
    """The stage fog. luminance scales with 2^(STAGE_EV - ev) so a shot at another exposure keeps the backdrop tone."""
    f = fog_actor()
    if f is None:
        return None
    c = f.get_component_by_class(unreal.ExponentialHeightFogComponent)
    c.set_start_distance(float(FOG["start"] if start is None else start))
    c.set_fog_density(float(FOG["density"] if density is None else density))
    lum = luminance or FOG["luminance"]
    k = 2.0 ** (STAGE_EV - (STAGE_EV if ev is None else ev))
    col = unreal.LinearColor(lum[0] * k, lum[1] * k, lum[2] * k, 1.0)
    for setter in ("set_fog_inscattering_color", "set_fog_inscattering_luminance"):
        if hasattr(c, setter):
            getattr(c, setter)(col)
            break
    else:
        c.set_editor_property("fog_inscattering_luminance", col)
    return c


def build_env():
    """Floor (2 km plane, grid instance), backdrop sphere (2 km radius, unlit), height fog, unbound grade volume."""
    plane = _load("/Engine/BasicShapes/Plane")
    fl = spawn(plane, (FLOOR_CENTRE[0], FLOOR_CENTRE[1], -0.3), "env", "Floor", scale=(FLOOR_SIZE_M, FLOOR_SIZE_M, 1.0))
    c = _smc(fl)
    c.set_material(0, mat("DevlogFloor_Mars_MI"))
    c.set_editor_property("cast_shadow", False)
    sphere = _load("/Engine/BasicShapes/Sphere")
    bd = spawn(sphere, (FLOOR_CENTRE[0], FLOOR_CENTRE[1], 0.0), "env", "Backdrop", scale=4000.0)
    c = _smc(bd)
    c.set_material(0, mat("DevlogBackdrop_Mars_MI"))
    c.set_editor_property("cast_shadow", False)
    c.set_collision_profile_name("NoCollision")
    fog = spawn(unreal.ExponentialHeightFog, (FLOOR_CENTRE[0], FLOOR_CENTRE[1], 0.0), "env", "Fog")
    fc = fog.get_component_by_class(unreal.ExponentialHeightFogComponent)
    fc.set_editor_property("fog_height_falloff", FOG["falloff"])
    fc.set_editor_property("fog_max_opacity", 1.0)
    fc.set_editor_property("enable_volumetric_fog", False)
    set_fog()
    ppv = spawn(unreal.PostProcessVolume, (FLOOR_CENTRE[0], FLOOR_CENTRE[1], 0.0), "env", "Grade")
    ppv.set_editor_property("unbound", True)
    ppv.set_editor_property("settings", _post(LOOK))
    return 4


# ====================================================================================== lights
def _color(c):
    return unreal.Color(r=int(round(255 * c[0])), g=int(round(255 * c[1])), b=int(round(255 * c[2])), a=255)


def _spot(bay, role, label):
    a = spawn(unreal.SpotLight, (0.0, 0.0, 0.0), bay, label, sub="Lights", roles=(role,))
    c = a.get_component_by_class(unreal.SpotLightComponent)
    c.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
    c.set_editor_property("intensity_units", unreal.LightUnits.CANDELAS)
    c.set_editor_property("use_inverse_squared_falloff", True)
    return a


def fit_rig(bay, centre, radius, preset=None, cam_az=CAM_AZ):
    """Aim the bay's key / rim / fill at `centre` from RIG positions (relative to the camera azimuth `cam_az`) scaled by
    `radius` (the subject's bounding radius) and light them with `preset` (the bay default if None)."""
    preset = preset or BAYS[bay]["preset"]
    p = dict(PRESETS[preset])
    p["key_lux"] *= BAYS[bay].get("key_scale", 1.0)
    rig = dict(RIG, **BAYS[bay].get("rig", {}))
    roles = {}
    for a in tagged(bay):
        tags = [str(t) for t in a.get_editor_property("tags")]
        for role in RIG:
            if "%s.%s.%s" % (TAG, bay, role) in tags:
                roles[role] = a
    for role, (az, el, dist, src, shadows) in rig.items():
        a = roles.get(role) or _spot(bay, role, role.capitalize())
        d = max(radius * dist, 250.0)
        yaw = math.radians(cam_az + az)
        e = math.radians(el)
        loc = (centre[0] + d * math.cos(e) * math.cos(yaw), centre[1] + d * math.cos(e) * math.sin(yaw),
               centre[2] + d * math.sin(e))
        a.set_actor_location_and_rotation(unreal.Vector(*loc), ds._rot(loc, centre), False, False)
        c = a.get_component_by_class(unreal.SpotLightComponent)
        lux = p["key_lux"] * {"key": 1.0, "rim": p["rim_ratio"] * BAYS[bay].get("rim_scale", 1.0),
                              "fill": p["fill_ratio"] * BAYS[bay].get("fill_scale", 1.0)}[role]
        c.set_editor_property("intensity", lux * (d / 100.0) ** 2)
        c.set_editor_property("light_color", _color(p[role]))
        c.set_editor_property("attenuation_radius", d * 2.2)
        c.set_editor_property("source_radius", max(radius * src, 3.0))
        c.set_editor_property("soft_source_radius", max(radius * src * 2.0, 3.0))
        cone = math.degrees(math.atan2(radius * 1.35, d))
        c.set_editor_property("outer_cone_angle", min(cone, 80.0))
        c.set_editor_property("inner_cone_angle", min(cone * 0.55, 79.0))
        c.set_editor_property("cast_shadows", bool(shadows))
        c.set_editor_property("specular_scale", 1.0 if role != "fill" else 0.4)
        c.set_editor_property("volumetric_scattering_intensity", 0.0)
    for a in tagged(bay, "practical"):
        c = a.get_component_by_class(unreal.LocalLightComponent)
        if c is None:
            continue
        auth = _practical_cd(a)
        c.set_editor_property("intensity", auth * p["practical"])
        c.set_visibility(p["practical"] > 0.0)
    return {"bay": bay, "preset": preset, "centre": centre, "radius": radius}


def _practical_cd(a):
    for t in a.get_editor_property("tags"):
        t = str(t)
        if t.startswith("cd="):
            return float(t[3:])
    return 0.0


def practical(bay, loc, cd, color, radius=900.0, source=4.0, shadows=True, label="Practical"):
    a = spawn(unreal.PointLight, loc, bay, label, sub="Practicals", roles=("practical",))
    a.set_editor_property("tags", list(a.get_editor_property("tags")) + [unreal.Name("cd=%.3f" % cd)])
    c = a.get_component_by_class(unreal.PointLightComponent)
    c.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
    c.set_editor_property("intensity_units", unreal.LightUnits.CANDELAS)
    c.set_editor_property("intensity", cd)
    c.set_editor_property("light_color", _color(color))
    c.set_editor_property("attenuation_radius", radius)
    c.set_editor_property("source_radius", source)
    c.set_editor_property("cast_shadows", shadows)
    return a


def reflection(bay, loc, radius, kind, brightness):
    a = spawn(unreal.SphereReflectionCapture, loc, bay, "Reflection", sub="Lights", roles=("reflection",))
    c = a.get_component_by_class(unreal.ReflectionCaptureComponent)
    c.set_editor_property("reflection_source_type", unreal.ReflectionSourceType.SPECIFIED_CUBEMAP)
    c.set_editor_property("cubemap", _load(HDR[kind]))
    c.set_editor_property("brightness", brightness)
    c.set_editor_property("influence_radius", radius)
    return a


def probes(bay, at):
    """An 18 % grey ball and a chrome ball beside `at`, invisible unless calibrate() shows them."""
    sphere = _load("/Engine/BasicShapes/Sphere")
    out = []
    for k, (name, mi) in enumerate((("ProbeGrey", "DevlogGrey18_Mars_MI"), ("ProbeChrome", "DevlogChrome_Mars_MI"))):
        a = spawn(sphere, (at[0] + (k - 0.5) * 40.0, at[1], at[2]), bay, name, scale=0.3, sub="Probes", roles=("probe",))
        c = _smc(a)
        c.set_material(0, mat(mi))
        c.set_visibility(False)
        out.append(a)
    return out


# ====================================================================================== bay 1: turntable
TT_SUBJECTS = {
    # name: [(mesh, x, y, yaw)] laid out around the anchor (bay-local cm, pivots on the floor)
    "wall4m": [("Wall4m", 0.0, 0.0, 0.0)],
    "wall_ossuary": [("WallOssuary4m", 0.0, 0.0, 0.0)],
    "portal6m": [("Portal6m", 0.0, 0.0, 0.0)],
    "pier_family": ([("Pier%s" % h, -1350.0 + 260.0 * k, 0.0, 0.0) for k, h in enumerate(("H3m5", "H4m", "H7m5", "H11m5", "H15m5"))]
                    + [("Vertexcol%s" % h, -150.0 + 220.0 * k, 0.0, 0.0) for k, h in enumerate(("H3m5", "H7m5", "H11m5", "H15m5"))]
                    + [("Halfcol%s" % h, 850.0 + 220.0 * k, 0.0, 0.0) for k, h in enumerate(("H3m5", "H7m5", "H11m5", "H15m5"))]),
}
TT_DEFAULT = "wall4m"


def _bay_origin(bay):
    o = BAYS[bay]["origin"]
    return (o[0], o[1], 0.0)


def build_turntable():
    bay = "turntable"
    ox, oy, _ = _bay_origin(bay)
    for name, items in TT_SUBJECTS.items():
        for k, (piece, x, y, yaw) in enumerate(items):
            m = kit(piece)
            cx, cy = _mesh_xy_centre(m, yaw)
            a = spawn(m, (ox + x - cx, oy + y - cy, 0.0), bay, "%s_%02d_%s" % (name, k, piece), (0.0, yaw, 0.0),
                      sub="Subjects/" + name, roles=("subject", "subject_" + name))
            _smc(a).set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
    probes(bay, (ox + 300.0, oy + 250.0, 120.0))
    r, s = BAYS[bay]["reflection"]
    reflection(bay, (ox, oy + 100.0, 250.0), r, BAYS[bay]["hdr"], s)
    set_subject(TT_DEFAULT)


def subject_actors(name):
    return tagged("turntable", "subject_" + name)


def set_subject(name, spin=0.0, preset=None, cam_az=CAM_AZ):
    """Show turntable subject `name` (the others hidden), rotated `spin` degrees about the anchor, the bay rig fitted to
    it. Returns (centre, half extents)."""
    ox, oy, _ = _bay_origin("turntable")
    for other in TT_SUBJECTS:
        for a in subject_actors(other):
            _smc(a).set_visibility(other == name)
    items = TT_SUBJECTS[name]
    acts = sorted(subject_actors(name), key=lambda a: a.get_actor_label())
    for a, (piece, x, y, yaw) in zip(acts, items):
        m = kit(piece)
        cx, cy = _mesh_xy_centre(m, yaw)
        px, py = x - cx, y - cy
        rx, ry = _rotz((px, py), spin)
        a.set_actor_location_and_rotation(unreal.Vector(ox + rx, oy + ry, 0.0),
                                          unreal.Rotator(roll=0.0, pitch=0.0, yaw=yaw + spin), False, False)
    c, e = actor_bounds(acts)
    fit_rig("turntable", c, math.sqrt(e[0] ** 2 + e[1] ** 2 + e[2] ** 2), preset, cam_az)
    return c, e


# ---------------------------------------------------------------- material stages (turntable subject)
STAGES = ("base_colour", "normals", "lit_no_wash", "wash", "fog_emissive", "final")
WASH_MASTERS = ("MiseAtlas_Mars_M", "Surface_Mars_M")
EMISSIVE_MASTERS = ("MiseAtlas_Mars_M", "Emissive_Mars_M")
MID_PREFIX = "DevlogStageMID"


def _mids(actors):
    """MIDs on every wash / emissive slot of `actors` (created once): [(mid, base, wash, glow, glow param)]."""
    out = []
    for a in actors:
        for c in a.get_components_by_class(unreal.PrimitiveComponent):
            try:
                n = c.get_num_materials()
            except Exception:
                continue
            for k in range(n):
                m = c.get_material(k)
                if m is None:
                    continue
                if not (isinstance(m, unreal.MaterialInstanceDynamic) and m.get_name().startswith(MID_PREFIX)):
                    if m.get_base_material().get_name() not in WASH_MASTERS + EMISSIVE_MASTERS:
                        continue
                    m = c.create_dynamic_material_instance(k, m, "%s_%d" % (MID_PREFIX, len(out)))
                parent = m.get_editor_property("parent")
                base = m.get_base_material().get_name()
                wash = MEL.get_material_instance_scalar_parameter_value(parent, "PaintStrength") if base in WASH_MASTERS else None
                gp = "Strength" if base == "Emissive_Mars_M" else "EmissiveStrength"
                glow = MEL.get_material_instance_scalar_parameter_value(parent, gp) if base in EMISSIVE_MASTERS else None
                out.append((m, base, wash, glow, gp))
    return out


def material_stage(actors, stage, k=1.0):
    """Set the six-stage progression on `actors`: returns {"source": capture source, "look": {...}, "fog": {...}}.
    base_colour / normals are capture sources (unlit buffers); lit_no_wash removes the paint wash and emissive;
    wash eases the wash in by k; fog_emissive brings emissive and a near fog in by k; final is the authored look."""
    s = STAGES.index(stage)
    wash = {0: 0.0, 1: 0.0, 2: 0.0, 3: k}.get(s, 1.0)
    glow = {4: k, 5: 1.0}.get(s, 0.0)
    for mid, base, w, g, gp in _mids(actors):
        if w is not None:
            mid.set_scalar_parameter_value("PaintStrength", w * wash)
        if g is not None:
            mid.set_scalar_parameter_value(gp, g * glow)
    return {"source": {0: "base", 1: "normal"}.get(s, "final"), "look": {"bloom": LOOK["bloom"] * (glow if s >= 2 else 1.0)},
            "fog_k": glow}


def restore_materials(actors=None):
    n = 0
    for a in actors if actors is not None else tagged():
        for c in a.get_components_by_class(unreal.PrimitiveComponent):
            try:
                cnt = c.get_num_materials()
            except Exception:
                continue
            for k in range(cnt):
                m = c.get_material(k)
                if isinstance(m, unreal.MaterialInstanceDynamic) and m.get_name().startswith(MID_PREFIX):
                    c.set_material(k, m.get_editor_property("parent"))
                    n += 1
    return n


# ====================================================================================== bay 2: cooking
PAN = COOK + "/Meshes/FryPan_Mars_SM"
CUBE = COOK + "/Meshes/MeatCube_Mars_SM"
PAN_STEEL = COOK + "/Materials/Instances/Pan_Steel_Mars_MI"
PAN_HANDLE = COOK + "/Materials/Instances/Pan_Handle_Mars_MI"
CUBE_HALF = 2.2                   # cooking_spec.CUBE_MESH_HALF_CM
CUBE_FOOTPRINT = round(CUBE_HALF * 2.0 ** 0.5 * 0.9, 2)
PAN_Z = 0.4                       # the pan's pivot is its cooking surface; this rests the underside on the counter
COUNTER = (180.0, 90.0, 90.0)     # counter slab size (x, y, height), cm
COUNTER_MI = "/Game/Mars/Environment/Materials/Instances/StoneFloor_Spillring_Mars_MI"   # blue-grey kit flagstone
COUNTER_TINT = (0.33, 0.33, 0.35, 1.0)
HOB = COUNTER[2]
# bay-local (x, y) of the pans on the counter top (the counter is centred on the bay origin)
PAN_A = (-22.0, 2.0, 32.0)        # x, y, yaw: the hero pan, handle toward front-right
PAN_B = (34.0, -14.0, -28.0)      # the second pan (drumstick)
# the hero pan's oil / meat look (Pan_Mars_M parameters, on a Devlog child instance of Pan_Steel_Mars_MI)
PAN_LOOK = {"Oil Amount": 0.9, "Sizzle": 0.6, "Fond": 0.1, "Seasoning": 0.2, "Carbon Specks": 0.2, "Oil Opacity": 0.5,
            "Pool Radius": round(1.1 * 2.0, 2), "Pool Margin": 1.7, "Pool Blend": 1.0, "Pool Wobble": 0.5,
            "Pool Edge Softness": 0.15, "Simmer Width": 0.8, "Simmer Cell": 0.6, "Simmer Density": 0.85,
            "Simmer Rim Darken": 0.9, "Contact Softness": 0.8, "Roughness": 0.08}
PAN_B_LOOK = {"Oil Amount": 0.55, "Sizzle": 0.35, "Fond": 0.35, "Seasoning": 0.6, "Roughness": 0.09}
# cube cook states: (sear XY +X -X +Y -Y), (sear +Z, -Z, Penetration, Oil Coat), (Glaze, Shape, Fry, Wet)
CUBE_STATES = {
    "raw": ((0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0)),
    # half: one side seared and flipped up (+Z 0.9), the band creeping up the raw sides (Penetration 0.45)
    "half": ((0.05, 0.05, 0.05, 0.05), (0.9, 0.2, 0.45, 0.6), (0.0, 0.3, 0, 0)),
    "flipped": ((0.12, 0.1, 0.15, 0.1), (0.95, 0.75, 0.75, 0.6), (0.0, 0.55, 0, 0)),
    "seared": ((0.95, 1.0, 0.9, 1.0), (1.0, 1.05, 1.0, 0.45), (0.35, 1.0, 0, 0)),
}
# hero pan arrangements: [(cube slot, pan-local x, y, yaw, state)]; "Meat Footprint", "Meat Footprint 1".. follow
ARRANGE = {
    "empty": [],
    "single_raw": [(0, 0.0, 0.0, 18.0, "raw")],
    "single_half": [(0, 0.0, 0.0, 18.0, "half")],
    "single_seared": [(0, 0.0, 0.0, 18.0, "seared")],
    "trio": [(0, -3.6, 2.4, 12.0, "half"), (1, 3.4, 3.0, -20.0, "flipped"), (2, 0.4, -4.0, 38.0, "seared")],
}
COOK_DEFAULT = "trio"
# food library meats (Food_Mars_M: the same CPD sear ledger), in the second pan and beside it on the counter
FOOD = COOK + "/Food/Meshes"
FOOD_ITEMS = [  # label, mesh, where ("panB" pan-local or "counter" bay-local), x, y, yaw, (sear xy), (sear z...), (finish)
    ("Drumstick", "Drumstick_Mars_SM", "panB", -1.5, 0.0, 15.0, (0.6, 0.5, 0.55, 0.6), (0.7, 1.0, 0.7, 0.5), (0.2, 0.8, 0, 0)),
    ("Tentacle", "Tentacle_Mars_SM", "counter", 2.0, -36.0, 8.0, (0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0.3)),
    ("RoastHorned", "RoastHorned_Mars_SM", "counter", 68.0, 22.0, 150.0, (0.9, 0.85, 0.9, 0.8), (0.9, 1.0, 0.9, 0.35),
     (0.4, 1.0, 0, 0)),
]


def _cook_mi(name, parent, scalars):
    mi = _load("%s/%s" % (F_MAT, name))
    if mi is None:
        mi = _tools().create_asset(name, F_MAT, unreal.MaterialInstanceConstant, unreal.MaterialInstanceConstantFactoryNew())
        _CACHE["%s/%s" % (F_MAT, name)] = mi
    MEL.set_material_instance_parent(mi, _load(parent))
    for k, v in scalars.items():
        MEL.set_material_instance_scalar_parameter_value(mi, k, float(v))
    MEL.update_material_instance(mi)
    EAL.save_loaded_asset(mi)
    return mi


def _set_cpd(actor, xy, z, fin):
    """The cook ledger on Custom Primitive Data, as the saved default AND on the live proxy (the default alone does not
    reach the renderer of an already registered component)."""
    c = _smc(actor)
    for i, v in ((0, xy), (4, z), (8, fin)):
        vec = unreal.Vector4(*map(float, v))
        c.set_default_custom_primitive_data_vector4(i, vec)
        c.set_custom_primitive_data_vector4(i, vec)


def _pan_world(p, local):
    """Pan-local (x, y) cm -> world (x, y) for pan placement p = (bay x, bay y, yaw)."""
    ox, oy, _ = _bay_origin("cooking")
    rx, ry = _rotz(local, p[2])
    return (ox + p[0] + rx, oy + p[1] + ry)


def build_cooking():
    bay = "cooking"
    ox, oy, _ = _bay_origin(bay)
    # counter: a bevelled kit stone block scaled to the slab, dark stone
    blk = kit("Boxes/BoxStoneBlock1m")
    lo, hi = _bounds_local(blk)
    ext = (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2])
    sc = (COUNTER[0] / ext[0], COUNTER[1] / ext[1], COUNTER[2] / ext[2])
    cx, cy = (lo[0] + hi[0]) * 0.5 * sc[0], (lo[1] + hi[1]) * 0.5 * sc[1]
    cnt = spawn(blk, (ox - cx, oy - cy, -lo[2] * sc[2]), bay, "Counter", scale=sc, roles=("counter",))
    c = _smc(cnt)
    top = mat("DevlogCounter_Mars_MI")
    if _load(COUNTER_MI) is not None:             # a darkened, finer child of the kit flagstone (no paint wash)
        top = _cook_mi("DevlogCounterStone_Mars_MI", COUNTER_MI, {"PaintStrength": 0.0})
        MEL.set_material_instance_vector_parameter_value(top, "Tint", unreal.LinearColor(*COUNTER_TINT))
        MEL.set_material_instance_vector_parameter_value(top, "TileMetres", unreal.LinearColor(1.5, 1.3, 0.0, 0.0))
        MEL.update_material_instance(top)
        EAL.save_loaded_asset(top)
    for k in range(c.get_num_materials()):
        c.set_material(k, top)
    pan = _load(PAN)
    pa_mi = _cook_mi("DevlogPanA_Mars_MI", PAN_STEEL, PAN_LOOK)
    pb_mi = _cook_mi("DevlogPanB_Mars_MI", PAN_STEEL, PAN_B_LOOK)
    for label, p, mi in (("PanA", PAN_A, pa_mi), ("PanB", PAN_B, pb_mi)):
        a = spawn(pan, (ox + p[0], oy + p[1], HOB + PAN_Z), bay, label, (0.0, p[2], 0.0), roles=("pan", label))
        pc = _smc(a)
        pc.set_material(0, mi)
        pc.set_material(1, _load(PAN_HANDLE))
    cube = _load(CUBE)
    for k in range(3):
        a = spawn(cube, (ox, oy, HOB + PAN_Z + CUBE_HALF), bay, "Cube_%d" % k, roles=("cube", "cube%d" % k))
        _smc(a).set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
    footprints = []
    for label, mesh, where, x, y, yaw, xy, z, fin in FOOD_ITEMS:
        m = _load("%s/%s" % (FOOD, mesh))
        if m is None:
            unreal.log_warning("[stage] food mesh %s missing" % mesh)
            continue
        cx, cy = _mesh_xy_centre(m, (PAN_B[2] if where == "panB" else 0.0) + yaw)
        if where == "panB":
            wx, wy = _pan_world(PAN_B, (x, y))
            z0 = HOB + PAN_Z
            footprints.append((x, y))
        else:
            wx, wy, z0 = ox + x, oy + y, HOB
        yaw_w = yaw + (PAN_B[2] if where == "panB" else 0.0)
        a = spawn(m, (wx - cx, wy - cy, z0), bay, label, (0.0, yaw_w, 0.0), sub="Food", roles=("food",))
        _set_cpd(a, xy, z, fin)
    for i, (x, y) in enumerate(footprints):
        MEL.set_material_instance_vector_parameter_value(pb_mi, "Meat Footprint" + ("" if i == 0 else " %d" % i),
                                                         unreal.LinearColor(x, y, 6.0, 0.0))
    MEL.update_material_instance(pb_mi)
    EAL.save_loaded_asset(pb_mi)
    probes(bay, (ox - 60.0, oy + 30.0, HOB + 12.0))
    r, s = BAYS[bay]["reflection"]
    reflection(bay, (ox, oy + 10.0, HOB + 30.0), r, BAYS[bay]["hdr"], s)
    arrange(COOK_DEFAULT)
    EAL.save_loaded_asset(pa_mi)                  # the saved map opens on the trio with its footprints


def _pan_a():
    return tagged("cooking", "PanA")[0]


def pan_params(**scalars):
    """Set scalar parameters on the hero pan's Devlog instance (e.g. Sizzle=1.0); returns the previous values."""
    mi = mat("DevlogPanA_Mars_MI")
    old = {}
    for k, v in scalars.items():
        name = k.replace("_", " ") if " " not in k else k
        old[name] = MEL.get_material_instance_scalar_parameter_value(mi, name)
        MEL.set_material_instance_scalar_parameter_value(mi, name, float(v))
    MEL.update_material_instance(mi)
    return old


def arrange(name, sizzle=None, oil=None, pan=None):
    """Place the hero pan's cubes for arrangement `name` (ARRANGE), set their CPD cook states and the pan instance's
    Meat Footprint slots; hidden cubes park under the counter. sizzle / oil override the pan's Sizzle / Oil Amount."""
    ox, oy, _ = _bay_origin("cooking")
    mi = mat("DevlogPanA_Mars_MI")
    cubes = {k: tagged("cooking", "cube%d" % k)[0] for k in range(3)}
    used = set()
    for i, (slot, x, y, yaw, state) in enumerate(ARRANGE[name]):
        a = cubes[slot]
        wx, wy = _pan_world(PAN_A, (x, y))
        a.set_actor_location_and_rotation(unreal.Vector(wx, wy, HOB + PAN_Z + CUBE_HALF),
                                          unreal.Rotator(roll=0.0, pitch=0.0, yaw=PAN_A[2] + yaw), False, False)
        _smc(a).set_visibility(True)
        _set_cpd(a, *CUBE_STATES[state])
        used.add(slot)
        MEL.set_material_instance_vector_parameter_value(mi, "Meat Footprint" + ("" if i == 0 else " %d" % i),
                                                         unreal.LinearColor(x, y, CUBE_FOOTPRINT, 0.0))
    for i in range(len(ARRANGE[name]), 6):
        MEL.set_material_instance_vector_parameter_value(mi, "Meat Footprint" + ("" if i == 0 else " %d" % i),
                                                         unreal.LinearColor(0.0, 0.0, 0.0, 0.0))
    for slot, a in cubes.items():
        if slot not in used:
            a.set_actor_location(unreal.Vector(ox, oy, 20.0), False, False)
            _smc(a).set_visibility(False)
    scal = dict(PAN_LOOK)
    scal.update(pan or {})
    if sizzle is not None:
        scal["Sizzle"] = sizzle
    if oil is not None:
        scal["Oil Amount"] = oil
    pan_params(**scal)
    MEL.update_material_instance(mi)
    return name


BOWL = (15.5, 15.5, 3.0)          # the pan's bowl (no handle) as a framing box, half extents about the cooking surface


def cooking_subject(which="panA"):
    """(centre, half extents) of a cooking subject: panA (its bowl and what is in it) / panA_handle / panB / bay."""
    if which == "panA":
        p = _pan_a().get_actor_location()
        return (p.x, p.y, p.z + BOWL[2]), BOWL
    if which == "panA_handle":
        return actor_bounds([_pan_a()] + [a for a in tagged("cooking", "cube") if _smc(a).is_visible()])
    if which == "panB":
        return actor_bounds(tagged("cooking", "PanB") + [a for a in tagged("cooking", "food")
                                                         if "Drumstick" in a.get_actor_label()])
    return actor_bounds(tagged("cooking", "counter") + tagged("cooking", "pan") + tagged("cooking", "food"))


def cube_world(slot=0):
    a = tagged("cooking", "cube%d" % slot)[0]
    p = a.get_actor_location()
    return (p.x, p.y, p.z)


# ====================================================================================== bay 3: room
ROOM = "crypt_octagon_hub"
ROOM_CUT_Z = 8.0          # placements at or above this (Blender metres) are cut away (third wall tier, roof, grilles)
ROOM_KEEP_HIGH = ("crypt_vault_rib", "crypt_vertexcol", "crypt_pier")
ROOM_DROP = ("crypt_roof", "crypt_screen_grille")


def _room_plan():
    with open(os.path.join(CRYPT_KIT, "rooms", ROOM + ".json")) as fh:
        return json.load(fh)


def build_room():
    import mise_mars_ue as mm
    bay = "room"
    ox, oy, _ = _bay_origin(bay)
    data = _room_plan()
    keep = []
    for d in data["placements"]:
        if any(d["piece"].startswith(p) for p in ROOM_DROP):
            continue
        if d["z"] >= ROOM_CUT_Z - 1e-3 and not any(d["piece"].startswith(p) for p in ROOM_KEEP_HIGH):
            continue
        keep.append(d)
    # the paver strip down the middle is open-jointed: a plain slab 2 cm under it so the stage grid never shows through
    keep.append({"piece": "crypt_floor_4x4", "x": -2.0, "y": 0.0, "z": -0.02, "rot": 0.0, "scale": [1.0, 6.0, 1.0]})
    data["placements"] = keep
    os.makedirs(SCRATCH, exist_ok=True)
    path = os.path.join(SCRATCH, "%s__devlog_stage.json" % ROOM)
    with open(path, "w") as fh:
        json.dump(data, fh)
    acts = mm.spawn_room(path, biome="Bellfold", origin=(ox, oy, 0.0), export_dir=CRYPT_KIT, folder=FOLDER + "/Room/Kit",
                         lights=False, sockets=False, blockers=False, mode="hism")
    for a in acts:
        a.set_actor_label("Stage_Room_Kit_" + ROOM)
        a.set_folder_path(FOLDER + "/Room/Kit")
        a.set_editor_property("tags", _tags(bay, "subject"))
    # torches: a sconce + flame light at each warm wall light of the plan (2.4 m), the upper wall lights as soft fill
    sconce = dressing("TorchSconce_A")
    cxb, cyb = 0.0, 12.0          # room centre, Blender metres
    n = 0
    for l in data.get("lights", []):
        if l["color"][2] > 0.5:                # the plan's teal glows: not in the warm preset
            continue
        bx, by, bz = mm.to_ue(l["x"], l["y"], l["z"])
        dx, dy = cxb - l["x"], -(cyb - l["y"])          # toward the centre, Unreal axes
        dl = math.hypot(dx, dy) or 1.0
        dx, dy = dx / dl, dy / dl
        if l["z"] < 4.0 and sconce is not None:
            yaw = math.degrees(math.atan2(-dx, dy))
            base = (ox + bx - dx * 40.0, oy + by - dy * 40.0, bz - 55.0)
            spawn(sconce, base, bay, "Sconce_%02d" % n, (0.0, yaw, 0.0), sub="Torches", roles=("torch",))
            practical(bay, (base[0] + dx * 45.0, base[1] + dy * 45.0, base[2] + 55.0), 26.0, (1.0, 0.62, 0.3),
                      radius=1300.0, source=4.0, shadows=True, label="Torch_%02d" % n)
        else:
            practical(bay, (ox + bx + dx * 30.0, oy + by + dy * 30.0, bz), 14.0, (1.0, 0.7, 0.42), radius=1500.0,
                      source=20.0, shadows=False, label="Upper_%02d" % n)
        n += 1
    probes(bay, (ox, oy - 600.0, 150.0))
    r, s = BAYS[bay]["reflection"]
    reflection(bay, (ox, oy - 1200.0, 300.0), r, BAYS[bay]["hdr"], s)
    room_rig()


def room_subject():
    return actor_bounds(tagged("room", "subject"))


def room_rig(preset=None, cam_az=CAM_AZ):
    c, e = room_subject()
    return fit_rig("room", c, math.sqrt(e[0] ** 2 + e[1] ** 2 + e[2] ** 2) * 0.8, preset, cam_az)


# ====================================================================================== map
BUILDERS = {"turntable": build_turntable, "cooking": build_cooking, "room": build_room}


def build_map(bays=None, save=True, rebuild_materials=False):
    """Create or open DevlogStage_Mars_MAP and (re)build the env and the named bays (default: DEFAULT_BAYS). Only this
    builder's actors (tag DevlogStage) are destroyed; returns counts."""
    if _les().is_in_play_in_editor():
        raise RuntimeError("stop PIE first")
    bays = list(bays or DEFAULT_BAYS)
    _CACHE.clear()
    os.makedirs(SCRATCH, exist_ok=True)
    made = build_materials(rebuild_materials)
    if EAL.does_asset_exist(MAP):
        if _world().get_path_name().split(".")[0] != MAP:
            _les().load_level(MAP)
    else:
        _les().new_level(MAP)
    doomed = [a for a in tagged() if any("%s.%s" % (TAG, b) in [str(t) for t in a.get_editor_property("tags")]
                                         for b in bays + ["env"])]
    if doomed:
        _eas().destroy_actors(doomed)
    build_env()
    counts = {}
    for b in bays:
        BUILDERS[b]()
        counts[b] = len(tagged(b))
    if save:
        unreal.EditorLoadingAndSavingUtils.save_current_level()
    return {"materials": made, "destroyed": len(doomed), "bays": counts, "map": _world().get_path_name()}


def open_stage():
    if _world().get_path_name().split(".")[0] != MAP:
        unreal.EditorLoadingAndSavingUtils.load_map(MAP)
    return _world().get_path_name()


def build_reflections(save=True):
    """Its OWN call after build_map: builds the reflection captures (the lighting half fails by design: no Lightmass)
    and saves the map + its BuiltData."""
    _les().build_light_maps(unreal.LightingBuildQuality.QUALITY_PREVIEW, True)
    pkgs = [p for p in unreal.EditorLoadingAndSavingUtils.get_dirty_map_packages() if p.get_name().startswith(MAP)]
    if save and pkgs:
        unreal.EditorLoadingAndSavingUtils.save_packages(pkgs, True)
    return [p.get_name() for p in pkgs]


# ====================================================================================== cameras
def frame(centre, half, az, elev, fov, fill=0.7, fill_w=0.86, aspect=16.0 / 9.0, aim=(0.0, 0.0)):
    """Solve a camera that sees the box (centre, half extents) from azimuth `az` (deg, direction from the subject to
    the eye; 90 = +Y) and elevation `elev` with horizontal fov `fov`, the box filling `fill` of the frame height (or
    fill_w of its width, whichever binds), centred (aim shifts the box centre in frame, NDC units). -> (eye, target)."""
    th = math.tan(math.radians(fov) * 0.5)
    tv = th / aspect
    corners = [(centre[0] + sx * half[0], centre[1] + sy * half[1], centre[2] + sz * half[2])
               for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    a, e = math.radians(az), math.radians(elev)
    dirv = (math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e))
    target = list(centre)

    def project(eye, tgt):
        f = [t - p for p, t in zip(eye, tgt)]
        fl = math.sqrt(sum(x * x for x in f))
        f = [x / fl for x in f]
        r = (f[1], -f[0], 0.0)
        rl = math.hypot(r[0], r[1]) or 1.0
        r = (r[0] / rl, r[1] / rl, 0.0)
        u = (r[1] * f[2] - r[2] * f[1], r[2] * f[0] - r[0] * f[2], r[0] * f[1] - r[1] * f[0])
        if u[2] < 0:
            u = tuple(-x for x in u)
            r = tuple(-x for x in r)
        xs, ys = [], []
        for p in corners:
            d = [p[i] - eye[i] for i in range(3)]
            z = sum(d[i] * f[i] for i in range(3))
            if z <= 1.0:
                return None
            xs.append(sum(d[i] * r[i] for i in range(3)) / z / th)
            ys.append(sum(d[i] * u[i] for i in range(3)) / z / tv)
        return min(xs), max(xs), min(ys), max(ys), r, u

    def eye_at(dist):
        return [target[i] + dirv[i] * dist for i in range(3)]

    dist = max(half) * 4.0
    for _ in range(4):
        lo, hi = max(half) * 0.2, max(half) * 200.0
        for _ in range(60):
            mid = (lo + hi) * 0.5
            pr = project(eye_at(mid), target)
            if pr is None:
                lo = mid
                continue
            x0, x1, y0, y1, _, _ = pr
            k = max((y1 - y0) / 2.0 / fill, (x1 - x0) / 2.0 / fill_w)
            if k > 1.0:
                lo = mid
            else:
                hi = mid
        dist = hi
        eye = eye_at(dist)
        x0, x1, y0, y1, r, u = project(eye, target)
        cx, cy = (x0 + x1) * 0.5 - aim[0], (y0 + y1) * 0.5 - aim[1]
        zc = sum((centre[i] - eye[i]) * dirv[i] * -1.0 for i in range(3))
        for i in range(3):
            target[i] += (cx * th * r[i] + cy * tv * u[i]) * abs(zc)
    eye = eye_at(dist)
    return tuple(eye), tuple(target)


# Shot presets: name -> dict(bay, subject, az (deg offset from the bay camera direction), elev, fov, fill, setup, ...)
# setup keys: subject (turntable), spin, arrange / sizzle / oil (cooking), stage (material stage), preset, t (frozen
# time), ev (exposure offset from STAGE_EV), eye / target (absolute, bypasses the solver)
SHOTS = {
    # turntable: 3/4 views at 25 deg, 40 deg fov (about 50 mm)
    "tt_wall4m": dict(bay="turntable", subject="wall4m", az=-38.0, elev=25.0, fov=42.0, fill=0.78),
    "tt_wall4m_normals": dict(bay="turntable", subject="wall4m", az=-38.0, elev=25.0, fov=42.0, fill=0.78, stage="normals"),
    "tt_wall4m_base": dict(bay="turntable", subject="wall4m", az=-38.0, elev=25.0, fov=42.0, fill=0.78, stage="base_colour"),
    "tt_wall4m_nowash": dict(bay="turntable", subject="wall4m", az=-38.0, elev=25.0, fov=42.0, fill=0.78, stage="lit_no_wash"),
    "tt_wall_ossuary": dict(bay="turntable", subject="wall_ossuary", az=32.0, elev=22.0, fov=42.0, fill=0.78),
    "tt_portal6m": dict(bay="turntable", subject="portal6m", az=-30.0, elev=22.0, fov=45.0, fill=0.72, fill_w=0.9),
    "tt_pier_family": dict(bay="turntable", subject="pier_family", az=-12.0, elev=14.0, fov=50.0, fill=0.74, fill_w=0.9),
    # cooking: the hero pan (A), top-down 60, three-quarter 30, an oil macro, the bay wide
    "cook_top60": dict(bay="cooking", focus="panA", az=-20.0, elev=60.0, fov=40.0, fill=0.8, arrange="trio"),
    "cook_34": dict(bay="cooking", focus="panA", az=-30.0, elev=30.0, fov=40.0, fill=0.62, arrange="trio"),
    "cook_cube": dict(bay="cooking", focus="cube0_wide", az=-30.0, elev=30.0, fov=35.0, fill=0.72, arrange="single_half"),
    "cook_pool_top": dict(bay="cooking", focus="pool", az=-20.0, elev=60.0, fov=35.0, fill=0.8, arrange="empty"),
    "cook_oil_macro": dict(bay="cooking", focus="cube0", az=24.0, elev=36.0, fov=34.0, dist=30.0, arrange="single_half",
                           ev=-1.6, sizzle=1.0, target_offset=(0.0, 1.2, 0.6)),
    "cook_wide": dict(bay="cooking", focus="bay", az=-26.0, elev=24.0, fov=40.0, fill=0.9, fill_w=0.92, arrange="trio",
                      rig_radius=150.0),
    # room: high 3/4 over the cut walls, and head height inside
    "room_high34": dict(bay="room", az=-32.0, elev=46.0, fov=44.0, fill=0.92, fill_w=0.92),
    "room_head": dict(bay="room", eye_local=(420.0, -260.0, 170.0), target_local=(-380.0, -1900.0, 260.0), fov=62.0),
}

# review stills: name -> (shot preset, overrides)
STILLS = [
    ("tt_wall4m_lit", "tt_wall4m", {}),
    ("tt_wall4m_normals", "tt_wall4m_normals", {}),
    ("tt_wall_ossuary", "tt_wall_ossuary", {}),
    ("tt_pier_family", "tt_pier_family", {}),
    ("tt_portal6m", "tt_portal6m", {}),
    ("cook_empty_sizzle0", "cook_pool_top", {"sizzle": 0.0, "oil": 1.0, "pan": {"Pool Radius": 6.5}}),
    ("cook_empty_sizzle1", "cook_pool_top", {"sizzle": 1.0, "oil": 1.0, "pan": {"Pool Radius": 6.5}}),
    ("cook_cube_raw", "cook_cube", {"arrange": "single_raw"}),
    ("cook_cube_half", "cook_cube", {"arrange": "single_half"}),
    ("cook_cube_seared", "cook_cube", {"arrange": "single_seared"}),
    ("cook_trio", "cook_34", {"arrange": "trio"}),
    ("cook_oil_macro", "cook_oil_macro", {}),
    ("cook_wide", "cook_wide", {}),
    ("room_high34", "room_high34", {}),
    ("room_head", "room_head", {}),
]
CONTACT = ["tt_wall4m_lit", "tt_wall4m_normals", "tt_wall_ossuary", "tt_pier_family", "tt_portal6m",
           "cook_empty_sizzle1", "cook_cube_seared", "cook_trio", "cook_oil_macro", "cook_wide",
           "room_high34", "room_head"]


def _shot_az(shot):
    if "eye_local" in shot:
        d = (shot["eye_local"][0] - shot["target_local"][0], shot["eye_local"][1] - shot["target_local"][1])
        return math.degrees(math.atan2(d[1], d[0]))
    return CAM_AZ + shot.get("az", 0.0)


def _setup(shot):
    """Put the stage in the shot's state (subject, arrangement, rig aimed for this camera); returns (centre, half) of
    its subject."""
    bay = shot["bay"]
    az = _shot_az(shot)
    if bay == "turntable":
        return set_subject(shot.get("subject", TT_DEFAULT), shot.get("spin", 0.0), shot.get("preset"), az)
    if bay == "cooking":
        arrange(shot.get("arrange", COOK_DEFAULT), shot.get("sizzle"), shot.get("oil"), shot.get("pan"))
        c, e = cooking_subject("panA")
        fit_rig("cooking", c, shot.get("rig_radius", 70.0), shot.get("preset"), az)
        focus = shot.get("focus", "panA")
        if focus == "pool":                     # the oil pool at the pan's centre
            p = _pan_a().get_actor_location()
            return (p.x, p.y, p.z + 0.5), (9.0, 9.0, 1.0)
        if focus.startswith("cube"):
            p = cube_world(int(focus[4]))
            if focus.endswith("_wide"):          # the cube and the oil round it
                return (p[0], p[1], p[2] - 1.0), (8.0, 8.0, 3.2)
            return p, (CUBE_HALF,) * 3
        return cooking_subject(focus)
    if bay == "room":
        room_rig(shot.get("preset"), az)
        return room_subject()
    raise KeyError(bay)


def resolve(name, **over):
    """A shot preset with overrides -> {eye, target, fov, ...}: sets the stage state (subject, arrangement, rig) too."""
    shot = dict(SHOTS[name], **over)
    centre, half = _setup(shot)
    ox, oy, _ = _bay_origin(shot["bay"])
    if "eye_local" in shot:
        eye = (ox + shot["eye_local"][0], oy + shot["eye_local"][1], shot["eye_local"][2])
        target = (ox + shot["target_local"][0], oy + shot["target_local"][1], shot["target_local"][2])
    elif "dist" in shot:
        a, e = math.radians(CAM_AZ + shot["az"]), math.radians(shot["elev"])
        off = shot.get("target_offset", (0.0, 0.0, 0.0))
        centre = tuple(c + o for c, o in zip(centre, off))
        target = tuple(centre)
        eye = (centre[0] + shot["dist"] * math.cos(e) * math.cos(a), centre[1] + shot["dist"] * math.cos(e) * math.sin(a),
               centre[2] + shot["dist"] * math.sin(e))
    else:
        eye, target = frame(centre, half, CAM_AZ + shot["az"], shot["elev"], shot["fov"], shot.get("fill", 0.7),
                            shot.get("fill_w", 0.86))
    dist = math.dist(eye, centre)
    radius = math.sqrt(sum(h * h for h in half))
    out = {"name": name, "bay": shot["bay"], "eye": [round(v, 2) for v in eye], "target": [round(v, 2) for v in target],
           "fov": shot["fov"], "t": shot.get("t", 12.0), "ev": STAGE_EV + shot.get("ev", 0.0),
           "fog_start": shot.get("fog_start", max(dist + radius * 1.2, 800.0)),
           "preset": shot.get("preset") or BAYS[shot["bay"]]["preset"], "stage": shot.get("stage", "final")}
    for k in ("subject", "arrange", "sizzle", "oil", "spin", "pan"):
        if k in shot:
            out[k] = shot[k]
    return out


# ====================================================================================== capture
class StageRig(ds.Rig):
    """ds.Rig (SceneCapture2D -> RT -> PNG, capture_every_frame on so the exposure is honoured) with the stage grade."""

    def __init__(self, size, look, source="final"):
        ds.Rig.__init__(self, size, look, source)
        self.comp.set_editor_property("post_process_settings", _post(self.look))

    def set_look(self, **kw):
        self.look.update(kw)
        self.comp.set_editor_property("post_process_settings", _post(self.look))


def _bay_look(bay, preset, ev):
    lk = dict(LOOK, ev=ev)
    lk["saturation"] = PRESETS[preset].get("saturation", LOOK["saturation"])
    return lk


PENDING = os.path.join(SCRATCH, "_pending_still.json")


def prepare_still(name, preset_name=None, draft=False, out_dir=None, **over):
    """Phase 1 of a still (its own Monolith call): put the stage in the shot's state (subject, arrangement, CPD, pan
    parameters, rig, material stage, fog) and remember the camera. The render state of those changes only reaches the
    renderer after an editor tick, so capture_still() runs in the NEXT call."""
    open_stage()
    if preset_name is None:
        for n, p, o in STILLS:
            if n == name:
                preset_name, over = p, dict(o, **over)
                break
    shot = resolve(preset_name, **over)
    shot["still"] = name
    shot["draft"] = bool(draft)
    shot["out_dir"] = out_dir or (os.path.join(SCRATCH, "drafts") if draft else os.path.join(REVIEW, "_raw"))
    look = _bay_look(shot["bay"], shot["preset"], shot["ev"])
    look.update(over.get("look", {}))
    shot["source"] = "final"
    if shot["bay"] == "turntable" and shot["stage"] != "final":
        st = material_stage(subject_actors(shot.get("subject", TT_DEFAULT)), shot["stage"])
        shot["source"] = st["source"]
        look.update(st["look"])
    shot["look"] = look
    set_fog(start=shot["fog_start"], ev=shot["ev"])
    with open(PENDING, "w") as fh:
        json.dump(shot, fh, indent=1)
    return shot


def capture_still():
    """Phase 2: render the pending still (2x supersampled unless draft), then restore fog, materials and probes."""
    with open(PENDING) as fh:
        shot = json.load(fh)
    size = DRAFT if shot["draft"] else (FULL[0] * SUPERSAMPLE, FULL[1] * SUPERSAMPLE)
    os.makedirs(shot["out_dir"], exist_ok=True)
    rig = StageRig(size, shot["look"], shot["source"])
    try:
        if shot["source"] != "final":           # unlit buffers: the floor / backdrop would only add a flat field
            for a in tagged("env"):
                rig.comp.hide_actor_components(a, False)
        path = rig.frame(shot["eye"], shot["target"], shot["fov"], shot["out_dir"], shot["still"] + ".png", shot["t"])
    finally:
        rig.close()
        set_fog()
        restore_materials(subject_actors(shot.get("subject", TT_DEFAULT)) if shot["bay"] == "turntable" else [])
        if shot.get("probes"):
            for a in tagged(shot["bay"], "probe"):
                _smc(a).set_visibility(False)
    shot["file"] = path
    shot["supersample"] = 1 if shot["draft"] else SUPERSAMPLE
    if not shot.get("probes"):
        _record(shot["still"], shot)
    return shot


def _record(name, shot):
    p = os.path.join(REVIEW, "stage_shots.json")
    data = {}
    if os.path.isfile(p):
        with open(p) as fh:
            data = json.load(fh)
    data[name] = {k: v for k, v in shot.items() if k != "file"}
    os.makedirs(REVIEW, exist_ok=True)
    with open(p, "w") as fh:
        json.dump(data, fh, indent=1)


def calibrate(bay, preset=None, ev=None):
    """Phase 1 of a probe still: the bay's 18 % grey and chrome balls moved onto its subject (under its rig, made
    visible); capture_still() in the next call renders a close-up and hides them again. The host measures the grey
    ball's lit side (target 100-130 / 255)."""
    open_stage()
    pr = tagged(bay, "probe")
    if bay == "turntable":
        c, e = set_subject(TT_DEFAULT, 0.0, preset)
        target = (c[0], c[1] + e[1] + 60.0, 120.0)
    elif bay == "cooking":
        arrange(COOK_DEFAULT)
        c, e = cooking_subject("panA")
        fit_rig(bay, c, 70.0, preset)
        target = (c[0] - 10.0, c[1] + 28.0, c[2] + 9.0)
    else:
        room_rig(preset)
        rc, _ = room_subject()
        target = (rc[0], rc[1], 150.0)
    for k, a in enumerate(pr):
        a.set_actor_location(unreal.Vector(target[0] + (k - 0.5) * 40.0, target[1], target[2]), False, False)
        _smc(a).set_visibility(True)
    ev = STAGE_EV if ev is None else ev
    shot = {"still": "calib_" + bay, "bay": bay, "draft": True, "out_dir": os.path.join(SCRATCH, "calib"),
            "eye": (target[0] - 60.0, target[1] + 260.0, target[2] + 60.0), "target": target, "fov": 30.0, "t": 12.0,
            "source": "final", "look": _bay_look(bay, preset or BAYS[bay]["preset"], ev), "probes": True}
    set_fog(ev=ev)
    with open(PENDING, "w") as fh:
        json.dump(shot, fh, indent=1)
    return shot


def still_names():
    return [n for n, _, _ in STILLS]
