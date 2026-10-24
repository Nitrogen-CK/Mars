# Variant C full-level dressing: source review

The checked-in plan inventories **11 Level Instances, 24 rooms, 26 source prop recipes, seven puzzles, 46 ports, 11 explicit ramps, 72 route links, nine low links, four scout crawls, two ladders, ten sightlines, seven windows and 21 continuity checkpoints**. All 45 linked concept/model/district images exist. This is an offline source plan; it is not a full-level runtime acceptance result.

`zone_plan.json` contains exact source coordinates, envelope dimensions, catalog names, model links, protected records and camera candidates. Its source hash pins the reviewed `Tools/LevelDesign/anchor_plans/data/warrens_v8c.json`. Authoritative art sources are `docs/art/warrens-c-dressing-r01/ROOM_DRESSING.md`, `room_dressing.json`, `assembly_recipes.json` and `prop_catalog.json`.

## Integration order and ownership

1. Capture all 11 actual saved Level Instances before writing. Resolve pivots and source components from that snapshot, rather than assuming logical room ownership or nominal tile rectangles.
2. Fit every owned saved floor height, source floor-voxel side, wall union face, roof underside and exact rotated ramp. Do not crop entire tiles to their declared rectangles: WaterworksW already contains frontier floors outside its rectangle, and the Cistern continues into Hub. Brineworks owns Undercroft geometry beneath Canal.
3. Reuse the current ChainCrossingKit and PumpCisternKit art under one explicit owner policy. Avoid stacking two shell veneers, two water surfaces or duplicate lamps over the same surface. Superseded owned art can be regenerated; original authored actors/collision remain authoritative.
4. Replace the 26 authored proxy silhouettes using the source recipes below. Keep gameplay-owned plate/key/glyph/gate/vat art attached to the actual runtime owner, with moving and static parts separate. A static substitute is not acceptance of the real mechanism.
5. Review the 24 room cameras, ten protected views, scout/pack passages and 21 boundary checkpoints. Adjust individual fixture reach/intensity from game cameras, then inspect continuity in a connected whole-level pass.

Do not introduce new walk collision, routes, ladders, boats, extra platforms, fake controls, additional objectives or a painted puzzle answer. Local decorative skins remain `NoCollision`.

## Zone identity and source assemblies

| Zone / logical rooms | Source-grounded assembly placement | Required references and protected read |
|---|---|---|
| Hub / hall, closet, four Well rims | Hoist `[40,55.5,0]`, envelope `1.6x1.6x7.5m`; pack plinth `[10,47.5,0]`; tallow `[12,46,0]`. Fit H01 frame, H02 pulley, H03 drum, H04 hook to one connected mechanism. Optional H05 cage may not imply a new rideable lift. | ENVC-01/11, MODEL02/36, DRESS01. Preserve the open `[34,44]-[46,56]` shaft, closet opening and five intersecting landmark/clue views. |
| Court / outer Court, sunken hunt floor | H14 SplitMourner at `[15,88,0]`, `2x1.2x4.5m`. Keep outer rim Z0 and center Z-1.5 distinct. One existing-source silhouette is stronger than a new crate maze. | ENVC-01, MODEL11, DRESS02. Preserve R1/R6, retreat width and Court-to-Ossuary stair. |
| Ossuary / ossuary, bridgehead | Bone shelving `[52,68,2.5]` and `[50,76,2.5]`, each `6x1x2.6m`; I06 plate `[42,66,2.5]`, `2x2x.3m`; tallow `[54,66,2.5]`. P29 is the related Mourner plaque. | ENVC-03/06, MODEL08/10/11, DRESS03. P3 latches; the image must not suggest a player must remain on the west plate. Preserve R5 bridge mouth and southeast window. |
| Waterworks-W / pump, Cistern | Reuse the source-fitted PWC pump at `[54,22,-2.5]`, `2x2x6m`, and roof root `[24,34,-2.5]`, `1.2x1.2x5m`. Cistern water/bed and bank are actual saved geometry. | ENVC-05/10, existing PumpCisternKit concepts/fit, DRESS04. Preserve humped low connector, R4/R6 approaches, Sump Stair and Chain gate. |
| Pit / lair, vault | Root envelope `[35,46,-5]`, `1.4x1.4x14m`: repeat short connected modules; tallow `[22,58,-5]`. P1 Vault door stays `[57,60,-5]`, span250cm. | ENVC-12, root/door model families, DRESS05. Preserve `pit-hoist`, one-way closet ladder and all four approaches; no climbable root escape or scenic stepping stones. |
| Canal / ford-w, ford-e, crossing structures | Bone Bridge source ramp `[62,74,2.5]` to `[84,74,2.5]`, width3m. Chain fixed route `[66,26,-2.5]` to `[96,24,-2.5]`, width2.5m. Existing tallow `[82,50,0]`. Use repeated A11/A12/A13 rib/deck/edge skins, not a new bridge. | ENVC-03/04/05/11, MODEL04, DRESS06. Exactly three crossing beats: Bone Bridge, always-open Ford and controlled Chain Crossing. Preserve both towers and the clue ray. |
| Belfry / belfry, bell loft | Tower `[104,50,0]`, `4x4x22m`, high bell near+16m; clue backing `[102,50,2]`, `.3x4x2m`; key plinth `[104,60,2.5]`; panel `[108,46,0]`; chimes `[98,54,0]`, `6x.2x3.5m`; tallow `[90,46,0]`. | ENVC-02/07, MODEL03/10/23, DRESS07. Catalog H06 crown/H07 bell/H08 yoke/H09 clapper. Key remains on reachable loft, not under the high bell. Do not cover the west clue face. |
| Reliquary / reliquary | H15 closed tomb `[88,84,2.5]`, `3x1.5x1.2m`; P3 gate `[100,76,2.5]`. Supporting storage only after real closed-wall fitting. | ENVC-06/07, MODEL11, DRESS08. Keep gate reward, mill-return landing and authored loft rail-drop approach clear. |
| Mill / mill | I12 curing vat `[88,106,5]`, `2.4x1.6x1.4m`; H11 millstone `[95,100.5,5]`, `2.5x2.5x2m`; H12 chute and I13 lid are separate parts. Source P7 owns the work island. | ENVC-08/09, MODEL06/37-r02, DRESS09. Keep pack staging and hand plane open. Do not move the required vat into the Brine Larder. |
| Catacomb / catacomb | H15 open tomb `[-18,80,0]`, `3x1.5x1.2m`; separate lid arranged inside its source envelope. One source tomb, sparse background urns only after wall/floor fitting. | ENVC-12, MODEL11, DRESS10. Preserve scout Court crawl and four winding dive ramps; no new vertical ladder. |
| Brineworks / cellar, sluice, larder, Undercroft | Reuse fitted Chain art: chain tell `[110,20,-2.5]`, `24x.4x.2m`; intended P2 wheel proxy `[122,12,-2.5]`; salt `[100,16,-2.5]`, `2x2x1.4m`. Larder remains a shallow store with one empty background rack. | ENVC-05/09, MODEL05/09, DRESS11 and corrected Chain section sheets. Preserve larder-to-bell roof view, source chain and R3/R7 scout access. No second curing objective. |

Every catalog ID in the JSON resolves to its actual name and model-sheet link. Supporting pieces are **conditional closed-wall candidates**, not permission to scatter props at guessed room centers. The 26 authored anchors are concrete assembly placements; optional storage needs the actual source wall/support fit first.

## Images that contradict the catalog or source

Confirmed by visual inspection:

- **DRESS01 labels are unreliable.** It calls A10 a service notice, P25 a storage rack, I20 a ladder and D15 a stone arch. Catalog A10 is ParapetCap200, P25 RecipeNoticeBoard, I20 CampPackPlinth and D15 RopeCoil. Use its layering and silhouette; resolve models from `prop_catalog.json`.
- **DRESS02 swaps identity.** H14 is illustrated/labeled as rock foundation and P26 as the statue; catalog H14 is SplitMourner and P26 RoyalServiceBanner.
- **DRESS03 depicts misleading component IDs.** Its chef/P29 and plate/P11 labels do not define assets. Catalog I06 is PackPlateHousing, P29 MournerSealPlaque, P11 a bone resource. The source plate is static latch input, not a pressure platform requiring a permanent chef.
- **DRESS07 mislabels almost the entire tower family.** Its I07 ladder is not the catalog I07 GlyphFaceInsert; catalog H07 is HighLandmarkBell, not the pictured roof. Use MODEL03/catalog for identities and actual 22m landmark envelope; do not relocate key or panel to match the exploded picture.
- **DRESS09 reverses important Mill IDs.** Its H12 vat and I12 millstone conflict with catalog H11 MillstoneDrum, H12 SaltChute and I12 CuringVat. Corrected MODEL37-r02 agrees with the catalog. Its extra upper loft/stair/landing is a visual assembly idea, not authored traversal.
- **DRESS10 invents a Catacomb ladder and swaps H15 to a rock shell.** Source has Catacomb dive ramps, and H15 is Sarcophagus. Use the low, irregular shell and open tomb mood only. Do not add that ladder, drop shaft or water pit.
- **DRESS11 labels I03 as a chef and W01 as a stone wall.** Catalog I03 is the wheel family and W01 the chain family. Its new timber platforms and screw-gate arrangement do not supersede the actual rising-bars/lever runtime contract.
- **ENVC-02 hangs a key from the high bell.** Source places the collectible on the +2.5m loft; the high bell is a distant +16m landmark. No duplicate collectible or unreachable objective.
- **ENVC-04/08/12 contain attractive extra stones, docks, ladders, boats and lofts.** They are not source routes. The source determines which three crossings and two ladders exist.
- **ENVC-12 paints a flooded Vault/Pit.** No source Pit water body exists: water records are Canal, Ford, Cistern and Brine Larder only. Retain the dry authored Pit rather than making a new deep hazard or scenic basin.
- **P2 remains a documented source/runtime mismatch.** Design asks for Sluice handwheel; the earlier actual snapshot had a lever-driven gate at Z0 and no Sluice wheel spawner. Recheck current live ownership. Art cannot silently repair this by adding a second control or frozen moving leaf.

Written source contracts override these pictures. MODEL36 and corrected MODEL37-r02 are useful mechanical references because their named frame/pulley/drum and mill/vat parts agree with the catalog.

## Surface and attachment failure modes to carry forward

- A source actor named `floor` can be a tall structural voxel. Hub floor27 spans `[16,38.5,-2.9]` to `[16.5,42,0]`: its lower-room side needs cladding while its Arrival walking top remains its own surface. Union queries must include floor solids, not just `wall`/`roof` labels.
- Fitted vaults must sit wholly **below** the opaque retained roof. Burying their crown inside it yields a flat ceiling with hidden ribs. The existing 15cm vault drop at source clearance>=2.2m leaves measured minimum2.034m above the new floor art. Preserve lower crawl roofs; do not force a vault into them.
- A source box top and a material carrier's pivot differ. Ground floor skins with thickness below; centered elbows/spanners and trays require their actual modeled bounds/interior shelf height. The prior candle fix used the tray's interior floor, not its raised rim. Do not normalize away connection points after designing a shaft/socket assembly.
- Imported front is **+Y**. For an interior fixture: north wall yaw0, south180, west-90, east90. Parent and insert meshes need shared intended frame but different attachment offsets: lantern hook and eye are not both at the housing center.
- Shade seam backings with the local material family; they are a hidden utility behind art, not a substitute flat facade. Quiet original-source material on distant exposed foundations can avoid a second unsupported masonry layer.
- Do not apply one material or visibility override to a whole Hub component to fix a handful of selected galleries. Preserve outside instances with exact source proxies or cover only selected source surfaces.
- Actual saved water top is authoritative. Cistern source design Z=-2.5 corresponds to saved water top about-2.59, with bed-2.9; raster bank edges remain-2.5. Floor veneers/backings must stay below water over the bed. Do not lower the physical bank to match the polygon painting.
- Pipe diameters, shaft axes, flange heights and cradle tops must meet. No unsupported dry-bank spout, wheel without axle, hanging rack without a wall, or floating coping above a depression. Ground underwater coping skirts to the bed where a raster bank differs from the clean polygon.
- Generated glyph art is not an answer. Preserve all six exact source glyph resources, runtime phrase ordering, plate seal relation and existing clue readability. No glyph wallpaper or invented route arrows.

## Camera and continuity acceptance

The JSON supplies standing and crouch candidates for every room/zone. Most ground coordinates come directly from source nodes or existing protected view starts; closet `[17,40,0]` and Vault `[62,60,-5]` are explicitly inferred room insets requiring a saved-floor/capsule check. Nominal node Z is not the same as an actual rasterized/wading floor: **snap to the actual saved top and verify the camera is inside the exercised player state**. Proposed eye offsets1.4m standing/.90m scout crouch fit below the documented capsule envelopes, but actual pawn offsets must be measured.

Transform plan metres to world centimetres with `[(x-70)*100,(y-55)*100,z*100]`. Keep the ten original sightline endpoints unchanged for comparison; separately capture from the pawn eye. Use carried lantern on/off, actual pack/scout crouch and two-way route observations. A free spectator or screenshot cannot prove physical traversal, replication or packaged collision.

The existing Court-link camera at plan `[6,33,-.9]` was outside saved floor and looked into a wall. The checked replacement is ground `[6,35,-2.5]`, aimed east toward `[12,35]`; its earlier eye-0.9 was a spectator calibration, not a universal pawn-eye constant.

At all21 port-pair checkpoints, compare both travel directions where allowed, source floor/rail heights, material scale, local light falloff, water level, boundary silhouettes and unobstructed widths. Port coordinates often differ because an actual authored stair/dogleg connects them: never create a straight new connector to make the numbers meet. Check all11 explicit ramps, both ladders, all four scout crawls, nine low links, mill/loft drops and the 24 authored reveal/transition points. Review ten landmark/clue views and seven windows with art visible and hidden.

Completion requires the main integrator's saved-world identity/collision comparison, fresh runtime instance counts, focused Toolbox gates and actual whole-level visual/movement review. This delegate performed source/image research and created these two planning files only.
