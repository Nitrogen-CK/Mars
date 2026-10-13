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
| `food_common.py` | Shared Blender helpers: faceted object creation, noise, lathe/loft/icosphere, paint (vertex colours + cavity), Smart UV, morph UVs, VAT UVs, Cycles mask bakes, PNG/EXR writers, FBX export + JSON sidecar, review sheets, re-import probe, and the runtime-mesh checker (`runtime_mesh_report` / `check_runtime_mesh`). |
| `build_food_meats.py` | RoastHorned, Drumstick, Tentacle (raw mesh + cooked morph in UV1/UV2, masks). |
| `build_food_produce.py` | Puffer, Turnip, SpikedBerry, TomatoBulb, ScaledPine, HerbPile, Mushroom (+ Half and Slice cross-sections for cutting). |
| `build_food_mortar.py` | Mortar, Pestle, loose salt crystals / peppercorns, Salt and Pepper piles in three crush stages. |
| `build_food_swatch.py` | `ColorSwatch_Mars_SM`, the vertex-colour calibration bar for the Unreal lookdev. |
| `build_food_prep.py` | `<Name>_Prep_Mars_SM` for every roster entry with a `prep` dict: the hero rebuilt to the game's runtime-mesh contract (one closed solid, <= 2048 render verts), its own mask transferred from the hero's; fails the build if the export breaks the contract. |
| `build_food_fryer.py` | `MarsBatterShell` geometry-node generator -> a `_Battered` twin of every fryable raw mesh (hero, authored cuts, prep variant), in the raw mesh's own frame; oil surface + bubbles rest meshes and their VAT textures + `OilVAT_Mars.json`. |
| `unreal/mars_food_ue.py`, `unreal/mars_food_hlsl.py` | Editor Python: import meshes / masks / VATs, build `Food_Mars_M`, `Batter_Mars_M`, `Accent_Mars_M`, `Salt_Mars_M`, `OilVAT_Mars_M`, `OilCoat_Mars_MF`, instances, slot assignment from the sidecars, `FoodLookdev_Mars_MAP`, captures. Reuses `mars_cooking_ue.py` helpers by import. |

## Rebuild

```powershell
$b = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
& $b -b --factory-startup --python Tools\Blender\mars_cooking\build_food_meats.py   -- --export --save --sheets
& $b -b --factory-startup --python Tools\Blender\mars_cooking\build_food_produce.py -- --export --save --sheets
& $b -b --factory-startup --python Tools\Blender\mars_cooking\build_food_mortar.py  -- --export --save --sheets
& $b -b --factory-startup --python Tools\Blender\mars_cooking\build_food_prep.py    -- --export --save --sheets
& $b -b --factory-startup --python Tools\Blender\mars_cooking\build_food_fryer.py   -- --oil --batter --save --sheets
```

Pass ABSOLUTE script paths when the shell's working directory is not the repo root (background shells on this machine
reset it). Each prints `FOOD_<CATEGORY>_OK`. Exports land in `D:\Repo\Content\Cooking\export\food\` (FBX + `.json`
sidecar per mesh, `<Name>_Mask_Mars_T.png`, the four `Oil*_VAT*_Mars_T.exr`, `OilVAT_Mars.json`), review sheets in
`export\food\review\`. Order matters: meats / produce export the heroes, `build_food_prep.py` reads them, and the
fryer's `--batter` pass reads every hero, cut and prep FBX. `--only A,B` on the prep builder (ingredient names) and on
the fryer (stems: `Mushroom_Slice`, `Puffer_Prep`) limits a run; `--batter-input <fbx>` batters any other mesh.

Unreal (editor Python over Monolith `editor_query run_python`, or the editor's Python console):

```python
import sys, importlib
sys.path.insert(0, r"D:\Repo\Mars\Tools\Blender\mars_cooking\unreal")
import mars_food_ue as mf; importlib.reload(mf)
mf.run_all()          # import_textures, import_meshes, build_materials, build_lookdev_map
```

`run_all` is driven by the sidecars, so new exports need no list: the prep meshes import with CPU access
(`mars_food_plan.wants_cpu_access`: the roster's `prep.cpu_access`, the ingredient's `cpu_access`, or the sidecar's),
each cut / prep / battered variant gets its own masked child instance, and the lookdev lifts battered meshes by
`shell_below_floor_cm`. Every battered mesh is re-imported because all of them moved to the raw-frame rule.

## The contract in one screen

- Units: builders work in cm, Z up; objects are created in metres at the origin and exported with the cooking_spec
  FBX settings (`-Z` forward, `Y` up, no scale, triangulated, linear vertex colours). Unreal local = (x, -y, z) cm.
- Pivot: centred in XY, lowest point at z = 0, long items along +X. Piles pivot at the mortar bowl floor centre;
  the pestle stands on its crushing head; the oil disc is a 1 m disc at z = 0 the game scales to its vessel.
- Battered frame rule (2026-10-10): `<X>_Battered_Mars_SM` is in the exact local frame of its raw input `<X>_Mars_SM`
  (raw core vertices unchanged, nothing re-centred), because the game swaps it in display-only at the raw piece's
  transform. The shell (1 cm offset, drips) reaches 1.5..2.5 cm below z = 0. Sidecar: `raw_source`, `frame: "raw"`,
  `pivot_shift_cm` (measured, Unreal local cm, always `[0, 0, 0]`; the build raises otherwise), `shell_offset_cm`,
  `shell_below_floor_cm`, `raw_bounds_min/max_cm`. A placer that wants it resting on a counter lifts it by
  `shell_below_floor_cm` (the lookdev does: `mars_food_plan.rest_lift`).
- UV0 atlas (Smart UV), UV1 `ShapeXY` / UV2 `ShapeZ` = raw -> cooked offset in Unreal cm (`uv1 = (ox, 1 - oy)`,
  `uv2 = (oz, 1)`), only on morphing meshes; VAT meshes carry `VATColumn` UV1 (`u = (i + 0.5) / n`).
- Vertex colour `Col`: linear RGB base albedo with per-facet jitter and warmer crevices, A = cavity.
- Mask textures (linear RGBA, TC_MASKS): R cook-first, G grain / speckle, B crust break-up, A rim.
- Custom Primitive Data: 0-3 sear +X -X +Y -Y, 4-7 sear +Z -Z / penetration / oil coat, 8-11 glaze / shape /
  fry / wet, 12 crumb coverage. Same first ten floats as `Meat_Mars_M`, so gameplay drives every cooking mesh the same way.
- Material slots: cooking slots `Flesh`, `Skin`, `Batter`; static accents `Horn`, `Bone`, `Leaf`, `Stem`, `Salt`,
  `Pepper`, `Stone`, `Wood`, `Oil`.

## Naming of variants

| Mesh | What | Material instances |
| --- | --- | --- |
| `<Ing>_Mars_SM` | the hero | `<Ing>_Mars_MI` |
| `<Ing>_<Cut>_Mars_SM` | authored cross section (`Mushroom_Half`, `Mushroom_Slice`) | `<Ing>_<Cut>_Mars_MI` (child, own mask) |
| `<Ing>_Prep_Mars_SM` | runtime-mesh variant (CPU access) | `<Ing>_Prep_Mars_MI` (child, own mask, Shape Scale 0) |
| `<X>_Battered_Mars_SM` | battered twin of raw mesh `<X>` (hero, cut or prep), same frame | `<X>_Batter_Mars_MI` + `<X>_BatteredCore_Mars_MI`; for X = Ing the original `<Ing>_Batter_Mars_MI` / `<Ing>_BatteredCore_Mars_MI`, for a variant children of them carrying the variant's own `<X>_Batter_Mask_Mars_T` |

Swap pairs (same transform, display-only): `<Ing>` <-> `<Ing>_Battered`, `<Ing>_<Cut>` <-> `<Ing>_<Cut>_Battered`,
`<Ing>_Prep` <-> `<Ing>_Prep_Battered`.

## Prep variants: the runtime-mesh contract

The game's runtime slicer (CkFoundation `CkRuntimeMesh`, `FCk_RuntimeMesh_ImportLimits`) imports a static mesh's
LOD0 only if it is ONE closed, connected, non-self-intersecting solid with positive volume, has at most 2048 RAW render
vertices (the position buffer, after Unreal splits corners on normal / UV / colour) and 4096 triangles, and the asset
has CPU access. A flat-shaded, per-facet-painted mesh has 3 render vertices per triangle, so ~680 tris is the ceiling
(`food_spec.PREP_TRI_BUDGET` = 660).

`build_food_prep.py` makes `<Ing>_Prep_Mars_SM` for each `INGREDIENTS[...]["prep"]` entry: import the exported hero,
split it into closed shells, `shells: "union"` boolean-merges the extra shells into the body (Exact solver) or
`"drop"` leaves them out, Decimate (collapse) to the budget with painted features (eyes, mouth, teeth: hero faces whose
colour stands well off the body colour) weighted to keep their triangles, then per face the slot + colour of the hero
surface seen along the face normal (so dropped shells still show as paint), alpha = own cavity, a fresh UV0 and
`<Ing>_Prep_Mask_Mars_T.png` transferred texel by texel from the hero's mask. No morph UV1 / UV2 (the slicer projects
every UV layer planar on its cut caps). Same frame and pivot as the hero, so the game can use either at one transform.

The checker, `food_common.check_runtime_mesh(fbx)` (`runtime_mesh_report` for report-only), re-imports the exported
FBX and FAILS the build unless: render vertices (unique position / normal / every UV / colour-byte corners) <= 2048;
tris <= 4096; after welding at 1e-4 cm (the importer's seam tolerance) every edge has exactly two triangles walking it in
opposite directions, no bowtie vertex, one component, no intersecting triangle pair, positive signed volume, no
triangle under 1e-5 cm2 or with an edge under 1e-3 cm; vertex colours present. It prints one `RUNTIME_MESH` line and the
numbers go into the sidecar's `runtime_mesh` block; the `prep` block lists what was merged / dropped. The Unreal
importer then warns if the imported asset's vertex count exceeds 2048.

| Prep mesh | Tris | Render verts | Shells | Notes |
| --- | --- | --- | --- | --- |
| `Drumstick_Prep_Mars_SM` | 660 | 1949 | bone shaft + 2 knuckle lobes unioned | |
| `Tentacle_Prep_Mars_SM` | 660 | 1980 | 16 suckers dropped | sucker rims painted onto the body |
| `Puffer_Prep_Mars_SM` | 658 | 1964 | 18 spikes unioned | eyes kept (painted, protected in the decimate) |
| `SpikedBerry_Prep_Mars_SM` | 660 | 1920 | 16 spikes + 2 small 4-tri front details (Skin) unioned | eyes, mouth and teeth kept |
| `Mushroom_Prep_Mars_SM` | 660 | 1980 | already one solid | plain decimate (the pale stem is a paint region, not a feature) |

Already within the contract, no prep twin: `MeatSlab_Mars_SM` (644 tris, 1926 render verts; also held to the prep
standard for cuttable meat below) and
`Mushroom_Slice_Mars_SM` (584 / 1748). Outside it (reported by `build_food_prep.py`, not rebuilt): `Mushroom_Half_Mars_SM`
(2622 render verts), `HerbPile_Mars_SM` (48 separate leaf / stem volumes, 8166 render verts).

## Prep standard for cuttable meat (2026-10-10)

Stephen's ruling: the steak minigame's `MeatCube_Mars_SM` (one cube, `Meat_Wagyu_Mars_MI` on `Meat_Mars_M`) sears per
face; a player who cuts meat at the bench must get the same behaviour and the same visual quality with the cut piece in
the pan, so meat that goes to the bench is prepped to a standard that makes that true. The cook model is six sear slots
(CPD 0-5: +X -X +Y -Y +Z -Z, Unreal local axes), each blended in by `pow(saturate(+-n), Face Sharpness)`, plus a cooked
band measured from the local bounds, so it only reads like the cube on a piece whose surface IS six faces.

An ingredient with `cook_standard=True` in `food_spec.INGREDIENTS` (every cuttable meat: category `meats` with
`cpu_access`; `food_common.cook_standard_of` applies it to such a meat even without the flag) fails its builder unless
the exported FBX passes `food_common.check_runtime_mesh` with these rules (constants `food_common.COOK_*`):

1. **Box-likeness for the six-face sear:** >= 85 % of the surface area has a face normal within 25 deg of one of the six
   local axes (`box_fraction`; the per-axis split and the nearest-axis split are reported too).
2. **Six real faces:** each of +X -X +Y -Y +Z -Z owns >= 5 % of the area within those 25 deg, so every ledger slot is a
   face the piece can rest on.
3. **Colour and UVs:** vertex colours with A = cavity in 0..1 and RGB albedo painted (not all white); UV0 inside 0..1
   and `<Name>_Mask_Mars_T.png` exported beside the FBX; morph UV1 / UV2 either absent or finite and <= the sidecar's
   `morph_max_cm`.
4. **The runtime-mesh contract** above (one closed solid, <= 2048 render verts / <= 4096 tris, no degenerates).

The checker prints a `COOK_STANDARD` line with every number (enforced, or `info` for other meshes) and the sidecar's
`runtime_mesh` block carries `cook_look` (box fraction, face split), `cook_attrs` (alpha / RGB / UV0 / mask / morph) and
`cook_standard` (enforced, ok, problems). `build_food_meats.py` runs it on every `cpu_access` meat after export and
raises when it fails; `build_food_prep.py` gets the numbers in its prep sidecars for free.

Beyond the mesh, a bench meat's look contract:

- **Materials on the food master.** Every slot of the bench meat and of its cut pieces wears one `Food_Mars_M` instance
  (`MeatSlab_Mars_MI`), so the whole piece reads the same CPD sear ledger; the vertex colours tell lean from fat.
- **Cap colour = flesh.** The runtime cut cap (slot 2 of a cut piece) is painted the meat's own cut-lean colour (the
  slab's `C(212, 36, 56)`, the colour of its authored end cuts), so a fresh cut matches the faces it sits beside.
- **Cuts only before cooking.** A piece is cut raw; the sear ledger starts at the cut. Cutting a seared piece would show
  raw-coloured caps beside crust with no band behind them.

The slab was re-shaped to meet the standard: a butcher-trimmed block (floor, two end cuts, two side trims and a fat-cap
trim, each a few degrees off true for the hand-cut read; the super-ellipsoid only shows at the rounded corners) with
blue-noise vertices dense along the creases (`SLAB_SP_EDGE` 1.35 cm) and sparse inside the trimmed faces (2.6 cm).

| Mesh (2026-10-10) | box (>= 0.85) | +X | -X | +Y | -Y | +Z | -Z | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `MeatSlab_Mars_SM` before (super-ellipsoid joint) | 0.785 | 0.055 | 0.054 | 0.114 | 0.109 | 0.206 | 0.247 | fail (box) |
| `MeatSlab_Mars_SM` (trimmed, 644 tris, 1926 render verts, 7561 cm3) | **0.911** | 0.069 | 0.070 | 0.144 | 0.141 | 0.245 | 0.242 | **pass** |
| `MeatSlab_HalfA_Mars_SM` (parity stand-in: the slab cut at x = 0) | 0.931 | 0.157 | 0.117 | 0.119 | 0.120 | 0.212 | 0.206 | rules 1, 2, 4 pass; no own mask (renders with the slab's) |
| `Mushroom_Slice_Mars_SM` (info) | 0.908 | 0.066 | 0.043 | 0.033 | 0.030 | 0.367 | 0.367 | fail (thin sides) |
| `Mushroom_Half_Mars_SM` (info) | 0.579 | 0.178 | 0.070 | 0.031 | 0.026 | 0.049 | 0.224 | fail |
| `Mushroom_Prep_Mars_SM` (info) | 0.479 | 0.032 | 0.034 | 0.032 | 0.036 | 0.105 | 0.240 | fail |
| `Drumstick_Prep_Mars_SM` (info) | 0.274 | 0.037 | 0.025 | 0.054 | 0.049 | 0.039 | 0.070 | fail |
| `Tentacle_Prep_Mars_SM` (info) | 0.390 | 0.007 | 0.035 | 0.067 | 0.052 | 0.100 | 0.128 | fail |
| `Puffer_Prep_Mars_SM` (info) | 0.332 | 0.055 | 0.052 | 0.038 | 0.039 | 0.064 | 0.084 | fail |
| `SpikedBerry_Prep_Mars_SM` (info) | 0.289 | 0.045 | 0.039 | 0.041 | 0.030 | 0.066 | 0.069 | fail |

The round heroes and their prep meshes are not cuttable meat and are not held to it; their numbers say how far a
per-face sear would read as a blend on them. The cube-vs-cut-piece look capture is `unreal/mars_cook_parity.py`
(`build_food_meats.py --only MeatSlab --export --parity_half <dir>` writes the half-slab stand-in it renders).

## Roster and results

Generated from the export sidecars (46 meshes, 2026-10-10; `OilBubble_Mars_SM` is under Niagara below). Every mesh: flat shaded, `Col` vertex colours, UV0 atlas, FBX + `.json` + mask PNG.

| Mesh | Tris | Size cm | Slots | Morph cm | Sidecar extras |
| --- | --- | --- | --- | --- | --- |
| `ColorSwatch_Mars_SM` | 60 | 15.0 | Stone | - | - |
| `Drumstick_Battered_Mars_SM` | 1664 | 22.5 | Flesh, Bone, Batter | - | raw frame |
| `Drumstick_Mars_SM` | 688 | 21.4 | Flesh, Bone | 1.7 | - |
| `Drumstick_Prep_Battered_Mars_SM` | 1596 | 22.5 | Flesh, Bone, Batter | - | raw frame |
| `Drumstick_Prep_Mars_SM` | 660 | 21.4 | Flesh, Bone | - | runtime_mesh, cpu_access |
| `HerbPile_Mars_SM` | 2766 | 16.0 | Leaf, Stem | - | manifold |
| `MeatSlab_Mars_SM` | 644 | 36.6 | Flesh, Skin | - | manifold, cpu_access, runtime_mesh (cook standard) |
| `Mortar_Mars_SM` | 1512 | 22.9 | Stone | - | bowl_floor_cm, bowl_inner_radius_cm |
| `Mushroom_Battered_Mars_SM` | 3242 | 14.4 | Skin, Batter | - | raw frame |
| `Mushroom_Half_Battered_Mars_SM` | 2114 | 14.2 | Skin, Flesh, Batter | - | raw frame |
| `Mushroom_Half_Mars_SM` | 874 | 11.9 | Skin, Flesh | - | manifold |
| `Mushroom_Mars_SM` | 1340 | 12.0 | Skin, Flesh | 1.4 | manifold |
| `Mushroom_Prep_Battered_Mars_SM` | 1596 | 14.4 | Skin, Batter | - | raw frame |
| `Mushroom_Prep_Mars_SM` | 660 | 12.0 | Skin | - | runtime_mesh, cpu_access |
| `Mushroom_Slice_Battered_Mars_SM` | 1412 | 14.1 | Skin, Flesh, Batter | - | raw frame |
| `Mushroom_Slice_Mars_SM` | 584 | 11.9 | Skin, Flesh | - | manifold |
| `OilBubbles_Mars_SM` | 3840 | 80.0 | Oil | - | - |
| `OilSurface_Mars_SM` | 7938 | 100.0 | Oil | - | - |
| `PepperPile_Cracked_Mars_SM` | 2089 | 10.5 | Pepper | - | footprint_radius_cm |
| `PepperPile_Ground_Mars_SM` | 482 | 11.3 | Pepper | - | footprint_radius_cm |
| `PepperPile_Whole_Mars_SM` | 2652 | 9.5 | Pepper | - | footprint_radius_cm |
| `Peppercorn_A_Mars_SM` | 320 | 1.0 | Pepper | - | - |
| `Peppercorn_B_Mars_SM` | 320 | 0.9 | Pepper | - | - |
| `Pestle_Mars_SM` | 544 | 18.0 | Stone | - | contact_point_cm |
| `Puffer_Battered_Mars_SM` | 3838 | 16.0 | Skin, Horn, Batter | - | raw frame |
| `Puffer_Mars_SM` | 1520 | 14.0 | Skin, Horn | 1.4 | - |
| `Puffer_Prep_Battered_Mars_SM` | 1750 | 16.1 | Skin, Horn, Batter | - | raw frame |
| `Puffer_Prep_Mars_SM` | 658 | 14.1 | Skin, Horn | - | runtime_mesh, cpu_access |
| `RoastHorned_Mars_SM` | 1308 | 30.8 | Flesh, Horn | 1.4 | - |
| `SaltCrystal_A_Mars_SM` | 52 | 2.5 | Salt | - | - |
| `SaltCrystal_B_Mars_SM` | 68 | 2.4 | Salt | - | - |
| `SaltCrystal_C_Mars_SM` | 54 | 2.6 | Salt | - | - |
| `SaltPile_Crystals_Mars_SM` | 1562 | 12.2 | Salt | - | footprint_radius_cm |
| `SaltPile_Dust_Mars_SM` | 482 | 11.5 | Salt | - | footprint_radius_cm |
| `SaltPile_Grit_Mars_SM` | 2312 | 11.7 | Salt | - | footprint_radius_cm |
| `ScaledPine_Mars_SM` | 1474 | 20.0 | Skin, Leaf | - | - |
| `SpikedBerry_Battered_Mars_SM` | 4254 | 11.7 | Skin, Horn, Batter | - | raw frame |
| `SpikedBerry_Mars_SM` | 1758 | 10.0 | Skin, Horn | - | - |
| `SpikedBerry_Prep_Battered_Mars_SM` | 1596 | 11.9 | Skin, Horn, Batter | - | raw frame |
| `SpikedBerry_Prep_Mars_SM` | 660 | 10.1 | Skin, Horn | - | runtime_mesh, cpu_access |
| `Tentacle_Battered_Mars_SM` | 4714 | 31.0 | Flesh, Batter | - | raw frame |
| `Tentacle_Mars_SM` | 1948 | 29.0 | Flesh | 3.3 | - |
| `Tentacle_Prep_Battered_Mars_SM` | 1596 | 31.0 | Flesh, Batter | - | raw frame |
| `Tentacle_Prep_Mars_SM` | 660 | 29.0 | Flesh | - | runtime_mesh, cpu_access |
| `TomatoBulb_Mars_SM` | 1640 | 12.0 | Skin, Leaf | 1.5 | - |
| `Turnip_Mars_SM` | 2016 | 16.0 | Skin, Leaf | 7.4 | - |

## Pickle (2026-10-12): a cut face drawn from local position

`Pickle_Mars_SM` (`build_food_produce.py --only Pickle --export`; 572 tris, 20.0 x 6.9 x 7.2 cm, 547 cm3) is a bench
ingredient that is its own prep mesh: one closed solid inside the runtime-mesh contract (`runtime_mesh=True` in
`food_spec` makes the produce builder run `check_runtime_mesh` on the export), straight along +X so every cross cut is a
round. Its cut face is not painted and not UV-mapped (the slicer gives a cap one colour and planar UVs anchored on the
blade): `unreal/mars_pickle_ue.py` builds `Pickle_Mars_M`, which reads the pixel's position in the piece's local frame
(the slicer never re-centres a piece) and draws the section that lies there: pale flesh, six seed pockets round a soft
core with a row of seeds along each, a thin rind. A cut across shows the round, a cut along shows the seed rows. The axis
and taper come from the sidecar's `section_*` numbers, which `build_pickle` writes from the same profile
(`pickle_radius`); change one, rebuild both. `Pickle_Mars_MI` (Section 0, the painted skin) is the mesh's slot and
`Pickle_Section_Mars_MI` (Section 1) the cap's slot in `Food_Pickle_Mars`. `mars_pickle_ue.run_all()` imports the one
mesh and rebuilds the master in place; `mars_food_ue.run_all()` would re-parent `Pickle_Mars_MI` onto `Food_Mars_M`
(its sidecar-driven instance pass does not know the pickle), so run `mars_pickle_ue.build_instances()` after it.

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

- Potato (stew / soup cuts) was mentioned but is not in the roster.
- Runtime slicing of the HerbPile is a gameplay feature (CkFoundation), not part of this library; the mesh is built
  closed and manifold so a slicer can cut it.
