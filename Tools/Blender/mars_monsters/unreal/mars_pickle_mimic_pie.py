"""PIE look at the pickle mimic, in a hidden editor (never Stephen's): places a Mars_PickleMimic_EntityScript spawner and a
review camera in Sandbox_Mars_MAP's Room 5 (the crawler room; the map is never saved), plays, moves the player about and
queues high-res shots of the client's view through that camera.

Each step is its own env_drive call, because PIE starts and frames advance only between calls:
    python ../../mars_environment/unreal/env_drive.py --port 9319 --py "<sys.path insert>; import mars_pickle_mimic_pie as pp; pp.prepare()"
    ... pp.pie_start()        (wait a few seconds)
    ... pp.place_player(FAR)  (the mimic stays disguised)   pp.shot("disguised")
    ... pp.place_player(NEAR) (it wakes, walks and bites)   pp.shot("bite_1"), pp.shot("bite_2") ...
    ... pp.pie_stop()
Shots land in Saved/Screenshots/PickleMimic/<name>.png.
"""
import os

import unreal

MAP = "/Game/Mars/Maps/Sandbox_Mars_MAP"
SCRIPT_CLASS = "/Script/Angelscript.Mars_PickleMimic_EntityScript"
SHOT_DIR = r"D:\Repo\Mars\Saved\Screenshots\PickleMimic"
LABEL = "PickleMimic_Review"
CAMERA = "PickleMimic_ReviewCamera"
CAPTURE = "PickleMimic_ReviewCapture"
CLEARANCE = 30.0                        # utils_pickle_mimic::Clearance
# Room 5 (x -3850 .. -2150, y -550 .. 550; its crawlers stand in the west half): the mimic near the east end facing -X,
# the player starts beyond WakeRadius toward the middle
MIMIC_XY = (-2400.0, 250.0)
MIMIC_YAW = 180.0
FAR = (-3100.0, 250.0)
NEAR = (-2720.0, 250.0)


def _les():
    return unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)


def _eas():
    return unreal.get_editor_subsystem(unreal.EditorActorSubsystem)


def _floor_z(world, x, y):
    hit = unreal.SystemLibrary.line_trace_single(world, unreal.Vector(x, y, 400.0), unreal.Vector(x, y, -600.0),
                                                 unreal.TraceTypeQuery.TRACE_TYPE_QUERY1, False, [],
                                                 unreal.DrawDebugTrace.NONE, True)
    if hit is None:
        return None
    t = hit.to_tuple()
    return t[4].z if t[0] else None      # (blocking hit, initial overlap, time, distance, location, ...)


def prepare():
    """Loads the map and (re)places the spawner and the camera in the editor level (unsaved)."""
    if _les().is_in_play_in_editor():
        raise RuntimeError("stop PIE first")
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    if world is None or world.get_path_name().split(".")[0] != MAP:
        _les().load_level(MAP)
        world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    for a in _eas().get_all_level_actors():
        if a.get_actor_label() in (LABEL, CAMERA, CAPTURE):
            a.destroy_actor()
    z = _floor_z(world, *MIMIC_XY)
    floor = 0.0 if z is None else z
    cls = unreal.load_class(None, SCRIPT_CLASS)
    if cls is None:
        raise RuntimeError("no %s (AngelScript not compiled?)" % SCRIPT_CLASS)
    spawner = _eas().spawn_actor_from_object(cls, unreal.Vector(MIMIC_XY[0], MIMIC_XY[1], floor + CLEARANCE),
                                             unreal.Rotator(roll=0.0, pitch=0.0, yaw=MIMIC_YAW))
    spawner.set_actor_label(LABEL)
    cam = _eas().spawn_actor_from_class(unreal.CameraActor, unreal.Vector(-2550.0, -300.0, floor + 160.0),
                                        unreal.Rotator(roll=0.0, pitch=0.0, yaw=0.0))
    cam.set_actor_label(CAMERA)
    capture_actor = _eas().spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(-2550.0, -300.0, floor + 160.0),
                                                  unreal.Rotator(roll=0.0, pitch=0.0, yaw=0.0))
    capture_actor.set_actor_label(CAPTURE)
    comp = capture_actor.capture_component2d
    comp.set_editor_property("capture_every_frame", False)
    comp.set_editor_property("capture_on_movement", False)
    return {"floor": floor, "floor_hit": z is not None, "spawner": spawner.get_name()}


def pie_start():
    _les().editor_request_begin_play()
    return True


def pie_stop():
    _les().editor_request_end_play()
    return True


def _pie_client():
    """(world, local player controller): the client world with a local controller."""
    worlds = sorted(unreal.EditorLevelLibrary.get_pie_worlds(True), key=lambda w: w.get_outermost().get_name(),
                    reverse=True)
    for w in worlds:
        for pc in unreal.GameplayStatics.get_all_actors_of_class(w, unreal.PlayerController):
            if pc.is_local_controller():
                return w, pc
    raise RuntimeError("no PIE world with a local player controller (is PIE running?)")


def place_player(xy, yaw=0.0):
    """Teleports the player's pawn (in every PIE world: the dedicated server's copy is the authority) to xy, standing on
    the floor, facing yaw."""
    out = []
    for w in unreal.EditorLevelLibrary.get_pie_worlds(True):
        for pc in unreal.GameplayStatics.get_all_actors_of_class(w, unreal.PlayerController):
            pawn = pc.get_controlled_pawn()
            if pawn is None:
                continue
            z = _floor_z(w, *xy)
            loc = unreal.Vector(xy[0], xy[1], (0.0 if z is None else z) + 100.0)
            pawn.teleport(loc, unreal.Rotator(roll=0.0, pitch=0.0, yaw=yaw))
            pc.set_control_rotation(unreal.Rotator(roll=0.0, pitch=0.0, yaw=yaw))
            out.append((w.get_outermost().get_name(), [round(loc.x), round(loc.y), round(loc.z)]))
    return out


def shot(name, eye=None, target=None, res=(1600, 900)):
    """Points the review camera (eye -> target, world cm) and queues a shot of the client view through it."""
    world, pc = _pie_client()
    cams = [c for c in unreal.GameplayStatics.get_all_actors_of_class(world, unreal.CameraActor)
            if c.get_actor_label() == CAMERA]
    if not cams:
        raise RuntimeError("no review camera in %s" % world.get_outermost().get_name())
    cam = cams[0]
    if eye is not None:
        e = unreal.Vector(*eye)
        cam.set_actor_location(e, False, False)
        if target is not None:
            cam.set_actor_rotation(unreal.MathLibrary.find_look_at_rotation(e, unreal.Vector(*target)), False)
    else:
        e = cam.get_actor_location()
        cam.set_actor_rotation(unreal.MathLibrary.find_look_at_rotation(e, unreal.Vector(MIMIC_XY[0], MIMIC_XY[1], 60.0)), False)
    pc.set_view_target_with_blend(cam, 0.0)
    os.makedirs(SHOT_DIR, exist_ok=True)
    path = os.path.join(SHOT_DIR, name + ".png")
    unreal.AutomationLibrary.take_high_res_screenshot(res[0], res[1], path, cam)
    return {"world": world.get_outermost().get_name(), "file": path}


def mimics():
    """Where each PIE world's mimic spawner actor stands (a cheap is-it-there probe)."""
    out = {}
    for w in unreal.EditorLevelLibrary.get_pie_worlds(True):
        for a in unreal.GameplayStatics.get_all_actors_of_class(w, unreal.Actor):
            if "PickleMimic" in a.get_name() or "PickleMimic" in a.get_actor_label():
                loc = a.get_actor_location()
                out.setdefault(w.get_outermost().get_name(), []).append((a.get_name(), [round(loc.x), round(loc.y), round(loc.z)]))
    return out


_JAR = {"last": MIMIC_XY}


def jar_location(piece="Frame"):
    """The review mimic's jar base now (world cm): the instance of PickleMimic_<piece>_Mars_SM nearest where it was last
    asked (other mimics may be placed in the map; the frame stands from the start to the topple)."""
    world, _ = _pie_client()
    at = _nearest_instance(_piece_isms(world, piece), _JAR["last"])
    if at is None:
        return None
    _JAR["last"] = (at.x, at.y)
    return (at.x, at.y, at.z)


def shot_jar(name, offset=(260.0, -230.0, 110.0), piece="Frame", aim_up=35.0):
    """A shot from offset (world cm) off the jar's current base, aimed at it."""
    at = jar_location(piece)
    if at is None:
        raise RuntimeError("no jar found")
    eye = (at[0] + offset[0], at[1] + offset[1], at[2] + offset[2])
    return shot(name, eye, (at[0], at[1], at[2] + aim_up))


FRAME_FILE = os.path.join(SHOT_DIR, "_frame.json")


def frame_far_side(distance=280.0, height=110.0, swing_deg=35.0):
    """Measures the jar and the player now and saves a camera on the jar's far side from the player (so the chef does not
    hide it), swung swing_deg round; shot_framed() reuses it without the slow actor scan."""
    import json
    import math
    at = jar_location("Glass")
    _, pc = _pie_client()
    p = pc.get_controlled_pawn().get_actor_location()
    dx, dy = at[0] - p.x, at[1] - p.y
    n = math.hypot(dx, dy) or 1.0
    a = math.atan2(dy, dx) + math.radians(swing_deg)
    eye = (at[0] + math.cos(a) * distance, at[1] + math.sin(a) * distance, at[2] + height)
    target = (at[0], at[1], at[2] + 30.0)
    os.makedirs(SHOT_DIR, exist_ok=True)
    with open(FRAME_FILE, "w") as fh:
        json.dump({"eye": eye, "target": target}, fh)
    return {"jar": at, "player": (p.x, p.y, p.z), "eye": eye}


def shot_framed(name):
    import json
    with open(FRAME_FILE) as fh:
        f = json.load(fh)
    return shot(name, tuple(f["eye"]), tuple(f["target"]))


_SEQ = {}


def shatter_sequence(times=(0.0, 0.12, 0.3, 0.6, 1.0, 2.0, 4.0), eye=(-2660.0, 40.0, 120.0), target=(-2400.0, 250.0, 25.0)):
    """Kills every mimic (Mars.PickleMimic.DebugKill 1) and shoots the client view through the review camera at each of
    `times` seconds after it, from a slate post-tick callback (an env_drive call takes seconds, the corpse lasts 6), then
    resets the cvar. Shots: Saved/Screenshots/PickleMimic/40_shatter_<t>.png."""
    import time
    world, pc = _pie_client()
    cams = [c for c in unreal.GameplayStatics.get_all_actors_of_class(world, unreal.CameraActor)
            if c.get_actor_label() == CAMERA]
    cam = cams[0]
    e = unreal.Vector(*eye)
    cam.set_actor_location(e, False, False)
    cam.set_actor_rotation(unreal.MathLibrary.find_look_at_rotation(e, unreal.Vector(*target)), False)
    pc.set_view_target_with_blend(cam, 0.0)
    os.makedirs(SHOT_DIR, exist_ok=True)
    _SEQ.update({"start": time.time(), "todo": list(times), "done": [], "killed": False, "cam": cam, "world": world})

    def tick(dt):
        now = time.time() - _SEQ["start"]
        if not _SEQ["killed"] and now >= 0.05:
            unreal.SystemLibrary.execute_console_command(_SEQ["world"], "Mars.PickleMimic.DebugKill 1")
            _SEQ["killed"] = True
            _SEQ["kill_at"] = now
            return
        waiting = _SEQ["done"] and not os.path.exists(_SEQ["done"][-1])      # one high-res shot at a time
        if _SEQ["killed"] and _SEQ["todo"] and not waiting and now - _SEQ["kill_at"] >= _SEQ["todo"][0]:
            t = _SEQ["todo"].pop(0)
            path = os.path.join(SHOT_DIR, "40_shatter_%04.2f.png" % t)
            if os.path.exists(path):
                os.remove(path)
            unreal.AutomationLibrary.take_high_res_screenshot(1600, 900, path, _SEQ["cam"])
            _SEQ["done"].append(path)
            return
        if _SEQ["killed"] and not _SEQ["todo"] and now - _SEQ["kill_at"] > max(times) + 0.5:
            unreal.SystemLibrary.execute_console_command(_SEQ["world"], "Mars.PickleMimic.DebugKill 0")
            unreal.unregister_slate_post_tick_callback(_SEQ["handle"])
            _SEQ["handle"] = None

    _SEQ["handle"] = unreal.register_slate_post_tick_callback(tick)
    return {"scheduled": list(times)}


_FOLLOW = {}


def _piece_isms(world, piece="Frame"):
    out = []
    for a in unreal.GameplayStatics.get_all_actors_of_class(world, unreal.Actor):
        if "PickleMimic_%s_Mars_SM" % piece in a.get_name():
            out += list(a.get_components_by_class(unreal.InstancedStaticMeshComponent))
    return out


def _nearest_instance(isms, near):
    """The world location of the instance nearest `near` (x, y) among isms, or None."""
    best, at = 1e18, None
    for c in isms:
        for i in range(c.get_instance_count()):
            t = c.get_instance_transform(i, True).translation
            d = (t.x - near[0]) ** 2 + (t.y - near[1]) ** 2
            if d < best:
                best, at = d, t
    return at


def stop_follow():
    h = _FOLLOW.pop("handle", None)
    if h is not None:
        unreal.unregister_slate_post_tick_callback(h)
    return h is not None


def cvar(command):
    """Runs a console command in the PIE client world (e.g. "Mars.PickleMimic.DebugHit 3")."""
    world, _ = _pie_client()
    unreal.SystemLibrary.execute_console_command(world, command)
    return command


def follow_sequence(prefix, count=12, gap=0.2, offset=(-150.0, -170.0, 80.0), aim_up=40.0, res=(1280, 720), max_seconds=60.0,
                    command=None, fixed=False):
    """Captures `count` frames (the review SceneCapture2D, synchronous), at least `gap` s apart, from `offset` (world cm) off
    the review mimic's jar (its frame, followed frame to frame; `fixed` keeps the pose from the first frame), aimed `aim_up`
    over its base. `command` (a console command) runs right after the first capture. Stops after `count` frames or
    `max_seconds` (stop_follow() stops it early) and writes <prefix>_log.json (time and jar base per frame).
    Frames: Saved/Screenshots/PickleMimic/<prefix>_NN.png."""
    import json
    import time
    stop_follow()
    world, _ = _pie_client()
    isms = _piece_isms(world)
    if not isms:
        raise RuntimeError("no jar frame instance")
    _capture_actor(world, res)
    start = time.time()
    seq = {"next": start, "done": 0, "log": [], "last": MIMIC_XY, "pose": None}

    def finish():
        stop_follow()
        with open(os.path.join(SHOT_DIR, prefix + "_log.json"), "w") as fh:
            json.dump(seq["log"], fh)

    def tick(dt):
        try:
            if seq["done"] >= count or time.time() - start > max_seconds:
                finish()
                return
            if time.time() < seq["next"]:
                return
            t = _nearest_instance(isms, seq["last"])
            if t is None:
                finish()
                return
            seq["last"] = (t.x, t.y)
            if seq["pose"] is None or not fixed:
                seq["pose"] = ((t.x + offset[0], t.y + offset[1], t.z + offset[2]), (t.x, t.y, t.z + aim_up))
            capture("%s_%02d" % (prefix, seq["done"]), seq["pose"][0], seq["pose"][1], res)
            if command and seq["done"] == 0:
                unreal.SystemLibrary.execute_console_command(world, command)
            seq["log"].append({"t": round(time.time() - start, 3), "jar": [round(t.x), round(t.y), round(t.z)]})
            seq["done"] += 1
            seq["next"] = time.time() + gap
        except Exception as ex:
            seq["log"].append({"error": str(ex)})
            finish()

    _FOLLOW["handle"] = unreal.register_slate_post_tick_callback(tick)
    return {"scheduled": count}


_CAPTURE = {}


def _capture_actor(world, res):
    """The review SceneCapture2D (placed by prepare) in the PIE client world, rendering final tonemapped colour into a
    render target of its own, so a capture never depends on whose view the player controller holds."""
    actor = [a for a in unreal.GameplayStatics.get_all_actors_of_class(world, unreal.SceneCapture2D)
             if a.get_actor_label() == CAPTURE][0]
    comp = actor.capture_component2d
    rt = comp.get_editor_property("texture_target")
    if rt is None or rt.get_editor_property("size_x") != res[0]:
        rt = unreal.RenderingLibrary.create_render_target2d(world, res[0], res[1], unreal.TextureRenderTargetFormat.RTF_RGBA8_SRGB)
        comp.set_editor_property("texture_target", rt)
        comp.set_editor_property("capture_source", unreal.SceneCaptureSource.SCS_FINAL_TONE_CURVE_HDR)
        comp.set_editor_property("fov_angle", 70.0)
    _CAPTURE["rt"] = rt
    return actor


def capture(name, eye, target, res=(1280, 720)):
    """Renders the PIE client world from eye toward target (world cm) into Saved/Screenshots/PickleMimic/<name>.png now."""
    world, _ = _pie_client()
    actor = _capture_actor(world, res)
    e = unreal.Vector(*eye)
    actor.set_actor_location_and_rotation(e, unreal.MathLibrary.find_look_at_rotation(e, unreal.Vector(*target)), False, False)
    actor.capture_component2d.capture_scene()
    os.makedirs(SHOT_DIR, exist_ok=True)
    unreal.RenderingLibrary.export_render_target(world, _CAPTURE["rt"], SHOT_DIR, name + ".png")
    return os.path.join(SHOT_DIR, name + ".png")


def capture_jar(name, offset=(-150.0, -170.0, 80.0), aim_up=40.0, res=(1280, 720)):
    at = jar_location("Frame")
    if at is None:
        raise RuntimeError("no jar found")
    return capture(name, (at[0] + offset[0], at[1] + offset[1], at[2] + offset[2]), (at[0], at[1], at[2] + aim_up), res)
