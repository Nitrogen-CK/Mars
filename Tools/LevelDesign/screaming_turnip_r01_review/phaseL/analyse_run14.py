"""Phase L Part 2: numbers from run-14-walk/walk_rows.json (the gloves grip the HarvestGrip sockets directly).
python analyse_run14.py <walk_rows.json> <out.json>

Per phase: glove bone (grip_r / grip_l) to the SAME row's socket (sock_r / sock_l) and to the previous row's; the drawn alpha
(instance ClipTime / 0.5) against the same row's Control alpha (ring x 0.97); during the sidestep the planted yaw against the
bearing to the player. Rows under a chase view (glove > 50 cm off) are excluded from the glove numbers."""
import json, math, sys

BED_XY = ((0.0, 0.0), (450.0, -450.0))


def bed(r, i):
    return r["beds"].get(str(i)) or {}


def ring(r):
    v = [x.get("pct") for x in r.get("ring") or [] if x.get("pct") is not None]
    return v[0] if v else None


def wrap(a):
    return (a + 180.0) % 360.0 - 180.0


def stats(xs):
    return None if not xs else dict(n=len(xs), mean=round(sum(xs) / len(xs), 4), max=round(max(xs), 4))


def phase_numbers(rows, i, phases):
    sel = [r for r in rows if r.get("phase") in phases and bed(r, i).get("vis") and bed(r, i).get("clip") in ("SRC_Tug", "SRC_Grip")
           and "grip_r" in r]
    same, prev, drawn, speed, yaw = [], [], [], [], []
    for p, q in zip([None] + sel, sel):
        b = bed(q, i)
        gs = max(math.dist(q["grip_r"], b["sock_r"]), math.dist(q["grip_l"], b["sock_l"]))
        if gs > 50:
            continue
        same.append(gs)
        if p is not None and q["game"] - p["game"] < 0.05:
            pb = bed(p, i)
            prev.append(max(math.dist(q["grip_r"], pb["sock_r"]), math.dist(q["grip_l"], pb["sock_l"])))
            speed.append(abs(q["d%d" % i] - p["d%d" % i]) / (q["game"] - p["game"]))
        if b.get("clip") == "SRC_Tug" and ring(q) is not None:
            drawn.append(abs(ring(q) * 0.97 - b["t"] / 0.5))
        px, py = q["player"][0] - BED_XY[i][0], q["player"][1] - BED_XY[i][1]
        yaw.append(abs(wrap(b["yaw"] - math.degrees(math.atan2(-py, -px)))))
    return dict(glove_vs_same_tick_socket=stats(same), glove_vs_prev_tick_socket=stats(prev),
                drawn_vs_control_same_tick=stats(drawn), walk_speed_median=round(sorted(speed)[len(speed) // 2], 1) if speed else None,
                yaw_err=stats(yaw))


def main(path, out):
    d = json.load(open(path))
    rows, marks = d["rows"], d["marks"]
    res = {"source": path}
    res["bed1_slow"] = phase_numbers(rows, 0, ("a1_slow", "a1_slow2"))
    res["bed1_sidestep"] = phase_numbers(rows, 0, ("a1_side",))
    res["bed1_fast"] = phase_numbers(rows, 0, ("a2_fast",))
    res["bed2_slow"] = phase_numbers(rows, 1, ("b1_slow", "b2_slow"))
    res["bed2_fast"] = phase_numbers(rows, 1, ("b3_fast",))
    side = [r for r in rows if r.get("phase") == "a1_side" and bed(r, 0)]
    if side:
        f, l = side[0], side[-1]
        res["sidestep_yaw"] = dict(yaw_from=bed(f, 0)["yaw"], yaw_to=bed(l, 0)["yaw"],
                                   bearing_from=round(math.degrees(math.atan2(-(f["player"][1]), -(f["player"][0]))), 3),
                                   bearing_to=round(math.degrees(math.atan2(-(l["player"][1]), -(l["player"][0]))), 3))
    # the cancel on bed 1 (b1): start alpha and the switch
    up = next(m["game"] for m in marks if m["label"] == "b1_up")
    seq = [r for r in rows if up - 0.05 <= r["game"] <= up + 1.0 and bed(r, 1).get("vis")]
    tug = [r for r in seq if bed(r, 1).get("clip") == "SRC_Tug"]
    can = [r for r in seq if bed(r, 1).get("clip") == "SRC_Cancel"]
    res["bed2_cancel"] = dict(last_tug_alpha=round(bed(tug[-1], 1)["t"] / 0.5, 4) if tug else None,
                              start_alpha=round(bed(can[0], 1)["t"] / (7 / 30.0), 4) if can else None,
                              glove_on_first_cancel_tick=round(max(math.dist(can[0]["grip_r"], bed(can[0], 1)["sock_r"]),
                                                                   math.dist(can[0]["grip_l"], bed(can[0], 1)["sock_l"])), 3) if can else None)
    res["readouts"] = [(m["label"], m.get("bed")) for m in marks if isinstance(m.get("bed"), str)]
    res["breaks"] = [(m["label"], m["game"]) for m in marks if m["label"].endswith("_gone")]
    json.dump(res, open(out, "w"), indent=1)
    for k, v in res.items():
        if k != "source":
            print(k, v)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
