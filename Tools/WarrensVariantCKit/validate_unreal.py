"""Independent saved-world audit against pre-art source and fitted manifest."""
import json,math
from collections import defaultdict
from pathlib import Path
import unreal as u
HERE=Path(__file__).resolve().parent
OUT=HERE/'Output'
OWNER='Mars.WarrensVariantCKit.Authoring.v1'
def vec(v):return [v.x,v.y,v.z]
def near(a,b):return len(a)==len(b) and all(abs(x-y)<.003 for x,y in zip(a,b))
def main():
    data=json.loads((OUT/'fitted_instances.json').read_text());baseline=json.loads((OUT/'Reports/full_source_baseline.json').read_text())
    result=dict(status='passed',tiles={},original_actor_checks=0,original_instance_checks=0,owned_instances=0,material_component_checks=0)
    for tile,base in baseline.items():
        world=u.load_asset(base['asset']);actors=[a for a in u.GameplayStatics.get_all_actors_of_class(world,u.Actor) if a.get_path_name().startswith(base['asset']+'.')]
        originals={a.get_actor_label():a for a in actors if OWNER not in [str(t) for t in a.tags]}
        for old in base['actors']:
            if not (old['label'].startswith('Warrens_') or old['components']):continue
            a=originals[old['label']];assert a.get_class().get_name()==old['class'];assert near(vec(a.get_actor_location()),old['at'])
            assert near(vec(a.get_actor_scale3d()),old.get('scale',[1,1,1]))
            result['original_actor_checks']+=1;comps={c.get_name():c for c in a.get_components_by_class(u.StaticMeshComponent)}
            for prior in old['components']:
                c=comps[prior['name']];assert c.static_mesh.get_path_name()==prior['mesh'];assert str(c.get_collision_profile_name())==prior['collision']
                if 'instances' not in prior:continue
                assert c.get_instance_count()==len(prior['instances'])
                for i,p in enumerate(prior['instances']):
                    t=c.get_instance_transform(i,world_space=True);q=u.Rotator(pitch=p['rotation'][0],yaw=p['rotation'][1],roll=p['rotation'][2]).quaternion()
                    assert near(vec(t.translation),p['at']) and near(vec(t.scale3d),p['scale']) and t.rotation.angular_distance(q)<.001,(tile,old['label'],i)
                    result['original_instance_checks']+=1
        groups={}
        for a in actors:
            tags=[str(t) for t in a.tags]
            assert not any(t in ['Mars.ChainCrossingKit.Authoring.v1','Mars.PumpCisternKit.Authoring.v1'] for t in tags),'Duplicate old pass'
            if OWNER not in tags:continue
            for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent):
                ident=a.get_actor_label().removeprefix('WVC_');assert ident not in groups;groups[ident]=c
                assert str(c.get_collision_profile_name())=='NoCollision' and not c.get_editor_property('generate_overlap_events')
                if ident=='CCS61':
                    assert not c.get_editor_property('cast_shadow')
                    assert c.get_material(0).get_path_name().endswith('M_CCK_Glass.M_CCK_Glass')
        expected=defaultdict(list)
        for p in data['placements']:
            if p['tile']==tile:expected[p['id']].append(p)
        assert set(groups)==set(expected),(tile,set(groups)^set(expected))
        for ident,rows in expected.items():
            c=groups[ident];assert c.get_instance_count()==len(rows)
            for i,p in enumerate(rows):
                t=c.get_instance_transform(i,world_space=True);r=p.get('rotation',[0,p.get('yaw',0),0]);q=u.Rotator(pitch=r[0],yaw=r[1],roll=r[2]).quaternion()
                assert near(vec(t.translation),[(p['at'][k]-data['pivots'][tile][k])*100 for k in range(3)]) and near(vec(t.scale3d),p['scale']) and t.rotation.angular_distance(q)<.001,(tile,ident,i)
            result['owned_instances']+=len(rows)
        ledger=json.loads((OUT/'Reports'/('dressed_'+tile+'.json')).read_text())
        for binding in ledger.get('gate_bindings',[]):
            script=originals[binding['actor']].get_editor_property('_EntityScript')
            assert script.get_editor_property(binding['property']).get_path_name()==binding['material']
        for m in ledger['material_overrides']:
            c=next(c for c in originals[m['actor']].get_components_by_class(u.StaticMeshComponent) if c.get_name()==m['component'])
            assert all(mat.get_path_name()==m['material'] for mat in c.get_materials());result['material_component_checks']+=1
        for v in {(v['tile'],v['label']):v for v in data['visibility_overrides']}.values():
            if v['tile']==tile:assert all(c.is_visible()==v['visible'] for c in originals[v['label']].get_components_by_class(u.StaticMeshComponent))
        result['tiles'][tile]=dict(instances=sum(len(r) for r in expected.values()),hism_groups=len(groups))
    assert result['original_instance_checks']==data['source_instance_count']==7481
    assert result['owned_instances']==len(data['placements'])
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
    (OUT/'Reports/unreal_level_validation.json').write_text(json.dumps(result,indent=2));print('VARIANT_C_SAVED_AUDIT_PASSED',result['original_actor_checks'],result['original_instance_checks'],result['owned_instances']);return result
if __name__=='__main__':main()
