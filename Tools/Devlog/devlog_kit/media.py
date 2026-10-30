"""Resolve ``src`` strings from a manifest into concrete media (frame sequence, video file or still image)."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from . import DevlogError
from .ffmpeg import probe

VIDEO_EXTS = {".mp4", ".mov", ".mkv", ".webm", ".avi", ".m4v", ".gif"}
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff"}
AUDIO_EXTS = {".wav", ".mp3", ".m4a", ".aac", ".flac", ".ogg", ".opus"}

_PRINTF = re.compile(r"%(0?)(\d*)d")


@dataclass
class Media:
    """A resolved source.

    kind:      ``sequence`` | ``video`` | ``image``
    path:      the file, or for sequences the printf pattern (absolute)
    start:     first frame number (sequences)
    frames:    frame count (sequences; video when known)
    fps:       native frame rate (sequences: the spec's ``fps``, else ``shot.json``, else 30; video: probed)
    duration:  seconds of source material (None for stills = unlimited)
    size:      (width, height) when known
    stamp:     cache fingerprint (count, sizes, mtimes)
    shot:      the sequence's ``shot.json`` if present
    has_alpha: the source carries real transparency (an alpha channel with at least one pixel below 255
               in the first frame, or a video pixel format with alpha)
    """
    kind: str
    path: Path
    start: int = 0
    frames: Optional[int] = None
    fps: float = 30.0
    duration: Optional[float] = None
    size: Optional[tuple[int, int]] = None
    stamp: str = ""
    shot: dict = field(default_factory=dict)
    has_alpha: bool = False


def resolve_path(src: str, media_root: Path) -> Path:
    """Absolute ``src`` stays; a relative one resolves against ``media_root``."""
    p = Path(src)
    return p if p.is_absolute() else (media_root / p)


def _pattern_regex(name: str) -> re.Pattern[str]:
    out, i = "", 0
    for m in _PRINTF.finditer(name):
        out += re.escape(name[i:m.start()])
        width = m.group(2)
        out += rf"(\d{{{width}}})" if (m.group(1) and width) else r"(\d+)"
        i = m.end()
    out += re.escape(name[i:])
    return re.compile("^" + out + "$", re.IGNORECASE)


def _image_size(p: Path) -> Optional[tuple[int, int]]:
    try:
        from PIL import Image
        with Image.open(p) as im:
            return im.size
    except Exception:  # noqa: BLE001 - an unreadable image is reported by ffmpeg later
        return None


def _image_alpha(p: Path) -> bool:
    """True when the image has an alpha channel that is not fully opaque."""
    try:
        from PIL import Image
        with Image.open(p) as im:
            if im.mode == "P" and "transparency" in im.info:
                im = im.convert("RGBA")
            if im.mode not in ("RGBA", "LA", "PA"):
                return False
            return im.getchannel("A").getextrema()[0] < 255
    except Exception:  # noqa: BLE001
        return False


_ALPHA_PIX = ("yuva", "rgba", "bgra", "argb", "abgr", "gbrap", "ya8", "ya16", "rgba64", "bgra64")


def resolve_media(src: str, media_root: Path, *, fps: Optional[float] = None, where: str = "") -> Media:
    """Resolve ``src`` (relative to ``media_root``) into :class:`Media`.

    ``src`` may be a printf frame pattern (``shot/%05d.png``), a folder of ``%05d.png`` frames, a video
    file or a still image. Raises :class:`DevlogError` (prefixed with ``where``) when the path is missing,
    a sequence is empty or has a gap (ffmpeg's image2 demuxer stops at the first missing number).
    """
    if not isinstance(src, str) or not src:
        raise DevlogError(f"{where}missing 'src'")
    p = resolve_path(src, media_root)
    if "%" not in p.name and p.is_dir():
        p = p / "%05d.png"
    if "%" in p.name:
        folder = p.parent
        if not folder.is_dir():
            raise DevlogError(f"{where}frame folder not found: {folder}  (src '{src}')")
        rx = _pattern_regex(p.name)
        nums: list[tuple[int, Path]] = []
        for f in folder.iterdir():
            m = rx.match(f.name)
            if m:
                nums.append((int(m.group(1)), f))
        if not nums:
            raise DevlogError(f"{where}no frames matching {p.name} in {folder}  (src '{src}')")
        nums.sort()
        start = nums[0][0]
        for k, (n, _) in enumerate(nums):
            if n != start + k:
                missing = p.name % (start + k) if p.name.count("%") == 1 else f"frame {start + k}"
                raise DevlogError(f"{where}frame sequence has a gap: {folder / missing} is missing "
                                  f"(found {len(nums)} frames starting at {start}); ffmpeg would stop there")
        shot: dict = {}
        sj = folder / "shot.json"
        if sj.is_file():
            try:
                shot = json.loads(sj.read_text(encoding="utf-8"))
            except json.JSONDecodeError as exc:
                raise DevlogError(f"{where}unreadable {sj}: {exc}") from exc
        rate = float(fps or shot.get("fps") or 30.0)
        stats = [f.stat() for _, f in nums]
        stamp = f"seq:{len(nums)}:{start}:{max(s.st_mtime_ns for s in stats)}:{sum(s.st_size for s in stats)}"
        return Media("sequence", p, start=start, frames=len(nums), fps=rate, duration=len(nums) / rate,
                     size=_image_size(nums[0][1]), stamp=stamp, shot=shot, has_alpha=_image_alpha(nums[0][1]))
    if not p.is_file():
        raise DevlogError(f"{where}media file not found: {p}  (src '{src}')")
    st = p.stat()
    stamp = f"file:{st.st_size}:{st.st_mtime_ns}"
    ext = p.suffix.lower()
    if ext in IMAGE_EXTS:
        return Media("image", p, frames=1, fps=float(fps or 30.0), duration=None, size=_image_size(p), stamp=stamp,
                     has_alpha=_image_alpha(p))
    if ext in VIDEO_EXTS:
        info = probe(p)
        size = (info.width, info.height) if info.width and info.height else None
        rate = float(fps or info.fps or 30.0)
        return Media("video", p, fps=rate, duration=info.duration, size=size, stamp=stamp,
                     frames=int(round(info.duration * rate)) if info.duration else None,
                     has_alpha=bool(info.pix_fmt and info.pix_fmt.startswith(_ALPHA_PIX)))
    raise DevlogError(f"{where}unsupported media type '{ext}' for {p} (frames %05d.png, "
                      f"video {sorted(VIDEO_EXTS)} or image {sorted(IMAGE_EXTS)})")


def resolve_audio(src: str, media_root: Path, *, where: str = "") -> tuple[Path, str]:
    """Resolve a music file; returns (path, cache stamp)."""
    p = resolve_path(src, media_root)
    if not p.is_file():
        raise DevlogError(f"{where}music file not found: {p}  (src '{src}')")
    st = p.stat()
    return p, f"audio:{st.st_size}:{st.st_mtime_ns}"
