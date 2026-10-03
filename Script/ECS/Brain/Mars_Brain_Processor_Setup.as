// Binds a new brain's planner OnActiveChainChanged to the leaf refresh, and refreshes once at once (a planner that
// planned on start may already hold a plan). The chain changes exactly when the plan's first action changes, so the
// leaf is derived from Get_FirstPlanClass there and nowhere else (no per-frame poll).
class UMars_Processor_Brain_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Brain_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Brain);
        Query.Require(FMars_Tag_Brain_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Brain = InHandle.As_Brain();

        auto Planner = Brain.Get_Planner();
        utils_goap_planner::BindTo_OnActiveChainChanged(Planner, FCk_Delegate_Goap_OnActiveChainChanged(this, n"OnActiveChainChanged"));

        Brain.Request_TryRemove(FMars_Tag_Brain_NeedsSetup);
        RefreshLeaf(Brain);
    }

    // The planner is a lifetime child of the brain's owner (utils_goap_planner::Create). The owner is excluded once it is
    // pending destroy, so a chain change during teardown finds no brain.
    UFUNCTION()
    private void OnActiveChainChanged(FCk_Handle_Goap_Planner InPlanner, FCk_Goap_Payload_OnActiveChainChanged InPayload)
    {
        auto Brain = utils_entity_lifetime::Get_LifetimeOwner(InPlanner).As_Brain(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Brain))
        { return; }

        RefreshLeaf(Brain);
    }

    // Reads the planner's first plan class and, when it differs from the stored leaf, stores it and broadcasts
    // OnLeafChanged.
    private void RefreshLeaf(FCk_Handle_Brain& InBrain)
    {
        auto& State = InBrain.Get_Fragment(FMars_Fragment_Brain);

        const TSubclassOf<UCk_GoapAction_EntityScript> Old = State.LeafClass.Get();
        const TSubclassOf<UCk_GoapAction_EntityScript> New = utils_goap_planner::Get_FirstPlanClass(State.Planner);
        if (Old == New)
        { return; }

        State.LeafClass = New;

        ck::Trace(f"[Brain] [{InBrain.ToString()}] leaf [{utils_brain::Get_ClassName(Old)}] -> [{utils_brain::Get_ClassName(New)}]");

        if (InBrain.Has_Fragment(FMars_Fragment_Brain_Signals))
        { InBrain.Get_Fragment(FMars_Fragment_Brain_Signals).OnLeafChanged.Broadcast(InBrain, Old, New); }
    }
}
