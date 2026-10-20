// The combination G then H, fed by real sources through the world's driver and the sink's rising edges: H first is
// rejected (and resets nothing, there being no progress), G then H completes it and asserts the sequence's own source
// on Mechanism.Channel.I; a falling edge is not an input; Reset clears the progress and drops the output. Nothing else
// sources G, H or I, which the test checks first.
class UMars_AutoTest_Sequence_WrongInputResetsThenTheRightOrderCompletes : UMars_AutoTestRig_Sequence
{
    private FCk_Handle_MechanismSource _G;
    private FCk_Handle_MechanismSource _H;
    private FCk_Handle_MechanismSource _Output;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        TArray<FGameplayTag> Steps;
        Steps.Add(GameplayTags::Mechanism_Channel_G);
        Steps.Add(GameplayTags::Mechanism_Channel_H);
        AddSequence(InHandle, Make_Spec(Steps));

        Add_Step("nothing else sources the channels; add the sources", n"Step_AddSources");
        Add_Step_WaitUntil("the sequence is set up", n"Check_SetUp", 0, 0);
        Add_Step("H rises first", n"Step_RaiseH");
        Add_Step_WaitUntil("H is rejected", n"Check_Rejected", k_SlowPolls, 0);
        Add_Step("H falls; G rises", n"Step_DropHRaiseG");
        Add_Step_WaitUntil("G is accepted as step 0", n"Check_FirstAccepted", k_SlowPolls, 0);
        Add_Step("the falling H was not an input", n"Step_AssertFallIgnored");
        Add_Step("H rises", n"Step_RaiseH");
        Add_Step_WaitUntil("the sequence completes and asserts its output", n"Check_Completed", k_SlowPolls, 0);
        Add_Step("reset it", n"Step_Reset");
        Add_Step_WaitUntil("the reset clears progress and drops the output", n"Check_Reset", k_SlowPolls, 0);
        Add_Step("one rejection, two accepts, one completion, one reset", n"Step_AssertCounts");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AddSources(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(utils_mechanism_source::Get_SourcesOn(InHandle, GameplayTags::Mechanism_Channel_G).Num(), 0, "nothing sources G");
        Assert_Equals_Int(utils_mechanism_source::Get_SourcesOn(InHandle, GameplayTags::Mechanism_Channel_H).Num(), 0, "nothing sources H");
        Assert_Equals_Int(utils_mechanism_source::Get_SourcesOn(InHandle, GameplayTags::Mechanism_Channel_I).Num(), 0, "nothing sources I");

        _G = AddSource(InHandle, GameplayTags::Mechanism_Channel_G);
        _H = AddSource(InHandle, GameplayTags::Mechanism_Channel_H);

        auto OutputSpec = FMars_MechanismSource_Spec();
        OutputSpec.OutputChannel = GameplayTags::Mechanism_Channel_I;
        _Output = utils_mechanism_source::Add(_Entity, OutputSpec);
    }

    UFUNCTION()
    private void Check_SetUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Sequence.Has_Fragment(FMars_Tag_Sequence_NeedsSetup) == false);
    }

    UFUNCTION()
    private void Step_RaiseH(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _H.Request_SetOutput(FMars_Request_MechanismSource_SetOutput(EMars_MechanismSource_Output::Asserted));
    }

    UFUNCTION()
    private void Check_Rejected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Rejected.Num() == 1);
    }

    UFUNCTION()
    private void Step_DropHRaiseG(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Rejected[0] == GameplayTags::Mechanism_Channel_H, "the rejection names H");
        Assert_Equals_Int(_Sequence.Get_Progress(), 0, "no progress");
        Assert_Equals_Int(_Resets, 0, "a reset with no progress broadcasts nothing");

        _H.Request_SetOutput(FMars_Request_MechanismSource_SetOutput(EMars_MechanismSource_Output::Deasserted));
        _G.Request_SetOutput(FMars_Request_MechanismSource_SetOutput(EMars_MechanismSource_Output::Asserted));
    }

    UFUNCTION()
    private void Check_FirstAccepted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Accepted.Num() == 1 && _Sequence.Get_Progress() == 1);
    }

    UFUNCTION()
    private void Step_AssertFallIgnored(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Accepted[0], 0, "G was accepted as step 0");
        Assert_Equals_Int(_Rejected.Num(), 1, "H falling was neither accepted nor rejected");
        Assert_False(_Sequence.Get_IsComplete(), "one of two steps is not complete");
    }

    UFUNCTION()
    private void Check_Completed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Sequence.Get_IsComplete() && _Completed == 1 && _Output.Get_IsAsserted());
    }

    UFUNCTION()
    private void Step_Reset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Sequence.Request_Reset();
    }

    UFUNCTION()
    private void Check_Reset(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Sequence.Get_Progress() == 0 && _Sequence.Get_IsComplete() == false && _Output.Get_IsAsserted() == false);
    }

    UFUNCTION()
    private void Step_AssertCounts(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Rejected.Num(), 1, "one rejection");
        Assert_Equals_Int(_Accepted.Num(), 2, "two accepted steps");
        Assert_True(_Accepted.Num() == 2 && _Accepted[1] == 1, "H was accepted as step 1");
        Assert_Equals_Int(_Completed, 1, "one completion");
        Assert_Equals_Int(_Resets, 1, "one reset");
    }

    private FCk_Handle_MechanismSource AddSource(FCk_Handle InHandle, FGameplayTag InChannel)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Spec = FMars_MechanismSource_Spec();
        Spec.OutputChannel = InChannel;
        return utils_mechanism_source::Add(Entity, Spec);
    }
}
