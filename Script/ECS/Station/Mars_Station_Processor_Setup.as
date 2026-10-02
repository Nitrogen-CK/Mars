// One-shot per station: keeps the Use target in step with the reservation. While an operator holds the station its Use
// target is disabled for everyone (the resolver skips it, so nobody can start a second reserve) and its prompt reads
// OccupiedText; on release it is enabled again and reads PromptText. A reservation that landed before this setup ran
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
        Apply_Occupied(Station, Station.Get_IsOperated());

        Station.Request_TryRemove(FMars_Tag_Station_NeedsSetup);
    }

    UFUNCTION()
    private void OnReserved(FCk_Handle_Station InStation, FCk_Handle InOperator)
    {
        Apply_Occupied(InStation, true);
    }

    // A same-drain re-seat broadcasts Released then Reserved; reading the station keeps the prompt right either way.
    UFUNCTION()
    private void OnReleased(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_ReleaseReason InReason)
    {
        if (ck::Is_NOT_Valid(InStation))
        { return; }

        Apply_Occupied(InStation, InStation.Get_IsOperated());
    }

    private void Apply_Occupied(FCk_Handle_Station InStation, bool InOccupied)
    {
        auto Target = InStation.Get_UseTarget();
        if (ck::Is_NOT_Valid(Target))
        { return; }

        utils_interact_target::Set_Enabled(Target, InOccupied ? ECk_EnableDisable::Disable : ECk_EnableDisable::Enable);

        auto Prompt = FCk_Handle(Target).As_InteractPrompt(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Prompt))
        { return; }

        const auto Spec = InStation.Get_Spec();
        Prompt.Request_UpdateText(FMars_Request_InteractPrompt_UpdateText(InOccupied ? Spec.OccupiedText : Spec.PromptText));
    }
}
