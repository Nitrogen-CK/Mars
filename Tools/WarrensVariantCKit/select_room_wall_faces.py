"""Read-only source wall coverage evaluator for Warrens authored rooms.

The only write is the explicitly requested new JSON file or directory. This
module never opens Blender/Unreal, imports a generator's main(), or edits source
plans, fit ledgers, assets, materials, or maps.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import importlib.util
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIT = ROOT / 'Tools/WarrensVariantCKit/Output/fitted_instances.json'
PLAN = ROOT / 'Tools/LevelDesign/anchor_plans/data/warrens_v8c.json'
ZONE = ROOT / 'Tools/WarrensVariantCKit/zone_plan.json'
BASELINE = ROOT / 'Tools/WarrensVariantCKit/Output/Reports/source_baseline.json'
SYNC = ROOT / 'Tools/WarrensVariantCKit/sync_art_libraries.py'
SYNC_SHA256 = '5de7683ebf5829952c0b31b39d3d28ff34b070019ab61fc2da01462ca3bbbad6'
MANIFEST = ROOT / 'Tools/ChainCrossingKit/Output/asset_manifest.json'
BRIEFS = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/room_briefs.json'
AXES = {0: (1, -1), 180: (1, 1), -90: (0, -1), 90: (0, 1)}
FLOOR_FRACTIONS = (.01, .25, .5, .75, .99)
FACE_SAMPLES = 21
OFFSETS = (.15, .30)

APPROVED_MEMBERSHIP = {
    'Ossuary': {
        'kind': 'saved source workflow bindings; placement_index values, not inferred from count',
        'path': 'Saved/WarrensCGameplay-20261024/OssuaryWallLibraryStage/KitLibrary/61dddb145f064c8bb39fc0cbbf506fc3/stage.json',
        'review': 'docs/art/warrens-c-gameplay-review-20261024/OSSUARY_WALL_PBR_RUNTIME_REVIEW.md',
    },
    'Hall': {'kind': 'approved finite selector membership', 'path': 'docs/art/warrens-c-gameplay-review-20261024/lookdev/hall-painterly-r01/wall_selection_r03.json', 'review': 'docs/art/warrens-c-gameplay-review-20261024/HALL_RETENTION_REVIEW.md'},
    'Cellar': {'kind': 'approved finite selector membership', 'path': 'docs/art/warrens-c-gameplay-review-20261024/lookdev/brineworks-painterly-r01/cellar_wall_selection_r01.json', 'review': 'docs/art/warrens-c-gameplay-review-20261024/CELLAR_RETENTION_REVIEW.md'},
    'Larder': {'kind': 'approved finite selector membership', 'path': 'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-painterly-r01/wall_selection_r01.json', 'review': 'docs/art/warrens-c-gameplay-review-20261024/LARDER_RETENTION_REVIEW.md'},
    'Sluice': {'kind': 'approved finite selector membership', 'path': 'docs/art/warrens-c-gameplay-review-20261024/lookdev/sluice-painterly-r01/sluice_wall_selection_r01.json', 'review': 'docs/art/warrens-c-gameplay-review-20261024/SLUICE_RETENTION_REVIEW.md'},
    'DarkSlate': {'kind': 'r04 source selection validation set, not an adoption approval', 'path': 'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-slate-painterly-r04/dark_slate_wall_coverage_r04.json', 'review': None},
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path: Path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def inside(point, poly):
    x, y = point
    result = False
    for a, b in zip(poly, poly[1:] + poly[:1]):
        if (a[1] > y) != (b[1] > y) and x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]:
            result = not result
    return result


def room_poly(room):
    if 'poly' in room:
        return room['poly']
    if 'rect' in room:
        x0, y0, x1, y1 = room['rect']
        return [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]
    return None


def source_bounds(row, pivot):
    center = [row['at'][i] / 100 + pivot[i] for i in range(3)]
    return ([center[i] - row['scale'][i] / 2 for i in range(3)],
            [center[i] + row['scale'][i] / 2 for i in range(3)])


def floor_witnesses(instances, pivot, point, z):
    found = []
    for idx, row in enumerate(instances):
        lo, hi = source_bounds(row, pivot)
        if (lo[0] + 1e-6 < point[0] < hi[0] - 1e-6
                and lo[1] + 1e-6 < point[1] < hi[1] - 1e-6
                and lo[2] <= z + 1e-5 and abs(hi[2] - z) < 1e-4):
            found.append(idx)
    return found


def wall_witnesses(instances, pivot, axis, sign, plane, tangent, tlo, thi, zlo, zhi):
    found = []
    for idx, row in enumerate(instances):
        lo, hi = source_bounds(row, pivot)
        face = hi[axis] if sign > 0 else lo[axis]
        if (abs(face - plane) < 1e-5 and lo[tangent] <= tlo + 1e-5
                and hi[tangent] >= thi - 1e-5 and lo[2] <= zlo + 1e-5
                and hi[2] >= zhi - 1e-5):
            found.append(idx)
    return found


def transformed_corners(asset, row):
    lo, hi = asset['bounds_min_cm'], asset['bounds_max_cm']
    a = math.radians(row.get('yaw', row.get('rotation', [0, 0, 0])[1]))
    c, s = math.cos(a), math.sin(a)
    return [[row['at'][0] + c * x - s * y,
             row['at'][1] + s * x + c * y,
             row['at'][2] + z]
            for x0 in (lo[0], hi[0]) for y0 in (lo[1], hi[1]) for z0 in (lo[2], hi[2])
            for x, y, z in [(x0 * row['scale'][0] / 100,
                             y0 * row['scale'][1] / 100,
                             z0 * row['scale'][2] / 100)]]


def projected_bounds(points):
    return [[min(p[i] for p in points), max(p[i] for p in points)] for i in range(3)]


def pair_geometry(index, rows, target, all_rooms, effective, removed, asset,
                  walls, floors, pivot, tile):
    veneer, backing = rows[index:index + 2]
    result = {'source_keys': [index, index + 1], 'room_id': target['id'], 'tile': tile, 'reasons': []}
    if index in removed or index + 1 in removed:
        result['reasons'].append('removed_by_current_effective_projection')
    if index not in effective or index + 1 not in effective:
        result['reasons'].append('absent_from_current_effective_projection')
    if veneer['yaw'] not in AXES:
        result['reasons'].append('noncardinal_wall_orientation')
        return result
    axis, sign = AXES[veneer['yaw']]
    tangent = 1 - axis
    plane = backing['at'][axis]
    tlo, thi = backing['at'][tangent] - backing['scale'][tangent] / 2, backing['at'][tangent] + backing['scale'][tangent] / 2
    zlo, zhi = backing['at'][2] - backing['scale'][2] / 2, backing['at'][2] + backing['scale'][2] / 2
    corners = transformed_corners(asset, veneer)
    mesh = projected_bounds(corners)
    # Corner order is x, then y, then z. Local -Y face: y index 0.
    face = projected_bounds([corners[i] for i in (0, 1, 4, 5)])
    exposed = corners[0][axis]
    width_error = max(abs(mesh[tangent][0] - tlo), abs(mesh[tangent][1] - thi))
    height_error = max(abs(mesh[2][0] - zlo), abs(mesh[2][1] - zhi))
    face_width_error = max(abs(face[tangent][0] - tlo), abs(face[tangent][1] - thi))
    face_height_error = max(abs(face[2][0] - zlo), abs(face[2][1] - zhi))
    delta = abs(exposed - plane)
    nlo, nhi = backing['at'][axis] - backing['scale'][axis] / 2, backing['at'][axis] + backing['scale'][axis] / 2
    backing_inside = nlo >= mesh[axis][0] - 1e-5 and nhi <= mesh[axis][1] + 1e-5
    if max(width_error, face_width_error) > 1e-4:
        result['reasons'].append('transformed_face_width_does_not_match_backing')
    if max(height_error, face_height_error) > 1e-4:
        result['reasons'].append('transformed_face_height_does_not_match_backing')
    if delta > .02:
        result['reasons'].append('exposed_face_not_within_20mm_of_backing_plane')
    if not backing_inside:
        result['reasons'].append('backing_outside_transformed_mesh_depth')
    if sign * (exposed - veneer['at'][axis]) <= 0:
        result['reasons'].append('face_not_on_authored_cardinal_side')
    if abs(veneer['at'][tangent] - backing['at'][tangent]) > 1e-5 or abs(veneer['at'][2] - zlo) > 1e-5:
        result['reasons'].append('veneer_backing_alignment_mismatch')
    if zlo < target['z'] - .03:
        result['reasons'].append('face_bottom_below_room_floor')
    top = target.get('top')
    if top is not None and zhi > top + .03:
        result['reasons'].append('face_top_above_authored_room_top')
    boxhits = wall_witnesses(walls, pivot, axis, sign, plane, tangent, tlo, thi, zlo, zhi)
    if len(boxhits) != 1:
        result['reasons'].append('source_wall_box_witness_missing_or_ambiguous')
    samples = {}
    for side in (-1, 1):
        for offset in OFFSETS:
            points = []
            for step in range(FACE_SAMPLES):
                frac = .001 + .998 * step / (FACE_SAMPLES - 1)
                point = [backing['at'][0], backing['at'][1]]
                point[tangent] = tlo + (thi - tlo) * frac
                point[axis] = exposed + side * offset
                owners = sorted(r['id'] for r in all_rooms
                                if abs(r.get('z', 1e9) - target['z']) < 1e-6
                                and room_poly(r) and inside(point, room_poly(r)))
                points.append({'fraction': frac, 'point': point, 'owners': owners})
            samples[f'{side:+d}_{offset:.2f}'] = points
    inward = samples[f'{sign:+d}_0.30']
    if any(p['owners'] != [target['id']] for p in inward):
        result['reasons'].append('normal_face_not_uniquely_owned_at_30cm')
    competing = sorted({o for ss in samples.values() for p in ss for o in p['owners'] if o != target['id']})
    if competing:
        result['reasons'].append('face_samples_enter_other_source_rooms')
    floorprobes = []
    for frac in FLOOR_FRACTIONS:
        point = [backing['at'][0], backing['at'][1]]
        point[tangent] = tlo + (thi - tlo) * frac
        point[axis] = exposed + sign * .30
        floorprobes.append({'fraction': frac, 'point': point, 'source_floor_boxes': floor_witnesses(floors, pivot, point, target['z'])})
    if any(len(p['source_floor_boxes']) != 1 for p in floorprobes):
        result['reasons'].append('floor_witness_missing_or_ambiguous')
    if index in effective and index + 1 in effective and (effective[index]['id'] != 'CCS15' or effective[index + 1]['id'] != 'BACKING_TX01'):
        result['reasons'].append('effective_projection_identity_mismatch')
    result.update(axis=axis, normal_sign=sign, tangent_axis=tangent, yaw=veneer['yaw'],
                  bounds_m={'tangent': [tlo, thi], 'vertical': [zlo, zhi], 'mesh': mesh, 'face': face},
                  source_wall_box_indices=boxhits, ownership_samples=samples,
                  floor_probes=floorprobes, competing_room_ids=competing,
                  transformed_width_error_m=width_error, transformed_face_width_error_m=face_width_error,
                  transformed_height_error_m=height_error, transformed_face_height_error_m=face_height_error,
                  face_backing_delta_m=delta, backing_within_mesh_depth=backing_inside,
                  local_ccs15_contract_m={'width': 2.0, 'thickness': .35, 'height': 3.0})
    result['reasons'] = sorted(set(result['reasons']))
    return result


def approved_sets():
    out = {}
    for label, spec in APPROVED_MEMBERSHIP.items():
        path = ROOT / spec['path']
        raw = read(path)
        if label == 'Ossuary':
            # Use actual saved library binding membership, one veneer per pair.
            veneer_keys = sorted({b['placement_index'] for b in raw['bindings']
                                  if b.get('placement_id') == 'CCS15'
                                  and b.get('role') == 'source exposed wall veneer'
                                  and b.get('scene') == 'Zone_Ossuary'})
            backing_keys = sorted({b['placement_index'] for b in raw['bindings']
                                   if b.get('placement_id') == 'BACKING_TX01'
                                   and b.get('role') == 'source wall seam backing'
                                   and b.get('scene') == 'Zone_Ossuary'})
            keys = sorted(set(veneer_keys + backing_keys))
            # The saved source workflow owns 597 veneers + 597 adjacent backings
            # in Zone_Ossuary: 1194 exact source keys (597 complete pairs).
            assert len(veneer_keys) == len(backing_keys) == 597, (len(veneer_keys), len(backing_keys))
            assert all(b == a + 1 for a, b in zip(veneer_keys, backing_keys)), 'Ossuary stored keys are not exact adjacent source pairs'
        else:
            keys = sorted(set(int(k) for k in raw.get('selected_source_keys', [])))
        review_path = ROOT / spec['review'] if spec['review'] else None
        assert review_path is None or review_path.is_file(), ('Missing membership retention review', label)
        out[label] = {'source_keys': keys, 'pairs': len(keys) // 2,
                      'membership_source': spec['path'], 'membership_sha256': sha(path),
                      'membership_method': spec['kind'],
                      'review': spec['review'], 'review_sha256': sha(review_path) if review_path and review_path.is_file() else None}
    expected = {'Ossuary': 1194, 'Hall': 144, 'Cellar': 88, 'Larder': 62, 'Sluice': 58, 'DarkSlate': 484}
    for name, count in expected.items():
        assert len(out[name]['source_keys']) == count, (name, len(out[name]['source_keys']), count)
    return out


def run(room_ids, output_path):
    dest = Path(output_path).resolve()
    if not dest.is_relative_to(ROOT.resolve()):
        raise ValueError('Review output must stay inside the project workspace.')
    if dest.exists():
        raise FileExistsError(f'Refusing overwrite: {dest}')
    if not dest.parent.is_dir():
        raise FileNotFoundError(f'Output parent must already exist: {dest.parent}')
    if not room_ids:
        raise ValueError('At least one explicit room ID is required.')
    briefs = read(BRIEFS)
    brief_rows = {r['id']: r for r in briefs['rooms']}
    plan = read(PLAN)
    plan_rows = {r['id']: r for r in plan['rooms']}
    zone = read(ZONE)
    zone_rows = {r['source_room']['id']: r for r in zone['rooms']}
    fit = read(FIT)
    baseline = read(BASELINE)
    manifest = read(MANIFEST)
    asset = next(a for a in manifest['assets'] if a['id'] == 'CCS15')
    if len(room_ids) != len(set(room_ids)):
        raise ValueError('Room IDs must be unique.')
    unknown = sorted(set(room_ids) - set(brief_rows))
    if unknown:
        raise ValueError(f'Unknown room IDs: {unknown}')
    alias = {'Waterworks-W': 'WaterworksW'}
    room_meta = {}
    for rid in room_ids:
        tile = alias.get(zone_rows[rid]['logical_zone'], zone_rows[rid]['logical_zone'])
        if tile not in baseline or tile not in fit['pivots']:
            raise ValueError(f'No source baseline/pivot for {rid}: {tile}')
        room_meta[rid] = (plan_rows[rid], tile)
    sync_spec = importlib.util.spec_from_file_location('_read_only_room_wall_sync', SYNC)
    assert sha(SYNC) == SYNC_SHA256, 'Reviewed source projection helper changed'
    sync = importlib.util.module_from_spec(sync_spec)
    sync_spec.loader.exec_module(sync)
    projection = sync.projection()
    rows = fit['placements']
    effective = {int(k): row for k, row in projection['effective'] if str(k).isdigit()}
    removed = set(projection['removals'])
    candidate_indices = defaultdict(list)
    for i in range(len(rows) - 1):
        a, b = rows[i:i + 2]
        if (a['tile'] == b['tile'] and a['id'] == 'CCS15' and b['id'] == 'BACKING_TX01'
                and a['role'] == 'source exposed wall veneer' and b['role'] == 'source wall seam backing'):
            candidate_indices[a['tile']].append(i)
    all_authored = list(plan['rooms'])
    room_results = []
    selected_global = {}
    evaluated_by_index = defaultdict(list)
    for rid in room_ids:
        target, tile = room_meta[rid]
        source = baseline[tile]
        wallactor = next(a for a in source['actors'] if a['label'] == 'Warrens_Greybox_wall')
        flooractor = next(a for a in source['actors'] if a['label'] == 'Warrens_Greybox_floor')
        walls, floors = wallactor['components'][0]['instances'], flooractor['components'][0]['instances']
        pivot = fit['pivots'][tile]
        evaluations = [pair_geometry(i, rows, target, all_authored, effective, removed, asset,
                                     walls, floors, pivot, tile)
                       for i in candidate_indices[tile]]
        eligible = [e for e in evaluations if not e['reasons']]
        for e in evaluations:
            evaluated_by_index[e['source_keys'][0]].append((rid, e))
        keys = sorted(k for e in eligible for k in e['source_keys'])
        for k in keys:
            selected_global.setdefault(k, []).append(rid)
        histogram = Counter(reason for e in evaluations for reason in e['reasons'])
        room_results.append({
            'id': rid, 'label': target.get('label') or brief_rows[rid].get('label', ''),
            'zone': brief_rows[rid]['zone'], 'fitted_tile': tile,
            'source_floor_z_m': target['z'], 'authored_top_z_m': target.get('top'),
            'room_shape': 'poly' if 'poly' in target else ('rect' if 'rect' in target else 'none'),
            'pivot_m': pivot, 'evaluation': {'candidate_complete_pairs': len(evaluations),
                                             'eligible_complete_pairs': len(eligible),
                                             'eligible_source_keys': keys,
                                             'reason_counts_nonexclusive': dict(sorted(histogram.items()))},
            'selected_pair_evidence': eligible,
            'empty_selection_status': None if eligible else 'NO_ELIGIBLE_SOURCE_FACES: no candidate passed all source bounds, room ownership, wall-box, floor-box, and effective-projection checks',
        })
    duplicate_keys = {str(k): v for k, v in selected_global.items() if len(v) > 1}
    approved = approved_sets()
    overlap = {}
    for room in room_results:
        rkeys = set(room['evaluation']['eligible_source_keys'])
        overlap[room['id']] = {name: sorted(rkeys & set(ref['source_keys'])) for name, ref in approved.items()}
    # r04 golden validation is part of the prescribed regression contract.
    r04_path = ROOT / APPROVED_MEMBERSHIP['DarkSlate']['path']
    r04 = read(r04_path)
    r04_keys = set(r04['selected_source_keys'])
    golden = set()
    for room in room_results:
        if room['id'] in ('catacomb', 'lair', 'vault'):
            golden.update(room['evaluation']['eligible_source_keys'])
    golden_checked = {'catacomb', 'lair', 'vault'}.issubset(room_ids)
    if golden_checked:
        assert len(golden) == len(r04_keys) == 484 and golden == r04_keys, 'Catacomb/Pit/Vault golden source-key set differs from r04'
    files = [FIT, PLAN, ZONE, BASELINE, SYNC, MANIFEST, BRIEFS, ROOT / 'Tools/ChainCrossingKit/Output/FBX/WarrensC_CCS15_RoomWallBay_Mars_SM.fbx']
    files.extend(ROOT / s['path'] for s in APPROVED_MEMBERSHIP.values())
    files.extend(ROOT / s['review'] for s in APPROVED_MEMBERSHIP.values() if s['review'] and (ROOT / s['review']).is_file())
    inputs = {p.relative_to(ROOT).as_posix(): sha(p) for p in files}
    input_contract = {'current_projection': {'sync_projection_status': projection.get('boundary'),
                                             'removal_indices': sorted(removed),
                                             'effective_visible_rows': len(projection['effective'])},
                      'fit_placement_count': len(rows),
                      'ccs15_asset_bounds_cm': {'min': asset['bounds_min_cm'], 'max': asset['bounds_max_cm']},
                      'source_face_probe_contract': {'normal_offsets_m': list(OFFSETS), 'normal_samples_per_offset': FACE_SAMPLES,
                                                     'floor_fractions': list(FLOOR_FRACTIONS)},
                      'geometry_contract': 'Transforms all eight manifest bound corners with fitted plan yaw; CCS15 local x=2m width, y=.35m thickness, z=3m height; exact transformed face/backing width and vertical bounds checked; no pivot added to fitted row at; source box witnesses use tile pivot.'}
    report = {'status': 'SOURCE_ONLY_REVIEW_INVENTORY', 'schema': 'warrens-current-room-wall-coverage-r01',
              'authority_note': 'This is a finite source membership inventory, not a material choice, art approval, runtime observation, or claim of full-room coverage.',
              'room_ids_requested': room_ids, 'input_sha256': inputs, 'input_contract': input_contract,
              'membership_references': {k: {kk: vv for kk, vv in v.items() if kk != 'source_keys'} for k, v in approved.items()},
              'approved_overlap_source_keys_by_room': overlap,
              'duplicate_eligible_source_keys_across_requested_rooms': duplicate_keys,
              'room_inventory': room_results,
              'golden_catacomb_pit_vault_r04': {'checked': golden_checked,
                                                 'pair_count': len(golden) // 2,
                                                 'source_key_count': len(golden),
                                                 'matches_r04_exactly': golden == r04_keys if golden_checked else None,
                                                 'r04_reference': APPROVED_MEMBERSHIP['DarkSlate']['path']},
              'limitations': ['Source geometry, fitted rows, polygon ownership, and projection only; no rendered or runtime wall visibility was observed.',
                              'Only exact adjacent CCS15 veneer/BACKING_TX01 pairs are considered; floors, ceilings, trim, props, noncardinal faces, and other mesh families are out of scope.',
                              'No selection implies adoption: room overlap is listed for root ownership review, and approved references are membership records rather than blanket room art approval.',
                              'Rooms without authored polygons/rectangles can remain explicitly unevaluable or empty; no footprint is inferred from a neighboring room.']}
    if dest.suffix.lower() == '.json':
        if dest.exists():
            raise FileExistsError(f'Refusing overwrite: {dest}')
        if not dest.parent.is_dir():
            raise FileNotFoundError(f'Output parent must already exist: {dest.parent}')
        dest.write_text(json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + '\n', encoding='utf-8')
        return dest
    if dest.exists():
        raise FileExistsError(f'Refusing overwrite: {dest}')
    dest.mkdir(parents=False)
    out = dest / 'coverage.json'
    out.write_text(json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + '\n', encoding='utf-8')
    return out


def cli():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--room-ids', nargs='+', required=True, help='Explicit authored room IDs from room_briefs.json')
    parser.add_argument('--output', required=True, help='New JSON file (parent exists) or a new directory (receives coverage.json)')
    args = parser.parse_args()
    path = run(args.room_ids, args.output)
    print(path)


if __name__ == '__main__':
    cli()
