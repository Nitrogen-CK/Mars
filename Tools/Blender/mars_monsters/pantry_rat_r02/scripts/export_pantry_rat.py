"""Pantry Rat R02 (copied from ../pantry_rat_r01/scripts/export_pantry_rat.py; R01 -> R02 names / paths, R02 review folders) - Phase 2 FBX export (the cellar bat recipe verbatim: COMMON / BIND / CLIP / STATIC exporter args,
armature renamed `Armature` while exporting, only the export armature + one mesh selected, one action per clip FBX).

Opens source/PantryRat_R02.blend (clips authored + baked by animate_pantry_rat.py) and writes:
  export/PantryRat_R02_Mars_SK.fbx                  LOD0 mesh + 26-bone armature, rest pose, no animation
  export/anims/PantryRat_R02_<Clip>_Mars_ANIM.fbx   34 x (armature + mesh + exactly ONE action), frames 0..N, 30 fps
  export/PantryRat_R02_Den_Mars_SM.fbx              den shell (slot Stone) + recess tunnel and back plane (slot Void),
                                                    den-local frame (origin floor centre of the den root, +X = out of the den)
  export/PantryRat_R02_DenEyePlate_Mars_SM.fbx      the paired-eye plate as ONE quad, UV 0..1 (U=0 at den +Y)
  export/PantryRat_R02_Cheese_Mars_SM.fbx           Monk's Rind wedge, slots Rind, Flesh (split by the authored colours)
  export/validation/Cube10_Mars_SM.fbx              10 cm cube (static recipe check)
  export/validation/export_settings.json            every exporter argument, Blender / FBX add-on versions, file headers
  export/validation/expected.json                   what the round trip must read back (UE cm (x, -y, z))
  export/anims/expected_anims.json                  per-clip landmark bone heads on every frame (UE cm)
  export/PantryRat_R02_Manifest.json                bones, slots, bounds, clips, Carry sockets in the UE frame, markers
The .blend is never saved. Prints PANTRY_RAT_OK / PANTRY_RAT_FAIL <reason>.

Run:  blender -b --factory-startup source/PantryRat_R02.blend --python scripts/export_pantry_rat.py
"""
import json
import math
import os
import struct
import sys
import traceback

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "export")
VAL = os.path.join(OUT, "validation")
ANIMS = os.path.join(OUT, "anims")
ARM_NAME = "PantryRat_R02_Armature"
MESH_NAME = "PantryRat_R02_Body"
TO_UE = np.array([1.0, -1.0, 1.0])
S = Matrix(((1, 0, 0), (0, -1, 0), (0, 0, 1)))
UE_ROOT = "/Game/ArtCandidates/PantryRat/R02"
LANDMARKS = ("body", "chest", "head", "jaw", "fore_foot_l", "fore_foot_r", "hind_foot_l", "hind_foot_r", "tail_04",
             "spoon_prop", "ear_l")
ADDITIVE_REF = {"clip": "IdleBreath", "frame": 0}

COMMON = dict(use_selection=True, apply_unit_scale=True, apply_scale_options="FBX_SCALE_NONE", global_scale=1.0,
              axis_forward="-Z", axis_up="Y", use_mesh_modifiers=False, mesh_smooth_type="FACE", use_triangles=True,
              use_tspace=False, add_leaf_bones=False, path_mode="STRIP", colors_type="SRGB",
              use_custom_props=False, bake_space_transform=False)
STATIC = dict(COMMON, object_types={"MESH"}, bake_anim=False)
SKELETAL = dict(COMMON, object_types={"ARMATURE", "MESH"}, primary_bone_axis="Y", secondary_bone_axis="X",
                use_armature_deform_only=True, armature_nodetype="NULL")
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


def ue(v):
    return [round(float(x), 4) for x in (np.array(v) * TO_UE)]


def mesh_facts(ob, M=None):
    me = ob.data
    me.calc_loop_triangles()
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    if M is not None:
        m = np.array(M)
        co = co @ m[:3, :3].T + m[:3, 3]
    u = co * TO_UE
    return {"object": ob.name, "tris": len(me.loop_triangles), "verts": len(me.vertices),
            "slots": [m.name for m in me.materials], "bounds_ue_cm": {"min": u.min(0).round(3).tolist(),
                                                                       "max": u.max(0).round(3).tolist()},
            "uv_layers": [x.name for x in me.uv_layers]}


def fcurves(action):
    out = []
    try:
        for layer in action.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    out.extend(cb.fcurves)
    except AttributeError:
        pass
    return out


def box_uv(me, scale=0.01):
    """UV0 by box projection on the face normal (static props only; nothing samples it but the lightmap generator)."""
    uvl = me.uv_layers.get("UV0") or me.uv_layers.new(name="UV0")
    for p in me.polygons:
        n = p.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][ax]
        for li in p.loop_indices:
            v = me.vertices[me.loops[li].vertex_index].co
            uvl.data[li].uv = (v[a] * scale, v[b] * scale)


def static_from(objs, name, slot_of, M_inv):
    """Join copies of objs into one new mesh object in a local frame (M_inv @ world), material slots by name."""
    bm = bmesh.new()
    slots = []
    for ob in objs:
        me = ob.data.copy()
        me.transform(M_inv @ ob.matrix_world)
        sl = slot_of(ob)
        if sl not in slots:
            slots.append(sl)
        tmp = bmesh.new()
        tmp.from_mesh(me)
        for f in tmp.faces:
            f.material_index = slots.index(sl)
        m2 = bpy.data.meshes.new("_tmp")
        tmp.to_mesh(m2)
        tmp.free()
        bm.from_mesh(m2)
        bpy.data.meshes.remove(m2)
        bpy.data.meshes.remove(me)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for s_ in slots:
        me.materials.append(bpy.data.materials.get(s_) or bpy.data.materials.new(s_))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def export_static(ob, path):
    select_only([ob])
    bpy.ops.export_scene.fbx(filepath=path, **STATIC)


def main():
    fails = []
    for d in (OUT, VAL, ANIMS):
        os.makedirs(d, exist_ok=True)
    sc = bpy.context.scene
    sc.render.fps, sc.render.fps_base = 30, 1.0
    if abs(sc.unit_settings.scale_length - 0.01) > 1e-6:
        fails.append("scale_length %s" % sc.unit_settings.scale_length)
    arm = bpy.data.objects[ARM_NAME]
    body = bpy.data.objects[MESH_NAME]
    arm.matrix_world = Matrix.Identity(4)
    files = {}
    clips = json.load(open(os.path.join(ANIMS, "clips.json")))
    report = json.load(open(os.path.join(ROOT, "review", "round_05", "anim_report.json")))

    # ---- cube (static recipe check)
    bpy.ops.mesh.primitive_cube_add(size=10.0, location=(0, 0, 0))
    cube = bpy.context.active_object
    cube.name = cube.data.name = "Cube10_Mars_SM"
    export_static(cube, os.path.join(VAL, "Cube10_Mars_SM.fbx"))
    files["cube"] = os.path.join(VAL, "Cube10_Mars_SM.fbx")
    bpy.data.objects.remove(cube, do_unlink=True)

    # ---- bind
    arm.animation_data_create()
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.location, pb.rotation_quaternion, pb.scale = (0, 0, 0), (1, 0, 0, 0), (1, 1, 1)
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    bones = [{"name": b.name, "parent": b.parent.name if b.parent else None, "head_ue_cm": ue(b.head_local),
              "tail_ue_cm": ue(b.tail_local)} for b in arm.data.bones]
    old = arm.name
    p = os.path.join(OUT, "PantryRat_R02_Mars_SK.fbx")
    try:
        arm.name = "Armature"
        select_only([arm, body])
        bpy.ops.export_scene.fbx(filepath=p, **BIND)
    finally:
        arm.name = old
    files["bind"] = p
    bind = mesh_facts(body)
    co = np.array([v.co for v in body.data.vertices]) * TO_UE
    nose = co[np.argmax(co[:, 0])]
    bind["nose_point_ue_cm"] = nose.round(3).tolist()

    # ---- Carry sockets (rest): component-space frame, and the bone-relative frame under the convention
    # R_ue = S R_b S, t_ue = S t  =>  relative location = S (Blender jaw-local), relative axes X = S x, Z = S z
    sockets = {}
    jaw = arm.data.bones["jaw"]
    Mj = jaw.matrix_local
    for nm in ("Carry_Mouth", "Carry_Drag"):
        e = bpy.data.objects[nm]
        Me = e.matrix_world.copy()
        loc_b = Mj.inverted() @ Me
        R = Me.to_3x3().normalized()
        Rl = loc_b.to_3x3().normalized()
        sockets[nm] = {
            "bone": "jaw",
            "component_cm": ue(Me.translation),
            "component_axis_x": [round(x, 6) for x in (S @ R.col[0])],
            "component_axis_z": [round(x, 6) for x in (S @ R.col[2])],
            "blender_world_rest_cm": [round(x, 4) for x in Me.translation],
            "blender_jaw_local_cm": [round(x, 4) for x in loc_b.translation],
            "blender_jaw_local_quat_wxyz": [round(x, 6) for x in loc_b.to_quaternion()],
            "ue_relative_location_cm_predicted": ue(loc_b.translation),
            "ue_relative_axis_x_predicted": [round(x, 6) for x in (S @ Rl.col[0])],
            "ue_relative_axis_z_predicted": [round(x, 6) for x in (S @ Rl.col[2])],
            "frame_rule": "UE = (x, -y, z); a frame's UE X axis = S*x_b, Z axis = S*z_b (Y = Z x X in UE's left-handed "
                          "sense); bone-relative values assume the UE jaw rest rotation = S*R_b*S (proved on the Unreal "
                          "readback: predicted vs read relative)"}
    jaw_rest = {"head_ue_cm": ue(jaw.head_local), "tail_ue_cm": ue(jaw.tail_local)}

    # ---- clips
    arm.data.pose_position = "POSE"
    expected = {"landmark_bones": list(LANDMARKS), "frame_map": "UE cm (x, -y, z)", "clips": {}}
    out_clips = {}
    jaw_loaded = {}
    for name in clips:
        act = bpy.data.actions.get(name)
        if act is None:
            fails.append("missing action %s" % name)
            continue
        if any(fc.data_path.endswith("scale") for fc in fcurves(act)):
            fails.append("%s has scale keys" % name)
        if any('"root"' in fc.data_path for fc in fcurves(act)):
            fails.append("%s keys the root" % name)
        start, end = clips[name]["frames"]
        arm.animation_data.action = act
        if arm.animation_data.action_slot is None and len(act.slots):
            arm.animation_data.action_slot = act.slots[0]
        lm = {}
        jmax = 0.0
        cf = report["clips"][name].get("carry_frames")
        for f in range(start, end + 1):
            sc.frame_set(f)
            bpy.context.view_layer.update()
            k = {n: ue(arm.matrix_world @ arm.pose.bones[n].head) for n in LANDMARKS}
            r = arm.pose.bones["root"].matrix
            k["root_dev"] = round(float(r.translation.length + r.to_quaternion().angle), 8)
            lm[str(f)] = k
            if cf and cf[0] <= f <= cf[1]:
                jmax = max(jmax, math.degrees(arm.pose.bones["jaw"].rotation_quaternion.angle))
        if cf:
            jaw_loaded[name] = round(jmax, 3)
        sc.frame_set(start)
        path = os.path.join(ANIMS, "PantryRat_R02_%s_Mars_ANIM.fbx" % name)
        sc.frame_start, sc.frame_end = start, end
        try:
            arm.name = "Armature"
            select_only([arm, body])
            bpy.ops.export_scene.fbx(filepath=path, **CLIP)
        finally:
            arm.name = old
        expected["clips"][name] = {"file": os.path.basename(path), "first": start, "last": end,
                                   "samples": end - start + 1, "loop": clips[name]["loop"], "landmarks": lm}
        rc_ = report["clips"][name]
        keyf = sorted({start, end, (start + end) // 2})
        out_clips[name] = {"fps": 30, "frames": [start, end], "frame_count": end - start, "samples": end - start + 1,
                           "seconds": round((end - start) / 30.0, 6),
                           "seconds_proposed": rc_["seconds_proposed"], "loop": clips[name]["loop"],
                           "additive": clips[name]["additive"],
                           "additive_reference": ADDITIVE_REF if clips[name]["additive"] else None,
                           "landmarks_ue_cm": {str(f): lm[str(f)] for f in keyf},
                           "file": "export/anims/" + os.path.basename(path), "bytes": os.path.getsize(path),
                           "unreal_path": "%s/Animation/PantryRat_R02_%s_Mars_ANIM" % (UE_ROOT, name),
                           "carry_frames": cf}
        if clips[name].get("design_speed_cm_s"):
            # the stance slide speed the clip was authored at; the assembly's play-rate table (Mars_PantryRat_EntityScript.as)
            # carries the same numbers
            out_clips[name]["design_speed_cm_s"] = clips[name]["design_speed_cm_s"]
        print("EXPORTED clip %-17s %s" % (name, path))
    arm.animation_data.action = None
    with open(os.path.join(ANIMS, "expected_anims.json"), "w") as fh:
        json.dump(expected, fh, indent=1)

    # ---- statics: den (Stone/Void), den eye plate quad, cheese (Rind/Flesh)
    den_root = bpy.data.objects["Den_StoneArch"]
    Minv = den_root.matrix_world.inverted()
    den = static_from([bpy.data.objects[n] for n in ("Den_StoneArch_Shell", "Den_Recess", "Den_BackPlane")],
                      "PantryRat_R02_Den_Mars_SM", lambda o: "Stone" if o.name.endswith("Shell") else "Void", Minv)
    box_uv(den.data)
    p = os.path.join(OUT, "PantryRat_R02_Den_Mars_SM.fbx")
    export_static(den, p)
    files["den"] = p
    den_f = mesh_facts(den)
    # eye plate: the front (+X local, out of the den) face of the authored plate as one quad, UV 0..1 kept
    ep = bpy.data.objects["Den_EyePlate"]
    me = ep.data.copy()
    me.transform(Minv @ ep.matrix_world)
    bm = bmesh.new()
    bm.from_mesh(me)
    uvl = bm.loops.layers.uv.get("UV0") or bm.loops.layers.uv.active
    front = [f for f in bm.faces if f.normal.x > 0.9]
    fco = [l.vert.co.copy() for f in front for l in f.loops]
    fuv = [tuple(l[uvl].uv) for f in front for l in f.loops] if uvl else []
    bm.free()
    bpy.data.meshes.remove(me)
    xs = max(v.x for v in fco)
    ys = [v.y for v in fco]
    zs = [v.z for v in fco]
    y0, y1, z0, z1 = min(ys), max(ys), min(zs), max(zs)
    qme = bpy.data.meshes.new("PantryRat_R02_DenEyePlate_Mars_SM")
    # winding: normal +X (out of the den, toward the viewer); U = 0 at +Y (resident's left), V = 0 at the bottom
    qme.from_pydata([(xs, y0, z0), (xs, y1, z0), (xs, y1, z1), (xs, y0, z1)], [], [(0, 1, 2, 3)])
    q_uv = qme.uv_layers.new(name="UV0")
    for li, uvv in zip(range(4), ((1, 0), (0, 0), (0, 1), (1, 1))):
        q_uv.data[li].uv = uvv
    qme.materials.append(bpy.data.materials.get("EyePatch"))
    qme.update()
    quad = bpy.data.objects.new("PantryRat_R02_DenEyePlate_Mars_SM", qme)
    sc.collection.objects.link(quad)
    p = os.path.join(OUT, "PantryRat_R02_DenEyePlate_Mars_SM.fbx")
    export_static(quad, p)
    files["den_eye_plate"] = p
    plate_f = dict(mesh_facts(quad), quad_normal_ue=[round(x, 4) for x in (S @ qme.polygons[0].normal)],
                   source_front_uv_range=[[round(min(u[0] for u in fuv), 4), round(max(u[0] for u in fuv), 4)],
                                          [round(min(u[1] for u in fuv), 4), round(max(u[1] for u in fuv), 4)]] if fuv else None,
                   uv_rule="U = 0 at den +Y Blender (= UE -Y, the resident's LEFT when it faces out of the den), "
                           "U = 1 at den -Y; V = 0 at the bottom")
    # cheese
    ch = bpy.data.objects["Cheese_MonksRind"]
    cme = ch.data.copy()
    cob = bpy.data.objects.new("PantryRat_R02_Cheese_Mars_SM", cme)
    sc.collection.objects.link(cob)
    cme.materials.clear()
    for s_ in ("Rind", "Flesh"):
        cme.materials.append(bpy.data.materials.get(s_) or bpy.data.materials.new(s_))
    col = cme.color_attributes.get("Col")
    cnt = {"Rind": 0, "Flesh": 0}
    for p_ in cme.polygons:
        c = np.mean([tuple(col.data[li].color_srgb if col.domain == "CORNER" else
                           col.data[cme.loops[li].vertex_index].color_srgb)[:3] for li in p_.loop_indices], axis=0)
        rind = (c[0] - c[2]) > 0.3
        p_.material_index = 0 if rind else 1
        cnt["Rind" if rind else "Flesh"] += 1
    box_uv(cme)
    p = os.path.join(OUT, "PantryRat_R02_Cheese_Mars_SM.fbx")
    export_static(cob, p)
    files["cheese"] = p
    cheese_f = dict(mesh_facts(cob), faces_per_slot=cnt)

    # markers (den-local UE cm) + world
    markers = {}
    for n in ("EntryPortal", "ExitPortal", "ReturnAdmission", "OutsideStand"):
        o = bpy.data.objects[n]
        markers[n] = {"den_local_ue_cm": ue((Minv @ o.matrix_world).translation),
                      "phase1_court_world_ue_cm": ue(o.matrix_world.translation)}

    # ---- settings + expected + manifest
    fbx_ver = None
    try:
        import addon_utils
        for m in addon_utils.modules():
            if m.__name__ in ("io_scene_fbx", "bl_ext.system.io_scene_fbx"):
                fbx_ver = ".".join(str(x) for x in m.bl_info.get("version", ()))
    except Exception as e:  # noqa: BLE001
        fbx_ver = "unknown (%s)" % e
    all_files = dict(files)
    all_files.update({"clip_%s" % n: os.path.join(ANIMS, "PantryRat_R02_%s_Mars_ANIM.fbx" % n) for n in out_clips})
    settings = {"blender_version": bpy.app.version_string, "fbx_addon_version": fbx_ver,
                "scene_unit_settings": {"system": sc.unit_settings.system, "scale_length": sc.unit_settings.scale_length},
                "frame_map": "Blender (x, y, z) BU=cm -> Unreal (x, -y, z) cm",
                "armature_export_name": "Armature (renamed during export only; Unreal drops this root node)",
                "static_mesh_args": jsonable(STATIC), "bind_args": jsonable(BIND), "clip_args": jsonable(CLIP),
                "recipe_source": "Tools/Blender/mars_monsters/cellar_bat_r01/scripts/export_cellar_bat.py (verbatim)",
                "files": {k: {"path": os.path.relpath(v, ROOT).replace("\\", "/"), "bytes": os.path.getsize(v),
                              "header": fbx_header(v)} for k, v in all_files.items()}}
    with open(os.path.join(VAL, "export_settings.json"), "w") as fh:
        json.dump(settings, fh, indent=1)
    exp = {"bones": bones, "bind": bind, "slots": bind["slots"], "den": den_f, "den_eye_plate": plate_f,
           "cheese": cheese_f, "cube_bounds_ue_cm": {"min": [-5.0] * 3, "max": [5.0] * 3}, "sockets": sockets}
    with open(os.path.join(VAL, "expected.json"), "w") as fh:
        json.dump(exp, fh, indent=1)
    hdr = fbx_header(files["bind"])
    manifest = {
        "asset": "PantryRat_R02", "generated_by": "scripts/export_pantry_rat.py (Phase 2)",
        "versions": {"blender": bpy.app.version_string, "fbx_exporter_addon": fbx_ver,
                     "fbx_file_version": hdr.get("file_version"), "fbx_creator": hdr.get("Creator")},
        "units_axes": {"blender": "1 BU = 1 cm (scale_length 0.01), +X forward, +Z up, rat LEFT = Blender +Y",
                       "frame_map": "Blender (x, y, z) -> Unreal (x, -y, z); rat LEFT (*_l) = Unreal -Y",
                       "exporter_args_common": jsonable(COMMON), "bind_args": jsonable(BIND), "clip_args": jsonable(CLIP)},
        "bone_count": len(bones), "bones": bones, "slots": bind["slots"],
        "bind": {k: bind[k] for k in ("tris", "verts", "bounds_ue_cm", "nose_point_ue_cm")},
        "withers_target_cm": 35.3, "jaw_rest": jaw_rest,
        "sockets": sockets,
        "clip_contract": {"fps": 30, "root": "root bone never keyed: identity on every sample of every clip",
                          "durations": "frames N = round_half_up(seconds * 30); N+1 samples on frames 0..N; length N/30 s",
                          "loops": "frame N == frame 0 in pose; seam second difference <= interior max (anim_report)",
                          "additive": "EarFlick / TailSettle: full poses that start and end on IdleBreath frame 0; "
                                      "import additive (local space) against IdleBreath frame 0",
                          "jaw_closed_on_carry_max_deg": jaw_loaded},
        "clips": out_clips,
        "den": {"file": "export/PantryRat_R02_Den_Mars_SM.fbx", "slots": den_f["slots"], "tris": den_f["tris"],
                "bounds_ue_cm": den_f["bounds_ue_cm"], "frame": "den-local: origin = den root on the floor, +X = out "
                                                              "of the den (the opening faces +X), opening 60 x 60",
                "markers": markers},
        "den_eye_plate": {"file": "export/PantryRat_R02_DenEyePlate_Mars_SM.fbx", "tris": plate_f["tris"],
                          "bounds_ue_cm": plate_f["bounds_ue_cm"], "uv_rule": plate_f["uv_rule"]},
        "cheese": {"file": "export/PantryRat_R02_Cheese_Mars_SM.fbx", "slots": cheese_f["slots"],
                   "tris": cheese_f["tris"], "bounds_ue_cm": cheese_f["bounds_ue_cm"],
                   "faces_per_slot": cnt, "pivot": "base centre"},
        "unreal_paths": {"skeletal_mesh": UE_ROOT + "/Meshes/PantryRat_R02_Mars_SK",
                         "skeleton": UE_ROOT + "/Meshes/PantryRat_R02_Mars_SKEL",
                         "animations": UE_ROOT + "/Animation/PantryRat_R02_<Clip>_Mars_ANIM",
                         "props": UE_ROOT + "/Props/", "materials": UE_ROOT + "/Materials/"},
    }
    with open(os.path.join(OUT, "PantryRat_R02_Manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=1)
    print("BIND", json.dumps({k: bind[k] for k in ("tris", "verts", "slots", "bounds_ue_cm")}))
    print("SOCKETS", json.dumps(sockets))
    print("DEN", json.dumps(den_f), "PLATE", json.dumps(plate_f), "CHEESE", json.dumps(cheese_f))
    print("JAW_LOADED_MAX_DEG", json.dumps(jaw_loaded))
    print("FBX", json.dumps(hdr), "addon", fbx_ver)
    if len(bones) != 26:
        fails.append("bones %d" % len(bones))
    if len(out_clips) != 35:   # Phase 9: + Walk
        fails.append("clips %d" % len(out_clips))
    if cnt["Rind"] == 0 or cnt["Flesh"] == 0:
        fails.append("cheese slots %s" % cnt)
    if fails:
        print("PANTRY_RAT_FAIL " + "; ".join(fails))
        sys.exit(1)
    print("PANTRY_RAT_OK")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        print("PANTRY_RAT_FAIL exception")
        sys.exit(1)
