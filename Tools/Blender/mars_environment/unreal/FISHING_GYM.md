# Fishing gym (`/Game/Mars/Maps/FishingGym_Mars_MAP`)

The fishing station on the bank of a sunken pool in a crypt-kit room, lit with the station gym's numbers. Built by
`mars_fishing_gym_ue.py` (this folder), the way `mars_station_gym_ue.py` builds the kitchen: a reproducible Python
builder run through Monolith editor Python, never hand-placed actors. The room is planned in the builder's `LAYOUT`
and spawned straight from the crypt kit manifest (`C:\Users\Stephen\Documents\Houdini\Blender\export\crypt_kit`,
or `MISE_KIT_EXPORT`); the kit meshes must be imported (`/Game/Mars/Environment/Meshes`).

## Run

From the project root, with no other MarsEditor open on Mars (a hidden editor cannot save a map Stephen's open editor
has loaded; and close the hidden one before any `--test`, or the fresh-boot test editor becomes SECONDARY):

```bash
python Tools/Blender/mars_environment/unreal/env_drive.py --port 9317 --launch
python Tools/Blender/mars_environment/unreal/env_drive.py --port 9317 --module mars_fishing_gym_ue --alias fg --call "fg.run_all()"
python Tools/Blender/mars_environment/unreal/env_drive.py --port 9317 --module mars_fishing_gym_ue --alias fg --call "fg.capture()"
python Tools/Blender/mars_environment/unreal/env_drive.py --port 9317 --quit
```

`run_all()` creates or rebuilds the map, applies the look, sets the game mode, saves, cooks the Jolt static world and
saves again; it returns a report (`instanced` 184 kit instances, `pieces` 22, `lamps` 12, `starts` 4, the spots' written
specs, `saved`, `cooked`). `capture()` is a separate call: it renders `SHOTS` (`start`, `spot_b`, `water`, `high`) to
`D:\Repo\Content\Environment\Dressing\export\review\fishing_gym\<shot>.png` through a scene capture (darker and more
saturated than the game view). `inspect()` prints the spots' specs and the water as the open map carries them.
`apply_look()` re-applies `mars_station_gym_ue.LOOK` without a rebuild.

Re-runnable: a rebuild destroys every actor in the `Mise_FishingGym` and `FishingGym` outliner folders and every
`FishingGym_*` label, then places everything again (second run: `cleared` 50). Hand edits inside those folders are
lost; anything placed elsewhere survives. The `Mars.Sandbox.PlaceFishingStation` placer is untouched.

## Layout (Unreal cm, the pool's centre at the origin, +Z up)

| What | Numbers |
|---|---|
| Room interior | 24 x 24 m (+-1200), 6 x 6 `crypt_floor_4x4` / `_pavers_4x4` tiles, tops at Z 0 (the bank) |
| Pool | 16 x 16 m (+-800), the middle 4 x 4 tiles, their tops at Z -120; two `crypt_wall_course_4m` courses line each side (Z -90 and -140), faces toward the water |
| Water | `AMars_StillWater` `FishingGym_Pool` at (0, 0, -6), `Size` 1600 x 1600, `Deep` off, `Murk` 1.0, `Seed` 3: the surface 6 cm under the bank's lip |
| Walls | `crypt_wall_4m` course at Z 0 (3.5 m), `crypt_wall_course_4m` band at Z 350, `crypt_wall_flat_4m` course at Z 400; quoins at (+-1220, +-1220) Z 0 / 400; `crypt_roof_4x4` at Z 400 (ceiling 7.5 m) |
| Spot A | `FishingGym_Spot_A`, root (-850, 0, 0), yaw 0 (casts +X), `Fishing.Water.SurfaceZ` -6, `Fishing.Seed` 1; the operator stands at (-895, 0), the spot disc at (-310, 0, -5.5), a max cast lands at X 50 |
| Spot B | `FishingGym_Spot_B`, root (0, 850, 0), yaw -90 (casts -Y), `SurfaceZ` -6, `Seed` 7; stand (0, 895), disc (0, 310, -5.5) |
| Cast fan | +-45 deg, 900 cm max: from either root the fan's corners land at 636 cm to the side, inside the pool's 800; the 150 cm min cast lands 100 cm past the lip |
| Player starts | `FishingGym_PlayerStart_0..3` at Z 110: (-1080, -160) yaw 0 behind spot A; (160, 1080) yaw -90 behind spot B; (1080, -160) yaw 180; (-160, -1080) yaw 90 |
| Lamps | 8 lanterns (`camp_lantern` on a `box_stone_block_1m`, light at Z 76) at (+-1170, +-600) and (+-600, +-1170), 400 W; 4 bare lamps over the water at (+-500, +-500, 420), 320 W. Candelas = watts x 0.08 x `LOOK["light_scale"]` 2.4 |
| Rig | height fog, flat ambient, sphere reflection capture at (0, 0, 200) radius 1800 (the crypt warm cubemap when the environment HDRs are imported), the grade: all `mars_station_gym_ue.LOOK` |
| Climb-out | pool corner +X+Y: `box_stone_block_1m` at (530, 760, -120) (top -70) and `box_stone_block_2m` at (690, 730, -120) (top -20): -120 / -70 / -20 / 0 steps, out of both cast fans; a jump clears the lip anyway |
| Labels | `FISHING GYM` on the -Y wall at Z 300; `Spot A  seed 1` / `Spot B  seed 7` tags on the bank beside each stand, facing its start |

The station reads the water as a world Z plane (`FMars_Fishing_WaterSpec.SurfaceZ`): the builder writes it, and the seed,
onto each spawner's instanced entity script (`_EntityScript.Fishing`) and reads it back; `inspect()` after a reload from
disk shows -6 / 1 and -6 / 7. The editor's preview entity is built when the spawner is placed, before the spec is written,
so in the editor the spot disc may sit at Z 0 until the map is reopened; PIE spawns from the saved spec.

## What to check in PIE

Open the map, PIE from `FishingGym_PlayerStart_0` (the view faces +X over the pool, spot A on the left, its `Idle`
label beside the bank slab). Then:

1. Walk up to spot A's bank slab (the root, 50 cm from the lip): the Use prompt reads **Fish here**; press Use. The
   rod rises into the right glove, the left glove on the reel; the view is free inside +-45 deg of +X.
2. **Cast**: hold Primary, release. The rod whips, the bait flies out over the water and lands **on the water**, not
   above or under it (the surface is 6 cm below the bank: watch the bait against the lip from the bank, and bob there).
   A short hold lands near the lip (150 cm min), a full hold lands 9 m out, near the middle of the pool. Aim left and
   right: the fan stays over the water.
3. **Bite**: after 3-9 s the bait dips (`Mars_FishingBite` forces one). The rod jerks.
4. **Hook strike**: press Primary inside the bite window; the rod jerks again and the label reads `Hooked`. Miss the
   window and the bait settles for another wait.
5. **Reel**: hold Primary. The reel handle turns, the line shortens, the label shows tension and line length; the rod
   bows with tension. Ease off when tension is high; the fish runs now and then.
6. **Land**: the line comes in, the fish flings up to the catch point in front of the chest and **lands on the bank**
   (the fish food, `Mars_ItemDef_Food_Fish`, the station's default catch). `Mars_FishingLand` forces it. The tally on the label
   goes up. `Mars_FishingState` prints the kernel's state.
7. Walk round to spot B (`FishingGym_PlayerStart_1` faces it) and repeat: same bank, different seed, so the bite waits and
   runs differ. Compare the two.
8. Fall into the pool on purpose: the climb-out blocks in the +X+Y corner step out (jump if a 50 cm step is too tall).

Not yet seen in PIE from this session (the map was built and captured in a hidden editor; the fishing scripts were not
changed): the prompt, the cast, the bait on the water, the bite, the hook, the reel, the landing. The headless
`--test-pattern Fishing` run covers the kernel and the station's intent reader, not this map.
