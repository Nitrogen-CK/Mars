"""Cellar Bat R01 - Phase 4 export: bind mesh + LODs re-exported from the final scene, one FBX per clip, the
expected landmarks for the round trip, and export/CellarBat_R01_Manifest.json.

Uses the recipe of export_cellar_bat.py unchanged (COMMON / BIND / CLIP args, `Armature` rename, only the export
armature + one mesh selected). Every clip FBX = export armature + LOD0 mesh + exactly ONE action (the baked
`<Clip>` action written by animate_cellar_bat.py), frames 0..N, 30 fps.

Run (after animate_cellar_bat.py saved the scene):
  blender -b --factory-startup source/CellarBat_R01.blend --python scripts/export_anims_cellar_bat.py
Writes export/CellarBat_R01_Mars_SK.fbx, _LOD1_, _LOD2_, export/anims/CellarBat_R01_<Clip>_Mars_ANIM.fbx (18),
export/anims/expected_anims.json, export/CellarBat_R01_Manifest.json. Never saves the .blend.
Prints CELLAR_BAT_OK / CELLAR_BAT_FAIL <reason>.
"""
import json
import os
import sys
import traceback

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import bat_rig  # noqa: E402
import export_cellar_bat as E  # noqa: E402

ROOT = E.ROOT
OUT = E.OUT
ANIMS = os.path.join(OUT, "anims")
UE_ROOT = "/Game/ArtCandidates/CellarBat/R01"
ADDITIVE_REF = {"clip": "Hover", "frame": 0}
# bone HEADS (FBX stores no bone tails, leaf lengths change on import); the wing tips are the mesh extremes
CLIP_LANDMARKS = ("finger_01b_l", "finger_01b_r", "finger_03b_l", "finger_03b_r", "wrist_l", "wrist_r", "head",
                  "jaw", "foot_l", "foot_r", "ear_tip_l")
FLAP_KEYS = (0, 4, 8, 12, 15)


def clip_fbx_name(clip):
    return "CellarBat_R01_%s_Mars_ANIM.fbx" % clip


def export_clip_range(arm, mesh, act, start, end, path):
    """One action over an explicit range (a one-frame pose exports frames 0..0)."""
    sc = bpy.context.scene
    arm.data.pose_position = "POSE"
    arm.animation_data.action = act
    if arm.animation_data.action_slot is None and len(act.slots):
        arm.animation_data.action_slot = act.slots[0]
    sc.frame_start, sc.frame_end = int(start), int(end)
    sc.render.fps, sc.render.fps_base = 30, 1.0
    old = arm.name
    try:
        arm.name = "Armature"
        E.select_only([arm, mesh])
        bpy.ops.export_scene.fbx(filepath=path, **E.CLIP)
    finally:
        arm.name = old


def main():
    fails = []
    os.makedirs(ANIMS, exist_ok=True)
    sc = bpy.context.scene
    arm = bpy.data.objects[E.ARM_NAME]
    body = bpy.data.objects[E.MESH_NAME]
    for n, _f in E.LODS.values():
        bpy.data.objects[n].hide_set(False)
    clips = json.load(open(os.path.join(ANIMS, "clips.json")))
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = argv[argv.index("--clips") + 1].split(",") if "--clips" in argv else None
    if only:
        clips = {n: clips[n] for n in only}
    ctrl = bpy.data.objects[bat_rig.CTRL_NAME]
    bat_rig.use_action(ctrl, None, 0)
    bat_rig.reset(ctrl)

    # ---- bind + LODs at rest (constraints muted: the export bones alone)
    bat_rig.mute(arm, True)
    arm.animation_data_create()
    arm.animation_data.action = None
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    lods = {}
    for lod, (mname, fname) in (() if only else E.LODS.items()):
        p = os.path.join(OUT, fname)
        E.export_skeletal(arm, bpy.data.objects[mname], p)
        lods[str(lod)] = dict(E.mesh_facts(bpy.data.objects[mname]), file=fname, bytes=os.path.getsize(p),
                              header=E.fbx_header(p))
        print("EXPORTED LOD%d %s" % (lod, p))
    bones = [{"name": b.name, "parent": b.parent.name if b.parent else None} for b in arm.data.bones]

    # ---- clips
    arm.data.pose_position = "POSE"
    expected = {"landmark_bones": list(CLIP_LANDMARKS), "frame_map": "UE cm (x, -y, z)", "clips": {}}
    out_clips = {}
    for name, info in clips.items():
        act = bpy.data.actions.get(info["export_action"])
        if act is None:
            fails.append("missing action %s" % info["export_action"])
            continue
        start, end = info["frames"]
        arm.animation_data.action = act
        if arm.animation_data.action_slot is None and len(act.slots):
            arm.animation_data.action_slot = act.slots[0]
        lm = {}
        for f in range(start, end + 1):
            sc.frame_set(f)
            bpy.context.view_layer.update()
            k = {n: (np.array(arm.matrix_world @ arm.pose.bones[n].head) * E.TO_UE).round(4).tolist()
                 for n in CLIP_LANDMARKS}
            r = arm.pose.bones["root"].matrix
            k["root_dev"] = round(float(r.translation.length + r.to_quaternion().angle), 8)
            k["mesh"] = E.mesh_extremes(body)      # every frame: the skinned wing-tip / top / bottom extremes
            lm[str(f)] = k
        sc.frame_set(start)
        path = os.path.join(ANIMS, clip_fbx_name(name))
        export_clip_range(arm, body, act, start, end, path)
        expected["clips"][name] = {"file": os.path.basename(path), "first": start, "last": end,
                                   "samples": end - start + 1, "loop": info["loop"], "landmarks": lm}
        out_clips[name] = {"fps": info["fps"], "frames": info["frames"], "samples": info["samples"],
                           "loop": info["loop"], "markers": info["markers"],
                           "source_control_action": info["control_action"], "export_action": info["export_action"],
                           "file": "export/anims/" + os.path.basename(path), "bytes": os.path.getsize(path),
                           "unreal_path": "%s/Animation/CellarBat_R01_%s_Mars_ANIM" % (UE_ROOT, name),
                           "note": info.get("note", "")}
        if name in ("BankLeft", "BankRight"):
            out_clips[name]["additive"] = {"type": "one held full pose (2 identical samples, frames 0..1), set "
                                                   "additive in Unreal", "reference_pose": ADDITIVE_REF}
            out_clips[name]["csv_deviation"] = "CSV says 0-0; padded to 2 identical samples because the Unreal FBX " \
                                               "importer rejects a zero-length take"
        print("EXPORTED clip %-15s %s" % (name, path))
    arm.animation_data.action = None
    bat_rig.mute(arm, False)
    if only:   # merge the re-exported clips into the existing expected landmarks and manifest; nothing else changes
        ep = os.path.join(ANIMS, "expected_anims.json")
        old = json.load(open(ep))
        old["clips"].update(expected["clips"])
        with open(ep, "w") as fh:
            json.dump(old, fh, indent=1)
        mpath = os.path.join(OUT, "CellarBat_R01_Manifest.json")
        man = json.load(open(mpath))
        man["clips"].update(out_clips)
        man["clip_contract"]["additive_note"] = (
            "BankLeft/BankRight are full poses authored as Hover frame 0 + the bank intent, exported as 2 identical "
            "samples (frames 0..1; the Unreal FBX importer rejects a zero-length take); set them additive against "
            "Hover frame 0 in Unreal")
        with open(mpath, "w") as fh:
            json.dump(man, fh, indent=1)
        print("MERGED", sorted(out_clips), "into", ep, "and", mpath)
        if fails or len(out_clips) != len(only):
            print("CELLAR_BAT_FAIL " + "; ".join(fails))
            sys.exit(1)
        print("CELLAR_BAT_OK")
        return
    with open(os.path.join(ANIMS, "expected_anims.json"), "w") as fh:
        json.dump(expected, fh, indent=1)

    fbx_ver = None
    try:
        import addon_utils
        for m in addon_utils.modules():
            if m.__name__ in ("io_scene_fbx", "bl_ext.system.io_scene_fbx"):
                fbx_ver = ".".join(str(x) for x in m.bl_info.get("version", ()))
    except Exception as e:  # noqa: BLE001
        fbx_ver = "unknown (%s)" % e
    meas = {}
    mp = os.path.join(ROOT, "review", "phase3b", "measurements.json")
    if os.path.exists(mp):
        mm = json.load(open(mp)).get("measure", {})
        meas = {k: v for k, v in mm.items() if isinstance(v, (int, float))}
    manifest = {
        "asset": "CellarBat_R01",
        "generated_by": "scripts/export_anims_cellar_bat.py (Phase 4)",
        "versions": {"blender": bpy.app.version_string, "fbx_exporter_addon": fbx_ver,
                     "fbx_file_version": lods["0"]["header"].get("file_version"),
                     "fbx_note": "binary FBX written by the Blender exporter (file version above), not Autodesk FBX "
                                 "2020.2; proven by the Blender round trip and the Phase 2 Unreal import"},
        "units_axes": {"blender_scene": {"system": sc.unit_settings.system,
                                         "scale_length": sc.unit_settings.scale_length, "note": "1 BU = 1 cm"},
                       "exporter_args_common": E.jsonable(E.COMMON), "bind_args": E.jsonable(E.BIND),
                       "clip_args": E.jsonable(E.CLIP),
                       "frame_map": "Blender (x, y, z) cm -> Unreal (x, -y, z) cm; +X forward, +Z up; bat left "
                                    "(*_l) = Blender +Y = Unreal -Y",
                       "armature_export_name": "Armature (renamed only while exporting; Unreal drops the node)"},
        "dimensions_cm": dict(meas, span_target=75.0),
        "lods": {k: {kk: v[kk] for kk in ("file", "tris", "verts", "slots", "bounds_ue_cm", "span_cm", "bytes")}
                 for k, v in lods.items()},
        "bone_count": len(bones),
        "bones": bones,
        "material_slots": lods["0"]["slots"],
        "vertex_colour": "corner attribute Col (sRGB bytes): RGB albedo, A cavity/occlusion",
        "uv": "UV0 (lightmap-packed, non-overlapping)",
        "morph_targets": [],
        "clip_contract": {
            "fps": 30,
            "root": "root bone identity on every sample of every clip (asserted by the bake and the round trip); "
                    "runtime owns travel, perch alignment and falling",
            "loop_convention": "loops export N+1 samples on frames 0..N; frame N duplicates frame 0 in pose and slope "
                               "(Hover/FlyForward 16 samples, Glide/Stun 31, RoostIdle 61); Unreal imports N+1 keys, "
                               "length N/30 s, and must loop without holding the seam",
            "file_content": "export armature + LOD0 mesh + exactly one action per clip FBX (bake_anim_use_all_actions"
                            "=False, bake_anim_use_nla_strips=False)",
            "additive_reference_pose": ADDITIVE_REF,
            "additive_note": "BankLeft/BankRight are full poses authored as Hover frame 0 + the bank intent, exported "
                             "as 2 identical samples (frames 0..1; the Unreal FBX importer rejects a zero-length take); "
                             "set them additive against Hover frame 0 in Unreal",
            "markers": "presentation only (frame numbers in each clip's `markers`); gameplay owns damage/state"},
        "clips": out_clips,
        "export_paths": {"bind": "export/" + E.LODS[0][1], "lod1": "export/" + E.LODS[1][1],
                         "lod2": "export/" + E.LODS[2][1], "anims_dir": "export/anims/"},
        "unreal_paths": {"skeletal_mesh": UE_ROOT + "/Meshes/CellarBat_R01_Mars_SK",
                         "skeleton": UE_ROOT + "/Meshes/CellarBat_R01_Mars_SKEL",
                         "physics_asset": UE_ROOT + "/Meshes/CellarBat_R01_Mars_PHYS",
                         "animations": UE_ROOT + "/Animation/CellarBat_R01_<Clip>_Mars_ANIM",
                         "material_instances": {s: UE_ROOT + "/Materials/CellarBat_R01_%s_Mars_MI" % s
                                                for s in lods["0"]["slots"]}},
    }
    mpath = os.path.join(OUT, "CellarBat_R01_Manifest.json")
    with open(mpath, "w") as fh:
        json.dump(manifest, fh, indent=1)
    print("MANIFEST", mpath)
    if len(bones) != 42:
        fails.append("bones %d" % len(bones))
    if len(out_clips) != 18:
        fails.append("clips %d" % len(out_clips))
    if fails:
        print("CELLAR_BAT_FAIL " + "; ".join(fails))
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
