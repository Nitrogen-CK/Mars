# Pantry Rat R01 - PROGRESS

Production record for `docs/art/pantry-rat-dens-production-r01/` (Mars). Every claim is marked **confirmed** (evidence
named) or **inferred**. Owned root: this folder only. Nothing committed; no git writes; Unreal / Monolith untouched.

## Phase 1 - coherent rat / den / cheese blockout, 26-bone rig, pose and clearance proofs (2026-11-06, DONE - awaiting planner audit)

Brief: `PHASE_1_BRIEF.md`. Branch dev, HEAD 2154da267d9abf5516a63c9428fbb43e5c2fbfed (not re-queried by this executor;
no git command was run). Blender 5.2.2 LTS, fresh background processes only.

### Rerun (from this folder; each prints PANTRY_RAT_OK / PANTRY_RAT_FAIL and exits non-zero on failure)
```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup --python scripts/build_pantry_rat.py -- --tag r08   # [--no-save] [--no-renders] [--views-only]
"$B" -b --factory-startup --python scripts/reopen_check.py
```
Last runs: build exit 0, `PANTRY_RAT_OK`, 17.7 s build + 59 renders (`review/phase1/build_log.txt`); reopen exit 0,
`PANTRY_RAT_OK` (26 bones, slots in order, 2086 tris, 1130 verts, max 3 influences, 15 pose actions), run AFTER the
final build. **confirmed** (printed markers / exit codes).

### Files
- `scripts/build_pantry_rat.py` builder; `scripts/rat_common.py` mesh builder (MB, cellar-bat pattern), posing (FK,
  aim, 2-bone IK), BVH audits; `scripts/rat_render.py` renders; `scripts/reopen_check.py`.
- `RIG.json` (26 bones + parents, Carry frames), `source/PantryRat_R01.blend`, `review/phase1/measurements.json`,
  `review/phase1/build_log.txt`, renders under `review/phase1/` (views, poses, den, court, iterations).

### Scene **confirmed** (reopen_check)
Collections Authoring (AUTH_* per-part solids, hidden), Rig (empty: poses rotate export bones directly), Export
(`PantryRat_R01_Body` skinned to `PantryRat_R01_Armature`), Props (den, cheese, proxies, pack + pockets, crates, chef,
floor, `Carry_Mouth`/`Carry_Drag` Empties on `jaw`), Review (camera, lights, 10 cm rulers, label, route ribbons).
Root at origin, rest identity, never posed. Pose actions `PantryRat_R01_Pose_<name>` x15 (11 brief poses + rummage,
rummage_p3, rear_rummage, drag_carry), fake user; resolved pose defs also in text block `PantryRat_R01_PoseDefs.json`.

### Measured neutral vs target (measurements.json `neutral`) **confirmed**
| quantity | target | measured |
|---|---:|---:|
| withers top (torso max z, x 1.4..5.4 over the shoulder joint) | 35 | 35.26 |
| nose tip to tail tip (whole mesh X extent) | 65 | 64.995 |
| body length tail excluded | ~40 | 40.70 |
| body width (torso Y) | ~30 | 29.71 (32.60 incl. ears) |
| height incl. spoon | <= 65 | 46.84 (44.60 without spoon = ear tips) |
| belly min z | - | 3.86 |
No deviation > 1 cm. Tris 2086 (budget 2500), verts 1130. Per tag: torso 324, head 196, nose 32, ears 120, eye patches
18, upper limbs 152, lower limbs 192, paws+toes 216, tail 180, spoon 114, cuffs (spoon strap) 80, chest band 384.
Per slot: Body 748, Pink 548, Belly 116, Wood 114, Harness 464, EyePatch 18. Slot order Body, Pink, Belly, Wood,
Harness, EyePatch. Anatomy islands: ears 2, eye patches 2, upper limbs 4, lower limbs 4, tail 1 (4 bone segments,
constricted at the joints), nose 1, band 1, spoon+2 cuffs.
Skin: max 3 influences, 0 unnormalised, 0 unweighted, no stray groups; spoon + cuffs 100% `spoon_prop` (144 verts),
patches 100% `head` (20), ears 100% `ear_l`/`ear_r` (64); band follows torso weights, blending to `spoon_prop` where it
rides over the handle. Rig vs RIG.json: 26/26 names and parents match, root identity.

### Eye patch UVs **confirmed** (numbers), orientation vs Unreal **inferred**
LEFT patch (+Y) U 0.000..0.477, RIGHT patch U 0.523..1.000, both V 0..1. Convention: U decreases toward rat-left;
left patch back edge U=0, front edge 0.5; right patch front 0.5, back 1 -> EyePlate.ush `frac(2U)` (mirrored on the
left) runs front->back on both eyes. Den plate: one paired quad, U=0 at the den's +Y (resident's left), U=1 at -Y.
EEVEE preview node tree (review-only approximation of the shader's half split) draws exactly two eyes:
`views/eyes_closeup_eevee.png`, `den/portal_front_empty.png`. Not proven: LookX sign and asymmetric-cell facing in the
real MarsEyePlate material (Phase 2).

### Per-pose audit (measurements.json `pose_audit`) **confirmed**
tris = BVH triangle-pair overlaps; clear = min signed distance (spoon to torso+haunch), dist = unsigned min distance.
| pose | spoon-torso tris / clear | spoon min z | harness-torso tris | head-spoon tris / dist | proxy-chest tris / dist | proxy-spoon tris / dist | legs(lower+paw)-torso tris | paws-torso | below floor | body lift by spoon | patch detach |
|---|---|---|---|---|---|---|---|---|---|---|---|
| neutral | 0 / 0.28 | 33.88 | 0 | 0 / 1.12 | - | - | 47 | 0 | 0 | 0 | 0.25 |
| crouch | 0 / 0.93 | 32.31 | 0 | 0 / 1.72 | - | - | 66 | 0 | 0 | 0.01 | 0.25 |
| stretch | 0 / 0.26 | 31.98 | 0 | 0 / 2.14 | - | - | 46 | 0 | 0 | 0.15 | 0.25 |
| bound_apex | 0 / 0.28 | 41.35 | 0 | 0 / 0.97 | - | - | 0 | 0 | 0 | 0.09 | 0.25 |
| rear_up | 0 / 0.28 | 21.12 | 0 | 0 / 7.44 | - | - | 0 | 0 | 0 | 0 | 0.25 |
| jaw_carry | 0 / 0.22 | 33.47 | 0 | 0 / 1.11 | 0 / 7.64 | 0 / 22.64 | 45 | 0 | 0 | 0 | 0.25 |
| look_back | 0 / 0.28 | 33.88 | 0 | 0 / 0.64 | 0 / 5.85 | 0 / 23.94 | 45 | 0 | 0 | 0 | 0.25 |
| topple_left | 0 / 0.20 | 9.68 | 0 | 0 / 0.65 | - | - | 0 | 0 | 0 | 0 | 0.25 |
| topple_right | 0 / 0.28 | 9.05 | 0 | 0 / 3.73 | - | - | 0 | 0 | 0 | 0 | 0.25 |
| dead_back | 0 / 0.28 | 0.14 | 0 | 0 / 1.07 | - | - | 13 | 0 | 0 | 0 | 0.25 |
| den_crouch | 0 / 1.05 | 32.36 | 0 | 0 / 2.41 | - | - | 64 | 0 | 0 | 0.17 | 0.25 |
| rummage (P2/P3) | 0 / 0.28 | 27.71 | 0 | 0 / 4.21 | - | - | 31 | 0 | 0 | 0 | 0.25 |
| rear_rummage | 0 / 0.28 | 14.51 | 0 | 0 / 3.39 | - | - | 0 | 0 | 0 | 0 | 0.25 |
| drag_carry | 0 / 0.22 | 32.47 | 0 | 0 / 1.09 | 0 / 10.55 | 0 / 22.39 | 52 | 0 | 0 | 0 | 0.25 |
Eye-patch detachment 0.25 cm in every pose = the authored offset (patch verts 0.25 cm proud of the head, all 100%
`head`, as is the head skin under them). `legs-torso` > 0 is the lower legs/knees embedded in the low belly (47 in
neutral; the paws never enter the torso, 0 everywhere). Treated as anatomy embedding, not a clip - **inferred**
acceptable for a blockout; it is a number the planner may rule on.
Ratios: crouch height 0.856 of neutral (no spoon; 0.927 incl. spoon), stretch length 1.202, bound apex body +8 cm
skeletal lift (root at origin, rat min z 10.48 = airborne), rear_up nose 42.13 cm, look-back yaw 45 deg total (neck
20.25 + head 24.75) toward rat-left = largest yaw <= 70 with the carried proxy >= 2 cm off spoon and chest
(`look_back_yaw_search`). dead_back: roll 210 deg (30 deg off belly-up toward one flank), no spoon slide; body rests
on the floor (lift 0), spoon 0.14 cm above the floor.

### Clips closed in the source (before -> after) **confirmed** (`pose_fixes`)
Automatic smallest-correction search on the `spoon_prop` bone (lift along its up axis / slide round the chest axis /
pitch), applied in the stored pose action:
- stretch: spoon-torso 25 tris, clear -1.13 -> 0 tris, +0.26 (lift 1.0 cm, pitch -3 deg).
- jaw_carry: head(ear)-spoon 10 tris -> 0 (slide -3 deg).
- topple_left: head(ear)-spoon 59 tris -> 0 (lift 0.3, slide -10, pitch +3).
- drag_carry: head(ear)-spoon 14 tris -> 0 (slide -3). This pose first bypassed the audit/fix path; caught on review
  of the final table and routed through it; the fail gate now covers every pose and paws-in-torso.
- rear_up: tucked fore paws 32 tris inside the chest -> 0 (tuck targets moved 3.5 cm forward of the chest).
Earlier iterations (logged in build_log history, sheets in `iterations/`): crouch/den_crouch below floor after the
belly was lowered -> body drop reduced (crouch -2.9, den_crouch -3.1 cm); tail below floor in stretch/bound/rear ->
tail posed by aims + a floor guard.

### Den **confirmed** (measurements.json `den`)
Stone Arch: 7 voussoirs + 4 jamb blocks, opening 60 x 60 (30 cm jambs + 30 cm radius head), recess tunnel to a black
back plane 45 cm behind the front plane, eye plate 20 x 8 at z 22 two cm proud of the back plane, court wall around.
Markers (den local, floor, outside the recess): EntryPortal (24,-14), ExitPortal (24,14), ReturnAdmission (48,0),
OutsideStand (75,0). Den world (392,0), facing -X.
Portal (den_crouch WITH spoon): posed Y extent 32.47, Z max 43.14 -> box clearance 27.53 width total / 16.87 height;
arch-profile min clearance 12.88 cm (tightest point y -10.98, z 43.13 = spoon bowl). Fits; opening not widened.
Grazing 75 deg off the portal axis at z 25, both sides: no plate or recess rectangle edge visible
(`den/grazing_left.png`, `den/grazing_right.png`) - judged by eye at 1000 px, **confirmed visually**, not measured.

### Cheese, proxies, court **confirmed**
Cheese_MonksRind 15.0 x 10.0 x 8.0, 56 tris, pivot base centre, orange rind back + rims over ivory flesh.
Mushroom proxy 12 x 12 x 8 (100 tris), one at Pocket2, one on Carry_Mouth. Backpack envelope box 86 x 116 x 121, pivot
floor centre, world (-300,0) yawed 180 so the pocket face looks into the court; measured X 86.8 because of 0.4 cm
pocket-mouth marker tabs on that face (readability only). Pockets pack-local (-31,1.25,75), (-31,22.5,37.5),
(-31,-17.5,37.5). Chef capsule r39 hh75, axis 120 cm from the pack pivot (my reading of "120 cm from the pack").
Crates 60 cm at (-60,0) and (90,0). Floor 800 x 600.

Pocket reach (rear feet planted on their rest targets, min z 0.0; fore paws on the pack face):
- Pocket2 / Pocket3 (37.5): reached, nose z 37.5 at 39.3 deg rear pitch; nose is 0.5 cm off the envelope face,
  12.5 cm from the socket point (the socket lies 12 cm behind the envelope face).
- Pocket1 (75): NOT reached. Max rear (82 deg, neck/head up) nose z 48.33 -> shortfall 26.67 cm (planner decision).
- Finding: against the 86 cm envelope the nose cannot get within 12 cm of any socket; whether the real
  SM_PlayerBackpack surface lets the snout reach the item needs the real mesh (**inferred** risk).
Carry offsets (Blender jaw-bone space, head-relative): Carry_Mouth t (0, 6.02, 0.60) cm, euler (0, 114.76, 90) deg;
the item pivot (base centre) sits there, cap forward-down. Carry_Drag t (0, 16.71, -24.12) cm, quat wxyz
(0.706, -0.042, 0.042, 0.706): bulky 30 x 30 x 25 proxy pivot (base centre) on the floor ahead, jaw tip 2.19 cm below
its near top edge, 2.5 cm bite; proxy vs chest/legs/spoon 0 tris, proxy min z 0.0.
Death drop (dead_back corpse): vertical drop from the carry point lands under the corpse (gap 0.0); released 12 cm
forward it lies outside the corpse silhouette, horizontal gap 5.37 cm (shown in `court/death_drop*.png`).
Flee routes (top-down): Loop_A min 188.5 cm to the portal markers, 42.9 cm to crate faces, 107 to the pack, 141.8 to
the chef capsule; FigureEight_B 175.4 / 18.3 / 94 / 115.2. Both >= 150 from the portals and > 15 cm (rat half
width) off the crates. Plausibility only; no navmesh.

### Rulings applied
1. Spoon (sheet 02 projections disagree): bowl behind the head over the right shoulder, handle down-back to the
   left hip, strapped. Measured: a rigid 31 cm spoon cannot touch both the hip and the 36 cm crest, so it rests
   tangent on the hip-to-crest slope (0.45 cm stand-off); the handle end floats 4.5 cm above the hip-surface axis
   point and the bowl axis sits 8.5 cm above the shoulder surface. Joint search minimises bowl lift + 1.5 x
   handle-end lift.
2. Chest band at x -7 (behind the forelegs, mid-back as on sheet 02 top/rear views); it climbs 3.25 cm over the
   cuffed handle so it actually straps the spoon.
3. Written scale over drawings: 35 cm withers on a 40.7 cm body makes the body taller for its length than the
   sheet 02 side drawing; kept the numbers.
4. Look-back direction rat-left (away from the bowl). dead_back tilted 30 deg off belly-up so the body, not the
   spoon, bears on the floor.
5. Eye UV convention and den plate convention as above.

### Look-and-fix rounds (sheets in `review/phase1/iterations/`, compare against sheet 02 in `compare_02_rNN.png`)
r01 cream belly on the back (colour test used pre-orientation normals), thin stick spoon, legs long, head/ears
small -> r02 belly fixed, head x1.15, ears bigger, spoon x1.5; eyes blown white -> r03 handle cross-section was
squashed on the wrong axis (edge-up) and the bowl rode 13 cm high -> joint spoon solve, band moved under the handle
-> r04 ears turned outward (read from front and side), emission tamed -> r05 belly lowered 2 cm -> r06 forelegs 3 cm
back under the chest mass, front chest deepened -> r07/r08 final (withers trim, drag/rear_up clip fixes).

### Look first
`review/phase1/compare_02.png`, `views/hero_eevee.png`, `views/eyes_closeup_eevee.png`, `poses/sheet_locomotion.png`,
`poses/sheet_death.png`, `den/sheet_den.png`, `court/sheet_court.png`.

### Not verified / open
- No FBX export or Blender round trip (optional item skipped). No Unreal import; bone-axis conversion of the Carry
  frames to UE sockets not done.
- Eye UV halves proven only against a Blender approximation of EyePlate.ush; LookX sign / asymmetric cells untested.
- Grazing-angle occlusion judged visually, not measured; cutaway framing is functional, not presentation-grade.
- Signed clearance uses a nearest-face normal test (reliable on the blobby torso, misreads thin ears - head numbers
  are unsigned distance + overlap count for that reason).
- Lower-leg embedding in the belly (legs-torso counts) and the floating handle end are accepted blockout
  compromises pending the planner's audit.
- Pose shapes are blockout keys, not animation; IK knee directions are plausible, not reviewed per frame.

Claim most likely wrong: the eye-patch U direction (rat-left = low U) matching what MarsEyePlate expects in Unreal;
it follows the brief's literal wording and the shader's mirror rule, but no in-engine render confirmed it.

## Phase 2 - 34 clips, export round trip, rat-local Masked looks, saved + reloaded Unreal candidate (2026-11-06/07, DONE except the items under "Open")

Brief: `PHASE_2_BRIEF.md`. Branch dev (HEAD not re-queried; no git write command was run). Blender 5.2.2, fresh background
processes. Unreal: the live MarsEditor through Monolith only (5.7.4, project D:/Repositories/CkRepos/Orion/Mars.uproject, PIE off
before every write). Every script prints PANTRY_RAT_OK / PANTRY_RAT_FAIL and exits non-zero on failure.

### Rerun (from this folder; order matters - each step reads the previous one's output)
```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup --python scripts/build_pantry_rat.py -- --tag p2r01 --views-only --review-dir review/phase2/build  # band fix; saves source
"$B" -b --factory-startup source/PantryRat_R01.blend --python scripts/animate_pantry_rat.py          # 34 clips + audits; saves source
"$B" -b --factory-startup source/PantryRat_R01.blend --python scripts/animate_pantry_rat.py -- --render-only --sheet-tag final
"$B" -b --factory-startup source/PantryRat_R01.blend --python scripts/dither_uv_pantry_rat.py        # dense UV0 for the dither; saves source
"$B" -b --factory-startup source/PantryRat_R01.blend --python scripts/export_pantry_rat.py
"$B" -b --factory-startup --python scripts/validate_roundtrip.py
# Unreal (Monolith editor_query run_python, mode execute_file, unattended true), command = "<abs path to script> <stage>":
#   editor_query run_console_command: Ck_Usf_GenerateLooks MarsPantryRatSurface ; Ck_Usf_GenerateLooks MarsPantryRatEyePlate
#   scripts/pantry_rat_import_ue.py part_a | socket_plan | part_b | save | readback
#   sockets: animation_query add_socket on .../Meshes/PantryRat_R01_Mars_SKEL with the socket_plan values (never raw add_socket)
#   scripts/pantry_rat_review_ue.py build | capture all | pockets | readback | restore <previous map>
# Toolbox: the detached wrapper of VALIDATION.md, one new run dir per run, --test --no-live --discover-fresh --test-pattern=<X>
```
`build_pantry_rat.py` rebuilds the .blend from nothing (it drops the clip actions and the dense UV0): re-run every later step after it.

### Files (new unless marked)
- `scripts/animate_pantry_rat.py` (author + bake + audit + contact sheets), `scripts/dither_uv_pantry_rat.py`,
  `scripts/export_pantry_rat.py`, `scripts/validate_roundtrip.py`, `scripts/pantry_rat_import_ue.py`, `scripts/pantry_rat_review_ue.py`;
  `scripts/build_pantry_rat.py` (modified: band fix, `--review-dir`, harness gate = clearance >= -0.2, `band_float_max_cm`).
- `review/phase2/anim_report.json`, `review/phase2/clip_table.md`, `review/phase2/clips/<Clip>_sheet.png` x34 (+ `_front` / `_tq`
  sheets; `clips/iterations/` r01 / r02 / r03 / final), `review/phase2/views/{front,rear}.png` (+ `*_phase1_before.png`),
  `review/phase2/dither_uv_report.json`, `review/phase2/unreal/*.png`, `review/phase2/unreal/pie1_playback/` (20 PIE frames),
  `unreal/pie1_playback_strips.png`, `unreal/pie1_playback_motion.json`, `unreal/review_map_readback.json`, `unreal/review_stages.json`.
- `export/PantryRat_R01_Mars_SK.fbx`, `export/anims/PantryRat_R01_<Clip>_Mars_ANIM.fbx` x34, `export/PantryRat_R01_Den_Mars_SM.fbx`,
  `export/PantryRat_R01_DenEyePlate_Mars_SM.fbx`, `export/PantryRat_R01_Cheese_Mars_SM.fbx`, `export/validation/{Cube10_Mars_SM.fbx,
  export_settings.json, expected.json}`, `export/anims/{clips.json, expected_anims.json, roundtrip_report.json}`,
  `export/PantryRat_R01_Manifest.json`, `export/unreal_readback.json`, `export/unreal_withers.json`.
- `Shaders/Looks/PantryRatSurface.ush`, `Shaders/Looks/PantryRatEyes.ush`, `Script/ECS/PantryRat/Mars_PantryRat_Look_Assets.as`,
  `Script/Tests/PantryRat/Mars_AutoTest_PantryRat_LookMastersResolve.as`, `Script/Tests/PantryRat/Mars_AutoTest_PantryRat_CandidateAssetsReload.as`.
- `docs/art/pantry-rat-dens-production-r01/ANIMATION_MANIFEST.csv` (modified): `durationSeconds` = quantised seconds; new columns
  `frames`, `samples`, `proposedSeconds` (the authored value, which animate_pantry_rat.py reads); 34 rows; `verify_package.py` still passes.
- Unreal (saved): `/Game/ArtCandidates/PantryRat/R01/{Meshes/PantryRat_R01_Mars_SK, Meshes/PantryRat_R01_Mars_SKEL,
  Materials/PantryRat_R01_{Body,Pink,Belly,Wood,Harness,Stone,Void,Rind,Flesh}_Mars_MI, Materials/PantryRat_R01_Prop_Mars_M,
  Animation/PantryRat_R01_<Clip>_Mars_ANIM x34, Props/PantryRat_R01_{Den,DenEyePlate,Cheese}_Mars_SM, Review/PantryRat_R01_Review_MAP}`;
  generated masters `/Game/Mars/Materials/GeneratedLooks/M_CkUsf_Look_MarsPantryRat{Surface,EyePlate}` (the look root the brief set).
- Written by the editor, not by my scripts (do not stage blindly): the map save's CkJolt hook ->
  `/Game/CkJoltData/ArtCandidates/PantryRat/R01/Review/PantryRat_R01_Review_MAP/{JoltCell_-1_0, JoltCell_0_-1, JoltCell_0_0, JoltIndex}`;
  the AS recompile regenerated `Script/Generated/Mars_AutoTestActors.as` / `Mars_EntitySpawnParams.as` (already dirty from another
  session); the CkAutoTest populator auto-saved `Content/Mars/Maps/AutoTests_Mars_MAP.umap` with the two new test actors (log 01:12:18
  and 01:33:25 UTC). `M_CkUsf_Look_MarsEyePlate` (SHARED) and the two rat masters are DIRTY IN MEMORY only, from my
  `material_query recompile_material` calls; nothing saved them. Do not Save All. **confirmed** (get_dirty_content_packages, log).

### A. Clips **confirmed** (anim_report.json; the 34-row table is `review/phase2/clip_table.md`)
- 34/34 authored on the export bones (no control rig): key poses in the Phase 1 pose language (Phase 1 resolved poses from the
  `PantryRat_R01_PoseDefs.json` text block + new keys), cubic Hermite per bone channel (Catmull-Rom inside, periodic loops, zero
  slope at one-shot ends), the four paws re-solved each frame by 2-bone IK onto splined ankle/toe/sole targets (zero slope at
  grounded keys, never below the rest contact height); topples and DeadHold FK. Root never keyed, no scale keys (the export checks both).
- Durations N = round_half_up(s x 30), N+1 samples: 0.25 -> 8 (0.2667 s), 0.18 -> 5 (0.1667), 0.12 -> 4 (0.1333), 0.35 -> 11 (0.3667),
  0.45 -> 14 (0.4667); all other proposed values are exact 30 Hz spans. Shortest clip HitReact 5 samples; DeadHold 31 identical samples.
- Audit of every baked frame of every clip: 0 bad frames (spoon-torso, harness-torso (clearance >= -0.2), head-spoon, below floor
  > 0.2 cm, patch detach > 0.6, spoon lifting the body, carry proxy vs chest / spoon / legs on carry frames). Worst harness clearance
  -0.198 (LoadedBound); min spoon clearance 0.035 (LoadedIdle); carry proxy chest clearance >= 5.37 (LoadedLookBack), spoon >= 22.0, legs 0 tris.
- Loop seams (11 loops): frame N == frame 0 exactly; the second difference across the seam <= the largest one inside the clip on every
  loop (BoundCycle 0.99 vs 5.23, IdleBreath 0.0028 vs 0.0037, ...). Round-trip seam 0.0 cm on every loop.
- Planted-foot drift on the non-locomotion IK clips (grounded = ankle <= rest + 0.15 cm, toe <= 1.2 cm): 0.000 cm on all.
  Locomotion clips report the stance slide the mover cancels: BoundCycle fore 36-43 / hind 46-59 cm/s, LoadedBound fore 31-33 /
  hind 42-48 cm/s (fore != hind: see Open).
- Strapped-spoon fit: one slide/lift/pitch per clip (no key-to-key jitter), Phase 1 search order, tested at every frame of clips
  <= 30 frames and at keys + midpoints of longer ones; 16 clips needed one (BoundCycle / LoadedBound lift 1.0 cm; DeathToppleLeft
  lift 1.5 / slide -10 / pitch 6 for the fall, its last key keeps the Phase 1 topple_left fix). DeadHold == dead_back; the topples end
  exactly on topple_left / topple_right.
- Content: den clips through the 60 x 60 arch with the spoon: tightest arch clearance 12.65 cm (DenEmerge f30, bowl at y -10.98
  z 43.43), 10.00 (DenEnter f0, standing outside). Jaw on Carry_Mouth: 0.0 deg jaw rotation on every carry frame of LoadedIdle / Bound /
  TurnLeft / TurnRight / LookBack / Cornered; Snatch 1.77 deg max after the clamp (spline overshoot); MouthRelease 16.3 deg by its last
  carry frame (f2). No rear/groom/eat in Loaded*; Rear* empty-mouthed; turns key no root yaw (start and end facing +X); EarFlick /
  TailSettle start and end on IdleBreath frame 0 (landmark delta 0.0).
- Fixes, one axis per round (before -> after):
  1. Chest band (Phase 1 finding): inner face radial at the widest strap-width hit minus 0.15 cm, 0.5 thick (was 0.55 off the facet
     normal, 0.6 thick: a ring 1.15 cm proud). Neutral harness clearance -0.15 (<= 0.2 embed). `views/front.png` / `rear.png` vs
     `*_phase1_before.png`: the floating ring at the lower flanks is gone; from the rear the band still reads at the silhouette (wider
     than the tapering rump) and tents 4 cm over the handle (unchanged). **confirmed visually**.
  2. Paws dipping under the floor between stance keys (BoundCycle f2 / f11 -0.39 / -0.27) -> floor clamp on splined paw targets -> 0.
  3. Touch-down slides (StretchAttend 1.21, BoundStart 3.0, BoundStop 3.27, Snatch 0.55 cm) -> zero slope at grounded keys, paws step
     instead of sliding, BoundStop classed as braking stance -> 0.000 on every stationary clip.
  4. Harness embed down to -0.41 in turns (chest/pelvis counter-twist) -> the yaw lead moved to `body` -> -0.15.
  5. Startle band under the floor -0.46 (body drop 3.8) -> drop 2.8 -> 0; Backstep / LoadedLookBack head-spoon -> smaller head lift, no nod.
  6. Topple: legs through the floor in the fall + the upper ear into the bowl on the rebound -> airborne hop with tucked legs, gentler
     rebound, ears forward on impact -> 0 bad frames.
  7. Bound fore paws never grounded (IK overreach at land) -> land target +4.2 (was +6), body +1.0 at land -> fore grounded f8-f12.
- Looked at against sheets 04 / 05 / 06: BoundCycle r01 -> r02 (spine squash/stretch: chest/pelvis slide, streaming tail) -> r03
  (land fix); Rummage r01 -> r02 (tug -5/-3 cm, body rocks back); Snatch r01 -> r02 (head jerks back on the clamp, clear rear-down step
  onto four feet); LoadedBound r02 / r03 (item held clear of the legs); DeathToppleLeft r01 -> r02 (hop, roll, belly up, legs up).
  All 34 sheets rendered; ~25 not individually reviewed.

### B. Export + round trip **confirmed** (export/validation/export_settings.json, export/anims/roundtrip_report.json)
- Recipe: cellar bat COMMON / BIND / CLIP / STATIC verbatim (`Armature` rename, selection, `bake_anim_use_all_actions=False`,
  `use_armature_deform_only=True`, `armature_nodetype='NULL'`, axis_forward -Z / up Y, apply_unit_scale, FBX_SCALE_NONE).
  FBX binary 7400, Creator "Blender (stable FBX IO) - 5.2.2 LTS - 5.15.0".
- Statics: den = shell (Stone) + recess tunnel + back plane (Void), den-local frame (+X out of the opening), 330 tris; eye plate = one
  quad, normal +X, UV 0..1, U = 0 at the resident's LEFT (UE -Y); cheese = Rind 20 faces / Flesh 14 faces by authored colour, 56 tris.
- Round trip (fresh scene per file): bind 26 bones, names / parents exact, heads 5e-05 cm, 2086 tris, slots in order, bounds 0.0005 cm,
  armature scale 1, max 2 influences, 0 bad weights; Carry_Mouth / Carry_Drag rebuilt on the imported jaw 3e-05 / 7e-05 cm from the
  export; 34 clips with 1 action each, keyed 0..N with N+1 samples, root identity on every sample, landmarks at first / middle / last
  frame within 0.00032 cm; den / plate / cheese tris + slots + bounds exact. 0 fails.

### Sockets (UE frame) **confirmed** (pantry_rat_import_ue.py socket_plan + readback)
Proved: UE jaw rest = S R_b S (S = diag(1,-1,1)), so bone-relative = S x Blender jaw-local; predicted vs computed in UE: location
0.0 / 0.0001 cm, axes 1e-06.
| socket | bone | relative location (UE cm) | relative rotation (pitch, yaw, roll) | component at rest (UE) | Blender world rest |
|---|---|---|---|---|---|
| Carry_Mouth | jaw | (0, -6.0237, 0.5955) | (-65.2406, 90, -180) | (19.8, 0, 20.6) | (19.8, 0, 20.6) |
| Carry_Drag | jaw | (0, -16.7145, -24.1189) | (-6.7595, -90, 0) | (24.546, 0, -5.906) | (24.546, 0, -5.906) |
Readback error 0.0 cm on both (target 0.5). Socket X = item forward, Z = item up (cap): Carry_Mouth Z = (0.788, 0, -0.616), cap forward-down.

### C. Looks **confirmed** (live editor log + Monolith)
- Generated by `run_console_command Ck_Usf_GenerateLooks MarsPantryRatSurface` / `MarsPantryRatEyePlate`: log `CkUsfEditor: Generated
  master for look [MarsPantryRatSurface]` (01:12:30 UTC), `[MarsPantryRatEyePlate]` (01:12:43). `material_query recompile_material`
  -> "recompiled" on both; `get_compilation_stats`: Surface is_compiled true, Masked, VS 296 / PS 286; EyePlate is_compiled true,
  Masked, VS 296 / PS 144. Live log: no "compile error" / "Failed to compile" line. Both render in the editor world (captures), not checkered.
- Shared Eyes untouched: EyePlate.ush, Script/ECS/Eyes, the atlas not edited. PantryRatEyes.ush includes EyePlate.ush and calls
  `Mars_Look_EyePlate` with its 21 arguments in order; the AS asset copies the MarsEyePlate block verbatim (19 params) then FadeAlpha CPD 14.
  Dither line verbatim in both .ush files.

### D. Unreal candidate **confirmed** (export/unreal_readback.json `readback` = final pass after the UV reimport)
16/16 checks: dedicated SKEL; bind bounds vs Blender 0.0005 cm; nose at max X 23.1 (= Blender); 26 bones, parents exact; root
identity; bone scales 1 (dev 1.3e-06); bone heads 5e-05 cm; ear_l at -Y; slots Body/Pink/Belly/Wood/Harness/EyePatch -> 5 MIs on
M_CkUsf_Look_MarsPantryRatSurface (Color = slot colour, FadeAlpha default 1.0) + the raw MarsPantryRatEyePlate master; both sockets;
den (complex-as-simple), plate (1 box, shared MarsEyePlate), cheese (1 box, opaque prop MIs); 34 clips: frames = manifest, length N/30,
loop flags, root motion off, 26 tracks, EarFlick / TailSettle AAT_LOCAL_SPACE_BASE vs IdleBreath f0, root translation 0, landmark bones
vs Blender <= 0.00014 cm at 3 frames each. Withers in UE 35.256 cm (Body-slot vertices in the Phase 1 x 1.4..5.4 band; target 35.3 +- 0.5).

### Pocket depths (real SM_PlayerBackpack x1.25, yaw 180) **confirmed** (unreal/review_stages.json `pockets`)
Rays from 60 cm in front of each socket (outward = the pack's -X face = world +X) toward it:
| pocket | socket world (UE) | simple-collision surface | render surface |
|---|---|---|---|
| Pocket1 | (-268.75, -1.25, 75) | 10.43 cm in front of the socket | first hit 1.97 cm behind the socket (socket 1.97 cm proud of the mesh) |
| Pocket2 | (-268.75, -22.5, 37.5) | 10.43 | 0.70 cm behind |
| Pocket3 | (-268.75, 17.5, 37.5) | 10.43 | 0.72 cm behind |
The editor line trace (Visibility, Monolith query_raycast's channel) hits the mesh's default simple collision; the render surface
(GeometryScript ray on the triangles) lies 0.7-2 cm behind the sockets. Phase 1's envelope assumed 12 cm. Numbers only.

### Review map + captures **confirmed** (each image named here was opened and looked at)
`/Game/ArtCandidates/PantryRat/R01/Review/PantryRat_R01_Review_MAP` (new_level + save from run_python; 31 tagged actors; CPD per rat in
`unreal/review_map_readback.json`). Static captures are SceneCapture2D renders of the editor world (capture_scene_preview renders an
asset preview scene and cannot show per-actor CPD).
- `unreal/close_Alpha05_with_mushroom.png`: FadeAlpha 0.5 = pixel-fine cut-out over every rat part incl. eyes and spoon; the real
  Mushroom_Prep_Mars_SM beside it renders solid. The pattern is NOT random speckle but pixel-scale line / moire bands per face (zoom
  `unreal/crop_alpha05_head_x3.png`; before the UV fix, `unreal/iterations/crop_alpha05_head_x3_r01.png` had coarser bands several
  pixels wide). Inferred cause: IGN is low-discrepancy for integer pixel steps; on a continuous UV*512 it is a folded linear ramp, i.e. stripes.
- `unreal/close_Rat_Alpha0.png`: nothing at alpha 0, no shadow. `unreal/close_Rat_Alpha1.png`, `unreal/row_neutral.png`: solid at 1.
- `unreal/close_Rat_Cpd14Unset.png`: a rat whose CPD stops at index 13 renders NOTHING: an unwritten slot 14 reads 0, not the 1.0
  material default. Seeding CPD 14 = 1 before the first visible frame is mandatory (spec section 12), now measured.
- `unreal/eyes_front_XEyes.png`: cells 20/20, exactly two readable X eyes. `unreal/eyes_front_Asym.png`: cell 2 (small) on the rat's
  LEFT, cell 19 (wide) on its RIGHT: U < 0.5 = LEFT holds in the real material (Phase 1 finding 3 and its claim-most-likely-wrong: correct).
- `unreal/den_neutral.png`: stone arch, black recess, one paired plate, two amber eyes (shared opaque MarsEyePlate, CPD 19/19, strength 6).
- `unreal/side_Rat_Alpha05.png`: mid-fade, far-side legs and leg segments embedded in the belly show through the cut-outs as darker
  shapes (observed; how much is far side vs embedded is inferred).
- Amber/teal static captures (`unreal/row_amberteal.png`, `den_amberteal.png`) are blown out (bat's 8000 cd key; the capture's exposure
  bias did not take): not usable. The amber/teal rig is visible in PIE: `unreal/pie1_playback/frame_005.png`.

### PIE playback **confirmed** (capture_pie_movement_clip PANTRYRAT_PIE1, 6 s, view target Cam_Playback; PIE stopped; level restored)
20 frames, 18 valid, ok true, 0 runtime errors, ~3 fps capture. Single-node actors: BoundCycle, Rummage, Snatch, LoadedBound (mushroom
on Carry_Mouth), DeathToppleLeft, DeadHold, DenEmerge. `unreal/pie1_playback_strips.png` (rows top -> bottom in that order, frames 2..19)
and the mean per-frame pixel change per rat tile (`unreal/pie1_playback_motion.json`): DeathToppleLeft 0.099, LoadedBound 0.042,
Snatch 0.031, BoundCycle 0.028, Rummage 0.021, DenEmerge 0.007, DeadHold 0.0026 (still, as authored). Looked at: the topple row cycles
upright -> side -> belly; rummage / snatch reared; the bound rows change body height. The ~0.33 s capture interval is coarser than the
0.4 s bound loop, so gait quality in Unreal is not judged from it.

### E. Toolbox (detached per VALIDATION.md; Exit.json + the real log read each time)
| run dir (Saved/Logs/PantryRatValidation/) | pattern | exit | result |
|---|---|---|---|
| phase2-run01-pantryrat | PantryRat | 1 | 2 of 5309 selected; CandidateAssetsReload PASS; LookMastersResolve FAIL (NEW): the headless -nullrhi editor logs "Look [MarsPantryRatSurface] / [MarsPantryRatEyePlate] master material has shader compile errors (or is still compiling)" from Get_LookMasterMaterial (CkUsf_Utils.cpp:44-52), the same line it logs for MarsImageDecal and MarsEyePlate at boot. Contaminated 0. |
| phase2-run02-pantryrat | PantryRat | **0** | 2/2 passed (CandidateAssetsReload; LookMastersResolve now loads the masters by the look's path), Failed 0, Contaminated 0, no NEW failures |
| phase2-run03-eyes | Eyes | **0** | 18 selected, 16 passed; Still red (listed) 2: `Mars_AutoTest_EyesDummy_ComposesAndWrites`, `Mars_AutoTest_Eyes_LookMasterResolves` (same MarsEyePlate shader-compile line as the list); no NEW, no Now passing; Contaminated 0 |
This phase edited no Eyes source; the two Eyes reds are unchanged. The CandidateAssetsReload green in a fresh headless process is the
cold-read proof of the saved candidate. AngelScript / .ush edits were frozen during each run (the one test edit fell between run01 and
run02). Focused patterns only, not the full gate.

### Deviations
- D2-1 No control rig: clips key the export bones directly (the Phase 1 Rig collection is empty); a per-frame IK re-solve replaces constraints.
- D2-2 The body slots' UV0 became a dense box projection (24 cm per UV, ~21 IGN cells per cm) so the verbatim dither is pixel-fine;
  EyePatch UVs untouched. UV0 is no longer lightmap-style non-overlapping (skeletal meshes take no lightmap).
- D2-3 "MIDs" are MaterialInstanceConstant assets; per-actor MIDs are runtime.
- D2-4 Den collision complex-as-simple (a simple box would seal the portal); plate and cheese one box each.
- D2-5 LookMastersResolve loads the masters by path and makes MIDs on a skeletal mesh component, not through
  utils_usf::Get_LookMasterMaterial / Create_MID_ForLook (headless runs cannot pass that renderer check). A hand-authored wrapper with
  Get_ExpectedLogErrors was tried first and broke the live editor's hot reload (a class of that name already existed in
  Script/Generated/Mars_AutoTestActors.as); reverted within a minute; the editor's next full reload (01:37:52 UTC) was clean.
- D2-6 Food and den stone use an opaque `PantryRat_R01_Prop_Mars_M` (Color param), so they can never read the rat fade.
- D2-7 Static rats in the review map are in the bind pose; the playback row animates.

### Open / not verified
- Dither look: verbatim BB dither gives fine LINE patterns, not random speckle. Planner fork: keep verbatim (BB parity) or feed IGN a
  pixel-integer input (floor(UV*512)) / a hash. Not done (the brief says verbatim).
- Amber/teal static captures overexposed; only PIE frames show that rig.
- Locomotion stance speeds differ fore vs hind (BoundCycle 36-59 cm/s): some foot slip at any single mover speed.
- ~25 of 34 contact sheets not individually reviewed; gait quality in Unreal not judged.
- Rear view of the band: ring at the silhouette and the tent over the handle remain - a ruling on whether that reads as floating.
- Gameplay rats (Eyes feature writing CPD 0..13, FadeAlpha ramps) are Phase 3; here CPD is set by hand.
- Rat masters and the shared MarsEyePlate dirty in memory from recompile_material (not saved).
Claim most likely wrong: that the stripe pattern is inherent to IGN on continuous UVs (inferred from the formula and two renders; a
floor(UV*512) variant was not rendered).

### Dither fix (coordinator ruling after the Phase 2 audit, 2026-11-07)
Both rat looks now threshold on `CkUsf_Hash21(floor(In.UV * 512.0)) < FadeAlpha` (white noise per UV cell; IGN needs pixel
coordinates a surface look cannot read). Contract unchanged: Masked, FadeAlpha CPD 14, no AS / UV / slot change, masters not regenerated.
Live editor: `recompile_material` alone kept the old shader (image identical, 0 px diff); `RecompileShaders Material
M_CkUsf_Look_MarsPantryRat{Surface,EyePlate}` (console) picked up the new .ush (68452 px changed); compile stats still is_compiled true,
Masked. Before -> after: `unreal/iterations/{close_Alpha05_with_mushroom,crop_alpha05_head_x3,side_Rat_Alpha05,close_Rat_Alpha05}_ign.png`
-> `unreal/{close_Alpha05_with_mushroom,crop_alpha05_head_x3,side_Rat_Alpha05,close_Rat_Alpha05}.png`, new `unreal/eyes_front_Alpha05.png`.
Looked at: the 3x crop is random per-pixel speckle with no visible bands on any face; the eyes speckle with the body at 0.5. **confirmed**
(renders). Nothing saved: the review map is dirty (capture actors) and left open; `Ck_Usf_ReloadShaders` (tried first, reloaded 0 changed
sources) left M_CkUsf_Look_{Glass,ProtoGrid,ProtoGridUV} (CkFoundation) dirty in memory beside the rat masters and MarsEyePlate.

## Phase 3 - PantryRaid / RatDen / PantryRat kernels, guarded original-item theft, routed tests (2026-11-07, DONE - awaiting planner audit)

Brief: `PHASE_3_BRIEF.md`. Branch dev, HEAD 2154da26 (git log, read-only). No git write command was run. The live MarsEditor was
used only through its AngelScript hot reload (every batch read back from `Saved/Logs/Mars.log`); no Monolith call, no PIE, no
asset save by me. Final sources hashed in `Saved/Logs/PantryRatValidation/phase3-final-sources.md5` (57 files; md5 of that list
07fff20bf739c43247024337da07d2a6), taken before the final batch run05; no source edit during or after it.

### Existing files edited (named in this section before each edit; additive only) **confirmed** (`git diff --stat`)
- `Config/DefaultGameplayTags.ini` +6: `AttachPoint.Mars.RatMouth`, `Inventory.Mars.RatPocket`, `Monster.Mars.PantryRat` (mine;
  `HitZone.Mars.Body` already existed, line 928) and `Mars.SmState.PantryRat.{Alive,Dead}` (appended by the live editor's state-tag
  generator once the HFSM compiled). The `Mars.SmState.ScreamingTurnipBed.Pull` line was dirty before me.
- `Script/Generated/DynamicHandleTypes.json` +27: `FCk_Handle_PantryRaid`, `FCk_Handle_PantryRat`, `FCk_Handle_RatDen` (inserted in the
  file's own order; the rest byte-identical, no trailing newline, as found). No "'FCk_Handle_X' is not a data type" transient appeared
  in the live log (0 hits after the first batch), because the entries were present before the first compile.
- `Script/Items/Mars_Item_Ingredients.as` +8: `mars_items::Add_PantryIngredientTrait(this);` in each of the 8 forage defs.
- `Script/ECS/SurfaceNavigator/Mars_SurfaceNavigator_{Feature,Utils,Processor_Requests,Processor_Tick}.as` +50/-1: one request
  `FMars_Request_SurfaceNavigator_SetSpeed { float32 Speed; }` (Requests array, `Request_SetSpeed` / `Get_Speed` mixins, State
  `TOptional<float32> SpeedOverride`), drained before Stop/MoveTo; the Tick steers with the override when set, else `Spec.Speed`
  (no override = the old line). D3-0: Processor_Tick is outside the brief's file list but is the reader "used by Tick" names.
- Touched and restored: `Script/ECS/PantryRat/Mars_PantryRat_Look_Assets.as` (Phase 2, untracked) had its line endings flipped to
  CRLF by my normaliser for about two minutes, then put back to LF; its content never changed.
- Written by the editor, not by me (do not stage blindly): `Script/Generated/{Mars_AutoTestActors,Mars_EntitySpawnParams,
  Mars_ScriptProcessorDrivers}.as` (already dirty from the sibling session) and `Content/Mars/Maps/AutoTests_Mars_MAP.umap` (the
  CkAutoTest populator auto-saved it with the 26 new test actors, live log 02:33:22 and 02:56:38 UTC). Untouched: every Crawler /
  Cookbook / Sandbox / Jolt / ScreamingTurnip / PaleCrawler / CellarBat path, every plugin, every production map.

### New files **confirmed** (all compile clean in the live editor: last reload 03:10:52 UTC, no `Angelscript: Error` after it)
- Items: `Script/Items/Traits/Mars_ItemTrait_StinkyCheese.as`, `Script/Items/Traits/Mars_ItemTrait_PantryIngredient.as` (with
  `mars_items::Add_PantryIngredientTrait`), `Script/Items/Mars_Item_PantryIngredients.as` (`Mars_ItemDef_MonksRind`: Transient, blockout
  presentation on `/Game/ArtCandidates/PantryRat/R01/Props/PantryRat_R01_Cheese_Mars_SM` with the ProtoGrid override cleared,
  StinkyCheese, no Food; `mars_items::MonksRind()`).
- `Script/ECS/RatDen/Mars_RatDen_{Feature,Utils,Processor_Requests}.as`, `Script/WorldObjects/Monsters/Mars_RatDen_EntityScript.as`.
- `Script/ECS/PantryRaid/Mars_PantryRaid_{Feature,Utils,Processor_Requests,Processor_Tick}.as`,
  `Script/WorldObjects/Monsters/Mars_PantryRaid_EntityScript.as`.
- `Script/ECS/PantryRat/Mars_PantryRat_{Feature,Utils,Processor_Requests,Processor_Tick,Processor_Setup,Hfsm,AnimInstance}.as`,
  `Script/WorldObjects/Monsters/Mars_PantryRat_EntityScript.as`.
- Tests: `Script/Tests/PantryRaid/` (rig `Mars_AutoTestRig_PantryRaid` + 11), `Script/Tests/RatDen/` (4), `Script/Tests/PantryRat/`
  (11 new beside Phase 2's 2).
- Validation: `Saved/Logs/PantryRatValidation/{RunPattern.ps1, RunBatch.ps1, phase3-run00..05-*/, phase3-final-sources.md5}`.

### What exists (shape) **confirmed** by the compile and the routed tests; how anything looks is not claimed
- **PantryRaid** (`utils_pantry_raid::Add(Owner, Spec)`, tag `TAG_MarsPantryRaid`): Spec groups Population / Scent / Guard / Routing /
  Theft / Speeds / Hop / Rhythm, each with a `Validate` mixin chained by the Spec's; `Parts.NavVolume`. Tick: clock (zero, negative or
  non-finite delta ignored, hitch capped at 0.25 s) -> every chef's current location (`TAG_MarsCombatTarget` roots with a Hotbar,
  anywhere) -> dens in the bounds -> roster prune -> readiness (field built AND current AND a provider `Success` route from a den's
  OutsideStand to the bounds' centre AND at least one den; `FMars_Tag_PantryRaid_Ready` stamped last) -> pack records (World +
  settled + cheese + stealable slots at most 48 cm above the pack root; scent arms after GroundArmSeconds; guard hysteresis 220 / 320
  with a 1 s dwell; lease lapse) -> at most one emergence per frame (armed target, cap, spacing, a den slot available, its
  OutsideStand clear of every chef). Requests: SpawnRat (once per operation id), RatDied, RatHome, ReleaseLease (by token),
  GrantLease (one lease per pack). Rats are spawned on the raid entity, so the raid owns them.
- **RatDen** (`utils_rat_den::Add`, tag `TAG_MarsRatDen`): portals in the den frame (Blender (x, y, z) -> UE (x, -y, z)), resident
  slots Dormant / Pending / Outside / DeadCooldown with operation ids, the eye proxy = the lowest Dormant slot (unset = black).
  Requests Emerge, MarkOutside, AdmitReturn (reads the rat's own pocket: a loaded rat is refused, logged, never ensured),
  ResidentDied, SetEyes. Signals OnEmergeReady / OnResidentReturned / OnReturnRefused / OnEyesChanged. Entity script: shell, an
  independent eye plate, Eyes on the plate (the shared MarsEyePlate the plate mesh wears), Wide while shown, strength 0 when vacant.
- **PantryRat** (`utils_pantry_rat::Add(Root, Spec)`, tag `TAG_MarsPantryRat`): SurfaceMotion (Rays, Slide, clearance 18, step 0,
  MaxSpeed 340) -> SurfaceNavigator (100, 30, 2, 15, 25) -> Monster (`Monster.Mars.PantryRat`, Health 1/1 born invulnerable, flesh
  zone `HitZone.Mars.Body`) -> hurtbox (20, 15, 17) -> the mouth node published as `AttachPoint.Mars.RatMouth` -> the capacity-1,
  NoStacking, non-persisted pocket (`Inventory.Mars.RatPocket`; CkInventory composes it on a child entity the rat owns) with the
  dynamic `UMars_PantryRat_PocketPolicy` and a PointAtOffset mount marker on the mouth -> fragments -> the state machine LAST. The
  phase enum is the spec's table plus BlockedCleanup. Single writer `UMars_Processor_PantryRat_HandleRequests` in the spec's priority
  order; `Processor_Tick` owns the clock, threat hysteresis (300 / 380), the no-target clock, the provider-only route rule and the
  carry / release receipts; `Processor_Setup` binds the zone's OnHit, Monster OnDied and the navigator's answers. HFSM Alive{Behave}
  / Dead{Dead}: the tasks read state and only enqueue.
- **Theft transaction**: lease (raid) -> Inspect 0.4 s -> ClaimTell 1.6 s (aborts on lease loss, guard or threat; a last guard check
  on current transforms) -> Claim -> drain: ClaimTransfer and `SlotInventory.Request_TransferItem_ToDataOnly(ExpectedItem, Pocket)` with
  the rat-owned correlated callback (never `FMars_Request_CargoSlot_Take`) -> CkInventory runs the pocket policy at the commit: rat
  alive, not lethal, in ClaimTransfer, pocket empty, item == the lease's item, the raid still holds that lease under that token
  before expiry, pack World + settled, no chef within GuardEnterCm of the pack by CURRENT transforms -> a refusal is a benign
  Contended / Cancelled, the lease dropped, back to Observe; acceptance requires `NewItemInTarget == Item` and parent == pocket ->
  CarryMountPending -> receipt (Persistent: its own world item settled Carried on the rat; Transient: one Visual world item on the
  mouth node constructed) -> FleeWithLoot.
- **Death receipts**: TakeHit is lethal only for `Amount > 0 && Causer.Is_Item() && Causer.As_Item().Has_Strike()` with a Hotbar
  instigator -> `SetInvulnerable(Disable)` + `ApplyDamage(Max)` in one drain, LethalPending, lease cancelled, navigator stopped.
  OnDied -> Dying (a claim in flight waits for its answer) -> Persistent loot: its own world item's `Request_Release(Forward * 80)`
  once (ReleaseOperationId), receipt = World with the item back in its own holder, refusal (bound OnReleaseRefused) -> BlockedCleanup
  + Warning; Transient loot: a World-mode `UMars_WorldItem_EntityScript` under the world's transient entity adopting SourceItem /
  SourceInventory from the pocket, receipt = the item in that holder -> DeadHold. `utils_monster::Add_DespawnTimer` is never used; no
  fade (Phase 4).

### Tests (one scenario per file; each file's header names its rubric row)
| row | test | run05 (final sources) |
|---|---|---|
| compose | `Mars_AutoTest_PantryRaid_SpecValidateRejectsEveryBadGroup` | PASS |
| compose + R01 / R27 kernel half | `Mars_AutoTest_RatDen_ComposesDormantAndGrantsOneSlotPerOperation` | PASS |
| compose + R23 edge table | `Mars_AutoTest_PantryRat_ComposesWithPocketMouthAndAnInvulnerableBody` | PASS |
| R01 | `Mars_AutoTest_PantryRaid_ReadinessGatesEmergence` | PASS |
| R02 | `Mars_AutoTest_RatDen_EyesHandOffToTheEmergingRat` | PASS |
| R03 | `Mars_AutoTest_PantryRaid_UnattendedPackStaysTarget` | PASS |
| R04 | `Mars_AutoTest_RatDen_NoTargetReturnsEmptyRatsHome` | PASS |
| R05 | `Mars_AutoTest_PantryRaid_SeatedChefGuardsForThirtySeconds` (30 s of raid clock, dilation 4) | PASS |
| R06 | `Mars_AutoTest_PantryRaid_ClosestValidThreatWins` | PASS |
| R07 | `Mars_AutoTest_PantryRaid_GuardHysteresisNoJitter` | PASS |
| R08 | `Mars_AutoTest_PantryRaid_GuardArrivesBeforeCommit` | PASS |
| R09 | `Mars_AutoTest_PantryRaid_TwoRatsOnePackOneLease` | PASS |
| R10 | `Mars_AutoTest_PantryRaid_PlayerTakeRaceOneWinner` | PASS |
| R11 | `Mars_AutoTest_PantryRaid_AnyIngredientIsEligible` | PASS |
| R12 | `Mars_AutoTest_PantryRaid_CheeseStolenStopsRecruitment` | PASS |
| R13 | `Mars_AutoTest_PantryRat_LoadedRatNeverReturns` (20 s of rat clock, dilation 4) | PASS |
| R14 | `Mars_AutoTest_PantryRat_FleeRejectsTheDenMouth` | PASS |
| R17 | `Mars_AutoTest_PantryRat_HitBeforeCommitBlocksTheClaim` / `Mars_AutoTest_PantryRat_HitAfterCommitReleasesOnce` | PASS |
| R18 | `Mars_AutoTest_PantryRat_PersistentFoodReleasedOnce` | PASS |
| R19 | `Mars_AutoTest_PantryRat_TransientForageAdopted` | PASS |
| R23 | `Mars_AutoTest_PantryRat_LoadedFadeVeto` | PASS |
| R25 | `Mars_AutoTest_PantryRat_ReleaseRefusalBlocksCleanup` | PASS |
| R26 | `Mars_AutoTest_RatDen_RemovalKeepsTheLootCarrier` | PASS |
| R27 | `Mars_AutoTest_PantryRat_StaleCallbacksIgnored` | PASS |
| R28 | `Mars_AutoTest_PantryRat_BoundRhythm` | PASS |

Hand-authored runner actors, written in the same file as their test before the generator first saw it (the generator then reports
"306 skipped (hand-authored)", +4): R08, R10 and R17-before expect the MonksRind rollback line; R25 expects `rolled back source
remove`, `it stays mounted` and `blocked its corpse cleanup` and requires `blocked its corpse cleanup`.

### Toolbox runs (detached per VALIDATION.md: `RunBatch.ps1` -> `RunPattern.ps1`, one dir per pattern, `--test --no-live --discover-fresh --test-pattern=<X>`; the real `Toolbox.log` summary and `Exit.json` read each time; no `.as` / `.ush` saved during a run) **confirmed**
| run dir (`Saved/Logs/PantryRatValidation/`) | exit | result |
|---|---|---|
| phase3-run00-aborted-badpattern | none | my wrapper passed "PantryRaid,RatDen,PantryRat" as ONE pattern; stopped during discovery, no verdict |
| phase3-run01-pantryraid | 1 | 3 selected: R01 PASS; SpecValidate FAIL (tag read in the Add frame); R03 FAIL (no lease in 33 s) |
| phase3-run01-ratden | 0 | 1/1 |
| phase3-run01-pantryrat | 1 | 2/3: rat compose FAIL (finding 1) |
| phase3-run02-pantryraid | 1 | 2/3: R03 FAIL (finding 2, diagnosed from its lane log) |
| phase3-run02-pantryrat | 1 | 2/3: rat compose FAIL (finding 5) |
| phase3-run03-pantryraid | 0 | 11/11 |
| phase3-run03-ratden | 0 | 4/4 |
| phase3-run03-pantryrat | 1 | 10/13: compose (finding 5), R17-before (finding 4), R25 (finding 3) |
| phase3-run04-pantryrat | 0 | 13/13 |
| **phase3-run05-pantryraid** (final sources) | **0** | 11/11, Contaminated 0, no new failures |
| **phase3-run05-ratden** | **0** | 4/4, Contaminated 0 |
| **phase3-run05-pantryrat** | **0** | 13/13 (11 mine + Phase 2's CandidateAssetsReload, LookMastersResolve), Contaminated 0 |
| **phase3-run05-cargoslot** (regression) | **0** | 6/6 incl. `Mars_AutoTest_CargoSlot_ATransferThatFailsBroadcasts` (its required ensure still fires) |
| **phase3-run05-surfacenavigator** | **0** | 5/5 (the SetSpeed edit leaves the navigator lane green) |
| **phase3-run05-backpack** | **0** | 5/5 |
| **phase3-run05-worlditem** | **0** | 25/25 |
| **phase3-run05-eyes** | **0** | 19 selected (Phase 2's 18 + my R02, whose name holds "Eyes"): 17 passed; Still red (listed) 2: `Mars_AutoTest_EyesDummy_ComposesAndWrites`, `Mars_AutoTest_Eyes_LookMasterResolves` (unchanged known reds, not mine); no NEW failure |
| **phase3-run05-monster** | **0** | 3/3 |
run05 ran 03:11:32-03:31:11 UTC; `md5sum -c` of `phase3-final-sources.md5` passed after it (sources unchanged). Focused patterns only;
not the full gate. The population line reads `[population] --test-pattern '<X>' selects N of them (0 renderer-only)` in every run.

### Findings that changed the code (each reproduced in a lane log before the fix)
1. `utils_inventory_data_only::Add(Entity, ...)` composes the inventory on its OWN child of `Entity`: a pocket added on an extra child
   made the rat its grandparent (run01 compose: "the pocket's lifetime owner is the rat" failed). Fixed: added on the rat root;
   CkInventory's child entity is the "child entity whose lifetime owner is the rat".
2. Route answers were scoped to the phase ENUM: a re-entered BoundApproach read the previous visit's Arrived and left in one frame
   (run02 lane log `Saved/Logs/Mars_4-backup-2026.11.07-02.52.10.log`: BoundApproach -> Observe 16 ms apart, no movement, no lease in
   33 s). Fixed: every phase change resets the route and an Advance stops a move in flight.
3. CkInventory validates a failed transfer's ROLLBACK re-add against the SOURCE inventory's accept policy: R25's refused release (holder
   full) bounced off the pocket's own policy and the Mushroom ended in no inventory (run03 lane log `Saved/Logs/Mars_3-backup-2026.11.07-03.04.48.log`: CkEnsure
   `Rollback == ECk_Inventory_OperationResult_Add::Success`, `CkInventory_RequestHandlers.cpp:675`). Fixed: the pocket always accepts
   its own recorded loot (D3-2). A framework hazard worth a CkFoundation note: a custom-accept source can lose an item on any refused
   outgoing transfer.
4. The inventory coordinator commits a transfer in the SAME frame the rat's drain issues it (run03 lane logs: ClaimTell ->
   ClaimTransfer -> answer at one frame number), before the HitZone's TakeHit reaches the rat; "strike and claim in one step"
   therefore commits and is released once (the correct R17-after behaviour). R17-before now latches the hit first, then claims.
5. A rat composed by a bare Add on a live entity enters Alive before its Dead byte attribute exists (CkEnsure "ByteAttribute
   [ByteAttribute.Mars.Monster.Dead] not found on context entity", run02 / run03). Production rats compose inside their entity
   script's construction (the Bat pattern); the compose test now spawns through the entity script.
6. CkInventory's refusal line logs at Verbose in these lanes (`CkInventory: Verbose: ... refused add of [...] (Failed Rejected by Custom
   Acceptance Logic); rolled back source remove`), not as the Warning the digest read; the expectations stay (harmless).

### Evidence lines (lane logs under `Saved/Logs/`; the editor rotates them, so the surviving lines are copied to `Saved/Logs/PantryRatValidation/phase3-evidence-lanelines.txt`)
- R08 (run03, read at about 03:00 UTC from `Mars_2-backup-2026.11.07-02.59.27.log` lines 2003-2009, since rotated away): lease token 1
  -> ClaimTell -> ClaimTransfer -> `CkInventory: Verbose: ... refused add of [...(Item (Mars_ItemDef_MonksRind))] (Failed Rejected by
  Custom Acceptance Logic); rolled back source remove` -> Observe, all in frame 716. The run05 R08 lane log was not retained.
- R10 (run05, `Mars_4-backup-2026.11.07-03.13.44.log` lines 2008-2009): ClaimTell -> ClaimTransfer -> Observe within frame 998 and
  no rollback line: the chef's Take ran first and the rat's transfer found its source empty (Cancelled). Only this ordering was
  observed, in run03 and run05 alike (D3-16).
- R25 before the fix (run03, `Mars_3-backup-2026.11.07-03.04.48.log`): `CkEnsure: Error: ... Rollback == ECk_Inventory_OperationResult_Add::Success`
  beside the WorldItem's `it stays mounted` and my `blocked its corpse cleanup` (finding 3). After the fix (run04,
  `Mars_3-backup-2026.11.07-03.10.11.log`): the same refusal and BlockedCleanup with no rollback ensure; test green.
- Finding 2's lane log (`Mars_4-backup-2026.11.07-02.52.10.log`) was read at 02:53 UTC and has since rotated away.

### Deviations
- D3-0 SurfaceNavigator `Processor_Tick` edited (one line) beside the three files the brief lists.
- D3-1 The drain-time predicate cannot test `Item.Get_ParentInventory() == slot`: CkInventory removes the item from its source and
  clears its parent link (RemoveItem: `TUtils_Item_ParentInventory::AddOrReplace(ItemHandle, FCk_Handle_Inventory())`) BEFORE the
  validated add (DoTransfer: remove, then add with Validate). Source membership is CkInventory's own check on the source the claim
  names, the lease's slot inventory (`Failed_SourceNotInInventory`); the predicate checks item == the lease's ExpectedItem.
- D3-2 The pocket policy accepts its own recorded loot unconditionally (finding 3).
- D3-3 SurfaceMotion `MaxStepHeight` 0, not 12: `FCk_SurfaceMotion_Contact`'s IsValid requires 0 or a value above Clearance (18).
- D3-4 One HFSM tick task (Behave) drives the control side of the whole phase table; the phase is kernel state and the kernel's edge
  table (`utils_pantry_rat::Get_IsAllowedAdvance`) decides every transition. Not one HFSM state per phase.
- D3-5 Clips by `USkeletalMeshComponent::PlayAnimation` from a phase -> clip table (brief-named). `PlayAnimation` puts the component
  in single-node mode, so the `UMars_PantryRat_AnimInstance` telemetry is only live once an AnimBP replaces it (inferred; no renderer).
- D3-6 Health born invulnerable (brief-named); a lethal weapon hit is normalised by `SetInvulnerable(Disable)` + `ApplyDamage(Max)`.
- D3-7 The mouth node sits at a computed rest frame on the root (`utils_pantry_rat::k_MouthRest`: the Carry_Mouth rest (19.8, 0, 20.6)
  less the 18 cm clearance, rotation (52, 0, 180) derived from the socket axes - inferred); it is NOT re-parented to the skeletal
  `Carry_Mouth` socket (AttachPoints publish once; Phase 4).
- D3-8 A bulky item (half-width over 10 cm) rides `k_DragRest` (upright, 24.5 cm ahead, at floor height) relative to the mouth node,
  written on the pocket's mount marker just before the claim; not the Carry_Drag socket's own rotation and z.
- D3-9 Den discovery = `ForEach_Entity(TAG_MarsRatDen)` inside the bounds every 0.5 s, not a persistent delta-gated query; the field
  comes only from `Spec.Parts.NavVolume` (no tag discovery); no static LOS ray (not used).
- D3-10 An admitted empty rat is destroyed by the raid (no pooling, no 0.25 s return fade: Phase 4).
- D3-11 Receipts are polled conditions in the rat's Tick (Persistent carry: `Get_Mount() == Carried && Get_Carrier() == rat &&
  Get_IsSettled()`, the predicate OnMountSettled reports; release: World with the item in that holder), not bound callbacks; the
  release refusal IS bound (`OnReleaseRefused` on a CDO `UMars_PantryRat_ReleaseListener` that finds the rat by `TAG_MarsPantryRat`).
- D3-12 Slot pick = eligible slot `(OperationId - 1) mod count` (deterministic per rat), not a hash.
- D3-13 Requests beyond the brief's lists: RatDen MarkOutside; raid SpawnRat / RatHome / RatDied / GrantLease / ReleaseLease; rat
  ClaimResult / NavResult / ReleaseRefused / Died / Stop / Advance / MoveTo.
- D3-14 `BlockedCleanup` added to the phase enum (the spec's "visible blocked cleanup").
- D3-15 New tags are resolved by name (`utils_gameplay_tag::ResolveGameplayTag`), not `GameplayTags::` constants (the live editor's tag
  namespace refreshes only at startup; the headless boots read the ini).
- D3-16 R10 observed only the take-first ordering.
- D3-17 R08 proves a refusal at the commit, not WHICH clause refused (a chef within GuardEnterCm by current transforms, or the lease
  the raid dropped on seeing the guard; both are read at the commit).
- D3-18 The "fixture clock" is global time dilation 4 (R05, R13, R14); the kernels advance on the dilated delta.
- D3-19 Display-level diagnostics: one line per rat phase change, raid readiness, each lease, each refused move or straight-line stop.
- D3-20 Agent radius 25 queries against fields baked with the capsule r40 profile work (GroundNav filters by per-cell clearance).

### Not verified / open
- Nothing visual: no renderer ran (rat mesh, per-slot MIs, CPD 14 seeding on a real component, Eyes on the EyePatch slot, Downed X eyes,
  the den plate Wide / black, the PlayAnimation clip table, mouth and drag offsets). All Phase 4.
- The Dying-while-ClaimTransfer path (a death drained between a claim's issue and its answer) is code-only: the coordinator answered
  in the same frame every time it was observed.
- R10's predicate-first ordering; R06 stops once the threat is seen (AvoidPlayer movement unasserted); FleeCornered never entered.
- Multiplayer: everything is DoesNotReplicate (the inventory / WorldItem path is local-only) - the R30 release blocker, not Phase 3.
- Catchability (R15) and fun: no real chase. Gate scope: focused patterns only, never the full gate.

Claim most likely wrong: that the mouth node's rest frame (`k_MouthRest`, rotation (52, 0, 180)) and the drag offset put a carried food
where the Phase 2 sockets do - derived from socket axes and rest positions, never rendered; the headless tests only prove the food
mounts on the published point.

## Phase 4 - pursuit, weapon death, dither, end-to-end court story, release evidence (2026-11-07, IN PROGRESS)

Brief: `PHASE_4_BRIEF.md`. Branch dev, HEAD 2154da26 (read-only). No git write command is run. Started 03:44 UTC.
Editor state at start (Monolith `list_dirty_packages`, 03:44 UTC): **0 dirty packages** - the Phase 2 materials the brief lists as
dirty are no longer dirty in this editor session (the live log `Saved/Logs/Mars.log` opened 2026-11-06; last script reload 03:10:52 UTC).

### Files I will edit (named before the edit; all are mine from Phase 3 unless marked)
- `Script/ECS/PantryRat/Mars_PantryRat_{Feature,Utils,Processor_Requests,Processor_Tick,Hfsm}.as` (kernel: fade clock, dead hold,
  corpse fade + destroy, return fade + hidden hand-off, loaded-veto log, flee scoring, topple side helper).
- `Script/ECS/PantryRat/Mars_PantryRat_AnimInstance.as` -> moved to `Script/WorldObjects/Monsters/Mars_PantryRat_AnimInstance.as` (D4-1, additive move).
- `Script/WorldObjects/Monsters/Mars_PantryRat_EntityScript.as` (topple rows, fade/hide write, eyes re-seed on body recreation, headless body option).
- `Script/ECS/PantryRaid/Mars_PantryRaid_Processor_Requests.as` (RatHome on a loaded rat: refused, logged once - already refused; log wording).
- Tests under `Script/Tests/{PantryRat,PantryRaid,RatDen}/` (new files + the rig `Mars_AutoTestRig_PantryRaid.as`).
- New: a review court under `Script/WorldObjects/Monsters/Mars_PantryRatReview.as` (court director entity script for the review map) and
  `Tools/Blender/mars_monsters/pantry_rat_r01/scripts/pantry_rat_court_ue.py` (map build + PIE driver).
- Shared files: none planned (no new tags, no new handle types, no SurfaceNavigator edit). Any change here is named first.
- Named during the work (before each edit, all my Phase 3 files): `Script/ECS/PantryRaid/Mars_PantryRaid_{Feature,Utils}.as`
  (+`RefusedRetirements` counter / getter), `Script/WorldObjects/Monsters/Mars_RatDen_EntityScript.as` (+`ShellCollisionProfile`
  spawn param, default BlockAll). Editor-written as a consequence: `Script/Generated/Mars_EntitySpawnParams.as` (the RatDen spawn
  params gained the field; the live editor regenerated it), `Script/Generated/Mars_AutoTestActors.as` + `Content/Mars/Maps/AutoTests_Mars_MAP.umap`
  (the populator: 6 new test actors, auto-saved 03:55:30 UTC). No shared file was edited by hand in this phase.

### Files (Phase 4) **confirmed** (`ls`; the live editor compiled the final set clean: last reload 04:40:34 UTC, no `Angelscript: Error` after it)
Changed (mine): `Script/ECS/PantryRat/Mars_PantryRat_{Feature,Utils,Processor_Requests,Processor_Tick,Hfsm}.as`,
`Script/WorldObjects/Monsters/Mars_PantryRat_EntityScript.as` (rewritten), `Script/WorldObjects/Monsters/Mars_RatDen_EntityScript.as`,
`Script/ECS/PantryRaid/Mars_PantryRaid_{Feature,Utils,Processor_Requests}.as`, `Script/Tests/PantryRaid/Mars_AutoTestRig_PantryRaid.as`,
`Script/Tests/PantryRat/Mars_AutoTest_PantryRat_{LoadedFadeVeto,ReleaseRefusalBlocksCleanup}.as` (extended).
Moved (D4-1): `Script/ECS/PantryRat/Mars_PantryRat_AnimInstance.as` -> `Script/WorldObjects/Monsters/Mars_PantryRat_AnimInstance.as` (content unchanged).
New: tests `Script/Tests/PantryRat/Mars_AutoTest_PantryRat_{CorneredThiefHoldsLootAndDies,RealStrikeKillsOnceAndTheCorpseFades,
RealStrikeBetweenClaimAndDrain,DeadEyesPersistAndTheToppleFollowsTheBlow,CorpseFadeIsIsolatedPerRat}.as`,
`Script/Tests/RatDen/Mars_AutoTest_RatDen_EmptyReturnFadesHidesThenEmergesSolid.as`; the review court
`Script/WorldObjects/Monsters/Mars_PantryRatReview.as` (`UMars_PantryRatCourt_EntityScript`: composes the court and drives the chef bot);
`Tools/Blender/mars_monsters/pantry_rat_r01/scripts/pantry_rat_court_ue.py` (map build / readback / PIE story driver / follow camera);
map `/Game/ArtCandidates/PantryRat/R01/Review/PantryRat_R01_Court_MAP` (+ its CkJolt cook `/Game/CkJoltData/ArtCandidates/PantryRat/R01/Review/PantryRat_R01_Court_MAP/*`,
written by the save hook: 8 bodies, 3 cells); evidence `review/phase4/**`, `Saved/Logs/PantryRatValidation/{phase4-*, phase4-evidence-lanelines.txt, phase4-final-sources.md5}`.
Final sources hashed 04:44 UTC: `phase4-final-sources.md5` (61 files; md5 of the list `cf3c044b7d1f8acbc47858132bec3cfb`); no `.as` saved after it.

### What changed in the kernel and assembly **confirmed** by the lanes and the PIE log lines cited below
- **One fade clock** (`FMars_Fragment_PantryRat.FadeAlpha`, written only by `Processor_Tick::Advance_Fade`): DenEnter waits
  `DenCrouchSeconds` (1.0, the DenEnter clip) then ramps 1 -> 0 over `ReturnFadeSeconds` (0.25); at 0 it sets `Hidden`, resets
  FadeAlpha to 1 in the same write, enters DormantInDen and only then asks the den to admit it (the den's slot goes Dormant and its
  proxy eyes come back after the rat is hidden - no doubled eyes; the raid retires the entity on the den's answer; a den that never
  answers gets one RatHome after 2 s). DeadHold -> CorpseFade only when `Clock >= DiedAt + DeathHoldSeconds` (3 s from the death,
  `Death.DiedAt` set in HandleDied) AND the loot is out (receipt landed, pocket empty); CorpseFade 1 -> 0 over 0.35 s, then Destroyed +
  one `Request_DestroyEntity`. Loot back in the pocket during CorpseFade -> BlockedCleanup.
- **Persistent release receipt** now also needs the food's pickup live (`WorldItem.Get_Pickup().Get_EnableDisable() == Enable`).
- **Loaded veto, logged once**: an Advance to ReturnEmpty / DenEnter / DormantInDen / CorpseFade / Destroyed on a loaded rat is refused,
  counted (`LoadedVetoes`) and logged the first time; a DenEnter fade on a loaded rat (unreachable through the edge table) is vetoed the
  same way; the raid's RatHome on a loaded rat is refused, counted (`RefusedRetirements`) and logged once (was a Warning).
- **Every phase step is logged and broadcast** (`StepFrom/StepTo` trail, `utils_pantry_rat::Emit_PhaseSteps`): a pass that goes
  FleeWithLoot -> Dying -> LootReleasePending reports both steps (finding F4-1). Each line names the rat id, op, both phases, location,
  clock, loot handle and fade.
- **Flee scoring (spec section 8)**: ring candidates scored by the ROUTE's separation from the nearest chef (the closest any chef on the
  rat's floor comes to the provider route, sampled every 50 cm, capped by the goal's own separation); a candidate that cannot beat the
  best is never queried; deterministic tie by ring index; den-portal keep-out on goal + every waypoint unchanged; ReturnEmpty's arrival
  no longer admits the rat itself (the kernel does, after the fade). Not implemented: the "turn / occluder" bonus (D4-5).
- **Topple side**: the drain records the lethal hit's impulse (`Death.HitImpulse`); `utils_pantry_rat::Get_ToppleSide(right, impulse,
  leftClear, rightClear)` picks the pushed side unless its floor clearance failed and the other passed (both blocked keeps the pushed side).
- **Assembly** (`Mars_PantryRat_EntityScript`): CPD 14 copied from FadeAlpha only when it changes (forced on a new primitive); hides the
  body before the write when `Hidden`; on the first dead frame clears the emote layer, sets the persistent Downed state, picks the topple
  with a Jolt static ray 35 cm to each side at belly height, plays `DeathToppleLeft/Right` for 0.8 s then `DeadHold`; `Rebuild_Body()`
  recreates the body primitive (CPD 14 first, then the Eyes are re-pointed and push all of 0..13); `BuildBodyHeadless` spawn flag for
  tests; a weak back-pointer fragment `FMars_Fragment_PantryRat_Assembly` (tests and the court read it).

### Tests added / extended (one scenario per file; the header names the row)
| row | test | result |
|---|---|---|
| R13 + R14 (cornered) | `Mars_AutoTest_PantryRat_CorneredThiefHoldsLootAndDies` (keep-out 5000 -> no admissible goal: FleeCornered for 2 s with the same cheese, no flee move, no home/fade phase; the real strike kills it in place; one release) | PASS run02, run03 |
| R16 a+b, R21 | `Mars_AutoTest_PantryRat_RealStrikeKillsOnceAndTheCorpseFades` (dealer DamageScale 0.02 -> 0.4 damage; two StrikeSweeps in one step; HitsDealt 2, depletions 1, Dying 1, hold >= 3 s from the death, fade ~0.35 s, the Mushroom world item World + pickup live after the corpse is destroyed) | PASS run02, run03 |
| R16 c, R17 | `Mars_AutoTest_PantryRat_RealStrikeBetweenClaimAndDrain` (strike when the Claim is queued or in flight; either order: one depletion, one Dying, at most one release, the item in exactly one place) | PASS run02, run03; observed order: the claim had already drained (ClaimTransfer -> CarryMountPending -> Dying), released once |
| R20 + topple | `Mars_AutoTest_PantryRat_DeadEyesPersistAndTheToppleFollowsTheBlow` (real body built headless; a 1 s emote, then a strike toward the right; cells 20/20, no emote/blink/look, body CPD 0/1 = 20 and 14 = 1 after the emote's duration; topple Right then DeadHold; `Rebuild_Body` re-seeds 20/20 + CPD 14; the pure side rule on 5 cases) | PASS run02, run03 |
| R24 (+R21 CPD half) | `Mars_AutoTest_PantryRat_CorpseFadeIsIsolatedPerRat` (two real bodies; one fades: its CPD 14 tracks FadeAlpha through (0,1), CPD 0..13 unchanged in every frame of the fade, the other rat's CPD 14 stays 1; Wood/Harness/Body are slots of the one body primitive) | PASS run02, run03 |
| R22 (+R04 dither) | `Mars_AutoTest_RatDen_EmptyReturnFadesHidesThenEmergesSolid` (fade ~0.25 s of rat clock before the hide; FadeAlpha 1 in every hidden frame; the den proxy off for the fading resident; Dormant + proxy after; the next emergence a new entity, solid and visible from its first watched frame) | PASS run01, run03 |
| R23 | `Mars_AutoTest_PantryRat_LoadedFadeVeto` + raid RatHome refused, `LoadedVetoes >= 3`, never hidden, still on the roster | PASS run02, run03 |
| R25 | `Mars_AutoTest_PantryRat_ReleaseRefusalBlocksCleanup` now watched 4 s (past the hold): never CorpseFade, never hidden, never destroyed | PASS run02, run03 |

### The court and how the story is driven **confirmed** (readback `review/phase4/court_map_readback.json`, PIE logs)
- Map `/Game/ArtCandidates/PantryRat/R01/Review/PantryRat_R01_Court_MAP` (created by `pantry_rat_court_ue.py build` through run_python +
  LevelEditorSubsystem, saved 04:07:47 UTC, never a console level load): 2100 x 1500 ProtoGrid floor, 120 cm walls, two 200 x 140 x 100
  crates at (0, +-330), PlayerStart (900, -550), Sun / Sky / exposure PPV, `Cam_Follow` + `Cam_Overview`, world settings GameMode
  `Mars_Gameplay_GameMode` (the real player character), and ONE placed `UMars_PantryRatCourt_EntityScript` at the origin. The director
  composes (game worlds only) the nav field (rat-sized bake capsule, D4-3), the raid (bounds = the court), one den at (-950, 0) facing +X
  (shell NoCollision, D4-3), a World backpack at (300, 0) with the Mushroom (Persistent Food) in cargo slot 1 and a Monk's Rind in slot 2.
- Weapon: the cleaver (`mars_items::Cleaver()`, `Script/Items/Mars_Item_Sandbox.as:72-102`: UseState `UMars_SmState_ItemUse_Strike`,
  Strike damage 20 Sever; reach 180, radius 25, windup 0.15 s, recovery 0.35 s are the `Mars_ItemTrait_Strike.as` defaults) put in the selected hotbar slot by `Review_GiveCleaver`, the
  same code path as the `Mars_Give Cleaver` cheat (D4-4).
- **Chef = the real player character driven by a bot on the director's tick (D4-2), not keyboard input.** Movement: the InputIntents
  `SetMoveDirection` request the Move action's `OnMove` sends (`Mars_Gameplay_InputProfile.as:268`); view: `utils_input_intents::Request_Look`
  (what `OnLook` sends, `:291`) in a closed loop; presses: the resolver intent opened as the IntentToResolver task does, then its best
  target started with `InteractTarget.Request_StartInteraction(player, player)` exactly as the task's `Forward_To`
  (`Mars_PlayerCharacter_Hfsm_Tasks.as:1036-1046`), held 0.2 s. Finding F4-2: opening the Primary intent alone (the `Mars_Primary`
  cheat) starts nothing - the strike never ran in runs 04-05 (`swing [None] dealt [0]` on 30+ presses) until the bot forwarded the target.
  The strike that lands is therefore the player's real `UMars_SmTask_ItemUse_Strike` (windup, viewpoint sphere sweep, DamageDealer).
- Capture: `capture_pie_movement_clip` (0.5 s frames, 2560 x 1392) on `Cam_Follow`, which a Python post-tick follows on the story's rat
  (on the far side of the rat from the chef in story09). Editor window not minimised (`IsIconic` False, 04:08 UTC); `list_dirty_packages`
  0 before every PIE; PIE stopped by the session before every write.

### The court story (PIE, `review/phase4/pie/story08` + `story09`; log lines copied to `phase4-evidence-lanelines.txt`) **confirmed** unless marked
Rat op 1 = the Mushroom thief; times are PIE seconds from the clip start; frames are `frame_NNN.png` (0.5 s apart). story09 repeats story08
with the camera on the far side from the chef; it is the run whose death beat is framed.
| beat | story08 frames | story09 frames | log line (Saved/Logs/Mars.log, UTC) |
|---|---|---|---|
| grounded cheese pack, den eyes lit (second resident dormant) | 004, 014 (plate eyes lit) | - | `04.33.40 ... pack [World] ... den eyes [true] slot0 [Dormant]` |
| cleaver in hand, chef walks to the pack | 008 (chef + cleaver beside the pack) | - | `04.33.40 [PantryRatCourt] cleaver into hotbar slot [0]`, `04.33.41 bot arrived at [X=429.999 Y=-60.000]` |
| emerge -> observe -> guarded watch (no claim) | 014-024 (rat at the den, watching) | - | `04.33.45 op [1] Observe -> WatchGuarded`, `04.33.49 op [2] Observe -> WatchGuarded`, leases [0] through `04.33.53` |
| chef leaves, pack stays | 030 | - | `04.33.53 PANTRYRAT_STORY t=8.40 state leave`, `04.33.55 bot arrived at [X=850 Y=520]` |
| bound / observe bursts toward the pack | 040 (two rats out) | - | `04.33.55 op [1] WatchGuarded -> Observe` ... Observe/BoundApproach alternation |
| inspect + rummage + snatch (the Mushroom, item 410) | 056-066 | - | `04.34.09 leased slot [1] item [410 ... Food_Mushroom]`, `Observe -> Inspect`, `Inspect -> ClaimTell`, `04.34.11 ClaimTell -> ClaimTransfer`, `ClaimTransfer -> CarryMountPending ... loot [410...]`, `CarryMountPending -> FleeWithLoot` |
| the Mushroom at the jaw | `crop_mouth_068.png` (cap under the snout, stem in the jaw) | - | describe `04.34.11 mushroom ... parent [Inventory.Mars.RatPocket] mount [Carried] carrier [rat] at [Z=20.6]` |
| loaded flee, chef chasing | 066-072 | 66-75 | `04.34.11 chasing [...] op [1] loot [410...]`, chase lines (chef 420 cm/s) |
| one weapon strike | 072 | 75-76 | `04.34.14 started the [InteractionIntent.Mars.Primary] interaction`, `the chef's strike was DEALT ... amount [20.0] causer [Cleaver]`, `FleeWithLoot -> Dying` (story09 `04.37.08`) |
| topple + DeadHold | 073-076 (rat under the chef) | 76-80, `crop_corpse_080.png` (on its side, belly up) | `04.34.14 topples Left (impulse ...)`; story09 `04.37.08 topples Right` |
| X eyes | NOT SEEN in PIE (the head is under the chef's body in every corpse frame) | NOT SEEN | headless R20 only (inferred for PIE) |
| the SAME Mushroom dropped | - | 86-96 (Mushroom on the floor) | `Dying -> LootReleasePending -> DeadHold ... loot [TOMBSTONE]`; describe `04.34.18 mushroom item [410] parent [Inventory.Mars.WorldItemHolder] mount [World]` |
| 3 s hold | - | 76-83 | story08 `DeadHold -> CorpseFade at clock 32.044` vs Dying at 29.033 (3.01 s); story09 30.312 -> 33.395 (3.08 s) |
| corpse dithers, Mushroom solid | - | 82 (`crop_corpse_082.png`: body, spoon, harness and shadow speckled together), 86+ (Mushroom solid, corpse gone) | `CorpseFade -> Destroyed ... fade [0.0]` 0.35-0.44 s later |
| chef picks the Mushroom up | - | (the external view does not show the held item, see unverified) | `04.34.19 started the [InteractionIntent.Mars.Use] interaction`; describe `04.34.24 state done ... mushroom item [410] parent [Inventory.Mars.Slot.1] mount [Carried] carrier [Player]` |
Same item handle `410|0(410)` from the pack's cargo slot -> the rat pocket -> the world holder -> the player's hotbar slot: no respawn.

**Separately - pack picked up before any theft** (`review/phase4/pie/return10`, `strip_return.png`): chef walks to the pack, Use ->
pack `[Carried]` (`04.38.54 started the [InteractionIntent.Mars.Use] interaction`), the out rat `Observe -> ReturnEmpty -> DenEnter`
(04.38.54), `DenEnter -> DormantInDen` at clock 3.707 (crouch 1.0 + fade), den `eyes [true] slot0 [Dormant]`; frame 016 shows the
rat mid-dither at the den mouth, 017 gone; `Review_SpawnSecondPack` then a second emergence `op [2] Emerge -> Observe` (04.39.03)
starts solid (frames 032-033).

### Catchability (R15) **confirmed** from the chase log lines; the input is the bot (D4-2)
Chef `MaxWalkSpeed` 420 (`Script/PlayerCharacter/Mars_PlayerCharacter_Assets.as:27` Walk = 420, applied at `Mars_PlayerCharacter.as:147`;
measured: chase lines `speed [420.0]` in every run), never sprint. Rat loaded speed 320 (`FMars_PantryRaid_Speeds.LoadedFlee`), 2-3 bounds
of 0.4 s then 0.35-0.65 s look-back (`FMars_PantryRaid_Rhythm`). Same start for all: chef at (850, 520) when the theft lands, rat at the pack.
| run | time to first strike opportunity | strike landed | presses |
|---|---|---|---|
| run07 (04:31) | 3.16 s | yes, first press (+0.41 s) | 1 |
| story08 (04:34) | 3.06 s | yes, first press (+0.15 s) | 1 |
| story09 (04:37) | 2.51 s | yes (+1.5 s) | 2 |
| reload12 (04:43, reloaded map) | 2.69 s | yes, first press (+0.16 s) | 1 |
No tuning change: the walking chef catches the loaded rat in about 3 s every time, so `ASSET_AND_GAMEPLAY_MANIFEST.json` is untouched.
Inferred, not measured: whether the chase is FUN - it is short because the rat's flee goals from the pack corner and the chef's start
corner overlap; a human reviewer should judge it.

### R30 - multiplayer **BLOCKED** (facts read, nothing implemented)
Every ownership path of this feature is local-only, so a client can neither see nor agree on the loot, the corpse or the fade:
- CargoSlot inventories: `utils_inventory_data_only::Add(SlotEntity, InventoryParams, ECk_Replication::DoesNotReplicate)` (`Script/ECS/CargoSlot/Mars_CargoSlot_Utils.as:35`).
- Monster team and Dead attribute: `utils_team::Add(..., DoesNotReplicate)` and `utils_byte_attribute::Add(InRoot, DeadSpec, DoesNotReplicate)` (`Script/ECS/Monster/Mars_Monster_Utils.as:21,33`); Health's attribute `DoesNotReplicate` (`Script/ECS/Health/Mars_Health_Utils.as:15`).
- Rat pocket `DoesNotReplicate` (`Script/ECS/PantryRat/Mars_PantryRat_Utils.as:140`); rat / den / raid entity scripts `_Replication = DoesNotReplicate` and their roots' transforms too (`Mars_PantryRat_EntityScript.as:40,103`, `Mars_RatDen_EntityScript.as:10,47`, `Mars_PantryRaid_EntityScript.as:7,27`).
- WorldItem: `_Replication = DoesNotReplicate`, root transform and holder inventory `DoesNotReplicate` (`Script/WorldObjects/Items/Mars_WorldItem_EntityScript.as:19,83,377`), so the dropped food's holder and its body are local.
- SurfaceMotion / SurfaceNavigator: no replication setting in `CkSurfaceMotion_*.h` or `Script/ECS/SurfaceNavigator/*`; the rat's motion writes a root transform that is itself `DoesNotReplicate` (inferred: rat movement is local).
**Prerequisite before any client can see the correct state:** the item ownership chain must replicate server-authoritatively - the
CargoSlot inventories, the rat pocket and the WorldItem holder inventory (with the item's parent link and the WorldItem mount/carrier),
plus the rat root transform, its Monster Dead attribute and the rat's phase/FadeAlpha (or an explicit replicated presentation state) -
and the raid/rat/den entity scripts must spawn as server-owned replicated entities. Until then, multiplayer release is blocked; the
local slice is locally verified only. No two-client / late-join run was attempted.

### R01-R30 (HEAD 2154da26 + uncommitted sources hashed in `phase4-final-sources.md5`; runs in `Saved/Logs/PantryRatValidation/`)
| row | verdict | evidence |
|---|---|---|
| R01 | PASS | `Mars_AutoTest_PantryRaid_ReadinessGatesEmergence` (run03-pantryraid); PIE: the court raid logs `ready: 1 den(s)` before any emergence |
| R02 | PASS | `Mars_AutoTest_RatDen_EyesHandOffToTheEmergingRat` (run03-ratden); PIE story08 frame 014 (the dormant resident's pair lit in the plate while the other rat is out); return10 `den eyes [true] slot0 [Dormant]` after the hide; R22 test: proxy off during the fade |
| R03 | PASS | `..._UnattendedPackStaysTarget` (run03); PIE story08: chef leaves (04.33.53) -> lease 04.34.09 -> theft |
| R04 | PASS | `..._NoTargetReturnsEmptyRatsHome` + `..._EmptyReturnFadesHidesThenEmergesSolid` (run03-ratden); PIE return10 (pack picked up, ReturnEmpty -> DenEnter -> DormantInDen, dither frame 016) |
| R05 | PASS (headless 30 s) | `..._SeatedChefGuardsForThirtySeconds` (run03); PIE guard held 5-24 s with leases [0] and both rats WatchGuarded (story08 04.33.45-04.33.53, reload12); a standing chef (crouch not driven) |
| R06 | PASS | `..._ClosestValidThreatWins` (run03) |
| R07 | PASS | `..._GuardHysteresisNoJitter` (run03) |
| R08 | PASS | `..._GuardArrivesBeforeCommit` (run03) |
| R09 | PASS | `..._TwoRatsOnePackOneLease` (run03); PIE: two residents, leases granted one at a time (story08 token 1, then token 2 after the first theft) |
| R10 | PASS | `..._PlayerTakeRaceOneWinner` (run03) (take-first order only, D3-16) |
| R11 | PASS | `..._AnyIngredientIsEligible` (run03); PIE: Mushroom (Persistent Food) and Monk's Rind both stolen |
| R12 | PASS | `..._CheeseStolenStopsRecruitment` (run03); PIE story08/09: the Monk's Rind thief keeps fleeing with it |
| R13 | PASS | `..._LoadedRatNeverReturns` + `..._CorneredThiefHoldsLootAndDies` (run03-pantryrat) |
| R14 | PASS | `..._FleeRejectsTheDenMouth` + `..._CorneredThiefHoldsLootAndDies` (cornered, catchable in place) (run03) |
| R15 | PASS (bot-driven input, D4-2) | catchability table: 4/4 chases from the same start caught on walk 420 in 2.5-3.2 s, strike landed each time; no tuning change |
| R16 | PASS | `..._RealStrikeKillsOnceAndTheCorpseFades` (fractional 0.4 + two contacts -> 1 depletion, 1 Dying, 1 drop) + `..._RealStrikeBetweenClaimAndDrain` (run03); PIE: 5 kills by the real ItemUse strike, one `-> Dying` each |
| R17 | PASS (one order observed) | `..._HitBeforeCommitBlocksTheClaim`, `..._HitAfterCommitReleasesOnce`, `..._RealStrikeBetweenClaimAndDrain` (run03); the Dying-during-ClaimTransfer branch is still code-only (D4-7) |
| R18 | PASS | `..._PersistentFoodReleasedOnce` (run03); PIE: item 410 pocket -> its own world holder (World) -> the player's slot |
| R19 | PASS | `..._TransientForageAdopted` (run03); PIE run06/07: the Monk's Rind thief killed, `LootReleasePending -> DeadHold` with the receipt |
| R20 | PASS (headless) / PIE visual not seen | `..._DeadEyesPersistAndTheToppleFollowsTheBlow` (run03: cells 20/20 on the real body primitive after the timed emote and after `Rebuild_Body`); X eyes not visible in any PIE corpse frame (head under the chef) |
| R21 | PASS | `..._RealStrikeKillsOnceAndTheCorpseFades` (hold >= 3 s from death, ~0.35 s fade, Mushroom alive after) (run03); PIE story09 frames 82 (speckled corpse incl. spoon + harness + shadow) and 86-96 (corpse gone, Mushroom solid) |
| R22 | PASS | `..._EmptyReturnFadesHidesThenEmergesSolid` (run03); PIE return10 frames 016 (mid-dither) / 017 (gone) / 032-033 (next rat solid) |
| R23 | PASS | `..._LoadedFadeVeto` (Advance x3 + den AdmitReturn + raid RatHome refused) (run03) |
| R24 | PASS (headless) | `..._CorpseFadeIsIsolatedPerRat` (run03: CPD 0..13 untouched, other rat CPD 14 = 1, spoon/harness slots on the one primitive); PIE frame 82 shows spoon + harness dithering with the body; two rats fading side by side not framed in PIE |
| R25 | PASS | `..._ReleaseRefusalBlocksCleanup` (watched 4 s past the hold) (run03) |
| R26 | PASS | `..._RemovalKeepsTheLootCarrier` (run03) |
| R27 | PASS | `..._StaleCallbacksIgnored` (run03) |
| R28 | PASS | `..._BoundRhythm` (run03); PIE logs: Observe / BoundApproach alternation (run03 PIE 04.17.21-04.17.29) and FleeWithLoot / FleePause bursts |
| R29 | PASS | `Mars_AutoTest_PantryRat_CandidateAssetsReload` in a fresh headless editor (run03-pantryrat and the full gate); the court map reopened from disk (readback `review/phase4/court_map_readback.json`: 14 actors, `Mars_Gameplay_GameMode`) and the story repeated on it (reload12: same beats, Mushroom 410 into the player's slot). The .blend/FBX reopen is Phase 1/2 evidence, not re-run |
| R30 | **BLOCKED** | see "R30 - multiplayer"; everything `DoesNotReplicate`; no two-client run |

### Toolbox runs (detached: `RunBatch.ps1` -> `RunPattern.ps1`, one dir per pattern; the full gate `RunGate.ps1`; the real `Toolbox.log` summary and `Exit.json` read each time; no `.as` saved during a run) **confirmed**
| run dir (`Saved/Logs/PantryRatValidation/`) | exit | result |
|---|---|---|
| phase4-run01-pantryrat | 1 | 18 selected, 15 passed: RealStrikeKillsOnce, CorneredThief, RealStrikeBetweenClaimAndDrain failed on "one Dying" (F4-1: Dying never broadcast) |
| phase4-run01-ratden | 0 | 5/5 (incl. the new R22 test) |
| phase4-run01-pantryraid | 0 | 11/11 |
| phase4-run02-pantryrat | 0 | 18/18, Contaminated 0 (after the step trail) |
| **phase4-run03-pantryrat** (final sources, 04:44-05:14 UTC batch) | **0** | 18/18, Contaminated 0 |
| **phase4-run03-ratden** | **0** | 5/5 |
| **phase4-run03-pantryraid** | **0** | 11/11 |
| **phase4-run03-cargoslot** | **0** | 6/6 (incl. `ATransferThatFailsBroadcasts`) |
| **phase4-run03-surfacenavigator** | **0** | 5/5 |
| **phase4-run03-backpack** | **0** | 5/5 |
| **phase4-run03-worlditem** | **0** | 25/25 |
| **phase4-run03-eyes** | **0** | 20 selected, 18 passed; Still red (listed) (2): `Mars_AutoTest_EyesDummy_ComposesAndWrites`, `Mars_AutoTest_Eyes_LookMasterResolves` (unchanged known reds, not mine); no NEW failure |
| **phase4-run03-monster** | **0** | 3/3 |
| **phase4-run03-attack** | **0** | 20/20 (the AttackCatalog / crawler attack tests: the enemy attack, see the note below) |
| **phase4-run03-health** | **0** | 12/12 (1 renderer-only, ran in the real-renderer editor) |
`md5sum -c phase4-final-sources.md5` passed after run03 (05:14 UTC) and the full gate was launched on the same sources.
Note: `Script/ECS/Attack` is the CRAWLER attack catalog, not the chef's; the chef's attack is the held item's
`UMars_SmTask_ItemUse_Strike` (`Script/Items/Hfsm/Mars_ItemUse_Hfsm.as:116`) through `Request_StrikeSweep`
(`Script/ECS/DamageDealer/Mars_DamageDealer_Utils.as`), which the new tests and the PIE strikes use.

### The single full gate **confirmed** (`Saved/Logs/PantryRatValidation/phase4-gate01-full/`, `RunGate.ps1`: `--test --no-live --discover-fresh`, no pattern; 05:14:22-06:01:08 UTC on the hashed final sources; `Toolbox.log` copied to `phase4-gate01-full-Toolbox.copy.log`)
**Exit code 1** (`Exit.json` `toolboxExitCode` 1). Renderer-only section: `Renderer-only: 226 test(s) ran in a real-renderer editor`; no exit 81.
```
[population] 5341 of 11102 discovered tests are in the gate population — roots from AutomationGate.json: Ck CkAngelscriptGenerator CkGrid CkSubsystemBrowser CkGoapDebugger
[population]   included: Ck(2060) Project(2000) CkTests(881) Monolith(126) CkAngelscriptGenerator(96) GitLink(86) CkHands(39) ControlRig(32) Angelscript(7) CkGoapDebugger(5) CkGrid(5) CkFoundation(2) CkSubsystemBrowser(2)
[population]   renderer-only: 226 of them need a real renderer (flagged NonNullRHI) and run in a real-renderer editor after the headless lanes
=== Test summary ===
Total: 5341
Passed: 5229
Failed: 112
Skipped: 0
Contaminated: 0
Duration: 45m 20s
Failed tests (112):  [list omitted here: it is the union of NEW FAILURES, Still red and Listed flaky below; full text in phase4-gate01-summary-verbatim.txt]
Renderer-only: 226 test(s) ran in a real-renderer editor
=== Known reds: 81 listed (38 in AutomationGate.json, 1 in Plugins/CkFoundation/AutomationGate.json, 6 in Plugins/CkGameplayDebugger/AutomationGate.json, 36 in Plugins/CkTests/AutomationGate.json) ===
NEW FAILURES — not on the list, these fail the gate (71):
  Angelscript.CppTests.AngelscriptCodeCoverage.IntegrationTest
  Ck.Chain.DistanceConstraint.DistanceConstraint_PreservesSegmentLengths
  Ck.Chain.DistanceConstraint.InvalidInput_RejectsWithoutPartialMutation
  Ck.Chain.PathHistory.Extrapolation_LargeArcUsesFiniteDifference
  Ck.Chain.PathHistory.InvalidInput_RejectsWithoutPartialMutation
  Ck.Chain.PathHistory.LiveHead_UnrepresentablePoseRejectsWithoutMutation
  Ck.Chain.PathHistory.Orientation_DegenerateUpFallsBackToSampled
  Ck.Chain.PathHistory.Record_RejectsChordBelowSpacing
  Ck.Chain.PathHistory.Reseed_ProducesTwoSamplesBehindAndAtHead
  Ck.Chain.PathHistory.Ring_WrapsWithoutReallocInSteadyState
  Ck.Chain.PathHistory.Sample_BehindOldest_ExtrapolatesOrHolds
  Ck.Chain.PathHistory.Slice_RejectsUnrepresentableArcRebase
  Ck.Chain.PathHistory.Solve_InvalidInputRejectsBeforePlacement
  Ck.Chain.PathHistory.Trim_KeepsAtLeastTwoAndCoversDistance
  Ck.CkSpatialQuery.Probe.ContactFilterRejectsCapacityExhaustion
  Ck.CrowdDebugger.Viewport3d.AvoidanceVolumesFailClosedAcrossWorldChange
  Ck.CrowdDebugger.Viewport3d.LaterBadAgentAbortsWithoutPublishing
  Ck.DebugScene.Target.CapacityAndInvalidInputAreAtomic
  Ck.DebugScene.Target.FrameCommitFailureRollsBackAllItems
  Ck.DebugScene.Target.FramePrepareFailureRollsBackAllItems
  Ck.DebugScene.Target.NamedChannelsRetainIndependently
  Ck.EntityScript.EditorServices.PendingAssetRename
  Ck.Gait.Processor.NonFiniteVelocity_RestsAndRecovers
  Ck.NavmeshDebugDraw.MeshComponent.AreaPreviewPreservesAuthoritativeState
  Ck.NavmeshDebugDraw.MeshComponent.InvalidApplyIsAtomic
  Ck.PixelArtViewer.TimeTrack
  Ck.Pmg.DebugLineSet.BreadcrumbSupport.ComposesAndRebakesThickness
  Ck.ProceduralAnimation.Action.Editor.MountedToolkit.TwoTabsModesAndCapture
  Ck.ProceduralAnimation.Action.Editor.Undo.SubjectChangeRefreshesAppearance
  Ck.TextureDebugger.SceneAudit.ContextCommands
  Ck.UiAuthoring.Debugger.EventLog.AuthoredPresentation
  CkTests.UnitTests.CkCrowd.AvoidanceSample.AdaptiveDepth
  CkTests.UnitTests.CkCrowd.AvoidanceSample.NeighborSide.InvalidAndPlanar
  CkTests.UnitTests.CkCrowd.AvoidanceSample.ReachabilityProjection
  CkTests.UnitTests.CkCrowd.ConstrainToNavmesh.SurfaceOffset
  CkTests.UnitTests.CkCrowd.StationaryMarkup.WindowedSpeedThreshold
  CkTests.UnitTests.CkCrowd.StrictDynamicDispatch.MalformedConfirmedBlockerFailsTerminally
  CkTests.UnitTests.CkGroundNav.Bake.Budget_TargetedMultiProfileIsAtomicAndInvalidListDoesNotMutate
  CkTests.UnitTests.CkGroundNav.Facade.DynamicPath_UsesStrictObstacleSnapshotAndRejectsMalformedEndpoints
  CkTests.UnitTests.CkGroundNav.FieldTransform.RefusalsAreAtomic
  CkTests.UnitTests.CkGroundNav.LinkAdmission.EndpointOutsideTheVolumeFails
  CkTests.UnitTests.CkGroundNav.LinkAdmission.EqualEndpointsFail
  CkTests.UnitTests.CkGroundNav.LinkAdmission.InvalidEntityFails
  CkTests.UnitTests.CkGroundNav.LinkAdmission.MultiplierBelowOneFails
  CkTests.UnitTests.CkGroundNav.LinkAdmission.UnregisteredAreaTagFails
  CkTests.UnitTests.CkGroundNav.LinkState.BatchAdmitsAllOrNothing
  CkTests.UnitTests.CkGroundNav.LinkVeto.MultiplierBelowOneIsRefusedAtTheRequestBoundary
  CkTests.UnitTests.CkGroundNav.StreamingAcceptance.BuildInvoker.InvalidDescriptorsAreIgnored
  CkTests.UnitTests.CkGroundNav.StreamingAcceptance.Invoker.Registry.InvalidInputDoesNotMutate
  CkTests.UnitTests.CkGroundNav.StreamingAcceptance.Registry.LoadingIsAtomic
  CkTests.UnitTests.CkGroundNav.StreamingAcceptance.Registry.RegistrationIsAtomic
  CkTests.UnitTests.CkGroundNav.Volume.Markup_RejectsADegenerateShape
  CkTests.UnitTests.CkGroundNav.Volume.Markup_RejectsAnUnpublishedAreaTag
  CkTests.UnitTests.CkUsf.GeneratesUsableMasters
  CkTests.UnitTests.CkUsf.GymShadingModelsCompileAllLegacyVariants
  CkTests.UnitTests.CkUsf.NiagaraSpriteContract  (editor died mid-test)
  CkTests.UnitTests.CkUsf.OutlineClaims
  CkTests.UnitTests.CkUsf.ShadingModelDeclarationToonPipelineReloadUpdatesExistingMID
  CkTests.UnitTests.CkUsf.StylizeCVarSurfaceReachesTheMid
  CkTests.UnitTests.CkUsf.ToonAuthoringGeneratesNativeMaster
  CkTests.UnitTests.CkUsf.ToonLightingReloadUpdatesExistingMID
  CkTests.UnitTests.CkUsf.ToonRejectsUnsupportedAuthoringAtomically
  CkTests.UnitTests.CkUsf.ToonReservedOutputNamesAreScoped
  Project.Functional Tests.CkTests.AutoTests.AutoTests_CkTests_Level.Ck_AutoTest_ProceduralAnimation_SpiderCourseTraversal
  Project.Functional Tests.Mars.Maps.AutoTests_Mars_MAP.Mars_AutoTest_CuttingStation_SweepWithoutATrayIsRefused
  Project.Functional Tests.Mars.Maps.AutoTests_Mars_MAP.Mars_AutoTest_DamageDealer_FriendlyFireRejected
  Project.Functional Tests.Mars.Maps.AutoTests_Mars_MAP.Mars_AutoTest_FryStation_ATakeOutThroughTheIntentIsCappedByTheTray
  Project.Functional Tests.Mars.Maps.AutoTests_Mars_MAP.Mars_AutoTest_HitZone_HurtboxRegistration
  Project.Functional Tests.Mars.Maps.AutoTests_Mars_MAP.Mars_AutoTest_KeyLock_ATransferThatFailsBroadcasts
  Project.Functional Tests.Mars.Maps.AutoTests_Mars_MAP.Mars_AutoTest_LanternHook_ARequestThatFailsBroadcasts
  Project.Functional Tests.Mars.Maps.AutoTests_Mars_MAP.Mars_AutoTest_LanternHook_TwoRefuelsInOneDrainKeepTheSecondTallow
Still red (listed) (36):
  Ck.CapabilityGallery.InstalledResources  [Plugins/CkTests]
  Ck.DialogDebugger.Authored.PIE  [Plugins/CkTests]
  Ck.Dynamic.Net.AS_DynamicFragment_DriverCarrierOnNotify  [Plugins/CkTests]
  Ck.Dynamic.Net.AS_DynamicFragment_DriverCarrierReplicates  [Plugins/CkTests]
  Ck.GoapDebugger.Squad.Authored.PIE  [Plugins/CkTests]
  Ck.GoapDebugger.Timeline.Authored.PIE  [Plugins/CkTests]
  Ck.Particles.PrewarmTemplates  [Plugins/CkFoundation]
  Ck.PathNetworkEditor.Designer.FitLoadedWorldIgnoresLevelBoundsActor
  Ck.ProceduralAnimation.Gait.LandingProbeLiftsASwingOntoAStep  [Plugins/CkTests]
  Ck.ProceduralAnimation.SurfaceMotion.SnapshotShowsThePendingContact
  Ck.Snapshot.LevelRootRemoval.AuthorityBoundary  [Plugins/CkTests]
  Ck.Snapshot.LevelRootRemoval.CancellationSurvivesSourceTeardown  [Plugins/CkTests]
  Ck.Snapshot.LevelRootRemoval.DuplicateIdentityFailsClosed  [Plugins/CkTests]
  Ck.Snapshot.LevelRootRemoval.LevelActorBridgeOrigin  [Plugins/CkTests]
  Ck.Snapshot.Meta.FragmentPostureCoverage
  Ck.Snapshot.Meta.NoProcessorBypassesQuarantine  [Plugins/CkTests]
  Ck.Snapshot.Meta.WallTimeReadsAreAllowListed  [Plugins/CkTests]
  Ck.UIDebugger.History.PIE  [Plugins/CkTests]
  Ck.UiAuthoring.EcsDebugger.StateMachineInspector.AuthoredVariants  [Plugins/CkTests]
  Monolith.CursorPagination.QueryMismatchRejection
  Monolith.ReflectionIntel.CppReflect.FindSpecifier
  Monolith.ReflectionIntel.CppReflect.UHTArtefactParse
  Monolith.ReflectionIntel.Decision.HeuristicAccuracy
  Monolith.ReflectionIntel.Decision.StalenessFlag
  Monolith.ReflectionIntel.Decision.SupersessionChain
  Monolith.ReflectionIntel.Risk.ConditionalGateSweep
  Project.Functional Tests.CkTests.AutoTests.AutoTests_CkTests_Level.Ck_AutoTest_Crowd_AvoidanceVolume_InitialPathAvoidsExpandedObb  [Plugins/CkTests]
  Project.Functional Tests.CkTests.AutoTests.AutoTests_CkTests_Level.Ck_AutoTest_Crowd_BunchUp_SettlesAtSharedGoal  [Plugins/CkTests]
  Project.Functional Tests.CkTests.AutoTests.AutoTests_CkTests_Level.Ck_AutoTest_PaViz_NavigationFocus  [Plugins/CkTests]
  Project.Functional Tests.CkTests.AutoTests.AutoTests_CkTests_Level.Ck_AutoTest_PaViz_StressVisual  [Plugins/CkTests]
  Project.Functional Tests.CkTests.AutoTests.AutoTests_CkTests_Level.Ck_AutoTest_PaViz_Visual  [Plugins/CkTests]
  Project.Functional Tests.CkTests.AutoTests.AutoTests_CkTests_Level.Ck_AutoTest_ProceduralAnimation_PillarCrossingRenderedTraversal  [Plugins/CkTests]
  Project.Functional Tests.CkTests.AutoTests.AutoTests_CkTests_Level.Ck_AutoTest_ProceduralAnimation_PostsCentipedeReturns  [Plugins/CkTests]
  Project.Functional Tests.CkTests.AutoTests.AutoTests_CkTests_Level.Ck_AutoTest_VisualLod_RenderBandProfileLifecycle  [Plugins/CkTests]
  Project.Functional Tests.Mars.Maps.AutoTests_Mars_MAP.Mars_AutoTest_EyesDummy_ComposesAndWrites
  Project.Functional Tests.Mars.Maps.AutoTests_Mars_MAP.Mars_AutoTest_Eyes_LookMasterResolves
Listed flaky, failed, not re-run (5):
  Ck.GoapDebugger.AgentColumn.Authored.PIE  [Plugins/CkTests]
  Ck.TextureDebugger.Ux.TextureHealthContextMenuTarget  [Plugins/CkGameplayDebugger]
  Ck.UiAuthoring.Button.VisualStyle
  Project.Functional Tests.CkTests.AutoTests.AutoTests_CkTests_Level.Ck_AutoTest_IskmRenderer_BatchedVisual  [Plugins/CkTests]
  Project.Functional Tests.CkTests.AutoTests.AutoTests_CkTests_Level.Ck_AutoTest_ProceduralAnimation_PillarsEngageSteppedTops  [Plugins/CkTests]
Now passing (listed red) — remove with --known-reds prune (23):
  Ck.Snapshot.HeaderProvenance.CaptureStampsTheWritingBuild
  Ck.Snapshot.Idempotency.RepeatedLoadSameSlot
  Ck.Snapshot.Idempotency.SaveAfterLoadThenLoad
  Ck.Snapshot.Ordering.BeginPlayObservesConstructDefaults
  Ck.Snapshot.Ordering.CrossEntityLiftIsAtomic
  Ck.Snapshot.Ordering.DestroyWhileQuarantinedRunsEndPlay
  Ck.Snapshot.Ordering.MarkerClearCannotSkipSetup
  Ck.Snapshot.Ordering.NoProcessorSeesHalfHydrated
  Ck.Snapshot.Ordering.OnHydratedFiresAfterAllPayloads
  Ck.Snapshot.Ordering.QuarantineAlwaysLiftsAtFinish
  Ck.Snapshot.Ordering.SetupRunsOncePostHydration
  Ck.Snapshot.Parity.FogOfWar_RoundTrip
  Ck.Snapshot.Parity.LocalCoordinateConversion_RoundTrip
  Ck.Snapshot.Promise.OneShotAcrossTwoLoads
  Ck.Snapshot.Promise.SurvivesTravel
  Ck.Snapshot.Report.NoHandlerPayloadIsCountedAndNamed
  Ck.Snapshot.Report.UnappliedPayloadDowngradesResult
  Ck.Snapshot.Restore.NoDanglingStoredHandles
  Ck.VoiceChat.Net.HybridRenderMode
  Ck.VoiceChat.Net.ModerationMatrix
  Ck.VoiceChat.Net.PlaybackConfig
  Project.Functional Tests.CkTests.AutoTests.AutoTests_CkTests_Level.Ck_AutoTest_Queue_ReserveDistanceRefreshPerf
  Project.Functional Tests.CkTests.AutoTests.AutoTests_CkTests_Level.Ck_AutoTest_Sway_ChildSceneNodeFollowsSwayedPose
Now passing (listed red in a plugin's file) — not pruned from here; if it holds in the plugin's home project, open a PR there (3):
  Ck.AggroDebugger.Authored.PIE  [Plugins/CkTests]
  Ck.Jolt.Cook.Inspector.Authored.ModuleLifecycle  [Plugins/CkGameplayDebugger]
  Ck.UiAuthoring.StyleLab.Window  [Plugins/CkGameplayDebugger]
Listed flaky, passed — if it keeps passing, remove the entry (14):
  Ck.EcsDebugger.AuthoredWindow
  Ck.GoapDebugger.SearchTrace.Authored.PIE  [Plugins/CkTests]
  Ck.Jolt.Body.Lifecycle.ChurnThousandReturnsToBaseline  [Plugins/CkTests]
  Ck.ResourceInspector.Activity.History  [Plugins/CkTests]
  Ck.ResourceInspector.Dialog.NativeScenarios  [Plugins/CkTests]
  Ck.ResourceInspector.PinnedSnapshots.NativeRepeat  [Plugins/CkTests]
  Ck.TextureDebugger.AuthoredWindow  [Plugins/CkGameplayDebugger]
  Ck.UiAuthoring.SchedulerDebugger.Inspector.AuthoredComposition  [Plugins/CkGameplayDebugger]
  Ck.UiAuthoring.StyleLab.InputHudAuthored  [Plugins/CkGameplayDebugger]
  Ck.UnrealComponent.TransformPropagation.DirtyOwnersOnly  [Plugins/CkTests]
  Project.Functional Tests.CkTests.AutoTests.AutoTests_CkTests_Level.Ck_AutoTest_GroundNav_Link_TraversalHandshakeFiresExactlyOnce  [Plugins/CkTests]
  Project.Functional Tests.CkTests.AutoTests.AutoTests_CkTests_Level.Ck_AutoTest_ProceduralAnimation_SpiderInteractiveRosterDiagnostics  [Plugins/CkTests]
```
**Attribution of the 71 NEW failures** (none is a PantryRat / RatDen / PantryRaid test; every one of my 34 tests passed in this gate):
- They fall in two symptom classes. (a) An expected Warning/ensure line counted fewer times than the test requires (`Expected ('Warning')
  level log message ... to occur 2 times ... found 1`, or `1 times ... found 0`) - 59 such lines in the gate log, across pure C++
  framework suites (CkChain PathHistory/DistanceConstraint, CkGroundNav, CkCrowd, DebugScene, ...) and the Mars tests
  `HitZone_HurtboxRegistration`, `KeyLock_ATransferThatFailsBroadcasts`, `LanternHook_ARequestThatFailsBroadcasts`,
  `LanternHook_TwoRefuelsInOneDrainKeepTheSecondTallow`. (b) `CkUsf reload rejected: shader source is absent or unreadable
  [/CkUsf/ReloadTest_...]` logged into unrelated Mars tests (`CuttingStation_SweepWithoutATrayIsRefused`, `DamageDealer_FriendlyFireRejected`,
  `FryStation_ATakeOutThroughTheIntentIsCappedByTheTray`) while the CkUsf reload tests ran in another lane (`CkUsf.NiagaraSpriteContract  (editor died mid-test)`).
- Run alone (`phase4-attr01-*`, 06:03-06:09 UTC, default list): `Ck.Chain.PathHistory.Trim_KeepsAtLeastTwoAndCoversDistance` **red alone**
  (same "2 times ... found 1" message) - a C++ CkChain unit test no Mars script can reach: pre-existing in this tree, not mine (confirmed by
  construction). `Mars_AutoTest_HitZone_HurtboxRegistration` **red alone** (its three expected `ck::EnsureIfNot` messages found 0 times;
  `Script/ECS/HitZone/*` and its test are untouched since 4dd7f082, 2026-10-22). `Mars_AutoTest_KeyLock_ATransferThatFailsBroadcasts`
  **green alone** (in-suite only).
- Prime suspect for class (a), inferred and NOT confirmed: the ensure display / de-duplication policy of this tree - the CkFoundation
  submodule's working copy has `Content/CkEditorOnly/EnsureDisplayPolicy_CkEditorTools_EUW.uasset` modified (plus CkUsf generated looks)
  and CkTests has an untracked test source; none of that is mine (I edited nothing under `Plugins/`). A repeated ensure logged once
  matches every "2 times ... found 1". Class (b) is lane-crossing contamination by the CkUsf reload tests' temp shader files (inferred).
  I did not A/B by reverting my change: it is untracked work in the live editor and removing it would delete classes and rewrite the
  AutoTests map through the populator. **Not proven "not mine" for the four Mars class-(a) tests beyond: they fail the same way as a C++
  test that cannot involve my files, and none of their code paths is in my diff.**
- `Still red (listed)` (36) includes the two Eyes known reds by name; `Now passing` (23 root + 3 plugin) and `Listed flaky` blocks are
  above verbatim; I did not prune the list (the brief gives no list edit; `--known-reds prune` is a separate commit for the owner).

### Findings (each reproduced before the fix)
- F4-1 The drain/Tick broadcast only the pass's net phase change, so a FleeWithLoot -> Dying -> LootReleasePending pass never reported
  Dying (run01: three tests saw 0 Dying transitions; lane log lines in `phase4-evidence-lanelines.txt`). Fixed with the step trail.
- F4-2 The `Mars_Primary` cheat (resolver StartIntent alone) starts no interaction: the IntentToResolver task also starts the best
  target itself. 30+ bot presses in PIE runs 04-05 logged `swing [None] dealt [0]` with `best primary targets [1]`; forwarding the target
  as the task does made the first press kill (run06 `04.28.34 the chef's strike was DEALT`). The cheat's docstring ("as the Primary key
  does") is wrong for held-item use - a one-line follow-up for its owner, not changed here.
- F4-3 In a rendered court the den's shell (BlockAll, open complex collision) bakes into the ground field as open faces
  (`CkGroundNav: Warning: GroundNav bake found [1] static body with OPEN collision`, 04.13.53) and the rat's ExitPortal / OutsideStand /
  ReturnAdmission are off the field (`refused a Home move ... provider [NoSurface]` looping, runs 01-02). The headless lanes never saw it
  (no den mesh headless). The court spawns the shell NoCollision (D4-3); the shipped default is unchanged - **a real level placing this
  den will hit the same NoSurface loop** until the shell gets a closed collision or the portal markers move clear of it.
- F4-4 With a second pack spawned at (300, 450) (return10), residents emerge, find no target view and return 2 s later, and the raid
  emerges the next one 4 s after: an emerge/return churn (ops 3..14 in 45 s, log `04.39.08`-`04.39.57`). The raid arms on scent + an
  eligible slot but does not require a provider route from the den to the slot's work point, which the rat's target view does (inferred
  cause, not confirmed: the work point near that pack is unreachable). Follow-up: emergence should require the same reachability the
  rat's target view requires (spec section 7 item 4).
- F4-5 The DenEnter crouch plays in place at the ReturnAdmission marker (48 cm in front of the arch), so the return dither happens
  outside the den mouth (`return10/frame_016.png`), not inside it. The kernel never moves the rat through the portal. Follow-up for
  the planner: a short move through the portal before the fade, or a marker inside the arch.

### Deviations
- D4-1 `Mars_PantryRat_AnimInstance.as` moved beside the entity script (brief-named, additive move).
- D4-2 The chef is driven by a bot on the court director, not by keyboard/mouse: movement and look through the InputIntents requests the
  Move/Look handlers send, presses through the resolver as the IntentToResolver task does (Enhanced Input injection of held axes flickers
  per the CkGauntlet spec's injection note; the brief's own warning that injected presses do not reach CkIntent rows). Everything below the
  input layer - CharacterMovement at MaxWalkSpeed, the held-item use, the Strike task's sweep, the DamageDealer, the HitZone - is the
  real game path. R15 is therefore "bot-driven player input", not a human.
- D4-3 The court's ground field bakes a rat-sized capsule (radius 20, half-height 22) and the court's den shell is NoCollision (F4-3);
  new `ShellCollisionProfile` spawn param on the den script, default BlockAll.
- D4-4 The cleaver is given by the `Mars_Give` path (hotbar slot add + select), not picked up from the floor.
- D4-5 Flee scoring implements items 1-4 of spec section 8 (portal keep-out, chef clearance, playable floor = the ring inside the
  bounds, route separation from the nearest pursuer); item 5 (a turn / occluder bonus) is not implemented.
- D4-6 `Get_RouteSeparation` and the 5-parameter `Get_IsRouteClear` overload exceed the 3-parameter rule (the Phase 3 4-parameter
  `Get_IsRouteClear` already did); not packed into a query struct.
- D4-7 R16 (c) is the real strike issued while the rat's Claim is queued or in flight; only the "claim drained first" order was observed
  (the inventory commits in the drain's frame), so the HandleDied-during-ClaimTransfer branch remains code-only.
- D4-8 The court's two residents both raid; the story chases the Mushroom's thief (`Review_RatHasMushroom`, falling back to any loaded
  rat after 20 s); the second thief (the Monk's Rind) keeps fleeing (R12 behaviour, observed in story08/09 logs).
- D4-9 The PIE "repeat on the reloaded map" is reload12 (the court map unloaded by opening the Phase 2 review map, then opened again
  from disk); the map was never dirty after its 04:07 save (`list_dirty_packages` 0 before every PIE), so no `save_loaded_asset` call was needed.

### Not verified / open
- X eyes in PIE: the corpse's head was under the chef in every captured corpse frame (story08 073-076, story09 76-82). R20 rests on the
  headless CPD readback (cells 20/20 on the real body primitive) and Phase 2's static `eyes_front_XEyes.png`.
- The mouth carry is seen once from above (`story08/crop_mouth_068.png`): plausible (cap under the snout); no side view, so the exact
  jaw contact and the bulky `k_DragRest` are not judged. No re-parenting to the `Carry_Mouth` socket was needed for that frame.
- The topple clip is seen in story09 (rat on its side, belly up, `crop_corpse_080.png`); whether it is the RIGHT side's authored clip
  visually (vs Left) is not judged from frames, only from the log line.
- The picked-up Mushroom: the log proves it is in the player's hotbar slot, carried by the player; the external review camera shows a
  Mushroom near the floor afterwards (story09 frames 86-96) - most likely the first-person hold seen from outside (inferred).
- Two rats fading side by side in PIE (R24 visual) was not framed; R24 rests on the headless CPD readback.
- Fun / feel of the chase; real keyboard input; gait foot slip at 320 cm/s; den eyes' look/blink quality.
- Multiplayer (R30 BLOCKED). The emerge/return churn (F4-4) and the outside-the-mouth dither (F4-5).

Claim most likely wrong: that the strike in PIE is "the player's real attack". Everything after the press is the real path, but the
press itself is my bot's forwarding of the resolver's best target, modelled on `Forward_To` in the IntentToResolver task; if a human's
click goes through any other gate (an input-layer matcher row, a CkIntent hold condition) the bot would not exercise it, and R15's
"catchable on walk alone" was measured with a perfectly aimed, instantly turning chef.

Editor state left (06:12 UTC): the Phase 2 review map open again (as found), `list_dirty_packages` 0, no PIE. Nothing committed, nothing
pushed; HEAD still 2154da26; no file under `Plugins/` edited by me, no production map touched.
