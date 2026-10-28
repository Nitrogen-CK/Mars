"""Finite physical-cell ownership and exposed solid-union faces for one room.

Reads verified source geometry only. All products are derived review files.
"""
import argparse,hashlib,json,math,itertools
from collections import Counter,defaultdict
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02'
GRID=.5
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def area(p):return abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(p,p[1:]+p[:1])))/2 if p else 0
def signed(p):return sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(p,p[1:]+p[:1]))
def clip(poly,convex):
    result=poly;sgn=1 if signed(convex)>0 else -1
    for a,b in zip(convex,convex[1:]+convex[:1]):
        source=result;result=[]
        if not source:break
        def distance(p):return sgn*((b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0]))
        old=source[-1];od=distance(old)
        for p in source:
            d=distance(p)
            if (d>=0)!=(od>=0):
                t=od/(od-d);result.append([old[i]+(p[i]-old[i])*t for i in range(2)])
            if d>=0:result.append(p)
            old,od=p,d
    return result
def rectpoly(r):return [[r[0],r[1]],[r[2],r[1]],[r[2],r[3]],[r[0],r[3]]]
def roompoly(r):return r.get('poly') or (rectpoly(r['rect']) if 'rect'in r else None)
def union_overlap(subject,regions):
    total=0
    for size in range(1,len(regions)+1):
        for group in itertools.combinations(regions,size):
            q=subject
            for region in group:q=clip(q,region)
            total+=(1 if size%2 else -1)*area(q)
    return total
def source_boxes(baseline):
    result=[]
    for tile in baseline:
        b=baseline[tile]
        for a in b['actors']:
            if a['label'] not in ('Warrens_Greybox_wall','Warrens_Greybox_floor','Warrens_Greybox_roof'):continue
            for comp in a['components']:
                assert comp['mesh'].split('.')[0]=='/Engine/BasicShapes/Cube'
                for i,r in enumerate(comp.get('instances',[])):
                    assert max(abs(v) for v in r['rotation'])<1e-5
                    at=[r['at'][k]/100+b['pivot'][k] for k in range(3)]
                    box=dict(key=f"{tile}:{a['label']}:{i}",tile=tile,label=a['label'],index=i,
                        lo=[at[k]-r['scale'][k]/2 for k in range(3)],hi=[at[k]+r['scale'][k]/2 for k in range(3)])
                    # Scope structural context by bounds, not ownership tile:
                    # Main owns the rear wall; Court can own the east niche.
                    if box['lo'][0]<2 and box['hi'][0]>-30 and box['lo'][1]<93 and box['hi'][1]>61 and box['lo'][2]<5 and box['hi'][2]>-.6:result.append(box)
    return result
def contains(b,p):return all(b['lo'][i]-1e-7<=p[i]<=b['hi'][i]+1e-7 for i in range(3))
def connectors(plan,target):
    result=[];nodes=plan['nodes']
    paths=[]
    for i,l in enumerate(plan['links']):
        a,b=nodes[l['a']],nodes[l['b']]
        pts=[a]+[[v[0],v[1],a[2]+(b[2]-a[2])*(j+1)/(len(l.get('via',[]))+1)] for j,v in enumerate(l.get('via',[]))]+[b]
        paths.append((f'link:{i}:{l["a"]}-{l["b"]}',pts,l['width']))
    for kind in ('extraRamps','crawls'):
        for i,r in enumerate(plan[kind]):
            a,b=r['a'],r['b'];z=r.get('z',a[2] if len(a)>2 else 0)
            aa=[a[0],a[1],a[2] if len(a)>2 else z];bb=[b[0],b[1],b[2] if len(b)>2 else z]
            pts=[aa]+[[v[0],v[1],z] for v in r.get('via',[])]+[bb]
            paths.append((f'{kind}:{r.get("id",i)}',pts,r.get('width',.8)))
    for name,pts,width in paths:
        for i,(a,b) in enumerate(zip(pts,pts[1:])):
            if min(abs(a[2]),abs(b[2]))>.6:continue
            dx,dy=b[0]-a[0],b[1]-a[1];n=math.hypot(dx,dy)
            if n<1e-8:continue
            nx,ny=-dy/n*width/2,dx/n*width/2
            poly=[[a[0]+nx,a[1]+ny],[a[0]-nx,a[1]-ny],[b[0]-nx,b[1]-ny],[b[0]+nx,b[1]+ny]]
            if max(p[0] for p in poly)<-25 or min(p[0] for p in poly)>-3 or max(p[1] for p in poly)<63 or min(p[1] for p in poly)>89:continue
            result.append(dict(key=name+':'+str(i),poly=poly,z_range=[a[2],b[2]]))
    return result
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',required=True);args=parser.parse_args()
    out=(ROOT/args.output).resolve();assert out.is_relative_to(DOC.resolve()) and not out.exists()
    paths=dict(baseline=ROOT/'Tools/WarrensVariantCKit/Output/Reports/full_source_baseline.json',
        plan=ROOT/'Tools/LevelDesign/anchor_plans/data/warrens_v8c.json',
        native=ROOT/'Saved/WarrensCGameplay-20261024/catacomb_native_main_walls_r02.json',
        fit=ROOT/'Tools/WarrensVariantCKit/Output/fitted_instances.json')
    data={k:json.loads(p.read_text()) for k,p in paths.items()};baseline,plan=data['baseline'],data['plan']
    old=next(a for a in baseline['Main']['actors'] if a['label']=='Warrens_Greybox_wall')['components'][0]['instances']
    assert old==data['native']['instances'] and not data['native']['dirty_maps']
    room=next(r for r in plan['rooms'] if r['id']=='catacomb');poly=roompoly(room)
    niches=[r for r in plan['niches'] if r['id'].startswith('catacomb-') and abs(r['z'])<1e-5]
    regions=[poly]+[rectpoly(r['rect']) for r in niches]
    assert all(((poly[(i+1)%len(poly)][0]-poly[i][0])*(poly[(i+2)%len(poly)][1]-poly[(i+1)%len(poly)][1])-(poly[(i+1)%len(poly)][1]-poly[i][1])*(poly[(i+2)%len(poly)][0]-poly[(i+1)%len(poly)][0]))>0 for i in range(len(poly)))
    others=[(r['id'],roompoly(r)) for r in plan['rooms'] if r['id']!='catacomb' and abs(r['z'])<1e-5 and roompoly(r)]
    others += [(r['id'],rectpoly(r['rect'])) for r in plan['niches'] if not r['id'].startswith('catacomb-') and abs(r['z'])<1e-5]
    boxes=source_boxes(baseline);lookup={b['key']:b for b in boxes};cons=connectors(plan,poly)
    floors=[b for b in boxes if b['label']=='Warrens_Greybox_floor' and abs(b['hi'][2])<1e-5]
    cells={};excluded=[]
    for b in floors:
        for ix in range(math.floor(b['lo'][0]/GRID),math.ceil(b['hi'][0]/GRID)):
            for iy in range(math.floor(b['lo'][1]/GRID),math.ceil(b['hi'][1]/GRID)):
                r=[max(ix*GRID,b['lo'][0]),max(iy*GRID,b['lo'][1]),min((ix+1)*GRID,b['hi'][0]),min((iy+1)*GRID,b['hi'][1])]
                cp=rectpoly(r);a=area(cp);overlap=union_overlap(cp,regions)
                # Native raster boundary cells whose ideal polygon divides
                # them exactly in half remain supported room surface. r01
                # excluded the equality case, exposing known wall91 strips.
                if overlap<a*.5-1e-8:continue
                competing=[rid for rid,p in others if area(clip(p,cp))>1e-7]
                crossing=[]
                for c in cons:
                    q=clip(c['poly'],cp)
                    if area(q)-union_overlap(q,regions)>1e-7:crossing.append(c['key'])
                if competing or crossing:
                    excluded.append(dict(cell=[ix,iy],rect=r,source=b['key'],competing_rooms=competing,outside_connectors=crossing));continue
                assert (ix,iy) not in cells,('Source floors overlap',ix,iy)
                center=[(r[0]+r[2])/2,(r[1]+r[3])/2,.02]
                solids=[v['key'] for v in boxes if contains(v,center)]
                if solids:continue
                cells[ix,iy]=dict(cell=[ix,iy],rect=r,source=b['key'],nominal_overlap_area=overlap,physical_area=a,
                    full_footprint_competing_rooms=competing,full_footprint_outside_connector_overlap=crossing)
    assert len(cells)>100
    # Source solid union faces exactly at the admitted physical floor boundary.
    faces=[];ceilings=[]
    for (ix,iy),cell in cells.items():
        r=cell['rect'];center=[(r[0]+r[2])/2,(r[1]+r[3])/2]
        roofs=[b for b in boxes if b['lo'][2]>.05 and b['lo'][0]-1e-7<=center[0]<=b['hi'][0]+1e-7 and b['lo'][1]-1e-7<=center[1]<=b['hi'][1]+1e-7]
        top=3.5
        if roofs:
            z=min(b['lo'][2] for b in roofs);owners=[b['key'] for b in roofs if abs(b['lo'][2]-z)<1e-5]
            assert 2.2<=z<=10,('Unreviewed source clearance',cell,z)
            top=z;ceilings.append(dict(rect=r,z=z,source_solids=owners,floor_source=cell['source'],cell=[ix,iy]))
        for axis,sign,neighbor in ((0,-1,(ix-1,iy)),(0,1,(ix+1,iy)),(1,-1,(ix,iy-1)),(1,1,(ix,iy+1))):
            if neighbor in cells:continue
            tangent=1-axis;plane=r[axis] if sign<0 else r[axis+2];tlo,thi=r[tangent],r[tangent+2]
            p=[0,0,0];p[axis]=plane+sign*.001;p[tangent]=(tlo+thi)/2
            outward=[b for b in boxes if b['lo'][axis]-1e-7<=p[axis]<=b['hi'][axis]+1e-7 and b['lo'][tangent]-1e-7<=p[tangent]<=b['hi'][tangent]+1e-7]
            zs=sorted({0,top}|{round(v,8) for b in outward for v in (b['lo'][2],b['hi'][2]) if 0<v<top})
            for za,zb in zip(zs,zs[1:]):
                p[2]=(za+zb)/2;solid=[b for b in outward if contains(b,p)]
                q=list(p);q[axis]=plane-sign*.001
                if not solid or any(contains(b,q) for b in boxes):continue
                faces.append(dict(axis=axis,normal_sign=-sign,plane=plane,tangent_bounds=[tlo,thi],z_bounds=[za,zb],source_solids=sorted(b['key'] for b in solid),floor_source=cell['source'],cell=[ix,iy]))
    groups=defaultdict(list)
    for f in faces:groups[(f['axis'],f['normal_sign'],f['plane'],*f['z_bounds'])].append(f)
    merged=[]
    for key,group in groups.items():
        for f in sorted(group,key=lambda f:f['tangent_bounds'][0]):
            if merged and all(merged[-1][k]==f[k] for k in ('axis','normal_sign','plane','z_bounds')) and abs(merged[-1]['tangent_bounds'][1]-f['tangent_bounds'][0])<1e-6:
                merged[-1]['tangent_bounds'][1]=f['tangent_bounds'][1];merged[-1]['source_solids']=sorted(set(merged[-1]['source_solids']+f['source_solids']));merged[-1]['floor_sources']=sorted(set(merged[-1]['floor_sources']+[f['floor_source']]))
            else:merged.append({k:v for k,v in f.items() if k not in ('cell','floor_source')}|dict(floor_sources=[f['floor_source']]))
    # Suppress only original surface rows intersecting the admitted physical
    # cells/owned facade support. Preserve corridors and unrelated tile rows.
    superseded=[];partial_context=[]
    assets=json.loads((ROOT/'Tools/ChainCrossingKit/Output/asset_manifest.json').read_text())
    slab=next(a for a in assets['assets'] if a['id']=='CCS13')
    slabsize=[(b-a)/100 for a,b in zip(slab['bounds_min_cm'],slab['bounds_max_cm'])]
    for i,row in enumerate(data['fit']['placements']):
        if row['tile']!='Catacomb':continue
        if row['role'] in ('source floor veneer','source floor seam backing','source ceiling underside','source ceiling seam backing'):
            x,y,z=row['at']
            w,h=(row['scale'][0],row['scale'][1]) if row['id'].startswith('BACKING') else (row['scale'][0]*slabsize[0],row['scale'][1]*slabsize[1])
            footprint=[x-w/2,y-h/2,x+w/2,y+h/2]
            intersections=[clip(rectpoly(v['rect']),rectpoly(footprint)) for v in cells.values()]
            covered=sum(area(p) for p in intersections);total=w*h
            if covered>1e-8 and (abs(z)<.02 or abs(z-3.5)<.02):
                if abs(covered-total)<1e-6:superseded.append(i)
                else:partial_context.append(dict(source_key=i,footprint=footprint,admitted_area=covered,total_area=total,policy='Original remains exact; new admitted stone surface sits above it, outside footprint remains source context.'))
        elif row['role'] in ('source exposed wall veneer','source wall seam backing'):
            # Measured face-pair lists determine the old finite facings;
            # never suppress a whole CCS15 actor or all Catacomb tile rows.
            pass
    oldsel=json.loads((ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-slate-painterly-r05-current-source/dark_slate_wall_coverage_r04.json').read_text())
    diag=json.loads((ROOT/'Saved/WarrensCGameplay-20261024/slate_raster_face_diagnosis_r01.json').read_text())
    wallkeys=sorted(k for p in oldsel['pairs']+diag['proposal'] if p.get('room')=='catacomb' for k in p['source_keys'])
    superseded+=wallkeys
    out.mkdir(parents=True)
    result=dict(status='DERIVED_SOURCE_SUPPORTED_ROOM_GEOMETRY_CANDIDATE',grid_metres=GRID,room=room,owned_niches=niches,
        inputs={p.relative_to(ROOT).as_posix():sha(p) for p in paths.values()},source_boxes=boxes,
        admitted_floor_cells=list(cells.values()),excluded_transition_cells=excluded,connector_regions=cons,
        wall_faces=merged,ceiling_faces=ceilings,superseded_fit_keys=sorted(set(superseded)),partial_original_context=partial_context,old_wall_keys=wallkeys,
        native_main_pose_count=len(old),native_main_pose_max_error=0,
        policy='Full physical cell footprints; at least half of authored room+three named Catacomb POI niches, zero other-room/niche/connector overlap outside owned union. Exact half cells retained after confirmed wall91 trace. Source solid-union boundary faces only. Ceiling clipped to admitted physical cells. All geometry remains visual NoCollision.',
        source_context='Original source solids retained at exact native poses for enclosure; no closure plane or route change.')
    path=out/'room_geometry.json';path.write_text(json.dumps(result,indent=2)+'\n')
    print('ROOM_GEOMETRY',len(cells),'floor cells',len(merged),'continuous source faces',len(ceilings),'clipped ceiling cells',len(superseded),'old surfaces',len(excluded),'transition cells excluded',sha(path))

if __name__=='__main__':main()
