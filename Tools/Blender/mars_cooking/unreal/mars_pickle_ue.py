"""Editor Python for the pickle (food_spec.INGREDIENTS["Pickle"], built by build_food_produce.py): imports
Pickle_Mars_SM as a runtime-mesh solid (CPU access, every triangle kept), builds Pickle_Mars_M and its two instances,
and puts the skin instance on the mesh.

The pickle is cut at the bench, and a cut face has to read as a pickle: pale flesh, a ring of seed pockets round a soft
core, a thin dark rind. The runtime slicer gives a cut face one flat colour and planar UVs anchored on the blade, so
neither can carry a pattern that stays centred on the pickle. Pickle_Mars_M draws it as a solid texture instead: the
pixel's position in the piece's own local frame (the slicer never re-centres a piece) says how far it is from the long
axis and where along it, so every cut, straight across or lengthwise, shows the section that lies there. The axis and
the taper come from the mesh's sidecar (section_*), the numbers build_food_produce.build_pickle writes.

    Pickle_Mars_M                  master (opaque, default lit). Section 0 = the skin (the painted vertex colours),
                                   Section 1 = a cut face (the solid texture).
    Pickle_Mars_MI                 Section 0: the mesh's Skin slot
    Pickle_Section_Mars_MI         Section 1: the cut cap's slot (Food_Pickle_Mars in Script/Food/Mars_Food_Def.as)

Run in the editor (Monolith editor_query run_python, or the Python console):

    import sys, importlib
    sys.path.insert(0, r"D:\\Repo\\Mars\\Tools\\Blender\\mars_cooking\\unreal")
    import mars_pickle_ue as mp; importlib.reload(mp)
    mp.run_all()          # import_mesh, build_material, build_instances, assign_materials

The master is rebuilt IN PLACE (its graph emptied and redrawn, then recompiled), never replaced: replacing a master
under live instances asserts in the renderer (see mars_cooking_ue).
"""
import importlib
import json
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
for _p in (HERE, os.path.dirname(HERE)):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import mars_cooking_ue as mc  # noqa: E402
import mars_food_ue as mf  # noqa: E402
import mars_food_plan as plan  # noqa: E402

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary

MESH = "Pickle_Mars_SM"
MASTER = "Pickle_Mars_M"
SKIN_MI = "Pickle_Mars_MI"
SECTION_MI = "Pickle_Section_Mars_MI"


def _log(msg):
    unreal.log("MarsPickle: %s" % msg)


def _warn(msg):
    unreal.log_warning("MarsPickle: %s" % msg)


def _lin(r, g, b):
    """sRGB bytes -> linear, as food_common.srgb paints them."""
    def f(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (f(r), f(g), f(b), 1.0)


# The cut face, in the piece's local frame (Unreal cm: x along the pickle, the axis at y = 0, z = Axis.y). The radius the
# skin has at x is build_food_produce.pickle_radius; t runs 0 on the axis to 1 at the skin. Pockets: Lobes.x seed pockets
# round the axis (one of them straight up, so a blade coming down through the axis opens a row of seeds), each a
# teardrop of jelly holding a row of seeds every Lobes.y cm along the pickle.
SECTION_HLSL = """float u = clamp((P.x - Axis.x) / max(Axis.w, 0.01), -0.999, 0.999);
float skin = Axis.z * pow(1.0 - pow(abs(u), Taper.x), 1.0 / Taper.y) * (1.0 + Taper.z * u);
float2 q = float2(P.y, P.z - Axis.y);
float t = saturate(length(q) / max(skin, 0.05));
float a = (atan2(q.y, q.x) / 6.2831853 + 0.25) * Lobes.x;
float cell = floor(a + 0.5);
float f = a - cell;

float pocket = 1.0 - smoothstep(0.72, 1.0, length(float2((t - 0.37) / 0.23, f / 0.36)));
float row = frac(P.x / max(Lobes.y, 0.05) + frac(sin(cell * 12.9898) * 43758.5453)) - 0.5;
float seed = 1.0 - smoothstep(0.65, 1.0, length(float3((t - 0.37) / 0.11, f / 0.17, row / 0.34)));
float core = 1.0 - smoothstep(0.05, 0.16, t);

float3 c = lerp(Inner.rgb, Flesh.rgb, smoothstep(0.52, 0.72, t));
c = lerp(c, Jelly.rgb, saturate(max(pocket, core) * 0.9));
c = lerp(c, Seed.rgb, seed);
c = lerp(c, Rind.rgb, smoothstep(0.86, 0.95, t));

Roughness = lerp(SkinRoughness, lerp(0.34, 0.5, seed), Section);
return lerp(saturate(VC), c, Section);"""

# (name, sRGB bytes, description): the cut face's colours.
COLOURS = (
    ("Flesh", (216, 224, 158), "The firm flesh under the rind."),
    ("Inner", (198, 206, 118), "The softer flesh round the seed pockets."),
    ("Jelly", (148, 160, 70), "The seed pockets' jelly and the core."),
    ("Seed", (238, 230, 184), "The seeds."),
    ("Rind", (62, 84, 30), "The thin skin at the edge of a cut."),
)


def read_section(export_dir=None):
    """The sidecar's section_* numbers (build_food_produce.build_pickle), Unreal local cm."""
    path = os.path.join(plan.food_dir(export_dir), MESH + ".json")
    with open(path) as fh:
        meta = json.load(fh)
    missing = [k for k in ("section_centre_x_cm", "section_axis_z_cm", "section_radius_cm", "section_half_length_cm",
                           "section_taper_a", "section_taper_b", "section_fatten") if k not in meta]
    if missing:
        raise RuntimeError("%s has no %s: rebuild the pickle (build_food_produce.py --only Pickle --export)" % (
            path, ", ".join(missing)))
    return meta


# ------------------------------------------------------------------ mesh
def import_mesh(export_dir=None):
    """Pickle_Mars_SM as mars_food_ue imports a runtime-mesh solid: legacy FBX importer, vertex colours, no degenerate
    removal at import or build, CPU access, one hull of simple collision."""
    if mc._in_pie():
        raise RuntimeError("stop PIE before importing (assets imported during PIE vanish)")
    src = plan.food_dir(export_dir)
    path = os.path.join(src, MESH + ".fbx")
    if not os.path.isfile(path):
        raise RuntimeError("no %s: run build_food_produce.py --only Pickle --export" % path)
    meta = read_section(export_dir)
    existing = mc._asset(mf.F_MESH, MESH)                  # a reimport reads the asset's stored FBX options
    data = existing.get_editor_property("asset_import_data") if existing is not None else None
    if data is not None:
        mf._set(data, "remove_degenerates", False)
    cvar = "Interchange.FeatureFlags.Import.FBX"            # the legacy importer honours FbxImportUI
    was = unreal.SystemLibrary.get_console_variable_bool_value(cvar)
    unreal.SystemLibrary.execute_console_command(None, "%s 0" % cvar)
    try:
        mc._tools().import_asset_tasks([mf._mesh_task(path, MESH, True)])
    finally:
        unreal.SystemLibrary.execute_console_command(None, "%s %d" % (cvar, 1 if was else 0))
    mesh = mc._asset(mf.F_MESH, MESH)
    if mesh is None:
        raise RuntimeError("%s did not import" % MESH)
    sme = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
    mf._collision(sme, mesh, True)
    mf._cpu_access(sme, mesh)
    mf._keep_degenerates(sme, mesh)
    mf._check_mesh(sme, mesh, meta)
    EAL.save_loaded_asset(mesh)
    _log("imported %s" % MESH)
    return mesh


# ------------------------------------------------------------------ material
def _empty(material):
    """delete_all_material_expressions skips nodes: repeat until the graph is empty."""
    for _ in range(16):
        if MEL.get_num_material_expressions(material) == 0:
            return
        MEL.delete_all_material_expressions(material)
    _warn("%s still has %d expressions" % (material.get_name(), MEL.get_num_material_expressions(material)))


def build_material(export_dir=None):
    meta = read_section(export_dir)
    m = mc._asset(mf.F_MAT, MASTER)
    if m is None:
        m = mc._tools().create_asset(MASTER, mf.F_MAT, unreal.Material, unreal.MaterialFactoryNew())
    else:
        _empty(m)
    g = mc._Graph(m, -2600)

    g.group("Pickle")
    section = g.scalar("Section", 0.0, 0.0, 1.0, "0 = the skin (the painted vertex colours), 1 = a cut face (the "
                       "solid texture read from the piece's local position).")
    skin_rough = g.scalar("Skin Roughness", 0.42, 0.0, 1.0, "The brined skin's roughness.")
    g.group("Section shape")
    axis = g.vector("Axis", (meta["section_centre_x_cm"], meta["section_axis_z_cm"], meta["section_radius_cm"],
                             meta["section_half_length_cm"]),
                    "The pickle's long axis in its mesh's local cm (the sidecar's section_* numbers).",
                    ("Centre X", "Axis Z", "Radius", "Half Length"))
    taper = g.vector("Taper", (meta["section_taper_a"], meta["section_taper_b"], meta["section_fatten"], 0.0),
                     "The skin's radius along the pickle: R (1 - |u|^A)^(1/B) (1 + Fatten u), as the mesh builder's.",
                     ("A", "B", "Fatten", "-"))
    lobes = g.vector("Lobes", (6.0, 1.15, 0.0, 0.0), "Seed pockets round the axis, and the seeds' spacing along it (cm).",
                     ("Pockets", "Seed Spacing", "-", "-"))
    g.group("Section colours")
    colours = [(name, g.vector(name, _lin(*rgb), desc)) for name, rgb, desc in COLOURS]

    x = -600
    local, _ = g.local_space(x - 700, -900)
    vc = g.expr(unreal.MaterialExpressionVertexColor, x - 700, -500)
    inputs = [("P", local, ""), ("VC", vc, ""), ("Section", section, ""), ("SkinRoughness", skin_rough, ""),
              ("Axis", axis, "RGBA"), ("Taper", taper, "RGBA"), ("Lobes", lobes, "RGBA")]
    inputs += [(name, node, "") for name, node in colours]
    look = g.custom("Pickle skin / cut face", SECTION_HLSL, inputs, x, -900, mc.FLOAT3, (("Roughness", mc.FLOAT1),))

    MEL.connect_material_property(look, "", unreal.MaterialProperty.MP_BASE_COLOR)
    MEL.connect_material_property(look, "Roughness", unreal.MaterialProperty.MP_ROUGHNESS)
    MEL.recompile_material(m)
    EAL.save_loaded_asset(m)
    _log("built %s (%d expressions)" % (MASTER, MEL.get_num_material_expressions(m)))
    return m


def build_instances():
    parent = mc._asset(mf.F_MAT, MASTER)
    if parent is None:
        raise RuntimeError("%s is not built" % MASTER)
    for name, section in ((SKIN_MI, 0.0), (SECTION_MI, 1.0)):
        inst = mc._asset(mf.F_INST, name)
        if inst is None:
            inst = mc._tools().create_asset(name, mf.F_INST, unreal.MaterialInstanceConstant,
                                            unreal.MaterialInstanceConstantFactoryNew())
        MEL.set_material_instance_parent(inst, parent)
        MEL.set_material_instance_scalar_parameter_value(inst, "Section", section)
        MEL.update_material_instance(inst)
        EAL.save_loaded_asset(inst)
    _log("instances %s, %s" % (SKIN_MI, SECTION_MI))


def assign_materials():
    mesh = mc._asset(mf.F_MESH, MESH)
    skin = mc._asset(mf.F_INST, SKIN_MI)
    if mesh is None or skin is None:
        raise RuntimeError("%s or %s is missing" % (MESH, SKIN_MI))
    for i in range(len(mesh.get_editor_property("static_materials"))):
        mesh.set_material(i, skin)
    EAL.save_loaded_asset(mesh)
    _log("%s wears %s" % (MESH, SKIN_MI))


def run_all(export_dir=None):
    import_mesh(export_dir)
    build_material(export_dir)
    build_instances()
    assign_materials()
    return "pickle ok"
