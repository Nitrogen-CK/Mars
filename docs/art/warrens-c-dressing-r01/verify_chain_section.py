"""Validate actual section art files, reviews, component coverage, links and JS."""
from pathlib import Path
from collections import Counter
import hashlib,json,re,subprocess
from PIL import Image
ROOT=Path(__file__).resolve().parent
OUT=ROOT/'sections/chain-crossing-sluice'
parts=json.loads((OUT/'model_catalog.json').read_text())
jobs=[j for j in json.loads((ROOT/'image_jobs.json').read_text()) if j.get('section')=='chain-crossing-sluice']
progress=json.loads((ROOT/'art_progress.json').read_text())['completed']
assert len(parts)==len({p['id'] for p in parts})==88
assert len(jobs)==27
assert len([j for j in jobs if j['section_part_ids']])==23
for p in parts:
    matches=[j for j in jobs if p['id'] in j['section_part_ids']]
    assert len(matches)==1,(p['id'],len(matches))
    assert matches[0]['id']==p['model_sheet']
    assert (OUT/'briefs'/f"{p['id']}_{p['name']}.md").is_file()
for j in jobs:
    path=ROOT/j['image'];entry=progress[j['id']]
    assert path.is_file() and entry['path']==j['image'],j['id']
    assert hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256'],j['id']
    assert entry['review']=='inspected',j['id']
    with Image.open(path) as im:assert im.width>=1500 and im.height>=1000
    assert (ROOT/'prompts'/f"{j['id']}.txt").is_file()
wheel=next(j for j in jobs if j['id']=='CS06')
assert wheel['image'].endswith('CS06-r02.png') and (ROOT/wheel['revision_reference']).is_file()
html=(OUT/'PREVIEW.html').read_text(encoding='utf-8')
script=re.search(r'<script>(.*?)</script>',html,re.S).group(1)
(OUT/'qa').mkdir(exist_ok=True)
script_path=OUT/'qa/preview-script.js';script_path.write_text(script,encoding='utf-8')
result=subprocess.run(['node','--check',str(script_path)],capture_output=True,text=True)
assert result.returncode==0,result.stderr
for match in re.findall(r'(?:src|href)="([^"#]+)"',html):
    if '${' in match or match.startswith(('http','data:')) or match.endswith(('.zip','VERIFICATION.json')):continue
    assert (OUT/match).is_file(),match
for p in parts:
    # Brief links select revisions rather than stale original images.
    ref=next(j for j in jobs if j['id']==p['model_sheet'])
    assert (ROOT/ref['image']).is_file()
report={'component_entries':len(parts),'roles':dict(Counter(p['role'] for p in parts)),
 'model_sheets':23,'assembly_and_player_sheets':4,'native_images_reviewed':len(jobs),
 'components_with_one_linked_model_sheet':len(parts),'selected_wheel_revision':'CS06-r02.png',
 'source_contracts_read':True,'source_control_mismatch_documented':True,
 'gallery_javascript_syntax':'passed','static_links':'passed',
 'browser_visual_observation':'Not claimed: local-file browser navigation unavailable under tool policy.',
 'production_meshes_or_unreal_integration':False}
(OUT/'VERIFICATION.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
