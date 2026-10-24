"""Check final local deliverables, independent of generation completion signals."""
import collections
import datetime
import hashlib
import json
import re
import subprocess
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parent
plan = json.loads((root/'plan.json').read_text(encoding='utf-8'))
progress = json.loads((root/'progress.json').read_text(encoding='utf-8'))
assert len(plan['jobs']) == 108
assert len({j['id'] for j in plan['jobs']}) == 108
assert len(progress['completed']) == 108, len(progress['completed'])
assert not progress.get('failed'), progress.get('failed')
counts = collections.Counter(j['category'] for j in plan['jobs'])
assert len(counts) == 9 and all(n == 12 for n in counts.values()), counts
hashes = set()
minimum = [100000, 100000]
for job in plan['jobs']:
    entry = progress['completed'][job['id']]
    assert entry['review'] == 'inspected', job['id']
    assert entry['path'] == job['image'], job['id']
    path = root/entry['path']
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    assert digest == entry['sha256'], job['id']
    assert digest not in hashes, 'Duplicate image: '+job['id']
    hashes.add(digest)
    with Image.open(path) as image:
        assert list(image.size) == entry['dimensions']
        assert image.width >= 1024 and image.height >= 768
        minimum = [min(minimum[0], image.width), min(minimum[1], image.height)]
        image.verify()
    assert (root/'prompts'/f"{job['id']}.txt").read_text(encoding='utf-8') == job.get('actual_prompt', job['prompt']), job['id']
    assert (root/'thumbs'/f"{job['id']}.jpg").is_file()
for category in counts:
    assert (root/'contact-sheets'/f'{category}.jpg').is_file()
sources = json.loads((root/'sources.json').read_text(encoding='utf-8'))
assert hashlib.sha256((root/'references/Warrens-v8-Variants.html').read_bytes()).hexdigest() == sources['sha256']
gallery = (root/'PREVIEW.html').read_text(encoding='utf-8')
match = re.search(r'const DATA=(.*?);const total=', gallery, re.S)
assert match
cards = json.loads(match.group(1))
assert len(cards) == 108
assert {c['id'] for c in cards} == {j['id'] for j in plan['jobs']}
script = re.search(r'<script>(.*?)</script>', gallery, re.S).group(1)
(root/'review-script.js').write_text(script, encoding='utf-8')
syntax = subprocess.run(['node', '--check', str(root/'review-script.js')], capture_output=True, text=True)
assert syntax.returncode == 0, syntax.stderr
report = {'verified_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'concepts':108, 'categories':dict(counts), 'inspected':108,
          'unique_image_hashes':len(hashes), 'minimum_dimensions':minimum,
          'exact_prompt_files':108, 'thumbnail_files':108,
          'source_layout_hash_matches':True, 'gallery_cards':len(cards),
          'gallery_javascript_syntax':'passed: node --check',
          'browser_observation':'Not run: browser policy blocked file:// navigation. Image sheets inspected directly.',
          'unreal_changes':'None in this art task'}
(root/'VERIFICATION.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report))
