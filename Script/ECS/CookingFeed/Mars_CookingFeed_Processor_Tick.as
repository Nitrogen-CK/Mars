// What every step of one feed's tick reads: the feed, its spec and the frame's real time.
struct FMars_CookingFeed_Frame
{
    FCk_Handle_CookingFeed Feed;
    FMars_CookingFeed_Spec Spec;
    float32 DeltaSeconds = 0.0f;
}

// The one clock of the transfer. First it guards the reservation: before the release, a reserved piece that is gone or no
// longer on the source (unloaded by someone, the platter swapped under it) cancels the transfer as a Cancel would. Every
// positive-dt frame it measures the release node's world velocity; while the hand is in a timed phase it advances the phase
// time and crosses every boundary the frame reaches, each once and in order (a long frame crosses several, a zero-length
// phase passes through), carrying the remainder into the next phase. Carry's end samples the release (the reserved piece,
// the node's pose this frame, the spec's local velocity rotated to the node plus the inherited node velocity) and waits for
// the admission answer; Return's end idles the hand. AwaitAdmission has no clock. Last, the stock is compared with what was
// last broadcast: the source changes under the feed without a request, so its edges are found here.
class UMars_Processor_CookingFeed_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_CookingFeed);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_CookingFeed& InState)
    {
        auto Frame = FMars_CookingFeed_Frame();
        Frame.Feed = InHandle.As_CookingFeed();
        Frame.Spec = Frame.Feed.Get_Spec();
        Frame.DeltaSeconds = float32(InDeltaT.Get_Seconds());

        Guard_Reservation(Frame, InState);
        Measure_Release(Frame, InState);
        Advance_Phase(Frame, InState);
        Broadcast_StockIfChanged(Frame, InState);
    }

    // From Reach through Carry the reserved piece must still be on the source. In AwaitAdmission it is off the platter by
    // design (control unloaded it for the release) and only an answer or a Cancel ends the transfer.
    private void Guard_Reservation(FMars_CookingFeed_Frame& InFrame, FMars_Fragment_CookingFeed& InState)
    {
        const auto IsBeforeRelease = InState.Phase == EMars_CookingFeed_Phase::Reach || InState.Phase == EMars_CookingFeed_Phase::Grasp
            || InState.Phase == EMars_CookingFeed_Phase::Carry;
        if (InState.Active.IsSet() == false || IsBeforeRelease == false)
        { return; }

        const auto Reservation = InState.Active.GetValue();
        if (utils_cooking_feed::Get_IsOnSource(Reservation.Piece, InState.Source))
        { return; }

        utils_cooking_feed::Cancel_Active(InState);
        ck::Trace(f"[CookingFeed] [{InFrame.Feed.ToString()}] {utils_cooking_feed::Get_PieceName(Reservation.Id)} [{Reservation.Piece.ToString()}] left the source before its release: transfer cancelled");

        auto Feed = InFrame.Feed;
        if (Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
        { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnTransferSettled.Broadcast(Feed, Reservation.Id, EMars_CookingFeed_Settle::Cancelled); }

        if (Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
        { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnPhaseChanged.Broadcast(Feed, EMars_CookingFeed_Phase::Idle); }
    }

    // A zero-dt frame cannot estimate motion: it leaves the last velocity and pose.
    private void Measure_Release(FMars_CookingFeed_Frame& InFrame, FMars_Fragment_CookingFeed& InState)
    {
        if (InFrame.DeltaSeconds <= 0.0f || ck::Is_NOT_Valid(InFrame.Spec.Nodes.Release))
        { return; }

        const auto Now = utils_transform::Get_EntityCurrentTransform(InFrame.Spec.Nodes.Release);
        if (InState.ReleasePrevWorld.IsSet())
        {
            const auto Previous = InState.ReleasePrevWorld.GetValue();
            InState.ReleaseVelocity = (Now.GetLocation() - Previous.GetLocation()) / float64(InFrame.DeltaSeconds);
        }

        InState.ReleasePrevWorld = TOptional<FTransform>(Now);
    }

    private void Advance_Phase(FMars_CookingFeed_Frame& InFrame, FMars_Fragment_CookingFeed& InState)
    {
        if (utils_cooking_feed::Get_IsTimed(InState.Phase) == false)
        { return; }

        InState.PhaseSeconds += InFrame.DeltaSeconds;

        auto Entered = TArray<EMars_CookingFeed_Phase>();
        auto Released = false;
        while (utils_cooking_feed::Get_IsTimed(InState.Phase))
        {
            const auto Duration = utils_cooking_feed::Get_PhaseDuration(InFrame.Spec.Timing, InState.Phase);
            if (InState.PhaseSeconds < Duration)
            { break; }

            InState.PhaseSeconds -= Duration;
            if (InState.Phase == EMars_CookingFeed_Phase::Carry)
            { Released = Sample_Release(InFrame, InState); }

            InState.Phase = Get_NextPhase(InState.Phase);
            Entered.Add(InState.Phase);
        }

        if (utils_cooking_feed::Get_IsTimed(InState.Phase) == false)
        { InState.PhaseSeconds = 0.0f; }

        if (Entered.Num() == 0)
        { return; }

        const auto Release = InState.PendingRelease;
        ck::Trace(f"[CookingFeed] [{InFrame.Feed.ToString()}] hand -> {InState.Phase :n} ({Entered.Num()} boundary(ies) this frame)");

        auto Feed = InFrame.Feed;
        for (const auto Phase : Entered)
        {
            if (Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
            { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnPhaseChanged.Broadcast(Feed, Phase); }
        }

        if (Released && Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
        { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnReleaseRequested.Broadcast(Feed, Release); }
    }

    // The release at Carry's end, kept in PendingRelease. False (and nothing kept) without a reservation, which Carry always
    // has.
    private bool Sample_Release(FMars_CookingFeed_Frame& InFrame, FMars_Fragment_CookingFeed& InState)
    {
        if (ck::EnsureIfNot(InState.Active.IsSet(), f"[CookingFeed] [{InFrame.Feed.ToString()}] reached the release with no reserved piece"))
        { return false; }

        const auto Reservation = InState.Active.GetValue();
        const auto ReleaseWorld = utils_transform::Get_EntityCurrentTransform(InFrame.Spec.Nodes.Release);
        const auto& Motion = InFrame.Spec.Motion;
        const auto Velocity = ReleaseWorld.GetRotation().RotateVector(Motion.ReleaseVelocityLocal)
            + InState.ReleaseVelocity * float64(Motion.VelocityInheritance);

        InState.PendingRelease = FMars_CookingFeed_Release(Reservation.Id, ReleaseWorld, Velocity, Reservation.Id.StockIndex);
        InState.PendingRelease.Piece = Reservation.Piece;

        ck::Trace(f"[CookingFeed] [{InFrame.Feed.ToString()}] released {utils_cooking_feed::Get_PieceName(Reservation.Id)} [{Reservation.Piece.ToString()}] at {ReleaseWorld.GetLocation()} moving {Velocity}");
        return true;
    }

    // One broadcast per edge of (Available, Admitted), after every other step of the frame.
    private void Broadcast_StockIfChanged(FMars_CookingFeed_Frame& InFrame, FMars_Fragment_CookingFeed& InState)
    {
        const auto Available = utils_cooking_feed::Get_Available(InState);
        const auto Admitted = InState.Admitted;
        if (Available == InState.LastStockAvailable && Admitted == InState.LastStockAdmitted)
        { return; }

        InState.LastStockAvailable = Available;
        InState.LastStockAdmitted = Admitted;
        ck::Trace(f"[CookingFeed] [{InFrame.Feed.ToString()}] stock: {Available} available, {Admitted} admitted");

        auto Feed = InFrame.Feed;
        if (Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
        { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnStockChanged.Broadcast(Feed, Available, Admitted); }
    }

    private EMars_CookingFeed_Phase Get_NextPhase(EMars_CookingFeed_Phase InPhase) const
    {
        switch (InPhase)
        {
            case EMars_CookingFeed_Phase::Reach: return EMars_CookingFeed_Phase::Grasp;
            case EMars_CookingFeed_Phase::Grasp: return EMars_CookingFeed_Phase::Carry;
            case EMars_CookingFeed_Phase::Carry: return EMars_CookingFeed_Phase::AwaitAdmission;
            default: return EMars_CookingFeed_Phase::Idle;
        }
    }
}
