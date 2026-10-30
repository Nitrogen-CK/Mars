# devlog_kit

Assemble devlog videos (a 2-4 minute "making of", <= 30 s vertical-friendly breakdowns) from a JSON
**episode manifest** that references clean footage: PNG frame sequences, video files and stills. The kit adds
every caption, lower third, title/chapter/end card, compare wipe, picture-in-picture inset, transition,
progress bar and music, and encodes an H.264 MP4.

* Python 3.10 standard library + **Pillow** + **numpy** + **imageio-ffmpeg** (for the ffmpeg binary). Nothing
  else, no imports from the host project, no ffprobe needed.
* Text is drawn by Pillow into transparent PNGs (word wrap, boxes, shadows, accent words) and composited with
  ffmpeg `overlay` + `enable='between(t,a,b)'`. `drawtext` is never used.
* Pixels stay RGB from decode to the final pass, so there is exactly one RGB to YUV (BT.709, tv range)
  conversion and the theme colours come out right.

## Drop it into another project

1. Copy the `devlog_kit/` folder anywhere, e.g. `<project>/Tools/Devlog/devlog_kit/`.
2. `pip install pillow numpy imageio-ffmpeg` (any recent versions; tested with Pillow 12.3, numpy 2.2,
   imageio-ffmpeg 0.6 / ffmpeg 7.1). To use another ffmpeg, set `DEVLOG_FFMPEG=<path to ffmpeg>`.
3. Run the commands **from the folder that contains `devlog_kit/`**:

```
python -m devlog_kit.render     <episode.json> --out <file.mp4> [--preview] [--segment <id>] [--dry-run] [--no-cache]
python -m devlog_kit.validate   <episode.json> [--preview] [--no-media] [--quiet]
python -m devlog_kit.storyboard <episode.json> [--markdown] [--no-media]
python -m devlog_kit.probe      <video.mp4> [--count-frames]
python -m devlog_kit.selftest   [--root <dir>] [--out <file.mp4>] [--preview] [--write-episode <episode.json>] [--regen]
```

| command | what it does |
|---|---|
| `render` | Validates, builds one intermediate per segment in `<out>_cache/`, then chains them into `<out>`. `--preview` = 960x540, crf 28, preset veryfast. `--segment ID` renders just that segment (no transitions, progress bar or music) for fast iteration. `--dry-run` validates and prints the plan and filter-graph paths without encoding. `--no-cache` rebuilds every segment. |
| `validate` | Schema, every media path (frame folders, gaps in numbering, video/still files, music), text fit (captions must fit 2 lines at the minimum size), duration arithmetic (in/out vs source length, transitions vs segment lengths, captions vs segment ends). Exit 0 = no errors. `--no-media` checks schema, text and timing only, for manifests written before their footage exists. |
| `storyboard` | Timing table: segment, start, end, duration, transition in, and every caption and lower third on the **output** timeline. `--markdown` emits a table for `STORYBOARD.md`. |
| `probe` | ffprobe-like JSON (size, fps, pix_fmt, duration, audio, frame count) using only ffmpeg. |
| `selftest` | Generates synthetic footage, renders an episode that uses every feature, probes it and extracts check frames. |

Environment: `DEVLOG_FFMPEG_THREADS` (default 4) caps ffmpeg's encoder and filter threads, so renders do not
starve other jobs.

### Caching

Each segment is rendered to `<out>_cache/<segment id>_<hash>.mp4` (RGB H.264, crf 12, near-lossless). The hash
covers the segment's JSON, the resolved theme, the output size/fps/preview flag, the referenced media's frame
count, sizes and mtimes, and the kit's own source code. Re-rendering after a caption edit rebuilds only that
segment, then re-runs the final pass (transitions, progress bar, music, final encode). Stale builds of a
segment are deleted. The cache is safe to delete at any time. `filtergraph.txt` and `ffmpeg.log` beside each
cached segment show exactly what ran.

### Output

`libx264`, crf/preset from `output` (contract: crf 18, preset slow), `yuv420p`, High profile, BT.709 tags,
constant frame rate, `+faststart`.
**Audio:** with `audio.music` set, one AAC 48 kHz stereo 192 kb/s track (the music looped or trimmed to the
video, gain, fade in and out). **Without music the MP4 has no audio track at all**, and audio inside video-file
sources is ignored. (Some platforms like a track; add music, even near-silent, if you need one.)

## Manifest schema v1

Times are seconds. Every segment-local time (`at`) is measured from the segment's own start. Durations are
rounded to whole frames. Keys starting with `_`, and `notes`, `comment` or `description` keys, are ignored.
`validate` warns about any other unknown key, which catches typos.

### Top level

| key | default | meaning |
|---|---|---|
| `version` | required, `1` | schema version |
| `title` | file name | used for logs and MP4 metadata |
| `output.width`, `output.height` | `1920`, `1080` | even numbers. Any aspect works (see 9:16 below) |
| `output.fps` | `30` | constant output frame rate |
| `output.crf`, `output.preset` | `18`, `"slow"` | final libx264 settings (`--preview` forces 28 / veryfast and half size) |
| `output.progress_bar` | `false` | thin accent bar along the bottom edge of the whole video |
| `theme` | `"default"` | a built-in theme name, a path to a theme JSON (relative to the manifest), or an inline object. Partial themes are merged over the default; an inline object may set `"base": "<name or path>"` |
| `media_root` | manifest folder | where relative `src` paths resolve; a relative `media_root` is relative to the manifest |
| `transitions.default` | `{"type": "fade", "duration": 0.4}` | transition into every segment after the first |
| `audio.music` | `null` | music file (wav/mp3/m4a/flac/ogg), relative to `media_root` |
| `audio.gain_db` | `-16` | music gain |
| `audio.fade` | `1.0` | music fade in and out, seconds |
| `segments` | required | the list below, in playback order |

### Transitions

A transition is `{"type": T, "duration": D}`, or just the type as a string. `T` is `fade` (default),
`wipeleft`, `smoothleft`, `fadeblack`, `none` (or `cut`), or any other ffmpeg `xfade` name (`wiperight`,
`slideleft`, `circleopen`, `dissolve`...). A transition overlaps the two segments, so the total length is
`sum(segment durations) - sum(transition durations)`. A segment's `transition` key overrides the default for the
cut **into** that segment. Rules checked by `validate`: a transition must be shorter than both of its segments,
and a segment's incoming plus outgoing transitions must fit inside it.

### Source objects

Wherever media is referenced (a `clip` segment itself; `compare.left` / `.right`; `overlay.base` / `.inset`;
`title`/`chapter`/`end` `.background`) these keys apply. A bare string is shorthand for `{"src": ...}`.

| key | default | meaning |
|---|---|---|
| `src` | required | `folder/%05d.png` (printf frame pattern; the first number is detected, a gap in the numbering is an error), a folder (= `folder/%05d.png`), a video file (`.mp4 .mov .mkv .webm .avi .m4v .gif`) or a still (`.png .jpg .webp ...`) |
| `fps` | `shot.json` `fps` beside the frames, else 30 | frame rate of a sequence's source frames |
| `in` | `0` | source seconds to start at |
| `out` | end of source | source seconds to stop at |
| `speed` | `1` | timelapse factor: `2` plays twice as fast (frames are dropped to keep the output at `output.fps`) |
| `fit` | `contain` (`cover` for backgrounds and opaque insets) | `contain` letterboxes in the theme background, `cover` crops to fill, `stretch` distorts |

`in` and `out` work in every source object, including `base`, `inset`, `left` and `right`, and trim that source
before it is composited. When a source is shorter than the segment, its last frame is held (and `validate`
warns). A segment's `duration` always decides the output length.

### Common segment keys

| key | default | meaning |
|---|---|---|
| `id` | `NN_type` (warned) | unique name, used in errors, cache files and `--segment` |
| `type` | required | `title`, `chapter`, `clip`, `compare`, `overlay` or `end` |
| `duration` | see each type | output seconds |
| `transition` | `transitions.default` | transition into this segment (ignored on the first segment) |
| `captions` | `[]` | list of captions, below |
| `lower_third` | none | `{"title", "subtitle"?, "at": 0.5, "duration": 4.0}` |
| `zoom` | none | slow push `{"from": 1.0, "to": 1.08, "anchor": "center", "ease": "linear"}`. `from`/`to` are in 1..4 (1 = full frame). `anchor` is `center`, `top`, `bottom`, `left`, `right`, `top-left`, `top-right`, `bottom-left`, `bottom-right` or `[x, y]` in 0..1. `ease` is `linear`, `inout`, `in` or `out`. The push is sub-pixel (ffmpeg `perspective`, cubic), not `zoompan`, so it does not jitter. It applies to the clip, to both compare sources (so they stay aligned), to the overlay `base`, and to card backgrounds |

**Caption** keys:

| key | default | meaning |
|---|---|---|
| `text` | required | `*words*` render in the accent colour. A newline (`\n` in JSON, or a literal backslash-n) forces a line break |
| `at` | `0` | start, seconds into the segment |
| `duration` | required | seconds on screen (contract target: >= 2.0) |
| `style` | `big` | `big`: TikTok-style, bold, about 72 px, boxed, at most 2 lines, kept inside the centre 1080 px column, shrinks down to 52 px before failing validation, two lines balanced. `small`: about 44 px subtitle, boxed, at most 2 lines |
| `position` | `center` for big, `bottom` for small | `top`, `center` or `bottom`, inside the 5 % safe margins. A bottom caption whose box would collide with an active lower third is raised above it |

Captions fade in and out over 0.2 s, and `big` rises 16 px as it fades in. `validate` warns about captions shorter
than 2 s, more than 7 words on a line, or more than halfway inside a crossfade.

**Lower third:** an accent bar and slab anchored bottom-left inside the safe margins, with the title in bold
and an optional subtitle in the muted colour. It slides in from the left over 0.35 s, slides out at the end,
and fades over 0.15 s.

### Segment types

| type | keys | duration default |
|---|---|---|
| `title` | `title`, `subtitle`?, `background`? | 3.0 |
| `chapter` | `number`? (int, shown as `01`, or any string), `title`, `subtitle`?, `background`? | 2.0 |
| `clip` | source keys at the segment level (`src`, `fps`, `in`, `out`, `speed`, `fit`) | `(out - in) / speed`, or 4.0 for a still |
| `compare` | `mode`, `left`, `right`, `labels`? `[left, right]`, `sweep`? | 5.0 |
| `overlay` | `base`, `inset` | the base's `(out - in) / speed` |
| `end` | `lines` (list of strings), `background`? | 3.0 |

* **title**: title (Georgia Bold, up to 2 lines), a short accent rule and the subtitle, centred, fading and rising
  in with a stagger. `background` is a source object plus `blur` (Gaussian sigma in 1080p px) and `darken`
  (0..1). It pushes 1.00 to 1.06 unless the segment sets `zoom`. Without a background the card is the theme
  colour.
* **chapter**: accent number, then a thin accent rule that grows from the centre, then the title and an optional
  subtitle. Optional background as for title.
* **clip**: one source, full frame.
* **compare**:
  * `split`: the left half of `left` and the right half of `right`, with a 3 px light divider. Labels sit
    top-left and top-right.
  * `wipe`: starts on `left`. A 3 px light divider sweeps left to right between `sweep[0]` and `sweep[1]` of the
    duration (default `[0.1, 0.9]`) and reveals `right` behind it, so it ends on `right`. The two sources play in
    sync. The `left` label sits top-right and hides as the divider reaches it; the `right` label appears
    top-left once the divider has passed. Read it as before -> after.
  * `sidebyside`: both sources letterboxed into two 16:9 panes with their labels underneath.
* **overlay** (picture in picture): `base` full frame plus an `inset`, a source object with these extra keys:
  * `position` (default `right`): `right`, `left`, `center`, `top-right`, `top-left`, `bottom-right`,
    `bottom-left`. `right`, `left` and `center` are vertically centred.
  * `width` (default 0.42): fraction of the frame width; height follows the source aspect.
  * `margin` (default 0.04): fraction of the frame width from the edges.
  * `label`: optional pill above the inset, or below it when there is no room.
  * `frame`: the kit's own rounded corners, soft shadow and hairline border. Defaults to **true for opaque
    sources and false for sources with real alpha** (an RGBA PNG sequence whose first frame has any pixel
    below 255, or a video with an alpha pixel format). An alpha inset composites with its own alpha, so a
    diagram that draws its own translucent panel gets no second panel or shadow. Set `"frame": true` to add
    the shadow and border anyway; the source's alpha is kept and no rounded mask is applied. Set
    `"frame": false` to show an opaque inset with square corners and no decoration.
  * The inset fades in over 0.3 s.
* **end**: lines centred. The first is in the title font, the rest in the body font, with staggered fade-ins.

## Theme file

`themes/default.json` holds every look decision. All pixel values are authored for a 1080 px tall 16:9 frame
and scaled by `min(width, height) / 1080`. Colours can be `"#rrggbb"`, `"#rrggbbaa"`, `[r, g, b]`,
`[r, g, b, alpha 0..1]` or a name from `colors`.

| section | contents |
|---|---|
| `colors` | `background` #0b0b0f, `text` #f3efe6, `accent` #e0a84a (amber), `secondary` #4aa3e0, `muted`, `shadow` |
| `fonts` | roles: `caption` (Bahnschrift Bold), `caption_light` (Bahnschrift SemiBold), `body` (Bahnschrift Regular), `title` (Georgia Bold), `code` (Consolas). Each role is `{"paths": [...first existing wins...], "variation": "<named instance>"?, "index": 0?}`, with macOS and Linux fallbacks listed. If none exists, Pillow's built-in font is used and `validate` warns |
| `safe_margin` | 0.05 of width and of height |
| `caption` | `fade`, `box` (rgba 0,0,0,0.55), `radius` 24, `shadow`, `accent_markup`, `accent_color`, and per style (`big`, `small`): `font`, `size`, `min_size`, `max_lines`, `column` (max box width; 1080 for big), `padding`, `line_spacing`, `rise`, `default_position` |
| `lower_third` | fonts, sizes, colours, `bar_width`, `padding`, `box`, `radius`, `max_width`, `slide` 0.35, `fade` |
| `title_card`, `chapter_card`, `end_card` | fonts, sizes, colours, rule size and timing, gaps, fade/rise/stagger, `background_zoom` |
| `label` | pill font, size, box, radius, padding, dot colour |
| `inset` | `radius`, `shadow_blur`, `shadow_offset`, `shadow`, `border`, `border_color`, `label_gap` |
| `compare` | `divider_width` 3, `divider_color`, default `sweep`, side-by-side `gap`, `label_fade` |
| `progress_bar` | `height` 6, `color` (accent), `track` (rgba) |
| `zoom` | default `ease` |

To restyle one video, put an inline object in the manifest: `"theme": {"colors": {"accent": "#7fd36b"}}`.
To restyle a project, copy `default.json` to `themes/<name>.json`, edit it, and set `"theme": "<name>"`.

## Worked examples

### 1. A 30 s material breakdown (16:9, vertical-safe captions)

Open on the effect for 2 s, then 4-6 beats with one idea per caption. Captions are `big` and sit at the bottom,
clear of the inset, inside the centre column.

```json
{
  "version": 1,
  "title": "Material breakdown: drips",
  "output": {"width": 1920, "height": 1080, "fps": 30, "progress_bar": true},
  "media_root": "D:/Repo/Content/Devlog/materials",
  "transitions": {"default": {"type": "fade", "duration": 0.4}},
  "segments": [
    {"id": "hook", "type": "clip", "src": "unreal/drip_side/%05d.png", "in": 0, "out": 4.5, "duration": 4.5,
     "captions": [{"at": 2.0, "duration": 2.0, "text": "No particles. *No simulation.*"}]},
    {"id": "fall", "type": "overlay", "duration": 6,
     "base": {"src": "unreal/drip_side/%05d.png", "in": 4, "out": 10},
     "inset": {"src": "diagrams/fall_curve/%05d.png", "position": "right", "width": 0.42, "label": "height(t)"},
     "captions": [{"at": 0.3, "duration": 2.7, "text": "Each drop is a *formula of time*", "position": "bottom"},
                  {"at": 3.0, "duration": 2.8, "text": "Run it backwards:\nwhen does it land?", "position": "bottom"}]},
    {"id": "mask", "type": "compare", "mode": "wipe", "duration": 5,
     "left": {"src": "unreal/puddle_final/%05d.png"}, "right": {"src": "unreal/puddle_mask/%05d.png"},
     "labels": ["Final", "Mask"], "transition": "wipeleft",
     "captions": [{"at": 0.4, "duration": 2.4, "text": "Each puddle draws its own outline", "position": "bottom"}]},
    {"id": "macro", "type": "clip", "src": "unreal/bead_macro/%05d.png", "speed": 0.5, "duration": 6,
     "zoom": {"from": 1.0, "to": 1.12, "anchor": [0.55, 0.4]},
     "captions": [{"at": 0.4, "duration": 2.6, "text": "The bead swells until it lets go"},
                  {"at": 3.2, "duration": 2.4, "text": "Four cards per strand take turns", "style": "small"}]},
    {"id": "end", "type": "end", "lines": ["Mise en Monstre", "Material breakdown: drips"], "duration": 2.0,
     "transition": {"type": "fadeblack", "duration": 0.6}}
  ]
}
```

Length: 4.5 + 6 + 5 + 6 + 2 - (0.4 + 0.4 + 0.4 + 0.6) = 21.7 s. Check it with `storyboard`.

### 2. A 3 minute making-of

Chapters of 20-45 s, each a chapter card followed by timelapse clips. Use `speed` so that one piece builds in
6-12 s, and a lower third the first time each asset appears.

```json
{
  "version": 1,
  "title": "Building the crypt kit",
  "output": {"width": 1920, "height": 1080, "fps": 30, "crf": 18, "preset": "slow", "progress_bar": true},
  "media_root": "D:/Repo/Content/Devlog/mise_crypt",
  "transitions": {"default": {"type": "fade", "duration": 0.5}},
  "audio": {"music": "music/crypt_theme.mp3", "gain_db": -18, "fade": 2.0},
  "segments": [
    {"id": "intro", "type": "title", "title": "Mise en Monstre", "subtitle": "Making of: the crypt kit",
     "duration": 4, "background": {"src": "unreal/showcase_fly/00120.png", "blur": 8, "darken": 0.5}},
    {"id": "ch1", "type": "chapter", "number": 1, "title": "Blocking out", "duration": 2.5},
    {"id": "wall4m", "type": "clip", "src": "blender/wall4m_build/%05d.png", "in": 0, "out": 40, "speed": 4,
     "lower_third": {"title": "CryptWall4m", "subtitle": "Blender 5.2, procedural build", "at": 0.5, "duration": 4},
     "captions": [{"at": 1.0, "duration": 3.0, "text": "Every piece is *built by a script*"},
                  {"at": 5.0, "duration": 3.0, "text": "blocks, then bevels", "style": "small"}],
     "zoom": {"from": 1.0, "to": 1.06}},
    {"id": "arch", "type": "clip", "src": "blender/arch_build/%05d.png", "speed": 5, "duration": 9,
     "lower_third": {"title": "CryptArch", "at": 0.5, "duration": 3.5}},
    {"id": "ch2", "type": "chapter", "number": 2, "title": "Paint and wear", "duration": 2.5},
    {"id": "paint", "type": "compare", "mode": "wipe", "duration": 7,
     "left": "blender/wall4m_raw/%05d.png", "right": "blender/wall4m_painted/%05d.png",
     "labels": ["Blocked", "Painted"]},
    {"id": "ch3", "type": "chapter", "number": 3, "title": "Into Unreal", "duration": 2.5},
    {"id": "showcase", "type": "clip", "src": "unreal/showcase_fly/%05d.png", "duration": 20,
     "captions": [{"at": 2, "duration": 3, "text": "76 pieces, one material"}]},
    {"id": "end", "type": "end", "lines": ["Mise en Monstre", "devlog 01", "thanks for watching"], "duration": 4,
     "transition": {"type": "fadeblack", "duration": 1.0}}
  ]
}
```

Iterate with `render ... --preview` (half size, fast), fix a single beat with `--segment wall4m`, and run the full
quality render once at the end. The cache keeps untouched segments.

### 3. A 9:16 variant

Two ways to get a vertical video:

* **Crop the finished 16:9.** `big` captions stay inside the centre 1080 px column of a 1920 px frame. For a
  strict crop of the full 1080 px height (a 608 px wide column), set the theme's `caption.big.column` to about
  560 so captions survive, then:
  `ffmpeg -i ep.mp4 -vf "crop=ih*9/16:ih,scale=1080:1920:flags=lanczos" -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a copy ep_9x16.mp4`.
  A square 1080x1080 centre crop (placed in a 1080x1920 frame over a blurred copy of itself) keeps every `big`
  caption with the default theme. Lower thirds and compare labels sit near the 16:9 edges and are lost in any crop, so give a
  vertical cut its own captions instead.
* **Render natively.** Copy the manifest and set `"output": {"width": 1080, "height": 1920}`. Layout scales by
  `min(w, h) / 1080`, safe margins follow the frame, and `big` captions are capped at the frame width minus
  margins. Set `"fit": "cover"` on 16:9 sources so they fill the tall frame (centre crop), and use `zoom` with an
  `anchor` to frame the subject. `contain` letterboxes them in the theme colour instead.

## Self-test

```
python -m devlog_kit.selftest --root <scratch dir> --out <renders>/devlog_kit_selftest.mp4 --write-episode episodes/_example/episode.json
```

The self-test generates synthetic frame sequences (a gradient "build" shot, raw and painted brick walls, a
self-drawing diagram, the same diagram on its own RGBA panel), a video file, stills and a music bed. It renders
a 29 s episode with every segment type, both caption styles, accent markup, a forced line break, a lower third,
zoom, a wipe, split and side-by-side compare, a framed PiP and an alpha PiP, a cut, fade, wipeleft, smoothleft
and fadeblack transitions, the progress bar and music. It then checks size, fps, pix_fmt, frame count, duration
and audio, and extracts evenly spaced frames to `<root>/check/` for a visual check.

## Module map

`manifest.py` (schema, defaults, validation, timeline) - `media.py` (sources) - `theme.py` (themes, colours,
fonts) - `text.py` (Pillow rendering) - `segments.py` (per-segment ffmpeg graphs) - `render.py` (cache, xfade
assembly, encode) - `ffmpeg.py` (binary, runner, probe) - `validate.py`, `storyboard.py`, `probe.py`,
`selftest.py` (CLIs).
