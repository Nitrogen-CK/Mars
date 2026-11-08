"""One-off repair (2026-11-07): the Monk's Rind wedge was hand-wound inside-out (all 56 faces; build_cheese now calls
rc.orient_closed_islands). Flips Cheese_MonksRind in source/PantryRat_R02.blend, saves it, and re-exports only
export/PantryRat_R02_Cheese_Mars_SM.fbx with the export script's own cheese recipe (slot split by colour, box UV0).
Run: blender -b --factory-startup source/PantryRat_R02.blend --python scripts/fix_cheese_normals.py
"""
import os
import sys

import bmesh
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import export_pantry_rat as ex  # noqa: E402

ch = bpy.data.objects["Cheese_MonksRind"]
me = ch.data
c = sum((v.co for v in me.vertices), bpy.data.objects["Cheese_MonksRind"].location * 0) / len(me.vertices)
inward_before = sum(1 for p in me.polygons if p.normal.dot(p.center - c) < 0)
if inward_before == len(me.polygons):
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    me.update()
inward_after = sum(1 for p in me.polygons if p.normal.dot(p.center - c) < 0)
print("CHEESE_FLIP inward before %d after %d of %d" % (inward_before, inward_after, len(me.polygons)))
assert inward_after == 0, "cheese still has inward faces"
bpy.ops.wm.save_mainfile(filepath=bpy.data.filepath)
print("SAVED", bpy.data.filepath)

sc = bpy.context.scene
cme = ch.data.copy()
cob = bpy.data.objects.new("PantryRat_R02_Cheese_Mars_SM", cme)
sc.collection.objects.link(cob)
cme.materials.clear()
for s_ in ("Rind", "Flesh"):
    cme.materials.append(bpy.data.materials.get(s_) or bpy.data.materials.new(s_))
col = cme.color_attributes.get("Col")
cnt = {"Rind": 0, "Flesh": 0}
for p_ in cme.polygons:
    cc = np.mean([tuple(col.data[li].color_srgb if col.domain == "CORNER" else
                        col.data[cme.loops[li].vertex_index].color_srgb)[:3] for li in p_.loop_indices], axis=0)
    rind = (cc[0] - cc[2]) > 0.3
    p_.material_index = 0 if rind else 1
    cnt["Rind" if rind else "Flesh"] += 1
ex.box_uv(cme)
p = os.path.join(ex.OUT, "PantryRat_R02_Cheese_Mars_SM.fbx")
ex.export_static(cob, p)
print("EXPORTED", p, cnt, ex.mesh_facts(cob))
