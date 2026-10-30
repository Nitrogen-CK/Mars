"""Per-segment ffmpeg filter-graph builders.

Each segment becomes one ffmpeg call producing an intermediate MP4 of exactly ``plan.frames`` frames at the
output size and rate. Pixels stay in RGB (``gbrp``) from source decode to the final encode, so text and theme
colours are converted to YUV exactly once (BT.709) in the final pass. Text is Pillow-rendered PNG composited
with ``overlay`` + ``enable='between(t,a,b)'``; fades are ``fade=...:alpha=1`` on the overlay input.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from PIL import Image

from .ffmpeg import fpath
from .manifest import ANCHORS, Episode, SegPlan, source_window
from .media import Media
from .text import (Placed, chapter_card, end_card, inset_parts, label_image, place_caption, place_lower_third,
                   title_card)


# ------------------------------------------------------------------------------------------------------------
# graph helper
# ------------------------------------------------------------------------------------------------------------
@dataclass
class Graph:
    """Accumulates ffmpeg inputs and filter chains; written to a script file for ``-/filter_complex``."""
    inputs: list[list[str]] = field(default_factory=list)
    lines: list[str] = field(default_factory=list)
    n: int = 0

    def add_input(self, args: list[str]) -> int:
        self.inputs.append(args)
        return len(self.inputs) - 1

    def new(self, prefix: str = "v") -> str:
        self.n += 1
        return f"[{prefix}{self.n}]"

    def add(self, ins: str | list[str], chain: str, out: Optional[str] = None) -> str:
        out = out or self.new()
        src = "".join(ins) if isinstance(ins, list) else ins
        self.lines.append(f"{src}{chain}{out}")
        return out

    def input_args(self) -> list[str]:
        return [a for inp in self.inputs for a in inp]

    def script(self) -> str:
        return ";\n".join(self.lines) + "\n"


@dataclass
class Ctx:
    """Everything a builder needs: the episode, the segment plan and a work folder for layer PNGs."""
    ep: Episode
    plan: SegPlan
    work: Path

    @property
    def W(self) -> int:
        return self.ep.output.width

    @property
    def H(self) -> int:
        return self.ep.output.height

    @property
    def fps(self) -> int:
        return self.ep.output.fps

    @property
    def dur(self) -> float:
        return self.plan.frames / self.ep.output.fps

    @property
    def theme(self):  # noqa: ANN201 - Theme
        return self.ep.theme


def _f(v: float) -> str:
    return f"{v:.5f}".rstrip("0").rstrip(".") if isinstance(v, float) else str(v)


# ------------------------------------------------------------------------------------------------------------
# sources
# ------------------------------------------------------------------------------------------------------------
def scale_filters(w: int, h: int, fit: str, bg: str) -> list[str]:
    """Scale to exactly ``w`` x ``h``: contain (letterbox in the theme background), cover (crop) or stretch."""
    if fit == "cover":
        return [f"scale={w}:{h}:force_original_aspect_ratio=increase:flags=lanczos", f"crop={w}:{h}"]
    if fit == "stretch":
        return [f"scale={w}:{h}:flags=lanczos"]
    return [f"scale={w}:{h}:force_original_aspect_ratio=decrease:flags=lanczos",
            f"pad={w}:{h}:(ow-iw)/2:(oh-ih)/2:color={bg}"]


def zoom_filter(z: dict, frames: int, ease_default: str = "linear") -> Optional[str]:
    """Sub-pixel slow push with ``perspective`` (cubic, per-frame): the crop window shrinks from 1/from to 1/to of
    the frame towards ``anchor``. Unlike ``zoompan`` it does not step on integer pixels."""
    z0 = float(z.get("from", 1.0))
    z1 = float(z.get("to", z0))
    if abs(z0 - 1.0) < 1e-6 and abs(z1 - 1.0) < 1e-6:
        return None
    a = z.get("anchor", "center")
    ax, ay = ANCHORS[a] if isinstance(a, str) else (float(a[0]), float(a[1]))
    n1 = max(1, frames - 1)
    p = f"clip(on/{n1},0,1)"
    ease = z.get("ease", ease_default)
    e = {"inout": f"({p})*({p})*(3-2*({p}))", "out": f"(1-pow(1-{p},2))", "in": f"pow({p},2)"}.get(ease, p)
    zz = f"({_f(z0)}+({_f(z1 - z0)})*{e})"
    w, h = f"(W/{zz})", f"(H/{zz})"
    x0, y0 = f"((W-{w})*{_f(ax)})", f"((H-{h})*{_f(ay)})"
    return (f"perspective=x0='{x0}':y0='{y0}':x1='{x0}+{w}':y1='{y0}':x2='{x0}':y2='{y0}+{h}':"
            f"x3='{x0}+{w}':y3='{y0}+{h}':interpolation=cubic:sense=source:eval=frame")


def source_chain(g: Graph, ctx: Ctx, media: Media, spec: dict, frames: int, *, box: Optional[tuple[int, int]] = None,
                 zoom: Optional[dict] = None, fit: Optional[str] = None, skip_frames: int = 0,
                 alpha: bool = False) -> str:
    """Add ``media`` as an input and return a label carrying exactly ``frames`` gbrp frames at ``box`` size.

    Applies ``in``/``out`` (source seconds), ``speed`` (setpts + fps drops frames for timelapse), scaling,
    last-frame hold when the source runs short, and ``zoom``. ``alpha`` keeps the source's transparency
    (``gbrap``, transparent letterbox) for compositing.
    """
    W, H = box or (ctx.W, ctx.H)
    fps = ctx.fps
    t_in, t_out, speed = source_window(spec)
    secs = frames / fps + 1.0
    trim_dur = (t_out - t_in) if t_out is not None else None
    if media.kind == "sequence":
        start = media.start + int(round(t_in * media.fps))
        idx = g.add_input(["-framerate", _f(media.fps), "-start_number", str(start), "-i", fpath(media.path)])
    elif media.kind == "video":
        pre = ["-ss", f"{t_in:.4f}"] if t_in > 0 else []
        idx = g.add_input(pre + ["-i", fpath(media.path)])
    else:
        idx = g.add_input(["-loop", "1", "-framerate", str(fps), "-t", f"{secs:.3f}", "-i", fpath(media.path)])
    f: list[str] = []
    if media.kind != "image":
        if trim_dur is not None:
            f.append(f"trim=duration={trim_dur:.5f}")
        f.append("setpts=PTS-STARTPTS")
        if abs(speed - 1.0) > 1e-9:
            f.append(f"setpts=PTS/{speed:.6g}")
    f.append(f"fps={fps}")
    f += scale_filters(W, H, fit or spec.get("fit", "contain"), "black@0" if alpha else ctx.theme.hex("background"))
    f += ["setsar=1", "format=gbrap" if alpha else "format=gbrp", f"tpad=stop_mode=clone:stop_duration={secs:.3f}",
          f"trim=end_frame={frames}", "setpts=PTS-STARTPTS"]
    if zoom:
        zf = zoom_filter(zoom, frames, ctx.theme.get("zoom.ease", "linear"))
        if zf:
            f.append(zf)
    if skip_frames:  # drop the head after zooming so the zoom stays in step with a sibling source (wipe)
        f += [f"trim=start_frame={skip_frames}", "setpts=PTS-STARTPTS"]
    f.append(f"fps={fps}")  # setpts leaves the link's frame rate unknown; xfade needs it declared
    return g.add(f"[{idx}:v]", ",".join(f))


def color_chain(g: Graph, ctx: Ctx, color: str, size: Optional[tuple[int, int]] = None,
                frames: Optional[int] = None, rgba: bool = False) -> str:
    """A solid colour source (``color`` in ffmpeg syntax, may carry ``@alpha``)."""
    w, h = size or (ctx.W, ctx.H)
    n = frames or ctx.plan.frames
    idx = g.add_input(["-f", "lavfi", "-i", f"color=c={color}:s={w}x{h}:r={ctx.fps}:d={n / ctx.fps + 0.5:.3f}"])
    return g.add(f"[{idx}:v]", f"format={'rgba' if rgba else 'gbrp'},trim=end_frame={n},setpts=PTS-STARTPTS,"
                               f"fps={ctx.fps}")


# ------------------------------------------------------------------------------------------------------------
# overlays
# ------------------------------------------------------------------------------------------------------------
def _save(ctx: Ctx, name: str, im: Image.Image) -> Path:
    ctx.work.mkdir(parents=True, exist_ok=True)
    k = len(list(ctx.work.glob("*.png"))) + len([d for d in ctx.work.iterdir() if d.is_dir()])
    p = ctx.work / f"{k:02d}_{name}.png"
    im.save(p, compress_level=1)
    return p


def _save_frames(ctx: Ctx, name: str, frames: list[Image.Image]) -> Path:
    ctx.work.mkdir(parents=True, exist_ok=True)
    k = len(list(ctx.work.glob("*.png"))) + len([d for d in ctx.work.iterdir() if d.is_dir()])
    d = ctx.work / f"{k:02d}_{name}"
    d.mkdir(exist_ok=True)
    for i, im in enumerate(frames):
        im.save(d / f"{i:05d}.png", compress_level=1)
    return d / "%05d.png"


def overlay_placed(g: Graph, ctx: Ctx, base: str, pl: Placed) -> str:
    """Composite a :class:`Placed` image (still or animated frames) onto ``base`` with fades/rise/slide."""
    seg = ctx.dur
    start = max(0.0, pl.start)
    end = min(seg, pl.end if pl.end is not None else seg)
    dur = end - start
    if dur <= 1e-3:
        return base
    fps = ctx.fps
    if pl.frames:
        pattern = _save_frames(ctx, pl.name, pl.frames)
        idx = g.add_input(["-framerate", str(fps), "-start_number", "0", "-i", fpath(pattern)])
        chain = [f"format=rgba", f"tpad=stop_mode=clone:stop_duration={dur + 0.5:.3f}", f"trim=duration={dur:.5f}"]
    else:
        assert pl.image is not None
        png = _save(ctx, pl.name, pl.image)
        idx = g.add_input(["-loop", "1", "-framerate", str(fps), "-t", f"{dur:.5f}", "-i", fpath(png)])
        chain = ["format=rgba"]
    fi = min(pl.fade_in, dur / 2)
    fo = min(pl.fade_out, dur / 2)
    if fi > 0:
        chain.append(f"fade=t=in:st=0:d={fi:.4f}:alpha=1")
    if fo > 0:
        chain.append(f"fade=t=out:st={max(0.0, dur - fo):.4f}:d={fo:.4f}:alpha=1")
    chain.append(f"setpts=PTS-STARTPTS+{start:.5f}/TB")
    ov = g.add(f"[{idx}:v]", ",".join(chain))
    x = str(pl.x)
    y = str(pl.y)
    if pl.slide_from and pl.slide > 0:
        sl = min(pl.slide, dur / 2)
        off = (f"{pl.slide_from}*(pow(1-clip((t-{start:.4f})/{sl:.4f},0,1),3)"
               f"+pow(clip((t-{end - sl:.4f})/{sl:.4f},0,1),3))")
        x = f"{pl.x}-{off}"
    if pl.rise and fi > 0:
        rt = max(fi, 0.25)
        y = f"{pl.y}+{pl.rise}*pow(1-clip((t-{start:.4f})/{rt:.4f},0,1),2)"
    return g.add([base, ov], f"overlay=x='{x}':y='{y}':eof_action=pass:format=gbrp:"
                             f"enable='between(t,{start:.4f},{end:.4f})'")


def text_layers(g: Graph, ctx: Ctx, base: str) -> str:
    """Captions and the lower third shared by every segment type."""
    spec = ctx.plan.spec
    lt: Optional[Placed] = None
    if isinstance(spec.get("lower_third"), dict):
        lt = place_lower_third(ctx.theme, spec["lower_third"])
        base = overlay_placed(g, ctx, base, lt)
    for c in spec.get("captions") or []:
        pl = place_caption(ctx.theme, c)
        if lt is not None and lt.image is not None and pl.image is not None:
            lt_end = lt.end if lt.end is not None else ctx.dur
            overlap_t = pl.start < lt_end and (pl.end or ctx.dur) > lt.start
            overlap_x = pl.x < lt.x + lt.image.width and pl.x + pl.image.width > lt.x
            overlap_y = pl.y + pl.image.height > lt.y
            if overlap_t and overlap_x and overlap_y:  # sit above the lower third instead of on it
                pl = place_caption(ctx.theme, c, avoid_bottom=lt.y)
        base = overlay_placed(g, ctx, base, pl)
    return base


# ------------------------------------------------------------------------------------------------------------
# segment types
# ------------------------------------------------------------------------------------------------------------
def _background(g: Graph, ctx: Ctx, zoom_key: str) -> str:
    spec = ctx.plan.spec
    bg = spec.get("background")
    m = ctx.plan.media.get("background")
    if not bg or m is None:
        return color_chain(g, ctx, ctx.theme.hex("background"))
    zoom = spec.get("zoom")
    if zoom is None:
        z = ctx.theme.get(f"{zoom_key}.background_zoom")
        zoom = {"from": z[0], "to": z[1], "ease": "out"} if z else None
    lab = source_chain(g, ctx, m, bg, ctx.plan.frames, zoom=zoom, fit=bg.get("fit", "cover"))
    chain = []
    blur = float(bg.get("blur", 0) or 0)
    if blur > 0:
        chain.append(f"gblur=sigma={ctx.theme.pxf(blur):.3f}:steps=3")
    k = 1.0 - float(bg.get("darken", 0) or 0)
    if k < 0.999:
        chain.append(f"colorchannelmixer=rr={k:.4f}:gg={k:.4f}:bb={k:.4f}")
    return g.add(lab, ",".join(chain)) if chain else lab


def build_card(g: Graph, ctx: Ctx) -> str:
    """``title`` | ``chapter`` | ``end`` cards."""
    spec, t = ctx.plan.spec, ctx.plan.type
    key = {"title": "title_card", "chapter": "chapter_card", "end": "end_card"}[t]
    base = _background(g, ctx, key)
    if t == "title":
        layers = title_card(ctx.theme, spec["title"], spec.get("subtitle"), ctx.fps)
    elif t == "chapter":
        layers = chapter_card(ctx.theme, spec.get("number"), spec["title"], spec.get("subtitle"), ctx.fps)
    else:
        layers = end_card(ctx.theme, spec["lines"])
    for pl in layers:
        base = overlay_placed(g, ctx, base, pl)
    return base


def build_clip(g: Graph, ctx: Ctx) -> str:
    spec = ctx.plan.spec
    return source_chain(g, ctx, ctx.plan.media["src"], spec, ctx.plan.frames, zoom=spec.get("zoom"))


def _labels(ctx: Ctx) -> tuple[Optional[str], Optional[str]]:
    lab = ctx.plan.spec.get("labels") or [None, None]
    return lab[0], lab[1]


def build_compare(g: Graph, ctx: Ctx) -> str:
    """split | wipe | sidebyside."""
    spec, th = ctx.plan.spec, ctx.theme
    mode = spec.get("mode", "split")
    W, H, n, fps = ctx.W, ctx.H, ctx.plan.frames, ctx.fps
    zoom = spec.get("zoom")
    lf = float(th.get("compare.label_fade", 0.15))
    left_lab, right_lab = _labels(ctx)
    dw = max(1, th.px(th.get("compare.divider_width", 3)))
    divc = th.hex(th.get("compare.divider_color", "text"))
    if mode == "sidebyside":
        gap = th.px(th.get("compare.gap", 28))
        bw = (W - 2 * th.safe_x - gap) // 2 // 2 * 2
        bh = int(round(bw * 9 / 16 / 2)) * 2
        base = color_chain(g, ctx, th.hex("background"))
        lab_h = label_image(th, "Ag").height if (left_lab or right_lab) else 0
        y = (H - bh - (lab_h + th.px(18) if lab_h else 0)) // 2
        xs = (th.safe_x, th.safe_x + bw + gap)
        for side, x, text in (("left", xs[0], left_lab), ("right", xs[1], right_lab)):
            src = source_chain(g, ctx, ctx.plan.media[side], spec[side], n, box=(bw, bh), zoom=zoom)
            base = g.add([base, src], f"overlay=x={x}:y={y}:format=gbrp")
            if text:
                im = label_image(th, text)
                base = overlay_placed(g, ctx, base, Placed(f"label_{side}", im, x + (bw - im.width) // 2,
                                                           y + bh + th.px(18), start=0.2, fade_in=lf))
        return base
    L = source_chain(g, ctx, ctx.plan.media["left"], spec["left"], n, zoom=zoom)
    if mode == "split":
        R = source_chain(g, ctx, ctx.plan.media["right"], spec["right"], n, zoom=zoom)
        half = W // 2
        lc = g.add(L, f"crop={half}:{H}:0:0")
        rc = g.add(R, f"crop={W - half}:{H}:{half}:0")
        base = g.add([lc, rc], "hstack=inputs=2")
        div = color_chain(g, ctx, divc, size=(dw, H))
        base = g.add([base, div], f"overlay=x={half - dw // 2}:y=0:format=gbrp")
        if left_lab:
            base = overlay_placed(g, ctx, base, Placed("label_left", label_image(th, left_lab), th.safe_x, th.safe_y,
                                                       start=0.2, fade_in=lf))
        if right_lab:
            im = label_image(th, right_lab)
            base = overlay_placed(g, ctx, base, Placed("label_right", im, W - th.safe_x - im.width, th.safe_y,
                                                       start=0.2, fade_in=lf))
        return base
    # wipe: the right source is revealed from the left edge as the divider sweeps left -> right
    sw = spec.get("sweep") or th.get("compare.sweep", [0.1, 0.9])
    f0 = max(1, int(round(sw[0] * n)))
    f1 = min(n - 1, max(f0 + 2, int(round(sw[1] * n))))
    t0, sd = f0 / fps, (f1 - f0) / fps
    R = source_chain(g, ctx, ctx.plan.media["right"], spec["right"], n, zoom=zoom, skip_frames=f0)
    base = g.add([L, R], f"xfade=transition=wiperight:duration={sd:.5f}:offset={t0:.5f},"
                         f"trim=end_frame={n},setpts=PTS-STARTPTS")
    div = color_chain(g, ctx, divc, size=(dw, H))
    base = g.add([base, div], f"overlay=x='{W}*(t-{t0:.5f})/{sd:.5f}-{dw / 2:.1f}':y=0:format=gbrp:"
                              f"enable='between(t,{t0:.5f},{t0 + sd:.5f})'")
    dur = n / fps
    if left_lab:  # "before": top-right, hidden when the divider reaches it
        im = label_image(th, left_lab)
        x = W - th.safe_x - im.width
        hide = t0 + sd * (x / W)
        if hide > 0.35:
            base = overlay_placed(g, ctx, base, Placed("label_left", im, x, th.safe_y, start=0.1, end=hide,
                                                       fade_in=lf, fade_out=lf))
    if right_lab:  # "after": top-left, shown once the divider has passed it
        im = label_image(th, right_lab)
        show = t0 + sd * ((th.safe_x + im.width) / W)
        if show < dur - 0.3:
            base = overlay_placed(g, ctx, base, Placed("label_right", im, th.safe_x, th.safe_y, start=show,
                                                       fade_in=lf))
    return base


def inset_rect(ctx: Ctx, media: Media, ins: dict) -> tuple[int, int, int, int]:
    """(x, y, w, h) of the PiP inset."""
    W, H = ctx.W, ctx.H
    w = int(round(W * float(ins.get("width", 0.42)) / 2)) * 2
    sw, sh = media.size or (16, 9)
    h = int(round(w * sh / sw / 2)) * 2
    h = min(h, H - 2 * ctx.theme.safe_y)
    m = int(round(W * float(ins.get("margin", 0.04))))
    pos = ins.get("position", "right")
    xs = {"left": m, "right": W - m - w, "center": (W - w) // 2}
    ys = {"top": m, "bottom": H - m - h, "middle": (H - h) // 2}
    if pos in ("right", "left", "center"):
        return xs[pos], ys["middle"], w, h
    v, hz = pos.split("-")
    return xs[hz], ys[v], w, h


def inset_framed(media: Media, ins: dict) -> bool:
    """``inset.frame``: draw the kit's rounded mask, shadow and border. Defaults to true for opaque sources and
    false for sources with their own alpha (they bring their own panel)."""
    fr = ins.get("frame")
    return (not media.has_alpha) if fr is None else bool(fr)


def build_overlay(g: Graph, ctx: Ctx) -> str:
    """Picture-in-picture: base full frame plus an inset. Opaque insets get rounded corners, a soft shadow and a
    hairline border (``frame``); insets with their own alpha composite as-is unless ``frame: true``."""
    spec, th = ctx.plan.spec, ctx.theme
    n = ctx.plan.frames
    base = source_chain(g, ctx, ctx.plan.media["base"], spec["base"], n, zoom=spec.get("zoom"))
    ins = spec["inset"]
    media = ctx.plan.media["inset"]
    x, y, w, h = inset_rect(ctx, media, ins)
    framed = inset_framed(media, ins)
    fade = 0.3
    border = None
    if framed:
        mask, shadow, (sx, sy), border = inset_parts(th, w, h)
        base = overlay_placed(g, ctx, base, Placed("inset_shadow", shadow, x + sx, y + sy, fade_in=fade))
    if media.has_alpha:
        # keep the source's own transparency; contain so a transparent panel's corners are never cropped
        src = source_chain(g, ctx, media, ins, n, box=(w, h), fit=ins.get("fit", "contain"), alpha=True)
        ia = g.add(src, f"fade=t=in:st=0:d={fade}:alpha=1")
    else:
        src = source_chain(g, ctx, media, ins, n, box=(w, h), fit=ins.get("fit", "cover"))
        if framed:
            mpng = _save(ctx, "inset_mask", mask)
            midx = g.add_input(["-loop", "1", "-framerate", str(ctx.fps), "-t", f"{n / ctx.fps + 0.5:.3f}",
                                "-i", fpath(mpng)])
            mk = g.add(f"[{midx}:v]", f"format=gray,trim=end_frame={n},setpts=PTS-STARTPTS")
            ia = g.add([g.add(src, "format=gbrap"), mk], f"alphamerge,fade=t=in:st=0:d={fade}:alpha=1")
        else:
            ia = g.add(src, f"format=gbrap,fade=t=in:st=0:d={fade}:alpha=1")
    base = g.add([base, ia], f"overlay=x={x}:y={y}:format=gbrp")
    if border is not None:
        base = overlay_placed(g, ctx, base, Placed("inset_border", border, x, y, fade_in=fade))
    if ins.get("label"):
        im = label_image(th, ins["label"])
        gap = th.px(th.get("inset.label_gap", 14))
        ly = y - gap - im.height if y - gap - im.height >= th.safe_y // 2 else y + h + gap
        base = overlay_placed(g, ctx, base, Placed("inset_label", im, x, ly, start=0.25, fade_in=0.2))
    return base


BUILDERS = {"title": build_card, "chapter": build_card, "end": build_card, "clip": build_clip,
            "compare": build_compare, "overlay": build_overlay}


def build_segment_graph(ctx: Ctx) -> Graph:
    """Full graph for one segment, ending in ``[out]``."""
    g = Graph()
    base = BUILDERS[ctx.plan.type](g, ctx)
    base = text_layers(g, ctx, base)
    g.add(base, f"trim=end_frame={ctx.plan.frames},setpts=PTS-STARTPTS", "[out]")
    return g


def describe(ctx: Ctx) -> str:
    """Short human summary of a segment for dry runs."""
    s = ctx.plan.spec
    bits = [ctx.plan.type]
    if ctx.plan.type == "compare":
        bits.append(s.get("mode", "split"))
    for k, m in ctx.plan.media.items():
        bits.append(f"{k}={m.kind}:{Path(str(m.path)).parent.name if m.kind == 'sequence' else Path(m.path).name}")
    if s.get("zoom"):
        bits.append(f"zoom {json.dumps(s['zoom'])}")
    return " ".join(bits)
