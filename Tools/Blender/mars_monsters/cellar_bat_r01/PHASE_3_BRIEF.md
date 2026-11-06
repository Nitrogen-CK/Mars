# Phase 3 brief - finished mesh, materials, animator rig, LODs

Phase 2 is accepted (read `PROGRESS.md` Phase 2 and the renders under `review/phase2/`; read the prompt
`docs/art/flying-units-r01/MODEL_ANIMATE_IMPORT_PROMPT.md` Phase 3 and `PRODUCTION_SPEC.md` sections 1-3; LOOK at
`02-model-turnaround-v2.png`, `03-wing-rig-and-expressions-v2.png`, `04-animation-poses.png` with the Read tool).
Start from `scripts/build_cellar_bat.py` and `source/CellarBat_R01.blend`; keep the proven export recipe in
`scripts/export_cellar_bat.py` and the round trip in `scripts/validate_roundtrip.py` working. Everything stays under
this folder (`scripts/`, `source/`, `export/`, `review/phase3/`). No Unreal writes in this phase except, if you need to
re-prove a recipe change, the existing `/Game/ArtCandidates/CellarBat/R01/Validation/` assets via
`scripts/cellar_bat_validation_ue.py` (Monolith `editor_query run_python`; confirm the project path first).

## Audit findings on the Phase 2 blockout that this phase must resolve (one visible issue per iteration, render each)

1. **Inner membrane (plagiopatagium) is a thin strip.** The sheet's inner panel is a broad sheet running from the
   innermost finger along the flank down to the ankle, giving the wing a broad, rounded, scalloped trailing edge and
   making the hanging wrap possible. Model it as a real panel with its own loops; its trailing edge between the
   innermost finger tip and the ankle must be a continuous curve, not a straight line.
2. **Wrap reads as a skirt, not a cloak.** In the WRAPPED and HANG panels the folded wings cover the flanks and chest
   like a cloak: elbows tucked at the sides, wrists up near the shoulders/chin, finger fans closed and lying flat
   against the body sides and front, ribs visible as diagonals across the front. Re-solve the wrap targets with the
   new inner membrane so the membranes envelop the torso sides (left wing overlapping right at the front, 1-2 cm
   layering, zero body intersection, zero left/right intersection). This is the prompt's named residual risk: prove
   it with renders from front, side, back and three-quarter and with the intersection counts.
3. **Torso is leaner than the reference.** Make the torso a chunkier pear (keep width 12 cm; add belly volume and a
   rounder chest with the sculpted tuft wedges reading as 3-4 overlapping scallop rows, as in the sheet); keep
   nose-to-rump 22 cm along the body axis.
4. **Flap frame 8 grazes the flank** (6 triangle pairs per side) - resolve with the new membrane root loops.
5. Ears: brown outer shell with a slightly lighter inner face, base-to-tip 10 cm, crisp triangular silhouette;
   face: recessed dark mask, short muzzle with a small nose wedge, mouth interior dark, two ivory upper fangs; eyes
   exactly two small amber solids.

## Deliverables

- **Final LOD0 mesh** in `Export` collection: 6-9k triangles (a justified modest overrun is OK; report actual tris
  and render vertices), closed solids (torso, head, ears, legs, fangs, eyes, claws), intentionally open two-sided
  membranes identified separately from non-manifold defects (run and print a defect audit: duplicate verts, zero-area
  tris, flipped normals, non-manifold edges not on the membrane boundary). Authored split normals (flat facets on
  body; membranes may use flat or lightly smoothed - keep the facet look), deterministic triangulation, UV0 with no
  overlaps (needed for Unreal lightmaps/vertex painting), stable slot order `Body, Membrane, Eyes`.
- **Materials via vertex colours** (RGB albedo mask palette, A = cavity/occlusion), same palette as Phase 2 tuned so
  the body reads under neutral light: fur #433831, face #171415, membrane #713B46, ribs #B7A18A, eye #FFC570.
  Membrane material two-sided, roughness 0.65; body 0.8; eyes restrained emissive. Record what the exporter writes
  (vertex colours sRGB) so the Unreal importer can bind the three slots to material instances that read vertex
  colour. No textures unless you can justify them; if you add any, provide source maps and colour spaces.
- **LOD1 (~3k) and LOD2 (~1k)** on the same skeleton, same slot order, silhouette priorities: ears, outer wing
  silhouette, membrane attachments before tufts. Export them as separate skeletal FBXs (`CellarBat_R01_LOD1_Mars_SK.fbx`,
  `_LOD2_`) with the same armature and bone names.
- **Animator rig**: a `Rig` collection with a control armature (or control bones in a separate armature) driving the
  42 export bones through constraints: body pitch/roll (pelvis/spine), independent per-wing flap (shoulder), elbow,
  wrist curl, finger fan open/close (one driver per wing spreading the four fingers), wing fold (a single control
  that reproduces the proven wrap targets), paired ear controls (rest/alert/flat/twitch), jaw open, feet/perch
  contact (foot targets). Controls must bake cleanly to the export bones (`bpy.ops.nla.bake` with visual keying onto
  the export armature) and must NOT be in the export selection. Write `scripts/bake_cellar_bat.py` that bakes any
  action from the control rig onto the export armature and verify one test action round-trips through it.
- **Skinning**: max 4 influences, normalized, smooth shoulder/membrane blends, ribs rigid to fingers, membranes
  blending between neighbouring fingers and to the flank/ankle; inspect all extreme poses (spread, deepest downstroke,
  highest upstroke, full wrap, both banks, hanging) at every LOD and render contact sheets (`review/phase3/`).
  Optional corrective shape keys only if a specific collapse remains (wrist fold, wing root); if you add any, export
  them as morph targets and prove them in the Blender round trip.
- **Hanging**: both feet planted on the perch bar through the foot controls (solved, not placed), root stationary at
  the body centre.
- Updated `scripts/validate_roundtrip.py` covering LODs, UV0 presence, vertex colours, and morphs if any. Export the
  bind mesh (`export/CellarBat_R01_Mars_SK.fbx`), the LODs and a 16-frame flap test clip from the control rig through
  the bake script (`export/validation/` is fine for the clip) and run the round trip.
- Reference renders with rulers (front, side, back, dorsal, ventral, three-quarter, face and wing-root close-ups),
  plus an EEVEE pass with a neutral three-point light and one with amber key / teal fill to check the palette.
  Compare against the sheets and write what still differs.

## Rules

- Keep everything parametric and reproducible in `build_cellar_bat.py` (it may grow sub-modules under `scripts/`);
  the `.blend` is rebuilt from it. Every script prints `CELLAR_BAT_OK` / `CELLAR_BAT_FAIL <reason>`.
- No subdivision surfaces, no sculpt noise, no dense geometry to fake fidelity. Facets must stay purposeful.
- Do not change the 42-bone export contract, bone names, slot order, or the export recipe without recording a
  justified deviation in PROGRESS.md.
- Fresh background Blender processes only; no git; no edits outside this folder.
- Update PROGRESS.md (Phase 3 section): measured counts (tris, render verts per LOD, influences max, defect audit),
  the wrap/hang intersection table, what changed against the Phase 2 numbers, control list, commands, open risks.

## Reporting back

Files, rerun commands, counts per LOD, the defect audit, the wrap/hang/flap intersection table, control rig list and
the bake proof, round-trip results, and the contact sheets to look at. State what remains unverified.
