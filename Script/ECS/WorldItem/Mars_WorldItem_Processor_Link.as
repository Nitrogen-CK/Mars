// On a machine without authority, links a Persistent World-mode item to the item it is the body of, from the item the
// authority wrote into the replicated ledger (FMars_Fragment_WorldItem_Net.Item), through the same utils_world_item::Add_Item
// the authority's seed and adopt use; from then on UMars_Processor_WorldItem_Reconcile derives its mount here too. Only a
// client's Add stamps FMars_Tag_WorldItem_AwaitingLink, so the authority never runs this.
//
// A blank handle is the item not resolved on this machine yet, never an error: the body stays unlinked and follows the
// replicated pose. Polled every frame rather than bound to the ledger's notify, because a value that arrived before a bind
// never notifies again.
class UMars_Processor_WorldItem_Link : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunBefore.Add(n"/Script/Angelscript.Mars_Processor_WorldItem_Reconcile");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_WorldItem);
        Query.Require(FMars_Tag_WorldItem_AwaitingLink);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_WorldItem_Net& InNet)
    {
        const auto Item = InNet.Item;
        if (ck::Is_NOT_Valid(Item))
        { return; }

        auto Self = InHandle.As_WorldItem();
        Self.Request_TryRemove(FMars_Tag_WorldItem_AwaitingLink);
        utils_world_item::Add_Item(Self, Item);
    }
}
