# Warrens Phase 5 review package

Status: PARTIAL — CkUSF material amendment completed2026-10-22; see current amendment section at the end. Historical pre-amendment identities/counts below remain evidence for that scene.  Batch A material/dressing and local-light axes accepted by author review, with bounded actual-input approaches passed. Four missing Batch A sound deliveries block batch completion; B/C and Phase6 remain unstarted. Final coherent checkpoint retained; PIE stopped and editor dirty0.

## Scope

- Implements `docs/plans/warrens-two-player-level-design/PHASE_5.md`; entry boundary is `PHASE_5_RECONCILIATION.md`.
- Repository `D:/Repositories/CkRepos/Orion`, branch `dev`. Layout and intention for two players; no MP, station/player/crawler/framework behavior or new audio system.
- GPT-6.1 Sol/xhigh production executor, Sol/high independent source reconciliation; root independently inspected source, hashes, original pixels and route receipts.
- Phase4 normal heard-audio remains unaccepted. The user advanced Phase5; the Phase1 receipt explicitly blocks only the missing Phase5 sound axis. This does not promote Phase4 full acceptance to green.
- Phase5 exit is unmet: only areas1-4 visual axes are authored; sound missing; areas5-12 presentation unstarted. Human recognition and simultaneous two-human play remain unobserved.

## Commits

Base/HEAD: `72d2f9592b854fd9948d0f7ec4aacc64e17b3fb3`.

`git -c submodule.recurse=false log --oneline 72d2f9592b854fd9948d0f7ec4aacc64e17b3fb3..HEAD` returned exit0 with empty output. No commit or push authorized or performed.

## Diffstat

`git -c submodule.recurse=false diff --stat 72d2f9592b854fd9948d0f7ec4aacc64e17b3fb3..HEAD` returned exit0 with empty output: there are no new commits. Implementation remains uncommitted; do not attribute the shared working-tree diff to this phase.

Owned production delta against the actual Phase5 entry: `evidence/phase-5/entry-20261022/phase5-owned-source.patch` (complete final four-path delta), with axis-specific `source-builder.patch` and `source-light-axis.patch`; `build_warrens.py`, `design_warrens_v7.py`, `design_warrens_v7_geometry.json`, generated `data/warrens.json`; seven new MIs under `Content/Mars/Environment/Warrens/Materials/`; generated Warrens map/all Jolt. Current/temp-emitted AS is byte-identical. Entry dirt is enumerated in `baseline.json.dirtyStatus` and preserved for its owners.

## Claims table

Evidence paths below are relative to `docs/plans/warrens-two-player-level-design/evidence/phase-5/`.

| Claim | Evidence kind | Pointer |
|---|---|---|
| Concurrent Control/Dial/Bellkeeper changes reconciled without unexpected relevant drift | VERIFIED-artifact | `reconciliation-20261022/independent-readonly-reconciliation.json`: final14 applied artifacts exact, protected28 exact, Control6 exact; accepted Bellkeeper/Dial final kernels retained. Root independently rehashed final14. |
| Coherent rollback checkpoints retained | VERIFIED-artifact | `entry-20261022/baseline.json`:115 entry copies; `preapply-materials-20261022/manifest.json`, `pre-ossuary-correction-20261022/manifest.json`, `pre-light-20261022/manifest.json`:122 copies each. Restore coupled source/map/allJolt/MIs, never map alone. |
| Fresh static gates pass on frozen final source | VERIFIED-artifact | `entry-20261022/light-source-invariance.json.staticGate`: `exit:0`, `checks:131`, `failed:[]`, `graphCases:320`, `negativeRejected:5`, `sourceHashAndMtimeDrift:[]`. Command: `python -B Tools/LevelDesign/anchor_plans/validate_warrens_two_player.py --negative-checks --output <artifact>`. Root independently rehashed all five launch files+mtimeNs before live light apply. |
| Frozen v6 default emission preserved | VERIFIED-rerun | Root `lead-source-gate.json`: independently executed entry/current pure builders; complete v6 manifest/summary and3875 effective mesh/kind/material/profile/transform assignments equal. Independent `independent-light-A-audit.json` repeats full v6 equality after light metadata. |
| Existing v7 collision/geometry/gameplay preserved | VERIFIED-rerun | `lead-source-gate.json` plus `reconciliation-20261022/independent-light-A-audit.json`: all4149 original mesh/profile/transforms exact, entities/labels exact; only presentation metadata added. AS SHA256 `5759a5949ce78c5382a60362bb192c8b29b54364f3a9015677af1ac6955f04ac` matches entry and temporary emission. |
| Seven owned material instances persist intended values | VERIFIED-artifact | `lead-material-gate.json`, `entry-20261022/material-persisted-readbacks.json`:7 exact post-reload parameter sets, explicit alpha1/LineWidth0; shared source MI hash unchanged. |
| Material setter return discrepancy diagnosed without engine change | VERIFIED-artifact | Installed `D:/Repositories/UnrealEngine-Angelscript/Engine/Source/Editor/MaterialEditor/Private/MaterialEditingLibrary.cpp:1165-1174,1253-1262` writes+Updates then returns unchangedfalse. Root and executor read source; actual persisted readbacks gate creation, not false return. First failed assertion retained. |
| New dressing is attached/supported and clear of protected spaces | VERIFIED-artifact | `entry-20261022/placement-preflight.json`; native corner bounds, protected rectangle checks; `lead-applied-light-gate.json` independently compares all18 native bounds to original/corrected receipts within1e-6m, all NoCollision. Pixel evidence is separate below. |
| Single Ossuary facade correction preserves original envelope | VERIFIED-rerun | Root `lead-ossuary-correction-gate.json`: only four at/yaw pairs change; actual positive-Y mesh face was diagnosed, then four facades flipped with pivot compensation. Four AABBs unchanged; repeated apply207→207; root full static rerun `lead-ossuary-corrected-static.json` actual exit0. |
| Local lights preserve global darkness controls and unrelated lights | VERIFIED-rerun | `reconciliation-20261022/independent-light-A-audit.json`: exactly2 scales+9 appended rows, every nonlight manifest field exact. Root `lead-native-light-gate.json`: native33→42, only hearth5200→1300 and Court1600→800 change among originals; all other fields exact; ambient.2/tint/exposure1/1/bias0 unchanged. Units are CANDELAS. |
| Native geometry audit remains green | VERIFIED-artifact | `entry-20261022/light-native-audit.json`: `samples:898`, `missing:0`, `startsClear:20`, `crawlsOk:6`, `lowTunnelBlocked:0`, `jolt:true`. The audit is geometry evidence, not an end-to-end pair test. |
| Saved scene and unrelated ownership preserved | VERIFIED-rerun | `lead-applied-light-gate.json`: root rehashed23 applied artifacts+1270 protected sources, drift0; compares unowned15 numeric transforms/class/path/tags exact,29 HISM groups/4149 instances,18 NoCollision dressing bounds. Map SHA `23b6886dc9de7b65777240bae97304759bc6fd3a1ffbe7294aa44587906a2348`. Identity taken after actual async cook completion Mars.log10737/04:28:35.063UTC. |
| Batch A visual axes pass author review | VERIFIED-artifact | Root `lead-pixel-A-gate.json`: opened original four matched room views, Well depth/P4 ordered glyphs/full cost wording and attachment details; hood/toolboard, connected chain, split monument, supported rubble, inward recessed niches and three lidded vessels readable. Four comparable camera pairs exactXY/angles/FOV90, eye settling<.2mm, no held lantern. `entry-20261022/batch-A-before-after.png` shows actual output. No bone-filled shelf claim. |
| Altered approaches and kitchen mounts pass bounded local input check | VERIFIED-rerun | Root `lead-route-A-gate.json` independently parses `entry-20261022/final-A-approaches/receipt.json`: errornull,44steps,9walks,22 reached waypoints,291samples; no setup event within walks; real EnhancedInput Mars_IA_Move; Searing/Cutting operatingtrue→false, final health100/empty worn packtrue. Root opened supported rubble and actual mounted/control/plate images. |
| Full cargo/pair/normal-audio acceptance | ASSUMED | Not examined this phase: simultaneous people, loaded cargo transfer, human room recognition and normal heard sound. Short single-actor empty-pack segments do not establish these. Phase4 normal heard-audio remains pending. |
| Phase5 audio and whole phase completed | ASSUMED | Four exact approved Batch A sound deliveries absent; B/C not started. Existing generic effects are not approved replacements; missing content is not intentional quiet. |
| Final cleanup/checkpoint retained | VERIFIED-rerun | Root `lead-closing-gate.json`: independently rehashed all122 current/copy checkpoint files,1270 protected sources and23 applied artifacts, drift[]; HEAD unchanged. Final native editor receipt has Warrens/PIEfalse/dirtyMaps0/dirtyContent0 and exact15 unowned. `closing-20261022/manifest.json` retains the coupled copies. |

## Risk-ranked hunks

1. `build_warrens.py:984-1034` — full rotated-box containment/exact source overrides can leak surface assignments across districts. Default v6 equality and current4149 geometry/profile/transform invariance independently rerun; ambiguous crossing pieces remain neutral.
2. `build_warrens.py:1715-1784` — typed assets resolve before deleting owned actors; effective material/profile grouping and dressing reuse ownership lifecycle. Wrong grouping can change collision across the entire map despite a cosmetic intention.29 groups/4149 native instances verified.
3. `build_warrens.py:1035-1050` — optional exact-match light overrides and task records must preserve existing summary/light alias and explicit fill fields. Independent pure-manifest/native readback comparison verifies only approved2+9 changes; existing renderer/exposure unchanged.
4. `design_warrens_v7_geometry.json` presentation block — imported pivots and front-face orientation can cause floating/blank geometry despite correct AABBs. Source-grounded four-facade correction retains exact envelopes; supported chain, table vessels and rubble reviewed in actual pixels.
5. Seven owned MIs — setters returnfalse after writes in installed engine; explicit RGBA/persisted readbacks authoritative. Source parent unchanged; selected grid removal changes surfaces, not collision or mesh interpretation.
6. Asynchronous editor save/collision cooking — early hashes are stale-green risk. Final identity after actual cook completion is coupled; restore map/allJolt/materials/source together.
7. Test harness state — stale local-player objects, fixture placement settling and wrong hotkeys can produce false physical claims. Exact live world guarded; low rubble eye rejected; mapped Tab exit confirmed source/runtime; setup placements explicitly excluded from traversal.

## Deviations

- Missing sounds are deferred only to their declared Phase5 sound axis by the approved Phase1 receipt. Batch A visual work advances under the new user request; batch completion/B/C remain held.
- Draft defects corrected before first apply: chain spacing, detached/double-rotated Ossuary facades, Court rubble overlap with c1, and exact inherited Well root overrides. Existing small cauldron vessels replace generic closed cylinders.
- Material API false-return assertion stopped the first attempt. Native implementation explains the result; explicit alpha/readback/save/reload used, with no engine or parameter-name guess.
- The original Well view mostly showed parapet. A separately recorded ordinary standing rim view is used for depth comparison; neither setup image is traversal.
- One material/dressing correction used: native positive-Y cubby face established, then four Ossuary facades flipped/pivot-compensated. Current output is recessed niches, not bone-filled shelves.
- Corrected-facade apply was mistakenly launched before its static run completed. Further writes were held; `sequencing-violation.json` retains this. Executor actual exit0 and root independent full131/320/5-negative run completed on exact frozen source/artifacts; acceptance held until both. Light apply correctly waited for its final static exit0 before starting.
- Null-editor-world light sphere preflight rejected; retained `light-origin-native-preflight-REJECTED-null-world.json`. Valid9-source query used actual Warrens editor world/207actor guard.
- One rubble detail settled below the rim and is rejected as ordinary approach proof. Final supported actual-input arrival replaces it; original is retained.
- Walk harness rejected a stale null-world player before inputs and used Q incorrectly once for station exit. Failed receipt retained; source `Script/Inputs/Profiles/Mars_Gameplay_InputProfile.as:186,189` confirms Tab=Back/Q=StationAddFood. Resumed the same mount with Tab, then observed exit. No source/gameplay repair or repeated successful walk.
- No local-light correction was needed after the first approved pass; material/dressing frozen through lighting and final approaches.

## Baseline diff

Baseline `entry-20261022/static-baseline.json` → final `light-static.json`:131 checks/320 graph cases/5 negative rejections retained, exit0, failed[]. Native baseline→final:898 samples/0 missing,20 starts,6 crawls,lowTunnelBlocked0,Jolttrue. No new source build or automation run is claimed: PHASE5 expressly permits Python/assets-only gates when emitted AS is identical, as verified here.

Prior Phase4 focused52→57 and postcontrast Bellkeeper10 belong to their captured prior source and are not relabeled fresh Phase5 runs. The final local route check covers9 short segments/22 waypoints with an empty worn pack, not full P2/P3, two-human play or MP.

## Open questions / follow-ups

1. Supply original/licensed approved `HearthCooling_Mars_SND`, `WellDripChain_Mars_SND`, `CourtLooseStone_Mars_SND`, `OssuaryDryTick_Mars_SND` under `/Game/Mars/Environment/Warrens/Audio/`, with source/rights records. Then author positional sources and listen at threshold/centre/adjacent room. No generic substitutions or fabricated audio system.
2. B/C remain unstarted until A completes or the user explicitly authorizes a different axis ordering. No Phase6, commit or push.
3. Normal heard audio, voluntary pair role-swapping and room recognition require human observation; current geometry and single-player input proof do not substitute.
4. Tunable values: v7 presentation `regions`, `sourceOverrides`, `dressing`, `lightOverrides`, `taskLights` in `design_warrens_v7_geometry.json`; retain global ambient/exposure and original collision.

## Current CkUSF amendment - 2026-10-22

User explicitly requested replacing regular greybox appearance with CkUSF. [Amendment](../../plans/warrens-two-player-level-design/PHASE_5_CKUSF_MATERIAL_AMENDMENT.md), [complete session rundown](../../plans/warrens-two-player-level-design/SESSION_RUNDOWN.md).

- Actual source delta is opt-in `presentation.defaultMaterials` before existing region/exact overrides, material definitions and regenerated-equivalent JSON.7owned MIs reparented+3neutral MIs created from existing CkUSF Displace; all3scalars0, alpha1, BaseColor palette/.55. No new shader, AS or plugin change.
- Current14dressing materials use owned CkUSF;4retain authored nongrid kit textures. All4,149 environment instances and18dressing pieces are ProtoGrid-free. Shared runtime gameplay grid materials remain; no global actor claim.
- Current evidence lives in `evidence/phase-5/ckusf-20261022/`: root `lead-material-gate.json` checks10persisted parent/palette/zeros and unchanged shared assets; `lead-source-gate.json` independently executes v6/v7 and proves3final source files byte-identical to reviewed draft; final canonical static exit0/131checks/320graph/5negative rejections precedes live apply.
- Root `lead-native-pixel-gate.json` independently compares all4,149 native assignments to final source (quaternion reconstruction within saved6dp precision),42lights/PP/15unowned exact,16camera pairs exact angles/FOV90 and<1mm settling; original pixels and12area atlas reviewed. Native audit898/0missing,20starts,6crawls,Jolttrue. Pit near-field/B-C finished lighting remains unaccepted.
- One material bucket merges29->28HISMs,216->215actors, instances unchanged. Current map SHA256 `6e5a611f8976f77c4fd3b110cc859b4065ed5381a88a8dd24be5932a10ed3ad2`. Root `lead-closing-gate.json` independently rehashes126current/copy checkpoint files,1270protected sources and26applied artifacts, drift[]; HEAD unchanged,PIEoff/dirty0. These current identities supersede pre-amendment23-artifact identities above.
- No new gameplay/input/full-suite run is claimed for this Python/assets-only source-invariant amendment. Four A sounds, B/C district presentation, Phase4 heard audio and human-pair evidence remain pending. No MP/commit/push.
