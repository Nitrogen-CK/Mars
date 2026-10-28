"""Bake deliberate pigment groups from editable Blender polygons, then preview the room."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-shape-pbr-r03'
POLYGONS=[[[0.02,0.12],[0.28,0.05],[0.46,0.19],[0.4,0.39],[0.16,0.47],[0.02,0.34]],[[0.1,0.37],[0.32,0.26],[0.52,0.39],[0.46,0.58],[0.21,0.62],[0.06,0.49]],[[0.42,0.21],[0.54,0.18],[0.64,0.27],[0.56,0.36],[0.43,0.33]],[[0.02,0.58],[0.09,0.5],[0.18,0.56],[0.16,0.66],[0.06,0.67]],[[0.6,0.58],[0.81,0.49],[0.98,0.64],[0.93,0.91],[0.72,0.97],[0.57,0.8]],[[0.49,0.7],[0.6,0.58],[0.78,0.64],[0.81,0.79],[0.66,0.86],[0.49,0.82]],[[0.81,0.4],[0.94,0.39],[0.99,0.48],[0.93,0.57],[0.82,0.54]],[[0.46,0.91],[0.54,0.83],[0.64,0.88],[0.62,0.98],[0.5,0.98]],[[0.11,0.77],[0.22,0.7],[0.36,0.75],[0.41,0.9],[0.29,0.96],[0.11,0.91]],[[0.28,0.69],[0.37,0.61],[0.46,0.66],[0.44,0.76],[0.35,0.79]]]
GROUP_COLOURS=[(.28,.22,.13,1),(.15,.155,.135,1),(.215,.19,.145,1)]
POLYGON_TONES=[0,2,1,2,1,2,0,0,2,0]
# First actual bake measured52.09% coverage, above the reviewed40-45% target.
# Shrink each authored contour about its own centroid; retain spacing and hierarchy.
POLYGONS=[[(sum(v[0] for v in p)/len(p)+(x-sum(v[0] for v in p)/len(p))*.9,
            sum(v[1] for v in p)/len(p)+(y-sum(v[1] for v in p)/len(p))*.9) for x,y in p] for p in POLYGONS]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    import bpy
    from mathutils import Vector
    out=DOC/'grouped-pigment-r08b';assert not out.exists();out.mkdir()
    bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16
    scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.view_settings.exposure=0;scene.view_settings.gamma=1
    image=bpy.data.images.load(str(DOC/'Stone_CleanPlanes_BaseColor_R04.png'));image.colorspace_settings.name='sRGB'
    materials=[]
    for i,color in enumerate([(.18,.16,.12,1),*GROUP_COLOURS]):
        m=bpy.data.materials.new('QuietStone' if i==0 else 'PigmentGroup_'+str(i));m.use_nodes=True;t=m.node_tree;t.nodes.clear()
        e=t.nodes.new('ShaderNodeEmission');e.inputs['Color'].default_value=color;o=t.nodes.new('ShaderNodeOutputMaterial');t.links.new(e.outputs[0],o.inputs['Surface'])
        if i:
            tex=t.nodes.new('ShaderNodeTexImage');tex.image=image;tex.extension='REPEAT'
            geom=t.nodes.new('ShaderNodeNewGeometry');t.links.new(geom.outputs['Position'],tex.inputs['Vector'])
            mix=t.nodes.new('ShaderNodeMixRGB');mix.inputs[0].default_value=.12;mix.inputs[1].default_value=color;t.links.new(tex.outputs['Color'],mix.inputs[2]);t.links.new(mix.outputs[0],e.inputs['Color'])
        materials.append(m)
    verts=[(-1,-1,.001),(2,-1,.001),(2,2,.001),(-1,2,.001)];faces=[(0,1,2,3)];ids=[0]
    for iy in (-1,0,1):
        for ix in (-1,0,1):
            for i,poly in enumerate(POLYGONS):
                start=len(verts);verts.extend((x+ix,y+iy,.002+i*.001) for x,y in poly);faces.append(tuple(range(start,len(verts))));ids.append(POLYGON_TONES[i]+1)
    mesh=bpy.data.meshes.new('Authored_Group_Silhouettes');mesh.from_pydata(verts,[],faces)
    for m in materials:mesh.materials.append(m)
    for p,i in zip(mesh.polygons,ids):p.material_index=i
    high=bpy.data.objects.new('HIGH_Deliberate_PigmentGroups',mesh);scene.collection.objects.link(high)
    lm=bpy.data.meshes.new('LOW_OneMetre_AlbedoBake');lm.from_pydata([(0,0,0),(1,0,0),(1,1,0),(0,1,0)],[],[(0,1,2,3)]);lm.update()
    uv=lm.uv_layers.new(name='UV0')
    for loop in lm.loops:uv.data[loop.index].uv=lm.vertices[loop.vertex_index].co.xy
    low=bpy.data.objects.new('LOW_OneMetre_AlbedoBake',lm);scene.collection.objects.link(low)
    m=bpy.data.materials.new('AlbedoBakeTarget');m.use_nodes=True;lm.materials.append(m)
    baked=bpy.data.images.new('Stone_GroupedPigment_BaseColor_R08',width=1024,height=1024,alpha=False,float_buffer=True)
    t=m.node_tree;n=t.nodes.new('ShaderNodeTexImage');n.image=baked;t.nodes.active=n
    high.select_set(True);low.select_set(True);bpy.context.view_layer.objects.active=low
    scene.render.bake.use_selected_to_active=True;scene.render.bake.cage_extrusion=.03;scene.render.bake.max_ray_distance=.06;scene.render.bake.margin=0;bpy.ops.object.bake(type='EMIT')
    albedo=out/'Stone_GroupedPigment_BaseColor_R08.png';scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGB';scene.render.image_settings.color_depth='16';baked.save_render(str(albedo),scene=scene)
    import numpy as np
    p=np.empty(1024*1024*4,dtype=np.float32);baked.pixels.foreach_get(p);p=p.reshape(1024,1024,4)[:,:,:3]
    base=np.array([.18,.16,.12],dtype=np.float32);coverage=float(np.mean(np.max(abs(p-base),axis=2)>.0001));assert .38<coverage<.5,coverage
    assert max(float(abs(p[:,0]-p[:,-1]).max()),float(abs(p[0]-p[-1]).max()))<.00001
    for im in bpy.data.images:
        if im.source=='FILE':im.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'GroupedPigment_Source_R08.blend'),compress=True)
    source=DOC/'room-quiet-strength-r05/Catacomb_QuietStrength_PBR_R05.blend';bpy.ops.wm.open_mainfile(filepath=str(source))
    new=bpy.data.images.load(str(albedo),check_existing=False);new.colorspace_settings.name='sRGB';new.pack()
    for family in ('walls','floor','ceiling','prop'):
        mat=bpy.data.materials['CatacombPilot_R02_Paint_'+family]
        tex,=[n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and n.image.name.startswith('Stone_CleanPlanes_BaseColor')]
        tex.image=new
    scene=bpy.data.scenes['02_VariantC_Cutaway'];bpy.context.window.scene=scene
    previous=json.loads((DOC/'room-quiet-strength-r05/receipt.json').read_text());lights=json.loads((DOC.parent/'catacomb-reference-match-r02/pilot-preview-r03/receipt.json').read_text())['lights'];frames=[]
    for row in previous['frames']:
        warm=row['warm'];camera=bpy.data.objects[row['camera']];assert camera.type=='CAMERA'
        for l in lights:bpy.data.objects[l['name']].hide_render=(l['group']=='warm')!=warm
        lamp=bpy.data.objects['CatacombPilot_R02_PlayerLanternReviewProxy'];lamp.location=camera.location+(camera.matrix_world.to_quaternion()@Vector((.25,-.45,-.45)))
        scene.camera=camera;p=out/row['file'];scene.render.filepath=str(p);bpy.ops.render.render(write_still=True);frames.append(dict(row,sha256=sha(p)))
    derived=out/'Catacomb_GroupedPigment_PBR_R08.blend';bpy.ops.wm.save_as_mainfile(filepath=str(derived),compress=True)
    report=dict(status='AUTHORED_GROUP_HIERARCHY_ROOM_PREVIEW',polygons=POLYGONS,group_base_linear_rgba=GROUP_COLOURS,interior_albedo_variation_mix=.12,quiet_base_linear=[.18,.16,.12],painted_fraction=coverage,quiet_fraction=1-coverage,
        albedo_sha256=sha(albedo),albedo_file=albedo.relative_to(ROOT).as_posix(),source_sha256=sha(source),derived_sha256=sha(derived),frames=frames,tool_sha256=sha(__file__),
        policy='Ten authored polygons in three unequal loose groups; each88percent dominant tone/12percent R04 palette variation. Truly quiet base outside. Both-axis opposite-edge pixels exactly equal. Existing per-stone randomUV phase avoids coherent two-stamp rows. Normals and roughness remain independently geometry/material baked R03, unchanged in this comparison.',
        boundary='Fresh owned Blender source + derived room only, no source-map/native asset/library mutation. Native actual lighting and scale acceptance pending.')
    (out/'receipt.json').write_text(json.dumps(report,indent=2)+'\n');print('GROUPED_PIGMENT_READY',sha(out/'receipt.json'),flush=True)
if __name__=='__main__':main()
