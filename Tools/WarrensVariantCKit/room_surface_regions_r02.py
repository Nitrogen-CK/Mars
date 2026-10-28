"""Reusable source-supported room surface proposal; never edits a map or asset.

Current native source-solid input requires connector and visual review before
any generated mesh is adopted. No surface is invented across an authored void.
"""
import argparse
import collections
import hashlib
import importlib.util
import json
import math
import re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'
GRID=.5
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def geometry_helpers():
    p=Path(__file__).with_name('catacomb_pilot_manifest.py');s=importlib.util.spec_from_file_location('_room_geometry',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--room',required=True);parser.add_argument('--native-solids',required=True);parser.add_argument('--max-local-ceiling-clearance',type=float,default=8);parser.add_argument('--output-name',required=True);a=parser.parse_args();g=geometry_helpers()
    native_path=(ROOT/a.native_solids).resolve();assert native_path.is_relative_to(ROOT.resolve());paths=[ROOT/'Tools/LevelDesign/anchor_plans/data/warrens_v8c.json',native_path,ROOT/'Tools/WarrensVariantCKit/Output/fitted_instances.json'];plan,native,fit=[json.loads(p.read_text()) for p in paths];assert native['status']=='READ_ONLY_CURRENT_ASSEMBLED_NATIVE_SOLIDS' and native['dirty']==dict(maps=[],content=[]);room,=[r for r in plan['rooms'] if r['id']==a.room];z=room['z'];polygon=g.roompoly(room);owned=[polygon]+[g.rectpoly(r['rect']) for r in plan['niches'] if r['id'].startswith(a.room+'-') and abs(r['z']-z)<1e-5];others=[(r['id'],g.roompoly(r)) for r in plan['rooms'] if r['id']!=a.room and abs(r['z']-z)<1e-5]+[(r['id'],g.rectpoly(r['rect'])) for r in plan['niches'] if not r['id'].startswith(a.room+'-') and abs(r['z']-z)<1e-5]
    lo=[min(p[i] for poly in owned for p in poly)-1 for i in (0,1)];hi=[max(p[i] for poly in owned for p in poly)+1 for i in (0,1)];boxes=[]
    for actor in native['actors']:
        match=re.search(r'/LI_Warrens_(\w+)_LevelInstance_',actor['level']);tile=match[1] if match else 'Main'
        for ci,c in enumerate(actor['components']):
            assert c['mesh']=='/Engine/BasicShapes/Cube'
            for index,r in enumerate(c['instances']):
                assert max(abs(v) for v in r['q'][:3])<1e-8 and abs(r['q'][3]-1)<1e-8
                at=[r['at'][0]/100+70,r['at'][1]/100+55,r['at'][2]/100];box=dict(key=f"{tile}:{actor['label']}:{ci}:{index}",tile=tile,label=actor['label'],component=ci,index=index,lo=[at[k]-r['scale'][k]/2 for k in range(3)],hi=[at[k]+r['scale'][k]/2 for k in range(3)])
                if all(box['lo'][i]<hi[i] and box['hi'][i]>lo[i] for i in (0,1)) and box['lo'][2]<z+15 and box['hi'][2]>z-.6:boxes.append(box)
    ceiling_footprints=[]
    for row in fit['placements']:
        if row['role']!='source ceiling seam backing' or not row['id'].startswith('BACKING'):continue
        x,y,_=row['at'];w,h=row['scale'][:2];rect=[x-w/2,y-h/2,x+w/2,y+h/2]
        if rect[0]<hi[0] and rect[2]>lo[0] and rect[1]<hi[1] and rect[3]>lo[1]:ceiling_footprints.append(rect)
    floors=[b for b in boxes if b['label']=='Warrens_Greybox_floor' and abs(b['hi'][2]-z)<1e-5];cells={};excluded=[]
    for b in floors:
        for ix in range(math.floor(max(b['lo'][0],lo[0])/GRID),math.ceil(min(b['hi'][0],hi[0])/GRID)):
            for iy in range(math.floor(max(b['lo'][1],lo[1])/GRID),math.ceil(min(b['hi'][1],hi[1])/GRID)):
                rect=[max(ix*GRID,b['lo'][0]),max(iy*GRID,b['lo'][1]),min((ix+1)*GRID,b['hi'][0]),min((iy+1)*GRID,b['hi'][1])];cp=g.rectpoly(rect);area=g.area(cp);overlap=g.union_overlap(cp,owned)
                if overlap<area*.5-1e-8:continue
                competing=[rid for rid,p in others if g.area(g.clip(p,cp))>1e-7]
                if competing:excluded.append(dict(cell=[ix,iy],competing=competing));continue
                centre=[(rect[0]+rect[2])/2,(rect[1]+rect[3])/2,z+.02]
                if any(g.contains(v,centre) for v in boxes):continue
                assert (ix,iy) not in cells,('Overlapping source floor ownership',ix,iy)
                cells[ix,iy]=dict(cell=[ix,iy],rect=rect,source=b['key'],physical_area=area,nominal_overlap_area=overlap)
    assert cells,'No source-supported cells'
    faces=[];ceilings=[];open_cells=[]
    for (ix,iy),cell in cells.items():
        r=cell['rect'];centre=[(r[0]+r[2])/2,(r[1]+r[3])/2];roofs=[b for b in boxes if z+.05<b['lo'][2]<=z+a.max_local_ceiling_clearance and b['lo'][0]-1e-7<=centre[0]<=b['hi'][0]+1e-7 and b['lo'][1]-1e-7<=centre[1]<=b['hi'][1]+1e-7];top=z+3.5
        if roofs and sum(g.area(g.clip(g.rectpoly(v),g.rectpoly(r))) for v in ceiling_footprints)>=g.area(g.rectpoly(r))-1e-7:
            top=min(b['lo'][2] for b in roofs);owners=sorted(b['key'] for b in roofs if abs(b['lo'][2]-top)<1e-5);ceilings.append(dict(cell=[ix,iy],rect=r,z=top,source_solids=owners))
        else:open_cells.append([ix,iy])
        for axis,sign,neighbor in ((0,-1,(ix-1,iy)),(0,1,(ix+1,iy)),(1,-1,(ix,iy-1)),(1,1,(ix,iy+1))):
            if neighbor in cells:continue
            tangent=1-axis;plane=r[axis] if sign<0 else r[axis+2];tlo,thi=r[tangent],r[tangent+2];p=[0,0,0];p[axis]=plane+sign*.001;p[tangent]=(tlo+thi)/2;outward=[b for b in boxes if b['lo'][axis]-1e-7<=p[axis]<=b['hi'][axis]+1e-7 and b['lo'][tangent]-1e-7<=p[tangent]<=b['hi'][tangent]+1e-7];zs=sorted({z,top}|{round(v,8) for b in outward for v in (b['lo'][2],b['hi'][2]) if z<v<top})
            for za,zb in zip(zs,zs[1:]):
                p[2]=(za+zb)/2;solid=[b for b in outward if g.contains(b,p)];q=list(p);q[axis]=plane-sign*.001
                if solid and not any(g.contains(b,q) for b in boxes):faces.append(dict(axis=axis,normal_sign=-sign,plane=plane,tangent_bounds=[tlo,thi],z_bounds=[za,zb],source_solids=sorted(b['key'] for b in solid)))
    groups=collections.defaultdict(list)
    for f in faces:groups[(f['axis'],f['normal_sign'],f['plane'],*f['z_bounds'])].append(f)
    merged=[]
    for key,group in sorted(groups.items()):
        for f in sorted(group,key=lambda f:f['tangent_bounds'][0]):
            if merged and all(merged[-1][k]==f[k] for k in ('axis','normal_sign','plane','z_bounds')) and abs(merged[-1]['tangent_bounds'][1]-f['tangent_bounds'][0])<1e-6:merged[-1]['tangent_bounds'][1]=f['tangent_bounds'][1];merged[-1]['source_solids']=sorted(set(merged[-1]['source_solids']+f['source_solids']))
            else:merged.append(f)
    assert re.fullmatch(r'[a-z0-9-]+',a.output_name);out=DOC/a.output_name;out.mkdir(parents=True,exist_ok=False);result=dict(status='CURRENT_NATIVE_SOURCE_SUPPORTED_REGIONS_CONNECTOR_AND_VISUAL_REVIEW_REQUIRED',room=room,grid_metres=GRID,source_boxes=boxes,admitted_floor_cells=list(cells.values()),excluded_competing_cells=excluded,wall_faces=merged,ceiling_faces=ceilings,source_open_overhead_cells=open_cells,inputs={p.relative_to(ROOT).as_posix():sha(p) for p in paths},tool_sha256=sha(__file__),requires_native_solid_pose_witness=False,local_ceiling_clearance_max_metres=a.max_local_ceiling_clearance,ceiling_ownership='Current native support within declared local height AND source-fitted ceiling footprint; remote wallcaps never close roof break',connector_transition_review_required=True,boundary='Derived proposal only. Floor cells use room/niche physical coverage; surfaces require actual source solid support. No ceiling over uncovered source cells. Connector transition clipping and current native solid reconciliation remain release gates. No meshes/imports/source/native/library files changed.')
    (out/'room_regions.json').write_text(json.dumps(result,indent=2)+'\n');print('ROOM_REGIONS',a.room,len(cells),'floor',len(merged),'wall regions',len(ceilings),'supported ceiling cells',len(open_cells),'open overhead')
if __name__=='__main__':main()
