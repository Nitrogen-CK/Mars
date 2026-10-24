"""Build the C dressing specification from current authored layout; no Unreal mutations."""
from pathlib import Path
import csv, hashlib, json, shutil

ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[2]
if (ROOT/'art_progress.json').exists():raise SystemExit('Pack already initialized; use the individual builders. Existing generated art will not be overwritten.')
def save(name,data):
    (ROOT/name).write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
for name in ['textures','textures/surfaces','textures/atlases','textures/decals','textures/fx','art','art/painted','art/model-sheets','references','prompts','blender','qa','briefs']:
    (ROOT/name).mkdir(parents=True,exist_ok=True)
layout_path=REPO/'Tools/LevelDesign/anchor_plans/data/warrens_v8c.json'
layout=json.loads(layout_path.read_text(encoding='utf-8'))
shutil.copy2(layout_path,ROOT/'references/warrens_v8c-source.json')
old=REPO/'docs/art/overnight-exploration-r01'
old_plan=json.loads((old/'plan.json').read_text(encoding='utf-8'))
concepts=[j for j in old_plan['jobs'] if j['category']=='environment-C']
for job in concepts:shutil.copy2(old/job['image'],ROOT/'references'/Path(job['image']).name)
shutil.copy2(old/'contact-sheets/environment-C.jpg',ROOT/'references/C-CONCEPTS.jpg')
save('SOURCE.json',{'layout':str(layout_path.relative_to(REPO)),'sha256':hashlib.sha256(layout_path.read_bytes()).hexdigest(),
    'revision':layout['revision'],'concept_snapshot':'docs/art/overnight-exploration-r01','concept_ids':[j['id'] for j in concepts],
    'source_rule':'Current JSON owns dimensions, ports, puzzle relationships, views and tile boundaries. Concept paintings own mood and broad forms only.',
    'confirmed':{'level_instance_tiles':len(layout['instances']),'room_records':len(layout['rooms']),'protected_views':len(layout['views']),
        'capsule_cm':{'diameter':78,'standing_height':150,'crouched_height':105,'crouched_with_pack':140},
        'capsule_source':'Script/PlayerCharacter/Mars_PlayerCharacter_Assets.as:70',
        'bell_tower_height_m':22,'high_bell_z_m':16,'key_plinth_z_m':2.5,'curing_stop':'Mill / P7 at [88,106,5]',
        'glyphs':['Square','Circle','Triangle','Diamond','Cross','Bars']},
    'important_differences':['P7 curing vat belongs in Salt Mill, not a second mandatory Brine Larder station.',
        'Key remains on accessible +2.5 m loft; overhead landmark bell is at +16 m.',
        'There are 11 current instance tiles. Stale prose in notes saying nine is not the instance list.',
        'No fractured-clue quest is added to P4. Six existing glyphs stay individually swappable; phrase remains authored by gameplay.',
        'Foliage, banners and shelf dressing must not block the ten authored landmark/clue views.']})

# id, name, family, neutral sRGB base, roughness, metallic, tile U/V metres, relief millimetres
material_rows=[
('TX01','LimestoneAshlar','ashlar','#858473',.86,0,[2,2],1.2),
('TX02','BroadFlagstone','flagstone','#777a71',.88,0,[2,2],.9),
('TX03','LimePlaster','plaster','#bab59b',.92,0,[2,2],.3),
('TX04','CaveRock','rock','#616e69',.91,0,[3,3],.5),
('TX05','SaltCrust','salt','#d0ccb4',.93,0,[1,1],.6),
('TX06','BoneIvory','bone','#c9bd94',.79,0,[1,1],.2),
('TX07','OakPlank','plank','#79604a',.84,0,[2,2],.6),
('TX08','DarkTimber','timber','#504633',.85,0,[1,2],.3),
('TX09','BlackIron','iron','#696b64',.69,1,[1,1],.1),
('TX10','AgedBrass','brass','#ad9258',.62,1,[1,1],.1),
('TX11','PatinatedCopper','copper','#617e6c',.80,0,[1,1],.1),
('TX12','LinenCanvas','cloth','#b9ac87',.96,0,[1,1],.15),
('TX13','BrownLeather','leather','#6f4d35',.82,0,[1,1],.2),
('TX14','RopeFibre','rope','#9a865d',.96,0,[.5,1],.2),
('TX15','OliveCeramic','ceramic','#63714b',.42,0,[1,1],.1),
('TX16','Parchment','paper','#d8c79e',.97,0,[1,1],.05),
('TX17','DampStone','wetstone','#626e66',.43,0,[2,2],.8),
('TX18','TallowWax','wax','#d2c49a',.59,0,[.5,.5],.1),
('TX19','Soot','soot','#343b36',.98,0,[1,1],.05)]
materials=[]
for ident,name,family,color,rough,metal,tile,relief in material_rows:
    materials.append({'id':ident,'name':name,'family':family,'base_srgb_hex':color,'roughness':rough,'metallic':metal,
        'tile_metres':tile,'relief_mm':relief,'resolution':1024,'asset_stem':f'WarrensC_{name}',
        'maps':{suffix:f'textures/surfaces/{ident}_{name}_{suffix}.png' for suffix in ['BaseColor','ORM','NormalGL','NormalDX','Height']},
        'role':'Subtle shared surface variation. Geometry and face colors supply the low-poly silhouette; no baked amber/teal light.'})
save('materials.json',materials)

palette=[('StoneLight','#a5a38a'),('StoneMid','#858473'),('StoneDark','#59645f'),('Mortar','#535c55'),
('Ivory','#d6c79f'),('Bone','#c1b38d'),('Salt','#ddd8bc'),('Chalk','#ebe0bd'),
('Oak','#826247'),('DarkOak','#4e4030'),('Rope','#a58c5f'),('Leather','#705039'),
('Iron','#686e69'),('IronDark','#383f3b'),('Brass','#ad9258'),('CopperPatina','#60816f'),
('Canvas','#c4b18b'),('Paper','#decfa8'),('RoyalRed','#873c34'),('ServiceOlive','#657249'),
('BellTeal','#42645b'),('WarningOchre','#bd9251'),('Clay','#965f41'),('CeramicCream','#c4b99b'),
('HerbDark','#3f5937'),('HerbLight','#74814b'),('Truffle','#4f4635'),('Brine','#4b6d52'),
('Wax','#dbcca5'),('Soot','#303831'),('Ember','#d87939'),('EyeIvory','#f5e5ad')]
save('palette.json',[{'name':n,'srgb_hex':c,'index':i,'uv_center':[(i%8+.5)/8,1-(i//8+.5)/4]} for i,(n,c) in enumerate(palette)])

STYLE='MISE EN MONSTRE / Warrens C: ultra-low-poly flat-shaded dungeon kitchen fantasy. Broad matte colors, chunky beveled primitive construction, restrained surface detail. Neutral limestone, warm oak, bone ivory, dark iron and muted aged brass; amber/teal light only in encounter insets, never painted onto material charts. Small faceless chefs with two ivory eyes are scale cues only. No photorealism, dense engraving, realistic gore, microtexture, modern machinery, glossy high-fantasy ornament or decorative clutter on interaction surfaces.'
jobs=[]
painted=[
('ART01','RoyalClocheCrest','A flat cut-paper heraldic emblem: one squat serving cloche under a tiny three-point crown, two broad leaf sprigs below. Symmetric, bold, six large shapes, parchment ivory and muted red with charcoal outlines. No lettering. Used on removable service banners; not a puzzle glyph.'),
('ART02','WellHoistEmblem','One thick dark-olive crane hook hanging from a simple three-bar wooden hoist silhouette, enclosed by an imperfect ivory circle. Bold block-print ink marks, no small chain links or text. Navigation emblem for the west bank, not a directional arrow or interactive prompt.'),
('ART03','BellBankEmblem','One squat brass bell silhouette with a thick clapper, enclosed by a simple broken ivory arch, dark teal accent. Broad block-print ink marks, no text. Navigation emblem for the east bank, not one of the Bellkeeper lock glyphs.'),
('ART04','MournerServiceSeal','A simple split stone mourner silhouette with lowered head and two hanging cloth panels, an empty pack-shaped rectangle below. Ivory and olive stamp graphic with charcoal outline. Broad shapes only, no lettering or puzzle symbols. Same decorative seal can appear on pack-plate housing and related cache gate without changing their functions.'),
('ART05','KitchenHarvestMural','A flat isolated ragged-edge stencil mural: three tiny faceless cooks carry one giant mushroom and a covered bowl. Cute angular silhouettes, ivory paint with olive details. No realistic shading, no floor, no wall texture, no letters, no arrows and no combinational symbols. Decorative ancient kitchen story only.'),
('ART06','CuringServicePatch','A flat isolated cloth-patch graphic showing one broad brine vat, a droplet above and two herb leaves beside it. Rounded cut-paper silhouette, cream, olive and ochre, charcoal outline. No labels, no recipe order arrows and no letters. This marks the existing P7 Salt Mill support stop.')]
for ident,title,brief in painted:
    jobs.append({'id':ident,'type':'painted','title':title,'brief':brief,'image':f'art/painted/{ident}_{title}.png',
       'prompt':f'Use case: stylized-concept. Asset type: isolated transparent-background game prop decal. {STYLE}\nPrimary request: {brief}\nComposition: one single large emblem centered with generous transparent margin, orthographic flat 2D art, fills70 percent of a square canvas. It must be a usable texture PNG with genuine alpha transparency, not a board, not a 3D render, not a scene or mockup. No drop shadow, no baked light, no paper background, no border, no watermark. Exact coherent bold shapes readable when reduced.'})
boards=[
('MODEL01','SharedMasonryKit','A reusable limestone dressing kit: 2m wall face,1m filler,90-degree corner, pier, separate capital, 3m-clear arch surround and a low parapet cap. Each piece separated, neutral front and side views, one small assembled arch inset. These are thin non-colliding visual skins around retained greybox collision; no steps or extra entrances.',['A01','A02','A04','A05','A06','A08','A10']),
('MODEL02','WellHoist','A narrow7.5m tall timber hoist assembly with base footprint1.6m square: two stout uprights, crosshead, big simple pulley, rope drum, simple hook and empty detachable cargo cage. Exploded moving-parts breakdown, front/side/three-quarter views. Keep hook, drum and cage separate. Not a massive house-sized crane. A150cm grey capsule and120cm chef show scale.',['H01','H02','H03','H04','H05']),
('MODEL03','BelfryBellRig','A22m tower LANDMARK is assembled from modular masonry; show a separate large simple octagonal bell, yoke, clapper and chain hanger. Bell aperture high at16m. A separate small key plinth on the2.5m mezzanine is accessible to cooks; never hang the key from the high bell. Exploded bell pieces and an elevation diagram connecting tower, loft and two distinct heights.',['H06','H07','H08','H09','I01']),
('MODEL04','BoneBridgeDress','Chunky ivory fossil arch ribs, capped bridge posts, low broad bone-like coping and one restrained skull-shaped keystone. Separated modeling views and one assembly along a retained3m-clear existing bridge. The render skin adds no crossing or stepping-stone route. Not anatomically realistic skeletons.',['A11','A12','A13','H10']),
('MODEL05','SluiceChainKit','A compact1m square1.6m high handwheel pedestal; separate wide wooden wheel, axle, spindle and guard. Heavy low-detail chain links, a low covered chain guide, and a compact2.5m opening gate frame with separate translating bars. Exploded parts and slack/taut visual poses are reference only; preserve existing mechanism logic.',['I03','I04','I05','W01','W02','W03']),
('MODEL06','SaltMillCuringStation','One octagonal millstone/drum2.5m diameter2m high with separate axle and broad white salt chute. Beside it the P7 curing vat2.4x1.6x1.4m: wide wooden tub, brine insert, removable lid, herb rack and drying rack. Modeling front/side/three-quarter views and one small assembled Salt Mill station. The P7 station is at+5m in Salt Mill, not Brine Larder.',['H11','H12','I12','I13','P14','P15']),
('MODEL07','PumpWaterworks','West-bank pump tower2x2x6m with a simple piston housing, two broad pipe elbows, square drain, octagonal wheel and metal collars. Separate axle and piston. A dark riverbank inset shows its silhouette without blue glowing machinery. Exploded parts/front/side views, straight modular pipe sections reuse.',['H13','W04','W05','W06','W07']),
('MODEL08','PantryStorageKit','A restrained low-poly pantry kit: tall timber shelf, low workbench, open and closed crate sharing a body, broad brine barrel with removable lid, squat olive jar, ceramic bowl, cloth sack and a simple drying rack. Orthographic front/side views of separated objects, neutral studio illumination, no piles of clutter. Distinct usable mouths/handles, one material family per part.',['P01','P02','P03','P04','P05','P06','P07','P08','P15']),
('MODEL09','PracticalLightKit','A family of four simple practical fixtures: wall lantern with removable glass insert, small table lantern, wall sconce with separate flame-card slot, and a grouped three-candle holder. Dark iron frames, broad amber glass only in a small lit-state inset; neutral main views unlit. Separate hanging ring and hook, open/closed service panel poses. Reuse existing lantern gameplay; this is visual dressing.',['L01','L02','L03','L04','L05']),
('MODEL10','InteractionHousingKit','A coordinated mechanism ART-HOUSING kit: three-dial Bellkeeper panel with BLANK replaceable dial faces, six exact simple glyph inserts shown square,circle,triangle,diamond,cross,three parallel bars; pack-shaped floor plate2m square, ladder-foot gate, backside lever and red key escutcheon. Front/side parts, exploded pivots, no decorative symbols on controls. No invented lock solution.',['I02','I06','I07','I08','I09','I10','I11'])]
for ident,title,brief,assets in boards:
    jobs.append({'id':ident,'type':'model-sheet','title':title,'brief':brief,'catalog_ids':assets,'image':f'art/model-sheets/{ident}_{title}.png',
       'prompt':f'Use case: stylized-concept. Asset type: Blender modeling reference sheet. {STYLE}\nPrimary request: {brief}\nComposition: landscape3:2 professional production sheet on plain warm grey. Large isolated neutral-lit parts with front/side/three-quarter views, sparse dimensional guide strokes and a few tiny material swatches. Crisp buildable silhouettes, no dense text or ornate labels. Tiny identifier {ident} at top. Show component separations clearly; scene insets occupy at most15percent. Reference views are art direction; exact dimensions are governed by the written catalog.'})
save('image_jobs.json',jobs)
save('art_progress.json',{'completed':{},'review_notes':{}})
for j in jobs:(ROOT/'prompts'/f"{j['id']}.txt").write_text(j['prompt'],encoding='utf-8')
save('PLACEMENT_SOURCE.json',{k:layout[k] for k in ['instances','rooms','views','windows','links','ladders','shortcuts','puzzles','props','lights','water','upper']})
print(json.dumps({'root':str(ROOT),'material_families':len(materials),'image_jobs':len(jobs),'tiles':len(layout['instances'])}))
