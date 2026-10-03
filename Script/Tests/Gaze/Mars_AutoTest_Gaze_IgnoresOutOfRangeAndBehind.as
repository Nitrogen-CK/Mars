// Three sensed targets the gaze must not look at: one just beyond RangeCm (its probe still overlaps the sense sphere),
// one inside MinRangeCm and one behind the eye node. The gaze stays on no target with a zero aim and OnTargetChanged
// never fires; moving the out-of-range target into range then makes it the target. Isolated Z band: -56000.
class UMars_AutoTest_Gaze_IgnoresOutOfRangeAndBehind : UCk_AutoTest_Base
{
    private FVector _Origin = FVector(0.0, 0.0, -56000.0);
    private FCk_Handle_Gaze _Gaze;
    private FCk_Handle _BeyondRange;
    private FCk_Handle _InsideMinRange;
    private FCk_Handle _Behind;
    private int32 _TargetChangedCount = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto EyeEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto EyeNode = utils_transform::Add(EyeEntity, FTransform(FRotator::ZeroRotator, _Origin), ECk_Replication::DoesNotReplicate);

        auto Spec = MakeSpec();
        Spec.MinRangeCm = 50.0f;
        _Gaze = utils_gaze::Add(EyeNode, Spec);
        _Gaze.BindTo_OnTargetChanged(FMars_Delegate_Gaze_OnTargetChanged(this, n"OnTargetChanged"));

        // The 20 cm probe at 310 cm still reaches into the 300 cm sense sphere, so only the range check can reject it.
        _BeyondRange = MakeTarget(InHandle, _Origin + FVector(310.0, 0.0, 0.0));
        _InsideMinRange = MakeTarget(InHandle, _Origin + FVector(30.0, 0.0, 0.0));
        _Behind = MakeTarget(InHandle, _Origin + FVector(-150.0, 0.0, 0.0));

        Add_Step_WaitUntil("all three targets are sensed", n"Check_AllSensed");
        Add_Step_WaitSeconds("let the gaze evaluate them", 0.25);
        Add_Step("no target, zero aim, OnTargetChanged never fired", n"Step_AssertNoTarget");
        Add_Step("move the out-of-range target into range", n"Step_MoveIntoRange");
        Add_Step_WaitUntil("the gaze looks at it", n"Check_LooksAtMoved");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnTargetChanged(FCk_Handle_Gaze InGaze, FCk_Handle_Transform InPrevious, FCk_Handle_Transform InCurrent)
    {
        ++_TargetChangedCount;
    }

    UFUNCTION()
    private void Check_AllSensed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(DoGet_IsSensed(_BeyondRange) && DoGet_IsSensed(_InsideMinRange) && DoGet_IsSensed(_Behind));
    }

    UFUNCTION()
    private void Step_AssertNoTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Gaze.Get_HasTarget(), "Get_HasTarget() is false with only out-of-range, too-close and behind targets");
        Assert_Invalid(_Gaze.Get_Target(), "Get_Target() is none with only out-of-range, too-close and behind targets");

        const auto Aim = _Gaze.Get_AimYawPitchDeg();
        Assert_True(Aim.IsNearlyZero(), f"the aim is zero without a target (got [{Aim.ToString()}])");
        Assert_Equals_Int(_TargetChangedCount, 0, "OnTargetChanged never fired");
    }

    UFUNCTION()
    private void Step_MoveIntoRange(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_transform::Request_SetLocation(_BeyondRange.As_Transform(), FCk_Request_Transform_SetLocation(_Origin + FVector(200.0, 0.0, 0.0)));
    }

    UFUNCTION()
    private void Check_LooksAtMoved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Gaze.Get_Target() == DoGet_Head(_BeyondRange) && _TargetChangedCount == 1);
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
