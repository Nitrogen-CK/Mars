"""Read-only private surface validation, including complete positive-face mapping."""
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def comparator():
    path=Path(__file__).with_name('compare_room_native_triangles_r01.py');spec=importlib.util.spec_from_file_location('_native_mesh_compare',path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module


def validate(mesh,config):
    import unreal as u
    room=config['room'];family=config['family'];row=config['export'];target=config['mesh_target']
    assert mesh.get_path_name().split('.')[0]==target
    filenames=list(map(str,mesh.get_editor_property('asset_import_data').extract_filenames()))
    assert len(filenames)==1 and Path(filenames[0]).resolve()==(ROOT/row['file']).resolve()
    slots=list(mesh.static_materials)
    assert [str(v.get_editor_property('imported_material_slot_name')) for v in slots]==row['materials']
    bindings=[v.get_editor_property('material_interface').get_path_name().split('.')[0] for v in slots]
    assert bindings==[config['palette_target'],'/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02/Materials/M_CP_Mortar_R02']
    sub=u.get_editor_subsystem(u.StaticMeshEditorSubsystem)
    assert sub.get_simple_collision_count(mesh)==sub.get_convex_collision_count(mesh)==0 and sub.get_num_uv_channels(mesh,0)==1
    assert not mesh.get_editor_property('nanite_settings').get_editor_property('enabled')
    assert not mesh.get_editor_property('asset_import_data').get_editor_property('remove_degenerates') and not sub.get_lod_build_settings(mesh,0).get_editor_property('remove_degenerates')
    expected_path=ROOT/config['expected_geometry_file']
    assert sha(expected_path)==config['expected_geometry_sha256']
    expected=json.loads(expected_path.read_text());compare=comparator()
    zero=sum(compare.cross_area_squared(t)==0 for t in expected['triangles'])
    assert zero==config['exact_zero_area_FBX_triangles'] and len(expected['triangles'])==row['triangles']
    expected_count=row['triangles']-zero
    assert mesh.get_num_triangles(0)==expected_count
    counts={};dm=None
    for label,lodtype in [('source',u.GeometryScriptLODType.SOURCE_MODEL),('render',u.GeometryScriptLODType.RENDER_DATA)]:
        lod=u.GeometryScriptMeshReadLOD();lod.lod_type=lodtype;lod.lod_index=0
        candidate=u.DynamicMesh();copied=u.GeometryScript_AssetUtils.copy_mesh_from_static_mesh(mesh,candidate,u.GeometryScriptCopyMeshFromAssetOptions(),lod)
        assert copied[1]==u.GeometryScriptOutcomePins.SUCCESS and candidate.get_triangle_count()==expected_count
        counts[label]=candidate.get_triangle_count()
        if label=='render':dm=candidate
    colours=u.GeometryScript_VertexColors.get_mesh_per_vertex_colors(dm,False);assert colours[2] is True and colours[3] is False
    values=u.GeometryScript_List.convert_color_list_to_array(colours[1])
    actual_colours=sorted(set(tuple(round(c.to_tuple()[k]*255) for k in range(3)) for c in values))
    ranges=json.loads((DOC/'four_room_vertex_range_contract_r01.json').read_text())
    colour_proof,=[r for r in ranges['meshes'] if r['room']==room and r['family']==family and r['kind']=='range_safe_original']
    assert colour_proof['sha256']==row['sha256'] and colour_proof['referenced_corners_outside_native_UNorm_range']==0
    assert actual_colours==[tuple(v) for v in colour_proof['expected_native_RGB_bytes']]
    normals=u.GeometryScript_Normals.get_mesh_per_vertex_normals(dm,False);assert normals[2] is True and normals[3] is False
    nv=u.GeometryScript_List.convert_vector_list_to_array(normals[1]);nrange=[min(v.length() for v in nv),max(v.length() for v in nv)]
    assert .99<nrange[0]<=nrange[1]<1.01
    bounds=mesh.get_bounds();low=[v-e for v,e in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())];high=[v+e for v,e in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())]
    error=max(abs(a-b) for aa,bb in [(low,row['unreal_bounds_min_cm']),(high,row['unreal_bounds_max_cm'])] for a,b in zip(aa,bb));assert error<.001
    triangles=[]
    for i in range(expected_count):
        p=u.GeometryScript_MeshQueries.get_triangle_positions(dm,i);uv=u.GeometryScript_MeshQueries.get_triangle_u_vs(dm,0,i);mat=u.GeometryScript_Materials.get_triangle_material_id(dm,i)
        assert p[0] and uv[3] and mat[1]
        triangles.append(dict(positions=[list(v.to_tuple()) for v in p[1:]],uv=[list(v.to_tuple()) for v in uv[:3]],material=mat[0]))
    native=dict(target=target,fbx_sha256=row['sha256'],triangles=triangles)
    result=compare.compare(expected,native)
    geometry=DOC/('native_geometry_'+room+'_'+family+'_r02.json');proof_path=DOC/('native_correspondence_'+room+'_'+family+'_r02.json')
    for path,data in [(geometry,native),(proof_path,result)]:
        if path.exists():assert json.loads(path.read_text())==data
        else:path.write_text(json.dumps(data,separators=(',',':'))+'\n')
    return dict(source_render_counts=counts,FBX_triangles=row['triangles'],exact_zero_area_FBX_faces=zero,materials=bindings,colour_byte_set_exact=True,colour_count=len(actual_colours),normal_length_range=nrange,bounds_min_cm=low,bounds_max_cm=high,bounds_error_cm=error,UV_channels=1,simple_collision=0,convex_collision=0,nanite=False,render_geometry_file=geometry.relative_to(ROOT).as_posix(),render_geometry_sha256=sha(geometry),correspondence_file=proof_path.relative_to(ROOT).as_posix(),correspondence_sha256=sha(proof_path),maximum_corner_displacement_cm=result['maximum_corner_displacement_cm'])
