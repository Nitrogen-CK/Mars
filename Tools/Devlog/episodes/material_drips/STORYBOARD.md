# Material breakdown: drips and droplets (<= 30 s, 16:9)

What the viewer should leave with: **nothing in a Mars drip is simulated.** Every drop, bead, splash and ring is a formula
of game time inside the material; a script only measures each strand once, in the editor. Every on-screen claim is
sourced in [FACTS.md](FACTS.md). Manifest: [episode.json](episode.json).

**Re-planned 2026-10-24 against the real Unreal footage** (see *What changed* below). Running time **28.0 s** (840 frames),
0.4 s cross-fades between all segments. Renders: `D:\Repo\Content\Devlog\renders\material_drips.mp4` (final),
`material_drips_preview.mp4` (960x540 draft), `material_drips_contact.png` (12 evenly spaced frames).

| # | Out (s) | Picture (source seconds) | Inset / diagram | Captions (big, output time) | Why it is clever |
|---|---|---|---|---|---|
| T | 0.00-1.50 | Title over a blurred `drip_bead_macro` frame 60 | - | (card) "Mise en Monstre" / "Material breakdown: drips" | - |
| 1 | 1.10-5.50 | `drip_bead_macro` 0.0-4.4: the hook. Bead swells and lets go at 0.57, 1.96, 2.70, 3.32, 3.98 s; clean for 2 s | - | bottom 3.10-5.10 **No particles. *No simulation.*** | Drops are 4 cards per strand that the vertex shader moves; nothing ticks. |
| 2 | 5.10-11.10 | `drip_bead_macro` 2.0-8.0 (releases at beat 0.70, 1.32, 1.98, 2.70, 3.39, 4.17, 5.49 s) | `drip_clock`, right, 0.40 wide, **synced** to the macro: same strand (85 cm thread), playhead = game time 14.0 + beat time | bottom 5.50-8.00 **The bead swells *until it lets go*** / 8.20-10.60 ***Four cards* per strand take turns** | The bead's size is read off the same clock as the drops, so it lets go exactly when the next drop starts; the inset's fall curve starts on the frame the footage bead detaches. |
| 3 | 10.70-16.70 | `drip_strand_side` 1.0-7.0: the whole 85 cm pipe-joint strand, drops into the basin (impacts at beat 1.33, 2.06, 2.69, 3.34, 4.07, 4.76, 5.53 s) | `fall_curve`, right, label pill "Example: a 3.5 m strand" (self-timed, half speed) | **top** 11.10-13.50 **Each drop is a *formula of time*** / 13.70-16.20 **Run it backwards:\n*when does it land?*** | Drag fall has an exact closed form and an exact inverse: the shader knows a drop's landing time without stepping anything. |
| 4 | 16.30-21.80 | `slots_wrap` full frame (the diagram is the picture) | - | bottom 16.70-19.20 **A card waits out *its own splash*** / 19.50-21.50 **Loops every hour *without a seam*** | Drop k rides card k mod 4; the period is stretched so a card is free before its next drop, and the 3600 s wrap holds a multiple of 4 drops. |
| 5 | 21.40-26.90 | `drip_splash_floor` 0.5-6.0 (Leak_VaultLine #1, 349.5 cm; impacts at beat 0.74, 2.45, 3.92, 5.26 s); push 1.20 -> 1.26 anchored right edge so the impact point (frame centre) sits at x 0.4, left of the inset | `strand_trace`, right, **synced** to the splash shot: same strand; phase 4 (live drops) from beat 3.04 s, its drop lands at beat 3.92 s with the footage's | bottom 21.80-24.00 **Each strand is *traced to the floor*** / 24.50-26.70 **Every drop *lands exactly* on it** | The script traces up to the vault and down to the floor once, packs the length into per-instance custom data, and the fall formula ends exactly at that length. |
| E | 26.50-28.00 | End card | - | "Mise en Monstre" / "Material breakdown: drips" | - |

Caption rules held: one idea each, <= 7 words per line, 2 lines max, >= 2.0 s on screen, nothing over the first 2 s of
beat 1, no caption inside a cross-fade (validate: 0 errors, 0 warnings). Big captions stay inside the central 1080 px.
Insets sit on the right, vertically centred, clear of every caption.

## What changed from the first storyboard, and why

| Change | Reason (footage caveat) |
|---|---|
| Hook is `drip_bead_macro`, not `drip_strand_side` | In `drip_strand_side` the 85 cm strand fills 80 % of the frame height, so a falling drop is about 8-10 px wide and the thread almost vanishes against the dark brick. The macro (15 cm from the bead) reads instantly. |
| Clock beat moved to beat 2, right after the hook, on macro 2.0-8.0 | It continues the hook's subject. The 2.4 s overlap with the hook's footage is invisible (the bead cycle repeats every 0.68 s). |
| Fall beat (beat 3) keeps `drip_strand_side` but puts its captions on **top** | The basin splash is at the frame bottom (y about 980 px); a bottom caption hid every landing. The inset is labelled "Example: a 3.5 m strand" because `fall_curve` plots the 350 cm example, not the 85 cm footage strand (whose drag barely shows). |
| Trace beat (beat 5) uses `drip_splash_floor` 0.5-6.0 with a right-anchored push | The vault-line strand really is traced up (placed at z 300, its source attached to the vault at z 349) and down to the floor, so every phase of `strand_trace` is true of it; the pipe-joint strand has `attach_up` off. The push moves the impact point out from under the inset. |
| `drip_clock`, `strand_trace` re-rendered with the footage strands | They now replay the exact releases and impacts of the frames under them (checked at full resolution: crown and first ring land on the same frame in footage and inset). |
| `slots_wrap` re-laid out | Its legend and "One loop" line sat under a 2-line bottom caption; everything is now above y 660 of 900. |
| Captions moved off transitions, all >= 2 s | Clears the earlier "half-faded caption" warnings. |

## Diagrams (`D:/Repo/Content/Devlog/materials/diagrams/`, renderer `Tools/Devlog/footage/diagrams/render_diagrams.py`)

| Shot | Beat | Sync | Command (run from `Tools\Devlog\footage\diagrams`) |
|---|---|---|---|
| `drip_clock` | 2 | t0 = 12.0 + 2.0 = 14.0; strand 85, 1.48133, 0.73664, 0.4, mode 1 (read from the shot.json) | `python -I render_diagrams.py --shot drip_clock --out D:/Repo/Content/Devlog/materials/diagrams --sync D:/Repo/Content/Devlog/materials/unreal/drip_bead_macro/shot.json --offset 2.0 --seconds 6` |
| `fall_curve` | 3 | none (self-timed explainer, 350 cm example strand, half speed) | unchanged: `python -I render_diagrams.py --shot fall_curve --out D:/Repo/Content/Devlog/materials/diagrams` |
| `slots_wrap` | 4 | none (its own 12 m strand at 2 /s) | `python -I render_diagrams.py --shot slots_wrap --out D:/Repo/Content/Devlog/materials/diagrams` |
| `strand_trace` | 5 | t0 = 12.5 + 0.5 = 13.0; strand 349.5155, 0.65742, 0.57824, 0.7, mode 0 | `python -I render_diagrams.py --shot strand_trace --out D:/Repo/Content/Devlog/materials/diagrams --sync D:/Repo/Content/Devlog/materials/unreal/drip_splash_floor/shot.json --offset 0.5 --seconds 5.5` |

`--sync` with no `--strand` now reads the footage strand (length, rate, seed, jitter **and mode**) from the shot.json.

## Re-render

```
cd D:\Repo\Mars\Tools\Devlog
python -m devlog_kit.validate episodes/material_drips/episode.json
python -m devlog_kit.render episodes/material_drips/episode.json --out D:/Repo/Content/Devlog/renders/material_drips_preview.mp4 --preview
python -m devlog_kit.render episodes/material_drips/episode.json --out D:/Repo/Content/Devlog/renders/material_drips.mp4
python -m devlog_kit.probe D:/Repo/Content/Devlog/renders/material_drips.mp4 --count-frames
```
