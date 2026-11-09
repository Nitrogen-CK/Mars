"""The planted sockets vs SRC_Tug's authored socket travel (crown_travel.json) at the same row's scrub alpha and at the
previous row's: which one the drawn pose matches. python pose_lag.py <analysis.json> ..."""
import json, sys
sys.path.insert(0, __file__.rsplit("/", 1)[0] if "/" in __file__ else ".")
import analyse_walk as A
for path in sys.argv[1:]:
    a = json.load(open(path))
    for k in ("bed0", "bed1_pull1", "bed1_pull2"):
        rows = a[k]["rows"]
        same = max(max(abs(x - A.clip_travel(q["alpha"])) for x in q["local_travel"]) for p, q in zip(rows, rows[1:]))
        prev = max(max(abs(x - A.clip_travel(p["alpha"])) for x in q["local_travel"]) for p, q in zip(rows, rows[1:]))
        print(path.replace("\\", "/").split("/")[-2], k, "vs clip at same-row alpha max %.3f cm; at previous-row alpha max %.3f cm" % (same, prev))
