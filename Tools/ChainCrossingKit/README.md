# Chain Crossing / Sluice procedural kit

Open [PREVIEW.html](PREVIEW.html) for all model thumbnails, FBXs and review images.

## Deliverables

- `Output/ChainCrossing_KitLibrary.blend`: all 88 catalog assets, marked for Blender's Asset Browser, four catalogs, packed images, neutral library scene.
- `Output/ChainCrossing_Diorama.blend`: the same shared data plus the assembled crossing study; opens on the diorama scene.
- `Output/FBX/`: one centimetre-scale static mesh per CCS ID, separate moving mechanism pieces, UV0 and material slots.
- `Output/asset_manifest.json`: actual bounds, catalog envelopes, pivots, triangles, slots and construction flags.
- `Output/fitted_instances.json`: placements fitted independently to saved Variant C geometry, not copied from the diorama composition.
- `Output/Reports/`: Blender, Unreal import, preserved-geometry and runtime evidence. Timestamped original tile backups are under `Reports/Backups/`.

The saved `.blend` files contain both scenes. Library entries and the diorama use linked collection instances, not copied geometry. Unreal uses one HISM component per distinct mesh in each scene/tile.

## Unreal locations

All imported assets live under `/Game/Mars/Environment/ChainCrossingKit`:

- `Meshes`: all 88 static meshes.
- `Materials` and `Textures`: shared surface families, atlas, masked wear/flame and translucent water/glass.
- `Maps/ChainCrossing_KitLibrary_Mars_MAP`: all 88 models with labels.
- `Maps/ChainCrossing_Diorama_Mars_MAP`: standalone instanced assembly.

Live dressing is in these existing district assets, preserving their Level Instance boundaries:

- `/Game/Mars/Maps/Variants/v8c/LI_Warrens_WaterworksW`
- `/Game/Mars/Maps/Variants/v8c/LI_Warrens_Canal`
- `/Game/Mars/Maps/Variants/v8c/LI_Warrens_Brineworks`

Open `/Game/Mars/Maps/Warrens_VariantC_Mars_MAP` to see the assembled level.

## Rebuild in headless Blender

Run from the repository root in PowerShell:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python Tools/ChainCrossingKit/build_kit.py
```

Useful parameters after `--`:

- `--seed 1031`: deterministic shape variation; default seed.
- `--no-render`: generate/save/export without the 90 review renders.
- `--only CCS21,CCS27`: bounded family iteration. Subsets write below `Output/Subsets/<hash>` and cannot replace the complete library.

Geometry tools are reusable, parameterised primitives in `build_kit.Builder`. The architecture, mechanisms and dressing family modules receive dimensions/materials from the catalog. Water carriers are generated in the core. Change an individual silhouette in its family module; change section arrangement in `placement.py`; change live fitting in `fitted_placement.py`.

The art source is `docs/art/warrens-c-dressing-r01/sections/chain-crossing-sluice/model_catalog.json`; shared texture recipes are in that art pack's `materials.json`. Blender works in metres. FBX export explicitly writes centimetre vertices with unit scale 0.01; Unreal import independently verifies all three bounds axes. Flat cards legitimately have one zero-depth axis; actual mesh dimensions are recorded separately from proposed art envelopes.

Axis contract: neutral Blender is X/right, front -Y, Z/up. The native Unreal FBX importer uses `convert_scene=True`, `force_front_x_axis=False` and maps vertices to `(X,-Y,Z)`. Imported front is therefore +Y. A mechanism modeled with Blender front -Y needs an Unreal **yaw -90 degrees** adapter to face the runtime actor's +X axis. The `mesh_adapter` flags in the Blender manifest describe the neutral Blender frame; Unreal asset metadata/report records the converted adapter. Review scenes convert Blender placements with the same reflection; the live fitter already outputs native Unreal coordinates.

## Validate and import

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background Tools/ChainCrossingKit/Output/ChainCrossing_KitLibrary.blend --python Tools/ChainCrossingKit/validate_blender.py
python Tools/ChainCrossingKit/fitted_placement.py
python Tools/ChainCrossingKit/make_preview.py
```

Run the importer in Unreal editor Python, outside PIE:

```python
import runpy
runpy.run_path('D:/Repositories/CkRepos/Orion/Tools/ChainCrossingKit/import_assets.py')['main']()
```

For a smoke import pass `['CCS01']` to `main`. Existing imports must have this tool's ownership metadata and the identical source path; foreign assets are refused. The importer restores the previous Interchange FBX flag, matches material slots by name, removes generated collision and verifies imported bounds. It saves only owned assets.

## Reapply a district

1. Save unrelated editor work. `snapshot_unreal.py` refuses dirty maps and creates timestamped copies. Keep the original production baseline when iterating; do not replace it with an already dressed snapshot.
2. Run `fitted_placement.py` in ordinary Python after editing the fitter.
3. Run `unreal_scenes.prepare_switch()` in editor Python. It checks dirty packages and collects unreachable Python cycles.
4. Open the tile with Monolith's guarded `editor.load_level` action. Do not bypass it with a direct map-load call after inspecting World assets in Python. A stale resident world can trigger Unreal's fatal world-leak check.
5. Execute the following with the matching tile key:

```python
import runpy
runpy.run_path('D:/Repositories/CkRepos/Orion/Tools/ChainCrossingKit/unreal_scenes.py')['dress']('Brineworks')
import gc
gc.collect()
```

Keys are `WaterworksW`, `Canal`, `Brineworks`. Each pass removes only exact-tag-owned dressing actors, replaces them, applies declared source visibility/material overrides and saves that tile. Original transforms, geometry and collision profiles are retained. Prototypes used as collision proxies stay present: only their rendering is hidden. The hidden floor chain proxy is `Warrens_Greybox_inlay`; the separate Cellar prop remains visible.

The fitter's `seed`, `detail_density`, ROI and source pivots are explicit parameters/constants. `unreal_scenes.py` owns the wall-lamp intensity (currently 6), color and radius. Lighting uses the existing level exposure and ambient settings.

`preview_world('KitLibrary')` and `preview_world('Diorama')` rebuild their respective already-open owned review maps. These use separate neutral studio lighting and fixed exposure; that setup never changes the live districts. Saved camera actors frame the kit/assembly; pilot the camera to use its 65-degree FOV.

## Verification

Fresh saved-library audit: 88 assets, 26,686 triangles, UV0/materials/packed images, 88 linked library entries and 259 diorama placements. Unreal import audit passed all 88 meshes, with maximum bounds discrepancy below 0.00004 cm. Saved district audit checked 39 original authored actors and 2,476 original instances against the pre-write snapshot: transforms, meshes and collision profiles retained. Dressing adds 1,216 instances across 73 HISM groups.

Toolbox editor build succeeded and the focused Warrens automation gate passed 6/6, with no failed or contaminated selected tests. Final eight-second PIE gate completed cleanly and its delayed live-world probe confirmed all 1,216 dressing instances. `Output/Renders/PIE_SLUICE_FINAL.png`, `PIE_CROSSING_FINAL.png` and `PIE_CHAIN_DETAIL.png` are actual PIE standing-height spectator observations. These checks do not establish physical-input traversal, multiplayer or packaged-build acceptance. Earlier failed capture diagnostics are retained separately; use `Reports/pie_final_gate.json` for the final runtime verdict.

## Gameplay boundaries and current source mismatch

The current map's Chain shortcut is a lever-driven rising gate at world Z=0. The design describes the crossing at Z=-250 cm and a wheel in the Sluice, but the saved Brineworks tile has no handwheel spawner. This kit preserves that implementation. It does not install a frozen gate leaf over the runtime leaf or create an unwired control. The visible wheel on the storage crate is a noninteractive spare. All active mechanism parts are supplied separately in the asset library for a later opt-in visual integration.

The diorama is an assembly study of the intended arrangement, not proof of the current gameplay wiring. Water/flame/drip/ripple assets are material carriers/static art, not complete flowing-water or particle simulations. Physics-ready loose props, LOD authoring, lightmap UVs, networking and packaged-build acceptance are outside this visual pass. Current maps retain existing collision; new dressing uses `NoCollision`.

## Exact rollback

The authoritative rollback paths and original SHA256 hashes are in `Output/Reports/level_baseline.json`. Close the editor, then restore the three named `.umap` copies to their recorded original paths. This restores original materials/visibility as well as removing dressing. Removing owned actors alone does **not** restore the original component render overrides. Preserve any subsequent unrelated map edits before using the byte-for-byte backups.

No commit or push is part of this task. Existing cookbook/Sandbox/source changes are unrelated and remain owned by their original workstreams.
