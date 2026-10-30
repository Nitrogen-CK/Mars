"""Print an episode's timing table: segment, start, end, transitions and every caption/lower third on the
output timeline (segment-local times shifted by the segment's start, which accounts for xfade overlaps).

    python -m devlog_kit.storyboard <episode.json> [--markdown] [--no-media]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Optional

from . import DevlogError
from .manifest import Episode, load_episode
from .text import plain_text


def _tc(t: float) -> str:
    m, s = divmod(t, 60)
    return f"{int(m)}:{s:05.2f}"


def rows(ep: Episode) -> list[dict]:
    """One dict per segment with its timed text items."""
    fps = ep.output.fps
    out = []
    for s in ep.segments:
        start = s.start(fps)
        spec = s.spec
        items = []
        lt = spec.get("lower_third")
        if isinstance(lt, dict) and lt.get("title"):
            at, d = float(lt.get("at", 0.5)), float(lt.get("duration", 4.0))
            txt = lt["title"] + (f" / {lt['subtitle']}" if lt.get("subtitle") else "")
            items.append((start + at, start + at + d, "lower third", txt))
        for c in spec.get("captions") or []:
            if isinstance(c, dict) and c.get("text"):
                at, d = float(c.get("at", 0.0)), float(c.get("duration", 0))
                items.append((start + at, start + at + d, f"caption {c.get('style', 'big')}"
                              + (f" {c['position']}" if c.get("position") else ""), plain_text(c["text"])))
        t = s.type
        if t in ("title", "chapter"):
            head = (f"#{spec.get('number')} " if t == "chapter" and spec.get("number") is not None else "") + \
                   str(spec.get("title", "")) + (f" / {spec['subtitle']}" if spec.get("subtitle") else "")
        elif t == "end":
            head = " / ".join(spec.get("lines") or [])
        elif t == "compare":
            head = f"{spec.get('mode', 'split')}: " + " vs ".join(str(x) for x in (spec.get("labels") or ["left", "right"]))
        elif t == "overlay":
            head = "inset " + str((spec.get("inset") or {}).get("label") or (spec.get("inset") or {}).get("src", ""))
        else:
            head = str(spec.get("src", ""))
            if spec.get("speed") not in (None, 1, 1.0):
                head += f"  x{spec['speed']}"
        out.append({"id": s.id, "type": t, "start": start, "end": s.end(fps), "dur": s.duration(fps),
                    "trans": f"{s.trans_in[0]} {s.trans_in[1] / fps:.2f}s" if s.trans_in[1] else "cut" if s.index else "",
                    "head": head, "items": sorted(items)})
    return out


def text_table(ep: Episode) -> str:
    lines = [f"{ep.title}  ({ep.output.width}x{ep.output.height}, {ep.total_seconds:.2f}s)",
             f"{'#':>2} {'segment':<20} {'type':<8} {'start':>8} {'end':>8} {'dur':>6}  {'in':<15} content"]
    for k, r in enumerate(rows(ep)):
        lines.append(f"{k:>2} {r['id']:<20.20s} {r['type']:<8} {_tc(r['start']):>8} {_tc(r['end']):>8} "
                     f"{r['dur']:6.2f}  {r['trans']:<15} {r['head']}")
        for a, b, kind, txt in r["items"]:
            lines.append(f"{'':>2} {'':<20} {'':<8} {_tc(a):>8} {_tc(b):>8} {b - a:6.2f}  {kind:<15} \"{txt}\"")
    return "\n".join(lines)


def markdown_table(ep: Episode) -> str:
    out = [f"| # | segment | type | start | end | dur | transition in | content |",
           "|---|---|---|---|---|---|---|---|"]
    for k, r in enumerate(rows(ep)):
        out.append(f"| {k} | `{r['id']}` | {r['type']} | {_tc(r['start'])} | {_tc(r['end'])} | {r['dur']:.2f} | "
                   f"{r['trans']} | {r['head'].replace('|', '/')} |")
        for a, b, kind, txt in r["items"]:
            out.append(f"| | | | {_tc(a)} | {_tc(b)} | {b - a:.2f} | {kind} | \"{txt.replace('|', '/')}\" |")
    out.append(f"\nTotal: {ep.total_seconds:.2f} s ({ep.total_frames} frames at {ep.output.fps} fps).")
    return "\n".join(out)


def main(argv: Optional[list[str]] = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m devlog_kit.storyboard", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("episode", type=Path)
    ap.add_argument("--markdown", action="store_true", help="emit a Markdown table (for STORYBOARD.md)")
    ap.add_argument("--no-media", action="store_true", help="do not resolve media (footage not rendered yet)")
    a = ap.parse_args(argv)
    try:
        ep = load_episode(a.episode, check_text=False, check_media=not a.no_media)
    except DevlogError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    print(markdown_table(ep) if a.markdown else text_table(ep))
    if ep.errors:
        print(f"\n(note: {len(ep.errors)} validation error(s); run python -m devlog_kit.validate)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
