"""Package source, exports, previews and evidence; verify every archive entry."""
import hashlib
import json
from pathlib import Path
import re
import zipfile

root = Path(__file__).resolve().parent
files = set()
for pattern in ['*.py', '*.json', '*.html', 'Textures/*', 'Model/*.py', 'Model/*.json',
                'Model/*.md', 'Model/*.blend', 'Model/FBX/*.fbx', 'Model/Renders/*.png',
                'Model/Renders/*.gif', 'UnrealPreview/Verified*/*.png']:
    files.update(p for p in root.glob(pattern) if p.is_file())
files.discard(root / 'delivery_manifest.json')
for target in re.findall(r'(?:src|href)="([^"#]+)"', (root / 'PREVIEW.html').read_text()):
    if target.endswith('.zip'):
        continue
    assert (root / target).is_file(), target
manifest = {p.relative_to(root).as_posix(): {'bytes': p.stat().st_size,
             'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(files)}
(root / 'delivery_manifest.json').write_text(json.dumps(manifest, indent=2))
files.add(root / 'delivery_manifest.json')
archive = root / 'Cookbook-Model-Rig-R02.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as output:
    for path in sorted(files):
        output.write(path, path.relative_to(root).as_posix())
with zipfile.ZipFile(archive) as check:
    assert check.testzip() is None
    for path in files:
        name = path.relative_to(root).as_posix()
        assert hashlib.sha256(check.read(name)).digest() == hashlib.sha256(path.read_bytes()).digest(), name
print(json.dumps({'archive': str(archive), 'bytes': archive.stat().st_size,
                  'verified_entries': len(files), 'gallery_links': 'all valid'}))
