"""Full-level read-only source inventory and pre-campaign binary checkpoint.

Run outside PIE. Earlier undressed source snapshots win for the four already
authored tiles; fresh current snapshots record source state for the other seven.
Never replaces an existing production baseline or any map file.
"""
import gc,hashlib,json,shutil
from datetime import datetime
from pathlib import Path
import unreal as u
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OUT=HERE/'Output/Reports'
OWNERS={'Mars.ChainCrossingKit.Authoring.v1','Mars.PumpCisternKit.Authoring.v1','Mars.WarrensVariantCKit.Authoring.v1'}
def vec(v):return [v.x,v.y,v.z]
def main():
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
    assert not u.EditorLoadingAndSavingUtils.get_dirty_content_packages()
    assert not u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    OUT.mkdir(parents=True,exist_ok=True)
    baseline_path=OUT/'source_baseline.json'
    assert not baseline_path.exists(),'Production baseline already exists; never overwrite it'
    checkpoint=OUT/'Backups'/datetime.now().strftime('%Y%m%d-%H%M%S');checkpoint.mkdir(parents=True,exist_ok=False)
    data=json.loads((ROOT/'Tools/LevelDesign/anchor_plans/data/warrens_v8c.json').read_text())
    current={};backups={}
    for tile in data['instances']:
        key=tile['asset'].replace('LI_Warrens_','');asset='/Game/Mars/Maps/Variants/v8c/'+tile['asset']
        disk=ROOT/'Content/Mars/Maps/Variants/v8c'/(tile['asset']+'.umap')
        assert disk.is_file()
        shutil.copy2(disk,checkpoint/disk.name)
        backups[key]=dict(asset=asset,disk=str(disk),sha256=hashlib.sha256(disk.read_bytes()).hexdigest(),backup=str(checkpoint/disk.name))
        world=u.load_asset(asset);rows=[]
        for a in u.GameplayStatics.get_all_actors_of_class(world,u.Actor):
            if any(str(tag) in OWNERS for tag in a.tags):continue
            r=a.get_actor_rotation()
            row=dict(label=a.get_actor_label(),class_name=a.get_class().get_name(),at=vec(a.get_actor_location()),rotation=[r.pitch,r.yaw,r.roll],scale=vec(a.get_actor_scale3d()),hidden=bool(a.hidden),components=[])
            row['class']=row.pop('class_name')
            for c in a.get_components_by_class(u.StaticMeshComponent):
                cr=dict(name=c.get_name(),mesh=c.static_mesh.get_path_name() if c.static_mesh else None,collision=str(c.get_collision_profile_name()),materials=[m.get_path_name() if m else None for m in c.get_materials()],visible=c.is_visible())
                if isinstance(c,u.InstancedStaticMeshComponent):
                    cr['instances']=[]
                    for i in range(c.get_instance_count()):
                        t=c.get_instance_transform(i,world_space=True);r=t.rotation.rotator()
                        cr['instances'].append(dict(at=vec(t.translation),scale=vec(t.scale3d),rotation=[r.pitch,r.yaw,r.roll]))
                row['components'].append(cr)
            if isinstance(a,u.PointLight):
                c=a.point_light_component;row['light']=dict(intensity=c.intensity,attenuation_radius=c.attenuation_radius,color=str(c.light_color))
            rows.append(row)
        current[key]={**backups[key], 'pivot':[tile['rect'][0],tile['rect'][1],tile['z']], 'actors':rows}
    baseline=dict(current)
    for path in [ROOT/'Tools/ChainCrossingKit/Output/Reports/level_baseline.json',ROOT/'Tools/PumpCisternKit/Output/Reports/level_baseline.json']:
        for key,original in json.loads(path.read_text()).items():
            baseline[key]={**original,'pivot':current[key]['pivot']}
    (OUT/'checkpoint.json').write_text(json.dumps(backups,indent=2))
    (OUT/'current_source_snapshot.json').write_text(json.dumps(current,indent=2))
    baseline_path.write_text(json.dumps(baseline,indent=2))
    count=sum(len(c.get('instances',[])) for v in baseline.values() for a in v['actors'] for c in a['components'])
    print('VARIANT_C_SOURCE_CHECKPOINT',len(baseline),count,str(checkpoint))
    return dict(tiles=len(baseline),source_instances=count,checkpoint=str(checkpoint))
if __name__=='__main__':main()
