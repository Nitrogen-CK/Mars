# East-room runtime pixel review r03

Inspected all twelve original 1600x1000 room PNGs at their saved exposure, dated **2026-10-24 18:11:58-18:12:31 UTC**. No image was edited or brightened. Only this report was written; no AS, assets, maps, Unreal calls, or tests were touched.

**Result:** the visible ceiling, Larder grid, and bell contrast issues are improved in this batch. No new definite unsupported or disconnected assembly is established by these images. The remaining limitations are the Vault/Cellar visibility and several unexposed attachment/route details; this is not whole-level clearance or interaction acceptance.

## Confirmed changes and remaining findings

- **Ceilings:** Catacomb, Sluice, and Cistern now show broad rectangular soffit surfaces, without the earlier conspicuous interleaving triangular sliver field in their illuminated regions. Catacomb's upper-left surface is especially clear. Fine seams/stippling remain visible; these stills do not establish temporal flicker. The new quieter plane improves continuity against [MODEL14](D:/Repositories/CkRepos/Orion/docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL14_FloorAndCeilingSkins.png), inspected during this review. This is a pixel result, not verification of how the ceiling geometry was produced.
- **Larder:** the formerly blue rectangular ProtoGrid patch in the left opening is absent. A quiet dark lower surface and a warm lit passage above/behind it now occupy that region (approximately x350-530/y430-620). No conspicuous blue grid replacement appears elsewhere in this frame. The exact TX09 binding and gate actuation are source/runtime-audit facts owned by main; they cannot be proven from this image alone.
- **Bell:** the loft shows a gold faceted hollow mouth, a dark clapper silhouette, and a distinct rim. The interior is still the brightest part, but is no longer an undifferentiated near-white patch. Cooler light now reveals stone piers and upper crossmembers, improving the visible tower load path. The yoke/root attachment remains partly in silhouette; chain/hanger tops and bone-chime mounts are outside useful detail. [MODEL23](D:/Repositories/CkRepos/Orion/docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL23_LandmarkBellConstruction.png), inspected here, is the joint/material reference. No further light change is justified by these stills alone.
- **Vault evidence gap persists:** a large close warm plane at right, dark doorway/central silhouette, and a partial floor path remain visible. The revised image is less fragmented than the prior reviewed view, but does not expose door hinges, lock access, full sweep, or the interior. A close wall/door can be intentional; there is no confirmed intersection or missing asset diagnosis. A useful opposite/oblique player view would resolve this if visual acceptance of the vault door is required.
- **Cellar evidence gap persists:** only a small lit floor island and low faceted forms near center are readable. Storage support and passage layout remain black at the captured exposure. Establish the intended player-lantern state before interpreting this as a lighting defect.
- **Sluice joint detail remains ambiguous:** the diagonal timber ends do not visibly join the nearby upright tops (most apparent around x570-655/y300-345 and x950-1025/y300-345). They may be independent wall-mounted elements. The frame establishes neither floating parts nor a continuous post/brace joint; a side view or saved attachment audit would decide. The earlier quiet-ceiling issue is resolved in the shown area independently of this joint question.

## Twelve-room observations

All paths below refer to `Tools/WarrensVariantCKit/Output/Runtime/ROOM_<room>.png`. Observations describe visible pixels only.

| Room / UTC | Confirmed visible continuity and layout | Remaining limit |
|---|---|---|
| Reliquary / 18:11:58 | Closed tomb lid/body/base form a continuous assembly seated on the lit floor. Broad foreground approach is empty in this view; distant upper platform/rail silhouettes remain. | Stair arrival, upper access, and back side of tomb are not established. |
| Mill / 18:12:01 | Faceted mill drum has visible timber feet meeting the floor; partial vat/station sits at right. The illuminated central floor lane is open. | Chute/axle, back supports, drying rack, and full working area remain unexposed. |
| Catacomb / 18:12:04 | Tomb body and separate lid on the floor at left remain distinct from the closed Reliquary assembly. Body base contacts the floor. Overhead soffit is now continuous rectangular panels. | Camera remains below the rim, so the open cavity cannot be independently confirmed here. Crawl and Pit route are outside view. |
| Belfry / 18:12:07 | Tall continuous piers, arched/crossmember silhouette, chains, and the bell occupy the open vertical volume. Cooler exterior illumination reveals structure beyond the warm interior. | One pier partly occludes the bell; upper attachment and hanger endpoints are too dark or cropped. |
| Bell loft / 18:12:10 | Open bell mouth, inner facets, rim, and clapper silhouette are visible together. Tall piers and upper crossmembers now read around it. | Upward framing does not establish loft floor/ladder/key access or roof/chime attachments. |
| Cellar / 18:12:13 | Small central floor island and several low faceted forms are visible, with distant light points. | Room boundaries, storage supports, and traversal path cannot be assessed at this exposure. |
| Sluice / 18:12:16 | Shelf cluster rests at the left wall; floor-chain anchor/low detail is near center. Broad lit approach remains open in the frame. Flat soffit spans the room. | Diagonal/upright relationship above remains ambiguous. Moving gate pocket/control access is not exercised. |
| Larder / 18:12:19 | Green water stays below the visible perimeter edge. The warm left opening supplies orientation and no longer contains the blue grid patch. | Gate movement, submerged bed/depth, and Larder-to-bell roof sightline are not shown. |
| Pump / 18:12:22 | Pump body, diagonal feet, and plinth meet visibly. Wheel sits on the body. Pipes connect at collars and have repeated wall supports. Left passage is visibly open. | Far pipe terminations, full upper assembly, and physical route clearance are outside the image proof. |
| Cistern / 18:12:25 | Shallow green water overlays a visible tiled bed; perimeter rim and right bank form a continuous edge. Right wall, upper rail, and broad soffit are readable. | Slender bank-side pole/element has no readable top attachment; bank and wading clearance are unmeasured. |
| Lair / 18:12:28 | Revised camera exposes a broad uninterrupted tiled foreground floor and a distant warm-lit opening around a pier. The previous close blue-gray occluder no longer dominates. | Most cavern boundaries/organic dressing remain dark. Hoist reveal, roots, and the full escape path remain unproven. |
| Vault / 18:12:31 | Partial floor path, left masonry plane, central dark doorway/shape, and large warm right plane are visible. | Door construction, hardware, sweep, interior, and full approach remain insufficiently exposed. No geometry fault is established. |

## Source grounding and scope

[room_dressing.json](D:/Repositories/CkRepos/Orion/docs/art/warrens-c-dressing-r01/room_dressing.json:330) preserves the supported wall-pipe system and source 0.4m Cistern pool; [the Undercroft contract](D:/Repositories/CkRepos/Orion/docs/art/warrens-c-dressing-r01/room_dressing.json:1017) preserves the floor-chain tell, 0.4m Larder water, and bell roof sightline. Pump/Cistern pixels support local assembly continuity; they do not measure source dimensions. The Larder roof sightline and high chime attachments remain uncaptured rather than failed. No claim is made about collision, door travel, headroom, actual wade depth, physics, gameplay, multiplayer, or packaged behavior.

The earlier report supplies the previous inspected observations; its referenced runtime filenames have since been overwritten by this fresh batch. It is not a preserved image baseline or a matched-image comparison artifact.

## Capture identity

All times are 2026-10-24 UTC. Each capture was checked newer than 18:11:00 UTC before review.

| Room | SHA256 |
|---|---|
| reliquary | `b86a4569dcb0570dd8d10b1514010da704182d17e3029faa442cadd5df0730f2` |
| mill | `14059c0a6bac5c57c21e275dd34604006d3e88ea2b05a17e09e068bc4cece8a9` |
| catacomb | `28f09da8926e66c4eabf7027d1ab5beb993e73a952cdc2674e1e3584c47fcc70` |
| belfry | `578c3caca277c23e3010021bc4bce2e210fb6e0d022d39687c216bc013c7798a` |
| bell-loft | `09127c327b0d067e0d8a48a2624e8f79918d540cac3a7dc7caaf01bdca4bdebe` |
| cellar | `c03c849af7165d73030f43bf44a4b25f6cc6810e11396b584839ec5f1560a141` |
| sluice | `4d76ca675e06c2cb6c8c7fbc860e9ad7d0fa80248aa2ac535c0d3887d50bb029` |
| larder | `0766015db2adf5d26561d72791d932b5e5541d688f82f63f846948e4991a2573` |
| pump | `2d659d4da56114104c88158772e0091fbb2212f8a8cba8d992d1063982fe9207` |
| cistern | `2833fba90a6cf6eb0ef555e4746920e50992e1d55ad384247db815fab09d75a6` |
| lair | `ebb0007e59c648b15248f2a8febe5694086791829dc3f0ae88dbd2388ee14a04` |
| vault | `94e245a290411165e91013905958196214262c5bbced7e3e4601a096c854f81d` |

Main owns any follow-up observation or correction. This review introduces no new requested asset/map change.
