"""Import Eyes_Atlas_Mars_T.png into the project as the eye-plate look's atlas texture.

Unreal EDITOR Python only (Tools > Execute Python Script, or `py <path>` in the editor console). Stop PIE first.

The PNG stores a distance field, not a picture, so the texture must read back exactly what was written:
linear (no sRGB), single-channel grayscale, no mips (the look samples mip 0 only) and clamped addressing (the
look clamps inside each cell itself; wrapping would bleed the opposite edge of the atlas into the border cells).
"""

import os

import unreal

DESTINATION_PATH = "/Game/Mars/Gameplay/PlayerCharacter/Eyes"
ASSET_NAME = "Eyes_Atlas_Mars_T"
OBJECT_PATH = f"{DESTINATION_PATH}/{ASSET_NAME}.{ASSET_NAME}"
SOURCE_PNG = os.path.join(os.path.dirname(os.path.abspath(__file__)), f"{ASSET_NAME}.png")


def import_atlas():
    if not os.path.isfile(SOURCE_PNG):
        raise RuntimeError(f"Eye atlas PNG not found at [{SOURCE_PNG}]; run make_eye_atlas.py first")

    task = unreal.AssetImportTask()
    task.set_editor_property("filename", SOURCE_PNG)
    task.set_editor_property("destination_path", DESTINATION_PATH)
    task.set_editor_property("destination_name", ASSET_NAME)
    task.set_editor_property("automated", True)
    task.set_editor_property("replace_existing", True)
    task.set_editor_property("save", False)
    task.set_editor_property("async_", False)
    unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])

    # does_asset_exist lags behind a replace in this project; resolve the object directly instead.
    texture = unreal.load_object(None, OBJECT_PATH)
    if not isinstance(texture, unreal.Texture2D):
        raise RuntimeError(f"Import of [{SOURCE_PNG}] did not produce a Texture2D at [{OBJECT_PATH}] (got {texture})")

    texture.set_editor_property("srgb", False)
    texture.set_editor_property("compression_settings", unreal.TextureCompressionSettings.TC_GRAYSCALE)
    texture.set_editor_property("mip_gen_settings", unreal.TextureMipGenSettings.TMGS_NO_MIPMAPS)
    texture.set_editor_property("address_x", unreal.TextureAddress.TA_CLAMP)
    texture.set_editor_property("address_y", unreal.TextureAddress.TA_CLAMP)
    texture.set_editor_property("lod_group", unreal.TextureGroup.TEXTUREGROUP_WORLD)

    if not unreal.EditorAssetLibrary.save_loaded_asset(texture, False):
        raise RuntimeError(f"Saving [{OBJECT_PATH}] failed")

    print(
        f"Eye atlas imported: {OBJECT_PATH} "
        f"size={texture.blueprint_get_size_x()}x{texture.blueprint_get_size_y()} "
        f"srgb={texture.get_editor_property('srgb')} "
        f"compression={texture.get_editor_property('compression_settings')} "
        f"mips={texture.get_editor_property('mip_gen_settings')} "
        f"address=({texture.get_editor_property('address_x')}, {texture.get_editor_property('address_y')}) "
        f"lod_group={texture.get_editor_property('lod_group')}"
    )


import_atlas()
