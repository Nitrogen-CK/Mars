"""Static spatial contracts for Warrens v7; this never claims physical traversal.

Default: validate the emitted live JSON. --preview builds v7 in memory. Negative
checks mutate independent in-memory data/manifests, never source or live files.
"""
import argparse
import copy
import heapq
import itertools
import json
import math
from collections import deque
from pathlib import Path

import build_warrens as builder
import design_warrens_v6 as v6
import design_warrens_v7 as v7

EPSILON = 0.005
ERROR_ARRAYS = ('gateLeaks', 'walkBreaks', 'ladderErrors', 'capErrors', 'connectorErrors')
PRESERVED = ('nodes', 'links', 'footprint', 'groups', 'entrances', 'courts', 'puzzles', 'channels', 'caches',
             'maxActiveCaches', 'locks', 'ladders', 'upper', 'holes', 'extraWalks', 'crawls', 'quarryMinWalkCm')


def axes(box):
    angle = math.radians(box['yaw'])
    return (math.cos(angle), math.sin(angle)), (-math.sin(angle), math.cos(angle))


def contains_xy(box, point, margin=0):
    u, v = axes(box)
    dx, dy = point[0] - box['centre'][0], point[1] - box['centre'][1]
    return abs(dx*u[0] + dy*u[1]) <= box['size'][0]/2 + margin and \
        abs(dx*v[0] + dy*v[1]) <= box['size'][1]/2 + margin


def overlaps_rect(box, rect):
    """Exact separating-axis overlap for an axis-aligned reservation and yaw box."""
    u, v = axes(box)
    hx, hy = box['size'][0]/2, box['size'][1]/2
    ex, ey = (rect[2]-rect[0])/2, (rect[3]-rect[1])/2
    dx, dy = box['centre'][0]-(rect[0]+rect[2])/2, box['centre'][1]-(rect[1]+rect[3])/2
    return all(abs(dx*x + dy*y) < ex*abs(x) + ey*abs(y) +
               hx*abs(u[0]*x + u[1]*y) + hy*abs(v[0]*x + v[1]*y) - EPSILON
               for x, y in ((1, 0), (0, 1), u, v))


def intrudes(box, rect, low, high):
    # Pitched raster ramps are not vertical obstacles; new authored pieces have
    # no pitch. Their support/continuity remains the builder's tread contract.
    if abs(box.get('pitch', 0)) > EPSILON or box['kind'] in ('water', 'inlay'):
        return False
    bottom, top = box['centre'][2]-box['size'][2]/2, box['centre'][2]+box['size'][2]/2
    return top > low + EPSILON and bottom < high - EPSILON and overlaps_rect(box, rect)


def floor_hits_standing_capsule(box, feet, radius=.39, height=2.2):
    """Measured chef radius with conservative 2.2m headroom and rounded foot.

    A square reservation incorrectly treats a neighbouring floor at the ramp
    mouth as a shin-height wall. Distance to the vertical capsule segment keeps
    real floor/ceiling contacts without deleting the inherited slab regression.
    """
    u,v=axes(box); delta=[feet[i]-box['centre'][i] for i in range(2)]
    dx=max(0,abs(sum(delta[i]*u[i] for i in range(2)))-box['size'][0]/2)
    dy=max(0,abs(sum(delta[i]*v[i] for i in range(2)))-box['size'][1]/2)
    low,high=box['centre'][2]-box['size'][2]/2,box['centre'][2]+box['size'][2]/2
    dz=max(0,low-(feet[2]+height-radius),feet[2]+radius-high)
    return dx*dx+dy*dy+dz*dz < (radius-EPSILON)**2


def ramp_mouth_contact_feet(boxes, ideal, radius=.39):
    """A rounded capsule rides the floor lip before following the ramp plane.

    Allow only an ordinary <=0.35m ground contact. A slab over the descending
    player cannot qualify; check overhead clearance from the raised contact.
    """
    result=ideal[:]
    for box in boxes:
        if box['kind']!='floor' or box.get('pitch'):
            continue
        u,v=axes(box); delta=[ideal[i]-box['centre'][i] for i in range(2)]
        dx=max(0,abs(sum(delta[i]*u[i] for i in range(2)))-box['size'][0]/2)
        dy=max(0,abs(sum(delta[i]*v[i] for i in range(2)))-box['size'][1]/2)
        if dx*dx+dy*dy >= radius*radius:
            continue
        top=box['centre'][2]+box['size'][2]/2
        contact=top-radius+math.sqrt(radius*radius-dx*dx-dy*dy)
        if ideal[2] <= contact <= ideal[2]+.35:
            result[2]=max(result[2],contact)
    return result


def samples(rect, step=.2):
    nx, ny = max(1, math.ceil((rect[2]-rect[0])/step)), max(1, math.ceil((rect[3]-rect[1])/step))
    return [(rect[0]+.01+(rect[2]-rect[0]-.02)*i/nx,
             rect[1]+.01+(rect[3]-rect[1]-.02)*j/ny) for i in range(nx+1) for j in range(ny+1)]


def support_failures(boxes, rect, z):
    support = [b for b in boxes if b['kind'] in ('floor', 'gallery', 'ramp') and abs(b.get('pitch', 0)) < EPSILON
               and abs(b['centre'][2]+b['size'][2]/2-z) < .025 and overlaps_rect(b, rect)]
    return [p for p in samples(rect) if not any(contains_xy(b, p) for b in support)]


def ray_hit(box, start, end):
    """Segment vs yaw box using slab intervals; includes NoCollision silhouettes."""
    u, v = axes(box)
    def local(p):
        dx, dy = p[0]-box['centre'][0], p[1]-box['centre'][1]
        return [dx*u[0]+dy*u[1], dx*v[0]+dy*v[1], p[2]-box['centre'][2]]
    a, b = local(start), local(end)
    first, last = .002, .998
    for i in range(3):
        half = box['size'][i]/2
        delta = b[i]-a[i]
        if abs(delta) < 1e-9:
            if abs(a[i]) > half:
                return False
        else:
            lo, hi = sorted(((-half-a[i])/delta, (half-a[i])/delta))
            first, last = max(first, lo), min(last, hi)
            if first > last:
                return False
    return True


def graph_cases(data):
    group = data['groups'][0]
    cases, failures = 0, []
    for count in range(group['maxClosed']+1):
        for closed in itertools.combinations(group['anchorIds'], count):
            adjacent = {n: [] for n in data['nodes']}
            for edge in data['links']:
                if edge.get('closedBy') not in closed:
                    adjacent[edge['a']].append((edge['b'], edge['costCm']))
                    adjacent[edge['b']].append((edge['a'], edge['costCm']))
            for entrance in data['entrances']:
                distance, queue = {entrance['node']: 0}, [(0, entrance['node'])]
                while queue:
                    cost, node = heapq.heappop(queue)
                    if cost != distance[node]:
                        continue
                    for nxt, weight in adjacent[node]:
                        proposed = cost+weight
                        if proposed < distance.get(nxt, float('inf')):
                            distance[nxt] = proposed
                            heapq.heappush(queue, (proposed, nxt))
                cases += 1
                missing = sorted(set(adjacent)-set(distance))
                eligible = any(distance.get(c['node'], -1) >= data['quarryMinWalkCm'] for c in data['courts'])
                if missing or not eligible:
                    failures.append(dict(closed=closed, entrance=entrance['node'], missing=missing, eligible=eligible))
    return dict(cases=cases, failures=failures)


def delta_boxes(data, manifest):
    ids = {s['id'] for s in data['structures'] if 'areaId' in s}
    original = v6.build()['props']
    for p in data['props']:
        if p.get('id', '').startswith('legacy-prop-'):
            old = original[int(p['id'].split('-')[-1])]
            if any(p.get(k) != old.get(k) for k in ('at', 'size', 'yaw')):
                ids.add(p['id'])
    return [b for b in manifest['boxes'] if b.get('sourceId') in ids]


def recovery_overlap(box, rect, low, high):
    """Exact SAT for a yaw/pitch emitted box and an upright clearance volume."""
    if not box.get('pitch', 0):
        return intrudes(box,rect,low,high)
    yaw, pitch = math.radians(box['yaw']), math.radians(box.get('pitch', 0))
    cy, sy, cp, sp = math.cos(yaw), math.sin(yaw), math.cos(pitch), math.sin(pitch)
    local = ((cy*cp, sy*cp, sp), (-sy, cy, 0), (-cy*sp, -sy*sp, cp))
    world = ((1,0,0), (0,1,0), (0,0,1))
    centre = ((rect[0]+rect[2])/2, (rect[1]+rect[3])/2, (low+high)/2)
    extent = ((rect[2]-rect[0])/2, (rect[3]-rect[1])/2, (high-low)/2)
    half = [s/2 for s in box['size']]
    delta = [box['centre'][i]-centre[i] for i in range(3)]
    dot = lambda a,b: sum(x*y for x,y in zip(a,b))
    cross = lambda a,b: (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
    for axis in world + local + tuple(cross(a,b) for a in world for b in local):
        length = math.sqrt(dot(axis,axis))
        if length < 1e-9:
            continue
        radius = sum(extent[i]*abs(axis[i]) for i in range(3)) + sum(half[i]*abs(dot(axis,local[i])) for i in range(3))
        if abs(dot(delta,axis)) >= radius-EPSILON*length:
            return False
    return True


def recovery_connected(data, raster, drop, boxes):
    """Check emitted support and blocking geometry along the recorded recovery.

    Uses the measured 0.39 m chef radius and the authored clearance height.
    The roof recovery's recorded 1.45 m descent is allowed only downward; the
    ordinary 0.35 m step bound remains. Physical falls/items still need play.
    """
    grid = raster[builder.level_of_z(drop['exitPlanM'][2], data.get('upper'))]
    rect = drop['landingRectPlanM']
    start_xy = ((rect[0]+rect[2])/2, (rect[1]+rect[3])/2)
    start = grid.cell_of(start_xy)
    goal = grid.cell_of(drop['exitPlanM'][:2])
    walkable = ('floor', 'grate', 'tread', 'low')
    solids = [b for b in boxes if b['kind'] not in ('water','inlay','dressing')]
    supports = [b for b in solids if b['kind'] in ('floor','gallery','ramp') and abs(b.get('pitch',0)) < EPSILON]
    radius, height = .39, data['twoPlayer']['clearHeightM']
    def supported(point,z):
        return any(abs(b['centre'][2]+b['size'][2]/2-z) < .025 and contains_xy(b,point) for b in supports)
    def obstructed(point,z):
        r = [point[0]-radius,point[1]-radius,point[0]+radius,point[1]+radius]
        return [b.get('sourceId',f'box:{i}') for i,b in enumerate(solids) if recovery_overlap(b,r,z+.035,z+height)]
    for label,point,z in [('start',start_xy,drop['floorZ']),('goal',drop['exitPlanM'][:2],drop['exitPlanM'][2])]:
        if grid.at(point) not in walkable or not supported(point,z):
            return dict(connected=False,reason=label+' has no emitted support',at=[*point,z])
        blocked = obstructed(point,z)
        if blocked:
            return dict(connected=False,reason=label+' is obstructed',at=[*point,z],geometryIds=blocked)
    cache = {}
    def node(cell):
        if cell not in cache:
            if grid.get(*cell) not in walkable:
                cache[cell] = None
            else:
                point = grid.centre(*cell)
                z = grid.zf[cell[1]][cell[0]]
                if drop['floorZ'] > z and supported(point,drop['floorZ']):
                    z = drop['floorZ']
                cache[cell] = z if supported(point,z) and not obstructed(point,z) else None
        return cache[cell]
    if node(start) is None or node(goal) is None:
        return dict(connected=False,reason='endpoint raster cell lacks emitted clearance/support')
    max_descent = max(.35,drop['floorZ']-drop['exitPlanM'][2])
    visited, queue = {start}, deque([start])
    while queue:
        cell = queue.popleft()
        if cell == goal:
            return dict(connected=True,visitedCells=len(visited))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nxt = cell[0]+dx, cell[1]+dy
            if nxt in visited or node(nxt) is None:
                continue
            if node(nxt)-node(cell) > .35 or node(cell)-node(nxt) > max_descent:
                continue
            visited.add(nxt)
            queue.append(nxt)
    return dict(connected=False,reason='emitted solids disconnect recovery floor',visitedCells=len(visited))


def validate(data, manifest_override=None):
    # Frozen authoring tables contain tuples; JSON stores the same ordered
    # values as lists. Compare both in their serialized representation.
    original = json.loads(json.dumps(v6.build()))
    if 'bellkeeper' in data:
        original['caches'].remove('Bellkeeper')
        p4 = next(p for p in original['puzzles'] if p['id'] == 'P4')
        p4['kind'] = 'Bellkeeper dial lock'
        p4['needsNote'] = 'the three ordered dial glyphs on the well south wall, read from the Bridge edge'
    protected = json.loads(json.dumps({key: data[key] for key in PRESERVED}))
    manifest, summary = builder.manifest(write=False, data=data)
    if manifest_override is not None:
        manifest = manifest_override
    boxes = manifest['boxes']
    added = delta_boxes(data, manifest)
    meta = data['twoPlayer']
    limit = {'A': 4, 'B': 8, 'C': 12}[meta['authoredBatch']]
    checks = []
    def check(id, failures, **details):
        checks.append(dict(id=id, passed=not failures, failures=failures, **details))
    check('source:revision', [] if data['revision'] == 'v7r1' else [data['revision']])
    for key in PRESERVED:
        check('preserved:'+key, [] if protected[key] == original[key] else ['differs from frozen v6'])
    if 'bellkeeper' in data:
        encounter = data['bellkeeper']
        panel = next(e for e in manifest['entities'] if e['cls'] == 'Mars_Bellkeeper_EntityScript')
        clue = next(e for e in manifest['entities'] if e['cls'] == 'Mars_BellkeeperClue_EntityScript')
        expected = [dict(enum='EMars_Bellkeeper_Glyph', value=g) for g in encounter['phrase']]
        check('P4:one-phrase', [] if panel['props']['Phrase']['array'] == clue['props']['Phrase']['array'] == expected
              and all(a != b for a, b in zip(encounter['phrase'], encounter['startGlyphs'])) else ['phrase/start mismatch'])
        cache_entities = [e for e in manifest['entities'] if e['cls'] == 'Mars_Anchor_Cache_EntityScript']
        check('P4:cache-budget', [] if data['caches'] == ['Mourner','SealedBurial','Porter'] and data['maxActiveCaches'] == 2
              and len(cache_entities) == 3 else ['expected three random cache anchors / maxActive2'])
        for name, rect in [('landing', encounter['vent']['landingRectPlanM']), ('partner-stage', encounter['partnerStageRectPlanM'])]:
            check('P4:support:'+name, support_failures(boxes, rect, 0))
            check('P4:clear:'+name, [b.get('sourceId', f'box:{i}') for i,b in enumerate(boxes) if intrudes(b,rect,.035,2.1)])
        sweep = encounter['vent']['loadedSweep']
        failures = []
        for index in range(25):
            t = index / 24
            x,y,z = [a*(1-t)+b*t for a,b in zip(sweep['startPlanM'],sweep['endPlanM'])]
            radius = sweep['radiusM']
            rect = [x-radius,y-radius,x+radius,y+radius]
            failures += support_failures(boxes,rect,z)
            failures += [b.get('sourceId',f'box:{i}') for i,b in enumerate(boxes) if intrudes(b,rect,z+.035,z+sweep['heightM'])]
        check('P4:static-loaded-sweep', failures, samples=25, limitation='reservation, not actual movement/trajectory')
    graph = graph_cases(data)
    check('graph:320', graph['failures'] if graph['cases'] == 320 else ['wrong case count'], cases=graph['cases'])
    for key in ERROR_ARRAYS:
        check('builder:'+key, summary[key])
    for reservation in meta['clearRectangles']:
        if reservation['id'] == 'P2-south' and limit < 9:
            continue
        rect, z = reservation['rectPlanM'], reservation['floorZ']
        check('support:'+reservation['id'], support_failures(boxes, rect, z))
        check('clear:'+reservation['id'], [b.get('sourceId', f'box:{i}') for i, b in enumerate(boxes)
              if intrudes(b, rect, z+.035, z+meta['clearHeightM'])])
    for port in data['openings']:
        if port['kind'] != 'wall' or not port.get('traversable'):
            continue
        x, y, z = port['at']
        half = port['width']/2
        rect = [x-.3, y-half, x+.3, y+half] if port['axis'] == 'x' else [x-half, y-.3, x+half, y+.3]
        check('port:'+port['id'], [b.get('sourceId', f'box:{i}') for i, b in enumerate(boxes)
              if intrudes(b, rect, z+.035, z+port['height'])])
    for mouth in builder.gated_mouths(data):
        if mouth['id'] == 'P2' and limit < 9:
            continue  # the existing cell-aligned throat is corrected in batch C
        x, y = mouth['at']
        rect = [x-1, y-.3, x+1, y+.3] if mouth['axis'] == 'x' else [x-.3, y-1, x+.3, y+1]
        check('gate:'+mouth['id'], [b.get('sourceId', f'box:{i}') for i, b in enumerate(boxes)
              if intrudes(b, rect, mouth['z']+.035, mouth['z']+2.2)])
    for ladder in meta['ladderReservations']:
        x, y, z = ladder['framePlanM']
        top = z+ladder['heightMetres']
        for label, rect, low, high in [('mount', ladder['frontMountRectPlanM'], z+.035, z+2.2),
                                      ('shaft', ladder['shaftRectPlanM'], z+.1, top+1.5),
                                      ('top-approach', ladder['topApproachRectPlanM'], top+.035, top+2.2)]:
            check('ladder:'+ladder['ladder']+':'+label, [b.get('sourceId', f'box:{i}') for i, b in enumerate(boxes)
                  if intrudes(b, rect, low, high)])
        ex, ey, ez = ladder['topExitFeetPlanM']
        check('ladder:'+ladder['ladder']+':exit-support', support_failures(boxes, [ex-.1, ey-.1, ex+.1, ey+.1], ez))
    for station in meta['stationReservations']:
        x, y, z = station['positionPlanM']
        rect = [x-.4, y-.8, x+.4, y+.8]
        for label, r, low, high in [('table', rect, z, z+2.22),
                                   ('operator', station['transverseWorkRectPlanM'], z, z+2.2)]:
            check('station:'+station['id']+':'+label, [b['sourceId'] for b in added if intrudes(b, r, low, high)])
        eye = station['cameraPlanM']
        check('station:'+station['id']+':camera', [b['sourceId'] for b in added if ray_hit(b, eye, [x, y, z+.75])])
    check('kitchen:transit', [b['sourceId'] for b in added if intrudes(b, meta['kitchenTransit']['rectPlanM'], .035, 2.2)])
    # A 1.4 m moving envelope preserves single-file loaded travel. The separate
    # 2.4 m reservations are the passing promise; route centre lines are frozen.
    path_failures = []
    for link in data['links']:
        if link['kind'] == 'spiral':
            connector = next(c for c in data['connectors'] if c['id'] == link['connector'])
            points = connector['points']
        elif any(o['link'] == [link['a'],link['b']] for o in data.get('rampOverrides', [])):
            r=next(r for r in builder.ramps_of(data) if r['link'] == link)
            points=[[*r['upper'],r['top']],[*r['start'],r['top']],
                    [*r['descent_end'],r['bottom']],[*r['end'],r['bottom']]]
        else:
            points = [[p[0], p[1], builder.z_on_link(data, link, p)] for p in builder.polyline(data, link)]
        for a, b in zip(points, points[1:]):
            count = max(1, math.ceil(math.dist(a, b)/.25))
            for k in range(count+1):
                p = [a[i]+(b[i]-a[i])*k/count for i in range(3)]
                rect = [p[0]-.7, p[1]-.7, p[0]+.7, p[1]+.7]
                for obstacle in added:
                    if intrudes(obstacle, rect, p[2]+.035, p[2]+2.2):
                        path_failures.append(dict(link=link['a']+'-'+link['b'], at=p, geometryId=obstacle['sourceId']))
    check('paths:loaded-envelope', path_failures)
    # This inherited diagonal dive crossed raster rock even when all newly
    # authored solids were clear. Check the emitted rock, not only v7 additions.
    ramp_failures = []
    dive = next(r for r in builder.ramps_of(data) if [r['link']['a'],r['link']['b']] == ['ci1','dg'])
    points = [[*dive['start'],dive['top']],[*dive['descent_end'],dive['bottom']],[*dive['end'],dive['bottom']]]
    for a,b in zip(points,points[1:]):
        for i in range(41):
            p = [a[k]+(b[k]-a[k])*i/40 for k in range(3)]
            p = ramp_mouth_contact_feet(boxes,p)
            rect = [p[0]-.7,p[1]-.7,p[0]+.7,p[1]+.7]
            for obstacle in boxes:
                collision = floor_hits_standing_capsule(obstacle,p) if obstacle['kind']=='floor' else intrudes(obstacle,rect,p[2]+.035,p[2]+2.2)
                if obstacle['kind'] not in ('ramp','water','inlay','dressing') and collision:
                    ramp_failures.append(dict(at=p,geometryId=obstacle.get('sourceId'),box=obstacle))
    check('ramp:cistern-dive:loaded-rock-clear', ramp_failures)
    upper_support, upper_clear = [], []
    for ends in [('PU','CI'),('PU','p1')]:
        link = next(l for l in data['links'] if (l['a'],l['b']) == ends)
        for a,b in zip(builder.polyline(data,link),builder.polyline(data,link)[1:]):
            count=max(1,math.ceil(math.dist(a,b)/.1)); dx,dy=b[0]-a[0],b[1]-a[1]; length=math.hypot(dx,dy)
            for i in range(count+1):
                p=[a[k]+(b[k]-a[k])*i/count for k in range(2)]
                for side in (-.58,0,.58):
                    q=[p[0]-dy/length*side,p[1]+dx/length*side]
                    if not any(o['kind'] in ('floor','gallery') and not o.get('pitch') and
                               abs(o['centre'][2]+o['size'][2]/2+2.5)<.025 and contains_xy(o,q) for o in boxes):
                        upper_support.append(dict(link=ends,at=q))
                rect=[p[0]-.39,p[1]-.39,p[0]+.39,p[1]+.39]
                upper_clear += [dict(link=ends,at=p,box=o) for o in boxes if o['kind'] not in ('water','inlay','dressing') and intrudes(o,rect,-2.465,-.3)]
    check('crossing:upper-routes-support',upper_support)
    check('crossing:upper-routes-clear',upper_clear)
    groups = meta['structuralGroups']
    check('groups:all', [] if {g['areaId'] for g in groups} == set(range(1, limit+1)) else ['missing area IDs'])
    emitted_ids = {b.get('sourceId') for b in boxes}
    for group in groups:
        check('group:'+str(group['areaId']), [id for id in group['geometryIds'] if id not in emitted_ids])
    rays = [('well-rim', [50.6,41.8,1.35], [60,44,-3.8]),
            ('well-bridge', [60,54,3.85], [60,44,-3.8]),
            ('well-gallery', [50,49,6.35], [60,44,-3.8]),
            ('well-pit', [60,44,-3.65], [60,44,7.5]),
            ('bridge-clue-reader', [58.2,54.8,3.85], [60,38.25,-1.2]),
            ('bridge-clue-partner', [59.4,54.8,3.85], [60,38.25,-1.2])]
    for id, start, end in rays:
        check('view:'+id, [b['sourceId'] for b in added if ray_hit(b, start, end)])
    raster = builder.rasterize(data)
    expected_drops = {g['id'] for g in data['upper']['railGaps']} | {'overlook-floor-break', 'roof-recovery-ledge'}
    check('drops:coverage', [] if {d['source'] for d in meta['drops']} == expected_drops else ['missing authored drop'])
    for drop in meta['drops']:
        rect, z = drop['landingRectPlanM'], drop['floorZ']
        check('drop:'+drop['id']+':support', support_failures(boxes, rect, z))
        check('drop:'+drop['id']+':clear', [b.get('sourceId', f'box:{i}') for i, b in enumerate(boxes)
              if intrudes(b, rect, z+.035, z+2.2)])
        recovery = recovery_connected(data,raster,drop,boxes)
        check('drop:'+drop['id']+':recovery', [] if recovery['connected'] else [recovery])
        eye = [*drop['fromPlanM'][:2], drop['fromPlanM'][2]+1.35]
        target = [*drop['exitPlanM'][:2], drop['exitPlanM'][2]+.6]
        landing = [(rect[0]+rect[2])/2, (rect[1]+rect[3])/2, z+.1]
        check('drop:'+drop['id']+':visible-exit', [b['sourceId'] for b in added if ray_hit(b, eye, target) or ray_hit(b, eye, landing)])
    return dict(mode='static', revision=data['revision'], passed=all(c['passed'] for c in checks),
                checks=checks, summary=summary, graph=graph,
                limitation='No runtime collision, worn/filled pack, item drop simulation, input or two-person gameplay proof.')


def negative_checks(data):
    records = []
    for id, expected in [('obstruct-PK', 'clear:PK-east'), ('remove-closet-support', 'support:closet-top-wait'),
                         ('obstruct-required-path', 'paths:loaded-envelope'),
                         ('enclose-inspection-recovery', 'drop:inspection-opening:recovery'),
                         ('restore-dive-rock', 'ramp:cistern-dive:loaded-rock-clear')]:
        changed = copy.deepcopy(data)
        manifest, _ = builder.manifest(write=False, data=changed)
        if id == 'restore-dive-rock':
            changed['rampOverrides'] = []
            manifest, _ = builder.manifest(write=False, data=changed)
        elif id == 'remove-closet-support':
            rect = next(r['rectPlanM'] for r in changed['twoPlayer']['clearRectangles'] if r['id'] == 'closet-top-wait')
            manifest['boxes'] = [b for b in manifest['boxes'] if not (b['kind'] in ('floor','gallery') and
                abs(b['centre'][2]+b['size'][2]/2) < .025 and overlaps_rect(b, rect))]
        elif id == 'enclose-inspection-recovery':
            for side,at,size in [('W',[-2.31,19.7,-2.5],[.2,1.8,.8]),('E',[-.69,19.7,-2.5],[.2,1.8,.8]),
                                 ('S',[-1.5,18.89,-2.5],[1.8,.2,.8]),('N',[-1.5,20.51,-2.5],[1.8,.2,.8])]:
                changed['structures'].append(dict(id='AUDIT-recovery-ring-'+side,kind='beam',at=at,size=size,
                                                 yaw=0,collision=True,areaId=10))
            manifest, _ = builder.manifest(write=False,data=changed)
        else:
            at = [47,44,0] if id == 'obstruct-PK' else [47,41,0]
            mutation = dict(id='NEGATIVE-'+id, kind='beam', at=at, size=[2.4,1,2], yaw=0,
                            collision=True, areaId=1, role='negative')
            changed['structures'].append(mutation)
            manifest, _ = builder.manifest(write=False, data=changed)
        result = validate(changed, manifest)
        failed = [c['id'] for c in result['checks'] if not c['passed']]
        records.append(dict(id=id, expectedCheck=expected, rejected=expected in failed, failedChecks=failed))
    return records


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preview', action='store_true')
    parser.add_argument('--negative-checks', action='store_true')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    data = v7.build() if args.preview else builder.load()
    result = validate(data)
    if args.preview:
        serialized = validate(json.loads(json.dumps(data)))
        result['serializedPreview'] = dict(passed=serialized['passed'],
            failedChecks=[c['id'] for c in serialized['checks'] if not c['passed']])
        result['passed'] &= serialized['passed']
    if args.negative_checks:
        result['negativeChecks'] = negative_checks(data)
        result['passed'] &= all(n['rejected'] for n in result['negativeChecks'])
    if args.output:
        args.output.write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k not in ('checks','summary')}, separators=(',',':')))
    for check in result['checks']:
        print(('PASS ' if check['passed'] else 'FAIL ')+check['id']+
              ('' if check['passed'] else ': '+json.dumps(check['failures'][:8])))
    raise SystemExit(0 if result['passed'] else 1)
