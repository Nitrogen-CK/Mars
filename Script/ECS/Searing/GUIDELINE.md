# Cook-state guideline: making a mesh that sears on the pan

Any mesh that goes to the searing station (and, before it, the cutting bench) must follow this contract, or it will
not sear, not cut, or not look like the reference cube. The contract is enforced in three places; the rest is
convention. Read this before authoring a new meat.

Where the pieces live:

| Concern | Owner |
|---|---|
| The per-face cook ledger on every piece (`Sear[6]`, `Batter[6]`, `OilCoat`, `Crumb`, `Battered`) | `Script/ECS/FoodPiece/Mars_FoodPiece_Feature.as` (`FMars_FoodPiece_CookState`), written only by its processor via `Request_SetCookState` |
| The six faces and the sear clock | `Script/ECS/Searing/` (`EMars_FoodPiece_Face`: +X −X +Y −Y +Z −Z in that order; 3 s per face to 1.0; Ready after all six) |
| The 14-float Custom Primitive Data block every cooking material reads | `Script/Common/Mars_CookState.as` (`utils_cookstate`) |
| What a food is (mesh, slots, cap, kind, mass, battered variant) | `Script/Food/Mars_Food_Def.as` (`UMars_Food_Def`, `Validate`) |
| The one place a piece's look is written | the `Write_Look` mixin on the food piece in `Script/Food/Mars_Food_Look.as` |
| The art contract and the checker | `Tools/Blender/mars_cooking/FOOD_LIBRARY.md`, `food_common.check_runtime_mesh(cook_standard=...)` |

## 1. How the pan decides what is cooking

The kernel knows nothing about the mesh's shape beyond its local bounding box. Each frame it rotates the six local axis
normals by the piece's rotation and takes the one pointing most downward as the face on the pan. Heat goes into that
face's slot. A face that reaches 1.0 is seared; the sixth seared face makes the piece Ready. The material then colours
each pixel by blending the six slot values with the pixel's **local normal** (Face Sharpness controls how hard the
blend is), and draws the cooked band inward from the local bounding-box planes.

Everything below follows from that: **the mesh must really have six faces that lie on its local axes**, and the
material must read the block.

## 2. Mesh contract (runtime mesh + six faces)

Enforced by the Blender checker (`COOK_STANDARD` line; a `cook_standard=True` ingredient fails its build otherwise) and
by CkRuntimeMesh at import (a failing mesh never becomes a piece).

- **One closed, connected, positive-volume solid.** No separate shells (eyes, spikes, bones as islands), no
  self-intersections, no degenerate triangles. Union or drop extra shells and paint them instead (see `build_food_prep.py`).
- **Under the ceiling:** ≤ 2048 LOD0 render vertices (counted after normal/UV/colour seam splits; flat shading costs ~3
  per triangle) and ≤ 4096 triangles. Aim for 600–700 triangles.
- **CPU access on** (`cpu_access` in `food_spec.INGREDIENTS`; the importer sets `bAllowCPUAccess`). Runtime-mesh
  sources import with degenerates kept, or the FBX importer can open the solid.
- **Box-like:** ≥ 85 % of the surface area has a normal within 25° of one of the six local axes, and each of ±X ±Y ±Z
  owns ≥ 5 % of that area. Bevels and a few off-true trims are fine (the slab is a butcher-trimmed block at 0.91);
  domes, drumsticks and spiky things are not, and will mis-bucket their sear.
- **Frame:** pivot at the base centre, long axis along +X, lying flat; the bench cuts along its local axes with 90°
  turns, so every cap lands on an axis and inherits a slot cleanly.
- **Size:** the board's chop budget and the pan's radius assume joints of roughly the slab's scale (37 × 20 × 12 cm).
  Portions thinner than the food's `Tuners` minimum (slab: 1 cm, 50 g) are refused by the cut.

## 3. Paint and UV contract

- **Vertex colour:** RGB = albedo (lean vs fat is paint, not a second material), A = cavity in 0..1 (crevices sear
  later). Never all-white.
- **UV0** inside 0..1 with a `<Name>_Mask_Mars_T.png` exported (the food master samples it; R is cook-first).
- **UV1/UV2** either absent or a finite raw-to-cooked morph offset within the sidecar's `morph_max_cm`. Cut caps keep
  the rim's interpolated morph (`Cap.Set_UVPolicy(PlanarOnLayer0_KeepInterpolated)`), so a morph does not tear at
  the cut edge, but prefer no morph on cuttable meat.
- **Slots:** name them `Flesh` / `Skin` (cook slots) and keep accents (`Bone`, `Horn`) to named slots only. The cap
  slot is the one after the last section.

## 4. Material contract

- Every cook slot **and the cap** wear an instance of the food master `Food_Mars_M` (or the cube's `Meat_Mars_M`).
  `Accent_Mars_M` reads no cook state: a slot on it never browns. Only a named `Bone` / `Horn` slot may use it.
- Start the instance from `MeatSlab_Mars_MI` (the reference slab) so Face Sharpness, band depth, crust, char and
  clear-coat parameters match the cube-era look; the parity sheet under `D:\Repo\Content\Cooking\export\review\parity\`
  is the reference for "looks like the cube".
- The block the material reads (`utils_cookstate::Make_CustomPrimitiveData`, four Vector4 groups):

| CPD index | Meaning | Range |
|---|---|---|
| 0–3 | Sear +X, −X, +Y, −Y | 0 raw, 1 full crust, >1.25 char |
| 4–5 | Sear +Z, −Z | same |
| 6 | Penetration (sum of sears, capped at 1) | 0..1 |
| 7 | Oil coat (the station's dressing) | 0..1 |
| 8 | Glaze | 0..1 |
| 9 | Shape (raw → cooked silhouette; mean sear) | 0..1 |
| 10 | Fry (batter heat mean) | 0 raw, 1 golden, 2 burnt |
| 11 | Wet (stew soak) | 0..1 |
| 12 | Crumb coverage | 0..1 |
| 13 | Battered | 0 or 1 |

Writes are deferred requests on the piece's `RuntimeMeshDisplay`, sent only when a float moved ≥ 0.02
(`constants_cookstate::k_WriteThreshold`) or when a face has just seared through. A battered piece also mirrors the
block onto its static-mesh shell.

## 5. Food definition contract (`Mars_Food_Def.as`)

`UMars_Food_Def::Validate` runs at composition and refuses a bad food with a reason; it is also pinned by
`FoodDef_EveryMeatFoodReadsTheCookState` (add every new food to that test's list by hand).

```angelscript
asset Food_<Name>_Mars of UMars_Food_Def
{
    Data.Mesh = assets::<Name>_Mars_SM();          // the prepped hero mesh
    Data.MassKg = <volume cm3 x density>;           // the sidecar's volume x ~1.05 g/cm3 for meat
    Data.Kind.AddTag(GameplayTags::Food_Meat_<Cut>); // Food.Meat gates the bench and the pan docks
    Tuners = FMars_FoodPiece_Tuners(0.05, 1.0);     // smallest portion: kg, cm
    // one food-master instance per slot, in slot order, then the cap's slot
    Visuals.Display.Set_Materials(Materials);
    Visuals.Cap.Set_MaterialID(<last section + 1>);
    Visuals.Cap.Set_Color(<cut flesh, linear, alpha > 0>);   // alpha is the cap's cavity
    Visuals.Cap.Set_CmPerUVUnit(<UV span of the mesh in cm>);
    Visuals.Cap.Set_UVPolicy(ECk_RuntimeMesh_CapUVPolicy::PlanarOnLayer0_KeepInterpolated);
    Layout.YawDegrees = 90.0;                       // long axis across the blade on the board
}
```

`Validate_CookLook` rejects a `Food.Meat` food with no cap material or a cap alpha of 0. Leave `Visuals.Battered`
unset on meat: batter is for whole fryable ingredients at the batter station, never for anything that is cut.

## 6. Pipeline, in order

1. Add the ingredient to `food_spec.INGREDIENTS` with `category="meats"`, `cpu_access=True`, `cook_standard=True`,
   and a build function in `build_food_meats.py`.
2. Export: `blender -b --factory-startup --python <abs>\build_food_meats.py -- --only <Name> --export --sheets`.
   The run must print `COOK_STANDARD ... PASS` and `FOOD_MEATS_OK`; read the numbers (box fraction, per-face shares,
   render verts) and the review sheet.
3. Import through `unreal/mars_food_ue.py` (`import_meshes` + `_import_textures` + `build_instances` for the new
   sidecar; runtime-mesh sources keep degenerates and get CPU access), resave the mesh once, regenerate
   `Script/Generated/MarsAssets.as` (`CkAssetRegistrySubsystem.generate_all_asset_registries()`).
4. Add the food definition (above) and an item in `Script/Items/Mars_Item_Food.as`; add the food to
   `FoodDef_EveryMeatFoodReadsTheCookState`.
5. Prove it: `--test-pattern FoodDef`, then `FoodPiece` (a prep-food import-and-cut test like
   `FoodPiece_APrepFoodImportsReadyAndCuts`), `Cutting`, `Searing` (`Searing_ACutSlabHalfSearsEverySideAndIsReady`
   is the template for "a cut piece completes"). Then look at it in PIE: crust, band, cap colour, oil sheen.

## 7. What breaks the contract

- A slot on `Accent_Mars_M`, or a cap with no material: the piece cooks in the ledger and never shows it.
- A mesh that is not box-like: faces mis-bucket, Ready may be unreachable, the band follows the wrong planes.
- Cutting after cooking: halves inherit the whole ledger, so a fresh cap would read as seared. The bench only takes
  whole joints; keep it that way.
- Raising the runtime-mesh ceilings as a constant: the import preflight packs keys with a 2048 radix.
- Writing the ledger from a station script, widget or actor: only the FoodPiece processor writes it, through a request.
