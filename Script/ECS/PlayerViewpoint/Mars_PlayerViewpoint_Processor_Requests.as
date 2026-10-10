// Drains view holds and releases in arrival order (a holder held and released in one frame ends released; released and
// held again, ends held). The camera's orientation control follows the holder set once the batch applied: it is turned off
// when the set becomes held and back on when it empties; a batch that leaves it held or free changes nothing. A viewpoint
// without a camera (a test rig's hand-made trace) keeps the set and has no camera to drive.
class UMars_Processor_PlayerViewpoint_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_PlayerViewpoint_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_PlayerViewpoint);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_PlayerViewpoint_Requests& InRequests,
                       FMars_Fragment_PlayerViewpoint& InState)
    {
        auto Self = InHandle.As_PlayerViewpoint();

        TArray<FMars_PlayerViewpoint_ViewHoldRequest> ViewHoldRequests = InRequests.ViewHoldRequests;

        // InRequests is invalid past this line.
        Self.Request_TryRemove(FMars_Fragment_PlayerViewpoint_Requests);

        const auto WasHeld = InState.ViewHolders.Num() > 0;
        for (const auto& Request : ViewHoldRequests)
        {
            if (Request.Change == EMars_PlayerViewpoint_ViewHoldChange::Hold)
            { InState.ViewHolders.AddUnique(Request.Holder); }
            else if (InState.ViewHolders.Contains(Request.Holder))
            { InState.ViewHolders.Remove(Request.Holder); }
        }

        const auto IsHeld = InState.ViewHolders.Num() > 0;
        if (IsHeld == WasHeld || ck::Is_NOT_Valid(InState.Camera))
        { return; }

        auto Camera = InState.Camera;
        Camera.Request_Set_HasOrientationControl(IsHeld == false);
    }
}
