"""Blender-ready modeling inventory; all placement quantities are proposals, not actor counts."""
from pathlib import Path
import csv,json,re
ROOT=Path(__file__).resolve().parent
DATA=r'''
A01|AshlarWall200|architecture|0|200,35,300|TX01|all|3|broad two-course bevels; skin retained walls; no new collision
A02|AshlarWall100|architecture|0|100,35,300|TX01|all|2|half-width filler using same block cadence as A01
A03|AshlarWall050|architecture|1|50,35,300|TX01|all|2|end filler; do not stretch a 2m texture into a different stone scale
A04|CornerPier|architecture|0|80,80,300|TX01,TX10|all|2|stackable square pier; metal accents optional
A05|PierBase|architecture|0|110,110,35|TX01|all|2|base perimeter outside retained path
A06|PierCapital|architecture|0|110,110,45|TX01|all|2|broad stepped capital; no fine carved ornament
A07|ArchSurround300|architecture|0|380,45,420|TX01|Hub,Court,Ossuary,Reliquary,Belfry|2|3m CLEAR opening is a proposed skin template; fit authored doorway collision
A08|ArchSurround250|architecture|0|330,45,380|TX01|Catacomb,Brineworks,Waterworks-W,Pit|2|2.5m CLEAR opening template; frame never narrows existing gate or crawl
A09|ArchKeystone|architecture|1|70,60,80|TX01|all|3|separate accent for a real arch; no fake door outline
A10|ParapetCap200|architecture|0|200,50,25|TX01|Hub,Canal,Belfry,Reliquary|3|retains protective railing silhouette; no traversable extensions
A11|BoneArchRib|architecture|0|200,45,120|TX06|Canal|3|sectional fossil rib overlay along existing Bone Bridge; not a new bridge mesh
A12|BoneBridgePost|architecture|0|50,50,110|TX06|Canal|2|broad safe post; collision remains greybox railing
A13|BoneCoping200|architecture|0|200,35,35|TX06|Canal|2|match post socket; keep inner edge outside bridge clear width
A14|FloorSkin200|architecture|0|200,200,4|TX02|all|4|visual-only floor overlay; no change to walk height or step collision
A15|FloorSkin100|architecture|1|100,100,4|TX02|all|3|filler matching A14 texel density
A16|CeilingSkin200|architecture|1|200,200,20|TX01,TX03|Hub,Ossuary,Catacomb,Brineworks|3|ceiling skin must not reduce existing headroom
A17|StairFascia|architecture|1|200,20,45|TX01|all|2|decorate riser face only; never replace authored stair height
A18|LandingEdge200|architecture|0|200,35,15|TX01|all|3|side-edge skin; keep collision and visible drop endpoints aligned
A19|ThresholdCover|architecture|1|250,50,3|TX09|all|2|thin non-colliding cover below/flush with retained threshold
A20|BurialNicheFrame|architecture|1|160,25,180|TX01,TX06|Ossuary,Reliquary,Catacomb|3|closed decorative niche backing unless source actually opens here
A21|CaveRockLarge|architecture|0|300,200,300|TX04|Pit,Court,Catacomb,Canal|4|8-12 broad planar faces; fit shell without blocking views
A22|CaveRockMedium|architecture|1|150,100,150|TX04|all|4|silhouette variation; no small traversable stepping ledges
A23|CrackCoverStrip|architecture|1|200,25,60|TX04|all|3|hide tile shell joins while leaving explicit window cuts open
A24|WindowSurround|architecture|0|220,30,200|TX01|Hub,Canal,Belfry,Brineworks|3|frame authored sight windows; no opaque center bars across clues
H01|WellHoistFrame|landmark|0|160,160,750|TX08,TX09|Hub|1|whole frame fits source proxy; separate drum hook cage and ropes
H02|HoistPulley|landmark|0|90,30,90|TX08,TX09|Hub|2|rotation about local Y; circular silhouette with 8-12 sides
H03|HoistDrum|landmark|0|100,70,100|TX08,TX09|Hub|1|axle and rope slot visible; cosmetic unless existing hoist control owns it
H04|HoistHook|landmark|0|45,20,80|TX09|Hub|2|tip rounded enough for chunky style; no new physical hanging interaction
H05|HoistCage|landmark|1|140,140,180|TX08,TX09|Hub|1|empty cage visual candidate; do not imply a new usable elevator
H06|BellTowerCrownModule|landmark|0|400,400,400|TX01,TX10|Belfry|2|skin existing 22m landmark envelope with repeated modules; not 22m of unique mesh
H07|HighLandmarkBell|landmark|0|240,240,280|TX10|Belfry|1|proposed bell size inside tower aperture at source light height +16m
H08|BellYoke|landmark|0|300,100,80|TX08,TX09|Belfry|1|swing pivot at axle center; bell mesh remains separate
H09|BellClapper|landmark|0|30,30,180|TX09|Belfry|1|top pivot; no new bell simulation supplied
H10|BoneBridgeKeystone|landmark|1|150,70,100|TX06|Canal|2|one simple skull-like abstract block; no realistic teeth field
H11|MillstoneDrum|landmark|0|250,250,200|TX01,TX08|Mill|1|separate central axle and broad octagonal grinding faces
H12|SaltChute|landmark|0|200,80,120|TX08,TX05|Mill|2|blanketed coarse salt insert; do not create a climbable ramp to a new route
H13|PumpTower|landmark|0|200,200,600|TX09,TX11|Waterworks-W|1|source west-bank audio landmark; piston and wheel separate
H14|SplitMourner|landmark|0|200,120,450|TX01,TX06|Court|1|source Court silhouette; split robe planes and downturned faceless head
H15|Sarcophagus|landmark|1|300,150,120|TX01,TX10|Reliquary,Catacomb|2|same body with separate lid; one source open tomb in Catacomb
W01|HeavyChainLink|waterworks|0|30,18,8|TX09|Brineworks,Canal,Waterworks-W|2|8-sided chunky links; instance one link for near chain; use ribbon/low LOD at distance
W02|FloorChainGuide200|waterworks|0|200,35,20|TX09|Brineworks|2|covers/frames existing P2 tell; do not obscure the chain under crates
W03|ChainDrum|waterworks|0|80,60,80|TX09,TX08|Canal,Brineworks|1|axle-center pivot; separate from static gate frame
W04|PipeStraight200|waterworks|1|200,40,40|TX11,TX09|Waterworks-W,Brineworks|3|8-sided pipe; socket centers at both ends
W05|PipeElbow90|waterworks|1|80,80,40|TX11,TX09|Waterworks-W,Brineworks|2|same diameter as W04; no end caps in socket openings
W06|PipeCollar|waterworks|1|50,18,50|TX09|Waterworks-W,Brineworks|2|shared bolt clusters; baked/single mesh at small sizes
W07|FloorDrain|waterworks|1|80,80,5|TX09|Waterworks-W,Brineworks|2|flush visual grate; no pit collision or traversable opening
W08|BrineGutter200|waterworks|1|200,60,25|TX01,TX17|Brineworks,Mill|2|placed along walls; not a new directional puzzle channel
W09|WallSpout|waterworks|1|50,70,60|TX11|Waterworks-W,Brineworks|2|optional water FX socket at mouth; no mandatory water simulation
W10|CisternRimBlock|waterworks|0|200,60,60|TX17|Waterworks-W|3|skin existing basin boundaries; do not introduce climb-outs across deep water
W11|VatLiquidInsert|waterworks|0|210,130,3|TX15|Mill,Brineworks|2|recess below vessel lip; optional shader insert not an opaque traversable platform
W12|CanalEdgeFoamCard|waterworks|2|200,60,1|FX_Water|Canal,Brineworks,Waterworks-W|3|alpha/masked art at existing shore only; no collision
I01|KeyLoftPlinth|interaction|0|80,80,30|TX01,TX10|Belfry|1|accessible +2.5m loft; retain source key pickup location
I02|BellkeeperPanelHousing|interaction|0|100,40,140|TX09,TX10|Belfry|1|visual housing only; source entity owns dials phrase controls and rewards
I03|SluiceHandwheelPedestal|interaction|0|100,100,160|TX08,TX09|Brineworks|1|same source handwheel actor; keep grip rotation and reach point
I04|WheelAxle|interaction|0|20,80,20|TX09|Brineworks|1|local Y rotation; axle center pivot and end sockets
I05|ChainCrossingBarsSkin|interaction|0|250,30,250|TX09|Canal|1|skin existing P2 latched bars; span 250cm sourced, height proposed
I06|PackPlateHousing|interaction|0|200,200,30|TX01,TX10|Ossuary|1|same source pressure plate; wide clear center; P3 LATCHES after pack press
I07|GlyphFaceInsert|interaction|0|40,2,40|AT04|Belfry|6|six exact glyph variants; no decorative pseudo glyphs beside controls
I08|DialBlank|interaction|0|20,8,20|TX10,TX09|Belfry|1|center pivot; one blank face reused for three runtime dial placements and their authored glyphs
I09|LadderFootBarsSkin|interaction|0|100,20,170|TX09|Belfry|1|existing P5 foot bars; keep original translation and collision
I10|LoftLeverSkin|interaction|0|50,35,80|TX09,TX08|Belfry|1|pivot at hinge; existing control state and grip remain authoritative
I11|RedKeyEscutcheon|interaction|0|35,10,50|TX09|Pit|1|door lock mount for existing Red key contract; no new key type
I12|CuringVat|interaction|0|240,160,140|TX08,TX09,TX15|Mill|1|P7 source support stop +5m; tool/hand area stays unobstructed
I13|CuringVatLid|interaction|1|240,160,15|TX08,TX09|Mill|1|separate prop with handle pivot; leave off unless current interaction needs it
I14|ExistingRedKey|interaction|0|15,5,35|TX10|Belfry|1|REUSE existing pickup actor and dimensions; listed envelope is only a visual placeholder
I15|BacksideBarLeverSkin|interaction|0|40,25,80|TX09,TX08|Hub|1|closet-side only; never put a usable-looking handle on blocked hall side
I16|ScoutLadder100Segment|interaction|0|100,15,100|TX08,TX09|Hub,Pit|1|repeat over source 5m height; use existing ladder actor and travel endpoints
I17|LoftLadder125Segment|interaction|0|100,15,125|TX08,TX09|Belfry|1|two segments over source 2.5m height; existing P5 gate and ladder logic
I18|MournerCacheGateSkin|interaction|0|250,30,250|TX09,TX01|Reliquary|1|shared Mourner seal with I06; source P3 latch, no second player hold
I19|VaultDoorSkin|interaction|0|250,30,300|TX09,TX01|Pit|1|source opening span 250cm; pivot and sweep must match existing door actor
I20|CampPackPlinth|interaction|0|120,120,30|TX01|Hub|1|source camp-door pack plinth; reuse existing shared backpack instead of modeling another
P01|TimberShelf|storage|1|200,55,220|TX08|all|3|separate planks optional; keep lower shelves out of walking strip
P02|PreparationBench|storage|1|200,70,90|TX07,TX09|Hub,Mill,Brineworks|2|broad quiet top and clear hands workspace; no fake station unless gameplay exists
P03|StorageCrateBody|storage|1|80,60,60|TX07,TX09|all|3|one body with open/closed configurations; no physics for fixed dressing
P04|StorageCrateLid|storage|1|80,60,8|TX07|all|2|separate object; hinge sockets optional
P05|BrineBarrel|storage|1|85,85,110|TX07,TX09|Brineworks,Mill,Hub|3|8-12 sides; separate cap shares the same UV lane
P06|OliveStorageJar|storage|1|45,45,60|TX15|all|3|closed jars for decor; never visually duplicate collectible Pickle Mimic jars
P07|ServingBowl|storage|1|35,35,14|TX15|Hub,Mill,Brineworks|3|thick rim and low interior count; no tiny glossy glaze detail
P08|ClothSack|storage|1|60,45,80|TX12|Mill,Brineworks,Hub|4|folds are broad geometry; tied mouth and flat stable base
P09|SaltCrystalChunk|storage|1|50,50,60|TX05|Mill,Brineworks|4|5-8 large facets; no glowy crystal or treasure read
P10|SaltHeap|storage|1|150,100,70|TX05|Mill,Brineworks|3|solid broad silhouette; no collision hump in routes
P11|BoneBundle|storage|1|120,40,50|TX06|Ossuary,Catacomb|4|graphic smooth bones; no realistic anatomical gore
P12|OssuaryUrn|storage|1|40,40,60|TX06,TX01|Ossuary,Catacomb|3|simple closed ceramic/stone vessel; shape clearly different from loot jars
P13|ReliquaryBox|storage|1|80,50,50|TX10,TX08|Reliquary|2|opaque locked-look dressing only outside the actual reward cache; avoid duplicate reward readability
P14|HerbDryingRod|storage|1|200,30,30|TX08,TX14|Mill,Brineworks|2|overhead wall area away from protected sight cones
P15|DryingRack|storage|1|200,60,220|TX08,TX14|Mill,Brineworks|2|P7 support silhouette; reserve vat approach and backpack standing space
P16|TallowPot|storage|1|45,45,35|TX15,TX18|Hub,Ossuary,Belfry|2|optional quiet lighting supply prop; no new resource system
P17|Cup|storage|2|20,20,25|TX15|Hub,Mill|3|thick handle gap; non-interactable dress only
P18|Platter|storage|2|55,40,7|TX15|Hub,Mill,Brineworks|2|shallow rounded octagon; broad rim
P19|FoldedCloth|storage|2|80,60,4|TX12|Hub,Mill|3|three simple folds; no simulation
P20|ReedBasket|storage|2|70,55,40|TX14|Hub,Mill,Brineworks|2|solid simplified weave; do not model individual reeds
P21|MortarPestle|storage|2|35,35,45|TX01|Mill|2|one quiet tabletop accent; never occupy an actual tool socket
P22|MillHopper|storage|1|180,160,140|TX08,TX09|Mill|1|octagonal funnel; separate from the source millstone
P23|SackStack|storage|1|120,90,90|TX12|Mill,Brineworks|3|merge fixed stack geometry; keep loose sack variant P08 for silhouette changes
P24|WindowShutter|storage|1|100,20,160|TX08,TX09|Hub,Belfry,Reliquary|2|never close an authored view; blind fake shutter only on closed walls
P25|RecipeNoticeBoard|storage|1|70,3,100|TX16,TX08|Hub|2|blank surface for current widget/decal; no invented required instruction text
P26|RoyalServiceBanner|storage|1|80,4,200|TX12|Hub,Court,Reliquary|2|ART01 emblem on opaque cloth; static broad folds, no cloth simulation
P27|BellBankBanner|storage|1|80,4,180|TX12|Belfry,Reliquary,Brineworks,Mill|2|ART03 is a bank identity mark, not a lock glyph
P28|WellBankBanner|storage|1|80,4,180|TX12|Hub,Ossuary,Waterworks-W,Canal|2|ART02 hoist mark distinguishes bank by silhouette as well as color
P29|MournerSealPlaque|storage|0|50,3,60|TX16,TX10|Ossuary,Reliquary|1|ART04 identifies linked P3 plate/gate without adding any glyph sequence
P30|CuringStopPlaque|storage|0|60,3,60|TX16,TX08|Mill|1|ART06 on source P7 support station only; Brine Larder signage is storage identity
L01|WallLanternSkin|lighting|0|35,25,55|TX09|all|2|reuse existing sconce/lantern presentation and authored light actor; no baked glow in albedo
L02|TableLanternSkin|lighting|1|25,25,40|TX09|Hub,Mill,Brineworks|2|fixture candidate; do not duplicate existing pickup mechanics
L03|WallSconceSkin|lighting|0|30,35,60|TX09|all|2|separate flame-card socket; attached fixture does not create a new light by itself
L04|CandleHolder|lighting|1|45,35,40|TX09,TX18|Hub,Ossuary,Reliquary,Belfry,Pit|3|reuses authored candle locations; no decorative light spam
L05|LanternWallHook|lighting|0|15,25,25|TX09|all|2|mount origin on wall; preserve existing interaction point where a real hook exists
L06|LanternGlassInsert|lighting|0|25,20,35|TX15|all|1|separate glass/emissive surface; add real light only through authored lighting setup
L07|CandleTrio|lighting|1|35,35,50|TX18|Hub,Ossuary,Reliquary,Belfry,Pit|3|simple solid wax forms with separate wicks; no animated melt
L08|EmberBrazier|lighting|1|90,90,100|TX09,TX19|Court,Hub|2|do not place a bright brazier at every junction; one focal source per scene
L09|ShaftLightFrame|lighting|1|200,50,150|TX01,TX09|Hub|1|frame source shaft light aperture; keep existing light reach for later PIE calibration
D01|RootShort|detail|1|200,80,120|TX08|Hub,Waterworks-W,Pit|4|4-6 thick angular branches; no invisible collision tendrils
D02|RootLong|detail|1|200,60,250|TX08|Hub,Waterworks-W,Pit|3|combine on source root envelopes; never imply a climbable unapproved ladder
D03|DryHerbBunch|detail|1|50,30,80|AT01|Mill,Brineworks|4|low-poly leaves/solid clusters preferred to alpha overdraw
D04|MushroomCluster|detail|1|60,60,50|AT01|Court,Catacomb,Pit|3|do not duplicate required harvestable species as non-interactable copies
D05|PebbleCluster|detail|2|80,60,10|TX04|all|4|few broad stones; no collision in movement lanes
D06|BrokenFloorTile|detail|2|80,60,20|TX01|all|3|lean against wall or sink flush; do not add traversal obstacles
D07|BoneFragment|detail|2|40,20,15|TX06|Ossuary,Catacomb|3|graphic broken ends, no sharp realistic debris
D08|SaltChunkCluster|detail|1|80,70,40|TX05|Mill,Brineworks|3|same palette as P09; merged static set
D09|ClothScrap|detail|2|50,50,2|TX12|Hub,Mill|3|flat low-poly silhouette; no cloth sim or pickup state
D10|RepairPlank|detail|1|150,25,6|TX07|all|3|wall repair only in route zones; no player-created bridge implication
D11|BoltedRepairPlate|detail|1|70,40,4|TX09|Waterworks-W,Brineworks|2|broad plate and four large bolt heads
D12|DustCardPlane|detail|2|100,100,1|FX_Dust|all|1|optional material/card carrier only; no particle system supplied
D13|WaterlineCard|detail|2|200,60,1|FX_Water|Canal,Waterworks-W,Brineworks|3|follow existing water edge; no surface that reads as a walkable plank
D14|CobwebCorner|detail|2|80,5,80|AT01|Catacomb,Ossuary|2|few thick geometry strands; never web over an interactive target
D15|RopeCoil|detail|1|60,60,20|TX14|Hub,Canal,Mill|3|broad five-turn coil; geometry may be merged for fixed dress
D16|ShelfDivider|detail|1|200,40,10|TX08|all|2|reuse P01 shelving dimensions; closes visual gaps without extra materials
'''
tiles=json.loads((ROOT/'PLACEMENT_SOURCE.json').read_text())['instances'];tile_ids=[t['id'] for t in tiles]
source=json.loads((ROOT/'PLACEMENT_SOURCE.json').read_text())
materials={m['id']:m for m in json.loads((ROOT/'materials.json').read_text())}
uv='UV0: use shared palette or one trim lane for small props; tiling surfaces at catalog tile_metres for large forms. UV1: non-overlapping lightmap UVs with padding when static-light use requires them.'
catalog=[]
source_indices={'H01':0,'H14':3,'I20':4,'I06':8,'I01':10,'I02':11,'H13':12,'I03':13,'I12':23,'H11':24}
# Resolve source rows by notes, not brittle indices (the current authored list can grow).
source_notes={'H01':'THE HOIST','H14':'split mourner','I20':'Camp Door','I06':'pack plate','I01':'key plinth','I02':'dial lock','H13':'the pump:','I03':'hand-wheel','I12':'brine vat','H11':'millstone'}
bindings={'I02':'Mars_Bellkeeper_EntityScript.as','I03':'Mars_HandWheel_EntityScript.as','I06':'Mars_PressurePlate_EntityScript.as',
          'I07':'Mars_BellkeeperGlyphs.as','I08':'Mars_Bellkeeper_EntityScript.as','I10':'Mars_Lever_EntityScript.as',
          'I11':'Mars_KeyLock_EntityScript.as','I15':'Mars_Lever_EntityScript.as','I16':'Mars_Ladder_EntityScript.as',
          'I17':'Mars_Ladder_EntityScript.as','I19':'Mars_KeyLock_EntityScript.as','L01':'Mars_LanternSconce_EntityScript.as',
          'L02':'Mars_Lantern_EntityScript.as','L03':'Mars_LanternSconce_EntityScript.as','L05':'Mars_LanternHook_Prompt.as'}
axis_pivots={'H02':'axle center; rotation local Y','H03':'axle center; rotation local Y','H08':'yoke axle center; rotation local Y',
             'H09':'top hinge center','W03':'axle center; rotation local Y','I04':'axle center; rotation local Y',
             'I08':'face center; rotation local Y','I10':'lever hinge','I15':'lever hinge','I19':'existing actor hinge, never recompute from artist view'}
extra_rows=ROOT/'extra_prop_rows.txt'
if extra_rows.exists():DATA+='\n'+extra_rows.read_text(encoding='utf-8')
for line in DATA.strip().splitlines():
    if not line.strip():continue
    ident,name,category,priority,dims,mats,regions,variants,notes=line.split('|')
    dims=[float(x) for x in dims.split(',')];mats=mats.split(',');regions=tile_ids.copy() if regions=='all' else regions.split(',')
    rank=int(priority);category_budget={'architecture':[100,700],'landmark':[700,4500],'waterworks':[150,1200],'interaction':[300,1800],'storage':[150,900],'lighting':[200,1000],'detail':[30,350]}
    if ident=='H01':category_budget['landmark']=[900,3500]
    coll='NoCollision visual dressing; retained greybox/world collision is authoritative.'
    if category=='interaction':coll='Art skin only. Keep existing actor collision, pivots, sweeps, grip frames and traces. Collision replacement requires a later gameplay/PIE pass.'
    if ident=='I14':coll='Reuse existing Red key actor/mesh and pickup collision; do not generate a replacement at the listed placeholder dimensions.'
    pivot=axis_pivots.get(ident,'bottom-center at contact plane')
    if ident.startswith('A') and ident not in ['A21','A22']:pivot='lower-left rear module grid corner; contact plane stays on authored shell'
    if ident in ['A14','A15','A19']:pivot='top-left grid corner; walking face Z=0, mesh thickness extends below the authored walk plane'
    if ident in ['I07','I11','P25','P26','P27','P28','P29','P30','L01','L03','L05','W09']:pivot='rear-center mounting surface; art faces local -Y'
    a={'id':ident,'name':name,'asset_name':f'WarrensC_{name}_Mars_SM','category':category,'priority':f'P{rank}',
       'status':'reuse_existing' if ident=='I14' else ('visual_skin_preserve_authored_contract' if category=='interaction' or ident in bindings else 'new_static_art_candidate'),
       'dimensions_cm':dict(zip(['width','depth','height'],dims)),'dimension_basis':'proposed modeling envelope; fit current source ports/collision before dressing',
       'materials':mats,'tiles':regions,'variants':int(variants),'pivot':pivot,'collision':coll,'uv':uv,
       'lod0_triangles_target_range':category_budget[category],'material_slots_target':'1 preferred, 2 maximum where metal/glass needs a separate surface',
       'lod_guidance':'LOD1 about half the triangles; distant small decor can cull. These are proposed art budgets, not measured runtime performance.',
       'sockets':(['Axis','Grip_Existing'] if category=='interaction' else ['Mount'] if pivot.startswith('rear') else []),
       'notes':notes,'placement_quantity_basis':'proposed density ranges; not an editor actor inventory',
       'proposed_quantity_per_listed_tile':[1,1] if ident in source_notes or category=='interaction' else ([4,18] if category=='architecture' else [2,6] if category in ['storage','lighting'] else [1,3]),
       'blender_generation_brief':f'Generate {name}, asset {ident}, for Mise en Monstre Warrens C. Ultra-low-poly flat shading, chunky primitive silhouette, 1-2 broad bevels, no realistic microdetail. Proposed width/depth/height {dims}cm. Blender Z up, width local X, front -Y. Pivot: {pivot}. Materials {mats}. {notes}. {coll} {uv} Keep all moving components separate. Apply object scale; do not add gameplay, lights or collision automatically. Output one named collection, meshes, optional UCX only when later approved, and a neutral front/side/three-quarter preview.'}
    if ident in source_notes:
        anchor=next((p for p in source['props'] if source_notes[ident].lower() in p.get('note','').lower()),None)
        assert anchor,(ident,source_notes[ident])
        a['source_anchor_metres']=anchor['at'];a['source_proxy_size_metres']=anchor['size']
        a['dimension_basis']='current authored source proxy envelope' if list(dims)==[x*100 for x in anchor['size']] else 'module proposed inside current authored source proxy envelope'
    if ident in bindings:a['existing_gameplay_source']='Script/WorldObjects/'+('Items/' if ident in ['L02','L05'] else 'Mechanisms/')+bindings[ident]
    if ident=='I14':
        a['asset_name']='REUSE_EXISTING_RED_KEY'
        a['blender_generation_brief']='Do not generate a new I14 mesh. Reuse the existing Red key pickup and its current size, material, collision, grip and interaction contract. The catalog dimensions are an illustrative placeholder only. Keep the source pickup on the accessible Belfry loft; do not attach it to the high bell.'
    if ident=='P11':a['notes']+='; include one reusable single-bone component for the source Belfry chimes'
    if ident=='P25':
        a['tiles']=['Hub','Belfry']
        a['notes']+='; second variant is an oversized blank P4 clue backing, not a baked phrase'
        a['variant_specs']=[{'name':'HubNotice','dimensions_cm':[70,3,100]},
            {'name':'TowerClueBacking','dimensions_cm':[400,30,200],'source_anchor_metres':[102,50,2],
             'note':'Blank geometry fitted to the current proxy envelope and face orientation; separate I07 glyphs remain runtime-authored.'}]
    if ident in ['P11','P25']:a['blender_generation_brief']+=' Additional variant requirement: '+a['notes']
    if ident=='P25':a['blender_generation_brief']+=' Variant dimensions and source context: '+json.dumps(a['variant_specs'])
    catalog.append(a)
jobs=json.loads((ROOT/'image_jobs.json').read_text())
for a in catalog:
    a['model_sheets']=[{'id':j['id'],'image':j['image']} for j in jobs if j['type']=='model-sheet' and a['id'] in j.get('catalog_ids',[])]
    a['dressing_sheets']=[{'id':j['id'],'image':j['image']} for j in jobs if j['type']=='dressing-sheet' and a['id'] in j.get('catalog_ids',[])]
ids={a['id'] for a in catalog};assert len(ids)==len(catalog)
for j in json.loads((ROOT/'image_jobs.json').read_text()):assert set(j.get('catalog_ids',[]))<=ids,(j['id'],set(j.get('catalog_ids',[]))-ids)
assert all(set(a['tiles'])<=set(tile_ids) for a in catalog)
assert all(set(a['materials'])<=set(materials)|{'AT01','AT04','FX_Water','FX_Dust'} for a in catalog)
(ROOT/'prop_catalog.json').write_text(json.dumps(catalog,indent=2)+'\n',encoding='utf-8')
fields=['id','name','asset_name','category','priority','status','dimension_basis','dimensions_cm','materials','tiles','variants','variant_specs','pivot','collision','lod0_triangles_target_range','notes','model_sheets','dressing_sheets','blender_generation_brief']
with (ROOT/'prop_catalog.csv').open('w',newline='',encoding='utf-8-sig') as f:
    writer=csv.DictWriter(f,fieldnames=fields);writer.writeheader()
    for a in catalog:writer.writerow({k:json.dumps(a.get(k,'')) if isinstance(a.get(k),(list,dict)) else a.get(k,'') for k in fields})
for a in catalog:
    refs='\n'.join(f"- [{j['id']}](../{j['image']})" for j in a['model_sheets']+a['dressing_sheets']) or 'Reuse existing asset; no new mesh requested.'
    (ROOT/'briefs'/f"{a['id']}_{a['name']}.md").write_text(f"# {a['id']} / {a['name']}\n\n{a['blender_generation_brief']}\n\nPriority: {a['priority']}\n\nDimension basis: {a['dimension_basis']}\n\nTiles: {', '.join(a['tiles'])}\n\nTriangle target: {a['lod0_triangles_target_range']} (proposal).\n\nSockets: {a['sockets']}\n\n## Visual references\n\n{refs}\n",encoding='utf-8')
print(json.dumps({'prop_entries':len(catalog),'priority_counts':{p:sum(a['priority']==p for a in catalog) for p in ['P0','P1','P2']},'source_anchored':sum('source_anchor_metres' in a for a in catalog)}))
