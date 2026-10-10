// What every step of one Searing's tick reads: the kernel, its spec, the pan's pose and heat, and the frame's real time.
struct FMars_Searing_Frame
{
    FCk_Handle_Searing Searing;
    FMars_Searing_Spec Spec;
    FTransform PanBaseWorld;
    FVector PanUp = FVector::UpVector;
    bool IsHot = false;
    float32 DeltaSeconds = 0.0f;
}

// One piece's edges this frame, broadcast once the whole tick applied (so a handler reads the written state).
struct FMars_Searing_PieceEvents
{
    FMars_CookingFeed_PieceId Id;
    FCk_Handle Entity;
    TOptional<EMars_Searing_Contact> Contact;
    bool Flipped = false;
    bool Lost = false;
    // Set when the face on the pan crossed a tenth: the face and the reported alpha.
    TOptional<float32> ProgressAlpha;
    EMars_Searing_Face ProgressFace = EMars_Searing_Face::NegZ;
    TOptional<EMars_Searing_Face> Seared;
    bool Ready = false;
}

// Every frame: the lingering lost bodies age (and are destroyed at LingerSeconds), then each live piece in admission order:
// whether it is on the pan (on/off edges), the face it rests on (flips), its loss, and the sear of its face on the pan
// (its sixth seared face makes it Ready); then the tally, the pieces' edges, and the aggregate sizzle edge last. The pan
// moves itself (an Implement); Jolt owns every piece's pose; the kernel reads it back through the entity transform and
// never writes it, and judges an adopted piece only once it has arrived at its release. Nothing is ever spawned here:
// pieces arrive only through AddPiece.
class UMars_Processor_Searing_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Searing);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Searing& InState)
    {
        auto Frame = FMars_Searing_Frame();
        Frame.Searing = InHandle.As_Searing();
        Frame.Spec = Frame.Searing.Get_Spec();
        Frame.PanBaseWorld = Frame.Searing.Get_PanBaseWorld();
        Frame.PanUp = Frame.PanBaseWorld.GetRotation().GetUpVector();
        Frame.IsHot = InState.Heat == EMars_Searing_Heat::Hot;
        Frame.DeltaSeconds = float32(InDeltaT.Get_Seconds());

        Advance_Lingering(Frame, InState);

        TArray<FMars_Searing_PieceEvents> Events;
        for (int32 Index = 0; Index < InState.Pieces.Num(); ++Index)
        {
            auto Piece = InState.Pieces[Index];
            // A lost piece only lingers; a piece whose entity is gone is going with a station torn down around it.
            if (Piece.Status == EMars_Searing_PieceStatus::Lost || ck::Is_NOT_Valid(Piece.Entity))
            { continue; }

            // An adopted piece is judged only once it is where it was released, or once it has taken too long to get there.
            if (Piece.Arriving.IsSet())
            {
                Piece.ArrivingSeconds += Frame.DeltaSeconds;
                if (utils_searing::Get_HasArrived(Piece.Body, Piece.Entity, Piece.Arriving.GetValue()) == false)
                {
                    if (Piece.ArrivingSeconds < utils_searing::k_ArrivalMaxSeconds)
                    {
                        InState.Pieces[Index] = Piece;
                        continue;
                    }

                    ck::EnsureIfNot(false, f"[Searing] [{Frame.Searing.ToString()}] piece {utils_cooking_feed::Get_PieceName(Piece.Id)} [{Piece.Entity.ToString()}] "
                        + f"never arrived at its release: {utils_searing::Get_ArrivalDistance(Piece.Entity, Piece.Arriving.GetValue())} cm away "
                        + f"after {Piece.ArrivingSeconds} s; judged where it is");
                }

                Piece.Arriving.Reset();
            }

            auto PieceEvents = FMars_Searing_PieceEvents();
            PieceEvents.Id = Piece.Id;
            PieceEvents.Entity = Piece.Entity;

            Advance_Contact(Frame, Piece, PieceEvents);
            Advance_RestingFace(Frame, Piece, PieceEvents);
            Advance_Loss(Frame, Piece, PieceEvents);
            Advance_Sear(Frame, Piece, PieceEvents);
            InState.Pieces[Index] = Piece;

            if (PieceEvents.Flipped)
            {
                InState.Tally.Flips += 1;
                ck::Trace(f"[Searing] [{Frame.Searing.ToString()}] piece {utils_cooking_feed::Get_PieceName(Piece.Id)} now rests on "
                    + f"{utils_searing::Get_FaceName(Piece.RestingFace)} (flips {InState.Tally.Flips})");
            }

            if (PieceEvents.Lost)
            {
                InState.Tally.Losses += 1;
                ck::Trace(f"[Searing] [{Frame.Searing.ToString()}] lost piece {utils_cooking_feed::Get_PieceName(Piece.Id)} "
                    + f"[{Piece.Entity.ToString()}] (losses {InState.Tally.Losses})");
            }

            Events.Add(PieceEvents);
        }

        Advance_Tally(Frame, InState);
        Broadcast_PieceEvents(Frame, InState, Events);
        Broadcast_SizzleEdge(Frame, InState);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Piece lifecycle
    //----------------------------------------------------------------------------------------------------------------------

    // A lost piece keeps simulating as a lingering body; at Loss.LingerSeconds it leaves the array and its entity is destroyed.
    // Nothing replaces it.
    private void Advance_Lingering(FMars_Searing_Frame& InFrame, FMars_Fragment_Searing& InState)
    {
        for (int32 Index = InState.Pieces.Num() - 1; Index >= 0; --Index)
        {
            auto Piece = InState.Pieces[Index];
            if (Piece.Status != EMars_Searing_PieceStatus::Lost)
            { continue; }

            Piece.LingerSeconds += InFrame.DeltaSeconds;
            if (Piece.LingerSeconds < InFrame.Spec.Loss.LingerSeconds)
            {
                InState.Pieces[Index] = Piece;
                continue;
            }

            InState.Pieces.RemoveAt(Index);

            // Already gone with a station torn down around it.
            if (ck::Is_NOT_Valid(Piece.Entity))
            { continue; }

            ck::Trace(f"[Searing] [{InFrame.Searing.ToString()}] destroyed lost piece {utils_cooking_feed::Get_PieceName(Piece.Id)} [{Piece.Entity.ToString()}]");
            utils_entity_lifetime::Request_DestroyEntity(Piece.Entity);
        }
    }

    // On the pan = the piece rests on the pan base (Resting) and its centre is over the disc. A Ready piece is tracked too
    // (it can be tossed off the pan and lost).
    private void Advance_Contact(FMars_Searing_Frame& InFrame, FMars_Searing_PieceState& InPiece, FMars_Searing_PieceEvents& OutEvents)
    {
        const auto IsOnPan = InPiece.Entity.As_Resting().Get_IsResting() && Get_IsOverDisc(InFrame, InPiece);
        const auto Contact = IsOnPan ? EMars_Searing_Contact::OnPan : EMars_Searing_Contact::Airborne;
        if (Contact == InPiece.Contact)
        { return; }

        InPiece.Contact = Contact;
        if (Contact == EMars_Searing_Contact::OnPan)
        { InPiece.LastProgressStep = -1; }

        OutEvents.Contact = Contact;
    }

    // A flip is a cooking piece's resting face changing: while on the pan, a down face other than the resting one that stays
    // down for k_FaceSettleSeconds becomes the resting face. Nothing is sampled at the on/off edges (a tumbling cube shows
    // passing faces there), and a tumble on the pan without leaving it counts too.
    private void Advance_RestingFace(FMars_Searing_Frame& InFrame, FMars_Searing_PieceState& InPiece, FMars_Searing_PieceEvents& OutEvents)
    {
        if (InPiece.Status != EMars_Searing_PieceStatus::Cooking || InPiece.Contact != EMars_Searing_Contact::OnPan)
        { return; }

        const auto Down = Get_DownFace(InFrame, InPiece);
        if (Down == InPiece.RestingFace)
        {
            InPiece.CandidateSeconds = 0.0f;
            return;
        }

        InPiece.CandidateSeconds += InFrame.DeltaSeconds;
        if (InPiece.CandidateSeconds < utils_searing::k_FaceSettleSeconds)
        { return; }

        InPiece.RestingFace = Down;
        InPiece.CandidateSeconds = 0.0f;
        OutEvents.Flipped = true;
    }

    // A piece (cooking or ready) whose middle left the disc (past PanRadius and its own reach, or more than
    // Loss.FallThroughCm below the cooking surface, whatever its thickness) is lost: it keeps simulating as a lingering body.
    private void Advance_Loss(FMars_Searing_Frame& InFrame, FMars_Searing_PieceState& InPiece, FMars_Searing_PieceEvents& OutEvents)
    {
        const auto Pose = Get_PanPose(InFrame, InPiece);
        const auto Local = Pose.GetLocation();
        const auto AboveTop = Local.Z - utils_searing::k_PanSurfaceZ;
        const auto OffTheDisc = Local.Size2D() > InFrame.Spec.Loss.PanRadius + utils_searing::Get_RadialExtent(InPiece.HalfExtents);
        const auto FellThrough = AboveTop < -InFrame.Spec.Loss.FallThroughCm;
        if (OffTheDisc == false && FellThrough == false)
        { return; }

        ck::Trace(f"[Searing] [{InFrame.Searing.ToString()}] piece {utils_cooking_feed::Get_PieceName(InPiece.Id)} leaves the pan: "
            + f"radius {Local.Size2D() :.2} (off the disc {OffTheDisc}), {AboveTop :.3} cm above the surface (fell through {FellThrough})");

        InPiece.Status = EMars_Searing_PieceStatus::Lost;
        InPiece.LingerSeconds = 0.0f;
        InPiece.LastProgressStep = -1;
        OutEvents.Lost = true;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Ledger
    //----------------------------------------------------------------------------------------------------------------------

    // A cooking piece's face on a hot pan sears toward 1 (never past it). Progress is reported at tenths, each face once at
    // 1, and the sixth seared face makes the piece Ready (the others keep cooking).
    private void Advance_Sear(FMars_Searing_Frame& InFrame, FMars_Searing_PieceState& InPiece, FMars_Searing_PieceEvents& OutEvents)
    {
        if (InFrame.IsHot == false
            || InPiece.Status != EMars_Searing_PieceStatus::Cooking
            || InPiece.Contact != EMars_Searing_Contact::OnPan)
        { return; }

        const auto Face = Get_DownFace(InFrame, InPiece);
        const auto Index = int32(Face);
        const auto Before = InPiece.FaceSear[Index];
        const auto After = Math::Min(1.0f, Before + InFrame.DeltaSeconds / InFrame.Spec.Cook.SecondsPerFace);
        InPiece.FaceSear[Index] = After;

        const auto Step = Math::FloorToInt(After * float32(utils_searing::k_SearSignalSteps));
        if (Step != InPiece.LastProgressStep)
        {
            InPiece.LastProgressStep = Step;
            OutEvents.ProgressFace = Face;
            OutEvents.ProgressAlpha = TOptional<float32>(float32(Step) / float32(utils_searing::k_SearSignalSteps));
        }

        if (Before >= 1.0f || After < 1.0f)
        { return; }

        OutEvents.Seared = TOptional<EMars_Searing_Face>(Face);
        if (utils_searing::Get_SearedFaceCount(InPiece.FaceSear) < utils_searing::k_FaceCount)
        { return; }

        InPiece.Status = EMars_Searing_PieceStatus::Ready;
        OutEvents.Ready = true;
    }

    // Seconds while hot and any piece is cooking.
    private void Advance_Tally(FMars_Searing_Frame& InFrame, FMars_Fragment_Searing& InState)
    {
        if (InFrame.IsHot == false)
        { return; }

        for (const auto& Piece : InState.Pieces)
        {
            if (Piece.Status == EMars_Searing_PieceStatus::Cooking)
            {
                InState.Tally.Seconds += InFrame.DeltaSeconds;
                return;
            }
        }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Broadcasts
    //----------------------------------------------------------------------------------------------------------------------

    // Per piece, in admission order: contact, progress, seared face, ready, lost.
    private void Broadcast_PieceEvents(FMars_Searing_Frame& InFrame, const FMars_Fragment_Searing& InState,
        const TArray<FMars_Searing_PieceEvents>& InEvents)
    {
        for (const auto& Event : InEvents)
        {
            const auto PieceName = utils_cooking_feed::Get_PieceName(Event.Id);
            if (Event.Seared.IsSet())
            { ck::Trace(f"[Searing] [{InFrame.Searing.ToString()}] piece {PieceName} face {utils_searing::Get_FaceName(Event.Seared.GetValue())} seared"); }

            if (Event.Ready)
            {
                ck::Trace(f"[Searing] [{InFrame.Searing.ToString()}] piece {PieceName} ready ({InState.Tally.Seconds :.2} s hot, "
                    + f"{InState.Tally.Losses} lost, {InState.Tally.Flips} flips)");
            }
        }

        if (InFrame.Searing.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
        { return; }

        // The signals fragment is fetched per broadcast: a handler may compose fragments while it runs.
        auto Searing = InFrame.Searing;
        for (const auto& Event : InEvents)
        {
            if (Event.Contact.IsSet())
            { Searing.Get_Fragment(FMars_Fragment_Searing_Signals).OnPanContactChanged.Broadcast(Searing, Event.Id, Event.Contact.GetValue()); }

            if (Event.ProgressAlpha.IsSet())
            {
                Searing.Get_Fragment(FMars_Fragment_Searing_Signals).OnSearProgress.Broadcast(
                    Searing, Event.Id, Event.ProgressFace, Event.ProgressAlpha.GetValue());
            }

            if (Event.Seared.IsSet())
            { Searing.Get_Fragment(FMars_Fragment_Searing_Signals).OnFaceSeared.Broadcast(Searing, Event.Id, Event.Seared.GetValue()); }

            if (Event.Ready)
            { Searing.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceReady.Broadcast(Searing, Event.Id, InState.Tally); }

            if (Event.Lost)
            { Searing.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceLost.Broadcast(Searing, Event.Id, Event.Entity); }
        }
    }

    // Aggregate: Sizzling while hot and any cooking piece lies on the pan on a face not yet seared; edges only.
    private void Broadcast_SizzleEdge(FMars_Searing_Frame& InFrame, FMars_Fragment_Searing& InState)
    {
        auto IsSizzling = false;
        if (InFrame.IsHot)
        {
            for (const auto& Piece : InState.Pieces)
            {
                if (Piece.Status != EMars_Searing_PieceStatus::Cooking || Piece.Contact != EMars_Searing_Contact::OnPan
                    || ck::Is_NOT_Valid(Piece.Entity))
                { continue; }

                if (Piece.FaceSear[int32(Get_DownFace(InFrame, Piece))] < 1.0f)
                {
                    IsSizzling = true;
                    break;
                }
            }
        }

        const auto Now = IsSizzling ? EMars_Searing_Sizzle::Sizzling : EMars_Searing_Sizzle::Quiet;
        if (Now == InState.Sizzle)
        { return; }

        InState.Sizzle = Now;
        if (InFrame.Searing.Has_Fragment(FMars_Fragment_Searing_Signals))
        { InFrame.Searing.Get_Fragment(FMars_Fragment_Searing_Signals).OnSizzleChanged.Broadcast(InFrame.Searing, Now); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Piece geometry (as of the last transform update)
    //----------------------------------------------------------------------------------------------------------------------

    // The piece's middle and rotation in the pan base body's frame.
    private FTransform Get_PanPose(const FMars_Searing_Frame& InFrame, const FMars_Searing_PieceState& InPiece) const
    {
        const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(InPiece.Entity.As_Transform());
        return utils_searing::Get_CentreFrame(PieceWorld.GetRelativeTransform(InFrame.PanBaseWorld), InPiece.CentreLocal);
    }

    private EMars_Searing_Face Get_DownFace(const FMars_Searing_Frame& InFrame, const FMars_Searing_PieceState& InPiece) const
    {
        const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(InPiece.Entity.As_Transform());
        return utils_searing::Get_DownFace(PieceWorld.GetRotation(), InFrame.PanUp);
    }

    // The piece's middle, in the pan base's frame, within PanRadius of the axis and between Loss.FallThroughCm below (a thin
    // slice sunk into the pan's surface still lies on it) and three half heights above the cooking surface (a piece hovering
    // over the pan is not on it).
    private bool Get_IsOverDisc(const FMars_Searing_Frame& InFrame, const FMars_Searing_PieceState& InPiece) const
    {
        const auto Pose = Get_PanPose(InFrame, InPiece);
        const auto Local = Pose.GetLocation();
        const auto AboveTop = Local.Z - utils_searing::k_PanSurfaceZ;
        const auto HalfHeight = utils_searing::Get_WorldHalfExtentZ(Pose.GetRotation(), InPiece.HalfExtents);
        return Local.Size2D() <= InFrame.Spec.Loss.PanRadius && AboveTop >= -InFrame.Spec.Loss.FallThroughCm
            && AboveTop <= 3.0 * HalfHeight;
    }
}
