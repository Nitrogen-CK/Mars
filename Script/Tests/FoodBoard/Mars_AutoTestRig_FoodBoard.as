struct FMars_AutoTest_FoodBoard_PieceEvent
{
    FCk_Handle_FoodBoard Board;
    FCk_Handle_FoodPiece Piece;
}

struct FMars_AutoTest_FoodBoard_Refusal
{
    FCk_Handle_FoodBoard Board;
    FCk_Handle_FoodPiece Piece;
    EMars_FoodBoard_PlaceRefusal Refusal = EMars_FoodBoard_PlaceRefusal::Full;
}

struct FMars_AutoTest_FoodBoard_Issue
{
    FCk_Handle_FoodBoard Board;
    FMars_FoodBoard_CutIssue Issue;
}

struct FMars_AutoTest_FoodBoard_PieceCut
{
    FCk_Handle_FoodBoard Board;
    FCk_Handle_FoodPiece Source;
    FCk_Handle_FoodPiece Positive;
    FCk_Handle_FoodPiece Negative;
}

// The FoodBoard rig, on the FoodPiece rig (pieces under the world's transient entity, tracked for cleanup, their cuts
// recorded and their halves tracked). Boards are plain Transform entities under the test entity, recorded per board: every
// placement, refusal, chop, committed cut, release and clear. Boxes and planes are placed in a board's own frame, and the
// tests rotate their boards, so the frame math is exercised.
UCLASS(Abstract)
class UMars_AutoTestRig_FoodBoard : UMars_AutoTestRig_FoodPiece
{
    protected TArray<FMars_AutoTest_FoodBoard_PieceEvent> _Placed;
    protected TArray<FMars_AutoTest_FoodBoard_Refusal> _Refusals;
    protected TArray<FMars_AutoTest_FoodBoard_Issue> _Issues;
    protected TArray<FMars_AutoTest_FoodBoard_PieceCut> _PieceCuts;
    protected TArray<FMars_AutoTest_FoodBoard_PieceEvent> _ReleasedEvents;
    protected TArray<FCk_Handle_FoodBoard> _Cleared;

    // Room for every test's pieces; four cuts a chop; a visible parting; a release ring no test fills by accident.
    protected FMars_FoodBoard_Tuners Make_Tuners() const
    {
        auto Tuners = FMars_FoodBoard_Tuners();
        Tuners.MaxHeldPieces = 8;
        Tuners.MaxCutsPerChop = 4;
        Tuners.SeparationCm = 1.0f;
        Tuners.MaxReleasedPieces = 8;
        return Tuners;
    }

    protected FCk_Handle_FoodBoard Build_Board(FCk_Handle InOwner, FTransform InWorld, FMars_FoodBoard_Tuners InTuners)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InOwner);
        utils_transform::Add(Entity, InWorld, ECk_Replication::DoesNotReplicate);
        auto Board = utils_foodboard::Add(Entity, FMars_FoodBoard_Spec(InTuners));
        Board.BindTo_OnPlaced(FMars_Delegate_FoodBoard_OnPlaced(this, n"OnBoardPlaced"));
        Board.BindTo_OnPlaceRefused(FMars_Delegate_FoodBoard_OnPlaceRefused(this, n"OnBoardPlaceRefused"));
        Board.BindTo_OnCutIssued(FMars_Delegate_FoodBoard_OnCutIssued(this, n"OnBoardCutIssued"));
        Board.BindTo_OnPieceCut(FMars_Delegate_FoodBoard_OnPieceCut(this, n"OnBoardPieceCut"));
        Board.BindTo_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnBoardReleased"));
        Board.BindTo_OnCleared(FMars_Delegate_FoodBoard_OnCleared(this, n"OnBoardCleared"));
        return Board;
    }

    // A box piece at InLocal in InBoard's frame; not yet placed.
    protected FCk_Handle_FoodPiece Build_BoxOn(FCk_Handle_FoodBoard InBoard, FTransform InLocal, float InMassKg)
    {
        return Build_Piece(Get_BoxMesh(), InLocal * Get_BoardWorld(InBoard), Make_Spec(InMassKg));
    }

    protected void Place(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece)
    {
        auto Board = InBoard;
        Board.Request_Place(FMars_Request_FoodBoard_Place(InPiece));
    }

    protected void Chop(FCk_Handle_FoodBoard InBoard, FMars_FoodPiece_WorldPlane InPlane)
    {
        auto Board = InBoard;
        Board.Request_Cut(FMars_Request_FoodBoard_Cut(InPlane));
    }

    protected FTransform Get_BoardWorld(FCk_Handle_FoodBoard InBoard) const
    {
        FCk_Handle Entity = InBoard;
        return utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
    }

    // A plane through InLocalPositionCm with InLocalNormal, both in InBoard's frame, as a world plane.
    protected FMars_FoodPiece_WorldPlane Make_BoardPlane(FCk_Handle_FoodBoard InBoard, FVector InLocalPositionCm, FVector InLocalNormal) const
    {
        const auto BoardWorld = Get_BoardWorld(InBoard);
        return Make_WorldPlane(BoardWorld.TransformPosition(InLocalPositionCm), BoardWorld.TransformVectorNoScale(InLocalNormal));
    }

    // The tangent is any unit vector across the normal.
    protected FMars_FoodPiece_WorldPlane Make_WorldPlane(FVector InPositionCm, FVector InNormal) const
    {
        const auto Normal = InNormal.GetSafeNormal();
        const auto Across = Math::Abs(Normal.Z) < 0.9 ? FVector::UpVector : FVector::ForwardVector;
        return FMars_FoodPiece_WorldPlane(InPositionCm, Normal, Normal.CrossProduct(Across).GetSafeNormal());
    }

    // The world centre of the box fixture's bounds at InPiece's pose.
    protected FVector Get_WorldBoundsCenter(FCk_Handle_FoodPiece InPiece) const
    {
        return Get_World(InPiece).TransformPosition(Get_BoundsCenter(InPiece));
    }

    protected int32 Get_PlacedCount(FCk_Handle_FoodBoard InBoard) const
    {
        auto Count = 0;
        for (const auto& Event : _Placed)
        {
            if (Event.Board == InBoard)
            { ++Count; }
        }

        return Count;
    }

    protected TArray<FMars_AutoTest_FoodBoard_Refusal> Get_Refusals(FCk_Handle_FoodBoard InBoard) const
    {
        TArray<FMars_AutoTest_FoodBoard_Refusal> Refusals;
        for (const auto& Refusal : _Refusals)
        {
            if (Refusal.Board == InBoard)
            { Refusals.Add(Refusal); }
        }

        return Refusals;
    }

    protected TArray<FMars_FoodBoard_CutIssue> Get_Issues(FCk_Handle_FoodBoard InBoard) const
    {
        TArray<FMars_FoodBoard_CutIssue> Issues;
        for (const auto& Issue : _Issues)
        {
            if (Issue.Board == InBoard)
            { Issues.Add(Issue.Issue); }
        }

        return Issues;
    }

    protected TArray<FMars_AutoTest_FoodBoard_PieceCut> Get_PieceCuts(FCk_Handle_FoodBoard InBoard) const
    {
        TArray<FMars_AutoTest_FoodBoard_PieceCut> PieceCuts;
        for (const auto& PieceCut : _PieceCuts)
        {
            if (PieceCut.Board == InBoard)
            { PieceCuts.Add(PieceCut); }
        }

        return PieceCuts;
    }

    protected TArray<FCk_Handle_FoodPiece> Get_ReleasedEvents(FCk_Handle_FoodBoard InBoard) const
    {
        TArray<FCk_Handle_FoodPiece> Pieces;
        for (const auto& Event : _ReleasedEvents)
        {
            if (Event.Board == InBoard)
            { Pieces.Add(Event.Piece); }
        }

        return Pieces;
    }

    protected int32 Get_ClearedCount(FCk_Handle_FoodBoard InBoard) const
    {
        auto Count = 0;
        for (const auto& Board : _Cleared)
        {
            if (Board == InBoard)
            { ++Count; }
        }

        return Count;
    }

    protected bool Get_IsSameOrder(TArray<FCk_Handle_FoodPiece> InActual, TArray<FCk_Handle_FoodPiece> InExpected) const
    {
        if (InActual.Num() != InExpected.Num())
        { return false; }

        for (int32 Index = 0; Index < InActual.Num(); ++Index)
        {
            if (InActual[Index] != InExpected[Index])
            { return false; }
        }

        return true;
    }

    // Whether the board's committed-cut record names InSource.
    protected bool Get_WasCut(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InSource) const
    {
        for (const auto& PieceCut : Get_PieceCuts(InBoard))
        {
            if (PieceCut.Source == InSource)
            { return true; }
        }

        return false;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnBoardPlaced(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece)
    {
        auto Event = FMars_AutoTest_FoodBoard_PieceEvent();
        Event.Board = InBoard;
        Event.Piece = InPiece;
        _Placed.Add(Event);
    }

    UFUNCTION()
    private void OnBoardPlaceRefused(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece, EMars_FoodBoard_PlaceRefusal InRefusal)
    {
        auto Refusal = FMars_AutoTest_FoodBoard_Refusal();
        Refusal.Board = InBoard;
        Refusal.Piece = InPiece;
        Refusal.Refusal = InRefusal;
        _Refusals.Add(Refusal);
    }

    UFUNCTION()
    private void OnBoardCutIssued(FCk_Handle_FoodBoard InBoard, FMars_FoodBoard_CutIssue InIssue)
    {
        auto Issue = FMars_AutoTest_FoodBoard_Issue();
        Issue.Board = InBoard;
        Issue.Issue = InIssue;
        _Issues.Add(Issue);
    }

    UFUNCTION()
    private void OnBoardPieceCut(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InSource, FCk_Handle_FoodPiece InPositive, FCk_Handle_FoodPiece InNegative)
    {
        auto PieceCut = FMars_AutoTest_FoodBoard_PieceCut();
        PieceCut.Board = InBoard;
        PieceCut.Source = InSource;
        PieceCut.Positive = InPositive;
        PieceCut.Negative = InNegative;
        _PieceCuts.Add(PieceCut);
    }

    UFUNCTION()
    private void OnBoardReleased(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece)
    {
        auto Event = FMars_AutoTest_FoodBoard_PieceEvent();
        Event.Board = InBoard;
        Event.Piece = InPiece;
        _ReleasedEvents.Add(Event);
    }

    UFUNCTION()
    private void OnBoardCleared(FCk_Handle_FoodBoard InBoard)
    {
        _Cleared.Add(InBoard);
    }
}
