"""Screaming Turnip R01 Phase F (and the Phase G re-check, the Phase H run-03 at the x3.0 size): PIE driver for the review room (playtest.py pattern: begin / note / screenshot / key).

Run through Monolith `editor_query run_python` with normal PIE running in the review map
(/Game/ArtCandidates/ScreamingTurnip/R01/Review/ScreamingTurnip_R01_Review_MAP):

    import sys; sys.path.insert(0, r"D:/Repositories/CkRepos/Orion/Tools/LevelDesign/screaming_turnip_r01_review")
    import screaming_turnip_pie_ue as t        # import once per PIE session; do not reload while the monitor runs
    t.begin("run-01")                          # asserts the world is not throttled, binds the review traces, starts the monitor
    t.aim_at((0, 0, 5)); ...                   # then key('LeftMouseButton', True) in ONE call and key(..., False) in a later one
    t.note("F1-prompt"); t.screenshot("F1_prompt")

Input goes through Mars_ExpeditionAcceptance (Aim / Key: the raw input-source path, the game's own Use / Primary / Drop
mapping), never through injected Enhanced Input actions. Readouts come from Mars_ScreamingTurnipAcceptance (kernel per
turnip, bed state; its Watch binds ck::Trace lines '[TurnipReview] ...' into Mars.log for every commit / phase / placement
change). The monitor (a slate post-tick callback) records every change of placement / phase / sequence / playing clip
with the game time, so the run.json carries the exact sequence and clip switching.

Outputs: captures/pie/<run>/run.json (rows), captures/pie/<run>/<label>.png (Shot SHOWUI: game + HUD prompt).
"""

import json
import math
import re
import time
from pathlib import Path

import unreal as u

HERE = Path(__file__).resolve().parent
OUT = HERE / "captures" / "pie"
TURNIP_CLASS = "/Script/Angelscript.Mars_ScreamingTurnipAcceptance"
EXPEDITION_CLASS = "/Script/Angelscript.Mars_ExpeditionAcceptance"
BED_CLASS = "/Script/Angelscript.Mars_ScreamingTurnipBed_EntityScript"
PRESENTATION_CLASS = "/Script/Angelscript.Mars_ScreamingTurnipPresentationComponent"

session = globals().get("session")
_handles = globals().get("_handles") or {}

_VEC = re.compile(r"X=(-?[0-9.e+-]+) Y=(-?[0-9.e+-]+) Z=(-?[0-9.e+-]+)")


def _world():
    return u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()


def game_time():
    return u.GameplayStatics.get_time_seconds(session["world"])


def begin(label=None, check_throttle=True):
    """check_throttle=False only inside capture_pie_movement_clip, whose per-frame ReadPixels holds each frame near 0.15 s
    (Phase H run-03-clip): the capture's own cost, not a minimized window."""
    global session
    world = _world()
    assert world, "Start normal PIE first"
    pc = u.GameplayStatics.get_player_controller(world, 0)
    pawn = pc.get_controlled_pawn()
    assert pawn, "Wait for the actual player"
    assert not check_throttle or u.GameplayStatics.get_world_delta_seconds(world) < .1, \
        "Restore the Unreal window before testing: world is throttled below 10 FPS"
    expedition = u.new_object(u.load_class(None, EXPEDITION_CLASS), outer=pc)
    turnip = u.new_object(u.load_class(None, TURNIP_CLASS), outer=pc)
    session = dict(world=world, pc=pc, pawn=pawn, helper=expedition, turnip=turnip, started=time.monotonic(),
                   game_started=u.GameplayStatics.get_time_seconds(world), events=[], held_keys=set(),
                   run=label or time.strftime("run-%Y%m%d-%H%M%S"), last_sig=None, changes=[], deltas=[])
    globals()["session"] = session
    folder().mkdir(parents=True, exist_ok=True)
    watch()
    monitor_start()
    note("begin")
    return folder()


def folder():
    return OUT / session["run"]


# ------------------------------------------------------------------------------------------------------------ readouts

def turnips_text():
    return session["turnip"].call_method("Turnips", args=(session["pawn"],))


def turnips():
    """Parsed kernel readout: list of dicts (entity, placement, phase, seq, clock, warning, mount, at, up, ...)."""
    rows = []
    for line in turnips_text().splitlines():
        if not line.startswith("turnip="):
            continue
        row = {}
        for key in ("turnip", "frame", "placement", "phase", "seq", "clock", "warning", "next_warning", "last_commit",
                    "support", "mount", "settled", "speed", "sleep"):
            m = re.search(r"\b%s=(\S+)" % key, line)
            if m:
                row[key] = m.group(1)
        for key in ("at", "up"):
            m = re.search(r"\b%s=X=(-?[0-9.e+-]+) Y=(-?[0-9.e+-]+) Z=(-?[0-9.e+-]+)" % key, line)
            if m:
                row[key] = [round(float(v), 2) for v in m.groups()]
        rows.append(row)
    return rows


def world_item_count():
    m = re.match(r"world_items=(\d+)", turnips_text())
    return int(m.group(1)) if m else -1


def clip_state(c):
    """(sequence asset, clip time) of a presentation component. Phase K: the component plays through the AnimBlueprint
    (Mars_ScreamingTurnip_AnimInstance's Sequence / ClipTime); the single-node API (GetPosition, GetAnimationAsset) would
    log "Currently in Animation Blueprint mode" each call, so it is used only when the instance has no such fields."""
    inst = c.get_anim_instance()
    if inst is None:
        return None, 0.0
    try:
        return inst.get_editor_property("Sequence"), float(inst.get_editor_property("ClipTime"))
    except Exception:
        asset = inst.get_animation_asset() if hasattr(inst, "get_animation_asset") else None
        return asset, c.get_position()


def _pie_objects(class_path):
    cls = u.load_class(None, class_path)
    return [o for o in u.ObjectIterator(cls) if "UEDPIE" in o.get_path_name()]


def beds():
    out = []
    for b in _pie_objects(BED_CLASS):
        text = session["turnip"].call_method("Bed", args=(b,))
        if text.startswith("bed="):
            out.append(text)
    return sorted(set(out))


def clips():
    """Every live presentation component (item and bed): clip, time, world location / up, visible."""
    rows = []
    for c in _pie_objects(PRESENTATION_CLASS):
        try:
            if not c.get_owner():
                continue
            inst = c.get_anim_instance()
            asset, clip_t = clip_state(c)
            loc = c.get_world_location()
            up = c.get_up_vector()
            fwd = c.get_forward_vector()
            curves = {}
            if inst:
                for curve in ("Inhale", "Scream"):
                    try:
                        curves[curve] = round(inst.get_curve_value(curve), 3)
                    except Exception:
                        pass
            rows.append(dict(name=c.get_name().rsplit("_", 1)[-1], clip=(asset.get_name().replace("ScreamingTurnip_R01_", "")
                                                      .replace("_Mars_ANIM", "") if asset else None), curves=curves,
                             t=round(clip_t, 3),
                             at=[round(loc.x, 1), round(loc.y, 1), round(loc.z, 1)],
                             up=[round(up.x, 2), round(up.y, 2), round(up.z, 2)],
                             fwd=[round(fwd.x, 2), round(fwd.y, 2), round(fwd.z, 2)], visible=c.is_visible()))
        except Exception as e:  # a component mid-teardown
            rows.append(dict(name=str(c), error=str(e)))
    return rows


def inspect():
    return session["helper"].call_method("Inspect", args=(session["pawn"],)).splitlines()[0]


def watch():
    return session["turnip"].call_method("Watch", args=(session["pawn"],))


def note(event, **extra):
    world = session["world"]
    row = dict(t=round(time.monotonic() - session["started"], 2),
               game_elapsed=round(game_time() - session["game_started"], 3),
               frame_delta=round(u.GameplayStatics.get_world_delta_seconds(world), 4),
               event=event, player=inspect(), world_items=world_item_count(), turnips=turnips(), beds=beds(),
               clips=clips(), **extra)
    session["events"].append(row)
    _flush()
    print(json.dumps(row))
    return row


def _flush():
    (folder() / "run.json").write_text(json.dumps(dict(events=session["events"], changes=session["changes"],
                                                       max_delta=max(session["deltas"] or [0])), indent=1))


def screenshot(label):
    path = str(folder() / (label + ".png")).replace("\\", "/")
    u.SystemLibrary.execute_console_command(session["world"], 'Shot SHOWUI filename="' + path + '" -nosuffix', session["pc"])
    return path


# ------------------------------------------------------------------------------------------------------------ monitor

def _signature():
    sig = []
    for r in turnips():
        sig.append((r.get("turnip"), r.get("placement"), r.get("phase"), r.get("seq"), r.get("mount")))
    for c in clips():
        sig.append((c.get("name"), c.get("clip")))
    return sig


def _monitor_tick(dt):
    try:
        w = _world()
        if not w or not session or w != session["world"]:
            monitor_stop()
            return
        session["deltas"].append(round(u.GameplayStatics.get_world_delta_seconds(w), 4))
        if len(session["deltas"]) > 20000:
            session["deltas"] = session["deltas"][-10000:]
        sig = _signature()
        if sig != session["last_sig"]:
            prev = session["last_sig"]
            session["last_sig"] = sig
            session["changes"].append(dict(game=round(game_time() - session["game_started"], 3),
                                           frame_delta=session["deltas"][-1],
                                           turnips=[dict(entity=s[0], placement=s[1], phase=s[2], seq=s[3], mount=s[4])
                                                    for s in sig if len(s) == 5],
                                           clips=[dict(name=s[0], clip=s[1]) for s in sig if len(s) == 2],
                                           at=[(r.get("turnip"), r.get("at"), r.get("up"), r.get("clock"))
                                               for r in turnips()]))
            if len(session["changes"]) % 5 == 0:
                _flush()
        for fn in list(session.get("whens", [])):
            try:
                if fn():
                    session["whens"].remove(fn)
            except Exception as e:
                session["whens"].remove(fn)
                session["changes"].append(dict(game=round(game_time() - session["game_started"], 3), error=str(e)))
    except Exception as e:
        print("monitor error", e)


def monitor_start():
    monitor_stop()
    session["whens"] = []
    _handles["monitor"] = u.register_slate_post_tick_callback(_monitor_tick)
    globals()["_handles"] = _handles


def monitor_stop():
    h = _handles.pop("monitor", None)
    if h is not None:
        u.unregister_slate_post_tick_callback(h)


def when(fn):
    """fn() runs every tick (after the change record) until it returns True."""
    session["whens"].append(fn)


# ------------------------------------------------------------------------------------------------------------ input

def aim_at(at):
    camera = u.GameplayStatics.get_player_camera_manager(session["world"], 0)
    rotation = u.MathLibrary.find_look_at_rotation(camera.get_camera_location(), u.Vector(*at))
    assert session["helper"].call_method("Aim", args=(session["pawn"], rotation))
    return dict(camera=str(camera.get_camera_location()), rotation=str(rotation))


def key(name, down):
    assert session["helper"].call_method("Key", args=(session["pawn"], u.Name(name), down))
    (session["held_keys"].add if down else session["held_keys"].discard)(name)
    session["changes"].append(dict(game=round(game_time() - session["game_started"], 3), key=name, down=down))


def key_after(name, down, seconds):
    """Key edge on a later tick (the playtest.py tap() pattern): never the same frame as the call that schedules it."""
    start = game_time()
    def fn():
        if game_time() - start >= seconds:
            key(name, down)
            return True
        return False
    when(fn)


def walk_to(target, tolerance=40, label="walk"):
    """Native movement input toward target (x, y) each tick until within tolerance; stalls are recorded."""
    state = dict(stagnant=0., prev=session["pawn"].get_actor_location(), done=False)
    def fn():
        at = session["pawn"].get_actor_location()
        dx, dy = target[0] - at.x, target[1] - at.y
        d = math.hypot(dx, dy)
        if d <= tolerance:
            state["done"] = True
            session["changes"].append(dict(game=round(game_time() - session["game_started"], 3), arrive=label,
                                           at=[round(at.x), round(at.y), round(at.z)]))
            return True
        moved = (at - state["prev"]).length()
        state["prev"] = at
        state["stagnant"] = state["stagnant"] + 1 if moved < .5 else 0
        if state["stagnant"] > 180:
            session["changes"].append(dict(game=round(game_time() - session["game_started"], 3), blocked=label,
                                           remaining=round(d)))
            return True
        session["pawn"].add_movement_input(u.Vector(dx / d, dy / d, 0), 1, False)
        return False
    when(fn)
    return state


def stop():
    for name in list(session["held_keys"]):
        key(name, False)
    monitor_stop()
    _flush()


# ------------------------------------------------------------------------------------------------------------ cameras

def chase_view(target, offset=(-180.0, -210.0, 120.0), fov=50.0):
    """Third-person view of target: a PIE CameraActor beside it becomes the view target. Shoot in a LATER call, then
    chase_back(). Phase H: the default offset is the Phase F one x 3.0 (the manifest scale_factor; was (-60, -70, 40))."""
    world = session["world"]
    loc = u.Vector(target[0] + offset[0], target[1] + offset[1], target[2] + offset[2])
    rot = u.MathLibrary.find_look_at_rotation(loc, u.Vector(*target))
    cam = session.get("chase_cam")
    if not cam or not u.SystemLibrary.is_valid(cam):
        # No PIE spawn path in Python: borrow the PIE copy of a review display actor (no collision), hide its mesh and
        # view through it (its eyes view point = actor location / rotation). The editor map is untouched.
        cam = next(a for a in u.GameplayStatics.get_all_actors_of_class(world, u.SkeletalMeshActor)
                   if a.get_actor_label().endswith("Display_HandHeight_SK"))
        cam.skeletal_mesh_component.set_visibility(False)
        session["chase_cam"] = cam
    cam.set_actor_location_and_rotation(loc, rot, False, True)
    session["pc"].set_view_target_with_blend(cam, 0.0)
    return str(loc)


def chase_back():
    session["pc"].set_view_target_with_blend(session["pawn"], 0.0)


def shoot_at_phase(label, phase, clip_time, index=0, placement=None, once=True):
    """Shot SHOWUI on the tick the index-th turnip is in phase (and placement) with its item clip past clip_time."""
    def fn():
        rows = turnips()
        if len(rows) <= index:
            return False
        r = rows[index]
        if r.get("phase") != phase or (placement and r.get("placement") != placement):
            return False
        at = r.get("at") or [0, 0, 0]
        near = [c for c in clips() if c.get("at") and abs(c["at"][0] - at[0]) < 2 and abs(c["at"][1] - at[1]) < 2]
        if not near or (near[0].get("t") or 0) < clip_time:
            return False
        path = screenshot(label)
        session["changes"].append(dict(game=round(game_time() - session["game_started"], 3), shot=label, turnip=r,
                                       clip=near[0]))
        return once
    when(fn)


HULL_CENTRE_UP = 20.25     # manifest gameplay_numbers.hull_centre_offset_from_root z (was 6.0 at 16 cm)


def mouth_view(index_at, distance=114.0, lift=24.0):
    """Chase view in front of the item clip's mouth (+X of the presentation) at clip location index_at (x, y).
    Phase H: distance / lift / centre are the Phase F ones x 3.0 (38 / 8 / 6 at 16 cm)."""
    c = min((c for c in clips() if c.get("at")), key=lambda c: (c["at"][0] - index_at[0]) ** 2 + (c["at"][1] - index_at[1]) ** 2)
    f, at = c["fwd"], c["at"]
    flat = math.hypot(f[0], f[1]) or 1.0
    centre = (at[0] + c["up"][0] * HULL_CENTRE_UP, at[1] + c["up"][1] * HULL_CENTRE_UP, at[2] + c["up"][2] * HULL_CENTRE_UP)
    off = (f[0] / flat * distance, f[1] / flat * distance, lift)
    return chase_view(centre, offset=off), c


def throw_during_inhale(inhale_at=0.3, lead=0.45, index=0):
    """F7: press Drop (R) lead seconds before the held turnip's next warning, release it inhale_at seconds into its Inhale
    (a held Drop past ThrowHoldSeconds throws). Both edges land on later ticks than the call."""
    state = dict(down=False)
    def fn():
        rows = turnips()
        if len(rows) <= index:
            return False
        r = rows[index]
        if not state["down"]:
            nw = r.get("next_warning")
            if r.get("placement") == "Held" and r.get("phase") == "RecoveryIdle" and nw not in (None, "unset") \
                    and float(nw) <= lead:
                key("R", True)
                state["down"] = True
            return False
        if r.get("phase") == "Inhale":
            c = [c for c in clips() if c.get("clip") == "ROOT_Inhale"]
            if c and (c[0].get("t") or 0) >= inhale_at:
                session["changes"].append(dict(game=round(game_time() - session["game_started"], 3),
                                               throw_release_state=r, clip=c[0]))
                key("R", False)
                return True
        return False
    when(fn)


# ------------------------------------------------------------------------------------------------------------ Phase G

def bed_params():
    """Each PIE bed script's launch: what the placed spawners actually construct with (a stored spawn param would keep
    an old default)."""
    out = []
    for b in _pie_objects(BED_CLASS):
        try:
            out.append(dict(bed=b.get_name(), launch=str(b.get_editor_property("ReleaseLaunch")),
                            spin=str(b.get_editor_property("ReleaseSpinDeg"))))
        except Exception as e:
            out.append(dict(bed=b.get_name(), error=str(e)))
    return out


def item_pose(near_xy=None):
    """The item presentation(s) (not the planted bed components): world location, up, forward (+X = the mouth), and the
    pose relative to near_xy (a bed's origin) when given. A root is 'mouth down' when fwd.z < -0.7, 'side' when |up.z| < 0.5."""
    rows = []
    for c in clips():
        if not c.get("at") or not c.get("visible") or (c.get("clip") or "").startswith("SRC_"):
            continue
        row = dict(c)
        if near_xy:
            row["rel"] = [round(c["at"][0] - near_xy[0], 1), round(c["at"][1] - near_xy[1], 1), c["at"][2]]
            row["dist"] = round(math.hypot(row["rel"][0], row["rel"][1]), 1)
        row["mouth"] = "down" if c["fwd"][2] < -0.7 else ("up" if c["fwd"][2] > 0.7 else "level")
        row["lying"] = "upright" if c["up"][2] > 0.5 else ("upside-down" if c["up"][2] < -0.5 else "side")
        rows.append(row)
    return rows


def view_forward():
    camera = u.GameplayStatics.get_player_camera_manager(session["world"], 0)
    f = camera.get_actor_forward_vector()
    return [round(f.x, 2), round(f.y, 2), round(f.z, 2)]


# ------------------------------------------------------------------------------------------------------------ Phase H

def sequence(steps, label="seq"):
    """Runs steps (callables returning True when done) one after another on later ticks; each step is polled every
    tick from the monitor. Returns the state dict (index, done)."""
    state = dict(index=0, done=False)
    def fn():
        if state["index"] >= len(steps):
            state["done"] = True
            session["changes"].append(dict(game=round(game_time() - session["game_started"], 3), sequence_done=label))
            return True
        if steps[state["index"]]():
            state["index"] += 1
        return False
    when(fn)
    return state


def step_wait(seconds):
    box = {}
    def fn():
        box.setdefault("start", game_time())
        return game_time() - box["start"] >= seconds
    return fn


def step_call(f):
    def fn():
        f()
        return True
    return fn


def step_walk(target, tolerance=30):
    box = {}
    def fn():
        if "state" not in box:
            box["state"] = walk_to(target, tolerance)
            return False
        return box["state"]["done"] or any(c.get("blocked") for c in session["changes"][-3:])
    return fn


def step_until(pred):
    return pred


def turnip_settled(index=0):
    def fn():
        rows = turnips()
        return len(rows) > index and rows[index].get("placement") == "LooseSettled"
    return fn


def harvest_steps(stand=(-110.0, 0.0), aim=(0.0, 0.0, 15.0), hold=1.8):
    """Walk to stand, aim at the bed, hold LMB for hold seconds (> the 1.4 s pull: Grip 0.4 + Tug 1.0 since Phase I),
    wait for the yield to settle."""
    return [step_walk(stand), step_call(lambda: aim_at(aim)), step_wait(0.2), step_call(lambda: key("LeftMouseButton", True)),
            step_wait(hold), step_call(lambda: key("LeftMouseButton", False)), turnip_settled(0)]


def morph_probe():
    """Item presentation clip, time and the anim instance's Inhale / Scream curve values (what drives the morphs in
    single-node mode), plus the component's manual GetMorphTarget map (0 by design for curve-driven morphs)."""
    out = []
    for c in _pie_objects(PRESENTATION_CLASS):
        try:
            if not c.get_owner():
                continue
            inst = c.get_anim_instance()
            asset, clip_t = clip_state(c)
            out.append(dict(clip=asset.get_name() if asset else None, t=round(clip_t, 3),
                            curve_inhale=round(inst.get_curve_value("Inhale"), 4) if inst else None,
                            curve_scream=round(inst.get_curve_value("Scream"), 4) if inst else None,
                            manual_inhale=c.get_morph_target("Inhale"), manual_scream=c.get_morph_target("Scream"),
                            disable_morph_target=c.get_editor_property("disable_morph_target"),
                            visible=c.is_visible()))
        except Exception as e:
            out.append(dict(error=str(e)))
    return out


def slomo(factor):
    """Global time dilation (the console's slomo): the motion clip runs the settled cycle slowed so that the capture's
    ~7 frames per real second sample the clips finely in game time."""
    u.SystemLibrary.execute_console_command(session["world"], "slomo %s" % factor, session["pc"])
    session["changes"].append(dict(game=round(game_time() - session["game_started"], 3), slomo=factor))
