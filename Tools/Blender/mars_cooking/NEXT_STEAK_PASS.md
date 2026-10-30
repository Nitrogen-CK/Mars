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

## 2026-10-25: simmer bubbles come in groups (Stephen: "the bubbles look really uniform")

`PAN_POOL`'s simmer used to put one bead in every cell of a jittered 0.55-0.6 cm grid, about 85 % of them alive at
Sizzle 1, so the film read as an even lattice. It now has a cluster layer on top:

- **Patches:** value noise on coarse cells `Simmer Cluster Scale` x `Simmer Cell` wide (default 2.5), its lookup warped
  by a second noise so no lattice shows, each lattice value re-rolling on its own clock (`Simmer Cluster Rate`, default
  0.15 per second) so patches swell, drift and fade. It is thresholded so that about `Simmer Cluster Cover` (default
  0.4) of the film lies in a patch: dense core, thinning edge.
- **Beads:** a grid 0.65 x `Simmer Cell` (so a patch's beads crowd), each cell alive with Sizzle x `Simmer Density` x
  (patch x 1.15 + `Simmer Stray` + the meat band), evaluated once per bead (no dome is ever cut). Radius 0.4-1.6 x
  0.19 x `Simmer Cell` (the largest is still 0.3 x `Simmer Cell`), centre jittered as far as the bead's size allows,
  own rate and phase per bead, as before.
- **Between patches:** `Simmer Stray` (default 0.02) lone bubbles; otherwise calm oil.
- **Near the meat:** the `Simmer Width` band adds `Simmer Near Meat` x near x (0.5 + patch noise), so it bubbles
  outside the patches too (and unevenly along the meat); nothing bubbles under a meat. The band is read at the bead's
  centre.
- Measured on `cook_empty_sizzle1` (Sizzle 1, Density 0.85): about 0.45 x the old bubble count on the open film.
- Existing instance overrides (`Simmer Cell` 0.6, `Simmer Density` 0.85 on the lookdev and Devlog pans) keep working;
  the four new scalars are master defaults only.
- Rebuild the pan alone, in place: `mc.rebuild_pan()` (`_reset_material` empties the same UMaterial; the recompile
  refreshes every instance). Before/after: `D:\Repo\Content\Devlog\stage_review\oil_bubbles_before_after.png`.

### Same day: the still oil beads on the dry pan gather in patches too

`PAN_DROPS`'s still beads (`Beads()`, two layers: `Bead Cell` and 0.46 x it) were one bead per jittered cell with chance
`Bead Density`. They now share a static patch layer (no clock: the beads do not move):

- **Patches:** value noise on cells `Bead Cluster Scale` x `Bead Cell` wide (default 3.0), its lookup warped, thresholded
  so about `Bead Cluster Cover` (default 0.2) of the pan lies in a patch, dense core thinning to the edge. Both bead
  layers read the same field, so big and small beads gather together.
- **Chance per cell:** `Bead Density` x (4 x patch + `Bead Stray`), capped at 1, read at the cell centre (no bead is cut
  by a patch edge). `Bead Stray` (default 0.05) leaves a few lone beads on the clean steel.
- **Beads:** radius spread evenly over 0.4-1.6 x 0.19 x `Bead Size` x the cell (mean about the old one), centre
  jittered as far as the radius allows, so no rows. The running drops and the two-size merge are unchanged.
- Measured on `cook_empty_sizzle1` (the dry ring between the pool and the rim): about 0.32 x the old bead count.
  Before/after: `D:\Repo\Content\Devlog\stage_review\dry_beads_before_after.png`.
