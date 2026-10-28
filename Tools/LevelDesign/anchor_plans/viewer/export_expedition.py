"""Build the offline expedition concept atlas using the existing Warrens manifest.

Only viewer output is written. Scenario placement and camp/district connections
are design annotations; no Unreal assets or canonical layout data are modified.
"""
import argparse
import hashlib
import heapq
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(HERE.parent))
import build_warrens


def graph_path(source, start, end, closed):
    """Return existing graph edges, oriented with their full authored polylines."""
    heap = [(0, start)]
    costs = {start: 0}
    previous = {}
    while heap:
        cost, node = heapq.heappop(heap)
        if cost != costs[node]:
            continue
        if node == end:
            break
        for link in source['links']:
            if link.get('closedBy') in closed:
                continue
            other = link['b'] if link['a'] == node else link['a'] if link['b'] == node else None
            if other is None:
                continue
            candidate = cost + link['costCm']
            if candidate < costs.get(other, float('inf')):
                costs[other] = candidate
                previous[other] = (node, link)
                heapq.heappush(heap, (candidate, other))
    assert end in costs, f'No authored graph path: {start} -> {end} under {closed}'
    edges = []
    node = end
    while node != start:
        parent, link = previous[node]
        edges.append((parent, node, link))
        node = parent
    edges.reverse()
    points = []
    node_ids = [start]
    for a, b, link in edges:
        raw = [source['nodes'][link['a']], *link['via'], source['nodes'][link['b']]]
        # Height interpolation is illustrative between graph endpoints; use the
        # explicit spiral curve rather than drawing a straight diagonal staircase.
        if link['kind'] == 'spiral':
            raw = next(c['points'] for c in source['connectors'] if c['id'] == 'service-spiral')
            if link['a'] == 'sp1':
                raw = list(reversed(raw))
        if a != link['a']:
            raw = list(reversed(raw))
        z0, z1 = source['nodes'][a][2], source['nodes'][b][2]
        part = [[v[0], v[1], v[2] if len(v) > 2 else z0 + (z1-z0)*i/(len(raw)-1)] for i, v in enumerate(raw)]
        points.extend(part if not points else part[1:])
        node_ids.append(b)
    if not points:
        points = [source['nodes'][start]]
    return dict(kind='graph', label=f'{start} → {end}: authored graph', nodeIds=node_ids,
                points=points, costMetres=costs[end]/100,
                boundary='Existing route graph only; no item-lock, collision or travel-time simulation.')


def proposal(source):
    site = lambda ident, label, at, room, kind: dict(id=ident, label=label, at=at, position=at,
                                                    roomId=room, kind=kind, status='Proposed assignment')
    bonus = site('mushroom', 'Optional mushroom garnish', [-12.3, 15.5, -2.5], 'root-grotto', 'bonus')
    bonus['status'] = 'Existing mushroom-bed location; proposed recipe bonus'
    scenarios = []
    definitions = [
        ('deep-supper', 'Deep Supper', 'A / 017', 'S3', 'H2', 'lair', 'S1', ['R7'], 'SL',
         'Brine jars have collected in the Pit. The direct Well descent is closed; inspect the Chime-side approach.',
         ['CE', 'SL']),
        ('court-delivery', 'The Long Delivery', 'B / 042', 'S1', 'H1', 'court-pit', 'S4', ['R6'], 'CI',
         'A broken pantry shipment occupies the Court. The direct Court/Cistern link is closed; the service spiral offers a distinct loaded alternative.',
         ['CI', 'PU']),
        ('across-well', 'Across the Well', 'C / 108', 'S4', 'CH', 'chime', 'S3', ['R3'], 'PU',
         'The target occupies a Chime Hall storage alcove. Salt Cellar access is interrupted, so compare the Well-rim and eastern descent approaches.',
         ['PU', 'CI'])]
    for ident, title, seed, entry, target, room, exit_node, closed, seasoning, description, forage_nodes in definitions:
        hunt = site('hunt', 'Pickle Mimic / preserved Brined Dill Heart', source['nodes'][target], room, 'target')
        hunt['nodeId'] = target
        forage = [site('seasoning-'+n, 'Common cave seasoning · source '+str(i+1), source['nodes'][n],
                       {'CI':'cistern','PU':'pump','SL':'sluice','CE':'cellar'}[n], 'seasoning')
                  for i, n in enumerate(forage_nodes)]
        entry_site = site('entry', 'Arrival boundary '+entry, source['nodes'][entry], '', 'arrival')
        exit_site = site('exit', 'Return boundary '+exit_node, source['nodes'][exit_node], '', 'return')
        approach = [graph_path(source, entry, seasoning, closed), graph_path(source, seasoning, target, closed)]
        optional = [graph_path(source, target, 'gE', closed)]
        optional.append(dict(kind='schematic', label='Inspect the mushroom shelf',
                             points=[source['nodes']['gE'], bonus['at']],
                             boundary='Within-room inspection annotation, not a validated walking trajectory.'))
        direct_return = graph_path(source, target, exit_node, closed)
        return_paths = [direct_return]
        return_note = 'Return along existing graph routes to '+exit_node+'. The connection from this boundary to camp is proposed, not built.'
        if ident == 'deep-supper':
            shortcut = dict(kind='physical-return', label='Earned Pit ladder / SC2 return',
                            points=[source['nodes']['H2'], [50,33,-5], [49.3,33,0], [46,35,0], source['nodes']['aS']],
                            boundary='Existing ladder/SC2 route shown schematically. It is outside the route graph; no movement path or cost is claimed.')
            return_paths = [shortcut, graph_path(source, 'aS', exit_node, closed)]
            return_note = 'Use the existing Pit ladder and closet-side SC2 release, then follow graph routes to S1. The dashed connector is schematic and outside the route graph; camp transfer at S1 is proposed.'
        roles = dict(reader='Read the approach, creature signs and return route; then swap roles.',
                     carrier='Choose pack staging before the hunt; carry the shared harvest after it.')
        def stage(sid, heading, desc, paths=(), markers=(), **extra):
            return dict(id=sid, title=heading, label=heading, description=desc, note=desc,
                        status='Design illustration', paths=list(paths), markers=list(markers), roles=roles, **extra)
        stages = [
            stage('brief','Read the order',
                  'Course 1 prototype: one preserved monster part, common cave seasoning, and an optional mushroom garnish. The cookbook identifies habitats; exact review markers are hidden until enabled.',
                  markers=[entry_site], nodeId=entry),
            stage('approach','Choose an approach',description,
                  approach, [entry_site, forage[0]], nodeId=entry),
            stage('hunt','Hunt and preserve',
                  'An authored opportunity occupies this existing hunt court. Inspect signs, stage the pack, and preserve the part. Placement is a proposed contract; no creature spawn or combat is simulated.',
                  markers=[hunt], nodeId=target, roomId=room),
            stage('optional','Take the detour?',
                  'Return now, or inspect the existing Grotto mushroom shelf for an optional finish. The return preview in the next stage assumes you declined this detour; a chosen garnish is not required for completion.',
                  optional, [bonus], roomId='root-grotto', nodeId='gE'),
            stage('return','Bring it home',return_note,return_paths,[exit_site],nodeId=exit_node),
            stage('cook','Resolve the expedition',
                  'Proposed camp finale: prepare the same recovered ingredients, retain their condition, and see the result. Camp connection and cooking-at-camp are not implemented by this mockup.',
                  markers=[exit_site],nodeId=exit_node)]
        for s in stages:
            graph_sections = [p for p in s['paths'] if p['kind'] == 'graph']
            # Keep graph segments separate when a schematic connector lies between them.
            if len(graph_sections) == 1 and len(s['paths']) == 1:
                s['routeNodeIds'] = graph_sections[0]['nodeIds']
        scenarios.append(dict(id=ident,title=title,seed=seed,seedLabel=seed,summary=description,
                              habitat='Derelict food stores within the Warrens; feeding signs narrow the search to an occupied hunt court.',
                              entryNode=entry,returnNode=exit_node,closedGates=closed,hunt=hunt,forage=forage,bonus=bonus,
                              requiredSites=[hunt,*forage],optionalSites=[bonus],stages=stages,
                              guarantee='Design guarantee: one viable target opportunity and two alternative common-seasoning sources. This is an authored scenario, not a validated runtime spawn rule.',
                              damageRisk='Availability is guaranteed by the proposed contract; preservation and successful return are player outcomes.',
                              returnAlternative=direct_return))
    return dict(title='The Descent · Expedition Atlas',date='23 October 2026',
                boundary='Proposed expedition design on current Warrens geometry. No live map, gameplay or MP changes.',
                world=dict(districts=[
                    dict(id='warrens',title='The Warrens',depth='First district · multiple elevations',status='Current geometry / proposed contracts',
                         habitat='Brine-fed larders, roots, ossuaries and derelict food stores.',
                         identity='The Well, broad service spiral, supported pipe runs, drying racks and inward burial niches.',
                         resources=['Pickle Mimic part · proposed hunt assignments','Common seasoning · proposed forage assignment','Mushroom shelf · existing fixture / optional recipe use'],
                         variations=['Three authored contract setups','Existing R-route choices','Voluntary optional return detour']),
                    dict(id='drowned',title='The Brineworks',depth='Deeper neighboring band · schematic',status='Future concept only',
                         habitat='Flooded stores and mineral seep chambers.',identity='Channels, cistern silhouettes and salt-crusted arches.',
                         resources=['Future habitat-specific part','Common mineral seasoning'],variations=['Later district assembly','No authored geometry in this mockup']),
                    dict(id='ossuary',title='The Ash Refectories',depth='Lower neighboring band · schematic',status='Future concept only',
                         habitat='Cold ovens, bone stores and abandoned dining halls.',identity='Kiln mouths, banquet silhouettes and pale ash.',
                         resources=['Future habitat-specific part','Optional aromatic garnish'],variations=['Later neighboring-district contracts','No authored geometry in this mockup'])],
                           connections=[dict(fromId='camp',to='warrens',kind='arrival',status='Proposed',label='Deploy to known district boundary'),
                                        dict(fromId='warrens',to='camp',kind='return',status='Proposed',label='Earned party + pack return'),
                                        dict(fromId='warrens',to='drowned',kind='adjacent',status='Future concept',label='Optional neighboring district'),
                                        dict(fromId='drowned',to='ossuary',kind='adjacent',status='Future concept',label='Advanced contracts later')]),
                contract=dict(id='midnight-pickle',title='Midnight Pickle Consommé',course='Course 1 · prototype contract',
                              required=[dict(id='part',label='Preserved Brined Dill Heart',kind='Monster part',habitat='Warrens food stores',rule='One authored hunt opportunity; no spawn lottery.'),
                                        dict(id='seasoning',label='Common cave seasoning',kind='Forage',habitat='Mineral chambers',rule='Either of two reachable proposed sources; no rarity tiers.')],
                              optional=dict(id='garnish',label='Grotto mushroom garnish',rule='Optional finish; never a completion gate.'),
                              cooking='Short physical cooking at camp is proposed. Preserve ingredient identity and condition. The current Chapel field kitchen remains existing map content.'),
                scenarios=scenarios,
                rules=[dict(title='Learn the habitat',text='District identity and creature rules stay reliable; encounter sites and local approach conditions can vary.'),
                       dict(title='Keep a run stable',text='Selecting another setup illustrates a new expedition. Revisit within a run without rerolling or replenishing it.'),
                       dict(title='Separate persistence',text='Future permanent discovery grants district-arrival eligibility. Local releases reset next expedition and stay open once earned in this one.'),
                       dict(title='Reward a detour',text='Optional secrets add a finish, supplies or knowledge. They never hide required ingredients.'),
                       dict(title='Two players, one intention',text='Short voluntary scout/carrier splits and clear reunion space; no compulsory simultaneous hold or MP implementation.')],
                scope=dict(existing=['Current Warrens builder manifest and 4,149 primitive transforms','Route graph, seven R sockets, ladders, SC2 and latched mechanisms','Two-player staging reservations and existing Grotto mushroom fixture','Existing physical ingredient, pack, station and cookbook foundations'],
                           proposed=['One Course 1 recipe and three authored expedition configurations','Target and common-forage assignment at the shown sites','Camp return boundary and short ingredient-driven camp finale','Coarse habitat clues and district discovery rules'],
                           deferred=['True procedural geometry and adaptive population director','Brineworks / Ash Refectories geometry and lift network','Cross-district mandatory recipes, quality tiers and cargo-only banking','Full field-kitchen system, expanded progression and all MP-specific work']))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--three',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    source=build_warrens.load()
    manifest,summary=build_warrens.manifest(write=False,data=source)
    accepted=json.loads((ROOT/'Saved/WarrensOrangeLandmarks-20261022/manifest-after.json').read_text())
    assert manifest==accepted, 'Current geometry differs from accepted snapshot'
    assert hashlib.sha256(args.three.read_bytes()).hexdigest()=='170c6789f43217c96b3170f4b42fafe135de7f7cd48497a4218f9757ee1d49fa'
    concept=proposal(source)
    payload=dict(source=source,manifest=manifest,summary=summary,proposal=concept,
                 commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                 sourceHash=hashlib.sha256(build_warrens.DATA.read_bytes()).hexdigest())
    html=(HERE/'expedition.template.html').read_text(encoding='utf-8')
    for token,content in [('DATA',json.dumps(payload,separators=(',',':')).replace('<','\\u003c')),
                          ('THREE',args.three.read_text(encoding='utf-8').replace('</script','<\\/script')),
                          ('SCRIPT',(HERE/'expedition.js').read_text(encoding='utf-8'))]:
        assert '<!--'+token+'-->' in html, token
        html=html.replace('<!--'+token+'-->',content)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(html,encoding='utf-8')
    evidence=ROOT/'Saved/WarrensExpeditionMockup-20261023'
    evidence.mkdir(exist_ok=True)
    (evidence/'proposal.json').write_text(json.dumps(concept,indent=2),encoding='utf-8')
    (evidence/'payload.json').write_text(json.dumps(payload),encoding='utf-8')
    print(json.dumps(dict(output=str(args.output.resolve()),bytes=args.output.stat().st_size,
                          scenarios=len(concept['scenarios']),stagesPerScenario=6,boxes=len(manifest['boxes']),
                          acceptedGeometryExact=True,sourceHash=payload['sourceHash'])))


if __name__=='__main__':
    main()
