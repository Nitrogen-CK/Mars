"""Source-box fitting only; produces NoCollision artwork, never edits a level.

Coordinates are plan metres. UE FRotator uses positive pitch toward +Z,
positive yaw toward +Y, and positive roll takes local +Y toward -Z.
"""
import json
import math
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PIVOTS = {'WaterworksW': (4, 14, -2.5), 'Hub': (4, 36, 0)}
HUB_RECT = (4, 36, 29, 45)
EPS = .008


def default_specs():
    return {
        'WaterworksW': {'baseline_path': ROOT/'Tools/ChainCrossingKit/Output/Reports/level_baseline.json',
                       'pivot': PIVOTS['WaterworksW']},
        'Hub': {'baseline_path': HERE/'Output/Reports/level_baseline.json', 'pivot': PIVOTS['Hub'],
                'rect': HUB_RECT, 'max_floor_z': -1.4}}


def asset_bounds():
    manifest = json.loads((ROOT/'Tools/ChainCrossingKit/Output/asset_manifest.json').read_text())
    bounds = {a['id']: ([v/100 for v in a['bounds_min_cm']], [v/100 for v in a['bounds_max_cm']])
              for a in manifest['assets'] if a['id'] in ('CCS13','CCS15','CCS18')}
    bounds['BACKING'] = ([-.5]*3, [.5]*3)
    return bounds


def rotate(v, rotation):
    p, y, r = map(math.radians, rotation)
    cp, sp, cy, sy, cr, sr = math.cos(p), math.sin(p), math.cos(y), math.sin(y), math.cos(r), math.sin(r)
    axes = ((cp*cy, cp*sy, sp), (sr*sp*cy-cr*sy, sr*sp*sy+cr*cy, -sr*cp),
            (-cr*sp*cy-sr*sy, sr*cy-cr*sp*sy, cr*cp))
    return [sum(v[j]*axes[j][k] for j in range(3)) for k in range(3)]


def intersect(a, b):
    c = max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3])
    return c if c[2]-c[0] > 1e-6 and c[3]-c[1] > 1e-6 else None


def subtract(rect, other):
    cut = intersect(rect, other)
    if not cut:
        return [rect]
    x0, y0, x1, y1 = rect
    a, b, c, d = cut
    return [q for q in ((x0,y0,a,y1), (c,y0,x1,y1), (a,y0,c,b), (a,d,c,y1))
            if q[2]-q[0] > 1e-6 and q[3]-q[1] > 1e-6]


def chunks(a, b, step=2):
    n = max(1, math.ceil((b-a)/step))
    return [(a+(b-a)*i/n, a+(b-a)*(i+1)/n) for i in range(n)]


def contains(box, x, y, z=None):
    return (box['lo'][0]-1e-6 <= x <= box['hi'][0]+1e-6 and
            box['lo'][1]-1e-6 <= y <= box['hi'][1]+1e-6 and
            (z is None or box['lo'][2]+1e-5 < z < box['hi'][2]-1e-5))


def load_boxes(tile_specs=None):
    tile_specs = default_specs() if tile_specs is None else tile_specs
    result = {}
    for tile, spec in tile_specs.items():
        data = json.loads(Path(spec['baseline_path']).read_text())[tile]
        boxes = []
        for actor in data['actors']:
            for comp in actor['components']:
                for n, inst in enumerate(comp.get('instances', [])):
                    at = [inst['at'][k]/100+spec['pivot'][k] for k in range(3)]
                    size = inst['scale']
                    boxes.append(dict(key=f"{actor['label']}:{n}", label=actor['label'], at=at,
                                      size=size, rotation=inst['rotation'],
                                      lo=[at[k]-size[k]/2 for k in range(3)],
                                      hi=[at[k]+size[k]/2 for k in range(3)]))
        result[tile] = boxes
    return result


def build(tile_specs=None):
    tile_specs = default_specs() if tile_specs is None else tile_specs
    all_boxes = load_boxes(tile_specs)
    bounds = asset_bounds()
    dims = {key: [hi[k]-lo[k] for k in range(3)] for key,(lo,hi) in bounds.items()}
    rows, coverage = [], {'tiles': {}, 'untouched_semantic_areas': [
        'All surfaces outside each tile specification rectangle or floor-height range',
        'Original source actors, collision, galleries, props, water and gameplay mechanisms'],
        'evidence_scope': 'Pure Python source-surface geometry; requires Unreal and PIE visual acceptance'}
    def add(tile, ident, at, scale, role, yaw=0, rotation=None, material=None):
        row = dict(tile=tile, id=ident, at=at, scale=scale, yaw=yaw, role=role, collision='NoCollision')
        if rotation is not None:
            row['rotation'] = rotation
        if material:
            row['material'] = material
        rows.append(row)

    for tile, boxes in all_boxes.items():
        spec = tile_specs[tile]
        scope_rect = spec.get('rect')
        min_floor_z, max_floor_z = spec.get('min_floor_z', -math.inf), spec.get('max_floor_z', math.inf)
        floor_boxes = [b for b in boxes if b['label'] == 'Warrens_Greybox_floor']
        # Raster floors can be tall structural voxels: e.g. Hub floor27 spans
        # Z=-2.9..0 beside the lower Cistern. Its top belongs to Arrival Hub,
        # but its exposed sides belong to this room. Include every floor in
        # solid-union queries without selecting its walking top for dressing.
        walls = [b for b in boxes if b['label'] in ('Warrens_Greybox_wall', 'Warrens_Greybox_roof', 'Warrens_Greybox_floor')]
        floors, floor_rects, ceiling_rects = [], [], []
        skipped = Counter()
        source_samples = missing_samples = hidden_samples = 0
        for b in floor_boxes:
            rect = (*b['lo'][:2], *b['hi'][:2])
            if b['hi'][2] > max_floor_z:
                skipped['upper_floor'] += 1
                continue
            if b['hi'][2] < min_floor_z:
                skipped['lower_floor'] += 1
                continue
            if scope_rect is not None:
                rect = intersect(rect, scope_rect)
                if rect is None:
                    skipped['outside_rect_floor'] += 1
                    continue
            floors.append(dict(box=b, rect=rect, top=b['hi'][2]))
            # Split at overlapping wall bounds: wholly buried floor samples are not exposed surfaces.
            xs, ys = {rect[0], rect[2]}, {rect[1], rect[3]}
            for wall in walls:
                if not wall['lo'][2] < b['hi'][2]+.02 < wall['hi'][2]:
                    continue
                hit = intersect(rect, (*wall['lo'][:2], *wall['hi'][:2]))
                if hit:
                    xs.update((hit[0],hit[2])); ys.update((hit[1],hit[3]))
            for xa, xb in zip(sorted(xs), sorted(xs)[1:]):
                for ya, yb in zip(sorted(ys), sorted(ys)[1:]):
                    x, y = (xa+xb)/2, (ya+yb)/2
                    if any(contains(w,x,y,b['hi'][2]+.02) for w in walls):
                        hidden_samples += 1
                        continue
                    remaining = [(xa,ya,xb,yb)]
                    for old, z in floor_rects:
                        if abs(z-b['hi'][2]) < .001:
                            remaining = [q for p in remaining for q in subtract(p,old)]
                    for rect_piece in remaining:
                        floor_rects.append((rect_piece,b['hi'][2]))
                        for a,c in chunks(rect_piece[0],rect_piece[2]):
                            for d,e in chunks(rect_piece[1],rect_piece[3]):
                                add(tile,'CCS13',[(a+c)/2,(d+e)/2,b['hi'][2]+EPS],[(c-a)/dims['CCS13'][0],(e-d)/dims['CCS13'][1],1], 'source floor veneer')
                                add(tile,'BACKING',[(a+c)/2,(d+e)/2,b['hi'][2]], [c-a,e-d,.006], 'source floor seam backing',material='TX02')
                    # Independent sample membership against emitted footprint registry.
                    for tx,ty in ((x,y),(xa+.001,ya+.001),(xb-.001,yb-.001)):
                        source_samples += 1
                        missing_samples += not any(abs(z-b['hi'][2])<.001 and p[0]-1e-6<=tx<=p[2]+1e-6 and p[1]-1e-6<=ty<=p[3]+1e-6 for p,z in floor_rects)

        # Undersides are intersections of source solids with actual floor footprints.
        # Subtract already-covered areas and reject surfaces buried in another solid.
        for floor in floors:
            candidates = sorted((w for w in walls if 2.2 <= w['lo'][2]-floor['top'] <= 10), key=lambda w:w['lo'][2])
            covered = []
            for w in candidates:
                hit = intersect(floor['rect'], (*w['lo'][:2], *w['hi'][:2]))
                if hit is None:
                    continue
                pieces = [hit]
                for old in covered:
                    pieces = [q for p in pieces for q in subtract(p,old)]
                for old,z in ceiling_rects:
                    if abs(z-w['lo'][2])<.001:
                        pieces = [q for p in pieces for q in subtract(p,old)]
                for piece in pieces:
                    for a,c in chunks(piece[0],piece[2]):
                        for d,e in chunks(piece[1],piece[3]):
                            x,y=(a+c)/2,(d+e)/2
                            if any(contains(other,x,y,w['lo'][2]-.01) for other in walls):
                                continue
                            # The whole vault shell must sit below the retained opaque solid;
                            # burying its crown makes it render as the old flat underside.
                            # 2.2m minimum source clearance leaves >=2.042m below its low edge.
                            add(tile,'CCS18',[x,y,w['lo'][2]-.158],[(c-a)/dims['CCS18'][0],(e-d)/dims['CCS18'][1],.15/dims['CCS18'][2]], 'source ceiling underside')
                            add(tile,'BACKING',[x,y,w['lo'][2]], [c-a,e-d,.008], 'source ceiling seam backing',material='TX01')
                            ceiling_rects.append(((a,d,c,e),w['lo'][2]))
                    covered.append(piece)

        seen_faces = {}
        wall_without_ceiling = 0
        for b in walls:
            for axis, sign, yaw in ((1,-1,0),(1,1,180),(0,-1,-90),(0,1,90)):
                tangent=1-axis
                fixed=b['lo'][axis] if sign<0 else b['hi'][axis]
                low,high=b['lo'][tangent],b['hi'][tangent]
                if scope_rect is not None:
                    if not scope_rect[axis]-1e-6<=fixed<=scope_rect[axis+2]+1e-6:
                        continue
                    low=max(low,scope_rect[tangent]); high=min(high,scope_rect[tangent+2])
                if high-low<1e-6:
                    continue
                # Split union face at adjacent floor and wall boundaries before testing exposure.
                cuts={low,high}
                near=[]
                for f in floors:
                    rect=f['rect']
                    if rect[axis]-.12<=fixed+sign*.06<=rect[axis+2]+.12 and rect[tangent]<high and rect[tangent+2]>low:
                        near.append(f);cuts.update((max(low,rect[tangent]),min(high,rect[tangent+2])))
                for other in walls:
                    if other['lo'][axis]-.02<=fixed+sign*.02<=other['hi'][axis]+.02:
                        for v in (other['lo'][tangent],other['hi'][tangent]):
                            if low<v<high: cuts.add(v)
                for la,lb in zip(sorted(cuts),sorted(cuts)[1:]):
                    for a,c in chunks(la,lb):
                        mid=(a+c)/2
                        xy=[0.,0.];xy[axis]=fixed+sign*.06;xy[tangent]=mid
                        adjacent=[f for f in near if f['rect'][tangent]-1e-6<=mid<=f['rect'][tangent+2]+1e-6]
                        for f in adjacent:
                            bottom=max(b['lo'][2],f['top'])
                            # At boundary voxels the outward probe can be just outside the roof footprint.
                            # Query above the adjacent retained floor, never extrapolate a room centre.
                            floor_probe=[max(f['rect'][k]+.001,min(xy[k],f['rect'][k+2]-.001)) for k in range(2)]
                            caps=[w['lo'][2] for w in walls if contains(w,*floor_probe) and .05<=w['lo'][2]-f['top']<=10]
                            top=min(b['hi'][2],min(caps) if caps else b['hi'][2])
                            if not caps:
                                wall_without_ceiling += 1
                                if top-f['top']>10:
                                    skipped['wall_face_no_overhead_ceiling_above_10m']+=1
                                    continue
                            if top<=bottom:
                                continue
                            zs={bottom,top}
                            for other in walls:
                                if contains(other,*xy):
                                    zs.update(v for v in (other['lo'][2],other['hi'][2]) if bottom<v<top)
                            for z0,z1 in zip(sorted(zs),sorted(zs)[1:]):
                                if any(contains(other,*xy,(z0+z1)/2) for other in walls):
                                    continue
                                key=(axis,sign,round(fixed,5))
                                occupied=seen_faces.setdefault(key,[])
                                pieces=[(a,z0,c,z1)]
                                for old in occupied:
                                    pieces=[q for p in pieces for q in subtract(p,old)]
                                for aa,za,cc,zc in pieces:
                                    occupied.append((aa,za,cc,zc))
                                    at=[0.,0.,za];at[tangent]=(aa+cc)/2
                                    # Bury most thickness; visible face projects only 12mm from the retained wall.
                                    at[axis]=fixed-sign*(dims['CCS15'][1]/2-.012)
                                    depth=dims['CCS15'][1]
                                    if scope_rect is not None:
                                        lo=max(at[axis]-depth/2,scope_rect[axis])
                                        hi=min(at[axis]+depth/2,scope_rect[axis+2])
                                        if hi-lo<=1e-6: continue
                                        at[axis]=(lo+hi)/2;depth=hi-lo
                                    add(tile,'CCS15',at,[(cc-aa)/dims['CCS15'][0],depth/dims['CCS15'][1],(zc-za)/dims['CCS15'][2]], 'source exposed wall veneer',yaw)
                                    back=list(at);back[2]=(za+zc)/2
                                    back[axis]=fixed
                                    lo,hi=fixed-.004,fixed+.004
                                    if scope_rect is not None:
                                        lo=max(lo,scope_rect[axis]);hi=min(hi,scope_rect[axis+2])
                                    if hi>lo:
                                        back[axis]=(lo+hi)/2
                                        size=[0.,0.,zc-za];size[axis]=hi-lo;size[tangent]=cc-aa
                                        add(tile,'BACKING',back,size,'source wall seam backing',material='TX01')

        ramp_count=0
        ramp_source_area=ramp_emitted_area=ramp_max_error=0.
        for b in boxes:
            if b['label']!='Warrens_Greybox_ramp': continue
            corners=[]
            for x in (-b['size'][0]/2,b['size'][0]/2):
                for y in (-b['size'][1]/2,b['size'][1]/2):
                    off=rotate((x,y,b['size'][2]/2),b['rotation'])
                    corners.append([b['at'][k]+off[k] for k in range(3)])
            if not all(min_floor_z<=p[2]<=max_floor_z and
                       (scope_rect is None or scope_rect[0]<=p[0]<=scope_rect[2] and scope_rect[1]<=p[1]<=scope_rect[3]) for p in corners):
                skipped['ramp_outside_scope']+=1
                continue
            ramp_source_area+=b['size'][0]*b['size'][1]
            normal=rotate((0,0,1),b['rotation'])
            source_top_offset=rotate((0,0,b['size'][2]/2),b['rotation'])
            plane=[b['at'][k]+source_top_offset[k] for k in range(3)]
            for xa,xb in chunks(-b['size'][0]/2,b['size'][0]/2):
                for ya,yb in chunks(-b['size'][1]/2,b['size'][1]/2):
                    off=rotate(((xa+xb)/2,(ya+yb)/2,b['size'][2]/2+EPS),b['rotation'])
                    at=[b['at'][k]+off[k] for k in range(3)]
                    ramp_emitted_area+=(xb-xa)*(yb-ya)
                    ramp_max_error=max(ramp_max_error,abs(sum((at[k]-plane[k])*normal[k] for k in range(3))-EPS))
                    add(tile,'CCS13',at,[(xb-xa)/dims['CCS13'][0],(yb-ya)/dims['CCS13'][1],.03/dims['CCS13'][2]], 'source ramp top veneer',b['rotation'][1],list(b['rotation']))
                    off=rotate(((xa+xb)/2,(ya+yb)/2,b['size'][2]/2),b['rotation'])
                    back=[b['at'][k]+off[k] for k in range(3)]
                    add(tile,'BACKING',back,[xb-xa,yb-ya,.006], 'source ramp seam backing',b['rotation'][1],list(b['rotation']),material='TX02')
            ramp_count+=1
        tile_rows=[r for r in rows if r['tile']==tile]
        low_overhead = 0
        for f in floors:
            x=(f['rect'][0]+f['rect'][2])/2; y=(f['rect'][1]+f['rect'][3])/2
            overhead=[w['lo'][2]-f['top'] for w in walls if contains(w,x,y) and w['lo'][2]>f['top']+.05]
            low_overhead += bool(overhead and min(overhead)<2.2)
        coverage['tiles'][tile]=dict(source_floor_boxes=len(floor_boxes),selected_floor_boxes=len(floors),
            exposed_floor_samples=source_samples,missing_floor_samples=missing_samples,buried_floor_cells_excluded=hidden_samples,
            floor_boxes_with_center_overhead_below_2_2m=low_overhead,
            ceiling_policy='Only source undersides with 2.2..10m existing clearance; low tunnels retained without vault veneer',
            emitted_floor_union_area_m2=sum((p[2]-p[0])*(p[3]-p[1]) for p,z in floor_rects),
            ramp_instances_covered=ramp_count,roles=dict(Counter(r['role'] for r in tile_rows)),excluded=dict(skipped),
            ramp_source_area_m2=ramp_source_area,ramp_emitted_area_m2=ramp_emitted_area,
            ramp_normal_offset_max_error_m=ramp_max_error,
            wall_segments_without_overhead_source_box=wall_without_ceiling,
            selected_floor_bounds=([min(f['rect'][0] for f in floors),min(f['rect'][1] for f in floors),
                                   max(f['rect'][2] for f in floors),max(f['rect'][3] for f in floors)] if floors else None))
    coverage['rotation_checks']={'positive_pitch_x':rotate((1,0,0),(90,0,0)),
        'positive_yaw_x':rotate((1,0,0),(0,90,0)),'positive_roll_y':rotate((0,1,0),(0,0,90))}
    invalid_dimensions=scoped_outside=hub_outside=0
    for row in rows:
        invalid_dimensions += any(not math.isfinite(v) or v<=0 for v in row['scale'])
        rect=tile_specs[row['tile']].get('rect')
        if rect is None: continue
        lo,hi=bounds[row['id']]
        for x in (lo[0],hi[0]):
            for y in (lo[1],hi[1]):
                for z in (lo[2],hi[2]):
                    off=rotate((x*row['scale'][0],y*row['scale'][1],z*row['scale'][2]),row.get('rotation',(0,row['yaw'],0)))
                    outside=not all(rect[k]-1e-6<=row['at'][k]+off[k]<=rect[k+2]+1e-6 for k in range(2))
                    scoped_outside+=outside
                    hub_outside+=outside and row['tile']=='Hub'
    coverage['generated_geometry_checks']={'placements':len(rows),'invalid_dimensions':invalid_dimensions,
        'scoped_xy_corner_violations':scoped_outside,'hub_xy_corner_violations':hub_outside,
        'asset_dimensions_metres':dims,'all_rows_no_collision':all(r['collision']=='NoCollision' for r in rows)}
    assert invalid_dimensions==scoped_outside==0
    return {'placements':rows,'coverage':coverage}


if __name__=='__main__':
    result=build()
    report=HERE/'Output/Reports/surface_fitting_checks.json'
    report.parent.mkdir(parents=True,exist_ok=True)
    report.write_text(json.dumps(result['coverage'],indent=2)+'\n')
    print(json.dumps(result['coverage'],indent=2))
