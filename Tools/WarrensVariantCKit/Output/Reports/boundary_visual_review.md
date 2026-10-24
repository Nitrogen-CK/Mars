# Boundary and protected-view pixel review

Inspected **all31 actual1600×1000 PNGs** in `Output/Runtime`:10 VIEW images dated2026-10-24 **17:48:14–17:48:41UTC**,21 SEAM images **17:48:44–17:49:44UTC**. Read `runtime_review.py` to confirm directory/capture method; no Unreal/Blender calls. Pixel coordinates below are approximate, origin upper-left. Smoke/probe success is not visual signoff.

## Findings that change acceptance

- **Protected glyph view fails visual readability:** `VIEW_rim-glyphs` shows near corridor aroundx590–860,y470–780 and tiny distant light/geometry aroundx890–1020,y450–520, but no readable three-glyph clue. Source camera(48,50,1.4) and protected target(102,50,2) were preserved. Ray/OBB tests against saved wall/roof/floor/ramp solids find no source obstruction along this exact segment. This is an art/light/clue visibility issue to investigate, not authority to carve source geometry or move the protected camera.
- **Several boundary images are invalid approach evidence because targets cut original geometry:** Court→Ossuary hits Main wall89 after2.161m; Hub→Pump hits Hub wall127 after1.209m; Court→Cistern hits Hub wall111 after3.028m; Reliquary→Mill hits Reliquary wall27 after2.200m; Brineworks→Pit hits Canal floor69 after2.535m; west-facing Chain segment cuts WaterworksW wall76 after11.386m. These are direct-line framing errors through bends/source solids, not demonstrated new veneer blockage.
- **Two targets point vertically:** Hub→Ossuary camera and target shareXY(42,60); Catacomb→Pit shareXY(-8,50). They show upper surfaces instead of the approach. Belfry→Larder also aims into its own original ramp2, ray parameter.7412. Correct review framing rather than changing source geometry.
- **Bridge and bell readability remains weak** in VIEW_bridge-hoist/bridge-bell and both Bone Bridge seams. Warm endpoints and cool tower piers read; much of deck/rail and bell body is black. Main is already adjusting these lights; this report does not request another global lighting pass.

## All10 protected views

| ID | Actual pixel observation / scope |
|---|---|
| VIEW_ford-hoist | Near masonry corridor and ceiling occupyx300–1600; far bright bayx940–1000,y615–675. Hoist itself is not legible at this exposure. Source segment is unobstructed; distant light/readability issue, not confirmed wall occlusion. |
| VIEW_ford-bell | Bell underside is a small bright oval atx775–825,y520–550; cool support piers and chains run below. Landmark exists, but body/silhouette is weak. Near ford floor only a bottom strip. |
| VIEW_bridge-hoist | Warm left openingx75–430,y280–680 and near dark railx750–1500,y710–950. Hoist target nearcenter is not readable; no confirmed detached/blocked structure. |
| VIEW_bridge-bell | Cool tower piersx725–860,y550–780 and tiny bell rim around(800,530); bridge foreground is black. Insufficient deck/rail identity proof. |
| VIEW_rim-glyphs | Clue not readable; see priority finding. Keep exact protected source camera/target. |
| VIEW_hall-hoist | Hoist frame, chain, lower drum and rail line read aroundx740–900,y450–940, with warm practical. No obvious detached component; source bearer embed remains too dark for pixel confirmation. |
| VIEW_loft-well | Layered void with warm vertical faces and a cool slabx540–750,y480–900. Well depth implied; near walk edge and distant hoist are mostly black. No definite new geometry fault. |
| VIEW_belfry-pit | Warm high wallx950–1100,y500–800, small lower practical and rail strip. Pit depth/context readable in silhouette only; floor approach not validated. |
| VIEW_pit-hoist | Hoist front visiblex720–875,y445–950, upper pulley and loadchain continuous; lower base cropped. Useful vertical landmark evidence, not footing proof. |
| VIEW_larder-bell | Bright bell underside aroundx760–810,y510–570; surroundings nearly black. Physical presence shown, silhouette/context not accepted. |

## All21 boundary seams

| ID suffix after SEAM_ | Actual pixels / classification |
|---|---|
| Hub__Court__court | Close existing blue/black gate bars fillright-centerx700–1290,y100–800; no approach floor. Dynamic gate state/framing, not proof added art closes path. |
| Hub__Ossuary__ossuary | Nearly black frame. SameXY vertical target; invalid approach framing. |
| Court__Ossuary__ossuary | Small lit Ossuary shelf/ceiling openingx820–1030,y300–645. Direct target segment cuts original corner wall; adjust route-tangent camera. |
| Hub__Waterworks-W__pump | Almost black except tiny lit wedge at far-rightx1550–1600,y400–550. Segment hits source wall within1.209m; invalid framing through dogleg. |
| Court__Waterworks-W__cistern | Black frame without assessable floor/wall junction. Segment hits source wall after3.028m; invalid long direct aim through bend. |
| Hub__Pit__cascade | Warm short rail/landingx520–750,y440–700; tiny lit upper bay around(720,290). Some level change visible; main stair tread continuity not sufficiently lit. |
| Hub__Pit__closet | Existing teal interaction/ladder outline fillscentralx650–940,y50–950; background black. Too close to mechanism for ladder-well continuity signoff. No new art collision established. |
| Waterworks-W__Pit__sump | Cool pool of light on Pit floorx500–1080,y390–520, source furniture centered(840,425), upper rimline visible. Landing/context readable; near ramp surface dark. |
| Waterworks-W__Canal__chain | Warm near tiled deck and two rail linesx650–1380,y550–950; far lit opening. Near continuity plausible; target segment cuts original west bank corner farther away. |
| Canal__Brineworks__chain-e | Well-lit narrow corridor/roof, continuous near tile surface; right wall and left practical bracket visible. No obvious floor crack or impossible attachment in shown portion. Far turn black. |
| Ossuary__Canal__bridge | Dark bridge rails inforeground, warm openingx670–930,y200–535. No obvious hole visible, but central deck/ivory railing identity too dark to accept. |
| Canal__Reliquary__bridge-e | Warm endpoint/gate aroundx700–930,y380–570; both dark rails frame center. Bridge floor/edge continuity insufficiently visible. |
| Hub__Canal__ford | Lit near stone corridorx530–980,y170–700, green water-colored strip acrossmouthy515–555, distant ramp. Strip is visible but alone is not proof water penetrates source floor; assess matched forward water/step view. |
| Canal__Belfry__ford-e | Cool tile floor and tower base/gate inleft-halfx20–630,y200–600; long dark horizontal boundary acrossforeground. No definite crack/step defect; dark edge warrants closer forward view. |
| Belfry__Reliquary__reliquary | Right-edge cool tower/chain sliverx1230–1600,y460–950; most frameblack. Upward/sideward framing fails stair surface review although no source segment hit was found. |
| Belfry__Brineworks__cellar | Existing gate bars span frame; lit floor/wall visiblethroughx660–880,y70–520. Gate state is expected source mechanism, not an added obstruction. No tread landing proof. |
| Belfry__Brineworks__larder | Black frame. Target ray intersects standing original ramp2; camera looks into approach surface. |
| Reliquary__Mill__mill | Only tiny warm floor slitx1040–1090,y325–445. Segment cuts original stair-turn wall; camera cannot show winding staircontinuity. |
| Court__Catacomb__court | Tiny cool floor/ceiling opening at farupper-rightx1350–1600,y50–395; restblack. Source target segment clear, but poor aim/readability for low passage. No invented geometry repair supported. |
| Catacomb__Pit__pit | Right-half close stair/ceiling lattice; left-halfblack. SameXY upward target explains extreme framing. Do not call staircase blocked from this image. |
| Brineworks__Pit__undercroft | Entire frameblack; direct target goes through original Canal floor69. Winding low-route tangent required. |

## Evidence limits and next action

All31 files were inspected; none omitted because smoke tests passed. The visible lit Chain corridor and hoist views provide useful appearance evidence. Many other images are too dark, gate-facing, or geometrically mis-aimed to establish continuity. No new floor crack, disconnected structure, or added-geometry route blockage was confirmed from these pixels. This does **not** certify those surfaces absent defects.

Source ray calculations used all saved unrotated solids, then rotated source OBBs for relevant ramp cases. Target-only contact was excluded (segment endpoint is not an occlusion). Protected view source coordinates remain authoritative. Correct cameras for bent/vertical seam targets, retain VIEW_rim-glyphs exactly, and investigate its separate clue readability. Main owns maps/lights/assets; this review changed only this report.

## Authorized camera correction after pixel review

Parent subsequently authorized edits to **make_views.py only**, plus regeneration of its review-camera JSON. No lighting, geometry, assets, or protected sightline was changed. `python Tools/WarrensVariantCKit/make_views.py` passed after final edits, producing **55 unique IDs**. Nine seams now follow authored route vertices/endpoints: the six original-solid-obstructed segments, two sameXY targets, and the additional Belfry→Larder own-ramp obstruction diagnosed above.

Each corrected camera records `source_camera_proof`: actual source floor/ramp contact,15 body probes at center/cardinal radius.35m across low/mid/head heights, and a clear whole target line against all retained wall/roof/floor/ramp OBBs. Broad-phase bounds account for rotation. A target merely touching a source face at segment endpoint does not fail validation. **All nine remained at1.4m standing eye height**, and all nine target segments pass. These are sampled source-body checks, not runtime capsule sweeps.

| Seam short name | Corrected eye planXYZ | Corrected target planXYZ | Authored route basis |
|---|---|---|---|
| Hub→Ossuary | (42,60,2.524779) | (44,64,3.9) | wN→o0 |
| Court→Ossuary | (30,86,2.178354) | (32,86,2.437231) | c2→via(32,86)→o1 |
| Hub→Pump | (50,40,.587) | (52,38,.143591) | wSE→via(52,38)→p1 |
| Court→Cistern | (5,56,-.799837) | (4.5,55,-1.1) | c1→cw |
| Chain west | (81,25,-1.1) | (66,26,-1.1) | authored Chain Crossing west endpoint |
| Belfry→Larder | (112,52,.338008) | (112,46,-1.1) | be→bl0 |
| Reliquary→Mill | (104,101,5.152238) | (104,104,5.601595) | mill-stair-b endpoint |
| Catacomb→Pit | (-8,50,-2.345175) | (-4,46,-3.595179) | catacomb-dive-b endpoint |
| Brineworks→Undercroft | (80,25.0667,-3.6) | (66,26,-3.6) | actual ut1→ut2 via vertices |

`VIEW_rim-glyphs` remains exactly eye **(48,50,1.4)**, target **(102,50,2)**, asserted by the generator. Clue readability remains a separate unresolved visual issue. Existing31 PNGs reviewed above predate these camera corrections: **no refreshed-pixel signoff is implied**. Main must recapture corrected IDs.
