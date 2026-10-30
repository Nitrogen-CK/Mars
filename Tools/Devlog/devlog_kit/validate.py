"""Validate an episode manifest: schema, every referenced media path, text fit and duration arithmetic.

    python -m devlog_kit.validate <episode.json> [--preview] [--no-media] [--quiet]

Exit code 0 = no errors (warnings allowed), 1 = errors. Each issue names the segment id and, for media,
the missing path. ``--no-media`` skips every media check (schema, text fit and timing only), for manifests
written before their footage exists. Warnings flag the contract's timing targets (captions >= 2.0 s, <= 7 words per line),
held last frames, captions under transitions and unknown keys (typos).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Optional

from . import DevlogError
from .manifest import Episode, load_episode


def summary(ep: Episode) -> str:
    """One line per segment: id, type, start-end, transition in, media."""
    fps = ep.output.fps
    rows = []
    for s in ep.segments:
        tr = f"<{s.trans_in[0]} {s.trans_in[1] / fps:.2f}s" if s.trans_in[1] else ""
        media = ", ".join(f"{k}:{m.kind}" + (f"[{m.frames}f@{m.fps:g}]" if m.kind == "sequence" else "")
                          for k, m in s.media.items())
        rows.append(f"  {s.index:2d} {s.id:<22.22s} {s.type:<8s} {s.start(fps):7.2f} -> {s.end(fps):7.2f} "
                    f"({s.duration(fps):5.2f}s) {tr:<16s} {media}")
    return "\n".join(rows)


def main(argv: Optional[list[str]] = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m devlog_kit.validate", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("episode", type=Path)
    ap.add_argument("--preview", action="store_true", help="check text fit at preview size")
    ap.add_argument("--no-media", action="store_true",
                    help="schema/text/timing only: do not resolve media paths (footage not rendered yet)")
    ap.add_argument("--quiet", action="store_true", help="print issues only")
    a = ap.parse_args(argv)
    try:
        ep = load_episode(a.episode, preview=a.preview, check_media=not a.no_media)
    except DevlogError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    if not a.quiet:
        print(f"{ep.path}\n  '{ep.title}'  {ep.output.width}x{ep.output.height} @ {ep.output.fps} fps  "
              f"theme={ep.theme.desc}  media_root={ep.media_root}"
              f"{'  (media NOT checked)' if a.no_media else ''}")
        print(summary(ep))
        print(f"  total {ep.total_seconds:.2f}s ({ep.total_frames} frames)"
              f"{'  music=' + str(ep.music) if ep.music else '  (no music: silent, no audio track)'}")
    for i in ep.issues:
        print(f"  {i}")
    n_err, n_warn = len(ep.errors), len(ep.warnings)
    print(f"{'OK' if not n_err else 'FAILED'}: {n_err} error(s), {n_warn} warning(s)")
    return 1 if n_err else 0


if __name__ == "__main__":
    sys.exit(main())
