# Screaming Turnip R01 - verification report (Phase H, 2026-11-06)

**Headline:** the v1 slice (planted -> unarmed harvest -> held -> thrown -> physically settled -> repeated screams) runs end to
end in PIE on the x3.0 (48 cm) asset with the real mouth. One scream is committed per cycle at 9.51 s start-to-start. The
`Inhale` / `Scream` morphs play in game, and the tired warning clip is wired. Of the 18 acceptance cases, 10 PASS, 5 are
PARTIAL, 3 are NOT RUN, and T11-T13 are out of scope by ruling. Nothing is committed.

Every claim is **confirmed** (the evidence is named: a log, a run.json row, a capture, or a test result) or **inferred**
(the reason is given). The evidence roots used below are:
- `pie3/` = `Tools/LevelDesign/screaming_turnip_r01_review/captures/pie/run-03/` (run.json + PNGs, PIE in the review map,
  game seconds from `begin`).
- `clip/` = `Tools/LevelDesign/screaming_turnip_r01_review/captures/pie/run-03-clip/` (motion capture: `frames4/` + the
  `strip_*.png` sheets, and `run-03-clip4/run.json` next to `run-03/`).
- `pie1/`, `pie2/` = the same folder's `run-01/` (Phase F, 16 cm) and `run-02/` (Phase G, 16 cm).
- `logs/` = `Saved/Logs/`.

## T01-T18

| case | verdict | evidence |
|---|---|---|
| T01 cancel the tug before release | **PASS** | `pie3/run.json`: LMB 4.582 -> 5.135, SRC_Tug -> SRC_Cancel 5.162 -> SRC_Idle 5.432; bed `charges=1 released=0`, `world_items=0` (`F2_after_cancel` row). Test `ACancelledPullKeepsTheCharge` green (`logs/Test-TurnipH-Final-ScreamingTurnip.stdout.txt`). |
| T02 complete the harvest; two interactors race | **PARTIAL** | The completed pull is proven: bed 1 yield 0.707 s after the press, bed `charges=0 released=1 exhausted=true`, target Disable/Exhausted, `world_items=1` (`pie3/run.json` 15.227 -> 15.934). Bed 2 gives the same result (F9). Test `AnUnarmedPullReleasesOneRootAndEmptiesTheBed` is green. **The race of two interactors was not run** (single player; no second interactor rig). |
| T03 released body readiness delayed or refused | **NOT RUN** | No fault injection exists for the WorldItem spawn. |
| T04 hold through three calls | **PASS** | `pie3`: picked up during RecoveryIdle at 101.0. The held commits on the kernel clock were 89.639 / 99.144 / 108.749 / 118.271. Start-to-start was 9.509 across the pickup and 9.505 held. 9.605 was a cycle where my inhale-peak screenshot made a 0.237 s frame; the kernel then commits on that tick by design. 9.522 was held. One commit per scream (seq +1 each). |
| T05 rest on its side through three calls | **PASS** | `pie3` F4: seq 1..9 settled at the same root pose, at (76.56, -12.43, 3.15) up (0.27, 0.83, 0.49), on every row 18.1 -> 96.1. Unhitched intervals 9.510 / 9.515 / 9.508 / 9.523. The pose is never touched by animation (root bone identity, Phase B/C). |
| T06 throw during the inhale and during the scream | **PASS** | Inhale: R released at Inhale clip t 0.316 (warning 0.59), Transfer/Dormant 142.839 -> Loose 142.872; seq 13 unchanged; silent flight. It hit the east wall and settled 145.416, then a fresh ROOT_Anticipate and a scream 1.505 s later. Scream: R down at Scream t 0.08 (seq 17 committed at clock 159.537), released at 160.028 (still Scream), Transfer -> Loose. seq 17 is kept (not undone); no commit in flight or on impact. Settled 162.78 into RecoveryIdle (cooldown kept). Next Anticipate at 167.544 = commit + 8.007; next scream at 169.039 = 9.502 after. |
| T07 bounce, settle, then disturb it | **PASS** | Root 2 was thrown into root 1 while root 1 was in its Inhale (seq 23). Root 1 went LooseSettled -> Loose (Dormant, no commit) at 241.281, re-settled once at 243.093 with a fresh **ROOT_Anticipate**, and screamed 1.541 s later (`pie3/run.json` 240.6 - 244.6). One exit and one re-entry, no flip storm. Walking the chef into a settled root does not move it: the capsule is blocked ("blocked walk, remaining 59", 217.174) and the root stayed at (526.5, -462.37). The motion run also logged an exit 0.39 s after a settle under capture frame times of 0.23 s (`run-03-clip/run.json` 5.945 -> 6.336 -> 7.208): one exit, one re-entry. |
| T08 rapid re-grabs; stow / unstow | **PARTIAL** | Stow / unstow PASS (`pie3` F8): picked up in Anticipate (Transfer -> Held, resumed ROOT_Anticipate); stowed in Inhale: Transfer -> Protected, Dormant, silent. Unstowed 5.4 s later into a fresh warning: Anticipate at clock 75.717, scream at 77.229 (1.512 s). Riding the back: `crop_F8_stowed_3p.png`. Pickups preserve identity and cooldown (T04, T06). **Rapid settled <-> held re-grabs were not driven.** |
| T09 kill at the deadline; tear down | **PASS** | Test `DestroyMidWarningEmitsNoFinalScream` green. `pie3` teardown at 09.48.52: 0 `[ScreamingTurnip]` or `[TurnipReview]` lines after `BeginTearingDown`, 0 `Ensure condition failed` in the PIE window (`logs/Mars.log` 13762-14683). No audio exists, so nothing can loop. |
| T10 animation/audio disabled, replayed, hitches | **PARTIAL** | Hitches: frames of 0.21-0.40 s (screenshots, run_python) gave exactly one commit per cycle, and the next was scheduled from that commit (the 9.6 s intervals above). The capture runs at 0.15-0.36 s frames kept one scream per cycle (`run-03-clip4/run.json`). Notifies: none decide anything (kernel clocks only; Phase D design). Animation-disabled and replay were not run. |
| T11-T13 RootMaw hearing | **OUT OF SCOPE** | Maintainer ruling 2026-11-06. The kernel still broadcasts `OnScreamCommitted(sequence, position)`; no listener exists. |
| T14 peak inhale / scream, held and on its side | **PARTIAL** | Held at the peaks (`pie3/sheet_F6_held_fp.png`: anticipate, inhale curve 1.0, scream curve 1.0): the deformation is clear, the gloves stay on the flanks, and the root does not move in the hands. On its side (`pie3/sheet_F4_settled_mouth.png`) it is clear too. **Wall clipping was not inspected**: the root screamed while lying against the east wall (F7, 145-147), but no capture was taken there. |
| T15 save / reload the private review scene | **PARTIAL** | Phase C3 re-opened the review map from disk (18 actors, positions) and the PIE runs here loaded it. **The cold asset reload after an editor restart is NOT RUN** (`scripts/screaming_turnip_import_ue.py reload`; expect `readings_match: true`). |
| T16 full inventory; refused pickup or throw | **NOT RUN** | |
| T17 two independent roots | **PASS** | `pie3` F9: root 424 runs seq 1..10 (clock 3.51 ...) while root 329 runs seq 19..29 (clock 178 ...), interleaved and independent. Both beds land the same bed-relative pose (76.5, -12.4, 3.1). Test `TwoRootsKeepIndependentClocks` green. |
| T18 two players | **NOT RUN** | Network prerequisite: `UMars_WorldItem_EntityScript` and the bed are `DoesNotReplicate`. No claim is made. |

## Phase H specifics

- **AnticipateTired:** PASS. Test `TheWarningAfterARecoveryPlaysTheTiredAnticipate` samples the clip on every poll of three
  Anticipate phases: first `ROOT_Anticipate`, then `ROOT_AnticipateTired` twice, never switched within a phase. In PIE
  (`pie3/run.json`) every warning out of RecoveryIdle played `ROOT_AnticipateTired` (27.667, 37.191, 46.808 ...). Every
  warning out of Dormant played `ROOT_Anticipate`: the first after landing (18.146), after a throw (145.416), after the
  disturbance (243.093), and after a pickup resume (266.7).
- **Morphs in game:** PASS. The anim instance's curves read `Inhale` 1.0 at Inhale t 1.13-1.16 and `Scream` 1.0 at Scream
  t 0.23-0.24, settled and held (`morph` rows in `pie3/run.json`). `GetMorphTarget` reads 0, as Phase C2 established: it
  holds manual weights only. `disable_morph_target` is false. The captures show the morph shapes: the inhale cheek lobes
  and the scream's rolled rim with both tooth rows (`pie3/sheet_F4_settled_mouth.png`, `sheet_F6_held_fp.png`). Nothing
  needed fixing: the single-node player drives the curves.
- **Motion** (`clip/strip_*.png`; slomo 0.15 over the warning / scream / recover, 1.0 over RecoveryIdle; one frame is
  about 0.05 game s):
  - Scream snap: one intermediate frame (squarish half-open), then the full gape.
  - Shake: the leaves and bulb visibly change angle frame to frame through the held gape. The frequency is not
    resolvable: 20 Hz sampling against a 15 Hz shake.
  - Recover: the gape closes over about three frames, through a squarish half-open frame (B3-1), to the pucker. It reads
    as a quick close, not a pop.
  - AnticipateTired: the leaves rise from the drooped RecoveryIdle over the whole clip with no single-frame jump.
  - My judgement, not measured: the RecoveryIdle -> AnticipateTired cut does not pop.

- **The pull's glove targets** (coordinator request): the bed now declares a grip table on the leaf stalks (manifest
  `HarvestGrip_R` / `_L` + `k_PlantedOffset`, Power pose).
  - In PIE the gloves' grip bones landed on the nodes within 0.1 cm, with the lowest fingertip 4.3 cm above the floor
    (bed top 2.06). **Confirmed** (`run-03-pull/` event `P6_bed2_cancel_t012`, `crop_P6_bed2_t012.png`).
  - The nodes are static: they do not ride the SRC_Tug dip.

## Gates of record

Toolbox v1.73, test-only path beside the open editor. Quiescence was checked before each run (no "Full Reload is
required" pending, no `.as` edit in flight).

| pattern | Phase H result | knownReds |
|---|---|---|
| ScreamingTurnip (before the grip addendum) | **10/10**, exit 0 | none ran, no new failure |
| Cookbook (before the grip addendum; the addendum touches no Cookbook path) | **5/5**, exit 0 | none ran, no new failure |
| WorldItem (before the grip addendum; the addendum touches no WorldItem path) | **25/25**, exit 0 | none ran, no new failure |
| ScreamingTurnip (iteration, before the last comment-only bed edit) | 10/10 | none ran, no new failure |
| GripPoint (after the x3 grip numbers) | 5/5 | none ran, no new failure |
| ScreamingTurnip / FPHands / Forage (after the harvest-grip addendum, the last code change) | 10/10 / 34/34 / 9/9 | none ran, no new failure |

Logs are `logs/Test-TurnipH-*.stdout.txt`. Earlier gates of record (in PROGRESS.md):
- Phase D: ScreamingTurnip 8/8, WorldItem 23/23, Forage 9/9, Cookbook 5/5, FPHands 31/31, HeldItem 5/5.
- Phase E: GripPoint 5/5, FPHands 34/34, HeldView 2/2, TPBody 4/4, WorldItem 25/25, HeldItem 6/6, Searing 39/39,
  Interactable 14/14, Forage 9/9, Station 74/76.
- Phase G: ScreamingTurnip 9/9, WorldItem 25/25, FPHands 34/34, HeldItem 6/6, Forage 9/9, Interactable 14/14; the A/B
  run `Test-TurnipG-AB-NoRunAfter` was 0/1 by design.

The two Station reds (Phase E):
- `CkTests.UnitTests.CkCrowd.StationaryMarkup.WindowedSpeedThreshold` is red alone too. It is a C++ CkCrowd unit test
  in the CkTests submodule that no AngelScript change reaches. It is not this campaign's (**inferred** from scope; no
  A/B stash run). Prime suspect: the sibling-dirty submodule binaries.
- `Mars_AutoTest_FryStation_TheOperatorsKeysDriveTheSkimmer` was green alone and 8/8 in its group: a flake.

No full gate was run (maintainer rule: focused patterns only).

## Placeholder or deferred

- No audio or VFX cues exist (scream, inhale, harvest, impact).
- `SRC_Grip` and `SRC_Release` are not played (Tug on start, Cancel on a failed finish); `ROOT_ImpactSquash` and the
  settle-rock overlays are not played.
- B3-1: the squarish half-open Recover frame is visible in motion (above).
- Rim corners: a darker violet patch inside the upper-left rim and grey wedges at the rim corners at full gape, held and
  settled (`sheet_F6_held_fp.png`, `strip_cycle1_*`). It is mild under the review light. The cause is still the Phase C2
  inference: recomputed morph normals.
- RootMaw hearing is out of v1 by ruling.
- Networking: the WorldItem is `DoesNotReplicate`; this is an explicit prerequisite and no claim is made.
- The bed's `EMars_Interactable_DisableReason::Exhausted` and the grip-point producer are Phase E changes outside this
  campaign's own files, and they are uncommitted.

## Maintainer steps left

1. Run the cold-reload stage after the next editor restart: `scripts/screaming_turnip_import_ue.py reload`. Expect
   `readings_match: true` and an empty `hash_diff` against `review/phaseC3/readback_pre_restart.json`.
2. The 16 vs 22 cm question is superseded by the x3.0 ruling (48 cm). Confirm the size in the held first-person view
   (`pie3/crop_F6_held_fp.png`): the root sits low between the gloves with its mouth in the lower third. Raising it is
   `k_HeldLocation` Z in `Script/Items/Mars_Item_ScreamingTurnip.as` (currently -25.5).
3. Optional: a third mouth round on the oval (B2b remainder).
4. Commit decisions. Nothing is committed: the campaign's new files (Script/, Tools/, Content/ArtCandidates/), the Phase E
   edits to shared files, and the editor's regenerated `Script/Generated/*` and `AutoTests_Mars_MAP.umap` side effects.
5. Optional: wall-clipping (T14), rapid re-grabs (T08), the two-interactor race (T02), and full inventory (T16) in a
   later PIE pass.

## Phase I - the pull rows (Opus, 2026-11-06; detail in PROGRESS.md "Phase I Part 1b + Part 2")

| row | verdict | evidence |
|---|---|---|
| I-1 stems stay seated, geometry unchanged | **PASS** | `review/phaseI/rebuild_compare.json`: 0.0 cm on rest / keys / bones / statics; only 40 stem weights changed. `anim_report.json` stem_gap <= -0.315 on every clip (ROOT_Anticipate +0.317 closed). |
| I-2 SRC_Tug crown 39.5 +- 0.5 | **PASS** | `crown_travel.json` 39.50; Unreal readback `reimport_phaseI` per-frame landmarks <= 8e-5 cm. |
| I-3 untouched clips unchanged | **PASS** | `diff_expected_anims.py --bones-only` exit 0; Unreal clip readback diff limited to the three SRC clips. |
| I-4 SK reimport: morphs, tris, bones, sockets | **PASS** | Monolith: [Inhale, Scream], 3188 tris, 17 bones, 6 sockets identical; readback groups PASS. |
| I-5 pull length 0.4 + 1.0 s, Tug at half rate | **PASS** | `captures/pie/run-04-pull/pull_rows.json` bed 2: Grip 0.41 s, Tug 0.97 s, rate 0.50. |
| I-6 sockets rise >= 7 cm | **PASS** | +7.55 / +7.51 cm (bed 2 / bed 1). |
| I-7 gloves on the sockets | **PASS** (end to end) | Glove vs previous-frame socket 0.000 cm; same frame <= 0.53 cm (one frame of travel). Node-to-socket not readable (private handles). |
| I-8 cancel: start alpha, no jump, gloves ride down, ends SRC_Idle | **PARTIAL** | Ends SRC_Idle; start alpha 0.36 at Tug alpha 0.59 (+0.46 cm step). Crown socket moves 2.12 cm in one 64 ms frame (rate-1 Cancel), above the 1.5 cm rule at this sampler's fps. **The gloves let go on the cancel** (23 cm off after 64 ms). |
| I-9 full strain look | **PARTIAL** | `run-04-pull-strain/S3_tug_end_side.png`: stalks stretched out of a slight dome, no gap. First person (`S2`): the dome is hidden by the gloves and prompt. |
| I-10 motion clip | **PARTIAL** | `run-04-pull-clip/strip_tug_side_f15_f21.png`: a smooth rise, but only about 4 frames of the Tug. |
| I-11 0 ensures; Sandbox restored | **PARTIAL** | 0 ensures in Mars.log 19338-20084. **Sandbox not restored**: the review map is dirty from the SK reimport, and the discard-load was refused by the session's permission classifier. Nothing is dirty outside the owned folder. |

## Phase J Part 3 - the walk-away pull in Unreal (Opus, 2026-11-08; detail in PROGRESS.md "Phase J Part 3")

Paths: `R` = `Tools/LevelDesign/screaming_turnip_r01_review/`.

| row | verdict | evidence |
|---|---|---|
| J-1 SK (1b weights) + SRC_Tug / Cancel / Release reimported, readback | **PASS** | `R/phaseJ/reimport_phaseJ.json`: 4 groups PASS; Tug crown f15 (-35.998, 0, 42.3013) err 0.0; frames 15 / 7 / 6; diff vs `reimport_phaseI` only the bounds and the 3 clips (plus < 1e-3 cm reference drift on 2 untouched clips). |
| J-2 SK bounds cover the lean | **PASS** | Bounds with extension (-64.69, -28.04, -8)..(30.21, 28.04, 68); `was_recently_rendered` true on every visible row; `R/captures/pie/run-05-walk-clip-edge` frames 082-090: the bulb at the frame edge, the stalks drawn. Bind bounds wholly off-screen not framed. |
| J-3 alpha tracks (d - d0) / WalkCm within 0.1 once settled | **PASS** at rest / **PARTIAL** walking | At rest <= 0.0029 (`R/phaseJ/rest_error.txt`); walking at 30 cm/s the spring trails 0.105-0.113 (`R/captures/pie/run-05-walk/walk_rows_analysis.json`). |
| J-4 socket travel within 3 cm of alpha x 38.2 | **PARTIAL** | Max 4.38 cm (A, 15 fps) / 2.97 (B): the clip's ease, up to 2.98 cm (`R/phaseJ/clip_linearity.txt`), plus the pose one tick behind the scrub (it matches the clip at the previous alpha within 0.012 cm, `R/phaseJ/pose_lag.txt`). |
| J-5 gloves on the grip targets <= 0.5 cm, reach-cap frames | **PASS** (end to end) | Glove(n) vs socket(n-1) 0.000 cm on all clean rows; 0 reach-cap shortfall rows; same tick <= 3.16 cm (15 fps) / 2.02 (B). Node-to-socket not readable. |
| J-6 release at alpha >= 0.97 | **PASS** (crossing inferred) | The root is out one tick after alpha 0.953-0.968 (ring 0.983 / 0.998), 4 pulls. |
| J-7 yaw faces the player within 5 deg; a sidestep follows | **PASS** after the turn | <= 0.001 deg from the turn's end; sidestep -90 -> -66.2 / -61.5, err 0.001. The turn starts after the Grip (2-3 ticks), not during it. |
| J-8 the prompt ring fills | **PASS** | abs(ring x 0.97 - alpha) <= 0.00014 (B, 727 rows). |
| J-9 cancel: start ~1 - a, no socket jump > 1.5 cm, gloves ride down, ends SRC_Idle, charge kept | **PARTIAL** | Start 0.405 at a 0.586; in-clip 1.22-1.28 cm per ~60 Hz sample; **switch frame 3.57 cm** (authored Tug(a) / Cancel(1 - a) mismatch); **the gloves leave** (Script side); SRC_Idle at 0.44 s; charges=1, pull 2 released. |
| J-10 captures | **PARTIAL** | First person: the prompt hides the turnip. Side: the dome low in the soil, long low stalks to the chef's hands, the root airborne (`R/captures/pie/run-05-walk-clip/sheet_pull_side.png`). |
| J-11 0 ensures, Sandbox untouched, 0 foreign dirty | **PASS** (turnip) | Mars.log 3406-5467: 1 ensure, line 4635 `InRHITexture` D3D12, at `MONOLITH_CLIP begin` before any driver step; sessions A / B / D 0. 0 dirty packages; the Sandbox file unchanged. |

## Phase J Part 3b - Cancel mirror, aim from the press, 110 cm stand (Opus, 2026-11-09; detail in PROGRESS.md "Phase J Part 3b")

Paths: `R` = `Tools/LevelDesign/screaming_turnip_r01_review/`; run files under `R/captures/pie/run-06-walk/`.

| row | verdict | evidence |
|---|---|---|
| J-12 SRC_Cancel reimported alone, readback | **PASS** | `R/phaseJ/reimport_phaseJ_clips.json`: 4 groups PASS; 7 frames; chain Tug f15 -> Cancel 1.1e-5 cm; only SRC_Cancel saved; diff limited to SRC_Cancel (and one manifest-envelope margin number). |
| J-13 yaw starts on the press, within 5 deg before the Grip ends | **PASS** | `walk_rows_analysis.json` `yaw_from_press`: within 5 deg at +0.120 s (45 deg turn) and +0.195 s (90 deg); the turn starts on the first SRC_Grip tick. |
| J-14 bed 0 back-off to the break from 110 cm | **PASS** (alpha while walking as J-3) | d0 110.44; rest error <= 0.002 (`R/phaseJ/rest_error_run06.txt`); ring abs(x 0.97 - alpha) <= 0.00014; break one tick after alpha 0.967; gloves lagged 0.000 cm on 121 rows (`R/phaseJ/run06_gloves_bed0.txt`). |
| J-15 first-person captures with the gloves on the stalks, lean toward the camera; side capture for the dome | **PASS** (my read) | `sheet_bed0.png`, `zoom_K1_K4.png`, `sheet_side_bed1.png` K5; `R/captures/pie/run-06-walk-clip/sheet_pull_side.png`. |
| J-16 cancel switch jump <= 1.5 cm, spanned steps <= 1.5 cm, charge kept | **PASS** (let-go at 0.65, not 0.5-0.6) | Switch row 0.371 cm, first Cancel-pose row 1.019 cm (Part 3: 3.57); in-clip 0.88-1.41 cm per ~60 Hz sample; charges=1. The gloves still leave (Script side). |
| J-17 second pull on bed 1 after the cancel | **PASS** | Break one tick after alpha 0.968; `bed1_after` released=1. |
| J-18 0 ensures, Sandbox untouched, 0 foreign dirty | **PASS** | Mars.log 5562-6326: 0 ensures (clip tool included); 0 dirty packages; Sandbox mtime unchanged. |

## Phase J Part 3c - the 2x stretch in Unreal (Opus, 2026-11-09; detail in PROGRESS.md "Phase J Part 3c")

Paths: `R` = `Tools/LevelDesign/screaming_turnip_r01_review/`; run files under `R/captures/pie/run-07-walk/`.

| row | verdict | evidence |
|---|---|---|
| J-19 SK + SRC_Tug / Cancel / Release reimported, readback | **PASS** | `R/phaseJ/reimport_phaseJ_1d.json`: 4 groups PASS; Tug crown f15 (-71.9944, 0, 45.7995) err 0.0; frames 15 / 7 / 6; diff limited to the 3 clips and the bounds. |
| J-20 bounds cover x -100..+30 | **PASS** | (-100.69, -28.04, -8)..(30.21, 28.04, 70); `was_recently_rendered` true on every visible row. |
| J-21 alpha vs (d - d0) / 74.2 at rest within 0.01 | **PASS** | 0.0016 (`R/phaseJ/rest_error_run07.txt`). |
| J-22 sockets follow the scrub; gloves <= 0.5 cm lagged; reach-cap shortfalls | **PASS** | Previous-tick clip match <= 0.017 cm (`pose_lag_run07.txt`); glove lag 0.000 cm on 332 rows; 0 shortfall ticks (MaxReachCm unset, `Mars_PlayerCharacter_Assets.as:225`). |
| J-23 the focus holds to the break | **PASS** | Ring up on every Tug row; no drop; break at d 184.6 / 189.6 cm, pitch -27.7 / -27.1 deg (`R/phaseJ/run07_extra.txt`). |
| J-24 release at the threshold | **PASS** (crossing inferred) | Released after alpha 0.946 (inside a 0.094 s screenshot tick) and 0.969. |
| J-25 captures, the dome, the rods, faceting | **PASS** (my read) | `zoom_K4b_stalks_fp.png`: faceting visible (flat light / dark bands per face); `zoom_K5_rods_side.png`: rods to a low dome, no neck; `R/captures/pie/run-07-walk-clip/sheet_pull_side.png`. |
| J-26 cancel: switch jump, steps per 60 Hz, charge, second pull | **PARTIAL** | Let-go 0.496; switch 0.23 cm (first drawn row 1.38 cm incl. about 1.0 cm of play); **steps 2.0-2.5 cm per 60 Hz frame (peak 2.67), over 1.5**; charges=1; pull 2 released. Span of about 1.17 s needed (inferred). |
| J-27 0 ensures, Sandbox untouched, 0 foreign dirty | **PASS** | Mars.log 7737-8506: 0 ensures; 0 dirty; Sandbox mtime unchanged. |

## Phase J Part 3d - the 4x stretch in Unreal (Opus, 2026-11-09; detail in PROGRESS.md "Phase J Part 3d")

Paths: `R` = `Tools/LevelDesign/screaming_turnip_r01_review/`; run files under `R/captures/pie/run-08-walk/`.

| row | verdict | evidence |
|---|---|---|
| J-28 SK + 3 SRC clips reimported, readback | **PASS** | `R/phaseJ/reimport_phaseJ_1e.json`: 4 groups PASS; Tug crown f15 (-143.9856, 0, 51.7974) err 0.0; frames 15 / 7 / 6; diff limited to the clips and the bounds. |
| J-29 bounds cover x -170..+30, z 75 | **PASS** | (-171.69, -28.04, -8)..(30.21, 28.04, 76); rendered on every visible row. |
| J-30 the pull survives the ray leaving the 250 cm trace | **PASS** | `ray_focus.json` / `R/phaseJ/ray_focus_run08.txt`: bed 1 pull 2, 38 rows with the ray past 250 cm (from d 278.7, pitch -18.6) all `focused=true` with the ring up; break at d 388.0 (ray enters at 358 cm). |
| J-31 alpha vs (d - d0) / 146.2 at rest within 0.01 | **PASS** | 0.001 (`R/phaseJ/rest_error_run08.txt`). |
| J-32 sockets follow the scrub; gloves; reach cap | **PASS** | Previous-tick clip match <= 0.033 cm; glove lag <= 0.001 cm on 667 rows; same tick <= 3.61; 0 shortfall ticks. |
| J-33 yaw within 5 deg in the Grip; release at the threshold | **PASS** (crossing inferred) | 0.094 / 0.181 s after the press; break after alpha 0.969 / 0.968. |
| J-34 spring lag at full walking speed | **FINDING** | Trail up to 0.54; the break at 276.8 cm walked, 130.6 cm past WalkCm (`R/phaseJ/run08_extra.txt`). |
| J-35 captures: rods, cone, stipple, faceting, clip | **PASS** (my read) | `zoom_K5_rods_side.png` / `zoom_K5_cone_side.png`: square rods about 1.5 m, a pink cone, the stipple reading as a dashed line; first person: the gloves and leaves leave the frame at full strain; `R/captures/pie/run-08-walk-clip/sheet_pull_side.png`. |
| J-36 cancel: switch, steps per 60 Hz, charge, second pull | **PARTIAL** | Let-go 0.473; switch row 0.19 cm; **steps median 4.11, max 5.57 cm per 60 Hz frame**; charges=1; the full-speed pull 2 broke. A span of about 1.9 s is needed for 1.5 cm (inferred). |
| J-37 0 ensures, Sandbox untouched, 0 foreign dirty | **PASS** | Mars.log 8795-9600: 0 ensures; 0 dirty; Sandbox mtime unchanged. |

## Phase J Part 3e - the bed's spring at 400 / 40 (Opus, 2026-11-09; detail in PROGRESS.md "Phase J Part 3e")

Paths: `R` = `Tools/LevelDesign/screaming_turnip_r01_review/`.

| row | verdict | evidence |
|---|---|---|
| J-38 hot compile clean | **PASS** | Mars.log 9613-9618, no errors, no Full Reload. |
| J-39 full-speed overshoot past WalkCm within ~25 cm | **PARTIAL** | +65.9 (run-10, no screenshots), +70.7, +62.1 cm (was +130.6): `R/phaseJ/run10_fast_bed0.txt`, `run10_fast_bed1.txt`, `run10b_fast_bed0.txt`. |
| J-40 gloves at full speed; arm reach | **PASS** | Glove lag 0.000 cm (run-10 bed 0, 83 rows); same tick <= 4.74 cm; eye-to-glove 82.9 -> 196.1 cm (`R/phaseJ/run10_reach.txt`). |
| J-41 the mid-pull stop: overshoot <= 0.02, settle <= 0.2 s | **PASS** overshoot / **PARTIAL** settle | Overshoot -0.0001; settled within 0.01 at 0.251 s (`R/captures/pie/run-09-walk/run09_analysis.json`). |
| J-42 cancel from 1 - a, charge kept, slow pull to the break | **PASS** | Start 0.4011 vs 0.4014; charges=1; the slow break at -1.65 cm vs WalkCm. |
| J-43 the stiff spring on a long frame | **FINDING (FAIL)** | run-09 bed 0 released at 114 cm walked, drawn alpha 0.30, on a 0.0955 s tick; one semi-implicit step from the sampled state crosses 0.97 for dt >= ~0.08 s (`R/phaseJ/run09_spring_step.txt`). |
| J-44 captures | **PARTIAL** | Valid: M1, M2, M4, M5, `R/captures/pie/run-10b-walk/N3_midwalk_side_viewport.png`. Void: M3 (camera outside the room), run-09 L3 / L4 (after the early release). |
| J-45 0 ensures, nothing dirty, Sandbox untouched | **PASS** | Mars.log 9666-10396: 0 ensures; 0 dirty; Sandbox mtime unchanged. |

## Phase J Part 3f - the substepped spring (Opus, 2026-11-09; detail in PROGRESS.md "Phase J Part 3f")

Paths: `R` = `Tools/LevelDesign/screaming_turnip_r01_review/`.

| row | verdict | evidence |
|---|---|---|
| J-46 hot compile clean | **PASS** | Mars.log 10409-10415; 0 errors / Full Reload in 10397-10613. |
| J-47 reproduction against the substepped update | **PASS** | dt 0.0955 -> alpha 0.6087 (was 1.440); no frame length crosses 0.97 from the sampled state (`R/phaseJ/run11_spring_substep.txt`). |
| J-48 full speed with screenshots: release only past WalkCm | **PASS** | Last visible tick at +58.7 cm (alpha 0.924); release inside the 0.4 s screenshot tick (`R/phaseJ/run11_fast_bed0.txt`). |
| J-49 alpha <= 0.1 per tick, ticks > 0.05 s listed | **PARTIAL** | One tick > 0.05 s: dt 0.3625, alpha 0.420 -> 0.789 (+0.369) while the target moved +0.49 (walked 74 -> 200 cm); every other tick <= 0.07. No early release. |
| J-50 gloves | **PASS** | Glove(n) vs socket(n-1) 0.000 cm. |
| J-51 the mid-pull stop | **PASS** overshoot / **PARTIAL** settle | Overshoot 0.0001; settle 0.243 s (`R/captures/pie/run-11-walk/run11_analysis.json`). |
| J-52 cancel from 1 - a, charge kept, slow break | **PASS** | 0.4119 vs 0.4116; charges=1; the slow break at -1.5 cm vs WalkCm. |
| J-53 captures | **PASS** (P4 is post-release) | `R/captures/pie/run-11-walk/sheet_fast_bed0.png`. |
| J-54 0 ensures, nothing dirty, Sandbox untouched | **PASS** | Mars.log 10614-10872: 0; 0 dirty; Sandbox mtime unchanged. |

## Phase K Part 3 - the stretch as an Unreal tuner (Opus, 2026-11-09; detail in PROGRESS.md "Phase K Part 3")

Paths: `R` = `Tools/LevelDesign/screaming_turnip_r01_review/`; run files under `R/captures/pie/run-12-walk/`.

| row | verdict | evidence |
|---|---|---|
| K-1 ABP built, bound, wired, compiles, saved alone | **PASS** (`_v2`) | `R/phaseK/animbp_report.json` / `_readback.json`: 5 nodes, 3 Property bindings, output from ComponentToLocalSpace, parent / skeleton right, not errored; `TURNIP_ABP_OK`. |
| K-1a the unsuffixed `ScreamingTurnip_R01_Mars_ABP` | **STALE, unused** | Saved with "references an unknown Anim Sequence Base" (the Sequence pin not exposed); listed by `list_errored_blueprints`; PIE runs with `on_compile_errors: suppress`. **The maintainer deletes it with the editor closed.** |
| K-2 SRC_Tug / Cancel / Release reimported; crown x fixed | **PASS** | `R/phaseJ/reimport_phaseK_clips.json`: max crown x deviation 0.0161 cm; frames 15 / 7 / 6; diff limited to the 3 clips. |
| K-3 bed 1 travel 74 / 9 set in the review map | **PASS** | export_text after the save; bed 2 unchanged; only the review map written. |
| K-4 bed 1 pops at TravelCm; sockets 74 +- 3 | **PASS** | Pop at 74.00 cm walked; sockets 73.33 at alpha 0.961 (`run12_summary.txt`). |
| K-5 crown x = -TravelCm at full strain within 2 cm | **PARTIAL** | Crown x = -a T within 0.031 cm every tick (/a = -74.005, -146.198); the bed stops at a ~0.965 (EngageAlpha), so -71.1 / -141.3. |
| K-6 bed 2 as run-11 | **PASS** | Pop at -1.63 cm vs 146.2; charge kept after the cancel; pull 2 popped. |
| K-7 gloves ride the sockets; the lag | **PASS** (prev tick) / **FINDING** | 0.000 cm to the previous tick's sockets; the pose is one tick behind the Control (drawn alpha == previous-tick Control alpha within 0.0001, `R/phaseK/run12_lag.txt`). |
| K-8 the cancel: switch <= 1.5 cm, the offset with the clip | **PASS** switch / **PARTIAL** speed | Switch step 0.25 cm; the offset follows the clip one tick late (~3 cm); steps 2.8-4.1 cm per 60 Hz tick (the 0.7 s span over 146 cm). |
| K-9 rendered with the bulb off-screen | **PASS** | 92 / 92 ticks; `Q10_bed2_bulb_offscreen.png`. |
| K-10 morph curves after the pull | **PASS** | Held root: Scream curve 1.0, Inhale 0.92; `Q11_scream_fp.png` mouth open. |
| K-11 captures | **PASS** | `sheet_fp_both.png`, `R/captures/pie/run-12c-walk/side_by_side_74_vs_146.png`, `sheet_side_cancel_scream.png` (Q9 void, retaken). |
| K-12 0 ensures, nothing foreign dirty, Sandbox untouched | **PASS** | Mars.log 14693-30989: 0; dirty []; Sandbox mtime unchanged. |
| K-13 a grip without a press (run-12b) | **FINDING** | Bed 2 SRC_Grip at 9.98 with no key held, the manipulation never began; not reproduced in run-12c. |

## Phase K Part 3b - run-13 (Opus, 2026-11-09; detail in PROGRESS.md "Phase K Part 3b")

Paths: `R` = `Tools/LevelDesign/screaming_turnip_r01_review/`; run files under `R/captures/pie/run-13-walk/`.

| row | verdict | evidence |
|---|---|---|
| K-14 cold boot: the Phase K scripts and the `_v2` ABP | **PASS** | A fresh editor (the previous one found closed, no dump): boot compile clean, no Full Reload; `_v2` runs; bed travels persisted. |
| K-15 the drawn pose is this frame's Control alpha | **PASS** | Drawn vs same-tick Control <= 0.00014 on 270 / 541 / 56 ticks (`R/phaseK/run13_summary.txt`). |
| K-16 the gloves on the sockets; the trail | **PASS** (one frame) | Glove vs previous-tick socket 0.000; same tick mean 0.25 cm at 30 cm/s, 1.35 cm (max 3.5) at full speed. |
| K-17 the strain held to the release | **PASS** | Threshold and release in the same frame; the crown at its last alpha on the hide tick, 0 only after (`R/phaseK/run13_strain_held.txt`). |
| K-18 the press-less grip | **NOT REPRODUCED** (3 / 3) | No grip before the press; Use / Primary Idle between the let-go tick and the press; grip 16-28 ms after the press. |
| K-19 the bed-2 cancel at ~0.5, charge kept, breaks | **PASS** switch / **PARTIAL** speed | Switch step 1.8-2.05 cm, equal to the in-clip steps; 3.7 cm per 60 Hz (the span); charges=1 x3; both beds released. |
| K-20 the driver's single-node calls | **FIXED** | 0 "Currently in Animation Blueprint mode" lines in the session. |
| K-21 0 ensures, nothing dirty, Sandbox untouched | **PASS** | Mars.log 1-3670: 0; dirty []; Sandbox mtime unchanged. |

## Phase L Part 2 - the gloves on the live sockets (Opus, 2026-11-09; detail in PROGRESS.md "Phase L Part 2")

Paths: `R` = `Tools/LevelDesign/screaming_turnip_r01_review/`.

| row | verdict | evidence |
|---|---|---|
| L-1 the Phase L compile clean; no single-node reads | **PASS** | Mars.log: no error, no Full Reload; 0 "Currently in Animation Blueprint mode" (1-8306). |
| L-2 glove to the same tick's socket, both beds, 30 cm/s and full speed | **PASS** | 0.000 / 0.000 cm on 183 / 29 / 433 / 39 ticks (`R/phaseL/run14_summary.txt`). |
| L-3 the drawn alpha still same-tick | **PASS** | <= 0.0001 (one let-go tick excepted). |
| L-4 the yaw carries the grips | **PASS** | Sidestep 44.29 -> 72.50 deg, yaw error <= 0.0007, gloves 0.000 cm. |
| L-5 cancel at ~0.5, charge kept; both breaks | **PASS** | Start 0.519 at a 0.507; charges=1; both released. |
| L-6 the glove frame on the stalks | **PASS** grip / **UNJUDGED** full strain | `R/captures/pie/run-14-walk/zoom_gloves.png`: fists round the stalks at the grip; at full strain the leaves hide the fingers; no twist seen. |
| L-7 regression: pulled lever | **PASS** (look) | `R/captures/pie/run-14-sandbox/G1_lever_grip.png`, `G2_lever_pulled.png`; glove-to-socket not sampled. |
| L-8 regression: two-handed pickup (Cookbook) | **PASS** (look) | `R/captures/pie/run-14-sandbox-pickups/G3b_cookbook_*`; held = Cookbook. |
| L-9 regression: one-handed pickup riding home (Red key) | **PASS** (look) | `G5b_key_*`; held = Key_Red. |
| L-10 regression: platter / dock Place | **NOT DONE** | The dock was not located. |
| L-11 0 ensures, nothing dirty, Sandbox not saved | **PASS** | Mars.log 1-8306: 0; dirty []; Sandbox mtime unchanged. |
