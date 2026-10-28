"""Freeze room-facing Hall/west-rim wall pairs for a bounded material preview."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIT = ROOT / 'Tools/WarrensVariantCKit/Output/fitted_instances.json'
PLAN = ROOT / 'Tools/LevelDesign/anchor_plans/data/warrens_v8c.json'
MANIFEST = ROOT / 'Tools/ChainCrossingKit/Output/asset_manifest.json'
OUT = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/lookdev/hall-painterly-r01'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def inside(point, polygon):
    x, y = point
    result = False
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        if (a[1] > y) != (b[1] > y) and x < (b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:
            result = not result
    return result


def main():
    fit, plan, manifest = [json.loads(p.read_text()) for p in (FIT, PLAN, MANIFEST)]
    rooms = {r['id']: r for r in plan['rooms'] if r['id'] in ('hall', 'rimW')}
    assert set(rooms) == {'hall', 'rimW'}
    polygons = {}
    for name, room in rooms.items():
        if 'poly' in room:
            polygons[name] = room['poly']
        else:
            x0, y0, x1, y1 = room['rect']
            polygons[name] = [[x0,y0],[x1,y0],[x1,y1],[x0,y1]]
    dimensions = next(a for a in manifest['assets'] if a['id'] == 'CCS15')['actual_dimensions_cm']
    rows, pairs, excluded, all_lines = fit['placements'], [], [], []
    axes = {0:(1,-1), 180:(1,1), -90:(0,-1), 90:(0,1)}
    for index, row in enumerate(rows):
        if row['tile'] != 'Hub' or row['id'] != 'CCS15' or row.get('role') != 'source exposed wall veneer':
            continue
        back = rows[index+1]
        assert back['tile'] == 'Hub' and back['id'] == 'BACKING_TX01' and back['role'] == 'source wall seam backing'
        axis, sign = axes[row['yaw']]
        tangent = 1-axis
        width = row['scale'][0]*dimensions[0]/100
        assert abs(width-back['scale'][tangent]) < 1e-5
        assert abs(row['at'][tangent]-back['at'][tangent]) < 1e-5
        assert abs(row['at'][2]-(back['at'][2]-back['scale'][2]/2)) < 1e-5
        assert abs(row['scale'][2]*dimensions[2]/100-back['scale'][2]) < 1e-5
        samples = []
        for offset in (-width/2+.001, 0, width/2-.001):
            point = list(back['at'][:2])
            point[axis] += sign*.15
            point[tangent] += offset
            samples.append(point)
        owners = [name for name, polygon in polygons.items() if all(inside(p, polygon) for p in samples)
                  and row['at'][2] >= rooms[name]['z']-.03]
        line = dict(source_keys=[index,index+1], face_center=back['at'], width=width, tangent=tangent,
                    axis=axis, normal_sign=sign, room_probes=samples, owners=owners)
        all_lines.append(line)
        if len(owners) == 1:
            pairs.append(dict(line, room=owners[0], rows=[row,back]))
        else:
            excluded.append(dict(line, reason='Shared/ambiguous or outside exact complete room face; original retained'))
    keys = [key for pair in pairs for key in pair['source_keys']]
    assert len(keys) == len(set(keys)) and len(all_lines) == 1026 and pairs
    counts = {name: sum(pair['room'] == name for pair in pairs) for name in rooms}
    assert all(counts.values())
    report = dict(status='SOURCE_SELECTION_REVIEW_REQUIRED', inputs={p.relative_to(ROOT).as_posix():sha(p)
        for p in (FIT,PLAN,MANIFEST)}, rooms=rooms, polygons=polygons, pairs=pairs, selected_source_keys=sorted(keys),
        selected_wall_instances=len(keys), veneer_count=len(pairs), backing_count=len(pairs), per_room_pairs=counts,
        hub_wall_pairs=len(all_lines), retained_pairs=len(excluded), exclusions=excluded,
        rule='Full face sampled at both inset ends and center, 15cm toward its source-exposed side, wholly inside one authored room; face bottom at/above room floor. Pair by source-emission adjacency and validate dimensions/pose. No ceiling, floor, timber, shared/ambiguous face or whole-Hub selection.',
        boundary='Proposed finite key set for source-room preview only. Art review of overlay and actual room render required before map adoption.')
    output = OUT / 'wall_selection_r01.json'
    assert not output.exists()
    output.write_text(json.dumps(report, indent=2) + '\n')
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 960 800"><rect width="960" height="800" fill="#182027"/><style>text{fill:#e9e4d8;font:16px sans-serif}</style><text x="24" y="30">Hall / west rim: exact proposed wall-face membership</text>']
    def point(x,y):
        return (50+(x-3)*25, 730-(y-30)*22)
    for name, polygon in polygons.items():
        coords = ' '.join('%.2f,%.2f'%point(*p) for p in polygon)
        svg.append('<polygon points="'+coords+'" fill="none" stroke="#e5d8aa" stroke-width="2"/>')
    for line in all_lines:
        a, b = list(line['face_center'][:2]), list(line['face_center'][:2])
        a[line['tangent']] -= line['width']/2
        b[line['tangent']] += line['width']/2
        xa,ya = point(*a); xb,yb = point(*b)
        color = '#dd9a5f' if line['owners'] == ['hall'] else '#75c6d2' if line['owners'] == ['rimW'] else '#48545e'
        if any(p['source_keys'] == line['source_keys'] for p in pairs):
            weight=3
        else:
            color, weight = '#48545e', 1
        svg.append(f'<line x1="{xa}" y1="{ya}" x2="{xb}" y2="{yb}" stroke="{color}" stroke-width="{weight}"/>')
    svg.append(f'<text x="24" y="770">Hall {counts["hall"]} pairs (orange); west rim {counts["rimW"]} pairs (cyan). Grey remains original.</text></svg>')
    overlay = OUT / 'wall_selection_r01.svg'
    assert not overlay.exists()
    overlay.write_text('\n'.join(svg))
    print(dict(selected_instances=len(keys), per_room_pairs=counts, source_key_sha256=sha(output), overlay=overlay.as_posix()))


if __name__ == '__main__':
    main()
