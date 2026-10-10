// A refilled source never reuses a piece id. The feed draws from the rig's six-piece platter. The first press reserves the
// top of the pile and its release is the attempt's transfer 0; while that release awaits its admission a seventh piece is
// loaded onto the source, so the pile is six high again when the answer (Accepted, by hand) sends the hand home. The next
// press reserves the top again, and its release is transfer 1: an id counts transfers, not places in the pile. A Searing
// kernel beside the feed (the rig's Build_Searing, on a box pan) is handed both releases through its station's admission
// inbox and admits both: neither is refused as already on the pan.
class UMars_AutoTest_CookingFeed_ARefilledSourceNeverReusesAPieceId : UMars_AutoTestRig_CookingFeed
{
    // Where the refill is built, beside the platter.
    private const FVector k_RefillOffset = FVector(50.0, -60.0, 0.0);

    private FCk_Handle_FoodPiece _Refill;
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
        Add_Step_WaitUntil("the first piece awaits admission", n"Check_AwaitingAdmission", 0, 0);
        Add_Step("hand the release to the pan, refill the source and accept", n"Step_ForwardRefillAndAccept");
        Add_Step_WaitUntil("the hand is at rest and the refill froze on the pile", n"Check_RestAndRefilled", k_SlowPolls, 0);
        Add_Step("press add food again", n"Step_Begin");
        Add_Step_WaitUntil("the second piece awaits admission", n"Check_AwaitingAdmission", 0, 0);
        Add_Step("hand the release to the pan and accept", n"Step_ForwardAndAccept");
        Add_Step_WaitUntil("the pan answered both releases", n"Check_PanAnsweredBoth", 0, 0);
        Add_Step("transfers 0 and 1 of one attempt, both admitted", n"Step_AssertDistinctAndAdmitted");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_ForwardRefillAndAccept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Releases.Num(), 1, "one release so far");
        const auto Release = _Releases.Last();
        utils_cooking_feed::Request_Admit(_SearingStation, Release);

        _Refill = Build_Piece(Get_BoxMesh(), FTransform(FRotator::ZeroRotator, k_Origin + k_PlatterLocal + k_RefillOffset), Make_Spec(0.1));
        _Platter.Request_Load(FMars_Request_Platter_Load(_Refill));

        Resolve(Release.PieceId, EMars_CookingFeed_Admission::Accepted);
    }

    UFUNCTION()
    private void Check_RestAndRefilled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle && _Platter.Get_Held().Contains(_Refill)
            && _Platter.Get_HeldCount() == k_Stock && _Platter.Get_PendingCount() == 0);
    }

    UFUNCTION()
    private void Step_ForwardAndAccept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Releases.Num(), 2, "two releases");
        const auto Release = _Releases.Last();
        utils_cooking_feed::Request_Admit(_SearingStation, Release);
        Resolve(Release.PieceId, EMars_CookingFeed_Admission::Accepted);
    }

    UFUNCTION()
    private void Check_PanAnsweredBoth(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 2);
    }

    UFUNCTION()
    private void Step_AssertDistinctAndAdmitted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Releases.Num(), 2, "two releases");
        if (_Releases.Num() != 2)
        { return; }

        const auto Generation = _Feed.Get_Generation();
        const auto First = _Releases[0].PieceId;
        const auto Second = _Releases[1].PieceId;
        Assert_True(First.Generation == Generation && Second.Generation == Generation, "both releases belong to the one attempt");
        Assert_Equals_Int(First.TransferIndex, 0, "the first release is transfer 0");
        Assert_Equals_Int(Second.TransferIndex, 1, "the second release is transfer 1");
        Assert_False(First.Get_IsSame(Second), "the two ids differ");
        Assert_Equals_String(utils_cooking_feed::Get_PieceName(Second), f"g{Generation}#1", "the second release's name");

        Assert_Equals_Int(_Admissions.Num(), 2, "the pan answered two releases");
        for (int32 Index = 0; Index < _Admissions.Num(); ++Index)
        {
            Assert_True(_Admissions[Index] == EMars_CookingFeed_Admission::Accepted,
                f"release {utils_cooking_feed::Get_PieceName(_AdmissionIds[Index])} was admitted (reason: {_AdmissionReasons[Index]})");
            Assert_False(_AdmissionReasons[Index].Contains("already on the pan"), "no release was refused as already on the pan");
        }

        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 2, "the pan holds both pieces");
        Assert_Equals_Int(Get_SettleCount(EMars_CookingFeed_Settle::Admitted), 2, "the feed settled both Admitted");
    }

    UFUNCTION()
    private void OnPieceAdmission(FCk_Handle InStation, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Admission InAdmission, FString InReason)
    {
        _AdmissionIds.Add(InPieceId);
        _Admissions.Add(InAdmission);
        _AdmissionReasons.Add(InReason);
    }
}
