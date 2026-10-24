# R05 runtime pixel audit: boundaries and protected views

Inspected all **31 current runtime PNGs**: 21 `SEAM_` images and 10 `VIEW_` images, all 1600×1000. Their local filesystem timestamps are 2026-10-24 14:33:15–14:34:45. This review records visible presentation and continuity only. Black regions do not prove that geometry is absent or blocked. No Unreal or Blender call was made for this visual audit.

`pie_final_boundaries_r05.json` records status `complete`, `ok: true`, 5,307 samples, and no warnings. The reported boundary smoke run also recorded 63 probes. Those runtime checks do not substitute for inspecting the pixels or walking each seam with a player capsule.

## Findings

- **Bridge presentation improved and reads coherently in this capture set.** `SEAM_Ossuary__Canal__bridge` and `SEAM_Canal__Reliquary__bridge-e` now show tiled deck surfaces, paired side rails, and warm lanterns at the rail-end posts. The floor grid remains visible under the sharply crossed shadows; no visible deck hole, disconnected rail, or floating lamp is apparent in these frames. `VIEW_bridge-hoist` also shows the near deck and rail assembly, while `VIEW_bridge-bell` places the bell within its tower arch and shows a lit rail-end fixture. This is visual evidence for the captured spans and angles, not runtime capsule clearance.
- **West Chain remains the clearest non-bridge continuity view.** `SEAM_Waterworks-W__Canal__chain` shows a continuous near tiled deck with paired rails and readable wall lighting. The far end remains dark, so only the near span is visually supported.
- **The P4 clue is still unreadable.** `VIEW_rim-glyphs` shows a lit passage and water-colored threshold, but the three-glyph target remains too small and dark to read. The known source gap (missing original dial/clue actors and no Bellkeeper encounter) is a source-baseline finding, not something this screenshot can verify. Existing prototype controls remain; this review does not imply fixed-answer leaves were added.
- **R06 supersedes four Brineworks-related captures and the Sluice room view.** The current images predate the Sluice brace-joint correction and header application. Mark `SEAM_Canal__Brineworks__chain-e`, `SEAM_Belfry__Brineworks__cellar`, `SEAM_Belfry__Brineworks__larder`, and `SEAM_Brineworks__Pit__undercroft` provisional until recaptured. `ROOM_sluice` is outside these 31 IDs and also needs its R06 capture.
- **Other dark or narrowly aimed images remain inconclusive.** The views below do not justify calling geometry absent, disconnected, or blocked. Several show a lit endpoint or structure without exposing the intervening walking surface.

## All 31 current images

| Image ID | Current pixel observation |
|---|---|
| `VIEW_ford-hoist` | The overhead/vertical structure is faint in a cool pool, while the lower bay remains almost black. The machinery silhouette and footing are not clear enough to assess. |
| `VIEW_ford-bell` | Bell underside and support are visible in a blue-white pool; surrounding floor and vertical context stay dark. Landmark is present in view, approach continuity is not shown. |
| `VIEW_bridge-hoist` | Near tiled deck, two rails, and lit post-end fixture are visible. The deck reads continuous to the darker turn; the hoist itself is not clear from this angle. |
| `VIEW_bridge-bell` | Bell sits inside the tall arched tower; a lantern at the foreground rail end is visible. Most of the surrounding volume is dark, so this is landmark evidence rather than route proof. |
| `VIEW_rim-glyphs` | Near corridor, threshold, and green-lit band are visible. Distant glyphs remain unreadable; retain the protected camera and treat clue readability separately. |
| `VIEW_hall-hoist` | A tall support/mechanism silhouette rises beside a lit floor edge, with most of the room dark. No clear contact defect is visible, but the base is not sufficiently exposed for footing confirmation. |
| `VIEW_loft-well` | Warm wall planes and the tall vertical structure frame a dark open volume. The void reads, while the walk edge and lower landing remain underexposed. |
| `VIEW_belfry-pit` | Tiled floor and parallel rails lead toward a lit central landing/gate area. Tile lines appear continuous in the visible strip; shadows are hard but do not resemble a missing deck section. |
| `VIEW_pit-hoist` | Hoist frame and nearby floor are visible; dark surroundings and cropping limit confirmation of lower base contact. |
| `VIEW_larder-bell` | Small bell silhouette is visible against a dark bay. Nearby vertical bars/rails are faint and the floor is not readable. |
| `SEAM_Hub__Court__court` | Existing gate bars and nearby lit wall/floor fragments are visible; most approach floor is dark. The image records the mechanism state, not evidence that dressing blocks the passage. |
| `SEAM_Hub__Ossuary__ossuary` | The corrected camera now shows an illuminated upper surface and shelf-like structure, but little walking surface. The seam remains visually unassessable. |
| `SEAM_Court__Ossuary__ossuary` | A small warm-lit side opening and a few nearby objects appear at the frame edge; the rest is dark, with no useful floor continuity view. |
| `SEAM_Hub__Waterworks-W__pump` | Nearly black with no assessable approach surface. No absence or blockage conclusion is supported. |
| `SEAM_Court__Waterworks-W__cistern` | Nearly black; no reliable floor-to-wall transition is visible. Inconclusive. |
| `SEAM_Hub__Pit__cascade` | A lit stair/landing edge and adjoining dark lower surface are more visible than in R03. The visible boundary is continuous in this crop, but the full tread run is not exposed. |
| `SEAM_Hub__Pit__closet` | A cyan vertical feature and narrow dark surround are visible; ladder-well floor and lower approach remain hidden. |
| `SEAM_Waterworks-W__Pit__sump` | A strong cool pool lights a central floor patch and a small nearby object. The surrounding landing and approach are too dark to judge. |
| `SEAM_Waterworks-W__Canal__chain` | Continuous tiled near deck, paired rails, and wall lighting are clearly visible. No near-span gap or rail break appears; far end remains dark. |
| `SEAM_Canal__Brineworks__chain-e` | Lit corridor with a readable tiled floor, opposing walls, and wall fixtures. No visible seam gap in this capture; provisional pending R06 structural reapplication. |
| `SEAM_Ossuary__Canal__bridge` | Deck tiles continue between both side rails; lanterns sit at the rail-end posts and illuminate the threshold. Strong crossing shadows fall over visible tile lines, with no visible hole or detached fixture. |
| `SEAM_Canal__Reliquary__bridge-e` | The tiled deck and both rail lines continue into the far landing; matching post-end lanterns are mounted at the bridge ends. Crossed shadows are sharp, but the underlying floor grid stays visible. |
| `SEAM_Hub__Canal__ford` | Lit stone corridor, near floor, and green-lit far threshold read as a connected passage. The green band alone does not establish water or collision behavior. |
| `SEAM_Canal__Belfry__ford-e` | Gate/tower elements and a cool-lit patch of floor are visible at left; the dark center and foreground prevent a full approach assessment. |
| `SEAM_Belfry__Reliquary__reliquary` | Cool tower/support strip and a lower landing edge are visible on the right; most of the span is dark. No visible break, but continuity is not established. |
| `SEAM_Belfry__Brineworks__cellar` | Mostly black with no usable floor detail. Provisional pending R06. |
| `SEAM_Belfry__Brineworks__larder` | A small warm wall light and faint green floor patch are visible; the route surface remains largely hidden. Provisional pending R06. |
| `SEAM_Reliquary__Mill__mill` | Entire frame is effectively black at this capture. No conclusion about the stair or seam is supported. |
| `SEAM_Court__Catacomb__court` | Small cool-lit upper opening appears at the right edge; the lower passage surface is not visible enough to judge. |
| `SEAM_Catacomb__Pit__pit` | Very dark; faint vertical/step-like shapes appear near the center, but the lower route surface cannot be assessed. |
| `SEAM_Brineworks__Pit__undercroft` | Entire route is too dark to inspect. Provisional pending R06; darkness is not evidence of missing geometry. |

## Scope and limits

Current fitting data is provisional at 37,511 rows while the Sluice brace-joint correction and header reapplication are pending; this report makes no live-placement count or full-level completion claim from that manifest. The visual review is limited to the 31 named captures. R06 must refresh the four Brineworks seams and `ROOM_sluice` before those areas receive final visual review. Physical input, network/co-op behavior, packaged collision, and traversal by a player capsule are not established here.
