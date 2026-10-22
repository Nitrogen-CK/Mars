# Phase 4 bounded reconciliation amendment

Approved for execution by the phase lead under the user's 2026-10-21 instruction to reconcile concurrent Bellkeeper/Control/Dial changes and execute Phase 4. Preserves the encounter's intended behavior and every shared mechanism implementation. No MP or Phase 5.

## Retain

Retain inherited opt-in Control FreeTurn, Dial Angle/Turn/Settle, grip/look turning, release snapping, uniform detent clicks and no threshold ring. Travel remains the default for levers/chains. Retain Phase 4's documented existing kernel deviations: owned timer, generalized reward array with the last kept, same-entity commit sink and optional source. Sequence remains untouched. Actual discovery counts replace stale planned counts.

## Confirmed source counterexamples; behavioral reproduction precedes repair

1. A live-pulse wrong commit rearms Bellkeeper's timer and requests the same asserted Source level. MechanismSource discards unchanged output; the existing Trap responds to powered changes and its nonloop Cycle does not restart. Source/timer-only tests do not establish a new telegraph/burst.
2. A gripped dial may point at 50 degrees while its nearest index is 1. A correct commit then locks it; the current locked early return drops the later release Settle, permanently freezing the pointer between glyphs.
3. The panel has detent audio but no required verdict bell strokes. This is missing assembly work, not an audio-verification pass.

## Bounded composition repair

The panel constructs one unchanged `UMars_Vent_EntityScript` as a lifetime-owned child through the existing archetype spawn/constructed-promise APIs. Its spec is the existing nonloop BurstVent and its Sink is empty. Placement, direction and push impulse remain authored by v7. The panel finishes its own local construction first: the framework defers child spawning while the lifetime owner is still constructing. Only the child's completed-construction callback initializes Bellkeeper with its public Cycle handle. The commit sink remains absent until then. Verify this through an actual opted-in panel spawn; direct Cycle fixtures do not exercise this lifecycle.

Add an optional explicit Cycle construction input to Bellkeeper, preserving existing consumers that omit it. Warrens requires the dedicated-cycle configuration. Bellkeeper is the sole controller of that Cycle; `P4.Vent` remains semantic output and must not also power the child through a Sink. No global discovery or direct fragment writes from assembly.

On failure, a stopped dedicated Cycle receives Running directly. A running Cycle receives Stopped with restart intent retained in Bellkeeper state. Only the actual Stopped acknowledgement permits the subsequent Running request. Starting/restarting the pulse clock follows the acknowledged Running transition. Process callbacks as feature requests; copy/revalidate state and ignore stale events/timer identities. A solved lock cancels restart intent before stopping the vent and clearing its clock/output. Owner teardown destroys the child and all work. Preserve the legacy source-only contract for existing callers; do not claim their external channel-driven vents gain the new dedicated-cycle restart behavior.

Do not use a delay, a timing margin, same-drain false/true Source requests, polling Source false as downstream acknowledgement, a chain cooldown, hidden lockout, lost-cost suppression, or changes to shared Trap/Cycle/Source/Driver/Sink/Vent/PullChain implementations. Those alternatives either race coalescing, alter the policy or broaden scope.

When a Dial lock applies, settle its angle to the detent represented by its current index before freezing further movement; publish the actual final angle. Later step/turn/settle requests remain ineffective while locked. This adds no per-dial correctness feedback before commit.

Implement the missing wrong/correct bell strokes in panel assembly using existing suitable assets. Verify actual captured sound or retain a clear human-audio acceptance blocker; a PlaySound call is not an observation of loudness.

## Required proof

Capture fresh unchanged focused baselines. First reproduce the two counterexamples using actual Bellkeeper/Dial and the actual Source/Sink/Trap/Cycle coupling; preserve red results. Then verify:

- Wrong commits during Telegraph and Fire stop/disarm and begin a fresh Telegraph then Fire; clock starts from actual Running and both intended durations can finish.
- Solve while restart awaits acknowledgement prevents a later restart; stale timer/events cannot truncate or rearm the replacement.
- Owner teardown leaves no owned Cycle/vent/timer work.
- A correct commit while a dial is between detents locks its visible pointer exactly on the selected glyph; later release cannot move it.
- Existing Control/Dial/Bellkeeper and relevant Sequence/Trap/cache gates retain their actual baseline results; no full suite or repeated Phase 3 pack lanes.

All existing Phase 4 v7 phrase/cache/placement, pre-apply preview, checkpoint, normal-input physical and local two-role acceptance gates still apply. One local placement/light correction only. A new semantic mismatch or failure outside this amendment is a STOP, not permission for another architecture.
