"""Editor side of the crawler pieces (build_crawler_pieces.py): imports the spider's base colour texture, builds the
textured master Crawler_Mars_M (BaseColor texture x Tint, Roughness, Specular; usable on instanced static meshes, which
is how UMars_Crawler_EntityScript draws its parts) and its instance Crawler_Mars_MI, then imports the nine
Crawler_<Part>_Mars_SM FBXs through the Send to Unreal prop importer, which binds their "Crawler" slot to
Crawler_Mars_MI. Re-runnable: the texture and the meshes re-import in place, the master is rebuilt in place.

Run in the editor's Python (Monolith `editor_query run_python`), never during PIE:

    import sys, importlib
    sys.path.insert(0, r"D:\\Repo\\Mars\\Tools\\Blender\\mars_monsters\\unreal")
    import mars_crawler_ue as mcu; importlib.reload(mcu)
    print(mcu.run_all())
"""
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
SEND_TO_UNREAL = os.path.join(os.path.dirname(os.path.dirname(HERE)), "mars_send_to_unreal", "unreal")
for _p in (SEND_TO_UNREAL,):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import mars_prop_ue  # noqa: E402

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary

EXPORT_DIR = r"D:\Repo\Content\Monsters\Crawler\export"
TEXTURE_SOURCE = r"D:\Repo\Content\Monsters\Crawler\source\spider+3d+model.fbm\spider+3d+model_basecolor.jpg"
F_ROOT = "/Game/Mars/Gameplay/Monsters/Crawler"
F_MESH = F_ROOT + "/Meshes"
F_MAT = F_ROOT + "/Materials"
TEXTURE = "Crawler_BaseColor_Mars_T"
MASTER = "Crawler_Mars_M"
INSTANCE = "Crawler_Mars_MI"
PIECES = ("Body", "LegUpperFront", "LegLowerFront", "LegUpperMid", "LegLowerMid", "LegUpperBack", "LegLowerBack", "Foot",
          "Fang")
TEXTURE_MAX_SIZE = 2048                       # the source is 4096 square; the crawler never fills the screen


def _tools():
    return unreal.AssetToolsHelpers.get_asset_tools()


def _path(folder, name):
    return "%s/%s.%s" % (folder, name, name)


def _load(folder, name):
    p = _path(folder, name)
    return unreal.load_asset(p) if EAL.does_asset_exist(p) else None


def import_texture():
    task = unreal.AssetImportTask()
    task.filename = TEXTURE_SOURCE
    task.destination_path = F_MAT
    task.destination_name = TEXTURE
    task.replace_existing = True
    task.automated = True
    task.save = False
    _tools().import_asset_tasks([task])
    tex = _load(F_MAT, TEXTURE)
    if tex is None:
        raise RuntimeError("texture %s did not import" % TEXTURE)
    tex.set_editor_property("srgb", True)
    tex.set_editor_property("max_texture_size", TEXTURE_MAX_SIZE)
    EAL.save_loaded_asset(tex)
    return tex


def build_master(tex):
    m = _load(F_MAT, MASTER)
    if m is None:
        m = _tools().create_asset(MASTER, F_MAT, unreal.Material, unreal.MaterialFactoryNew())
    for _ in range(8):
        if MEL.get_num_material_expressions(m) == 0:
            break
        MEL.delete_all_material_expressions(m)
    m.set_editor_property("used_with_instanced_static_meshes", True)

    sample = MEL.create_material_expression(m, unreal.MaterialExpressionTextureSampleParameter2D, -700, -200)
    sample.set_editor_property("parameter_name", "BaseColor")
    sample.set_editor_property("texture", tex)
    tint = MEL.create_material_expression(m, unreal.MaterialExpressionVectorParameter, -700, 100)
    tint.set_editor_property("parameter_name", "Tint")
    tint.set_editor_property("default_value", unreal.LinearColor(1.0, 1.0, 1.0, 1.0))
    mul = MEL.create_material_expression(m, unreal.MaterialExpressionMultiply, -350, -100)
    MEL.connect_material_expressions(sample, "RGB", mul, "A")
    MEL.connect_material_expressions(tint, "", mul, "B")
    MEL.connect_material_property(mul, "", unreal.MaterialProperty.MP_BASE_COLOR)
    for name, value, y, prop in (("Roughness", 0.7, 250, unreal.MaterialProperty.MP_ROUGHNESS),
                                 ("Specular", 0.4, 350, unreal.MaterialProperty.MP_SPECULAR)):
        p = MEL.create_material_expression(m, unreal.MaterialExpressionScalarParameter, -350, y)
        p.set_editor_property("parameter_name", name)
        p.set_editor_property("default_value", value)
        MEL.connect_material_property(p, "", prop)
    MEL.recompile_material(m)
    EAL.save_loaded_asset(m)
    return m


def build_instance(master, tex):
    mi = _load(F_MAT, INSTANCE)
    if mi is None:
        mi = _tools().create_asset(INSTANCE, F_MAT, unreal.MaterialInstanceConstant,
                                   unreal.MaterialInstanceConstantFactoryNew())
    MEL.set_material_instance_parent(mi, master)
    MEL.set_material_instance_texture_parameter_value(mi, "BaseColor", tex)
    MEL.update_material_instance(mi)
    EAL.save_loaded_asset(mi)
    return mi


def import_meshes():
    jobs = [{"fbx": os.path.join(EXPORT_DIR, "Crawler_%s_Mars_SM.fbx" % p).replace("\\", "/"),
             "name": "Crawler_%s_Mars_SM" % p, "folder": F_MESH, "sockets": []} for p in PIECES]
    return mars_prop_ue.import_props(jobs, {"search_root": "/Game/Mars", "material_pattern": "{slot}_Mars_MI"})


def mesh_report():
    out = {}
    for p in PIECES:
        mesh = _load(F_MESH, "Crawler_%s_Mars_SM" % p)
        if mesh is None:
            out[p] = None
            continue
        box = mesh.get_bounding_box()
        out[p] = {"min": [round(v, 2) for v in (box.min.x, box.min.y, box.min.z)],
                  "max": [round(v, 2) for v in (box.max.x, box.max.y, box.max.z)],
                  "materials": [m.material_interface.get_name() if m.material_interface else None
                                for m in mesh.static_materials]}
    return out


def run_all():
    if mars_prop_ue.base._in_pie():
        return {"error": "the editor is in PIE - stop it and run again"}
    for folder in (F_MESH, F_MAT):
        EAL.make_directory(folder)
    tex = import_texture()
    master = build_master(tex)
    build_instance(master, tex)
    res = import_meshes()
    res["meshes"] = mesh_report()
    return res
