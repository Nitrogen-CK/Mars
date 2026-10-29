# Steward service selection progress

Revision 3: focused tests, functional capture, full route and mission travel/return/reset passed. Settled front/side drape captures and the reading HUD screenshot were visually reviewed. Local logical commits requested; no push.

## Current architecture

- Existing catalog, Camp GameMode/controller authority and atomic replicated party state own service selection/travel. Four dishes target canonical Warrens. Hosted return retains selection; ReturnToMenu resets it.
- Camp-only corrected body variant, existing skeleton, separate 6s/181-frame holding loop. Original SK/SKEL remain unchanged. Parchment root (55,0,175), 80 x 90 cm flat reading face; forward lower drape reaches within 1.003 cm of the floor and partly unrolls. Static authored geometry, no cloth simulation.
- Persistent 800 x 900 world-space widget, scale .095, anchor world Z156; plane top198.75/bottom113.25. Contracts camera (0,-865,179), looking at (0,-1055,179), FOV58. Prompt/outline/resolver focus clears only for CampMenu; candidate tracking continues for Back reacquisition. Other view holders retain their contracts.
- Original camp arch contained Barred and Extraction overlays at (1200,-200,0), yaw90. Only those surveyed instances were replaced by owned CampOpenArch_Mars_SM. Shared source assets unchanged; frame retains three explicit collision hulls (posts and 30cm threshold). The single gate is now (1220,0,0), unit root, 240 x 300 cm opening, 12 bars.
- Persistent HISM Hearthscrew visuals/collision plus lamps and lower-post backwall: 60 owned groups. Existing outer seam cap (1640,-200,0) remains raised360cm as a lintel. This seam is distinct from the original inner arch. Source kit unchanged.
- UE mesh collision blocks CharacterMovement; explicit Jolt boxes on separate entities remain for loose objects. Gate projects committed valid service; preview cannot open it.

## Evidence

- Baseline CampSession 4/4, exit0: Saved/Logs/StewardBaseline.log. Earlier native Toolbox build succeeded; no C++ edits since.
- Revision3 Interactable: 14/14, 0 failed/skipped/contaminated, exit0,42s: Saved/Logs/StewardRevision3InteractableTests.log. Includes CampMenu clear/reacquire focus regression coverage.
- Revision3 Camp: 8/8, 0 failed/skipped/contaminated, exit0,39s: Saved/Logs/StewardRevision3CampTests.log. Focused tests, not a full suite.
- Fresh Output/Runtime/review.json passed: actual visible idle prompt/outline, hidden prompt/outline during reading, restored on Back, same persistent WidgetComponent before/after, preview leaves gate closed, Confirm commits DillBroth, original gate blocks at x1174.73 and continuous open crossing reaches x1990.90 from x850. Menu operations use raw gameplay Use and WidgetInteraction Slate keys.
- Fresh capture session pie_smoke_5_213703: complete120.013s,158 frames, captured_ok=true, zero runtime error/ensure counters, expected success marker present. Current MP4 re-encoded from its first functional sequence; 3,481,760 bytes, all frames decoded. Full reading screenshot visually includes Confirm/Back/status. Actual Shot showui capture Output/Runtime/10_Reading_HUD.png also shows the prompt and outline absent while reading.
- A route harness start at camp origin landed on existing central scenery and could not move; this was test setup, not arch contact. Revised start is x850 inside camp, with continuous production capsule traversal through original arch and every source tread waypoint; no traversal teleport. Passed172/172 waypoints in45.0731s, radius39/half-height75. Route session pie_smoke_6_213934 completed with zero runtime error/ensure counters.
- Open-frame import saved/readback has904 triangles and3 explicit convex hulls, no central visual blocker. Output/Arch/saved_asset_verification.json. Prop-only import preserves character/animation hashes; Output/Art/protected_character_hashes.json and Output/import_report.json.
- Independent read-only audit found no concrete P1/P2 issue in CampMenu focus lifetime, expanded UI or arch replacement idempotence. Repeat placement saved successfully with60 groups.

## Historical evidence and limits

Earlier correction proved injected Enhanced Input single pointer row/Confirm clicks with All/CaptureDuringMouseDown; this is not hardware mouse input. Earlier travel/return/reset, lower-post departure UI and Devour before/after checks passed; they are distinct from current route evidence. Original route started beyond the inner arch and did not prove that barrier; revision3 fixes that proof gap.

Gauntlet StewardMissionTravelReturn remains blocked before execution by unrelated procedural plugin AS boot errors (Saved/Logs/Gauntlet/20261028-171143/StewardMissionTravelReturn_r1.log). Remote clients/late joins, packaged behavior and separate loose-Jolt contact remain unobserved. No broad plugin fixes or Git delivery.

Rollback: use Output/Revision3/Camp_Before_Arch_Revision.umap for the pre-revision3 map and revert only owned source/assets. Initial feature backup remains Output/Baseline/Camp_Mars_MAP.umap. Preserve unrelated submodule/source dirt.

Revision3 travel_review.json passed in10.1000s: arrived Warrens with service, hosted return retained service/open gate, ReturnToMenu cleared service/closed gate. The combined visual session had failed optional camera-creation probes; its travel report and HUD screenshot are valid separate artifacts, not a passing aggregate visual-session claim.


Final settled drape capture session pie_smoke_10_214601 used a temporary PIE camera only. Front/side PNGs show the floor apron and curl; actual interaction framing remains the saved Contracts endpoint. Local MP4/PNG/FBX/Blender products follow repository global ignore rules and remain available on disk; safety backup maps are explicitly ignored. The editor reports no dirty map. The new present animation has an incidental in-memory dirty flag after PIE; its on-disk SHA256 remains2edcf3a61d90f179493dc289ba56c63901e6ee1b4b7d9310742cd7e8cec929bb, the validated import being committed.
