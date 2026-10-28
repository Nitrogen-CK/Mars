"""Export the BookMenu plugin's skeletal mesh, its animation sequences and the textures its materials use.

Unreal EDITOR Python. Runs headless with the editor closed:

    Binaries/Win64/MarsEditor-Cmd.exe Mars.uproject -run=pythonscript -script="<this file>"
        -unattended -nosplash -nullrhi -CkAsDeclineRegenOwnership

Writes to Tools/BookMenuArt/Export/:
    SK_Book_01.fbx                 skeletal mesh (LOD0) + skeleton
    Anims/<AnimSequence>.fbx       one FBX per sequence (skeleton + curves, no mesh)
    Textures/<Texture>.png|.tga    every texture the book's material instances reference
    export_report.json             slots, bounds, anim lengths, material parameters
"""

import json
import os

import unreal

SOURCE_ROOT = "/BookMenu"
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Export")

MESH_PATH = "/BookMenu/Meshes/SK_Book_01"
MATERIAL_INSTANCES = [
    "/BookMenu/Materials/MI_Cover_01",
    "/BookMenu/Materials/MI_PageA",
    "/BookMenu/Materials/MI_PageB",
    "/BookMenu/Materials/MI_PageC",
    "/BookMenu/Materials/MI_PageD",
    "/BookMenu/Materials/MI_Pages_Side_01",
]
EXTRA_TEXTURES = [
    "/BookMenu/Textures/UV_Layouts/T_Book_01_Cover_UV2_Layout_2k",
    "/BookMenu/Textures/UV_Layouts/T_Book_01_Pages_UV0_Layout_2k",
    "/BookMenu/Textures/UV_Layouts/T_Book_01_Pages_UV2_Layout_2k",
    "/BookMenu/Textures/Masks/T_Book_01_Cover_M_2k",
    "/BookMenu/Textures/Masks/T_Book_01_Pages_M_2k",
    "/BookMenu/Textures/ID_Maps/T_Book_01_Cover_ID_2k",
]


def fbx_options(export_preview_mesh):
    options = unreal.FbxExportOption()
    options.set_editor_property("fbx_export_compatibility", unreal.FbxExportCompatibility.FBX_2020)
    options.set_editor_property("ascii", False)
    options.set_editor_property("force_front_x_axis", False)
    options.set_editor_property("vertex_color", True)
    options.set_editor_property("level_of_detail", False)
    options.set_editor_property("collision", False)
    options.set_editor_property("export_morph_targets", True)
    options.set_editor_property("export_preview_mesh", export_preview_mesh)
    options.set_editor_property("map_skeletal_motion_to_root", False)
    options.set_editor_property("export_local_time", True)
    # Material baking CPU-skins the mesh through a render-backed component and asserts under -nullrhi.
    options.set_editor_property("bake_material_inputs", unreal.FbxMaterialBakeMode.DISABLED)
    return options


def run_export(obj, filename, options=None):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    task = unreal.AssetExportTask()
    task.set_editor_property("object", obj)
    task.set_editor_property("filename", filename)
    task.set_editor_property("automated", True)
    task.set_editor_property("prompt", False)
    task.set_editor_property("replace_identical", True)
    if options is not None:
        task.set_editor_property("options", options)
    ok = unreal.Exporter.run_asset_export_task(task)
    errors = [str(e) for e in task.get_editor_property("errors")]
    ok = ok and os.path.isfile(filename)
    return ok, errors


def export_texture(texture, report):
    name = texture.get_name()
    for ext in (".png", ".tga"):
        filename = os.path.join(OUT_DIR, "Textures", name + ext)
        ok, errors = run_export(texture, filename)
        if ok:
            report["textures"][name] = {"file": filename, "size": [texture.blueprint_get_size_x(), texture.blueprint_get_size_y()],
                                         "srgb": bool(texture.get_editor_property("srgb"))}
            return
    report["errors"].append(f"texture {name}: {errors}")


def describe_material(mi):
    lib = unreal.MaterialEditingLibrary
    info = {"parent": str(mi.get_editor_property("parent").get_path_name()), "textures": {}, "scalars": {}, "vectors": {}}
    for name in lib.get_texture_parameter_names(mi):
        tex = lib.get_material_instance_texture_parameter_value(mi, name)
        info["textures"][str(name)] = tex.get_path_name() if tex else None
    for name in lib.get_scalar_parameter_names(mi):
        info["scalars"][str(name)] = lib.get_material_instance_scalar_parameter_value(mi, name)
    for name in lib.get_vector_parameter_names(mi):
        c = lib.get_material_instance_vector_parameter_value(mi, name)
        info["vectors"][str(name)] = [c.r, c.g, c.b, c.a]
    return info


def main():
    registry = unreal.AssetRegistryHelpers.get_asset_registry()
    registry.scan_paths_synchronous([SOURCE_ROOT], True)

    report = {"mesh": {}, "anims": {}, "materials": {}, "textures": {}, "errors": []}

    mesh = unreal.load_asset(MESH_PATH)
    if not isinstance(mesh, unreal.SkeletalMesh):
        raise RuntimeError(f"{MESH_PATH} did not load as a SkeletalMesh (got {mesh})")

    ok, errors = run_export(mesh, os.path.join(OUT_DIR, "SK_Book_01.fbx"), fbx_options(export_preview_mesh=False))
    bounds = mesh.get_bounds()
    report["mesh"] = {
        "ok": ok,
        "errors": errors,
        "skeleton": mesh.get_editor_property("skeleton").get_path_name(),
        "bounds_origin": [bounds.origin.x, bounds.origin.y, bounds.origin.z],
        "bounds_extent": [bounds.box_extent.x, bounds.box_extent.y, bounds.box_extent.z],
        "materials": [
            {"slot": str(m.get_editor_property("material_slot_name")),
             "material": m.get_editor_property("material_interface").get_path_name() if m.get_editor_property("material_interface") else None}
            for m in mesh.get_editor_property("materials")
        ],
    }

    anim_filter = unreal.ARFilter(package_paths=[SOURCE_ROOT], recursive_paths=True,
                                  class_paths=[unreal.TopLevelAssetPath("/Script/Engine", "AnimSequence")])
    for data in registry.get_assets(anim_filter):
        anim = data.get_asset()
        name = anim.get_name()
        ok, errors = run_export(anim, os.path.join(OUT_DIR, "Anims", name + ".fbx"), fbx_options(export_preview_mesh=False))
        entry = {"ok": ok, "errors": errors, "path": anim.get_path_name(), "play_length": anim.get_play_length()}
        try:
            entry["num_frames"] = unreal.AnimationLibrary.get_num_frames(anim)
            rate = unreal.AnimationLibrary.get_frame_rate(anim)
            entry["frame_rate"] = [rate.numerator, rate.denominator]
        except Exception as e:  # frame-rate API shape differs across engine versions; length is enough
            entry["frame_info_error"] = str(e)
        # Morph-target curves (PageBend_*) ride in the FBX as static custom props only; Blender's importer drops their
        # keys, so they are carried here and rebuilt as drivers on the Blender side.
        entry["curves"] = {}
        for curve in unreal.AnimationLibrary.get_animation_curve_names(anim, unreal.RawCurveTrackTypes.RCT_FLOAT):
            times, values = unreal.AnimationLibrary.get_float_keys(anim, curve)
            entry["curves"][str(curve)] = {"times": list(times), "values": list(values)}
        report["anims"][name] = entry

    texture_paths = set(EXTRA_TEXTURES)
    for path in MATERIAL_INSTANCES:
        mi = unreal.load_asset(path)
        if mi is None:
            report["errors"].append(f"material {path} failed to load")
            continue
        info = describe_material(mi)
        report["materials"][path] = info
        texture_paths.update(p.split(".")[0] for p in info["textures"].values() if p and p.startswith(SOURCE_ROOT))

    for path in sorted(texture_paths):
        texture = unreal.load_asset(path)
        if isinstance(texture, unreal.Texture2D):
            export_texture(texture, report)
        else:
            report["errors"].append(f"texture {path} did not load as Texture2D")

    with open(os.path.join(OUT_DIR, "export_report.json"), "w") as f:
        json.dump(report, f, indent=2, default=str)

    print(f"BookMenuExport: mesh_ok={report['mesh']['ok']} anims={sum(a['ok'] for a in report['anims'].values())}/{len(report['anims'])} "
          f"textures={len(report['textures'])} errors={len(report['errors'])}")


main()
