"""Screaming Turnip R01 Phase J Part 3: the walk-away pull's per-tick evidence (run-05-walk), on top of screaming_turnip_pie_ue.

Run with normal PIE running in the review map, through Monolith `editor_query run_python`:

    import sys; sys.path.insert(0, r"D:/Repositories/CkRepos/Orion/Tools/LevelDesign/screaming_turnip_r01_review")
    import screaming_turnip_pie_ue as t, screaming_turnip_walk_ue as w
    t.begin("run-05-walk"); w.sample_start(); w.run_measure()     # then poll w.status(); w.finish() writes walk_rows.json

Per tick (`walk_rows.json`): game time, frame delta, the player's root (actor location; the pawn the Walk control's Puller
is the transform of), each visible planted presentation component (bed 0 at the origin, bed 1 at (450, -450)): clip,
position t, the component's world yaw, the HarvestGrip_R / _L sockets and the crown in world space; the glove bones
grip_r / grip_l; the interact prompt ring's Percent (the Control's progress toward EngageAlpha, Mars_InteractPrompt_Widget);
the bed readouts (charges / released). The bed's grip nodes are private ECS handles (no Python path): glove-to-socket is
the end-to-end measure, as in Phase I.

Movement: the pawn's own add_movement_input each tick (the walk_to pattern of screaming_turnip_pie_ue), scaled to the speed
asked, with the camera re-aimed at the bed every tick (Mars_ExpeditionAcceptance Aim), as a player backing off while
looking at the turnip.
"""

import json
import math

import unreal as u

import screaming_turnip_pie_ue as t

BED_XY = ((0.0, 0.0), (450.0, -450.0))
AIM_Z = 15.0
WALK_CM = 38.2               # constants_screaming_turnip_assets::k_StretchTravelCm (manifest gameplay_numbers)
TUG_LENGTH_S = 0.5           # SRC_Tug: 15 frames at 30 fps (clip readback length_s)
PROMPT_CLASS = "/Script/Angelscript.Mars_InteractPrompt_Widget"

state = globals().get("state") or {}
globals()["state"] = state


def _v(x):
    return [round(x.x, 3), round(x.y, 3), round(x.z, 3)]


def _gloves_comp():
    c = state.get("gloves")
    try:
        if c is not None and u.SystemLibrary.is_valid(c):
            return c
    except Exception:
        state.pop("gloves", None)
    for comp in u.ObjectIterator(u.SkeletalMeshComponent):
        if "UEDPIE" not in comp.get_path_name():
            continue
        try:
            if comp.get_bone_index("grip_r") != -1 and comp.get_bone_index("grip_l") != -1:
                state["gloves"] = comp
                return comp
        except Exception:
            pass
    return None


def _prompts():
    out = []
    try:
        cls = u.load_class(None, PROMPT_CLASS)
        world = t.session["world"]
        for wdg in u.ObjectIterator(cls):
            try:
                if wdg.get_world() != world or not wdg.is_visible():
                    continue
            except Exception:
                continue
            img = wdg.get_editor_property("Duration")
            if img is None:
                continue
            mid = img.get_dynamic_material()
            pct = mid.get_scalar_parameter_value("Percent") if mid else None
            out.append(dict(pct=None if pct is None else round(pct, 4), vis=str(img.get_visibility()).split(".")[-1],
                            shown=wdg.is_visible()))
    except Exception as e:
        out.append(dict(error=str(e)))
    return out


def _planted():
    out = {}
    for c in t._pie_objects(t.PRESENTATION_CLASS):
        try:
            if not c.get_owner():
                continue
            inst = c.get_anim_instance()
            clip_t, offset = None, None
            try:
                # Phase K: the AnimBlueprint instance's fields (Mars_ScreamingTurnip_AnimInstance), written by the component
                asset = inst.get_editor_property("Sequence")
                clip_t = inst.get_editor_property("ClipTime")
                offset = inst.get_editor_property("CrownOffset")
            except Exception:
                asset, clip_t = t.clip_state(c)
            name = asset.get_name().replace("ScreamingTurnip_R01_", "").replace("_Mars_ANIM", "") if asset else None
            if not name or not name.startswith("SRC_"):
                continue
            loc = c.get_world_location()
            bed = min(range(len(BED_XY)), key=lambda i: (loc.x - BED_XY[i][0]) ** 2 + (loc.y - BED_XY[i][1]) ** 2)
            fwd = c.get_forward_vector()
            out[bed] = dict(clip=name, t=round(clip_t, 4), vis=c.is_visible(),
                            offset=None if offset is None else _v(offset),
                            yaw=round(math.degrees(math.atan2(fwd.y, fwd.x)), 3),
                            sock_r=_v(c.get_socket_location("HarvestGrip_R")),
                            sock_l=_v(c.get_socket_location("HarvestGrip_L")),
                            crown=_v(c.get_socket_location("crown")), loc=_v(loc))
            try:
                out[bed]["rendered"] = c.was_recently_rendered(0.2)
            except Exception as e:
                out[bed]["rendered"] = str(e)[:60]
        except Exception as e:
            out.setdefault("errors", []).append(str(e))
    return out


INTENT_TAGS = {"use": "Mars.Intent.Interact.Use", "primary": "Mars.Intent.Interact.Primary"}


def _intents():
    """The player's gameplay intent rows (Use, Primary): phase and activation frame, read from the gameplay input profile's
    matcher. Path: the local player's Ck_InputSource_Subsystem -> its input source -> the input layer at the profile's
    priority 10 (Mars_Gameplay_InputProfile.as LayerPriority) -> Ck_Utils_IntentMatcher_UE.do_cast_checked -> get_intent_phase
    / try_get_activation_frame by tag."""
    M = u.Ck_Utils_IntentMatcher_UE
    m = state.get("matcher")
    try:
        if m is None:
            sub = [o for o in u.ObjectIterator(u.Ck_InputSource_Subsystem) if "Default__" not in o.get_path_name()][0]
            m = state["matcher"] = M.do_cast_checked(u.Ck_Utils_InputLayer_UE.try_get_layer_with_priority(sub.get_input_source(), 10))
            state["intent_tags"] = {}
            for k, n in INTENT_TAGS.items():
                tg = u.GameplayTag()
                tg.import_text('(TagName="%s")' % n)
                state["intent_tags"][k] = tg
        out = {}
        for k, tg in state["intent_tags"].items():
            out[k] = [str(M.get_intent_phase(m, tg)).split(".")[-1].split(":")[0], M.try_get_activation_frame(m, tg)]
        return out
    except Exception as e:
        state.pop("matcher", None)
        return {"error": str(e)[:120]}


def _focus_flags():
    """The bed readout's focused= per bed (Mars_ScreamingTurnipAcceptance.Bed: the interactable's Get_IsFocused)."""
    beds = state.get("bed_objs")
    if beds is None:
        beds = state["bed_objs"] = {}
        for b in t._pie_objects(t.BED_CLASS):
            txt = t.session["turnip"].call_method("Bed", args=(b,))
            if " at=" in txt:
                vals = [float(x.split("=")[1]) for x in txt.split(" at=")[-1].split()[:3]]
                i = min(range(len(BED_XY)), key=lambda k: math.hypot(vals[0] - BED_XY[k][0], vals[1] - BED_XY[k][1]))
                beds[i] = b
    out = {}
    for i, b in beds.items():
        try:
            txt = t.session["turnip"].call_method("Bed", args=(b,))
            out[i] = "focused=true" in txt
        except Exception as e:
            out[i] = str(e)[:40]
    return out


def sample():
    g = _gloves_comp()
    p = t.session["pawn"].get_actor_location()
    row = dict(game=round(t.game_time() - t.session["game_started"], 4),
               dt=round(u.GameplayStatics.get_world_delta_seconds(t.session["world"]), 4), player=_v(p),
               beds=_planted(), ring=_prompts(), keys=sorted(t.session["held_keys"]), phase=state.get("phase"))
    try:
        cm = u.GameplayStatics.get_player_camera_manager(t.session["world"], 0)
        cr = cm.get_camera_rotation()
        row["pitch"] = round(cr.pitch, 3)
        row["cam"] = _v(cm.get_camera_location()) + [round(cr.pitch, 3), round(cr.yaw, 3)]
    except Exception:
        pass
    if state.get("track_focus"):
        row["focused"] = _focus_flags()
    if state.get("track_intents"):
        row["intents"] = _intents()
    for i, b in enumerate(BED_XY):
        row["d%d" % i] = round(math.hypot(p.x - b[0], p.y - b[1]), 3)
    if g is not None:
        row["grip_r"], row["grip_l"] = _v(g.get_socket_location("grip_r")), _v(g.get_socket_location("grip_l"))
    state["rows"].append(row)
    return row


def sample_start():
    state.pop("gloves", None)
    state.pop("bed_objs", None)
    state.pop("matcher", None)
    state["rows"] = []
    state["shots"] = []
    state["marks"] = []
    state["stop"] = False

    def fn():
        if state.get("stop"):
            return True
        sample()
        return False
    t.when(fn)


def mark(label, **extra):
    rows = state.get("rows") or []
    row = dict(label=label, game=round(t.game_time() - t.session["game_started"], 4),
               last_row_game=rows[-1]["game"] if rows else None, **extra)
    state["marks"].append(row)
    t.session["changes"].append(dict(game=row["game"], mark=label))
    return row


def bed_text(i):
    for b in t._pie_objects(t.BED_CLASS):
        txt = t.session["turnip"].call_method("Bed", args=(b,))
        m = txt.split(" at=")[-1] if " at=" in txt else ""
        if m:
            vals = [float(x.split("=")[1]) for x in m.split()[:3]]
            if math.hypot(vals[0] - BED_XY[i][0], vals[1] - BED_XY[i][1]) < 5:
                return txt
    return None


# ------------------------------------------------------------------------------------------------------------ steps

def aim_bed(i):
    t.aim_at((BED_XY[i][0], BED_XY[i][1], AIM_Z))


def step_mark(label, **extra):
    return t.step_call(lambda: mark(label, **extra))


def step_bed_mark(i, label):
    return t.step_call(lambda: mark(label, bed=bed_text(i)))


def step_phase(name):
    def f():
        state["phase"] = name
    return t.step_call(f)


def step_move(i, speed_cms, until, radial=1.0, tangential=0.0, hold_radius=None, max_s=8.0, scale_per_cms=None):
    """Each tick: re-aim at bed i and add movement input along radial (away from the bed) + tangential (counter-clockwise
    seen from above) at an input scale giving speed_cms (calibrated: scale = speed / full speed, read from
    state['full_speed']). hold_radius: a radial correction that keeps the distance at that radius (a sidestep).
    until(row) ends the step; max_s caps it."""
    box = {}

    def fn():
        now = t.game_time()
        box.setdefault("start", now)
        rows = state.get("rows") or []
        if rows and until(rows[-1]):
            return True
        if now - box["start"] >= max_s:
            mark("move_timeout", bed=i)
            return True
        p = t.session["pawn"].get_actor_location()
        bx, by = BED_XY[i]
        dx, dy = p.x - bx, p.y - by
        d = math.hypot(dx, dy) or 1.0
        rx, ry = dx / d, dy / d
        tx, ty = -ry, rx
        r = radial
        hr = hold_radius() if callable(hold_radius) else hold_radius
        if hr is not None:
            r = max(-1.0, min(1.0, (hr - d) / 5.0))
        vx, vy = rx * r + tx * tangential, ry * r + ty * tangential
        n = math.hypot(vx, vy) or 1.0
        scale = min(1.0, speed_cms / state.get("full_speed", 300.0))
        t.session["pawn"].add_movement_input(u.Vector(vx / n, vy / n, 0.0), scale, False)
        aim_bed(i)
        return False
    return fn


def step_aim_hold(i, seconds):
    """Stand still, re-aiming at bed i every tick for seconds."""
    box = {}

    def fn():
        now = t.game_time()
        box.setdefault("start", now)
        aim_bed(i)
        return now - box["start"] >= seconds
    return fn


def alpha_of(row, i):
    b = row["beds"].get(i) or row["beds"].get(str(i))
    if not b:
        return None
    if b["clip"] == "SRC_Tug":
        return b["t"] / TUG_LENGTH_S
    return 0.0 if b["clip"] in ("SRC_Grip", "SRC_Idle") else None


def ring_alpha(row):
    vals = [r.get("pct") for r in row.get("ring") or [] if r.get("pct") is not None]
    return max(vals) * 0.97 if vals else None


def released(row, i):
    b = row["beds"].get(i) or row["beds"].get(str(i))
    return b is not None and b.get("vis") is False


# ------------------------------------------------------------------------------------------------------------ calibrate

def calibrate(seconds=1.0, scale=1.0, direction=(0.0, 1.0)):
    """Walk the pawn along direction at the input scale for seconds; full_speed = measured cm/s at scale 1."""
    box = {}

    def fn():
        now = t.game_time()
        p = t.session["pawn"].get_actor_location()
        if "start" not in box:
            box.update(start=now, p0=p)
        if now - box["start"] >= seconds:
            v = math.hypot(p.x - box["p0"].x, p.y - box["p0"].y) / (now - box["start"])
            state.setdefault("calib", []).append(dict(scale=scale, cms=round(v, 2)))
            return True
        t.session["pawn"].add_movement_input(u.Vector(direction[0], direction[1], 0.0), scale, False)
        return False
    return fn


# ------------------------------------------------------------------------------------------------------------ runs

STAND0 = (-80.0, -80.0)          # bed 0 from the -X/-Y diagonal: the planted root must turn 45 deg to face it
STAND1 = (450.0, -320.0)         # bed 1 from +Y: the planted root must turn -90 deg to face it


def run_measure(speed=30.0):
    """Session A (no screenshots: the clean numbers).
    Bed 0: grip from the diagonal, stand 0.7 s (the 0.4 s Grip, then begin), back off at `speed` until the root is out.
    Bed 1, pull 1: from +Y, back off to Tug alpha >= 0.5, let go (cancel), stand 2 s.
    Bed 1, pull 2: grip, back off to alpha >= 0.4, sidestep counter-clockwise round the bed at that radius for 2 s (the yaw
    follows), then back off to the break."""
    def tug_at_least(i, a):
        return lambda r: (alpha_of(r, i) or 0.0) >= a

    def gone(i):
        return lambda r: released(r, i)

    box = {}

    def side_radius():
        return box.get("r1")

    def remember_radius():
        box["r1"] = state["rows"][-1]["d1"]
        mark("sidestep_radius", r=box["r1"])

    s = [step_phase("walk0"), t.step_walk(STAND0, tolerance=8), step_aim_hold(0, 0.6), step_bed_mark(0, "bed0_before"),
         step_phase("grip0"), step_mark("use0_down"), t.step_call(lambda: t.key("LeftMouseButton", True)),
         step_aim_hold(0, 0.7), step_phase("back0"), step_mark("back0_start"),
         step_move(0, speed, gone(0), max_s=6.0), step_mark("bed0_gone"), step_phase("after0"),
         t.step_call(lambda: t.key("LeftMouseButton", False)), t.step_wait(1.5), step_bed_mark(0, "bed0_after"),
         step_phase("walk1"), t.step_walk(STAND1, tolerance=8), step_aim_hold(1, 0.6), step_bed_mark(1, "bed1_before"),
         step_phase("grip1a"), step_mark("use1a_down"), t.step_call(lambda: t.key("LeftMouseButton", True)),
         step_aim_hold(1, 0.7), step_phase("back1a"), step_move(1, speed, tug_at_least(1, 0.5), max_s=4.0),
         step_phase("cancel1a"), step_mark("use1a_up"), t.step_call(lambda: t.key("LeftMouseButton", False)),
         step_aim_hold(1, 2.0), step_bed_mark(1, "bed1_after_cancel"),
         step_phase("walk1b"), t.step_walk(STAND1, tolerance=8), step_aim_hold(1, 0.6),
         step_phase("grip1b"), step_mark("use1b_down"), t.step_call(lambda: t.key("LeftMouseButton", True)),
         step_aim_hold(1, 0.7), step_phase("back1b"), step_move(1, speed, tug_at_least(1, 0.4), max_s=4.0),
         t.step_call(remember_radius), step_phase("side1b"), step_mark("side1b_start"),
         step_move(1, speed, lambda r: False, tangential=1.0, radial=0.0, hold_radius=side_radius, max_s=2.0),
         step_phase("back1b_2"), step_mark("side1b_end"), step_move(1, speed, gone(1), max_s=6.0),
         step_mark("bed1_gone"), t.step_call(lambda: t.key("LeftMouseButton", False)), t.step_wait(1.5),
         step_bed_mark(1, "bed1_after"), step_phase("done")]
    state["seq"] = t.sequence(s, "run-05-walk")
    return state["seq"]


def status():
    rows = state.get("rows") or []
    seq = state.get("seq") or {}
    return dict(seq=dict(index=seq.get("index"), done=seq.get("done")), rows=len(rows), phase=state.get("phase"),
                last=rows[-1] if rows else None, marks=state.get("marks"), calib=state.get("calib"))


def finish(name="walk_rows.json"):
    state["stop"] = True
    path = t.folder() / name
    path.write_text(json.dumps(dict(rows=state["rows"], shots=state["shots"], marks=state["marks"],
                                    calib=state.get("calib"), full_speed=state.get("full_speed"), morph=state.get("morph")),
                                    indent=0))
    t.stop()
    return str(path)


# ------------------------------------------------------------------------------------------------------------ captures

def shot(label):
    rows = state.get("rows") or []
    t.screenshot(label)
    state["shots"].append(dict(label=label, row=rows[-1] if rows else None))
    t.session["changes"].append(dict(game=round(t.game_time() - t.session["game_started"], 3), shot=label))


def step_shot(label):
    return t.step_call(lambda: shot(label))


def step_until(pred, max_s=10.0):
    box = {}

    def fn():
        box.setdefault("start", t.game_time())
        rows = state.get("rows") or []
        return (rows and pred(rows[-1])) or t.game_time() - box["start"] >= max_s
    return fn


def step_view(fn_target):
    """Switch to a chase view computed at run time: fn_target() -> (target, offset, fov)."""
    def f():
        target, offset, fov = fn_target()
        t.chase_view(target, offset=offset, fov=fov)
    return t.step_call(f)


def facing(i):
    """Unit XY vector from bed i toward the player (the planted root's -X once turned)."""
    p = t.session["pawn"].get_actor_location()
    dx, dy = p.x - BED_XY[i][0], p.y - BED_XY[i][1]
    n = math.hypot(dx, dy) or 1.0
    return dx / n, dy / n


def side_view(i, along_cm, dist_cm, fov, z=12.0, lift=10.0):
    """A camera dist_cm to the side of bed i's pull axis, looking at the point along_cm toward the player."""
    def f():
        fx, fy = facing(i)
        px, py = fy, -fx
        tgt = (BED_XY[i][0] + fx * along_cm, BED_XY[i][1] + fy * along_cm, z)
        return tgt, (px * dist_cm, py * dist_cm, lift), fov
    return f


def run_captures(speed=30.0, slomo=0.25):
    """Session B (screenshots, slomo: no timing claims). Bed 0 from the diagonal: first-person shots at alpha 0.3 / 0.7,
    a hold short of the break (want 0.9) with a first-person shot, a side shot, a bulb-at-the-edge side shot and a
    bind-bounds-out-of-frustum side shot; then on to the break (a shot at alpha >= 0.94) and after the release. Bed 1 from
    +Y: back to 0.5, shots, let go, shots through the cancel; pull 2: back to 0.45, a sidestep with a top-side view shot
    before and after it, then back off to the break."""
    def a_at_least(i, a):
        return lambda r: (alpha_of(r, i) or 0.0) >= a

    def want_at_least(i, a, d0box):
        return lambda r: (r["d%d" % i] - d0box["d0"]) / WALK_CM >= a

    def gone(i):
        return lambda r: released(r, i)

    d0 = {}

    def keep_d0(i):
        def f():
            d0["d0"] = state["rows"][-1]["d%d" % i]
            mark("d0", bed=i, d0=d0["d0"])
        return t.step_call(f)

    s = [t.step_call(lambda: t.slomo(slomo)), step_phase("walk0"), t.step_walk(STAND0, tolerance=8), step_aim_hold(0, 0.3),
         keep_d0(0), step_mark("use0_down"), t.step_call(lambda: t.key("LeftMouseButton", True)), step_aim_hold(0, 0.15),
         step_shot("J0_grip_fp"), step_aim_hold(0, 0.6), step_phase("back0"),
         step_move(0, speed, a_at_least(0, 0.3), max_s=6.0), step_shot("J1_alpha03_fp"),
         step_move(0, speed, a_at_least(0, 0.7), max_s=6.0), step_shot("J2_alpha07_fp"),
         step_move(0, speed, want_at_least(0, 0.9, d0), max_s=6.0), step_phase("hold0"), step_aim_hold(0, 1.0),
         step_shot("J3_full_strain_fp"), step_aim_hold(0, 0.1),
         step_view(side_view(0, 15.0, 170.0, 50.0, z=18.0, lift=25.0)), step_aim_hold(0, 0.1), step_shot("J4_full_strain_side"),
         step_aim_hold(0, 0.1), step_view(side_view(0, 50.0, 120.0, 40.0)), step_aim_hold(0, 0.1),
         step_shot("J5a_bulb_at_edge_side"), step_aim_hold(0, 0.1), step_view(side_view(0, 75.0, 120.0, 30.0)),
         step_aim_hold(0, 0.1), step_shot("J5b_bind_bounds_out_of_view_side"), step_aim_hold(0, 0.1),
         t.step_call(t.chase_back), step_aim_hold(0, 0.2), step_phase("back0b"),
         step_move(0, speed, a_at_least(0, 0.94), max_s=6.0), step_shot("J6_break_fp"),
         step_move(0, speed, gone(0), max_s=4.0), step_mark("bed0_gone"),
         t.step_call(lambda: t.key("LeftMouseButton", False)), step_aim_hold(0, 0.6), step_shot("J7_after_release_fp"),
         step_aim_hold(0, 1.0), step_bed_mark(0, "bed0_after"),
         step_phase("walk1"), t.step_walk(STAND1, tolerance=8), step_aim_hold(1, 0.3), keep_d0(1),
         step_mark("use1a_down"), t.step_call(lambda: t.key("LeftMouseButton", True)), step_aim_hold(1, 0.7),
         step_phase("back1a"), step_move(1, speed, a_at_least(1, 0.5), max_s=6.0), step_shot("J8_bed1_alpha05_fp"),
         step_aim_hold(1, 0.05), step_mark("use1a_up"), t.step_call(lambda: t.key("LeftMouseButton", False)),
         step_phase("cancel1a"), step_aim_hold(1, 0.06), step_shot("J9_cancel_early_fp"), step_aim_hold(1, 0.12),
         step_shot("J10_cancel_mid_fp"), step_aim_hold(1, 1.0), step_shot("J11_cancel_done_fp"),
         step_bed_mark(1, "bed1_after_cancel"),
         step_phase("walk1b"), t.step_walk(STAND1, tolerance=8), step_aim_hold(1, 0.3), keep_d0(1),
         step_mark("use1b_down"), t.step_call(lambda: t.key("LeftMouseButton", True)), step_aim_hold(1, 0.7),
         step_phase("back1b"), step_move(1, speed, a_at_least(1, 0.45), max_s=6.0), step_aim_hold(1, 0.5),
         step_view(lambda: ((BED_XY[1][0], BED_XY[1][1], 10.0), (0.0, -1.0, 220.0), 60.0)), step_aim_hold(1, 0.1),
         step_shot("J12_sidestep_before_top"), step_aim_hold(1, 0.1), t.step_call(t.chase_back), step_aim_hold(1, 0.1),
         t.step_call(lambda: state.update(side_r=state["rows"][-1]["d1"])), step_phase("side1b"), step_mark("side1b_start"),
         step_move(1, speed, lambda r: False, tangential=1.0, radial=0.0, hold_radius=lambda: state.get("side_r"),
                   max_s=2.5),
         step_mark("side1b_end"), step_aim_hold(1, 0.4),
         step_view(lambda: ((BED_XY[1][0], BED_XY[1][1], 10.0), (0.0, -1.0, 220.0), 60.0)), step_aim_hold(1, 0.1),
         step_shot("J13_sidestep_after_top"), step_aim_hold(1, 0.1), t.step_call(t.chase_back), step_aim_hold(1, 0.1),
         step_phase("back1b_2"), step_move(1, speed, gone(1), max_s=8.0), step_mark("bed1_gone"),
         t.step_call(lambda: t.key("LeftMouseButton", False)), step_aim_hold(1, 1.0), step_bed_mark(1, "bed1_after"),
         t.step_call(lambda: t.slomo(1.0)), step_phase("done")]
    state["seq"] = t.sequence(s, "run-05-walk-shots")
    return state["seq"]


def clip_drive_walk(label="run-05-walk-clip", speed=30.0, hold_want=0.9):
    """Inside capture_pie_movement_clip (python_script at start, or a probe): bed 0's walk pull seen from a side camera
    170 cm off the pull axis; a hold short of the break (want 0.9) with two close side views 25 cm off the axis (the chase
    view keeps the player camera's FOV, so the frame is placed by distance): 'edge' looks at 40 cm toward the player (the
    bulb at the frame's edge), 'out' at 60 cm (the frame starts about 35 cm toward the player: the bind bounds, which end
    17.7 cm toward the player, are outside it; the extended bounds reach 64.7 cm, the leaves about 58). Then back to the
    side view and on to the break. Scene-only frames (no HUD). The view phases are marked in walk_rows.json.
    Under the capture each frame is about 0.2 s of game time, so a 30 cm/s walk overshoots the hold by a frame (6 cm): the
    first clip (run-05-walk-clip) broke the root before the close views; run-05-walk-clip-edge uses speed 15, hold_want 0.8."""
    state.clear()
    t.begin(label, check_throttle=False)
    state["full_speed"] = 400.0
    sample_start()
    d0 = {}

    def keep_d0():
        d0["d0"] = state["rows"][-1]["d0"]
        mark("d0", d0=d0["d0"], fov=u.GameplayStatics.get_player_camera_manager(t.session["world"], 0).get_fov_angle())

    wide = side_view(0, 15.0, 170.0, 0.0, z=18.0, lift=25.0)
    s = [step_phase("walk0"), t.step_walk(STAND0, tolerance=8), step_aim_hold(0, 0.3), t.step_call(keep_d0),
         step_view(wide), step_phase("view_wide"), step_mark("use0_down"),
         t.step_call(lambda: t.key("LeftMouseButton", True)), step_aim_hold(0, 0.7),
         step_move(0, speed, lambda r: (r["d0"] - d0["d0"]) / WALK_CM >= hold_want, max_s=12.0), step_phase("hold"),
         step_aim_hold(0, 1.5),
         step_view(side_view(0, 40.0, 25.0, 0.0, z=12.0, lift=8.0)), step_phase("view_edge"), step_aim_hold(0, 1.5),
         step_view(side_view(0, 60.0, 25.0, 0.0, z=12.0, lift=8.0)), step_phase("view_out"), step_aim_hold(0, 1.5),
         step_view(wide), step_phase("view_wide_2"), step_aim_hold(0, 0.5),
         step_move(0, speed, lambda r: released(r, 0), max_s=6.0), step_mark("bed0_gone"),
         t.step_call(lambda: t.key("LeftMouseButton", False)), step_aim_hold(0, 1.5), step_phase("done"),
         t.step_call(lambda: finish())]
    state["seq"] = t.sequence(s, label)
    return state["seq"]


# ------------------------------------------------------------------------------------------------------------ Part 3b

def step_approach(target, i, speed=40.0, tol=1.5, max_s=6.0):
    """A slow final approach to target (x, y) at speed cm/s, re-aiming at bed i; ends within tol cm."""
    box = {}

    def fn():
        now = t.game_time()
        box.setdefault("start", now)
        p = t.session["pawn"].get_actor_location()
        dx, dy = target[0] - p.x, target[1] - p.y
        d = math.hypot(dx, dy)
        aim_bed(i)
        if d <= tol or now - box["start"] >= max_s:
            mark("stand", bed=i, at=[round(p.x, 2), round(p.y, 2)], off=round(d, 2))
            return True
        scale = min(1.0, speed / state.get("full_speed", 400.0))
        t.session["pawn"].add_movement_input(u.Vector(dx / d, dy / d, 0.0), scale, False)
        return False
    return fn


STAND0_110 = (-77.782, -77.782)  # bed 0 at 110 cm on the -X/-Y diagonal (the root turns 45 deg)
STAND1_110 = (450.0, -340.0)     # bed 1 at 110 cm on +Y (the root turns -90 deg)


def run_06(speed=30.0, slomo=0.25, label="run-06-walk", let_go=0.55, side=(10.0, 130.0), speed2=None):
    """Part 3b (run-06-walk): every pull from a 110 cm stand, slomo for fine rows. Bed 0: prompt shot, Use, grip shot,
    back off with first-person shots at alpha 0.3 / 0.7, a hold near full strain (want 0.92) with a first-person and a side
    shot, then on to the break (shot at alpha >= 0.94) and after the release. Bed 1: Use, back off to alpha 0.55, let go
    (cancel shots), then a second pull to the break."""
    def a_at_least(i, a):
        return lambda r: (alpha_of(r, i) or 0.0) >= a

    def gone(i):
        """Released, or the pull dropped (SRC_Cancel while Use is held: the focus lost); the drop is marked with the
        distance and the camera pitch."""
        def f(r):
            if released(r, i):
                return True
            b = r["beds"].get(i) or r["beds"].get(str(i)) or {}
            if b.get("clip") == "SRC_Cancel" and "LeftMouseButton" in r["keys"]:
                mark("pull_dropped", bed=i, d=r["d%d" % i], pitch=r.get("pitch"), ring=r.get("ring"))
                return True
            return False
        return f

    d0 = {}

    def keep_d0(i):
        def f():
            d0[i] = state["rows"][-1]["d%d" % i]
            mark("d0", bed=i, d0=d0[i], walk_cm=WALK_CM)
        return t.step_call(f)

    def want_at_least(i, a):
        return lambda r: (r["d%d" % i] - d0[i]) / WALK_CM >= a

    s = [t.step_call(lambda: t.slomo(slomo)),
         step_phase("walk0"), t.step_walk(STAND0_110, tolerance=25), step_approach(STAND0_110, 0), step_aim_hold(0, 0.6), keep_d0(0),
         step_shot("K0_prompt_fp"), step_aim_hold(0, 0.1),
         step_phase("grip0"), step_mark("use0_down"), t.step_call(lambda: t.key("LeftMouseButton", True)),
         step_aim_hold(0, 0.35), step_shot("K1_grip_fp"), step_aim_hold(0, 0.45),
         step_phase("back0"), step_move(0, speed, a_at_least(0, 0.3), max_s=8.0), step_shot("K2_alpha03_fp"),
         step_move(0, speed, a_at_least(0, 0.7), max_s=8.0), step_shot("K3_alpha07_fp"),
         step_move(0, speed, want_at_least(0, 0.92), max_s=8.0), step_phase("hold0"), step_aim_hold(0, 1.0),
         step_shot("K4_full_strain_fp"), step_aim_hold(0, 0.1), step_shot("K4b_full_strain_fp_again"), step_aim_hold(0, 0.1),
         step_view(side_view(0, side[0], side[1], 0.0, z=10.0, lift=20.0)), step_aim_hold(0, 0.1),
         step_shot("K5_full_strain_side"), step_aim_hold(0, 0.1), t.step_call(t.chase_back), step_aim_hold(0, 0.2),
         step_phase("back0b"), step_move(0, speed, lambda r: a_at_least(0, 0.94)(r) or gone(0)(r), max_s=8.0),
         step_shot("K6_break_fp"), step_move(0, speed, gone(0), max_s=6.0), step_mark("bed0_gone"),
         t.step_call(lambda: t.key("LeftMouseButton", False)), step_aim_hold(0, 0.5), step_shot("K7_after_release_fp"),
         step_aim_hold(0, 1.0), step_bed_mark(0, "bed0_after"),
         step_phase("walk1"), t.step_walk(STAND1_110, tolerance=25), step_approach(STAND1_110, 1), step_aim_hold(1, 0.6), keep_d0(1),
         step_phase("grip1a"), step_mark("use1a_down"), t.step_call(lambda: t.key("LeftMouseButton", True)),
         step_aim_hold(1, 0.8), step_phase("back1a"), step_move(1, speed, a_at_least(1, let_go), max_s=8.0),
         step_shot("K8_bed1_letgo_fp"), step_aim_hold(1, 0.05),
         step_phase("cancel1a"), step_mark("use1a_up"), t.step_call(lambda: t.key("LeftMouseButton", False)),
         step_aim_hold(1, 0.1), step_shot("K9_cancel_early_fp"), step_aim_hold(1, 1.5), step_shot("K10_cancel_done_fp"),
         step_bed_mark(1, "bed1_after_cancel"),
         step_phase("walk1b"), t.step_walk(STAND1_110, tolerance=25), step_approach(STAND1_110, 1), step_aim_hold(1, 0.6), keep_d0(1),
         step_phase("grip1b"), step_mark("use1b_down"), t.step_call(lambda: t.key("LeftMouseButton", True)),
         step_aim_hold(1, 0.8), step_phase("back1b"), step_move(1, speed2 or speed, gone(1), max_s=12.0), step_mark("bed1_gone"),
         t.step_call(lambda: t.key("LeftMouseButton", False)), step_aim_hold(1, 1.0), step_bed_mark(1, "bed1_after"),
         t.step_call(lambda: t.slomo(1.0)), step_phase("done")]
    state["seq"] = t.sequence(s, label)
    return state["seq"]


def clip_drive_06(label="run-06-walk-clip", speed=30.0, walk_cm=None):
    """capture_pie_movement_clip probe: bed 0's pull from the 110 cm stand, a wide side view, to the break."""
    global WALK_CM
    if walk_cm:
        WALK_CM = walk_cm
    state.clear()
    t.begin(label, check_throttle=False)
    state["full_speed"] = 400.0
    sample_start()
    wide = side_view(0, 40.0, 220.0, 0.0, z=15.0, lift=30.0)
    s = [step_phase("walk0"), t.step_walk(STAND0_110, tolerance=25), step_approach(STAND0_110, 0), step_aim_hold(0, 0.5), step_view(wide),
         step_phase("view_wide"), step_mark("use0_down"), t.step_call(lambda: t.key("LeftMouseButton", True)),
         step_aim_hold(0, 0.8), step_move(0, speed, lambda r: released(r, 0), max_s=16.0), step_mark("bed0_gone"),
         t.step_call(lambda: t.key("LeftMouseButton", False)), step_aim_hold(0, 1.5), step_phase("done"),
         t.step_call(lambda: finish())]
    state["seq"] = t.sequence(s, label)
    return state["seq"]


def run_09(slomo=0.25, label="run-09-walk", fast=400.0, slow=30.0):
    """Part 3e (the bed's spring 400 / 40): bed 0 one pull at full backward speed (input scale 1.0) to the break, with
    first-person shots at the grip, mid-walk and the break and one side shot mid-walk; bed 1: full speed to target 0.5,
    stop and hold 1 s (overshoot / settle), let go (cancel), then a slow (30 cm/s) pull to the break."""
    d0 = {}

    def keep_d0(i):
        def f():
            d0[i] = state["rows"][-1]["d%d" % i]
            mark("d0", bed=i, d0=d0[i], walk_cm=WALK_CM)
        return t.step_call(f)

    def walked_at_least(i, cm):
        return lambda r: r["d%d" % i] - d0[i] >= cm or released(r, i)

    def want_at_least(i, a):
        return lambda r: (r["d%d" % i] - d0[i]) / WALK_CM >= a

    def a_at_least(i, a):
        return lambda r: (alpha_of(r, i) or 0.0) >= a or released(r, i)

    def gone(i):
        return lambda r: released(r, i)

    s = [t.step_call(lambda: t.slomo(slomo)),
         step_phase("walk0"), t.step_walk(STAND0_110, tolerance=25), step_approach(STAND0_110, 0), step_aim_hold(0, 0.6),
         keep_d0(0), step_phase("grip0"), step_mark("use0_down"), t.step_call(lambda: t.key("LeftMouseButton", True)),
         step_aim_hold(0, 0.35), step_shot("L1_grip_fp"), step_aim_hold(0, 0.45),
         step_phase("fast0"), step_mark("fast0_start"), step_move(0, fast, walked_at_least(0, 70.0), max_s=4.0),
         step_shot("L2_midwalk_fp"),
         step_move(0, fast, walked_at_least(0, 95.0), max_s=4.0), step_view(side_view(0, 70.0, 260.0, 0.0, z=10.0, lift=40.0)),
         step_move(0, fast, walked_at_least(0, 110.0), max_s=4.0), step_shot("L3_midwalk_side"),
         step_move(0, fast, walked_at_least(0, 120.0), max_s=4.0), t.step_call(t.chase_back),
         step_move(0, fast, a_at_least(0, 0.94), max_s=4.0), step_shot("L4_break_fp"),
         step_move(0, fast, gone(0), max_s=4.0), step_mark("bed0_gone"), step_phase("after0"),
         t.step_call(lambda: t.key("LeftMouseButton", False)), step_aim_hold(0, 1.0), step_bed_mark(0, "bed0_after"),
         step_phase("walk1"), t.step_walk(STAND1_110, tolerance=25), step_approach(STAND1_110, 1), step_aim_hold(1, 0.6),
         keep_d0(1), step_phase("grip1a"), step_mark("use1a_down"), t.step_call(lambda: t.key("LeftMouseButton", True)),
         step_aim_hold(1, 0.8), step_phase("fast1a"), step_move(1, fast, want_at_least(1, 0.5), max_s=4.0),
         step_phase("stop1a"), step_mark("stop1a"), step_aim_hold(1, 1.0), step_mark("use1a_up"),
         step_phase("cancel1a"), t.step_call(lambda: t.key("LeftMouseButton", False)), step_aim_hold(1, 1.5),
         step_bed_mark(1, "bed1_after_cancel"),
         step_phase("walk1b"), t.step_walk(STAND1_110, tolerance=25), step_approach(STAND1_110, 1), step_aim_hold(1, 0.6),
         keep_d0(1), step_phase("grip1b"), step_mark("use1b_down"), t.step_call(lambda: t.key("LeftMouseButton", True)),
         step_aim_hold(1, 0.8), step_phase("slow1b"), step_move(1, slow, gone(1), max_s=14.0), step_mark("bed1_gone"),
         t.step_call(lambda: t.key("LeftMouseButton", False)), step_aim_hold(1, 1.0), step_bed_mark(1, "bed1_after"),
         t.step_call(lambda: t.slomo(1.0)), step_phase("done")]
    state["seq"] = t.sequence(s, label)
    return state["seq"]


def run_10(label="run-10-walk", fast=400.0):
    """Part 3e supplement: run-09's bed 0 full-speed pull released early on a screenshot's long tick (the spring's single
    step overshoots, phaseJ/run09_spring_step.txt). Bed 0: the full-speed pull with NO screenshots (slomo 0.25), the clean
    walked-at-break. Bed 1: the full-speed pull with the captures, at slomo 0.1 so a screenshot tick stays short in game
    time (about 0.04 s)."""
    d0 = {}

    def keep_d0(i):
        def f():
            d0[i] = state["rows"][-1]["d%d" % i]
            mark("d0", bed=i, d0=d0[i], walk_cm=WALK_CM)
        return t.step_call(f)

    def walked_at_least(i, cm):
        return lambda r: r["d%d" % i] - d0[i] >= cm or released(r, i)

    def a_at_least(i, a):
        return lambda r: (alpha_of(r, i) or 0.0) >= a or released(r, i)

    def gone(i):
        return lambda r: released(r, i)

    s = [t.step_call(lambda: t.slomo(0.25)),
         step_phase("walk0"), t.step_walk(STAND0_110, tolerance=25), step_approach(STAND0_110, 0), step_aim_hold(0, 0.6),
         keep_d0(0), step_phase("grip0"), step_mark("use0_down"), t.step_call(lambda: t.key("LeftMouseButton", True)),
         step_aim_hold(0, 0.8), step_phase("fast0"), step_mark("fast0_start"), step_move(0, fast, gone(0), max_s=4.0),
         step_mark("bed0_gone"), t.step_call(lambda: t.key("LeftMouseButton", False)), step_aim_hold(0, 1.0),
         step_bed_mark(0, "bed0_after"),
         step_phase("walk1"), t.step_walk(STAND1_110, tolerance=25), step_approach(STAND1_110, 1), step_aim_hold(1, 0.6),
         t.step_call(lambda: t.slomo(0.1)), keep_d0(1), step_phase("grip1"), step_mark("use1_down"),
         t.step_call(lambda: t.key("LeftMouseButton", True)), step_aim_hold(1, 0.35), step_shot("M1_grip_fp"),
         step_aim_hold(1, 0.45), step_phase("fast1"), step_mark("fast1_start"),
         step_move(1, fast, walked_at_least(1, 60.0), max_s=4.0), step_shot("M2_midwalk_fp"),
         step_move(1, fast, walked_at_least(1, 80.0), max_s=4.0),
         step_view(lambda: ((BED_XY[1][0], BED_XY[1][1] + 70.0, 15.0), (260.0, 0.0, 40.0), 0.0)),
         step_move(1, fast, walked_at_least(1, 100.0), max_s=4.0), step_shot("M3_midwalk_side"),
         step_move(1, fast, walked_at_least(1, 115.0), max_s=4.0), t.step_call(t.chase_back),
         step_move(1, fast, a_at_least(1, 0.94), max_s=4.0), step_shot("M4_break_fp"),
         step_move(1, fast, gone(1), max_s=4.0), step_mark("bed1_gone"),
         t.step_call(lambda: t.key("LeftMouseButton", False)), step_aim_hold(1, 0.5), step_shot("M5_after_release_fp"),
         step_aim_hold(1, 0.5), step_bed_mark(1, "bed1_after"), t.step_call(lambda: t.slomo(1.0)), step_phase("done")]
    state["seq"] = t.sequence(s, label)
    return state["seq"]


def run_10b(label="run-10b-walk", fast=400.0):
    """Part 3e: the side view mid-walk at full speed (run-10's bed 1 side camera stood outside the room): bed 0 at slomo
    0.1, a side shot at about 100 cm walked (the run-08 K5 framing), then first person to the break."""
    d0 = {}

    def keep_d0():
        d0[0] = state["rows"][-1]["d0"]
        mark("d0", bed=0, d0=d0[0])

    s = [t.step_call(lambda: t.slomo(0.1)), step_phase("walk0"), t.step_walk(STAND0_110, tolerance=25),
         step_approach(STAND0_110, 0), step_aim_hold(0, 0.6), t.step_call(keep_d0), step_mark("use0_down"),
         t.step_call(lambda: t.key("LeftMouseButton", True)), step_aim_hold(0, 0.8), step_phase("fast0"),
         step_mark("fast0_start"), step_move(0, fast, lambda r: r["d0"] - d0[0] >= 80.0 or released(r, 0), max_s=4.0),
         step_view(side_view(0, 70.0, 260.0, 0.0, z=10.0, lift=40.0)),
         step_move(0, fast, lambda r: r["d0"] - d0[0] >= 100.0 or released(r, 0), max_s=4.0), step_shot("N3_midwalk_side"),
         step_move(0, fast, lambda r: r["d0"] - d0[0] >= 110.0 or released(r, 0), max_s=4.0), t.step_call(t.chase_back),
         step_move(0, fast, lambda r: released(r, 0), max_s=4.0), step_mark("bed0_gone"),
         t.step_call(lambda: t.key("LeftMouseButton", False)), step_aim_hold(0, 0.5), step_bed_mark(0, "bed0_after"),
         t.step_call(lambda: t.slomo(1.0)), step_phase("done")]
    state["seq"] = t.sequence(s, label)
    return state["seq"]


def run_11(label="run-11-walk", fast=400.0, slow=30.0):
    """Part 3f (the Control's substepped spring): bed 0 the full-speed pull WITH first-person screenshots at normal time
    (slomo 1: the screenshot ticks are long, as the ones that popped run-09); bed 1 as run-09 (slomo 0.25): full speed to
    target 0.5, stop 1 s, let go, then a slow pull to the break."""
    d0 = {}

    def keep_d0(i):
        def f():
            d0[i] = state["rows"][-1]["d%d" % i]
            mark("d0", bed=i, d0=d0[i], walk_cm=WALK_CM)
        return t.step_call(f)

    def walked_at_least(i, cm):
        return lambda r: r["d%d" % i] - d0[i] >= cm or released(r, i)

    def want_at_least(i, a):
        return lambda r: (r["d%d" % i] - d0[i]) / WALK_CM >= a

    def a_at_least(i, a):
        return lambda r: (alpha_of(r, i) or 0.0) >= a or released(r, i)

    def gone(i):
        return lambda r: released(r, i)

    s = [t.step_call(lambda: t.slomo(1.0)),
         step_phase("walk0"), t.step_walk(STAND0_110, tolerance=25), step_approach(STAND0_110, 0), step_aim_hold(0, 0.6),
         keep_d0(0), step_phase("grip0"), step_mark("use0_down"), t.step_call(lambda: t.key("LeftMouseButton", True)),
         step_aim_hold(0, 0.35), step_shot("P1_grip_fp"), step_aim_hold(0, 0.45),
         step_phase("fast0"), step_mark("fast0_start"), step_move(0, fast, walked_at_least(0, 70.0), max_s=4.0),
         step_shot("P2_midwalk_fp"), step_move(0, fast, walked_at_least(0, 110.0), max_s=4.0), step_shot("P3_midwalk_fp"),
         step_move(0, fast, a_at_least(0, 0.94), max_s=4.0), step_shot("P4_break_fp"),
         step_move(0, fast, gone(0), max_s=4.0), step_mark("bed0_gone"), step_phase("after0"),
         t.step_call(lambda: t.key("LeftMouseButton", False)), step_aim_hold(0, 1.0), step_bed_mark(0, "bed0_after"),
         t.step_call(lambda: t.slomo(0.25)),
         step_phase("walk1"), t.step_walk(STAND1_110, tolerance=25), step_approach(STAND1_110, 1), step_aim_hold(1, 0.6),
         keep_d0(1), step_phase("grip1a"), step_mark("use1a_down"), t.step_call(lambda: t.key("LeftMouseButton", True)),
         step_aim_hold(1, 0.8), step_phase("fast1a"), step_move(1, fast, want_at_least(1, 0.5), max_s=4.0),
         step_phase("stop1a"), step_mark("stop1a"), step_aim_hold(1, 1.0), step_mark("use1a_up"),
         step_phase("cancel1a"), t.step_call(lambda: t.key("LeftMouseButton", False)), step_aim_hold(1, 1.5),
         step_bed_mark(1, "bed1_after_cancel"),
         step_phase("walk1b"), t.step_walk(STAND1_110, tolerance=25), step_approach(STAND1_110, 1), step_aim_hold(1, 0.6),
         keep_d0(1), step_phase("grip1b"), step_mark("use1b_down"), t.step_call(lambda: t.key("LeftMouseButton", True)),
         step_aim_hold(1, 0.8), step_phase("slow1b"), step_move(1, slow, gone(1), max_s=14.0), step_mark("bed1_gone"),
         t.step_call(lambda: t.key("LeftMouseButton", False)), step_aim_hold(1, 1.0), step_bed_mark(1, "bed1_after"),
         t.step_call(lambda: t.slomo(1.0)), step_phase("done")]
    state["seq"] = t.sequence(s, label)
    return state["seq"]



# ------------------------------------------------------------------------------------------------------------ Phase K

def run_12(slow=30.0, t1=74.0, t2=146.2):
    """Phase K Part 3 (run-12, slomo 0.25): the stretch is a bed tuner (bed 0 TravelCm t1, bed 1 t2) applied by the ABP.
    Bed 0: grip, slow back-off with first-person shots at the grip / mid (alpha 0.5) / full strain (hold at target 0.92) and
    a side shot, then to the break. Bed 1: grip, back off to alpha 0.5, let go (the cancel, shots), then a second pull to a
    hold at 0.92: a first-person shot, a side shot, a close side view with the bulb off-screen (rendered flag sampled), then
    the break. Then the bed-0 root: walk to it, pick it up (Use tap), hold it until it screams (shot at Scream)."""
    d0 = {}

    def keep_d0(i):
        def f():
            d0[i] = state["rows"][-1]["d%d" % i]
            mark("d0", bed=i, d0=d0[i])
        return t.step_call(f)

    def want_at_least(i, a, travel):
        return lambda r: (r["d%d" % i] - d0[i]) / travel >= a or released(r, i)

    def a_at_least(i, a):
        return lambda r: (alpha_of(r, i) or 0.0) >= a or released(r, i)

    def gone(i):
        return lambda r: released(r, i)

    def side(i, travel):
        return side_view(i, travel * 0.5, travel * 1.2 + 60.0, 0.0, z=10.0, lift=25.0)

    root = {}

    def find_root():
        rows = t.turnips()
        if rows and rows[0].get("at"):
            root["at"] = rows[0]["at"]
            mark("root_at", at=root["at"], placement=rows[0].get("placement"), phase=rows[0].get("phase"))
            return True
        return False

    def walk_to_root():
        box = {}

        def fn():
            if "st" not in box:
                at = root["at"]
                p = t.session["pawn"].get_actor_location()
                dx, dy = at[0] - p.x, at[1] - p.y
                n = math.hypot(dx, dy) or 1.0
                box["st"] = t.walk_to((at[0] - dx / n * 90.0, at[1] - dy / n * 90.0), 10)
                return False
            return box["st"]["done"] or any(c.get("blocked") for c in t.session["changes"][-3:])
        return fn

    def aim_root():
        t.aim_at((root["at"][0], root["at"][1], root["at"][2] + 10.0))

    def held():
        rows = t.turnips()
        return bool(rows) and rows[0].get("placement") in ("Held",)

    def screaming():
        rows = t.turnips()
        if rows and rows[0].get("phase") == "Scream":
            state.setdefault("morph", []).append(dict(game=round(t.game_time() - t.session["game_started"], 4),
                                                     probe=t.morph_probe()))
            return True
        return False

    def sample_morph():
        state.setdefault("morph", []).append(dict(game=round(t.game_time() - t.session["game_started"], 4),
                                                 phase=(t.turnips() or [{}])[0].get("phase"), probe=t.morph_probe()))

    s = [t.step_call(lambda: t.slomo(0.25)),
         # bed 0 (TravelCm t1)
         step_phase("walk0"), t.step_walk(STAND0_110, tolerance=25), step_approach(STAND0_110, 0), step_aim_hold(0, 0.6),
         keep_d0(0), step_mark("use0_down"), t.step_call(lambda: t.key("LeftMouseButton", True)), step_phase("grip0"),
         step_aim_hold(0, 0.35), step_shot("Q1_bed1_grip_fp"), step_aim_hold(0, 0.45),
         step_phase("back0"), step_move(0, slow, a_at_least(0, 0.5), max_s=10.0), step_shot("Q2_bed1_mid_fp"),
         step_move(0, slow, want_at_least(0, 0.92, t1), max_s=10.0), step_phase("hold0"), step_aim_hold(0, 1.0),
         step_shot("Q3_bed1_full_fp"), step_aim_hold(0, 0.1), step_view(side(0, t1)), step_aim_hold(0, 0.1),
         step_shot("Q4_bed1_full_side"), step_aim_hold(0, 0.1), t.step_call(t.chase_back), step_aim_hold(0, 0.2),
         step_phase("back0b"), step_move(0, slow, gone(0), max_s=10.0), step_mark("bed0_gone"),
         t.step_call(lambda: t.key("LeftMouseButton", False)), step_aim_hold(0, 1.0), step_bed_mark(0, "bed0_after"),
         # bed 1 (TravelCm t2): the cancel
         step_phase("walk1"), t.step_walk(STAND1_110, tolerance=25), step_approach(STAND1_110, 1), step_aim_hold(1, 0.6),
         keep_d0(1), step_mark("use1a_down"), t.step_call(lambda: t.key("LeftMouseButton", True)), step_phase("grip1a"),
         step_aim_hold(1, 0.35), step_shot("Q5_bed2_grip_fp"), step_aim_hold(1, 0.45),
         step_phase("back1a"), step_move(1, slow, a_at_least(1, 0.45), max_s=12.0), step_mark("use1a_up"),
         step_phase("cancel1a"), t.step_call(lambda: t.key("LeftMouseButton", False)), step_aim_hold(1, 0.1),
         step_shot("Q6_bed2_cancel_fp"), step_aim_hold(1, 1.5), step_bed_mark(1, "bed1_after_cancel"),
         # bed 1: the second pull
         step_phase("walk1b"), t.step_walk(STAND1_110, tolerance=25), step_approach(STAND1_110, 1), step_aim_hold(1, 0.6),
         keep_d0(1), step_mark("use1b_down"), t.step_call(lambda: t.key("LeftMouseButton", True)), step_phase("grip1b"),
         step_aim_hold(1, 0.8), step_phase("back1b"), step_move(1, slow, a_at_least(1, 0.5), max_s=12.0),
         step_shot("Q7_bed2_mid_fp"), step_move(1, slow, want_at_least(1, 0.92, t2), max_s=12.0), step_phase("hold1b"),
         step_aim_hold(1, 1.0), step_shot("Q8_bed2_full_fp"), step_aim_hold(1, 0.1), step_view(side(1, t2)),
         step_aim_hold(1, 0.1), step_shot("Q9_bed2_full_side"), step_aim_hold(1, 0.1),
         step_view(side_view(1, 110.0, 25.0, 0.0, z=12.0, lift=8.0)), step_phase("offscreen1b"), step_aim_hold(1, 0.6),
         step_shot("Q10_bed2_bulb_offscreen"), step_aim_hold(1, 0.6), t.step_call(t.chase_back), step_phase("back1b_2"),
         step_aim_hold(1, 0.2), step_move(1, slow, gone(1), max_s=12.0), step_mark("bed1_gone"),
         t.step_call(lambda: t.key("LeftMouseButton", False)), step_aim_hold(1, 1.0), step_bed_mark(1, "bed1_after"),
         t.step_call(lambda: t.slomo(1.0)),
         # the bed-0 root: pick it up and wait for a scream
         step_phase("root"), find_root, walk_to_root(), t.step_call(aim_root), t.step_wait(0.3), t.step_call(aim_root),
         t.step_wait(0.2), t.step_call(lambda: t.key("LeftMouseButton", True)), t.step_wait(0.25),
         t.step_call(lambda: t.key("LeftMouseButton", False)), t.step_wait(1.0), step_mark("pickup", held=None),
         t.step_call(lambda: mark("placement", turnips=t.turnips())), t.step_call(sample_morph),
         step_until(lambda r: held() or True, max_s=0.1), step_phase("wait_scream"),
         step_until(lambda r: screaming(), max_s=25.0), step_shot("Q11_scream_fp"), t.step_wait(0.15),
         t.step_call(sample_morph), t.step_wait(0.15), t.step_call(sample_morph),
         t.step_call(lambda: mark("after_scream", turnips=t.turnips())), step_phase("done")]
    state["seq"] = t.sequence(s, "run-12-walk")
    return state["seq"]


def run_12b(slow=30.0, t1=74.0, t2=146.2, beds=(0, 1), label="run-12b-walk"):
    """Phase K Part 3 supplement (run-12b): the side views at full strain side by side (run-12's bed-1 side camera stood
    outside the room). Each bed: grip, slow back-off to a hold at target 0.92, a side shot from the side of the pull axis
    that stays inside the room (the camera dist scaled by the bed's travel), then let go (the pull cancels)."""
    d0 = {}

    def keep_d0(i):
        def f():
            d0[i] = state["rows"][-1]["d%d" % i]
            mark("d0", bed=i, d0=d0[i])
        return t.step_call(f)

    def want_at_least(i, a, travel):
        return lambda r: (r["d%d" % i] - d0[i]) / travel >= a or released(r, i)

    def one(i, stand, travel, label):
        return [step_phase("walk%d" % i), t.step_walk(stand, tolerance=25), step_approach(stand, i), step_aim_hold(i, 0.6),
                keep_d0(i), step_mark("use%d_down" % i), t.step_call(lambda: t.key("LeftMouseButton", True)),
                step_aim_hold(i, 0.8), step_phase("back%d" % i), step_move(i, slow, want_at_least(i, 0.92, travel), max_s=12.0),
                step_phase("hold%d" % i), step_aim_hold(i, 1.0),
                step_view(side_view(i, travel * 0.5, -(travel * 1.2 + 60.0), 0.0, z=10.0, lift=25.0)), step_aim_hold(i, 0.1),
                step_shot(label), step_aim_hold(i, 0.1), t.step_call(t.chase_back), step_aim_hold(i, 0.2),
                step_mark("use%d_up" % i), t.step_call(lambda: t.key("LeftMouseButton", False)), step_aim_hold(i, 1.5)]

    s = [t.step_call(lambda: t.slomo(0.25))] + one(0, STAND0_110, t1, "R1_bed1_full_side") + \
        one(1, STAND1_110, t2, "R2_bed2_full_side") + [t.step_call(lambda: t.slomo(1.0)), step_phase("done")]
    state["seq"] = t.sequence(s, "run-12b-walk")
    return state["seq"]



def run_13(slow=30.0, fast=400.0, t1=74.0, t2=146.2, reps=3):
    """Phase K Part 3b (run-13, slomo 0.25; per tick the Use / Primary intent rows). A: bed 0 slow to 0.5 (shot) and a hold
    at target 0.92 (shot), let go. B x reps (run-12b's press-less grip): bed 0 grip, back to 0.5, let go; walk to bed 1 with
    Use up, wait 2 s at the stand, press, back to 0.5, let go (bed 1's cancel, charge kept). C: bed 1 slow to 0.5 (shot),
    a hold at 0.92 (shot + side shot), on to the break. D: bed 0 at full backward speed to the break (the strain held between
    the threshold and the release; the full-speed trail)."""
    d0 = {}

    def keep_d0(i):
        def f():
            d0[i] = state["rows"][-1]["d%d" % i]
            mark("d0", bed=i, d0=d0[i])
        return t.step_call(f)

    def want_at_least(i, a, travel):
        return lambda r: (r["d%d" % i] - d0[i]) / travel >= a or released(r, i)

    def a_at_least(i, a):
        return lambda r: (alpha_of(r, i) or 0.0) >= a or released(r, i)

    def gone(i):
        return lambda r: released(r, i)

    def down(label):
        return [step_mark(label + "_down"), t.step_call(lambda: t.key("LeftMouseButton", True))]

    def up(label):
        return [step_mark(label + "_up"), t.step_call(lambda: t.key("LeftMouseButton", False))]

    def stand(i):
        st = STAND0_110 if i == 0 else STAND1_110
        return [t.step_walk(st, tolerance=25), step_approach(st, i), step_aim_hold(i, 0.6), keep_d0(i)]

    s = [t.step_call(lambda: t.slomo(0.25))]
    # A
    s += [step_phase("A_walk")] + stand(0) + down("A") + [step_phase("A_grip"), step_aim_hold(0, 0.8), step_phase("A_back"),
          step_move(0, slow, a_at_least(0, 0.5), max_s=10.0), step_shot("S1_bed1_mid_fp"),
          step_move(0, slow, want_at_least(0, 0.92, t1), max_s=10.0), step_phase("A_hold"), step_aim_hold(0, 1.0),
          step_shot("S2_bed1_full_fp"), step_aim_hold(0, 0.1)] + up("A") + [step_phase("A_cancel"), step_aim_hold(0, 1.5)]
    # B
    for k in range(reps):
        p = "B%d" % (k + 1)
        s += [step_phase(p + "_walk0")] + stand(0) + down(p + "_bed1") + [step_phase(p + "_grip0"), step_aim_hold(0, 0.8),
              step_phase(p + "_back0"), step_move(0, slow, a_at_least(0, 0.5), max_s=10.0)] + up(p + "_bed1") +              [step_phase(p + "_cancel0"), step_aim_hold(0, 1.0), step_phase(p + "_walk1")] + stand(1) +              [step_phase(p + "_wait1"), step_mark(p + "_wait_start"), step_aim_hold(1, 2.0), step_mark(p + "_wait_end")] +              down(p + "_bed2") + [step_phase(p + "_grip1"), step_aim_hold(1, 0.8), step_phase(p + "_back1"),
              step_move(1, slow, a_at_least(1, 0.5), max_s=10.0)] + up(p + "_bed2") +              [step_phase(p + "_cancel1"), step_aim_hold(1, 1.5), step_bed_mark(1, p + "_bed2_after_cancel")]
    # C
    s += [step_phase("C_walk")] + stand(1) + down("C") + [step_phase("C_grip"), step_aim_hold(1, 0.8), step_phase("C_back"),
          step_move(1, slow, a_at_least(1, 0.5), max_s=12.0), step_shot("S3_bed2_mid_fp"),
          step_move(1, slow, want_at_least(1, 0.92, t2), max_s=12.0), step_phase("C_hold"), step_aim_hold(1, 1.0),
          step_shot("S4_bed2_full_fp"), step_aim_hold(1, 0.1),
          step_view(side_view(1, t2 * 0.5, -(t2 * 1.2 + 60.0), 0.0, z=10.0, lift=25.0)), step_aim_hold(1, 0.1),
          step_shot("S5_bed2_full_side"), step_aim_hold(1, 0.1), t.step_call(t.chase_back), step_aim_hold(1, 0.2),
          step_phase("C_back2"), step_move(1, slow, gone(1), max_s=12.0), step_mark("C_gone")] + up("C") +          [step_aim_hold(1, 1.0), step_bed_mark(1, "bed2_after")]
    # D
    s += [step_phase("D_walk")] + stand(0) + down("D") + [step_phase("D_grip"), step_aim_hold(0, 0.8), step_phase("D_fast"),
          step_mark("D_fast_start"), step_move(0, fast, gone(0), max_s=6.0), step_mark("D_gone")] + up("D") +          [step_aim_hold(0, 1.0), step_bed_mark(0, "bed1_after"), t.step_call(lambda: t.slomo(1.0)), step_phase("done")]
    state["seq"] = t.sequence(s, "run-13-walk")
    return state["seq"]


def run_14(slow=30.0, fast=400.0, t1=74.0, t2=146.2):
    """Phase L Part 2 (run-14, slomo 0.25): the gloves on the HarvestGrip sockets directly. Bed 0: pull 1 slow with a grip
    shot, a hold at target 0.6 with a counter-clockwise sidestep (the yaw carries the grips), on to a hold at 0.92 (shot),
    let go; pull 2 at full speed to the break. Bed 1: pull 1 with a grip shot, slow to 0.5, let go (the cancel); pull 2 slow
    to a hold at 0.92 (shot), let go; pull 3 at full speed to the break."""
    d0 = {}

    def keep_d0(i):
        def f():
            d0[i] = state["rows"][-1]["d%d" % i]
            mark("d0", bed=i, d0=d0[i])
        return t.step_call(f)

    def want_at_least(i, a, travel):
        return lambda r: (r["d%d" % i] - d0[i]) / travel >= a or released(r, i)

    def a_at_least(i, a):
        return lambda r: (alpha_of(r, i) or 0.0) >= a or released(r, i)

    def gone(i):
        return lambda r: released(r, i)

    def stand(i):
        st = STAND0_110 if i == 0 else STAND1_110
        return [t.step_walk(st, tolerance=25), step_approach(st, i), step_aim_hold(i, 0.6), keep_d0(i)]

    def press(label):
        return [step_mark(label + "_down"), t.step_call(lambda: t.key("LeftMouseButton", True))]

    def release(label):
        return [step_mark(label + "_up"), t.step_call(lambda: t.key("LeftMouseButton", False))]

    s = [t.step_call(lambda: t.slomo(0.25))]
    # bed 0, pull 1: grip shot, slow, sidestep at 0.6, hold at 0.92, let go
    s += [step_phase("a1_walk")] + stand(0) + press("a1") + [step_phase("a1_grip"), step_aim_hold(0, 0.35),
          step_shot("L1_bed1_grip_fp"), step_aim_hold(0, 0.45), step_phase("a1_slow"),
          step_move(0, slow, want_at_least(0, 0.6, t1), max_s=10.0), step_aim_hold(0, 0.4),
          t.step_call(lambda: state.update(side_r=state["rows"][-1]["d0"])), step_phase("a1_side"), step_mark("a1_side_start"),
          step_move(0, slow, lambda r: False, tangential=1.0, radial=0.0, hold_radius=lambda: state.get("side_r"), max_s=2.5),
          step_mark("a1_side_end"), step_phase("a1_slow2"), step_move(0, slow, want_at_least(0, 0.92, t1), max_s=10.0),
          step_phase("a1_hold"), step_aim_hold(0, 1.0), step_shot("L2_bed1_full_fp"), step_aim_hold(0, 0.1)] + \
         release("a1") + [step_phase("a1_cancel"), step_aim_hold(0, 1.5)]
    # bed 0, pull 2: full speed to the break
    s += [step_phase("a2_walk")] + stand(0) + press("a2") + [step_phase("a2_grip"), step_aim_hold(0, 0.8),
          step_phase("a2_fast"), step_move(0, fast, gone(0), max_s=6.0), step_mark("a2_gone")] + release("a2") + \
         [step_aim_hold(0, 1.0), step_bed_mark(0, "bed1_after")]
    # bed 1, pull 1: grip shot, slow to 0.5, let go
    s += [step_phase("b1_walk")] + stand(1) + press("b1") + [step_phase("b1_grip"), step_aim_hold(1, 0.35),
          step_shot("L3_bed2_grip_fp"), step_aim_hold(1, 0.45), step_phase("b1_slow"),
          step_move(1, slow, a_at_least(1, 0.5), max_s=10.0)] + release("b1") + \
         [step_phase("b1_cancel"), step_aim_hold(1, 1.5), step_bed_mark(1, "bed2_after_cancel")]
    # bed 1, pull 2: slow to a hold at 0.92 (shot), let go
    s += [step_phase("b2_walk")] + stand(1) + press("b2") + [step_phase("b2_grip"), step_aim_hold(1, 0.8),
          step_phase("b2_slow"), step_move(1, slow, want_at_least(1, 0.92, t2), max_s=12.0), step_phase("b2_hold"),
          step_aim_hold(1, 1.0), step_shot("L4_bed2_full_fp"), step_aim_hold(1, 0.1)] + release("b2") + \
         [step_phase("b2_cancel"), step_aim_hold(1, 1.5)]
    # bed 1, pull 3: full speed to the break
    s += [step_phase("b3_walk")] + stand(1) + press("b3") + [step_phase("b3_grip"), step_aim_hold(1, 0.8),
          step_phase("b3_fast"), step_move(1, fast, gone(1), max_s=6.0), step_mark("b3_gone")] + release("b3") + \
         [step_aim_hold(1, 1.0), step_bed_mark(1, "bed2_after"), t.step_call(lambda: t.slomo(1.0)), step_phase("done")]
    state["seq"] = t.sequence(s, "run-14-walk")
    return state["seq"]
