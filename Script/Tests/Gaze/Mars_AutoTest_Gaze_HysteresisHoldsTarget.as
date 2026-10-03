// With SwitchCloserRatio 0.15 and the current target 200 cm away, a sensed challenger 10% closer (180 cm) does not take
// the gaze; moved 30% closer (140 cm) it does; then the first target, moved to 115 cm (just over 15% closer than the
// challenger's 140 cm), takes it back. OnTargetChanged fires once per change: none -> current, current -> challenger,
// challenger -> current. Isolated Z band: -56500.
class UMars_AutoTest_Gaze_HysteresisHoldsTarget : UCk_AutoTest_Base
{
    private FVector _Origin = FVector(0.0, 0.0, -56500.0);
    private FCk_Handle_Gaze _Gaze;
    private FCk_Handle _Current;
    private FCk_Handle _Challenger;
    private int32 _TargetChangedCount = 0;
    private FCk_Handle_Transform _LastPrevious;
    private FCk_Handle_Transform _LastCurrent;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto EyeEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto EyeNode = utils_transform::Add(EyeEntity, FTransform(FRotator::ZeroRotator, _Origin), ECk_Replication::DoesNotReplicate);

        auto Spec = MakeSpec();
        Spec.SwitchCloserRatio = 0.15f;
        _Gaze = utils_gaze::Add(EyeNode, Spec);
        _Gaze.BindTo_OnTargetChanged(FMars_Delegate_Gaze_OnTargetChanged(this, n"OnTargetChanged"));

        _Current = MakeTarget(InHandle, _Origin + FVector(200.0, 0.0, 0.0));

        Add_Step_WaitUntil("the gaze looks at the only target", n"Check_LooksAtCurrent");
        Add_Step("OnTargetChanged fired once, from no target to it", n"Step_AssertAcquired");
        Add_Step("add a challenger 10% closer", n"Step_AddChallenger");
        Add_Step_WaitUntil("the challenger is sensed", n"Check_ChallengerSensed");
        Add_Step_WaitSeconds("let the gaze weigh it", 0.25);
        Add_Step("the gaze held its target", n"Step_AssertHeld");
        Add_Step("move the challenger 30% closer", n"Step_MoveChallengerCloser");
        Add_Step_WaitUntil("the gaze looks at the challenger", n"Check_LooksAtChallenger");
        Add_Step("OnTargetChanged fired once more, from the old target to the challenger", n"Step_AssertSwitched");
        Add_Step("move the first target to 115 cm, 17.9% closer than the challenger's 140 cm", n"Step_MoveCurrentJustPastRatio");
        Add_Step_WaitUntil("the gaze looks at the first target again", n"Check_LooksAtCurrent");
        Add_Step("OnTargetChanged fired once more, from the challenger back to the first target", n"Step_AssertSwitchedBack");
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
    private void Check_LooksAtCurrent(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Gaze.Get_Target() == DoGet_Head(_Current));
    }

    UFUNCTION()
    private void Step_AssertAcquired(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_TargetChangedCount, 1, "OnTargetChanged fired once, on acquiring the first target");
        Assert_Invalid(_LastPrevious, "the first OnTargetChanged comes from no target");
        Assert_True(_LastCurrent == DoGet_Head(_Current), "the first OnTargetChanged names the target's Head");
    }

    UFUNCTION()
    private void Step_AddChallenger(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // 180 cm (3-4-5), 53 degrees off +X: inside the cone, 10% closer than the current 200 cm.
        _Challenger = MakeTarget(InHandle, _Origin + FVector(108.0, 144.0, 0.0));
    }

    UFUNCTION()
    private void Check_ChallengerSensed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(DoGet_IsSensed(_Challenger));
    }

    UFUNCTION()
    private void Step_AssertHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Gaze.Get_Target() == DoGet_Head(_Current), "a challenger 10% closer does not take the gaze");
        Assert_Equals_Int(_TargetChangedCount, 1, "OnTargetChanged did not fire again while the target was held");
    }

    UFUNCTION()
    private void Step_MoveChallengerCloser(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // 140 cm: below the 170 cm the current target's 200 cm and the 0.15 ratio demand.
        utils_transform::Request_SetLocation(_Challenger.As_Transform(), FCk_Request_Transform_SetLocation(_Origin + FVector(84.0, 112.0, 0.0)));
    }

    UFUNCTION()
    private void Check_LooksAtChallenger(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Gaze.Get_Target() == DoGet_Head(_Challenger));
    }

    UFUNCTION()
    private void Step_AssertSwitched(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_TargetChangedCount, 2, "OnTargetChanged fired a second time, on the switch");
        Assert_True(_LastPrevious == DoGet_Head(_Current), "the switch's OnTargetChanged comes from the old target's Head");
        Assert_True(_LastCurrent == DoGet_Head(_Challenger), "the switch's OnTargetChanged names the challenger's Head");
    }

    UFUNCTION()
    private void Step_MoveCurrentJustPastRatio(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_transform::Request_SetLocation(_Current.As_Transform(), FCk_Request_Transform_SetLocation(_Origin + FVector(115.0, 0.0, 0.0)));
    }

    UFUNCTION()
    private void Step_AssertSwitchedBack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_TargetChangedCount, 3, "OnTargetChanged fired a third time, on the switch back");
        Assert_True(_LastPrevious == DoGet_Head(_Challenger), "the switch back's OnTargetChanged comes from the challenger's Head");
        Assert_True(_LastCurrent == DoGet_Head(_Current), "the switch back's OnTargetChanged names the first target's Head");
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
