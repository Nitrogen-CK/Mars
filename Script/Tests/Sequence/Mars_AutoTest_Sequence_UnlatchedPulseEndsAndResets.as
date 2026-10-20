// An unlatched sequence over one step completes on its input and resets itself when its 0.3 s output pulse ends: one
// completion, then one reset, progress back to 0. Inputs are requested directly; its sink listens on
// Mechanism.Channel.J, which nothing sources (checked first), so no stray edge reaches it.
class UMars_AutoTest_Sequence_UnlatchedPulseEndsAndResets : UMars_AutoTestRig_Sequence
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        TArray<FGameplayTag> Steps;
        Steps.Add(GameplayTags::Mechanism_Channel_J);
        auto Spec = Make_Spec(Steps);
        Spec.Latch = false;
        Spec.OutputPulseSeconds = 0.3f;
        AddSequence(InHandle, Spec);

        Add_Step("nothing sources J; input the step", n"Step_Input");
        Add_Step_WaitUntil("the sequence completes", n"Check_Completed", 0, 0);
        Add_Step("complete, not yet reset", n"Step_AssertCompleted");
        Add_Step_WaitUntil("the pulse ends and resets it", n"Check_Reset", k_SlowPolls, 0);
        Add_Step("one completion, one reset", n"Step_AssertReset");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Input(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(utils_mechanism_source::Get_SourcesOn(InHandle, GameplayTags::Mechanism_Channel_J).Num(), 0, "nothing sources J");
        _Sequence.Request_Input(FMars_Request_Sequence_Input(GameplayTags::Mechanism_Channel_J));
    }

    UFUNCTION()
    private void Check_Completed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Completed == 1);
    }

    UFUNCTION()
    private void Step_AssertCompleted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Sequence.Get_IsComplete(), "the one step completes it");
        Assert_Equals_Int(_Resets, 0, "the pulse has not ended yet");
    }

    UFUNCTION()
    private void Check_Reset(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Resets == 1);
    }

    UFUNCTION()
    private void Step_AssertReset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Sequence.Get_IsComplete(), "no longer complete");
        Assert_Equals_Int(_Sequence.Get_Progress(), 0, "progress back to 0");
        Assert_Equals_Int(_Completed, 1, "completed once");
    }
}
