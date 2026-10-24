# Architecture / interaction rendered review

Reviewed 2026-10-24: all 29 actual `Output/Previews/WVC001..012.png` and `WVC028..044.png`, the corresponding `Output/asset_manifest.json` entries, `model_catalog.json`, and `generators/architecture_interaction.py`. These are isolated asset renders, not placement, animation, collision, or PIE acceptance.

## Result and required regeneration

The existing renders show real arch/window voids, an open curing vat, and separate moving leaves without attached static surrounds. Seven entries need regeneration after the generator corrections below. Existing FBX/GLB/previews/manifest were left untouched; the current images therefore still depict the defects.

| IDs | Confirmed rendered/source defect | Generator correction |
|---|---|---|
| WVC010 / A20 | Black patches at both niche sill/jamb corners. Jambs occupied Z=0..0.68h while sill occupied 0..0.11h, sharing exposed Y faces. | Jambs now start at sill top 0.11h and retain spring top 0.68h (`architecture_interaction.py:188`). |
| WVC028 / I01 | Black top strap lanes. Stone cap and straps both ended at Z=h with overlapping top planes. | Stone cap ends at 0.96h; straps start there and end at h (`:94`). |
| WVC029 / I02 | Black panel corner rectangles. Full-height side boxes overlapped the top/bottom crossbars on exposed Y planes. | Side boxes span 0.11h..0.89h between crossbars (`:205`). |
| WVC033 / I08 | Preview reads as a plain brass cylinder; the separate rim is invisible. Old rim front=-0.37d, buried behind cylinder front=-0.5d. | Rim front=-0.58d and rear=-0.40d, visibly proud and embedded into face (`:237`). |
| WVC040 / I16; WVC041 / I17 | Black rectangles at rail end shoes. Wooden rail end and metal shoe end faces coincided. | Wood rails span 0.12h..0.88h between shoes; segment envelope unchanged (`:268`). |
| WVC043 / I19 | Render shows an offset rim/strap assembly. Old rim rear=-0.28d while leaf front=-0.10d: 5.4cm gap at d=30cm; boss rear left a 6cm gap. | Rim rear=-0.05d intersects leaf; strap rear=-0.015m intersects leaf front=-0.03m; boss rear=-0.03m contacts leaf (`:281`, `:285`). |

The coplanar geometry is confirmed from the generator. Its responsibility for the black patches is strongly supported by the matching locations in all five images; elimination of the visible artifacts still requires the new renders.

## Complete bounded visual coverage

| IDs | Observation and remaining placement contract |
|---|---|
| WVC001 A05 | Low stepped stone foot, broad bevels; base perimeter must remain outside retained path. |
| WVC002 A06 | Separate inverted stepped capital; contact underside to retained pier top. |
| WVC003 A07 | Open segmented arch, no opaque backing. 3m clear width below 2.3m spring; curved upper aperture is narrower. |
| WVC004 A08 | Open segmented arch, no opaque backing. 2.5m clear width below 2.15m spring. |
| WVC005 A09 | Plain tapered stone wedge; use as a real arch accent, not a false door marker. |
| WVC006 A11 | Sectional quarter rib with open underside, not a complete bridge; mirror/repeat on exterior without intruding into 3m bridge clear deck. |
| WVC007 A12 | Broad bone post with foot, shaft, faceted cap; position outside retained railing/path envelope. |
| WVC008 A13 | Three chunky coping blocks; inner edge must stay outside bridge clear width. |
| WVC009 A19 | Thin iron threshold. Manifest Z=-3cm..0 confirms thickness below walking face; do not place it as a raised 3cm step. |
| WVC010 A20 | Closed pointed decorative niche; backing is intentional, never place on a route/window. Corner correction pending render. |
| WVC011 A23 | Irregular stone seam cover; never span source windows or new apparent doorways. |
| WVC012 A24 | Genuine open arched window; clear width 1.584m below 0.9m spring, not a rectangular 2.2m clear opening. Match the source sightline, not only the exterior envelope. |
| WVC028 I01 | Broad empty key plinth; corrected straps pending render; existing pickup remains separate. |
| WVC029 I02 | Three real annular dial seats on blank housing; no glyphs/control solution. Corrected corners pending render. |
| WVC030 I04 | Solid Y-axis axle with collars; center pivot. Capping is appropriate for a solid axle. |
| WVC031 I05 | Pointed-bottom bars and two rails only; no stationary frame. Existing gate controls motion and collision. |
| WVC032 I06 | Broad empty pressure-plate center with raised perimeter; no invented control. Visual center below rim does not define physical activation plane. |
| WVC033 I08 | Blank center-pivot dial, Y axis; corrected visible rim pending render. Runtime supplies glyph insert. |
| WVC034 I09 | Narrow bar leaf only, no ladder/static surround. |
| WVC035 I10 | Lever arm, grip, and hinge hub only; no wall plate attached to moving mesh. Hinge adapter required. |
| WVC036 I11 | Real keyhole opening visible through escutcheon; center pivot is not rear mounting plane. Back/contact offset must come from actual bounds. |
| WVC037 I12 | Open octagonal rim and inner walls, recessed floor; no top disk. Separate lid required. Interior floor/carrier is at 0.168m/0.173m before finish. |
| WVC038 I13 | Separate chamfered lid with handle; bottom-center pivot. Seat bottom at actual vat rim height; keep runtime grasp/motion separate. |
| WVC039 I15 | Moving backside lever arm/hub only; no hall-side handle. Hinge adapter required. |
| WVC040 I16 | 1m ladder segment, three broad rungs; corrected end shoes pending render. |
| WVC041 I17 | 1.25m ladder segment, four broad rungs; corrected end shoes pending render. |
| WVC042 I18 | Bars/rails leaf only; shared seal P29 is a separate carrier. Do not introduce a hold requirement into source P3 latch. |
| WVC043 I19 | Oval door leaf and its trim only, no masonry surround; corrected trim contact pending render. Existing hinge/sweep must drive mesh. |
| WVC044 I20 | Broad empty pack plinth; source shared backpack remains separate. |

## Reference fidelity and deliberate source precedence

Compared actual model sheets including `MODEL01_SharedMasonryKit.png`, `MODEL10_InteractionHousingKit-r02.png`, `MODEL25_LaddersAndBacksideGateHardware.png`, `MODEL26_VaultDoorCampPlinthAndBox-r02.png`, and `MODEL37_MillAndCuringVatBreakdown-r02.png` with the renders. Other cited architecture sheets were inspected during implementation (MODEL04, MODEL13-r02, MODEL15).

The generated kit matches the broad, faceted, low-detail visual vocabulary but is simpler than the painted sheets: arch shoulder/foot trims, masonry surface variation, timber plank breaks, and fasteners are reduced. This is a style limitation, not a claim of exact image fidelity. MODEL26 depicts a timber door and timber-topped camp plinth; authoritative catalog I19 materials TX09/TX01 and I20 TX01 instead produce iron/stone. MODEL10 depicts a broad timber/stone panel assembly; catalog I02 is a narrower 100x40x140cm housing with its listed palette. No unsupported material or envelope changes were made to imitate contradictory concept imagery.

## Dimensions, checks, and continuity traps

Confirmed all 29 existing exported manifest envelopes match declared dimensions with maximum error 0.000040cm. This checks bounding dimensions, not apertures or runtime socket agreement. A19 exported top-contact Z is effectively zero; I04/I08/I11 are center-pivot; remaining entries are bottom-center.

After the source fixes: Python AST parse, all 29 source dispatches through a stdlib recording Builder, positive primitive sizes/nonzero rods, valid mesh indices, and eight contact/plane assertions pass (exit 0). No Blender or Unreal was invoked. The post-fix exports and visual result remain unverified.

Placement acceptance must preserve: actual source arch/crawl widths and upper headroom; window sightline apertures; Bone Bridge inner clear edge; lower/upper floor boundaries; ladder retained endpoints; threshold contact plane; existing door/gate/lever pivot, sweep, collision, grip and trace contracts. Production bottom-center is not a substitute for those runtime pivots. Panel dial socket flag coordinates are explicitly pre-finish and need transformed bounds/socket verification. Imported front is Unreal +Y; north wall yaw0, south180, west-90, east90. No whole-zone collision or material override is authorized by this asset review.
