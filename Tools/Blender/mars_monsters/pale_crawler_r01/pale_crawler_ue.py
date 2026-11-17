"""Editor side of the Pale Crawler R01 art candidate (SCHEMA.md beside this file). Runs inside the Unreal Editor's Python
(Monolith `editor_query run_python`), never during PIE. Everything it writes lives under /Game/ArtCandidates/PaleCrawler/R01
and is named PaleCrawler_R01_*.

- run_import(export_dir): manifest -> master material + one instance per slot -> the 11 FBX meshes (legacy FBX importer,
  authored normals, degenerates KEPT, no collision, no lightmap UVs), slots bound by name, a per-mesh report checked
  against the sidecar values (triangles exact, bounds within 0.1 cm, slots exact and bound).
- prove_reload(): hashes the .uasset files, unloads the packages, reloads them and re-reads the meshes and instances.
- build_review_scene(manifest): the review map with both poses assembled, a 140 cm chef marker and neutral lights.
- capture_views(out_dir, ...): SceneCapture2D -> PNGs (no editor viewport involved). Run it in a SEPARATE run_python call
  after build_review_scene, so shaders and mesh builds started by earlier calls have finished.
- list_candidate_assets(), restore_level(path).

Run snippet:
    import sys, importlib, json; sys.path.insert(0, r"D:\\Repositories\\CkRepos\\Orion\\Tools\\Blender\\mars_monsters\\pale_crawler_r01")
    import pale_crawler_ue as pc; importlib.reload(pc)
    print(json.dumps(pc.run_import(r"D:\\Repositories\\CkRepos\\Orion\\docs\\art\\pale-crawler-model-r01\\production\\export"), indent=1))
"""
import hashlib
import json
import math
import os
import re
import struct
import sys
import zlib

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
_SEND = os.path.join(os.path.dirname(os.path.dirname(HERE)), "mars_send_to_unreal", "unreal")
if _SEND not in sys.path:
    sys.path.insert(0, _SEND)
import mars_character_ue as base  # noqa: E402

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary

F_ROOT = "/Game/ArtCandidates/PaleCrawler/R01"
F_MESH = F_ROOT + "/Meshes"
F_MAT = F_ROOT + "/Materials"
F_REVIEW = F_ROOT + "/Review"
PREFIX = "PaleCrawler_R01_"
MASTER = "PaleCrawler_R01_Mars_M"
MI_NAME = "PaleCrawler_R01_%s_Mars_MI"
REVIEW_MAP = F_REVIEW + "/PaleCrawler_R01_Review_MAP"
MANIFEST = "PaleCrawler_R01_Assembly.json"
TAG_REVIEW, TAG_JOINTS, TAG_LIGHT, TAG_POSE = "PaleCrawlerR01Review", "PaleCrawlerR01Joints", "neutral_light", "PaleCrawlerR01Pose_"
BOUNDS_TOL_CM = 0.1
SHAPES = "/Engine/BasicShapes/"                     # Plane 100x100, Cylinder 100 tall x 100 wide (centred), Sphere r50
CUBEMAP = "/Engine/MapTemplates/Sky/DaylightAmbientCubemap"
SUN_LUX, SKY_INTENSITY = 3.0, 0.5
AMBER = ((1.0, 0.55, 0.2), 8000.0, (150.0, 0.0, 300.0))     # colour, candela, offset from the assembly centre
TEAL = ((0.2, 0.7, 0.8), 2500.0, (-200.0, -200.0, 150.0))   # behind-left (-X, -Y)
# Manual exposure per lighting mode: one capture has no eye-adaptation history, so auto exposure is unreliable. With
# AEM_MANUAL and no physical camera the value is an exposure COMPENSATION in stops (scene luminance x 2^bias), so a
# brighter rig needs a more NEGATIVE value: ~3 lux sun + sky -> about 1 stop up; 8000 cd amber at ~3.3 m (~700 lux) -> about
# 5 stops down. Tuned by eye against probe captures (2026-10-30): +9.3 blew the dungeon rig out to white, -7.5 was too dark.
EXPOSURE_EV100 = {"neutral": 2.0, "dungeon": -5.0}
WARMUP_CAPTURES = 3                                 # captures per view before export, so temporal effects settle
FOV, VIEW_DIST, FACE_DIST, KNEE_DIST, KNEE_LEG = 50.0, 450.0, 90.0, 80.0, "R2"
VIEWS = ("front", "right_side", "rear", "top", "three_quarter", "face_closeup", "knee_closeup")


def _err(e):
    return "%s: %s" % (type(e).__name__, e)


def _path(folder, name):
    return "%s/%s.%s" % (folder, name, name)


def _v(vec):
    return [round(vec.x, 3), round(vec.y, 3), round(vec.z, 3)]


def _vec(xyz, off=(0.0, 0.0, 0.0)):
    return unreal.Vector(float(xyz[0]) + off[0], float(xyz[1]) + off[1], float(xyz[2]) + off[2])


def _json(v):
    if v is None or isinstance(v, (bool, int, float, str)):
        return v
    if isinstance(v, unreal.Vector):
        return _v(v)
    if isinstance(v, unreal.Rotator):
        return {"roll": v.roll, "pitch": v.pitch, "yaw": v.yaw}
    return str(v)


def _pie():
    return {"error": "the editor is in PIE - stop it and run again"} if base._in_pie() else None


def _srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _ar_assets(root, classes=()):
    flt = unreal.ARFilter(class_paths=[unreal.TopLevelAssetPath("/Script/Engine", c) for c in classes],
                          package_paths=[root], recursive_paths=True)
    return unreal.AssetRegistryHelpers.get_asset_registry().get_assets(flt)


def _content_dir():
    return os.path.normpath(unreal.Paths.convert_relative_path_to_full(unreal.Paths.project_content_dir()))


def _disk_base(pkg):
    return os.path.join(_content_dir(), *pkg[len("/Game/"):].split("/"))


def load_manifest(export_dir):
    with open(os.path.join(export_dir, MANIFEST), "r", encoding="utf-8") as f:
        return json.load(f)


def _new_or_load(name, folder, cls, factory):
    p = _path(folder, name)
    if EAL.does_asset_exist(p):
        a = base._load(p)
        if not isinstance(a, cls):
            raise RuntimeError("%s exists but is a %s" % (p, a.get_class().get_name() if a else None))
        return a, False
    return unreal.AssetToolsHelpers.get_asset_tools().create_asset(name, folder, cls, factory), True


def create_materials(manifest):
    out = {"master": None, "instances": {}, "error": None}
    if _pie():
        return dict(out, **_pie())
    try:
        m, new = _new_or_load(MASTER, F_MAT, unreal.Material, unreal.MaterialFactoryNew())
        for _ in range(8):
            if MEL.get_num_material_expressions(m) == 0:
                break
            MEL.delete_all_material_expressions(m)
        m.set_editor_property("used_with_instanced_static_meshes", True)
        tint = MEL.create_material_expression(m, unreal.MaterialExpressionVectorParameter, -400, -100)
        tint.set_editor_property("parameter_name", "Tint")
        tint.set_editor_property("default_value", unreal.LinearColor(r=1.0, g=1.0, b=1.0, a=1.0))
        MEL.connect_material_property(tint, "", unreal.MaterialProperty.MP_BASE_COLOR)
        for name, value, y, prop in (("Roughness", 0.8, 150, unreal.MaterialProperty.MP_ROUGHNESS),
                                     ("Specular", 0.3, 250, unreal.MaterialProperty.MP_SPECULAR)):
            p = MEL.create_material_expression(m, unreal.MaterialExpressionScalarParameter, -400, y)
            p.set_editor_property("parameter_name", name)
            p.set_editor_property("default_value", value)
            MEL.connect_material_property(p, "", prop)
        MEL.recompile_material(m)
        EAL.save_loaded_asset(m)
        out["master"] = {"path": _path(F_MAT, MASTER), "new": new}
        mats = manifest["materials"]
        for slot in mats["slots"]:
            mi, new = _new_or_load(MI_NAME % slot, F_MAT, unreal.MaterialInstanceConstant,
                                   unreal.MaterialInstanceConstantFactoryNew())
            MEL.set_material_instance_parent(mi, m)
            srgb = [float(c) for c in mats["srgb"][slot][:3]]
            lin = [_srgb_to_linear(c) for c in srgb]
            MEL.set_material_instance_vector_parameter_value(mi, "Tint", unreal.LinearColor(r=lin[0], g=lin[1], b=lin[2], a=1.0))
            rough = (mats.get("roughness") or {}).get(slot)
            if rough is not None:
                MEL.set_material_instance_scalar_parameter_value(mi, "Roughness", float(rough))
            MEL.update_material_instance(mi)
            EAL.save_loaded_asset(mi)
            out["instances"][slot] = {"path": _path(F_MAT, MI_NAME % slot), "new": new, "tint_srgb": srgb,
                                      "tint_linear": [round(c, 5) for c in lin], "roughness": rough,
                                      "readback": _mi_reading(mi)}
    except Exception as e:
        out["error"] = _err(e)
    return out


def _mi_reading(mi):
    try:
        t = MEL.get_material_instance_vector_parameter_value(mi, "Tint")
        parent = mi.get_editor_property("parent")
        return {"parent": parent.get_name() if parent else None, "tint": [round(t.r, 5), round(t.g, 5), round(t.b, 5)],
                "roughness": round(MEL.get_material_instance_scalar_parameter_value(mi, "Roughness"), 5)}
    except Exception as e:
        return {"error": _err(e)}


def _options():
    opts = unreal.FbxImportUI()
    opts.automated_import_should_detect_type = False
    opts.import_mesh = True
    opts.import_as_skeletal = False
    opts.import_animations = False
    opts.import_materials = False
    opts.import_textures = False
    opts.mesh_type_to_import = unreal.FBXImportType.FBXIT_STATIC_MESH
    d = opts.static_mesh_import_data
    d.combine_meshes = True
    d.generate_lightmap_u_vs = False
    d.auto_generate_collision = False
    d.normal_import_method = unreal.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS
    # FbxImportUI's defaults come from the user's last interactive import (config), so pin the transform too
    for prop, value in (("remove_degenerates", False), ("build_nanite", False),
                        ("vertex_color_import_option", unreal.VertexColorImportOption.REPLACE),
                        ("import_uniform_scale", 1.0), ("import_translation", unreal.Vector(0.0, 0.0, 0.0)),
                        ("import_rotation", unreal.Rotator(roll=0.0, pitch=0.0, yaw=0.0))):
        base._set(d, prop, value)
    return opts


def _run_tasks(jobs):
    tasks = []
    for job in jobs:
        t = base._task(job)
        t.options = _options()
        tasks.append(t)
    was = unreal.SystemLibrary.get_console_variable_bool_value(base.FBX_FLAG)
    unreal.SystemLibrary.execute_console_command(None, "%s 0" % base.FBX_FLAG)
    try:
        unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks(tasks)
    finally:
        unreal.SystemLibrary.execute_console_command(None, "%s %d" % (base.FBX_FLAG, 1 if was else 0))


_IMPORT_FIELDS = ("remove_degenerates", "normal_import_method", "auto_generate_collision", "generate_lightmap_u_vs",
                  "combine_meshes", "build_nanite", "import_uniform_scale", "import_translation", "import_rotation",
                  "convert_scene", "force_front_x_axis", "convert_scene_unit")
_BUILD_FIELDS = ("remove_degenerates", "recompute_normals", "recompute_tangents", "use_mikk_t_space",
                 "generate_lightmap_u_vs", "build_reversed_index_buffer")


def _import_readback(mesh):
    out = {}
    try:
        d = mesh.get_editor_property("asset_import_data")
        out["class"] = d.get_class().get_name() if d else None
        for f in _IMPORT_FIELDS:
            try:
                out[f] = _json(d.get_editor_property(f))
            except Exception as e:
                out[f] = "unavailable (%s)" % _err(e)
        for key, fn in (("source_files", lambda: [str(s) for s in d.extract_filenames()]),
                        ("first_filename", lambda: str(d.get_first_filename()))):
            try:
                out[key] = fn()
            except Exception as e:
                out[key] = "unavailable (%s)" % _err(e)
    except Exception as e:
        out["error"] = _err(e)
    return out


def _lod0_build(mesh):
    try:
        s = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem).get_lod_build_settings(mesh, 0)
        return {f: _json(s.get_editor_property(f)) for f in _BUILD_FIELDS}
    except Exception as e:
        return {"unavailable": _err(e)}


def _patch_lod0_degenerates(mesh):
    """The LOD0 build setting is what the mesh build actually honours; force it off and rebuild."""
    sub = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
    s = sub.get_lod_build_settings(mesh, 0)
    s.set_editor_property("remove_degenerates", False)
    sub.set_lod_build_settings(mesh, 0, s)


def _collision(mesh):
    try:
        body = mesh.get_editor_property("body_setup")
        if body is None:
            return {"body_setup": False, "convex": 0, "simple": 0}
        agg = body.get_editor_property("agg_geom")
        n = {k: len(agg.get_editor_property(k)) for k in ("convex_elems", "box_elems", "sphere_elems", "sphyl_elems",
                                                          "tapered_capsule_elems")}
        return {"body_setup": True, "convex": n["convex_elems"], "simple": sum(n.values()), "elems": n}
    except Exception as e:
        return {"error": _err(e)}


def _bind(mesh):
    bound, unbound = {}, []
    for i, m in enumerate(mesh.static_materials):
        slot = str(m.material_slot_name)
        mi = base._load(_path(F_MAT, MI_NAME % re.sub(r"[._]\d{3}$", "", slot)))
        if mi is None:
            bound[slot] = None
            unbound.append(slot)
            continue
        mesh.set_material(i, mi)
        bound[slot] = mi.get_name()
    return bound, unbound


def _mesh_report(mesh, exp, unbound):
    box = mesh.get_bounding_box()
    got_box = [box.min.x, box.min.y, box.min.z, box.max.x, box.max.y, box.max.z]
    want_box = list(exp.get("bounds_min") or []) + list(exp.get("bounds_max") or [])
    slots = [str(m.material_slot_name) for m in mesh.static_materials]
    tris, verts = mesh.get_num_triangles(0), mesh.get_num_vertices(0)
    ok = {"tris": tris == exp.get("tris"),
          "bounds": len(want_box) == 6 and all(abs(a - b) <= BOUNDS_TOL_CM for a, b in zip(got_box, want_box)),
          "slots": slots == list(exp.get("slots") or []) and not unbound}
    ok["all"] = all(ok.values())
    return {"num_triangles": tris, "num_vertices": verts, "bounds_min": _v(box.min), "bounds_max": _v(box.max),
            "slots": slots, "collision": _collision(mesh), "ok": ok,
            "bounds_max_err": round(max(abs(a - b) for a, b in zip(got_box, want_box)), 4) if len(want_box) == 6 else None,
            "expected": {k: exp.get(k) for k in ("tris", "render_vertices", "bounds_min", "bounds_max", "slots")}}


def import_meshes(manifest, export_dir, save=True):
    res = {"meshes": {}, "collisions": {}, "skipped": [], "failed": [], "second_pass": [], "ok": False, "error": None}
    if _pie():
        return dict(res, **_pie())
    try:
        names = sorted(manifest["meshes"])
        elsewhere = {}
        for a in _ar_assets("/Game", ("StaticMesh",)):
            if str(a.asset_name) in names:
                elsewhere.setdefault(str(a.asset_name), []).append(str(a.package_name))
        jobs = []
        for name in names:
            entry = manifest["meshes"][name]
            fbx = os.path.join(export_dir, entry.get("fbx") or name + ".fbx")
            others = [p for p in elsewhere.get(name, []) if p != F_MESH + "/" + name]
            path = _path(F_MESH, name)
            if not name.startswith(PREFIX):
                res["skipped"].append("%s (name lacks %s)" % (name, PREFIX))
            elif not os.path.isfile(fbx):
                res["skipped"].append("%s (no file %s)" % (name, fbx))
            elif others:
                res["collisions"][name] = others
            elif EAL.does_asset_exist(path) and not isinstance(base._load(path), unreal.StaticMesh):
                res["collisions"][name] = [path + " (exists, not a StaticMesh)"]
            else:
                jobs.append({"fbx": fbx.replace("\\", "/"), "folder": F_MESH, "name": name, "path": path,
                             "new": not EAL.does_asset_exist(path), "expected": entry})
        if jobs:
            _run_tasks(jobs)
        second = []
        for job in jobs:
            mesh = base._load(job["path"])
            if mesh is not None and _import_readback(mesh).get("remove_degenerates") is not False:
                try:
                    mesh.get_editor_property("asset_import_data").set_editor_property("remove_degenerates", False)
                except Exception as e:
                    res["skipped"].append("%s (could not clear import-data remove_degenerates: %s)" % (job["name"], _err(e)))
                second.append(job)
        if second:
            _run_tasks(second)
            res["second_pass"] = [j["name"] for j in second]
        for job in jobs:
            mesh = base._load(job["path"])
            if mesh is None:
                res["failed"].append(job["name"])
                continue
            rep = {"path": job["path"].split(".")[0], "new": job["new"], "second_pass": job in second,
                   "build_settings_patched": False}
            try:
                if _lod0_build(mesh).get("remove_degenerates") is True:
                    _patch_lod0_degenerates(mesh)
                    rep["build_settings_patched"] = True
            except Exception as e:
                rep["build_settings_patched"] = "failed: " + _err(e)
            rep["bound"], rep["unbound"] = _bind(mesh)
            rep["import_data"] = _import_readback(mesh)
            rep["lod0_build"] = _lod0_build(mesh)
            try:
                rep.update(_mesh_report(mesh, job["expected"], rep["unbound"]))
            except Exception as e:
                rep["report_error"] = _err(e)
            if save:
                rep["saved"] = bool(EAL.save_loaded_asset(mesh))
            res["meshes"][job["name"]] = rep
        res["ok"] = bool(res["meshes"]) and not (res["failed"] or res["collisions"] or res["skipped"]) and \
            all(r.get("ok", {}).get("all") for r in res["meshes"].values())
    except Exception as e:
        res["error"] = _err(e)
    return res


def list_candidate_assets():
    assets = sorted(str(a.package_name) for a in _ar_assets(F_ROOT))
    disk, root = [], _disk_base(F_ROOT)
    for d, _, files in os.walk(root):
        disk += [os.path.relpath(os.path.join(d, f), root).replace("\\", "/") for f in files]
    return {"assets": assets, "count": len(assets), "disk": sorted(disk),
            "not_prefixed": [a for a in assets if not a.rsplit("/", 1)[1].startswith(PREFIX)]}


def _hashes(pkg):
    out = {}
    for ext in (".uasset", ".umap", ".uexp", ".ubulk"):
        f = _disk_base(pkg) + ext
        if os.path.isfile(f):
            with open(f, "rb") as fh:
                out[ext] = {"size": os.path.getsize(f), "sha256": hashlib.sha256(fh.read()).hexdigest()}
    return out


def _reading(pkg):
    try:
        a = unreal.load_asset("%s.%s" % (pkg, pkg.rsplit("/", 1)[1]))
        if isinstance(a, unreal.StaticMesh):
            box = a.get_bounding_box()
            return {"class": "StaticMesh", "tris": a.get_num_triangles(0), "verts": a.get_num_vertices(0),
                    "bounds_min": _v(box.min), "bounds_max": _v(box.max),
                    "materials": [m.material_interface.get_name() if m.material_interface else None
                                  for m in a.static_materials]}
        if isinstance(a, unreal.MaterialInstanceConstant):
            return dict({"class": "MaterialInstanceConstant"}, **_mi_reading(a))
        return {"class": a.get_class().get_name() if a else None}
    except Exception as e:
        return {"error": _err(e)}


def prove_reload():
    if _pie():
        return _pie()
    res = {"current_level": _world_package(), "error": None}
    try:
        pkgs = [p for p in list_candidate_assets()["assets"] if not p.startswith(F_REVIEW)]
        for p in pkgs:
            EAL.save_asset(p, True)                   # only_if_is_dirty: a dirty package refuses to unload
        res["hashes_before"] = {p: _hashes(p) for p in pkgs}
        res["before"] = {p: _reading(p) for p in pkgs}
        packages = [k for k in (unreal.find_package(p) for p in pkgs) if k is not None]
        r = unreal.EditorLoadingAndSavingUtils.unload_packages(packages)
        del packages
        res["unload"] = {"result": [str(x) for x in r] if isinstance(r, tuple) else str(r)}
        # UnloadPackages reports success even when GC keeps a referenced object alive; check what is still in memory
        res["still_in_memory"] = [p for p in pkgs if unreal.find_object(None, "%s.%s" % (p, p.rsplit("/", 1)[1]))]
        res["after"] = {p: _reading(p) for p in pkgs}
        res["hashes_after"] = {p: _hashes(p) for p in pkgs}
        res["readings_match"] = res["before"] == res["after"]
        res["reloaded_from_disk"] = not res["still_in_memory"]
    except Exception as e:
        res["error"] = _err(e)
    return res


def _les():
    return unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)


def _eas():
    return unreal.get_editor_subsystem(unreal.EditorActorSubsystem)


def _world():
    return unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()


def _world_package():
    w = _world()
    return w.get_outermost().get_name() if w else None


def _spawn(cls, loc, rot=None, label=None, tags=(), transient=False):
    a = _eas().spawn_actor_from_class(cls, loc, rot or unreal.Rotator(roll=0.0, pitch=0.0, yaw=0.0), transient)
    if label:
        a.set_actor_label(label)
    if tags:
        a.set_editor_property("tags", [unreal.Name(t) for t in tags])
    return a


def _mesh_actor(mesh, loc, rot, label, tags, scale=None):
    a = _spawn(unreal.StaticMeshActor, loc, rot, label, tags)
    c = a.static_mesh_component
    c.set_mobility(unreal.ComponentMobility.MOVABLE)
    c.set_static_mesh(mesh)
    c.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)
    if scale:
        a.set_actor_scale3d(unreal.Vector(*scale))
    return a


def _rotation(cols):
    """rotation_cols are the local X/Y/Z axes in the parent frame; FMatrix stores basis axes as rows."""
    x, y, z = cols
    try:
        planes = [unreal.Plane(x=float(c[0]), y=float(c[1]), z=float(c[2]), w=0.0) for c in (x, y, z)]
        m = unreal.Matrix(x_plane=planes[0], y_plane=planes[1], z_plane=planes[2],
                          w_plane=unreal.Plane(x=0.0, y=0.0, z=0.0, w=1.0))
        return m.rotator(), "matrix"            # Conv_MatrixToRotator (ScriptMethod Rotator)
    except Exception:
        return unreal.MathLibrary.make_rot_from_xz(_vec(x), _vec(z)), "make_rot_from_xz"


def _axis_err(actor, cols):
    got = (actor.get_actor_forward_vector(), actor.get_actor_right_vector(), actor.get_actor_up_vector())
    return max(abs(getattr(g, k) - float(c[i])) for g, c in zip(got, cols) for i, k in enumerate("xyz"))


def build_review_scene(manifest, pose_names=("neutral", "crouch"), spacing_cm=400.0):
    if _pie():
        return _pie()
    res = {"map": REVIEW_MAP, "previous_level": _world_package(), "created": False, "deleted": 0, "actors": 0,
           "missing_meshes": [], "rotation_method": {}, "rotation_max_err": 0.0, "error": None}
    try:
        if EAL.does_asset_exist(REVIEW_MAP):
            ok = _les().load_level(REVIEW_MAP)
        else:
            ok = _les().new_level(REVIEW_MAP, False)
            res["created"] = True
        if not ok or _world_package() != REVIEW_MAP:
            res["error"] = "could not open %s (current level %s)" % (REVIEW_MAP, _world_package())
            return res
        for a in list(_eas().get_all_level_actors()):
            if a.actor_has_tag(TAG_REVIEW):
                _eas().destroy_actor(a)
                res["deleted"] += 1
        mid = (len(pose_names) - 1) * spacing_cm * 0.5
        _mesh_actor(unreal.load_asset(SHAPES + "Plane"), unreal.Vector(mid, 0.0, 0.0), None, PREFIX + "Ground",
                    [TAG_REVIEW], (10.0, 10.0, 1.0))
        sun = _spawn(unreal.DirectionalLight, unreal.Vector(0.0, 0.0, 500.0),
                     unreal.Rotator(roll=0.0, pitch=-45.0, yaw=-150.0), PREFIX + "NeutralSun", [TAG_REVIEW, TAG_LIGHT])
        sun.root_component.set_mobility(unreal.ComponentMobility.MOVABLE)
        lc = sun.get_component_by_class(unreal.DirectionalLightComponent)
        lc.set_intensity(SUN_LUX)
        lc.set_light_color(unreal.LinearColor(r=1.0, g=1.0, b=1.0, a=1.0))
        sky = _spawn(unreal.SkyLight, unreal.Vector(0.0, 0.0, 300.0), None, PREFIX + "NeutralSky", [TAG_REVIEW])
        sky.root_component.set_mobility(unreal.ComponentMobility.MOVABLE)
        sc = sky.get_component_by_class(unreal.SkyLightComponent)
        sc.set_editor_property("source_type", unreal.SkyLightSourceType.SLS_SPECIFIED_CUBEMAP)
        sc.set_editor_property("cubemap", unreal.load_asset(CUBEMAP))
        sc.set_intensity(SKY_INTENSITY)
        sc.recapture_sky()
        chef = manifest["chef_marker"]
        h = float(chef.get("height", 140.0))
        for i, pose in enumerate(pose_names):
            off = (i * spacing_cm, 0.0, 0.0)
            data = manifest["poses"][pose]
            cl = chef["location"]
            _mesh_actor(unreal.load_asset(SHAPES + "Cylinder"), _vec((cl[0], cl[1], h * 0.5), off), None,
                        "ChefMarker_140cm_%s" % pose, [TAG_REVIEW], (0.4, 0.4, h / 100.0))
            for inst in data["instances"]:
                mesh = base._load(_path(F_MESH, inst["mesh"]))
                if mesh is None:
                    res["missing_meshes"].append("%s/%s" % (pose, inst["id"]))
                    continue
                rot, method = _rotation(inst["rotation_cols"])
                res["rotation_method"][method] = res["rotation_method"].get(method, 0) + 1
                a = _mesh_actor(mesh, _vec(inst["location"], off), rot, "%s%s_%s" % (PREFIX, pose, inst["id"]),
                                [TAG_REVIEW, TAG_POSE + pose])
                res["rotation_max_err"] = max(res["rotation_max_err"], round(_axis_err(a, inst["rotation_cols"]), 6))
            if pose == "crouch":
                sphere = unreal.load_asset(SHAPES + "Sphere")
                for leg in data["legs"]:
                    for j in ("hip", "knee", "ankle", "foot"):
                        if leg.get(j):
                            _mesh_actor(sphere, _vec(leg[j], off), None, "%scrouch_%s_%s" % (PREFIX, leg["id"], j),
                                        [TAG_REVIEW, TAG_JOINTS], (0.06, 0.06, 0.06))
        res["saved"] = bool(_les().save_current_level())
        res["actors"] = sum(1 for a in _eas().get_all_level_actors() if a.actor_has_tag(TAG_REVIEW))
        ext = os.path.join(_content_dir(), "__ExternalActors__", *F_REVIEW[len("/Game/"):].split("/"))
        res["external_actors_dir"] = ext if os.path.isdir(ext) else None   # would be outside F_ROOT: report it
    except Exception as e:
        res["error"] = _err(e)
    return res


def _write_png_rgb(path, w, h, samples):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for c in samples[y * w:(y + 1) * w]:
            raw.extend((c.r, c.g, c.b))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) +
                chunk(b"IDAT", zlib.compress(bytes(raw), 6)) + chunk(b"IEND", b""))


def _opaque_png(world, rt, path, w, h):
    """FinalColorLDR's alpha is not guaranteed opaque; if sampled alpha is not 255, rewrite the PNG as RGB."""
    rl = unreal.RenderingLibrary
    probes = [rl.read_render_target_pixel(world, rt, x, y) for x, y in ((w // 2, h // 2), (1, 1), (w - 2, h - 2))]
    if all(p.a == 255 for p in probes):
        return False
    r = rl.read_render_target(world, rt, True)
    samples = list(r[-1] if isinstance(r, tuple) else r)
    if len(samples) != w * h:
        raise RuntimeError("read_render_target returned %d samples, expected %d" % (len(samples), w * h))
    _write_png_rgb(path, w, h, samples)
    return True


def _views(c, body, manifest, pose, off):
    d = VIEW_DIST
    e, a = math.radians(35.0), math.radians(45.0)
    out = [("front", c + unreal.Vector(d, 0.0, 0.0), c), ("right_side", c + unreal.Vector(0.0, d, 0.0), c),
           ("rear", c + unreal.Vector(-d, 0.0, 0.0), c), ("top", c + unreal.Vector(0.0, 0.0, d), c),
           ("three_quarter", c + unreal.Vector(d * math.cos(e) * math.cos(a), d * math.cos(e) * math.sin(a),
                                               d * math.sin(e)), c)]
    data = (manifest or {}).get("poses", {}).get(pose)
    if data and data.get("chelicerae"):
        roots = [ch["root"] for ch in data["chelicerae"]]
        head = _vec([sum(r[k] for r in roots) / len(roots) for k in range(3)], off)
    else:
        origin, extent = body.get_actor_bounds(False)
        head = unreal.Vector(origin.x + extent.x, origin.y, origin.z)
    out.append(("face_closeup", head + unreal.Vector(FACE_DIST * 0.985, 0.0, -FACE_DIST * 0.17), head))
    leg = next((lg for lg in (data or {}).get("legs", []) if lg["id"] == KNEE_LEG), None)
    if leg:
        knee = _vec(leg["knee"], off)
        n = math.sqrt(0.35 ** 2 + 0.9 ** 2 + 0.25 ** 2)
        out.append(("knee_closeup", knee + unreal.Vector(0.35, 0.9, 0.25) * (KNEE_DIST / n), knee))
    return out


def capture_views(out_dir, pose="neutral", lighting="neutral", size=(1600, 1200), spacing_cm=400.0, manifest=None):
    if _pie():
        return _pie()
    res = {"pose": pose, "lighting": lighting, "written": [], "alpha_rewritten": [], "skipped_views": [], "error": None}
    if _world_package() != REVIEW_MAP:
        res["error"] = "open %s first (build_review_scene); current level is %s" % (REVIEW_MAP, _world_package())
        return res
    if lighting not in EXPOSURE_EV100:
        res["error"] = "lighting must be one of %s" % sorted(EXPOSURE_EV100)
        return res
    world, w, h = _world(), int(size[0]), int(size[1])
    os.makedirs(out_dir, exist_ok=True)
    actors = list(_eas().get_all_level_actors())
    body = next((a for a in actors if a.actor_has_tag(TAG_POSE + pose) and a.get_actor_label() == "%s%s_Body" % (PREFIX, pose)), None)
    if body is None:
        res["error"] = "no %s%s_Body actor in the review map" % (PREFIX, pose)
        return res
    off = (round(body.get_actor_location().x / spacing_cm) * spacing_cm, 0.0, 0.0)
    c = unreal.Vector(off[0], 0.0, 40.0)
    res["centre"] = _v(c)
    suns, temp, cap, rt = [], [], None, None
    try:
        if lighting == "dungeon":
            suns = [a.get_component_by_class(unreal.DirectionalLightComponent) for a in actors if a.actor_has_tag(TAG_LIGHT)]
            for s in suns:
                s.set_visibility(False)
            for colour, cd, o in (AMBER, TEAL):
                p = _spawn(unreal.PointLight, c + unreal.Vector(*o), transient=True)
                p.root_component.set_mobility(unreal.ComponentMobility.MOVABLE)
                pc_ = p.get_component_by_class(unreal.PointLightComponent)
                pc_.set_editor_property("intensity_units", unreal.LightUnits.CANDELAS)
                pc_.set_intensity(cd)
                pc_.set_light_color(unreal.LinearColor(r=colour[0], g=colour[1], b=colour[2], a=1.0))
                pc_.set_attenuation_radius(1500.0)
                temp.append(p)
        rt = unreal.RenderingLibrary.create_render_target2d(world, w, h, unreal.TextureRenderTargetFormat.RTF_RGBA8,
                                                             unreal.LinearColor(r=0.0, g=0.0, b=0.0, a=1.0), False, False)
        cap = _spawn(unreal.SceneCapture2D, c, transient=True)
        comp = cap.get_editor_property("capture_component2d")
        comp.set_editor_property("texture_target", rt)
        comp.set_editor_property("capture_source", unreal.SceneCaptureSource.SCS_FINAL_COLOR_LDR)
        comp.set_editor_property("capture_every_frame", False)
        comp.set_editor_property("capture_on_movement", False)
        comp.set_editor_property("always_persist_rendering_state", True)
        comp.set_editor_property("fov_angle", FOV)
        pp = comp.get_editor_property("post_process_settings")
        for k, v in (("override_auto_exposure_method", True), ("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL),
                     ("override_auto_exposure_apply_physical_camera_exposure", True),
                     ("auto_exposure_apply_physical_camera_exposure", False),
                     ("override_auto_exposure_bias", True), ("auto_exposure_bias", EXPOSURE_EV100[lighting])):
            pp.set_editor_property(k, v)
        comp.set_editor_property("post_process_settings", pp)
        # the poses stand spacing_cm apart along X and the full views sit VIEW_DIST out, inside the neighbour's legs:
        # hide every actor of the other poses (pieces, their chef marker, the crouch joint spheres) from this capture
        others = [t for t in (TAG_POSE + "neutral", TAG_POSE + "crouch") if t != TAG_POSE + pose]
        hidden = [a for a in actors if any(a.actor_has_tag(t) for t in others)
                  or (a.get_actor_label().startswith("ChefMarker_140cm_") and not a.get_actor_label().endswith("_" + pose))
                  or (a.actor_has_tag(TAG_JOINTS) and pose != "crouch")]
        for a in hidden:                      # HiddenActors itself is not editable through reflection
            comp.hide_actor_components(a, False)
        res["hidden_actors"] = len(hidden)
        views = _views(c, body, manifest, pose, off)
        res["skipped_views"] = [v for v in VIEWS if v not in [n for n, _, _ in views]]
        for name, loc, target in views:
            rot = unreal.Rotator(roll=0.0, pitch=-90.0, yaw=0.0) if name == "top" else \
                unreal.MathLibrary.find_look_at_rotation(loc, target)
            cap.set_actor_location(loc, False, True)
            cap.set_actor_rotation(rot, True)
            for _ in range(WARMUP_CAPTURES):
                comp.capture_scene()
            fname = "UE_%s_%s_%s.png" % (pose, lighting, name)
            unreal.RenderingLibrary.export_render_target(world, rt, out_dir, fname)
            path = os.path.abspath(os.path.join(out_dir, fname))
            if not os.path.isfile(path):
                raise RuntimeError("export_render_target wrote nothing at " + path)
            if _opaque_png(world, rt, path, w, h):
                res["alpha_rewritten"].append(name)
            res["written"].append(path)
    except Exception as e:
        res["error"] = _err(e)
    finally:
        for a in temp + ([cap] if cap else []):
            _eas().destroy_actor(a)
        for s in suns:
            s.set_visibility(True)
        if rt is not None:
            unreal.RenderingLibrary.release_render_target2d(rt)
    return res


def restore_level(path):
    if _pie():
        return _pie()
    if not path or path.startswith("/Temp"):
        return {"loaded": False, "error": "no saved level to restore (%r)" % path}
    try:
        return {"loaded": bool(_les().load_level(path)), "current_level": _world_package(), "error": None}
    except Exception as e:
        return {"loaded": False, "error": _err(e)}


def run_import(export_dir):
    if _pie():
        return _pie()
    try:
        manifest = load_manifest(export_dir)
        for folder in (F_MESH, F_MAT, F_REVIEW):
            EAL.make_directory(folder)
    except Exception as e:
        return {"error": _err(e)}
    return {"export_dir": export_dir, "materials": create_materials(manifest),
            "import": import_meshes(manifest, export_dir), "candidates": list_candidate_assets()}
