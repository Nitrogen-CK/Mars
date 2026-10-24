# Source geometry placement adversarial review

## Latest source/math refresh: 35,315 then 35,313 rows

The previous deck, duplication, and Bone Bridge findings are now **confirmed corrected in generated data**:

- **11/11 Mill walking decks** have exact `SOURCE_CUBE_TX02` shape proxies. Independently intersected topZ5.008 floor veneers cover **256.4999999999993/256.5m²**, across92 floor rows. The former0.5m strips are included.
- **Zero exact duplicate transforms** in the35,315-row finaldata snapshot, compared with2038 duplicate pairs previously. Signature includes tile,assetID,position,scale,rotation rounded to1e-5.
- **Canal gallery6/7 now use WVC008 bone coping**, eight2m segments atY72.5/75.5, bottomZ3.38, topZ3.5, with matching bone posts. No blind Ossuary tile classification remains in those bridge rows.
- **Hoist feet now supported by two timber cantilevers:** CCS86 atX39.408/40.592,Y55.6,Z=-.35, scale(1,.75,1), yaw90. Actual world bounds for each are Xcenter±.1125,Y54.6..56.6,Z=-.35..0. All four hoist foot centers(X39.408/40.592,Y54.908/56.092) contact beam topZ0. Each beam embeds into retained Hub floor73 over Y56..56.5, width.225m, height.35m: **0.039375m³** source-solid overlap. The narrow beam supports the full0.224m wooden leg width; the wider foot band overhangs by17.42mm per side. Anchor plates centeredY56.2 fit within retained floor73 and rest on veneer topZ.008. This proves visible geometry contact, not structural engineering or runtime collision.
- Two initially added CCS87 braces were unsupported at their upper ends: they rose fromZ0 to1.44 between the frame's two leg rows rather than below the bearers. They are **absent in the subsequent35,313-row data**, so that concern is resolved.
- **Six shelf bundles corrected:** new WVC052 basesZ3.6305 sit3mm above middle shelf topZ3.6275. CCS69 actual H2.2m and source board centers(.12,.49,.87)h, thickness.045h, give board tops2.8135/3.6275/4.4635 above shelf base2.5. Bundle tops4.1305 leave **.234m** below upper board underside4.3645. The earlier floating/interpenetrating3.245 placement is gone.
- Reliquary closed tomb body spansZ2.5..3.7; lid spans3.5..3.7, intentionally embedding.2m per source recipe. Catacomb open body spansX[-19.5,-16.5], separate grounded lidX[-16.15,-13.15]: **.35m** lateral separation, basesZ0. This is intentional separate-lid composition, not unsupported lid floating.

### Remaining source/math findings pending main regeneration

At the last read, JSON still had35,313 rows and contained the following. Main has accepted removal of the chime floor piers and Pit prop; those removals were **not yet present in this inspected output**:

1. **Chime floor piers cross protected route centerlines.** CCS06 at(95.05,54,0) and(100.95,54,0), scale(.16,.16,1.1666667), has a0.192m square shell and height3.5m. Source BF→fe runs through(90,54) fromBF(98,54); BF→be goes straight from(98,54) to(108,54). Both paths cross the side-return shells of the piers, not merely a loose hero AABB. Remove the floor piers. There is real source overhead for replacement suspension: **Belfry roof0 bounds(88,44,24)..(108,64,24.3)** covers both beam ends(95.05,54)/(100.95,54). Nearest undersideZ24 gives **20.495m** hanger length from beam topZ3.505. No intermediate support was found; no invented crossbeam is needed. Long-chain appearance must be reviewed in PIE.
2. **Pit story rock candidate intrudes into route band.** WVC067 at(30.14,33.75,-4.992), bounds2×.8×1.2m, contains sampled d2→H2 centerline point(30.194,33.452,-5). This is a bounding-volume candidate rather than triangle proof for an irregular rock; removal is the conservative accepted response.
3. **Inherited floating plaque across S4 route:** CCS79 at(122,8.25,-1.2), bounds.6×.03×.6m, yaw0, lies on S4→SL X122 centerline with vertical span[-1.2,-.6] above floor-2.5. No supporting art nearby. At plaque center(122,8.25,-.9), nearest retained walls are1.5206906m away: Brineworks wall67/68 sidefacesX120.5/123.5, endingY8. Remove or wall-mount outside the3m mouth. This was inherited from the partial crossing dressing and was not previously caught by the auto-bay support test.

### Quantified clearance and its precise scope

Transformed actual mesh bounding boxes were tested against all46 protected ports and source link polylines at<=.25m XY intervals, using authored endpointZ and length-proportional interpolation through via points. This is a conservative art-intersection test; it does not prove capsule clearance or ramp contact.

- **Minimum art AABB distance to a protected port in a1.5m standing band is1.277419m** at Canal chain-e(88,24,-2.5), to inherited crossing cage(89.25,23.2255,-1). This cage starts exactly1.5m above port ground; floating-point bounds include that contact plane. For a taller1.8m band it also counts. Its nominal2.5m port radius1.25m leaves only **.027419m** radial margin. This distance is radial, not a directional aperture-width measurement.
- Excluding surfaces starting exactly at1.5m, the nearest obstruction is the hoist bearing shaft, whose rear extent reachesY56.3: distance **1.7m** to Ossuary port(40,58,0), leaving **.2m** beyond its nominal3m halfwidth. Source walking node wN(40,57,0) is only **.7m** from the same shaft envelope. Consequently the full nominal3m walking corridor is not proven clear around the hoist, even though the port center itself is free.
- **Minimum sampled walking-path AABB distance is0**, including the chime/Pit/plaque findings above. Other zeros are existing source hearth atK(16,50), low bank coping at Cistern path/water edges, and low floor-chain guides. They cannot all be called new blocking regressions: hearth occupies its authored source anchor and the low guides/banks require actual traversal/image review. No blanket "all routes clear" claim is supported.
- After removing chime floor piers, lowest hanging chime bound isZ2.09; retained floor art top.008 gives **2.082m overhead clearance** under chimes, beam lower bound3.4m. The long suspension chains stay above the beam.
- Bone Bridge rail inner faces remainY72.55 and75.45, giving **2.9m visual inner width**, identical to retained0.1m-thick rails centered72.5/75.5. Full3m nominal route width already differs from source rail inner width by.1m; the new art does not introduce that difference.
- Generic vault lowest visual edge remains **2.034m** above raised floor art at the tightest generated vault. This is independent of source low tunnels, which do not receive vault veneers.

Source port Z on stairs is not a reliable standing plane: some nominal ports lie immediately below nearby stair landing undersides. Simply subtracting portZ from every overhead solid produced spurious4.3cm/27.2cm "headrooms" at stair transitions. Those values were discarded instead of presenting them as player clearance. Actual ramp/player-camera observation is required there.

**Evidence boundary:** exact deck coverage, duplicate counts, timber/foot/rim contacts, shelf heights, source roof attachment, and transformed bounds are source/static proof. Actual clear passage, appearance of long hangers, contact shadows, visual clipping, player eye/capsule height, and movement through retained collision remain runtime/PIE work. Historical audit snapshots follow below; do not treat their resolved findings as current failures.

2026-10-24. Read-only audit of `fitted_placement.py`, `Output/fitted_instances.json`, `Output/Reports/source_baseline.json`, `zone_plan.json`, source v8c JSON, all three asset manifests, and the reused `PumpCisternKit/surface_fitting.py`. No Blender/Unreal execution or placement edits. Main retained prop selection/landmarks; later requested the bounded hero-support and duplicate checks recorded below.

## Follow-up snapshot: 37,325 rows

Main added broad-gallery floor classification and Canal bridge identity after the original findings. Latest inspected JSON had **37,325 rows**. This is progress, with three remaining confirmed defects:

1. **Four Mill deck strips still excluded:** classification `h<=.5,minXY>.6` preserves only7 of11 decks. Mill gallery2 dimensions(.5,7,.4), gallery6(.5,7.5,.4), gallery7(.5,6,.4), gallery9(.5,5.5,.4) are also walking deck partitions with topZ5.0. They total **13m²**. True narrow rails are0.1m deep. Use exact source indices0..10 or a threshold separating0.1m rails from0.5m strips.
2. **2038 exact same-asset/transform duplicate pairs:** 2001 CCS15 wall pairs,32 gallery-post pairs,4 auto-lamp component pairs,1 story-prop pair. Signature was tile,assetID,position,scale,full rotation rounded to1e-5. Import filtering tests substring `source wall`, which does not match retained role `source exposed wall veneer`. Example Hub CCS15 at(17,38.163,-2.5), scale(1,1,.833333), yaw0 appears at rows2014 and36421. These are coincident visible faces. Gallery corner post duplication includes Hub(20.5,39,0) and(20.5,41,0); per-room bay selection duplicates the rimE/rimS fixture/story location. Exclude structural imported roles explicitly and deduplicate final exact transforms after assembly.
3. **Hoist has two unsupported feet:** WVC013 at(40,55.5,0), four modeled foot centers X39.408/40.592 and Y54.908/56.092, derived from `heroes.py:_hoist_frame` at0.37×1.6m. The two south feet atY54.908 have only Pit floor top=-5m, giving a **5m unsupported drop** below their bases. North feet atY56.092 rest on Hub floor73 top0, bounds(34,56,-.4)..(46,56.5,0). The frame's center being over the well alone would not establish this; the actual individual foot positions do. Closest tested full-foot-envelope grounded candidate(38,57.5) lies only2.062m from Ossuary stair port(40,58), so shifting there blindly violates the current3m port exclusion. Main must choose a source-supported placement or omit the frame; do not invent structural/collision support across the well.

In the same snapshot, basic ground contacts of Court split mourner(15,88), Reliquary tomb(88,84), Brineworks salt pieces(99.5,15.5)/(100.5,16.5), Mill vat(88,106)/millstone(95,100.5), Catacomb tomb(-18,80)/separate lid(-14.65,80) match retained floor/deck topZ. Bone bundles are intentionally on shelf height, suspended bells on their socket assembly, and tomb lids on their body; ground-only tests were not mislabeled as unsupported for those components. Auto lamps increased to50: source-solid AABB penetration test still found0, and nearest protected-port distance remained3.00326489m. These checks do not certify full hero footprint or runtime sweep.

The following original findings preserve their earlier snapshot evidence; apply status must be checked after the next regeneration.

The placement JSON changed during this audit: first read 37,056 rows, later read 37,190. Structural gallery and lamp findings persisted in the later read. At the final calculation the fitter mtime was 1792839227.082, newer than placement JSON 1792839169.238: regenerate before treating the latest source as applied. Source baseline mtime was 1792837203.267.

## Confirmed high-priority defect: Mill decks classified as rails

`fitted_placement.py:52-66` hides every `Warrens_Greybox_gallery` actor, then turns each box into an upright CCS11 infill and posts based only on its longest XY dimension. That actor label contains both railings and walking platforms.

Mill gallery instance indices **0..10** are eleven broad, 0.4m thick walking deck partitions. Their total non-overlapping XY area is **256.5m²**, union bounds **(80,96,4.6)..(100,113,5.0)**. Example index0: center **(91.25,100.25,4.8)**, dimensions **14.5×8.5×0.4m**. Index1 is **(99,100.25,4.8)**, **1×7.5×0.4m**. The seven narrow gallery indices11..17 are genuine railings and require separate treatment.

For deck0, current rows36651..36658 use CCS11 scale **(0.90625,70.8333333,0.5)**, baseZ4.6, yaw0. This stretches the 0.12m fence depth to **8.5m**, rather than creating a walking surface. The first row is at **(84.90625,100.25,4.6)**. CCS11 is an open rail mesh; the opaque source deck is hidden. Retained collision can therefore support a player over visibly open art.

The shared fitter selects only `Warrens_Greybox_floor` tops. Current JSON contains **zero Mill floor veneer rows at Z5.008**, and calculated intersection with those eleven deck tops is **0/256.5m²**. Reported floor coverage **2700/2700 boxes, 8100 samples, missing0** excludes the decks entirely. Source `upper.z=5.0` agrees with deck top. This is a concrete coverage omission, not a sampling failure.

Recommended correction: classify broad gallery deck partitions independently, retain/source-skin them as solid floors with top contact at5.0, and replace only true narrow rails. Preserve source collision and the authored drop gap. If actor visibility remains coarse, restore exact source deck proxies or include every deck top in the structural surface input; do not leave hidden platform instances represented by CCS11.

## Confirmed concept identity mismatch: Bone Bridge uses iron

`bone=tile=='Ossuary'` at `fitted_placement.py:58` cannot select any current source gallery: baseline has **zero Ossuary galleries**. The Bone Bridge's two long rail partitions belong to **Canal gallery6 and gallery7**:

| Source index | Center | Dimensions | Current replacement |
|---|---|---|---|
| Canal6 | (74,72.5,3) | 8×0.1×1m | CCS11 iron infill + CCS09 posts |
| Canal7 | (74.5,75.5,3) | 8×0.1×1m | CCS11 iron infill + CCS09 posts |

`zone_plan.protected.ramps` identifies Bone Bridge from(62,74,2.5) to(84,74,2.5), width3m; MODEL04 and WVC007/008 supply ivory bone posts/coping. Select the actual source bridge gallery rows/footprint for bone treatment. This is visual identity only; keep inner clear edges and retained collision fixed.

## Independently confirmed structural checks

- **No cross-tile coplanar floor overlap:** transformed actual CCS13 bounds, including scale/yaw, were spatially bucketed and pair-tested for positive XY intersection between different tiles at the same topZ. Result **0 intersecting pairs, 0m² pair overlap**. This checks emitted ordinary floor veneers, not the omitted Mill gallery decks or non-horizontal ramp joints.
- **Ramps:** baseline contains **34** `Warrens_Greybox_ramp` instances; emitted coverage records **34** (Hub5, Court4, Ossuary2, WaterworksW6, Pit2, Canal3, Belfry3, Reliquary3, Mill1, Catacomb2, Brineworks3). Rotations are copied exactly. The shared math uses UE positive pitch toward+Z and roll taking local+Y toward-Z. This preserves source plane slope; it does not independently certify runtime collision.
- **Floor contact:** CCS13 actual bounds Z=-0.05..0m and base top offset+0.008m give veneer Z=[floor-0.042,floor+0.008]. Source seam backing thickness0.006m lies around original top. No raised 5cm slab is added above the retained walk plane.
- **Vault low edge:** minimum independently calculated row-base clearance over the highest supporting floor veneer is **2.034m**, e.g. Hub row center(4,43.5,-0.458), floor top-2.5, veneer top-2.492. Formula: source clearance2.2 - vault drop0.158 - floor raise0.008. Actual ceiling art bounds begin at localZ0, so this is its lowest bounding edge. Low source tunnels below2.2m do not receive vault veneers.
- **Wall visible projection:** CCS15 actual depth0.35m, center offset0.175-0.012=0.163m into source wall; visible bounding face projects **0.012m** into free space. Both sides of an ideal original corridor reduce visual clear width by0.024m. Existing collision stays at the original source face.
- **Port center safety:** all **46** zone-plan ports were tested against transformed AABBs of emitted wall veneers, gallery infill and gallery posts, over standing-body Z band[portZ+0.2,portZ+1.4]. Result **0 source-port center intersections**. This is point/band evidence, not a full capsule or full authored-width clearance proof. It also cannot validate a moving gate sweep.
- **Gallery count:** baseline contains **63** gallery boxes and fitter reports63 replacements, confirming the defect above is semantic classification rather than missing instance enumeration.

## Lamp normals and mount math

Audited all **47** automatically selected `closed-bay lantern cage` rows independently against source boxes. Imported front+Y gives outward normal **(-sin(yaw),cos(yaw))**. Recover source face as cageXY-normal×0.14m. All47 recover an actual source wall face at the hook height; **0 unsupported mounts**. The code's four mappings are correct: source north wall/front+Y yaw0; south180; west-90; east90.

Actual cage bounds are width0.35m, depth0.25m, height0.55m. Cage center0.14m out from the wall places its rear at **0.015m** out; structural veneer face is0.012m out, leaving **3mm** separation. Bracket center is0.02m out and actual depth0.25m, so its back extends **0.105m into the supporting source solid**. Hook base is cageBase+0.3935m; bracket top is cageBase+0.6435m versus cage roof bound cageBase+0.55m. Exact curved hook contact still requires the rendered assembled view; whole bounds alone cannot certify it.

AABB intersection of all47 cages against all tiles' unrotated source wall/roof/floor solids found **0 penetrations**. Closest auto cage center to an elevation-compatible protected port is Belfry **(91,49.14,1.45)** to port(88,49,0), distance **3.00326489m**; matches the 3m bay exclusion. No mount-normal reversal was found.

## Bounded seam and opening details

Gallery posts are centered on source partition endpoints rather than inset. On typical0.1m rails, each endpoint post extends **0.05m** beyond the source long-axis bounds. This is real extra visual geometry, though the port-center check above found no collision at a source port. At Mill drop, left rail index11 endsX87.5, right index12 startsX92.5; 0.1m end posts reduce the retained geometric gap from5m to **4.9m**, still containing the authored **X88..92** 4m drop opening. Preserve that inset if posts/materials change.

Tall open volumes intentionally omit faces with no applicable overhead cap and source height beyond10m. Excluded candidate counts are Hub163, Court1373, Ossuary38, WaterworksW193, Pit226, Canal1130, Belfry602, Reliquary116, Mill167, Catacomb5, Brineworks330. These are candidate segments, not unique visible holes. They cannot establish complete visual shell coverage; runtime camera evidence remains necessary, especially Court/Belfry landmarks. This review found no basis to extrapolate a roof or whole-tile wall over those volumes.

No live map writes, exports, original collision, or source geometry were changed by this review. Fix the Mill deck classification before visual acceptance; then regenerate and review the actual Mill walking view and both sides of the Bone Bridge. Other calculations above are static evidence only.
