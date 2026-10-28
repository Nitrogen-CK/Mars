"""Read-only exact triangle rays from an existing practical to its wall.

Geometry witness only; masked/translucent material shadowing is labelled and
not assumed from a triangle hit. Does not toggle any shadow or light state.
"""
import hashlib,importlib.util,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/LarderRollout'


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def probe():
    import unreal as u
    assert Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve()
    editor=u.get_editor_subsystem(u.UnrealEditorSubsystem);assert editor.get_game_world() is None;w=editor.get_editor_world();assert w.get_path_name()=='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    hp=Path(__file__).with_name('larder_render_attribution_r01.py');sp=importlib.util.spec_from_file_location('_fixture_ray_math',hp);math=importlib.util.module_from_spec(sp);sp.loader.exec_module(math)
    lights=[c for a in u.GameplayStatics.get_all_actors_of_class(w,u.Actor) if a.get_actor_label()=='WVC_Practical_59' for c in a.get_components_by_class(u.PointLightComponent)];light,=lights;origin=light.get_world_location();targets=dict(upper=u.Vector(3900,-1250,30),lower=u.Vector(3900,-1250,-220),centre=u.Vector(3900,-1250,-80));cache={};rays=[]
    for name,target in targets.items():
        hits=[]
        for actor in u.GameplayStatics.get_all_actors_of_class(w,u.Actor):
            if actor.get_editor_property('hidden'):continue
            for c in actor.get_components_by_class(u.StaticMeshComponent):
                mesh=c.static_mesh
                if not mesh or not c.is_visible() or c.get_editor_property('hidden_in_game') or not c.cast_shadow:continue
                transforms=[(i,c.get_instance_transform(i,world_space=True)) for i in range(c.get_instance_count())] if isinstance(c,u.InstancedStaticMeshComponent) else [(None,c.get_world_transform())]
                bounds=mesh.get_bounds();lo=[v-e for v,e in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())];hi=[v+e for v,e in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())]
                for index,tf in transforms:
                    a=tf.inverse_transform_location(origin);b=tf.inverse_transform_location(target)
                    if math.box_hit(list(a.to_tuple()),list(b.to_tuple()),lo,hi) is None:continue
                    key=mesh.get_path_name()
                    if key not in cache:
                        dm=u.DynamicMesh();lod=u.GeometryScriptMeshReadLOD();lod.set_editor_property('lod_type',u.GeometryScriptLODType.RENDER_DATA);lod.set_editor_property('lod_index',0);copy=u.GeometryScript_AssetUtils.copy_mesh_from_static_mesh(mesh,dm,u.GeometryScriptCopyMeshFromAssetOptions(),lod);assert copy[1]==u.GeometryScriptOutcomePins.SUCCESS;cache[key]=[u.GeometryScript_MeshQueries.get_triangle_positions(dm,i)[1:] for i in range(dm.get_triangle_count())]
                    nearest=None;triangle=None
                    for ti,(x,y,z) in enumerate(cache[key]):
                        t=math.triangle_hit(a,b-a,x,y,z)
                        if t is not None and (nearest is None or t<nearest):nearest=t;triangle=ti
                    if nearest is not None:
                        mats=[]
                        for mat in c.get_materials():
                            parent=mat
                            while isinstance(parent,u.MaterialInstanceConstant):parent=parent.get_editor_property('parent')
                            mats.append(dict(path=mat.get_path_name() if mat else None,base=parent.get_path_name() if parent else None,blend=str(parent.get_editor_property('blend_mode')) if isinstance(parent,u.Material) else None))
                        hits.append(dict(fraction=nearest,actor=actor.get_path_name(),label=actor.get_actor_label(),component=c.get_path_name(),instance=index,mesh=key,triangle=triangle,world_hit=list((origin+(target-origin)*nearest).to_tuple()),materials=mats,casts_shadow=c.cast_shadow))
        rays.append(dict(label=name,origin=list(origin.to_tuple()),wall_target=list(target.to_tuple()),hits=sorted(hits,key=lambda h:h['fraction'])))
    result=dict(status='READ_ONLY_SOURCE_PRACTICAL_SHADOW_CASTER_TRIANGLE_WITNESS',light=light.get_path_name(),intensity=light.intensity,source_radius=light.source_radius,cast_shadows=light.cast_shadows,rays=rays,tool_sha256=sha(__file__),ray_math_sha256=sha(hp),boundary='Exact visible shadow-casting mesh triangles in current editor source scene; no lights/materials/actors changed. Opaque cap hits identify geometric occluders; masked opacity and real shadow-map pixels require the separate reversible native shadow diagnostic. No assertion that every ray triangle casts an opaque pixel.')
    p=RUN/'fixture59_shadow_caster_rays_r01.json';assert not p.exists();p.write_text(json.dumps(result,indent=2)+'\n');print('PRACTICAL_OCCLUDER_RAYS',[(r['label'],[(v['label'],v['instance'],v['world_hit'],v['materials']) for v in r['hits'][:2]]) for r in rays])


if __name__=='__main__':probe()
