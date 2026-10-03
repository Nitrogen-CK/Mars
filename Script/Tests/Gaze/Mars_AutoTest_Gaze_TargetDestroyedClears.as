// Destroying the owner the gaze looks at returns the gaze to no target: OnTargetChanged fires from that Head to nothing,
// Get_HasTarget() is false and the aim is zero, with no invalid-handle error on the way (any error fails the test).
// Isolated Z band: -58000.
class UMars_AutoTest_Gaze_TargetDestroyedClears : UCk_AutoTest_Base
{
    private FVector _Origin = FVector(0.0, 0.0, -58000.0);
    private FCk_Handle_Gaze _Gaze;
    private FCk_Handle _Target;
    private FCk_Handle_Transform _TargetHead;
    private int32 _TargetChangedCount = 0;
    private FCk_Handle_Transform _LastPrevious;
    private FCk_Handle_Transform _LastCurrent;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto EyeEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto EyeNode = utils_transform::Add(EyeEntity, FTransform(FRotator::ZeroRotator, _Origin), ECk_Replication::DoesNotReplicate);
        _Gaze = utils_gaze::Add(EyeNode, MakeSpec());
        _Gaze.BindTo_OnTargetChanged(FMars_Delegate_Gaze_OnTargetChanged(this, n"OnTargetChanged"));

        _Target = MakeTarget(InHandle, _Origin + FVector(200.0, 0.0, 0.0));
        _TargetHead = DoGet_Head(_Target);

        Add_Step_WaitUntil("the gaze looks at the target", n"Check_LooksAtTarget");
        Add_Step("destroy the target's owner", n"Step_DestroyTarget");
        Add_Step_WaitUntil("OnTargetChanged fired from the target's Head to nothing", n"Check_Cleared");
        Add_Step("no target and a zero aim", n"Step_AssertCleared");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnTargetChanged(FCk_Handle_Gaze InGaze, FCk_Handle_Transform InPrevious, FCk_Handle_Transform InCurrent)
    {
        ++_TargetChangedCount;
        _LastPrevious = InPrevious;
        _LastCurrent = InCurrent;
    }

    UFUNCTION()
    private void Check_LooksAtTarget(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Gaze.Get_Target() == _TargetHead && _TargetChangedCount == 1);
    }

    UFUNCTION()
    private void Step_DestroyTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_entity_lifetime::Request_DestroyEntity(_Target);
    }

    UFUNCTION()
    private void Check_Cleared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TargetChangedCount == 2);
    }

    UFUNCTION()
    private void Step_AssertCleared(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_LastPrevious == _TargetHead, "the clearing OnTargetChanged comes from the destroyed target's Head");
        Assert_Invalid(_LastCurrent, "the clearing OnTargetChanged goes to no target");
        Assert_False(_Gaze.Get_HasTarget(), "Get_HasTarget() is false after the target's owner is destroyed");
        Assert_Invalid(_Gaze.Get_Target(), "Get_Target() is none after the target's owner is destroyed");

        const auto Aim = _Gaze.Get_AimYawPitchDeg();
        Assert_True(Aim.IsNearlyZero(), f"the aim is zero without a target (got [{Aim.ToString()}])");
    }

    // Its own owner and context (so the gaze's probe may overlap it), a kinematic Silent Probe.Mars.Player sphere like the
    // player's body probe, and a Head attach point at the owner's origin.
    private FCk_Handle MakeTarget(FCk_Handle InHandle, FVector InLocation)
    {
        auto Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        Owner.Request_OverrideToSelf();
        auto Root = utils_transform::Add(Owner, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);

        auto BodyProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Player);
        BodyProbeSpec.Set_MotionType(ECk_MotionType::Kinematic)
                     .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent);
        utils_prefab::Create_ProbeNode_Sphere(Root, 20.0f, BodyProbeSpec);

        auto Head = utils_scene_node::Create(Root, FTransform::Identity).As_Transform();

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
