// The drain is judged by where a piece lies, not what it touches: a piece lying still inside the basket's interior drains,
// whatever it rests on. One piece is released into the basket and drains on its floor; a second is released onto it and
// comes to rest on top of it (its middle above the first's top), never on the basket floor; it drains too, within its
// DrainSeconds of stillness, long before the drain budget (raised far past the test) could. It is still in the basket on
// the first piece when it drains.
class UMars_AutoTest_Fry_APieceOnAnotherPieceDrains : UMars_AutoTestRig_Fry
{
    default _TimeoutSeconds = 20.0f;

    // Far past anything the test waits: only stillness can drain the top piece.
    private const float32 k_DrainBudgetSeconds = 120.0f;
    private const float64 k_DropClearance = 0.5;

    private FMars_CookingFeed_PieceId _Bottom;
    private FMars_CookingFeed_PieceId _Top;
    private bool _TopTouchedTheFloor = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Receiver.DrainBudgetSeconds = k_DrainBudgetSeconds;
        BuildStation(InHandle, Spec);
        Build_Pieces(2);

        Add_Step_WaitUntil("the scoop and basket bodies are in the simulation", n"Check_BodiesAdded", 0, 0);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", 0, 0);
        Add_Step("release the first piece into the basket", n"Step_ReleaseBottom");
        Add_Step_WaitUntil("the first piece drained on the basket floor", n"Check_FirstDrained", k_SlowPolls, 0);
        Add_Step("release the second piece onto the first", n"Step_ReleaseTop");
        Add_Step_WaitUntil("the second piece drained", n"Check_TopDrained", k_SlowPolls, 0);
        Add_Step("it drained lying on the first piece, inside the basket", n"Step_AssertOnTop");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_ReleaseBottom(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Bottom = AddPiece(k_BasketLocal + FVector(0.0, 0.0, Get_BoxHalfExtents().Z + 3.0));
    }

    UFUNCTION()
    private void Step_ReleaseTop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Bottom = Get_PieceRootLocal(_Bottom);
        _Top = AddPiece(Bottom + FVector(0.0, 0.0, 2.0 * Get_BoxHalfExtents().Z + k_DropClearance));
    }

    // Polled every frame: whether the top piece ever rests on the basket floor before it drains.
    UFUNCTION()
    private void Check_TopDrained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Fry.Get_HasPiece(_Top) == false || _Added.Num() < 2)
        {
            Res.Set(false);
            return;
        }

        const auto Resting = _Fry.Get_PieceState(_Top).Entity.As_Resting();
        if (Resting.Get_HasTarget(_Spec.Nodes.BasketBody) && Resting.Get_IsRestingOn(_Spec.Nodes.BasketBody))
        { _TopTouchedTheFloor = true; }

        Res.Set(_Fry.Get_PieceDrain(_Top) == EMars_Fry_Drain::Drained);
    }

    UFUNCTION()
    private void Step_AssertOnTop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Fry.Get_PieceWhereabouts(_Top) == EMars_Fry_Whereabouts::DrainBasket, "the second piece is in the basket");
        Assert_False(_TopTouchedTheFloor, "the second piece never rested on the basket floor");

        const auto Top = Get_PieceRootLocal(_Top);
        const auto Bottom = Get_PieceRootLocal(_Bottom);
        Assert_True(Top.Z > Bottom.Z + Get_BoxHalfExtents().Z, f"the second piece lies on the first (middles at Z {Top.Z} over {Bottom.Z})");
        Assert_Equals_Int(Count_Ids(_DrainedIds, _Top), 1, "OnPieceDrained named the second piece once");
    }
}
