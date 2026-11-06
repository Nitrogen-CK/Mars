# Phase 5 brief - candidate-only Unreal import of the final bat, readback, reload, reimport

Read `PROGRESS.md` (every phase and audit; Phase 2 proved the export recipe and a candidate importer pattern on the
blockout, Phase 4 produced the final exports and the manifest), the prompt's Phase 5 section in
`docs/art/flying-units-r01/MODEL_ANIMATE_IMPORT_PROMPT.md`, `PRODUCTION_SPEC.md` section 5, and the existing code:
`scripts/cellar_bat_validation_ue.py` (Phase 2's importer + readback, your starting point),
`Tools/Blender/mars_send_to_unreal/unreal/mars_character_ue.py` (legacy FBX importer with the Interchange flag
restored in a finally), `Tools/Blender/mars_monsters/pale_crawler_r01/pale_crawler_ue.py` (materials from a manifest,
reload proof, asset-registry collision checks). Inputs: `export/CellarBat_R01_Manifest.json`, `export/CellarBat_R01_Mars_SK.fbx`,
`export/CellarBat_R01_LOD1_Mars_SK.fbx`, `export/CellarBat_R01_LOD2_Mars_SK.fbx`, `export/anims/CellarBat_R01_<Clip>_Mars_ANIM.fbx`
(18). All Unreal work goes through Monolith `editor_query run_python` (`{"command": ..., "mode": "execute_file",
"unattended": true}`); confirm the project path `D:/Repositories/CkRepos/Orion/Mars.uproject` and PIE off first; never
run during PIE; writes only under `/Game/ArtCandidates/CellarBat/R01/` (`Meshes/`, `Animation/`, `Materials/`,
`Physics/`); save only those assets; never Save All; restore every importer/console flag in a `finally`.

## Deliverable: `scripts/cellar_bat_import_ue.py` (candidate importer + validator) and its run record

1. **Materials**: one master material `CellarBat_R01_Mars_M` (vertex colour RGB as base colour, vertex alpha as
   cavity/AO multiplier, scalar `Roughness`, `Specular`; `TwoSided` switch via a static parameter or a second master
   `CellarBat_R01_TwoSided_Mars_M`; `Eyes` emissive from a vector parameter with a scalar intensity) and three
   instances `CellarBat_R01_Body_Mars_MI` (rough 0.85, spec 0.25), `CellarBat_R01_Membrane_Mars_MI` (two-sided,
   rough 0.8), `CellarBat_R01_Eyes_Mars_MI` (restrained emissive #FFC570, intensity ~3). Readback each parameter.
2. **Bind mesh**: import `CellarBat_R01_Mars_SK.fbx` as SkeletalMesh `/Game/ArtCandidates/CellarBat/R01/Meshes/
   CellarBat_R01_Mars_SK` creating skeleton `CellarBat_R01_Mars_SKEL` (new, dedicated; do not reuse the Phase 2
   validation skeleton), `normal_import_method = FBXNIM_IMPORT_NORMALS`, vertex colours REPLACE, morph targets ON (the
   manifest says none; assert 0 after import), `create_physics_asset = False` then build `CellarBat_R01_Mars_PHYS` with
   ONE capsule/sphere body on `spine` (or `pelvis`+`spine`) sized to the torso, no wing bodies, and assign it. Bind the
   three slots by name to the instances. Add sockets `Mouth` (head, at the manifest's mouth offset), `RoostFootL`/
   `RoostFootR` (foot_l/foot_r) and `Perch` (pelvis, at the hang contact). Set bounds: import LODs 1 and 2 onto the same
   mesh (`import_lod` route of the FBX importer or `SkeletalMeshEditorSubsystem.import_lod`), set LOD screen sizes
   (1.0 / 0.35 / 0.15 as a start), then extend the bounds (`positive_bounds_extension`/`negative_bounds_extension`) so
   the spread and deepest-downstroke poses are contained (compute from the manifest's pose bounds or from the clips'
   max bone extents).
3. **Clips**: import all 18 FBXs as AnimSequences `/Game/ArtCandidates/CellarBat/R01/Animation/
   CellarBat_R01_<Clip>_Mars_ANIM` against `CellarBat_R01_Mars_SKEL`, 30 fps, bone tracks on, no root motion
   (`root_motion_mode = NO_ROOT_MOTION_EXTRACTION`), loops flagged (`RateScale 1`; mark looping in the manifest; add a
   `bLoop`-style note). Set `BankLeft`/`BankRight` additive: `additive_anim_type = AAT_LocalSpaceBase` with
   `ref_pose_type = ABPT_ANIM_FRAME`, ref pose = `CellarBat_R01_Hover_Mars_ANIM` frame 0 (`animation_query
   set_additive_settings` or the Python properties). Add notifies as plain markers at the manifest's marker frames
   (`ReleaseContact`, `FootContact`, `ScreechSound`, `Wingbeat`) with `animation_query add_notify` (no sound assets:
   silent hooks named `<Marker>_Silent`).
4. **Readback** (`export/unreal_readback_final.json`): mesh bounds (span 75 +/- 0.5 cm in the reference pose, nose at
   +X), ref-pose root identity and all bone scales 1, 42 bones with exact parents, material slots in order with their
   instances, LOD count 3 with per-LOD triangle counts matching the manifest, morph count 0, sockets, physics bodies
   (1-2, on spine/pelvis), per-clip: frames/samples, fps, length, track count 42, root track stationary (sample `root`
   at 5 times through `animation_query get_animated_bone_transform` or `get_bone_track_keys`), loop seam
   (`frame 0 == last` for the loops per the manifest convention), additive type/ref for the banks, notifies. Compare
   against the manifest and print a pass/fail per item.
5. **Reload proof**: hash the saved `.uasset` files, unload the packages (`EditorAssetLibrary` unload / `unreal.
   EditorLoadingAndSavingUtils.unload_packages`), reload, re-run the readback, compare. Then run the whole import
   again (reimport path, `replace_existing = True`) and prove: same asset count under the root (no duplicates, no
   `_1` suffixes), materials still bound, bone order unchanged, every clip still points at the same skeleton,
   sockets intact. Record both passes.
6. **Captures through Monolith** (`editor_query capture_anim_frames` for Hover, Launch, Perch/RoostIdle, Swoop,
   BankLeft/Right applied, both membrane sides; `capture_scene_preview` of the mesh under neutral and amber/teal
   lights if a preview scene is available) into `review/phase5/`. LOOK at them. Note: the `InRHITexture` engine
   ensure can break the editor into Visual Studio on a first viewport read; if the editor freezes, report and wait.
7. `PROGRESS.md` Phase 5 section: commands, the readback table, reload/reimport proof, capture paths, deviations,
   unverified items.

Rules: no git state changes; no `AutomationGate.json` edits; no `run_console_command` level ops; no PIE; no edits to
`Script/` (the runtime executor owns it) or to the Blender scripts. Report: assets created (paths), readback table
pass/fail, reload/reimport results, capture files to look at, what remains unverified.
