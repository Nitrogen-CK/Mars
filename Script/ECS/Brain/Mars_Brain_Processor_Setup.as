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
        if (ck::IsValid(Planner))
        { utils_goap_planner::BindTo_OnActiveChainChanged(Planner, FCk_Delegate_Goap_OnActiveChainChanged(this, n"OnActiveChainChanged")); }

        Brain.Request_TryRemove(FMars_Tag_Brain_NeedsSetup);
        utils_brain::Refresh(Brain);
    }

    // The planner is a lifetime child of the brain's owner (utils_goap_planner::Create).
    UFUNCTION()
    private void OnActiveChainChanged(FCk_Handle_Goap_Planner InPlanner, FCk_Goap_Payload_OnActiveChainChanged InPayload)
    {
        auto Brain = utils_entity_lifetime::Get_LifetimeOwner(FCk_Handle(InPlanner)).As_Brain(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Brain))
        { return; }

        utils_brain::Refresh(Brain);
    }
}
