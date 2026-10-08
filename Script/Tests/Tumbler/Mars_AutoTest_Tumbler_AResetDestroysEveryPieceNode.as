// Three admitted pieces are scene nodes under the drum; a Reset destroys every one of them (the nodes go invalid), empties
// the drum and shuts the hatch, and the drum loads again once the hatch is reopened.
class UMars_AutoTest_Tumbler_AResetDestroysEveryPieceNode : UMars_AutoTestRig_Tumbler
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());

        Add_Step_WaitUntil("the station's nodes are posed", n"Check_NodesPosed", 0, 2.0f);
        Add_Steps_OpenHatch();
        Add_Step("load pieces 0, 1 and 2", n"Step_AddThree");
        Add_Step_WaitUntil("three pieces are added", n"Check_Added3", 0, 1.0f);
        Add_Step("reset", n"Step_Reset");
        Add_Step_WaitUntil("every piece node is destroyed", n"Check_NodesGone", 0, 1.0f);
        Add_Step_WaitUntil("the hatch is closed", n"Check_HatchClosed", 0, 2.0f);
        Add_Step("the drum is empty and the hand free", n"Step_AssertEmpty");
        Add_Steps_OpenHatch();
        Add_Step("load piece 0 again", n"Step_AddFirst");
        Add_Step_WaitUntil("it is added", n"Check_Added4", 0, 1.0f);
        Add_Step("the drum loads again", n"Step_AssertReloaded");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AddThree(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (int32 Slot = 0; Slot < 3; ++Slot)
        { AddPiece(Slot); }
    }

    UFUNCTION()
    private void Step_AddFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AddPiece(0);
    }

    UFUNCTION()
    private void Check_Added3(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Added.Num() >= 3);
    }

    UFUNCTION()
    private void Check_Added4(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Added.Num() >= 4);
    }

    UFUNCTION()
    private void Step_Reset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (const auto& Piece : _Added)
        { Assert_Valid(Piece, "a piece node is valid before the reset"); }

        _Tumbler.Request_Reset(FMars_Request_Tumbler_Reset());
    }

    UFUNCTION()
    private void Check_NodesGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Gone = true;
        for (const auto& Piece : _Added)
        {
            if (ck::IsValid(Piece))
            { Gone = false; }
        }

        auto Res = OutResult;
        Res.Set(Gone);
    }

    UFUNCTION()
    private void Step_AssertEmpty(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Tumbler.Get_PieceCount(), 0, "the drum is empty");
        Assert_True(Check_HandMode(EMars_Tumbler_HandMode::Free), "the hand is free");
        Assert_False(_Tumbler.Get_HasPiece(Make_Id(0)), "piece 0 is gone");
    }

    UFUNCTION()
    private void Step_AssertReloaded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Admissions.Last() == EMars_CookingFeed_Admission::Accepted, f"piece 0 is accepted again (reason: {_AdmissionReasons.Last()})");
        Assert_Equals_Int(_Tumbler.Get_PieceCount(), 1, "one piece in the drum");
        Assert_Valid(_Added.Last(), "its node is valid");
    }
}
