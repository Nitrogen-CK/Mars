# Production progress

Completed 2026-10-24. Starting commit: `793bd123b2d2f4ebe9f398487f4cf48992fc9f22`. No commit or push performed. Existing unrelated cookbook, Sandbox/Jolt, deleted maps, generated/source/config and submodule changes were preserved.

## Delivered

- All 88 Chain Crossing/Sluice catalog models generated in Blender 5.2 headless: 26,686 total triangles, UV0, assigned shared materials, explicit pivots, deterministic family tools and per-ID FBXs/previews.
- Packed Blender Asset Browser library with 88 marked entries in four catalogs. Shared diorama uses 259 linked collection instances of 37 models. Both saved files contain both scenes and open on the named scene.
- All 88 meshes, 28 material recipes and 62 textures imported under `/Game/Mars/Environment/ChainCrossingKit`; native axis settings, centimetre dimensions and slot assignments checked. Imported front +Y; runtime mechanism +X adapter is Unreal yaw -90 degrees.
- Saved Unreal kit-library and diorama maps, camera actors and isolated studio lighting. Reflected Blender scene placements match the FBX coordinate conversion.
- Existing Variant C WaterworksW/Canal/Brineworks Level Instances dressed using source-fitted placements: 125/275/816 instances, respectively; 1,216 total across 73 HISM groups. Owned local lamp lights use the existing live-level exposure. Rendering overrides are confined to those districts; original geometry/collision remains.
- `PREVIEW.html` contains all 88 previews/FBXs, Blender and Unreal dioramas, real PIE views, audits and rebuild instructions. `README.md` documents regeneration, fitting, import, reapply and exact backup rollback.

## Final evidence

- `Output/Reports/blender_validation.json`: fresh saved-library process passed all 88. Includes 32 matched vault shell triangle pairs with positive thickness; 77 images packed.
- `Output/Reports/unreal_import_all.json`: passed 88/88; maximum bounds discrepancy under 0.00004 cm.
- `Output/Reports/unreal_level_validation.json`: final recheck passed 39 original authored actors and 2,476 original instances against the pre-write snapshot. Meshes, transforms and collision profiles unchanged. All 1,216 added instances use NoCollision; no dirty map/content packages at final check.
- Toolbox editor build succeeded. Focused Warrens automation passed 6/6, zero selected failures/contamination, exit 0. No gameplay source changed during this production task. This is not a full-suite or regression-free claim.
- `Output/Reports/pie_final_gate.json`: completed eight seconds/324 samples, ok=true; delayed live probe confirmed `CHAIN_KIT_RUNTIME_COUNT_1216`; all monitored runtime-error patterns zero. `pie_live_identity.json` independently records 73 NoCollision groups in the UEDPIE Variant C world.
- `Output/Renders/PIE_SLUICE_FINAL.png`, `PIE_CROSSING_FINAL.png`, `PIE_CHAIN_DETAIL.png`: actual standing-height spectator views captured during live PIE, not editor substitutes. Final review-map screenshots are `UE_DIORAMA.png` and `UE_LIBRARY.png`.
- Final Python compilation and 88-ID FBX/preview/file-presence checks passed. Preview local links checked after regeneration.

## Resolved production defects / retained diagnostics

CCS18 warped shell quads had inconsistent top/bottom diagonals, allowing the upper surface to pierce the underside by 1.23 cm. Matching explicit triangulation and fitted ribs/springers fixed it; fresh geometry validation and runtime images cover the final rebuilt mesh. The green floor proxy was the source inlay, not the separate Cellar crate: only the inlay is hidden now; source collision and the real crate are retained.

One earlier direct Python map switch crashed with a fatal world-leak check; the refchain included retained Python UObject wrappers. No target tile had been modified then, and all three original package hashes matched the snapshot. Restarted via Toolbox and used guarded Monolith load_level plus Python cycle collection thereafter. All later district/review-map switches and saves succeeded. Do not reintroduce direct unguarded switches after loading World assets into Python.

An early rendered clip's initial ReadPixels capture raised one D3D12 null-texture ensure; its red report is retained. A separate manually stopped acceptance report also has ok=false because its requested duration was not completed. Neither is the final gate. Later native queued screenshots and the completed final PIE gate succeeded.

Review-map close-ups exposed an overbright ambient cubemap washing surfaces white. Final review lighting disables that contribution/bloom, uses a modest directional key, specified skylight and point lights; this never changes the live districts.

## Limits / follow-up

The source shortcut remains a lever-driven rising gate at world Z=0; planned crossing floor is -250 cm and there is no Sluice handwheel spawner. This visual task did not alter that gameplay contract. Separate moving mechanism meshes are supplied; the wheel on a storage crate is a noninteractive spare. No frozen art leaf overlays the moving gate.

Water/flame/drip/ripple assets are static material carriers, not full effects simulations. Physics-ready loose props, LODs/lightmap UVs and moving-mechanism skin integration remain separate work. No physical-input traversal, multiplayer or packaged-build acceptance is claimed.

The editor is back on `/Game/Mars/Maps/Warrens_VariantC_Mars_MAP`, outside PIE, camera framed on the dressed Sluice. Exact rollback uses the three timestamped original .umap copies under `Output/Reports/Backups/20261024-031008/`, with editor closed and later unrelated map edits preserved. Deleting owned actors alone does not restore the original render-material/visibility overrides.
