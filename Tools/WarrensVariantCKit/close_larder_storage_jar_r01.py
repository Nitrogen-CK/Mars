"""Derived-only closed decorative jar successor; original body/FBX untouched."""
import hashlib,importlib.util,json,math,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/closed-storage-jar-r01'
CAP_RADIUS_CM=7.9
CAP_BOTTOM_CM=58.2
CAP_TOP_CM=59.4

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    import bpy,bmesh
    from mathutils import Matrix,Vector
    assert not OUT.exists();p=Path(__file__).with_name('room_art_capture_r33.py');sp=importlib.util.spec_from_file_location('_jar_guard',p);guard=importlib.util.module_from_spec(sp);sp.loader.exec_module(guard);guard.guard()
    manifest=ROOT/'Tools/WarrensVariantCKit/Output/asset_manifest.json';row,=[r for r in json.loads(manifest.read_text())['assets'] if r['id']=='WVC048'];source=manifest.parent/row['fbx'].replace('\\','/');source_sha=sha(source)
    bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=.01
    bpy.ops.import_scene.fbx(filepath=str(source),use_custom_normals=True);body,=[o for o in scene.objects if o.type=='MESH'];body.data.calc_loop_triangles();assert len(body.data.loop_triangles)==292 and len(body.data.materials)==1 and len(body.data.uv_layers)==1
    initial_matrix=[list(r) for r in body.matrix_world];assert all(abs(initial_matrix[i][j]-(i==j))<1e-7 for i in range(4) for j in range(4));body.matrix_world=Matrix.Identity(4)
    original_points=[list(v.co) for v in body.data.vertices];original_triangles=[list(t.vertices) for t in body.data.loop_triangles];original_bounds=[[min(v.co[i] for v in body.data.vertices) for i in range(3)],[max(v.co[i] for v in body.data.vertices) for i in range(3)]]
    assert max(abs(original_bounds[0][i]-row['bounds_min_cm'][i]) for i in range(3))<.001 and max(abs(original_bounds[1][i]-row['bounds_max_cm'][i]) for i in range(3))<.001
    bpy.ops.object.select_all(action='DESELECT');bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=CAP_RADIUS_CM,depth=CAP_TOP_CM-CAP_BOTTOM_CM,end_fill_type='NGON',location=(0,0,(CAP_TOP_CM+CAP_BOTTOM_CM)/2));cap=bpy.context.object;cap.name='ClosedStorageJar_RecessedCeramicPlug';cap.data.materials.append(body.data.materials[0]);cap.data.uv_layers[0].name=body.data.uv_layers[0].name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);cap_bounds=[[min(v.co[i] for v in cap.data.vertices) for i in range(3)],[max(v.co[i] for v in cap.data.vertices) for i in range(3)]]
    assert all(original_bounds[0][i]<cap_bounds[0][i]<=cap_bounds[1][i]<original_bounds[1][i] for i in range(3));cap.data.calc_loop_triangles();assert len(cap.data.loop_triangles)==36
    cap.select_set(True);body.select_set(True);bpy.context.view_layer.objects.active=body;bpy.ops.object.join();body.name='WVC_Larder_ClosedStorageJar_R01_SM';body.data.name=body.name
    assert [list(v.co) for v in body.data.vertices[:len(original_points)]]==original_points
    bm=bmesh.new();bm.from_mesh(body.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(body.data);bm.free();body.data.update();body.data.calc_loop_triangles();assert len(body.data.loop_triangles)==328 and len(body.data.materials)==1 and len(body.data.uv_layers)==1
    assert [list(v.co) for v in body.data.vertices[:len(original_points)]]==original_points
    assert [list(t.vertices) for t in body.data.loop_triangles[:292]]==original_triangles
    final_bounds=[[min(v.co[i] for v in body.data.vertices) for i in range(3)],[max(v.co[i] for v in body.data.vertices) for i in range(3)]];assert final_bounds==original_bounds
    OUT.mkdir(parents=True);fbx=OUT/(body.name+'.fbx');bpy.ops.export_scene.fbx(filepath=str(fbx),use_selection=True,object_types={'MESH'},global_scale=1,apply_unit_scale=True,apply_scale_options='FBX_SCALE_NONE',axis_forward='-Y',axis_up='Z',use_mesh_modifiers=False,mesh_smooth_type='FACE',use_triangles=False,bake_anim=False,path_mode='STRIP',use_custom_props=True,colors_type='LINEAR')
    # Derived neutral geometry inspection only, not the actual game material.
    preview=bpy.data.materials.new('ClosedJar_GeometryInspection_Only');preview.use_nodes=True;bs=preview.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.17,.21,.07,1);bs.inputs['Roughness'].default_value=.88;body.data.materials[0]=preview
    scene.world=bpy.data.worlds.new('ClosedJar_InspectionWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.14,.17,.20,1);scene.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.3
    for name,at,power,size in [('Key',(90,-90,160),500,100),('Fill',(-100,-10,90),250,100)]:
        d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=at;o.rotation_euler=(Vector((0,0,30))-o.location).to_track_quat('-Z','Y').to_euler()
    scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=128;scene.render.resolution_x=850;scene.render.resolution_y=850;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
    frames=[]
    for name,at in [('three_quarter',(90,-120,100)),('top',(30,-40,135)),('side',(110,0,45))]:
        d=bpy.data.cameras.new(name);d.type='ORTHO';d.ortho_scale=100;d.clip_start=.1;d.clip_end=1000;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=at;o.rotation_euler=(Vector((0,0,30))-o.location).to_track_quat('-Z','Y').to_euler();scene.camera=o;scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True);frames.append(dict(file=name+'.png',sha256=sha(OUT/(name+'.png'))))
    blend=OUT/'ClosedStorageJar_Study_R01.blend';bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True);assert sha(source)==source_sha;guard.guard()
    receipt=dict(status='DERIVED_CLOSED_DECOR_JAR_PREVIEW_NOT_NATIVE_ACCEPTED',source=source.relative_to(ROOT).as_posix(),source_sha256=source_sha,source_manifest_sha256=sha(manifest),source_import_matrix=initial_matrix,source_matrix_normalization='Measured original FBX axis offdiagonals below1e-7; only object matrix normalized to identity. Exact body local vertices and all292 original triangle indices retained.',body_vertices=len(original_points),original_triangles=292,new_plug_triangles=36,total_triangles=328,body_geometry_exact=True,original_bounds_cm=original_bounds,final_bounds_cm=final_bounds,cap_radius_cm=CAP_RADIUS_CM,cap_bottom_cm=CAP_BOTTOM_CM,cap_top_cm=CAP_TOP_CM,cap_bounds_cm=cap_bounds,uv_channels=1,source_material_slot=row['materials'][0],fbx=fbx.relative_to(ROOT).as_posix(),fbx_sha256=sha(fbx),derived_blend_sha256=sha(blend),tool_sha256=sha(__file__),frames=frames,boundary='Adds one recessed closed ceramic plug inside the original mouth and45x45x60cm envelope. Original body topology/positions and source FBX bytes unchanged. Derived inspection material/light only; no source model/library/asset import, material assignment, instance pose, collision, collectible jar or forage changes. Native FBX roundtrip/readback and actual room appearance remain pending.')
    (OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('CLOSED_DECOR_JAR_STUDY_READY',sha(OUT/'receipt.json'),flush=True)

if __name__=='__main__':main()
