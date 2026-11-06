# Phase C brief - Unreal candidate import through Monolith, materials, sockets, readback, review room

You are the Opus executor for Phase C of the Screaming Turnip R01 campaign. Read first: `PROGRESS.md` (Phase 1
facts incl. the editor-killing operations, decisions D-1..D-5, Phase A audit, Phase B section), `PHASE_B_BRIEF.md`
(what the exports contain), `export/ScreamingTurnip_R01_Manifest.json`, `export/anims/clips.json`,
`export/anims/expected_anims.json`, `export/validation/expected.json`, and the precedent you adapt:
`Tools/Blender/mars_monsters/cellar_bat_r01/scripts/cellar_bat_import_ue.py` (stages, `_LegacyFbx`, `_sk_opts`,
`_anim_opts`, `import_mesh`, `_build_master`, `create_materials`, `bind_materials`, readback, owned-asset accounting,
`save_loaded_asset` only), `cellar_bat_r01/PHASE_5_BRIEF.md`, the bat PROGRESS Phase 5 section (readback table,
incidents I-3/I-4), `Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_review_ue.py` (review room through
`run_python`, restore_level) and `Tools/Blender/mars_monsters/pale_crawler_r01/pale_crawler_ue.py` (static meshes,
materials from a manifest, reload proof).

Route: Monolith MCP (`mcp__monolith__*`). Discover schemas before use (`monolith_discover('editor')`,
`describe_query action_schema`). All Unreal writes go through `editor_query run_python {"command": "<abs path to
scripts/screaming_turnip_import_ue.py> <stage>", "mode": "execute_file", "unattended": true}`; sockets through
`animation_query add_socket` (never raw Python `add_socket`); readback through `animation_query get_skeleton_info /
get_sequence_info`, `mesh_query`, `project_query get_saved_asset_state`, `editor_query list_dirty_packages`.
Preflight every stage: project == `D:/Repositories/CkRepos/Orion/Mars.uproject`, PIE off, dirty packages listed
before and after (yours only). Never: level load via `run_console_command`, `unload_packages`, deleting/force-deleting
/reloading a loaded Blueprint, Save All, writes outside `/Game/ArtCandidates/ScreamingTurnip/R01/`.

## Deliverables (`/Game/ArtCandidates/ScreamingTurnip/R01/`, names per D-1)

1. **Materials** `Materials/ScreamingTurnip_R01_Mars_M` (master: BaseColor = VertexColor.RGB ^ `VertexColorGamma` 2.2 x
   lerp(`CavityFloor` 0.45, 1, VertexColor.A), scalar `Roughness`/`Specular`, Metallic 0, `used_with_skeletal_mesh`)
   and instances `ScreamingTurnip_R01_{Skin,Leaf,Mouth,Teeth}_Mars_MI` (Skin rough 0.85 spec 0.25; Leaf rough 0.7 spec
   0.3 two-sided via the MI override; Mouth rough 0.9 spec 0.1; Teeth rough 0.5 spec 0.4) plus `TurnipBed_R01_Mars_MI`
   (Soil: rough 0.95 spec 0.1) on the same master (static mesh usage flag too). Read back every parameter.
2. **Skeletal mesh** `Meshes/ScreamingTurnip_R01_Mars_SK` from `export/ScreamingTurnip_R01_Mars_SK.fbx` (legacy FBX
   importer, Interchange flag off in a finally, `FBXNIM_IMPORT_NORMALS`, vertex colour REPLACE, `convert_scene=True`,
   uniform scale 1, new dedicated skeleton renamed `Meshes/ScreamingTurnip_R01_Mars_SKEL`, `create_physics_asset=False`
   - the item's collision comes from the static hull, no PHYS asset needed; if the importer insists on one, create it
   minimal and record it). Bind the four slots by name to the instances. Bounds extension from the manifest's global
   clip envelope (+2 cm margin). Sockets on the SKEL via `animation_query add_socket`: `Grip_L`, `Grip_R`, `MouthCue`,
   `SoilLine`, `HarvestGrip_L`, `HarvestGrip_R` with the manifest's bone + transform; read back component-space
   positions at bind and assert against the manifest within 0.1 cm.
3. **Statics** `Meshes/ScreamingTurnip_R01_Collision_Mars_SM` (import as StaticMesh, generate simple collision =
   convex from the mesh itself, assign a plain hidden-safe material; add static-mesh sockets `Grip_L`/`Grip_R` at the
   manifest transforms so the Phase D/E producer can read them), `Meshes/TurnipBed_R01_Mars_SM`,
   `Meshes/TurnipBedEmpty_R01_Mars_SM` (Soil MI bound, simple box/convex collision). Read back bounds vs the manifest.
4. **Clips** `Animation/ScreamingTurnip_R01_<Clip>_Mars_ANIM` x15 against the SKEL: 30 fps, bone tracks, no root motion,
   loop flag from the manifest, rate 1; read back keys == N+1, length == N/30 s, 17 tracks, root identity at 5 samples,
   loop seams (QuietIdle, RecoveryIdle, SRC_Idle, AirborneLeafTrail) first == last, and the body/cheek scale at the
   peak frames of Inhale/Scream equals the manifest (proves non-uniform bone scale imports). Chain check: Anticipate
   f0 vs QuietIdle f0, Scream f0 vs Inhale last, etc., within the manifest's deltas.
5. **Cube** `Validation/Cube10_Mars_SM` bounds 10.000.
6. **Reload + reimport proof** as the bat did: readback saved to `export/unreal_readback_final.json`; reimport all with
   `replace_existing` -> identical readback, no `_1` duplicates; the reload proof is a cold readback after the
   maintainer's next editor restart (write the `reload` stage; do NOT unload packages).
7. **Review room** `Review/ScreamingTurnip_R01_Review_MAP` built by `Tools/LevelDesign/screaming_turnip_r01_review/
   screaming_turnip_review_ue.py` (`build_review_scene()` / `restore_level()`, bat pattern): a 1200 x 1200 x 400 room
   (floor top at Z 0, ProtoGrid walls), neutral sun/sky plus an amber key and a teal fill, three static displays of the SK
   (neutral, with a placed bed; one rotated 90 deg on its side on the floor; one at hand height 45 cm in front of a
   `PlayerStart` for the first-person-scale check), the two beds, and - once Phase D's `Mars.ScreamingTurnip.BuildReviewRoom`
   command exists - its entity actors placed through the entity-spawner factory (planted bed entity, floor slab,
   PlayerStart) so Phase E/PIE can play there. WorldSettings game mode override = the sandbox's `/Script/Angelscript.Mars_Gameplay_GameMode`
   (`Config/DefaultEngine.ini:17` maps the `Sandbox_Mars_` prefix to it; the review map's name has no prefix, so set
   the override through Monolith `editor.author_map_settings`). Save only the review map. Captures: Monolith
   `capture_scene_preview` of the SK (bind) front/side/three-quarter/mouth close-up, and of the review room from the
   PlayerStart; animated frames through Monolith are known to return the bind pose (bat Phase 5) - do not claim motion
   from them; motion is proven numerically (item 4) and visually in PIE later.
8. Write `scripts/screaming_turnip_import_ue.py` with stages `materials`, `mesh`, `statics`, `clips`, `readback`,
   `reimport`, `reload`, `all`; and fill the Phase C section of `PROGRESS.md` (assets table, readback table with
   expected/got/PASS, sockets, captures, incidents, deviations, not verified).

## Hard rules

- Writes only under `/Game/ArtCandidates/ScreamingTurnip/R01/` and `Tools/Blender/mars_ingredients/screaming_turnip_r01/`
  + `Tools/LevelDesign/screaming_turnip_r01_review/`. No git operations. No edits under `Script/` (Phase D/E own it; the
  asset-path swap in `constants_screaming_turnip_assets` is done by the Phase E executor from your final paths - list
  them exactly). Never touch another folder's assets; never Save All; restore every flag in a `finally`.
- The editor is live and other work may be open in it: check `list_dirty_packages` before each stage and refuse to
  proceed if a package outside your root is dirty AND your stage would save (report instead).
- If Monolith refuses or an engine call fails twice with evidence, record the exact error, finish the independent
  deliverables, and report the boundary. Never retry a crashing call; if the editor dies, stop and report (the
  maintainer relaunches: `CkAuto/UnrealToolbox.exe --launch-editor --project D:/Repositories/CkRepos/Orion/Mars.uproject`).

## Reporting back

Assets created (full paths); readback table (expected/got/PASS per row: bounds, bones, root pose, scales, sockets,
slots, clips keys/length/seams/scale peaks); the exact asset paths for the Phase E swap; captures to look at; incidents;
what remains unverified (animated view, PIE). Confirmed vs inferred on every claim.
