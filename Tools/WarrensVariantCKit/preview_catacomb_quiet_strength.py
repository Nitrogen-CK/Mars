"""One-axis offline pigment-strength diagnostic on the completed R04 PBR candidate."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-shape-pbr-r03'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    import bpy
    from mathutils import Vector,Matrix
    source=DOC/'room-preview-r04/Catacomb_CleanShapes_PBR_R04.blend';assert Path(bpy.data.filepath).resolve()==source.resolve()
    assert sha(source)==json.loads((DOC/'room-preview-r04/receipt.json').read_text())['derived_sha256']
    out=DOC/'room-quiet-strength-r05';assert not out.exists();out.mkdir()
    mix=dict(walls=.55,floor=.5,ceiling=.15,prop=.35)
    for family,value in mix.items():
        mat=bpy.data.materials['CatacombPilot_R02_Paint_'+family]
        n,=[n for n in mat.node_tree.nodes if n.type=='MIX_RGB' and n.blend_type=='MIX' and n.inputs[2].is_linked and n.inputs[2].links[0].from_node.type=='TEX_IMAGE' and n.inputs[2].links[0].from_node.image.name.startswith('Stone_CleanPlanes')]
        n.inputs[0].default_value=value
    scene=bpy.data.scenes['02_VariantC_Cutaway'];bpy.context.window.scene=scene
    prior=json.loads((DOC/'room-preview-r04/receipt.json').read_text());lights=json.loads((DOC.parent/'catacomb-reference-match-r02/pilot-preview-r03/receipt.json').read_text())['lights'];frames=[]
    for warm,view in [(False,'standing'),(True,'standing'),(True,'tomb')]:
        old=next(r for r in prior['frames'] if r['view']==view)
        camera=bpy.data.objects[old['camera']];assert camera.type=='CAMERA'
        for l in lights:bpy.data.objects[l['name']].hide_render=(l['group']=='warm')!=warm
        lamp=bpy.data.objects['CatacombPilot_R02_PlayerLanternReviewProxy'];lamp.location=camera.location+(camera.matrix_world.to_quaternion()@Vector((.25,-.45,-.45)))
        scene.camera=camera;p=out/(('Warm' if warm else 'Neutral')+'_'+view+'.png');scene.render.filepath=str(p);bpy.ops.render.render(write_still=True)
        frames.append(dict(file=p.name,view=view,warm=warm,sha256=sha(p),camera=old['camera'],camera_matrix=old['camera_matrix']))
    p=out/'Catacomb_QuietStrength_PBR_R05.blend';bpy.ops.wm.save_as_mainfile(filepath=str(p),compress=True)
    r=dict(status='ONE_AXIS_PIGMENT_STRENGTH_DIAGNOSTIC',mix=mix,source_sha256=sha(source),derived_sha256=sha(p),frames=frames,tool_sha256=sha(__file__),boundary='Only pigment strength changed; same new normals/roughness/geometry/camera/old Blender local-light rig. Native creation still held pending shape verdict.')
    (out/'receipt.json').write_text(json.dumps(r,indent=2)+'\n');print('QUIET_STRENGTH_READY',sha(out/'receipt.json'))
if __name__=='__main__':main()
