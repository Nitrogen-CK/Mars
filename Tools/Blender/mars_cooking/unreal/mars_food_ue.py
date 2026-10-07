"""Editor side of the Mars food library: imports the food meshes / masks / oil VAT textures the Blender builders export
(food_spec.EXPORT_DIR), builds the food masters (Food_Mars_M, Batter_Mars_M, Accent_Mars_M, Salt_Mars_M, OilVAT_Mars_M
and the shared OilCoat_Mars_MF), their instances, assigns mesh slots from the JSON sidecars, builds
FoodLookdev_Mars_MAP with the whole roster in its cook states and captures review shots. Run in the editor's Python
(Monolith `editor_query run_python`):

    import sys, importlib
    sys.path.insert(0, r"D:\\Repo\\Mars\\Tools\\Blender\\mars_cooking\\unreal")
    import mars_food_ue as mf; importlib.reload(mf)
    mf.run_all()            # or the single steps: import_textures / import_meshes / build_materials / build_lookdev_map
    mf.capture(r"D:\\Repo\\Content\\Cooking\\export\\food\\review\\ue")     # with the lookdev map open
    mf.report()             # dry run: logs the slot assignment and instance plan, touches nothing

Built on mars_cooking_ue (the working meat / pan module on this engine build): its graph builder (_Graph), import task,
asset helpers and spawn / CPD helpers are imported and reused. That module belongs to another session, so it is
imported but never reloaded or edited. The pure data logic (sidecars, slot resolution, cook states, layout, VAT JSON)
lives in mars_food_plan, the Custom-node HLSL in mars_food_hlsl (MEAT_COOK / MEAT_NORMAL / MEAT_SHAPE come from
mars_cooking_hlsl unchanged).

The masters are generated: a rebuild replaces them, so tune looks in the material instances (instance overrides that
are not data-driven survive a rebuild). Masters are only replaced while no actor in the open level draws them.
"""
import glob
import importlib
import json
import math
import os
import sys
import tempfile

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
for _p in (HERE, os.path.dirname(HERE)):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import food_spec as fs  # noqa: E402
import mars_cooking_hlsl as mhlsl  # noqa: E402
import mars_cooking_ue as mc  # noqa: E402
import mars_food_hlsl as hlsl  # noqa: E402
import mars_food_plan as plan  # noqa: E402

importlib.reload(fs)
importlib.reload(hlsl)
importlib.reload(plan)

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary
FLOAT1, FLOAT3, FLOAT4 = mc.FLOAT1, mc.FLOAT3, mc.FLOAT4
FLOAT2 = unreal.CustomMaterialOutputType.CMOT_FLOAT2

F_MESH = fs.UE_FOLDER + "/Meshes"
F_TEX = fs.UE_FOLDER + "/Textures"
F_MAT = fs.UE_FOLDER + "/Materials"
F_INST = F_MAT + "/Instances"
F_LOOK = fs.UE_FOLDER + "/Lookdev"
F_FX = plan.NIAGARA_FOLDER
LOOKDEV_MAP = "/Game/Mars/Maps/FoodLookdev_Mars_MAP"
assert LOOKDEV_MAP != mc.spec.UE_LOOKDEV_MAP           # never touch CookingLookdev_Mars_MAP
VAT_JSON = "OilVAT_Mars.json"
STUDIO_HDR = "CookingStudio_Mars_HDR"                  # imported by mars_cooking_ue into the cooking Textures folder

SEAR_XY = mc.SEAR_XY                                   # ("+X", "-X", "+Y", "-Y")
SEAR_Z = mc.SEAR_Z                                     # ("+Z", "-Z", "Penetration", "Oil Coat")
FINISH = ("Glaze", "Shape", "Fry", "Wet")              # food_spec.CPD["Finish"]

SAMPLER_MASKS = unreal.MaterialSamplerType.SAMPLERTYPE_MASKS
SAMPLER_NORMAL = unreal.MaterialSamplerType.SAMPLERTYPE_NORMAL
SAMPLER_LINEAR = unreal.MaterialSamplerType.SAMPLERTYPE_LINEAR_COLOR


def _log(msg):
    unreal.log("MarsFood: %s" % msg)


def _warn(msg):
    unreal.log_warning("MarsFood: %s" % msg)


def _set(obj, prop, value):
    """set_editor_property that reports instead of aborting the whole step on a renamed / missing property."""
    try:
        obj.set_editor_property(prop, value)
        return True
    except Exception as exc:
        _warn("%s.%s = %r: %s" % (type(obj).__name__, prop, value, exc))
        return False


def _enum(enum_cls, *names):
    for n in names:
        v = getattr(enum_cls, n, None)
        if v is not None:
            return v
    return None


def _material(name):
    """A master, instance or engine material by name (or full object path)."""
    if name.startswith("/"):
        return mc._load(name)
    return mc._asset(F_MAT, name) or mc._asset(F_INST, name) or mc._asset(F_LOOK, name)


def _food_names(src, pattern):
    return [os.path.splitext(os.path.basename(p))[0] for p in sorted(glob.glob(os.path.join(src, pattern)))]


# ------------------------------------------------------------------ textures
def _texture_jobs(src):
    jobs = []
    for pattern, kind in (("*_Mask_Mars_T.png", "masks"), ("*_Normal_Mars_T.png", "normal"),
                          ("Oil*_VAT*_Mars_T.exr", "vat")):
        for path in sorted(glob.glob(os.path.join(src, pattern))):
            jobs.append((os.path.splitext(os.path.basename(path))[0], path, kind))
    return jobs


def _configure_texture(tex, kind):
    tcs = unreal.TextureCompressionSettings
    if kind == "masks":
        _set(tex, "compression_settings", tcs.TC_MASKS)
        _set(tex, "srgb", False)
    elif kind == "normal":
        _set(tex, "compression_settings", tcs.TC_NORMALMAP)
        _set(tex, "srgb", False)
        _set(tex, "flip_green_channel", False)                  # DirectX green-down, like the meat cube
    elif kind in ("vat", "vat_rest"):
        f32 = _enum(tcs, "TC_HDR_F32") if kind == "vat" else None
        if f32 is None or not _set(tex, "compression_settings", f32):
            _set(tex, "compression_settings", tcs.TC_HDR)
        _set(tex, "srgb", False)
        _set(tex, "mip_gen_settings", unreal.TextureMipGenSettings.TMGS_NO_MIPMAPS)
        _set(tex, "filter", unreal.TextureFilter.TF_NEAREST)
        _set(tex, "never_stream", True)
        _set(tex, "virtual_texture_streaming", False)           # a virtual texture cannot be sampled for WPO
        _set(tex, "address_x", unreal.TextureAddress.TA_CLAMP)
        _set(tex, "address_y", unreal.TextureAddress.TA_CLAMP)


def _import_textures(jobs):
    """jobs: (asset name, file, kind). Imports in one batch, then sets the per-kind texture settings."""
    if not jobs:
        return []
    mc._tools().import_asset_tasks([mc._task(path, F_TEX, name) for name, path, _ in jobs])
    done = []
    for name, path, kind in jobs:
        tex = mc._asset(F_TEX, name)
        if tex is None:
            _warn("texture %s did not import (%s)" % (name, path))
            continue
        _configure_texture(tex, kind)
        EAL.save_loaded_asset(tex)
        done.append(name)
    return done


def _ensure_generated(force=False):
    """The 4 x 4 neutral mask / flat normal / VAT rest textures the masters use as defaults (written as PNGs to the
    temp folder by mars_food_plan.write_png, so the masters build before any export exists)."""
    folder = os.path.join(tempfile.gettempdir(), "mars_food_ue")
    jobs = []
    for name, rgba, kind in plan.GENERATED:
        if force or mc._asset(F_TEX, name) is None:
            jobs.append((name, plan.write_png(os.path.join(folder, name + ".png"), 4, 4, rgba), kind))
    return _import_textures(jobs)


def read_vat(export_dir=None):
    """(per-stem decode constants, per-stem VAT texture names) from the EXRs present and OilVAT_Mars.json."""
    src = plan.food_dir(export_dir)
    vat_tex = plan.vat_textures(_food_names(src, "Oil*_VAT*_Mars_T.exr"))
    stems = set(vat_tex)
    for meta in plan.read_metas(src):
        if "_error" not in meta and plan.classify(meta) == "oil":
            stems.add(plan.parse_name(meta["name"])[0])
    if not stems:
        return {}, vat_tex
    data, path = None, os.path.join(src, VAT_JSON)
    if os.path.isfile(path):
        try:
            with open(path) as fh:
                data = json.load(fh)
        except (OSError, ValueError) as exc:
            _warn("%s unreadable: %s" % (path, exc))
    else:
        _warn("%s missing: VAT decode falls back to food_spec (%d frames, %.1f s) and zero bounds"
              % (path, fs.OIL_FRAMES, fs.OIL_SECONDS))
    vat = plan.vat_meta(data, sorted(stems))
    metas = {plan.parse_name(m["name"])[0]: m for m in plan.read_metas(src) if "_error" not in m}
    for stem, d in sorted(vat.items()):
        _log("VAT %s: pos %s .. %s cm, %d frames / %.2f s, flip V %d, json version %s, pop %s (from %s)"
             % (stem, d["pos_min"], d["pos_max"], d["frames"], d["seconds"], d["flip_v"], d["version"], d["pop"],
                d["source"] or "defaults"))
        if d["source"] is None:
            _warn("VAT %s: no pos_min / pos_max in %s, the offset decodes to zero" % (stem, VAT_JSON))
        if not d["flip_known"]:
            _warn("VAT %s: %s does not say which row holds frame 0; Flip V = 0 assumes the top row. If the loop "
                  "plays backwards (bubbles un-pop), set Flip V 1 on %s_Mars_MI" % (stem, VAT_JSON, stem))
        tex = mc._asset(F_TEX, vat_tex.get(stem, {}).get("Pos")) if vat_tex.get(stem, {}).get("Pos") else None
        if tex is not None:
            try:
                w, h = tex.blueprint_get_size_x(), tex.blueprint_get_size_y()
                if h and h != d["frames"]:
                    _warn("VAT %s: texture has %d rows, decode uses %d frames" % (stem, h, d["frames"]))
                verts = metas.get(stem, {}).get("verts")
                if verts and w and w != verts:
                    _warn("VAT %s: texture is %d columns wide, the mesh sidecar has %d verts" % (stem, w, verts))
            except Exception as exc:
                _warn("VAT %s: could not read the texture size (%s)" % (stem, exc))
    return vat, vat_tex


def import_textures(export_dir=None):
    """Every *_Mask_Mars_T.png (TC_MASKS, linear), *_Normal_Mars_T.png (TC_NORMALMAP, no green flip) and the
    Oil*_VAT*_Mars_T.exr (TC_HDR_F32 or TC_HDR, linear, no mips, nearest, never streamed) of the food export, plus
    the generated defaults. Returns read_vat()."""
    if mc._in_pie():
        raise RuntimeError("stop PIE before importing (assets imported during PIE vanish)")
    src = plan.food_dir(export_dir)
    jobs = _texture_jobs(src)
    if not jobs:
        _warn("no food textures in %s" % src)
    done = _import_textures(jobs)
    _ensure_generated(force=True)
    _log("%d of %d textures imported from %s" % (len(done), len(jobs), src))
    return read_vat(src)


# ------------------------------------------------------------------ meshes
def _mesh_task(path, name):
    """mc.import_meshes' legacy FBX settings (import normals, no lightmap UVs so UV1 / UV2 survive, combined, no
    auto collision) plus the FBX vertex colours."""
    task = mc._task(path, F_MESH, name)
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
    _set(sm, "vertex_color_import_option", unreal.VertexColorImportOption.REPLACE)
    _set(sm, "build_nanite", False)                     # small faceted props with WPO: keep them off Nanite
    task.options = opts
    return task


def _collision(sme, mesh, simple):
    """Replace the simple collision: one 26-DOP hull (18-DOP, then a box as fallbacks), or none."""
    try:
        sme.remove_collisions(mesh)
    except Exception as exc:
        _warn("%s: remove_collisions failed (%s)" % (mesh.get_name(), exc))
    if not simple:
        return
    for shape in ("NDOP26", "NDOP18", "BOX"):
        kind = _enum(unreal.ScriptCollisionShapeType, shape)
        if kind is None:
            continue
        try:
            index = sme.add_simple_collisions(mesh, kind)
        except Exception as exc:
            _warn("%s: add_simple_collisions %s failed (%s)" % (mesh.get_name(), shape, exc))
            continue
        if index is not None and index >= 0:
            return
        _warn("%s: add_simple_collisions %s returned %s" % (mesh.get_name(), shape, index))
    _warn("%s: no simple collision" % mesh.get_name())


def _full_precision_uvs(sme, mesh):
    """The VAT column is UV1.x = (i + 0.5) / 4096; half-float UVs step by 1/2048 above 0.5 and would read every
    other column, so the oil meshes need full-precision UVs."""
    try:
        bs = sme.get_lod_build_settings(mesh, 0)
        if not bs.get_editor_property("use_full_precision_u_vs"):
            bs.set_editor_property("use_full_precision_u_vs", True)
            sme.set_lod_build_settings(mesh, 0, bs)
            _log("%s: full-precision UVs on" % mesh.get_name())
    except Exception as exc:
        _warn("%s: could not switch on full-precision UVs (%s); switch it on by hand in the mesh's LOD0 build "
              "settings or the VAT reads the wrong columns" % (mesh.get_name(), exc))


def _cpu_access(sme, mesh):
    """Allow CPU Access, which runtime slicing (ProceduralMesh copy) needs in cooked builds."""
    try:
        sme.set_allow_cpu_access(mesh, True)
        _log("%s: allow CPU access" % mesh.get_name())
    except Exception as exc:
        if not _set(mesh, "allow_cpu_access", True):
            _warn("%s: could not allow CPU access (%s)" % (mesh.get_name(), exc))


def _check_mesh(sme, mesh, meta):
    b = mesh.get_bounds()
    try:
        uvs = sme.get_num_uv_channels(mesh, 0)
    except Exception:
        uvs = -1
    _log("%s extent %.1f %.1f %.1f cm, %d uv channels" % (mesh.get_name(), b.box_extent.x, b.box_extent.y,
                                                          b.box_extent.z, uvs))
    if not meta or "_error" in meta:
        return
    want = len(meta.get("uv_layers") or ())
    if want and uvs >= 0 and uvs != want:
        _warn("%s: %d uv channels, sidecar lists %d (%s)" % (mesh.get_name(), uvs, want, meta.get("uv_layers")))
    for w in plan.uv_layer_warnings(meta):
        _warn(w)
    if meta.get("color_attr"):
        try:
            if not sme.has_vertex_colors(mesh):
                _warn("%s: sidecar has vertex colours but the mesh imported none" % mesh.get_name())
        except Exception:
            pass


def import_meshes(export_dir=None):
    """Every *_Mars_SM.fbx of the food export, then collision (none on the oil meshes, which also get full-precision
    UVs) and the slot assignment from the sidecars."""
    if mc._in_pie():
        raise RuntimeError("stop PIE before importing (assets imported during PIE vanish)")
    src = plan.food_dir(export_dir)
    files = sorted(glob.glob(os.path.join(src, "*_Mars_SM.fbx")))
    if not files:
        _warn("no *_Mars_SM.fbx in %s" % src)
        return []
    metas = {m["name"]: m for m in plan.read_metas(src)}
    names = [os.path.splitext(os.path.basename(p))[0] for p in files]
    tasks = [_mesh_task(path, name) for path, name in zip(files, names)]
    cvar = "Interchange.FeatureFlags.Import.FBX"            # the legacy importer honours FbxImportUI
    was = unreal.SystemLibrary.get_console_variable_bool_value(cvar)
    unreal.SystemLibrary.execute_console_command(None, "%s 0" % cvar)
    try:
        mc._tools().import_asset_tasks(tasks)
    finally:
        unreal.SystemLibrary.execute_console_command(None, "%s %d" % (cvar, 1 if was else 0))
    sme = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
    done = []
    for name in names:
        mesh = mc._asset(F_MESH, name)
        if mesh is None:
            _warn("mesh %s did not import" % name)
            continue
        meta = metas.get(name)
        if meta is None:
            _warn("%s has no sidecar: imported, but it gets no slot assignment" % name)
        elif "_error" in meta:
            _warn("%s: sidecar unreadable (%s)" % (name, meta["_error"]))
        kind = plan.classify(meta) if meta and "_error" not in meta else None
        oil = kind == "oil" or name.startswith("Oil")
        _collision(sme, mesh, not oil)
        ing = plan.parse_name(name)[1]
        if fs.INGREDIENTS.get(ing, {}).get("cpu_access"):
            _cpu_access(sme, mesh)                              # runtime slicing (HerbPile, Mushroom) reads the buffers
        if oil and kind != "particle":
            _full_precision_uvs(sme, mesh)
            reach = float(((meta or {}).get("vat") or {}).get("max_offset_cm") or 8.0)
            for side in ("positive_bounds_extension", "negative_bounds_extension"):
                _set(mesh, side, unreal.Vector(reach, reach, reach))      # the VAT moves verts off the rest disc
        _check_mesh(sme, mesh, meta)
        EAL.save_loaded_asset(mesh)
        done.append(name)
    _log("%d of %d meshes imported from %s" % (len(done), len(names), src))
    assign_mesh_materials(export_dir)
    return done


def assign_mesh_materials(export_dir=None):
    """Every mesh with a sidecar: cooking slots -> the ingredient's instance (Batter -> the batter instance, the core of
    a battered mesh -> <Ing>_BatteredCore_Mars_MI), static slots -> the accent / salt / oil instance."""
    metas = [m for m in plan.read_metas(plan.food_dir(export_dir)) if "_error" not in m]
    missing, unknown, assigned = set(), [], 0
    for meta in metas:
        mesh = mc._asset(F_MESH, meta["name"])
        if mesh is None:
            continue
        sidecar_slots = set(plan.slots_of(meta))
        changed = False
        for i, slot in enumerate(mesh.get_editor_property("static_materials")):
            name = plan.clean_slot(slot.get_editor_property("material_slot_name"))
            if sidecar_slots and name not in sidecar_slots:
                _warn("%s: slot %s is not in its sidecar %s" % (meta["name"], name, sorted(sidecar_slots)))
            mi_name = plan.resolve_material(meta["name"], name, meta)
            if mi_name is None:
                unknown.append("%s.%s" % (meta["name"], name))
                continue
            mi = mc._asset(F_INST, mi_name)
            if mi is None:
                missing.add(mi_name)
                continue
            mesh.set_material(i, mi)
            changed = True
            assigned += 1
        if changed:
            EAL.save_loaded_asset(mesh)
    for u in unknown:
        _warn("unknown slot %s (not in food_spec.SLOTS_*), left as is" % u)
    if missing:
        _log("instances not built yet (run build_materials): %s" % ", ".join(sorted(missing)))
    _log("%d slots assigned" % assigned)


# ------------------------------------------------------------------ material building
_RETIRED = []      # (package path, object name, is_function)


def _retire(asset, name, is_function):
    aside = "%s/%s_retired" % (F_MAT, name)
    if EAL.rename_loaded_asset(asset, aside):
        _RETIRED.append((aside, name + "_retired", is_function))
        return True
    return False


def _fresh_master(name):
    """mc._fresh_material for the food Materials folder (mc's is hard-wired to the cooking folder): a brand-new master
    at the path; an existing one is renamed aside, build_instances re-parents its instances, _drop_retired deletes it."""
    m = mc._asset(F_MAT, name)
    if m is not None:
        stale = mc._asset(F_MAT, name + "_retired")
        if stale is not None:                  # left by an interrupted build: its instances come back first
            for data in MEL.get_child_instances(stale):
                inst = data.get_asset()
                MEL.set_material_instance_parent(inst, m)
                EAL.save_loaded_asset(inst)
            EAL.delete_loaded_asset(stale)
            unreal.SystemLibrary.collect_garbage()
        if not _retire(m, name, False):
            MEL.delete_all_material_expressions(m)
            _warn("%s could not be moved aside, wiped in place (Custom nodes may linger)" % name)
            return m
    return mc._tools().create_asset(name, F_MAT, unreal.Material, unreal.MaterialFactoryNew())


def _fresh_function(name):
    f = mc._asset(F_MAT, name)
    if f is not None:
        stale = mc._asset(F_MAT, name + "_retired")
        if stale is not None:
            EAL.delete_loaded_asset(stale)
            unreal.SystemLibrary.collect_garbage()
        if not _retire(f, name, True):
            MEL.delete_all_material_expressions_in_function(f)
            _warn("%s could not be moved aside, wiped in place" % name)
            return f
    return mc._tools().create_asset(name, F_MAT, unreal.MaterialFunction, unreal.MaterialFunctionFactoryNew())


def _drop_retired():
    """Delete the retired masters, then the retired function they referenced."""
    for want_function in (False, True):
        for entry in [r for r in _RETIRED if r[2] == want_function]:
            _RETIRED.remove(entry)
            path, obj_name, _ = entry
            obj_path = "%s.%s" % (path, obj_name)
            obj = mc._load(obj_path)
            ok = EAL.delete_loaded_asset(obj) if obj is not None else True
            unreal.SystemLibrary.collect_garbage()
            if not ok or unreal.find_object(None, obj_path) is not None:
                _warn("retired %s could not be deleted, left in place (safe to delete by hand)" % path)


def _release_masters():
    """mc._release_masters for the food masters: replacing a master the open level draws asserts in the renderer
    (UniformExpressionCache should be up to date), so the food lookdev map is swapped for a blank map and any other
    map that uses them is refused."""
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    if world is None:
        return
    users = set()
    for actor in unreal.get_editor_subsystem(unreal.EditorActorSubsystem).get_all_level_actors():
        for comp in actor.get_components_by_class(unreal.MeshComponent):
            for mat in comp.get_materials():
                base = mat.get_base_material() if mat is not None else None
                if base is not None and base.get_name().replace("_retired", "") in plan.MASTERS:
                    users.add(actor.get_actor_label())
    if not users:
        return
    current = world.get_outermost().get_name()
    if current != LOOKDEV_MAP:
        raise RuntimeError("%s draws the food masters (%s); open another map before rebuilding them"
                           % (current, ", ".join(sorted(users)[:5])))
    unreal.EditorLoadingAndSavingUtils.new_blank_map(False)
    unreal.SystemLibrary.collect_garbage()


def _require(name):
    tex = mc._asset(F_TEX, name)
    if tex is None:
        raise RuntimeError("texture %s missing: run import_textures() first" % name)
    return tex


def _report_material(m):
    try:
        st = MEL.get_statistics(m)
        vs = st.get_editor_property("num_vertex_shader_instructions")
        ps = st.get_editor_property("num_pixel_shader_instructions")
        vts = st.get_editor_property("num_vertex_texture_samples")
        _log("%s: %d expressions, VS %d / PS %d instructions, %d vertex texture samples"
             % (m.get_name(), MEL.get_num_material_expressions(m), vs, ps, vts))
        if ps <= 0:
            _warn("%s reports 0 pixel instructions (a compile error, or still compiling): open it and read the errors"
                  % m.get_name())
    except Exception as exc:
        _log("%s: %d expressions (no statistics: %s)" % (m.get_name(), MEL.get_num_material_expressions(m), exc))


class _FnGraph(mc._Graph):
    """mc._Graph inside a material function: same parameter columns, expressions created in the function."""

    def expr(self, cls, x, y):
        return MEL.create_material_expression_in_function(self.m, cls, x, y)


def _vec4f(x, y=0.0, z=0.0, w=0.0):
    """FVector4f is opaque in this build's Python (no ctor args, no fields): fill it through import_text."""
    try:
        v = unreal.Vector4f()
        v.import_text("(X=%f,Y=%f,Z=%f,W=%f)" % (x, y, z, w))
        return v
    except Exception:
        return None


def _fn_type(*names):
    for n in names:
        v = getattr(unreal.FunctionInputType, n, None)
        if v is not None:
            return v
    return None


FN_SCALAR = ("FUNCTION_INPUT_SCALAR",)
FN_VECTOR2 = ("FUNCTION_INPUT_VECTOR2",)
FN_VECTOR3 = ("FUNCTION_INPUT_VECTOR3",)
FN_VECTOR4 = ("FUNCTION_INPUT_VECTOR4",)


def _fn_input(g, name, kind, prio, preview, x, y, desc=""):
    """A FunctionInput with a preview value used as its default (so callers may leave it unconnected)."""
    e = g.expr(unreal.MaterialExpressionFunctionInput, x, y)
    e.set_editor_property("input_name", name)
    t = _fn_type(*kind)
    if t is not None:
        _set(e, "input_type", t)
    else:
        _warn("%s: FunctionInputType %s not found, input %s keeps its default type" % (g.m.get_name(), kind, name))
    _set(e, "sort_priority", prio)
    _set(e, "description", desc)
    _set(e, "use_preview_value_as_default", True)
    v = _vec4f(*(tuple(preview) + (0.0, 0.0, 0.0, 0.0))[:4]) if isinstance(preview, (tuple, list)) else _vec4f(preview)
    if v is not None:
        _set(e, "preview_value", v)
    return e


def _fn_output(g, name, prio, src, out, x, y, desc=""):
    o = g.expr(unreal.MaterialExpressionFunctionOutput, x, y)
    o.set_editor_property("output_name", name)
    _set(o, "sort_priority", prio)
    _set(o, "description", desc)
    g.link(src, out, o, "")
    return o


def _call(g, fn, pins, x, y):
    """A MaterialFunctionCall of fn wired from pins [(function input, source node, source output)]; None (and the
    node removed) when the call does not take the pins, so the caller can inline the graph instead."""
    if fn is None:
        return None
    call, ok = None, False
    try:
        call = g.expr(unreal.MaterialExpressionMaterialFunctionCall, x, y)
        try:
            call.set_material_function(fn)                       # exposed in this build; refreshes the pins
        except Exception:
            call.set_editor_property("material_function", fn)    # PostEditChange -> SetMaterialFunctionEx
        ok = all(MEL.connect_material_expressions(src, out, call, pin) for pin, src, out in pins)
    except Exception as exc:
        _warn("%s: %s call failed (%s)" % (g.m.get_name(), fn.get_name(), exc))
    if ok:
        return call
    _warn("%s: the %s call did not take its pins, inlining it" % (g.m.get_name(), fn.get_name()))
    if call is not None:
        try:
            MEL.delete_material_expression(g.m, call)
        except Exception:
            pass
    return None


def _coat_params(g):
    strength = g.scalar("Oil Coat Strength", 0.8, 0.0, 1.0, "Clear coat at oil 1 (oil, glaze and raw wetness all come through here).")
    coat_rough = g.scalar("Oil Coat Roughness", 0.12, 0.0, 0.5, "Roughness of the coat.")
    coat_breakup = g.scalar("Oil Coat Breakup", 0.35, 0.0, 1.0, "How patchy the coat sits (the Breakup mask).")
    base_gloss = g.scalar("Oil Base Gloss", 0.6, 0.0, 1.0, "Roughness multiplier under a full coat: oil wets and glosses what it covers.")
    return strength, coat_rough, coat_breakup, base_gloss


def build_oil_coat_function():
    """OilCoat_Mars_MF: Oil (0..1), Breakup (mask, 0.5 neutral), Roughness In -> ClearCoat, ClearCoatRoughness,
    Roughness Out. Its four parameters (group "10 Oil Coat (shared)") appear on every instance of the masters that call it."""
    f = _fresh_function(plan.OIL_COAT_MF)
    _set(f, "description", "Shared oil / glaze coat of the Mars food masters: clear coat amount, coat roughness and the "
                           "roughness under the coat.")
    _set(f, "expose_to_library", True)
    g = _FnGraph(f, x0=-1700, y0=-700)
    g.group("10 Oil Coat (shared)")
    strength, coat_rough, coat_breakup, base_gloss = _coat_params(g)
    scalar_type = _enum(unreal.FunctionInputType, "FUNCTION_INPUT_SCALAR", "FUNCTIONINPUT_SCALAR")
    if scalar_type is None:
        try:
            scalar_type = unreal.FunctionInputType.cast(0)          # FunctionInput_Scalar is the first entry
        except Exception:
            _warn("no scalar FunctionInputType; OilCoat_Mars_MF inputs stay Vector3 (OIL_COAT reads .x)")
    ins = {}
    previews = (0.0, 0.5, 0.5)
    descs = ("Oil / glaze / wetness amount 0..1.", "Coat break-up mask (mask B), 0.5 neutral.", "Surface roughness before the coat.")
    for i, (name, preview, desc) in enumerate(zip(plan.COAT_INPUTS, previews, descs)):
        e = g.expr(unreal.MaterialExpressionFunctionInput, -1100, -500 + i * 170)
        e.set_editor_property("input_name", name)
        if scalar_type is not None:
            _set(e, "input_type", scalar_type)
        _set(e, "sort_priority", i)
        _set(e, "description", desc)
        _set(e, "use_preview_value_as_default", True)
        v = _vec4f(preview)
        if v is not None:
            _set(e, "preview_value", v)
        ins[name] = e
    cu = g.custom("OilCoat: oil -> clear coat, gloss under it", hlsl.OIL_COAT, (
        ("Oil", ins[plan.COAT_INPUTS[0]], ""), ("Breakup", ins[plan.COAT_INPUTS[1]], ""),
        ("RoughIn", ins[plan.COAT_INPUTS[2]], ""), ("Strength", strength, ""), ("CoatBreakup", coat_breakup, ""),
        ("BaseGloss", base_gloss, "")), -700, -500, FLOAT1, (("RoughOut", FLOAT1),))
    for i, (name, (src, out)) in enumerate(zip(plan.COAT_OUTPUTS, ((cu, ""), (coat_rough, ""), (cu, "RoughOut")))):
        o = g.expr(unreal.MaterialExpressionFunctionOutput, -250, -500 + i * 170)
        o.set_editor_property("output_name", name)
        _set(o, "sort_priority", i)
        g.link(src, out, o, "")
    MEL.update_material_function(f)
    EAL.save_loaded_asset(f)
    _log("%s: %d expressions" % (f.get_name(), MEL.get_num_material_expressions_in_function(f)))
    return f


def _coat(g, coat, surf, x, y):
    """The OilCoat_Mars_MF call fed by a surface node's Oil / Patch / Roughness outputs. If the call node does not
    take the function's pins, the same HLSL is inlined with the same parameter names so the master still compiles.
    Returns {ClearCoat, ClearCoatRoughness, Roughness: (node, output)}."""
    call = _call(g, coat, [(pin, surf, out) for out, pin in zip(("Oil", "Patch", "Roughness"), plan.COAT_INPUTS)], x, y)
    if call is not None:
        return dict(zip(("ClearCoat", "ClearCoatRoughness", "Roughness"), ((call, o) for o in plan.COAT_OUTPUTS)))
    g.group("10 Oil Coat (inline)")
    strength, coat_rough, coat_breakup, base_gloss = _coat_params(g)
    cu = g.custom("OilCoat (inline fallback)", hlsl.OIL_COAT, (
        ("Oil", surf, "Oil"), ("Breakup", surf, "Patch"), ("RoughIn", surf, "Roughness"), ("Strength", strength, ""),
        ("CoatBreakup", coat_breakup, ""), ("BaseGloss", base_gloss, "")), x, y, FLOAT1, (("RoughOut", FLOAT1),))
    return {"ClearCoat": (cu, ""), "ClearCoatRoughness": (coat_rough, ""), "Roughness": (cu, "RoughOut")}


def build_vertex_decode_function():
    """VertexColorDecode_Mars_MF: (sRGB Decode 0/1, Cavity AO 0..1) -> Base Colour, AO, Cavity. Any material that
    paints from the food vertex colours can call it; the caller feeds its own parameters into the two inputs."""
    f = _fresh_function(plan.VERTEX_DECODE_MF)
    _set(f, "description", "Mars food vertex colours: RGB painted albedo (as the FBX holds it) and A cavity. sRGB Decode 1 "
                           "treats RGB as sRGB-encoded (pow 2.2); the food exports are linear, so callers pass 0.")
    _set(f, "expose_to_library", True)
    g = _FnGraph(f, x0=-1600, y0=-500)
    s = _fn_input(g, "sRGB Decode", FN_SCALAR, 0, 0.0, -1100, -500, "1 = decode sRGB-encoded vertex colour.")
    a = _fn_input(g, "Cavity AO", FN_SCALAR, 1, 0.4, -1100, -330, "How much the cavity (alpha) occludes.")
    vc = g.expr(unreal.MaterialExpressionVertexColor, -1100, -160)
    dec = g.custom("VertexDecode: vertex colour -> base, cavity -> AO", hlsl.VERTEX_DECODE, (
        ("VC", vc, ""), ("Cavity", vc, "A"), ("SrgbDecode", s, ""), ("CavityAO", a, "")), -750, -400, FLOAT3,
        (("AO", FLOAT1),))
    _fn_output(g, "Base Colour", 0, dec, "", -300, -500)
    _fn_output(g, "AO", 1, dec, "AO", -300, -330)
    _fn_output(g, "Cavity", 2, vc, "A", -300, -160)
    MEL.update_material_function(f)
    EAL.save_loaded_asset(f)
    _log("%s: %d expressions" % (f.get_name(), MEL.get_num_material_expressions_in_function(f)))
    return f


def _vertex_base(g, srgb, cav_ao, x, y, fn=None):
    """Decoded vertex colour: {base, ao, cavity: (node, output)} through VertexColorDecode_Mars_MF, inlined if the
    call does not take."""
    call = _call(g, fn, [("sRGB Decode", srgb, ""), ("Cavity AO", cav_ao, "")], x + 300, y)
    if call is not None:
        return {"base": (call, "Base Colour"), "ao": (call, "AO"), "cavity": (call, "Cavity")}
    vc = g.expr(unreal.MaterialExpressionVertexColor, x, y)
    base = g.custom("VertexDecode: vertex colour -> base, cavity -> AO", hlsl.VERTEX_DECODE, (
        ("VC", vc, ""), ("Cavity", vc, "A"), ("SrgbDecode", srgb, ""), ("CavityAO", cav_ao, "")),
        x + 300, y, FLOAT3, (("AO", FLOAT1),))
    return {"base": (base, ""), "ao": (base, "AO"), "cavity": (vc, "A")}


def _sear_params(g):
    return {
        "sear_range": g.scalar("Sear Range", 2.0, 0.5, 4.0, "Sear value that reaches full browning time."),
        "sharp": g.scalar("Face Sharpness", 4.0, 1.0, 16.0, "How strictly a sear value stays on its own side. Lower "
                          "blends around round shapes."),
        "breakup": g.scalar("Crust Breakup", 0.3, 0.0, 1.5, "Patchiness of the browning (mask B)."),
        "edge_boost": g.scalar("Edge Boost", 0.35, 0.0, 1.0, "Extra sear on edges (mask A)."),
        "band_depth": g.scalar("Band Depth", 1.5, 0.0, 6.0, "Centimetres the cooked band reaches in from the bounds at "
                               "Penetration 1."),
        "band_soft": g.scalar("Band Softness", 0.55, 0.05, 1.0, "Softness of the band's leading edge."),
        "band_wobble": g.scalar("Band Wobble", 0.5, 0.0, 2.0, "Centimetres of irregularity on the band edge."),
        "band_ramp": g.scalar("Band Ramp Position", 0.24, 0.0, 0.5, "Browning time the cooked band shows."),
        "lag": g.scalar("Crevice Lag", 0.6, 0.0, 1.0, "How much later the crevices brown (cook-first = mask R x vertex "
                        "cavity). 0 = everything browns together."),
    }


def _cook_graph(g, p, sa, sb, da, db, use_dbg, mask, cavity, x, y):
    """FOOD_COOK_FIRST -> MEAT_COOK on the given sources; returns the MEAT_COOK node (time, crust, burn, oil)."""
    lp, ln = g.local_space(x - 700, y + 350)
    bounds = g.expr(unreal.MaterialExpressionObjectLocalBounds, x - 440, y + 690)
    first = g.custom("FoodCookFirst: crevices sear later", hlsl.FOOD_COOK_FIRST, (
        ("SearA",) + sa, ("SearB",) + sb, ("DbgA",) + da, ("DbgB",) + db, ("UseDebug",) + use_dbg,
        ("Mask",) + mask, ("Cavity",) + cavity, ("Lag", p["lag"], "")), x - 300, y, FLOAT4, (("SearZ", FLOAT4),))
    return g.custom("MeatCook (mars_cooking_hlsl): sear -> time, crust, burn, oil", mhlsl.MEAT_COOK, (
        ("P", lp, ""), ("N", ln, ""), ("BMin", bounds, "Min"), ("BMax", bounds, "Max"),
        ("SearA", first, ""), ("SearB", first, "SearZ"), ("DbgA", first, ""), ("DbgB", first, "SearZ"),
        ("UseDebug",) + use_dbg, ("Mask",) + mask, ("Sharp", p["sharp"], ""), ("Breakup", p["breakup"], ""),
        ("EdgeBoost", p["edge_boost"], ""), ("BandDepth", p["band_depth"], ""), ("BandSoft", p["band_soft"], ""),
        ("BandWobble", p["band_wobble"], ""), ("BandRamp", p["band_ramp"], ""), ("SearRange", p["sear_range"], "")),
        x + 100, y + 250, FLOAT4)


def build_food_cook_function():
    """FoodCook_Mars_MF: the cook model (sear per local axis + penetration band + cook-first crevices) as a function.
    Inputs Sear XY, Sear Z + Cook (the CPD vectors, debug already resolved by the caller), Mask (RGBA), Cavity ->
    Cook = (browning time, crust, burn, oil coat). Its nine tunables (group "04 Sear") appear on the caller's instances."""
    f = _fresh_function(plan.FOOD_COOK_MF)
    _set(f, "description", "Mars food cook model: Sear XY (+X -X +Y -Y), Sear Z + Cook (+Z -Z Penetration OilCoat), "
                           "Mask (R cook-first, B break-up, A edge), Cavity -> Cook (time, crust, burn, oil).")
    _set(f, "expose_to_library", True)
    g = _FnGraph(f, x0=-3000, y0=-900)
    g.group("04 Sear")
    p = _sear_params(g)
    a = _fn_input(g, "Sear XY", FN_VECTOR4, 0, (0.0, 0.0, 0.0, 0.0), -2400, -900, "Sear +X -X +Y -Y (0 raw, 1 crust, 2 burnt).")
    b = _fn_input(g, "Sear Z + Cook", FN_VECTOR4, 1, (0.0, 0.0, 0.0, 0.0), -2400, -730, "Sear +Z -Z, Penetration, Oil Coat.")
    m = _fn_input(g, "Mask", FN_VECTOR4, 2, (1.0, 0.5, 0.5, 0.0), -2400, -560, "R cook-first, G grain, B break-up, A edge.")
    c = _fn_input(g, "Cavity", FN_SCALAR, 3, 1.0, -2400, -390, "Vertex-colour cavity (1 open).")
    zero = g.expr(unreal.MaterialExpressionConstant, -2400, -220)
    _set(zero, "r", 0.0)
    cook = _cook_graph(g, p, (a, ""), (b, ""), (a, ""), (b, ""), (zero, ""), (m, ""), (c, ""), -1500, -900)
    _fn_output(g, "Cook", 0, cook, "", -800, -700, "Browning time, crust, burn, oil coat.")
    MEL.update_material_function(f)
    EAL.save_loaded_asset(f)
    _log("%s: %d expressions" % (f.get_name(), MEL.get_num_material_expressions_in_function(f)))
    return f


def _food_cook(g, fn, sear_a, sear_b, dbg_a, dbg_b, use_dbg, mask, cavity, x, y):
    """(node, output) of the cook vector: FoodCook_Mars_MF fed with the debug-resolved CPD vectors, or the same graph
    inlined in the master (with its own Sear parameters) if the call does not take."""
    if fn is not None:
        la = g.expr(unreal.MaterialExpressionLinearInterpolate, x - 300, y)
        g.link(sear_a, "RGBA", la, "A")
        g.link(dbg_a, "RGBA", la, "B")
        g.link(use_dbg, "", la, "Alpha")
        lb = g.expr(unreal.MaterialExpressionLinearInterpolate, x - 300, y + 160)
        g.link(sear_b, "RGBA", lb, "A")
        g.link(dbg_b, "RGBA", lb, "B")
        g.link(use_dbg, "", lb, "Alpha")
        call = _call(g, fn, [("Sear XY", la, ""), ("Sear Z + Cook", lb, ""), ("Mask", mask, "RGBA"),
                             ("Cavity",) + cavity], x, y)
        if call is not None:
            return (call, "Cook")
    g.group("04 Sear (inline)")
    p = _sear_params(g)
    cook = _cook_graph(g, p, (sear_a, "RGBA"), (sear_b, "RGBA"), (dbg_a, "RGBA"), (dbg_b, "RGBA"), (use_dbg, ""),
                       (mask, "RGBA"), cavity, x, y)
    return (cook, "")


SRGB_DESC = ("1 = treat the vertex colour as sRGB-encoded and decode it (pow 2.2). The FBX importer hands the material "
             "exactly the values in the FBX, and the food FBXs are exported with linear colours, so 0 should be right; "
             "the lookdev swatch row checks it.")


# ------------------------------------------------------------------ Food_Mars_M
def build_food_master(fns):
    coat = fns.get("coat")
    m = _fresh_master(plan.MASTER_FOOD)
    m.set_editor_property("shading_model", unreal.MaterialShadingModel.MSM_CLEAR_COAT)
    g = mc._Graph(m, x0=-5800)

    g.group("01 Driven (Custom Primitive Data)")
    sear_a = g.vector("Sear XY", (0, 0, 0, 0), "Sear per local axis: 0 raw, 1 full crust, 2 burnt. Custom Primitive Data 0-3.",
                      SEAR_XY, cpd=fs.CPD["SearXY"])
    sear_b = g.vector("Sear Z + Cook", (0, 0, 0, 0), "Sear on +Z / -Z, Penetration 0..1 and Oil Coat 0..1. Custom Primitive "
                      "Data 4-7.", SEAR_Z, cpd=fs.CPD["SearZCook"])
    fin = g.vector("Finish", (0, 0, 0, 0), "Glaze 0..1, Shape 0..1 (raw -> cooked morph), Fry 0..2 (batter only), Wet 0..1 "
                   "(stew / soup soak). Custom Primitive Data 8-11.", FINISH, cpd=fs.CPD["Finish"])

    g.group("02 Debug Override")
    use_dbg = g.scalar("Debug Use Sliders", 0.0, 0.0, 1.0, "1 = ignore Custom Primitive Data and use the three vectors below "
                       "(look tuning in an instance; leave 0 in game).")
    dbg_a = g.vector("Debug Sear XY", (0, 0, 0, 0), "", SEAR_XY)
    dbg_b = g.vector("Debug Sear Z + Cook", (0, 0, 1, 0), "", SEAR_Z)
    dbg_f = g.vector("Debug Finish", (0, 0, 0, 0), "", FINISH)

    g.group("03 Base Colour")
    srgb = g.scalar("Vertex Colour sRGB", 0.0, 0.0, 1.0, SRGB_DESC)
    cav_ao = g.scalar("Cavity AO", 0.4, 0.0, 1.0, "Ambient occlusion from the vertex-colour cavity (alpha).")

    g.group("05 Browning")
    cooked_tint = g.vector("Cooked Tint", (0.88, 0.78, 0.68, 1.0), "Multiplier the cooked-through state puts on the base colour.")
    cooked_at = g.scalar("Cooked At", 0.24, 0.01, 1.0, "Browning time at which the cooked tint is complete.")
    crust_col = g.vector("Crust Colour", (0.75, 0.6, 0.45, 1.0), "Multiplier at full crust (darkens and warms).")
    crust_albedo = g.vector("Crust Albedo", (0.17, 0.08, 0.035, 1.0), "Browned-crust colour the crust pulls toward.")
    crust_replace = g.scalar("Crust Replace", 0.55, 0.0, 1.0, "How far full crust pulls the colour to Crust Albedo "
                             "(a saturated painted base otherwise only gets redder).")
    char_col = g.vector("Char Colour", (0.025, 0.018, 0.014, 1.0), "Colour burnt food goes to (replaces, not multiplies).")
    grain = g.scalar("Grain Contrast", 0.2, 0.0, 1.0, "Strength of the grain / speckle in the colour (mask G).")

    g.group("06 Textures")
    uv0 = g.expr(unreal.MaterialExpressionTextureCoordinate, g.x0 + g.col * g.COL_W - 260, g.y0)
    mask = g.texture("Mask", _require(plan.NEUTRAL_MASK), SAMPLER_MASKS, uv0,
                     "R cook-first, G grain (0.5 neutral), B crust break-up (0.5 neutral), A edge.")
    nrm = g.texture("Normal", _require(plan.FLAT_NORMAL), SAMPLER_NORMAL, uv0, "Optional fine relief; flat by default.")
    nrm_raw = g.scalar("Normal Raw", 0.3, 0.0, 2.0, "Normal strength while raw.")
    nrm_crust = g.scalar("Normal Crust", 0.6, 0.0, 3.0, "Normal strength of the crust.")

    g.group("07 Surface")
    r_raw = g.scalar("Roughness Raw", 0.45)
    r_crust = g.scalar("Roughness Crust", 0.72)
    r_burnt = g.scalar("Roughness Burnt", 0.9)

    g.group("08 Wet + Glaze")
    raw_wet = g.scalar("Raw Wetness", 0.4, 0.0, 1.0, "Coat of the raw, moist surface (fades as the crust forms).")
    glaze_strength = g.scalar("Glaze Strength", 1.0, 0.0, 1.0, "Coat at Glaze 1.")
    wet_darken = g.scalar("Wet Darken", 0.15, 0.0, 0.5, "How much darker Wet 1 makes the colour.")
    wet_gloss = g.scalar("Wet Gloss", 0.55, 0.0, 1.0, "Roughness multiplier at Wet 1.")

    g.group("09 Shape")
    shape_scale = g.scalar("Shape Scale", 1.0, 0.0, 2.0, "Multiplier on the baked raw -> cooked offset (UV1 / UV2). The "
                           "build sets 0 on ingredients exported without a morph.")

    x = -1500
    vtx = _vertex_base(g, srgb, cav_ao, x - 700, -1500, fns.get("decode"))
    cook = _food_cook(g, fns.get("cook"), sear_a, sear_b, dbg_a, dbg_b, use_dbg, mask, vtx["cavity"], x, -1100)
    surf = g.custom("FoodSurface: browning chain, roughness, coat amount", hlsl.FOOD_SURFACE, (
        ("Base",) + vtx["base"], ("Cook",) + cook, ("Mask", mask, "RGBA"), ("Fin", fin, "RGBA"), ("DbgFin", dbg_f, "RGBA"),
        ("UseDebug", use_dbg, ""), ("CookedTint", cooked_tint, ""), ("CookedAt", cooked_at, ""),
        ("CrustColor", crust_col, ""), ("CrustAlbedo", crust_albedo, ""), ("CrustReplace", crust_replace, ""),
        ("CharColor", char_col, ""), ("GrainContrast", grain, ""),
        ("RoughRaw", r_raw, ""), ("RoughCrust", r_crust, ""), ("RoughBurnt", r_burnt, ""), ("RawWet", raw_wet, ""),
        ("GlazeStrength", glaze_strength, ""), ("WetDarken", wet_darken, ""), ("WetGloss", wet_gloss, ""),
        ("NrmRaw", nrm_raw, ""), ("NrmCrust", nrm_crust, "")), x + 700, -900, FLOAT3,
        (("Roughness", FLOAT1), ("Oil", FLOAT1), ("Patch", FLOAT1), ("NormalStrength", FLOAT1)))
    oil = _coat(g, coat, surf, x + 1150, -800)
    normal = g.custom("MeatNormal (mars_cooking_hlsl)", mhlsl.MEAT_NORMAL,
                      (("Nrm", nrm, "RGB"), ("Strength", surf, "NormalStrength")), x + 1150, -300)
    uv1 = g.expr(unreal.MaterialExpressionTextureCoordinate, x + 400, 200)
    uv1.set_editor_property("coordinate_index", 1)
    uv2 = g.expr(unreal.MaterialExpressionTextureCoordinate, x + 400, 320)
    uv2.set_editor_property("coordinate_index", 2)
    shape = g.custom("MeatShape (mars_cooking_hlsl): raw -> cooked offset (local cm)", mhlsl.MEAT_SHAPE, (
        ("UV1", uv1, ""), ("UV2", uv2, ""), ("Fin", fin, "RGBA"), ("DbgFin", dbg_f, "RGBA"), ("UseDebug", use_dbg, ""),
        ("Scale", shape_scale, "")), x + 700, 200)
    wpo = g.to_world(shape, "", x + 1150, 200)
    g.finish({"BaseColor": (surf, ""), "Roughness": oil["Roughness"], "Normal": (normal, ""),
              "ClearCoat": oil["ClearCoat"], "ClearCoatRoughness": oil["ClearCoatRoughness"],
              "WorldPositionOffset": (wpo, ""), "AmbientOcclusion": vtx["ao"]}, x + 1650, -700)
    return m


# ------------------------------------------------------------------ Batter_Mars_M
def build_batter_master(fns):
    coat = fns.get("coat")
    m = _fresh_master(plan.MASTER_BATTER)
    m.set_editor_property("shading_model", unreal.MaterialShadingModel.MSM_CLEAR_COAT)
    g = mc._Graph(m, x0=-5200)

    g.group("01 Driven (Custom Primitive Data)")
    sear_b = g.vector("Sear Z + Cook", (0, 0, 0, 0), "Only Oil Coat (alpha) is read here. Custom Primitive Data 4-7.",
                      SEAR_Z, cpd=fs.CPD["SearZCook"])
    fin = g.vector("Finish", (0, 0, 0, 0), "Fry (blue) 0 raw batter, 1 golden, 2 burnt. Custom Primitive Data 8-11.",
                   FINISH, cpd=fs.CPD["Finish"])

    g.group("02 Debug Override")
    use_dbg = g.scalar("Debug Use Sliders", 0.0, 0.0, 1.0, "1 = ignore Custom Primitive Data and use the vectors below.")
    dbg_b = g.vector("Debug Sear Z + Cook", (0, 0, 1, 0), "", SEAR_Z)
    dbg_f = g.vector("Debug Finish", (0, 0, 1, 0), "", FINISH)

    g.group("03 Base Colour")
    srgb = g.scalar("Vertex Colour sRGB", 0.0, 0.0, 1.0, SRGB_DESC)
    cav_ao = g.scalar("Cavity AO", 0.4, 0.0, 1.0, "Ambient occlusion from the vertex-colour cavity (alpha).")

    g.group("04 Fry")
    golden = g.vector("Golden Tint", (0.85, 0.58, 0.28, 1.0), "Multiplier the pale raw batter goes to at Fry 1.")
    burnt = g.vector("Burnt Colour", (0.05, 0.03, 0.015, 1.0), "Colour at Fry 2.")
    edge_boost = g.scalar("Edge Boost", 0.4, 0.0, 1.0, "Drips and edges (mask A) colour first.")
    fry_breakup = g.scalar("Fry Breakup", 0.35, 0.0, 1.5, "Patchiness of the frying (mask B).")
    crumb = g.scalar("Crumb Contrast", 0.25, 0.0, 1.0, "Crumb light / dark in the colour (mask G).")

    g.group("05 Textures")
    uv0 = g.expr(unreal.MaterialExpressionTextureCoordinate, g.x0 + g.col * g.COL_W - 260, g.y0)
    mask = g.texture("Mask", _require(plan.NEUTRAL_MASK), SAMPLER_MASKS, uv0,
                     "G crumb (0.5 neutral), B fry break-up (0.5 neutral), A drips / edges.")
    nrm = g.texture("Normal", _require(plan.FLAT_NORMAL), SAMPLER_NORMAL, uv0, "Optional crumb relief; flat by default.")
    nrm_raw = g.scalar("Normal Raw", 0.15, 0.0, 2.0)
    nrm_fried = g.scalar("Normal Fried", 0.7, 0.0, 3.0)

    g.group("06 Surface")
    r_raw = g.scalar("Roughness Raw", 0.3, 0.0, 1.0, "Wet raw batter.")
    r_golden = g.scalar("Roughness Golden", 0.62)
    r_burnt = g.scalar("Roughness Burnt", 0.85)
    crumb_rough = g.scalar("Crumb Roughness", 0.25, 0.0, 1.0, "Roughness swing of the crumb (mask G) once fried.")
    raw_coat = g.scalar("Raw Coat", 0.85, 0.0, 1.0, "Coat of the wet raw batter (fades as it fries).")

    x = -1500
    vtx = _vertex_base(g, srgb, cav_ao, x - 700, -1300, fns.get("decode"))
    surf = g.custom("BatterSurface: raw -> golden -> burnt", hlsl.BATTER_SURFACE, (
        ("Base",) + vtx["base"], ("Mask", mask, "RGBA"), ("Fin", fin, "RGBA"), ("DbgFin", dbg_f, "RGBA"),
        ("SearB", sear_b, "RGBA"), ("DbgB", dbg_b, "RGBA"), ("UseDebug", use_dbg, ""), ("GoldenTint", golden, ""),
        ("BurntColor", burnt, ""), ("EdgeBoost", edge_boost, ""), ("FryBreakup", fry_breakup, ""),
        ("CrumbContrast", crumb, ""), ("RoughRaw", r_raw, ""), ("RoughGolden", r_golden, ""), ("RoughBurnt", r_burnt, ""),
        ("CrumbRough", crumb_rough, ""), ("RawCoat", raw_coat, ""), ("NrmRaw", nrm_raw, ""), ("NrmFried", nrm_fried, "")),
        x, -900, FLOAT3, (("Roughness", FLOAT1), ("Oil", FLOAT1), ("Patch", FLOAT1), ("NormalStrength", FLOAT1)))
    oil = _coat(g, coat, surf, x + 450, -800)
    normal = g.custom("MeatNormal (mars_cooking_hlsl)", mhlsl.MEAT_NORMAL,
                      (("Nrm", nrm, "RGB"), ("Strength", surf, "NormalStrength")), x + 450, -300)
    g.finish({"BaseColor": (surf, ""), "Roughness": oil["Roughness"], "Normal": (normal, ""),
              "ClearCoat": oil["ClearCoat"], "ClearCoatRoughness": oil["ClearCoatRoughness"],
              "AmbientOcclusion": vtx["ao"]}, x + 950, -700)
    return m


# ------------------------------------------------------------------ Accent_Mars_M / Salt_Mars_M
def build_accent_master(fns):
    """Static slots (horn, bone, leaf, stem, stone, wood): vertex colour x Tint, Roughness, Specular, cavity AO."""
    m = _fresh_master(plan.MASTER_ACCENT)
    g = mc._Graph(m, x0=-2600, y0=-900)
    g.group("01 Base Colour")
    srgb = g.scalar("Vertex Colour sRGB", 0.0, 0.0, 1.0, SRGB_DESC)
    tint = g.vector("Tint", (1.0, 1.0, 1.0, 1.0), "Multiplier on the vertex colour.")
    cav_ao = g.scalar("Cavity AO", 0.5, 0.0, 1.0, "Ambient occlusion from the vertex-colour cavity (alpha).")
    g.group("02 Surface")
    rough = g.scalar("Roughness", 0.6)
    spec = g.scalar("Specular", 0.5)
    vtx = _vertex_base(g, srgb, cav_ao, -1300, -800, fns.get("decode"))
    mul = g.expr(unreal.MaterialExpressionMultiply, -700, -800)
    g.link(*(vtx["base"] + (mul, "A")))
    g.link(tint, "", mul, "B")
    g.finish({"BaseColor": (mul, ""), "Roughness": (rough, ""), "Specular": (spec, ""),
              "AmbientOcclusion": vtx["ao"]}, -350, -800)
    return m


def build_salt_master(fns):
    """Salt / pepper crystals: Accent plus subsurface (opaque MSM_SUBSURFACE; Opacity is the scattering amount)."""
    m = _fresh_master(plan.MASTER_SALT)
    m.set_editor_property("shading_model", unreal.MaterialShadingModel.MSM_SUBSURFACE)
    g = mc._Graph(m, x0=-2600, y0=-900)
    g.group("01 Base Colour")
    srgb = g.scalar("Vertex Colour sRGB", 0.0, 0.0, 1.0, SRGB_DESC)
    tint = g.vector("Tint", (1.0, 1.0, 1.0, 1.0), "Multiplier on the vertex colour.")
    cav_ao = g.scalar("Cavity AO", 0.2, 0.0, 1.0)
    g.group("02 Crystal")
    rough = g.scalar("Roughness", 0.2)
    spec = g.scalar("Specular", 0.6)
    sss_col = g.vector("Subsurface Color", (0.92, 0.94, 0.97, 1.0), "Colour of the light scattered through the crystal.")
    sss_amount = g.scalar("Subsurface Amount", 0.7, 0.0, 1.0, "Scattering strength (the Opacity pin of the subsurface model).")
    vtx = _vertex_base(g, srgb, cav_ao, -1300, -800, fns.get("decode"))
    mul = g.expr(unreal.MaterialExpressionMultiply, -700, -800)
    g.link(*(vtx["base"] + (mul, "A")))
    g.link(tint, "", mul, "B")
    g.finish({"BaseColor": (mul, ""), "Roughness": (rough, ""), "Specular": (spec, ""),
              "SubsurfaceColor": (sss_col, ""), "Opacity": (sss_amount, ""), "AmbientOcclusion": vtx["ao"]}, -350, -800)
    return m


# ------------------------------------------------------------------ BubbleGlass_Mars_MF
def _glass_params(g):
    return {
        "rim": g.scalar("Rim Darken", 0.55, 0.0, 1.0, "How much darker the dome gets toward its silhouette (fresnel)."),
        "centre": g.scalar("Centre Brighten", 0.6, 0.0, 3.0, "How much brighter the dome gets where it faces the camera."),
        "film": g.scalar("Thin Film", 0.25, 0.0, 1.0, "Iridescent tint on the rim."),
        "back": g.scalar("Back Darken", 0.6, 0.0, 1.0, "Backfaces (the inside of a popping dome) as the liquid colour times this."),
        "rough": g.scalar("Roughness", 0.05, 0.0, 1.0),
        "spec": g.scalar("Specular", 1.0),
    }


def _glass_node(g, p, pins, x, y):
    """The BUBBLE_GLASS Custom node on the given (pin, node, output) sources for N / Pop / BubbleUV / LiquidColor /
    PopEdge / PopReach / PopWobble; view terms are built here."""
    cam = g.expr(unreal.MaterialExpressionCameraVectorWS, x - 300, y + 200)
    side = g.expr(unreal.MaterialExpressionTwoSidedSign, x - 300, y + 280)
    t = g.expr(unreal.MaterialExpressionTime, x - 300, y + 360)
    src = dict((pin, (node, out)) for pin, node, out in pins)
    return g.custom("BubbleGlass: fake glass + pop mask", hlsl.BUBBLE_GLASS, (
        ("N",) + src["N"], ("Pop",) + src["Pop"], ("CamV", cam, ""), ("Side", side, ""), ("BubbleUV",) + src["BubbleUV"],
        ("LiquidColor",) + src["LiquidColor"], ("RimDarken", p["rim"], ""), ("CentreBrighten", p["centre"], ""),
        ("ThinFilm", p["film"], ""), ("BackDarken", p["back"], ""), ("PopEdge",) + src["PopEdge"],
        ("PopReach",) + src["PopReach"], ("PopWobble",) + src["PopWobble"], ("T", t, "")), x, y, FLOAT3,
        (("Mask", FLOAT1), ("WorldN", FLOAT3)))


GLASS_INPUTS = (("Liquid Colour", "LiquidColor"), ("Pop", "Pop"), ("Pop Reach", "PopReach"), ("Pop Edge", "PopEdge"),
                ("Pop Wobble", "PopWobble"), ("BubbleLocal", "BubbleUV"), ("Normal WS", "N"))
GLASS_OUTPUTS = ("Base Colour", "Opacity Mask", "Roughness", "Specular", "Normal WS")


def build_bubble_glass_function():
    """BubbleGlass_Mars_MF: Liquid Colour, Pop, Pop Reach, Pop Edge, Pop Wobble, BubbleLocal (height, phase), Normal WS
    -> Base Colour, Opacity Mask, Roughness, Specular, Normal WS. Its look parameters (group "04 Glass": Rim Darken,
    Centre Brighten, Thin Film, Back Darken, Roughness, Specular) appear on every caller's instances."""
    f = _fresh_function(plan.BUBBLE_GLASS_MF)
    _set(f, "description", "Mars bubble look: opaque fake glass (fresnel rim, centre brighten, thin film, liquid "
                           "backfaces) and the pop mask (dissolve from the apex down to 1 - Pop Reach; Pop >= 0.999 hides).")
    _set(f, "expose_to_library", True)
    g = _FnGraph(f, x0=-2200, y0=-800)
    g.group("04 Glass")
    p = _glass_params(g)
    kinds = (FN_VECTOR3, FN_SCALAR, FN_SCALAR, FN_SCALAR, FN_SCALAR, FN_VECTOR2, FN_VECTOR3)
    previews = ((1.0, 1.0, 1.0), 0.0, 0.6, 0.04, 0.06, (0.0, 0.0), (0.0, 0.0, 1.0))
    ins = {}
    for i, ((name, pin), kind, preview) in enumerate(zip(GLASS_INPUTS, kinds, previews)):
        ins[pin] = _fn_input(g, name, kind, i, preview, -1500, -800 + i * 150)
    cu = _glass_node(g, p, [(pin, node, "") for pin, node in ins.items()], -900, -600)
    for i, (name, (src, out)) in enumerate(zip(GLASS_OUTPUTS, ((cu, ""), (cu, "Mask"), (p["rough"], ""), (p["spec"], ""),
                                                             (cu, "WorldN")))):
        _fn_output(g, name, i, src, out, -350, -800 + i * 150)
    MEL.update_material_function(f)
    EAL.save_loaded_asset(f)
    _log("%s: %d expressions" % (f.get_name(), MEL.get_num_material_expressions_in_function(f)))
    return f


def _bubble_glass(g, fn, sources, x, y):
    """{Base Colour, Opacity Mask, Roughness, Specular, Normal WS: (node, output)} through BubbleGlass_Mars_MF, or the
    same graph inlined (with its own Glass parameters) when the call does not take. sources: function input name ->
    (node, output)."""
    call = _call(g, fn, [(name,) + sources[name] for name, _ in GLASS_INPUTS], x, y)
    if call is not None:
        return dict((name, (call, name)) for name in GLASS_OUTPUTS)
    g.group("04 Glass (inline)")
    p = _glass_params(g)
    cu = _glass_node(g, p, [(pin,) + sources[name] for name, pin in GLASS_INPUTS], x, y)
    return {"Base Colour": (cu, ""), "Opacity Mask": (cu, "Mask"), "Roughness": (p["rough"], ""),
            "Specular": (p["spec"], ""), "Normal WS": (cu, "WorldN")}


# ------------------------------------------------------------------ OilVAT_Mars_M / OilBubble_Mars_M
def _vat_core(g, metas, vat, vat_tex, bubbles):
    """The VAT playback both oil masters share: UV from the VAT column + Time, both VAT textures sampled in the vertex
    shader, decoded offset -> WPO and the normal transformed local -> world (still in the vertex shader, ready to pack
    into the interpolator). Defaults come from the matching stem (bubbles or surface)."""
    stems = [s for s in sorted(set(vat) | set(vat_tex)) if plan.is_bubble(s) == bubbles]
    with_tex = [s for s in stems if vat_tex.get(s, {}).get("Pos")]
    first = (with_tex or stems or [None])[0]
    d = vat.get(first, {}) if first else {}
    pos_tex = mc._asset(F_TEX, vat_tex.get(first, {}).get("Pos")) if vat_tex.get(first, {}).get("Pos") else None
    nrm_tex = mc._asset(F_TEX, vat_tex.get(first, {}).get("Nrm")) if vat_tex.get(first, {}).get("Nrm") else None
    column, seen = plan.uv_index(metas, "VATColumn", 1, bubbles)
    if len(seen) > 1:
        _warn("%s: oil meshes disagree on the VAT UV channel %s; reading UV%d" % (g.m.get_name(), seen, column))

    g.group("01 Playback")
    speed = g.scalar("Speed", 1.0, -4.0, 4.0, "Playback rate (1 = the baked loop length).")
    seconds = g.scalar("Seconds", float(d.get("seconds", fs.OIL_SECONDS)), 0.1, 30.0, "Loop length (OilVAT_Mars.json).")
    frames = g.scalar("Frames", float(d.get("frames", fs.OIL_FRAMES)), 1.0, 2048.0, "Rows in the VAT (OilVAT_Mars.json).")
    flip = g.scalar("Flip V", float(d.get("flip_v", 0)), 0.0, 1.0, "1 when frame 0 is on the bottom row of the texture.")
    tc = g.expr(unreal.MaterialExpressionTextureCoordinate, -2300, -1300)
    tc.set_editor_property("coordinate_index", column)
    t = g.expr(unreal.MaterialExpressionTime, -2300, -1150)
    uv = g.custom("OilVatUV: column + frame row", hlsl.OIL_VAT_UV, (
        ("Column", tc, ""), ("T", t, ""), ("Speed", speed, ""), ("Seconds", seconds, ""), ("Frames", frames, ""),
        ("FlipV", flip, "")), -2000, -1300, FLOAT2)

    g.group("02 VAT")
    pos = g.texture("VAT Position", pos_tex or _require(plan.VAT_REST), SAMPLER_LINEAR, uv,
                    "RGB = offset from the rest mesh, normalised over Pos Min .. Pos Max. Alpha = pop progress (v2 bubbles).")
    nrm = g.texture("VAT Normal", nrm_tex or _require(plan.VAT_REST), SAMPLER_LINEAR, uv, "RGB = normal * 0.5 + 0.5, local axes.")
    pmin = g.vector("Pos Min", tuple(d.get("pos_min", (0.0, 0.0, 0.0))) + (0.0,), "Local cm.", ("X", "Y", "Z", "-"))
    pmax = g.vector("Pos Max", tuple(d.get("pos_max", (0.0, 0.0, 0.0))) + (0.0,), "Local cm.", ("X", "Y", "Z", "-"))

    x = -1400
    dec = g.custom("OilVatDecode: offset + normal", hlsl.OIL_VAT_DECODE, (
        ("Pos", pos, "RGB"), ("Nrm", nrm, "RGB"), ("PosMin", pmin, ""), ("PosMax", pmax, "")), x, -900, FLOAT3,
        (("VatNormal", FLOAT3),))
    return {"pos": pos, "dec": dec, "wpo": g.to_world(dec, "", x + 450, -900),
            "nws": g.to_world(dec, "VatNormal", x + 450, -700), "x": x}


def build_oil_master(metas, vat, vat_tex, fns=None):
    """Opaque oil / stew surface: _vat_core, then (world normal, decoded height) through one vertex interpolator;
    Liquid Colour in the crests, Liquid Colour Deep in the troughs (UseVC 1 multiplies the painted vertex colour)."""
    m = _fresh_master(plan.MASTER_OIL)
    _set(m, "tangent_space_normal", False)                  # the VAT normal is built in world space
    g = mc._Graph(m, x0=-4400)
    core = _vat_core(g, metas, vat, vat_tex, False)
    x = core["x"]
    pack = g.custom("Pack: world normal + height", hlsl.VAT_PACK_HEIGHT,
                    (("N", core["nws"], ""), ("Offset", core["dec"], "")), x + 700, -700, FLOAT4)
    vi = g.expr(unreal.MaterialExpressionVertexInterpolator, x + 950, -700)
    g.link(pack, "", vi, "")

    g.group("03 Liquid")
    liquid = g.vector("Liquid Colour", (1.0, 1.0, 1.0, 1.0), "Crest colour (multiplies the vertex colour while Use Vertex "
                      "Colour is 1; white = the painted oil).")
    deep = g.vector("Liquid Colour Deep", (1.0, 1.0, 1.0, 1.0), "Trough colour, blended in by the depth below rest.")
    use_vc = g.scalar("Use Vertex Colour", 1.0, 0.0, 1.0, "1 = multiply the painted vertex colour in; 0 = the liquid "
                      "colours alone (stew and other liquids).")
    deep_range = g.scalar("Deep Range", 2.0, 0.1, 10.0, "Centimetres below rest at which the trough reaches Liquid Colour Deep.")

    g.group("04 Surface")
    srgb = g.scalar("Vertex Colour sRGB", 0.0, 0.0, 1.0, SRGB_DESC)
    cav_ao = g.scalar("Cavity AO", 0.0, 0.0, 1.0)
    rough = g.scalar("Roughness", 0.08, 0.0, 1.0, "Keep low: oil is a mirror.")
    spec = g.scalar("Specular", 0.5)

    vtx = _vertex_base(g, srgb, cav_ao, x - 300, -1500, (fns or {}).get("decode"))
    ps = g.custom("OilSurface: liquid colour + normal", hlsl.OIL_SURFACE_PS, (
        ("Packed", vi, ""), ("VC",) + vtx["base"], ("LiquidColor", liquid, ""), ("LiquidDeep", deep, ""),
        ("UseVC", use_vc, ""), ("DeepRange", deep_range, "")), x + 1250, -900, FLOAT3, (("WorldN", FLOAT3),))
    g.finish({"BaseColor": (ps, ""), "Roughness": (rough, ""), "Specular": (spec, ""), "Normal": (ps, "WorldN"),
              "WorldPositionOffset": (core["wpo"], ""), "AmbientOcclusion": vtx["ao"]}, x + 1700, -900)
    return m


def build_bubble_master(metas, vat, vat_tex, fns=None):
    """Masked, two-sided bubbles: _vat_core, (world normal, pop) through one vertex interpolator, opaque fake glass
    (fresnel rim darken / centre brighten, thin film, darker liquid backfaces) and the pop mask from BubbleLocal."""
    m = _fresh_master(plan.MASTER_BUBBLE)
    _set(m, "tangent_space_normal", False)
    _set(m, "blend_mode", unreal.BlendMode.BLEND_MASKED)
    _set(m, "two_sided", True)
    _set(m, "opacity_mask_clip_value", 0.5)
    g = mc._Graph(m, x0=-4400)
    core = _vat_core(g, metas, vat, vat_tex, True)
    x = core["x"]
    local_idx, seen = plan.uv_index(metas, "BubbleLocal", 2, True)
    if len(seen) > 1:
        _warn("bubble meshes disagree on the BubbleLocal UV channel %s; reading UV%d" % (seen, local_idx))

    g.group("03 Pop")
    use_pop = g.scalar("Use Pop", 0.0, 0.0, 1.0, "1 = VAT Position alpha is pop progress (OilVAT_Mars.json carries a pop "
                       "block); 0 ignores the alpha and masks nothing.")
    pop_edge = g.scalar("Pop Edge", 0.04, 0.001, 0.3, "Width of the dithered edge where the dome dissolves (BubbleLocal height units).")
    pop_reach = g.scalar("Pop Reach", 0.6, 0.05, 1.0, "How far down the dome the dissolve sweeps at pop 1 (BubbleLocal height); "
                         "below 1 keeps the ring above the oil for the whole pop window.")
    pop_wobble = g.scalar("Pop Wobble", 0.06, 0.0, 0.3, "Ripple of the dissolve edge around the ring (0 = a flat cut).")
    pack = g.custom("Pack: world normal + pop", hlsl.VAT_PACK_POP,
                    (("N", core["nws"], ""), ("Pos", core["pos"], "RGBA"), ("UsePop", use_pop, "")), x + 700, -700, FLOAT4)
    vi = g.expr(unreal.MaterialExpressionVertexInterpolator, x + 950, -700)
    g.link(pack, "", vi, "")

    g.group("04 Liquid")
    liquid = g.vector("Liquid Colour", (1.0, 1.0, 1.0, 1.0), "Bubble colour (multiplies the vertex colour while Use Vertex "
                      "Colour is 1).")
    use_vc = g.scalar("Use Vertex Colour", 1.0, 0.0, 1.0, "1 = multiply the painted vertex colour in; 0 = Liquid Colour alone.")

    g.group("05 Surface")
    srgb = g.scalar("Vertex Colour sRGB", 0.0, 0.0, 1.0, SRGB_DESC)
    zero = g.scalar("Cavity AO", 0.0, 0.0, 1.0)

    vtx = _vertex_base(g, srgb, zero, x - 300, -1500, (fns or {}).get("decode"))
    unpack = g.custom("Unpack: world normal + pop", hlsl.VAT_UNPACK, (("Packed", vi, ""),), x + 1150, -700, FLOAT3,
                      (("Pop", FLOAT1),))
    mix = g.custom("Liquid colour", hlsl.LIQUID_MIX, (("LiquidColor", liquid, ""), ("VC",) + vtx["base"],
                                                      ("UseVC", use_vc, "")), x + 1150, -1100)
    local = g.expr(unreal.MaterialExpressionTextureCoordinate, x + 1150, -350)
    local.set_editor_property("coordinate_index", local_idx)
    out = _bubble_glass(g, (fns or {}).get("glass"), {
        "Liquid Colour": (mix, ""), "Pop": (unpack, "Pop"), "Pop Reach": (pop_reach, ""), "Pop Edge": (pop_edge, ""),
        "Pop Wobble": (pop_wobble, ""), "BubbleLocal": (local, ""), "Normal WS": (unpack, "")}, x + 1500, -900)
    g.finish({"BaseColor": out["Base Colour"], "Roughness": out["Roughness"], "Specular": out["Specular"],
              "Normal": out["Normal WS"], "OpacityMask": out["Opacity Mask"],
              "WorldPositionOffset": (core["wpo"], "")}, x + 1950, -900)
    return m


def build_particle_master(metas, fns=None):
    """OilBubbleParticle_Mars_M: the Niagara mesh-particle bubble. Same glass look and pop mask (BubbleGlass_Mars_MF);
    no WPO (the particle carries position / scale); pop = DynamicParameter.x (Niagara "Dynamic Material Parameters",
    slot 0), the edge phase = DynamicParameter.y; Liquid Colour = Particle Color while Use Particle Colour is 1, so one
    material serves oil, stew and the pan oil."""
    m = _fresh_master(plan.MASTER_PARTICLE)
    _set(m, "blend_mode", unreal.BlendMode.BLEND_MASKED)
    _set(m, "two_sided", True)
    _set(m, "opacity_mask_clip_value", 0.5)
    _set(m, "used_with_niagara_mesh_particles", True)
    g = mc._Graph(m, x0=-3200)
    local_idx = 2
    for meta in metas:
        if "_error" not in meta and plan.classify(meta) == "particle" and "BubbleLocal" in (meta.get("uv_layers") or ()):
            local_idx = list(meta["uv_layers"]).index("BubbleLocal")

    g.group("01 Liquid")
    use_pc = g.scalar("Use Particle Colour", 1.0, 0.0, 1.0, "1 = the Niagara particle colour (the system's Liquid Colour "
                      "user parameter); 0 = Liquid Colour below.")
    liquid = g.vector("Liquid Colour", (0.95, 0.58, 0.14, 1.0), "Bubble colour while Use Particle Colour is 0.")
    g.group("03 Pop")
    pop_edge = g.scalar("Pop Edge", 0.04, 0.001, 0.3, "Width of the dithered edge where the dome dissolves.")
    pop_reach = g.scalar("Pop Reach", 0.6, 0.05, 1.0, "How far down the bubble the dissolve sweeps at pop 1.")
    pop_wobble = g.scalar("Pop Wobble", 0.06, 0.0, 0.3, "Ripple of the dissolve edge around the ring.")

    x = -1500
    pc = g.expr(unreal.MaterialExpressionParticleColor, x - 400, -1000)
    dyn = g.expr(unreal.MaterialExpressionDynamicParameter, x - 400, -800)
    _set(dyn, "parameter_index", 0)
    _set(dyn, "default_value", unreal.LinearColor(0.0, 0.0, 0.0, 0.0))     # no Niagara module -> intact, not popped
    mix = g.custom("Particle liquid colour", hlsl.PARTICLE_LIQUID, (("LiquidColor", liquid, ""), ("PC", pc, ""),
                                                                   ("UsePC", use_pc, "")), x, -1000)
    tc = g.expr(unreal.MaterialExpressionTextureCoordinate, x - 400, -600)
    tc.set_editor_property("coordinate_index", local_idx)
    local = g.custom("BubbleLocal + particle phase", hlsl.PARTICLE_LOCAL, (("BubbleUV", tc, ""), ("Phase", dyn, "G")),
                     x, -600, FLOAT2)
    vn = g.expr(unreal.MaterialExpressionVertexNormalWS, x - 400, -400)
    out = _bubble_glass(g, (fns or {}).get("glass"), {
        "Liquid Colour": (mix, ""), "Pop": (dyn, "R"), "Pop Reach": (pop_reach, ""), "Pop Edge": (pop_edge, ""),
        "Pop Wobble": (pop_wobble, ""), "BubbleLocal": (local, ""), "Normal WS": (vn, "")}, x + 400, -800)
    g.finish({"BaseColor": out["Base Colour"], "Roughness": out["Roughness"], "Specular": out["Specular"],
              "OpacityMask": out["Opacity Mask"]}, x + 850, -800)
    return m



def build_splatter_master():
    """OilSplatter_Mars_M: translucent oil droplet for the Niagara splatter (engine plane, mesh particles): a soft round
    spot with a wobbly outline and a darker rim, colour and fade from the particle colour."""
    m = _fresh_master(plan.MASTER_SPLATTER)
    _set(m, "blend_mode", unreal.BlendMode.BLEND_TRANSLUCENT)
    _set(m, "used_with_niagara_mesh_particles", True)
    g = mc._Graph(m, x0=-2600, y0=-900)
    g.group("01 Droplet")
    rim = g.scalar("Rim Darken", 0.55, 0.0, 1.0, "How much darker the droplet's rim is than its centre.")
    soft = g.scalar("Softness", 0.12, 0.01, 0.5, "Width of the soft outline.")
    wob = g.scalar("Wobble", 1.0, 0.0, 2.0, "Irregularity of the outline.")
    rough = g.scalar("Roughness", 0.15)
    spec = g.scalar("Specular", 0.5)
    uv = g.expr(unreal.MaterialExpressionTextureCoordinate, -1400, -900)
    pc = g.expr(unreal.MaterialExpressionParticleColor, -1400, -760)
    pos = g.expr(unreal.MaterialExpressionObjectPositionWS, -1400, -600)
    seed = g.custom("Seed from the particle position", "return frac(dot(Pos.xy, float2(0.1373, 0.1719)));",
                    (("Pos", pos, ""),), -1100, -600, FLOAT1)
    spot = g.custom("Droplet spot", hlsl.SPLATTER_SPOT, (
        ("UV", uv, ""), ("PC", pc, ""), ("PCA", pc, "A"), ("Seed", seed, ""), ("RimDarken", rim, ""),
        ("Softness", soft, ""), ("Wobble", wob, "")), -800, -800, FLOAT3, (("Opa", FLOAT1),))
    g.finish({"BaseColor": (spot, ""), "Opacity": (spot, "Opa"), "Roughness": (rough, ""), "Specular": (spec, "")},
             -400, -800)
    return m


# ------------------------------------------------------------------ instances
def build_instances(metas, vat, vat_tex, reset_looks=False):
    """reset_looks re-applies the create-only look presets (otherwise kept, so artist tweaks survive)."""
    specs = plan.instance_plan(metas, vat, vat_tex, has_texture=lambda n: mc._asset(F_TEX, n) is not None)
    made = 0
    for spec in specs:
        folder = F_LOOK if spec["folder"] == "look" else F_INST
        parent = _material(spec["parent"])
        if parent is None:
            _warn("%s: parent %s missing, skipped" % (spec["name"], spec["parent"]))
            continue
        inst = mc._asset(folder, spec["name"])
        created = inst is None
        if created:
            inst = mc._tools().create_asset(spec["name"], folder, unreal.MaterialInstanceConstant,
                                            unreal.MaterialInstanceConstantFactoryNew())
        MEL.set_material_instance_parent(inst, parent)
        # the Set*ParameterValue calls always return false in this build (MaterialEditingLibrary.cpp), so check the
        # names against the parent's parameter lists instead
        known = {kind: set(str(n) for n in getter(inst)) for kind, getter in (
            ("scalar", MEL.get_scalar_parameter_names), ("vector", MEL.get_vector_parameter_names),
            ("texture", MEL.get_texture_parameter_names))}
        scalars = dict(spec["create_scalars"]) if created or reset_looks else {}
        scalars.update(spec["scalars"])
        vectors = dict(spec["create_vectors"]) if created or reset_looks else {}
        vectors.update(spec["vectors"])
        for k, v in scalars.items():
            if k not in known["scalar"]:
                _warn("%s: no scalar parameter %s" % (spec["name"], k))
            MEL.set_material_instance_scalar_parameter_value(inst, k, float(v))
        for k, v in vectors.items():
            if k not in known["vector"]:
                _warn("%s: no vector parameter %s" % (spec["name"], k))
            MEL.set_material_instance_vector_parameter_value(inst, k, unreal.LinearColor(*v))
        for k, tex_name in spec["textures"].items():
            tex = mc._asset(F_TEX, tex_name)
            if tex is None:
                _warn("%s: texture %s missing" % (spec["name"], tex_name))
                continue
            if k not in known["texture"]:
                _warn("%s: no texture parameter %s" % (spec["name"], k))
            MEL.set_material_instance_texture_parameter_value(inst, k, tex)
        MEL.update_material_instance(inst)
        EAL.save_loaded_asset(inst)
        made += 1
    _log("%d material instances" % made)


MASTER_KEYS = ("food", "batter", "accent", "salt", "oil", "bubble", "particle", "splatter")
# function key -> (asset, builder, the master keys that call it: they are rebuilt with it)
FUNCTIONS = {
    "decode": (plan.VERTEX_DECODE_MF, lambda: build_vertex_decode_function(), set(MASTER_KEYS)),
    "cook": (plan.FOOD_COOK_MF, lambda: build_food_cook_function(), {"food"}),
    "coat": (plan.OIL_COAT_MF, lambda: build_oil_coat_function(), {"food", "batter"}),
    "glass": (plan.BUBBLE_GLASS_MF, lambda: build_bubble_glass_function(), {"bubble", "particle"}),
}


def rebuild(*keys, export_dir=None, stats=False, reset_looks=False):
    """Rebuild only some masters / functions (keys from MASTER_KEYS and FUNCTIONS; none = all), then the instances,
    the retired-asset cleanup and the slot assignment, in one call (the retired list lives in this module, which a
    reload resets). Every master that calls a rebuilt function is rebuilt with it (else it would keep calling the
    retired copy that _drop_retired deletes)."""
    if mc._in_pie():
        raise RuntimeError("stop PIE before rebuilding the food materials")
    keys = set(keys or MASTER_KEYS + tuple(FUNCTIONS))
    _release_masters()
    src = plan.food_dir(export_dir)
    metas = plan.read_metas(src)
    vat, vat_tex = read_vat(src)
    _ensure_generated()
    fns = {}
    for key, (name, builder, users) in FUNCTIONS.items():
        fn = mc._asset(F_MAT, name)
        if key in keys or fn is None:
            try:
                fn = builder()
                keys |= users
            except Exception as exc:
                fn = None
                keys |= users
                _warn("%s failed (%s); its callers inline the graph instead" % (name, exc))
        fns[key] = fn
    builders = {"food": lambda: build_food_master(fns), "batter": lambda: build_batter_master(fns),
                "accent": lambda: build_accent_master(fns), "salt": lambda: build_salt_master(fns),
                "oil": lambda: build_oil_master(metas, vat, vat_tex, fns),
                "bubble": lambda: build_bubble_master(metas, vat, vat_tex, fns),
                "particle": lambda: build_particle_master(metas, fns),
                "splatter": build_splatter_master}
    masters = [builders[k]() for k in MASTER_KEYS if k in keys]
    build_instances(metas, vat, vat_tex, reset_looks)
    _drop_retired()
    assign_mesh_materials(export_dir)
    if stats:
        for m in masters:
            _report_material(m)
    return masters


def build_materials(export_dir=None, stats=True):
    """OilCoat_Mars_MF, the five masters, their instances, then the slot assignment. Refuses during PIE and while the
    open level (other than the food lookdev map, which is swapped for a blank map) draws a food master."""
    return rebuild(export_dir=export_dir, stats=stats)


def stats():
    """Shader statistics of the five masters (compiles them for the current platform if needed)."""
    for name in plan.MASTERS:
        m = mc._asset(F_MAT, name)
        if m is None:
            _warn("%s missing" % name)
        else:
            _report_material(m)


# ------------------------------------------------------------------ lookdev map
SHOTS = {}           # name -> (eye, target, fov); written by build_lookdev_map, read back by capture


def _shots_file():
    return os.path.join(unreal.Paths.project_saved_dir(), "MarsFood", "FoodLookdev_Shots.json")


def _load_shots(export_dir=None):
    """The shots of the map as it was built (the layout moves when sidecars are added later), else recomputed."""
    try:
        with open(_shots_file()) as fh:
            return {k: (tuple(e), tuple(t), f) for k, (e, t, f) in json.load(fh)["shots"].items()}
    except (OSError, ValueError, KeyError):
        _warn("no saved lookdev shots, framing from the current sidecars")
        return plan.plan_lookdev(plan.read_metas(plan.food_dir(export_dir)))["shots"]


def _spawn_rig(extent):
    """mc.build_lookdev_map's studio rig: warm key, fill, sky light + reflection capture on the studio HDR, grade."""
    hdr = mc._asset(mc.F_TEX, STUDIO_HDR)
    cx, cy = (extent[0] + extent[1]) * 0.5, (extent[2] + extent[3]) * 0.5
    span = max(extent[1] - extent[0], extent[3] - extent[2])
    key = mc._spawn(unreal.DirectionalLight, (cx, cy, 300), (0, -55, -115), "Key", "Food/Rig")
    kc = key.get_component_by_class(unreal.DirectionalLightComponent)
    mc._try(kc, "intensity", 4.0)
    mc._try(kc, "light_color", unreal.Color(r=255, g=232, b=200, a=255))
    mc._try(kc, "light_source_angle", 3.0)
    mc._try(kc, "forward_shading_priority", 1)              # the Key wins forward shading / translucency
    fill = mc._spawn(unreal.DirectionalLight, (cx, cy, 300), (0, -30, 60), "Fill", "Food/Rig")
    fc = fill.get_component_by_class(unreal.DirectionalLightComponent)
    mc._try(fc, "intensity", 1.2)
    mc._try(fc, "light_color", unreal.Color(r=255, g=214, b=190, a=255))
    mc._try(fc, "cast_shadows", False)
    mc._try(fc, "forward_shading_priority", 0)
    sky = mc._spawn(unreal.SkyLight, (cx, cy, 200), label="StudioAmbient", folder="Food/Rig")
    sc = sky.get_component_by_class(unreal.SkyLightComponent)
    if hdr is not None:
        mc._try(sc, "source_type", unreal.SkyLightSourceType.SLS_SPECIFIED_CUBEMAP)
        mc._try(sc, "cubemap", hdr)
    else:
        _warn("%s not found in %s (run mars_cooking_ue.import_textures); the sky light captures the scene instead"
              % (STUDIO_HDR, mc.F_TEX))
    mc._try(sc, "intensity", 0.4)
    mc._try(sc, "real_time_capture", False)
    cap = mc._spawn(unreal.SphereReflectionCapture, (cx, cy, 20), label="StudioReflection", folder="Food/Rig")
    cc = cap.get_component_by_class(unreal.SphereReflectionCaptureComponent)
    if hdr is not None:
        mc._try(cc, "reflection_source_type", unreal.ReflectionSourceType.SPECIFIED_CUBEMAP)
        mc._try(cc, "cubemap", hdr)
    mc._try(cc, "influence_radius", max(400.0, span * 0.8))
    ppv = mc._spawn(unreal.PostProcessVolume, (cx, cy, 0), label="Grade", folder="Food/Rig")
    mc._try(ppv, "unbound", True)
    s = ppv.get_editor_property("settings")
    for k, v in (("override_auto_exposure_method", True), ("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL),
                 ("override_auto_exposure_bias", True), ("auto_exposure_bias", mc.EXPOSURE_BIAS),
                 ("override_bloom_intensity", True), ("bloom_intensity", 0.6)):
        mc._try(s, k, v)
    ppv.set_editor_property("settings", s)


def build_lookdev_map(stay=False, export_dir=None):
    """FoodLookdev_Mars_MAP rebuilt from scratch from the sidecars (plan.plan_lookdev): a counter, the studio rig, a row
    per cooking ingredient in the five FOOD_STATES, a row per battered mesh in Fry 0 / 1 / 2, the mortar set, the oil
    disc with its bubbles and the vertex-colour swatch. Saves it, and returns to the map that was open unless stay."""
    if mc._in_pie():
        raise RuntimeError("stop PIE before building the lookdev map")
    les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
    eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    current = world.get_outermost().get_name() if world else None
    dirty = [p.get_name() for p in unreal.EditorLoadingAndSavingUtils.get_dirty_map_packages()]
    temp = bool(current) and current.startswith("/Temp/")     # e.g. the blank map _release_masters opened
    if current != LOOKDEV_MAP:
        if current in dirty and not temp:
            raise RuntimeError("%s has unsaved changes; save it before building the food lookdev map" % current)
        if EAL.does_asset_exist(LOOKDEV_MAP):
            les.load_level(LOOKDEV_MAP)
        else:
            les.new_level(LOOKDEV_MAP)
    eas.destroy_actors([a for a in eas.get_all_level_actors() if not isinstance(a, (unreal.WorldSettings, unreal.Brush))])

    metas = plan.read_metas(plan.food_dir(export_dir))
    layout = plan.plan_lookdev(metas, read_vat(export_dir)[0])
    SHOTS.clear()
    SHOTS.update(layout["shots"])
    plane = mc._load("/Engine/BasicShapes/Plane.Plane")
    shapes = {plan.PLANE: plane, plan.CYLINDER: mc._load("/Engine/BasicShapes/Cylinder.Cylinder")}
    x0, x1, y0, y1 = layout["extent"]

    counter_mi = mc._asset(F_LOOK, "FoodCounter_Mars_MI")
    if counter_mi is None:
        counter_mi = mc._tools().create_asset("FoodCounter_Mars_MI", F_LOOK, unreal.MaterialInstanceConstant,
                                              unreal.MaterialInstanceConstantFactoryNew())
        MEL.set_material_instance_parent(counter_mi, mc._load(plan.BASIC_SHAPE_MATERIAL))
    MEL.set_material_instance_vector_parameter_value(counter_mi, "Color", unreal.LinearColor(0.20, 0.09, 0.035, 1.0))
    MEL.update_material_instance(counter_mi)
    EAL.save_loaded_asset(counter_mi)
    counter = mc._spawn(plane, ((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0.0), label="Counter", folder="Food")
    counter.set_actor_scale3d(unreal.Vector((x1 - x0) / 100.0, (y1 - y0) / 100.0, 1.0))
    counter.get_component_by_class(unreal.StaticMeshComponent).set_material(0, counter_mi)

    missing, spawned, placed = set(), 0, {}
    for p in layout["placements"]:
        if p["mesh"] == plan.NIAGARA:
            a = _spawn_niagara(p, placed)
            if a is None:
                missing.add(plan.NIAGARA_BUBBLES)
            else:
                placed[p["label"]] = a
                spawned += 1
            continue
        mesh = shapes.get(p["mesh"]) or mc._asset(F_MESH, p["mesh"])
        if mesh is None:
            missing.add(p["mesh"])
            continue
        scale = tuple(p["scale"]) if isinstance(p["scale"], (tuple, list)) else (p["scale"],) * 3
        loc = list(p["loc"])
        if p["mesh"] == plan.CYLINDER:                    # engine shapes are centred: rest the bottom on loc z
            b = mesh.get_bounds()
            loc[2] += (b.box_extent.z - b.origin.z) * scale[2]
        a = mc._spawn(mesh, loc, (p.get("roll", 0.0), 0.0, p["yaw"]), p["label"], p["folder"])
        placed[p["label"]] = a
        if scale != (1.0, 1.0, 1.0):
            a.set_actor_scale3d(unreal.Vector(*scale))
        comp = a.get_component_by_class(unreal.StaticMeshComponent)
        if p["material"]:
            mi = _material(p["material"])
            if mi is None:
                _warn("%s: material %s missing (run build_materials)" % (p["label"], p["material"]))
            else:
                for i in range(max(comp.get_num_materials(), 1)):
                    comp.set_material(i, mi)
        if p["cpd"]:
            mc._set_cpd(a, *p["cpd"])
        if p["bounds_scale"]:
            _set(comp, "bounds_scale", float(p["bounds_scale"]))
        spawned += 1
    if missing:
        _warn("meshes not imported, skipped: %s" % ", ".join(sorted(missing)))

    _spawn_rig(layout["extent"])
    les.save_current_level()
    try:
        os.makedirs(os.path.dirname(_shots_file()), exist_ok=True)
        with open(_shots_file(), "w") as fh:
            json.dump({"map": LOOKDEV_MAP, "shots": layout["shots"], "extent": layout["extent"]}, fh, indent=1)
    except OSError as exc:
        _warn("could not save the shot list (%s)" % exc)
    if current and current != LOOKDEV_MAP and not temp and not stay:
        les.load_level(current)
    _log("lookdev map built: %s (%d placements, shots %s)" % (LOOKDEV_MAP, spawned, sorted(SHOTS)))
    return layout


def _spawn_niagara(p, placed, actor=None):
    """An OilBubbles_Mars_NS actor with the placement's user parameter overrides, attached (keep world) to its host
    (or, with actor, only the overrides on that existing Niagara actor)."""
    if actor is not None:
        a = actor
    else:
        ns = mc._asset(F_FX, plan.NIAGARA_BUBBLES)
        if ns is None:
            return None
        a = mc._spawn(ns, p["loc"], (0.0, 0.0, 0.0), p["label"], p["folder"])
    comp = a.get_component_by_class(unreal.NiagaraComponent)
    for k, v in p["user"].items():
        try:
            if isinstance(v, (tuple, list)) and len(v) == 2:
                comp.set_variable_vec2(k, unreal.Vector2D(*v))
            elif isinstance(v, (tuple, list)):
                comp.set_variable_linear_color(k, unreal.LinearColor(*v))
            else:
                comp.set_variable_float(k, float(v))
        except Exception as exc:
            _warn("%s: user parameter %s: %s" % (p["label"], k, exc))
    host = placed.get(p.get("attach"))
    if host is not None:
        rule = unreal.AttachmentRule.KEEP_WORLD
        a.attach_to_actor(host, "", rule, rule, rule, False)
    return a


# ------------------------------------------------------------------ pan bubbles / splatter (steak minigame)
PAN_OIL_AMBER = (0.22, 0.1, 0.02, 1.0)              # dark amber: beads, not pearls
PAN_BUBBLES_USER = {"BubbleRadiusMin": 0.12, "BubbleRadiusMax": 0.25, "LifetimeMin": 0.6, "LifetimeMax": 1.0,
                    "StartDepth": 0.3, "WobbleAmplitude": 0.05, "RiseFraction": 0.5, "LiquidColour": PAN_OIL_AMBER}
PAN_SPLATTER_USER = {"SplatterRate": 14.0, "BurstsPerSecond": 3.0, "FlingMin": 2.0, "FlingMax": 8.0,
                     "SplatterSizeMin": 0.15, "SplatterSizeMax": 0.4, "SplatterLife": 2.0, "SplatterArc": 0.8,
                     "SplatterColour": (0.1, 0.045, 0.012, 1.0)}


def _spawn_attached(system_name, label, host, local, user, folder):
    """A Niagara actor at host-local cm `local`, rotated with the host, user parameters set, attached keeping world."""
    ns = mc._asset(F_FX, system_name)
    if ns is None:
        raise RuntimeError("%s missing (run mars_food_niagara.py)" % system_name)
    xf = host.get_actor_transform()
    world = xf.transform_location(unreal.Vector(*local))
    eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    a = eas.spawn_actor_from_object(ns, world, host.get_actor_rotation())
    a.set_actor_label(label)
    a.set_folder_path(folder)
    _spawn_niagara({"label": label, "user": user, "attach": None, "loc": (0, 0, 0), "folder": folder}, {}, actor=a)
    rule = unreal.AttachmentRule.KEEP_WORLD
    a.attach_to_actor(host, "", rule, rule, rule, False)
    return a


def attach_pan_bubbles(actor_label="Meat_InPan", outer_cm=3.5, rate=25.0, oil_lift_cm=0.1, splatter=True):
    """The steak pan's oil bubbles (and splatter) in the meat cube's local space: OilBubbles_Mars_NS actors attached
    to the cube actor `actor_label`, in four strips around the cube's footprint (a 2 * outer_cm square minus the cube),
    SpawnRate split by strip area; SurfaceZ = the pan surface relative to the cube's centre pivot (minus the mesh's
    half extent: cooking_spec.CUBE_MESH_HALF_CM for the hand-authored cube, else CUBE_HALF_CM) plus oil_lift_cm.
    With splatter, one OilSplatter_Mars_NS at the cube's footprint edge. Existing PanBubbles_* /
    PanSplatter actors are replaced. mars_cooking_ue.build_lookdev_map calls this after it places the cube (the
    open map must be it); the caller saves the map."""
    eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    actors = eas.get_all_level_actors()
    host = next((a for a in actors if a.get_actor_label() == actor_label), None)
    if host is None:
        raise RuntimeError("no actor %s in the open map" % actor_label)
    old = [a for a in actors if a.get_actor_label().startswith(("PanBubbles_", "PanSplatter"))]
    if old:
        eas.destroy_actors(old)
    half = getattr(mc.spec, "CUBE_MESH_HALF_CM", mc.spec.CUBE_HALF_CM)
    inner = half + 0.3
    surface = -half + oil_lift_cm
    strips = {"E": ((inner + outer_cm) * 0.5, 0.0, outer_cm - inner, 2.0 * outer_cm),
              "W": (-(inner + outer_cm) * 0.5, 0.0, outer_cm - inner, 2.0 * outer_cm),
              "N": (0.0, (inner + outer_cm) * 0.5, 2.0 * inner, outer_cm - inner),
              "S": (0.0, -(inner + outer_cm) * 0.5, 2.0 * inner, outer_cm - inner)}
    area = sum(ex * ey for _, _, ex, ey in strips.values())
    made = []
    for name, (cx, cy, ex, ey) in strips.items():
        user = dict(PAN_BUBBLES_USER, SpawnExtent=(ex, ey), SurfaceZ=surface, SpawnRate=rate * ex * ey / area)
        made.append(_spawn_attached(plan.NIAGARA_BUBBLES, "PanBubbles_%s" % name, host, (cx, cy, 0.0), user, "Cooking/FX"))
    if splatter:
        user = dict(PAN_SPLATTER_USER, SplatterRadius=mc.spec.CUBE_FOOTPRINT_CM, SurfaceZ=surface)
        made.append(_spawn_attached(plan.NIAGARA_SPLATTER, "PanSplatter", host, (0.0, 0.0, 0.0), user, "Cooking/FX"))
    _log("%d pan FX actors attached to %s (SurfaceZ %.2f cm in its space)" % (len(made), actor_label, surface))
    return made


def warm_niagara(seconds=2.0, fps=30.0):
    """Advance every Niagara component in the open map (a still capture otherwise shows whatever the editor has ticked)."""
    n = 0
    for actor in unreal.get_editor_subsystem(unreal.EditorActorSubsystem).get_all_level_actors():
        for comp in actor.get_components_by_class(unreal.NiagaraComponent):
            try:
                comp.activate(True)
                comp.advance_simulation(int(seconds * fps), 1.0 / fps)
                n += 1
            except Exception as exc:
                _warn("%s: advance_simulation failed (%s)" % (actor.get_actor_label(), exc))
    _log("advanced %d Niagara components by %.1f s" % (n, seconds))
    return n


def capture(out_dir, shots=None, size=(1600, 1000), source=None, suffix="", export_dir=None):
    """mc.capture with the food SHOTS: renders the named shots of the open map (the food lookdev map) to
    <out_dir>/<shot>.png through a temporary SceneCapture2D."""
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    if world is None or world.get_outermost().get_name() != LOOKDEV_MAP:
        _warn("the open map is not %s; the shots are framed for it" % LOOKDEV_MAP)
    if not SHOTS:
        SHOTS.update(_load_shots(export_dir))
    names = [n for n in (shots or sorted(SHOTS)) if n in SHOTS]
    unreal.SystemLibrary.execute_console_command(world, "r.TextureStreaming 0")     # session cvar, never saved
    os.makedirs(out_dir, exist_ok=True)
    rt = unreal.RenderingLibrary.create_render_target2d(world, size[0], size[1], unreal.TextureRenderTargetFormat.RTF_RGBA8)
    actor = unreal.get_editor_subsystem(unreal.EditorActorSubsystem).spawn_actor_from_class(unreal.SceneCapture2D,
                                                                                            unreal.Vector(0, 0, 0))
    try:
        comp = actor.get_component_by_class(unreal.SceneCaptureComponent2D)
        comp.set_editor_property("texture_target", rt)
        comp.set_editor_property("capture_source", source or unreal.SceneCaptureSource.SCS_FINAL_COLOR_LDR)
        comp.set_editor_property("capture_every_frame", False)
        comp.set_editor_property("capture_on_movement", False)
        for name in names:
            eye, target, fov = SHOTS[name]
            d = [t - e for e, t in zip(eye, target)]
            yaw = math.degrees(math.atan2(d[1], d[0]))
            pitch = math.degrees(math.atan2(d[2], math.hypot(d[0], d[1])))
            actor.set_actor_location_and_rotation(unreal.Vector(*eye), unreal.Rotator(roll=0.0, pitch=pitch, yaw=yaw),
                                                  False, False)
            comp.set_editor_property("fov_angle", float(fov))
            comp.capture_scene()
            unreal.RenderingLibrary.export_render_target(world, rt, out_dir, name + suffix + ".png")
    finally:
        actor.destroy_actor()
    _log("captured %s -> %s" % (names, out_dir))
    return names


# ------------------------------------------------------------------ dry run / everything
def report(export_dir=None):
    """Logs what the build would do from the sidecars, touching no asset: slot -> instance per mesh, the instance plan
    and the lookdev shots."""
    src = plan.food_dir(export_dir)
    metas = plan.read_metas(src)
    vat_tex = plan.vat_textures(_food_names(src, "Oil*_VAT*_Mars_T.exr"))
    have = set(_food_names(src, "*_Mars_T.png")) | set(_food_names(src, "*_Mars_T.exr"))
    for meta in metas:
        if "_error" in meta:
            _warn("%s: %s" % (meta["name"], meta["_error"]))
            continue
        slots = ", ".join("%s -> %s" % (s, plan.resolve_material(meta["name"], s)) for s in plan.slots_of(meta))
        _log("%-28s %-9s %s" % (meta["name"], plan.classify(meta), slots))
    for spec in plan.instance_plan(metas, {}, vat_tex, has_texture=lambda n: n in have):
        _log("instance %-34s parent %-24s textures %s" % (spec["name"], spec["parent"].split(".")[-1], spec["textures"]))
    _log("lookdev shots: %s" % sorted(plan.plan_lookdev(metas)["shots"]))


def run_all(export_dir=None, shots_dir=None):
    """import_textures, import_meshes, build_materials, build_lookdev_map, and the review shots when shots_dir is set
    (then the previously open map comes back)."""
    import_textures(export_dir)
    import_meshes(export_dir)
    build_materials(export_dir)
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    previous = world.get_outermost().get_name() if world else None
    build_lookdev_map(stay=bool(shots_dir), export_dir=export_dir)
    if shots_dir:
        capture(shots_dir, export_dir=export_dir)
        if previous and previous != LOOKDEV_MAP and not previous.startswith("/Temp/"):
            unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).load_level(previous)
