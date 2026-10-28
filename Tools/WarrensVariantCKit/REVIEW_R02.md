# Variant C concept fidelity review — R02

The current map is a first art draft. Broad surface coverage was delivered, but the previous audit overstated visual completeness. Mesh counts and preserved source geometry did not establish finished composition, grounded gameplay fixtures, readable clues, or correct mechanism placement.

Review model: `gpt-6.1-sol`, `high` effort, independently reviewing concepts and captured pixels. The lead checked the source mechanisms, inspected representative concept/runtime images, and collected fresh live PIE geometry. No gameplay, map, mesh, light, or asset changes were made in this review.

## Lead reconciliation and confirmed current evidence

- **Confirmed in fresh PIE:** the Chain-location fixed gate post centers are `[-410,-2900,120]` and `[-190,-2900,120]`, with lintel `[-300,-2900,230]`; bars are at `Z110` and extend along world X. The fixed frame is independent of leaf movement, so its elevation cannot be explained by an opening animation. The frame feet are at Z0 above the authored crossing floor at Z−250cm. The gate plane runs along the east/west route rather than across it. See `ReviewR02/chain_gate_live_components.json`. The earlier report's uncertainty about whether those recorded transforms remain current is resolved; exact ECS owner/channel and open-state behavior still need tracing before a repair.
- **Confirmed source discrepancy:** `Tools/LevelDesign/anchor_plans/data/warrens_v8c.json:1980–1990` supplies yaw90 and no Z; `build_warrens.py:2212` defaults Z to0. Placement and static gate surrounds need correction together. Lowering only the decorative skin would leave the active collision behind.
- **Confirmed intended P2 versus implementation:** the plan says the remote Sluice wheel lowers the causeway; current construction generates a fixed crossing and a locally operated rising Bars gate. Recommendation: retain the authored lowering interaction for the eventual gameplay repair. The painting does not prove an extending/retracting bridge. Do not turn an incomplete prototype substitution into the permanent art contract.
- **The reported green hook is still unresolved.** Its floating appearance is visible in the user's screenshot, but its entity and attachment failure have not been reproduced. The fresh session exposed two sconce mounting plates elsewhere (`ReviewR02/sconce_live_mounts.json`), not at the reported crossing. Random anchor selection or a different fixture may be involved; that is a hypothesis. Do not claim the hook is repaired or move a guessed decorative instance.
- **Confirmed visual fidelity gaps:** the saved Sluice and Ossuary images show the regular shell, isolated fixtures, sparse shelf contents and large dark regions described below. These image observations support the proposed changes; they do not prove missing hidden geometry.

## What is actually missing, and what to reuse

| Work package | Missing result | Existing work to reuse / required adaptation |
|---|---|---|
| Functional fixtures | Grounded, consistently styled gates, hooks, levers, locks, plates and ladders in their real states | Bind the available kit parts to actual runtime owners/moving nodes. Keep grips, trace targets, collisions, travel and return paths authoritative; do not layer frozen HISM substitutes over them. |
| P2 crossing | A coherent remote wheel → chain → lowered causeway interaction and a visibly supported structure | Reconcile the original authored P2 before finalizing machinery art. Correct the elevated/parallel shortcut and matching surrounds as one ownership-aware repair. |
| Architectural silhouette | Broad irregular masonry, portal reveals, supported pier bases, selected arch/rock transitions | Extend the procedural shared kit with a small modular family. Avoid reintroducing compressed vaults or filling low crawl/headroom envelopes. |
| Ossuary | Bone storage that reads as dense storage, plus visible plate/seal correspondence | Existing shelf and bone-bundle meshes can be instanced/merged more densely within the original envelopes. Concept chef-on-plate staging must not imply a permanent co-op hold. |
| Mill, Cellar and Reliquary | Readable process/storage/ritual ensembles rather than isolated props | Recompose existing vat, rack, chute, millstone, jars, barrels, votives and tomb parts against supported closed bays. No invented second curing objective or collectible-looking food. |
| District wayfinding | Clear complementary Well/Bell identities and meaningful symbols | ART02 and ART03 already exist as source art but have no final fitted placements; add supported carriers where useful. ART05 is optional, not a required asset omission. |
| Water and banks | Readable shallow crossings, damp transitions and consistent water-edge composition | Preserve actual depths, dry Pit and routes. Use existing water/foam/wear families selectively; do not turn the Ford into a jumping route. |
| Practical lighting | Legible room forms and controls without repeated black fixture wedges | Diagnose the fixture housing/emitter/standoff before adding lights. Improve motivated local pools and landmark contrast; retain darkness and the player's lantern role. |
| Landmark and clue composition | Readable hoist, bell and authored clue from actual approaches | Recheck the ten protected views at pawn eye. Some current shots do not show their intended target. Missing P4 encounter/clue authoring remains a gameplay gap, not permission to invent an answer. |
| Acceptance coverage | Local control/key/door views and actual mechanism states | Replace the duplicated high-bell inspection angles with distinct floor/loft views; inspect the actual Vault doorway. Keep the original capture set as baseline, not proof of completion. |

Repair order: placement/ownership and P2 contract → representative fixture lighting and clue readability → architectural silhouette → district ensembles → detail accents. Revalidate affected player routes and state transitions after repairs. More small props alone will not close this gap.

## Snapshot commit state

The preceding requested snapshot is committed locally: `ea832e5` source art, `bf2f8f1` shared kits, `678c622` opt-in gate materials, `26811b6` complete Variant C art pass. Nothing was pushed. All 289 pre-existing staged entries were preserved byte-for-byte. This R02 review and its live geometry evidence were produced after those commits and remain uncommitted.

The review below is retained as the independent reviewer's scoped evidence. It did not itself perform the lead's fresh PIE checks above.

---
# Variant C: independent concept and recorded-runtime review

Reviewed 2026-10-24. Read-only review; no maps, assets, source, Git index, or gameplay state changed. This file is the only output.

## Verdict

The recorded integration has broad surface coverage and recognizable individual props, but it does not yet deliver the concepts' district identity, readable focal composition, or finished gameplay presentation. The highest-impact problems are the P2 implementation mismatch, the elevated/parallel prototype Chain gate evidence, unreadable distant clue/landmark compositions, and repeated hard lantern shadow wedges. A count of placed meshes or a previous FINAL_AUDIT pass does not settle these concerns.

Evidence vocabulary: **Confirmed** means directly read source/data or inspected image pixels this session. **Inferred** means an explanation/recommendation supported by that evidence but not reproduced in a fresh live session. **Unverified** means evidence is insufficient. A room image showing darkness does not prove an asset is absent.

## Evidence and limits

- Inspected all 12 ENVC image pixels in `docs/art/overnight-exploration-r01/images/environment-C/`, all 11 DRESS district sheets in `docs/art/warrens-c-dressing-r01/art/district-sheets/`, all 24 `ROOM_*.png` and all 10 `VIEW_*.png` in `Tools/WarrensVariantCKit/Output/Runtime/`.
- Also inspected `SEAM_Waterworks-W__Canal__chain.png`, `SEAM_Canal__Brineworks__chain-e.png`, `SEAM_Court__Catacomb__court.png`, `SEAM_Catacomb__Pit__pit.png`, and both `DIAG_GlassShadow_ON/OFF.png`. The other 17 seam images were not independently pixel-reviewed here.
- Recomputed SHA256 for all 55 images referenced by `Output/Reports/runtime_capture_manifest.json`: **55 matched, zero mismatches**. Manifest captures are 2026-10-24 18:28:30 through 18:47:18 UTC. This ties findings to recorded files, not to a newly captured current editor session.
- Read `ROOM_DRESSING.md`, `SOURCE_REVIEW.md`, catalogs, `prop_assemblies.json`, final `fitted_instances.json`, the source v8c plan, relevant builder and mechanism source, and stored runtime component audit. Fitted data has 37,511 placements; stored `runtime_instances.json` also reports 37,511, 266 HISM groups and NoCollision art. These are inventory evidence only.
- `runtime_review.py:13-15` moves `CameraActor_0`, sets FOV80 and switches view target. These are real PIE-world captures using authored free-camera positions; they do not show the actual pawn eye, hand/trace interaction, carried lantern illumination, pack clearance, control activation, multiplayer, or packaged collision.
- No fresh live PIE, automation, editor mutation, or state exercise was performed by this reviewer. No claim of runtime functionality or regression freedom is made.

## Priority 1: gameplay meaning and visible placement

### P2 is an incomplete substitution, not an established fixed-bridge design

**Confirmed original intent:** `Tools/LevelDesign/anchor_plans/data/warrens_v8c.json:2148` says the east-bank Sluice handwheel **lowers the chain causeway**, with the Cellar floor chain as its tell. The shortcut note at line1990 also attributes opening to that distant wheel; link note at2257 says causeway lowered from the Cellar side. ENVC-05 depicts a chain-supported crossing with a wheel and floor-chain relationship. The single painted state cannot establish whether it lowers or extends.

**Confirmed actual implementation:** `build_warrens.py:2212-2214` generates `Mars_Shortcut_EntityScript`, passing the Chain channel and local lever side. `Mars_Shortcut_EntityScript.as:46-66` constructs a latched Bars gate and its nearby lever. `build_warrens.py:2233-2239` emits the separate handwheel branch only for a puzzle kind starting `sluice grate`; actual P2 kind at source line2137 starts `the Chain Crossing's latched bars`. That branch is not selected. `Mars_Gate_EntityScript.as:9-11,114-123` describes/attaches a leaf that rises on a moving node. The static route remains available geometry.

Later `docs/art/warrens-c-dressing-r01/sections/chain-crossing-sluice/README.md:7,15` protects a fixed causeway and explicitly acknowledges the handwheel-versus-lever mismatch. Those art compatibility rules describe the existing prototype; they do not override original P2 intent. The separate Sandbox `Mars_ChainBridge_EntityScript` and Gauntlet8 lower a deck, but their existence does not prove Variant C uses them.

**Recommendation:** mark P2 incomplete. Retain present collision and route for the art-only correction pass; do not add a static fake Sluice wheel or a frozen bridge leaf. In a separately approved gameplay pass, implement the intended distant wheel/chain/lowering relationship, or deliberately revise P2 to fixed causeway plus rising gate and update its authored clues. The user's extension reading is a design fork to resolve; a static concept is insufficient evidence to change lowering into extension. Capture blocked, moving, latched-open and two-way return states from both banks before calling the crossing complete.

### The raised/wrong-facing Chain gate has source and recorded-runtime support

**Confirmed:** ChainCrossing shortcut source at `warrens_v8c.json:1980-1990` supplies `[67,26]`, yaw90 and no `z`. Builder line2212 defaults missing `z` to0. The source crossing route is at -2.5m. The gate opening spans local Y (`Mars_Gate_EntityScript.as:39-42`).

Stored `Output/Reports/runtime_grid_audit.json` records the Chain-location frame at world post centers `[-410,-2900,120]`, `[-190,-2900,120]`, lintel `[-300,-2900,230]`, and bars at X -387.5 through -212.5, Y -2900, Z110. The fixed frame centers agree with a base at Z0, **2.5m above the route**, and a gate width along world X. The causeway runs predominantly east-west, also world X, so its gate plane is parallel to travel instead of across it.

**Inferred:** the missing shortcut elevation and supplied yaw are strong explanations for the raised/parallel prototype gate reported by the user. These recorded generic component hosts are not a fresh entity-ownership trace; do not state that the user's exact frame/state has been reproduced.

Art currently follows that elevated contract: final fitted rows `WaterworksW/CCS36@[65.9,26,0]`, `CCS36@[68.1,26,0]` and `CCS37@[67,26,4.4]` are static current gate guides/surround. Lowering only these skins would separate art from the active gate.

**Correction:** verify current live gate root and closed/open component transforms, then correct the owning shortcut elevation/orientation and attached static surround together. Confirm threshold collision and the lever/remote control side in the actual chosen P2 contract. Do not cover the problem with extra wall/floor geometry.

### Gameplay controls remain visibly outside the art pass

**Confirmed scope gap:** `fitted_placement.py:220-221` deliberately retains physical controls, glyphs, ladders and doors as their working runtime actors. `Mars_Gate_EntityScript.as:34-36,84-88,111-115` falls back to ProtoGrid materials unless a presentation override is provided. `ROOM_closet.png` and `ROOM_cellar.png` show dim teal/green pole-and-ring shapes amidst finished fixtures; their support/attachment is not readable in these views. `ROOM_ford-e.png` retains a bright prototype-looking barred doorway. `ROOM_vault.png` does not provide a readable dressed red-key doorway.

**Unverified:** whether the user's green floating hook is one of these objects; whether it is truly unsupported, intentionally interactive, in the wrong coordinate frame, or in a wrong animation state. The user screenshot itself was not passed to this delegate for pixel inspection.

**Correction:** audit each active gate, key, plate, ladder, hook, panel and lever at its actual entity owner; give it a coherent static/moving skin and grounded mounting plate without altering grip/trace/collision. Keep interaction targets recognizable and moving art parented to the true moving node. This is missing integration work, not permission to install static HISM substitutes.

## Priority 2: composition and concept identity

### Important distant reads are not demonstrated

**Confirmed pixels:** `VIEW_rim-glyphs.png` contains a small distant doorway/light cluster, but the three glyphs cannot be read. `VIEW_ford-hoist.png` is dominated by a straight masonry corridor/soffit; the hoist is not visually identifiable. `VIEW_loft-well.png` and `VIEW_belfry-pit.png` are dominated by dark structural masses. `VIEW_larder-bell.png` reduces the bell to a small isolated lit fragment. A geometry ray that reaches an endpoint does not establish the clue or landmark composition.

This is a visible readability failure in these recorded frames, not a confirmed finding that art physically blocks a source ray. Preserve the authored camera anchors and clue content. First inspect actual pawn-eye/clue visibility with art on/off; then improve local illumination, contrast and silhouette framing. If retained source structure blocks the intended composition, record it as a level-design issue rather than deleting topology during dressing. Keep the authored cold-lit bell identity (`source props[1]`) instead of making all districts uniformly amber.

### The repeated shell still reads as a tiled blockout

**Confirmed pixels:** `ROOM_hall.png`, `ROOM_court.png`, `ROOM_court-pit.png`, `ROOM_cistern.png`, `ROOM_catacomb.png`, `ROOM_sluice.png` and the two Chain seam frames show broad, regular flat panels, near-identical floor/ceiling cells and extremely straight wall edges. Individual prop silhouettes do not compensate for the continuous uniform shell. ENVC01/03/10 and DRESS01/02/04/10 use thicker irregular masonry, broken courses, clustered supports, arch reveals, rock transitions and distinct foreground/middle-distance depth.

**Confirmed implementation choice:** `fitted_placement.py:28-34` replaces repeated CCS18 vault undersides with flipped CCS13 slabs to avoid folded-panel artifacts. This explains the flat-ceiling direction; it is a reasonable compatibility correction, but leaves an aesthetic gap.

**Correction:** retain source collision/clearance and use a small family of beveled silhouette caps, uneven closed-wall masonry courses, supported pier bases and occasional arch/rock transitions. Break repetition in broad shape and material value; do not substitute realistic noisy textures or uniformly scatter rubble on playable floors. Low roofs/crawls keep their measured envelope. Do not reintroduce the rejected compressed vault grid.

### Fixture self-shadow patterns overpower room forms

**Confirmed pixels:** large black triangular wedges above/below lanterns repeat in `ROOM_hall`, `ROOM_court-pit`, `ROOM_cistern`, `ROOM_reliquary`, `ROOM_sluice`, `ROOM_cellar`, `ROOM_vault` and both Chain seams. White-hot small cages compete with largely black architecture. The concepts use broad readable warm pools, darker but legible adjacent forms and restrained cool depth.

`DIAG_GlassShadow_OFF.png` visibly improves deck illumination relative to ON, but retains large patterned shadows. Current `runtime_instances.json` reports non-shadowing translucent inserts. Therefore the remaining wedges must not be diagnosed as the already-disabled glass alone.

**Correction:** one fixture/one room first: inspect housing, frame shadowing, emitter position, source radius and wall standoff; change one axis and show matched captures. Broaden motivated local light around room identity and control approaches, retain dark transitions and carried-lantern relevance. Do not globally raise exposure or add a point light to every candle.

### District stories are present as ingredients, weak as assemblies

**Confirmed placement data:** only three painted service emblem placements occur: Hub ART01, Ossuary ART04 and Mill ART06 (`fitted_placement.py:214-219`). No ART02 Well emblem, ART03 Bell emblem or ART05 harvest mural is fitted. These omissions are not all mandatory (harvest mural is optional), but west/east symbolic wayfinding and the promised complementary district stories are not established by the current art. The same final data has 37 closed-wall story-dressing placements across all districts; large mesh counts are predominantly surface coverage.

`ROOM_ossuary.png` clearly shows long shelf frames with only sparse pale bone bundles rather than the concepts' dense storage wall. `ROOM_reliquary.png` presents a plain isolated closed sarcophagus; `ROOM_catacomb.png` presents its tomb/lid on regular tiled floor under a flat ceiling. `ROOM_mill.png` frames a plain vat side against a bare wall: the chute/rack/salt/millstone production grouping is not communicated from that recorded approach, although data confirms the millstone, chute, vat and rack exist.

**Correction:** compose a few source-supported ensembles around the existing anchors: denser merged Ossuary bundles inside the two 6x1x2.6m envelopes; tomb + votive + restrained brass storage against a closed bay; vat/rack/salt process grouping inside its current Mill footprint; cellar barrel/jar/chain-guide grouping. Add Well/Bell emblem carriers only where actual routes/closed support and protected views allow them. Preserve sparse Court/Pit floors and blank space around controls.

## Full room coverage matrix

Every `ROOM_...png` listed below was independently inspected. Paths are relative to `Tools/WarrensVariantCKit/Output/Runtime/`. Suggested corrections are art proposals, not verified runtime fixes.

| District / reference | Room / image stem | Confirmed recorded read and practical next correction |
|---|---|---|
| Hub / DRESS01, ENVC01/11 | hall / ROOM_hall | Brazier and one bright fixture dominate bare regular shell; strengthen warm arrival ensemble on closed bays, preserve open route to hoist. |
| Hub | closet / ROOM_closet | Very dark; teal control/hook-like silhouette and railing are visible but mounting is unreadable. Inspect actor-owned attachment and ladder/bar control from actual approach. |
| Hub | rimW / ROOM_rimW | Tall narrow hoist frame readable close-up, surroundings black. Improve rim silhouette and supported service detail, keep shaft fully open. |
| Hub | rimE / ROOM_rimE | Distant target cluster lacks readable clue. Preserve exact glyph content and verify across-canal contrast. |
| Hub | rimN / ROOM_rimN | Almost wholly black with small cold wall strips. Establish local rim edge and next-route read without filling shaft. |
| Hub | rimS / ROOM_rimS | Hoist assembly visible but isolated; keep existing connected frame/chain, add local context/foreground only outside walk strip. |
| Court / DRESS02, ENVC01 | court / ROOM_court | Distant split silhouette is lit from its base while center/perimeter disappear. Read statue silhouette and sunken hunting space; keep retreat floor empty. |
| Court | court-pit / ROOM_court-pit | Tall regular pier and uniform tiles outweigh Court identity. Ground broken masonry on perimeter, preserve -1.5m floor distinction and ramps. |
| Ossuary / DRESS03, ENVC03/06 | ossuary / ROOM_ossuary | Shelves/bones exist but sparse; plate/shared seal relationship not demonstrated by this angle. Densify merged bundles inside source envelopes and inspect P3 separately. |
| Ossuary | bridgehead / ROOM_bridgehead | Long corridor with thin rails/flat wall, little Bone Bridge identity. Improve supported ivory coping/post silhouettes and approach framing; keep bridge mouth/window clear. |
| Waterworks-W / DRESS04, ENVC05/10 | pump / ROOM_pump | Recognizable pump and connected pipes; surrounding shell generic and dark. Add one maintenance grouping/pipe support rhythm; avoid extra turnable-looking control. |
| Waterworks-W | cistern / ROOM_cistern | Basin edge/water/ripples exist, but uniform ceiling and hard shadow wedges dominate. Preserve actual shallow bed/water; improve supported bank/arch/fixture composition. |
| Pit / DRESS05, ENVC12 | lair / ROOM_lair | Mostly dark tiled floor and one distant wall pool; cavern/root scale not established. Reveal selective rock/root silhouette and shaft relationship, keep authored dry floor. |
| Pit | vault / ROOM_vault | Camera emphasizes a bare wall corner/lantern rather than key door. Need a separate near/front red-key doorway capture before judging fit; no extra platform/root escape. |
| Canal / DRESS06, ENVC03/04/05/11 | ford-w / ROOM_ford-w | Regular masonry corridor/soffit framing dominates; shallow Ford and both-landmark composition not communicated. Verify route/depth cues, don't add jumping stones. |
| Canal | ford-e / ROOM_ford-e | Bright barred doorway and regular walls; water/shore meaning weak. Preserve always-open Ford and separate it visually from controlled Chain route. |
| Belfry / DRESS07, ENVC02/07 | belfry / ROOM_belfry | Camera aims almost entirely upward to bell/cold piers. Add actual floor-level panel/ladder/entry views; preserve 22m/+16m landmark hierarchy. |
| Belfry | bell-loft / ROOM_bell-loft | Again aims at high bell; reachable +2.5m key, lever and landing not shown. Audit key/plinth/grips/rail drop directly. |
| Reliquary / DRESS08, ENVC06/07 | reliquary / ROOM_reliquary | Plain tomb isolated on tiled floor; backdrop/ritual-storage identity weak. Compose votive/brass grouping on closed wall, protect P3 gate and drop landings. |
| Mill / DRESS09, ENVC08/09 | mill / ROOM_mill | Vat side dominates; rack/chute/stone process group not readable in this view though placed. Improve local grouping/light hierarchy without moving P7 or staging pack inside hand plane. |
| Catacomb / DRESS10, ENVC12 | catacomb / ROOM_catacomb | Tomb/lid visible; open cavity difficult to read, regular blue-lit ceiling/floor generic. Reveal actual hollow tomb and irregular closed-wall niche; retain existing dive ramps. |
| Brineworks / DRESS11, ENVC05/09 | cellar / ROOM_cellar | Isolated lantern and salt pile; chain-to-control story unclear, teal hook-like form not readable. Ground actual attachment and show chain routing without blocking headroom. |
| Brineworks | sluice / ROOM_sluice | Timber header/braces and side stores present; center has low fixture, no demonstrated intended P2 handwheel. Keep P2 mismatch explicit; don't dress a fake objective. |
| Brineworks | larder / ROOM_larder | Shallow green surface present but most structure dark; bell roof-break relationship weak. Keep 0.4m depth and clear view, frame background storage without second curing stop. |

Camera coverage itself needs correction: manifest shows `ROOM_belfry` target `[104,50,15]`, `ROOM_bell-loft` target `[104,50,16]`; both inspect the high bell. `ROOM_vault` targets `[64,62,-3.8]` rather than the source red-key doorway `[57,60,-5]`. These images count as room locations but cannot accept local controls or the vault frontage.

## Concept arrangements to adapt rather than copy

These are deliberate gameplay concessions; do not classify them as missing detail or automatically implement them:

1. ENVC02's dangling high-bell key is unreachable relative to the actual +2.5m loft key; retain the reachable objective and high +16m landmark separately.
2. ENVC04's discrete scenic Ford stones must not turn the always-open shallow crossing into a jumping test or create another deep-water route. Preserve source water and actual walk surface.
3. ENVC05's apparent movable crossing must be reconciled with original lowering intent and incomplete current P2; extension is not established by the painting. DRESS11's screw gate/extra timber decks are not the implemented mechanism contract.
4. DRESS03/ENVC06's chef-on-plate composition can imply a simultaneous co-op hold. P3 latches after pack press; use plate/seal correspondence without suggesting a player must remain behind.
5. DRESS07/ENVC07 must not repair the authored Reliquary rail-drop gap or move the key/panel up to match the picture. No random generated lock answer on the west face.
6. DRESS09/ENVC08 extra loft/stair and salt chute piles are composition ideas, not routes. Keep Mill P7, source ramps, pack staging and one-way rail drop.
7. ENVC09 workbenches/vats are supporting larder mood, not permission to move required curing from Mill or introduce duplicate stations/collectible-looking food.
8. DRESS10's Catacomb ladder and flooded shaft conflict with source dive ramps. ENVC12's flooded Pit/boats/docks conflict with authored dry Pit and route count. Preserve source traversal.
9. DRESS sheets have unreliable component labels: e.g. DRESS02 H14 rock/P26 statue vs catalog H14 SplitMourner; DRESS09 swaps vat/mill IDs; DRESS11 I03 chef/W01 wall vs wheel/chain catalog. Resolve identity from catalog, shape from image. This was reconfirmed by reading catalog names against displayed labels.
10. Concepts show wide exposed parapets, small chefs and hanging scenic cargo. Do not infer safe player clearance from them: written standing/crouch/backpack envelope, source rails, ladder endpoints, control sweeps and protected views remain authoritative.

## Recommended correction sequence and acceptance

1. Resolve P2's intended movement/control contract and reproduce the current gate/hook problems with actual live entity transforms. Fix owning placement/skin attachment, not only static art.
2. Reframe inspection around actual pawn eye/control approach; add door/panel/plate/key/ladder shots and carried-lantern on/off. Keep current 55 manifest-backed captures as the visual baseline.
3. Calibrate one representative practical light and one landmark/clue view; match before/after cameras. Then propagate only the confirmed fixture correction.
4. Break broad shell repetition with source-supported silhouette/closed-wall masonry/rock work. Strengthen one anchored district ensemble per room group before adding small accents.
5. Recheck every affected route in real player states: crossing both ways, pack/scout, crawl, ladder, gate closed/moving/open, clue read, authored drops. Run focused Toolbox build/tests if gameplay/source changes; a visual-only pass still needs actual saved-map/PIE visual proof.

Likeliest claim to be wrong without fresh live verification: the elevated/parallel gate's exact current ownership/state and the green hook's actual attachment cause. The source/default elevation discrepancy and recorded component positions are concrete; the final causal diagnosis still needs the live failing path.
