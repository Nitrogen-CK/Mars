# Phase B4 brief - scale the whole asset x3.0 (maintainer: "at least 2.5x / 3x bigger", "the size of the rock sphere in the sandbox gym"), re-animate, re-export

You are the Opus executor for Phase B4. Read first: `PROGRESS.md` (Phase B3 + C2 sections and audits; Phase G's PIE
read that the 16 cm turnip is small in the first-person mitts), `PHASE_B3_BRIEF.md`, the scripts (`build_screaming_turnip.py`
with `P` and `POSES`, `animate_screaming_turnip.py`, `export_screaming_turnip.py`, `validate_roundtrip.py`,
`render_screaming_turnip.py`, `render_anims_screaming_turnip.py`, `turnip_audit.py`).

## Decision (Fable, from the maintainer's ruling)

One global scale `P["SCALE"] = 3.0` (the sandbox Rock is `engine::Sphere()` x 0.3 = a 30 cm ball; the bulb is the comparable mass, so bulb height 9.9 -> 29.7 cm) applied to every length in the build (bulb, muzzle, lips, teeth, cavity, leaves,
stems, taproot, cheek lobes, hull, both beds, landmark/socket positions, pose translation keys, shape-key offsets).
Neutral height becomes 48.0 cm (16 x 3.0); bulb about 29.7 x 28.0 x 23.8. Ratios, angles, scale factors, timings and the rig (17 bones, D-A1, root
identity, slot order) do not change. The grip sockets scale with the hull (Grip_L/R at (0, -/+11.82, 12.0)), MouthCue,
SoilLine (28.8) and HarvestGrip too. Bed outer size 72 x 72 x 12.3 cm. Keep the texel-free facet style: do NOT add
geometry because the object is bigger (same tri count); the facets simply get bigger.

## Deliverables

1. Builder at scale: `review/phaseB4/measurements.json` and `pose_report.json` with every B3 number x3.0 (print the
   ratio per quantity; anything that does not scale by 3.0 +-0.5% is a bug to fix, not a deviation to record), the
   pose sheets, lighting compare and a first-person mock at the NEW size (90 deg FOV, 45 cm: it should now fill a
   good part of the frame - report the fraction).
2. Animate: the 16 clips re-authored on the scaled mesh (same frames/loops/chain/cut rules, shape-key peaks
   identical), per-frame audits 0 intersections (the band jump B3-1 may remain), `review/phaseB4/anim_report.json`,
   `cycle_sheet.png`, `ROOT_Scream_sheet.png`, `ROOT_Inhale_sheet.png`.
3. Export (DEV-13 recipe) + round trip (`fails: []`) + manifest refreshed (`dimensions_cm`, sockets, collision,
   beds, `scale_factor: 3.0`, envelope = B3 envelope x3.0 ~ 63.6 x 42.6 x 41.7) + `phase_c_readback` updated with
   the new expected numbers. Record the `k_*` numbers the Script side must adopt in a `gameplay_numbers` block:
   grip points, hull centre offset (0, 0, 20.25), planted offset (-28.8), bed top height, release-point suggestion
   (bed centre + 60 cm), a HeldOffset starting value (the hull centre must sit where the 16 cm one did relative to the
   cupped gloves: compute from (14, 0, -12) and the hull centre offset) and PickupProbeRadius (hull radius + margin).
4. `PROGRESS.md` Phase B4 section: the ratio table, clip table, round trip, manifest, gameplay_numbers, not verified.

## Hard rules

Write only under `Tools/Blender/mars_ingredients/screaming_turnip_r01/`; `export/` and `export/anims/` are yours
this phase (Phase C2 has finished reading them - confirm in PROGRESS.md that the C2 section exists before the first
export). No git, no Unreal, no `Script/`. Headless Blender only. Every script prints `TURNIP_OK` / `TURNIP_FAIL`.
Look at the sheets. Final message: ratio table, clip table, round trip, manifest path, the gameplay_numbers block
verbatim, the fp-mock fraction, what remains unverified; confirmed vs inferred.
