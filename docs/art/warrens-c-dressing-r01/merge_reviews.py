"""Run only after generation finishes; a review applies only to its exact selected bytes."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parent
progress=json.loads((ROOT/'art_progress.json').read_text())
for ident,review in json.loads((ROOT/'qa/review-log.json').read_text()).items():
    entry=progress['completed'][ident]
    assert review['sha256']==entry['sha256']==hashlib.sha256((ROOT/review['image']).read_bytes()).hexdigest(),ident
    assert review['image']==entry['path'],ident
    entry['review']='inspected';entry['review_mode']=review['mode']
(ROOT/'art_progress.json').write_text(json.dumps(progress,indent=2)+'\n')
print('Image reviews merged with matching source hashes.')
