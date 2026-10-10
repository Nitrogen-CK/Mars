// The drain is bounded: a piece inside the basket that never lies still is Drained once it has been inside
// Receiver.DrainBudgetSeconds, so the operator can always take it out. A piece released into the basket is kept sliding
// (its velocity set to k_SlideSpeed along the basket, alternating direction, every frame) and never accrues stillness; it
// is Drained no sooner than the budget after it came into the basket, its drain progress then full, and it is takeable.
class UMars_AutoTest_Fry_APieceThatNeverStillsDrainsAtTheBudget : UMars_AutoTestRig_Fry
{
    default _TimeoutSeconds = 20.0f;

    private const float32 k_DrainBudgetSeconds = 2.0f;
    // The poll that records the drain comes up to a frame or two after the Tick that drained it.
    private const float32 k_FrameSlackSeconds = 0.1f;
    // Well over utils_fry::k_StillSpeed after a frame's friction.
    private const float64 k_SlideSpeed = 40.0;

    private FMars_CookingFeed_PieceId _Piece;
    private TOptional<float32> _InBasketTime;
    private float32 _DrainedTime = 0.0f;
    private int32 _Polls = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Receiver.DrainBudgetSeconds = k_DrainBudgetSeconds;
        BuildStation(InHandle, Spec);
        Build_Pieces(1);

        Add_Step_WaitUntil("the scoop and basket bodies are in the simulation", n"Check_BodiesAdded", 0, 0);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", 0, 0);
        Add_Step("release the piece into the basket", n"Step_Release");
        Add_Step_WaitUntil("kept sliding, the piece drained at the budget", n"Check_DrainedWhileSliding", k_SlowPolls, 0);
        Add_Step("it drained no sooner than the budget, and is takeable", n"Step_AssertBudget");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Piece = AddPiece(k_BasketLocal + FVector(0.0, 0.0, Get_BoxHalfExtents().Z + 3.0));
    }

    // Polled every frame: once the piece is in the basket, its velocity is set along the basket's X, flipping each poll, so
    // it never lies still; the time it came in and the time it drained are recorded.
    UFUNCTION()
    private void Check_DrainedWhileSliding(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Added.Num() < 1 || _Fry.Get_PieceWhereabouts(_Piece) != EMars_Fry_Whereabouts::DrainBasket)
        {
            Res.Set(false);
            return;
        }

        if (_InBasketTime.IsSet() == false)
        { _InBasketTime = TOptional<float32>(Get_Now()); }

        if (_Fry.Get_PieceDrain(_Piece) == EMars_Fry_Drain::Drained)
        {
            _DrainedTime = Get_Now();
            Res.Set(true);
            return;
        }

        ++_Polls;
        const auto Direction = (_Polls % 2) == 0 ? 1.0 : -1.0;
        auto Body = _Fry.Get_PieceBody(_Piece);
        const auto Velocity = _Fry.Get_RootWorld().GetRotation().RotateVector(FVector(k_SlideSpeed * Direction, 0.0, 0.0));
        utils_jolt_body::Request_SetLinearVelocity(Body, FCk_Request_JoltBody_SetLinearVelocity(Velocity));
        Res.Set(false);
    }

    UFUNCTION()
    private void Step_AssertBudget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Elapsed = _DrainedTime - _InBasketTime.GetValue();
        Assert_True(Elapsed >= k_DrainBudgetSeconds - k_FrameSlackSeconds, f"it drained {Elapsed} s after it came into the basket, not before the budget");
        Assert_Equals_Float(_Fry.Get_PieceDrainProgress(_Piece), 1.0f, 0.0001f, "its drain progress is full");
        Assert_Equals_Int(_Fry.Get_TakeableCount(), 1, "it is takeable");
        Assert_Equals_Int(Count_Ids(_DrainedIds, _Piece), 1, "OnPieceDrained named it once");
    }
}
