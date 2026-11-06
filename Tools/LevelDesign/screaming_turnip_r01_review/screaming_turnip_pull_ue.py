"""Screaming Turnip R01 Phase I: the pull's per-tick evidence (run-04-pull), on top of screaming_turnip_pie_ue.

Run with normal PIE running in the review map, through Monolith `editor_query run_python` (execute_statement):

    import sys; sys.path.insert(0, r"D:/Repositories/CkRepos/Orion/Tools/LevelDesign/screaming_turnip_r01_review")
    import screaming_turnip_pie_ue as t, screaming_turnip_pull_ue as p
    t.begin("run-04-pull"); p.sample_start(); p.run()        # then poll p.status(); p.finish() writes pull_rows.json

Per tick (`pull_rows.json`): game time, frame delta, each planted presentation component (bed index by location: 0 = the
bed at the origin, 1 = the bed at (450, -450)), its clip / position t / the HarvestGrip_R / _L socket world positions, and
the glove bones grip_r / grip_l (the first PIE skeletal mesh component that has both bones). The grip nodes themselves are
private ECS handles of the bed script (no Python path); the bed writes each node onto its socket every tick
(Mars_ScreamingTurnipBed_EntityScript.as DoMove_GripNode), so glove-to-socket is the end-to-end measure.
"""

import json
import math

import unreal as u

import screaming_turnip_pie_ue as t

BED_XY = ((0.0, 0.0), (450.0, -450.0))
STAND = ((-110.0, 0.0), (318.0, -429.0))
AIM = ((0.0, 0.0, 15.0), (450.0, -450.0, 15.0))

state = globals().get("state") or {}


def _v(x):
    return [round(x.x, 2), round(x.y, 2), round(x.z, 2)]


def _gloves_comp():
    c = state.get("gloves")
    if c is not None and u.SystemLibrary.is_valid(c):
        return c
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


def _planted():
    out = {}
    for c in t._pie_objects(t.PRESENTATION_CLASS):
        try:
            if not c.get_owner() or not c.is_visible():
                continue
            inst = c.get_anim_instance()
            asset = inst.get_animation_asset() if inst and hasattr(inst, "get_animation_asset") else None
            name = asset.get_name().replace("ScreamingTurnip_R01_", "").replace("_Mars_ANIM", "") if asset else None
            if not name or not name.startswith("SRC_"):
                continue
            loc = c.get_world_location()
            bed = min(range(len(BED_XY)), key=lambda i: (loc.x - BED_XY[i][0]) ** 2 + (loc.y - BED_XY[i][1]) ** 2)
            out[bed] = dict(clip=name, t=round(c.get_position(), 4),
                            sock_r=_v(c.get_socket_location("HarvestGrip_R")),
                            sock_l=_v(c.get_socket_location("HarvestGrip_L")),
                            crown=_v(c.get_socket_location("crown")))
        except Exception as e:
            out.setdefault("errors", []).append(str(e))
    return out


def sample():
    g = _gloves_comp()
    row = dict(game=round(t.game_time() - t.session["game_started"], 4),
               dt=round(u.GameplayStatics.get_world_delta_seconds(t.session["world"]), 4), beds=_planted(),
               keys=sorted(t.session["held_keys"]))
    if g is not None:
        row["grip_r"], row["grip_l"] = _v(g.get_socket_location("grip_r")), _v(g.get_socket_location("grip_l"))
    state["rows"].append(row)
    return row


def sample_start():
    state["rows"] = []
    state["shots"] = []
    def fn():
        if state.get("stop"):
            return True
        sample()
        return False
    t.when(fn)


def shot_when(label, pred):
    """Shot SHOWUI on the first tick pred(row) holds for the last sampled row."""
    def fn():
        rows = state.get("rows") or []
        if rows and pred(rows[-1]):
            t.screenshot(label)
            state["shots"].append(dict(label=label, row=rows[-1]))
            t.session["changes"].append(dict(game=rows[-1]["game"], shot=label))
            return True
        return False
    t.when(fn)


def clip_of(row, bed):
    b = row["beds"].get(bed) or row["beds"].get(str(bed))
    return (b or {}).get("clip"), (b or {}).get("t", 0.0)


def arm_bed1_shots():
    shot_when("I1_grip_end", lambda r: clip_of(r, 0)[0] == "SRC_Tug")
    shot_when("I2_tug_mid", lambda r: clip_of(r, 0)[0] == "SRC_Tug" and clip_of(r, 0)[1] >= 0.25)
    shot_when("I3_tug_end_full_strain_fp", lambda r: clip_of(r, 0)[0] == "SRC_Tug" and clip_of(r, 0)[1] >= 0.46)


def run():
    """Bed 1: the full pull (held 1.8 s) with captures; bed 2: a press let go at 0.9 s (cancel) with captures at the
    let-go and 0.2 s after; then bed 2's full pull with NO captures (the clean timing sample)."""
    s = [t.step_walk(STAND[0]), t.step_call(lambda: t.aim_at(AIM[0])), t.step_wait(0.3),
         t.step_call(arm_bed1_shots), t.step_call(lambda: t.key("LeftMouseButton", True)), t.step_wait(1.8),
         t.step_call(lambda: t.key("LeftMouseButton", False)), t.turnip_settled(0),
         t.step_call(lambda: t.screenshot("I4_after_release")), t.step_wait(1.0),
         t.step_walk(STAND[1]), t.step_call(lambda: t.aim_at(AIM[1])), t.step_wait(0.3),
         t.step_call(lambda: t.key("LeftMouseButton", True)), t.step_wait(0.9),
         t.step_call(lambda: t.key("LeftMouseButton", False)), t.step_call(lambda: t.screenshot("I5_bed2_cancel_press")),
         t.step_wait(0.2), t.step_call(lambda: t.screenshot("I6_bed2_cancel_plus02")), t.step_wait(2.5),
         t.step_call(lambda: t.aim_at(AIM[1])), t.step_wait(0.3),
         t.step_call(lambda: t.key("LeftMouseButton", True)), t.step_wait(1.8),
         t.step_call(lambda: t.key("LeftMouseButton", False)), t.step_wait(3.0)]
    state["seq"] = t.sequence(s, "run-04-pull")
    return state["seq"]


def status():
    rows = state.get("rows") or []
    return dict(seq=state.get("seq"), rows=len(rows), last=rows[-1] if rows else None, shots=[s["label"] for s in state["shots"]])


def finish():
    state["stop"] = True
    path = t.folder() / "pull_rows.json"
    path.write_text(json.dumps(dict(rows=state["rows"], shots=state["shots"]), indent=0))
    t.stop()
    return str(path)


def run_strain(slomo=0.2):
    """Session B (run-04-pull-strain): bed 1's pull slowed by slomo so the end-of-frame Shot lands before the root pops:
    first-person shots at Tug t 0.25 / 0.44, then a side chase view of the bed at Tug t >= 0.47 (one later tick), back to
    first person. Timing is NOT measured here (run-04-pull bed 2 is the timing sample)."""
    box = {}
    def side():
        if box.get("side"):
            return True
        rows = state.get("rows") or []
        if rows and clip_of(rows[-1], 0)[0] == "SRC_Tug" and clip_of(rows[-1], 0)[1] >= 0.465:
            if "cam" not in box:
                box["cam"] = t.chase_view((0.0, 0.0, 8.0), offset=(0.0, -150.0, 30.0), fov=50.0)
                return False
            t.screenshot("S3_tug_end_side")
            state["shots"].append(dict(label="S3_tug_end_side", row=rows[-1]))
            box["side"] = True
            return True
        return False
    shot_when("S1_tug_mid_fp", lambda r: clip_of(r, 0)[0] == "SRC_Tug" and clip_of(r, 0)[1] >= 0.25)
    shot_when("S2_tug_end_full_strain_fp", lambda r: clip_of(r, 0)[0] == "SRC_Tug" and clip_of(r, 0)[1] >= 0.44)
    s = [t.step_walk(STAND[0]), t.step_call(lambda: t.aim_at(AIM[0])), t.step_wait(0.3),
         t.step_call(lambda: t.slomo(slomo)), t.step_call(lambda: t.key("LeftMouseButton", True)), side,
         t.step_wait(0.5), t.step_call(t.chase_back), t.step_wait(2.0),
         t.step_call(lambda: t.key("LeftMouseButton", False)), t.step_call(lambda: t.slomo(1.0)), t.step_wait(1.0)]
    state["seq"] = t.sequence(s, "run-04-pull-strain")
    return state["seq"]


def clip_drive(label="run-04-pull-clip"):
    """Inside capture_pie_movement_clip (a probe at ~1 s): bed 1's full pull seen from a side camera (the bed at 150 cm,
    30 cm up); aim is set from the player's own camera before the view switches."""
    state.clear()
    t.begin(label, check_throttle=False)
    sample_start()
    s = [t.step_walk(STAND[0]), t.step_call(lambda: t.aim_at(AIM[0])), t.step_wait(0.2),
         t.step_call(lambda: t.chase_view((0.0, 0.0, 8.0), offset=(0.0, -150.0, 30.0), fov=50.0)),
         t.step_call(lambda: t.key("LeftMouseButton", True)), t.step_wait(1.8),
         t.step_call(lambda: t.key("LeftMouseButton", False)), t.step_wait(1.5), t.step_call(finish)]
    state["seq"] = t.sequence(s, label)
    return state["seq"]
