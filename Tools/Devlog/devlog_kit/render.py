"""Render an episode manifest to MP4.

    python -m devlog_kit.render <episode.json> --out <file.mp4> [--preview] [--segment <id>] [--dry-run] [--no-cache]

Pipeline: validate -> one intermediate per segment in ``<out>_cache/`` (keyed by a hash of the segment JSON,
the theme, the output settings, the referenced media's sizes/mtimes and the kit's own source) -> one final
pass that chains the intermediates with ``xfade``/``concat``, draws the progress bar, mixes the music and
encodes H.264 (BT.709, yuv420p, +faststart). Re-renders only rebuild segments whose key changed.

Audio: with ``audio.music`` the MP4 carries one AAC 48 kHz stereo track (looped/trimmed to length, gain,
fade in/out); without music the MP4 has **no audio track** (source audio in video clips is ignored).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
import time
from pathlib import Path
from typing import Optional

from . import DevlogError, __version__
from .ffmpeg import THREADS, fpath, probe, run, thread_args
from .manifest import Episode, SegPlan, load_episode
from .segments import Ctx, Graph, build_segment_graph, describe

PKG_DIR = Path(__file__).resolve().parent

#: Intermediate encodes: RGB H.264 (no chroma subsampling until the final pass), visually lossless.
INTERMEDIATE = {"full": ["-c:v", "libx264rgb", "-crf", "12", "-preset", "veryfast"],
                "preview": ["-c:v", "libx264rgb", "-crf", "20", "-preset", "ultrafast"]}


def kit_fingerprint() -> str:
    """Hash of the kit's code and built-in themes, so a kit change invalidates cached segments."""
    h = hashlib.sha1(__version__.encode())
    for p in sorted(list(PKG_DIR.glob("*.py")) + list((PKG_DIR / "themes").glob("*.json"))):
        h.update(p.name.encode())
        h.update(p.read_bytes())
    return h.hexdigest()


def segment_key(ep: Episode, plan: SegPlan, kit: str) -> str:
    """Cache key of one segment's intermediate."""
    o = ep.output
    payload = {
        "spec": plan.spec, "frames": plan.frames, "theme": ep.theme.fingerprint(), "kit": kit,
        "out": [o.width, o.height, o.fps, o.preview],
        "media": {k: [str(m.path), m.stamp, m.fps, m.start] for k, m in sorted(plan.media.items())},
    }
    return hashlib.sha1(json.dumps(payload, sort_keys=True, default=str).encode()).hexdigest()[:12]


def cache_dir_for(out: Path) -> Path:
    return out.with_name(out.stem + "_cache")


def render_segment(ep: Episode, plan: SegPlan, cache: Path, kit: str, *, force: bool = False,
                   dry_run: bool = False, label: str = "") -> Path:
    """Build (or reuse) the intermediate MP4 for ``plan``; returns its path."""
    key = segment_key(ep, plan, kit)
    target = cache / f"{plan.id}_{key}.mp4"
    name = label or f"segment '{plan.id}'"
    if target.is_file() and not force:
        print(f"  {name}: cached ({target.name})")
        return target
    work = cache / f"{plan.id}_{key}"
    if work.exists():
        shutil.rmtree(work, ignore_errors=True)
    work.mkdir(parents=True, exist_ok=True)
    ctx = Ctx(ep, plan, work)
    try:
        g = build_segment_graph(ctx)
    except DevlogError as exc:
        raise DevlogError(f"[segment '{plan.id}'] {exc}") from exc
    except (KeyError, ValueError) as exc:
        raise DevlogError(f"[segment '{plan.id}'] could not build the segment ({type(exc).__name__}: {exc}); "
                          f"run validate for details") from exc
    script = work / "filtergraph.txt"
    script.write_text(g.script(), encoding="utf-8")
    mode = "preview" if ep.output.preview else "full"
    partial = target.with_suffix(".partial.mp4")
    args = [*thread_args(), *g.input_args(), "-/filter_complex", fpath(script), "-map", "[out]",
            "-frames:v", str(plan.frames), *INTERMEDIATE[mode], "-threads", str(THREADS), "-r", str(ep.output.fps),
            "-an", fpath(partial)]
    if dry_run:
        print(f"  {name}: would build {target.name}  [{describe(ctx)}]  graph: {script}")
        return target
    stale = re.compile(rf"^{re.escape(plan.id)}_([0-9a-f]{{12}})(\.mp4|\.partial\.mp4)?$")
    for old in cache.iterdir():
        m = stale.match(old.name)
        if m and m.group(1) != key:  # an older build of this segment
            shutil.rmtree(old, ignore_errors=True) if old.is_dir() else old.unlink(missing_ok=True)
    run(args, label=name, total_seconds=plan.frames / ep.output.fps, log_path=work / "ffmpeg.log")
    partial.replace(target)
    return target


def assemble(ep: Episode, plans: list[SegPlan], files: list[Path], out: Path, cache: Path, *,
             progress_bar: bool, music: bool, dry_run: bool = False) -> int:
    """Chain the intermediates with xfade/concat, add the progress bar and music, and encode ``out``.
    Returns the number of output frames."""
    o = ep.output
    fps, W, H = o.fps, o.width, o.height
    g = Graph()
    labs = []
    for f in files:
        idx = g.add_input(["-i", fpath(f)])
        labs.append(g.add(f"[{idx}:v]", f"setpts=PTS-STARTPTS,fps={fps}"))
    acc, length = labs[0], plans[0].frames
    for p, lab in zip(plans[1:], labs[1:]):
        ttype, tf = p.trans_in
        if tf <= 0:
            acc = g.add([acc, lab], f"concat=n=2:v=1:a=0,fps={fps}")
            length += p.frames
        else:
            acc = g.add([acc, lab], f"xfade=transition={ttype}:duration={tf / fps:.5f}:offset={(length - tf) / fps:.5f}")
            length += p.frames - tf
    total = length / fps
    th = ep.theme
    if progress_bar:
        bh = max(2, th.px(th.get("progress_bar.height", 6)))
        tidx = g.add_input(["-f", "lavfi", "-i", f"color=c={th.ff_color(th.get('progress_bar.track', [0, 0, 0, 0.45]))}"
                                                 f":s={W}x{bh}:r={fps}:d={total + 0.5:.3f}"])
        track = g.add(f"[{tidx}:v]", "format=rgba")
        bidx = g.add_input(["-f", "lavfi", "-i", f"color=c={th.hex(th.get('progress_bar.color', 'accent'))}"
                                                 f":s={W}x{bh}:r={fps}:d={total + 0.5:.3f}"])
        bar = g.add(f"[{bidx}:v]", "format=rgba")
        acc = g.add([acc, track], f"overlay=x=0:y={H - bh}:format=gbrp:eof_action=pass")
        acc = g.add([acc, bar], f"overlay=x='-{W}+{W}*(t+{1 / fps:.5f})/{total:.5f}':y={H - bh}:format=gbrp:eof_action=pass")
    g.add(acc, f"trim=end_frame={length},setpts=PTS-STARTPTS,"
               f"scale=out_color_matrix=bt709:out_range=tv:flags=bicubic+accurate_rnd+full_chroma_int,"
               f"format=yuv420p", "[vout]")
    audio_args: list[str] = []
    if music and ep.music is not None:
        aidx = g.add_input(["-stream_loop", "-1", "-i", fpath(ep.music)])
        fade = max(0.0, min(float(ep.audio.get("fade", 1.0)), total / 2))
        chain = [f"atrim=0:{total:.5f}", "asetpts=PTS-STARTPTS", f"volume={float(ep.audio.get('gain_db', -16)):.2f}dB"]
        if fade > 0:
            chain += [f"afade=t=in:st=0:d={fade:.3f}", f"afade=t=out:st={total - fade:.5f}:d={fade:.3f}"]
        chain += ["aresample=48000", "aformat=channel_layouts=stereo"]
        g.lines.append(f"[{aidx}:a]{','.join(chain)}[aout]")
        audio_args = ["-map", "[aout]", "-c:a", "aac", "-b:a", "192k", "-ar", "48000"]
    script = cache / "final_filtergraph.txt"
    script.write_text(g.script(), encoding="utf-8")
    partial = out.with_name(out.stem + ".partial.mp4")
    args = [*thread_args(), *g.input_args(), "-/filter_complex", fpath(script), "-map", "[vout]", *audio_args,
            "-c:v", "libx264", "-crf", str(o.crf), "-preset", o.preset, "-pix_fmt", "yuv420p", "-profile:v", "high",
            "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-color_range", "tv",
            "-r", str(fps), "-frames:v", str(length), "-threads", str(THREADS), "-movflags", "+faststart",
            "-metadata", f"title={ep.title}", "-t", f"{total:.5f}", fpath(partial)]
    if dry_run:
        print(f"  final: would encode {length} frames ({total:.2f}s) -> {out}  graph: {script}")
        return length
    run(args, label="final encode", total_seconds=total, log_path=cache / "final_ffmpeg.log")
    partial.replace(out)
    return length


def print_issues(ep: Episode) -> None:
    for i in ep.issues:
        print(f"  {i}")


def render(manifest: Path, out: Path, *, preview: bool = False, segment: Optional[str] = None,
           dry_run: bool = False, force: bool = False) -> Path:
    """Render ``manifest`` to ``out`` (see module docstring). Returns ``out``."""
    t0 = time.time()
    ep = load_episode(manifest, preview=preview)
    print(f"devlog_kit {__version__}: {ep.title}  ({ep.output.width}x{ep.output.height} @ {ep.output.fps} fps, "
          f"{'preview' if preview else 'full quality'}, {ep.total_seconds:.2f}s, {len(ep.segments)} segments)")
    if ep.issues:
        print_issues(ep)
    if ep.errors:
        raise DevlogError(f"{len(ep.errors)} error(s) in {manifest}; nothing rendered")
    out = out.resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    cache = cache_dir_for(out)
    cache.mkdir(parents=True, exist_ok=True)
    kit = kit_fingerprint()
    if segment:
        plan = ep.segment(segment)
        f = render_segment(ep, plan, cache, kit, force=force, dry_run=dry_run)
        single = SegPlan(plan.index, plan.id, plan.type, plan.spec, plan.frames, ("none", 0), 0, plan.media)
        assemble(ep, [single], [f], out, cache, progress_bar=False, music=False, dry_run=dry_run)
    else:
        files = []
        for k, plan in enumerate(ep.segments):
            files.append(render_segment(ep, plan, cache, kit, force=force, dry_run=dry_run,
                                        label=f"[{k + 1}/{len(ep.segments)}] segment '{plan.id}'"))
        n = assemble(ep, ep.segments, files, out, cache, progress_bar=ep.output.progress_bar,
                     music=ep.music is not None, dry_run=dry_run)
        if n != ep.total_frames:
            raise DevlogError(f"internal: assembled {n} frames but the timeline says {ep.total_frames}")
    if not dry_run:
        info = probe(out)
        print(f"wrote {out}  {info.width}x{info.height} {info.fps:g} fps {info.pix_fmt} {info.duration:.2f}s "
              f"audio={'yes' if info.has_audio else 'no'}  ({out.stat().st_size / 1e6:.1f} MB, {time.time() - t0:.1f}s)")
    return out


def main(argv: Optional[list[str]] = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m devlog_kit.render", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("episode", type=Path, help="episode manifest (JSON, schema v1)")
    ap.add_argument("--out", type=Path, required=True, help="output .mp4 (cache goes in <out>_cache/)")
    ap.add_argument("--preview", action="store_true", help="960x540, crf 28, preset veryfast")
    ap.add_argument("--segment", metavar="ID", help="render only this segment (no transitions/progress/music)")
    ap.add_argument("--dry-run", action="store_true", help="validate and print the plan; encode nothing")
    ap.add_argument("--no-cache", action="store_true", help="rebuild every segment even if cached")
    a = ap.parse_args(argv)
    try:
        render(a.episode, a.out, preview=a.preview, segment=a.segment, dry_run=a.dry_run, force=a.no_cache)
    except DevlogError as exc:
        print(f"\nERROR: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\ninterrupted", file=sys.stderr)
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())
