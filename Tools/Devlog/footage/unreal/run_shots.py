"""Host-side runner for devlog_unreal_shots.py (plain Python 3.10 + Pillow + imageio_ffmpeg; no unreal).

    python run_shots.py --shot <name>|all|A|B [--draft] [--start N --end M] [--no-preview]
    python run_shots.py --call "ds.still('water', (520,290,88), (520,62,88), 50)"     # any editor-side call
    python run_shots.py --list
    python run_shots.py --quit                                                          # quit the hidden editor

Launches a hidden MarsEditor on port 9317 (or reuses the one already listening there; never 9316), then per shot:
prepare (open the map, one-off setup) -> shoot in chunks of --chunk frames (one Monolith call each, under the 1200 s
call timeout) -> finish (restore) -> flatten the PNGs to 8-bit RGB (the render target exports RGBA with a scene-depth
alpha) -> shot.json -> _preview.mp4 (ffmpeg -threads 4).
Full frames go to D:/Repo/Content/Devlog/{mise_crypt,materials}/unreal/<shot>/; drafts (960x540, every 10th frame)
to the session scratchpad drafts/<shot>/.
"""
import argparse
import concurrent.futures as cf
import glob
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
COOKING_UE = os.path.join(REPO, "Tools", "Blender", "mars_cooking", "unreal")
sys.path.insert(0, COOKING_UE)
import mars_cook_parity as cp  # noqa: E402  (Monolith client, wait_for, launch, quit_editor)

PORT = 9317
LOG = os.path.join(REPO, "Saved", "Logs", "HiddenEnv_Mars.log")
SRC_NAME = "Tools/Devlog/footage/unreal/devlog_unreal_shots.py"


def module_code(call):
    return ("import sys, importlib\n"
            "sys.path.insert(0, r'%s')\n"
            "import devlog_unreal_shots as ds\n"
            "importlib.reload(ds)\n"
            "import json\n"
            "_r = %s\n"
            "print('RESULT ' + json.dumps(_r, default=str))\n") % (HERE, call)


def connect(launch=True):
    try:
        m = cp.Monolith(PORT)
        m.python("print(1)")
        return m
    except Exception:
        if not launch:
            raise
    print("launching a hidden MarsEditor on %d (log %s)" % (PORT, LOG), flush=True)
    cp.launch(PORT, LOG)
    return cp.wait_for(PORT, 1500)


def call(m, expr):
    text = m.python(module_code(expr), check=False)
    try:
        outer = json.loads(text)
        outs = [o.get("output", "") for o in outer.get("output", [])] if isinstance(outer, dict) else [text]
        text = "".join(outs) if outs else text
    except Exception:
        pass
    result = None
    for line in text.splitlines():
        if line.startswith("RESULT "):
            result = json.loads(line[7:])
    if result is None:
        raise RuntimeError("editor call failed: %s\n%s" % (expr, text[-4000:]))
    return result


def ffmpeg():
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def _flatten(path):
    from PIL import Image
    im = Image.open(path)
    if im.mode != "RGB":
        im.convert("RGB").save(path, optimize=False, compress_level=4)


def flatten(out_dir):
    files = sorted(glob.glob(os.path.join(out_dir, "[0-9][0-9][0-9][0-9][0-9].png")))
    with cf.ThreadPoolExecutor(6) as ex:
        list(ex.map(_flatten, files))
    return len(files)


def preview(out_dir, name, fps):
    out = os.path.join(out_dir, "_preview.mp4")
    cmd = [ffmpeg(), "-y", "-loglevel", "error", "-framerate", str(fps), "-i", os.path.join(out_dir, "%05d.png"),
           "-c:v", "libx264", "-crf", "23", "-pix_fmt", "yuv420p", "-threads", "4", out]
    subprocess.run(cmd, check=True)
    return out


def run_shot(m, name, draft, chunk, start=None, end=None, do_preview=True):
    info = call(m, "ds.info(%r, %r)" % (name, draft))
    out_dir = info["out_dir"]
    os.makedirs(out_dir, exist_ok=True)
    n = info["frames_written"]
    s0 = 0 if start is None else start
    s1 = n if end is None else min(end, n)
    t_start = time.time()
    print("[%s] %s: %d frames -> %s" % (time.strftime("%H:%M:%S"), name, s1 - s0, out_dir), flush=True)
    call(m, "ds.prepare(%r)" % name)
    try:
        k = s0
        while k < s1:
            k1 = min(k + chunk, s1)
            r = call(m, "ds.shoot(%r, %r, %d, %d)" % (name, draft, k, k1))
            el = time.time() - t_start
            print("  frames %d..%d done (%s) %.0fs" % (k, k1 - 1, r.get("last"), el), flush=True)
            k = k1
    finally:
        call(m, "ds.finish(%r)" % name)
    flatten(out_dir)
    if start is None and end is None:
        meta = call(m, "ds.info(%r, %r)" % (name, draft))
        shot = {"fps": meta["fps"], "frames": meta["frames_written"], "real_seconds_covered": meta["real_seconds_covered"],
                "description": meta["description"], "source": SRC_NAME + " shoot(%r%s)" % (name, ", draft=True" if draft else "")}
        shot.update(meta["extra"])
        with open(os.path.join(out_dir, "shot.json"), "w") as fh:
            json.dump(shot, fh, indent=1)
        if do_preview:
            preview(out_dir, name, meta["fps"])
    print("[%s] %s done in %.0fs" % (time.strftime("%H:%M:%S"), name, time.time() - t_start), flush=True)
    return out_dir


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shot")
    ap.add_argument("--draft", action="store_true")
    ap.add_argument("--chunk", type=int, default=60)
    ap.add_argument("--start", type=int)
    ap.add_argument("--end", type=int)
    ap.add_argument("--call")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--quit", action="store_true")
    ap.add_argument("--no-preview", action="store_true")
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
    if a.call:
        print(json.dumps(call(m, a.call), indent=1, default=str))
    if a.list:
        print(json.dumps(call(m, "ds.shot_names()"), indent=1))
    if a.shot:
        names = call(m, "ds.shot_names(%r)" % a.shot)
        for name in names:
            run_shot(m, name, a.draft, a.chunk if not a.draft else max(a.chunk, 200), a.start, a.end, not a.no_preview)


if __name__ == "__main__":
    main()
