"""Headless periodic stone substrate: geometry-baked normals and independent roughness."""
import hashlib,json,math,random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-shape-pbr-r03'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    import bpy
    from mathutils import Vector
    from mathutils.geometry import delaunay_2d_cdt
    assert not (OUT/'Stone_Substrate_R03.blend').exists()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16
    seed=31027;rng=random.Random(seed);sites=[]
    for iy in range(5):
        for ix in range(5):
            sites.append(((ix+.5+rng.uniform(-.34,.34))/5,(iy+.5+rng.uniform(-.34,.34))/5,.008+rng.uniform(-.006,.006)))
    points=[];heights=[]
    for ty in (-1,0,1):
        for tx in (-1,0,1):
            for x,y,z in sites:points.append(Vector((x+tx,y+ty)));heights.append(z)
    result=delaunay_2d_cdt(points,[],[],0,1e-8)
    verts,_,faces,orig_v,_,_=result
    assert len(verts)==len(points) and all(len(v)==1 for v in orig_v)
    zs=[heights[v[0]] for v in orig_v]
    mesh=bpy.data.meshes.new('Periodic_Chisel_Surface_ActualGeometry')
    mesh.from_pydata([(v.x,v.y,zs[i]) for i,v in enumerate(verts)],[],faces);mesh.update()
    high=bpy.data.objects.new('HIGH_Periodic_Chisel_1m',mesh);scene.collection.objects.link(high)
    rough_values=[.82,.86,.88,.90,.92]
    for i,value in enumerate(rough_values):
        m=bpy.data.materials.new('DryStone_Finish_'+str(value));m.use_nodes=True
        bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.3,.27,.2,1);bs.inputs['Roughness'].default_value=value
        mesh.materials.append(m)
    for p in mesh.polygons:
        x=sum(mesh.vertices[i].co.x for i in p.vertices)/len(p.vertices)
        y=sum(mesh.vertices[i].co.y for i in p.vertices)/len(p.vertices)
        # Periodic facet identity, independent of colour and height.
        ident=f'{round(x%1,5)}/{round(y%1,5)}'
        p.material_index=int(hashlib.sha256(ident.encode()).hexdigest()[:8],16)%len(rough_values)
        p.use_smooth=False
    lowmesh=bpy.data.meshes.new('LOW_OneMetre_UnitUV')
    lowmesh.from_pydata([(0,0,0),(1,0,0),(1,1,0),(0,1,0)],[],[(0,1,2,3)]);lowmesh.update()
    uv=lowmesh.uv_layers.new(name='Physical1m')
    for loop in lowmesh.loops:uv.data[loop.index].uv=lowmesh.vertices[loop.vertex_index].co.xy
    low=bpy.data.objects.new('LOW_Bake_Target',lowmesh);scene.collection.objects.link(low)
    mat=bpy.data.materials.new('Coordinated_Stone_PBR_R03');mat.use_nodes=True;lowmesh.materials.append(mat)
    tree=mat.node_tree;bs=tree.nodes.get('Principled BSDF');target=tree.nodes.new('ShaderNodeTexImage')
    scene.render.bake.use_selected_to_active=True;scene.render.bake.cage_extrusion=.03
    scene.render.bake.max_ray_distance=.06;scene.render.bake.margin=0;scene.render.bake.normal_space='TANGENT'
    for o in scene.objects:o.select_set(False)
    high.select_set(True);low.select_set(True);bpy.context.view_layer.objects.active=low
    maps={}
    for name,kind,green in [('Stone_BroadPlanes_NormalGL_R03','NORMAL','POS_Y'),('Stone_BroadPlanes_NormalDX_R03','NORMAL','NEG_Y'),('Stone_BroadPlanes_Roughness_R03','ROUGHNESS',None)]:
        image=bpy.data.images.new(name,width=1024,height=1024,alpha=False,float_buffer=True,is_data=True)
        image.colorspace_settings.name='Non-Color';target.image=image;tree.nodes.active=target
        if green:scene.render.bake.normal_g=green
        bpy.ops.object.bake(type=kind)
        path=OUT/(name+'.png');image.filepath_raw=str(path);image.file_format='PNG'
        scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGB';scene.render.image_settings.color_depth='16'
        image.save_render(str(path),scene=scene)
        # Reload the actual exported numerical PNG, rather than trusting a bake completion message.
        re=bpy.data.images.load(str(path),check_existing=False);re.colorspace_settings.name='Non-Color'
        import numpy as np
        px=np.empty(1024*1024*4,dtype=np.float32);re.pixels.foreach_get(px);px=px.reshape(1024,1024,4)[:,:,:3]
        edge=dict(x_mean=float(np.abs(px[:,0]-px[:,-1]).mean()),y_mean=float(np.abs(px[0]-px[-1]).mean()),
                  x_max=float(np.abs(px[:,0]-px[:,-1]).max()),y_max=float(np.abs(px[0]-px[-1]).max()))
        metric=dict(minimum=px.min(axis=(0,1)).tolist(),maximum=px.max(axis=(0,1)).tolist(),mean=px.mean(axis=(0,1)).tolist(),opposite_edges=edge)
        if kind=='NORMAL':
            n=px*2-1;length=np.linalg.norm(n,axis=2)
            assert n[:,:,2].min()>.93 and np.abs(length-1).max()<.002,metric
            metric.update(max_unit_length_error=float(np.abs(length-1).max()),max_tilt_degrees=float(np.degrees(np.arccos(n[:,:,2].clip(-1,1))).max()))
        else:assert px.min()>.80 and px.max()<.94,metric
        maps[name]=dict(file=path.relative_to(ROOT).as_posix(),sha256=sha(path),metrics=metric)
        print('BAKE_VERIFIED',name,metric,flush=True)
    # Real BRDF preview, constant camera/light/exposure; normal GL is used by Blender.
    high.hide_render=True;high.hide_viewport=True
    image=bpy.data.images.load(str(OUT/'Stone_BroadPlanes_BaseColor_R03.png'));image.colorspace_settings.name='sRGB'
    albedo=tree.nodes.new('ShaderNodeTexImage');albedo.image=image;tree.links.new(albedo.outputs['Color'],bs.inputs['Base Color'])
    normal=tree.nodes.new('ShaderNodeTexImage');normal.image=bpy.data.images.load(str(OUT/'Stone_BroadPlanes_NormalGL_R03.png'));normal.image.colorspace_settings.name='Non-Color'
    normal_map=tree.nodes.new('ShaderNodeNormalMap');normal_map.inputs['Strength'].default_value=.55;tree.links.new(normal.outputs['Color'],normal_map.inputs['Color'])
    rough=tree.nodes.new('ShaderNodeTexImage');rough.image=bpy.data.images.load(str(OUT/'Stone_BroadPlanes_Roughness_R03.png'));rough.image.colorspace_settings.name='Non-Color'
    ld=bpy.data.lights.new('Fixed_Neutral_Grazing','AREA');light=bpy.data.objects.new(ld.name,ld);scene.collection.objects.link(light);light.location=(-.6,-.4,.42)
    ld.energy=90;ld.shape='DISK';ld.size=.8;light.rotation_euler=(Vector((.5,.5,0))-light.location).to_track_quat('-Z','Y').to_euler()
    cd=bpy.data.cameras.new('Fixed_Swatch_Camera');camera=bpy.data.objects.new(cd.name,cd);scene.collection.objects.link(camera);camera.location=(.5,-.5,1.3)
    camera.rotation_euler=(Vector((.5,.5,0))-camera.location).to_track_quat('-Z','Y').to_euler();cd.type='ORTHO';cd.ortho_scale=1.5;scene.camera=camera
    scene.world=bpy.data.worlds.new('Neutral_Studio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.15,.15,.15,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.2
    scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.view_settings.exposure=0;scene.view_settings.gamma=1
    scene.render.resolution_x=900;scene.render.resolution_y=800;scene.render.resolution_percentage=100
    scene.render.image_settings.color_mode='RGB';scene.render.image_settings.color_depth='8';bs.inputs['Roughness'].default_value=.88
    scene.render.filepath=str(OUT/'A_BroadShapes_AlbedoOnly_Grazing.png');bpy.ops.render.render(write_still=True)
    tree.links.new(normal_map.outputs['Normal'],bs.inputs['Normal']);tree.links.new(rough.outputs['Color'],bs.inputs['Roughness'])
    scene.render.filepath=str(OUT/'B_BroadShapes_NormalRoughness_Grazing.png');bpy.ops.render.render(write_still=True)
    for im in bpy.data.images:
        if im.source=='FILE':im.pack()
    scene.render.bake.use_selected_to_active=False
    blend=OUT/'Stone_Substrate_R03.blend';bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
    report=dict(status='GEOMETRY_BAKED_PERIODIC_STONE_NORMALS_AND_INDEPENDENT_ROUGHNESS',physical_tile_metres=1,seed=seed,
        sites=sites,source_vertices=len(mesh.vertices),source_faces=len(mesh.polygons),height_metres=[min(zs),max(zs)],maps=maps,
        base_color_file='Stone_BroadPlanes_BaseColor_R03.png',base_color_sha256=sha(OUT/'Stone_BroadPlanes_BaseColor_R03.png'),
        blend_sha256=sha(blend),tool_sha256=sha(__file__),boundary='Fresh owned Blender source only. Normal maps are Cycles selected-to-active tangent bakes of actual periodic flat-shaded shallow facet geometry. Roughness is an independently assigned dry-stone finish per periodic facet, never inferred from albedo. Pigment need not be a physical height edge; color and relief are different properties. No brick/mortar seams baked into these maps; existing modeled masonry owns those. Native import/use and actual room review pending.')
    (OUT/'PBR_BAKE_RECEIPT.json').write_text(json.dumps(report,indent=2)+'\n')
    print('STONE_PBR_BAKE_READY',sha(OUT/'PBR_BAKE_RECEIPT.json'),flush=True)
if __name__=='__main__':main()
