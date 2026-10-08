// A slide-only implement (Axes None, Slide.CmPerLookDegree 1.5, box half extents 30 / 30, a Commanded lift that the look
// never moves): look (10, -10) moves the slide target to (15, 15) (X from the look's -Y, Y from its X), the spring
// settles the slide there within 0.5 and holds it; look (100, 0) clamps Y at 30. A second implement with a disc
// (Radius 20 about Centre (5, 0)) clamps a look past the radius onto the circle. A set lift target of -20 is taken as
// it is and the lift settles near it. No tilt target ever moves.
class UMars_AutoTest_Implement_SlideFollowsTheLookAndALiftTargetCanBeSet : UMars_AutoTestRig_Implement
{
    default _TimeoutSeconds = 8.0f;

    private const float32 k_CmPerLookDegree = 1.5f;
    private const float32 k_HalfExtent = 30.0f;
    private const float32 k_SlideTolerance = 0.5f;
    private const float32 k_HoldSeconds = 0.3f;
    private const float32 k_LiftTarget = -20.0f;
    private const float32 k_LiftTolerance = 0.5f;
    private const float32 k_DiscRadius = 20.0f;
    private const FVector2D k_DiscCentre = FVector2D(5.0, 0.0);

    private FCk_Handle_Implement _Disc;
    private float32 _HoldStart = 0.0f;
    // The furthest the slide strayed from its target during the hold.
    private float64 _HoldDrift = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildImplement(InHandle, Make_SlideSpec());
        _Disc = Build_DiscImplement(InHandle);

        Add_Step("drive both implements and look right and up", n"Step_DriveAndLook");
        Add_Step_WaitUntil("the look moved the slide target", n"Check_TargetMoved", 0, 0.3f);
        Add_Step("the slide target is (15, 15)", n"Step_AssertTarget");
        Add_Step_WaitUntil("the slide settled at its target", n"Check_SlideAtTarget", 0, 1.5f);
        Add_Step("start the hold", n"Step_StartHold");
        Add_Step_WaitUntil("the slide is held for 0.3 s", n"Check_HoldElapsed", 0, 1.0f);
        Add_Step("the slide held; look far right", n"Step_AssertHeldThenLookFar");
        Add_Step_WaitUntil("the far look clamped the targets", n"Check_TargetsClamped", 0, 0.3f);
        Add_Step("the box clamps Y at 30 and the disc onto its circle; set the lift target", n"Step_AssertClampedThenSetLift");
        Add_Step_WaitUntil("the lift settled near its target", n"Check_LiftAtTarget", 0, 1.5f);
        Add_Step("the lift target is -20 and no tilt target moved", n"Step_AssertLiftAndNoTilt");
        Run_Steps(InHandle);
    }

    private FMars_Implement_Spec Make_SlideSpec()
    {
        auto Spec = FMars_Implement_Spec();
        Spec.Tilt.Axes = EMars_Implement_TiltAxes::None;
        Spec.Lift.Mode = EMars_Implement_LiftMode::Commanded;
        Spec.Lift.LiftPerLookDegree = 0.0f;
        Spec.Lift.MinLift = -30.0f;
        Spec.Lift.MaxLift = 5.0f;
        Spec.Slide.CmPerLookDegree = k_CmPerLookDegree;
        Spec.Slide.HalfExtentX = k_HalfExtent;
        Spec.Slide.HalfExtentY = k_HalfExtent;
        return Spec;
    }

    // The same slide clamped to a disc instead of the box, on its own node beside the rig's.
    private FCk_Handle_Implement Build_DiscImplement(FCk_Handle InHandle)
    {
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform(FRotator::ZeroRotator, k_Origin + FVector(0.0, 500.0, 0.0)),
            ECk_Replication::DoesNotReplicate);
        auto Node = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 100.0)));

        auto Spec = Make_SlideSpec();
        Spec.Slide.Centre = k_DiscCentre;
        Spec.Slide.Radius = k_DiscRadius;
        Spec.Nodes = FMars_Implement_Nodes(Node);
        return utils_implement::Add(RootEntity, Spec);
    }

    UFUNCTION()
    private void Step_DriveAndLook(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Implement) && ck::IsValid(_Disc), "both implements composed");

        Drive();
        _Disc.Request_SetDrive(FMars_Request_Implement_SetDrive(EMars_Implement_Drive::Driven));
        Look(FVector(10.0, -10.0, 0.0));
    }

    UFUNCTION()
    private void Check_TargetMoved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Implement.Get_TargetSlide().Size() > 1.0);
    }

    UFUNCTION()
    private void Step_AssertTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = _Implement.Get_TargetSlide();
        Assert_Equals_Float(Target.X, 15.0, 0.001, "10 degrees of look up push the slide target 15 away (+X)");
        Assert_Equals_Float(Target.Y, 15.0, 0.001, "10 degrees of look right move the slide target 15 right (+Y)");
    }

    UFUNCTION()
    private void Check_SlideAtTarget(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set((_Implement.Get_Slide() - _Implement.Get_TargetSlide()).Size() <= float64(k_SlideTolerance));
    }

    UFUNCTION()
    private void Step_StartHold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _HoldStart = float32(System::GetGameTimeInSeconds());
        _HoldDrift = 0.0;
    }

    UFUNCTION()
    private void Check_HoldElapsed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _HoldDrift = Math::Max(_HoldDrift, (_Implement.Get_Slide() - _Implement.Get_TargetSlide()).Size());
        auto Res = OutResult;
        Res.Set(float32(System::GetGameTimeInSeconds()) - _HoldStart >= k_HoldSeconds);
    }

    UFUNCTION()
    private void Step_AssertHeldThenLookFar(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Slide = _Implement.Get_Slide();
        ck::Trace(f"[Implement] slide held at {Slide} (target {_Implement.Get_TargetSlide()}), drift {_HoldDrift :.3}");
        Assert_True(_HoldDrift <= float64(k_SlideTolerance), f"the slide held at its target (drift {_HoldDrift})");

        const auto Node = utils_scene_node::Get_Offset(_Node).GetLocation();
        Assert_Equals_Float(Node.X, Slide.X, 0.01, "the node's offset carries the slide (X)");
        Assert_Equals_Float(Node.Y, Slide.Y, 0.01, "the node's offset carries the slide (Y)");

        Look(FVector(100.0, 0.0, 0.0));
        _Disc.Request_Look(FMars_Request_Implement_Look(FVector(100.0, 0.0, 0.0)));
    }

    UFUNCTION()
    private void Check_TargetsClamped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Implement.Get_TargetSlide().Y > 20.0 && _Disc.Get_TargetSlide().Y > 10.0);
    }

    UFUNCTION()
    private void Step_AssertClampedThenSetLift(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = _Implement.Get_TargetSlide();
        Assert_Equals_Float(Target.Y, float64(k_HalfExtent), 0.001, "a far look clamps the box target at the half extent");
        Assert_Equals_Float(Target.X, 15.0, 0.001, "a sideways look leaves X alone");

        const auto DiscTarget = _Disc.Get_TargetSlide();
        const auto DiscReach = (DiscTarget - k_DiscCentre).Size();
        ck::Trace(f"[Implement] disc slide target {DiscTarget}, {DiscReach :.3} from the centre");
        Assert_Equals_Float(DiscReach, float64(k_DiscRadius), 0.01, "a look past the radius clamps onto the circle");

        _Implement.Request_SetLiftTarget(FMars_Request_Implement_SetLiftTarget(k_LiftTarget));
    }

    UFUNCTION()
    private void Check_LiftAtTarget(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::Abs(_Implement.Get_Lift() - k_LiftTarget) <= k_LiftTolerance);
    }

    UFUNCTION()
    private void Step_AssertLiftAndNoTilt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Implement.Get_TargetLift(), k_LiftTarget, 0.001, "the set lift target is taken as it is");

        const auto Tilt = _Implement.Get_TargetTilt();
        Assert_Equals_Float(Tilt.Pitch, 0.0, 0.0001, "no pitch target");
        Assert_Equals_Float(Tilt.Yaw, 0.0, 0.0001, "no yaw target");
        Assert_Equals_Float(Tilt.Roll, 0.0, 0.0001, "no roll target");
        Assert_Equals_Float(_Disc.Get_TargetTilt().Roll, 0.0, 0.0001, "the disc implement never tilted");
    }
}
