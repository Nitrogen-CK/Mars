"""Service Steward: the source scene (a Tripo body + face plate on its auto-rig) -> the game-ready skeletal mesh.

Needs an armature `ServiceSteward` with the meshes `Body` and `Face` parented to it, as the source scene has them
(any units, any object scale: the armature's world scale is the steward's height). Re-runnable; nothing here reads a
selection or a mode. The .blend, the texture and the FBX live outside this repo, in the content folder
(D:\Repo\Content\Characters\ServiceSteward); the script writes next to the .blend it is run on. Headless:

    cd D:\Repo\Content\Characters\ServiceSteward
    blender -b ServiceSteward_Source.blend --python D:\Repo\Mars\Tools\Blender\mars_steward\build_steward.py -- --save ServiceSteward.blend --export

then, in the editor, unreal/mars_steward_ue.py imports the result.

What it does, in order:
  1. normalise  - the scene to cm (unit scale 0.01) and the rig's world transform baked into bones and vertices, so
                  the FBX carries no scale (the chef pipeline's convention: cm, Z up, facing -Y, left = +X).
  2. materials  - the body's material is `M_Steward` (its base colour repointed at Textures/Steward_BaseColor.jpg),
                  the face plate's is `M_EyePlate`.
  3. eye plate  - the whole face plate becomes the eye plate: in Unreal the MarsEyePlate look (Script/ECS/Eyes) draws
                  that slot as a black void with two glowing eyes, the same tech as the chef's eye quads. Each half of
                  the plate (it is a wedge with a keel down the middle) is UV-projected onto its own eye rectangle;
                  see build_eye_plate.
  4. weights    - the face plate rides the head bone rigidly (the eyes' face node follows that bone).
  5. idle       - `A_Steward_Idle`, a 6 s breathing loop (build_idle).
  6. export     - Steward_Mars_SK.fbx and Steward_Idle_Mars_AS.fbx next to the .blend.

Prints one `STEWARD_..._OK` line per step and `STEWARD_FACE` with where the face node sits (the editor-side helper
measures the same thing off the imported mesh).
"""
import json
import math
import os
import sys
from math import radians

import bpy
from mathutils import Matrix, Quaternion, Vector

# Outputs go next to the .blend the script runs on (the content folder), not next to the script.
OUT = os.path.dirname(bpy.data.filepath) if bpy.data.filepath else os.getcwd()

RIG_NAME = "ServiceSteward"
BODY_NAME = "Body"
FACE_NAME = "Face"
BODY_MATERIAL = "M_Steward"
EYES_MATERIAL = "M_EyePlate"     # the slot name the steward's entity script looks up (FMars_Steward_Face::EyesSlot)
EYES_BONE = "head"
TEXTURE = os.path.join(OUT, "Textures", "Steward_BaseColor.jpg")
FBX_MESH = os.path.join(OUT, "Steward_Mars_SK.fbx")
FBX_IDLE = os.path.join(OUT, "Steward_Idle_Mars_AS.fbx")
SIDECAR = os.path.join(OUT, "Steward_Mars_SK.json")   # what the editor-side helper needs to know about the mesh
UNITS_TAG = "steward_units"

# --- the eye plate (cm, after normalise; +X is the steward's left) ----------------------------------------------
# Measured off the source texture's painted eyes (2026-10-12): bright ovals about 4.3 x 8.4 cm in the plane of each
# half of the wedge, centred near (+3.3, -26.2, 229.4) and (-4.3, -25.2, 229.3); the two are made symmetric here.
EYE_CENTRE = Vector((3.8, -25.7, 229.35))       # the left eye; the right one mirrors X
EYE_NORMAL = Vector((0.687, -0.703, 0.170))     # out of the left half of the wedge (fitted through the painted eye)
EYE_DRAWN = (4.3, 8.4)                          # the resting eye as drawn on the plate: width, height
# The resting style's shape inside its atlas cell (Tools/EyesAtlas: the Classic Oval is 44 x 76 px of a 128 px
# cell). The eye rectangle is the drawn size over these, so the cell lands at EYE_DRAWN. The rectangle (12.5 x 14.1)
# is wider than a half plate on purpose: no vertex's U leaves its half, where the look's frac() would repeat the eye.
EYE_CELL_SHAPE = (44.0 / 128.0, 76.0 / 128.0)
EYE_U_MARGIN = 0.01                             # U (per eye, 0..1) is clamped inside this margin of its half

# --- the idle ---------------------------------------------------------------------------------------------------
IDLE_ACTION = "A_Steward_Idle"
IDLE_FPS = 30
IDLE_FRAMES = 180                               # 6 s; frame 0 == frame 180
IDLE_KEY_STEP = 5

FBX_COMMON = dict(use_selection=True, apply_unit_scale=True, apply_scale_options='FBX_SCALE_NONE',
                  global_scale=1.0, axis_forward='-Z', axis_up='Y',
                  primary_bone_axis='X', secondary_bone_axis='-Y',
                  add_leaf_bones=False, use_armature_deform_only=False, armature_nodetype='NULL')


def objects():
    arm = bpy.data.objects[RIG_NAME]
    return arm, bpy.data.objects[BODY_NAME], bpy.data.objects[FACE_NAME]


# ----------------------------------------------------------------------------------------------------------------
# 1. units
# ----------------------------------------------------------------------------------------------------------------
def normalise():
    """cm scene, identity object transforms: the rig's world transform (the 2.9 that makes the steward 2.9 m) goes
    into the bones and the vertices. Done once (the rig is tagged); a second run only checks."""
    arm, body, face = objects()
    sc = bpy.context.scene
    if arm.get(UNITS_TAG) != "cm":
        to_cm = Matrix.Scale(1.0 / 0.01 * sc.unit_settings.scale_length, 4)
        bpy.context.view_layer.update()
        for o in (body, face):
            o.data.transform(to_cm @ o.matrix_world)
            o.data.update()
        arm.data.transform(to_cm @ arm.matrix_world)
        arm.matrix_world = Matrix.Identity(4)
        for o in (body, face):
            o.matrix_parent_inverse = Matrix.Identity(4)
            o.matrix_basis = Matrix.Identity(4)
        sc.unit_settings.system = 'METRIC'
        sc.unit_settings.scale_length = 0.01
        arm[UNITS_TAG] = "cm"
        bpy.context.view_layer.update()
    zs = [v.co.z for v in body.data.vertices]
    ident = all(abs(arm.matrix_world[i][j] - (1.0 if i == j else 0.0)) < 1e-6 for i in range(4) for j in range(4))
    assert ident and abs(sc.unit_settings.scale_length - 0.01) < 1e-9, "the rig is tagged cm but is not normalised"
    print("STEWARD_UNITS_OK height=%.2f cm feet=%.3f bones=%d" % (max(zs) - min(zs), min(zs), len(arm.data.bones)))
    return max(zs) - min(zs)


# ----------------------------------------------------------------------------------------------------------------
# 2. materials
# ----------------------------------------------------------------------------------------------------------------
def materials():
    arm, body, face = objects()
    mat = body.data.materials[0]
    mat.name = BODY_MATERIAL
    if os.path.isfile(TEXTURE) and mat.node_tree:
        for n in mat.node_tree.nodes:
            if n.type == 'TEX_IMAGE' and n.image is not None:
                n.image.filepath = TEXTURE
                n.image.name = os.path.basename(TEXTURE)
    eyes = bpy.data.materials.get(EYES_MATERIAL) or bpy.data.materials.new(EYES_MATERIAL)
    eyes.diffuse_color = (0.0, 0.0, 0.0, 1.0)  # the plate is black where no eye is drawn
    face.data.materials.clear()
    face.data.materials.append(eyes)
    for p in face.data.polygons:
        p.material_index = 0
    print("STEWARD_MATERIALS_OK body=%s face=%s" % (body.data.materials[0].name, face.data.materials[0].name))


# ----------------------------------------------------------------------------------------------------------------
# 3. the eye plate
# ----------------------------------------------------------------------------------------------------------------
def eye_frame(side):
    """(centre, out, up, normal) of one eye rectangle; side +1 = the steward's left eye (+X), -1 = the right.
    `out` runs along the plate away from the keel, `up` up the plate."""
    n = Vector((EYE_NORMAL.x * side, EYE_NORMAL.y, EYE_NORMAL.z)).normalized()
    up = (Vector((0.0, 0.0, 1.0)) - n * n.z).normalized()
    out = up.cross(n).normalized()
    if out.x * side < 0.0:
        out = -out
    return Vector((EYE_CENTRE.x * side, EYE_CENTRE.y, EYE_CENTRE.z)), out, up, n


def eye_rect():
    return EYE_DRAWN[0] / EYE_CELL_SHAPE[0], EYE_DRAWN[1] / EYE_CELL_SHAPE[1]


def build_eye_plate():
    """UVs of the face plate for the eye-plate look (Shaders/Looks/EyePlate.ush): U < 0.5 is the left eye and
    U > 0.5 the right, each half one eye rectangle with U 0 / 1 on the outer edges and 0.5 on both inner ones; V is
    0 on the top edge in Unreal, so Blender's v is 1 there. Each polygon is projected along its half's normal onto
    that half's rectangle (a decal), so the eye lies on the wedge with no extra geometry. Outside the rectangle the
    look draws black: v runs free (no wrap), u is clamped inside its half (a wrapped u would draw a second eye; the
    plate's outer flanks turn away past the rectangle's outer edge, well clear of the eye)."""
    arm, body, face = objects()
    me = face.data
    w, h = eye_rect()
    layer = me.uv_layers.active or me.uv_layers.new(name="UVMap")
    # the resting eye's box in the rectangle's own 0..1 space
    rest_u = (0.5 - EYE_CELL_SHAPE[0] / 2.0, 0.5 + EYE_CELL_SHAPE[0] / 2.0)
    rest_v = (0.5 - EYE_CELL_SHAPE[1] / 2.0, 0.5 + EYE_CELL_SHAPE[1] / 2.0)
    clamped, smeared = 0, []
    u_lo, u_hi, v_lo, v_hi = 1e9, -1e9, 1e9, -1e9
    for p in me.polygons:
        side = 1 if p.center.x >= 0.0 else -1
        c, out, up, n = eye_frame(side)
        us, vs, poly_clamped = [], [], False
        for li in p.loop_indices:
            d = me.vertices[me.loops[li].vertex_index].co - c
            u = 0.5 - d.dot(out) / w          # 0 on the outer edge, 1 on the inner
            v = 0.5 + d.dot(up) / h           # Blender v: 1 on the top edge
            us.append(u)
            vs.append(v)
            uc = min(1.0 - EYE_U_MARGIN, max(EYE_U_MARGIN, u))
            if uc != u:
                clamped += 1
                poly_clamped = True
            layer.data[li].uv = (uc * 0.5, v) if side > 0 else (1.0 - uc * 0.5, v)
        u_lo, u_hi, v_lo, v_hi = min(u_lo, *us), max(u_hi, *us), min(v_lo, *vs), max(v_hi, *vs)
        # a clamped polygon stretches the cell across itself: fine where the look draws black, wrong under the eye
        if poly_clamped and max(us) > rest_u[0] and min(us) < rest_u[1] and max(vs) > rest_v[0] and min(vs) < rest_v[1]:
            smeared.append(p.index)
    me.update()
    assert not smeared, "face polygons %s leave their half of the eye plate under the resting eye" % smeared
    print("STEWARD_EYEPLATE_OK polys=%d rect=%.2fx%.2f drawn=%.1fx%.1f u=[%.3f %.3f] v=[%.3f %.3f] clamped_loops=%d" % (
        len(me.polygons), w, h, EYE_DRAWN[0], EYE_DRAWN[1], u_lo, u_hi, v_lo, v_hi, clamped))


# ----------------------------------------------------------------------------------------------------------------
# 4. weights
# ----------------------------------------------------------------------------------------------------------------
def weights():
    """The face plate rigid on the head bone; the body's weights (the source auto-rig's) normalised."""
    arm, body, face = objects()
    for g in list(face.vertex_groups):
        face.vertex_groups.remove(g)
    face.vertex_groups.new(name=EYES_BONE).add(list(range(len(face.data.vertices))), 1.0, 'REPLACE')
    worst = 0
    for v in body.data.vertices:
        gs = [g for g in v.groups if g.weight > 0.0]
        total = sum(g.weight for g in gs)
        assert total > 0.0, "body vertex %d has no weight" % v.index
        worst = max(worst, len(gs))
        for g in gs:
            g.weight /= total
    names = {b.name for b in arm.data.bones}
    stray = [g.name for g in body.vertex_groups if g.name not in names]
    assert not stray, "body vertex groups without a bone: %s" % stray
    print("STEWARD_WEIGHTS_OK face=%s body_max_influences=%d" % (EYES_BONE, worst))


def face_node():
    """Where the eyes' face node sits: on the plate's keel, level with the eyes (armature space, cm)."""
    arm, body, face = objects()
    keel = sorted((v.co for v in face.data.vertices if abs(v.co.x) < 0.3 and v.co.y < -20.0), key=lambda c: c.z)
    below = [c for c in keel if c.z <= EYE_CENTRE.z][-1]
    above = [c for c in keel if c.z > EYE_CENTRE.z][0]
    t = (EYE_CENTRE.z - below.z) / (above.z - below.z)
    return Vector((0.0, below.y + (above.y - below.y) * t, EYE_CENTRE.z))


def face_report():
    """The numbers the Unreal side needs: the face node and the head bone it rides. Unreal's component space is this
    one with Y flipped (the steward faces +Y there, its left is +X)."""
    arm, body, face = objects()
    node = face_node()
    b = arm.data.bones[EYES_BONE]
    print("STEWARD_FACE node_blender=(%.2f, %.2f, %.2f) node_unreal=(%.2f, %.2f, %.2f) facing_unreal=+Y "
          "head_bone_blender=(%.2f, %.2f, %.2f)" % (*node, node.x, -node.y, node.z, *b.head_local))


# ----------------------------------------------------------------------------------------------------------------
# 5. the idle
# ----------------------------------------------------------------------------------------------------------------
def _basis(arm, bone, turns):
    """Pose-basis quaternion of `bone` for `turns` = [(armature-space axis, degrees), ...] applied in order on top of
    the rest pose (parents taken at rest: the idle's angles are small)."""
    q = Quaternion()
    for axis, deg in turns:
        q = Quaternion(Vector(axis).normalized(), radians(deg)) @ q
    rest = arm.data.bones[bone].matrix_local.to_quaternion()
    return rest.inverted() @ q @ rest


def idle_pose(t):
    """bone -> [(axis, degrees)] at phase t in [0, 1). Armature axes: +X the steward's left, -Y its front, +Z up.
    A turn about +X by a positive angle tips a bone's top backward (+Y... toward the back); about +Y it rolls the top
    toward -X (the steward's right); about +Z it yaws to the steward's right as seen from above."""
    breath = math.sin(2.0 * math.pi * 2.0 * t)                  # two breaths per loop (3 s each)
    lift = 0.5 - 0.5 * math.cos(2.0 * math.pi * 2.0 * t)        # 0 exhaled .. 1 inhaled
    sway = math.sin(2.0 * math.pi * t)                          # one slow sway per loop
    drift = math.sin(2.0 * math.pi * t + 1.1)
    X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
    pose = {
        "spine_01": [(Y, 0.35 * sway)],
        "spine_02": [(X, 0.45 * breath), (Y, 0.25 * sway)],
        "spine_03": [(X, 0.75 * breath)],
        "neck_01": [(X, -0.6 * breath), (Y, -0.4 * sway)],
        "head": [(Z, 2.2 * drift), (X, 1.0 * sway - 1.5), (Y, -0.5 * drift)],
    }
    for s, sx in (("l", 1.0), ("r", -1.0)):
        # the arms come in from the A-pose and hang a little forward; the shoulders rise with the breath
        pose["clavicle_" + s] = [(Y, -sx * 0.9 * lift)]
        pose["upperarm_" + s] = [(Y, sx * (9.0 - 0.6 * lift)), (X, -3.0)]
        pose["lowerarm_" + s] = [(X, -9.0 - 1.0 * breath), (Y, sx * 2.0)]
        pose["hand_" + s] = [(X, -4.0), (Y, sx * 3.0)]
    return pose


def build_idle():
    """`A_Steward_Idle`: in place (root and pelvis untouched, so the feet stay planted), frame 0 == frame 180."""
    arm, body, face = objects()
    old = bpy.data.actions.get(IDLE_ACTION)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(IDLE_ACTION)
    act.use_fake_user = True
    if not arm.animation_data:
        arm.animation_data_create()
    arm.animation_data.action = act
    slot = act.slots[0] if act.slots else act.slots.new('OBJECT', arm.name)
    arm.animation_data.action_slot = slot
    bones = sorted(idle_pose(0.0))
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        pb.location, pb.rotation_quaternion, pb.scale = (0, 0, 0), (1, 0, 0, 0), (1, 1, 1)
    prev = {}
    for f in range(0, IDLE_FRAMES + 1, IDLE_KEY_STEP):
        pose = idle_pose((f % IDLE_FRAMES) / IDLE_FRAMES)
        for name in bones:
            q = _basis(arm, name, pose[name])
            if name in prev and prev[name].dot(q) < 0.0:   # keep the keys on one side of the double cover
                q = -q
            prev[name] = q
            pb = arm.pose.bones[name]
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=f, group=name)
    fcurves = act.layers[0].strips[0].channelbags[0].fcurves
    for fc in fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = 'BEZIER'
            kp.handle_left_type = kp.handle_right_type = 'AUTO_CLAMPED'
        fc.update()
    loop = max(abs(fc.evaluate(0) - fc.evaluate(IDLE_FRAMES)) for fc in fcurves)
    assert loop < 1e-5, "the idle does not loop: %g" % loop
    # leave the rig at rest with the action unassigned: the scene is a build output, the action has a fake user
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.location, pb.rotation_quaternion, pb.scale = (0, 0, 0), (1, 0, 0, 0), (1, 1, 1)
    print("STEWARD_IDLE_OK action=%s frames=0..%d fps=%d bones=%d fcurves=%d loop_error=%g" % (
        act.name, IDLE_FRAMES, IDLE_FPS, len(bones), len(fcurves), loop))
    return act


# ----------------------------------------------------------------------------------------------------------------
# 6. export
# ----------------------------------------------------------------------------------------------------------------
class _ExportState:
    """Selects exactly `objs` with the rig active and renamed `Armature` (Unreal drops a node of that name, so the
    skeleton's root is the `root` bone); puts the selection, names, frame range, rate and action back after."""

    def __init__(self, arm, objs, action=None, frames=None):
        self.arm, self.objs, self.action, self.frames = arm, objs, action, frames

    def __enter__(self):
        vl, sc = bpy.context.view_layer, bpy.context.scene
        self.sel = [o for o in vl.objects if o.select_get()]
        self.active = vl.objects.active
        self.range = (sc.frame_start, sc.frame_end, sc.frame_current, sc.render.fps, sc.render.fps_base)
        self.other = bpy.data.objects.get("Armature")
        if self.other is not None and self.other is not self.arm:
            self.other.name = "__steward_other_armature"
        self.name = self.arm.name
        self.arm.name = "Armature"
        if not self.arm.animation_data:
            self.arm.animation_data_create()
        ad = self.arm.animation_data
        self.prev = (ad.action, ad.action_slot if ad.action else None)
        for o in vl.objects:
            o.select_set(o in self.objs)
        vl.objects.active = self.arm
        sc.render.fps, sc.render.fps_base = IDLE_FPS, 1.0
        if self.action is not None:
            ad.action = self.action
            ad.action_slot = self.action.slots[0]
            sc.frame_start, sc.frame_end = self.frames
        else:
            ad.action = None
        return self

    def __exit__(self, *exc):
        vl, sc = bpy.context.view_layer, bpy.context.scene
        self.arm.name = self.name
        if self.other is not None and self.other is not self.arm:
            self.other.name = "Armature"
        ad = self.arm.animation_data
        ad.action = self.prev[0]
        if self.prev[0] is not None and self.prev[1] is not None:
            ad.action_slot = self.prev[1]
        if self.prev[0] is None:
            for pb in self.arm.pose.bones:
                pb.location, pb.rotation_quaternion, pb.scale = (0, 0, 0), (1, 0, 0, 0), (1, 1, 1)
        for o in vl.objects:
            o.select_set(o in self.sel)
        vl.objects.active = self.active
        sc.frame_start, sc.frame_end = self.range[0], self.range[1]
        sc.render.fps, sc.render.fps_base = self.range[3], self.range[4]
        sc.frame_set(self.range[2])
        return False


def export():
    arm, body, face = objects()
    with _ExportState(arm, [arm, body, face]):
        bpy.ops.export_scene.fbx(filepath=FBX_MESH, object_types={'ARMATURE', 'MESH'}, bake_anim=False,
                                 mesh_smooth_type='FACE', use_tspace=False, **FBX_COMMON)
    print("STEWARD_EXPORT_OK", FBX_MESH, os.path.getsize(FBX_MESH))
    act = bpy.data.actions.get(IDLE_ACTION)
    if act is not None:
        with _ExportState(arm, [arm], act, (0, IDLE_FRAMES)):
            bpy.ops.export_scene.fbx(filepath=FBX_IDLE, object_types={'ARMATURE'}, bake_anim=True,
                                     bake_anim_use_all_bones=True, bake_anim_use_nla_strips=False,
                                     bake_anim_use_all_actions=False, bake_anim_force_startend_keying=True,
                                     bake_anim_step=1.0, bake_anim_simplify_factor=0.0, **FBX_COMMON)
        print("STEWARD_EXPORT_OK", FBX_IDLE, os.path.getsize(FBX_IDLE))
    zs = [v.co.z for v in body.data.vertices]
    node = face_node()
    w, h = eye_rect()
    side = {
        "height_cm": round(max(zs) - min(zs), 3),
        "eyes_bone": EYES_BONE,
        "eyes_slot": EYES_MATERIAL,
        "body_slot": BODY_MATERIAL,
        # Unreal component space: Blender's with Y flipped
        "face_node_unreal": [round(node.x, 3), round(-node.y, 3), round(node.z, 3)],
        "eye_rect_cm": [round(w, 3), round(h, 3)],
        "eye_drawn_cm": list(EYE_DRAWN),
        "idle": {"action": IDLE_ACTION, "frames": IDLE_FRAMES, "fps": IDLE_FPS} if act is not None else None,
    }
    with open(SIDECAR, "w", encoding="utf-8") as f:
        json.dump(side, f, indent=2)
    print("STEWARD_EXPORT_OK", SIDECAR)


def build():
    normalise()
    materials()
    build_eye_plate()
    weights()
    face_report()
    build_idle()
    print("STEWARD_BUILD_OK")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    build()
    if "--export" in args:
        export()
    if "--save" in args:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args[args.index("--save") + 1]), copy=True)
        print("STEWARD_SAVED", args[args.index("--save") + 1])
