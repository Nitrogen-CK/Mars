"""Exact NoCollision HISM delta; original fitted art ledger stays read-only."""
import hashlib
import importlib.util
import json
from pathlib import Path

import unreal as u

HERE = Path(__file__).resolve().parent
KIT = HERE.parent
OWNER = 'Mars.WarrensC.P2SlidingSpan.20261024'
ART_OWNER = 'Mars.WarrensVariantCKit.Authoring.v1'
EA = u.get_editor_subsystem(u.EditorActorSubsystem)


def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))


def preflight(tile,pivot):
    delta = read(HERE/'Output/art_delta.json')
    assert hashlib.sha256((KIT/'Output/fitted_instances.json').read_bytes()).hexdigest()==delta['source_ledger_sha256']
    source = HERE.parents[2]/'Tools/LevelDesign/anchor_plans/data/warrens_v8c_p2_section.json'
    assert hashlib.sha256(source.read_bytes()).hexdigest()==delta['section_sha256']
    art_tile = 'WaterworksW' if tile=='Waterworks-W' else tile
    actors = {a.get_actor_label():a for a in EA.get_all_level_actors()}
    found = {}
    for row in delta['removed']:
        if row['tile']!=art_tile: continue
        actor = actors['WVC_'+row['id']]
        assert ART_OWNER in [str(t) for t in actor.tags],actor.get_actor_label()
        components = actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
        assert len(components)==1
        comp = components[0]
        assert str(comp.get_collision_profile_name())=='NoCollision'
        at = u.Vector(*[(row['at'][k]-pivot[k])*100 for k in range(3)])
        p,y,r = row.get('rotation',[0,row.get('yaw',0),0])
        rotation = u.Rotator(pitch=p,yaw=y,roll=r).quaternion()
        indices = []
        for i in range(comp.get_instance_count()):
            t = comp.get_instance_transform(i,world_space=True)
            if (t.translation-at).length()<.1 and (t.scale3d-u.Vector(*row['scale'])).length()<.001 and t.rotation.angular_distance(rotation)<.001:
                indices.append(i)
        assert len(indices)==1,('Art instance mismatch',row,indices)
        selected = found.setdefault(comp,set())
        assert indices[0] not in selected,('Repeated art removal',row)
        selected.add(indices[0])
    lights = []
    for row in delta['removed_lights']:
        if row['tile']!=art_tile: continue
        actor = actors['WVC_Practical_'+str(row['index'])]
        assert isinstance(actor,u.PointLight) and ART_OWNER in [str(t) for t in actor.tags]
        at = u.Vector(*[(row['at'][k]-pivot[k])*100 for k in range(3)])
        assert (actor.get_actor_location()-at).length()<.1
        lights.append(actor)
    added = [r for r in delta['added'] if r['tile']==art_tile]
    # Resolve original catalog mesh paths/materials before touching any instance.
    registry = {}
    for kit in ('ChainCrossingKit','PumpCisternKit','WarrensVariantCKit'):
        for row in read(KIT.parent/kit/'Output/asset_manifest.json')['assets']:
            registry[row['id']]='/Game/Mars/Environment/'+kit+'/Meshes/'+row['name']
    for key in ('TX01','TX02','TX04','TX17'): registry['BACKING_'+key]='/Engine/BasicShapes/Cube'
    for row in added:
        registry[row['id']]=registry.get(row.get('mesh_id',row['id']),registry.get(row['id']))
        assert registry[row['id']] and u.load_asset(registry[row['id']]),row
        if row.get('material'): assert u.load_asset('/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_'+row['material'])
    return dict(removals=found,lights=lights,added=added,registry=registry)


def apply(plan,tile,pivot):
    for comp,indices in plan['removals'].items():
        comp.modify()
        for index in sorted(indices,reverse=True): assert comp.remove_instance(index)
    for actor in plan['lights']: assert EA.destroy_actor(actor)
    spec = importlib.util.spec_from_file_location('p2_art_instance_core',KIT.parent/'ChainCrossingKit/unreal_scenes.py')
    core = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(core)
    core.OWNER = OWNER
    core.PREFIX = 'WVC_P2_Art_'
    core.FOLDER = 'Warrens/GameplayRevision/P2'
    counts = core.add_instances(plan['added'],pivot,True,plan['registry'],'/Game/Mars/Environment/ChainCrossingKit')
    return dict(removed_instances=sum(len(v) for v in plan['removals'].values()),
                removed_lights=len(plan['lights']),added_instances=sum(counts.values()),hism_groups=len(counts))
