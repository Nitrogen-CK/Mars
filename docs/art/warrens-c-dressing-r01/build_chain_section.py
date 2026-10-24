"""Self-contained Chain Crossing / Sluice model-reference dossier. Offline only."""
from pathlib import Path
import csv,hashlib,json,math
ROOT=Path(__file__).resolve().parent
OUT=ROOT/'sections/chain-crossing-sluice'
(OUT/'art').mkdir(parents=True,exist_ok=True)
(OUT/'briefs').mkdir(exist_ok=True)
layout=json.loads((ROOT/'references/warrens_v8c-source.json').read_text())
shared={p['id']:p for p in json.loads((ROOT/'prop_catalog.json').read_text())}
# Width, depth, height in cm. These are proposed art envelopes unless stated otherwise.
DATA='''
01|CausewayDeckBay|250,200,20|A14|TX02|core|flat stone wearing skin; 2m length along crossing; top exactly on retained walking plane; thickness below it
02|CausewayEndClosure|250,100,20|A19|TX02|core|trim-to-fit end bay at the existing angled bank junction; not an extra ramp
03|DeckEdgeFascia|200,20,60|A18|TX01|core|vertical stone side strip below deck level; no inward projection into clear width
04|DeckUndersideRib|250,40,50|A07|TX01|support|broad shallow arch/rib under retained causeway; no climbable ledge or new underwater route
05|BankAbutment|300,100,300|A04|TX01|core|stone/rock interface fitted behind retained bank surface; match source actual shoreline
06|SupportPierShell|120,120,300|A04|TX01|support|non-colliding half-shell only around an existing support footprint; do not add new canal stepping stones
07|PierWaterlineCollar|140,140,40|W10|TX17|support|faceted wet collar below deck; separate so waterline height can be adjusted
08|BankCopingStrip|200,35,30|A10|TX01|core|top cap around existing bank edge; preserve existing rail height and walk strip
09|RailPost|30,30,100|A12|TX01|core|blocky plain stone post; source deep-water rail is 100cm high; position outside retained clear path
10|RailCap|40,40,15|A10|TX01|core|single reusable broad bevel cap; no lantern on every post
11|RailInfillBay|200,12,80|W01|TX09|core|straight static iron/chain visual infill over existing safety rail; not a second moving control chain
12|RailEndTerminal|40,35,100|A12|TX01|support|plain terminal post with broad iron attachment; distinguishes fixed rail from floor mechanism chain
13|RoomFloorBay|200,200,5|A14|TX02|core|broad flat flagstone face over retained cellar/sluice floor; no trip hazards
14|FloorFillerBay|100,200,5|A15|TX02|core|half-width filler using same tile scale; never shrink UVs to force-fit
15|RoomWallBay|200,35,300|A01|TX01|core|large-block wall skin with flat back and 1 broad bevel; do not change authored room boundaries
16|WallCornerPier|60,60,300|A04|TX01|core|overlap closure for existing wall corners; avoid corridor intrusion
17|ArchSurround|300,40,350|A07|TX01|core|thin surround fitted to an existing opening, not a new doorway; separated jambs and arch head
18|VaultCeilingBay|200,200,30|A16|TX01|core|faceted vault underside skin above retained headroom; unobtrusive ribs at seams
19|PlasterRepairPatch|150,3,160|A23|TX03|support|irregular broad wall inset with two chipped edges; shallow facing only
20|StairAndThresholdFascia|250,5,30|A17|TX01|support|adjustable front fascia for existing stairs at local transitions; no new stair route; top flush
21|HandwheelBody|50,5,50|I03|TX09|core|50cm diameter, 5cm thick visible rim and broad spokes; source HandWheel mesh contract; rotating part only, preserve Grip_L and Grip_R
22|WheelAxleStub|12,30,12|I04|TX09|core|30cm from mounting surface to wheel center in existing actor local +X; one continuous axis, no eccentric wheel
23|WheelMountHousing|100,100,160|I03|TX01,TX09|core|source 1x1x1.6m presentation proxy; proposed pedestal/backplate shell; final attachment must preserve actor wheel position and probe
24|ChainDrum|60,80,60|W03|TX09|core|separate grooved drum on its axle; simple chain tangent path; static until an existing mover hookup is approved
25|AxleBearingBlock|30,25,35|W06|TX09|support|single bearing body mirrored/instanced as needed; no moving collider or new interaction
26|PawlCover|45,20,40|D11|TX09|support|static closed ratchet/pawl cover; suggest a latched mechanism without a second usable handle
27|HeavyChainLink|32,20,8|W01|TX09|core|one chunky closed oval link; alternate orientation when instanced; simple bevel and broad cross-section
28|ChainCornerGuide|60,60,40|W02|TX09|core|guide wheel and bracket separated; short chain bend has no impossible link penetration
29|FloorChainGuide|200,40,20|W02|TX09|core|low protective channel skinned inside the source floor-chain envelope; keep continuous chain visible, do not create a trip obstruction
30|ChainEndAnchor|35,25,40|W01|TX09|core|eye, pin and wall plate; distinct from a usable pull handle; pin can be instanced from CCS42
31|WallFairlead|45,25,45|W02|TX09|support|broad open fairlead for wall transition; no unexplained chain disappearing through closed stone
32|OverheadChainHanger|30,35,50|L05|TX09|optional|short fixed bracket only at plausible supports; optional static hangers, not extra swing physics
33|RisingBarGateLeaf|200,12,220|I05|TX09|core|source gate opening 200x220cm; bars stay see-through; leaf moves straight +Z by source OpenOffset220cm, not a drawbridge
34|GateFramePost|20,40,240|I05|TX01,TX09|core|two static posts at source gate frame; retain existing colliders and no wider clear opening
35|GateLintel|240,40,20|I05|TX01|core|source static lintel above 220cm opening; not parented to moving leaf
36|GateGuideChannel|15,20,440|I05|TX09|core|static side guides extend for the 220cm leaf plus 220cm open travel; fit source ceiling before integration
37|GateTopHood|240,50,80|I05|TX09,TX01|support|open/slotted visual cover around upper parked leaf; keep movement envelope unobstructed; placement above frame is a proposal
38|GateStopShoe|25,30,15|I05|TX09|support|low socket/stop outside actual walk strip; no raised central threshold
39|CounterweightCase|45,40,240|I05|TX09|optional|closed static side case only if space allows; cosmetic explanation, no new physics, no promised animated counterweight
40|ExistingShortcutLeverHandle|15,20,80|I15|TX09|compatibility|skin concept for the builder existing lever path; not an additional player control next to the intended handwheel
41|LeverMountBase|40,40,50|I15|TX01,TX09|compatibility|separate static mount matching existing lever hinge and grip frame after measurement; do not infer new interaction reach
42|FastenerAndPinKit|20,20,20|D11|TX09|support|one collection: broad bolt head, short hinge pin, axle end cap, plain strap; repeat these, never model dozens of unique bolts
43|LargeBankRock|300,200,250|A21|TX04|core|broad irregular 12-30 plane form; flat buried base, no new traversable shelf
44|MediumRockWedge|160,120,130|A22|TX04|support|two asymmetric wedges to fill closed-shell seams; suppress tiny noisy facets
45|CaveWallPanel|400,100,400|E03|TX04|core|flat rear and overlapping ends; large planes with enough broad silhouette variation to hide repetition
46|CaveInsideCorner|300,300,400|E04|TX04|core|inside/outside variants; fit around retained wall corner without closing a port
47|CaveCeilingCap|400,400,100|E05|TX04|core|underside-facing cap; no hanging rock teeth into gate travel, player clearance or protected views
48|WetBankSkirt|400,120,200|E07|TX17,TX04|core|vertical wet-rock facing below bank; waterline in a separate material/card, never baked amber light
49|TallCliffFace|400,150,600|E09|TX04|support|vertical overlapping module for closed far shell only; no silhouette blocking distant landmarks
50|WallToeRubble|200,60,30|E08|TX04|support|merged 5-8 broad rocks in a narrow closed-wall strip; keep causeway and floor chain clear
51|DeepCanalSurface|400,400,1|E10|FX_Water|core|single flat repeatable plane, not a water cube; existing source canal depth is2m, gameplay-owned; do not model bed or change water level
52|FoamEdgeStrip|200,50,1|W12|FX_Water|support|thin irregular alpha carrier at bank/abutment contact; no foam ribbon spanning the crossing
53|WallWaterlineCard|200,60,1|D13|FX_Water|support|vertical wear/alpha plane following existing water surface level; distinct from a walkable ledge
54|BrineGutter|200,45,30|W08|TX17|support|open shallow U-channel along closed-wall maintenance bay; keep source path flat and clear
55|WallSpout|60,80,60|W09|TX17,TX11|support|short outlet with hollow mouth; static art, no new drain lever
56|OutletFlowRibbon|40,35,100|E12|FX_Water|optional|thin bent plane from spout to existing water only; no grand waterfall and no new water-level mechanic
57|DripRippleCard|80,80,1|E13|FX_Water|optional|flat radial alpha carrier, graphic rings and UVs only; later timing/material hookup
58|VerticalDripCard|30,1,120|E20|FX_Water|optional|thin alpha plane for sparse leak at a closed wall; optional FX carrier, not a particle system
59|FloorPuddleCard|150,100,1|D13|FX_Water|optional|flush irregular film on existing floor; no new wading volume, collision or slippery mechanic
60|LanternHousing|35,25,55|L01|TX09|core|body and door/latch silhouette in one art collection; reuse authored fixture locations and existing light rather than add spam
61|LanternGlass|25,20,35|L06|TX15|core|separate simple glass insert; avoid dense internal geometry, no glow baked into base color
62|WallLanternHook|15,25,25|L05|TX09|core|separate static wall hook; preserve existing hook interaction contract where an actual usable hook is retained
63|SconceFixture|30,35,60|L03|TX09|support|one broad dish and bracket with a flame socket; no new point light by default
64|FlameCard|25,1,50|L03|AT01|support|crossed or single alpha card carrier using provided flame input; emissive/material animation to be integrated later
65|LanternRestSet|45,40,60|L02|TX09,TX01|core|small static rest ledge/frame around source pump-rest niche; existing pickup/hook owns actual lantern interaction; not a second decorative pickup copy
66|BrineBarrel|90,90,120|P05|TX08,TX09|support|closed stave silhouette with two broad hoops; no new openable barrel mechanic
67|CrateBodyAndLid|100,80,80|P03|TX08|support|one body plus reusable lid P04; no clutter stack over the floor-chain tell
68|ClothSack|70,60,100|P08|TX12|support|low-poly tied sack with two broad folds; no collectible glow or pickup claim
69|StorageShelf|200,50,220|P01|TX08|support|closed-wall shelf only; broad boards and shallow feet; avoid extra room dividers
70|SaltChunkCluster|80,70,40|D08|TX05|support|matte chalky salt, not glowing gems; grouped off the path
71|RopeCoil|60,60,20|D15|TX14|support|five thick broad turns with no high-frequency fibers; not another interactable rope
72|RepairPlank|150,25,6|D10|TX07|support|wall repair prop; never spans the canal or repairs an authored route gap
73|BoltedRepairPlate|70,40,4|D11|TX09|support|broad iron patch with four large reusable fasteners from CCS42
74|ClothScrap|50,50,2|D09|TX12|optional|two low folds, static cloth; keep floor-chain line unobscured
75|MaintenanceBucket|50,45,55||TX09,TX08|optional|simple fixed empty bucket and thick handle; visual dressing only, not a new water-carry item
76|LongLadle|25,15,90||TX08|optional|one chunky maintenance/kitchen utensil in a closed-wall bucket; no improvised usable lever silhouette
77|ReedBasket|70,60,60|P20|TX08|optional|broad simplified woven bands; static fixed storage
78|MaintenanceNoticeBoard|70,3,100|P25|TX16,TX08|support|blank parchment backing for a later authored maintenance note; no random text or lock answer
79|SluiceIdentityPlaque|60,3,60|P30|TX16,TX09|support|new distinct wheel-and-chain silhouette on a plain plaque; do NOT reuse the curing-stop vat emblem here; no glyphs or hint sequence
80|RouteMarkerPlate|50,3,40||TX16|optional|plain reversible backing for a verified route arrow; graphic supplied separately; no invented new direction or secret passage
81|BankClothMarker|60,4,140|P27|TX12|optional|small torn cloth with plain bank-identity emblem; no lock glyph trim and no line-of-sight obstruction
82|SaltWearDecalCarrier|120,1,70|D08|TX05|optional|thin wall/floor-facing card or decal projector input; no raised collision crust in the movement lane
83|DampStreakDecalCarrier|150,1,120|D13|TX17|optional|sparse broad vertical mask; not black photographic grunge hiding geometry
84|CobwebCorner|80,5,80|D14|AT01|optional|few broad geometry strands above a closed bay only; never across gate opening or mechanism target
85|BrokenFloorTile|80,60,20|D06|TX01|optional|leaning wall prop or sunk flush fragment; no new floor obstacle
86|TimberSupportBeam|200,30,35|E22|TX08|support|straight broad beam with flat end joints; fit to existing ceiling/support envelope above retained headroom, not a new climb route
87|DiagonalTimberBrace|120,25,120|E23|TX08,TX09|support|separate diagonal brace and broad reusable strap from CCS42; never narrow the control approach or gate travel pocket
88|FloorDrainAndGrille|80,80,15|W07|TX09,TX17|support|one collection with separate plain grate and shallow recessed rim; surface flush to retained floor and no new hole or fluid simulation
'''
parts=[]
for line in DATA.strip().splitlines():
    n,name,dims,base,mats,role,note=line.split('|');ident='CCS'+n
    dims=[float(v) for v in dims.split(',')]
    model_sheet='CS27' if int(n)>=86 else f'CS{next(i for i,lohi in enumerate([(1,4),(5,8),(9,12),(13,16),(17,20),(21,24),(25,28),(29,32),(33,36),(37,39),(40,42),(43,46),(47,50),(51,53),(54,56),(57,59),(60,63),(64,65),(66,70),(71,75),(76,81),(82,85)],1) if lohi[0]<=int(n)<=lohi[1]):02}'
    basis='proposed art envelope; fit retained geometry/actor before import'
    if n=='21':basis='source mesh contract: 50cm diameter and 5cm thickness (Mars_HandWheel_EntityScript.as)'
    if n=='22':basis='source actor: 30cm mount-to-wheel distance and 12cm stub section'
    if n in ['33','34','35']:basis='source gate part dimensions; 200x220cm opening within 250cm source mouth'
    pivot='bottom-center at contact plane; front -Y and Z up in neutral Blender reference'
    if 21<=int(n)<=25:pivot='wheel/drum axle center; source Unreal axis is local +X, mesh adapter must preserve it'
    if int(n)==33:pivot='preserve existing gate moving-node origin at doorway base; straight +Z travel only'
    if int(n) in [51,52,57,59,82]:pivot='surface corner at exact retained floor/water elevation; no thickness above walk plane'
    part=dict(id=ident,name=name,dimensions_cm=dict(zip(['width','depth','height'],dims)),dimension_basis=basis,
      shared_asset=base or None,shared_reuse_note='Use shared family as shape/material starting point; section dimensions and source contract win. This is not a request to duplicate an existing mesh.' if base else 'Section-specific proposed mesh or carrier.',
      materials=mats.split(','),role=role,notes=note,pivot=pivot,model_sheet=model_sheet,
      collision='Visual skin/carrier defaults NoCollision; retain current greybox and gameplay-actor collision, traces, grip frames and movement sweeps.',
      status='compatibility skin only; design/runtime control choice unresolved' if role=='compatibility' else 'model reference candidate; not a finished mesh',
      quantity_basis='Estimate after source placement fitting; repeated bays/links are instances, not unique models.')
    part['blender_brief']=f"Generate {ident} {name} for the Chain Crossing / Sluice in Mise en Monstre. Ultra-low-poly, chunky flat-shaded primitives with at most one broad bevel and quiet matte surfaces. Envelope W/D/H {dims}cm; {basis}. Pivot: {pivot}. Materials {mats}. {note}. {part['collision']} Keep moving and static components separate. UV0 uses the shared palette/trim or tiling scale from materials.json. Apply object scale, name collection {ident}_{name}, provide front/side/three-quarter views. No collision, lights, gameplay or finished FX system automatically. Reference: art/{model_sheet}.png."
    parts.append(part)
jobs=json.loads((ROOT/'image_jobs.json').read_text())
GROUPS=[
 ('CausewayDeckAndUnderside','The crossing is a fixed stone causeway, not a suspended plank bridge. Show flat continuous deck bay, angle-trimmable end closure, side fascia BELOW walking surface, broad underside support rib. Keep four objects isolated with top/edge/underside views.'),
 ('AbutmentsPiersAndBankCoping','Show bank abutment, noncolliding half-shell support pier, separate waterline collar, plain coping strip. Include rear/contact faces and a small exploded bank joint. Do not add stepping-stone supports in open water.'),
 ('SafetyRailAssembly','Show rail post, separate broad cap, static low iron/chain infill bay, terminal. Straight neutral views and an exploded two-post assembly. Fixed rail stays outside the retained clear causeway path. No lantern on every post and no control-chain confusion.'),
 ('RoomFloorWallAndCorner','Four isolated room modules with top/front/back/edge views: broad flat floor bay, half-width filler, large-block masonry wall bay, corner pier. Preserve flat walk surface and quiet large geometry.'),
 ('ArchCeilingAndTransitionSkins','Arched surround with separate jamb/head; vault underside ceiling bay; thin broad plaster patch; thin stair-front/threshold fascia. Show rear mounting planes and unobtrusive module joins. No invented stair or doorway.'),
 ('HandwheelPedestalAndDrum','Handwheel rim and spokes as one rotating 50cm-diameter body, separate straight axle, static pedestal/backplate, separate chain drum. Front/side/exploded views. Show a small mitten hand at the rim so it reads as a modest usable handwheel, NOT a giant ship wheel. Axle passes centrally, smooth broad spokes, no new control lever. Catalog owns exact size; no measurement text.'),
 ('ChainLinkBearingsAndCornerGuide','Four isolated pieces: plain axle-bearing block, closed noninteractive pawl cover, large closed oval chain link, corner guide with separated wheel and bracket. Show alternating orientation of three links in a small inset, pin connections and central axes. No impossible penetrations or exposed fantasy clockwork.'),
 ('FloorChainRouteHardware','Floor chain guide as a low open channel, end anchor eye and pin, wall fairlead, optional overhead fixed hanger. Front/top/cross-section and a small chain-through-guide assembly. The floor chain is a readable continuous tell in a protected maintenance strip, never a large hazard lying across a walkway.'),
 ('RisingGateLeafAndFrame','Rising portcullis leaf with simple evenly spaced upright bars and two crossrails; separate left/right static post (one reusable post), static lintel and long vertical guide channel. Neutral exploded front and side views. Small paired CLOSED and OPEN diagrams: SAME fixed floor, leaf rises straight vertically, no hinged drawbridge or wheel at this gate. No solid opaque door covering sight through bars.'),
 ('GateHousingStopsAndCase','Static upper parked-leaf hood, low outside-edge gate stop shoe, optional closed side counterweight case. Show open/slotted hood and hollow backing, separate front/side. A ghosted leaf translation envelope must remain empty. Counterweight case is cosmetic only, no active gears or new levers.'),
 ('CompatibilityLeverAndFasteners','Existing shortcut lever handle with separate static mounting base, plus one reusable small fastener/pin collection. Neutral front/side/exploded views and a ghost hinge axis. Label as compatibility art, not a second control to install beside the intended Sluice handwheel. Four simple component silhouettes in fastener kit, no detailed screws.'),
 ('LocalRocksWallsAndCorners','Large bank boulder, medium asymmetric wedge, flat-backed cave wall panel, modular cave corner. Very broad low-poly faces, no fine texture. Front/side/top or back views and silhouette alternatives. No newly climbable ledges, no glowing gems.'),
 ('CavernRoofWetBanksAndRubble','Cave ceiling underside cap, vertical wet-bank skirt, tall far cliff shell panel, narrow rubble toe strip. Broad flat shading, exposed contact faces, joins and one small shoreline cutaway. Wetness is a material band, no baked light. No extra rocks forming crossings.'),
 ('CanalWaterAndEdgeCards','Three isolated carrier meshes: perfectly FLAT single water plane, irregular thin foam-edge alpha strip, vertical thin waterline-stain card. Show single-plane wireframes, UV layout rectangles and simple stylized material previews. Deep water is contextual cutaway only; DO NOT model a cube of water, basin walls or floor as any of these three assets. No shallow ford in this section.'),
 ('GutterSpoutAndSmallOutflow','Shallow U-shaped gutter with visible cross-section, short hollow wall-spout, optional thin bent outflow ribbon. Front/side/top, open pipe mouth and ribbon wireframe. One small existing-pool contact inset, not a new waterfall or water-level puzzle.'),
 ('DripsRipplesAndPuddleCarriers','Three optional FX carrier models: horizontal ripple plane, vertical drip plane, flush floor puddle plane. Show thin wireframes plus graphic alpha masks on checker panels and simple final material. Flat planes only. Do not depict finished Niagara particles, water collisions, slippery mechanics or physical wave meshes.'),
 ('LanternHousingGlassHookAndSconce','Four separate pieces: chunky lantern metal housing, faceted glass insert, broad wall hook, plain torch/sconce bracket. Neutral front/side/exploded views with a flame socket; small unlit and warm-lit thumbnail only. No dense ornate cage bars and no point-light spam.'),
 ('FlameCarrierAndLanternRest','A flame alpha-card mesh shown as wireframe and mask, plus the small wall-mounted lantern-rest/ledge assembly at the Pump-rest niche. Existing lantern pickup is a grey ghost context, not another new prop to duplicate. Neutral front/side and lit thumbnail. Do not invent new hook interaction or bake glow.'),
 ('SaltCellarStorageKit','Five simple objects isolated in a two-row grid: brine barrel, crate with separate reusable lid, tied cloth sack, shallow timber shelving, matte salt-chunk cluster. Front/side/top. Storage belongs on closed walls, never on floor-chain route or causeway; no loot glow or real crystal detail.'),
 ('MaintenanceDressAndRepairs','Five isolated objects: broad rope coil, wall repair plank, bolted iron patch plate, simple cloth scrap, chunky empty bucket with broad handle. Neutral front/side/top and one sparse repair-bay grouping. No plank over canal and no new pickup mechanics.'),
 ('UtilityToolsAndSigns','Six separated simple items: broad long ladle, reed basket, BLANK maintenance notice board, Sluice identity plaque showing ONLY a plain wheel-and-chain silhouette, BLANK route-marker backing, small bank cloth marker with a plain bell silhouette. No tiny text, no lock glyphs, no baked puzzle answer, no directional arrow until placement is verified. Keep tools distinct from usable controls.'),
    ('WearWebAndBrokenStone','Four isolated optional dressing carriers/props: salt wear mask card, broad damp-streak card, thick geometry corner web, leaning or flush broken floor tile. Wireframe and alpha-mask where appropriate, front/side for solid props. No photoreal grunge; keep sparse and readable, never hide the mechanism or chain.'),
    ('TimberSupportsAndFloorDrain','Three isolated structural/utility objects: a straight square timber support beam, a diagonal brace with broad iron strap, a recessed floor-drain body with separate simple metal grate. Large front/side/end views, exploded brace joint, drain cross-section and separated grate. No hundreds of slats; 5-7 broad grate bars only. The grate top is flush with the retained floor. One small wall/ceiling support assembly, not a new overhead route. Matte flat shading, no fine grain.'),
]
style=('Use case: stylized-concept. Blender model reference sheet for MISE EN MONSTRE / WARRENS C / CHAIN CROSSING AND SLUICE. '
 'Deliberately simple ultra-low-poly, flat-shaded chunky game shapes, broad bevels, low detail, matte limestone, muted slate rock, warm dark timber, charcoal iron, quiet brass. '
 'NO photoreal texture, fine engraving, realistic gore, dense scratches, tiny brick noise, steampunk gears or lock symbols. '
 'Landscape 3:2 neutral warm-grey production board; each isolated component gets LARGE front/side/three-quarter, underside or exploded views as appropriate. '
 'Exact labels are the CCS IDs and short names below. No numeric dimension text. Written brief owns exact scale and runtime contract. '
 'Tiny 120cm-style faceless ivory-eyed chef only as proportion context; clearance is governed by the written source capsule, not the sketch. '
 'No built map or runtime acceptance implied. ')
existing={j['id'] for j in jobs}
section_jobs=[]
for i,(title,brief) in enumerate(GROUPS,1):
    ident='CS27' if i==23 else f'CS{i:02}';items=[p for p in parts if p['model_sheet']==ident]
    prompt=style+'\nPrimary request: '+brief+'\nExact component labels: '+'; '.join(p['id']+' '+p['name'] for p in items)+'. Header: '+ident+' / '+title+'. Assemblies use at most15percent; isolated parts dominate.'
    job=dict(id=ident,type='section-sheet',section='chain-crossing-sluice',title=title,section_part_ids=[p['id'] for p in items],
      brief=brief,image=f'sections/chain-crossing-sluice/art/{ident}.png',prompt=prompt)
    section_jobs.append(job)
    if ident not in existing:jobs.append(job)
ASSEMBLIES=[
 ('CS23','WholeSectionAssembly','Large cutaway art hierarchy, not a metric map: left a local fixed stone causeway with safe plain rails and a see-through rising bar gate at the Pump-side mouth; right a separate Sluice control bay with a modest wall/pedestal handwheel, chain drum and floor-chain guide. Between the two local assemblies show a thin DIAGRAMMATIC connecting chain line, not an invented continuous room. Water is deep and below retained walk faces. Reveal bank rock skirts, floor skins, gate static/moving pieces, sparse fixtures and closed-wall maintenance storage. Keep the whole central walking surface visibly empty. No new drawbridge, dock boat, bonus ladder or second wheel. No dimension labels.'),
 ('CS24','PumpApproachClosedAndOpen','Two matched player-height views of the SAME local Pump-end approach with a carried warm lantern, deep cool shadows and the crossing beyond. Left: see-through barred leaf blocks mouth. Right: same camera, same fixed causeway, SAME bank geometry and objects, bars parked vertically above opening, leaving route clear. The causeway does NOT rotate, rise or lower. No handwheel at the Pump end. Keep rear landmarks abstract and distant, not giant new assets.'),
 ('CS25','SluiceControlBayAssembly','One local Sluice control cluster: large neutral front three-quarter cutaway, side exploded parts, small dark lantern-lit player inset. Modest handwheel on central axle, static mount, single drum, chain through low guide strip, quiet stone wall, one dim fixture and a small blank maintenance board. Keep hand and pack standing space empty. No additional control levers or giant ship wheel. Show separate static and moving pieces by spacing, not complex text.'),
 ('CS26','CellarChainTellAndMaintenanceBay','One local floor-chain tell through a Cellar maintenance bay. Large neutral top/three-quarter view, shallow side cross-section, small player lantern inset. Repeated open chain guides protect a visible heavy chain in a thin maintenance strip along a closed wall. Plain wide walk lane beside it; one sparse shelf/barrel repair grouping behind the chain, not on it. A guide/fairlead resolves a bend plausibly; no chain clipping through masonry. No arrows, new tunnel, climbable pile or second mandatory curing vat.'),
]
for ident,title,brief in ASSEMBLIES:
    job=dict(id=ident,type='section-sheet',section='chain-crossing-sluice',title=title,section_part_ids=[],brief=brief,
      image=f'sections/chain-crossing-sluice/art/{ident}.png',prompt=style+'\nAsset type: local assembly/readability concept. '+brief+' Header '+ident+' / '+title+'. Images illustrate art direction only; source layout and scripts own mechanics.')
    section_jobs.append(job)
    if ident not in existing:jobs.append(job)
for j in section_jobs:
    (ROOT/'prompts'/f"{j['id']}.txt").write_text(j['prompt']+'\n',encoding='utf-8')
(ROOT/'image_jobs.json').write_text(json.dumps(jobs,indent=2)+'\n')
for p in parts:
    j=next(j for j in jobs if j['id']==p['model_sheet'])
    p['reference_image']=(ROOT/j['image']).relative_to(OUT).as_posix()
    p['blender_brief']=p['blender_brief'].replace(f"art/{p['model_sheet']}.png",p['reference_image'])
(OUT/'model_catalog.json').write_text(json.dumps(parts,indent=2)+'\n')
with (OUT/'model_catalog.csv').open('w',encoding='utf-8-sig',newline='') as f:
    writer=csv.DictWriter(f,fieldnames=list(parts[0]));writer.writeheader()
    for p in parts:writer.writerow({k:json.dumps(v) if isinstance(v,(list,dict)) else v for k,v in p.items()})
for p in parts:
    p['blender_brief']=p['blender_brief'].replace(f"art/{p['model_sheet']}.png",p['reference_image'])
    (OUT/'briefs'/f"{p['id']}_{p['name']}.md").write_text(f"# {p['id']} / {p['name']}\n\n{p['blender_brief']}\n\n[Visual reference](../{p['reference_image']})\n\nShared family: {p['shared_asset'] or 'section-specific proposal'}. {p['shared_reuse_note']}\n",encoding='utf-8')
source={k:layout[k] for k in ['revision','shortcuts','puzzles','extraRamps','water','deepWaterRail']}
source['source_sha256']=hashlib.sha256((ROOT/'references/warrens_v8c-source.json').read_bytes()).hexdigest()
source['engine_observation']='Read-only MCP: editor world is Warrens_VariantC_Mars_MAP; nested mechanism actors were not resolved by top-level actor labels. No PIE behavior claimed.'
source['source_code_contracts']={
 'causeway':'Tools/LevelDesign/anchor_plans/design_warrens_v8c.py:143: [66,26,-2.5] to [96,24,-2.5], width2.5m',
 'gate':'Script/WorldObjects/Mechanisms/Mars_Gate_EntityScript.as:40-41: 200x220cm clear opening; static frame and vertically moving leaf',
 'gate_travel':'Script/ECS/Gate/Mars_Gate_Feature.as:27: OpenOffset[0,0,220]cm',
 'wheel':'Script/WorldObjects/Mechanisms/Mars_HandWheel_EntityScript.as:32,75: 30cm offset, 50cm diameter, 5cm thickness',
 'builder_mismatch':'build_warrens.py:2233 matches kind.startswith(sluice grate), whereas current P2 kind is the Chain Crossing latched bars; ChainCrossing is spawned through shortcuts[] at2209-2215 with a lever-owning Mars_Shortcut_EntityScript.'}
(OUT/'SOURCE_AND_CONTRACTS.json').write_text(json.dumps(source,indent=2)+'\n')
length=math.dist([66,26],[96,24])
notes=f'''# Chain Crossing and Sluice / complete model-reference kit

{len(parts)} component/model entries in {len(GROUPS)} modeling sheets, plus four assembly/readability sheets. Repeated links, boards, bolts and bays are instances of shared components. Optional entries are explicitly optional. These are concepts and Blender briefs, not finished meshes.

## Authored extent

- Fixed causeway centerline [66,26,-2.5] to [96,24,-2.5]m: {length:.3f}m long, 2.5m source width. Do not change its walk surface or turn it into a new moving bridge.
- Pump-side gate [67,26,-2.5]m; source shortcut mouth span250cm. Current gate component has 200x220cm clear opening, 20cm posts, 40cm frame depth and 220cm upward leaf travel. The art must retain those distinctions; a 250cm mouth is not a 250cm gate opening.
- Sluice design control at [122,12,-2.5]m inside the [114,8]-[130,22]m room. Salt Cellar is [96,12]-[110,26]m. Source chain proxy at [110,20,-2.5]m has24x0.4x0.2m envelope; it is an art tell, not an exact continuous routing spline.
- Source deep canal depth2m and retained deep-water rail1m. Water body owns actual water level. Never infer a walkable bed from a material preview.
- Keep Pump-rest niche[66,28]-[70,31]m and all nearby authored routes/ports. Do not invent extra stairs, stepping stones, ladders, boats or docks.

## Important integration finding

The written design calls for a Sluice handwheel. Current source builder selects its wheel branch only for a P2 kind beginning `sluice grate`; the present P2 label does not match. ChainCrossing is also spawned as a `Mars_Shortcut_EntityScript`, which owns a side lever and latched rising Bars gate. This dossier does not repair that gameplay mismatch. CCS21-39 show the intended wheel/gate art; CCS40-41 document compatibility with the existing lever path. Do not install both as competing player controls. Resolve control/channel ownership in the later gameplay integration pass and verify it in PIE.

Read-only MCP confirmed the editor currently has Variant C open. Top-level actor-label inspection did not resolve nested mechanism actors, so no runtime wheel presence, gate activation or movement is claimed.

## Build order and reuse

1. Fit floor, wall, arch, roof and bank rock skins to retained geometry. Make the empty path read before dressing it.
2. Build repeating deck bay, bank edge and rail kit; trim end closures to source angle. The approximately30m crossing needs repeated bays, not a single giant bespoke mesh. Suggested2m longitudinal bays require15 repeats plus a fitted remainder; quantities are proposals until actor fitting.
3. Skin static gate frame separately from moving leaf. Preserve the full leaf travel volume and current moving-node origin/collision.
4. Build the modest50cm wheel body, axle, mount, drum, one chain link and guide hardware. Preserve actual grip sockets, actor local +X wheel axis, probe and source/sink channel ownership during the later integration.
5. Fit flat water surface and sparse edge cards. Water is a material/carrier setup, not a solid geometry volume. Output of this dossier is not a Niagara system, fluid simulation or working sluice water-level mechanic.
6. Reuse existing fixture/lantern actors. One source dim Sluice light is authored at[122,15,0.1]m; fixture artwork does not justify adding lights to every post. Calibrate eventual intensity and reach from the actual player camera.
7. Add closed-wall storage and one maintenance story cluster; keep the chain tell, hand space, gate opening and retreat route clear. Optional FX/decals come last.

## Materials and graphic inputs

Use the parent [Blender material library](../../blender/WarrensC_MaterialLibrary.blend) and [material guide](../../MATERIAL_GUIDE.md). Stone:TX01/TX02/TX03, rock:TX04/TX17, wood:TX07/TX08, iron:TX09, muted copper:TX11, cloth:TX12, rope:TX14, glass:TX15, parchment:TX16, water:FX_Water. Shared technical maps are in ../../textures. No amber/teal light baked into albedo. Apply broad face colors and low-poly geometry before detail maps.

The Sluice plaque must use a wheel-and-chain mark. The generic P30 CuringStopPlaque is a shape/material-family reference only: do not put its vat/curing emblem at the Sluice. Use blank notice and route backing; authored text/arrows are a later verified placement task, and no random lock glyphs belong here.

## Distant context is reused

The far Well/hoist and Bell Tower can appear in player mood shots. They are shared landmarks, not new local copies. Parent MODEL02/03/23/36 cover the hoist, tower and bell. Keep their actual district positions and original sightlines; do not move them closer to match a painting.

## Modeling contract

Blender units metres, transforms applied, local Z up. Catalog dimensions are cm. Shared-family references are starting points: do not duplicate an asset merely because it occurs in more than one section. Each row states envelope, role, shared family, material IDs, pivot and copying brief. Ordinary static dress/carriers defaultNoCollision; keep existing source walk collision, actor colliders, grip frames and sweeps. Make one named collection per component; split moving/static meshes. One/two quiet material slots; use shared palette/trim/tiling UVs. Simple thumbnail views do not override the written dimensional contract.

## Later Unreal acceptance

No live map, gameplay script, imported prop or light has been changed. Future acceptance must exercise Pump-side blocked view, intended Sluice activation, latched open state and two-way return; pack crossing; gate travel/threshold; floor-chain visibility; bank rails; carried-lantern readability; existing water behavior; nearby Undercroft routes and protected distant views. Use appropriate CkAuto tests after actual integration. Concept sheets cannot establish any of those outcomes.
'''
(OUT/'README.md').write_text(notes,encoding='utf-8')
print(json.dumps({'section':str(OUT),'components':len(parts),'model_sheets':len(GROUPS),'assembly_sheets':4,'total_section_sheets':len(section_jobs)}))
