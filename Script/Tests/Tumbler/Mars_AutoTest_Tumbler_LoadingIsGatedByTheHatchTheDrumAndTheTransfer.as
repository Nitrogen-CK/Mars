// A piece released at the shut hatch is rejected (the reason names Closed) and makes nothing. With the hatch open a piece is
// accepted as a node under the drum at coverage 0; the same Id again is rejected, and past Drum.Capacity (6) a seventh slot
// is rejected naming the capacity, after which the drum cannot load. A transfer in flight refuses a press on the open hatch
// (LoadingInFlight) and on the lever; once it lands the hatch may toggle again.
class UMars_AutoTest_Tumbler_LoadingIsGatedByTheHatchTheDrumAndTheTransfer : UMars_AutoTestRig_Tumbler
{
    default _TimeoutSeconds = 10.0f;

    private int32 _RefusalsBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());

        Add_Step_WaitUntil("the station's nodes are posed", n"Check_NodesPosed", 0, 2.0f);
        Add_Step("release slot 0 at the shut hatch", n"Step_AddFirst");
        Add_Step_WaitUntil("the release is answered", n"Check_Answered1", 0, 1.0f);
        Add_Step_WaitFrames("anything made would show", 2);
        Add_Step("rejected at the shut hatch, nothing made", n"Step_AssertRejectedClosed");
        Add_Steps_OpenHatch();
        Add_Step("release slot 0 at the open hatch", n"Step_AddFirst");
        Add_Step_WaitUntil("the release is answered", n"Check_Answered2", 0, 1.0f);
        Add_Step("accepted as a node under the drum at coverage 0", n"Step_AssertAccepted");
        Add_Step("release slot 0 again, then slots 1 to 6", n"Step_AddTheRest");
        Add_Step_WaitUntil("all eight releases are answered", n"Check_Answered9", 0, 1.0f);
        Add_Step("the duplicate and the seventh are rejected", n"Step_AssertFull");
        Add_Step("a transfer is in flight", n"Step_LoadingInFlight");
        Add_Step_WaitUntil("the drum knows", n"Check_InFlight", 0, 1.0f);
        Add_Step("look at the open hatch", n"Step_LookToHatch");
        Add_Step_WaitUntil("the hatch is hovered", n"Check_HoveredHatch", 0, 2.0f);
        Add_Step("press on the open hatch", n"Step_PressCounted");
        Add_Step_WaitUntil("the press is answered", n"Check_Refused", 0, 1.0f);
        Add_Step("refused as LoadingInFlight", n"Step_AssertInFlightRefusal");
        Add_Step("look at the lever", n"Step_LookToLever");
        Add_Step_WaitUntil("the lever is hovered", n"Check_HoveredLever", 0, 2.0f);
        Add_Step("press on the lever", n"Step_PressCounted");
        Add_Step_WaitUntil("the press is answered", n"Check_Refused", 0, 1.0f);
        Add_Step("the lever press was refused", n"Step_AssertLeverRefused");
        Add_Step("the transfer lands", n"Step_LoadingIdle");
        Add_Step_WaitUntil("the hatch may toggle again", n"Check_CanToggle", 0, 1.0f);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AddFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AddPiece(0);
    }

    UFUNCTION()
    private void Check_Answered1(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 1);
    }

    UFUNCTION()
    private void Check_Answered2(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 2);
    }

    UFUNCTION()
    private void Check_Answered9(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 9);
    }

    UFUNCTION()
    private void Step_AssertRejectedClosed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Admissions[0] == EMars_CookingFeed_Admission::Rejected, "rejected");
        Assert_True(_AdmissionReasons[0].Contains("Closed"), f"the reason names the shut hatch (got {_AdmissionReasons[0]})");
        Assert_Equals_Int(_Added.Num(), 0, "no OnPieceAdded");
        Assert_Equals_Int(_Tumbler.Get_PieceCount(), 0, "nothing in the drum");
    }

    UFUNCTION()
    private void Step_AssertAccepted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Admissions[1] == EMars_CookingFeed_Admission::Accepted, f"accepted (reason: {_AdmissionReasons[1]})");
        Assert_Equals_Int(_Added.Num(), 1, "one OnPieceAdded");
        if (_Added.Num() < 1)
        { return; }

        const auto Piece = _Added[0];
        Assert_Valid(Piece, "the piece node is valid");
        Assert_True(_AddedIds[0].Get_IsSame(Make_Id(0)), "the added piece carries slot 0's Id");
        const FCk_Handle Drum = _Spec.Nodes.Drum;
        Assert_True(utils_entity_lifetime::Get_LifetimeOwner(Piece) == Drum, "the piece node is a lifetime child of the drum");
        Assert_Equals_Float(_Tumbler.Get_PieceCoverage(Make_Id(0)), 0.0, 0.0, "a new piece has no coverage");
        Assert_Equals_Int(_Tumbler.Get_PieceCount(), 1, "one piece in the drum");
    }

    UFUNCTION()
    private void Step_AddTheRest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AddPiece(0);
        for (int32 Slot = 1; Slot <= 6; ++Slot)
        { AddPiece(Slot); }
    }

    UFUNCTION()
    private void Step_AssertFull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Admissions[2] == EMars_CookingFeed_Admission::Rejected, "the duplicate is rejected");
        Assert_True(_AdmissionReasons[2].Contains("already in"), f"the reason names the duplicate (got {_AdmissionReasons[2]})");
        for (int32 Index = 3; Index < 8; ++Index)
        { Assert_True(_Admissions[Index] == EMars_CookingFeed_Admission::Accepted, f"slot {Index - 2} is accepted (reason: {_AdmissionReasons[Index]})"); }

        Assert_True(_Admissions[8] == EMars_CookingFeed_Admission::Rejected, "the seventh slot is rejected");
        Assert_True(_AdmissionReasons[8].Contains("Capacity"), f"the reason names the capacity (got {_AdmissionReasons[8]})");
        Assert_Equals_Int(_Tumbler.Get_PieceCount(), _Spec.Drum.Capacity, "the drum is full");
        Assert_Equals_Int(_Added.Num(), _Spec.Drum.Capacity, "one OnPieceAdded per accepted piece");
        Assert_False(_Tumbler.Get_CanLoad(), "a full drum cannot load");
    }

    UFUNCTION()
    private void Step_LoadingInFlight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        SetLoading(EMars_Tumbler_Loading::InFlight);
    }

    UFUNCTION()
    private void Check_InFlight(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Tumbler.Get_Loading() == EMars_Tumbler_Loading::InFlight);
    }

    UFUNCTION()
    private void Step_PressCounted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _RefusalsBefore = _Refusals.Num();
        Press();
    }

    UFUNCTION()
    private void Check_Refused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Refusals.Num() > _RefusalsBefore);
    }

    UFUNCTION()
    private void Step_AssertInFlightRefusal(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Refusals.Last() == EMars_Tumbler_Refusal::LoadingInFlight, f"refused as LoadingInFlight (got {_Refusals.Last() :n})");
        Assert_True(Check_Hatch(EMars_Tumbler_Hatch::Open), "the hatch stays open");
        Assert_False(_Tumbler.Get_CanToggleHatch(), "the hatch cannot toggle with a transfer in flight");
    }

    UFUNCTION()
    private void Step_AssertLeverRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Check_HandMode(EMars_Tumbler_HandMode::Free), "the hand stays free");
        Assert_Equals_Int(Count_Modes(EMars_Tumbler_HandMode::Reaching, 0), 0, "the hand never reached");
        Log(f"[Mars_AutoTest_Tumbler_LoadingIsGatedByTheHatchTheDrumAndTheTransfer] lever press refused: {_Refusals.Last() :n}");
    }

    UFUNCTION()
    private void Step_LoadingIdle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        SetLoading(EMars_Tumbler_Loading::Idle);
    }

    UFUNCTION()
    private void Check_CanToggle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Tumbler.Get_CanToggleHatch());
    }
}
