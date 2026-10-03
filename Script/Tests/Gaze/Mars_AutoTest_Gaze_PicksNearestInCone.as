// With two targets in range and in the cone, the gaze looks at the nearer one's Head: A ahead-right-above (yaw and pitch
// positive). Once A is moved out of range it looks at B ahead-left-below (yaw and pitch negative). Isolated Z band:
// -55500.
class UMars_AutoTest_Gaze_PicksNearestInCone : UCk_AutoTest_Base
{
    private FVector _Origin = FVector(0.0, 0.0, -55500.0);
    private FCk_Handle_Gaze _Gaze;
    private FCk_Handle _TargetA;
    private FCk_Handle _TargetB;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto EyeEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto EyeNode = utils_transform::Add(EyeEntity, FTransform(FRotator::ZeroRotator, _Origin), ECk_Replication::DoesNotReplicate);
        _Gaze = utils_gaze::Add(EyeNode, MakeSpec());

        _TargetA = MakeTarget(InHandle, _Origin + FVector(150.0, 80.0, 60.0));
        _TargetB = MakeTarget(InHandle, _Origin + FVector(250.0, -80.0, -60.0));

        Add_Step_WaitUntil("both targets are sensed and the gaze looks at the nearer A", n"Check_LooksAtA");
        Add_Step("A is to the right and above", n"Step_AssertAimAtA");
        Add_Step("move A out of range", n"Step_MoveAAway");
        Add_Step_WaitUntil("the gaze looks at B", n"Check_LooksAtB");
        Add_Step("B is to the left and below", n"Step_AssertAimAtB");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_LooksAtA(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(DoGet_IsSensed(_TargetA) && DoGet_IsSensed(_TargetB) && _Gaze.Get_Target() == DoGet_Head(_TargetA));
    }

    UFUNCTION()
    private void Step_AssertAimAtA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Gaze.Get_HasTarget(), "Get_HasTarget() is true while looking at A");

        const auto Aim = _Gaze.Get_AimYawPitchDeg();
        Assert_True(Aim.X > 0.0, f"yaw toward a target on the right is positive (got [{Aim.X}])");
        Assert_True(Aim.Y > 0.0, f"pitch toward a target above is positive (got [{Aim.Y}])");
        Assert_Equals_Float(Aim.X, Math::RadiansToDegrees(Math::Atan2(80.0, 150.0)), 0.1, "the yaw points at A");
        Assert_Equals_Float(Aim.Y, Math::RadiansToDegrees(Math::Atan2(60.0, Math::Sqrt(150.0 * 150.0 + 80.0 * 80.0))), 0.1, "the pitch points at A");
    }

    UFUNCTION()
    private void Step_MoveAAway(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_transform::Request_SetLocation(_TargetA.As_Transform(), FCk_Request_Transform_SetLocation(_Origin + FVector(1000.0, 0.0, 0.0)));
    }

    UFUNCTION()
    private void Check_LooksAtB(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Gaze.Get_Target() == DoGet_Head(_TargetB));
    }

    UFUNCTION()
    private void Step_AssertAimAtB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Aim = _Gaze.Get_AimYawPitchDeg();
        Assert_True(Aim.X < 0.0, f"yaw toward a target on the left is negative (got [{Aim.X}])");
        Assert_True(Aim.Y < 0.0, f"pitch toward a target below is negative (got [{Aim.Y}])");
        Assert_Equals_Float(Aim.X, Math::RadiansToDegrees(Math::Atan2(-80.0, 250.0)), 0.1, "the yaw points at B");
        Assert_Equals_Float(Aim.Y, Math::RadiansToDegrees(Math::Atan2(-60.0, Math::Sqrt(250.0 * 250.0 + 80.0 * 80.0))), 0.1, "the pitch points at B");
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
