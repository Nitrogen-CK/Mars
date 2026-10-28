"""Emit the reviewed C prototype manifest without replacing its saved baseline."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PLANS = ROOT/'Tools/LevelDesign/anchor_plans'
RUN = ROOT/'Saved/WarrensCGameplay-20261024'
sys.path.insert(0,str(PLANS))
import build_warrens as builder


def main():
    builder.MAP = '/Game/Mars/Maps/Warrens_VariantC_Mars_MAP'
    data = json.loads((PLANS/'data/warrens_v8c.json').read_text())
    manifest,summary = builder.manifest(write=False,data=data)
    assert not any(summary.get(k) for k in ('gateLeaks','walkBreaks','dropErrors','blockedViews','propErrors'))
    assert len(manifest['sectionOverrides']) == 1
    assert sum(e['cls']=='Mars_SlidingBridge_EntityScript' for e in manifest['entities']) == 1
    assert not any(e['cls']=='Mars_Shortcut_EntityScript' and e['note']=='ChainCrossing' for e in manifest['entities'])
    for suffix,value in [('manifest',manifest),('summary',summary)]:
        (RUN/('p2-'+suffix+'.json')).write_text(json.dumps(value,indent=1))
    print(json.dumps(dict(section=manifest['sectionOverrides'],
        boundary='Static manifest only; moving support, guard collision and played traversal remain runtime gates.',
        placement_warnings=summary['ladderErrors'])))


if __name__ == '__main__': main()
