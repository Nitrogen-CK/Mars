"""Headless Blender repeat diagnostic; never resamples or overwrites the source PNG."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]


def main():
    import bpy
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', required=True)
    parser.add_argument('--sha256', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    source, output = (ROOT / args.image).resolve(), (ROOT / args.output).resolve()
    assert source.is_relative_to(ROOT) and output.is_relative_to(ROOT)
    assert source.is_file() and not output.exists() and not output.with_suffix('.json').exists()
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    assert digest == args.sha256
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = scene.render.resolution_y = 1600
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.film_transparent = False
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'None'
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    mesh = bpy.data.meshes.new('Diagnostic8mPlane')
    mesh.from_pydata([(-4,-4,0),(4,-4,0),(4,4,0),(-4,4,0)], [], [(0,1,2,3)])
    uv = mesh.uv_layers.new(name='TwoMetreRepeat')
    for loop, co in zip(mesh.loops, [(0,0),(4,0),(4,4),(0,4)]):
        uv.data[loop.index].uv = co
    plane = bpy.data.objects.new('TileStress_Only', mesh)
    scene.collection.objects.link(plane)
    material = bpy.data.materials.new('DiagnosticUnlitAlbedo')
    material.use_nodes = True
    material.node_tree.nodes.clear()
    image = bpy.data.images.load(str(source), check_existing=False)
    image.colorspace_settings.name = 'sRGB'
    tex = material.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = image
    tex.extension = 'REPEAT'
    emission = material.node_tree.nodes.new('ShaderNodeEmission')
    out = material.node_tree.nodes.new('ShaderNodeOutputMaterial')
    material.node_tree.links.new(tex.outputs['Color'], emission.inputs['Color'])
    material.node_tree.links.new(emission.outputs[0], out.inputs['Surface'])
    mesh.materials.append(material)
    cam_data = bpy.data.cameras.new('DiagnosticOrthographic')
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 8
    cam = bpy.data.objects.new('DiagnosticOrthographic', cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0,0,10)
    scene.camera = cam
    scene.render.filepath = str(output)
    bpy.ops.render.render(write_still=True)
    assert hashlib.sha256(source.read_bytes()).hexdigest() == digest
    record = dict(source=args.image, source_sha256=digest, repeat_count=[4,4], plane_metres=[8,8],
        texture_repeat_metres=[2,2], unlit=True, source_modified=False,
        output_sha256=hashlib.sha256(output.read_bytes()).hexdigest(),
        boundary='Synthetic flat repeat diagnostic only; no actual room, geometry scale or Unreal acceptance.')
    output.with_suffix('.json').write_text(json.dumps(record, indent=2) + '\n')
    print('TILE_PROBE_RENDERED', str(output), record['output_sha256'], flush=True)


if __name__ == '__main__':
    main()
