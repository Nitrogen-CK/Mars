"""Episode manifest (schema v1): loading, defaults, validation and timeline arithmetic.

:func:`load_episode` never raises for content problems; it collects :class:`Issue` objects (errors and
warnings, each naming the segment id) so ``validate`` can report everything at once. ``render`` refuses to
run while any error remains. Unreadable JSON raises :class:`DevlogError`.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

from . import DevlogError, SCHEMA_VERSION
from .media import Media, resolve_audio, resolve_media
from .theme import Theme, resolve_theme_dict

SEGMENT_TYPES = ("title", "chapter", "clip", "compare", "overlay", "end")
COMPARE_MODES = ("split", "wipe", "sidebyside")
CAPTION_STYLES = ("big", "small")
POSITIONS = ("top", "center", "bottom")
INSET_POSITIONS = ("right", "left", "center", "top-right", "top-left", "bottom-right", "bottom-left")
FITS = ("contain", "cover", "stretch")
ANCHORS = {"center": (0.5, 0.5), "top": (0.5, 0.0), "bottom": (0.5, 1.0), "left": (0.0, 0.5), "right": (1.0, 0.5),
           "top-left": (0.0, 0.0), "top-right": (1.0, 0.0), "bottom-left": (0.0, 1.0), "bottom-right": (1.0, 1.0)}
XFADE_TYPES = ("fade", "wipeleft", "wiperight", "wipeup", "wipedown", "slideleft", "slideright", "slideup",
               "slidedown", "circlecrop", "rectcrop", "distance", "fadeblack", "fadewhite", "radial", "smoothleft",
               "smoothright", "smoothup", "smoothdown", "circleopen", "circleclose", "vertopen", "vertclose",
               "horzopen", "horzclose", "dissolve", "pixelize", "diagtl", "diagtr", "diagbl", "diagbr", "hlslice",
               "hrslice", "vuslice", "vdslice", "hblur", "fadegrays", "wipetl", "wipetr", "wipebl", "wipebr",
               "squeezeh", "squeezev", "zoomin", "fadefast", "fadeslow", "hlwind", "hrwind", "vuwind", "vdwind",
               "coverleft", "coverright", "coverup", "coverdown", "revealleft", "revealright", "revealup",
               "revealdown")

DEFAULT_DURATIONS = {"title": 3.0, "chapter": 2.0, "end": 3.0, "compare": 5.0}
STILL_DEFAULT_DURATION = 4.0

_IGNORED = {"notes", "comment", "description"}
_COMMON = {"id", "type", "duration", "captions", "lower_third", "zoom", "transition"}
_SOURCE = {"src", "fps", "in", "out", "speed", "fit"}
KNOWN_KEYS = {
    "title": _COMMON | {"title", "subtitle", "background"},
    "chapter": _COMMON | {"number", "title", "subtitle", "background"},
    "end": _COMMON | {"lines", "background"},
    "clip": _COMMON | _SOURCE,
    "compare": _COMMON | {"mode", "left", "right", "labels", "sweep"},
    "overlay": _COMMON | {"base", "inset"},
}
_BG_KEYS = _SOURCE | {"blur", "darken"}
_INSET_KEYS = _SOURCE | {"position", "width", "margin", "label", "frame"}
_CAPTION_KEYS = {"at", "duration", "text", "style", "position"}
_LT_KEYS = {"title", "subtitle", "at", "duration"}
_ZOOM_KEYS = {"from", "to", "anchor", "ease"}
_OUTPUT_KEYS = {"width", "height", "fps", "crf", "preset", "progress_bar"}
_TOP_KEYS = {"version", "title", "output", "theme", "media_root", "transitions", "audio", "segments"}

#: Contract timing targets (warnings only).
MIN_CAPTION_SECONDS = 2.0
MAX_WORDS_PER_LINE = 7


@dataclass
class Issue:
    level: str          # "error" | "warning"
    where: str          # "segment 'wall4m'", "episode", ...
    message: str

    def __str__(self) -> str:
        return f"{self.level.upper():7s} [{self.where}] {self.message}"


@dataclass
class Output:
    width: int = 1920
    height: int = 1080
    fps: int = 30
    crf: int = 18
    preset: str = "slow"
    progress_bar: bool = False
    preview: bool = False


@dataclass
class SegPlan:
    """A segment after defaults and timing: ``frames`` long, entered via ``trans_in`` = (type, frames)."""
    index: int
    id: str
    type: str
    spec: dict
    frames: int = 0
    trans_in: tuple[str, int] = ("none", 0)
    start_frame: int = 0
    media: dict[str, Media] = field(default_factory=dict)
    ok: bool = True

    def duration(self, fps: int) -> float:
        return self.frames / fps

    def start(self, fps: int) -> float:
        return self.start_frame / fps

    def end(self, fps: int) -> float:
        return (self.start_frame + self.frames) / fps


@dataclass
class Episode:
    path: Path
    raw: dict
    title: str
    output: Output
    theme: Theme
    media_root: Path
    audio: dict
    music: Optional[Path]
    music_stamp: str
    segments: list[SegPlan]
    issues: list[Issue]
    total_frames: int = 0

    @property
    def errors(self) -> list[Issue]:
        return [i for i in self.issues if i.level == "error"]

    @property
    def warnings(self) -> list[Issue]:
        return [i for i in self.issues if i.level == "warning"]

    @property
    def total_seconds(self) -> float:
        return self.total_frames / self.output.fps

    def segment(self, seg_id: str) -> SegPlan:
        for s in self.segments:
            if s.id == seg_id:
                return s
        raise DevlogError(f"no segment with id '{seg_id}' (have {[s.id for s in self.segments]})")


def _num(v: Any) -> bool:
    return isinstance(v, (int, float)) and not isinstance(v, bool)


class _Checker:
    def __init__(self, check_media: bool = True) -> None:
        self.issues: list[Issue] = []
        self.check_media = check_media

    def err(self, where: str, msg: str) -> None:
        self.issues.append(Issue("error", where, msg))

    def warn(self, where: str, msg: str) -> None:
        self.issues.append(Issue("warning", where, msg))

    def keys(self, where: str, obj: dict, known: set[str], what: str) -> None:
        for k in obj:
            if k not in known and k not in _IGNORED and not k.startswith("_"):
                self.warn(where, f"unknown {what} key '{k}' (ignored; known: {', '.join(sorted(known))})")


def parse_transition(v: Any, chk: _Checker, where: str, default: tuple[str, float]) -> tuple[str, float]:
    """Accept ``"fade"``, ``{"type": "fade", "duration": 0.4}``, ``"none"`` or ``null``."""
    if v is None:
        return default
    if isinstance(v, str):
        v = {"type": v}
    if not isinstance(v, dict):
        chk.err(where, f"transition must be a string or object, got {v!r}")
        return default
    chk.keys(where, v, {"type", "duration"}, "transition")
    ttype = v.get("type", default[0])
    dur = v.get("duration", default[1] if default[1] > 0 else 0.4)
    if ttype in (None, "none", "cut"):
        return ("none", 0.0)
    if ttype not in XFADE_TYPES:
        chk.err(where, f"unknown transition type '{ttype}' (fade, wipeleft, smoothleft, fadeblack, none, "
                       f"or any ffmpeg xfade name)")
        return default
    if not _num(dur) or dur < 0:
        chk.err(where, f"transition duration must be a number >= 0, got {dur!r}")
        return default
    return (ttype, float(dur)) if dur > 0 else ("none", 0.0)


def _resolve(chk: _Checker, where: str, spec: Any, media_root: Path, what: str) -> Optional[Media]:
    if not isinstance(spec, dict):
        chk.err(where, f"'{what}' must be an object with a 'src', got {spec!r}")
        return None
    if "src" not in spec:
        chk.err(where, f"'{what}' has no 'src'")
        return None
    if not isinstance(spec["src"], str) or not spec["src"]:
        chk.err(where, f"'{what}.src' must be a non-empty string")
        return None
    if not chk.check_media:
        return None
    fps = spec.get("fps")
    if fps is not None and (not _num(fps) or fps <= 0):
        chk.err(where, f"'{what}.fps' must be > 0, got {fps!r}")
        fps = None
    try:
        return resolve_media(spec["src"], media_root, fps=fps, where=f"{what}: ")
    except DevlogError as exc:
        chk.err(where, str(exc))
        return None


def source_window(spec: dict) -> tuple[float, Optional[float], float]:
    """(in, out, speed) of a source spec with defaults."""
    return float(spec.get("in", 0.0) or 0.0), (float(spec["out"]) if spec.get("out") is not None else None), \
        float(spec.get("speed", 1.0) or 1.0)


def source_coverage(media: Media, spec: dict) -> Optional[float]:
    """Output seconds the source can fill at its speed (None = unlimited, i.e. a still)."""
    if media.kind == "image" or media.duration is None:
        return None
    t_in, t_out, speed = source_window(spec)
    end = media.duration if t_out is None else min(t_out, media.duration)
    return max(0.0, (end - t_in) / speed)


def _check_source_window(chk: _Checker, where: str, spec: dict, media: Optional[Media], what: str) -> None:
    for k in ("in", "out", "speed"):
        if k in spec and spec[k] is not None and not _num(spec[k]):
            chk.err(where, f"'{what}.{k}' must be a number, got {spec[k]!r}")
            return
    t_in, t_out, speed = source_window(spec)
    if speed <= 0:
        chk.err(where, f"'{what}.speed' must be > 0, got {speed}")
    if t_in < 0:
        chk.err(where, f"'{what}.in' must be >= 0, got {t_in}")
    if t_out is not None and t_out <= t_in:
        chk.err(where, f"'{what}.out' ({t_out}) must be greater than 'in' ({t_in})")
    if spec.get("fit", "contain") not in FITS:
        chk.err(where, f"'{what}.fit' must be one of {FITS}, got {spec.get('fit')!r}")
    if media is None or media.kind == "image" or media.duration is None:
        return
    if t_in >= media.duration:
        chk.err(where, f"'{what}.in' {t_in:.2f}s is past the end of the source ({media.duration:.2f}s): {media.path}")
    elif t_out is not None and t_out > media.duration + 1e-3:
        chk.warn(where, f"'{what}.out' {t_out:.2f}s is past the end of the source ({media.duration:.2f}s); "
                        f"the last frame is held")


def _check_zoom(chk: _Checker, where: str, z: Any) -> None:
    if z is None:
        return
    if not isinstance(z, dict):
        chk.err(where, f"'zoom' must be an object {{from, to, anchor}}, got {z!r}")
        return
    chk.keys(where, z, _ZOOM_KEYS, "zoom")
    for k in ("from", "to"):
        if k in z and (not _num(z[k]) or z[k] < 1.0 or z[k] > 4.0):
            chk.err(where, f"'zoom.{k}' must be a number in [1.0, 4.0] (1.0 = full frame), got {z[k]!r}")
    a = z.get("anchor", "center")
    if isinstance(a, str):
        if a not in ANCHORS:
            chk.err(where, f"'zoom.anchor' must be one of {sorted(ANCHORS)} or [x, y] in 0..1, got '{a}'")
    elif not (isinstance(a, list) and len(a) == 2 and all(_num(c) and 0 <= c <= 1 for c in a)):
        chk.err(where, f"'zoom.anchor' must be a name or [x, y] in 0..1, got {a!r}")
    if z.get("ease", "linear") not in ("linear", "inout", "out", "in"):
        chk.err(where, f"'zoom.ease' must be linear | inout | in | out, got {z.get('ease')!r}")


def _check_timed(chk: _Checker, where: str, obj: dict, what: str, seg_dur: float, default_at: float = 0.0,
                 default_dur: Optional[float] = None) -> bool:
    at = obj.get("at", default_at)
    dur = obj.get("duration", default_dur)
    if not _num(at) or at < 0:
        chk.err(where, f"{what}: 'at' must be a number >= 0, got {at!r}")
        return False
    if dur is None or not _num(dur) or dur <= 0:
        chk.err(where, f"{what}: 'duration' must be a number > 0, got {dur!r}")
        return False
    if at >= seg_dur:
        chk.err(where, f"{what}: starts at {at:.2f}s but the segment is only {seg_dur:.2f}s long")
        return False
    if at + dur > seg_dur + 1e-3:
        chk.warn(where, f"{what}: runs to {at + dur:.2f}s, past the segment end {seg_dur:.2f}s; it is cut at the end")
    return True


def _segment_duration(chk: _Checker, where: str, s: dict, plan: SegPlan) -> Optional[float]:
    t = s.get("type")
    dur = s.get("duration")
    if dur is not None and (not _num(dur) or dur <= 0):
        chk.err(where, f"'duration' must be a number > 0, got {dur!r}")
        return None
    if t in DEFAULT_DURATIONS:
        return float(dur if dur is not None else DEFAULT_DURATIONS[t])
    key = "src" if t == "clip" else "base"
    media = plan.media.get(key)
    spec = s if t == "clip" else (s.get("base") or {})
    if media is None:
        if dur is not None:
            return float(dur)
        t_in, t_out, speed = source_window(spec)
        if t_out is not None and t_out > t_in and speed > 0:
            return (t_out - t_in) / speed
        if not chk.check_media:
            chk.warn(where, "no 'duration' or 'out' and media not checked; timing assumes 1.0s")
            return 1.0
        return None
    cover = source_coverage(media, spec)
    if dur is None:
        if cover is None:
            chk.warn(where, f"still image with no 'duration'; using {STILL_DEFAULT_DURATION}s")
            return STILL_DEFAULT_DURATION
        return cover
    if cover is not None and dur > cover + 1.0 / 30:
        chk.warn(where, f"'duration' {dur:.2f}s is longer than the source covers ({cover:.2f}s at speed "
                        f"{source_window(spec)[2]:g}); the last frame is held for {dur - cover:.2f}s")
    return float(dur)


def load_episode(path: Path | str, *, preview: bool = False, check_text: bool = True,
                 check_media: bool = True) -> Episode:
    """Load, default and validate an episode manifest. See the module docstring.

    ``check_media=False`` validates schema, text fit and timing only: no media path is resolved (footage may not
    exist yet), so source lengths are not checked and the episode cannot be rendered.
    """
    path = Path(path).resolve()
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise DevlogError(f"episode manifest not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise DevlogError(f"episode manifest {path} is not valid JSON: {exc}") from exc
    if not isinstance(raw, dict):
        raise DevlogError(f"episode manifest {path} must be a JSON object")
    chk = _Checker(check_media)
    E = "episode"
    chk.keys(E, raw, _TOP_KEYS, "top-level")
    if raw.get("version") != SCHEMA_VERSION:
        chk.err(E, f"'version' must be {SCHEMA_VERSION}, got {raw.get('version')!r}")

    # output ---------------------------------------------------------------------------------------------
    o = raw.get("output") or {}
    if not isinstance(o, dict):
        chk.err(E, "'output' must be an object")
        o = {}
    chk.keys(E, o, _OUTPUT_KEYS, "output")
    out = Output(width=int(o.get("width", 1920)), height=int(o.get("height", 1080)), fps=int(o.get("fps", 30)),
                 crf=int(o.get("crf", 18)), preset=str(o.get("preset", "slow")),
                 progress_bar=bool(o.get("progress_bar", False)))
    if out.width % 2 or out.height % 2 or out.width < 64 or out.height < 64:
        chk.err(E, f"output size must be even and >= 64 px (yuv420p), got {out.width}x{out.height}")
    if out.fps <= 0:
        chk.err(E, f"output fps must be > 0, got {out.fps}")
    if preview:
        k = 540.0 / min(out.width, out.height)
        out.width, out.height = int(round(out.width * k / 2)) * 2, int(round(out.height * k / 2)) * 2
        out.crf, out.preset, out.preview = 28, "veryfast", True

    # theme ----------------------------------------------------------------------------------------------
    try:
        tdata, tdesc = resolve_theme_dict(raw.get("theme", "default"), path.parent)
    except DevlogError as exc:
        chk.err(E, str(exc))
        tdata, tdesc = resolve_theme_dict("default", path.parent)
    theme = Theme(tdata, out.width, out.height, tdesc)

    # media root -----------------------------------------------------------------------------------------
    mr = raw.get("media_root")
    media_root = path.parent if not mr else (Path(mr) if Path(mr).is_absolute() else path.parent / mr)
    if not media_root.is_dir():
        (chk.err if check_media else chk.warn)(E, f"media_root does not exist: {media_root}")

    # transitions ----------------------------------------------------------------------------------------
    tr = raw.get("transitions") or {}
    if not isinstance(tr, dict):
        chk.err(E, "'transitions' must be an object like {\"default\": {\"type\": \"fade\", \"duration\": 0.4}}")
        tr = {}
    chk.keys(E, tr, {"default"}, "transitions")
    default_tr = parse_transition(tr.get("default"), chk, "transitions.default", ("fade", 0.4))

    # audio ----------------------------------------------------------------------------------------------
    audio = dict(raw.get("audio") or {})
    chk.keys(E, audio, {"music", "gain_db", "fade"}, "audio")
    audio.setdefault("gain_db", -16.0)
    audio.setdefault("fade", 1.0)
    music, music_stamp = None, ""
    if audio.get("music") and check_media:
        try:
            music, music_stamp = resolve_audio(str(audio["music"]), media_root, where="audio.music: ")
        except DevlogError as exc:
            chk.err(E, str(exc))
    for k in ("gain_db", "fade"):
        if not _num(audio[k]):
            chk.err(E, f"'audio.{k}' must be a number, got {audio[k]!r}")
            audio[k] = -16.0 if k == "gain_db" else 1.0

    # segments -------------------------------------------------------------------------------------------
    segs_raw = raw.get("segments")
    plans: list[SegPlan] = []
    if not isinstance(segs_raw, list) or not segs_raw:
        chk.err(E, "'segments' must be a non-empty list")
        segs_raw = []
    seen: set[str] = set()
    for i, s in enumerate(segs_raw):
        if not isinstance(s, dict):
            chk.err(f"segment #{i}", "each segment must be an object")
            continue
        sid = s.get("id")
        if not isinstance(sid, str) or not sid:
            sid = f"{i:02d}_{s.get('type', 'segment')}"
            chk.warn(f"segment #{i}", f"no 'id'; using '{sid}'")
        if sid in seen:
            chk.err(f"segment '{sid}'", "duplicate segment id")
        seen.add(sid)
        where = f"segment '{sid}'"
        t = s.get("type")
        plan = SegPlan(i, sid, str(t), s)
        plans.append(plan)
        if t not in SEGMENT_TYPES:
            chk.err(where, f"unknown type '{t}' (one of {', '.join(SEGMENT_TYPES)})")
            plan.ok = False
            continue
        chk.keys(where, s, KNOWN_KEYS[t], f"'{t}' segment")
        n_err = len([x for x in chk.issues if x.level == "error"])

        if t in ("title", "chapter") and not isinstance(s.get("title"), str):
            chk.err(where, f"'{t}' needs a 'title' string")
        if t == "end":
            lines = s.get("lines")
            if not (isinstance(lines, list) and lines and all(isinstance(x, str) for x in lines)):
                chk.err(where, "'end' needs 'lines': a non-empty list of strings")
        if t in ("title", "chapter", "end") and s.get("background") is not None:
            bg = s["background"]
            if isinstance(bg, str):
                bg = {"src": bg}
                s["background"] = bg
            if isinstance(bg, dict):
                chk.keys(where, bg, _BG_KEYS, "background")
                for k in ("blur", "darken"):
                    if k in bg and (not _num(bg[k]) or bg[k] < 0 or (k == "darken" and bg[k] > 1)):
                        chk.err(where, f"'background.{k}' must be a number (darken in 0..1), got {bg[k]!r}")
            m = _resolve(chk, where, bg, media_root, "background")
            if m:
                plan.media["background"] = m
                _check_source_window(chk, where, bg, m, "background")
        if t == "clip":
            m = _resolve(chk, where, s, media_root, "src") if "src" in s else None
            if "src" not in s:
                chk.err(where, "'clip' needs a 'src'")
            if m:
                plan.media["src"] = m
            _check_source_window(chk, where, s, m, "clip")
        if t == "compare":
            mode = s.get("mode", "split")
            if mode not in COMPARE_MODES:
                chk.err(where, f"'mode' must be one of {COMPARE_MODES}, got {mode!r}")
            for side in ("left", "right"):
                sp = s.get(side)
                if isinstance(sp, str):
                    sp = {"src": sp}
                    s[side] = sp
                if isinstance(sp, dict):
                    chk.keys(where, sp, _SOURCE, side)
                m = _resolve(chk, where, sp, media_root, side)
                if m:
                    plan.media[side] = m
                    _check_source_window(chk, where, sp, m, side)
            labels = s.get("labels")
            if labels is not None and not (isinstance(labels, list) and len(labels) == 2
                                           and all(isinstance(x, (str, type(None))) for x in labels)):
                chk.err(where, "'labels' must be a list of two strings (left, right)")
            sw = s.get("sweep")
            if sw is not None and not (isinstance(sw, list) and len(sw) == 2 and all(_num(x) for x in sw)
                                       and 0 <= sw[0] < sw[1] <= 1):
                chk.err(where, "'sweep' must be [start, end] fractions of the duration, 0 <= start < end <= 1")
        if t == "overlay":
            for part in ("base", "inset"):
                sp = s.get(part)
                if isinstance(sp, str):
                    sp = {"src": sp}
                    s[part] = sp
                if isinstance(sp, dict):
                    chk.keys(where, sp, _SOURCE if part == "base" else _INSET_KEYS, part)
                m = _resolve(chk, where, sp, media_root, part)
                if m:
                    plan.media[part] = m
                    _check_source_window(chk, where, sp, m, part)
            ins = s.get("inset") if isinstance(s.get("inset"), dict) else {}
            if ins.get("position", "right") not in INSET_POSITIONS:
                chk.err(where, f"'inset.position' must be one of {INSET_POSITIONS}, got {ins.get('position')!r}")
            w = ins.get("width", 0.42)
            if not _num(w) or not 0.05 <= w <= 1.0:
                chk.err(where, f"'inset.width' must be a fraction of the frame width in 0.05..1, got {w!r}")
            mg = ins.get("margin", 0.04)
            if not _num(mg) or not 0 <= mg < 0.5:
                chk.err(where, f"'inset.margin' must be a fraction of the frame width in 0..0.5, got {mg!r}")
            if ins.get("label") is not None and not isinstance(ins.get("label"), str):
                chk.err(where, "'inset.label' must be a string")
            if ins.get("frame") is not None and not isinstance(ins.get("frame"), bool):
                chk.err(where, "'inset.frame' must be true or false")
        _check_zoom(chk, where, s.get("zoom"))

        dur = _segment_duration(chk, where, s, plan)
        if dur is None:
            plan.ok = False
            continue
        plan.frames = max(1, int(round(dur * out.fps)))
        if i > 0:
            ttype, tdur = parse_transition(s.get("transition"), chk, where, default_tr)
            plan.trans_in = (ttype, int(round(tdur * out.fps)))
        elif s.get("transition") is not None:
            chk.warn(where, "'transition' on the first segment is ignored (it is the transition *into* a segment)")
        seg_dur = plan.frames / out.fps

        # timed layers
        caps = s.get("captions") or []
        if not isinstance(caps, list):
            chk.err(where, "'captions' must be a list")
            caps = []
        for ci, c in enumerate(caps):
            cw = (f"caption {ci} ('{' '.join(str(c.get('text', '')).split())[:32]}')" if isinstance(c, dict)
                  else f"caption {ci}")
            if not isinstance(c, dict) or not isinstance(c.get("text"), str) or not c["text"].strip():
                chk.err(where, f"{cw}: needs a non-empty 'text'")
                continue
            chk.keys(where, c, _CAPTION_KEYS, "caption")
            if c.get("style", "big") not in CAPTION_STYLES:
                chk.err(where, f"{cw}: 'style' must be big | small, got {c.get('style')!r}")
                continue
            if c.get("position") is not None and c["position"] not in POSITIONS:
                chk.err(where, f"{cw}: 'position' must be top | center | bottom, got {c['position']!r}")
            if not _check_timed(chk, where, c, cw, seg_dur):
                continue
            if c["duration"] < MIN_CAPTION_SECONDS - 1e-6:
                chk.warn(where, f"{cw}: on screen {c['duration']:.2f}s (< {MIN_CAPTION_SECONDS}s target)")
            if check_text:
                from .text import FitError, caption_image
                try:
                    _, info = caption_image(theme, c["text"], c.get("style", "big"))
                    if max(info["words_per_line"]) > MAX_WORDS_PER_LINE:
                        chk.warn(where, f"{cw}: {max(info['words_per_line'])} words on one line "
                                        f"(> {MAX_WORDS_PER_LINE} target)")
                except FitError as exc:
                    chk.err(where, f"{cw}: {exc}")
        lt = s.get("lower_third")
        if lt is not None:
            if not isinstance(lt, dict) or not isinstance(lt.get("title"), str):
                chk.err(where, "'lower_third' needs a 'title' string")
            else:
                chk.keys(where, lt, _LT_KEYS, "lower_third")
                _check_timed(chk, where, lt, "lower_third", seg_dur, 0.5, lt.get("duration", 4.0))
                if check_text:
                    from .text import FitError, lower_third_image
                    try:
                        lower_third_image(theme, lt["title"], lt.get("subtitle"))
                    except FitError as exc:
                        chk.err(where, f"lower_third: {exc}")
        if check_text and t in ("title", "chapter", "end") and \
                len([x for x in chk.issues if x.level == "error"]) == n_err:
            from .text import FitError, chapter_card, end_card, title_card
            try:
                if t == "title":
                    title_card(theme, s["title"], s.get("subtitle"), out.fps)
                elif t == "chapter":
                    chapter_card(theme, s.get("number"), s["title"], s.get("subtitle"), out.fps)
                else:
                    end_card(theme, s["lines"])
            except FitError as exc:
                chk.err(where, f"card text: {exc}")
        if len([x for x in chk.issues if x.level == "error"]) > n_err:
            plan.ok = False

    # timeline -------------------------------------------------------------------------------------------
    pos = 0
    for k, p in enumerate(plans):
        if p.frames <= 0:
            continue
        ttype, tf = p.trans_in
        if k > 0:
            prev = plans[k - 1]
            if tf > 0 and (tf >= prev.frames or tf >= p.frames):
                chk.err(f"segment '{p.id}'", f"transition '{ttype}' ({tf / out.fps:.2f}s) must be shorter than both "
                                             f"'{prev.id}' ({prev.frames / out.fps:.2f}s) and this segment "
                                             f"({p.frames / out.fps:.2f}s)")
            if k > 1 and tf + prev.trans_in[1] > prev.frames:
                chk.err(f"segment '{prev.id}'", f"its incoming ({prev.trans_in[1] / out.fps:.2f}s) and outgoing "
                                                f"({tf / out.fps:.2f}s) transitions overlap; lengthen it or shorten them")
            pos -= tf
        p.start_frame = max(0, pos)
        pos += p.frames
        # captions hidden under transitions
        seg_dur = p.frames / out.fps
        t_in = tf / out.fps
        t_out = plans[k + 1].trans_in[1] / out.fps if k + 1 < len(plans) else 0.0
        for c in (p.spec.get("captions") or []):
            if isinstance(c, dict) and _num(c.get("at")) and _num(c.get("duration")):
                # warn only when the caption sits more than halfway into a crossfade (half-faded text)
                if c["at"] < t_in / 2 - 1e-6 or c["at"] + c["duration"] > seg_dur - t_out / 2 + 1e-6:
                    snippet = " ".join(str(c.get("text")).split())[:32]
                    chk.warn(f"segment '{p.id}'", f"caption '{snippet}' runs more than halfway into a transition "
                                                  f"(in {t_in:.2f}s / out {t_out:.2f}s); it will be half-faded")
    total = pos
    for w in theme.font_warnings:
        chk.warn("theme", w)
    return Episode(path=path, raw=raw, title=str(raw.get("title", path.stem)), output=out, theme=theme,
                   media_root=media_root, audio=audio, music=music, music_stamp=music_stamp, segments=plans,
                   issues=chk.issues, total_frames=max(0, total))
