// Drains Open, then MovePointer, then Close - so a press and release landing in one frame opens and cancels, and a
// pointer move queued alongside a close still counts towards the choice.
class UMars_Processor_EmoteWheel_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_EmoteWheel_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_EmoteWheel);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_EmoteWheel_Requests& InRequests,
                       FMars_Fragment_EmoteWheel& InState)
    {
        auto Self = InHandle.As_EmoteWheel();

        TArray<FMars_Request_EmoteWheel_Open> OpenRequests = InRequests.OpenRequests;
        TArray<FMars_Request_EmoteWheel_MovePointer> MovePointerRequests = InRequests.MovePointerRequests;
        TArray<FMars_Request_EmoteWheel_Close> CloseRequests = InRequests.CloseRequests;

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_EmoteWheel_Requests);

        for (int32 Index = 0; Index < OpenRequests.Num(); ++Index)
        { HandleOpenRequest(Self, InState); }

        for (const auto& Request : MovePointerRequests)
        { HandleMovePointerRequest(Self, InState, Request); }

        for (const auto& Request : CloseRequests)
        { HandleCloseRequest(Self, InState, Request); }
    }

    private void HandleOpenRequest(FCk_Handle_EmoteWheel& InWheel, FMars_Fragment_EmoteWheel& InState)
    {
        if (InState.IsOpen)
        { return; }

        InState.IsOpen = true;
        InState.Pointer = FVector2D::ZeroVector;
        InState.HoveredIndex = -1;

        if (InWheel.Has_Fragment(FMars_Fragment_EmoteWheel_Signals))
        { InWheel.Get_Fragment(FMars_Fragment_EmoteWheel_Signals).OnOpened.Broadcast(InWheel); }
    }

    // The pointer is clamped to the rim, so pushing past it slides around the wheel instead of building up travel the
    // player would have to undo.
    private void HandleMovePointerRequest(
        FCk_Handle_EmoteWheel& InWheel,
        FMars_Fragment_EmoteWheel& InState,
        const FMars_Request_EmoteWheel_MovePointer& InRequest)
    {
        if (InState.IsOpen == false)
        { return; }

        const auto& Params = InWheel.Get_Fragment(FMars_Fragment_EmoteWheel_Params);

        auto Pointer = InState.Pointer + InRequest.Delta / Params.PointerTravel;
        if (Pointer.Size() > 1.0)
        { Pointer = Pointer.GetSafeNormal(); }

        InState.Pointer = Pointer;

        const auto PrevIndex = InState.HoveredIndex;
        const auto NewIndex = utils_emote_wheel::Get_SectorAt(Pointer, Params.Entries.Num(), Params.DeadZoneRatio);
        if (NewIndex == PrevIndex)
        { return; }

        InState.HoveredIndex = NewIndex;

        if (InWheel.Has_Fragment(FMars_Fragment_EmoteWheel_Signals))
        { InWheel.Get_Fragment(FMars_Fragment_EmoteWheel_Signals).OnHoveredChanged.Broadcast(InWheel, PrevIndex, NewIndex); }
    }

    private void HandleCloseRequest(
        FCk_Handle_EmoteWheel& InWheel,
        FMars_Fragment_EmoteWheel& InState,
        const FMars_Request_EmoteWheel_Close& InRequest)
    {
        if (InState.IsOpen == false)
        { return; }

        const auto ChosenIndex = InState.HoveredIndex;
        const auto ChosenEntry = InWheel.TryGet_Entry(ChosenIndex);
        const auto IsChosen = InRequest.Confirm && ChosenEntry.IsSet() && ChosenEntry.GetValue().IsEnabled;

        InState.IsOpen = false;
        InState.Pointer = FVector2D::ZeroVector;
        InState.HoveredIndex = -1;

        // Re-fetched per broadcast: a listener may add fragments to the wheel.
        if (IsChosen && InWheel.Has_Fragment(FMars_Fragment_EmoteWheel_Signals))
        { InWheel.Get_Fragment(FMars_Fragment_EmoteWheel_Signals).OnEmoteChosen.Broadcast(InWheel, ChosenIndex, ChosenEntry.GetValue().Emote); }

        if (InWheel.Has_Fragment(FMars_Fragment_EmoteWheel_Signals))
        { InWheel.Get_Fragment(FMars_Fragment_EmoteWheel_Signals).OnClosed.Broadcast(InWheel); }
    }
}
