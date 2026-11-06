# Phase A brief - Screaming Turnip blockout, 17-bone rig, four extremes, export-recipe proof

You are the Opus executor for Phase A of the Screaming Turnip R01 campaign. Read, in this order, before touching
anything: `PROGRESS.md` beside this file (Phase 1 facts, decisions D-1..D-5); the handoff package
`docs/art/screaming-turnip-production-r01/`: `DESIGN_TECH_SPEC.md` (sections 3, 4 and 10 Gate A/B are yours),
`ASSET_MANIFEST.json` (identity, deformation guardrails), `ANIMATION_MANIFEST.csv`; and LOOK AT all six PNG sheets with
the Read tool (`01-model-turnaround.png` .. `06-throw-and-settle.png`). Then read the precedent scripts you will adapt:
`Tools/Blender/mars_monsters/cellar_bat_r01/scripts/build_cellar_bat.py` (scene reset, `MB` mesh builder, `tube`/`hull`,
armature, explicit weights, colour attribute, materials, pose proofs, intersection audit), `export_cellar_bat.py` (the
export recipe, armature-rename trick), `validate_roundtrip.py`, `render_cellar_bat.py`, and the bat `PROGRESS.md`
Phase 2 section (what a finished phase record looks like).

Blender: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`, headless only:
`"$B" -b --factory-startup --python scripts/<script>.py -- [flags]`. Never attach to a running Blender. The written
spec wins over the generated sheets wherever they disagree (counts, dimensions, timing).

## Deliverables

1. `scripts/build_screaming_turnip.py` - reproducible headless builder, parametric in cm, that writes
   `source/ScreamingTurnip_R01.blend` with collections `Authoring` (editable solids), `Rig` (control armature if you
   add one; may be empty), `Export` (ONE export mesh `ScreamingTurnip_R01_Body` skinned to ONE export armature
   `ScreamingTurnip_R01_Armature` with exactly the 17 bones below; plus the three static objects of item 4), `Review`
   (camera, rulers, labels; never exported). Scene: `scale_length 0.01` (1 BU = 1 cm), 30 fps.
2. The BLOCKOUT (not final topology; roughly 1.5-3k tris) that already reads as the sheets' turnip:
   - One squat pear-round bulb, broad flat facets, no subdivision, no noise. Magenta shoulders stepping into ivory lower
     flesh (the step is a faceted colour band, not a smooth gradient).
   - One centred folded cross-like mouth seam on the +X face; cream bellows cheeks either side; a closed-backed dark
     plum mouth cavity behind the seam (a real cavity solid, so the gape shows depth); eight small blunt ivory tooth
     wedges, four upper (weighted to `body`) and four lower (weighted to `jaw`), hidden inside the closed seam at rest.
   - Exactly five thick angular green leaves on stout stems from one crown, with real thickness (not planes).
   - One short central taproot pointing straight down. No eyes, limbs, nose, brows, tongue, standing roots.
   - Neutral overall height 16.0 cm from taproot tip (z = 0) to the highest leaf tip. Bulb about 10 h x 9 w x 8 d
     (height along Z, width along Y, depth along X). Measure and print all of these.
   - Frame: mouth faces +X, +Z up, Blender (x, y, z) == Unreal (x, -y, z) (so `_l` bones sit at Blender +Y). Root
     origin at the neutral taproot tip and it stays there in every pose.
   - Material slots in this order: `Skin`, `Leaf`, `Mouth`, `Teeth`. Colour attribute `Col`, BYTE_COLOR on CORNER,
     written as sRGB bytes: RGB = albedo (ivory #F3E6D2, magenta #C0477E shoulders, leaf #7FA93C with darker
     #5E8230 stems, mouth plum #6B2A44, teeth #EFE4CC; +-5% per-facet jitter), A = 1.0 for now (cavity bake is Phase B).
     Blender materials: Principled with Base Color = VertexColor(`Col`).RGB (same graph as the bat's `make_material`).
3. The 17-bone export armature, names and parents exact (D-2 in PROGRESS.md):
   `root` -> `body` -> { `jaw`, `cheek_l`, `cheek_r`, `crown`, `taproot` }; `crown` -> `leaf_01_a` -> `leaf_01_b`,
   ... `leaf_05_a` -> `leaf_05_b`. `root` at the origin, roll 0, identity rest matrix, `use_deform` on every bone,
   `use_connect=False`, quaternion rotation mode. Heads: `body` at the bulb centre; `jaw` at the lower lip hinge
   (below the seam, inside the bulb, axis along Y so rotation about its local axis drops the lower lip); `cheek_l/_r`
   at each cheek centre; `crown` at the leaf base on top of the bulb; `taproot` at the bulb's underside. Explicit
   weights (max 4 influences, normalized; `weights_check` like the bat): lower lip + lower teeth + chin wedge to `jaw`
   (falloff into `body`), each cheek region to its cheek bone (falloff into `body`), leaves to their two bones,
   taproot to `taproot`, everything else to `body`. Nothing weighted to `root`.
4. Three static export objects in `Export` (each a separate closed solid, slot `Soil` where applicable, flat facets):
   `TurnipBed_R01` (soil cap + rim, about 24 cm across x 4 cm tall, with a dished top the bulb sits in; origin at the
   soil line centre), `TurnipBedEmpty_R01` (same rim with an open socket hole), `ScreamingTurnip_R01_Collision` (a
   convex hull of the NEUTRAL bulb only - no leaves, no taproot tip - roughly 24-40 tris, origin == the turnip root).
   Record the collision hull's extents and centre offset from the root.
5. Four posed extremes proven on the export bones (poses are rotations/scales of `body`, `jaw`, `cheek_*`, `crown`,
   `leaf_*`; `root` identity; nothing scaled on `root`), each rendered front / side / three-quarter with a 10 cm ruler
   under `review/phaseA/<pose>/` plus one contact sheet per pose:
   - `neutral` (seam closed, relaxed crown),
   - `inhale` (cheeks inflated to about 1.4x their neutral silhouette, leaves raised, seam a TINY pursed aperture - not
     an open mouth; bulb slightly squashed),
   - `scream` (huge gape: lower jaw dropped so the opening is about 65% of neutral bulb width, teeth visible, bulb
     stretched ~1.30 h / 0.90 w, five leaves fanned out and back),
   - `recover` (deflated cheeks, overshoot squash ~0.75 h / 1.25 w, drooping crown).
   Also render `impact_squash` (brief squash around the physics pose, root unmoved) as a fifth sheet if time allows.
   For each pose print: overall bounds (h x w x d, cm), max bound against the proposed envelope 22 x 14 x 13 cm, and a
   triangle-pair self-intersection count (BVH of the posed export mesh, like `bat_audit`), split into lip/teeth vs
   cavity, leaf vs leaf, leaf vs bulb. Inspect the renders yourself (Read the PNGs) and do at least two look-and-fix
   rounds on the silhouette and the mouth; keep each round's sheet under `review/phaseA/iterations/`.
6. Landmarks measured in the neutral pose and written to `review/phaseA/measurements.json`: root (0,0,0); body
   centre; bulb height/width/depth; crown base; highest leaf tip; the proposed socket positions relative to root:
   `Grip_L` / `Grip_R` (lower flanks, where two gloves cup the bulb from below, roughly z = 3-4 cm, y = +-4.5 cm),
   `MouthCue` (seam centre on the +X face), `SoilLine` (the planted soil line: the bulb's magenta shoulder just above
   soil, so about z = 9-10 cm on the bulb's surface, i.e. the bed's top sits here), `HarvestGrip_L/_R` (stalk bases
   where gloves grasp the crown). These are data for Phase C sockets; do not add them as bones.
7. Export-recipe proof, `scripts/export_screaming_turnip.py` (keep the bat's recipe verbatim; args recorded in
   `export/validation/export_settings.json` with Blender and FBX header versions read back from the files):
   - `export/validation/Cube10_Mars_SM.fbx` (10 cm cube),
   - `export/validation/ScreamingTurnip_R01_Blockout_Mars_SK.fbx` (bind mesh + armature),
   - `export/validation/ScreamingTurnip_R01_Blockout_ScreamTest_Mars_ANIM.fbx` - one 19-frame test clip (0..18,
     neutral -> scream -> neutral) baked on the export bones, exactly one action in the file, `root` identity on every
     frame, scale keys allowed on the other bones,
   - the three statics as `export/validation/<Name>_Mars_SM.fbx`.
   - `scripts/validate_roundtrip.py`: fresh-scene re-import of every file (`anim_offset=0`): cube +-5 cm; armature
     `Armature` scale 1 / 17 bones / names+parents exact / bind heads within 0.1 cm; tri count, slot order, bounds,
     colour attribute, max 4 influences; clip: one action, frames 0..18, root identity every frame, jaw/cheek/leaf tip
     landmarks within 0.1 cm at frames 0/9/18, and **bone scale keys survive the round trip** (cheek_l scale at frame 9
     matches the authored value within 0.01). Write `export/validation/roundtrip_report.json`.
   No Unreal import in this phase (the editor route is Phase C).
8. Fill the Phase A section of `PROGRESS.md`: exact rerun commands, measured numbers, bone check, per-pose bounds and
   intersection counts, the export recipe result, deviations (DEV-n) and open risks, each claim marked
   **confirmed**/**inferred**.

## Hard rules

- Write only under `Tools/Blender/mars_ingredients/screaming_turnip_r01/` (`scripts/`, `source/`, `export/`,
  `review/`, `PROGRESS.md`). No git operations. Nothing under `Content/`, `Script/`, `Plugins/`,
  `Tools/Blender/mars_cooking/`. Do not reuse the old static Turnip anatomy from `build_food_produce.py` (eyes, six
  leaves, three standing roots); you may copy generic helpers from it or from the bat scripts.
- Every script prints `TURNIP_OK` on success or `TURNIP_FAIL <reason>` and exits non-zero on failure; only the builder
  saves the `.blend`. Arguments after `--`. Each script puts its own folder on `sys.path`.
- Facet style: broad planes, flat shading, no subdivision modifiers, no textures. The sheets' faceted read must
  survive at 16 cm in a first-person hand (that is the design bet; make the forms chunky, not fussy).
- `root` never moves, rotates or scales in any pose or clip. The collision hull and sockets are neutral-geometry data;
  expressive scaling never reaches them.
- Teeth follow their gum (upper to `body`, lower to `jaw`); they do not stretch into needles.
- If a proportion must change to make the gape close/open cleanly (lip loops, cavity depth), make the smallest local
  change, render before/after, and record it as a deviation. If the scream extreme exceeds the 22 x 14 x 13 envelope,
  report the measured envelope; do not clip the pose.
- Do not claim anything from a script existing: run it, read its printed numbers and the PNGs.

## Reporting back (your final message)

Files created (paths); the exact rerun commands; measured neutral dimensions and landmark table; bone-hierarchy
check; per-pose bounds vs envelope and intersection counts; what you changed across the look-and-fix rounds; the
export recipe result and round-trip numbers (including the scale-key check); which contact sheets to look at; what
remains unverified. Mark confirmed vs inferred.
