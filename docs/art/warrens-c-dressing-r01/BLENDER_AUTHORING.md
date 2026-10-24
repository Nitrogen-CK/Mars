# Warrens C / Blender authoring handoff

## Start here

Open `blender/WarrensC_MaterialLibrary.blend`. It contains packed image resources,35 unique art materials and three review scenes: neutral swatches, a warm/cool lighting study, and atlas/decal cards. Review cubes/cards are NOT production props. Asset-marked materials may be appended or used through a Blender Asset Library. Material metadata contains the catalog IDs used in every brief.

Use `prop_catalog.csv` for production tracking, `prop_catalog.json` for tools and `briefs/<ID>_<Name>.md` for a copyable modeling request. `python get_brief.py H01` prints an individual prompt; `python get_brief.py --tile Mill --priority P0` prints a focused batch. No script generates150 finished prop meshes or changes Unreal.

## Recommended first batch (24 entries)

A01,A04,A07,A08,A10,A14,A21,H01,H02,H03,H04,H07,H11,H13,H14,I02,I03,I06,I12,I19,P01,P03,P05,L01.

Build this silhouette/interaction pass first, then finish the remaining P0 skins, P1 support groups and finally P2 accents. The150 entries are a comprehensive modular catalog, not a demand to author150 unique high-detail models before the level can be dressed. Several reuse one body or existing actor.

## Units, axes and pivots

The library uses metres:1 Blender unit =1m =100 Unreal cm. Catalog width/depth/height are centimetres. Blender modeling convention is width local X, depth local Y, Z up, visual front -Y. All pivots are explicit per asset; do not infer orientation from a rendered camera. Apply object scale before handoff. Use a1m cube and the actual78cm-diameter/150cm-high capsule for scale checks; the visible chef height is not clearance authority. Source anchor positions are authoring-plan coordinates for later placement, not vertex offsets: build each mesh around its local pivot, then resolve Level Instance local/world transforms during the eventual Unreal dressing pass.

Architectural modules use a grid contact corner. Floor/threshold skins A14/A15/A19 use a TOP corner with walking face Z=0 and thickness below it, so they do not float above the collision floor. Wall-mounted plaques use their rear-center contact plane. Axles pivot at their axis, levers at their hinge, clappers at their suspension and doors at the current gameplay hinge. Never center a door or lever because that makes the modeling screenshot easier.

All dimensions are modeling proposals unless `dimension_basis` names the source proxy envelope. Ten entries include exact source proxy positions/sizes. A crown module can be4m high inside a22m tower envelope: those are different quantities. Fit generic arch frames to retained door mouths before export; do not narrow them to a generic nominal opening.

## Geometry and components

- Favor cubes, low-sided cylinders, one broad bevel and flat shading. Large neutral faces and silhouette carry detail. No modeled threads, dense basket weave, engraved text or brick-by-brick geometry on distant surfaces.
- Catalog triangle ranges are proposed LOD0 art budgets, not tested engine limits or performance claims. Small details30-350, ordinary storage150-900, mechanisms300-1800, major landmarks700-4500 triangles are starting ranges. Use actual silhouette need to choose within them.
- Keep moving drum, pulley, hook, clapper, gate bars, dial faces, spindle, lid and lever handle separate. Put an axle/hinge empty at each documented pivot. Do not join every part of a mechanism into one static mesh.
- Keep one material slot where possible; use two for a real frame/alpha/emissive split. Fixed crate stacks/bone bundles may merge. Reuse the same crate body/lid, pipe diameter/collars, shelf divider and bone modules. Avoid a new material per prop variant.
- Unless a specific brief overrides it, variants are clean/base, one broad chip, one repair/salt-wear treatment and a modest silhouette change within the same envelope. They can be configurations or UV treatments instead of unique meshes: the open sarcophagus reuses its body/lid and the three dials reuse one blank. Interactive variants never change grip positions, collision footprint or pivot.
- Use opaque low-poly leaf and rope geometry for the main silhouette. Alpha cards are reserved for a few small accents, waterlines and flame shapes; do not layer many cards through the player camera.
- Static dress has NoCollision by default. Retained greybox and existing interactive actors remain collision authority. New UCX is a separate review step, not an automatic byproduct of mesh generation.

## UVs and color

UV0 is the selected palette/trim/tiling scheme; UV1 is a clean non-overlapping lightmap UV only when the eventual lighting pipeline requires it. Keep texel scale consistent with material `tile_metres`, use the documented trim gutters and keep glyph UV islands centered in their atlas cells. If the consuming material uses vertex A as cavity, default it to1 when no cavity is authored; otherwise confirm that material's vertex contract. Pick vertex RGB or texture as the color owner. Never apply a world-lit beauty render as base color.

## Interaction interfaces

I02/I03/I06/I10/I11/I15/I16/I17 and light skins link to current source contracts where known. These are art handoffs, not proof those entities are placed or fully integrated in the current map. Preserve actual actor bounds, grip frames, traces, visual signal consumers, authoritative state and phase timing during later integration. Do not create a new control script to accommodate a mesh pivot.

P3 remains latched after the pack press; no second player must hold it. P4 uses six authored glyph shapes and a runtime/configured three-symbol phrase; no baked answer in decorative paint. The Red key remains on the+2.5m loft. P7's curing station remains at the Salt Mill source. Blank panel/notice surfaces are intentionally available for current widget/decal logic.

## Export/handoff checklist

1. Save a dedicated per-kit `.blend` with source names and separate moving parts. Keep source materials available and apply scale.
2. Name final static meshes `WarrensC_<Name>_Mars_SM`; LOD and collision names must follow the project's actual import convention. A proposed convex hull uses `UCX_<exact mesh name>_00` only after collision review.
3. Export only production mesh collections, never QA cubes/cards/cameras/lights. For FBX, state centimetre conversion and axes explicitly and round-trip a1m cube: imported size must be100cm. The library contains no finished prop FBX and makes no export-roundtrip claim.
4. Check normals, zero-area triangles, mirrored UVs, bevel scale, pivots, separate animation parts, packed vs relative texture paths and correct normal green channel. Keep material paths relative for transport.
5. On later Unreal import, preserve surface/physical-material routing, entity ownership, gate sweeps and grips. Recheck the ten source views, the three crossings, pack clearance, ladders/drops and dark player-camera readability. Use CkAuto for any required future gameplay/map tests.

## Out of scope for this handoff

No live map placement, new puzzle or quest, new edible item, monster rig, vermin implementation, pickup/throw logic, CkFoundation change, Unreal material asset or lighting rebalance. Reuse the existing backpack, Red key, lantern behavior and gameplay controls. Decorative sealed jars must not imitate a collectible Pickle Mimic or required ingredient.


## Expanded visual coverage

See [VISUAL_COVERAGE.md](VISUAL_COVERAGE.md): every one of the149 new-model candidates has a linked modeling sheet. I14 reuses the existing Red key. There are38 modeling sheets and11 exploratory district composition studies. The [Chain Crossing / Sluice dossier](sections/chain-crossing-sluice/PREVIEW.html) adds88 local component entries,23 model sheets and4 assembly/player-view sheets with individual Blender briefs.

District DRESS images are exploratory composition studies, not technical model sheets or placement plans. Their in-image IDs and relative arrangements are non-authoritative and sometimes conflict with the catalog/source; use the linked MODEL/CS sheets and written briefs for asset identity, dimensions and placement constraints. DRESS06 in particular must not be used to add a waterfall or stepping-stone crossing. These known limitations are deliberate review flags, not runtime acceptance.
