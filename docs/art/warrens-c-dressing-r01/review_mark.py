"""Record human-visible image review hashes separately from active generation progress."""
from pathlib import Path
import argparse,hashlib,json
ROOT=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('ids',nargs='+');p.add_argument('--mode',default='native image');a=p.parse_args()
jobs={j['id']:j for j in json.loads((ROOT/'image_jobs.json').read_text())}
path=ROOT/'qa/review-log.json';review=json.loads(path.read_text()) if path.exists() else {}
for ident in a.ids:
    j=jobs[ident];im=ROOT/j['image'];assert im.is_file(),ident
    review[ident]={'image':j['image'],'sha256':hashlib.sha256(im.read_bytes()).hexdigest(),'mode':a.mode}
path.write_text(json.dumps(review,indent=2)+'\n')
print('Reviewed: '+', '.join(a.ids))
