// The Searing side of the pan: a look on a cold pan does nothing (the pan Implement stays Idle); the heat makes the pan
// Driven and the forwarded look tilts it (10 degrees right steer the roll toward 12); a reset levels the pan and idles it.
// The pan does not relax here (LevelReturnDegreesPerSecond 0), so the level after the reset is the reset's doing.
class UMars_AutoTest_Searing_LookTiltsThePanAndItLevelsOut : UMars_AutoTestRig_Searing
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto PanSpec = FMars_Implement_Spec();
        PanSpec.Tilt.LevelReturnDegreesPerSecond = 0.0f;
        BuildStation(InHandle, Make_TestSpec(), PanSpec);

        Add_Step("look right on a cold pan", n"Step_ColdLook");
        Add_Step_WaitFrames("the cold look drained", 4);
        Add_Step("the cold pan stayed level and idle; heat and look right", n"Step_AssertLevelThenHeatAndLookRight");
        Add_Step_WaitUntil("the look tilted the pan", n"Check_RolledPast5", 0, 0.3f);
        Add_Step("the hot pan is driven and rolled right; reset", n"Step_AssertRolledThenReset");
        Add_Step_WaitUntil("the reset reached the pan", n"Check_PanResetAndIdle", 0, 0.5f);
        Add_Step("the pan is level, idle and cold", n"Step_AssertReset");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_ColdLook(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Searing), "the feature composed");
        Assert_True(ck::IsValid(_Pan), "the pan Implement composed");
        Assert_False(_Searing.Get_IsHot(), "the pan starts cold");
        Look(FVector(10.0, 0.0, 0.0));
    }

    UFUNCTION()
    private void Step_AssertLevelThenHeatAndLookRight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Tilt = _Searing.Get_PanTilt();
        Assert_Equals_Float(Tilt.Roll, 0.0, 0.001, "a cold look leaves the roll at 0");
        Assert_Equals_Float(Tilt.Pitch, 0.0, 0.001, "a cold look leaves the pitch at 0");
        Assert_True(_Searing.Get_Pan().Get_Drive() == EMars_Implement_Drive::Idle, "a cold pan is Idle");

        Heat();
        Look(FVector(10.0, 0.0, 0.0));
    }

    UFUNCTION()
    private void Check_RolledPast5(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Searing.Get_PanTilt().Roll > 5.0);
    }

    UFUNCTION()
    private void Step_AssertRolledThenReset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Searing.Get_IsHot(), "the pan is hot");
        Assert_True(_Searing.Get_Pan().Get_Drive() == EMars_Implement_Drive::Driven, "the heat made the pan Driven");

        const auto Tilt = _Searing.Get_PanTilt();
        Assert_True(Tilt.Roll > 5.0 && Tilt.Roll <= 12.01, f"10 degrees of look right rolled the pan toward 12 (got {Tilt.Roll})");
        Assert_Equals_Float(Tilt.Pitch, 0.0, 0.001, "a sideways look does not pitch the pan");

        _Searing.Request_Reset(FMars_Request_Searing_Reset());
    }

    UFUNCTION()
    private void Check_PanResetAndIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Searing.Get_Pan().Get_Drive() == EMars_Implement_Drive::Idle && Math::Abs(_Searing.Get_PanTilt().Roll) < 0.001);
    }

    UFUNCTION()
    private void Step_AssertReset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Tilt = _Searing.Get_PanTilt();
        Assert_Equals_Float(Tilt.Roll, 0.0, 0.001, "the reset levelled the roll");
        Assert_Equals_Float(Tilt.Pitch, 0.0, 0.001, "the reset levelled the pitch");
        Assert_True(_Searing.Get_Pan().Get_Drive() == EMars_Implement_Drive::Idle, "the reset idled the pan");
        Assert_False(_Searing.Get_IsHot(), "the reset chilled the pan");

        const auto NodeRoll = utils_scene_node::Get_Offset(_PanNode).Rotator().Roll;
        Assert_Equals_Float(NodeRoll, 0.0, 0.5, "the pan node's offset is level again");
    }
}
