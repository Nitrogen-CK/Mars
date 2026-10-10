"""Mars Candles: a sidebar panel over candle_gen (the SDF candle generator).

Use it either way:
  * Scripting workspace > Text > Open > this file > Run Script (registers until Blender closes), or
  * Edit > Preferences > Add-ons > Install from Disk > this file, then enable "Mars Candles". An installed copy no
    longer sits beside candle_gen.py, so it looks for the generator in the folder named by the MARS_COOKING_TOOLS
    environment variable and then in D:\\Repo\\Mars\\Tools\\Blender\\mars_cooking.
Then: 3D View > sidebar (N) > "Mars Candles" tab.

  Generate        builds / replaces the preview object "CandlePreview_Mars_SM" (with its SOCKET_Flame_NN empties) from
                  the current parameters, where the old preview stood.
  Randomize Seed  a new seed, then Generate.
  Export          FBX + JSON sidecar of the preview into the export folder under the typed name; the "_Mars_SM"
                  suffix is enforced.

The mesh follows the contract in candle_gen's docstring (slots Wax / Wick / Flame, "Col", UV1 "CandleData").
"""
import importlib
import os
import random
import sys

import bpy

bl_info = {
    "name": "Mars Candles",
    "author": "Mars",
    "version": (1, 0, 0),
    "blender": (4, 2, 0),
    "location": "3D View > Sidebar > Mars Candles",
    "description": "Procedural melted candle clusters (SDF blend, height variation) with flames, sockets and export",
    "category": "Object",
}

FALLBACK_TOOLS_DIR = r"D:\Repo\Mars\Tools\Blender\mars_cooking"
PREVIEW_NAME = "CandlePreview_Mars_SM"


def _load_generator():
    """Import candle_gen from this file's folder (or the fallbacks when installed as an add-on)."""
    here = os.path.dirname(os.path.abspath(__file__))
    for folder in (here, os.environ.get("MARS_COOKING_TOOLS", ""), FALLBACK_TOOLS_DIR):
        if folder and os.path.isfile(os.path.join(folder, "candle_gen.py")):
            if folder not in sys.path:
                sys.path.insert(0, folder)
            return importlib.import_module("candle_gen")
    raise ImportError("Mars Candles: candle_gen.py not found beside %s, in MARS_COOKING_TOOLS or in %s" % (
        __file__, FALLBACK_TOOLS_DIR))


cg = _load_generator()
_DEFAULT = cg.CandleParams()


# ================================================================ properties (one per generator parameter)
class MarsCandleSettings(bpy.types.PropertyGroup):
    seed: bpy.props.IntProperty(name="Seed", default=_DEFAULT.seed, min=0, max=2 ** 31 - 1,
                                description="Every dice roll of the cluster comes from this")
    count: bpy.props.IntProperty(name="Candles", default=_DEFAULT.count, min=1, max=12,
                                 description="How many candles stand in the cluster")
    radius_min_cm: bpy.props.FloatProperty(name="Radius Min", default=_DEFAULT.radius_min_cm, min=0.8, max=8.0,
                                           soft_min=1.2, soft_max=4.5, step=10, precision=2,
                                           description="Thinnest candle (cm)")
    radius_max_cm: bpy.props.FloatProperty(name="Radius Max", default=_DEFAULT.radius_max_cm, min=0.8, max=8.0,
                                           soft_min=1.2, soft_max=4.5, step=10, precision=2,
                                           description="Fattest candle (cm)")
    height_min_cm: bpy.props.FloatProperty(name="Height Min", default=_DEFAULT.height_min_cm, min=2.0, max=60.0,
                                           soft_min=4.0, soft_max=30.0, step=50, precision=1,
                                           description="Shortest candle at full height variation (cm)")
    height_max_cm: bpy.props.FloatProperty(name="Height Max", default=_DEFAULT.height_max_cm, min=2.0, max=60.0,
                                           soft_min=4.0, soft_max=30.0, step=50, precision=1,
                                           description="Tallest candle at full height variation (cm)")
    height_variation: bpy.props.FloatProperty(name="Height Variation", default=_DEFAULT.height_variation, min=0.0,
                                              max=1.0, subtype="FACTOR",
                                              description="0 = every candle at the mean height, 1 = the full min..max spread")
    spread_cm: bpy.props.FloatProperty(name="Spread", default=_DEFAULT.spread_cm, min=-2.0, max=20.0, soft_min=-1.0,
                                       soft_max=8.0, step=10, precision=2,
                                       description="Gap between neighbouring candles (cm): 0 touches, negative overlaps, "
                                                   "small values fuse")
    blend_cm: bpy.props.FloatProperty(name="Blend", default=_DEFAULT.blend_cm, min=0.0, max=8.0, soft_max=5.0, step=10,
                                      precision=2,
                                      description="SDF smooth-union radius (cm): 0 = hard union, larger = more melted together")
    blend_top: bpy.props.FloatProperty(name="Blend At Top", default=_DEFAULT.blend_top, min=0.0, max=1.0,
                                       subtype="FACTOR",
                                       description="Share of the blend radius kept high up: 1 = uniform, lower = fused at "
                                                   "the foot with distinct tops")
    melt: bpy.props.FloatProperty(name="Melt", default=_DEFAULT.melt, min=0.0, max=1.0, subtype="FACTOR",
                                  description="Slumped rims, burnt bowl, drips and the size of the wax pool")
    palette: bpy.props.EnumProperty(name="Palette", default=_DEFAULT.palette,
                                    items=[(n, n.capitalize(), "") for n in cg.PALETTE_NAMES],
                                    description="Wax colours (mixed adds the occasional red / purple candle)")
    accent_chance: bpy.props.FloatProperty(name="Accent Chance", default=_DEFAULT.accent_chance, min=0.0, max=1.0,
                                           subtype="FACTOR",
                                           description="Mixed palette: chance of a red or purple candle")
    lean: bpy.props.FloatProperty(name="Lean", default=_DEFAULT.lean, min=0.0, max=1.0, subtype="FACTOR",
                                  description="How far the candles tilt off vertical")
    lit: bpy.props.BoolProperty(name="Lit (flames)", default=_DEFAULT.lit,
                                description="Off = wicks only, no flame geometry (the flame sockets stay)")
    closed_base: bpy.props.BoolProperty(name="Closed Underside", default=_DEFAULT.closed_base,
                                        description="Keep the flat underside (a closed shell); off drops those hidden faces")
    voxel_cm: bpy.props.FloatProperty(name="Voxel", default=_DEFAULT.voxel_cm, min=0.15, max=1.5, step=5, precision=2,
                                      description="SDF sampling resolution (cm); smaller = finer drips, slower")
    target_tris: bpy.props.IntProperty(name="Target Tris", default=_DEFAULT.target_tris, min=120, max=60000,
                                       description="Triangle budget of the whole mesh (wax + wicks + flames)")
    # export
    export_name: bpy.props.StringProperty(name="Name", default="CandleCluster_Custom_Mars_SM",
                                          description="Asset name; the _Mars_SM suffix is enforced")
    export_dir: bpy.props.StringProperty(name="Folder", default=cg.EXPORT_DIR, subtype="DIR_PATH",
                                         description="Where the FBX and its JSON sidecar go")
    last_info: bpy.props.StringProperty(name="Last Result", default="")

    def to_params(self):
        return cg.CandleParams(**{name: getattr(self, name) for name in cg.PARAM_NAMES})


def _missing_params():
    have = set(MarsCandleSettings.__annotations__)
    return [n for n in cg.PARAM_NAMES if n not in have]


def _preview(context):
    obj = bpy.data.objects.get(PREVIEW_NAME)
    return obj if obj is not None and obj.type == "MESH" else None


def _generate(context):
    settings = context.scene.mars_candles
    old = _preview(context)
    where = old.matrix_world.copy() if old is not None else None
    obj, info = cg.generate(settings.to_params(), name=PREVIEW_NAME, verbose=False)
    if where is not None:
        obj.matrix_world = where
    for o in context.view_layer.objects:
        o.select_set(o is obj)
    context.view_layer.objects.active = obj
    settings.last_info = "%d candles, %d tris, %.0f x %.0f x %.0f cm, %.2f s" % (
        len(info["candles"]), info["tris"], info["size_cm"][0], info["size_cm"][1], info["size_cm"][2],
        info["seconds"]["total"])
    return obj, info


# ================================================================ operators
class MARSCANDLES_OT_generate(bpy.types.Operator):
    bl_idname = "mars_candles.generate"
    bl_label = "Generate"
    bl_description = "Build / replace the candle preview object from the current parameters"
    bl_options = {"REGISTER", "UNDO"}

    @classmethod
    def poll(cls, context):
        return context.mode == "OBJECT"

    def execute(self, context):
        try:
            obj, info = _generate(context)
        except Exception as exc:
            self.report({"ERROR"}, "Mars Candles: %s" % exc)
            return {"CANCELLED"}
        self.report({"INFO"}, "Mars Candles: %s" % context.scene.mars_candles.last_info)
        return {"FINISHED"}


class MARSCANDLES_OT_randomize_seed(bpy.types.Operator):
    bl_idname = "mars_candles.randomize_seed"
    bl_label = "Randomize Seed"
    bl_description = "Roll a new seed and generate"
    bl_options = {"REGISTER", "UNDO"}

    @classmethod
    def poll(cls, context):
        return context.mode == "OBJECT"

    def execute(self, context):
        context.scene.mars_candles.seed = random.SystemRandom().randrange(1, 1000000)
        return bpy.ops.mars_candles.generate()


class MARSCANDLES_OT_export(bpy.types.Operator):
    bl_idname = "mars_candles.export"
    bl_label = "Export"
    bl_description = "FBX + JSON sidecar of the preview into the export folder (the _Mars_SM suffix is enforced)"
    bl_options = {"REGISTER"}

    @classmethod
    def poll(cls, context):
        return context.mode == "OBJECT"

    def execute(self, context):
        settings = context.scene.mars_candles
        obj = _preview(context)
        try:
            if obj is None or cg.info_of(obj) is None:
                obj, _ = _generate(context)
            name = cg.clean_name(settings.export_name)
            settings.export_name = name
            folder = bpy.path.abspath(settings.export_dir) if settings.export_dir else cg.EXPORT_DIR
            path = cg.export_candle(obj, folder, name)
        except Exception as exc:
            self.report({"ERROR"}, "Mars Candles: %s" % exc)
            return {"CANCELLED"}
        self.report({"INFO"}, "Mars Candles: exported %s" % path)
        return {"FINISHED"}


# ================================================================ panel
class MARSCANDLES_PT_panel(bpy.types.Panel):
    bl_idname = "MARSCANDLES_PT_panel"
    bl_label = "Mars Candles"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Mars Candles"

    def draw(self, context):
        s = context.scene.mars_candles
        layout = self.layout
        layout.use_property_split = True
        layout.use_property_decorate = False

        row = layout.row(align=True)
        row.scale_y = 1.4
        row.operator("mars_candles.generate", icon="LIGHT_POINT")
        row.operator("mars_candles.randomize_seed", text="Randomize Seed", icon="FILE_REFRESH")
        if s.last_info:
            layout.label(text=s.last_info, icon="INFO")

        col = layout.column(align=True)
        col.prop(s, "seed")
        col.prop(s, "count")

        box = layout.box()
        box.label(text="Size")
        col = box.column(align=True)
        col.prop(s, "radius_min_cm")
        col.prop(s, "radius_max_cm")
        col = box.column(align=True)
        col.prop(s, "height_min_cm")
        col.prop(s, "height_max_cm")
        box.prop(s, "height_variation", slider=True)

        box = layout.box()
        box.label(text="Fuse and Melt")
        col = box.column(align=True)
        col.prop(s, "spread_cm")
        col.prop(s, "blend_cm")
        col.prop(s, "blend_top", slider=True)
        box.prop(s, "melt", slider=True)
        box.prop(s, "lean", slider=True)

        box = layout.box()
        box.label(text="Look")
        box.prop(s, "palette")
        sub = box.column()
        sub.active = s.palette == "mixed"
        sub.prop(s, "accent_chance", slider=True)
        box.prop(s, "lit")

        box = layout.box()
        box.label(text="Mesh")
        col = box.column(align=True)
        col.prop(s, "voxel_cm")
        col.prop(s, "target_tris")
        box.prop(s, "closed_base")

        box = layout.box()
        box.label(text="Export")
        box.prop(s, "export_name")
        box.prop(s, "export_dir")
        row = box.row()
        row.scale_y = 1.3
        row.operator("mars_candles.export", icon="EXPORT")


CLASSES = (MarsCandleSettings, MARSCANDLES_OT_generate, MARSCANDLES_OT_randomize_seed, MARSCANDLES_OT_export,
           MARSCANDLES_PT_panel)


def register():
    missing = _missing_params()
    if missing:
        raise RuntimeError("Mars Candles: no property for generator parameter(s) %s" % missing)
    for cls in CLASSES:
        bpy.utils.register_class(cls)
    bpy.types.Scene.mars_candles = bpy.props.PointerProperty(type=MarsCandleSettings)


def unregister():
    if hasattr(bpy.types.Scene, "mars_candles"):
        del bpy.types.Scene.mars_candles
    for cls in reversed(CLASSES):
        bpy.utils.unregister_class(cls)


if __name__ == "__main__":
    register()
