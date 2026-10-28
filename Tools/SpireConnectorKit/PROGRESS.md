# Spire production progress

## Complete: model delivery and single-player PIE acceptance

All four source Level Instances passed post-fix PIE acceptance in the isolated R02 map with persistent collision proxies. Source visual Level Instances remain NoCollision; basecamp integration uses the persistent collision helper.

## Confirmed results

- Baseline:10 normal-chef traversal cases passed. Safety sweeps found4 missing main roof colliders;741 rail and24 doorway sweeps passed.
- Fix: production.py now generates shared COL_R600_Roof and COL_R700_Roof and places12 sectors per assembly in persistent collision recipes. Rebuilt/imported105 meshes, including29 collision assets and516 convex hulls.
- Final PIE:18 chef traversal/yoke cases and9 cases with the110x220cm design-envelope capsule passed.1080 stair waypoints;39700 recorded movement frames, all Walking. No route teleports, jumping, stalls or falls. Setup relocation is explicit between separate cases.
- Physical guard contacts:16/16 passed with the actual78x150cm chef capsule.
- Final safety sweeps:769/769 passed. The same4 failing roof checks now hit the new roof colliders. No initial overlaps; other765 checks remain green.
- Fresh Blender:405 surface/bore rays and1167 sampled220cm headroom rays passed;105 marked assets, manifold collision proxies.
- Final native reload audit:105 meshes; all2359 source transforms checked; source visual counts163/166/156/1874. Native kit library refreshed to105 meshes; diorama2219 visual instances. Native simple-collision floor rays389/389 passed.
- Unreal Toolbox:40 focused CkJolt tests passed,0 failed/skipped/contaminated, process exit0. Saved/Logs/Spire-PIE-CkJolt-Test.log. No C++/AngelScript edits or engine rebuild.
- Class-default capsule still39cm radius/75cm half-height after gauge tests. Live camp/Warrens protected hashes unchanged. Source spire maps saved after owned reimport updates. No commit or push by this task.

## Evidence

Output/Reports/pie_acceptance.json aggregates and hashes all27 final traversal/gauge reports. Output/PIE/final/physical_guards.json records physical guard contacts. Output/PIE/final/geometry_sweeps.json records final runtime safety sweeps. Raw frame samples, events and actual PIE screenshots are retained in final-chef and final-gauge folders. Output/Reports/delivery.json binds delivery hashes and validation reports.

The saved test map is /Game/Mars/Environment/SpireConnectorKit/Maps/Spire_PIEAcceptance_R02_Mars_MAP. The older baseline map and all baseline failure reports are retained separately. Unreal is left on the comparison diorama after tests; PIE stopped.

## Reusable tools and recovery

Build.ps1 rebuilds/validates Blender and FBX outputs. import_unreal.py checks source ownership, hashes, bounds, slots and convex counts. unreal_scenes.py authors source/library/diorama maps and places persistent collision. pie_acceptance.py provides the real-pawn traversal/gauge suites; pie_geometry_audit.py sweeps runtime geometry; pie_guard_contact.py presses the chef into rails; pie_report.py verifies report completeness.

An editor authoring crash was caused by holding Package wrappers from save_packages across NewLevel. All maps were saved beforehand. save_dirty_owned_maps scopes/releases wrappers and returns strings before any subsequent map switch. The user dismissed the restart dialog; final PIE and subsequent map switches completed successfully. Raw crash evidence is retained under Output/PIE/crash-20261027-193521.txt.

## Limits

Validated: automated single-player PIE at the declared source scale/shape with normal movement and a separate enlarged clearance gauge. Unverified: packaged CkJolt lookup, co-op passing space, performance and subjective keyboard feel. Current CkJolt transient Level Instance lookup restriction remains; keep collision in a stable persistent integration map. Existing camp server travel is unchanged. Props/central flue/root/basket remain visual dressing; no lift or new travel behavior was added.
