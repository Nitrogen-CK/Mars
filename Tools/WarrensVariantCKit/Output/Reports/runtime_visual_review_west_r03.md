# West room actual-pixel review r03

Actually inspected all12 assigned original1600×1000 PNGs under `Output/Runtime`, with fresh2026-10-24 mtimes **18:11:22–18:11:55UTC**. These images supersede the17:40 room observations. No Unreal/Blender calls or asset/map edits.

## Outcome

**Ceiling lattice issue is visually resolved:** Hall, Closet, Ossuary and Ford-west now show quiet, flat masonry slab undersides; the previous bright triangular rib lattice is absent. **Ford-east approach framing improved:** floor, low candle and Belfry base/entry are now visible rather than a bell-only upward view. **Bridgehead near approach improved** with the new practical: near floor/wall and a short rail/entry segment read, although the middle bridge is still too dark in this image to accept deck/rail continuity.

**One confirmed camera defect remains in the captured r03 pixels:** ROOM_rimN faces an original wall, not the rim approach. Its old eye(43.4592201,56.1086554,1.4)→target(45,60,1) intersects retained Hub wall84 after approximately2.586m, at(44.4068,58.5018,1.154). Original wall bounds(42.5,58.5,-.4)..(47,59,3.7). This is a review-camera defect, not evidence a new wall blocks the authored route.

No detached fixture, unsupported bone bundle, exposed prototype grid, new floor crack, or impossible hoist attachment was confirmed in the **visible lit portions**. Dark or cropped contacts remain unverified; this statement is not whole-room signoff.

## All12 room observations

| Room / mtime UTC | Visible evidence and remaining limitation |
|---|---|
| **hall /18:11:22** | Near tile floor, right block wall/urn/practical and warm brazier read coherently. Ceiling is now a continuous slab grid without the old lattice. No visible floor break. Brazier is foreground-cropped; distant opening/rails remain dark. No full-room traversal or pack-plinth conclusion from this angle. |
| **closet /18:11:25** | Gallery fascia, slab soffit and two lit masonry returns remain readable; existing teal interaction outlines remain in dark center/foreground. No obvious detached gallery edge. Lower ladder landing/control-side clearance is still too dark to verify. |
| **court /18:11:28** | Lit foreground floor continuous between wall ends. Four-legged live actor now occupies lower-center, with feet appearing on floor; do not classify that actor as a dressing placement regression. Distant mourner wing/base light visible; statue figure/front and surrounding bays remain silhouettes. |
| **court-pit /18:11:31** | Broad near floor and same four-legged actor visible at left. Tall wall end and angular warm stair/transition to its right remain readable only in silhouette. No demonstrated new blockage or floating art; detailed stair junction still unverified. |
| **rimW /18:11:34** | Timber frame, drum/shaft and a practical form a coherent hoist silhouette. Rail line continues around the visible Well edge. No obvious detached pulley/drum. Bearer/embed contacts and floor immediately under the hoist are dark, so earlier source-contact proof is not promoted to pixel proof. |
| **rimE /18:11:37** | Near stone corridor/threshold and green water-colored strip visible; plain slab soffit now fits this enclosed passage. Far tower details small/dark. ROOM view does not prove the separate protected glyph clue legible, nor does the green strip alone establish water penetrating floor. |
| **rimN /18:11:40** | Close masonry face fills right-half; left-half largely black. Does not show the rim route. Confirmed original-wall intersection described above; camera target fixed after review, awaiting recapture. |
| **rimS /18:11:43** | Frontal hoist chain/pulley/drum and rear rail line remain identifiable. Hoist feet/bearers are not sufficiently exposed to certify supports visually. No newly visible mechanical contradiction. |
| **ossuary /18:11:46** | Warm shelves and bone bundles clearly visible. Bundles read seated on middle boards; upper shelf gap remains. Open near floor/passage between shelf groups has no visible added blockage. Flat slab ceiling replaces lattice. Other puzzle/bridge-side controls are outside useful framing. |
| **bridgehead /18:11:49** | New practical lights broad left near wall and tiled approach. Short right rail/entry post and far gate are now discernible. Central/middle bridge deck is still black: partial approach evidence improved, entire crossing/ivory rail identity not accepted from this frame. Hard rectangular patch on lit left wall reads as a shadow; no unsupported plaque/fixture identity is inferred. |
| **ford-w /18:11:52** | Near tile floor, masonry corridor walls and flat slab ceiling read continuously. Forward opening/green water-colored strip still visible. Far ford/ramp junction remains dark; no definite seam hole shown, physical wade/step continuity not established by still image. |
| **ford-e /18:11:55** | Camera now faces forward: near floor/candle at left and cool Belfry base/entry at center-right are visible. No obvious isolated floating object or floor break on illuminated tiles. Dark central transition prevents a complete landing-edge review; large plain rectangular tower feature is visible, but this ROOM frame does not identify it as erroneous clue masking. |

## Authorized single camera correction after this capture

Parent authorized **only ROOM_rimN target** in `make_views.py`. Changed target **(45,60,1)→(48.5,57,1.4)**, the actual authored wN→wE route via vertex. Camera eye remains **(43.4592201,56.1086554,1.4)**. This is a horizontal tangent view along the rim, not an upward hoist close-up.

`python Tools/WarrensVariantCKit/make_views.py` passed (exit0). Before/after generated JSON comparison found **exactly one changed field: ROOM_rimN.target**, with all55 unique IDs retained. Exact source protected VIEW_rim-glyphs eye(48,50,1.4)/target(102,50,2) unchanged. New target segment has **zero source wall/roof/floor/ramp OBB intersections**, and **101/101** projected approach-line samples have an actual source floor topZ0. These are source/static checks, not a runtime sweep. Parent must recapture ROOM_rimN; the r03 PNG reviewed here predates the one-line correction.

No global brightening is requested. Remaining dark portions are explicitly evidence limits. Successful PIE smoke and these images do not by themselves prove player-input traversal, dynamic controls, crouch/pack fit, all-direction seam continuity, or hidden faces.
