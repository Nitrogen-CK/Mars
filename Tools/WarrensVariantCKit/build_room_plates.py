"""Current-source room plates: fresh Blender frames and a local HTML atlas.

Render uses the unchanged source-view helper with output/source overrides only.
Atlas generation runs in ordinary Python. Neither action edits original assets.
"""
import argparse
import hashlib
import html
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import sys
from html.parser import HTMLParser

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
REVIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024'
OUT = REVIEW / 'final-room-plates'
FRAMES = OUT / 'source_views'
HELPER = REVIEW / 'source_views/render_source_views.py'
SOURCE = HERE / 'Output/WarrensVariantC_Diorama.blend'


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, value):
    assert Path(path).resolve().is_relative_to(OUT.resolve())
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + '\n', encoding='utf-8')


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def guards():
    sync = module('room_plate_source_guards', HERE / 'sync_art_libraries.py')
    result = sync.immutable_files()
    for path in [HELPER, REVIEW / 'source_views/render_manifest.json', REVIEW / 'room_briefs.json',
            REVIEW / 'FINAL_CONCEPT_REQUIREMENTS.md', REVIEW / 'LAYOUT_ART_COVERAGE.md', HERE / 'zone_plan.json',
            ROOT / 'Tools/LevelDesign/anchor_plans/data/warrens_v8c.json',
            ROOT / 'docs/art/warrens-c-dressing-r01/materials.json']:
        result[path.relative_to(ROOT).as_posix()] = sha(path)
    assert sha(SOURCE) == 'ac79fa7e3636891688f95939815188e4cf92f67f607e139af28aeb6436500d5f', 'Promoted Diorama differs'
    library = HERE / 'Output/WarrensVariantC_KitLibrary.blend'
    assert sha(library) == '50a54a4d7efbff84314cc6dfb303a2308fc801474ae8292d7cb050bfcfc388cf', 'Promoted library differs'
    return result


def verify_protected():
    before=read(OUT/'guard_before.json');current=guards()
    assert before==read(OUT/'fresh_render_verification.json')['protected_files']
    receipt=read(OUT/'brief_correction_receipt.json')
    key='docs/art/warrens-c-gameplay-review-20261024/room_briefs.json'
    assert receipt['path']==key
    assert before[key]==receipt['before_sha256'] and current[key]==receipt['after_sha256']
    assert set(current)==set(before) and [k for k in before if before[k]!=current[k]]==[key]
    original=(OUT/'room_briefs_before_correction.json').read_bytes()
    assert hashlib.sha256(original).hexdigest()==before[key]
    assert {(r['room_id'],r['field']) for r in receipt['changes']}=={
        ('ossuary','action_feedback'),('bell-loft','action_feedback'),('lair','action_feedback'),('lair','player_view')}
    assert len(receipt['changes'])==4
    expected=original
    old_rooms={r['id']:r for r in json.loads(original)['rooms']}
    new_rooms={r['id']:r for r in read(ROOT/key)['rooms']}
    for row in receipt['changes']:
        assert old_rooms[row['room_id']][row['field']]==row['old']
        assert new_rooms[row['room_id']][row['field']]==row['new']
        old=json.dumps(row['old'],ensure_ascii=False).encode('utf-8')
        new=json.dumps(row['new'],ensure_ascii=False).encode('utf-8')
        assert expected.count(old)==1
        expected=expected.replace(old,new,1)
    assert expected==(ROOT/key).read_bytes(), 'Undocumented brief change'
    return dict(unchanged=len(before)-1,documented_corrections=1,receipt='brief_correction_receipt.json')


def render():
    import bpy
    assert not FRAMES.exists(), 'Fresh frames require an unused output directory'
    before = guards()
    write(OUT / 'guard_before.json', before)
    helper = module('current_source_room_views', HELPER)
    helper.SOURCE_BLEND = SOURCE
    helper.OUT = FRAMES
    helper.BLEND_OUT = FRAMES / 'WarrensC_CurrentRoomViews.blend'
    original_argv = sys.argv[:]
    try:
        sys.argv = [str(HELPER)]
        helper.main()
    finally:
        sys.argv = original_argv
    manifest = read(FRAMES / 'render_manifest.json')
    prior = {r['room_id']:r for r in read(REVIEW / 'source_views/render_manifest.json')['rooms']}
    assert manifest['room_count'] == 24 and manifest['image_count'] == 48
    records = []
    for row in manifest['rooms']:
        old = prior[row['room_id']]
        for field in ('standing_eye_plan', 'standing_target_plan', 'standing_lens_mm', 'source_eye_height_m', 'source_floor_z_m'):
            assert row[field] == old[field], ('Historical camera contract changed', row['room_id'], field)
        for kind in ('overview', 'standing'):
            path = FRAMES / row[kind + '_image']
            camera = bpy.data.objects[row[kind + '_camera']]
            records.append(dict(room_id=row['room_id'], view=kind, file=path.relative_to(ROOT).as_posix(), sha256=sha(path),
                camera_matrix=[list(v) for v in camera.matrix_world], lens_mm=camera.data.lens,
                camera_type=camera.data.type, horizontal_fov_degrees=math.degrees(camera.data.angle_x),
                ortho_scale=camera.data.ortho_scale if camera.data.type == 'ORTHO' else None))
    assert guards() == before, 'Protected original changed during render'
    write(OUT / 'fresh_render_verification.json', dict(status='FRESH48_CURRENT_SOURCE', source=SOURCE.relative_to(ROOT).as_posix(),
        source_sha256=sha(SOURCE), helper_sha256=sha(HELPER), records=records, protected_files=before,
        camera_contract='Existing source-view helper, same authored eyes/targets/lenses and overview construction; fresh current promoted geometry.',
        boundary='Static artwork and temporary neutral review fill. Runtime entities and game lighting are separate existing insets. Original assets never saved.'))
    print('ROOM_PLATE_FRESH_RENDER_COMPLETE', len(records), flush=True)


FLOW = {
 'hall': ['Camp threshold', 'Hoist and open Well rim', 'Orient; no activity stop', 'Camp door / continuous rim'],
 'closet': ['Compact service nook', 'Separate ladder from barred face', 'Existing P6 return interaction', 'Ladder landing into Hall'],
 'court': ['Broad Court approach', 'Mourner / lower Court / Ossuary', 'Read existing niche destinations', 'Continuous upper rim'],
 'court-pit': ['Sunken Court floor', 'Read the existing 1.5m step', 'Traverse the lower basin', 'Pale upper Court rim'],
 'rimW': ['West rim', 'Hoist and open shaft', 'Choose the authored rim direction', 'Parapet toward Hall / camp'],
 'rimE': ['East-rim observation point', 'Distant P4 anticipation cue', 'Recognize tower inscription; approach to read', 'Retreat along the rim'],
 'rimN': ['North rim', 'Shaft / hoist / opposite rim', 'Orient across the void', 'Continuous rim loop'],
 'rimS': ['South rim', 'Pump approach or open Ford', 'Choose the existing connection', 'Rim line toward Hall'],
 'ossuary': ['West bone-storage approach', 'Plate to distant P3 cache', 'One chef OR pack occupies; latch', 'Bone Bridge return'],
 'bridgehead': ['Ossuary-side doorway', 'Existing Bone Bridge', 'Cross and read the landmarks', 'Room-side arch / ribs'],
 'ford-w': ['West shallow-water bank', 'Always-open Ford', 'Wade the authored shallows', 'West steps / Well hoist'],
 'ford-e': ['East bank landing', 'Ford or Belfry approach', 'Use the existing shallow crossing', 'Same bank edge back'],
 'reliquary': ['Tomb and landing', 'P3 cache / Mill stair / rail drop', 'Follow the existing destination', 'Stair / authored drop read'],
 'mill': ['High work district', 'Mushroom forage / work island', 'Harvest forage; curing inactive', 'Existing stair / one-way drop'],
 'catacomb': ['Low burial approach', 'Tomb / closed drawer / niches', 'Explore existing source pockets', 'Authored crawl / descent exits'],
 'belfry': ['Bell and timber landmark', 'P4 panel or P5 loft route', 'Use their existing runtime owners', 'Ground exits / loft return'],
 'bell-loft': ['Reliquary rail-drop first access', 'Red key and P5 lever', 'Collect key / open existing P5 ladder', 'Opened P5 ladder to Belfry ground'],
 'cellar': ['Walk-height cellar', 'Bellnut forage / passive chain', 'Harvest; follow to sole windlass', 'Stair / crossing alternatives'],
 'sluice': ['Remote control approach', 'Sole P2 windlass', 'Haul cage; guards open after seating', 'Seated crossing / Ford / R7'],
 'larder': ['Brine store / roof break', 'Shallow-water forage', 'Use existing wade destination', 'Stair / ledge / Undercroft'],
 'pump': ['Pump landmark', 'Crossing / Ford / descent', 'Choose existing route; pump is decor', 'Sump / lower connections'],
 'cistern': ['Shallow basin edge', 'Existing bank forage', 'Use the authored basin approach', 'Existing bank route'],
 'lair': ['Lowest dry cavern', 'P1 Vault or authored exits', 'Choose existing branch / return', 'Closet ladder home cue'],
 'vault': ['Dry Pit-side approach', 'Existing red-key door', 'Bring reachable Belfry-loft key', 'Retreat through Pit'],
}
POI_HOST = {**{k:'court' for k in ['court-pack','court-forage','court-omen','court-threat']},
 **{k:'ossuary' for k in ['ossuary-husk','ossuary-rest']}, 'bridge-omen':'bridgehead','mourner':'reliquary','reliquary-rest':'reliquary',
 **{k:'belfry' for k in ['bellkeeper','belfry-threat','belfry-pack','sealed-burial']},'cellar-salt':'cellar','porter':'sluice',
 **{k:'larder' for k in ['larder-forage','larder-ledge','larder-threat']},'pump-omen':'pump','pump-rest':'pump','cistern-forage':'cistern',
 **{k:'lair' for k in ['pit-pack','pit-rest','pit-forage','pit-shelf']},
 **{k:'mill' for k in ['mill-pack','mill-threat','mill-rest']}, **{k:'catacomb' for k in ['catacomb-husk','catacomb-cache','catacomb-omen']}}
BEATS = {
 'P1': dict(title='Red-key Vault', rooms=['vault','bell-loft','lair'], owner='Runtime red key / key lock / door',
   action='Carry the reachable Belfry-loft key to the existing Vault door. The Vault contains authored Ration plus useful lantern-fuel Tallow; no healing or nutrition effect is claimed for the Ration. Static views omit runtime items and the door leaf; no locked/unlocked pose is fabricated.'),
 'P2': dict(title='One windlass, one sliding cage', rooms=['sluice','cellar','pump'], owner='Mars_SlidingBridge_EntityScript',
   action='Sluice alone controls the cage. The routed drive is passive. Both end guards remain closed until actual seating; stored/partial/seated images are separate runtime captures.'),
 'P3': dict(title='Mourner occupancy latch', rooms=['ossuary','bridgehead','reliquary'], owner='Runtime PressurePlate / latched cache gate',
   action='One chef OR backpack on the west occupancy plate latches the east cache gate, revealing guaranteed authored Tallow. After release the slab begins rising following the 0.5-second delay; the distant cache gate stays latched open. No permanently depressed slab, mass threshold, pack-only rule or simultaneous hold.'),
 'P4': dict(title='Bellkeeper', rooms=['belfry','rimE','ford-e'], owner='Bellkeeper / clue / external commit chain',
    action='The long rim view anticipates the inscription; it does not prove full-phrase reading. The unchanged east-Ford landing at plan [85,50.5,0] supplies the actual close reading reference. Grip/turn existing dials and pull the existing commit chain. Candles show the remaining Tallow opportunities. A wrong commit triggers the vent and red flash, losing one opportunity until the final protected reward; solve shows green and pays the remainder. Glyph identity, pointer and reward state remain runtime-owned.'),
 'P5': dict(title='Belfry ladder foot', rooms=['belfry','bell-loft','reliquary'], owner='Existing barred-foot gate / loft lever / ladder',
   action='Reach the loft by the authored Reliquary rail-drop approach, use the loft lever, then use the existing ladder. Diagram pins are source beat anchors, not a barrier pose.'),
 'P6': dict(title='Closet return', rooms=['closet','lair'], owner='Existing SC2 gate / closet ladder',
   action='The existing Pit ladder returns to the closet landing and barred return. No new control handle or second ladder.'),
 'P7': dict(title='Mill: planned / inactive', rooms=['mill'], owner='MushroomBed forage is runtime; vat/hopper are static dressing',
   action='Mushroom forage is an existing destination. Curing is unimplemented: no recipe, progress, required stop, product or reward is depicted.'),
}
FEEDBACK = {
 'P1':'Vault payoff: authored Ration plus useful lantern-fuel Tallow. Ration has no claimed healing or nutrition effect.',
 'P3':'Mourner payoff: guaranteed authored Tallow. The slab resets after the 0.5-second release delay; the distant cache gate remains latched open.',
 'P4':'Candles show remaining Tallow opportunities. Wrong commit: vent, red flash and one lost opportunity until the final protected reward. Solve: green and the remaining Tallow payout.',
}
RUNTIME = {
 'sluice': [('ART_held_sluice','Actual held-lantern windlass / fixed mount'),('ART_held_east_partial','P2 partial pose capture'),('ART_held_east_seated','P2 seated pose capture')],
 'cellar': [('ART_held_east_seated','P2 seated destination context; different bank camera')],
 'pump': [('ART_held_west','P2 west threshold context; actual captured pose')],
 'belfry': [('ART_held_bellkeeper','Actual held-lantern panel; current captured state'),('ART_observe_clue_close','Actual east-Ford close clue view; empty hands, existing lighting'),('ART_held_clue_close','Matched east-Ford close clue view; actual picked-up/opened held lantern')],
 'rimE': [('ART_held_clue','Long rim anticipation / recognition only; full-phrase reading unproven'),('ART_observe_clue_close','Actual east-Ford close clue view; empty hands, existing lighting'),('ART_held_clue_close','Matched east-Ford close clue view; actual picked-up/opened held lantern')],
 'ford-e': [('ART_observe_clue_close','Actual east-Ford close clue view; empty hands, existing lighting'),('ART_held_clue_close','Matched east-Ford close clue view; actual picked-up/opened held lantern')],
 'mill': [('ART_held_mill_floor','Actual held-lantern Mill / forage context')],
}

CSS = '''
:root{color-scheme:dark;--bg:#141e23;--panel:#1e2b30;--ink:#ece8dc;--muted:#adbdc0;--gold:#edc47e;--cyan:#94d5d2;--line:#3d5056}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.5 system-ui,sans-serif}main{max-width:1600px;margin:auto;padding:30px}a{color:var(--gold);text-decoration:none}a:hover{text-decoration:underline}h1,h2,h3{font-family:Georgia,serif;font-weight:400}h1{font-size:clamp(32px,4vw,58px);line-height:1.1;margin:16px 0}h2{font-size:31px;margin:32px 0 14px}h3{font-size:24px;margin:18px 0 8px}p{max-width:1050px}.eyebrow,.label{font-size:12px;letter-spacing:.12em;text-transform:uppercase;color:var(--cyan)}nav{display:flex;gap:20px;flex-wrap:wrap;border-bottom:1px solid var(--line);padding-bottom:16px}.badge{display:inline-block;border:1px solid var(--line);padding:4px 9px;font-size:12px;border-radius:20px;color:var(--muted)}.notice{padding:14px 18px;background:#26343a;border-left:3px solid var(--cyan);color:var(--muted);font-size:14px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(285px,1fr));gap:20px}.tile,.card{border:1px solid var(--line);background:var(--panel);padding:14px}.tile img{aspect-ratio:1000/650}.tile h3{margin:10px 0}.tile small{color:var(--muted)}.flow{display:grid;grid-template-columns:repeat(4,1fr);gap:1px;background:var(--line);border:1px solid var(--line);margin:24px 0}.flow div{padding:14px;background:var(--panel)}.flow b{display:block;font-size:11px;letter-spacing:.1em;color:var(--gold);margin-bottom:6px}.frames{display:grid;grid-template-columns:minmax(0,1.65fr) minmax(0,1fr);gap:20px}figure{margin:0}img{display:block;width:100%;height:auto}figcaption{font-size:13px;color:var(--muted);padding:8px 0}.minor{font-size:13px;color:var(--muted)}.columns{display:grid;grid-template-columns:1fr 1fr;gap:24px}.models{display:grid;grid-template-columns:repeat(auto-fit,minmax(120px,1fr));gap:10px}.model{background:#233238;border:1px solid var(--line);padding:8px}.model span{font-size:11px;color:var(--muted);display:block}.swatches{display:flex;flex-wrap:wrap;gap:10px}.swatch{font-size:12px;min-width:85px}.swatch i{display:block;width:85px;height:34px;border:1px solid #ffffff50}.chips{display:flex;gap:8px;flex-wrap:wrap}.chips a{font:12px ui-monospace,monospace;border:1px solid var(--line);padding:4px 7px}svg{display:block;width:100%;background:#18272d;border:1px solid var(--line)}svg text{fill:var(--ink);font-family:system-ui,sans-serif}table{border-collapse:collapse;width:100%;font-size:13px}td,th{text-align:left;padding:9px;border-bottom:1px solid var(--line);vertical-align:top}code{font:12px ui-monospace,monospace;overflow-wrap:anywhere}.runtime{border-top:3px solid var(--gold);padding-top:12px}.runtime figure{background:#1e2b30;padding:10px}.runtime img{max-height:420px;object-fit:contain}.poi:target,.card:target{outline:2px solid var(--gold)}input{font:inherit;padding:9px 12px;width:min(540px,100%);background:#25363d;color:var(--ink);border:1px solid var(--line)}details{padding:12px 0}summary{cursor:pointer;color:var(--gold)}.break{margin-top:48px}footer{color:var(--muted);font-size:13px;border-top:1px solid var(--line);margin-top:30px;padding-top:14px}@media(max-width:900px){main{padding:18px}.frames,.columns{grid-template-columns:1fr}.flow{grid-template-columns:1fr 1fr}}@media print{body{background:white;color:black}nav,input{display:none}.card,.tile,.flow div{background:white}a{color:black}.flow{break-inside:avoid}figure{break-inside:avoid}}
'''
JS = """const q=document.getElementById('room-search');if(q)q.addEventListener('input',()=>{const v=q.value.toLowerCase();for(const n of document.querySelectorAll('[data-room]'))n.hidden=!n.dataset.room.toLowerCase().includes(v)});"""


def esc(value):
    return html.escape(str(value), quote=True)


def href(path, page):
    return Path(os.path.relpath(path, page.parent)).as_posix()


def anchor(path, label, page):
    return '<a href="' + esc(href(path,page)) + '">' + esc(label) + '</a>'


def shell(title, body, page):
    nav = ' | '.join(anchor(OUT/name,label,page) for name,label in [('index.html','24 rooms'),('poi-atlas.html','31 POIs'),('puzzles.html','7 beats')])
    return '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>'+esc(title)+'</title><style>'+CSS+'</style></head><body><main><nav>'+nav+'</nav>'+body+'<footer>Current promoted source geometry. Neutral static review frames; separate runtime captures. Layout, collision, routes, ports and gameplay owners remain source-authored. Art review set; final appearance/player comprehension remains unaccepted.</footer></main><script>'+JS+'</script></body></html>'


def polygon(room):
    if 'poly' in room:
        return room['poly']
    a,b,c,d = room['rect']
    return [[a,b],[c,b],[c,d],[a,d]]


def svg_plan(layout, page, selected=None, niches=None, extra=None, global_map=False):
    rooms = layout['rooms']; points = [p for room in rooms if (selected is None and not extra) or room['id']==selected for p in polygon(room)]
    niches = layout['niches'] if niches is None else niches
    for n in niches:
        a,b,c,d=n['rect']; points += [[a,b],[c,d]]
    for e in extra or []:points.append(e['at'][:2])
    if global_map:
        a,b,c,d=layout['footprint']
    else:
        a=min(p[0] for p in points)-4;b=min(p[1] for p in points)-4;c=max(p[0] for p in points)+4;d=max(p[1] for p in points)+4
        if c-a<16:a,c=(a+c)/2-8,(a+c)/2+8
        if d-b<16:b,d=(b+d)/2-8,(b+d)/2+8
    chunks=['<svg viewBox="'+f'{a} {-d} {c-a} {d-b}'+'" role="img" aria-label="Source plan locator, annotations only; north up">']
    scale=max(c-a,d-b)/110
    for room in rooms:
        ps=' '.join(f'{x},{-y}' for x,y in polygon(room))
        chunks.append('<polygon points="'+ps+'" fill="'+('#34565d' if room['id']==selected else '#22343a')+'" stroke="#52666a" stroke-width=".18"/>')
    for tile in layout['instances']:
        for port in tile['ports']:
            x,y,z=port['at']
            if a<=x<=c and b<=y<=d:
                chunks.append(f'<circle cx="{x}" cy="{-y}" r="{.42*scale}" fill="#edc47e"><title>{esc(tile["id"]+":"+port["id"])} z{z}; width {port["width"]}m</title></circle>')
    indices={n['id']:i+1 for i,n in enumerate(layout['niches'])}
    colors=dict(P='#dec26e',F='#8fc18e',C='#ceb78c',N='#8ecfd6',O='#b6a1c9',T='#a5adb0')
    for n in niches:
        x,y,x1,y1=n['rect'];cx=(x+x1)/2;cy=(y+y1)/2;url=href(OUT/'poi-atlas.html',page)+'#poi-'+n['id']
        chunks.append('<a href="'+esc(url)+'"><rect x="'+str(x)+'" y="'+str(-y1)+'" width="'+str(x1-x)+'" height="'+str(y1-y)+'" fill="none" stroke="'+colors[n['family']]+'" stroke-width=".35"/>')
        chunks.append(f'<circle cx="{cx}" cy="{-cy}" r="{1.25*scale}" fill="#102027"/><text x="{cx}" y="{-cy+.6*scale}" font-size="{1.7*scale}" text-anchor="middle">{indices[n["id"]]:02}</text><title>{esc(n["id"])} z{n["z"]}</title></a>')
    for e in extra or []:
        x,y=e['at'][:2]; label=e['label'];chunks.append(f'<circle cx="{x}" cy="{-y}" r="{.65*scale}" fill="#f4ddab"><title>{esc(e["at"])}</title></circle><text x="{x+scale}" y="{-y-scale}" font-size="{2*scale}">{esc(label)}</text>')
    chunks.append(f'<text x="{a+scale}" y="{-d+3*scale}" font-size="{2*scale}">N up | plan metres | point annotations</text></svg>')
    return ''.join(chunks)


def runtime_figure(stem, label, page):
    image=REVIEW/(stem+'.png');meta=REVIEW/(stem+'.json');record=read(meta)
    assert record['image_sha256']==sha(image), 'Runtime image provenance mismatch: '+stem
    caption=label+' | FOV '+str(record['fov'])+' | t='+f'{record["world_time"]:.3f}'+'s. '+record['boundary']
    return '<figure>'+anchor(image,'Open actual runtime frame',page)+'<img loading="lazy" src="'+esc(href(image,page))+'" alt="'+esc(label)+'"><figcaption>'+esc(caption)+' '+anchor(meta,'Capture record',page)+'</figcaption></figure>'


def contact_sheets(manifest):
    from PIL import Image, ImageDraw
    for kind in ('standing','overview'):
        sheet=Image.new('RGB',(1200,1344),'#141e23');draw=ImageDraw.Draw(sheet)
        for i,row in enumerate(manifest['rooms']):
            x=(i%4)*300;y=(i//4)*224
            with Image.open(FRAMES/row[kind+'_image']) as source:
                thumb=source.copy();thumb.thumbnail((294,192));sheet.paste(thumb,(x,y+24))
            draw.text((x+6,y+5),row['room_id']+' / '+kind,fill='#ece8dc')
        sheet.save(OUT/(kind+'_contact_sheet.png'))


def atlas():
    verify_protected()
    verify=read(OUT/'fresh_render_verification.json');manifest=read(FRAMES/'render_manifest.json')
    assert len(verify['records'])==48 and all(sha(ROOT/x['file'])==x['sha256'] for x in verify['records'])
    layout=read(ROOT/'Tools/LevelDesign/anchor_plans/data/warrens_v8c.json');briefs=read(REVIEW/'room_briefs.json')
    rooms={r['id']:r for r in layout['rooms']};views={r['room_id'].removeprefix('ROOM_'):r for r in manifest['rooms']}
    assert set(rooms)==set(FLOW)==set(views)=={r['id'] for r in briefs['rooms']} and len(rooms)==24
    assert len(layout['niches'])==31 and set(POI_HOST)=={n['id'] for n in layout['niches']}
    assert len(layout['puzzles'])==7 and {p['id'] for p in layout['puzzles']}==set(BEATS)
    assert sum(len(x['ports']) for x in layout['instances'])==46 and len(layout['windows'])==7 and len(layout['views'])==10
    contact_sheets(manifest)
    models={};previews={}
    for kit in ['ChainCrossingKit','PumpCisternKit','WarrensVariantCKit']:
        folder=HERE.parent/kit/'Output';m=read(folder/'asset_manifest.json')
        for row in m['assets']:
            models[row['id']]=row;previews[row['id']]=folder/'Previews'/(row['id']+'.png')
    assert len(models)==196
    materials={m['id']:m for m in read(ROOT/'docs/art/warrens-c-dressing-r01/materials.json')}
    output=[];page=OUT/'index.html';tiles=[]
    for index,brief in enumerate(briefs['rooms'],1):
        brief=dict(brief)
        ident=brief['id'];v=views[ident];file=OUT/'rooms'/(ident+'.html');file.parent.mkdir(parents=True,exist_ok=True)
        if ident=='rimE':
            brief.update(art_direction='Retain the current parapet and clear Well opening as a frame for the distant tower inscription. No added sighting motif or painted answer is proposed.', first_read='The distant clue is an anticipation / recognition cue. Complete phrase reading from the 54 m rim view is unproven; approach the existing east-Ford landing to read.', action_feedback='The unchanged 65 cm dynamic clue shares the runtime panel phrase. Current close reading evidence comes from plan [85,50.5,0]; the rim image establishes distant context only.')
        elif ident=='belfry':
            brief['action_feedback']='P5 lever/ladder state remains unchanged. Preserve the current P4 clue and panel; the rim view anticipates the inscription and the existing east-Ford landing supplies the close reading reference. No fixed painted answer.'
        poi=[n for n in layout['niches'] if POI_HOST[n['id']]==ident]
        beats=[k for k,b in BEATS.items() if ident in b['rooms']]
        flow='<div class="flow">'+''.join('<div><b>'+str(i+1)+' / '+label+'</b>'+esc(value)+'</div>' for i,(label,value) in enumerate(zip(['ARRIVAL READ','GOAL / CHOICE','ACTION / DISCOVERY','RETURN / HOME'],FLOW[ident])))+'</div>'
        body='<p class="eyebrow">'+f'{index:02} / 24 | '+esc(brief['zone'])+' | brief floor z'+str(brief['source_floor_z'])+'m</p><h1>'+esc(brief['label'])+'</h1>'+flow
        body+='<div class="frames"><figure><a href="'+esc(href(FRAMES/v['standing_image'],file))+'"><img src="'+esc(href(FRAMES/v['standing_image'],file))+'" alt="Fresh unmodified standing source frame '+ident+'"></a><figcaption><span class="badge">B / standing source authority</span> '+esc(str(v['standing_eye_plan'])+' -> '+str(v['standing_target_plan']))+' | '+str(v['standing_lens_mm'])+'mm. Static artwork; runtime actors omitted.</figcaption></figure><div><figure><a href="'+esc(href(FRAMES/v['overview_image'],file))+'"><img src="'+esc(href(FRAMES/v['overview_image'],file))+'" alt="Fresh unmodified overview source frame '+ident+'"></a><figcaption>A / local ownership and composition. Original overview construction; no player-readability claim.</figcaption></figure>'+svg_plan(layout,file,ident,poi)+'<p class="minor">Source polygon, numbered niche rectangles and protected port dots. Annotation only; elevations remain explicit in the POI atlas.</p></div></div>'
        body+='<div class="columns"><section><h2>Art focus</h2><p>'+esc(brief['art_direction'])+'</p><p class="minor">'+esc(brief['first_read'])+'</p><h3>Keep clear</h3><ul>'+''.join('<li>'+esc(x)+'</li>' for x in brief['continuity_checks'])+'</ul></section><section><h2>Who owns the read</h2><p><span class="badge">STATIC</span> Source-fitted '+esc(brief['zone'])+' artwork, shell, silhouettes and existing materials.</p><p><span class="badge">RUNTIME</span> '+esc('; '.join(BEATS[k]['owner'] for k in beats) if beats else 'Existing gameplay/forage/POI entities; no state is reconstructed in the source frame.')+'</p><div class="chips">'+''.join('<a href="'+esc(href(OUT/'puzzles.html',file)+'#'+k)+'">'+k+'</a>' for k in beats)+''.join('<a href="'+esc(href(OUT/'poi-atlas.html',file)+'#poi-'+n['id'])+'">'+esc(n['id'])+'</a>' for n in poi)+'</div><p class="minor">'+esc(brief['action_feedback'])+'</p></section></div>'
        if any(k in FEEDBACK for k in beats):
            body+='<div class="notice"><span class="badge">Existing gameplay feedback</span> '+esc(' '.join(FEEDBACK[k] for k in beats if k in FEEDBACK))+'</div>'
        keys=[]
        for mid in brief['existing_model_ids']:
            assert mid in models and previews[mid].is_file(),mid
            for key in models[mid]['material_keys']:
                if key in materials and key not in keys:keys.append(key)
        body+='<h2>Current kit palette</h2><div class="swatches">'+''.join('<div class="swatch"><i style="background:'+esc(materials[k]['base_srgb_hex'])+'"></i>'+esc(k+' '+materials[k]['name'])+'<br><code>'+esc(materials[k]['base_srgb_hex'])+'</code></div>' for k in keys[:6])+'</div><p class="minor">Declared catalogue base-sRGB colors, not sampled frame colors or a new material/light adoption.</p>'
        body+='<div class="models">'+''.join('<a class="model" href="'+esc(href(previews[mid],file))+'"><img loading="lazy" src="'+esc(href(previews[mid],file))+'" alt="Existing model '+mid+'"><b>'+mid+'</b><span>'+esc(models[mid]['name'])+'</span></a>' for mid in brief['existing_model_ids'])+'</div><p class="minor">Existing first-pass kit IDs from the room brief. Cards identify reusable parts; they do not add every pictured part to this room or duplicate its controls.</p>'
        refs=[p for p in brief['concept_refs'] if 'model-sheets/' in p]
        body+='<details><summary>Native model-sheet / source art references</summary><ul>'+''.join('<li>'+anchor(ROOT/p,Path(p).stem,file)+'</li>' for p in refs)+'</ul><p class="minor">Shape/art references only; the fresh A/B images define current room geometry. Historical rejected environment paintings are not used as architecture.</p></details>'
        if ident in RUNTIME:
            body+='<section class="runtime"><p class="eyebrow">Separate actual runtime evidence</p><div class="grid">'+''.join(runtime_figure(stem,label,file) for stem,label in RUNTIME[ident])+'</div></section>'
        if ident in ['rimE','belfry','ford-e']:
            body+='<p class="notice">P4 reading amendment: rim anticipation and close east-Ford reading are distinct. Current 65 cm clue and geometry remain unchanged. The close capture is isolated and teleported; walked approach / novice comprehension remain separate checks. '+anchor(REVIEW/'P4_CLUE_READABILITY_PROPOSAL.md','Source analysis and review boundary',file)+'</p>'
        if ident in ['sluice','cellar','pump']:
            body+='<p class="notice">'+anchor(REVIEW/'P2_ART_RUNTIME_ACCEPTANCE.md','Current P2 runtime acceptance and traversal boundary',file)+': actual seated worn-pack crossing is recorded separately; stored / partial / seated images do not themselves prove traversal, loaded cargo, bypass or novice comprehension.</p>'
        body+='<p class="minor">Camera note: '+esc(v['target_note'])+'. '+anchor(FRAMES/'render_manifest.json','Fresh render manifest',file)+' | '+anchor(OUT/'fresh_render_verification.json','Hashes and camera matrices',file)+'</p>'
        file.write_text(shell(brief['label'],body,file),encoding='utf-8');output.append(dict(id=ident,file=file.relative_to(OUT).as_posix(),poi_ids=[n['id'] for n in poi],puzzles=beats,models=brief['existing_model_ids']))
        tiles.append('<a class="tile" data-room="'+esc(ident+' '+brief['label']+' '+brief['zone'])+'" href="'+esc(href(file,page))+'"><img loading="lazy" src="'+esc(href(FRAMES/v['standing_image'],page))+'" alt="'+esc(ident)+' source standing"><span class="eyebrow">'+f'{index:02}'+' / '+esc(brief['zone'])+'</span><h3>'+esc(brief['label'])+'</h3><small>'+esc(FLOW[ident][1])+'</small></a>')
    page=OUT/'poi-atlas.html';body='<p class="eyebrow">Exact source IDs / 31 authored niches</p><h1>Side discoveries, located</h1><p>Numbered rectangles reproduce the authored niche bounds. Family letters and floor elevations are preserved; these markers do not add actors, routes or collision. Room links are reading associations, not tile ownership.</p>'+svg_plan(layout,page,global_map=True)
    body+='<table><tr><th># / exact ID</th><th>Family / anchor</th><th>Plan rectangle / floor</th><th>Authored note</th><th>Room plate</th></tr>'
    for i,n in enumerate(layout['niches'],1):body+='<tr class="poi" id="poi-'+n['id']+'"><td>'+f'{i:02}'+' <code>'+n['id']+'</code></td><td>'+n['family']+' / '+esc(n['anchorId'])+'</td><td>'+esc(n['rect'])+'<br>z'+str(n['z'])+'m</td><td>'+esc(n['note'])+'</td><td>'+anchor(OUT/'rooms'/(POI_HOST[n['id']]+'.html'),POI_HOST[n['id']],page)+'</td></tr>'
    body+='</table><p class="notice">Cellar distinction: source niche cellar-salt remains at [96,8,100,12], z-2.5. The current Bellnut forage at [99,18,-2.5] is a separate authored runtime fixture; this atlas does not move either to make them coincide.</p>'
    page.write_text(shell('31 POI locators',body,page),encoding='utf-8')
    page=OUT/'puzzles.html';body='<p class="eyebrow">Seven authored beats / state ownership</p><h1>Actions and their owners</h1><p>These source-anchor diagrams locate a relationship. They do not draw a traversable link or fabricate gate, dial, reward or bridge states. Current runtime images and records remain separate.</p>'
    for p in layout['puzzles']:
        ident=p['id'];beat=BEATS[ident];extra=[dict(at=p['at'],label=ident+' source beat anchor')]
        if ident!='P7':extra.append(dict(at=p['needsAt'],label='source dependency anchor'))
        if ident=='P4':extra=[dict(at=layout['bellkeeper'][k]['at'],label='P4 '+k) for k in ('panel','chain','clue')]
        if ident=='P7':extra=[dict(at=p['at'],label='P7 inactive destination'),dict(at=[92,102,5],label='Mushroom forage')]
        body+='<section class="card break" id="'+ident+'"><p class="eyebrow">'+ident+(' / PLANNED - INACTIVE' if ident=='P7' else ' / existing source-owned beat')+'</p><h2>'+esc(beat['title'])+'</h2><div class="columns"><div>'+svg_plan(layout,page,niches=[],extra=extra)+'</div><div><p>'+esc(beat['action'])+'</p><p><span class="badge">OWNER</span> '+esc(beat['owner'])+'</p><div class="chips">'+''.join('<a href="'+esc(href(OUT/'rooms'/(name+'.html'),page))+'">'+esc(name)+'</a>' for name in beat['rooms'])+'</div><p class="minor">'+('No current pose is implied by these anchor pins.' if ident not in ['P2','P4','P7'] else 'See linked room plates for separately sourced actual runtime context; no static answer or state is drawn.')+'</p></div></div></section>'
    page.write_text(shell('Seven puzzle/detail insets',body,page),encoding='utf-8')
    page=OUT/'index.html';body='<p class="eyebrow">Warrens C / source-grounded art review set</p><h1>Twenty-four rooms.<br>The layout stays legible.</h1><p>Fresh standing and overview frames from the promoted original diorama, with native annotation plates. Review arrival, destination, action and return alongside the actual shell, current kit palette and exact POI IDs. This set proposes no new geometry or gameplay.</p><div class="notice">48 fresh static frames /24 rooms /31 niche IDs /7 puzzle insets /46 protected ports. P2 moving parts and windlass are runtime-owned; P4 states use actual captures; P7 curing is inactive. Neutral review fill is separate from game lighting. Final art/player acceptance remains for root review.</div><p><input id="room-search" aria-label="Filter room plates" placeholder="Find a room, district or landmark"></p><div class="grid">'+''.join(tiles)+'</div><h2>Find the side discoveries</h2>'+svg_plan(layout,page,global_map=True)+'<p>'+anchor(OUT/'poi-atlas.html','Open all 31 exact POI locators',page)+' | '+anchor(OUT/'puzzles.html','Open the seven owner/detail insets',page)+'</p>'
    body+='<p>'+anchor(OUT/'standing_contact_sheet.png','24 standing thumbnails',page)+' | '+anchor(OUT/'overview_contact_sheet.png','24 overview thumbnails',page)+' (derived contact sheets; full original PNGs remain on each plate).</p><details><summary>Protected source contracts: 46 ports /7 windows /10 views</summary><table><tr><th>Port ID</th><th>Plan / z</th><th>Width / kind</th></tr>'
    for tile in layout['instances']:
        for port in tile['ports']:body+='<tr><td>'+esc(tile['id']+':'+port['id'])+'</td><td>'+esc(port['at'])+'</td><td>'+esc(str(port['width'])+'m / '+port['kind'])+'</td></tr>'
    body+='</table><h3>Windows</h3><p>'+esc(', '.join(w['id'] for w in layout['windows']))+'</p><h3>Protected views</h3><p>'+esc(', '.join(v['id'] for v in layout['views']))+'</p></details><p>'+anchor(REVIEW/'FINAL_CONCEPT_REQUIREMENTS.md','Plate requirements',page)+' | '+anchor(OUT/'fresh_render_verification.json','Fresh geometry/camera provenance',page)+'</p>'
    page.write_text(shell('24 current room concept plates',body,page),encoding='utf-8')
    write(OUT/'plate_manifest.json',dict(status='REVIEW_SET_NOT_FINAL_ART_ACCEPTANCE',rooms=output,room_count=24,fresh_frames=48,poi_ids=[n['id'] for n in layout['niches']],puzzles=list(BEATS),ports=46,windows=7,protected_views=10,source_sha256=sha(SOURCE),renderer='Unchanged source-view helper with source/output configuration overrides',boundary='Unmodified actual PNGs are geometry authority. Runtime images are existing capture insets only. No generated concept architecture or fictional states.'))
    verify_protected()
    verify_atlas()


def verify_atlas():
    import subprocess
    data=read(OUT/'plate_manifest.json');frames=read(OUT/'fresh_render_verification.json')
    assert data['room_count']==len(data['rooms'])==24 and len(frames['records'])==48
    assert len(set(data['poi_ids']))==31 and len(data['puzzles'])==7
    protected=verify_protected()
    class Links(HTMLParser):
        def __init__(self):super().__init__();self.links=[];self.ids=[]
        def handle_starttag(self,tag,attrs):
            for key,value in attrs:
                if key in ('href','src'):self.links.append(value)
                if key=='id':self.ids.append(value)
    count=0
    for path in sorted(OUT.rglob('*.html')):
        content=path.read_text(encoding='utf-8');parser=Links();parser.feed(content)
        assert len(parser.ids)==len(set(parser.ids)),path
        assert not any(bad in content for bad in ['\u00c3\u00a2','\u00e2\u20ac\u201d','\ufffd']), ('Encoding',path)
        for link in parser.links:
            name,_,fragment=link.partition('#');target=(path.parent/name).resolve() if name else path
            assert target.is_file(),(path,link)
            if fragment and target.suffix=='.html':
                other=Links();other.feed(target.read_text(encoding='utf-8'));assert fragment in other.ids,(path,link)
            count+=1
        for code in re.findall(r'<script>(.*?)</script>',content,re.S):
            result=subprocess.run(['node','--check','-'],input=code,text=True,capture_output=True)
            assert result.returncode==0,result.stderr
    for row in frames['records']:assert sha(ROOT/row['file'])==row['sha256']
    for stem in {stem for rows in RUNTIME.values() for stem,label in rows}:
        assert sha(REVIEW/(stem+'.png'))==read(REVIEW/(stem+'.json'))['image_sha256'],stem
    write(OUT/'verification.json',dict(status='PASSED_SOURCE_STATIC_ATLAS_CHECKS',rooms=24,fresh_frames=48,poi_ids=31,puzzles=7,ports=46,windows=7,protected_views=10,html_files=len(list(OUT.rglob('*.html'))),local_links=count,utf8=True,javascript_syntax=True,protected_hashes_unchanged=False,protected=protected,source_sha256=sha(SOURCE),builder_sha256=sha(__file__),boundary='471 protected hashes unchanged; one exact documented room brief correction. Source/data/link/syntax checks plus actual fresh renders. Root/Astra visual art review and current-gameplay acceptance remain separate.'))
    print('ROOM_PLATE_ATLAS_VERIFIED',24,48,31,7,'links',count,flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--action', required=True, choices=('render', 'atlas', 'verify'))
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else None)
    if args.action == 'render':
        render()
    elif args.action == 'atlas':
        atlas()
    else:
        verify_atlas()


if __name__ == '__main__':
    main()
