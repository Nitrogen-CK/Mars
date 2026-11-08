"""Pantry Rat R02 - Phase 5 copy of ../pantry_rat_r01/scripts/pantry_rat_court_ue.py (Phase 4 court; the PIE story driver
unchanged, plus a rat-relative framing schedule `frame_start` and the dither slow-motion helper). Phase 4 court: review map build and the PIE story driver. Runs inside the editor's Python through
Monolith `editor_query run_python` (build / restore / readback, never in PIE) and as `capture_pie_movement_clip`
python_script / probe_scripts (story, inside PIE). Pattern: pantry_rat_review_ue.py (Phase 2) and
Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_review_ue.py (the map is opened / created with LevelEditorSubsystem,
never a console level load; only the court map is saved).

The court is /Game/ArtCandidates/PantryRat/R01/Review/PantryRat_R01_Court_MAP: a 2100 x 1500 ProtoGrid floor with 120 cm
walls, two obstacles (crates the chase goes round), the player start, lights, review cameras and ONE placed AngelScript
director (UMars_PantryRatCourt_EntityScript, Script/WorldObjects/Monsters/Mars_PantryRatReview.as) that composes the nav
field, the raid, the den, the cheese pack (Mushroom in slot 1, Monk's Rind in slot 2) and the chef bot. World settings use
Mars_Gameplay_GameMode (the player character).

Stages (run_python execute_file "<this file> <stage>"): build | restore <map> | readback
In PIE: import pantry_rat_court_ue as m; m.story_start("theft"|"return"|"chase"); the story advances on its own each tick
and logs PANTRYRAT_STORY lines; m.follow_start() keeps the review camera on the rat.
Prints PANTRY_RAT_OK / PANTRY_RAT_FAIL from the stages.
"""
import json
import math
import os
import sys
import traceback

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(HERE)
OUT = os.path.join(ROOT_DIR, "review", "phase9")
COURT_MAP = "/Game/ArtCandidates/PantryRat/R01/Review/PantryRat_R01_Court_MAP"
PREFIX = "PantryRatCourt_"
TAG = "PantryRatR01Court"
AS = "/Script/Angelscript."
DIRECTOR = AS + "Mars_PantryRatCourt_EntityScript"
GAME_MODE = AS + "Mars_Gameplay_GameMode"
CUBE = "/Engine/BasicShapes/Cube.Cube"
PROTOGRID = "/Game/Mars/Materials/ProtoGrid/ProtoGrid_%s_Mars_MI"
CUBEMAP = "/Engine/MapTemplates/Sky/DaylightAmbientCubemap"
SUN_LUX, SKY_INTENSITY = 3.0, 0.5

HALF_X, HALF_Y, WALL_H, WALL_T = 1050.0, 750.0, 120.0, 40.0
OBSTACLES = {"CrateNorth": ((0.0, 330.0), (200.0, 140.0, 100.0)), "CrateSouth": ((0.0, -330.0), (200.0, 140.0, 100.0))}
PLAYER_START = ((900.0, -550.0, 100.0), 150.0)
CAMERAS = {   # label -> (location, look-at, fov)
    "Cam_Overview": ((0.0, -1250.0, 1500.0), (0.0, -60.0, 0.0), 70.0),
    "Cam_Follow": ((0.0, -400.0, 250.0), (0.0, 0.0, 0.0), 55.0),
}


def _err(e):
    return "%s: %s\n%s" % (type(e).__name__, e, traceback.format_exc())


def _les():
    return unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)


def _eas():
    return unreal.get_editor_subsystem(unreal.EditorActorSubsystem)


def _world():
    return unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()


def _game_world():
    return unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_game_world()


def _world_package():
    w = _world()
    return w.get_outermost().get_name() if w else None


def _pie():
    return _les().is_in_play_in_editor()


def _v(x):
    return unreal.Vector(float(x[0]), float(x[1]), float(x[2]))


def _rot(yaw=0.0, pitch=0.0, roll=0.0):
    return unreal.Rotator(roll=roll, pitch=pitch, yaw=yaw)


def _tag(a, label):
    a.set_actor_label(PREFIX + label)
    a.set_editor_property("tags", [unreal.Name(TAG)])
    return a


def _block(label, centre, size, look):
    a = _eas().spawn_actor_from_class(unreal.StaticMeshActor, _v(centre), _rot())
    c = a.static_mesh_component
    c.set_static_mesh(unreal.load_asset(CUBE))
    a.set_actor_scale3d(unreal.Vector(size[0] * 0.01, size[1] * 0.01, size[2] * 0.01))
    c.set_collision_profile_name("BlockAll")
    mi = unreal.load_asset(PROTOGRID % look)
    if mi:
        c.set_material(0, mi)
    return _tag(a, label)


def _look(eye, target):
    return unreal.MathLibrary.find_look_at_rotation(_v(eye), _v(target))


def _place():
    sx, sy = HALF_X * 2.0 + WALL_T * 2.0, HALF_Y * 2.0 + WALL_T * 2.0
    _block("Floor", (0.0, 0.0, -10.0), (sx + 400.0, sy + 400.0, 20.0), "Floor")
    wz = WALL_H * 0.5
    _block("WallNorth", (0.0, HALF_Y + WALL_T * 0.5, wz), (sx, WALL_T, WALL_H), "Wall")
    _block("WallSouth", (0.0, -HALF_Y - WALL_T * 0.5, wz), (sx, WALL_T, WALL_H), "Wall")
    _block("WallEast", (HALF_X + WALL_T * 0.5, 0.0, wz), (WALL_T, sy, WALL_H), "Wall")
    _block("WallWest", (-HALF_X - WALL_T * 0.5, 0.0, wz), (WALL_T, sy, WALL_H), "Wall")
    for label, ((x, y), size) in OBSTACLES.items():
        _block(label, (x, y, size[2] * 0.5), size, "Platform")

    cls = unreal.load_class(None, DIRECTOR)
    if cls is None:
        raise RuntimeError("AngelScript class %s is not loaded (does the script compile?)" % DIRECTOR)
    d = _eas().spawn_actor_from_object(cls, unreal.Vector(0.0, 0.0, 0.0), _rot())
    if d is None:
        raise RuntimeError("the entity spawner factory placed nothing for %s" % DIRECTOR)
    _tag(d, "Director")

    loc, yaw = PLAYER_START
    _tag(_eas().spawn_actor_from_class(unreal.PlayerStart, _v(loc), _rot(yaw)), "PlayerStart")

    sun = _eas().spawn_actor_from_class(unreal.DirectionalLight, unreal.Vector(0.0, 0.0, 500.0), _rot(-150.0, -50.0))
    _tag(sun, "Sun")
    lc = sun.get_component_by_class(unreal.DirectionalLightComponent)
    lc.set_mobility(unreal.ComponentMobility.MOVABLE)
    lc.set_intensity(SUN_LUX)
    sky = _eas().spawn_actor_from_class(unreal.SkyLight, unreal.Vector(0.0, 0.0, 300.0), _rot())
    _tag(sky, "Sky")
    sc = sky.get_component_by_class(unreal.SkyLightComponent)
    sc.set_mobility(unreal.ComponentMobility.MOVABLE)
    sc.set_editor_property("source_type", unreal.SkyLightSourceType.SLS_SPECIFIED_CUBEMAP)
    sc.set_editor_property("cubemap", unreal.load_asset(CUBEMAP))
    sc.set_intensity(SKY_INTENSITY)
    for label, (loc, target, fov) in CAMERAS.items():
        cam = _eas().spawn_actor_from_class(unreal.CameraActor, _v(loc), _look(loc, target))
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

    ws = _world().get_world_settings()
    gm = unreal.load_class(None, GAME_MODE)
    ws.set_editor_property("default_game_mode", gm)
    return sorted(a.get_actor_label() for a in _eas().get_all_level_actors() if a.actor_has_tag(TAG))


def build():
    if _pie():
        return {"error": "PIE is running"}
    res = {"map": COURT_MAP, "previous_level": _world_package(), "created": False, "deleted": 0, "saved": False, "error": None}
    try:
        if _world_package() != COURT_MAP:
            if unreal.EditorAssetLibrary.does_asset_exist(COURT_MAP):
                ok = _les().load_level(COURT_MAP)
            else:
                ok = _les().new_level(COURT_MAP, False)
                res["created"] = True
            if not ok or _world_package() != COURT_MAP:
                res["error"] = "could not open %s (current %s)" % (COURT_MAP, _world_package())
                return res
        for a in list(_eas().get_all_level_actors()):
            if a.actor_has_tag(TAG) or a.get_actor_label().startswith(PREFIX):
                _eas().destroy_actor(a)
                res["deleted"] += 1
        res["actors"] = _place()
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


def readback():
    rows = []
    for a in _eas().get_all_level_actors():
        if not a.actor_has_tag(TAG):
            continue
        loc, scl = a.get_actor_location(), a.get_actor_scale3d()
        rows.append({"label": a.get_actor_label(), "class": a.get_class().get_name(),
                     "location": [round(loc.x, 1), round(loc.y, 1), round(loc.z, 1)],
                     "scale": [round(scl.x, 3), round(scl.y, 3), round(scl.z, 3)]})
    gm = _world().get_world_settings().get_editor_property("default_game_mode")
    return {"level": _world_package(), "game_mode": gm.get_name() if gm else None, "count": len(rows),
            "actors": sorted(rows, key=lambda r: r["label"])}


# ---------------------------------------------------------------------------------------------------------------------
# PIE: the director, the story driver and the follow camera
# ---------------------------------------------------------------------------------------------------------------------

DEAD = ("Dying", "LootReleasePending", "DeadHold", "CorpseFade", "Destroyed", "BlockedCleanup")
LOADED = ("CarryMountPending", "FleeWithLoot", "FleePause", "FleeCornered")
_story = {"handle": None}
_follow = {"handle": None}


def director():
    cls = unreal.load_class(None, DIRECTOR)
    if cls is None:
        return None
    live = [o for o in unreal.ObjectIterator(cls) if "UEDPIE" in o.get_path_name()]
    for o in live:
        try:
            if o.call_method("Review_IsComposed"):
                return o
        except Exception:
            pass
    return None


def _log(text):
    unreal.log("PANTRYRAT_STORY %s" % text)


def _call(name, args=()):
    d = _story.get("director") or director()
    _story["director"] = d
    return d.call_method(name, args) if d else None


def _phase():
    return str(_call("Review_RatPhase"))


def _set(state):
    _story["state"] = state
    _story["since"] = _story["clock"]
    _log("t=%.2f state %s | %s" % (_story["clock"], state, _call("Review_Describe")))


def _story_tick(delta):
    st = _story
    if _game_world() is None:
        story_stop("pie ended")
        return
    try:
        st["clock"] += delta
        age = st["clock"] - st["since"]
        s, kind = st["state"], st["kind"]
        phase = _phase()
        if st["clock"] >= st["next_describe"]:
            st["next_describe"] = st["clock"] + 2.0
            _log("t=%.2f %s" % (st["clock"], _call("Review_Describe")))
        if phase != st.get("last_phase"):
            _log("t=%.2f rat phase %s -> %s" % (st["clock"], st.get("last_phase"), phase))
            st["last_phase"] = phase
        ready = bool(_call("Review_IsReady"))
        pack = _call("Review_PackLocation")
        if s == "wait_ready":
            if ready:
                _call("Review_GiveCleaver")
                if kind in ("theft", "return"):
                    _call("Review_BotWalkTo", (unreal.Vector(pack.x + 130.0, pack.y - 60.0, pack.z), 25.0))
                    _set("guard_walk")
                else:
                    _set("chase_wait_loaded")
        elif s == "guard_walk":
            if str(_call("Review_BotMode")) == "Idle":
                _set("guard")
        elif s == "guard":
            if kind == "return" and phase in ("Observe", "WatchGuarded", "BoundApproach", "AvoidPlayer") and age > 2.0:
                _call("Review_BotPressUseAt", (unreal.Vector(pack.x, pack.y, pack.z + 25.0),))
                _set("pickup_pack")
            elif kind == "theft" and phase == "WatchGuarded" and st.get("watched_at") is None:
                st["watched_at"] = st["clock"]
                _log("t=%.2f the rat watches the guarded pack" % st["clock"])
            elif kind == "theft" and st.get("watched_at") is not None and st["clock"] - st["watched_at"] >= st["guard_seconds"]:
                _call("Review_BotWalkTo", (unreal.Vector(850.0, 520.0, 100.0), 40.0))
                _set("leave")
        elif s == "leave":
            if str(_call("Review_BotMode")) == "Idle":
                _set("away")
        elif s in ("away", "chase_wait_loaded"):
            want_mushroom = kind == "theft" and age < 20.0
            if phase in LOADED and phase != "CarryMountPending" and (not want_mushroom or _call("Review_RatHasMushroom")):
                _call("Review_BotChase", (st["strike_range"],))
                _set("chase")
        elif s == "chase":
            if phase in DEAD or phase == "none":
                _set("dead")
            elif age > st["chase_timeout"]:
                _call("Review_BotStop")
                _set("chase_timeout")
        elif s == "dead":
            if phase in ("none", "Destroyed"):
                food = _call("Review_FoodLocation")
                _call("Review_BotWalkTo", (unreal.Vector(food.x, food.y, food.z), 70.0))
                _set("to_food")
        elif s == "to_food":
            if str(_call("Review_BotMode")) == "Idle":
                food = _call("Review_FoodLocation")
                _call("Review_BotPressUseAt", (unreal.Vector(food.x, food.y, food.z),))
                _set("pickup_food")
        elif s == "pickup_food":
            if age > 3.0:
                _set("done")
        elif s == "pickup_pack":
            if age > 1.0 and "pack [World]" not in str(_call("Review_Describe")):
                _call("Review_BotWalkTo", (unreal.Vector(850.0, -520.0, 100.0), 40.0))
                _set("pack_taken")
            elif age > 4.0:
                _set("pickup_pack_failed")
        elif s == "pack_taken":
            if phase == "none" and age > 1.0:
                _set("returned")
        elif s == "returned":
            if age > 1.5:
                _call("Review_SpawnSecondPack")
                _set("second_pack")
        elif s == "second_pack":
            if phase not in ("none",) and age > 0.5:
                _set("second_rat")
        elif s == "second_rat":
            if age > 3.0:
                _set("done")
    except Exception as e:
        unreal.log_warning("PANTRYRAT_STORY error %s" % _err(e))
        story_stop("error")


def story_start(kind="theft", guard_seconds=5.0, strike_range=95.0, chase_timeout=25.0):
    story_stop("restart")
    if _game_world() is None:
        return {"error": "no PIE world"}
    _story.update({"kind": kind, "state": "wait_ready", "clock": 0.0, "since": 0.0, "next_describe": 0.0,
                   "guard_seconds": guard_seconds, "strike_range": strike_range, "chase_timeout": chase_timeout,
                   "director": director(), "last_phase": None, "watched_at": None})
    if _story["director"] is None:
        return {"error": "no PIE court director"}
    _story["handle"] = unreal.register_slate_post_tick_callback(_story_tick)
    _log("start %s" % kind)
    return {"started": kind}


def story_stop(reason="stop"):
    h = _story.get("handle")
    if h is not None:
        unreal.unregister_slate_post_tick_callback(h)
        _story["handle"] = None
        _log("stop %s state %s" % (reason, _story.get("state")))


def _follow_tick(delta):
    st = _follow
    world = _game_world()
    if world is None:
        follow_stop("pie ended")
        return
    try:
        d = st.get("director") or director()
        st["director"] = d
        here = d.call_method("Review_RatLocation") if d else None
        if here is None or (here.x == 0.0 and here.y == 0.0 and here.z == 0.0):
            here = d.call_method("Review_FoodLocation") if d else None
        if here is None or (here.x == 0.0 and here.y == 0.0):
            here = st.get("last") or unreal.Vector(0.0, 0.0, 0.0)
        st["last"] = here
        ox, oy, oz = st["offset"]
        want = unreal.Vector(here.x + ox, here.y + oy, here.z + oz)
        chef = d.call_method("Review_ChefLocation") if (d and st.get("away_from_chef")) else None
        if chef is not None and not (chef.x == 0.0 and chef.y == 0.0):
            # The far side of the subject from the chef, so the chef never stands between the camera and the rat.
            dx, dy = here.x - chef.x, here.y - chef.y
            n = math.hypot(dx, dy)
            if n > 1.0:
                dist = math.hypot(ox, oy)
                want = unreal.Vector(here.x + dx / n * dist, here.y + dy / n * dist, here.z + oz)
        pos = st.get("pos") or want
        a = min(1.0, max(0.0, delta * st["rate"]))
        pos = unreal.Vector(pos.x + (want.x - pos.x) * a, pos.y + (want.y - pos.y) * a, pos.z + (want.z - pos.z) * a)
        st["pos"] = pos
        cam = st["cam"]
        cam.set_actor_location_and_rotation(pos, unreal.MathLibrary.find_look_at_rotation(pos, here), False, True)
        pc = unreal.GameplayStatics.get_player_controller(world, 0)
        if pc and pc.get_view_target() != cam:
            pc.set_view_target_with_blend(cam, 0.0)
    except Exception as e:
        unreal.log_warning("PANTRYRAT_FOLLOW error %s" % e)
        follow_stop("error")


def follow_start(offset=(40.0, -300.0, 300.0), rate=4.0, camera="Cam_Follow", away_from_chef=True):
    follow_stop("restart")
    world = _game_world()
    if world is None:
        return {"error": "no PIE world"}
    cams = [c for c in unreal.GameplayStatics.get_all_actors_of_class(world, unreal.CameraActor)
            if c.get_actor_label() == PREFIX + camera]
    if not cams:
        return {"error": "no %s in PIE" % camera}
    cc = cams[0].get_component_by_class(unreal.CameraComponent)
    pp = cc.get_editor_property("post_process_settings")
    pp.set_editor_property("override_motion_blur_amount", True)
    pp.set_editor_property("motion_blur_amount", 0.0)
    cc.set_editor_property("post_process_settings", pp)
    cc.set_editor_property("post_process_blend_weight", 1.0)
    _follow.update({"cam": cams[0], "offset": offset, "rate": rate, "pos": None, "director": None, "away_from_chef": away_from_chef})
    _follow["handle"] = unreal.register_slate_post_tick_callback(_follow_tick)
    return {"following": camera}


def follow_stop(reason="stop"):
    h = _follow.get("handle")
    if h is not None:
        unreal.unregister_slate_post_tick_callback(h)
        _follow["handle"] = None


# ---------------------------------------------------------------------------------------------------------------------
# Phase 5: rat-relative framing (close-ups) and the dither slow motion
# ---------------------------------------------------------------------------------------------------------------------

_frame = {"handle": None}


def _rat_relative(here, yaw_deg, fwd, side, up):
    y = math.radians(yaw_deg)
    fx, fy = math.cos(y), math.sin(y)
    rx, ry = -fy, fx   # UE right of a +X-forward frame rotated by yaw
    return unreal.Vector(here.x + fx * fwd + rx * side, here.y + fy * fwd + ry * side, here.z + up)


def _frame_tick(delta):
    st = _frame
    world = _game_world()
    if world is None:
        frame_stop("pie ended")
        return
    try:
        d = st.get("director") or director()
        st["director"] = d
        if d is None:
            return
        phase = str(d.call_method("Review_RatPhase"))
        here = d.call_method("Review_RatLocation")
        if phase == "none" or here is None or (here.x == 0.0 and here.y == 0.0):
            if st.get("slow"):
                unreal.SystemLibrary.execute_console_command(world, "slomo 1")
                st["slow"] = False
                unreal.log("PANTRYRAT_STORY slomo 1 (no live rat)")
            return
        yaw = float(d.call_method("Review_RatYaw"))
        fade = float(d.call_method("Review_RatFade"))
        shot = None
        for phases, s in st["schedule"]:
            if phase in phases:
                shot = s
                break
        if shot is None:
            shot = st["default"]
        fwd, side, up, look_up, look_fwd = shot
        if st.get("yaw_lock") is not None and phase in DEAD:
            yaw = st["yaw_lock"]
        elif phase in DEAD:
            st["yaw_lock"] = yaw
        want = _rat_relative(here, yaw, fwd, side, up)
        target = _rat_relative(here, yaw, look_fwd, 0.0, look_up)
        pos = st.get("pos") or want
        a = min(1.0, max(0.0, delta * st["rate"]))
        pos = unreal.Vector(pos.x + (want.x - pos.x) * a, pos.y + (want.y - pos.y) * a, pos.z + (want.z - pos.z) * a)
        st["pos"] = pos
        st["cam"].set_actor_location_and_rotation(pos, unreal.MathLibrary.find_look_at_rotation(pos, target), False, True)
        pc = unreal.GameplayStatics.get_player_controller(world, 0)
        if pc and pc.get_view_target() != st["cam"]:
            pc.set_view_target_with_blend(st["cam"], 0.0)
        # Phase 9: per-phase slow motion (a 0.4 s capture interval samples a 0.4 s bound every 0.05 s at slomo 0.125).
        want = (st.get("slomo_phases") or {}).get(phase, 1.0)
        if st.get("slomo_phases") is not None and want != st.get("phase_slomo", 1.0):
            unreal.SystemLibrary.execute_console_command(world, "slomo %s" % want)
            st["phase_slomo"] = want
            unreal.log("PANTRYRAT_STORY slomo %s phase %s" % (want, phase))
        # Slow motion while the rat dithers, so a 0.5 s capture interval lands on alpha ~0.5.
        if st.get("slomo") and 0.0 < fade < 1.0 and not st.get("slow"):
            unreal.SystemLibrary.execute_console_command(world, "slomo %s" % st["slomo"])
            st["slow"] = True
            unreal.log("PANTRYRAT_STORY slomo %s at fade %.3f phase %s" % (st["slomo"], fade, phase))
        elif st.get("slow") and (fade >= 1.0 or fade <= 0.0):
            unreal.SystemLibrary.execute_console_command(world, "slomo 1")
            st["slow"] = False
            unreal.log("PANTRYRAT_STORY slomo 1 at fade %.3f phase %s" % (fade, phase))
        if st["clock"] >= st.get("next_log", 0.0):
            st["next_log"] = st["clock"] + 0.5
            unreal.log("PANTRYRAT_FRAME t=%.2f phase %s fade %.3f yaw %.1f at %s" % (st["clock"], phase, fade, yaw, here))
        st["clock"] += delta
    except Exception as e:
        unreal.log_warning("PANTRYRAT_FRAME error %s" % e)
        frame_stop("error")


def frame_start(schedule, default=(110.0, 70.0, 25.0, 15.0, 10.0), rate=6.0, camera="Cam_Follow", slomo=None, slomo_phases=None):
    """schedule: [(phases, (fwd, side, up, look_up, look_fwd)), ...] in the rat's frame (cm; side + = the rat's right)."""
    follow_stop("frame")
    frame_stop("restart")
    world = _game_world()
    if world is None:
        return {"error": "no PIE world"}
    cams = [c for c in unreal.GameplayStatics.get_all_actors_of_class(world, unreal.CameraActor)
            if c.get_actor_label() == PREFIX + camera]
    if not cams:
        return {"error": "no %s in PIE" % camera}
    cc = cams[0].get_component_by_class(unreal.CameraComponent)
    cc.set_editor_property("field_of_view", 40.0)
    pp = cc.get_editor_property("post_process_settings")
    pp.set_editor_property("override_motion_blur_amount", True)
    pp.set_editor_property("motion_blur_amount", 0.0)
    cc.set_editor_property("post_process_settings", pp)
    _frame.update({"cam": cams[0], "schedule": [(tuple(p), tuple(s)) for p, s in schedule], "default": tuple(default),
                   "rate": rate, "pos": None, "director": None, "clock": 0.0, "slomo": slomo, "slow": False, "yaw_lock": None,
                   "slomo_phases": slomo_phases, "phase_slomo": 1.0})
    _frame["handle"] = unreal.register_slate_post_tick_callback(_frame_tick)
    return {"framing": camera}


def frame_stop(reason="stop"):
    h = _frame.get("handle")
    if h is not None:
        unreal.unregister_slate_post_tick_callback(h)
        _frame["handle"] = None
        w = _game_world()
        if w is not None and (_frame.get("slow") or _frame.get("phase_slomo", 1.0) != 1.0):
            unreal.SystemLibrary.execute_console_command(w, "slomo 1")


if __name__ == "__main__":
    args = sys.argv[1:] or ["readback"]
    try:
        if args[0] == "build":
            r = build()
        elif args[0] == "restore":
            r = restore(args[1])
        else:
            r = readback()
        print(json.dumps(r, indent=1, default=str))
        print("PANTRY_RAT_FAIL" if (isinstance(r, dict) and r.get("error")) else "PANTRY_RAT_OK")
    except Exception as e:
        print(_err(e))
        print("PANTRY_RAT_FAIL")
