// Two sensed owners that publish no AttachPoint.Mars.Head - one without AttachPoints at all, one publishing only Back -
// fire the gaze's ensure and are never selected, although both are nearer than a third owner with a Head, which the
// gaze looks at. Each is reported once while it stays sensed (two reported owners, not a report per pass), and moving
// them out of range clears the reports. Isolated Z band: -57500.
class UMars_AutoTest_Gaze_TargetWithoutHeadEnsures : UMars_AutoTestRig_Gaze
{
    default _TimeoutSeconds = 8.0f;

    private FVector _Origin = FVector(0.0, 0.0, -57500.0);
    private FCk_Handle _NoAttachPoints;
    private FCk_Handle _BackOnly;
    private FCk_Handle _WithHead;
    private int32 _TargetChangedCount = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto EyeNode = Make_EyeNode(InHandle, _Origin);
        _Gaze = utils_gaze::Add(EyeNode, MakeSpec());
        _Gaze.BindTo_OnTargetChanged(FMars_Delegate_Gaze_OnTargetChanged(this, n"OnTargetChanged"));

        _NoAttachPoints = MakeOwner(InHandle, _Origin + FVector(120.0, 60.0, 0.0));

        _BackOnly = MakeOwner(InHandle, _Origin + FVector(120.0, -60.0, 0.0));
        PublishPoint(_BackOnly, GameplayTags::AttachPoint_Mars_Back);

        _WithHead = MakeOwner(InHandle, _Origin + FVector(250.0, 0.0, 0.0));
        PublishPoint(_WithHead, GameplayTags::AttachPoint_Mars_Head);

        Add_Step_WaitUntil("all three owners are sensed and the gaze looks at the one with a Head", n"Check_LooksAtWithHead");
        Add_Step_WaitSeconds("let the gaze keep evaluating the headless owners", 0.25);
        Add_Step("the gaze never selected a headless owner and reported each once", n"Step_AssertOnlyWithHead");
        Add_Step("move both headless owners out of range", n"Step_MoveHeadlessAway");
        Add_Step_WaitUntil("neither headless owner is sensed and no report remains", n"Check_ReportsCleared");
        Add_Step("the gaze still looks at the owner with a Head", n"Step_AssertStillWithHead");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnTargetChanged(FCk_Handle_Gaze InGaze, FCk_Handle_Transform InPrevious, FCk_Handle_Transform InCurrent)
    {
        ++_TargetChangedCount;
    }

    UFUNCTION()
    private void Check_LooksAtWithHead(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(DoGet_IsSensed(_NoAttachPoints) && DoGet_IsSensed(_BackOnly) && DoGet_IsSensed(_WithHead) &&
                _Gaze.Get_Target() == DoGet_Head(_WithHead));
    }

    UFUNCTION()
    private void Step_AssertOnlyWithHead(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Gaze.Get_Target() == DoGet_Head(_WithHead), "the gaze still looks at the owner with a Head");
        Assert_Equals_Int(_TargetChangedCount, 1, "OnTargetChanged fired once: only the owner with a Head was ever selected");
        Assert_Equals_Int(_Gaze.Get_ReportedOwnerCount(), 2, "both headless owners are reported while sensed");
    }

    UFUNCTION()
    private void Step_MoveHeadlessAway(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_transform::Request_SetLocation(_NoAttachPoints.As_Transform(), FCk_Request_Transform_SetLocation(_Origin + FVector(-1000.0, 60.0, 0.0)));
        utils_transform::Request_SetLocation(_BackOnly.As_Transform(), FCk_Request_Transform_SetLocation(_Origin + FVector(-1000.0, -60.0, 0.0)));
    }

    UFUNCTION()
    private void Check_ReportsCleared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(DoGet_IsSensed(_NoAttachPoints) == false && DoGet_IsSensed(_BackOnly) == false &&
                _Gaze.Get_ReportedOwnerCount() == 0);
    }

    UFUNCTION()
    private void Step_AssertStillWithHead(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Gaze.Get_Target() == DoGet_Head(_WithHead), "the gaze looks at the owner with a Head after the others left");
        Assert_Equals_Int(_TargetChangedCount, 1, "OnTargetChanged did not fire again after the headless owners left");
    }
}

// Hand-authored so the gaze's ensure on each headless owner is an expected error rather than a failure.
class AMars_AutoTest_Gaze_TargetWithoutHeadEnsures_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 8.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Gaze_TargetWithoutHeadEnsures;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("which publishes no [AttachPoint.Mars.Head] attach point - not a look target");
        return Out;
    }
}
