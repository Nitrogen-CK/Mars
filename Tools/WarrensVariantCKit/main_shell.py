"""Checkpoint, quiet source surround materials, and audit persistent main world.

The tiled build retains global rock/floor fillers in the persistent world.
These524 instances are original source, not an additional district or new route.
"""
import hashlib,json,shutil
from pathlib import Path
from datetime import datetime
import unreal as u
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OUT=HERE/'Output/Reports'
MAIN='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP'
def vec(v):return list(v.to_tuple())
def snapshot():
    ed=u.get_editor_subsystem(u.UnrealEditorSubsystem);assert ed.get_editor_world().get_path_name().split('.')[0]==MAIN
    assert not ed.get_game_world() and not u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
    rows=[]
    for a in u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors():
        if not (a.get_actor_label().startswith('Warrens_')):continue
        r=a.get_actor_rotation();row=dict(label=a.get_actor_label(),class_name=a.get_class().get_name(),at=vec(a.get_actor_location()),scale=vec(a.get_actor_scale3d()),rotation=[r.pitch,r.yaw,r.roll],components=[])
        for c in a.get_components_by_class(u.StaticMeshComponent):
            item=dict(name=c.get_name(),mesh=c.static_mesh.get_path_name(),collision=str(c.get_collision_profile_name()),materials=[m.get_path_name() if m else None for m in c.get_materials()])
            if isinstance(c,u.InstancedStaticMeshComponent):
                item['instances']=[]
                for i in range(c.get_instance_count()):
                    t=c.get_instance_transform(i,world_space=True);r=t.rotation.rotator();item['instances'].append(dict(at=vec(t.translation),scale=vec(t.scale3d),rotation=[r.pitch,r.yaw,r.roll]))
            row['components'].append(item)
        rows.append(row)
    return dict(asset=MAIN,actors=rows)
def checkpoint():
    path=OUT/'main_source_baseline.json';assert not path.exists()
    data=snapshot();disk=ROOT/'Content/Mars/Maps/Warrens_VariantC_Mars_MAP.umap';backup=OUT/'Backups'/('Main-'+datetime.now().strftime('%Y%m%d-%H%M%S'));backup.mkdir(parents=True,exist_ok=False);shutil.copy2(disk,backup/disk.name)
    data.update(backup=str(backup/disk.name),sha256=hashlib.sha256(disk.read_bytes()).hexdigest());path.write_text(json.dumps(data,indent=2));print('PERSISTENT_SOURCE_CHECKPOINT',sum(len(c.get('instances',[])) for a in data['actors'] for c in a['components']))
def apply():
    assert (OUT/'main_source_baseline.json').is_file();snapshot()
    keys={'Warrens_Greybox_floor':'TX02','Warrens_Greybox_wall':'TX17','Warrens_Greybox_ramp':'TX02'};ledger=[]
    for a in u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors():
        if a.get_actor_label() not in keys:continue
        mat=u.load_asset('/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_'+keys[a.get_actor_label()]);assert mat
        for c in a.get_components_by_class(u.StaticMeshComponent):c.set_material(0,mat);ledger.append(dict(actor=a.get_actor_label(),component=c.get_name(),material=mat.get_path_name()))
    assert u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level();(OUT/'main_material_ledger.json').write_text(json.dumps(ledger,indent=2));print('PERSISTENT_SURROUND_MATERIALS_APPLIED',len(ledger))
def audit():
    old=json.loads((OUT/'main_source_baseline.json').read_text());now=snapshot();a={r['label']:r for r in now['actors']};n=0
    for prior in old['actors']:
        live=a[prior['label']];assert live['class_name']==prior['class_name']
        for key in ['at','scale','rotation']:assert all(abs(x-y)<.003 for x,y in zip(live[key],prior[key]))
        for i,c in enumerate(prior['components']):
            current=live['components'][i]
            assert c['mesh']==current['mesh'] and c['collision']==current['collision']
            for j,p in enumerate(c.get('instances',[])):
                for key in ['at','scale','rotation']:assert all(abs(x-y)<.003 for x,y in zip(p[key],current['instances'][j][key]))
                n+=1
    result=dict(status='passed',source_instances=n,level_instance_actors=sum(a['class_name']=='LevelInstance' for a in old['actors']),materials_only=True)
    assert n==524 and result['level_instance_actors']==11
    (OUT/'main_source_validation.json').write_text(json.dumps(result,indent=2));print('PERSISTENT_SOURCE_AUDIT_PASSED',result)
