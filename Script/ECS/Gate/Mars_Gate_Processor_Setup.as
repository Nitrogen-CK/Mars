// The link, on the authority: a Gate that also has a MechanismSink opens while powered; a Gate that also has a
// MechanismSource asserts while open. Both features live on the gate's own entity. A gate with a threshold retries a
// deferred close each time something leaves it. A client wires none of it: it binds the ledger's rep-notify and its
// first pass shows the ledger this machine composed. The ledger's first application is the state the copy was born
// into, taken once as it stands: the leaf put at its pose at once, and OnOpenChanged announcing a standing open gate.
// Each later change is reconciled as it arrives: the leaf swings and OnOpenChanged is broadcast when the replicated
// position changes.
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
        Gate.Request_TryRemove(FMars_Tag_Gate_NeedsSetup);

        if (utils_net::Get_HasAuthority(InHandle) == false)
        {
            InHandle.BindTo_OnRepNotify(FMars_Fragment_Gate, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
            Reconcile(Gate, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Gate.Request_TryRemove(FMars_Fragment_Gate_Mirror);

        auto Sink = InHandle.As_MechanismSink(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Sink))
        {
            Sink.BindTo_OnPoweredChanged(FMars_Delegate_MechanismSink_OnPoweredChanged(this, n"OnSinkPoweredChanged"),
                ECk_Signal_BindingPolicy::FireIfPayloadInFlight);
        }

        auto Source = InHandle.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        {
            Gate.BindTo_OnOpenChanged(FMars_Delegate_Gate_OnOpenChanged(this, n"OnGateOpenChanged"));
            Source.Request_SetOutput(utils_mechanism_source::Make_SetOutput(Get_SourceOutput(Gate.Get_Position())));
        }

        auto Threshold = Gate.Get_Threshold();
        if (ck::IsValid(Threshold))
        { Threshold.BindTo_OnEntityExited(FMars_Delegate_Trigger_OnEntityExited(this, n"OnThresholdEntityExited")); }
    }

    // An expected absence, not a defect: a notify can land on a gate already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_Gate() == false)
        { return; }

        auto Gate = InHandle.As_Gate();
        if (Gate.Get_Fragment(FMars_Fragment_Gate_Mirror).InitialState == EMars_Net_InitialState::Awaited)
        {
            Gate.Get_Fragment(FMars_Fragment_Gate_Mirror).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Gate, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Reconcile(Gate, EMars_Net_Reconcile::AsItArrives);
    }

    // A deferred close is still open, so it moves nothing and broadcasts nothing. The diff against Last guards the
    // reconcile and the notify alike: one replicated change broadcasts once.
    private void Reconcile(FCk_Handle_Gate& InGate, EMars_Net_Reconcile InHow)
    {
        auto& Mirror = InGate.Get_Fragment(FMars_Fragment_Gate_Mirror);
        const auto WasOpen = Mirror.Last.State != EMars_Gate_State::Closed;
        Mirror.Last = InGate.Get_Fragment(FMars_Fragment_Gate);

        const auto Position = InGate.Get_Position();
        const auto Open = Position == EMars_Gate_Position::Open;
        if (Open == WasOpen)
        { return; }

        // As it stands the leaf is put at its pose at once; as it arrives it swings there.
        auto Mover = InGate.Get_MovingNode().As_Mover();
        if (InHow == EMars_Net_Reconcile::AsItStands)
        { Mover.Request_Scrub(FMars_Request_Mover_Scrub(Open ? 1.0f : 0.0f)); }

        Mover.Request_MoveTo(FMars_Request_Mover_MoveTo(Open ? EMars_Mover_Pose::End : EMars_Mover_Pose::Start));

        if (InGate.Has_Fragment(FMars_Fragment_Gate_Signals) == false)
        { return; }

        // Handlers read the gate's position: scope the script world to the gate's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InGate));
        InGate.Get_Fragment(FMars_Fragment_Gate_Signals).OnOpenChanged.Broadcast(InGate, Position);
    }

    // The source asserts while the gate is open.
    private EMars_MechanismSource_Output Get_SourceOutput(EMars_Gate_Position InPosition) const
    {
        return InPosition == EMars_Gate_Position::Open ? EMars_MechanismSource_Output::Asserted : EMars_MechanismSource_Output::Deasserted;
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
        const auto Position = InPower == EMars_MechanismSink_Power::Powered ? EMars_Gate_Position::Open : EMars_Gate_Position::Closed;
        Gate.Request_SetPosition(FMars_Request_Gate_SetPosition(Position));
    }

    UFUNCTION()
    private void OnGateOpenChanged(FCk_Handle_Gate InGate, EMars_Gate_Position InPosition)
    {
        auto Source = InGate.As_MechanismSource();
        Source.Request_SetOutput(utils_mechanism_source::Make_SetOutput(Get_SourceOutput(InPosition)));
    }
}
