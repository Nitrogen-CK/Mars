# Phase 1 brief - Pantry Rat R01: coherent rat / den / cheese blockout, 26-bone rig, extreme-pose and clearance proofs

You are the executor for Phase 1 of `docs/art/pantry-rat-dens-production-r01/` (Mars, D:/Repositories/CkRepos/Orion).
Read, in this order, before any Blender work:
1. `docs/art/pantry-rat-dens-production-r01/PHASE_1.md` (the gate you are executing), `PROMPT.md`, `DESIGN_TECH_SPEC.md`
   section 5 (anatomy, rig, den, cheese) and section 11 (eye patches / UV halves), `ACCEPTANCE.md` artifact rubric.
2. LOOK at the sheets with the Read tool: `02-rat-model-turnaround.png` (five views + palette), `03-rig-construction-and-eyes.png`
   (parts, rig, eye states, squash/stretch/look-back), `01-den-and-eye-cues.png` (Stone Arch, den cutaway, eye plate),
   `04-curiosity-and-bound-poses.png` (bound cycle, rear, stretch), `05-claim-and-loaded-flee-poses.png` (rummage, snatch, carry),
   `06-weapon-hit-and-x-eyes.png` (topple, dead hold belly-up), `09-dithered-cleanup.png`.
3. The proven pipeline to pattern after, same machine, same Blender: `Tools/Blender/mars_monsters/cellar_bat_r01/`
   (`scripts/build_cellar_bat.py` headless parametric builder, `scripts/render_cellar_bat.py`, `scripts/bat_audit.py` BVH
   self-intersection audit, `scripts/validate_roundtrip.py`, and `PROGRESS.md` for the evidence format). Reuse its
   conventions and helper patterns; do not import its anatomy.
4. `Shaders/Looks/EyePlate.ush` and `Script/ECS/Eyes/Mars_Eyes_Look_Assets.as` (read only) so the eye-patch UVs are
   authored for the existing paired-eye plate layout.

## Environment (confirmed by the planner, 2026-11-06)
- Blender 5.2.2 LTS: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`. Run ONLY fresh background processes:
  `blender -b --factory-startup --python <script> -- [args]`. Never attach to a running Blender. The Unreal editor is open
  on this project; you do not touch Unreal in this phase (no Monolith calls, no imports).
- Branch dev, HEAD 2154da267d9abf5516a63c9428fbb43e5c2fbfed. The tree is dirty with another session's work (Crawler,
  Cookbook, Sandbox map, Jolt cells, generated scripts). Do not touch, stash, restore or stage anything. No git commands
  that write.
- You own exactly `Tools/Blender/mars_monsters/pantry_rat_r01/` (this folder): `scripts/`, `source/`, `review/phase1/`,
  `RIG.json`, `PROGRESS.md`. Nothing else may be written.

## Frame and units (same as the cellar bat, proven in Unreal)
1 BU = 1 cm (`scene.unit_settings.scale_length = 0.01`, 30 fps). The rat faces +X, up +Z. Blender (x, y, z) reads as
Unreal (x, -y, z); rat LEFT (`*_l`) is Blender +Y. The export root bone sits at the ORIGIN = floor centre beneath the
neutral body (spec: "Root origin is floor-center beneath the neutral body"), rest matrix identity, and it never moves in
any pose. Everything is authored in cm in the builder; no scale compensation anywhere.

## Deliverables
1. `scripts/build_pantry_rat.py` - reproducible headless builder producing `source/PantryRat_R01.blend` with collections
   `Authoring` (editable per-part solids), `Rig` (controls if you add any; never exported), `Export` (ONE export mesh
   `PantryRat_R01_Body` skinned to ONE armature `PantryRat_R01_Armature` with exactly the 26 bones below, no leaf
   bones, no extra root), `Props` (den shell, recess plane, eye plate, markers, cheese wedge, mushroom proxy, backpack
   proxy, crates, floor - separate objects, never skinned), `Review` (cameras, 10 cm rulers, labels). Prints
   `PANTRY_RAT_OK` / `PANTRY_RAT_FAIL <reason>`, exits non-zero on failure. Flags like the bat builder (`--no-save`,
   `--no-renders`, `--views-only`).
2. One coherent faceted low-poly rat (flat shading, no subdivision, no fur, no textures): plump charcoal-purple body with
   compact haunches, tapered snout with a pink nose, exactly two pink faceted ears, exactly four legs each upper/lower/paw
   with pink paws, one segmented tapered pink tail (4 segments), cream belly, two DARK eye patches on the head (the amber
   eye shapes are material, not geometry - the patches are flat dark facets), one wooden spoon strapped diagonally on the
   back by a leather harness (one chest band behind the forelegs + the spoon strap). Spoon placement ruling for the
   contradicting projections on sheet 02: bowl behind the head over the shoulders a little to the rat's RIGHT, handle
   running back and down to the rat's LEFT hip, lying on the back, not floating. Material slots, in this order:
   `Body`, `Pink`, `Belly`, `Wood`, `Harness`, `EyePatch`. Flat palette start (sRGB): Body #5A4553, Pink #D97B86,
   Belly #E9D5C1, Wood #A8683B, Harness #6E4327, EyePatch #241C22. Eye patches are two separate small facet clusters
   weighted 100% to `head`, UV-mapped so the LEFT patch covers the left half of the paired-eye plate layout and the RIGHT
   patch the right half, matching what `EyePlate.ush` samples (record the exact U ranges you used in measurements.json).
3. Targets, measured by the script and printed: shoulder (withers top above floor) 35 cm; nose tip to tail tip 65 cm in
   the neutral pose (X extent of the whole mesh; also report the tail-excluded body length and the body width); body
   about 40 cm long x 30 cm wide; neutral height including spoon <= 65 cm. LOD0 authoring budget <= 2500 triangles;
   report the real count per part and total, and vertex count. Deviations of more than 1 cm from a target are
   recorded, not hidden.
4. Rig: 26 export bones, exactly these names and parents (write them to `RIG.json` and check the built armature against it):
   `root` -> `body` -> `pelvis`, `chest`; `chest` -> `neck` -> `head` -> `jaw`; `head` -> `ear_l`, `ear_r`;
   `chest` -> `fore_upper_l` -> `fore_lower_l` -> `fore_foot_l` and the `_r` chain; `pelvis` -> `hind_upper_l` ->
   `hind_lower_l` -> `hind_foot_l` and the `_r` chain; `pelvis` -> `tail_01` -> `tail_02` -> `tail_03` -> `tail_04`;
   `chest` -> `spoon_prop`. Skin: max 4 influences, normalised, every vertex weighted; the spoon and harness are rigid to
   `spoon_prop` (harness band may blend to chest); ears rigid to `ear_*`; eye patches to `head`. Add a plain Empty
   `Carry_Mouth` parented to `jaw` in `Props` (not a bone) and record its jaw-local transform: it is the mouth-carry
   contact frame.
5. Pose proofs (define poses on the export bones, capture, render side + front + three-quarter, and run a BVH
   self-intersection audit per pose like `bat_audit.py`; also count vertices below the floor plane z=0 with a 0.2 cm
   tolerance, and report the eye-patch detachment = max distance of any patch vertex from the head surface):
   `neutral`, `crouch` (height 0.85 of neutral), `stretch` (length 1.20 of neutral, rear feet planted), `bound_apex`
   (body lifted 8 cm, legs tucked - the ROOT stays at the origin, the lift is skeletal), `rear_up` (on hind legs, empty
   mouth - report nose height), `jaw_carry` (mouth closed on the mushroom proxy, head level, food readable in front of the
   chest, not inside chest or spoon), `look_back` (head yaw limited so the carried proxy stays readable and clear of the
   spoon - report the yaw you chose), `topple_left`, `topple_right` (lying on the side), `dead_back` (belly up, X eyes
   are material - just the pose; spoon/harness must not lift the body or pass through the floor), `den_crouch` (the
   pass-through pose for step 6). Required numbers per pose: spoon-vs-torso, spoon-vs-floor, harness-vs-torso,
   head-vs-spoon, carry-proxy-vs-chest, carry-proxy-vs-spoon, legs-vs-torso, below-floor vertex count, eye-patch
   detachment. A pose that clips the spoon through the torso or floor is fixed in the source (placement, strap offset,
   bone roll), re-rendered with the same filename, and the before/after numbers are both recorded. No "test later".
6. Den: Stone Arch shell (faceted stones, low chunky arch like sheet 01) with a 60 x 60 cm opening (width x height at
   the floor), 45 cm recess depth, a black recess back plane, and an independent paired-eye plate (amber eyes are
   material; make the plate a dark quad sized for the layout, ~20 x 8 cm, centred ~22 cm above the floor inside the
   recess), plus four plain Empties `EntryPortal`, `ExitPortal`, `OutsideStand`, `ReturnAdmission` on the floor outside
   the recess (nav endpoints are outside the recess). Proof: place the rat in `den_crouch` WITH the spoon at the opening
   and report its posed Y/Z extents against the 60 x 60 opening (clearance in cm, must be positive, no scale change).
   If the posed envelope with spoon does not fit, widen the measured shell opening and record the new opening in
   measurements.json (never shrink the rat for the entrance). Render a grazing-angle view (camera ~75 deg off the
   portal axis, at rat eye height) and inspect it: the rectangular eye plate / recess plane edges must not be visible
   past the shell; if they are, deepen/bevel the recess or inset the plate and re-render.
7. Cheese wedge prop `Cheese_MonksRind`: edible wedge silhouette, orange rind (#D9842B) over ivory flesh (#F2E6C8),
   about 15 cm long x 10 cm wide x 8 cm tall, pivot at base centre. Record dims and tris. No cooking data.
8. Court blockout (plausibility only, no gameplay): floor 800 x 600 cm; a grounded backpack PROXY box with the real
   grounded pack envelope 86 (X, depth) x 116 (Y, width) x 121 (Z, height) cm, pivot at floor centre, pockets on its -X
   face as Empties at pack-local (-31, 1.25, 75) `Pocket1`, (-31, 22.5, 37.5) `Pocket2`, (-31, -17.5, 37.5) `Pocket3`
   (these are the real `SM_PlayerBackpack` sockets x MeshScale 1.25, read from the asset); a mushroom proxy 12 x 12 x 8
   cm (the real `Mushroom_Prep_Mars_SM` bounds, stem down) sitting at Pocket2 and another in the rat's jaw for the
   carry poses; two 60 cm crates as obstacles; a chef proxy capsule radius 39 cm, half height 75 cm (real player capsule)
   standing 120 cm from the pack. Prove and render: (a) `rummage` - rat's nose reaches Pocket2/Pocket3 at 37.5 cm with
   rear feet planted (report nose height and reach); (b) `rear_rummage` - whether the reared rat's nose reaches
   Pocket1 at 75 cm; if not, record the shortfall in cm as a measured finding (the raid may then only claim the lower
   pockets, or the pack layout changes - that is a planner decision, not yours); (c) `jaw_carry` with the mushroom at
   the Carry_Mouth frame, and a `drag_carry` variant with an authored lower carry offset for a bulky 30 x 30 x 25 cm
   proxy (sheet 03 "mouth carry marker") - report both offsets; (d) `death_drop` - the toppled rat beside the released
   mushroom lying on the floor outside the corpse silhouette (report the horizontal gap); (e) a top-down court render
   with two drawn flee routes (curves) around both crates that keep >= 150 cm from the den portal Empties.
9. Renders under `review/phase1/`: `views/` front, right, rear, top, underside, three-quarter hero (sheet 02 set, with
   a ruler), `poses/<pose>_{side,front,tq}.png` + one contact sheet per pose group, `den/` (portal front, grazing,
   cutaway with the eye plate), `court/` (rummage, rear_rummage, carry, drag_carry, death_drop, topdown). EEVEE or
   Workbench, flat shading, dark neutral background so facets read. Keep every iteration's sheet in
   `review/phase1/iterations/` and overwrite only the final named files.
10. `review/phase1/measurements.json`: every number above (dims, counts per part, bones, slot order, UV ranges, pose
    audit table, portal clearance, pocket reach, carry offsets, drop gap), plus `review/phase1/build_log.txt`.
11. Reopen proof: `scripts/reopen_check.py` opens `source/PantryRat_R01.blend` in a NEW background process and verifies
    collections, the export mesh/armature, the 26 bones vs `RIG.json`, slot order and that the pose actions exist;
    prints `PANTRY_RAT_OK`. Run it last and record the exit code.
12. `PROGRESS.md` in this folder (new; format of the cellar bat's): Phase 1 section with exact rerun commands, every
    measured number, the per-pose audit table, what you changed to close each clip/contact and the before/after
    numbers, the spoon-placement and any other reconciliation ruling you applied, deviations from targets, and what
    stays unverified. Mark each claim **confirmed** (evidence file) or **inferred**.

Optional if everything above is green: export the bind mesh + armature with the cellar bat's `SKELETAL`/`BIND` recipe
to `export/validation/PantryRat_R01_Blockout_Mars_SK.fbx` and run a Blender-only round trip (bones/parents/slots/
bounds). No Unreal. Label it a recipe smoke test, not a Phase 2 result.

## Hard rules
- One species, the approved spoon-backed rat. No fur, no extra limbs, no alternative designs, no gameplay code.
- Written counts and scale override the drawings where projections disagree; record each ruling.
- Fix the source, never the render: no hiding faces, scaling parts, or detaching the spoon to pass a check.
- At least two look-and-fix rounds on the five-view silhouette and the hero three-quarter, judged by Reading the PNGs
  yourself against sheet 02 (plump pear body, low stance, big ears, short tapered snout, chunky faceted spoon).
- Every script prints its OK/FAIL marker and exits non-zero on failure. A viewport of primitives is not fidelity.
- Do not write outside this folder. Do not run git write commands. Do not open or touch the Unreal editor.

## Reporting back (final message)
Files created with paths; exact rerun commands; measured dims vs targets; tri/vert counts; bone check result; the per-pose
audit table; portal clearance; pocket reach numbers (incl. Pocket1); carry/drag offsets; drop gap; the rulings you
applied; which PNGs to look at first; what remains unverified.
