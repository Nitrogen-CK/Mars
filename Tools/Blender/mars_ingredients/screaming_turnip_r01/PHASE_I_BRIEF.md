# Phase I brief - the pull has travel: SRC_Tug lifts the stalks, the gloves ride them; reimport; PIE at the 1.4 s pull

You are the Opus executor for Phase I. Read first: `PROGRESS.md` (Phases B3, B4, C2, G, H and the stalk-grip addendum
with its measured glove placement), `PHASE_B4_BRIEF.md` (the x3.0 contract), `PHASE_C2_BRIEF.md` (the importer's route and
rules), `PHASE_H_BRIEF.md` (the PIE rules), the scripts `scripts/animate_screaming_turnip.py` (the pose library `PLANT /
GRIP / STRAIN / REL_*`, the `Clip` table, `--clips`), `scripts/export_screaming_turnip.py`, `scripts/validate_roundtrip.py`,
`scripts/render_anims_screaming_turnip.py`, `scripts/screaming_turnip_import_ue.py` (stages `clips`, `readback`), the PIE
driver `Tools/LevelDesign/screaming_turnip_r01_review/screaming_turnip_pie_ue.py`, and `export/anims/expected_anims.json`
(per clip, every frame, the landmark bone heads in UE cm).

## Why (the maintainer, 2026-11-06, with three concept sheets: Reach / Grip / Load tension / Break free / Recoil / Recover)

"I would expect the hands to kinda follow the motion of the pull. Increase the interaction time by 2x to make it easier to
test and validate." The Script side is done by Fable in this same pass (do not edit `Script/`): the bed's two grip nodes now
ride the planted mesh's `HarvestGrip_R / _L` sockets every tick of a pull (FPHands re-reads a grip node each tick, so the
gloves follow), the pull is Grip 0.4 s + Tug 1.0 s (the clips are stretched to span the stages: play rate 0.5), and a
cancel resumes `SRC_Cancel` from the strain reached. What is missing is the travel itself: today `SRC_Tug` moves the crown
head from 31.8 to 32.4 cm (`expected_anims.json`, SRC_Tug f0 -> f15; the body squashes in place), so gloves riding the
sockets would move about 1 cm over a second. The concept's "LOAD TENSION" panel is the stalks pulled straight up, the bulb
still in the soil, the arms lifting.

## Decisions (Fable; measured targets, not taste)

- **Crown travel.** At `SRC_Tug`'s last frame the crown bone head sits at **39.5 +- 0.5 cm** UE root-relative (from 31.8 at
  f0: about 7.7 cm of stalk stretch; the HarvestGrip sockets ride the crown, crown-relative z 3.385, so they travel the
  same). The mid key (f8) at 50-60 % of the lift with the authored ease.
- **The bulb stays planted** (body `bdz` stays `PLANT_DZ`, the root bone never moves) and **elongates** under the pull
  instead of squashing: `bh` about 1.06, `bw` about 0.96 at full strain. The rim holds the shoulders; the taproot holds the
  base. If the elongation reads badly on the sheet, say so and keep a slight squash, but the crown target stands.
- **Leaves** keep their authored droop under the pull (`la -12 / lb -7` region); do not fan them.
- `SRC_Grip` is unchanged (its 1 cm dip is the hands closing). `SRC_Cancel` and `SRC_Release` start from the new STRAIN
  automatically; re-tune `REL_OVER / REL_UNDER` only if the round trip or the sheets show the release no longer settles at
  NEUTRAL (== `ROOT_QuietIdle` f0; the validator asserts the chain) or overshoots absurdly from the higher strain.
- **Clip lengths do not change** (SRC_Grip 0..6, SRC_Tug 0..15, SRC_Cancel 0..7, SRC_Release 0..6 at 30 fps): the bed
  stretches them to its stages at runtime.
- **Deformation.** The stems between the body and the crown stretch elastically (that is the style: the release is an
  elastic overshoot); tearing, inverted faces, or the leaf blades detaching from the stalks are bugs. The per-frame audit
  (intersections 0 except the documented lip folds) must hold on every SRC clip. Look at the sheets.

## Part 1 - Blender (start now; no Unreal, no Script/)

1. Copy `source/ScreamingTurnip_R01.blend` to `source/ScreamingTurnip_R01_phaseH.blend` before the first write.
2. Edit the pose library / the `SRC_Tug` key in `scripts/animate_screaming_turnip.py` to hit the targets above. Keep the
   edit minimal and commented with the target numbers.
3. Re-animate (the whole table, so the blend stays consistent), re-export (DEV-13 recipe), round trip (`fails: []`),
   manifest refresh (the SRC clip notes, the crown travel, `scale_factor` untouched). Prove the untouched clips are
   byte-identical in intent: diff `expected_anims.json` before/after for every `ROOT_*` clip and `SRC_Idle` / `SRC_Grip`
   (landmarks identical to 0.001 cm). Record the diff command and its result.
4. `review/phaseI/`: `SRC_Tug_sheet.png`, `SRC_Cancel_sheet.png`, `SRC_Release_sheet.png`, `pull_chain_sheet.png` (SRC_Idle
   f0 -> SRC_Grip -> SRC_Tug -> SRC_Release in one strip, and -> SRC_Cancel in a second), `anim_report.json`, and a
   `crown_travel.json` with the crown and both HarvestGrip socket positions per frame of the four SRC clips (UE cm).
5. `PROGRESS.md` Phase I Part 1 section: the pose numbers before/after, the crown travel table, the audit, the round trip,
   the diff proof, what you saw on the sheets, what remains unverified. **Stop and report.** Part 2 waits for Fable's go
   (the headless test lanes must not overlap the reimport).

## Part 2 - Unreal reimport + PIE (only after the go)

1. Importer `clips` stage (replace_existing; the SKEL reused; `import_morph_targets=True`) and `readback`: assert the
   four SRC clips' frame counts and, for `SRC_Tug`, the crown track's last-frame translation against `crown_travel.json`
   (bone-space; convert as `readback_b4` does). All other clips unchanged (readback identical to Phase C3's
   `unreal_readback_final.json`). Preflight as Phase C2 (PIE off, no foreign dirty package, Mars.log tail: no pending
   "Full Reload is required"; if one is pending, stop and report - Fable restarts the editor).
2. PIE `run-04-pull` on the review map (`Tools/LevelDesign/screaming_turnip_r01_review/`), driver rules as Phase F/H:
   - Bed 1: the full pull held 1.8 s (`harvest_steps`). Sample per tick (the `gloves` rows): the glove `grip_r / grip_l`
     bones, the two grip nodes (`ScreamingTurnipBed.HarvestGrip_R / _L`, world), and the planted component's
     `HarvestGrip_R / _L` socket world positions. Prove: node-to-socket <= 0.5 cm (one frame of lag allowed), glove
     bone-to-node <= 0.5 cm once reached, the sockets rise >= 7 cm across the Tug, the clip rows show `SRC_Grip` for about
     0.4 s then `SRC_Tug` for about 1.0 s (position advancing at half rate), then the release. Captures at Grip end, Tug
     mid, Tug end, and after the release (first person, the HUD prompt visible).
   - Bed 2: a press let go at about 0.9 s (Grip done, Tug about half): `SRC_Cancel` starts at alpha about 0.5 (the clips
     row's `t` at its first sample), the gloves ride back down with the sockets, the crown socket never jumps more than
     1.5 cm between consecutive samples, and the follow ends with the clip back on `SRC_Idle`. Captures at the cancel
     press and 0.2 s after.
   - A `capture_pie_movement_clip` of bed 1's pull from a side camera (PIE docked, not minimized), so the lift is judged in
     motion. Say what you see, honestly.
   - 0 ensures in the window (Mars.log line range quoted); the Sandbox restored, 0 dirty packages outside the owned
     candidate folder.
3. `PROGRESS.md` Phase I Part 2 section and `VERIFICATION.md` (the pull rows: evidence files, PASS/PARTIAL), every claim
   confirmed/inferred.

## Hard rules

Part 1 writes only under `Tools/Blender/mars_ingredients/screaming_turnip_r01/`. Part 2 writes only under
`/Game/ArtCandidates/ScreamingTurnip/R01/` (saved per owned asset, never Save All), `Tools/LevelDesign/screaming_turnip_r01_review/`
(driver tweaks and captures) and the two record files. No git. No `Script/` edits: if a Script-side fault blocks you,
measure it and report. No level load through `run_console_command`, never `unload_packages`, no deleting or reloading
loaded Blueprints. Every Blender script prints `TURNIP_OK` / `TURNIP_FAIL`. Final message per part: files, rerun commands,
the numbers, which sheets/captures to look at, what remains unverified, confirmed vs inferred.
