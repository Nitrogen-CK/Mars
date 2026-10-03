// The gaze's eye node hangs under an owner that also carries a Probe.Mars.Player body probe and a Head attach point,
// 100 cm in front of the eye. The sense trigger shares that owner's context, so the owner's own probe is never sensed and
// its Head is never targeted, although it is the nearest Head in range. The positive control is a foreign stand-in at
// exactly that spot: it is sensed and takes the gaze from a foreign target 200 cm away, so the spot itself is eligible
// and only the shared context keeps the owner out. Isolated Z band: -57000.
class UMars_AutoTest_Gaze_NeverTargetsOwnOwner : UCk_AutoTest_Base
{
    private FVector _Origin = FVector(0.0, 0.0, -57000.0);
    private FVector _OwnHeadOffset = FVector(100.0, 0.0, 0.0);
    private FCk_Handle_Gaze _Gaze;
    private FCk_Handle _OwnOwner;
    private FCk_Handle _Foreign;
    private FCk_Handle _StandIn;
    private float64 _WindowStartSeconds = 0.0;
    private bool _EverTargetedOwnHead = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _OwnOwner = MakeTarget(InHandle, _Origin, _OwnHeadOffset);

        auto OwnRoot = _OwnOwner.As_Transform();
        auto EyeNode = utils_scene_node::Create(OwnRoot, FTransform::Identity).As_Transform();
        _Gaze = utils_gaze::Add(EyeNode, MakeSpec());
        _Gaze.BindTo_OnTargetChanged(FMars_Delegate_Gaze_OnTargetChanged(this, n"OnTargetChanged"));

        _Foreign = MakeTarget(InHandle, _Origin + FVector(200.0, 0.0, 0.0), FVector::ZeroVector);

        Add_Step("the eye node shares its context with its owner, the foreign target does not", n"Step_AssertContexts");
        Add_Step_WaitUntil("the gaze looks at the foreign target, never sensing its own owner", n"Check_LooksAtForeign");
        Add_Step("add a foreign stand-in at the owner's own Head", n"Step_AddStandIn");
        Add_Step_WaitUntil("the stand-in is sensed and takes the gaze, the own owner still unsensed", n"Check_LooksAtStandIn");
        Add_Step("the stand-in is its own context; start the window", n"Step_StartWindow");
        Add_Step_WaitUntil("for 0.25 s the gaze keeps evaluating without sensing its own owner", n"Check_WindowWithoutOwnOwner", 0, 2.0f);
        Add_Step("the gaze still looks at the stand-in and never looked at its own owner's Head", n"Step_AssertNeverOwn");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnTargetChanged(FCk_Handle_Gaze InGaze, FCk_Handle_Transform InPrevious, FCk_Handle_Transform InCurrent)
    {
        if (InCurrent == DoGet_Head(_OwnOwner))
        { _EverTargetedOwnHead = true; }
    }

    UFUNCTION()
    private void Step_AssertContexts(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::Ctx(_Gaze) == _OwnOwner, "the eye node's context is the owner carrying the body probe and Head");
        Assert_True(ck::Ctx(_Foreign) == _Foreign, "the foreign target is its own context");
    }

    UFUNCTION()
    private void Check_LooksAtForeign(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (Get_OwnOwnerStaysUnsensed() == false)
        { return; }

        Res.Set(_Gaze.Get_Target() == DoGet_Head(_Foreign));
    }

    UFUNCTION()
    private void Step_AddStandIn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _StandIn = MakeTarget(InHandle, _Origin + _OwnHeadOffset, FVector::ZeroVector);
    }

    UFUNCTION()
    private void Check_LooksAtStandIn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (Get_OwnOwnerStaysUnsensed() == false)
        { return; }

        Res.Set(DoGet_IsSensed(_StandIn) && _Gaze.Get_Target() == DoGet_Head(_StandIn));
    }

    UFUNCTION()
    private void Step_StartWindow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::Ctx(_StandIn) == _StandIn, "the stand-in is its own context");

        const auto StandInHead = utils_transform::Get_EntityCurrentLocation(DoGet_Head(_StandIn));
        const auto OwnHead = utils_transform::Get_EntityCurrentLocation(DoGet_Head(_OwnOwner));
        Assert_True(StandInHead.Equals(OwnHead, 0.01),
            f"the stand-in's Head is at the owner's own Head (stand-in [{StandInHead.ToString()}], own [{OwnHead.ToString()}])");

        _WindowStartSeconds = System::GetGameTimeInSeconds();
    }

    UFUNCTION()
    private void Check_WindowWithoutOwnOwner(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (Get_OwnOwnerStaysUnsensed() == false)
        { return; }

        Res.Set(System::GetGameTimeInSeconds() - _WindowStartSeconds >= 0.25);
    }

    UFUNCTION()
    private void Step_AssertNeverOwn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Gaze.Get_Target() == DoGet_Head(_StandIn), "the gaze still looks at the stand-in");
        Assert_False(_EverTargetedOwnHead, "OnTargetChanged never named the owner's own Head");
    }

    // Fails the test the first time the owner's own body probe is inside the gaze's sense trigger.
    private bool Get_OwnOwnerStaysUnsensed()
    {
        if (DoGet_IsSensed(_OwnOwner) == false)
        { return true; }

        FinishFailure("the gaze's sense trigger detected its own owner's body probe");
        return false;
    }

    // Its own owner and context (so the gaze's probe may overlap it), a kinematic Silent Probe.Mars.Player sphere like the
    // player's body probe, and a Head attach point; probe and Head both sit at InLocalOffset from the owner's origin.
    private FCk_Handle MakeTarget(FCk_Handle InHandle, FVector InLocation, FVector InLocalOffset)
    {
        auto Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        Owner.Request_OverrideToSelf();
        auto Root = utils_transform::Add(Owner, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);
        const auto Offset = FTransform(FRotator::ZeroRotator, InLocalOffset);

        auto BodyProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Player);
        BodyProbeSpec.Set_MotionType(ECk_MotionType::Kinematic)
                     .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent);
        utils_prefab::Create_ProbeNode_Sphere(Root, 20.0f, BodyProbeSpec, Offset);

        auto Head = utils_scene_node::Create(Root, Offset).As_Transform();

        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Head, Head));
        utils_attach_points::Add(Owner, AttachPointsSpec);
        return Owner;
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
