"""Procedural finite polygon paint coverage; bake from editable geometry, then compare room."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-shape-pbr-r03'
POLYGONS=[[(.05,.25),(.35,.10),(.62,.22),(.57,.48),(.23,.62),(.05,.48)],
          [(.60,.60),(.91,.49),(.99,.69),(.85,.96),(.59,.89)]]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    import bpy
    from mathutils import Vector
    out=DOC/'paint-coverage-r06';assert not out.exists();out.mkdir()
    bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16
    def emit(name,value):
        m=bpy.data.materials.new(name);m.use_nodes=True;t=m.node_tree;t.nodes.clear()
        e=t.nodes.new('ShaderNodeEmission');e.inputs['Color'].default_value=(value,value,value,1);o=t.nodes.new('ShaderNodeOutputMaterial');t.links.new(e.outputs[0],o.inputs['Surface']);return m
    black=emit('Quiet_Unpainted',0);white=emit('Deliberate_Pigment_Group',1)
    verts=[(-1,-1,.001),(2,-1,.001),(2,2,.001),(-1,2,.001)];faces=[(0,1,2,3)]
    for iy in (-1,0,1):
        for ix in (-1,0,1):
            for poly in POLYGONS:
                start=len(verts);verts.extend((x+ix,y+iy,.002) for x,y in poly);faces.append(tuple(range(start,len(verts))))
    mesh=bpy.data.meshes.new('Finite_Editable_Polygon_PaintRegions');mesh.from_pydata(verts,[],faces);mesh.materials.append(black);mesh.materials.append(white)
    for p in mesh.polygons:p.material_index=int(p.index>0)
    high=bpy.data.objects.new('HIGH_PaintRegion_Geometry',mesh);scene.collection.objects.link(high)
    lm=bpy.data.meshes.new('LOW_MaskTarget');lm.from_pydata([(0,0,0),(1,0,0),(1,1,0),(0,1,0)],[],[(0,1,2,3)]);lm.update()
    uv=lm.uv_layers.new(name='TileUV')
    for l in lm.loops:uv.data[l.index].uv=lm.vertices[l.vertex_index].co.xy
    low=bpy.data.objects.new('LOW_MaskTarget',lm);scene.collection.objects.link(low)
    mat=bpy.data.materials.new('MaskBake');mat.use_nodes=True;lm.materials.append(mat)
    image=bpy.data.images.new('Stone_PaintCoverage_R06',width=1024,height=1024,alpha=False,float_buffer=True,is_data=True);image.colorspace_settings.name='Non-Color'
    n=mat.node_tree.nodes.new('ShaderNodeTexImage');n.image=image;mat.node_tree.nodes.active=n
    high.select_set(True);low.select_set(True);bpy.context.view_layer.objects.active=low
    scene.render.bake.use_selected_to_active=True;scene.render.bake.cage_extrusion=.03;scene.render.bake.max_ray_distance=.06;scene.render.bake.margin=0
    bpy.ops.object.bake(type='EMIT')
    mask=out/'Stone_PaintCoverage_R06.png';scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGB';scene.render.image_settings.color_depth='16'
    image.save_render(str(mask),scene=scene)
    import numpy as np
    a=np.empty(1024*1024*4,dtype=np.float32);image.pixels.foreach_get(a);a=a.reshape(1024,1024,4)[:,:,0]
    coverage=float(a.mean(dtype=np.float64));assert .3<coverage<.45 and np.max(a[0])==np.max(a[-1])==np.max(a[:,0])==np.max(a[:,-1])==0
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'Stone_PaintCoverage_Source_R06.blend'),compress=True)
    source=DOC/'room-quiet-strength-r05/Catacomb_QuietStrength_PBR_R05.blend';assert sha(source)==json.loads((DOC/'room-quiet-strength-r05/receipt.json').read_text())['derived_sha256']
    bpy.ops.wm.open_mainfile(filepath=str(source))
    mask_image=bpy.data.images.load(str(mask),check_existing=False);mask_image.colorspace_settings.name='Non-Color';mask_image.pack()
    changes=[]
    for family in ('walls','floor','ceiling','prop'):
        mat=bpy.data.materials['CatacombPilot_R02_Paint_'+family];t=mat.node_tree
        mix,=[n for n in t.nodes if n.type=='MIX_RGB' and n.blend_type=='MIX' and n.inputs[2].is_linked and n.inputs[2].links[0].from_node.type=='TEX_IMAGE' and n.inputs[2].links[0].from_node.image.name.startswith('Stone_CleanPlanes')]
        old_factor=mix.inputs[0].default_value;albedo=mix.inputs[2].links[0].from_node
        paint=t.nodes.new('ShaderNodeTexImage');paint.image=mask_image;paint.extension='REPEAT';paint.projection=albedo.projection;paint.projection_blend=albedo.projection_blend
        if albedo.inputs['Vector'].is_linked:t.links.new(albedo.inputs['Vector'].links[0].from_socket,paint.inputs['Vector'])
        multiply=t.nodes.new('ShaderNodeMath');multiply.operation='MULTIPLY';multiply.inputs[1].default_value=old_factor;t.links.new(paint.outputs['Color'],multiply.inputs[0]);t.links.new(multiply.outputs[0],mix.inputs[0])
        changes.append(dict(family=family,original_factor=old_factor,mask=paint.name,multiply=multiply.name,delta='Only albedo pigment coverage; normal/roughness/lighting unchanged'))
    scene=bpy.data.scenes['02_VariantC_Cutaway'];bpy.context.window.scene=scene
    r=json.loads((DOC/'room-quiet-strength-r05/receipt.json').read_text());lights=json.loads((DOC.parent/'catacomb-reference-match-r02/pilot-preview-r03/receipt.json').read_text())['lights'];frames=[]
    for row in r['frames']:
        warm=row['warm'];camera=bpy.data.objects[row['camera']];assert camera.type=='CAMERA'
        for l in lights:bpy.data.objects[l['name']].hide_render=(l['group']=='warm')!=warm
        lamp=bpy.data.objects['CatacombPilot_R02_PlayerLanternReviewProxy'];lamp.location=camera.location+(camera.matrix_world.to_quaternion()@Vector((.25,-.45,-.45)))
        scene.camera=camera;p=out/row['file'];scene.render.filepath=str(p);bpy.ops.render.render(write_still=True);frames.append(dict(row,sha256=sha(p)))
    derived=out/'Catacomb_GroupedPaint_PBR_R06.blend';bpy.ops.wm.save_as_mainfile(filepath=str(derived),compress=True)
    receipt=dict(status='ONE_AXIS_FINITE_PAINT_COVERAGE_DIAGNOSTIC',polygons=POLYGONS,covered_fraction=coverage,quiet_fraction=1-coverage,mask_sha256=sha(mask),source_sha256=sha(source),derived_sha256=sha(derived),changes=changes,frames=frames,tool_sha256=sha(__file__),
        boundary='Coverage only: existing R04 image colour appears inside two deliberate finite polygon regions, with truly quiet stone base elsewhere. Existing random per-stone UV phase prevents a coherent grid of paint regions. No normal/roughness/geometry/light/Unreal or source-library changes.')
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('GROUPED_PAINT_COVERAGE_READY',sha(out/'receipt.json'),flush=True)
if __name__=='__main__':main()
