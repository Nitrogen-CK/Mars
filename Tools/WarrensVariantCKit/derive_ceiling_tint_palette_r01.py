"""Measure source FBX front-face tint distribution, using verified native quantization."""
import collections
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    import bpy
    source = DOC/'roof-completion-export-r01/WVC_Larder_HighRoof_R01_SM.fbx'
    proof = DOC/'roof-completion-export-r01/colour_quantization_proof.json'
    native = DOC/'roof-completion-export-r01/native_asset.json'
    expected = json.loads(proof.read_text())
    asset = json.loads(native.read_text())
    assert sha(source) == asset['source_sha256'] and asset['raw_payload_colour_byte_set_exact']
    assert sha(ROOT/('Content/'+asset['target'].removeprefix('/Game/')+'.uasset')) == asset['package_sha256']
    out = DOC/'ceiling-underlay-family-r01'
    assert not out.exists()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.scale_length = .01
    bpy.ops.import_scene.fbx(filepath=str(source), use_custom_normals=True, colors_type='LINEAR')
    obj, = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    mesh = obj.data
    mesh.calc_loop_triangles()
    colours = mesh.color_attributes.active_color
    assert colours.domain == 'CORNER'
    weights = collections.defaultdict(float)
    count = 0
    for triangle in mesh.loop_triangles:
        if triangle.material_index != 0 or triangle.normal.z >= -.99:
            continue
        rgb = [tuple(int(max(0, min(1, v))*255) for v in colours.data[i].color[:3]) for i in triangle.loops]
        assert rgb[0] == rgb[1] == rgb[2] and min(rgb[0]) > 0
        assert list(rgb[0]) in expected['new_expected_RGB_bytes']
        weights[rgb[0]] += triangle.area
        count += 1
    assert weights and count == 786
    total = sum(weights.values())
    cumulative = 0.
    entries = []
    for rgb, area in sorted(weights.items(), key=lambda item: (sum(item[0]), item[0])):
        cumulative += area/total
        entries.append(dict(native_RGB_bytes=rgb, shader_vertex_UNorm=[v/255 for v in rgb], area_cm2=area, probability=area/total, cumulative_probability=cumulative))
    entries[-1]['cumulative_probability'] = 1.
    result = dict(status='AREA_WEIGHTED_VERIFIED_NATIVE_CEILING_VERTEX_TINT_PALETTE_NOT_APPEARANCE_ACCEPTED', source_sha256=sha(source), quantization_proof_sha256=sha(proof), native_asset_receipt_sha256=sha(native), native_package_sha256=asset['package_sha256'], tool_sha256=sha(__file__), front_face_triangles=count, total_front_area_cm2=total, palette=entries, vertex_gain=1.2, weighted_mean_vertex_UNorm=[sum(e['shader_vertex_UNorm'][k]*e['probability'] for e in entries) for k in range(3)], boundary='Actual downward source FBX stone triangles only, weighted by geometric area. Raw LINEAR FBX RGB truncated to native bytes by the previously independently verified importer contract. Values here represent normalized vertex bytes before the accepted shader gain1.2, not screenshot RGB or an additional sRGB decode. New world-cell assignment can reproduce this measured distribution statistically; it does not reproduce source per-cell colour/UV phase exactly.')
    out.mkdir()
    (out/'native_ceiling_tint_palette.json').write_text(json.dumps(result, indent=2)+'\n')
    print('MEASURED_CEILING_TINT_PALETTE', len(entries), count, result['weighted_mean_vertex_UNorm'], flush=True)


if __name__ == '__main__':
    main()
