// What one drain changed, broadcast after every request is applied: the transfers it settled, the presses it refused, and
// the phase it started from (its edge is the difference). The stock edge is the Tick's: it changes without a request.
struct FMars_CookingFeed_Drain
{
    FCk_Handle_CookingFeed Feed;
    EMars_CookingFeed_Phase StartPhase = EMars_CookingFeed_Phase::Idle;
    // In parallel: one entry per settled transfer.
    TArray<FMars_CookingFeed_PieceId> SettledPieces;
    TArray<EMars_CookingFeed_Settle> Settles;
    TArray<EMars_CookingFeed_Refusal> Refusals;
}

// Drains Reset -> SetSource -> Cancel -> ResolveAdmission -> BeginTransfer, then broadcasts: every settle and refusal in
// order, the phase edge. Reset bumps the generation before clearing anything (a reservation it finds settles Cancelled under
// its old id); SetSource cancels a transfer in flight, bumps the generation and swaps the platter; Cancel drops a
// reservation and idles the hand; ResolveAdmission counts (Accepted) or drops (Rejected) the reservation only while
// awaiting admission for exactly that piece, every other answer is a traced no-op; BeginTransfer reserves the top of the
// source's frozen pile, and every press beyond the first in a drain, or while busy or empty, is refused, never deferred.
// Every cancel before the release puts a piece the feed already took off the source back onto it
// (utils_cooking_feed::Return_Piece); a released piece is control's (the bridge puts a rejected one back).
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
        const auto BeginCount = InRequests.BeginTransferRequests.Num();

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

        for (int32 Index = 0; Index < BeginCount; ++Index)
        { Apply_Begin(Drain, InState); }

        Broadcast(Drain, InState);
    }

    // The generation moves first: an answer for any older piece is stale from here on. The source keeps what it holds.
    private void Apply_Reset(FMars_CookingFeed_Drain& InDrain, FMars_Fragment_CookingFeed& InState)
    {
        InState.Generation += 1;

        if (InState.Active.IsSet())
        { Record_Settle(InDrain, InState.Active.GetValue().Id, EMars_CookingFeed_Settle::Cancelled); }

        utils_cooking_feed::Return_Piece(InState, InDrain.Feed.Get_HandNode());
        utils_cooking_feed::Cancel_Active(InState);
        InState.Admitted = 0;
        InState.PendingRelease = FMars_CookingFeed_Release();

        ck::Trace(f"[CookingFeed] [{InDrain.Feed.ToString()}] reset: generation {InState.Generation}, {utils_cooking_feed::Get_Available(InState)} on the source, hand idle");
    }

    // A transfer in flight is drawn from the old platter, so it is cancelled first; then the generation moves on.
    private void Apply_SetSource(FMars_CookingFeed_Drain& InDrain, FMars_Fragment_CookingFeed& InState,
                                 const FMars_Request_CookingFeed_SetSource& InRequest)
    {
        if (InRequest.Source == InState.Source)
        { return; }

        if (InState.Active.IsSet())
        { Apply_Cancel(InDrain, InState); }

        InState.Generation += 1;
        InState.Source = InRequest.Source;

        ck::Trace(f"[CookingFeed] [{InDrain.Feed.ToString()}] source -> [{InState.Source.ToString()}]: generation {InState.Generation}, {utils_cooking_feed::Get_Available(InState)} on it");
    }

    // A reservation still held is dropped (a piece the feed took off the source goes back onto it); a hand already returning
    // (its piece answered) is simply home.
    private void Apply_Cancel(FMars_CookingFeed_Drain& InDrain, FMars_Fragment_CookingFeed& InState)
    {
        if (InState.Phase == EMars_CookingFeed_Phase::Idle)
        {
            ck::Trace(f"[CookingFeed] [{InDrain.Feed.ToString()}] cancel ignored: the hand is idle");
            return;
        }

        const auto Active = InState.Active;
        utils_cooking_feed::Return_Piece(InState, InDrain.Feed.Get_HandNode());
        if (utils_cooking_feed::Cancel_Active(InState))
        { Record_Settle(InDrain, Active.GetValue().Id, EMars_CookingFeed_Settle::Cancelled); }

        ck::Trace(f"[CookingFeed] [{InDrain.Feed.ToString()}] cancelled the transfer: {utils_cooking_feed::Get_Available(InState)} left");
    }

    // Honoured only while awaiting admission for exactly this piece (same generation and slot). The hand returns either way;
    // a rejected piece is control's to put back on the source.
    private void Apply_Resolve(FMars_CookingFeed_Drain& InDrain, FMars_Fragment_CookingFeed& InState,
                               const FMars_Request_CookingFeed_ResolveAdmission& InRequest)
    {
        const auto PieceName = utils_cooking_feed::Get_PieceName(InRequest.PieceId);
        if (InState.Phase != EMars_CookingFeed_Phase::AwaitAdmission || InState.Active.IsSet() == false)
        {
            ck::Trace(f"[CookingFeed] [{InDrain.Feed.ToString()}] admission answer for {PieceName} ignored: not awaiting one (phase {InState.Phase :n})");
            return;
        }

        const auto Piece = InState.Active.GetValue().Id;
        if (InRequest.PieceId.Get_IsSame(Piece) == false)
        {
            ck::Trace(f"[CookingFeed] [{InDrain.Feed.ToString()}] admission answer for {PieceName} ignored: awaiting {utils_cooking_feed::Get_PieceName(Piece)}");
            return;
        }

        InState.Active.Reset();
        InState.Phase = EMars_CookingFeed_Phase::Return;
        InState.PhaseSeconds = 0.0f;

        if (InRequest.Admission == EMars_CookingFeed_Admission::Accepted)
        {
            InState.Admitted += 1;
            Record_Settle(InDrain, Piece, EMars_CookingFeed_Settle::Admitted);
            ck::Trace(f"[CookingFeed] [{InDrain.Feed.ToString()}] {PieceName} admitted ({InState.Admitted} admitted, {utils_cooking_feed::Get_Available(InState)} left)");
        }
        else
        {
            Record_Settle(InDrain, Piece, EMars_CookingFeed_Settle::Rejected);
            ck::Trace(f"[CookingFeed] [{InDrain.Feed.ToString()}] {PieceName} rejected: {InRequest.Reason} ({utils_cooking_feed::Get_Available(InState)} left)");
        }
    }

    private void Apply_Begin(FMars_CookingFeed_Drain& InDrain, FMars_Fragment_CookingFeed& InState)
    {
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
            ck::Trace(f"[CookingFeed] [{InDrain.Feed.ToString()}] press refused: the source's pile is settling");
            InDrain.Refusals.Add(EMars_CookingFeed_Refusal::Busy);
            return;
        }

        const auto StockIndex = Held.Num() - 1;
        const auto Piece = Held[StockIndex];

        InState.Active = TOptional<FMars_CookingFeed_Reservation>(
            FMars_CookingFeed_Reservation(FMars_CookingFeed_PieceId(InState.Generation, StockIndex), Piece));
        InState.Phase = EMars_CookingFeed_Phase::Reach;
        InState.PhaseSeconds = 0.0f;

        ck::Trace(f"[CookingFeed] [{InDrain.Feed.ToString()}] transfer of {utils_cooking_feed::Get_PieceName(InState.Active.GetValue().Id)} [{Piece.ToString()}] started ({utils_cooking_feed::Get_Available(InState)} left)");
    }

    private void Record_Settle(FMars_CookingFeed_Drain& InDrain, const FMars_CookingFeed_PieceId& InPiece, EMars_CookingFeed_Settle InSettle)
    {
        InDrain.SettledPieces.Add(InPiece);
        InDrain.Settles.Add(InSettle);
    }

    private void Broadcast(FMars_CookingFeed_Drain& InDrain, const FMars_Fragment_CookingFeed& InState)
    {
        if (InDrain.Refusals.Num() > 0)
        { ck::Trace(f"[CookingFeed] [{InDrain.Feed.ToString()}] refused {InDrain.Refusals.Num()} press(es), the first {InDrain.Refusals[0] :n}"); }

        // Read before any handler runs: a handler may issue requests (or tear the station down).
        const auto Phase = InState.Phase;
        auto Feed = InDrain.Feed;

        for (int32 Index = 0; Index < InDrain.Settles.Num(); ++Index)
        {
            if (Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
            { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnTransferSettled.Broadcast(Feed, InDrain.SettledPieces[Index], InDrain.Settles[Index]); }
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
