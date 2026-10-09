// A pan held at its 30-degree clamp (no level return) slides the resting piece down the bowl toward the low edge (combined
// friction 0.3 is below tan 30 = 0.58) until the rising wall stops it. After 2 s the same piece is still on the pan, parked
// well off centre, with no loss and no flip. The slide is traced every 0.25 s, then the parked radius and the time to 90 %
// of it.
class UMars_AutoTest_Searing_HeldTiltParksTheSteakAgainstTheLip : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 10.0f;

    // The hold is sampled every k_SlideSampleSeconds: how far and how fast the piece slides down the tilt.
    private const float32 k_SlideSampleSeconds = 0.25f;
    private const int32 k_SlideSamples = 8;
    private const float64 k_SlideSettleFraction = 0.9;

    private FCk_Handle _FirstSteak;
    private float32 _HoldStart = 0.0f;
    private TArray<float32> _SlideTimes;
    private TArray<float64> _SlideRadii;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        auto PanSpec = FMars_Implement_Spec();
        PanSpec.Tilt.LevelReturnDegreesPerSecond = 0.0f;
        BuildStation(InHandle, Spec, PanSpec);
        Build_Pieces(1);

        Add_Step("heat the pan", n"Step_Heat");
        Add_Steps_AddPieceAndLand();
        Add_Step("tilt the pan right to its clamp", n"Step_TiltRight");
        // The tilt reaches the clamp at MaxTiltRateDegreesPerSecond (0.1 s); runner frames are not processor ticks.
        Add_Step_WaitUntil("the look tilted the pan to its clamp", n"Check_RollAtClamp", 0, 0.5f);
        Add_Step("the roll holds at the clamp", n"Step_AssertHeldAtClamp");
        for (auto Sample = 0; Sample < k_SlideSamples; ++Sample)
        {
            Add_Step_WaitSeconds("hold the tilt", k_SlideSampleSeconds);
            Add_Step("trace the slide", n"Step_TraceSlide");
        }

        Add_Step("the piece is parked against the lip, still on the pan", n"Step_AssertParked");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_TiltRight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FirstSteak = _Searing.Get_PieceEntity(Get_FirstId());
        Assert_True(ck::IsValid(_FirstSteak), "a piece rests on the pan");
        Look(FVector(30.0, 0.0, 0.0));
    }

    UFUNCTION()
    private void Check_RollAtClamp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Searing.Get_PanTilt().Roll >= _PanSpec.Tilt.MaxTiltDegrees - 0.01);
    }

    UFUNCTION()
    private void Step_AssertHeldAtClamp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Roll = _Searing.Get_PanTilt().Roll;
        Assert_Equals_Float(Roll, _PanSpec.Tilt.MaxTiltDegrees, 0.01, "36 degrees of roll clamp at MaxTiltDegrees and hold");

        const auto NodeRoll = utils_scene_node::Get_Offset(_PanNode).Rotator().Roll;
        Assert_Equals_Float(NodeRoll, Roll, 0.5, "the pan node's offset rotation shows the roll");

        _HoldStart = Get_Now();
        Trace_Slide();
    }

    UFUNCTION()
    private void Step_TraceSlide(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Trace_Slide();
    }

    private void Trace_Slide()
    {
        const auto Local = _Searing.Get_PiecePanLocal(Get_FirstId());
        const auto Time = Get_Now() - _HoldStart;
        _SlideTimes.Add(Time);
        _SlideRadii.Add(Local.Size2D());
        ck::Trace(f"[SearingSlide] t={Time :.2} r={Local.Size2D() :.2} z={Local.Z :.2} roll={_Searing.Get_PanTilt().Roll :.1}");
    }

    // The first sampled time the piece was within k_SlideSettleFraction of its final radius.
    private float32 Get_SlideSettleSeconds(float64 InFinalRadius) const
    {
        for (auto Index = 0; Index < _SlideRadii.Num(); ++Index)
        {
            if (_SlideRadii[Index] >= InFinalRadius * k_SlideSettleFraction)
            { return _SlideTimes[Index]; }
        }

        return _SlideTimes[_SlideTimes.Num() - 1];
    }

    UFUNCTION()
    private void Step_AssertParked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Local = _Searing.Get_PiecePanLocal(Get_FirstId());
        ck::Trace(f"[Searing] held tilt: piece parked at pan-local {Local} (radius {Local.Size2D() :.2}), roll {_Searing.Get_PanTilt().Roll :.2}");
        const auto FinalRadius = _SlideRadii[_SlideRadii.Num() - 1];
        ck::Trace(f"[SearingSlide] reached 90 % of the final radius after {Get_SlideSettleSeconds(FinalRadius) :.2} s; final radius {FinalRadius :.2}");

        Assert_Equals_Float(_Searing.Get_PanTilt().Roll, _PanSpec.Tilt.MaxTiltDegrees, 0.01, "the roll held at the clamp");
        Assert_True(_Searing.Get_PieceEntity(Get_FirstId()) == _FirstSteak, "the piece on the pan is the one that was tilted");
        Assert_True(Get_IsOnPan(Get_FirstId()), f"the piece is still on the pan (contact {_Searing.Get_PieceContact(Get_FirstId()) :n})");
        Assert_True(Local.Size2D() > _Spec.Loss.PanRadius * 0.5,
            f"the piece slid well off centre toward the lip (radius {Local.Size2D() :.2}, PanRadius {_Spec.Loss.PanRadius})");

        const auto Tally = _Searing.Get_Tally();
        Assert_Equals_Int(Tally.Losses, 0, "no loss");
        Assert_Equals_Int(_Lost.Num(), 0, "OnPieceLost never fired");
        Assert_Equals_Int(_Searing.Get_Summary().Lost, 0, "nothing lost");
        Assert_Equals_Int(_Added.Num(), 1, "no other piece");
        Assert_Equals_Int(Tally.Flips, 0, "a slide is no flip");
    }
}

class AMars_AutoTest_Searing_HeldTiltParksTheSteakAgainstTheLip_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 10.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_HeldTiltParksTheSteakAgainstTheLip;
}
