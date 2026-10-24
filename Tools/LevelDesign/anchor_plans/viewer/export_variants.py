"""Export the Warrens v8 layout variants as ONE self-contained, offline HTML (viewer + a tab per layout + Compare).

python viewer/export_variants.py [--output PATH] [--layouts v8a v8b ...] [--no-baseline]

Default: every data/warrens_v8*.json, plus data/warrens.json as the current baseline (first tab). --layouts takes
v8a / warrens_v8a / a path to any layout .json. Embeds the pinned three.js r160 global build (hash asserted), the
layouts, viewer.js, variants.js and index.html's side panel; writes READ-ME.txt beside the output. Reads data only:
it runs no design script and touches no Unreal asset.
"""
import argparse
import datetime
import hashlib
import json
import re
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
PLANS = HERE.parent
DATA = PLANS / 'data'
ROOT = HERE.parents[3]
THREE = ROOT / 'Saved/WarrensShare-20261022/three.min.js'
THREE_SHA256 = '170c6789f43217c96b3170f4b42fafe135de7f7cd48497a4218f9757ee1d49fa'
DEFAULT_OUT = ROOT / 'docs/design/warrens-v8-variants-20261023/Warrens-v8-Variants.html'

README = """WARRENS v8 / LAYOUT VARIANTS - {date}

Open {name} in Chrome or Edge. It is self-contained and works offline from disk: no server, network or install.

These are proposed layouts, not the playable map. The live Warrens map (data/warrens.json, revision {baseline}) is the
first tab, for comparison. Nothing in this file changes the game, the builder or any Unreal asset.

Tabs along the top switch layouts. Compare puts every layout side by side: footprint, floor heights, how much of the
walked plan is corridor, the transition lengths between rooms, the Well-facing rooms, the authored beats, one-way and
two-way shortcuts, Level Instance tiles and ports, how many route-gate closure sets keep every entrance connected,
dead ends, anything the viewer could not draw, and each layout's thesis.

In a layout tab:
- Orbit (drag rotate, right-drag pan, wheel zoom), Plan (top down) and Walk (first person at the chef's numbers: WASD,
  Shift sprint, C crouch, Esc). Walk's "go to view..." stands you at a Well window looking at the landmark.
- instances: dashed outlines are proposed Unreal Level Instance tiles at their height, one colour each; the small
  squares are their ports (doors, stairs, ladders, crawls, balconies, lifts, drops) with ids.
- views: pale cyan dashed sightlines from a wing to the landmark, arrowhead at the landmark ("Well windows").
- beats: diamonds mark the authored transition between two spaces (turn, stair, squeeze, bridge, reveal, drop, lift,
  ladder).
- The star label is the landmark; "N/E/S/W face" labels sit 8 m out on each side and name what that side shows.
- Variant notes (side panel) hold the layout's thesis, principles, changes and risks. "Cannot render" lists data the
  mockup cannot draw (for example a room outside its level's grid).

Limits: the viewer rasterizes the data at 0.5 m the way build_warrens.py does; it does not show materials, dressing,
lighting as built, collision, physics or two-player behaviour. Graph metrics use authored link costs; ladders, lifts
and drops count as links but are not drawn as floor.

Layouts in this export: {layouts}
Generated {generated}{commit}. Three.js r160, MIT License, (c) 2010-2023 three.js authors.
"""


def resolve(name):
    p = Path(name)
    if p.suffix == '.json' and p.exists():
        return p.resolve()
    stem = name if name.startswith('warrens') else 'warrens_' + name
    f = DATA / (stem + '.json')
    if not f.exists():
        raise SystemExit(f'no layout {name!r}: looked for {f}')
    return f


def load(f, tab):
    raw = f.read_bytes()
    d = json.loads(raw.decode('utf-8'))
    d['_file'] = f.name
    d['_tab'] = tab or str(d.get('revision') or f.stem.replace('warrens_', ''))
    return d, dict(file=f.name, revision=d.get('revision'), sha256=hashlib.sha256(raw).hexdigest())


def index_parts():
    html = (HERE / 'index.html').read_text(encoding='utf-8')
    style = re.search(r'<style>(.*?)</style>', html, re.S)
    app = re.search(r'(<div id="app">.*?)\s*<script src="layouts.js">', html, re.S)
    assert style and app, 'index.html no longer has the <style> / <div id="app"> ... <script src="layouts.js"> shape'
    return style.group(1), app.group(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--output', type=Path, default=DEFAULT_OUT)
    parser.add_argument('--layouts', nargs='+', help='v8a v8b ... (or warrens_v8a, or a .json path); default every data/warrens_v8*.json')
    parser.add_argument('--no-baseline', action='store_true', help='leave out data/warrens.json')
    args = parser.parse_args()

    assert hashlib.sha256(THREE.read_bytes()).hexdigest() == THREE_SHA256, f'Unexpected Three.js distribution at {THREE}'
    files = [resolve(n) for n in args.layouts] if args.layouts else sorted(DATA.glob('warrens_v8*.json'))
    if not files:
        print('note: no data/warrens_v8*.json yet; exporting the baseline only')
    layouts, meta_files = [], []
    if not args.no_baseline:
        base = DATA / 'warrens.json'
        d, m = load(base, None)
        d['_tab'] = 'current ' + str(d.get('revision'))
        layouts.append(d); meta_files.append(m)
    for f in files:
        if f.resolve() == (DATA / 'warrens.json').resolve() and not args.no_baseline:
            continue
        d, m = load(f, None)
        layouts.append(d); meta_files.append(m)
    assert layouts, 'nothing to export'

    try:
        commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        commit = ''
    generated = datetime.datetime.now().strftime('%Y-%m-%d %H:%M')
    payload = dict(layouts=layouts, meta=dict(generated=generated, commit=commit, files=meta_files))
    style, app = index_parts()
    script = lambda text: text.replace('</script', '<\\/script')
    html = (HERE / 'variants.template.html').read_text(encoding='utf-8')
    for token, content in [('INDEX_STYLE', style), ('APP', app),
                           ('DATA', json.dumps(payload, separators=(',', ':')).replace('<', '\\u003c')),
                           ('THREE', script(THREE.read_text(encoding='utf-8'))),
                           ('VIEWER', script((HERE / 'viewer.js').read_text(encoding='utf-8'))),
                           ('SCRIPT', script((HERE / 'variants.js').read_text(encoding='utf-8')))]:
        assert html.count('<!--' + token + '-->') == 1, token
        html = html.replace('<!--' + token + '-->', content)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(html, encoding='utf-8')
    readme = args.output.parent / 'READ-ME.txt'
    readme.write_text(README.format(date=datetime.date.today().strftime('%d %B %Y').upper(), name=args.output.name,
                                    baseline=layouts[0].get('revision') if not args.no_baseline else 'not included',
                                    layouts=', '.join(f"{d['_tab']} ({d['_file']})" for d in layouts),
                                    generated=generated, commit=f' from commit {commit[:9]}' if commit else ''), encoding='utf-8')
    print(json.dumps(dict(output=str(args.output.resolve()), bytes=args.output.stat().st_size, readme=str(readme.resolve()),
                          layouts=[f"{d['_tab']} <- {d['_file']}" for d in layouts], commit=commit[:9])))


if __name__ == '__main__':
    main()
