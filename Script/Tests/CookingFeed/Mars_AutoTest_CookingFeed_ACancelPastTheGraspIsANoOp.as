// A transfer past its grasp is committed. A Cancel while the hand carries its piece changes nothing: the hand carries on
// under the same reservation, nothing settles, the generation stays, and the release still comes for that very piece.
// Accepted, it is admitted once and the hand returns to rest; nothing was ever Cancelled.
class UMars_AutoTest_CookingFeed_ACancelPastTheGraspIsANoOp : UMars_AutoTestRig_CookingFeed
{
    private FMars_CookingFeed_PieceId _Reserved;
    private FCk_Handle_FoodPiece _Piece;
    private int32 _GenerationBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        // A Carry long enough that the cancel lands inside it.
        auto Spec = Make_TestSpec();
        Spec.Timing = FMars_CookingFeed_TimingSpec(0.1f, 0.05f, 0.5f, 0.1f);
        BuildFeed(InHandle, Spec);
        Add_Steps_SourceTheFeed();

        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the hand carries its piece", n"Check_Carrying", 0, 0);
        Add_Step("cancel while carrying", n"Step_CancelInCarry");
        Add_Step_WaitFrames("the cancel drains", 2);
        Add_Step("the carry goes on: same reservation, nothing settled", n"Step_AssertStillCarrying");
        Add_Step_WaitUntil("the release still comes", n"Check_AwaitingAdmission", 0, 0);
        Add_Step("the release names the carried piece; accept it", n"Step_AssertReleaseAndAccept");
        Add_Step_WaitUntil("the hand is back at rest", n"Check_Idle", 0, 0);
        Add_Step("admitted once, never cancelled", n"Step_AssertAdmitted");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Carrying(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Carry);
    }

    UFUNCTION()
    private void Step_CancelInCarry(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Feed.TryGet_ActivePiece().IsSet(), "a piece is reserved");
        if (_Feed.TryGet_ActivePiece().IsSet())
        { _Reserved = _Feed.TryGet_ActivePiece().GetValue(); }

        _Piece = _Feed.TryGet_ActiveFoodPiece();
        _GenerationBefore = _Feed.Get_Generation();
        Cancel();
    }

    UFUNCTION()
    private void Step_AssertStillCarrying(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Phase = _Feed.Get_Phase();
        Assert_True(Phase == EMars_CookingFeed_Phase::Carry || Phase == EMars_CookingFeed_Phase::AwaitAdmission,
            f"the hand is still carrying (or released) (got {Phase :n})");
        const auto Active = _Feed.TryGet_ActivePiece();
        Assert_True(Active.IsSet() && Active.GetValue().Get_IsSame(_Reserved), "under the same reservation");
        Assert_Equals_Int(_Settles.Num(), 0, "nothing settled");
        Assert_Equals_Int(_Feed.Get_Generation(), _GenerationBefore, "the generation stayed");
        Assert_Equals_Int(Get_PhaseCount(EMars_CookingFeed_Phase::Idle), 0, "the hand never rested");
    }

    UFUNCTION()
    private void Step_AssertReleaseAndAccept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Releases.Num(), 1, "one release");
        Assert_True(_Releases.Num() == 1 && _Releases[0].PieceId.Get_IsSame(_Reserved) && _Releases[0].Piece == _Piece,
            "for the carried piece");
        Step_AcceptPending(InHandle, InPayload);
    }

    UFUNCTION()
    private void Step_AssertAdmitted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Settles.Num(), 1, "one transfer settled");
        Assert_True(_Settles.Num() == 1 && _Settles[0] == EMars_CookingFeed_Settle::Admitted, "it settled Admitted");
        Assert_Equals_Int(Get_SettleCount(EMars_CookingFeed_Settle::Cancelled), 0, "nothing was cancelled");
        Assert_Ledger(k_Stock - 1, 1, "after the admission");
    }
}
