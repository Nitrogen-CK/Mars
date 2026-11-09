"""Phase K Part 3b: numbers from run-13-walk/walk_rows.json. python analyse_run13.py <walk_rows.json> <out.json>

Drawn alpha = the instance's ClipTime / 0.5 s while SRC_Tug plays; Control alpha = the ring (Percent) x 0.97, the same tick.
Bed 0 is the review's "bed 1" (TravelCm 74 / LiftCm 9), bed 1 is "bed 2" (146.2 / 18)."""
import json, math, sys

TRAVEL = {0: (74.0, 9.0), 1: (146.2, 18.0)}
TUG_S, CANCEL_S = 0.5, 7 / 30.0


def bed(r, i):
    return r["beds"].get(str(i)) or {}


def ring(r):
    v = [x.get("pct") for x in r.get("ring") or [] if x.get("pct") is not None]
    return v[0] if v else None


def local_x(b, key):
    c, s = math.cos(math.radians(b["yaw"])), math.sin(math.radians(b["yaw"]))
    return (b[key][0] - b["loc"][0]) * c + (b[key][1] - b["loc"][1]) * s


def marks_of(marks, label):
    return [m["game"] for m in marks if m["label"] == label]


def lag(rows, i, phases):
    """Drawn alpha vs the Control alpha the same tick and the previous tick; gloves vs same / previous tick sockets."""
    sel = [r for r in rows if r.get("phase") in phases and bed(r, i).get("clip") == "SRC_Tug" and bed(r, i).get("vis")
           and ring(r) is not None]
    same = [abs(ring(r) * 0.97 - bed(r, i)["t"] / TUG_S) for r in sel]
    prev = [abs(ring(p) * 0.97 - bed(q, i)["t"] / TUG_S) for p, q in zip(sel, sel[1:])]
    g_same, g_prev = [], []
    for p, q in zip(sel, sel[1:]):
        if "grip_r" not in q:
            continue
        bq, bp = bed(q, i), bed(p, i)
        gs = max(math.dist(q["grip_r"], bq["sock_r"]), math.dist(q["grip_l"], bq["sock_l"]))
        if gs > 50:      # a chase-view row: the gloves follow the view
            continue
        g_same.append(gs)
        g_prev.append(max(math.dist(q["grip_r"], bp["sock_r"]), math.dist(q["grip_l"], bp["sock_l"])))
    speed = [abs(q["d%d" % i] - p["d%d" % i]) / (q["game"] - p["game"]) for p, q in zip(sel, sel[1:]) if q["game"] > p["game"]]
    dts = [r["dt"] for r in sel]
    return dict(n=len(sel), drawn_vs_same_tick_max=round(max(same), 5) if same else None,
                drawn_vs_same_tick_mean=round(sum(same) / len(same), 5) if same else None,
                drawn_vs_prev_tick_max=round(max(prev), 5) if prev else None,
                glove_vs_prev_socket_max=round(max(g_prev), 4) if g_prev else None,
                glove_vs_same_socket_max=round(max(g_same), 3) if g_same else None,
                glove_vs_same_socket_mean=round(sum(g_same) / len(g_same), 3) if g_same else None,
                walk_speed_median=round(sorted(speed)[len(speed) // 2], 1) if speed else None,
                dt_median=round(sorted(dts)[len(dts) // 2], 4) if dts else None)


def strain_held(rows, i, start, end):
    """From the tick the Control's alpha reaches the threshold (the ring at 1 or gone) to the tick the root hides: the drawn
    Tug alpha and the crown x."""
    seq = [r for r in rows if start <= r["game"] <= end + 0.5]
    out, last_vis, thr = [], None, None
    for r in seq:
        b = bed(r, i)
        if not b:
            continue
        rg = ring(r)
        if thr is None and b.get("clip") == "SRC_Tug" and (rg is None or rg >= 0.999 or (rg == 0.0 and b["t"] > 0.3)):
            thr = r["game"]
        out.append(dict(game=r["game"], dt=r["dt"], clip=b.get("clip"), t=b.get("t"), vis=b.get("vis"), ring=rg,
                        crown_x=round(local_x(b, "crown"), 3), offset=b.get("offset"), walked=None))
        if b.get("vis"):
            last_vis = r["game"]
    window = [o for o in out if thr is not None and thr <= o["game"] <= (last_vis or thr)]
    return dict(threshold_tick=thr, last_visible_tick=last_vis, window=window,
                drawn_alpha_in_window=[round(o["t"] / TUG_S, 4) for o in window if o["clip"] == "SRC_Tug"],
                crown_x_in_window=[o["crown_x"] for o in window], tail=out[-12:] if out else [])


def pressless(rows, marks, reps):
    out = []
    for k in range(1, reps + 1):
        p = "B%d" % k
        ws, we = marks_of(marks, p + "_wait_start"), marks_of(marks, p + "_wait_end")
        pr = marks_of(marks, p + "_bed2_down")
        if not ws or not pr:
            out.append(dict(rep=k, error="marks missing"))
            continue
        before = [r for r in rows if marks_of(marks, p + "_bed1_up")[0] <= r["game"] < pr[0]]
        grip_before = [r for r in before if bed(r, 1).get("clip") == "SRC_Grip"]
        intents_live = [(r["game"], r.get("intents")) for r in before
                        if any((v or ["IDLE"])[0] != "IDLE" for k2, v in (r.get("intents") or {}).items() if k2 != "error")]
        after = [r for r in rows if pr[0] <= r["game"] <= pr[0] + 0.6]
        first_grip = next((r["game"] for r in after if bed(r, 1).get("clip") == "SRC_Grip"), None)
        first_intent = next((r for r in after if (r.get("intents") or {}).get("use", ["IDLE"])[0] != "IDLE"), None)
        back = [r for r in rows if p + "_back1" == r.get("phase")]
        max_alpha = max((bed(r, 1)["t"] / TUG_S for r in back if bed(r, 1).get("clip") == "SRC_Tug"), default=None)
        max_ring = max((ring(r) or 0 for r in back), default=None)
        out.append(dict(rep=k, use_up=marks_of(marks, p + "_bed1_up")[0], wait=[ws[0], we[0] if we else None], press=pr[0],
                        grip_before_press=[(r["game"], r["keys"], r.get("intents")) for r in grip_before[:5]],
                        intents_not_idle_before_press=intents_live[:8], first_grip_after_press=first_grip,
                        first_use_intent_after_press=None if not first_intent else (first_intent["game"], first_intent.get("intents")),
                        max_alpha_in_back=None if max_alpha is None else round(max_alpha, 4), max_ring_in_back=max_ring,
                        bed_readout=next((m.get("bed") for m in marks if m["label"] == p + "_bed2_after_cancel"), None)))
    return out


def cancel(rows, marks, i, label_up, until_label):
    T, L = TRAVEL[i]
    up = marks_of(marks, label_up)[0]
    until = marks_of(marks, until_label)[0] if marks_of(marks, until_label) else up + 3.0
    seq = [r for r in rows if up - 0.05 <= r["game"] <= until and bed(r, i).get("vis")]
    steps, prev = [], None
    for r in seq:
        b = bed(r, i)
        if prev is not None:
            pb = bed(prev, i)
            st = max(math.dist(b["sock_r"], pb["sock_r"]), math.dist(b["sock_l"], pb["sock_l"]))
            dt = r["game"] - prev["game"]
            steps.append(dict(game=r["game"], dt=r["dt"], sw=pb["clip"] + "->" + b["clip"], t=b["t"], step=round(st, 3),
                              per_60hz=round(st / dt / 60.0, 3) if dt > 0 else None, offset_x=(b.get("offset") or [0])[0],
                              crown_x=round(local_x(b, "crown"), 3)))
        prev = r
    tug = [r for r in seq if bed(r, i).get("clip") == "SRC_Tug"]
    can = [s for s in steps if s["sw"].endswith("SRC_Cancel")]
    first = next((s for s in steps if s["sw"] == "SRC_Tug->SRC_Cancel"), None)
    a_last = bed(tug[-1], i)["t"] / TUG_S if tug else None
    return dict(up=up, last_tug_alpha=None if a_last is None else round(a_last, 4),
                first_cancel=first, start_alpha=None if not first else round(first["t"] / CANCEL_S, 4),
                want_start=None if a_last is None else round(1 - a_last, 4),
                switch_step=None if not first else first["step"],
                step_after_switch=next((s["step"] for s in steps if first and s["game"] > first["game"]), None),
                per_60hz_max=max((s["per_60hz"] for s in can if s["per_60hz"] is not None and s["dt"] < 0.05), default=None),
                steps=steps[:30])


def main(path, outp):
    d = json.load(open(path))
    rows, marks = d["rows"], d["marks"]
    reps = len([m for m in marks if m["label"].endswith("_wait_start")])
    res = {"source": path}
    res["lag_bed1_slow"] = lag(rows, 0, ("A_back",))
    res["lag_bed2_slow"] = lag(rows, 1, ("C_back", "C_back2"))
    res["lag_bed1_fast"] = lag(rows, 0, ("D_fast",))
    res["strain_held_bed1_fast"] = strain_held(rows, 0, marks_of(marks, "D_fast_start")[0], marks_of(marks, "D_gone")[0])
    res["strain_held_bed2_slow"] = strain_held(rows, 1, marks_of(marks, "C_down")[0], marks_of(marks, "C_gone")[0])
    res["pressless"] = pressless(rows, marks, reps)
    res["cancel_bed1_A"] = cancel(rows, marks, 0, "A_up", "B1_bed1_down")
    res["cancels_bed2"] = [cancel(rows, marks, 1, "B%d_bed2_up" % k, "B%d_bed2_after_cancel" % k) for k in range(1, reps + 1)]
    res["readouts"] = [(m["label"], m.get("bed")) for m in marks if isinstance(m.get("bed"), str)]
    json.dump(res, open(outp, "w"), indent=0)
    for k in ("lag_bed1_slow", "lag_bed2_slow", "lag_bed1_fast"):
        print(k, res[k])
    for k in ("strain_held_bed1_fast", "strain_held_bed2_slow"):
        s = res[k]
        print(k, {x: s[x] for x in ("threshold_tick", "last_visible_tick", "drawn_alpha_in_window", "crown_x_in_window")})
    for p in res["pressless"]:
        print("pressless", {x: p.get(x) for x in ("rep", "use_up", "wait", "press", "grip_before_press", "intents_not_idle_before_press",
                                                   "first_grip_after_press", "first_use_intent_after_press", "max_alpha_in_back", "max_ring_in_back")})
    for c in [res["cancel_bed1_A"]] + res["cancels_bed2"]:
        print("cancel", {x: c.get(x) for x in ("last_tug_alpha", "start_alpha", "want_start", "switch_step", "step_after_switch", "per_60hz_max")})
    print("readouts", [(a, (b or "")[60:140]) for a, b in res["readouts"]])


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
