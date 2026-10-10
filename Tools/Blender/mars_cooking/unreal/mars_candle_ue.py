"""Editor side of the Mars procedural CANDLES (candle_gen.py / build_candles.py): imports the candle FBXs with their
data UV channel intact, and builds the two procedural materials the flicker lives in.

    import sys, importlib
    sys.path.insert(0, r"D:\\Repo\\Mars\\Tools\\Blender\\mars_cooking\\unreal")
    import mars_candle_ue as mk; importlib.reload(mk)
    mk.run_all()                 # import_meshes, build_materials, assign_slots

Mesh contract (candle_gen): slots Wax / Wick / Flame; vertex colour = wax colour (linear) + cavity in A; UV1 =
(candle id 0..1, v) where v is the height along the flame on Flame vertices and the "glow" under the flame on Wax
vertices (1 at the rim, 0 about 7 cm down).

CandleFlame_Mars_M (unlit): the flame's brightness, sway and stretch come from a few summed sines of time, entirely in
the shader (no texture, no tick).  Every flame is out of step with every other one because its phase is the sum of
  - the candle id in UV1.u            (each candle of one cluster mesh),
  - PerInstanceRandom                 (each instance of an instanced component),
  - a hash of the object position     (each placed actor / instance, wherever it stands),
  - custom primitive data 0           ("Phase Offset": set per component to choose it by hand),
and custom primitive data 1 ("Intensity Offset") dims or boosts one component's flames.
CandleWax_Mars_M (lit): the painted wax, with a warm glow under each flame (UV1.v) that breathes with that flame.
Both masters are rebuilt IN PLACE (same UMaterial emptied and refilled): replacing a master asserts in the renderer
while instances of it are on screen.
"""
import glob
import importlib
import json
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import mars_cooking_ue as mc  # noqa: E402

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary

EXPORT_DIR = os.path.join(mc.spec.EXPORT_DIR, "candles")
UE_FOLDER = mc.spec.UE_FOLDER + "/Candles"            # /Game/Mars/Gameplay/Cooking/Candles
F_MESH, F_MAT = UE_FOLDER + "/Meshes", UE_FOLDER + "/Materials"
FLAME_MASTER, WAX_MASTER = "CandleFlame_Mars_M", "CandleWax_Mars_M"
SLOT_INSTANCE = {"Wax": "CandleWax_Mars_MI", "Wick": "CandleWax_Mars_MI", "Flame": "CandleFlame_Mars_MI"}
FLOAT1 = unreal.CustomMaterialOutputType.CMOT_FLOAT1
FLOAT3 = unreal.CustomMaterialOutputType.CMOT_FLOAT3

# One phase per flame, in 0..1.
PHASE_HLSL = """float p = Id * 7.31 + Rand * 3.17 + dot(ObjPos, float3(0.0123, 0.0217, 0.0079)) + Offset;
return frac(p);"""

# x = brightness (about 1, dipping when the flame gutters), y / z = sideways sway in -1..1.
FLICKER_HLSL = """float t = Time * Speed + Phase * 61.0;
float n = sin(t * 6.1) * 0.5 + sin(t * 13.7 + 1.3) * 0.3 + sin(t * 23.3 + 2.1) * 0.2;
float gutter = saturate(sin(t * 0.37 + Phase * 17.0) * 4.0 - 3.2);
float i = 1.0 + n * Amount - gutter * Gutter;
float sx = sin(t * 2.3) * 0.6 + sin(t * 5.9 + 0.7) * 0.4;
float sy = sin(t * 1.9 + 1.1) * 0.6 + sin(t * 4.7 + 2.3) * 0.4;
return float3(max(i, 0.05), sx, sy);"""

# The tip moves most (height squared); a bright flame stands taller.
FLAME_OFFSET_HLSL = """float h = saturate(Height);
float bend = h * h * Sway;
return float3(Flicker.y * bend, Flicker.z * bend, h * (Flicker.x - 1.0) * Stretch);"""

# A blue foot, a pale core, an orange tip.
FLAME_COLOR_HLSL = """float h = saturate(Height);
float3 c = lerp(Core, Tip, smoothstep(0.35, 1.0, h));
c = lerp(Base, c, smoothstep(0.0, 0.22, h));
return c * Intensity * Flicker.x * max(1.0 + Boost, 0.0);"""

WAX_GLOW_HLSL = """float g = pow(saturate(Glow), Falloff);
return Color * g * Intensity * Flicker.x * max(1.0 + Boost, 0.0);"""


def _log(msg):
    unreal.log("[candles] %s" % msg)


def _warn(msg):
    unreal.log_warning("[candles] %s" % msg)


# ------------------------------------------------------------------ meshes
def read_metas(folder):
    metas = []
    for p in sorted(glob.glob(os.path.join(folder, "*_Mars_SM.json"))):
        try:
            with open(p) as fh:
                metas.append(json.load(fh))
        except Exception as exc:
            _warn("%s unreadable: %s" % (p, exc))
    return metas


def import_meshes(path=None):
    """Legacy FBX import (Interchange off for the batch): authored normals, no lightmap UV generation (UV1 is data),
    no collision, sockets from the SOCKET_ empties."""
    if mc._in_pie():
        raise RuntimeError("stop PIE before importing (assets imported during PIE vanish)")
    src = path or EXPORT_DIR
    files = sorted(glob.glob(os.path.join(src, "*_Mars_SM.fbx")))
    if not files:
        _warn("no *_Mars_SM.fbx in %s" % src)
        return []
    tasks, names = [], []
    for f in files:
        name = os.path.splitext(os.path.basename(f))[0]
        task = mc._task(f, F_MESH, name)
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
                            ("remove_degenerates", True)):
            try:
                sm.set_editor_property(prop, value)
            except Exception:
                pass
        task.options = opts
        tasks.append(task)
        names.append(name)
    cvar = "Interchange.FeatureFlags.Import.FBX"
    was = unreal.SystemLibrary.get_console_variable_bool_value(cvar)
    unreal.SystemLibrary.execute_console_command(None, "%s 0" % cvar)
    try:
        mc._tools().import_asset_tasks(tasks)
    finally:
        unreal.SystemLibrary.execute_console_command(None, "%s %d" % (cvar, 1 if was else 0))
    sme = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
    reports = []
    for name in names:
        mesh = mc._asset(F_MESH, name)
        if mesh is None:
            _warn("mesh %s did not import" % name)
            continue
        uvs = sme.get_num_uv_channels(mesh, 0)
        slots = [str(s.get_editor_property("material_slot_name")) for s in mesh.get_editor_property("static_materials")]
        if uvs < 2:
            _warn("%s has %d UV channel(s): the flicker needs UV1 (candle id, height / glow)" % (name, uvs))
        reports.append({"name": name, "uv_channels": uvs, "slots": slots})
        EAL.save_loaded_asset(mesh)
    _log("%d of %d candle meshes imported from %s" % (len(reports), len(names), src))
    return reports


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


def _phase_and_flicker(g, x, y):
    """The shared head of both graphs: UV1, the per-flame phase, the flicker vector.  Returns (uv1.u, uv1.v, flicker,
    intensity boost node)."""
    g.group("Flicker")
    speed = g.scalar("Flicker Speed", 1.0, 0.0, 4.0, "How fast the flame dances.")
    amount = g.scalar("Flicker Amount", 0.22, 0.0, 1.0, "How far the brightness swings round its mean.")
    gutter = g.scalar("Gutter", 0.45, 0.0, 1.0, "How far the flame dips when it gutters, now and then.")
    g.group("Per Component (Custom Primitive Data)")
    offset = g.scalar("Phase Offset", 0.0, 0.0, 1.0, "Custom primitive data 0: shifts this component's flames in time.")
    offset.set_editor_property("use_custom_primitive_data", True)
    offset.set_editor_property("primitive_data_index", 0)
    boost = g.scalar("Intensity Offset", 0.0, -1.0, 2.0, "Custom primitive data 1: -1 puts this component's flames out, "
                                                         "+1 doubles them.")
    boost.set_editor_property("use_custom_primitive_data", True)
    boost.set_editor_property("primitive_data_index", 1)

    uv = g.expr(unreal.MaterialExpressionTextureCoordinate, x, y)
    uv.set_editor_property("coordinate_index", 1)
    u = g.expr(unreal.MaterialExpressionComponentMask, x + 220, y)
    for ch, on in (("r", True), ("g", False), ("b", False), ("a", False)):
        u.set_editor_property(ch, on)
    g.link(uv, "", u, "")
    v = g.expr(unreal.MaterialExpressionComponentMask, x + 220, y + 120)
    for ch, on in (("r", False), ("g", True), ("b", False), ("a", False)):
        v.set_editor_property(ch, on)
    g.link(uv, "", v, "")
    rand = g.expr(unreal.MaterialExpressionPerInstanceRandom, x, y + 260)
    pos = g.expr(unreal.MaterialExpressionObjectPositionWS, x, y + 360)
    time = g.expr(unreal.MaterialExpressionTime, x, y + 460)
    phase = g.custom("Flame Phase", PHASE_HLSL, [("Id", u, ""), ("Rand", rand, ""), ("ObjPos", pos, ""), ("Offset", offset, "")],
                     x + 480, y + 240, out=FLOAT1)
    flicker = g.custom("Flicker", FLICKER_HLSL, [("Time", time, ""), ("Speed", speed, ""), ("Phase", phase, ""),
                                                 ("Amount", amount, ""), ("Gutter", gutter, "")], x + 760, y + 320, out=FLOAT3)
    return u, v, flicker, boost


def build_flame_master():
    m = _master(FLAME_MASTER)
    m.set_editor_property("shading_model", unreal.MaterialShadingModel.MSM_UNLIT)
    m.set_editor_property("two_sided", False)
    g = mc._Graph(m, -2600)
    g.group("Flame")
    intensity = g.scalar("Intensity", 4.5, 0.0, 100.0, "Emissive strength of the core (tuned at the station gym's exposure).")
    core = g.vector("Core Color", (1.0, 0.78, 0.36, 1.0), "The body of the flame.")
    tip = g.vector("Tip Color", (1.0, 0.36, 0.06, 1.0), "The top of the flame.")
    base = g.vector("Base Color", (0.10, 0.16, 0.55, 1.0), "The blue foot at the wick.")
    sway = g.scalar("Sway", 0.55, 0.0, 3.0, "How far the tip leans (cm).")
    stretch = g.scalar("Stretch", 1.2, 0.0, 4.0, "How much taller a bright flame stands (cm per unit of brightness).")
    _, v, flicker, boost = _phase_and_flicker(g, -1500, -600)
    color = g.custom("Flame Colour", FLAME_COLOR_HLSL, [("Height", v, ""), ("Core", core, ""), ("Tip", tip, ""), ("Base", base, ""),
                                                        ("Intensity", intensity, ""), ("Flicker", flicker, ""), ("Boost", boost, "")],
                     -300, -500, out=FLOAT3)
    offset = g.custom("Flame Offset", FLAME_OFFSET_HLSL, [("Height", v, ""), ("Flicker", flicker, ""), ("Sway", sway, ""),
                                                          ("Stretch", stretch, "")], -300, 0, out=FLOAT3)
    g.finish({"EmissiveColor": (color, ""), "WorldPositionOffset": (offset, "")}, 200, -300)
    return m


def build_wax_master():
    m = _master(WAX_MASTER)
    m.set_editor_property("shading_model", unreal.MaterialShadingModel.MSM_DEFAULT_LIT)
    g = mc._Graph(m, -2600)
    g.group("Wax")
    tint = g.vector("Tint", (1.0, 1.0, 1.0, 1.0), "Multiplies the painted wax colour.")
    cavity = g.scalar("Cavity AO", 0.5, 0.0, 1.0, "How much the painted cavity (vertex alpha) darkens the wax.")
    rough = g.scalar("Roughness", 0.42, 0.0, 1.0)
    spec = g.scalar("Specular", 0.45, 0.0, 1.0)
    g.group("Glow")
    glow_color = g.vector("Glow Color", (1.0, 0.5, 0.16, 1.0), "The light coming through the wax under the flame.")
    glow_int = g.scalar("Glow Intensity", 0.9, 0.0, 20.0)
    falloff = g.scalar("Glow Falloff", 1.6, 0.2, 6.0, "Higher keeps the glow nearer the rim.")
    _, v, flicker, boost = _phase_and_flicker(g, -1500, -200)
    vc = g.expr(unreal.MaterialExpressionVertexColor, -1500, -900)
    base = g.custom("Wax Colour", "return Col * Tint * lerp(1.0, Alpha, Cavity);",          # the node's first pin is RGB only
                    [("Col", vc, ""), ("Alpha", vc, "A"), ("Tint", tint, ""), ("Cavity", cavity, "")], -700, -900, out=FLOAT3)
    glow = g.custom("Wax Glow", WAX_GLOW_HLSL, [("Glow", v, ""), ("Falloff", falloff, ""), ("Color", glow_color, ""),
                                                ("Intensity", glow_int, ""), ("Flicker", flicker, ""), ("Boost", boost, "")],
                    -300, -300, out=FLOAT3)
    g.finish({"BaseColor": (base, ""), "Roughness": (rough, ""), "Specular": (spec, ""), "EmissiveColor": (glow, "")}, 200, -600)
    return m


def build_materials():
    """Both masters (in place) and one instance of each; instance values an artist changed survive a rebuild."""
    made = []
    for build, master, inst in ((build_flame_master, FLAME_MASTER, "CandleFlame_Mars_MI"),
                                (build_wax_master, WAX_MASTER, "CandleWax_Mars_MI")):
        m = build()
        mi = mc._asset(F_MAT, inst)
        if mi is None:
            mi = mc._tools().create_asset(inst, F_MAT, unreal.MaterialInstanceConstant, unreal.MaterialInstanceConstantFactoryNew())
        MEL.set_material_instance_parent(mi, m)
        MEL.update_material_instance(mi)
        EAL.save_loaded_asset(mi)
        stats = MEL.get_statistics(m)
        made.append((master, MEL.get_num_material_expressions(m), stats.num_pixel_shader_instructions))
    _log("candle materials: %s" % made)
    return made


def assign_slots(path=None):
    n = 0
    for meta in read_metas(path or EXPORT_DIR):
        mesh = mc._asset(F_MESH, meta["name"])
        if mesh is None:
            continue
        for i, sm in enumerate(mesh.get_editor_property("static_materials")):
            slot = str(sm.get_editor_property("material_slot_name")).split(".")[0]
            mi = mc._asset(F_MAT, SLOT_INSTANCE.get(slot, ""))
            if mi is None:
                _warn("%s: no instance for slot %s" % (meta["name"], slot))
                continue
            mesh.set_material(i, mi)
            n += 1
        EAL.save_loaded_asset(mesh)
    _log("%d candle slots assigned" % n)
    return n


def run_all(path=None):
    reports = import_meshes(path)
    made = build_materials()
    assign_slots(path)
    return {"meshes": reports, "materials": made}
