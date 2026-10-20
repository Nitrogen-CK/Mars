// A release lands in the receiving station's admission inbox, and the kernel there drains it. The feed's own station has no
// receiving kernel: a release sent there is not queued (Request_Admit answers false). Sent to a Searing station (the rig's
// Build_Searing), the release is the one entry in that station's inbox when the station signals OnQueued; once the pan has
// drained it the inbox is empty, the pan answers Accepted on the station's OnAdmission and holds the piece, and the piece
// names the pan's station as its holder. Accepted by hand, the feed settles Admitted and the hand goes home.
class UMars_AutoTest_CookingFeed_AReleaseLandsInTheStationInbox : UMars_AutoTestRig_CookingFeed
{
    private FMars_CookingFeed_Release _Release;
    // The station's inbox as each OnQueued found it.
    private TArray<FMars_CookingFeed_Release> _QueuedInbox;
    private int32 _QueuedSignals = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildFeed(InHandle, Make_TestSpec());
        auto Owner = InHandle;
        Build_Searing(Owner);
        Record_Admissions(_SearingStation);
        utils_cooking_feed::BindTo_OnQueued(_SearingStation, FMars_Delegate_StationAdmission_OnQueued(this, n"OnStationQueued"));
        Add_Steps_SourceTheFeed();

        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanAdded", 0, 0);
        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the piece awaits admission", n"Check_AwaitingAdmission", 0, 0);
        Add_Step("send the release to the feed's own station, then to the pan's", n"Step_Send");
        Add_Step_WaitUntil("the pan answered", n"Check_Answered", 0, 0);
        Add_Step("the inbox held the release, the pan drained it and holds the piece; accept", n"Step_AssertDrainedAndAccept");
        Add_Step_WaitUntil("the feed is idle", n"Check_Idle", 0, 0);
        Add_Step("the feed settled Admitted", n"Step_AssertSettled");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Send(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Releases.Num(), 1, "one release");
        if (_Releases.Num() != 1)
        { return; }

        _Release = _Releases.Last();
        Assert_True(ck::IsValid(_Release.Piece), "the release carries its piece");
        Assert_False(utils_cooking_feed::Get_IsAdmitting(_Station), "no kernel receives at the feed's own station");
        Assert_True(utils_cooking_feed::Get_IsAdmitting(_SearingStation), "the pan receives at its station");
        Assert_False(utils_cooking_feed::Request_Admit(_Station, _Release), "a release sent where no kernel receives is not queued");
        Assert_Equals_Int(_QueuedSignals, 0, "nothing was queued at the pan yet");

        Assert_True(utils_cooking_feed::Request_Admit(_SearingStation, _Release), "the pan's station queues the release");
    }

    UFUNCTION()
    private void Check_Answered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 1);
    }

    UFUNCTION()
    private void Step_AssertDrainedAndAccept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_QueuedSignals, 1, "the station signalled OnQueued once");
        Assert_Equals_Int(_QueuedInbox.Num(), 1, "the inbox held one release when it was queued");
        if (_QueuedInbox.Num() == 1)
        {
            Assert_True(_QueuedInbox[0].PieceId.Get_IsSame(_Release.PieceId), "the inbox held the release's Id");
            Assert_True(_QueuedInbox[0].Piece == _Release.Piece, "the inbox held the release's piece");
        }

        Assert_Equals_Int(_SearingStation.Get_Fragment(FMars_Fragment_StationAdmission).Inbox.Num(), 0, "the pan drained the inbox");

        Assert_Equals_Int(_Admissions.Num(), 1, "one answer");
        if (_Admissions.Num() == 1)
        {
            Assert_True(_AdmissionIds[0].Get_IsSame(_Release.PieceId), "the answer names the release's Id");
            Assert_True(_Admissions[0] == EMars_CookingFeed_Admission::Accepted, f"the pan accepted it (reason: {_AdmissionReasons[0]})");
        }

        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 1, "the pan holds one piece");
        Assert_True(_Searing.Get_HasPiece(_Release.PieceId), "the pan holds the release's Id");
        Assert_True(_Release.Piece.TryGet_Holder() == _SearingStation, "the piece names the pan's station as its holder");

        Resolve(_Release.PieceId, EMars_CookingFeed_Admission::Accepted);
    }

    UFUNCTION()
    private void Step_AssertSettled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_SettleCount(EMars_CookingFeed_Settle::Admitted), 1, "the feed settled Admitted once");
        Assert_Equals_Int(_Settles.Num(), 1, "and nothing else");
        Assert_Ledger(k_Stock - 1, 1, "after the admission");
    }

    UFUNCTION()
    private void OnStationQueued(FCk_Handle InStation)
    {
        _QueuedSignals += 1;
        _QueuedInbox = InStation.Get_Fragment(FMars_Fragment_StationAdmission).Inbox;
    }
}
