# Making of: the crypt kit (devlog 01): storyboard

Episode: `episode.json` (schema v1, devlog kit). Output 1920x1080, 30 fps, 2:45.6, silent (no music track),
progress bar on. Footage: `D:\Repo\Content\Devlog\mise_crypt\{blender,unreal}\<shot>\`.

```
cd D:\Repo\Mars\Tools\Devlog
python -m devlog_kit.validate   episodes\mise_crypt_making_of\episode.json
python -m devlog_kit.render     episodes\mise_crypt_making_of\episode.json --out D:\Repo\Content\Devlog\renders\mise_crypt_making_of.mp4
python -m devlog_kit.render     episodes\mise_crypt_making_of\episode.json --out D:\Repo\Content\Devlog\renders\mise_crypt_making_of_preview.mp4 --preview
```

The hook of the whole video is the contrast: the code does in milliseconds (a piece in ~0.03 s, a room plan in 12 ms,
the atlas in 6.5 s) what the footage shows over seconds. Big captions carry the hooks, small captions name stages.

## Chapters

| chapter | output time | length | footage |
|---|---|---|---|
| Cold open | 0:00.0 - 0:13.0 | 13.0 s | title over blurred `showcase_fly` 00170, then `showcase_fly` 1.5-10 s |
| 1 One wall | 0:13.0 - 0:36.5 | 23.5 s | `wall4m_build` (build 1.5x, stages 0.5x), `wall_raw`/`wall_painted` wipe |
| 2 Rules, not models | 0:36.5 - 1:04.6 | 28.1 s | `ossuary4m_build` 1.25x, ossuary wipe, `portal6m_build` 1.25x + paint dissolve, `pier_family` |
| 3 The atlas | 1:04.6 - 1:39.0 | 34.4 s | `atlas_paint` 0.5x, atlas beside the painted ossuary, `kit_lineup` |
| 4 A room in 12 ms | 1:39.0 - 1:58.5 | 19.5 s | `room_assembly` (build 1.25x, orbit 1x), plan vs `rooms_octagon_orbit` side by side |
| 5 Into Unreal | 1:58.5 - 2:40.1 | 41.6 s | `kit_gallery_dolly`, `material_stages` 0.85x + lit/final wipe, `rooms_octagon_orbit` 3-8 s, `vignette_pan` |
| End card | 2:40.1 - 2:45.6 | 5.5 s | blurred `vignette_pan` 00239 |

**Cold open.** Lead with the finished look, not the process: the camera cranes over the showcase plaza and looks down
into the Bellfold nave while two big captions make the claim ("every stone placed by code", "just rules and a seed")
that the rest of the video pays off.

**1 One wall.** One piece, start to finish, slowly enough to read. The blockout drops in at 1.5x under a lower third
carrying the 0.03 s build time; the cut to half speed for the stages (bevel and wobble, face categories, UV strips,
atlas material) gives every captioned stage 2 s or more. The raw/painted wipe closes the loop.

**2 Rules, not models.** Variety from one builder. The ossuary and portal build faster and stop at finished geometry
(the stages were shown on the wall; replaying them fast would flash each by in under half a second); the portal
dissolves straight to its atlas look. The pier family shows the same idea as a size ladder: five heights, half and
vertex columns, each a 4 m storey up.

**3 The atlas.** The texture is code too. The MISE atlas paints strip by strip at half speed so the map passes
(height, normals, AO, cavity, final) each hold about 1.7 s; then the sheet sits beside a piece wearing it, and the
library dolly lands the scale: 116 pieces, one library file.

**4 A room in 12 ms.** The planner: one call lays floor, two tiers of walls, columns, vault ribs, climbing boxes and
the kitchen carvings, then the orbit lands the punchline (101 pieces, 12 milliseconds). The side-by-side bridges to
Unreal: the same planner built the octagon hub in the game's CryptRooms map.

**5 Into Unreal.** The kit as HISM instances in the showcase gallery, then one fixed camera stepping through the six
material layers (base colour, normals, lit, paint wash, fog and glow, final), one caption per 2.35 s stage. The paint
wash is subtle in the footage, so a lit-only/final wipe follows to make the difference visible. The octagon vault and
the sarcophagus vignette close on mood, with a pointer to the next episode.

## Timeline (`python -m devlog_kit.storyboard episode.json --markdown`)

| # | segment | type | start | end | dur | transition in | content |
|---|---|---|---|---|---|---|---|
| 0 | `title` | title | 0:00.00 | 0:05.50 | 5.50 |  | Mise en Monstre / Making of: the crypt kit |
| 1 | `hook` | clip | 0:05.10 | 0:13.60 | 8.50 | fade 0.40s | unreal/showcase_fly/%05d.png |
| | | | 0:06.10 | 0:09.10 | 3.00 | caption big | "Every stone here / was placed by code" |
| | | | 0:09.60 | 0:12.60 | 3.00 | caption big | "No hand modelling. / Just rules and a seed." |
| 2 | `ch1` | chapter | 0:13.00 | 0:16.50 | 3.50 | fadeblack 0.60s | #1 One wall / a 4 m crypt wall, start to finish |
| 3 | `wall_build` | clip | 0:16.10 | 0:19.90 | 3.80 | fade 0.40s | blender/wall4m_build/%05d.png  x1.5 |
| | | | 0:16.40 | 0:19.70 | 3.30 | lower third | "CryptWall4m / 39 primitives, built in 0.03 s" |
| | | | 0:16.50 | 0:19.30 | 2.80 | caption big top | "Every block is / placed by a script" |
| 4 | `wall_stages` | clip | 0:19.90 | 0:31.50 | 11.60 | cut | blender/wall4m_build/%05d.png  x0.5 |
| | | | 0:20.50 | 0:23.40 | 2.90 | caption small | "Bevels, tilt and wobble: / a hand-cut look, no hand edits" |
| | | | 0:23.60 | 0:25.80 | 2.20 | caption small | "Every face knows what it is" |
| | | | 0:26.00 | 0:28.20 | 2.20 | caption small | "Faces snap into atlas strips" |
| | | | 0:28.40 | 0:31.00 | 2.60 | caption small | "Then the trim sheet goes on" |
| 5 | `wall_wipe` | compare | 0:31.10 | 0:37.10 | 6.00 | fade 0.40s | wipe: Blocked vs Painted |
| | | | 0:31.90 | 0:34.30 | 2.40 | caption small | "Same mesh, one material" |
| | | | 0:34.50 | 0:36.50 | 2.00 | caption small | "Atlas plus a painterly wash" |
| 6 | `ch2` | chapter | 0:36.50 | 0:40.00 | 3.50 | fadeblack 0.60s | #2 Rules, not models / one builder, many pieces |
| 7 | `ossuary_build` | clip | 0:39.60 | 0:44.53 | 4.93 | fade 0.40s | blender/ossuary4m_build/%05d.png  x1.25 |
| | | | 0:39.90 | 0:43.30 | 3.40 | lower third | "CryptWallOssuary4m / 45 primitives, six skull niches" |
| | | | 0:40.00 | 0:42.80 | 2.80 | caption big top | "Same builder, / different course rules" |
| 8 | `ossuary_wipe` | compare | 0:44.13 | 0:50.13 | 6.00 | fade 0.40s | wipe: Blocked vs Painted |
| | | | 0:46.73 | 0:49.53 | 2.80 | caption small | "Ready for bones and candles" |
| 9 | `portal_build` | clip | 0:49.73 | 0:54.80 | 5.07 | fade 0.40s | blender/portal6m_build/%05d.png  x1.25 |
| | | | 0:50.03 | 0:52.93 | 2.90 | caption big bottom | "Jambs first, / then eleven voussoirs" |
| 10 | `portal_paint` | clip | 0:54.00 | 0:57.60 | 3.60 | fade 0.80s | blender/portal6m_build/%05d.png  x0.33333 |
| | | | 0:54.80 | 0:57.10 | 2.30 | caption small | "8 m wide, 6 m clear" |
| 11 | `piers` | clip | 0:57.20 | 1:05.20 | 8.00 | fade 0.40s | blender/pier_family/%05d.png |
| | | | 0:57.70 | 0:59.70 | 2.00 | caption big top | "One pier, five heights" |
| | | | 0:59.60 | 1:02.50 | 2.90 | caption small | "Half columns, vertex columns" |
| | | | 1:02.60 | 1:04.60 | 2.00 | caption small | "Each step: one 4 m storey" |
| 12 | `ch3` | chapter | 1:04.60 | 1:08.10 | 3.50 | fadeblack 0.60s | #3 The atlas / one trim sheet, painted by code |
| 13 | `atlas` | clip | 1:07.70 | 1:24.37 | 16.67 | fade 0.40s | blender/atlas_paint/%05d.png  x0.5 |
| | | | 1:08.10 | 1:10.70 | 2.60 | caption big bottom | "The texture is code too" |
| | | | 1:10.80 | 1:12.80 | 2.00 | caption small | "Stone by stone, facet by facet" |
| | | | 1:12.90 | 1:14.90 | 2.00 | caption small top | "Wood, iron and a flat palette" |
| | | | 1:14.90 | 1:16.90 | 2.00 | caption small | "Every stroke is real height" |
| | | | 1:17.10 | 1:21.50 | 4.40 | caption small | "Then normals, AO and cavity" |
| | | | 1:21.80 | 1:23.90 | 2.10 | caption small | "Rim light and grime, painted in" |
| 14 | `atlas_pair` | compare | 1:23.97 | 1:29.97 | 6.00 | fade 0.40s | sidebyside: MISE atlas vs CryptWallOssuary4m |
| | | | 1:24.77 | 1:29.17 | 4.40 | caption small | "One sheet, every stone in the kit" |
| 15 | `lineup` | clip | 1:29.57 | 1:39.57 | 10.00 | fade 0.40s | blender/kit_lineup/%05d.png |
| | | | 1:29.87 | 1:33.37 | 3.50 | lower third | "Crypt_Kit_Library.blend / every SM_ piece, one section per group" |
| | | | 1:29.97 | 1:32.87 | 2.90 | caption big top | "116 pieces, / one library file" |
| | | | 1:33.77 | 1:36.17 | 2.40 | caption small | "Walls, portals, floors, stairs" |
| | | | 1:36.87 | 1:38.87 | 2.00 | caption small | "Boxes are the climbing kit" |
| 16 | `ch4` | chapter | 1:38.97 | 1:42.47 | 3.50 | fadeblack 0.60s | #4 A room in 12 ms / planned by code on a 1 m grid |
| 17 | `room_build` | clip | 1:42.07 | 1:50.40 | 8.33 | fade 0.40s | blender/room_assembly/%05d.png  x1.25 |
| | | | 1:42.27 | 1:45.47 | 3.20 | lower third | "crypt_octagon_16_T2 / 16 x 16 m, octagon hub, two tiers" |
| | | | 1:42.47 | 1:45.27 | 2.80 | caption big top | "One call plans / the whole room" |
| | | | 1:46.32 | 1:48.32 | 2.00 | caption small | "Vault ribs, then boxes to climb" |
| | | | 1:48.37 | 1:50.37 | 2.00 | caption small | "Then the kitchen carvings" |
| 18 | `room_orbit` | clip | 1:50.40 | 1:53.50 | 3.10 | cut | blender/room_assembly/%05d.png |
| | | | 1:50.60 | 1:53.00 | 2.40 | caption big top | "101 pieces, / 12 milliseconds" |
| 19 | `room_unreal` | compare | 1:53.10 | 1:59.10 | 6.00 | fade 0.40s | sidebyside: Planned in Blender vs Octagon hub in Unreal |
| | | | 1:53.90 | 1:57.90 | 4.00 | caption small top | "The same planner builds the game's rooms" |
| 20 | `ch5` | chapter | 1:58.50 | 2:02.00 | 3.50 | fadeblack 0.60s | #5 Into Unreal / instanced, lit and painted |
| 21 | `gallery` | clip | 2:01.60 | 2:09.60 | 8.00 | fade 0.40s | unreal/kit_gallery_dolly/%05d.png |
| | | | 2:02.00 | 2:05.40 | 3.40 | lower third | "CryptShowcase / the kit as HISM instances" |
| | | | 2:02.10 | 2:05.10 | 3.00 | caption big top | "The same pieces, / instanced in Unreal" |
| | | | 2:05.60 | 2:08.70 | 3.10 | caption big top | "Stone materials, / world-aligned" |
| 22 | `material_stages` | clip | 2:09.20 | 2:23.33 | 14.13 | fade 0.40s | unreal/material_stages/%05d.png  x0.85 |
| | | | 2:09.45 | 2:11.45 | 2.00 | caption small | "1/6 Base colour: the atlas, unlit" |
| | | | 2:11.75 | 2:13.75 | 2.00 | caption small | "2/6 Normals: kit maps plus paint detail" |
| | | | 2:14.10 | 2:16.10 | 2.00 | caption small | "3/6 Lit, with no paint wash" |
| | | | 2:16.46 | 2:18.46 | 2.00 | caption small | "4/6 The paint wash fades in" |
| | | | 2:18.81 | 2:20.81 | 2.00 | caption small | "5/6 Fog and glow fade in" |
| | | | 2:21.10 | 2:23.10 | 2.00 | caption small | "6/6 Final: every layer on" |
| 23 | `material_wipe` | compare | 2:22.93 | 2:28.93 | 6.00 | fade 0.40s | wipe: Lit only vs Wash, fog, glow |
| | | | 2:24.13 | 2:27.73 | 3.60 | caption small | "A painterly layer over every stone" |
| 24 | `octagon` | clip | 2:28.53 | 2:33.53 | 5.00 | fade 0.40s | unreal/rooms_octagon_orbit/%05d.png |
| | | | 2:30.43 | 2:33.13 | 2.70 | caption big bottom | "Vault ribs: paths for / ceiling crawlers" |
| 25 | `vignette` | clip | 2:33.13 | 2:41.13 | 8.00 | fade 0.40s | unreal/vignette_pan/%05d.png |
| | | | 2:33.63 | 2:36.83 | 3.20 | caption big top | "Code lays the stones. / Light and paint set the mood." |
| | | | 2:37.23 | 2:39.93 | 2.70 | caption small | "Next: the materials, up close" |
| 26 | `end` | end | 2:40.13 | 2:45.63 | 5.50 | fadeblack 1.00s | Mise en Monstre / devlog 01 · making of the crypt kit |

Total: 165.63 s (4969 frames at 30 fps).
