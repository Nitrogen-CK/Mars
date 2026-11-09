"""Phase L Part 2 regression look (PHASE_L_BRIEF.md D-L5): every other grip after D-L1 (grips read live at composition).

Run in normal PIE on the SANDBOX map (loaded read-only through LevelEditorSubsystem.load_level; never saved), through
Monolith `editor_query run_python`:

    import sys; sys.path.insert(0, r"D:/Repositories/CkRepos/Orion/Tools/LevelDesign/screaming_turnip_r01_review")
    import screaming_turnip_pie_ue as t, screaming_turnip_regression_ue as g
    t.begin("run-14-sandbox", check_throttle=False); g.run()      # poll g.status(); g.finish()

Targets (the Sandbox builder's labels and places): Mech_LeverA (a Mars_Sandbox_PulledLever, 3250, -460): grip and pull a
little with look deltas; Item_Cookbook (two-handed, -450, 0): pick up; Item_Key_Red (one-handed, rides home, -550, -2250):
pick up. The pawn is teleported to a stand 120 cm off each target, aimed at it, then Use is pressed through
Mars_ExpeditionAcceptance (the game's own input path). Shots: Shot SHOWUI. Per tick: the glove bones (grip_r / grip_l).
"""
import json
import math

import unreal as u

import screaming_turnip_pie_ue as t

state = globals().get("state") or {}
globals()["state"] = state

TARGETS = {
    "lever": dict(at=(3250.0, -460.0, 100.0), stand=(3130.0, -460.0)),
    "cookbook": dict(at=(-450.0, 0.0, 50.0), stand=(-570.0, 0.0)),
    "key": dict(at=(-550.0, -2250.0, 30.0), stand=(-670.0, -2250.0)),
}
# run 2 (run_pickups): the first run aimed over the floor items (the builder's spawn z) and never focused them; aim at
# the item's live world location instead (the WorldItem actor nearest the target, read in PIE).


def _v(x):
    return [round(x.x, 3), round(x.y, 3), round(x.z, 3)]


def _gloves():
    for comp in u.ObjectIterator(u.SkeletalMeshComponent):
        if "UEDPIE" not in comp.get_path_name():
            continue
        try:
            if comp.get_bone_index("grip_r") != -1 and comp.get_bone_index("grip_l") != -1:
                return comp
        except Exception:
            pass
    return None


def sample():
    g = state.get("gloves")
    try:
        if g is None or not u.SystemLibrary.is_valid(g):
            g = state["gloves"] = _gloves()
    except Exception:
        g = state["gloves"] = _gloves()
    row = dict(game=round(t.game_time() - t.session["game_started"], 4), phase=state.get("phase"),
               player=_v(t.session["pawn"].get_actor_location()), keys=sorted(t.session["held_keys"]))
    if g is not None:
        row["grip_r"], row["grip_l"] = _v(g.get_socket_location("grip_r")), _v(g.get_socket_location("grip_l"))
    state["rows"].append(row)


def mark(label, **extra):
    state["marks"].append(dict(label=label, game=round(t.game_time() - t.session["game_started"], 4), **extra))


def step_phase(name):
    return t.step_call(lambda: state.update(phase=name))


def teleport(name):
    def f():
        x, y = TARGETS[name]["stand"]
        p = t.session["pawn"]
        p.set_actor_location(u.Vector(x, y, p.get_actor_location().z), False, True)
        mark("teleport_" + name, at=[x, y])
    return t.step_call(f)


def aim(name):
    return t.step_call(lambda: t.aim_at(TARGETS[name]["at"]))


def shot(label):
    def f():
        t.screenshot(label)
        mark("shot_" + label)
    return t.step_call(f)


def look_pull(dx, dy, ticks):
    box = {"n": 0}

    def fn():
        t.session["helper"].call_method("Look", args=(t.session["pawn"], u.Vector(dx, dy, 0.0)))
        box["n"] += 1
        return box["n"] >= ticks
    return fn


def inspect_mark(label):
    return t.step_call(lambda: mark(label, inspect=t.inspect()))


def run():
    state.clear()
    state.update(rows=[], marks=[], phase=None)

    def tick():
        if state.get("stop"):
            return True
        sample()
        return False
    t.when(tick)
    s = [step_phase("lever"), teleport("lever"), t.step_wait(0.5), aim("lever"), t.step_wait(0.3), aim("lever"),
         t.step_wait(0.3), shot("G0_lever_focus"), t.step_wait(0.2), t.step_call(lambda: t.key("LeftMouseButton", True)),
         t.step_wait(0.8), shot("G1_lever_grip"), t.step_wait(0.2), look_pull(0.0, 2.0, 20), t.step_wait(0.3),
         shot("G2_lever_pulled"), t.step_wait(0.2), look_pull(0.0, -2.0, 20), t.step_call(lambda: t.key("LeftMouseButton", False)),
         t.step_wait(1.0), inspect_mark("after_lever"),
         step_phase("cookbook"), teleport("cookbook"), t.step_wait(0.5), aim("cookbook"), t.step_wait(0.3), aim("cookbook"),
         t.step_wait(0.3), t.step_call(lambda: t.key("LeftMouseButton", True)), t.step_wait(0.15),
         t.step_call(lambda: t.key("LeftMouseButton", False)), t.step_wait(0.25), shot("G3_cookbook_reach"), t.step_wait(1.0),
         shot("G4_cookbook_held"), inspect_mark("after_cookbook"), t.step_call(lambda: t.key("R", True)), t.step_wait(0.1),
         t.step_call(lambda: t.key("R", False)), t.step_wait(1.0), inspect_mark("after_drop"),
         step_phase("key"), teleport("key"), t.step_wait(0.5), aim("key"), t.step_wait(0.3), aim("key"), t.step_wait(0.3),
         t.step_call(lambda: t.key("LeftMouseButton", True)), t.step_wait(0.15), t.step_call(lambda: t.key("LeftMouseButton", False)),
         t.step_wait(0.25), shot("G5_key_reach"), t.step_wait(1.0), shot("G6_key_held"), inspect_mark("after_key"),
         step_phase("done")]
    state["seq"] = t.sequence(s, "run-14-sandbox")
    return state["seq"]


def status():
    return dict(seq=state.get("seq"), phase=state.get("phase"), rows=len(state.get("rows") or []), marks=state.get("marks"))


def finish():
    state["stop"] = True
    path = t.folder() / "regression_rows.json"
    path.write_text(json.dumps(dict(rows=state["rows"], marks=state["marks"]), indent=0))
    t.stop()
    return str(path)



def _item_at(name):
    """The live location of the PIE item nearest the target (its spawned actor, after physics settled)."""
    want = TARGETS[name]["at"]
    best = None
    for a in u.GameplayStatics.get_all_actors_of_class(t.session["world"], u.Actor):
        loc = a.get_actor_location()
        dd = math.hypot(loc.x - want[0], loc.y - want[1])
        nm = a.get_class().get_name()
        if dd < 60.0 and ("WorldItem" in nm or "Cookbook" in nm or "Item" in nm or "Mars_" in nm) and "Character" not in nm:
            if best is None or dd < best[0]:
                best = (dd, loc, nm)
    return best


def aim_live(name):
    def f():
        b = _item_at(name)
        if b:
            t.aim_at((b[1].x, b[1].y, b[1].z + 3.0))
            mark("aim_" + name, at=_v(b[1]), cls=b[2])
        else:
            t.aim_at((TARGETS[name]["at"][0], TARGETS[name]["at"][1], 5.0))
            mark("aim_" + name + "_fallback")
    return t.step_call(f)


def run_pickups():
    state.clear()
    state.update(rows=[], marks=[], phase=None)

    def tick():
        if state.get("stop"):
            return True
        sample()
        return False
    t.when(tick)
    s = []
    for name, tag in (("cookbook", "G3b"), ("key", "G5b")):
        s += [step_phase(name), teleport(name), t.step_wait(0.6), aim_live(name), t.step_wait(0.4), aim_live(name),
              t.step_wait(0.4), shot(tag + "_" + name + "_focus"), t.step_wait(0.2),
              t.step_call(lambda: t.key("LeftMouseButton", True)), t.step_wait(0.2),
              t.step_call(lambda: t.key("LeftMouseButton", False)), t.step_wait(0.2), shot(tag + "_" + name + "_reach"),
              t.step_wait(1.2), shot(tag + "_" + name + "_held"), inspect_mark("after_" + name)]
        if name == "cookbook":
            s += [t.step_call(lambda: t.key("R", True)), t.step_wait(0.1), t.step_call(lambda: t.key("R", False)),
                  t.step_wait(1.0), inspect_mark("after_drop")]
    s += [step_phase("done")]
    state["seq"] = t.sequence(s, "run-14-sandbox-pickups")
    return state["seq"]
