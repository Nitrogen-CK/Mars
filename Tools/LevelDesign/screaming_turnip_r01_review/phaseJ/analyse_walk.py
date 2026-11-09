"""Phase J Part 3: numbers from a run-05-walk walk_rows.json (plain python, outside the editor).

    python analyse_walk.py <walk_rows.json> [out.json]

Alpha: the drawing's alpha is the scrubbed SRC_Tug position / 0.5 s (the bed scrubs SRC_Tug to the Control's alpha each
tick, Mars_ScreamingTurnipBed_EntityScript.as DoScrub_Tug); the ring's alpha is the prompt's Percent x EngageAlpha 0.97
(when the sampler saw the prompt). d0 is the player's root distance to the bed on the Use press (the player stands still
through the 0.4 s Grip, so the Control's WalkStartCm, taken when the gloves grip, is the same distance).
"""
import json
import math
import sys

import os
WALK_CM = float(os.environ.get("WALK_CM", "38.2"))   # Part 3c: WALK_CM=74.2
TUG_S = 0.5
CANCEL_S = 7 / 30.0
BED_XY = ((0.0, 0.0), (450.0, -450.0))
SPRING_LAG_S = 12.0 / 60.0      # Damping / Stiffness: the spring's steady lag behind a constant-rate Pull
CROWN_TRAVEL = "D:/Repositories/CkRepos/Orion/Tools/Blender/mars_ingredients/screaming_turnip_r01/review/phaseJ/crown_travel.json"
_TUG = json.load(open(CROWN_TRAVEL))["clips"]["SRC_Tug"]


def clip_travel(alpha):
    """HarvestGrip_R's -X travel from SRC_Tug f0 at the clip position alpha (linear between the authored frames)."""
    f = max(0.0, min(15.0, alpha * 15.0))
    f0 = int(math.floor(f))
    f1 = min(15, f0 + 1)
    x0, x1 = _TUG[str(f0)]["HarvestGrip_R"][0], _TUG[str(f1)]["HarvestGrip_R"][0]
    x = x0 + (x1 - x0) * (f - f0)
    return -(x - _TUG["0"]["HarvestGrip_R"][0])


def local_travel(b, i):
    """Each socket's travel along the planted root's own -X (its facing, the component yaw), from the f0 socket x -1.522."""
    c, s_ = math.cos(math.radians(b["yaw"])), math.sin(math.radians(b["yaw"]))
    out = []
    for k in ("sock_r", "sock_l"):
        rx, ry = b[k][0] - BED_XY[i][0], b[k][1] - BED_XY[i][1]
        out.append(-(rx * c + ry * s_) - 1.522)
    return out


def bed(row, i):
    return row["beds"].get(str(i)) or row["beds"].get(i)


def h(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def d3(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def wrap(a):
    return (a + 180.0) % 360.0 - 180.0


def aim(row, i):
    px, py = row["player"][0] - BED_XY[i][0], row["player"][1] - BED_XY[i][1]
    return math.degrees(math.atan2(-py, -px))


def mark(marks, label, nth=0):
    hits = [m for m in marks if m["label"] == label]
    return hits[nth]["game"] if len(hits) > nth else None


def gloves(rows, i, lo, hi):
    """Glove bone vs socket, same frame and glove(n) vs socket(n-1), for rows in [lo, hi)."""
    out = dict(n=0, same_max=0.0, lag1_max=0.0, over_05_same=0, over_05_lag1=0, worst=None, over_rows=[])
    prev = None
    for r in rows:
        if not (lo <= r["game"] < hi):
            continue
        b = bed(r, i)
        if not b or "grip_r" not in r or not b.get("vis"):
            prev = None
            continue
        same = max(d3(r["grip_r"], b["sock_r"]), d3(r["grip_l"], b["sock_l"]))
        out["n"] += 1
        out["same_max"] = max(out["same_max"], same)
        out["over_05_same"] += same > 0.5
        if prev is not None:
            lag = max(d3(r["grip_r"], prev["sock_r"]), d3(r["grip_l"], prev["sock_l"]))
            if lag > out["lag1_max"]:
                out["worst"] = dict(game=r["game"], dt=r["dt"], lag1=round(lag, 3), same=round(same, 3), clip=b["clip"],
                                    t=b["t"])
            out["lag1_max"] = max(out["lag1_max"], lag)
            if lag > 0.5:
                out["over_05_lag1"] += 1
                out["over_rows"].append(dict(game=r["game"], dt=r["dt"], lag1=round(lag, 3), same=round(same, 3),
                                             clip=b["clip"], t=b["t"]))
        prev = b
    out["same_max"], out["lag1_max"] = round(out["same_max"], 3), round(out["lag1_max"], 3)
    out["over_rows"] = out["over_rows"][:20]
    return out


def pull(rows, marks, i, press, end, until_label=None):
    """A walk pull on bed i: press (Use down game time) .. end (game time of the release / let-go)."""
    pre = [r for r in rows if r["game"] <= press]
    d0 = pre[-1]["d%d" % i]
    out = dict(bed=i, press=press, end=end, d0=round(d0, 3))
    tug = [r for r in rows if press < r["game"] <= end and bed(r, i) and bed(r, i)["clip"] == "SRC_Tug" and bed(r, i)["vis"]]
    if not tug:
        out["error"] = "no SRC_Tug rows"
        return out
    first = tug[0]
    s0 = (bed(first, i)["sock_r"], bed(first, i)["sock_l"])
    out["tug_first"] = dict(game=first["game"], t=bed(first, i)["t"], d=first["d%d" % i])
    # player still through the grip
    grip_rows = [r for r in rows if press <= r["game"] <= first["game"]]
    out["player_moved_during_grip_cm"] = round(max(h(r["player"], grip_rows[0]["player"]) for r in grip_rows), 3)
    per = []
    for r in tug:
        b = bed(r, i)
        a = b["t"] / TUG_S
        d = r["d%d" % i]
        want = min(1.0, max(0.0, (d - d0) / WALK_CM))
        # the target a spring-lag ago (the Pull the spring is following, SPRING_LAG_S back)
        back = [q for q in rows if q["game"] <= r["game"] - SPRING_LAG_S]
        want_lag = min(1.0, max(0.0, (back[-1]["d%d" % i] - d0) / WALK_CM)) if back else None
        ux, uy = r["player"][0] - BED_XY[i][0], r["player"][1] - BED_XY[i][1]
        n = math.hypot(ux, uy) or 1.0
        ux, uy = ux / n, uy / n
        trav = [(b["sock_r"][0] - s0[0][0]) * ux + (b["sock_r"][1] - s0[0][1]) * uy,
                (b["sock_l"][0] - s0[1][0]) * ux + (b["sock_l"][1] - s0[1][1]) * uy]
        ring = [x.get("pct") for x in r.get("ring") or [] if x.get("pct") is not None]
        lt = local_travel(b, i)
        ct = clip_travel(a)
        per.append(dict(game=r["game"], dt=r["dt"], d=round(d, 3), gained=round(d - d0, 3), alpha=round(a, 4),
                        want=round(want, 4), err=round(a - want, 4),
                        want_lag=None if want_lag is None else round(want_lag, 4),
                        err_lag=None if want_lag is None else round(a - want_lag, 4),
                        sock_travel=[round(x, 3) for x in trav], sock_travel_want=round(a * WALK_CM, 3),
                        sock_travel_err=round(max(abs(x - a * WALK_CM) for x in trav), 3),
                        local_travel=[round(x, 3) for x in lt], local_err_vs_alpha=round(max(abs(x - a * WALK_CM) for x in lt), 3),
                        clip_travel=round(ct, 3), local_err_vs_clip=round(max(abs(x - ct) for x in lt), 3),
                        yaw=b["yaw"], aim=round(aim(r, i), 3), yaw_err=round(wrap(b["yaw"] - aim(r, i)), 3),
                        ring=max(ring) if ring else None, rendered=b.get("rendered"), sock_r=b["sock_r"]))
    out["rows"] = per
    settled = [p for p in per if p["game"] >= first["game"] + 0.5]
    out["settle_rule"] = "rows from 0.5 s after the first SRC_Tug row (about 2.5 spring time constants)"
    if settled:
        out["alpha_err_max_abs"] = max(abs(p["err"]) for p in settled)
        out["alpha_err_mean"] = round(sum(p["err"] for p in settled) / len(settled), 4)
        lagged = [p for p in settled if p["err_lag"] is not None]
        out["alpha_err_lag_max_abs"] = max(abs(p["err_lag"]) for p in lagged) if lagged else None
        out["n_settled"] = len(settled)
    out["sock_travel_err_max"] = max(p["sock_travel_err"] for p in per)
    worst = max(per, key=lambda p: p["local_err_vs_alpha"])
    out["local_travel_err_vs_alpha_max"] = dict(err=worst["local_err_vs_alpha"], game=worst["game"], alpha=worst["alpha"],
                                                local=worst["local_travel"], want=worst["sock_travel_want"])
    out["local_travel_err_vs_clip_max"] = max(p["local_err_vs_clip"] for p in per)
    out["local_travel_at_last"] = dict(alpha=per[-1]["alpha"], local=per[-1]["local_travel"], want=per[-1]["sock_travel_want"],
                                       clip=per[-1]["clip_travel"])
    out["yaw_err_max_abs_after_0_2s"] = max(abs(p["yaw_err"]) for p in per if p["game"] >= press + 0.2) \
        if any(p["game"] >= press + 0.2 for p in per) else None
    last = per[-1]
    out["last_tug_row"] = dict(game=last["game"], alpha=last["alpha"], d=last["d"], gained=last["gained"],
                               want=last["want"], ring=last["ring"])
    # yaw over the whole pull, including the grip (turn speed)
    yaws = [(r["game"], bed(r, i)["yaw"], round(aim(r, i), 3)) for r in rows
            if press - 0.1 <= r["game"] <= end and bed(r, i)]
    out["yaw_track_first"] = yaws[:12]
    out["gloves"] = gloves(rows, i, first["game"], end + 1e-6)
    out["gloves_from_press_0_17"] = gloves(rows, i, press + 0.17, end + 1e-6)
    ring_rows = [p for p in per if p["ring"] is not None]
    out["ring_vs_alpha"] = dict(n=len(ring_rows), max_ring=max((p["ring"] for p in ring_rows), default=None),
                                max_abs_ring_x097_minus_alpha=max((abs(p["ring"] * 0.97 - p["alpha"]) for p in ring_rows),
                                                                  default=None))
    out["rendered_false_rows"] = [p["game"] for p in per if p["rendered"] is False]
    out["frame_dt"] = dict(max=max(p["dt"] for p in per), mean=round(sum(p["dt"] for p in per) / len(per), 4))
    return out


def cancel(rows, i, up, until):
    """The let-go: the last SRC_Tug row before Use up, SRC_Cancel's rows, socket steps, gloves, the end on SRC_Idle."""
    out = dict(up=up)
    before = [r for r in rows if r["game"] <= up and bed(r, i) and bed(r, i)["clip"] == "SRC_Tug"]
    out["last_tug"] = dict(game=before[-1]["game"], t=bed(before[-1], i)["t"], alpha=round(bed(before[-1], i)["t"] / TUG_S, 4))
    seq = [r for r in rows if before[-1]["game"] <= r["game"] <= until and bed(r, i)]
    can = [r for r in seq if bed(r, i)["clip"] == "SRC_Cancel"]
    out["cancel_first"] = dict(game=can[0]["game"], t=bed(can[0], i)["t"],
                               start_alpha=round(bed(can[0], i)["t"] / CANCEL_S, 4),
                               want_start_alpha=round(1 - out["last_tug"]["alpha"], 4)) if can else None
    steps, prev = [], None
    for r in seq:
        b = bed(r, i)
        if prev is not None:
            pb = bed(prev, i)
            dt = r["game"] - prev["game"]
            j = max(d3(b["sock_r"], pb["sock_r"]), d3(b["sock_l"], pb["sock_l"]))
            steps.append(dict(game=r["game"], dt=round(dt, 4), clip=pb["clip"] + "->" + b["clip"], t=b["t"],
                              step=round(j, 3), speed=round(j / dt, 2) if dt > 0 else None,
                              per_60hz=round(j / dt / 60.0, 3) if dt > 0 else None,
                              glove=round(max(d3(r["grip_r"], b["sock_r"]), d3(r["grip_l"], b["sock_l"])), 3)
                              if "grip_r" in r else None))
        prev = r
    out["steps"] = steps[:60]
    cs = [s for s in steps if "SRC_Cancel" in s["clip"]]
    out["max_step_per_sample"] = max((s["step"] for s in cs), default=None)
    out["max_speed_cms"] = max((s["speed"] for s in cs if s["speed"]), default=None)
    out["max_step_at_60hz_equiv"] = max((s["per_60hz"] for s in cs if s["per_60hz"]), default=None)
    idle = [r for r in seq if bed(r, i)["clip"] == "SRC_Idle" and r["game"] > up]
    out["idle_at"] = idle[0]["game"] if idle else None
    out["cancel_span_s"] = round(idle[0]["game"] - can[0]["game"], 4) if idle and can else None
    return out


def main(path, out_path=None):
    data = json.load(open(path))
    rows, marks = data["rows"], data["marks"]
    res = dict(source=path, n_rows=len(rows), marks=[(m["label"], m["game"], m.get("bed")) for m in marks])
    res["bed0"] = pull(rows, marks, 0, mark(marks, "use0_down"), mark(marks, "bed0_gone"))
    res["bed1_pull1"] = pull(rows, marks, 1, mark(marks, "use1a_down"), mark(marks, "use1a_up"))
    res["bed1_cancel"] = cancel(rows, 1, mark(marks, "use1a_up"), mark(marks, "use1b_down"))
    res["bed1_pull2"] = pull(rows, marks, 1, mark(marks, "use1b_down"), mark(marks, "bed1_gone"))
    s0, s1 = mark(marks, "side1b_start"), mark(marks, "side1b_end")
    side = [p for p in res["bed1_pull2"].get("rows", []) if s0 is not None and s0 <= p["game"] <= s1]
    res["sidestep"] = dict(n=len(side), aim_from=side[0]["aim"] if side else None, aim_to=side[-1]["aim"] if side else None,
                           yaw_from=side[0]["yaw"] if side else None, yaw_to=side[-1]["yaw"] if side else None,
                           yaw_err_max_abs=max((abs(p["yaw_err"]) for p in side), default=None),
                           d_range=[min(p["d"] for p in side), max(p["d"] for p in side)] if side else None,
                           alpha_range=[min(p["alpha"] for p in side), max(p["alpha"] for p in side)] if side else None)
    # Part 3b: the yaw per tick from each Use press until the Tug starts (+0.1 s)
    for key, label, i in (("bed0", "use0_down", 0), ("bed1_pull1", "use1a_down", 1), ("bed1_pull2", "use1b_down", 1)):
        press = mark(marks, label)
        tf = (res[key].get("tug_first") or {}).get("game", press + 0.6)
        res[key]["yaw_from_press"] = [dict(dt_from_press=round(r["game"] - press, 4), clip=bed(r, i)["clip"], t=bed(r, i)["t"],
                                           yaw=bed(r, i)["yaw"], aim=round(aim(r, i), 3),
                                           err=round(wrap(bed(r, i)["yaw"] - aim(r, i)), 3))
                                      for r in rows if press <= r["game"] <= tf + 0.1 and bed(r, i)]
        within = [y for y in res[key]["yaw_from_press"] if abs(y["err"]) <= 5.0]
        res[key]["yaw_within_5deg_after_press_s"] = within[0]["dt_from_press"] if within else None
    res["bed_readouts"] = [(m["label"], m.get("bed")) for m in marks if m.get("bed") and isinstance(m.get("bed"), str)]
    out_path = out_path or path.replace(".json", "_analysis.json")
    json.dump(res, open(out_path, "w"), indent=1)
    for k in ("bed0", "bed1_pull1", "bed1_pull2"):
        p = res[k]
        print(k, {x: p.get(x) for x in ("d0", "tug_first", "player_moved_during_grip_cm", "alpha_err_max_abs", "alpha_err_mean",
                                         "alpha_err_lag_max_abs", "n_settled", "sock_travel_err_max",
                                         "local_travel_err_vs_alpha_max", "local_travel_err_vs_clip_max", "local_travel_at_last",
                                         "yaw_err_max_abs_after_0_2s", "last_tug_row", "ring_vs_alpha", "frame_dt",
                                         "rendered_false_rows")})
        g = p.get("gloves") or {}
        print("  gloves", {x: g.get(x) for x in ("n", "same_max", "lag1_max", "over_05_same", "over_05_lag1", "worst")})
        print("  yaw", p.get("yaw_track_first"))
    c = res["bed1_cancel"]
    print("cancel", {x: c.get(x) for x in ("last_tug", "cancel_first", "max_step_per_sample", "max_speed_cms",
                                           "max_step_at_60hz_equiv", "idle_at", "cancel_span_s")})
    for s in c["steps"]:
        if "Cancel" in s["clip"] or "Idle" in s["clip"]:
            print("   ", s)
    print("sidestep", res["sidestep"])
    print("readouts", res["bed_readouts"])
    return out_path


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
