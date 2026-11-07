"""Editor side of the eye swarm pieces (build_eye_swarm_pieces.py): imports the EyeSwarm_<Part>_Mars_SM FBXs (Eyeball,
Eyelid, Socket) through the Send to Unreal prop importer into /Game/Mars/Gameplay/Monsters/EyeSwarm/Meshes, and builds the
material parameter collection EyeSwarm_Mars_MPC (four Vector parameters Player0..Player3, default (0, 0, -1e7, 0): the
"absent player" sentinel the eye shader ignores). It does NOT create materials: the eye materials are CkUsf generated looks;
a slot already bound keeps its material across re-imports, and a slot still on the default material is bound to a
material named <Slot>_Mars_MI under /Game/Mars if one exists by then.

Vertex colours are the contract (RGB = the vertex's unit direction * 0.5 + 0.5 in the mesh's frame, A = 1; see the
builder's docstring), so the import MUST replace them from the FBX: mars_prop_ue._options() sets
static_mesh_import_data.vertex_color_import_option = REPLACE (through mars_character_ue._set, which skips a missing
property silently), and import_meshes() re-asserts that on the meshes' own import data after the import and reports the
stored colours (mesh_report: vertex-colour presence per LOD 0 via has_vertex_colors). Nanite off (build_nanite False in
the import options and nanite_settings.enabled False on the asset), no collision (the import makes none; remove_collisions
clears anything left, and the body setup's default profile is NoCollision): the eyes are drawn as instances and never
collide.

Re-runnable: meshes re-imported IN PLACE, the MPC kept (existing parameters keep their ids; missing ones are added, the
four Player defaults re-asserted).

Run in a hidden editor (never during PIE):
    python ../../mars_environment/unreal/env_drive.py --port 9317 --module mars_eye_swarm_ue --alias es \
        --call "es.run_all()"
(env_drive puts its own folder on sys.path; this module adds its own.)
"""
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
SEND_TO_UNREAL = os.path.join(os.path.dirname(os.path.dirname(HERE)), "mars_send_to_unreal", "unreal")
for _p in (SEND_TO_UNREAL, HERE):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import mars_prop_ue  # noqa: E402

EAL = unreal.EditorAssetLibrary

EXPORT_DIR = r"D:\Repo\Content\Monsters\EyeSwarm\export"
F_ROOT = "/Game/Mars/Gameplay/Monsters/EyeSwarm"
F_MESH = F_ROOT + "/Meshes"
F_MAT = F_ROOT + "/Materials"
PIECES = ("Eyeball", "Eyelid", "Socket")
MPC = "EyeSwarm_Mars_MPC"
ABSENT = (0.0, 0.0, -1.0e7, 0.0)                # a player slot nobody fills: far below the world
MPC_VECTORS = {"Player%d" % k: ABSENT for k in range(4)}


def mesh_name(part):
    return "EyeSwarm_%s_Mars_SM" % part


def _tools():
    return unreal.AssetToolsHelpers.get_asset_tools()


def _path(folder, name):
    return "%s/%s.%s" % (folder, name, name)


def _load(folder, name):
    p = _path(folder, name)
    return unreal.load_asset(p) if EAL.does_asset_exist(p) else None


def _try_set(obj, prop, value):
    try:
        obj.set_editor_property(prop, value)
        return True
    except Exception as exc:  # noqa: BLE001 - report, never abort the import over a cosmetic property
        unreal.log_warning("EyeSwarm: could not set %s.%s (%s)" % (type(obj).__name__, prop, exc))
        return False


def _finish_mesh(mesh):
    """No Nanite, no collision, vertex colours replaced on any later re-import from the asset's own import data."""
    notes = {}
    nanite = mesh.get_editor_property("nanite_settings")
    if nanite is not None and nanite.get_editor_property("enabled"):
        nanite.set_editor_property("enabled", False)
        notes["nanite"] = _try_set(mesh, "nanite_settings", nanite) and "disabled"
    else:
        notes["nanite"] = "off"
    unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem).remove_collisions(mesh)
    body = mesh.get_editor_property("body_setup")
    if body is not None:
        inst = body.get_editor_property("default_instance")
        if _try_set(inst, "collision_profile_name", "NoCollision"):
            _try_set(body, "default_instance", inst)
        _try_set(body, "collision_trace_flag", unreal.CollisionTraceFlag.CTF_USE_SIMPLE_AS_COMPLEX)
    data = mesh.get_editor_property("asset_import_data")
    if isinstance(data, unreal.FbxStaticMeshImportData):
        notes["vertex_color_import_option"] = str(data.get_editor_property("vertex_color_import_option"))
        if data.get_editor_property("vertex_color_import_option") != unreal.VertexColorImportOption.REPLACE:
            _try_set(data, "vertex_color_import_option", unreal.VertexColorImportOption.REPLACE)
            notes["vertex_color_import_option"] += " -> REPLACE"
    return notes


def import_meshes():
    jobs = [{"fbx": os.path.join(EXPORT_DIR, mesh_name(p) + ".fbx").replace("\\", "/"), "name": mesh_name(p),
             "folder": F_MESH, "sockets": []} for p in PIECES]
    res = mars_prop_ue.import_props(jobs, {"search_root": "/Game/Mars", "material_pattern": "{slot}_Mars_MI"},
                                    save=False)
    res["finish"] = {}
    for p in PIECES:
        mesh = _load(F_MESH, mesh_name(p))
        if mesh is None:
            continue
        res["finish"][p] = _finish_mesh(mesh)
        EAL.save_loaded_asset(mesh)
    return res


def build_mpc():
    """EyeSwarm_Mars_MPC with Vector parameters Player0..Player3 (default ABSENT). Existing parameters keep their ids;
    missing ones are added; the four Player defaults are re-asserted. Returns the parameter names and defaults."""
    EAL.make_directory(F_MAT)
    mpc = _load(F_MAT, MPC)
    if mpc is None:
        mpc = _tools().create_asset(MPC, F_MAT, unreal.MaterialParameterCollection,
                                    unreal.MaterialParameterCollectionFactoryNew())
    vectors = list(mpc.get_editor_property("vector_parameters"))
    by_name = {str(p.get_editor_property("parameter_name")): k for k, p in enumerate(vectors)}
    for name, value in MPC_VECTORS.items():
        if name in by_name:
            p = vectors[by_name[name]]
        else:
            p = unreal.CollectionVectorParameter()
            p.set_editor_property("parameter_name", name)
            vectors.append(p)
        p.set_editor_property("default_value", unreal.LinearColor(*value))
        if name in by_name:
            vectors[by_name[name]] = p
    mpc.set_editor_property("vector_parameters", vectors)
    EAL.save_loaded_asset(mpc)
    out = {}
    for p in mpc.get_editor_property("vector_parameters"):
        c = p.get_editor_property("default_value")
        out[str(p.get_editor_property("parameter_name"))] = [c.r, c.g, c.b, c.a]
    return out


def mesh_report():
    out = {}
    for p in PIECES:
        mesh = _load(F_MESH, mesh_name(p))
        if mesh is None:
            out[p] = None
            continue
        box = mesh.get_bounding_box()
        body = mesh.get_editor_property("body_setup")
        agg = body.get_editor_property("agg_geom") if body else None
        prims = sum(len(agg.get_editor_property(k)) for k in ("sphere_elems", "box_elems", "sphyl_elems",
                                                                "convex_elems")) if agg else 0
        sme = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
        info = {"min": [round(v, 3) for v in (box.min.x, box.min.y, box.min.z)],
                "max": [round(v, 3) for v in (box.max.x, box.max.y, box.max.z)],
                "verts": sme.get_number_verts(mesh, 0),
                "nanite": bool(mesh.get_editor_property("nanite_settings").get_editor_property("enabled")),
                "collision_prims": prims,
                "materials": {str(m.material_slot_name): (m.material_interface.get_name() if m.material_interface
                                                          else None) for m in mesh.static_materials}}
        try:
            info["tris"] = int(mesh.get_num_triangles(0))
        except Exception:  # noqa: BLE001
            info["tris"] = None
        try:
            info["vertex_colors"] = bool(sme.has_vertex_colors(mesh))
        except Exception:  # noqa: BLE001
            info["vertex_colors"] = None
        out[p] = info
    return out


def run_all():
    if mars_prop_ue.base._in_pie():
        return {"error": "the editor is in PIE - stop it and run again"}
    for folder in (F_MESH, F_MAT):
        EAL.make_directory(folder)
    res = import_meshes()
    mpc = build_mpc()
    return {"import": res, "mpc": mpc, "meshes": mesh_report()}
