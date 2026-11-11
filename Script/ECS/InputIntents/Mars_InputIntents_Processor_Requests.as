// Drains SetMatcher, then SetMoveDirection, each in submission order, then AddLookDelta, then ClearRemote, then
// ApplyRemoteSample in arrival order. Every SetMatcher that changes the matcher broadcasts OnMatcherChanged(Prev, New) - a
// swap to INVALID and back inside one frame broadcasts twice - so matcher-signal consumers rebind inside the handler. The
// AddLookDelta requests of one drain and the remote look total's move over the drain are summed into LookDelta
// (replacing the last one) and advance LookDeltaSequence once.
//
// Remote samples (the authority's copy of a remote operator): the first after a clear seeds the totals and serials and
// raises nothing. Later, a serial that advanced starts a run of that many presses stamped with this frame, or lengthens the
// row's run while a reader may not have read all of it yet. The getter reads a run one press a frame
// (utils_input_intents::TryGet_RemoteActivationFrame), so presses that land together (a late burst, a sample making up
// lost ones) are never merged, and a press that arrives already released is still read. A run holds at most
// constants_input_intents::k_MaxRemoteRunPresses. A sample whose serial is behind the row's is stale and changes nothing
// in that row.
class UMars_Processor_InputIntents_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_InputIntents_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_InputIntents);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_InputIntents_Requests& InRequests,
                       FMars_Fragment_InputIntents& InState)
    {
        auto Self = InHandle.As_InputIntents();

        TArray<FMars_Request_InputIntents_SetMatcher> SetMatcherRequests = InRequests.SetMatcherRequests;
        TArray<FMars_Request_InputIntents_SetMoveDirection> SetMoveDirectionRequests = InRequests.SetMoveDirectionRequests;
        TArray<FMars_Request_InputIntents_AddLookDelta> AddLookDeltaRequests = InRequests.AddLookDeltaRequests;
        TArray<FMars_Request_InputIntents_ClearRemote> ClearRemoteRequests = InRequests.ClearRemoteRequests;
        TArray<FMars_Request_InputIntents_ApplyRemoteSample> ApplyRemoteSampleRequests = InRequests.ApplyRemoteSampleRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_InputIntents_Requests);

        for (const auto& Request : SetMatcherRequests)
        { HandleSetMatcherRequest(Self, InState, Request); }

        for (const auto& Request : SetMoveDirectionRequests)
        { InState.MoveDirection = Request.MoveDirection; }

        auto LookDelta = Sum_LookDeltas(AddLookDeltaRequests);

        if (ClearRemoteRequests.IsEmpty() == false && Self.Has_Fragment(FMars_Fragment_InputIntents_Remote))
        {
            auto& Remote = Self.Get_Fragment(FMars_Fragment_InputIntents_Remote);
            Remote = FMars_Fragment_InputIntents_Remote();
        }

        if (ApplyRemoteSampleRequests.IsEmpty() == false)
        {
            const auto RemoteLook = HandleApplyRemoteSampleRequests(Self, ApplyRemoteSampleRequests);
            if (RemoteLook.IsSet())
            {
                const auto LocalLook = LookDelta.IsSet() ? LookDelta.GetValue() : FVector::ZeroVector;
                LookDelta = TOptional<FVector>(LocalLook + RemoteLook.GetValue());
            }
        }

        if (LookDelta.IsSet())
        {
            InState.LookDelta = LookDelta.GetValue();
            InState.LookDeltaSequence += 1;
        }
    }

    private TOptional<FVector> Sum_LookDeltas(const TArray<FMars_Request_InputIntents_AddLookDelta>& InRequests)
    {
        if (InRequests.IsEmpty())
        { return TOptional<FVector>(); }

        auto LookDelta = FVector::ZeroVector;
        for (const auto& Request : InRequests)
        { LookDelta += Request.LookDelta; }

        return TOptional<FVector>(LookDelta);
    }

    // Applies every sample in order; returns how far the look total moved over them (unset = it did not move).
    private TOptional<FVector> HandleApplyRemoteSampleRequests(
        FCk_Handle_InputIntents& InIntents,
        const TArray<FMars_Request_InputIntents_ApplyRemoteSample>& InRequests)
    {
        auto& Remote = InIntents.AddOrGet_Fragment(FMars_Fragment_InputIntents_Remote);

        auto Drain = FMars_InputIntents_RemoteDrain();
        Drain.Intents = InIntents;
        Drain.Frame = int32(utils_time::Get_FrameCounter());
        Drain.LookStart = Remote.LookTotal;

        for (const auto& Request : InRequests)
        { Apply_Sample(Remote, Request.Sample, Drain); }

        if (Drain.LookStart.IsSet() == false || Remote.LookTotal.IsSet() == false)
        { return TOptional<FVector>(); }

        const auto Moved = Remote.LookTotal.GetValue() - Drain.LookStart.GetValue();
        if (Moved.IsZero())
        { return TOptional<FVector>(); }

        return TOptional<FVector>(Moved);
    }

    private void Apply_Sample(
        FMars_Fragment_InputIntents_Remote& InOutRemote,
        const FMars_InputIntents_RemoteSample& InSample,
        FMars_InputIntents_RemoteDrain& InOutDrain)
    {
        const auto Seeding = InOutRemote.LookTotal.IsSet() == false;
        InOutRemote.LookTotal = TOptional<FVector>(InSample.LookTotal);
        if (Seeding)
        { InOutDrain.LookStart = TOptional<FVector>(InSample.LookTotal); }

        for (const auto& Intent : InSample.Intents)
        {
            const auto RowIndex = Find_Row(InOutRemote, Intent.Intent);
            if (RowIndex == ck::INDEX_NONE())
            {
                // A row first seen seeds, as the whole sample does after a clear: its serial so far raises nothing.
                auto NewRow = FMars_InputIntents_RemoteRow();
                NewRow.Intent = Intent.Intent;
                NewRow.PressSerial = Intent.PressSerial;
                NewRow.Hold = Intent.Hold;
                InOutRemote.Rows.Add(NewRow);
                continue;
            }

            auto& Row = InOutRemote.Rows[RowIndex];
            if (Intent.PressSerial < Row.PressSerial)
            { continue; }

            if (Intent.PressSerial > Row.PressSerial)
            {
                const auto Advanced = Intent.PressSerial - Row.PressSerial;
                if (Advanced > 1)
                { ck::Trace(f"[InputIntents] [{InOutDrain.Intents.ToString()}] [{Intent.Intent.ToString()}] advanced {Advanced} presses in one sample: read one a frame"); }

                if (utils_input_intents::Get_IsRemoteRunRead(Row, InOutDrain.Frame))
                {
                    Row.ActivationFrame = TOptional<int32>(InOutDrain.Frame);
                    Row.Presses = 0;
                }

                Row.Presses = Math::Min(Row.Presses + Advanced, constants_input_intents::k_MaxRemoteRunPresses);
            }

            Row.PressSerial = Intent.PressSerial;
            Row.Hold = Intent.Hold;
        }
    }

    private int32 Find_Row(const FMars_Fragment_InputIntents_Remote& InRemote, FGameplayTag InIntent)
    {
        for (int32 Index = 0; Index < InRemote.Rows.Num(); ++Index)
        {
            if (InRemote.Rows[Index].Intent == InIntent)
            { return Index; }
        }

        return ck::INDEX_NONE();
    }

    private void HandleSetMatcherRequest(
        FCk_Handle_InputIntents& InIntents,
        FMars_Fragment_InputIntents& InState,
        const FMars_Request_InputIntents_SetMatcher& InRequest)
    {
        const auto PrevMatcher = InState.Matcher;
        if (PrevMatcher == InRequest.Matcher)
        { return; }

        InState.Matcher = InRequest.Matcher;

        if (InIntents.Has_Fragment(FMars_Fragment_InputIntents_Signals))
        { InIntents.Get_Fragment(FMars_Fragment_InputIntents_Signals).OnMatcherChanged.Broadcast(InIntents, PrevMatcher, InRequest.Matcher); }
    }
}
