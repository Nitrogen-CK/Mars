"""Phase K Part 3: numbers from run-12-walk/walk_rows.json (the stretch applied by the ABP; bed 0 TravelCm 74 / LiftCm 9,
bed 1 TravelCm 146.2 / LiftCm 18). python analyse_run12.py <walk_rows.json> <out.json>

Per tick: alpha = the instance's ClipTime / 0.5 s while SRC_Tug plays (the bed scrubs the Tug to the Control's alpha); the
ring = the prompt's Percent (Control alpha / 0.97); `offset` = the instance's CrownOffset (component space); the crown /
HarvestGrip sockets in the planted component's own frame (location `loc`, yaw `yaw`); the glove bones."""
import json, math, sys

BED_XY = ((0.0, 0.0), (450.0, -450.0))
TRAVEL = {0: (74.0, 9.0), 1: (146.2, 18.0)}
TUG_S, CANCEL_S = 0.5, 7 / 30.0
SOCK_F0_X = -1.522


def local(b, key):
    c, s = math.cos(math.radians(b["yaw"])), math.sin(math.radians(b["yaw"]))
    dx, dy, dz = (b[key][k] - b["loc"][k] for k in range(3))
    return [dx * c + dy * s, -dx * s + dy * c, dz]


def bed(r, i):
    return r["beds"].get(str(i)) or {}


def mark(marks, label, n=0):
    h = [m for m in marks if m["label"] == label]
    return h[n]["game"] if len(h) > n else None


def ring(r):
    v = [x.get("pct") for x in r.get("ring") or [] if x.get("pct") is not None]
    return v[0] if v else None


def pull(rows, marks, i, press, end, d0):
    T, L = TRAVEL[i]
    per, prev = [], None
    for r in rows:
        b = bed(r, i)
        if not (press <= r["game"] <= end) or not b or not b.get("vis") or b.get("clip") not in ("SRC_Tug", "SRC_Grip"):
            prev = None if not b or not b.get("vis") else prev
            continue
        a = b["t"] / TUG_S if b["clip"] == "SRC_Tug" else 0.0
        cr = local(b, "crown")
        sr, sl = local(b, "sock_r"), local(b, "sock_l")
        g_same = max(math.dist(r["grip_r"], b["sock_r"]), math.dist(r["grip_l"], b["sock_l"])) if "grip_r" in r else None
        g_lag = max(math.dist(r["grip_r"], prev["sock_r"]), math.dist(r["grip_l"], prev["sock_l"])) if prev and "grip_r" in r else None
        off = b.get("offset") or [0, 0, 0]
        per.append(dict(game=r["game"], dt=r["dt"], phase=r.get("phase"), walked=round(r["d%d" % i] - d0, 2), clip=b["clip"],
                        alpha=round(a, 4), ring=ring(r), offset=off,
                        offset_err=round(max(abs(off[0] + a * T), abs(off[2] - a * L)), 4),
                        crown_x=round(cr[0], 3), crown_x_err=round(cr[0] + a * T, 3), crown_z=round(cr[2], 3),
                        sock_travel=round(-(sr[0] - SOCK_F0_X), 3), sock_travel_l=round(-(sl[0] - SOCK_F0_X), 3),
                        glove_same=None if g_same is None else round(g_same, 3), glove_lag1=None if g_lag is None else round(g_lag, 3),
                        rendered=b.get("rendered")))
        prev = b
    tug = [p for p in per if p["clip"] == "SRC_Tug"]
    fp = [p for p in tug if p["glove_same"] is not None and p["glove_same"] < 50 and p["phase"] not in ("hold0", "hold1b", "offscreen1b")]
    hold = [p for p in tug if p["phase"] in ("hold0", "hold1b")]
    last = tug[-1] if tug else None
    out = dict(bed=i, travel=T, lift=L, d0=d0, n=len(per), n_tug=len(tug),
               last_visible=last, walked_at_break_vs_travel=None if not last else round(last["walked"] - T, 2),
               crown_x_err_max_abs=max(abs(p["crown_x_err"]) for p in tug) if tug else None,
               offset_err_max=max(p["offset_err"] for p in tug) if tug else None,
               ring_vs_alpha_max=max((abs(p["ring"] * 0.97 - p["alpha"]) for p in tug if p["ring"] is not None), default=None),
               hold=dict(n=len(hold), alpha=[min((p["alpha"] for p in hold), default=None), max((p["alpha"] for p in hold), default=None)],
                         crown_x=[min((p["crown_x"] for p in hold), default=None), max((p["crown_x"] for p in hold), default=None)],
                         crown_x_at_alpha1_extrapolated=round(hold[-1]["crown_x"] / hold[-1]["alpha"], 3) if hold and hold[-1]["alpha"] else None),
               full_strain_crown_x=None if not last else last["crown_x"],
               full_strain_crown_x_vs_minus_travel=None if not last else round(last["crown_x"] + T, 3),
               sock_travel_at_last=None if not last else [last["sock_travel"], last["sock_travel_l"]],
               sock_travel_per_alpha_at_last=None if not last or not last["alpha"] else round(last["sock_travel"] / last["alpha"], 3),
               gloves=dict(n=len(fp), lag1_max=max((p["glove_lag1"] for p in fp if p["glove_lag1"] is not None), default=None),
                           same_max=max((p["glove_same"] for p in fp), default=None),
                           same_mean=round(sum(p["glove_same"] for p in fp) / len(fp), 4) if fp else None),
               rows=per)
    return out


def cancel(rows, i, up, until):
    T, L = TRAVEL[i]
    seq = [r for r in rows if up - 0.05 <= r["game"] <= until and bed(r, i) and bed(r, i).get("vis")]
    steps, prev = [], None
    for r in seq:
        b = bed(r, i)
        cr = local(b, "crown")
        if b["clip"] == "SRC_Tug":
            a_stretch = b["t"] / TUG_S
        elif b["clip"] == "SRC_Cancel":
            a_stretch = 1.0 - b["t"] / CANCEL_S
        else:
            a_stretch = 0.0
        off = b.get("offset") or [0, 0, 0]
        row = dict(game=r["game"], dt=r["dt"], clip=b["clip"], t=b["t"], stretch_alpha=round(a_stretch, 4), offset_x=off[0],
                   offset_vs_clip=round(off[0] + a_stretch * T, 3), crown_x=round(cr[0], 3),
                   glove=round(max(math.dist(r["grip_r"], b["sock_r"]), math.dist(r["grip_l"], b["sock_l"])), 3) if "grip_r" in r else None)
        if prev is not None:
            pb = bed(prev, i)
            st = max(math.dist(b["sock_r"], pb["sock_r"]), math.dist(b["sock_l"], pb["sock_l"]))
            dtt = r["game"] - prev["game"]
            row.update(step=round(st, 3), per_60hz=round(st / dtt / 60.0, 3) if dtt > 0 else None,
                       switch=pb["clip"] + "->" + b["clip"])
        steps.append(row)
        prev = r
    can = [s for s in steps if s["clip"] == "SRC_Cancel"]
    tug_last = [s for s in steps if s["clip"] == "SRC_Tug"]
    return dict(last_tug=tug_last[-1] if tug_last else None, first_cancel=can[0] if can else None,
                start_alpha=round(can[0]["t"] / CANCEL_S, 4) if can else None,
                want_start=round(1 - tug_last[-1]["stretch_alpha"], 4) if tug_last else None,
                switch_steps=[s for s in steps if "Tug->SRC_Cancel" in (s.get("switch") or "")] +
                             [s for s in steps if s.get("switch") == "SRC_Cancel->SRC_Cancel"][:2],
                in_clip_per_60hz_max=max((s["per_60hz"] for s in can if s.get("per_60hz") is not None and s["dt"] < 0.05), default=None),
                in_clip_step_max=max((s["step"] for s in can if s.get("step") is not None), default=None),
                offset_vs_clip_max_abs=max((abs(s["offset_vs_clip"]) for s in can), default=None),
                idle_at=next((s["game"] for s in steps if s["clip"] == "SRC_Idle" and s["game"] > up), None), steps=steps[:80])


def main(path, out):
    d = json.load(open(path))
    rows, marks = d["rows"], d["marks"]
    d0s = [m["d0"] for m in marks if m["label"] == "d0"]
    res = {"source": path}
    res["bed1_travel74"] = pull(rows, marks, 0, mark(marks, "use0_down"), mark(marks, "bed0_gone"), d0s[0])
    res["bed2_pull1"] = pull(rows, marks, 1, mark(marks, "use1a_down"), mark(marks, "use1a_up"), d0s[1])
    res["bed2_cancel"] = cancel(rows, 1, mark(marks, "use1a_up"), mark(marks, "use1b_down"))
    res["bed2_pull2"] = pull(rows, marks, 1, mark(marks, "use1b_down"), mark(marks, "bed1_gone"), d0s[2])
    off = [bed(r, 1) for r in rows if r.get("phase") == "offscreen1b" and bed(r, 1)]
    res["bed2_offscreen"] = dict(n=len(off), rendered=[b.get("rendered") for b in off],
                                 alpha=[round(b["t"] / TUG_S, 4) for b in off if b.get("clip") == "SRC_Tug"][:3])
    res["readouts"] = [(m["label"], m.get("bed")) for m in marks if isinstance(m.get("bed"), str)]
    res["morph"] = d.get("morph")
    json.dump(res, open(out, "w"), indent=0)
    for k in ("bed1_travel74", "bed2_pull1", "bed2_pull2"):
        print(k, {x: v for x, v in res[k].items() if x != "rows"})
    c = res["bed2_cancel"]
    print("bed2_cancel", {x: v for x, v in c.items() if x != "steps"})
    print("bed2_offscreen", res["bed2_offscreen"])
    print("readouts", res["readouts"])


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
