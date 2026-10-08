// A Commanded slide (Axes None, no lift, Slide.Mode Commanded with a non-zero CmPerLookDegree that must not matter, box half
// extents 30 / 30): a driven look (10, -10) leaves the slide target at zero and the node at rest; SetSlideTarget (12, -8)
// is taken as it is and the spring settles the node there (the node's offset carries it); another look moves nothing;
// SetSlideTarget (100, 0) clamps X at 30. A second implement with a Look slide ignores a SetSlideTarget (traced no-op).
class UMars_AutoTest_Implement_ACommandedSlideIgnoresTheLookAndTracksItsTarget : UMars_AutoTestRig_Implement
{
    default _TimeoutSeconds = 8.0f;

    private const float32 k_HalfExtent = 30.0f;
    private const FVector2D k_Target = FVector2D(12.0, -8.0);
    private const float32 k_SlideTolerance = 0.5f;

    private FCk_Handle_Implement _LookSlide;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildImplement(InHandle, Make_CommandedSpec());
        _LookSlide = Build_LookSlideImplement(InHandle);

        Add_Step("drive both implements and look right and up", n"Step_DriveAndLook");
        Add_Step_WaitSeconds("the look would have moved a Look slide", 0.25f);
        Add_Step("the look moved nothing; set the slide target on both", n"Step_AssertStillThenSetTarget");
        Add_Step_WaitUntil("the commanded slide settled at its target", n"Check_SlideAtTarget", 0, 1.5f);
        Add_Step("the target is taken as it is and the node carries it; look again", n"Step_AssertTrackedThenLook");
        Add_Step_WaitSeconds("the look would have moved a Look slide", 0.25f);
        Add_Step("the look moved nothing; set a target past the box", n"Step_AssertUnmovedThenSetFar");
        Add_Step_WaitFrames("the far target drains", 2);
        Add_Step("the far target clamps at the half extent; the Look slide ignored its request", n"Step_AssertClamped");
        Run_Steps(InHandle);
    }

    private FMars_Implement_Spec Make_CommandedSpec()
    {
        auto Spec = FMars_Implement_Spec();
        Spec.Tilt.Axes = EMars_Implement_TiltAxes::None;
        Spec.Lift.Mode = EMars_Implement_LiftMode::None;
        Spec.Slide.Mode = EMars_Implement_SlideMode::Commanded;
        Spec.Slide.CmPerLookDegree = 1.5f;
        Spec.Slide.HalfExtentX = k_HalfExtent;
        Spec.Slide.HalfExtentY = k_HalfExtent;
        return Spec;
    }

    // The same box with a Look slide, on its own node beside the rig's.
    private FCk_Handle_Implement Build_LookSlideImplement(FCk_Handle InHandle)
    {
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform(FRotator::ZeroRotator, k_Origin + FVector(0.0, 500.0, 0.0)),
            ECk_Replication::DoesNotReplicate);
        auto Node = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 100.0)));

        auto Spec = Make_CommandedSpec();
        Spec.Slide.Mode = EMars_Implement_SlideMode::Look;
        Spec.Nodes = FMars_Implement_Nodes(Node);
        return utils_implement::Add(RootEntity, Spec);
    }

    UFUNCTION()
    private void Step_DriveAndLook(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Implement) && ck::IsValid(_LookSlide), "both implements composed");

        Drive();
        _LookSlide.Request_SetDrive(FMars_Request_Implement_SetDrive(EMars_Implement_Drive::Driven));
        Look(FVector(10.0, -10.0, 0.0));
        _LookSlide.Request_Look(FMars_Request_Implement_Look(FVector(10.0, -10.0, 0.0)));
    }

    UFUNCTION()
    private void Step_AssertStillThenSetTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Implement.Get_IsDriven(), "the commanded implement is driven");
        Assert_Equals_Float(_Implement.Get_TargetSlide().Size(), 0.0, 0.0001, "a look never moves a Commanded slide's target");
        Assert_Equals_Float(_Implement.Get_Slide().Size(), 0.0, 0.0001, "the node stayed at rest");

        _Implement.Request_SetSlideTarget(FMars_Request_Implement_SetSlideTarget(k_Target));
        _LookSlide.Request_SetSlideTarget(FMars_Request_Implement_SetSlideTarget(k_Target));
    }

    UFUNCTION()
    private void Check_SlideAtTarget(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Implement.Get_TargetSlide().Size() > 1.0
            && (_Implement.Get_Slide() - _Implement.Get_TargetSlide()).Size() <= float64(k_SlideTolerance));
    }

    UFUNCTION()
    private void Step_AssertTrackedThenLook(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = _Implement.Get_TargetSlide();
        Assert_Equals_Float(Target.X, k_Target.X, 0.001, "the set target is taken as it is (X)");
        Assert_Equals_Float(Target.Y, k_Target.Y, 0.001, "the set target is taken as it is (Y)");

        const auto Slide = _Implement.Get_Slide();
        const auto Node = utils_scene_node::Get_Offset(_Node).GetLocation();
        Assert_Equals_Float(Node.X, Slide.X, 0.01, "the node's offset carries the slide (X)");
        Assert_Equals_Float(Node.Y, Slide.Y, 0.01, "the node's offset carries the slide (Y)");

        Look(FVector(-20.0, 20.0, 0.0));
    }

    UFUNCTION()
    private void Step_AssertUnmovedThenSetFar(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = _Implement.Get_TargetSlide();
        Assert_Equals_Float(Target.X, k_Target.X, 0.001, "a second look left the target alone (X)");
        Assert_Equals_Float(Target.Y, k_Target.Y, 0.001, "a second look left the target alone (Y)");

        _Implement.Request_SetSlideTarget(FMars_Request_Implement_SetSlideTarget(FVector2D(100.0, 0.0)));
    }

    UFUNCTION()
    private void Step_AssertClamped(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = _Implement.Get_TargetSlide();
        Assert_Equals_Float(Target.X, float64(k_HalfExtent), 0.001, "a target past the box clamps at the half extent");
        Assert_Equals_Float(Target.Y, 0.0, 0.001, "and keeps its Y");

        // The look (10, -10) moved the Look slide's target to (15, 15); its SetSlideTarget changed nothing.
        const auto LookTarget = _LookSlide.Get_TargetSlide();
        Assert_Equals_Float(LookTarget.X, 15.0, 0.001, "the Look slide's target is the look's (X), not the request's");
        Assert_Equals_Float(LookTarget.Y, 15.0, 0.001, "the Look slide's target is the look's (Y), not the request's");
    }
}
