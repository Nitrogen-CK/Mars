// The link a lamp bank relies on: a rising edge on the countdown's own MechanismSink charges it, a falling edge does not,
// and the MechanismSource on the same entity is asserted exactly while the countdown is charged. The edges are fed straight
// to the sink, so no mechanism driver or other placeable is involved.
class UMars_AutoTest_Countdown_SinkEdgeChargesAndSourceFollows : UCk_AutoTest_Base
{
    private FCk_Handle_Countdown _Countdown;
    private FCk_Handle_MechanismSink _Sink;
    private FCk_Handle_MechanismSource _Source;
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

        _Countdown = utils_countdown::Add(Entity, FMars_Countdown_Spec(2, 0.2f, false));

        auto SourceSpec = FMars_MechanismSource_Spec();
        SourceSpec.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.M");
        _Source = utils_mechanism_source::Add(Entity, SourceSpec);

        Add_Step("the input channel tag exists", n"Step_AssertChannel");
        Add_Step_WaitUntil("the link is set up (the sink's edge signal is bound)", n"Check_LinkBound", 0, 5.0f);
        Add_Step("a falling edge on the input", n"Step_FallingEdge");
        Add_Step_WaitSeconds("let the sink drain it", 0.1f);
        Add_Step("a falling edge does not charge", n"Step_AssertNotCharged");
        Add_Step("a rising edge on the input", n"Step_RisingEdge");
        Add_Step_WaitUntil("the countdown is charged and its source asserted", n"Check_ChargedAndAsserted", 0, 5.0f);
        Add_Step_WaitUntil("the countdown drains and its source drops", n"Check_EmptyAndDropped", 0, 5.0f);
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
            && _Sink.Get_Fragment(FMars_Fragment_MechanismSink_Signals).OnInputEdge._Inner.IsBound());
    }

    UFUNCTION()
    private void Step_FallingEdge(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Sink.Request_NotifyInputEdge(FMars_Request_MechanismSink_NotifyInputEdge(_InputChannel, false));
    }

    UFUNCTION()
    private void Step_AssertNotCharged(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Countdown.Get_Remaining(), 0, "a falling edge leaves the countdown empty");
        Assert_False(_Source.Get_IsAsserted(), "the source stays down while empty");
    }

    UFUNCTION()
    private void Step_RisingEdge(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Sink.Request_NotifyInputEdge(FMars_Request_MechanismSink_NotifyInputEdge(_InputChannel, true));
    }

    UFUNCTION()
    private void Check_ChargedAndAsserted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Countdown.Get_Remaining() == 2 && _Source.Get_IsAsserted());
    }

    UFUNCTION()
    private void Check_EmptyAndDropped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Countdown.Get_Remaining() == 0 && _Source.Get_IsAsserted() == false);
    }
}
