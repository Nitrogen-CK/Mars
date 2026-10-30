"""ffmpeg binary resolution, a process runner with live progress, and ffprobe-free media probing.

imageio-ffmpeg ships ``ffmpeg`` but not ``ffprobe``, so :func:`probe` parses ``ffmpeg -i`` output.
Every command is built as an argument list (never a shell string), so Windows paths with spaces are safe.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import threading
import time
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Optional, Sequence

from . import DevlogError

#: Thread budget for every ffmpeg call (the machine is shared with Blender/Unreal jobs).
THREADS = int(os.environ.get("DEVLOG_FFMPEG_THREADS", "4"))

_FFMPEG: Optional[str] = None


def ffmpeg_exe() -> str:
    """Return the ffmpeg binary: ``$DEVLOG_FFMPEG`` if set, else imageio-ffmpeg's bundled binary."""
    global _FFMPEG
    if _FFMPEG:
        return _FFMPEG
    env = os.environ.get("DEVLOG_FFMPEG")
    if env and Path(env).is_file():
        _FFMPEG = env
        return env
    try:
        import imageio_ffmpeg  # type: ignore
    except ImportError as exc:  # pragma: no cover - environment problem
        raise DevlogError("imageio-ffmpeg is not installed (pip install imageio-ffmpeg), "
                          "or set DEVLOG_FFMPEG to an ffmpeg binary") from exc
    _FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
    return _FFMPEG


def fpath(p: Path | str) -> str:
    """Path as ffmpeg likes it on every OS: absolute, forward slashes."""
    return str(Path(p).resolve()).replace("\\", "/")


def thread_args() -> list[str]:
    """Global options limiting ffmpeg's filter threads."""
    return ["-filter_threads", str(THREADS), "-filter_complex_threads", str(THREADS)]


def _fmt_secs(s: float) -> str:
    m, s = divmod(max(0.0, s), 60)
    return f"{int(m)}:{s:04.1f}"


def run(args: Sequence[str], *, label: str, total_seconds: Optional[float] = None,
        quiet: bool = False, log_path: Optional[Path] = None) -> None:
    """Run ffmpeg with ``args`` (without the binary), printing a one-line progress meter.

    Raises :class:`DevlogError` naming ``label`` with the tail of ffmpeg's log on failure.
    """
    cmd = [ffmpeg_exe(), "-hide_banner", "-nostdin", "-y", "-loglevel", "error",
           "-progress", "pipe:1", "-nostats", *args]
    if log_path:
        log_path.write_text(subprocess.list2cmdline(cmd) + "\n", encoding="utf-8")
    t0 = time.time()
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, encoding="utf-8", errors="replace")
    err_lines: list[str] = []

    def _drain() -> None:
        assert proc.stderr is not None
        for line in proc.stderr:
            err_lines.append(line.rstrip())

    th = threading.Thread(target=_drain, daemon=True)
    th.start()
    last_print = 0.0
    tty = sys.stdout.isatty()
    assert proc.stdout is not None
    for line in proc.stdout:
        if quiet or not tty or not line.startswith("out_time_us="):
            continue
        try:
            done = int(line.split("=", 1)[1]) / 1e6
        except ValueError:
            continue
        now = time.time()
        if now - last_print < 0.5:
            continue
        last_print = now
        if total_seconds:
            pct = min(100.0, 100.0 * done / total_seconds)
            sys.stdout.write(f"\r  {label}: {pct:5.1f}%  ({_fmt_secs(done)} / {_fmt_secs(total_seconds)})  "
                             f"{now - t0:5.1f}s elapsed ")
        else:
            sys.stdout.write(f"\r  {label}: {_fmt_secs(done)}  {now - t0:5.1f}s elapsed ")
        sys.stdout.flush()
    proc.wait()
    th.join(timeout=5)
    if not quiet:
        sys.stdout.write(f"\r  {label}: done in {time.time() - t0:.1f}s" + " " * 30 + "\n")
        sys.stdout.flush()
    if log_path and err_lines:
        with log_path.open("a", encoding="utf-8") as fh:
            fh.write("\n".join(err_lines) + "\n")
    if proc.returncode != 0:
        tail = "\n    ".join(err_lines[-25:]) or "(no output)"
        where = f"\n  full command and log: {log_path}" if log_path else ""
        raise DevlogError(f"ffmpeg failed while rendering {label} (exit {proc.returncode}):\n    {tail}{where}")


@dataclass
class ProbeInfo:
    """What :func:`probe` learned about a media file."""
    path: str
    duration: Optional[float]
    width: Optional[int]
    height: Optional[int]
    fps: Optional[float]
    pix_fmt: Optional[str]
    video_codec: Optional[str]
    has_audio: bool
    audio_codec: Optional[str]
    frames: Optional[int] = None

    def to_dict(self) -> dict:
        return asdict(self)


_DUR_RE = re.compile(r"Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)")
_VID_RE = re.compile(r"Video: (\w+)[^,]*,\s*(\w+)")
_SIZE_RE = re.compile(r"\b(\d{2,5})x(\d{2,5})\b")
_FPS_RE = re.compile(r"([\d.]+)\s+fps")
_TBR_RE = re.compile(r"([\d.]+)\s+tbr")
_AUD_RE = re.compile(r"Stream #\S+.*?: Audio: (\w+)")


def probe(path: Path | str, count_frames: bool = False) -> ProbeInfo:
    """Probe ``path`` by parsing ``ffmpeg -i``. ``count_frames`` also stream-copies to count video packets."""
    p = Path(path)
    if not p.exists():
        raise DevlogError(f"cannot probe missing file: {p}")
    res = subprocess.run([ffmpeg_exe(), "-hide_banner", "-nostdin", "-i", fpath(p)],
                         capture_output=True, text=True, encoding="utf-8", errors="replace")
    txt = res.stderr
    dur = None
    m = _DUR_RE.search(txt)
    if m:
        dur = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
    width = height = None
    fps = None
    pix = codec = None
    for line in txt.splitlines():
        if ": Video:" in line and codec is None:
            vm = _VID_RE.search(line)
            if vm:
                codec, pix = vm.group(1), vm.group(2)
            sm = _SIZE_RE.search(line.split("Video:", 1)[1])
            if sm:
                width, height = int(sm.group(1)), int(sm.group(2))
            fm = _FPS_RE.search(line) or _TBR_RE.search(line)
            if fm:
                fps = float(fm.group(1))
    am = _AUD_RE.search(txt)
    info = ProbeInfo(fpath(p), dur, width, height, fps, pix, codec, am is not None, am.group(1) if am else None)
    if count_frames:
        res = subprocess.run([ffmpeg_exe(), "-hide_banner", "-nostdin", "-i", fpath(p), "-map", "0:v:0",
                              "-c", "copy", "-f", "null", "-"],
                             capture_output=True, text=True, encoding="utf-8", errors="replace")
        frames = re.findall(r"frame=\s*(\d+)", res.stderr)
        info.frames = int(frames[-1]) if frames else None
    return info


def extract_frame(video: Path, t: float, out_png: Path) -> None:
    """Write the frame at output time ``t`` of ``video`` to ``out_png``."""
    out_png.parent.mkdir(parents=True, exist_ok=True)
    cmd = [ffmpeg_exe(), "-hide_banner", "-nostdin", "-y", "-loglevel", "error", "-ss", f"{t:.3f}",
           "-i", fpath(video), "-frames:v", "1", "-update", "1", fpath(out_png)]
    res = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if res.returncode != 0 or not out_png.exists():
        raise DevlogError(f"could not extract frame at {t:.2f}s from {video}: {res.stderr.strip()[-400:]}")
