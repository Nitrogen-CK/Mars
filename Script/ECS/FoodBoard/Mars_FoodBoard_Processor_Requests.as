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
    TArray<FMars_Request_FoodBoard_ResolveCut> PieceCuts;
    // The board's pieces were moved this drain (a parting or a turn): their moves land after it (FGroup_Transform), so a
    // cut or a turn behind them waits for the next pass.
    bool Moved = false;
    TArray<FCk_Handle_FoodPiece> Placed;
    TArray<FMars_FoodBoard_PlaceRefused> Refused;
    TArray<FMars_FoodBoard_CutIssue> CutIssues;
    // The yaw of each applied Turn.
    TArray<float32> Turned;
    TArray<FCk_Handle_FoodPiece> Released;
    // One per applied Release that let nothing go.
    TArray<EMars_FoodBoard_ReleaseRefusal> ReleaseRefusals;
    // One per release the station's inbox held, answered on the station's OnAdmission.
    TArray<FMars_CookingFeed_AdmissionAnswer> Answers;
}

// Why the queue's head did not apply this drain.
enum EMars_FoodBoard_HeadWait
{
    // It applied: the queue moves on.
    None,
    // A cut in flight resolves it (its ResolveCut wakes the board).
    CutInFlight,
    // The pieces moved this drain: the next pass applies it.
    PiecesMoved
}

// Drains ResolveCut -> (parting) -> Place (then the station inbox's releases, each a Place posed on the pile node and
// answered on the station's OnAdmission) -> the queue, then broadcasts in that order. Pieces destroyed elsewhere leave the
// ledger after the resolutions, so a cut source (destroyed by its own commit) is still found by its ResolveCut. The board
// parts only when quiet (Apply_Parting). This drain's cuts, turns and releases join the queue in arrival order (the
// station's take-outs, each a Release onto its tray, after them), and the queue applies from its head until an entry must
// wait (EMars_FoodBoard_HeadWait): a cut while a parting is owed or once the pieces moved this drain, a turn while any cut
// is in flight or once the pieces moved; everything behind a waiting entry waits with it. Turns that reach the head
// together apply as one yaw of their sum, so two turns in one drain compose.
//
// The board is the one owner of its pieces' lease facts: it stamps every piece it holds with the holder fact and its
// pickup's Ledger claim (a whole food is a world item a hand could otherwise take off the board behind its back), and
// removes the holder when it lets a piece go: the claim goes then for a piece let go where it lies, and only once it lands
// for one it loads onto a tray (a refusal places it back on the board, claim and all).
//
// It is also the board's only listener: the station's inbox and take-outs (OnQueued wakes this drain), every held piece's
// OnCutResolved (each becomes a ResolveCut on the board, drained the same frame because RuntimeMesh resolves slices in
// FGroup_Gameplay; a Cut replaces the piece with its halves, any other outcome leaves it whole and free for the next chop),
// the answers of every tray it loads (OnLoaded, OnLoadRefused) and the board's own destruction (held pieces end with it; a
// piece it handed off lives on). The only FoodPiece fragment it writes is the holder fact.
class UMars_Processor_FoodBoard_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Cutting_Tick");
    default _MarkedDirtyBy = FMars_Fragment_FoodBoard_Requests;

    // Above every Sequence: a request list whose entries are all merged.
    private const int32 k_Exhausted = 2147483647;

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

        TArray<FMars_Request_FoodBoard_ResolveCut> ResolveCutRequests = InRequests.ResolveCutRequests;
        TArray<FMars_Request_FoodBoard_Place> PlaceRequests = InRequests.PlaceRequests;
        const TArray<FMars_FoodBoard_Op> Arrived = Make_Ops(InRequests);

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Drain.Board.Request_TryRemove(FMars_Fragment_FoodBoard_Requests);

        Watch_Station(Drain.Board);
        TArray<FMars_CookingFeed_Release> Inbox = utils_cooking_feed::Take_Inbox(InHandle);
        TArray<FMars_Request_StationTakeOut> TakeOuts = utils_cooking_feed::Take_TakeOutRequests(InHandle);

        InState.Queue.Append(Arrived);
        for (const auto& TakeOut : TakeOuts)
        {
            auto Op = FMars_FoodBoard_Op();
            Op.Kind = EMars_FoodBoard_OpKind::Release;
            Op.Release = Make_TakeOutRelease(TakeOut);
            InState.Queue.Add(Op);
        }

        for (const auto& Request : ResolveCutRequests)
        { Apply_ResolveCut(Drain, InState, Request); }

        Drop_Gone(Drain, InState);
        Apply_Parting(Drain, InState);

        for (const auto& Request : PlaceRequests)
        { Apply_Place(Drain, InState, Request); }

        for (const auto& Release : Inbox)
        { Apply_Admission(Drain, InState, Release); }

        const auto Wait = Apply_Queue(Drain, InState);
        if (Wait == EMars_FoodBoard_HeadWait::PiecesMoved)
        { Drain.Board.AddOrGet_Fragment(FMars_Fragment_FoodBoard_Requests); }

        Broadcast(Drain);
    }

    // This drain's cuts, turns and releases as queue entries in arrival order: each list is already in its own order, so
    // the merge takes the lowest Sequence at the head of the three.
    private TArray<FMars_FoodBoard_Op> Make_Ops(const FMars_Fragment_FoodBoard_Requests& InRequests) const
    {
        TArray<FMars_FoodBoard_Op> Ops;
        auto Cut = 0;
        auto Turn = 0;
        auto Release = 0;
        const auto Total = InRequests.CutRequests.Num() + InRequests.TurnRequests.Num() + InRequests.ReleaseRequests.Num();
        while (Ops.Num() < Total)
        {
            const auto CutSequence = Cut < InRequests.CutRequests.Num() ? InRequests.CutRequests[Cut].Sequence : k_Exhausted;
            const auto TurnSequence = Turn < InRequests.TurnRequests.Num() ? InRequests.TurnRequests[Turn].Sequence : k_Exhausted;
            const auto ReleaseSequence = Release < InRequests.ReleaseRequests.Num() ? InRequests.ReleaseRequests[Release].Sequence : k_Exhausted;

            auto Op = FMars_FoodBoard_Op();
            if (CutSequence <= TurnSequence && CutSequence <= ReleaseSequence)
            {
                Op.Kind = EMars_FoodBoard_OpKind::Cut;
                Op.Cut = InRequests.CutRequests[Cut];
                Op.Sequence = CutSequence;
                ++Cut;
            }
            else if (TurnSequence <= ReleaseSequence)
            {
                Op.Kind = EMars_FoodBoard_OpKind::Turn;
                Op.Turn = InRequests.TurnRequests[Turn];
                Op.Sequence = TurnSequence;
                ++Turn;
            }
            else
            {
                Op.Kind = EMars_FoodBoard_OpKind::Release;
                Op.Release = InRequests.ReleaseRequests[Release];
                Op.Sequence = ReleaseSequence;
                ++Release;
            }

            Ops.Add(Op);
        }

        return Ops;
    }

    // Quiet: no cut the board submitted is in flight and no parting is owed.
    private bool Get_IsQuiet(const FMars_Fragment_FoodBoard& InState) const
    {
        if (InState.Unparted.Num() > 0)
        { return false; }

        for (const auto& Piece : InState.Held)
        {
            if (Piece.Get_HasBoardCutPending())
            { return false; }
        }

        return true;
    }

    // Applies the queue from its head until an entry must wait; returns why it stopped (None: the queue is empty).
    private EMars_FoodBoard_HeadWait Apply_Queue(FMars_FoodBoard_Drain& InDrain, FMars_Fragment_FoodBoard& InState)
    {
        while (InState.Queue.Num() > 0)
        {
            const auto Head = InState.Queue[0];
            if (Head.Kind == EMars_FoodBoard_OpKind::Release)
            {
                InState.Queue.RemoveAt(0);
                Apply_Release(InDrain, InState, Head.Release);
                continue;
            }

            const auto Wait = Get_HeadWait(InDrain, InState, Head.Kind);
            if (Wait != EMars_FoodBoard_HeadWait::None)
            { return Wait; }

            if (Head.Kind == EMars_FoodBoard_OpKind::Cut)
            {
                InState.Queue.RemoveAt(0);
                Apply_Cut(InDrain, InState, Head.Cut);
                continue;
            }

            Apply_Turns(InDrain, InState);
        }

        return EMars_FoodBoard_HeadWait::None;
    }

    // A cut cuts the parted poses as they will be seen (no parting owed, nothing moved this drain); a turn turns only a
    // quiet board's pieces as they stand.
    private EMars_FoodBoard_HeadWait Get_HeadWait(const FMars_FoodBoard_Drain& InDrain, const FMars_Fragment_FoodBoard& InState,
        EMars_FoodBoard_OpKind InKind) const
    {
        const auto IsBlocked = InKind == EMars_FoodBoard_OpKind::Turn ? Get_IsQuiet(InState) == false : InState.Unparted.Num() > 0;
        if (IsBlocked)
        { return EMars_FoodBoard_HeadWait::CutInFlight; }

        if (InDrain.Moved)
        { return EMars_FoodBoard_HeadWait::PiecesMoved; }

        return EMars_FoodBoard_HeadWait::None;
    }

    // Every turn at the queue's head goes, as one yaw of their sum (each still answers with its own OnTurned).
    private void Apply_Turns(FMars_FoodBoard_Drain& InDrain, FMars_Fragment_FoodBoard& InState)
    {
        auto DeltaDegrees = 0.0f;
        while (InState.Queue.Num() > 0 && InState.Queue[0].Kind == EMars_FoodBoard_OpKind::Turn)
        {
            const auto Turn = InState.Queue[0].Turn;
            InState.Queue.RemoveAt(0);
            DeltaDegrees += Turn.DeltaDegrees;
            InDrain.Turned.Add(Turn.DeltaDegrees);
        }

        Apply_Turn(InDrain, InState, DeltaDegrees);
    }

    // Every held piece turns about the pile node on the world's vertical axis, location and rotation together. The location
    // moves by an offset (as the parting does).
    private void Apply_Turn(FMars_FoodBoard_Drain& InDrain, FMars_Fragment_FoodBoard& InState, float32 InDeltaDegrees)
    {
        const auto Pivot = InDrain.Board.Get_PileNodeWorld().GetLocation();
        const auto Yaw = FQuat(FVector::UpVector, Math::DegreesToRadians(float64(InDeltaDegrees)));

        for (const auto& Piece : InState.Held)
        {
            FCk_Handle Entity = Piece;
            auto PieceTransform = Entity.As_Transform();
            const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(PieceTransform);
            const auto Location = PieceWorld.GetLocation();
            Offset(Piece, (Pivot + Yaw.RotateVector(Location - Pivot)) - Location);
            utils_transform::Request_SetRotation(PieceTransform, FCk_Request_Transform_SetRotation((Yaw * PieceWorld.GetRotation()).Rotator()));
        }

        InDrain.Moved = true;
    }

    // A cut that did not commit leaves its piece held and whole. A committed cut's halves take the source's index (positive
    // first) and are stamped and watched like any held piece; its plane waits in Unparted for the board to go quiet. Nothing
    // removes a piece mid-cut (a release skips it, and a source destroyed by its own commit leaves the ledger only after its
    // resolution), so a source the board no longer holds is a defect: it ensures and its halves are destroyed.
    private void Apply_ResolveCut(FMars_FoodBoard_Drain& InDrain, FMars_Fragment_FoodBoard& InState,
                                  const FMars_Request_FoodBoard_ResolveCut& InRequest)
    {
        if (InRequest.Outcome != EMars_FoodPiece_CutOutcome::Cut)
        { return; }

        const auto Index = utils_foodboard::Find_Piece(InState.Held, InRequest.Source);
        if (ck::EnsureIfNot(Index >= 0, f"[FoodBoard] [{InDrain.Board.ToString()}] the cut of [{InRequest.Source.ToString()}] committed after it left the board: nothing removes a piece mid-cut"))
        {
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

        Admit(InDrain.Board, Positive);
        Admit(InDrain.Board, Negative);

        InDrain.PieceCuts.Add(InRequest);

        if (InRequest.Plane.IsSet())
        { Add_Unparted(InState, InRequest.Plane.GetValue()); }
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
    // pre-move poses is sound: no piece moves farther than a fraction of a gap. The queue's cuts and turns wait for the next pass.
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

        InDrain.Moved = true;
    }

    // A piece destroyed elsewhere is no longer the board's to cut or release.
    private void Drop_Gone(FMars_FoodBoard_Drain& InDrain, FMars_Fragment_FoodBoard& InState)
    {
        Remove_Gone(InState.Held);
    }

    private void Apply_Place(FMars_FoodBoard_Drain& InDrain, FMars_Fragment_FoodBoard& InState, const FMars_Request_FoodBoard_Place& InRequest)
    {
        auto Piece = InRequest.Piece;
        const auto Refusal = Try_Place(InDrain, InState, Piece);
        if (Refusal.IsSet())
        { InDrain.Refused.Add(FMars_FoodBoard_PlaceRefused(Piece, Refusal.GetValue())); }
    }

    // A release from the station's inbox is a Place, its piece posed on the pile node in its food's layout once the board
    // holds it (the feed's release only marks where the glove let go); answered either way. A release with no piece places
    // nothing.
    private void Apply_Admission(FMars_FoodBoard_Drain& InDrain, FMars_Fragment_FoodBoard& InState, const FMars_CookingFeed_Release& InRelease)
    {
        auto Piece = InRelease.Piece;
        if (ck::Is_NOT_Valid(Piece))
        {
            InDrain.Answers.Add(FMars_CookingFeed_AdmissionAnswer(InRelease.PieceId, EMars_CookingFeed_Admission::Rejected, "no piece to place on the board"));
            return;
        }

        const auto Refusal = Try_Place(InDrain, InState, Piece);
        if (Refusal.IsSet())
        {
            InDrain.Refused.Add(FMars_FoodBoard_PlaceRefused(Piece, Refusal.GetValue()));
            InDrain.Answers.Add(FMars_CookingFeed_AdmissionAnswer(InRelease.PieceId, EMars_CookingFeed_Admission::Rejected,
                f"the board refused it: {Refusal.GetValue() :n}"));
            return;
        }

        const auto PoseWorld = InDrain.Board.Get_PoseOnPile(Piece);
        FCk_Handle Entity = Piece;
        auto PieceTransform = Entity.As_Transform();
        utils_transform::Request_SetLocation(PieceTransform, FCk_Request_Transform_SetLocation(PoseWorld.GetLocation()));
        utils_transform::Request_SetRotation(PieceTransform, FCk_Request_Transform_SetRotation(PoseWorld.Rotator()));
        InDrain.Answers.Add(FMars_CookingFeed_AdmissionAnswer(InRelease.PieceId, EMars_CookingFeed_Admission::Accepted, ""));
    }

    // Holds InPiece, or answers why not.
    private TOptional<EMars_FoodBoard_PlaceRefusal> Try_Place(FMars_FoodBoard_Drain& InDrain, FMars_Fragment_FoodBoard& InState, FCk_Handle_FoodPiece& InPiece)
    {
        const auto Refusal = Get_PlaceRefusal(InDrain.Board, InPiece);
        if (Refusal.IsSet())
        { return Refusal; }

        InState.Held.Add(InPiece);
        Admit(InDrain.Board, InPiece);
        utils_world_item::Request_ClaimPickup(InPiece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Disable);
        Watch_Teardown(InDrain.Board);
        InDrain.Placed.Add(InPiece);
        return TOptional<EMars_FoodBoard_PlaceRefusal>();
    }

    private TOptional<EMars_FoodBoard_PlaceRefusal> Get_PlaceRefusal(const FCk_Handle_FoodBoard& InBoard, const FCk_Handle_FoodPiece& InPiece)
    {
        if (Get_IsGone(InPiece))
        { return TOptional<EMars_FoodBoard_PlaceRefusal>(EMars_FoodBoard_PlaceRefusal::Gone); }

        // The holder fact, whichever ledger it names: a platter's or a pan's piece is refused as another board's is.
        const auto Holder = InPiece.TryGet_Holder();
        if (Holder == InBoard)
        { return TOptional<EMars_FoodBoard_PlaceRefusal>(EMars_FoodBoard_PlaceRefusal::AlreadyHeld); }

        if (ck::IsValid(Holder))
        { return TOptional<EMars_FoodBoard_PlaceRefusal>(EMars_FoodBoard_PlaceRefusal::HeldElsewhere); }

        FCk_Handle Entity = InPiece;
        if (Entity.Is_JoltBody() && utils_jolt_body::Get_MotionType(Entity.As_JoltBody()) == ECk_MotionType::Dynamic)
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

    // Every held piece free to move leaves, in held order, until MaxPieces have left: let go where it lies (its Ledger claim
    // released), or loaded onto the request's tray (the claim kept until it lands). A piece still cutting (or not Ready), or
    // past the cap, stays held, so the halves of a cut in flight land on the board. A release that let nothing go is
    // refused: NoRoom under a cap of zero, else NothingFree.
    private void Apply_Release(FMars_FoodBoard_Drain& InDrain, FMars_Fragment_FoodBoard& InState, const FMars_Request_FoodBoard_Release& InRequest)
    {
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

            Let_Go(InDrain.Board, Piece);
            if (ck::IsValid(InRequest.Tray))
            { utils_cooking_feed::Send_ToTray(Piece, FMars_Fragment_StationLanding(InDrain.Board, FMars_CookingFeed_PieceId(), InRequest.Tray)); }
            else
            { utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Enable); }

            InDrain.Released.Add(Piece);
            ++ReleasedCount;
        }

        InState.Held = StillHeld;

        if (ReleasedCount > 0 && ck::IsValid(InRequest.Tray))
        { Watch_Tray(InRequest.Tray); }

        if (ReleasedCount > 0)
        { return; }

        const auto IsCappedAtZero = InRequest.MaxPieces.IsSet() && InRequest.MaxPieces.GetValue() <= 0;
        InDrain.ReleaseRefusals.Add(IsCappedAtZero ? EMars_FoodBoard_ReleaseRefusal::NoRoom : EMars_FoodBoard_ReleaseRefusal::NothingFree);
    }

    // The board stops watching the piece's cuts and no longer names it, nor holds it.
    private void Let_Go(const FCk_Handle_FoodBoard& InBoard, FCk_Handle_FoodPiece& InPiece)
    {
        InPiece.UnbindFrom_OnCutResolved(FMars_Delegate_FoodPiece_OnCutResolved(this, n"OnHeldPieceCutResolved"));
        InPiece.Request_TryRemove(FMars_Fragment_FoodBoard_Membership);
        utils_foodpiece::Clear_Holder(InPiece, InBoard);
    }

    // Stamps InPiece as held by InBoard (its membership and the holder fact) and watches its cuts.
    private void Admit(const FCk_Handle_FoodBoard& InBoard, FCk_Handle_FoodPiece& InPiece)
    {
        auto& Membership = InPiece.AddOrGet_Fragment(FMars_Fragment_FoodBoard_Membership);
        Membership.Board = InBoard;
        Membership.PendingCutPlane.Reset();
        utils_foodpiece::Stamp_Holder(InPiece, InBoard);

        InPiece.BindTo_OnCutResolved(FMars_Delegate_FoodPiece_OnCutResolved(this, n"OnHeldPieceCutResolved"));
    }

    // A take-out is the board's own Release onto its tray, capped at the room the press read: no tray caps it at none.
    private FMars_Request_FoodBoard_Release Make_TakeOutRelease(const FMars_Request_StationTakeOut& InTakeOut) const
    {
        const auto MaxPieces = ck::IsValid(InTakeOut.Tray) ? InTakeOut.MaxPieces : 0;
        return FMars_Request_FoodBoard_Release(TOptional<int32>(MaxPieces), InTakeOut.Tray);
    }

    // Unbinding first keeps the watch single across drains: the station's queue wakes this drain.
    private void Watch_Station(const FCk_Handle_FoodBoard& InBoard)
    {
        FCk_Handle Station = InBoard;
        utils_cooking_feed::UnbindFrom_OnQueued(Station, FMars_Delegate_StationAdmission_OnQueued(this, n"OnStationQueued"));
        utils_cooking_feed::BindTo_OnQueued(Station, FMars_Delegate_StationAdmission_OnQueued(this, n"OnStationQueued"));
    }

    // Unbinding first keeps one binding per tray across take-outs.
    private void Watch_Tray(const FCk_Handle_Platter& InTray)
    {
        auto Tray = InTray;
        Tray.UnbindFrom_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnTrayLoaded"));
        Tray.UnbindFrom_OnLoadRefused(FMars_Delegate_Platter_OnLoadRefused(this, n"OnTrayLoadRefused"));
        Tray.BindTo_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnTrayLoaded"));
        Tray.BindTo_OnLoadRefused(FMars_Delegate_Platter_OnLoadRefused(this, n"OnTrayLoadRefused"));
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

        FCk_Handle Station = Board;
        for (const auto& Answer : InDrain.Answers)
        { utils_cooking_feed::Broadcast_Admission(Station, Answer); }

        for (const auto& Issue : InDrain.CutIssues)
        {
            if (Board.Has_Fragment(FMars_Fragment_FoodBoard_Signals))
            { Board.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnCutIssued.Broadcast(Board, Issue); }
        }

        for (const auto& YawDegrees : InDrain.Turned)
        {
            if (Board.Has_Fragment(FMars_Fragment_FoodBoard_Signals))
            { Board.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnTurned.Broadcast(Board, YawDegrees); }
        }

        for (const auto& Piece : InDrain.Released)
        {
            if (Board.Has_Fragment(FMars_Fragment_FoodBoard_Signals))
            { Board.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnReleased.Broadcast(Board, Piece); }
        }

        for (const auto Refusal : InDrain.ReleaseRefusals)
        {
            if (Board.Has_Fragment(FMars_Fragment_FoodBoard_Signals))
            { Board.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnReleaseRefused.Broadcast(Board, Refusal); }
        }
    }

    // A held piece's cut resolved: every outcome reaches the board as a ResolveCut (a Cut replaces the piece with its halves;
    // any other outcome leaves it whole and free for the next chop, and may leave the board quiet enough to part). A board
    // already being destroyed takes no halves.
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

    // The station queued a release or a take-out: the board drains it this frame.
    UFUNCTION()
    private void OnStationQueued(FCk_Handle InStation)
    {
        auto Station = InStation;
        if (Station.Is_FoodBoard())
        { Station.AddOrGet_Fragment(FMars_Fragment_FoodBoard_Requests); }
    }

    // A piece the board loaded onto a tray landed there: the tray holds it now, and its pickup's Ledger claim goes.
    UFUNCTION()
    private void OnTrayLoaded(FCk_Handle_Platter InTray, FCk_Handle_FoodPiece InPiece)
    {
        const auto Landing = utils_cooking_feed::TryGet_Landing(InPiece, InTray);
        if (Landing.IsSet() == false || Get_IsBoard(Landing.GetValue().Station) == false)
        { return; }

        auto Piece = InPiece;
        utils_cooking_feed::Clear_Landing(Piece);
        utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Enable);
    }

    // A piece the board loaded onto a tray was refused: where it lies is where the board let it go, so placing it again puts
    // it back on the board's books.
    UFUNCTION()
    private void OnTrayLoadRefused(FCk_Handle_Platter InTray, FCk_Handle_FoodPiece InPiece, EMars_Platter_LoadRefusal InRefusal)
    {
        const auto Landing = utils_cooking_feed::TryGet_Landing(InPiece, InTray);
        if (Landing.IsSet() == false || Get_IsBoard(Landing.GetValue().Station) == false)
        { return; }

        auto Piece = InPiece;
        utils_cooking_feed::Clear_Landing(Piece);
        auto Station = Landing.GetValue().Station;
        auto Board = Station.As_FoodBoard();
        Board.Request_Place(FMars_Request_FoodBoard_Place(Piece));
    }

    // A live board's station: a landing whose board is gone has nothing to go back to.
    private bool Get_IsBoard(const FCk_Handle& InStation) const
    {
        return ck::IsValid(InStation)
            && utils_entity_lifetime::Get_IsPendingDestroy(InStation, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false
            && InStation.Is_FoodBoard();
    }

    // Held pieces end with the board (under the world's transient entity they would outlive it); a piece it handed off lives
    // on. The halves of a cut that committed after the board's last drain were never admitted, so they go too.
    UFUNCTION()
    private void OnBoardBeginDestroy(FCk_Handle InBoard)
    {
        auto BoardEntity = InBoard;
        if (BoardEntity.Has_Fragment(FMars_Fragment_FoodBoard) == false)
        { return; }

        const TArray<FCk_Handle_FoodPiece> Held = BoardEntity.Get_Fragment(FMars_Fragment_FoodBoard).Held;
        for (const auto& Piece : Held)
        { utils_entity_lifetime::Request_DestroyEntity(Piece); }

        if (BoardEntity.Has_Fragment(FMars_Fragment_FoodBoard_Requests))
        {
            const TArray<FMars_Request_FoodBoard_ResolveCut> Pending = BoardEntity.Get_Fragment(FMars_Fragment_FoodBoard_Requests).ResolveCutRequests;
            for (const auto& Request : Pending)
            {
                if (Request.Outcome != EMars_FoodPiece_CutOutcome::Cut)
                { continue; }

                Destroy_Halves(Request);
            }
        }
    }
}
