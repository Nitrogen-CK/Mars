"""One-off (2026-11-07): reimport the repaired Monk's Rind FBX (faces now wound outward) over
/Game/ArtCandidates/PantryRat/R02/Props/PantryRat_R02_Cheese_Mars_SM, re-apply the Rind/Flesh MIs and the box collision
exactly as import_statics does, save only that asset, and print a JSON readback. Runs in the editor's Python via
Monolith editor_query run_python (execute_file)."""
import json
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pantry_rat_import_ue as im  # noqa: E402

NAME = "PantryRat_R02_Cheese_Mars_SM"
FBX, COLL = im.STATICS[NAME]
rep = {"name": NAME, "fbx": os.path.join(im.EXPORT, FBX), "fbx_mtime": os.path.getmtime(os.path.join(im.EXPORT, FBX))}
before = im._load(im._path(im.F_PROPS, NAME))
rep["existed_before"] = before is not None
task = im._task(rep["fbx"], im.F_PROPS, NAME, im._sm_opts())
with im._LegacyFbx() as flag:
    unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
rep["interchange_flag_before_after"] = [flag.was, flag.after]
sm = im._load(im._path(im.F_PROPS, NAME))
if sm is None:
    rep["error"] = "static mesh missing after import"
else:
    sel = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
    mats = list(sm.static_materials)
    for i, m in enumerate(mats):
        slot = str(m.material_slot_name)
        mat = im._load(im._path(im.F_MAT, im.MI % slot))
        if mat is not None:
            m.set_editor_property("material_interface", mat)
            mats[i] = m
    sm.set_editor_property("static_materials", mats)
    sel.remove_collisions(sm)
    sel.add_simple_collisions(sm, unreal.ScriptCollisionShapeType.BOX)
    rep["slots"] = [str(m.material_slot_name) for m in sm.static_materials]
    rep["materials"] = [m.material_interface.get_path_name() if m.material_interface else None for m in sm.static_materials]
    b = sm.get_bounding_box()
    rep["bounds"] = {"min": [round(b.min.x, 3), round(b.min.y, 3), round(b.min.z, 3)],
                     "max": [round(b.max.x, 3), round(b.max.y, 3), round(b.max.z, 3)]}
    rep["tris_lod0"] = sm.get_num_triangles(0)
    rep["verts_lod0"] = sm.get_num_vertices(0)
    rep["saved"] = im.save_owned([sm])
print("CHEESE_REIMPORT " + json.dumps(rep))
