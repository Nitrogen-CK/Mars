// A RunWhilePowered pendulum (no catch angle) rests disarmed while its sink is unpowered; powering the sink (a source on
// Mechanism.Channel.F through the world's driver) starts the swing and arms the hazard; unpowering it stops the swing,
// which eases to rest before the hazard disarms. Nothing else sources Mechanism.Channel.F, which the test checks first.
class UMars_AutoTest_Pendulum_SinkPowerGatesTheSwing : UMars_AutoTestRig_Pendulum
{
    private FCk_Handle_MechanismSink _Sink;
    private FCk_Handle_MechanismSource _Source;
    private bool _SawArmedWhileEasing = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Swing = Make_SwingSpec();
        Swing.StartRunning = false;
        AddPendulum(InHandle, FVector(48000.0, 330000.0, -41000.0), Swing, EMars_PoweredBehavior::RunWhilePowered);

        auto SinkSpec = FMars_MechanismSink_Spec();
        SinkSpec.InputChannels.Add(GameplayTags::Mechanism_Channel_F);
        _Sink = utils_mechanism_sink::Add(_Entity, SinkSpec);

        Add_Step("nothing else sources the channel", n"Step_AssertChannelIsOurs");
        Add_Step_WaitUntil("the sink evaluates unpowered", n"Check_Evaluated", 0, 0);
        Add_Step("unpowered: at rest and disarmed", n"Step_AssertResting");
        Add_Step("power the sink", n"Step_Power");
        Add_Step_WaitUntil("the swing runs and the hazard arms", n"Check_RunningArmed", k_SlowPolls, 0);
        Add_Step("unpower the sink", n"Step_Unpower");
        Add_Step_WaitUntil("the swing eases to rest and the hazard disarms", n"Check_RestDisarmed", k_SlowPolls, 0);
        Add_Step("armed while easing out, one rest", n"Step_AssertEasedOut");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertChannelIsOurs(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Sink, "the sink composed");
        Assert_Equals_Int(utils_mechanism_source::Get_SourcesOn(InHandle, GameplayTags::Mechanism_Channel_F).Num(), 0,
            "no source in the world outputs on Mechanism.Channel.F before the test adds its own");

        auto SourceEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto SourceSpec = FMars_MechanismSource_Spec();
        SourceSpec.OutputChannel = GameplayTags::Mechanism_Channel_F;
        _Source = utils_mechanism_source::Add(SourceEntity, SourceSpec);
    }

    UFUNCTION()
    private void Check_Evaluated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Sink.Get_HasEvaluated());
    }

    UFUNCTION()
    private void Step_AssertResting(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Sink.Get_IsPowered(), "the sink is unpowered");
        Assert_False(_Oscillator.Get_IsSwinging(), "the swing rests");
        Assert_False(_Hazard.Get_IsArmed(), "a resting pendulum's hazard is disarmed");
    }

    UFUNCTION()
    private void Step_Power(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Source.Request_SetOutput(FMars_Request_MechanismSource_SetOutput(EMars_MechanismSource_Output::Asserted));
    }

    UFUNCTION()
    private void Check_RunningArmed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Oscillator.Get_IsRunning() && _Hazard.Get_IsArmed() && Math::Abs(_Oscillator.Get_Angle()) > 5.0f);
    }

    UFUNCTION()
    private void Step_Unpower(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Source.Request_SetOutput(FMars_Request_MechanismSource_SetOutput(EMars_MechanismSource_Output::Deasserted));
    }

    // Latches the easing window: stopped, still swinging, the hazard still armed.
    UFUNCTION()
    private void Check_RestDisarmed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (_Oscillator.Get_IsRunning() == false && _Oscillator.Get_IsSwinging() && _Hazard.Get_IsArmed())
        { _SawArmedWhileEasing = true; }

        auto Res = OutResult;
        Res.Set(_Oscillator.Get_IsSwinging() == false && _Hazard.Get_IsArmed() == false);
    }

    UFUNCTION()
    private void Step_AssertEasedOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_SawArmedWhileEasing, "the hazard stayed armed while the stopped swing eased out");
        Assert_Equals_Int(_RestCount, 1, "coming to rest broadcast OnCameToRest once");
        Assert_Equals_Int(_ArmedEdges, 1, "one Armed edge");
        Assert_Equals_Int(_DisarmedEdges, 1, "one Disarmed edge");
    }
}
