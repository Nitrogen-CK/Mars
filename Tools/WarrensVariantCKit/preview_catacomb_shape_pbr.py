"""Derived-only room-scale PBR shape comparison; originals remain unchanged."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OLD=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02'
OUT=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-shape-pbr-r03'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    import bpy
    from mathutils import Vector
    source=OLD/'pilot-final-shading-r06/CatacombPilot_R06.blend';assert Path(bpy.data.filepath).resolve()==source.resolve()
    assert sha(source)==json.loads((OLD/'pilot-final-shading-r06/receipt.json').read_text())['derived_sha256']
    target=OUT/'room-preview-r04';assert not target.exists();target.mkdir()
    guard=json.loads((ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot/baseline_guard_r02.json').read_text())
    guards=guard['immutable_guards']|guard['collision_hashes'];assert all(sha(ROOT/k)==v for k,v in guards.items())
    scene=bpy.data.scenes['02_VariantC_Cutaway'];bpy.context.window.scene=scene
    source_receipt=json.loads((OLD/'pilot-preview-r03/receipt.json').read_text())
    ceiling=json.loads((OLD/'pilot-preview-r02/receipt.json').read_text())
    frames=[];cameras={}
    for view in ('standing','tomb','ceiling'):
        r=next(v for v in (ceiling if view=='ceiling' else source_receipt)['frames'] if v['view']==view)
        camera,=[o for o in scene.objects if o.type=='CAMERA' and all(abs(a-b)<1e-5 for aa,bb in zip(o.matrix_world,r['camera_matrix']) for a,b in zip(aa,bb))]
        cameras[view]=camera
    scene.render.resolution_x=1280;scene.render.resolution_y=800;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGB';scene.render.image_settings.color_depth='8'
    def render(stage,views=('standing','tomb'),warm=False):
        for l in source_receipt['lights']:bpy.data.objects[l['name']].hide_render=(l['group']=='warm')!=warm
        for view in views:
            camera=cameras[view];assert camera.type=='CAMERA';scene.camera=camera
            lamp=bpy.data.objects['CatacombPilot_R02_PlayerLanternReviewProxy'];lamp.location=camera.location+(camera.matrix_world.to_quaternion()@Vector((.25,-.45,-.45)))
            p=target/(stage+'_'+view+'.png');scene.render.filepath=str(p);bpy.ops.render.render(write_still=True)
            frames.append(dict(stage=stage,view=view,file=p.name,sha256=sha(p),camera=camera.name,camera_matrix=[list(v) for v in camera.matrix_world],warm=warm))
    render('A_PreviousAlbedo')
    albedo=bpy.data.images.load(str(OUT/'Stone_CleanPlanes_BaseColor_R04.png'),check_existing=False);albedo.colorspace_settings.name='sRGB'
    normal=bpy.data.images.load(str(OUT/'Stone_BroadPlanes_NormalGL_R03.png'),check_existing=False);normal.colorspace_settings.name='Non-Color'
    rough=bpy.data.images.load(str(OUT/'Stone_BroadPlanes_Roughness_R03.png'),check_existing=False);rough.colorspace_settings.name='Non-Color'
    changes=[]
    strengths=dict(walls=.8,floor=.3,ceiling=.18,prop=.6)
    rough_mix=dict(walls=.8,floor=.75,ceiling=.35,prop=.65)
    for family in ('walls','floor','ceiling','prop'):
        mat=bpy.data.materials['CatacombPilot_R02_Paint_'+family];t=mat.node_tree;bs=t.nodes.get('Principled BSDF')
        pigment,=[n for n in t.nodes if n.type=='TEX_IMAGE'];pigment.image=albedo
        rn=t.nodes.new('ShaderNodeTexImage');rn.image=rough;rn.extension='REPEAT'
        if pigment.inputs['Vector'].is_linked:t.links.new(pigment.inputs['Vector'].links[0].from_socket,rn.inputs['Vector'])
        rn.projection=pigment.projection;rn.projection_blend=pigment.projection_blend
        nn=t.nodes.new('ShaderNodeTexImage');nn.image=normal;nn.extension='REPEAT'
        if family!='prop' and pigment.inputs['Vector'].is_linked:t.links.new(pigment.inputs['Vector'].links[0].from_socket,nn.inputs['Vector'])
        nm=t.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=strengths[family];t.links.new(nn.outputs['Color'],nm.inputs['Color'])
        if family in ('floor','ceiling'):
            # Keep the deliberate local plane baseline, add only the mapped perturbation.
            base=bs.inputs['Normal'].links[0].from_socket
            geom=t.nodes.new('ShaderNodeNewGeometry')
            sub=t.nodes.new('ShaderNodeVectorMath');sub.operation='SUBTRACT';t.links.new(nm.outputs['Normal'],sub.inputs[0]);t.links.new(geom.outputs['Normal'],sub.inputs[1])
            add=t.nodes.new('ShaderNodeVectorMath');add.operation='ADD';t.links.new(base,add.inputs[0]);t.links.new(sub.outputs['Vector'],add.inputs[1])
            norm=t.nodes.new('ShaderNodeVectorMath');norm.operation='NORMALIZE';t.links.new(add.outputs['Vector'],norm.inputs[0]);ns=norm.outputs['Vector']
        else:ns=nm.outputs['Normal']
        mix=t.nodes.new('ShaderNodeMixRGB');mix.inputs[0].default_value=rough_mix[family]
        value=bs.inputs['Roughness'].default_value;mix.inputs[1].default_value=(value,value,value,1);t.links.new(rn.outputs['Color'],mix.inputs[2])
        changes.append(dict(family=family,normal_node=ns.node.name,normal_socket=ns.name,rough_node=mix.name,rough_mix=rough_mix[family],normal_strength=strengths[family],physical_maps='Existing PigmentUV for surfaces; original UV0 normal and existing local projection roughness on tomb.'))
        mat['shape_pbr_candidate']='R04 clean-plane albedo + actual geometry baked NormalGL/DX R03 + independent Roughness R03'
    render('B_CleanShapes_AlbedoOnly')
    for r in changes:
        mat=bpy.data.materials['CatacombPilot_R02_Paint_'+r['family']];t=mat.node_tree;bs=t.nodes.get('Principled BSDF');t.links.new(t.nodes[r['normal_node']].outputs[r['normal_socket']],bs.inputs['Normal'])
    render('C_CleanShapes_Normal')
    for r in changes:
        mat=bpy.data.materials['CatacombPilot_R02_Paint_'+r['family']];t=mat.node_tree;bs=t.nodes.get('Principled BSDF');t.links.new(t.nodes[r['rough_node']].outputs['Color'],bs.inputs['Roughness'])
    render('D_CleanShapes_NormalRoughness',('standing','tomb','ceiling'))
    render('E_CleanShapes_Warm',('standing','tomb','ceiling'),warm=True)
    for im in (albedo,normal,rough):im.pack()
    derived=target/'Catacomb_CleanShapes_PBR_R04.blend';bpy.ops.wm.save_as_mainfile(filepath=str(derived),compress=True)
    assert all(sha(ROOT/k)==v for k,v in guards.items())
    receipt=dict(status='DERIVED_ROOM_SCALE_CLEAN_SHAPES_PBR_COMPARISON_RENDERED',source_sha256=sha(source),derived_sha256=sha(derived),frames=frames,changes=changes,
        albedo_sha256=sha(OUT/'Stone_CleanPlanes_BaseColor_R04.png'),bake_receipt_sha256=sha(OUT/'PBR_BAKE_RECEIPT.json'),guard_count=len(guards),tool_sha256=sha(__file__),
        boundary='Offline derived room preview only; previous two-practical Blender lighting is not the final native Z light setup. No Unreal source/material/map or original Blender library changes. Normal and roughness additions isolated in successive matched frames. Actual native AA0 view remains required.')
    (target/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('ROOM_PBR_PREVIEW_READY',sha(target/'receipt.json'),flush=True)
if __name__=='__main__':main()
