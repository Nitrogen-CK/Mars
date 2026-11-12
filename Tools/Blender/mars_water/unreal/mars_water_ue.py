"""Editor side of the Mars drips / puddles / wet-surface system (Tools/Environment/DRIPS_PLAN.md §2.3, §5): the three card
meshes (duplicates of the engine Plane), Water_Mars_PhysMat, the seven masters (built IN PLACE: instances and placed
actors keep their references) and their instances, plus the checks.

Driven from outside the editor (plain Python 3) through env_drive.py and a hidden editor of its own:

    python Tools/Blender/mars_environment/unreal/env_drive.py --port 9318 --launch
    python Tools/Blender/mars_environment/unreal/env_drive.py --port 9318 --module mars_water_ue --alias mw ^
        --call "mw.run_all()"
    (env_drive imports from its own folder; the call below puts this folder on the path first)

or inside the editor:

    import sys, importlib
    sys.path.insert(0, r"D:\\Repo\\Mars\\Tools\\Blender\\mars_water\\unreal")
    import mars_water_ue as mw; importlib.reload(mw)
    mw.run_all()             # build_meshes, build_physmat, build_masters, build_instances, verify_materials

The masters are generated: tune looks in the instances (a rebuild keeps their overrides), or edit the HLSL in
Shaders/Water/*.ush and run `recompileshaders changed` (no graph rebuild needed for a pure HLSL change).
"""
import importlib
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
WATER_DIR = os.path.dirname(HERE)
COOKING_UE = os.path.join(os.path.dirname(WATER_DIR), "mars_cooking", "unreal")
for _p in (HERE, WATER_DIR, COOKING_UE, os.path.dirname(COOKING_UE)):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import water_spec as spec  # noqa: E402
import mars_cooking_ue as mc  # noqa: E402

importlib.reload(spec)

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary
F1 = unreal.CustomMaterialOutputType.CMOT_FLOAT1
F2 = unreal.CustomMaterialOutputType.CMOT_FLOAT2
F3 = unreal.CustomMaterialOutputType.CMOT_FLOAT3
F4 = unreal.CustomMaterialOutputType.CMOT_FLOAT4
MP = unreal.MaterialProperty
DEBUG = 0          # > 0 builds the masters with MARS_WET_DEBUG (see MarsWet.ush); never save a debug build for real use


def _log(msg):
    unreal.log("MarsWater: %s" % msg)


def _warn(msg):
    unreal.log_warning("MarsWater: %s" % msg)


# ------------------------------------------------------------------ meshes and phys mat
def build_meshes():
    """DropletCard / WetDecalCard / StillWater: duplicates of /Engine/BasicShapes/Plane (100 x 100 cm in XY, one UV
    channel 0..1), collision removed, bounds extended so the shader-moved cards are never culled."""
    sme = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
    plane = EAL.load_asset(spec.PLANE)
    assert plane is not None, "the engine Plane is missing"
    assert sme.get_num_uv_channels(plane, 0) == 1, "the Plane should have exactly one UV channel"
    ext = plane.get_bounds().box_extent
    assert abs(ext.x - 50.0) < 0.5 and abs(ext.y - 50.0) < 0.5, "the Plane should be 100 x 100 cm (got %s)" % ext
    report = {}
    for name, (pos, neg) in spec.MESHES.items():
        path = "%s/%s" % (spec.F_MESH, name)
        mesh = mc._asset(spec.F_MESH, name)
        if mesh is None:
            mesh = EAL.duplicate_asset(spec.PLANE, path)
        sme.remove_collisions(mesh)
        mesh.set_editor_property("positive_bounds_extension", unreal.Vector(*pos))
        mesh.set_editor_property("negative_bounds_extension", unreal.Vector(*neg))
        try:
            ns = mesh.get_editor_property("nanite_settings")
            ns.set_editor_property("enabled", False)
            mesh.set_editor_property("nanite_settings", ns)
        except Exception:
            pass
        EAL.save_loaded_asset(mesh)
        report[name] = {"bounds": str(mesh.get_bounds().box_extent), "uv": sme.get_num_uv_channels(mesh, 0)}
    _log("meshes %s" % report)
    return report


def build_physmat():
    """Water_Mars_PhysMat: a duplicate of Mud_Mars_PhysMat (water footsteps, the drip down-trace's water classifier)."""
    obj = mc._asset(spec.PHYSMAT_FOLDER, spec.PHYSMAT)
    if obj is None:
        obj = EAL.duplicate_asset(spec.PHYSMAT_SOURCE, "%s/%s" % (spec.PHYSMAT_FOLDER, spec.PHYSMAT))
        EAL.save_loaded_asset(obj)
    return obj.get_path_name()


# ------------------------------------------------------------------ graph helpers
class _G(mc._Graph):
    """mars_cooking_ue._Graph plus the water helpers (PICD with a CPD fallback, packing, the shared time)."""

    def __init__(self, material, x0=-3200, y0=-1600):
        super().__init__(material, x0, y0)
        self.nx, self.ny = -1400, -1200

    def at(self, dy=140):
        self.ny += dy
        return self.nx, self.ny

    def const3(self, v):
        c = self.expr(unreal.MaterialExpressionConstant3Vector, *self.at())
        c.set_editor_property("constant", unreal.LinearColor(v[0], v[1], v[2], 1.0))
        return c

    def picd(self, index, cpd):
        """PerInstanceCustomData index -> its DefaultValue is the CPD scalar (plain components and the parameter
        default use that)."""
        p = self.expr(unreal.MaterialExpressionPerInstanceCustomData, *self.at())
        p.set_editor_property("data_index", index)
        self.link(cpd, "", p, "DefaultValue")
        return p

    def pack(self, title, nodes, out=F4):
        names = ("A", "B", "C", "D")
        code = "return float%d(%s);" % (len(nodes), ", ".join(names[:len(nodes)])) if len(nodes) > 1 else "return A;"
        return self.custom(title, code, [(names[i], n, o) for i, (n, o) in enumerate(nodes)], *self.at(), out=out)

    def time(self, debug):
        t = self.expr(unreal.MaterialExpressionTime, *self.at())
        t.set_editor_property("override_period", True)
        t.set_editor_property("period", spec.CONSTANTS["MARS_DRIP_WRAP"])
        assert t.get_editor_property("override_period") and abs(t.get_editor_property("period") - 3600.0) < 1e-3
        return self.custom("Drip Time", "return DebugTime >= 0 ? DebugTime : Time;",
                           [("DebugTime", debug, ""), ("Time", t, "")], *self.at(), out=F1)

    def wet(self, title, code, inputs, out=F1, extra=(), include=None):
        cu = self.custom(title, code, inputs, *self.at(220), out=out, extra=extra)
        cu.set_editor_property("include_file_paths", [include or spec.WET_INCLUDE])
        if DEBUG:
            d = unreal.CustomDefine()
            d.set_editor_property("define_name", "MARS_WET_DEBUG")
            d.set_editor_property("define_value", str(DEBUG))
            cu.set_editor_property("additional_defines", [d])
        return cu

    def vi(self, src, out):
        v = self.expr(unreal.MaterialExpressionVertexInterpolator, *self.at())
        self.link(src, out, v, "VS")
        return v

    def world_pos(self):
        wp = self.expr(unreal.MaterialExpressionWorldPosition, *self.at())
        wp.set_editor_property("world_position_shader_offset",
                               unreal.WorldPositionIncludedOffsets.WPT_EXCLUDE_ALL_SHADER_OFFSETS)
        return wp

    def local_to_world_pos(self, v):
        tp = self.expr(unreal.MaterialExpressionTransformPosition, *self.at())
        tp.set_editor_property("transform_source_type", unreal.MaterialPositionTransformSource.TRANSFORMPOSSOURCE_LOCAL)
        tp.set_editor_property("transform_type", unreal.MaterialPositionTransformSource.TRANSFORMPOSSOURCE_WORLD)
        self.link(self.const3(v), "", tp, "")
        return tp

    def local_to_world_vec(self, v):
        t = self.expr(unreal.MaterialExpressionTransform, *self.at())
        t.set_editor_property("transform_source_type", unreal.MaterialVectorCoordTransformSource.TRANSFORMSOURCE_LOCAL)
        t.set_editor_property("transform_type", unreal.MaterialVectorCoordTransform.TRANSFORM_WORLD)
        self.link(self.const3(v), "", t, "")
        return t

    def view(self, prop):
        v = self.expr(unreal.MaterialExpressionViewProperty, *self.at())
        v.set_editor_property("property", prop)
        return v

    def node(self, cls):
        return self.expr(cls, *self.at())

    def out(self, node, out_name, prop):
        if not MEL.connect_material_property(node, out_name, prop):
            _warn("%s: could not connect %s.%s -> %s" % (self.m.get_name(), node.get_name(), out_name, prop))

    def cpd_scalars(self, group, names, defaults):
        self.group(group)
        nodes = []
        for i, (n, d) in enumerate(zip(names, defaults)):
            e = self.scalar("%s (CPD %d)" % (n, i), d, -10000.0, 10000.0,
                            "Custom primitive data %d: the value a plain component (no instances) uses." % i)
            e.set_editor_property("use_custom_primitive_data", True)
            e.set_editor_property("primitive_data_index", i)
            nodes.append(e)
        return nodes


def _split_camel(text):
    words, cur = [], ""
    for ch in text:
        if ch.isupper() and cur and not cur[-1].isupper():
            words.append(cur)
            cur = ch
        else:
            cur += ch
    return words + [cur]


def _master(name):
    """The master at F_MAT, emptied IN PLACE if it exists (delete_all_material_expressions skips nodes: loop to 0).
    Replacing a live master asserts in the renderer; emptying it keeps every reference."""
    m = mc._asset(spec.F_MAT, name)
    if m is None:
        return mc._tools().create_asset(name, spec.F_MAT, unreal.Material, unreal.MaterialFactoryNew())
    for _ in range(8):
        if MEL.get_num_material_expressions(m) == 0:
            break
        MEL.delete_all_material_expressions(m)
    return m


def _scratch(name):
    path = "/Game/WaterScratch/" + name
    if EAL.does_asset_exist(path):
        m = EAL.load_asset(path)
        for _ in range(8):
            if MEL.get_num_material_expressions(m) == 0:
                break
            MEL.delete_all_material_expressions(m)
        return m
    return mc._tools().create_asset(name, "/Game/WaterScratch", unreal.Material, unreal.MaterialFactoryNew())


def _props(m, **kw):
    for k, v in kw.items():
        m.set_editor_property(k, v)


def _finish(g):
    MEL.layout_material_expressions(g.m) if hasattr(MEL, "layout_material_expressions") else None
    MEL.recompile_material(g.m)
    EAL.save_loaded_asset(g.m)
    st = MEL.get_statistics(g.m)
    return {"vs": st.num_vertex_shader_instructions, "ps": st.num_pixel_shader_instructions}


# ------------------------------------------------------------------ Droplet_Mars_M (§3.3, §3.4, §5.1)
def build_droplet(variant=()):
    """variant: debug toggles for a scratch copy (/Game/WaterScratch/DropTest_M): 'nowpo', 'noscene', 'novi'."""
    if variant:
        m = _scratch("DropTest_M")
    else:
        m = _master("Droplet_Mars_M")
    _props(m, material_domain=unreal.MaterialDomain.MD_SURFACE, blend_mode=unreal.BlendMode.BLEND_TRANSLUCENT,
           shading_model=unreal.MaterialShadingModel.MSM_DEFAULT_LIT,
           translucency_lighting_mode=unreal.TranslucencyLightingMode.TLM_SURFACE_PER_PIXEL_LIGHTING,
           two_sided=True, used_with_instanced_static_meshes=True, tangent_space_normal=False,
           translucency_pass=unreal.MaterialTranslucencyPass.MTP_AFTER_DOF, compute_fog_per_pixel=True,
           output_translucent_velocity=False)
    g = _G(m)
    cpd = g.cpd_scalars("Custom Primitive Data", spec.CARD_DATA, (100.0, 0.8, 0.0, 0.6, 0.0, 0.0, 1.0, 0.0))
    g.group("Shape")
    radius = g.scalar("DropRadiusCm", spec.DROP_RADIUS_CM, 0.1, 2.0, "Drop radius (cm) before the per-instance DropScale.")
    tear = g.scalar("TearK", 1.6, 0.0, 4.0, "How much a fast drop stretches into a teardrop.")
    shutter = g.scalar("Shutter", 0.011, 0.0, 0.05, "Motion-streak seconds (speed x Shutter adds to the streak length).")
    minpx = g.scalar("MinPixels", 2.0, 0.5, 4.0, "Cards never shrink below this many pixels (alpha keeps the energy).")
    thread_w = g.scalar("ThreadWidthCm", 0.16, 0.02, 1.0, "Pipe-joint thread / stream half width at the source (cm).")
    thread_b = g.scalar("ThreadBreakCm", 14.0, 1.0, 100.0, "A stream breaks into beads this far below its source (cm).")
    g.group("Look")
    body = g.vector("BodyTint", (0.02, 0.025, 0.03, 1.0), "Lit base colour of the water body.")
    tint = g.vector("WaterTint", (0.92, 0.96, 1.0, 1.0), "Tint of the refracted scene through the drop.")
    trans = g.scalar("Transmission", 0.85, 0.0, 1.0, "How much of the refracted scene comes through.")
    refract_px = g.scalar("RefractPx", 6.0, 0.0, 30.0, "Inverted-lens refraction offset in pixels at the drop rim.")
    rough = g.scalar("Roughness", 0.12, 0.0, 1.0, "0.05-0.15: lower = sharper but rarer torch glints on 1-3 px drops.")
    spec_ = g.scalar("Specular", 0.5, 0.0, 1.0, "Stylised sparkle (water is 0.25).")
    sparkle = g.vector("SparkleTint", (0.75, 0.85, 1.0, 1.0), "Display-referred rim on every drop (reads in any room).")
    sparkle_k = g.scalar("SparkleStrength", 0.15, 0.0, 2.0, "Screen brightness of the thin edge rim (exposure-independent).")
    op_scale = g.scalar("OpacityScale", 0.8, 0.0, 2.0, "Below 1 the drop reads as clear water over the refracted scene.")
    g.group("Distance")
    fade0 = g.scalar("FadeStartCm", 2500.0, 0.0, 10000.0)
    fade1 = g.scalar("FadeEndCm", 3500.0, 0.0, 10000.0, "Cards collapse beyond this camera distance.")
    g.group("Debug")
    debug = g.scalar("DebugTime", -1.0, -1.0, 3600.0, ">= 0 freezes the drip clock at this time (frozen-time captures).")
    g.group("Switches")
    use_refr = g._param(unreal.MaterialExpressionStaticSwitchParameter, 160, "UseSceneRefraction",
                        "On: the drop shows the refracted scene (one scene-colour copy per frame). Off: a body gradient.")
    use_refr.set_editor_property("default_value", True)

    T = g.time(debug)
    picd = [g.picd(i, cpd[i]) for i in range(8)]
    d0 = g.pack("D0 Length Rate Seed Jitter", [(p, "") for p in picd[0:4]])
    d1 = g.pack("D1 Mode Slot DropScale Surface", [(p, "") for p in picd[4:8]])
    shape = g.pack("Shape", [(radius, ""), (tear, ""), (shutter, ""), (minpx, "")])
    thread = g.pack("Thread", [(thread_w, ""), (thread_b, ""), (fade0, ""), (fade1, "")])
    tan = g.view(unreal.MaterialExposedViewProperty.MEVP_TAN_HALF_FIELD_OF_VIEW)
    size = g.view(unreal.MaterialExposedViewProperty.MEVP_VIEW_SIZE)
    view2 = g.custom("View2", "return float2(Tan.y, Size.y);", [("Tan", tan, ""), ("Size", size, "")], *g.at(), out=F2)
    view4 = g.custom("View4", "return float4(Tan.y, Size.y, 1.0 / max(Size.x, 1.0), 1.0 / max(Size.y, 1.0));",
                     [("Tan", tan, ""), ("Size", size, "")], *g.at(), out=F4)
    origin = g.local_to_world_pos((0.0, 0.0, 0.0))
    up = g.local_to_world_vec((0.0, 0.0, 1.0))
    cam = g.node(unreal.MaterialExpressionCameraPositionWS)
    wp = g.world_pos()
    uv = g.node(unreal.MaterialExpressionTextureCoordinate)

    g.nx, g.ny = -400, -1200
    vs = g.wet("DropVS", "return MarsWet_DropVS(D0, D1, T, UV, Origin, Up, Cam, WP, Shape, Thread, View, I0, I1);",
               [("D0", d0, ""), ("D1", d1, ""), ("T", T, ""), ("UV", uv, ""), ("Origin", origin, ""), ("Up", up, ""),
                ("Cam", cam, ""), ("WP", wp, ""), ("Shape", shape, ""), ("Thread", thread, ""), ("View", view2, "")],
               out=F3, extra=(("I0", F4), ("I1", F4)))
    # The interpolated I0 / I1 come from their own calls of MarsWet_DropVS (a Custom node's extra output fed into a
    # VertexInterpolator reaches the pixel shader as zeros in 5.7): same inputs, same result, the compiler shares the work.
    vs_ins = [("D0", d0, ""), ("D1", d1, ""), ("T", T, ""), ("UV", uv, ""), ("Origin", origin, ""), ("Up", up, ""),
              ("Cam", cam, ""), ("WP", wp, ""), ("Shape", shape, ""), ("Thread", thread, ""), ("View", view2, "")]
    call = "float4 I0, I1; MarsWet_DropVS(D0, D1, T, UV, Origin, Up, Cam, WP, Shape, Thread, View, I0, I1); return %s;"
    vs0 = g.wet("DropVS I0", call % "I0", vs_ins, out=F4)
    vs1 = g.wet("DropVS I1", call % "I1", vs_ins, out=F4)
    vi0 = g.vi(vs0, "")
    vi1 = g.vi(vs1, "")
    look = g.pack("Look", [(refract_px, ""), (trans, ""), (op_scale, ""), (trans, "")])
    g.nx, g.ny = 200, -1200
    if "novi" in variant:
        vi0 = g.pack("I0 const", [(radius, ""), (radius, ""), (radius, ""), (op_scale, "")])
        vi1 = g.pack("I1 const", [(op_scale, ""), (op_scale, ""), (op_scale, ""), (op_scale, "")])
    ps = g.wet("DropPS", "return MarsWet_DropPS(I0, I1, UV, T, Cam, WP, View, Look, NormalWS, Refract, Body);",
               [("I0", vi0, "PS" if "novi" not in variant else ""), ("I1", vi1, "PS" if "novi" not in variant else ""), ("UV", uv, ""), ("T", T, ""), ("Cam", cam, ""), ("WP", wp, ""),
                ("View", view4, ""), ("Look", look, "")],
               out=F1, extra=(("NormalWS", F3), ("Refract", F2), ("Body", F1)))
    scene = g.node(unreal.MaterialExpressionSceneColor)
    scene.set_editor_property("input_mode", unreal.MaterialSceneAttributeInputMode.OFFSET_FRACTION)
    if not MEL.connect_material_expressions(ps, "Refract", scene, "OffsetFraction"):
        g.link(ps, "Refract", scene, "")
    refr = g.custom("Refracted", "return Scene.rgb * Transmission * WaterTint.rgb;",
                    [("Scene", scene, ""), ("Transmission", trans, ""), ("WaterTint", tint, "")], *g.at(), out=F3)
    flat = g.custom("Body Gradient", "return lerp(0.15, 1.0, Body) * WaterTint.rgb * 0.02;",
                    [("Body", ps, "Body"), ("WaterTint", tint, "")], *g.at(), out=F3)
    g.link(refr, "", use_refr, "True")
    g.link(flat, "", use_refr, "False")
    rim = g.custom("Sparkle Rim", "float R = saturate((1.0 - Body) / 0.65); R *= R; return Tint.rgb * Strength * R * R;",
                   [("Body", ps, "Body"), ("Tint", sparkle, ""), ("Strength", sparkle_k, "")], *g.at(), out=F3)
    eye = g.node(unreal.MaterialExpressionEyeAdaptationInverse)
    if not any(MEL.connect_material_expressions(rim, "", eye, n) for n in ("LightValue", "LightValueInput", "Light Value")):
        _warn("Droplet_Mars_M: could not connect the sparkle rim to EyeAdaptationInverse")
    emissive = g.custom("Emissive", "return Base + Rim;", [("Base", use_refr, ""), ("Rim", eye, "")], *g.at(), out=F3)

    if "nowpo" not in variant:
        g.out(vs, "", MP.MP_WORLD_POSITION_OFFSET)
    g.out(body, "", MP.MP_BASE_COLOR)
    g.out(flat if "noscene" in variant else emissive, "", MP.MP_EMISSIVE_COLOR)
    g.out(ps, "NormalWS", MP.MP_NORMAL)
    g.out(rough, "", MP.MP_ROUGHNESS)
    g.out(spec_, "", MP.MP_SPECULAR)
    g.out(ps, "", MP.MP_OPACITY)
    return _finish(g)


# ------------------------------------------------------------------ mesh decals: rings and puddles
def _decal_master(name):
    m = _master(name)
    _props(m, material_domain=unreal.MaterialDomain.MD_DEFERRED_DECAL, blend_mode=unreal.BlendMode.BLEND_TRANSLUCENT,
           used_with_instanced_static_meshes=True)
    return m


def _decal_vs(g, n, cpd_names, defaults):
    """PICD 0..n-1 read in the vertex stage, plus the instance's world scale (cm per UV unit) and origin: three
    interpolators A = PICD 0..3, B = (PICD 4, PICD 5, ScaleX, ScaleY)."""
    cpd = g.cpd_scalars("Custom Primitive Data", cpd_names, defaults)
    picd = [g.picd(i, cpd[i]) for i in range(n)]
    ax = g.local_to_world_vec((100.0, 0.0, 0.0))
    ay = g.local_to_world_vec((0.0, 100.0, 0.0))
    a = g.pack("A", [(p, "") for p in picd[0:4]])
    rest = [(p, "") for p in picd[4:6]]
    while len(rest) < 2:
        rest.append((cpd[0], ""))
    b = g.custom("B", "return float4(E, F, length(AX), length(AY));",
                 [("E", rest[0][0], ""), ("F", rest[1][0], ""), ("AX", ax, ""), ("AY", ay, "")], *g.at(), out=F4)
    return g.vi(a, ""), g.vi(b, "")


def build_impact():
    m = _decal_master("DripImpact_Mars_M")
    g = _G(m)
    via, vib = _decal_vs(g, 6, spec.RING_DATA, (100.0, 0.8, 0.0, 0.6, 0.0, 1.0))
    g.group("Rings")
    width = g.scalar("RingWidthCm", 1.2, 0.1, 5.0)
    decay = g.scalar("Decay", 0.8, 0.05, 3.0, "Ring amplitude e-folding time (s).")
    gain = g.scalar("RingAlphaGain", 0.6, 0.0, 4.0, "Opacity per unit slope (rings only show where the water moves).")
    dimple = g.scalar("Dimple", 0.4, 0.0, 2.0, "The crater the drop punches for the first 0.12 s.")
    radius = g.scalar("DropRadiusCm", spec.DROP_RADIUS_CM, 0.1, 2.0, "Must match the drop material (same clock).")
    rough = g.scalar("Roughness", 0.03, 0.0, 1.0)
    spec_ = g.scalar("Specular", 0.3, 0.0, 1.0)
    g.group("Debug")
    debug = g.scalar("DebugTime", -1.0, -1.0, 3600.0)
    T = g.time(debug)
    uv = g.node(unreal.MaterialExpressionTextureCoordinate)
    ring = g.pack("Ring", [(width, ""), (decay, ""), (gain, ""), (dimple, "")])
    g.nx, g.ny = 200, -1200
    ps = g.wet("Rings", "float2 P = (UV - 0.5) * B.zw * float2(1, -1);\n"
                        "return MarsWet_ImpactRings(A, B.xy, P, T, Ring, Radius, Normal);",
               [("A", via, "PS"), ("B", vib, "PS"), ("UV", uv, ""), ("T", T, ""), ("Ring", ring, ""), ("Radius", radius, "")],
               out=F1, extra=(("Normal", F3),))
    g.out(ps, "Normal", MP.MP_NORMAL)
    g.out(rough, "", MP.MP_ROUGHNESS)
    g.out(spec_, "", MP.MP_SPECULAR)
    g.out(ps, "", MP.MP_OPACITY)
    return _finish(g)


def build_ring_card():
    """DripRingCard_Mars_M: the same rings as DripImpact_Mars_M on a translucent lit card a few mm over the water.
    Single Layer Water does not receive DBuffer decals (checked in WaterLookdev: no ring in the SLW normals), so drips
    that land on water lay their rings with this card instead of the mesh decal."""
    m = _master("DripRingCard_Mars_M")
    _props(m, material_domain=unreal.MaterialDomain.MD_SURFACE, blend_mode=unreal.BlendMode.BLEND_TRANSLUCENT,
           shading_model=unreal.MaterialShadingModel.MSM_DEFAULT_LIT,
           translucency_lighting_mode=unreal.TranslucencyLightingMode.TLM_SURFACE_PER_PIXEL_LIGHTING,
           used_with_instanced_static_meshes=True, translucency_pass=unreal.MaterialTranslucencyPass.MTP_AFTER_DOF,
           output_translucent_velocity=False)
    g = _G(m)
    via, vib = _decal_vs(g, 6, spec.RING_DATA, (100.0, 0.8, 0.0, 0.6, 0.0, 1.0))
    g.group("Rings")
    width = g.scalar("RingWidthCm", 1.2, 0.1, 5.0)
    decay = g.scalar("Decay", 0.8, 0.05, 3.0, "Ring amplitude e-folding time (s).")
    gain = g.scalar("RingAlphaGain", 0.8, 0.0, 4.0, "Opacity per unit slope.")
    dimple = g.scalar("Dimple", 0.4, 0.0, 2.0)
    radius = g.scalar("DropRadiusCm", spec.DROP_RADIUS_CM, 0.1, 2.0, "Must match the drop material (same clock).")
    rough = g.scalar("Roughness", 0.04, 0.0, 1.0)
    spec_ = g.scalar("Specular", 0.5, 0.0, 1.0)
    tint = g.vector("WaterColour", (0.006, 0.009, 0.007, 1.0), "Lit colour of the ring crests.")
    g.group("Debug")
    debug = g.scalar("DebugTime", -1.0, -1.0, 3600.0)
    T = g.time(debug)
    uv = g.node(unreal.MaterialExpressionTextureCoordinate)
    ring = g.pack("Ring", [(width, ""), (decay, ""), (gain, ""), (dimple, "")])
    g.nx, g.ny = 200, -1200
    ps = g.wet("Rings", "float2 P = (UV - 0.5) * B.zw * float2(1, -1);\n"
                        "return MarsWet_ImpactRings(A, B.xy, P, T, Ring, Radius, Normal);",
               [("A", via, "PS"), ("B", vib, "PS"), ("UV", uv, ""), ("T", T, ""), ("Ring", ring, ""), ("Radius", radius, "")],
               out=F1, extra=(("Normal", F3),))
    g.out(tint, "", MP.MP_BASE_COLOR)
    g.out(ps, "Normal", MP.MP_NORMAL)
    g.out(rough, "", MP.MP_ROUGHNESS)
    g.out(spec_, "", MP.MP_SPECULAR)
    g.out(ps, "", MP.MP_OPACITY)
    return _finish(g)


def _puddle_shape(g, via, vib):
    g.group("Shape")
    facets = g.scalar("Facets", 9.0, 0.0, 12.0, "Half-planes cut into the outline (0 = round).")
    lobes = g.scalar("LobeAmount", 0.3, 0.0, 1.0)
    island = g.scalar("IslandThreshold", 0.62, 0.3, 1.0, "Higher = fewer dry islands.")
    uv = g.node(unreal.MaterialExpressionTextureCoordinate)
    wp = g.world_pos()
    shape = g.custom("Shape In", "return float4(A.x, A.w, Facets, Lobes);",
                     [("A", via, "PS"), ("Facets", facets, ""), ("Lobes", lobes, "")], *g.at(), out=F4)
    masks = g.wet("Puddle Shape", "return MarsWet_PuddleShape((UV - 0.5) * 2.0, WP.xy, Shape, Island);",
                  [("UV", uv, ""), ("WP", wp, ""), ("Shape", shape, ""), ("Island", island, "")], out=F2)
    return masks, wp


def build_puddle_wet():
    m = _decal_master("PuddleWet_Mars_M")
    g = _G(m)
    via, vib = _decal_vs(g, 4, spec.PUDDLE_DATA, (0.3, 0.85, 0.0, 0.3))
    masks, _ = _puddle_shape(g, via, vib)
    g.group("Wet")
    tint = g.vector("WaterTint", (0.010, 0.009, 0.007, 1.0), "What the stone darkens toward.")
    deep = g.scalar("DeepDarken", 0.6, 0.0, 1.0, "Opacity of the darkening in the puddle core (albedo x (1 - this)).")
    rim = g.scalar("RimDarken", 0.45, 0.0, 1.0, "Opacity of the darkening on the damp rim.")
    wet = g.custom("Wet In", "return float4(A.y, Deep, Rim, 0);", [("A", via, "PS"), ("Deep", deep, ""), ("Rim", rim, "")],
                   *g.at(), out=F4)
    ps = g.wet("Puddle Wet", "return MarsWet_PuddleWet(Masks, Wet);", [("Masks", masks, ""), ("Wet", wet, "")])
    g.out(tint, "", MP.MP_BASE_COLOR)
    g.out(ps, "", MP.MP_OPACITY)
    return _finish(g)


def build_puddle_gloss():
    m = _decal_master("PuddleGloss_Mars_M")
    g = _G(m)
    via, vib = _decal_vs(g, 4, spec.PUDDLE_DATA, (0.3, 0.85, 0.0, 0.3))
    masks, wp = _puddle_shape(g, via, vib)
    g.group("Gloss")
    deep_op = g.scalar("DeepOpacity", 0.95, 0.0, 1.0, ">= 0.91 pushes the core below the capture fade start (0.1).")
    rim_op = g.scalar("RimOpacity", 0.5, 0.0, 1.0)
    deep_r = g.scalar("DeepRoughness", 0.03, 0.0, 1.0)
    rim_r = g.scalar("RimRoughness", 0.35, 0.0, 1.0)
    spec_ = g.scalar("Specular", 0.3, 0.0, 1.0)
    micro = g.scalar("MicroRippleAmp", 0.03, 0.0, 0.3)
    g.group("Rain")
    rain_min = g.scalar("RainRate", 0.6, 0.0, 10.0, "Rain rings per m^2 per s when RainRipples is on (the instance's "
                                                    "custom data 2 raises it).")
    cell = g.scalar("RainCellCm", 16.0, 4.0, 64.0)
    rain_sw = g._param(unreal.MaterialExpressionStaticSwitchParameter, 160, "RainRipples", "Ambient rain rings.")
    rain_sw.set_editor_property("default_value", False)
    zero = g.expr(unreal.MaterialExpressionConstant, *g.at())
    rain_on = g.custom("Rain On", "return max(A.z, RainMin);", [("A", via, "PS"), ("RainMin", rain_min, "")], *g.at(), out=F1)
    g.link(rain_on, "", rain_sw, "True")
    g.link(zero, "", rain_sw, "False")
    g.group("Debug")
    debug = g.scalar("DebugTime", -1.0, -1.0, 3600.0)
    T = g.time(debug)
    gloss = g.custom("Gloss In", "return float4(A.y, Deep, Rim, Micro);",
                     [("A", via, "PS"), ("Deep", deep_op, ""), ("Rim", rim_op, ""), ("Micro", micro, "")], *g.at(), out=F4)
    rough = g.pack("Rough In", [(deep_r, ""), (rim_r, ""), (rain_sw, ""), (cell, "")])
    ps = g.wet("Puddle Gloss", "return MarsWet_PuddleGloss(Masks, WP.xy, T, Gloss, Rough, Normal, Roughness);",
               [("Masks", masks, ""), ("WP", wp, ""), ("T", T, ""), ("Gloss", gloss, ""), ("Rough", rough, "")],
               extra=(("Normal", F3), ("Roughness", F1)))
    metal = g.expr(unreal.MaterialExpressionConstant, *g.at())
    g.out(ps, "Normal", MP.MP_NORMAL)
    g.out(ps, "Roughness", MP.MP_ROUGHNESS)
    g.out(spec_, "", MP.MP_SPECULAR)
    g.out(metal, "", MP.MP_METALLIC)
    g.out(ps, "", MP.MP_OPACITY)
    return _finish(g)


# ------------------------------------------------------------------ WetStreak_Mars_M (projected decal, §3.10)
def build_streak():
    m = _master("WetStreak_Mars_M")
    _props(m, material_domain=unreal.MaterialDomain.MD_DEFERRED_DECAL, blend_mode=unreal.BlendMode.BLEND_TRANSLUCENT)
    g = _G(m)
    g.group("Streak")
    rivulets = g.scalar("Rivulets", 4.0, 1.0, 6.0)
    riv_w = g.scalar("RivuletWidth", 0.06, 0.01, 0.3, "Rivulet half width (fraction of the decal width).")
    halo = g.scalar("HaloOpacity", 0.35, 0.0, 1.0)
    core = g.scalar("CoreOpacity", 0.85, 0.0, 1.0)
    core_r = g.scalar("CoreRoughness", 0.06, 0.0, 1.0)
    halo_r = g.scalar("HaloRoughness", 0.25, 0.0, 1.0)
    mineral = g.vector("MineralTint", (0.09, 0.04, 0.015, 1.0), "Rust or calcite gathered under the source.")
    damp = g.vector("DampTint", (0.012, 0.011, 0.009, 1.0), "What the wall darkens toward.")
    flip = g.scalar("FlipV", 0.0, 0.0, 1.0, "1 flips the decal V (if the streak runs up from the source).")
    g.group("Debug")
    debug = g.scalar("DebugTime", -1.0, -1.0, 3600.0)
    T = g.time(debug)
    uv = g.node(unreal.MaterialExpressionTextureCoordinate)
    dc = g.node(unreal.MaterialExpressionDecalColor)
    wp = g.world_pos()
    axis = g.local_to_world_vec((1.0, 0.0, 0.0))
    along = g.local_to_world_vec((0.0, 1.0, 0.0))
    params = g.pack("Streak In", [(rivulets, ""), (riv_w, ""), (halo, ""), (core, "")])
    face = g.custom("Face Mask", "float3 N = normalize(cross(ddx(WP), ddy(WP)));\n"
                                 "return smoothstep(0.6, 0.85, abs(dot(N, normalize(Axis))));",
                    [("WP", wp, ""), ("Axis", axis, "")], *g.at(), out=F1)
    g.nx, g.ny = 200, -1200
    ps = g.wet("Streak", "float2 U = float2(UV.x, lerp(UV.y, 1.0 - UV.y, Flip));\n"
                         "float4 Dc = DC; float Len = 2.0 * length(Along); float Tt = T; float4 Pp = P; float Fm = Face;\n"
                         "float Rv = 0; float Mn = 0;\n"
                         "float Op = MarsWet_Streak(U, Dc, Len, Tt, Pp, Fm, Rv, Mn);\n"
                         "Rivulet = Rv; Mineral = Mn; return Op;",
               [("UV", uv, ""), ("Flip", flip, ""), ("DC", dc, "RGBA"), ("Along", along, ""), ("T", T, ""), ("P", params, ""),
                ("Face", face, "")], extra=(("Rivulet", F1), ("Mineral", F1)))
    color = g.custom("Streak Colour", "return lerp(Damp.rgb, MineralTint.rgb, saturate(Mineral));",
                     [("Damp", damp, ""), ("MineralTint", mineral, ""), ("Mineral", ps, "Mineral")], *g.at(), out=F3)
    rough = g.custom("Streak Roughness", "return lerp(HaloR, CoreR, saturate(Rivulet));",
                     [("HaloR", halo_r, ""), ("CoreR", core_r, ""), ("Rivulet", ps, "Rivulet")], *g.at(), out=F1)
    normal = g.custom("Streak Normal", "return normalize(float3(0.0, 0.0, 1.0) + float3(0.0, 0.25 * Rivulet, 0.0));",
                      [("Rivulet", ps, "Rivulet")], *g.at(), out=F3)
    sp = g.expr(unreal.MaterialExpressionConstant, *g.at())
    sp.set_editor_property("r", 0.35)
    g.out(color, "", MP.MP_BASE_COLOR)
    g.out(normal, "", MP.MP_NORMAL)
    g.out(rough, "", MP.MP_ROUGHNESS)
    g.out(sp, "", MP.MP_SPECULAR)
    g.out(ps, "", MP.MP_OPACITY)
    return _finish(g)


# ------------------------------------------------------------------ still water (§3.11)
def _water_common(g):
    cpd = g.cpd_scalars("Custom Primitive Data", spec.STILLWATER_DATA, (200.0, 200.0, 0.0, 1.0, 0.0))
    g.group("Water")
    deep = g.vector("DeepColour", (0.006, 0.009, 0.007, 1.0))
    edge = g.vector("EdgeColour", (0.03, 0.035, 0.02, 1.0))
    scum_c = g.vector("ScumColour", (0.035, 0.04, 0.022, 1.0))
    fade = g.scalar("DepthFadeCm", 180.0, 1.0, 1000.0, "Edge-to-deep colour distance, times Murk (CPD 3).")
    scum_w = g.scalar("ScumWidthCm", 15.0, 0.0, 100.0)
    scum_r = g.scalar("ScumRoughness", 0.35, 0.0, 1.0)
    rough = g.scalar("Roughness", 0.03, 0.0, 1.0)
    spec_ = g.scalar("Specular", 0.3, 0.0, 1.0)
    swell = g.scalar("Swell", 0.02, 0.0, 0.2, "Slope of the drifting swell.")
    g.group("Rain")
    rain_sw = g._param(unreal.MaterialExpressionStaticSwitchParameter, 160, "RainRipples", "Ambient rain rings.")
    rain_sw.set_editor_property("default_value", False)
    rain_on = g.custom("Rain On", "return max(R, 0.6);", [("R", cpd[4], "")], *g.at(), out=F1)
    zero = g.expr(unreal.MaterialExpressionConstant, *g.at())
    g.link(rain_on, "", rain_sw, "True")
    g.link(zero, "", rain_sw, "False")
    g.group("Debug")
    debug = g.scalar("DebugTime", -1.0, -1.0, 3600.0)
    T = g.time(debug)
    uv = g.node(unreal.MaterialExpressionTextureCoordinate)
    wp = g.world_pos()
    c4 = g.pack("Cpd", [(cpd[0], ""), (cpd[1], ""), (cpd[2], ""), (cpd[3], "")])
    sw = g.pack("Swell In", [(fade, ""), (scum_w, ""), (swell, ""), (rain_sw, "")])
    g.nx, g.ny = 200, -1200
    ps = g.wet("Still Water", "return MarsWet_StillWater(UV, WP.xy, T, Cpd, Swell, Normal, Scum);",
               [("UV", uv, ""), ("WP", wp, ""), ("T", T, ""), ("Cpd", c4, ""), ("Swell", sw, "")],
               extra=(("Normal", F3), ("Scum", F1)))
    color = g.custom("Water Colour", "return lerp(lerp(Edge.rgb, Deep.rgb, Depth), Scum.rgb, saturate(S));",
                     [("Edge", edge, ""), ("Deep", deep, ""), ("Depth", ps, ""), ("Scum", scum_c, ""), ("S", ps, "Scum")],
                     *g.at(), out=F3)
    r = g.custom("Water Roughness", "return lerp(R, SR, saturate(S));",
                 [("R", rough, ""), ("SR", scum_r, ""), ("S", ps, "Scum")], *g.at(), out=F1)
    g.out(ps, "Normal", MP.MP_NORMAL)
    g.out(r, "", MP.MP_ROUGHNESS)
    g.out(spec_, "", MP.MP_SPECULAR)
    return color, ps


def build_still_water():
    m = _master("StillWater_Mars_M")
    _props(m, material_domain=unreal.MaterialDomain.MD_SURFACE, blend_mode=unreal.BlendMode.BLEND_OPAQUE,
           shading_model=unreal.MaterialShadingModel.MSM_DEFAULT_LIT,
           material_decal_response=unreal.MaterialDecalResponse.MDR_NORMAL_ROUGHNESS)
    g = _G(m)
    color, _ = _water_common(g)
    g.out(color, "", MP.MP_BASE_COLOR)
    return _finish(g)


def build_still_water_deep():
    m = _master("StillWaterDeep_Mars_M")
    _props(m, material_domain=unreal.MaterialDomain.MD_SURFACE, blend_mode=unreal.BlendMode.BLEND_OPAQUE,
           shading_model=unreal.MaterialShadingModel.MSM_SINGLE_LAYER_WATER,
           material_decal_response=unreal.MaterialDecalResponse.MDR_NORMAL_ROUGHNESS)
    g = _G(m)
    color, ps = _water_common(g)
    g.group("Single Layer Water")
    absorb = g.vector("Absorption", (0.040, 0.014, 0.020, 1.0), "1/cm: red dies within ~25 cm, green within ~70 cm.")
    scatter = g.vector("Scattering", (0.0012, 0.0026, 0.0018, 1.0), "1/cm.")
    phase = g.scalar("PhaseG", 0.15, -1.0, 1.0)
    behind = g.scalar("ColorScaleBehindWater", 0.6, 0.0, 1.0)
    slw = g.node(unreal.MaterialExpressionSingleLayerWaterMaterialOutput)
    for src, pin in ((scatter, "ScatteringCoefficients"), (absorb, "AbsorptionCoefficients"), (phase, "PhaseG"),
                     (behind, "ColorScaleBehindWater")):
        if not any(MEL.connect_material_expressions(src, "", slw, n) for n in (pin, unreal.Name(pin))) and                 not MEL.connect_material_expressions(src, "", slw, " ".join(_split_camel(pin))):
            _warn("StillWaterDeep_Mars_M: could not connect %s" % pin)
    dark = g.custom("SLW Base", "return Color * 0.25;", [("Color", color, "")], *g.at(), out=F3)
    g.out(dark, "", MP.MP_BASE_COLOR)
    return _finish(g)


# ------------------------------------------------------------------ stylized water (STYLIZED_WATER_PLAN.md)
def _srgb(c):
    """Godot source_color uniforms are sRGB: the linear value the shader sees."""
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)


# Godot materials/mise_water.tres, metres -> cm (per-metre scales / 100); the colours are converted from sRGB.
STYLIZED = {
    "Colour": (("AbsorptionColour", _srgb((0.97, 0.45, 0.4)) + (1.0,), "Absorbed from the scene behind; 1 - this is "
                "the deep body colour (linear)."),
               ("BeersLaw", 4.0, 0.0, 20.0, "Absorption exponent over DepthDistanceCm."),
               ("DepthDistanceCm", 400.0, 1.0, 5000.0, "Depth (cm, vertical) at which the absorption saturates."),
               ("FresnelColour", _srgb((0.05, 0.35, 0.4)) + (1.0,), "Grazing-angle colour (linear)."),
               ("FresnelRadius", 2.2, 0.0, 6.0, "Fresnel exponent."),
               ("Roughness", 0.08, 0.0, 1.0, ""),
               ("Specular", 0.3, 0.0, 1.0, "")),
    "Glow": (("GlowColour", _srgb((0.12, 0.75, 0.7)) + (1.0,), "Mise glow: deep water and caustic ridges emit this "
              "(display-referred: the same on screen at any exposure)."),
             ("GlowStrength", 0.3, 0.0, 8.0, "Glow of the body (x (0.25 + depth blend)); foam glows at half this."),
             ("GlowCaustic", 1.5, 0.0, 8.0, "Glow of the caustic ridges.")),
    "Displacement": (("DisplacementStrengthCm", 5.0, 0.0, 50.0, "Swell height (cm, world position offset on Z)."),
                     ("DisplacementScrollSpeed", 0.05, 0.0, 1.0, ""),
                     ("DisplacementScrollOffset", (-0.2, 0.3, 0.0, 0.0), "Second sample's extra scroll (xy)."),
                     ("DisplacementScaleOffset", 0.5, 0.0, 4.0, "Second sample's scale factor."),
                     ("DisplacementScale", 0.0012, 0.0, 0.05, "Texture tiles per cm.")),
    "Edge": (("EdgeThicknessCm", 25.0, 0.0, 200.0, "Foam band where the opaque scene comes within this of the surface."),
             ("EdgeSpeed", 0.2, 0.0, 1.0, ""),
             ("EdgeNoiseScale", 0.006, 0.0, 0.05, "Foam noise tiles per cm.")),
    "Player": (("InfluenceSizeCm", 120.0, 0.0, 400.0, "Ripple radius round Water_Mars_MPC PlayerPosition (within 1 m "
                "of the surface)."),
               ("PlayerWaveFrequency", 10.0, 0.0, 20.0, ""),
               ("PlayerWaveSpeed", 5.0, 0.0, 10.0, "")),
    "Caustics": (("CausticSize", 0.012, 0.0, 0.08, "Caustic cells per cm on the floor."),
                 ("CausticRangeCm", 4000.0, 0.0, 25600.0, "Caustics fade out over the last 20 m before this distance."),
                 ("CausticStrength", 0.15, 0.0, 1.0, "")),
    "Reflections": (("SsrMixStrength", 0.45, 0.0, 1.0, "Only with ScreenSpaceReflections on."),
                    ("SsrTravel", 100.0, 0.0, 300.0, "Godot units: steps + metres travelled before giving up."),
                    ("SsrStepNearCm", 50.0, 10.0, 1000.0, ""),
                    ("SsrStepFarCm", 400.0, 200.0, 2000.0, ""),
                    ("SsrTolerance", 1.0, 0.0, 2.0, "A hit lies within this many steps behind the scene depth.")),
    "Normal Map": (("RefractionStrength", 0.6, 0.0, 4.0, "Screen-UV shift (Godot's refract_uv, unchanged)."),
                   ("NormalMapStrength", 0.8, 0.0, 4.0, ""),
                   ("ScrollSpeed", 0.15, 0.0, 1.0, ""),
                   ("ScrollOffset", (0.1, -0.3, 0.0, 0.0), "Second sample's extra scroll (xy)."),
                   ("ScaleOffset", 0.5, 0.0, 4.0, ""),
                   ("NormalMapScale", 0.0015, 0.0, 0.05, "Normal texture tiles per cm.")),
}
# texture object parameter -> (texture, sampler type)
STYLIZED_TEXTURE_PARAMS = (
    ("DisplacementTexture", "StylizedWaterDisplace_Mars_T", unreal.MaterialSamplerType.SAMPLERTYPE_GRAYSCALE),
    ("EdgeNoiseTexture", "StylizedWaterEdgeNoise_Mars_T", unreal.MaterialSamplerType.SAMPLERTYPE_GRAYSCALE),
    ("EdgeRampTexture", "StylizedWaterEdgeRamp_Mars_T", unreal.MaterialSamplerType.SAMPLERTYPE_GRAYSCALE),
    ("NormalTexture", "StylizedWaterNormal_Mars_T", unreal.MaterialSamplerType.SAMPLERTYPE_NORMAL),
)


def import_stylized_textures(bake=False):
    """Imports (bake=True first runs stylized_water_noise.py, which needs numpy + Pillow in the editor's Python; the
    host-side `python Tools/Blender/mars_water/stylized_water_noise.py` is the usual way) and sets up the four stylized-water textures to F_TEX. The noises tile and keep
    their mips (the normal is read at mip 2, as Godot does); the ramp clamps and has none."""
    if bake:
        import stylized_water_noise as swn
        importlib.reload(swn)
        swn.bake()
    tasks = [mc._task(os.path.join(spec.STYLIZED_EXPORT_DIR, d["file"]), spec.F_TEX, name)
             for name, d in spec.STYLIZED_TEXTURES.items()]
    mc._tools().import_asset_tasks(tasks)
    TCS, TA = unreal.TextureCompressionSettings, unreal.TextureAddress
    out = {}
    for name, d in spec.STYLIZED_TEXTURES.items():
        tex = mc._asset(spec.F_TEX, name)
        if tex is None:
            _warn("texture %s did not import" % name)
            continue
        tex.set_editor_property("srgb", False)
        if d["kind"] == "normal":
            tex.set_editor_property("compression_settings", TCS.TC_NORMALMAP)
            tex.set_editor_property("flip_green_channel", False)
        else:
            tex.set_editor_property("compression_settings", TCS.TC_GRAYSCALE)
        if d["kind"] == "ramp":
            tex.set_editor_property("address_x", TA.TA_CLAMP)
            tex.set_editor_property("address_y", TA.TA_CLAMP)
            tex.set_editor_property("mip_gen_settings", unreal.TextureMipGenSettings.TMGS_NO_MIPMAPS)
        else:
            tex.set_editor_property("address_x", TA.TA_WRAP)
            tex.set_editor_property("address_y", TA.TA_WRAP)
        EAL.save_loaded_asset(tex)
        out[name] = "%dx%d" % (tex.blueprint_get_size_x(), tex.blueprint_get_size_y())
    _log("stylized textures %s" % out)
    return out


def _write_grid_obj(path, quads):
    """A quads x quads grid over the 100 x 100 cm square, Z up, normal +Z, UV 0..1 (U along +X, V down +Y)."""
    n = quads + 1
    lines = ["# %s (mars_water_ue._write_grid_obj)" % os.path.basename(path), "o StillWaterGrid", "vn 0 0 1"]
    for j in range(n):
        for i in range(n):
            lines.append("v %.5f %.5f 0" % (-50.0 + 100.0 * i / quads, -50.0 + 100.0 * j / quads))
    for j in range(n):
        for i in range(n):
            lines.append("vt %.6f %.6f" % (i / quads, j / quads))
    lines.append("usemtl Water")
    for j in range(quads):
        for i in range(quads):
            a, b, c, d = j * n + i + 1, j * n + i + 2, (j + 1) * n + i + 2, (j + 1) * n + i + 1
            lines.append("f %d/%d/1 %d/%d/1 %d/%d/1" % (a, a, b, b, c, c))
            lines.append("f %d/%d/1 %d/%d/1 %d/%d/1" % (a, a, c, c, d, d))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        fh.write("\n".join(lines) + "\n")


def build_grid_mesh():
    """StillWaterGrid_Mars_SM: the glow pool's tessellated surface (the swell is a vertex offset). A live mesh is never
    rebuilt in place: an existing asset is kept unless its vertex count is wrong."""
    sme = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
    want = (spec.GRID_QUADS + 1) ** 2
    mesh = mc._asset(spec.F_MESH, spec.GRID_MESH)
    if mesh is None or sme.get_number_verts(mesh, 0) != want:
        obj = os.path.join(spec.REPO, "Saved", "WaterFx", spec.GRID_MESH + ".obj")
        _write_grid_obj(obj, spec.GRID_QUADS)
        path = "%s/%s" % (spec.F_MESH, spec.GRID_MESH)
        if EAL.does_asset_exist(path):
            EAL.delete_asset(path)
        before = set(EAL.list_assets(spec.UE_ROOT, recursive=True, include_folder=False))
        mc._tools().import_asset_tasks([mc._task(obj, spec.F_MESH, spec.GRID_MESH)])
        mesh = mc._asset(spec.F_MESH, spec.GRID_MESH)
        if mesh is None:
            raise RuntimeError("%s did not import" % obj)
        for p in set(EAL.list_assets(spec.UE_ROOT, recursive=True, include_folder=False)) - before:
            if not p.split(".")[0].endswith(spec.GRID_MESH):
                EAL.delete_asset(p.split(".")[0])          # materials the importer made from usemtl
    sme.remove_collisions(mesh)
    pos, neg = spec.GRID_BOUNDS
    mesh.set_editor_property("positive_bounds_extension", unreal.Vector(*pos))
    mesh.set_editor_property("negative_bounds_extension", unreal.Vector(*neg))
    try:
        ns = mesh.get_editor_property("nanite_settings")
        ns.set_editor_property("enabled", False)
        mesh.set_editor_property("nanite_settings", ns)
    except Exception:
        pass
    mesh.set_material(0, mc._asset(spec.F_MAT, "StillWaterGlow_Mars_MI"))
    EAL.save_loaded_asset(mesh)
    b = mesh.get_bounds()
    ext = b.box_extent
    assert abs(ext.x - 50.0) < 0.5 and abs(ext.y - 50.0) < 0.5, "the grid should be 100 x 100 cm in XY (got %s)" % ext
    return {"verts": sme.get_number_verts(mesh, 0), "extent": str(ext)}


def build_mpc():
    """Water_Mars_MPC: PlayerPosition (cm, written by AMars_StillWater's glow style for the local player), WindDirection,
    WindIntensity (Godot's shader globals). Existing parameters keep their ids; missing ones are added."""
    mpc = mc._asset(spec.F_MAT, spec.MPC)
    if mpc is None:
        mpc = mc._tools().create_asset(spec.MPC, spec.F_MAT, unreal.MaterialParameterCollection,
                                       unreal.MaterialParameterCollectionFactoryNew())
    vectors = list(mpc.get_editor_property("vector_parameters"))
    scalars = list(mpc.get_editor_property("scalar_parameters"))
    have = {str(p.get_editor_property("parameter_name")) for p in vectors + scalars}
    for name, value in spec.MPC_DEFAULTS.items():
        if name in have:
            continue
        if isinstance(value, tuple):
            p = unreal.CollectionVectorParameter()
            p.set_editor_property("parameter_name", name)
            p.set_editor_property("default_value", unreal.LinearColor(*value))
            vectors.append(p)
        else:
            p = unreal.CollectionScalarParameter()
            p.set_editor_property("parameter_name", name)
            p.set_editor_property("default_value", float(value))
            scalars.append(p)
    mpc.set_editor_property("vector_parameters", vectors)
    mpc.set_editor_property("scalar_parameters", scalars)
    EAL.save_loaded_asset(mpc)
    return sorted(str(p.get_editor_property("parameter_name")) for p in vectors + scalars)


def build_stylized_assets():
    return {"textures": import_stylized_textures(), "mpc": build_mpc()}


def build_stylized_all():
    """Everything the glow pool needs, touching no other water asset: textures, MPC, the master, its instance, the grid."""
    if mc._in_pie():
        raise RuntimeError("stop PIE first")
    r = {"stylized": build_stylized_assets(), "masters": build_masters(["StylizedWater_Mars_M"]),
         "instances": build_instances(["StillWaterGlow_Mars_MI"]), "grid": build_grid_mesh()}
    return r


def _stylized_params(g):
    """One column per STYLIZED group; returns {name: node}."""
    nodes = {}
    for group, params in STYLIZED.items():
        g.group(group)
        for p in params:
            if isinstance(p[1], tuple):
                nodes[p[0]] = g.vector(p[0], p[1], p[2])
            else:
                nodes[p[0]] = g.scalar(p[0], p[1], p[2], p[3], p[4])
    g.group("Textures")
    for name, tex, sampler in STYLIZED_TEXTURE_PARAMS:
        e = g._param(unreal.MaterialExpressionTextureObjectParameter, 220, name, "")
        e.set_editor_property("texture", mc._asset(spec.F_TEX, tex))
        e.set_editor_property("sampler_type", sampler)
        nodes[name] = e
    g.group("Switches")
    ssr = g._param(unreal.MaterialExpressionStaticSwitchParameter, 160, "ScreenSpaceReflections",
                   "The Godot 100-step reflection march on the scene colour (Mars runs r.ReflectionMethod=0). Off by default.")
    ssr.set_editor_property("default_value", False)
    one = g.expr(unreal.MaterialExpressionConstant, *g.at())
    one.set_editor_property("r", 1.0)
    zero = g.expr(unreal.MaterialExpressionConstant, *g.at())
    g.link(one, "", ssr, "True")
    g.link(zero, "", ssr, "False")
    nodes["SsrOn"] = ssr
    return nodes


def _mpc_param(g, mpc, name):
    e = g.node(unreal.MaterialExpressionCollectionParameter)
    e.set_editor_property("collection", mpc)
    e.set_editor_property("parameter_name", name)
    return e


def build_stylized_water():
    """StylizedWater_Mars_M: the Godot MiseCryptLab water (Shaders/Water/MarsStylizedWater.ush). Translucent, lit per
    pixel (Surface ForwardShading), opacity 1: the refracted scene, absorption, foam, caustics and fresnel are worked out
    from SceneColor / SceneDepth in the shade node and come out as the lit base colour, as Godot's ALBEDO; the glow goes
    to emissive. The swell is WPO on Z (needs StillWaterGrid_Mars_SM)."""
    mpc = mc._asset(spec.F_MAT, spec.MPC)
    assert mpc is not None, "build_mpc() first"
    m = _master("StylizedWater_Mars_M")
    _props(m, material_domain=unreal.MaterialDomain.MD_SURFACE, blend_mode=unreal.BlendMode.BLEND_TRANSLUCENT,
           shading_model=unreal.MaterialShadingModel.MSM_DEFAULT_LIT,
           translucency_lighting_mode=unreal.TranslucencyLightingMode.TLM_SURFACE_PER_PIXEL_LIGHTING,
           tangent_space_normal=False, translucency_pass=unreal.MaterialTranslucencyPass.MTP_AFTER_DOF,
           compute_fog_per_pixel=True, output_translucent_velocity=False, two_sided=False)
    g = _G(m)
    p = _stylized_params(g)
    g.group("Debug")
    debug = g.scalar("DebugTime", -1.0, -1.0, 3600.0, ">= 0 freezes the water clock (frozen-time captures).")
    T = g.time(debug)
    wind_dir = _mpc_param(g, mpc, "WindDirection")
    wind_int = _mpc_param(g, mpc, "WindIntensity")
    player = _mpc_param(g, mpc, "PlayerPosition")
    wind = g.custom("Wind", "return float4(D.xyz, I);", [("D", wind_dir, ""), ("I", wind_int, "")], *g.at(), out=F4)

    def v4(title, rgb, w):
        return g.custom(title, "return float4(C.rgb, S);", [("C", p[rgb], ""), ("S", p[w], "")], *g.at(), out=F4)

    absorb = v4("Absorb", "AbsorptionColour", "BeersLaw")
    fresnel = v4("Fresnel", "FresnelColour", "FresnelRadius")
    glow = v4("Glow", "GlowColour", "GlowStrength")
    depth = g.pack("Depth Edge", [(p["DepthDistanceCm"], ""), (p["EdgeThicknessCm"], ""), (p["EdgeSpeed"], ""),
                                  (p["EdgeNoiseScale"], "")])
    caustic = g.pack("Caustic", [(p["CausticSize"], ""), (p["CausticRangeCm"], ""), (p["CausticStrength"], ""),
                                 (p["GlowCaustic"], "")])
    ripple = g.pack("Ripple", [(p["InfluenceSizeCm"], ""), (p["PlayerWaveFrequency"], ""), (p["PlayerWaveSpeed"], ""),
                               (p["Roughness"], "")])
    normal = g.pack("Normal", [(p["RefractionStrength"], ""), (p["NormalMapStrength"], ""), (p["ScrollSpeed"], ""),
                               (p["ScaleOffset"], "")])
    normal2 = g.custom("Normal2", "return float4(O.xy, S, Tol);",
                       [("O", p["ScrollOffset"], ""), ("S", p["NormalMapScale"], ""), ("Tol", p["SsrTolerance"], "")],
                       *g.at(), out=F4)
    ssr = g.pack("Ssr", [(p["SsrMixStrength"], ""), (p["SsrTravel"], ""), (p["SsrStepNearCm"], ""),
                         (p["SsrStepFarCm"], "")])
    disp = g.pack("Displace", [(p["DisplacementStrengthCm"], ""), (p["DisplacementScrollSpeed"], ""),
                               (p["DisplacementScaleOffset"], ""), (p["DisplacementScale"], "")])
    wp_vs = g.world_pos()
    wp_ps = g.node(unreal.MaterialExpressionWorldPosition)       # after the swell (Godot's displaced global_position)
    scene_color = g.node(unreal.MaterialExpressionSceneColor)
    scene_depth = g.node(unreal.MaterialExpressionSceneDepth)

    g.nx, g.ny = -400, -1200
    vs = g.wet("Swell", "return float3(0, 0, MarsStylizedWater_Displace(WP.xy, T, Wind, Disp, Scroll.xy, Tex, TexSampler));",
               [("WP", wp_vs, ""), ("T", T, ""), ("Wind", wind, ""), ("Disp", disp, ""),
                ("Scroll", p["DisplacementScrollOffset"], ""), ("Tex", p["DisplacementTexture"], "")],
               out=F3, include=spec.STYLIZED_INCLUDE)
    g.nx, g.ny = 200, -1200
    code = ("FMarsStylizedWaterInputs I;\n"
            "I.WP = WP; I.T = T; I.Wind = Wind; I.Player = Player.xyz; I.Absorb = Absorb; I.Fresnel = Fresnel;\n"
            "I.Glow = Glow; I.Depth = Depth; I.Caustic = Caustic; I.Ripple = Ripple; I.Normal = NormalP;\n"
            "I.Normal2 = Normal2; I.Ssr = Ssr; I.SsrOn = SsrOn;\n"
            "// SceneColorBinding / SceneDepthBinding: unused, they make the translucent pass bind what the include reads\n"
            "FMarsStylizedWater O = MarsStylizedWater_Shade(Parameters, I, NormalTex, NormalTexSampler,\n"
            "    EdgeTex, EdgeTexSampler, RampTex, RampTexSampler);\n"
            "WaterNormal = O.Normal; Emissive = O.Emissive;\n"
            "return O.BaseColor;")
    ps = g.wet("Stylized Water", code,
                  [("WP", wp_ps, ""), ("T", T, ""), ("Wind", wind, ""), ("Player", player, ""), ("Absorb", absorb, ""),
                   ("Fresnel", fresnel, ""), ("Glow", glow, ""), ("Depth", depth, ""), ("Caustic", caustic, ""),
                   ("Ripple", ripple, ""), ("NormalP", normal, ""), ("Normal2", normal2, ""), ("Ssr", ssr, ""),
                   ("SsrOn", p["SsrOn"], ""), ("NormalTex", p["NormalTexture"], ""), ("EdgeTex", p["EdgeNoiseTexture"], ""),
                   ("RampTex", p["EdgeRampTexture"], ""), ("SceneColorBinding", scene_color, ""),
                   ("SceneDepthBinding", scene_depth, "")],
               out=F3, extra=(("WaterNormal", F3), ("Emissive", F3)), include=spec.STYLIZED_INCLUDE)
    opacity = g.expr(unreal.MaterialExpressionConstant, *g.at())
    opacity.set_editor_property("r", 1.0)
    g.out(vs, "", MP.MP_WORLD_POSITION_OFFSET)
    g.out(ps, "", MP.MP_BASE_COLOR)
    g.out(ps, "WaterNormal", MP.MP_NORMAL)
    g.out(ps, "Emissive", MP.MP_EMISSIVE_COLOR)
    g.out(p["Roughness"], "", MP.MP_ROUGHNESS)
    g.out(p["Specular"], "", MP.MP_SPECULAR)
    g.out(opacity, "", MP.MP_OPACITY)
    return _finish(g)


BUILDERS = {
    "Droplet_Mars_M": build_droplet,
    "DripImpact_Mars_M": build_impact,
    "DripRingCard_Mars_M": build_ring_card,
    "PuddleWet_Mars_M": build_puddle_wet,
    "PuddleGloss_Mars_M": build_puddle_gloss,
    "WetStreak_Mars_M": build_streak,
    "StillWater_Mars_M": build_still_water,
    "StillWaterDeep_Mars_M": build_still_water_deep,
    "StylizedWater_Mars_M": build_stylized_water,
}


def build_masters(names=None):
    stats = {}
    for name in (names or spec.MASTERS):
        stats[name] = BUILDERS[name]()
        budget = spec.BUDGETS.get(name)
        if budget and stats[name]["ps"] > budget[0]:
            _warn("%s pixel shader %d instructions > budget %d" % (name, stats[name]["ps"], budget[0]))
    _log("instruction counts %s" % stats)
    return stats


def build_instances(names=None):
    out = []
    for name, (parent_name, scalars, vectors, switches) in spec.INSTANCES.items():
        if names and name not in names:
            continue
        parent = mc._asset(spec.F_MAT, parent_name)
        inst = mc._asset(spec.F_MAT, name)
        if inst is None:
            inst = mc._tools().create_asset(name, spec.F_MAT, unreal.MaterialInstanceConstant,
                                            unreal.MaterialInstanceConstantFactoryNew())
        MEL.set_material_instance_parent(inst, parent)
        for k, v in scalars.items():
            MEL.set_material_instance_scalar_parameter_value(inst, k, float(v))
        for k, v in vectors.items():
            MEL.set_material_instance_vector_parameter_value(inst, k, unreal.LinearColor(*v))
        for k, v in switches.items():
            MEL.set_material_instance_static_switch_parameter_value(inst, k, bool(v))
        MEL.update_material_instance(inst)
        EAL.save_loaded_asset(inst)
        out.append(name)
    return out


# ------------------------------------------------------------------ checks
def audit_decal_response():
    """Environment masters that do not take colour + normal + roughness from decals (puddles would not show on them)."""
    bad = {}
    for path in EAL.list_assets("/Game/Mars/Environment", recursive=True, include_folder=False):
        data = unreal.EditorAssetLibrary.find_asset_data(path)
        if str(data.asset_class_path.asset_name) != "Material":
            continue
        m = EAL.load_asset(path)
        r = m.get_editor_property("material_decal_response")
        if r != unreal.MaterialDecalResponse.MDR_COLOR_NORMAL_ROUGHNESS and m.get_name() not in spec.MASTERS:
            bad[m.get_name()] = str(r)
    return bad


def verify_materials():
    out = {"errors": []}

    def need(cond, msg):
        if not cond:
            out["errors"].append(msg)

    for name in spec.MASTERS:
        m = mc._asset(spec.F_MAT, name)
        need(m is not None, "%s missing" % name)
        if m is None:
            continue
        st = MEL.get_statistics(m)
        out[name] = {"vs": st.num_vertex_shader_instructions, "ps": st.num_pixel_shader_instructions}
        need(st.num_pixel_shader_instructions > 0, "%s has no pixel shader (compile error?)" % name)
        times = [e for e in _expressions(m) if isinstance(e, unreal.MaterialExpressionTime)]
        need(all(t.get_editor_property("override_period") and abs(t.get_editor_property("period") - 3600.0) < 1e-3
                 for t in times), "%s: a Time node without the 3600 s period" % name)
        if name in ("Droplet_Mars_M", "DripImpact_Mars_M", "DripRingCard_Mars_M", "PuddleWet_Mars_M", "PuddleGloss_Mars_M"):
            need(m.get_editor_property("used_with_instanced_static_meshes"), "%s: no ISM usage" % name)
    sw = mc._asset(spec.F_MAT, "StillWater_Mars_M")
    if sw is not None:
        need(sw.get_editor_property("material_decal_response") == unreal.MaterialDecalResponse.MDR_NORMAL_ROUGHNESS,
             "StillWater_Mars_M must be MDR_NormalRoughness")
    for name, (pos, neg) in spec.MESHES.items():
        mesh = mc._asset(spec.F_MESH, name)
        need(mesh is not None, "%s missing" % name)
        if mesh is not None:
            p = mesh.get_editor_property("positive_bounds_extension")
            need(abs(p.z - pos[2]) < 1e-3, "%s bounds extension %s" % (name, p))
    out["decal_response"] = audit_decal_response()
    out["ok"] = not out["errors"]
    if out["ok"]:
        print("WATER_MATERIALS_OK")
    return out


def _expressions(m):
    try:
        return list(m.get_editor_property("expressions"))
    except Exception:
        try:
            return list(MEL.get_material_expressions(m)) if hasattr(MEL, "get_material_expressions") else []
        except Exception:
            return []


def run_all():
    if mc._in_pie():
        raise RuntimeError("stop PIE first")
    r = {"meshes": build_meshes(), "physmat": build_physmat(), "stylized": build_stylized_assets(),
         "masters": build_masters(), "instances": build_instances(), "grid": build_grid_mesh()}
    r["verify"] = verify_materials()
    return r
