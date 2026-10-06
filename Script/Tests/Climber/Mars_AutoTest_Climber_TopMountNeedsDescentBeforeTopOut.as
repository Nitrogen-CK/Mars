// A Top mount starts at the top and holding up there does not top straight back out: the climber must first go below
// 0.95. Then: down at the foot of a fresh Front mount steps off (Bottom), and a jump mid-climb leaves the ladder (Jump).
class UMars_AutoTest_Climber_TopMountNeedsDescentBeforeTopOut : UMars_AutoTestRig_Climber
{
    private float64 _HoldUpStartSeconds = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_Ladder_Spec();
        Spec.Height = 300.0f;
        BuildLadderAndClimber(InHandle, Spec);

        Add_Step("mount from the top", n"Step_MountTop");
        Add_Step_WaitUntil("the climber is climbing", n"Check_Climbing", 0, 2.0f);
        Add_Step("a top mount starts at the top", n"Step_AssertAtTop");
        Add_Step("start holding up at the top", n"Step_StartHoldUp");
        Add_Step_WaitUntil("hold up at the top for 0.3 s", n"Check_HeldUp", 0, 2.0f);
        Add_Step("holding up right after a top mount does not top out", n"Step_AssertStillClimbing");
        Add_Step_WaitUntil("climbing down goes below 0.9", n"Check_Below", 0, 3.0f);
        Add_Step_WaitUntil("climbing up again tops out", n"Check_ToppedOut", 0, 3.0f);
        Add_Step("the climb ended at the top", n"Step_AssertTop");

        Add_Step("mount from the front", n"Step_MountFront");
        Add_Step_WaitUntil("the climber is climbing again", n"Check_Climbing", 0, 2.0f);
        Add_Step("climb down once at the foot", n"Step_ClimbDownOnce");
        Add_Step_WaitUntil("the climber stepped off", n"Check_NotClimbing", 0, 2.0f);
        Add_Step("the climb ended at the bottom", n"Step_AssertBottom");

        Add_Step("mount from the front again", n"Step_MountFront");
        Add_Step_WaitUntil("the climber is climbing a third time", n"Check_Climbing", 0, 2.0f);
        Add_Step_WaitUntil("climbing up reaches 0.3", n"Check_AboveFoot", 0, 3.0f);
        Add_Step("jump off", n"Step_Jump");
        Add_Step_WaitUntil("the climber jumped off", n"Check_NotClimbing", 0, 2.0f);
        Add_Step("the climb ended in a jump", n"Step_AssertJump");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_MountTop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Ladder), "the ladder composed");
        _Climber.Request_Mount(FMars_Request_Climber_Mount(_Ladder, EMars_Ladder_Zone::Top));
    }

    UFUNCTION()
    private void Step_MountFront(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Climber.Request_Mount(FMars_Request_Climber_Mount(_Ladder, EMars_Ladder_Zone::Front));
    }

    UFUNCTION()
    private void Check_NotClimbing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Climber.Get_IsClimbing() == false);
    }

    UFUNCTION()
    private void Step_AssertAtTop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Alpha = _Climber.Get_Alpha();
        Assert_True(Alpha > 0.999f, f"a top mount starts at alpha 1 (alpha {Alpha})");
    }

    UFUNCTION()
    private void Step_StartHoldUp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _HoldUpStartSeconds = System::GetGameTimeInSeconds();
        _Climber.Request_Climb(FMars_Request_Climber_Climb(1.0f));
    }

    // Keeps pushing up every poll until 0.3 s have passed since the hold started.
    UFUNCTION()
    private void Check_HeldUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        _Climber.Request_Climb(FMars_Request_Climber_Climb(1.0f));
        Res.Set(System::GetGameTimeInSeconds() - _HoldUpStartSeconds >= 0.3);
    }

    UFUNCTION()
    private void Step_AssertStillClimbing(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Climber.Get_IsClimbing(), f"still climbing after holding up at the top (a dismount recorded: {_Climber.Get_LastDismount().IsSet()})");
    }

    UFUNCTION()
    private void Check_Below(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        _Climber.Request_Climb(FMars_Request_Climber_Climb(-1.0f));
        Res.Set(_Climber.Get_Alpha() < 0.9f);
    }

    UFUNCTION()
    private void Step_AssertTop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertDismount(EMars_Climber_Dismount::Top, "at the top");
    }

    UFUNCTION()
    private void Step_ClimbDownOnce(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Climber.Request_Climb(FMars_Request_Climber_Climb(-1.0f));
    }

    UFUNCTION()
    private void Step_AssertBottom(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertDismount(EMars_Climber_Dismount::Bottom, "at the bottom");
    }

    UFUNCTION()
    private void Step_Jump(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Climber.Get_IsClimbing(), "climbing before the jump");
        _Climber.Request_Dismount(FMars_Request_Climber_Dismount(EMars_Climber_Dismount::Jump));
    }

    UFUNCTION()
    private void Step_AssertJump(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertDismount(EMars_Climber_Dismount::Jump, "in a jump");
    }
}
