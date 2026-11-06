# Phase B2 brief - the mouth, modelled for real (maintainer: "very disappointed with the result for the mouth")

You are the Opus executor for Phase B2 of the Screaming Turnip R01 campaign. Read first: `PROGRESS.md` (Phase A/B
sections and both audits), `PHASE_B_BRIEF.md`, and LOOK AT (Read tool) the concept sheets
`docs/art/screaming-turnip-production-r01/01-model-turnaround.png`, `02-construction-and-deformation.png` (MOUTH SECTION
and PUSH THE SHAPES), `04-exaggerated-vocal-cycle.png`, then the current side-by-side
`review/phaseB/iterations/r08_final_sidebyside.png`. The scripts are yours: `scripts/build_screaming_turnip.py`,
`turnip_audit.py`, `render_screaming_turnip.py`, `sidebyside_screaming_turnip.py` (the animate/export/validate scripts
are NOT run in this phase - see the gate at the end).

## What is wrong (Fable + maintainer read of r08_final_sidebyside.png)

- Neutral: the concept mouth is four PLUMP lip pads pressed together, deep dark creases between them forming the X, a
  pinched centre, the whole mouth sitting proud of the bulb like a pursed kiss. The model has a thin dark X line on a
  smooth shell with barely-raised pillows: it reads as a scratch, not a mouth.
- Inhale: the concept has two big rounded cheek lobes bulging forward AND outward past the lips, the X pinched hard
  between them. The model is a wide squash with the same flat X.
- Scream: the concept gape is bounded by a thick, continuous, rolled ivory lip rim (upper lip arching, lower lip a
  thick ledge), the teeth seated in plum gum bands inside the rim, the cavity a smooth rounded dark pocket. The model's
  gape is a hole cut into the shell with thin edges; the teeth float; it reads as a cave.

## What to build (geometry, measured; keep the facet style, no subdivision, no textures)

1. **A real mouth patch with radial topology.** Replace the X-seam face patch with a mouth built from concentric loops
   around the seam centre on the +X face: ring 0 = the pinched centre; rings 1-3 = the lips (two loops per lip so the
   lip can roll); ring 4 = the outer crease edge; rings 5-6 = the muzzle-to-bulb blend. Four radial spokes at
   +-45 deg (toward the muzzle corners) are pulled inward to cut the X creases. The scream opens rings 0-1 into the
   cavity; the lip rings become the rolled rim.
2. **Neutral targets** (measure and print them): a muzzle region about 5.5 cm wide x 4.0 cm tall centred on the seam,
   standing 0.8-1.0 cm proud of the bulb surface at the lips and fading to 0 at ring 6; four lip pads each >= 1.0 cm
   thick at the seam; crease depth >= 0.5 cm along the X arms (arm length ~2.5 cm each); the centre pinched >= 0.4 cm
   deep; lip colour = skin ivory with the crease interior darker (a cavity-alpha bake darkens it; add a slightly
   warmer pink to the lip pads' RGB as the concept does). From the front the X must read as creases between pads, not
   a drawn line; from the side the muzzle must read as a bump.
3. **Scream targets**: the gape bounded by a lip rim >= 0.8 cm thick everywhere around the opening, rolling OUTWARD
   (the rim is visible from the front as an ivory band around the plum cavity, as sheet 04); the upper lip an arch, the
   lower lip a thick ledge; two plum gum bands (slightly lighter than the cavity) inside the rim, the 4 + 4 blunt ivory
   teeth seated in them (~0.5 cm, visible against the cavity, none floating); the cavity a smooth closed rounded pocket
   >= 3 cm deep with no shell edge visible; gape width 0.62-0.68 of neutral bulb width; mouth corners rounded.
4. **Cheek lobes**: two explicit lateral lobe regions (vertex groups) centred near (x +1.5, y +-3.3, z 6.3). On the
   inhale they bulge forward (+X) by >= 1.0 cm and outward by >= 1.2 cm as rounded spheres that stand PAST the lips in
   the front view (sheet 04 INHALE), while the lip pads purse 10-15% tighter toward the centre with no opening (gap
   <= 0.15 cm). Achieve it by weighting: lip pads to `body` (upper) and `jaw` (lower), lobes to `cheek_l/_r`; the
   cheek bones may translate forward/outward as well as scale (D-A1 keeps rotation off them). The pucker must not open
   when the cheeks move: prove it with the printed gap.
5. Keep: 17 bones, `root` identity, slots `Skin, Leaf, Mouth, Teeth` (gums go in `Mouth`), D-A1, 15 closed islands or
   fewer, 0 defects, max 4 influences, 1.5-4k tris (the mouth may cost up to ~1k more), the neutral 16.000 cm, bulb
   dimensions within +-0.3 cm of Phase B, hull and sockets unchanged unless the muzzle moves `MouthCue` (then update
   `measurements.json`).

## Review rounds (the acceptance is visual; numbers only gate the rounds)

Each round renders `review/phaseB2/iterations/rNN_mouth_sidebyside.png`: THREE rows (neutral, inhale, scream), each
row = concept crop of the MOUTH REGION (crop the sheet so the mouth fills ~60% of the tile) | render crop at the SAME
framing (front) | render crop (three-quarter) | render crop (side). Same lighting as `lighting/` neutral. Look at it
yourself, write one line per row on what still differs, fix ONE visible thing per round, re-render. Minimum four
rounds; stop when the three rows match the concept in: lip volume, crease depth, pinched centre, cheek lobes past the
lips, rolled rim, seated teeth, cavity depth. Also re-render the Phase B pose sheets and the `fp_mock` with the new
mouth. Print per pose: muzzle protrusion, lip thickness, crease depth, centre pinch, gap, lobe forward/outward offsets,
rim thickness at the scream, cavity depth, intersections (lip/teeth vs cavity must be 0; lip self-contact pairs reported).

## Gate (STOP here)

Do NOT run `animate_screaming_turnip.py`, `export_screaming_turnip.py` or `validate_roundtrip.py` in this phase: the
Phase C importer is reading `export/` right now, and the maintainer reviews the mouth before the clips are re-authored
on it. Deliver the builder change, the saved `.blend` (the Phase B clip actions in it will be stale against the new
mesh; say so), the round sheets, `review/phaseB2/measurements.json`, and the Phase B2 section of `PROGRESS.md`
(what changed in the topology, the per-round findings, the measured table, deviations, what remains). Your final
message: files, rerun commands, the measured table, which sheet to look at, and your own honest read of what still
differs from the concept. Confirmed vs inferred on every claim.

## Hard rules

Write only under `Tools/Blender/mars_ingredients/screaming_turnip_r01/` (`scripts/`, `source/`, `review/phaseB2/`,
`PROGRESS.md`); never write under `export/` this phase; no git; no Unreal; no edits elsewhere. Headless Blender only,
`--factory-startup`. Never claim from a script existing; run it, read the numbers and the PNGs.
