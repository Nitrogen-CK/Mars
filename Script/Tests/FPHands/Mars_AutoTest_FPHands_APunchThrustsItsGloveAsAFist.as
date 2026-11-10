// The gloves show the Punch feature's jabs: the glove whose fist is in flight gets a punch grip - where it rests, moved by
// the spec's thrust (mirrored across the view for the left glove), with the spec's punch rotation - an alpha above zero
// and the Fist pose, while the other glove is left as it rests. Once the fist is home both gloves are as they rest again.
// The punch alpha eases a stroke's linear progress: 0 at the throw, 1 at the blow, 0 home. Gloves on an entity without the
// Punch feature are left alone (every other FPHands test). FPHands and Punch on the test entity; no Hands state machine.
class UMars_AutoTest_FPHands_APunchThrustsItsGloveAsAFist : UMars_AutoTestRig_Hands
{
    private FCk_Handle_Punch _Punch;
    private FMars_FPHands_Spec _HandsSpec;

    // Every poll that reads the left fist in flight must see its glove punching and the right at rest.
    private int32 _InFlightPolls = 0;
    private bool _LeftAlwaysPunched = true;
    private bool _RightAlwaysRested = true;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Hands(InHandle, _HandsSpec);

        // Slow enough that the jab spans many frames in a headless lane.
        auto PunchSpec = FMars_Punch_Spec();
        PunchSpec.Rhythm.ImpactSeconds = 0.4f;
        PunchSpec.Rhythm.RecoverySeconds = 0.6f;
        PunchSpec.Rhythm.ComboSeconds = 2.0f;
        _Punch = utils_punch::Add(_Player, PunchSpec);

        Add_Step("the punch alpha eases out and back, and the left glove's thrust is mirrored", n"Step_AssertCurve");
        Add_Step("at rest neither glove punches; throw", n"Step_AssertRestAndThrow");
        Add_Step_WaitUntil("the left fist went out and came home", n"Check_JabRanHome", k_SlowPolls, 0);
        Add_Step("in flight the left glove punched as a fist and the right rested; both rest again", n"Step_AssertJab");
        Run_Steps(InHandle);
    }

    private FMars_FPHands_HandTargets Get_Targets() const
    {
        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(_Hands.Get_HandNode());
        auto Targets = FMars_FPHands_HandTargets();
        _Hands.Get_HandTargets(FMars_FPHands_TargetFrame(HandWorld, FVector::ZeroVector, FVector::ZeroVector), Targets);
        return Targets;
    }

    UFUNCTION()
    private void Step_AssertCurve(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto& Spec = _HandsSpec.Punch;
        Assert_Equals_Float(utils_fphands::Get_PunchAlpha(Spec, EMars_Punch_Stroke::Out, 0.0f), 0.0f, 0.001f, "a fist just thrown is at rest");
        Assert_Equals_Float(utils_fphands::Get_PunchAlpha(Spec, EMars_Punch_Stroke::Out, 1.0f), 1.0f, 0.001f, "at the end of the out stroke it is at the blow");
        Assert_Equals_Float(utils_fphands::Get_PunchAlpha(Spec, EMars_Punch_Stroke::Back, 0.0f), 1.0f, 0.001f, "the back stroke starts at the blow");
        Assert_Equals_Float(utils_fphands::Get_PunchAlpha(Spec, EMars_Punch_Stroke::Back, 1.0f), 0.0f, 0.001f, "and ends at rest");
        Assert_Equals_Float(utils_fphands::Get_PunchAlpha(Spec, EMars_Punch_Stroke::None, 0.5f), 0.0f, 0.001f, "a fist at home is at rest");

        const auto Rest = FTransform(FRotator::ZeroRotator, FVector(1.0, 2.0, 3.0), FVector::OneVector);
        const auto Right = utils_fphands::Make_PunchGrip(Spec, EMars_Hand::Right, Rest);
        const auto Left = utils_fphands::Make_PunchGrip(Spec, EMars_Hand::Left, Rest);
        Assert_True((Right.GetLocation() - Rest.GetLocation()).Equals(Spec.ThrustOffset, 0.001), "the right glove travels the thrust from where it rests");
        Assert_True((Left.GetLocation() - Rest.GetLocation()).Equals(FVector(Spec.ThrustOffset.X, -Spec.ThrustOffset.Y, Spec.ThrustOffset.Z), 0.001),
            "the left glove travels the thrust mirrored across the view");
        Assert_True(Right.GetRotation().Equals(Spec.GripRotation_R, 0.001) && Left.GetRotation().Equals(Spec.GripRotation_L, 0.001),
            "each glove takes its own punch rotation");
    }

    UFUNCTION()
    private void Step_AssertRestAndThrow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Targets = Get_Targets();
        Assert_Equals_Float(Targets.Left.PunchAlpha, 0.0f, 0.0001f, "at rest the left glove does not punch");
        Assert_Equals_Float(Targets.Right.PunchAlpha, 0.0f, 0.0001f, "at rest the right glove does not punch");
        Assert_True(Targets.Left.Pose == EMars_HandGripPose::Relaxed && Targets.Right.Pose == EMars_HandGripPose::Relaxed, "at rest both gloves are relaxed");

        _Punch.Request_Throw(FMars_Request_Punch_Throw());
    }

    UFUNCTION()
    private void Check_JabRanHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        // Clear of both ends of the jab, where the eased alpha rounds to zero.
        if (_Punch.Get_Extension(EMars_Hand::Left) > 0.05f)
        {
            const auto Targets = Get_Targets();
            const auto& Spec = _HandsSpec.Punch;
            const auto Expected = utils_fphands::Make_PunchGrip(Spec, EMars_Hand::Left, Targets.Left.GripInHand);
            const auto LeftPunches = Targets.Left.PunchAlpha > 0.0f && Targets.Left.Pose == Spec.Pose
                && Targets.Left.PunchGrip.GetLocation().Equals(Expected.GetLocation(), 0.001);
            const auto RightRests = Targets.Right.PunchAlpha <= 0.0f && Targets.Right.Pose == EMars_HandGripPose::Relaxed;

            _InFlightPolls += 1;
            _LeftAlwaysPunched = _LeftAlwaysPunched && LeftPunches;
            _RightAlwaysRested = _RightAlwaysRested && RightRests;
        }

        auto Res = OutResult;
        Res.Set(_Punch.Get_JabsThrown() >= 1 && _Punch.Get_IsPunching() == false);
    }

    UFUNCTION()
    private void Step_AssertJab(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_InFlightPolls > 0, "the left fist was seen in flight at least once");
        Assert_True(_LeftAlwaysPunched,
            f"on every one of {_InFlightPolls} in-flight polls the left glove had a punch grip (its rest moved by the mirrored thrust), an alpha above zero and the Fist pose");
        Assert_True(_RightAlwaysRested, f"on every one of {_InFlightPolls} in-flight polls the right glove rested, relaxed");

        const auto Targets = Get_Targets();
        Assert_Equals_Float(Targets.Left.PunchAlpha, 0.0f, 0.0001f, "home again, the left glove does not punch");
        Assert_True(Targets.Left.Pose == EMars_HandGripPose::Relaxed, "home again, the left glove is relaxed");
    }
}
