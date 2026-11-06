# Phase H brief - presentation on the real mouth (AnticipateTired, morph playback), final PIE pass, report

You are the Opus executor for Phase H. Read first: `PROGRESS.md` (Phases D, E, F, G, B3, C2 and their audits),
`PHASE_G_BRIEF.md` + the Phase G section (what the five fixes changed and the run-02 captures), `PHASE_F_BRIEF.md` +
the PIE driver `Tools/LevelDesign/screaming_turnip_r01_review/screaming_turnip_pie_ue.py` and helper
`Script/Editor/Mars_ScreamingTurnipAcceptance.as`, the manifest `export/ScreamingTurnip_R01_Manifest.json`
(`clip_contract`: the AnticipateTired cut), `Script/Items/Presentation/Mars_ScreamingTurnipPresentationComponent.as`,
`Script/Items/Mars_Item_ScreamingTurnip.as` (`constants_screaming_turnip_assets`), `Script/ECS/ScreamingTurnip/*.as`.

## Deliverable 0 - adopt the x3.0 numbers (Phase B4 manifest `gameplay_numbers`)

Before anything else, read `export/ScreamingTurnip_R01_Manifest.json` -> `gameplay_numbers` (written by Phase B4) and
the Phase B4 + C3 sections of `PROGRESS.md`. Update, from those numbers only (no guessing): `Grip.Points`
(x3: (0, -/+11.82, 12.0) with the yaw 180 convention Phase G set), `HeldOffset` (the hull centre must sit where the
16 cm one did relative to the cupped gloves - the manifest gives the starting value; PIE decides the final), the
planted offset (-28.8), the bed's probe half-extents / offset and release point (bed centre + ~60 cm), `ReleaseLaunch`
(re-tune so a 48 cm root lands within reach on its side), `PickupProbeRadius`, the map builder's bed spacing, and the
PIE driver's camera distances. Re-run the turnip tests (short timings) and the grip-point tests that assert the
turnip's numbers. Record every changed number with its source line in the manifest.

## Deliverables

1. **AnticipateTired wiring.** The presentation plays `ROOT_AnticipateTired` when the phase becomes `Anticipate` from
   `RecoveryIdle` (or `Recover`), and `ROOT_Anticipate` when it comes from `Dormant`/`QuietIdle`. The kernel's
   `OnPhaseChanged(prev, new)` already carries the previous phase: the component remembers the last transition it saw
   (presentation state, not gameplay state) and `Get_WantedClip` takes it as an input; the per-tick re-read must not
   flip the choice mid-clip (the chosen clip stays until the phase changes again). Add the clip stem to
   `constants_screaming_turnip_assets` and a focused test if the component logic is testable headless (a component
   unit test like the Cookbook's, if one exists; otherwise state it is PIE-verified only).
2. **Morph playback in game.** Confirm in PIE that the single-node player drives the `Inhale`/`Scream` curves
   (component `GetMorphTarget("Scream")` sampled from the acceptance helper at the scream peak, and the capture shows the
   rolled rim). If the curves do not drive the morphs in single-node mode, diagnose (curve compression settings? the
   sequence's `bEnableRootMotion`-style flags? morph target weights needing `SetMorphTarget` from curve values?) and
   fix at the right boundary; record exact evidence.
3. **Final PIE pass** (run-03) with the real mouth: F2, F3 (landing pose after Phase G's launch tune), F4 three
   settled screams with captures at inhale peak and scream peak (mouth-facing camera), F5/F6 held (first-person:
   the mouth faces the player after P-1; capture inhale peak and scream peak), F7 throw (T06 variant: throw DURING
   the scream too), F7b disturb a settled root with a second throw-in or a nudge (T07: exit then fresh warning),
   F8 stow (rides the back after P-5), F9 two roots, F10 teardown. Motion evidence: `capture_pie_movement_clip` with
   a mouth-facing camera actor (bat pattern, PIE docked and not minimized) of one full cycle on the settled root, so
   the AnticipateTired cut, the scream snap, the Recover band jump and the shake are judged in motion; say what you
   see, honestly.
4. **Verification report** `Tools/Blender/mars_ingredients/screaming_turnip_r01/VERIFICATION.md`: the T01-T18 matrix
   with PASS / PARTIAL / NOT RUN and the evidence file for each; the gate results of record (every pattern, counts,
   knownReds verdicts, the two Station reds and their attribution); what is placeholder or deferred (audio/VFX cues,
   SRC_Grip timing, overlays, B3-1, RootMaw hearing out of scope by ruling, networking prerequisite: WorldItem
   `DoesNotReplicate`, no claim); the maintainer steps left (cold-reload stage on the next editor restart, the 16 vs
   22 cm ruling, a third mouth round on the oval if wanted, commit decisions - nothing is committed); every claim
   confirmed/inferred.
5. `PROGRESS.md` Phase H section.

## Rules

Edits allowed: the presentation component, `constants_screaming_turnip_assets`, the acceptance helper, the PIE
driver, new tests under `Script/Tests/ScreamingTurnip/`, `VERIFICATION.md`, `PROGRESS.md`. Gates: `ScreamingTurnip`,
`Cookbook`, `WorldItem` on the final code (test-only path, quiescence). PIE rules as Phase F (LMB = Use/Primary, R
held > 0.35 s = throw, slot keys Two/One = stow/unstow; key down/up inside the tick callback; stop if throttled or the
editor dies; level ops via run_python; restore the level; never Save All). No git, no Content/ writes beyond the
review map if a preset is placed, no kernel changes without a measured reason recorded first.
