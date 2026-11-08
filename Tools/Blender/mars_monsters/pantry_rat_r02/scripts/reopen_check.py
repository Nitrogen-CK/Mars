"""Pantry Rat R02 (copied from ../pantry_rat_r01/scripts/reopen_check.py; R01 -> R02 names / paths, R02 review folders) - reopen proof. Opens source/PantryRat_R02.blend in a fresh background process and verifies the
collections, the export mesh + armature, the 26 bones and parents vs RIG.json, the material slot order, the skin, the
Carry frames and that every pose action exists.

Run:  blender -b --factory-startup --python scripts/reopen_check.py
Prints PANTRY_RAT_OK or PANTRY_RAT_FAIL <reason>; exits non-zero on failure.
"""
import json
import os
import sys
import traceback

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BLEND = os.path.join(ROOT, "source", "PantryRat_R02.blend")
RIG_JSON = os.path.join(ROOT, "RIG.json")
POSES = ["neutral", "crouch", "stretch", "bound_apex", "rear_up", "jaw_carry", "look_back", "topple_left",
         "topple_right", "dead_back", "den_crouch", "rummage", "rummage_p3", "rear_rummage", "drag_carry"]
SLOTS = ["Body", "Pink", "Belly", "Wood", "Harness", "EyePatch"]


def main():
    fails = []
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    for c in ("Authoring", "Rig", "Export", "Props", "Review"):
        if c not in bpy.data.collections:
            fails.append("collection %s" % c)
    exp = bpy.data.collections.get("Export")
    meshes = [o for o in exp.objects if o.type == "MESH"] if exp else []
    arms = [o for o in exp.objects if o.type == "ARMATURE"] if exp else []
    if [o.name for o in meshes] != ["PantryRat_R02_Body"] or [o.name for o in arms] != ["PantryRat_R02_Armature"]:
        fails.append("export objects %s %s" % ([o.name for o in meshes], [o.name for o in arms]))
    body, arm = bpy.data.objects.get("PantryRat_R02_Body"), bpy.data.objects.get("PantryRat_R02_Armature")
    with open(RIG_JSON) as fh:
        rig = json.load(fh)
    want = {b["name"]: b["parent"] for b in rig["bones"]}
    got = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
    if got != want:
        fails.append("bones differ: missing %s extra %s parents %s" % (
            sorted(set(want) - set(got)), sorted(set(got) - set(want)),
            [n for n in want if n in got and got[n] != want[n]]))
    leaf = [b.name for b in arm.data.bones if b.name.endswith("_end") or b.name.endswith("_leaf")]
    if leaf:
        fails.append("leaf bones %s" % leaf)
    slots = [m.name for m in body.data.materials]
    if slots != SLOTS:
        fails.append("slots %s" % slots)
    mods = [m for m in body.modifiers if m.type == "ARMATURE" and m.object == arm]
    if not mods or body.parent != arm:
        fails.append("skin binding")
    maxinf, unw = 0, 0
    for v in body.data.vertices:
        ws = [g.weight for g in v.groups if g.weight > 0]
        maxinf = max(maxinf, len(ws))
        unw += 0 if ws else 1
    if maxinf > 3 or unw:   # R02: max 3 influences
        fails.append("weights maxinf %d unweighted %d" % (maxinf, unw))
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    acts = sorted(a.name for a in bpy.data.actions)
    missing = [p for p in POSES if "PantryRat_R02_Pose_" + p not in acts]
    if missing:
        fails.append("pose actions missing %s" % missing)
    # R02: the 34 clips of the frozen clip contract, flat shading on every face
    import csv
    man = os.path.abspath(os.path.join(ROOT, "..", "..", "..", "..", "docs", "art", "pantry-rat-dens-production-r01",
                                       "ANIMATION_MANIFEST.csv"))
    names = [r["name"] for r in csv.DictReader(open(man, newline="", encoding="utf-8"))] + ["Walk"]   # Phase 9 (D9-1)
    miss_clips = [n for n in names if n not in acts]
    if len(names) != 35 or miss_clips:
        fails.append("clips %d missing %s" % (len(names), miss_clips))
    smooth = sum(1 for p in body.data.polygons if p.use_smooth)
    if smooth:
        fails.append("smooth-shaded faces %d" % smooth)
    for n in ("Carry_Mouth", "Carry_Drag"):
        o = bpy.data.objects.get(n)
        if o is None or o.parent != arm or o.parent_bone != "jaw":
            fails.append("%s frame" % n)
    for n in ("Den_StoneArch_Shell", "Den_Recess", "Den_BackPlane", "Den_EyePlate", "EntryPortal", "ExitPortal",
              "OutsideStand", "ReturnAdmission", "Cheese_MonksRind", "Backpack_Proxy", "Pocket1", "Pocket2", "Pocket3",
              "Mushroom_AtPocket2", "Crate_1", "Crate_2", "Chef_Capsule_r39_hh75", "Court_Floor"):
        if n not in bpy.data.objects:
            fails.append("prop %s" % n)
    print("REOPEN", json.dumps({"bones": len(got), "slots": slots, "tris": tris, "verts": len(body.data.vertices),
                                "max_influences": maxinf, "pose_actions": len([a for a in acts if "Pose_" in a]),
                                "clip_actions": len(names) - len(miss_clips), "smooth_faces": smooth,
                                "file": BLEND}))
    return fails


if __name__ == "__main__":
    try:
        fails = main()
    except Exception as exc:  # noqa: BLE001
        traceback.print_exc()
        fails = ["exception %s" % exc]
    if fails:
        print("PANTRY_RAT_FAIL " + "; ".join(fails))
        sys.exit(1)
    print("PANTRY_RAT_OK")
    sys.exit(0)
