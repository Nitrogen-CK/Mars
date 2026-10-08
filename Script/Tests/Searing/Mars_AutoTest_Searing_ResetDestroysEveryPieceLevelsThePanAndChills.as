// A reset mid-session (hot, tilted, two pieces on the pan, one face seared) destroys both pieces and leaves the pan empty
// (nothing is added back), levels and chills the pan and zeroes the tally and the summary.
class UMars_AutoTest_Searing_ResetDestroysEveryPieceLevelsThePanAndChills : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 10.0f;

    // Pan-local: either side of the centre, a gap between the two cubes.
    private const FVector k_LeftLocal = FVector(-8.0, 0.0, 8.0);
    private const FVector k_RightLocal = FVector(8.0, 0.0, 8.0);
    // How long the empty pan is watched after the reset for anything added back.
    private const float32 k_WatchSeconds = 0.5f;

    private TArray<FCk_Handle> _OldPieces;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        auto PanSpec = FMars_Implement_Spec();
        PanSpec.Tilt.LevelReturnDegreesPerSecond = 0.0f;
        BuildStation(InHandle, Spec, PanSpec);

        Add_Step("heat the pan", n"Step_Heat");
        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanBodyAdded", 0, 3.0f);
        Add_Step("add two pieces", n"Step_AddTwo");
        Add_Step_WaitUntil("both pieces landed on the pan", n"Check_BothOnPan", 0, 3.0f);
        Add_Step("tilt the pan", n"Step_Tilt");
        Add_Step_WaitUntil("the first piece's face on the pan seared", n"Check_FirstDownFaceSeared", 0, 2.0f);
        Add_Step("reset", n"Step_Reset");
        Add_Step_WaitUntil("both old piece entities are gone", n"Check_OldPiecesGone", 0, 2.0f);
        Add_Step_WaitSeconds("watch the empty pan", k_WatchSeconds);
        Add_Step("an empty, level, cold pan with a zero tally", n"Step_AssertReset");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AddTwo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AddPieceAt(k_LeftLocal);
        AddPieceAt(k_RightLocal);
    }

    UFUNCTION()
    private void Check_BothOnPan(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_AddedIds.Num() == 2 && Get_IsOnPan(_AddedIds[0]) && Get_IsOnPan(_AddedIds[1]));
    }

    UFUNCTION()
    private void Step_Tilt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Look(FVector(15.0, 0.0, 0.0));
    }

    UFUNCTION()
    private void Step_Reset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 2, "two pieces are on the pan before the reset");
        for (const auto& PieceId : _AddedIds)
        {
            const auto Piece = _Searing.Get_PieceEntity(PieceId);
            Assert_True(ck::IsValid(Piece), f"piece {utils_cooking_feed::Get_PieceName(PieceId)} is live before the reset");
            _OldPieces.Add(Piece);
        }

        Assert_Equals_Float(_Searing.Get_PanTilt().Roll, 18.0, 0.01, "the pan is tilted before the reset");
        Assert_True(_Searing.Get_SearedFaceCount(Get_FirstId()) >= 1, "a face is seared before the reset");
        Assert_True(_Searing.Get_IsHot(), "the pan is hot before the reset");

        _Searing.Request_Reset(FMars_Request_Searing_Reset());
    }

    UFUNCTION()
    private void Check_OldPiecesGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllGone = _OldPieces.Num() == 2;
        for (const auto& Piece : _OldPieces)
        {
            if (ck::IsValid(Piece))
            { AllGone = false; }
        }

        auto Res = OutResult;
        Res.Set(AllGone);
    }

    UFUNCTION()
    private void Step_AssertReset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 0, "the reset emptied the pan");
        Assert_Equals_Int(_Added.Num(), 2, "nothing was added after the reset");
        for (const auto& PieceId : _AddedIds)
        { Assert_False(_Searing.Get_HasPiece(PieceId), f"piece {utils_cooking_feed::Get_PieceName(PieceId)} is gone"); }

        const auto Tilt = _Searing.Get_PanTilt();
        Assert_Equals_Float(Tilt.Roll, 0.0, 0.001, "the reset levelled the roll");
        Assert_Equals_Float(Tilt.Pitch, 0.0, 0.001, "the reset levelled the pitch");
        Assert_Equals_Float(_Searing.Get_PanLift(), 0.0, 0.001, "no lift after the reset");

        Assert_False(_Searing.Get_IsHot(), "the reset chilled the pan");
        Assert_True(_Heats.Num() > 0 && _Heats.Last() == EMars_Searing_Heat::Cold, "OnHeatChanged reported the chill");
        Assert_True(_Searing.Get_Sizzle() == EMars_Searing_Sizzle::Quiet, "an empty pan is quiet");

        const auto Tally = _Searing.Get_Tally();
        Assert_Equals_Float(Tally.Seconds, 0.0, 0.0001, "the tally's seconds are zero");
        Assert_Equals_Int(Tally.Flips, 0, "the tally's flips are zero");
        Assert_Equals_Int(Tally.Losses, 0, "the tally's losses are zero");

        const auto Summary = _Searing.Get_Summary();
        Assert_Equals_Int(Summary.Admitted, 0, "the summary admits nothing");
        Assert_Equals_Int(Summary.Cooking + Summary.Ready + Summary.Lost, 0, "the summary is empty");
    }
}

class AMars_AutoTest_Searing_ResetDestroysEveryPieceLevelsThePanAndChills_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 10.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_ResetDestroysEveryPieceLevelsThePanAndChills;
}
