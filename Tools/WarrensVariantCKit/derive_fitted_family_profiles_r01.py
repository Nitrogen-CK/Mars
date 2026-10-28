"""Measure range-safe native-family tint quantiles from actual source FBXs."""
import collections
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/fitted-context-family-r01'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    import bpy
    from io_scene_fbx import parse_fbx
    source_path = DOC/'native_family_sources_r01.json'
    source = json.loads(source_path.read_text())
    profiles = {}
    for family, row in source['families'].items():
        path = ROOT/row['source_file']
        assert sha(path) == row['source_sha256']
        assert sha(ROOT/('Content/'+row['mesh'].removeprefix('/Game/')+'.uasset')) == row['package_sha256']
        tree, version = parse_fbx.parse(str(path))
        objects, = [v for v in tree.elems if v.id == b'Objects']
        geometry, = [v for v in objects.elems if v.id == b'Geometry']
        layer, = [v for v in geometry.elems if v.id == b'LayerElementColor']
        raw, = [v for v in layer.elems if v.id == b'Colors']
        values = list(raw.props[0])
        raw_range = dict(RGB_min=[min(values[i+k] for i in range(0, len(values), 4)) for k in range(3)], RGB_max=[max(values[i+k] for i in range(0, len(values), 4)) for k in range(3)], colour_entries_outside_UNorm=sum(any(v < 0 or v > 1 for v in values[i:i+3]) for i in range(0, len(values), 4)))
        raw_rgb = {tuple(int(max(0, min(1, values[i+k]))*255) for k in range(3)) for i in range(0, len(values), 4)}
        assert raw_rgb == {tuple(v) for v in row['native_RGB_bytes']}
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.scene.unit_settings.scale_length = .01
        bpy.ops.import_scene.fbx(filepath=str(path), use_custom_normals=True, colors_type='LINEAR')
        obj, = [o for o in bpy.context.scene.objects if o.type == 'MESH']
        mesh = obj.data
        mesh.calc_loop_triangles()
        assert len(mesh.loop_triangles) == row['native_render_triangles']
        colours = mesh.color_attributes.active_color
        assert colours.domain == 'CORNER'
        weights = collections.defaultdict(float)
        count = 0
        for triangle in mesh.loop_triangles:
            if triangle.material_index != 0:
                continue
            z = triangle.normal.z
            if family == 'Walls' and abs(z) > .01:
                continue
            if family == 'Floor' and z < .99:
                continue
            if family == 'Ceiling' and z > -.99:
                continue
            rgb = [tuple(int(max(0, min(1, v))*255) for v in colours.data[i].color[:3]) for i in triangle.loops]
            assert rgb[0] == rgb[1] == rgb[2] and min(rgb[0]) > 0
            weights[rgb[0]] += triangle.area
            count += 1
        assert weights and count
        ordered = sorted(weights.items(), key=lambda item: (sum(item[0]), item[0]))
        total = sum(weights.values())
        cumulative = []
        value = 0.
        for rgb, area in ordered:
            value += area/total
            cumulative.append((rgb, value))
        swatches = []
        index = 0
        for sample in range(64):
            quantile = (sample+.5)/64
            while cumulative[index][1] < quantile:
                index += 1
            swatches.append([v/255 for v in cumulative[index][0]])
        mean = [sum(rgb[k]/255*area/total for rgb, area in ordered) for k in range(3)]
        approximation = [sum(v[k] for v in swatches)/64 for k in range(3)]
        profiles[family] = dict(source=row, source_raw_range=raw_range, verified_clamp_then_truncate_native_RGB_set=True, area_weighted_triangles=count, weighted_area_cm2=total, unique_area_weighted_colours=len(weights), vertex_gain=1.2, quantile_swatches_UNorm=swatches, quantile_CDF_resolution=1/64, exact_weighted_mean_UNorm=mean, quantile_mean_UNorm=approximation, mean_delta_UNorm=[b-a for a, b in zip(mean, approximation)])
        print('FITTED_FAMILY_PROFILE', family, count, len(weights), profiles[family]['mean_delta_UNorm'], flush=True)
    output = DOC/'fitted_family_profiles_r01.json'
    assert not output.exists()
    output.write_text(json.dumps(dict(status='MEASURED_NATIVE_FAMILY_VALUES_AND_64_AREA_QUANTILES_NOT_ART_ACCEPTED', source_receipt_sha256=sha(source_path), tool_sha256=sha(__file__), families=profiles, boundary='Every clamped/truncated FBX RGB byte set matches actual native render data exactly. Existing accepted-source raw clipping is recorded; this targets actual accepted native tint, not equivalence to unclipped Blender floats. Palette swatches are 64 measured area-weighted quantiles; statistical CDF resolution and actual mean error are recorded, not exact source-cell assignment. No screenshot-derived tint or second drawn grid. Intended for a separate fitted-static-stone triplanar family shader proposal; no native graph, assets, bindings or source changes.'), indent=2)+'\n')


if __name__ == '__main__':
    main()
