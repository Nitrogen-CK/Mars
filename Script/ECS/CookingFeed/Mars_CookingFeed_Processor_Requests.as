// What one drain changed, broadcast after every request is applied: the transfers it settled, the pieces it let go where
// they lie, the presses it refused, and the phase it started from (its edge is the difference). The stock edge is the
// Tick's: it changes without a request.
struct FMars_CookingFeed_Drain
{
    FCk_Handle_CookingFeed Feed;
    EMars_CookingFeed_Phase StartPhase = EMars_CookingFeed_Phase::Idle;
    // In parallel: one entry per settled transfer.
    TArray<FMars_CookingFeed_PieceId> SettledPieces;
    TArray<EMars_CookingFeed_Settle> Settles;
    // Pieces utils_cooking_feed::Return_Piece let go where they lie: no platter was left to take them back.
    TArray<FCk_Handle_FoodPiece> LetGoPieces;
    TArray<EMars_CookingFeed_Refusal> Refusals;
}

// Drains Reset -> SetSource -> Cancel -> ResolveAdmission -> BeginTransfer, then broadcasts: every settle, every piece let
// go where it lies and every refusal, in order, then the phase edge. A transfer past its grasp is committed: Reset and
// Cancel leave Carry and AwaitAdmission be, and a returning hand finishes its return. Reset otherwise bumps the generation
// (and restarts the transfer count) before clearing anything (a reservation still reaching or grasping settles Cancelled
// under its old id); SetSource cancels a transfer in flight in any phase, bumps the generation (restarting the count) and
// swaps the platter; Cancel drops a reservation still reaching or grasping and idles the hand; ResolveAdmission counts
// (Accepted) or drops (Rejected) the reservation only while awaiting admission for exactly that piece, every other answer
// is a no-op; BeginTransfer refuses a press whose station gate is Shut (StationGate) before anything else, and otherwise
// reserves the top of the source's frozen pile under the attempt's next transfer index. A press while busy (so every press
// after the one a drain started a transfer with) or empty is refused, never deferred.
// The feed is the one owner of the put-back: every piece it took and nobody admitted (cancelled, rejected, or orphaned by a
// new source) goes back to the platter it came from, or is let go where it lies when no platter is left to take it
// (utils_cooking_feed::Return_Piece).
class UMars_Processor_CookingFeed_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_CookingFeed_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_CookingFeed);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_CookingFeed_Requests& InRequests,
                       FMars_Fragment_CookingFeed& InState)
    {
        auto Drain = FMars_CookingFeed_Drain();
        Drain.Feed = InHandle.As_CookingFeed();
        Drain.StartPhase = InState.Phase;

        const auto HasReset = InRequests.ResetRequests.Num() > 0;
        TArray<FMars_Request_CookingFeed_SetSource> SetSourceRequests = InRequests.SetSourceRequests;
        const auto HasCancel = InRequests.CancelRequests.Num() > 0;
        TArray<FMars_Request_CookingFeed_ResolveAdmission> ResolveRequests = InRequests.ResolveAdmissionRequests;
        TArray<FMars_Request_CookingFeed_BeginTransfer> BeginRequests = InRequests.BeginTransferRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Drain.Feed.Request_TryRemove(FMars_Fragment_CookingFeed_Requests);

        if (HasReset)
        { Apply_Reset(Drain, InState); }

        for (const auto& Request : SetSourceRequests)
        { Apply_SetSource(Drain, InState, Request); }

        if (HasCancel)
        { Apply_Cancel(Drain, InState); }

        for (const auto& Request : ResolveRequests)
        { Apply_Resolve(Drain, InState, Request); }

        for (const auto& Request : BeginRequests)
        { Apply_Begin(Drain, InState, Request); }

        Broadcast(Drain, InState);
    }

    // The generation moves first: an answer for any older piece is stale from here on. The source keeps what it holds. A
    // committed transfer keeps its attempt, so its answer still counts.
    private void Apply_Reset(FMars_CookingFeed_Drain& InDrain, FMars_Fragment_CookingFeed& InState)
    {
        if (utils_cooking_feed::Get_IsCommitted(InState.Phase))
        { return; }

        InState.Generation += 1;
        InState.NextTransferIndex = 0;

        if (InState.Active.IsSet())
        { Abandon(InDrain, InState); }

        InState.Admitted = 0;
        InState.PendingRelease = FMars_CookingFeed_Release();
    }

    // The stock changed under the hand: a transfer in flight is drawn from the old platter, so it is cancelled in any phase
    // and its piece goes back to the platter it came from; then the generation moves on.
    private void Apply_SetSource(FMars_CookingFeed_Drain& InDrain, FMars_Fragment_CookingFeed& InState,
                                 const FMars_Request_CookingFeed_SetSource& InRequest)
    {
        if (InRequest.Source == InState.Source)
        { return; }

        if (InState.Active.IsSet())
        { Abandon(InDrain, InState); }

        InState.Generation += 1;
        InState.NextTransferIndex = 0;
        InState.Source = InRequest.Source;
        InState.Admitted = 0;
    }

    // Honoured while the hand reaches for or grasps its piece. Past the grasp the transfer is committed, and a returning hand
    // (its piece answered) finishes its return.
    private void Apply_Cancel(FMars_CookingFeed_Drain& InDrain, FMars_Fragment_CookingFeed& InState)
    {
        if (InState.Phase == EMars_CookingFeed_Phase::Idle)
        { return; }

        if (utils_cooking_feed::Get_IsCommitted(InState.Phase))
        { return; }

        if (InState.Phase == EMars_CookingFeed_Phase::Return)
        { return; }

        Abandon(InDrain, InState);
    }

    // The reservation is dropped and settles Cancelled; a piece the feed took goes back first.
    private void Abandon(FMars_CookingFeed_Drain& InDrain, FMars_Fragment_CookingFeed& InState)
    {
        const auto Active = InState.Active;
        Give_Back(InDrain, InState);
        if (utils_cooking_feed::Cancel_Active(InState))
        { Record_Settle(InDrain, Active.GetValue().Id, EMars_CookingFeed_Settle::Cancelled); }
    }

    // The reserved piece goes back (utils_cooking_feed::Return_Piece); one let go where it lies is broadcast with the drain.
    // Called while the reservation still stands.
    private void Give_Back(FMars_CookingFeed_Drain& InDrain, const FMars_Fragment_CookingFeed& InState)
    {
        if (utils_cooking_feed::Return_Piece(InState, InDrain.Feed.Get_HandNode()) == EMars_CookingFeed_PieceReturn::LetGo)
        { InDrain.LetGoPieces.Add(InState.Active.GetValue().Piece); }
    }

    // Honoured only while awaiting admission for exactly this piece (same generation and transfer). The hand returns either way;
    // a rejected piece goes back to the platter it came from before the hand turns home.
    private void Apply_Resolve(FMars_CookingFeed_Drain& InDrain, FMars_Fragment_CookingFeed& InState,
                               const FMars_Request_CookingFeed_ResolveAdmission& InRequest)
    {
        if (InState.Phase != EMars_CookingFeed_Phase::AwaitAdmission || InState.Active.IsSet() == false)
        { return; }

        const auto Piece = InState.Active.GetValue().Id;
        if (InRequest.PieceId.Get_IsSame(Piece) == false)
        { return; }

        if (InRequest.Admission == EMars_CookingFeed_Admission::Rejected)
        { Give_Back(InDrain, InState); }

        InState.Active.Reset();
        InState.Phase = EMars_CookingFeed_Phase::Return;
        InState.PhaseSeconds = 0.0f;

        if (InRequest.Admission == EMars_CookingFeed_Admission::Accepted)
        {
            InState.Admitted += 1;
            Record_Settle(InDrain, Piece, EMars_CookingFeed_Settle::Admitted);
        }
        else
        { Record_Settle(InDrain, Piece, EMars_CookingFeed_Settle::Rejected); }
    }

    // The station's own gate is asked first: a Shut gate refuses the press before the feed looks at its hand or its stock.
    private void Apply_Begin(FMars_CookingFeed_Drain& InDrain, FMars_Fragment_CookingFeed& InState,
                             const FMars_Request_CookingFeed_BeginTransfer& InRequest)
    {
        if (InRequest.Gate == EMars_CookingFeed_StationGate::Shut)
        {
            InDrain.Refusals.Add(EMars_CookingFeed_Refusal::StationGate);
            return;
        }

        if (InState.Phase != EMars_CookingFeed_Phase::Idle)
        {
            InDrain.Refusals.Add(EMars_CookingFeed_Refusal::Busy);
            return;
        }

        if (utils_cooking_feed::Get_Available(InState) <= 0)
        {
            InDrain.Refusals.Add(EMars_CookingFeed_Refusal::Empty);
            return;
        }

        if (ck::Is_NOT_Valid(InDrain.Feed.Get_ReleaseNode()))
        {
            InDrain.Refusals.Add(EMars_CookingFeed_Refusal::NoRelease);
            return;
        }

        // Idle with stock: nothing is reserved, so the top of the pile (the last piece frozen) is free to take. A pile still
        // settling has nothing frozen to reach for yet: the press is refused, the next one takes the top.
        const auto Held = InState.Source.Get_Held();
        if (Held.Num() == 0)
        {
            InDrain.Refusals.Add(EMars_CookingFeed_Refusal::Busy);
            return;
        }

        const auto Piece = Held.Last();
        const auto TransferIndex = InState.NextTransferIndex;
        InState.NextTransferIndex += 1;

        InState.Active = TOptional<FMars_CookingFeed_Reservation>(
            FMars_CookingFeed_Reservation(FMars_CookingFeed_PieceId(InState.Generation, TransferIndex), Piece, InState.Source));
        InState.Phase = EMars_CookingFeed_Phase::Reach;
        InState.PhaseSeconds = 0.0f;
    }

    private void Record_Settle(FMars_CookingFeed_Drain& InDrain, const FMars_CookingFeed_PieceId& InPiece, EMars_CookingFeed_Settle InSettle)
    {
        InDrain.SettledPieces.Add(InPiece);
        InDrain.Settles.Add(InSettle);
    }

    private void Broadcast(FMars_CookingFeed_Drain& InDrain, const FMars_Fragment_CookingFeed& InState)
    {
        // Read before any handler runs: a handler may issue requests (or tear the station down).
        const auto Phase = InState.Phase;
        auto Feed = InDrain.Feed;

        for (int32 Index = 0; Index < InDrain.Settles.Num(); ++Index)
        {
            if (Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
            { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnTransferSettled.Broadcast(Feed, InDrain.SettledPieces[Index], InDrain.Settles[Index]); }
        }

        for (const auto& Piece : InDrain.LetGoPieces)
        {
            if (Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
            { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnPieceLetGo.Broadcast(Feed, Piece); }
        }

        for (const auto Refusal : InDrain.Refusals)
        {
            if (Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
            { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnTransferRefused.Broadcast(Feed, Refusal); }
        }

        if (Phase != InDrain.StartPhase && Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
        { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnPhaseChanged.Broadcast(Feed, Phase); }
    }
}
