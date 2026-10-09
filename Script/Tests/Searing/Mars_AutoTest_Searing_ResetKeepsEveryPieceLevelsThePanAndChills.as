// A reset mid-session (hot, tilted, two pieces on the pan, one face seared) keeps both pieces on the pan with their sear
// (the player's food is theirs): the same entities, still on the books and still cooking, nothing destroyed and nothing
// added. The tally is zeroed by the reset (read before the levelling pan can tumble the kept pieces into new flips), and
// the pan is levelled, idled and chilled.
class UMars_AutoTest_Searing_ResetKeepsEveryPieceLevelsThePanAndChills : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 10.0f;

    // Pan-local: either side of the centre, a gap between the two boxes.
    private const FVector k_LeftLocal = FVector(-8.0, 0.0, 8.0);
    private const FVector k_RightLocal = FVector(8.0, 0.0, 8.0);
    // How long the pan is watched after the reset for a piece destroyed or added.
    private const float32 k_WatchSeconds = 0.5f;

    private TArray<FCk_Handle> _OldPieces;
    private TArray<float32> _FirstSearBeforeReset;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        auto PanSpec = FMars_Implement_Spec();
        PanSpec.Tilt.LevelReturnDegreesPerSecond = 0.0f;
        BuildStation(InHandle, Spec, PanSpec);
        Build_Pieces(2);

        Add_Step("heat the pan", n"Step_Heat");
        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanBodyAdded", 0, 3.0f);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", 0, 3.0f);
        Add_Step("add two pieces", n"Step_AddTwo");
        Add_Step_WaitUntil("both pieces landed on the pan", n"Check_BothOnPan", 0, 3.0f);
        Add_Step("tilt the pan", n"Step_Tilt");
        Add_Step_WaitUntil("the first piece's face on the pan seared", n"Check_FirstDownFaceSeared", 0, 2.0f);
        Add_Step("reset", n"Step_Reset");
        Add_Step_WaitFrames("the reset drains (a flip needs utils_searing::k_FaceSettleSeconds)", 2);
        Add_Step("the reset zeroed the tally and chilled the pan", n"Step_AssertTallyZeroed");
        Add_Step_WaitUntil("the reset reached the pan", n"Check_PanLevelAndIdle", 0, 1.0f);
        Add_Step_WaitSeconds("watch the pan", k_WatchSeconds);
        Add_Step("both pieces kept with their sear; a level, cold pan with a zero tally", n"Step_AssertReset");
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

        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        { _FirstSearBeforeReset.Add(_Searing.Get_FaceSear(Get_FirstId(), EMars_Searing_Face(Index))); }

        Assert_Equals_Float(_Searing.Get_PanTilt().Roll, 18.0, 0.01, "the pan is tilted before the reset");
        Assert_True(_Searing.Get_SearedFaceCount(Get_FirstId()) >= 1, "a face is seared before the reset");
        Assert_True(_Searing.Get_IsHot(), "the pan is hot before the reset");
        Assert_True(_Searing.Get_Tally().Seconds > 0.0f, "the tally ran before the reset");

        _Searing.Request_Reset(FMars_Request_Searing_Reset());
    }

    UFUNCTION()
    private void Step_AssertTallyZeroed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Searing.Get_IsHot(), "the reset chilled the pan");
        const auto Tally = _Searing.Get_Tally();
        Assert_Equals_Float(Tally.Seconds, 0.0, 0.0001, "the tally's seconds are zero");
        Assert_Equals_Int(Tally.Flips, 0, "the tally's flips are zero");
        Assert_Equals_Int(Tally.Losses, 0, "the tally's losses are zero");
    }

    UFUNCTION()
    private void Check_PanLevelAndIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Searing.Get_Pan().Get_Drive() == EMars_Implement_Drive::Idle && Math::Abs(_Searing.Get_PanTilt().Roll) < 0.001);
    }

    UFUNCTION()
    private void Step_AssertReset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 2, "the reset kept both pieces on the books");
        Assert_Equals_Int(_Added.Num(), 2, "nothing was added after the reset");
        for (int32 Index = 0; Index < _AddedIds.Num(); ++Index)
        {
            const auto PieceId = _AddedIds[Index];
            const auto PieceName = utils_cooking_feed::Get_PieceName(PieceId);
            Assert_True(_Searing.Get_HasPiece(PieceId), f"piece {PieceName} is still on the pan's books");
            Assert_True(ck::IsValid(_OldPieces[Index]), f"piece {PieceName}'s entity is still live");
            Assert_True(_Searing.Get_PieceEntity(PieceId) == _OldPieces[Index], f"piece {PieceName} is the same entity");
            Assert_True(_Searing.Get_PieceStatus(PieceId) == EMars_Searing_PieceStatus::Cooking, f"piece {PieceName} is still cooking");
        }

        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        {
            const auto Face = EMars_Searing_Face(Index);
            Assert_Equals_Float(_Searing.Get_FaceSear(Get_FirstId(), Face), _FirstSearBeforeReset[Index], 0.0001,
                f"the first piece's face {utils_searing::Get_FaceName(Face)} kept its sear through the reset");
        }

        Assert_True(_Searing.Get_SearedFaceCount(Get_FirstId()) >= 1, "the seared face is still seared");
        Assert_Equals_Int(_Lost.Num(), 0, "nothing was lost");

        const auto Tilt = _Searing.Get_PanTilt();
        Assert_Equals_Float(Tilt.Roll, 0.0, 0.001, "the reset levelled the roll");
        Assert_Equals_Float(Tilt.Pitch, 0.0, 0.001, "the reset levelled the pitch");
        Assert_Equals_Float(_Searing.Get_PanLift(), 0.0, 0.001, "no lift after the reset");

        Assert_False(_Searing.Get_IsHot(), "the reset chilled the pan");
        Assert_True(_Heats.Num() > 0 && _Heats.Last() == EMars_Searing_Heat::Cold, "OnHeatChanged reported the chill");
        Assert_True(_Searing.Get_Sizzle() == EMars_Searing_Sizzle::Quiet, "a cold pan is quiet");

        Assert_Equals_Float(_Searing.Get_Tally().Seconds, 0.0, 0.0001, "the tally's seconds stay zero (nothing sears on a cold pan)");

        const auto Summary = _Searing.Get_Summary();
        Assert_Equals_Int(Summary.Cooking, 2, "the summary has the two kept pieces cooking");
        Assert_Equals_Int(Summary.Admitted, 2, "the summary counts the two kept pieces");
    }
}

class AMars_AutoTest_Searing_ResetKeepsEveryPieceLevelsThePanAndChills_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 10.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_ResetKeepsEveryPieceLevelsThePanAndChills;
}
