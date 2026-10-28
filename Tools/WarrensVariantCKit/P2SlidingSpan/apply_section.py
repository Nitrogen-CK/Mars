"""Exact, checkpointed P2 prototype patch to the three canonical source LIs.

Never rebuilds the dressed map or saves the assembled Main. All native matches
and asset references are resolved before mutation; save receipts are idempotent.
"""
import hashlib
import importlib.util
import json
from pathlib import Path

import unreal as u

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RUN = ROOT/'Saved/WarrensCGameplay-20261024'
SECTION = ROOT/'Tools/LevelDesign/anchor_plans/data/warrens_v8c_p2_section.json'
OWNER = 'Mars.WarrensC.P2SlidingSpan.20261024'
EA = u.get_editor_subsystem(u.EditorActorSubsystem)
ED = u.get_editor_subsystem(u.UnrealEditorSubsystem)
LES = u.get_editor_subsystem(u.LevelEditorSubsystem)


def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def context(tile):
    assert tile in ('Canal','Waterworks-W','Brineworks'),tile
    manifest = read(RUN/'p2-manifest.json')
    spec = next(row for row in manifest['tiles'] if row['id'] == tile)
    path = '/Game/Mars/Maps/Variants/v8c/'+spec['asset']
    assert ED.get_editor_world().get_path_name().split('.')[0] == path,'Guarded load '+path
    assert ED.get_game_world() is None,'Stop PIE'
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages(),'Unsaved maps'
    assert not u.EditorLoadingAndSavingUtils.get_dirty_content_packages(),'Unsaved content'
    disk = ROOT/('Content/'+path.removeprefix('/Game/')+'.umap')
    prior = read(RUN/'P2Checkpoint/manifest.json')[disk.relative_to(ROOT).as_posix()]
    assert sha(Path(prior['backup'])) == prior['sha256'],'Checkpoint changed'
    receipt = RUN/('p2_applied_'+tile+'.json')
    assert sha(disk) == (read(receipt)['after_sha256'] if receipt.exists() else prior['sha256']),'Map changed externally'
    return manifest,spec,path,disk,receipt


def position(at,pivot): return u.Vector(*[(at[k]-pivot[k])*100 for k in range(3)])


def matches(transform,at,scale,rotation):
    q = u.Rotator(pitch=rotation[0],yaw=rotation[1],roll=rotation[2]).quaternion()
    return ((transform.translation-at).length() < .1
        and (transform.scale3d-u.Vector(*scale)).length() < .001
        and transform.rotation.angular_distance(q) < .001)


def collision_removals(section,tile,pivot):
    sources = [row['source'] for row in section['splits']] + section['removed_boxes']
    removals = {}
    for row in sources:
        if row['tile'] != tile: continue
        found = []
        for actor in EA.get_all_level_actors():
            if not actor.get_actor_label().startswith('Warrens_Greybox_'+row['kind']): continue
            for comp in actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent):
                for index in range(comp.get_instance_count()):
                    if matches(comp.get_instance_transform(index,world_space=True),position(row['centre'],pivot),
                               row['size'],[row['pitch'],row['yaw'],0]):
                        found.append((comp,index))
        assert len(found) == 1,('Source collision mismatch',row,found)
        comp,index = found[0]
        removals.setdefault(comp,set()).add(index)
    return removals


def add_solids(manifest,tile,pivot):
    rows = [row for row in manifest['boxes'] if row.get('tile') == tile
            and row.get('sourceId','').startswith('P2_SlidingSpan:')]
    subsystem = u.get_engine_subsystem(u.SubobjectDataSubsystem)
    groups = {}
    for row in rows: groups.setdefault(row['kind'],[]).append(row)
    for kind,values in groups.items():
        actor = EA.spawn_actor_from_class(u.Actor,u.Vector(),u.Rotator())
        actor.set_actor_label('WVC_P2_Solids_'+kind)
        actor.tags = [u.Name(OWNER)]
        actor.set_folder_path('Warrens/GameplayRevision/P2')
        actor.root_component.set_mobility(u.ComponentMobility.STATIC)
        root = subsystem.k2_gather_subobject_data_for_instance(actor)[0]
        handle,reason = subsystem.add_new_subobject(u.AddNewSubobjectParams(parent_handle=root,
                                                  new_class=u.HierarchicalInstancedStaticMeshComponent))
        comp = u.SubobjectDataBlueprintFunctionLibrary.get_associated_object(
            u.SubobjectDataBlueprintFunctionLibrary.get_data(handle))
        assert comp,reason
        comp.set_mobility(u.ComponentMobility.STATIC)
        comp.set_static_mesh(u.load_asset('/Engine/BasicShapes/Cube'))
        comp.set_collision_profile_name('BlockAll')
        comp.set_material(0,u.load_asset('/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_'+('TX02' if kind=='floor' else 'TX01')))
        for row in values:
            comp.add_instance(u.Transform(location=position(row['centre'],pivot),scale=u.Vector(*row['size']),
                rotation=u.Rotator(pitch=row['pitch'],yaw=row['yaw'],roll=0)),world_space=True)
    return dict(instances=len(rows),hism_groups=len(groups))


def apply(tile):
    manifest,spec,path,disk,receipt = context(tile)
    if receipt.exists(): return read(receipt)
    section = read(SECTION)
    pivot = spec['pivot']
    removals = collision_removals(section,tile,pivot)
    actors = EA.get_all_level_actors()
    assert not any(OWNER in [str(t) for t in actor.tags] for actor in actors),'Unreceipted P2 mutation'
    shortcut = []
    for actor in actors:
        if 'Spawner' not in actor.get_class().get_name(): continue
        script = actor.get_editor_property('_EntityScript')
        if script.get_class().get_name() == 'Mars_Shortcut_EntityScript' and 'Shortcut.Mars.Warrens.ChainCrossing' in script.get_editor_property('ShortcutId').export_text():
            assert (actor.get_actor_location()-position(section['remove_entity']['at'],pivot)).length() < .1
            shortcut.append(actor)
    assert len(shortcut) == (1 if tile=='Waterworks-W' else 0),('Legacy owner mismatch',shortcut)
    helper_spec = importlib.util.spec_from_file_location('p2_fixture_core',HERE.parent/'gameplay_revision.py')
    helper = importlib.util.module_from_spec(helper_spec)
    helper_spec.loader.exec_module(helper)
    entities = [row for row in manifest['entities'] if row.get('tile')==tile and row['note']=='P2 sliding cargo crossing']
    for row in entities:
        assert u.load_class(None,'/Script/Angelscript.'+row['cls'])
        for value in row['props'].values():
            if isinstance(value,dict) and 'fields' in value:
                for nested in value['fields'].values(): helper.coerce(nested)
            else: helper.coerce(value)
    # Full art preflight returns exact per-component/index matches and owned
    # replacements. It must exist before changing collision or the old owner.
    art_spec = importlib.util.spec_from_file_location('p2_art_patch',HERE/'patch_art.py')
    art = importlib.util.module_from_spec(art_spec)
    art_spec.loader.exec_module(art)
    art_plan = art.preflight(tile,pivot)
    for comp,indices in removals.items():
        comp.modify()
        for index in sorted(indices,reverse=True): assert comp.remove_instance(index)
    for actor in shortcut: assert EA.destroy_actor(actor)
    solids = add_solids(manifest,tile,pivot)
    for row in entities:
        actor = helper.spawn(row,pivot)
        actor.set_actor_label('WVC_P2_SlidingSpan')
        actor.tags = [u.Name(OWNER)]
        actor.set_folder_path('Warrens/GameplayRevision/P2')
    art_result = art.apply(art_plan,tile,pivot)
    assert LES.save_current_level(),path
    report = dict(map=path,tile=tile,after_sha256=sha(disk),
        removed_source_instances=sum(len(v) for v in removals.values()),
        removed_shortcut=len(shortcut),solids=solids,owners=len(entities),art=art_result,
        boundary='Saved canonical LI prototype. Not a runtime, loaded traversal or packaged acceptance result.')
    receipt.write_text(json.dumps(report,indent=2))
    print('P2_APPLIED',json.dumps(report))
    return report


def update_guard_mesh():
    """Apply the reviewed see-through guard art at the same collision envelope.

    This is a separate receipt-versioned update: never repeat the source/art
    removals from apply() on an already-patched Level Instance.
    """
    manifest,spec,path,disk,receipt=context('Canal')
    previous=read(receipt)
    asset_path='/Game/Mars/Environment/WarrensVariantCKit/P2SlidingSpan/WarrensC_P2S03_Guard_Mars_SM'
    mesh=u.load_asset(asset_path)
    assert mesh and u.EditorAssetLibrary.get_metadata_tag(mesh,'P2Owner')=='WarrensC.P2SlidingSpan.20261024'
    actors=[a for a in EA.get_all_level_actors() if a.get_actor_label()=='WVC_P2_SlidingSpan']
    assert len(actors)==1 and OWNER in [str(t) for t in actors[0].tags]
    script=actors[0].get_editor_property('_EntityScript')
    if script.get_editor_property('GuardMeshOverride')==mesh:
        assert previous.get('guard_screen_mesh')==asset_path
        return previous
    assert not script.get_editor_property('GuardMeshOverride'),'Foreign guard art'
    actors[0].modify()
    script.modify()
    script.set_editor_property('GuardMeshOverride',mesh)
    assert LES.save_current_level(),path
    previous['before_guard_screen_sha256']=previous['after_sha256']
    previous['after_sha256']=sha(disk)
    previous['guard_screen_mesh']=asset_path
    receipt.write_text(json.dumps(previous,indent=2))
    print('P2_GUARD_SCREEN_SAVED',json.dumps(previous))
    return previous
