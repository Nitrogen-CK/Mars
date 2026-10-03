// A sink whose input channel has no source still evaluates: the world's mechanism driver pushes that channel's (0, 0)
// counts, the sink broadcasts its first OnPoweredChanged (unpowered), and the StartOpen gate it drives closes. Nothing
// sources Mechanism.Channel.D. The gate and its sink are built in the test; the driver is the world's. Isolated Z band:
// -78000.
class UMars_AutoTest_Gate_UnsourcedSinkClosesStartOpenGate : UCk_AutoTest_Base
{
    private FVector _Origin = FVector(0.0, 0.0, -78000.0);
    private FCk_Handle_Gate _Gate;
    private FCk_Handle_MechanismSink _Sink;
    private FGameplayTag _Channel;
    private bool _StartedOpen = false;
    private int32 _PoweredChangedCount = 0;
    private bool _LastPowered = true;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Channel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.D");

        auto GateEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto GateRoot = utils_transform::Add(GateEntity, FTransform(FRotator::ZeroRotator, _Origin), ECk_Replication::DoesNotReplicate);

        auto GateSpec = FMars_Gate_Spec();
        GateSpec.StartOpen = true;
        _Gate = utils_gate::Add(GateRoot, GateSpec);
        _StartedOpen = ck::IsValid(_Gate) && _Gate.Get_IsOpen();

        auto SinkSpec = FMars_MechanismSink_Spec();
        SinkSpec.InputChannels.Add(_Channel);
        _Sink = utils_mechanism_sink::Add(GateEntity, SinkSpec);
        if (ck::IsValid(_Sink))
        { _Sink.BindTo_OnPoweredChanged(FMars_Delegate_MechanismSink_OnPoweredChanged(this, n"OnPoweredChanged")); }

        Add_Step("the gate starts open on a sink with an unsourced channel", n"Step_AssertStart");
        Add_Step_WaitUntil("the driver evaluates the sink", n"Check_Evaluated", 0, 5.0f);
        Add_Step("the first evaluation broadcast unpowered", n"Step_AssertBroadcast");
        Add_Step_WaitUntil("the unpowered sink closes the gate", n"Check_Closed", 0, 5.0f);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertStart(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Channel.IsValid(), "Mechanism.Channel.D is registered");
        Assert_True(ck::IsValid(_Gate), "utils_gate::Add returned a gate");
        Assert_True(ck::IsValid(_Sink), "utils_mechanism_sink::Add returned a sink");
        Assert_True(_StartedOpen, "StartOpen opens the gate at Add");
    }

    UFUNCTION()
    private void Check_Evaluated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Sink.Get_HasEvaluated());
    }

    UFUNCTION()
    private void Step_AssertBroadcast(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_PoweredChangedCount, 1, "the first evaluation broadcasts OnPoweredChanged once");
        Assert_False(_LastPowered, "a channel with no source leaves the sink unpowered");
        Assert_False(_Sink.Get_IsPowered(), "the sink is unpowered");
    }

    UFUNCTION()
    private void Check_Closed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Gate.Get_IsOpen() == false);
    }

    UFUNCTION()
    private void OnPoweredChanged(FCk_Handle_MechanismSink InSink, EMars_MechanismSink_Power InPower)
    {
        ++_PoweredChangedCount;
        _LastPowered = InPower == EMars_MechanismSink_Power::Powered;
    }
}
