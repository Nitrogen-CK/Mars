"""PIE look at the eye wall (Mars_EyeWallDummy_EntityScript), in a hidden editor (never Stephen's): generates the two
eye-swarm looks, places a review wall and a SceneCapture2D on Sandbox_Mars_MAP's main floor (the map is never saved),
plays, moves the player far (idle wander and blinks) and near (every eye converges on the chef) and captures the client
world through that capture (synchronous; HighResShot is unreliable here, see mars_pickle_mimic_pie).

Each step is its own env_drive call, because PIE starts and frames advance only between calls:
    python ../../mars_environment/unreal/env_drive.py --port 9317 --module mars_eye_wall_pie --alias ew --call "ew.generate_looks()"
    ... ew.prepare()                             (loads the map, places the wall + capture)
    ... ew.pie_start()                           (wait a few seconds)
    ... ew.place_player(ew.FAR)                  (out of focus range: eyes wander)      ew.capture_wall("10_far")
    ... ew.place_player(ew.NEAR)                 (inside FocusNearCm: eyes converge)    ew.capture_wall("20_near")
    ... ew.pie_stop()
Frames land in Saved/Screenshots/EyeWall/<name>.png.
"""
import os

import unreal

MAP = "/Game/Mars/Maps/Sandbox_Mars_MAP"
SCRIPT_CLASS = "/Script/Angelscript.Mars_EyeWallDummy_EntityScript"
SHOT_DIR = r"D:\Repo\Mars\Saved\Screenshots\EyeWall"
LABEL = "EyeWall_Review"
CAPTURE = "EyeWall_ReviewCapture"
LOOKS = ("MarsEyeball", "MarsEyelid")
MASTERS = ("/Game/Mars/Materials/GeneratedLooks/M_CkUsf_Look_MarsEyeball",
           "/Game/Mars/Materials/GeneratedLooks/M_CkUsf_Look_MarsEyelid")
# The sandbox builder's own spot (Mars.Sandbox.PlaceEyeWall): on the main floor, north of the EyesDummy, its face toward
# -X where the player starts are. The slab is 300 x 200 x 20 cm; the eyes poke out of its -X face at x ~ -160.
WALL_XY = (-150.0, 550.0)
WALL_YAW = 180.0
FAR = (-1300.0, 550.0)       # beyond FocusFarCm (900): idle wander
NEAR = (-380.0, 550.0)       # inside FocusNearCm (300): every eye on the chef


def _les():
    return unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)


def _eas():
    return unreal.get_editor_subsystem(unreal.EditorActorSubsystem)


def _editor_world():
    return unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()


def generate_looks():
    """Runs Ck_Usf_GenerateLooks for both eye-swarm looks in the editor world (never in PIE) and reports whether the
    masters exist afterwards. Generation compiles shaders synchronously enough for the asset to be saved; a compile
    error is logged by CkUsfEditor and leaves the master missing."""
    if _les().is_in_play_in_editor():
        raise RuntimeError("stop PIE first")
    world = _editor_world()
    for look in LOOKS:
        unreal.SystemLibrary.execute_console_command(world, "Ck_Usf_GenerateLooks %s" % look)
    return {m.rsplit("/", 1)[1]: unreal.EditorAssetLibrary.does_asset_exist(m) for m in MASTERS}


def masters_exist():
    return {m.rsplit("/", 1)[1]: unreal.EditorAssetLibrary.does_asset_exist(m) for m in MASTERS}


def _floor_z(world, x, y):
    hit = unreal.SystemLibrary.line_trace_single(world, unreal.Vector(x, y, 400.0), unreal.Vector(x, y, -600.0),
                                                 unreal.TraceTypeQuery.TRACE_TYPE_QUERY1, False, [],
                                                 unreal.DrawDebugTrace.NONE, True)
    if hit is None:
        return None
    t = hit.to_tuple()
    return t[4].z if t[0] else None


def prepare():
    """Loads the map and (re)places the wall spawner and the capture in the editor level (unsaved)."""
    if _les().is_in_play_in_editor():
        raise RuntimeError("stop PIE first")
    world = _editor_world()
    if world is None or world.get_path_name().split(".")[0] != MAP:
        _les().load_level(MAP)
        world = _editor_world()
    for a in _eas().get_all_level_actors():
        if a.get_actor_label() in (LABEL, CAPTURE):
            a.destroy_actor()
    z = _floor_z(world, *WALL_XY)
    floor = 0.0 if z is None else z
    cls = unreal.load_class(None, SCRIPT_CLASS)
    if cls is None:
        raise RuntimeError("no %s (AngelScript not compiled?)" % SCRIPT_CLASS)
    spawner = _eas().spawn_actor_from_object(cls, unreal.Vector(WALL_XY[0], WALL_XY[1], floor),
                                             unreal.Rotator(roll=0.0, pitch=0.0, yaw=WALL_YAW))
    spawner.set_actor_label(LABEL)
    capture_actor = _eas().spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(-500.0, 550.0, floor + 150.0),
                                                  unreal.Rotator(roll=0.0, pitch=0.0, yaw=0.0))
    capture_actor.set_actor_label(CAPTURE)
    comp = capture_actor.capture_component2d
    comp.set_editor_property("capture_every_frame", False)
    comp.set_editor_property("capture_on_movement", False)
    return {"floor": floor, "floor_hit": z is not None, "spawner": spawner.get_name(), "masters": masters_exist()}


def pie_start():
    _les().editor_request_begin_play()
    return True


def pie_stop():
    _les().editor_request_end_play()
    return True


def _pie_client():
    worlds = sorted(unreal.EditorLevelLibrary.get_pie_worlds(True), key=lambda w: w.get_outermost().get_name(),
                    reverse=True)
    for w in worlds:
        for pc in unreal.GameplayStatics.get_all_actors_of_class(w, unreal.PlayerController):
            if pc.is_local_controller():
                return w, pc
    raise RuntimeError("no PIE world with a local player controller (is PIE running?)")


def place_player(xy, yaw=0.0):
    """Teleports the player's pawn in every PIE world to xy on the floor, facing yaw (0 = toward the wall's face)."""
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


def eye_instances():
    """Instance counts of every ISM in the client world, to confirm the wall composed (two ISMs with 35 instances)."""
    world, _ = _pie_client()
    out = []
    for a in unreal.GameplayStatics.get_all_actors_of_class(world, unreal.Actor):
        for c in a.get_components_by_class(unreal.InstancedStaticMeshComponent):
            mesh = c.get_editor_property("static_mesh")
            mat = c.get_material(0)
            out.append({"actor": a.get_actor_label(), "component": c.get_name(), "instances": c.get_instance_count(),
                        "mesh": mesh.get_name() if mesh else None, "material": mat.get_name() if mat else None})
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
        comp.set_editor_property("fov_angle", 60.0)
    _CAPTURE["rt"] = rt
    return actor


def capture(name, eye, target, res=(1280, 720)):
    """Renders the PIE client world from eye toward target (world cm) into Saved/Screenshots/EyeWall/<name>.png now."""
    world, _ = _pie_client()
    actor = _capture_actor(world, res)
    e = unreal.Vector(*eye)
    actor.set_actor_location_and_rotation(e, unreal.MathLibrary.find_look_at_rotation(e, unreal.Vector(*target)), False, False)
    actor.capture_component2d.capture_scene()
    os.makedirs(SHOT_DIR, exist_ok=True)
    unreal.RenderingLibrary.export_render_target(world, _CAPTURE["rt"], SHOT_DIR, name + ".png")
    return os.path.join(SHOT_DIR, name + ".png")


def capture_wall(name, distance=260.0, height=130.0, side=0.0, res=(1280, 720)):
    """The wall's face from `distance` cm in front of it (toward -X), `side` cm along +Y, at `height`."""
    face_x = WALL_XY[0] - 10.0
    return capture(name, (face_x - distance, WALL_XY[1] + side, height), (face_x, WALL_XY[1], 120.0), res)


def capture_closeup(name, res=(1280, 720)):
    """A few eyes large: 70 cm off the face, slightly from the side, so the lids and the iris read."""
    face_x = WALL_XY[0] - 10.0
    return capture(name, (face_x - 70.0, WALL_XY[1] + 40.0, 135.0), (face_x, WALL_XY[1] + 10.0, 125.0), res)
