# Steak pass: stylized cube, matched oil pool, whole-pool simmer, pan bubbles

Status 2026-10-07: items 1-5 DONE (captures in D:\Repo\Content\Cooking/export/review/steak); items 6-7 in progress.

Stephen's request 2026-10-07 after the Mario Party frame review.

## Steak minigame changes (other session's files: `cooking_spec.py`, `build_cooking_meshes.py`,
## `build_cooking_textures.py`, `unreal/mars_cooking_ue.py`, `unreal/mars_cooking_hlsl.py`)

1. **Cube half the size:** `cooking_spec.CUBE_HALF_CM` 4.0 -> 2.0 (also the lump / bevel constants scale with it).
   Rebuild meshes + textures, re-import, and update the lookdev placements that use `spec.CUBE_HALF_CM`.
2. **Stylized like the Mario cube:** clean saturated pink-red lean, a few broad pale fat streaks instead of the fine
   wagyu web (lower the marbling frequencies in `build_meat`: fewer, wider veins, no `pockets` noise), softer fibre
   contrast (`Fibre Contrast` ~0.1), flatter normal (`Normal Raw` ~0.1), slightly larger edge bevel, glossy raw
   clear coat; crust ramp a clean caramel brown. Keys live in `RAMPS` (`SearRamp_WagyuLean/Fat`) and the
   `Meat_Wagyu_Mars_MI` instance; re-import the ramps with `build_curves(refresh=True)`.
3. **Pool matched to the cube:** the `Pan_Steel_LookdevCooking_Mars_MI` values `Meat Footprint` radius (was 4.9 for
   the 8 cm cube -> ~2.5), `Pool Radius` 3.4 -> ~1.7, `Pool Margin` 1.6 -> ~0.8 so the oil pool hugs the cube; the
   gameplay side sets Meat Footprint from the cube's size (CUBE_HALF_CM * sqrt 2 * 0.9).
4. **Simmer over the whole pool:** in `PAN_POOL` the bubble term is gated by `ring` (a band around the meat). Replace
   `ring` with `film` (bubbles everywhere the oil is) scaled by `Sizzle`, keep a mild boost near the meat
   (`+ 0.5 * ring`), and let `Sizzle` also raise `SimRate` slightly.
5. Rebuild through `mc.build_materials()` only (release-masters rule in [[mars-cooking-look]]), rebuild
   `CookingLookdev_Mars_MAP`, capture `pan_cooking`, `pan_cooking_close`, `cubes`, `cube_plated`.

## Pan-side improvements from the Mario breakdown (food library files)

6. Place `OilBubbles_Mars_NS` on the pan with `SpawnExtent` = the pool footprint, `SurfaceZ` = oil level,
   bubble radius 0.2..0.4 cm, `Rim Darken` high / `Centre Brighten` low on `OilBubbleParticle_Mars_MI` so they read
   as the dark-rimmed beads in the Mario frame; `LiquidColour` = the pan oil tint.
7. A small splatter emitter (sprites: dark droplets around the meat footprint, fading over ~2 s) as a second emitter
   in `OilBubbles_Mars_NS` or its own `OilSplatter_Mars_NS`, built with `mars_food_niagara.py` style Monolith calls.

Run against Stephen's editor on Monolith 9316 (never a hidden instance while he might build); his map must not be
left dirty. Use Opus agents at high effort, one for 1-5 then one for 6-7 (same editor, so sequential).
