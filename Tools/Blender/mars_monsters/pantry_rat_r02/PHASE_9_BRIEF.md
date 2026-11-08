# PHASE 9 BRIEF - locomotion that matches the mover, and a thief that faces the pack

Executor brief (Opus). Planner: the Fable session that owns `docs/art/pantry-rat-dens-production-r01/PROGRESS.md`. You own the
Phase 9 section you append to `Tools/Blender/mars_monsters/pantry_rat_r02/PROGRESS.md` (every claim **confirmed** with the evidence
named, or **inferred**; deviations D9-n) and the files named below. Read first: this brief; the R02 `PROGRESS.md` (R5 clips, the
Phase 5-8 sections and the cheese repair at the end); `scripts/animate_pantry_rat.py` (`bound_keys`, the `C[...]` clip registry,
the contact/drift audit near line 816); `export/PantryRat_R02_Manifest.json` (`clips`); the Phase 4 section of
`../pantry_rat_r01/PROGRESS.md` (court director, capture script); the project `CLAUDE.md` (request doctrine, three layers);
`CkAuto/.claude/skills/build-test/SKILL.md`.

## The maintainer's two complaints (2026-11-07, after playing the court)
1. "The rats are missing some walk/run/bounce animations (and whatever is necessary)."
2. "They should also always face the backpack when they are trying to steal stuff."

## What the planner confirmed (file:line)
- The rat has ONE locomotion clip for every unloaded move and one for the loaded flee. `Get_Clip`
  (`Script/WorldObjects/Monsters/Mars_PantryRat_EntityScript.as:434-481`) maps phase first; any other phase with measured speed
  > 20 cm/s gets `BoundCycle`, `FleeWithLoot` moving gets `LoadedBound`. `BoundStart`, `BoundStop`, `TurnLeft90`, `TurnRight90`,
  `Turn180`, `LoadedTurnLeft/Right` are authored and never played. `Play_Clip` (line 419) calls `_Body.PlayAnimation(Clip, Loop)`
  at play rate 1 whatever the speed.
- The bound's authored stride is a fraction of the travel. `bound_keys` (`scripts/animate_pantry_rat.py:227`) is a "visual arc
  only": the planted paws slide back about 10 cm per 0.4 s cycle (the clip table reports stance 35.7-59 cm/s), while the mover
  carries the rat at `FMars_PantryRaid_Speeds` Creep 100 / Approach 240 / LoadedFlee 320 cm/s
  (`Script/ECS/PantryRaid/Mars_PantryRaid_Feature.as:173-183`): 40-128 cm per cycle. The paws slide 4-10x; the rat glides. The
  design spec asked for the opposite ("Visual bound length follows measured movement speed", `DESIGN_TECH_SPEC.md:258`).
- Nothing faces the pack. No rotation request exists in `Script/ECS/PantryRat/` or `Script/ECS/SurfaceNavigator/` (grep). The body's
  yaw is SurfaceMotion's: it turns toward the last steering direction at `SurfaceTurnRate` 180 deg/s, and `HandleStop`
  (`Script/ECS/SurfaceNavigator/Mars_SurfaceNavigator_Processor_Requests.as:47`) sends `Steering(ZeroVector, 0)`, which keeps the
  travel tangent (`DoGet_Forward` fallbacks, `Plugins/CkFoundation/Source/CkProceduralAnimation/Public/CkProceduralAnimation/Core/CkProceduralSurfaceMotion.cpp:557-573`).
  So after the last approach burst the rat stands at the work point (45 cm off the slot, `WorkStandoffCm`) facing wherever that
  burst pointed, through Inspect (0.4 s), ClaimTell (1.6 s), ClaimTransfer and CarryMountPending.
- SurfaceMotion turns at zero speed: `StepProceduralSurfaceMotion` derives `Forward` from the steer direction regardless of
  `InSpeed` and `DoTurn` / `DoAdopt` slerp the body toward it (`CkProceduralSurfaceMotion.cpp:640-705`). A
  `FCk_Request_SurfaceMotion_Steering(Direction, 0)` is valid (`CkSurfaceMotion_Fragment_Data.h:308-313`) and sets `_Direction`
  without moving (`CkSurfaceMotion_Processor.cpp:84-103`). **Inferred until your test proves it**: that a zero-speed steer turns the
  body in place in the headless court rig.

## Decisions (deviate as D9-n with the reason)
- **Kernel, control, assembly stay separate.** Facing is a kernel request (the rat's processors issue it); clip choice and play
  rate are assembly (the entity script). No clip name, speed threshold or mesh reaches `Script/ECS/`.
- **Facing.** Add `FMars_Request_SurfaceNavigator_Face(FVector InWorldDirection)` to the navigator (array on its Requests
  fragment, drained by `UMars_Processor_SurfaceNavigator_HandleRequests`): when `Status != Moving`, send
  `Steering(Direction.GetSafeNormal2D(), 0)`; while Moving it is dropped (a move owns the steer). The PantryRat kernel issues it from
  `HandleAdvance` (`Script/ECS/PantryRat/Mars_PantryRat_Processor_Requests.as:248`) on entry to `Inspect` and `ClaimTell`, and from
  the claim path on entry to `ClaimTransfer`: direction = planar vector from the rat to the target slot's mount point
  (`FMars_PantryRaid_TargetView.SlotLocation`; fall back to `PackLocation`). The kernel already resolves the target view the HFSM
  reads (`Get_TargetView`, `Mars_PantryRat_Hfsm.as:339`); reuse that path, do not duplicate the lookup. Re-issue once per phase
  entry, not per tick.
- **Locomotion clips re-authored so a planted paw stays planted.** Author each cycle so the stance slides back at the clip's
  design speed (`drift` in the audit), and the assembly scales the play rate to the measured speed:
  - `Walk` (NEW, loop): four-beat creep at 100 cm/s, 0.5 s (15 frames), 50 cm per cycle, no flight, head low, tail trailing
    (sheet-04 "curiosity" row body). Used for Creep-speed moves (Emerge -> OutsideStand, and any measured speed below the bound
    threshold).
  - `BoundCycle` (loop): re-author at a design speed of 200 cm/s, 0.4 s (12 frames), 80 cm per cycle, the R7 apex (11.9 cm) kept.
  - `LoadedBound` (loop): design speed 280 cm/s, lower apex (9.4 cm), 0.4 s is allowed (D9: the frozen 14-frame count may change,
    name and loop flag may not).
  - `BoundStart` (one-shot, 5 frames) and `BoundStop` (one-shot, 5 frames) stay; wire them (below).
  - Frame counts in `export/PantryRat_R02_Manifest.json`, `review/phase2/clip_table.md`'s R02 copy, and
    `Script/Tests/PantryRat/Mars_AutoTest_PantryRat_CandidateAssetsReload.as` (now 35 clips) follow. Write each clip's design speed
    into the manifest (`clips.<name>.design_speed_cm_s`) - the assembly reads its play-rate reference from a constant table in
    the entity script, NOT from the manifest at runtime; keep the two in sync and say so in PROGRESS.
- **Assembly clip logic** (`Mars_PantryRat_EntityScript.as`): measured planar speed (already computed in `OnTick`, line 306) picks
  Idle (< 20), Walk (20..160), Bound (>= 160) for unloaded moving phases; LoadedBound for `FleeWithLoot` moving. Play rate =
  measured speed / the clip's design speed, clamped 0.7..1.5, applied with `_Body.SetPlayRate` each tick the clip is a locomotion
  loop (rate 1 for everything else). Edge transitions: idle -> moving plays `BoundStart` (or nothing for Walk) and switches to the
  cycle when it ends (`UAnimSequence.GetPlayLength()` + the start time, or `_Body.IsPlaying()`), moving -> idle plays `BoundStop`
  then the phase's idle clip. Keep `Play_Clip`'s "same clip, no restart" guard. Turn clips stay unused (D9: say so).
- **The bounce is the clip's apex**, not a procedural bob: no new node, no root offset; the hurtbox is unchanged.
- **Speeds and timings are not retuned** (Creep/Approach/LoadedFlee, Inspect/Rummage seconds).

## Environment and ownership (unchanged)
- Branch dev, HEAD 2154da26. No git write commands. The sibling session's dirty files untouched. Nothing under `Plugins/`. No
  production map. BusterBlock read-only. Blender 5.2 background only (`-b --factory-startup`); the R02 pipeline scripts.
- The live MarsEditor is open: never close, restart or Save-All it. Monolith MCP only (`monolith_discover` / `describe_query` first;
  `editor_query list_dirty_packages` before any PIE and before any save; the old `M_CkUsf_Look_MarsPantryRatEyePlate` master is
  dirty in memory and stays unsaved). Forbidden: console level loads, deleting / force-deleting / reloading loaded assets, raw
  `add_socket`, `unload_packages`, PIE while minimised, PIE with a dirty broken Blueprint. Reimport the changed clips with the
  import script's own task options (`_anim_opts`) over the existing `/Game/ArtCandidates/PantryRat/R02/Animation/...` assets (the
  cheese reimport in `scripts/reimport_cheese_ue.py` is the pattern); the new `Walk` clip imports beside them. Save only the assets
  you created or reimported, by name.
- Toolbox only, through the detached wrapper in `Saved/Logs/PantryRatValidation/` (one run dir per pattern: `phase9-runNN-<lane>`;
  read `Toolbox.log` + `Exit.json`). **Focused patterns only: `PantryRat`, `SurfaceNavigator`, `PantryRaid`, `RatDen`. No full gate.**
  Copy every lane-log line you cite into `Saved/Logs/PantryRatValidation/phase9-evidence-lanelines.txt`. Hash the final sources
  before the last batch and `md5sum -c` after it.

## Steps (gated; stop a gate with evidence rather than working around it)
1. **Facing, red first.** `Mars_AutoTest_PantryRat_ThiefFacesTheSlot`: court rig, a rat placed at the work point with its root yawed
   180 deg away from the slot, advanced to Inspect with a lease; assert that within 0.6 s the planar dot of the root's forward with
   (slot - rat) is >= 0.95 and stays so through ClaimTell until the claim request; also that a `Face` sent during a `MoveTo` does not
   change the move's steer. Prove it red without the request (run dir named `...-red`), then green. Add the navigator test
   `Mars_AutoTest_SurfaceNavigator_FaceTurnsInPlace` (idle navigator, Face, body turns toward it, location unchanged).
2. **Clips.** Re-author Walk / BoundCycle / LoadedBound in `animate_pantry_rat.py`; run the clip audit: planted drift for each
   locomotion loop must equal its design speed within 10 % (report the numbers), seams 0, no interpenetration, spoon/harness
   clearances as before. Render a contact sheet per clip (`review/phase9/clips/<clip>_sheet.png`) and a side-by-side with the
   sheet-04 locomotion row. Export the clips; manifest + clip table + reload test updated; roundtrip validation on the changed
   clips.
3. **Assembly.** Clip logic + play rate + start/stop edges as decided. Extend `Mars_AutoTest_PantryRat_BoundRhythm` (or add a
   sibling) so a headless rat reports the clip it would pick and its play rate at Creep / Approach / LoadedFlee speeds (the entity
   script's `Get_PlayingClip` exists; add a `Get_PlayRate` the same way) - the test runs without a body, so expose the pure
   decision as a `utils`-free private function the test can reach through the script's public getters, or test the thresholds via
   the telemetry struct. No clip name in `Script/ECS/`.
4. **Lanes green:** `PantryRat` (19+), `SurfaceNavigator`, `PantryRaid` 14, `RatDen` 6. Name every result.
5. **PIE proof on the court** (`scripts/pantry_rat_court_ue.py` story, editor not minimised, dirty packages checked): (a) a bound
   strip of 8 consecutive frames at the approach with the floor grid visible, side view, so the planner can see whether a planted
   paw holds its grid cell; (b) a creep strip at Emerge -> OutsideStand; (c) a crop at Inspect and one at ClaimTell from above
   showing the rat's nose toward the slot, with the log lines of the Face request and the phase transitions; (d) the loaded flee
   strip. Write what you see for each (paw slide in cm per cycle estimated from the grid, apex height, the rat's heading vs the
   slot). Deliver under `review/phase9/pie/`.
6. Reload proof: `CandidateAssetsReload` on 35 clips (part of the PantryRat lane).

## Reporting back
Phase 9 section in the R02 `PROGRESS.md`: files changed; the clip table (name, frames, design speed, measured drift); the request
and where the kernel issues it; Toolbox run dirs and exits with named results; the PIE strips and what you saw; what stays
unverified; the one claim you would most expect to be wrong. Same content in your final message. Nothing committed, nothing
pushed, no production map or plugin touched, no full gate.
