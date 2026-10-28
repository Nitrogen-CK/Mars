"""Read-only rollout inventory. Selection centres are planning, not mesh ownership."""
import collections
import hashlib
import html
import json
import math
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024'
OUT=DOC/'lookdev/remaining-room-rollout-r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def poly(room):
    if 'poly' in room:return room['poly']
    a,b,c,d=room['rect'];return [[a,b],[c,b],[c,d],[a,d]]
def inside(p,polygon):
    x,y=p;odd=False
    for a,b in zip(polygon,polygon[1:]+polygon[:1]):
        if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:odd=not odd
    return odd
def near(p,polygon,distance=.8):
    if inside(p,polygon):return True
    for a,b in zip(polygon,polygon[1:]+polygon[:1]):
        dx,dy=b[0]-a[0],b[1]-a[1];t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy)))
        if math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy)<=distance:return True
    return False
def plain(s):return html.unescape(re.sub('<[^>]+>',' ',s)).strip()
def main():
    assert not OUT.exists()
    paths=[ROOT/'Tools/LevelDesign/anchor_plans/data/warrens_v8c.json',ROOT/'Tools/WarrensVariantCKit/Output/fitted_instances.json',ROOT/'Tools/WarrensVariantCKit/Output/Reports/full_source_baseline.json']
    plan,fit,baseline=[json.loads(p.read_text()) for p in paths]
    rows=[]
    for room in plan['rooms']:
        rid=room['id'];polygon=poly(room);z=room['z'];plate=DOC/'final-room-plates/rooms'/(rid.lower()+'.html');text=plate.read_text() if plate.exists() else ''
        focus=re.search(r'<h2>Art focus</h2>\s*<p>(.*?)</p>',text,re.S);clear=re.search(r'<h3>Keep clear</h3><ul>(.*?)</ul>',text,re.S)
        candidates=[(i,r) for i,r in enumerate(fit['placements']) if near(r['at'][:2],polygon) and z-.6<=r['at'][2]<=z+10]
        family=collections.Counter('ceiling' if 'ceiling' in r['role'] else 'floor' if 'floor' in r['role'] else 'wall' if 'wall' in r['role'] else 'prop' for _,r in candidates)
        tiles=collections.Counter(r['tile'] for _,r in candidates)
        rows.append(dict(room=rid,floor_z=z,polygon=polygon,art_focus=plain(focus[1]) if focus else None,protected_features=[plain(s) for s in re.findall(r'<li>(.*?)</li>',clear[1],re.S)] if clear else [],source_plate=plate.relative_to(ROOT).as_posix(),candidate_source_keys=[i for i,_ in candidates],candidate_role_counts=dict(family),candidate_tile_counts=dict(tiles),native_level_instances={t:baseline[t]['asset'] for t in tiles},status='SOURCE_PILOT_ACCEPTED' if rid=='catacomb' else 'AWAITING_ROOM_SPECIFIC_SURFACE_AND_NATIVE_REVIEW'))
    order=['larder','hall','ossuary','cellar','sluice','belfry','bell-loft','reliquary','mill','closet','court','court-pit','rimW','rimE','rimN','rimS','bridgehead','ford-w','ford-e','pump','cistern','lair','vault']
    assert len(rows)==24 and set(order)=={r['room'] for r in rows if r['room']!='catacomb'}
    OUT.mkdir(parents=True)
    report=dict(status='READ_ONLY_REMAINING_ROOM_ROLLOUT_SURVEY',inputs={p.relative_to(ROOT).as_posix():sha(p) for p in paths},priority=order,rooms=rows,boundary='Counts use source placement centres near room polygons and may overlap adjacent/stacked rooms. They are planning candidates, never authority to rebind/remove whole HISM groups. Historic source geometry must be matched to fresh native solid/instance snapshots before constructing visual veneers. No assets/maps/library originals written.',shared_method='Retain broad physical masonry courses, angular low-frequency pigment, independently baked normal/roughness, quiet joints, opt-in per-room material instances, existing gameplay ownership. Preserve each room art focus/clear features; no global warm recolor or enemy pass.')
    (OUT/'surface_survey.json').write_text(json.dumps(report,indent=2)+'\n')
    larder=next(r for r in rows if r['room']=='larder')
    (OUT/'LARDER_NEXT.md').write_text('# Next room: Brine Larder\n\nApply the accepted material/shape method while preserving the Larder concept: '+larder['art_focus']+'\n\nProtected features:\n\n'+''.join('- '+s+'\n' for s in larder['protected_features'])+'\nImplementation scope: fresh native Brineworks/Main snapshots; finite source-supported wall/floor/ceiling regions; broad courses with the accepted independent normal/roughness; pale dry banks and teal-green shallow brine; decorative storage timber/iron/salt props. Existing roof openings remain open. Compare arrival, bank/wade edge, storage wall, overhead coverage and bell sightline in the same native views. Source-instance poses, collision, water depth, objectives and forage tables remain protected.\n\nAstra review the actual derived preview before adoption; save only scoped approved source/kit changes, reopen and recapture assembled native result. Update reusable native and Blender exhibits with the room.\n\nConfirmed: these constraints are transcribed from the current room plate. Inferred: the placement-centre survey indicates candidate families; it does not establish complete ownership or physical clearance.\n')
    print('ROLLOUT_SURVEY',len(rows),'rooms;',len(order),'remaining;',dict(larder['candidate_role_counts']))
if __name__=='__main__':main()
