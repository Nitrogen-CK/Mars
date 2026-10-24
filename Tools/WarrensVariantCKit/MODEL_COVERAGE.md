# Warrens Variant C model coverage

Reviewed 150 source catalog entries against reference jobs and measured CCS/PWC manifests: **80 new meshes**, **69 CCS/PWC reuse mappings or composites**, and **one reuse-only Red Key actor**. Reuse requires visual-function fit plus a workable dimension/pivot adapter; it never replaces source gameplay behavior.

## Source and evidence

- `docs/art/warrens-c-dressing-r01/prop_catalog.json`: 150 source rows and their dimensions, pivots, materials, variants, and model/dressing-sheet references.
- `docs/art/warrens-c-dressing-r01/image_jobs.json`: 82 linked model, district, painted, and section image jobs. `model_catalog.json` retains the image paths.
- `docs/art/warrens-c-dressing-r01/assembly_recipes.json`: 26 source-prop recipes and P1–P7 puzzle-art memberships, copied into each relevant `assembly_refs`.
- `Tools/ChainCrossingKit/Output/asset_manifest.json`: measured CCS01–CCS88 bounds, pivots, flags, and material keys.
- `Tools/PumpCisternKit/Output/asset_manifest.json`: measured PWC01–PWC25 bounds, pivots, flags, and material keys.
- References are concept art, not finished meshes. All 150 source entries and every available source sheet link are represented in `model_catalog.json`.

## Production contract

- `models[]` contains only new Builder rows with `WVC###` IDs (three-letter prefix plus integer for the current `id[3:]` parser), `dimensions_cm` (width/depth/height), materials, shared Builder category, supported production pivot, `blender_brief`, source ID, and concept links.
- `source_mappings[]` has all 150 IDs and resolves each to a new `WVC###`, an actual CCS/PWC asset/composite, or the existing Red Key actor. Existing IDs are not duplicated in the generated model list.
- `source_pivot` preserves the original source pivot text; `production_pivot` uses `bottom center`, `center`, or `top contact`. `pivot_adapter` captures source corner, mounting, hinge, or axle transforms the Builder pivot enum cannot express.
- All meshes are visual-only: keep retained source collision authoritative. Do not add controls, gameplay, UI, or lights. Skins for interactive objects preserve the source actor pivot, grip, channel, hinge, state, and collision.
- `I14` is reuse-only: P1 uses the reachable existing Red Key pickup. No replacement model or actor. Puzzle glyphs, phrases, notices, banners, plaque identity, and P7 state remain runtime/source-authored.

## Reuse map

| Source IDs | Existing production asset | Basis and fit notes |
|---|---|---|
| A01, A02, A03 | `CCS15` | course-wall skin; exact envelope and bottom-center pivot; same ashlar course module; width scale 0.5; same ashlar end-fill; width scale 0.25 |
| A04 | `CCS16` | stacked square corner pier; scale footprint to 80x80, preserve 300cm height |
| A10, A18 | `CCS08` | straight stone coping strip; scale depth to50cm and height to25cm; landing edge stone coping; scale height30 to15cm |
| A14 | `CCS13` | flagstone floor skin; same plan and top-contact walking plane |
| A15 | `CCS14` | half-width floor skin; source plan100x100 vs 100x200; scale depth0.5 |
| A16 | `CCS18` | vault underside bay; source dimensions match plan and 30cm thickness can scale to20cm |
| A17 | `CCS03` | stair fascia strip; scale height60 to45cm |
| A21 | `CCS43` | large faceted cave rock; scale height250 to300cm |
| A22, E02 | `CCS44` | faceted wedge rock; source 160x120x130, scale to200x120x180; faceted wedge; scale160x120x130 to200x120x180 |
| H13 | `PWC01` | pump tower body exact 200x200x600 envelope; source audio/gameplay actor remains authoritative |
| W01 | `CCS27` | closed heavy oval link; near-exact 32x20x8 vs30x18x8; instantiate/rotate alternate link planes |
| W02 | `CCS29` | continuous open chain guide; scale depth40 to35cm |
| W03 | `CCS24` | static chain drum; transform +X mesh axis to source Y axle, scale to80x60x80 |
| W04 | `PWC05` | hollow straight pipe; exact 200x40x40, axisX |
| W05 | `PWC06` | hollow 90-degree XY elbow; exact 80x80x40, sockets per PWC manifest |
| W06 | `PWC07` | hollow pipe collar; rotate axisX to source Z and scale envelope to50x18x50 |
| W07 | `CCS88` | recessed floor drain/grille; scale thickness15 to5cm, top-contact pivot must flip/offset to bottom contact |
| W08 | `CCS54` | open gutter channel; scale depth45 to60cm and height30 to25cm |
| W09 | `CCS55` | hollow wall spout; scale XY to50x70; pivot/orientation adapter to rear-center mount, open mouth retained |
| W10 | `PWC10` | straight cistern rim module; scale depth55 to60 and height55 to60cm |
| W12 | `CCS52` | thin alpha foam edge carrier; scale depth50 to60cm; FX_Water source material overrides Foam |
| I03 | `CCS23` | same 100x100x160 handwheel pedestal housing; keep source handwheel/grip/control/channel |
| I07, P29, P30 | `CCS80` | blank route backing only; scale to40x2x40; use authored AT04 glyph resources at runtime; blank backing; scale to50x3x60 and apply ART04; do not reuse CCS79 curing-stop identity plaque; blank backing; scale to60x3x60 and apply ART06/runtime P7 state |
| I14 | `existing source Red Key pickup actor/mesh` | prop_catalog status reuse_existing; assembly recipe source prop 10 and P1 explicitly say reuse existing key pickup; dimensions are placeholder only. No concept sheet or generated replacement. |
| P01 | `CCS69` | timber shelving; scale depth50 to55cm |
| P05 | `CCS66` | barrel silhouette; near-match 90x90x120 to85x85x110 |
| P08, P23 | `CCS68` | cloth sack; scale envelope to60x45x80; composite of multiple scaled sack instances within stack envelope; no new mesh |
| P20 | `CCS77` | reed basket; scale depth60 to55 and height60 to40 |
| P25 | `CCS78` | blank notice board backing; do not bake text, runtime/source notice remains separate |
| P26, P27, P28 | `PWC24` | plain quiet cloth banner; scale to80x4x200 and apply ART01 decal/material; plain quiet cloth banner; scale to80x4x180 and apply ART03; plain quiet cloth banner; scale to80x4x180 and apply ART02 |
| L01, L02 | `CCS60` | lantern cage housing; exact35x25x55; table lantern cage; scale to25x25x40 |
| L03 | `CCS63` | wall sconce housing; exact30x35x60 |
| L05 | `CCS62` | lantern wall hook; exact15x25x25 |
| L06 | `CCS61` | lantern glass insert; exact25x20x35 |
| L07 | `PWC23` | compose three unlit candle instances in 35x35x50 envelope; no auto lights |
| D05 | `PWC17` | top-contact pebble bed; scale to80x60x10 |
| D06 | `CCS85` | broken floor-tile silhouette; exact plan80x60; catalog height20 matches |
| D08 | `CCS70` | salt chunk cluster; exact80x70x40 |
| D09 | `CCS74` | cloth scrap; exact50x50x2 |
| D10 | `CCS72` | repair plank; exact150x25x6 |
| D11 | `CCS73` | bolted repair plate; exact70x40x4 |
| D13 | `CCS53` | vertical waterline card; exact200x60x1 |
| D15 | `CCS71` | rope coil; exact60x60x20 |
| E03 | `CCS45` | straight cave wall panel; exact400x100x400 |
| E04 | `CCS46` | inside-corner cave wall; outside variant composed from two CCS45 panels |
| E05 | `CCS47` | inverted cave ceiling cap; exact400x400x100; resolve authored pivot conflict (catalog bottom-center vs notes rear top-contact) per placement |
| E06 | `CCS06` | three-sided support half-shell; scale footprint120 to200 and height300 to500 |
| E07 | `CCS48` | wet bank skirt; exact400x120x200 |
| E08 | `CCS50` | rubble toe strip; exact200x60x30 |
| E09 | `CCS49` | cliff face; exact400x150x600 |
| E10, E11 | `CCS51` | deep canal water surface card; exact400x400x1; shallow ford surface card; scale XY to200x200; preserve visible floor under shallow water |
| E12 | `CCS56` | bent outlet flow ribbon; exact40x35x100 |
| E13 | `CCS57` | impact ripple card; exact80x80x1 |
| E14 | `PWC25` | source cistern polygon surface; use exact source outline for basin; CCS51 remains the generic tiled pool surface |
| E15 | `CCS59` | scum surface patch; exact150x100 plan, material override FX_Water/TX05 |
| E19 | `COMPOSITE_P14_P11_W01` | chime rail: reuse three instances P14 crossbar, P11 single-bone component, and short CCS27/PWC chain link; fit source 6m envelope |
| E20 | `CCS58` | vertical drip card; exact30x1x120 |
| E22 | `CCS86` | timber support beam; exact200x30x35 |
| E23 | `CCS87` | diagonal timber brace; exact120x25x120 |

## New model queue

| Production ID | Source / model | Size cm (W×D×H) | Pivot | Materials | Concept sheet(s) | Priority |
|---|---|---:|---|---|---|---|
| `WVC001` | `A05` PierBase | 110.0×110.0×35.0 | bottom center (source: lower-left rear module grid corner; contact plane stays on authored shell) | TX01 | [MODEL01](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL01_SharedMasonryKit.png) | P0 |
| `WVC002` | `A06` PierCapital | 110.0×110.0×45.0 | bottom center (source: lower-left rear module grid corner; contact plane stays on authored shell) | TX01 | [MODEL01](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL01_SharedMasonryKit.png) | P0 |
| `WVC003` | `A07` ArchSurround300 | 380.0×45.0×420.0 | bottom center (source: lower-left rear module grid corner; contact plane stays on authored shell) | TX01 | [MODEL13](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL13_MasonryClosures-r02.png) | P0 |
| `WVC004` | `A08` ArchSurround250 | 330.0×45.0×380.0 | bottom center (source: lower-left rear module grid corner; contact plane stays on authored shell) | TX01 | [MODEL01](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL01_SharedMasonryKit.png) | P0 |
| `WVC005` | `A09` ArchKeystone | 70.0×60.0×80.0 | bottom center (source: lower-left rear module grid corner; contact plane stays on authored shell) | TX01 | [MODEL13](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL13_MasonryClosures-r02.png) | P1 |
| `WVC006` | `A11` BoneArchRib | 200.0×45.0×120.0 | bottom center (source: lower-left rear module grid corner; contact plane stays on authored shell) | TX06 | [MODEL04](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL04_BoneBridgeDress.png), [DRESS06](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS06_CanalDressingAssembly.png) | P0 |
| `WVC007` | `A12` BoneBridgePost | 50.0×50.0×110.0 | bottom center (source: lower-left rear module grid corner; contact plane stays on authored shell) | TX06 | [MODEL04](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL04_BoneBridgeDress.png), [DRESS06](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS06_CanalDressingAssembly.png) | P0 |
| `WVC008` | `A13` BoneCoping200 | 200.0×35.0×35.0 | bottom center (source: lower-left rear module grid corner; contact plane stays on authored shell) | TX06 | [MODEL04](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL04_BoneBridgeDress.png), [DRESS06](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS06_CanalDressingAssembly.png) | P0 |
| `WVC009` | `A19` ThresholdCover | 250.0×50.0×3.0 | top contact (source: top-left grid corner; walking face Z=0, mesh thickness extends below the authored walk plane) | TX09 | [MODEL15](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL15_StairsWindowsAndThresholds.png) | P1 |
| `WVC010` | `A20` BurialNicheFrame | 160.0×25.0×180.0 | bottom center (source: lower-left rear module grid corner; contact plane stays on authored shell) | TX01, TX06 | [MODEL11](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL11_MournerAndBurialKit.png), [DRESS03](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS03_OssuaryDressingAssembly.png), [DRESS08](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS08_ReliquaryDressingAssembly.png), [DRESS10](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS10_CatacombDressingAssembly.png) | P1 |
| `WVC011` | `A23` CrackCoverStrip | 200.0×25.0×60.0 | bottom center (source: lower-left rear module grid corner; contact plane stays on authored shell) | TX04 | [MODEL13](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL13_MasonryClosures-r02.png) | P1 |
| `WVC012` | `A24` WindowSurround | 220.0×30.0×200.0 | bottom center (source: lower-left rear module grid corner; contact plane stays on authored shell) | TX01 | [MODEL15](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL15_StairsWindowsAndThresholds.png), [DRESS07](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS07_BelfryDressingAssembly.png) | P0 |
| `WVC013` | `H01` WellHoistFrame | 160.0×160.0×750.0 | bottom center (source: bottom-center at contact plane) | TX08, TX09 | [MODEL02](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL02_WellHoist.png), [MODEL36](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL36_WellHoistMechanicalBreakdown.png), [DRESS01](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS01_HubDressingAssembly.png) | P0 |
| `WVC014` | `H02` HoistPulley | 90.0×30.0×90.0 | center (source: axle center; rotation local Y) | TX08, TX09 | [MODEL02](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL02_WellHoist.png), [MODEL36](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL36_WellHoistMechanicalBreakdown.png), [DRESS01](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS01_HubDressingAssembly.png) | P0 |
| `WVC015` | `H03` HoistDrum | 100.0×70.0×100.0 | center (source: axle center; rotation local Y) | TX08, TX09 | [MODEL02](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL02_WellHoist.png), [MODEL36](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL36_WellHoistMechanicalBreakdown.png), [DRESS01](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS01_HubDressingAssembly.png) | P0 |
| `WVC016` | `H04` HoistHook | 45.0×20.0×80.0 | bottom center (source: bottom-center at contact plane) | TX09 | [MODEL02](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL02_WellHoist.png), [MODEL36](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL36_WellHoistMechanicalBreakdown.png), [DRESS01](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS01_HubDressingAssembly.png) | P0 |
| `WVC017` | `H05` HoistCage | 140.0×140.0×180.0 | bottom center (source: bottom-center at contact plane) | TX08, TX09 | [MODEL02](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL02_WellHoist.png), [MODEL36](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL36_WellHoistMechanicalBreakdown.png) | P1 |
| `WVC018` | `H06` BellTowerCrownModule | 400.0×400.0×400.0 | bottom center (source: bottom-center at contact plane) | TX01, TX10 | [MODEL03](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL03_BelfryBellRig.png), [DRESS07](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS07_BelfryDressingAssembly.png) | P0 |
| `WVC019` | `H07` HighLandmarkBell | 240.0×240.0×280.0 | bottom center (source: bottom-center at contact plane) | TX10 | [MODEL03](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL03_BelfryBellRig.png), [MODEL23](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL23_LandmarkBellConstruction.png), [DRESS07](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS07_BelfryDressingAssembly.png) | P0 |
| `WVC020` | `H08` BellYoke | 300.0×100.0×80.0 | center (source: yoke axle center; rotation local Y) | TX08, TX09 | [MODEL03](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL03_BelfryBellRig.png), [MODEL23](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL23_LandmarkBellConstruction.png), [DRESS07](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS07_BelfryDressingAssembly.png) | P0 |
| `WVC021` | `H09` BellClapper | 30.0×30.0×180.0 | center (source: top hinge center) | TX09 | [MODEL03](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL03_BelfryBellRig.png), [MODEL23](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL23_LandmarkBellConstruction.png), [DRESS07](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS07_BelfryDressingAssembly.png) | P0 |
| `WVC022` | `H10` BoneBridgeKeystone | 150.0×70.0×100.0 | bottom center (source: bottom-center at contact plane) | TX06 | [MODEL04](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL04_BoneBridgeDress.png), [DRESS06](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS06_CanalDressingAssembly.png) | P1 |
| `WVC023` | `H11` MillstoneDrum | 250.0×250.0×200.0 | bottom center (source: bottom-center at contact plane) | TX01, TX08 | [MODEL06](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL06_SaltMillCuringStation.png), [MODEL37](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL37_MillAndCuringVatBreakdown-r02.png), [DRESS09](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS09_MillDressingAssembly.png) | P0 |
| `WVC024` | `H12` SaltChute | 200.0×80.0×120.0 | bottom center (source: bottom-center at contact plane) | TX08, TX05 | [MODEL06](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL06_SaltMillCuringStation.png), [MODEL37](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL37_MillAndCuringVatBreakdown-r02.png), [DRESS09](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS09_MillDressingAssembly.png) | P0 |
| `WVC025` | `H14` SplitMourner | 200.0×120.0×450.0 | bottom center (source: bottom-center at contact plane) | TX01, TX06 | [MODEL11](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL11_MournerAndBurialKit.png), [DRESS02](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS02_CourtDressingAssembly.png) | P0 |
| `WVC026` | `H15` Sarcophagus | 300.0×150.0×120.0 | bottom center (source: bottom-center at contact plane) | TX01, TX10 | [MODEL11](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL11_MournerAndBurialKit.png), [DRESS08](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS08_ReliquaryDressingAssembly.png), [DRESS10](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS10_CatacombDressingAssembly.png) | P1 |
| `WVC027` | `W11` VatLiquidInsert | 210.0×130.0×3.0 | bottom center (source: bottom-center at contact plane) | TX15 | [MODEL22](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL22_CisternAndVatLiquids.png) | P0 |
| `WVC028` | `I01` KeyLoftPlinth | 80.0×80.0×30.0 | bottom center (source: bottom-center at contact plane) | TX01, TX10 | [MODEL03](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL03_BelfryBellRig.png), [DRESS07](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS07_BelfryDressingAssembly.png) | P0 |
| `WVC029` | `I02` BellkeeperPanelHousing | 100.0×40.0×140.0 | bottom center (source: bottom-center at contact plane) | TX09, TX10 | [MODEL10](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL10_InteractionHousingKit-r02.png), [DRESS07](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS07_BelfryDressingAssembly.png) | P0 |
| `WVC030` | `I04` WheelAxle | 20.0×80.0×20.0 | center (source: axle center; rotation local Y) | TX09 | [MODEL05](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL05_SluiceChainKit.png), [DRESS11](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS11_BrineworksDressingAssembly.png) | P0 |
| `WVC031` | `I05` ChainCrossingBarsSkin | 250.0×30.0×250.0 | bottom center (source: bottom-center at contact plane) | TX09 | [MODEL05](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL05_SluiceChainKit.png), [DRESS06](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS06_CanalDressingAssembly.png) | P0 |
| `WVC032` | `I06` PackPlateHousing | 200.0×200.0×30.0 | bottom center (source: bottom-center at contact plane) | TX01, TX10 | [MODEL10](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL10_InteractionHousingKit-r02.png), [DRESS03](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS03_OssuaryDressingAssembly.png) | P0 |
| `WVC033` | `I08` DialBlank | 20.0×8.0×20.0 | center (source: face center; rotation local Y) | TX10, TX09 | [MODEL10](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL10_InteractionHousingKit-r02.png), [DRESS07](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS07_BelfryDressingAssembly.png) | P0 |
| `WVC034` | `I09` LadderFootBarsSkin | 100.0×20.0×170.0 | bottom center (source: bottom-center at contact plane) | TX09 | [MODEL10](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL10_InteractionHousingKit-r02.png), [DRESS07](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS07_BelfryDressingAssembly.png) | P0 |
| `WVC035` | `I10` LoftLeverSkin | 50.0×35.0×80.0 | bottom center (source: lever hinge) | TX09, TX08 | [MODEL10](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL10_InteractionHousingKit-r02.png), [DRESS07](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS07_BelfryDressingAssembly.png) | P0 |
| `WVC036` | `I11` RedKeyEscutcheon | 35.0×10.0×50.0 | center (source: rear-center mounting surface; art faces local -Y) | TX09 | [MODEL10](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL10_InteractionHousingKit-r02.png), [DRESS05](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS05_PitDressingAssembly.png) | P0 |
| `WVC037` | `I12` CuringVat | 240.0×160.0×140.0 | bottom center (source: bottom-center at contact plane) | TX08, TX09, TX15 | [MODEL06](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL06_SaltMillCuringStation.png), [MODEL37](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL37_MillAndCuringVatBreakdown-r02.png), [DRESS09](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS09_MillDressingAssembly.png) | P0 |
| `WVC038` | `I13` CuringVatLid | 240.0×160.0×15.0 | bottom center (source: bottom-center at contact plane) | TX08, TX09 | [MODEL06](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL06_SaltMillCuringStation.png), [MODEL37](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL37_MillAndCuringVatBreakdown-r02.png), [DRESS09](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS09_MillDressingAssembly.png) | P1 |
| `WVC039` | `I15` BacksideBarLeverSkin | 40.0×25.0×80.0 | bottom center (source: lever hinge) | TX09, TX08 | [MODEL25](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL25_LaddersAndBacksideGateHardware.png) | P0 |
| `WVC040` | `I16` ScoutLadder100Segment | 100.0×15.0×100.0 | bottom center (source: bottom-center at contact plane) | TX08, TX09 | [MODEL25](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL25_LaddersAndBacksideGateHardware.png), [DRESS05](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS05_PitDressingAssembly.png) | P0 |
| `WVC041` | `I17` LoftLadder125Segment | 100.0×15.0×125.0 | bottom center (source: bottom-center at contact plane) | TX08, TX09 | [MODEL25](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL25_LaddersAndBacksideGateHardware.png), [DRESS07](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS07_BelfryDressingAssembly.png) | P0 |
| `WVC042` | `I18` MournerCacheGateSkin | 250.0×30.0×250.0 | bottom center (source: bottom-center at contact plane) | TX09, TX01 | [MODEL25](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL25_LaddersAndBacksideGateHardware.png), [DRESS08](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS08_ReliquaryDressingAssembly.png) | P0 |
| `WVC043` | `I19` VaultDoorSkin | 250.0×30.0×300.0 | bottom center (source: existing actor hinge, never recompute from artist view) | TX09, TX01 | [MODEL26](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL26_VaultDoorCampPlinthAndBox-r02.png), [DRESS05](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS05_PitDressingAssembly.png) | P0 |
| `WVC044` | `I20` CampPackPlinth | 120.0×120.0×30.0 | bottom center (source: bottom-center at contact plane) | TX01 | [MODEL26](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL26_VaultDoorCampPlinthAndBox-r02.png), [DRESS01](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS01_HubDressingAssembly.png) | P0 |
| `WVC045` | `P02` PreparationBench | 200.0×70.0×90.0 | bottom center (source: bottom-center at contact plane) | TX07, TX09 | [MODEL08](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL08_PantryStorageKit.png), [DRESS09](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS09_MillDressingAssembly.png) | P1 |
| `WVC046` | `P03` StorageCrateBody | 80.0×60.0×60.0 | bottom center (source: bottom-center at contact plane) | TX07, TX09 | [MODEL08](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL08_PantryStorageKit.png), [DRESS01](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS01_HubDressingAssembly.png) | P1 |
| `WVC047` | `P04` StorageCrateLid | 80.0×60.0×8.0 | bottom center (source: bottom-center at contact plane) | TX07 | [MODEL08](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL08_PantryStorageKit.png) | P1 |
| `WVC048` | `P06` OliveStorageJar | 45.0×45.0×60.0 | bottom center (source: bottom-center at contact plane) | TX15 | [MODEL08](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL08_PantryStorageKit.png), [DRESS11](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS11_BrineworksDressingAssembly.png) | P1 |
| `WVC049` | `P07` ServingBowl | 35.0×35.0×14.0 | bottom center (source: bottom-center at contact plane) | TX15 | [MODEL08](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL08_PantryStorageKit.png) | P1 |
| `WVC050` | `P09` SaltCrystalChunk | 50.0×50.0×60.0 | bottom center (source: bottom-center at contact plane) | TX05 | [MODEL27](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL27_SaltAndMillStorage.png), [DRESS09](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS09_MillDressingAssembly.png), [DRESS11](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS11_BrineworksDressingAssembly.png) | P1 |
| `WVC051` | `P10` SaltHeap | 150.0×100.0×70.0 | bottom center (source: bottom-center at contact plane) | TX05 | [MODEL27](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL27_SaltAndMillStorage.png), [DRESS09](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS09_MillDressingAssembly.png) | P1 |
| `WVC052` | `P11` BoneBundle | 120.0×40.0×50.0 | bottom center (source: bottom-center at contact plane) | TX06 | [MODEL11](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL11_MournerAndBurialKit.png), [MODEL24](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL24_ServiceBellsAndBoneChimes.png), [DRESS03](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS03_OssuaryDressingAssembly.png), [DRESS07](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS07_BelfryDressingAssembly.png), [DRESS10](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS10_CatacombDressingAssembly.png) | P1 |
| `WVC053` | `P12` OssuaryUrn | 40.0×40.0×60.0 | bottom center (source: bottom-center at contact plane) | TX06, TX01 | [MODEL11](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL11_MournerAndBurialKit.png), [DRESS03](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS03_OssuaryDressingAssembly.png), [DRESS10](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS10_CatacombDressingAssembly.png) | P1 |
| `WVC054` | `P13` ReliquaryBox | 80.0×50.0×50.0 | bottom center (source: bottom-center at contact plane) | TX10, TX08 | [MODEL26](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL26_VaultDoorCampPlinthAndBox-r02.png), [DRESS08](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS08_ReliquaryDressingAssembly.png) | P1 |
| `WVC055` | `P14` HerbDryingRod | 200.0×30.0×30.0 | bottom center (source: bottom-center at contact plane) | TX08, TX14 | [MODEL06](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL06_SaltMillCuringStation.png), [DRESS07](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS07_BelfryDressingAssembly.png), [DRESS09](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS09_MillDressingAssembly.png), [DRESS11](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS11_BrineworksDressingAssembly.png) | P1 |
| `WVC056` | `P15` DryingRack | 200.0×60.0×220.0 | bottom center (source: bottom-center at contact plane) | TX08, TX14 | [MODEL06](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL06_SaltMillCuringStation.png), [MODEL08](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL08_PantryStorageKit.png), [DRESS09](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS09_MillDressingAssembly.png), [DRESS11](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS11_BrineworksDressingAssembly.png) | P1 |
| `WVC057` | `P16` TallowPot | 45.0×45.0×35.0 | bottom center (source: bottom-center at contact plane) | TX15, TX18 | [MODEL28](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL28_KitchenTabletopKit.png) | P1 |
| `WVC058` | `P17` Cup | 20.0×20.0×25.0 | bottom center (source: bottom-center at contact plane) | TX15 | [MODEL28](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL28_KitchenTabletopKit.png) | P2 |
| `WVC059` | `P18` Platter | 55.0×40.0×7.0 | bottom center (source: bottom-center at contact plane) | TX15 | [MODEL28](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL28_KitchenTabletopKit.png) | P2 |
| `WVC060` | `P19` FoldedCloth | 80.0×60.0×4.0 | bottom center (source: bottom-center at contact plane) | TX12 | [MODEL28](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL28_KitchenTabletopKit.png) | P2 |
| `WVC061` | `P21` MortarPestle | 35.0×35.0×45.0 | bottom center (source: bottom-center at contact plane) | TX01 | [MODEL28](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL28_KitchenTabletopKit.png) | P2 |
| `WVC062` | `P22` MillHopper | 180.0×160.0×140.0 | bottom center (source: bottom-center at contact plane) | TX08, TX09 | [MODEL27](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL27_SaltAndMillStorage.png), [DRESS09](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS09_MillDressingAssembly.png) | P1 |
| `WVC063` | `P24` WindowShutter | 100.0×20.0×160.0 | bottom center (source: bottom-center at contact plane) | TX08, TX09 | [MODEL15](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL15_StairsWindowsAndThresholds.png) | P1 |
| `WVC064` | `L04` CandleHolder | 45.0×35.0×40.0 | bottom center (source: bottom-center at contact plane) | TX09, TX18 | [MODEL09](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL09_PracticalLightKit.png), [DRESS01](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS01_HubDressingAssembly.png), [DRESS03](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS03_OssuaryDressingAssembly.png), [DRESS05](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS05_PitDressingAssembly.png), [DRESS08](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS08_ReliquaryDressingAssembly.png), [DRESS10](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS10_CatacombDressingAssembly.png) | P1 |
| `WVC065` | `L08` EmberBrazier | 90.0×90.0×100.0 | bottom center (source: bottom-center at contact plane) | TX09, TX19 | [MODEL32](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL32_GlassWaxBrazierAndLightFrame.png), [DRESS02](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS02_CourtDressingAssembly.png) | P1 |
| `WVC066` | `L09` ShaftLightFrame | 200.0×50.0×150.0 | bottom center (source: bottom-center at contact plane) | TX01, TX09 | [MODEL32](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL32_GlassWaxBrazierAndLightFrame.png), [DRESS01](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS01_HubDressingAssembly.png) | P1 |
| `WVC067` | `D01` RootShort | 200.0×80.0×120.0 | bottom center (source: bottom-center at contact plane) | TX08 | [MODEL12](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL12_RootsAndForageDressKit.png), [DRESS02](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS02_CourtDressingAssembly.png), [DRESS05](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS05_PitDressingAssembly.png) | P1 |
| `WVC068` | `D02` RootLong | 200.0×60.0×250.0 | bottom center (source: bottom-center at contact plane) | TX08 | [MODEL12](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL12_RootsAndForageDressKit.png), [DRESS04](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS04_Waterworks-WDressingAssembly.png), [DRESS05](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS05_PitDressingAssembly.png) | P1 |
| `WVC069` | `D03` DryHerbBunch | 50.0×30.0×80.0 | bottom center (source: bottom-center at contact plane) | AT01 | [MODEL12](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL12_RootsAndForageDressKit.png), [DRESS09](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS09_MillDressingAssembly.png) | P1 |
| `WVC070` | `D04` MushroomCluster | 60.0×60.0×50.0 | bottom center (source: bottom-center at contact plane) | AT01 | [MODEL12](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL12_RootsAndForageDressKit.png), [DRESS02](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS02_CourtDressingAssembly.png) | P1 |
| `WVC071` | `D07` BoneFragment | 40.0×20.0×15.0 | bottom center (source: bottom-center at contact plane) | TX06 | [MODEL33](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL33_RepairAndBurialAccents.png), [DRESS03](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS03_OssuaryDressingAssembly.png), [DRESS10](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS10_CatacombDressingAssembly.png) | P2 |
| `WVC072` | `D12` DustCardPlane | 100.0×100.0×1.0 | bottom center (source: bottom-center at contact plane) | FX_Dust | [MODEL34](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL34_AtmosphereCarrierMeshes.png) | P2 |
| `WVC073` | `D14` CobwebCorner | 80.0×5.0×80.0 | bottom center (source: bottom-center at contact plane) | AT01 | [MODEL33](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL33_RepairAndBurialAccents.png), [DRESS10](docs/art/warrens-c-dressing-r01/art/district-sheets/DRESS10_CatacombDressingAssembly.png) | P2 |
| `WVC074` | `D16` ShelfDivider | 200.0×40.0×10.0 | bottom center (source: bottom-center at contact plane) | TX08 | [MODEL29](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL29_BasketClothAndShelfParts.png) | P1 |
| `WVC075` | `E01` RockButtressLarge | 300.0×180.0×450.0 | bottom center (source: bottom-center at contact plane) | TX04 | [MODEL16](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL16_LargeRockSilhouettes.png) | P0 |
| `WVC076` | `E16` BellLipDamageInsert | 90.0×25.0×70.0 | bottom center (source: bottom-center at contact plane) | TX10 | [MODEL23](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL23_LandmarkBellConstruction.png) | P1 |
| `WVC077` | `E17` ServiceBellSmall | 45.0×45.0×60.0 | bottom center (source: bottom-center at contact plane) | TX10 | [MODEL24](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL24_ServiceBellsAndBoneChimes.png) | P1 |
| `WVC078` | `E18` BellBracket | 70.0×40.0×90.0 | bottom center (source: bottom-center at contact plane) | TX08, TX09 | [MODEL24](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL24_ServiceBellsAndBoneChimes.png) | P1 |
| `WVC079` | `E21` LowMistCard | 300.0×1.0×100.0 | bottom center (source: bottom-center at contact plane) | FX_Dust | [MODEL34](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL34_AtmosphereCarrierMeshes.png) | P2 |
| `WVC080` | `E24` BrokenBeamEnd | 100.0×35.0×35.0 | bottom center (source: bottom-center at contact plane) | TX08 | [MODEL35](docs/art/warrens-c-dressing-r01/art/model-sheets/MODEL35_TimberStructureAndBreaks.png) | P1 |

## Placement and assembly flags

- `A05`/`A06`: CCS07 is a pier waterline collar, not a base/capital; both remain new.
- `P03`/`P04`: CCS67 combines crate body and lid; it cannot satisfy the distinct source parts, so both remain new.
- `I16`/`I17`: CCS76 is a long ladle, not a ladder; both remain new. Retain authored climb collision.
- `E04`: CCS46 supplies the inside corner; the outside variant can be composed from two CCS45 panels.
- `E05`: source note conflicts with catalog pivot (bottom-center versus rear/top contact); resolve against the source concept before placement.
- `W07`: CCS88 is top-contact with recessed grille, while source asks bottom-center; the adapter must preserve the grille flush with the floor.
- `W09`: CCS55 is hollow but bottom-center; adapt it to the source rear-center wall mount.
- `E14`: PWC25 is the 1150×1100 source cistern polygon; use it for the authored basin. CCS51 remains the generic 400cm water card.
- `E19`: composite uses P14 rail, P11 bone, and W01 chain links; source recipe calls for three shared crossbars and no new sound logic.
- `Water` is the Builder category for source `waterworks`; chain/pipe pieces are static visuals unless source actors already own behavior.
