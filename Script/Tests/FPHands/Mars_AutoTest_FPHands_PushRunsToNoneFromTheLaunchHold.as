// A push requested at rest runs the Hands sub-SM Rest -> Push -> Rest: the phase goes Push, None, and through the whole
// push the gloves keep the hold the request carried, even after the feature's own hold empties (as it does a few frames
// after a real launch). The push curve starts at the hold, peaks at OutSeconds and is back at the hold when it ends.
class UMars_AutoTest_FPHands_PushRunsToNoneFromTheLaunchHold : UMars_AutoTestRig_Hands
{
    // Every poll that reads Push must see the launch hold kept: one bad sample fails the run.
    private int32 _PushPolls = 0;
    private bool _PushHoldWasTwoHanded = true;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_FPHands_Spec();
        Spec.Push.OutSeconds = 0.1f;
        Spec.Push.BackSeconds = 0.2f;
        Add_Hands(InHandle, Spec);
        Add_HandsSm();
        Log_Phases();

        Add_Step("the push curve starts at the hold, peaks at OutSeconds and returns", n"Step_AssertCurve");
        Add_Step_WaitUntil("the Hands SM rests in Rest, listening for a push", n"Check_RestListeningForPush", 0, 5.0f);
        Add_Step("request a throw push from a two-handed hold, then empty the hold", n"Step_RequestPush");
        Add_Step_WaitUntil("the phase went through Push back to None", n"Check_BackToNone", 0, 5.0f);
        Add_Step("Push ran once and kept the launch hold while the feature's hold was empty", n"Step_AssertSequence");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertCurve(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spec = FMars_FPHands_PushSpec();
        Spec.OutSeconds = 0.1f;
        Spec.BackSeconds = 0.2f;
        Assert_True(Math::Abs(utils_fphands::Get_PushAlpha(Spec, 0.0f)) < 0.001f, "push starts at the hold");
        Assert_True(Math::Abs(utils_fphands::Get_PushAlpha(Spec, 0.1f) - 1.0f) < 0.001f, "push is fully out at OutSeconds");
        Assert_True(Math::Abs(utils_fphands::Get_PushAlpha(Spec, 0.3f)) < 0.001f, "push is back at the hold when it ends");
        Assert_True(Math::Abs(utils_fphands::Get_PushSeconds(Spec) - 0.3f) < 0.001f, "push lasts OutSeconds + BackSeconds");
    }

    UFUNCTION()
    private void Step_RequestPush(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Hold = FMars_FPHands_Hold();
        Hold.Kind = EMars_FPHands_HoldKind::TwoHanded;
        _Hands.Request_StartPush(FMars_Request_FPHands_StartPush(Hold, EMars_LaunchKind::Throw));
        _Hands.Request_SetHold(FMars_Request_FPHands_SetHold(FCk_Handle_Item()));
    }

    UFUNCTION()
    private void Check_BackToNone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (_Hands.Get_Phase() == EMars_FPHands_Phase::Push)
        {
            const auto KeptLaunchHold = _Hands.Get_PushHold().Kind == EMars_FPHands_HoldKind::TwoHanded
                && _Hands.Get_Hold().Kind == EMars_FPHands_HoldKind::Empty && _Hands.Get_PushKind() == EMars_LaunchKind::Throw;
            _PushPolls += 1;
            _PushHoldWasTwoHanded = _PushHoldWasTwoHanded && KeptLaunchHold;
        }

        auto Res = OutResult;
        Res.Set(_Phases.Num() >= 2 && _Hands.Get_Phase() == EMars_FPHands_Phase::None);
    }

    UFUNCTION()
    private void Step_AssertSequence(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_PushPolls > 0, "the Push phase was observed at least once");
        Assert_True(_PushHoldWasTwoHanded,
            f"on every one of {_PushPolls} Push polls the gloves kept the launch's two-handed throw hold while the feature's hold was empty");

        Assert_Equals_Int(_Phases.Num(), 2, "two phase changes");
        if (_Phases.Num() != 2)
        { return; }

        Assert_True(_Phases[0] == EMars_FPHands_Phase::Push, f"first change is to Push (got {_Phases[0] :n})");
        Assert_True(_Phases[1] == EMars_FPHands_Phase::None, f"second change is back to None (got {_Phases[1] :n})");
    }
}
