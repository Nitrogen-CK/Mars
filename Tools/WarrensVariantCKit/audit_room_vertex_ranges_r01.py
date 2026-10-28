"""Raw FBX native-upload contract for original and quarantined palette exports."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    from io_scene_fbx import parse_fbx
    rows = []
    for room, original in [('hall', 'hall-export-r02'), ('ossuary', 'ossuary-export-r01'), ('cellar', 'cellar-export-r01'), ('sluice', 'sluice-export-r01')]:
        for kind, folder in [('range_safe_original', original), ('quarantined_palette_bake', room+'-palette-export-r01')]:
            path = DOC/folder/'export.json'
            export = json.loads(path.read_text())
            for mesh in export['exports']:
                source = ROOT/mesh['file']
                assert sha(source) == mesh['sha256']
                tree, version = parse_fbx.parse(str(source))
                objects, = [v for v in tree.elems if v.id == b'Objects']
                geometry, = [v for v in objects.elems if v.id == b'Geometry']
                layer, = [v for v in geometry.elems if v.id == b'LayerElementColor']
                colours, = [v for v in layer.elems if v.id == b'Colors']
                indices, = [v for v in layer.elems if v.id == b'ColorIndex']
                raw = list(colours.props[0])
                values = [raw[i:i+4] for i in range(0, len(raw), 4)]
                ids = list(indices.props[0])
                assert len(ids) == mesh['triangles']*3 and all(0 <= i < len(values) for i in ids)
                outside = sum(any(v < 0 or v > 1 for v in values[i][:3]) for i in ids)
                if kind == 'range_safe_original':
                    assert outside == 0, (room, mesh['family'], outside)
                row = dict(room=room, family=mesh['family'], kind=kind, source=mesh['file'], sha256=sha(source), FBX_version=version, referenced_corners=len(ids), RGB_min=[min(values[i][k] for i in ids) for k in range(3)], RGB_max=[max(values[i][k] for i in ids) for k in range(3)], referenced_corners_outside_native_UNorm_range=outside)
                if kind == 'range_safe_original':
                    row['expected_native_RGB_bytes'] = sorted({tuple(int(255*max(0, min(1, v))) for v in values[i][:3]) for i in ids})
                rows.append(row)
                print('RAW_NATIVE_RANGE', room, mesh['family'], kind, outside, flush=True)
    output = DOC/'four_room_vertex_range_contract_r01.json'
    assert not output.exists()
    output.write_text(json.dumps(dict(status='TWELVE_ORIGINAL_FBX_RANGE_SAFE_PALETTE_BAKES_QUARANTINED', tool_sha256=sha(__file__), meshes=rows, boundary='Original mesh vertex colours are inside native UNorm range; expected native bytes use the independently calibrated truncation contract. Palette-baked alternatives are quarantined for native use because Hall/Ossuary wall and Cellar floor values clip. Use original vertices with new owned RoomTint material parameters. This does not prove native import or room appearance.'), indent=2)+'\n')


if __name__ == '__main__':
    main()
