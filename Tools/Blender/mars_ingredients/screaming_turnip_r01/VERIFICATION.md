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
