"""Pantry Rat R01 - review map, editor-world captures and pocket depths (Phase 2). Runs inside the editor's Python through
Monolith `editor_query run_python` ({"command": "<this file> <stage> [args]", "mode": "execute_file", "unattended": true}),
never in PIE. Pattern: Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_review_ue.py (the map is opened / created
with LevelEditorSubsystem from run_python, never a console level load; only the review map is saved).

Stages:
  build             open/create /Game/ArtCandidates/PantryRat/R01/Review/PantryRat_R01_Review_MAP, replace every actor
                    this module placed, save the map (the CkJolt save hook writes /Game/CkJoltData/... for it)
  capture <set>     SceneCapture2D renders of the editor world to review/phase2/unreal/<name>.png
                    (set: all | neutral | amberteal | closeups)
  pockets           Pocket1..3 surface-to-socket depth on the real SM_PlayerBackpack (x1.25): Monolith-equivalent
                    collision ray (editor world line trace) + render-surface ray (GeometryScript on the mesh)
  restore <map>     load the level that was open before `build`
  readback          actor list + CPD per rat -> review/phase2/unreal/review_map_readback.json
Prints PANTRY_RAT_OK / PANTRY_RAT_FAIL.
"""
import json
import math
import os
import sys
import time
import traceback

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(HERE)
OUT = os.path.join(ROOT_DIR, "review", "phase2", "unreal")
REVIEW_MAP = "/Game/ArtCandidates/PantryRat/R01/Review/PantryRat_R01_Review_MAP"
PREFIX = "PantryRatReview_"
TAG = "PantryRatR01Review"
R = "/Game/ArtCandidates/PantryRat/R01"
SK = R + "/Meshes/PantryRat_R01_Mars_SK"
DEN = R + "/Props/PantryRat_R01_Den_Mars_SM"
PLATE = R + "/Props/PantryRat_R01_DenEyePlate_Mars_SM"
CHEESE = R + "/Props/PantryRat_R01_Cheese_Mars_SM"
ANIM = R + "/Animation/PantryRat_R01_%s_Mars_ANIM"
SHARED_EYE = "/Game/Mars/Materials/GeneratedLooks/M_CkUsf_Look_MarsEyePlate"
BACKPACK = "/Game/Mars/Gameplay/PlayerBackpack/Meshes/SM_PlayerBackpack"
MUSHROOM = "/Game/Mars/Gameplay/Cooking/Food/Meshes/Mushroom_Prep_Mars_SM"
CUBE = "/Engine/BasicShapes/Cube.Cube"
PROTOGRID = "/Game/Mars/Materials/ProtoGrid/ProtoGrid_%s_Mars_MI"
CUBEMAP = "/Engine/MapTemplates/Sky/DaylightAmbientCubemap"
SUN_LUX, SKY_INTENSITY = 3.0, 0.5                          # the cellar bat review rig
AMBER = ((1.0, 0.55, 0.2), 8000.0, (250.0, 150.0, 300.0))
TEAL = ((0.2, 0.7, 0.8), 2500.0, (-300.0, -250.0, 150.0))
AMBER_EYE = (1.0, 0.78, 0.45, 1.0)

# eye CPD 0..13 (constants_eyes layout): cells L R PrevL PrevR | Blend BlinkL BlinkR Strength | LookX LookY | rgba
def eye_cpd(left, right, strength=6.0, look=(0.0, 0.0)):
    return [float(left), float(right), float(left), float(right), 1.0, 0.0, 0.0, strength, look[0], look[1]] + list(AMBER_EYE)


# static review rats: label -> (location, yaw, cpd list (15 floats unless 'unset14'), note)
RATS = {
    "Rat_Alpha1": ((100.0, -225.0, 0.0), 0.0, eye_cpd(2, 2) + [1.0], "solid, round-dot eyes"),
    "Rat_Alpha05": ((100.0, -135.0, 0.0), 0.0, eye_cpd(2, 2) + [0.5], "half faded; real mushroom beside it"),
    "Rat_Alpha0": ((100.0, -45.0, 0.0), 0.0, eye_cpd(2, 2) + [0.0], "gone"),
    "Rat_XEyes": ((100.0, 45.0, 0.0), 0.0, eye_cpd(20, 20) + [1.0], "dead face: X cells 20/20, LookX 0, blink 0"),
    "Rat_Asym": ((100.0, 135.0, 0.0), 0.0, eye_cpd(2, 19) + [1.0], "left cell 2 (dot), right cell 19 (wide)"),
    "Rat_Cpd14Unset": ((100.0, 225.0, 0.0), 0.0, eye_cpd(2, 2), "CPD written 0..13 only: what an unseeded slot 14 reads"),
}
PLAYBACK = ("BoundCycle", "Rummage", "Snatch", "LoadedBound", "DeathToppleLeft", "DeadHold", "DenEmerge")
PLAYBACK_Y = -480.0
CAMERAS = {   # label -> (location, (pitch, yaw), fov)
    "Cam_Overview": ((420.0, 0.0, 150.0), (-14.0, 180.0), 70.0),
    "Cam_Playback": ((0.0, -880.0, 70.0), (-4.0, 90.0), 65.0),
}
DEN_LOC, DEN_YAW = (300.0, 430.0, 0.0), 0.0             # den local +X (out of the den) -> world +X, toward the sun side
PACK_LOC, PACK_YAW, PACK_SCALE = (-300.0, 0.0, 0.0), 180.0, 1.25


def _err(e):
    return "%s: %s\n%s" % (type(e).__name__, e, traceback.format_exc())


def _les():
    return unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)


def _eas():
    return unreal.get_editor_subsystem(unreal.EditorActorSubsystem)


def _world():
    return unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()


def _world_package():
    w = _world()
    return w.get_outermost().get_name() if w else None


def _pie():
    return unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).is_in_play_in_editor()


def _v(x):
    return unreal.Vector(float(x[0]), float(x[1]), float(x[2]))


def _rot(yaw=0.0, pitch=0.0, roll=0.0):
    return unreal.Rotator(roll=roll, pitch=pitch, yaw=yaw)


def _tag(a, label):
    a.set_actor_label(PREFIX + label)
    a.set_editor_property("tags", [unreal.Name(TAG)])
    return a


def _sm_actor(label, mesh, loc, yaw=0.0, scale=1.0, mats=None):
    a = _eas().spawn_actor_from_class(unreal.StaticMeshActor, _v(loc), _rot(yaw))
    c = a.static_mesh_component
    c.set_static_mesh(unreal.load_asset(mesh))
    a.set_actor_scale3d(unreal.Vector(scale, scale, scale))
    for i, m in enumerate(mats or []):
        if m:
            c.set_material(i, unreal.load_asset(m))
    return _tag(a, label)


def _block(label, centre, size, look):
    a = _sm_actor(label, CUBE, centre, mats=[PROTOGRID % look])
    a.set_actor_scale3d(unreal.Vector(size[0] * 0.01, size[1] * 0.01, size[2] * 0.01))
    a.static_mesh_component.set_collision_profile_name("BlockAll")
    return a


def _set_cpd(comp, values):
    cpd = unreal.CustomPrimitiveData()
    cpd.set_editor_property("data", [float(x) for x in values])
    comp.set_editor_property("custom_primitive_data", cpd)
    for i, x in enumerate(values):   # the runtime copy too (editor render this session)
        comp.set_custom_primitive_data_float(i, float(x))


def _rat(label, loc, yaw, anim=None):
    a = _eas().spawn_actor_from_class(unreal.SkeletalMeshActor, _v(loc), _rot(yaw))
    c = a.skeletal_mesh_component
    c.set_skeletal_mesh_asset(unreal.load_asset(SK))
    if anim:
        c.set_animation_mode(unreal.AnimationMode.ANIMATION_SINGLE_NODE)
        d = c.get_editor_property("animation_data")
        d.set_editor_property("anim_to_play", unreal.load_asset(ANIM % anim))
        d.set_editor_property("saved_looping", True)
        d.set_editor_property("saved_playing", True)
        d.set_editor_property("saved_position", 0.0)
        d.set_editor_property("saved_play_rate", 1.0)
        c.set_editor_property("animation_data", d)
    return _tag(a, label)


def _attach_mushroom(label, rat):
    m = _sm_actor(label, MUSHROOM, (0, 0, 0))
    m.static_mesh_component.set_collision_profile_name("NoCollision")
    m.attach_to_component(rat.skeletal_mesh_component, "Carry_Mouth", unreal.AttachmentRule.SNAP_TO_TARGET,
                          unreal.AttachmentRule.SNAP_TO_TARGET, unreal.AttachmentRule.KEEP_WORLD, False)
    return m


def _place():
    out = {}
    _block("Floor", (0.0, 0.0, -10.0), (1800.0, 1600.0, 20.0), "Floor")
    _block("WallNorth", (0.0, 820.0, 200.0), (1800.0, 40.0, 400.0), "Wall")
    _block("WallWest", (-920.0, 0.0, 200.0), (40.0, 1600.0, 400.0), "Wall")
    den = _sm_actor("Den", DEN, DEN_LOC, DEN_YAW)
    plate = _sm_actor("DenEyePlate", PLATE, DEN_LOC, DEN_YAW, mats=[SHARED_EYE])
    _set_cpd(plate.static_mesh_component, eye_cpd(19, 19))     # 19/19 wide, strength 6, amber; opaque shared master
    plate.static_mesh_component.set_collision_profile_name("NoCollision")
    _sm_actor("Cheese", CHEESE, (380.0, 330.0, 0.0), 30.0)
    _sm_actor("Backpack", BACKPACK, PACK_LOC, PACK_YAW, PACK_SCALE)
    rats = {}
    for label, (loc, yaw, cpd, note) in RATS.items():
        a = _rat(label, loc, yaw)
        _set_cpd(a.skeletal_mesh_component, cpd)
        rats[label] = a
    mloc = RATS["Rat_Alpha05"][0]
    _sm_actor("Mushroom_BesideFadingRat", MUSHROOM, (mloc[0] + 34.0, mloc[1] + 30.0, 0.0), 20.0)
    for i, clip in enumerate(PLAYBACK):
        a = _rat("Play_" + clip, (-300.0 + i * 100.0, PLAYBACK_Y, 0.0), 0.0, clip)
        _set_cpd(a.skeletal_mesh_component, (eye_cpd(20, 20) if clip in ("DeathToppleLeft", "DeadHold") else eye_cpd(2, 2)) + [1.0])
        if clip in ("Snatch", "LoadedBound"):
            _attach_mushroom("Play_%s_Mushroom" % clip, a)
    start = _eas().spawn_actor_from_class(unreal.PlayerStart, unreal.Vector(-700.0, 600.0, 100.0), _rot(-45.0))
    _tag(start, "PlayerStart")
    # lights (cellar bat review rig) - movable, so the editor world renders them without a lighting build
    sun = _eas().spawn_actor_from_class(unreal.DirectionalLight, unreal.Vector(0.0, 0.0, 500.0), _rot(-150.0, -45.0))
    _tag(sun, "NeutralSun")
    lc = sun.get_component_by_class(unreal.DirectionalLightComponent)
    lc.set_mobility(unreal.ComponentMobility.MOVABLE)
    lc.set_intensity(SUN_LUX)
    sky = _eas().spawn_actor_from_class(unreal.SkyLight, unreal.Vector(0.0, 0.0, 300.0), _rot())
    _tag(sky, "NeutralSky")
    sc = sky.get_component_by_class(unreal.SkyLightComponent)
    sc.set_mobility(unreal.ComponentMobility.MOVABLE)
    sc.set_editor_property("source_type", unreal.SkyLightSourceType.SLS_SPECIFIED_CUBEMAP)
    sc.set_editor_property("cubemap", unreal.load_asset(CUBEMAP))
    sc.set_intensity(SKY_INTENSITY)
    for label, (colour, cd, loc) in (("AmberLight", AMBER), ("TealLight", TEAL)):
        p = _eas().spawn_actor_from_class(unreal.PointLight, _v(loc), _rot())
        _tag(p, label)
        pc = p.get_component_by_class(unreal.PointLightComponent)
        pc.set_mobility(unreal.ComponentMobility.MOVABLE)
        pc.set_editor_property("intensity_units", unreal.LightUnits.CANDELAS)
        pc.set_intensity(cd)
        pc.set_light_color(unreal.LinearColor(r=colour[0], g=colour[1], b=colour[2], a=1.0))
        pc.set_attenuation_radius(1500.0)
    for label, (loc, (pitch, yaw), fov) in CAMERAS.items():
        cam = _eas().spawn_actor_from_class(unreal.CameraActor, _v(loc), _rot(yaw, pitch))
        _tag(cam, label)
        cc = cam.get_component_by_class(unreal.CameraComponent)
        cc.set_editor_property("field_of_view", fov)
        cc.set_editor_property("constrain_aspect_ratio", False)
    ppv = _eas().spawn_actor_from_class(unreal.PostProcessVolume, unreal.Vector(0.0, 0.0, 300.0), _rot())
    _tag(ppv, "Exposure")
    ppv.set_editor_property("unbound", True)
    st = ppv.get_editor_property("settings")
    st.set_editor_property("override_auto_exposure_bias", True)
    st.set_editor_property("auto_exposure_bias", -1.0)
    ppv.set_editor_property("settings", st)
    out["actors"] = sorted(a.get_actor_label() for a in _eas().get_all_level_actors() if a.actor_has_tag(TAG))
    return out


def build():
    if _pie():
        return {"error": "PIE is running"}
    res = {"map": REVIEW_MAP, "previous_level": _world_package(), "created": False, "deleted": 0, "saved": False,
           "error": None}
    try:
        if _world_package() != REVIEW_MAP:
            if unreal.EditorAssetLibrary.does_asset_exist(REVIEW_MAP):
                ok = _les().load_level(REVIEW_MAP)
            else:
                ok = _les().new_level(REVIEW_MAP, False)
                res["created"] = True
            if not ok or _world_package() != REVIEW_MAP:
                res["error"] = "could not open %s (current %s)" % (REVIEW_MAP, _world_package())
                return res
        for a in list(_eas().get_all_level_actors()):
            if a.actor_has_tag(TAG) or a.get_actor_label().startswith(PREFIX):
                _eas().destroy_actor(a)
                res["deleted"] += 1
        res.update(_place())
        res["saved"] = bool(_les().save_current_level())
    except Exception as e:
        res["error"] = _err(e)
    return res


def restore(path):
    if _pie():
        return {"error": "PIE is running"}
    try:
        return {"loaded": bool(_les().load_level(path)), "current_level": _world_package(), "error": None}
    except Exception as e:
        return {"loaded": False, "error": _err(e)}


def _actor(label):
    for a in _eas().get_all_level_actors():
        if a.get_actor_label() == PREFIX + label:
            return a
    return None


def _lights(mode):
    on = {"neutral": ("NeutralSun", "NeutralSky"), "amberteal": ("AmberLight", "TealLight", "NeutralSky"),
          "all": ("NeutralSun", "NeutralSky", "AmberLight", "TealLight")}[mode]
    for n in ("NeutralSun", "NeutralSky", "AmberLight", "TealLight"):
        a = _actor(n)
        comp = a.get_component_by_class(unreal.LightComponentBase)
        comp.set_visibility(n in on)
    sky = _actor("NeutralSky").get_component_by_class(unreal.SkyLightComponent)
    sky.set_intensity(SKY_INTENSITY if mode != "amberteal" else 0.12)


def _look(eye, target):
    d = unreal.Vector(target[0] - eye[0], target[1] - eye[1], target[2] - eye[2])
    return unreal.MathLibrary.make_rot_from_x(d)


def _capture(name, eye, target, fov=50.0, w=1280, h=800, bias=0.0):
    os.makedirs(OUT, exist_ok=True)
    world = _world()
    rt = unreal.RenderingLibrary.create_render_target2d(world, w, h, unreal.TextureRenderTargetFormat.RTF_RGBA8_SRGB)
    cap = _eas().spawn_actor_from_class(unreal.SceneCapture2D, _v(eye), _look(eye, target))
    try:
        c = cap.capture_component2d
        c.set_editor_property("fov_angle", fov)
        c.set_editor_property("texture_target", rt)
        c.set_editor_property("capture_source", unreal.SceneCaptureSource.SCS_FINAL_COLOR_LDR)
        c.set_editor_property("capture_every_frame", False)
        pp = c.get_editor_property("post_process_settings")
        pp.set_editor_property("override_auto_exposure_method", True)
        pp.set_editor_property("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL)
        pp.set_editor_property("override_auto_exposure_bias", True)
        pp.set_editor_property("auto_exposure_bias", bias)
        pp.set_editor_property("override_auto_exposure_apply_physical_camera_exposure", True)
        pp.set_editor_property("auto_exposure_apply_physical_camera_exposure", False)
        c.set_editor_property("post_process_settings", pp)
        c.capture_scene()
        unreal.RenderingLibrary.export_render_target(world, rt, OUT, name + ".png")
    finally:
        _eas().destroy_actor(cap)
    return os.path.join(OUT, name + ".png")


def _rat_head(label, up=25.0, fwd=15.0):
    loc = RATS[label][0] if label in RATS else None
    return (loc[0] + fwd, loc[1], up)


def capture(which="all"):
    if _pie():
        return {"error": "PIE is running"}
    if _world_package() != REVIEW_MAP:
        return {"error": "review map not open (current %s)" % _world_package()}
    shots = []
    if which in ("all", "neutral", "amberteal"):
        for mode, bias in (("neutral", 0.0), ("amberteal", -4.0)):
            if which not in ("all", mode):
                continue
            _lights(mode)
            shots.append(_capture("row_%s" % mode, (420.0, 40.0, 120.0), (100.0, 0.0, 20.0), 70.0, bias=bias))
            shots.append(_capture("den_%s" % mode, (470.0, 400.0, 45.0), (300.0, 430.0, 24.0), 55.0, bias=bias))
            shots.append(_capture("playback_row_%s" % mode, (0.0, -880.0, 70.0), (0.0, PLAYBACK_Y, 20.0), 65.0, bias=bias))
    if which in ("all", "closeups"):
        _lights("neutral")
        for label in RATS:
            x, y, _z = RATS[label][0]
            shots.append(_capture("close_%s" % label, (x + 95.0, y + 30.0, 45.0), (x + 12.0, y, 24.0), 40.0, bias=-1.0))
        x, y, _z = RATS["Rat_Alpha05"][0]
        shots.append(_capture("close_Alpha05_with_mushroom", (x + 120.0, y + 70.0, 50.0), (x + 15.0, y + 15.0, 15.0), 45.0))
        # side views from the open side (Alpha0 next door renders nothing; Alpha1 is the end of the row)
        x, y, _z = RATS["Rat_Alpha05"][0]
        shots.append(_capture("side_Rat_Alpha05", (x - 8.0, y + 85.0, 20.0), (x - 8.0, y, 15.0), 60.0, bias=-0.5))
        x, y, _z = RATS["Rat_Alpha1"][0]
        shots.append(_capture("side_Rat_Alpha1", (x - 8.0, y - 85.0, 20.0), (x - 8.0, y, 15.0), 60.0, bias=-0.5))
        shots.append(_capture("eyes_front_XEyes", (RATS["Rat_XEyes"][0][0] + 60.0, RATS["Rat_XEyes"][0][1], 28.0),
                              (RATS["Rat_XEyes"][0][0] + 15.0, RATS["Rat_XEyes"][0][1], 24.0), 35.0, bias=-2.0))
        shots.append(_capture("eyes_front_Alpha05", (RATS["Rat_Alpha05"][0][0] + 60.0, RATS["Rat_Alpha05"][0][1], 28.0),
                              (RATS["Rat_Alpha05"][0][0] + 15.0, RATS["Rat_Alpha05"][0][1], 24.0), 35.0, bias=-2.0))
        shots.append(_capture("eyes_front_Asym", (RATS["Rat_Asym"][0][0] + 60.0, RATS["Rat_Asym"][0][1], 28.0),
                              (RATS["Rat_Asym"][0][0] + 15.0, RATS["Rat_Asym"][0][1], 24.0), 35.0, bias=-2.0))
    _lights("all")
    return {"shots": [os.path.relpath(s, ROOT_DIR).replace("\\", "/") for s in shots]}


def pockets():
    if _world_package() != REVIEW_MAP:
        return {"error": "review map not open"}
    pack = _actor("Backpack")
    mesh = unreal.load_asset(BACKPACK)
    T = pack.get_actor_transform()
    out = {"pack_world": [T.translation.x, T.translation.y, T.translation.z], "yaw": PACK_YAW, "scale": PACK_SCALE,
           "collision_trace_flag": str(mesh.get_editor_property("body_setup").get_editor_property("collision_trace_flag")),
           "pockets": {}}
    # render surface: GeometryScript ray against the mesh triangles (mesh space, scaled by the actor transform)
    dm = unreal.DynamicMesh()
    unreal.GeometryScript_AssetUtils.copy_mesh_from_static_mesh(mesh, dm, unreal.GeometryScriptCopyMeshFromAssetOptions(),
                                                               unreal.GeometryScriptMeshReadLOD())
    unreal.GeometryScript_MeshTransforms.transform_mesh(dm, T)
    bvh = unreal.GeometryScript_MeshSpatial.build_bvh_for_mesh(dm)
    bvh = [e for e in bvh if isinstance(e, unreal.GeometryScriptDynamicMeshBVH)][0] if isinstance(bvh, tuple) else bvh
    for n in ("Pocket1", "Pocket2", "Pocket3"):
        s = mesh.find_socket(n)
        sl = unreal.Transform(location=s.relative_location, rotation=s.relative_rotation,
                              scale=unreal.Vector(1, 1, 1))
        sw = unreal.MathLibrary.compose_transforms(sl, T).translation
        outward = T.rotation.rotate_vector(unreal.Vector(-1.0, 0.0, 0.0))   # the pocket face is the mesh's -X side
        start = sw + outward * 60.0
        end = sw - outward * 5.0
        hit = unreal.SystemLibrary.line_trace_single(_world(), start, end, unreal.TraceTypeQuery.TRACE_TYPE_QUERY1,
                                                     False, [], unreal.DrawDebugTrace.NONE, True)
        r = {"socket_world": [round(sw.x, 3), round(sw.y, 3), round(sw.z, 3)], "ray_start": [round(start.x, 3), round(start.y, 3), round(start.z, 3)]}
        if isinstance(hit, tuple):
            ok, h = hit[0], hit[1]
        else:
            h = hit
            ok = h is not None
        if ok and h is not None:
            t = h.to_tuple()
            loc = t[4]
            act = t[9]
            r["collision_hit"] = [round(loc.x, 3), round(loc.y, 3), round(loc.z, 3)]
            r["collision_hit_actor"] = act.get_actor_label() if act else None
            r["collision_ray_distance_cm"] = round(float(t[3]), 3)
            r["collision_depth_cm"] = round((loc - sw).length(), 3)
        else:
            r["collision_hit"] = None
        opts = unreal.GeometryScriptSpatialQueryOptions()
        ray = unreal.Ray(origin=start, direction=(end - start).normal())
        q = unreal.GeometryScript_MeshSpatial.find_nearest_ray_intersection_with_mesh(dm, bvh, start, (end - start).normal(), opts)
        res = [e for e in (q if isinstance(q, tuple) else (q,)) if isinstance(e, unreal.GeometryScriptRayHitResult)]
        if res and res[0].get_editor_property("hit"):
            hp = res[0].get_editor_property("hit_position")
            r["render_hit"] = [round(hp.x, 3), round(hp.y, 3), round(hp.z, 3)]
            r["render_surface_to_socket_cm"] = round((hp - sw).length(), 3)
        else:
            r["render_hit"] = None
        out["pockets"][n] = r
    return out


def readback():
    out = {"map": _world_package(), "actors": {}}
    for a in _eas().get_all_level_actors():
        if not a.actor_has_tag(TAG):
            continue
        r = {"class": a.get_class().get_name(), "loc": [round(x, 2) for x in (a.get_actor_location().x, a.get_actor_location().y,
                                                                            a.get_actor_location().z)]}
        comp = a.get_component_by_class(unreal.PrimitiveComponent)
        if comp is not None:
            try:
                r["cpd_defaults"] = [round(x, 3) for x in comp.get_editor_property("custom_primitive_data").get_editor_property("data")]
            except Exception:
                pass
        if isinstance(a, unreal.SkeletalMeshActor):
            c = a.skeletal_mesh_component
            d = c.get_editor_property("animation_data")
            ap = d.get_editor_property("anim_to_play")
            r["anim"] = ap.get_name() if ap else None
            r["mode"] = str(c.get_editor_property("animation_mode"))
            r["materials"] = [m.get_name() if m else None for m in c.get_materials()]
        out["actors"][a.get_actor_label()] = r
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "review_map_readback.json"), "w") as fh:
        json.dump(out, fh, indent=1)
    return out


def main(argv):
    stage = argv[1] if len(argv) > 1 else "readback"
    t0 = time.time()
    try:
        if stage == "build":
            rep = build()
        elif stage == "capture":
            rep = capture(argv[2] if len(argv) > 2 else "all")
        elif stage == "pockets":
            rep = pockets()
        elif stage == "restore":
            rep = restore(argv[2])
        elif stage == "readback":
            rep = readback()
        else:
            raise ValueError(stage)
    except Exception as e:
        rep = {"error": _err(e)}
    rep["seconds"] = round(time.time() - t0, 2)
    rep = json.loads(json.dumps(rep, default=str))
    p = os.path.join(OUT, "review_stages.json")
    os.makedirs(OUT, exist_ok=True)
    data = json.load(open(p)) if os.path.exists(p) else {}
    data[stage] = rep
    with open(p, "w") as fh:
        json.dump(data, fh, indent=1)
    print("PANTRY_RAT_REVIEW " + json.dumps(rep)[:12000])
    print("PANTRY_RAT_OK" if not rep.get("error") else "PANTRY_RAT_FAIL")


main(sys.argv)
