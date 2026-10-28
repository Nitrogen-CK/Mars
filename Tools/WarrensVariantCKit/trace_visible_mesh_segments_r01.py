"""Read-only visible static render-LOD segments, including NoCollision instances."""
import hashlib,importlib.util
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def trace(world,rays,only_shadow_casters=False):
    import unreal as u
    assert world==u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() and u.GameplayStatics.is_game_paused(world)
    sp=importlib.util.spec_from_file_location('_visible_ray_box',Path(__file__).with_name('larder_render_attribution_r01.py'));math=importlib.util.module_from_spec(sp);sp.loader.exec_module(math)
    w=world;cache={};component_candidates=0;instance_candidates=0
    for actor in u.GameplayStatics.get_all_actors_of_class(w,u.Actor):
        if actor.get_editor_property('hidden'):continue
        for c in actor.get_components_by_class(u.StaticMeshComponent):
            mesh=c.static_mesh
            if not mesh or not c.is_visible() or c.get_editor_property('hidden_in_game') or (only_shadow_casters and not c.cast_shadow):continue
            centre,extent,radius=u.SystemLibrary.get_component_bounds(c);lo=[a-b for a,b in zip(centre.to_tuple(),extent.to_tuple())];hi=[a+b for a,b in zip(centre.to_tuple(),extent.to_tuple())]
            relevant=[r for r in rays if math.box_hit(r['origin'],r['target'],lo,hi) is not None]
            if not relevant:continue
            component_candidates+=1;bounds=mesh.get_bounds();lo=[a-b for a,b in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())];hi=[a+b for a,b in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())]
            transforms=[(i,c.get_instance_transform(i,world_space=True)) for i in range(c.get_instance_count())] if isinstance(c,u.InstancedStaticMeshComponent) else [(None,c.get_world_transform())]
            for index,transform in transforms:
                for ray in relevant:
                    start=transform.inverse_transform_location(u.Vector(*ray['origin']));end=transform.inverse_transform_location(u.Vector(*ray['target']))
                    if math.box_hit(list(start.to_tuple()),list(end.to_tuple()),lo,hi) is None:continue
                    instance_candidates+=1;key=mesh.get_path_name()
                    if key not in cache:
                        dm=u.DynamicMesh();lod=u.GeometryScriptMeshReadLOD();lod.set_editor_property('lod_type',u.GeometryScriptLODType.RENDER_DATA);lod.set_editor_property('lod_index',0);copy=u.GeometryScript_AssetUtils.copy_mesh_from_static_mesh(mesh,dm,u.GeometryScriptCopyMeshFromAssetOptions(),lod);assert copy[1]==u.GeometryScriptOutcomePins.SUCCESS
                        built=u.GeometryScript_MeshSpatial.build_bvh_for_mesh(dm);assert u.GeometryScript_MeshSpatial.is_bvh_valid_for_mesh(dm,built[1])[1];cache[key]=(dm,built[1])
                    dm,bvh=cache[key];direction=end-start;length=direction.length();assert length>0;opts=u.GeometryScriptSpatialQueryOptions();opts.set_editor_property('max_distance',length);opts.set_editor_property('allow_unsafe_modified_queries',False)
                    hit=u.GeometryScript_MeshSpatial.find_nearest_ray_intersection_with_mesh(dm,bvh,start,direction*(1/length),opts)[1]
                    if not hit.hit:continue
                    at=transform.transform_location(hit.hit_position);origin=u.Vector(*ray['origin']);delta=u.Vector(*ray['target'])-origin;fraction=(at-origin).dot(delta)/delta.dot(delta);assert -.000001<=fraction<=1.000001
                    materials=[]
                    for mat in c.get_materials():
                        parent=mat
                        while isinstance(parent,u.MaterialInstanceConstant):parent=parent.get_editor_property('parent')
                        materials.append(dict(path=mat.get_path_name() if mat else None,blend=str(parent.get_editor_property('blend_mode')) if isinstance(parent,u.Material) else None))
                    ray['hits'].append(dict(fraction=fraction,distance_cm=(at-origin).length(),actor=actor.get_path_name(),label=actor.get_actor_label(),component=c.get_path_name(),instance=index,mesh=key,triangle=hit.hit_triangle_id,world_hit=list(at.to_tuple()),materials=materials,collision=str(c.get_collision_enabled()),cast_shadow=c.cast_shadow,plan_hit=[at.x/100+70,at.y/100+55,at.z/100]))
    for r in rays:r['hits'].sort(key=lambda v:v['fraction'])
    return dict(world=w.get_path_name(),rays=rays,component_candidates=component_candidates,instance_ray_candidates=instance_candidates,mesh_bvhs=len(cache),only_shadow_casters=only_shadow_casters,tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
