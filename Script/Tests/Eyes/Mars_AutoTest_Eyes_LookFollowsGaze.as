// With Gaze on the same face node and a target's head 45 degrees to the right, LookOffset.X settles at +0.75
// (45 / LookMaxYawDeg 60); an expression with AllowLook = false brings it back to ~0 while the target is still there,
// clearing it restores the look, and destroying the target returns it to ~0. A target in front and 100 cm above the
// node then gives a positive LookOffset.Y, and one 100 cm below a negative one. Isolated Z band: -67000.
class UMars_AutoTest_Eyes_LookFollowsGaze : UCk_AutoTest_Base
{
    // Six eased convergences plus the probe detecting each target.
    default _TimeoutSeconds = 14.0f;

    private FCk_Handle_Eyes _Eyes;
    private FCk_Handle_Gaze _Gaze;
    private FCk_Handle _TargetOwner;

    private float _ExpectedLookX = 0.75;
    private float _LookTolerance = 0.02;

    // 100 cm above or below the node, 200 cm in front: pitch atan(100 / 200), scaled by LookMaxPitchDeg.
    private float32 _LookMaxPitchDeg = 40.0f;
    private float _ExpectedLookY = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto FaceEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto FaceNode = utils_transform::Add(FaceEntity, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -67000.0)),
            ECk_Replication::DoesNotReplicate);

        auto GazeSpec = FMars_Gaze_Spec();
        GazeSpec.DetectionFilter.AddTag(GameplayTags::Probe_Mars_Player);
        GazeSpec.AimPoint = GameplayTags::AttachPoint_Mars_Head;
        GazeSpec.RangeCm = 300.0f;
        _Gaze = utils_gaze::Add(FaceNode, GazeSpec);

        auto EyesSpec = FMars_Eyes_Spec();
        EyesSpec.BlinkEnabled = false;
        EyesSpec.LookMaxYawDeg = 60.0f;
        EyesSpec.LookMaxPitchDeg = _LookMaxPitchDeg;
        _Eyes = utils_eyes::Add(FaceNode, EyesSpec);

        _ExpectedLookY = Math::RadiansToDegrees(Math::Atan2(100.0, 200.0)) / _LookMaxPitchDeg;

        // In front of the node, 45 degrees toward +Y, level with it: yaw +45, pitch 0, about 283 uu away.
        _TargetOwner = MakeTarget(InHandle, FVector(200.0, 200.0, -67000.0));

        Add_Step("gaze and eyes composed on the face node, with a presentation", n"Step_AssertComposed");
        Add_Step_WaitUntil("the gaze has the target and LookOffset settles at (+0.75, 0)", n"Check_LookingAtTarget");
        Add_Step("play an expression that forbids looking, until cleared", n"Step_PlayNoLook");
        Add_Step_WaitUntil("LookOffset returns to ~0 while the gaze still has the target", n"Check_CentredWithTarget");
        Add_Step("clear the emote", n"Step_ClearEmote");
        Add_Step_WaitUntil("LookOffset settles at (+0.75, 0) again", n"Check_LookingAtTarget");
        Add_Step("destroy the target", n"Step_DestroyTarget");
        Add_Step_WaitUntil("the gaze has no target and LookOffset returns to ~0", n"Check_CentredWithoutTarget");
        Add_Step("add a target 100 cm above the node", n"Step_AddTargetAbove");
        Add_Step_WaitUntil("LookOffset settles at (0, +pitch / LookMaxPitchDeg)", n"Check_LookingUp");
        Add_Step("LookOffset.Y is positive for a target above", n"Step_AssertLookingUp");
        Add_Step("destroy the target", n"Step_DestroyTarget");
        Add_Step_WaitUntil("the gaze has no target and LookOffset returns to ~0", n"Check_CentredWithoutTarget");
        Add_Step("add a target 100 cm below the node", n"Step_AddTargetBelow");
        Add_Step_WaitUntil("LookOffset settles at (0, -pitch / LookMaxPitchDeg)", n"Check_LookingDown");
        Add_Step("LookOffset.Y is negative for a target below", n"Step_AssertLookingDown");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertComposed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Gaze, "utils_gaze::Add returns a valid handle");
        Assert_Valid(_Eyes, "utils_eyes::Add returns a valid handle");
        if (_Eyes.Get_HasPresentation() == false)
        { FinishFailure("the eyes have no presentation in this world - Get_CanExecuteCosmeticEvents was false"); }
    }

    UFUNCTION()
    private void Check_LookingAtTarget(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Look = _Eyes.Get_LookOffset();

        auto Res = OutResult;
        Res.Set(_Gaze.Get_HasTarget()
            && Math::Abs(Look.X - _ExpectedLookX) < _LookTolerance
            && Math::Abs(Look.Y) < _LookTolerance);
    }

    UFUNCTION()
    private void Step_PlayNoLook(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Squeeze = FMars_Eyes_ExpressionDef();
        Squeeze.LeftCell = 15;
        Squeeze.RightCell = 15;
        Squeeze.AllowBlink = false;
        Squeeze.AllowLook = false;
        _Eyes.Request_PlayExpression(FMars_Request_Eyes_PlayExpression(Squeeze));
    }

    UFUNCTION()
    private void Check_CentredWithTarget(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Look = _Eyes.Get_LookOffset();

        auto Res = OutResult;
        Res.Set(_Gaze.Get_HasTarget()
            && Math::Abs(Look.X) < _LookTolerance
            && Math::Abs(Look.Y) < _LookTolerance);
    }

    UFUNCTION()
    private void Step_ClearEmote(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Eyes.Request_ClearExpression(FMars_Request_Eyes_ClearExpression(EMars_Eyes_Layer::Emote));
    }

    UFUNCTION()
    private void Step_DestroyTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_entity_lifetime::Request_DestroyEntity(_TargetOwner);
    }

    UFUNCTION()
    private void Check_CentredWithoutTarget(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Look = _Eyes.Get_LookOffset();

        auto Res = OutResult;
        Res.Set(_Gaze.Get_HasTarget() == false
            && Math::Abs(Look.X) < _LookTolerance
            && Math::Abs(Look.Y) < _LookTolerance);
    }

    UFUNCTION()
    private void Step_AddTargetAbove(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _TargetOwner = MakeTarget(InHandle, FVector(200.0, 0.0, -67000.0 + 100.0));
    }

    UFUNCTION()
    private void Check_LookingUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Look = _Eyes.Get_LookOffset();

        auto Res = OutResult;
        Res.Set(_Gaze.Get_HasTarget()
            && Math::Abs(Look.X) < _LookTolerance
            && Math::Abs(Look.Y - _ExpectedLookY) < _LookTolerance);
    }

    UFUNCTION()
    private void Step_AssertLookingUp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Look = _Eyes.Get_LookOffset();
        Assert_True(Look.Y > 0.0, f"LookOffset.Y for a target above (got [{Look.Y}])");
    }

    UFUNCTION()
    private void Step_AddTargetBelow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _TargetOwner = MakeTarget(InHandle, FVector(200.0, 0.0, -67000.0 - 100.0));
    }

    UFUNCTION()
    private void Check_LookingDown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Look = _Eyes.Get_LookOffset();

        auto Res = OutResult;
        Res.Set(_Gaze.Get_HasTarget()
            && Math::Abs(Look.X) < _LookTolerance
            && Math::Abs(Look.Y + _ExpectedLookY) < _LookTolerance);
    }

    UFUNCTION()
    private void Step_AssertLookingDown(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Look = _Eyes.Get_LookOffset();
        Assert_True(Look.Y < 0.0, f"LookOffset.Y for a target below (got [{Look.Y}])");
    }

    // Its own context root (so the gaze's probe treats it as someone else), a kinematic Silent body probe named
    // Probe.Mars.Player like the player's, and a Head attach point at its origin.
    private FCk_Handle MakeTarget(FCk_Handle InHandle, FVector InLocation)
    {
        auto Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        Owner.Request_OverrideToSelf();
        auto OwnerTransform = utils_transform::Add(Owner, FTransform(FRotator::ZeroRotator, InLocation),
            ECk_Replication::DoesNotReplicate);

        auto ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Player);
        ProbeSpec.Set_MotionType(ECk_MotionType::Kinematic)
                 .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent);
        utils_prefab::Create_ProbeNode_Sphere(OwnerTransform, 20.0f, ProbeSpec);

        auto Head = utils_scene_node::Create(OwnerTransform, FTransform::Identity).As_Transform();

        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Head, Head));
        utils_attach_points::Add(Owner, AttachPointsSpec);

        return Owner;
    }
}
