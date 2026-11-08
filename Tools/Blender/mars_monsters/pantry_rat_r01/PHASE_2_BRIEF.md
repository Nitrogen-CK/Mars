# Phase 2 brief - Pantry Rat R01: 34 clips, export round trip, rat-local Masked looks, saved + reloaded Unreal candidate

You are the executor for Phase 2 of `docs/art/pantry-rat-dens-production-r01/`. Phase 1 PASSED (planner audit 2026-11-06):
`source/PantryRat_R01.blend` holds the 26-bone rat, den, cheese and court; `PROGRESS.md` in this folder and
`review/phase1/measurements.json` hold every number. Read, in this order:
1. `docs/art/pantry-rat-dens-production-r01/PHASE_2.md` (the gate), `DESIGN_TECH_SPEC.md` sections 5, 11, 12 (anatomy/clips,
   eyes, dither), `ANIMATION_MANIFEST.csv` (34 records), `VALIDATION.md` (detached Toolbox template, evidence format),
   `DIGEST_EYES_DITHER.md` (the real Eyes/look APIs with file:line - read it fully; it replaces guessing).
2. This folder's `PROGRESS.md` (Phase 1: scene layout, pose language, Carry frames, the chest-band and leg-embedding findings),
   `RIG.json`, `scripts/build_pantry_rat.py`, `scripts/rat_common.py`.
3. LOOK at `04-curiosity-and-bound-poses.png`, `05-claim-and-loaded-flee-poses.png`, `06-weapon-hit-and-x-eyes.png`,
   `09-dithered-cleanup.png`, `03-rig-construction-and-eyes.png` with the Read tool.
4. The proven pipeline, same machine: `Tools/Blender/mars_monsters/cellar_bat_r01/scripts/animate_cellar_bat.py` (clip
   authoring in a pose language, Catmull-Rom keys, periodic loops, lags), `bake_cellar_bat.py`, `export_anims_cellar_bat.py`
   + `export_cellar_bat.py` (the FBX recipe that imported at scale 1 with no extra root), `validate_roundtrip.py`,
   `cellar_bat_import_ue.py` (Monolith run_python importer: legacy FBX importer with the Interchange flag off in a finally,
   new skeleton, slots, sockets, physics, clips with loop flags, save_loaded_asset per asset, readback JSON), and
   `cellar_bat_r01/PROGRESS.md` sections "Phase 5", "Review map (built and saved through run_python)" and every "Incident"
   entry (the editor was killed five times; their rules are now hard rules below).
5. `CkAuto/.claude/skills/build-test/SKILL.md` (current) before any Toolbox run. `Plugins/CkFoundation/Source/CkUsf/CLAUDE.md`
   (look generation: console `Ck_Usf_GenerateLooks <LookName>` or the `UCkUsf_GeneratorSubsystem`).

## Environment
- Blender 5.2.2 at `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`, fresh background processes only.
- The Unreal editor (MarsEditor.exe) is OPEN on `D:/Repositories/CkRepos/Orion/Mars.uproject`; Monolith MCP tools
  (`mcp__monolith__*`) are the ONLY route into it. First call `monolith_discover` for the namespaces you use and confirm the
  project path + PIE off with `editor_query run_python`. Never close, restart or minimise the editor.
- Branch dev, HEAD 2154da26; another session's dirt is in the tree (Crawler, Cookbook, Sandbox map, Jolt cells, Script/Generated).
  Touch none of it. No git write commands.
- Writes allowed ONLY to: this folder (`scripts/`, `source/`, `export/`, `review/phase2/`, `PROGRESS.md`, manifest),
  `Content/ArtCandidates/PantryRat/R01/**` (through the editor), `Shaders/Looks/PantryRatSurface.ush` and
  `Shaders/Looks/PantryRatEyes.ush` (new), `Script/ECS/PantryRat/Mars_PantryRat_Look_Assets.as` (new),
  `Script/Tests/PantryRat/Mars_AutoTest_PantryRat_*.as` (new), `Saved/Logs/PantryRatValidation/**`. The editor may regenerate
  `Script/Generated/*` on its own; never edit those by hand. Never touch `Script/ECS/Eyes/`, `Shaders/Looks/EyePlate.ush`,
  the atlas, or any shared material.

## Deliverables

### A. Clips (Blender) - `scripts/animate_pantry_rat.py`, `scripts/bake_pantry_rat.py` (or one script), `review/phase2/anim_report.json`
1. Author ALL 34 records of ANIMATION_MANIFEST.csv on the export bones (or a control rig you add under `Rig`, baked to the
   export bones like the bat), 30 fps, root bone identity on every frame (no root translation/rotation/scale keys), no scale
   keys anywhere. Quantise each duration to an integer number of 30 Hz intervals (nearest, half-up: 0.25 s -> 8 frames =
   0.2667 s; 0.18 -> 5 = 0.1667; 0.12 -> 4 = 0.1333; 0.35 -> 11 = 0.3667; 0.45 -> 14 = 0.4667) and record the exact
   frames/seconds per clip in the manifest. Loops: N+1 samples, frame N == frame 0 in value and slope (seam check);
   one-shots ease in/out. Never a one-sample clip (the importer rejects it): a hold like DeadHold is >= 2 samples.
2. Content rules (from the manifest's cues): den clips stay low (DenEmerge/DenEnter crouch through the 60x60 portal with the
   spoon - re-run the Phase 1 portal check on their extreme frames); every Loaded* clip and MouthRelease keep the jaw closed
   on the Carry_Mouth proxy until MouthRelease opens it; no rear/groom/eat in Loaded clips; RearUp/RearObserve/RearDown only
   empty-mouthed; Startle widens nothing in the mesh (eyes are material); DeathToppleLeft/Right end in the Phase 1
   topple_left/right poses, DeadHold = dead_back; BoundCycle: crouch -> push -> low bound (<= 8 cm lift) -> forefeet land ->
   hind gather -> settle, the visual arc only (no root motion); Rummage: hind feet braced, forepaws tug; Snatch: jaw clamps
   then one step back; TurnLeft90/Right90/Turn180: body/legs turn in place with NO world yaw keyed on the root (the rat's
   facing is SurfaceMotion's); EarFlick/TailSettle are additive banks relative to IdleBreath frame 0.
3. Audit every baked frame like Phase 1 (BVH: spoon-torso, harness-torso, head-spoon, carry-proxy-chest/spoon, below-floor
   verts, patch detachment) + loop seam (pose and tangent) + foot contact drift for planted feet. Fix one axis at a time in
   the source; record before/after. Fix the Phase 1 finding too: the chest band must hug the torso (no visible floating ring
   from front/rear; allow <= 0.2 cm embed), re-rendering `review/phase2/views/front.png`/`rear.png`.
4. Render contact sheets (every 2nd-4th frame) under `review/phase2/clips/<Clip>_sheet.png` for ALL 34 clips, side view, plus
   front for Turn*/Startle/Backstep/Rear* and three-quarter for Snatch/Loaded*/DeathTopple*/DeadHold. Look at them yourself
   against sheets 04/05/06 and iterate at least two rounds on BoundCycle, Rummage/Snatch, LoadedBound and DeathTopple.

### B. Export + Blender round trip - `scripts/export_pantry_rat.py`, `scripts/validate_roundtrip.py`, `export/`
- Bind `export/PantryRat_R01_Mars_SK.fbx` (LOD0 mesh + 26-bone armature, rest pose), one FBX per clip
  `export/anims/PantryRat_R01_<Clip>_Mars_ANIM.fbx` (armature + mesh + exactly ONE action), static
  `export/PantryRat_R01_Den_Mars_SM.fbx` (shell + recess plane as two material slots `Stone`, `Void`; the eye plate as a
  separate `export/PantryRat_R01_DenEyePlate_Mars_SM.fbx` quad with UV 0..1), `export/PantryRat_R01_Cheese_Mars_SM.fbx`
  (slots `Rind`, `Flesh`). Use the cellar bat's COMMON/BIND/CLIP/STATIC recipe verbatim (`Armature` rename, selection,
  `bake_anim_use_all_actions=False`, `use_armature_deform_only=True`, `armature_nodetype='NULL'`); record every exporter
  argument + FBX header version in `export/validation/export_settings.json`.
- Manifest `export/PantryRat_R01_Manifest.json`: bones/parents, slot order, bind bounds, per-clip {frames, seconds, loop,
  additive, landmarks at key frames}, Carry_Mouth and Carry_Drag restated in the UE socket frame (parent bone `jaw`,
  relative location/rotation in UE cm, computed from the Blender bone-space values in RIG.json / measurements.json via the
  (x, -y, z) map and the bone-axis convention you prove on the round trip), den/cheese bounds, the marker Empties in UE cm.
- Round trip into a fresh background scene: 26 bones/names/parents, bind heads within 0.1 cm, tri count, slot order, bounds,
  34 clips with the right frame counts and a landmark bone pose at 3 frames each. Write `export/anims/roundtrip_report.json`.

### C. Rat-local Masked looks (shader + AS), shared Eyes untouched
- `Shaders/Looks/PantryRatSurface.ush`: a SurfaceLit flat-colour look (Color vector param, non-CPD) with the BusterBlock
  dither verbatim: `if (FadeAlpha < 1.0) { O.OpacityMask = (CkUsf_IGN(In.UV * 512.0) < FadeAlpha) ? 1.0 : 0.0; }`
  (`CkUsf_IGN` is in `/CkUsf/Common.ush:530`). FadeAlpha is a Scalar param, `_CustomPrimitiveData = true`,
  `_CustomPrimitiveDataIndex = 14`, `_DefaultScalar = 1.0`.
- `Shaders/Looks/PantryRatEyes.ush`: includes `/Project/Looks/EyePlate.ush`, calls `Mars_Look_EyePlate(...)` with the SAME
  positional signature and CPD indices 0..13 (copy the parameter block of `Mars_Eyes_Look_Assets.as` exactly), then applies
  the same FadeAlpha/CPD14 mask. Blend mode Masked, SurfaceUnlit, `_UsedWithSkeletalMesh = true`.
- `Script/ECS/PantryRat/Mars_PantryRat_Look_Assets.as`: `asset MarsPantryRatSurface of UCkUsf_LookDefinition` and
  `asset MarsPantryRatEyePlate of UCkUsf_LookDefinition` (pattern: `Mars_Eyes_Look_Assets.as`; `_GeneratedPackageRoot =
  "/Game/Mars/Materials/GeneratedLooks"`), plus `namespace utils_pantry_rat_look { Look_Surface(); Look_EyePlate(); }`
  accessors and a `Make_SlotColors()` table (Body #5A4553, Pink #D97B86, Belly #E9D5C1, Wood #A8683B, Harness #6E4327).
  Document CPD 14 as the rat fade slot in the file header; nothing else on the rat primitive may use 14.
- Generate the two masters in the live editor (`Ck_Usf_GenerateLooks MarsPantryRatSurface` / `MarsPantryRatEyePlate` via
  `editor_query run_console_command`, or the generator subsystem from run_python - read the CkUsf CLAUDE.md first) and PROVE
  they compile: `material_query recompile_material` on each master returns success, and the live log has no
  `shader compile error` naming them. If MarsEyePlate itself fails to compile in this editor, STOP the eye half, record the
  exact log lines, and continue with the surface look.
- Add `Script/Tests/PantryRat/Mars_AutoTest_PantryRat_LookMastersResolve.as` modeled on
  `Script/Tests/Eyes/Mars_AutoTest_Eyes_LookMasterResolves.as` (reads the two masters through the accessors, asserts blend
  mode Masked and that a MID exposes FadeAlpha) - headless, no mesh needed.

### D. Unreal candidate - `scripts/pantry_rat_import_ue.py` run through `editor_query run_python {mode: execute_file, unattended: true}`
- Import under `/Game/ArtCandidates/PantryRat/R01/{Meshes,Materials,Animation,Props,Review}` only: SK + new SKEL (bones 26,
  root identity, every bone scale 1, forward +X: nose at max X, withers 35.3 +- 0.5 cm, slot order Body/Pink/Belly/Wood/
  Harness/EyePatch), per-slot MIDs on `M_CkUsf_Look_MarsPantryRatSurface` with the slot colours and the EyePatch slot on the
  `M_CkUsf_Look_MarsPantryRatEyePlate` master (raw master, as the chef does), sockets `Carry_Mouth` and `Carry_Drag` on `jaw`
  via `animation_query add_socket` (never raw Python add_socket), the 34 ANIM sequences with loop flags (additive banks as
  additive, reference IdleBreath frame 0), den/plate/cheese static meshes with simple collision. Readback JSON
  `export/unreal_readback.json`: every count above, the socket world location at rest vs Blender world rest (19.8, 0, 20.6)
  within 0.5 cm, clip frame counts/lengths vs the manifest, and a landmark bone transform at 3 frames per clip vs Blender.
- Pocket depth measurement (Phase 1 finding 2): place `SM_PlayerBackpack` at scale 1.25 in the review map, pocket face toward
  +X of the rat, and `mesh_query query_raycast` from 60 cm in front of each Pocket socket toward it; record the surface-to-socket
  depth per pocket. Numbers only; no design change.
- Review map `/Game/ArtCandidates/PantryRat/R01/Review/PantryRat_R01_Review_MAP` built and saved through run_python like the
  cellar bat's (never `run_console_command` level load/new level): floor, two walls, den SM + plate quad with the SHARED
  `M_CkUsf_Look_MarsEyePlate` master (opaque; set its CPD 0..13 by hand to cells 19/19 strength 6 amber), three rat
  SkeletalMeshActors with CPD14 = 1.0 / 0.5 / 0.0, a fourth rat whose EyePatch CPD shows cells 20/20 (X) with LookX/blink 0,
  a fifth with asymmetric cells (left 2, right 19) to PROVE the eye-patch left/right halves (Phase 1 finding 3), a real
  `Mushroom_Prep_Mars_SM` beside the fading rat, the real backpack, `NeutralSun/NeutralSky` and the amber/teal lights from the
  cellar bat review map, cameras. Captures (`editor_query capture_scene_preview`, static poses are fine): neutral and
  amber/teal lighting, close-ups of alpha 1/0.5/0, the X eyes, the asymmetric eyes, and the solid mushroom beside the
  half-faded rat. LOOK at every capture and iterate: fine UV-anchored speckle at 0.5, nothing at 0, food solid, exactly two
  eyes per rat, X readable. Also look for Phase 1 finding 3 (embedded knee geometry showing mid-fade); report what you see.
- Playback proof: SkeletalMeshActors with single-node animation for BoundCycle, Rummage, Snatch, LoadedBound, DeathToppleLeft,
  DeadHold, DenEmerge; capture via `capture_pie_movement_clip` / `run_pie_smoke` with a camera (the cellar bat PROGRESS says
  `capture_anim_frames` returns the bind pose - do not use it as evidence). Keep PIE runs short (<= 20 s), stop PIE after
  each, and restore the previously open level the way the bat script did.
- Save ONLY the assets you created (`EditorAssetLibrary.save_loaded_asset`), never Save All. The map save runs the Jolt cook
  hook and writes `/Game/CkJoltData/ArtCandidates/PantryRat/...`; that is expected, report it.

### E. Reload proof + Toolbox evidence
- `Script/Tests/PantryRat/Mars_AutoTest_PantryRat_CandidateAssetsReload.as`: loads the SK, SKEL, all 34 ANIMs, the MIDs, den
  and cheese meshes by path (soft refs resolved at test time), asserts bone count 26, slot order, 34 clips with the manifest's
  frame counts, FadeAlpha param present on a rat MID. Run it through the Toolbox: that headless editor is a FRESH process, so
  a green run IS the cold-read proof (the live editor cannot be restarted by you). Add a per-test
  `Get_ExpectedLogErrors` only for a line you can name.
- Toolbox runs, detached per VALIDATION.md's template (new run dir each, `--project=D:\Repositories\CkRepos\Orion\Mars.uproject
  --test --no-live --discover-fresh --test-pattern=<X>`), AFTER your final `.as`/`.ush` saves and with no further script
  edits until Exit.json exists: (1) `PantryRat` (your two tests must be discovered - a 0-test run is not a pass),
  (2) `Eyes` (the two listed known reds `Mars_AutoTest_EyesDummy_ComposesAndWrites` and `Mars_AutoTest_Eyes_LookMasterResolves`:
  report Still red / Now passing / NEW by name, and whether your change touched them - it must not). Read `[population]`,
  `=== Known reds ===`, `Contaminated:` and the exit code from the real log; a notification is not a result. Warn in your
  report that AngelScript edits must be frozen during each run.

### F. Records
- `PROGRESS.md` Phase 2 section (this folder): rerun commands, the 34-row quantised clip table (frames/seconds/loop/audit
  numbers), fixes before/after, export recipe + FBX version, round-trip and Unreal readback summaries, socket frames, pocket
  depths, look generation evidence (log lines, recompile results), capture list with what you saw, PIE playback evidence,
  Toolbox run dirs with exit codes and named results, deviations, what remains unverified. Mark each claim confirmed/inferred.
- Update `docs/art/pantry-rat-dens-production-r01/ANIMATION_MANIFEST.csv` durations to the quantised values (keep 34 rows,
  add `frames` and `samples` columns) and note it in PROGRESS.

## Hard rules (editor-killing operations learned on this machine - never do them)
- No level load / new level / `Automation` via `run_console_command`; build the map in run_python as the bat did.
- No deleting, force-deleting or reloading a loaded Blueprint/asset; no `unload_packages`; no raw `SkeletalMesh.add_socket`.
- No PIE while the editor window is minimised (3 fps); keep runs short; stop PIE every time.
- Freeze `.as`/`.ush` edits during any Toolbox run (hot reload beside the headless editor contaminates it).
- Fix the source, never the render. No new species, no fur, no extra bones. Shared Eyes/atlas/EyePlate untouched.
- Every script prints `PANTRY_RAT_OK` / `PANTRY_RAT_FAIL <reason>`; exit non-zero on failure. Long Blender runs in the
  foreground with a generous timeout; split clip groups if a run would pass 10 minutes.

## Reporting back (final message)
Files created (paths); rerun commands; the clip table summary (34 rows authored, quantised durations, loop seam results);
round-trip result; Unreal readback numbers (bones, slots, sockets vs expected, clip counts); pocket depths; look generation
and recompile evidence; which captures to look at first and what each proves; PIE playback evidence; Toolbox run dirs,
exit codes, named results incl. the two Eyes known reds; what remains unverified; the one claim you would most expect to be wrong.
