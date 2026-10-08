// A press on the hovered hatch swings it open; a second press while it swings is refused (HatchMoving) and nothing is queued
// (it rests Open). Shut again, the lever is gripped, rocked and let go; a press on the hatch while the drum returns is
// refused (NotHome) and the hatch stays Closed; once the drum is home the same press opens it.
class UMars_AutoTest_Tumbler_TheHatchTogglesOnlyAtHomeAndSettled : UMars_AutoTestRig_Tumbler
{
    default _TimeoutSeconds = 12.0f;

    private int32 _RefusalsBefore = 0;
    private bool _MissedTheReturn = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());

        Add_Step_WaitUntil("the station's nodes are posed", n"Check_NodesPosed", 0, 2.0f);
        Add_Step("look at the hatch", n"Step_LookToHatch");
        Add_Step_WaitUntil("the hatch is hovered", n"Check_HoveredHatch", 0, 2.0f);
        Add_Step("press on the hatch", n"Step_Press");
        Add_Step_WaitUntil("the hatch is opening", n"Check_HatchOpening", 0, 1.0f);
        Add_Step("press again while it swings", n"Step_PressAgain");
        Add_Step_WaitUntil("the second press is answered", n"Check_Refused", 0, 1.0f);
        Add_Step("the second press was refused as HatchMoving", n"Step_AssertMoving");
        Add_Step_WaitUntil("the hatch is open", n"Check_HatchOpen", 0, 2.0f);
        Add_Step_WaitSeconds("nothing queued may toggle it back", 0.5f);
        Add_Step("the hatch rests Open after one opening", n"Step_AssertStillOpen");
        Add_Steps_CloseHatch();
        Add_Steps_Grip();
        Add_Step_Rock("rock down for 20 frames", k_RockDegrees, 20);
        Add_Step("let go", n"Step_Release");
        Add_Step_WaitUntil("a press lands on the hatch while the drum returns", n"Check_PressedWhileReturning", 0, 2.0f);
        Add_Step_WaitUntil("the press is answered", n"Check_Refused", 0, 1.0f);
        Add_Step("the press was refused as NotHome and the hatch stayed shut", n"Step_AssertNotHome");
        Add_Step_WaitUntil("the drum is home", n"Check_DrumHome", 0, 2.0f);
        Add_Steps_OpenHatch();
        Add_Step("the hatch opened at home", n"Step_AssertOpenedAtHome");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_PressAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _RefusalsBefore = _Refusals.Num();
        Press();
    }

    UFUNCTION()
    private void Check_Refused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Refusals.Num() > _RefusalsBefore);
    }

    UFUNCTION()
    private void Step_AssertMoving(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Refusals.Num(), _RefusalsBefore + 1, "one refusal");
        Assert_True(_Refusals.Last() == EMars_Tumbler_Refusal::HatchMoving, f"refused as HatchMoving (got {_Refusals.Last() :n})");
    }

    UFUNCTION()
    private void Step_AssertStillOpen(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Check_Hatch(EMars_Tumbler_Hatch::Open), f"the hatch is still Open (got {_Tumbler.Get_Hatch() :n})");
        Assert_Equals_Int(_Hatches.Num(), 2, "two hatch edges: Opening, Open");
        if (_Hatches.Num() < 2)
        { return; }

        Assert_True(_Hatches[0] == EMars_Tumbler_Hatch::Opening && _Hatches[1] == EMars_Tumbler_Hatch::Open, "Opening then Open");
        Assert_True(_HatchMover.Get_Target() == EMars_Mover_Pose::End, "the hatch Mover still targets open");
    }

    // Keeps the cursor on the hatch tab (it rides the returning drum) and presses once the hatch is hovered while the drum
    // still returns.
    UFUNCTION()
    private void Check_PressedWhileReturning(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (Check_Drum(EMars_Tumbler_Drum::Returning) == false)
        {
            _MissedTheReturn = true;
            Res.Set(true);
            return;
        }

        if (Check_Hovered(EMars_Tumbler_Target::Hatch))
        {
            _RefusalsBefore = _Refusals.Num();
            Press();
            Res.Set(true);
            return;
        }

        LookToHatch();
        Res.Set(false);
    }

    UFUNCTION()
    private void Step_AssertNotHome(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_MissedTheReturn, "the press landed while the drum was returning");
        Assert_True(_Refusals.Last() == EMars_Tumbler_Refusal::NotHome, f"refused as NotHome (got {_Refusals.Last() :n})");
        Assert_True(Check_Hatch(EMars_Tumbler_Hatch::Closed), f"the hatch stayed Closed (got {_Tumbler.Get_Hatch() :n})");
    }

    UFUNCTION()
    private void Step_AssertOpenedAtHome(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Check_Drum(EMars_Tumbler_Drum::Home), "the drum is home");
        Assert_True(_Hatches.Last() == EMars_Tumbler_Hatch::Open, "the last hatch edge is Open");
    }
}
