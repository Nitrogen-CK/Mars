# Warrens Phase 3 review package

Phase 3 is complete under the approved local fixture/query acceptance scope. Route semantics, fixed rewards, pack recovery, actual kitchen operations, occupied-position envelopes and final saved-map audits pass. No MP, Phase 4, complete meal-loop or two-human playtest claim.

## Scope and repository state

Plan: `docs/plans/warrens-two-player-level-design/PHASE_3.md`. The user separately authorized fixing the reproduced local pack-loading issue. No cooking overhaul, commit or push.

Base/HEAD: `72d2f9592b854fd9948d0f7ec4aacc64e17b3fb3`, branch `dev`; changes remain local. Shared Control/Dial/Bellkeeper/Crawler, generated assets and submodule dirt are preserved. Coherent checkpoints identify owned hunks; whole-file Git dirt does not imply ownership.

Evidence paths below are relative to `docs/plans/warrens-two-player-level-design/evidence/phase-3/`.

## Implemented behavior and acceptance

| Change | Confirmed evidence | Boundary |
|---|---|---|
| Warrens-only route table: arch 6, rubble 2, far-side scout latch 4; seven v7 route anchors opt in | `entry-20261021/step1-static-contract.json`; preset and two actual candidate tests; `lead-final-route-gate-audit.json` | Generic table and frozen v6 manifest/summary unchanged; map-specific row indices recorded |
| Entry Pan, optional authored Grotto mushroom forage, readable PK/P2/P3 cues | Entry control/cue snapshots; `local-cargo-20261021/normal-recovery-*`; final PK/P3/Red Key input milestones under `kitchen-20261021/` | Existing local mechanisms reused. P2 moves bars, water remains cosmetic/static. Cache pool stays four and old P4 remains |
| Loaded pack stays stable and normal pickup preserves its actual Mushroom | `local-cargo-20261021/{normal-recovery-acceptance,normal-recovery-body-rows}.json`; independent `lead-local-cargo-final-gate-audit.json` | 166 samples/9.944425 s, Dynamic pack displacement/speed zero, same Mushroom at Pocket1; normal pickup becomes Carried/Kinematic. Fixture teleports establish approach only |
| Mourner fuel visible before cost; one chef activates P3; release stays latched; fuel retrieved and used | `remaining-step2-20261021/` pre-cost PNGs, occupied/deasserted rows, reward/refuel snapshots and active-cache bounds | Actual cache-body/rest gap 70.0205 cm. One local chef, no remote/human-pair claim |
| Both Vault rewards visible through closed gate; normal Red Key insertion opens gate; both rewards retrieved | `vault-reward-placement-20261021/` pre-cost PNGs, key-source rows and actual pickup snapshots | Correct fuel item IDs 2087/2088. Failed W movement excluded; interior reward setup used fixture teleport |
| Two actual stations and two receiving platters replace matching blockout props | `kitchen-20261021/{approved-placement,bounded-slide,slide-static-preview}.json`; actual station PNGs/input/state receipts | Cutting [37.8,48,0]/yaw0; Searing [41.2,48,0]/yaw180. Only two old props removed; hearth/rack retained. Receiving rests [42,42,0] and [43,42,0] |
| Cutting and Searing operate with grips/camera and worn pack; roles use measured stand-ins | Cutting board1 -> board2 -> board0/two pieces on output tray; final Searing `OnPan/Resting`, NegZ sear1.0; final same-chef Searing -> Cutting board2. `Final-solo-Cutting-two-halves.png`, `Final-Searing-cooked-face.png`, raw `runtime-inputs.jsonl` | Final Searing actual worn-pack trace hits null. One-face heating proves reused operation; fully ready takeout/service is not claimed |
| Opened portals and occupied receiving-role envelopes clear body/pack queries | `kitchen-20261021/{final-native-portal-sweeps,runtime-final-verdict}.json`; `runtime-final-portals.py`; independent `lead-final-physical-audit.json` | Four native visibility-query capsule/actual pack sweeps, all hit null; eight endpoint floors supported. Actual gates opened through normal PK/key and single-chef plate paths. These are clearance queries, not player traversal/input feel or human-pair proof |

## Bounded kitchen correction

Initial Searing X41.7 passed the chef-capsule projection but its actual worn pack intersected the retained rack. The permitted two 0.25 m westward steps move only that station to X41.2 (total 1 m from original X42.2). Its operator/dock/camera reservations move rigidly; facing, assets and kitchen walls remain unchanged. The measured pack envelope leaves 15.84 cm to the rack, and the final native trace is clear. Actual Searing and solo use of both operations were re-observed after the move.

Both receiving platters settled asleep with zero velocity at root Z71.407 cm over 70 cm rests, consistent with the existing 1.5 cm underside offset. Temporary editor food and player-owned runtime food were removed; no fixture-only food remains in the saved map.

## Local pack correction and affected contracts

Confirmed cause: UE QueryOnly/non-Block signatures were admitted as solid Jolt contacts. A mounted kinematic Mushroom could drive its dropped Dynamic pack. `CkJolt_Subsystem.cpp` now ORs a per-contact sensor response at Added and Persisted before the interest early-return, using the immutable collision table. Body/probe sensor identity, pair admission, query response and event payload remain intact. Native lifetime/table-read ordering was independently inspected.

Existing platters depended on QueryOnly `IgnoreOnlyPawn` for physical support; a valid original-native A/B confirmed that dependency. The project now explicitly defines `Mars_PlatterPhysical` (QueryAndPhysics, existing Pawn/Vehicle ignores), opts small/large platter bodies/rims/mounted food into it, retains the mounting profile immutably per WorldItem, acknowledges that profile before Held/Carried, and restores the original profile on release. Body-bearing items reject an empty mounted profile; bodiless visual items remain valid. Default items retain the previous named mounting profile. No settling, timing, recipes or cooking behavior changed.

Production paths: `Config/DefaultEngine.ini`; `Plugins/CkFoundation/Source/CkJolt/Public/CkJolt/Subsystem/CkJolt_Subsystem.cpp`; `Script/Items/Traits/Mars_ItemTrait_Presentation.as`; `Script/Items/Mars_Item_Platter.as`; `Script/ECS/WorldItem/Mars_WorldItem_{Feature,Utils,Processor_Mount}.as`; `Script/ECS/Platter/Mars_Platter_{Feature,Utils}.as`.

Three new regressions exercise QueryOnly physical response, runtime profile changes and actual Mushroom cargo on a dropped pack. Existing WorldItem spec and platter lifecycle tests assert the explicit profile contract. Test registration/assets came from supported editor/Toolbox discovery, not handwritten generated wrappers.

## Test baseline and final evidence

Route/mechanism baseline: Candidate3 + Resolver19 + Gate2 + KeyLock6 =30/30. Two new candidate tests produce final32/32: Candidate5, Resolver19, Gate2, KeyLock6. All four real Toolbox exits zero; skipped/contaminated/source drift zero. Root independently parsed raw totals and all32 unique engine Success names: `lead-final-route-gate-audit.json`.

Local fix: original six scopes are73 observations/72 unique. Including the valid original-native platter scope gives the identical123-name final set: baseline120 passing plus3 new behavioral reds -> final123 passing, missing0/added0. Seven final serial Toolbox exits zero: Jolt40/40, CargoSlot5/5, WorldItem22/22, Backpack4/4, QueryOnlyProbe1/1, CollisionLayers1/1, Platter52/52. This is125 observations with two overlapping names, not125 unique tests. Skipped0/contaminated0; all15 frozen source/config hashes match.

Root raw-exit/log/name-set audits: `lead-local-cargo-final-gate-audit.json`, `lead-local-cargo-baseline-set-audit.json`. Native build actually compiled the subsystem unity and linked CkJolt. Rejected compile/discovery attempts, secondary-process baselines and the first stale-mtime rollback that skipped native rebuilding are preserved as invalid evidence. Valid A/B details: `lead-local-cargo-platter-isolation.md`.

Final placement-only Searing/reservation changes do not alter emitted AS or the15 local-fix source hashes; source lanes were not unnecessarily repeated. Final static checks124/124 with320 graph cases pass. Editor/Jolt audit:898 samples/0 missing,20 starts,6/6 crawls,low tunnel blocked0,Jolt true. No full suite or regression-free claim.

Unchanged candidate EntityLeaks Display counts are17/16/6/16 per rig, matching the prior accepted5/5 scope. They are retained as a test-isolation limit, not silently treated as whole-suite proof.

## Final saved identity and independent check

`kitchen-20261021/final-applied-identity.json` records14 map/data/AS/Jolt artifact hashes, dirty packages0, PIE stopped, temporary food removed and all15 unowned actors exactly preserved.

- Map SHA256: `2814d8b967f39faf88d5769e5633f5c0602a14a5701bd78215ae24b8c12b907e`.
- Geometry SHA256: `c06c18323842e731e4a709099d6912ae46dae666c1502532ae5472fc64e41bf8`.
- Emitted AS SHA256: `205eedab869b33b3fcce3e582dda49ff4f0f2993948a738211c7685ebe40b718`.

`lead-final-physical-audit.json` independently rehashes all14 artifacts and15 frozen source/config paths with zero drift; reads actual final station states and four clear sweeps; and proves the full current `build_warrens.manifest(write=False)` equals the manifest from the physically observed corrected scene, with zero changed keys. Cleanup serialization/reservation metadata did not change the observed geometry. Final PNGs were independently viewed.

## Limits, follow-ups and rollback

No MP/network work, two-human playtest, movement feel, finished meal/service or Phase4 adoption is claimed. Human-pair design acceptance remains a later phase.

Unchanged adjacent follow-ups: NoCollision signature diagnostic/acceptance mismatch; late-created FoodPiece body applies its Pawn-ignore contract only on attachment. Mixed overlap directions/continuously touching manifold transitions remain coverage limits. No source work was added for them.

Rollback is phase-owned hunks plus a coherent map checkpoint after checking later edits. Native correction, explicit platter contract and regressions form one dependency-coupled set. Never reset whole generated files, maps or submodule worktrees. No rollback, commit, rebase or outward action was taken.
