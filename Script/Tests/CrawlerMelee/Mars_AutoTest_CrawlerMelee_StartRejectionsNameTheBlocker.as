// A start the kernel cannot admit is rejected once, named by the preferred attack's first blocker, and recorded as a
// Rejected history event. A passive armed crawler stands still; one tagged target is moved around it:
//   - with no combat target the start rejection reads NoTarget, and a start at the target is rejected as TargetInvalid
//     (admission checks the requested target first, so NoTarget is a read, not a Rejected event);
//   - two same-frame SetCombatTarget requests drain into one OnTargetChanged (no target -> the target);
//   - the target 300 cm ahead: OutOfRange; 80 cm to the right: Facing; 90 cm ahead while the crawler creeps forward: Moving;
//   - clearing the combat target broadcasts OnTargetChanged once more (the target -> no target).
// Each rejection waits on the drained request and its history event, never on a frame count.
class UMars_AutoTest_CrawlerMelee_StartRejectionsNameTheBlocker : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(-330000.0, -150000.0, 600.0);

    private const FVector k_HalfExtents = FVector(10.0, 20.0, 20.0);
    private const float32 k_CreepSpeed = 30.0f;

    private FVector _TargetGoal;
    private TArray<FCk_Handle> _ChangedFrom;
    private TArray<FCk_Handle> _ChangedTo;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(4));

        Add_SettleSteps();
        Add_Step("spawn the target 300 cm ahead; bind OnTargetChanged", n"Step_SpawnTarget");
        Add_Step("no combat target: the rejection reads NoTarget; start at the target anyway", n"Step_StartWithoutTarget");
        Add_Step_WaitUntil("the start drained and was rejected", n"Check_StartRejected", k_SlowPolls, 0);
        Add_Step("rejected as TargetInvalid; select the target twice in one frame", n"Step_SelectTarget");
        Add_Step_WaitUntil("the combat target drained", n"Check_TargetAcquired", k_SlowPolls, 0);
        Add_Step("one OnTargetChanged; start out of range", n"Step_StartOutOfRange");
        Add_Step_WaitUntil("the start drained and was rejected", n"Check_StartRejected", k_SlowPolls, 0);
        Add_Step("rejected as OutOfRange; move the target 80 cm to the right", n"Step_MoveTargetAside");
        Add_Step_WaitUntil("the target stands to the side", n"Check_TargetAtGoal", k_SlowPolls, 0);
        Add_Step("start at the side target", n"Step_Start");
        Add_Step_WaitUntil("the start drained and was rejected", n"Check_StartRejected", k_SlowPolls, 0);
        Add_Step("rejected as Facing; move the target 90 cm ahead", n"Step_MoveTargetAhead");
        Add_Step_WaitUntil("the target stands ahead and a start would be admitted", n"Check_Admissible", k_SlowPolls, 0);
        Add_Step("creep forward", n"Step_Creep");
        Add_Step_WaitUntil("the crawler is moving", n"Check_Moving", k_SlowPolls, 0);
        Add_Step("start while moving", n"Step_Start");
        Add_Step_WaitUntil("the start drained and was rejected", n"Check_StartRejected", k_SlowPolls, 0);
        Add_Step("rejected as Moving; stop and clear the combat target", n"Step_StopAndClear");
        Add_Step_WaitUntil("the combat target cleared", n"Check_TargetCleared", k_SlowPolls, 0);
        Add_Step("OnTargetChanged ran once per changing drain", n"Step_AssertTargetChanges");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Crawler.BindTo_OnTargetChanged(FMars_Delegate_Crawler_OnTargetChanged(this, n"OnTargetChanged"));
        _Target = SpawnCombatTargetAt(InHandle, Get_FacingTransform(Get_PointFromRoot(300.0, 0.0)), k_HalfExtents);
    }

    UFUNCTION()
    private void OnTargetChanged(FCk_Handle_Crawler InCrawler, FCk_Handle InOld, FCk_Handle InNew)
    {
        _ChangedFrom.Add(InOld);
        _ChangedTo.Add(InNew);
    }

    UFUNCTION()
    private void Step_StartWithoutTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Rejection = _Crawler.Get_StartRejection(_Target.Entity);
        const FString RejectionText = Rejection.IsSet() ? f"{Rejection.GetValue() :n}" : "none";
        Assert_True(Rejection.IsSet() && Rejection.GetValue() == EMars_Crawler_AttackReject::NoTarget,
            f"with no combat target the start rejection reads NoTarget (got {RejectionText})");
        Request_StartAndMark();
    }

    UFUNCTION()
    private void Step_SelectTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_RejectedOnce(EMars_Crawler_AttackReject::TargetInvalid, "a start at a target that is not the combat target");
        _Crawler.Request_SetCombatTarget(FMars_Request_Crawler_SetCombatTarget(_Target.Entity));
        _Crawler.Request_SetCombatTarget(FMars_Request_Crawler_SetCombatTarget(_Target.Entity));
    }

    UFUNCTION()
    private void Step_StartOutOfRange(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ChangedTo.Num(), 1, "two same-frame selections broadcast OnTargetChanged once");
        if (_ChangedTo.Num() == 1)
        { Assert_True(ck::Is_NOT_Valid(_ChangedFrom[0]) && _ChangedTo[0] == _Target.Entity, "it reported no target -> the target"); }

        Request_StartAndMark();
    }

    UFUNCTION()
    private void Step_MoveTargetAside(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_RejectedOnce(EMars_Crawler_AttackReject::OutOfRange, "a start at a target 300 cm ahead");
        MoveTargetTo(Get_PointFromRoot(0.0, 80.0));
    }

    UFUNCTION()
    private void Step_Start(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Request_StartAndMark();
    }

    UFUNCTION()
    private void Step_MoveTargetAhead(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_RejectedOnce(EMars_Crawler_AttackReject::Facing, "a start at a target 80 cm to the right");
        MoveTargetTo(Get_PointFromRoot(90.0, 0.0));
    }

    UFUNCTION()
    private void Step_Creep(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Motion = _Crawler.Get_Motion();
        utils_surface_motion::Request_Steering(Motion, FCk_Request_SurfaceMotion_Steering(Get_Forward(), k_CreepSpeed));
    }

    UFUNCTION()
    private void Step_StopAndClear(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_RejectedOnce(EMars_Crawler_AttackReject::Moving, "a start while the crawler creeps forward");
        Assert_Equals_Int(Count_RecordsSinceMark(EMars_Crawler_AttackPhase::Windup), 0, "no start was admitted");

        auto Motion = _Crawler.Get_Motion();
        utils_surface_motion::Request_Steering(Motion, FCk_Request_SurfaceMotion_Steering(Get_Forward(), 0.0f));
        _Crawler.Request_SetCombatTarget(FMars_Request_Crawler_SetCombatTarget(FCk_Handle()));
    }

    UFUNCTION()
    private void Step_AssertTargetChanges(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ChangedTo.Num(), 2, "OnTargetChanged ran once for the selection and once for the clear");
        if (_ChangedTo.Num() == 2)
        { Assert_True(_ChangedFrom[1] == _Target.Entity && ck::Is_NOT_Valid(_ChangedTo[1]), "the clear reported the target -> no target"); }
    }

    private void MoveTargetTo(FVector InGoal)
    {
        _TargetGoal = InGoal;
        auto Root = _Target.Root;
        utils_transform::Request_SetTransform(Root, Get_FacingTransform(InGoal));
    }

    UFUNCTION()
    private void Check_TargetAtGoal(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set((utils_transform::Get_EntityCurrentLocation(_Target.Root) - _TargetGoal).Size() < 0.1);
    }

    // The target stands where it was moved and nothing about the crawler or the target forbids a start: the positive proof
    // that the Moving rejection below comes from the creep alone.
    UFUNCTION()
    private void Check_Admissible(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set((utils_transform::Get_EntityCurrentLocation(_Target.Root) - _TargetGoal).Size() < 0.1 &&
            _Crawler.Get_StartRejection(_Target.Entity).IsSet() == false);
    }

    UFUNCTION()
    private void Check_Moving(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_surface_motion::Get_Velocity(_Crawler.Get_Motion()).Size() > 10.0);
    }

    UFUNCTION()
    private void Check_TargetCleared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_HasPendingCombatRequests() == false && ck::Is_NOT_Valid(_Crawler.Get_CombatTarget()));
    }
}
