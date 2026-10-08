// A press on the hovered lever reaches for it and grips it (the Control manipulating, the drum Gripped). Rocking the look
// down carries the lever and drum to the end of the arc and up brings them back, the grip held throughout and the Control
// never engaging (a held crank has no threshold). Letting go frees the hand at once and the drum returns home: the axle
// Mover's alpha back to 0 and the lever grip back at its home world pose.
class UMars_AutoTest_Tumbler_AHeldGripRocksInsideTheArcAndNeverCompletes : UMars_AutoTestRig_Tumbler
{
    default _TimeoutSeconds = 12.0f;

    private FVector _GripHomeWorld;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());

        Add_Step_WaitUntil("the station's nodes are posed", n"Check_NodesPosed", 0, 2.0f);
        Add_Step("remember the lever grip's home pose", n"Step_CaptureHome");
        Add_Steps_Grip();
        Add_Step("the grip went through a reach", n"Step_AssertReached");
        Add_Step_Rock("rock down for 60 frames", k_RockDegrees, 60);
        Add_Step("the lever is at the end of the arc, still gripped, nothing engaged", n"Step_AssertAtEnd");
        Add_Step_Rock("rock up for 30 frames", -k_RockDegrees, 30);
        Add_Step("the lever came back inside the arc, still gripped", n"Step_AssertCameBack");
        Add_Step("let go", n"Step_Release");
        Add_Step("the hand is free and the drum returning one pass later", n"Step_AssertLetGo");
        Add_Step_WaitUntil("the drum is home", n"Check_DrumHome", 0, 2.0f);
        Add_Step_WaitFrames("the grip node takes the home offset", 2);
        Add_Step("the lever and drum are back at home", n"Step_AssertHome");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_CaptureHome(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Tumbler), "the feature composed");
        _GripHomeWorld = Get_GripWorld();
        Assert_True(Check_Drum(EMars_Tumbler_Drum::Home), "the drum starts home");
        Assert_True(Check_HandMode(EMars_Tumbler_HandMode::Free), "the hand starts free");
    }

    UFUNCTION()
    private void Step_AssertReached(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_HandModes.Num() >= 2, f"two hand edges at least (got {_HandModes.Num()})");
        if (_HandModes.Num() < 2)
        { return; }

        Assert_True(_HandModes[0] == EMars_Tumbler_HandMode::Reaching, f"the first edge is Reaching (got {_HandModes[0] :n})");
        Assert_True(_HandModes[1] == EMars_Tumbler_HandMode::Gripped, f"the second edge is Gripped (got {_HandModes[1] :n})");
        Assert_True(_Drums.Num() >= 1 && _Drums.Last() == EMars_Tumbler_Drum::Gripped, "the drum reported Gripped");
    }

    UFUNCTION()
    private void Step_AssertAtEnd(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Alpha = _Axle.Get_Alpha();
        Assert_True(Alpha > 0.95f, f"the drum reached the end of the arc (alpha {Alpha :.3})");
        Assert_True(_Lever.Get_IsManipulating(), "the lever is still gripped");
        Assert_True(Check_HandMode(EMars_Tumbler_HandMode::Gripped), "the hand still grips");
        Assert_Equals_Int(_LeverEngagedCount, 0, "the Control never engaged");
        Assert_False(_Lever.Get_IsActive(), "the Control is still inactive");
        Assert_Equals_Float(_Tumbler.Get_DrumDegrees(), Alpha * _Spec.Drum.ArcDegrees, 0.01, "the drum degrees are the alpha times the arc");
    }

    UFUNCTION()
    private void Step_AssertCameBack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Alpha = _Axle.Get_Alpha();
        Assert_True(Alpha < 0.6f, f"the drum came back inside the arc (alpha {Alpha :.3})");
        Assert_True(_Lever.Get_IsManipulating(), "the lever is still gripped");
        Assert_Equals_Int(_LeverEngagedCount, 0, "the Control never engaged");
    }

    UFUNCTION()
    private void Step_AssertLetGo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Check_HandMode(EMars_Tumbler_HandMode::Free), f"the hand is free (got {_Tumbler.Get_HandMode() :n})");
        Assert_True(Check_Drum(EMars_Tumbler_Drum::Returning), f"the drum is returning (got {_Tumbler.Get_Drum() :n})");
    }

    UFUNCTION()
    private void Step_AssertHome(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Axle.Get_Alpha(), 0.0, 0.0, "the axle Mover is back at alpha 0");
        Assert_False(_Lever.Get_IsManipulating(), "the lever is let go");
        Assert_Equals_Int(_LeverEngagedCount, 0, "the Control never engaged");
        const auto Error = (Get_GripWorld() - _GripHomeWorld).Size();
        Assert_True(Error <= k_PoseTolerance, f"the lever grip is back at its home pose ({Error :.3} cm off)");
    }
}
