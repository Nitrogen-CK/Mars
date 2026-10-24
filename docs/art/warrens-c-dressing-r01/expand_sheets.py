"""Extend the level-wide art handoff without changing any engine assets."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parent
def read(name):return json.loads((ROOT/name).read_text(encoding='utf-8'))
jobs=read('image_jobs.json')
STYLE=('Use case: stylized-concept. Asset type: Blender modeling production reference for MISE EN MONSTRE / Warrens C. '
 'Deliberately simple low-poly game art, flat-shaded large polygon planes, chunky rounded proportions, sparse broad bevels, '
 'matte limestone, warm brown timber, ivory bone, charcoal iron, muted brass, quiet slate rock. '
 'Match a tiny faceless chef with two ivory eyes, mitt-like hands and a chunky chef hat. '
 'NOT realistic medieval prop art: no grain photographs, fine scratches, dense individual bricks, tiny filigree, photogrammetry, '
 'hyperreal water, dense triangulated noise, realistic gore, ornamental glyphs or random lock answers. '
 'Large isolated readable components on a plain warm-grey background. Neutral studio lighting. '
 'Landscape 3:2 sheet, clean spacing, clear front/side/three-quarter or exploded views. '
 'Label each asset with its exact catalog ID and a short English name; no dimension numbers, no invented measurements. '
 'Written catalog governs dimensions and mechanisms. No arrows pretending to be playable paths. ')
SHEETS=[
 ('MODEL13','MasonryClosures',['A03','A07','A09','A23'],
  'Four columns: half-metre filler wall, wide arch surround in separated left/right/top pieces, loose keystone, thin irregular seam-cover strip. Show front and side for each. Broad stone blocks, one arch assembly inset. Do not turn the seam cover into a deep ledge.'),
 ('MODEL14','FloorAndCeilingSkins',['A14','A15','A16'],
  'Three clearly separated modules: large floor tile skin with broad flagstones, smaller half-width filler, underside ceiling slab. Show top and edge views, flat rear planes and one subtle tile rotation variant. Floors have a continuous flat walking plane; bevels extend down, never a field of raised trip hazards.'),
 ('MODEL15','StairsWindowsAndThresholds',['A17','A18','A19','A24','P24'],
  'Five simple architectural components: thin stair-front fascia, landing nosing strip, flush threshold, arched window surround, timber shutter. Show profiles and hinge separation of shutter. A small assembled wall bay is reference only. No new stairs or window holes are invented.'),
 ('MODEL16','LargeRockSilhouettes',['A21','A22','E01','E02'],
  'Four big rock families: large boulder, medium boulder, tall buttress shoulder, asymmetric wedge. Each has front/side/top views plus two silhouette variants. Massive clean planar faces, 12-30 broad faces per form, subdued blue-grey brown rock, one bevel at most. Show flat buried bases and small overlaps for modular assembly. No glowing crystals, no stairs carved into boulders.'),
 ('MODEL17','CaveWallCeilingAndCorners',['E03','E04','E05','E06'],
  'A buildable cavern shell kit: straight rock wall panel with flat rear, inside/outside corner alternatives, overhead ceiling cap with its underside visible, split half-shell pillar around an existing support. Show mating edge overlaps, rear faces and a small exploded ceiling-to-wall assembly. Few very broad chunky planes, not granular rocks. Preserve a wide empty passage in the assembly; no hanging teeth into headroom.'),
 ('MODEL18','CliffsBanksAndRubble',['E07','E08','E09','D05','D06'],
  'Five pieces: vertical wet-rock bank skirt, narrow closed-wall rubble toe strip, tall cliff-face panel, low pebble cluster, broken flagstone leaning prop. Show isolated front/side and silhouette variants. Rock skirt faces down into water and has no new foothold. Cliff module overlaps vertically. Clearly distinguish architecture mass, low scatter and thin broken floor tile. No stepping stones across water.'),
 ('MODEL19','CanalGuttersAndCisternEdges',['W08','W09','W10'],
  'Three water-management modules: shallow U-shaped brine gutter with an open cross section, short faceted wall spout with a visible outlet, wedge rim block for a cistern. Show open cross-sections, top, underside and front views, end joins, and one small rim-and-spout assembly. Limestone and dark damp stone, copper outlet collar only. No decorative wheel or lever.'),
 ('MODEL20','DeepAndShallowWaterAssembly',['E10','E11','W12','D13'],
  'Technical art sheet with four labeled components and clean cutaway diagrams. E10 large perfectly flat deep-canal surface tile; E11 smaller shallow-ford flat tile; W12 narrow irregular foam alpha edge strip on a plane; D13 vertical waterline staining card against a wall. Show wireframe carrier beside final stylized material for each. Compare a dark deep canal section with a clear shallow floor-visible section, both with the same flat calm surface. Broad simplified reflections only, no waves sculpted as rocks and no glowing water. Alpha is illustrated on a small checker card. No new rocks or alternate crossing.'),
 ('MODEL21','OutletFlowAndDripImpacts',['E12','E13'],
  'Two visual FX carrier types: a short bent thin ribbon dropping from an existing spout into an existing pool, and a flat circular ripple-impact alpha card. Large neutral views show mesh topology beside final simple translucent result. Also show two ribbon silhouettes (straight and slight S) and two graphic ripple masks. Water only travels the short existing outlet drop, no grand waterfall or new vertical level route. Mark only E12 and E13; no complete animated system implied.'),
 ('MODEL22','CisternAndVatLiquids',['E14','W11','E15'],
  'Three separate components: square cistern water carrier, an oval/rounded-rectangular insert nested inside a curing vat rim, sparse thin brine-scum alpha islands. Show top and cross-section, hidden backing meshes, fill line below rim, and a small shallow basin assembly. Stylized muted green-grey clear water and off-white scum only at edges. No bubbling magic potion. The vat shell is a ghost outline, not a new mandatory station.'),
 ('MODEL23','LandmarkBellConstruction',['H07','H08','H09','E16'],
  'Focus entirely on the high landmark bell: a big elegant 10-12 sided broad brass shell with thick lip, a stout timber-and-iron pivot yoke, a separate chunky clapper, optional chipped lip variant insert. Large front, side and underside orthographic views; hollow interior clearly visible; exploded shell/yoke/clapper relationship with hinge axes. Two silhouettes of intact/chipped bell. No surface ornament or runes. No key hanging from it, no tower stairs in this sheet.'),
 ('MODEL24','ServiceBellsAndBoneChimes',['E17','E18','E19','P11'],
  'Small service bell with simple front/side/underside views; timber wall bracket and broad iron hanger shown separate; a wooden chime rail with three to five separate blunt bones tied on thick cord, plus single-bone component P11. Emphasize scale hierarchy: these are dull small set dressing, very different from the great landmark bell. No pull cords suggesting interaction, no musical symbol puzzle, no real human gore.'),
 ('MODEL25','LaddersAndBacksideGateHardware',['I15','I16','I17','I18'],
  'Four separate mechanical art skins: backside-only bar lever with visible hinge, short reusable scout ladder segment, slightly taller loft ladder segment, simple Mourner cache gate. Show ladder end joints and repeated assembly without inventing a platform. Gate frame and moving leaf separated in front/side. Lever appears only on interior/backside face. Existing actor controls pivots/collision. No extra front handle and no additional lock or answer.'),
 ('MODEL26','VaultDoorCampPlinthAndBox',['I19','I20','P13'],
  'Vault door leaf and static surround shown separated with existing-hinge concept, a low camp pack plinth with broad flat top, small closed reliquary storage box. Big front/side/three-quarter and an exploded hinge detail. Distinct silhouettes, muted iron/limestone/brass. No bonus key, no glowing interactive box, no invented lock glyphs. Closed box is fixed dressing, door skin fits existing gameplay actor.'),
 ('MODEL27','SaltAndMillStorage',['P09','P10','P22','P23'],
  'Individual simple salt crystal lump with three blunt variants, low salt heap, wooden mill hopper with open funnel and throat, merged cloth sack stack. Front/side/top for each and small workbench-side grouping. White salt is chalky and matte rather than luminous gemstones. Hopper parts fit a working mill visually but add no new controls. No tall pile blocking station access.'),
 ('MODEL28','KitchenTabletopKit',['P16','P17','P18','P19','P21'],
  'Five chunky kitchen objects clearly isolated: tallow pot with wax cap, cup with broad handle, simple serving platter, folded square cloth, mortar and separate pestle. Front/side/top or underside views, two restrained shape variants each. Oversized readable bevels, warm ceramic/cloth/wood, no intricate decoration. Materials quiet and flat shaded; no photographic food.'),
 ('MODEL29','BasketClothAndShelfParts',['P20','D09','D16'],
  'Reed basket built from broad simplified woven bands rather than hundreds of strands; flat cloth scrap with 2-3 angular folds; shelf divider board and its end profile. Separate top/front/side views and two variants. One small shelf cubby assembly inset. No soft-body cloth simulation or detailed fiber rendering.'),
 ('MODEL30','NoticeBoardsAndRoyalCloth',['P25','P26'],
  'P25 notice-board family shown as a small kitchen notice and separately a much wider distant clue backing; both boards have BLANK clear insert regions, never bake a glyph answer. P26 royal service banner on a separate rod, front/back/side broad-fold views. Large simple cloche emblem on cloth is decoration only, no diamond, cross or bars glyphs. Show opaque low-poly cloth and clear mount separation. No tiny illegible text.'),
 ('MODEL31','DistrictSignsAndStationPlaques',['P27','P28','P29','P30'],
  'Four identification props in separate columns with front/side/mount view. Bell-bank cloth banner has plain bell silhouette; well-bank banner has plain hoist silhouette; Mourner plaque has abstract split-statue silhouette; curing-stop plaque has salt-vat silhouette. No extra tiny symbols around these marks, especially no lock glyph decoration. Shapes and edge cuts distinguish signs as well as muted red/olive colors. No sequence arrows or recipe instructions.'),
 ('MODEL32','GlassWaxBrazierAndLightFrame',['L06','L07','L08','L09'],
  'Four pieces: separate faceted lantern glass insert without lantern housing, three stubby candles with separate wicks, low sturdy ember brazier with removable charcoal insert, broad architectural shaft-light aperture frame. Front/side/top or exploded views. Show unlit neutral geometry prominently and only a tiny warm-lit inset. No point-light spawning, no baked bloom on albedo, no new light through a closed ceiling.'),
 ('MODEL33','RepairAndBurialAccents',['D07','D10','D11','D14'],
  'Four low-detail pieces: blunt bone fragment, broad repair plank with 3 simple end variants, iron patch plate with four oversized bolts, triangular cobweb made from a few thick geometry strands. Front/side views with clear silhouettes and a small closed-wall repair grouping. No gore, no extremely thin subpixel web lines, no plank bridge or additional interactable bolts.'),
 ('MODEL34','AtmosphereCarrierMeshes',['D12','E20','E21'],
  'Honest technical art reference for three optional FX carrier meshes: a dust-speck alpha plane, a vertical thin drip plane, a low soft mist plane. Each shown as wireframe rectangle, simple alpha mask card, and a small final material sample. No particles, fog simulation or finished animation claimed. Very sparse shapes; never hide a ladder, clue or gameplay path behind the sample. Warm-grey board, readable labels and clear transparent checker behind masks.'),
 ('MODEL35','TimberStructureAndBreaks',['E22','E23','E24'],
  'Three structural timber modules: square straight beam, diagonal brace with oversized iron strap, broken end segment with just three broad split planes. Front/side/end and exploded brace-to-post join. Two simplified shape variants each, matte dark wood with broad value faces and no grain texture. One small support-frame assembly at edge. Not a new climbable ramp.'),
 ('MODEL36','WellHoistMechanicalBreakdown',['H01','H02','H03','H04','H05'],
  'Well hoist with isolated upright frame, pulley with visible central axle, winch drum, blunt hook and open hanging cage. Clear exploded relationships; front/side views of pulley/drum/hook are large enough to model. Thick rope routing has a plausible continuous path through pulley to drum. No new lever, rideable lift controls, walkway or gameplay route. Model cage is visual only. Very simple chunky shapes and one bevel, not detailed machinery.'),
 ('MODEL37','MillAndCuringVatBreakdown',['H11','H12','I12','I13'],
  'Four hero components: octagonal millstone drum with separate axle, salt chute with open throat, broad shallow curing vat, separate lid. Neutral top/front/side and exploded lid-to-vat views. Salt falls into equipment rather than onto a mandatory walking lane. Keep vat rim and hand access clear, broad working island. Reference only: required station belongs in Salt Mill, not Brine Larder. No added gears, tutorial walls or alternate controls.'),
 ('MODEL38','PumpAndPipeAssemblyBreakdown',['H13','W04','W05','W06','W07'],
  'A tall heavy pump body, short straight pipe, right-angle pipe elbow, flange/collar, recessed floor drain. Front/side and open pipe end views with consistent diameter, separate bolted collar and simple pipe-to-pump assembly. Use fully oxidized muted green-grey copper and dark iron, matte broad faces. Do not add a second handwheel or any movable controls. Expose pump silhouette and readable floor drain.'),
]
existing={j['id'] for j in jobs}
for ident,title,ids,brief in SHEETS:
    if ident in existing:continue
    prompt=STYLE+'\nPrimary request: '+brief+'\nExact catalog labels: '+', '.join(ids)+'. Header: '+ident+' / '+title+'. Keep each asset visibly separate. An assembly inset may use at most 15 percent of the sheet.'
    jobs.append(dict(id=ident,type='model-sheet',title=title,catalog_ids=ids,brief=brief,
                     image=f'art/model-sheets/{ident}_{title}.png',prompt=prompt))
rooms=read('room_dressing.json')
for i,room in enumerate(rooms,1):
    ident=f'DRESS{i:02}'
    if ident in existing:continue
    title=room['id']+'DressingAssembly'
    brief=room['identity']+' '+room['placement']+' Keep clear: '+room['avoid']
    prompt=(STYLE+'\nAsset type: district dressing assembly reference, not a measured map redraw. '
      'Composition: left 60 percent is a large isolated cutaway vignette with dressing separated into numbered broad layers; '
      'right top 25 percent is a player-height dark lantern-lit mood view of that same local cluster; right bottom 15 percent is a few isolated kit components. '
      'The vignette is one local prop cluster, never the entire district or invented travel route. '
      'Show foundation/large rock shell, architecture skin, hero mechanism, supporting storage and sparse accents as a buildable hierarchy. '
      'No extra random interactables, no dense floor clutter. Hero and path must read immediately. '
      'No measurements or lock answers printed. Header '+ident+' / '+room['id']+'. '
      'Neutral art views remain clear and matte; only the player inset uses deep teal shadow and warm amber lanterns. '
      'Current authored source constraints: '+brief+' '+room['story']+
      '\nUse these catalog pieces: '+', '.join(room['hero']+room['support'])+'. '
      'Preserve all existing clearances and ports; no new crossing. If canal appears it is continuous deep water except existing shallow ford; do not place random stepping stones. '
      'Any key belongs only at the accessible low loft, never the high bell. Any clue backing is blank, with runtime glyphs supplied later. '
      'Do not claim this illustration proves the map layout or runtime lighting.')
    jobs.append(dict(id=ident,type='dressing-sheet',title=title,tiles=[room['id']],
      catalog_ids=list(dict.fromkeys(room['hero']+room['support'])),brief=brief,
      image=f'art/district-sheets/{ident}_{title}.png',prompt=prompt))
(ROOT/'art/district-sheets').mkdir(exist_ok=True)
(ROOT/'image_jobs.json').write_text(json.dumps(jobs,indent=2)+'\n',encoding='utf-8')
for j in jobs:
    p=ROOT/'prompts'/f"{j['id']}.txt"
    if not p.exists():p.write_text(j['prompt']+'\n',encoding='utf-8')
print(json.dumps({'model_sheets':sum(j['type']=='model-sheet' for j in jobs),'district_sheets':sum(j['type']=='dressing-sheet' for j in jobs),'jobs':len(jobs)}))
