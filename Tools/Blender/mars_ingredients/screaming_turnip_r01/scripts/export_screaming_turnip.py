"""Screaming Turnip R01 - Phase B / B3 export (the Cellar Bat recipe; Phase A proved it on this asset).

Phase B3 recipe change (DEV-13): the bind SK and every clip export with use_triangles=False. With use_triangles=True the
exporter writes the mesh from a temporary triangulated copy whose Key is not animated, so every baked shape-key value is
0.0 (proved in Phase B2b: review/phaseB2b/shapekey_roundtrip_verbatim.json vs shapekey_roundtrip.json). The body mesh
is all triangles already (asserted before every skeletal export), so the written polygons are unchanged. Statics keep
the Phase B recipe verbatim. Each clip FBX carries the armature action `<Clip>` and the Key action `<Clip>_Key`
(shape-key channels `Inhale` / `Scream`, baked per frame as FBX BlendShapeChannel DeformPercent curves).

Opens source/ScreamingTurnip_R01.blend (built by build_screaming_turnip.py, clips by animate_screaming_turnip.py) and
writes (1 BU = 1 cm, scale_length 0.01):
  export/ScreamingTurnip_R01_Mars_SK.fbx                      bind mesh + 17-bone armature, rest pose, no animation
  export/ScreamingTurnip_R01_Collision_Mars_SM.fbx            neutral bulb hull (origin == turnip root)
  export/TurnipBed_R01_Mars_SM.fbx, TurnipBedEmpty_R01_Mars_SM.fbx   origin = soil-line centre
  export/validation/Cube10_Mars_SM.fbx                        10 cm cube (unit check)
  export/anims/ScreamingTurnip_R01_<Clip>_Mars_ANIM.fbx       armature + mesh + exactly ONE action, range = clip range
  export/expected.json          bind / statics / cube facts the round trip must read back (Unreal cm (x, -y, z))
  export/anims/expected_anims.json   per clip, EVERY frame: landmark bone heads, skinned extremes (6 scalars),
                                     root deviation; scale keys at each clip's peak frame
  export/ScreamingTurnip_R01_Manifest.json   asset manifest (bat shape)
  export/export_settings.json   every exporter argument, versions, FBX headers read back from the files
The armature object is renamed `Armature` for each skeletal export (Unreal drops that node) and renamed back; the
beds' scene location (soil line z) is zeroed for export and restored. Never saves the .blend.

Phase B4 (size x3.0): reads review/phaseB4/{measurements,anim_report}.json; the manifest carries `scale_factor`, the
B3 -> B4 numbers the Unreal side must re-assert (`phase_c_readback`, for C3) and a `gameplay_numbers` block (the
Script constants to adopt in Phase H: grip points, hull centre, planted offset, bed heights, release point, HeldOffset,
pickup probe radius), computed from the export's own facts and the B3 manifest (review/phaseB4/b3_baseline/).

Run (from the screaming_turnip_r01 folder):
  "$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/export_screaming_turnip.py
Prints TURNIP_OK or TURNIP_FAIL <reason>.
"""
import json
import math
import os
import struct
import sys
import traceback

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import build_screaming_turnip as BT  # noqa: E402

ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "export")
VAL = os.path.join(OUT, "validation")
ANIMS = os.path.join(OUT, "anims")
UE_ROOT = "/Game/ArtCandidates/ScreamingTurnip/R01"
SK_FBX = "ScreamingTurnip_R01_Mars_SK.fbx"
TO_UE = np.array([1.0, -1.0, 1.0])
LANDMARK_BONES = ["body", "jaw", "cheek_l", "cheek_r", "crown", "taproot"] + ["leaf_%02d_b" % i for i in range(1, 6)]
SCALE_BONES = ("body", "cheek_l", "cheek_r", "crown", "taproot")

COMMON = dict(use_selection=True, apply_unit_scale=True, apply_scale_options="FBX_SCALE_NONE", global_scale=1.0,
              axis_forward="-Z", axis_up="Y", use_mesh_modifiers=False, mesh_smooth_type="FACE", use_triangles=True,
              use_tspace=False, add_leaf_bones=False, path_mode="STRIP", colors_type="SRGB",
              use_custom_props=False, bake_space_transform=False)
STATIC = dict(COMMON, object_types={"MESH"}, bake_anim=False)
SKELETAL = dict(COMMON, object_types={"ARMATURE", "MESH"}, primary_bone_axis="Y", secondary_bone_axis="X",
                use_armature_deform_only=True, armature_nodetype="NULL")
# B3 DEV-13: skeletal exports carry shape keys -> use_triangles=False (mesh asserted all-triangles first)
SKELETAL = dict(SKELETAL, use_triangles=False)
BIND = dict(SKELETAL, bake_anim=False)
CLIP = dict(SKELETAL, bake_anim=True, bake_anim_use_all_bones=True, bake_anim_use_nla_strips=False,
            bake_anim_use_all_actions=False, bake_anim_force_startend_keying=True, bake_anim_step=1.0,
            bake_anim_simplify_factor=0.0)


def fbx_header(path):
    with open(path, "rb") as fh:
        data = fh.read()
    out = {"magic": data[:20].decode("ascii", "replace").rstrip("\x00 ")}
    if data.startswith(b"Kaydara FBX Binary"):
        out["file_version"] = struct.unpack("<I", data[23:27])[0]
    for key in (b"FBXHeaderVersion", b"FBXVersion"):
        i = data.find(key)
        if i >= 0:
            j = i + len(key)
            if data[j:j + 1] == b"I":
                out[key.decode()] = struct.unpack("<i", data[j + 1:j + 5])[0]
    i = data.find(b"Creator")
    if i >= 0 and data[i + 7:i + 8] == b"S":
        n = struct.unpack("<I", data[i + 8:i + 12])[0]
        out["Creator"] = data[i + 12:i + 12 + n].decode("utf-8", "replace")
    return out


def select_only(objs):
    for o in bpy.context.view_layer.objects:
        o.select_set(o in objs)
    bpy.context.view_layer.objects.active = objs[0]


def jsonable(d):
    return {k: (sorted(v) if isinstance(v, set) else v) for k, v in d.items()}


def world_verts(obj, evaluated=False):
    if evaluated:
        dg = bpy.context.evaluated_depsgraph_get()
        ev = obj.evaluated_get(dg)
        me = ev.to_mesh()
    else:
        me = obj.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    if evaluated:
        ev.to_mesh_clear()
    m = np.array(obj.matrix_world)
    return (co.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]) * TO_UE


def mesh_facts(ob):
    me = ob.data
    me.calc_loop_triangles()
    ue = world_verts(ob)
    ca = me.color_attributes.get("Col")
    return {"object": ob.name, "tris": len(me.loop_triangles), "verts": len(me.vertices),
            "slots": [m.name for m in me.materials],
            "bounds_ue_cm": {"min": ue.min(0).round(4).tolist(), "max": ue.max(0).round(4).tolist()},
            "color_attribute": None if ca is None else {"name": ca.name, "type": ca.data_type, "domain": ca.domain}}


def extremes(body):
    v = world_verts(body, evaluated=True)
    return [round(float(x), 4) for x in list(v.min(0)) + list(v.max(0))]   # min x y z, max x y z (UE cm)


def use_action(arm, act):
    arm.animation_data.action = act
    if act is not None and getattr(arm.animation_data, "action_slot", None) is None and len(getattr(act, "slots", [])):
        arm.animation_data.action_slot = act.slots[0]


SK_NAMES = ("Inhale", "Scream")
PEAK_RULES = {"ROOT_Inhale": {"Inhale": "last"}, "ROOT_Scream": {"Scream": (3, 18)}}


def use_key_action(body, act):
    key = body.data.shape_keys
    ad = key.animation_data or key.animation_data_create()
    ad.action = act
    if act is not None and getattr(ad, "action_slot", None) is None and len(getattr(act, "slots", [])):
        ad.action_slot = act.slots[0]
    if act is None:
        for n in SK_NAMES:
            key.key_blocks[n].value = 0.0


def assert_all_tris(body):
    bad = sum(1 for p in body.data.polygons if len(p.vertices) != 3)
    if bad:
        raise RuntimeError("body mesh has %d non-triangle polygons: use_triangles=False would change them" % bad)


def sk_now(body):
    kb = body.data.shape_keys.key_blocks
    return {n: round(float(kb[n].value), 6) for n in SK_NAMES}


def blender_verts(body):
    """Evaluated (skinned + morphed) body vertices, Blender world cm (the round trip compares the same frame)."""
    return world_verts(body, evaluated=True) * TO_UE


def gameplay_numbers(S, sockets, hull, expected, anim_rep, meas):
    """B4: the Script constants (Script/Items/Mars_Item_ScreamingTurnip.as, Mars_ScreamingTurnipBed_EntityScript.as)
    re-derived at the new size. Unreal cm (x, -y, z), root = the taproot tip."""
    b3 = json.load(open(os.path.join(ROOT, "review", "phaseB4", "b3_baseline", "ScreamingTurnip_R01_Manifest.json")))
    hv = np.array([tuple(v.co) for v in bpy.data.objects[BT.COLL_NAME].data.vertices]) * TO_UE
    centre = 0.5 * (hv.min(0) + hv.max(0))
    radius = float(np.linalg.norm(hv - centre, axis=1).max())
    c3 = np.array(b3["collision"]["centre_offset_from_root_cm"]) * TO_UE
    old_root = np.array([14.0, 0.0, -12.0])

    def yaw180(v):
        return np.array([-v[0], -v[1], v[2]])

    held_hull = old_root + yaw180(c3)                      # where the B3 hull centre sat in the hand frame
    new_root = held_hull - yaw180(centre)
    bed = expected["statics"][BT.BED_NAME]["bounds_ue_cm"]
    margin = 5.0
    r = lambda v: [round(float(x), 3) for x in v]
    return {
        "frame": "Unreal cm (x, -y, z) from the skeletal mesh root (the taproot tip); the item's proxy pivot == that root",
        "scale_factor": S,
        "k_GripLocation_R": r(sockets["Grip_L"]["root_relative_ue_cm"]),
        "k_GripLocation_L": r(sockets["Grip_R"]["root_relative_ue_cm"]),
        "grip_note": "R takes the root's -Y flank landmark (its Grip_L), L the +Y one, as now (k_GripRotation yaw 180 "
                     "unchanged); was (0, -/+3.94, 4.0). The grips are now %.2f cm apart (was %.2f): check the "
                     "Cradle glove layout spreads that wide" % (
                         abs(sockets["Grip_L"]["root_relative_ue_cm"][1] - sockets["Grip_R"]["root_relative_ue_cm"][1]),
                         abs(b3["sockets"]["Grip_L"]["root_relative_ue_cm"][1] - b3["sockets"]["Grip_R"]["root_relative_ue_cm"][1])),
        "hull_centre_offset_from_root": r(centre),
        "hull_centre_note": "bounds centre of the collision hull; x is %.3f (not 0) because the hull's +X half is widened "
                            "over the lip crest (B2b); comment in constants_screaming_turnip_assets says 6.75 -> %.2f" % (
                                centre[0], centre[2]),
        "hull_extents": {k: hull["extents_cm"][k] for k in ("h_z", "w_y", "d_x")},
        "k_PlantedOffset": [0.0, 0.0, round(-float(sockets["SoilLine"]["root_relative_ue_cm"][2]), 3)],
        "bed": {"outer_size_cm": [round(bed["max"][0] - bed["min"][0], 3), round(bed["max"][1] - bed["min"][1], 3),
                                  round(bed["max"][2] - bed["min"][2], 3)],
                "top_z_above_soil_line": round(bed["max"][2], 4), "bottom_z": round(bed["min"][2], 4),
                "pivot": "soil-line centre (unchanged)"},
        "k_ReleasePointOffset_suggestion": [0.0, 0.0, 20.0 * S],
        "release_note": "bed centre + %g cm (was + 20): the hop starts with the %.1f cm root's base clear of the %.2f cm "
                        "bed top. ReleaseLaunch / ReleaseSpinDeg / the bed probe (30, 30, 20) half extents are not "
                        "re-derived here: the probe box is now smaller than the %.0f cm bed (judge in Phase H)" % (
                            20.0 * S, meas["overall_height_tip_to_highest_leaf_cm"], bed["max"][2], bed["max"][0] * 2),
        "HeldOffset_location": r(new_root),
        "HeldOffset_rotation": [0.0, 180.0, 0.0],
        "held_note": "B3 HeldOffset (14, 0, -12) yaw 180 put the hull centre at %s in the hand frame (root + yaw180(%s)); "
                     "the B4 root goes at %s so the hull centre stays there. With the brief's x-free centre (0, 0, %.2f) "
                     "the value is (14, 0, %.2f)" % (r(held_hull), r(c3), r(new_root), centre[2],
                                                      -12.0 + float(c3[2]) - float(centre[2])),
        "hull_bounding_radius": round(radius, 3),
        "PickupProbeRadius_suggestion": float(math.ceil(radius + margin)),
        "pickup_note": "hull bounding radius from its centre %.2f + %g cm margin, rounded up (B3 radius would be %.2f). "
                       "Only used when the item has no Mesh (Mars_WorldItem_Utils.as:391 / :406): the proxy hull's "
                       "bounds drive the probe otherwise" % (radius, margin, radius / S),
    }


def main():
    fails = []
    for d in (OUT, VAL, ANIMS):
        os.makedirs(d, exist_ok=True)
    sc = bpy.context.scene
    if abs(sc.unit_settings.scale_length - 0.01) > 1e-9:
        fails.append("scale_length %s" % sc.unit_settings.scale_length)
    arm = bpy.data.objects[BT.ARM_NAME]
    body = bpy.data.objects[BT.MESH_NAME]
    arm.animation_data_create()
    files = {}
    clips = json.load(open(os.path.join(ANIMS, "clips.json")))
    meas = json.load(open(os.path.join(ROOT, "review", "phaseB4", "measurements.json")))      # B4 builder output
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    rev = argv[argv.index("--review") + 1] if "--review" in argv else "phaseB4"     # Phase I: -- --review phaseI
    anim_rep = json.load(open(os.path.join(ROOT, "review", rev, "anim_report.json")))   # animate output (B4 default)
    S = float(meas["scale_factor"])
    if abs(BT.unit(arm) - S) > 1e-6:
        fails.append("blend unit %s != measurements scale %s" % (BT.unit(arm), S))
    assert_all_tris(body)

    # ---- cube
    bpy.ops.mesh.primitive_cube_add(size=10.0, location=(0, 0, 0))
    cube = bpy.context.active_object
    cube.name = cube.data.name = "Cube10_Mars_SM"
    p = os.path.join(VAL, "Cube10_Mars_SM.fbx")
    select_only([cube])
    bpy.ops.export_scene.fbx(filepath=p, **STATIC)
    files["cube"] = p
    bpy.data.objects.remove(cube, do_unlink=True)

    # ---- statics
    expected = {"bones": [], "statics": {}, "cube": {"file": "validation/Cube10_Mars_SM.fbx",
                                                     "bounds_ue_cm": {"min": [-5.0] * 3, "max": [5.0] * 3}}}
    for n in (BT.BED_NAME, BT.BED_EMPTY_NAME, BT.COLL_NAME):
        ob = bpy.data.objects[n]
        old = ob.location.copy()
        hid = ob.hide_get()
        ob.hide_set(False)
        try:
            ob.location = (0, 0, 0)
            bpy.context.view_layer.update()
            p = os.path.join(OUT, "%s_Mars_SM.fbx" % n)
            select_only([ob])
            bpy.ops.export_scene.fbx(filepath=p, **STATIC)
            expected["statics"][n] = dict(mesh_facts(ob), file=os.path.basename(p), scene_location_restored=list(old))
            files[n] = p
        finally:
            ob.location = old
            ob.hide_set(hid)

    # ---- bind
    use_action(arm, None)
    use_key_action(body, None)
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    for b in arm.data.bones:
        expected["bones"].append({"name": b.name, "parent": b.parent.name if b.parent else None,
                                  "head_ue_cm": (np.array(b.head_local) * TO_UE).round(4).tolist(),
                                  "length_cm": round(b.length, 5),
                                  "rest_quat_blender": [round(x, 6) for x in b.matrix_local.to_quaternion()]})
    expected["sk"] = dict(mesh_facts(body), file=SK_FBX,
                          shape_keys=[kb.name for kb in body.data.shape_keys.key_blocks])
    old = arm.name
    try:
        arm.name = "Armature"
        select_only([arm, body])
        p = os.path.join(OUT, SK_FBX)
        bpy.ops.export_scene.fbx(filepath=p, **BIND)
        files["sk"] = p
    finally:
        arm.name = old
    arm.data.pose_position = "POSE"

    # ---- clips
    exp_anims = {"landmark_bones": LANDMARK_BONES, "frame_map": "UE cm (x, -y, z)",
                 "extremes": "skinned mesh [min x, min y, min z, max x, max y, max z] UE cm", "clips": {}}
    man_clips = {}
    # Phase I: crown + HarvestGrip socket tracks per frame of the SRC clips (UE cm, root-relative). A socket rides its bone
    # rigidly: world = crown pose matrix @ crown rest matrix^-1 @ rest socket (the crown's net scale is 1: it
    # counter-scales the body).
    hg_rest = {n: Vector(meas["landmarks"]["sockets_blender_cm"][n]) for n in ("HarvestGrip_R", "HarvestGrip_L")}
    crown_rest_inv = arm.data.bones["crown"].matrix_local.inverted()
    travel = {"frame_map": "UE cm (x, -y, z), root-relative (the taproot tip); 30 fps; sockets ride the crown",
              "clips": {}}
    # Phase J Part 1b: the bulb-top "neck" gauge. Dimple = the bulb vertex on the axis carrying crown weight; top ring =
    # the other bulb vertices carrying crown weight. Per SRC_Tug frame, their skinned displacement from f0 (UE cm).
    cg = body.vertex_groups["crown"].index
    bulb_crown = [v.index for v in body.data.vertices
                  if any(g.group == cg and g.weight > 0 for g in v.groups) and
                  not any(body.vertex_groups[g.group].name.startswith("leaf_") for g in v.groups)]
    dimple = [i for i in bulb_crown if abs(body.data.vertices[i].co.x) < 1e-4 and abs(body.data.vertices[i].co.y) < 1e-4]
    ring = [i for i in bulb_crown if i not in dimple]
    neck = {"frame_map": "UE cm (x, -y, z), root-relative; displacement from SRC_Tug f0 (== SRC_Grip f6)",
            "dimple_vertex": dimple, "top_ring_vertices": len(ring), "target": "dimple <= 25 % of the crown head's "
            "travel at SRC_Tug f15 (<= 9 cm x, <= 3 cm z); the top ring less", "frames": {}}
    for name, info in clips.items():
        act = bpy.data.actions.get(name)
        if act is None:
            fails.append("missing action %s" % name)
            continue
        start, end = info["frames"]
        if end - start < 1:
            fails.append("%s one-sample clip" % name)
        use_action(arm, act)
        kact = bpy.data.actions.get(info.get("export_key_action", name + "_Key"))
        if kact is None:
            fails.append("missing Key action for %s" % name)
            continue
        use_key_action(body, kact)
        rule = PEAK_RULES.get(name, {})
        peak_frames = set()
        for nm, r in rule.items():
            peak_frames |= {end} if r == "last" else set(range(r[0], r[1] + 1))
        if name in ("ROOT_Inhale",):
            peak_frames |= {0}                      # also the zero frame, as a control
        if name in ("ROOT_QuietIdle", "SRC_Idle"):
            peak_frames |= {0}                      # zero clips: mesh == bones-only skin
        pverts = {}
        lm, peak = {}, {"frame": None, "dev": -1.0}
        for f in range(start, end + 1):
            sc.frame_set(f)
            k = {n: (np.array(arm.matrix_world @ arm.pose.bones[n].head) * TO_UE).round(4).tolist()
                 for n in LANDMARK_BONES}
            r = arm.pose.bones["root"].matrix
            k["root_dev"] = round(float(r.translation.length + r.to_quaternion().angle), 8)
            k["extremes"] = extremes(body)
            k["scale"] = {n: [round(x, 6) for x in arm.pose.bones[n].scale] for n in SCALE_BONES}
            k["sk"] = sk_now(body)
            if f in peak_frames:
                pverts[str(f)] = blender_verts(body).round(5).tolist()
            dev = max(abs(x - 1.0) for n in ("body", "cheek_l") for x in arm.pose.bones[n].scale)
            if dev > peak["dev"]:
                peak = {"frame": f, "dev": round(dev, 5)}
            lm[str(f)] = k
            if name == "SRC_Tug":
                ev = world_verts(body, evaluated=True)
                neck["frames"][str(f)] = {"crown": k["crown"], "dimple": ev[dimple[0]].round(4).tolist(),
                                          "ring": ev[ring].round(4).tolist()}
            if name.startswith("SRC_"):
                M = arm.matrix_world @ arm.pose.bones["crown"].matrix @ crown_rest_inv
                travel["clips"].setdefault(name, {})[str(f)] = dict(
                    {"crown": k["crown"]},
                    **{n: (np.array(M @ v) * TO_UE).round(4).tolist() for n, v in hg_rest.items()})
        sc.frame_start, sc.frame_end = int(start), int(end)
        sc.render.fps, sc.render.fps_base = 30, 1.0
        sc.frame_set(start)
        fname = "ScreamingTurnip_R01_%s_Mars_ANIM.fbx" % name
        p = os.path.join(ANIMS, fname)
        old = arm.name
        try:
            arm.name = "Armature"
            select_only([arm, body])
            bpy.ops.export_scene.fbx(filepath=p, **CLIP)
        finally:
            arm.name = old
        skp = {}
        for nm in SK_NAMES:
            vals = [lm[str(f)]["sk"][nm] for f in range(start, end + 1)]
            mx = max(vals)
            fr = [f for f, v in zip(range(start, end + 1), vals) if abs(v - mx) <= 1e-4] if mx > 1e-4 else []
            skp[nm] = {"max": round(mx, 6), "frames_at_max": [fr[0], fr[-1]] if fr else []}
        exp_anims["clips"][name] = {"file": fname, "first": start, "last": end, "samples": end - start + 1,
                                    "loop": info["loop"], "scale_peak_frame": peak["frame"], "landmarks": lm,
                                    "shape_key_peaks": skp, "peak_rule": {k: (v if v == "last" else list(v))
                                                                         for k, v in rule.items()},
                                    "peak_verts_blender_cm": pverts}
        ar = anim_rep["clips"].get(name, {})
        man_clips[name] = {"frames": [start, end], "samples": end - start + 1, "fps": 30,
                           "duration_s": round((end - start) / 30.0, 4), "loop": info["loop"],
                           "file": "export/anims/" + fname, "bytes": os.path.getsize(p),
                           "unreal_path": "%s/Animation/ScreamingTurnip_R01_%s_Mars_ANIM" % (UE_ROOT, name),
                           "note": info["note"], "chain": info.get("chain", {}),
                           "bounds_cm": ar.get("clip_bounds"), "intersections_max": ar.get("isect_max"),
                           "curves": list(SK_NAMES), "curve_peaks": skp,
                           "curve_note": {"ROOT_Inhale": "Inhale eases 0 -> 1, holds 1.0 from f30 to f36 (last 0.2 s)",
                                          "ROOT_Scream": "Inhale 1 -> 0 and Scream 0 -> 1 over f0..f3; Scream holds 1.0 f3..f18",
                                          "ROOT_Recover": "Scream 1 -> 0 over f0..f8 (jumps the 0.43-0.67 tooth/lip band "
                                                          "between f3 and f4); Inhale 0"}.get(
                               name, "both curves keyed 0.0 on every frame (a hard cut never inherits a stale value)")}
        if name in travel["clips"]:
            tr = travel["clips"][name]
            z = [tr[str(f)]["crown"][2] for f in range(start, end + 1)]
            hz = [tr[str(f)]["HarvestGrip_R"][2] for f in range(start, end + 1)]
            x = [tr[str(f)]["crown"][0] for f in range(start, end + 1)]           # Phase J: the crown leans in X too
            hx = [tr[str(f)]["HarvestGrip_R"][0] for f in range(start, end + 1)]
            man_clips[name]["crown_travel_ue_cm"] = {
                "crown_z_first_last": [z[0], z[-1]], "crown_z_min_max": [min(z), max(z)],
                "crown_dz": round(z[-1] - z[0], 4), "harvest_grip_z_first_last": [hz[0], hz[-1]],
                "crown_x_first_last": [x[0], x[-1]], "crown_dx": round(x[-1] - x[0], 4),
                "harvest_grip_x_first_last": [hx[0], hx[-1]],
                "per_frame": "review/%s/crown_travel.json" % rev}
        print("EXPORTED clip %-24s frames %d..%d  %d bytes" % (name, start, end, os.path.getsize(p)))
    use_action(arm, None)
    use_key_action(body, None)
    sc.frame_set(0)
    with open(os.path.join(ANIMS, "expected_anims.json"), "w") as fh:
        json.dump(exp_anims, fh, indent=1)
    with open(os.path.join(OUT, "expected.json"), "w") as fh:
        json.dump(expected, fh, indent=1)
    # Phase J: the walk-away stretch = the horizontal (UE XY) travel of the HarvestGrip sockets from SRC_Tug f0 (== SRC_Grip
    # f6, where the gloves grip) to SRC_Tug f15 (full strain); both sockets ride the crown, so they travel the same.
    stretch = None
    if "SRC_Tug" in travel["clips"]:
        tug = travel["clips"]["SRC_Tug"]
        last = str(max(int(k) for k in tug))
        hor = {n: round(float(np.hypot(*(np.array(tug[last][n][:2]) - np.array(tug["0"][n][:2])))), 4)
               for n in ("HarvestGrip_R", "HarvestGrip_L")}
        crown_h = round(float(np.hypot(*(np.array(tug[last]["crown"][:2]) - np.array(tug["0"]["crown"][:2])))), 4)
        # Phase K: the clip carries only the pose (crown head held at x 0); this is the clip's own socket travel, the
        # pitch swinging the socket offset (~2 cm). The stretch distance is the bed's runtime tuner (k_StretchTravelCm_default).
        stretch = {"frames": "SRC_Tug f0 (== SRC_Grip f6) -> f%s" % last, "socket_horizontal_travel_cm": hor,
                   "crown_horizontal_travel_cm": crown_h,
                   "crown_delta_xz_cm": [round(tug[last]["crown"][0] - tug["0"]["crown"][0], 4),
                                         round(tug[last]["crown"][2] - tug["0"]["crown"][2], 4)],
                   "clip_socket_travel_cm": round(float(np.mean(list(hor.values()))), 1)}
        travel["stretch"] = stretch
    if neck["frames"]:
        f0, fr = neck["frames"]["0"], {}
        for f, d in neck["frames"].items():
            cd = np.array(d["crown"]) - np.array(f0["crown"])
            dd = np.array(d["dimple"]) - np.array(f0["dimple"])
            rd = np.array(d["ring"]) - np.array(f0["ring"])
            rn = np.linalg.norm(rd, axis=1)
            fr[f] = {"crown_d": cd.round(3).tolist(), "dimple_d": dd.round(3).tolist(),
                     "dimple_pct_of_crown": round(100.0 * float(np.linalg.norm(dd)) / max(1e-9, float(np.linalg.norm(cd))), 1),
                     "ring_max_d": round(float(rn.max()), 3), "ring_max_abs_dx": round(float(np.abs(rd[:, 0]).max()), 3),
                     "ring_max_dz": round(float(rd[:, 2].max()), 3),
                     "ring_pct_of_crown": round(100.0 * float(rn.max()) / max(1e-9, float(np.linalg.norm(cd))), 1)}
        neck["frames"] = fr
        last = fr[str(max(int(k) for k in fr))]
        neck["f15"] = last
        # Phase K: the clip alone has ~2 cm of crown travel, so the percentage / ring-below-dimple rules are meaningless
        # here; the clip is gated on the absolute limits, and the stretched neck by animate's injected default
        # (review/<rev>/inject_146.2_20.json) and the --inject-stretch sweep (inject_summary.json).
        if abs(last["dimple_d"][0]) > 9.0 or last["dimple_d"][2] > 3.0:
            fails.append("neck: dimple %s (%.1f %%), ring max %.3f" % (last["dimple_d"], last["dimple_pct_of_crown"],
                                                                     last["ring_max_d"]))
        print("NECK f15", json.dumps(last))
    if "--review" in argv:
        if neck["frames"]:
            with open(os.path.join(ROOT, "review", rev, "neck.json"), "w") as fh:
                json.dump(neck, fh, indent=1)
        with open(os.path.join(ROOT, "review", rev, "crown_travel.json"), "w") as fh:
            json.dump(travel, fh, indent=1)

    # ---- manifest
    fbx_ver = None
    try:
        import addon_utils
        for m in addon_utils.modules():
            if m.__name__ in ("io_scene_fbx", "bl_ext.system.io_scene_fbx"):
                fbx_ver = ".".join(str(x) for x in m.bl_info.get("version", ()))
    except Exception as e:  # noqa: BLE001
        fbx_ver = "unknown (%s)" % e
    L = meas["landmarks"]
    sk_bl = L["sockets_blender_cm"]
    heads = {b["name"]: np.array(b["head_ue_cm"]) for b in expected["bones"]}

    def sock(name, bone, why):
        pos = np.array(sk_bl[name]) * TO_UE
        return {"bone": bone, "root_relative_ue_cm": pos.round(3).tolist(),
                "bone_relative_ue_cm": (pos - heads[bone]).round(3).tolist(), "rotation_ue_deg_pyr": [0.0, 0.0, 0.0],
                "note": why}

    sockets = {
        "Grip_L": sock("Grip_L", "root", "lower left flank (bulb surface at z %g); on root so it never inherits "
                                         "expressive body scale (spec section 3)" % (BT.P["GRIP_Z"] * S)),
        "Grip_R": sock("Grip_R", "root", "lower right flank; on root (spec section 3)"),
        "MouthCue": sock("MouthCue", "jaw", "seam centre on the +X face; follows the jaw for sound/VFX"),
        "SoilLine": sock("SoilLine", "body", "planted soil line; on body so the SRC clips' planted offset (body "
                                             "z %+.1f cm) carries it" % anim_rep["planted"]["body_offset_z_cm"]),
        "HarvestGrip_L": sock("HarvestGrip_L", "crown", "%g cm up the stem of leaf_02 (+Y, turnip left); on crown "
                                                        "so it rides the grip dip / tug stretch" % (0.8 * S)),
        "HarvestGrip_R": sock("HarvestGrip_R", "crown", "%g cm up the stem of leaf_04 (-Y); on crown" % (0.8 * S)),
    }
    hull = meas["collision_hull"]
    bones = [{"name": b["name"], "parent": b["parent"]} for b in expected["bones"]]
    manifest = {
        "asset": "ScreamingTurnip_R01",
        "generated_by": "scripts/export_screaming_turnip.py (Phase B4: the B3 asset x3.0 - mesh, keys, rig, clips, statics)",
        "scale_factor": S,
        "scale_note": "Phase B4 (maintainer ruling 2026-11-06: the bulb ~ the 30 cm sandbox Rock): every length = %g x the "
                      "Phase B3 16 cm asset (vertices, shape-key deltas, bone heads, pose translations, sockets, hull, beds); "
                      "rotations, scale keys, curve values, timings, topology (3188 tris) and the rig contract unchanged. "
                      "Proof: review/phaseB4/scale_check*.json (vertex-level vs the B3 blend, every report length)." % S,
        "versions": {"blender": bpy.app.version_string, "fbx_exporter_addon": fbx_ver,
                     "fbx_file_version": fbx_header(files["sk"]).get("file_version"),
                     "fbx_note": "binary FBX written by the Blender exporter; proven by the Blender round trip "
                                 "(validate_roundtrip.py), Unreal import is Phase C"},
        "units_axes": {"blender_scene": {"system": sc.unit_settings.system,
                                         "scale_length": sc.unit_settings.scale_length, "note": "1 BU = 1 cm"},
                       "exporter_args_common": jsonable(COMMON), "bind_args": jsonable(BIND),
                       "clip_args": jsonable(CLIP), "static_args": jsonable(STATIC),
                       "frame_map": "Blender (x, y, z) cm -> Unreal (x, -y, z) cm; mouth +X, +Z up; turnip left "
                                    "(*_l) = Blender +Y = Unreal -Y",
                       "armature_export_name": "Armature (renamed only while exporting; Unreal drops the node)"},
        "dimensions_cm": {"neutral_overall": meas["overall"], "bulb": meas["bulb"],
                          "overall_height_tip_to_highest_leaf": meas["overall_height_tip_to_highest_leaf_cm"],
                          "body_centre_offset_from_root": L["body_centre_bone_head"],
                          "global_clip_envelope": anim_rep["envelope"]},
        "bone_count": len(bones),
        "bones": bones,
        "rig_contract": "root identity on every sample of every clip; non-leaf bones have identity rest rotation; "
                        "body scale X == Z; jaw and crown rotate about Y only; the crown translates in X and Z (Phase J "
                        "cr_dx / cr_dz); crown/taproot counter-scale the body; "
                        "cheeks scale per axis + translate, never rotate (D-A1)",
        "material_slots": expected["sk"]["slots"],
        "mesh": {"tris": expected["sk"]["tris"], "verts": expected["sk"]["verts"],
                 "bounds_ue_cm": expected["sk"]["bounds_ue_cm"]},
        "vertex_colour": "corner attribute Col (BYTE_COLOR, sRGB bytes): RGB albedo, A cavity/occlusion baked in the "
                         "neutral pose (1 - 0.85 * cos-weighted occlusion, floor 0.15)",
        "uv": "none (vertex-colour materials)",
        "morph_targets": list(SK_NAMES),
        "morph_target_note": "relative shape keys on the body mesh, authored in posed space (delta = A_v^-1 (T - P0); "
                             "morphs apply before skinning in Blender and Unreal). Inhale: spherical lobes + 0.97 purse "
                             "(%s verts, max rest delta %s cm); Scream: elliptical rolled rim, gum band, pocket, seated "
                             "teeth (%s verts, %s cm). Each key is sculpted for its full bone pose (inhale / scream)." % (
                                 meas["shape_keys"][0].get("vertices_moved"), meas["shape_keys"][0].get("max_rest_delta_cm"),
                                 meas["shape_keys"][1].get("vertices_moved"), meas["shape_keys"][1].get("max_rest_delta_cm")),
        "clip_contract": {
            "fps": 30,
            "root": "root bone identity on every sample of every clip (asserted by animate and the round trip); "
                    "physics owns travel; no root motion",
            "loop_convention": "loops export N+1 samples on frames 0..N; frame N duplicates frame 0 in pose and slope; "
                               "Unreal imports N+1 keys, length N/30 s",
            "file_content": "export armature + mesh, exactly one armature action per clip FBX plus the mesh Key's "
                            "action (bake_anim_use_all_actions=False, bake_anim_use_nla_strips=False)",
            "curves": "every clip carries the morph curves Inhale and Scream on every sample (FBX BlendShapeChannel "
                      "DeformPercent = value x 100); clips that do not use a key carry 0.0 on every sample",
            "export_recipe_change": "DEV-13: skeletal exports use_triangles=False (with True the exporter bakes the "
                                    "shape-key curves from an unanimated copy: all 0.0). Mesh is all triangles (asserted).",
            "hard_cuts": "runtime plays clips with hard cuts (D-3); the vocal chain QuietIdle f0 -> Anticipate -> "
                         "Inhale -> Scream -> Recover -> RecoveryIdle is continuous (deltas 0, shape keys included); "
                         "after the recovery phase the presentation plays ROOT_AnticipateTired (starts == RecoveryIdle "
                         "f0, ends == Inhale f0) instead of ROOT_Anticipate; hard cuts: QuietIdle any frame -> "
                         "Anticipate f0 and RecoveryIdle any frame -> AnticipateTired f0",
            "chain_deltas": anim_rep["chain"],
            "hands": "the four HANDS_* rows of ANIMATION_MANIFEST.csv are not Blender clips (D-4: FPHands)"},
        "clips": man_clips,
        "sockets": sockets,
        "collision": {"object": BT.COLL_NAME, "tris": hull["tris"], "extents_cm": hull["extents_cm"],
                      "centre_offset_from_root_cm": hull["centre_offset_from_root_cm"],
                      "file": "export/%s_Mars_SM.fbx" % BT.COLL_NAME},
        "beds": {n: {"tris": expected["statics"][n]["tris"], "slots": expected["statics"][n]["slots"],
                     "bounds_ue_cm": expected["statics"][n]["bounds_ue_cm"], "origin": "soil-line centre",
                     "file": "export/%s_Mars_SM.fbx" % n} for n in (BT.BED_NAME, BT.BED_EMPTY_NAME)},
        "planted": anim_rep["planted"],
        "export_paths": {"bind": "export/" + SK_FBX, "collision": "export/%s_Mars_SM.fbx" % BT.COLL_NAME,
                         "bed": "export/%s_Mars_SM.fbx" % BT.BED_NAME,
                         "bed_empty": "export/%s_Mars_SM.fbx" % BT.BED_EMPTY_NAME,
                         "cube": "export/validation/Cube10_Mars_SM.fbx", "anims_dir": "export/anims/"},
        "unreal_paths": {"skeletal_mesh": UE_ROOT + "/Meshes/ScreamingTurnip_R01_Mars_SK",
                         "skeleton": UE_ROOT + "/Meshes/ScreamingTurnip_R01_Mars_SKEL",
                         "animations": UE_ROOT + "/Animation/ScreamingTurnip_R01_<Clip>_Mars_ANIM",
                         "animation_list": {n: c["unreal_path"] for n, c in man_clips.items()},
                         "new_in_b3": {"ROOT_AnticipateTired": man_clips.get("ROOT_AnticipateTired", {}).get("unreal_path")},
                         "material": UE_ROOT + "/Materials/ScreamingTurnip_R01_Mars_M",
                         "material_instances": {s: UE_ROOT + "/Materials/ScreamingTurnip_R01_%s_Mars_MI" % s
                                                for s in expected["sk"]["slots"]},
                         "statics": {n: UE_ROOT + "/Meshes/%s_Mars_SM" % n
                                     for n in (BT.BED_NAME, BT.BED_EMPTY_NAME, BT.COLL_NAME)}},
    }
    manifest["phase_c_readback"] = {
        "import": {"skeletal_mesh": "export/" + SK_FBX + " with import_morph_targets=True (the FBX carries BlendShape "
                                    "Inhale / Scream)",
                   "animations": "every export/anims/*.fbx onto the SK's skeleton; replace_existing=True (reimport of "
                                 "the 15 Phase B clips + the new ROOT_AnticipateTired)",
                   "statics": "the three statics, B4 size (hull x %.3f..%.3f, beds %g x %g cm) replace_existing=True; "
                              "regenerate the hull's convex element and the beds' box collision" % (
                                  hull["extents_cm"]["min"][0], hull["extents_cm"]["max"][0],
                                  expected["statics"][BT.BED_NAME]["bounds_ue_cm"]["max"][0] * 2,
                                  expected["statics"][BT.BED_NAME]["bounds_ue_cm"]["max"][1] * 2),
                   "skeleton": "B4 moves every bone head x%g: the reimport MUST update the skeleton reference pose "
                               "(update_skeleton_reference_pose=True on the stored import data, C2-2) or the SKEL keeps "
                               "the 16 cm pose; re-assert all six sockets at the B4 positions below (Monolith "
                               "set_socket_transform, as C2 did for MouthCue)" % S,
                   "bounds_extension": "envelope (%.3f x %.3f x %.3f) + %g cm margin (the C2 2 cm x %g)" % (
                       anim_rep["envelope"]["h_z"], anim_rep["envelope"]["w_y"], anim_rep["envelope"]["d_x"],
                       2.0 * S, S),
                   "normals": "FBXNIM_IMPORT_NORMALS as in Phase C; morph normals are NOT proven: Unreal may recompute "
                              "them for morph targets (bComputeWeightedNormals / morph normal import) - inspect the "
                              "scream rim shading in engine"},
        "assert_on_skeletal_mesh": {"morph_target_names": list(SK_NAMES), "tris": expected["sk"]["tris"],
                                    "bones": len(bones), "material_slots": expected["sk"]["slots"],
                                    "bind_bounds_ue_cm": expected["sk"]["bounds_ue_cm"],
                                    "bone_heads_ue_cm": {b["name"]: b["head_ue_cm"] for b in expected["bones"]},
                                    "envelope_cm": {k: anim_rep["envelope"][k] for k in ("min", "max", "h_z", "w_y", "d_x")},
                                    "sockets": {k: {"bone": v["bone"], "relative_ue_cm": v["bone_relative_ue_cm"]}
                                                for k, v in sockets.items()}},
        "assert_on_each_anim_sequence": {
            "get_sequence_info_curve_names": list(SK_NAMES),
            "num_keys": {n: c["samples"] for n, c in man_clips.items()},
            "curve_peaks": {n: c["curve_peaks"] for n, c in man_clips.items()},
            "explicit": {"ROOT_Inhale": "Inhale == 1.0 at the last key (f36) and f30..f36",
                         "ROOT_Scream": "Scream == 1.0 at f3..f18, Inhale == 0.0 from f3",
                         "ROOT_Recover": "Scream 1.0 at f0, 0.0 from f8",
                         "others": "Inhale and Scream curves present and 0.0 on every key"}},
        "assert_on_statics": {n: {"tris": expected["statics"][n]["tris"], "bounds_ue_cm": expected["statics"][n]["bounds_ue_cm"]}
                              for n in (BT.BED_NAME, BT.BED_EMPTY_NAME, BT.COLL_NAME)},
        "hull_sockets": {"Grip_L": sockets["Grip_L"]["root_relative_ue_cm"], "Grip_R": sockets["Grip_R"]["root_relative_ue_cm"]},
        "cuts": {r["from"] + " -> " + r["to"]: [r["max_head_delta_cm"], r["max_rot_delta_deg"]] for r in anim_rep["chain"]
                 if r["hard_cut"] or "AnticipateTired" in r["to"]},
        "cut_gate_note": "chain joints stay 0; the RecoveryIdle f0 -> AnticipateTired f0 gate stays <= 0.1 cm / 1 deg; "
                         "landmark tolerance per frame 0.02 cm (C2) is now 3x stricter relative to the asset",
        "playback": "single-node PlayAnimation of ROOT_Scream in the review room drives the morph (the gape opens "
                    "into the rolled rim); compare a capture to review/phaseB4/clips/ROOT_Scream_sheet.png",
        "not_proven_in_blender": ["Unreal morph-target import of these FBX files", "morph normals",
                                  "curve -> morph binding at runtime"],
    }
    manifest["gameplay_numbers"] = gameplay_numbers(S, sockets, hull, expected, anim_rep, meas)
    # Phase K: the stretch is a bed tuner (FMars_ScreamingTurnipBed_StretchSpec TravelCm / LiftCm, a runtime crown offset in
    # the ABP); the manifest records its default and the travel range the deformation audit holds
    # (review/<rev>/inject_summary.json, written by review/phaseK/inject_summary_k.py from the --inject-stretch runs).
    inj_p = os.path.join(ROOT, "review", rev, "inject_summary.json")
    if os.path.exists(inj_p):
        inj = json.load(open(inj_p))
        g = manifest["gameplay_numbers"]
        g["k_StretchTravelCm_default"] = inj["default"]["T_cm"]
        g["k_StretchLiftCm_default"] = inj["default"]["L_cm"]
        g["stretch_runtime_safe_travel_cm"] = inj["safe_travel_cm"]
        ff = inj["first_fail_above_default"]
        g["stretch_note"] = (
            "Phase K: the walk-away stretch is a runtime tuner, not clip content. The bed's Pull.Stretch (TravelCm, LiftCm; "
            "default %g / %g cm) drives the ABP's ModifyBone on `crown` (component space, Add): (-TravelCm * a, 0, LiftCm * a), "
            "a = the Control alpha while gripped, 1 - played alpha while SRC_Cancel plays. SRC_Tug / SRC_Cancel / SRC_Release "
            "carry only the pose (crown pitch, trailing leaves, bulb tilt; crown head held at x 0, clip socket travel %s cm "
            "from the pitch). The HarvestGrip sockets travel TravelCm + about 2 cm. Deformation audit with the offset "
            "injected (intersections 0, stem_gap <= 0, neck): safe for TravelCm %s cm with LiftCm ~ 0.137 x TravelCm; the "
            "first failure above the default is at %s cm (%s). Below %s cm the relative neck rule (ring below dimple) fails "
            "and at 0-5 cm the pitched crown lays the leaves on the bulb / lifts a stem base. Per run: review/%s/inject_summary.json" % (
                inj["default"]["T_cm"], inj["default"]["L_cm"], stretch["clip_socket_travel_cm"] if stretch else None,
                inj["safe_travel_cm"], ff["T_cm"] if ff else None, ff["first_fail"] if ff else None,
                inj["safe_travel_cm"][0], rev))
    elif stretch is not None:
        fails.append("no %s: run the --inject-stretch sweep and review/phaseK/inject_summary_k.py first" % inj_p)
    print("GAMEPLAY_NUMBERS", json.dumps(manifest["gameplay_numbers"]))
    with open(os.path.join(OUT, "ScreamingTurnip_R01_Manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=1)
    settings = {"blender_version": bpy.app.version_string, "fbx_addon_version": fbx_ver,
                "recipe_change_DEV_13": {
                    "what": "use_triangles=False for the bind SK and every clip (statics unchanged: use_triangles=True)",
                    "why": "with use_triangles=True the exporter writes the mesh from a temporary triangulated copy whose "
                           "Key is not animated: every baked shape-key value is 0.0 (BlendShapeChannel / DeformPercent "
                           "curves present but all zero); the mesh is already all triangles, so False writes the same "
                           "polygons and keeps the animated Key",
                    "proof": ["review/phaseB2b/shapekey_roundtrip.json (False: value 1.0 at the peak, verts 8e-6 cm)",
                              "review/phaseB2b/shapekey_roundtrip_verbatim.json (True: value 0.0, peak mesh off 3.53 cm)",
                              "export/anims/roundtrip_report.json (B3: every clip's curves read back)"],
                    "guard": "export asserts the body mesh is all triangles before every skeletal export"},
                "static_mesh_args": jsonable(STATIC), "bind_args": jsonable(BIND), "clip_args": jsonable(CLIP),
                "files": {os.path.relpath(p, ROOT): {"bytes": os.path.getsize(p), "header": fbx_header(p)}
                          for p in list(files.values()) +
                          [os.path.join(ANIMS, c["file"]) for c in exp_anims["clips"].values()]}}
    with open(os.path.join(OUT, "export_settings.json"), "w") as fh:
        json.dump(settings, fh, indent=1)
    for k, v in settings["files"].items():
        print("FILE %-62s %8d bytes  v%s" % (k, v["bytes"], v["header"].get("file_version")))
    print("SOCKETS", json.dumps(sockets))
    if len(expected["bones"]) != 17:
        fails.append("bones %d" % len(expected["bones"]))
    if len(man_clips) != 16:
        fails.append("clips %d" % len(man_clips))
    if fails:
        print("TURNIP_FAIL " + "; ".join(fails))
        sys.exit(1)
    print("TURNIP_OK")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        print("TURNIP_FAIL exception")
        sys.exit(1)
