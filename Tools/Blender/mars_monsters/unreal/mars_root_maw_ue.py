"""Editor side of the Root Maw pieces (build_root_maw_pieces.py): builds the vertex-colour master RootMaw_Mars_M (two-sided:
the bulb's inside shows dark through the gaping maw; for skeletal and instanced static meshes; VertexColor x Tint into BaseColor, darkened by BackfaceShade on back faces; VertexColor x
Emissive x Glow into Emissive, Glow = custom primitive data 0, default 1: the entity script dims the eyes through it), the
root master RootMawRoot_Mars_M (BaseColour -> TipColour along UV0.x, the builder's procedural roots' base -> tip, x the
Niagara particle's colour; flagged for Niagara mesh particles), one instance per slot (RootMawSkin_Mars_MI,
RootMawEye_Mars_MI, RootMawRoot_Mars_MI), imports the RootMaw_<Part>_Mars_SM FBXs through the Send to Unreal prop
importer (each slot bound to <Slot>_Mars_MI) and the skinned head RootMaw_Head_Mars_SKM (bones root and jaw, its own
skeleton RootMaw_Head_Mars_SKEL) through the Send to Unreal character importer, its slot bound by name. Removes the rigid
RootMaw_Lower/Upper_Mars_SM a first cut used (the head is skinned since Stephen's 2026-11-02 ruling). Re-runnable:
masters rebuilt IN PLACE (expressions emptied, never deleted), instances updated, meshes re-imported. The Niagara root
trail is mars_root_maw_niagara.py.

Run in a hidden editor (never during PIE):
    python ../../mars_environment/unreal/env_drive.py --port 9317 --module mars_root_maw_ue --alias rm \
        --call "rm.run_all()"
(env_drive puts its own folder on sys.path; this module adds its own.)
"""
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
SEND_TO_UNREAL = os.path.join(os.path.dirname(os.path.dirname(HERE)), "mars_send_to_unreal", "unreal")
for _p in (SEND_TO_UNREAL, HERE):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import mars_character_ue  # noqa: E402
import mars_prop_ue  # noqa: E402

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary

EXPORT_DIR = r"D:\Repo\Content\Monsters\RootMaw\export"
F_ROOT = "/Game/Mars/Gameplay/Monsters/RootMaw"
F_MESH = F_ROOT + "/Meshes"
F_MAT = F_ROOT + "/Materials"
MASTER = "RootMaw_Mars_M"
ROOT_MASTER = "RootMawRoot_Mars_M"
ROOTS = tuple("Root%d" % k for k in range(4))
PIECES = ("Throat",) + ROOTS
HEAD = "RootMaw_Head_Mars_SKM"
SKELETON = "RootMaw_Head_Mars_SKEL"
RETIRED = ("RootMaw_Lower_Mars_SM", "RootMaw_Upper_Mars_SM")
# the roots' base -> tip colours: build_root_maw_pieces.ROOT_BASE_SRGB / ROOT_TIP_SRGB (74, 46, 28) / (198, 140, 82), linear
ROOT_BASE = (0.069, 0.027, 0.011)
ROOT_TIP = (0.565, 0.262, 0.085)

# slot: (tint, roughness, emissive)
SLOTS = {
    "RootMawSkin": ((1.0, 1.0, 1.0), 0.75, 0.0),
    "RootMawEye":  ((1.0, 1.0, 1.0), 0.40, 6.0),
}
BACKFACE_SHADE = 0.06                           # the bulb's inside, seen through the gaping jaw: near black


def _tools():
    return unreal.AssetToolsHelpers.get_asset_tools()


def _path(folder, name):
    return "%s/%s.%s" % (folder, name, name)


def _load(folder, name):
    p = _path(folder, name)
    return unreal.load_asset(p) if EAL.does_asset_exist(p) else None


def _empty(name):
    m = _load(F_MAT, name)
    created = m is None
    if created:
        m = _tools().create_asset(name, F_MAT, unreal.Material, unreal.MaterialFactoryNew())
    for _ in range(8):
        if MEL.get_num_material_expressions(m) == 0:
            break
        MEL.delete_all_material_expressions(m)
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
    """RootMaw_Mars_M: lerp(VertexColor x Tint x BackfaceShade, VertexColor x Tint, TwoSidedSign as 0..1) -> BaseColor;
    VertexColor x Emissive x Glow -> Emissive; Roughness, Specular. Two-sided, for instanced static meshes."""
    m, created = _empty(MASTER)
    m.set_editor_property("two_sided", True)
    MEL.set_material_usage(m, unreal.MaterialUsage.MATUSAGE_INSTANCED_STATIC_MESHES)
    MEL.set_material_usage(m, unreal.MaterialUsage.MATUSAGE_SKELETAL_MESH)
    m.set_editor_property("used_with_skeletal_mesh", True)
    m.set_editor_property("used_with_instanced_static_meshes", True)
    vc = MEL.create_material_expression(m, unreal.MaterialExpressionVertexColor, -1200, -100)
    tint = _vector(m, "Tint", (1.0, 1.0, 1.0), -1200, 50)
    albedo = MEL.create_material_expression(m, unreal.MaterialExpressionMultiply, -950, -50)
    MEL.connect_material_expressions(vc, "", albedo, "A")
    MEL.connect_material_expressions(tint, "", albedo, "B")
    shade = _scalar(m, "BackfaceShade", BACKFACE_SHADE, -950, 100)
    dark = MEL.create_material_expression(m, unreal.MaterialExpressionMultiply, -750, 50)
    MEL.connect_material_expressions(albedo, "", dark, "A")
    MEL.connect_material_expressions(shade, "", dark, "B")
    sign = MEL.create_material_expression(m, unreal.MaterialExpressionTwoSidedSign, -950, 250)
    half = MEL.create_material_expression(m, unreal.MaterialExpressionConstantBiasScale, -750, 250)
    half.set_editor_property("bias", 1.0)
    half.set_editor_property("scale", 0.5)
    MEL.connect_material_expressions(sign, "", half, "")
    lerp = MEL.create_material_expression(m, unreal.MaterialExpressionLinearInterpolate, -500, 0)
    MEL.connect_material_expressions(dark, "", lerp, "A")
    MEL.connect_material_expressions(albedo, "", lerp, "B")
    MEL.connect_material_expressions(half, "", lerp, "Alpha")
    MEL.connect_material_property(lerp, "", unreal.MaterialProperty.MP_BASE_COLOR)
    emis = _scalar(m, "Emissive", 0.0, -950, 400)
    glow = _scalar(m, "Glow", 1.0, -950, 500)
    glow.set_editor_property("use_custom_primitive_data", True)
    glow.set_editor_property("primitive_data_index", 0)
    mul = MEL.create_material_expression(m, unreal.MaterialExpressionMultiply, -700, 420)
    MEL.connect_material_expressions(vc, "", mul, "A")
    MEL.connect_material_expressions(emis, "", mul, "B")
    mul2 = MEL.create_material_expression(m, unreal.MaterialExpressionMultiply, -450, 450)
    MEL.connect_material_expressions(mul, "", mul2, "A")
    MEL.connect_material_expressions(glow, "", mul2, "B")
    MEL.connect_material_property(mul2, "", unreal.MaterialProperty.MP_EMISSIVE_COLOR)
    for name, value, y, prop in (("Roughness", 0.75, 650, unreal.MaterialProperty.MP_ROUGHNESS),
                                 ("Specular", 0.35, 750, unreal.MaterialProperty.MP_SPECULAR)):
        MEL.connect_material_property(_scalar(m, name, value, -450, y), "", prop)
    MEL.recompile_material(m)
    EAL.save_loaded_asset(m)
    return m, {"created": created, "expressions": MEL.get_num_material_expressions(m)}


def build_root_master():
    """RootMawRoot_Mars_M: lerp(BaseColour, TipColour, UV0.x ^ TipFalloff) x the particle's colour (VertexColor on a Niagara
    mesh is Particles.Color: the system tints and darkens each root through it) -> BaseColor; Roughness, Specular. For
    Niagara mesh particles."""
    m, created = _empty(ROOT_MASTER)
    MEL.set_material_usage(m, unreal.MaterialUsage.MATUSAGE_NIAGARA_MESH_PARTICLES)
    m.set_editor_property("used_with_niagara_mesh_particles", True)
    uv = MEL.create_material_expression(m, unreal.MaterialExpressionTextureCoordinate, -1100, 0)
    mask = MEL.create_material_expression(m, unreal.MaterialExpressionComponentMask, -900, 0)
    mask.set_editor_property("r", True)
    mask.set_editor_property("g", False)
    MEL.connect_material_expressions(uv, "", mask, "")
    falloff = _scalar(m, "TipFalloff", 0.8, -900, 120)
    power = MEL.create_material_expression(m, unreal.MaterialExpressionPower, -700, 40)
    MEL.connect_material_expressions(mask, "", power, "Base")
    MEL.connect_material_expressions(falloff, "", power, "Exponent")
    lerp = MEL.create_material_expression(m, unreal.MaterialExpressionLinearInterpolate, -500, -100)
    MEL.connect_material_expressions(_vector(m, "BaseColour", ROOT_BASE, -800, -300), "", lerp, "A")
    MEL.connect_material_expressions(_vector(m, "TipColour", ROOT_TIP, -800, -180), "", lerp, "B")
    MEL.connect_material_expressions(power, "", lerp, "Alpha")
    particle = MEL.create_material_expression(m, unreal.MaterialExpressionVertexColor, -500, 150)
    mul = MEL.create_material_expression(m, unreal.MaterialExpressionMultiply, -300, -50)
    MEL.connect_material_expressions(lerp, "", mul, "A")
    MEL.connect_material_expressions(particle, "", mul, "B")
    MEL.connect_material_property(mul, "", unreal.MaterialProperty.MP_BASE_COLOR)
    for name, value, y, prop in (("Roughness", 0.85, 300, unreal.MaterialProperty.MP_ROUGHNESS),
                                 ("Specular", 0.3, 400, unreal.MaterialProperty.MP_SPECULAR)):
        MEL.connect_material_property(_scalar(m, name, value, -300, y), "", prop)
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


def build_instances(master, root_master):
    out = {}
    for slot, (tint, rough, emissive) in SLOTS.items():
        mi, created = _instance("%s_Mars_MI" % slot, master)
        MEL.set_material_instance_vector_parameter_value(mi, "Tint", unreal.LinearColor(tint[0], tint[1], tint[2], 1.0))
        MEL.set_material_instance_scalar_parameter_value(mi, "Roughness", rough)
        MEL.set_material_instance_scalar_parameter_value(mi, "Emissive", emissive)
        MEL.update_material_instance(mi)
        EAL.save_loaded_asset(mi)
        out[mi.get_name()] = {"created": created}
    mi, created = _instance("RootMawRoot_Mars_MI", root_master)
    MEL.update_material_instance(mi)
    EAL.save_loaded_asset(mi)
    out[mi.get_name()] = {"created": created}
    return out


def import_meshes():
    jobs = [{"fbx": os.path.join(EXPORT_DIR, "RootMaw_%s_Mars_SM.fbx" % p).replace("\\", "/"),
             "name": "RootMaw_%s_Mars_SM" % p, "folder": F_MESH, "sockets": []} for p in PIECES]
    res = mars_prop_ue.import_props(jobs, {"search_root": "/Game/Mars", "material_pattern": "{slot}_Mars_MI"})
    # nothing collides: the kernel's hurtbox and the surface motion's rays are the Maw's only physics
    sme = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
    for p in PIECES:
        mesh = _load(F_MESH, "RootMaw_%s_Mars_SM" % p)
        if mesh is not None:
            sme.remove_collisions(mesh)
            EAL.save_loaded_asset(mesh)
    return res


def import_head():
    """The skinned head through the character importer; on first import its skeleton is renamed SKELETON and its physics
    asset deleted (nothing on the Maw collides); its slot is bound to <slot>_Mars_MI by name."""
    first = _load(F_MESH, HEAD) is None
    job = {"fbx": os.path.join(EXPORT_DIR, HEAD + ".fbx").replace("\\", "/"), "folder": F_MESH, "name": HEAD,
           "kind": "skeletal", "skeleton": _path(F_MESH, SKELETON) if _load(F_MESH, SKELETON) else None}
    res = mars_character_ue.import_character([job], save=False)
    mesh = _load(F_MESH, HEAD)
    if mesh is None:
        return res
    if first:
        skel = mesh.skeleton
        if skel is not None and skel.get_name() != SKELETON:
            EAL.rename_asset(skel.get_path_name().split(".")[0], "%s/%s" % (F_MESH, SKELETON))
        phys = mesh.physics_asset
        if phys is not None:
            mesh.set_editor_property("physics_asset", None)
            EAL.delete_asset(phys.get_path_name().split(".")[0])
    mats = list(mesh.materials)
    for k, m in enumerate(mats):
        mi = _load(F_MAT, "%s_Mars_MI" % m.material_slot_name)
        if mi is not None:
            m.material_interface = mi
            mats[k] = m
    mesh.set_editor_property("materials", mats)
    EAL.save_loaded_asset(mesh)
    if mesh.skeleton is not None:
        EAL.save_loaded_asset(mesh.skeleton)
    return res


def retire_cut_pieces():
    """Deletes the rigid upper/lower pieces the first cut used (nothing references them since the head is skinned)."""
    gone = []
    for name in RETIRED:
        path = "%s/%s" % (F_MESH, name)
        if EAL.does_asset_exist(path) and EAL.delete_asset(path):
            gone.append(name)
    return gone


def head_report():
    mesh = _load(F_MESH, HEAD)
    if mesh is None:
        return None
    box = mesh.get_bounds().box_extent if hasattr(mesh, "get_bounds") else None
    return {"skeleton": mesh.skeleton.get_name() if mesh.skeleton else None,
            "physics": mesh.physics_asset.get_name() if mesh.physics_asset else None,
            "materials": {str(m.material_slot_name): (m.material_interface.get_name() if m.material_interface else None)
                          for m in mesh.materials},
            "extent": [round(box.x, 2), round(box.y, 2), round(box.z, 2)] if box is not None else None}


def mesh_report():
    out = {}
    for p in PIECES:
        mesh = _load(F_MESH, "RootMaw_%s_Mars_SM" % p)
        if mesh is None:
            out[p] = None
            continue
        box = mesh.get_bounding_box()
        out[p] = {"min": [round(v, 2) for v in (box.min.x, box.min.y, box.min.z)],
                  "max": [round(v, 2) for v in (box.max.x, box.max.y, box.max.z)],
                  "materials": {str(m.material_slot_name): (m.material_interface.get_name() if m.material_interface
                                                            else None) for m in mesh.static_materials}}
    return out


def run_all():
    if mars_prop_ue.base._in_pie():
        return {"error": "the editor is in PIE - stop it and run again"}
    for folder in (F_MESH, F_MAT):
        EAL.make_directory(folder)
    master, master_info = build_master()
    root_master, root_info = build_root_master()
    instances = build_instances(master, root_master)
    res = import_meshes()
    head = import_head()
    return {"master": master_info, "root_master": root_info, "instances": instances, "import": res, "head": head,
            "retired": retire_cut_pieces(), "meshes": mesh_report(), "head_mesh": head_report()}
