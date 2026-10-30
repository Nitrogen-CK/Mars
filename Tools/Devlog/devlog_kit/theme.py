"""Theme loading (built-in name, JSON path or inline object, deep-merged over ``themes/default.json``),
colour parsing and font resolution with fallbacks."""

from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any, Optional, Union

from PIL import ImageFont

from . import DevlogError

THEMES_DIR = Path(__file__).resolve().parent / "themes"

RGBA = tuple[int, int, int, int]


def deep_merge(base: dict, over: dict) -> dict:
    """Return ``base`` with ``over`` merged in recursively (dicts merge, everything else replaces)."""
    out = copy.deepcopy(base)
    for k, v in over.items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = deep_merge(out[k], v)
        else:
            out[k] = copy.deepcopy(v)
    return out


def _read_json(p: Path) -> dict:
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise DevlogError(f"theme file not found: {p}") from exc
    except json.JSONDecodeError as exc:
        raise DevlogError(f"theme file {p} is not valid JSON: {exc}") from exc


def resolve_theme_dict(spec: Union[None, str, dict], manifest_dir: Path) -> tuple[dict, str]:
    """Resolve a manifest ``theme`` value into a full theme dict and a short description.

    * ``None`` / ``"default"``: the built-in default.
    * a string naming a file in ``devlog_kit/themes/`` (without ``.json``), or a path to a JSON file
      (relative to the manifest folder): merged over the default, so a theme file may be partial.
    * an object: merged over the default (or over ``"base"``, a name/path, when given).
    """
    default = _read_json(THEMES_DIR / "default.json")
    if spec is None or spec == "default":
        return default, "default"
    if isinstance(spec, str):
        builtin = THEMES_DIR / f"{spec}.json"
        p = builtin if builtin.is_file() else Path(spec)
        if not p.is_absolute():
            p = manifest_dir / p
        return deep_merge(default, _read_json(p)), str(p)
    if isinstance(spec, dict):
        base = default
        desc = "inline"
        if isinstance(spec.get("base"), str):
            base, desc = resolve_theme_dict(spec["base"], manifest_dir)
            desc = f"inline over {desc}"
        return deep_merge(base, {k: v for k, v in spec.items() if k != "base"}), desc
    raise DevlogError(f"'theme' must be \"default\", a theme name/path or an object, got {type(spec).__name__}")


class Theme:
    """A resolved theme bound to an output frame size.

    All pixel values in the theme are 1080p units; :meth:`px` scales them by ``min(width, height) / 1080``.
    """

    def __init__(self, data: dict, width: int, height: int, desc: str = "default") -> None:
        self.data = data
        self.desc = desc
        self.width = width
        self.height = height
        self.scale = min(width, height) / 1080.0
        self._fonts: dict[tuple[str, int], ImageFont.FreeTypeFont] = {}
        self.font_warnings: list[str] = []
        self._font_checked: set[str] = set()

    # -- access ---------------------------------------------------------------------------------------------
    def get(self, dotted: str, default: Any = None) -> Any:
        """``theme.get("caption.big.size")``."""
        cur: Any = self.data
        for part in dotted.split("."):
            if not isinstance(cur, dict) or part not in cur:
                return default
            cur = cur[part]
        return cur

    def px(self, v: float) -> int:
        """Scale a 1080p-unit length to output pixels."""
        return int(round(float(v) * self.scale))

    def pxf(self, v: float) -> float:
        return float(v) * self.scale

    @property
    def safe_x(self) -> int:
        return int(round(self.width * float(self.get("safe_margin", 0.05))))

    @property
    def safe_y(self) -> int:
        return int(round(self.height * float(self.get("safe_margin", 0.05))))

    # -- colours --------------------------------------------------------------------------------------------
    def color(self, v: Any) -> RGBA:
        """Parse ``#rgb``, ``#rrggbb``, ``#rrggbbaa``, ``[r, g, b]``, ``[r, g, b, a(0..1)]`` or a colour name
        from ``colors`` (e.g. ``"accent"``) into an RGBA tuple of 0..255 ints."""
        if isinstance(v, str) and not v.startswith("#"):
            named = self.get(f"colors.{v}")
            if named is None:
                raise DevlogError(f"theme: unknown colour name '{v}'")
            return self.color(named)
        if isinstance(v, str):
            h = v[1:]
            if len(h) == 3:
                h = "".join(c * 2 for c in h)
            if len(h) not in (6, 8):
                raise DevlogError(f"theme: bad colour '{v}'")
            r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
            a = int(h[6:8], 16) if len(h) == 8 else 255
            return (r, g, b, a)
        if isinstance(v, (list, tuple)) and len(v) in (3, 4):
            r, g, b = (int(round(float(c))) for c in v[:3])
            a = 255 if len(v) == 3 else int(round(float(v[3]) * 255)) if float(v[3]) <= 1.0 else int(v[3])
            return (r, g, b, a)
        raise DevlogError(f"theme: bad colour {v!r}")

    def hex(self, v: Any) -> str:
        """Colour as ``0xRRGGBB`` for ffmpeg (alpha dropped)."""
        r, g, b, _ = self.color(v)
        return f"0x{r:02x}{g:02x}{b:02x}"

    def ff_color(self, v: Any) -> str:
        """Colour as ``0xRRGGBB@alpha`` for ffmpeg colour sources."""
        r, g, b, a = self.color(v)
        return f"0x{r:02x}{g:02x}{b:02x}@{a / 255:.3f}"

    # -- fonts ----------------------------------------------------------------------------------------------
    def font(self, role: str, size_px: int) -> ImageFont.FreeTypeFont:
        """Load the font for ``role`` (a key of ``fonts``) at ``size_px`` output pixels, trying each path in
        order and falling back to Pillow's built-in font (with a warning) when none exists."""
        key = (role, size_px)
        if key in self._fonts:
            return self._fonts[key]
        spec = self.get(f"fonts.{role}")
        if spec is None:
            raise DevlogError(f"theme: no font role '{role}' (have {sorted(self.get('fonts', {}))})")
        if isinstance(spec, str):
            spec = {"paths": [spec]}
        paths = spec.get("paths") or ([spec["path"]] if "path" in spec else [])
        font: Optional[ImageFont.FreeTypeFont] = None
        for p in paths:
            if Path(p).is_file():
                try:
                    font = ImageFont.truetype(p, size_px, index=int(spec.get("index", 0)))
                except OSError:
                    continue
                var = spec.get("variation")
                if var:
                    try:
                        font.set_variation_by_name(var)
                    except (OSError, ValueError):
                        if role not in self._font_checked:
                            self.font_warnings.append(f"font role '{role}': {p} has no variation '{var}'")
                break
        if font is None:
            if role not in self._font_checked:
                self.font_warnings.append(f"font role '{role}': none of {paths} exist; using Pillow's default font")
            font = ImageFont.load_default(size_px)  # type: ignore[assignment]
        self._font_checked.add(role)
        self._fonts[key] = font  # type: ignore[assignment]
        return font  # type: ignore[return-value]

    def fingerprint(self) -> str:
        """Stable JSON of the theme for cache keys."""
        return json.dumps(self.data, sort_keys=True)
