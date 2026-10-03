// Two sensed owners that publish no AttachPoint.Mars.Head - one without AttachPoints at all, one publishing only Back -
// fire the gaze's ensure and are never selected, although both are nearer than a third owner with a Head, which the
// gaze looks at. Each is reported once while it stays sensed (two reported owners, not a report per pass), and moving
// them out of range clears the reports. Isolated Z band: -57500.
class UMars_AutoTest_Gaze_TargetWithoutHeadEnsures : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 8.0f;

    private FVector _Origin = FVector(0.0, 0.0, -57500.0);
    private FCk_Handle_Gaze _Gaze;
    private FCk_Handle _NoAttachPoints;
    private FCk_Handle _BackOnly;
    private FCk_Handle _WithHead;
    private int32 _TargetChangedCount = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto EyeEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto EyeNode = utils_transform::Add(EyeEntity, FTransform(FRotator::ZeroRotator, _Origin), ECk_Replication::DoesNotReplicate);
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

    // Its own owner and context (so the gaze's probe may overlap it) with a kinematic Silent Probe.Mars.Player sphere like
    // the player's body probe, and no attach points.
    private FCk_Handle MakeOwner(FCk_Handle InHandle, FVector InLocation)
    {
        auto Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        Owner.Request_OverrideToSelf();
        auto Root = utils_transform::Add(Owner, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);

        auto BodyProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Player);
        BodyProbeSpec.Set_MotionType(ECk_MotionType::Kinematic)
                     .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent);
        utils_prefab::Create_ProbeNode_Sphere(Root, 20.0f, BodyProbeSpec);
        return Owner;
    }

    // Publishes a single attach point at the owner's origin.
    private void PublishPoint(FCk_Handle& InOwner, FGameplayTag InTag)
    {
        auto Root = InOwner.As_Transform();
        auto Node = utils_scene_node::Create(Root, FTransform::Identity).As_Transform();

        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(InTag, Node));
        utils_attach_points::Add(InOwner, AttachPointsSpec);
    }

    private FCk_Handle_Transform DoGet_Head(const FCk_Handle& InOwner) const
    {
        return InOwner.As_AttachPoints().Get_AttachPoint(GameplayTags::AttachPoint_Mars_Head);
    }

    // True when one of InOwner's probes is inside the gaze's sense trigger.
    private bool DoGet_IsSensed(const FCk_Handle& InOwner) const
    {
        const auto& State = _Gaze.Get_Fragment(FMars_Fragment_Gaze);
        for (auto Entity : State.Sense.Get_EntitiesInside())
        {
            if (ck::Ctx(Entity) == InOwner)
            { return true; }
        }
        return false;
    }

    private FMars_Gaze_Spec MakeSpec() const
    {
        auto Spec = FMars_Gaze_Spec();
        Spec.DetectionFilter.AddTag(GameplayTags::Probe_Mars_Player);
        Spec.AimPoint = GameplayTags::AttachPoint_Mars_Head;
        Spec.RangeCm = 300.0f;
        return Spec;
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
