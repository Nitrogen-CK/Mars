# R03 runtime pixel audit: boundaries and protected views

This review inspected the actual **31 current PNGs** in `Output/Runtime`: 21 `SEAM_` images and 10 `VIEW_` images, each 1600×1000. Their filesystem timestamps span 2026-10-24 14:14:08–14:15:38 local. The nine seam cameras listed in `boundary_visual_review.md` had already been corrected before these captures. No Unreal or Blender calls were made for this audit.

This is a visual-readability and continuity audit of the saved pixels, not a collision or traversal test. Black pixels do not establish that geometry is absent or blocked. Several images are too dark or framed away from the walk surface to judge. The four bridge captures (`VIEW_bridge-hoist`, `VIEW_bridge-bell`, `SEAM_Ossuary__Canal__bridge`, `SEAM_Canal__Reliquary__bridge-e`) are pending another capture after bridge posts, caps, and lanterns are applied; their current pixels are provisional.

## Current findings

- **Best continuity evidence:** `SEAM_Waterworks-W__Canal__chain` now shows a lit, tiled walking surface, flanking walls, and two continuous rail lines. No visible deck gap or rail discontinuity appears in the captured corridor. This is visual evidence for the shown span only.
- **Corrected west Chain camera:** `SEAM_Waterworks-W__Canal__chain` is no longer dominated by the former obstructing source wall. The approach reads as a long narrow corridor, but the distant turn remains dark. The image supports near-span continuity, not a complete route review.
- **Nine corrected views remain mixed:** most now avoid the exact source-solid intersections diagnosed in R02, but several still show mostly ceiling/wall or an unlit area. Camera validation and smoke probes do not make those pixels useful for art or surface acceptance.
- **Protected glyph view still fails readability:** `VIEW_rim-glyphs` shows the near passage, floor threshold, and green-lit band; the distant target remains a few tiny warm/cool marks with no legible three-glyph clue. Preserve its authored camera and investigate presentation/readability separately.
- **Bridge visuals are not final:** the current four bridge images do not include the pending posts/caps/lantern pass. Do not use them to accept the revised bridge assembly.
- **No new geometry defect is confirmed by these pixels.** Where the approach floor or seam is hidden in darkness, the result is inconclusive; it does not certify the area defect-free.

## All 31 current images

| Image ID | Pixel observation and evidence limit |
|---|---|
| `VIEW_ford-hoist` | Dark vertical space with a small lit area below; the hoist silhouette and its attachment are not clear enough to assess. |
| `VIEW_ford-bell` | A small bell underside is visible in a cool light pool. Its body and surrounding approach remain dark, so landmark presence is visible but context is weak. |
| `VIEW_bridge-hoist` | A well-lit narrow deck, side walls, parallel rails, and wall light read clearly. The hoist target is not legible; pending bridge assembly capture supersedes this view. |
| `VIEW_bridge-bell` | Mostly black, with only faint central structure visible. Bell/deck continuity is not assessable; pending bridge assembly capture. |
| `VIEW_rim-glyphs` | Near corridor and threshold are visible; the distant glyphs remain unreadable at this exposure. Keep the protected camera/target. |
| `VIEW_hall-hoist` | Upright mechanism/chain structures and nearby platform edge are visible against a dark bay. The floor-to-support contact is not clear enough for footing confirmation. |
| `VIEW_loft-well` | A large vertical structure and layered void read, with illuminated upper wall/ceiling and a dark lower edge. Well depth is suggested; walk-edge continuity is not demonstrated. |
| `VIEW_belfry-pit` | A lit lower pit/landing patch and small rail or mechanism elements appear within a mostly dark room. Floor approach remains underexposed. |
| `VIEW_pit-hoist` | Large hoist frame and adjacent masonry are visible; the lower base/footing is partly cropped and surroundings are dark. |
| `VIEW_larder-bell` | Small bright bell form is visible against black surroundings. The silhouette is identifiable only at close inspection; room context is absent. |
| `SEAM_Hub__Court__court` | Existing gate bars dominate the center/right. Little approach floor is visible; this records the gate state and framing, not a new-art obstruction. |
| `SEAM_Hub__Ossuary__ossuary` | Corrected camera now shows an illuminated overhead/upper surface and a shelf-like structure; the route floor is still not visible enough to judge the seam. |
| `SEAM_Court__Ossuary__ossuary` | A small warm-lit corner and upper surface appear at frame edge; most of the view is black. No floor continuity conclusion. |
| `SEAM_Hub__Waterworks-W__pump` | A doorway-sized lit opening reveals part of a wall and floor, but the dark approach and transition dominate. The former straight-line source-wall issue is no longer visually diagnostic; seam remains unassessable. |
| `SEAM_Court__Waterworks-W__cistern` | Nearly black with no reliable floor or wall junction to inspect. Inconclusive, not evidence of absent geometry. |
| `SEAM_Hub__Pit__cascade` | Small warm landing/rail area and an upper light patch are visible; stair tread continuity is not sufficiently exposed. |
| `SEAM_Hub__Pit__closet` | Narrow dark view with a cyan vertical feature near center. The floor and ladder-well continuation are not readable. |
| `SEAM_Waterworks-W__Pit__sump` | A localized cool-lit patch and nearby structure stand out in a dark room. No clear evidence of the full landing or approach surface. |
| `SEAM_Waterworks-W__Canal__chain` | Brightest seam image: tiled floor, side walls, and paired rails visibly continue through the near corridor. No visible gap in the captured span; far turn remains dark. |
| `SEAM_Canal__Brineworks__chain-e` | Lit narrow corridor with a continuous tiled surface, framed walls, and visible wall lantern/bracket. No obvious floor discontinuity in the shown span; far turn is dark. |
| `SEAM_Ossuary__Canal__bridge` | Current capture is very dark; near rail silhouettes and a warm opening are visible, while deck identity is weak. Pending bridge assembly recapture. |
| `SEAM_Canal__Reliquary__bridge-e` | Warm endpoint and side rails are visible, but central bridge deck is dark. Pending bridge assembly recapture. |
| `SEAM_Hub__Canal__ford` | A lit stone corridor and green-lit band across the far threshold are visible. The band alone does not establish water/floor penetration or a traversable crossing. |
| `SEAM_Canal__Belfry__ford-e` | A gate/tower structure and a patch of tiled floor appear at left; the long dark foreground boundary makes the approach edge hard to judge. |
| `SEAM_Belfry__Reliquary__reliquary` | Mostly dark, with a narrow cool tower/rail strip on the right. Stair surface and landing continuity are not assessable. |
| `SEAM_Belfry__Brineworks__cellar` | Existing gate bars occupy much of the frame; a lit floor/wall patch is visible through them. Expected mechanism state, not evidence of an added art blockage. |
| `SEAM_Belfry__Brineworks__larder` | Nearly black with a small distant light and faint green floor-colored patch. No useful ramp/landing read. |
| `SEAM_Reliquary__Mill__mill` | A small warm floor/step patch and rail edge are visible amid darkness. The corrected route-tangent view still does not show stair continuity clearly. |
| `SEAM_Court__Catacomb__court` | A small cool-lit upper-right opening is visible; most of the image is dark. Low-passage floor and approach remain unassessable. |
| `SEAM_Catacomb__Pit__pit` | Corrected view contains faint vertical/step-like forms, but the image remains very dark and does not establish the lower route surface. |
| `SEAM_Brineworks__Pit__undercroft` | Entire route is too dark to assess visually. Do not infer that the route or geometry is absent. |

## Camera correction comparison

The nine corrected seams from R02 are `SEAM_Hub__Ossuary__ossuary`, `SEAM_Court__Ossuary__ossuary`, `SEAM_Hub__Waterworks-W__pump`, `SEAM_Court__Waterworks-W__cistern`, `SEAM_Waterworks-W__Canal__chain`, `SEAM_Belfry__Brineworks__larder`, `SEAM_Reliquary__Mill__mill`, `SEAM_Catacomb__Pit__pit`, and `SEAM_Brineworks__Pit__undercroft`. Current images confirm the captures exist after the camera update. The west Chain view now provides useful corridor-floor evidence. For the other eight, corrected routing removed the earlier straight-through-source-solid framing premise, but the resulting pixels remain dark, edge-framed, or pointed at upper surfaces; they do not resolve approach continuity. This is a presentation/evidence limitation, not proof that camera math or source geometry is wrong.

R02's sampled source contact/probe and target-ray checks are static geometric checks; the `pie_boundaries_r01.json` smoke record is a runtime audit record, not a player capsule walk. Neither proves physical traversal through these specific seams. A refreshed capture after the pending bridge dressing and a brighter, surface-forward pass for the unreadable approaches are needed before visual signoff.
