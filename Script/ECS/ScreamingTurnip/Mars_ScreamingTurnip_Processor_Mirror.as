// Once per root: the authority drops the mirror state (its drain and its tick publish the ledger). A machine without
// authority binds the ledger's rep-notify and reconciles once as it stands, which shows what this machine composed.
// The ledger's first application is the state the copy was born into and is taken once as it stands: the levels are
// written into the state and settle fragments the presentation reads and announced, a phase it was born into starts
// on this machine's clock, and no scream is raised (one committed before this copy took its state is not replayed).
// Each later change is reconciled as it arrives: the levels are written and announced, a changed phase starts on this
// machine's clock, and the kernel's three signals are raised once per arrived change. A sequence that advanced by more
// than one raises one scream, the latest; a phase that never arrived because two of the authority's writes reached
// this machine as one is not replayed.
class UMars_Processor_ScreamingTurnip_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_ScreamingTurnip_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_ScreamingTurnip);
        Query.Require(FMars_Tag_ScreamingTurnip_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_ScreamingTurnip_NeedsMirror);
        auto Turnip = InHandle.As_ScreamingTurnip();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Turnip.Get_Fragment(FMars_Fragment_ScreamingTurnip_Local).Last = TOptional<FMars_Fragment_ScreamingTurnip_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_ScreamingTurnip_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Turnip, EMars_ScreamingTurnip_Reconcile::AsItStands);
    }

    // An expected absence, not a defect: a notify can land on an entity already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_ScreamingTurnip() == false)
        { return; }

        auto Turnip = InHandle.As_ScreamingTurnip();
        if (Turnip.Get_Fragment(FMars_Fragment_ScreamingTurnip_Local).InitialState == EMars_Net_InitialState::Awaited)
        {
            Turnip.Get_Fragment(FMars_Fragment_ScreamingTurnip_Local).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Turnip, EMars_ScreamingTurnip_Reconcile::AsItStands);
            return;
        }

        Reconcile(Turnip, EMars_ScreamingTurnip_Reconcile::AsItArrives);
    }

    // Last is written before the fragments and any broadcast; the broadcasts come after every write.
    private void Reconcile(FCk_Handle_ScreamingTurnip& InTurnip, EMars_ScreamingTurnip_Reconcile InHow)
    {
        const auto Ledger = InTurnip.Get_Fragment(FMars_Fragment_ScreamingTurnip_Net);
        auto& Local = InTurnip.Get_Fragment(FMars_Fragment_ScreamingTurnip_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[ScreamingTurnip] [{InTurnip.ToString()}] has no mirror state off authority"))
        { return; }

        const auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_ScreamingTurnip_Net>(Ledger);
        if (utils_screaming_turnip::Get_IsSameLedger(Ledger, Last))
        { return; }

        const auto PlacementChanged = Ledger.Placement != Last.Placement;
        const auto PhaseChanged = Ledger.Phase != Last.Phase;
        const auto ScreamArrived = InHow == EMars_ScreamingTurnip_Reconcile::AsItArrives && Ledger.ScreamSequence != Last.ScreamSequence;

        auto& State = InTurnip.Get_Fragment(FMars_Fragment_ScreamingTurnip);
        State.Placement = Ledger.Placement;
        State.Phase = Ledger.Phase;
        State.ScreamSequence = Ledger.ScreamSequence;
        State.LastWorldPosition = Ledger.ScreamPosition;
        if (PhaseChanged)
        { State.PhaseStartedAt = State.Clock; }

        if (ScreamArrived)
        { State.LastScreamCommittedAt = TOptional<float32>(State.Clock); }

        InTurnip.Get_Fragment(FMars_Fragment_ScreamingTurnip_Settle).HasSupport = Ledger.Support == EMars_ScreamingTurnip_Support::Supported;

        // Handlers react on the root (its presentation): scope the script world to its own. A rep-notify has none.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InTurnip));

        if (PlacementChanged && InTurnip.Has_Fragment(FMars_Fragment_ScreamingTurnip_Signals))
        { InTurnip.Get_Fragment(FMars_Fragment_ScreamingTurnip_Signals).OnPlacementChanged.Broadcast(InTurnip, Last.Placement, Ledger.Placement); }

        if (PhaseChanged && InTurnip.Has_Fragment(FMars_Fragment_ScreamingTurnip_Signals))
        { InTurnip.Get_Fragment(FMars_Fragment_ScreamingTurnip_Signals).OnPhaseChanged.Broadcast(InTurnip, Last.Phase, Ledger.Phase); }

        if (ScreamArrived && InTurnip.Has_Fragment(FMars_Fragment_ScreamingTurnip_Signals))
        { InTurnip.Get_Fragment(FMars_Fragment_ScreamingTurnip_Signals).OnScreamCommitted.Broadcast(InTurnip, Ledger.ScreamSequence, Ledger.ScreamPosition); }
    }
}
