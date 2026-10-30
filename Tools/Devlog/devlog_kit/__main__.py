"""``python -m devlog_kit`` prints the available sub-commands."""

USAGE = """devlog_kit commands (run from the folder that contains devlog_kit/):
  python -m devlog_kit.render     <episode.json> --out <file.mp4> [--preview] [--segment <id>] [--dry-run] [--no-cache]
  python -m devlog_kit.validate   <episode.json> [--preview] [--no-media]
  python -m devlog_kit.storyboard <episode.json> [--markdown] [--no-media]
  python -m devlog_kit.probe      <video.mp4> [--count-frames]
  python -m devlog_kit.selftest   [--root <dir>] [--out <file.mp4>] [--preview] [--write-episode <episode.json>]
"""

if __name__ == "__main__":
    print(USAGE)
