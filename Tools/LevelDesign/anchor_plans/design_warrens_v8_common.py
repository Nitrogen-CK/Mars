"""Shared builder for the Warrens v8 layout variants (design_warrens_v8a.py .. v8e.py).

Each variant script declares plain tables (nodes, links, rooms, crawls, ladders, pockets, puzzles, props, lights, and the
v8 annotation layers: instances, views, transitions, landmark, notes) and calls build()/write(). The output is the same
data/warrens*.json schema the 3D viewer (viewer/index.html) and the offline checker read, plus the v8 layers the viewer
learned for this round. Nothing here is live: the builder reads data/warrens.json (v7r1) and these write data/warrens_v8*.json.

Shared vocabulary across every variant (so the resolver's contract is unchanged):
- node 'K' is HOME: the Camp Door (the arrival hall's camp exit), not a kitchen: cooking happens at base camp;
- H1..H3 hunt courts, R1..R7 route gates in one closure group (max 3 closed), S* entrances (player-start tags);
- pocket families F/C/O/T/X/N/P as in v5; pocket ids become Anchor.Mars.Warrens.<CamelCase> tag leaves;
- link kinds: walk, stair (same-level treads or a main->deep dive), spiral, ramp, ladder, lift, drop (ramp and the last
  three are graph-only: the viewer draws their geometry from extraRamps[] / ladders[] / holes[], never from the link;
  use ramp for any stair that crosses into the rafters or out of the undercroft, since the viewer's dive drawing assumes main->deep).
Costs: walk/spiral = polyline length; stair = hypot(run, rise); ladder = run + 3 x rise (climbing at about a third of
walking speed); drop = run (instant, one way); lift = run + 20 m (waiting for the cage).
"""
import json
import math
from pathlib import Path

DATA = Path(__file__).resolve().parent / 'data'
TUNNEL, CORRIDOR = 2.5, 3.0


def pocket_anchor_id(niche_id):
    return ''.join(part[:1].upper() + part[1:] for part in niche_id.split('-'))


def length(pts):
    return sum(math.dist(p[:2], q[:2]) for p, q in zip(pts, pts[1:]))


def build(V):
    """V is the variant module (or any namespace) exposing the tables named below."""
    N = V.NODES
    polyline = lambda a, b, via: [N[a][:2]] + [tuple(p[:2]) for p in via] + [N[b][:2]]
    links = []
    for row in V.LINKS:
        a, b, via, w, kind, closed = row[:6]
        extra = row[6] if len(row) > 6 else {}
        for n in (a, b):
            if n not in N:
                raise SystemExit(f'link {a}-{b}: unknown node {n}')
        run = length(polyline(a, b, via))
        rise = abs(N[a][2] - N[b][2])
        if kind in ('stair', 'spiral', 'ramp'):
            cost = math.hypot(run, rise)
        elif kind == 'ladder':
            cost = run + 3 * rise
        elif kind == 'lift':
            cost = run + 20
        elif kind == 'drop':
            cost = run
        else:
            if rise > 0.01:
                raise SystemExit(f'walk link {a}-{b} changes height ({N[a][2]} -> {N[b][2]}); make it a stair')
            cost = run
        link = dict(a=a, b=b, via=[list(p) for p in via], width=w, kind=kind, closedBy=closed, costCm=int(round(cost * 100)),
                    leverNode=V.LEVER_NODE.get(closed) if closed else None)
        link.update(extra)
        links.append(link)
    # stair slopes: check() reports them against the builder's limits on the ramp as built (a dive <= 18, a stair or flight <= 26.6)
    anchors = []
    for s in V.ENTRANCES:
        anchors.append(dict(id=s, family='S', at=list(N[s][:2]), node=s, note='foyer'))
    for aid, node in V.COURTS.items():
        anchors.append(dict(id=aid, family='H', at=list(N[node][:2]), node=node, note='hunt court'))
    gate_ids = []
    for row in V.LINKS:
        if row[5]:
            if row[5] in gate_ids:
                raise SystemExit(f'gate {row[5]} on two links')
            gate_ids.append(row[5])
            at = V.ANCHOR_AT.get(row[5]) or N[row[0]][:2]
            anchors.append(dict(id=row[5], family='R', at=list(at), node=row[0], note='route gate'))
            lever = V.LEVER_NODE.get(row[5])
            if lever and lever not in (row[0], row[1]):
                raise SystemExit(f'lever node of {row[5]} is not an end of its link')
    niches = []
    for n in V.NICHES:
        d = dict(n, anchorId=pocket_anchor_id(n['id']))
        if n['id'] == 'bellkeeper':  # as v7: the Bellkeeper pays authored rewards; the plan offers no random cache here
            d['authoredReward'] = True
        if 'rect' in d: d['rect'] = list(d['rect'])
        else: d['poly'] = [list(p) for p in d['poly']]
        niches.append(d)
    rooms = []
    for r in V.ROOMS:
        d = dict(r)
        if 'rect' in d: d['rect'] = list(d['rect'])
        else: d['poly'] = [list(p) for p in d['poly']]
        rooms.append(d)
    shape = lambda s: (dict(s, rect=list(s['rect'])) if 'rect' in s else dict(s, poly=[list(p) for p in s['poly']]))
    upper = V.UPPER
    out = dict(
        map='Warrens', revision=V.REVISION, source=V.SOURCE, units='metres; costCm is the walk cost in centimetres', hearth='K',
        footprint=list(V.FOOTPRINT), deep=list(V.DEEP), rampRoofZ=getattr(V, 'RAMP_ROOF_Z', -2.4),
        nodes={k: list(v) for k, v in N.items()}, links=links, rooms=rooms,
        crawls=[dict(c, a=list(c['a']), b=list(c['b'])) for c in V.CRAWLS],
        galleries=[], upper=upper, ladders=[dict(l, at=list(l['at'])) for l in V.LADDERS],
        holes=[shape(h) for h in V.HOLES],
        extraWalks=[dict(w, pts=[list(p) for p in w['pts']]) if 'pts' in w else shape(w) for w in V.EXTRA_WALKS],
        shortcuts=[dict(s, at=list(s['at'])) for s in V.SHORTCUTS], cracks=[],
        pillars=[shape(p) for p in V.PILLARS], lowLinks=[list(l) for l in V.LOW_LINKS], lowRoof=getattr(V, 'LOW_ROOF', 2.2),
        locks=V.LOCKS, puzzles=[dict(p, at=list(p['at']), needsAt=list(p['needsAt'])) for p in V.PUZZLES],
        extraRamps=[dict(r, a=list(r['a']), b=list(r['b'])) for r in V.EXTRA_RAMPS],
        niches=niches, caches=[n['anchorId'] for n in niches if n['family'] == 'C' and not n.get('authoredReward')], maxActiveCaches=getattr(V, 'MAX_ACTIVE_CACHES', 2),
        water=[shape(w) for w in V.WATER],
        props=[dict(p, at=list(p['at']), size=list(p['size'])) for p in V.PROPS],
        lights=[dict(l, at=list(l['at'])) for l in V.LIGHTS],
        groups=[dict(name='Warren', anchorIds=gate_ids, maxClosed=V.MAX_CLOSED)],
        entrances=[dict(anchorId=s, playerStartTag=f'Expedition.Entrance.{s}', node=s) for s in V.ENTRANCES],
        courts=[dict(anchorId=a, node=n) for a, n in V.COURTS.items()],
        anchors=anchors, channels={g: f'Mechanism.Channel.Anchor.Warrens.{g}' for g in gate_ids}, quarryMinWalkCm=5000,
        # v8 layers
        instances=[dict(i, **({'rect': list(i['rect'])} if 'rect' in i else {'poly': [list(p) for p in i['poly']]}),
                        ports=[dict(p, at=list(p['at'])) for p in i.get('ports', [])]) for i in V.INSTANCES],
        views=[dict(v, **{'from': list(v['from']), 'to': list(v['to'])}) for v in V.VIEWS],
        transitions=[dict(t, at=list(t['at'])) for t in V.TRANSITIONS],
        landmark=V.LANDMARK, notes=V.NOTES,
        **({'rampOverrides': [dict(o, link=list(o['link'])) for o in V.RAMP_OVERRIDES]} if hasattr(V, 'RAMP_OVERRIDES') else {}),  # build_warrens: per-dive start / descentEnd / roofZ
        dropGaps=[dict(g, a=list(g['a']), b=list(g['b'])) for g in getattr(V, 'DROP_GAPS', [])],  # build_warrens: a room edge's authored drop at z (optional landing {rect, z})
        windows=[dict(w, a=list(w['a']), b=list(w['b'])) for w in getattr(V, 'WINDOWS', [])],  # build_warrens: {id, a, b, sill, head}: wall boxes cut between sill and head
        movementChecks=True,  # build_warrens: the P5 manifest checks (chef step 0.45, 2 m clear height, drops, views, slopes, props)
        capWadeDepth=True,  # build_warrens: a wading pool (depth <= 1 m) is sunk at most 0.4 m, so its banks are steps
        deepLowRoofFollowsFloor=True,  # build_warrens: a deep low tunnel's lintel stops under a main floor above it (the Undercroft under the Pump Room)
        railLedges=True,  # build_warrens: a walkable edge dropping more than 2 m gets a rail, ledgeRail high (rail gaps, flight heads, tunnel mouths excepted)
        **({'ledgeRail': V.LEDGE_RAIL} if hasattr(V, 'LEDGE_RAIL') else {}),  # build_warrens: the ledge rail height (default 1 m)
        **({'deepWaterRail': V.DEEP_WATER_RAIL} if hasattr(V, 'DEEP_WATER_RAIL') else {}),  # build_warrens: the deep-water rail height (default ledgeRail)
        flightMouthsOpen=True,  # build_warrens: no gallery rail across a flight's head where it meets an upper floor
    )
    # Optional authored encounters stay local to the declaring variant.
    for attr, key in (('BELLKEEPER', 'bellkeeper'), ('LOCAL_FIXTURES', 'localFixtures'),
                      ('ENTRY_KIT_TOOLS', 'entryKitTools'), ('ENTRY_KIT_LIGHT', 'entryKitLight'),
                      ('SECTION_OVERRIDES', 'sectionOverrides'), ('PLACED_PICKUP_STARTUP', 'placedPickupStartup')):
        if hasattr(V, attr):
            out[key] = getattr(V, attr)
    check(out)
    return out


def check(d):
    """Cheap structural checks before the viewer sees the file (the viewer's metrics do the closure enumeration)."""
    N = d['nodes']
    deg = {}
    for l in d['links']:
        deg[l['a']] = deg.get(l['a'], 0) + 1; deg[l['b']] = deg.get(l['b'], 0) + 1
    for k in N:
        if k not in deg:
            raise SystemExit(f'node {k} has no link')
    for s in d['entrances']:
        if s['node'] not in N: raise SystemExit(f'entrance {s} off the graph')
    if 'K' not in N: raise SystemExit('no K (the Camp Door / home node)')
    # every entrance reaches every court and K with everything open
    adj = {}
    for l in d['links']:
        adj.setdefault(l['a'], []).append(l['b']); adj.setdefault(l['b'], []).append(l['a'])
    def reach(src):
        seen = {src}; stack = [src]
        while stack:
            u = stack.pop()
            for v in adj.get(u, []):
                if v not in seen: seen.add(v); stack.append(v)
        return seen
    targets = ['K'] + [c['node'] for c in d['courts']]
    for e in d['entrances']:
        r = reach(e['node'])
        missing = [t for t in targets if t not in r]
        if missing: raise SystemExit(f"{e['anchorId']} cannot reach {missing}")
    # closure sets: every entrance reaches every target under every legal closure (cap from the group)
    group = d['groups'][0]; ids = group['anchorIds']; cap = group['maxClosed']
    from itertools import combinations
    bad = []
    for k in range(cap + 1):
        for closed in combinations(ids, k):
            adj2 = {}
            for l in d['links']:
                if l['closedBy'] in closed: continue
                adj2.setdefault(l['a'], []).append(l['b']); adj2.setdefault(l['b'], []).append(l['a'])
            for e in d['entrances']:
                seen = {e['node']}; stack = [e['node']]
                while stack:
                    u = stack.pop()
                    for v in adj2.get(u, []):
                        if v not in seen: seen.add(v); stack.append(v)
                if any(t not in seen for t in targets):
                    bad.append((closed, e['anchorId'])); break
    if bad:
        raise SystemExit(f'{len(bad)} closure sets strand an entrance, e.g. {bad[:4]}')
    # slopes, mirrored from the builder (same functions, same limits, measured on the ramp as built): reported, not fatal
    import build_warrens as bw
    slopes = bw.slope_errors(d)
    for e in slopes:
        print('slope error (build_warrens slopeErrors):', e)
    d['_checks'] = dict(closureSetsChecked=sum(math.comb(len(ids), k) for k in range(cap + 1)), stranded=0, slopeErrors=slopes,
                        slopeLimits=dict(dive=bw.DIVE_MAX, stair=bw.STAIR_MAX))


def write(V):
    data = build(V)
    out = DATA / f'warrens_{V.FILE}.json'
    out.write_text(json.dumps(data, indent=1), encoding='utf-8')
    m = data
    print(f"wrote {out.name} ({m['revision']}): {len(m['nodes'])} nodes, {len(m['links'])} links, {len(m['rooms'])} rooms, "
          f"{len(m['niches'])} pockets, {len(m['puzzles'])} puzzles, {len(m['instances'])} instances, {len(m['views'])} views, "
          f"{len(m['transitions'])} beats; closure sets checked {m['_checks']['closureSetsChecked']}, stranded 0")
    return data
