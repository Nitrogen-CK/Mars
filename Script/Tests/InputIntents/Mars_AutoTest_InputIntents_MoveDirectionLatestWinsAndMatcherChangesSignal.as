// SetMoveDirection: of two in one drain the later wins. SetMatcher broadcasts OnMatcherChanged(Prev, New) only when the
// matcher changes: once to the new matcher, not again for the same one, once more back to none.
class UMars_AutoTest_InputIntents_MoveDirectionLatestWinsAndMatcherChangesSignal : UCk_AutoTest_Base
{
    private FCk_Handle_InputIntents _Intents;
    private UMars_AutoTestHelper_UseKey _Key;
    private int32 _Changes = 0;
    private FCk_Handle_IntentMatcher _LastPrev;
    private FCk_Handle_IntentMatcher _LastNew;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = InHandle;
        _Intents = utils_input_intents::Add(Entity);
        _Intents.BindTo_OnMatcherChanged(FMars_Delegate_InputIntents_OnMatcherChanged(this, n"OnMatcherChanged"));

        _Key = Cast<UMars_AutoTestHelper_UseKey>(NewObject(this, UMars_AutoTestHelper_UseKey));
        _Key.Build(InHandle, EKeys::F9);

        Add_Step("two move directions and a matcher in one frame", n"Step_TwoMovesAndAMatcher");
        Add_Step_WaitUntil("the frame's requests are drained", n"Check_Drained", 0, 0);
        Add_Step("the later move direction won and the matcher change was announced once", n"Step_AssertFirstDrain");
        Add_Step("the same matcher again, and a stop", n"Step_SameMatcherAndStop");
        Add_Step_WaitUntil("the frame's requests are drained", n"Check_Drained", 0, 0);
        Add_Step("the move stopped and the same matcher announced nothing", n"Step_AssertSameMatcher");
        Add_Step("no matcher", n"Step_ClearMatcher");
        Add_Step_WaitUntil("the clear is drained", n"Check_Drained", 0, 0);
        Add_Step("the clear was announced from the old matcher to none", n"Step_AssertCleared");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnMatcherChanged(FCk_Handle_InputIntents InIntents, FCk_Handle_IntentMatcher InPrev, FCk_Handle_IntentMatcher InNew)
    {
        _Changes += 1;
        _LastPrev = InPrev;
        _LastNew = InNew;
    }

    UFUNCTION()
    private void Check_Drained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Intents.Has_Fragment(FMars_Fragment_InputIntents_Requests) == false);
    }

    UFUNCTION()
    private void Step_TwoMovesAndAMatcher(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Key.Get_Matcher()), "the key stack built a matcher");
        _Intents.Request_SetMoveDirection(FMars_Request_InputIntents_SetMoveDirection(FVector(1.0, 0.0, 0.0)));
        _Intents.Request_SetMoveDirection(FMars_Request_InputIntents_SetMoveDirection(FVector(0.0, 1.0, 0.0)));
        _Intents.Request_SetMatcher(FMars_Request_InputIntents_SetMatcher(_Key.Get_Matcher()));
    }

    UFUNCTION()
    private void Step_AssertFirstDrain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Move = _Intents.Get_MoveDirection();
        Assert_True(Move.Equals(FVector(0.0, 1.0, 0.0), 0.0001), f"the later move direction (0, 1, 0) won (got [{Move.ToString()}])");
        Assert_Equals_Int(_Changes, 1, "the matcher change was announced once");
        Assert_True(ck::Is_NOT_Valid(_LastPrev) && _LastNew == _Key.Get_Matcher(), "from no matcher to the key stack's");
        Assert_True(_Intents.Get_Matcher() == _Key.Get_Matcher(), "the intents read the key stack's matcher");
    }

    UFUNCTION()
    private void Step_SameMatcherAndStop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Intents.Request_SetMatcher(FMars_Request_InputIntents_SetMatcher(_Key.Get_Matcher()));
        _Intents.Request_SetMoveDirection(FMars_Request_InputIntents_SetMoveDirection(FVector::ZeroVector));
    }

    UFUNCTION()
    private void Step_AssertSameMatcher(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Move = _Intents.Get_MoveDirection();
        Assert_True(Move.Equals(FVector::ZeroVector, 0.0001), f"the stop applied (got [{Move.ToString()}])");
        Assert_Equals_Int(_Changes, 1, "the same matcher again announced nothing");
    }

    UFUNCTION()
    private void Step_ClearMatcher(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Intents.Request_SetMatcher(FMars_Request_InputIntents_SetMatcher(FCk_Handle_IntentMatcher()));
    }

    UFUNCTION()
    private void Step_AssertCleared(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Changes, 2, "the clear was announced");
        Assert_True(_LastPrev == _Key.Get_Matcher() && ck::Is_NOT_Valid(_LastNew), "from the key stack's matcher to none");
        Assert_True(ck::Is_NOT_Valid(_Intents.Get_Matcher()), "the intents read no matcher");
    }
}
