// A world item the spawn funnel put under the replicated spawn owner still follows the owner its caller named
// (FMars_Fragment_WorldItem_Tether): once that owner is gone or ending, the item is destroyed, and the destroy replicates.
// It reads entities still under construction too (the tether is stamped at spawn), so an owner that dies before its item
// finishes building takes the item with it.
//
// Authority only: the tether is stamped by the authority's funnel and a client never ends a replicated entity.
class UMars_Processor_WorldItem_Tether : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_WorldItem_Tether;

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_WorldItem_Tether& InTether)
    {
        if (utils_net::Get_HasAuthority(InHandle) == false || utils_world_item::Get_IsEnding(InHandle))
        { return; }

        if (utils_world_item::Get_IsEnding(InTether.Owner) == false)
        { return; }

        utils_entity_lifetime::Request_DestroyEntity(InHandle);
    }
}
