# Stylized water (Godot port) + fishing gym: plan (2026-10-29, not started)

Stephen asked: replicate the Godot MiseCryptLab water shader in Unreal and put together a fishing gym.
Reconnaissance only so far; nothing below is built.

## Source (Godot)

- `C:\Users\Stephen\Documents\Houdini\Godot\MiseCryptLab\shaders\third_party\stylized_water.gdshader`: Malido's
  "Absorption Based Stylized Water" (CC0) plus a Mise glow term. Instance values in `materials\mise_water.tres`.
- Textures are generated FastNoiseLite (`materials\water\*.tres`, all seed 7, seamless): displacement = simplex-smooth
  freq 0.02 256 px; edge_noise = cellular freq 0.03 256 px; normal = cellular freq 0.02 as a normal map (bump 6);
  edge_ramp = 1D gradient white at 0 -> black at 0.08.
- Target look: `captures\cistern_traverse_Conceptmatch_20261018_192111\00_r00_cistern_-_eye.png` (glowing teal pool,
  white foam lines where piers cut the surface, teal OmniLights under the water). Pool built in the kit's
  `crypt_cathedral_hall` shell by `tools\traversal_gen.gd` (24 x 40 m hall, pool x -12..12, y 6..34 m, floor -4 m,
  water -0.6 m).

## Port: what each Godot term becomes (Godot metres -> cm, Y-up xz -> Z-up xy)

| Godot | Unreal |
|---|---|
| vertex displacement (2 scrolled samples, mix 0.4, strength 0.05 m) | WPO on Z, 5 cm |
| normal map (2 scrolled samples at LOD 2, strength 0.8) | normal; sample a blurred mip |
| screen + depth texture, refraction, Beer's law (depth_distance 4 m, beers_law 4) | translucent material: SceneColor + SceneDepth nodes (keep them in the graph so the bindings exist), the rest in a Custom node |
| edge foam (relative depth / edge_thickness 0.25 m, noise through ramp) | same, from SceneDepth vs pixel depth |
| player ripples (global `player_position`) | a new MPC `Water_Mars_MPC` (PlayerPosition, WindDirection, WindIntensity); something visual-only writes the local player's position |
| caustics (OpenSimplex2 with derivatives, size 1.2 /m, range 40 m) | port the HLSL verbatim into a new `Shaders/Water/MarsStylizedWater.ush` |
| SSR loop (100 steps) | Mars has no SSR (`r.ReflectionMethod=0`); port the march in the .ush on SceneColor/SceneDepth, behind a static switch |
| glow emission (Mise term) | emissive; feeds bloom |

Bake the four noise textures offline (numpy, periodic noise so they tile) and import them; mips then do the
Godot LOD-2 blur.

## Where it goes

- New master `StylizedWater_Mars_M` + instance `StillWaterGlow_Mars_MI` built by a `build_stylized_water()` in
  `Tools/Blender/mars_water/unreal/mars_water_ue.py` (add to `BUILDERS`, `water_spec.MASTERS` / `INSTANCES`), using the
  existing `_G` helpers and `wet()` include pattern.
- `AMars_StillWater` already takes a `WaterMaterial` override, so the pool actor needs at most a style enum.
- Run through a hidden editor (`env_drive.py --port 9318 --launch`), not Stephen's Monolith on 9316 while he works.

## Fishing gym

- Fishing kernel (M1), station HFSM + entity script (M2) and `Mars.Sandbox.PlaceFishingStation` (pool + station) already
  exist; FishingGrounds (M6) does not.
- New `FishingGym_Mars_MAP`: the cathedral-hall cistern (as in Godot) with the stylized pool, a bank ledge with 2-3
  hand-placed fishing stations (`StartOpen = true`, `SurfaceZ` set), piers/islands, teal under-lights + warm wall
  fixtures, and a cutting table + searing station to take the catch through to the pan.
- Builder: a `mars_fishing_gym_ue.py` on the `mars_station_gym_ue.py` model (kit layout JSON from
  `C:\Users\Stephen\Documents\Houdini\Blender\export\crypt_kit`, HISM shell, key/home tags so hand edits survive).

## Order

1. Bake + import the noise textures. 2. Port the shader (.ush + master + instance), check it on the
`WaterLookdev_Mars_MAP` cistern bay. 3. MPC + player-position writer. 4. Gym builder + map. 5. PIE look check, then
`--test-pattern Fishing` and `--test-pattern StillWater`.
