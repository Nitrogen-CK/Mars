"""Map every source dressing proxy and authored puzzle to reusable catalog pieces."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parent
layout=json.loads((ROOT/'references/warrens_v8c-source.json').read_text())
catalog=json.loads((ROOT/'prop_catalog.json').read_text());ids={a['id'] for a in catalog}
rows=[]
for index,prop in enumerate(layout['props']):
    kind=prop['kind'];note=prop.get('note','');n=note.lower()
    if kind=='station':
        if 'hoist' in n:assets=['H01','H02','H03','H04','H05'];rule='Whole source hoist envelope; separate all moving/optional cage components. No new elevator behavior.'
        elif 'brine vat' in n:assets=['I12','I13','W11','P14','P15'];rule='Salt Mill P7 source stop, not a second Larder objective. Preserve hands/pack approach.'
        elif 'dial lock' in n:assets=['I02','I07','I08'];rule='Blank housing and separate runtime glyph discs. No baked answer.'
        else:raise AssertionError(prop)
    elif kind=='pillar':
        if 'bell tower' in n:assets=['H06','H07','H08','H09'];rule='Assemble modular crown/pier skins within22m tower envelope; high bell near+16m. Key stays on the+2.5m loft.'
        elif 'pump' in n:assets=['H13','W04','W05','W06'];rule='Retain the west-bank audio landmark and source control presentation ownership.'
        elif 'hand-wheel' in n:assets=['I03','I04'];rule='Keep source handwheel pivot, grip, control and channel; no decorative duplicate control.'
        elif 'millstone' in n:assets=['H11','H12','P22'];rule='Octagonal mill silhouette; chute/hopper are separate supporting art.'
        else:raise AssertionError(prop)
    elif kind=='plinth':
        if 'pack plate' in n:assets=['I06','P29'];rule='P3 plate latches; no simultaneous hold. Source plate collision remains authoritative.'
        elif 'key plinth' in n:assets=['I01','I14'];rule='Reuse the existing key pickup on the reachable loft; do not generate another key.'
        else:assets=['I20'];rule='Existing camp-door pack staging point; do not generate a second backpack.'
    elif kind=='statue':assets=['H14'];rule='Source Court landmark; keep surrounding hunt floor open.'
    elif kind=='root':assets=['D01','D02'];rule='Repeat short root modules inside the full source root envelope. Do not model one14m mesh or create a climbable route.'
    elif kind=='sarcophagus':assets=['H15'];rule='Shared body and separate lid; only the Catacomb source calls for an open tomb.'
    elif kind=='candles':assets=['L04','L07'];rule='Art skins at the authored candle location; do not automatically spawn extra point lights.'
    elif kind=='chimes':assets=['P14','P11','W01'];rule='Source6m-wide bone-chime assembly: instance3 shared2m crossbars, hang single-bone P11 variants with short W01 chains. Keep within the shallow source envelope. No new SFX logic.'
    elif kind=='stack':
        if 'glyph' in n:assets=['P25','I07'];rule='Use the P25 TowerClueBacking variant sized400x30x200cm and six swappable I07 glyph resources. Face/phrase/ordering remain source/runtime-controlled; no painted answer.'
        elif 'chain' in n:assets=['W01','W02'];rule='Repeat links/guides along the24m source chain tell, not one unique long mesh. Preserve the control-to-gate read.'
        elif 'salt' in n:assets=['P09','D08'];rule='Merge a few large solid salt shapes; no glowy treasure cluster.'
        else:assets=['P01','P11'];rule='Shared shelving and merged bone bundles inside the exact source stack envelope.'
    else:raise AssertionError(prop)
    assert set(assets)<=ids
    rows.append({'source_prop_index':index,'kind':kind,'note':note,'source_anchor_metres':prop['at'],
                 'source_proxy_size_metres':prop['size'],'catalog_ids':assets,'assembly_rule':rule})
puzzles={'P1':['I01','I11','I14','I19'],'P2':['I03','I04','I05','W01','W02','W03'],
         'P3':['I06','I18','P29'],'P4':['I02','I07','I08','P25'],'P5':['I09','I10','I17'],
         'P6':['I05','I15','I16'],'P7':['I12','P14','P15','P30']}
assert set(puzzles)=={p['id'] for p in layout['puzzles']}
(ROOT/'assembly_recipes.json').write_text(json.dumps({'source_props':rows,'puzzle_art':puzzles},indent=2)+'\n')
lines=['# Source-to-art assembly recipes','',
       'Every current source prop proxy is covered below. These are replacement-ART recipes, not actor-spawn instructions or a claim of live integration. Keep existing entity/control ownership. Coordinates and sizes are authoring-plan metres; generate local-pivot meshes and resolve instance transforms only during placement.','',
       '| Source index / kind | Source note | Catalog pieces | Source anchor / envelope (m) | Assembly |',
       '|---|---|---|---|---|']
for row in rows:lines.append(f"| {row['source_prop_index']} / {row['kind']} | {row['note'] or 'shared source proxy'} | {', '.join(row['catalog_ids'])} | {row['source_anchor_metres']} / {row['source_proxy_size_metres']} | {row['assembly_rule']} |")
lines+=['','## Authored puzzle coverage','', '| Puzzle | Art pieces |','|---|---|']
for key,assets in puzzles.items():lines.append(f"| {key} | {', '.join(assets)} |")
lines+=['', 'The P6 bars may reuse the neutral bars geometry from I05; do not carry a Chain-Crossing-specific badge or channel into SC2. Shared meshes are visual reuse only. P4 retains individual glyphs and its authored phrase; the decorative emblems are never a clue source.']
(ROOT/'ASSEMBLY_RECIPES.md').write_text('\n'.join(lines)+'\n')
print(json.dumps({'source_proxies_covered':len(rows),'authored_puzzles_covered':len(puzzles)}))
