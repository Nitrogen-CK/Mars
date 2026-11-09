"""Phase K Part 1: summarise the --inject-stretch runs (review/phaseK/inject_T_L.json) into inject_summary.json, read by the
export for gameplay_numbers.stretch_runtime_safe_travel_cm. Plain Python. Run from the screaming_turnip_r01 folder:
  python review/phaseK/inject_summary_k.py
Prints TURNIP_OK (the default passes and a failure was found above it) / TURNIP_FAIL."""
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT = (146.2, 20.0)          # the bed's FMars_ScreamingTurnipBed_StretchSpec default; animate DEFAULT_STRETCH
runs = []
for p in glob.glob(os.path.join(HERE, "inject_*.json")):
    if not re.match(r"inject_[0-9.]+_[0-9.]+\.json$", os.path.basename(p)):
        continue
    d = json.load(open(p))
    first = d["fails"][0] if d["fails"] else None
    gates = sorted({re.sub(r" \[.*|\{.*|[-0-9.]+$", "", f.split(": ", 1)[1]).strip() for f in d["fails"]})
    tug = d["clips"]["SRC_Tug"]
    runs.append({"T_cm": d["T_cm"], "L_cm": d["L_cm"], "pass": not d["fails"], "fail_count": len(d["fails"]),
                 "failing_gates": gates, "first_fail": first,
                 "tug_full": {"crown_xz": tug["crown_at_full"], "socket_R": tug["socket_R_at_full"],
                              "dimple_d_xz": tug["dimple_d_at_full"], "ring_max_d": tug["ring_max_d_at_full"],
                              "stem_gap_max": tug["stem_gap_max"]},
                 "release_info_count": len(d.get("release_info", []))})
runs.sort(key=lambda r: r["T_cm"])
dflt = [r for r in runs if abs(r["T_cm"] - DEFAULT[0]) < 1e-6]
above = [r for r in runs if r["T_cm"] > DEFAULT[0]]
first_fail_above = next((r for r in above if not r["pass"]), None)
safe_max = max((r["T_cm"] for r in above if r["pass"] and (first_fail_above is None or r["T_cm"] < first_fail_above["T_cm"])),
               default=None)
below = [r for r in runs if r["T_cm"] <= DEFAULT[0]]
last_fail_below = max((r["T_cm"] for r in below if not r["pass"]), default=None)
safe_min = min((r["T_cm"] for r in below if r["pass"] and (last_fail_below is None or r["T_cm"] > last_fail_below)),
               default=None)
out = {"what": "runtime crown offset (-T * a, 0, L * a) UE cm injected on SRC_Tug (a = f / 15) and SRC_Cancel (a = 1 - f / 7);"
               " gates: intersections 0, stem_gap <= 0, neck (dimple <= 9 cm x / <= 3 cm z from Tug f0, ring below the"
               " dimple); SRC_Release is info only (the bed never plays it); L ~ 0.137 T above the brief's four points",
       "default": {"T_cm": DEFAULT[0], "L_cm": DEFAULT[1]},
       "default_run": dflt[0] if dflt else None,
       "safe_travel_cm": [safe_min, safe_max],
       "first_fail_above_default": first_fail_above,
       "last_fail_below_default": last_fail_below,
       "runs": runs}
json.dump(out, open(os.path.join(HERE, "inject_summary.json"), "w"), indent=1)
for r in runs:
    print("T %6.1f L %5.1f  %s  %s" % (r["T_cm"], r["L_cm"], "PASS" if r["pass"] else "FAIL %2d" % r["fail_count"],
                                       ", ".join(r["failing_gates"])))
print("SAFE", out["safe_travel_cm"], "first fail above", first_fail_above and (first_fail_above["T_cm"], first_fail_above["first_fail"]))
ok = bool(dflt and dflt[0]["pass"] and first_fail_above is not None)
print("TURNIP_OK inject_summary" if ok else "TURNIP_FAIL inject_summary")
sys.exit(0 if ok else 1)
