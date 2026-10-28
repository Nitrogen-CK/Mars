"""Actual two-by-two pigment/PBR swatch using the native Blender material source."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-shape-pbr-r03'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    import bpy
    out=DOC/'periodic-pigment-repeat-r08';assert not out.exists();out.mkdir()
    low=bpy.data.objects['LOW_Bake_Target'];t=low.data.materials[0].node_tree;bs=t.nodes.get('Principled BSDF')
    image=bpy.data.images.load(str(DOC/'grouped-pigment-r08b/Stone_GroupedPigment_BaseColor_R08.png'));image.colorspace_settings.name='sRGB'
    albedo=bs.inputs['Base Color'].links[0].from_node;assert albedo.type=='TEX_IMAGE';albedo.image=image
    for v in low.data.uv_layers.active.data:v.uv*=2
    scene=bpy.context.scene;scene.render.image_settings.color_depth='8'
    output=t.nodes.get('Material Output');surface=output.inputs['Surface'].links[0].from_socket
    emit=t.nodes.new('ShaderNodeEmission');t.links.new(albedo.outputs['Color'],emit.inputs['Color']);t.links.new(emit.outputs[0],output.inputs['Surface'])
    frames=[]
    for name,lit in [('AlbedoOnly_Unlit_2x2',False),('Albedo_Normal_Roughness_Grazing_2x2',True)]:
        if lit:t.links.new(surface,output.inputs['Surface'])
        p=out/(name+'.png');scene.render.filepath=str(p);bpy.ops.render.render(write_still=True);frames.append(dict(file=p.name,sha256=sha(p)))
    (out/'receipt.json').write_text(json.dumps(dict(status='TWO_BY_TWO_CLUSTERED_PIGMENT_AND_PBR_REPEAT',frames=frames,albedo_sha256=sha(DOC/'grouped-pigment-r08b/Stone_GroupedPigment_BaseColor_R08.png'),boundary='Repeated swatch only. Actual masonry uses distinct per-stone UV phase/rotation, not one coherent room-wide motif.'),indent=2)+'\n');print('PIGMENT_2X2_READY',sha(out/'receipt.json'))
if __name__=='__main__':main()
