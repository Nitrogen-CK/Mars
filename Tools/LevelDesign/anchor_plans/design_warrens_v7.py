"""Warrens v7: authored spatial identities and two-person cargo reservations.

Run without arguments to write the live layout. build(batch='A'/'B'/'C') previews
the cumulative structural batches without touching the live JSON or frozen v6.
Local route and fixture deltas are opt-in; frozen v6 and its generic tables stay unchanged.
"""
import copy
import json
from pathlib import Path

import design_warrens_v6 as v6

HERE = Path(__file__).resolve().parent
OUT = HERE / 'data' / 'warrens.json'
GEOMETRY_PATH = HERE / 'design_warrens_v7_geometry.json'


def build(batch='C'):
    geometry = json.loads(GEOMETRY_PATH.read_text(encoding='utf-8'))
    data = copy.deepcopy(v6.build())
    data['revision'] = 'v7r1'
    data['source'] = 'Tools/LevelDesign/anchor_plans/design_warrens_v7.py (Warrens v7: two-person spatial revision)'
    data['routeAnchorClass'] = 'Mars_Warrens_Anchor_Route_EntityScript'
    for key in ('structures', 'openings', 'connectors', 'terrain', 'kitchen'):
        data[key] = copy.deepcopy(geometry[key])
    data['geometryDeviations'] = copy.deepcopy(geometry['deviations'])
    data['localFixtures'] = copy.deepcopy(geometry.get('localFixtures', []))
    data['wayfindingLabels'] = copy.deepcopy(geometry.get('wayfindingLabels', []))
    data['entryKitPan'] = geometry.get('entryKitPan', False)
    if 'presentation' in geometry:
        data['presentation'] = copy.deepcopy(geometry['presentation'])
    if 'bellkeeper' in geometry:
        data['bellkeeper'] = copy.deepcopy(geometry['bellkeeper'])
        data['lights'] += copy.deepcopy(geometry['bellkeeper'].get('taskLights', []))
        data['caches'].remove('Bellkeeper')
        niche = next(n for n in data['niches'] if n['anchorId'] == 'Bellkeeper')
        niche['authoredReward'] = True  # retain its floor/walls, suppress only the random cache anchor
        niche['note'] = "Bellkeeper's Confession: authored dial-lock rewards (P4)"
        puzzle = next(p for p in data['puzzles'] if p['id'] == 'P4')
        puzzle['kind'] = 'Bellkeeper dial lock'
        puzzle['needsNote'] = 'the three ordered dial glyphs on the well south wall, read from the Bridge edge'
    limit = {'A': 4, 'B': 8, 'C': 12}[batch]
    data['rooms'] += copy.deepcopy(geometry['localRooms'])
    data['clearanceCuts'] = [copy.deepcopy(c) for c in geometry['clearanceCuts'] if c['areaId'] <= limit]
    data['rampOverrides'] = [copy.deepcopy(r) for r in geometry.get('rampOverrides', []) if r['areaId'] <= limit]
    data['structures'] = [s for s in data['structures'] if s.get('areaId', 0) <= limit]
    for index, prop in enumerate(data['props']):
        prop['id'] = f'legacy-prop-{index:02d}'
    for change in geometry['propChanges']:
        if change['areaId'] > limit:
            continue
        hits = [p for p in data['props'] if p['kind'] == change['kind'] and p['at'] == change['from']]
        assert len(hits) == 1, change
        if change.get('remove'):
            data['props'].remove(hits[0])
        else:
            hits[0].update(copy.deepcopy(change['set']))
    data['twoPlayer'] = copy.deepcopy(geometry['twoPlayer'])
    data['twoPlayer']['structuralGroups'] = [g for g in data['twoPlayer']['structuralGroups'] if g['areaId'] <= limit]
    data['twoPlayer']['authoredBatch'] = batch
    return data


if __name__ == '__main__':
    data = build()
    OUT.write_text(json.dumps(data, indent=1), encoding='utf-8')
    print(f'wrote {OUT.name}: {data["revision"]}, {len(data["nodes"])} nodes, {len(data["links"])} links, '
          f'{len(data["structures"])} structures, {len(data["twoPlayer"]["structuralGroups"])} structural groups')
