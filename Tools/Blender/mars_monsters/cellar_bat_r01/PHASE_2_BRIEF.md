# Phase 2 brief - Cellar Bat blockout, 42-bone rig, early fold/flap proof, export-recipe validation

You are the executor for Phase 2 of `docs/art/flying-units-r01/MODEL_ANIMATE_IMPORT_PROMPT.md` (read it fully first,
then `PRODUCTION_SPEC.md`, `RIG.json`, `ANIMATION_LIST.csv`, `REVIEW.md`, and LOOK AT the four PNG sheets with the Read
tool: `01-concept-directions.png` (develop A only), `02-model-turnaround-v2.png`, `03-wing-rig-and-expressions-v2.png`,
`04-animation-poses.png`). Also read `PROGRESS.md` beside this file (Phase 1 facts: Blender 5.2.2 at
`C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`, Monolith editor identity confirmed).

## Deliverable of this phase

1. `scripts/build_cellar_bat.py` - a reproducible headless builder (`blender -b --factory-startup --python
   scripts/build_cellar_bat.py -- [flags]`), parametric in cm, that produces `source/CellarBat_R01.blend` with four
   collections: `Authoring` (editable solids, symmetric base), `Rig` (control armature / IK targets, if any),
   `Export` (ONE export mesh object + ONE export armature with exactly the 42 bones of RIG.json, names and parents
   exact, no extra root, no leaf bones), `Review` (cameras/lights/rulers; never exported).
2. A skinned BLOCKOUT (not final topology): pear torso, short-muzzled head with recessed dark face, two broad
   triangular ears, muzzle/jaw with two ivory upper fangs, chest tufts as a few modeled wedges, two hind legs with
   three-toed rigid feet, two wings each with upperarm/forearm/wrist, two-segment thumb, four two-segment long fingers,
   three interdigital membrane panels + the inner membrane to flank and ankle. Three material slots in this order:
   `Body`, `Membrane`, `Eyes`. Palette start: fur #433831, face #171415, membrane #713B46, ribs #B7A18A, eye #FFC570.
   Eyes are exactly two small amber solids in the recessed face.
3. Dimensions (measure them in the script and print them): spread span 75 cm tip-to-tip, nose-to-rump 22 cm
   (excluding ears and feet), torso width 12 cm, ear base-to-tip 10 cm. Root at the body centre of the neutral
   flight bind pose. Final Unreal axes: +X forward, +Y right, +Z up, centimetres, unit transforms.
4. Pose proofs, rendered as PNG sequences (and one contact sheet per test) under `review/phase2/`:
   `spread`, `half_fold`, `wrapped`, `hanging` (inverted, feet planted on a drawn perch bar, wings wrapped), and a full
   `flap` cycle (16 frames: high-V upstroke, broad power stroke, deep downstroke, bent-wrist reduced-area recovery, frame
   15 == frame 0). Folding is done by rotating the export bones (adduct shoulder, flex elbow, draw wrist to chest,
   close the finger fan) - never by scaling, hiding faces or detaching membranes. Report self-intersection: implement a
   cheap check (BVH tree of the posed export mesh against itself, or membrane-vs-body overlap volume) and print numbers
   per pose. If the proportions cannot fully wrap, make the smallest local adjustment (e.g. finger lengths, wrist
   placement), render before/after, and record the deviation in PROGRESS.md.
5. Reference renders with a ruler/scale bar: front, side, back, dorsal, ventral, three-quarter, plus face and
   wing-root close-ups (`review/phase2/views/*.png`). Use EEVEE or Workbench with flat shading so facets read.
6. Export-recipe validation (`scripts/export_cellar_bat.py`, reused in later phases):
   - Export a 10 cm cube (`export/validation/Cube10_Mars_SM.fbx`) and the skinned blockout bind mesh + armature
     (`export/validation/CellarBat_R01_Blockout_Mars_SK.fbx`) and one short 16-frame flap test clip against the same
     armature (`export/validation/CellarBat_R01_Blockout_Flap.fbx`).
   - Exporter settings must be recorded verbatim in `export/validation/export_settings.json` together with the Blender
     version and the FBX version string the exporter wrote (read it back from the file header: the ASCII/binary FBX
     header carries `FBXHeaderVersion`/`FBXVersion`). Do not claim 2020.2 unless the file says so.
   - Known good starting point in this repo for static meshes: `axis_forward='-Z', axis_up='Y',
     apply_scale_options='FBX_SCALE_NONE', use_mesh_modifiers=False, add_leaf_bones=False, mesh_smooth_type='FACE',
     use_triangles=True, path_mode='STRIP'` with geometry authored so Unreal reads +X forward (see
     `../pale_crawler_r01/build_pale_crawler.py`, `export_assembly` and its module docstring about the (x, -y, z)
     frame map). For a skinned mesh you must additionally prove: armature object and root bone import at scale 1 (no
     "root scale 100"), bone names/parents exact, no added armature root bone, `bake_anim_use_all_actions=False`,
     `bake_anim_use_nla_strips=False`, only the one action per clip file, `object_types={'ARMATURE','MESH'}`,
     `use_armature_deform_only=True`, `armature_nodetype='NULL'`, `primary_bone_axis`/`secondary_bone_axis` recorded.
     Try scene `unit_settings.scale_length = 0.01` (1 BU = 1 cm) with `apply_unit_scale=True` first; if the cube or
     bones come in at the wrong scale, iterate the recipe (never compensate in Unreal).
   - Blender round trip: `scripts/validate_roundtrip.py` imports the exported FBXs into a fresh background scene and
     compares bone count/names/parents, bind-pose head positions (0.1 cm), mesh triangle count, material slot names
     and order, bounds, and a few skinned-pose landmarks (wing tips at the flap keys) - compare positions
     semantically, not vertex indices.
   - Unreal validation THROUGH MONOLITH ONLY (tools `mcp__monolith__editor_query` action `run_python` with
     `{"command": <python>, "mode": "execute_file", "unattended": true}`): first re-confirm the open project path is
     exactly `D:/Repositories/CkRepos/Orion/Mars.uproject` and PIE is off; then import the cube as a StaticMesh and the
     blockout as a SkeletalMesh (new skeleton) and the flap clip as an AnimSequence into
     `/Game/ArtCandidates/CellarBat/R01/Validation/` using the legacy FBX importer pattern of
     `Tools/Blender/mars_send_to_unreal/unreal/mars_character_ue.py` (Interchange flag off in a try/finally,
     `FbxImportUI`, `normal_import_method = FBXNIM_IMPORT_NORMALS`, materials/textures off). Then READ BACK: cube bounds
     == 10 cm; bat span == 75 +/- 0.5 cm (bounds Y extent in the spread bind pose), forward == +X (nose at max X),
     reference pose: root bone transform identity, every bone scale (1,1,1), bone count 42, names/parents exact
     (`unreal.SkeletalMesh` -> `skeleton`, use `animation_query get_skeleton_info`/`get_bone_ref_pose` or Python
     `unreal.AnimationLibrary`/skeleton bone APIs), material slots `Body, Membrane, Eyes` in order, the clip has 16
     frames at 30 fps and animates wrist bones. Save ONLY those validation assets (`EditorAssetLibrary.save_loaded_asset`),
     never Save All, never touch other packages. Write the readback JSON to `export/validation/unreal_readback.json`.
     If the Monolith route fails twice with evidence, record the exact error in PROGRESS.md and continue (the Blender
     deliverables do not depend on it).

## Hard rules

- Fresh background Blender processes only. Never attach to a running Blender; `--factory-startup` is fine because the
  process is yours. Save only under this folder's `source/`, `export/`, `review/`.
- Do not edit anything outside `Tools/Blender/mars_monsters/cellar_bat_r01/` except the Unreal validation assets under
  `/Game/ArtCandidates/CellarBat/R01/Validation/`. No git operations. No global add-on installs. No project settings
  changes (restore any importer flag in a `finally`).
- The stylized faceted low-poly look is the target: broad clean planes, flat shading, NO subdivision surfaces, no
  noise textures. The blockout should already read as the bat on the sheets (pear torso, big ears, broad wings with
  pale ribs, dark face with two amber eyes, two fangs).
- Keep the blockout's triangle count modest (roughly 2-4k) - Phase 3 refines topology towards the 6-9k LOD0 budget.
  Put loops at shoulder/elbow/wrist/knuckles/ankle attachment so the fold does not collapse.
- The world root bone stays at the body centre and never moves in any pose; hanging is done by pelvis/spine/leg
  rotation relative to the root (the perch bar is drawn where the feet end up).
- Skin weights: max 4 influences, normalized; membranes blend between finger bones; ribs can follow fingers rigidly.
- Every script prints `CELLAR_BAT_OK` on success or `CELLAR_BAT_FAIL <reason>`; exit non-zero on failure.
- Use `Read` on the rendered PNGs yourself and iterate on one visible issue at a time (at least two look-and-fix
  rounds on silhouette/face). A viewport of primitives is not fidelity; the contact sheets must be inspected.
- Keep PROGRESS.md current: at the end, fill the Phase 2 section with exact commands, measured numbers (span, length,
  width, ear, tri/vertex counts, per-pose intersection numbers), the chosen export recipe and the Unreal readback
  summary, plus any deviation and open risk. Mark each claim confirmed/inferred.

## Reporting back (your final message)

List: files created (paths), the exact rerun commands, measured dimensions, bone-hierarchy check result, per-pose
intersection numbers and what you changed to get the wrap to close, the export recipe that proved correct (or the exact
failure), the Unreal readback numbers, and which PNGs/contact sheets to look at. State what remains unverified.
