# PHASE 4 BRIEF - pursuit, weapon death, dither, end-to-end court story, release evidence

Executor brief (Opus). Planner: the Fable session that owns `docs/art/pantry-rat-dens-production-r01/PROGRESS.md`. You own
`Tools/Blender/mars_monsters/pantry_rat_r01/PROGRESS.md` (append a Phase 4 section, every claim **confirmed** with evidence named or
**inferred**, deviations as D4-n) and the Phase 3 feature files you extend. Read, in order: this brief; `PHASE_3_BRIEF.md` (its
"Phase 2 outcomes" and "Architecture" sections still bind); the Phase 3 section of the production `PROGRESS.md` (what exists, what was
deviated); `docs/art/pantry-rat-dens-production-r01/PHASE_4.md`, `ACCEPTANCE.md` (R01-R30), `DESIGN_TECH_SPEC.md` sections 6, 8, 10,
12, 13, 14; `VALIDATION.md`; the project `CLAUDE.md`; `CkAuto/.claude/skills/build-test/SKILL.md`.

## Environment and ownership
- Same as Phase 3: branch dev, no git write commands, the sibling session's dirt untouched, nothing under `Plugins/` edited,
  BusterBlock read-only, Toolbox only (detached wrapper, one run dir per run, read the real `Toolbox.log` + `Exit.json`), the live
  MarsEditor never closed/restarted/Save-All'd, Monolith the only route in, the editor-killing operations of the Phase 3 brief
  forbidden, production maps off limits.
- PIE is allowed and required in this phase. Rules: PIE only with the editor window NOT minimised (a minimised editor throttles
  PIE to ~3 fps and the capture is worthless); stop PIE before any write; never start PIE with a dirty broken Blueprint in memory
  (PIE compiles every dirty BP). Check `editor_query get_dirty_content_packages` first and report what is dirty; do not save other
  people's dirty assets.
- The court for the story is a NEW review map under `/Game/ArtCandidates/PantryRat/R01/Review/` (e.g. `PantryRat_R01_Court_MAP`),
  built through `run_python` like Phase 2's review map, never a production map. It needs: floor + walls (an arena with at least two
  obstacles the chase can go round), a GroundNav volume that builds (wait on `Get_IsBuilt`), one den entity script, one World-mode
  backpack with a Monk's Rind in a <= 48 cm pocket and a mushroom in the other, the player start, a weapon the chef can equip
  (whatever the project's chef weapon path is: read `Script/ECS/Attack` and the hotbar/strike item definitions; cite the asset).

## Phase 3 outcomes that bind this phase (audited 2026-11-07; the production PROGRESS Phase 3 section has the detail)
- **What exists (names are exact; read the files, do not rename).** Features `Script/ECS/PantryRaid/` (`utils_pantry_raid`,
  `FCk_Handle_PantryRaid`), `Script/ECS/RatDen/` (`utils_rat_den`, `FCk_Handle_RatDen`), `Script/ECS/PantryRat/` (`utils_pantry_rat`,
  `FCk_Handle_PantryRat`, phase enum `EMars_PantryRat_Phase` incl. `BlockedCleanup`, single writer `UMars_Processor_PantryRat_HandleRequests`,
  `Processor_Tick` owns the clock/threat hysteresis/receipts, `Processor_Setup` binds OnHit/OnDied/nav answers, HFSM Alive{Behave}/Dead{Dead}
  with ONE Behave tick task and the kernel edge table `utils_pantry_rat::Get_IsAllowedAdvance` deciding every transition). Entity scripts
  `Script/WorldObjects/Monsters/Mars_{RatDen,PantryRaid,PantryRat}_EntityScript.as`. Items: `Mars_ItemDef_MonksRind` (`mars_items::MonksRind()`,
  Transient, StinkyCheese trait), `Mars_ItemTrait_PantryIngredient` on the 8 forage defs. Tags `AttachPoint.Mars.RatMouth`,
  `Inventory.Mars.RatPocket`, `Monster.Mars.PantryRat`, resolved by name through `utils_gameplay_tag::ResolveGameplayTag` (the live editor's
  tag namespace refreshes only at startup). Tests: `Script/Tests/{PantryRaid,RatDen,PantryRat}/` with rig `Mars_AutoTestRig_PantryRaid`;
  extend those rigs, do not build a second one.
- **Headless proven in Phase 3 (run05, all exit 0):** R01-R14, R17, R18, R19, R23, R25, R26, R27, R28. Do not re-prove them; keep their
  lanes green (`PantryRaid` 11, `RatDen` 4, `PantryRat` 13 incl. Phase 2's two) and extend with the Phase 4 rows only.
- **Flee is partial.** The edge table already confines a loaded rat to FleeWithLoot/FleePause/FleeCornered and the den refuses a loaded
  return (`HandleAdmitReturn`), but FleeCornered was never entered and AvoidPlayer movement is unasserted. Step 1 fills the burst/look-back
  rhythm, the candidate scoring and the cornered case on top of that table; do not rewrite the table.
- **Visual placement is unverified and the executor's own "most likely wrong".** The mouth node sits at a computed rest frame
  `utils_pantry_rat::k_MouthRest` (rotation (52, 0, 180), (19.8, 0, 2.6) on the root) and is NOT parented to the skeletal `Carry_Mouth`
  socket; bulky items ride `k_DragRest` upright on the floor. Step 6's first PIE frame with a carried mushroom decides: if the food is not
  at the jaw, fix the frame (or parent the node to the socket after the mesh exists) BEFORE the story run, and record the before/after
  crop. `Mars_PantryRat_AnimInstance.as` is a presentation type that currently lives in `Script/ECS/PantryRat/`; move it beside the
  entity script when you touch it (D4-n, additive move, update nothing else).
- **Clips** run through `USkeletalMeshComponent::PlayAnimation` from a phase->clip table in the rat entity script (line ~213); the
  component is in single-node mode so the AnimInstance telemetry is not live. Topple left/right (step 4) and the DeadHold pose are new
  rows in that table; keep the table, do not introduce an AnimBP unless a clip blend is impossible without one (say so).
- **Receipts** are polled conditions in the rat Tick (carry: `Get_Mount() == Carried && Get_Carrier() == rat && Get_IsSettled()`; release:
  World with the item back in its holder); the release refusal is a bound `OnReleaseRefused` on `UMars_PantryRat_ReleaseListener`. Keep
  that shape; DeadHold/CorpseFade admission in step 3 reads the same receipt flags.
- **Empty return today destroys the rat on admission** (no fade). Step 5 inserts the 0.25 s FadeAlpha ramp BEFORE the destroy/dormant
  hand-off and must re-seed `FadeAlpha = 1.0` (CPD 14 via `utils_pantry_rat_look::Get_FadeAlphaCpdIndex()`) before the next emergence's
  first visible frame; the assembly already copies `_Rat.Get_FadeAlpha()` to CPD 14 at entity-script lines ~119/121/186.
- **Death path facts:** TakeHit is lethal only for `Amount > 0 && Causer.Is_Item() && Causer.As_Item().Has_Strike()` with a Hotbar
  instigator; the drain applies `SetInvulnerable(Disable)` + `ApplyDamage(Max)`; the inventory coordinator commits a claim in the SAME
  frame the drain issues it (so "hit between enqueue and drain" must be staged by latching the hit first, as `HitBeforeCommitBlocksTheClaim`
  does). The death-during-ClaimTransfer path is code-only so far; step 2(c) is where it gets a routed proof.
- **Framework hazard (do not "fix" in Plugins/):** CkInventory validates a failed transfer's rollback re-add against the SOURCE's custom
  accept policy (`CkInventory_RequestHandlers.cpp:675`); the rat pocket therefore always accepts its own recorded loot back
  (`Get_CanCommitClaim`). Any new inventory you add with a custom predicate needs the same clause.
- **Fixture clock** = global time dilation 4 (R05/R13/R14 pattern); reuse it for the 3 s hold and the fade ramps rather than real-time waits.
- **Evidence retention:** the editor rotates lane logs within minutes. Copy every evidence line you cite into
  `Saved/Logs/PantryRatValidation/phase4-evidence-lanelines.txt` the moment you read it (Phase 3 lost two).
- **Shared dirty files:** `Script/ECS/SurfaceNavigator/*` now carry the additive SetSpeed request on top of a clean HEAD; `Config/DefaultGameplayTags.ini`
  has one sibling line (`Mars.SmState.ScreamingTurnipBed.Pull`) and `Script/Generated/*` is editor-written. Keep edits to those additive and
  named in PROGRESS before you make them, as before.
- **Attack lane names:** add `Attack` and `Health` to the focused pattern list in step 8 only if tests with those names exist
  (`--test --print-population --test-pattern <X>` first); report "no tests selected" rather than a fake green.

## Steps (gated; stop a gate with evidence rather than working around it)
1. **Flee completion.** FleeWithLoot / FleePause / FleeCornered exactly as the spec state table: bursts of 2-3 bounds at the loaded
   speed then 0.35-0.65 s look-back; candidates scored per spec section 8 with deterministic tie-break; loaded goals >= 150 cm from
   every den portal and never through a den mouth; no edge from any loaded state to ReturnEmpty / DenEnter / Dormant / distance
   despawn, enforced by a validator in the drain (a stale callback or a raid "return" request on a loaded rat is REFUSED and logged
   once). FleeCornered stays reachable and hit-able with the item in its mouth. Tests: R13, R14, R23 (headless, no assets).
2. **Weapon-hit adapter, final.** Phase 3 built the provenance gate (Causer item `Has_Strike()`, Instigator chef root) and the
   normalised lethal path (`Request_SetInvulnerable(Disable)` + `Request_ApplyDamage(Max)`). Finish it against the REAL chef
   attack: read the attack feature (`Script/ECS/Attack`, windup/strike/recover phases, the strike sweep that produces the hit event)
   and prove in a routed test that one real `FMars_Attack` strike on the rat hurtbox yields exactly one Health depletion, one
   Dying transition, one drop, with (a) a fractional-damage weapon, (b) a duplicated hurtbox contact in the same sweep, (c) the hit
   landing between Claim enqueue and drain (death wins; a late accepted receipt is released once; no second drop). Tests: R16, R17.
3. **Drop receipts + dead hold.** Persistent: `Request_Release` once per ReleaseOperationId, receipt = the WorldItem's OnMountChanged
   -> World, then world pickup readiness (the food's interactable is live). Transient: new WorldItem adopting SourceItem /
   SourceInventory; receipt = constructed AND `Loot.Get_ParentInventory()` moved. DeadHold starts at death; CorpseFade admission needs
   BOTH the receipt and >= 3 s hold. Refusal / no receipt -> BlockedCleanup: rat stays visible and dead, one Warning with the operation
   id and reason, the pocket owner is never destroyed, the item is never lost. Tests: R18, R19, R25 (headless with a fixture world
   item; the Backpack/WorldItem lanes stay green).
4. **X eyes + topple.** Dying: clear any Emote, `Request_SetStateExpression(utils_eyes::Expression_Downed())` (cell 20, no duration,
   no blink/look); it must survive a timed-expression duration and a face primitive recreation (re-seed CPD 0..13 through the Eyes
   feature and CPD 14 = 1 on the recreated primitive). Topple side from the hit impulse direction (left/right authored clips
   `DeathToppleLeft/Right`), falling back to the safe side when the floor clearance test fails; then `DeadHold`. Test: R20 headless
   (Eyes state + CPD readback via the Eyes feature's own accessors, no renderer).
5. **Dither.** Empty return: after DenEnter's crouch-in, FadeAlpha 1 -> 0 over 0.25 s on EVERY rat primitive (body mesh, eye plate,
   any extra component) through one clock in the kernel (`FMars_Fragment_PantryRat.FadeAlpha` written by the HandleRequests/Tick
   drain, presentation copies it to CPD 14 each frame it changes); hidden + Dormant only on completion; reset to 1.0 while hidden,
   BEFORE the next emergence's first visible frame. Corpse: 1 -> 0 over 0.35 s after step 3's admission; destroy once at 0 with no
   owned/pending loot. Loaded veto: any fade/return/despawn request while the pocket is non-empty is refused (R23). Isolation: two
   rats, one fading, one solid; CPD 0..13 untouched by the fade write (read back); the spoon and harness fade with the body (same
   primitive); the dropped food and the den never receive the rat alpha. Tests: R21, R22, R24 headless (fragment values + CPD readback
   on the component); visual proof in step 6.
6. **The full court story in PIE** (the deliverable of this phase). Sequence, in one PIE session, captured as frames + the log:
   grounded cheese pack -> den eyes lit -> emerge -> bound/observe bursts -> seated chef guard (rat waits, no claim) -> chef leaves,
   pack stays -> inspect + rummage -> snatch the mushroom (Monk's Rind or mushroom, say which) -> loaded flee around the obstacles
   with the chef chasing -> one weapon strike -> X eyes + topple -> the SAME mushroom entity dropped at the mouth -> 3 s hold ->
   corpse dithers out while the mushroom stays solid -> chef picks the mushroom up. Then separately: pick the pack up before any
   theft -> the empty rat returns, crouches in, dithers out in 0.25 s, the den eyes come back; a second emergence starts solid.
   How to drive it (facts from earlier campaigns; verify the calls against the live Monolith schemas first):
   - `editor_query run_pie_smoke` / `capture_pie_movement_clip` with `probe_scripts` (python probes at timestamps) and a view
     target actor are the capture tools; Phase 2's `pantry_rat_review_ue.py` and the bat's `cellar_bat_review_ue.py` show the pattern.
   - Chef movement: Move/Look are Enhanced Input bound directly, and injected `Mars_IA_Look` reaches the look channel. Buttons are
     CkIntent rows read by HFSM tasks; injected IA presses do NOT reach CkIntent rows. The searing campaign opened interaction
     intents from python through `Ck_Utils_InteractionResolver_UE.request_start_intent` (recipe in `docs/plans/searing/PROGRESS.md`).
     For the attack, find the public request the chef's attack intent row issues and call that from a probe; say exactly what you
     called. If no injection path reaches a real attack, FALL BACK to a scripted chef stand-in (an entity script that walks the
     chase corridor and issues the same public strike request) and label the run "scripted chef, not player input" - that run is
     evidence for everything except R15, which then stays NOT RUN for the maintainer.
   - Deliver: `review/phase4/pie/<run>/frame_*.png`, a contact strip, the PIE log excerpt with the rat's phase transitions (log one
     line per transition with the rat id, phase, loot handle), and a table mapping each story beat to the frame range and log line.
7. **Catchability (R15).** With the real chef movement asset values (read them from the project at runtime - the debugger page
   `Script/Debugger/Pages/Mars_DebugPage_Player.as` prints `Movement.MaxWalkSpeed`; cite the asset) and the real attack reach/windup
   from the Attack clip, run the chase of step 6 three times from the same start and report: time to first strike opportunity,
   whether a strike landed, and the loaded speed/pause values used. Loaded 320 cm/s is the spec's starting value, not a claim; if
   the chef cannot catch the rat in the arena within ~20 s on walk alone, lower the loaded speed or lengthen the pause and record
   the change in `ASSET_AND_GAMEPLAY_MANIFEST.json` and the production PROGRESS. If every run needed sprint, say so plainly.
8. **Gates.** Focused patterns first (`PantryRat`, `RatDen`, `PantryRaid`, then CargoSlot, SurfaceNavigator, Backpack, WorldItem,
   Eyes, Monster, Attack, Health). Then ONE full gate (`--test --no-live --discover-fresh`, no pattern) on the FINAL binaries and
   sources - this is the single full run the project rules allow for the campaign, so it runs last, after the last edit, as a
   detached process (it exceeds 2 h background limits; wait on its exit). Report: `[population]`, `=== Known reds ===`, every
   `Still red (listed)` by name, every `Now passing`, every NEW failure by name with whether you caused it, Contaminated, the exit
   code, and the renderer-only section outcome (exit 81 means those tests did not run; say so). A green run that predates any
   later edit is stale: re-run.
9. **Multiplayer (R30).** Do not implement replication. Read and cite the facts: CargoSlot inventories, Monster team/dead attributes
   and the rat pocket are `ECk_Replication::DoesNotReplicate`; WorldItem defaults; whether SurfaceMotion/Navigator replicate. Write
   the R30 verdict as BLOCKED with the exact prerequisite (which ownership path must replicate before a client can see the correct
   loot/dead/fade state) - never as PASS, never as "works locally so fine".
10. **Save/reload + repeat.** Save the court map and any new assets by name (`save_loaded_asset`), re-run `CandidateAssetsReload`
    in a fresh headless editor (R29), then repeat the step 6 story once more on the reloaded map (shorter capture is fine) and say
    it matched.

## Reporting back
`Tools/Blender/mars_monsters/pantry_rat_r01/PROGRESS.md` Phase 4 section with: files created/changed; the per-row table R01-R30 with
PASS / FAIL / BLOCKED / NOT RUN and the evidence for each (test name + run dir, or frame range + log line); Toolbox run dirs and exit
codes with named results (the full gate's known-red/new-failure block verbatim); the story beat table; the catchability table and any
tuning change; the R30 blocker text; what stays unverified; the one claim you would most expect to be wrong. Hand back the same in
your final message. Nothing committed, nothing pushed, no production map or plugin touched.
