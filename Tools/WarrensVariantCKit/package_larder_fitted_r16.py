"""Package actual native comparisons with control variation and review boundary."""
import hashlib
import html
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageStat

ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/native-fitted-stone-r16'


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


comparisons=[]
names=['low_ceiling_fitted','low_ceiling_base','storage_fitted','bank_fitted','outside_belfry_fitted','outside_sluice_fitted','roof_window_fitted','s3_fitted']
for name in names:
    records=[]
    for suffix in ['A','B']+(['C'] if name.startswith('low_ceiling') else []):
        path=DOC/(name+'_'+suffix+'.png');im=Image.open(path);im.load();assert im.size==(1600,1000)
        side=json.loads(path.with_suffix('.json').read_text())
        records.append((suffix,path,side))
    a,b=records[:2];delta=[k for k in a[2] if a[2][k]!=b[2][k]]
    assert set(delta)=={'view','fitted_stone'}
    control=None
    if len(records)==3:
        c=records[2];diff=ImageChops.difference(Image.open(a[1]).convert('RGB'),Image.open(c[1]).convert('RGB'))
        control=dict(changed_RGB_pixels=sum(any(v) for v in diff.getdata()),maximum_channel_difference=max(v[1] for v in diff.getextrema()),mean_channel_difference=ImageStat.Stat(diff).mean,bbox=diff.getbbox(),PNG_bytes_identical=a[1].read_bytes()==c[1].read_bytes())
    comparisons.append(dict(name=name,files=[dict(state=suffix,file=path.name,sha256=sha(path)) for suffix,path,_ in records],AB_sidecar_changed_keys=delta,control=control))
for path in DOC.glob('*.png'):
    im=Image.open(path);im.load();assert im.size==(1600,1000)
restored=ROOT/'Saved/WarrensCGameplay-20261024/LarderRollout/finish_room_trial_r12/restored.json'
review=DOC/'ASTRA_FITTED_STONE_AND_WORKING_ROOM_REVIEW_R16.md'
result=dict(status='ASTRA_ACCEPTED_WORKING_LARDER_ART_RETENTION_IMPLEMENTATION_PENDING',comparisons=comparisons,actual_png_count=len(list(DOC.glob('*.png'))),restoration_file=restored.relative_to(ROOT).as_posix(),restoration_sha256=sha(restored),review_sha256=sha(review),boundary='Actual native player/lantern captures, original/new material binding axis only. Geometry, light, props, water and accepted R14 raw shell fixed. Lit control has small unclassified variation; no perfect pixel claim. Normal/roughness buffers use independent existing texture maps. Working appearance accepted by Astra; source levels/native and Blender libraries are not yet updated by this gallery. Outside Sluice floor remains an explicit later-rollout coverage boundary.')
(DOC/'fitted_comparison_receipt_r01.json').write_text(json.dumps(result,indent=2)+'\n')
sections=[]
for row in comparisons:
    figures=''.join('<figure><figcaption>'+html.escape(v['state']+' — '+('fitted stone' if v['state']=='B' else 'original fitted finish'))+'</figcaption><a href="'+v['file']+'"><img src="'+v['file']+'"></a></figure>' for v in row['files'])
    sections.append('<section><h2>'+html.escape(row['name'].replace('_',' '))+'</h2><div class="pair">'+figures+'</div></section>')
page='''<!doctype html><html><meta charset="utf-8"><title>Larder native finish R16</title><style>body{background:#171511;color:#eee5cf;font:16px/1.5 system-ui;margin:30px;max-width:1800px}h1{font-size:32px}h2{font-size:20px}p{max-width:1000px}.pair{display:flex;gap:12px}figure{flex:1;margin:0;min-width:0}img{width:100%;display:block}figcaption{padding:8px;background:#29261f}section{margin:30px 0}a{color:#efc880}.status{border-left:4px solid #bea767;padding-left:16px}</style><h1>Larder — complete working finish</h1><p class="status">Astra accepted this working appearance for retention implementation. These are actual Unreal player-camera captures. Source levels and libraries still need to be saved and verified.</p><p>Broad painterly stone now covers the formerly pale fitted ceiling and wall returns. Independent normal and roughness maps are retained. Every comparison holds the accepted roof, lighting, props and brine fixed; only the five enumerated decorative fitted groups change.</p><p>Return controls are shown for the low ceiling. Lit A/C has a small unclassified pixel variation; BaseColor A/C differs at three pixels by at most two byte values. No exact Lit parity claim.</p>'''+''.join(sections)+'''<section><h2>Independent channel checks</h2><div class="pair"><figure><figcaption>WorldNormal</figcaption><img src="fitted_normal_B.png"></figure><figure><figcaption>Roughness</figcaption><img src="fitted_roughness_B.png"></figure></div></section><p><a href="ASTRA_FITTED_STONE_AND_WORKING_ROOM_REVIEW_R16.md">Astra review</a> · <a href="fitted_comparison_receipt_r01.json">Capture and restoration evidence</a></p></html>'''
(DOC/'PREVIEW.html').write_text(page,encoding='utf-8')
print('R16_GALLERY_PACKAGED',result['actual_png_count'],'ACTUAL_NATIVE_PNGS')
