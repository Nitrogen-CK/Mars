"""devlog_kit: assemble devlog videos from a JSON episode manifest.

Project-agnostic: depends only on the Python 3.10 standard library, Pillow, numpy and
imageio-ffmpeg (for the ffmpeg binary). Copy this folder next to any project and run
``python -m devlog_kit.render <episode.json> --out <file.mp4>`` from its parent folder.

Modules:
    render      CLI: build the MP4 (per-segment cache, xfade assembly, progress bar, music).
    validate    CLI: schema + media + duration arithmetic checks.
    storyboard  CLI: timing table (segment, start, end, captions).
    probe       CLI: ffprobe-like summary of a video file (ffprobe is not shipped by imageio-ffmpeg).
    selftest    CLI: synthetic footage + an episode exercising every feature.
    manifest    loading, defaults, timeline arithmetic, validation.
    media       source resolution (frame sequences, video files, stills).
    theme       theme loading/merging and font resolution.
    text        Pillow renderers for captions, lower thirds, cards, labels, inset frames.
    segments    per-segment ffmpeg filter-graph builders.
    ffmpeg      ffmpeg binary resolution, process runner with progress, media probing.
"""

__version__ = "1.0.0"
SCHEMA_VERSION = 1


class DevlogError(Exception):
    """A user-facing error. The message names the segment id and the offending path where relevant."""
