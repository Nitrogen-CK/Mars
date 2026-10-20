// A SuppressWhilePowered trap runs while its sink is unpowered; powering the sink (a source on Mechanism.Channel.E,
// through the world's mechanism driver) stops the cycle mid-Active, which disarms the hazard and lowers the part;
// unpowering it starts the cycle again from Safe. Nothing else sources Mechanism.Channel.E, which the test checks first.
class UMars_AutoTest_Trap_PoweredSinkSuppressesTheCycleAndResets : UMars_AutoTestRig_Trap
{
    private FCk_Handle_MechanismSink _Sink;
    private FCk_Handle_MechanismSource _Source;
    private int32 _StoppedEdges = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddTrap(InHandle, FVector(40000.0, 330000.0, -41000.0), EMars_PoweredBehavior::SuppressWhilePowered);
        _Cycle.BindTo_OnRunningChanged(FMars_Delegate_Cycle_OnRunningChanged(this, n"OnRunningChanged"));

        auto SinkSpec = FMars_MechanismSink_Spec();
        SinkSpec.InputChannels.Add(GameplayTags::Mechanism_Channel_E);
        _Sink = utils_mechanism_sink::Add(_Entity, SinkSpec);

        Add_Step("nothing else sources the channel", n"Step_AssertChannelIsOurs");
        Add_Step_WaitUntil("the unpowered sink lets the trap reach Active", n"Check_ActiveArmed", k_SlowPolls, 0);
        Add_Step("power the sink", n"Step_Power");
        Add_Step_WaitUntil("the cycle stops, disarmed and lowered", n"Check_StoppedAndReset", k_SlowPolls, 0);
        Add_Step("one stop edge, and the sink is powered", n"Step_AssertStopped");
        Add_Step("unpower the sink", n"Step_Unpower");
        Add_Step_WaitUntil("the cycle runs again from Safe", n"Check_RunningFromSafe", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertChannelIsOurs(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Sink, "the sink composed");
        Assert_Equals_Int(utils_mechanism_source::Get_SourcesOn(InHandle, GameplayTags::Mechanism_Channel_E).Num(), 0,
            "no source in the world outputs on Mechanism.Channel.E before the test adds its own");

        auto SourceEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto SourceSpec = FMars_MechanismSource_Spec();
        SourceSpec.OutputChannel = GameplayTags::Mechanism_Channel_E;
        _Source = utils_mechanism_source::Add(SourceEntity, SourceSpec);
    }

    UFUNCTION()
    private void Check_ActiveArmed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cycle.Get_IsRunning() && _Cycle.Get_CurrentPhase() == GameplayTags::Mechanism_Phase_Active && _Hazard.Get_IsArmed());
    }

    UFUNCTION()
    private void Step_Power(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Source.Request_SetOutput(FMars_Request_MechanismSource_SetOutput(EMars_MechanismSource_Output::Asserted));
    }

    UFUNCTION()
    private void Check_StoppedAndReset(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cycle.Get_IsRunning() == false && _Hazard.Get_IsArmed() == false && _Mover.Get_Target() == EMars_Mover_Pose::Start);
    }

    UFUNCTION()
    private void Step_AssertStopped(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Sink.Get_IsPowered(), "the sink is powered");
        Assert_Equals_Int(_StoppedEdges, 1, "the cycle broadcast one Stopped edge");
    }

    UFUNCTION()
    private void Step_Unpower(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Phases.Empty();
        _Source.Request_SetOutput(FMars_Request_MechanismSource_SetOutput(EMars_MechanismSource_Output::Deasserted));
    }

    UFUNCTION()
    private void Check_RunningFromSafe(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cycle.Get_IsRunning() && _Phases.Num() >= 1 && _Phases[0] == GameplayTags::Mechanism_Phase_Safe);
    }

    UFUNCTION()
    private void OnRunningChanged(FCk_Handle_Cycle InCycle, EMars_Cycle_RunState InRunState)
    {
        if (InRunState == EMars_Cycle_RunState::Stopped)
        { ++_StoppedEdges; }
    }
}
