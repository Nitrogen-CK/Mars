"""ffprobe-like summary of a media file (imageio-ffmpeg ships no ffprobe).

    python -m devlog_kit.probe <video.mp4> [--count-frames]

Prints JSON: duration, width, height, fps, pix_fmt, codecs, audio presence and (optionally) the frame count.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Optional

from . import DevlogError
from .ffmpeg import probe


def main(argv: Optional[list[str]] = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m devlog_kit.probe", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("file", type=Path)
    ap.add_argument("--count-frames", action="store_true")
    a = ap.parse_args(argv)
    try:
        print(json.dumps(probe(a.file, count_frames=a.count_frames).to_dict(), indent=2))
    except DevlogError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
