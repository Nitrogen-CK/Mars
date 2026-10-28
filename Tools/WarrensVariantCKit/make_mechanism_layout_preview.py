"""Read-only P1/P5 source-box SVG review. Never imports Unreal or Blender."""
import argparse
from datetime import datetime, timezone
import hashlib
import html
import json
import math
import os
from pathlib import Path
import textwrap
import uuid

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
REVIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024'
OUT = REVIEW / 'mechanism-layout-preview/r01'
MANIFEST = ROOT / 'Saved/AnchorPlans/v8c-manifest.json'
FIT_SHA = 'ebc3ef56c09eb0126fa35707c8b2f4a231aeb61a8df776a6debccdd2be6ea546'
SOURCE_SHA = '2fb8dfdfbf1a3ad1a5e019204fc679d827eda137381f4b86934fd7b71dbcc7dc'
IMAGES = {
    'P5': ['ART_observe_p5_barred_arrival', 'ART_observe_p5_loft_lever'],
    'P1': ['ART_held_p1_lock_held_inspection', 'mechanism-observations/p1_lock_closed_key_held'],
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def e(value):
    return html.escape(str(value), quote=True)


def fmt(values):
    return '[' + ', '.join(f'{v:g}' for v in values) + ']'


def axes(pitch, yaw):
    p, y = math.radians(pitch), math.radians(yaw)
    return ((math.cos(p)*math.cos(y), math.cos(p)*math.sin(y), math.sin(p)),
            (-math.sin(y), math.cos(y), 0),
            (-math.sin(p)*math.cos(y), -math.sin(p)*math.sin(y), math.cos(p)))


def transformed(root, offset, pitch, yaw):
    basis = axes(pitch, yaw)
    return [root[i] + sum(offset[j]*basis[j][i] for j in range(3)) for i in range(3)]


def envelope(root, center, half, pitch, yaw):
    return [transformed(root, [center[i]+sign[i]*half[i] for i in range(3)], pitch, yaw)
            for sign in ((x,y,z) for x in (-1,1) for y in (-1,1) for z in (-1,1))]


def source_boxes(manifest, bounds, z=None, section_x=None):
    # Axis-aligned source wall/floor boxes are drawn at their full actual bounds.
    # Sloped/rotated geometry is intentionally omitted and never reconstructed.
    rows = []
    for index, box in enumerate(manifest['boxes']):
        if box['kind'] not in ('wall', 'floor', 'plinth') or box.get('yaw',0) or box.get('pitch',0):
            continue
        low = [c-s*.5 for c,s in zip(box['centre'],box['size'])]
        high = [c+s*.5 for c,s in zip(box['centre'],box['size'])]
        if section_x is None:
            if not low[2]-.00001 <= z <= high[2]+.00001:
                continue
            a,b = (low[0],low[1]),(high[0],high[1])
        else:
            if not low[0]-.00001 <= section_x <= high[0]+.00001:
                continue
            a,b = (low[1],low[2]),(high[1],high[2])
        if b[0] < bounds[0] or a[0] > bounds[2] or b[1] < bounds[1] or a[1] > bounds[3]:
            continue
        rows.append(dict(index=index,box=box,low=low,high=high,a=a,b=b))
    return sorted(rows,key=lambda r:r['box']['kind']=='wall')


class Diagram:
    def __init__(self, title, bounds, ident, section=False):
        self.bounds,self.section = bounds,section
        self.width,self.height = (1000,480) if section else (650,690)
        self.scale = min((self.width-130)/(bounds[2]-bounds[0]),(self.height-150)/(bounds[3]-bounds[1]))
        self.left,self.top = 60,65
        self.parts = [f'<svg viewBox="0 0 {self.width} {self.height}" role="img" aria-label="{e(title)}"><defs><clipPath id="{ident}"><rect x="45" y="45" width="{self.width-70}" height="{self.height-110}"/></clipPath></defs>',
                      f'<rect width="{self.width}" height="{self.height}" fill="#f5f3ed"/>',f'<text x="25" y="27" class="title">{e(title)}</text>',f'<g clip-path="url(#{ident})">']
        self.axis_labels=[]
        for a in range(math.ceil(bounds[0]),math.floor(bounds[2])+1):
            self.line((a,bounds[1]),(a,bounds[3]),'#d9d7d0',width=.6)
            if not section and bounds[2]-bounds[0]>10 and a%2:
                continue
            x,y=self.point(a,bounds[1] if not section else bounds[3])
            self.axis_labels.append(f'<text x="{x-8}" y="{y-15}" class="label">{a}</text>')
        for b in range(math.ceil(bounds[1]),math.floor(bounds[3])+1):
            self.line((bounds[0],b),(bounds[2],b),'#d9d7d0',width=.6)
            x,y=self.point(bounds[0],b)
            self.axis_labels.append(f'<text x="{x-38}" y="{y+5}" class="label">{b}</text>')

    def point(self,a,b):
        x = self.left+(a-self.bounds[0])*self.scale
        y = self.top+((self.bounds[3]-b) if self.section else (b-self.bounds[1]))*self.scale
        return x,y

    def line(self,a,b,color='#444',dash='',width=2):
        x,y=self.point(*a); xx,yy=self.point(*b)
        self.parts.append(f'<line x1="{x}" y1="{y}" x2="{xx}" y2="{yy}" stroke="{color}" stroke-width="{width}" stroke-dasharray="{dash}"/>')

    def rect(self,a,b,color,stroke='#666',dash='',title=''):
        x,y=self.point(*a); xx,yy=self.point(*b)
        self.parts.append(f'<rect x="{min(x,xx)}" y="{min(y,yy)}" width="{abs(xx-x)}" height="{abs(yy-y)}" fill="{color}" stroke="{stroke}" stroke-dasharray="{dash}"><title>{e(title)}</title></rect>')

    def label(self,a,b,text,color='#222',dx=8,dy=-8):
        if not hasattr(self,'callouts'):
            self.callouts={}
        key=(a,b)
        if key in self.callouts:
            self.callouts[key]['text']+='; '+text
        else:
            self.callouts[key]=dict(text=text,color=color)

    def dot(self,a,b,color,r=4):
        x,y=self.point(a,b)
        self.parts.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{color}"/>')

    def arrow(self,a,b,color):
        self.line(a,b,color,width=3)
        x,y=self.point(*a);xx,yy=self.point(*b);angle=math.atan2(yy-y,xx-x)
        points=[(xx,yy),(xx-11*math.cos(angle-.4),yy-11*math.sin(angle-.4)),(xx-11*math.cos(angle+.4),yy-11*math.sin(angle+.4))]
        self.parts.append('<polygon fill="'+color+'" points="'+' '.join(f'{u},{v}' for u,v in points)+'"/>')

    def finish(self,note):
        self.parts += ['</g>']+self.axis_labels
        rows=math.ceil(len(self.callouts)/2)
        callout_top=self.height-15
        legend_top=callout_top+rows*65+10
        canvas_height=legend_top+65
        self.parts[0]=self.parts[0].replace(f'viewBox="0 0 {self.width} {self.height}"',f'viewBox="0 0 {self.width} {canvas_height}"')
        self.parts[1]=self.parts[1].replace(f'height="{self.height}"',f'height="{canvas_height}"')
        markers=[]
        for index,((a,b),record) in enumerate(self.callouts.items()):
            number=index+1
            x,y=self.point(a,b)
            column=index%2
            row=index//2
            anchor_x=25+column*self.width/2
            anchor_y=callout_top+row*65
            color=record['color']
            self.parts.append(f'<polyline points="{x},{y} {x},{self.height-65} {anchor_x},{anchor_y-14}" fill="none" stroke="{color}" stroke-width="1" opacity=".45"/>')
            markers.append(f'<circle cx="{x}" cy="{y}" r="9" fill="#f5f3ed" stroke="{color}"/><text x="{x}" y="{y+4}" text-anchor="middle" font-family="sans-serif" font-size="12" fill="{color}">{number}</text>')
            self.parts.append(f'<text x="{anchor_x}" y="{anchor_y}" fill="{color}" class="label">{number}.</text>')
            lines=textwrap.wrap(record['text'],width=int((self.width/2-55)/9))
            for line_number,line in enumerate(lines):
                self.parts.append(f'<text x="{anchor_x+23}" y="{anchor_y+line_number*17}" fill="{color}" class="label">{e(line)}</text>')
        self.parts+=markers
        for i,line in enumerate(note.split('; ')):
            self.parts.append(f'<text x="25" y="{legend_top+i*16}" class="legend">{e(line)}</text>')
        self.parts.append('</svg>')
        return ''.join(self.parts)


def panel(manifest, puzzle, root, pitch, yaw, state, fit, section=False):
    proposed = state=='proposed'
    color = '#007d87' if proposed else '#bf4036'
    if puzzle=='P5':
        bounds = (53,-.5,77,6) if section else (90,53,109,77)
        section_x = root[0] if section else None
        z = 2.5
    else:
        bounds = (57.5,-5.5,62,-.4) if section else (54.8,57.5,59,62)
        section_x = root[0] if section else None
        z = -4
    mode = f'Section x={root[0]:g} m; horizontal=plan Y, vertical=Z' if section else f'Plan XY; source-box slice z={z:g} m'
    drawing = Diagram(f'{puzzle} | '+('PROPOSED AFTER' if proposed else 'BEFORE')+' | '+mode,bounds,puzzle+state+str(section),section)
    boxes = source_boxes(manifest,bounds,z,section_x)
    for row in boxes:
        key=row['index']; special=key in (2903,6441,6455)
        drawing.rect(row['a'],row['b'],'#b9b6ae' if row['box']['kind']=='wall' else '#e0dfd6',
                     '#9c3b36' if special else '#aaa',title=f"box {key} {row['box']['kind']} {fmt(row['low'])} to {fmt(row['high'])}")
        if special:
            a,b=row['a'],row['b']
            anchor=((max(a[0],bounds[0])+min(b[0],bounds[2]))*.5,
                    (max(a[1],bounds[1])+min(b[1],bounds[3]))*.5)
            if section and key in (6441,6455):
                anchor=(anchor[0],-2.2 if key==6441 else -3.0)
            drawing.label(*anchor,'wall '+str(key),'#84322e')
    project = (lambda p:(p[1],p[2])) if section else (lambda p:(p[0],p[1]))
    if puzzle=='P1':
        plate = envelope(root,[0,0,.03],[.2,.2,.03],pitch,yaw)
        probe = envelope(root,[0,0,.1],[.3,.3,.2],pitch,yaw)
        gate = [57,60,-5]
        a,b = project([56.8,58.8,-5]),project([57.2,61.2,-2.6])
        drawing.rect(a,b,'#e9cb7955','#9f711f','7 5','Unchanged gate source frame envelope: 40cm depth, 240cm outside width/height')
        drawing.label(*project(gate),'gate projected x=57; z=-5' if section else 'gate unchanged z=-5','#845c13',dy=20)
        camera=fit['p1']['current_lock_and_face_los']['camera_plan']
        target=fit['p1']['current_lock_and_face_los']['candidate_face_target' if proposed else 'current_face_target']
        drawing.line(project(camera),project(target),'#218a50' if proposed else '#bf4036','5 4')
        drawing.dot(*project(camera),'#444')
        drawing.label(*project(camera),'saved camera','#444',dx=-105,dy=-12)
        normal=axes(pitch,yaw)[2]
        face_end=[root[i]+normal[i]*.7 for i in range(3)]
        if not section and not proposed:
            drawing.label(*project(root),'face +Z (up)','#bf4036',dy=28)
        else:
            drawing.arrow(project(root),project(face_end),color)
    else:
        # Lever probe is authored half-extents40/40/55cm, center45cm above root.
        plate = envelope(root,[0,0,0],[.12,.25,.12],pitch,yaw)
        probe = envelope(root,[0,0,.45],[.4,.4,.55],pitch,yaw)
        ladder=[100,57,0]
        if section:
            drawing.line((57,0),(57,2.5),'#a47415',dash='7 5',width=5)
            drawing.label(57,1.3,'projected ladder x100 / gate x98.75','#845c13',dx=10,dy=0)
            drawing.line((57,0),(57,2.2),'#705718',dash='4 4',width=9)
        else:
            drawing.dot(*project(ladder),'#a47415',r=6)
            drawing.label(*project(ladder),'ladder [100,57,0]','#845c13',dx=-120,dy=-12)
            drawing.line((98.75,56),(98.75,58),'#705718',width=5)
            drawing.label(98.75,56,'barred foot [98.75,57,0]','#845c13',dx=-150,dy=-12)
            if proposed:
                start=fit['p5']['candidate_stair_head']
                drawing.arrow(project(start),project(root),'#218a50')
                drawing.label(*project(start),'measured stair-head approach','#236e41',dx=-100,dy=-14)
        direction=axes(pitch,yaw)[0]
        drawing.arrow(project(root),project([root[i]-direction[i]*.75 for i in range(3)]),color)
        if not section:
            drawing.label(*project(root),'handle tips local -X',color,dx=10,dy=32)
        else:
            drawing.line(project(root),project([root[0],root[1],root[2]+.9]),color,width=4)
    for points,fill,stroke,dash,title in ((probe,'#49a3d526','#388bbb','5 3','Source interaction probe envelope'),
                                          (plate,color+'77',color,'','Source control body envelope')):
        projected=[project(p) for p in points]
        drawing.rect((min(p[0] for p in projected),min(p[1] for p in projected)),
                     (max(p[0] for p in projected),max(p[1] for p in projected)),fill,stroke,dash,title)
    drawing.dot(*project(root),color,6)
    drawing.label(*project(root),('new ' if proposed else 'current ')+fmt(root),color,dx=10,dy=-18)
    note = 'Grid in metres; Exact wall/floor boxes, slopes/details omitted; Blue dash: probe. Off-slice gate/ladder are projected diagrams.'
    return drawing.finish(note),[r['index'] for r in boxes]


def inset(stem):
    path = REVIEW/(stem+'.json')
    record = read(path)
    image = REVIEW/(stem+'.png')
    assert sha(image)==record['image_sha256']
    relative = os.path.relpath(image,OUT).replace('\\','/')
    return '<figure><img src="'+e(relative)+'"><figcaption>Actual current PIE: '+e(stem.split('/')[-1])+'. '+e(record['boundary'])+'</figcaption></figure>'


def main():
    global OUT
    parser=argparse.ArgumentParser()
    parser.add_argument('--fit-receipt',required=True)
    parser.add_argument('--fit-sha256',required=True)
    parser.add_argument('--revision',choices=('r01','r02'),default='r02')
    parser.add_argument('--refresh-r02-receipt',help='Preserve an existing r02 draft receipt and QA while refreshing its presentation.')
    args=parser.parse_args()
    OUT=REVIEW/'mechanism-layout-preview'/args.revision
    path=(ROOT/args.fit_receipt).resolve()
    assert path.is_relative_to((ROOT/'Saved/WarrensCGameplay-20261024/P1P5MechanismFit').resolve())
    assert args.fit_sha256==FIT_SHA==sha(path)
    refresh=None
    if OUT.exists():
        assert args.revision=='r02' and args.refresh_r02_receipt
        refresh_path=(ROOT/args.refresh_r02_receipt).resolve()
        assert refresh_path.parent==OUT.resolve() and refresh_path.name.startswith('receipt_')
        refresh=read(refresh_path)
        assert refresh['revision']=='r02' and refresh['fit']['sha256']==FIT_SHA
        assert refresh['manifest_sha256']==sha(MANIFEST)
        assert sha(ROOT/refresh['output']['file'])==refresh['output']['sha256']
        assert all(sha(ROOT/p)==h for p,h in refresh['protected'].items())
    else:
        assert not args.refresh_r02_receipt
    fit=read(path)
    assert fit['status']=='SOURCE_GEOMETRY_SURVEY_COMPLETE' and fit['source_sha256']==SOURCE_SHA==sha(ROOT/fit['source'])
    assert all(sha(ROOT/p)==h for p,h in fit['inputs'].items())
    manifest=read(MANIFEST)
    old5,=[r for r in manifest['entities'] if r.get('note')=='P5 lever']
    old1,=[r for r in manifest['entities'] if r.get('note')=='vault lock']
    gate5,=[r for r in manifest['entities'] if r.get('note')=='P5 barred foot of belfry-ladder']
    gate1,=[r for r in manifest['entities'] if r.get('note')=='vault door']
    assert old5['at']==[102,60,2.5] and old1['at']==[56,58.3,-5]
    assert gate5['at']==[98.75,57,0] and gate1['at']==[57,60,-5]
    assert manifest['boxes'][2903]['centre']==[102.75,68,2.1]
    assert manifest['boxes'][6441]['centre']==[56.75,55.75,-2.9] and manifest['boxes'][6455]['centre']==[55.75,57.5,-2.9]
    assert fit['p5']['proposed_lever_root']==[93,73.5,2.503] and fit['p1']['candidate_mount']==[56.5,58.512,-4]
    p5=fit['p5'];p1=fit['p1']
    assert p1['face_orientation']['candidate_pitch']==-90 and p1['face_orientation']['candidate_yaw']==90
    assert len(p5['floor_footprint_rays'])==9 and all(r['ray']['hit'] for r in p5['floor_footprint_rays'])
    assert len(p5['approach_floor_rays'])==13 and all(r['ray']['hit'] for r in p5['approach_floor_rays'])
    assert len(p5['body_height_clearance_rays'])==8 and not any(r['ray']['hit'] for r in p5['body_height_clearance_rays'])
    assert p5['source_eye_to_candidate_sight']['hit'] is False
    assert len(p1['candidate_wall_support_rays'])==5 and all(r['ray']['hit'] for r in p1['candidate_wall_support_rays'])
    assert len(p1['candidate_wall_grid'])==9 and all(r['ray']['hit'] for r in p1['candidate_wall_grid'])
    assert p1['current_lock_and_face_los']['current_los']['hit'] is True and p1['current_lock_and_face_los']['candidate_los']['hit'] is False
    paths=[MANIFEST,path,ROOT/fit['source'],HERE/'probe_mechanism_fit.py',
           ROOT/'Tools/LevelDesign/anchor_plans/design_warrens_v8c.py']
    paths += [ROOT/p for p in fit['inputs']]
    paths += [HERE/'../../Script/WorldObjects/Mechanisms'/name for name in ('Mars_KeyLock_EntityScript.as','Mars_Lever_EntityScript.as','Mars_Gate_EntityScript.as')]
    paths += list((ROOT/'Content/Mars/Maps/Variants/v8c').glob('*.umap'))
    paths += [ROOT/'Content/Mars/Maps/Warrens_VariantC_Mars_MAP.umap']
    paths += [REVIEW/(stem+suffix) for stems in IMAGES.values() for stem in stems for suffix in ('.json','.png')]
    prior=None
    if args.revision=='r02':
        prior_folder=REVIEW/'mechanism-layout-preview/r01'
        prior_receipt,=prior_folder.glob('receipt_*.json')
        prior=read(prior_receipt)
        assert prior['fit']['sha256']==FIT_SHA and prior['manifest_sha256']==sha(MANIFEST)
        assert sha(ROOT/prior['output']['file'])==prior['output']['sha256']
        assert all(sha(ROOT/p)==h for p,h in prior['protected'].items())
        paths += [p for p in prior_folder.rglob('*') if p.is_file()]
    guards={p.resolve():sha(p) for p in paths}
    sections=[];diagrams=[]
    for puzzle,title,old,proposed in [('P5','P5: accessible remote unlock, unchanged barred ladder',old5,p5['proposed_lever_root']),
                                     ('P1','P1: exposed north wall mount, unchanged Vault gate',old1,p1['candidate_mount'])]:
        svgs=[]
        for section in (False,True):
            pair=[]
            for state,at,pitch,yaw in [('before',old['at'],old.get('pitch',0),old['yaw']),
                                      ('proposed',proposed,-90 if puzzle=='P1' else 0,90 if puzzle=='P1' else 0)]:
                svg,indices=panel(manifest,puzzle,at,pitch,yaw,state,fit,section)
                pair.append(svg)
                diagrams.append(dict(puzzle=puzzle,state=state,mode='section' if section else 'plan',root=at,pitch=pitch,yaw=yaw,source_box_indices=indices))
            svgs.append('<div class="pair">'+''.join(pair)+'</div>')
        if puzzle=='P5':
            text='Current lever [102,60,2.5] is on the inaccessible loft. Source wall2903 spans X97.5..108 / Y64..72 / Z-0.4..4.6; it blocks the claimed incoming north rail-drop. The ladder gate is opened by that same loft lever: the first-access cycle has no verified incoming rail-drop. The rejected 13 m new corridor is not proposed here. Relocate the same lever to Reliquary [93,73.5,2.503], yaw0, keeping Mechanism.Channel.Warrens.Puzzle.P5. This changes the meaning to a remote unlock; both ladder and gate remain in Belfry. Proposed owner: Reliquary LI.'
            floors=[r['ray']['location'][2] for r in p5['floor_footprint_rays']]
            details=f"Static survey: 9 footprint floor hits Z{min(floors):.3f}..{max(floors):.3f}; 13 approach floor hits from {fmt(p5['candidate_stair_head'])}; eight 0.35 m body-height rays and stair-head LOS clear. Source probe half-extents40/40/55 cm, center45 cm above root; base diameter24 cm, axle50 cm; handle90 cm. No runtime capsule, lever sweep or control reach has been tested at the new pose."
        else:
            text='Current Pit lock [56,58.3,-5], pitch0/yaw90 faces upward (+Z), buried among source walls6441/6455. Proposed Pit lock [56.5,58.512,-4], pitch-90/yaw90 has local+Z facing plan+Y. It mounts on wall6441 north face, one metre above the Pit floor. Keep the same Red key contract, kept key, channel and gate [57,60,-5]. No wall/floor/gate cuts or new door are proposed.'
            gaps=[(p1['candidate_mount'][1]-r['ray']['location'][1])*1000 for r in p1['candidate_wall_support_rays']]
            estimates=p1['gate_dimensions']['frame_clearance_estimate_cm']
            details=f"Static survey: five back support points plus 3x3 wall grid; masonry relief gap {min(gaps):.1f}..{max(gaps):.1f} mm. Existing saved camera LOS is occluded at the old upward face, clear to the proposed face. Estimated gate-frame separation: X {estimates['x_to_gate_front']:.1f} cm, nearest post {estimates['y_to_near_post']:.1f} cm. Source plate40x40x6 cm; ring24 cm; interaction probe half-extents30/30/20 cm at local Z10 cm. Gate/lock/probe fit still requires actual runtime observation."
        sections.append('<section><h2>'+e(title)+'</h2><p>'+e(text)+'</p>'+''.join(svgs)+'<p class="measure">'+e(details)+'</p><div class="pair">'+''.join(inset(s) for s in IMAGES[puzzle])+'</div></section>')
    token=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S')+'_'+uuid.uuid4().hex[:8]
    receipt_name='receipt_'+token+'.json'
    page='''<!doctype html><html lang="en"><meta charset="utf-8"><title>P1/P5 mechanism layout proposal</title><style>
body{background:#1b1f24;color:#e7e3db;font:16px/1.55 system-ui;max-width:1600px;margin:24px auto;padding:0 22px}h1,h2{font-weight:600}.pair{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin:16px 0}.pair svg{width:100%;height:auto;background:#f5f3ed}.title{font:bold 16px sans-serif;fill:#242424}.label{font:14px sans-serif;paint-order:stroke;stroke:#f5f3ed;stroke-width:3px;stroke-linejoin:round}.legend{font:12px sans-serif;fill:#343434}section{margin:38px 0}.measure{padding:14px;background:#293039}figure{margin:0}img{width:100%;display:block}figcaption{padding:10px;font-size:13px;background:#293039}a{color:#a6d9ed}code{overflow-wrap:anywhere}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style>
<h1>P5 lever / P1 lock: concrete layout proposal</h1><p><strong>Source SVG diagrams, not screenshots of proposed runtime actors.</strong> Before uses the current emitted C manifest. Proposed after changes only the two control poses shown. All gray wall/floor rectangles come from exact manifest box bounds; no invented corridor or reconstructed wall. Diagram control/probe envelopes are source dimensions, not spawned components.</p><p>Red = current control; cyan = proposed control; blue dashed = interaction probe; ochre = unchanged gate/ladder envelope. Sections explicitly change their X slice to pass through each control. Static fit rays are evidence for source support and sightlines only. New poses have no runtime collision, interaction, sweep, visual or first-access acceptance and are not adopted.</p>'''
    page+=''.join(sections)+'<footer><p>Inputs: <a href="'+e(os.path.relpath(path,OUT).replace('\\','/'))+'">pinned fit receipt</a>; <a href="'+receipt_name+'">preview receipt and protected hashes</a>. No live/editor/Blender calls or original writes. These diagrams do not change art materials, mechanism channels, gates, ladders, pickups or rewards.</p>'
    if prior is not None:
        assert diagrams==prior['diagrams']
        page+='<p>r02 changes label spacing and external callouts only. <a href="../r01/PREVIEW.html">Frozen r01 geometry/evidence reference</a>.</p>'
    if refresh is not None:
        assert diagrams==refresh['diagrams'] and refresh['source_boxes']=={str(i):manifest['boxes'][i] for i in (2903,6441,6455)}
    page+='</footer></html>'
    assert all(sha(p)==expected for p,expected in guards.items())
    OUT.mkdir(parents=True,exist_ok=refresh is not None)
    target=OUT/'PREVIEW.html'
    target.write_text(page,encoding='utf-8')
    receipt=dict(status='SOURCE_SVG_LAYOUT_PROPOSAL_REVIEW_REQUIRED',tool_sha256=sha(__file__),
        revision=args.revision,previous_revision=None if prior is None else dict(file=prior_receipt.relative_to(ROOT).as_posix(),sha256=sha(prior_receipt),geometry_and_evidence_equal=True),
        previous_layout_draft=None if refresh is None else dict(file=refresh_path.relative_to(ROOT).as_posix(),sha256=sha(refresh_path)),
        fit=dict(file=args.fit_receipt,sha256=FIT_SHA),manifest_sha256=sha(MANIFEST),
        protected={p.relative_to(ROOT).as_posix():h for p,h in guards.items()},
        diagrams=diagrams,source_boxes={str(i):manifest['boxes'][i] for i in (2903,6441,6455)},
        output=dict(file=target.relative_to(ROOT).as_posix(),sha256=sha(target)),
        boundary='Only a geometric source mockup and linked current runtime insets. New P5/P1 poses and remote-unlock semantics need review; no live adoption or runtime proof.')
    (OUT/receipt_name).write_text(json.dumps(receipt,sort_keys=True,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    assert all(sha(p)==expected for p,expected in guards.items())
    print(json.dumps(dict(status=receipt['status'],preview=str(target),receipt=receipt_name,receipt_sha256=sha(OUT/receipt_name),guarded_files=len(guards),diagrams=len(diagrams)),indent=2))


if __name__=='__main__':
    main()
