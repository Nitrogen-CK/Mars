"""Cellar Bat R01 - animator control rig (Phase 3).

A separate armature `CellarBat_R01_Controls` (collection `Rig`, never exported) drives the 42 export bones through
constraints on the export armature:

  FK layer      `CTL_<bone>` for every export bone except `root` (same rest head/tail/roll, same hierarchy under
                `CTL_root`). Each export bone carries `RIG_FK` = Copy Transforms (local -> local, replace).
                Animated directly: body pitch/roll (`CTL_pelvis`, `CTL_spine`), per-wing flap (`CTL_upperarm_*`),
                elbow (`CTL_forearm_*`), wrist curl (`CTL_wrist_*`), per-finger / thumb FK, neck/head, jaw, ears, legs.
  Sliders       bones whose local Y location (up in the viewport) is the value; Limit Location clamps them:
                  CTL_fold_l / CTL_fold_r   0..1  wing fold: 0 spread, 0.5 the half fold, 1 the solved wrap
                                                  (two Transform constraints per wing bone, `RIG_fold_a` 0..0.5 and
                                                  `RIG_fold_b` 0.5..1, Euler targets = the aim-solved local rotations)
                  CTL_fan_l / CTL_fan_r     -0.3..1  finger fan: 1 closes the four fingers toward the forearm,
                                                  negative spreads them (`RIG_fan`, one per finger)
                  CTL_ears  Y -1..1 (-1 flat, 0 rest, +1 alert), X 0..1 twitch (both ears; `RIG_ear_*`)
                  CTL_jaw_open              0..1  jaw open (`RIG_jaw`)
                  CTL_perch                 0..1  foot contact: blends both legs onto the foot targets (IK)
  Foot targets  `CTL_foot_ik_l/_r` (children of CTL_root, rest = the foot bones): IK (chain 2) on `shin_*` and
                a world Copy Rotation on `foot_*`, both with influence driven by CTL_perch (simple-expression driver,
                no Python needed when the file is opened).
Constraint order on a wing bone: RIG_FK, RIG_fold_a, RIG_fold_b, RIG_fan (each Transform mixes AFTER, i.e. as a child
of what came before). The root bone carries no constraint and never moves.
"""
import math

import bpy
from mathutils import Matrix, Quaternion, Vector

CTRL_NAME = "CellarBat_R01_Controls"

SLIDERS = {  # value name -> (slider bone, local axis index, min, max)
    "fold_l": ("CTL_fold_l", 1, 0.0, 1.0), "fold_r": ("CTL_fold_r", 1, 0.0, 1.0),
    "fan_l": ("CTL_fan_l", 1, -0.3, 1.0), "fan_r": ("CTL_fan_r", 1, -0.3, 1.0),
    "ear_alert": ("CTL_ears", 1, -1.0, 1.0), "ear_twitch": ("CTL_ears", 0, 0.0, 1.0),
    "jaw_open": ("CTL_jaw_open", 1, 0.0, 1.0), "perch": ("CTL_perch", 1, 0.0, 1.0),
}
SLIDER_BONES = {  # bone -> world head (cm), slider bones point up (+Z) so local Y = world up
    "CTL_fold_l": (0.0, 9.0, 34.0), "CTL_fold_r": (0.0, -9.0, 34.0),
    "CTL_fan_l": (0.0, 12.0, 34.0), "CTL_fan_r": (0.0, -12.0, 34.0),
    "CTL_ears": (0.0, 0.0, 34.0), "CTL_jaw_open": (0.0, 3.0, 34.0), "CTL_perch": (0.0, -3.0, 34.0),
}


def wing_bones(sfx):
    out = ["upperarm" + sfx, "forearm" + sfx, "wrist" + sfx]
    for i in range(1, 5):
        out += ["finger_0%da%s" % (i, sfx), "finger_0%db%s" % (i, sfx)]
    return out + ["thumb_a" + sfx, "thumb_b" + sfx]


def _transform_rot(pb, name, ctrl, sub, axis, frm, q, mix="AFTER", extrapolate=False, at_min=False):
    c = pb.constraints.new("TRANSFORM")
    c.name = name
    c.target = ctrl
    c.subtarget = sub
    c.owner_space = "LOCAL"
    c.target_space = "LOCAL"
    c.map_from = "LOCATION"
    c.map_to = "ROTATION"
    ax = "xyz"[axis]
    setattr(c, "from_min_" + ax, frm[0])
    setattr(c, "from_max_" + ax, frm[1])
    up = ax.upper()
    c.map_to_x_from = c.map_to_y_from = c.map_to_z_from = up
    e = q.to_euler("XYZ")
    c.to_euler_order = "XYZ"
    lo, hi = ((e.x, e.y, e.z), (0.0, 0.0, 0.0)) if at_min else ((0.0, 0.0, 0.0), (e.x, e.y, e.z))
    c.to_min_x_rot, c.to_min_y_rot, c.to_min_z_rot = lo
    c.to_max_x_rot, c.to_max_y_rot, c.to_max_z_rot = hi
    c.mix_mode_rot = mix
    c.use_motion_extrapolate = extrapolate
    return c


def _drive_influence(con, ctrl, bone, axis="LOC_Y"):
    fc = con.driver_add("influence")
    drv = fc.driver
    drv.type = "SCRIPTED"
    v = drv.variables.new()
    v.name = "v"
    v.type = "TRANSFORMS"
    t = v.targets[0]
    t.id = ctrl
    t.bone_target = bone
    t.transform_type = axis
    t.transform_space = "LOCAL_SPACE"
    drv.expression = "v"
    return fc


def build(export_arm, coll, tables):
    """tables: fold_half / fold_wrap {bone: Quaternion local}, fan {bone: Quaternion local at fan=1},
    ear_alert / ear_flat / ear_twitch {bone: Quaternion local}, jaw_open Quaternion local."""
    data = bpy.data.armatures.new(CTRL_NAME)
    ctrl = bpy.data.objects.new(CTRL_NAME, data)
    coll.objects.link(ctrl)
    bpy.context.view_layer.objects.active = ctrl
    for o in bpy.context.view_layer.objects:
        o.select_set(o is ctrl)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = data.edit_bones
    r = eb.new("CTL_root")
    r.head, r.tail, r.roll = Vector((0, 0, 0)), Vector((0, 6.0, 0)), 0.0
    src = export_arm.data.bones
    for b in src:
        if b.name == "root":
            continue
        e = eb.new("CTL_" + b.name)
        e.head, e.tail = Vector((0, 0, 0)), Vector((0, b.length, 0))
        e.matrix = b.matrix_local.copy()
        e.length = b.length
    for b in src:
        if b.name == "root":
            continue
        e = eb["CTL_" + b.name]
        e.parent = eb["CTL_" + b.parent.name] if b.parent and b.parent.name != "root" else eb["CTL_root"]
        e.use_connect = False
    for s in ("l", "r"):
        fb = src["foot_" + s]
        e = eb.new("CTL_foot_ik_" + s)
        e.head, e.tail = Vector((0, 0, 0)), Vector((0, fb.length, 0))
        e.matrix = fb.matrix_local.copy()
        e.length = fb.length
        e.parent = eb["CTL_root"]
    for n, h in SLIDER_BONES.items():
        e = eb.new(n)
        e.head = Vector(h)
        e.tail = Vector(h) + Vector((0, 0, 1.5))
        e.roll = 0.0
        e.parent = eb["CTL_root"]
    for e in eb:
        e.use_deform = False
    bpy.ops.object.mode_set(mode="OBJECT")
    data.display_type = "OCTAHEDRAL"
    for pb in ctrl.pose.bones:
        pb.rotation_mode = "QUATERNION"
        if pb.name.startswith("CTL_") and pb.name[4:] in src and pb.name != "CTL_root":
            pb.lock_location = (True, True, True)
            pb.lock_scale = (True, True, True)
    ctrl.pose.bones["CTL_root"].lock_location = (True, True, True)
    ctrl.pose.bones["CTL_root"].lock_rotation = (True, True, True)
    ctrl.pose.bones["CTL_root"].lock_rotation_w = True
    for n in SLIDER_BONES:
        pb = ctrl.pose.bones[n]
        pb.lock_rotation = (True, True, True)
        pb.lock_rotation_w = True
        pb.lock_scale = (True, True, True)
        axes = {SLIDERS[k][1]: (SLIDERS[k][2], SLIDERS[k][3]) for k in SLIDERS if SLIDERS[k][0] == n}
        pb.lock_location = tuple(i not in axes for i in range(3))
        lc = pb.constraints.new("LIMIT_LOCATION")
        lc.owner_space = "LOCAL"
        lc.use_transform_limit = True
        for i, ax in enumerate("xyz"):
            lo, hi = axes.get(i, (0.0, 0.0))
            setattr(lc, "use_min_" + ax, True)
            setattr(lc, "use_max_" + ax, True)
            setattr(lc, "min_" + ax, lo)
            setattr(lc, "max_" + ax, hi)

    # ---- constraints on the export bones
    ab = export_arm.pose.bones
    for pb in ab:
        for c in list(pb.constraints):
            pb.constraints.remove(c)
        if pb.name == "root":
            continue
        c = pb.constraints.new("COPY_TRANSFORMS")
        c.name = "RIG_FK"
        c.target = ctrl
        c.subtarget = "CTL_" + pb.name
        c.owner_space = c.target_space = "LOCAL"
        c.mix_mode = "REPLACE"
    for s in ("l", "r"):
        sfx = "_" + s
        for bn in wing_bones(sfx):
            qh = tables["fold_half"].get(bn, Quaternion())
            qw = tables["fold_wrap"].get(bn, Quaternion())
            _transform_rot(ab[bn], "RIG_fold_a", ctrl, "CTL_fold" + sfx, 1, (0.0, 0.5), qh)
            _transform_rot(ab[bn], "RIG_fold_b", ctrl, "CTL_fold" + sfx, 1, (0.5, 1.0), qh.inverted() @ qw)
        for i in range(1, 5):
            bn = "finger_0%da%s" % (i, sfx)
            _transform_rot(ab[bn], "RIG_fan", ctrl, "CTL_fan" + sfx, 1, (0.0, 1.0), tables["fan"][bn],
                           extrapolate=True)
        for bn in ("ear_base" + sfx, "ear_tip" + sfx):
            if bn in tables["ear_alert"]:
                _transform_rot(ab[bn], "RIG_ear_alert", ctrl, "CTL_ears", 1, (0.0, 1.0), tables["ear_alert"][bn])
            if bn in tables["ear_flat"]:
                # Y -1 -> flat, 0 and above -> rest (clamped)
                _transform_rot(ab[bn], "RIG_ear_flat", ctrl, "CTL_ears", 1, (-1.0, 0.0), tables["ear_flat"][bn],
                               at_min=True)
            if bn in tables["ear_twitch"]:
                _transform_rot(ab[bn], "RIG_ear_twitch", ctrl, "CTL_ears", 0, (0.0, 1.0), tables["ear_twitch"][bn])
        ik = ab["shin" + sfx].constraints.new("IK")
        ik.name = "RIG_perch_ik"
        ik.target = ctrl
        ik.subtarget = "CTL_foot_ik" + sfx
        ik.chain_count = 2
        ik.use_tail = True
        ik.use_stretch = False
        _drive_influence(ik, ctrl, "CTL_perch")
        cr = ab["foot" + sfx].constraints.new("COPY_ROTATION")
        cr.name = "RIG_perch_foot"
        cr.target = ctrl
        cr.subtarget = "CTL_foot_ik" + sfx
        cr.owner_space = cr.target_space = "WORLD"
        cr.mix_mode = "REPLACE"
        _drive_influence(cr, ctrl, "CTL_perch")
    _transform_rot(ab["jaw"], "RIG_jaw", ctrl, "CTL_jaw_open", 1, (0.0, 1.0), tables["jaw_open"])
    bpy.context.view_layer.update()
    return ctrl


def reset(ctrl):
    for pb in ctrl.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Quaternion()
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)


def set_controls(ctrl, values):
    """values: {"CTL_x": Quaternion | {"rot": Quaternion, "loc": Vector}, slider name: float,
    "foot_ik_l"/"foot_ik_r": world (armature-space) Matrix for the foot target}."""
    reset(ctrl)
    bpy.context.view_layer.update()
    for k, v in values.items():
        if k in SLIDERS:
            bn, ax, lo, hi = SLIDERS[k]
            loc = list(ctrl.pose.bones[bn].location)
            loc[ax] = float(v)
            ctrl.pose.bones[bn].location = loc
        elif k.startswith("foot_ik_"):
            pb = ctrl.pose.bones["CTL_" + k]
            pb.matrix_basis = ctrl.convert_space(pose_bone=pb, matrix=v, from_space="POSE", to_space="LOCAL")
        elif isinstance(v, dict):
            pb = ctrl.pose.bones[k]
            if "rot" in v:
                pb.rotation_quaternion = v["rot"]
            if "loc" in v:
                pb.location = v["loc"]
        else:
            ctrl.pose.bones[k].rotation_quaternion = v
    bpy.context.view_layer.update()


def key_all(ctrl, frame):
    for pb in ctrl.pose.bones:
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)


def pose_action(ctrl, name, values, frame=0):
    if ctrl.animation_data is None:
        ctrl.animation_data_create()
    act = bpy.data.actions.get(name) or bpy.data.actions.new(name)
    act.use_fake_user = True
    ctrl.animation_data.action = act
    set_controls(ctrl, values)
    key_all(ctrl, frame)
    ctrl.animation_data.action = None
    reset(ctrl)
    bpy.context.view_layer.update()
    return act


def use_action(ctrl, act, frame=0):
    if ctrl.animation_data is None:
        ctrl.animation_data_create()
    ctrl.animation_data.action = act
    if act is not None and ctrl.animation_data.action_slot is None and len(act.slots):
        ctrl.animation_data.action_slot = act.slots[0]
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()


def mute(export_arm, state=True):
    for pb in export_arm.pose.bones:
        for c in pb.constraints:
            c.mute = state
    bpy.context.view_layer.update()


def pose_matrices(arm):
    return {pb.name: pb.matrix.copy() for pb in arm.pose.bones}


def compare(ma, mb):
    """max head distance (cm) and max rotation difference (deg) between two pose-matrix dicts."""
    dp, da = 0.0, 0.0
    for k in ma:
        a, b = ma[k], mb[k]
        dp = max(dp, (a.translation - b.translation).length)
        q = a.to_quaternion().rotation_difference(b.to_quaternion())
        da = max(da, math.degrees(q.angle) if q.angle <= math.pi else 360.0 - math.degrees(q.angle))
    return dp, da
