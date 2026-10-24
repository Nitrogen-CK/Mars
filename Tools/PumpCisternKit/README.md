# Pump + Cistern production kit

Open [PREVIEW.html](PREVIEW.html) for the actual level views, concepts, model sheets, per-model FBXs and evidence. [MODEL_LIST.csv](MODEL_LIST.csv) is the complete new/reused inventory generated from the saved library manifest.

## Scope and source

Full `LI_Warrens_WaterworksW`, including its connecting corridors and all six source ramps. Cistern continues into the lower `LI_Warrens_Hub`: only floors below -1.4m within plan rectangle `[4,36,29,45]`, plus the visible sides of upper floor voxels and six boundary galleries. Upper Arrival Hub walking surfaces are excluded. Chain Crossing/Sluice corrections remain a bounded section in Canal/Brineworks; Ford, Bone Bridge and Brine Larder are excluded.

Authoritative geometry is the saved original actor/instance snapshots, checked against `Tools/LevelDesign/anchor_plans/data/warrens_v8c.json`. New environment paintings establish silhouette, material and light direction; their staging does not override saved topology. The current Chain crossing is enclosed by source wall masses. Opening it into the canal painting would require a separate topology change.

## Deliverables

- `Concepts/ENV_Pump_R01.png`, `ENV_Cistern_R01.png`: stylized environment and player-view directions.
- `Concepts/PC01.png` through `PC05.png`: all 24 new prop/architecture models; `PC06.svg` specifies the exact polygon water carrier. Dimensions in `model_catalog.json` govern production over illustrated labels.
- `Output/PumpCistern_KitLibrary.blend`: 25 new assets, linked reused Chain collections, Asset Browser catalogs, packed textures and a neutral library scene.
- `Output/PumpCistern_Diorama.blend`: source-fitted instanced cutaway. Ceiling art and out-of-scope source-gallery context proxies are omitted from the cutaway only.
- `Output/FBX/`: centimetre-scale meshes, UV0, named material slots and explicit pivots. Mechanism parts remain separate for later opt-in animation.
- `Output/fitted_instances.json`: repeatable source-fitted placement, visibility/light declarations and coverage evidence.
- `Output/Reports/`: saved Blender, Unreal import, source preservation, runtime and focused automation evidence.

The new pump wheel, piston and service pipe branch are static art. The branch ends in a closed service cap; it does not simulate flowing water. The basin surface stays at original water height (1mm surface separation), with the retained bed and collision. Unsupported outlet/trickle art was removed after source checks found no supporting wall and dry bank beneath it.

## Unreal locations

New meshes: `/Game/Mars/Environment/PumpCisternKit/Meshes`.

Shared materials/textures and reused CCS meshes: `/Game/Mars/Environment/ChainCrossingKit`.

Review maps:

- `/Game/Mars/Environment/PumpCisternKit/Maps/PumpCistern_KitLibrary_Mars_MAP`
- `/Game/Mars/Environment/PumpCisternKit/Maps/PumpCistern_Diorama_Mars_MAP`

Assembled level: `/Game/Mars/Maps/Warrens_VariantC_Mars_MAP`.

Live dressing preserves the existing Level Instance boundaries. It adds owned HISM components with `NoCollision`. Original meshes, transforms and collision profiles remain in place. The source pump/root/water/gallery proxies are hidden only where declared; outside-section gallery visuals are restored with exact source-mesh/material instances. No gameplay code, Jolt generation, route, gate control or water volume is changed.

## Rebuild

From the repository root:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python Tools/PumpCisternKit/build_kit.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background Tools/PumpCisternKit/Output/PumpCistern_KitLibrary.blend --python Tools/PumpCisternKit/validate_blender.py
python Tools/ChainCrossingKit/fitted_placement.py
python Tools/PumpCisternKit/make_preview.py
```

`-- --no-render` skips renders. The shared Chain builder supplies procedural primitives, materials, UVs, Asset Browser entries, exports and instancing; `generators/pump_cistern.py` supplies this family's shapes. `surface_fitting.py` is a reusable rectangle/solid-union fitter parameterized by tile baseline, pivot, XY scope and floor-height range. `fitted_placement.py` owns the source-aware assembly.

For Unreal, import outside PIE using `import_assets.main()`. Open each target tile through guarded Monolith `editor.load_level`, after `ChainCrossingKit/unreal_scenes.prepare_switch()`, then call this kit's `unreal_scenes.dress('WaterworksW')` or `dress('Hub')`. Reapply removes only actors tagged `Mars.PumpCisternKit.Authoring.v1`. The Chain pass has a separate owner and must also be applied for its section props and Waterworks base material overrides.

Create/open review maps through guarded Monolith before `preview_world('KitLibrary')` or `preview_world('Diorama')`. Save an active tile with `LevelEditorSubsystem.save_current_level()`. Do not use generic package saving on a loaded inactive Level Instance: the editor's file reader may hold its package open. The observed failed save left all three checkpoint files byte-for-byte intact; its diagnostic log is retained separately.

## Verification and limits

`validate_unreal.py` compares all four saved source worlds to pre-write snapshots, including every original instance transform/mesh/collision and every new HISM transform/count/collision. `runtime_review.py` confirms the actual PIE world and both ownership groups, then captures delayed player-height cameras. These cameras are observations, not physical-input traversal or multiplayer proof. Focused Warrens automation uses `CkAuto/UnrealToolbox.exe`; no raw build/test engine invocation is used.

Original rollback maps are in `ChainCrossingKit/Output/Reports/Backups/20261024-031008` and `PumpCisternKit/Output/Reports/Backups/20261024-050500`. A pre-correction three-tile checkpoint is in `ChainCrossingKit/Output/Reports/R02/Before-20261024-045927`. Restore only the intended map with the editor closed, preserving later unrelated changes. No commit or push is part of this work.

Tuning: model envelopes/material choices in `model_catalog.json`; shape detail in `generators/pump_cistern.py`; lamp positions/intensities, original-light overrides and prop density in `fitted_placement.py`; surface separation `EPS=.008` in `surface_fitting.py`; water tint/opacity in the shared import/build material recipes. Source collision and topology are separate constraints, not art knobs.
