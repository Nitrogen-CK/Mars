// A charge fills every step at once; then one step drains every SecondsPerStep, each change broadcast once, and the
// countdown stays empty (and stops running) once the last step is gone.
class UMars_AutoTest_Countdown_ChargeDrainsOneStepAtATime : UCk_AutoTest_Base
{
    private FCk_Handle_Countdown _Countdown;
    private TArray<int32> _Changes;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Countdown = utils_countdown::Add(Entity, FMars_Countdown_Spec(3, 0.2f, false));
        _Countdown.BindTo_OnRemainingChanged(FMars_Delegate_Countdown_OnRemainingChanged(this, n"OnRemainingChanged"));

        Add_Step("it starts empty and idle", n"Step_AssertEmpty");
        Add_Step("charge it", n"Step_Charge");
        Add_Step_WaitUntil("every step is charged", n"Check_Full", 0, 5.0f);
        Add_Step_WaitUntil("it drains to empty", n"Check_Empty", 0, 5.0f);
        Add_Step_WaitSeconds("let it sit empty", 0.3f);
        Add_Step("it drained one step at a time and stopped", n"Step_AssertDrained");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnRemainingChanged(FCk_Handle_Countdown InCountdown, int32 InRemaining)
    {
        _Changes.Add(InRemaining);
    }

    UFUNCTION()
    private void Step_AssertEmpty(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Countdown.Get_Remaining(), 0, "an uncharged countdown starts empty");
        Assert_False(_Countdown.Has_Fragment(FMars_Tag_Countdown_Running), "an empty countdown does not run");
    }

    UFUNCTION()
    private void Step_Charge(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Countdown.Request_Charge();
    }

    UFUNCTION()
    private void Check_Full(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Countdown.Get_Remaining() == 3);
    }

    UFUNCTION()
    private void Check_Empty(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Countdown.Get_Remaining() == 0);
    }

    UFUNCTION()
    private void Step_AssertDrained(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Changes.Num(), 4, "one broadcast for the charge and one per drained step");
        if (_Changes.Num() == 4)
        {
            Assert_Equals_Int(_Changes[0], 3, "the charge fills every step");
            Assert_Equals_Int(_Changes[1], 2, "then one step drains");
            Assert_Equals_Int(_Changes[2], 1, "then another");
            Assert_Equals_Int(_Changes[3], 0, "then the last");
        }

        Assert_Equals_Int(_Countdown.Get_Remaining(), 0, "it stays empty");
        Assert_False(_Countdown.Has_Fragment(FMars_Tag_Countdown_Running), "an empty countdown stops running");
    }
}
