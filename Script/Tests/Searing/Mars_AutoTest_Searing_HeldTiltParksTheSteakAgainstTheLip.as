// A pan held at its 30-degree clamp (no level return) slides the resting steak toward the low edge (combined friction 0.3
// is below tan 30 = 0.58), where the lip stops it: a 6 uu cube tips over the 3 uu lip only past 63 degrees. After 2 s the
// same steak is still on the pan, parked well off centre, with no loss and no flip.
class UMars_AutoTest_Searing_HeldTiltParksTheSteakAgainstTheLip : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 10.0f;

    private FCk_Handle _FirstSteak;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        auto PanSpec = FMars_Implement_Spec();
        PanSpec.Tilt.LevelReturnDegreesPerSecond = 0.0f;
        BuildStation(InHandle, Spec, PanSpec);

        Add_Step("heat the pan", n"Step_Heat");
        Add_Step_WaitUntil("the steak landed on the pan", n"Check_OnPan", 0, 3.0f);
        Add_Step("tilt the pan right to its clamp", n"Step_TiltRight");
        // The tilt reaches the clamp at MaxTiltRateDegreesPerSecond (0.1 s); runner frames are not processor ticks.
        Add_Step_WaitUntil("the look tilted the pan to its clamp", n"Check_RollAtClamp", 0, 0.5f);
        Add_Step("the roll holds at the clamp", n"Step_AssertHeldAtClamp");
        Add_Step_WaitSeconds("hold the tilt", 2.0f);
        Add_Step("the steak is parked against the lip, still on the pan", n"Step_AssertParked");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_TiltRight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FirstSteak = _Searing.Get_Steak();
        Assert_True(ck::IsValid(_FirstSteak), "a steak rests on the pan");
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
    }

    UFUNCTION()
    private void Step_AssertParked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Local = _Searing.Get_SteakPanLocal();
        ck::Trace(f"[Searing] held tilt: steak parked at pan-local {Local} (radius {Local.Size2D() :.2}), roll {_Searing.Get_PanTilt().Roll :.2}");

        Assert_Equals_Float(_Searing.Get_PanTilt().Roll, _PanSpec.Tilt.MaxTiltDegrees, 0.01, "the roll held at the clamp");
        Assert_True(_Searing.Get_Steak() == _FirstSteak, "the steak on the pan is the one that was tilted");
        Assert_True(_Searing.Get_IsOnPan(), f"the steak is still on the pan (phase {_Searing.Get_Phase() :n})");
        Assert_True(Local.Size2D() > _Spec.Loss.PanRadius * 0.5,
            f"the steak slid well off centre toward the lip (radius {Local.Size2D() :.2}, PanRadius {_Spec.Loss.PanRadius})");

        const auto Tally = _Searing.Get_Tally();
        Assert_Equals_Int(Tally.Losses, 0, "no loss");
        Assert_Equals_Int(_Lost.Num(), 0, "OnSteakLost never fired");
        Assert_Equals_Int(_Searing.Get_LostSteakCount(), 0, "nothing lingers");
        Assert_Equals_Int(_Spawned.Num(), 1, "no fresh steak");
        Assert_Equals_Int(Tally.Flips, 0, "a slide is no flip");
    }
}
