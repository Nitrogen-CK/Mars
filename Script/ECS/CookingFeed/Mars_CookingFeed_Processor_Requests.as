// What one drain changed, broadcast after every request is applied: the transfers it settled, the presses it refused, and
// the stock and phase it started from (their edges are the difference).
struct FMars_CookingFeed_Drain
{
    FCk_Handle_CookingFeed Feed;
    int32 StartAvailable = 0;
    int32 StartAdmitted = 0;
    EMars_CookingFeed_Phase StartPhase = EMars_CookingFeed_Phase::Idle;
    // In parallel: one entry per settled transfer.
    TArray<FMars_CookingFeed_PieceId> SettledPieces;
    TArray<EMars_CookingFeed_Settle> Settles;
    TArray<EMars_CookingFeed_Refusal> Refusals;
}

// Drains Reset -> Cancel -> ResolveAdmission -> BeginTransfer, then broadcasts: every settle and refusal in order, the stock
// edge, the phase edge. Reset bumps the generation before clearing anything (a reservation it finds settles Cancelled under
// its old id); Cancel restores a reserved slot and idles the hand; ResolveAdmission spends (Accepted) or restores (Rejected)
// the reservation only while awaiting admission for exactly that piece, every other answer is a traced no-op; BeginTransfer
// reserves the lowest free slot, and every press beyond the first in a drain, or while busy or empty, is refused, never
// deferred. Nothing is spent before an Accepted answer.
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
        Drain.StartAvailable = InState.Available;
        Drain.StartAdmitted = InState.Admitted;
        Drain.StartPhase = InState.Phase;

        const auto HasReset = InRequests.ResetRequests.Num() > 0;
        const auto HasCancel = InRequests.CancelRequests.Num() > 0;
        TArray<FMars_Request_CookingFeed_ResolveAdmission> ResolveRequests = InRequests.ResolveAdmissionRequests;
        const auto BeginCount = InRequests.BeginTransferRequests.Num();

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Drain.Feed.Request_TryRemove(FMars_Fragment_CookingFeed_Requests);

        if (HasReset)
        { Apply_Reset(Drain, InState); }

        if (HasCancel)
        { Apply_Cancel(Drain, InState); }

        for (const auto& Request : ResolveRequests)
        { Apply_Resolve(Drain, InState, Request); }

        for (int32 Index = 0; Index < BeginCount; ++Index)
        { Apply_Begin(Drain, InState); }

        Broadcast(Drain, InState);
    }

    // The generation moves first: an answer for any older piece is stale from here on.
    private void Apply_Reset(FMars_CookingFeed_Drain& InDrain, FMars_Fragment_CookingFeed& InState)
    {
        const auto Spec = InDrain.Feed.Get_Spec();
        InState.Generation += 1;

        if (InState.Active.IsSet())
        { Record_Settle(InDrain, InState.Active.GetValue(), EMars_CookingFeed_Settle::Cancelled); }

        InState.Active.Reset();
        InState.Phase = EMars_CookingFeed_Phase::Idle;
        InState.PhaseSeconds = 0.0f;
        InState.Available = Spec.Supply.InitialCount;
        InState.Admitted = 0;
        InState.PendingRelease = FMars_CookingFeed_Release();
        for (int32 Slot = 0; Slot < InState.SlotTaken.Num(); ++Slot)
        { InState.SlotTaken[Slot] = false; }

        ck::Trace(f"[CookingFeed] [{InDrain.Feed.ToString()}] reset: generation {InState.Generation}, {InState.Available} pieces, hand idle");
    }

    // A reservation still held goes back to its slot; a hand already returning (its piece answered) is simply home.
    private void Apply_Cancel(FMars_CookingFeed_Drain& InDrain, FMars_Fragment_CookingFeed& InState)
    {
        if (InState.Phase == EMars_CookingFeed_Phase::Idle)
        {
            ck::Trace(f"[CookingFeed] [{InDrain.Feed.ToString()}] cancel ignored: the hand is idle");
            return;
        }

        if (InState.Active.IsSet())
        {
            const auto Piece = InState.Active.GetValue();
            Restore_Slot(InState, Piece);
            Record_Settle(InDrain, Piece, EMars_CookingFeed_Settle::Cancelled);
            InState.Active.Reset();
        }

        InState.Phase = EMars_CookingFeed_Phase::Idle;
        InState.PhaseSeconds = 0.0f;

        ck::Trace(f"[CookingFeed] [{InDrain.Feed.ToString()}] cancelled the transfer: {InState.Available} left");
    }

    // Honoured only while awaiting admission for exactly this piece (same generation and slot). The hand returns either way.
    private void Apply_Resolve(FMars_CookingFeed_Drain& InDrain, FMars_Fragment_CookingFeed& InState,
                               const FMars_Request_CookingFeed_ResolveAdmission& InRequest)
    {
        const auto PieceName = utils_cooking_feed::Get_PieceName(InRequest.PieceId);
        if (InState.Phase != EMars_CookingFeed_Phase::AwaitAdmission || InState.Active.IsSet() == false)
        {
            ck::Trace(f"[CookingFeed] [{InDrain.Feed.ToString()}] admission answer for {PieceName} ignored: not awaiting one (phase {InState.Phase :n})");
            return;
        }

        const auto Piece = InState.Active.GetValue();
        if (InRequest.PieceId.Get_IsSame(Piece) == false)
        {
            ck::Trace(f"[CookingFeed] [{InDrain.Feed.ToString()}] admission answer for {PieceName} ignored: awaiting {utils_cooking_feed::Get_PieceName(Piece)}");
            return;
        }

        if (InRequest.Admission == EMars_CookingFeed_Admission::Accepted)
        {
            InState.Admitted += 1;
            Record_Settle(InDrain, Piece, EMars_CookingFeed_Settle::Admitted);
            ck::Trace(f"[CookingFeed] [{InDrain.Feed.ToString()}] {PieceName} admitted ({InState.Admitted} admitted, {InState.Available} left)");
        }
        else
        {
            Restore_Slot(InState, Piece);
            Record_Settle(InDrain, Piece, EMars_CookingFeed_Settle::Rejected);
            ck::Trace(f"[CookingFeed] [{InDrain.Feed.ToString()}] {PieceName} rejected: {InRequest.Reason} ({InState.Available} left)");
        }

        InState.Active.Reset();
        InState.Phase = EMars_CookingFeed_Phase::Return;
        InState.PhaseSeconds = 0.0f;
    }

    private void Apply_Begin(FMars_CookingFeed_Drain& InDrain, FMars_Fragment_CookingFeed& InState)
    {
        if (InState.Phase != EMars_CookingFeed_Phase::Idle)
        {
            InDrain.Refusals.Add(EMars_CookingFeed_Refusal::Busy);
            return;
        }

        if (InState.Available <= 0)
        {
            InDrain.Refusals.Add(EMars_CookingFeed_Refusal::Empty);
            return;
        }

        if (ck::Is_NOT_Valid(InDrain.Feed.Get_ReleaseNode()))
        {
            InDrain.Refusals.Add(EMars_CookingFeed_Refusal::NoRelease);
            return;
        }

        // Available > 0 leaves a free slot: taken slots are the reservation and the admitted pieces only.
        const auto Slot = InState.SlotTaken.FindIndex(false);
        if (ck::EnsureIfNot(Slot >= 0, f"[CookingFeed] [{InDrain.Feed.ToString()}] has {InState.Available} pieces left but no free slot"))
        { return; }

        InState.SlotTaken[Slot] = true;
        InState.Active = TOptional<FMars_CookingFeed_PieceId>(FMars_CookingFeed_PieceId(InState.Generation, Slot));
        InState.Available -= 1;
        InState.Phase = EMars_CookingFeed_Phase::Reach;
        InState.PhaseSeconds = 0.0f;

        ck::Trace(f"[CookingFeed] [{InDrain.Feed.ToString()}] transfer of {utils_cooking_feed::Get_PieceName(InState.Active.GetValue())} started ({InState.Available} left)");
    }

    private void Restore_Slot(FMars_Fragment_CookingFeed& InState, const FMars_CookingFeed_PieceId& InPiece)
    {
        InState.Available += 1;
        if (InState.SlotTaken.IsValidIndex(InPiece.StockIndex))
        { InState.SlotTaken[InPiece.StockIndex] = false; }
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
        const auto Available = InState.Available;
        const auto Admitted = InState.Admitted;
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

        const auto StockMoved = Available != InDrain.StartAvailable || Admitted != InDrain.StartAdmitted;
        if (StockMoved && Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
        { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnStockChanged.Broadcast(Feed, Available, Admitted); }

        if (Phase != InDrain.StartPhase && Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
        { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnPhaseChanged.Broadcast(Feed, Phase); }
    }
}
