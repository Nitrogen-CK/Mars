"""Scoped C gameplay patch; never reapplies the dressed greybox.

Run apply_tile only after guarded Monolith load of the exact target map, outside
PIE. P2 is deliberately excluded: bridge_fit.json records its protected-tunnel
blocker. Restore the dated checkpoint with Unreal closed to roll back.
"""
import hashlib
import json
from pathlib import Path

import unreal as u

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024'
RUN = ROOT / 'Saved/WarrensCGameplay-20261024'
OWNER = 'Mars.WarrensC.GameplayRevision.20261024'
PREFIX = 'WVC_GP_'
EA = u.get_editor_subsystem(u.EditorActorSubsystem)
ED = u.get_editor_subsystem(u.UnrealEditorSubsystem)
LES = u.get_editor_subsystem(u.LevelEditorSubsystem)


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def data():
    return read(RUN / 'revision-manifest.json')


def tag(name):
    result = u.GameplayTag()
    result.import_text('(TagName="' + name + '")')
    assert name in result.export_text(), 'Unregistered tag: ' + name
    return result


def coerce(value):
    if isinstance(value, dict):
        if 'vector' in value:
            return u.Vector(*value['vector'])
        if 'rotator' in value:
            p,y,r = value['rotator']
            return u.Rotator(pitch=p,yaw=y,roll=r)
        if 'transform' in value:
            t = value['transform']
            p,y,r = t.get('rotation', [0,0,0])
            return u.Transform(location=u.Vector(*t['location']),
                               rotation=u.Rotator(pitch=p,yaw=y,roll=r))
        if 'asset' in value:
            asset = u.load_asset(value['asset'])
            assert asset, value['asset']
            return asset
        if 'struct' in value:
            struct = getattr(u, value['struct'])()
            for key, item in value['fields'].items():
                struct.set_editor_property(key, coerce(item))
            return struct
        if 'enum' in value:
            enum = getattr(u,value['enum'][1:],None) or getattr(u,value['enum'])
            return getattr(enum,value['value'].upper())
        if 'tag' in value:
            return tag(value['tag'])
        if 'array' in value:
            return [coerce(item) for item in value['array']]
    return u.Name(value) if isinstance(value,str) else value


def selected(row):
    return (row['note'].startswith('P4 ') or row['note'].startswith('C_')
            or any(' entry '+item in row['note'] for item in ('Cleaver','Tenderizer','Lantern','Tallow')))


def row_id(row):
    return row['note'].replace(' ','_').replace(':','_')


def context(tile):
    manifest = data()
    spec = next((t for t in manifest['tiles'] if t['id']==tile),None)
    path = '/Game/Mars/Maps/Warrens_VariantC_Mars_MAP' if tile is None else '/Game/Mars/Maps/Variants/v8c/'+spec['asset']
    pivot = [70,55,0] if tile is None else spec['pivot']
    assert ED.get_editor_world().get_path_name().split('.')[0] == path, 'Guarded load '+path+' first'
    assert ED.get_game_world() is None, 'PIE must be stopped'
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages(), 'Unsaved maps'
    assert not u.EditorLoadingAndSavingUtils.get_dirty_content_packages(), 'Unsaved content'
    disk = ROOT / ('Content/'+path.removeprefix('/Game/')+'.umap')
    checkpoint = read(RUN/'Checkpoint/manifest.json')
    assert disk.relative_to(ROOT).as_posix() in checkpoint, 'No package checkpoint'
    receipt = RUN/('applied_'+str(tile)+'.json')
    expected = read(receipt)['after_sha256'] if receipt.exists() else checkpoint[disk.relative_to(ROOT).as_posix()]['sha256']
    assert hashlib.sha256(disk.read_bytes()).hexdigest() == expected, 'Package changed since checkpoint/own apply'
    return manifest,path,pivot,disk,receipt


def location(at,pivot):
    return u.Vector(*[(at[i]-pivot[i])*100 for i in range(3)])


def patch_boxes(tile,pivot):
    delta = read(REVIEW/'geometry_delta.json')
    old = [b for b in delta['removed'] if b['tile']==tile]
    added = [b for b in delta['added'] if b['tile']==tile]
    assert tile in ('Belfry','Brineworks') or not (old or added), 'Unexpected geometry scope'
    # Exact transforms identify the original collision instances, even after a
    # previous presentation pass hid the source or changed its material.
    removals = {}
    for row in old:
        want = location(row['centre'],pivot)
        matches=[]
        for actor in EA.get_all_level_actors():
            if not actor.get_actor_label().startswith('Warrens_Greybox_'+row['kind']):
                continue
            for comp in actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent):
                for index in range(comp.get_instance_count()):
                    t=comp.get_instance_transform(index,world_space=True)
                    if ((t.translation-want).length()<0.1
                            and (t.scale3d-u.Vector(*row['size'])).length()<0.001):
                        matches.append((comp,index))
        assert len(matches)==1, ('Source collision instance mismatch',row,len(matches))
        comp,index=matches[0]
        removals.setdefault(comp,[]).append(index)
    for comp,indices in removals.items():
        comp.modify()
        for index in sorted(indices,reverse=True):
            assert comp.remove_instance(index)
    # Added boxes are visible, owned collision carriers. Do not unhide every
    # original wall actor or use NoCollision scenery to stand in for a closure.
    stone=u.load_asset('/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX01')
    floor=u.load_asset('/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX02')
    assert stone and floor
    for index,row in enumerate(added):
        actor=EA.spawn_actor_from_class(u.StaticMeshActor,location(row['centre'],pivot),
                                      u.Rotator(pitch=row['pitch'],yaw=row['yaw'],roll=0))
        assert actor
        actor.set_actor_label(PREFIX+'P4_Collision_'+row['kind']+'_'+str(index))
        actor.tags=[u.Name(OWNER)];actor.set_folder_path('Warrens/GameplayRevision')
        comp=actor.static_mesh_component
        comp.set_mobility(u.ComponentMobility.STATIC)
        comp.set_static_mesh(u.load_asset('/Engine/BasicShapes/Cube'))
        comp.set_collision_profile_name('BlockAll')
        comp.set_material(0,floor if row['kind']=='floor' else stone)
        actor.set_actor_scale3d(u.Vector(*row['size']))
    return dict(removed=len(old),added=len(added))


def spawn(row,pivot):
    cls=u.load_class(None,'/Script/Angelscript.'+row['cls'])
    assert cls, row['cls']
    actor=EA.spawn_actor_from_object(cls,location(row['at'],pivot),
                                   u.Rotator(pitch=row.get('pitch',0),yaw=row['yaw'],roll=0))
    assert actor
    actor.set_actor_label(PREFIX+row_id(row))
    actor.tags=[u.Name(OWNER)];actor.set_folder_path('Warrens/GameplayRevision')
    script=actor.get_editor_property('_EntityScript')
    for key,value in row['props'].items():
        if isinstance(value,dict) and 'fields' in value:
            converted=script.get_editor_property(key)
            for field,item in value['fields'].items():
                converted.set_editor_property(field,coerce(item))
        else:
            converted=coerce(value)
        script.set_editor_property(key,converted)
    if row['cls']=='Mars_Gate_EntityScript':
        script.set_editor_property('MaterialOverride',u.load_asset('/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX09'))
    return actor


def apply_tile(tile):
    manifest,path,pivot,disk,receipt=context(tile)
    rows=[r for r in manifest['entities'] if r.get('tile')==tile and selected(r)]
    previous=read(receipt) if receipt.exists() else None
    existing={a.get_actor_label():a for a in EA.get_all_level_actors()}
    labels=[PREFIX+row_id(r) for r in rows]
    assert len(labels)==len(set(labels))
    # Validate all references before the first actor mutation.
    for row in rows:
        assert u.load_class(None,'/Script/Angelscript.'+row['cls']),row['cls']
        for value in row['props'].values():
            if not (isinstance(value,dict) and 'fields' in value):coerce(value)
    if previous:
        assert all(label in existing for label in previous['fixtures']), 'Owned fixture missing; inspect before reapply'
        return previous  # Same revision is intentionally idempotent; no spawn-on-entry duplication.
    if tile is None:
        raise RuntimeError('Fresh Main apply is held: saving the assembled Level Instance world triggers '
                           'unstable Jolt cook identities. The saved candidate has a receipt; do not '
                           'repeat its original Main save until the canonical cook workflow is repaired.')
    reuse={};used=set()
    for row in rows:
        # Existing hand-authored pickups are retained, never duplicated or
        # renamed. Consume each candidate at most once (two entry tallow).
        if not ('WorldItem_' in row['cls'] or ' entry ' in row['note']):continue
        want=location(row['at'],pivot)
        candidates=[]
        for actor in existing.values():
            if actor.get_path_name() in used or 'Spawner' not in actor.get_class().get_name():continue
            script=actor.get_editor_property('_EntityScript')
            if script.get_class().get_name()!=row['cls']:continue
            distance=(actor.get_actor_location()-want).length()
            if distance<130:candidates.append((distance,actor))
        if candidates:
            actor=min(candidates,key=lambda pair:pair[0])[1]
            reuse[row_id(row)]=actor.get_actor_label();used.add(actor.get_path_name())
    # Only this C niche leaves resolver management. All other caches retain
    # their table and budget. Its exact tag identifies the saved actor.
    removed_mourner=[]
    for actor in list(existing.values()):
        if 'Spawner' not in actor.get_class().get_name():continue
        script=actor.get_editor_property('_EntityScript')
        if script.get_class().get_name()!='Mars_Anchor_Cache_EntityScript':continue
        anchor=script.get_editor_property('AnchorId')
        if 'Anchor.Mars.Warrens.Mourner' in anchor.export_text():
            removed_mourner.append(actor.get_actor_label())
            assert EA.destroy_actor(actor)
    geometry=patch_boxes(tile,pivot)
    actual_labels=[]
    for row,label in zip(rows,labels):
        if row_id(row) in reuse:
            actual_labels.append(reuse[row_id(row)])
            continue
        assert label not in existing, 'Unexpected pre-existing label '+label
        spawn(row,pivot)
        actual_labels.append(label)
    assert LES.save_current_level(),path
    report=dict(map=path,fixtures=actual_labels,reused_pickups=reuse,removed_mourner=removed_mourner,geometry=geometry,
                after_sha256=hashlib.sha256(disk.read_bytes()).hexdigest(),
                boundary='P2 held. Source patch only; live behavior/collision/pickup still require observation.')
    receipt.write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('WVC_GAMEPLAY_REVISION',json.dumps(report))
    return report
