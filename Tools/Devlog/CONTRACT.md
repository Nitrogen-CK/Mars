# Devlog production contract (v1, 2026-10-24)

Shared rules for everyone producing devlog media for Mars (public title: **Mise en Monstre**). Read fully before
producing a frame. On-screen text may say "Mise en Monstre"; file and folder names stay neutral (`mise_crypt`, `water`).

## Tools (all present on this machine, nothing to install)
- ffmpeg 7.1 (gyan essentials build): `python -c "import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())"`
  -> `C:\Users\Stephen\AppData\Local\Programs\Python\Python310\lib\site-packages\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe`.
  Has drawtext (freetype), overlay, xfade, zoompan, fade, tpad, libx264/libx265, prores, aac. No NVENC (GPU is AMD).
- Python 3.10 at `C:\Users\Stephen\AppData\Local\Programs\Python\Python310\python.exe` with numpy 2.2, Pillow 12.3, imageio-ffmpeg 0.6.
- Blender 5.2 LTS: `"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b --factory-startup --python <script> -- <args>`.
  No live Blender socket is running; work headless. Blender 5.x API gotchas: `C:\Users\Stephen\.claude\skills\blender-mcp\SKILL.md`.
- Unreal: no editor is running. Only ONE hidden editor may run (port 9317), owned by the Unreal agent:
  `python D:\Repo\Mars\Tools\Blender\mars_environment\unreal\env_drive.py --port 9317 --launch` (boot can take 10+ min),
  then `--call` / `--py`, and `--quit` when done. Never touch port 9316 (Stephen's interactive editor).
- Fonts: `C:\Windows\Fonts\bahnschrift.ttf` (UI/captions), `georgia*.ttf` (titles), `consola*.ttf` (code).

## Output format
- 1920x1080, 30 fps, H.264 (libx264, crf 18, preset slow, `-pix_fmt yuv420p`), AAC audio if any. Square pixels.
- Frame sequences: 8-bit PNG, 1920x1080 (or exactly half: 960x540 for drafts), zero-padded `%05d.png` starting at 00000,
  one folder per shot, with a `shot.json` beside it: `{"fps": 30, "frames": N, "real_seconds_covered": X,
  "description": "...", "source": "<script that made it>"}`.
- Captions are **not** burned into source frames. Source frames are clean footage; all text, lower thirds, titles,
  progress bars and diagrams-over-footage are applied by the devlog kit from the episode manifest. (A diagram that IS
  the footage, e.g. an animated graph, is footage and may contain its own axis labels, but no narration captions.)

## Folder layout
```
D:\Repo\Mars\Tools\Devlog\                 (git, Mars)
  CONTRACT.md                              this file
  devlog_kit\                              project-agnostic kit: python -m devlog_kit.render <episode.json> --out <mp4>
  episodes\<episode>\episode.json          one manifest per video (references media by path)
  episodes\<episode>\STORYBOARD.md         beats, timings, caption text, what each shot shows
D:\Repo\Content\Devlog\                    (NOT git; media)
  mise_crypt\blender\<shot>\00000.png ...  Blender making-of footage
  mise_crypt\unreal\<shot>\00000.png ...   Unreal making-of footage
  materials\unreal\<shot>\...              Unreal footage for the material breakdowns
  materials\diagrams\<shot>\...            Pillow/Blender-rendered explainer animations
  renders\<episode>.mp4                    final videos (+ `_preview.mp4` drafts)
```
Every producer also writes a quick preview mp4 of each shot next to its frames (`_preview.mp4`, plain ffmpeg
`-framerate 30 -i %05d.png -c:v libx264 -crf 23 -pix_fmt yuv420p`) and LOOKS at a few frames before calling it done.

## Episode manifest (devlog kit input), schema v1
```json
{
  "version": 1,
  "title": "Building the crypt kit",
  "output": {"width": 1920, "height": 1080, "fps": 30, "crf": 18, "preset": "slow"},
  "theme": "default",
  "media_root": "D:/Repo/Content/Devlog/mise_crypt",
  "transitions": {"default": {"type": "fade", "duration": 0.4}},
  "audio": {"music": null, "gain_db": -16, "fade": 1.0},
  "segments": [
    {"id": "intro", "type": "title", "title": "Mise en Monstre", "subtitle": "Making of: the crypt kit",
     "duration": 3.0, "background": {"src": "unreal/showcase_fly/00120.png", "blur": 8, "darken": 0.5}},
    {"id": "chapter1", "type": "chapter", "number": 1, "title": "Blocking out", "duration": 2.0},
    {"id": "wall4m", "type": "clip", "src": "blender/wall4m_build/%05d.png", "fps": 30,
     "in": 0.0, "out": 20.0, "speed": 2.0,
     "lower_third": {"title": "CryptWall4m", "subtitle": "Blender 5.2, procedural build", "at": 0.5, "duration": 4.0},
     "captions": [{"at": 1.0, "duration": 3.0, "text": "Every piece is built by a script", "style": "big"},
                  {"at": 5.0, "duration": 3.0, "text": "blocks, then bevels", "style": "small", "position": "bottom"}],
     "zoom": {"from": 1.0, "to": 1.08, "anchor": "center"}},
    {"id": "cmp", "type": "compare", "duration": 6.0, "mode": "wipe",
     "left": {"src": "blender/wall4m_raw/%05d.png"}, "right": {"src": "blender/wall4m_painted/%05d.png"},
     "labels": ["Blocked", "Painted"]},
    {"id": "pip", "type": "overlay", "base": {"src": "unreal/cistern_rings/%05d.png"},
     "inset": {"src": "diagrams/drip_clock/%05d.png", "position": "right", "width": 0.42, "margin": 0.04}, "duration": 12.0,
     "captions": [{"at": 0.0, "duration": 4.0, "text": "Every drop is a function of game time", "style": "big"}]},
    {"id": "end", "type": "end", "lines": ["Mise en Monstre", "devlog 01"], "duration": 3.0}
  ]
}
```
Segment types the kit must support: `title`, `chapter`, `clip` (frames `%05d.png` or a video file or a still image),
`compare` (split | wipe | side-by-side), `overlay` (picture-in-picture), `end`. Common fields: `captions[]`,
`lower_third`, `zoom` (slow push), `speed` (timelapse factor, applied to `clip`), `in`/`out` (source seconds),
`duration` (output seconds). Caption `style`: `big` (TikTok-style, centred, bold, boxed, 2 lines max) or `small`
(bottom-third subtitle). `position`: top | center | bottom. `media_root` resolves relative `src`. Theme = fonts,
colours, safe margins (5 % of frame, so a 16:9 export can later be cropped to 9:16 if the centre column holds).
Captions obey the 9:16 safe column: keep `big` text inside the central 1080 px.

## Timing targets
- Material breakdown visualizers: <= 30 s each, 4-6 beats, one idea per caption, caption on screen >= 2.0 s, max 7 words
  per line, 2 lines. Open with the effect for 2 s before the first caption.
- Making-of: 2-4 min total, chapters of 20-45 s. Timelapse speed so that one piece builds in 6-12 s.
