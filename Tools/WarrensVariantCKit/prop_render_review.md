# Variant C prop and organic preview review

Review is against the generated neutral previews in `Output/Previews/` and `model_catalog.json`; it is a static silhouette/material-read check, not an in-map fit or runtime review. Representative previews are linked below.

| Preview | Static observation |
|---|---|
| [WVC045 PreparationBench](Output/Previews/WVC045.png), [WVC046 StorageCrateBody](Output/Previews/WVC046.png), [WVC047 StorageCrateLid](Output/Previews/WVC047.png) | Bench reads as stable furniture; crate body has a visible open interior and lid remains separate. |
| [WVC048 OliveStorageJar](Output/Previews/WVC048.png), [WVC049 ServingBowl](Output/Previews/WVC049.png), [WVC058 Cup](Output/Previews/WVC058.png), [WVC059 Platter](Output/Previews/WVC059.png), [WVC061 MortarPestle](Output/Previews/WVC061.png) | Open mouths/cavities and handles are legible in these views; reusable tableware silhouettes are usable. Jar handle is partly occluded from the current camera angle. |
| [WVC050 SaltCrystalChunk](Output/Previews/WVC050.png), [WVC051 SaltHeap](Output/Previews/WVC051.png) | Chunk reads as faceted salt/rock. “Heap” reads as separated upright chunks more than a low piled mound; use sparingly or revisit the silhouette. |
| [WVC052 BoneBundle](Output/Previews/WVC052.png), [WVC071 BoneFragment](Output/Previews/WVC071.png), [WVC082 SingleChimeBone](Output/Previews/WVC082.png) | Bundle is legible but very squared, with prominent tie strips and rectangular shafts. Fragment and single bone read as blunt stylized pieces; use WVC082 for the chime recipe rather than WVC052. |
| [WVC053 OssuaryUrn](Output/Previews/WVC053.png), [WVC054 ReliquaryBox](Output/Previews/WVC054.png) | Box is clear and well-proportioned. Urn preview has a dark opening under its top knob; confirm it is an intended mouth rather than a cap/mesh gap. |
| [WVC055 HerbDryingRod](Output/Previews/WVC055.png), [WVC056 DryingRack](Output/Previews/WVC056.png), [WVC069 DryHerbBunch](Output/Previews/WVC069.png) | Rod and rack are stable, plain silhouettes; herb bunch reads clearly as tied foliage. |
| [WVC057 TallowPot](Output/Previews/WVC057.png), [WVC064 CandleHolder](Output/Previews/WVC064.png), [WVC065 EmberBrazier](Output/Previews/WVC065.png), [WVC066 ShaftLightFrame](Output/Previews/WVC066.png) | Holder and brazier silhouettes are readable; keep them unlit art only. Verify the pot’s light-colored top is the intended wax surface. |
| [WVC062 MillHopper](Output/Previews/WVC062.png), [WVC037 CuringVat](Output/Previews/WVC037.png), [WVC027 VatLiquidInsert](Output/Previews/WVC027.png) | Hopper has an open upper funnel and legs; lower throat is hard to judge from the single camera. Vat insert is a thin surface and should sit below the rim. |
| [WVC067 RootShort](Output/Previews/WVC067.png), [WVC068 RootLong](Output/Previews/WVC068.png), [WVC075 RockButtressLarge](Output/Previews/WVC075.png) | Roots are sharply faceted and stylized, with bend/taper; suitable as non-traversal wall dressing after clearance fit. Buttress is a simple steep wedge, readable as rock but generic. |
| [WVC070 MushroomCluster](Output/Previews/WVC070.png), [WVC073 CobwebCorner](Output/Previews/WVC073.png), [WVC074 ShelfDivider](Output/Previews/WVC074.png) | Cobweb and divider read clearly. Mushroom caps show dark center holes/punctures in the preview; verify mesh normals/opening intent before broad use. |
| [WVC072 DustCardPlane](Output/Previews/WVC072.png), [WVC079 LowMistCard](Output/Previews/WVC079.png) | Both are nearly invisible at this neutral preview scale/material; they need a visibility check with their authored alpha materials before placement. |
| [WVC076 BellLipDamageInsert](Output/Previews/WVC076.png), [WVC077 ServiceBellSmall](Output/Previews/WVC077.png), [WVC078 BellBracket](Output/Previews/WVC078.png), [WVC080 BrokenBeamEnd](Output/Previews/WVC080.png), [WVC081 SarcophagusLid](Output/Previews/WVC081.png) | Damage insert, bell, bracket, and lid silhouettes are readable. BrokenBeamEnd looks mostly like a plain rectangular beam with a small protruding end, not an obvious broken/splintered end. |

## Catalog-to-manifest mismatch

`model_catalog.json` maps source `L07` CandleTrio to production ID `PWC23` with a 35×35×50 cm reuse basis. The actual `Tools/PumpCisternKit/Output/asset_manifest.json` defines `PWC23` as one 15×15×30 cm `CandleStub` (also confirmed by the matching `PWC23` preview). The placement proposal therefore composes three PWC23 stub instances per WVC064 holder and uses canonical `source_id: PWC23`; the catalog reuse mapping itself remains untouched and should be reconciled by the integration owner.

## Fit boundaries

`prop_assemblies.json` uses only source anchor coordinates or explicit offsets within the corresponding source envelope. It omits the P2 chain run pending its exact route polyline, the roof roots pending ceiling-contact transforms, and source-owned clue/control props. All entries remain proposals: collision, routes, gameplay actors, and port clearance require the independent map fit requested by the parent task.
