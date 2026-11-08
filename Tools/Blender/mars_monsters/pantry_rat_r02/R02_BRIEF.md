# PANTRY RAT R02 - model and animation rework (Blender only)

Executor brief (Opus). Planner: the Fable session that owns `docs/art/pantry-rat-dens-production-r01/PROGRESS.md`. You own this
folder (`Tools/Blender/mars_monsters/pantry_rat_r02/`): `PROGRESS.md` (every claim **confirmed** with the evidence named, or
**inferred**; deviations as DR-n), `scripts/`, `source/`, `export/`, `review/`. R01 (`../pantry_rat_r01/`) is READ-ONLY reference:
copy what you reuse into this folder, never edit it (a Phase 4 executor is working there and in the live editor right now).

## Why this exists
The maintainer rejected the R01 model after seeing it in the engine: "more like a mouse than a rat, proportions off, level of detail
bad". The planner's own read of the in-engine captures against sheet 02 (`docs/art/pantry-rat-dens-production-r01/02-rat-model-turnaround.png`):
1. Head: short blunt snout; huge round disc ears set high. The sheet: a long wedge snout about a third of the head length, small
   angular shield ears set back, flat faceted eye patches on the skull sides.
2. Body: an egg with no chest, no haunch, no belly plane; belly dark. The sheet: low and long, chest mass + pelvis mass readable,
   cream belly plane from chin to tail root (underside view).
3. Limbs: stubs with paddle feet. The sheet: hip / knee / foot read on every leg (construction sheet 03, "LEG (SIDE) - STRUCTURE"),
   small paws with toes.
4. Spoon + harness: a thick flat band; the spoon barely reads. The sheet: the spoon is the silhouette feature, bowl up over the
   shoulder, handle down the flank, one diagonal strap across the chest plus a girth.
5. Surface: noisy smooth-shaded triangulation. The sheet: crisp intentional facets, flat-shaded planes. The tri count was never
   the problem; the topology and shading were.
6. Colour: red-brown body, dark belly. The sheet palette: mauve body, pink ears/nose/tail/paws, cream belly, wood spoon, amber eyes.

## Decisions made by the planner (say if you must deviate, as DR-n)
- **Canonical references:** sheet 02 (turnaround) for proportions and palette, sheet 03 for construction, eye states and the carry
  pose, sheets 04/05 for the behaviour poses. The hero view is sheet 02 "FRONT THREE-QUARTER (HERO)". The quality bar is the sheet
  itself, not another Mars creature.
- **Budget:** 3000-4500 LOD0 triangles, flat-shaded (no auto-smooth, no smooth-by-angle; export custom normals = face normals).
  Under 2000 is fine if the planes read; over 5000 is a deviation.
- **Rig contract is frozen:** the 26 bones of `../pantry_rat_r01/RIG.json` keep their names, parents and roles (root identity, never
  posed); `Carry_Mouth` / `Carry_Drag` Empties on `jaw`. Bone rest POSITIONS move with the new proportions. Max 3 influences.
- **Material slot contract is frozen:** slot order Body, Pink, Belly, Wood, Harness, EyePatch; the eye patch UV convention of R01
  (left patch U 0..0.5 back->front, right patch 0.5..1 front->back, V 0..1) must hold exactly, the engine look reads it.
- **Clip contract is frozen:** the same 34 clips, names and loop flags as `../pantry_rat_r01/review/phase2/clip_table.md`, at 30 Hz;
  BoundCycle stays a 0.4 s loop. Re-author the poses on the new body (the sheet poses are the targets); do not just replay the R01
  curves on a rig whose segments changed length.
- **Scale targets stay:** withers 35 cm, nose tip to tail tip 65 cm neutral, torso ~40 cm without tail, body width ~30 cm, height
  incl. spoon <= 65 cm. Den arch clearance with the spoon (R01 measured 12.65 cm) must stay >= 8 cm (measure it against the R01
  den mesh, copied).
- **No engine work in this brief.** No Monolith, no Unreal import, no `.uasset`, nothing under `Content/`, nothing under
  `Script/`. Prepare the import script with R02 paths (`/Game/ArtCandidates/PantryRat/R02/...`) but do not run it; the planner
  runs the import after the Phase 4 executor releases the editor.
- No git write commands. Blender 5.2 background processes only (`-b --factory-startup`), same as R01.

## Process: one axis per round, a compare sheet every round, two hand-backs
Build a compare harness first (`scripts/compare_sheet.py`): renders the current model from the six sheet-02 cameras (front,
right side, rear, hero three-quarter, top, underside) at the same framing and places each beside the matching crop of sheet 02
(crop the sheet once into `review/sheet_crops/`). Output `review/round_NN/compare_02.png` plus the six single renders. Flat-shaded,
palette materials sampled from the sheet-02 swatches (record the hex values in PROGRESS), EEVEE, neutral three-point light,
grey floor with a 10 cm grid. Same camera transforms every round so rounds diff visually.

Rounds (each ends with a compare sheet you have LOOKED at and a one-paragraph verdict in PROGRESS naming what still differs):
- **R1 Silhouette.** Side and top profile: snout wedge length, skull height, ear size/placement, chest and haunch masses, belly line,
  spoon size and angle, tail length and taper. Judge on the side and top views only.
- **R2 Head.** Wedge snout with a defined bridge, nose block, eye patches as flat facets, ears as small angular shields set back and
  tilted out, jaw split for the carry. Judge on front, hero and side.
- **HAND-BACK 1** after R2: report the two compare sheets; stop and wait for the planner's audit (the planner will resume you with
  corrections or a go).
- **R3 Limbs + feet.** Three-segment legs with readable hip/knee/foot per sheet 03; small paws with 4 toes front / 5 rear or the
  sheet's count; stance width from the underside view.
- **R4 Spoon, harness, paint.** Spoon bowl and handle proportions from the hero view, diagonal chest strap + girth, cream belly
  plane boundary from the underside view, mauve body, pink extremities; eye patch UVs re-verified numerically.
- **R5 Rig + clips.** Skin to the 26-bone rig; re-author the 34 clips; render the sheet-04/05 pose set (sniff, stretch+check,
  rear+observe, startle+backstep, loaded bound, brake+look-back, carry mushroom, dead X topple) beside the sheet crops; a BoundCycle
  contact sheet; the R01 audits (feet planted, loop seams, no interpenetration, den clearance).
- **R6 Export.** FBX mesh + 34 clips to `export/`, round-trip validation (copy and adapt `validate_roundtrip.py`), reopen check,
  import script prepared (not run).
- **HAND-BACK 2** after R6 with the full report.

Keep a `review/round_NN/` per round and never overwrite an earlier round's renders. If a round's verdict says "still differs" after
three iterations on the same axis, stop that axis, write what you tried and what you think is blocking, and hand back early.

## Reporting back (PROGRESS.md, and the same in your final message at each hand-back)
Rerun commands; files; per-round verdicts with the compare sheet paths; the measured table (withers, nose-tail, torso, width, height,
den clearance, tris, verts, influences); palette hex values; deviations DR-n; what is not verified; the one claim you would most
expect to be wrong. Nothing committed, nothing imported, nothing under r01 edited.
