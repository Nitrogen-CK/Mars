// The authority evaluates the sink in its request drain and needs no setup. A client binds the ledger's rep-notify and
// reconciles once (a value that arrived before the bind never re-fires): every Power change it sees, the first
// evaluation included, broadcasts OnPoweredChanged as the authority's drain did.
class UMars_Processor_MechanismSink_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_MechanismSink_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_MechanismSink);
        Query.Require(FMars_Tag_MechanismSink_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_MechanismSink_NeedsSetup);

        if (utils_net::Get_HasAuthority(InHandle))
        {
            InHandle.Request_TryRemove(FMars_Fragment_MechanismSink_Mirror);
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_MechanismSink,
            FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(InHandle);
    }

    // An expected absence, not a defect: a notify can land on an entity already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_MechanismSink() == false)
        { return; }

        Reconcile(InHandle);
    }

    private void Reconcile(FCk_Handle InHandle)
    {
        auto Sink = InHandle.As_MechanismSink();
        const auto Ledger = Sink.Get_Fragment(FMars_Fragment_MechanismSink);
        auto& Mirror = Sink.Get_Fragment(FMars_Fragment_MechanismSink_Mirror);
        const auto PreviousPower = Mirror.Last.Power;
        Mirror.Last = Ledger;

        // OnPoweredChanged never carries Unevaluated.
        if (Ledger.Power == PreviousPower || Ledger.Power == EMars_MechanismSink_Power::Unevaluated)
        { return; }

        if (Sink.Has_Fragment(FMars_Fragment_MechanismSink_Signals) == false)
        { return; }

        // Handlers light lamps, open gates, hold countdowns and start a Steward: scope the script world to the sink's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(Sink));
        Sink.Get_Fragment(FMars_Fragment_MechanismSink_Signals).OnPoweredChanged.Broadcast(Sink, Ledger.Power);
    }
}
