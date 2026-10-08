// A grip begun OnRelease (a held crank) has no threshold: pulled far past EngageAlpha it stays gripped at the hard stop and
// nothing engages or finishes; pulled back it rocks back while still held; only EndManipulation lets go, and the handle then
// settles to rest. No interaction: the grip is the kernel's own, not the player's.
class UMars_AutoTest_Control_HeldGripRocksInsideTheArcUntilRelease : UMars_AutoTestRig_Lever
{
    private const int32 k_PushFrames = 40;
    private const int32 k_RockBackFrames = 20;
    private const float32 k_NudgeDegrees = 4.0f;

    private int32 _PushedFrames = 0;
    private int32 _RockedBackFrames = 0;
    private float32 _AlphaBeforeRockBack = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildLever(InHandle, EMars_Control_Activation::Inactive);

        Add_Step("grip the lever until release, with no interaction", n"Step_BeginHeldGrip");
        Add_Step_WaitUntil("the lever is gripped", n"Check_IsManipulating", 0, 5.0f);
        Add_Step("the grip is held until release", n"Step_AssertHeldGrip");
        Add_Step_WaitUntil("push past the threshold to the stop", n"Check_PushedToTheStop", 0, 5.0f);
        Add_Step("still gripped at the stop, nothing engaged or finished", n"Step_AssertHeldAtTheStop");
        Add_Step_WaitUntil("pull back while held", n"Check_RockedBack", 0, 5.0f);
        Add_Step("the handle rocked back and is still gripped", n"Step_AssertRockedBack");
        Add_Step("let go", n"Step_EndManipulation");
        Add_Step_WaitUntil("the handle settles back to rest", n"Check_SettledToRest", 0, 5.0f);
        Add_Step("released without engaging", n"Step_AssertReleased");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_BeginHeldGrip(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Control.Request_BeginManipulation(FMars_Request_Control_BeginManipulation(
            FCk_Handle_Interaction(), _Player, EMars_Control_ManipulationCompletion::OnRelease));
    }

    UFUNCTION()
    private void Step_AssertHeldGrip(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Control.Get_ManipulationCompletion() == EMars_Control_ManipulationCompletion::OnRelease,
            "the grip keeps the completion its request asked for");
    }

    // At least k_PushFrames nudges, and on until the spring has carried the handle to the stop.
    UFUNCTION()
    private void Check_PushedToTheStop(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_PushedFrames >= k_PushFrames && _Control.Get_ManipulationAlpha() > 0.97f)
        {
            Res.Set(true);
            return;
        }

        _PushedFrames += 1;
        _Control.Request_Nudge(FMars_Request_Control_Nudge(k_NudgeDegrees));
        Res.Set(_Control.Get_IsManipulating() == false);
    }

    UFUNCTION()
    private void Step_AssertHeldAtTheStop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Control.Get_IsManipulating(), "a held grip is not ended by the threshold");
        Assert_Equals_Float(_Control.Get_ManipulationAlpha(), 1.0f, 0.03f, "the handle rests at the far stop");
        Assert_Equals_Int(_FinishedResults.Num(), 0, "nothing finished");
        Assert_Equals_Int(_EngagedCount, 0, "nothing engaged");
        Assert_False(_Control.Get_IsActive(), "the lever never flipped");
        _AlphaBeforeRockBack = _Control.Get_ManipulationAlpha();
    }

    // At least k_RockBackFrames nudges back, and on until the handle has come back under 0.7.
    UFUNCTION()
    private void Check_RockedBack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_RockedBackFrames >= k_RockBackFrames && _Control.Get_ManipulationAlpha() < 0.7f)
        {
            Res.Set(true);
            return;
        }

        _RockedBackFrames += 1;
        _Control.Request_Nudge(FMars_Request_Control_Nudge(-k_NudgeDegrees));
        Res.Set(_Control.Get_IsManipulating() == false);
    }

    UFUNCTION()
    private void Step_AssertRockedBack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Control.Get_IsManipulating(), "still gripped after pulling back");
        const auto Alpha = _Control.Get_ManipulationAlpha();
        Assert_True(Alpha < 0.7f && Alpha < _AlphaBeforeRockBack,
            f"the handle rocked back from {_AlphaBeforeRockBack} while held (got {Alpha})");
        Assert_Equals_Int(_EngagedCount, 0, "nothing engaged");
    }

    UFUNCTION()
    private void Step_EndManipulation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Control.Request_EndManipulation();
    }

    UFUNCTION()
    private void Step_AssertReleased(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Control.Get_IsManipulating(), "let go");
        Assert_True(_Control.Get_ManipulationCompletion() == EMars_Control_ManipulationCompletion::AtEngageAlpha,
            "no grip reads AtEngageAlpha");
        Assert_Equals_Int(_EngagedCount, 0, "nothing engaged");
        Assert_Equals_Int(_FinishedResults.Num(), 0, "nothing finished");
        Assert_True(_Mover.Get_Target() == EMars_Mover_Pose::Start, "the target is still the rest pose");
    }
}
