// A settle shows an implement's targets at once. A skimmer-shaped implement (no tilt axes, its targets held while
// driven, a slow critically damped Commanded lift, a Commanded slide in a 30 x 30 box, a small orbit) is asked a settle
// first, then driven and given a lift, a tilt and a slide target in the same frame: once its drain has run it shows
// them, its springs at rest, its orbit at full radius and its node written there (the settle is applied after the
// targets of its drain, whatever the order they were asked in), and it holds them for half a second. A pan-shaped
// implement (the default spec: a Kick lift) asked a reset, a follow of a driven, tilted command and a settle in one
// frame shows the command's tilt at once and does not lift (the first command only records its kick total).
// Retargeted with no settle, the skimmer eases again.
class UMars_AutoTest_Implement_ASettleShowsItsTargetsAtOnce : UMars_AutoTestRig_Implement
{
    default _TimeoutSeconds = 6.0f;

    private const float32 k_Lift = -40.0f;
    private const FRotator k_Tilt = FRotator(55.0, 0.0, 0.0);
    private const FVector2D k_Slide = FVector2D(12.0, -8.0);
    private const FRotator k_FollowedTilt = FRotator(10.0, 0.0, 5.0);
    private const float32 k_KickTotal = 30.0f;
    private const float32 k_OrbitRadius = 3.0f;
    private const float32 k_HoldSeconds = 0.5f;
    // Within this of a target the implement is at it.
    private const float64 k_AtTarget = 0.01;

    private FCk_Handle_Implement _Pan;

    // Both implements as the first poll that found both drains run read them.
    private FMars_Fragment_Implement _SkimmerAtPoll;
    private FMars_Fragment_Implement _PanAtPoll;
    private float64 _OrbitAtPoll = -1.0;

    // The hold: when it began and the largest distance of the lift, the pitch and the slide from their targets.
    private float64 _HoldStart = 0.0;
    private float64 _WorstHeldCm = -1.0;

    // The skimmer's lift at the first poll that read its new targets.
    private float32 _LiftAtRetarget = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildImplement(InHandle, Make_SkimmerSpec());
        _Pan = Build_Pan(InHandle);

        Add_Step("settle first, then drive and target the skimmer; reset, follow and settle the pan", n"Step_SettleAndTarget");
        Add_Step_WaitUntil("both drains ran", n"Check_Drained", 0, 0);
        Add_Step("both show their targets at once", n"Step_AssertSettled");
        Add_Step_WaitUntil("half a second passes", n"Check_Held", k_SlowPolls, 0);
        Add_Step("the skimmer never left its targets; retarget it with no settle", n"Step_AssertHeldThenRetarget");
        Add_Step_WaitUntil("the new targets drained", n"Check_Retargeted", 0, 0);
        Add_Step("the skimmer eases toward them", n"Step_AssertEases");
        Run_Steps(InHandle);
    }

    private FMars_Implement_Spec Make_SkimmerSpec()
    {
        auto Spec = FMars_Implement_Spec();
        Spec.Tilt.Axes = EMars_Implement_TiltAxes::None;
        Spec.Tilt.Relax = EMars_Implement_Relax::WhileIdle;
        Spec.Tilt.MaxTiltDegrees = 60.0f;
        Spec.Lift.Mode = EMars_Implement_LiftMode::Commanded;
        Spec.Lift.SpringHz = 1.5f;
        Spec.Lift.DampingRatio = 1.0f;
        Spec.Lift.MinLift = -45.0f;
        Spec.Lift.MaxLift = 5.0f;
        Spec.Slide.Mode = EMars_Implement_SlideMode::Commanded;
        Spec.Slide.HalfExtentX = 30.0f;
        Spec.Slide.HalfExtentY = 30.0f;
        Spec.Orbit.Radius = k_OrbitRadius;
        Spec.Orbit.Hz = 1.0f;
        return Spec;
    }

    // The default spec (a Kick lift) on its own node beside the rig's.
    private FCk_Handle_Implement Build_Pan(FCk_Handle InHandle)
    {
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform(FRotator::ZeroRotator, k_Origin + FVector(0.0, 500.0, 0.0)),
            ECk_Replication::DoesNotReplicate);
        auto Node = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 100.0)));

        auto Spec = FMars_Implement_Spec();
        Spec.Nodes = FMars_Implement_Nodes(Node);
        return utils_implement::Add(RootEntity, Spec);
    }

    UFUNCTION()
    private void Step_SettleAndTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Implement) && ck::IsValid(_Pan), "both implements composed");
        Assert_True(_Pan.Get_Spec().Lift.Mode == EMars_Implement_LiftMode::Kick, "the pan-shaped implement has a Kick lift");

        _Implement.Request_Settle(FMars_Request_Implement_Settle());
        Drive();
        _Implement.Request_SetLiftTarget(FMars_Request_Implement_SetLiftTarget(k_Lift));
        _Implement.Request_SetTiltTarget(FMars_Request_Implement_SetTiltTarget(k_Tilt));
        _Implement.Request_SetSlideTarget(FMars_Request_Implement_SetSlideTarget(k_Slide));

        auto Command = FMars_Implement_Command();
        Command.Drive = EMars_Implement_Drive::Driven;
        Command.Tilt = k_FollowedTilt;
        Command.KickTotal = k_KickTotal;
        _Pan.Request_Reset(FMars_Request_Implement_Reset());
        _Pan.Request_Follow(FMars_Request_Implement_Follow(Command));
        _Pan.Request_Settle(FMars_Request_Implement_Settle());
    }

    UFUNCTION()
    private void Check_Drained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto IsDrained = _Implement.Get_TargetLift() < k_Lift + 1.0f && _Pan.Get_Steering() == EMars_Implement_Steering::Followed;
        if (IsDrained)
        {
            _SkimmerAtPoll = _Implement.Get_Fragment(FMars_Fragment_Implement);
            _PanAtPoll = _Pan.Get_Fragment(FMars_Fragment_Implement);
            _OrbitAtPoll = _Implement.Get_OrbitOffset().Size();
        }

        Res.Set(IsDrained);
    }

    UFUNCTION()
    private void Step_AssertSettled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Skimmer = _SkimmerAtPoll;
        Assert_Equals_Float(Skimmer.Lift, k_Lift, 0.001, "the skimmer shows its lift target at once");
        Assert_Equals_Float(Skimmer.LiftVelocity, 0.0, 0.001, "its lift spring is at rest");
        Assert_Equals_Float(Skimmer.Pitch, k_Tilt.Pitch, 0.001, "it shows its pitch target at once");
        Assert_Equals_Float(Skimmer.Slide.X, k_Slide.X, 0.001, "it shows its slide target at once (X)");
        Assert_Equals_Float(Skimmer.Slide.Y, k_Slide.Y, 0.001, "it shows its slide target at once (Y)");
        Assert_Equals_Float(Skimmer.SlideVelocity.Size(), 0.0, 0.001, "its slide spring is at rest");
        Assert_Equals_Float(_OrbitAtPoll, float64(k_OrbitRadius), 0.001, "its orbit shows at full radius (the share at 1)");
        Assert_Equals_Float(Skimmer.WrittenLift, Skimmer.Lift, 0.001, "its node was written at the lift it shows");
        Assert_Equals_Float(Skimmer.WrittenPitch, Skimmer.Pitch, 0.001, "its node was written at the pitch it shows");
        Assert_Equals_Float((Skimmer.WrittenSlide - Skimmer.Slide).Size(), 0.0, 0.001, "its node was written at the slide it shows");

        const auto Pan = _PanAtPoll;
        Assert_Equals_Float(Pan.Pitch, k_FollowedTilt.Pitch, 0.001, "the pan shows the command's pitch at once");
        Assert_Equals_Float(Pan.Yaw, k_FollowedTilt.Yaw, 0.001, "the pan shows the command's yaw at once");
        Assert_Equals_Float(Pan.Roll, k_FollowedTilt.Roll, 0.001, "the pan shows the command's roll at once");
        Assert_Equals_Float(Pan.Lift, 0.0, 0.001, "the pan does not lift (the first command records its kick total)");
        Assert_Equals_Float(Pan.LiftVelocity, 0.0, 0.001, "the pan's lift has nothing in flight");

        _HoldStart = System::GetGameTimeInSeconds();
    }

    UFUNCTION()
    private void Check_Held(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Lift = float64(Math::Abs(_Implement.Get_Lift() - _Implement.Get_TargetLift()));
        const auto Pitch = float64(Math::Abs(_Implement.Get_Tilt().Pitch - _Implement.Get_TargetTilt().Pitch));
        const auto Slide = (_Implement.Get_Slide() - _Implement.Get_TargetSlide()).Size();
        _WorstHeldCm = Math::Max(_WorstHeldCm, Math::Max(Lift, Math::Max(Pitch, Slide)));

        auto Res = OutResult;
        Res.Set(System::GetGameTimeInSeconds() - _HoldStart >= k_HoldSeconds);
    }

    UFUNCTION()
    private void Step_AssertHeldThenRetarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_WorstHeldCm >= 0.0 && _WorstHeldCm <= k_AtTarget,
            f"for half a second the skimmer's lift, pitch and slide stayed at their targets (worst {_WorstHeldCm})");
        _Implement.Request_SetLiftTarget(FMars_Request_Implement_SetLiftTarget(0.0f));
        _Implement.Request_SetSlideTarget(FMars_Request_Implement_SetSlideTarget(FVector2D::ZeroVector));
    }

    UFUNCTION()
    private void Check_Retargeted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsRetargeted = _Implement.Get_TargetLift() > -float32(k_AtTarget);
        if (IsRetargeted)
        { _LiftAtRetarget = _Implement.Get_Lift(); }

        auto Res = OutResult;
        Res.Set(IsRetargeted);
    }

    UFUNCTION()
    private void Step_AssertEases(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_LiftAtRetarget < -30.0f,
            f"retargeted with no settle the skimmer eases: its lift is still {_LiftAtRetarget} as its target reads 0");
    }
}
