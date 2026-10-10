// The chop is the kernel's own clock: a Cutting with no cleaver drawn at all (no Mover anywhere) chops. A chop request
// broadcasts OnChopStarted at once, lands (OnChopLanded) no sooner than ChopSeconds later while the kernel still reads
// chopping, and the kernel reads Idle again no sooner than a second ChopSeconds after the landing; a second chop then
// starts and lands the same way. Two starts, two landings.
class UMars_AutoTest_Cutting_TheChopClockIsTheKernels : UMars_AutoTestRig_Cutting
{
    // The poll that sees an edge comes up to a frame after the Tick that made it.
    private const float32 k_FrameSlackSeconds = 0.05f;

    private float32 _ChopTime = 0.0f;
    private float32 _LandTime = 0.0f;
    private float32 _IdleTime = 0.0f;
    private bool _ChoppingAtLanding = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, FMars_Cutting_Spec());

        _Cutting.BindTo_OnChopStarted(FMars_Delegate_Cutting_OnChopStarted(this, n"OnChopStarted"));
        _Cutting.BindTo_OnChopLanded(FMars_Delegate_Cutting_OnChopLanded(this, n"OnChopLanded"));
        _Cutting.BindTo_OnChopLanded(FMars_Delegate_Cutting_OnChopLanded(this, n"OnChopLandedTimed"));

        Add_Step("chop", n"Step_Chop");
        Add_Step_WaitUntil("the chop landed", n"Check_Landed1", 0, 0);
        Add_Step_WaitUntil("the cleaver is back up", n"Check_Idle", 0, 0);
        Add_Step("the kernel's clock ran the strike and the recover", n"Step_AssertClock");
        Add_Step("chop again", n"Step_Chop");
        Add_Step_WaitUntil("the second chop landed and the cleaver is back up", n"Check_Landed2AndIdle", 0, 0);
        Add_Step("two starts, two landings", n"Step_AssertTwoChops");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Chop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Cutting), "the feature composed with no Mover");
        _ChopTime = Get_Now();
        _Cutting.Request_Chop(FMars_Request_Cutting_Chop());
    }

    UFUNCTION()
    private void Check_Landed1(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ChopsLanded >= 1);
    }

    UFUNCTION()
    private void Check_Idle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsIdle = _Cutting.Get_IsChopping() == false;
        if (IsIdle)
        { _IdleTime = Get_Now(); }

        auto Res = OutResult;
        Res.Set(IsIdle);
    }

    UFUNCTION()
    private void Step_AssertClock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto ChopSeconds = _Cutting.Get_Spec().ChopSeconds;
        Assert_Equals_Int(_ChopsStarted, 1, "OnChopStarted fired once");
        Assert_True(_LandTime - _ChopTime >= ChopSeconds - k_FrameSlackSeconds,
            f"the chop landed {_LandTime - _ChopTime} s after it started (strike {ChopSeconds} s)");
        Assert_True(_ChoppingAtLanding, "the kernel still read chopping as the chop landed");
        Assert_True(_IdleTime - _LandTime >= ChopSeconds - k_FrameSlackSeconds,
            f"the cleaver was back up {_IdleTime - _LandTime} s after the landing (recover {ChopSeconds} s)");
    }

    UFUNCTION()
    private void Check_Landed2AndIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ChopsLanded >= 2 && _Cutting.Get_IsChopping() == false);
    }

    UFUNCTION()
    private void Step_AssertTwoChops(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ChopsStarted, 2, "two OnChopStarted");
        Assert_Equals_Int(_ChopsLanded, 2, "two OnChopLanded");
    }

    UFUNCTION()
    private void OnChopLandedTimed(FCk_Handle_Cutting InCutting)
    {
        if (_LandTime == 0.0f)
        {
            _LandTime = Get_Now();
            _ChoppingAtLanding = InCutting.Get_IsChopping();
        }
    }

    private float32 Get_Now() const
    {
        return float32(System::GetGameTimeInSeconds());
    }
}
