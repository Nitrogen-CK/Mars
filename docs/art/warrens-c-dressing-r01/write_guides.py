"""Human-readable dressing plan, source-derived room coverage and Blender production contracts."""
from pathlib import Path
import csv,json,html,math,re
ROOT=Path(__file__).resolve().parent
layout=json.loads((ROOT/'references/warrens_v8c-source.json').read_text())
catalog=json.loads((ROOT/'prop_catalog.json').read_text())
ids={p['id'] for p in catalog}
def write(name,text):
    text=text.replace('126','150').replace('57 P0 core,56 P1 support,13 P2 optional','67 P0 core,66 P1 support,17 P2 optional')
    text=text.replace('twelve Blender modeling-reference sheets','38 Blender modeling-reference sheets and 11 district assembly sheets')
    if name in ['README.md','BLENDER_AUTHORING.md']:
        text+='\n\n## Expanded visual coverage\n\nSee [VISUAL_COVERAGE.md](VISUAL_COVERAGE.md): every one of the149 new-model candidates has a linked modeling sheet. I14 reuses the existing Red key. There are38 modeling sheets and11 exploratory district composition studies. The [Chain Crossing / Sluice dossier](sections/chain-crossing-sluice/PREVIEW.html) adds88 local component entries,23 model sheets and4 assembly/player-view sheets with individual Blender briefs.\n\nDistrict DRESS images are exploratory composition studies, not technical model sheets or placement plans. Their in-image IDs and relative arrangements are non-authoritative and sometimes conflict with the catalog/source; use the linked MODEL/CS sheets and written briefs for asset identity, dimensions and placement constraints. DRESS06 in particular must not be used to add a waterfall or stepping-stone crossing. These known limitations are deliberate review flags, not runtime acceptance.\n'
    (ROOT/name).write_text(re.sub(r'(?m)^-(?=\S)','- ',text.strip())+'\n',encoding='utf-8')

regions=[
dict(id='Hub',rooms=['hall','closet','rimW','rimE','rimN','rimS'],concepts=['ENVC-01','ENVC-11'],materials=['TX01','TX02','TX08','TX09','TX10'],
    identity='West bank: the hoist, a clear circular Well rim, and a modest warm arrival island. The shaft and timber silhouette orient the whole district.',
    hero=['H01','H02','H03','H04','I20','L09'],support=['A10','P03','P05','P25','P26','P28','D15','L01','L04'],
    placement='Keep the hoist at [40,55.5,0] within its 1.6 x1.6 x7.5m source proxy. Place crates/rope behind the rim path and on closed wall bays. The pack plinth remains at [10,47.5,0]. Closet dressing frames the existing 5m scout ladder and closet-side bar control.',
    avoid='No decorative cage that implies a new rideable lift. No opaque hoist banner in the east-rim glyph view. No handle on the barred hall face. Preserve the shaft opening and walkable rim.',
    views=['hall-hoist','rim-glyphs','pit-hoist','ford-hoist','loft-well'],story='One service notice and one rope repair cluster; the exit stays legible without adding arrows to every wall.'),
dict(id='Court',rooms=['court','court-pit'],concepts=['ENVC-01'],materials=['TX01','TX04','TX06','TX08'],
    identity='A broad hunting court with one split mourner silhouette. Low interrupted storage at the edges; a quiet floor in the center.',
    hero=['H14'],support=['A21','A22','P26','D01','D04','L08'],
    placement='Source statue center [15,88,0], proxy 2 x1.2 x4.5m. Keep the 0m rim and -1.5m sunken court distinct. Dress outer walls and non-traversed alcoves instead of filling the combat floor.',
    avoid='No crate maze, pillars or hanging roots that alter retreat routes. Do not raise the sunken floor with debris. Optional mushrooms must not masquerade as required harvestable food.',
    views=[],story='One abandoned service delivery at an outer wall, with sparse royal cloth caught on the stone.'),
dict(id='Ossuary',rooms=['ossuary','bridgehead'],concepts=['ENVC-06','ENVC-03'],materials=['TX01','TX06','TX08','TX10'],
    identity='First-bank bone storage at +2.5m. The west pack plate and the east-bound Bone Bridge are visually connected by one shared Mourner seal.',
    hero=['I06','P29'],support=['P01','P11','P12','A20','L04','D07'],
    placement='Plate remains at [42,66,2.5], source proxy 2 x2 x0.3m. Bone-stack envelopes stay at [52,68,2.5] and [50,76,2.5], each 6 x1 x2.6m. Use merged bone bundles inside those envelopes.',
    avoid='No shelf across the south-east sight window or bridge mouth. P3 latches after a pack press; art must not imply a simultaneous hold or a second player waiting here.',
    views=['bridge-hoist','bridge-bell'],story='Bone bundles are stacked for kitchens rather than medical realism. A repeated small Mourner badge points to the related cache gate, not an invented lock sequence.'),
dict(id='Waterworks-W',rooms=['pump','cistern'],concepts=['ENVC-10','ENVC-05'],materials=['TX17','TX09','TX11','TX01'],
    identity='A damp low western utility district. The 6m pump is the heavy audio/shape landmark; the Cistern is a broad readable shallow basin.',
    hero=['H13','W10'],support=['W04','W05','W06','W07','W09','P05','D02','D11','L01'],
    placement='Pump source [54,22,-2.5], size2 x2 x6m. Cistern water remains the source 0.4m pool, not a deep new hazard. Pipes stay against closed walls; curved joints reuse the one pipe diameter. Frame the barred Chain Crossing view from the Pump end.',
    avoid='No pipe across the humped connector or source ramps. No new ledges across deep water and no decorative turnable wheel beside the real control. Wet decals remain visual only.',
    views=[],story='Use one repair patch and a small drain leak to suggest maintenance. Floor chain and moving bars are P2 tells; do not bury them under rust/debris.'),
dict(id='Pit',rooms=['lair','vault'],concepts=['ENVC-12'],materials=['TX04','TX17','TX08','TX09'],
    identity='The lowest cavern at -5m. One compact Vault mouth, roots framing the shaft above, and an earned scout return ladder.',
    hero=['I19','I11','I16'],support=['A21','A22','D01','D02','L04'],
    placement='Keep Red-key door source [57,60,-5] and its250cm span. Ladder uses the source [19,40] baseZ-5,height5m and the authored closet top. Roots can use the [35,46,-5] source envelope but must not occlude the hoist view.',
    avoid='No extra stepping stones, new platforms or climbable root escape. No glowing loot-style mineral heaps. Vault sweep, key lock and ladder arrival areas remain clear.',
    views=['pit-hoist'],story='Very few small props. One old supply remnant near a closed wall should make the scale of the cavern stronger.'),
dict(id='Canal',rooms=['ford-w','ford-e'],concepts=['ENVC-03','ENVC-04','ENVC-05','ENVC-11'],materials=['TX01','TX06','TX17','TX09'],
    identity='The district edge and exactly the authored crossing beats: Bone Bridge above, always-open shallow Ford, controlled Chain Crossing below. Both towers remain recognizable.',
    hero=['A11','A12','A13','H10','W01','I05'],support=['A10','P27','P28','D13','L03'],
    placement='Use the source tile ports: Bone Bridge W/E[66,74,2.5]/[88,74,2.5], Ford[66,49,-2.5]/[88,49,0], Chain[66,26,-2.5]/[88,24,-2.5]. Decorative bridge skins preserve existing deck widths, rails and movement collision. Ford water is0.4m; canal depth is2m.',
    avoid='The paintings contain scenic stones; do not turn them into a fourth crossing. Retain source deep-water rails and do not add climb-out props. No banners across both-tower views or the clue ray.',
    views=['ford-hoist','ford-bell','bridge-hoist','bridge-bell','rim-glyphs'],story='Hoist-hook marks on the west bank, bell marks on the east. Shape redundancy works in darkness; color is secondary.'),
dict(id='Belfry',rooms=['belfry','bell-loft'],concepts=['ENVC-02','ENVC-07'],materials=['TX01','TX10','TX08','TX06'],
    identity='East-bank vertical landmark: 22m tower, high bell around+16m, accessible loft+2.5m. A coherent panel/lever/key family sits at reachable authored locations.',
    hero=['H06','H07','H08','H09','I01','I02','I07','I08','I09','I10','I17'],support=['P27','A24','L03','P14','P11','W01','P25'],
    placement='Key plinth [104,60,2.5], dial panel[108,46,0], loft lever[102,60,2.5]. The source ladder at[100,57] hasheight2.5m. The large west-facing clue is read across the canal from the Well rim; keep glyph discs individual.',
    avoid='Never suspend the Red key at the high bell. Do not bake a random three-symbol answer into a mural. Keep the intended Reliquary rail drop and landing open; do not repair that authored gap with a decorative railing.',
    views=['ford-bell','bridge-bell','rim-glyphs','loft-well','belfry-pit'],story='Sparse bell cloth and bone chimes, not rows of extra collectible-looking keys.'),
dict(id='Reliquary',rooms=['reliquary'],concepts=['ENVC-07','ENVC-06'],materials=['TX01','TX10','TX08','TX06'],
    identity='Brass-and-stone storage on the east side of the Bone Bridge. One tomb silhouette and a stair that offers the authored loft approach.',
    hero=['H15','I18','P29'],support=['P01','P13','A20','L04','P27'],
    placement='Source tomb [88,84,2.5] size3 x1.5 x1.2m. Keep the P3 Mourner gate at[100,76,2.5]. Use shelves on closed wall bays, with generous blank space around the reward target and stair/rail-drop approach.',
    avoid='No extra gate, secret interactable badge or simultaneous co-op plate requirement. Keep the mill-return drop landing clear.',
    views=['bridge-bell','bridge-hoist'],story='One repaired brass box and an abstract kitchen-harvest mural can supply history without looking like a second puzzle.'),
dict(id='Mill',rooms=['mill'],concepts=['ENVC-08','ENVC-09'],materials=['TX05','TX08','TX12','TX15','TX09'],
    identity='The +5m Curing Room: a clear brine vat work island, an octagonal millstone, salt chute and drying rack. This is the required P7 support stop.',
    hero=['H11','H12','I12','P30'],support=['I13','P02','P05','P08','P09','P10','P14','P15','P22','P23','D03','L02'],
    placement='Curing vat [88,106,5], proxy2.4 x1.6 x1.4m; millstone[95,100.5,5],size2.5 x2.5 x2m. Stage pack space beside the station and retain all approach/control points. Dress the rack behind, not above the hand interaction plane.',
    avoid='No sack pile on the Reliquary stair or the authored one-way mill rail drop. Do not move the required vat to the Brine Larder just because a painting shows a workbench there.',
    views=[],story='One curing-service patch is enough. The room reads as a process stop through vat, rack and salt rather than a new tutorial wall of text.'),
dict(id='Catacomb',rooms=['catacomb'],concepts=['ENVC-12'],materials=['TX04','TX01','TX06','TX19'],
    identity='A low, far-west burial bead with one open tomb and a descending connection into the Pit. More irregular shell, fewer manufactured props.',
    hero=['H15'],support=['A20','A21','P11','P12','D07','D14','L04'],
    placement='Source open tomb[-18,80,0],size3 x1.5 x1.2m. Keep the Court crawl, the dive and arrival/exit headroom exactly as authored. A sparse urn grouping can mark a closed side bay.',
    avoid='No tomb lid across the crawl, no low web over an interaction target, no cache doorway painted onto a closed wall.',
    views=[],story='A faded decorative harvest mural is optional; do not use the six Bellkeeper glyphs as decorative wallpaper.'),
dict(id='Brineworks',rooms=['cellar','sluice','larder'],concepts=['ENVC-05','ENVC-09'],materials=['TX17','TX08','TX11','TX05','TX15'],
    identity='East-bank Salt Cellar, Sluice and shallow Brine Larder, plus the Undercroft route beneath the canal. Salt, brine barrels and the floor chain distinguish it from the western pump.',
    hero=['I03','I04','W01','W02','W03'],support=['W08','P05','P06','P08','P09','P14','P15','D08','L01'],
    placement='Sluice control [122,12,-2.5]. Source floor-chain proxy [110,20,-2.5],24 x0.4 x0.2m: use repeated links/guides rather than one long baked mesh. Brine Larder water remains0.4m and its roof break keeps the bell visible.',
    avoid='No second mandatory curing station. No crates above the Undercroft headroom, on the chain tell, across the bars, or in the Larder-to-bell roof sightline. Storage jars must not mimic collectible monsters.',
    views=['larder-bell'],story='Closed brine stores and one empty drying rack suggest overflow from the Mill, rather than moving the run objective here.')]
assert {r['id'] for r in regions}=={i['id'] for i in layout['instances']}
assert {room for r in regions for room in r['rooms']}=={r['id'] for r in layout['rooms']}
for r in regions:
    assert set(r['hero']+r['support'])<=ids,r['id']
    r['environment_kit']=[p['id'] for p in catalog if p['id'].startswith('E') and r['id'] in p['tiles']]
    instance=next(t for t in layout['instances'] if t['id']==r['id'])
    r['source_bounds_metres']=instance['rect'];r['source_ports']=instance['ports']
    r['target_density']='Proposal: one hero cluster per authored point,2-4 support clusters per closed-wall room; leave at least one whole wall bay empty. No automatic scatter.'
(ROOT/'room_dressing.json').write_text(json.dumps(regions,indent=2)+'\n')
room_lines=['# Warrens C / dressing by tile','',
 'All11 current Level Instance tiles and all24 room records are covered. Counts and densities below are proposals. The layout snapshot in references/ is the dimensional source; pictures are shape/mood guides. No actors have been placed.','',
 '## Rules across the district','',
 '- Preserve every existing walk strip at its authored width, all ports, stair profiles, gate sweeps, ladder starts/ends, drops, crouch passages, deep-water rails and the three crossing beats. Decorative skins default to NoCollision.',
 '- Place large forms first, then material families, practical-light fixture skins, medium storage clusters and finally a few small accents. Do not scatter tiny props over navigable floors.',
 '- Source capsule:78cm diameter,150cm standing,105cm crouched,140cm crouched with backpack. The visible chef is smaller than this collision envelope. Do not size passages from a concept-sheet chef.',
 '- Keep approach/hand/trace space at controls. Proposed staging allowance is125cm around a control and one open pack-sized stand beside the vat/plate; the actual actor grip and collision must be checked later in PIE.',
 '- Navigation marks go only on an existing intended route. An opaque skin may not cover any of the ten authored views or seven source window cuts. A readable clue is never buried under artistic distress.',
 '- Amber and teal are light roles. Do not bake either into base color, make every room equally bright, or add a point light to each candle. Final fixture intensity/reach needs Unreal game-camera calibration.','']
for r in regions:
    room_lines += [f"## {r['id']}",'',r['identity'],'',f"Source rooms: {', '.join(r['rooms'])}. Concepts: {', '.join(r['concepts'])}.",'',
        f"**Materials:** {', '.join(r['materials'])}. **Hero kit:** {', '.join(r['hero'])}. **Supporting pieces:** {', '.join(r['support'])}.",'',
        '**Place:** '+r['placement'],'','**Keep clear:** '+r['avoid'],'','**Small story:** '+r['story'],'',
        '**Protected views:** '+(', '.join(r['views']) or 'All intersecting source views and local authored ports; no named view starts in this tile.')+'.','']
    room_lines += ['**Environment shell / water / structure kit:** '+', '.join(r['environment_kit'])+'. See [visual coverage](VISUAL_COVERAGE.md) for every item and district assembly.','']
room_lines += ['## Source sightlines (metres)','', '| ID | From | To | Read |','|---|---|---|---|']
for view in layout['views']:room_lines.append(f"| {view['id']} | {view['from']} | {view['to']} | {view['label']} |")
room_lines += ['','## Before/after acceptance for the eventual dressing pass','',
 'At the original player camera, compare each source view with art visible and hidden. Walk/crouch/pack each crossing, ladder, authored drop and low link. Exercise P1-P7, gate sweeps and the plate latch. Check floor chain visibility in slack/taut states and Red key pickup reach on the loft. Test dark-room legibility with the actual carried lantern. Run appropriate focused CkAuto gates after any future gameplay or map integration; this offline art package supplies no runtime acceptance.']
write('ROOM_DRESSING.md','\n'.join(room_lines))

write('MATERIAL_GUIDE.md',r'''
# Warrens C / texture and material specification

## What is supplied

19 restrained surface families, each with five maps: BaseColor, ORM, NormalGL, NormalDX, Height. There are95 surface PNGs at1024x1024. The procedural fields are UV-periodic and the outermost texels match exactly in both axes. These are code-native material resources; six separate decorative art sources were generated with the built-in image tool. No AI picture is relabeled as a measured PBR/normal map.

AT01 is a32-swatch palette (512x256), AT02 is the architecture trim and AT03 the prop trim (each1024x1024, five maps), AT04 is the glyph/navigation RGBA atlas (1024x2048). Palette and trim UV metadata are included. Individual icons are256x256 PNG and editable SVG. Four wear decals, two water normal conventions, one periodic water breakup/foam map and a flame card complete the texture inputs.

## Map contract

| Map | Data | Blender | Eventual Unreal import |
|---|---|---|---|
| BaseColor | sRGB RGB, no baked directional illumination | Image sRGB -> Base Color | sRGB on; base-color/default compression |
| ORM.R | local material cavity AO | Separate Color R, optional AO input | Linear, masks compression; do not treat as opacity |
| ORM.G | roughness | Separate Color G -> Roughness | Linear, masks compression |
| ORM.B | metallic (patina lowers metal response) | Separate Color B -> Metallic | Linear, masks compression |
| NormalGL | tangent space +Y | Non-Color -> Normal Map -> Normal | Do not import this as the default DX map |
| NormalDX | same tangent field, inverted green | unused by library | Normalmap compression, sRGB off; use this OR flip GL green, never both |
| Height |16-bit single channel, midpoint neutral | optional, not wired into displacement | Linear; optional future material input; no geometry/collision displacement |
| Alpha art | straight-alpha PNG | RGB -> Base Color, A -> Alpha | Use an appropriate masked/decal material; preserve clean alpha |

Normal maps derive from the same declared millimetre-scale height field; green convention and tiling are validated. Height decode is (value/65535-0.5)*2*relief_mm. Normal strength1 already represents a deliberately quiet surface; increase only after inspecting actual mesh scale. No roughness/normal images were invented by image generation.

## UV and scale

`materials.json` gives physical repeat width/height in metres per tile. Example:TX01 is2m x2m, hence one UV repeat per2m. Wood grain runs along texture V: rotate UVs to follow a beam. Use repeat addressing for surface maps. The tiny shared palette is sampled at the documented swatch centers using nearest/closest filtering; reserve it for flat-colored faces, or store the equivalent swatch in vertex RGB.

Trim sheets repeat ONLY along U. Select one horizontal V band inside `trim_metadata.json` bounds. The8px V inset is a gutter, not useful art space. Do not wrap V, cross a lane boundary, or shrink the entire chart onto a hero prop. AO/roughness/metal data are separate even when a trim row has a constant color. Trim Height is neutral: no fake strip-edge displacement is promised.

The six generated transparent sources are native1254x1254 PNGs and intentionally preserved unchanged. They are directly usable as Blender image inputs. For final streaming/mip atlases, bake them onto the prop's power-of-two atlas during prop production; do not claim the native non-power-of-two files have already been engine-streaming qualified. Keep padding around alpha islands. Exact gameplay glyphs come from the vector/256px files, not painted emblems.

## Base-color ownership and the project materials

This package does not replace the current CkUsf/ProtoGrid masters or physical-material routing. Offline Blender materials demonstrate the maps. A later approved Unreal art pass must adapt them to the project's surface setup while preserving collision, physical materials and entity presentation ownership.

Choose one base-color owner per mesh: vertex RGB/palette OR the colored BaseColor image. Do not multiply two fully colored albedos together. For painted meshes using the project's RGB-albedo/A-cavity convention, preserve those channels; confirm each architecture material's actual vertex contract before assigning masks. ORM.R is material microcavity and is not a bake of an individual prop's scene shadows. The library deliberately does not multiply AO into the base color.

## Shader recipes

- **Opaque stone/wood/bone/cloth:** BaseColor + ORM + correct normal map; opaque surface; no emission. Keep large faceted geometry and one broad bevel as the visible style.
- **Iron/brass/copper:** same graph, ORM.B controls metal response. Use broad rough highlights; no sharp realistic grunge or gleaming polished chrome. Patina stays low contrast.
- **Wet stone:** TX17 is a material candidate with lower roughness, not a new water/physics system. Wetness decals must not change traversability.
- **Palette:** one shared low-cost visual material with face UVs at swatch centers; no claim of measured draw-call performance.
- **Trim:** one surface graph with atlas maps and lane-specific UVs. A separate alpha/emissive slot is the exception, not a new material per bolt.
- **Paint/sign:** use an opaque cloth/stone backing and a thin masked overlay or approved decal path. Do not turn painted seals into interactable widgets.
- **Glass/lantern:** geometry insert separate from frame; emissive contribution and real light are independent. Never encode the lamp pool in the frame albedo.
- **Water:** four-metre periodic normals; RGBA breakup is R slow noise/G second phase/B sparse foam/A white. Two panned samples and existing depth/shore handling are an integration recipe, not a supplied Unreal shader. No world-space flow direction is encoded. The Blender water material is a static look sample.
- **Flame:** a graphic alpha card with a small proposed emissive response; it is not an animated fire simulation. FX_Dust aliases the flour breakup material as a card input; no particle system is created.

## Readability

Keep 70-80percent of a room's visible material area quiet (an art-direction proposal, not a measured current value). Use one dominant neutral, one manufactured accent and one meaningful landmark. Hand controls, keyholes and puzzle discs need clean silhouettes and no distressed symbol ambiguity. Near black is reserved for depth, soot and shadows; the environment does not require bright orange stone to look warm under a lamp.
''')

write('BLENDER_AUTHORING.md',r'''
# Warrens C / Blender authoring handoff

## Start here

Open `blender/WarrensC_MaterialLibrary.blend`. It contains packed image resources,35 unique art materials and three review scenes: neutral swatches, a warm/cool lighting study, and atlas/decal cards. Review cubes/cards are NOT production props. Asset-marked materials may be appended or used through a Blender Asset Library. Material metadata contains the catalog IDs used in every brief.

Use `prop_catalog.csv` for production tracking, `prop_catalog.json` for tools and `briefs/<ID>_<Name>.md` for a copyable modeling request. `python get_brief.py H01` prints an individual prompt; `python get_brief.py --tile Mill --priority P0` prints a focused batch. No script generates126 finished prop meshes or changes Unreal.

## Recommended first batch (24 entries)

A01,A04,A07,A08,A10,A14,A21,H01,H02,H03,H04,H07,H11,H13,H14,I02,I03,I06,I12,I19,P01,P03,P05,L01.

Build this silhouette/interaction pass first, then finish the remaining P0 skins, P1 support groups and finally P2 accents. The126 entries are a comprehensive modular catalog, not a demand to author126 unique high-detail models before the level can be dressed. Several reuse one body or existing actor.

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
''')

write('README.md',r'''
# Warrens C / dressing production pack r01

Open **PREVIEW.html** for material previews, modeling sheets, a searchable prop catalog and tile-specific dressing instructions.

-19 surface families,95 map PNGs,1024x1024 each: BaseColor/ORM/NormalGL/NormalDX/16-bit Height.
-Two five-map trim sheets, a32-color palette and a glyph/navigation alpha atlas with20 individual vector/PNG icons.
-Four wear decals, water normal/breakup maps and a graphic flame card.
-Six native transparent painted emblems/murals; twelve Blender modeling-reference sheets.
-126 prop entries:57 P0 core,56 P1 support,13 P2 optional, with dimensions/pivots/materials/collision/variants/Blender briefs.
-All11 current Level Instance tiles and24 source room records covered; all10 source view rays listed.
-A packed Blender material library,35 unique art materials and three rendered review scenes.

Start with `BLENDER_AUTHORING.md`, then the first24-entry batch and the appropriate tile in `ROOM_DRESSING.md`. Use `MATERIAL_GUIDE.md` for map channels, UV scale, trim bands, native-art caveats and eventual Unreal material integration. `SOURCE.json` records what is source-measured versus proposed. `prop_catalog.csv` is the production tracker; `briefs/` holds individual requests.

`ASSEMBLY_RECIPES.md` maps every one of the26 source dressing proxies and all seven authored puzzle locations to the reusable catalog pieces. Generate each shared asset once, then instance it. Use the current file selected in `image_jobs.json`/PREVIEW.html; original images retained beside r02 corrections are revision sources.

The current layout JSON governs dimensions/mechanism locations. The prior concept paintings govern mood and shapes. P7 is in Salt Mill; the Red key is on the accessible Belfry loft, distinct from the high landmark bell. The picture sheets are not metric CAD drawings and do not override these contracts.

Materials/maps are actual local assets. The surface/FX/vector resources are deterministic code-native outputs; painted emblems/modeling images use built-in image generation. Painted sources remain native1254px transparent art for Blender, with power-of-two prop-atlas baking left to prop production. No external image API runner was used.

This is a Blender-ready art handoff. It has not been imported into Unreal or accepted in PIE. The live level, gameplay, plugin configuration and existing cookbook library are unchanged. No commit or push is part of this request.

Look controls live in `materials.json` (base_srgb_hex, roughness, metallic, tile_metres, relief_mm) and `palette.json`. Procedural rebuilding requires NumPy/Pillow; the supplied `.blend` can be opened independently without installing them. `prepare.py` is initialization-only and refuses to overwrite an existing pack. Generated art is preserved; use its prompt/revision records rather than re-running preparation.
''')

write('get_brief.py',r'''
"""Print one Blender request, or a batch filtered by tile/priority. Never runs Blender or edits the map."""
import argparse,json
from pathlib import Path
r=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('id',nargs='?');p.add_argument('--tile');p.add_argument('--priority',choices=['P0','P1','P2']);a=p.parse_args()
items=json.loads((r/'prop_catalog.json').read_text())
items=[i for i in items if (not a.id or i['id']==a.id) and (not a.tile or a.tile in i['tiles']) and (not a.priority or i['priority']==a.priority)]
if not items:raise SystemExit('No matching prop entries')
print('Material library: blender/WarrensC_MaterialLibrary.blend\nRead BLENDER_AUTHORING.md before generating.\n')
for item in items:print(item['id']+' / '+item['name']+'\n'+item['blender_generation_brief']+'\n')
''')

# Vector overview: actual source footprints, tile bounds and ten view rays. It is not a new layout proposal.
def point(p):return f'{p[0]:.3f},{-p[1]:.3f}'
svg=['<svg xmlns="http://www.w3.org/2000/svg" viewBox="-34 -132 190 142" style="background:#20271f">',
     '<style>text{font:2px sans-serif;fill:#eddfbb}.room{fill:#7d8571;fill-opacity:.25;stroke:#9aa17d;stroke-width:.25}.tile{fill:none;stroke:#baa977;stroke-width:.25;stroke-dasharray:1 1}.view{stroke:#e3b563;stroke-width:.15;opacity:.6}</style>']
for tile in layout['instances']:
    x0,y0,x1,y1=tile['rect'];svg.append(f'<rect class="tile" x="{x0}" y="{-y1}" width="{x1-x0}" height="{y1-y0}"/><text x="{x0+1}" y="{-y1+3}">{html.escape(tile["id"])}</text>')
for room in layout['rooms']:
    if 'rect' in room:
        x0,y0,x1,y1=room['rect'];poly=[[x0,y0],[x1,y0],[x1,y1],[x0,y1]]
    else:poly=room['poly']
    svg.append('<polygon class="room" points="'+' '.join(point(p) for p in poly)+'"/>')
    if room.get('label'):
        x=sum(p[0] for p in poly)/len(poly);y=sum(p[1] for p in poly)/len(poly)
        svg.append(f'<text x="{x}" y="{-y}" text-anchor="middle">{html.escape(room["label"])} z{room["z"]}</text>')
for view in layout['views']:
    a,b=view['from'],view['to'];svg.append(f'<line class="view" x1="{a[0]}" y1="{-a[1]}" x2="{b[0]}" y2="{-b[1]}"/>')
svg+=['<text x="-30" y="6">Source footprints and protected view rays; stacked floors overlap. Dimensions in metres. No new connections.</text>','</svg>']
write('SOURCE_FOOTPRINTS.svg',''.join(svg))
print(json.dumps({'tiles':len(regions),'covered_rooms':len({x for r in regions for x in r['rooms']}),'guides_written':True}))
