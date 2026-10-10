// A release at the shut hatch is rejected naming the hatch (Closed) and the box is left as it was: no holder, still
// bodiless where it waited, no record and no OnPieceAdded. With the hatch open the same release is accepted and the station
// holds the box.
class UMars_AutoTest_Tumbler_AdmissionNeedsTheHatchOpen : UMars_AutoTestRig_Tumbler
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_Boxes(1);

        Add_Steps_StationReady();
        Add_Step("release box 0 at the shut hatch", n"Step_Admit");
        Add_Step_WaitUntil("the release is answered", n"Check_Answered1", 0, 0);
        Add_Step_WaitFrames("anything adopted would show", 2);
        Add_Step("rejected at the shut hatch, the box untouched", n"Step_AssertRejected");
        Add_Steps_OpenHatch();
        Add_Step("release box 0 at the open hatch", n"Step_Admit");
        Add_Step_WaitUntil("the release is answered", n"Check_Answered2", 0, 0);
        Add_Step("accepted: the station holds the box", n"Step_AssertAccepted");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Admit(FCk_Handle InHandle, FInstancedStruct InPayload)
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
    private void Check_Answered2(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 2);
    }

    UFUNCTION()
    private void Step_AssertRejected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Admissions[0] == EMars_CookingFeed_Admission::Rejected, "rejected");
        Assert_True(_AdmissionReasons[0].Contains("Closed"), f"the reason names the shut hatch (got {_AdmissionReasons[0]})");
        Assert_Equals_Int(_Added.Num(), 0, "no OnPieceAdded");
        Assert_Equals_Int(_Tumbler.Get_PieceCount(), 0, "nothing in the drum");

        const auto Box = _Boxes[0];
        FCk_Handle BoxEntity = Box;
        Assert_False(ck::IsValid(Box.TryGet_Holder()), "no ledger holds the box");
        Assert_False(BoxEntity.Is_JoltBody(), "the box got no body");
        const auto Error = (utils_transform::Get_EntityCurrentLocation(BoxEntity.As_Transform()) - (k_Origin + k_BoxShelfLocal)).Size();
        Assert_True(Error <= k_PoseTolerance, f"the box is where it waited ({Error :.3} cm off)");
    }

    UFUNCTION()
    private void Step_AssertAccepted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Admissions[1] == EMars_CookingFeed_Admission::Accepted, f"accepted (reason: {_AdmissionReasons[1]})");
        Assert_Equals_Int(_Added.Num(), 1, "one OnPieceAdded");
        Assert_Equals_Int(_Tumbler.Get_PieceCount(), 1, "one piece in the drum");
        Assert_True(_Boxes[0].TryGet_Holder() == _StationEntity, "the station holds the box");
    }
}
