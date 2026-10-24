"""Package verified outputs; no backups, caches or duplicated source archive."""
from pathlib import Path
import hashlib,json,zipfile
ROOT=Path(__file__).resolve().parent
report=json.loads((ROOT/'VERIFICATION.json').read_text())
assert report['fresh_blender_reopen']['fresh_process_open']
files=sorted(p for p in ROOT.rglob('*') if p.is_file() and p.suffix not in ['.zip','.pyc','.blend1','.blend2'] and '__pycache__' not in p.parts and p.name!='manifest.json')
manifest={p.relative_to(ROOT).as_posix():{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files}
(ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
target=ROOT/'WarrensC-Dressing-Pack-r01.zip'
with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:
    for path in files+[ROOT/'manifest.json']:z.write(path,path.relative_to(ROOT).as_posix())
with zipfile.ZipFile(target) as z:
    assert z.testzip() is None
    assert set(z.namelist())==set(manifest)|{'manifest.json'}
    for name,meta in manifest.items():assert hashlib.sha256(z.read(name)).hexdigest()==meta['sha256'],name
print(json.dumps({'archive':str(target),'files':len(files)+1,'bytes':target.stat().st_size,'all_manifest_hashes_verified':True,'sha256':hashlib.file_digest(target.open('rb'),'sha256').hexdigest()}))
