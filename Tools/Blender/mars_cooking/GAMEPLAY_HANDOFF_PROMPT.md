# Prompt: wire the cooking visuals into gameplay (pan, deep fryer, stew)

You are integrating the finished cooking visuals of the Mars project (UE 5.5-era fork, CkFoundation ECS, AngelScript
gameplay) into playable stations. The art, materials, VATs and Niagara systems already exist and are reviewed; your job
is the gameplay composition that drives them: which components attach to what, which feature owns which state, and
how the material / particle parameters are fed every frame. Read before you design; do not re-author art.

## Read first

- `D:\Repo\Mars\CLAUDE.md`, section "Mars gameplay script conventions" (features under `Script/ECS/<Feature>/`, typed
  handles, the request doctrine, HFSM tasks own behaviour, actors are composition, widgets are logic only, view via
  `utils_player_viewpoint`). Then `Plugins/CkFoundation/Script/CLAUDE.md` for the AngelScript patterns.
- `D:\Repo\Mars\Tools\Blender\mars_cooking\FOOD_LIBRARY.md`: the asset contract. The parts you need:
  - Custom Primitive Data on every cooking mesh (meats, produce, batter): floats 0-3 sear +X -X +Y -Y (0 raw, 1 full
    crust, 2 burnt), 4-7 sear +Z -Z / Penetration 0..1 / Oil Coat 0..1, 8-11 Glaze / Shape (raw->cooked morph 0..1) /
    Fry (batter 0 raw, 1 golden, 2 burnt) / Wet (stew soak 0..1). Gameplay writes these with
    `SetDefaultCustomPrimitiveDataFloat` / `SetCustomPrimitiveDataVector4` on the mesh component.
  - Mesh naming: `<Name>_Mars_SM`, battered variant `<Name>_Battered_Mars_SM`, stage meshes `SaltPile_<Stage>_Mars_SM`
    / `PepperPile_<Stage>_Mars_SM`, mushroom cuts `Mushroom_Half_Mars_SM` / `Mushroom_Slice_Mars_SM`. Sidecar JSONs next
    to every FBX (`D:\Repo\Content\Cooking\export\food\*.json`) carry size_cm, slots, morph_max_cm, the mortar's
    `bowl_floor_cm` / `bowl_inner_radius_cm`, pile footprints. `food_spec.INGREDIENTS` lists which are fryable,
    morphing, cuttable (`cpu_access`), and the cut variants.
  - Assets: `/Game/Mars/Gameplay/Cooking/Food/{Meshes,Textures,Materials,FX}`, lookdev `/Game/Mars/Maps/FoodLookdev_Mars_MAP`.
- `C:\Users\Stephen\.claude\projects\D--Repo-Mars\memory\mars-cooking-look.md` and the steak pipeline
  (`Tools/Blender/mars_cooking/cooking_spec.py`, `unreal/mars_cooking_ue.py`): the pan's instance parameters and the
  4 cm cube (`CUBE_HALF_CM` 2.0, `CUBE_FOOTPRINT_CM` 2.55), lookdev `/Game/Mars/Maps/CookingLookdev_Mars_MAP`.
- `unreal/mars_food_ue.py` `attach_pan_bubbles(...)` and `unreal/mars_food_plan.py` (`NIAGARA_USER`, `LIQUIDS`,
  `BUBBLE_LOOK`): the exact Niagara user parameters and the liquid colour table.

## What exists (names are exact)

Pan station: `FryPan_Mars_SM` (pivot = centre of the cooking surface, handle along +X), material `Pan_Mars_M` via
`Pan_Steel_Mars_MI` with per-cook instance parameters: Oil Amount, Sizzle, Fond, Seasoning, Meat Footprint
(pan-local x, y, radius; radius 0 = no meat), Oil Trail (pan-local x, y that lags the meat so the pool stretches),
Pool Radius / Margin / Blend / Wobble, Simmer Density / Near Meat / Rim Darken. Meat: `MeatCube_Mars_SM` +
`Meat_Wagyu_Mars_MI` (clear coat; sear per axis via CPD). Niagara: `OilBubbles_Mars_NS` (local-space mesh bubbles;
user params SpawnRate, SpawnRadius or SpawnExtent xy, SurfaceZ, StartDepth, BubbleRadiusMin/Max, LifetimeMin/Max,
RiseFraction, PopFraction, SurfaceSink, WobbleAmplitude/Frequency, ScalePulse, RingScale, ApexSink, LiquidColour) and
`OilSplatter_Mars_NS` (SplatterRate, BurstsPerSecond, FlingMin/Max, SplatterArc, SplatterSize, SplatterLife,
SplatterRadius, SplatterColour). The lookdev attaches four bubble strips around the cube footprint plus one splatter at
the cube centre with SurfaceZ = -CUBE_HALF_CM + 0.1 in the cube's space (see `attach_pan_bubbles`).

Deep fryer: `OilSurface_Mars_SM` (1 m disc, VAT-driven, `OilSurface_Mars_MI`, scale to the vessel), `OilBubbles_Mars_SM`
(VAT bubbles with baked pop, `OilBubbles_Mars_MI`) or the Niagara bubbles; battered meshes for Drumstick, Tentacle,
Puffer, SpikedBerry, Mushroom with `Batter_Mars_M` instances (`<Name>_Batter_Mars_MI`) driven by Fry (CPD 10) and
Oil Coat (CPD 7). No fryer basket or cauldron prop exists yet (the pan and the mortar are the only vessels).

Stew: the same surface + bubble meshes with the `StewSurface_Mars_MI` / `StewBubbles_Mars_MI` pair (colour, deep
colour, bubble colour, speed from `LIQUIDS["Stew"]`), ingredients soak via Wet (CPD 11), cut variants for the pot
(mushroom Half / Slice; herbs are one sliceable pile). No cauldron prop exists yet.

Mortar: `Mortar_Mars_SM` (bowl floor at local (0, 0, 3) cm, inner radius 7.6), `Pestle_Mars_SM` (stands on its head,
grip up), loose `SaltCrystal_A/B/C`, `Peppercorn_A/B`, stage piles pivoted at the bowl floor centre.

## Build (one feature set per station under `Script/ECS/`, following the conventions exactly)

1. **Pan station** (`Script/ECS/PanCook/` or extend whatever the steak-minigame branch already has; check
   `git branch -a` and the gameplay branch before creating a parallel feature):
   - Composition: pan actor = pan mesh + a `MeatSlot` scene point at the cooking surface; the cube is its own entity
     (held item) that snaps to the slot; both Niagara systems attach to the CUBE (local space), so flipping or
     sliding the cube carries its beads and splatter; the pan material gets Meat Footprint from the cube's pan-local
     position every tick and Oil Trail from a lagged copy (first-order lag, ~0.25 s), Oil Amount from the oil
     resource poured, Sizzle from pan temperature x oil amount, Fond accumulating with time-at-sear.
   - Cook model: a `FMars_Fragment_PanCook` with per-face sear (6 floats), penetration, oil coat, glaze, shape; a
     processor integrates heat into the face that touches the surface (the cube's down axis in pan space), writes
     the CPD block (0-9) on the cube's mesh component, and raises signals at thresholds (seared, done, burnt).
     Flip / move are requests (`FMars_Request_PanCook_Flip` etc.) driven by HFSM tasks from CkIntent rows.
   - Movement: the pan jiggle / toss is a state machine on the station (idle, shake, toss, land); the cube's
     footprint and the oil trail follow from the simulated cube position, not from animation.
   - Plating: the finished cube keeps its CPD when it leaves the pan (Glaze rises on the plate).

2. **Deep fryer station** (`Script/ECS/Fry/`): a vessel (blockout cylinder until a prop exists) holding a scaled
   `OilSurface_Mars_SM` + bubbles at the oil level, a basket point below the surface, and a "dip" request that swaps a
   fryable ingredient's mesh to its `<Name>_Battered_Mars_SM` (slots remap by name) and sets Fry to 0 (raw batter,
   Oil Coat 1). A processor ramps Fry 0 -> 1 over the fry time and on to 2 if left, driving the batter instance's
   CPD; lifting the basket stops the ramp and lets Oil Coat drain toward 0.3 over ~5 s. Ingredients in the basket bob
   with a small sine (the VAT surface is visual only). The Niagara bubbles at the surface spawn in a box matching the
   basket footprint, SpawnRate scaling with how many items are frying.

3. **Stew station** (`Script/ECS/Stew/`): a cauldron (blockout until a prop exists) with the stew surface pair at the
   liquid level; ingredients thrown in become "floating" entities: a processor applies a swirl field in vessel-local
   space (tangential velocity around the centre plus a gentle inward pull and a bob that follows a cheap sine of the
   VAT phase), so items circle and drift toward the centre, then sink / dissolve after their soak time; Wet (CPD 11)
   ramps 0 -> 1 while soaking, Shape (CPD 9) ramps for the slumping produce; ladling out is a request that spawns the
   item back as a held thing. Bubbles via the Niagara system with the stew colours and Speed 0.6; a splash of
   `OilSplatter_Mars_NS` in the stew colour on each throw-in. Cut items (mushroom Half / Slice, herb pieces from the
   chopping station) are first-class stew ingredients.

4. **Shared**: a `utils_cookstate` helper that packs the sear / fry / wet state into the CPD block in one place (the
   indices above), used by all three stations; a lookdev-style test map per station under `Content/Mars/Maps/` and
   CkTests covering: CPD written as expected at thresholds, footprint follows the cube, the dip swaps the mesh and
   remaps slots, swirl keeps items inside the vessel radius, requests are drained by the feature's processor only.

Constraints: no fragment writes outside each feature's processors; `Add(Handle, Spec)` only; specs validated with a
`Validate` mixin; no strong UObject refs in fragments (soft pointers / handles); widgets are logic only; use the build
and test skill (`/build-test`) for any C++ or script change and run the focused test patterns before the full gate.
Do not edit the art builders under `Tools/Blender/mars_cooking` or the Unreal material modules; if a parameter you
need is missing, say so in your report rather than adding it ad hoc. Report what you built per station, the request
and signal lists, how each material / Niagara parameter is fed, and what still needs a prop or a design call.
