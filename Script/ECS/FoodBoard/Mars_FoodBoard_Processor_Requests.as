struct FMars_FoodBoard_PlaceRefused
{
    FCk_Handle_FoodPiece Piece;
    EMars_FoodBoard_PlaceRefusal Refusal = EMars_FoodBoard_PlaceRefusal::Full;

    FMars_FoodBoard_PlaceRefused() {}

    FMars_FoodBoard_PlaceRefused(FCk_Handle_FoodPiece InPiece, EMars_FoodBoard_PlaceRefusal InRefusal)
    {
        Piece = InPiece;
        Refusal = InRefusal;
    }
}

// A held piece a chop may cut: its world frame, and how far its centroid is from the plane's position.
struct FMars_FoodBoard_CutCandidate
{
    FCk_Handle_FoodPiece Piece;
    FTransform World;
    float DistanceCm = 0.0;
}

// What one drain did, broadcast once every request is applied.
struct FMars_FoodBoard_Drain
{
    FCk_Handle_FoodBoard Board;
    bool Cleared = false;
    TArray<FMars_Request_FoodBoard_ResolveCut> PieceCuts;
    // The board was parted this drain: its pieces' moves land after it (FGroup_Transform).
    bool Parted = false;
    // Waiting chops (or a waiting sweep) were re-queued this drain: anything newer goes behind them.
    bool Flushed = false;
    TArray<FCk_Handle_FoodPiece> Placed;
    TArray<FMars_FoodBoard_PlaceRefused> Refused;
    TArray<FMars_FoodBoard_CutIssue> CutIssues;
    TArray<FCk_Handle_FoodPiece> Released;
}

// Drains Clear -> ResolveCut -> (parting) -> Place -> Cut -> Release, then broadcasts in that order. Pieces destroyed
// elsewhere leave the ledger after the resolutions, so a cut source (destroyed by its own commit) is still found by its
// ResolveCut. The board parts only when quiet (Apply_Parting). Chops never cut poses a parting is about to move: while a
// parting is owed (a committed cut waits for others in flight) they wait on the board state; a drain that parted, or
// re-queued waiting chops, hands this drain's chops to the next pass, behind the waiting ones. A sweep queued with a chop
// that waits or moves on waits or moves on with it.
//
// It is also the board's only listener: every held piece's OnCutResolved (each becomes a ResolveCut on the board, drained
// the same frame because RuntimeMesh resolves slices in FGroup_Gameplay; a Cut replaces the piece with its halves, any other
// outcome leaves it whole and free for the next chop) and the board's own destruction (held pieces end with it; released
// pieces live on). It never writes a FoodPiece fragment.
class UMars_Processor_FoodBoard_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_FoodBoard_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_FoodBoard);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_FoodBoard_Requests& InRequests,
                       FMars_Fragment_FoodBoard& InState)
    {
        auto Drain = FMars_FoodBoard_Drain();
        Drain.Board = InHandle.As_FoodBoard();

        const auto HasClear = InRequests.ClearRequests.Num() > 0;
        TArray<FMars_Request_FoodBoard_ResolveCut> ResolveCutRequests = InRequests.ResolveCutRequests;
        TArray<FMars_Request_FoodBoard_Place> PlaceRequests = InRequests.PlaceRequests;
        TArray<FMars_Request_FoodBoard_Cut> CutRequests = InRequests.CutRequests;
        TArray<FMars_Request_FoodBoard_Release> ReleaseRequests = InRequests.ReleaseRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Drain.Board.Request_TryRemove(FMars_Fragment_FoodBoard_Requests);

        if (HasClear)
        { Apply_Clear(Drain, InState); }

        for (const auto& Request : ResolveCutRequests)
        { Apply_ResolveCut(Drain, InState, Request); }

        Drop_Gone(Drain, InState);
        Apply_Parting(Drain, InState);

        for (const auto& Request : PlaceRequests)
        { Apply_Place(Drain, InState, Request); }

        const auto HasChops = CutRequests.Num() > 0 || InState.WaitingCuts.Num() > 0;
        if (InState.Unparted.Num() > 0 && HasChops)
        {
            InState.WaitingCuts.Append(CutRequests);
            InState.WaitingReleases.Append(ReleaseRequests);
            if (CutRequests.Num() > 0)
            { ck::Trace(f"[FoodBoard] [{Drain.Board.ToString()}] {CutRequests.Num()} chop(s) wait for the cuts in flight ({InState.WaitingCuts.Num()} waiting)"); }
        }
        else if ((Drain.Parted && CutRequests.Num() > 0) || Drain.Flushed)
        {
            auto& Next = Drain.Board.AddOrGet_Fragment(FMars_Fragment_FoodBoard_Requests);
            Next.CutRequests.Append(CutRequests);
            Next.ReleaseRequests.Append(ReleaseRequests);
        }
        else
        {
            for (const auto& Request : CutRequests)
            { Apply_Cut(Drain, InState, Request); }

            for (const auto& Request : ReleaseRequests)
            { Apply_Release(Drain, InState, Request); }
        }

        Broadcast(Drain);
    }

    // Held pieces are the board's to end; released ones are not. A chop still waiting has nothing left to cut: it knocks.
    private void Apply_Clear(FMars_FoodBoard_Drain& InDrain, FMars_Fragment_FoodBoard& InState)
    {
        const TArray<FCk_Handle_FoodPiece> Held = InState.Held;
        InState.Held.Empty();
        InState.IsUntouched = true;
        InState.Unparted.Empty();
        InDrain.Cleared = true;

        for (const auto& Piece : Held)
        { utils_entity_lifetime::Request_DestroyEntity(Piece); }

        for (int32 Index = 0; Index < InState.WaitingCuts.Num(); ++Index)
        { InDrain.CutIssues.Add(FMars_FoodBoard_CutIssue()); }

        const auto Knocked = InState.WaitingCuts.Num();
        InState.WaitingCuts.Empty();
        InState.WaitingReleases.Empty();

        ck::Trace(f"[FoodBoard] [{InDrain.Board.ToString()}] cleared: {Held.Num()} held piece(s) destroyed, {InState.Released.Num()} released kept, {Knocked} waiting chop(s) knocked");
    }

    // A cut that did not commit leaves its piece held and whole. A committed cut's halves take the source's index (positive
    // first) and are stamped and watched like any held piece; its plane waits in Unparted for the board to go quiet. A source
    // no longer held was cleared after its cut was submitted: nothing of that cut may reach the board.
    private void Apply_ResolveCut(FMars_FoodBoard_Drain& InDrain, FMars_Fragment_FoodBoard& InState,
                                  const FMars_Request_FoodBoard_ResolveCut& InRequest)
    {
        if (InRequest.Outcome != EMars_FoodPiece_CutOutcome::Cut)
        {
            ck::Trace(f"[FoodBoard] [{InDrain.Board.ToString()}] [{InRequest.Source.ToString()}] cut {InRequest.Outcome :n}: it stays held, whole");
            return;
        }

        const auto Index = utils_foodboard::Find_Piece(InState.Held, InRequest.Source);
        if (Index < 0)
        {
            ck::Trace(f"[FoodBoard] [{InDrain.Board.ToString()}] the cut of [{InRequest.Source.ToString()}] committed after it left the board: its halves are destroyed");
            Destroy_Halves(InRequest);
            return;
        }

        const auto HalvesAreLive = ck::IsValid(InRequest.Positive) && ck::IsValid(InRequest.Negative);
        if (ck::EnsureIfNot(HalvesAreLive, f"[FoodBoard] [{InDrain.Board.ToString()}] the cut of [{InRequest.Source.ToString()}] handed over a dead half"))
        {
            InState.Held.RemoveAt(Index);
            Destroy_Halves(InRequest);
            return;
        }

        auto Positive = InRequest.Positive;
        auto Negative = InRequest.Negative;
        InState.Held[Index] = Positive;
        InState.Held.Insert(Negative, Index + 1);
        InState.IsUntouched = false;

        Admit(InDrain.Board, Positive);
        Admit(InDrain.Board, Negative);

        InDrain.PieceCuts.Add(InRequest);

        if (InRequest.Plane.IsSet())
        { Add_Unparted(InState, InRequest.Plane.GetValue()); }

        ck::Trace(f"[FoodBoard] [{InDrain.Board.ToString()}] [{InRequest.Source.ToString()}] cut into [{Positive.ToString()}] and [{Negative.ToString()}] ({InState.Held.Num()} held)");
    }

    // One entry per distinct plane: a chop that cut several pieces, or two chops along one plane, part the board once.
    private void Add_Unparted(FMars_Fragment_FoodBoard& InState, const FMars_FoodPiece_WorldPlane& InPlane)
    {
        for (const auto& Plane : InState.Unparted)
        {
            if (utils_foodboard::Get_IsSamePlane(Plane, InPlane))
            { return; }
        }

        InState.Unparted.Add(InPlane);
    }

    // The board parts once it is quiet: no cut it submitted is still in flight. Then every held piece moves SeparationCm / 2
    // away from each unparted plane on its centroid's side, the newest halves included, so each cut opens a gap and every
    // earlier gap keeps its width. Waiting for quiet is what makes a chop whose cuts commit over several frames (RuntimeMesh
    // slices two per frame) part once, and keeps every piece still at its blade until its own cut lands. Classifying by the
    // pre-move poses is sound: no piece moves farther than a fraction of a gap. The chops that waited go next.
    private void Apply_Parting(FMars_FoodBoard_Drain& InDrain, FMars_Fragment_FoodBoard& InState)
    {
        if (InState.Unparted.Num() == 0)
        { return; }

        for (const auto& Piece : InState.Held)
        {
            if (Piece.Get_HasBoardCutPending())
            { return; }
        }

        const TArray<FMars_FoodPiece_WorldPlane> Planes = InState.Unparted;
        InState.Unparted.Empty();
        Flush_Waiting(InDrain, InState);

        const auto HalfSeparationCm = 0.5 * float(InDrain.Board.Get_Tuners().SeparationCm);
        if (HalfSeparationCm <= 0.0)
        { return; }

        for (const auto& Plane : Planes)
        {
            for (const auto& Piece : InState.Held)
            {
                if (utils_runtime_mesh::Get_SetupState(Piece.Get_Geometry()) != ECk_RuntimeMesh_SetupState::Ready)
                { continue; }

                FCk_Handle Entity = Piece;
                const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
                const auto Centroid = PieceWorld.TransformPosition(utils_runtime_mesh::Get_Metrics(Piece.Get_Geometry()).Get_CentroidCm());
                const auto Side = (Centroid - Plane.PositionCm).DotProduct(Plane.Normal) >= 0.0 ? 1.0 : -1.0;
                Offset(Piece, Plane.Normal * (Side * HalfSeparationCm));
            }
        }

        InDrain.Parted = true;
        ck::Trace(f"[FoodBoard] [{InDrain.Board.ToString()}] parted along {Planes.Num()} cut plane(s) ({InState.Held.Num()} held)");
    }

    // The waiting chops (and the sweeps behind them) go back on the queue, oldest first, ahead of anything this drain adds;
    // the next pass applies them, after the parting moves have landed.
    private void Flush_Waiting(FMars_FoodBoard_Drain& InDrain, FMars_Fragment_FoodBoard& InState)
    {
        if (InState.WaitingCuts.Num() == 0 && InState.WaitingReleases.Num() == 0)
        { return; }

        auto& Next = InDrain.Board.AddOrGet_Fragment(FMars_Fragment_FoodBoard_Requests);
        Next.CutRequests.Append(InState.WaitingCuts);
        Next.ReleaseRequests.Append(InState.WaitingReleases);

        ck::Trace(f"[FoodBoard] [{InDrain.Board.ToString()}] the board is quiet: {InState.WaitingCuts.Num()} waiting chop(s) go next");

        InState.WaitingCuts.Empty();
        InState.WaitingReleases.Empty();
        InDrain.Flushed = true;
    }

    // A piece destroyed elsewhere is no longer the board's to cut, release or clear.
    private void Drop_Gone(FMars_FoodBoard_Drain& InDrain, FMars_Fragment_FoodBoard& InState)
    {
        const auto Dropped = Remove_Gone(InState.Held) + Remove_Gone(InState.Released);
        if (Dropped > 0)
        { ck::Trace(f"[FoodBoard] [{InDrain.Board.ToString()}] dropped {Dropped} piece(s) destroyed elsewhere"); }
    }

    private void Apply_Place(FMars_FoodBoard_Drain& InDrain, FMars_Fragment_FoodBoard& InState, const FMars_Request_FoodBoard_Place& InRequest)
    {
        auto Piece = InRequest.Piece;
        const auto Refusal = Get_PlaceRefusal(InDrain.Board, Piece);
        if (Refusal.IsSet())
        {
            ck::Trace(f"[FoodBoard] [{InDrain.Board.ToString()}] refused [{Piece.ToString()}]: {Refusal.GetValue() :n}");
            InDrain.Refused.Add(FMars_FoodBoard_PlaceRefused(Piece, Refusal.GetValue()));
            return;
        }

        InState.IsUntouched = InState.Held.Num() == 0;
        InState.Held.Add(Piece);
        Admit(InDrain.Board, Piece);
        Watch_Teardown(InDrain.Board);
        InDrain.Placed.Add(Piece);

        ck::Trace(f"[FoodBoard] [{InDrain.Board.ToString()}] placed [{Piece.ToString()}] ({InState.Held.Num()} held)");
    }

    private TOptional<EMars_FoodBoard_PlaceRefusal> Get_PlaceRefusal(const FCk_Handle_FoodBoard& InBoard, const FCk_Handle_FoodPiece& InPiece)
    {
        if (Get_IsGone(InPiece))
        { return TOptional<EMars_FoodBoard_PlaceRefusal>(EMars_FoodBoard_PlaceRefusal::Gone); }

        const auto Holder = InPiece.TryGet_FoodBoard();
        if (Holder == InBoard)
        { return TOptional<EMars_FoodBoard_PlaceRefusal>(EMars_FoodBoard_PlaceRefusal::AlreadyHeld); }

        if (ck::IsValid(Holder))
        { return TOptional<EMars_FoodBoard_PlaceRefusal>(EMars_FoodBoard_PlaceRefusal::HeldElsewhere); }

        FCk_Handle Entity = InPiece;
        if (Entity.Is_JoltBody())
        { return TOptional<EMars_FoodBoard_PlaceRefusal>(EMars_FoodBoard_PlaceRefusal::Loose); }

        if (InBoard.Get_Occupancy() >= InBoard.Get_Tuners().MaxHeldPieces)
        { return TOptional<EMars_FoodBoard_PlaceRefusal>(EMars_FoodBoard_PlaceRefusal::Full); }

        return TOptional<EMars_FoodBoard_PlaceRefusal>();
    }

    // Candidates are the held pieces free to cut whose bounds the plane straddles. The budget is MaxCutsPerChop, capped by the
    // room MaxHeldPieces leaves once every cut in flight has added its second half. Nearest centroids to the plane's position
    // go first; past the budget the chop only knocks.
    private void Apply_Cut(FMars_FoodBoard_Drain& InDrain, FMars_Fragment_FoodBoard& InState, const FMars_Request_FoodBoard_Cut& InRequest)
    {
        auto Issue = FMars_FoodBoard_CutIssue();
        const auto Plane = utils_foodboard::Get_UnitPlane(InRequest.Plane);
        if (ck::EnsureIfNot(Plane.IsSet(), f"[FoodBoard] [{InDrain.Board.ToString()}] was asked to cut along a degenerate plane (position {InRequest.Plane.PositionCm}, normal {InRequest.Plane.Normal})"))
        {
            InDrain.CutIssues.Add(Issue);
            return;
        }

        auto Candidates = Find_Candidates(InState.Held, Plane.GetValue());
        const auto Tuners = InDrain.Board.Get_Tuners();
        Issue.Straddling = Candidates.Num();
        Issue.Budget = Math::Max(0, Math::Min(Tuners.MaxCutsPerChop, Tuners.MaxHeldPieces - InDrain.Board.Get_Occupancy()));

        for (int32 Attempt = 0; Attempt < Issue.Budget && Candidates.Num() > 0; ++Attempt)
        {
            const auto Candidate = Take_Nearest(Candidates);
            if (Submit_Cut(Candidate, Plane.GetValue()))
            { ++Issue.Issued; }
        }

        InDrain.CutIssues.Add(Issue);

        ck::Trace(f"[FoodBoard] [{InDrain.Board.ToString()}] chop: {Issue.Straddling} straddling, budget {Issue.Budget}, {Issue.Issued} cut(s) issued");
    }

    private TArray<FMars_FoodBoard_CutCandidate> Find_Candidates(const TArray<FCk_Handle_FoodPiece>& InHeld, const FMars_FoodPiece_WorldPlane& InPlane)
    {
        TArray<FMars_FoodBoard_CutCandidate> Candidates;
        for (const auto& Piece : InHeld)
        {
            if (Get_IsFree(Piece) == false)
            { continue; }

            FCk_Handle Entity = Piece;
            const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
            const auto Metrics = utils_runtime_mesh::Get_Metrics(Piece.Get_Geometry());
            if (utils_foodboard::Get_IsStraddling(PieceWorld, Metrics, InPlane) == false)
            { continue; }

            auto Candidate = FMars_FoodBoard_CutCandidate();
            Candidate.Piece = Piece;
            Candidate.World = PieceWorld;
            Candidate.DistanceCm = (PieceWorld.TransformPosition(Metrics.Get_CentroidCm()) - InPlane.PositionCm).Size();
            Candidates.Add(Candidate);
        }

        return Candidates;
    }

    private FMars_FoodBoard_CutCandidate Take_Nearest(TArray<FMars_FoodBoard_CutCandidate>& InOutCandidates)
    {
        auto Nearest = 0;
        for (int32 Index = 1; Index < InOutCandidates.Num(); ++Index)
        {
            if (InOutCandidates[Index].DistanceCm < InOutCandidates[Nearest].DistanceCm)
            { Nearest = Index; }
        }

        const auto Candidate = InOutCandidates[Nearest];
        InOutCandidates.RemoveAt(Nearest);
        return Candidate;
    }

    // The pending normal is set before the piece drains its cut, so a second chop in this drain already skips it and already
    // counts its second half. A scaled piece frame has no local plane (Get_LocalPlane ensured): no cut.
    private bool Submit_Cut(const FMars_FoodBoard_CutCandidate& InCandidate, const FMars_FoodPiece_WorldPlane& InPlane)
    {
        const auto LocalPlane = utils_foodpiece::Get_LocalPlane(InCandidate.World, InPlane);
        if (LocalPlane.IsSet() == false)
        { return false; }

        auto Piece = InCandidate.Piece;
        auto& Membership = Piece.Get_Fragment(FMars_Fragment_FoodBoard_Membership);
        Membership.PendingCutPlane = TOptional<FMars_FoodPiece_WorldPlane>(InPlane);
        Piece.Request_Cut(FMars_Request_FoodPiece_Cut(LocalPlane.GetValue()));
        return true;
    }

    // Every held piece free to move leaves, in held order, until MaxPieces have left. A piece still cutting (or not Ready),
    // or past the cap, stays held, so the halves of a cut in flight land on the board. Loose: the piece gets a dynamic convex
    // body of its own mesh and mass and the board's release velocity, and moves to the end of Released; past
    // MaxReleasedPieces the oldest released pieces are destroyed. Handoff: the piece is only let go, where it lies.
    private void Apply_Release(FMars_FoodBoard_Drain& InDrain, FMars_Fragment_FoodBoard& InState, const FMars_Request_FoodBoard_Release& InRequest)
    {
        const auto Tuners = InDrain.Board.Get_Tuners();
        FCk_Handle BoardEntity = InDrain.Board;
        const auto BoardWorld = utils_transform::Get_EntityCurrentTransform(BoardEntity.As_Transform());
        const auto Velocity = BoardWorld.GetRotation().RotateVector(Tuners.Release.VelocityLocal);
        const auto IsLoose = InRequest.Mode == EMars_FoodBoard_ReleaseMode::Loose;

        TArray<FCk_Handle_FoodPiece> StillHeld;
        auto ReleasedCount = 0;
        for (const auto& Held : InState.Held)
        {
            auto Piece = Held;
            const auto IsCapped = InRequest.MaxPieces.IsSet() && ReleasedCount >= InRequest.MaxPieces.GetValue();
            if (IsCapped || Get_IsFree(Piece) == false)
            {
                StillHeld.Add(Piece);
                continue;
            }

            if (IsLoose)
            {
                Loosen(Piece, Tuners.Release, Velocity);
                InState.Released.Add(Piece);
            }
            else
            { Let_Go(Piece); }

            InDrain.Released.Add(Piece);
            ++ReleasedCount;
        }

        InState.Held = StillHeld;
        if (ReleasedCount > 0)
        { InState.IsUntouched = false; }

        if (IsLoose == false)
        {
            ck::Trace(f"[FoodBoard] [{InDrain.Board.ToString()}] handed off {ReleasedCount} piece(s) ({StillHeld.Num()} still held)");
            return;
        }

        const auto Destroyed = Trim_Released(InState, Tuners.MaxReleasedPieces);

        ck::Trace(f"[FoodBoard] [{InDrain.Board.ToString()}] released {ReleasedCount} piece(s) at {Velocity} cm/s ({StillHeld.Num()} still held, {Destroyed} oldest released destroyed)");
    }

    private void Loosen(FCk_Handle_FoodPiece& InPiece, const FMars_FoodBoard_ReleaseTuners& InTuners, FVector InWorldVelocity)
    {
        auto Convex = FCk_JoltBody_RuntimeConvexSpec();
        Convex.Set_PointsCm(utils_runtime_mesh::Copy_LocalVerticesCm(InPiece.Get_Geometry()));

        auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::RuntimeConvex);
        BodySpec.Set_RuntimeConvex(Convex);
        BodySpec.Set_MotionType(ECk_MotionType::Dynamic);
        BodySpec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        BodySpec.Set_MassKg(float32(InPiece.Get_MassKg()));
        BodySpec.Set_SurfaceSource(ECk_JoltBody_SurfaceSource::Explicit);
        BodySpec.Set_Friction(InTuners.Friction);
        BodySpec.Set_Restitution(InTuners.Restitution);
        BodySpec.Set_CollisionProfileName(InTuners.CollisionProfileName);

        FCk_Handle Entity = InPiece;
        auto Body = utils_jolt_body::Add(Entity, BodySpec);

        // Applied once the body is set up.
        if (InWorldVelocity.IsNearlyZero() == false)
        { utils_jolt_body::Request_SetLinearVelocity(Body, FCk_Request_JoltBody_SetLinearVelocity(InWorldVelocity)); }

        const auto IsObserved = utils_jolt_body::TryPromise_OnSetupResolved(Body, FCk_Delegate_JoltBody_OnSetupResolved(this, n"OnReleasedBodySetupResolved"));
        ck::EnsureIfNot(IsObserved, f"[FoodBoard] released piece [{InPiece.ToString()}] has a body whose setup cannot be observed");

        Let_Go(InPiece);
    }

    // The board stops watching the piece's cuts and no longer names it.
    private void Let_Go(FCk_Handle_FoodPiece& InPiece)
    {
        InPiece.UnbindFrom_OnCutResolved(FMars_Delegate_FoodPiece_OnCutResolved(this, n"OnHeldPieceCutResolved"));
        InPiece.Request_TryRemove(FMars_Fragment_FoodBoard_Membership);
    }

    private int32 Trim_Released(FMars_Fragment_FoodBoard& InState, int32 InMaxReleased)
    {
        auto Destroyed = 0;
        while (InState.Released.Num() > InMaxReleased)
        {
            const auto Oldest = InState.Released[0];
            InState.Released.RemoveAt(0);
            utils_entity_lifetime::Request_DestroyEntity(Oldest);
            ++Destroyed;
        }

        return Destroyed;
    }

    // Stamps InPiece as held by InBoard and watches its cuts.
    private void Admit(const FCk_Handle_FoodBoard& InBoard, FCk_Handle_FoodPiece& InPiece)
    {
        auto& Membership = InPiece.AddOrGet_Fragment(FMars_Fragment_FoodBoard_Membership);
        Membership.Board = InBoard;
        Membership.PendingCutPlane.Reset();

        InPiece.BindTo_OnCutResolved(FMars_Delegate_FoodPiece_OnCutResolved(this, n"OnHeldPieceCutResolved"));
    }

    // Unbinding first keeps the watch single across placements.
    private void Watch_Teardown(const FCk_Handle_FoodBoard& InBoard)
    {
        FCk_Handle Board = InBoard;
        Board.UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnBoardBeginDestroy"));
        Board.BindTo_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnBoardBeginDestroy"));
    }

    private void Offset(const FCk_Handle_FoodPiece& InPiece, FVector InDeltaCm)
    {
        if (InDeltaCm.IsNearlyZero())
        { return; }

        FCk_Handle Entity = InPiece;
        utils_transform::Request_AddLocationOffset(Entity.As_Transform(), FCk_Request_Transform_AddLocationOffset(InDeltaCm));
    }

    private void Destroy_Halves(const FMars_Request_FoodBoard_ResolveCut& InRequest)
    {
        utils_entity_lifetime::Request_DestroyEntity(InRequest.Positive);
        utils_entity_lifetime::Request_DestroyEntity(InRequest.Negative);
    }

    // Removes the dead entries; returns how many.
    private int32 Remove_Gone(TArray<FCk_Handle_FoodPiece>& InOutPieces)
    {
        auto Removed = 0;
        for (int32 Index = InOutPieces.Num() - 1; Index >= 0; --Index)
        {
            if (Get_IsGone(InOutPieces[Index]))
            {
                InOutPieces.RemoveAt(Index);
                ++Removed;
            }
        }

        return Removed;
    }

    private bool Get_IsGone(const FCk_Handle_FoodPiece& InPiece)
    {
        return ck::Is_NOT_Valid(InPiece) || utils_entity_lifetime::Get_IsPendingDestroy(InPiece, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }

    // Ready, not cutting, and no board cut awaiting its answer: a piece a chop may cut or a sweep may release.
    private bool Get_IsFree(const FCk_Handle_FoodPiece& InPiece)
    {
        return InPiece.Get_Status() == EMars_FoodPiece_Status::Ready && InPiece.Get_IsCutting() == false
            && InPiece.Get_HasBoardCutPending() == false;
    }

    private void Broadcast(FMars_FoodBoard_Drain& InDrain)
    {
        auto Board = InDrain.Board;

        if (InDrain.Cleared && Board.Has_Fragment(FMars_Fragment_FoodBoard_Signals))
        { Board.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnCleared.Broadcast(Board); }

        for (const auto& Cut : InDrain.PieceCuts)
        {
            if (Board.Has_Fragment(FMars_Fragment_FoodBoard_Signals))
            { Board.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnPieceCut.Broadcast(Board, Cut.Source, Cut.Positive, Cut.Negative); }
        }

        for (const auto& Piece : InDrain.Placed)
        {
            if (Board.Has_Fragment(FMars_Fragment_FoodBoard_Signals))
            { Board.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnPlaced.Broadcast(Board, Piece); }
        }

        for (const auto& Refused : InDrain.Refused)
        {
            if (Board.Has_Fragment(FMars_Fragment_FoodBoard_Signals))
            { Board.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnPlaceRefused.Broadcast(Board, Refused.Piece, Refused.Refusal); }
        }

        for (const auto& Issue : InDrain.CutIssues)
        {
            if (Board.Has_Fragment(FMars_Fragment_FoodBoard_Signals))
            { Board.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnCutIssued.Broadcast(Board, Issue); }
        }

        for (const auto& Piece : InDrain.Released)
        {
            if (Board.Has_Fragment(FMars_Fragment_FoodBoard_Signals))
            { Board.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnReleased.Broadcast(Board, Piece); }
        }
    }

    // A held piece's cut resolved: every outcome reaches the board as a ResolveCut, drained after any Clear of the same drain
    // (a Cut replaces the piece with its halves; any other outcome leaves it whole and free for the next chop, and may leave
    // the board quiet enough to part). A board already being destroyed takes no halves.
    UFUNCTION()
    private void OnHeldPieceCutResolved(FCk_Handle_FoodPiece InSource, FMars_FoodPiece_CutResult InResult)
    {
        auto Source = InSource;
        const auto IsMember = Source.Has_Fragment(FMars_Fragment_FoodBoard_Membership);
        if (ck::EnsureIfNot(IsMember, f"[FoodBoard] watched piece [{Source.ToString()}] resolved a cut without a board membership"))
        { return; }

        auto& Membership = Source.Get_Fragment(FMars_Fragment_FoodBoard_Membership);
        const auto PendingCutPlane = Membership.PendingCutPlane;
        Membership.PendingCutPlane.Reset();
        auto Board = Membership.Board;
        const auto IsCut = InResult.Outcome == EMars_FoodPiece_CutOutcome::Cut;

        if (ck::Is_NOT_Valid(Board) || utils_entity_lifetime::Get_IsPendingDestroy(Board, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        {
            if (IsCut)
            {
                ck::Trace(f"[FoodBoard] [{Source.ToString()}] was cut as its board went away: its halves are destroyed");
                utils_entity_lifetime::Request_DestroyEntity(InResult.Positive);
                utils_entity_lifetime::Request_DestroyEntity(InResult.Negative);
            }

            return;
        }

        // Recovery for a cut the board did not submit: the halves are still held, only unparted.
        if (IsCut)
        { ck::EnsureIfNot(PendingCutPlane.IsSet(), f"[FoodBoard] [{Board.ToString()}] held piece [{Source.ToString()}] was cut by something other than its board"); }

        auto& Requests = Board.AddOrGet_Fragment(FMars_Fragment_FoodBoard_Requests);
        Requests.ResolveCutRequests.Add(FMars_Request_FoodBoard_ResolveCut(Source, InResult, PendingCutPlane));
    }

    // Held pieces end with the board (under the world's transient entity they would outlive it); released pieces live on. The
    // halves of a cut that committed after the board's last drain were never admitted, so they go too.
    UFUNCTION()
    private void OnBoardBeginDestroy(FCk_Handle InBoard)
    {
        auto BoardEntity = InBoard;
        if (BoardEntity.Has_Fragment(FMars_Fragment_FoodBoard) == false)
        { return; }

        const TArray<FCk_Handle_FoodPiece> Held = BoardEntity.Get_Fragment(FMars_Fragment_FoodBoard).Held;
        for (const auto& Piece : Held)
        { utils_entity_lifetime::Request_DestroyEntity(Piece); }

        auto Orphaned = 0;
        if (BoardEntity.Has_Fragment(FMars_Fragment_FoodBoard_Requests))
        {
            const TArray<FMars_Request_FoodBoard_ResolveCut> Pending = BoardEntity.Get_Fragment(FMars_Fragment_FoodBoard_Requests).ResolveCutRequests;
            for (const auto& Request : Pending)
            {
                if (Request.Outcome != EMars_FoodPiece_CutOutcome::Cut)
                { continue; }

                Destroy_Halves(Request);
                ++Orphaned;
            }
        }

        ck::Trace(f"[FoodBoard] [{BoardEntity.ToString()}] destroyed: {Held.Num()} held piece(s) and {Orphaned} uncommitted cut(s) destroyed with it");
    }

    // A mesh Jolt cannot hull is a content defect, and there is no fallback shape; a body cancelled with its entity or world
    // is not a defect.
    UFUNCTION()
    private void OnReleasedBodySetupResolved(FCk_Handle_JoltBody InBody, ECk_JoltBody_SetupState InState, ECk_JoltBody_SetupFailure InFailure)
    {
        if (InState != ECk_JoltBody_SetupState::Failed || InFailure == ECk_JoltBody_SetupFailure::Cancelled)
        { return; }

        ck::EnsureIfNot(false, f"[FoodBoard] released piece [{InBody.ToString()}] got no body: {InFailure :n} ({utils_jolt_body::Get_SetupDiagnostic(InBody)})");
    }
}
