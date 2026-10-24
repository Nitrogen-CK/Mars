"""Local review catalog generated from actual production manifests and evidence."""
import csv,html,json
from pathlib import Path
HERE=Path(__file__).resolve().parent
OUT=HERE/'Output'
def main():
    e=html.escape;manifest=json.loads((OUT/'asset_manifest.json').read_text());fitted=json.loads((OUT/'fitted_instances.json').read_text())
    cards=[]
    for r in manifest['assets']:
        cards.append(f'''<article data-search="{e(r['id']+' '+r['name']).lower()}"><a href="Output/Previews/{r['id']}.png"><img loading="lazy" src="Output/Previews/{r['id']}.png" alt="{e(r['name'])}"></a><h3>{r['id']} · {e(r['name'].split('_')[2])}</h3><p>{r['triangles']} triangles · {' × '.join(str(round(n,1)) for n in r['actual_dimensions_cm'])} cm<br>{e(r['pivot'])} · {e(', '.join(r['material_keys']))}</p><a href="Output/{r['fbx'].replace(chr(92),'/')}">FBX</a></article>''')
    def fig(path,caption):return f'<figure><a href="{path}"><img loading="lazy" src="{path}" alt="{e(caption)}"></a><figcaption>{e(caption)}</figcaption></figure>'
    comparisons=''
    for v in ['PUMP','CISTERN','SLUICE','CROSSING','HUMP','COURT_LINK']:
        if not (OUT/'After'/f'{v}.png').is_file():continue
        comparisons+=f'<h3>{v.replace("_"," ").title()}</h3><div class="compare">'
        if (OUT/'Before'/f'{v}.png').is_file():comparisons+=fig(f'Output/Before/{v}.png','Before — matched PIE camera')
        comparisons+=fig(f'Output/After/{v}.png','After — actual PIE player-height spectator view')+'</div>'
    sheets=''.join(fig(f'Concepts/PC{i:02}.png',f'PC{i:02} — illustrated silhouette direction; catalog dimensions govern production') for i in range(1,6))+fig('Concepts/PC06.svg','PC06 — exact source water polygon and carrier specification')
    reuse=','.join(manifest['shared_reuse_ids'])
    cov=fitted['coverage']['tiles'];coverage=''.join(f"<tr><td>{tile}</td><td>{v['selected_floor_boxes']} / {v['source_floor_boxes']}</td><td>{v['emitted_floor_union_area_m2']:.2f} m²</td><td>{v['ramp_instances_covered']}</td><td>{v['missing_floor_samples']}</td></tr>" for tile,v in cov.items())
    status='Saved-state and runtime evidence linked below. Counts and source fitting are separate from physical-input or multiplayer acceptance.'
    gate_path=OUT/'Reports/pie_final_gate.json'
    if gate_path.is_file():
        gate=json.loads(gate_path.read_text());status=f"Final PIE: {gate['status']}, {gate['sample_count']} observed frames, monitored errors {gate['total_matches']}. "+status
    body=f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Waterworks · Pump + Cistern production kit</title><style>
    body{{margin:0;background:#172522;color:#f0eadb;font:16px/1.5 system-ui}}main{{max-width:1480px;margin:auto;padding:40px}}h1,h2{{font-family:Georgia}}h1{{font-size:44px;margin-bottom:0}}h2{{font-size:30px;margin-top:55px}}p,figcaption{{color:#bfcac1}}a{{color:#e4c47f}}nav{{display:flex;gap:20px;flex-wrap:wrap;margin:24px 0}}img{{width:100%;display:block}}figure{{margin:0 0 20px}}figcaption{{padding:10px 0}}.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(245px,1fr));gap:18px}}.compare{{display:grid;grid-template-columns:repeat(auto-fit,minmax(420px,1fr));gap:14px}}article{{background:#24352e;border:1px solid #4e6555;padding:15px}}article h3{{font-size:16px}}article p{{font-size:13px}}.note{{border-left:4px solid #d2ae65;padding:14px 20px;background:#29392f}}table{{border-collapse:collapse;width:100%}}td,th{{padding:12px;text-align:left;border-bottom:1px solid #526153}}input{{padding:14px;background:#293c34;color:#fff;border:1px solid #718574;width:90%;max-width:640px}}
    </style><main><h1>Pump + Cistern</h1><p>Full Waterworks-W · lower Cistern continuation · {len(manifest['assets'])} new models · {len(manifest['shared_reuse_ids'])} reused Chain meshes · source-fitted instancing</p>
    <nav><a href="Output/PumpCistern_KitLibrary.blend">Blender asset library</a><a href="Output/PumpCistern_Diorama.blend">Blender diorama</a><a href="README.md">Rebuild / Unreal paths</a><a href="MODEL_LIST.csv">Model inventory</a><a href="../ChainCrossingKit/PREVIEW.html">Chain kit</a></nav>
    <div class="note">Scope: all Waterworks-W source floors and ramps, plus the lower Cistern in Hub. Chain Crossing/Sluice remains a bounded section in the adjacent tiles. Upper Hub, Ford, Bone Bridge and Brine Larder are outside this pass. Source routes and collision stay authoritative; the existing enclosed Chain corridor cannot become the open canal painting through cosmetic dressing.</div>
    <h2>Actual level review</h2><p>{status}</p>{comparisons}
    <nav><a href="Output/Reports/unreal_level_validation.json">Saved geometry / collision / placement audit</a><a href="Output/Reports/runtime_instances.json">Live PIE instance audit</a><a href="Output/Reports/pie_final_gate.json">Final PIE log verdict</a><a href="Output/Reports/blender_validation.json">Fresh Blender-file audit</a><a href="Output/Reports/unreal_import_all.json">Unreal import audit</a></nav>
    <h2>Coverage</h2><table><tr><th>Source tile</th><th>Floor boxes in scope / total</th><th>Exposed floor area</th><th>Ramps</th><th>Uncovered samples</th></tr>{coverage}</table><p>Coverage measures source floor/ramp envelopes, not concept fidelity. Original rasterized banks and low tunnel envelopes are retained.</p>
    <h2>Source-fitted assemblies</h2><div class="compare">{fig('Output/Renders/DIORAMA.png','Blender cutaway — original footprint, shared collection instances; ceiling skins omitted for inspection')}{fig('Output/Renders/UNREAL_DIORAMA.png','Saved Unreal cutaway — HISM assembly')}</div>{fig('Output/Renders/KIT_LIBRARY.png','Blender library — all new and reused model entries')}
    <h2>Environment direction</h2><div class="compare">{fig('Concepts/ENV_Pump_R01.png','Pump — stylized direction and lamp-lit player view')}{fig('Concepts/ENV_Cistern_R01.png','Cistern — stylized direction and lamp-lit player view')}</div>
    <h2>Model sheets</h2><div class="compare">{sheets}</div>
    <h2>25 new model assets</h2><input id="filter" placeholder="Filter PWC ID or name" aria-label="Filter model assets"><div class="grid">{''.join(cards)}</div>
    <h2>Shared art reused</h2><p>{reuse}. These reference the existing Chain kit, with shared material and texture assets. BACKING_TX01/TX02 are hidden-seam utility cubes, not duplicate exported models.</p>
    <div class="note">The pump wheel and pipe branch are static art. The existing rising gate remains lever-driven at its current height; no new handwheel interaction was added. PIE cameras prove appearance and loaded instances. Physical-input traversal, co-op and packaged collision have not been accepted by these checks.</div></main>
    <script>document.querySelector('#filter').addEventListener('input',e=>{{let q=e.target.value.toLowerCase();document.querySelectorAll('article').forEach(a=>a.hidden=!a.dataset.search.includes(q))}})</script></html>'''
    (HERE/'PREVIEW.html').write_text(body,encoding='utf-8')
    with (HERE/'MODEL_LIST.csv').open('w',newline='',encoding='utf-8') as f:
        w=csv.writer(f);w.writerow(['ID','Model','Width_cm','Depth_cm','Height_cm','Pivot','Triangles','MaterialKeys','FBX','Reuse'])
        for r in manifest['assets']:w.writerow([r['id'],r['name'],*r['actual_dimensions_cm'],r['pivot'],r['triangles'],';'.join(r['material_keys']),'Output/'+r['fbx'],False])
        shared=json.loads((HERE.parent/'ChainCrossingKit/Output/asset_manifest.json').read_text())['assets']
        for r in shared:
            if r['id'] in manifest['shared_reuse_ids']:w.writerow([r['id'],r['name'],*r['actual_dimensions_cm'],r['pivot'],r['triangles'],';'.join(r['material_keys']),'../ChainCrossingKit/Output/'+r['fbx'],True])
    print('PUMP_REVIEW_INDEX',len(cards),len(fitted['placements']))
if __name__=='__main__':main()
