# Mars food library (cooking ingredients, stages, fryer, mortar)

Procedural, re-runnable Blender 5.2 builders for the faceted "monster food" roster of the cooking game, their cook
stages, the batter generator, the bubbling-oil VAT and the mortar-and-pestle stage meshes, plus the Unreal importer
and materials. Everything here is generated from the scripts in this folder; the `.blend` files and exports under
`D:\Repo\Content\Cooking\food` are build outputs (off-repo, like the rest of `D:\Repo\Content`).

Style ruling (2026-10-06): faceted low-poly silhouettes that still read as believable food, not hyper-real. Meats
reuse the sear / penetration cook model of `Meat_Mars_M`; anything fried shares one oil-coat material function; salt
and pepper are separate stage meshes; herbs are one closed pile mesh the chopping station can slice at runtime.

## Files

| File | Role |
| --- | --- |
| `food_spec.py` | The contract every builder and the importer read: roster, sizes, pivots, UV channels, vertex colours, masks, CPD layout, VAT encoding, batter notes. Change it here first. |
| `food_common.py` | Shared Blender helpers: faceted object creation, noise, lathe/loft/icosphere, paint (vertex colours + cavity), Smart UV, morph UVs, VAT UVs, Cycles mask bakes, PNG/EXR writers, FBX export + JSON sidecar, review sheets, re-import probe. |
| `build_food_meats.py` | RoastHorned, Drumstick, Tentacle (raw mesh + cooked morph in UV1/UV2, masks). |
| `build_food_produce.py` | Puffer, Turnip, SpikedBerry, TomatoBulb, ScaledPine, HerbPile, Mushroom (+ Half and Slice cross-sections for cutting). |
| `build_food_mortar.py` | Mortar, Pestle, loose salt crystals / peppercorns, Salt and Pepper piles in three crush stages. |
| `build_food_swatch.py` | `ColorSwatch_Mars_SM`, the vertex-colour calibration bar for the Unreal lookdev. |
| `build_food_fryer.py` | `MarsBatterShell` geometry-node generator -> `<Name>_Battered_Mars_SM` for every fryable ingredient; oil surface + bubbles rest meshes and their VAT textures + `OilVAT_Mars.json`. |
| `unreal/mars_food_ue.py`, `unreal/mars_food_hlsl.py` | Editor Python: import meshes / masks / VATs, build `Food_Mars_M`, `Batter_Mars_M`, `Accent_Mars_M`, `Salt_Mars_M`, `OilVAT_Mars_M`, `OilCoat_Mars_MF`, instances, slot assignment from the sidecars, `FoodLookdev_Mars_MAP`, captures. Reuses `mars_cooking_ue.py` helpers by import. |

## Rebuild

```powershell
$b = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
& $b -b --factory-startup --python Tools\Blender\mars_cooking\build_food_meats.py   -- --export --save --sheets
& $b -b --factory-startup --python Tools\Blender\mars_cooking\build_food_produce.py -- --export --save --sheets
& $b -b --factory-startup --python Tools\Blender\mars_cooking\build_food_mortar.py  -- --export --save --sheets
& $b -b --factory-startup --python Tools\Blender\mars_cooking\build_food_fryer.py   -- --oil --batter --save --sheets
```

Each prints `FOOD_<CATEGORY>_OK`. Exports land in `D:\Repo\Content\Cooking\export\food\` (FBX + `.json` sidecar per
mesh, `<Name>_Mask_Mars_T.png`, the four `Oil*_VAT*_Mars_T.exr`, `OilVAT_Mars.json`), review sheets in
`export\food\review\`. Run the fryer's `--batter` pass after the meats / produce builders, it reads their FBXs.

Unreal (editor Python over Monolith `editor_query run_python`, or the editor's Python console):

```python
import sys, importlib
sys.path.insert(0, r"D:\Repo\Mars\Tools\Blender\mars_cooking\unreal")
import mars_food_ue as mf; importlib.reload(mf)
mf.run_all()          # import_textures, import_meshes, build_materials, build_lookdev_map
```

## The contract in one screen

- Units: builders work in cm, Z up; objects are created in metres at the origin and exported with the cooking_spec
  FBX settings (`-Z` forward, `Y` up, no scale, triangulated, linear vertex colours). Unreal local = (x, -y, z) cm.
- Pivot: centred in XY, lowest point at z = 0, long items along +X. Piles pivot at the mortar bowl floor centre;
  the pestle stands on its crushing head; the oil disc is a 1 m disc at z = 0 the game scales to its vessel.
- UV0 atlas (Smart UV), UV1 `ShapeXY` / UV2 `ShapeZ` = raw -> cooked offset in Unreal cm (`uv1 = (ox, 1 - oy)`,
  `uv2 = (oz, 1)`), only on morphing meshes; VAT meshes carry `VATColumn` UV1 (`u = (i + 0.5) / n`).
- Vertex colour `Col`: linear RGB base albedo with per-facet jitter and warmer crevices, A = cavity.
- Mask textures (linear RGBA, TC_MASKS): R cook-first, G grain / speckle, B crust break-up, A rim.
- Custom Primitive Data: 0-3 sear +X -X +Y -Y, 4-7 sear +Z -Z / penetration / oil coat, 8-11 glaze / shape /
  fry / wet. Same first ten floats as `Meat_Mars_M`, so gameplay drives every cooking mesh the same way.
- Material slots: cooking slots `Flesh`, `Skin`, `Batter`; static accents `Horn`, `Bone`, `Leaf`, `Stem`, `Salt`,
  `Pepper`, `Stone`, `Wood`, `Oil`.

## Roster and results

Generated from the export sidecars (33 meshes). Every mesh: flat shaded, `Col` vertex colours, UV0 atlas, FBX + `.json` + mask PNG.

| Mesh | Tris | Size cm | Slots | Morph cm | Sidecar extras |
| --- | --- | --- | --- | --- | --- |
| `ColorSwatch_Mars_SM` | 60 | 15.0 | Stone | - | - |
| `Drumstick_Battered_Mars_SM` | 1664 | 22.5 | Flesh, Bone, Batter | - | - |
| `Drumstick_Mars_SM` | 688 | 21.4 | Flesh, Bone | 1.7 | - |
| `HerbPile_Mars_SM` | 2766 | 16.0 | Leaf, Stem | - | manifold |
| `Mortar_Mars_SM` | 1512 | 22.9 | Stone | - | bowl_floor_cm, bowl_inner_radius_cm |
| `Mushroom_Battered_Mars_SM` | 3242 | 14.4 | Skin, Batter | - | - |
| `Mushroom_Half_Mars_SM` | 874 | 11.9 | Skin, Flesh | - | manifold |
| `Mushroom_Mars_SM` | 1340 | 12.0 | Skin, Flesh | 1.4 | manifold |
| `Mushroom_Slice_Mars_SM` | 584 | 11.9 | Skin, Flesh | - | manifold |
| `OilBubbles_Mars_SM` | 3840 | 80.0 | Oil | - | - |
| `OilSurface_Mars_SM` | 7938 | 100.0 | Oil | - | - |
| `PepperPile_Cracked_Mars_SM` | 2089 | 10.5 | Pepper | - | footprint_radius_cm |
| `PepperPile_Ground_Mars_SM` | 482 | 11.3 | Pepper | - | footprint_radius_cm |
| `PepperPile_Whole_Mars_SM` | 2652 | 9.5 | Pepper | - | footprint_radius_cm |
| `Peppercorn_A_Mars_SM` | 320 | 1.0 | Pepper | - | - |
| `Peppercorn_B_Mars_SM` | 320 | 0.9 | Pepper | - | - |
| `Pestle_Mars_SM` | 544 | 18.0 | Stone | - | contact_point_cm |
| `Puffer_Battered_Mars_SM` | 3838 | 16.0 | Skin, Horn, Batter | - | - |
| `Puffer_Mars_SM` | 1520 | 14.0 | Skin, Horn | 1.4 | - |
| `RoastHorned_Mars_SM` | 1308 | 30.8 | Flesh, Horn | 1.4 | - |
| `SaltCrystal_A_Mars_SM` | 52 | 2.5 | Salt | - | - |
| `SaltCrystal_B_Mars_SM` | 68 | 2.4 | Salt | - | - |
| `SaltCrystal_C_Mars_SM` | 54 | 2.6 | Salt | - | - |
| `SaltPile_Crystals_Mars_SM` | 1562 | 12.2 | Salt | - | footprint_radius_cm |
| `SaltPile_Dust_Mars_SM` | 482 | 11.5 | Salt | - | footprint_radius_cm |
| `SaltPile_Grit_Mars_SM` | 2312 | 11.7 | Salt | - | footprint_radius_cm |
| `ScaledPine_Mars_SM` | 1474 | 20.0 | Skin, Leaf | - | - |
| `SpikedBerry_Battered_Mars_SM` | 4254 | 11.7 | Skin, Horn, Batter | - | - |
| `SpikedBerry_Mars_SM` | 1758 | 10.0 | Skin, Horn | - | - |
| `Tentacle_Battered_Mars_SM` | 4714 | 31.0 | Flesh, Batter | - | - |
| `Tentacle_Mars_SM` | 1948 | 29.0 | Flesh | 3.3 | - |
| `TomatoBulb_Mars_SM` | 1640 | 12.0 | Skin, Leaf | 1.5 | - |
| `Turnip_Mars_SM` | 2016 | 16.0 | Skin, Leaf | 7.4 | - |

## Oil, bubbles and other liquids (version 2 of the VAT)

- `OilSurface_Mars_SM` + `OilBubbles_Mars_SM` are shared by every liquid: the surface material (`OilVAT_Mars_M`)
  has `Liquid Colour` / `Liquid Colour Deep` (troughs) and the bubble material (`OilBubble_Mars_M`, masked,
  two-sided) fakes glass opaquely: liquid colour brightened at the centre, darkened and thin-film tinted at the rim,
  backfaces shaded as liquid. No translucency, no refraction pass.
- Pop: the bubbles position VAT's alpha carries the pop progress per vertex and frame (0 intact, 0..1 over the last
  15 % of a bubble's cycle while it widens into a base ring, 1 while hidden); UV2 `BubbleLocal` holds each vertex's
  height within its bubble (x) and the bubble index (y). Opacity Mask = `BubbleLocal.x < 1 - pop`, so the dome
  dissolves from the apex down and leaves the ring. `Use Pop` on the instance switches it.
- Liquids are rows of `LIQUIDS` in `unreal/mars_food_plan.py` (colour, deep colour, bubble colour, speed): each row
  makes a surface + bubbles instance pair, a puck in the lookdev and a shot. `Stew` is the second row.

## Niagara bubbles (reusable pop, e.g. the pan oil in local space to the meat cube)

- `OilBubble_Mars_SM`: one 1 cm dome (320 tris, pivot at its base, UV2 `BubbleLocal` x = height) exported by
  `build_food_fryer.py --bubble-mesh`.
- `OilBubbleParticle_Mars_M` (+ `_MI`): masked two-sided glass via `BubbleGlass_Mars_MF` (shared with the VAT
  bubble master); pop = Dynamic Material Parameter x, edge phase = y, colour = particle colour.
- `/Game/Mars/Gameplay/Cooking/Food/FX/OilBubbles_Mars_NS`: local-space CPU emitter, mesh renderer on the dome,
  custom modules `MarsBubbleSpawn_Mars_NM` (disc or box spawn, start below the surface, random radius / lifetime,
  liquid colour) and `MarsBubbleUpdate_Mars_NM` (ease-out rise, ride wobble + scale pulse, pop window driving the
  dynamic parameter and the ring scale / apex sink, then death). 18 user parameters (SpawnRate, SpawnRadius or
  SpawnExtent, SurfaceZ, StartDepth, BubbleRadiusMin/Max, LifetimeMin/Max, RiseFraction, PopFraction, SurfaceSink,
  Wobble*, ScalePulse, RingScale, ApexSink, LiquidColour). A pan instance sets SpawnExtent, SurfaceZ and LiquidColour.
- Rebuild: `python unreal\mars_food_niagara.py --port 9316` against a running editor with Monolith (it uses
  Monolith's `niagara_query` actions; plain editor Python cannot author Niagara module stacks in this build).

## Follow-ups noted during the build

- Potato and pickle (stew / soup cuts) were mentioned but are not in the starter roster.
- Runtime slicing of the HerbPile is a gameplay feature (CkFoundation), not part of this library; the mesh is built
  closed and manifold so a slicer can cut it.
