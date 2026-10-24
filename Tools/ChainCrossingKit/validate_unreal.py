"""Audit saved district worlds against pre-write transforms/collision, outside PIE."""
import gc
import json
from pathlib import Path
import unreal as u

HERE=Path(__file__).resolve().parent
OUT=HERE/'Output'
OWNER='Mars.ChainCrossingKit.Authoring.v1'

def vec(v):return [v.x,v.y,v.z]
def near(a,b):return len(a)==len(b) and all(abs(x-y)<.002 for x,y in zip(a,b))

def main():
    baseline=json.loads((OUT/'Reports/level_baseline.json').read_text())
    report={'status':'passed','tiles':{},'original_actor_checks':0,'original_instance_checks':0,'new_instances':0}
    for tile,base in baseline.items():
        world=u.load_asset(base['asset'])
        actors=u.GameplayStatics.get_all_actors_of_class(world,u.Actor)
        original={a.get_actor_label():a for a in actors if OWNER not in [str(t) for t in a.tags]}
        original_rows=[a for a in base['actors'] if a['label'].startswith('Warrens_') or a['components']]
        for old in original_rows:
            assert old['label'] in original,(tile,old['label'])
            a=original[old['label']];assert a.get_class().get_name()==old['class']
            assert near(vec(a.get_actor_location()),old['at']),(tile,old['label'],'moved')
            report['original_actor_checks']+=1
            components={c.get_name():c for c in a.get_components_by_class(u.StaticMeshComponent)}
            for cr in old['components']:
                c=components[cr['name']]
                assert c.static_mesh.get_path_name()==cr['mesh'],(tile,old['label'],'mesh changed')
                assert str(c.get_collision_profile_name())==cr['collision'],(tile,old['label'],'collision changed')
                if 'instances' not in cr:continue
                assert c.get_instance_count()==len(cr['instances'])
                for i,old_instance in enumerate(cr['instances']):
                    t=c.get_instance_transform(i,world_space=True);r=t.rotation.rotator()
                    assert near(vec(t.translation),old_instance['at']) and near(vec(t.scale3d),old_instance['scale'])
                    assert near([r.pitch,r.yaw,r.roll],old_instance['rotation'])
                    report['original_instance_checks']+=1
        hisms=[c for a in actors if OWNER in [str(t) for t in a.tags] for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)]
        for c in hisms:
            assert str(c.get_collision_profile_name())=='NoCollision'
            assert c.static_mesh.get_path_name().startswith('/Game/Mars/Environment/ChainCrossingKit/Meshes/')
        count=sum(c.get_instance_count() for c in hisms)
        expected=json.loads((OUT/'Reports'/('dressed_'+tile+'.json')).read_text())
        assert count==expected['instances'] and len(hisms)==expected['unique_meshes']
        report['tiles'][tile]={'original_actors':len(original_rows),'hism_components':len(hisms),'instances':count,'original_transforms_and_collision_unchanged':True}
        report['new_instances']+=count
    assert report['new_instances']==len(json.loads((OUT/'fitted_instances.json').read_text())['placements'])
    report['dirty_maps']=[p.get_path_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_map_packages()]
    assert not report['dirty_maps'],report['dirty_maps']
    (OUT/'Reports/unreal_level_validation.json').write_text(json.dumps(report,indent=2))
    print('SAVED_UNREAL_LEVEL_AUDIT_PASSED',report['original_actor_checks'],report['original_instance_checks'],report['new_instances'])
    return report

if __name__=='__main__':main()
