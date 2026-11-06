"""Cellar Bat R01 - bake a control-rig action onto the export armature (Phase 3).

The animator works on `CellarBat_R01_Controls` (bat_rig.py). This bakes any of its actions onto the 42 export bones
with `bpy.ops.nla.bake(visual_keying=True)` (every frame, every bone, rotation/location/scale keys), names the result,
then MUTES the rig constraints so the export armature plays the baked keys alone, and proves the bake: for every frame
the baked pose (constraints muted, controls unassigned) must equal the live rig pose (constraints on, control action)
within 0.001 cm / 0.01 deg, and the root bone must stay at the identity.

Usable as a module (export_cellar_bat.py imports `bake`) or standalone:
  blender -b --factory-startup source/CellarBat_R01.blend --python scripts/bake_cellar_bat.py -- \
      --action CellarBat_R01_FlapTest_Ctl [--name CellarBat_R01_FlapTest] [--start 0 --end 15] [--fbx <path>]
Standalone runs never save the .blend (the builder owns it). Prints CELLAR_BAT_OK / CELLAR_BAT_FAIL <reason>.
"""
import json
import math
import os
import sys
import traceback

import bpy
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import bat_rig  # noqa: E402

ARM_NAME = "CellarBat_R01_Armature"
TOL_CM, TOL_DEG = 1e-3, 0.01


def bake(action_name, baked_name=None, start=None, end=None):
    sc = bpy.context.scene
    arm = bpy.data.objects[ARM_NAME]
    ctrl = bpy.data.objects[bat_rig.CTRL_NAME]
    act = bpy.data.actions[action_name]
    if start is None or end is None:
        fr = act.frame_range
        start, end = int(round(fr[0])), int(round(fr[1]))
    baked_name = baked_name or action_name.replace("_Ctl", "")
    old = bpy.data.actions.get(baked_name)
    if old is not None:
        bpy.data.actions.remove(old)

    # live rig reference
    bat_rig.mute(arm, False)
    if arm.animation_data:
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bat_rig.use_action(ctrl, act, start)
    ref = {}
    for f in range(start, end + 1):
        sc.frame_set(f)
        ref[f] = bat_rig.pose_matrices(arm)

    # bake (visual keying) onto the export armature
    for o in bpy.context.view_layer.objects:
        o.select_set(o is arm)
    bpy.context.view_layer.objects.active = arm
    arm.hide_set(False)
    bpy.ops.object.mode_set(mode="POSE")
    for pb in arm.pose.bones:          # Blender 5.x keeps bone selection on the pose bone
        if hasattr(pb, "select"):
            pb.select = True
        else:
            pb.bone.select = True
    bpy.ops.nla.bake(frame_start=start, frame_end=end, step=1, only_selected=False, visual_keying=True,
                     clear_constraints=False, clear_parents=False, use_current_action=False, clean_curves=False,
                     bake_types={"POSE"})
    bpy.ops.object.mode_set(mode="OBJECT")
    baked = arm.animation_data.action
    baked.name = baked_name
    baked.use_fake_user = True

    # prove it: constraints muted, controls unassigned -> baked keys alone reproduce the rig
    bat_rig.mute(arm, True)
    bat_rig.use_action(ctrl, None, start)
    bat_rig.reset(ctrl)
    dp, da, root_dev = 0.0, 0.0, 0.0
    for f in range(start, end + 1):
        sc.frame_set(f)
        m = bat_rig.pose_matrices(arm)
        p, a = bat_rig.compare(m, ref[f])
        dp, da = max(dp, p), max(da, a)
        rq = m["root"].to_quaternion()
        root_dev = max(root_dev, m["root"].translation.length, math.degrees(rq.angle) if rq.angle <= math.pi else 0)
    keyed = set()
    for fc in _fcurves(baked):
        if fc.data_path.startswith('pose.bones["'):
            keyed.add(fc.data_path.split('"')[1])
    nonuni = 0
    for fc in _fcurves(baked):
        if fc.data_path.endswith(".scale"):
            nonuni += sum(1 for k in fc.keyframe_points if abs(k.co[1] - 1.0) > 1e-5)
    report = {"control_action": action_name, "baked_action": baked.name, "frames": [start, end],
              "frame_count": end - start + 1, "keyed_bones": len(keyed), "max_head_err_cm": round(dp, 6),
              "max_rot_err_deg": round(da, 5), "root_max_deviation": round(root_dev, 6),
              "non_unit_scale_keys": nonuni, "constraints_muted_for_export": True}
    ok = dp <= TOL_CM and da <= TOL_DEG and len(keyed) == len(arm.pose.bones) and root_dev < 1e-5 and nonuni == 0
    return baked, report, ok


def _fcurves(action):
    """F-curves of an action (layered actions in Blender 4.4+ keep them in channelbags)."""
    out = []
    try:
        for layer in action.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    out.extend(cb.fcurves)
    except AttributeError:
        pass
    if not out and hasattr(action, "fcurves"):
        out = list(action.fcurves)
    return out


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

    def arg(k, d=None):
        return argv[argv.index(k) + 1] if k in argv else d

    action = arg("--action", "CellarBat_R01_FlapTest_Ctl")
    start = int(arg("--start")) if arg("--start") is not None else None
    end = int(arg("--end")) if arg("--end") is not None else None
    baked, rep, ok = bake(action, arg("--name"), start, end)
    print("BAKE", json.dumps(rep))
    fbx = arg("--fbx")
    if fbx:
        import export_cellar_bat
        export_cellar_bat.export_clip(bpy.data.objects[ARM_NAME], bpy.data.objects[export_cellar_bat.MESH_NAME],
                                      baked, fbx)
        print("EXPORTED", fbx)
    if not ok:
        print("CELLAR_BAT_FAIL bake mismatch %s" % json.dumps(rep))
        sys.exit(1)
    print("CELLAR_BAT_OK")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        print("CELLAR_BAT_FAIL exception")
        sys.exit(1)
