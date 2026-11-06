"""Phase I: diff two expected_anims.json files clip by clip (plain Python, no Blender).

Every numeric leaf of every frame (landmark bone heads, extremes, scale, shape-key values, root deviation) and the peak
vertices are compared; a clip is UNCHANGED when its frame set is equal and the max abs difference <= --tol (cm, default
0.001). Run (from the screaming_turnip_r01 folder):
  python scripts/diff_expected_anims.py review/phaseI/baseline/expected_anims.json export/anims/expected_anims.json \
      [--expect-changed SRC_Tug,SRC_Release,SRC_Cancel] [--out review/phaseI/expected_anims_diff.json]
--bones-only (Part 1b): UNCHANGED judges only the bone landmarks (heads, root_dev, scale, shape-key values); the skinned
extremes and peak vertices are reported per clip but not judged (the stem weights changed).
Prints TURNIP_OK when the unchanged set is exactly all clips minus --expect-changed, else TURNIP_FAIL.
"""
import json
import sys


def leaves(x, path=""):
    if isinstance(x, dict):
        for k in sorted(x):
            yield from leaves(x[k], path + "/" + str(k))
    elif isinstance(x, list):
        for i, v in enumerate(x):
            yield from leaves(v, "%s[%d]" % (path, i))
    else:
        yield path, x


def clip_diff(a, b):
    la, lb = dict(leaves(a)), dict(leaves(b))
    if set(la) != set(lb):
        return {"structure": sorted(set(la) ^ set(lb))[:10]}, float("inf")
    worst, where = 0.0, None
    for k, v in la.items():
        w = lb[k]
        if isinstance(v, (int, float)) and not isinstance(v, bool) and isinstance(w, (int, float)):
            d = abs(float(v) - float(w))
        else:
            d = 0.0 if v == w else float("inf")
        if d > worst:
            worst, where = d, k
    return {"max_abs": worst, "at": where, "leaves": len(la)}, worst


def main():
    args = [a for a in sys.argv[1:]]
    opt = lambda k, d=None: args[args.index(k) + 1] if k in args else d
    a_p, b_p = args[0], args[1]
    tol = float(opt("--tol", "0.001"))
    expect = set(opt("--expect-changed", "").split(",")) - {""}
    A, B = json.load(open(a_p))["clips"], json.load(open(b_p))["clips"]
    rep, changed, fails = {}, set(), []
    for n in sorted(set(A) | set(B)):
        if n not in A or n not in B:
            fails.append("%s missing on one side" % n)
            continue
        d, worst = clip_diff(A[n], B[n])
        # Part 1b: split the difference into bone landmarks (heads, root_dev, scale, sk) vs skinned extremes vs peak verts
        bones_w, ext_w = 0.0, 0.0
        for f, la in A[n]["landmarks"].items():
            lb = B[n]["landmarks"].get(f, {})
            for k, v in la.items():
                w = lb.get(k)
                dd = clip_diff({"x": v}, {"x": w})[1] if w is not None else float("inf")
                if k == "extremes":
                    ext_w = max(ext_w, dd)
                else:
                    bones_w = max(bones_w, dd)
        d["bone_landmarks_max_abs"] = bones_w
        d["extremes_max_abs"] = ext_w
        d["peak_verts_max_abs"] = clip_diff(A[n].get("peak_verts_blender_cm", {}), B[n].get("peak_verts_blender_cm", {}))[1]
        if "--bones-only" in args:
            worst = bones_w
        d["unchanged"] = worst <= tol
        if not d["unchanged"]:
            changed.add(n)
        rep[n] = d
        print("%-24s %s bones %.6f extremes %.4f peak_verts %.4f (all-leaf max %s at %s)" % (
            n, "UNCHANGED" if d["unchanged"] else "CHANGED  ", d["bone_landmarks_max_abs"], d["extremes_max_abs"],
            d["peak_verts_max_abs"], d.get("max_abs"), d.get("at")))
    if expect and changed != expect:
        fails.append("changed %s != expected %s" % (sorted(changed), sorted(expect)))
    out = opt("--out")
    if out:
        json.dump({"a": a_p, "b": b_p, "tol_cm": tol, "clips": rep, "changed": sorted(changed), "fails": fails},
                  open(out, "w"), indent=1, default=str)
    print("TURNIP_FAIL " + "; ".join(fails) if fails else "TURNIP_OK (%d changed: %s)" % (len(changed), sorted(changed)))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
