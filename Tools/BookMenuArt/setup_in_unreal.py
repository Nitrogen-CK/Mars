"""Wire the worn book into Mars: stain textures, stained copies of the BookMenu master materials, instances, slots.

Unreal EDITOR Python (live editor: Tools > Execute Python Script, or Monolith editor.run_python). Idempotent.
Expects SK_Book_Worn already imported into /Game/Mars/Gameplay/PlayerCookbook on Anim_Book_Skeleton.

- Imports Textures/T_BookWorn_*.png as PlayerCookbook_*Stain*_Mars_T.
- Duplicates /BookMenu M_Pages_Master and M_Cover_Master into PlayerCookbook_{Pages,Cover}_Mars_M and appends one stain
  layer after their final MaterialAttributes: the plugin's own MF_Add_Dirt fed with the stain texture sampled on UV3
  (StainUV): BaseColor = lerp(base, stain RGB, stain A * Stain Intensity), Roughness += (Stain Roughness + Grease
  Roughness * mask G) * the same mask. Every original parameter (incl. "BC", which the BookMenu anim instance overrides
  with each page's widget render target) is unchanged.
- Duplicates the plugin's MIs onto those masters (PageB/C/D keep inheriting from PageA, like the plugin) and assigns them
  to SK_Book_Worn's slots exactly as SK_Book_01 does (PageFirst = PageA's MI, PageLast = PageB's MI).
Plugin content is never modified.
"""

import os

import unreal

DEST = "/Game/Mars/Gameplay/PlayerCookbook"
MESH = f"{DEST}/SK_Book_Worn"
TEX_DIR = f"{DEST}/Textures"
MAT_DIR = f"{DEST}/Materials"
PNG_DIR = os.path.join(unreal.Paths.convert_relative_path_to_full(unreal.Paths.project_dir()), "Tools", "BookMenuArt", "Textures")
STAIN_FUNCTION = "/BookMenu/Materials/Functions/MF_Add_Dirt"
TAG = "PlayerCookbook stain overlay (StainUV = UV3)"
UV_STAIN = 3

TEXTURES = {
    "PlayerCookbook_PagesStain_Mars_T": ("T_BookWorn_Pages_Stain_BC.png", True),
    "PlayerCookbook_PagesStainMask_Mars_T": ("T_BookWorn_Pages_StainMask.png", False),
    "PlayerCookbook_CoverStain_Mars_T": ("T_BookWorn_Cover_Stain_BC.png", True),
    "PlayerCookbook_CoverStainMask_Mars_T": ("T_BookWorn_Cover_StainMask.png", False),
}
MASTERS = {
    "Pages": ("/BookMenu/Materials/Master/M_Pages_Master", "PlayerCookbook_Pages_Mars_M",
              "PlayerCookbook_PagesStain_Mars_T", "PlayerCookbook_PagesStainMask_Mars_T"),
    "Cover": ("/BookMenu/Materials/Master/M_Cover_Master", "PlayerCookbook_Cover_Mars_M",
              "PlayerCookbook_CoverStain_Mars_T", "PlayerCookbook_CoverStainMask_Mars_T"),
}
# (new instance, plugin source instance, parent: master key or another new instance)
INSTANCES = [
    ("PlayerCookbook_Cover_Mars_MI", "/BookMenu/Materials/MI_Cover_01", "Cover"),
    ("PlayerCookbook_PagesBase_Mars_MI", "/BookMenu/Materials/MI_Pages_Side_01", "Pages"),
    ("PlayerCookbook_PageA_Mars_MI", "/BookMenu/Materials/MI_PageA", "Pages"),
    ("PlayerCookbook_PageB_Mars_MI", "/BookMenu/Materials/MI_PageB", "PlayerCookbook_PageA_Mars_MI"),
    ("PlayerCookbook_PageC_Mars_MI", "/BookMenu/Materials/MI_PageC", "PlayerCookbook_PageA_Mars_MI"),
    ("PlayerCookbook_PageD_Mars_MI", "/BookMenu/Materials/MI_PageD", "PlayerCookbook_PageA_Mars_MI"),
]
SLOTS = {
    "Cover": "PlayerCookbook_Cover_Mars_MI", "PagesBase": "PlayerCookbook_PagesBase_Mars_MI",
    "PageA": "PlayerCookbook_PageA_Mars_MI", "PageB": "PlayerCookbook_PageB_Mars_MI",
    "PageC": "PlayerCookbook_PageC_Mars_MI", "PageD": "PlayerCookbook_PageD_Mars_MI",
    "PageFirst": "PlayerCookbook_PageA_Mars_MI", "PageLast": "PlayerCookbook_PageB_Mars_MI",
}

mel = unreal.MaterialEditingLibrary
eal = unreal.EditorAssetLibrary
to_save = []


def require(obj, what):
    if obj is None:
        raise RuntimeError(f"PlayerCookbook setup: {what} not found")
    return obj


def import_textures():
    tools = unreal.AssetToolsHelpers.get_asset_tools()
    for name, (png, srgb) in TEXTURES.items():
        path = os.path.join(PNG_DIR, png)
        if not os.path.isfile(path):
            raise RuntimeError(f"Missing {path}; run blender_stains.py first")
        task = unreal.AssetImportTask()
        task.set_editor_property("filename", path)
        task.set_editor_property("destination_path", TEX_DIR)
        task.set_editor_property("destination_name", name)
        task.set_editor_property("automated", True)
        task.set_editor_property("replace_existing", True)
        task.set_editor_property("save", False)
        tools.import_asset_tasks([task])
        tex = require(unreal.load_asset(f"{TEX_DIR}/{name}"), name)
        tex.set_editor_property("srgb", srgb)
        tex.set_editor_property("compression_settings", unreal.TextureCompressionSettings.TC_DEFAULT)
        tex.set_editor_property("compression_no_alpha", False)
        to_save.append(tex)


def connect(src, src_out, dst, dst_in):
    """Function-call pins are named with a type suffix ("Mask (S)"); try the bare name first."""
    for name in (dst_in, f"{dst_in} (S)", f"{dst_in} (V3)", f"{dst_in} (MA)"):
        if mel.connect_material_expressions(src, src_out, dst, name):
            return
    raise RuntimeError(f"Could not connect {src.get_name()}.{src_out} -> {dst.get_name()}.{dst_in}")


def param(mat, cls, name, x, y):
    node = mel.create_material_expression(mat, cls, x, y)
    node.set_editor_property("parameter_name", name)
    node.set_editor_property("group", "Stains")
    return node


def stain_samplers(mat, call):
    """The stain layer's two texture parameters, found by walking up from its function call. Unconnected inputs come
    back as None; never pass one back into get_inputs_for_material_expression (it dereferences null and takes the
    editor down)."""
    found, frontier = [], [call]
    for _ in range(3):
        upstream = []
        for node in frontier:
            for src in mel.get_inputs_for_material_expression(mat, node):
                if src is None:
                    continue
                if (isinstance(src, unreal.MaterialExpressionTextureSampleParameter2D)
                        and str(src.get_editor_property("parameter_name")) in ("Stain BC", "Stain Mask")):
                    if src not in found:
                        found.append(src)
                else:
                    upstream.append(src)
        frontier = upstream
    return found


def share_samplers(mat, nodes):
    """The cover master already uses 14 samplers; shared samplers keep the stain layer off the 16-sampler limit."""
    changed = False
    for node in nodes:
        if node.get_editor_property("sampler_source") != unreal.SamplerSourceMode.SSM_WRAP_WORLD_GROUP_SETTINGS:
            node.set_editor_property("sampler_source", unreal.SamplerSourceMode.SSM_WRAP_WORLD_GROUP_SETTINGS)
            changed = True
    return changed


def stained_master(key):
    src, name, bc_name, mask_name = MASTERS[key]
    path = f"{MAT_DIR}/{name}"
    mat = unreal.load_asset(path) if eal.does_asset_exist(path) else eal.duplicate_asset(src, path)
    require(mat, path)
    out = require(mel.get_material_property_input_node(mat, unreal.MaterialProperty.MP_MATERIAL_ATTRIBUTES),
                  f"{name} MaterialAttributes output")
    if isinstance(out, unreal.MaterialExpressionMaterialFunctionCall) and out.get_editor_property("desc") == TAG:
        samplers = stain_samplers(mat, out)
        if len(samplers) != 2:
            raise RuntimeError(f"{name}: expected the Stain BC / Stain Mask samplers, found {len(samplers)}")
        if share_samplers(mat, samplers):
            mel.recompile_material(mat)
            to_save.append(mat)
        print(f"PlayerCookbook: {name} already has the stain layer")
        return mat

    x = out.get_editor_property("material_expression_editor_x") + 400
    y = out.get_editor_property("material_expression_editor_y")
    uv = mel.create_material_expression(mat, unreal.MaterialExpressionTextureCoordinate, x, y + 400)
    uv.set_editor_property("coordinate_index", UV_STAIN)

    bc = param(mat, unreal.MaterialExpressionTextureSampleParameter2D, "Stain BC", x + 250, y + 250)
    bc.set_editor_property("texture", unreal.load_asset(f"{TEX_DIR}/{bc_name}"))
    bc.set_editor_property("sampler_type", unreal.MaterialSamplerType.SAMPLERTYPE_COLOR)
    mask = param(mat, unreal.MaterialExpressionTextureSampleParameter2D, "Stain Mask", x + 250, y + 550)
    mask.set_editor_property("texture", unreal.load_asset(f"{TEX_DIR}/{mask_name}"))
    mask.set_editor_property("sampler_type", unreal.MaterialSamplerType.SAMPLERTYPE_LINEAR_COLOR)
    share_samplers(mat, (bc, mask))
    for node in (bc, mask):
        mel.connect_material_expressions(uv, "", node, "UVs")

    intensity = param(mat, unreal.MaterialExpressionScalarParameter, "Stain Intensity", x + 250, y - 150)
    intensity.set_editor_property("default_value", 1.0)
    rough = param(mat, unreal.MaterialExpressionScalarParameter, "Stain Roughness", x + 250, y - 50)
    rough.set_editor_property("default_value", 0.1)
    grease = param(mat, unreal.MaterialExpressionScalarParameter, "Grease Roughness", x + 250, y + 50)
    grease.set_editor_property("default_value", -0.45)
    mul = mel.create_material_expression(mat, unreal.MaterialExpressionMultiply, x + 550, y + 50)
    mel.connect_material_expressions(grease, "", mul, "A")
    mel.connect_material_expressions(mask, "G", mul, "B")
    add = mel.create_material_expression(mat, unreal.MaterialExpressionAdd, x + 700, y)
    mel.connect_material_expressions(rough, "", add, "A")
    mel.connect_material_expressions(mul, "", add, "B")
    zero = mel.create_material_expression(mat, unreal.MaterialExpressionConstant, x + 700, y + 150)

    call = mel.create_material_expression(mat, unreal.MaterialExpressionMaterialFunctionCall, x + 950, y)
    call.set_editor_property("material_function", require(unreal.load_asset(STAIN_FUNCTION), STAIN_FUNCTION))
    call.set_editor_property("desc", TAG)
    connect(out, "", call, "Base_Material")
    connect(bc, "RGB", call, "Dirt_Color")
    connect(bc, "A", call, "Mask")
    connect(intensity, "", call, "Intensity")
    connect(add, "", call, "Roughness")
    connect(zero, "", call, "Metallic_Reduction")
    if not mel.connect_material_property(call, "Result", unreal.MaterialProperty.MP_MATERIAL_ATTRIBUTES):
        raise RuntimeError(f"Could not connect the stain layer to {name}'s output")
    mel.recompile_material(mat)
    to_save.append(mat)
    print(f"PlayerCookbook: stain layer added to {name}")
    return mat


def instances(masters):
    made = {}
    for name, src, parent_key in INSTANCES:
        path = f"{MAT_DIR}/{name}"
        mi = unreal.load_asset(path) if eal.does_asset_exist(path) else eal.duplicate_asset(src, path)
        require(mi, path)
        parent = masters[parent_key] if parent_key in masters else made[parent_key]
        mel.set_material_instance_parent(mi, parent)
        mel.update_material_instance(mi)
        made[name] = mi
        to_save.append(mi)
    return made


def assign(made):
    mesh = require(unreal.load_asset(MESH), MESH)
    if mesh.get_editor_property("skeleton").get_path_name() != "/BookMenu/Meshes/Anim_Book_Skeleton.Anim_Book_Skeleton":
        raise RuntimeError(f"{MESH} is not on Anim_Book_Skeleton")
    # Array properties come back as copies of their structs: edit the copies, then set the whole array.
    materials = []
    for slot in mesh.get_editor_property("materials"):
        slot.set_editor_property("material_interface", made[SLOTS[str(slot.get_editor_property("material_slot_name"))]])
        materials.append(slot)
    mesh.set_editor_property("materials", materials)
    if mesh.get_editor_property("physics_asset") is None:
        mesh.set_editor_property("physics_asset", unreal.load_asset("/BookMenu/Meshes/PA_Book_01"))
    to_save.append(mesh)
    print("PlayerCookbook: slots " + ", ".join(
        f"{s.get_editor_property('material_slot_name')}={s.get_editor_property('material_interface').get_name()}"
        for s in mesh.get_editor_property("materials")))


def main():
    import_textures()
    masters = {key: stained_master(key) for key in MASTERS}
    made = instances(masters)
    assign(made)
    for asset in to_save:
        if not eal.save_loaded_asset(asset, False):
            raise RuntimeError(f"Saving {asset.get_path_name()} failed")
    print(f"PlayerCookbook setup ok: saved {len(to_save)} assets")


main()
