# Phase B2b brief - mouth, second round: short pillowed X, spherical cheeks, oval rolled gape

Fable review of `review/phaseB2/iterations/r12_final_mouth_sidebyside.png` (2026-11-06): neutral close but the X arms
are too long/straight and the pads read as ridges; inhale still one wide wrinkled mass (no spheres); scream a V-bottom
trapezoid with flat side rims and lower-corner overlaps. Read first: `PROGRESS.md` (Phase B2 section incl. "Next"),
`PHASE_B2_BRIEF.md`, the concept sheets (`01`, `02` MOUTH SECTION, `04`) and the r12 sheet; scripts are yours
(`build_screaming_turnip.py` is the Phase B2 builder with the 44 x 10 mouth patch).

## Decisions (Fable)

1. **Weights decouple the lips from the cheeks.** Rings 0-4 (lips, crease floor) are weighted to `body` (upper half)
   and `jaw` (lower half) ONLY; the lateral lobe regions are weighted to `cheek_l/_r` ONLY (full weight at the lobe
   apex, falling to 0 before ring 4); the muzzle outer rings (5-6) blend. Remove the "matched cheek share on both
   sides of every crease" scheme and the `jx` jaw-forward key. The pucker then cannot open when the cheeks move
   because no lip vertex carries cheek weight. Cheek bones translate forward (+X) >= 1.5 cm and outward >= 1.2 cm and
   scale ~1.3 on the inhale (translation + scale, no rotation: D-A1 kept).
2. **Shape keys are authorised where bones cannot get the shape** (spec section 3: allowed if import/playback is
   proven). Author at most three: `Inhale` (two spherical lobes standing >= 0.5 cm ahead of the lip crest in +X, the
   pads pursed 10-15%), `Scream` (the lip loop as a rounded ELLIPSE, rim rolled outward >= 0.8 cm thick everywhere,
   lower corners resolved, upper lip arch, lower lip ledge), optionally `Pucker` (neutral pillow emphasis). The jaw bone
   still drops for the gross opening and the body bone still squashes/stretches; a shape key only sculpts what bones
   cannot. Prove the route BEFORE relying on it: a 10-frame test clip keying one shape key 0 -> 1 -> 0 exported with
   the Phase B recipe, re-imported in a fresh Blender scene with the shape-key value at frame 5 == 1.0 (extend
   `validate_roundtrip.py`), and record in PROGRESS.md the exporter/validator facts (Blender writes shape keys as FBX
   blend-shape channels; `bake_anim` exports keyed shape-key values). The Unreal side (morph target on the SK, curve on
   the AnimSequence, single-node playback driving it) is Phase C's reimport to prove; name the exact readback it must do
   (morph target names on the SK; `get_sequence_info` curve names) in PROGRESS.md.
3. **Neutral X**: arms ~45% of the bulb width (from ~90%), gently curved outward like a four-petal pucker (sheet 01), each
   pad convex in both directions (a pillow, not a ridge), crease depth >= 0.5 cm at mid-arm, centre pinch >= 0.4 cm.
   Calm the facets below the lower lip (larger, fewer facets; no saw-tooth).
4. **Scream outline**: the opening bounded by the lip loop as an ellipse about 0.62-0.68 of neutral bulb width wide and
   ~1.1x that tall, rim min thickness >= 0.8 cm, side rims rounded (not flat bands), 0 mouth-vs-shell and shell-self
   overlaps at the lower corners (split the side pads' lower halves from the lower lip loop in the topology as the
   Phase B2 "Next" item 2 says), teeth seated in the gum bands, cavity >= 3 cm. In profile the gape should not jut the
   whole face forward: the rim rolls, the bulb does not.
5. Keep everything else from the Phase A/B contract (17 bones, root identity, slot order, 0 defects, closed islands,
   max 4 influences, neutral 16.000, bulb +-0.3 of Phase B, hull: if the lip crest stands > 0.5 cm outside the hull's
   +X face, widen the hull by that amount and record it - Phase C re-imports the hull in B3).

## Rounds and acceptance

Same three-row mouth side-by-side as B2 (`review/phaseB2b/iterations/rNN_mouth_sidebyside.png`), one visible fix per
round, at least four rounds, then the pose overview, lighting compare and fp mock with the new mouth. Print the B2
measured table per pose plus: lip crest x vs lobe apex x at inhale (>= +0.5 cm lobe ahead), gape ellipse width/height,
rim min/mean, lower-corner overlap counts, shape-key list and round-trip proof. Honest per-row read at the end.

## Gate (STOP here)

As B2: do NOT run `animate_screaming_turnip.py` / `export_screaming_turnip.py` (except the single shape-key test clip
into `export/validation/`, which Phase C does not read) / full `validate_roundtrip.py`; never write the production
files under `export/` or `export/anims/`; no git; no Unreal; headless Blender only. Fill the Phase B2b section of
`PROGRESS.md`. Final message: files, rerun commands, measured table, the sheet to look at, shape-key proof result,
honest read of what still differs. Confirmed vs inferred on every claim.
