"""Persist native generated art; thumbnails are review aids only."""
import argparse,hashlib,json,shutil
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parent
parser=argparse.ArgumentParser();parser.add_argument('id');parser.add_argument('source')
args=parser.parse_args()
jobs=json.loads((ROOT/'image_jobs.json').read_text(encoding='utf-8'))
job=next(j for j in jobs if j['id']==args.id)
target=ROOT/job['image'];assert not target.exists(),target
shutil.copy2(args.source,target)
progress=json.loads((ROOT/'art_progress.json').read_text(encoding='utf-8'))
with Image.open(target) as image:
    dims=list(image.size)
    alpha=list(image.getchannel('A').getextrema()) if 'A' in image.getbands() else None
    thumb=image.convert('RGBA');back=Image.new('RGBA',thumb.size,'#30352d');back.alpha_composite(thumb)
    back.convert('RGB').resize((480,320)).save(ROOT/'qa'/f'{args.id}.jpg',quality=91)
progress['completed'][args.id]={'path':job['image'],'dimensions':dims,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
    'alpha_extrema':alpha,'original':args.source,'review':'pending'}
(ROOT/'art_progress.json').write_text(json.dumps(progress,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'id':args.id,'dimensions':dims,'alpha_extrema':alpha}))
