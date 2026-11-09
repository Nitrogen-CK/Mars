"""Part 3e: a full-speed walk pull, per tick from its fast-walk start to the release.
python analyse_fast.py <walk_rows.json> <bed> <d0 mark index> <fast start mark> <out.json>"""
import json, math, sys
WALK = 146.2
d = json.load(open(sys.argv[1])); rows, marks = d["rows"], d["marks"]
i, n, start_label = int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
d0 = [m for m in marks if m["label"] == "d0"][n]["d0"]
t0 = next(m["game"] for m in marks if m["label"] == start_label)
per, prev, released_at = [], None, None
for r in rows:
    if r["game"] < t0:
        continue
    b = r["beds"].get(str(i)) or {}
    if b.get("vis") is False:
        released_at = dict(game=r["game"], dt=r["dt"], walked=round(r["d%d" % i] - d0, 2)); break
    if b.get("clip") != "SRC_Tug":
        continue
    a = b["t"] / 0.5
    w = r["d%d" % i] - d0
    ring = [x.get("pct") for x in r.get("ring") or [] if x.get("pct") is not None]
    gs = max(math.dist(r["grip_r"], b["sock_r"]), math.dist(r["grip_l"], b["sock_l"])) if "grip_r" in r else None
    gl = max(math.dist(r["grip_r"], prev["sock_r"]), math.dist(r["grip_l"], prev["sock_l"])) if prev is not None and "grip_r" in r else None
    per.append(dict(game=round(r["game"], 4), dt=r["dt"], walked=round(w, 2), want=round(min(1, max(0, w / WALK)), 4),
                    alpha=round(a, 4), ring=ring[0] if ring else None, trail=round(min(1, max(0, w / WALK)) - a, 4),
                    glove_same=None if gs is None else round(gs, 3), glove_lag1=None if gl is None else round(gl, 3)))
    prev = b
sp = [(q["walked"] - p["walked"]) / (q["game"] - p["game"]) for p, q in zip(per, per[1:]) if q["game"] > p["game"]]
fp = [p for p in per if p["glove_same"] is not None and p["glove_same"] < 50]
out = dict(d0=d0, n=len(per), dt_max=max(p["dt"] for p in per), walk_speed_max=round(max(sp), 1),
           last_visible=per[-1], released_at=released_at,
           walked_at_break_vs_walkcm=round(per[-1]["walked"] - WALK, 2) if per else None,
           trail_max=max(p["trail"] for p in per),
           ring_x097_vs_alpha_max=max(abs(p["ring"] * 0.97 - p["alpha"]) for p in per if p["ring"] is not None),
           glove_lag1_max=max((p["glove_lag1"] for p in fp if p["glove_lag1"] is not None), default=None),
           glove_lag1_over_05=sum(1 for p in fp if (p["glove_lag1"] or 0) > 0.5),
           glove_same_max=max(p["glove_same"] for p in fp), rows_chase_view_excluded=len(per) - len(fp), rows=per)
json.dump(out, open(sys.argv[5], "w"), indent=0)
print({k: v for k, v in out.items() if k != "rows"})
for p in per[::4]: print("  ", p)
