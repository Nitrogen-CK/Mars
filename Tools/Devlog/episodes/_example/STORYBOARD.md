# _example: devlog_kit self-test episode

`episode.json` here is the manifest that `python -m devlog_kit.selftest` writes and renders. It points at
synthetic footage that the self-test generates (`media_root` is the self-test scratch folder), so render it
only after running the self-test, or regenerate the footage with:

```
cd D:\Repo\Mars\Tools\Devlog
python -m devlog_kit.selftest --root <scratch>\devlog_selftest --out D:\Repo\Content\Devlog\renders\devlog_kit_selftest.mp4 --write-episode episodes\_example\episode.json
```

Output: `D:\Repo\Content\Devlog\renders\devlog_kit_selftest.mp4`, 1920x1080, 30 fps, yuv420p, 29.00 s (870 frames),
with an AAC music bed and the progress bar on. The point of the episode is coverage: every segment type and
feature appears at least once.

## Beats

| # | beat | what the shot shows | what it exercises |
|---|---|---|---|
| 0 | intro | title over a blurred (sigma 8), 50 % darkened still from the build shot, pushing in 1.00 to 1.06 | `title`, background still, blur/darken, staggered fade and rise, accent rule |
| 1 | chapter1 | "01 / Clips and captions" on the theme background | `chapter`, number format, rule growing from the centre, fade transition |
| 2 | build | 360-frame gradient "build" sequence at 2x, slow push 1.00 to 1.08 | `clip` from frames, `in`/`out`, `speed` (timelapse frame dropping), `zoom`, lower third slide, `big` caption with `*accent*` words, `small` caption |
| 3 | wipe | blocked-out wall wiped to the painted wall; the divider sweeps from 10 % to 90 % of the beat | `compare` wipe, 3 px divider, labels that hide and appear with the divider, `wipeleft` transition |
| 4 | split | left half: the painted wall from an MP4; right half: a still of the raw wall | `compare` split, video-file source, still source, `big` caption at `bottom`, `smoothleft` transition |
| 5 | sidebyside | raw and painted walls in two panes with labels | `compare` sidebyside, source-level `in`/`out`, hard cut (`"transition": "none"`) |
| 6 | pip | the build shot with a 960x540 "drip clock" diagram inset (upscaled) on the right | `overlay`: framed inset (rounded corners, shadow, border), inset label, `big` caption at `top` |
| 7 | pip_alpha | the painted wall with the diagram on its own RGBA panel (alpha 240, transparent corners), top-left | alpha inset composited with its own alpha and no kit frame; caption with a forced line break (`\n`) |
| 8 | end | three centred lines | `end`, staggered fades, `fadeblack` transition |

## Timing (output timeline)

| # | segment | type | start | end | dur | transition in | content |
|---|---|---|---|---|---|---|---|
| 0 | `intro` | title | 0:00.00 | 0:03.00 | 3.00 |  | Devlog Kit / Self-test: every segment type |
| 1 | `chapter1` | chapter | 0:02.60 | 0:04.80 | 2.20 | fade 0.40s | #1 Clips and captions / frames, speed, zoom, lower third |
| 2 | `build` | clip | 0:04.40 | 0:10.40 | 6.00 | fade 0.40s | build_a/%05d.png  x2.0 |
| | | | 0:04.80 | 0:08.40 | 3.60 | lower third | "BuildA_Sequence / 360 frames, played at 2x" |
| | | | 0:05.00 | 0:07.60 | 2.60 | caption big | "Every piece is built by a script" |
| | | | 0:07.80 | 0:09.80 | 2.00 | caption small bottom | "blocks, then bevels" |
| 3 | `wipe` | compare | 0:09.90 | 0:14.40 | 4.50 | wipeleft 0.50s | wipe: Blocked vs Painted |
| | | | 0:10.50 | 0:13.10 | 2.60 | caption small | "The divider sweeps left to right" |
| 4 | `split` | compare | 0:13.90 | 0:16.90 | 3.00 | smoothleft 0.50s | split: Video file vs Still image |
| | | | 0:14.40 | 0:16.40 | 2.00 | caption big bottom | "Split: video and still" |
| 5 | `sidebyside` | compare | 0:16.90 | 0:19.90 | 3.00 | cut | sidebyside: Blocked vs Painted |
| 6 | `pip` | overlay | 0:19.50 | 0:24.00 | 4.50 | fade 0.40s | inset drip clock |
| | | | 0:20.00 | 0:23.40 | 3.40 | caption big top | "Every drop keeps time" |
| 7 | `pip_alpha` | overlay | 0:23.60 | 0:27.00 | 3.40 | fade 0.40s | inset diagram_rgba/%05d.png |
| | | | 0:24.00 | 0:26.60 | 2.60 | caption big bottom | "An RGBA inset keeps / its own panel" |
| 8 | `end` | end | 0:26.40 | 0:29.00 | 2.60 | fadeblack 0.60s | Devlog Kit / self-test render / made with devlog_kit |

Total: 29.00 s (870 frames at 30 fps). Regenerate this table with
`python -m devlog_kit.storyboard episodes\_example\episode.json --markdown`.
