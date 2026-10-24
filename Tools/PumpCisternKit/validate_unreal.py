"""Compare all four saved source worlds and both owned passes to manifests."""
import json,importlib.util
from pathlib import Path
import unreal as u
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
SHARED=HERE.parent/'ChainCrossingKit'
OWNERS={'Mars.ChainCrossingKit.Authoring.v1':SHARED,'Mars.PumpCisternKit.Authoring.v1':HERE}

def near(a,b):return len(a)==len(b) and all(abs(x-y)<.003 for x,y in zip(a,b))
def vec(v):return [v.x,v.y,v.z]
def main():
    baseline=json.loads((SHARED/'Output/Reports/level_baseline.json').read_text())
    baseline.update(json.loads((HERE/'Output/Reports/level_baseline.json').read_text()))
    report=dict(status='passed',tiles={},original_actor_checks=0,original_instance_checks=0,new_instances=0,owners={})
    for tile,base in baseline.items():
        world=u.load_asset(base['asset']);actors=u.GameplayStatics.get_all_actors_of_class(world,u.Actor)
        original={a.get_actor_label():a for a in actors if not any(str(t) in OWNERS for t in a.tags)}
        for old in base['actors']:
            if not (old['label'].startswith('Warrens_') or old['components']):continue
            a=original[old['label']];assert a.get_class().get_name()==old['class']
            assert near(vec(a.get_actor_location()),old['at']),(tile,old['label'],'actor moved')
            report['original_actor_checks']+=1
            comps={c.get_name():c for c in a.get_components_by_class(u.StaticMeshComponent)}
            for cr in old['components']:
                c=comps[cr['name']];assert c.static_mesh.get_path_name()==cr['mesh']
                assert str(c.get_collision_profile_name())==cr['collision']
                if 'instances' not in cr:continue
                assert c.get_instance_count()==len(cr['instances'])
                for i,prior in enumerate(cr['instances']):
                    t=c.get_instance_transform(i,world_space=True);r=t.rotation.rotator()
                    assert near(vec(t.translation),prior['at']) and near(vec(t.scale3d),prior['scale']),(tile,old['label'],i)
                    assert near([r.pitch,r.yaw,r.roll],prior['rotation'])
                    report['original_instance_checks']+=1
        tile_counts={}
        for owner,folder in OWNERS.items():
            data=json.loads((folder/'Output/fitted_instances.json').read_text())
            expected=[p for p in data['placements'] if p['tile']==tile]
            groups={}
            for a in actors:
                if owner not in [str(t) for t in a.tags]:continue
                for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent):
                    ident=a.get_actor_label().split('_',1)[1]
                    assert ident not in groups,(tile,owner,ident)
                    assert str(c.get_collision_profile_name())=='NoCollision'
                    mesh=c.static_mesh.get_path_name()
                    assert mesh.startswith('/Game/Mars/Environment/ChainCrossingKit/Meshes/') or mesh.startswith('/Game/Mars/Environment/PumpCisternKit/Meshes/') or (ident.startswith('BACKING_') or ident=='SOURCE_GALLERY') and mesh=='/Engine/BasicShapes/Cube.Cube'
                    groups[ident]=c
            assert sum(c.get_instance_count() for c in groups.values())==len(expected),(tile,owner,'count')
            pivot=data['pivots'].get(tile,[0,0,0])
            for ident,c in groups.items():
                rows=[p for p in expected if p['id']==ident];assert c.get_instance_count()==len(rows)
                for i,p in enumerate(rows):
                    t=c.get_instance_transform(i,world_space=True);r=t.rotation.rotator()
                    assert near(vec(t.translation),[(p['at'][k]-pivot[k])*100 for k in range(3)]),(tile,ident,i,'at')
                    assert near(vec(t.scale3d),p['scale']),(tile,ident,i,'scale')
                    # Rotators have equivalent Euler representations; compare directions through quaternion angular distance.
                    rot=p.get('rotation',[0,p.get('yaw',0),0]);q=u.Rotator(pitch=rot[0],yaw=rot[1],roll=rot[2]).quaternion()
                    assert t.rotation.angular_distance(q)<.001,(tile,ident,i,'rotation')
            tile_counts[owner]=dict(instances=len(expected),hism_groups=len(groups))
            report['owners'][owner]=report['owners'].get(owner,0)+len(expected)
        report['tiles'][tile]=tile_counts
    for owner,folder in OWNERS.items():assert report['owners'][owner]==len(json.loads((folder/'Output/fitted_instances.json').read_text())['placements'])
    report['new_instances']=sum(report['owners'].values())
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
    (HERE/'Output/Reports/unreal_level_validation.json').write_text(json.dumps(report,indent=2))
    print('WATERWORKS_SAVED_AUDIT_PASSED',report['original_actor_checks'],report['original_instance_checks'],report['new_instances'])
    return report
if __name__=='__main__':main()
