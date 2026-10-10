// A kernel answers a release on its station's one OnAdmission signal, and that answer, forwarded as it is, is what the feed
// settles on (the station's bridge forwards it so). The test forwards the Searing station's OnAdmission (the rig's
// Build_Searing) to the feed and sends it the feed's release: one answer, Accepted, and the feed settles Admitted once and
// its hand goes home. The same release sent again is answered on the same signal, Rejected "already admitted"; forwarded,
// the feed ignores it (it awaits nothing): still one settle and one admitted, the pan still holds the one piece and is still
// its holder.
class UMars_AutoTest_CookingFeed_AnAdmissionAnswersThroughTheOneSignal : UMars_AutoTestRig_CookingFeed
{
    private FMars_CookingFeed_Release _Release;
    // In parallel: one entry per answer on the Searing station's OnAdmission.
    private TArray<FMars_CookingFeed_PieceId> _AdmissionIds;
    private TArray<EMars_CookingFeed_Admission> _Admissions;
    private TArray<FString> _AdmissionReasons;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildFeed(InHandle, Make_TestSpec());
        auto Owner = InHandle;
        Build_Searing(Owner);
        utils_cooking_feed::BindTo_OnAdmission(_SearingStation, FMars_Delegate_StationAdmission_OnAdmission(this, n"OnPieceAdmission"));
        Add_Steps_SourceTheFeed();

        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanAdded", 0, 0);
        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the piece awaits admission", n"Check_AwaitingAdmission", 0, 0);
        Add_Step("send the release to the pan", n"Step_Send");
        Add_Step_WaitUntil("the pan answered and the feed is idle", n"Check_AnsweredAndIdle", 0, 0);
        Add_Step("one Accepted answer, one Admitted settle; send the release again", n"Step_AssertAdmittedAndSendAgain");
        Add_Step_WaitUntil("the pan answered again", n"Check_Answered2", 0, 0);
        Add_Step_WaitFrames("the forwarded answer drains in the feed", 3);
        Add_Step("rejected as already admitted, and the feed spent nothing on it", n"Step_AssertDuplicateIgnored");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Send(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Releases.Num(), 1, "one release");
        if (_Releases.Num() != 1)
        { return; }

        _Release = _Releases.Last();
        Assert_True(utils_cooking_feed::Request_Admit(_SearingStation, _Release), "the pan's station queues the release");
    }

    UFUNCTION()
    private void Check_AnsweredAndIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 1 && _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle);
    }

    UFUNCTION()
    private void Step_AssertAdmittedAndSendAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Admissions.Num(), 1, "one answer");
        if (_Admissions.Num() == 1)
        {
            Assert_True(_AdmissionIds[0].Get_IsSame(_Release.PieceId), "the answer names the release's Id");
            Assert_True(_Admissions[0] == EMars_CookingFeed_Admission::Accepted, f"the pan accepted it (reason: {_AdmissionReasons[0]})");
        }

        Assert_Equals_Int(_Settles.Num(), 1, "the feed settled once");
        Assert_Equals_Int(Get_SettleCount(EMars_CookingFeed_Settle::Admitted), 1, "it settled Admitted");
        Assert_Ledger(k_Stock - 1, 1, "after the admission");

        Assert_True(utils_cooking_feed::Request_Admit(_SearingStation, _Release), "the pan's station queues the release again");
    }

    UFUNCTION()
    private void Check_Answered2(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 2);
    }

    UFUNCTION()
    private void Step_AssertDuplicateIgnored(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Admissions.Num(), 2, "two answers in all");
        if (_Admissions.Num() == 2)
        {
            Assert_True(_AdmissionIds[1].Get_IsSame(_Release.PieceId), "the second answer names the same Id");
            Assert_True(_Admissions[1] == EMars_CookingFeed_Admission::Rejected, "the repeat is rejected");
            Assert_True(_AdmissionReasons[1] == "already admitted", f"the reason names the repeat (got {_AdmissionReasons[1]})");
        }

        Assert_Equals_Int(_Settles.Num(), 1, "the feed still settled once");
        Assert_Ledger(k_Stock - 1, 1, "after the repeat");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, "the feed is idle");
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 1, "the pan holds one piece");
        Assert_True(_Release.Piece.TryGet_Holder() == _SearingStation, "the pan's station is still the piece's holder");
    }

    // Forwarded as it is, as the station's bridge does.
    UFUNCTION()
    private void OnPieceAdmission(FCk_Handle InStation, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Admission InAdmission, FString InReason)
    {
        _AdmissionIds.Add(InPieceId);
        _Admissions.Add(InAdmission);
        _AdmissionReasons.Add(InReason);
        _Feed.Request_ResolveAdmission(FMars_Request_CookingFeed_ResolveAdmission(InPieceId, InAdmission, InReason));
    }
}
