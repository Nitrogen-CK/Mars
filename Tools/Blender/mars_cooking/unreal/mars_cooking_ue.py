"""Editor side of the Mars cooking look: imports the meshes / textures the Blender + texture scripts export and builds
the sear ramps, Meat_Mars_M, Pan_Mars_M, their instances and the lookdev map. Run in the editor's Python (Monolith
`editor_query run_python`):

    import sys, importlib
    sys.path.insert(0, r"D:\\Repo\\Mars\\Tools\\Blender\\mars_cooking\\unreal")
    import mars_cooking_ue as mc; importlib.reload(mc)
    mc.run_all()            # or the single steps: import_textures / import_meshes / build_materials / build_lookdev_map

The masters are generated: a rebuild replaces them, so tune looks in the material instances (their overrides and
the sear ramp curves survive a rebuild).

MeatCube_Mars_SM is hand-authored since 2026-10-07: Stephen's D:\Repo\Content\Cooking\CookingProps.blend is its source
and export\MeatCube_Mars_SM.fbx is exported from there (build_cooking_meshes.py only rewrites it with --cube).
import_meshes just re-imports whatever FBX is in the export folder; cooking_spec.CUBE_MESH_HALF_CM is the mesh's measured
half extent (cube heights in the lookdev map, the pan's Meat Footprint).

The lookdev map also carries the pan's Niagara oil bubbles and splatter from the food library
(mars_food_ue.attach_pan_bubbles, attached to Meat_InPan); without that module the map builds without them.
"""
import importlib
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
for _p in (HERE, os.path.dirname(HERE)):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import cooking_spec as spec  # noqa: E402
import mars_cooking_hlsl as hlsl  # noqa: E402

importlib.reload(spec)
importlib.reload(hlsl)

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary
FLOAT1 = unreal.CustomMaterialOutputType.CMOT_FLOAT1
FLOAT3 = unreal.CustomMaterialOutputType.CMOT_FLOAT3
FLOAT4 = unreal.CustomMaterialOutputType.CMOT_FLOAT4

F_MESH = spec.UE_FOLDER + "/Meshes"
F_TEX = spec.UE_FOLDER + "/Textures"
F_MAT = spec.UE_FOLDER + "/Materials"
F_INST = F_MAT + "/Instances"
F_CURVE = F_MAT + "/Curves"
F_LOOK = spec.UE_FOLDER + "/Lookdev"


def _log(msg):
    unreal.log("MarsCooking: %s" % msg)


def _warn(msg):
    unreal.log_warning("MarsCooking: %s" % msg)


# ------------------------------------------------------------------ asset helpers
def _load(path):
    """The asset registry lags behind replaced imports, so fall back to the object itself."""
    if EAL.does_asset_exist(path):
        return EAL.load_asset(path)
    obj = unreal.find_object(None, path)
    if obj is None:
        try:
            obj = unreal.load_object(None, path)
        except Exception:
            obj = None
    return obj


def _asset(folder, name):
    return _load("%s/%s.%s" % (folder, name, name))


def _tools():
    return unreal.AssetToolsHelpers.get_asset_tools()


def _task(filename, folder, name):
    task = unreal.AssetImportTask()
    task.filename = filename
    task.destination_path = folder
    task.destination_name = name
    task.replace_existing = True
    task.automated = True
    task.save = False
    try:
        task.set_editor_property("async_", False)        # Interchange is asynchronous unless told otherwise
    except Exception:
        pass
    return task


def _in_pie():
    return unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).is_in_play_in_editor()


# ------------------------------------------------------------------ textures
TEXTURES = (
    ("MeatCube_Wagyu_Mask_Mars_T", "MeatCube_Wagyu_Mask_Mars_T.png", "masks"),
    ("MeatCube_Wagyu_Normal_Mars_T", "MeatCube_Wagyu_Normal_Mars_T.png", "normal"),
    ("CookingStudio_Mars_HDR", "CookingStudio_Mars_HDR.hdr", "hdr"),
)


def import_textures(export_dir=None):
    export_dir = export_dir or spec.EXPORT_DIR
    _tools().import_asset_tasks([_task(os.path.join(export_dir, f), F_TEX, n) for n, f, _ in TEXTURES])
    for name, _, kind in TEXTURES:
        tex = _asset(F_TEX, name)
        if tex is None:
            _warn("texture %s did not import" % name)
            continue
        if kind == "normal":
            tex.set_editor_property("compression_settings", unreal.TextureCompressionSettings.TC_NORMALMAP)
            tex.set_editor_property("srgb", False)
            tex.set_editor_property("flip_green_channel", False)      # generated DirectX style (green down)
        elif kind == "masks":
            tex.set_editor_property("compression_settings", unreal.TextureCompressionSettings.TC_MASKS)
            tex.set_editor_property("srgb", False)
        EAL.save_loaded_asset(tex)
    _log("textures imported")


# ------------------------------------------------------------------ meshes
def import_meshes(export_dir=None):
    """Legacy FBX importer (it honours FbxImportUI); normals come from the file, no lightmap UVs so the cube's
    shape offsets stay in UV1 / UV2. The cube FBX is hand-authored (see the module docstring): keep its UVMap /
    ShapeXY / ShapeZ layers and the Meat slot when re-exporting it."""
    export_dir = export_dir or spec.EXPORT_DIR
    if _in_pie():
        raise RuntimeError("stop PIE before importing (assets imported during PIE vanish)")
    names = ("MeatCube_Mars_SM", "FryPan_Mars_SM")
    tasks = []
    for name in names:
        task = _task(os.path.join(export_dir, name + ".fbx"), F_MESH, name)
        opts = unreal.FbxImportUI()
        opts.import_mesh = True
        opts.import_as_skeletal = False
        opts.import_materials = False
        opts.import_textures = False
        sm = opts.static_mesh_import_data
        sm.combine_meshes = True
        sm.generate_lightmap_u_vs = False
        sm.auto_generate_collision = False
        sm.set_editor_property("normal_import_method", unreal.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS)
        task.options = opts
        tasks.append(task)
    cvar = "Interchange.FeatureFlags.Import.FBX"
    was = unreal.SystemLibrary.get_console_variable_bool_value(cvar)
    unreal.SystemLibrary.execute_console_command(None, "%s 0" % cvar)
    try:
        _tools().import_asset_tasks(tasks)
    finally:
        unreal.SystemLibrary.execute_console_command(None, "%s %d" % (cvar, 1 if was else 0))
    for name in names:
        mesh = _asset(F_MESH, name)
        if mesh is None:
            _warn("mesh %s did not import" % name)
            continue
        b = mesh.get_bounds()
        _log("%s extent %.2f %.2f %.2f cm, %d uv channels" % (
            name, b.box_extent.x, b.box_extent.y, b.box_extent.z,
            unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem).get_num_uv_channels(mesh, 0)))
        EAL.save_loaded_asset(mesh)
    assign_mesh_materials()


def assign_mesh_materials():
    slots = {"MeatCube_Mars_SM": {"Meat": "Meat_Wagyu_Mars_MI"},
             "FryPan_Mars_SM": {"Pan": "Pan_Steel_Mars_MI", "Handle": "Pan_Handle_Mars_MI"}}
    for mesh_name, by_slot in slots.items():
        mesh = _asset(F_MESH, mesh_name)
        if mesh is None:
            continue
        for i, slot in enumerate(mesh.get_editor_property("static_materials")):
            mi = _asset(F_INST, by_slot.get(str(slot.get_editor_property("material_slot_name")), ""))
            if mi is not None:
                mesh.set_material(i, mi)
        EAL.save_loaded_asset(mesh)


# ------------------------------------------------------------------ sear ramps
RAMP_CURVES = ("SearRamp_WagyuLean_Mars_Curve", "SearRamp_WagyuFat_Mars_Curve")
RAMP_ATLAS = "SearRamps_Mars_CurveAtlas"


def build_curves(export_dir=None, refresh=False):
    """One CurveLinearColor per ramp CSV and the atlas that bakes them. Colour-curve keys are not script visible, so
    the curves come in through the CSV factory; a curve that already exists is the artist's and is left alone unless
    refresh is set (which re-imports the CSV over it)."""
    export_dir = export_dir or spec.EXPORT_DIR
    tasks = []
    for name in RAMP_CURVES:
        if _asset(F_CURVE, name) is not None and not refresh:
            continue
        task = _task(os.path.join(export_dir, name + ".csv"), F_CURVE, name)
        fac = unreal.CSVImportFactory()
        st = unreal.CSVImportSettings()
        st.set_editor_property("import_type", unreal.CSVImportType.ECSV_CURVE_LINEAR_COLOR)
        st.set_editor_property("import_curve_interp_mode", unreal.RichCurveInterpMode.RCIM_CUBIC)
        fac.set_editor_property("automated_import_settings", st)
        task.factory = fac
        tasks.append(task)
    if tasks:
        _tools().import_asset_tasks(tasks)
    curves = []
    for name in RAMP_CURVES:
        c = _asset(F_CURVE, name)
        if c is None:
            _warn("ramp %s did not import" % name)
            continue
        EAL.save_loaded_asset(c)
        curves.append(c)
    atlas = _asset(F_CURVE, RAMP_ATLAS)
    if atlas is None:
        atlas = _tools().create_asset(RAMP_ATLAS, F_CURVE, unreal.CurveLinearColorAtlas, unreal.CurveLinearColorAtlasFactory())
    atlas.set_editor_property("texture_size", 256)
    # the atlas only re-bakes when its curve list changes, so a refreshed curve (same object, new keys) would leave
    # the old ramp in the texture: clear the list first so setting it again is a change
    atlas.set_editor_property("gradient_curves", [])
    atlas.set_editor_property("gradient_curves", curves)
    EAL.save_loaded_asset(atlas)
    return atlas, {c.get_name(): c for c in curves}


# ------------------------------------------------------------------ material graph builder
_RETIRED = []


def _fresh_material(name):
    """A brand-new master at the path (wiping a graph in place leaves Custom nodes behind). An existing master is
    renamed aside; build_instances re-parents its instances and then deletes it."""
    m = _asset(F_MAT, name)
    if m is not None:
        aside = "%s/%s_retired" % (F_MAT, name)
        stale = _asset(F_MAT, name + "_retired")
        if stale is not None:                      # left by an interrupted build: its instances come back first
            for data in MEL.get_child_instances(stale):
                inst = data.get_asset()
                MEL.set_material_instance_parent(inst, m)
                EAL.save_loaded_asset(inst)
            EAL.delete_loaded_asset(stale)
            unreal.SystemLibrary.collect_garbage()
        if EAL.rename_loaded_asset(m, aside):
            _RETIRED.append(aside)
        else:
            MEL.delete_all_material_expressions(m)
            _warn("%s could not be moved aside, wiped in place" % name)
            return m
    return _tools().create_asset(name, F_MAT, unreal.Material, unreal.MaterialFactoryNew())


def _drop_retired():
    while _RETIRED:
        path = _RETIRED.pop()
        obj = EAL.load_asset(path) if EAL.does_asset_exist(path) else None
        ok = EAL.delete_loaded_asset(obj) if obj is not None else True
        unreal.SystemLibrary.collect_garbage()
        if not ok or EAL.does_asset_exist(path):
            _warn("retired master %s could not be deleted, left in place (safe to delete by hand)" % path)


class _Graph:
    """Parameters go in one column per group (the group is also the material-instance category); the rest is placed
    by hand to the right of them."""
    COL_W = 430

    def __init__(self, material, x0, y0=-1400):
        self.m = material
        self.x0, self.y0 = x0, y0
        self.col, self.y = -1, y0
        self.group_name, self.prio = None, 0

    def expr(self, cls, x, y):
        return MEL.create_material_expression(self.m, cls, x, y)

    def link(self, src, out, dst, pin):
        if not MEL.connect_material_expressions(src, out, dst, pin):
            _warn("%s: could not connect %s.%s -> %s.%s" % (self.m.get_name(), src.get_name(), out, dst.get_name(), pin))

    def group(self, name):
        self.group_name, self.prio = name, 0
        self.col += 1
        self.y = self.y0

    def _param(self, cls, height, name, desc):
        e = self.expr(cls, self.x0 + self.col * self.COL_W, self.y)
        self.y += height
        e.set_editor_property("parameter_name", name)
        e.set_editor_property("group", unreal.Name(self.group_name))
        e.set_editor_property("sort_priority", self.prio)
        self.prio += 1
        if desc:
            e.set_editor_property("desc", desc)
        return e

    def scalar(self, name, value, lo=0.0, hi=1.0, desc=""):
        e = self._param(unreal.MaterialExpressionScalarParameter, 100, name, desc)
        e.set_editor_property("default_value", value)
        e.set_editor_property("slider_min", lo)
        e.set_editor_property("slider_max", hi)
        return e

    def vector(self, name, value, desc="", channels=None, cpd=None):
        e = self._param(unreal.MaterialExpressionVectorParameter, 240, name, desc)
        e.set_editor_property("default_value", unreal.LinearColor(*value))
        if channels:
            cn = unreal.ParameterChannelNames()
            for key, label in zip("rgba", channels):
                cn.set_editor_property(key, unreal.Text(label))
            e.set_editor_property("channel_names", cn)
        if cpd is not None:
            e.set_editor_property("use_custom_primitive_data", True)
            e.set_editor_property("primitive_data_index", cpd)
        return e

    def texture(self, name, tex, sampler, uv, desc=""):
        e = self._param(unreal.MaterialExpressionTextureSampleParameter2D, 280, name, desc)
        if tex is not None:
            e.set_editor_property("texture", tex)
        e.set_editor_property("sampler_type", sampler)
        self.link(uv, "", e, "UVs")
        return e

    def ramp(self, name, atlas, curve, desc=""):
        e = self._param(unreal.MaterialExpressionCurveAtlasRowParameter, 200, name, desc)
        e.set_editor_property("atlas", atlas)
        e.set_editor_property("curve", curve)
        return e

    def custom(self, title, code, inputs, x, y, out=FLOAT3, extra=()):
        """inputs: (pin name, source node, source output name)."""
        cu = self.expr(unreal.MaterialExpressionCustom, x, y)
        cu.set_editor_property("code", code)
        cu.set_editor_property("output_type", out)
        cu.set_editor_property("description", title)
        pins = []
        for pin, _, _ in inputs:                      # CustomInput takes no constructor kwargs (UE 5.7)
            ci = unreal.CustomInput()
            ci.set_editor_property("input_name", pin)
            pins.append(ci)
        cu.set_editor_property("inputs", pins)
        outs = []
        for pin, ty in extra:
            co = unreal.CustomOutput()
            co.set_editor_property("output_name", pin)
            co.set_editor_property("output_type", ty)
            outs.append(co)
        if outs:
            cu.set_editor_property("additional_outputs", outs)
        for pin, src, out_name in inputs:
            self.link(src, out_name, cu, pin)
        return cu

    def local_space(self, x, y):
        """(local position before shader offsets, local vertex normal, bounds node)."""
        wp = self.expr(unreal.MaterialExpressionWorldPosition, x, y)
        wp.set_editor_property("world_position_shader_offset", unreal.WorldPositionIncludedOffsets.WPT_EXCLUDE_ALL_SHADER_OFFSETS)
        lp = self.expr(unreal.MaterialExpressionTransformPosition, x + 260, y)
        lp.set_editor_property("transform_source_type", unreal.MaterialPositionTransformSource.TRANSFORMPOSSOURCE_WORLD)
        lp.set_editor_property("transform_type", unreal.MaterialPositionTransformSource.TRANSFORMPOSSOURCE_LOCAL)
        self.link(wp, "", lp, "")
        vn = self.expr(unreal.MaterialExpressionVertexNormalWS, x, y + 160)
        ln = self.expr(unreal.MaterialExpressionTransform, x + 260, y + 160)
        ln.set_editor_property("transform_source_type", unreal.MaterialVectorCoordTransformSource.TRANSFORMSOURCE_WORLD)
        ln.set_editor_property("transform_type", unreal.MaterialVectorCoordTransform.TRANSFORM_LOCAL)
        self.link(vn, "", ln, "")
        return lp, ln

    def to_world(self, node, out, x, y):
        t = self.expr(unreal.MaterialExpressionTransform, x, y)
        t.set_editor_property("transform_source_type", unreal.MaterialVectorCoordTransformSource.TRANSFORMSOURCE_LOCAL)
        t.set_editor_property("transform_type", unreal.MaterialVectorCoordTransform.TRANSFORM_WORLD)
        self.link(node, out, t, "")
        return t

    def finish(self, attributes, x, y):
        """attributes: {MakeMaterialAttributes pin: (node, output)}. Clear coat has no MaterialProperty in Python, so
        every output goes through one MakeMaterialAttributes node."""
        self.m.set_editor_property("use_material_attributes", True)
        mma = self.expr(unreal.MaterialExpressionMakeMaterialAttributes, x, y)
        for pin, (node, out) in attributes.items():
            self.link(node, out, mma, pin)
        MEL.connect_material_property(mma, "", unreal.MaterialProperty.MP_MATERIAL_ATTRIBUTES)
        MEL.recompile_material(self.m)
        EAL.save_loaded_asset(self.m)


# ------------------------------------------------------------------ Meat_Mars_M
SEAR_XY = ("+X", "-X", "+Y", "-Y")
SEAR_Z = ("+Z", "-Z", "Penetration", "Oil Coat")
FINISH = ("Glaze", "Shape", "-", "-")


def build_meat_master(atlas, curves):
    m = _fresh_material("Meat_Mars_M")
    m.set_editor_property("shading_model", unreal.MaterialShadingModel.MSM_CLEAR_COAT)
    g = _Graph(m, x0=-5200)

    g.group("01 Driven (Custom Primitive Data)")
    sear_a = g.vector("Sear XY", (0, 0, 0, 0), "Sear per local axis: 0 raw, 1 full crust, 2 burnt. Custom Primitive Data 0-3.", SEAR_XY, cpd=0)
    sear_b = g.vector("Sear Z + Cook", (0, 0, 0, 0), "Sear on +Z / -Z, Penetration 0..1 (how far the cooked band has crept in; "
                      "scales Band Depth) and Oil Coat 0..1. Custom Primitive Data 4-7.", SEAR_Z, cpd=4)
    fin = g.vector("Finish", (0, 0, 0, 0), "Glaze 0..1 (resting juices, the plated shine) and Shape 0..1 (raw cut -> cooked "
                   "shape). Custom Primitive Data 8-9.", FINISH, cpd=8)

    g.group("02 Debug Override")
    use_dbg = g.scalar("Debug Use Sliders", 0.0, 0.0, 1.0, "1 = ignore Custom Primitive Data and use the three vectors below "
                       "(for look tuning in an instance; leave 0 in game).")
    dbg_a = g.vector("Debug Sear XY", (0, 0, 0, 0), "", SEAR_XY)
    dbg_b = g.vector("Debug Sear Z + Cook", (0, 0, 1, 0), "", SEAR_Z)
    dbg_f = g.vector("Debug Finish", (0, 0, 0, 0), "", FINISH)

    g.group("03 Sear")
    lean = g.ramp("Lean Ramp", atlas, curves.get(RAMP_CURVES[0]), "Colour of the lean meat over the sear (curve time 0..1 = sear 0..Sear Range).")
    fat = g.ramp("Fat Ramp", atlas, curves.get(RAMP_CURVES[1]), "Colour of the marbling over the sear.")
    sear_range = g.scalar("Sear Range", 2.0, 0.5, 4.0, "Sear value that reaches the end of the ramps.")
    sharp = g.scalar("Face Sharpness", 6.0, 1.0, 16.0, "How strictly a sear value stays on its own side. Lower blends around round shapes.")
    breakup = g.scalar("Crust Breakup", 0.3, 0.0, 1.5, "Patchiness of the browning (mask B).")
    edge_boost = g.scalar("Edge Boost", 0.35, 0.0, 1.0, "Extra sear on edges (mask A).")
    band_depth = g.scalar("Band Depth", 1.1, 0.0, 6.0, "Centimetres the cooked band reaches from a fully seared face at Penetration 1.")
    band_soft = g.scalar("Band Softness", 0.55, 0.05, 1.0, "Softness of the band's leading edge.")
    band_wobble = g.scalar("Band Wobble", 0.25, 0.0, 2.0, "Centimetres of irregularity on the band edge.")
    band_ramp = g.scalar("Band Ramp Position", 0.24, 0.0, 0.5, "Ramp time the cooked band shows (the grey-brown of cooked meat, not crust).")
    fibre = g.scalar("Fibre Contrast", 0.25, 0.0, 1.0, "Strength of the grain in the colour (mask G).")

    g.group("04 Textures")
    uv0 = g.expr(unreal.MaterialExpressionTextureCoordinate, g.x0 + g.col * g.COL_W - 260, g.y0)
    mask = g.texture("Mask", _asset(F_TEX, "MeatCube_Wagyu_Mask_Mars_T"), unreal.MaterialSamplerType.SAMPLERTYPE_MASKS, uv0,
                     "R fat marbling, G fibre grain, B crust break-up, A edge mask.")
    nrm = g.texture("Normal", _asset(F_TEX, "MeatCube_Wagyu_Normal_Mars_T"), unreal.MaterialSamplerType.SAMPLERTYPE_NORMAL, uv0)
    nrm_raw = g.scalar("Normal Raw", 0.25, 0.0, 2.0, "Normal strength while raw.")
    nrm_crust = g.scalar("Normal Crust", 0.55, 0.0, 3.0, "Normal strength of the crust.")

    g.group("05 Surface")
    r_lean = g.scalar("Roughness Lean", 0.42)
    r_fat = g.scalar("Roughness Fat", 0.5)
    r_crust = g.scalar("Roughness Crust", 0.72)
    r_burnt = g.scalar("Roughness Burnt", 0.9)
    fat_gloss = g.scalar("Rendered Fat Gloss", 0.2, 0.0, 0.5, "Roughness the marbling loses as it renders.")

    g.group("06 Coat")
    raw_wet = g.scalar("Raw Wetness", 0.45, 0.0, 1.0, "Clear coat of the raw, moist cut.")
    oil_strength = g.scalar("Oil Coat Strength", 0.8, 0.0, 1.0, "Clear coat at Oil Coat 1.")
    glaze_strength = g.scalar("Glaze Strength", 1.0, 0.0, 1.0, "Clear coat at Glaze 1.")
    coat_rough = g.scalar("Coat Roughness", 0.12, 0.0, 0.5)
    coat_breakup = g.scalar("Coat Breakup", 0.35, 0.0, 1.0, "How patchy the oil / glaze sits.")

    g.group("07 Shape")
    shape_scale = g.scalar("Shape Scale", 1.0, 0.0, 2.0, "Multiplier on the baked raw -> cooked offset (UV1 / UV2).")

    x = -1500
    lp, ln = g.local_space(x - 700, -900)
    bounds = g.expr(unreal.MaterialExpressionObjectLocalBounds, x - 440, -560)
    cook = g.custom("MeatCook: sear -> ramp time, crust, burn, oil", hlsl.MEAT_COOK, (
        ("P", lp, ""), ("N", ln, ""), ("BMin", bounds, "Min"), ("BMax", bounds, "Max"),
        ("SearA", sear_a, "RGBA"), ("SearB", sear_b, "RGBA"), ("DbgA", dbg_a, "RGBA"), ("DbgB", dbg_b, "RGBA"),
        ("UseDebug", use_dbg, ""), ("Mask", mask, "RGBA"), ("Sharp", sharp, ""), ("Breakup", breakup, ""),
        ("EdgeBoost", edge_boost, ""), ("BandDepth", band_depth, ""), ("BandSoft", band_soft, ""),
        ("BandWobble", band_wobble, ""), ("BandRamp", band_ramp, ""), ("SearRange", sear_range, "")), x, -900, FLOAT4)
    time = g.expr(unreal.MaterialExpressionComponentMask, x + 420, -1100)
    for ch, on in (("r", True), ("g", False), ("b", False), ("a", False)):
        time.set_editor_property(ch, on)
    g.link(cook, "", time, "")
    g.link(time, "", lean, "CurveTime")
    g.link(time, "", fat, "CurveTime")
    surf = g.custom("MeatSurface: colour, roughness, coat", hlsl.MEAT_SURFACE, (
        ("Lean", lean, ""), ("Fat", fat, ""), ("Mask", mask, "RGBA"), ("Cook", cook, ""),
        ("Fin", fin, "RGBA"), ("DbgFin", dbg_f, "RGBA"), ("UseDebug", use_dbg, ""), ("FibreContrast", fibre, ""),
        ("RoughLean", r_lean, ""), ("RoughFat", r_fat, ""), ("RoughCrust", r_crust, ""), ("RoughBurnt", r_burnt, ""),
        ("FatGloss", fat_gloss, ""), ("RawWet", raw_wet, ""), ("OilStrength", oil_strength, ""),
        ("GlazeStrength", glaze_strength, ""), ("CoatBreakup", coat_breakup, ""), ("NrmRaw", nrm_raw, ""),
        ("NrmCrust", nrm_crust, "")), x + 700, -900, FLOAT3,
        (("Roughness", FLOAT1), ("Coat", FLOAT1), ("NormalStrength", FLOAT1)))
    normal = g.custom("MeatNormal: scale the tangent normal", hlsl.MEAT_NORMAL,
                      (("Nrm", nrm, "RGB"), ("Strength", surf, "NormalStrength")), x + 1150, -300)
    uv1 = g.expr(unreal.MaterialExpressionTextureCoordinate, x + 400, 200)
    uv1.set_editor_property("coordinate_index", 1)
    uv2 = g.expr(unreal.MaterialExpressionTextureCoordinate, x + 400, 320)
    uv2.set_editor_property("coordinate_index", 2)
    shape = g.custom("MeatShape: raw -> cooked offset (local cm)", hlsl.MEAT_SHAPE, (
        ("UV1", uv1, ""), ("UV2", uv2, ""), ("Fin", fin, "RGBA"), ("DbgFin", dbg_f, "RGBA"), ("UseDebug", use_dbg, ""),
        ("Scale", shape_scale, "")), x + 700, 200)
    wpo = g.to_world(shape, "", x + 1150, 200)
    g.finish({"BaseColor": (surf, ""), "Roughness": (surf, "Roughness"), "Normal": (normal, ""),
              "ClearCoat": (surf, "Coat"), "ClearCoatRoughness": (coat_rough, ""),
              "WorldPositionOffset": (wpo, "")}, x + 1600, -700)
    return m


# ------------------------------------------------------------------ Pan_Mars_M
def build_pan_master():
    m = _fresh_material("Pan_Mars_M")
    m.set_editor_property("shading_model", unreal.MaterialShadingModel.MSM_CLEAR_COAT)
    m.set_editor_property("tangent_space_normal", False)       # the normal is built in pan-local space
    g = _Graph(m, x0=-6500)

    g.group("01 Driven")
    oil = g.scalar("Oil Amount", 0.0, 0.0, 1.0, "How much oil is in the pan: pool size, drop and bead count.")
    sizzle = g.scalar("Sizzle", 0.0, 0.0, 1.0, "Bubbling in the oil around the meat.")
    fond = g.scalar("Fond", 0.0, 0.0, 1.0, "Burnt-on residue built up over this cook; adds to the pan's Seasoning.")
    meat_desc = ("Meat position in pan-local cm and its footprint radius. Radius 0 = no meat. "
                 "For a cube of half extent h the radius is h * sqrt(2) * 0.9 (cooking_spec.CUBE_FOOTPRINT_CM: 2.55 for "
                 "the 4 cm cube), so the oil pool (that radius + Pool Margin * Oil Amount) hugs the cube.")
    trail_desc = "Pan-local cm position that lags behind the meat; the pool stretches between the two."
    meat = g.vector("Meat Footprint", (0, 0, 0, 0), meat_desc, ("X", "Y", "Radius", "-"))
    trail = g.vector("Oil Trail", (0, 0, 0, 0), trail_desc, ("X", "Y", "-", "-"))
    # Five more meats, so every piece on the searing station's pan (six at most) gets its own pool; the unsuffixed pair
    # is slot 0, kept so existing instances keep working. A slot with radius 0 draws nothing.
    meats = [g.vector("Meat Footprint %d" % i, (0, 0, 0, 0), meat_desc, ("X", "Y", "Radius", "-")) for i in range(1, 6)]
    trails = [g.vector("Oil Trail %d" % i, (0, 0, 0, 0), trail_desc, ("X", "Y", "-", "-")) for i in range(1, 6)]

    g.group("02 Pan Shape")
    base_r = g.scalar("Base Radius", spec.PAN_BASE_R, 2.0, 40.0, "Radius of the flat cooking base, cm.")
    rim_r = g.scalar("Rim Radius", spec.PAN_RIM_R, 2.0, 50.0, "Inner radius at the rim, cm.")

    g.group("03 Metal")
    metal_col = g.vector("Metal Color", (0.62, 0.63, 0.64, 1.0))
    metallic = g.scalar("Metallic", 1.0)
    rough = g.scalar("Roughness", 0.1, 0.0, 1.0, "Keep at or under 0.1: above that the engine fades reflection captures by "
                     "the indirect light at the pixel (r.ReflectionEnvironmentLightmapMixing), which blackens chrome in a dark room.")
    ring_freq = g.scalar("Ring Frequency", 9.0, 0.0, 40.0, "Lathe rings per cm of radius.")
    ring_strength = g.scalar("Ring Strength", 0.035, 0.0, 0.5)

    g.group("04 Seasoning")
    seasoning = g.scalar("Seasoning", 0.9, 0.0, 1.5, "The pan's permanent burnt-on patina. Thin it bronzes the steel, thick it is a dark matte skin.")
    season_radius = g.scalar("Seasoning Radius", 9.2, 0.0, 40.0, "Radius the patina covers, cm.")
    season_breakup = g.scalar("Seasoning Edge Breakup", 0.6, 0.0, 1.5, "How ragged the patina's outline is.")
    season_bands = g.scalar("Scorch Bands", 0.25, 0.0, 1.0, "Concentric lighter / darker rings in the patina.")
    season_specks = g.scalar("Carbon Specks", 0.5, 0.0, 1.0, "Small black burnt spots.")
    season_thin = g.vector("Seasoning Thin Color", (0.80, 0.50, 0.22, 1.0), "Tint a thin patina multiplies onto the steel.")
    season_thick = g.vector("Seasoning Thick Color", (0.05, 0.024, 0.012, 1.0), "Colour of the thick, opaque skin.")
    season_rough = g.scalar("Seasoning Roughness", 0.26, 0.0, 1.0, "Roughness of the thick skin. Higher is more matte, so the oil's gloss stands out more.")
    season_metal = g.scalar("Seasoning Metallic", 0.1, 0.0, 1.0, "Metallic of the thick skin.")

    g.group("05 Oil Look")
    oil_tint = g.vector("Oil Tint", (1.0, 0.74, 0.32, 1.0), "What the film does to the surface under it.")
    oil_rough = g.scalar("Oil Roughness", 0.04, 0.0, 0.5)
    oil_coat = g.scalar("Oil Coat", 1.0, 0.0, 1.0, "Clear coat strength of the oil.")
    oil_level = g.scalar("Oil Level", 0.9, 0.0, 1.0, "How far the pool's surface flattens to level.")
    oil_body = g.vector("Oil Body", (0.14, 0.055, 0.008, 1.0), "The oil's own amber.")
    oil_opacity = g.scalar("Oil Opacity", 0.25, 0.0, 1.0, "How much the pool shows its own amber instead of the surface under it. "
                           "0 is clear oil, which on bare chrome is almost invisible.")
    oil_edge = g.scalar("Oil Edge", 0.4, 0.0, 1.0, "Darkening of the line where the pool meets the pan.")

    g.group("06 Oil Pool")
    pool_r = g.scalar("Pool Radius", 2.2, 0.0, 20.0, "Centre puddle radius at Oil Amount 1, cm. About 1.1 x the cube's "
                      "half extent so the puddle stays close to the meat's pool.")
    margin = g.scalar("Pool Margin", 1.2, 0.0, 6.0, "Oil showing around the meat footprint at Oil Amount 1, cm (0.6 x the "
                      "cube's half extent: the pool is just wider than the cube).")
    blend = g.scalar("Pool Blend", 1.0, 0.0, 6.0, "How softly the puddle and the meat's blob merge, cm.")
    edge_soft = g.scalar("Pool Edge Softness", 0.25, 0.02, 2.0)
    wobble = g.scalar("Pool Wobble", 0.3, 0.0, 3.0, "Irregularity of the pool outline, cm.")
    meniscus = g.scalar("Meniscus", 0.6, 0.0, 2.0, "Normal tilt at the pool edge.")

    g.group("07 Oil Drops")
    cols = g.scalar("Drop Columns", 26.0, 3.0, 80.0, "Lanes around the pan the running drops use.")
    row_len = g.scalar("Drop Row Length", 3.5, 0.5, 12.0, "Spacing of drops down a lane, cm.")
    density = g.scalar("Drop Density", 0.5, 0.0, 1.0)
    drop_size = g.scalar("Drop Size", 0.22, 0.02, 1.0, "Drop radius, cm.")
    speed = g.scalar("Drop Speed", 0.8, 0.0, 6.0, "cm per second. Not for runtime driving: changing it shifts every drop.")
    drop_trail = g.scalar("Drop Trail", 1.6, 0.0, 6.0, "Length of the wet streak behind a drop, cm.")
    drop_normal = g.scalar("Drop Normal", 1.2, 0.0, 3.0)

    g.group("08 Oil Beads")
    bead_cell = g.scalar("Bead Cell", 1.1, 0.2, 5.0, "Spacing of the still beads, cm.")
    bead_density = g.scalar("Bead Density", 0.3, 0.0, 1.0)
    bead_size = g.scalar("Bead Size", 0.5, 0.0, 1.0)
    bead_normal = g.scalar("Bead Normal", 1.0, 0.0, 3.0)

    g.group("09 Oil Simmer")
    sim_density = g.scalar("Simmer Density", 0.5, 0.0, 1.0, "Share of the simmer cells alive at Sizzle 1. The whole oil "
                           "film bubbles; Sizzle scales the count and the rate.")
    sim_w = g.scalar("Simmer Width", 0.8, 0.1, 6.0, "Width of the band around the meat that bubbles harder, cm.")
    sim_near = g.scalar("Simmer Near Meat", 0.5, 0.0, 2.0, "Extra bubbling in the band around the meat.")
    sim_cell = g.scalar("Simmer Cell", 0.55, 0.1, 3.0, "Bubble spacing, cm (the largest bead radius is 0.3 x this).")
    sim_rate = g.scalar("Simmer Rate", 2.2, 0.0, 10.0, "Bubble cycles per second at Sizzle 0.5 (Sizzle 1 runs 1.25x).")
    sim_strength = g.scalar("Simmer Strength", 1.4, 0.0, 3.0, "Dome tilt of a bead: where its highlight lands.")
    sim_rim = g.scalar("Simmer Rim Darken", 0.75, 0.0, 1.0, "Dark outline of a bead.")

    g.group("10 Contact")
    contact = g.scalar("Contact Shadow", 0.6, 0.0, 1.0, "Darkening under the meat (stands in for its reflection).")
    contact_soft = g.scalar("Contact Softness", 0.8, 0.0, 6.0)

    x = -1700
    lp, ln = g.local_space(x - 700, -900)
    time = g.expr(unreal.MaterialExpressionTime, x - 440, -560)
    pool = g.custom("PanPool: oil pool, meniscus, simmer", hlsl.PAN_POOL, (
        ("P", lp, ""), ("T", time, ""), ("Meat", meat, "RGBA"), ("Trail", trail, "RGBA"), ("OilAmount", oil, ""),
        ("Sizzle", sizzle, ""), ("BaseR", base_r, ""), ("PoolR", pool_r, ""), ("Margin", margin, ""), ("Blend", blend, ""),
        ("EdgeSoft", edge_soft, ""), ("Wobble", wobble, ""), ("Meniscus", meniscus, ""), ("SimW", sim_w, ""),
        ("SimCell", sim_cell, ""), ("SimRate", sim_rate, ""), ("SimStrength", sim_strength, ""),
        ("SimDensity", sim_density, ""), ("SimNear", sim_near, ""))
        + tuple(("Meat%d" % i, e, "RGBA") for i, e in enumerate(meats, 1))
        + tuple(("Trail%d" % i, e, "RGBA") for i, e in enumerate(trails, 1)), x, -1100, FLOAT3,
        (("Bubble", FLOAT1), ("BubbleRim", FLOAT1)))
    drops = g.custom("PanDrops: running drops + beads", hlsl.PAN_DROPS, (
        ("P", lp, ""), ("N", ln, ""), ("T", time, ""), ("OilAmount", oil, ""), ("BaseR", base_r, ""), ("RimR", rim_r, ""),
        ("Cols", cols, ""), ("RowLen", row_len, ""), ("Density", density, ""), ("Size", drop_size, ""), ("Speed", speed, ""),
        ("Trail", drop_trail, ""), ("BeadCell", bead_cell, ""), ("BeadDensity", bead_density, ""),
        ("BeadSize", bead_size, ""), ("BeadNormal", bead_normal, "")), x, -300, FLOAT3)
    surf = g.custom("PanSurface: metal + seasoning + oil", hlsl.PAN_SURFACE, (
        ("P", lp, ""), ("N", ln, ""), ("Pool", pool, ""), ("Bubble", pool, "Bubble"), ("BubbleRim", pool, "BubbleRim"),
        ("SimRimDark", sim_rim, ""), ("Drops", drops, ""),
        ("MetalColor", metal_col, ""), ("Metallic", metallic, ""), ("Rough", rough, ""), ("RingFreq", ring_freq, ""),
        ("RingStrength", ring_strength, ""), ("Fond", fond, ""), ("Seasoning", seasoning, ""),
        ("SeasonRadius", season_radius, ""), ("SeasonBreakup", season_breakup, ""), ("SeasonBands", season_bands, ""),
        ("SeasonSpecks", season_specks, ""), ("SeasonThin", season_thin, ""), ("SeasonThick", season_thick, ""),
        ("SeasonRough", season_rough, ""), ("SeasonMetal", season_metal, ""),
        ("OilTint", oil_tint, ""), ("OilBody", oil_body, ""), ("OilOpacity", oil_opacity, ""), ("OilEdge", oil_edge, ""), ("OilCoat", oil_coat, ""),
        ("OilLevel", oil_level, ""), ("DropNormal", drop_normal, ""),
        ("Meat", meat, "RGBA"), ("Contact", contact, ""), ("ContactSoft", contact_soft, ""), ("RimR", rim_r, ""))
        + tuple(("Meat%d" % i, e, "RGBA") for i, e in enumerate(meats, 1)),
        x + 600, -800, FLOAT3,
        (("OutRoughness", FLOAT1), ("OutMetallic", FLOAT1), ("OutCoat", FLOAT1), ("OutNormal", FLOAT3)))
    world_n = g.to_world(surf, "OutNormal", x + 1050, -300)
    g.finish({"BaseColor": (surf, ""), "Metallic": (surf, "OutMetallic"), "Roughness": (surf, "OutRoughness"),
              "Normal": (world_n, ""), "ClearCoat": (surf, "OutCoat"), "ClearCoatRoughness": (oil_rough, "")},
             x + 1500, -800)
    return m


# ------------------------------------------------------------------ instances
# (name, folder, parent name, scalars, vectors). Listed values are set on every build; anything else an artist
# overrides in the instance is kept.
INSTANCES = (
    # stylized but believable: broad pale fat, faint branching veins, lean mottling + grain, a wet raw coat
    ("Meat_Wagyu_Mars_MI", F_INST, "Meat_Mars_M",
     {"Fibre Contrast": 0.2, "Normal Raw": 0.2, "Normal Crust": 0.45, "Raw Wetness": 0.45, "Coat Roughness": 0.2,
      "Roughness Lean": 0.46, "Roughness Fat": 0.42, "Crust Breakup": 0.15, "Edge Boost": 0.3,
      "Oil Coat Strength": 0.15, "Glaze Strength": 0.12, "Coat Breakup": 0.6,     # a crust is not a mirror
      "Band Depth": 0.55 * spec.CUBE_HALF_CM, "Band Wobble": 0.125 * spec.CUBE_HALF_CM}, {}),
    ("Pan_Steel_Mars_MI", F_INST, "Pan_Mars_M", {}, {}),
    ("Pan_Handle_Mars_MI", F_INST, "Pan_Mars_M",
     {"Metallic": 0.0, "Roughness": 0.38, "Ring Strength": 0.0, "Seasoning": 0.0},
     {"Metal Color": (0.62, 0.02, 0.02, 1.0)}),
    # lookdev only: the driven values gameplay will set at runtime
    # pool matched to the cube (half extent h = spec.CUBE_HALF_CM): see LOOKDEV_POOL_NOTE
    ("Pan_Steel_LookdevCooking_Mars_MI", F_LOOK, "Pan_Steel_Mars_MI",
     {"Oil Amount": 0.7, "Sizzle": 0.8, "Fond": 0.1, "Seasoning": 0.25, "Carbon Specks": 0.2, "Oil Opacity": 0.7,
      "Pool Radius": round(1.1 * spec.CUBE_HALF_CM, 2), "Pool Margin": round(0.6 * spec.CUBE_HALF_CM, 2),
      "Pool Blend": round(0.5 * spec.CUBE_HALF_CM, 2), "Pool Wobble": 0.5, "Pool Edge Softness": 0.15,
      "Simmer Width": round(0.4 * spec.CUBE_HALF_CM, 2), "Simmer Cell": 0.6, "Simmer Density": 0.85, "Simmer Rim Darken": 0.95,
      "Contact Softness": round(0.4 * spec.CUBE_HALF_CM, 2)},
     {"Meat Footprint": (1.5, -1.0, round(spec.CUBE_FOOTPRINT_CM, 2), 0.0), "Oil Trail": (0.15, -0.2, 0.0, 0.0)}),
    ("Pan_Steel_LookdevOiled_Mars_MI", F_LOOK, "Pan_Steel_Mars_MI",
     {"Oil Amount": 0.6, "Fond": 0.15}, {}),
)


LOOKDEV_POOL_NOTE = ("Pool matched to the meat cube (h = cooking_spec.CUBE_HALF_CM, 2 cm; the hand-authored mesh "
                     "measures 2.2): Meat Footprint radius = mesh half extent * sqrt(2) * 0.9 = 2.8 (gameplay sets it "
                     "the same way), Pool Radius = 1.1 h, Pool Margin = "
                     "0.6 h, Pool Blend / Simmer Width / Contact Softness = 0.5 / 0.4 / 0.4 h. Written by "
                     "mars_cooking_ue.build_instances; the listed values are overwritten on every build.")
DESCRIPTIONS = {"Pan_Steel_LookdevCooking_Mars_MI": LOOKDEV_POOL_NOTE}


def build_instances():
    for name, folder, parent_name, scalars, vectors in INSTANCES:
        parent = _asset(F_MAT, parent_name) or _asset(F_INST, parent_name)
        inst = _asset(folder, name)
        if inst is None:
            inst = _tools().create_asset(name, folder, unreal.MaterialInstanceConstant, unreal.MaterialInstanceConstantFactoryNew())
        MEL.set_material_instance_parent(inst, parent)
        for k, v in scalars.items():
            MEL.set_material_instance_scalar_parameter_value(inst, k, float(v))
        for k, v in vectors.items():
            MEL.set_material_instance_vector_parameter_value(inst, k, unreal.LinearColor(*v))
        if name in DESCRIPTIONS:
            EAL.set_metadata_tag(inst, "Description", DESCRIPTIONS[name])
        MEL.update_material_instance(inst)
        EAL.save_loaded_asset(inst)
    _drop_retired()
    _log("%d material instances" % len(INSTANCES))


MASTERS = ("Meat_Mars_M", "Pan_Mars_M")


def _release_masters():
    """A rebuild replaces the masters, and replacing one that the open level is drawing asserts in the renderer
    (UniformExpressionCache should be up to date; it took the editor down on 2026-10-06). So nothing in the open
    level may use them: the lookdev map is swapped for a blank map, any other map is refused."""
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    if world is None:
        return
    users = set()
    for actor in unreal.get_editor_subsystem(unreal.EditorActorSubsystem).get_all_level_actors():
        for comp in actor.get_components_by_class(unreal.MeshComponent):
            for mat in comp.get_materials():
                base = mat.get_base_material() if mat is not None else None
                if base is not None and base.get_name().replace("_retired", "") in MASTERS:
                    users.add(actor.get_actor_label())
    if not users:
        return
    current = world.get_outermost().get_name()
    if current != spec.UE_LOOKDEV_MAP:
        raise RuntimeError("%s draws the cooking masters (%s); open another map before rebuilding them"
                           % (current, ", ".join(sorted(users)[:5])))
    unreal.EditorLoadingAndSavingUtils.new_blank_map(False)
    unreal.SystemLibrary.collect_garbage()


def build_materials(export_dir=None, refresh_curves=False):
    if _in_pie():
        raise RuntimeError("stop PIE before rebuilding the cooking materials")
    _release_masters()
    atlas, curves = build_curves(export_dir, refresh_curves)
    meat = build_meat_master(atlas, curves)
    pan = build_pan_master()
    build_instances()
    assign_mesh_materials()
    for m in (meat, pan):
        _log("%s: %d expressions" % (m.get_name(), MEL.get_num_material_expressions(m)))
    return meat, pan


# ------------------------------------------------------------------ lookdev map
def _try(obj, prop, value):
    try:
        obj.set_editor_property(prop, value)
    except Exception as exc:
        _warn("%s.%s: %s" % (type(obj).__name__, prop, exc))


def _spawn(obj_or_class, loc, rot=(0.0, 0.0, 0.0), label=None, folder="Cooking"):
    eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    rotator = unreal.Rotator(roll=rot[0], pitch=rot[1], yaw=rot[2])
    if isinstance(obj_or_class, type):
        a = eas.spawn_actor_from_class(obj_or_class, unreal.Vector(*loc), rotator)
    else:
        a = eas.spawn_actor_from_object(obj_or_class, unreal.Vector(*loc), rotator)
    if label:
        a.set_actor_label(label)
    a.set_folder_path(folder)
    return a


# label, x offset, (Sear XY), (Sear Z + Cook), (Finish)
CUBE_STATES = (
    ("Raw", -16, (0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0)),
    ("FirstSide", -8, (0, 0, 0, 0), (0, 0.9, 1, 0.5), (0, 0.15, 0, 0)),
    ("Flipped", 0, (0.15, 0.1, 0.2, 0.1), (1.0, 0.7, 1, 0.7), (0, 0.5, 0, 0)),
    ("Plated", 8, (1.0, 0.9, 1.05, 0.95), (1.1, 1.0, 1, 0.3), (1, 1, 0, 0)),
    ("Burnt", 16, (1.5, 1.2, 1.7, 1.3), (2.0, 1.6, 1, 0.2), (0.3, 1, 0, 0)),
)                       # x offsets 8 cm apart: two cube widths of gap for the 4 cm cube
PAN_Z = 0.4            # the pan's pivot is its cooking surface; this rests the underside on the counter


def _set_cpd(actor, sear_xy, sear_z, finish):
    comp = actor.get_component_by_class(unreal.StaticMeshComponent)
    comp.set_default_custom_primitive_data_vector4(0, unreal.Vector4(*sear_xy))
    comp.set_default_custom_primitive_data_vector4(4, unreal.Vector4(*sear_z))
    comp.set_default_custom_primitive_data_vector4(8, unreal.Vector4(*finish))


def _attach_pan_fx():
    """The pan's Niagara oil bubbles + splatter, attached to Meat_InPan by the food library. Optional: if
    mars_food_ue does not import (or its Niagara systems are missing) the map is built without them."""
    try:
        import mars_food_ue as mf                    # lazy: the food module imports this one
    except Exception as exc:
        _warn("pan FX skipped, mars_food_ue did not import: %s" % exc)
        return []
    try:
        return mf.attach_pan_bubbles(actor_label="Meat_InPan", outer_cm=3.5, rate=25, oil_lift_cm=0.1, splatter=True)
    except Exception as exc:
        _warn("pan FX skipped: %s" % exc)
        return []


def build_lookdev_map(stay=False):
    """Two pans (one mid-cook with a cube and its Niagara oil bubbles / splatter, one just oiled), a row of cubes
    from raw to burnt, and the studio lighting / reflection the look is tuned under. Rebuilt from scratch on every
    call (every actor is replaced, the pan FX included); returns to the map that was open unless stay is set."""
    if _in_pie():
        raise RuntimeError("stop PIE before building the lookdev map")
    les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    current = world.get_outermost().get_name() if world else None
    dirty_maps = [p.get_name() for p in unreal.EditorLoadingAndSavingUtils.get_dirty_map_packages()]
    if current in dirty_maps:
        raise RuntimeError("%s has unsaved changes; save it before building the lookdev map" % current)
    if EAL.does_asset_exist(spec.UE_LOOKDEV_MAP):
        les.load_level(spec.UE_LOOKDEV_MAP)
        eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
        eas.destroy_actors([a for a in eas.get_all_level_actors() if not isinstance(a, (unreal.WorldSettings, unreal.Brush))])
    else:
        les.new_level(spec.UE_LOOKDEV_MAP)

    cube = _asset(F_MESH, "MeatCube_Mars_SM")
    pan = _asset(F_MESH, "FryPan_Mars_SM")
    hdr = _asset(F_TEX, "CookingStudio_Mars_HDR")
    handle = _asset(F_INST, "Pan_Handle_Mars_MI")

    # counter
    counter_mi = _asset(F_LOOK, "LookdevCounter_Mars_MI")
    if counter_mi is None:
        counter_mi = _tools().create_asset("LookdevCounter_Mars_MI", F_LOOK, unreal.MaterialInstanceConstant,
                                           unreal.MaterialInstanceConstantFactoryNew())
        MEL.set_material_instance_parent(counter_mi, _load("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial"))
    MEL.set_material_instance_vector_parameter_value(counter_mi, "Color", unreal.LinearColor(0.20, 0.09, 0.035, 1.0))
    MEL.update_material_instance(counter_mi)
    EAL.save_loaded_asset(counter_mi)
    counter = _spawn(_load("/Engine/BasicShapes/Plane.Plane"), (0, 0, 0), label="Counter")
    counter.set_actor_scale3d(unreal.Vector(6, 6, 1))
    counter.get_component_by_class(unreal.StaticMeshComponent).set_material(0, counter_mi)

    # the pan mid-cook: handle toward the camera (+Y)
    cook = _spawn(pan, (0, 0, PAN_Z), (0, 0, 90), "Pan_Cooking")
    comp = cook.get_component_by_class(unreal.StaticMeshComponent)
    comp.set_material(0, _asset(F_LOOK, "Pan_Steel_LookdevCooking_Mars_MI"))
    comp.set_material(1, handle)
    # the cube sits where the instance's Meat Footprint says (pan-local 1.5, -1.0; the pan is yawed 90)
    meat = _spawn(cube, (1.0, 1.5, PAN_Z + spec.CUBE_MESH_HALF_CM), (0, 0, 20), "Meat_InPan")
    _set_cpd(meat, (0.05, 0.05, 0.05, 0.05), (0.0, 1.0, 1.0, 0.8), (0, 0.3, 0, 0))
    _attach_pan_fx()

    oiled = _spawn(pan, (48, 0, PAN_Z), (0, 0, 90), "Pan_Oiled")
    comp = oiled.get_component_by_class(unreal.StaticMeshComponent)
    comp.set_material(0, _asset(F_LOOK, "Pan_Steel_LookdevOiled_Mars_MI"))
    comp.set_material(1, handle)

    for label, x, sear_xy, sear_z, finish in CUBE_STATES:
        a = _spawn(cube, (x, -34, spec.CUBE_MESH_HALF_CM), (0, 0, 25), "Meat_%s" % label)
        _set_cpd(a, sear_xy, sear_z, finish)

    # lighting: a warm key through the "window", the studio map for reflections and ambient
    key = _spawn(unreal.DirectionalLight, (0, 0, 300), (0, -55, -115), "Key", "Cooking/Rig")
    kc = key.get_component_by_class(unreal.DirectionalLightComponent)
    _try(kc, "intensity", 4.0)
    _try(kc, "light_color", unreal.Color(r=255, g=232, b=200, a=255))
    _try(kc, "light_source_angle", 3.0)
    fill = _spawn(unreal.DirectionalLight, (0, 0, 300), (0, -30, 60), "Fill", "Cooking/Rig")
    fc = fill.get_component_by_class(unreal.DirectionalLightComponent)
    _try(fc, "intensity", 1.2)
    _try(fc, "light_color", unreal.Color(r=255, g=214, b=190, a=255))
    _try(fc, "cast_shadows", False)
    sky = _spawn(unreal.SkyLight, (0, 0, 200), label="StudioAmbient", folder="Cooking/Rig")
    sc = sky.get_component_by_class(unreal.SkyLightComponent)
    _try(sc, "source_type", unreal.SkyLightSourceType.SLS_SPECIFIED_CUBEMAP)
    _try(sc, "cubemap", hdr)
    _try(sc, "intensity", 0.4)
    _try(sc, "real_time_capture", False)
    cap = _spawn(unreal.SphereReflectionCapture, (20, 10, 14), label="StudioReflection", folder="Cooking/Rig")
    cc = cap.get_component_by_class(unreal.SphereReflectionCaptureComponent)
    _try(cc, "reflection_source_type", unreal.ReflectionSourceType.SPECIFIED_CUBEMAP)
    _try(cc, "cubemap", hdr)
    _try(cc, "influence_radius", 400.0)
    ppv = _spawn(unreal.PostProcessVolume, (0, 0, 0), label="Grade", folder="Cooking/Rig")
    _try(ppv, "unbound", True)
    s = ppv.get_editor_property("settings")
    for k, v in (("override_auto_exposure_method", True), ("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL),
                 ("override_auto_exposure_bias", True), ("auto_exposure_bias", EXPOSURE_BIAS),
                 ("override_bloom_intensity", True), ("bloom_intensity", 0.6)):
        _try(s, k, v)
    ppv.set_editor_property("settings", s)

    les.save_current_level()
    if current and current != spec.UE_LOOKDEV_MAP and not stay:
        les.load_level(current)
    _log("lookdev map built: %s" % spec.UE_LOOKDEV_MAP)


EXPOSURE_BIAS = 0.2

# name -> (eye, target, fov) in the lookdev map
SHOTS = {
    "pan_cooking": ((0, 26, 44), (0, -1, 1), 42),
    "pan_cooking_close": ((6.5, 13, 15), (1, 1.5, 1.5), 34),
    "pan_oiled": ((48, 26, 44), (48, -1, 1), 42),
    "cubes": ((0, -16, 19), (0, -34, 1), 78),
    "cube_plated": ((-8, -28, 11), (8, -34, 2), 30),         # >= 15 cm out: the near clip plane is 10 cm
}


def capture(out_dir, shots=None, size=(1600, 1000), source=None, suffix=""):
    """Renders the named SHOTS of the map that is open (the lookdev map) to <out_dir>/<shot>.png through a temporary
    SceneCapture2D (high-res screenshots need a visible viewport)."""
    import math
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    # a capture has no streaming history, so textures would come in at a low mip; session cvar, never saved
    unreal.SystemLibrary.execute_console_command(world, "r.TextureStreaming 0")
    os.makedirs(out_dir, exist_ok=True)
    rt = unreal.RenderingLibrary.create_render_target2d(world, size[0], size[1], unreal.TextureRenderTargetFormat.RTF_RGBA8)
    actor = unreal.get_editor_subsystem(unreal.EditorActorSubsystem).spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(0, 0, 0))
    try:
        comp = actor.get_component_by_class(unreal.SceneCaptureComponent2D)
        comp.set_editor_property("texture_target", rt)
        comp.set_editor_property("capture_source", source or unreal.SceneCaptureSource.SCS_FINAL_COLOR_LDR)
        comp.set_editor_property("capture_every_frame", False)
        comp.set_editor_property("capture_on_movement", False)
        for name in (shots or SHOTS):
            eye, target, fov = SHOTS[name]
            d = [t - e for e, t in zip(eye, target)]
            yaw = math.degrees(math.atan2(d[1], d[0]))
            pitch = math.degrees(math.atan2(d[2], math.hypot(d[0], d[1])))
            actor.set_actor_location_and_rotation(unreal.Vector(*eye), unreal.Rotator(roll=0.0, pitch=pitch, yaw=yaw), False, False)
            comp.set_editor_property("fov_angle", float(fov))
            comp.capture_scene()
            unreal.RenderingLibrary.export_render_target(world, rt, out_dir, name + suffix + ".png")
    finally:
        actor.destroy_actor()
    _log("captured %s -> %s" % (list(shots or SHOTS), out_dir))


def run_all(export_dir=None):
    import_textures(export_dir)
    import_meshes(export_dir)
    build_materials(export_dir)
    build_lookdev_map()
