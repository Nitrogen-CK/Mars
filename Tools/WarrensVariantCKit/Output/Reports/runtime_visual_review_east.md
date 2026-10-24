# Final runtime visual review — east / remaining rooms

Reviewed the twelve actual 1600x1000 PNGs listed below, all modified **after 2026-10-24 17:40:00 UTC**. No older room image was used. Files were inspected at their original exposure, without brightening. No Unreal/Blender calls or asset edits were made.

**Result: this capture batch does not justify complete visual sign-off.** The Pump and Cistern show readable local assemblies. There are concrete remaining image issues in the Larder, Catacomb and bell views, and the Lair/Vault captures do not expose enough of their rooms to assess them. Darkness alone is not a request to brighten the whole map; the relevant player-lantern state and a useful camera position must be established first.

The supplied saved-UE audit counts were not rechecked here and are not pixel evidence. No movement, collision, interaction, animated gate or multiplayer claim follows from this review.

## Actionable findings

1. **Confirmed pixels — Larder still exposes a blue grid patch.** In [ROOM_larder.png](/D:/Repositories/CkRepos/Orion/Tools/WarrensVariantCKit/Output/Runtime/ROOM_larder.png), the left lit doorway contains a blue rectangular grid surface, approximately pixels x350–530/y450–610. This is distinct from the green water in the foreground. It needs a source/component ownership check before claiming all visible prototype surfaces are covered. **Unconfirmed cause:** retained prototype material, an intentional puzzle surface or a view through to another district. Identify the actual surface before changing it.
2. **Confirmed pixels — Catacomb ceiling has strong jagged triangular seams.** In [ROOM_catacomb.png](/D:/Repositories/CkRepos/Orion/Tools/WarrensVariantCKit/Output/Runtime/ROOM_catacomb.png), the illuminated upper-left ceiling is dominated by thin black/light triangular slivers and interleaving facets. Similar, less stark repeated triangular seams appear in the Sluice and Cistern ceiling views. This is substantially noisier than the broad quiet surfaces of [MODEL14](/D:/Repositories/CkRepos/Orion/docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL14_FloorAndCeilingSkins.png). **Unconfirmed cause:** geometry overlap, stitching, normals or lighting. A still image cannot prove z-fighting or self-intersection; inspect the affected saved ceiling geometry and compare the same camera after a targeted correction.
3. **Confirmed pixels — the high bell reads near-white against an unreadable support assembly.** [ROOM_belfry.png](/D:/Repositories/CkRepos/Orion/Tools/WarrensVariantCKit/Output/Runtime/ROOM_belfry.png) and [ROOM_bell-loft.png](/D:/Repositories/CkRepos/Orion/Tools/WarrensVariantCKit/Output/Runtime/ROOM_bell-loft.png) show a very bright pale bell interior while the yoke/upper attachment remain nearly black. The clapper is a visible dark silhouette in the loft view, and the open mouth is now visibly established. The bright bell works as a beacon, but its brass material and load-bearing assembly are much less readable than [MODEL23](/D:/Repositories/CkRepos/Orion/docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL23_LandmarkBellConstruction.png). Review the **local** bell light/material contrast if the intent is a metal bell rather than a luminous fixture. Do not infer emissive settings or a broken material from these pixels alone.
4. **Confirmed evidence gap — Lair and Vault views are obstructed.** [ROOM_lair.png](/D:/Repositories/CkRepos/Orion/Tools/WarrensVariantCKit/Output/Runtime/ROOM_lair.png) is predominantly black with large close blue-gray planes and only a small lit opening at bottom right. [ROOM_vault.png](/D:/Repositories/CkRepos/Orion/Tools/WarrensVariantCKit/Output/Runtime/ROOM_vault.png) is mostly close dark forms with a narrow bright wedge and small floor patches. Neither proves the room, route, door sweep or intended dressing is readable/clear. **Inference:** the chosen camera may intersect nearby geometry or point through an occluder; confirm its actual runtime position before treating this as missing art. Recapture from a valid player position with the intended lantern state.
5. **Needs joint check — Sluice angled timbers do not visibly meet the upright tops.** In [ROOM_sluice.png](/D:/Repositories/CkRepos/Orion/Tools/WarrensVariantCKit/Output/Runtime/ROOM_sluice.png), three diagonal pieces end offset from the separate upright tips. They can be wall-mounted elements, so this is **not confirmed floating geometry**. A side/oblique view should establish their wall attachment or matching brace/post joints. The center approach is visibly open in this still; physical clearance is outside this review.

## Room-by-room observations

| Capture / UTC | Confirmed from pixels | Limit / next useful observation |
|---|---|---|
| Reliquary — 17:40:47 | Closed stone tomb rests on the lit tiled floor; lid/body contact reads continuous. Foreground approach is unobstructed in this frame. Distant shelves/rails are silhouettes. | Stair, reward target and mill-drop landing cannot be accepted from this camera. Source calls for one tomb and generous approach space; visible tomb placement is consistent with that local intent. |
| Mill — 17:40:50 | Octagonal mill drum and its lower timber feet are visible on the floor. Vat/station is partly visible at right. Center floor lane is open in the image. | Chute, axle, drying rack and actual hand/tool working area are not readable enough to confirm their support/contact or P7 access. Do not promote the isolated drum view to a whole-station pass. |
| Catacomb — 17:40:53 | Tomb body and a separate lid lying to its left are visible. This preserves the visual distinction from the closed Reliquary tomb. | Camera is too low to see into the open tomb. Ceiling seam issue above needs review. The Court crawl/Pit connection is not shown. |
| Belfry — 17:40:56 | Tall piers, open vertical space and the high illuminated bell are visible; no solid wall closes the bell mouth in this view. | One pier partly occludes the bell. Yoke, suspension joints, roof hangers and chime mounts are too dark to inspect. Brightness issue above. |
| Bell loft — 17:40:59 | Hollow bell mouth and hanging clapper silhouette are visible together. Piers and open vertical volume frame the landmark. | Capture looks upward; it does not establish key plinth, ladder arrival, loft floor clearance or the across-canal clue. Roof/chime top attachments are not visible enough for sign-off. |
| Cellar — 17:41:02 | A small pool of floor light and a few low faceted rock/salt forms are visible, with distant lamp points. | Most boundaries/storage are black. Their support and the route cannot be assessed. Establish intended lantern state and a closer useful view before requesting a lighting change. |
| Sluice — 17:41:05 | Shelving sits at the left wall; the low floor-chain anchor/route detail is visible near center. Foreground floor lane is clear in the image. | Angled timber joint check above. Existing control/gate moving leaf and full travel pocket are not exercised or clearly shown. |
| Larder — 17:41:08 | Broad green water surface stays within a visible perimeter edge; no new stepping stones are visible in the foreground. Lit left opening supplies orientation. | Blue grid patch above. Submerged floor/depth and the larder-to-bell roof sightline are not established from this mostly dark angle. |
| Pump — 17:41:11 | Pump body stands on a readable base; diagonal feet meet that base. Wheel is attached to the body. Wall pipes have visible collars and a line of supporting brackets. Left connector appears visually open. | Pipe termination and the upper tower beyond this framing are not fully visible. No obvious detached pump part is demonstrated in this capture. |
| Cistern — 17:41:14 | Basin rim follows the shallow green water, with tiled bed visible through it. Water/rim contact reads continuous in the shown corners; small ripple accents remain on the water. Right bank walkway is visible. | A thin vertical dressing element at the right bank is visible, but its top attachment is outside readable detail. Ceiling seam pattern above remains. Actual wading depth/clearance is not measured by the image. |
| Lair — 17:41:17 | Large close planar occluders and a small lit lower-right opening are visible. | Invalid/insufficient room review, as above. No conclusion about roots, hoist view, cavern support or escape-route clearance. |
| Vault — 17:41:20 | Small lit floor fragments, a narrow bright angled surface and close dark geometry are visible. | Invalid/insufficient door/room review, as above. No conclusion about door mounting, key-lock access, door sweep or vault interior. |

## Reference grounding

The current [room_dressing.json](/D:/Repositories/CkRepos/Orion/docs/art/warrens-c-dressing-r01/room_dressing.json) calls for supported wall pipes outside the humped connector, a shallow 0.4m Cistern/Larder rather than a new hazard, a high bell near +16m with a separate accessible loft, and an open Catacomb tomb. Those contracts guide the observations; they do not prove what a dark/occluded image fails to show. [MODEL20](/D:/Repositories/CkRepos/Orion/docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL20_DeepAndShallowWaterAssembly.png) supports the visible shallow-water/bed distinction. [MODEL24](/D:/Repositories/CkRepos/Orion/docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL24_ServiceBellsAndBoneChimes.png) requires visible rail/bracket/rope load paths for chimes: these twelve frames do **not** expose those upper attachments well enough to confirm them.

## Capture identity

All dates are 2026-10-24 UTC; SHA256 values identify exactly the reviewed PNGs.

| Room | SHA256 |
|---|---|
| reliquary | `de0a8f1ed8a846e59d7a1a7b5a74ef57aa5a4896b02b3acb75eef53528dc55db` |
| mill | `c3f5175c5825d9a6a789d796156bcccea260f075ca567b8c36393d6a9ab5938b` |
| catacomb | `f17aea718a4d71d3a5f7e2c427df9917fac7145659a06505800399d4a43f3951` |
| belfry | `b3690d576c967dac4b0d5a4b29ef69e1f6a4fbe8446997761b576315e3411d57` |
| bell-loft | `4adc80b94b532d03ba8173987675fdd6350ef56fa3110a9f508ce16d18209c18` |
| cellar | `51fffd2431413a537d891e7ab20c754b6b056fc0437bbd569ab22d4f3dff3ee3` |
| sluice | `6b74fe68fa3069a54c76fbb6a2dd2d65fc22457adc2c5a7c73ba715de062d3f4` |
| larder | `8d8d486ec5df2d381dd4f2836cf47c6d7a483dc2e176818036985948995273bd` |
| pump | `b190c1414cb94e1cc0ebeff635ceb93650cbf0ae1c991b15cab4228ebc1f4571` |
| cistern | `497e13fe5cdcb7c7b8cb370fd3e45ce9d5679fdd7ffe108f8e97597a9bb078ef` |
| lair | `6809f720dbe897ac9d1281af448dd883e550c706931601b9b5cf2e6950f6e8d4` |
| vault | `2ecac52a00b1cba425d8be07b50214222eb5372fcf562795dbd8bb44196b115a` |

No files other than this report were authored for this runtime review. Main thread owns diagnosis, fixes and recapture.
