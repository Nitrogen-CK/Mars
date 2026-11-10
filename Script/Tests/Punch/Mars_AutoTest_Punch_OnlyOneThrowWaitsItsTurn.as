// Throws faster than the rhythm are not all jabs. Three throws in one frame are one throw: one jab starts and nothing
// waits. Two more inside the interval leave one throw waiting, and one more while it waits is dropped. The waiting throw
// goes once the interval has passed - here longer than a whole jab, so the first fist is already home when the second is
// thrown - with the other hand, and nothing is thrown after it: six throws were two jabs. No transform, no dealer:
// nothing here has a place in the world.
class UMars_AutoTest_Punch_OnlyOneThrowWaitsItsTurn : UCk_AutoTest_Base
{
    // A poll budget, not a ceiling: the jabs run on the rhythm's own clock.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle_Punch _Punch;
    private FMars_Punch_Spec _Spec;
    private TArray<EMars_Hand> _Thrown;
    // The left fist's stroke when the right was thrown.
    private TOptional<EMars_Punch_Stroke> _LeftStrokeAtRightThrow;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        // The interval outlasts a whole jab (0.4 s), so a throw that waited it out finds the first fist home.
        _Spec.Rhythm.ImpactSeconds = 0.15f;
        _Spec.Rhythm.RecoverySeconds = 0.25f;
        _Spec.Rhythm.IntervalSeconds = 1.0f;
        _Spec.Rhythm.ComboSeconds = 3.0f;

        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Punch = utils_punch::Add(Entity, _Spec);
        _Punch.BindTo_OnThrown(FMars_Delegate_Punch_OnThrown(this, n"OnThrown"));

        Add_Step("three throws in one frame", n"Step_ThrowThree");
        Add_Step_WaitUntil("a jab is thrown", n"Check_OneThrown", 0, 0);
        Add_Step("one jab, nothing waiting; two more throws inside the interval", n"Step_AssertOneJabAndThrowTwo");
        Add_Step_WaitUntil("a throw waits its turn", n"Check_Waiting", 0, 0);
        Add_Step("still one jab; one more throw while one waits", n"Step_AssertWaitingAndThrowOne");
        Add_Step_WaitUntil("the waiting throw goes", n"Check_TwoThrown", k_SlowPolls, 0);
        Add_Step("it is the right, thrown after the left came home", n"Step_AssertSecondJab");
        Add_Step_WaitSeconds("a third jab would be thrown an interval later", 1.5f);
        Add_Step("six throws were two jabs", n"Step_AssertNoThird");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnThrown(FCk_Handle_Punch InPunch, EMars_Hand InHand)
    {
        _Thrown.Add(InHand);
        if (InHand == EMars_Hand::Right && _LeftStrokeAtRightThrow.IsSet() == false)
        { _LeftStrokeAtRightThrow = TOptional<EMars_Punch_Stroke>(InPunch.Get_Stroke(EMars_Hand::Left)); }
    }

    UFUNCTION()
    private void Step_ThrowThree(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Punch.Request_Throw(FMars_Request_Punch_Throw());
        _Punch.Request_Throw(FMars_Request_Punch_Throw());
        _Punch.Request_Throw(FMars_Request_Punch_Throw());
    }

    UFUNCTION()
    private void Check_OneThrown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Punch.Get_JabsThrown() >= 1);
    }

    UFUNCTION()
    private void Step_AssertOneJabAndThrowTwo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Thrown.Num() == 1 && _Thrown[0] == EMars_Hand::Left, f"three throws in one frame were one jab, the left (thrown {_Thrown.Num()})");
        Assert_False(_Punch.Get_HasWaitingThrow(), "nothing waits: the frame's throws were one throw");

        _Punch.Request_Throw(FMars_Request_Punch_Throw());
        _Punch.Request_Throw(FMars_Request_Punch_Throw());
    }

    UFUNCTION()
    private void Check_Waiting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Punch.Get_HasWaitingThrow());
    }

    UFUNCTION()
    private void Step_AssertWaitingAndThrowOne(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Punch.Get_JabsThrown(), 1, "a throw inside the interval waits: still one jab");

        _Punch.Request_Throw(FMars_Request_Punch_Throw());
    }

    UFUNCTION()
    private void Check_TwoThrown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Punch.Get_JabsThrown() >= 2);
    }

    UFUNCTION()
    private void Step_AssertSecondJab(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Thrown.Num() == 2 && _Thrown[1] == EMars_Hand::Right, f"the waiting throw was the right (thrown {_Thrown.Num()})");
        Assert_True(_LeftStrokeAtRightThrow.IsSet() && _LeftStrokeAtRightThrow.GetValue() == EMars_Punch_Stroke::None,
            "the left fist was home when the right was thrown: the throw waited out the interval, which outlasts a jab");
        Assert_False(_Punch.Get_HasWaitingThrow(), "nothing waits now: the throw that came while one waited was dropped");
    }

    UFUNCTION()
    private void Step_AssertNoThird(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Punch.Get_JabsThrown(), 2, "no third jab");
        Assert_Equals_Int(_Thrown.Num(), 2, "OnThrown fired twice");
        Assert_False(_Punch.Get_IsPunching(), "both fists are home");
    }
}
