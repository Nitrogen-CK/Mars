// With a 0.3 s step timeout, a first step left without its second resets when the timeout runs out: one accepted step,
// then one reset and progress back to 0, never complete. Inputs are requested directly; its sink listens on
// Mechanism.Channel.J and K, which nothing sources (checked first).
class UMars_AutoTest_Sequence_StepTimeoutResetsProgress : UMars_AutoTestRig_Sequence
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        TArray<FGameplayTag> Steps;
        Steps.Add(GameplayTags::Mechanism_Channel_J);
        Steps.Add(GameplayTags::Mechanism_Channel_K);
        auto Spec = Make_Spec(Steps);
        Spec.StepTimeoutSeconds = TOptional<float32>(0.3f);
        AddSequence(InHandle, Spec);

        Add_Step("nothing sources J or K; input the first step", n"Step_Input");
        Add_Step_WaitUntil("the first step is accepted", n"Check_Accepted", 0, 0);
        Add_Step("progress 1, no reset yet", n"Step_AssertProgress");
        Add_Step_WaitUntil("the timeout resets it", n"Check_Reset", k_SlowPolls, 0);
        Add_Step("progress 0, never complete", n"Step_AssertReset");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Input(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(utils_mechanism_source::Get_SourcesOn(InHandle, GameplayTags::Mechanism_Channel_J).Num(), 0, "nothing sources J");
        Assert_Equals_Int(utils_mechanism_source::Get_SourcesOn(InHandle, GameplayTags::Mechanism_Channel_K).Num(), 0, "nothing sources K");
        _Sequence.Request_Input(FMars_Request_Sequence_Input(GameplayTags::Mechanism_Channel_J));
    }

    UFUNCTION()
    private void Check_Accepted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Accepted.Num() == 1);
    }

    UFUNCTION()
    private void Step_AssertProgress(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Sequence.Get_Progress(), 1, "one step in");
        Assert_Equals_Int(_Resets, 0, "the timeout has not run out yet");
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
        Assert_Equals_Int(_Sequence.Get_Progress(), 0, "the timeout cleared the progress");
        Assert_Equals_Int(_Completed, 0, "never completed");
        Assert_Equals_Int(_Accepted.Num(), 1, "only the first step was accepted");
    }
}
