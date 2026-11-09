"""Phase J: audit SRC_Tug / Cancel / Release from the saved actions at sub-frame steps (the bed scrubs Tug by alpha)."""
import sys, json
sys.path.insert(0, "D:/Repositories/CkRepos/Orion/Tools/Blender/mars_ingredients/screaming_turnip_r01/scripts")
import bpy
import build_screaming_turnip as BT
import animate_screaming_turnip as A
import turnip_audit
arm = bpy.data.objects[BT.ARM_NAME]; ob = bpy.data.objects[BT.MESH_NAME]
sc = bpy.context.scene
out = {}
for name, end in (("SRC_Tug", 15), ("SRC_Cancel", 7), ("SRC_Release", 6)):
    arm.animation_data_create(); arm.animation_data.action = bpy.data.actions[name]
    if arm.animation_data.action_slot is None:
        arm.animation_data.action_slot = bpy.data.actions[name].slots[0]
    A.assign(ob.data.shape_keys, bpy.data.actions[name + "_Key"])
    bad, gap, n = {}, -9, 0
    for i in range(end * 10 + 1):
        t = i / 10.0
        sc.frame_set(int(t), subframe=t - int(t))
        co, tris, tp, tl = turnip_audit.evaluated(ob)
        gap = max(gap, max(A.stem_gap(co, tris, tp, tl)))
        isx = turnip_audit.intersections(ob, BT.PART)
        b = {k: x for k, x in isx.items() if x and "(info)" not in k and "(sum)" not in k}
        if b:
            bad["%.1f" % t] = b
        n += 1
    out[name] = {"samples": n, "step_frames": 0.1, "stem_gap_max_cm": round(gap, 3), "isect": bad}
    print("SUB", name, json.dumps(out[name]), flush=True)
arm.animation_data.action = None
json.dump(out, open("D:/Repositories/CkRepos/Orion/Tools/Blender/mars_ingredients/screaming_turnip_r01/review/phaseJ/subframe_audit.json", "w"), indent=1)
print("TURNIP_OK subframe" if not any(v["isect"] for v in out.values()) else "TURNIP_FAIL subframe")
