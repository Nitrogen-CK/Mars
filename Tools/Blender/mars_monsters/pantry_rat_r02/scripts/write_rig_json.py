"""Pantry Rat R02 - write RIG.json from the built armature (names / parents identical to ../RIG_R01.json, the frozen
contract; R02 rest heads / tails added). blender -b --factory-startup source/PantryRat_R02.blend --python scripts/write_rig_json.py"""
import json
import os
import sys

import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
r01 = json.load(open(os.path.join(ROOT, "RIG_R01.json")))
arm = bpy.data.objects["PantryRat_R02_Armature"]
got = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
want = {b["name"]: b["parent"] for b in r01["bones"]}
ok = got == want
out = dict(r01)
out["name"] = "PantryRat_R02"
out["source"] = "R02_BRIEF.md (rig contract frozen: the 26 bones of ../pantry_rat_r01/RIG.json, names / parents / roles unchanged; rest positions follow the R02 proportions)"
out["bones"] = [{"name": b.name, "parent": b.parent.name if b.parent else None,
                 "rest_head_cm": [round(c, 4) for c in b.head_local], "rest_tail_cm": [round(c, 4) for c in b.tail_local]}
                for b in arm.data.bones]
out["names_parents_match_R01"] = ok
json.dump(out, open(os.path.join(ROOT, "RIG.json"), "w"), indent=1)
print("RIG_JSON", ok, len(out["bones"]))
print("PANTRY_RAT_OK" if ok else "PANTRY_RAT_FAIL")
sys.exit(0 if ok else 1)
