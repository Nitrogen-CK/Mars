# Devlog stage (DevlogStage_Mars_MAP)

A dark-studio lookdev map for devlog renders, built to match the Blender making-of frames: a dark backdrop, a dark floor
with a faint 1 m grid, a warm key, a cool rim and a soft fill, and manual exposure. It is used only for devlog renders.

- Builder (editor side): `mars_devlog_stage_ue.py`. It imports `devlog_unreal_shots.py` for the capture rig and the
  camera maths.
- Host runner: `run_stage.py`. It drives a hidden MarsEditor on port 9317 and never touches 9316.
- Map: `/Game/Mars/Maps/DevlogStage_Mars_MAP` (+ `_BuiltData`).
- Assets: `/Game/Mars/Devlog/Materials/`
  - `DevlogBackdrop_Mars_M` / `_MI`
  - `DevlogFloor_Mars_M` / `_MI`
  - `DevlogSurface_Mars_M` and its instances: `DevlogGrey18`, `DevlogChrome`, `DevlogCounter`
  - `DevlogCounterStone_Mars_MI`, a child of `StoneFloor_Spillring_Mars_MI` (`Tint` 0.33, `TileMetres` 1.5 x 1.3, no
    paint wash)
  - `DevlogPanA_Mars_MI` and `DevlogPanB_Mars_MI`, children of `Pan_Steel_Mars_MI`
- No cooking or kit master was rebuilt or edited. Only new instances were created.

## Rebuild / stills

```
cd D:\Repo\Mars\Tools\Devlog\footage\unreal
python run_stage.py --build                        # assets + map (idempotent), then builds and saves the reflection captures
python run_stage.py --build --bays cooking         # rebuild one bay (only its DevlogStage.<bay> actors are replaced)
python run_stage.py --stills                       # 15 review stills -> D:\Repo\Content\Devlog\stage_review\ + stats + contact sheets
python run_stage.py --stills --only cook_trio,room_head
python run_stage.py --stills --draft               # 960x540, into the session scratchpad drafts/
python run_stage.py --calibrate                    # 18 % grey + chrome probe close-ups per bay (+ stats)
python run_stage.py --call "st.resolve('cook_34')" # any editor-side call (st = the stage module)
python run_stage.py --quit
```

The runner launches the hidden editor if nothing is listening on 9317 (boot about 1-10 min). Each still is two Monolith
calls:

1. `st.prepare_still(name)` sets the state: subject, cube arrangement, CPD, pan parameters, rig aim, material stage and
   fog.
2. `st.capture_still()` renders in the next call, because those changes only reach the renderer after an editor tick.

Stills render at 3840x2160 and the host downsamples them to 1920x1080 (Lanczos). This is the anti-aliasing, because the
project runs `r.AntiAliasingMethod=0`. Water and time-driven materials use frozen time: `t` per shot, default 12.0 s,
through `r.Test.OverrideTimeMaterialExpressions`. Every still's resolved camera (eye, target, fov, t, ev, preset, state)
is appended to `stage_review/stage_shots.json`. That file is the hand-off for the video re-shoot.

## Layout (Unreal cm)

The bays sit 300 m apart along X. Every camera stands on its bay's +Y side, and the fog dissolves anything farther than
about 60-150 m into the backdrop.

| bay | origin | content | default preset | reflection capture |
|---|---|---|---|---|
| env | floor centre (30000, 0) | 2 km floor plane (grid instance, z -0.3), 2 km-radius unlit backdrop sphere, height fog, unbound grade volume | - | - |
| `turntable` | (0, 0) | kit subjects on the grid, one visible at a time: `wall4m`, `wall_ossuary`, `portal6m`, `pier_family` (5 piers + 4 vertex columns + 4 half columns) | neutral | sphere r 1600, CookingStudio HDR, 0.3 |
| `cooking` | (30000, 0) | stone counter 180 x 90 x 90 (hob height 90); hero pan A at (-22, 2) yaw 32 with three meat cubes; pan B at (34, -14) with `Drumstick_Mars_SM` (seared); `Tentacle_Mars_SM` (raw) and `RoastHorned_Mars_SM` (seared) on the counter | neutral | sphere r 400, CookingStudio HDR, 0.85 |
| `room` | (60000, 0) | `crypt_octagon_hub` plan as one HISM actor via `mise_mars_ue.spawn_room` (Bellfold); roof, grilles and the third wall tier (z >= 8 m) cut away, ribs / vertex columns / central pier kept; a slab under the open-jointed paver strip; 8 `TorchSconce_A` torches (26 cd) + 4 upper wall lights from the plan's warm lights | warm | sphere r 2400, CryptWarm HDR, 0.5 |

Every actor is tagged `DevlogStage` + `DevlogStage.<bay>`; lights also `DevlogStage.<bay>.<key|rim|fill|practical>`.
Each bay has hidden probes (`DevlogStage.<bay>.probe`: 18 % grey + chrome balls) that only `calibrate()` shows.

## Look

- **Exposure:** one stage EV, `STAGE_EV` = 10, for every bay (the exposure bias of the capture and of the grade
  volume). Bays are balanced with light, not exposure. Shots may offset it (`ev`); the macro uses -1.6.
- **Tonemapper:** toe 0.32 instead of 0.55. At 0.55 everything below about 0.1 crushed to black; 0.32 is close to the
  Blender Filmic shadows.
- **Grade:** bloom 0.12, vignette 0.22, saturation 0.92-1.0. No SSGI (the project default is screen-space GI), no Lumen
  reflections, no grain, fringe or flares.
- **Backdrop and floor:** colours go through `EyeAdaptationInverse`, so they are display-referred and do not change with
  exposure.
  - Floor `FloorGlow` (0.128, 0.124, 0.142) reads about (26, 25, 30), the same as Blender.
  - Grid lines: 1.8 cm wide, 1 m cells, anti-aliased (Golus "pristine grid").
  - The floor is lit (albedo 0.02, specular 0), so it takes contact shadows and a faint key pool.
- **Fog:** the fog is the horizon. Density 0.3, near-zero height falloff. Luminance (0.105, 0.105, 0.124) at EV 10, which
  reads about (20-23, 20-22, 25-27), the Blender #15151a. Each still starts the fog just behind its subject
  (`fog_start` = distance + 1.2 x radius) for a touch of depth, then restores 60 m.
- **Rig:** three movable spot lights per bay, re-aimed for every shot relative to that shot's camera azimuth (`RIG`, with
  per-bay overrides in `BAYS`):
  - key: 38 deg camera-left, 42 deg up
  - rim: behind, camera-right
  - fill: camera-right, low, large and soft, no shadows
  - Source radius scales with the subject.

**Presets** (`PRESETS`, applied by `fit_rig(bay, centre, radius, preset, cam_az)`):

| preset | key / rim / fill | key at subject | rim | fill | practicals | use |
|---|---|---|---|---|---|---|
| `neutral` | warm-white / cool / neutral-cool | 12.5 lux | x1.4 | x0.22 | off | Blender match: turntable, cooking |
| `warm` | amber / cool-teal / amber | 9 lux | x1.2 | x0.18 | on | room and crypt moods |
| `cool` | cool-white / cyan / blue | 9 lux | x1.6 | x0.2 | off | water (bay not built) |

## Shot presets (`SHOTS`)

Cameras are solved from the subject's bounds by `frame()` (azimuth, elevation, fov, height fill). `resolve(name)` returns
the eye, target and fov.

| name | bay / subject | view |
|---|---|---|
| `tt_wall4m` (+ `_normals`, `_base`, `_nowash`) | turntable `wall4m` | 3/4 from front-right, 25 deg, fov 42 (about 50 mm), fill 0.78 |
| `tt_wall_ossuary` | `wall_ossuary` | front-left, 22 deg, fov 42 |
| `tt_portal6m` | `portal6m` | 22 deg, fov 45 |
| `tt_pier_family` | `pier_family` | 14 deg (horizon in frame, as in Blender), fov 50 |
| `cook_top60` | pan A bowl | **top-down 60 deg**, fov 40, fill 0.8 |
| `cook_34` | pan A bowl | **three-quarter 30 deg**, fov 40 |
| `cook_cube` | cube 0 + its oil | 30 deg, fov 35 |
| `cook_pool_top` | the oil pool | 60 deg, fov 35 |
| `cook_oil_macro` | cube 0 | **oil macro**: 30 cm away (above the 18 cm minimum for the 10 cm near clip), 36 deg, fov 34, EV -1.6, Sizzle 1 |
| `cook_wide` | whole counter | 24 deg, fov 40 (rig widened to radius 150) |
| `room_high34` | octagon | high 3/4, 46 deg, fov 44, fill 0.92 |
| `room_head` | inside | eye 1.7 m near the S door looking N past the pier, fov 62 |

Shot options:
- `spin` (turntable rotation, deg; the subject turns, the rig follows the camera)
- `stage` (material stage)
- `arrange` / `sizzle` / `oil` / `pan` (pan A parameter overrides)
- `preset`, `t`, `ev`, `fog_start`, `rig_radius`, `target_offset`

**Material progression:** `material_stage(actors, stage, k)` steps through `base_colour` / `normals` / `lit_no_wash` /
`wash` / `fog_emissive` / `final` on the turntable subject. It uses MIDs on the `MiseAtlas` / `Surface` / `Emissive`
slots, and `restore_materials()` undoes them. `base_colour` and `normals` are capture sources; the env is hidden from
them.

**Cooking:**
- `arrange(name)` places the hero pan's cubes: `empty`, `single_raw`, `single_half`, `single_seared`, `trio`.
- It also sets each cube's CPD:
  - 0-3: sear +X -X +Y -Y
  - 4-7: +Z / -Z / Penetration / Oil Coat
  - 8-9: Glaze / Shape
- It fills pan A's `Meat Footprint` / `Meat Footprint 1..5` and resets pan A to `PAN_LOOK`.
- Cube states (`CUBE_STATES`):
  - raw = 0
  - half = +Z 0.9 (the seared face flipped up), -Z 0.2, Penetration 0.45, Oil Coat 0.6, Shape 0.3
  - flipped
  - seared = all faces about 1, Penetration 1, Glaze 0.35, Shape 1

## Review stills (`D:\Repo\Content\Devlog\stage_review\`)

`tt_wall4m_lit`, `tt_wall4m_normals`, `tt_wall_ossuary`, `tt_pier_family`, `tt_portal6m`, `cook_empty_sizzle0`,
`cook_empty_sizzle1`, `cook_cube_raw`, `cook_cube_half`, `cook_cube_seared`, `cook_trio`, `cook_oil_macro`, `cook_wide`,
`room_high34`, `room_head`.

- `stage_review_contact.png`: the 4x3 contact sheet (turntable 5, cooking 5, room 2).
- `stage_review_cooking_contact.png`: all eight cooking stills.
- `stage_review_stats.json`: luma percentiles per still.

## Caveats

- **Water bay not built.** The scope changed to the cooking bay; the `cool` preset and the CryptCold cubemap are ready
  for it. The lineup bay was dropped.
- **Pans read copper.** The steel reflects the warm `CookingStudio_Mars_HDR`, as in `CookingLookdev_Mars_MAP`.
- **Sizzle bubbles are small.** The simmer domes are under 0.4 cm, so Sizzle 0 vs 1 only reads in close shots
  (`cook_pool_top`, the macro). The Niagara oil bubbles from `mars_food_ue` are not attached: they do not freeze with
  material time.
- **Room floor is the plan's.** The plan's two scaled `crypt_floor_4x4` slabs stretch their texture (dark blue-grey
  squares) beside the paver strip. The room's south outer wall stays dark in the high 3/4 view.
- **PIE vs capture.** Exposure is calibrated on SceneCapture stills. A PIE or viewport view of the map uses the grade
  volume at the same EV but may read brighter (earlier finding: PIE 2.5-4.5 stops brighter than captures).
- **Probe reading.** The 18 % grey probe's key-lit side reads about 144-152 / 255 and its median about 102-105 (mid grey). Stone medians
  are about 100 (Blender about 94).
