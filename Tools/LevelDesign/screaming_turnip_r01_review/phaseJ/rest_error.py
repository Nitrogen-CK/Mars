"""Alpha vs (d - d0) / WalkCm while the player stands still (the spring settled): rows whose player has not moved > 0.05 cm
for >= 0.5 s game time. python rest_error.py <analysis.json> ..."""
import json, sys
for path in sys.argv[1:]:
    a = json.load(open(path))
    for k in ("bed0", "bed1_pull1", "bed1_pull2"):
        rows = a[k].get("rows", [])
        still, out = None, []
        for p, q in zip(rows, rows[1:]):
            if abs(q["d"] - p["d"]) < 0.05:
                still = still if still is not None else p["game"]
                if q["game"] - still >= 0.5 and q["gained"] > 1.0:
                    out.append(abs(q["err"]))
            else:
                still = None
        print(path.split("/")[-2], k, "rest rows", len(out), "max |alpha - want|", round(max(out), 4) if out else None)
