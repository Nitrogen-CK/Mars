# Phase G brief - the five PIE findings (P-1..P-5), tests, gates, PIE re-check

You are the Opus executor for Phase G of the Screaming Turnip R01 campaign. Read first: `PROGRESS.md` (Phase D, E, F
sections and audits; Phase F lists P-1..P-5 with measurements), `PHASE_F_BRIEF.md`, the Phase F driver
`Tools/LevelDesign/screaming_turnip_r01_review/screaming_turnip_pie_ue.py` and the review helper
`Script/Editor/Mars_ScreamingTurnipAcceptance.as`, then the files you change.

## Fixes (decided by Fable from the captures)

1. **P-1 face the holder.** `Script/Items/Mars_Item_ScreamingTurnip.as`: `HeldOffset = FTransform(FRotator(0, 180, 0),
   FVector(14, 0, -12))` and the grip points mirrored so the right glove stays on the holder's right (Right (0, -3.94, 4.0),
   Left (0, 3.94, 4.0) in the item frame). Verify with the existing grip-point tests (update their expected numbers if
   they assert the turnip's points) and in PIE: the mouth faces the camera when held; third-person hold still plausible.
2. **P-2 landing.** `Mars_ScreamingTurnipBed_EntityScript.as`: read how `FMars_Forage_LaunchSpec` applies linear and
   angular velocity (`Mars_Forage_Processor_Requests.as`) and what the Throwable's `(0, 180, 0)` spin does on release.
   Tune `ReleaseLaunch` to a longer hop (start (120, 0, 170)) with the angular velocity about Z (a yaw spin, no pitch
   tumble) so the root lands within reach, not mouth-down into the floor every time; it must still roll/settle by
   physics (never snapped upright). Measure the landing pose across both beds in PIE and record it.
3. **P-3 one-shot clips return to the loop.** `Mars_ScreamingTurnipPresentationComponent.as`: `Play_Clip(clip, loops)`
   gains a one-shot fallback: a non-looping clip, when it finishes (poll `IsPlaying()` / position vs length in the
   component's existing Tick, no timer), returns to the component's current loop clip (for the bed: `SRC_Idle`; for the
   item the kernel's wanted clip already covers it, so the fallback must not fight `Refresh_FromKernel` - the item's
   wanted clip wins). Bed: after SRC_Cancel it must show SRC_Idle again; after SRC_Tug on a completed pull the release
   swaps the visuals as today.
4. **P-4 scheduler edge.** `Mars_ScreamingTurnip_Processor_Tick.as`: `_RunAfter` the WorldItem processors that commit
   a mount change (read `Script/ECS/WorldItem/Mars_WorldItem_Processor_*.as` for the exact class names: Reconcile,
   Mount, Requests/Release, Launch, Arrive) so placement never trails the mount by a tick. Prove it: a test
   `Mars_AutoTest_ScreamingTurnip_AThrowOnTheLastInhaleTickDoesNotScream` (short timings; release the item on the tick
   the Inhale completes and assert no commit that tick or after; if the exact tick cannot be hit deterministically,
   assert from the processor driver order that the kernel tick runs after those processors and say so).
5. **P-5 carry on the back.** `Mars_Item_ScreamingTurnip.as`: `CarryPoint` / `CarryOffset` as `Mars_Item_Cookbook.as`
   uses (it rides the back in PIE); read what a whole food's carry does before copying anything else. Verify in PIE:
   stowed to a non-selected slot, the root rides the chef's back, not the floor.

## Gates and PIE re-check

Toolbox test-only path beside the open editor (quiescence protocol; no `.as` edits while a run is in flight):
`ScreamingTurnip`, `WorldItem`, `FPHands`, `HeldItem`, `Forage`, `Interactable` on the final code; any NEW failure solo
re-run and attributed. Then one PIE pass with the Phase F driver (F3 harvest + landing pose, F5 pickup + held facing
screenshot front, F8 stow capture, F2 cancel -> idle), captures under `captures/pie/run-02/`; look at them and say what
you see. Fill the Phase G section of `PROGRESS.md`.

## Hard rules

Files you may edit: the five named above, the presentation component, `Script/Tests/ScreamingTurnip/` (new test),
grip-point tests only to update the turnip's expected numbers, the PIE driver, `PROGRESS.md`. No other dirty path,
no submodule, no live map, no Content/ writes, no git. Mars conventions. No sleeps/timers/retries to hide a problem.
Report: per-fix what changed and the PIE evidence (file + number), gate results, what remains unverified, confirmed vs
inferred.
