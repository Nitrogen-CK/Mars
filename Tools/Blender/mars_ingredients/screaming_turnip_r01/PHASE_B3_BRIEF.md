# Phase B3 brief - clips on the B2b mouth (bones + shape keys), export, round trip, manifest

You are the Opus executor for Phase B3 of the Screaming Turnip R01 campaign. Read first: `PROGRESS.md` (Phase B
clip table and chain rules, Phase B2b section: the two shape keys `Inhale` / `Scream`, the shape-key round-trip proof
and its export-recipe consequence `use_triangles=False`, the widened hull, MouthCue 4.136; the audits), `PHASE_B_BRIEF.md`
Part 2 and Part 3 (the clip table, chain/seam rules, export and manifest contract), `PHASE_B2b_BRIEF.md`, then the
scripts: `animate_screaming_turnip.py` (Phase B; keys bones only - extend it), `export_screaming_turnip.py`,
`validate_roundtrip.py` (`check_anims` + `--shapekey-test`), `render_anims_screaming_turnip.py`,
`shapekey_test_screaming_turnip.py`. The B2b `.blend` has no clip actions (the builder reset wipes them): animate rebuilds them.

## Deliverables

1. **Clips, 16**: the 15 of the Phase B table (same frames/loops/chain rules) plus `ROOT_AnticipateTired` (0.3 s,
   0..9, no loop): identical to `ROOT_Anticipate` except it STARTS from `ROOT_RecoveryIdle` frame 0 (drooped crown,
   tired breath) so the RecoveryIdle -> Anticipate cut has no 42-degree leaf snap (B-2); its last frame == `ROOT_Inhale`
   frame 0 exactly. Report both hard cuts after the change: RecoveryIdle f0 -> AnticipateTired f0 (must be <= 0.1 cm /
   1 deg) and QuietIdle -> Anticipate f0 (as before).
   Shape keys: `key_pose` keys the `Inhale` and `Scream` channels per frame from the pose vectors (`k_inhale`,
   `k_scream`): Inhale ramps 0 -> 1 over ROOT_Inhale (eased, holding 1 for the last 0.2 s); Scream snaps to 1 within 3
   frames of ROOT_Scream and holds; Recover eases Scream 1 -> 0 over its first 0.25 s and Inhale stays 0; every other
   clip keys both at 0 explicitly (so a hard cut never inherits a stale value). The SRC clips key both at 0.
   Per-frame audit as Phase B (intersections 0 everywhere except documented lip/chin folds <= 3 pairs; the B2b
   zero at the scream corners must hold through the whole ROOT_Scream and ROOT_Recover), bounds per frame, global
   envelope. `review/phaseB3/anim_report.json`, contact sheets per clip + `cycle_sheet.png` + a `shapekey_sheet.png`
   showing Inhale at 0/0.5/1 and Scream at 0/0.5/1 with bones at rest.
2. **Export** with the recipe change recorded as DEV-13: `use_triangles=False` for the skeletal mesh and every clip
   (the mesh is all triangles already - assert it before export; statics keep the Phase B recipe); `export_settings.json`
   updated with the reason and the proof reference. Files: bind SK, the three statics (the widened hull), cube, 16
   clip FBX. One action per clip on the armature; the Key's action is allowed and expected (the validator accepts
   the two).
3. **Round trip** (`validate_roundtrip.py`): everything Phase B checked, plus per clip the shape-key values at the
   authored peak frames (Inhale 1.0 at ROOT_Inhale's last frame, Scream 1.0 at ROOT_Scream f3..f18, both 0 at every
   frame of QuietIdle/SRC_*), evaluated mesh at those frames within 0.01 cm of the authored, and the SK's three keys
   present by name. `export/anims/roundtrip_report.json`, `expected_anims.json`.
4. **Manifest** `export/ScreamingTurnip_R01_Manifest.json` refreshed: tris 3188, bones, sockets (MouthCue 4.136),
   collision extents (widened), 16 clips with the shape-key contract (`morph_targets: [Inhale, Scream]`, per clip the
   curve peaks), `clip_contract` noting curves, `unreal_paths` for the new clip, and a `phase_c_readback` block naming
   what the importer must assert: morph target names on the SK, `get_sequence_info` curve names `Inhale` / `Scream`
   with the peak values, `import_morph_targets=True`, `FBXNIM_IMPORT_NORMALS` with morphs (note the unproven morph
   normals), reimport with `replace_existing`.
5. `PROGRESS.md` Phase B3 section: rerun commands, clip table with chain/seam/cut deltas, shape-key peaks, envelope,
   round-trip numbers, DEV-13, deviations, not verified.

## Hard rules

Write only under `Tools/Blender/mars_ingredients/screaming_turnip_r01/` (`scripts/`, `source/`, `export/`,
`export/anims/`, `review/phaseB3/`, `PROGRESS.md`). No git. **No Unreal** (the reimport + morph readback is Phase C2,
run after the Script-side Phase G finishes: the editor is busy with PIE). Keep the Phase A contract (17 bones, root
identity, D-A1, slot order). Every script prints `TURNIP_OK` / `TURNIP_FAIL`. Look at the sheets you produce; never
claim from a script existing. Final message: files, rerun commands, the clip table with deltas and shape-key peaks,
envelope, round trip, which sheets to look at, not verified; confirmed vs inferred.
