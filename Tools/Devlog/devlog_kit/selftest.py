"""Self-test: generate synthetic footage, render an episode that uses every feature, verify the MP4.

    python -m devlog_kit.selftest [--root DIR] [--out FILE.mp4] [--preview] [--write-episode PATH] [--regen]

Footage (in ``--root``, default ``<tempdir>/devlog_kit_selftest``):
    build_a/      360 frames 1920x1080: drifting gradient, grid, moving disc, frame counter (a "build" shot)
    wall_raw/     150 frames: flat grey brick wall + the same moving light as wall_painted (compare left)
    wall_painted/ 150 frames: painted brick wall (compare right)
    diagram/      150 frames 960x540: a "drip clock" graph drawing itself (inset; exercises upscaling)
    diagram_rgba/ the same graph on its own RGBA panel (alpha 240, transparent corners): alpha-inset path
    wall_painted_preview.mp4   a video-file source;   wall_raw_still.png / title_bg.png   still sources
    music.wav     30 s synthetic chord (exercises the music path)
The episode exercises title, chapter, clip (speed, in/out, zoom, lower third, big + small captions with accent
markup and a forced line break), compare wipe/split/sidebyside, overlay (framed PiP + label, and an RGBA
inset composited with its own alpha), source-level in/out inside compare/overlay sources, end, xfade fade/wipeleft/smoothleft/fadeblack,
a hard cut, the progress bar and music. After rendering it probes the MP4 and extracts evenly spaced frames
to ``<root>/check/`` for a visual check.
"""

from __future__ import annotations

import argparse
import json
import math
import shutil
import sys
import tempfile
import wave
from pathlib import Path
from typing import Optional

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from . import DevlogError
from .ffmpeg import extract_frame, ffmpeg_exe, fpath, probe, run
from .manifest import load_episode
from .render import render

FOOTAGE_VERSION = 5


def _font(size: int) -> ImageFont.ImageFont:
    for p in ("C:/Windows/Fonts/consola.ttf", "/System/Library/Fonts/Menlo.ttc",
              "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"):
        if Path(p).is_file():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default(size)


def _shot_json(folder: Path, frames: int, desc: str) -> None:
    (folder / "shot.json").write_text(json.dumps({
        "fps": 30, "frames": frames, "real_seconds_covered": frames / 30, "description": desc,
        "source": "devlog_kit.selftest"}, indent=2), encoding="utf-8")


def _disc(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill: tuple) -> None:
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill)


def gen_build(folder: Path, n: int = 360, w: int = 1920, h: int = 1080) -> None:
    """Gradient + grid + moving disc + counter."""
    folder.mkdir(parents=True, exist_ok=True)
    xs = np.linspace(0, 1, w, dtype=np.float32)[None, :]
    ys = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    font = _font(34)
    for i in range(n):
        t = i / n
        a = np.array([60 + 40 * math.sin(6.28 * t), 70, 120 + 40 * math.cos(6.28 * t)], np.float32)
        b = np.array([200, 120 + 50 * math.sin(6.28 * t + 1), 60], np.float32)
        k = np.clip(xs * 0.6 + ys * 0.4, 0, 1)[..., None]
        img = (a * (1 - k) + b * k)
        img[::120, :, :] *= 0.75
        img[:, ::120, :] *= 0.75
        im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
        d = ImageDraw.Draw(im)
        cx = w * (0.5 + 0.35 * math.sin(6.28 * t * 2))
        cy = h * (0.5 + 0.30 * math.sin(6.28 * t * 3 + 0.7))
        _disc(d, cx, cy, 70, (250, 245, 230))
        _disc(d, cx, cy, 40, (30, 140, 220))
        # a growing "build": bars filling up over the shot
        for j in range(12):
            fill = min(1.0, max(0.0, t * 14 - j))
            x0 = 300 + j * 110
            d.rectangle((x0, 900 - 300 * fill, x0 + 80, 900), fill=(235, 225, 205))
        d.text((24, 20), f"SEQ build_a  f{i:04d}", font=font, fill=(255, 255, 255))
        im.save(folder / f"{i:05d}.png", compress_level=1)
    _shot_json(folder, n, "synthetic build: gradient, grid, moving disc, bars filling")


def _wall(w: int, h: int, painted: bool) -> np.ndarray:
    rng = np.random.default_rng(7)
    img = np.zeros((h, w, 3), np.float32)
    img[:] = (52, 50, 48) if painted else (70, 70, 72)
    bw, bh, mortar = 160, 72, 6
    for row in range(h // bh + 1):
        off = (bw // 2) * (row % 2)
        for col in range(-1, w // bw + 2):
            x0, y0 = col * bw + off + mortar // 2, row * bh + mortar // 2
            x1, y1 = x0 + bw - mortar, y0 + bh - mortar
            xa, xb, ya, yb = max(0, x0), min(w, x1), max(0, y0), min(h, y1)
            if xa >= xb or ya >= yb:
                continue
            if painted:
                base = np.array([150, 70, 48], np.float32) * rng.uniform(0.75, 1.15)
                grad = np.linspace(1.15, 0.8, yb - ya, dtype=np.float32)[:, None, None]
                noise = rng.normal(1.0, 0.06, (yb - ya, xb - xa, 1)).astype(np.float32)
                img[ya:yb, xa:xb] = np.clip(base * grad * noise, 0, 255)
            else:
                img[ya:yb, xa:xb] = 128 * rng.uniform(0.9, 1.1)
    return img


def gen_wall(folder: Path, painted: bool, n: int = 150, w: int = 1920, h: int = 1080) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    base = _wall(w, h, painted)
    font = _font(34)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    for i in range(n):
        t = i / n
        lx, ly = w * (0.15 + 0.7 * t), h * 0.45
        light = np.exp(-(((xx - lx) ** 2 + (yy - ly) ** 2) / (2 * 260.0 ** 2)))[..., None]
        img = np.clip(base * (0.55 + 0.75 * light), 0, 255).astype(np.uint8)
        im = Image.fromarray(img, "RGB")
        d = ImageDraw.Draw(im)
        d.text((24, 20), f"SEQ wall_{'painted' if painted else 'raw'}  f{i:04d}", font=font, fill=(255, 255, 255))
        im.save(folder / f"{i:05d}.png", compress_level=1)
    _shot_json(folder, n, f"synthetic brick wall ({'painted' if painted else 'blocked out'}) with a moving light")


def gen_diagram(folder: Path, n: int = 150, w: int = 960, h: int = 540, rgba: bool = False) -> None:
    """A graph that draws itself: the 'diagram is footage' case (own axis labels, no captions).
    ``rgba``: a transparent frame holding its own panel (alpha 240, transparent rounded corners)."""
    folder.mkdir(parents=True, exist_ok=True)
    font = _font(22)
    panel = None
    if rgba:
        ss = 4
        big = Image.new("L", (w * ss, h * ss), 0)
        ImageDraw.Draw(big).rounded_rectangle((0, 0, w * ss - 1, h * ss - 1), radius=28 * ss, fill=240)
        panel = big.resize((w, h), Image.LANCZOS)
    for i in range(n):
        t = (i + 1) / n
        im = Image.new("RGB", (w, h), (24, 34, 30) if rgba else (18, 22, 30))
        d = ImageDraw.Draw(im)
        x0, y0, x1, y1 = 70, 40, w - 30, h - 60
        for gx in range(x0, x1, 80):
            d.line((gx, y0, gx, y1), fill=(34, 40, 52))
        for gy in range(y0, y1, 60):
            d.line((x0, gy, x1, gy), fill=(34, 40, 52))
        d.line((x0, y1, x1, y1), fill=(160, 160, 170), width=2)
        d.line((x0, y0, x0, y1), fill=(160, 160, 170), width=2)
        d.text((x1 - 60, y1 + 14), "time", font=font, fill=(170, 170, 180))
        d.text((x0 - 60, y0 - 4), "level", font=font, fill=(170, 170, 180))
        pts = []
        steps = int(400 * t)
        for k in range(steps):
            u = k / 400
            v = (u * 5) % 1.0  # sawtooth: fill then drip
            pts.append((x0 + u * (x1 - x0), y1 - (y1 - y0) * 0.85 * v))
        if len(pts) > 1:
            d.line(pts, fill=(74, 163, 224), width=4)
            _disc(d, pts[-1][0], pts[-1][1], 9, (224, 168, 74))
        if panel is not None:
            im = im.convert("RGBA")
            im.putalpha(panel)
        im.save(folder / f"{i:05d}.png", compress_level=1)
    _shot_json(folder, n, "synthetic diagram: sawtooth 'drip clock' drawing itself"
               + (" on an RGBA panel (alpha 240, transparent rounded corners)" if rgba else ""))


def gen_music(path: Path, seconds: float = 30.0, rate: int = 48000) -> None:
    t = np.arange(int(seconds * rate), dtype=np.float32) / rate
    sig = np.zeros_like(t)
    for f, a in ((220.0, 0.5), (261.63, 0.35), (329.63, 0.35), (110.0, 0.4)):
        sig += a * np.sin(2 * np.pi * f * t)
    sig *= 0.18 * (0.75 + 0.25 * np.sin(2 * np.pi * 0.25 * t))
    st = np.stack([sig, sig * 0.97], axis=1)
    pcm = (np.clip(st, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(rate)
        wf.writeframes(pcm.tobytes())


def generate(root: Path, regen: bool = False) -> None:
    """Create all synthetic media under ``root`` (skipped when already present at this footage version)."""
    stamp = root / "footage_version.txt"
    if not regen and stamp.is_file() and stamp.read_text().strip() == str(FOOTAGE_VERSION):
        print(f"synthetic footage present in {root}")
        return
    print(f"generating synthetic footage in {root} ...")
    if root.exists():
        for sub in ("build_a", "wall_raw", "wall_painted", "diagram", "diagram_rgba"):
            shutil.rmtree(root / sub, ignore_errors=True)
    root.mkdir(parents=True, exist_ok=True)
    gen_build(root / "build_a")
    gen_wall(root / "wall_raw", painted=False)
    gen_wall(root / "wall_painted", painted=True)
    gen_diagram(root / "diagram")
    gen_diagram(root / "diagram_rgba", rgba=True)
    Image.open(root / "build_a" / "00200.png").save(root / "title_bg.png")
    Image.open(root / "wall_raw" / "00075.png").save(root / "wall_raw_still.png")
    run(["-framerate", "30", "-i", fpath(root / "wall_painted" / "%05d.png"), "-c:v", "libx264", "-crf", "23",
         "-pix_fmt", "yuv420p", "-threads", "4", fpath(root / "wall_painted_preview.mp4")],
        label="wall_painted_preview.mp4", total_seconds=5.0)
    gen_music(root / "music.wav")
    stamp.write_text(str(FOOTAGE_VERSION))


def episode_dict(root: Path) -> dict:
    """The self-test episode (every segment type and feature)."""
    return {
        "version": 1,
        "title": "devlog_kit self-test",
        "output": {"width": 1920, "height": 1080, "fps": 30, "crf": 18, "preset": "slow", "progress_bar": True},
        "theme": "default",
        "media_root": str(root).replace("\\", "/"),
        "transitions": {"default": {"type": "fade", "duration": 0.4}},
        "audio": {"music": "music.wav", "gain_db": -16, "fade": 1.0},
        "segments": [
            {"id": "intro", "type": "title", "title": "Devlog Kit", "subtitle": "Self-test: every segment type",
             "duration": 3.0, "background": {"src": "title_bg.png", "blur": 8, "darken": 0.5}},
            {"id": "chapter1", "type": "chapter", "number": 1, "title": "Clips and captions",
             "subtitle": "frames, speed, zoom, lower third", "duration": 2.2},
            {"id": "build", "type": "clip", "src": "build_a/%05d.png", "fps": 30, "in": 0.0, "out": 12.0, "speed": 2.0,
             "lower_third": {"title": "BuildA_Sequence", "subtitle": "360 frames, played at 2x", "at": 0.4,
                             "duration": 3.6},
             "captions": [{"at": 0.6, "duration": 2.6, "text": "Every piece is *built by a script*", "style": "big"},
                          {"at": 3.4, "duration": 2.0, "text": "blocks, then bevels", "style": "small",
                           "position": "bottom"}],
             "zoom": {"from": 1.0, "to": 1.08, "anchor": "center"}},
            {"id": "wipe", "type": "compare", "mode": "wipe", "duration": 4.5,
             "left": {"src": "wall_raw/%05d.png"}, "right": {"src": "wall_painted/%05d.png"},
             "labels": ["Blocked", "Painted"], "transition": {"type": "wipeleft", "duration": 0.5},
             "captions": [{"at": 0.6, "duration": 2.6, "text": "The divider sweeps left to right", "style": "small"}]},
            {"id": "split", "type": "compare", "mode": "split", "duration": 3.0,
             "left": {"src": "wall_painted_preview.mp4"}, "right": {"src": "wall_raw_still.png"},
             "labels": ["Video file", "Still image"], "transition": {"type": "smoothleft", "duration": 0.5},
             "captions": [{"at": 0.5, "duration": 2.0, "text": "Split: *video* and *still*", "style": "big",
                           "position": "bottom"}]},
            {"id": "sidebyside", "type": "compare", "mode": "sidebyside", "duration": 3.0,
             "left": {"src": "wall_raw/%05d.png", "in": 1.0, "out": 4.0},
             "right": {"src": "wall_painted/%05d.png", "in": 1.0, "out": 4.0},
             "labels": ["Blocked", "Painted"], "transition": "none"},
            {"id": "pip", "type": "overlay", "duration": 4.5,
             "base": {"src": "build_a/%05d.png", "in": 4.0},
             "inset": {"src": "diagram/%05d.png", "position": "right", "width": 0.42, "margin": 0.04,
                       "label": "drip clock"},
             "captions": [{"at": 0.5, "duration": 3.4, "text": "Every drop *keeps time*", "style": "big",
                           "position": "top"}]},
            {"id": "pip_alpha", "type": "overlay", "duration": 3.4,
             "base": {"src": "wall_painted/%05d.png", "in": 1.0, "out": 4.4},
             "inset": {"src": "diagram_rgba/%05d.png", "in": 1.0, "out": 4.4, "position": "top-left", "width": 0.36,
                       "margin": 0.05},
             "captions": [{"at": 0.4, "duration": 2.6, "text": "An RGBA inset keeps\nits own panel", "style": "big",
                           "position": "bottom"}]},
            {"id": "end", "type": "end", "lines": ["Devlog Kit", "self-test render", "made with devlog_kit"],
             "duration": 2.6, "transition": {"type": "fadeblack", "duration": 0.6}},
        ],
    }


def main(argv: Optional[list[str]] = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m devlog_kit.selftest", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", type=Path, default=Path(tempfile.gettempdir()) / "devlog_kit_selftest",
                    help="where synthetic footage, the episode and check frames go")
    ap.add_argument("--out", type=Path, default=None, help="output mp4 (default <root>/devlog_kit_selftest.mp4)")
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--write-episode", type=Path, default=None, help="also write the episode JSON here")
    ap.add_argument("--regen", action="store_true", help="regenerate the synthetic footage")
    ap.add_argument("--frames", type=int, default=6, help="evenly spaced check frames to extract")
    a = ap.parse_args(argv)
    root: Path = a.root.resolve()
    out: Path = (a.out or root / "devlog_kit_selftest.mp4").resolve()
    try:
        ffmpeg_exe()
        generate(root, a.regen)
        ep_json = root / "episode.json"
        data = episode_dict(root)
        ep_json.write_text(json.dumps(data, indent=2), encoding="utf-8")
        if a.write_episode:
            a.write_episode.parent.mkdir(parents=True, exist_ok=True)
            a.write_episode.write_text(json.dumps(data, indent=2), encoding="utf-8")
            print(f"episode written to {a.write_episode}")
        ep = load_episode(ep_json, preview=a.preview)
        if ep.errors:
            for i in ep.issues:
                print(f"  {i}")
            raise DevlogError("self-test episode failed validation")
        render(ep_json, out, preview=a.preview)
        info = probe(out, count_frames=True)
        exp_w, exp_h = ep.output.width, ep.output.height
        problems = []
        if (info.width, info.height) != (exp_w, exp_h):
            problems.append(f"size {info.width}x{info.height} != {exp_w}x{exp_h}")
        if not info.fps or abs(info.fps - ep.output.fps) > 0.01:
            problems.append(f"fps {info.fps} != {ep.output.fps}")
        if info.pix_fmt != "yuv420p":
            problems.append(f"pix_fmt {info.pix_fmt} != yuv420p")
        if info.frames != ep.total_frames:
            problems.append(f"frames {info.frames} != {ep.total_frames}")
        if not info.duration or abs(info.duration - ep.total_seconds) > 0.1:
            problems.append(f"duration {info.duration} != {ep.total_seconds:.2f}")
        if not info.has_audio:
            problems.append("no audio track although music is set")
        print(json.dumps(info.to_dict(), indent=2))
        check = root / "check"
        shutil.rmtree(check, ignore_errors=True)
        for k in range(a.frames):
            t = ep.total_seconds * (k + 0.5) / a.frames
            p = check / f"frame_{k:02d}_{t:05.2f}s.png"
            extract_frame(out, t, p)
            print(f"  check frame: {p}")
        if problems:
            raise DevlogError("self-test output check failed: " + "; ".join(problems))
        print(f"SELFTEST OK: {out}")
    except DevlogError as exc:
        print(f"\nSELFTEST FAILED: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
