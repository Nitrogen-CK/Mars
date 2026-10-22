# Phase 4 — Bellkeeper's dial lock, commitment and local stakes

**Execution reconciliation, 2026-10-22 UTC:** [PHASE_4_RECONCILIATION.md](PHASE_4_RECONCILIATION.md) supersedes the historical Momentary-click and powered-pulse wiring below. Preserve opt-in FreeTurn grip/drag/release; ordinary levers/chains and all shared Trap/Cycle/Source implementations stay unchanged. Warrens uses the dedicated owned vent with Stop/Running acknowledgements. Parent local construction finishes before the child promise adds kernel/commit wiring. Fresh baseline52/52; two real coupled reds; corrected actual-panel Bellkeeper gate10/10, exits0. Counts come from discovery (Dial4/Bellkeeper10), not the historical3+6.

The approved [placement preview](evidence/phase-4/preview-20261022/layout-preview.png) and [exact manifest](evidence/phase-4/preview-20261022/placement-manifest.json) retain the existing Chime Hall block and direct the unchanged push impulse southeast (yaw-75), away from the west operator and separate partner stage. The authored sign explicitly preserves the last Ration; readable presentation still requires pixels. Final static131/131 and graph320 pass. Actual wrong3/solve/Ration and native role-envelope observations are recorded in the [physical evidence index](evidence/phase-4/physical-20261022/PHYSICAL_ACCEPTANCE.md).

**Final local gate, 2026-10-22 UTC:** the one allowed placement/light correction and later [user-approved contrast-only pass](PHASE_4_CONTRAST_AMENDMENT_PROPOSAL.md) are used. Final normal-camera Diamond/Triangle/Cross and complete pre-cost sign wording both PASS independent pixel review. The dark text reached its component but default-lit material still washed it out; root approved a P4-only opt-in to the verified existing UnlitText within the approved dark-cue repair, holding color/light/placement fixed. [Exact material diff](evidence/phase-4/unlit-20261022/approved-unlit-diff.patch), [runtime material](evidence/phase-4/physical-20261022/final-unlit-cue-component.json). Fresh final contrast Toolbox build/Bellkeeper10/10, final static131/320 and post-PIE native map/Jolt audit pass; earlier57 remains the gate for its captured source. A single actual EnhancedInput route completes panel→Bridge reader→panel with no mid-route teleport. Its raced arrival photo is rejected, so standalone phrase pixels and movement do not claim live read-memory. The user cannot check audio now: normal heard loudness remains a full-acceptance blocker; diagnostic bypass clips do not satisfy it. Phase4 is implemented locally and frozen; do not start Phase5.

**Amended 2026-10-20 (maintainer): the pressed-seal phrase is replaced by a dial lock.** Three dials of six glyphs, a pull-chain commit, failed commits lose the Cleaver then the Tenderizer and fire a local steam vent, the Ration is always kept. Why: two seals gave two possible orders and a wrong press reset for free, so trying combinations cost nothing. Dials keep their set state visible between attempts, need no entry buffer, and make every commit a full guess (216 combinations; three blind tries succeed about 1.4% of the time). The old commit-mode Sequence extension is dropped: **Phase 4 no longer changes `Script/ECS/Sequence/`.**

> **Historical implemented snapshot, 2026-10-20 (kernels, assembly, sandbox G3); superseded by execution reconciliation above.** Deviations from the locked text below, all in the code: no Dial setup processor (nothing to link) and no Bellkeeper tick processor (the vent pulse is a `utils_timer` like Sequence's, ended through `FMars_Request_Bellkeeper_EndVent`); rewards are a `TArray<FMars_Bellkeeper_Reward>` (item definition + transform) lost from the front with the last always kept, so `Get_RemainingStakes` is `Get_RemainingRewards`; the vent source is optional; any rising edge on the lock's own sink is a commit (no commit-channel field in the kernel); the panel exposes `Phrase`/`StartGlyphs` glyph arrays and reward offsets in world axes from its origin; the one-shot vent is `utils_trap::Make_BurstVentSpec()` (Telegraph 0.8 + Fire 1.2, no loop, run while powered). Files: `Script/ECS/Dial/` (3), `Script/ECS/Bellkeeper/` (4), `Script/WorldObjects/Mechanisms/Mars_Bellkeeper{_EntityScript,Clue_EntityScript,Glyphs}.as`, tests under `Script/Tests/Dial/` (3) and `Script/Tests/Bellkeeper/` (5).

Take V0's complete phase-entry checkpoint before any mutation. Checkpoints **4A** (Dial kernel) and **4B** (Bellkeeper/placement) are resumable within this phase. Load `ck-game-feature-recipe` before 4A; resume in a fresh session if 4A consumes the safe context budget.

**Entry:** Phase 3 passes. Read `Mars_Seal_EntityScript.as` (glyph mesh pattern, Control + interactable composition), `Mars_PullChain_EntityScript.as` (release-to-rearm commit), `Mars_Vent_EntityScript.as` with `Script/ECS/Trap/`, `Script/ECS/Cycle/` and `Script/ECS/Hazard/`, `Mars_SequenceNode_EntityScript.as` (sink + source on one entity), `Mars_Control_Utils.as` (`BindTo_OnEngaged`) and approved `PROPOSAL_I.md` / `proposal.json:bellkeeperEncounter` for clue location and reward rests (its seal/slot semantics are superseded by this amendment). Confirm three contracts before writing code; if any differs, STOP and amend this bounded design:

1. A Momentary `Control` broadcasts `OnEngaged` once per Use press.
2. A `Cycle` set to `Running` starts at its first phase (not where it stopped), so one powered pulse of Telegraph + Fire length yields exactly one burst.
3. `Hazard` only pushes (`PushImpulse`); it applies no damage. The vent consequence is a push, not harm. Do not add damage here.

No new C++ feature/module, general puzzle framework or creature response is permitted.

**Change paths:** NEW `Script/ECS/Dial/Mars_Dial_{Feature,Utils,Processor_Setup,Processor_Requests}.as`; NEW `Script/ECS/Bellkeeper/Mars_Bellkeeper_{Feature,Utils,Processor_Setup,Processor_Requests,Processor_Tick}.as`; two entries in `Script/Generated/DynamicHandleTypes.json`; NEW `Script/WorldObjects/Mechanisms/Mars_Bellkeeper_EntityScript.as`, `Mars_BellkeeperClue_EntityScript.as` and `Mars_BellkeeperGlyphs.as` (shared glyph enum + mesh builder, assembly-only); NEW `Script/Tests/Dial/` (rig + three tests) and `Script/Tests/Bellkeeper/` (rig + six tests); `Config/DefaultGameplayTags.ini`; v7 generator/geometry/builder/live JSON/emitted AS/map/Jolt. `Mars_Seal_EntityScript.as`, the Sequence quartet, SequenceNode, PullChain, Vent and their tests remain unchanged; sandbox seals keep working.

## Locked kernels

All reflected fields use the neighbouring features' `UPROPERTY()` style; requests follow root `CLAUDE.md`'s request doctrine (snapshot → `Request_TryRemove` → apply in documented order → broadcast).

### 4A: Dial (`Script/ECS/Dial/`)

A dial is a ring of `Positions` detents and an index. It knows no glyph, mesh or answer.

```angelscript
// Mars_DialHandle requires FMars_Feature_Dial.
struct FMars_Feature_Dial {}
struct FMars_Dial_Spec { int32 Positions = 6; int32 StartIndex = 0; }
struct FMars_Fragment_Dial_Params { int32 Positions = 6; }
struct FMars_Fragment_Dial { int32 Index = 0; bool Locked = false; }
struct FMars_Request_Dial_Step
{
    int32 Detents = 1; // negative turns back; the kernel wraps
    FMars_Request_Dial_Step() {}
    FMars_Request_Dial_Step(int32 InDetents) { Detents = InDetents; }
}
struct FMars_Request_Dial_SetLocked
{
    bool Locked = true;
    FMars_Request_Dial_SetLocked() {}
    FMars_Request_Dial_SetLocked(bool InLocked) { Locked = InLocked; }
}
struct FMars_Fragment_Dial_Requests
{
    TArray<FMars_Request_Dial_SetLocked> Locks;
    TArray<FMars_Request_Dial_Step> Steps;
}
// Add belongs in utils_dial; getters/request mixins stay at file scope.
FCk_Handle_Dial Add(FCk_Handle& InHandle, FMars_Dial_Spec InSpec);
mixin int32 Get_Index(const FCk_Handle_Dial& Self);
mixin int32 Get_Positions(const FCk_Handle_Dial& Self);
mixin bool Get_IsLocked(const FCk_Handle_Dial& Self);
mixin void Request_Step(FCk_Handle_Dial& Self, const FMars_Request_Dial_Step& InRequest);
mixin void Request_SetLocked(FCk_Handle_Dial& Self, const FMars_Request_Dial_SetLocked& InRequest);
delegate void FMars_Delegate_Dial_OnIndexChanged(FCk_Handle_Dial InDial, int32 InIndex);
```

`Validate`: `Positions` in [2, 12]; `StartIndex` in [0, Positions). HandleRequests applies Locks (last wins) **before** Steps; a Step while locked is dropped; Steps apply FIFO with positive modulo; `OnIndexChanged` broadcasts once per drain when the index changed, carrying the final index. No timer, no correctness, no sound.

**Gate:** three Dial tests: (a) forward and backward wrap over several steps in one drain, one broadcast with the final index; (b) a lock in the same drain drops that drain's steps, unlock restores stepping; (c) invalid specs are rejected by `Add`'s ensure and compose nothing. Build + scoped `--test-pattern` Dial automation through V3, 3/3. **Pass → continue; failure → STOP.**

### 4B: Bellkeeper (`Script/ECS/Bellkeeper/`)

The Bellkeeper owns the answer, the commit judgement, the stakes, the rewards and the vent clock: every rule that must hold headless.

```angelscript
// Mars_BellkeeperHandle requires FMars_Feature_Bellkeeper.
struct FMars_Feature_Bellkeeper {}
struct FMars_Bellkeeper_Spec
{
    TArray<FCk_Handle_Dial> Dials;           // construction input: built by the assembly, panel order left to right
    TArray<int32> Answer;                    // one index per dial; derived by the builder from the one v7 phrase
    TArray<FTransform> RewardTransforms;     // 0/1/2 = Cleaver/Tenderizer/Ration
    FCk_Handle_MechanismSource VentSource;   // construction input: a child entity whose channel powers the vent
    float32 VentPulseSeconds = 2.0f;         // = the vent trap's Telegraph + Fire
}
struct FMars_Fragment_Bellkeeper_Params { /* the five Spec fields */ }
struct FMars_Fragment_Bellkeeper
{
    int32 FailedCommits = 0;                 // uncapped; stakes lost = Min(FailedCommits, 2)
    bool Solved = false;
    TArray<FCk_Handle> RewardHandles;
    TOptional<float32> VentRemainingSeconds; // unset = vent source deasserted
}
struct FMars_Request_Bellkeeper_Commit
{
    bool _Placeholder = false;
    FMars_Request_Bellkeeper_Commit() {}
}
struct FMars_Fragment_Bellkeeper_Requests { TArray<FMars_Request_Bellkeeper_Commit> Commits; }
FCk_Handle_Bellkeeper Add(FCk_Handle& InHandle, FMars_Bellkeeper_Spec InSpec);
mixin int32 Get_FailedCommits(const FCk_Handle_Bellkeeper& Self);
mixin int32 Get_RemainingStakes(const FCk_Handle_Bellkeeper& Self); // 3 - Min(FailedCommits, 2)
mixin bool Get_IsSolved(const FCk_Handle_Bellkeeper& Self);
mixin void Request_Commit(FCk_Handle_Bellkeeper& Self, const FMars_Request_Bellkeeper_Commit& InRequest);
delegate void FMars_Delegate_Bellkeeper_OnCommitFailed(FCk_Handle_Bellkeeper InBellkeeper, int32 InRemainingStakes);
delegate void FMars_Delegate_Bellkeeper_OnSolved(FCk_Handle_Bellkeeper InBellkeeper);
```

`Validate`: at least one dial, each valid; `Answer.Num() == Dials.Num()`; each `Answer[i]` in [0, `Dials[i].Get_Positions()`); the dials' current indices are not the answer on any dial (the start state is never one pull from solved); exactly three finite distinct reward transforms; `VentSource` valid; `VentPulseSeconds > 0`.

Setup requires a MechanismSink on the **same entity** listening to `P4.Commit`, binds `OnInputRose` to `Request_Commit`, and sets the optional same-entity Source (`P4`) to `Solved`. No global discovery.

Commit outcomes (HandleRequests; **at most one commit per drain**, so duplicate chain edges cannot spend two stakes):

| State at commit | Exact outcome |
|---|---|
| Solved | Ignore; no vent, no signal. |
| Every `Dials[i].Get_Index() == Answer[i]` | Set `Solved` **before** anything else; request `SetLocked(true)` on every dial; assert Source; request owned pickups for reward indices `>= Min(FailedCommits, 2)` (Ration always); store `Pending.Get_EntityUnderConstruction()` handles and report invalid spawns, never retrying into duplicates; broadcast `OnSolved` once. |
| Any dial off its answer | `FailedCommits += 1`; assert `VentSource` and set `VentRemainingSeconds = VentPulseSeconds` (a commit during a live pulse restarts it); dials keep their indices (the attempt stays visible); broadcast `OnCommitFailed(RemainingStakes)`. A third and later wrong commit still vents but loses nothing more. |

The judgement never reports which dial was wrong. Processor_Tick decrements `VentRemainingSeconds` and, at or below zero, deasserts `VentSource` and unsets the clock; zero DeltaT is a no-op. Copy needed values before broadcasting and revalidate handles after: listeners may destroy the owner. Only Add/processors write these fragments; the reward and vent policy stays in Bellkeeper, not in Dial.

Register `FCk_Handle_Dial` (ShortName `Dial`, SourceAsset `/Script/AngelscriptAssets.Mars_DialHandle`, RequiredFragments `["Mars_Feature_Dial"]`) and `FCk_Handle_Bellkeeper` (ShortName `Bellkeeper`, SourceAsset `/Script/AngelscriptAssets.Mars_BellkeeperHandle`, RequiredFragments `["Mars_Feature_Bellkeeper"]`) in `Script/Generated/DynamicHandleTypes.json`, matching the Sequence entry. These **two registry entries** are the project-mandated exception (root `CLAUDE.md`, Features); do not hand-edit generated AS wrappers/Params. Author declarations and consumers together, then supported discovery/regeneration.

## Assembly and placement

- **`Mars_BellkeeperGlyphs.as`** (assembly-only): `enum EMars_Bellkeeper_Glyph { Square, Circle, Triangle, Diamond, Cross, Bars }` and one mesh-part builder from engine primitives, following Seal's glyph pattern. Ring order is the enum order: dial index `i` points at glyph `i` on every dial. Greybox glyphs are nameable; Phase 5 may replace their art with harder-to-name marks without changing indices.
- **`Mars_Bellkeeper_EntityScript.as`** (the panel): builds three dial child entities at the old seal positions (x 86.4/87.0/87.6, y 57.98, z 1.2). Each dial: a plate with the six glyphs fixed around a 12 cm radius, a knob node with a pointer that the assembly rotates to `Index × 360 / Positions` on `OnIndexChanged`, a Momentary `Control` whose `OnEngaged` issues `Request_Step(1)` (one Use press = one detent clockwise), and an interactable with prompt "Turn dial". Identical detent click at every position: no click, glow or resistance marks the answer. It then builds the vent-source child entity (MechanismSource on `P4.Vent`) and adds Bellkeeper with Dials/Answer/RewardTransforms/VentSource, a sink on `P4.Commit` and the `P4` source. It owns three stake candles on the old slot shelf `(87,57.98,1.75)`, lit = `Get_RemainingStakes()`, the bell's distinct wrong and correct strokes (bound to `OnCommitFailed` / `OnSolved`), and nothing else. Exposes SpawnTransform, Answer, StartIndices, RewardTransforms, VentPulseSeconds.
- **Commit:** existing `UMars_PullChain_EntityScript` at bracket `(91.4,57.98,2.3)`, Source on `P4.Commit`, unchanged release-to-rearm behaviour. The pull rings the bell; the verdict stroke follows.
- **Vent:** existing `UMars_Vent_EntityScript` placed by the builder so its jet crosses the chain's pull stand, Sink on `P4.Vent`, `Trap.Powered = RunWhilePowered`, a Bellkeeper trap spec whose Telegraph + Fire equals `VentPulseSeconds` (0.8 s + 1.2 s) and whose Idle exceeds the pulse. The push must land on floor in the hall: no drop, crack or cargo rest inside the push envelope.
- **Clue:** `Mars_BellkeeperClue_EntityScript.as`, static composition from the glyph builder with a glyph array exposed on spawn, centre `(60,38.25,-2.2)`, 0.6 m glyphs, each drawn under a small dial pictogram so left/middle/right is unambiguous. Not readable from the panel. Add a local clue light if the current dimmed light fails legibility; do not revert district fill tuning.
- **One authoritative phrase.** v7 holds the glyph phrase **Diamond, Triangle, Cross** and the start glyphs **Square, Square, Square**; the builder derives the clue glyphs, `Answer` indices and dial start indices from them and fails if any start glyph equals its answer glyph. Do not store two hand-maintained sequences.
- **Tags:** add `Mechanism.Channel.Warrens.Puzzle.P4.Commit` and `.P4.Vent`; retain the `P4` output. Stop emitting `P4.SealA`/`P4.SealB`; remove their ini rows only if a grep after the map rebuild finds no remaining consumer.
- Use proposal.json's three distinct reward rests, checked against the actual item bodies.

**Gate:** six Bellkeeper tests: (a) a wrong commit increments, asserts the vent source for the pulse then deasserts, keeps dial indices, and reports remaining stakes 3→2→1 over three wrong commits with no further loss on the fourth; (b) a correct commit after N wrong commits latches, locks the dials (later steps dropped), asserts the source and spawns exactly the rewards at indices `>= Min(N,2)`, once, across repeated commits; (c) two commit edges in one drain judge once; (d) commits after solved are ignored with no vent; (e) owner teardown mid-pulse leaves no live vent source or tick work; (f) `Validate` rejects mismatched answer count, out-of-range answers and a start state equal to the answer on any dial, and the builder's emitted phrase matches the clue glyphs and `Answer`. Build + scoped Dial and Bellkeeper automation via V3, 3 + 6; restart after tag changes before strict apply. **Pass → continue; missing Params/tags or failed lifecycle → STOP, use supported regeneration; do not hand-edit AS wrappers.**

## Placement, rebuild and verification

Remove only Bellkeeper's random cache anchor, retaining the niche. Keep Mourner, SealedBurial and Porter with maxActiveCaches=2. Remove the old P4 pedestal, two-seal logic, its SequenceNode and the placeholder clue. Regenerate JSON, run `python -B Tools/LevelDesign/anchor_plans/emit_plan.py warrens` from root, and build/test the final source through V3. Rebuild/audit from checkpoint; run the static validator and AnchorResolver cache tests.

`[EDITOR-VERIFY]` From the Bridge read the complete phrase with a normal player camera; from the panel it is not readable. Two people may split reader/operator, but one may walk/read/return. Turn each dial through all six positions: identical clicks, nothing marks the answer. Pull with one dial wrong, twice; observe the wrong bell stroke, candles 3→2→1, the vent telegraph then a push that lands on floor, and the dials still showing the attempt. Pull a third wrong: vent, no further candle. Set the phrase and pull: correct stroke, dials locked, latched gate, and exactly the Ration (or more, with fewer failures) as physical pickups. Repeat with roles swapped where available. Verify loudness, the turn prompt and the chain's grip reach, not just source signals.

**Expected:** correct effects and no hidden prerequisite for the main route. **Pass → exit; source passes but readability/placement fails → one local placement/light correction and repeat; any semantic mismatch → STOP.** Ration's limited value is recorded, not remedied with invented healing. The vent's push-only consequence is recorded if players shrug it off; adding damage is outside this plan.

**Exit:** Sequence untouched; 3 Dial + 6 Bellkeeper tests pass against final source; the dial lock is physically observable locally; cache budget remains valid. Actual two-person gameplay evidence may remain pending independently.

**Rollback:** restore this phase's own source/config and prior data/map checkpoint together; partial rollback must not leave emitters requesting absent classes/tags. Preserve the older test/helper baseline and unrelated generated edits.
