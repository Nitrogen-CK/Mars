"""Part 3d: per tick, the view ray against the bed's Use probe (AABB: centre bed + (0, 0, 12), half (40, 40, 22);
Mars_ScreamingTurnipBed_EntityScript k_ProbeOffset / k_ProbeHalfExtents; the bed root is not yawed) within the 250 cm trace
(Mars_PlayerCharacter_Assets.as InteractionTraceDistance), the eye-to-probe-centre distance, the bed's focused flag
(Bed() readout) and the prompt ring, from a pull's press to its break. python ray_focus.py <walk_rows.json> <out.json>"""
import json, math, sys
BED_XY = ((0.0, 0.0), (450.0, -450.0))
HALF = (40.0, 40.0, 22.0)
TRACE = 250.0


def ray_hit(cam, c):
    ox, oy, oz, pitch, yaw = cam
    p, y = math.radians(pitch), math.radians(yaw)
    d = (math.cos(p) * math.cos(y), math.cos(p) * math.sin(y), math.sin(p))
    lo = [c[k] - HALF[k] for k in range(3)]
    hi = [c[k] + HALF[k] for k in range(3)]
    o = (ox, oy, oz)
    t0, t1 = -1e9, 1e9
    for k in range(3):
        if abs(d[k]) < 1e-9:
            if not lo[k] <= o[k] <= hi[k]:
                return None
            continue
        a, b = (lo[k] - o[k]) / d[k], (hi[k] - o[k]) / d[k]
        t0, t1 = max(t0, min(a, b)), min(t1, max(a, b))
    return round(t0, 2) if t1 >= max(t0, 0) else None


data = json.load(open(sys.argv[1]))
rows, marks = data["rows"], data["marks"]
def mk(l): return next((m["game"] for m in marks if m["label"] == l), None)
out = {}
for name, i, press, end in (("bed0", 0, mk("use0_down"), mk("bed0_gone")), ("bed1_pull2", 1, mk("use1b_down"), mk("bed1_gone"))):
    c = (BED_XY[i][0], BED_XY[i][1], 12.0)
    per = []
    for r in rows:
        if not (press <= r["game"] <= end) or "cam" not in r:
            continue
        b = r["beds"].get(str(i)) or {}
        th = ray_hit(r["cam"], c)
        eye = math.dist(r["cam"][:3], c)
        ring = [x.get("pct") for x in r.get("ring") or [] if x.get("pct") is not None]
        per.append(dict(game=r["game"], d=r["d%d" % i], eye=round(eye, 2), pitch=r["cam"][3], ray_enter=th,
                        ray_hits_in_trace=th is not None and th <= TRACE, focused=(r.get("focused") or {}).get(str(i)),
                        ring=ring[0] if ring else None, clip=b.get("clip"), alpha=round(b["t"] / 0.5, 4) if b.get("clip") == "SRC_Tug" else None,
                        vis=b.get("vis")))
    miss = [p for p in per if not p["ray_hits_in_trace"]]
    vis = [p for p in per if p["vis"]]
    out[name] = dict(n=len(per), first_ray_miss=miss[0] if miss else None, rows_ray_miss=len(miss),
                     rows_ray_miss_with_ring=sum(1 for p in miss if p["ring"] is not None),
                     rows_ray_miss_focused=sum(1 for p in miss if p["focused"] is True),
                     rows_focused_false=sum(1 for p in per if p["focused"] is False and p["vis"]),
                     last_visible=vis[-1] if vis else None, rows=per)
    print(name, {k: v for k, v in out[name].items() if k != "rows"})
json.dump(out, open(sys.argv[2], "w"), indent=0)
