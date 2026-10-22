# Warrens Phase 4 review package

Status: IMPLEMENTED AND CHECKPOINTED; full physical acceptance pending normal heard audio. Final cleanup identity is frozen; the earlier apply-time Jolt hashes preceded queued editor collision cooking.

## Scope

- Implements `docs/plans/warrens-two-player-level-design/PHASE_4.md`, `PHASE_4_RECONCILIATION.md` and user-approved `PHASE_4_CONTRAST_AMENDMENT_PROPOSAL.md`.
- Repository `D:/Repositories/CkRepos/Orion`, branch `dev`; no C++ or submodule implementation changes. Local layout/role intention only; MP work excluded.
- Incomplete: ordinary heard detents/wrong/correct feedback. User answered “I can’t check audio now”. No further blind audio experiments are authorized or useful.
- Two-human gameplay remains unobserved and separate from the allowed solo/envelope evidence. Phase 5 is not started.

## Commits

Exact base: `72d2f9592b854fd9948d0f7ec4aacc64e17b3fb3`.

`git log --oneline 72d2f9592b854fd9948d0f7ec4aacc64e17b3fb3..HEAD` returned no output, exit 0. No commits or push.
`git rev-parse HEAD` returned:

```text
72d2f9592b854fd9948d0f7ec4aacc64e17b3fb3
```

All implementation is dirty local work. Shared tree already contained Control/Dial/Bellkeeper/Crawler, local pack fixes, generated assets/config and submodule dirt. Never attribute the complete working-tree diff to this phase. Entry snapshots below define ownership.

## Diffstat

`git diff --stat 72d2f9592b854fd9948d0f7ec4aacc64e17b3fb3..HEAD` returned no output, exit 0, because this phase is uncommitted.

Owned changes relative to the 149-file entry checkpoint: bounded Bellkeeper vent/lifecycle and Dial lock-snap repairs, five Bellkeeper tests plus dedicated fixture; P4 authoring and opt-in builder label presentation; generated live plan/map/Jolt; phase docs/evidence. Entry: `evidence/phase-4/entry-20261022/baseline.json` and `checkpoint/`. Exact presentation patches: `contrast-20261022/approved-contrast-diff.patch`, `unlit-20261022/approved-unlit-diff.patch`.

## Claims table

Paths in this table are relative to `docs/plans/warrens-two-player-level-design/` unless explicitly prefixed `Script/` or `Tools/`.

| Claim | Evidence kind | Pointer |
|---|---|---|
| Accepted Phase 3 artifact identities matched entry | VERIFIED-artifact | `evidence/phase-4/lead-entry-audit.json`: fourteen matches; no drift. |
| Two coupled failures reproduced before repairs | VERIFIED-rerun | `lead-reproduction-audit.json` under the same evidence directory; actual raw existing-five pass/new-two fail, Toolbox exit 1. |
| Baseline 52 to focused 57 pass, all original test paths retained | VERIFIED-rerun | `lead-baseline-gate-audit.json`, `lead-final-gate-audit.json`; actual six raw engine logs and Toolbox exits independently read. This 57 gate predates the clue tint change. |
| Final AngelScript build/Bellkeeper 10 pass after clue contrast | VERIFIED-rerun | `lead-contrast-gate-audit.json`, `contrast-20261022/Bellkeeper-test-raw-Mars.log` and `.exit`; ten Success, engine/Toolbox 0, skips/contamination 0. The differently named `Bellkeeper-raw-Mars.log` is later discovery, not valid execution proof. |
| Actual owned panel constructs, operates and tears down its child vent | VERIFIED-rerun | `lifecycle-corrected-20261022/Bellkeeper-raw-Mars.log`, `OwnedPanelConstructsAndTearsDownItsVent`; direct kernel fixtures alone are insufficient. |
| Final static gates and frozen v6 output retained | VERIFIED-artifact | `unlit-20261022/static.json`, `static-exit.txt`, `static-v6-invariance.json`: 131 checks/320 graph cases, exit 0. Root separately compared complete v6 manifest and summary using entry/current builders without writes. |
| Saved map support/layout audit passes | VERIFIED-artifact | `applied-unlit-20261022/warrens-audit.json`: samples 898, missing 0, startsClear 20, crawlsOk 6, lowTunnelBlocked 0, jolt true. Its inherited plain-box/seal-order deviation prose is obsolete, not current clue evidence. |
| Bridge clue and complete cost cue readable at shown ordinary viewpoints | VERIFIED-artifact | `physical-20261022/final-independent-pixel-gates.json`; root and separate reviewer inspected original pixels. Diamond/Triangle/Cross; WRONG RINGS LOSE TOOLS / THE LAST RATION REMAINS. |
| All six detents on all three dials observed through input | VERIFIED-artifact | `physical-20261022/all-glyph-normal-input.jsonl`; root parsed every row, not only first/last. |
| Three wrong pulls preserve last stake and yield supported push landings | VERIFIED-artifact | `physical-20261022/corrected-three-wrong-pushes.json`, `three-wrong-sequence-receipt.json`, three candle views. Actual worn pack, Telegraph/Fire/Stopped, health 100, candles 2/1/1. |
| Correct solve locks dials, latches gate and pays physical rewards once | VERIFIED-artifact | `physical-20261022/three-failure-normal-solve.json`, `solve-sequence-receipt.json`, `actual-last-Ration-normal-pickup.png`; actual LMB/Look/chain path. `all-three-actual-reward-rests.json` separately covers zero-failure reward rests. |
| Local operator/partner reservations fit including measured worn-pack envelope | VERIFIED-artifact | `physical-20261022/final-native-role-envelopes.json`: five body/pack role-swapped reservations, no hits and native supported endpoints; static envelope proof only. |
| Solo normal movement-input route reaches reader and returns | VERIFIED-artifact | `lead-solo-route-audit.json`, `physical-20261022/solo_read_return.py` and `solo-read-return.json`: 14/14 waypoints, 443 samples, error null, 24.98436890169978 s. Initial fixture placement only; no mid-route teleport/direct movement/AI. One chef, no pack. |
| Final artifacts, source preservation and cleanup agree | VERIFIED-artifact | `lead-close-preservation-audit.json`: fourteen final hashes match `closing-20261022/final-applied-identity.json`; pack15/shared28 unchanged; prior57 source has only expected clueAS/data deltas. All fifteen unowned actors independently compared. Game world absent, dirty map/content zero, original audio CVar0. |
| Normal heard feedback is accepted | ASSUMED, NOT ACCEPTED | User unavailable. Normal PCM contains zero nonzero samples; diagnostic app-volume bypass is nonzero and always restored to 0. Neither proves human loudness. |
| Simultaneous two-human movement/communication and human clue recall work well | ASSUMED, NOT EXAMINED | No two-human play session. Solo movement and separate original-camera readability do not prove these qualities. |

## Risk-ranked hunks

1. `Script/WorldObjects/Mechanisms/Mars_Bellkeeper_EntityScript.as:119-180` — parent must finish local construction before lifetime-owned child can construct; callback then adds lock/commit wiring exactly once. Original Continue/wait form deadlocked under native entity-script ordering. Actual panel test closes this risk.
2. `Script/ECS/Bellkeeper/Mars_Bellkeeper_Processor_Requests.as:96-191` — Stop/Running acknowledgements restart active dedicated bursts; solve/teardown cancel pending intent/timer. A stale acknowledgement could otherwise revive the vent after solve. Dedicated optional mode preserves legacy Source-only consumers.
3. `Script/ECS/Bellkeeper/Mars_Bellkeeper_Processor_Setup.as:27-57` — validate child Cycle identity before forwarding run-state changes; late child callback/teardown is lifetime-sensitive.
4. `Script/ECS/Dial/Mars_Dial_Processor_Requests.as:28-39` — locked dial snaps to its selected index and broadcasts final angle with zero crossings. Preserves chosen glyph while stopping an unreleased pointer between detents.
5. `Tools/LevelDesign/anchor_plans/design_warrens_v7_geometry.json` P4 block — southeast push must avoid inherited wall and partner stage. Three actual loaded pushes close tested placement; conservative sweeps were never trajectory proof.
6. `Tools/LevelDesign/anchor_plans/build_warrens.py:1637-1642,1699-1703` — optional existing material must resolve before deletion; only P4-stakes opts in. Defaults preserved. Unlit text fixes source-confirmed lit-material washout without moving geometry/light.
7. `Script/WorldObjects/Mechanisms/Mars_BellkeeperClue_EntityScript.as:39-42` — ProtoGrid tint applies the intended dark palette to secondary/grid channels as well as primary. No shared mesh/material implementation changed.

## Deviations

- Preserve concurrent opt-in FreeTurn grip/drag/release; historical Momentary-click text superseded by reconciliation. Shared Control, Sequence, Trap, Cycle, Source/Sink, PullChain and Vent source preserved from entry.
- Use dedicated optional lifetime-owned unchanged vent and actual stop/run acknowledgements. Legacy Source-only wired consumers retain their earlier contract.
- Actual counts are Dial 4/Bellkeeper 10; five focused tests added. An initial actual-panel fixture compile error returned 76/no valid verdict; retained under lifecycle evidence, superseded by corrected public optional cast fixture.
- Retain inherited wall and both main routes; angle vent yaw -75 and reserve eastern landing. One placement/light correction lowered only vent 0.35 m, moved cue and reduced clue task light.
- User approved extra contrast repair after the permitted correction failed pixels. Dark clue discs pass; actual dark text still washed out under DefaultTextMaterialOpaque. Read-only material graph inspection confirmed lit BaseColor/no Emissive; existing UnlitText opt-in then passed matched pixels. No new shader/asset/global lighting change.
- Last change is Python/data-only; final AS remains exactly the successful postcontrast build/test source. No broad test rerun is represented as newer than it is.
- Solo arrival screenshot raced the resumed return camera and is rejected. Trace proves arrival/pause/return; the earlier same reader-camera image separately proves phrase readability. No human memory claim.
- The route receipt samples velocity before injected zero input drains (410.4152634412057,89.21497371231895,0); any later stopped state must use the cleanup receipt, not rewrite this sample.
- Diagnostic audio bypass recordings are explicitly diagnostic. Normal state restored exactly to 0; no audio source/preference/config repair.

## Baseline diff

`evidence/phase-4/lead-baseline-gate-audit.json` records 52/52: Control19, Dial4, Bellkeeper5, Sequence3, AnchorResolver19, Trap2.
`lead-final-gate-audit.json` records 57/57: same families with Bellkeeper10. All original paths retained; five new tests pass; failures/skips/contamination 0; each actual engine/Toolbox exit 0.
Postcontrast `lead-contrast-gate-audit.json`: Bellkeeper10/10 after final AS clue tint. Subsequent UnlitText change touches Python/data only. Full 57 gate is scoped to captured source, not claimed as rerun after presentation edits.
Root final source preservation audit is refreshed after cleanup: Phase3 local-fix15, shared/frozen28 and successful final AS exact; no unexpected source drift. Apply-time identity preceded queued editor auto-cook completion, not a PIE-time bake. Inspected source `Plugins/CkFoundation/Source/CkJoltEditor/Public/CkJoltEditor/Cook/CkJoltCook_EditorSubsystem.cpp:148-178,224-263` schedules sliced cook on level save; builder audit only validates current world. Actual raw log line5724 records cook completion02:51:09.361, after premature identity02:51:08.761 and before PIE02:51:29. Final fourteen artifacts independently hash-match `closing-20261022/final-applied-identity.json`. Map SHA256 `ffdcc53706cf148a2945642685638cf4d03ddf3431dd14686730f8f837eb67e5`. Raw log line6098 separately proves post-input-drain velocity0. Both line receipts independently match the copied raw log.

## Open questions / follow-ups

1. Human normal-audio check remains the physical acceptance blocker: hear detents and distinguish wrong/correct strokes at ordinary settings. User cannot check now; full acceptance stays open.
2. Separate future two-human local test should assess communication/read-memory burden and role swapping; no MP implementation follows from this phase.
3. Ration content value and push-only vent severity remain recorded limitations. No healing/damage/AI escalation added.
4. Final state: `closing-20261022/cleanup.json`, `final-applied-identity.json`, `post-input-drain-and-jolt-log-receipt.json`; root `lead-close-preservation-audit.json`. PIE stopped, editor saved/clean, local work remains uncommitted. No commit/push/Phase5.
