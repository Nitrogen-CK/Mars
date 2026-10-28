"""Read-only runtime cargo ownership receipts through public native APIs."""
import json
from pathlib import Path
import unreal as u


def capture(name):
    world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert world
    pawn = u.GameplayStatics.get_player_pawn(world, 0)
    proxy = next(s for s in u.ObjectIterator(u.Ck_EntityScript_UE)
                 if s.get_class().get_name() == 'Mars_PlacedPickup_EntityScript'
                 and s.get_outer() == world
                 and str(s.get_editor_property('FixtureId')) == 'WarrensC.Startup.S1_pack')
    pack = proxy.get_spawned_entity()
    handle_text = u.Ck_Utils_Handle_UE.conv_handle_to_string
    transform = u.Ck_Utils_Transform_UE.do_cast_checked(pack)
    nodes = u.Ck_Utils_SceneNode_UE.for_each_scene_node(
        transform, u.InstancedStruct(), u.Ck_Lambda_InHandle())[0]
    inventories = []
    for node in nodes:
        for inventory in u.Ck_Utils_Inventory_UE.for_each_inventories(
                node, u.InstancedStruct(), u.Ck_Lambda_InHandle())[0]:
            items = []
            for item in u.Ck_Utils_Inventory_UE.get_items(inventory):
                items.append(dict(handle=handle_text(item),
                    definition=u.Ck_Utils_Item_UE.get_definition(item).get_path_name(),
                    parent_matches=u.Ck_Utils_Handle_UE.is_equal(
                        inventory, u.Ck_Utils_Item_UE.get_parent_inventory(item))))
            inventories.append(dict(handle=handle_text(inventory), items=items))
    helper = u.new_object(u.load_class(None, '/Script/Angelscript.Mars_ExpeditionAcceptance'))
    report = dict(world=world.get_path_name(), t=u.GameplayStatics.get_time_seconds(world),
                  pawn=list(pawn.get_actor_location().to_tuple()), pack=handle_text(pack),
                  inventories=inventories, inspection=helper.inspect(pawn),
                  boundary='Read-only public native inventory and parent-ownership queries. '
                           'Positioning for the isolated movement trial is excluded.')
    output = Path(__file__).resolve().parents[2] / 'Saved/WarrensCGameplay-20261024' / (name + '.json')
    assert not output.exists(), 'Keep preceding observations immutable'
    output.write_text(json.dumps(report, indent=2))
    return report
