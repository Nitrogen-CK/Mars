# Material breakdown: water (puddles, wet surfaces, still water with rings) (<= 30 s, 16:9)

What the viewer should leave with: **the water has no textures and no simulation.** A puddle draws its own outline, being
wet is darker colour plus lower roughness, and every ring is timed to the landing of the drop above it by the same clock.
Every on-screen claim is sourced in [FACTS.md](FACTS.md). Manifest: [episode.json](episode.json).

**Re-planned 2026-10-24 against the real Unreal footage** (see *What changed* below). Running time **27.0 s** (810 frames),
0.4 s cross-fades between all segments. Renders: `D:\Repo\Content\Devlog\renders\material_water.mp4` (final),
`material_water_preview.mp4` (960x540 draft), `material_water_contact.png` (12 evenly spaced frames).

| # | Out (s) | Picture (source seconds) | Inset / diagram | Captions (big, output time) | Why it is clever |
|---|---|---|---|---|---|
| T | 0.00-1.50 | Title over a blurred `cistern_rings_wide` frame 90 | - | (card) "Mise en Monstre" / "Material breakdown: water" | - |
| 1 | 1.10-5.50 | `cistern_rings_wide` 0.0-4.4: rings across the still water, lamp glints wobbling; clean for 2 s | - | **top** 3.10-5.10 **No textures.\n*Every ripple is maths.*** | All breakup is hashed per instance and anchored in world space; nothing is painted or sampled. |
| 2 | 5.10-10.10 | wipe `puddle_wet_floor` (Final) -> `puddle_wet_floor_mask` (Base colour), 0.0-5.0, same camera and frozen times | - | bottom 5.50-7.70 **Each puddle *draws its own outline*** / 7.90-9.90 **A *deep core* and a *damp rim*** | One function cuts a faceted, lobed outline from a per-puddle seed and returns two masks; the base-colour pass shows the outline is computed, not painted. |
| 3 | 9.70-16.20 | `wet_layers` full frame, 6.5 s (cards: Stone 0.4, Mask 1.2, Darker 2.0, Glossy 2.8, Ripples 3.6, Rings 4.4 s) | (the diagram is the picture) | bottom 10.30-12.90 **Wet stone: *darker* and far *glossier*** / 13.30-15.70 **Roughness drops from *0.35 to 0.03*** | Wet is two decal layers that never fight: one only darkens the colour, the other only changes normals and roughness. |
| 4 | 15.80-21.30 | `drip_splash_floor` 2.0-7.5 (Leak_VaultLine #1; impacts at beat 0.95, 2.42, 3.76 s); push 1.20 -> 1.26 anchored right so the impact point sits at x 0.4 | `ring_timing`, right, **synced** to the splash shot: same strand, its diamonds land on the footage's impact frames | bottom 16.60-18.80 **Each ring starts *when its drop lands*** / 19.00-21.10 **Spreading at *22 cm/s,*\nlike real ripples** | The ring decal reads the drop's own five numbers and runs the same clock, so ring and drop agree without ever talking. |
| 5 | 20.90-25.90 | `wetstreak_wall` 0.0-5.0 (ceiling, then the ossuary streak's rivulets); push 1.00 -> 1.15 anchored high (0.5, 0.2) so the streak stays in frame while the camera tilts down | - | bottom 21.30-23.50 **Each streak *finds the wall* behind it** / 23.70-25.70 **then *traces its run* down the wall** | A script traces back to the wall behind the actor, then down the wall, and sizes the decal to what it measured. |
| E | 25.50-27.00 | End card | - | "Mise en Monstre" / "Material breakdown: water" | - |

Caption rules held: one idea each, <= 7 words per line, 2 lines max, >= 2.0 s on screen, nothing over the first 2 s of
beat 1, no caption inside a cross-fade (validate: 0 errors, 0 warnings). Big captions stay inside the central 1080 px.

## What changed from the first storyboard, and why

| Change | Reason (footage caveat) |
|---|---|
| **Dropped** the "Base colour vs Normals" wipe and its caption *The colour holds still. Normals move.* | `water_basecolor` is black water (single-layer water gets its colour from absorption, not base colour) and `water_normals` is a flat blue plane: the impact rings are not in the GBuffer normal, and the water's R/G values sit at 0-15 of 255 (they look clamped at 0, so half the slopes are missing). A contrast stretch (tried on frames 0/45/90/135: water R/G std about 4/255, stretched to +-3 sigma) shows only slow swell blobs with 8-bit banding and no rings, so a processed copy would not honestly show "normals move". |
| Beat 3 is now the **full-frame `wet_layers`** diagram instead of `wet_layers_inset` over the puddle footage | Replaces the dropped wipe; the puddle footage already carries beat 2. The full frame was re-laid out to keep everything above y 660 of 900 for bottom captions. |
| Beat 2 right label is **"Base colour"**, not "Mask" | `puddle_wet_floor_mask` is the `SCS_BASE_COLOR` capture (there is no roughness capture source). |
| Rings beat (4) uses `drip_splash_floor`, not `cistern_rings_wide` | Cistern rings are small, sit in the lower third under the caption, and come from six strands; on the splash shot the synced strand lands at the frame centre and its rings are big and clear. |
| Hook caption on **top**, forced line break | The cistern's rings and lamp glints fill the lower half; the break keeps "Every ripple is maths." on one line. |
| Streak caption **Wall streaks trace down to the floor** replaced by **Each streak finds the wall behind it / then traces its run down the wall** | The ossuary Streak_2 in the footage runs about 1.3 m and stops at the first niche row, not the floor. The new captions state only what `Place_Streak` does: a 60 cm trace back to the wall, then a trace down it that sets the length. |
| Captions moved off transitions, all >= 2 s | Clears the earlier "half-faded caption" warnings. |

## Diagrams (`D:/Repo/Content/Devlog/materials/diagrams/`, renderer `Tools/Devlog/footage/diagrams/render_diagrams.py`)

| Shot | Beat | Sync | Command (run from `Tools\Devlog\footage\diagrams`) |
|---|---|---|---|
| `wet_layers` (full) | 3 | none needed (its own puddle, seed 0.55); t0 1.0, 6.5 s | `python -I render_diagrams.py --shot wet_layers --out D:/Repo/Content/Devlog/materials/diagrams --seconds 6.5` |
| `ring_timing` | 4 | t0 = 12.5 + 2.0 = 14.5; strand 349.5155, 0.65742, 0.57824, 0.7, mode 0 (read from the shot.json); impacts at game 15.45, 16.92, 18.26 s | `python -I render_diagrams.py --shot ring_timing --out D:/Repo/Content/Devlog/materials/diagrams --sync D:/Repo/Content/Devlog/materials/unreal/drip_splash_floor/shot.json --offset 2.0 --seconds 5.5` |

`wet_layers_inset` is no longer used (left as rendered).

## Re-render

```
cd D:\Repo\Mars\Tools\Devlog
python -m devlog_kit.validate episodes/material_water/episode.json
python -m devlog_kit.render episodes/material_water/episode.json --out D:/Repo/Content/Devlog/renders/material_water_preview.mp4 --preview
python -m devlog_kit.render episodes/material_water/episode.json --out D:/Repo/Content/Devlog/renders/material_water.mp4
python -m devlog_kit.probe D:/Repo/Content/Devlog/renders/material_water.mp4 --count-frames
```
