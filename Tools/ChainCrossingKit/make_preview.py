"""Rebuild a local review index directly from the produced model manifest."""
import html
import json
from pathlib import Path
HERE=Path(__file__).resolve().parent
OUT=HERE/'Output'
rows=json.loads((OUT/'asset_manifest.json').read_text())['assets']
cards=[]
for r in rows:
    e=html.escape
    cards.append(f'''<article data-search="{e(r['id']+' '+r['name']).lower()}"><a href="Output/Previews/{r['id']}.png"><img loading="lazy" src="Output/Previews/{r['id']}.png" alt="{e(r['name'])}"></a><h3>{e(r['id'])} · {e(r['name'].split('_')[2])}</h3><p>{r['triangles']} triangles · {' × '.join(str(round(n,1)) for n in r['actual_dimensions_cm'])} cm</p><p>{e(r['pivot'])} · {e(', '.join(r['material_keys']))}</p><a href="Output/{r['fbx'].replace(chr(92),'/')}">FBX</a></article>''')
body='''<!doctype html><html lang="en"><meta charset="utf-8"><title>Chain Crossing · Production Kit</title><style>
body{margin:0;background:#202420;color:#eee5cc;font:16px system-ui}main{max-width:1500px;margin:auto;padding:40px}h1{font:46px Georgia}h2{font:30px Georgia}p{line-height:1.5;color:#c0c7b7}a{color:#d5b56b}img{width:100%;display:block}nav{display:flex;gap:24px;flex-wrap:wrap;margin:20px 0}input{padding:14px;background:#30392f;color:white;border:1px solid #63715d;width:90%;max-width:600px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:16px}article{background:#2a3029;padding:14px;border:1px solid #46503e}article h3{font-size:16px}article p{font-size:13px}.warning{border-left:4px solid #cba35b;padding:12px;background:#30342a}figure{margin:25px 0}figcaption{margin-top:10px;color:#c0c7b7}</style><main>
<h1>Chain Crossing + Sluice</h1><p>Procedural model production · 88 low-poly assets · shared texture families · instanced scenes</p>
<nav><a href="Output/ChainCrossing_KitLibrary.blend">Blender asset library</a><a href="Output/ChainCrossing_Diorama.blend">Blender diorama</a><a href="README.md">Build / Unreal instructions</a><a href="Output/Reports/blender_validation.json">Blender audit</a><a href="Output/Reports/unreal_import_all.json">Unreal import audit</a></nav>
<div class="warning">Gameplay contract: preserve the existing lever-driven rising gate and collision. The current map has no Sluice handwheel spawner and places the gate above the planned deck. Stored wheel art is a noninteractive spare. No static replacement leaf is installed over the moving gate.</div>
<figure><a href="Output/Renders/DIORAMA.png"><img src="Output/Renders/DIORAMA.png" alt="Instanced Blender diorama"></a><figcaption>Standalone assembly study. Live placement is fitted independently to saved level geometry.</figcaption></figure>
<h2>Unreal review scenes</h2><div class="grid"><figure><a href="Output/Renders/UE_DIORAMA.png"><img src="Output/Renders/UE_DIORAMA.png" alt="Imported Unreal diorama"></a><figcaption>Saved Unreal diorama: 259 instances of 37 shared meshes.</figcaption></figure><figure><a href="Output/Renders/UE_LIBRARY.png"><img src="Output/Renders/UE_LIBRARY.png" alt="Imported Unreal kit library"></a><figcaption>All 88 imported meshes at their actual scale. Per-model close-ups below.</figcaption></figure></div>
<h2>In Variant C</h2><p>1,216 placements across 73 HISM groups in three existing district Level Instances. Standing-height spectator views captured in PIE; walking and interaction acceptance remain separate.</p>
<div class="grid"><figure><a href="Output/Renders/PIE_SLUICE_FINAL.png"><img src="Output/Renders/PIE_SLUICE_FINAL.png" alt="Sluice room in PIE"></a><figcaption>Sluice storage and structure.</figcaption></figure><figure><a href="Output/Renders/PIE_CROSSING_FINAL.png"><img src="Output/Renders/PIE_CROSSING_FINAL.png" alt="Chain Crossing in PIE"></a><figcaption>Crossing with local lantern pools and preserved lane.</figcaption></figure></div>
<figure><a href="Output/Renders/PIE_CHAIN_DETAIL.png"><img src="Output/Renders/PIE_CHAIN_DETAIL.png" alt="Instanced chain, guides and stored tools in PIE"></a><figcaption>Instanced chain and maintenance props. The source green inlay is hidden; its collision state is retained.</figcaption></figure>
<nav><a href="Output/Reports/unreal_level_validation.json">Saved geometry audit</a><a href="Output/Reports/pie_live_identity.json">Runtime instance count</a><a href="Output/Reports/pie_final_gate.json">Final PIE gate</a></nav>
<h2>All 88 models</h2><p>Exact production dimensions, materials and pivots below. Clicking an image opens the full asset preview.</p><input id="filter" placeholder="Filter by CCS ID or model name" aria-label="Filter models"><div class="grid">'''+''.join(cards)+'''</div>
<script>document.querySelector('#filter').addEventListener('input',e=>{let q=e.target.value.toLowerCase();document.querySelectorAll('article').forEach(a=>a.hidden=!a.dataset.search.includes(q))})</script></main></html>'''
(HERE/'PREVIEW.html').write_text(body,encoding='utf-8')
print('PREVIEW_BUILT',len(cards))
