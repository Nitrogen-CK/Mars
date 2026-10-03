// HoldWhilePowered, the Porter's Wager slab: while a source on the countdown's input channel is asserted, the countdown is
// full and held (no drain, its own source asserted throughout); once the input drops it drains step by step to empty and
// its source drops. The input is a real MechanismSource, so the world's mechanism driver powers the sink, as in the level:
// counts fed straight to the sink would be overwritten by the driver's next recompute.
class UMars_AutoTest_Countdown_HoldWhilePoweredStaysFullThenDrains : UCk_AutoTest_Base
{
    private FCk_Handle_Countdown _Countdown;
    private FCk_Handle_MechanismSink _Sink;
    private FCk_Handle_MechanismSource _Source;
    private FCk_Handle_MechanismSource _Input;
    private FGameplayTag _InputChannel;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _InputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.L");

        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);

        auto SinkSpec = FMars_MechanismSink_Spec();
        SinkSpec.InputChannels.Add(_InputChannel);
        SinkSpec.Rule = EMars_MechanismSink_Rule::AnyChannel;
        _Sink = utils_mechanism_sink::Add(Entity, SinkSpec);

        _Countdown = utils_countdown::Add(Entity, FMars_Countdown_Spec(2, 0.4f, false, true));

        auto SourceSpec = FMars_MechanismSource_Spec();
        SourceSpec.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.M");
        _Source = utils_mechanism_source::Add(Entity, SourceSpec);

        auto InputEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto InputSpec = FMars_MechanismSource_Spec();
        InputSpec.OutputChannel = _InputChannel;
        _Input = utils_mechanism_source::Add(InputEntity, InputSpec);

        Add_Step("the input channel tag exists", n"Step_AssertChannel");
        Add_Step_WaitUntil("the link is set up (the sink's power signal is bound)", n"Check_LinkBound", 0, 5.0f);
        Add_Step("assert the input", n"Step_Power");
        Add_Step_WaitUntil("the countdown is full, held, and its source asserted", n"Check_HeldFull", 0, 5.0f);
        Add_Step_WaitSeconds("more than two steps' worth of time while powered", 1.0f);
        Add_Step("still full and held", n"Step_AssertStillFull");
        Add_Step("drop the input", n"Step_Unpower");
        Add_Step_WaitUntil("released, it drains to the last step", n"Check_DrainedOneStep", 0, 5.0f);
        Add_Step_WaitUntil("it drains to empty and its source drops", n"Check_EmptyAndDropped", 0, 5.0f);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertChannel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_InputChannel.IsValid(), "Mechanism.Channel.L is registered");
    }

    UFUNCTION()
    private void Check_LinkBound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Countdown.Has_Fragment(FMars_Tag_Countdown_NeedsSetup) == false
            && _Sink.Has_Fragment(FMars_Fragment_MechanismSink_Signals)
            && _Sink.Get_Fragment(FMars_Fragment_MechanismSink_Signals).OnPoweredChanged._Inner.IsBound());
    }

    UFUNCTION()
    private void Step_Power(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Input.Request_SetAsserted(true);
    }

    UFUNCTION()
    private void Check_HeldFull(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Countdown.Get_Remaining() == 2 && _Countdown.Get_IsHeld() && _Source.Get_IsAsserted());
    }

    UFUNCTION()
    private void Step_AssertStillFull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Countdown.Get_Remaining(), 2, "a held countdown does not drain");
        Assert_True(_Sink.Get_IsPowered(), "the driver powers the sink while the input is asserted");
        Assert_True(_Countdown.Get_IsHeld(), "the countdown is held while its sink is powered");
        Assert_False(_Countdown.Has_Fragment(FMars_Tag_Countdown_Running), "a held countdown does not tick");
        Assert_True(_Source.Get_IsAsserted(), "the source stays asserted while held");
    }

    UFUNCTION()
    private void Step_Unpower(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Input.Request_SetAsserted(false);
    }

    UFUNCTION()
    private void Check_DrainedOneStep(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Countdown.Get_IsHeld() == false && _Countdown.Get_Remaining() == 1 && _Source.Get_IsAsserted());
    }

    UFUNCTION()
    private void Check_EmptyAndDropped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Countdown.Get_Remaining() == 0 && _Source.Get_IsAsserted() == false);
    }
}
