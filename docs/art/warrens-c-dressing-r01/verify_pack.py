"""Asset-domain validation: seams, channels, source/brief integrity and static gallery links."""
from pathlib import Path
from collections import Counter
import hashlib,json,re,subprocess,xml.etree.ElementTree as ET
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[2]
def read(p):return json.loads((ROOT/p).read_text(encoding='utf-8'))
def im(p):
    with Image.open(ROOT/p) as image:return np.asarray(image)
materials=read('materials.json');assert len(materials)==19
edges=[];normal_error=0.
for mat in materials:
    for kind,path in mat['maps'].items():
        image=im(path);assert image.shape[:2]==(1024,1024),(mat['id'],kind,image.shape)
        assert np.array_equal(image[0],image[-1]),(mat['id'],kind,'V seam')
        assert np.array_equal(image[:,0],image[:,-1]),(mat['id'],kind,'U seam')
        if kind=='Height':assert (ROOT/path).read_bytes()[24]==16
        edges.append(path)
    gl=im(mat['maps']['NormalGL']).astype(np.float32);dx=im(mat['maps']['NormalDX']).astype(np.float32)
    assert np.array_equal(gl[...,0],dx[...,0]) and np.array_equal(gl[...,2],dx[...,2])
    assert np.max(np.abs(gl[...,1]+dx[...,1]-255))<=1
    unit=gl/127.5-1;normal_error=max(normal_error,float(np.max(np.abs(np.linalg.norm(unit,axis=-1)-1))))
assert normal_error<.012,normal_error
for trim in read('trim_metadata.json'):
    assert trim['repeat_u'] and not trim['repeat_v'] and len(trim['bands'])==8
    for kind,path in trim['maps'].items():
        image=im(path);assert image.shape[:2]==(1024,1024)
        assert np.array_equal(image[:,0],image[:,-1]),(trim['id'],kind,'U seam')
    for band in trim['bands']:assert band['uv_min'][1]<band['v_center']<band['uv_max'][1]
texture_files=list((ROOT/'textures').rglob('*.png'))
for path in texture_files:
    with Image.open(path) as image:
        w,h=image.size;assert w&(w-1)==0 and h&(h-1)==0,(path.name,image.size)
        image.verify()
decal=read('decal_metadata.json');assert len(decal)==20
canonical=['Glyph_'+x for x in ['Square','Circle','Triangle','Diamond','Cross','Bars']]
assert [x['name'] for x in decal[:6]]==canonical
for item in decal:
    ET.parse(ROOT/item['svg']);a=im(item['png']);assert a.shape==(256,256,4)
    assert a[...,3].min()==0 and a[...,3].max()==255
bars=im('textures/decals/Glyph_Bars.png')[...,3]>127
runs=np.diff(np.r_[False,bars[:,128],False].astype(np.int8));assert np.sum(runs==1)==3
assert all(bars[y,64:192].all() for y in [60,128,192]),'Bars are not horizontal'
for path in (ROOT/'textures/decals').glob('Wear_*.png'):
    a=im(path.relative_to(ROOT));assert not a[0,:,3].any() and not a[-1,:,3].any() and not a[:,0,3].any() and not a[:,-1,3].any(),path.name
art=read('art_progress.json');jobs=read('image_jobs.json');assert len(jobs)==len(art['completed'])==82
for job in jobs:
    entry=art['completed'][job['id']];path=ROOT/job['image'];assert entry['review']=='inspected',job['id']
    assert hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256'],job['id']
    if job['type']=='painted':
        a=im(job['image']);assert a.shape[2]==4 and a[...,3].min()==0 and a[...,3].max()==255
source=read('SOURCE.json');assert hashlib.sha256((ROOT/'references/warrens_v8c-source.json').read_bytes()).hexdigest()==source['sha256']
assert hashlib.sha256((REPO/source['layout']).read_bytes()).hexdigest()==source['sha256'],'Current source changed since snapshot'
layout=read('references/warrens_v8c-source.json');props=read('prop_catalog.json');rooms=read('room_dressing.json')
assemblies=read('assembly_recipes.json')
assert len(assemblies['source_props'])==len(layout['props'])==26
assert set(assemblies['puzzle_art'])=={p['id'] for p in layout['puzzles']}
assert len(props)==150 and len({p['id'] for p in props})==150
coverage=read('VISUAL_COVERAGE.json')
assert coverage['new_model_entries']==coverage['new_models_with_reviewed_reference']==149
assert coverage['uncovered_new_models']==[] and coverage['reuse_only_entries']==['I14']
for prop in props:
    assert prop['model_sheets'] or prop['status']=='reuse_existing',prop['id']
for tile in rooms:
    assert any(j['type']=='dressing-sheet' and tile['id'] in j['tiles'] for j in jobs),tile['id']
assert {r['id'] for r in rooms}=={t['id'] for t in layout['instances']}
assert {room for r in rooms for room in r['rooms']}=={r['id'] for r in layout['rooms']}
for prop in props:
    assert set(prop['tiles'])<={r['id'] for r in rooms}
    assert (ROOT/'briefs'/f"{prop['id']}_{prop['name']}.md").is_file()
    if 'existing_gameplay_source' in prop:assert (REPO/prop['existing_gameplay_source']).is_file(),prop['id']
    if prop['dimension_basis']=='current authored source proxy envelope':
        assert list(prop['dimensions_cm'].values())==[v*100 for v in prop['source_proxy_size_metres']],prop['id']
html=(ROOT/'PREVIEW.html').read_text(encoding='utf-8');script=re.search(r'<script>(.*?)</script>',html,re.S).group(1)
(ROOT/'qa/preview-script.js').write_text(script,encoding='utf-8')
result=subprocess.run(['node','--check',str(ROOT/'qa/preview-script.js')],capture_output=True,text=True);assert result.returncode==0,result.stderr
for match in re.findall(r'(?:src|href)="([^"#]+)"',html):
    if '${' in match or match.startswith(('http','data:')):continue
    if match.endswith('.zip') or match=='VERIFICATION.json':continue # Written after verification.
    assert (ROOT/match).is_file(),match
reopened=read('qa/BLENDER_REOPEN_VERIFICATION.json');assert reopened['fresh_process_open'] and reopened['unique_asset_materials']==35
for name in ['NEUTRAL_MATERIALS','LANTERN_MATERIALS','ATLASES_AND_ART']:
    with Image.open(ROOT/'qa'/f'{name}.png') as image:assert image.size==(1800,1400)
report={'source_sha256':source['sha256'],'source_still_matches_current_layout':True,'surface_families':19,
        'surface_maps':95,'matching_surface_edge_tests':len(edges)*2,'normal_max_unit_length_error':normal_error,
        'trim_sheets':2,'technical_pngs_power_of_two':len(texture_files),'vector_icons':20,'canonical_glyphs':6,
        'painted_alpha_sources':6,'model_sheets':sum(j['type']=='model-sheet' for j in jobs),
        'district_sheets':sum(j['type']=='dressing-sheet' for j in jobs),'selected_art_inspected':len(jobs),'prop_entries':len(props),
        'new_models_with_reviewed_reference':coverage['new_models_with_reviewed_reference'],'reuse_only_entries':['I14'],
        'priorities':dict(Counter(p['priority'] for p in props)),'tiles':len(rooms),'source_rooms':len(layout['rooms']),
        'source_dressing_proxies_covered':len(assemblies['source_props']),'authored_puzzles_covered':len(assemblies['puzzle_art']),
        'protected_views':len(layout['views']),'fresh_blender_reopen':reopened,'gallery_javascript_syntax':'passed',
        'browser_visual_observation':'Not claimed; local file navigation was blocked by browser policy in this chat.',
        'district_composition_status':'Inspected as exploratory composition only; in-image IDs/layout are non-authoritative and not accepted as technical/placement plans.',
        'unreal_import_or_pie_acceptance':False,'live_map_or_gameplay_edits':False}
(ROOT/'VERIFICATION.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
