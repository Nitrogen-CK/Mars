# Phase 3 — useful local routes, rewards and work positions

Take V0's complete phase-entry source/data/map/Jolt checkpoint before any mutation.

**Entry:** Phase 2 geometry/static and changed-surface observations pass. Recheck V1/V2 and latest map/data hashes. Read listed AS guidance and canonical Toolbox skill. Capture current targeted test discovery/results before changing source; close this project's editor before build. If relevant baseline failures exist, STOP and record names/ownership rather than claiming a clean baseline.

**Change paths:** v7 generator/geometry and builder; NEW `Script/WorldObjects/Anchors/Mars_Warrens_AnchorPresets.as`; NEW focused tests under `Script/Tests/Anchor/` with `AnchorCandidate_Warrens` in names; generated live plan/map; evidence. Existing station, generic gate, pressure-plate, wheel, item and global anchor-table files are read-only dependencies.

1. Create one map-specific route asset and subclass, following `Mars_Anchor_Presets.as:137–214` exactly:

   ```angelscript
   asset Mars_AnchorTable_WarrensRoute of UMars_AnchorTable_Def
   {
       Family = EMars_Anchor_Family::Route;
       Rows.Add(FMars_AnchorTable_Row(TSubclassOf<UCk_EntityScript_UE>(), 6.0f, EMars_Anchor_Role::Open));
       Rows.Add(FMars_AnchorTable_Row(UMars_Anchor_Rubble_EntityScript, 2.0f, EMars_Anchor_Role::Closed));
       Rows.Add(FMars_AnchorTable_Row(UMars_Anchor_OneSidedLeverGate_EntityScript, 4.0f, EMars_Anchor_Role::Open, EMars_AnchorRow_Need::LeverSide));
   }
   class UMars_Warrens_Anchor_Route_EntityScript : UMars_Anchor_Route_EntityScript
   {
       protected UMars_AnchorTable_Def Get_Table() const override
       { return Mars_AnchorTable_WarrensRoute; }
   }
   ```

   Builder selects this class only for v7 Warrens R anchors. Do not copy candidate implementations, change shared row order or repurpose debug pins. The plan's role solver remains authoritative; one-sided gates still require authored lever side and crawl geometry. Add two focused tests: only role-compatible/eligible rows can be drawn; an instantiated one-sided candidate opens permanently from its valid far-side control and supports sequential access. Use existing anchor/candidate rig patterns, not a new harness architecture.

   **Gate:** generic table unchanged; seven v7 R placements use the new class; no ordinary two-sided lever candidate appears; new tests exercise actual candidate behavior. **Pass → continue; any mismatch → STOP.** The three-row table intentionally has its own indices; fixtures must record those actual indices rather than reuse old global row numbers.

2. Preserve PK/P2/P3/P5/SC2 mechanics. Change their local geometry/labels to the PROMPT contract: a PK drive path connects two shutters; P2's matching symbol appears at wheel and remote bars; P3 shows one occupancy. Place one fixed tallow in Mourner and two in Vault, each on its own stable rest and separated from random spawn positions. Keep existing Red key/lock. Add one existing Pan beside each entrance kit so the selected entrance supplies one; do not place tools behind closed inactive mouths as supposed shared kit. Use manifest entity rows and existing item classes; no new item mechanics.

   **Gate:** the fixed rewards can be seen before the optional cost, touched/retrieved after release, and do not intersect random-cache bodies or keys. PK remains 2-second release and latched; P2 moves bars without changing water; a single actor/pack releases P3. **Pass → continue; wrong effect/missing reward → STOP at that specific placement.** Bellkeeper remains old P4 until Phase 4; do not remove its cache early.

   Add **one authored `UMars_Expedition_MushroomBed_EntityScript`** to Grotto's reachable shelf apron, using its existing SpawnTransform, 35 cm strike height and 180-second regrowth defaults (`Script/WorldObjects/Forage/Mars_Expedition_MushroomBed_EntityScript.as:1–18`; base `Mars_ForageVine_EntityScript.as:10–78`). Start on the dry south approach to the mineral shelf, outside its solid bounds x[-13,-7], y[17.5,19.5]; Phase 1/2 support measurement fixes the exact floor Z and point. Reserve a 2.4 m standing/retrieval bay and keep the inherited basin/fruit volume out of through traffic. Replace any misleading “required crown harvest” note with “optional existing mushroom forage.” This is separate from random forage and the static crown/vent. Observe a Pan strike or existing valid knock releasing an actual mushroom, then retrieval and pack loading; actor presence is not proof. **Pass → continue; invalid support/reach/drop recovery → adjust within the same dry apron once, otherwise STOP.** No forage source behavior changes; scoped Forage tests are required only if such a change is separately authorized.

3. Replace only matching kitchen blockout station/bench boxes with `UMars_CuttingStation_EntityScript` and `UMars_SearingStation_EntityScript`, using the sandbox placement pattern at `Mars_SandboxMapBuilder.as:576–594`. Place the two existing platter classes from `:680–681` on receiving rests. Follow AREA_SPEC transforms and measured dock/operator/camera envelopes. No changes to station source, recipes, serving, grading or combat are authorized.

   `[EDITOR-VERIFY]` Feed existing compatible meat/food through the reused operations in a temporary labelled fixture; remove fixture-only food before shipping. One person prepares while the other uses the second station/receiving area; swap. Also complete both operations sequentially with one person. **Expected:** visible existing cutting/searing output, usable grips/docks/camera, no crossing operator bodies or blocked cargo port. **Pass → continue; within the bounded slide rule → adjust and rerun; otherwise STOP with envelope evidence.** A known unrelated station behavior issue is a content dependency, not permission for a cooking overhaul.

4. Regenerate the live JSON and AS plan, then run the source gate in VALIDATION V3: build+AnchorCandidate tests, then relevant AnchorResolver, Gate and KeyLock families in separate Toolbox invocations. Existing baseline counts are discovery-derived; new focused route tests add two. Reapply/audit only after successful source compilation and discovery. Re-run the static validator and physical local control/fixture observations on the final files.

   ```powershell
   Set-Location 'D:/Repositories/CkRepos/Orion/Tools/LevelDesign/anchor_plans'
   python -B design_warrens_v7.py
   python -B emit_plan.py warrens
   python -B validate_warrens_two_player.py
   ```

   **Expected:** actual Toolbox exits/logs show zero new failures; old defaults remain unchanged; final scene matches manifest. **Pass → exit. Any failure or stale/secondary-process evidence → STOP and record; do not launch a full suite as a substitute.**

**Exit:** routes have distinct arch/rubble/scout semantics, fixed local gates are honestly presented, Vault/Mourner fuel and entry Pan exist, two useful kitchen work positions operate locally. Cache pool remains four until Phase 4. No claim about a complete meal/service loop or network behavior.

**Rollback:** restore only phase-owned source/builder/data hunks and the map checkpoint after checking later edits. Remove newly introduced route class/test files only if unused; leave generated wrappers to the supported regeneration workflow. Do not reset unrelated generated dirt.
