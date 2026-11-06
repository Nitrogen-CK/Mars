# Phase F brief - PIE verification of the vertical slice in the review room

You are the Opus executor for Phase F of the Screaming Turnip R01 campaign. Read first: `PROGRESS.md` (every section,
especially Phase C's review room and assets, Phase D's kernel facts, Phase E's grip points / HeldOffset / asset swap,
and the "not verified" lists), `docs/art/screaming-turnip-production-r01/DESIGN_TECH_SPEC.md` section 11 (T01-T10,
T14-T17), the memory-derived PIE facts below, and the code you will drive: `Script/Editor/Mars_ExpeditionAcceptance.as`
(the PIE input helper: Aim / Key / Look / Inspect, called from Python via
`unreal.new_object(unreal.load_class(None, '/Script/Angelscript.Mars_ExpeditionAcceptance'), outer=pc).call_method(...)`),
`Tools/LevelDesign/expedition_maps/playtest.py` (the proven driver pattern: begin / note / screenshot / key press
sequencing), `Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_review_ue.py` (review-room load/restore, chase
camera, `capture_pie_movement_clip` probe pattern), `Tools/LevelDesign/screaming_turnip_r01_review/screaming_turnip_review_ue.py`
(this campaign's room: PlayerStart at (-250, 0, 100), two bed entities at the origin and (450, -450, 0), GameMode
override `Mars_Gameplay_GameMode`), `Script/WorldObjects/Forage/Mars_ScreamingTurnipBed_EntityScript.as`,
`Script/WorldObjects/Items/Mars_ScreamingTurnip_EntityScript.as`, `Script/ECS/ScreamingTurnip/*.as`.

PIE facts (Orion memory, verified in earlier campaigns): injected Enhanced Input actions do NOT reach the pickup path;
`Mars_ExpeditionAcceptance` Key/Aim DO drive Use (E) and Primary (LMB) in Mars PIE; send key down and key up in
SEPARATE run_python calls; Look pitch is down-positive; interaction focus lags an instant aim snap, so press a call or
two after aiming; a minimized editor throttles PIE to ~3 fps (`playtest.py` asserts world delta < 0.1 s - keep that
assert and STOP with a report if it fails, asking the maintainer to restore the editor window); never
`capture_pie_movement_clip include_ui=true` while the editor is minimized; Monolith `run_pie_smoke` refuses on BP
compile errors (`on_compile_errors: "suppress"`); PIE visuals: user32 `PrintWindow(hwnd, hdc, 2)` of MarsEditor from
PowerShell while PIE is docked and not minimized, or `capture_pie_movement_clip` with a camera actor (bat pattern).
Level ops only through `run_python` (never `run_console_command` for a level load); restore the previously open level
afterwards; never Save All; the review map may be re-saved only if you placed something new in it.

## Deliverable: `Tools/LevelDesign/screaming_turnip_r01_review/screaming_turnip_pie_ue.py` + evidence + report

A driver in the playtest.py pattern (`begin()`, `note()`, `screenshot()`, key helpers) that, with PIE running in the
review map, performs and RECORDS (state, kernel clock, placement, phase, scream sequence, time) each of:

| step | action | required evidence |
|---|---|---|
| F1 | spawn at the PlayerStart, aim at the origin bed, verify the prompt "Pull Screaming Turnip" shows | screenshot + Inspect state |
| F2 | hold E for 0.3 s and release (T01 cancel) | no yield (count `TAG_MarsWorldItem` entities), bed charge 1, SRC_Cancel seen or stated |
| F3 | hold E through 0.7 s (T02 harvest) | exactly one yield entity, bed exhausted, empty-bed visual, item lands on the floor; screenshot |
| F4 | wait until LooseSettled, record the first settled scream time; let three settled screams pass (T05 timing with production numbers: 9.5 s start-to-start; if that is too slow for the session, spawn the bed with short Vocal via a review preset and say so) | sequence 1-3 with timestamps; one `OnScreamCommitted` per scream; clip switching seen (phase vs clip name from the presentation) |
| F5 | aim and tap E to pick it up (T04) | mount Held, placement Transfer -> Held, gloves cradle it; screenshot of the held turnip front and from a third-person chase/over-shoulder capture if cheap |
| F6 | hold through three held screams | sequence 4-6 with intervals == Cooldown + Anticipate + Inhale within a frame |
| F7 | throw during Inhale (Primary / the throw intent the HeldItemUse uses) (T06) | placement Loose within a frame, phase Dormant, no commit in flight, sequence unchanged; item lands and settles; a FULL fresh warning precedes scream 7 |
| F8 | pick it up again, stow to a non-selected hotbar slot, wait 3 s, unstow (T08) | Protected: silent; after unstow a fresh warning and the cooldown honoured |
| F9 | walk to the second bed (450, -450) and harvest it; two roots on the floor (T17) | independent sequences and clocks |
| F10 | end PIE (T09 teardown) | no ensure, no stale callback, no loop audio; `Mars.log` tail clean of `[ScreamingTurnip]` errors |

Evidence per step: a `run.json` row (playtest.py `note()` shape: time, world delta, event, Inspect state, plus the
turnip kernel readout - add a review-only readout if `Inspect` lacks it: a small `UFUNCTION` on a new
`Script/Editor/Mars_ScreamingTurnipAcceptance.as` helper that returns placement/phase/sequence/clock/current clip for
every `FCk_Handle_ScreamingTurnip` in the world; new file, nothing else in Script/ changes), the PIE screenshots named
by step under `Tools/LevelDesign/screaming_turnip_r01_review/captures/pie/`, and the `Mars.log` lines for each
`OnScreamCommitted` (add a `ck::Trace` in the review helper's binding, not in the kernel). Also capture: the held
turnip at the scream peak, the side-lying settled turnip at the scream peak (T05: it must stay side-lying), the
planted bed before/after harvest, the empty bed.

Then LOOK at every capture and answer, honestly: does the inhale read as a warning at hand distance; does the hard
cut RecoveryIdle -> Anticipate pop (B-2); do the gloves cradle the turnip plausibly (identity-rotation grip points,
HeldOffset (14, 0, -12)); does the cleaver still reach/hold correctly after Phase E (equip one from the sandbox item
presets if a review preset exists; otherwise say not checked); does the planted root sit at the soil line.

## Hard rules

- No edits under `Script/` except the one new review helper file; no kernel, item, bed or FPHands edits (report what
  you would change, with the measured reason). No Content/ writes except re-saving the review map if you placed a
  review preset in it (say so). No git. If PIE cannot start, the window is throttled, or the editor dies: stop,
  record exact evidence in PROGRESS.md, report.
- Another executor works in `Tools/Blender/` (Blender only); the mesh you see is the Phase B mesh (the mouth is being
  reworked); judge gameplay, timing, grips, clip switching and placement, not the mouth's fidelity.
- Fill the Phase F section of `PROGRESS.md`: the step table with measured times and verdicts, captures list, what
  failed or looked wrong (with your proposed fix and the file), what remains unverified. Confirmed vs inferred.

## Reporting back

The step table (F1-F10 with timestamps, sequences, placements, verdict); the visual answers above; the captures to
look at; the exact proposed fixes (file + change + reason) for anything wrong; what remains unverified; confirmed vs
inferred on every claim.
