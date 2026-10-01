// A charge while the countdown is draining refills every step and restarts the current one, then it drains from full.
class UMars_AutoTest_Countdown_RechargeWhileDrainingRefills : UCk_AutoTest_Base
{
    private FCk_Handle_Countdown _Countdown;
    private TArray<int32> _Changes;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Countdown = utils_countdown::Add(Entity, FMars_Countdown_Spec(4, 0.25f, false));
        _Countdown.BindTo_OnRemainingChanged(FMars_Delegate_Countdown_OnRemainingChanged(this, n"OnRemainingChanged"));

        Add_Step("charge it", n"Step_Charge");
        Add_Step_WaitUntil("it has drained to half", n"Check_Half", 0, 5.0f);
        Add_Step("charge it again", n"Step_Charge");
        Add_Step_WaitUntil("it is full again", n"Check_Full", 0, 5.0f);
        Add_Step_WaitUntil("it drains to empty", n"Check_Empty", 0, 5.0f);
        Add_Step("it refilled from half and drained from full", n"Step_AssertSequence");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnRemainingChanged(FCk_Handle_Countdown InCountdown, int32 InRemaining)
    {
        _Changes.Add(InRemaining);
    }

    UFUNCTION()
    private void Step_Charge(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Countdown.Request_Charge();
    }

    UFUNCTION()
    private void Check_Half(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Countdown.Get_Remaining() == 2);
    }

    UFUNCTION()
    private void Check_Full(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Countdown.Get_Remaining() == 4);
    }

    UFUNCTION()
    private void Check_Empty(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Countdown.Get_Remaining() == 0);
    }

    UFUNCTION()
    private void Step_AssertSequence(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TArray<int32> Expected;
        Expected.Add(4);
        Expected.Add(3);
        Expected.Add(2);
        Expected.Add(4);
        Expected.Add(3);
        Expected.Add(2);
        Expected.Add(1);
        Expected.Add(0);

        Assert_Equals_Int(_Changes.Num(), Expected.Num(), "charge, two drains, recharge, four drains");
        const auto Count = Math::Min(_Changes.Num(), Expected.Num());
        for (int32 Index = 0; Index < Count; ++Index)
        { Assert_Equals_Int(_Changes[Index], Expected[Index], f"change [{Index}]"); }
    }
}
