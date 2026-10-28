"""Independent source/derived reopen audit and three owned FBX exports only."""
import argparse,hashlib,importlib.util,json,math,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02'
PREFIX='CatacombPilot_R02_'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def main():
    import bpy
    from mathutils import Vector
    parser=argparse.ArgumentParser();parser.add_argument('--study',required=True);parser.add_argument('--output',required=True)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);study=(ROOT/args.study).resolve();out=(ROOT/args.output).resolve()
    assert study.is_relative_to(DOC.resolve()) and out.is_relative_to(DOC.resolve()) and not out.exists()
    receipt=read(study/'receipt.json');source=HERE/'Output/WarrensVariantC_Diorama.blend';derived=study/'CatacombPilot_R02.blend'
    assert Path(bpy.data.filepath).resolve()==source.resolve() and sha(source)==receipt['source_sha256']
    assert sha(derived)==receipt['derived_sha256']
    for frame in receipt['frames']:assert sha(study/frame['file'])==frame['sha256']
    assert all(sha(ROOT/k)==v for k,v in receipt['guards'].items())
    spec=importlib.util.spec_from_file_location('_audit_pilot_sync',HERE/'sync_art_libraries.py');sync=importlib.util.module_from_spec(spec);spec.loader.exec_module(sync)
    scene=bpy.data.scenes['02_VariantC_Cutaway'];bpy.context.window.scene=scene;bpy.context.view_layer.update()
    oldmesh={m.name:sync.mesh_hash(m) for m in bpy.data.meshes}
    oldmat={m.name:sync.stable(sync.nodes(m.node_tree)) for m in bpy.data.materials if m.use_nodes}
    oldobjects={o.name:dict(matrix=[list(v) for v in o.matrix_world],mesh=o.data.name if o.type=='MESH' else None,
        collection=o.instance_collection.name if o.instance_type=='COLLECTION' else None,hide=o.hide_render) for o in scene.objects}
    bpy.ops.wm.open_mainfile(filepath=str(derived),load_ui=False)
    scene=bpy.data.scenes['02_VariantC_Cutaway'];bpy.context.window.scene=scene;bpy.context.view_layer.update()
    assert all(sync.mesh_hash(bpy.data.meshes[k])==v for k,v in oldmesh.items())
    assert all(sync.stable(sync.nodes(bpy.data.materials[k].node_tree))==v for k,v in oldmat.items())
    changed_bindings=[];changed_visibility=[]
    for name,prior in oldobjects.items():
        obj=scene.objects[name];assert [list(v) for v in obj.matrix_world]==prior['matrix'],name
        assert (obj.data.name if obj.type=='MESH' else None)==prior['mesh'],name
        col=obj.instance_collection.name if obj.instance_type=='COLLECTION' else None
        if col!=prior['collection']:changed_bindings.append(name)
        if obj.hide_render!=prior['hide']:changed_visibility.append(name)
    assert sorted(changed_bindings)==['WVC026_Assembly_36578','WVC081_Assembly_36579']
    fit=read(HERE/'Output/fitted_instances.json')['placements']
    allowed={fit[i]['id']+'_Assembly_'+str(i) for i in receipt['suppressed_original_fit_keys']}
    assert all(name.split('.')[0] in allowed for name in changed_visibility)
    manifest_path=DOC/'geometry-r05/room_geometry.json';manifest=read(manifest_path)
    assert sha(manifest_path)==receipt['manifest_sha256']
    cells={tuple(c['cell']):c for c in manifest['admitted_floor_cells']}
    ceiling={tuple(c['cell']):c for c in manifest['ceiling_faces']}
    validation={}
    for kind in ('walls','floor','ceiling'):
        obj=bpy.data.objects[PREFIX+kind];record=next(r for r in receipt['new_geometry'] if r['kind']==kind)
        assert sync.mesh_hash(obj.data)==record['mesh_inventory']
        failures=[]
        for vertex in obj.data.vertices:
            x,y,z=vertex.co.x+58,55-vertex.co.y,vertex.co.z
            if kind=='walls':
                matched=any(f['tangent_bounds'][0]-2e-5<=([x,y][1-f['axis']])<=f['tangent_bounds'][1]+2e-5 and
                    f['z_bounds'][0]-2e-5<=z<=f['z_bounds'][1]+2e-5 and
                    .0129-2e-5<=([x,y][f['axis']]-f['plane'])*f['normal_sign']<=.018+2e-5 for f in manifest['wall_faces'])
            else:
                ix,iy=math.floor(x/.5),math.floor(y/.5);witness=[]
                for a in (ix-1,ix,ix+1):
                    for b in (iy-1,iy,iy+1):
                        c=(cells if kind=='floor' else ceiling).get((a,b))
                        if c and c['rect'][0]-2e-5<=x<=c['rect'][2]+2e-5 and c['rect'][1]-2e-5<=y<=c['rect'][3]+2e-5:
                            d=z if kind=='floor' else c['z']-z
                            if (.0089-2e-5<=d<=.012+2e-5 if kind=='floor' else .0129-2e-5<=d<=.018+2e-5):witness.append(c)
                matched=bool(witness)
            if not matched:failures.append([x,y,z])
        assert not failures,(kind,len(failures),failures[:3])
        validation[kind]=dict(vertices=len(obj.data.vertices),all_vertices_source_supported=True,stone_count=record['stone_count'])
    # Verify all formerly missing/plain-wall directions against the actual
    # saved derived geometry, without rendering or changing its original file.
    camera=bpy.data.objects[PREFIX+'standing'];scene.camera=camera;bpy.context.view_layer.update();frame=camera.data.view_frame(scene=scene)
    lo=[min(v[i] for v in frame) for i in (0,1)];hi=[max(v[i] for v in frame) for i in (0,1)];deps=bpy.context.evaluated_depsgraph_get();rays=[]
    for x,y in [(510,300),(750,300),(1000,320),(1000,390),(1040,300)]:
        d=Vector((lo[0]+(hi[0]-lo[0])*x/1250,lo[1]+(hi[1]-lo[1])*(1-y/813),frame[0].z));d=(camera.matrix_world.to_3x3()@d).normalized()
        hit,at,n,i,o,w=scene.ray_cast(deps,camera.location,d)
        assert hit and o.name==PREFIX+'walls',(x,y,hit,o.name if o else None)
        rays.append(dict(pixel=[x,y],object=o.name,plan_at=[at.x+58,55-at.y,at.z],material=o.material_slots[o.data.polygons[i].material_index].material.name))
    out.mkdir(parents=True);exports=[]
    export_scene=bpy.data.scenes.new(PREFIX+'ExportOnly');bpy.context.window.scene=export_scene;export_scene.unit_settings.system='METRIC';export_scene.unit_settings.scale_length=.01
    for kind in ('walls','floor','ceiling'):
        copies=[]
        for name in (PREFIX+kind,PREFIX+kind+'_Backing'):
            original=bpy.data.objects[name];obj=original.copy();obj.data=original.data.copy();export_scene.collection.objects.link(obj)
            for v in obj.data.vertices:v.co=(v.co-Vector((-72,-21,0)))*100
            for attr in obj.data.color_attributes:
                if attr.name=='StoneTint':
                    for d in attr.data:d.color=tuple(v/1.2 for v in d.color[:3])+(d.color[3],)
            obj.select_set(True);copies.append(obj)
        bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();obj=copies[0]
        obj.name='WVC_CatacombPilot_'+kind.capitalize()+'_R02_SM';obj.data.name=obj.name
        bpy.context.view_layer.update();path=out/(obj.name+'.fbx')
        bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},global_scale=1,
            apply_unit_scale=True,apply_scale_options='FBX_SCALE_NONE',axis_forward='-Y',axis_up='Z',use_mesh_modifiers=False,
            mesh_smooth_type='FACE',use_triangles=True,bake_anim=False,path_mode='STRIP',use_custom_props=True,colors_type='LINEAR')
        bounds=[[min(v.co[i] for v in obj.data.vertices) for i in range(3)],[max(v.co[i] for v in obj.data.vertices) for i in range(3)]]
        exports.append(dict(kind=kind,name=obj.name,file=path.relative_to(ROOT).as_posix(),sha256=sha(path),
            blender_bounds_cm=bounds,unreal_bounds_min_cm=[bounds[0][0],-bounds[1][1],bounds[0][2]],unreal_bounds_max_cm=[bounds[1][0],-bounds[0][1],bounds[1][2]],
            materials=[m.name for m in obj.data.materials],vertex_color_gain=1.2,
            source_material={m.name:('mortar' if 'QuietMortar'in m.name else kind) for m in obj.data.materials},
            placement_plan_metres=[-14,76,0],placement_main_cm=[-8400,2100,0],placement_catacomb_li_cm=[1400,3600,0],collision='NoCollision'))
        bpy.data.objects.remove(obj,do_unlink=True)
    assert all(sha(ROOT/k)==v for k,v in receipt['guards'].items()) and sha(derived)==receipt['derived_sha256']
    result=dict(status='INDEPENDENT_REOPEN_AND_SOURCE_SUPPORT_PASS_FBX_READY_NOT_NATIVE_APPROVED',
        source_sha256=sha(source),study_receipt_sha256=sha(study/'receipt.json'),derived_sha256=sha(derived),
        old_mesh_uv_inventories_equal=len(oldmesh),old_material_graphs_equal=len(oldmat),old_poses_equal=len(oldobjects),
        permitted_binding_changes=changed_bindings,permitted_visibility_changes=changed_visibility,
        vertex_source_support=validation,corrected_wall_rays=rays,exports=exports,guard_count=len(receipt['guards']),
        pigment_settings=receipt['pigment_settings'],tool_sha256=sha(__file__),
        boundary='Independent source/derived disk reopen and finite geometry proof. FBX exported only to new owned folder; no Unreal imports or original asset changes. Native player-light and traversal review required.')
    (out/'audit_export.json').write_text(json.dumps(result,indent=2)+'\n');print('PILOT_AUDIT_EXPORT_PASS',sha(out/'audit_export.json'),flush=True)
if __name__=='__main__':main()
