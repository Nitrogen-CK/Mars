# Phase 4 contrast amendment — approved by user

The user explicitly approved this repair through the pending scope question. Apply only the bounded changes below after the current physical sequence ends and PIE stops. The prior placement/light correction remains used; this approval permits one additional contrast-only pass. Preserve all earlier failures and evidence.

## Confirmed observation

Two independent reviews of `physical-20261022/Bridge-clue-corrected-normal-camera.png` at original 1280x720/FOV90 cannot reliably name the left glyph without knowing the answer. Triangle and Cross are clearer, but complete-phrase readability fails. `Bridge-matched-before-after.png` preserves the task-light scale 1 to 0.03 comparison. The P4 cost cue also remains pale against its bright wall.

## Source-grounded candidate, not a proven cause

`Script/WorldObjects/Mars_MeshPart.as` defaults `FMars_MeshPart.Tint` to `Primary`. Its Primary branch changes only `PrimaryColor`; the existing ProtoGrid branch changes Primary/Secondary/Line colors together. The clue's DiscPart currently requests a dark PrimaryColor but leaves the tint mode at its default. Thus its secondary and line colors retain the material's original palette. This explains a plausible remaining contrast source; only the rendered result can establish that the proposed change resolves readability.

## Exact bounded repair

1. In `Script/WorldObjects/Mechanisms/Mars_BellkeeperClue_EntityScript.as`, set `DiscPart.Tint = EMars_MeshPart_Tint::ProtoGrid` beside its existing dark PrimaryColor. Keep the existing mesh, phrase, 60 cm glyphs, transform, spacing and shared glyph builder.
2. In `Tools/LevelDesign/anchor_plans/build_warrens.py`, allow a per-label RGBA color with the current `(232,218,178,255)` as its unchanged default. In `design_warrens_v7_geometry.json`, opt only `P4-stakes` into dark lettering `(32,24,16,255)`. Keep its corrected placement, size and exact wording. Regenerate live JSON and save through the existing builder.

This changes contrast only. No further lighting/placement changes, shared MeshPart/glyph implementation edits, new materials/assets, mechanisms, rewards, player input, district fill or MP work. Preserve all unrelated dirt and frozen v6 output. No commit or push.

## Cause-based implementation revision within the approved contrast repair

The first render passes full-phrase readability but fails the cue. Read-only runtime inspection proves the color reached the actual TextRender component (native RGB 16/24/32 because the existing Python constructor is BGRA), and its material is `DefaultTextMaterialOpaque`, `MSM_DEFAULT_LIT`. The material graph routes vertex color to BaseColor, with Emissive unconnected. Thus a missing color assignment is ruled out; changing another color constant is not justified.

An existing `/Engine/EngineMaterials/UnlitText.UnlitText` was inspected: `MSM_UNLIT`, masked blend, vertex color feeding Emissive, and the font mask retained. The lead authorizes an optional per-label `textMaterial`, used only by `P4-stakes`, to select this existing asset. Other labels retain their exact default material. Keep the current actual dark color, placement and lighting fixed for this comparison. No new material/shader/asset or AngelScript change. This is a different material-response test within the user's approved dark-lettering goal, following the stuck protocol's read-only branch diagnosis; it is not another speculative color/placement variation.

Show the exact scoped diff, checkpoint, verify static/frozen-v6/map/Jolt, read back the actual material, and capture the same cue view. Failure of this comparison is a STOP; no further variation is included.

## Gate and stop

- Show the exact owned diff before applying it. Capture source/config/map/Jolt and unowned-actor identity.
- Build through Toolbox and run the focused Bellkeeper family against final AS. Retain the earlier 57-test evidence only for byte-identical untouched implementations; do not relabel it as a fresh full gate.
- Re-run static validation, frozen v6 full manifest/summary invariance and saved map/Jolt support audit.
- Capture the same normal Bridge camera and actual chain-facing cost cue. Two independent viewers must reliably name all three glyphs and read the complete cue from pixels, without zoom/source inference. Preserve matched before/after evidence.
- Any failure: STOP and retain an explicit readability blocker. Do not add another variation.

Audio remains a separate acceptance boundary: ordinary captures are silent; a reversible process-only A/B proves dependence on the application-volume path. Diagnostic recordings do not prove normal heard loudness. No permanent audio setting change is included here.
