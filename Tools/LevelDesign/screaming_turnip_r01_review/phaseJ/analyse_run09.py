"""Part 3e (spring 400 / 40): numbers from run-09-walk/walk_rows.json. python analyse_run09.py <walk_rows.json> <out.json>"""
import json, math, sys
WALK = 146.2
d = json.load(open(sys.argv[1])); rows, marks = d["rows"], d["marks"]
def mk(l, n=0):
    h = [m for m in marks if m["label"] == l]; return h[n] if len(h) > n else None
def bed(r, i): return r["beds"].get(str(i)) or {}
def alpha(r, i):
    b = bed(r, i); return b["t"] / 0.5 if b.get("clip") == "SRC_Tug" else (0.0 if b.get("clip") in ("SRC_Grip", "SRC_Idle") else None)
def ring(r):
    v = [x.get("pct") for x in r.get("ring") or [] if x.get("pct") is not None]; return v[0] if v else None
out = {}
# (1) bed 0 full speed
d0 = mk("d0", 0)["d0"]; t_fast = mk("fast0_start")["game"]
per, prev = [], None
for r in rows:
    b = bed(r, 0)
    if r["game"] < t_fast - 0.05 or not b or not b.get("vis") or b.get("clip") != "SRC_Tug":
        if b and b.get("vis") is False and per: break
        continue
    w = r["d0"] - d0; a = alpha(r, 0)
    g_same = max(math.dist(r["grip_r"], b["sock_r"]), math.dist(r["grip_l"], b["sock_l"])) if "grip_r" in r else None
    g_lag = max(math.dist(r["grip_r"], prev["sock_r"]), math.dist(r["grip_l"], prev["sock_l"])) if prev and "grip_r" in r else None
    per.append(dict(game=r["game"], dt=r["dt"], walked=round(w, 2), want=round(min(1, max(0, w / WALK)), 4), alpha=round(a, 4),
                    trail=round(min(1, max(0, w / WALK)) - a, 4), ring=ring(r), glove_same=None if g_same is None else round(g_same, 3),
                    glove_lag1=None if g_lag is None else round(g_lag, 3), phase=r.get("phase")))
    prev = b
fp = [p for p in per if p["phase"] in ("fast0",) and p["glove_lag1"] is not None]
speeds = [(q["walked"] - p["walked"]) / (q["game"] - p["game"]) for p, q in zip(per, per[1:]) if q["game"] > p["game"]]
out["bed0_fast"] = dict(d0=d0, rows=per, walked_at_break=per[-1]["walked"], over_walkcm=round(per[-1]["walked"] - WALK, 2),
                        alpha_at_last_visible=per[-1]["alpha"], ring_at_last_visible=per[-1]["ring"],
                        trail_max=max(p["trail"] for p in per), walk_speed_max=round(max(speeds), 1),
                        glove_lag1_max=max(p["glove_lag1"] for p in fp), glove_lag1_over_05=sum(p["glove_lag1"] > 0.5 for p in fp),
                        glove_same_max=max(p["glove_same"] for p in fp), n_first_person=len(fp),
                        note="glove rows exclude the side-view stretch (phase fast0 only counts rows before and after it? no: the side view is inside fast0; see glove_rows_side)")
# side view rows: the gloves follow the chase view; mark them
out["bed0_fast"]["glove_same_max_excluding_gt_50cm"] = max((p["glove_same"] for p in fp if p["glove_same"] < 50), default=None)
out["bed0_fast"]["rows_glove_gt_50cm"] = [p["game"] for p in fp if p["glove_same"] >= 50]
# (2) bed 1 stop at 0.5
d1 = mk("d0", 1)["d0"]; ts = mk("stop1a")["game"]; tu = mk("use1a_up")["game"]
hold = [r for r in rows if ts <= r["game"] <= tu]
dist_stop = [r["d1"] for r in hold]
w_end = (hold[-1]["d1"] - d1) / WALK
al = [(r["game"] - ts, alpha(r, 1), (r["d1"] - d1) / WALK) for r in hold]
over = max(a - w for _, a, w in al)
settle = next((dt for dt, a, w in al if all(abs(a2 - w2) <= 0.01 for t2, a2, w2 in al if t2 >= dt)), None)
pre = [r for r in rows if r["game"] < ts and bed(r, 1).get("clip") == "SRC_Tug"]
out["bed1_stop"] = dict(d0=d1, player_moved_during_hold_cm=round(max(dist_stop) - min(dist_stop), 3), want_end=round(w_end, 4),
                        alpha_at_stop=round(al[0][1], 4), want_at_stop=round(al[0][2], 4), alpha_end=round(al[-1][1], 4),
                        overshoot_max=round(over, 4), settle_within_001_after_s=None if settle is None else round(settle, 4),
                        track=[(round(a, 4), round(b, 4), round(c, 4)) for a, b, c in al[::3]])
# cancel after the stop
last = [r for r in rows if r["game"] <= tu and bed(r, 1).get("clip") == "SRC_Tug"][-1]
can = [r for r in rows if r["game"] > tu and bed(r, 1).get("clip") == "SRC_Cancel"]
out["bed1_cancel"] = dict(last_tug_alpha=round(alpha(last, 1), 4), cancel_first_t=bed(can[0], 1)["t"],
                          start_alpha=round(bed(can[0], 1)["t"] / (7 / 30.0), 4), want_start=round(1 - alpha(last, 1), 4),
                          readout=mk("bed1_after_cancel").get("bed"))
# (3) bed 1 slow pull 2
d2 = mk("d0", 2)["d0"]; tb = mk("use1b_down")["game"]
vis = [r for r in rows if r["game"] >= tb and bed(r, 1).get("vis") and bed(r, 1).get("clip") == "SRC_Tug"]
lv = vis[-1]
out["bed1_slow"] = dict(d0=d2, walked_at_break=round(lv["d1"] - d2, 2), alpha_last=round(alpha(lv, 1), 4), ring_last=ring(lv),
                        readout=mk("bed1_after").get("bed"),
                        trail_max=round(max(min(1, (r["d1"] - d2) / WALK) - alpha(r, 1) for r in vis), 4))
json.dump(out, open(sys.argv[2], "w"), indent=0)
for k, v in out.items():
    print(k, {x: y for x, y in v.items() if x not in ("rows", "track")})
print("bed0 per-tick (every 3rd):")
for p in per[::3]: print("  ", p)
print("bed1 hold track (t from stop, alpha, want):", out["bed1_stop"]["track"])
