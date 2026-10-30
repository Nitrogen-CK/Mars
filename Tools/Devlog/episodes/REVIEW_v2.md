# Devlog cuts v2: proposed storyboards for review (2026-10-25)

Nothing here is rendered yet. The first cuts over-explained (making-of: 47 captions in 2:45; drips: 10 in 28 s; water: 10
in 27 s). The proposals below cut captions to one idea per beat, let the footage breathe, and swap every Unreal shot for a
re-shoot on the new devlog stage (dark studio backdrop + three-point lighting, matching the Blender frames) once its
stills are approved. Lower thirds (piece name + one fact) stay: they name, they do not explain.

Mark a row `keep`, `cut`, `reword: ...` and send it back; or just say "fine" and only the stage stills gate the renders.

---

## 1. Making of: the crypt kit — 2:45 → about 2:05, 47 captions → 14

| # | beat | footage (speed) | out s | captions (big = B, small = S) |
|---|---|---|---|---|
| T | title | blurred stage still | 4 | card: Mise en Monstre / Making of: the crypt kit |
| 1 | hook | **stage** `room_stage_orbit` (new) | 7 | B "Every stone here was placed by code" |
| C1 | chapter 1 "One wall" | card | 3 | |
| 2 | wall builds | `wall4m_build` 6-170 at 1.5x | 4 | lower third "CryptWall4m · 39 primitives · 0.03 s" |
| 3 | wall stages | `wall4m_build` 171-344 at 0.6x | 9 | S "Bevels, categories, atlas strips: all rules" (one caption for the four stages) |
| 4 | blocked / painted | `wall_raw` ↔ `wall_painted` wipe | 5 | labels only |
| C2 | chapter 2 "Rules, not models" | card | 3 | |
| 5 | ossuary | `ossuary4m_build` 6-155 at 1.5x | 4 | lower third "CryptWallOssuary4m · six niches" |
| 6 | portal | `portal6m_build` 6-161 at 1.5x, dissolve to atlas | 5 | B "Same builder, different rules" |
| 7 | piers | `pier_family` 1x, trimmed to 6 s | 6 | S "One pier, five heights" |
| C3 | chapter 3 "The atlas" | card | 3 | |
| 8 | atlas paints | `atlas_paint` 0-105 at 0.75x | 5 | B "The texture is code too" |
| 9 | atlas passes | `atlas_paint` 106-249 at 0.75x | 6 | S "Height, normals, AO, cavity, paint" |
| 10 | lineup | `kit_lineup` 1x, trimmed to 7 s | 7 | lower third "Crypt_Kit_Library.blend · 116 pieces" |
| C4 | chapter 4 "A room in 12 ms" | card | 3 | |
| 11 | room builds | `room_assembly` 0-310 at 1.4x | 7 | B "One call plans the whole room" |
| 12 | room orbit | `room_assembly` 325-404 at 1x | 3 | B "101 pieces, 12 milliseconds" |
| C5 | chapter 5 "In the engine" | card | 3 | |
| 13 | turntable | **stage** wall + ossuary + portal instances, slow orbit | 6 | lower third "Unreal · HISM instances, world-aligned stone" |
| 14 | six layers | **stage** `material_stages` (base colour → final), 1x, no per-stage captions | 10 | B "Six layers, one material" at the start; a thin stage label strip is optional (say if you want it) |
| 15 | lit vs final | **stage** wipe lit-only ↔ final | 4 | S "A painterly wash over every stone" |
| 16 | room on stage | **stage** octagon room, high 3/4 then head height, warm preset | 7 | none |
| 17 | in the game | one real map shot (`vignette_pan`, sarcophagus crypt) **or cut** | 6 | B "Then the dark does the rest" |
| E | end | card | 4 | Mise en Monstre / devlog 01 |

Cut from v1: "No hand modelling. Just rules and a seed." (restates the hook), all 1/6…6/6 stage narration, "Every face
knows what it is", "Faces snap into atlas strips", "Then the trim sheet goes on", "Ready for bones and candles",
"Jambs first, then eleven voussoirs", "8 m wide, 6 m clear", "Half columns, vertex columns", "Each step: one 4 m
storey", four of the six atlas captions, the atlas-beside-ossuary side-by-side, "Walls, portals, floors, stairs",
"Boxes are the climbing kit", "Vault ribs, then boxes to climb", "Then the kitchen carvings", the Blender-vs-Unreal
room side-by-side, "Vault ribs: paths for ceiling crawlers", "Next: the materials, up close".
Open question: beat 17 keeps one in-game shot so the video ends in the game, not on a stage. Keep or cut?

---

## 2. Material breakdown: drips — 28 s, 10 captions → 5

| # | beat | footage | out s | caption |
|---|---|---|---|---|
| T | title | blurred stage bead still | 1.5 | card |
| 1 | hook | **stage** `drip_bead_macro` | 4.5 | B "No particles. No simulation." (at 2 s) |
| 2 | clock | **stage** bead macro + `drip_clock` inset (synced) | 6 | B "The bead swells until it lets go" |
| 3 | fall | **stage** `drip_strand_side` (strand ~1 m, drops readable) + `fall_curve` inset | 6 | B "Every drop is a formula of time" |
| 4 | slots | `slots_wrap` diagram full frame, trimmed to 4.5 s | 4.5 | B "Four cards per strand, never overlapping" |
| 5 | trace | **stage** `drip_splash_floor` + `strand_trace` inset (synced) | 5 | B "Traced to the floor once, in the editor" |
| E | end | card | 1.5 | |

Cut: "Four cards per strand take turns" (now beat 4's line), "Run it backwards: when does it land?", "A card waits out
its own splash", "Loops every hour without a seam", "Every drop lands exactly on it". Total ≈ 29 s.

---

## 3. Material breakdown: water — 27 s, 10 captions → 5

| # | beat | footage | out s | caption |
|---|---|---|---|---|
| T | title | blurred stage still | 1.5 | card |
| 1 | hook | **stage** still-water basin, rings + reflections | 4.5 | B "No textures. Every ripple is maths." (at 2 s) |
| 2 | puddle outline | **stage** puddles wipe final ↔ base colour | 5 | B "Each puddle draws its own outline" |
| 3 | wet layers | `wet_layers` diagram, trimmed to 5 s (cards: stone, mask, darker, glossy, rings) | 5 | B "Wet is darker and glossier. That's it." |
| 4 | rings | **stage** splash + `ring_timing` inset (synced) | 5.5 | B "Each ring starts when its drop lands" |
| 5 | streak | **stage** wall streak, slow tilt | 4.5 | B "Streaks are traced down the wall" |
| E | end | card | 1.5 | |

Cut: "A deep core and a damp rim", "Roughness drops from 0.35 to 0.03" (the diagram card says it), "Spreading at
22 cm/s, like real ripples", "Each streak finds the wall behind it / then traces its run down the wall". Total ≈ 27.5 s.

---

## What happens after your OK
1. Stage stills approved → re-shoot the Unreal shots on `DevlogStage_Mars_MAP` (same shot names, so the manifests only
   change `media_root` entries), re-sync the three diagrams to the new strands.
2. Render previews of the three cuts, send contact sheets, then finals.
