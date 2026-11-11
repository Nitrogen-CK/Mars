// Drains SetAim: only the last request of the drain applies, so an aim and its release in one frame end where the caller
// left it.
//   Aiming while idle: the Aiming marker is added (the predictor runs from the camera group of this frame), OnAimChanged.
//   Idle while aiming: the marker goes and the path is cleared, then OnAimChanged and OnPathUpdated.
//   Anything else: nothing.
class UMars_Processor_ThrowPreview_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_ThrowPreview_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_ThrowPreview);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_ThrowPreview_Requests& InRequests,
                       FMars_Fragment_ThrowPreview& InState)
    {
        auto Self = InHandle.As_ThrowPreview();

        TArray<FMars_Request_ThrowPreview_SetAim> SetAimRequests = InRequests.SetAimRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_ThrowPreview_Requests);

        if (SetAimRequests.Num() == 0)
        { return; }

        HandleSetAimRequest(Self, InState, SetAimRequests.Last());
    }

    private void HandleSetAimRequest(FCk_Handle_ThrowPreview& InPreview,
                                     FMars_Fragment_ThrowPreview& InState,
                                     const FMars_Request_ThrowPreview_SetAim& InRequest)
    {
        const auto IsAiming = InPreview.Get_IsAiming();
        if (InRequest.Aim == EMars_ThrowPreview_Aim::Aiming)
        {
            if (IsAiming)
            { return; }

            InPreview.Add_Fragment(FMars_Tag_ThrowPreview_Aiming());

            if (InPreview.Has_Fragment(FMars_Fragment_ThrowPreview_Signals))
            { InPreview.Get_Fragment(FMars_Fragment_ThrowPreview_Signals).OnAimChanged.Broadcast(InPreview, EMars_ThrowPreview_Aim::Aiming); }

            return;
        }

        if (IsAiming == false)
        { return; }

        InPreview.Request_TryRemove(FMars_Tag_ThrowPreview_Aiming);
        InState.Path = FMars_ThrowPreview_Path();

        // InState is not read past this line: a listener may add a fragment to the preview's entity.
        if (InPreview.Has_Fragment(FMars_Fragment_ThrowPreview_Signals))
        { InPreview.Get_Fragment(FMars_Fragment_ThrowPreview_Signals).OnAimChanged.Broadcast(InPreview, EMars_ThrowPreview_Aim::Idle); }

        if (InPreview.Has_Fragment(FMars_Fragment_ThrowPreview_Signals))
        { InPreview.Get_Fragment(FMars_Fragment_ThrowPreview_Signals).OnPathUpdated.Broadcast(InPreview); }
    }
}
