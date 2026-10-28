"""Export a single-file, offline Warrens review from the current builder manifest.

Does not run design generators or touch Unreal assets. Pass --three with the
existing viewer's pinned three.js 0.160.0 distribution, including its MIT header.
"""
import argparse
import base64
import hashlib
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(HERE.parent))
import build_warrens


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--three', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    library = args.three.read_text(encoding='utf-8')
    expected = '170c6789f43217c96b3170f4b42fafe135de7f7cd48497a4218f9757ee1d49fa'
    assert hashlib.sha256(args.three.read_bytes()).hexdigest() == expected, 'Unexpected Three.js distribution'
    source = build_warrens.load()
    manifest, summary = build_warrens.manifest(write=False, data=source)
    accepted = ROOT / 'Saved/WarrensOrangeLandmarks-20261022'
    assert manifest == json.loads((accepted / 'manifest-after.json').read_text()), 'Current map source differs from accepted snapshot'
    def embed(path):
        return 'data:image/png;base64,' + base64.b64encode((ROOT / path).read_bytes()).decode()
    payload = dict(source=source, manifest=manifest, summary=summary,
                   commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                   sourceHash=hashlib.sha256(build_warrens.DATA.read_bytes()).hexdigest(),
                   audit=json.loads((accepted / 'audit.json').read_text()),
                   static=json.loads((accepted / 'final-static.json').read_text()),
                   comparisons=[dict(title='Orange traversal landmarks', image=embed('Saved/WarrensOrangeLandmarks-20261022/before-after.png')),
                                dict(title='Material readability repair', image=embed('Saved/WarrensMaterialRepair-20261022/before-after.png')),
                                dict(title='All twelve areas: material before / after', image=embed('Saved/WarrensMaterialRepair-20261022/all-areas-before-after.png'))])
    html = (HERE / 'share.template.html').read_text(encoding='utf-8')
    for token, content in [('DATA', json.dumps(payload, separators=(',', ':')).replace('<', '\\u003c')),
                           ('THREE', library.replace('</script', '<\\/script')),
                           ('SCRIPT', (HERE / 'share.js').read_text(encoding='utf-8'))]:
        html = html.replace('<!--' + token + '-->', content)
    assert not any('<!--' + t + '-->' in html for t in ['DATA', 'THREE', 'SCRIPT'])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(html, encoding='utf-8')
    print(json.dumps(dict(output=str(args.output.resolve()), bytes=args.output.stat().st_size,
                          manifestBoxes=len(manifest['boxes']), acceptedManifestExact=True,
                          sourceHash=payload['sourceHash'], commit=payload['commit'])))


if __name__ == '__main__':
    main()
