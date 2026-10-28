"""Export an HTML-only, instance-oriented Warrens layout proposal. No live edits."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]


def proposal():
    def module(ident,name,at,size,height,theme,landmark,ports,intent,setup):
        return dict(id=ident,name=name,asset='LI_Warrens_'+ident,at=at,size=size,height=height,theme=theme,
                    landmark=landmark,ports=ports,intent=intent,setup=setup)
    modules=[
        module('PitHub','Pit / Well hub',[0,0,0],[36,36],10,'mineral',
               'Open shaft, off-centre hoist and broken crown; the same void is read from rim and quarry floor.',
               dict(N=[0,18,0],W=[-18,10,0],E=[18,10,0],S=[0,-18,0],SE=[18,-10,0],returnW=[-18,6,0]),
               'Two chefs can pause at a 6 m rim, point out separate exits and regroup without blocking traffic.',
               'One spatial anchor, five distinct threshold silhouettes. Keep central void and landmark in the hub instance.'),
        module('Arrival','Arrival gallery',[0,54,0],[16,20],4,'stone',
               'Split arch and empty pack rests; the first approach frames the Pit hoist.',
               dict(S=[0,-10,0],camp=[0,10,0]),
               'Depart and return together. A camp boundary is shown beyond the gallery; it is not a built lift.',
               'Reuses the Chapel vocabulary. Kitchen stations and recipe completion move to camp in this proposal.'),
        module('Court','Charnel Court',[-53,15,0],[32,30],8,'stone',
               'Tall broken mourner monument, broad processional floor and an asymmetric return arch.',
               dict(E=[16,0,0],S=[0,-15,0]),
               'A generous arrival lets one chef inspect the arena while the carrier chooses a staging edge.',
               'Retain existing Court forms and hunt function; no new enemy or combat system.'),
        module('Waterworks','Waterworks',[53,16,-2.5],[30,32],7,'metal',
               'Supported pipe elbow, dry trough and low ribbed sluice opening.',
               dict(W=[-15,0,0],SW=[-15,-8,0],S=[0,-16,0]),
               'Read remote bar response from a dry receiving pad. Water remains cosmetic.',
               'Pump, Salt Cellar and Sluice become legible internal bays of one editable area, rather than three competing entrances.'),
        module('Belfry','Chime Hall / Bellkeeper',[53,-40,0],[30,28],9,'wood',
               'Tall bell frame, timber baffles and a narrow view back toward the hoist.',
               dict(N=[0,14,0],W=[-15,0,0],NW=[-15,6,0]),
               'Separate the clue reader, dial operator and pack stage. No required route depends on solving Bellkeeper.',
               'Retain existing dial/chain behavior and reward stakes; relocate its clue locally during a later implementation pass.'),
        module('Ossuary','Ossuary / Reliquary',[0,-55,2.5],[32,26],5,'bone',
               'Triple bone-rib threshold, low inward niches and an ordered plinth silhouette.',
               dict(N=[0,13,0],W=[-16,0,0],E=[16,0,0]),
               'Single-person Mourner occupancy latches; the partner can inspect the result, then both move on.',
               'Retain plate, optional cache and existing niche kit; move far control/destination pairs into understandable local relationships.'),
        module('Grotto','Root Grotto',[-53,-43,-2.5],[38,30],7,'root',
               'Low twisted entry, leaning root crown and one quiet forage apron.',
               dict(N=[0,15,0],E=[19,0,0]),
               'A carrier can use the walking loop; a scout may inspect the recess without a compulsory drop.',
               'Reuses existing mushroom forage and root vocabulary. The quiet transition is deliberate contrast, not empty filler.'),
        module('PitDepths','Lower Pit / Vault',[0,0,-8],[22,22],6,'mineral',
               'The same shaft from below, a side Vault and the recognizable hoist overhead.',
               dict(E=[11,8,0],W=[-11,6,0]),
               'Keep pack staging outside the hunt footprint and provide a loaded walking approach plus an earned ladder return.',
               'Lower Pit shell includes a Vault annex at local [30,-4,0]. It is vertically beneath the hub, not a second disconnected landmark.')]
    def link(ident,a,ap,b,bp,label,via=(),shortcut=False,kind='walk'):
        return dict(id=ident,a=a,ap=ap,b=b,bp=bp,label=label,via=list(via),shortcut=shortcut,kind=kind,width=4)
    links=[
        link('ArrivalReveal','Arrival','S','PitHub','N','Split arch → first Pit reveal'),
        link('CourtThreshold','PitHub','W','Court','E','Broken arch → Court compression',[-28,15,0]),
        link('WaterThreshold','PitHub','E','Waterworks','W','Pipe elbow → lower Waterworks', [28,16,-1.25]),
        link('BoneThreshold','PitHub','S','Ossuary','N','Triple ribs → raised Ossuary'),
        link('RootApproach','Court','S','Grotto','N','Quiet root descent'),
        link('RootReturn','Grotto','E','Ossuary','W','Root shelf → burial stair'),
        link('EastCloister','Waterworks','S','Belfry','N','Dry service passage'),
        link('ProcessionBridge','Belfry','W','Ossuary','E','Timber choke → open procession', [27,-48,1.25]),
        link('BelfryReturn','Belfry','NW','PitHub','SE','Belfry-side latch → Pit recognition', [29,-24,0],True),
        link('QuarryDescent','Waterworks','SW','PitDepths','E','Loaded walking descent', [27,8,-5.5]),
        link('ClosetReturn','PitDepths','W','PitHub','returnW','SC2 / ladder return',[-24,6,-8],True,'ladder')]
    for edge in links:
        raw=edge['via']
        edge['via']=[raw] if raw and isinstance(raw[0],(int,float)) else raw
    return dict(title='Warrens · The Pit as a compass',date='23 October 2026',modules=modules,links=links,
                pit=dict(outer=18,inner=12,lower=-8),
                checkpoints=[dict(id='arrival',label='Arrival / first reveal',eye=[0,23,1.35],target=[-6,0,2]),
                             dict(id='court',label='Court / broken arch',eye=[-21,10,1.35],target=[0,0,-2]),
                             dict(id='water',label='Waterworks / pipe mouth',eye=[21,10,1.35],target=[0,0,-3]),
                             dict(id='bone',label='Ossuary / triple ribs',eye=[0,-21,1.35],target=[0,0,-3]),
                             dict(id='lower',label='Lower Pit / look up',eye=[0,-6,-6.65],target=[-7,2,7])],
                research=[
                    dict(title='Dark Souls · Firelink Shrine',url='https://soulslore.wikidot.com/das1-design-works',
                         finding='In the reproduced Design Works interview, Miyazaki describes a small hub connected to many places; Satake describes connections in every direction.',
                         application='The Pit becomes the repeated reference across five distinct thresholds. Two outer loops avoid making every trip return through the hub.',
                         limit='Apply the connectivity and recognition pattern, not the exact Firelink layout or bonfire systems. Source is an interview translation reproduced by Souls Lore.'),
                    dict(title='TUNIC · landmark reveals and rediscovered routes',url='https://www.gamedeveloper.com/design/designing-content-for-no-one-an-interview-with-the-team-behind-tunic',
                         finding='The developers discuss controlling vistas and when landmarks are seen, and passages understood after approaching from the other end.',
                         application='Compression → framed Pit glimpse → distinct room reveal. Far-side latches return to a known silhouette; the familiar place gains a new spatial relationship.',
                         limit='TUNIC uses an isometric camera. Here sightlines are proposed first-person camera checkpoints, not borrowed camera-hidden routes or proven visibility.'),
                    dict(title='Deep Dish Dungeon · deliberate exploration, useful friction',url='https://steamcommunity.com/app/2871520/announcements/',
                         finding='In Dev Blog #10 (16 October 2026), creative director Saulo Camarotti describes deliberate exploration and planning, while distinguishing them from unfair or confusing friction.',
                         application='Keep investigation and optional detours; remove repeated navigation tax. Restore bearings through distinct silhouettes, open views and earned returns.',
                         limit='This is developer-stated intent, not a claim of critical acclaim or a verified reconstruction of its dungeon. Do not copy its lack of direction as a goal.'),
                    dict(title='Unreal · Level Instances',url='https://dev.epicgames.com/documentation/en-us/unreal-engine/level-instancing-in-unreal-engine?application_version=5.6',
                         finding='Epic documents in-context editing of actor collections; changes to an instance propagate to its repetitions. Level Instances and static Packed Level Blueprints are distinct workflows.',
                         application='Eight area instances plus connector instances, each with a stable pivot and named floor-height ports. Assembly owns cross-area joins and unique mechanism identities.',
                         limit='HTML authoring proposal only. No Unreal assets are created. Level instancing does not by itself supply procedural generation or a streaming strategy.')],
                scope=['Cooking and recipe completion are at base camp. Arrival gallery contains no field kitchen.',
                       'Regular Level Instances are proposed for area shells/local dressing; Packed Level Blueprints may later suit purely static detail.',
                       'The parent assembly owns connector spans, cross-area bindings and unique anchor/channel identities. Repeated instances must not duplicate global mechanism IDs.',
                       'Room ports keep a fixed local position, width and floor elevation. Moving a module recomputes its connector preview; it does not silently alter the room.',
                       'Physical clearance, sightline occlusion, pacing and navigation recognition still require later Unreal/PIE and unfamiliar-pair acceptance.',
                       'No new gameplay systems, procedural generator, streaming setup or MP-specific work. Existing gates, dials, plate, forage and loaded returns are the intended reuse.'])


def interlocked_proposal():
    """Authoring chunks meet through shared architecture, rather than padded joins."""
    p=proposal()
    p.update(title='Warrens · One place, many ways through',revision=3)
    by_id={m['id']:m for m in p['modules']}
    def revise(ident,**values):
        by_id[ident].update(values)
    revise('Arrival',at=[0,26,0],size=[18,16],height=4.5,
           ports=dict(S=[0,-8,0],camp=[0,8,0]),
           landmark='A short, low arrival chamber opens straight onto the Pit crown; the hoist is revealed around an offset stone screen.',
           intent='Two chefs arrive together at a broad threshold. Cooking and recipe completion are at base camp.',
           setup='A shared wall and a framed reveal separate camp from the expedition. There is no approach corridor.')
    revise('Court',at=[-32,4,0],size=[28,32],height=9,
           poly=[[-14,-16],[14,-16],[14,10],[6,10],[6,16],[-14,16]],openEdges=[1],
           ports=dict(E=[14,2,0],S=[-4,-16,0]),
           landmark='A broken mourner monument stands in an asymmetric hall. Its open colonnade shares the Pit west rim.',
           intent='One chef can read the monument while the carrier keeps the hoist in view through the columns. The onward route turns behind the broken apse.',
           setup='Court and Pit are adjoining spaces, not distant rooms. The wall mass and column rhythm create the transition; the hunt floor stays broad.')
    revise('Grotto',at=[-31,-26,0],size=[32,28],height=5,
           poly=[[-16,-10],[-10,-14],[8,-14],[16,-6],[16,8],[13,8],[13,14],[-5,14],[-16,7]],
           ports=dict(N=[-5,14,0],E=[16,0,0]),
           landmark='Roots have invaded a collapsed burial apse. The route bends around a leaning root screen into an irregular forage court.',
           intent='The carrier follows the ground-level curve while the scout checks the sheltered forage edge. Both routes rejoin before the crypt breach.',
           setup='A turn behind Court rubble, a low root canopy and a breach into Ossuary replace an exterior connector. Reuse root/forage dressing; no new traversal ability.')
    revise('Ossuary',at=[0,-30,0],size=[30,24],height=4.5,
           poly=[[-15,-7],[-10,-12],[10,-12],[15,-7],[15,7],[8,12],[-8,12],[-15,7]],
           ports=dict(N=[0,12,0],W=[-15,4,0],E=[15,4,0]),
           landmark='An octagonal, low burial hall meets the Pit south lip. Repeated ribs and staggered niche walls conceal the exit until the final bay.',
           intent='A broad central aisle gives the carrier room to wait while the partner reads the Mourner/cache response. Side routes remain local.',
           setup='The north rib threshold is the Pit wall; the west breach is the Grotto wall. Separation comes from the low section and occlusion, not walking distance.')
    revise('Waterworks',at=[32,5,-3],size=[28,34],height=10,openEdges=[0],
           ports=dict(W=[-14,-1,0],SW=[4,-1,0],S=[0,-17,0]),
           landmark='A tall pump chamber exposes the quarry descent below. Supported pipes cross the void; the Pit hoist and the Belfry gallery occupy different levels of the same view.',
           intent='The dry receiving apron holds both chefs. The loaded walking descent winds through the open machinery void, separate from the optional sluice reward.',
           setup='The west stair is part of the Pit rim. The lower route occupies the chamber cut-out, while the Belfry joins its south wall. Water remains cosmetic.')
    revise('Belfry',at=[32,-26,-3],size=[28,28],height=12,
           poly=[[-14,-14],[14,-14],[14,4],[10,14],[-14,14]],
           openEdges=[3],
           ports=dict(N=[0,14,0],W=[-14,0,3],NW=[-14,14,3]),
           landmark='The bell hangs over a low service floor. A raised L-shaped reader gallery looks back across the pump chamber; the dial bay sits beneath its timber frame.',
           intent='The reader uses the gallery while the carrier stages below. An internal stair reunites them; solving Bellkeeper is optional.',
           setup='One space has two sections: a -3 m service floor and a 0 m gallery. Its earned shutter returns directly onto the Pit southeast rim, rather than across a long bridge.')
    revise('PitHub',ports=dict(N=[0,18,0],W=[-18,6,0],E=[18,4,-3],S=[0,-18,0],SE=[18,-10,0],returnW=[-18,6,0]),
           landmark='The open shaft, off-centre hoist and broken crown belong to the same excavated complex as the surrounding halls.',
           intent='A 6 m rim provides pause and passing space. Chefs can point across the shaft and choose a wing without a required hub commute.',
           setup='The Court colonnade, pump stair, bone threshold and timber shutter are built into the rim. Authoring seams do not require corridor pieces.')
    revise('PitDepths',size=[24,24],ports=dict(E=[11,8,0],W=[-11,6,0]),
           setup='The quarry lies below the same shaft. Its side Vault and the Waterworks ramp are visible as parts of one vertical excavation; loaded approach and earned ladder return remain distinct.')
    for m in p['modules']:
        if 'poly' not in m:
            w,h=m['size'];m['poly']=[[-w/2,-h/2],[w/2,-h/2],[w/2,h/2],[-w/2,h/2]]
    descriptions={
        'ArrivalReveal':('Arrival wall / offset reveal',6),
        'CourtThreshold':('Shared Court colonnade',10),
        'WaterThreshold':('Rim stair into pump chamber',8),
        'BoneThreshold':('Shared bone-rib threshold',6),
        'RootApproach':('Collapsed apse / root turn',6),
        'RootReturn':('Breached crypt wall',5),
        'EastCloister':('Pump / bell service opening',7),
        'ProcessionBridge':('Gallery / crypt wall',5),
        'BelfryReturn':('Earned gallery shutter',4),
        'QuarryDescent':('Terraced descent inside the pump void',6),
        'ClosetReturn':('SC2 / quarry rim ladder',2)}
    for e in p['links']:
        e['label'],e['width']=descriptions[e['id']]
        e['via']=[]
        e['ownership']='Shared threshold; assembly binds ports. No separate corridor instance.'
    descent=next(e for e in p['links'] if e['id']=='QuarryDescent')
    descent.update(via=[[36,12,-5],[28,18,-6],[11,18,-8]],ownership='Waterworks ramp terraces descend through its own open floor to the quarry; assembly binds the final seam.')
    next(e for e in p['links'] if e['id']=='ClosetReturn')['via']=[[-18,6,-8]]
    p['routes']={
        'west':[[-15,6,0],[-24,6,0],[-28,15,0],[-41,13,0],[-43,2,0],[-37,-6,0],[-36,-12,0],[-41,-23,0],[-33,-34,0],[-25,-32,0],[-15,-26,0],[0,-25,0],[0,-15,0],[-15,-15,0],[-15,6,0]],
        'east':[[15,4,-1.5],[18,4,-3],[32,0,-3],[32,-12,-3],[39,-28,-3],[28,-34,-3],[28,-22,0],[21,-22,0],[18,-26,0],[15,-26,0],[0,-25,0],[0,-15,0],[15,-15,0],[15,4,-1.5]],
        'lower':[[15,4,-1.5],[18,4,-3],[30,0,-3],[36,4,-3],[36,12,-5],[28,18,-6],[11,18,-8],[11,8,-8],[0,0,-8],[-11,6,-8],[-18,6,-8],[-18,6,0],[-15,6,0]]}
    p['checkpoints']=[
        dict(id='arrival',label='Arrival / around the screen',eye=[0,22,1.35],target=[-6,0,2]),
        dict(id='court',label='Court / shared Pit colonnade',eye=[-28,8,1.35],target=[-4,0,-2]),
        dict(id='water',label='Pump / quarry terraces below',eye=[39,3,-1.65],target=[28,14,-5.5]),
        dict(id='belfry',label='Belfry / raised reader gallery',eye=[21,-21,1.35],target=[32,0,-2]),
        dict(id='bone',label='Ossuary / final rib bay',eye=[0,-25,1.35],target=[0,-10,1]),
        dict(id='lower',label='Quarry / same hoist above',eye=[0,-6,-6.65],target=[-7,2,7])]
    p['research'][0]['application']='Repeat the Pit through adjoining spaces and overlapping vertical views. Outer loops run through the Court, Grotto, crypt and pump/bell complex; spokes are not the spatial objective.'
    p['research'][1]['application']='Use an offset screen, the last crypt bay and a gallery overlook to control recognition. Create reveal timing inside the architecture instead of adding long approach corridors.'
    p['research'][3]['application']='Use eight irregular area chunks with shared edges and height ports. A Level Instance seam may cross a continuous space; it does not imply a separate room or connector prefab.'
    p['scope']=[
        'Level Instances follow authoring responsibility, not a room/corridor grid. Shared edges, open colonnades and overlapping vertical views make one continuous complex.',
        'Cooking and recipe completion stay at base camp. No kitchen unlock tax returns to the expedition.',
        'Area instances own their local walls, floors, stairs and dressing. The parent owns shared seam alignment, cross-area bindings and unique identities; no automatic corridor stitching.',
        'The ordinary western and eastern loops stay available. The Belfry shutter and SC2 ladder remain earned returns; no new traversal ability is required.',
        'Internal routes illustrate circulation, not collision. Later Unreal acceptance must verify slopes, headroom below galleries, loaded clearance, visibility and unfamiliar-pair orientation.',
        'No gameplay system, procedural generation, streaming implementation or MP work. Reuse the existing gates, dials, plate, forage, hunt and reward roles.']
    return p


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--three',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    args=ap.parse_args()
    assert hashlib.sha256(args.three.read_bytes()).hexdigest()=='170c6789f43217c96b3170f4b42fafe135de7f7cd48497a4218f9757ee1d49fa'
    source_path=HERE.parent/'data/warrens.json'
    source=json.loads(source_path.read_text())
    previous_path=ROOT/'docs/design/warrens-pit-iteration-20261023/Warrens-Proposal.json'
    payload=dict(proposal=interlocked_proposal(),baseline=source,
                 previous=json.loads(previous_path.read_text(encoding='utf-8')),
                 commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                 sourceHash=hashlib.sha256(source_path.read_bytes()).hexdigest())
    html=(HERE/'pit_iteration.template.html').read_text(encoding='utf-8')
    for key,value in [('DATA',json.dumps(payload,separators=(',',':')).replace('<','\\u003c')),
                      ('THREE',args.three.read_text().replace('</script','<\\/script')),
                      ('SCRIPT',(HERE/'pit_iteration.js').read_text(encoding='utf-8'))]:
        html=html.replace('<!--'+key+'-->',value)
    args.output.parent.mkdir(exist_ok=True,parents=True)
    args.output.write_text(html,encoding='utf-8')
    (args.output.parent/'Warrens-Proposal.json').write_text(json.dumps(payload['proposal'],indent=2),encoding='utf-8')
    print(json.dumps(dict(output=str(args.output.resolve()),bytes=args.output.stat().st_size,
                         modules=len(payload['proposal']['modules']),links=len(payload['proposal']['links']),liveMapChanged=False)))


if __name__=='__main__':main()
