// The look delta reaches InputIntents as requests: one drain sums the frame's deltas and advances LookDeltaSequence once;
// a frame with no delta advances nothing; the next drain replaces the delta instead of accumulating it.
class UMars_AutoTest_InputIntents_LookDeltaSequenceAdvancesPerDrain : UCk_AutoTest_Base
{
    private FCk_Handle_InputIntents _Intents;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = InHandle;
        _Intents = utils_input_intents::Add(Entity);

        Add_Step("no delta before any request", n"Step_AssertInitial");
        Add_Step("add two deltas in one frame", n"Step_AddTwoDeltas");
        Add_Step_WaitUntil("the first drain advances the sequence", n"Check_SequenceIsOne", 0, 5.0f);
        Add_Step("a drain sums the frame's deltas", n"Step_AssertSummed");
        Add_Step_WaitSeconds("still frames", 0.2f);
        Add_Step("a still frame does not advance the sequence", n"Step_AssertStill");
        Add_Step("add one more delta", n"Step_AddOneDelta");
        Add_Step_WaitUntil("the second drain advances the sequence", n"Check_SequenceIsTwo", 0, 5.0f);
        Add_Step("the latest drain replaces the delta", n"Step_AssertReplaced");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertInitial(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Intents.Get_LookDeltaSequence(), 0, "the sequence starts at 0");
        Assert_True(_Intents.Get_LookDelta() == FVector::ZeroVector, "the delta starts at zero");
    }

    UFUNCTION()
    private void Step_AddTwoDeltas(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Intents.Request_AddLookDelta(FMars_Request_InputIntents_AddLookDelta(FVector(1.0, 2.0, 0.0)));
        _Intents.Request_AddLookDelta(FMars_Request_InputIntents_AddLookDelta(FVector(3.0, 4.0, 0.0)));
    }

    UFUNCTION()
    private void Check_SequenceIsOne(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Intents.Get_LookDeltaSequence() == 1);
    }

    UFUNCTION()
    private void Step_AssertSummed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto LookDelta = _Intents.Get_LookDelta();
        Assert_True(LookDelta.Equals(FVector(4.0, 6.0, 0.0), 0.001), f"a drain sums the frame's deltas ({LookDelta.ToString()})");
    }

    UFUNCTION()
    private void Step_AssertStill(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Intents.Get_LookDeltaSequence(), 1, "a still frame does not advance the sequence");
    }

    UFUNCTION()
    private void Step_AddOneDelta(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Intents.Request_AddLookDelta(FMars_Request_InputIntents_AddLookDelta(FVector(0.0, -1.0, 0.0)));
    }

    UFUNCTION()
    private void Check_SequenceIsTwo(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Intents.Get_LookDeltaSequence() == 2);
    }

    UFUNCTION()
    private void Step_AssertReplaced(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto LookDelta = _Intents.Get_LookDelta();
        Assert_True(LookDelta.Equals(FVector(0.0, -1.0, 0.0), 0.001), f"the latest drain replaces, never accumulates ({LookDelta.ToString()})");
    }
}
