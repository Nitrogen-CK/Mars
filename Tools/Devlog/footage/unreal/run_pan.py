"""Host-side runner for devlog_pan_shots.py (plain Python 3.10 + Pillow + imageio_ffmpeg; no unreal).

    python run_pan.py --shot <name>|all [--draft] [--start N --end M] [--chunk 20] [--quit]
    python run_pan.py --import-pieces            # SlabPiece_A..D_Mars_SM into /Game/Mars/Devlog/Pieces (saved)
    python run_pan.py --look slab|cube           # one draft still: does that piece read its cook state in the pan?
    python run_pan.py --ledger <name>            # the replayed kernel / station numbers of a shot
    python run_pan.py --call "ps.SHOTS"          # any editor-side call (ps = devlog_pan_shots, st = the stage module)
    python run_pan.py --quit                     # quit the hidden editor

Launches a hidden MarsEditor on 9317 (or reuses the one there; never 9316). Per shot: prepare (stage state, pieces, pan
MID) -> shoot in chunks (one Monolith call each) -> finish (restore). Full frames render at 3840x2160 into the scratch
raw folder; each chunk is downsampled (Lanczos) to 1920x1080 8-bit RGB into D:/Repo/Content/Devlog/pan_showcase/<shot>/
and the raw frames are deleted. Then shot.json and _preview.mp4. Drafts: 960x540, every 10th frame, scratch drafts/.
Stills (title_still, end_still) are written as <shot>.png beside the shot folders.
"""
import argparse
import concurrent.futures as cf
import glob
import json
import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "Tools", "Blender", "mars_cooking", "unreal"))
import mars_cook_parity as cp  # noqa: E402  (Monolith client, wait_for, launch, quit_editor)

PORT = 9317
LOG = os.path.join(REPO, "Saved", "Logs", "HiddenEnv_Mars.log")
SRC_NAME = "Tools/Devlog/footage/unreal/devlog_pan_shots.py"
OUT = r"D:\Repo\Content\Devlog\pan_showcase"
ORDER = ["oil_land", "sear_flip", "five_pieces", "char_fond", "ready_lineup", "title_still", "end_still"]


def module_code(call):
    return ("import sys, importlib\n"
            "sys.path.insert(0, r'%s')\n"
            "import devlog_unreal_shots as ds\n"
            "importlib.reload(ds)\n"
            "import mars_devlog_stage_ue as st\n"
            "importlib.reload(st)\n"
            "import devlog_pan_shots as ps\n"
            "importlib.reload(ps)\n"
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


def ffmpeg():
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def _down(args):
    src, dst, ss = args
    from PIL import Image
    im = Image.open(src).convert("RGB")
    if ss > 1:
        im = im.resize((im.width // ss, im.height // ss), Image.LANCZOS)
    im.save(dst, compress_level=4)
    os.remove(src)
    return dst


def _flatten(path):
    from PIL import Image
    im = Image.open(path)
    if im.mode != "RGB":
        im.convert("RGB").save(path, compress_level=4)


def downsample(raw_dir, out_dir, ss):
    files = sorted(glob.glob(os.path.join(raw_dir, "[0-9][0-9][0-9][0-9][0-9].png")))
    with cf.ThreadPoolExecutor(6) as ex:
        list(ex.map(_down, [(f, os.path.join(out_dir, os.path.basename(f)), ss) for f in files]))
    return len(files)


def preview(out_dir, fps):
    out = os.path.join(out_dir, "_preview.mp4")
    subprocess.run([ffmpeg(), "-y", "-loglevel", "error", "-framerate", str(fps), "-i", os.path.join(out_dir, "%05d.png"),
                    "-c:v", "libx264", "-crf", "23", "-pix_fmt", "yuv420p", "-threads", "4", out], check=True)
    return out


def run_shot(m, name, draft, chunk, start=None, end=None):
    info = call(m, "ps.info(%r, %r)" % (name, draft))
    out_dir, raw_dir = info["out_dir"], info["raw_dir"]
    still = info["frames_written"] == 1 and info["real_seconds_covered"] <= 1.0 / 30.0 + 1e-6
    n = info["frames_written"]
    s0 = 0 if start is None else start
    s1 = n if end is None else min(end, n)
    os.makedirs(out_dir, exist_ok=True)
    if not draft and start is None and end is None and not still:
        for f in glob.glob(os.path.join(out_dir, "[0-9][0-9][0-9][0-9][0-9].png")):
            os.remove(f)
    t_start = time.time()
    print("[%s] %s: %d frames -> %s (pieces: %s)" % (time.strftime("%H:%M:%S"), name, s1 - s0, out_dir,
                                                      info["extra"]["pieces"]), flush=True)
    call(m, "ps.prepare(%r)" % name)
    try:
        k = s0
        while k < s1:
            k1 = min(k + chunk, s1)
            r = call(m, "ps.shoot(%r, %r, %d, %d)" % (name, draft, k, k1))
            if not draft:
                downsample(raw_dir, out_dir, info["extra"]["supersample"])
            else:                              # the render target exports RGBA (scene-depth alpha): flatten to RGB
                files = sorted(glob.glob(os.path.join(out_dir, "[0-9][0-9][0-9][0-9][0-9].png")))[k:k1]
                with cf.ThreadPoolExecutor(6) as ex:
                    list(ex.map(_flatten, files))
            print("  frames %d..%d done %.0fs" % (k, k1 - 1, time.time() - t_start), flush=True)
            k = k1
    finally:
        call(m, "ps.finish(%r)" % name)
    if still:
        src = os.path.join(out_dir, "00000.png")
        dst = os.path.join(os.path.dirname(out_dir), name + ("_draft" if draft else "") + ".png")
        shutil.move(src, dst)
        shutil.rmtree(out_dir, ignore_errors=True)
        print("[%s] %s -> %s" % (time.strftime("%H:%M:%S"), name, dst), flush=True)
        return dst
    if start is None and end is None:
        shot = {"fps": info["fps"], "frames": n, "real_seconds_covered": info["real_seconds_covered"],
                "description": info["description"],
                "source": SRC_NAME + " shoot(%r%s) via run_pan.py" % (name, ", draft=True" if draft else "")}
        shot.update(info["extra"])
        with open(os.path.join(out_dir, "shot.json"), "w") as fh:
            json.dump(shot, fh, indent=1)
        preview(out_dir, info["fps"])
    print("[%s] %s done in %.0fs" % (time.strftime("%H:%M:%S"), name, time.time() - t_start), flush=True)
    return out_dir


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shot")
    ap.add_argument("--draft", action="store_true")
    ap.add_argument("--chunk", type=int, default=20)
    ap.add_argument("--start", type=int)
    ap.add_argument("--end", type=int)
    ap.add_argument("--import-pieces", action="store_true")
    ap.add_argument("--look")
    ap.add_argument("--ledger")
    ap.add_argument("--call")
    ap.add_argument("--quit", action="store_true")
    a = ap.parse_args()
    if a.quit and not (a.shot or a.call or a.look or a.import_pieces or a.ledger):
        try:
            m = cp.Monolith(PORT)
        except Exception:
            print("no editor on %d" % PORT)
            return
        cp.quit_editor(m, None)
        print("QUIT sent to %d" % PORT)
        return
    m = connect()
    if a.import_pieces:
        print(json.dumps(call(m, "ps.import_pieces()"), indent=1))
    if a.look:
        print(call(m, "ps.look_test(%r)" % a.look))
    if a.ledger:
        print(json.dumps(call(m, "ps.ledger(%r)" % a.ledger), indent=None))
    if a.call:
        print(json.dumps(call(m, a.call), indent=1, default=str))
    if a.shot:
        names = ORDER if a.shot == "all" else a.shot.split(",")
        for name in names:
            run_shot(m, name, a.draft, a.chunk if not a.draft else 100, a.start, a.end)
    if a.quit:
        cp.quit_editor(m, None)
        print("QUIT sent to %d" % PORT)


if __name__ == "__main__":
    main()
