# Warrens material readability repair

## Orange landmark follow-up

The user subsequently requested familiar orange accents on stairs and ramps. `TraversalOrange_Mars_MI` uses the existing opaque-lit CkUSF ProtoGrid parent and the original orange platform palette. The opt-in `presentation.traversalAccent` selects the service spiral's 54 bands (18 treads) and 13 ramp segments. Flat floors, landings, rails and walls keep their current palettes. The saved map splits the stair bands into one additional render group; all 4,149 geometry transforms and collision profiles remain exact. Mechanism and non-greybox actor state is untouched. The Jolt bake was updated for the render regrouping and validated.

Evidence: `Saved/WarrensOrangeLandmarks-20261022/`. Four matched PIE views; before/after stair image; 131 static checks, 320 route cases and five rejected negative fixtures. Native audit: 898 support samples, zero missing, 20 clear starts, six valid crawls, no blocked low tunnels, valid Jolt. The complete frozen-v6 manifest and summary remain identical with the opt-in accent absent. Changes are committed locally; nothing is pushed. The earlier ten-material repair below remains the baseline for this follow-up.

2026-10-22, America/Toronto. Supersedes the flat Displace material amendment. The user explicitly approved distinct CkUSF treatments and the earlier CkUSF grids as a blockout fallback. Layout and mechanisms remain unchanged.

The previous replacement used one displacement-demo parent with every variation scalar zero. It retained valid material assignments but removed visible surface structure. That visual acceptance was inadequate.

## Saved result

| Family | Blockout treatment |
|---|---|
| Stone, mortar and mineral | Existing CkUSF ProtoGrid, world-scaled joints, per-surface palette and grid spacing. Neutral floor/wall/roof retain readable measurement grids. |
| Soot timber and root wood | Existing CkUSF ProtoGridUV with elongated plank bands and warm/olive brown palettes. This is a blockout plank pattern, not finished wood grain. |
| Bone | Fine 25 cm ivory/ochre grid with subdued joints. |
| Iron | Steel-gray 50 cm plate grid. The tested StudioCopper metallic treatment read almost black under the unchanged kitchen lighting, so the approved grid fallback was selected. |

Only ten Warrens-owned material instances, their export sidecars and the `presentation.materials` definitions in the geometry/live JSON changed. No shared master, shader, map, collision bake, light, mechanism or gameplay source changed. Rebuild definitions are canonical in `Tools/LevelDesign/anchor_plans/design_warrens_v7_geometry.json`; the matching emitted data is `data/warrens.json`.

## Current-session evidence

Local evidence is under `Saved/WarrensMaterialRepair-20261022/` and is not committed with this document.

- `baseline.json` and `baseline/`: 46 source/asset snapshots, entry commit and file mtimes. Prior post-rebase Jolt result was 157/157; no new gameplay-suite claim is made for this material-only repair.
- `material-readbacks.json`: all ten instances saved, package-reloaded and compared to intended parent/scalar/vector values. Both final shared parent shaders are opaque, DefaultLit and support instanced meshes.
- `final-static.json`: actual process exit 0; 131 checks, 320 connected route cases, five negative fixtures rejected.
- `camera-verification.json`: 16 actual PIE player-camera before/after pairs, covering all 12 areas plus useful Well and P4 clue/cost views. Matching FOV 90 and angles; maximum eye delta 0.000662 m. All 42 authored lights and exposure settings match. Python Color allocation addresses are normalized out; their RGBA values are compared.
- `before-after.png`: kitchen, Ossuary, Pump and Root Grotto comparisons. `all-areas-before-after.png`: all 12 area pairs. Original 1280x720 images and capture receipts remain in `before-clean/` and `after-final/`.
- `source-verification.json`: all 24 protected files unchanged, including the map, baked collision, Bellkeeper sources and shared CkUSF parents/shaders. JSON differences are confined to material definitions; all ten sidecars match asset MD5 identities.
- `native-verification.json`: all 215 editor actors, static-mesh transforms, collision profiles, instance counts and material-slot paths match the entry snapshot. Map and content dirty counts are zero after save/reload; PIE is off.
- `log-verification.json`: no material compile failure, default-material fallback or shader-compiler error after the repair marker.

Capture placement uses fixture teleports and proves visual rendering, not traversal or two-human acceptance. The first screenshot callback repeated its first frame through re-entry; a guarded capture produced the clean 16-pair baseline used above. The physically metallic trial is retained separately and is not the final result. No lighting, layout or mechanism correction was used to improve these comparisons.

Changes are committed locally; nothing is pushed. Missing Phase5 audio, later presentation batches, normal heard-audio acceptance and human-pair acceptance retain their previous status.
