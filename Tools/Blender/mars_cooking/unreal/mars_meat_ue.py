"""Editor side of cuttable meat on the steak cube's master: MeatSlab_Wagyu_Mars_MI, a child of Meat_Mars_M for the bench
slab (MeatSlab_Mars_SM and its runtime cut pieces), MeatSlab_WagyuCap_Mars_MI (a child of it for the runtime cut cap
slot), plus the four textures they sample. Run in the editor's
Python (Monolith `editor_query run_python`, `unattended: true`), never during PIE:

    import sys, importlib
    sys.path.insert(0, r"D:\\Repo\\Mars\\Tools\\Blender\\mars_cooking\\unreal")
    import mars_meat_ue as mm; importlib.reload(mm)
    mm.run_all()            # = import_textures() + build_meat_instances()
    mm.report()             # dry run: what would be imported / set, touches nothing

Why Meat_Mars_M: Food_Mars_M multiplies the crust tints into the painted vertex colour, and a saturated red multiplied
by anything stays red, so the slab never browned (review\\parity\\CookParity_*_sheet.png). Meat_Mars_M colours by its sear
ramps (SearRamp_WagyuLean / WagyuFat rows of SearRamps_Mars_CurveAtlas) driven by the cook-state Custom Primitive Data
every cooking mesh shares (0-3 Sear XY, 4-7 Sear Z + Penetration + Oil Coat, 8-9 Glaze / Shape); it ignores vertex
colour and reads where the fat is from its Mask texture (R). The masters are not touched here.

Textures (Food/Textures, from food_spec.EXPORT_DIR, written by ../build_meatslab_marbling.py in the slab's UV0 space):
    MeatSlab_Marbling_Mars_T          TC_Masks, linear: R fat, G fibre + mottle, B crust break-up, A convex rims
    MeatSlab_Marbling_Normal_Mars_T   TC_Normalmap, DirectX green (no flip), like MeatCube_Wagyu_Normal_Mars_T
    MeatSlab_CapMarbling_Mars_T       the cap's tileable lean cross-section, 37 cm per UV unit (TC_Masks)
    MeatSlab_CapMarbling_Normal_Mars_T its normal

Why a cap instance: the bench's cut cap gets a planar UV0 about the knife's contact point (Food def Cap.CmPerUVUnit /
UVOffset), so on the slab's atlas it would read arbitrary texels, the fat cap's island included (a fresh lean cut showing
a pale slab). MeatSlab_WagyuCap_Mars_MI only swaps Mask / Normal for the tileable cross-section; every sear, band and
surface value comes from MeatSlab_Wagyu_Mars_MI, so cap and exterior cook alike. Food def: slots 0 / 1 =
MeatSlab_Wagyu_Mars_MI, the cap slot = MeatSlab_WagyuCap_Mars_MI, Cap.CmPerUVUnit = CAP_CM_PER_UV.

Instance values: the look values start as the cube's (mars_cooking_ue.INSTANCES "Meat_Wagyu_Mars_MI", read at build time)
and are CREATE-ONLY (an artist's later tweak survives a rebuild; reset_looks=True re-applies them). Always set:
the textures, Shape Scale 0 (the slab has no UV1 / UV2 morph; a mesh without them hands the material its last UV set
instead, so Shape would push the slab around by its UV0) and Debug Use Sliders 0.
"""
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
for _p in (HERE, os.path.dirname(HERE)):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import food_spec as fs  # noqa: E402
import mars_cooking_ue as mc  # noqa: E402  (imported, never reloaded or edited here: another session owns it)

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary

F_TEX = fs.UE_FOLDER + "/Textures"
F_INST = fs.UE_FOLDER + "/Materials/Instances"
MEAT_MASTER = "/Game/Mars/Gameplay/Cooking/Materials/Meat_Mars_M.Meat_Mars_M"
CUBE_INSTANCE = "Meat_Wagyu_Mars_MI"

# (asset name, file in food_spec.EXPORT_DIR, kind)
TEXTURES = (
    ("MeatSlab_Marbling_Mars_T", "MeatSlab_Marbling_Mars_T.png", "masks"),
    ("MeatSlab_Marbling_Normal_Mars_T", "MeatSlab_Marbling_Normal_Mars_T.png", "normal"),
    ("MeatSlab_CapMarbling_Mars_T", "MeatSlab_CapMarbling_Mars_T.png", "masks"),
    ("MeatSlab_CapMarbling_Normal_Mars_T", "MeatSlab_CapMarbling_Normal_Mars_T.png", "normal"),
)
CAP_CM_PER_UV = 37.0                               # build_meatslab_marbling --cap_cm: the Food def's Cap.CmPerUVUnit

SLAB_NOTE = ("Cuttable meat on Meat_Mars_M (the steak cube's master): sear colour from the Lean / Fat ramps, fat from "
             "MeatSlab_Marbling_Mars_T R (build_meatslab_marbling.py, the slab's UV0). Shape Scale 0: the slab has no "
             "morph UVs. Built by mars_meat_ue.build_meat_instances; look values are create-only.")

CAP_NOTE = ("The runtime cut cap of MeatSlab_Wagyu_Mars_MI: only Mask / Normal differ (MeatSlab_CapMarbling_*, a tileable "
            "lean cross-section at %g cm per UV unit = the Food def's Cap.CmPerUVUnit). Tune the cook look on the parent."
            % CAP_CM_PER_UV)

INSTANCES = (
    {"name": "MeatSlab_Wagyu_Mars_MI",
     "parent": MEAT_MASTER,
     "textures": {"Mask": "MeatSlab_Marbling_Mars_T", "Normal": "MeatSlab_Marbling_Normal_Mars_T"},
     "scalars": {"Shape Scale": 0.0, "Debug Use Sliders": 0.0},
     "create_from": CUBE_INSTANCE,                 # start from the cube's listed look values (per cm, so they carry over)
     "create_scalars": {},                         # slab-specific look deltas over the cube's, none yet
     "description": SLAB_NOTE},
    {"name": "MeatSlab_WagyuCap_Mars_MI",
     "parent": "MeatSlab_Wagyu_Mars_MI",           # an INSTANCES name built before it, or an object path
     "textures": {"Mask": "MeatSlab_CapMarbling_Mars_T", "Normal": "MeatSlab_CapMarbling_Normal_Mars_T"},
     "scalars": {},
     "create_from": None,
     "create_scalars": {},
     "description": CAP_NOTE},
)


def _log(msg):
    unreal.log("MarsMeat: %s" % msg)


def _warn(msg):
    unreal.log_warning("MarsMeat: %s" % msg)


def _cube_scalars(name):
    for inst_name, _, _, scalars, _ in mc.INSTANCES:
        if inst_name == name:
            return dict(scalars)
    _warn("%s not in mars_cooking_ue.INSTANCES, the instance starts from the master defaults" % name)
    return {}


def create_scalars(spec):
    """The create-only look values of one INSTANCES entry: the cube's, then the slab's own deltas."""
    values = _cube_scalars(spec["create_from"]) if spec.get("create_from") else {}
    values.update(spec["create_scalars"])
    return values


# ------------------------------------------------------------------ textures
def _configure(tex, kind):
    tcs = unreal.TextureCompressionSettings
    if kind == "masks":
        tex.set_editor_property("compression_settings", tcs.TC_MASKS)
        tex.set_editor_property("srgb", False)
    elif kind == "normal":
        tex.set_editor_property("compression_settings", tcs.TC_NORMALMAP)
        tex.set_editor_property("srgb", False)
        tex.set_editor_property("flip_green_channel", False)      # generated DirectX style (green down), as the cube's


def import_textures(export_dir=None, folder=F_TEX, save=True):
    """Imports TEXTURES into folder (save=False keeps them in memory, for a transient parity run)."""
    if mc._in_pie():
        raise RuntimeError("stop PIE before importing (assets imported during PIE vanish)")
    src = export_dir or fs.EXPORT_DIR
    jobs = [(n, os.path.join(src, f), k) for n, f, k in TEXTURES]
    missing = [p for _, p, _ in jobs if not os.path.isfile(p)]
    if missing:
        raise RuntimeError("run build_meatslab_marbling.py first, missing: %s" % ", ".join(missing))
    mc._tools().import_asset_tasks([mc._task(p, folder, n) for n, p, _ in jobs])
    done = {}
    for name, path, kind in jobs:
        tex = mc._asset(folder, name)
        if tex is None:
            _warn("texture %s did not import (%s)" % (name, path))
            continue
        _configure(tex, kind)
        if save:
            EAL.save_loaded_asset(tex)
        done[name] = tex
    _log("%d of %d textures imported into %s%s" % (len(done), len(jobs), folder, "" if save else " (unsaved)"))
    return done


def _texture(name, tex_folders):
    for folder in tex_folders:
        tex = mc._asset(folder, name)
        if tex is not None:
            return tex
    return None


# ------------------------------------------------------------------ instances
def build_meat_instances(reset_looks=False, folder=F_INST, tex_folders=(F_TEX,), save=True, only=None):
    """Creates / updates INSTANCES in folder. Look values are create-only unless reset_looks; textures, Shape Scale
    and Debug Use Sliders are set every time. save=False leaves everything in memory (transient parity runs).
    Returns {name: instance}."""
    if mc._in_pie():
        raise RuntimeError("stop PIE before building the meat instances")
    made = {}
    for spec in INSTANCES:
        if only and spec["name"] not in only:
            continue
        ref = spec["parent"]
        parent = mc._load(ref) if ref.startswith("/") else (made.get(ref) or mc._asset(folder, ref))
        if parent is None:
            raise RuntimeError("%s: parent %s missing" % (spec["name"], ref))
        inst = mc._asset(folder, spec["name"])
        created = inst is None
        if created:
            inst = mc._tools().create_asset(spec["name"], folder, unreal.MaterialInstanceConstant,
                                            unreal.MaterialInstanceConstantFactoryNew())
        MEL.set_material_instance_parent(inst, parent)
        # Set*ParameterValue returns false in this build whatever happens, so names are checked against the parent
        known = {kind: set(str(n) for n in getter(inst)) for kind, getter in (
            ("scalar", MEL.get_scalar_parameter_names), ("texture", MEL.get_texture_parameter_names))}
        scalars = create_scalars(spec) if created or reset_looks else {}
        scalars.update(spec["scalars"])
        for k, v in scalars.items():
            if k not in known["scalar"]:
                _warn("%s: Meat_Mars_M has no scalar parameter %s" % (spec["name"], k))
                continue
            MEL.set_material_instance_scalar_parameter_value(inst, k, float(v))
        for k, tex_name in spec["textures"].items():
            tex = _texture(tex_name, tex_folders)
            if tex is None:
                raise RuntimeError("%s: texture %s missing (import_textures first)" % (spec["name"], tex_name))
            if k not in known["texture"]:
                _warn("%s: Meat_Mars_M has no texture parameter %s" % (spec["name"], k))
                continue
            MEL.set_material_instance_texture_parameter_value(inst, k, tex)
        if spec.get("description"):
            EAL.set_metadata_tag(inst, "Description", spec["description"])
        MEL.update_material_instance(inst)
        if save:
            EAL.save_loaded_asset(inst)
        made[spec["name"]] = inst
        _log("%s %s in %s (%d scalars set%s)" % ("created" if created else "updated", spec["name"], folder, len(scalars),
                                                 "" if save else ", unsaved"))
    return made


def report():
    """Dry run: logs what run_all would import and set. Touches nothing."""
    lines = []
    for name, f, kind in TEXTURES:
        path = os.path.join(fs.EXPORT_DIR, f)
        lines.append("texture %s <- %s (%s, %s, %s)" % (name, path, kind, "exists" if os.path.isfile(path) else "MISSING",
                                                      "in project" if mc._asset(F_TEX, name) else "not imported"))
    for spec in INSTANCES:
        exists = mc._asset(F_INST, spec["name"]) is not None
        lines.append("instance %s/%s (%s), parent %s" % (F_INST, spec["name"], "exists" if exists else "new",
                                                        spec["parent"]))
        lines.append("  always: %s, textures %s" % (spec["scalars"], spec["textures"]))
        lines.append("  create-only: %s" % create_scalars(spec))
    for line in lines:
        _log(line)
    return lines


def run_all(export_dir=None, reset_looks=False):
    import_textures(export_dir)
    return build_meat_instances(reset_looks=reset_looks)
