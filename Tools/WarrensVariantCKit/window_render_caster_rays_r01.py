"""Read-only actual render-LOD caster rays using GeometryScript CPU BVHs.

Includes visible NoCollision decoration, the new veneers, and original SMC /
ISM / HISM casters. Geometry hits are not claims about opacity or VSM pixels.
"""
import hashlib,importlib.util,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/LarderRollout'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def probe(controller):
    import unreal as u
    controller.check();s=controller.STATE;w=s['world'];assert u.GameplayStatics.is_game_paused(w)
    sp=importlib.util.spec_from_file_location('_render_ray_box',Path(__file__).with_name('larder_render_attribution_r01.py'));math=importlib.util.module_from_spec(sp);sp.loader.exec_module(math)
    light=s['light'];tf=light.get_world_transform();origins=[('centre',light.get_world_location())]+[(f'corner_{y}_{z}',tf.transform_location(u.Vector(0,y*light.source_width/2,z*light.source_height/2))) for y in (-1,1) for z in (-1,1)]
    targets=[('east_mid',u.Vector(6200,-1500,300)),('east_high',u.Vector(6200,-1500,800))];rays=[dict(label=a+'_'+b,origin=list(origin.to_tuple()),target=list(target.to_tuple()),hits=[]) for a,origin in origins for b,target in targets]
    rays.append(dict(label='centre_bank',origin=list(light.get_world_location().to_tuple()),target=[5000,-500,0],hits=[]));cache={};component_candidates=0;instance_candidates=0
    for actor in u.GameplayStatics.get_all_actors_of_class(w,u.Actor):
        if actor.get_editor_property('hidden'):continue
        for c in actor.get_components_by_class(u.StaticMeshComponent):
            mesh=c.static_mesh
            if not mesh or not c.is_visible() or c.get_editor_property('hidden_in_game') or not c.cast_shadow:continue
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
                    ray['hits'].append(dict(fraction=fraction,distance_cm=(at-origin).length(),actor=actor.get_path_name(),label=actor.get_actor_label(),component=c.get_path_name(),instance=index,mesh=key,triangle=hit.hit_triangle_id,world_hit=list(at.to_tuple()),materials=materials,collision=str(c.get_collision_enabled())))
    for r in rays:r['hits'].sort(key=lambda v:v['fraction'])
    controller.check();record=dict(status='READ_ONLY_CURRENT_PAUSED_RENDER_LOD_CASTER_BVH_SEGMENTS',world=w.get_path_name(),actual_light=controller.own_light(),rays=rays,component_candidates=component_candidates,instance_ray_candidates=instance_candidates,actual_mesh_bvhs=len(cache),tool_sha256=sha(__file__),box_helper_sha256=sha(Path(math.__file__)),boundary='Actual current visible shadow-casting render-LOD geometry, including NoCollision skins and new wall mesh. All11 finite segment rays use native BVHs, current SMC/ISM/HISM transforms and nearest triangle per component instance. CPU geometry does not evaluate material WPO/opacity, pixel LOD, normal bias or VSM stochastic sampling. Geometric near-occluders must be classified separately from actual shadow pixels; absence does not prove a renderer root cause. No actor, material, light or source changes.')
    p=RUN/'window_light_render_caster_rays_r01.json';assert not p.exists();p.write_text(json.dumps(record,indent=2)+'\n');print('ACTUAL_RENDER_CASTER_RAYS',[(r['label'],[(round(h['distance_cm'],2),h['label'],h['instance']) for h in r['hits'][:3]]) for r in rays])
