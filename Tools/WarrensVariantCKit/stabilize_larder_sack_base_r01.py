"""Derived-only stable sack contact profile; existing source FBX never changes."""
import hashlib,importlib.util,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/stable-sack-foot-r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    import bpy
    from mathutils import Matrix,Vector
    assert not OUT.exists()
    spec=importlib.util.spec_from_file_location('_sack_guard',Path(__file__).with_name('room_art_capture_r33.py'));guard=importlib.util.module_from_spec(spec);spec.loader.exec_module(guard);guard.guard()
    source=ROOT/'Tools/ChainCrossingKit/Output/FBX/WarrensC_CCS68_ClothSack_Mars_SM.fbx';source_hash=sha(source)
    bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=.01
    bpy.ops.import_scene.fbx(filepath=str(source),use_custom_normals=True);body,=[o for o in scene.objects if o.type=='MESH'];mesh=body.data
    assert len(mesh.polygons)==320 and all(len(p.vertices)==3 for p in mesh.polygons) and len(mesh.materials)==2 and len(mesh.uv_layers)==1
    matrix=[list(v) for v in body.matrix_world];assert all(abs(matrix[i][j]-(i==j))<1e-7 for i in range(4) for j in range(4));body.matrix_world=Matrix.Identity(4)
    original=body.copy();original.data=mesh.copy();scene.collection.objects.link(original);original.name='SOURCE_Sack_InspectionOnly';original.hide_render=True
    points=[list(v.co) for v in mesh.vertices];triangles=[list(p.vertices) for p in mesh.polygons];uv=[list(v.uv) for v in mesh.uv_layers[0].data];normals=[v.vector.copy() for v in mesh.corner_normals]
    bounds=[[min(p[k] for p in points) for k in range(3)],[max(p[k] for p in points) for k in range(3)]]
    spec=importlib.util.spec_from_file_location('_contact_profile',Path(__file__).with_name('mesh_profile_contact_r01.py'));fit=importlib.util.module_from_spec(spec);spec.loader.exec_module(fit);profile=fit.adjacent_contact_profile(points,triangles)
    changes=[];changed_ids={i for i,j in profile['pairs']};affected=[p.index for p in mesh.polygons if set(p.vertices)&changed_ids]
    old_face_normals={p.index:p.normal.copy() for p in mesh.polygons}
    for i,j in profile['pairs']:
        before=list(mesh.vertices[i].co);mesh.vertices[i].co.x=points[j][0];mesh.vertices[i].co.y=points[j][1];changes.append(dict(vertex=i,adjacent_vertex=j,before_cm=before,after_cm=list(mesh.vertices[i].co)))
    mesh.update()
    for p in mesh.polygons:
        if p.index in affected:
            assert p.area>1e-6 and p.normal.dot(old_face_normals[p.index])>0
            for index in p.loop_indices:normals[index]=p.normal.copy()
    mesh.normals_split_custom_set(normals);mesh.update()
    assert [list(p.vertices) for p in mesh.polygons]==triangles and [list(v.uv) for v in mesh.uv_layers[0].data]==uv
    assert all(list(v.co)==points[v.index] for v in mesh.vertices if v.index not in changed_ids)
    assert all(v.co.z==points[v.index][2] for v in mesh.vertices)
    final_bounds=[[min(v.co[k] for v in mesh.vertices) for k in range(3)],[max(v.co[k] for v in mesh.vertices) for k in range(3)]];assert final_bounds==bounds
    OUT.mkdir(parents=True);body.name='WVC_Larder_StableFootSack_R01_SM';mesh.name=body.name;bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
    fbx=OUT/(body.name+'.fbx');bpy.ops.export_scene.fbx(filepath=str(fbx),use_selection=True,object_types={'MESH'},global_scale=1,apply_unit_scale=True,apply_scale_options='FBX_SCALE_NONE',axis_forward='-Y',axis_up='Z',use_mesh_modifiers=False,mesh_smooth_type='FACE',use_triangles=False,bake_anim=False,path_mode='STRIP',use_custom_props=True,colors_type='LINEAR')
    # Both comparison stages receive the same neutral geometry-inspection finish.
    mat=bpy.data.materials.new('Sack_Contact_InspectionOnly');mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.25,.18,.085,1);bs.inputs['Roughness'].default_value=.88
    tie=bpy.data.materials.new('Sack_Tie_InspectionOnly');tie.use_nodes=True;tie.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.08,.065,.04,1);tie.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.92
    for o in (body,original):o.data.materials[0]=mat;o.data.materials[1]=tie;o.scale=(.01,.01,.01)
    scene.unit_settings.scale_length=1
    bpy.ops.mesh.primitive_plane_add(size=4,location=(0,0,.004));floor=bpy.context.object;floor.name='Actual_Veneer_Floor_4mm_Above_SourceBase';fm=bpy.data.materials.new('InspectionFloor');fm.diffuse_color=(.12,.13,.14,1);floor.data.materials.append(fm)
    scene.world=bpy.data.worlds.new('Sack_InspectionWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.15,.17,.20,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35
    for name,at,power,size in [('Key',(1.5,-1.5,2.2),450,1.2),('Fill',(-1.4,-.4,1),160,1.5)]:
        d=bpy.data.lights.new(name,'AREA');d.energy=power;d.size=size;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=at;o.rotation_euler=(Vector((0,0,.4))-o.location).to_track_quat('-Z','Y').to_euler()
    scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=128;scene.render.resolution_x=900;scene.render.resolution_y=800;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX';frames=[]
    for view,at,target in [('approach',(0,-1.31,1.1126),(0,0,.25)),('contact_low',(0,-1,.35),(0,0,.10)),('side',(1,-.4,.65),(0,0,.4))]:
        d=bpy.data.cameras.new(view);d.lens=28;d.clip_start=.001;d.clip_end=20;o=bpy.data.objects.new(view,d);scene.collection.objects.link(o);o.location=at;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();scene.camera=o
        for stage in ('A_source','B_stable'):
            original.hide_render=stage!='A_source';body.hide_render=stage!='B_stable';path=OUT/(view+'_'+stage+'.png');scene.render.filepath=str(path);bpy.ops.render.render(write_still=True);frames.append(dict(file=path.name,sha256=sha(path),camera=list(at),target=list(target),floor_z_metres=.004))
    original.hide_render=True;body.hide_render=False;blend=OUT/'StableSackFoot_Study_R01.blend';bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True);assert sha(source)==source_hash;guard.guard()
    receipt=dict(status='DERIVED_STABLE_SACK_FOOT_CONTACT_STUDY_NOT_NATIVE_ACCEPTED',source=source.relative_to(ROOT).as_posix(),source_sha256=source_hash,source_import_matrix=matrix,profile=profile,changes=changes,changed_vertices=len(changes),affected_triangles=affected,triangles=320,uv_channels=1,bounds_cm=bounds,final_bounds_cm=final_bounds,fbx=fbx.relative_to(ROOT).as_posix(),fbx_sha256=sha(fbx),tool_sha256=sha(__file__),profile_tool_sha256=sha(Path(fit.__file__)),blend_sha256=sha(blend),frames=frames,boundary='Ten actual-adjacency/cyclic matched bottom XY vertices widened to existing adjacent profile; all Z, topology, UV, upper body/ties and bounds preserved. Adjacent changed face normals recomputed; native source model, instances, collision, gameplay and libraries unchanged. Inspection lighting/material only, no native silhouette acceptance. Independent actual FBX audit required.')
    (OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('STABLE_SACK_DERIVED_READY',sha(OUT/'receipt.json'),flush=True)

if __name__=='__main__':main()
