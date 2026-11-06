# Phase 6b-1 brief - review map, first real PIE flight with the blockout, kernel hardening

Phase 6a (headless kernel/HFSM/tests) is done and audited: read `PROGRESS.md` (Phase 6a section, the audit and the
incident), `PHASE_6_BRIEF.md` for the architecture, and the code under `Script/ECS/Bat/`,
`Script/WorldObjects/Monsters/Mars_CellarBat_EntityScript.as`, `Mars_SandboxBat.as`,
`Script/Editor/Mars_CellarBat_MapBuilder.as`, `Script/Tests/Bat/`, and
`Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_review_ue.py` (never run yet). The editor is running again
(Monolith at `http://localhost:9316/mcp`; re-confirm the project path `D:/Repositories/CkRepos/Orion/Mars.uproject`
before any write). The final mesh/clips/AnimBP are NOT ready (a Blender executor is producing them); this phase proves
the runtime in PIE with the Phase 2 blockout skeletal mesh that already exists:
`/Game/ArtCandidates/CellarBat/R01/Validation/CellarBat_R01_Blockout_Mars_SK` (42 bones, 75 cm span, +X forward) and
its clip `CellarBat_R01_Blockout_Flap_Mars_ANIM` (16 frames, loops).

## Work

1. **Kernel hardening (two small edits, keep tests green):**
   - In `utils_bat::Issue_Move` stamp the crowd MoveTo's `_CorrelationId` with `Route.Generation`; in
     `UMars_Processor_Bat_Setup` ignore `OnGoalFailed`/`OnGoalBlocked` answers whose info payload carries a different
     correlation id (read `FCk_CrowdAgent_GoalFailedInfo` / `GoalBlockedInfo` in
     `Plugins/CkFoundation/Source/CkCrowd/Public/CkCrowd/Agent/CkCrowdAgent_Fragment_Data.h`; if they carry no id,
     leave `OnGoalReached` as is and document it).
   - In `UMars_Processor_Bat_Tick::TickSwoop`/`Sweep` also stop and end the swoop (`Died`) when
     `Monster.Get_BodyHealth().Get_IsDepleted()` is true, not only when the Dead attribute has latched.
   - Re-run `--test --test-pattern Mars_AutoTest_Bat_` (fresh, `--discover-fresh` if the list is stale) and
     `--test-pattern Monster`; quiescence protocol applies (no `.as` saves during a run).
2. **Review map, built through `editor_query run_python` only** (NEVER `run_console_command` with a level
   load - that hung the editor). Run `cellar_bat_review_ue.py` (`build_review_scene`) to create and save ONLY
   `/Game/ArtCandidates/CellarBat/R01/Review/CellarBat_R01_Review_MAP` with: floor, walls, ceiling, a perch beam
   with the roost entity script actor, a pillar between perch and dummy, a hostile `UMars_TargetDummy_EntityScript`,
   the flight volume entity actor covering the room, the bat spawner (a `Mars_SandboxBat.as` preset with FlightNodes
   around the room), a PlayerStart and the neutral + amber/teal light rig (pale_crawler_ue.py AMBER/TEAL values). Spawn
   AngelScript entity-script actors the way `Script/Editor/Mars_MapBuilder_Utils.as` does it in Python terms:
   `unreal.EditorLevelLibrary.spawn_actor_from_class(unreal.load_class(None, '/Script/Angelscript.<Class>'), ...)` or
   `EditorActorSubsystem.spawn_actor_from_object(...)`, and set exposed spawn params on the spawner. Fix the script
   until it runs; after it returns, restore the previously open level (`restore_level`) so the maintainer's Sandbox
   map stays open. Verify with a readback (actors by class and location) saved to
   `Tools/LevelDesign/cellar_bat_r01_review/review_map_readback.json`.
3. **Stand-in visuals:** make the review preset point `Mesh` at the blockout SK above and give the entity script a
   way to play a single looping clip when no AnimBP class is set (`PlayAnimation(clip, true)` on the component, as the
   Steward does) so the bat flaps in PIE. Keep the final asset paths as the defaults; the preset overrides them.
4. **Real PIE:** load the review map through run_python (`unreal.EditorLoadingAndSavingUtils.load_map`) and start PIE
   via Monolith (`editor_query start_pie` / `run_pie_smoke`; read the schemas first with `describe_query
   action_schema`). Then sample the running bat: use `editor_query pie_get_object_properties` /
   `animation_query sample_pie_timeseries` / `run_python` reading the bat entity's phase through the spawner actor or
   log lines (the kernel broadcasts phase changes; add a verbose log line per phase change in the entity script if
   none exists) to record the sequence Roost -> Alert -> Launch -> Approach -> Telegraph -> Swoop -> Recover -> Return ->
   Brake -> Perch -> Roost with timestamps and locations, plus the dummy's OnDamaged count (exactly 1 per swoop). Capture
   `capture_pie_movement_clip` / `capture_scene_preview` PNG frames into
   `Tools/LevelDesign/cellar_bat_r01_review/captures/` showing the bat flying and swooping. Then exercise in the same
   or a second PIE run: kill the bat mid-flight (apply damage through run_python on the entity's Health; record Falling
   -> Landed and that no damage follows), and block the route (move the pillar into the corridor before PIE and record
   the explicit route outcome). Stop PIE at the end (`stop_pie`) and make sure PIE is off before you finish.
   If the flight volume reports `NoBake` or `EndpointUnresolvable` in PIE, diagnose it (the bake needs the Jolt static
   world to contain the walls: check the `[N] static bodies` summary line in the log, `_PIEStaticWorldMode`, mobility,
   collision profiles) and fix the map/entity scripts, not the kernel.
5. Update `PROGRESS.md` (Phase 6b-1 section): commands, test exits, the PIE phase timeline with numbers, capture paths,
   what failed and what is still unverified. Mark claims confirmed/inferred.

## Rules

- Writes only under `/Game/ArtCandidates/CellarBat/R01/` (plus the Script files you own from Phase 6a and the two
  Tools folders). Save only the review map and nothing else; never Save All; no git state changes; no edits to
  `AutomationGate.json`; never `run_console_command` for level operations; no editing of Blender-track folders
  (`Tools/Blender/mars_monsters/cellar_bat_r01/scripts|source|export|review`).
- If PIE through Monolith hangs the editor again, stop: record the exact call and the log tail in PROGRESS.md and
  report; do not kill the editor.
- Use PowerShell for the toolbox (background, long timeout) and Bash for everything else.

## Reporting back

Test exits (names), whether the review map exists on disk and what it contains, the PIE phase timeline and hit counts,
capture file paths, the blocked-route and death outcomes observed, and what remains unverified.
