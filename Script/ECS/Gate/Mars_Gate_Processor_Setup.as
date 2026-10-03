// The link: a Gate that also has a MechanismSink opens while powered; a Gate that also has a MechanismSource
// asserts while open. Both features live on the gate's own entity. A gate with a threshold retries a deferred close
// each time something leaves it.
class UMars_Processor_Gate_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Gate_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Gate);
        Query.Require(FMars_Tag_Gate_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Gate = InHandle.As_Gate();

        auto Sink = InHandle.As_MechanismSink(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Sink))
        {
            Sink.BindTo_OnPoweredChanged(FMars_Delegate_MechanismSink_OnPoweredChanged(this, n"OnSinkPoweredChanged"));
            if (Sink.Get_HasEvaluated())
            { Gate.Request_SetPosition(Make_SetPosition(Sink.Get_IsPowered())); }
        }

        auto Source = InHandle.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        {
            Gate.BindTo_OnOpenChanged(FMars_Delegate_Gate_OnOpenChanged(this, n"OnGateOpenChanged"));
            Source.Request_SetOutput(Make_SetOutput(Gate.Get_IsOpen()));
        }

        auto Threshold = Gate.Get_Threshold();
        if (ck::IsValid(Threshold))
        { Threshold.BindTo_OnEntityExited(FMars_Delegate_Trigger_OnEntityExited(this, n"OnThresholdEntityExited")); }

        Gate.Request_TryRemove(FMars_Tag_Gate_NeedsSetup);
    }

    private FMars_Request_Gate_SetPosition Make_SetPosition(bool InOpen) const
    {
        return FMars_Request_Gate_SetPosition(InOpen ? EMars_Gate_Position::Open : EMars_Gate_Position::Closed);
    }

    private FMars_Request_MechanismSource_SetOutput Make_SetOutput(bool InOpen) const
    {
        return FMars_Request_MechanismSource_SetOutput(InOpen ? EMars_MechanismSource_Output::Asserted : EMars_MechanismSource_Output::Deasserted);
    }

    UFUNCTION()
    private void OnThresholdEntityExited(FCk_Handle_Trigger InTrigger, FCk_Handle InEntity)
    {
        // The threshold lives on the gate's root, or on a scene node directly under it when it has a LocalOffset. The
        // owner is gone only while the gate is being torn down.
        FCk_Handle GateEntity = InTrigger;
        if (InTrigger.Is_Gate() == false)
        { GateEntity = utils_entity_lifetime::Get_LifetimeOwner(InTrigger); }

        if (ck::Is_NOT_Valid(GateEntity))
        { return; }

        auto Gate = GateEntity.As_Gate();
        if (Gate.Get_IsCloseDeferred() == false || Gate.Get_IsThresholdOccupied())
        { return; }

        Gate.Request_RetryClose();
    }

    UFUNCTION()
    private void OnSinkPoweredChanged(FCk_Handle_MechanismSink InSink, EMars_MechanismSink_Power InPower)
    {
        auto Gate = InSink.As_Gate();
        Gate.Request_SetPosition(Make_SetPosition(InPower == EMars_MechanismSink_Power::Powered));
    }

    UFUNCTION()
    private void OnGateOpenChanged(FCk_Handle_Gate InGate, EMars_Gate_Position InPosition)
    {
        auto Source = InGate.As_MechanismSource();
        Source.Request_SetOutput(Make_SetOutput(InPosition == EMars_Gate_Position::Open));
    }
}
