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
        const auto Arrival = utils_world_item::Consume_PendingArrival(InState.PendingArrival, Now);

        if (ck::IsValid(InState.Visual))
        { utils_entity_lifetime::Request_DestroyEntity(InState.Visual); }

        InState.Visual = FCk_Handle();

        // Owned by the lock entity, so it dies with the lock.
        if (ck::IsValid(Now) && Now.Has_Presentation())
        {
            auto Visual = FMars_WorldItem_VisualSpec(Now, InState.KeyMount, FTransform::Identity);
            Visual.ArriveFrom = Arrival;
            InState.Visual = utils_world_item::Request_SpawnVisual(InHandle, Visual);
        }

        auto Source = InHandle.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        {
            const auto Output = ck::IsValid(Now) ? EMars_MechanismSource_Output::Asserted : EMars_MechanismSource_Output::Deasserted;
            Source.Request_SetOutput(utils_mechanism_source::Make_SetOutput(Output));
        }

        auto Self = InHandle.As_KeyLock();
        if (Self.Has_Fragment(FMars_Fragment_KeyLock_Signals))
        { Self.Get_Fragment(FMars_Fragment_KeyLock_Signals).OnKeyChanged.Broadcast(Self, Now); }
    }
}
