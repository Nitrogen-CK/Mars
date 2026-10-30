"""Host-side runner for mars_devlog_stage_ue.py (plain Python 3.10 + Pillow; no unreal).

    python run_stage.py --build [--bays turntable,cooking] [--rebuild-materials]   # map + assets, then reflections
    python run_stage.py --reflections                                            # rebuild + save the reflection data
    python run_stage.py --stills [--only a,b] [--draft]                          # review stills + stats + contact sheets
    python run_stage.py --calibrate [--bays cooking]                             # grey / chrome probe close-ups + stats
    python run_stage.py --call "st.resolve('cook_34')"                           # any editor-side call
    python run_stage.py --quit                                                   # quit the hidden editor

Launches a hidden MarsEditor on 9317 (or reuses the one there; never 9316). Each still is one Monolith call: it renders
at 2x (SUPERSAMPLE) into stage_review/_raw/, the host downsamples it (Lanczos) to 1920x1080 8-bit RGB in stage_review/,
prints a histogram summary and builds stage_review_contact.png (4x3) and stage_review_cooking_contact.png.
"""
import argparse
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "Tools", "Blender", "mars_cooking", "unreal"))
import mars_cook_parity as cp  # noqa: E402  (Monolith client, wait_for, launch, quit_editor)

PORT = 9317
LOG = os.path.join(REPO, "Saved", "Logs", "HiddenEnv_Mars.log")
REVIEW = r"D:\Repo\Content\Devlog\stage_review"
SCRATCH = r"C:\Users\Stephen\AppData\Local\Temp\claude\D--Repo-Mars\5f3efb8e-b134-46b6-83b7-6ce0a5233bff\scratchpad\stage_agent"
FONT = r"C:\Windows\Fonts\bahnschrift.ttf"


def module_code(call):
    return ("import sys, importlib\n"
            "sys.path.insert(0, r'%s')\n"
            "import devlog_unreal_shots as ds\n"
            "importlib.reload(ds)\n"
            "import mars_devlog_stage_ue as st\n"
            "importlib.reload(st)\n"
            "import json\n"
            "_r = %s\n"
            "print('RESULT ' + json.dumps(_r, default=str))\n") % (HERE, call)


def connect():
    try:
        m = cp.Monolith(PORT)
        m.python("print(1)")
        return m
    except Exception:
        pass
    print("launching a hidden MarsEditor on %d (log %s)" % (PORT, LOG), flush=True)
    cp.launch(PORT, LOG)
    return cp.wait_for(PORT, 1800)


def call(m, expr):
    text = m.python(module_code(expr), check=False)
    try:
        outer = json.loads(text)
        outs = [o.get("output", "") for o in outer.get("output", [])] if isinstance(outer, dict) else [text]
        text = "".join(outs) if outs else text
    except Exception:
        pass
    for line in text.splitlines():
        if "RESULT " in line:
            return json.loads(line[line.index("RESULT ") + 7:])
    raise RuntimeError("editor call failed: %s\n%s" % (expr, text[-4000:]))


# ---------------------------------------------------------------- image checks
def stats(path, backdrop_max=40):
    """Luma percentiles of the frame and of its 'subject' pixels (brighter than the backdrop / floor)."""
    import numpy as np
    from PIL import Image
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    y = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    sub = y[y > backdrop_max]
    top = a[: a.shape[0] // 12].reshape(-1, 3).mean(0)
    out = {"mean": round(float(y.mean()), 1), "p1": round(float(np.percentile(y, 1)), 1),
           "p50": round(float(np.percentile(y, 50)), 1), "p99": round(float(np.percentile(y, 99)), 1),
           "blown%": round(float((a.max(axis=2) >= 250).mean() * 100), 2),
           "black%": round(float((a.max(axis=2) <= 3).mean() * 100), 2),
           "top_rgb": [round(float(v), 1) for v in top],
           "subject%": round(float(sub.size) / y.size * 100, 1)}
    if sub.size:
        out.update({"sub_p5": round(float(np.percentile(sub, 5)), 1), "sub_p50": round(float(np.percentile(sub, 50)), 1),
                    "sub_p95": round(float(np.percentile(sub, 95)), 1), "sub_p99.5": round(float(np.percentile(sub, 99.5)), 1)})
    return out


def finish_still(raw, dst, ss):
    from PIL import Image
    im = Image.open(raw).convert("RGB")
    if ss > 1:
        im = im.resize((im.width // ss, im.height // ss), Image.LANCZOS)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    im.save(dst, compress_level=4)
    return dst


def contact(names, out, cols=4, tile=(640, 360)):
    from PIL import Image, ImageDraw, ImageFont
    rows = (len(names) + cols - 1) // cols
    gap, lab = 8, 30
    W = cols * tile[0] + (cols + 1) * gap
    H = rows * (tile[1] + lab) + (rows + 1) * gap
    sheet = Image.new("RGB", (W, H), (12, 12, 15))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype(FONT, 20)
    except OSError:
        font = ImageFont.load_default()
    for i, n in enumerate(names):
        p = os.path.join(REVIEW, n + ".png")
        if not os.path.isfile(p):
            continue
        r, c = divmod(i, cols)
        x = gap + c * (tile[0] + gap)
        y = gap + r * (tile[1] + lab + gap)
        sheet.paste(Image.open(p).convert("RGB").resize(tile, Image.LANCZOS), (x, y))
        d.text((x + 4, y + tile[1] + 4), n, fill=(210, 210, 215), font=font)
    sheet.save(out)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", action="store_true")
    ap.add_argument("--bays")
    ap.add_argument("--rebuild-materials", action="store_true")
    ap.add_argument("--reflections", action="store_true")
    ap.add_argument("--stills", action="store_true")
    ap.add_argument("--only")
    ap.add_argument("--draft", action="store_true")
    ap.add_argument("--calibrate", action="store_true")
    ap.add_argument("--call")
    ap.add_argument("--quit", action="store_true")
    a = ap.parse_args()
    if a.quit:
        try:
            m = cp.Monolith(PORT)
        except Exception:
            print("no editor on %d" % PORT)
            return
        cp.quit_editor(m, None)
        print("QUIT sent to %d" % PORT)
        return
    m = connect()
    bays = a.bays.split(",") if a.bays else None
    if a.build:
        print(json.dumps(call(m, "st.build_map(%r, True, %r)" % (bays, a.rebuild_materials)), indent=1))
        a.reflections = True
    if a.reflections:
        print("reflections:", call(m, "st.build_reflections()"))
    if a.call:
        print(json.dumps(call(m, a.call), indent=1, default=str))
    if a.calibrate:
        for b in bays or ["turntable", "cooking", "room"]:
            call(m, "st.calibrate(%r)" % b)
            r = call(m, "st.capture_still()")
            print(b, r["file"], json.dumps(stats(r["file"])))
    if a.stills:
        names = call(m, "st.still_names()")
        if a.only:
            names = [n for n in names if n in a.only.split(",")]
        report = {}
        for n in names:
            t0 = time.time()
            call(m, "st.prepare_still(%r, draft=%r)" % (n, a.draft))
            shot = call(m, "st.capture_still()")
            dst = os.path.join(SCRATCH, "drafts", n + ".png") if a.draft else os.path.join(REVIEW, n + ".png")
            finish_still(shot["file"], dst, shot.get("supersample", 1))
            s = stats(dst)
            report[n] = s
            print("%-22s %4.0fs %s" % (n, time.time() - t0, json.dumps(s)), flush=True)
        if not a.draft:
            names_all = call(m, "st.still_names()")
            full = {n: stats(os.path.join(REVIEW, n + ".png")) for n in names_all
                    if os.path.isfile(os.path.join(REVIEW, n + ".png"))}
            with open(os.path.join(REVIEW, "stage_review_stats.json"), "w") as fh:
                json.dump(full, fh, indent=1)
            contact([n for n in call(m, "st.CONTACT") if n in names_all], os.path.join(REVIEW, "stage_review_contact.png"))
            contact([n for n in names_all if n.startswith("cook_")], os.path.join(REVIEW, "stage_review_cooking_contact.png"))


if __name__ == "__main__":
    main()
