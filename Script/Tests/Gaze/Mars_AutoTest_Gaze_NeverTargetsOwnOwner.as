// The gaze's eye node hangs under an owner that also carries a Probe.Mars.Player body probe and a Head attach point,
// 100 cm in front of the eye. A foreign target 200 cm in front becomes the target, and the owner's own Head is never
// selected even though it is nearer. Isolated Z band: -57000.
class UMars_AutoTest_Gaze_NeverTargetsOwnOwner : UCk_AutoTest_Base
{
    private FVector _Origin = FVector(0.0, 0.0, -57000.0);
    private FCk_Handle_Gaze _Gaze;
    private FCk_Handle _OwnOwner;
    private FCk_Handle _Foreign;
    private bool _EverTargetedOwnHead = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _OwnOwner = MakeTarget(InHandle, _Origin, FVector(100.0, 0.0, 0.0));

        auto OwnRoot = _OwnOwner.As_Transform();
        auto EyeNode = utils_scene_node::Create(OwnRoot, FTransform::Identity).As_Transform();
        _Gaze = utils_gaze::Add(EyeNode, MakeSpec());
        _Gaze.BindTo_OnTargetChanged(FMars_Delegate_Gaze_OnTargetChanged(this, n"OnTargetChanged"));

        _Foreign = MakeTarget(InHandle, _Origin + FVector(200.0, 0.0, 0.0), FVector::ZeroVector);

        Add_Step("the eye node shares its context with its owner, the foreign target does not", n"Step_AssertContexts");
        Add_Step_WaitUntil("the gaze looks at the foreign target", n"Check_LooksAtForeign");
        Add_Step_WaitSeconds("let the gaze keep evaluating both", 0.25);
        Add_Step("the gaze still looks at the foreign target and never looked at its own owner's Head", n"Step_AssertNeverOwn");
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
        Assert_True(ck::Ctx(FCk_Handle(_Gaze)) == _OwnOwner, "the eye node's context is the owner carrying the body probe and Head");
        Assert_True(ck::Ctx(_Foreign) == _Foreign, "the foreign target is its own context");
    }

    UFUNCTION()
    private void Check_LooksAtForeign(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Gaze.Get_Target() == DoGet_Head(_Foreign));
    }

    UFUNCTION()
    private void Step_AssertNeverOwn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Gaze.Get_Target() == DoGet_Head(_Foreign), "the gaze still looks at the foreign target");
        Assert_False(_EverTargetedOwnHead, "OnTargetChanged ever named the owner's own Head");
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

    private FMars_Gaze_Spec MakeSpec() const
    {
        auto Spec = FMars_Gaze_Spec();
        Spec.DetectionFilter.AddTag(GameplayTags::Probe_Mars_Player);
        Spec.AimPoint = GameplayTags::AttachPoint_Mars_Head;
        Spec.RangeCm = 300.0f;
        return Spec;
    }
}
