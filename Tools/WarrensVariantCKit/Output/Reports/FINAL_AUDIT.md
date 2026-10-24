# Variant C art delivery audit

The art pass covers all **11 original district Level Instances, 24 named room records and the persistent Main surround**. The library contains **196 reusable models: 83 new and 113 reused**. Final saved dressing contains **37,511 visual instances**. Original routes and district transforms were retained.

## Confirmed evidence

| Gate | Result | Evidence |
|---|---|---|
| Catalog and references | 150 source mappings; existing district concepts and model sheets reconciled against authoritative source IDs | `../../model_catalog.json`, `../../SOURCE_REVIEW.md`, `../../MODEL_COVERAGE.md` |
| Fresh saved Blender artifacts | 196 entries; 54,063 unique-model triangles; UVs/materials/bounds/pivots/packed images/exports pass; five hero socket contacts and hollow-bell rays pass | `blender_validation.json` |
| Final Unreal imports | All 196 saved mesh/export SHA256 pairs, material bindings and absent generated collision checked | `unreal_final_import_validation.json` |
| Source preservation | 190 original actors and all 7,481 original source instances retain meshes/transforms/collision; final 37,511 art instances match the fitted ledger | `unreal_level_validation.json` |
| Runtime ownership | 37,511 art instances, all NoCollision, previous partial passes absent; 67 translucent non-shadowing lantern inserts | `runtime_instances.json`, `pie_final_sluice_r06.json` |
| Full room capture | 24 actual PIE room views; 3,994 sampled frames; 49 probes passed; monitored runtime errors zero | `pie_final_rooms_r05.json` |
| Boundary/protected views | 21 seams and 10 protected views; 5,307 frames; 63 probes passed; monitored runtime errors zero | `pie_final_boundaries_r05.json` |
| Final Sluice changes | Changed room and four Brineworks seams recaptured after the last placement edit; 1,392 frames and 11 probes passed | `pie_final_sluice_r06.json` |
| Focused automation | Anchor 41/41; the six Warrens checks remain 6/6 versus baseline; both gameplay Gate tests pass | `toolbox_verification.json`, `Toolbox-Anchor.log`, `Toolbox-Gate.log` |
| Reusable Unreal review maps | 196-entry kit library and 32,343-instance ceiling-free cutaway saved separately from gameplay | `unreal_KitLibrary.json`, `unreal_Diorama.json` |

The broader Gate-name test filter ran 52 tests: 51 passed, one failed, contamination zero. Its sole failure is the **listed known red** `Monolith.ReflectionIntel.Risk.ConditionalGateSweep`; Toolbox exited 0 with no new failures. This is a focused gate, not a full regression run.

## Findings corrected during review

- Preserved all eleven Mill walking-deck strips instead of treating narrow deck strips as rails; removed duplicate structural veneers and shared endpoints.
- Fitted exposed upper/lower source surfaces and persistent-map surround, including the 524 original source instances outside the tiled baselines.
- Corrected Bone Bridge identity, kept its 2.9m inner rail width, and placed four cap lanterns on the actual asymmetrical post positions.
- Supported the hoist's four feet on rim-embedded bearers; seated bone bundles on shelf boards; suspended the chime beam from the actual roof instead of placing new piers across routes.
- Removed the unsupported plaque and route-crossing story rock. Preserved working controls rather than adding frozen decorative leaves or invented handwheels.
- Replaced compressed repeated vault skins with broad masonry soffits against the retained flat roof undersides. Their nominal minimum generated visual clearance is 2.18m (2.2m source clearance minus 12mm soffit and 8mm floor projection); source low crawls are separate retained geometry.
- Reduced the bell cavity light and added exterior crown lighting. The hollow bell, rim, clapper and supporting frame are now distinguishable in the reviewed views.
- Diagnosed lantern darkness with an actual matched PIE experiment: disabling only the opaque insert shadow reveals the bridge deck/rails. The insert now uses the existing translucent Glass material and does not cast an opaque shadow; brightness/exposure was not used to conceal the defect.
- Added default-null per-placement gate materials through the existing Gate/Anchor parameter path. Final Variant C bindings remove the blue Larder gate patch; other levels retain the original fallback. Geometry, control timing, channels, threshold logic and indicator tint were untouched.
- Corrected nine boundary camera directions and the north-rim room target against actual source solids; retained protected camera/target contracts.
- Repaired the inherited Sluice brace joints. Exported wood sockets drive placement after normalization. All 32 actual wood endcap vertices lie inside their intended post/header supports, with minimum surface distance 24.74458mm. The uprights back onto the original wall, and the shared header rests on their tops. See `sluice_saved_mesh_contact_audit.md` and its replayable probe.

## Visual audit and precise limits

Fresh independent pixel reviews cover all 24 room images and all 31 boundary/protected-view images: `runtime_visual_review_west_r05.md`, `runtime_visual_review_east_r05.md`, `boundary_visual_review_r05.md`. The final Sluice replacement views are reviewed separately in `runtime_visual_review_sluice_r06.md`. Exact current PNG hashes, times and camera metadata are recorded in `runtime_capture_manifest.json`.

The lit portions establish coherent masonry/floor transitions, readable bridge rails/deck, seated visible props and improved Cellar/Vault context. Dark or cropped contacts remain explicitly unverified; an image existing is not an acceptance result. Source/math checks supplement those views, rather than being presented as physical traversal proof.

The local gallery's 196 model cards, 55 runtime cards and 681 file references pass static validation, and its inline JavaScript passes `node --check`. Interactive browser QA was blocked because the browser security policy denies local-file URLs. No HTTP server, alternate browser or protocol workaround was used; interactive filters are not reported as browser-tested.

**Pre-existing P4 gap:** the source plan describes a Bellkeeper dial lock and three-glyph clue, but contains no Bellkeeper encounter configuration, and the saved baseline has neither actor. The housings stay blank. The protected glyph sightline therefore cannot show a readable answer. This art pass did not invent a phrase, puzzle solution or functioning lock.

Existing prototype controls/indicators remain where their runtime art contract is outside this dressing pass. Optional kit leaves, ladder pieces and dial parts are available for later runtime binding; static copies were not placed over active mechanisms.

This delivery does not establish physical-input feel, every capsule traversal, co-op/network behavior, packaged Level Instance/Jolt collision or packaged cooking. The original LevelIdentityIsStable cook issue was not repaired here. Visual saves temporarily pause only the automatic cook callback and restore the in-memory setting immediately; no persistent user-setting change is part of the pipeline.

## Rebuild, adjust and rollback

`../../fitted_placement.py` owns deterministic assembly positions, source fitting, lantern placement and local light intensities. `../../build_kit.py --render-scenes DIORAMA,ZONE_Brineworks` can rebuild/save every assembly while rendering only selected contexts. Shared timber joints export named sockets; source dimensions can change without hand-replacing brace offsets. Reuse the shared Blender Builder, collection instances and Unreal HISM authoring functions rather than duplicating meshes.

`../../unreal_scenes.py` owns opt-in map application and separate review-map illumination. `../../make_views.py` owns source-fitted review cameras. `../../make_preview.py` rebuilds the local evidence gallery. Existing source geometry and collision stay authoritative.

Rollback: close Unreal before restoring only the recorded map checkpoint copies (`checkpoint.json` and the Main backup record). Owned assets/art are tagged for repeatable reapplication. Clear the per-placement material overrides to restore prototype gate presentation. Do not reset unrelated worktree changes.

All work remains **uncommitted and unpushed**, as requested scope contains no commit/push instruction. Unrelated cookbook/plugin/Sandbox/config/generated changes were preserved.
