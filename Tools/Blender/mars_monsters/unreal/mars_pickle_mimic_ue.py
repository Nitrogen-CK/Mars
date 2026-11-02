"""Editor side of the pickle mimic pieces (build_pickle_mimic_pieces.py): builds the flat-colour master PickleMimic_Mars_M
(Color, Roughness, Metallic, Emissive x Color x Glow into Emissive, where Glow is custom primitive data 0 (default 1): the
entity script dims the eyes through it; flagged for instanced static meshes, which is how the game draws the rigid
pieces), the translucent glass master PickleMimicGlass_Mars_M, one instance per material slot (<Slot>_Mars_MI), and the
jar's brine instance PickleMimicBrine_Mars_MI, then imports the PickleMimic_<Part>_Mars_SM FBXs through the Send to
Unreal prop importer (SOCKET_ empties -> mesh sockets, each slot bound to <Slot>_Mars_MI). Re-runnable: masters rebuilt
IN PLACE (expressions emptied, never deleted - live instances keep their parent), instances updated, meshes re-imported.

The brine is NOT built here. PickleMimicBrine_Mars_MI is a child of the pickle brine shader's Pickle Jar instance
(PickleJarBrine_Mars_MI, built by mars_environment/unreal/mars_potion_ue.py's build_variants: the Brine and Pickle Jar
switches, pickles traced inside a cylinder) and overrides only the jar's size (Radius, Half Height), so every retune of
the brine lands on the mimic too. Until that instance exists it falls back to PickleBrine_Mars_MI (the round flask's
brine: no pickles, sphere maths); re-run reparent_brine() once the brine work lands.

Run in a hidden editor (never during PIE):
    python ../../mars_environment/unreal/env_drive.py --port 9319 --module mars_pickle_mimic_ue --alias pm \
        --call "pm.run_all()"
(env_drive puts its own folder on sys.path; this module adds its own.)
"""
import json
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
SEND_TO_UNREAL = os.path.join(os.path.dirname(os.path.dirname(HERE)), "mars_send_to_unreal", "unreal")
for _p in (SEND_TO_UNREAL, HERE):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import mars_prop_ue  # noqa: E402

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary

EXPORT_DIR = r"D:\Repo\Content\Monsters\PickleMimic\export"
F_ROOT = "/Game/Mars/Gameplay/Monsters/PickleMimic"
F_MESH = F_ROOT + "/Meshes"
F_MAT = F_ROOT + "/Materials"
MASTER = "PickleMimic_Mars_M"
GLASS_MASTER = "PickleMimicGlass_Mars_M"
BRINE = "PickleMimicBrine_Mars_MI"
F_POTION_MAT = "/Game/Mars/Gameplay/Items/Potion/Materials"
BRINE_PARENTS = ("PickleJarBrine_Mars_MI", "PickleBrine_Mars_MI")     # preferred first
SHARDS = tuple("Shard%02d" % k for k in range(10))
PIECES = ("Glass", "Liquid", "Frame", "Mouth", "Face", "Lid", "Bow", "Foot") + SHARDS

# slot: (linear colour, roughness, metallic, emissive) - the same numbers as build_pickle_mimic_pieces.PALETTE
SLOTS = {
    "PickleMimicWood":     ((0.46, 0.16, 0.045), 0.80, 0.0, 0.0),
    "PickleMimicWoodDark": ((0.25, 0.085, 0.025), 0.80, 0.0, 0.0),
    "PickleMimicBone":     ((0.87, 0.76, 0.60), 0.55, 0.0, 0.0),
    "PickleMimicGum":      ((0.26, 0.014, 0.018), 0.60, 0.0, 0.0),
    "PickleMimicVoid":     ((0.004, 0.003, 0.003), 1.00, 0.0, 0.0),
    "PickleMimicEye":      ((1.00, 0.80, 0.35), 0.40, 0.0, 6.0),
    "PickleMimicCloth":    ((0.60, 0.016, 0.022), 0.85, 0.0, 0.0),
}
GLASS = {"Color": (0.80, 0.92, 0.86), "Opacity": 0.10, "EdgeOpacity": 0.45, "Roughness": 0.06, "Specular": 0.6}
# the cracked glass (the shards standing in place while the mimic is hurt): paler and more opaque at grazing angles, so the
# breaks' faces, seen edge-on, read as white lines
GLASS_CRACKED = {"Color": (0.93, 0.98, 0.95), "Opacity": 0.16, "EdgeOpacity": 0.9}
# the brine cylinder (build_pickle_mimic_pieces LIQUID_RADIUS / LIQUID_HALF), cm
BRINE_SIZE = {"Radius": 27.0, "Half Height": 23.4}


def _tools():
    return unreal.AssetToolsHelpers.get_asset_tools()


def _path(folder, name):
    return "%s/%s.%s" % (folder, name, name)


def _load(folder, name):
    p = _path(folder, name)
    return unreal.load_asset(p) if EAL.does_asset_exist(p) else None


def _empty(name, folder):
    m = _load(folder, name)
    created = m is None
    if created:
        m = _tools().create_asset(name, folder, unreal.Material, unreal.MaterialFactoryNew())
    for _ in range(8):
        if MEL.get_num_material_expressions(m) == 0:
            break
        MEL.delete_all_material_expressions(m)
    MEL.set_material_usage(m, unreal.MaterialUsage.MATUSAGE_INSTANCED_STATIC_MESHES)
    m.set_editor_property("used_with_instanced_static_meshes", True)
    return m, created


def _scalar(m, name, value, x, y):
    p = MEL.create_material_expression(m, unreal.MaterialExpressionScalarParameter, x, y)
    p.set_editor_property("parameter_name", name)
    p.set_editor_property("default_value", value)
    return p


def _vector(m, name, rgb, x, y):
    p = MEL.create_material_expression(m, unreal.MaterialExpressionVectorParameter, x, y)
    p.set_editor_property("parameter_name", name)
    p.set_editor_property("default_value", unreal.LinearColor(rgb[0], rgb[1], rgb[2], 1.0))
    return p


def build_master():
    """PickleMimic_Mars_M: Color -> BaseColor, Color x Emissive x Glow -> EmissiveColor, Roughness, Metallic. Glow reads
    custom primitive data 0 (default 1 where the primitive sets none, e.g. every ISM piece)."""
    m, created = _empty(MASTER, F_MAT)
    color = _vector(m, "Color", (0.46, 0.16, 0.045), -900, -150)
    MEL.connect_material_property(color, "", unreal.MaterialProperty.MP_BASE_COLOR)
    emis = _scalar(m, "Emissive", 0.0, -900, 50)
    glow = _scalar(m, "Glow", 1.0, -900, 150)
    glow.set_editor_property("use_custom_primitive_data", True)
    glow.set_editor_property("primitive_data_index", 0)
    mul = MEL.create_material_expression(m, unreal.MaterialExpressionMultiply, -600, 0)
    MEL.connect_material_expressions(color, "", mul, "A")
    MEL.connect_material_expressions(emis, "", mul, "B")
    mul2 = MEL.create_material_expression(m, unreal.MaterialExpressionMultiply, -350, 50)
    MEL.connect_material_expressions(mul, "", mul2, "A")
    MEL.connect_material_expressions(glow, "", mul2, "B")
    MEL.connect_material_property(mul2, "", unreal.MaterialProperty.MP_EMISSIVE_COLOR)
    for name, value, y, prop in (("Roughness", 0.7, 250, unreal.MaterialProperty.MP_ROUGHNESS),
                                 ("Metallic", 0.0, 350, unreal.MaterialProperty.MP_METALLIC)):
        MEL.connect_material_property(_scalar(m, name, value, -350, y), "", prop)
    MEL.recompile_material(m)
    EAL.save_loaded_asset(m)
    return m, {"created": created, "expressions": MEL.get_num_material_expressions(m)}


def build_glass_master():
    """PickleMimicGlass_Mars_M: translucent, lit per pixel, a fresnel opacity (Opacity face-on, EdgeOpacity at grazing),
    the glass tint, low roughness. Two-sided off: the shell has an inside of its own."""
    m, created = _empty(GLASS_MASTER, F_MAT)
    m.set_editor_property("blend_mode", unreal.BlendMode.BLEND_TRANSLUCENT)
    m.set_editor_property("translucency_lighting_mode", unreal.TranslucencyLightingMode.TLM_SURFACE_PER_PIXEL_LIGHTING)
    color = _vector(m, "Color", GLASS["Color"], -900, -200)
    MEL.connect_material_property(color, "", unreal.MaterialProperty.MP_BASE_COLOR)
    face = _scalar(m, "Opacity", GLASS["Opacity"], -900, 0)
    edge = _scalar(m, "EdgeOpacity", GLASS["EdgeOpacity"], -900, 100)
    fres = MEL.create_material_expression(m, unreal.MaterialExpressionFresnel, -900, 200)
    lerp = MEL.create_material_expression(m, unreal.MaterialExpressionLinearInterpolate, -500, 50)
    MEL.connect_material_expressions(face, "", lerp, "A")
    MEL.connect_material_expressions(edge, "", lerp, "B")
    MEL.connect_material_expressions(fres, "", lerp, "Alpha")
    MEL.connect_material_property(lerp, "", unreal.MaterialProperty.MP_OPACITY)
    MEL.connect_material_property(_scalar(m, "Roughness", GLASS["Roughness"], -500, 250), "",
                                  unreal.MaterialProperty.MP_ROUGHNESS)
    MEL.connect_material_property(_scalar(m, "Specular", GLASS["Specular"], -500, 350), "",
                                  unreal.MaterialProperty.MP_SPECULAR)
    MEL.recompile_material(m)
    EAL.save_loaded_asset(m)
    return m, {"created": created, "expressions": MEL.get_num_material_expressions(m)}


def _instance(name, parent):
    mi = _load(F_MAT, name)
    created = mi is None
    if created:
        mi = _tools().create_asset(name, F_MAT, unreal.MaterialInstanceConstant,
                                   unreal.MaterialInstanceConstantFactoryNew())
    MEL.set_material_instance_parent(mi, parent)
    return mi, created


def build_instances(master, glass_master):
    out = {}
    for slot, (rgb, rough, metal, emissive) in SLOTS.items():
        mi, created = _instance("%s_Mars_MI" % slot, master)
        MEL.set_material_instance_vector_parameter_value(mi, "Color", unreal.LinearColor(rgb[0], rgb[1], rgb[2], 1.0))
        MEL.set_material_instance_scalar_parameter_value(mi, "Roughness", rough)
        MEL.set_material_instance_scalar_parameter_value(mi, "Metallic", metal)
        MEL.set_material_instance_scalar_parameter_value(mi, "Emissive", emissive)
        MEL.update_material_instance(mi)
        EAL.save_loaded_asset(mi)
        out[mi.get_name()] = {"created": created}
    mi, created = _instance("PickleMimicGlass_Mars_MI", glass_master)
    MEL.update_material_instance(mi)
    EAL.save_loaded_asset(mi)
    out[mi.get_name()] = {"created": created}
    mi, created = _instance("PickleMimicGlassCracked_Mars_MI", glass_master)
    rgb = GLASS_CRACKED["Color"]
    MEL.set_material_instance_vector_parameter_value(mi, "Color", unreal.LinearColor(rgb[0], rgb[1], rgb[2], 1.0))
    MEL.set_material_instance_scalar_parameter_value(mi, "Opacity", GLASS_CRACKED["Opacity"])
    MEL.set_material_instance_scalar_parameter_value(mi, "EdgeOpacity", GLASS_CRACKED["EdgeOpacity"])
    MEL.update_material_instance(mi)
    EAL.save_loaded_asset(mi)
    out[mi.get_name()] = {"created": created}
    return out


def reparent_brine():
    """PickleMimicBrine_Mars_MI under the best brine there is (PickleJarBrine_Mars_MI, else PickleBrine_Mars_MI), with
    the jar's size; returns which parent it took."""
    parent = None
    for name in BRINE_PARENTS:
        parent = _load(F_POTION_MAT, name)
        if parent is not None:
            break
    if parent is None:
        unreal.log_warning("[PickleMimic] no brine instance under %s: the jar's brine keeps no parent" % F_POTION_MAT)
        return {"parent": None}
    mi, created = _instance(BRINE, parent)
    for pname, value in BRINE_SIZE.items():
        MEL.set_material_instance_scalar_parameter_value(mi, pname, value)
    MEL.update_material_instance(mi)
    EAL.save_loaded_asset(mi)
    jar = parent.get_name() == BRINE_PARENTS[0]
    if not jar:
        unreal.log_warning("[PickleMimic] %s is a placeholder under %s (no Pickle Jar instance yet): re-run "
                           "reparent_brine() once PickleJarBrine_Mars_MI exists" % (BRINE, parent.get_name()))
    return {"parent": parent.get_name(), "pickle_jar": jar, "created": created, "size": BRINE_SIZE}


def _sidecar(part):
    try:
        with open(os.path.join(EXPORT_DIR, "PickleMimic_%s_Mars_SM.json" % part)) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def import_meshes():
    jobs = []
    for p in PIECES:
        jobs.append({"fbx": os.path.join(EXPORT_DIR, "PickleMimic_%s_Mars_SM.fbx" % p).replace("\\", "/"),
                     "name": "PickleMimic_%s_Mars_SM" % p, "folder": F_MESH,
                     "sockets": sorted((_sidecar(p).get("sockets") or {}).keys())})
    res = mars_prop_ue.import_props(jobs, {"search_root": "/Game/Mars", "material_pattern": "{slot}_Mars_MI"})
    # nothing collides: the kernel's hurtboxes and the walker's probes are the mimic's only physics
    sme = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
    for p in PIECES:
        mesh = _load(F_MESH, "PickleMimic_%s_Mars_SM" % p)
        if mesh is not None:
            sme.remove_collisions(mesh)
            EAL.save_loaded_asset(mesh)
    return res


def mesh_report():
    out = {}
    for p in PIECES:
        mesh = _load(F_MESH, "PickleMimic_%s_Mars_SM" % p)
        if mesh is None:
            out[p] = None
            continue
        box = mesh.get_bounding_box()
        sockets = {}
        for name in _sidecar(p).get("sockets", {}):
            s = mesh.find_socket(name)
            loc = s.get_editor_property("relative_location") if s is not None else None
            sockets[name] = [round(loc.x, 2), round(loc.y, 2), round(loc.z, 2)] if loc is not None else None
        out[p] = {"min": [round(v, 2) for v in (box.min.x, box.min.y, box.min.z)],
                  "max": [round(v, 2) for v in (box.max.x, box.max.y, box.max.z)],
                  "materials": {str(m.material_slot_name): (m.material_interface.get_name() if m.material_interface
                                                            else None) for m in mesh.static_materials},
                  "sockets": sockets}
    return out


def run_all():
    if mars_prop_ue.base._in_pie():
        return {"error": "the editor is in PIE - stop it and run again"}
    for folder in (F_MESH, F_MAT):
        EAL.make_directory(folder)
    master, master_info = build_master()
    glass, glass_info = build_glass_master()
    instances = build_instances(master, glass)
    brine = reparent_brine()
    res = import_meshes()
    return {"master": master_info, "glass": glass_info, "instances": instances, "brine": brine, "import": res,
            "meshes": mesh_report()}
