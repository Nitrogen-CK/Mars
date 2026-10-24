"""Local asset bookkeeping and review gallery; never calls an image API."""
import argparse, datetime, hashlib, html, json, shutil, zipfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parent
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def save(path,data):path.write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
def stamp():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('action',choices=['record','review','refresh','package','status'])
    parser.add_argument('--id');parser.add_argument('--source');parser.add_argument('--note',default='')
    args=parser.parse_args()
    plan=read(ROOT/'plan.json');progress=read(ROOT/'progress.json');jobs={j['id']:j for j in plan['jobs']}
    if args.action=='record':
        job=jobs[args.id];source=Path(args.source);target=ROOT/job['image']
        assert source.is_file(),source
        assert not target.exists(),f'Already generated: {target}'
        shutil.copy2(source,target)
        with Image.open(target) as image:
            dimensions=list(image.size);assert image.width>=1024 and image.height>=768,dimensions
            image.convert('RGB').resize((480,320)).save(ROOT/'thumbs'/f'{args.id}.jpg',quality=86)
        progress['completed'][args.id]={'path':job['image'],'original':str(source),'dimensions':dimensions,
            'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'generated_utc':stamp(),'review':'pending'}
        (ROOT/'prompts').mkdir(exist_ok=True)
        (ROOT/'prompts'/f'{args.id}.txt').write_text(job.get('actual_prompt',job['prompt']),encoding='utf-8')
        save(ROOT/'progress.json',progress)
    if args.action=='review':
        assert args.id in progress['completed']
        progress['completed'][args.id]['review']='inspected'
        progress['quality_notes'][args.id]=args.note
        save(ROOT/'progress.json',progress)
    if args.action in ['refresh','package']:
        refresh(plan,progress)
    if args.action=='package':
        files=[p for p in ROOT.rglob('*') if p.is_file() and p.suffix not in ['.zip','.pyc'] and '__pycache__' not in p.parts]
        manifest={p.relative_to(ROOT).as_posix():{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
                  for p in files if p.name!='manifest.json'}
        save(ROOT/'manifest.json',manifest)
        files=[p for p in files if p.name!='manifest.json']+[ROOT/'manifest.json']
        with zipfile.ZipFile(ROOT/'Mise-en-Monstre-Overnight-Concepts-r01.zip','w',zipfile.ZIP_DEFLATED) as archive:
            for p in files:archive.write(p,p.relative_to(ROOT).as_posix())
        with zipfile.ZipFile(ROOT/'Mise-en-Monstre-Overnight-Concepts-r01.zip') as archive:
            assert archive.testzip() is None
        print('ARCHIVE_VERIFIED',len(files))
    counts={cat:sum(j['id'] in progress['completed'] for j in plan['jobs'] if j['category']==cat) for cat in sorted({j['category'] for j in plan['jobs']})}
    print(json.dumps({'completed':len(progress['completed']),'planned':plan['total'],'categories':counts}))

def refresh(plan,progress):
    cards=[]
    for j in plan['jobs']:
        if j['id'] not in progress['completed']:continue
        info=progress['completed'][j['id']]
        cards.append({k:j[k] for k in ['id','category','title','brief','notes','image']})
        cards[-1]['review']=info['review']
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',22)
    small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16)
    categories=sorted({j['category'] for j in plan['jobs']})
    for category in categories:
        completed=[j for j in cards if j['category']==category]
        if not completed:continue
        sheet=Image.new('RGB',(1500,1540),'#252a23');draw=ImageDraw.Draw(sheet)
        draw.text((22,16),f'MISE EN MONSTRE / {category.upper()} / {len(completed)} STUDIES',fill='#f4e5c5',font=font)
        for i,job in enumerate(completed):
            x=(i%3)*500+10;y=(i//3)*370+60
            thumb=Image.open(ROOT/'thumbs'/f"{job['id']}.jpg")
            sheet.paste(thumb,(x,y));draw.text((x+4,y+326),f"{job['id']}  {job['title'][:38]}",fill='#f4e5c5',font=small)
        sheet.save(ROOT/'contact-sheets'/f'{category}.jpg',quality=91)
    payload=json.dumps(cards,ensure_ascii=False).replace('</',r'<\/')
    template='''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Mise en Monstre / concept library</title><style>
:root{color-scheme:dark;--bg:#1c211c;--panel:#292f27;--ink:#f4e6c8;--muted:#c1b79d;--accent:#d9b667}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.5 system-ui}header,main{max-width:1650px;margin:auto;padding:28px}h1,h2{font-family:Georgia,serif;line-height:1.15}h1{font-size:42px;margin:8px 0}p{max-width:1000px}a{color:#e6cc89}button,input{font:inherit;border:1px solid #74795e;background:#30382c;color:var(--ink);border-radius:5px;padding:8px 13px}button{cursor:pointer}button.on{background:#dbb963;color:#25291f}nav{display:flex;flex-wrap:wrap;gap:8px;margin:18px 0}.toolbar{display:flex;gap:12px;flex-wrap:wrap;align-items:center}input{min-width:280px;flex:1}.stats{color:var(--muted)}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(340px,1fr));gap:22px}article{background:var(--panel);border:1px solid #4a5342;border-radius:8px;overflow:hidden}article img{width:100%;aspect-ratio:3/2;object-fit:contain;display:block;cursor:zoom-in;background:#eee2c9}.body{padding:16px}.body h2{font-size:23px;margin:5px 0 12px}.tag{font-size:12px;letter-spacing:.09em;text-transform:uppercase;color:#d8bd80}.actions{display:flex;gap:10px;align-items:center;margin-top:15px}.notes{color:var(--muted);font-size:14px}.fave{margin-left:auto}dialog{border:1px solid #74795e;max-width:96vw;width:1500px;background:#20261f;color:var(--ink);padding:14px}dialog::backdrop{background:rgba(0,0,0,.9)}dialog img{width:100%;max-height:80vh;object-fit:contain}.modalbar{display:flex;gap:14px;justify-content:space-between}.compare{display:grid;grid-template-columns:1fr 1fr;gap:12px}.compare img{max-height:65vh}.source{padding:18px;background:#282e24;border-left:3px solid #d5b160}.footer{padding:30px;color:var(--muted)}@media(max-width:700px){header,main{padding:15px}h1{font-size:32px}.grid{grid-template-columns:1fr}.compare{grid-template-columns:1fr}}
</style></head><body><header><div class="tag">MISE EN MONSTRE / ART EXPLORATION / R01</div><h1>Little plans for a very large feast</h1><p>108 distinct concept sheets across nine collections. Simpler cookbook graphics, B/C/D environment interpretations, Royal Daily Feast openings, full HUD directions, mechanism art, prototype monsters and four families of vermin. Ideas are proposals; live maps and gameplay are unchanged.</p><div class="source">Environments follow the <a href="references/Warrens-v8-Variants.html">attached B/C/D layouts</a>. Each environment sheet pairs a regular art concept with a dark player-height view. <a href="README.md">Scope and review notes</a> · <a href="DESIGN_INDEX.md">Readable design briefs</a> · <a href="plan.json">All prompts</a> · <a href="sources.json">Source constraints</a></div><nav id="tabs"></nav><div class="toolbar"><input id="search" placeholder="Search ideas, rooms or behaviors" aria-label="Search concepts"><button id="favorites">Shortlist only</button><button id="compare">Compare shortlist</button><button id="export">Export shortlist</button><span id="stats" class="stats"></span></div></header><main><div id="grid" class="grid"></div><div class="footer">Click an image for full resolution. Stars are saved in this browser; export the shortlist to preserve it. Generated text and diagram details are exploratory art, not approved recipes, mechanics or production UI. Every full-resolution image is saved locally.</div></main><dialog id="modal"><div class="modalbar"><button id="previous">Previous</button><strong id="modalTitle"></strong><button id="next">Next</button><button id="close">Close</button></div><div id="modalContent"></div><p id="modalNotes"></p></dialog><script>
const DATA=__DATA__;const total=108;const key='mise-en-monstre-overnight-r01-shortlist';let selected='all',onlyFavorites=false,search='',visible=[],current=0;function readStars(){try{const value=JSON.parse(localStorage.getItem(key)||'[]');return Array.isArray(value)?value:[]}catch{return []}}function saveStars(){try{localStorage.setItem(key,JSON.stringify([...stars]))}catch{}}const stars=new Set(readStars());const escape=s=>s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));const labels={'cookbook':'Cookbook','environment-B':'B · Shaft helix','environment-C':'C · Towers & canal','environment-D':'D · Two loops','intro':'Intro','hud':'HUD','mechanisms':'Mechanisms','monsters':'Monsters','vermin':'Vermin'};const modal=document.querySelector('#modal');
function draw(){visible=DATA.filter(d=>(selected==='all'||d.category===selected)&&(!onlyFavorites||stars.has(d.id))&&(`${d.id} ${d.title} ${d.notes} ${d.brief}`.toLowerCase().includes(search)));document.querySelector('#stats').textContent=`${DATA.length}/${total} generated · ${visible.length} shown · ${stars.size} shortlisted`;document.querySelector('#tabs').innerHTML=['all',...Object.keys(labels)].map(c=>`<button data-category="${c}" class="${selected===c?'on':''}">${labels[c]||'All'} (${c==='all'?DATA.length:DATA.filter(d=>d.category===c).length})</button>`).join('');document.querySelector('#grid').innerHTML=visible.map(d=>`<article><img loading="lazy" src="thumbs/${d.id}.jpg" alt="${escape(d.title)}" data-open="${d.id}"><div class="body"><div class="tag">${d.id} / ${labels[d.category]}</div><h2>${escape(d.title)}</h2><p class="notes">${escape(d.notes)}</p><details><summary>Design brief</summary><p>${escape(d.brief)}</p></details><div class="actions"><a href="${d.image}" target="_blank">Full image</a><a href="prompts/${d.id}.txt" target="_blank">Prompt</a><button class="fave ${stars.has(d.id)?'on':''}" data-star="${d.id}" aria-label="Shortlist ${d.id}">${stars.has(d.id)?'★':'☆'}</button></div></div></article>`).join('');}
function openImage(id){current=visible.findIndex(d=>d.id===id);const d=visible[current];if(!d)return;document.querySelector('#modalTitle').textContent=`${d.id} / ${d.title}`;document.querySelector('#modalContent').innerHTML=`<img src="${d.image}" alt="${escape(d.title)}">`;document.querySelector('#modalNotes').textContent=d.notes;if(!modal.open)modal.showModal();}
document.body.addEventListener('click',e=>{if(e.target.dataset.category){selected=e.target.dataset.category;draw()}if(e.target.dataset.star){const id=e.target.dataset.star;stars.has(id)?stars.delete(id):stars.add(id);saveStars();draw()}if(e.target.dataset.open)openImage(e.target.dataset.open)});document.querySelector('#search').oninput=e=>{search=e.target.value.toLowerCase();draw()};document.querySelector('#favorites').onclick=e=>{onlyFavorites=!onlyFavorites;e.target.classList.toggle('on',onlyFavorites);draw()};document.querySelector('#close').onclick=()=>modal.close();document.querySelector('#previous').onclick=()=>{if(visible.length)openImage(visible[(current-1+visible.length)%visible.length].id)};document.querySelector('#next').onclick=()=>{if(visible.length)openImage(visible[(current+1)%visible.length].id)};document.addEventListener('keydown',e=>{if(!modal.open)return;if(e.key==='ArrowLeft')document.querySelector('#previous').click();if(e.key==='ArrowRight')document.querySelector('#next').click()});document.querySelector('#compare').onclick=()=>{const chosen=DATA.filter(d=>stars.has(d.id)).slice(0,4);document.querySelector('#modalTitle').textContent='Shortlist comparison / first four';document.querySelector('#modalContent').innerHTML=`<div class="compare">${chosen.length?chosen.map(d=>`<div><h2>${d.id} / ${escape(d.title)}</h2><img src="${d.image}"></div>`).join(''):'<p>Star a few images to compare them here.</p>'}</div>`;document.querySelector('#modalNotes').textContent='Use the category filters and stars to compare a focused set.';modal.showModal()};document.querySelector('#export').onclick=()=>{const chosen=DATA.filter(d=>stars.has(d.id));const blob=new Blob([JSON.stringify(chosen.map(d=>({id:d.id,title:d.title,category:d.category})),null,2)],{type:'application/json'});const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='Mise-en-Monstre-shortlist.json';a.click();URL.revokeObjectURL(a.href)};draw();
</script></body></html>'''
    (ROOT/'PREVIEW.html').write_text(template.replace('__DATA__',payload),encoding='utf-8')
    counts={cat:sum(c['category']==cat for c in cards) for cat in categories}
    (ROOT/'README.md').write_text('# Mise en Monstre / overnight concept library\n\n'
        f"Generated {len(cards)}/108 distinct full-resolution concept sheets.\n\n"
        +'\n'.join(f'- {cat}: {count}/12' for cat,count in counts.items())
        +'\n\nOpen PREVIEW.html to filter, inspect full images, compare favorites and export a shortlist. Each concept has an exact prompt and a plain-language brief in plan.json. Full PNGs remain unmodified; JPEG thumbnails/contact sheets are review aids. Built-in image generation was used; no external image API runner.\n\n'
        +'Cookbook sheets each include a monster-note page and a preparation page. They share the Pickle Mimic and Tomb-Truffle Broth examples so the twelve graphic styles can be compared directly. Environment sheets pair regular concept art and a dark player-height view. Intro sheets are six-frame sequences. HUD sheets include a complete screen plus component/state studies. Mechanism sheets show physical clue/action/result relationships. Monster briefs define one simple trigger/response/counterplay loop. Each vermin board varies Pantry Rat, Sootling, Flour Puff and Lint Scuttler together, providing 12 designs per family.\n\n'
        +'The attached HTML supplies B/C/D topology and rooms: B is the descending shaft helix, C has two towers and a canal, D has two loops joined at the Well. These are mood, prop and lighting studies, not metric construction drawings; some shaft views exaggerate depth. Camera height, room scale and light reach need calibration in Unreal. Interpretations must not be mistaken for revised level layouts. Royal Daily Feast cast and the dust-creature reference supply the visual anchors. The requested floor puffs are explored as the reference image\'s Flour Puff family.\n\n'
        +'All story additions, recipes, behavior loops and HUD interactions are proposals, not canon or implemented mechanics. Rendered words may need a typography pass; the written notes are authoritative. No Unreal map, gameplay source, plugin or engine asset is changed by this concept pass.\n',encoding='utf-8')

if __name__=='__main__':main()
