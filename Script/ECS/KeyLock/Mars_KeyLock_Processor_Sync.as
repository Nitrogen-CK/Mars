// Polls each lock's key against the last pass (the CargoSlot sync shape). A change destroys the old key visual, spawns one
// for the new key (a Visual-mode world item on the KeyMount node, arriving from where a fresh insert said it was), drives
// a MechanismSource on the same entity (asserted while a key is in), then broadcasts OnKeyChanged.
class UMars_Processor_KeyLock_Sync : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_KeyLock);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_KeyLock& InState)
    {
        auto Now = InState.Inventory.Get_SoleItem();
        if (Now == InState.LastSeen)
        { return; }

        InState.LastSeen = Now;

        if (ck::IsValid(InState.Visual))
        { utils_entity_lifetime::Request_DestroyEntity(InState.Visual); }

        InState.Visual = FCk_Handle();

        if (ck::IsValid(Now) && Now.Has_Presentation())
        { InState.Visual = SpawnVisual(InHandle, InState, Now); }

        auto Source = InHandle.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        {
            const auto Output = ck::IsValid(Now) ? EMars_MechanismSource_Output::Asserted : EMars_MechanismSource_Output::Deasserted;
            Source.Request_SetOutput(FMars_Request_MechanismSource_SetOutput(Output));
        }

        auto Self = InHandle.As_KeyLock();
        if (Self.Has_Fragment(FMars_Fragment_KeyLock_Signals))
        { Self.Get_Fragment(FMars_Fragment_KeyLock_Signals).OnKeyChanged.Broadcast(Self, Now); }
    }

    // Owned by the lock entity, so it dies with the lock. The key's pending arrival is consumed here either way.
    private FCk_Handle SpawnVisual(FCk_Handle& InLock, FMars_Fragment_KeyLock& InState, FCk_Handle_Item& InItem)
    {
        auto Visual = FMars_WorldItem_VisualSpec(InItem, InState.KeyMount, FTransform::Identity);
        if (InState.PendingArrival.IsSet() && InState.PendingArrival.GetValue().Item == InItem)
        {
            Visual.ArriveFrom = utils_world_item::Get_FreshArrival(InState.PendingArrival.GetValue());
            InState.PendingArrival.Reset();
        }

        return utils_world_item::Request_SpawnVisual(InLock, Visual);
    }
}
