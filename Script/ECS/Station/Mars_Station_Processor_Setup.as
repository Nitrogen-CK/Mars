// One-shot per station: keeps the Use target in step with the reservation. While an operator holds the station its Use
// target is disabled for everyone (the resolver skips it, so nobody can start a second reserve) and its prompt reads
// Prompt.OccupiedText; on release it is enabled again and reads Prompt.Text. A reservation that landed before this setup ran
// (same-frame reserve) is applied here at once.
class UMars_Processor_Station_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Station_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Station);
        Query.Require(FMars_Tag_Station_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Station = InHandle.As_Station();

        Station.BindTo_OnReserved(FMars_Delegate_Station_OnReserved(this, n"OnReserved"));
        Station.BindTo_OnReleased(FMars_Delegate_Station_OnReleased(this, n"OnReleased"));
        Sync_UseTarget(Station);

        Station.Request_TryRemove(FMars_Tag_Station_NeedsSetup);
    }

    UFUNCTION()
    private void OnReserved(FCk_Handle_Station InStation, FCk_Handle InOperator)
    {
        Sync_UseTarget(InStation);
    }

    // A same-drain re-seat broadcasts Released then Reserved; reading the station keeps the prompt right either way. A
    // station released by its own destruction has nothing left to update.
    UFUNCTION()
    private void OnReleased(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_ReleaseReason InReason)
    {
        if (ck::Is_NOT_Valid(InStation))
        { return; }

        Sync_UseTarget(InStation);
    }

    // The Use target follows the reservation. Its target is missing only when its interactable was rejected (ensured
    // there).
    private void Sync_UseTarget(FCk_Handle_Station InStation)
    {
        auto Target = InStation.Get_UseTarget();
        if (ck::Is_NOT_Valid(Target))
        { return; }

        const auto Occupied = InStation.Get_IsOperated();
        utils_interact_target::Set_Enabled(Target, Occupied ? ECk_EnableDisable::Disable : ECk_EnableDisable::Enable);

        const auto PromptSpec = InStation.Get_Spec().Prompt;
        auto Prompt = Target.As_InteractPrompt();
        Prompt.Request_UpdateText(FMars_Request_InteractPrompt_UpdateText(Occupied ? PromptSpec.OccupiedText : PromptSpec.Text));
    }
}
