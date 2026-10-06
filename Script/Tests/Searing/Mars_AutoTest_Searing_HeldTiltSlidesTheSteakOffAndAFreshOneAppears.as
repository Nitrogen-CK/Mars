// A pan held at its 30-degree clamp (no level return) slides the resting steak off the disc (combined friction 0.42 is
// below tan 30 = 0.58): the steak is lost, a fresh, different steak appears RespawnSeconds later, and the lost one is
// destroyed after LingerSeconds. The pan is levelled once the first steak is lost so the fresh one stays put.
class UMars_AutoTest_Searing_HeldTiltSlidesTheSteakOffAndAFreshOneAppears : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 12.0f;

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
        Add_Step_WaitUntil("the steak slid off the pan", n"Check_Lost1", 0, 5.0f);
        Add_Step("the steak was lost and lingers; level the pan", n"Step_AssertLostThenLevel");
        Add_Step_WaitUntil("a fresh steak spawned", n"Check_Spawned2", 0, 1.0f);
        Add_Step("the fresh steak is a different entity", n"Step_AssertFreshSteak");
        Add_Step_WaitUntil("the lost steak was destroyed", n"Check_LostDestroyed", 0, 1.5f);
        Add_Step("nothing lingers", n"Step_AssertNothingLingers");
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
    private void Step_AssertLostThenLevel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Phase = _Searing.Get_Phase();
        Assert_True(Phase == EMars_Searing_Phase::NoSteak, f"the pan is empty after the loss (got {Phase :n})");
        Assert_Equals_Int(_Searing.Get_Tally().Losses, 1, "one loss counted");
        Assert_Equals_Int(_Searing.Get_LostSteakCount(), 1, "the lost steak lingers");
        Assert_Equals_Int(_Lost.Num(), 1, "OnSteakLost fired once");
        if (_Lost.Num() > 0)
        {
            Assert_True(_Lost[0] == _FirstSteak, "the lost steak is the one that rested on the pan");
            Assert_True(ck::IsValid(_Lost[0]), "the lost steak is still live while it lingers");
        }

        Look(FVector(-_PanSpec.Tilt.MaxTiltDegrees / _PanSpec.Tilt.TiltPerLookDegree, 0.0, 0.0));
    }

    UFUNCTION()
    private void Step_AssertFreshSteak(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Spawned.Num(), 2, "OnSteakSpawned fired a second time");
        if (_Spawned.Num() == 2)
        {
            Assert_True(_Spawned[1] != _FirstSteak, "the fresh steak is a different entity");
            Assert_True(ck::IsValid(_Spawned[1]), "the fresh steak is live");
        }

        Assert_Equals_Float(_Searing.Get_PanTilt().Roll, 0.0, 0.01, "the pan is level again");
    }

    UFUNCTION()
    private void Step_AssertNothingLingers(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Searing.Get_LostSteakCount(), 0, "the lost steak left the list when it was destroyed");
        Assert_Equals_Int(_Lost.Num(), 1, "no second loss on the levelled pan");
    }
}
