"""PIE look at the Root Maw, in a hidden editor (never Stephen's): places a Mars_RootMaw_EntityScript spawner and a review
SceneCapture2D in Sandbox_Mars_MAP's Room 5 (the crawler room; the map is never saved), plays, moves the player about and
captures the client world through that capture (synchronous; HighResShot is unreliable here, see mars_pickle_mimic_pie).

Each step is its own env_drive call, because PIE starts and frames advance only between calls:
    python ../../mars_environment/unreal/env_drive.py --port 9317 --py "<sys.path insert>; import mars_root_maw_pie as rp; rp.prepare()"
    ... rp.pie_start()                          (wait a few seconds)
    ... rp.place_player(rp.FAR)                 (it stays buried)              rp.capture_maw("10_buried")
    ... rp.place_player(rp.NEAR)                (it bursts up)                 rp.capture_maw("20_up")
    ... rp.chase_sequence("30_chase", ...)      (the player steps away along a path; frames follow the Maw's glide)
    ... rp.pie_stop()
Frames land in Saved/Screenshots/RootMaw/<name>.png.
"""
import json
import math
import os
import time

import unreal

MAP = "/Game/Mars/Maps/Sandbox_Mars_MAP"
SCRIPT_CLASS = "/Script/Angelscript.Mars_RootMaw_EntityScript"
SHOT_DIR = r"D:\Repo\Mars\Saved\Screenshots\RootMaw"
LABEL = "RootMaw_Review"
CAPTURE = "RootMaw_ReviewCapture"
CLEARANCE = 30.0                        # utils_root_maw::Clearance
# Room 5 (measured in PIE 2026-11-02: floor at z 0 over x -3900 .. -2000, y 100 .. 1200; a block at x -2700 .. -2600,
# y 300 .. 400; the placed pickle mimic at about (-2596, 1113); crawlers wander the west half): the Maw near the east end
# facing -X, the player starts beyond WakeRadius (450) toward the middle. CHASE leads it west along y 650.
MAW_XY = (-2250.0, 650.0)
MAW_YAW = 180.0
FAR = (-3100.0, 650.0)
NEAR = (-2620.0, 650.0)
CHASE = [(-2800.0, 700.0), (-3000.0, 650.0), (-3200.0, 600.0), (-3400.0, 650.0), (-3600.0, 700.0), (-3750.0, 650.0)]


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
    """Loads the map and (re)places the spawner and the capture in the editor level (unsaved)."""
    if _les().is_in_play_in_editor():
        raise RuntimeError("stop PIE first")
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    if world is None or world.get_path_name().split(".")[0] != MAP:
        _les().load_level(MAP)
        world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    for a in _eas().get_all_level_actors():
        if a.get_actor_label() in (LABEL, CAPTURE):
            a.destroy_actor()
    z = _floor_z(world, *MAW_XY)
    floor = 0.0 if z is None else z
    cls = unreal.load_class(None, SCRIPT_CLASS)
    if cls is None:
        raise RuntimeError("no %s (AngelScript not compiled?)" % SCRIPT_CLASS)
    spawner = _eas().spawn_actor_from_object(cls, unreal.Vector(MAW_XY[0], MAW_XY[1], floor + CLEARANCE),
                                             unreal.Rotator(roll=0.0, pitch=0.0, yaw=MAW_YAW))
    spawner.set_actor_label(LABEL)
    capture_actor = _eas().spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(-2600.0, 300.0, floor + 160.0),
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
    stop_follow()
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


def cvar(command):
    """Runs a console command in the PIE client world (e.g. "Mars.RootMaw.DebugHit 3")."""
    world, _ = _pie_client()
    unreal.SystemLibrary.execute_console_command(world, command)
    return command


_MAW = {"last": MAW_XY}


def _heads(world):
    """Every Root Maw head (its poseable mesh component) in world."""
    out = []
    for c in _all_components(world, unreal.PoseableMeshComponent):
        mesh = c.get_skinned_asset() if hasattr(c, "get_skinned_asset") else None
        if mesh is not None and "RootMaw_Head" in mesh.get_name():
            out.append(c)
    return out


def _nearest_head(heads, near):
    best, at = 1e18, None
    for c in heads:
        t = c.get_world_location()
        d = (t.x - near[0]) ** 2 + (t.y - near[1]) ** 2
        if d < best:
            best, at = d, t
    return at


def maw_location():
    """The review Maw's body origin now (world cm: the ground under its bulb when it is up), from its head component
    nearest where it was last seen."""
    world, _ = _pie_client()
    at = _nearest_head(_heads(world), _MAW["last"])
    if at is None:
        return None
    _MAW["last"] = (at.x, at.y)
    return (at.x, at.y, at.z)


def roots_alive():
    """How many root particles the review Maw's trail holds now (its Niagara component's emitter count)."""
    world, _ = _pie_client()
    out = []
    for c in _all_components(world, unreal.NiagaraComponent):
        if c.get_asset() is not None and "RootMawRoots" in c.get_asset().get_name():
            loc = c.get_world_location()
            out.append({"at": [round(loc.x), round(loc.y), round(loc.z)], "active": c.is_active()})
    return out


def _all_components(world, cls):
    out = []
    for a in unreal.GameplayStatics.get_all_actors_of_class(world, unreal.Actor):
        out += list(a.get_components_by_class(cls))
    return out


_CAPTURE = {}


def _capture_actor(world, res):
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
    """Renders the PIE client world from eye toward target (world cm) into Saved/Screenshots/RootMaw/<name>.png now."""
    world, _ = _pie_client()
    actor = _capture_actor(world, res)
    e = unreal.Vector(*eye)
    actor.set_actor_location_and_rotation(e, unreal.MathLibrary.find_look_at_rotation(e, unreal.Vector(*target)), False, False)
    actor.capture_component2d.capture_scene()
    os.makedirs(SHOT_DIR, exist_ok=True)
    unreal.RenderingLibrary.export_render_target(world, _CAPTURE["rt"], SHOT_DIR, name + ".png")
    return os.path.join(SHOT_DIR, name + ".png")


def capture_maw(name, offset=(-220.0, -200.0, 110.0), aim_up=45.0, res=(1280, 720)):
    at = maw_location()
    if at is None:
        raise RuntimeError("no Maw found")
    return capture(name, (at[0] + offset[0], at[1] + offset[1], at[2] + offset[2]), (at[0], at[1], at[2] + aim_up), res)


_FOLLOW = {}


def stop_follow():
    h = _FOLLOW.pop("handle", None)
    if h is not None:
        unreal.unregister_slate_post_tick_callback(h)
    return h is not None


def chase_sequence(prefix, path, count=16, gap=0.25, offset=(60.0, -260.0, 120.0), aim_up=35.0, res=(1280, 720),
                   step_every=4, fixed_eye=None, max_seconds=60.0, command=None, facing=None):
    """Captures `count` frames at least `gap` s apart, following the review Maw (or from fixed_eye, world cm), while the
    player steps along `path` (a list of xy, one step every `step_every` frames, so the Maw keeps gliding after it).
    `facing` = (distance, swing degrees, height): the camera stands that far from the Maw toward the player (the side its
    maw faces while it hunts), swung round, instead of at `offset`. `command` (a console command) runs right after the
    first frame (an env_drive call takes seconds, a corpse lasts 5). Stops after `count` frames or `max_seconds`
    (stop_follow() stops it early) and writes <prefix>_log.json (time, Maw, player step per frame).
    Frames: Saved/Screenshots/RootMaw/<prefix>_NN.png."""
    stop_follow()
    world, pc = _pie_client()
    heads = _heads(world)
    if not heads:
        raise RuntimeError("no Maw head component")
    _capture_actor(world, res)
    start = time.time()
    seq = {"next": start, "done": 0, "log": [], "last": _MAW["last"], "steps": list(path)}

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
            stepped = None
            if seq["steps"] and seq["done"] % step_every == 0:
                stepped = seq["steps"].pop(0)
                place_player(stepped, yaw=0.0)
            t = _nearest_head(heads, seq["last"])
            if t is None:
                finish()
                return
            seq["last"] = (t.x, t.y)
            _MAW["last"] = seq["last"]
            if fixed_eye is not None:
                eye, target = fixed_eye, (t.x, t.y, t.z + aim_up)
            elif facing is not None:
                if "facing" not in seq:
                    p = pc.get_controlled_pawn().get_actor_location()
                    seq["facing"] = math.atan2(p.y - t.y, p.x - t.x) + math.radians(facing[1])
                a = seq["facing"]
                eye = (t.x + math.cos(a) * facing[0], t.y + math.sin(a) * facing[0], t.z + facing[2])
                target = (t.x, t.y, t.z + aim_up)
            else:
                eye, target = (t.x + offset[0], t.y + offset[1], t.z + offset[2]), (t.x, t.y, t.z + aim_up)
            capture("%s_%02d" % (prefix, seq["done"]), eye, target, res)
            if command and seq["done"] == 0:
                unreal.SystemLibrary.execute_console_command(world, command)
            seq["log"].append({"t": round(time.time() - start, 3), "maw": [round(t.x), round(t.y), round(t.z)],
                               "step": stepped})
            seq["done"] += 1
            seq["next"] = time.time() + gap
        except Exception as ex:
            seq["log"].append({"error": str(ex)})
            finish()

    _FOLLOW["handle"] = unreal.register_slate_post_tick_callback(tick)
    return {"scheduled": count}


def contact_sheet(prefix, cols=4, out=None):
    """Tiles <prefix>_NN.png into <prefix>_sheet.png (editor Python has no PIL: tiles through a render target canvas is
    overkill, so this is done on the host; see the session notes). Returns the frame list."""
    frames = sorted(f for f in os.listdir(SHOT_DIR) if f.startswith(prefix + "_") and f.endswith(".png") and "sheet" not in f)
    return [os.path.join(SHOT_DIR, f) for f in frames]
