"""Read-only tile snapshot and timestamped on-disk rollback copy. Execute in UE Python."""
import hashlib
import json
import shutil
from datetime import datetime
from pathlib import Path
import unreal as u

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'Tools/ChainCrossingKit/Output/Reports'
TILES=['WaterworksW','Canal','Brineworks']

def vector(v):return [v.x,v.y,v.z]

def main():
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages(),'Unsaved map changes: refusing snapshot/switch'
    data={}
    backup=OUT/'Backups'/datetime.now().strftime('%Y%m%d-%H%M%S');backup.mkdir(parents=True,exist_ok=True)
    for tile in TILES:
        asset='/Game/Mars/Maps/Variants/v8c/LI_Warrens_'+tile
        world=u.load_asset(asset);rows=[]
        for a in u.GameplayStatics.get_all_actors_of_class(world,u.Actor):
            row={'label':a.get_actor_label(),'class':a.get_class().get_name(),'at':vector(a.get_actor_location()),'components':[]}
            for c in a.get_components_by_class(u.StaticMeshComponent):
                mesh=c.static_mesh
                cr={'name':c.get_name(),'mesh':mesh.get_path_name() if mesh else None,'collision':str(c.get_collision_profile_name()),'materials':[m.get_path_name() if m else None for m in c.get_materials()]}
                if isinstance(c,u.InstancedStaticMeshComponent):
                    cr['instances']=[]
                    for i in range(c.get_instance_count()):
                        t=c.get_instance_transform(i,world_space=True);r=t.rotation.rotator()
                        cr['instances'].append({'at':vector(t.translation),'scale':vector(t.scale3d),'rotation':[r.pitch,r.yaw,r.roll]})
                row['components'].append(cr)
            rows.append(row)
        disk=ROOT/'Content/Mars/Maps/Variants/v8c'/('LI_Warrens_'+tile+'.umap')
        assert disk.is_file(),disk
        shutil.copy2(disk,backup/disk.name)
        data[tile]={'asset':asset,'disk':str(disk),'sha256':hashlib.sha256(disk.read_bytes()).hexdigest(),'backup':str(backup/disk.name),'actors':rows}
    (OUT/'level_baseline.json').write_text(json.dumps(data,indent=2))
    print('SNAPSHOT',[(k,len(v['actors'])) for k,v in data.items()],str(backup))

if __name__=='__main__':main()
