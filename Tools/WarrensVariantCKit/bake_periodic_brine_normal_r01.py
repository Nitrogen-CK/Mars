"""Independent periodic wave geometry bake; no colour-derived relief or source edits."""
import hashlib,importlib.util,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/brine-wave-normal-r01'
TILE_METRES=4.
HEIGHT_COEFFICIENT_METRES=.008
TERMS=[(3,1,.55),(1,-4,.30),(7,5,.15)]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def field(x,y):
    height=dx=dy=0.
    for a,b,weight in TERMS:
        phase=math.tau*(a*x+b*y)/TILE_METRES
        height+=weight*math.sin(phase);dx+=weight*math.cos(phase)*math.tau*a/TILE_METRES;dy+=weight*math.cos(phase)*math.tau*b/TILE_METRES
    return height*HEIGHT_COEFFICIENT_METRES,dx*HEIGHT_COEFFICIENT_METRES,dy*HEIGHT_COEFFICIENT_METRES

def main():
    import bpy,numpy as np
    from mathutils import Vector
    assert not OUT.exists()
    sp=importlib.util.spec_from_file_location('_brine_bake_guard',Path(__file__).with_name('room_art_capture_r33.py'));guard=importlib.util.module_from_spec(sp);sp.loader.exec_module(guard);guard.guard()
    original=ROOT/'docs/art/warrens-c-dressing-r01/textures/fx/Water_NormalGL.png';original_hash=sha(original)
    bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16
    # Extend beyond the central tile; explicit analytic vertex normals keep
    # periodic derivatives continuous rather than smoothing against a cut edge.
    steps=288;extent=4.5;start=-.25;points=[];normals=[]
    for j in range(steps+1):
        y=start+extent*j/steps
        for i in range(steps+1):
            x=start+extent*i/steps;z,dx,dy=field(x,y);points.append((x,y,z));normals.append(tuple(Vector((-dx,-dy,1)).normalized()))
    faces=[(j*(steps+1)+i,j*(steps+1)+i+1,(j+1)*(steps+1)+i+1,(j+1)*(steps+1)+i) for j in range(steps) for i in range(steps)]
    mesh=bpy.data.meshes.new('HIGH_ActualPeriodicWaveGeometry');mesh.from_pydata(points,[],faces);mesh.update()
    for polygon in mesh.polygons:polygon.use_smooth=True
    mesh.normals_split_custom_set_from_vertices(normals);high=bpy.data.objects.new(mesh.name,mesh);scene.collection.objects.link(high)
    lowmesh=bpy.data.meshes.new('LOW_FourMetre_UnitUV');lowmesh.from_pydata([(0,0,0),(4,0,0),(4,4,0),(0,4,0)],[],[(0,1,2,3)]);lowmesh.update();uv=lowmesh.uv_layers.new(name='PhysicalFourMetres')
    for loop in lowmesh.loops:uv.data[loop.index].uv=lowmesh.vertices[loop.vertex_index].co.xy/4
    low=bpy.data.objects.new(lowmesh.name,lowmesh);scene.collection.objects.link(low);mat=bpy.data.materials.new('Brine_Wave_StudyOnly');mat.use_nodes=True;lowmesh.materials.append(mat);tree=mat.node_tree;bs=tree.nodes['Principled BSDF'];bs.inputs['Base Color'].default_value=(.025,.075,.055,1);bs.inputs['Roughness'].default_value=.45
    target=tree.nodes.new('ShaderNodeTexImage');scene.render.bake.use_selected_to_active=True;scene.render.bake.cage_extrusion=.03;scene.render.bake.max_ray_distance=.06;scene.render.bake.margin=0;scene.render.bake.normal_space='TANGENT'
    bpy.ops.object.select_all(action='DESELECT');high.select_set(True);low.select_set(True);bpy.context.view_layer.objects.active=low
    OUT.mkdir(parents=True);maps={};decoded={}
    for convention,green in [('GL','POS_Y'),('DX','NEG_Y')]:
        name='Brine_PeriodicWave_Normal'+convention+'_R01';image=bpy.data.images.new(name,width=1024,height=1024,alpha=False,float_buffer=True,is_data=True);image.colorspace_settings.name='Non-Color';target.image=image;tree.nodes.active=target;scene.render.bake.normal_g=green;bpy.ops.object.bake(type='NORMAL')
        path=OUT/(name+'.png');scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGB';scene.render.image_settings.color_depth='16';image.save_render(str(path),scene=scene)
        re=bpy.data.images.load(str(path),check_existing=False);re.colorspace_settings.name='Non-Color';px=np.empty(1024*1024*4,dtype=np.float32);re.pixels.foreach_get(px);px=px.reshape(1024,1024,4)[:,:,:3];decoded[convention]=px;n=px*2-1;length=np.linalg.norm(n,axis=2)
        seams=dict(x_mean=float(np.abs(px[:,0]-px[:,-1]).mean()),x_max=float(np.abs(px[:,0]-px[:,-1]).max()),y_mean=float(np.abs(px[0]-px[-1]).mean()),y_max=float(np.abs(px[0]-px[-1]).max()))
        assert np.abs(length-1).max()<.002 and n[:,:,2].min()>.98 and max(seams['x_max'],seams['y_max'])<.005
        maps[convention]=dict(file=path.relative_to(ROOT).as_posix(),sha256=sha(path),minimum=px.min(axis=(0,1)).tolist(),maximum=px.max(axis=(0,1)).tolist(),maximum_unit_length_error=float(np.abs(length-1).max()),maximum_tilt_degrees=float(np.degrees(np.arccos(n[:,:,2].clip(-1,1))).max()),opposite_edge_texel_deltas=seams)
        print('BRINE_NORMAL_BAKED',convention,maps[convention],flush=True)
    gl,dx=decoded['GL'],decoded['DX'];assert np.abs(gl[:,:,[0,2]]-dx[:,:,[0,2]]).max()<4/65535 and np.abs(gl[:,:,1]+dx[:,:,1]-1).max()<4/65535
    analytic_seam=max(max(abs(a-b) for a,b in zip(field(0,TILE_METRES*j/100),field(TILE_METRES,TILE_METRES*j/100))) for j in range(101));analytic_seam=max(analytic_seam,max(max(abs(a-b) for a,b in zip(field(TILE_METRES*j/100,0),field(TILE_METRES*j/100,TILE_METRES))) for j in range(101)));assert analytic_seam<1e-12
    # Same BRDF/camera/light, two 4m repeats across an 8x8m inspection patch.
    high.hide_render=True;high.hide_viewport=True;low.scale=(2,2,1);scene.render.bake.use_selected_to_active=False
    coord=tree.nodes.new('ShaderNodeTexCoord');repeat=tree.nodes.new('ShaderNodeVectorMath');repeat.operation='MULTIPLY';repeat.inputs[1].default_value=(2,2,1);tree.links.new(coord.outputs['UV'],repeat.inputs[0]);tree.links.new(repeat.outputs['Vector'],target.inputs['Vector']);nm=tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=1;tree.links.new(target.outputs['Color'],nm.inputs['Color']);tree.links.new(nm.outputs['Normal'],bs.inputs['Normal'])
    scene.world=bpy.data.worlds.new('Brine_InspectionWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.08,.10,.13,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.3
    for name,at,colour,power,size in [('CoolWindow',(-1,4,3),(.55,.7,1),650,2.5),('WarmPractical',(6,6,2),(1,.55,.18),450,1),('NeutralGrazing',(4,-1,1.5),(1,1,1),200,1.5)]:
        d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=colour;d.size=size;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=at;o.rotation_euler=(Vector((4,4,0))-o.location).to_track_quat('-Z','Y').to_euler()
    d=bpy.data.cameras.new('Fixed_GrazingCamera');d.lens=24;d.clip_start=.01;d.clip_end=100;o=bpy.data.objects.new(d.name,d);scene.collection.objects.link(o);o.location=(4,-3,3.2);o.rotation_euler=(Vector((4,4,0))-o.location).to_track_quat('-Z','Y').to_euler();scene.camera=o
    scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=128;scene.render.resolution_x=1200;scene.render.resolution_y=800;scene.render.resolution_percentage=100;scene.render.image_settings.color_depth='8';scene.view_settings.view_transform='AgX';frames=[]
    for label,path in [('A_OriginalNormal_CorrectFourMetreTile',original),('B_StrongerNormal_SameFourMetreTile',ROOT/maps['GL']['file'])]:
        im=bpy.data.images.load(str(path),check_existing=False);im.colorspace_settings.name='Non-Color';target.image=im;f=OUT/(label+'.png');scene.render.filepath=str(f);bpy.ops.render.render(write_still=True);frames.append(dict(file=f.name,sha256=sha(f)))
    for image in bpy.data.images:
        if image.source=='FILE':image.pack()
    blend=OUT/'Brine_PeriodicWave_Study_R01.blend';bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True);assert sha(original)==original_hash;guard.guard()
    receipt=dict(status='DERIVED_PERIODIC_WAVE_GEOMETRY_TANGENT_NORMAL_BAKE_NOT_NATIVE_ACCEPTED',physical_tile_metres=TILE_METRES,height_coefficient_metres=HEIGHT_COEFFICIENT_METRES,terms=TERMS,actual_height_range_metres=[min(v[2] for v in points),max(v[2] for v in points)],analytic_height_and_derivative_opposite_edge_error=analytic_seam,source_vertices=len(points),source_quads=len(faces),maps=maps,frames=frames,original_normal_gl_sha256=original_hash,blend_sha256=sha(blend),tool_sha256=sha(__file__),boundary='Independent actual periodic 4m wave geometry, same harmonic directions as original with4x height coefficient candidate. GL/DX normals are selected-to-active tangent bakes with inverted green only; no albedo-derived relief, random noise, WPO, water geometry/physics, source texture/material/map or library edits. Inspection BRDF only. Correct original normal tiling in native BEFORE judging stronger map; do not adopt automatically.')
    (OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('PERIODIC_BRINE_STUDY_READY',sha(OUT/'receipt.json'),flush=True)

if __name__=='__main__':main()
