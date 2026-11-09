# Phase J brief - the walk-away pull: hold Use, back off, the stalks stretch toward you, the root pops at the break distance

You are the Opus executor for Phase J. Read first: `PROGRESS.md` (Phases B3, B4, C2, H, I), `PHASE_I_BRIEF.md` (the
pull-follow, the socket ride, the reimport route, the PIE rules), `scripts/animate_screaming_turnip.py` (pose library,
`Clip` table, the Phase I `stem_gap` audit), `scripts/build_screaming_turnip.py` (`PKEYS` / `params_of` / `bone_targets`,
about line 1165), `scripts/export_screaming_turnip.py` (the Phase I crown + HarvestGrip tracks, about line 307),
`export/ScreamingTurnip_R01_Manifest.json` (`gameplay_numbers`, `sockets`), and on the Script side
`Script/ECS/Control/` (all six files), `Script/PlayerCharacter/HFSM/Mars_PlayerCharacter_Hfsm_Tasks.as`
(`UMars_SmTask_ManipulateControl`, about line 337), `Script/WorldObjects/Forage/Mars_ScreamingTurnipBed_EntityScript.as`,
`Script/Items/Presentation/Mars_ScreamingTurnipPresentationComponent.as`, `Script/Items/Mars_Item_ScreamingTurnip.as`
(`constants_screaming_turnip_assets`), `Script/Tests/Control/` (the Lever rigs) and `Script/Tests/ScreamingTurnip/`.
Project rules: `CLAUDE.md` (Mars script conventions: request doctrine, three layers, max 3 params, Validate mixins,
TOptional over sentinels, enums over bools), `Plugins/CkFoundation/Script/ARCHITECTURE.md`.

## Why (the maintainer, 2026-11-08, with an Astro Bot still: the robot leaning back on a stretched rope)

"I would like to update the way the radish is harvested by having it behave more like Astro Bot. The player would need to
click and hold and then walk away from the radish. The leaves and stems would stretch and then, when far enough away, it
would pull it out fully. If you release before that, it goes back to how it was."

So the pull is no longer a timed hold. Progress is the ground the player has gained since gripping the stalks; the
stalks stretch toward the player by that amount; at the break distance the root comes out (the existing Forage release);
a Use let go, or a focus lost, before that springs the plant back (the existing `SRC_Cancel` from the strain reached).

## Decisions (Fable; measured targets, not taste)

### D-J1 The kernel is the Control feature, gaining a second pull source

A ManuallyCompleted control already owns everything the pull needs except its input: a 0..1 `Pull` that a damped spring
turns into `Alpha` (`UMars_Processor_Control_Tick`), an `EngageAlpha` threshold that ends the interaction `Succeeded`,
`OnManipulationProgress` (which already fills the prompt ring, `Mars_InteractPrompt_Widget.as`), the grip-wait in the
player's `UMars_SmTask_ManipulateControl`, and the rigs under `Script/Tests/Control/`. Today the only source of `Pull`
is the look delta (`Request_Nudge`, degrees along `PullAxis`). Phase J adds a second source: the puller's horizontal
distance from the control. No new feature, no new typed handle, no new tag.

- `enum EMars_Control_PullSource { Look, Walk }` in `Mars_Control_Feature.as`; `FMars_Control_Manipulation_Spec` gains
  `PullSource` (default `Look`: every existing control is unchanged) and `float32 WalkCm` (Walk only: the horizontal
  distance the puller gains from where it gripped that reads as `Pull` 1.0; default 40). Document that Walk ignores
  `PullAxis` and `AlphaPerDegree`. `Validate`: Walk needs ManuallyCompleted, `Mode == Travel`, `WalkCm > 0`; extend the
  spec-validation test (`Mars_AutoTest_Control_SpecValidateRejectsMismatchedPolicies`) with the two new rejections.
- `FMars_Request_Control_BeginManipulation` gains `FCk_Handle_Transform Puller` and a positional ctor
  `(Interaction, Completion, Puller)`. Begin on a Walk control with an invalid `Puller` ensures and is ignored (returns
  false, as the not-ManuallyCompleted case does). `FMars_Control_Manipulation` gains `Puller` and `float32 WalkStartCm`:
  the horizontal distance between the control entity's own transform (`utils_transform::Get_EntityCurrentTransform(Self.H())`)
  and the puller at Begin.
- `UMars_Processor_Control_Tick`, Walk only, before the spring step: `Pull = Clamp((Dist - WalkStartCm) / WalkCm, 0, 1)`
  where `Dist` is the horizontal (XY) distance control -> puller now; `TowardStart` direction mirrors it (`1 - ...`) as the
  nudge path does. A Walk manipulation whose `Puller` is no longer valid ends (same path as `EndManipulation`; the
  interaction then ends by its own teardown). `ApplyNudges` on a Walk control changes nothing (comment it: the pull is the
  distance; a nudge is not an error, the player task simply does not send them).
- Mixins in `Mars_Control_Utils.as`: `Get_PullSource()`, `TryGet_Puller()` (invalid unless manipulating a Walk control).
- `UMars_SmTask_ManipulateControl`: for a Walk control, no view hold at all (`HoldView` / `ViewLock` are Look's: the
  player has to look and walk), `BeginManipulation` passes the player's own transform handle as `Puller`
  (`_Player.As_Transform()`; the player's root is the thing that walks), and `DoTick` sends no nudges. Everything else
  (the grip wait, push-end wait, refusal, OnInteractionFinished) is shared.

The alternative weighed: a new `StretchPull` kernel (anchor, puller, break distance, spring, signals). Rejected: it would
re-implement the spring, the threshold, the interaction end, the progress ring and the grip wait, about 400 lines plus
rigs, to express one line of difference (where `Pull` comes from).

### D-J2 The bed composes a Walk control; its own Pull state still does the release

`Mars_ScreamingTurnipBed_EntityScript.as` adds `utils_control::Add(InHandle, Spec)` with `Interaction =
ManuallyCompleted`, `Behavior = Toggle` (unused: the bed does not route the interaction to `UMars_SmState_Control_Engage`,
so nothing ever engages and `IsActive` stays false; say so in the comment), no Mover, `Manipulation = { PullSource Walk,
WalkCm = constants_screaming_turnip_assets::k_StretchTravelCm, EngageAlpha 0.97, Stiffness 60, Damping 12 }`. The bed's
target entry stays its own (`AddInteractable`): completion `ManuallyCompleted` (no `InteractionDuration`),
`InteractionStateClass = UMars_SmState_ScreamingTurnipBed_Pull` (unchanged: claims the target, releases the Forage),
`RequiresFreeHands`, `AfterCompletion`, `ReachKind Hold`. `TryGet_ManipulatedControl` resolves the control through the
interactable's owner, so the player's task and the prompt ring find it without a `Make_InteractTarget` call.
`GripSeconds` stays (the SRC_Grip span, 0.4 s); `TugSeconds` goes (nothing is timed any more). Expose `PullStiffness` /
`PullDamping` as spawn params only if the PIE feel needs them; otherwise constants with the numbers above.

Follow tick (`OnFollowTick`, every tick of a pull, as Phase I):
1. `Alpha = _Control.TryGet_ManipulationAlpha()` (0 until the gloves grip and the manipulation begins).
2. Yaw: the planted node (keep the `PlantedNode` of `AddVisuals` as a member) is yawed so the mesh's **-X** (the Use side;
   the HarvestGrip comment says where the reach comes from) points at the puller horizontally (`_Control.TryGet_Puller()`,
   world XY from the bed root), eased at 540 deg/s so the bulb turns during the Grip clip rather than snapping; the yaw is
   kept after a cancel (the next pull re-aims). The two grip rotations `_HarvestGripRotation_R / _L` are rotated by the same
   yaw in `DoMove_GripNode`, so the gloves keep their handed frame on the turned stalks.
3. Scrub: once `Alpha > 0` (or once SRC_Grip has played through), `_Planted.Scrub_Clip(k_Clip_Tug, Alpha)`; the grip nodes
   ride the sockets as Phase I.
4. Cancel (`OnPullFinished` Failed): unchanged in shape; `SRC_Cancel` from `1 - Alpha` (a scrubbed clip's
   `Get_PlayedAlpha()` is its scrub alpha, so the existing line stands). Break (the threshold ends the interaction
   `Succeeded`): the Pull state releases the Forage; `OnForageReleased` swaps the visuals as today.

`UMars_ScreamingTurnipPresentationComponent` gains `Scrub_Clip(const FMars_ScreamingTurnip_PresentationClip&, float32 InAlpha)`:
starts the clip if it is not the one playing (drops any chain; `HoldLastFrame`), then holds it paused at
`InAlpha * length` (`SetPlayRate(0)` after `PlayAnimation`, then `SetPosition(..., false)` each call). Prove in PIE that a
paused single-node sequence poses the bones and the morph curves at the set position (the HarvestGrip socket world
positions must move with the alpha); if `SetPlayRate(0)` does not, use `Stop()` + `SetPosition` and say so.
`Get_HasPlayedThrough` must stay false for a scrubbed clip short of alpha 1 (rate 0 keeps `IsPlaying()` true; check).

### D-J3 The stretch clip: `SRC_Tug` re-authored as a lean-and-stretch toward -X

The Phase I `SRC_Tug` lifts the crown straight up 7.7 cm. The walk-away pull needs the crown (and the HarvestGrip sockets
on it) to travel **toward the puller**, by the distance the puller gains, so the gloves stay on the stalks while the
arms stay at their reach. Targets at `SRC_Tug` f15 (UE cm, root-relative, from `expected_anims.json`):

- Crown head: **dx = -36 +- 2 cm** (along the mesh's -X), **dz = +9 +- 2 cm** from its SRC_Grip f6 position. The HarvestGrip
  sockets ride the crown, so their horizontal travel is the same; `k_StretchTravelCm` = that measured horizontal travel,
  rounded to 0.1, written to the manifest (`gameplay_numbers.k_StretchTravelCm`, with the frame note) and hand-copied into
  `constants_screaming_turnip_assets` with a comment naming the manifest key, as `k_HarvestGripLocation_*` is.
- Crown pitched toward -X so the leaves trail behind the pull (`cr_y`; take the sign from `ROOT_AirborneLeafTrail`'s
  "crown pitched -X" pose), about 35-50 deg at f15; leaves `la -12 / lb -7` (Phase I) or tighter if the sheet shows them
  fanning.
- The bulb stays planted (`bdz = PLANT_DZ`, the root bone never moves) and tilts toward the pull: `brot` (body about Y)
  about 8 deg toward -X at f15, `bh 1.04 / bw 0.98`. The taproot holds the base.
- Mid key f8 at 50-60 % of the travel (dx about -20, dz about +5), authored ease.
- The rig gains one parameter: `cr_dx` (crown X translation, design cm, scaled by `unit()` in `bone_targets`, default 0) in
  `PKEYS` / `params_of` / `bone_targets`. Every clip that does not set it is byte-identical in intent: prove it with
  `scripts/diff_expected_anims.py` (every `ROOT_*` clip and `SRC_Idle` / `SRC_Grip` identical to 0.001 cm), as Phase I did.
  Update the rig-contract text in the builder docstring and the manifest (`rig_contract`): the crown translates in X and Z
  and rotates about Y.
- `SRC_Cancel` (STRAIN -> PLANT) and `SRC_Release` (STRAIN -> REL_OVER -> REL_UNDER -> NEUTRAL) start from the new STRAIN
  automatically; re-tune `REL_OVER / REL_UNDER` only if the round trip or the sheets show the release no longer settles at
  NEUTRAL (the validator asserts the chain) or whips absurdly from a 36 cm lean. The hop out of the bed happens on the
  Forage release, not in a clip.
- Clip lengths unchanged (SRC_Grip 0..6, SRC_Tug 0..15, SRC_Cancel 0..7, SRC_Release 0..6 at 30 fps): the bed scrubs
  SRC_Tug and plays the others at authored rate.
- Deformation: the stems stretch about 3x along their length (rubber is the style); tearing, inverted faces, the blades
  detaching from the stalks, or the stem bases leaving the bulb (`stem_gap` audit > 0) are bugs. Intersections 0 except the
  documented lip folds, on every SRC clip. Look at the sheets; if the stem base rings cannot hold a 36 cm lean, say so with
  the sheet and the number, and propose the travel you can hold.

Why the travel equals the walk: with `WalkCm == k_StretchTravelCm` the sockets move toward the player by the ground the
player gains, so the gloves' reach stays what it was at the grip; the spring lag (Stiffness 60 / Damping 12) is what
briefly extends the arms, then the crown catches up (the "load tension" read). FPHands caps a reach at the spec's
`MaxReachCm` (`Mars_FPHands_Reach.as`, `Make_ReachedGrip`), so a momentary lag beyond it leaves the gloves short of the
sockets for a frame or two; that is acceptable, measure it.

### D-J4 What ends a pull

- The threshold: `Alpha >= EngageAlpha` (0.97) ends the interaction `Succeeded`; the Pull state releases the Forage.
- Use let go: the intent task cancels the interaction (`Failed`); the bed plays `SRC_Cancel` from the strain.
- Focus lost: the player's interaction trace is 250 cm (`Mars_PlayerCharacter_Assets.as:226`) over a probe box 40 cm
  either side of the bed, so backing up 36 cm while looking at the turnip keeps the focus; looking away loses it, the
  intent task cancels, the plant springs back. That is a feature, not a bug; record it.
- Walking back toward the bed un-stretches: `Pull` falls, the spring follows it down (test 4 below).

## Part 1 - Blender (start now; no Unreal, no Script/)

1. Copy `source/ScreamingTurnip_R01.blend` to `source/ScreamingTurnip_R01_phaseI.blend` before the first write.
2. Builder: `cr_dx`. Animate: the new STRAIN / TUG_MID per D-J3, commented with the target numbers. Re-animate the whole
   table, re-export (DEV-13 recipe), round trip (`fails: []`), manifest refresh (`k_StretchTravelCm`, SRC notes, rig
   contract; `scale_factor` untouched). Diff proof for the untouched clips (command + result in PROGRESS).
3. `review/phaseJ/`: `SRC_Tug_sheet.png`, `SRC_Cancel_sheet.png`, `SRC_Release_sheet.png`, `pull_chain_sheet.png` (Idle f0
   -> Grip -> Tug -> Release; and -> Cancel), `anim_report.json`, `crown_travel.json` (crown + both HarvestGrip sockets per
   frame of the four SRC clips, UE cm, plus the horizontal socket travel at Tug f15).
4. `PROGRESS.md` Phase J Part 1: pose numbers before/after, the travel table, audits, round trip, diff proof, what the
   sheets show, what remains unverified. **Stop and report.**

## Part 2 - Script + tests (after Fable's go on Part 1; the editor may be open: `--test --no-live` only)

1. Control per D-J1, bed + presentation per D-J2, `k_StretchTravelCm` per Part 1's measurement, `k_Clip_*` constants as
   they are. Remove `TugSeconds` and every reader (the test rig pins it today).
2. Tests. ScreamingTurnip rig: `Start_Pull` still starts the interaction from the bare carrier, then begins the manipulation
   itself with a puller transform entity the rig owns (`FMars_Request_Control_BeginManipulation(Interaction, AtEngageAlpha,
   _Puller)`); `Walk_Puller(cm)` moves it straight away from the bed (`utils_transform::Request_SetLocation`). Rewrite
   `AnUnarmedPullReleasesOneRootAndEmptiesTheBed` (walk past `WalkCm` -> `Succeeded`, one root, empty bed, a second pull
   fails) and `ACancelledPullKeepsTheCharge` (walk to 0.5, cancel -> `Failed`, charge kept, alpha back near 0 within
   1 s). New: `AStretchShortOfTheBreakNeverReleases` (hold at 0.8 for 1 s: alpha within 0.05 of 0.8, interaction live,
   charge kept) and `WalkingBackUnstretches` (0.8 then 0.2: alpha falls below 0.3 within 1 s). Control: new
   `WalkPullFollowsTheDistance` (Lever rig, Walk source, a puller: alpha tracks `(d - d0) / WalkCm` within 0.05 once
   settled; past the threshold the interaction ends `Succeeded`), `WalkPullIgnoresLookNudges`, and through the player
   (`Mars_AutoTestRig_LeverThroughPlayer`) `WalkPullDoesNotHoldTheView` (no `ControlPull` hold while gripped; the player's
   root is the puller). Test names in the project's sentence style.
3. Lanes, focused: `--test-pattern Control`, `ScreamingTurnip`, `FPHands`, `Interactable` (the knownReds list is the
   baseline; read the `=== Known reds ===` block; name any new red and whether it is yours). No full gate.
4. `PROGRESS.md` Phase J Part 2. **Stop and report.**

## Part 3 - Unreal reimport + PIE (after Fable's go; no lane may run during the reimport)

1. Importer `clips` stage for `SRC_Tug`, `SRC_Cancel`, `SRC_Release` only (replace_existing, the SKEL reused; the mesh did
   not change, so no SK reimport) and `readback`: frame counts, and for `SRC_Tug` the crown track's last-frame translation
   against `crown_travel.json` (bone-space, converted as `readback_b4` does). Preflight as Phase C2 / I.
2. PIE `run-05-walk` on the review map, driver rules as Phase H/I (`screaming_turnip_pie_ue.py` gains the walk steps: Use
   down, then `MoveBackward` held; sample per tick the player's root XY distance to the bed, the control's alpha, the two
   sockets' world positions, the two glove bones, the grip nodes):
   - Bed 1: back away slowly (about 30 cm/s) until the break. Prove: alpha tracks `(d - d0) / WalkCm` within 0.1 once
     the spring settles; the sockets' horizontal travel toward the player is within 3 cm of `alpha * k_StretchTravelCm`;
     glove bone to grip node <= 0.5 cm once reached (one frame of lag allowed), and the frames where the FPHands reach cap
     leaves the glove short of its socket counted and the gap measured; the release fires at alpha >= 0.97; the yaw of the
     planted node faces the player within 5 deg; the prompt ring fills. Captures at alpha about 0.3, 0.7, the break, and
     after the release (first person, HUD visible), plus a `capture_pie_movement_clip` from a side camera (PIE docked).
   - Bed 2: back to alpha about 0.5, let go: `SRC_Cancel` starts at about 0.5 (the clip row's `t`), the sockets ride back
     down with the gloves on them, no socket jump > 1.5 cm between samples, the follow ends on `SRC_Idle`, the charge kept
     (a second pull works). Then a sidestep during a pull: the yaw follows.
   - 0 ensures in the window (Mars.log range quoted); the Sandbox untouched; 0 dirty packages outside the owned candidate
     folder and the campaign's review map.
3. `PROGRESS.md` Phase J Part 3 and `VERIFICATION.md` (J-1..J-n rows: evidence files, PASS/PARTIAL), every claim confirmed
   or inferred.

## Hard rules

Part 1 writes only under `Tools/Blender/mars_ingredients/screaming_turnip_r01/`. Part 2 writes only under `Script/` (the
Control feature, the player task, the bed, the presentation component, the item constants, the two test folders) and
the record files; no `Script/Generated/*` by hand (a headless boot regenerates drivers; never commit them), no
`Config/DefaultGameplayTags.ini`. Part 3 writes only under `/Game/ArtCandidates/ScreamingTurnip/R01/` (saved per owned
asset, never Save All), `Tools/LevelDesign/screaming_turnip_r01_review/` and the record files. No git. Build and test
only via `./CkAuto/UnrealToolbox.exe --project=D:/Repositories/CkRepos/Orion/Mars.uproject` (`--test --no-live
--test-pattern <P> --output=Saved/Logs/Test-TurnipJ-<P>.log` beside an open editor; no `.as` edits while a lane runs).
No level load through `run_console_command`, never `unload_packages`, no deleting or reloading loaded Blueprints. Every
Blender script prints `TURNIP_OK` / `TURNIP_FAIL`. Final message per part: files, rerun commands, the numbers, which
sheets/captures to look at, what remains unverified, confirmed vs inferred.
