"""Multi-elevation room veneers from a read-only current-native solid snapshot.

Produces review data only. Physical support, competing rooms, connector mouths,
water-bed elevations and source-fitted local roofs constrain every proposal.
"""
import argparse
import collections
import hashlib
import importlib.util
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'
GRID = .5
EPS = 1e-7


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def intersection(a, b):
    r = [max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3])]
    return r if r[2]-r[0] > EPS and r[3]-r[1] > EPS else None


def subtract(rect, cutter):
    """Disjoint exact rectangles of rect minus cutter, including narrow strips."""
    q = intersection(rect, cutter)
    if q is None:
        return [rect]
    pieces = [[rect[0], rect[1], q[0], rect[3]], [q[2], rect[1], rect[2], rect[3]],
              [q[0], rect[1], q[2], q[1]], [q[0], q[3], q[2], rect[3]]]
    return [r for r in pieces if r[2]-r[0] > EPS and r[3]-r[1] > EPS]


def helpers():
    spec = importlib.util.spec_from_file_location('_regions_geometry', Path(__file__).with_name('catacomb_pilot_manifest.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def connector_regions(plan, bounds):
    """Full declared widths; no Catacomb-specific height or coordinate filters."""
    paths = []
    for i, row in enumerate(plan['links']):
        a, b = plan['nodes'][row['a']], plan['nodes'][row['b']]
        via = row.get('via', [])
        points = [a] + [[v[0], v[1], a[2] + (b[2]-a[2])*(j+1)/(len(via)+1)] for j, v in enumerate(via)] + [b]
        paths.append((f'link:{i}', points, row['width']))
    for kind in ('extraRamps', 'crawls'):
        for i, row in enumerate(plan[kind]):
            z = row.get('z', row['a'][2] if len(row['a']) > 2 else 0)
            a, b = [list(v[:2]) + [v[2] if len(v) > 2 else z] for v in (row['a'], row['b'])]
            paths.append((f'{kind}:{row.get("id", i)}', [a]+[[v[0], v[1], z] for v in row.get('via', [])]+[b], row.get('width', .8)))
    result = []
    for key, points, width in paths:
        for i, (a, b) in enumerate(zip(points, points[1:])):
            length = math.hypot(b[0]-a[0], b[1]-a[1])
            if length < EPS:
                continue
            nx, ny = -(b[1]-a[1])/length*width/2, (b[0]-a[0])/length*width/2
            poly = [[a[0]+nx, a[1]+ny], [a[0]-nx, a[1]-ny], [b[0]-nx, b[1]-ny], [b[0]+nx, b[1]+ny]]
            if any(max(v[k] for v in poly) < bounds[k] or min(v[k] for v in poly) > bounds[k+2] for k in (0, 1)):
                continue
            result.append(dict(key=f'{key}:{i}', poly=poly, z_range=sorted([a[2], b[2]])))
    return result


def build(room_id, native_path, max_clearance=8, facade_path=None):
    g = helpers()
    paths = [ROOT/'Tools/LevelDesign/anchor_plans/data/warrens_v8c.json', native_path, ROOT/'Tools/WarrensVariantCKit/Output/fitted_instances.json']
    plan, native, fit = [json.loads(p.read_text(encoding='utf-8')) for p in paths]
    assert native['status'] == 'READ_ONLY_CURRENT_ASSEMBLED_NATIVE_SOLIDS' and native['dirty'] == dict(maps=[], content=[])
    room, = [v for v in plan['rooms'] if v['id'] == room_id]
    niches = [v for v in plan['niches'] if v['id'].startswith(room_id+'-')]
    water = [v for v in plan['water'] if v['id'].startswith(room_id+'-')]
    ownership = [dict(id=room_id, poly=g.roompoly(room), z=room['z'])] + [dict(id=v['id'], poly=g.rectpoly(v['rect']), z=v['z']) for v in niches]
    # The authored bed is a separate physical surface; the water sheet is never
    # accepted as support. Native raster edge half-cells follow the pilot rule.
    ownership += [dict(id=v['id']+'-bed', poly=v.get('poly') or g.rectpoly(v['rect']), z=v['z']-v['depth']) for v in water]
    all_owned = [v['poly'] for v in ownership]
    bounds = [min(p[i] for poly in all_owned for p in poly)-1 for i in (0, 1)] + [max(p[i] for poly in all_owned for p in poly)+1 for i in (0, 1)]
    low = min(v['z'] for v in ownership)
    top = room.get('top', room['z']+3.5)
    boxes = []
    for actor in native['actors']:
        match = re.search(r'/LI_Warrens_(\w+)_LevelInstance_', actor['level'])
        tile = match[1] if match else 'Main'
        for ci, component in enumerate(actor['components']):
            assert component['mesh'] == '/Engine/BasicShapes/Cube'
            for index, row in enumerate(component['instances']):
                assert max(abs(v) for v in row['q'][:3]) < 1e-8 and abs(row['q'][3]-1) < 1e-8
                at = [row['at'][0]/100+70, row['at'][1]/100+55, row['at'][2]/100]
                b = dict(key=f'{tile}:{actor["label"]}:{ci}:{index}', tile=tile, label=actor['label'], component=ci, index=index,
                         lo=[at[k]-row['scale'][k]/2 for k in range(3)], hi=[at[k]+row['scale'][k]/2 for k in range(3)])
                if all(b['lo'][i] < bounds[i+2] and b['hi'][i] > bounds[i] for i in (0, 1)) and b['lo'][2] < top+1 and b['hi'][2] > low-.6:
                    boxes.append(b)
    others = [dict(id=v['id'], poly=g.roompoly(v), z=v['z']) for v in plan['rooms'] if v['id'] != room_id]
    others += [dict(id=v['id'], poly=g.rectpoly(v['rect']), z=v['z']) for v in plan['niches'] if not v['id'].startswith(room_id+'-')]
    connectors = connector_regions(plan, bounds)
    ceiling_footprints = []
    for row in fit['placements']:
        if row['role'] != 'source ceiling seam backing' or not row['id'].startswith('BACKING'):
            continue
        x, y, z = row['at']; w, h = row['scale'][:2]
        ceiling_footprints.append(dict(rect=[x-w/2, y-h/2, x+w/2, y+h/2], z=z))
    cells = {}; excluded = []
    for b in boxes:
        if b['label'] != 'Warrens_Greybox_floor' and not b['label'].startswith('WVC_GP_P4_Collision_floor_'):
            continue
        z = b['hi'][2]
        owned = [v['poly'] for v in ownership if abs(v['z']-z) < 1e-5]
        if not owned:
            continue
        for ix in range(math.floor(max(b['lo'][0], bounds[0])/GRID), math.ceil(min(b['hi'][0], bounds[2])/GRID)):
            for iy in range(math.floor(max(b['lo'][1], bounds[1])/GRID), math.ceil(min(b['hi'][1], bounds[3])/GRID)):
                rect = [max(ix*GRID, b['lo'][0]), max(iy*GRID, b['lo'][1]), min((ix+1)*GRID, b['hi'][0]), min((iy+1)*GRID, b['hi'][1])]
                poly = g.rectpoly(rect); area = g.area(poly); overlap = g.union_overlap(poly, owned)
                if area < EPS or overlap < area*.5-EPS:
                    continue
                competing = [v['id'] for v in others if abs(v['z']-z) <= .401 and g.area(g.clip(v['poly'], poly)) > EPS]
                crossing = []
                for c in connectors:
                    if not c['z_range'][0]-.401 <= z <= c['z_range'][1]+.401:
                        continue
                    clip = g.clip(c['poly'], poly)
                    # A raster water-bed edge inside the same room is not an
                    # outside connector mouth. Membership stays same-Z above;
                    # only this geographic transition test uses all room zones.
                    if g.area(clip)-g.union_overlap(clip, all_owned) > EPS:
                        crossing.append(c['key'])
                if competing or crossing:
                    excluded.append(dict(cell=[ix, iy], z=z, rect=rect, competing=competing, outside_connectors=crossing))
                    continue
                centre = [(rect[0]+rect[2])/2, (rect[1]+rect[3])/2, z+.002]
                if any(g.contains(v, centre) for v in boxes):
                    continue
                key = (ix, iy)
                assert key not in cells, ('Overlapping physical ownership requires explicit review', key, z, cells.get(key))
                cells[key] = dict(cell=[ix, iy], rect=rect, z=z, source=b['key'], physical_area=area, nominal_overlap_area=overlap)
    assert cells
    ceilings = []; open_cells = []; faces = []
    for key, cell in cells.items():
        ix, iy = key; r = cell['rect']; z = cell['z']; centre = [(r[0]+r[2])/2, (r[1]+r[3])/2]
        # Require full support of the cell by a single current physical solid,
        # and full coverage by one matching fitted footprint. Overlap summation
        # cannot accidentally double-count duplicate backing rectangles.
        roofs = [b for b in boxes if z+.05 < b['lo'][2] <= z+max_clearance and
                 all(b['lo'][k]-EPS <= r[k] and b['hi'][k]+EPS >= r[k+2] for k in (0, 1)) and
                 any(abs(v['z']-b['lo'][2]) < .03 and all(v['rect'][k]-EPS <= r[k] and v['rect'][k+2]+EPS >= r[k+2] for k in (0, 1)) for v in ceiling_footprints)]
        if roofs:
            roof_z = min(b['lo'][2] for b in roofs)
            ceilings.append(dict(cell=cell['cell'], rect=r, z=roof_z, source_solids=sorted(b['key'] for b in roofs if abs(b['lo'][2]-roof_z) < 1e-5)))
        else:
            open_cells.append(cell['cell'])
        for axis, sign, neighbor in ((0, -1, (ix-1, iy)), (0, 1, (ix+1, iy)), (1, -1, (ix, iy-1)), (1, 1, (ix, iy+1))):
            # A neighboring floor cell does not imply open air above it.
            # Authored high returns/overhangs can begin above both floors;
            # inspect every column edge, then require exact physical faces.
            tangent = 1-axis; plane = r[axis] if sign < 0 else r[axis+2]; tlo, thi = r[tangent], r[tangent+2]
            p = [0, 0, 0]; p[axis] = plane+sign*.001; p[tangent] = (tlo+thi)/2
            outward = [b for b in boxes if abs((b['lo'][axis] if sign > 0 else b['hi'][axis])-plane) < EPS]
            inner_plane = plane-sign*.001
            inward = [b for b in boxes if b['lo'][axis]-EPS <= inner_plane <= b['hi'][axis]+EPS]
            for b in outward:
                rect = intersection([tlo, z, thi, top], [b['lo'][tangent], b['lo'][2], b['hi'][tangent], b['hi'][2]])
                if rect is None:
                    continue
                pieces = [rect]
                # Full rectangle subtraction prevents midpoint sampling from
                # extending a veneer through an upper opening or solid ledge.
                for v in inward:
                    cut = [v['lo'][tangent], v['lo'][2], v['hi'][tangent], v['hi'][2]]
                    pieces = [part for piece in pieces for part in subtract(piece, cut)]
                # Duplicate overlapping greybox solids must not create two
                # coplanar skins. Preserve first explicit physical witness.
                for old in faces:
                    if old['axis'] == axis and old['normal_sign'] == -sign and abs(old['plane']-plane) < EPS:
                        cut = [old['tangent_bounds'][0], old['z_bounds'][0], old['tangent_bounds'][1], old['z_bounds'][1]]
                        pieces = [part for piece in pieces for part in subtract(piece, cut)]
                faces += [dict(axis=axis, normal_sign=-sign, plane=plane, tangent_bounds=[r[0], r[2]], z_bounds=[r[1], r[3]], source_solids=[b['key']]) for r in pieces]
    groups = collections.defaultdict(list)
    for face in faces:
        groups[(face['axis'], face['normal_sign'], face['plane'], *face['z_bounds'])].append(face)
    merged = []
    for key, group in sorted(groups.items()):
        for f in sorted(group, key=lambda f: f['tangent_bounds'][0]):
            if merged and all(merged[-1][k] == f[k] for k in ('axis', 'normal_sign', 'plane', 'z_bounds')) and abs(merged[-1]['tangent_bounds'][1]-f['tangent_bounds'][0]) < 1e-6:
                merged[-1]['tangent_bounds'][1] = f['tangent_bounds'][1]
                merged[-1]['source_solids'] = sorted(set(merged[-1]['source_solids']+f['source_solids']))
            elif merged and merged[-1] == f:
                continue
            else:
                merged.append(f)
    # Later static Cube repairs can have faces inside a raster cell (e.g. a
    # five-centimetre gallery offset), not just on half-metre cell edges.
    # Admit only their exposed faces above an already-owned supported floor
    # column. Subtract the complete physical union and existing veneer union.
    repair_faces = []
    for b in boxes:
        if not b['label'].startswith('WVC_GP_P4_Collision_'):
            continue
        for axis in (0, 1):
            tangent = 1-axis
            for sign in (-1, 1):
                plane = b['lo'][axis] if sign < 0 else b['hi'][axis]
                air = plane+sign*.001
                for cell in cells.values():
                    r = cell['rect']
                    if not r[axis]-EPS <= air <= r[axis+2]+EPS:
                        continue
                    rect = intersection([r[tangent], cell['z'], r[tangent+2], top], [b['lo'][tangent], b['lo'][2], b['hi'][tangent], b['hi'][2]])
                    if rect is None:
                        continue
                    pieces = [rect]
                    for other in boxes:
                        if other['lo'][axis]+EPS < air < other['hi'][axis]-EPS:
                            cut = [other['lo'][tangent], other['lo'][2], other['hi'][tangent], other['hi'][2]]
                            pieces = [part for piece in pieces for part in subtract(piece, cut)]
                    for old in merged+repair_faces:
                        if old['axis'] == axis and old['normal_sign'] == sign and abs(old['plane']-plane) < EPS:
                            cut = [old['tangent_bounds'][0], old['z_bounds'][0], old['tangent_bounds'][1], old['z_bounds'][1]]
                            pieces = [part for piece in pieces for part in subtract(piece, cut)]
                    repair_faces += [dict(axis=axis, normal_sign=sign, plane=plane, tangent_bounds=[v[0], v[2]], z_bounds=[v[1], v[3]], source_solids=[b['key']]) for v in pieces]
    merged += repair_faces
    supplement = None
    if facade_path:
        supplement = json.loads(facade_path.read_text(encoding='utf-8'))
        assert supplement['room'] == room_id and sha(ROOT/supplement['review']) == supplement['review_sha256']
        lookup = {b['key']: b for b in boxes}
        for f in supplement['faces']:
            axis, sign, plane = f['axis'], f['normal_sign'], f['plane']; tangent = 1-axis
            rect = [f['tangent_bounds'][0], f['z_bounds'][0], f['tangent_bounds'][1], f['z_bounds'][1]]
            assert len(f['source_solids']) == 1
            b = lookup[f['source_solids'][0]]
            assert abs((b['hi'][axis] if sign > 0 else b['lo'][axis])-plane) < EPS
            assert all(b['lo'][k]-EPS <= rect[i] <= rect[i+2] <= b['hi'][k]+EPS for i, k in ((0, tangent), (1, 2)))
            air_plane = plane+sign*.001
            for other in boxes:
                if other['lo'][axis]+EPS < air_plane < other['hi'][axis]-EPS:
                    assert intersection(rect, [other['lo'][tangent], other['lo'][2], other['hi'][tangent], other['hi'][2]]) is None, ('Supplement inside solid', f, other['key'])
            for old in merged:
                if old['axis'] == axis and old['normal_sign'] == sign and abs(old['plane']-plane) < EPS:
                    assert intersection(rect, [old['tangent_bounds'][0], old['z_bounds'][0], old['tangent_bounds'][1], old['z_bounds'][1]]) is None, ('Supplement overlaps existing', f)
            merged.append(f)
        paths += [facade_path, ROOT/supplement['review']]
    return dict(status='DERIVED_MULTI_ELEVATION_SOURCE_SUPPORTED_ROOM_REVIEW_REQUIRED', room=room, owned_niches=niches, water=water, ownership=ownership, grid_metres=GRID,
                source_boxes=boxes, admitted_floor_cells=list(cells.values()), excluded_transition_cells=excluded,
                wall_faces=merged, ceiling_faces=ceilings, source_open_overhead_cells=open_cells, connector_regions=connectors,
                floor_elevation_counts=dict(collections.Counter(str(v['z']) for v in cells.values())), wall_absolute_top=top,
                inputs={p.relative_to(ROOT).as_posix():sha(p) for p in paths}, tool_sha256=sha(__file__), polygon_helper_sha256=sha(g.__file__), finite_facade_supplement=supplement,
                boundary='Derived-only proposal. Current native solids, full-width connector exclusions, physically supported multi-height floors, exposed union wall/riser faces and conservative matching local ceilings. No source geometry, water, lighting, mesh, asset, map or library writes. Independent vertex/connector/window and visual review required before adoption.')


def main():
    p = argparse.ArgumentParser(); p.add_argument('--room', required=True); p.add_argument('--native-solids', required=True); p.add_argument('--output-name', required=True); p.add_argument('--facade-supplement')
    args = p.parse_args(); assert re.fullmatch('[a-z0-9-]+', args.output_name)
    native = (ROOT/args.native_solids).resolve(); assert native.is_relative_to(ROOT.resolve())
    facade = (ROOT/args.facade_supplement).resolve() if args.facade_supplement else None
    assert facade is None or facade.is_relative_to(ROOT.resolve())
    result = build(args.room, native, facade_path=facade); out = DOC/args.output_name; out.mkdir(exist_ok=False, parents=True)
    (out/'room_regions.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print('MULTI_ELEVATION_REGIONS', args.room, result['floor_elevation_counts'], len(result['wall_faces']), 'wall regions', len(result['ceiling_faces']), 'local ceiling cells', len(result['excluded_transition_cells']), 'transition exclusions')


if __name__ == '__main__':
    main()
