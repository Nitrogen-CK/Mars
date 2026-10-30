"""Pillow renderers for every piece of on-screen text and chrome.

Everything is drawn into tightly-cropped transparent RGBA images (straight alpha) that the segment builder
writes to PNG and composites with ffmpeg ``overlay``. Layout is deterministic: word wrapping uses font
advance widths, boxes are supersampled rounded rectangles, and shadows are blurred glyph masks.

Caption markup: ``*words*`` renders those words in the theme's accent colour (``caption.accent_markup``);
``\\n`` forces a line break.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Optional

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from .theme import Theme, RGBA

SUPERSAMPLE = 4


# ------------------------------------------------------------------------------------------------------------
# primitives
# ------------------------------------------------------------------------------------------------------------
@dataclass
class Token:
    """One word. ``accent`` colours it; ``br`` forces a line break before it."""
    text: str
    accent: bool = False
    br: bool = False


class FitError(ValueError):
    """Text cannot fit the allowed lines even at the minimum size."""


def parse_markup(text: str, markup: bool = True) -> list[Token]:
    """Split ``text`` into word tokens, honouring ``*accent*`` spans and explicit newlines."""
    tokens: list[Token] = []
    text = str(text).replace("\\n", "\n")  # a literal backslash-n (two characters) also breaks the line
    for li, line in enumerate(text.split("\n")):
        parts = re.split(r"(\*[^*\n]+\*)", line) if markup else [line]
        first = True
        glue = False            # the previous part ended without a space: its last token continues into this one
        for part in parts:
            if not part:
                continue
            accent = markup and len(part) > 2 and part.startswith("*") and part.endswith("*")
            body = part[1:-1] if accent else part
            words = body.split()
            if words and glue and not body[0].isspace() and tokens and not first:
                # punctuation (or letters) glued to an accent span stays on that word: "*Final*:" -> "Final:"
                tokens[-1].text += words[0]
                words = words[1:]
            for w in words:
                tokens.append(Token(w, accent, br=(li > 0 and first)))
                first = False
            glue = bool(body) and not body[-1].isspace()
    return tokens


def plain_text(text: str) -> str:
    """Text with markup removed (for storyboards and word counts)."""
    return re.sub(r"\*([^*\n]+)\*", r"\1", str(text).replace("\\n", "\n")).replace("\n", " / ")


def _space(font: ImageFont.FreeTypeFont) -> float:
    return font.getlength(" ")


def line_width(line: list[Token], font: ImageFont.FreeTypeFont) -> float:
    if not line:
        return 0.0
    return sum(font.getlength(t.text) for t in line) + _space(font) * (len(line) - 1)


def wrap(tokens: list[Token], font: ImageFont.FreeTypeFont, max_w: float) -> list[list[Token]]:
    """Greedy word wrap; a single word wider than ``max_w`` still gets its own line (reported by :func:`fit`)."""
    lines: list[list[Token]] = []
    cur: list[Token] = []
    for t in tokens:
        if cur and (t.br or line_width(cur + [t], font) > max_w):
            lines.append(cur)
            cur = []
        cur.append(t)
    if cur:
        lines.append(cur)
    return lines


def _balance(tokens: list[Token], font: ImageFont.FreeTypeFont, max_w: float,
             lines: list[list[Token]]) -> list[list[Token]]:
    """For two-line results, move the break so both lines are similar width (nicer TikTok-style captions)."""
    if len(lines) != 2 or any(t.br for t in tokens):
        return lines
    best = lines
    best_score = max(line_width(lines[0], font), line_width(lines[1], font))
    for k in range(1, len(tokens)):
        a, b = tokens[:k], tokens[k:]
        wa, wb = line_width(a, font), line_width(b, font)
        if wa <= max_w and wb <= max_w and max(wa, wb) < best_score - 0.5:
            best, best_score = [a, b], max(wa, wb)
    return best


def fit(theme: Theme, text: str, role: str, size: float, min_size: float, max_w: float, max_lines: int,
        markup: bool = True, balance: bool = True) -> tuple[ImageFont.FreeTypeFont, list[list[Token]], int]:
    """Find the largest font size (from ``size`` down to ``min_size``, 1080p units) at which ``text`` wraps
    into at most ``max_lines`` lines of width ``max_w`` output pixels. Raises :class:`FitError`."""
    tokens = parse_markup(text, markup)
    if not tokens:
        raise FitError("empty text")
    s = float(size)
    while True:
        px = max(8, theme.px(s))
        font = theme.font(role, px)
        lines = wrap(tokens, font, max_w)
        too_wide = any(line_width(l, font) > max_w + 0.5 for l in lines)
        if len(lines) <= max_lines and not too_wide:
            if balance:
                lines = _balance(tokens, font, max_w, lines)
            return font, lines, px
        if s - 2 < float(min_size) - 1e-6:
            raise FitError(f"'{plain_text(text)}' needs {len(lines)} lines at the minimum size "
                           f"{min_size:g}px (max {max_lines}); shorten it")
        s -= 2


def font_metrics(font: ImageFont.FreeTypeFont) -> tuple[int, int, int]:
    """(ascent, descent, cap height) in pixels."""
    asc, desc = font.getmetrics()
    bb = font.getbbox("H", anchor="ls")
    cap = -bb[1] if bb else asc
    return asc, desc, cap


def rounded_rect(w: int, h: int, r: float, fill: RGBA, outline: Optional[RGBA] = None,
                 width: int = 0) -> Image.Image:
    """Anti-aliased rounded rectangle (drawn at 4x then reduced)."""
    w, h = max(1, int(w)), max(1, int(h))
    ss = SUPERSAMPLE
    big = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    rad = max(0, min(r, w / 2, h / 2)) * ss
    d.rounded_rectangle((0, 0, w * ss - 1, h * ss - 1), radius=rad, fill=fill,
                        outline=outline, width=width * ss if outline else 0)
    return big.resize((w, h), Image.LANCZOS)


def rounded_mask(w: int, h: int, r: float) -> Image.Image:
    """L-mode mask: 255 inside a rounded rectangle."""
    ss = SUPERSAMPLE
    big = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, w * ss - 1, h * ss - 1),
                                          radius=max(0, min(r, w / 2, h / 2)) * ss, fill=255)
    return big.resize((w, h), Image.LANCZOS)


def _text_mask(size: tuple[int, int], draws: list[tuple[float, float, str, ImageFont.FreeTypeFont]]) -> Image.Image:
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    for x, y, s, f in draws:
        d.text((x, y), s, font=f, fill=255, anchor="ls")
    return m


def draw_text_lines(img: Image.Image, lines: list[list[Token]], font: ImageFont.FreeTypeFont, *,
                    first_baseline: float, line_h: float, color: RGBA, accent: RGBA, align: str = "center",
                    x: float = 0.0, shadow: Optional[tuple[RGBA, float, tuple[float, float]]] = None) -> None:
    """Draw wrapped ``lines`` into ``img``. ``align`` = center (around img centre) | left (from ``x``).
    ``shadow`` = (colour, blur radius px, (dx, dy))."""
    space = _space(font)
    draws: list[tuple[float, float, str, ImageFont.FreeTypeFont, bool]] = []
    for i, line in enumerate(lines):
        lw = line_width(line, font)
        cx = (img.width - lw) / 2 if align == "center" else x
        by = first_baseline + i * line_h
        for t in line:
            draws.append((cx, by, t.text, font, t.accent))
            cx += font.getlength(t.text) + space
    if shadow:
        col, blur, (dx, dy) = shadow
        mask = _text_mask(img.size, [(a + dx, b + dy, s, f) for a, b, s, f, _ in draws])
        if blur > 0:
            mask = mask.filter(ImageFilter.GaussianBlur(blur))
        layer = Image.new("RGBA", img.size, col[:3] + (0,))
        layer.putalpha(mask.point(lambda v: int(v * col[3] / 255)))
        img.alpha_composite(layer)
    d = ImageDraw.Draw(img)
    for a, b, s, f, acc in draws:
        d.text((a, b), s, font=f, fill=accent if acc else color, anchor="ls")


def _shadow_spec(theme: Theme, strength: float = 1.0) -> tuple[RGBA, float, tuple[float, float]]:
    col = theme.color(theme.get("colors.shadow", [0, 0, 0, 0.65]))
    col = col[:3] + (int(col[3] * strength),)
    return col, theme.pxf(4), (0.0, theme.pxf(3))


# ------------------------------------------------------------------------------------------------------------
# placed layers (what the segment builder composites)
# ------------------------------------------------------------------------------------------------------------
@dataclass
class Placed:
    """An image (or animated frame list) placed in a segment.

    ``start``/``end`` are seconds into the segment (``end=None`` = to the segment end). ``rise`` px: the layer
    rises into place while fading in. ``slide_from`` px: the layer slides horizontally from ``x - slide_from``
    over ``slide`` seconds on entry and back out on exit (lower thirds).
    """
    name: str
    image: Optional[Image.Image]
    x: int
    y: int
    start: float = 0.0
    end: Optional[float] = None
    fade_in: float = 0.0
    fade_out: float = 0.0
    rise: int = 0
    slide_from: int = 0
    slide: float = 0.0
    frames: Optional[list[Image.Image]] = None
    meta: dict = field(default_factory=dict)


# ------------------------------------------------------------------------------------------------------------
# captions
# ------------------------------------------------------------------------------------------------------------
def caption_image(theme: Theme, text: str, style: str) -> tuple[Image.Image, dict]:
    """Render a boxed caption. Returns (image, info) with info = lines (plain), font px, words per line."""
    st = theme.get(f"caption.{style}")
    if st is None:
        raise FitError(f"unknown caption style '{style}' (big | small)")
    pad_x, pad_y = (theme.px(v) for v in st.get("padding", [32, 18]))
    column = min(theme.px(st.get("column", 1080)), theme.width - 2 * theme.safe_x)
    max_text_w = column - 2 * pad_x
    font, lines, px = fit(theme, text, st.get("font", "caption"), st.get("size", 60), st.get("min_size", 40),
                          max_text_w, int(st.get("max_lines", 2)), bool(theme.get("caption.accent_markup", True)))
    asc, desc, cap = font_metrics(font)
    line_h = px * float(st.get("line_spacing", 1.15))
    desc_vis = 0.22 * px
    text_w = max(line_width(l, font) for l in lines)
    w = int(round(text_w + 2 * pad_x))
    h = int(round(cap + (len(lines) - 1) * line_h + desc_vis + 2 * pad_y))
    img = rounded_rect(w, h, theme.px(theme.get("caption.radius", 24)), theme.color(theme.get("caption.box")))
    draw_text_lines(img, lines, font, first_baseline=pad_y + cap, line_h=line_h,
                    color=theme.color(theme.get("caption.color", "text")),
                    accent=theme.color(theme.get("caption.accent_color", "accent")),
                    shadow=_shadow_spec(theme, 0.8) if theme.get("caption.shadow", True) else None)
    info = {"lines": [" ".join(t.text for t in l) for l in lines], "font_px": px,
            "words_per_line": [len(l) for l in lines], "column_px": column}
    return img, info


def place_caption(theme: Theme, cap: dict, avoid_bottom: Optional[int] = None) -> Placed:
    """Render and position a caption dict (``text``, ``style``, ``position``, ``at``, ``duration``).

    ``avoid_bottom``: y of the top of a lower third active at the same time; bottom captions sit above it.
    """
    style = cap.get("style", "big")
    img, info = caption_image(theme, cap["text"], style)
    pos = cap.get("position") or theme.get(f"caption.{style}.default_position", "center")
    W, H = theme.width, theme.height
    x = (W - img.width) // 2
    if pos == "top":
        y = theme.safe_y + theme.px(10)
    elif pos == "bottom":
        bottom = H - theme.safe_y - (theme.px(20) if style == "big" else 0)
        if avoid_bottom is not None:
            bottom = min(bottom, avoid_bottom - theme.px(18))
        y = bottom - img.height
    else:
        y = (H - img.height) // 2
    fade = float(theme.get("caption.fade", 0.2))
    rise = theme.px(theme.get(f"caption.{style}.rise", 0))
    at, dur = float(cap.get("at", 0.0)), float(cap["duration"])
    return Placed(f"caption_{style}", img, int(x), int(y), start=at, end=at + dur, fade_in=fade, fade_out=fade,
                  rise=rise, meta=info)


# ------------------------------------------------------------------------------------------------------------
# lower third
# ------------------------------------------------------------------------------------------------------------
def lower_third_image(theme: Theme, title: str, subtitle: Optional[str]) -> Image.Image:
    """Dark slab with an accent bar on the left, title over subtitle."""
    lt = theme.get("lower_third")
    pad_x, pad_y = (theme.px(v) for v in lt.get("padding", [30, 18]))
    bar = theme.px(lt.get("bar_width", 8))
    max_w = min(theme.px(lt.get("max_width", 1100)), theme.width - 2 * theme.safe_x) - 2 * pad_x - bar
    tf, tl, tpx = fit(theme, title, lt["title_font"], lt["title_size"], lt["title_size"] * 0.75, max_w, 1, False,
                      balance=False)
    t_asc, t_desc, t_cap = font_metrics(tf)
    sub_lines: list[list[Token]] = []
    sf = None
    s_cap = 0
    s_line_h = 0.0
    spx = tpx
    if subtitle:
        sf, sub_lines, spx = fit(theme, subtitle, lt["subtitle_font"], lt["subtitle_size"],
                                 lt["subtitle_size"] * 0.8, max_w, 2, False, balance=False)
        _, _, s_cap = font_metrics(sf)
        s_line_h = spx * 1.25
    gap = theme.px(lt.get("gap", 6)) + (theme.px(14) if subtitle else 0)
    widths = [line_width(tl[0], tf)] + ([line_width(l, sf) for l in sub_lines] if sf is not None else [])
    w = int(round(bar + 2 * pad_x + max(widths)))
    desc_allow = 0.22 * spx
    h_text = t_cap + ((gap + s_cap + (len(sub_lines) - 1) * s_line_h) if sub_lines else 0) + desc_allow
    h = int(round(h_text + 2 * pad_y))
    slab = rounded_rect(w, h, theme.px(lt.get("radius", 10)), theme.color(lt["box"]))
    # accent bar clipped to the slab's rounded left edge
    bar_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(bar_layer).rectangle((0, 0, bar - 1, h), fill=theme.color(lt.get("bar_color", "accent")))
    alpha = bar_layer.getchannel("A")
    from PIL import ImageChops
    bar_layer.putalpha(ImageChops.multiply(alpha, rounded_mask(w, h, theme.px(lt.get("radius", 10)))))
    slab.alpha_composite(bar_layer)
    tx = bar + pad_x
    draw_text_lines(slab, tl, tf, first_baseline=pad_y + t_cap, line_h=0, align="left", x=tx,
                    color=theme.color(lt.get("title_color", "text")), accent=theme.color("accent"))
    if sub_lines and sf is not None:
        draw_text_lines(slab, sub_lines, sf, first_baseline=pad_y + t_cap + gap + s_cap, line_h=s_line_h,
                        align="left", x=tx, color=theme.color(lt.get("subtitle_color", "muted")),
                        accent=theme.color("accent"))
    return slab


def place_lower_third(theme: Theme, lt_spec: dict) -> Placed:
    """Lower third anchored bottom-left inside the safe margins, sliding in from the left."""
    img = lower_third_image(theme, lt_spec["title"], lt_spec.get("subtitle"))
    x = theme.safe_x
    y = theme.height - theme.safe_y - img.height
    at = float(lt_spec.get("at", 0.5))
    dur = float(lt_spec.get("duration", 4.0))
    lt = theme.get("lower_third")
    return Placed("lower_third", img, x, y, start=at, end=at + dur, fade_in=float(lt.get("fade", 0.15)),
                  fade_out=float(lt.get("fade", 0.15)), slide_from=x + img.width, slide=float(lt.get("slide", 0.35)))


# ------------------------------------------------------------------------------------------------------------
# labels (compare halves, PiP inset)
# ------------------------------------------------------------------------------------------------------------
def label_image(theme: Theme, text: str) -> Image.Image:
    """Small pill: accent dot + text."""
    lb = theme.get("label")
    font = theme.font(lb.get("font", "caption"), theme.px(lb.get("size", 30)))
    _, _, cap = font_metrics(font)
    pad_x, pad_y = (theme.px(v) for v in lb.get("padding", [20, 10]))
    dot = max(4, int(round(cap * 0.5)))
    dot_gap = int(round(cap * 0.5))
    toks = [parse_markup(text, False)]
    tw = line_width(toks[0], font)
    w = int(round(pad_x * 2 + dot + dot_gap + tw))
    h = int(round(cap + 0.22 * font.size + pad_y * 2))
    img = rounded_rect(w, h, theme.px(lb.get("radius", 14)), theme.color(lb["box"]))
    dot_img = rounded_rect(dot, dot, dot / 2, theme.color(lb.get("dot_color", "accent")))
    img.alpha_composite(dot_img, (pad_x, int(round(pad_y + cap / 2 - dot / 2 + 0.11 * font.size * 0.4))))
    draw_text_lines(img, toks, font, first_baseline=pad_y + cap, line_h=0, align="left", x=pad_x + dot + dot_gap,
                    color=theme.color(lb.get("color", "text")), accent=theme.color("accent"))
    return img


# ------------------------------------------------------------------------------------------------------------
# cards
# ------------------------------------------------------------------------------------------------------------
def _text_block(theme: Theme, text: str, role: str, size: float, min_size: float, color: RGBA, max_lines: int = 2,
                line_spacing: float = 1.1, shadow: bool = True) -> Image.Image:
    max_w = theme.width - 2 * theme.safe_x - theme.px(40)
    font, lines, px = fit(theme, text, role, size, min_size, max_w, max_lines, True)
    asc, desc, cap = font_metrics(font)
    line_h = px * line_spacing
    pad = theme.px(12)
    w = int(round(max(line_width(l, font) for l in lines) + 2 * pad))
    h = int(round(cap + (len(lines) - 1) * line_h + 0.25 * px + 2 * pad))
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw_text_lines(img, lines, font, first_baseline=pad + cap, line_h=line_h, color=color,
                    accent=theme.color("accent"), shadow=_shadow_spec(theme) if shadow else None)
    img.info["pad"] = pad
    return img


def rule_frames(theme: Theme, width: int, height: int, color: RGBA, n: int) -> list[Image.Image]:
    """A thin rule growing from its centre with an ease-out, ``n`` frames."""
    frames = []
    n = max(2, n)
    for i in range(n):
        p = i / (n - 1)
        e = 1 - (1 - p) ** 3
        cur = max(1, int(round(width * e)))
        im = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        im.alpha_composite(rounded_rect(cur, height, height / 2, color), ((width - cur) // 2, 0))
        frames.append(im)
    return frames


def _stack(theme: Theme, items: list[tuple[str, Image.Image, int]]) -> list[tuple[str, Image.Image, int, int]]:
    """Centre ``items`` (name, image, gap-before) vertically and horizontally; returns (name, img, x, y)."""
    total = sum(im.height + gap for _, im, gap in items)
    y = (theme.height - total) // 2
    out = []
    for name, im, gap in items:
        y += gap
        out.append((name, im, (theme.width - im.width) // 2, y))
        y += im.height
    return out


def title_card(theme: Theme, title: str, subtitle: Optional[str], fps: int) -> list[Placed]:
    """Title + accent rule + subtitle, centred, fading/rising in with a stagger."""
    tc = theme.get("title_card")
    t_img = _text_block(theme, title, tc["title_font"], tc["title_size"], tc.get("title_min_size", 72),
                        theme.color("text"))
    rule_w, rule_h = theme.px(tc.get("rule_width", 220)), max(2, theme.px(tc.get("rule_height", 4)))
    frames = rule_frames(theme, rule_w, rule_h, theme.color(tc.get("rule_color", "accent")), int(0.6 * fps))
    items: list[tuple[str, Image.Image, int]] = [("title", t_img, 0), ("rule", frames[-1], theme.px(tc.get("gap", 34)) // 2)]
    s_img = None
    if subtitle:
        s_img = _text_block(theme, subtitle, tc["subtitle_font"], tc["subtitle_size"], tc["subtitle_size"] * 0.75,
                            theme.color(tc.get("subtitle_color", "muted")))
        items.append(("subtitle", s_img, theme.px(tc.get("gap", 34)) // 2))
    fade, rise = float(tc.get("fade", 0.5)), theme.px(tc.get("rise", 18))
    out = []
    for name, im, x, y in _stack(theme, items):
        if name == "title":
            out.append(Placed("title", im, x, y, start=0.15, fade_in=fade, rise=rise))
        elif name == "rule":
            out.append(Placed("rule", None, x, y, start=0.45, frames=frames))
        else:
            out.append(Placed("subtitle", im, x, y, start=0.6, fade_in=fade, rise=rise // 2))
    return out


def chapter_card(theme: Theme, number: Optional[object], title: str, subtitle: Optional[str], fps: int) -> list[Placed]:
    """Chapter number (accent), a thin accent rule that grows in, the chapter title and optional subtitle."""
    cc = theme.get("chapter_card")
    items: list[tuple[str, Image.Image, int]] = []
    if number is not None and number != "":
        try:
            label = str(cc.get("number_format", "{n:02d}")).format(n=int(number))  # type: ignore[arg-type]
        except (ValueError, TypeError):
            label = str(number)
        items.append(("number", _text_block(theme, label, cc["number_font"], cc["number_size"], cc["number_size"],
                                            theme.color(cc.get("number_color", "accent")), 1), 0))
    rule_w, rule_h = theme.px(cc.get("rule_width", 260)), max(2, theme.px(cc.get("rule_height", 4)))
    frames = rule_frames(theme, rule_w, rule_h, theme.color(cc.get("rule_color", "accent")),
                         int(round(float(cc.get("rule_time", 0.55)) * fps)))
    gap = theme.px(cc.get("gap", 30))
    items.append(("rule", frames[-1], gap // 2 if items else 0))
    items.append(("title", _text_block(theme, title, cc["title_font"], cc["title_size"], cc.get("title_min_size", 60),
                                       theme.color("text")), gap // 2))
    if subtitle:
        items.append(("subtitle", _text_block(theme, subtitle, cc["subtitle_font"], cc["subtitle_size"],
                                              cc["subtitle_size"] * 0.75, theme.color(cc.get("subtitle_color", "muted"))),
                      gap // 3))
    fade, rise = float(cc.get("fade", 0.4)), theme.px(cc.get("rise", 14))
    r0 = float(cc.get("rule_start", 0.15))
    out = []
    for name, im, x, y in _stack(theme, items):
        if name == "number":
            out.append(Placed("number", im, x, y, start=0.05, fade_in=fade, rise=rise))
        elif name == "rule":
            out.append(Placed("rule", None, x, y, start=r0, frames=frames))
        elif name == "title":
            out.append(Placed("title", im, x, y, start=r0 + 0.15, fade_in=fade, rise=rise))
        else:
            out.append(Placed("subtitle", im, x, y, start=r0 + 0.35, fade_in=fade, rise=rise // 2))
    return out


def end_card(theme: Theme, lines: list[str]) -> list[Placed]:
    """Centred lines: the first in the title font, the rest in the body font, staggered fade-ins."""
    ec = theme.get("end_card")
    items: list[tuple[str, Image.Image, int]] = []
    for i, line in enumerate(lines):
        if i == 0:
            im = _text_block(theme, line, ec["first_font"], ec["first_size"], ec["first_size"] * 0.7, theme.color("text"))
        else:
            im = _text_block(theme, line, ec["line_font"], ec["line_size"], ec["line_size"] * 0.75,
                             theme.color(ec.get("line_color", "muted")))
        items.append((f"line{i}", im, theme.px(ec.get("line_gap", 26)) if i else 0))
    fade, stagger, rise = float(ec.get("fade", 0.5)), float(ec.get("stagger", 0.25)), theme.px(ec.get("rise", 14))
    return [Placed(name, im, x, y, start=0.1 + i * stagger, fade_in=fade, rise=rise)
            for i, (name, im, x, y) in enumerate(_stack(theme, items))]


# ------------------------------------------------------------------------------------------------------------
# picture-in-picture chrome
# ------------------------------------------------------------------------------------------------------------
def inset_parts(theme: Theme, w: int, h: int) -> tuple[Image.Image, Image.Image, tuple[int, int], Image.Image]:
    """(alpha mask L, shadow RGBA, shadow offset relative to the inset's top-left, border RGBA)."""
    ins = theme.get("inset")
    r = theme.px(ins.get("radius", 18))
    mask = rounded_mask(w, h, r)
    blur = theme.px(ins.get("shadow_blur", 22))
    pad = blur * 3
    sh_col = theme.color(ins.get("shadow", [0, 0, 0, 0.6]))
    sh_mask = Image.new("L", (w + 2 * pad, h + 2 * pad), 0)
    sh_mask.paste(rounded_mask(w, h, r), (pad, pad))
    sh_mask = sh_mask.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: int(v * sh_col[3] / 255))
    shadow = Image.new("RGBA", sh_mask.size, sh_col[:3] + (0,))
    shadow.putalpha(sh_mask)
    dx, dy = (theme.px(v) for v in ins.get("shadow_offset", [0, 10]))
    bw = max(1, theme.px(ins.get("border", 2)))
    border = rounded_rect(w, h, r, (0, 0, 0, 0), outline=theme.color(ins.get("border_color", [243, 239, 230, 0.35])),
                          width=bw)
    return mask, shadow, (dx - pad, dy - pad), border
