# What was missing, and what remains

## Art coverage found in the audit

- Timber support beam, diagonal brace and a recessed floor-drain/grille were missing from the first 85-entry local breakdown. They are CCS86-88, sheet CS27.
- The first wheel image read as a large wooden ship wheel. Selected CS06-r02 corrects it to the existing 50cm iron-wheel contract. The old image remains only as revision source.
- Shared MODEL13, MODEL26 and MODEL37 had incorrect catalog labels. Selected r02 revisions correct arch/keystone, plinth/box and mill/chute/vat IDs. CS26-r02 corrects the local chain-bay component labels.
- CS23-r02 places the gate on the continuous fixed walking deck, and CS24-r02 supplies matched first-person closed/open views. Earlier variants remain revision sources only.
- Each of the 88 local entries now has an explicit target sheet in MODEL_INDEX.md and model_catalog.json. Actual generated-file/hash/review checks are recorded separately in VERIFICATION.json; an entry in the plan alone does not prove completion.

## Production work deliberately still pending

1. **Generate the actual meshes in Blender.** This dossier is art direction, reusable component breakdowns, measurements and copying briefs. It is not 88 finished meshes, FBX exports, LODs, collision or rigging.
2. **Fit modules and the continuous chain route to the real level.** The source supplies a 24m floor-chain proxy envelope, not a connected chain-routing spline. Guide bends, wall transitions and exact instance counts must be fitted without blocking the existing lane. The 30.067m causeway needs fitted end closures, not blind repetition of a rectangular bridge mesh.
3. **Resolve the intended handwheel versus existing lever control path.** SOURCE_AND_CONTRACTS.json and README.md name the precise source mismatch. Do not install both controls or silently invent drawbridge motion. Retain the actual rising-gate moving node and verify source/sink wiring later.
4. **Build final water/FX material behavior.** Surface, foam, drip, ripple, puddle and flame sheets show mesh carriers and appearance. Shared material maps exist, but these concepts do not supply a finished Niagara system, water simulation, animated chain or automatic fluid gameplay.
5. **Author final text and navigation marks at verified placements.** Blank notice/route backings are intentional. A wheel-and-chain plaque is the Sluice identity; the curing-vat emblem belongs at the Mill. Do not derive a lock answer or new route from decorative art.
6. **Import, dress and accept in Unreal.** Preserve collision, gate travel, hand grips, rail heights, ports, water behavior and source views. Calibrate dark readability in the actual player camera and run appropriate focused CkAuto checks after integration.

No live map, gameplay, collision, light actor or plugin dependency was changed by this art pass. A read-only editor-world check confirmed Variant C was open, but did not establish nested actors or PIE behavior.
