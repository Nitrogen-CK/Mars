# Pantry Rat R02 - PROGRESS

Executor record for `R02_BRIEF.md`. Every claim is **confirmed** (evidence named) or **inferred**. Deviations are DR-n.
Owned root: this folder only. Nothing committed, no git command run, nothing imported, no Monolith call, nothing under
`Content/` or `Script/` written, nothing under `../pantry_rat_r01/` edited (only read and copied from).
Blender 5.2.2 LTS, `-b --factory-startup` background processes only.

Status: **R7 touch-ups done after the planner ACCEPTED hand-back 2 for import.** Hand-back 1 (R1 + R2) -> GO + R2e;
hand-back 2 (R3-R6) -> accepted with one touch-up round R7 (eye patch shape, nose front, three clips). Final pipeline
`review/round_07c_pipeline`. Nothing imported into Unreal; the import script is prepared, not run.

## Rerun (from this folder)
```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup --python scripts/sheet_measure.py                              # once: sheet-02 crops, swatches
"$B" -b --factory-startup --python scripts/compare_sheet.py -- --round NN --no-save       # model-only compare round
#   (without --no-save it overwrites source/PantryRat_R02.blend with the harness scene - run the pipeline after it)
#   --calibrate-hero   refit the hero camera (done once on round 01; the result is frozen in compare_sheet.py HERO)
bash scripts/run_pipeline.sh review/round_07c_pipeline   # (final run) build -> animate -> dither UV -> RIG.json -> export -> round trip
                                               #   -> reopen -> den check; stops at the first non-zero exit
"$B" -b --factory-startup source/PantryRat_R02.blend --python scripts/pose_compare.py -- --out review/round_07c_poses
# Unreal (NOT run; the planner runs it after the Phase 4 executor releases the editor): scripts/pantry_rat_import_ue.py
#   part_a | socket_plan | part_b | save | readback  via Monolith editor_query run_python, as R01 PROGRESS Phase 2 lists
```
`compare_sheet.py` refuses to write into a non-empty `review/round_NN/` (earlier rounds are never overwritten). Each run
prints `PANTRY_RAT_OK` / `PANTRY_RAT_FAIL` and exits non-zero on failure. Last run: `--round 02d`, exit 0, `PANTRY_RAT_OK`, 5.6 s.

## Files
- `scripts/sheet_measure.py` - crops sheet 02 once into `review/sheet_crops/`, samples the swatches, `sheet02_measure.json`.
- `scripts/compare_sheet.py` - compare harness (scene, palette materials, floor + 10 cm grid, fixed cameras, EEVEE
  renders, Workbench silhouette masks, compare tiles, IoU, measured table, rest contacts, eye-UV numbers).
- `scripts/rat_model.py` - R02 geometry (new). Every shape number is in `P`; `S` is a uniform scale knob (1.0).
- `scripts/rat_skin.py` - R02 bone rest layout for the frozen 26 bones + skin weights (max 3 influences).
- `scripts/rat_common.py` - from R01; R02 palette, `PART` + `jaw` 12 / `strap` 13, eye preview oval widened (review only).
- `scripts/build_pantry_rat.py` - R01's builder adapted (paths / names, R02 model + skin, R02 pose guards, drag-bite solve,
  tail mesh guard, spoon fix also for "spoon lifts body"); den / cheese / props / pose language are R01's code.
- `scripts/animate_pantry_rat.py` - R01's clip author adapted (R02 paths, rest heights, strap-fit also for "spoon lifts
  body", the bound keys re-authored on the R02 body against the sheet-04 row).
- `scripts/dither_uv_pantry_rat.py`, `export_pantry_rat.py`, `validate_roundtrip.py` (+ face-normal check),
  `reopen_check.py` (+ 34 clips, flat faces, <= 3 influences), `pantry_rat_import_ue.py` (R02 paths / palette; NOT run),
  `rat_render.py` - R01 copies with R01 -> R02 names / paths.
- `scripts/pose_compare.py` (sheet 04/05/06/03 pose set + bound contact sheet), `den_check.py` (clearance against the
  copied R01 den mesh), `write_rig_json.py`, `run_pipeline.sh`.
- `scripts/r01_*.py` - untouched verbatim copies of the R01 scripts (reference).
- `RIG.json` (R02 rest heads / tails; names / parents == `RIG_R01.json`, the frozen copy of R01's).
- `source/PantryRat_R02.blend` - the rigged, animated, dither-UV'd source (pipeline output).
- `export/` - `PantryRat_R02_Mars_SK.fbx`, `anims/PantryRat_R02_<Clip>_Mars_ANIM.fbx` x34, den / plate / cheese statics,
  `PantryRat_R02_Manifest.json`, `validation/`, `anims/{clips,expected_anims,roundtrip_report}.json`.
- `review/round_NN/` per round (renders, masks, compare sheets, metrics); `review/round_05/` (build measurements, anim
  report, clip table, den check), `review/round_05b/` + `review/round_06_poses/` (pose set, contact sheet),
  `review/round_06/` (pipeline logs), `review/den_ref/` (copied R01 den FBX), `review/r01_reference/`.

## Compare harness
Layout of `compare_02.png`: three rows, two views per row, each view as three tiles **sheet crop | R02 render | overlay**;
row 1 front, right side; row 2 rear, hero; row 3 top, underside. Overlay = the render at 45 % with the **sheet**
silhouette edge in red and the **model** silhouette edge in cyan. `compare_<view>.png` is one view's three tiles at full
size (2x the crop resolution).

Calibration (sheet px, from `sheet02_measure.json` and the column profiles) **confirmed** (numbers in `compare_sheet.py`):
| view | camera | px/cm | anchor |
|---|---|---:|---|
| right side | ortho, from -Y | 6.6 | back top y 205 -> floor y 438 = 35 cm; world x 0 = sheet x 675.5 (nose 871 / rump 480 centre) |
| front | ortho, from +X | 6.66 | whole-silhouette height ratio front/side 1.01; floor y 440; body centre x 198 |
| rear | ortho, from -X | 6.6 | floor y 440; body centre x 1048 |
| top | ortho, from +Z, nose up | 5.55 | nose y 548 = world x 29.6; nose-to-rump 324 px = side's 59.2 cm |
| underside | ortho, from -Z, nose up | 5.5 | as top; floor hidden |
| hero | perspective, lens 50 | - | az 31.67 deg (from the right side toward the front), el 2.70 deg, dist 112.0 cm to (0,0,18), shift (-0.0522, 0.0117) |
The hero camera was fitted once (`--calibrate-hero` on the round-01 model) by Gauss-Newton on six landmarks read off the
sheet hero (nose tip, both eyes, near fore/hind toes, far fore toes); residual rms 22.7 crop px, largest the far eye
(-32.7 px) and the near fore toes (-28.3 px) **confirmed** (printed by the calibration run). Frozen since; rounds 01-02d
all used the same six transforms.
Sheet silhouette = `(sat > 0.14) | (max < 0.56)` + 3x3 opening. The contact shadow measured sat <= 0.119, max >= 0.676, so
it is excluded; the first two thresholds tried (0.12 / 0.55 included shadow specks; 0.45 punched holes in dark facets)
were discarded after looking at the overlays. Lighting: world = the sheet background colour at strength 0.55, four
world-fixed suns (key front-right-above 3.2, fill left 1.1, rim behind 1.8, a weak 0.6 underside fill), EEVEE 32 samples,
Standard view transform.

## Palette (sRGB hex) **confirmed** for the swatches (`sheet02_measure.json swatch_hex`, median of a 20 px disc)
| slot | hex | source |
|---|---|---|
| Body | #694B59 | sheet-02 BODY swatch |
| Pink (ears / nose / tail / paws) | #EE8082 | PINK swatch |
| Belly | #EDC9AA | BELLY swatch |
| Wood (spoon) | #A76038 | SPOON swatch |
| Amber (eyes, preview only) | #FEC534 | AMBER EYES swatch |
| Harness | #9A5B44 | R4: median of the sheet's brown strap pixels (side strap #A26346, top girth #885139, rear band #9E5F47) **confirmed** (sampler run); R1-R4 renders used the placeholder #7A4728; the final compare `round_06b_final` and the pipeline output use #9A5B44 |
| EyePatch | #5A3F4D | R2e planner ruling (near-Body, slightly darker); the engine EyePlate look's patch base colour must be matched at import |
Swatches are lit spheres, so these are lit mid-tones used as flat base colours. Faces carry +-5 % per-facet jitter.

## Deviations
- **DR-1 (ACCEPTED by the planner at hand-back 1) Proportions follow the sheet drawing; the 65 cm nose-to-tail number
  does not hold.** The sheet's drawing and its "35 cm shoulder / 65 cm nose to tail" labels disagree (489 px long vs 233 px
  high to the back): anchored on the 35 cm back, keeping the sheet's height/length ratio (R02 0.62, sheet 0.60, R01 0.86).
  Final: curled rest footprint (nose to curled tail tip, mesh X extent) **75.9 cm**; **straightened** (nose to tail root
  58.3 + tail 27.6 along the curve) **~85.9 cm** - the planner's audit called 75 "nose to straight tail tip"; 75.9 is the
  curled footprint, the straight length is ~86 (flagged: if 75 straight was meant, shorten the tail ~10 cm via
  `rat_model.P["TAIL"]`). Knob for everything: `rat_model.S` / the `LOFT` x stations.
- **DR-2 Withers.** R01 measured "withers" as the torso top over the shoulder joint; R02's back peaks mid-back like the
  sheet's, so that measure is 33.4 (build, +-2 cm window) / 33.4 (harness, +-3) while the back top is 35.2.
- **DR-3 Spoon placement / den.** The straight spoon is tangent to the round flank, so its handle end stands off the lower
  flank (as in the sheet front view). The 26 cm handle put that end 22.6 cm off the axis in the den crouch (arch clearance
  7.4 < 8): handle shortened to 23 cm and the end target moved in (`SPOON_END`), slide direction more vertical; den
  clearance now 9.32 (DenEmerge / DenEnter, against the R01 den mesh). Bowl centre (-4.3, -11.3, 38.4), height 44.45.
- **DR-4 Spoon side.** Front, side, rear and hero views put the handle down the RIGHT flank; the top view draws it toward
  the LEFT hip. Kept right (4 views to 1). R01 had it right-shoulder-to-left-hip.
- **DR-5 Look-back direction** kept R01's ruling (toward the rat's LEFT, away from the bowl); sheet 05 panel 5 turns the
  head toward the viewer (the spoon side). Yaw 70 deg total (R01 45) - the largest <= 70 with the carried proxy >= 2 cm off
  spoon and chest and the harness within 0.2 cm.
- **DR-6 Iteration count.** R4 took five renders (04-04c on the axis, 04d-04e forced by the R5 den audit) - over the
  three-iteration rule; disclosed here rather than hidden.
- **DR-7 Gate edits in the copied R01 scripts** (all in R02 copies, R01 untouched): pose / clip spoon fixes also accept
  "spoon lifts body" (the right-flank spoon lands first in the right topple); the tail mesh guard pitches tail_01 up until
  no tail vertex is below 0.3 cm (the curled rest tail sags between joints); audit groups treat the whole loft as torso
  (the chest front is head-tagged past x 10); the R5 budget gate is 5000 tris (> 5000 = deviation per the brief).
Import-time checks the planner owns (not changed here; **inferred** impact):
  `Script/ECS/PantryRat/Mars_PantryRat_Utils.as:21` `k_AgentRadius = 25.0f` vs the nose 30.7 cm ahead of the root (R01 ~23)
  and a 75.9 cm footprint; R01's `export/unreal_withers.json` / Phase 2 readback withers band (35.3 +- 0.5) assume R01's
  body - R02 reads 35.2 as back top but 33.4 over the shoulder; the court / den markers and Phase 3/4 kernels were tuned
  on R01's length; Carry_Mouth / Carry_Drag offsets changed (see the manifest).

## Measured table - FINAL (pipeline output: `review/round_05/build/measurements.json`, `review/round_06b_final/metrics.json`, `export/anims/roundtrip_report.json`, `review/round_05/den_check.json`) **confirmed**
| quantity | target | R02 final | R01 |
|---|---:|---:|---:|
| back top (torso max z) | 35 | 35.2 | - |
| withers (torso max z over the shoulder joint, R01's measure) | 35 | 33.4 (DR-2) | 35.26 |
| nose to tail tip, curled rest footprint (mesh X extent) | 65 (DR-1 accepted) | **75.9** | 65.0 |
| nose to tail tip, tail straightened (nose to tail root 58.3 + tail 27.6) | - | **~85.9** (see DR-1) | - |
| nose to rump (loft, tail excluded) | - | 56.9 | 40.7 |
| trunk (rump to neck x 7, no head / tail) | ~40 | 36.9 | - |
| body width (torso Y) | ~30 | 31.0 | 29.7 |
| width incl. legs / ears / spoon | - | 40.1 | 32.6 |
| height incl. spoon | <= 65 | 44.45 | 46.8 |
| den clearance (DenEmerge / DenEnter vs the R01 den mesh) | >= 8 | **9.32** | 12.65 |
| tris / verts | 3000-4500 | **3092 / 1658** (R7: +16 nose tris; 3076 / 1650 before) | 2086 / 1130 |
| influences | <= 3 | **3** (0 unnormalised, 0 unweighted) | 3 |
Per slot: Body 1274, Pink 850, Belly 72, Wood 144, Harness 716, EyePatch 20. Rest contacts (06b_final): spoon-torso 0
overlaps / 0.8 cm, spoon-ears 0 / 5.5, ears embedded in the skull, girth-spoon 0 / 0.36, breast strap-spoon 0 / 0.36,
strap vs fore upper limbs 44 overlapping pairs (the legs cover it), jaw-nose 16 pairs (the chin tucks under the nose dome).

## IoU of model vs sheet silhouette per round (`metrics.json iou`) **confirmed**
| round | front | right | rear | hero | top | underside | tris |
|---|---:|---:|---:|---:|---:|---:|---:|
| 01 | 0.708 | 0.799 | 0.708 | 0.666 | 0.885 | 0.865 | 2184 |
| 01b | 0.735 | 0.858 | 0.735 | 0.683 | 0.869 | 0.852 | 2172 |
| 01c | 0.757 | 0.848 | 0.744 | 0.683 | 0.871 | 0.860 | 2172 |
| 01d | 0.752 | 0.837 | 0.750 | 0.674 | 0.915 | 0.877 | 2176 |
| 02 | 0.774 | 0.834 | 0.769 | 0.684 | 0.906 | 0.884 | 2258 |
| 02b | 0.776 | 0.832 | 0.772 | 0.681 | 0.906 | 0.885 | 2258 |
| 02c | 0.776 | 0.832 | 0.772 | 0.680 | 0.906 | 0.885 | 2258 |
| 02d | 0.770 | 0.832 | 0.771 | 0.683 | 0.907 | 0.885 | 2258 |
| 02e | 0.763 | 0.843 | 0.747 | 0.686 | 0.894 | 0.873 | 2276 |
| 03 | 0.753 | 0.834 | 0.737 | 0.675 | 0.896 | 0.872 | 2680 |
| 03b | 0.756 | 0.836 | 0.739 | 0.678 | 0.894 | 0.871 | 2680 |
| 04 | 0.759 | 0.840 | 0.743 | 0.679 | 0.891 | 0.877 | 3160 |
| 04b | 0.745 | 0.831 | 0.732 | 0.680 | 0.890 | 0.880 | 3224 |
| 04c | 0.742 | 0.834 | 0.729 | 0.678 | 0.887 | 0.881 | 3076 |
| 04d | 0.750 | 0.825 | 0.740 | 0.659 | 0.890 | 0.881 | 3012 |
| 04e | 0.750 | 0.825 | 0.740 | 0.663 | 0.885 | 0.883 | 3076 |
| 06b_final | 0.752 | 0.823 | 0.742 | 0.663 | 0.892 | 0.883 | 3076 |
| 07 | 0.752 | 0.822 | 0.742 | 0.663 | 0.892 | 0.883 | 3092 |
| 07b | 0.752 | 0.822 | 0.742 | 0.664 | 0.891 | 0.883 | 3092 |
IoU is a guide, not the verdict: the sheet's spoon lies across the other shoulder in the top view and the hero drawing is
chunkier than any one camera can match, so neither view can reach 1.

## Round verdicts (every compare sheet named here was opened and looked at)

### R1 Silhouette - `review/round_01d/compare_02.png` (iterations `round_01`, `01b`, `01c`, `01d`)
- 01 (first model off the sheet profiles: one superellipse loft rump-to-snout, pear sections, flat belly, upper-limb
  masses, curled tail, spoon tangent to the flank): side and top already read long and low; legs were thin stilts with
  daylight under the body, the spoon stood far off the flank.
- 01b: belly lowered 1 cm, leg masses lower and fatter, tail droops steeper, spoon targets lowered: side IoU 0.80 -> 0.86,
  legs merge with the body; the spoon slid 8.6 cm out (floating).
- 01c: spoon bowl target moved over the right shoulder: slide 4.7 cm, binding contact on the upper flank (-7.3,-14.2,24.6);
  the handle end stands 6 cm off the lower flank as in the sheet front view (sheet y -20.7, model -21.3).
- 01d: haunch narrowed and moved forward (it stuck out of the top-view egg), fore paws tucked: top IoU 0.87 -> 0.915.
- **Verdict (side + top):** snout wedge length, skull height, the hump-backed body with its rump curve, belly line and
  tail taper now sit on the sheet outline (side overlay: red and cyan coincide on the back, rump, head and snout).
  **Still differs:** (1) the sheet's spoon leans ~28 deg back along the near flank; ours is right-shoulder-to-hip but
  rises 2.5 cm higher (bowl centre z 38.3 vs ~36) because a straight spoon must clear a 31 cm round back. (2) The top
  view draws the handle toward the rat's LEFT hip; front, side, rear and hero put it on the RIGHT flank - kept right
  (4 views to 1). (3) Tail: the sheet's starts higher and thicker and curls tighter under itself. (4) Legs are still
  blobs-on-tubes (R3). (5) The cream belly shows from the side (R4 paint). Three iterations used; axis closed.

### R2 Head - `review/round_02d/compare_02.png` (iterations `round_02`, `02b`, `02c`, + `02d` defect fix)
- 02: wider cheeks (hw 11.4 at the skull), snout stations boxier on top (superellipse n 3.2-3.8 = a flat bridge plane
  with crisp shoulders), mouth line raised and a separate **jaw** wedge below it (part tag `jaw`, hinge near x 13.5),
  a pink **nose block** with a flat front disc and two dented nostrils, **eye facets**: head vertices within 4.4 cm of each
  eye centre pressed onto a plane (normal (0.55, +-0.82, 0.14)), the patch a planar heptagon 0.2 cm proud of it, R01 UV
  convention kept verbatim; ears centred lower-back and facing more forward.
- 02b: nose raised to the top of the snout end, head-underside cream only on faces pointing down (n.z < -0.85), ears up.
- 02c: nose profile rounded (widest ring 1 cm behind a bevelled disc).
- 02d (defect, found by the rest-contact audit, not by eye): the ears floated 0.66 cm off the skull; ear centre moved
  in 1.2 cm (y 12.8 -> 11.6) -> ears embedded, spoon-ear gap 0.76 cm. Front IoU 0.776 -> 0.770 (ears less wide).
- **Verdict (front, hero, side):** the head now reads as a rat's: wedge snout 0.41 of the head from the eye (the eye sits 1.6 cm forward of the sheet's), flat
  bridge, separate jaw with a visible mouth line, pig-disc nose with nostrils, flat eye facets, angular ears set back on
  the skull. **Still differs:** (1) front view: the sheet's ears sit wider (outer edge y 18.6, ours ~17) and face the
  viewer more squarely; tilting them out further would bring them back without un-embedding. (2) Hero: the sheet's head
  is shorter and rounder relative to a much bigger body mass; our snout reads longer there (the side view matches, so
  this is mostly the drawing's perspective). (3) The nose still reads as a short plug in the hero, not the sheet's soft
  dome. (4) A cream strip runs along the mouth line and under the chin/chest in front and hero (belly paint; R4 owns the
  belly-plane boundary). (5) The dark eye patch is larger than the amber eye the preview shader draws inside it; the
  engine look decides the eye size, the patch only bounds it. R2 used three iterations plus one defect fix; axis closed.

## Hand-back 1 audit (planner rulings, as applied)
GO to R3-R6 with one more head iteration (R2e) first. DR-1 ACCEPTED (35 cm height anchor, the sheet's height/length
ratio). Rest tail modelled with the sheet's curl (tip back toward the rump); report straight length and curled footprint.
Gameplay follow-ups recorded as import-time checks (below); nothing under Script/ touched.

### R2e Head (one iteration) - `review/round_02e/compare_front.png`, `compare_hero.png` (looked at; `compare_02.png` beside them)
Changes (all in `rat_model.P`): skull top raised to 32-33 cm at x 5.6-11 (within ~3 cm of the 35.2 back, flowing into the
shoulder), cheeks / jowls bulked (half width 12.6 at the skull, wide point lowered to z 18); eye patch a forward-facing
almond 1.5x (9.6 x 8.8 cm, front tipped down 14 deg) on a larger flat facet (radius 5.6) whose normal faces front-side
(0.64, +-0.75, 0.16) - fully visible from the front view; EyePatch preview colour #5A3F4D (near-Body) and the preview
amber oval widened to fill most of the patch (`rat_common.make_material`, review-only node tree); nose a 9 cm wide dome
(apex 0.7 cm proud, nostrils dented); the jaw extended to a chin under the nose (no cream on the jaw); ears lower on the
skull sides (centre z 30.2) and leaning out (up axis (-0.22, 0.62, 0.76)) so their outer edges pass the body width.
**Verdict (looked at front, hero):** head mass now reads as one block with the shoulder; eyes are big amber almonds visible
from the front like the sheet; ears now pass the body width. **Still differs:** the nose reads as a pink box from the
front rather than the sheet's soft dome; the amber eyes read rounder and slightly larger than the sheet's tall ovals; the
sheet's head is chunkier in the hero (drawing perspective). Eye patch UVs re-verified numerically in R4 (below).
Import-time check: the engine EyePlate look's patch base colour must be set to match #5A3F4D (the R01 master was authored
against a near-black patch) - noted in `scripts/pantry_rat_import_ue.py` beside `RAT_COLORS`; not done here.

### R3 Limbs + feet - `review/round_03b/compare_02.png` (iterations `round_03`, `03b`)
Three readable segments per leg (sheet 03 "LEG (SIDE) - STRUCTURE"): upper limb = shoulder / haunch mass tapering into a
knee / elbow knob; lower limb = hexagonal shin ending in a heel / wrist knob; pink paw pad + separate toes, **4 fore /
5 hind** (hind outer toe set back). Elbow points back, knee forward (matches the R01 IK poles). Stance from the sheet
underside: fore paws |y| 11.0, hind 11.8. 03b: paws and toes 20-30 % larger (03 read as thin slabs).
**Verdict (side, hero, underside, front):** hip / knee / foot read on every leg; toes countable from below and from the
front. **Still differs:** the sheet hides more of the legs under the body bulk (its forelegs barely show); our fore
shins read as short columns in the front view; the sheet's toes are rounder "beans". Two iterations.

### R4 Spoon, harness, paint - `review/round_04e/compare_02.png` (iterations `04`, `04b`, `04c`, `04d`, `04e`)
- Belly: cream is now one clean loop along mesh edges (a face is cream only when all three vertices lie in the bottom
  sector, half-angle 56 deg mid-body tapering to 0 at the chest x 9.5 and under the tail root x -25.5) - no isolated
  dark triangles; cream starts at the chest, never on the jaw or the mouth line. 72 cream tris.
- Harness: girth (closed, crosses the handle at the spoon's flank contact so it straps the spoon down; lift over the
  handle 4.0 cm) + one diagonal breast strap (open arc from the strap point 0.82 along the handle, round the front of
  the chest under the neck, to the girth low on the left flank). Leather cuffs on the handle where both cross it + one at
  the neck. Harness colour: rounds 04-04e still rendered the #7A4728 placeholder; after R4 it became #9A5B44 = median of the sheet's
  strap pixels (side strap #A26346, top girth #885139, rear band #9E5F47); `round_06b_final` and the pipeline use it.
- Spoon: bowl about ear-sized (12.8 x 10.4 cm), its face tilted toward the hero camera (concave normal (0.62, -0.74,
  0.25)); handle shortened 26 -> 23 cm (total ~38, sheet ~37) and its end target moved in - **04d/04e were forced by the
  R5 den audit** (the standing handle end stood 22.6 cm off the axis: arch clearance 7.4 < 8); now 9.32.
- Eye UVs (numbers, `review/round_06_final/metrics.json eye_patch_uv`): LEFT patch U 0.000..0.500, RIGHT 0.500..1.000,
  V 0..1 both; corr(U, x) = +0.993 on the left (back -> front) and -0.993 on the right (front -> back); corr(V, z) = 1.0.
  `convention_holds: true` **confirmed**.
**Verdict (hero, front, underside, top):** the spoon's bowl face shows in the hero, the breast strap runs from the spoon
forward across the shoulder as the sheet's side / hero do, the belly loop is clean. **Still differs:** the sheet's strap
reads horizontal across the shoulder (ours slopes down to the chest); the girth tents ~4 cm over the handle; the strap
passes under the forelegs (44 overlapping tri pairs with the upper-limb masses at rest - the legs hide it); the sheet's
top view still puts the spoon on the other diagonal. R4 took five renders: 04-04c on the axis, 04d-04e den fixes (over
the three-iteration rule - disclosed, not hidden).

### R5 Rig + clips - `review/round_06_poses/pose_set.png`, `review/round_06_poses/boundcycle_contact.png`
Rig: the 26 bones of `RIG_R01.json` - names, parents, roles identical (`RIG.json names_parents_match_R01: true`, build rig
check 26/26, root rest identity); rest positions moved onto the R02 body (`rat_skin.bone_layout`). Carry_Mouth /
Carry_Drag Empties on `jaw` (Carry_Drag re-solved: the drag pose lifts the head until the jaw tip is 2.44 cm below the
bulky proxy's 25 cm top edge; R01 2.19). Skin: max 3 influences, 0 unnormalised, 0 unweighted, no stray groups; spoon +
cuffs 100 % spoon_prop, jaw 100 % jaw, eye patches 100 % head, ears 100 % ear_l / ear_r; straps take the barycentric
weights of the loft triangle under them (they ride the surface) blending to spoon_prop over the handle.
Clips: the same 34 names, frame counts and loop flags as R01's clip table (`review/round_05/clip_table.md`, column
"= R01 frames/loop": yes x34), 30 Hz, BoundCycle 12 frames = 0.4 s loop. Every key pose is an R01-language spec
(rotations, body slides, IK foot targets) re-solved by IK on the R02 rig every frame - not R01 curves replayed; the
bound (BoundCycle / LoadedBound / Start / Stop) keys were re-authored against the sheet-04 row (longer spine flex,
airborne stretch with fore reaching and hind trailing, gathered crouch, apex lift 9.5 cm / loaded 7.5).
Audits (every baked frame of every clip, `anim_report.json`): 0 bad frames across 34 clips; loop seams frame N == frame 0
on all 11 loops with the seam second difference <= the interior maximum; worst harness clearance -0.11 cm (<= 0.2 embed),
minimum spoon clearance >= 0; den portal clearance 9.32 cm on DenEmerge / DenEnter, and 9.32 against the R01 den MESH
(`review/round_05/den_check.json`: mesh opening profile = analytic 60 x 60 within 0.47 cm below the crown); planted
drift 0.000 on the non-locomotion IK clips. 7 clips needed one strap fit (TurnRight90, LoadedTurnRight, SniffAir,
StretchAttend, BoundCycle, LoadedBound: lift 0.3-0.6 cm; DeathToppleRight lift 1.0 / slide 6 / pitch -3).
**Verdict (pose set vs sheets 04 / 05 / 06 / 03, BoundCycle contact sheet - looked at):** topple and dead hold match
the sheets well (belly up, legs up, harness across the belly); rear + observe, snatch and carry read; the loaded bound
apex is airborne and stretched like sheet 05 panel 4; the BoundCycle frames 4-6 read as the sheet's push / low bound.
**Still differs:** stretch + check is less stretched than the sheet; the startle is a crouch without the sheet's turn;
look-back turns away from the camera (DR-5); the sheet's bound is higher and longer in the air; fore / hind stance speeds
differ in the bound (fore 40-54, hind 37-95 cm/s: foot slip at any single mover speed, R01 had the same class, 36-59);
the X eyes, startle eyes etc. are the engine look's job, the preview shows round eyes only.

### R6 Export - `review/round_06/pipeline_log.txt` (8 steps, all exit 0, each printed PANTRY_RAT_OK)
- `export/PantryRat_R02_Mars_SK.fbx` (LOD0 mesh + 26-bone armature, rest), `export/anims/PantryRat_R02_<Clip>_Mars_ANIM.fbx`
  x34, `PantryRat_R02_{Den,DenEyePlate,Cheese}_Mars_SM.fbx` (R01's den / plate / cheese code, re-exported), the manifest
  (bones, slots, bounds, clip contract, Carry sockets in the UE frame). Recipe = R01's (cellar-bat COMMON / BIND / CLIP /
  STATIC, `mesh_smooth_type="FACE"`), UV0 = R01's dense dither box projection (2954 faces), eye patch UVs unchanged.
- Round trip (`export/anims/roundtrip_report.json`, fresh scene per file) **confirmed**: 0 fails; bind 26 bones, names /
  parents exact, heads 6e-05 cm, 3076 tris, slots in order, bounds 0.00048 cm, max 3 influences, 0 bad weights, **every
  imported loop normal == its face normal (min dot 1.0) = flat shading survives**; Carry_Mouth / Carry_Drag rebuilt on the
  imported jaw within 6e-05 cm; 34 clips, 1 action each, landmarks within 0.00018 cm, root identity on every sample,
  loop seams 0.0.
- Reopen (`reopen_check.py`, fresh process) **confirmed**: 26 bones == RIG.json, slots in order, 3076 tris / 1650 verts,
  max 3 influences, 15 pose actions + 34 clip actions, 0 smooth-shaded faces, Carry frames on `jaw`, props present.
- Den (`den_check.py`, against the copied R01 den FBX) **confirmed**: DenEmerge / DenEnter min clearance 9.32 cm (>= 8),
  tightest at the spoon handle end (y -20.68, z ~12) against the jamb.
- Import script `scripts/pantry_rat_import_ue.py`: R02 paths (`/Game/ArtCandidates/PantryRat/R02/...`, `PantryRat_R02_*`),
  R02 slot colours; **not run**. Its sockets come from the manifest (`socket_plan` stage) as in R01.

## Hand-back 2 audit (planner) and R7 touch-ups
Planner: ACCEPTED for import after one touch-up round. DR-1 means the curled footprint (75.9 curled / 85.9 straight
stands, tail not shortened); DR-2..DR-7 accepted as recorded.

### R7 - `review/round_07b/compare_02.png` (+ `compare_front.png`, `hero.png` looked at), pose set `review/round_07c_poses/pose_set.png`, contact sheet `review/round_07c_poses/boundcycle_contact.png`
1. Eye patch: an upright almond / oval, 7.2 x 9.4 cm (1.3x taller than wide, soft points top and bottom), its top leaning
   16 deg back toward the ears (`EYE_RS` 3.6, `EYE_RU` 4.7, `EYE_LEAN` -16). The first R7 try (`round_07`) left the patch's
   upper corners 0.61 cm off the head (the build's patch-detach gate is 0.6 - every pose failed): the flat eye facet was
   widened 5.6 -> 6.6 cm (`EYE_FLAT`), detach back to the 0.2 cm authored offset (`round_07b`). UVs re-verified:
   LEFT U 0.000..0.500, RIGHT 0.500..1.000, V 0..1 both; corr(U, x) +0.986 / -0.986 (front high on the left, low on the
   right), corr(V, z) 1.0; `convention_holds: true` **confirmed** (`review/round_07b/metrics.json eye_patch_uv`).
2. Nose: one more (staggered) ring of facets between the bevel and the disc (radius 0.65 at +0.22 cm) - the dome's front
   face is rounder. Still octagonal in outline from the front (8 sides).
3. Clips (`animate_pantry_rat.py`): StretchAttend - chest / neck slide +2.8 / +1.2 cm on the phase-1 stretch, fore paws
   +4.5 cm further (13.5 cm ahead of rest, ~1.5x), neck / head pitched down 6 + 6 deg, hind paws planted. Startle - crouch
   + a 36 deg turn away (body 18 + chest 6 + neck 6 + head 6, toward the rat's left) + one backstep (fore_r and hind_l lift
   at f6 and land 3 cm back at f9). First variant (`round_07_poses`, body slid back 1.6 cm) left a planted fore paw
   drifting 0.054 cm (IK reach clamp); body slide reduced to 0.8 cm -> 0.000 (`round_07c`). BoundCycle / LoadedBound apex 9.5 -> 11.9 cm and 7.5 -> 9.4 (+25 %), apex paws raised
   with it. Frame counts, loop flags and the 0.4 s bound unchanged.
Audits after R7 (final pipeline `review/round_07c_pipeline/pipeline_log.txt`: 8 steps exit 0; `anim_report.json`,
`den_check.json`, `roundtrip_report.json`) **confirmed**: 34 clips, 0 bad frames; 11 loops with frame N == frame 0 and
seam second difference <= interior max; planted drift 0.000 cm on all 20 non-locomotion IK clips (Startle included);
worst harness clearance -0.114 cm (<= 0.2 embed); min spoon clearance 0.019; den 9.32 cm on DenEmerge / DenEnter
against the R01 den mesh; round trip 0 fails (3092 tris, face normals min dot 1.0, landmarks <= 0.00019 cm); reopen OK
(26 bones, 34 clips, 15 poses, 0 smooth faces, max 3 influences). Frame counts / loop flags still == R01 (BoundCycle 12
frames, 0.4 s loop). Strap fits unchanged in kind (7 clips, lift 0.3-1.0 cm).
**Verdict (looked at: `round_07b` front / hero, `round_07c_poses` pose set + bound contact sheet + startle shot):** the eye
reads as a tall leaning oval, not a coin; stretch + check now visibly reaches with the head low; the startle crouches,
turns its head away and steps back; the bound apex is higher with the legs stretched fore and aft. **Still differs:** the
nose outline is still octagonal from the front; the bound remains lower than the sheet's drawing; the look-back direction
stays DR-5.

## Not verified / open
- Nothing imported; the R02 assets have never been seen in Unreal (look masters, MI colours, the EyePlate patch base
  colour #5A3F4D, sockets, dither, PIE playback) - the planner's import step.
- The FBX recipe is R01's; that UE imports `mesh_smooth_type="FACE"` as hard edges everywhere is **inferred** from R01's
  accepted import, not re-checked for R02 (the Blender round trip proves the file carries face normals).
- Bound stance speeds differ fore (40-54 cm/s) vs hind (37-95 cm/s): foot slip at any single mover speed.
- 24 of the 34 clips were judged only by their audits, not looked at frame by frame (the pose set covers 10 shots and the
  two bound contact sheets); the R01 per-clip contact sheets were not regenerated (`animate --render` not run).
- Den clearance is a YZ cross-section audit with the rat centred in the portal (R01's method), now against the R01 den
  mesh's opening profile; a rat off-centre in the portal was not simulated.
- Gameplay consumers of the old body (agent radius 25, withers readback band, court markers) - listed under the
  deviations, not changed.
- The source of earlier rounds is only the per-round `metrics.json` params plus the script state at that time.

Note: `review/round_05/{anim_report.json, den_check.json, build/measurements.json, clip_table.md}` are rewritten by every
pipeline run (the scripts' REVIEW path); their current contents are the R7 final run's. The per-run logs are kept per folder.

Claim I would most expect to be wrong: that UE imports the R02 FBX with hard edges everywhere (flat look) as it did R01's -
proven only on the Blender side (every loop normal == face normal after the round trip).

## Phase 5 - R02 in the engine: import, script swap, F4-3 / F4-5 fixes, story re-captured (2026-11-07, DONE - awaiting planner audit)

Brief: `PHASE_5_BRIEF.md`. Branch dev, HEAD 2154da26; no git write command run; nothing committed or pushed; nothing under `Plugins/`
edited; no production map edited; R01 assets untouched (the R01 court / review maps were opened and played, never saved); no full gate.
Live MarsEditor through Monolith only; editor not minimised (`IsIconic` 0); dirty packages checked before the PIE runs (only the rat
eye-plate master, D5-1). Sources hashed 06:30:54 UTC.

### Files changed / new (an original copy of every pre-existing file was taken before its edit)
- `Shaders/Looks/PantryRatEyes.ush` - the patch base colour (D5-1).
- `Script/WorldObjects/Monsters/Mars_PantryRat_EntityScript.as` - mesh + clip paths R01 -> R02 (lines 57, 377).
- `Script/WorldObjects/Monsters/Mars_RatDen_EntityScript.as` - den + plate paths R02; F4-3: the shell built in `BuildShell` with the
  `Ck.Jolt.NoBake` component tag; `BuildShellHeadless` spawn param; `FMars_Fragment_RatDen_Assembly` back-pointer + `Get_Shell()`.
- `Script/Items/Mars_Item_PantryIngredients.as` - cheese path R02.
- `Script/Tests/PantryRat/Mars_AutoTest_PantryRat_{LookMastersResolve,CandidateAssetsReload}.as` - R02 root / names / manifest name.
- `Script/ECS/PantryRat/Mars_PantryRat_Utils.as` - `k_MouthRest`, `k_DragRest`, `k_AgentRadius` comment.
- `Script/ECS/PantryRat/Mars_PantryRat_Feature.as` - `HurtboxHalfExtents` default.
- `Script/ECS/PantryRat/Mars_PantryRat_Hfsm.as` - F4-5: ReturnEmpty's second leg ReturnAdmission -> den `Inside` (Creep) before DenEnter.
- `Script/ECS/RatDen/Mars_RatDen_Feature.as`, `Mars_RatDen_Utils.as` - F4-5: `EMars_RatDen_Portal::Inside`,
  `FMars_RatDen_Portals.Inside` (-26, 0, 0) + validation, `Get_PortalWorld` branch.
- `Script/Tests/RatDen/Mars_AutoTest_RatDen_EmptyReturnFadesHidesThenEmergesSolid.as` - extended (fade-start location in the arch).
- NEW `Script/Tests/RatDen/Mars_AutoTest_RatDen_ShellStaysOutOfTheGroundField.as` (F4-3 test).
- `Script/WorldObjects/Monsters/Mars_PantryRatReview.as` - court: NoCollision shell override removed; `Review_RatYaw` / `Review_RatFade`.
- NEW `scripts/pantry_rat_court_ue.py` (copy of the R01 court script: output `review/phase5`; `frame_start` rat-relative framing and
  dither slow motion).
- Written by the editor, not by me: `Script/Generated/Mars_EntitySpawnParams.as` + `Mars_AutoTestActors.as` (hot-reload regeneration,
  06:26:49 UTC) and `Content/Mars/Maps/AutoTests_Mars_MAP.umap` (CkAutoTest populator auto-save 06:26:54 UTC with the new test's
  actor) - all three already dirty from other sessions; do not stage blindly.
- Unreal (saved by name): `/Game/ArtCandidates/PantryRat/R02/{Meshes/PantryRat_R02_Mars_SK, Meshes/PantryRat_R02_Mars_SKEL,
  Materials/PantryRat_R02_{Body,Pink,Belly,Wood,Harness,Stone,Void,Rind,Flesh}_Mars_MI, Materials/PantryRat_R02_Prop_Mars_M,
  Animation/PantryRat_R02_<Clip>_Mars_ANIM x34, Props/PantryRat_R02_{Den,DenEyePlate,Cheese}_Mars_SM}`.
- Evidence: `review/phase5/pie/{story01,crops01,crops02,return01}/frame_*.png`, `*_strip*.png`, `*_log_excerpt.txt`,
  `review/phase5/crops/*.png`, `export/unreal_readback.json`, `Saved/Logs/PantryRatValidation/{phase5-*, phase5-evidence-lanelines.txt,
  phase5-final-sources.md5}`.

### Step 1 - import **confirmed** (`export/unreal_readback.json` `readback`: 17/17 checks true)
`pantry_rat_import_ue.py part_a | socket_plan | part_b | save | readback` plus two `animation_query add_socket` calls on the SKEL.
Dedicated SKEL; bind bounds vs Blender 0.0005 cm; nose at max X 30.7 (= Blender); 26 bones, parents exact, root identity, bone scales
1 (6e-07), heads 6e-05 cm; ear_l at -Y; slots Body/Pink/Belly/Wood/Harness on 5 MIs of `M_CkUsf_Look_MarsPantryRatSurface`
(FadeAlpha default 1) + the raw `M_CkUsf_Look_MarsPantryRatEyePlate` on slot 5; statics present (den complex-as-simple, plate and
cheese one box); 34 clips: frames = manifest, length N/30, loop flags, no root motion, 26 tracks, EarFlick / TailSettle additive vs
IdleBreath f0, landmarks <= 0.0001 cm from Blender.
- **Sockets** (on `jaw`, read back on the saved mesh):

  | socket | relative loc (UE cm) | relative rot (P, Y, R) | component at rest | manifest target | err |
  |---|---|---|---|---|---|
  | Carry_Mouth | (0, -13.1374, 0.6779) | (-60.1878, 90, -180) | (26.6, 0, 13.2) | (26.6, 0, 13.2) | 0.0 cm, axes 0.0 |
  | Carry_Drag | (0, -17.2658, -25.5891) | (-21.8122, -90, 0) | (26.9454, 0, -13.3872) | (26.9455, 0, -13.3872) | 0.0001 cm, axes 0.0 |
- **Hard-edge GATE - PASS.** Readback: LOD0 render vertices **8955** for 3092 tris (9276 corners) = 96.5 % of corners split (a smooth
  import of this mesh would be near its 1658 positions plus UV/slot seams); R01, accepted faceted: 6043 for 2086 tris (96.6 %). LOD
  build settings `recompute_normals False`, `threshold_tangent_normal 2e-05`. Render: every PIE close-up shows flat facets with hard
  edges on body, ears, nose and paws (`crops/crop_hero_threequarter_live.png`, looked at) - faceted like the Blender renders.
- **Eye-plate colour:** the plate look has NO base/patch colour parameter (EyePlate.ush: BaseColor 0, emissive eyes, Unlit). Set as a
  constant `Mars_PantryRat_PatchColor = float3(0.1022, 0.0497, 0.0742)` (linear of sRGB #5A3F4D) in `Shaders/Looks/PantryRatEyes.ush`
  (the rat-local wrapper), applied as emissive under the eyes'; picked up with the console command `RecompileShaders Material
  M_CkUsf_Look_MarsPantryRatEyePlate` (`get_compilation_stats`: is_compiled true, Masked, PS 151 instructions, Phase 2 had 144). D5-1.

### Step 2 - every R01 -> R02 number changed
| number | R01 | R02 | why |
|---|---|---|---|
| `utils_pantry_rat::k_MouthRest` location | (19.8, 0, 20.6 - 18) | **(26.6, 0, 13.2 - 18)** | R02 Carry_Mouth component rest (manifest; read back 0.0 cm) less the 18 cm clearance (the D3-7 derivation) |
| `k_MouthRest` rotation | (52, 0, 180) | (52, 0, 180), unchanged | R02 Carry_Mouth axes equal R01's: X (-0.6157, 0, -0.788), Z (0.788, 0, -0.6157) |
| `k_DragRest` X | 24.546 | **26.9455** | R02 Carry_Drag rest X; z stays -18 (floor), upright (the D3-8 derivation) |
| `FMars_PantryRat_Spec.HurtboxHalfExtents` | (20, 15, 17) | **(28.5, 15.5, 17.5)** | R02 rump 26.2 behind / nose 30.7 ahead of the root, 31 wide, back top 35.2; box centred on the root spans 0.5..35.5 cm up and stops 2.2 cm short of the nose |
| `k_AgentRadius` | 25 | **25, kept** | decision: keep and document - the nose (30.7 ahead) can reach ~6 cm into a wall at a route end facing it; routes, ring scoring and raid readiness are tuned on 25 (D5-7) |
| RatDen `Portals.Inside` (new) | - | **(-26, 0, 0)** | F4-5: the navigator accepts arrival 30 cm short, so the root stops at den-local x <= 4 (arch x -47..9.5) |
| clip table | - | unchanged | R02 frame counts / loop flags equal R01's (readback) |

Withers / readback bands: no AS test reads one (grep); `pantry_rat_import_ue.py` `WITHERS` is unused by its stages. Court markers: the
court geometry is absolute (den at (-950, 0); recess back 47 cm behind it, 100 cm to the west wall's face) and the den markers are
den-relative in the kernel - nothing else needed a change.

### Step 3 - F4-3 and F4-5 **confirmed**
- **F4-3 fix.** The den shell keeps BlockAll (the player still collides with it) and carries `Ck.Jolt.NoBake`, the CkJolt bake filter's
  default component exclusion tag (`CkJolt_ProjectSettings.cpp:57-59`), which the hosted component's Automatic static-world bake honours
  (`CkUnrealComponent_Processor.cpp:166-185`). Pattern copied: the drip dressing and still water (`Script/WorldObjects/Dressing/Water/
  Mars_DripAssets.as:8,39`, `Mars_StillWater.as:99`). The court's NoCollision override is gone.
  Test `Mars_AutoTest_RatDen_ShellStaysOutOfTheGroundField` (shell built headless; the field baked only after the shell exists): bake
  Completed; the shell collides, profile BlockAll, tag present; a Jolt static ray across both arch walls hits nothing; provider Success
  from ExitPortal, EntryPortal, OutsideStand, ReturnAdmission and Inside to 3 m in front of the den.
  **Reproduced first:** `phase5-run00-ratden` with the tag line commented out: exit 1, this test NEW red (5/14 assertions) and the lane
  log line `GroundNav bake found [1] static body with OPEN collision ... StaticMeshComponent_2 [Mesh] ... 6 open edge(s) of 330
  triangle(s)` - F4-3's line, headless. With the tag (`phase5-run01-ratden`): 6/6, zero `OPEN collision` lines. PIE with the default
  BlockAll shell: no `OPEN collision` and no `refused ... NoSurface` line in any of the four runs.
- **F4-5 fix.** ReturnEmpty walks ReturnAdmission -> `Inside` at Creep and only then advances to DenEnter, so the crouch and the fade run
  in the arch. `EmptyReturnFadesHidesThenEmergesSolid` now asserts the root at the first FadeAlpha < 1 frame lies in den-local
  x -47..9.5, |y| <= 30 - PASS in `phase5-run01-ratden`. PIE: every DenEnter at X -946.6..-949.5 (den at -950: den-local x +0.5..+3.4,
  |y| < 3) in story01 / return01; `return01` frames 026 (solid) -> 029/030 (dithering) -> 032 (gone) show head and shoulders inside the
  arch while it fades.
- F4-4 not in scope, still present: story01 ops 1-3 emerge and go ReturnEmpty -> DenEnter within ~2.3 s while the chef walks to the pack
  (`06.31.34 op [1] ReturnEmpty -> DenEnter at [X=-946.893 Y=-2.962 Z=18.000] clock [2.579478]`), and return01 after the second pack.
  Follow-up as Phase 4 wrote it.

### Toolbox (detached `RunBatch.ps1` -> `RunPattern.ps1`, one dir per pattern; the real `Toolbox.log` summary + `Exit.json` read each time)
| run dir (`Saved/Logs/PantryRatValidation/`) | exit | result |
|---|---|---|
| phase5-run00-ratden (REPRO, tag removed) | 1 | 6 run, 5 passed; NEW: `Mars_AutoTest_RatDen_ShellStaysOutOfTheGroundField` |
| **phase5-run01-pantryrat** | **0** | 18/18 incl. `CandidateAssetsReload` on the R02 paths in a fresh headless editor (step 6) and `LookMastersResolve`; Contaminated 0 |
| **phase5-run01-ratden** | **0** | 6/6 (new ShellStays test, extended EmptyReturn); Contaminated 0 |
| **phase5-run01-pantryraid** | **0** | 11/11 |
| **phase5-run01-eyes** | **0** | 20 run, 18 passed; Still red (listed) 2: `Mars_AutoTest_EyesDummy_ComposesAndWrites`, `Mars_AutoTest_Eyes_LookMasterResolves`; no NEW |
| **phase5-run01-cargoslot** | **0** | 6/6 |
| **phase5-run01-worlditem** | **0** | 25/25 |
| **phase5-run01-monster** | **0** | 3/3 |

`phase5-final-sources.md5` (58 files; md5 of the list `d68dc80e4a094e02f5d46f2ad2d27d3d`) taken before run01; `md5sum -c` after it:
58/58 OK. No `.as` / `.ush` saved during run01 (only the court Python changed between PIE runs). The live editor compiled the final set
clean (no `Angelscript: Error` after 06:30:23 UTC). Focused patterns only; lane lines copied to `phase5-evidence-lanelines.txt`.

### Step 5 - story and crops on R02 (court map `/Game/ArtCandidates/PantryRat/R01/Review/PantryRat_R01_Court_MAP`, played, not saved)
Runs (`capture_pie_movement_clip`, frames under `review/phase5/pie/<run>/`): `story01` (60 s, 0.5 s frames, wide follow camera),
`crops01` (80 s, 0.33 s, rat-relative close framing, slomo 0.1 while FadeAlpha is in (0, 1)), `return01` (60 s, 0.33 s), `crops02`
(30 s, a front-framing attempt). **crops01 is the story of record** (its loot is the Mushroom); story01 tells the same story from the
wide camera but its thief took the Monk's Rind (`leased slot [2]`) and the 60 s ran out at the food pickup.

| beat | crops01 frames | log (`pie/crops01_log_excerpt.txt`, UTC) |
|---|---|---|
| raid ready; chef + cleaver walk to the pack | 001-012 | `06.33.27 [PantryRaid] ... ready: 1 den(s)` |
| emerge, watch the guarded pack | 013-041 (rear close-ups) | `06.33.32 op [1] Emerge -> Observe`; `06.33.40 WatchGuarded -> Observe` once the chef left |
| observe / bound bursts to the pack | 042-071 | Observe / BoundApproach alternation 06.33.41-06.33.52 |
| inspect + rummage, reared at the pack | 072-082 | `06.33.53 leased slot [1] item [410 ... Food_Mushroom]`, Observe -> Inspect -> ClaimTell |
| snatch; the Mushroom carried; loaded flee | 083-093 | `06.33.55 ClaimTransfer -> CarryMountPending ... loot [410 ...]`, `-> FleeWithLoot`, FleePause bursts |
| one real strike | 094-095 | `06.34.00 started the [InteractionIntent.Mars.Primary]`, `the chef's strike was DEALT ... amount [20.0] causer [... Cleaver]` |
| topple + DeadHold, X eyes | 096-099 | `06.34.00 topples Right`, `LootReleasePending -> DeadHold ... clock [28.049164]` |
| 3 s hold, corpse dither | 110-113 | `06.34.03 DeadHold -> CorpseFade ... clock [31.038939]` (2.99 s), `06.34.06 CorpseFade -> Destroyed ... fade [0.0]` (0.35 s rat clock) |
| chef picks the Mushroom up | (camera left on the corpse spot) | `06.34.08 started the [InteractionIntent.Mars.Use]`; `state done ... mushroom item [410] parent [Inventory.Mars.Slot.1] mount [Carried] carrier [Player]` |
| empty return (return01) | 013-021 out, 023-027 walk in + crouch, 028-031 dither, 032+ gone, 047+ next rat solid | `06.36.19 ReturnEmpty -> DenEnter at [X=-946.635 Y=-2.213]`, `06.36.22 DenEnter -> DormantInDen ... fade [1.0]`, `06.36.27` next Emerge |

Crops (`review/phase5/crops/`, each looked at):
- `crop_hero_threequarter_live.png` (crops01 080, reared at the pack, front-left three-quarter): **faceted**; body mauve, ear / nose /
  paws pink, the spoon behind; the eye a large **white-hot** oval with a thin darker outline - not amber; the patch reads near-Body.
- `crop_front_eye_lit.png` (078): the same angle a frame earlier, one eye lit. **No straight-on front close-up with both eyes** (D5-6).
- `crop_mouth_carry_side.png` (084, right side, running): the Mushroom (cap forward-down) sits **ahead of and below the snout, visibly
  detached from the jaw**, here and in 086-093 - not the Blender carry pose (item in the jaw). F5-1.
- `crop_corpse_x_eyes.png` (098): on its side, belly to the camera, **X eye clearly visible**, head NOT under the chef; the patch round
  the X reads pale pink / lavender, LIGHTER than the shadowed body (unlit emissive patch, body in the chef's shadow).
  `crop_corpse_solid_same_light.png` (097) is the solid frame from the same camera.
- `crop_corpse_mid_dither.png` (111; FadeAlpha 0.37-0.5 by the nearest 0.5 s log samples): per-pixel speckle over body, spoon, harness
  and the X eye together; the chef's backpack occludes the upper half.
- `crop_return_solid_in_arch.png` / `crop_return_mid_dither_in_arch.png` (return01 026 / 029, same sun and camera): head and shoulders
  inside the arch, spoon and harness on the back; at 029 the whole body speckles inside the den mouth.

### Deviations
- D5-1 The eye-patch colour is a shader constant, not a parameter. The plate look has none, and adding one needs the master regenerated
  (`Ck_Usf_GenerateLooks`), whose generator renames the loaded master away and creates a new object (`CkUsf_Generator.cpp:474-481`) -
  replacing a loaded asset that the saved R02 and R01 meshes reference; stopped there. `M_CkUsf_Look_MarsPantryRatEyePlate` is **dirty
  in memory, not saved** (its source is the .ush; it applies to R01 rats too). Knob: `Mars_PantryRat_PatchColor` in
  `Shaders/Looks/PantryRatEyes.ush`, then `RecompileShaders Material M_CkUsf_Look_MarsPantryRatEyePlate`.
- D5-2 F4-5 uses a new den marker `Inside` (-26, 0, 0) instead of moving the Phase 1 `EntryPortal` (24, 14, 0), which lies 24 cm
  outside the arch and is a loaded-flee keep-out point.
- D5-3 F4-3: the shell is out of the Jolt static world entirely, so the rats' Jolt queries (SurfaceMotion rays, the topple probe) and the
  ground field ignore the stone; a route could cross the arch walls (none seen). A closed collision mesh would be the stronger fix.
- D5-4 The court director (`Mars_PantryRatReview.as`) was edited (override removed, two read-only UFUNCTIONs) and PIE ran on the R01 court
  map; the map was never saved and never dirty.
- D5-5 Story of record = crops01; story01 stole the Rind and was cut at 60 s. crops01 left `slomo 0.1` on after the corpse was destroyed
  until PIE ended (script bug, fixed before return01): the pickup ran slowed; its logged result stands.
- D5-6 No straight-on front close-up: two rat-relative framings of the watching rat (crops01 013-041, crops02) came out as rear views;
  cause not found (inferred: my camera script's use of the root yaw).
- D5-7 `k_AgentRadius` kept at 25 (table).
- D5-8 `phase5-run00` ran a deliberately broken tree (the tag line commented out) to reproduce F4-3; the file was restored
  byte-identical before the hash and run01.
- D5-9 The hurtbox is centred on the root (the spec has no offset); the nose's last 2.2 cm are outside it.

### Findings
- F5-1 **The mouth carry floats ahead of the jaw** in PIE (crops01 084-093). The mouth node is a fixed rest frame on the root (D3-7) while
  the loaded clips move the head; the R02 rest itself reads back exact. Inferred cause; fix = ride the `Carry_Mouth` socket.
- F5-2 The eyes read white-hot, not amber, in every lit close-up (the Wide style's strength saturates EyeColor (1, 0.78, 0.45)).
- F5-3 The lease order is not stable: story01's first lease was slot 2 (Rind), crops01's slot 1 (Mushroom).

### Not verified / open
- A straight front close-up (D5-6); gait / foot slip in Unreal; the patch colour against the sheet in neutral light (near-Body when the
  head is lit, lighter than the body when it is shadowed).
- The dither crop's exact alpha (sampled every 0.5 s); rat routes vs the un-baked shell (D5-3); multiplayer (R30) unchanged; F4-4.
- Editor left: `PantryRat_R01_Review_MAP` open (as Phase 4 left it), no PIE, dirty: `M_CkUsf_Look_MarsPantryRatEyePlate` only.

Claim I would most expect to be wrong: that the eye patch "is #5A3F4D". It is that number in the shader, but as an unlit emissive it reads
lighter than the lit body whenever the head is in shadow (seen on the corpse), so against the sheet it may not match in most lighting.

## Phase 6 - amber eyes, the patch in shadow, the carry rides the jaw (2026-11-07, DONE - awaiting planner audit)

Planner audit of Phase 5: import, swap, F4-3 and F4-5 accepted; three items reopened (eyes white-hot, patch lighter than the body in
shadow, the carried item floating ahead of the jaw). Same rules: no git write, no full gate, no plugin / production map edit, editor
never closed or Save-All'd; dirty packages checked before every PIE (only `M_CkUsf_Look_MarsPantryRatEyePlate`, D5-1).

### Files changed (originals copied before the edit)
- `Script/WorldObjects/Monsters/Mars_PantryRat_EntityScript.as` - `EyeColor` / `EyeEmissiveStrength` / `MouthSocket` properties;
  `Make_EyeStyle` (Wide cells + amber + strength) used by `BuildEyes`; `Review_SetEyeStrength` (review sweep); `Follow_MouthSocket`
  on the dressing tick.
- `Shaders/Looks/PantryRatEyes.ush` - the patch emissive dimmed: `Mars_PantryRat_PatchLevel = 0.15` x #5A3F4D (linear).
- `Script/WorldObjects/Monsters/Mars_PantryRatReview.as` - `Review_SetRatEyeStrength` (court sweep only).
- Not touched: the shared MarsEyePlate look, the Eyes feature, `utils_pantry_rat::k_MouthRest` (still the node's creation frame).

### 1. Eyes amber **confirmed** (crop pixels, looked at)
- Set: `EyeColor = (0.9911, 0.5583, 0.0343)` (linear of the sheet amber #FEC534), **`EyeEmissiveStrength = 1.0`** (Wide default was
  (1, 0.78, 0.45) x 6). Cells: Wide's **19 / 19** kept - a full oval filling the patch, the sheet's Curious eye; no cell change.
- Sweep (`phase6/pie/crops01`, the court's `Review_SetRatEyeStrength` at 3.0 / 1.5 / 1.0 / 0.6 / 0.35 / 1.0 while the residents walked
  out and back; frames 018, 037, 055, 074 front-on, both eyes). Eye-pixel medians (sRGB) and the lowest saturation inside the eye:
  frame 018 = **3.0** (251, 239, 122), min sat 0.51 (pale yellow-white core); 037 = **1.0** and 074 = **1.0** (226, 196-197, 49), min
  sat 0.78; 055 = **0.35** (163, 121, 20), min sat 0.86 (dim ochre). The sheet swatch is (254, 197, 52): **1.0 reproduces it with no
  white core**, so 1.0 stays. Frame -> strength **confirmed** by the PNG write times (local UTC-5) against the log: 018 at 06:56:35.55
  after `rat eye strength [3.0]` 06:56:35.23; 037 at 41.97 after `[1.0]` 41.20; 055 at 48.00 after `[0.35]` 47.20; 074 at 54.40 after
  `[1.0]` 50.20.
- Crops: `review/phase6/crops/crop_front_eyes_amber.png` (crops01 037: straight-on front close-up, both eyes saturated amber ovals,
  dark patch ring, faceted) and `crop_hero_threequarter_amber.png` (crops01 183: three-quarter at the pack at the snatch, amber eye,
  Mushroom still in its pocket behind).

### 2. The patch in shadow - regeneration STOPPED (D6-1), emissive dimmed **confirmed** (looked at)
- The shading model is declared in the AS look asset, not the .ush: `MarsPantryRatEyePlate._Domain = ECk_Usf_Domain::SurfaceUnlit`
  (`Script/ECS/PantryRat/Mars_PantryRat_Look_Assets.as`). Making it Lit needs `Ck_Usf_GenerateLooks MarsPantryRatEyePlate`, and the
  generator does NOT rewrite in place: it `Rename`s the loaded `M_CkUsf_Look_MarsPantryRatEyePlate` to the transient package and creates
  a NEW `UMaterial` in the package (`Plugins/CkFoundation/Source/CkUsfEditor/Public/CkUsfEditor/Generator/CkUsf_Generator.cpp:474-481`),
  with no reference replacement - the loaded R01 and R02 skeletal meshes would keep pointing at the renamed-away object until reloaded
  (PIE would still draw the old one; a later save of either mesh would drop slot 5). That is a force-replace of a loaded master, so
  not done.
- Instead the patch emissive is `0.15 x (0.1022, 0.0497, 0.0742)` (`Mars_PantryRat_PatchLevel` in `Shaders/Looks/PantryRatEyes.ush`),
  picked up by `RecompileShaders Material M_CkUsf_Look_MarsPantryRatEyePlate` (the master stays dirty in memory, unsaved).
  Lower strength also cut the eye glow that lit the Phase 5 patch (the pale disc was mostly GlowStrength x 6).
- Proof: `crop_corpse_x_eyes_b.png` (carry04 305, corpse in sun) and `crop_corpse_x_eyes_a.png` (crops01 209): the patch is a DARK
  octagon round an amber X, darker than the lit mauve body around it in both; Phase 5's pale lavender disc is gone. In the front crop
  the patch reads as a dark ring, darker than the body (the sheet's patch is only slightly darker - see Not verified).

### 3. Carry rides the jaw **confirmed** (crops) + lane
- `Follow_MouthSocket` (entity script dressing tick, every frame with a body): the mouth node's offset on the root = the skeletal
  `Carry_Mouth` socket's world transform relative to the root's current transform, through `utils_scene_node::Request_UpdateOffset`.
  Without a body (headless) the node keeps `k_MouthRest`.
- **Drag point NOT moved to `Carry_Drag` (D6-2).** In every one of the 34 clips' rest the `Carry_Drag` socket sits 13.4 cm BELOW the
  floor (`component_cm` z -13.39; it was solved for the unauthored drag pose with the head lifted), so following it would bury a bulky
  item; no clip authors the drag pose, and no bulky item exists in the court. The bulky offset (`Get_CarryOffset`, k_DragRest relative to
  k_MouthRest) now rides the moving mouth node. Follow-up: author a drag pose / clip before the drag point follows its socket.
- Crops: `crop_carry_side_bound.png` (carry04 282, FleeWithLoot) and `crop_carry_side_pause.png` (carry04 296, FleePause by the log
  times `07.04.12-07.04.14`): the item's base sits at the jaw directly under the nose and moves with the head (also crops01 184-207,
  carry03 385-404) - the R02 carry pose's position. **The loot in all three PIE thefts was the Monk's Rind, not the Mushroom**
  (`leased slot [2]` at 06.57.30, 07.02.06, 07.04.06; F5-3); both ride the same mouth path (`Get_CarryOffset` = identity for items
  <= 10 cm half-width), so the Mushroom carry is inferred, not seen (D6-3).

### Toolbox (detached, one dir per pattern; `Toolbox.log` + `Exit.json` read) **confirmed**
| run dir | exit | result |
|---|---|---|
| **phase6-run01-pantryrat** | **0** | 18/18 (the headless mount / release tests on the fallback frame; CandidateAssetsReload R02) |
| **phase6-run01-ratden** | **0** | 6/6 |
| **phase6-run01-pantryraid** | **0** | 11/11 |
| **phase6-run01-eyes** | **0** | 18/20; Still red (listed): `Mars_AutoTest_EyesDummy_ComposesAndWrites`, `Mars_AutoTest_Eyes_LookMasterResolves`; no NEW |
`phase6-final-sources.md5` (58 files, list md5 `597ebf0c3eb17fa95346d7b2dbc288f0`) before the batch, `md5sum -c` after: 58/58 OK; the
live editor compiled the set clean (06:55:39 / 06:55:57 UTC, no `Angelscript: Error`). Lines in `phase5-evidence-lanelines.txt` (Phase 6 block).

### PIE runs (R01 court map, played, never saved; editor left on `PantryRat_R01_Review_MAP`)
`review/phase6/pie/crops01` (eye sweep + Rind theft + corpse), `carry02` (75 s, no theft: F4-4 churn held the guard state), `carry03`,
`carry04` (Rind thefts, side carry, corpse), strips `*_strip*.png`.

### Deviations
- D6-1 Lit eye-plate look not made: regeneration replaces the loaded master object (above); emissive patch dimmed instead.
- D6-2 Drag point not moved to `Carry_Drag` (socket under the floor at rest; no drag clip).
- D6-3 Mushroom carry not re-captured: three PIE thefts all leased the Rind (slot 2); the carry crops show the Rind.
- D6-4 Review-only eye-strength hooks (`Review_SetEyeStrength`, `Review_SetRatEyeStrength`) added to the assembly and the court.

### Not verified / open
- The Mushroom in the jaw (D6-3); the drag pose (D6-2); the patch against the sheet in neutral light (it now reads darker than the body
  when lit - the opposite error, smaller); eye strength under other exposures (tuned in the court's sun + exposure -1).
- F4-4 churn is now long enough to stall a theft run for 75 s (carry02).

Claim I would most expect to be wrong: that the carry fix holds for the Mushroom - it was proven on the Rind only (D6-3); the Mushroom's
taller stem pivot may sit differently against the jaw.

## Phase 7 - Lit eye plate under a new look, F4-4 emergence gate, the Mushroom carry (2026-11-07, DONE - awaiting planner audit)

Planner audit of Phase 6: amber eyes, the jaw-following carry and D6-1 / D6-2 / D6-4 accepted; the near-black 0.15 patch rejected. Same
rules: no git write, no full gate, no plugin / production map edit, editor never closed or Save-All'd, dirty packages checked before PIE.

### Files changed / new (originals copied before the edit)
- `Script/ECS/PantryRat/Mars_PantryRat_Look_Assets.as` - NEW look asset `MarsPantryRatEyePlateLit` (Domain `SurfaceLit`, Masked,
  `_UsedWithSkeletalMesh`, the MarsEyePlate block CPD 0..13, FadeAlpha CPD 14, then `PatchColor` Vector default (0.1022, 0.0497, 0.0742)
  = #5A3F4D); `utils_pantry_rat_look::Look_EyePlate()` now returns it, `Look_EyePlateUnlit()` the old one. The old asset is unchanged.
- `Shaders/Looks/PantryRatEyes.ush` - the Unlit wrapper reverted to its Phase 5 source (PatchColor at full #5A3F4D; the 0.15 level
  removed); NEW `Mars_Look_PantryRatEyePlateLit`: BaseColor = PatchColor (lit, Specular 0.25, Roughness 0.85 like the body look),
  Emissive = `Mars_Look_EyePlate`'s emissive only, OpacityMask = the hash dither.
- `Script/ECS/PantryRaid/Mars_PantryRaid_{Feature,Utils,Processor_Tick}.as` - F4-4 gate (below): pack-record reach cache fields,
  `EmergencesRequested` / `UnreachableTargetLogs` counters + getters, `Get_HasReachableTarget` / `Get_IsWorkPointReachable`.
- NEW `Script/Tests/PantryRaid/Mars_AutoTest_PantryRaid_UnreachablePackSpawnsNothing.as`.
- `Script/Tests/PantryRat/Mars_AutoTest_PantryRat_LookMastersResolve.as` - asserts the R02 slot 5 wears the Lit master, its MID reads
  PatchColor #5A3F4D, and the Unlit master still resolves Masked.
- `Script/WorldObjects/Monsters/Mars_PantryRatReview.as` - `Review_CheeseHigh` (court only: the Rind stowed in slot 0).
- `scripts/pantry_rat_import_ue.py` - `EYE_MASTER` = the Lit master (a re-run binds and reads back the Lit one).
- Unreal: NEW `/Game/Mars/Materials/GeneratedLooks/M_CkUsf_Look_MarsPantryRatEyePlateLit` (+ the CkAssetExporter `.ckexport` sidecar
  its save hook wrote); `PantryRat_R02_Mars_SK` re-saved with slot 5 = the Lit master. Editor-written as before: `Mars_EntitySpawnParams.as`,
  `Mars_AutoTestActors.as`, `AutoTests_Mars_MAP.umap` (populator, the new test's actor).

### 1. Lit eye plate **confirmed**
- Generated only the new look: console `Ck_Usf_GenerateLooks MarsPantryRatEyePlateLit` -> log `07.15.34:092 CkUsfEditor: Trace: [PIE-ID -2]
  Generated master for look [MarsPantryRatEyePlateLit]` (and `LogSavePackage: Moving ... M_CkUsf_Look_MarsPantryRatEyePlateLit.uasset`).
  The old master was not touched: same object path `/Game/Mars/Materials/GeneratedLooks/M_CkUsf_Look_MarsPantryRatEyePlate` in its own
  package after the generation, its `.uasset` still dated 2026-11-06 22:36 local, and `list_dirty_packages` showed the same single dirty
  package (the old master, dirty in memory since Phase 5) before and after. New master: `get_compilation_stats` is_compiled true,
  Masked, PS 342 instructions; Python: `MD_SURFACE`, `MSM_DEFAULT_LIT`, `BLEND_MASKED`.
- R02 `PantryRat_R02_Mars_SK` slot 5 (EyePatch) set to the Lit master and saved by name (R01's slot 5 still the old master). The old
  master recompiled from the reverted source (`RecompileShaders Material M_CkUsf_Look_MarsPantryRatEyePlate`; still dirty, unsaved).
  Re-seed: the rat body is built at spawn from the saved mesh, so every PIE rat after this wore the Lit plate (the Eyes CPD 0..13 and
  CPD 14 contract is unchanged).
- Proof (`review/phase7/crops/`, looked at):
  - `crop_corpse_x_eyes_lit_patch.png` (run01 342, corpse in the court sun): the patch is a lit **mauve** octagon round the amber X,
    slightly darker than the body. Pixels inside the patch (90, 62, 77) vs the body around it (105, 74, 93), (107, 76, 93), (118, 84,
    102); only the shadow rim under the patch's lower edge is dark (23, 16, 25). Not a black ring, not lighter than the body.
  - `crop_front_threequarter_lit_patch.png` (run01 320, reared at the pack, front three-quarter): amber eye in a patch shaded with the
    head's facets, a little darker than the body. No straight-on front frame came up in this run (the residents' return camera saw
    them from behind).

### 2. F4-4 emergence gate **confirmed** (headless) + a court finding
- `UMars_Processor_PantryRaid_Tick::Decide_Emergence` now also requires `Get_HasReachableTarget`: from the den's OutsideStand, a
  provider route (`Try_FindPathSync`, `k_AgentRadius`) to `utils_pantry_raid::Get_WorkPoint` of an eligible slot of an armed pack (the
  rat's own approach goal). An unreachable pack stays a target and spawns nothing; the answer is cached per pack (re-asked when it moves
  more than 5 cm, for another den, or every 1 s) and `armed pack [...] has no provider route from den [...]'s OutsideStand to any
  eligible work point: no emergence for it until it moves` is logged once per pack until it moves (`UnreachableTargetLogs`).
- Test **`Mars_AutoTest_PantryRaid_UnreachablePackSpawnsNothing`**: four static walls box the pack and bake into the field; 10 s of
  raid clock after the pack armed -> `Get_EmergencesRequested` 0, no rat, `Get_UnreachableTargetLogs` 1; walls removed, field rebuilt
  (Completed) -> an emergence follows. Lane: `phase7-run02-pantryraid` `Test Completed. Result={Success} Name={Mars_AutoTest_PantryRaid_UnreachablePackSpawnsNothing}`.
  First version red in `phase7-run01-pantryraid` (exit 1): the test rebuilt the field in the same step it destroyed the walls ->
  `GroundNav Volume ... failed to build: [Stale Geometry]`; fixed in the test (wait until the walls left Jolt, then rebuild) - a
  test-sequencing bug, not the gate. The unreachable line itself is not in the lane log (script `Log` verbosity does not reach the
  toolbox log); the test reads the counter.
- **F7-1 (court): the gate does not stop the court's churn, because its cause is not reachability.** In run01 residents still
  emerged and went home every ~6 s for 60 s (`07.19.03`-`07.20.23`, ops 1-16) toward a pack that was reachable (op 10 later stole the
  Mushroom from it). The resident stops at X -902 (OutsideStand -875 less the 30 cm arrival acceptance), 1202 cm from the pack at
  (300, 0), and the rat's `TryGet_Target` drops packs beyond `ScentRangeCm` 1200 - so the rat sees no target, while the raid (which
  does not apply the scent range) keeps emerging. Inferred from these numbers, not tested. Follow-up: emergence should use the same
  scent-range test the rat's target view uses (with the stand-arrival slack), or the court should place the pack nearer.
  Phase 6's F4-4 "inferred cause" (unreachable work point) was therefore wrong for the court.

### 3. Mushroom carry **confirmed** (crops vs the R02 Blender carry pose)
- Court run with `Review_CheeseHigh` (probe at 0.2 s, before the stow): `cheese slot [0] (stow requested [false])`; the Rind in the
  high slot 0 (over `MaxReachCm` 48) still arms the scent, so the Mushroom is the only eligible loot: `07.20.21 leased slot [1] item
  [410 ... Food_Mushroom]`, `07.20.23 op [10] ClaimTransfer -> CarryMountPending`.
- Crops (`review/phase7/crops/`): bound `crop_carry_mushroom_bound.png` (run01 328) and `_b` (336); pause `crop_carry_mushroom_pause.png`
  (329) and `_b` (339) (FleePause windows 07.20.25.09-25.59 and 27.30-27.81 by the log and the frame write times). In every one the
  Mushroom's stem is in the jaw under the nose and the cap stands forward-down in front of the snout, moving with the head - the
  same as the R02 Blender carry pose (`review/round_07c_poses/poses/carry_mushroom.png`: stem in the mouth, cap forward). No item hold
  offset change was needed.

### Toolbox **confirmed**
| run dir | exit | result |
|---|---|---|
| phase7-run01-pantryrat / ratden / eyes | 0 / 0 / 0 | 18/18, 6/6, 18/20 (listed reds) - superseded by run02 (the test file changed) |
| phase7-run01-pantryraid | 1 | 11/12: NEW `UnreachablePackSpawnsNothing` (the Stale Geometry rebuild, fixed in the test) |
| **phase7-run02-pantryraid** | **0** | 12/12 incl. `Mars_AutoTest_PantryRaid_UnreachablePackSpawnsNothing` |
| **phase7-run02-pantryrat** | **0** | 18/18 incl. the extended `LookMastersResolve` and `CandidateAssetsReload` |
| **phase7-run02-ratden** | **0** | 6/6 |
| **phase7-run02-eyes** | **0** | 18/20; Still red (listed): `Mars_AutoTest_EyesDummy_ComposesAndWrites`, `Mars_AutoTest_Eyes_LookMasterResolves`; no NEW |
`phase7-final-sources-run02.md5` (59 files, list md5 `52a35f83579f74936d6f8286b0b9f819`) before run02, `md5sum -c` after: 59/59 OK.
Lines copied to `phase5-evidence-lanelines.txt` (Phase 7 block). Focused patterns only.

### Deviations
- D7-1 The front proof is a front three-quarter (one eye), not straight-on.
- D7-2 The court's churn (F7-1) is not fixed by the planned gate; its likely cause (scent range vs the stand) is recorded, not changed.
- D7-3 `Review_CheeseHigh` is court-only; the shipped raid still offers both items (and F5-3, the slot pick by operation id parity,
  `TryGet_Target`'s `(Seed - 1) % EligibleSlots.Num()`, stands - which is why earlier runs kept taking slot 2).
- D7-4 The Lit master's save also wrote a `.ckexport` sidecar (CkAssetExporter save hook), as every saved asset here does.

### Not verified / open
- A straight-on front close-up; the patch under other lighting than the court sun; F7-1's cause (numbers only).
- The old Unlit master stays dirty in memory (unsaved, source reverted, recompiled); R01's mesh still wears it.
- Editor left on `PantryRat_R01_Review_MAP`, no PIE, dirty: `M_CkUsf_Look_MarsPantryRatEyePlate` only.

Claim I would most expect to be wrong: F7-1's cause - that the court churn is the 1200 cm scent range against a rat stopped 1202 cm
from the pack; it fits the logged positions but no run changed the range or the pack to prove it.

## Phase 8 - F7-1 proven and fixed: emergence uses the rat's own scent test (2026-11-07, DONE - awaiting planner audit)

Planner audit of Phase 7: all accepted. Phase 8 scope: F7-1 only. Same rules; focused lanes PantryRaid, PantryRat, RatDen; no full gate.

### Files changed / new
- `Script/ECS/PantryRaid/Mars_PantryRaid_Utils.as` - NEW shared `utils_pantry_raid::Get_IsWithinScent(Scent, PlanarDistance, SlackCm)`
  (distance + slack <= ScentRangeCm); `TryGet_Target` (the rat's target view) now uses it (slack 0); `Get_OutOfScentTargetLogs`.
- `Script/ECS/PantryRaid/Mars_PantryRaid_Processor_Tick.as` - `Get_HasReachableTarget` first applies the same helper from the den's
  OutsideStand with slack `utils_pantry_rat::k_ArrivalCm`; an out-of-range pack spawns nothing and is logged once until it moves.
- `Script/ECS/PantryRaid/Mars_PantryRaid_Feature.as` - `OutOfScentLogged` (pack record), `OutOfScentTargetLogs` (state).
- `Script/ECS/PantryRat/Mars_PantryRat_Utils.as` - `k_ArrivalCm = 30` (the navigator's AcceptanceRadius, was a literal 30 in `Add`).
- NEW tests `Script/Tests/PantryRaid/Mars_AutoTest_PantryRaid_OutOfScentPackSpawnsNothing.as`,
  `Script/Tests/PantryRaid/Mars_AutoTest_PantryRaid_InScentPackStillEmerges.as`.
- `Script/WorldObjects/Monsters/Mars_PantryRatReview.as` - court `PackLocation` (300, 0, 2) -> (250, 0, 2) (D8-2).

### Cause proven first (red), then the fix
- Why the slack: the resident walks to the OutsideStand and its navigator accepts arrival `k_ArrivalCm` (30) short, so it stands up
  to 30 cm farther from the pack than the stand. The court numbers: stand (-875, 0) -> pack (300, 0) 1175 cm (inside 1200), but every
  resident stopped at X -902 / -903 (1202-1203 cm, outside), so `TryGet_Target` saw nothing and it went home after
  NoTargetReturnSeconds - while the raid, which applied no scent test, kept emerging. With one helper and the arrival slack on the
  emergence side the two cannot disagree for a rat that reached its stand.
- `Mars_AutoTest_PantryRaid_OutOfScentPackSpawnsNothing` (den stand 575 cm from an armed, reachable pack, ScentRangeCm 525 - the court's
  1250-vs-1200 case scaled to the rig's +-600 cm field, D8-1): asserts no emergence / no rat / no ReturnEmpty in 10 s of raid clock, the
  out-of-range line logged once. **Red before the fix** (`phase8-run00-pantryraid`, exit 1): `FinishTest TestResult=Failed. Failed: step
  8/8 ...: no rat emerges for a pack beyond the scent range (emergences requested [3], rats seen [3], frames a rat spent in ReturnEmpty
  [169]) (3/6 assertions failed)` - three emergences, every rat back home with no target (the PantryRat phase lines themselves are
  script `Log` verbosity and never reach the toolbox log; the test's counts carry them). **Green after** (`phase8-run01-pantryraid`):
  `Test Completed. Result={Success} Name={Mars_AutoTest_PantryRaid_OutOfScentPackSpawnsNothing}`.
- `Mars_AutoTest_PantryRaid_InScentPackStillEmerges` (stand 575 cm, ScentRangeCm 640 - the 1150 case: inside with the slack): a rat
  emerges, works toward the pack (BoundApproach / Inspect / ClaimTell), never goes home, nothing logged out of range. Green before and
  after (`phase8-run00` and `phase8-run01`: `Result={Success} Name={Mars_AutoTest_PantryRaid_InScentPackStillEmerges}`).

### Court churn, first minute (`ReturnEmpty` lines counted in the live `Saved/Logs/Mars.log`)
- **Before: 9** (Phase 7 run01, 07.18.58-07.19.58, ops 1-9, each `Observe -> ReturnEmpty at [X=-902...]` about 2.0 s after emerging).
- **After: 0** (Phase 8 `review/phase8/pie/story01`, 07.48.59-07.49.59; 0 in the whole 90 s): 2 emergences, both
  `Emerge -> Observe -> WatchGuarded` within 1.1 s (`07.49.05`, `07.49.09`), the Mushroom leased (`07.49.26 leased slot [1]`), one strike
  (`07.49.32 ... DEALT`), story `done` at t 36.8 with the Mushroom in the player's Slot.1. Lines copied to `phase5-evidence-lanelines.txt`.
- With the pack where it was (300, 0) the court would get **no** emergence at all (1175 + 30 = 1205 > 1200) - inferred from the helper,
  not run; hence D8-2.

### Toolbox **confirmed**
| run dir | exit | result |
|---|---|---|
| phase8-run00-pantryraid (REPRO, before the fix) | 1 | 13/14; NEW: `Mars_AutoTest_PantryRaid_OutOfScentPackSpawnsNothing` |
| **phase8-run01-pantryraid** | **0** | 14/14 incl. OutOfScentPackSpawnsNothing, InScentPackStillEmerges, UnreachablePackSpawnsNothing |
| **phase8-run01-pantryrat** | **0** | 18/18 |
| **phase8-run01-ratden** | **0** | 6/6 |
`phase8-final-sources.md5` (61 files, list md5 `269bcf66e43912f0551539d206425668`) before run01, `md5sum -c` after: 61/61 OK.

### Deviations
- D8-1 The tests use the rig's scale (575 cm stand-to-pack, ranges 525 / 640) instead of literal 1250 / 1150 / 1200: the rig's field is
  +-600 cm and its den and pack offsets are shared by every raid test; the margins (50 out, 35 in after the 30 cm slack) mirror the brief.
- D8-2 The court pack moved 50 cm toward the den (dens as placed): at (300, 0) the court sat 5 cm outside the range once the arrival
  slack is counted. Review data only; the shipped ScentRangeCm (1200) is unchanged.

### Not verified / open
- The court with the pack at (300, 0) under the fix (predicted: no emergence, one out-of-range line) - not run.
- A rat that later wanders out of range of a pack it was working (the target view drops it as before; not a regression).
- `SecondPackLocation` (300, 450) is 1258 cm from the stand - the Phase 4 `return10` churn case is now expected to log out-of-range and
  spawn nothing; not run.

Claim I would most expect to be wrong: that the 30 cm arrival slack is the whole margin - a resident pushed back by a chef or stopping
on a different navigator waypoint could stand farther than 30 cm from the stand, and then the two tests disagree again.

## Cheese normals repair (planner, 2026-11-07)
- `build_cheese` wound every face inward; the FBX exported face normals, so the wedge rendered inside-out in Unreal (R01 too).
- Confirmed: `export/PantryRat_R02_Cheese_Mars_SM.fbx` before the fix measured 56/56 faces inward (Blender, centroid test +
  `recalc_face_normals` would flip 56). After: 0 inward, 0 flips, 168/168 loop normals agree. Same 56 tris, 30 verts, slots
  Rind 20 / Flesh 14, bounds +-7.5 x +-5 x 0..8.
- Changed: `scripts/build_pantry_rat.py` (`rc.orient_closed_islands(mb)` in `build_cheese`), `source/PantryRat_R02.blend`
  (`Cheese_MonksRind` flipped, saved), the cheese FBX, `scripts/fix_cheese_normals.py`, `scripts/reimport_cheese_ue.py`,
  the reimported + saved `/Game/ArtCandidates/PantryRat/R02/Props/PantryRat_R02_Cheese_Mars_SM`, renders in `review/cheese_fix/`.
- Manifest facts for the cheese are unchanged, so `PantryRat_R02_Manifest.json` was not rewritten.
- Inferred: the black side face in `cheese_after_hero.png` is the preview scene's shadow side (the opposite side face is lit in
  `cheese_after_tip.png`, and the measurement says no face is inverted); a normals overlay capture drew nothing.

## Phase 9 - locomotion that matches the mover, and a thief that faces the pack (2026-11-08, DONE - awaiting planner audit)

Brief: `PHASE_9_BRIEF.md`. Branch dev, HEAD 2154da26; no git write command run; nothing committed, staged or pushed; nothing under
`Plugins/` edited; no production map edited; `../pantry_rat_r01/` only read; no full gate (focused lanes only). Live MarsEditor through
Monolith only; it was found minimised and restored (ShowWindow restore, `IsIconic` False) before PIE (D9-11); dirty packages checked
before each PIE and the reimport save: only `M_CkUsf_Look_MarsPantryRatEyePlate` (D5-1), before and after. Originals of every edited
file are in `review/phase9/originals/` (script, tools, export incl. the .blend and the 34 old clip FBXs).

### Files changed / new
- `Script/ECS/SurfaceNavigator/Mars_SurfaceNavigator_Feature.as` - NEW `FMars_Request_SurfaceNavigator_Face(FVector InWorldDirection)`,
  `FaceRequests` array, state counters `FacesApplied` / `FacesDropped`.
- `.../Mars_SurfaceNavigator_Processor_Requests.as` - `HandleFace`, drained after Stop and MoveTo: Moving -> dropped (counted); else
  `Steering(Direction.GetSafeNormal2D(), 0)` to SurfaceMotion (the tick's dedupe state set to the zero steer it would send anyway).
- `.../Mars_SurfaceNavigator_Utils.as` - `Request_Face`, `Get_FacesApplied`, `Get_FacesDropped`.
- `Script/ECS/PantryRat/Mars_PantryRat_Utils.as` - `mixin TryGet_TargetView(rat)` (the HFSM's target query moved here, one lookup for
  control and kernel), `Get_FacesIssued`.
- `.../Mars_PantryRat_Hfsm.as` - `Get_TargetView()` now calls `_Rat.TryGet_TargetView()` (behaviour unchanged).
- `.../Mars_PantryRat_Feature.as` - `FacesIssued` counter.
- `.../Mars_PantryRat_Processor_Requests.as` - `utils_pantry_rat::Face_Target` (planar rat -> `TargetView.SlotLocation`, fallback the
  pack root, then the leased pack; logs `faces [slot] from [rat] in [phase] (heading [...])`); issued from `HandleAdvance` on entry to
  Inspect and ClaimTell (after that drain's Stop) and from `HandleClaim` on entry to ClaimTransfer. Once per entry.
- `Script/WorldObjects/Monsters/Mars_PantryRat_EntityScript.as` - assembly clip logic (below): `constants_pantry_rat_clips` (design
  speeds 100 / 200 / 280, bands 20 / 160, rate clamp 0.7..1.5, smoothing 0.05 s, band holds), measured speed from the kernel clock,
  clip choice every tick also headless, `Get_PlayRate`, `Get_MeasuredSpeed`, `Get_ClipFor`, `Get_PlayRateFor`; `SetPlayRate` on the body.
- Tests: NEW `Script/Tests/PantryRat/Mars_AutoTest_PantryRat_ThiefFacesTheSlot.as`, NEW
  `Script/Tests/PantryRat/Mars_AutoTest_PantryRat_LocomotionClipsFollowSpeed.as`, NEW
  `Script/Tests/SurfaceNavigator/Mars_AutoTest_SurfaceNavigator_FaceTurnsInPlace.as`; `Mars_AutoTest_PantryRat_CandidateAssetsReload.as`
  (35 clips, Walk 15, LoadedBound 12); `Mars_AutoTest_PantryRat_TransientForageAdopted.as` (counts Rinds in its own court, D9-7).
- `scripts/animate_pantry_rat.py` - `DESIGN_SPEED`, `CLIP_OVERRIDES` (Walk new, LoadedBound 0.4 s), `periodic`, `eased`, `gait_keys`
  (one key per frame; a planted paw slides back exactly speed / 30 cm per frame), `bound_gait`, `walk_gait`; BoundCycle / LoadedBound /
  Walk built from them; a drift gate (every grounded run within 10 % of the clip's design speed); `design_speed_cm_s` into clips.json.
  The old `bound_keys` stays, unused.
- `scripts/export_pantry_rat.py` (35 clips, `design_speed_cm_s` into the manifest), `validate_roundtrip.py` (35), `reopen_check.py`
  (csv names + Walk, 35), `pantry_rat_import_ue.py` (readback check `clips_35`), NEW `scripts/reimport_clips_ue.py`,
  `scripts/pantry_rat_court_ue.py` (per-phase slow motion `slomo_phases`; OUT = review/phase9), NEW `scripts/phase9_pie_start.py`.
- Regenerated: `source/PantryRat_R02.blend` (5 actions re-baked, saved by the animate script), `export/` (every FBX re-written by the
  exporter; landmarks of the 30 untouched clips identical to the originals - only BoundStart, BoundCycle, BoundStop, LoadedBound, Walk
  differ, compared `expected_anims.json` old vs new), `export/PantryRat_R02_Manifest.json`, `export/anims/{clips,expected_anims,
  roundtrip_report}.json`, `review/round_05/{anim_report.json, clip_table.md, clips/*}`.
- Unreal (saved by name, `reimport_clips_ue.py`): `/Game/ArtCandidates/PantryRat/R02/Animation/PantryRat_R02_{BoundStart,BoundCycle,
  BoundStop,LoadedBound}_Mars_ANIM` (reimported over) and NEW `PantryRat_R02_Walk_Mars_ANIM`.
- Editor-written, not by me: `Script/Generated/Mars_EntitySpawnParams.as` / `Mars_AutoTestActors.as` and `Content/Mars/Maps/
  AutoTests_Mars_MAP.umap` (populator actors for the three new tests) - already dirty from other sessions; do not stage blindly.

### 1. Facing **confirmed**
- Red first: `phase9-run00-red-pantryrat` (the three `Face_Target` calls commented out, `phase9-red-sources.md5`): exit 1, NEW
  `Mars_AutoTest_PantryRat_ThiefFacesTheSlot`: `from 0.6 s after Inspect began until the claim the rat faced the slot (min dot -1.0;
  first below 0.95: dot [-1.0] at [0.600496] s in [ClaimTell]) (2/11 assertions failed)` - the precondition (began Inspect facing away,
  dot <= -0.8) and the mid-move drop held; the second failure is the Faces count. Green after restore: `phase9-run01/04/05-pantryrat`
  `Result={Success} Name={Mars_AutoTest_PantryRat_ThiefFacesTheSlot}`.
- The test: court rig, rat at its slot's work point yawed 180 deg away, Stop + Advance Emerge -> Observe (D9-8); it leases and goes
  Inspect -> ClaimTell -> claim standing; asserts dot >= 0.95 from 0.6 s after Inspect to the claim, drift <= 5 cm, >= 3 Faces, and that a
  Face sent into the loaded flee move is dropped (`FacesDropped` +1, `FacesApplied` unchanged).
- `Mars_AutoTest_SurfaceNavigator_FaceTurnsInPlace`: idle body faces +Y (dot >= 0.99) within 2 uu of where it stood, Face counted applied;
  two Faces during a MoveTo dropped, heading stays on +X (min dot >= 0.99). Green in `phase9-run01/04/05-surfacenavigator`.
- So the inferred mechanism (a zero-speed steer turns the body in place) is now **confirmed** headless; the rat's turn rate is 360 deg/s
  (`utils_pantry_rat::Make_MotionSpec`, `Set_SurfaceTurnRate(360)`), so 180 deg takes 0.5 s.
- PIE (run02, `review/phase9/pie/c_face_log_lines.txt`): `00.41.14.938 faces [X=281.249 Y=-22.500 Z=37.625] from [X=291.897 Y=-63.517]
  in [Inspect] (heading [X=-0.251 Y=0.968])`, the same at ClaimTell (15.992) and ClaimTransfer (17.629); the second rat (op 2, the Rind)
  `faces [X=281.249 Y=17.500] ... (heading [X=-0.412 Y=-0.91...])` from the other side.

### 2. Clips **confirmed** (`review/round_05/anim_report.json`, `review/phase9/pipeline/*.log`: animate / export / roundtrip / reopen
all `PANTRY_RAT_OK`)
| clip | frames | loop | design speed cm/s | measured stance drift cm/s (every grounded run, all four paws) | seam (f0==fN / 2nd diff vs interior) | bad frames | worst harness / spoon clearance |
|---|---:|---|---:|---|---|---:|---|
| Walk (NEW) | 15 | loop | 100 | 100.0 (fore 5-frame, hind 6-frame stances) | 0 / 0.249 vs 0.677 | 0 | -0.086 / 0.176 |
| BoundCycle | 12 | loop | 200 | 200.0 (fore 2-frame, hind 3-frame) | 0 / 2.119 vs 5.300 | 0 | -0.102 / 0.179 |
| LoadedBound | 12 (was 14) | loop | 280 | 280.0 (fore 1-frame, hind 2-frame) | 0 / 2.125 vs 4.187 | 0 | -0.103 / 0.208 |
| BoundStart | 5 | one-shot | - | no grounded run | - | 0 | -0.097 / 0.113 |
| BoundStop | 5 | one-shot | - | (locomotion one-shot, braking slide) | - | 0 | -0.097 / 0.113 |
Drift equals design speed to the 0.1 cm/s the report rounds to (0 % off, gate 10 %), because every frame is a key and a planted paw's
target moves exactly speed / 30 cm per frame and the IK reaches it (an unreachable target would lift the ankle off the floor and break the
grounded run - none did). Walk keeps >= 1 paw down on every frame (union of runs covers 0..15). Apex: BoundCycle body rise 11.9 cm at f5,
LoadedBound 9.4 at f5 (the `rise` curve). Strap fit 0.3 cm lift on the three loops (as R7). Round trip 0 fails, 35 clips, Walk landmark
error 0.00012 cm; reopen 35 clips.
- Contact sheets (looked at): `review/phase9/clips/{BoundCycle,LoadedBound,Walk,BoundStart,BoundStop}_sheet.png`,
  `LoadedBound_tq_sheet.png`; side-by-side `review/phase9/clips/sheet04_vs_phase9_locomotion.png` (sheet-04 locomotion row over the
  three new sheets). Bound: gathered crouch on the hind paws, push, an airborne stretch with the fore paws reaching and the hind paws
  trailing, fore paws land one after the other, gather. Loaded: the same lower and flatter, Mushroom in the jaw, no contact with the fore
  legs. Walk: low body, head down, small paw lifts, a slow four-beat shuffle. Still differs from the sheet: the sheet's low bound draws the
  legs more extended and the body higher off the floor than the renders read; the walk reads more as a crouched shuffle than a stride.
- Unreal: `reimport_clips_ue.py` via `editor_query run_python`: all five `ok`, `pass true`: frames 5 / 12 / 5 / 12 / 15 = manifest,
  lengths N/30, loop flags, no root motion, 26 tracks, SKEL ok, landmark error <= 0.00007 cm vs `expected_anims.json`; saved exactly
  those five (`saved` lists the five paths); `list_dirty_packages` after: only the eye-plate master.
- Manifest `clips.<name>.design_speed_cm_s`: Walk 100, BoundCycle 200, LoadedBound 280 (read back from the JSON). The assembly's table
  (`constants_pantry_rat_clips` in `Mars_PantryRat_EntityScript.as`) carries the same three numbers; the animate script's `DESIGN_SPEED`
  is the source; keep the three in sync by hand (nothing reads the manifest at runtime).

### 3. Assembly **confirmed** (headless) + PIE
- Measured planar speed (smoothed, tau 0.05 s) picks a band: < 20 standing (the phase's idle clip), 20..160 Walk, >= 160 BoundCycle;
  FleeWithLoot moving -> LoadedBound. The band changes at once to the bound, to standing after 0.06 s, to the walk after 0.08 s from
  standing or 0.2 s from a bound (a stop's smoothed speed falls through the walk band in 0.10 s, so a bound that stops plays
  BoundStop, not the walk). Edges: standing -> BoundCycle plays BoundStart to its end first; BoundCycle -> a standing loop plays BoundStop
  to its end first; an edge clip gives way at once to any other clip (phase change, death). Play rate = speed / design speed clamped
  0.7..1.5 for Walk / BoundCycle / LoadedBound, 1 otherwise, via `SetPlayRate` when it changes by > 0.005. `Play_Clip`'s "same clip,
  no restart" guard kept (`Select_Clip`). Turn clips stay unused (D9-12).
- `Mars_AutoTest_PantryRat_LocomotionClipsFollowSpeed` (sibling of BoundRhythm): the table at Creep 100 -> Walk 1.0, Approach 240 ->
  BoundCycle 1.2, LoadedFlee 320 -> LoadedBound 1.143, standing -> idle clips at 1, clamps 1.5 / 0.7; live: every frame's rate equals
  speed / design (clamped), mid-burst BoundCycle ~1.2 and LoadedBound ~1.14 (>= 5 frames each), BoundStart -> BoundCycle and
  BoundCycle -> BoundStop both seen, the emergence creep walks and never bounds. Green in `phase9-run04` and `phase9-run05`. Its
  diagnostic run before the band fix (`phase9-run03-alone-...`) recorded the live sequence `DenEmerge Walk SniffGround IdleBreath
  BoundStart BoundCycle Walk SniffGround ...` with max speeds BoundApproach 239.95, FleeWithLoot 320.00, Emerge 94.6 cm/s.
- No clip name, speed threshold or mesh in `Script/ECS/` (grep: the kernel's new code is the Face request and the target view only).

### Toolbox (detached `RunBatch.ps1` -> `RunPattern.ps1`; `Toolbox.log` summary + `Exit.json` read; lines in
`Saved/Logs/PantryRatValidation/phase9-evidence-lanelines.txt`)
| run dir | exit | result |
|---|---|---|
| phase9-run00-red-pantryrat (REPRO, Face calls removed) | 1 | 17/19; NEW `ThiefFacesTheSlot` (above); `TransientForageAdopted` (order, D9-7) |
| phase9-run01-pantryrat | 1 | 18/20: `LocomotionClipsFollowSpeed` (speed read 0, F9-1), `TransientForageAdopted` (order) |
| phase9-run01-surfacenavigator / pantryraid / ratden | 0 / 0 / 0 | 6/6, 14/14, 6/6 |
| phase9-run02-alone-...transientforageadopted | 0 | alone: Success (it fails only after `ReleaseRefusalBlocksCleanup` in one lane) |
| phase9-run02-alone-...locomotionclipsfollowspeed | 1 | every measured speed 0.0 (F9-1) |
| phase9-run03-alone-...locomotionclipsfollowspeed | 1 | 22/23: speed fixed; BoundStop never (walk band committed on the stop) -> band holds |
| phase9-run04-{pantryrat,surfacenavigator,pantryraid,ratden} | 0 / 0 / 0 / 0 | 20/20, 6/6, 14/14, 6/6 |
| **phase9-run05-pantryrat** | **0** | **20/20** incl. ThiefFacesTheSlot, LocomotionClipsFollowSpeed, CandidateAssetsReload (35 clips), BoundRhythm, TransientForageAdopted |
| **phase9-run05-surfacenavigator** | **0** | **6/6** incl. FaceTurnsInPlace |
| **phase9-run05-pantryraid** | **0** | **14/14** |
| **phase9-run05-ratden** | **0** | **6/6** |
`phase9-final-sources-run05.md5` (78 files, list md5 `8f3bfa71bebefc8dd55c4f86d81c02a8`) before run05, `md5sum -c` after: 78/78 OK.
(run04 had its own list, 78/78 OK; only the entity script changed between run04 and run05 - the band holds.) Contaminated 0 everywhere.

### 5. PIE on the court (R01 court map, played, never saved; `review/phase9/pie/`; every image below looked at)
Runs: `run01` (first pass, 255 frames; the 0.12 s band hold glided the first 0.2 s of every burst on the idle clip - fixed, then)
`run02` (final code, 289 frames, 0.4 s interval; slomo 0.125 in BoundApproach / FleeWithLoot -> 0.05 s game per frame, 0.25 in Emerge
and Inspect; side camera on the rat's right, top camera for Inspect / ClaimTell). Logs `run0{1,2}_log_excerpt.txt`, frame write times
`run0{1,2}_frame_times.txt` (UTC, matched to the log).
- (a) `a_bound_strip_run02_076-083.png` (8 consecutive frames, burst 00.40.38.874-47.545, X -606 -> -348) + `a_bound_paws_079-082_crop.png`:
  gather (076), push with the hind paws extended back on the floor (077), airborne with the shadow clear of the paws (078), fore paws
  land (079), gather with the hind paws under the belly (080-082), push (083) - one bound per ~7 frames (0.35 s game = 0.4 s / 1.2,
  the play rate). Paw hold (estimate, inferred): across 080 -> 081 the planted fore paw moves ~2-3 cm against the nearest bright grid line
  (camera tracking and perspective make it no better than that); the old clip's slip would be 7-10 cm per 0.05 s (stance 40-95 cm/s vs
  240). Apex (estimate): body ~10 cm over its standing height in 078 (shadow gap), close to the authored 11.9 x play.
- (b) `b_creep_strip_run02_010-013.png`: the Emerge creep is ~25 cm (ExitPortal -> OutsideStand less the 30 cm acceptance) and lasts
  0.27 s game: 010 the crouched den pose, 011-012 low body, head down, ears forward, a fore paw stepping (the Walk pose), 013 Observe.
  Too short to judge a walk cycle in PIE (D9-4); run02 frames 065-075 also show the second rat (op 2) walking beside the first.
- (c) `c_inspect_top_run02_153.png` (Inspect, 0.1 s game after the Face) and `c_claimtell_top_run02_157.png` (ClaimTell), top view with
  the frame's up = the rat's forward: the nose points straight at the pack's pocket (the Mushroom stem) in both; strip
  `c_face_top_run02_150-159.png`; log lines `c_face_log_lines.txt` (Face + Observe -> Inspect -> ClaimTell -> ClaimTransfer). Heading vs
  slot: the logged Face heading (-0.251, 0.968) and the crops agree within what a top view shows (~10 deg, inferred).
- (d) `d_loaded_flee_strip_run02_180-187.png` (FleeWithLoot burst 00.41.24.0-33.2): LoadedBound, Mushroom in the jaw, a low gather /
  push / short airborne cycle; the flee runs along a crate so the background is the crate face. Story completed: strike DEALT
  00.41.39.906, topple Right, DeadHold -> CorpseFade -> Destroyed (00.41.43.289).

### 6. Reload proof **confirmed**: `Mars_AutoTest_PantryRat_CandidateAssetsReload` Success in `phase9-run04-pantryrat` and
`phase9-run05-pantryrat` (fresh headless editors): 35 clips with the manifest frame counts (Walk 15, LoadedBound 12).

### Deviations
- D9-1 Walk is added through `CLIP_OVERRIDES` in `animate_pantry_rat.py` (and `+ ["Walk"]` in `reopen_check.py`), not in the
  planner's `docs/art/.../ANIMATION_MANIFEST.csv`, which is left untouched.
- D9-2 LoadedBound 14 -> 12 frames (0.4 s), as allowed.
- D9-3 BoundStart / BoundStop re-exported and reimported too: they are derived from BoundCycle's f0, which moved (f0 is now the gathered
  hind stance, so BoundStart ends gathered and BoundStop starts from it).
- D9-4 Emerge plays DenEmerge only until the creep commits to the walk band (the brief: Walk for Emerge -> OutsideStand); the creep is
  ~25 cm so the walk shows a few frames per emergence.
- D9-5 The assembly measures speed against the kernel clock, not the timer's delta (F9-1).
- D9-6 Speed smoothing and band holds were added (not in the brief) so a ramp or a stop does not flash the wrong clip.
- D9-7 `Mars_AutoTest_PantryRat_TransientForageAdopted` now counts World Monk's Rinds within 1500 cm of its own court. Proven an order
  effect, not my change: red only when it ran after `ReleaseRefusalBlocksCleanup` in the same lane (run00, run01; the new tests
  re-partitioned the lanes), green alone (`phase9-run02-alone-...transientforageadopted`), green with the fix (run04, run05).
  Undo: drop the distance clause at line 69.
- D9-8 The facing test advances the placed rat Emerge -> Observe itself (with a Stop): with a den link the control layer would walk it to
  the den's OutsideStand first.
- D9-9 Navigator counters `FacesApplied` / `FacesDropped` (test observability).
- D9-10 `TryGet_TargetView` moved from the HFSM's private helper to a kernel mixin; the HFSM calls it.
- D9-11 The editor was minimised; restored with ShowWindow(SW_RESTORE) before PIE (not closed or restarted).
- D9-12 Turn clips (TurnLeft90 / TurnRight90 / Turn180 / LoadedTurn*) stay unused; the Face turn plays whatever the phase's clip is.
- D9-13 The locomotion assertions are a sibling test, not an extension of BoundRhythm.
- D9-14 The exporter rewrites every FBX; only the five changed clips were reimported (the other 30 are landmark-identical).

### Findings
- F9-1 In the lane, `InDeltaT` of the rat's `Create_Tick` timer gave a measured root speed of 0 every frame (run02-alone: "max speed by
  phase ... BoundApproach=0.0 FleeWithLoot=0.0"; the test's own timer measuring the same root read 0 too), while the kernel clock gave
  239.95 / 320.00 (run03). The pre-Phase-9 assembly measured speed the same way (`Speed > 20` picked BoundCycle), so it most likely never
  played BoundCycle / LoadedBound (inferred - a cause of complaint 1 beside the slide; not checked in old PIE footage). Cause of the zero
  not found (the timer fires; the location it reads does not change between its calls).

### Not verified / open
- Paw hold in PIE is an estimate (2-3 cm per 0.05 s against the grid); no fixed-camera measurement.
- The walk in PIE: only 2-3 frames per emergence; a long creep (the ReturnEmpty inside leg) was not captured.
- The headless lanes do not render; clip choice and rate are tested headless, the visuals only in run02's PIE strips.
- BoundStop / BoundStart on a body were not isolated in a PIE strip.
- Editor left on `PantryRat_R01_Court_MAP` (loaded by the capture), no PIE, dirty: `M_CkUsf_Look_MarsPantryRatEyePlate` only.

Claim I would most expect to be wrong: that a planted paw now holds its grid cell in PIE - the clips' stance drift equals the design
speed exactly and the rate follows the measured speed, but the measured speed is smoothed (0.05 s) and SurfaceMotion's real speed
around corners and bursts' first frames differs from the steady value, so the residual slide I estimated from the grid (2-3 cm per
frame step) is a guess from a tracking camera.
