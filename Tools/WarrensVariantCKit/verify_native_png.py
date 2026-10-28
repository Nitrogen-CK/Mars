"""Fully decode one native screenshot and write a unique verification sidecar."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

def main():
    p=argparse.ArgumentParser();p.add_argument('path');a=p.parse_args()
    root=Path(__file__).resolve().parents[2];path=(root/a.path).resolve()
    assert path.is_relative_to(root) and path.suffix.lower()=='.png'
    data=path.read_bytes();assert data.endswith(b'\x00\x00\x00\x00IEND\xaeB`\x82')
    with Image.open(path) as im:im.verify()
    with Image.open(path) as im:
        im.load();assert im.size==(1600,1000);mode=im.mode
    out=path.with_suffix('.decode.json');assert not out.exists()
    r=dict(status='PNG_CRC_AND_FULL_PIXEL_DECODE_PASSED',file=path.relative_to(root).as_posix(),sha256=hashlib.sha256(data).hexdigest(),bytes=len(data),size=[1600,1000],mode=mode)
    out.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))

if __name__=='__main__':main()
