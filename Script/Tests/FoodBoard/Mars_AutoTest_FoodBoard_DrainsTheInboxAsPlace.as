// The board's drain takes its station's admission inbox as its Place, posing each piece it places on its pile node (the
// release only marks where the glove let go). Three releases reach a turned board's inbox in one frame: a piece released at
// a pose off the pile node, a release that carries no piece, and the first piece again. The board answers each on its station's OnAdmission, in arrival order: Accepted, then
// Rejected "no piece to place on the board", then Rejected "the board refused it: AlreadyHeld" (OnPlaceRefused names it
// too). It holds the piece once (one OnPlaced), the piece names the board as its holder, the inbox is empty, and the piece
// lies at its pose on the pile node (a bare piece: the node's own pose), not the release's.
class UMars_AutoTest_FoodBoard_DrainsTheInboxAsPlace : UMars_AutoTestRig_FoodBoard
{
    private const FVector k_Origin = FVector(182000.0, -70000.0, -30000.0);
    // The release's pose in the board's frame: off its centre and turned on it.
    private const FVector k_ReleaseLocal = FVector(6.0, -4.0, 0.0);
    private const FRotator k_ReleaseTurn = FRotator(0.0, 25.0, 0.0);

    private FCk_Handle_FoodBoard _Board;
    private FCk_Handle _BoardEntity;
    private FCk_Handle_FoodPiece _Piece;
    private FTransform _ReleaseWorld;


    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Board = Build_Board(InHandle, FTransform(FRotator(0.0, 40.0, 0.0), k_Origin), Make_Tuners());
        _BoardEntity = _Board;
        Record_Admissions(_BoardEntity);
        // Built off the board: only the release poses it there.
        _Piece = Build_Piece(Get_BoxMesh(), FTransform(FRotator::ZeroRotator, k_Origin + FVector(0.0, 200.0, 0.0)), Make_Spec(1.0));

        Add_Step("release the piece, an empty release and the piece again into the board's inbox", n"Step_Release");
        Add_Step_WaitUntil("all three releases were answered", n"Check_Answered3", 0, 0);
        Add_Step_WaitFrames("the piece's pose is applied", 2);
        Add_Step("placed once on the pile node; the other two rejected with their reasons", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _ReleaseWorld = FTransform(k_ReleaseTurn, k_ReleaseLocal) * Get_BoardWorld(_Board);

        auto Placed = FMars_CookingFeed_Release(FMars_CookingFeed_PieceId(1, 0), _ReleaseWorld, FVector::ZeroVector);
        Placed.Piece = _Piece;
        auto Empty = FMars_CookingFeed_Release(FMars_CookingFeed_PieceId(1, 1), _ReleaseWorld, FVector::ZeroVector);
        auto Again = FMars_CookingFeed_Release(FMars_CookingFeed_PieceId(1, 2), _ReleaseWorld, FVector::ZeroVector);
        Again.Piece = _Piece;

        Assert_True(utils_cooking_feed::Request_Admit(_BoardEntity, Placed), "the board's station queues the release");
        Assert_True(utils_cooking_feed::Request_Admit(_BoardEntity, Empty), "the board's station queues the empty release");
        Assert_True(utils_cooking_feed::Request_Admit(_BoardEntity, Again), "the board's station queues the repeat");
    }

    UFUNCTION()
    private void Check_Answered3(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 3);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Admissions.Num(), 3, "three answers");
        if (_Admissions.Num() != 3)
        { return; }

        for (int32 Index = 0; Index < 3; ++Index)
        { Assert_Equals_Int(_AdmissionIds[Index].TransferIndex, Index, f"answer {Index} is release {Index}'s"); }

        Assert_True(_Admissions[0] == EMars_CookingFeed_Admission::Accepted, f"the release is accepted (reason: {_AdmissionReasons[0]})");
        Assert_True(_Admissions[1] == EMars_CookingFeed_Admission::Rejected, "the empty release is rejected");
        Assert_True(_AdmissionReasons[1] == "no piece to place on the board", f"the empty release's reason (got {_AdmissionReasons[1]})");
        Assert_True(_Admissions[2] == EMars_CookingFeed_Admission::Rejected, "the repeat is rejected");
        Assert_True(_AdmissionReasons[2] == "the board refused it: AlreadyHeld", f"the repeat's reason (got {_AdmissionReasons[2]})");

        Assert_Equals_Int(Get_PlacedCount(_Board), 1, "one OnPlaced");
        const auto Refusals = Get_Refusals(_Board);
        Assert_Equals_Int(Refusals.Num(), 1, "one OnPlaceRefused");
        if (Refusals.Num() == 1)
        {
            Assert_True(Refusals[0].Piece == _Piece, "the refusal names the piece");
            Assert_True(Refusals[0].Refusal == EMars_FoodBoard_PlaceRefusal::AlreadyHeld, f"refused AlreadyHeld (got {Refusals[0].Refusal :n})");
        }

        Assert_Equals_Int(_Board.Get_HeldCount(), 1, "the board holds one piece");
        Assert_True(_Board.Get_Held().Contains(_Piece), "the board holds the piece");
        Assert_True(_Piece.TryGet_Holder() == _BoardEntity, "the piece names the board as its holder");
        Assert_Equals_Int(_BoardEntity.Get_Fragment(FMars_Fragment_StationAdmission).Inbox.Num(), 0, "the inbox is empty");

        const auto PieceWorld = Get_World(_Piece);
        const auto PoseWorld = _Board.Get_PoseOnPile(_Piece);
        Assert_True(PieceWorld.GetLocation().Equals(PoseWorld.GetLocation(), 0.01),
            f"the piece lies at its pose on the pile node (got {PieceWorld.GetLocation()}, want {PoseWorld.GetLocation()})");
        Assert_True(PieceWorld.GetRotation().Equals(PoseWorld.GetRotation(), 0.0001), "the piece lies at its pose's rotation");
        Assert_False(PieceWorld.GetLocation().Equals(_ReleaseWorld.GetLocation(), 0.01), "not at the release's location");
    }
}
