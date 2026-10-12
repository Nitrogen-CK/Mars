"""Editor Python for the Service Steward (built by ../build_steward.py): imports the skeletal mesh and its idle,
the base colour texture, builds the body material, puts the materials on the mesh's two slots and reports the face
node the entity script needs.

    /Game/Mars/Gameplay/Steward/Meshes/Steward_Mars_SK        the body + the face plate (slots M_Steward, M_EyePlate)
    /Game/Mars/Gameplay/Steward/Meshes/Steward_Mars_SKEL      its skeleton (61 bones, root `root`)
    /Game/Mars/Gameplay/Steward/Meshes/Steward_Mars_PA        the importer's physics asset
    /Game/Mars/Gameplay/Steward/Anims/Steward_Idle_Mars_AS    the 6 s breathing loop
    /Game/Mars/Gameplay/Steward/Textures/Steward_BaseColor_Mars_T
    /Game/Mars/Gameplay/Steward/Materials/Steward_Mars_M      opaque lit, the texture as base colour

The M_EyePlate slot wears the generated MarsEyePlate look master (Script/ECS/Eyes/Mars_Eyes_Look_Assets.as), as
SK_Chef's eye slot does: the face plate is a black void until the Eyes feature writes the primitive's custom data.

Run in the editor (Monolith editor_query run_python, or the Python console), not during PIE:

    import sys, importlib
    sys.path.insert(0, r"D:\\Repo\\Mars\\Tools\\Blender\\mars_steward\\unreal")
    import mars_steward_ue as ms; importlib.reload(ms)
    ms.run_all()            # import_meshes, import_texture, build_material, assign_materials, face_offset

A re-run re-imports IN PLACE: the mesh keeps its skeleton, physics asset and slot materials, the idle is reused, the
material's graph is emptied and redrawn (never replaced under a live mesh). Everything is imported through the legacy
FBX importer by the Send to Unreal add-on's helper (mars_character_ue).
"""
import importlib
import json
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
_SEND = os.path.normpath(os.path.join(HERE, "..", "..", "mars_send_to_unreal", "unreal"))
for _p in (HERE, _SEND):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import mars_character_ue as mcu  # noqa: E402

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary

SOURCE_DIR = r"D:\Repo\Content\Characters\ServiceSteward"
ROOT = "/Game/Mars/Gameplay/Steward"
MESH_DIR, ANIM_DIR, TEX_DIR, MAT_DIR = ROOT + "/Meshes", ROOT + "/Anims", ROOT + "/Textures", ROOT + "/Materials"
MESH, SKELETON, PHYSICS = "Steward_Mars_SK", "Steward_Mars_SKEL", "Steward_Mars_PA"
IDLE = "Steward_Idle_Mars_AS"
TEXTURE = "Steward_BaseColor_Mars_T"
MATERIAL = "Steward_Mars_M"
EYE_LOOK = "/Game/Mars/Materials/GeneratedLooks/M_CkUsf_Look_MarsEyePlate"


def _log(msg):
    unreal.log("MarsSteward: %s" % msg)


def _path(folder, name):
    return "%s/%s.%s" % (folder, name, name)


def _load(folder, name):
    return unreal.load_object(None, _path(folder, name)) if EAL.does_asset_exist(_path(folder, name)) else None


def _sidecar():
    with open(os.path.join(SOURCE_DIR, MESH + ".json"), "r", encoding="utf-8") as f:
        return json.load(f)


def _rename(asset, folder, name):
    """Move a freshly imported asset to its Mars name; the redirector a rename leaves behind is deleted."""
    old = asset.get_path_name().split(".")[0]
    new = "%s/%s" % (folder, name)
    if old == new:
        return asset
    if not EAL.rename_asset(old, new):
        raise RuntimeError("could not rename %s to %s" % (old, new))
    if EAL.does_asset_exist(old):
        EAL.delete_asset(old)
    return unreal.load_object(None, _path(folder, name))


def import_meshes():
    """The skeletal mesh (a first import creates its skeleton and physics asset, renamed to the Mars names), then
    the idle on that skeleton."""
    importlib.reload(mcu)
    res = mcu.import_character([{"fbx": os.path.join(SOURCE_DIR, MESH + ".fbx"), "folder": MESH_DIR, "name": MESH,
                                 "kind": "skeletal", "skeleton": None}], save=False)
    if res["error"] or res["failed"] or res["skipped"]:
        raise RuntimeError("mesh import: %s" % res)
    mesh = _load(MESH_DIR, MESH)
    skeleton = _rename(mesh.skeleton, MESH_DIR, SKELETON)
    if mesh.physics_asset is not None:
        _rename(mesh.physics_asset, MESH_DIR, PHYSICS)
    res = mcu.import_character([{"fbx": os.path.join(SOURCE_DIR, IDLE + ".fbx"), "folder": ANIM_DIR, "name": IDLE,
                                 "kind": "anim", "skeleton": _path(MESH_DIR, SKELETON)}], save=False)
    if res["error"] or res["failed"] or res["skipped"]:
        raise RuntimeError("idle import: %s" % res)
    idle = _load(ANIM_DIR, IDLE)
    pose = unreal.AnimPoseExtensions.get_reference_pose(skeleton)
    _log("mesh %s bones=%d, idle %.2f s" % (mesh.get_name(), len(unreal.AnimPoseExtensions.get_bone_names(pose)),
                                           idle.get_play_length()))
    return mesh


def import_texture():
    task = unreal.AssetImportTask()
    task.filename = os.path.join(SOURCE_DIR, "Textures", "Steward_BaseColor.jpg")
    task.destination_path = TEX_DIR
    task.destination_name = TEXTURE
    task.replace_existing = True
    task.automated = True
    task.save = False
    unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
    tex = _load(TEX_DIR, TEXTURE)
    if tex is None:
        raise RuntimeError("texture did not import from %s" % task.filename)
    tex.set_editor_property("srgb", True)
    tex.set_editor_property("compression_settings", unreal.TextureCompressionSettings.TC_DEFAULT)
    tex.set_editor_property("lod_group", unreal.TextureGroup.TEXTUREGROUP_CHARACTER)
    _log("texture %s %dx%d" % (tex.get_name(), tex.blueprint_get_size_x(), tex.blueprint_get_size_y()))
    return tex


def build_material():
    """Steward_Mars_M: the base colour texture (a parameter, so a variant is an instance), roughness and specular as
    the MiniChef body's (MiniChef_Mars_M: 0.8 / 0.2)."""
    mat = _load(MAT_DIR, MATERIAL)
    if mat is None:
        mat = unreal.AssetToolsHelpers.get_asset_tools().create_asset(MATERIAL, MAT_DIR, unreal.Material,
                                                                      unreal.MaterialFactoryNew())
    MEL.delete_all_material_expressions(mat)
    mat.set_editor_property("used_with_skeletal_mesh", True)
    tex = MEL.create_material_expression(mat, unreal.MaterialExpressionTextureSampleParameter2D, -500, 0)
    tex.set_editor_property("parameter_name", "BaseColor")
    tex.set_editor_property("texture", _load(TEX_DIR, TEXTURE))
    MEL.connect_material_property(tex, "RGB", unreal.MaterialProperty.MP_BASE_COLOR)
    rough = MEL.create_material_expression(mat, unreal.MaterialExpressionScalarParameter, -500, 300)
    rough.set_editor_property("parameter_name", "Roughness")
    rough.set_editor_property("default_value", 0.8)
    MEL.connect_material_property(rough, "", unreal.MaterialProperty.MP_ROUGHNESS)
    spec = MEL.create_material_expression(mat, unreal.MaterialExpressionScalarParameter, -500, 420)
    spec.set_editor_property("parameter_name", "Specular")
    spec.set_editor_property("default_value", 0.2)
    MEL.connect_material_property(spec, "", unreal.MaterialProperty.MP_SPECULAR)
    MEL.recompile_material(mat)
    _log("material %s" % mat.get_name())
    return mat


def assign_materials():
    side = _sidecar()
    mesh = _load(MESH_DIR, MESH)
    want = {side["body_slot"]: _load(MAT_DIR, MATERIAL), side["eyes_slot"]: unreal.load_asset(EYE_LOOK)}
    if want[side["eyes_slot"]] is None:
        unreal.log_warning("MarsSteward: %s is not generated (Ck_Usf_GenerateLooks MarsEyePlate): the eye slot keeps "
                           "its placeholder" % EYE_LOOK)
    mats = list(mesh.materials)
    names = [str(m.material_slot_name) for m in mats]
    for slot in want:
        if slot not in names:
            raise RuntimeError("%s has no [%s] slot (it has %s) - re-export from build_steward.py" % (MESH, slot, names))
    for i, m in enumerate(mats):
        mat = want.get(str(m.material_slot_name))
        if mat is not None:
            mats[i] = unreal.SkeletalMaterial(material_interface=mat, material_slot_name=m.material_slot_name)
    mesh.set_editor_property("materials", mats)
    _log("slots %s" % [(str(m.material_slot_name), m.material_interface.get_name() if m.material_interface else None)
                       for m in mesh.materials])
    return mesh


def face_offset():
    """The face node relative to the eyes' bone, as FMars_Steward_Face::Offset wants it: +X out of the face, +Y the
    steward's right, +Z up, on the plate's keel level with the eyes. In component space the steward faces +Y with its
    left on +X, so the node is yawed 90 there. Returns (rotator, location) and logs the AngelScript literal."""
    side = _sidecar()
    mesh = _load(MESH_DIR, MESH)
    pose = unreal.AnimPoseExtensions.get_reference_pose(mesh.skeleton)
    head = unreal.AnimPoseExtensions.get_bone_pose(pose, side["eyes_bone"], unreal.AnimPoseSpaces.WORLD)
    node = unreal.Transform(location=unreal.Vector(*side["face_node_unreal"]), rotation=unreal.Rotator(roll=0.0, pitch=0.0, yaw=90.0))
    rel = node.make_relative(head)
    rot, loc = rel.rotation.rotator(), rel.translation
    _log("head bone in component space: loc=(%.3f, %.3f, %.3f) rot(p,y,r)=(%.3f, %.3f, %.3f)" % (
        head.translation.x, head.translation.y, head.translation.z,
        head.rotation.rotator().pitch, head.rotation.rotator().yaw, head.rotation.rotator().roll))
    _log("Face.Offset = FTransform(FRotator(%.3f, %.3f, %.3f), FVector(%.3f, %.3f, %.3f), FVector::OneVector)  "
         "// FRotator(Pitch, Yaw, Roll)" % (rot.pitch, rot.yaw, rot.roll, loc.x, loc.y, loc.z))
    return rot, loc


def save():
    for folder, name in ((MESH_DIR, MESH), (MESH_DIR, SKELETON), (MESH_DIR, PHYSICS), (ANIM_DIR, IDLE),
                         (TEX_DIR, TEXTURE), (MAT_DIR, MATERIAL)):
        asset = _load(folder, name)
        if asset is not None:
            EAL.save_loaded_asset(asset)


def run_all():
    if mcu._in_pie():
        raise RuntimeError("the editor is in PIE - stop it and run again")
    import_meshes()
    import_texture()
    build_material()
    assign_materials()
    save()
    return face_offset()
