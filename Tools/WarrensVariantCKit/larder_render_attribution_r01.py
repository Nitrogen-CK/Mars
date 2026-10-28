"""Read-only rendered-triangle centre-ray attribution, independent of collision.

Uses the prior actual camera pose in a fresh naturally resolved PIE. A fresh
random forage draw can differ: component hits are not silently equated with
the historical image. No actors, materials, lights or source files are edited.
"""
import hashlib,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/LarderRollout'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def box_hit(origin,target,lo,hi):
    near,far=0.,1.
    for i in range(3):
        d=target[i]-origin[i]
        if abs(d)<1e-10:
            if not lo[i]<=origin[i]<=hi[i]:return None
        else:
            a,b=sorted(((lo[i]-origin[i])/d,(hi[i]-origin[i])/d));near=max(near,a);far=min(far,b)
            if near>far:return None
    return near


def triangle_hit(origin,direction,a,b,c):
    e1,e2=b-a,c-a;p=direction.cross(e2);det=e1.dot(p)
    if abs(det)<1e-10:return None
    inv=1/det;tvec=origin-a;u=tvec.dot(p)*inv
    if u<0 or u>1:return None
    q=tvec.cross(e1);v=direction.dot(q)*inv
    if v<0 or u+v>1:return None
    t=e2.dot(q)*inv
    return t if 0<=t<=1 else None


def probe(view):
    import unreal as u
    assert view in ('storage','ceiling','wall_grazing','barrel')
    assert Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve()
    w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world();assert w and w.get_path_name()=='/Game/Mars/Maps/UEDPIE_0_Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    record=json.loads((DOC/'native-surface-r01'/(view+'_A_source.json')).read_text());origin=u.Vector(*record['camera']);forward=u.MathLibrary.get_forward_vector(u.Rotator(**record['rotation']));target=origin+forward*10000;mesh_cache={};hits=[];candidates=0
    for actor in u.GameplayStatics.get_all_actors_of_class(w,u.Actor):
        if actor.get_editor_property('hidden'):continue
        for comp in actor.get_components_by_class(u.StaticMeshComponent):
            mesh=comp.static_mesh
            if not mesh or not comp.is_visible() or comp.get_editor_property('hidden_in_game'):continue
            transforms=[(i,comp.get_instance_transform(i,world_space=True)) for i in range(comp.get_instance_count())] if isinstance(comp,u.InstancedStaticMeshComponent) else [(None,comp.get_world_transform())]
            bounds=mesh.get_bounds();lo=[v-e for v,e in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())];hi=[v+e for v,e in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())]
            for index,transform in transforms:
                start=transform.inverse_transform_location(origin);end=transform.inverse_transform_location(target)
                if box_hit(list(start.to_tuple()),list(end.to_tuple()),lo,hi) is None:continue
                candidates+=1;key=mesh.get_path_name()
                if key not in mesh_cache:
                    dm=u.DynamicMesh();lod=u.GeometryScriptMeshReadLOD();lod.set_editor_property('lod_type',u.GeometryScriptLODType.RENDER_DATA);lod.set_editor_property('lod_index',0);copied=u.GeometryScript_AssetUtils.copy_mesh_from_static_mesh(mesh,dm,u.GeometryScriptCopyMeshFromAssetOptions(),lod);assert copied[1]==u.GeometryScriptOutcomePins.SUCCESS
                    mesh_cache[key]=[u.GeometryScript_MeshQueries.get_triangle_positions(dm,i)[1:] for i in range(dm.get_triangle_count())]
                direction=end-start;nearest=None;triangle=None
                for ti,(a,b,c) in enumerate(mesh_cache[key]):
                    t=triangle_hit(start,direction,a,b,c)
                    if t is not None and (nearest is None or t<nearest):nearest=t;triangle=ti
                if nearest is not None:
                    hit=origin+(target-origin)*nearest;hits.append(dict(distance_cm=nearest*10000,actor=actor.get_path_name(),actor_class=actor.get_class().get_path_name(),label=actor.get_actor_label(),component=comp.get_path_name(),component_class=comp.get_class().get_path_name(),mesh=key,instance=index,triangle=triangle,world_hit=list(hit.to_tuple()),plan_hit=[hit.x/100+70,hit.y/100+55,hit.z/100],component_world_pose=dict(at=list(comp.get_world_location().to_tuple()),scale=list(comp.get_world_scale().to_tuple())),instance_world_pose=dict(at=list(transform.translation.to_tuple()),scale=list(transform.scale3d.to_tuple()),q=[transform.rotation.x,transform.rotation.y,transform.rotation.z,transform.rotation.w]),materials=[m.get_path_name() if m else None for m in comp.get_materials()],collision=str(comp.get_collision_enabled()),profile=str(comp.get_collision_profile_name())))
    result=dict(status='FRESH_NATIVE_RENDER_TRIANGLE_CENTRE_RAY_ATTRIBUTION_READ_ONLY',world=w.get_path_name(),historical_camera_record_sha256=sha(DOC/'native-surface-r01'/(view+'_A_source.json')),view=view,camera=record['camera'],rotation=record['rotation'],render_mesh_candidates=candidates,hits=sorted(hits,key=lambda r:r['distance_cm']),tool_sha256=sha(__file__),boundary='Centre pixel ray is independent of aspect/FOV and tests actual rendered StaticMesh triangles, including SMC/ISM/HISM and collision-disabled geometry. Fresh natural unpinned run: runtime draw identity can differ from the earlier still. No correspondence claim for a different random object until a new capture/readback matches it. No source or scene mutations.')
    p=RUN/(view+'_render_triangle_attribution_r01.json');assert not p.exists();p.write_text(json.dumps(result,indent=2)+'\n');print('RENDER_TRIANGLE_ATTRIBUTION',view,[(round(v['distance_cm'],2),v['label'],v['component_class'],v['mesh'].split('/')[-1],v['instance'],v['plan_hit'],v['materials']) for v in result['hits'][:4]])
    return result
