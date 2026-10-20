// One-shot per station: keeps the Use interactable in step with the reservation. While an operator holds the station its
// Use interactable holds the Operated claim (its framework target is disabled with it, so the resolver skips it and nobody
// can start a second reserve); on release the claim goes. Operated keeps the interactable focusable, so a focuser still
// sees the prompt (the placing script words it for the reservation). A reservation that landed before this setup ran
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

    // A same-drain re-seat broadcasts Released then Reserved; reading the station keeps the claim right either way. A
    // station released by its own destruction has nothing left to update.
    UFUNCTION()
    private void OnReleased(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_ReleaseReason InReason)
    {
        if (ck::Is_NOT_Valid(InStation))
        { return; }

        Sync_UseTarget(InStation);
    }

    // The Use interactable follows the reservation. It is missing only when it was rejected (ensured there).
    private void Sync_UseTarget(FCk_Handle_Station InStation)
    {
        auto Interactable = InStation.Get_Interactable();
        if (ck::Is_NOT_Valid(Interactable))
        { return; }

        if (InStation.Get_IsOperated())
        { Interactable.Request_Disable(FMars_Request_Interactable_Disable(EMars_Interactable_DisableReason::Operated)); }
        else
        { Interactable.Request_Enable(FMars_Request_Interactable_Enable(EMars_Interactable_DisableReason::Operated)); }
    }
}
