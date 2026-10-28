"""Render a genuine 2x2 repeat of baked data maps, with no albedo hiding seams."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-shape-pbr-r03'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    import bpy
    source=DOC/'Stone_Substrate_R03.blend';assert Path(bpy.data.filepath).resolve()==source.resolve()
    assert sha(source)==json.loads((DOC/'PBR_BAKE_RECEIPT.json').read_text())['blend_sha256']
    out=DOC/'periodic-data-repeat-r02';assert not out.exists();out.mkdir()
    low=bpy.data.objects['LOW_Bake_Target'];mat=low.data.materials[0];t=mat.node_tree;bs=t.nodes.get('Principled BSDF')
    for link in list(bs.inputs['Base Color'].links):t.links.remove(link)
    bs.inputs['Base Color'].default_value=(.28,.26,.22,1)
    for v in low.data.uv_layers.active.data:v.uv*=2
    normal,=[n for n in t.nodes if n.type=='NORMAL_MAP'];normal.inputs['Strength'].default_value=1
    rough=bs.inputs['Roughness'].links[0].from_node
    assert rough.type=='TEX_IMAGE' and rough.image.name.startswith('Stone_BroadPlanes_Roughness')
    scene=bpy.context.scene;scene.render.image_settings.color_depth='8';frames=[]
    for name,n,r in [('NormalOnly',True,False),('RoughnessOnly',False,True),('NormalAndRoughness',True,True)]:
        for s in ('Normal','Roughness'):
            for l in list(bs.inputs[s].links):t.links.remove(l)
        bs.inputs['Roughness'].default_value=.88
        if n:t.links.new(normal.outputs['Normal'],bs.inputs['Normal'])
        if r:t.links.new(rough.outputs['Color'],bs.inputs['Roughness'])
        p=out/(name+'_2x2_Grazing.png');scene.render.filepath=str(p);bpy.ops.render.render(write_still=True)
        frames.append(dict(file=p.name,sha256=sha(p),normal=n,roughness=r))
    receipt=dict(status='TWO_BY_TWO_DATA_MAP_REPEAT_RENDERED',source_sha256=sha(source),frames=frames,uv_repeat=[2,2],albedo='Disconnected; constant linear .28/.26/.22',boundary='Real BRDF grazing-light swatch for the data maps only. No claim about generated albedo edge continuity or native world rendering.')
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('TWO_BY_TWO_DATA_REPEAT_READY',sha(out/'receipt.json'))
if __name__=='__main__':main()
