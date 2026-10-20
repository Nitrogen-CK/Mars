// With the hatch open, box 0 is accepted as piece 0 and comes to rest inside the shell. Then, in one drain: box 0 again
// (under a new Id) is rejected as already admitted, box 1 under piece 0's Id is rejected as already in, boxes 2 to 6 are
// accepted, and box 7, past Drum.Capacity (6), is rejected naming the capacity, after which the drum cannot load.
class UMars_AutoTest_Tumbler_AdmissionRefusesADuplicateAndAFullDrum : UMars_AutoTestRig_Tumbler
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_Boxes(8);

        Add_Steps_StationReady();
        Add_Steps_OpenHatch();
        Add_Step("release box 0", n"Step_AddFirst");
        Add_Step_WaitUntil("the release is answered", n"Check_Answered1", 0, 0);
        Add_Step("accepted", n"Step_AssertAccepted");
        Add_Step_WaitUntil("it rests inside the shell", n"Check_AllAtRest", k_SlowPolls, 0);
        Add_Step("release box 0 again, box 1 as piece 0, then boxes 2 to 7", n"Step_AddTheRest");
        Add_Step_WaitUntil("all nine releases are answered", n"Check_Answered9", 0, 0);
        Add_Step("the duplicates and the seventh are rejected", n"Step_AssertFull");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AddFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Admit(0);
    }

    UFUNCTION()
    private void Check_Answered1(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 1);
    }

    UFUNCTION()
    private void Check_Answered9(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 9);
    }

    UFUNCTION()
    private void Step_AssertAccepted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Admissions[0] == EMars_CookingFeed_Admission::Accepted, f"accepted (reason: {_AdmissionReasons[0]})");
        Assert_Equals_Int(_Tumbler.Get_PieceCount(), 1, "one piece in the drum");
        Assert_Equals_Float(_Tumbler.Get_PieceCoverage(Make_Id(0)), 0.0, 0.0, "a raw piece has no coverage");
    }

    UFUNCTION()
    private void Step_AddTheRest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Admit_As(0, 7);
        Admit_As(1, 0);
        for (int32 Slot = 2; Slot <= 7; ++Slot)
        { Admit(Slot); }
    }

    UFUNCTION()
    private void Step_AssertFull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Admissions[1] == EMars_CookingFeed_Admission::Rejected, "box 0 again is rejected");
        Assert_True(_AdmissionReasons[1].Contains("already admitted"), f"the reason names the box (got {_AdmissionReasons[1]})");
        Assert_True(_Admissions[2] == EMars_CookingFeed_Admission::Rejected, "piece 0's Id again is rejected");
        Assert_True(_AdmissionReasons[2].Contains("already in"), f"the reason names the Id (got {_AdmissionReasons[2]})");
        for (int32 Index = 3; Index < 8; ++Index)
        { Assert_True(_Admissions[Index] == EMars_CookingFeed_Admission::Accepted, f"box {Index - 1} is accepted (reason: {_AdmissionReasons[Index]})"); }

        Assert_True(_Admissions[8] == EMars_CookingFeed_Admission::Rejected, "the seventh is rejected");
        Assert_True(_AdmissionReasons[8].Contains("Capacity"), f"the reason names the capacity (got {_AdmissionReasons[8]})");
        Assert_Equals_Int(_Tumbler.Get_PieceCount(), _Spec.Drum.Capacity, "the drum is full");
        Assert_Equals_Int(_Added.Num(), _Spec.Drum.Capacity, "one OnPieceAdded per accepted piece");
        Assert_False(ck::IsValid(_Boxes[1].TryGet_Holder()), "the refused box 1 is held by no ledger");
        Assert_False(ck::IsValid(_Boxes[7].TryGet_Holder()), "the refused box 7 is held by no ledger");
        Assert_True(_Tumbler.TryGet_LoadRefusal() == EMars_Tumbler_LoadRefusal::Full, "a full drum refuses a load as Full");
    }
}
