"""Phase J Part 1e: close-up renders of SRC_Tug f15 (stem base at the bulb, mid-stalk, the crown / blade attachment) to
judge the ~33x stalks (ribbons, ring gaps, blade attachment). Writes review/phaseJ/closeups/*.png and closeup_4x.png.
Run: "$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python review/phaseJ/closeup_j.py"""
import os, sys
ROOT = "D:/Repositories/CkRepos/Orion/Tools/Blender/mars_ingredients/screaming_turnip_r01"
sys.path.insert(0, ROOT + "/scripts")
import bpy
from mathutils import Vector
import build_screaming_turnip as BT
import render_screaming_turnip as R
OUT = ROOT + "/review/phaseJ/closeups"
sc = bpy.context.scene
R.setup(sc, 600)
arm = bpy.data.objects[BT.ARM_NAME]
arm.hide_render = True
arm.animation_data_create()
act = bpy.data.actions["SRC_Tug"]
arm.animation_data.action = act
if arm.animation_data.action_slot is None:
    arm.animation_data.action_slot = act.slots[0]
key = bpy.data.objects[BT.MESH_NAME].data.shape_keys
kad = key.animation_data or key.animation_data_create()
kad.action = bpy.data.actions["SRC_Tug_Key"]
if kad.action_slot is None:
    kad.action_slot = kad.action.slots[0]
for n in (BT.BED_EMPTY_NAME, BT.COLL_NAME):
    bpy.data.objects[n].hide_render = True
bpy.data.objects[BT.BED_NAME].hide_render = False
cam = bpy.data.objects["ReviewCam"]
sc.camera = cam
sc.frame_set(15)
crown = arm.matrix_world @ arm.pose.bones["crown"].head
base = Vector((0.0, 0.0, 33.0))
mid = (crown + base) * 0.5
tiles = []
for name, tgt, ortho in (("base", base, 6.0), ("mid", mid, 6.0), ("crown", crown, 8.0)):
    for view in ("side", "threequarter"):
        tiles.append(R.shot(sc, cam, os.path.join(OUT, "f15_%s_%s.png" % (name, view)), view,
                            "SRC_Tug f15 %s %s (%.0f cm wide)" % (name, view, ortho * 3), tgt, ortho))
R.save_sheet(tiles, 2, ROOT + "/review/phaseJ/closeup_4x.png")
print("TURNIP_OK closeup")
