// A piece has one holder, whichever ledger holds it, and every other ledger refuses it on that fact alone. Piece A is placed
// on a board and piece B loaded onto a platter: each names its ledger as its holder. Then each is offered to the other
// ledger: the board refuses B HeldElsewhere and the platter refuses A HeldElsewhere. Neither holder changed, neither
// ledger took a foreign piece, and neither piece carries the other ledger's membership.
class UMars_AutoTest_FoodPiece_OneHolderPerPiece : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(181000.0, -70000.0, -30000.0);
    // Physics settles outrun the harness's default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle_FoodBoard _Board;
    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _A;
    private FCk_Handle_FoodPiece _B;

    private TArray<FCk_Handle_FoodPiece> _BoardPlaced;
    // In parallel: one entry per OnPlaceRefused of the board.
    private TArray<FCk_Handle_FoodPiece> _BoardRefusedPieces;
    private TArray<EMars_FoodBoard_PlaceRefusal> _BoardRefusals;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Platter = Build_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin), Make_PlatterSpec(2));
        Build_Board(InHandle);
        _A = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(0.0, 300.0, 0.0)), 0.5);
        _B = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 0.0)), 0.5);

        Add_Step_WaitUntil("both pieces are Ready", n"Check_Ready", 0, 0);
        Add_Step("place A on the board and load B onto the platter", n"Step_Hold");
        Add_Step_WaitUntil("A is on the board and B landed on the platter", n"Check_Held", k_SlowPolls, 0);
        Add_Step("each holder is its ledger; offer each piece to the other ledger", n"Step_Cross");
        Add_Step_WaitUntil("both ledgers answered", n"Check_CrossAnswered", 0, 0);
        Add_Step("both refused HeldElsewhere and nothing changed hands", n"Step_Assert");
        Run_Steps(InHandle);
    }

    private void Build_Board(FCk_Handle InOwner)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InOwner);
        auto Root = utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, k_Origin + FVector(0.0, 200.0, 0.0)), ECk_Replication::DoesNotReplicate);
        auto PileNode = utils_scene_node::Create(Root, FTransform::Identity).As_Transform();
        auto Tuners = FMars_FoodBoard_Tuners();
        Tuners.MaxHeldPieces = 4;
        _Board = utils_foodboard::Add(Entity, FMars_FoodBoard_Spec(Tuners, PileNode));
        _Board.BindTo_OnPlaced(FMars_Delegate_FoodBoard_OnPlaced(this, n"OnBoardPlaced"));
        _Board.BindTo_OnPlaceRefused(FMars_Delegate_FoodBoard_OnPlaceRefused(this, n"OnBoardPlaceRefused"));
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_A) && Get_HasReadied(_B));
    }

    UFUNCTION()
    private void Step_Hold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Board.Request_Place(FMars_Request_FoodBoard_Place(_A));
        Load(_Platter, _B);
    }

    // B froze into the platter's pile, or either ledger refused (the next step fails on that).
    UFUNCTION()
    private void Check_Held(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto AnyRefused = _BoardRefusals.Num() > 0 || Get_AllRefusalCount(_Platter) > 0;
        auto Res = OutResult;
        Res.Set(AnyRefused || (_BoardPlaced.Contains(_A) && TryGet_Loaded(_B).IsSet()));
    }

    UFUNCTION()
    private void Step_Cross(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_BoardPlaced.Contains(_A), "the board placed A");
        Assert_True(TryGet_Loaded(_B).IsSet(), "B landed on the platter");
        Assert_True(_A.TryGet_Holder() == _Board, "A names the board as its holder");
        Assert_True(_B.TryGet_Holder() == _Platter, "B names the platter as its holder");

        _Board.Request_Place(FMars_Request_FoodBoard_Place(_B));
        Load(_Platter, _A);
    }

    UFUNCTION()
    private void Check_CrossAnswered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set((_BoardRefusals.Num() > 0 || _BoardPlaced.Contains(_B)) && (Get_AllRefusalCount(_Platter) > 0 || _Platter.Get_Occupancy() > 1));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_BoardRefusals.Num(), 1, "the board refused one piece");
        if (_BoardRefusals.Num() == 1)
        {
            Assert_True(_BoardRefusedPieces[0] == _B, "the board refused B");
            Assert_True(_BoardRefusals[0] == EMars_FoodBoard_PlaceRefusal::HeldElsewhere, f"refused HeldElsewhere (got {_BoardRefusals[0] :n})");
        }

        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 1, "the platter refused one piece");
        Assert_Equals_Int(Get_RefusalCount(_Platter, EMars_Platter_LoadRefusal::HeldElsewhere), 1, "the platter refused it HeldElsewhere");
        if (_Refused.Num() == 1)
        { Assert_True(_Refused[0].Piece == _A, "the platter refused A"); }

        Assert_True(_A.TryGet_Holder() == _Board, "A still names the board");
        Assert_True(_B.TryGet_Holder() == _Platter, "B still names the platter");
        Assert_Equals_Int(_Board.Get_HeldCount(), 1, "the board holds one piece");
        Assert_True(_Board.Get_Held().Contains(_A), "the board holds A");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 1, "the platter holds one piece");
        Assert_True(_Platter.Get_Held().Contains(_B), "the platter holds B");
        Assert_True(ck::Is_NOT_Valid(_A.TryGet_Platter()), "A names no platter");
        Assert_True(ck::Is_NOT_Valid(_B.TryGet_FoodBoard()), "B names no board");
    }

    UFUNCTION()
    private void OnBoardPlaced(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece)
    {
        _BoardPlaced.Add(InPiece);
    }

    UFUNCTION()
    private void OnBoardPlaceRefused(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece, EMars_FoodBoard_PlaceRefusal InRefusal)
    {
        _BoardRefusedPieces.Add(InPiece);
        _BoardRefusals.Add(InRefusal);
    }
}
