# Unreal footage for the devlogs

These are the Unreal shots for the crypt-kit making-of (A) and the water/drip material breakdowns (B). Every shot is
1920x1080 8-bit RGB PNG at 30 fps, numbered `%05d.png` from 00000. Each folder also holds a `shot.json` (contract
fields plus `map`, `frozen_t0`, `camera`, `camera_first`/`camera_last`, `capture_source`, `look` and `visible`) and a
`_preview.mp4`. The frames carry no captions. In-world text is noted per shot.

- (A) `D:\Repo\Content\Devlog\mise_crypt\unreal\<shot>\`
- (B) `D:\Repo\Content\Devlog\materials\unreal\<shot>\`

## How the frames are made

The script is `Tools/Devlog/footage/unreal/devlog_unreal_shots.py`, run inside a hidden MarsEditor on port 9317. The host
runner is `run_shots.py`.

- Each frame is a SceneCapture2D rendered to a render target and exported with `export_render_target`. The host then
  flattens the RGBA export to RGB.
- **Frozen time.** Frame i is rendered with `r.Test.OverrideTimeMaterialExpressions = t0 + i/30`. Drips, splashes,
  rings and flames are closed-form functions of time, so the footage is exactly 30 fps and the same command gives the
  same frames again.
- **Exposure.** Each shot sets manual exposure (`look.ev`) on the capture component, with `capture_every_frame` left on
  so the bias is honoured.
- **Reflections.** For the water shots, the WaterLookdev reflection captures are built in memory before shooting, so the
  cistern water and puddles reflect the authored crypt cubemaps. This build is never saved.
- **Nothing is saved.** Maps open with `EditorLoadingAndSavingUtils.load_map`. `material_stages` uses
  MaterialInstanceDynamics on the nave components and changes the fog density; both are restored after the shot. The
  in-world nave plaques are hidden from the capture only (`hide_actor_components`).

Re-run commands (they launch the hidden editor on 9317, or reuse one already running there):

```
cd D:\Repo\Mars\Tools\Devlog\footage\unreal
python run_shots.py --shot all                 # everything, full res (~20 min, ~0.27 s/frame)
python run_shots.py --shot A | B               # one deliverable
python run_shots.py --shot drip_strand_side    # one shot (comma list ok)
python run_shots.py --shot all --draft         # 960x540, every 10th frame, into the session scratchpad
python run_shots.py --quit                     # quit the hidden editor
```

## (A) Making-of the crypt kit

| shot | frames / s | map | t0 | camera | source |
|---|---|---|---|---|---|
| `showcase_fly` | 300 / 10.0 | CryptShowcase | 12.0 | 6-key Catmull-Rom path (arc-length, eased), look-at spline keyed to it, fov 70, EV 12.5 | final |
| `rooms_octagon_orbit` | 240 / 8.0 | CryptRooms | 12.0 | orbit around the octagon hub's central pier (r 800 to 650 cm, 110 deg), rising 1.7 to 8.5 m, fov 78, EV 13 to 14.2 | final |
| `material_stages` | 360 / 12.0 | CryptShowcase | 12.0 | fixed: eye (400,-900,180), target (800,-1500,250), fov 70, EV 11.9 | base / normal / final, per stage |
| `vignette_pan` | 240 / 8.0 | EnvVignettes | 12.0 | 3.4 m lateral dolly across the sarcophagus concept camera; target moves 0.4x for parallax; fov 60, EV 11.4, 6300 K grade | final |
| `kit_gallery_dolly` | 240 / 8.0 | CryptShowcase | 12.0 | 20 m dolly west along the first gallery row, eye y 560, z 240, fov 62, EV 12.5 | final |

### `showcase_fly`
- **0.0 to 3.5 s:** the kit gallery's wall row: rose-window wall, grille screens, portals and wall courses, with their
  in-world name labels on the floor. Teal sky and the railing behind.
- **3.5 to 6.0 s:** the camera cranes up over the plaza while turning north. The Bellfold nave's south wall and its
  upper gallery come into view.
- **6.0 to 10.0 s:** it clears the wall at about 9 m and looks down into the open-topped nave: the statue on the altar,
  arcades, balustrade galleries and candle shrines. The shot ends on the west arcade, with the statue's edge at the
  right of frame.
- **Caveats:** The nave name plaques and the gallery's big "MISE EN MONSTRE - CRYPT KIT" title are hidden from this
  capture; the gallery's per-piece labels stay. The open nave shows the teal sky because it is a nave slice. Good
  title backgrounds are around frames 00150 to 00200.

### `rooms_octagon_orbit`
- **0.0 to 3.2 s:** the hub at head height: torch-lit walls, doors and windows. The dark central pier sits left of
  centre and slides through the frame.
- **3.2 to 8.0 s:** the camera rises and tilts up into the umbrella vault ribs springing from the pier.
- **Caveats:** The vault is lit only by the wall torches. Exposure ramps up 1.2 EV during the rise, but the top of the
  vault stays dark, with the ribs in silhouette. The biome is Spillring (blue-grey kit), but it reads warm under the
  torches.

### `material_stages`
One fixed camera on the Bellfold nave's south-east arcade: two piers, round arches, the balustrade gallery and a candle
shrine. Six 2 s stages of 60 frames each:

| frames | seconds | stage | what it is |
|---|---|---|---|
| 0-59 | 0-2 | base colour | `SCS_BASE_COLOR`, unlit. PaintStrength = 0 (no paint wash) and emissive = 0 |
| 60-119 | 2-4 | normals | `SCS_NORMAL`, world-space normals (kit normal maps plus the paint detail normal) |
| 120-179 | 4-6 | lit, no wash | `SCS_FINAL_COLOR_LDR`, PaintStrength 0, fog off, emissive 0, bloom 0 |
| 180-239 | 6-8 | wash fading in | PaintStrength eases from 0 to the authored MI value (MiseAtlas / StoneWall / StoneFloor / PlainStone instances) |
| 240-299 | 8-10 | fog and emissive in | Height and volumetric fog density, max opacity and extinction ease from 0 to authored; EmissiveStrength (MiseAtlas) and Strength (Glow_Mars_MI) ease in; bloom 0 to 0.5 |
| 300-359 | 10-12 | final | everything at its authored value |

- **Caveats:**
  - The paint wash is a subtle effect here: the mean per-pixel change from no wash to full wash is about 14/255.
  - Fog and emissive add about 6/255 more, mostly as haze and teal sky in the background.
  - The base-colour stage looks flat because it is unlit, so the piers merge with the walls. It is the same camera.
  - Candle flames use their own materials and are not stepped.
  - There is no roughness stage: `SceneCaptureSource` has no roughness buffer.

### `vignette_pan`
- **0 to 8 s:** EnvVignettes "sarcophagus" room. The carved sarcophagus is centre-frame, with its candle cluster on top
  right, dead leaves on the floor, a pier behind and wall niches to the right. The camera slides left to right.
- **Caveats:** The left third of the frame is dark (the unlit side of the room).

### `kit_gallery_dolly`
- **0 to 8 s:** kit pieces in a row on the paved gallery floor. Each piece has its in-world name and size label at its
  feet ("CryptWallDiag1m4", "CryptWallCourseDiag2m8", "CryptPortal6m"...). The supports row and the railing are behind.
- **Caveats:** The labels are in-world TextRender actors, part of the scene, and they are large near the bottom edge.
  If captions need that area, place them top or centre. The big gallery title is hidden from the capture.

## (B) Water and drips (WaterLookdev_Mars_MAP)

All (B) shots are frozen-time stepped: frame i is at `t0 + i/30`. The drip shots' `shot.json` also has `strand`
(length_cm, rate, seed, jitter, mode, period_s, fall_s, source, impact, read from the DripLeak `CachedStrands` entry
and the actor's Timing / Look) and `camera` (eye, target, fov of frame 0), so the explainer can re-render the drip clock
in sync.

| shot | frames / s | t0 | strand(s) | camera (frame 0) | source |
|---|---|---|---|---|---|
| `drip_strand_side` | 360 / 12.0 | 12.0 | Leak_PipeJoint #0: L 85, rate 1.481, seed 0.7366, jitter 0.4, mode 1 (thread), period 0.675 s, fall 0.365 s | eye (790,62,92), target (520,62,88), fov 38; pushes in to 255 cm | final, EV 10 |
| `drip_bead_macro` | 240 / 8.0 | 12.0 | same strand | 15 cm from the bead: eye (507,69.5,108.7), target (520,62,107.2), fov 35 | final, EV 10.7 |
| `drip_splash_floor` | 240 / 8.0 | 12.5 | Leak_VaultLine #1: L 349.5, rate 0.657, seed 0.578, jitter 0.7, mode 0, period 1.523 s, fall 0.930 s | eye (229,545,78) to (229,535,70), target the impact (229,468,0), fov 50 | final, EV 13 |
| `cistern_rings_wide` | 360 / 12.0 | 12.0 | Leak_CisternA #0-5 (all six in `strands`), L 620 | eye (1530,640,62) to (1515,615,58), target (1365,360,-20), fov 56 | final, EV 12 |
| `water_normals` | 180 / 6.0 | 12.0 | as cistern | identical to `cistern_rings_wide` frames 0-179 | SCS_NORMAL |
| `water_basecolor` | 180 / 6.0 | 12.0 | as cistern | identical to `cistern_rings_wide` frames 0-179 | SCS_BASE_COLOR |
| `puddle_wet_floor` | 240 / 8.0 | 12.0 | (sewer Puddles, 5) | push-in, eye (450,900,150) to (380,790,110), target about (280,600,0), fov 60 | final, EV 12 |
| `puddle_wet_floor_mask` | 240 / 8.0 | 12.0 | same | identical camera and times | SCS_BASE_COLOR |
| `wetstreak_wall` | 240 / 8.0 | 12.0 | ossuary Streak_2 | eye (2570,330,190), tilt target z 330 to 40 on the back wall (x 2570), fov 60 | final, EV 11.3 |

**Frame-aligned pairs for wipes:** `puddle_wet_floor` and `puddle_wet_floor_mask` (240 frames each), and
`water_basecolor`, `water_normals` and `cistern_rings_wide` frames 0-179. Each set shares the same camera function, t0
and frame count.

### `drip_strand_side`
- **0 to 12 s:** the strand seen from the side. The spout is at the top, the warm brick far wall is behind, and the basin
  water is at the bottom, with rings spreading on it.
- The bead hangs at the thread tip about a quarter of the way down the frame. It releases, falls with drag (a short
  streak) and splashes into the basin.
- Releases and impacts (seconds into the shot): 0.57 and 0.93, 1.96 and 2.33, 2.70 and 3.06, 3.32 and 3.69, 3.98 and
  4.34, 4.70 and 5.07, 5.39 and 5.76, 6.17 and 6.53, 7.49 and 7.86, 8.19 and 8.55, 8.67 and 9.04, 9.35 and 9.72,
  10.05 and 10.42, 10.70 and 11.07, 11.51 and 11.87. There is also an impact at 0.24 s, and one jitter-skipped drop
  near 1.3 s (no release).
- **Caveats:** With the strand filling about 80 % of the frame height (85 cm in a 104 cm frame), a falling drop is only
  about 8-10 px wide and 20-30 px long at 1080p. It reads, but it is small. Use `drip_bead_macro` for the detail.

### `drip_bead_macro`
- **0 to 8 s:** the bead on its thread, centre-upper frame, against the dark blue sewer wall. It swells, necks,
  releases (the falling teardrop crosses the lower half for 1-2 frames) and a new bead starts.
- Releases are at the same times as `drip_strand_side` (0.57, 1.96, 2.70, 3.32, 3.98, 4.70, 5.39, 6.17, 7.49 s).

### `drip_splash_floor`
- **0 to 8 s:** looking down at the impact puddle on the sewer floor. This strand hits at 0.29, 1.24, 2.95, 4.42 and
  5.76 s.
- Each impact gives a 1-2 frame fall streak, then the splash crown (about 0.16 s, 5 frames), then a ring expanding at
  22 cm/s for 1.4 s.
- Rings from neighbouring vault-line strands also cross the frame.

### `cistern_rings_wide`
- **0 to 12 s:** low over the cistern's single-layer water. The water reflects the crypt cubemap and the sunk floor reads
  through it. Rings from the six cistern-A strands appear across the surface, about 4 per second.
- The two cold lamp glints in the water (centre) wobble as rings cross them. A brick pier is at the top centre and the
  causeway edge at the left.
- **Caveats:** The drops falling from the 6 m vault are too thin to see at this distance. The shot is about the rings
  and reflections.

### `water_normals` / `water_basecolor`
- **Caveats for `water_normals`:** In the GBuffer normal buffer the water is a near-flat blue plane. Only the slow swell
  noise is there, visible after a contrast stretch (std about 7/255). **The impact rings do not appear in
  `SCS_NORMAL`**, so the ring normals are not in the GBuffer here. For a split-screen they show "flat surface plus
  walls"; diagram the rings themselves from the shader.
- **Caveats for `water_basecolor`:** The water's base colour is black (single-layer water colour comes from absorption
  and scattering, not base colour). The walls and pier show their kit base colour.

### `puddle_wet_floor` / `puddle_wet_floor_mask`
- **0 to 8 s:** sewer floor flagstones with dark wet puddle shapes. Their glossy cores catch the lamps, with a bright
  glint at the upper right. Vault-line drops land in them and spread rings. The camera pushes in slowly.
- **Mask pass:** `SCS_BASE_COLOR` shows the puddles as darker wet patches on grey-brown stone. There is no roughness
  capture source, so this is the closest mask the capture can give.

### `wetstreak_wall`
- **0 to 3 s:** the ceiling and the top courses, with the streak's dark rivulets starting under the ceiling.
- **3 to 6 s:** the rivulets run down two to three brick courses.
- **6 to 8 s:** the ossuary niche rows and the floor.
- **Caveats:** Streak_2 in the ossuary bay ends at the first niche row (about 1.3 m long), not at the floor. The sewer
  bay's Streak_Left is too faint to read under its torch, so the ossuary streak was used. The light is warm and fairly
  flat.

## Not shot / substitutions

- **Bead macro:** the brief suggested a ceiling bead. The vault-line ceiling beads read as rings from below, so the
  macro uses the pipe-joint thread bead (mode 1).
- **Strand side:** this uses the sewer pipe joint (85 cm) rather than the 3 m probe strand. The probe uses a black
  timing-probe material on an emissive board, which is not the real look.
- **Wet streak:** this uses the ossuary Streak_2, as noted above.
