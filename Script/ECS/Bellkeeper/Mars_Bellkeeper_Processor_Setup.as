// The link, on the authority: every rising edge on the MechanismSink on the bellkeeper's own entity is a commit, the
// optional MechanismSource on that entity is asserted while the lock is solved, and every dial's index change asks the
// lock to publish. A client wires none of it: it binds the ledger's rep-notify and its first pass shows the ledger this
// machine composed. The ledger's first application is the state the copy was born into, taken once as it stands: its
// level announced and its dials placed, no failure and no solve the ledger already holds raised. Each later change is
// reconciled as it arrives: its dials step there and it raises the failures and the solve the change implies.
class UMars_Processor_Bellkeeper_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Bellkeeper_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Bellkeeper);
        Query.Require(FMars_Tag_Bellkeeper_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Bellkeeper = InHandle.As_Bellkeeper();

        if (utils_net::Get_HasAuthority(InHandle) == false)
        {
            InHandle.BindTo_OnRepNotify(FMars_Fragment_Bellkeeper_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
            Reconcile(Bellkeeper, EMars_Net_Reconcile::AsItStands);
            Bellkeeper.Request_TryRemove(FMars_Tag_Bellkeeper_NeedsSetup);
            return;
        }

        Bellkeeper.Request_TryRemove(FMars_Fragment_Bellkeeper_Mirror);

        auto Sink = InHandle.As_MechanismSink(ECk_SanityCheck::UnChecked);
        const auto HasSink = ck::IsValid(Sink);
        ck::EnsureIfNot(HasSink, f"[Bellkeeper] [{Bellkeeper.ToString()}] has no MechanismSink on its entity; nothing can commit");
        if (HasSink)
        { Sink.BindTo_OnInputRose(FMars_Delegate_MechanismSink_OnInputRose(this, n"OnSinkInputRose")); }

        auto Source = InHandle.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        {
            const auto Output = Bellkeeper.Get_IsSolved() ? EMars_MechanismSource_Output::Asserted : EMars_MechanismSource_Output::Deasserted;
            Source.Request_SetOutput(utils_mechanism_source::Make_SetOutput(Output));
        }

        auto VentCycle = Bellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper_Params).VentCycle;
        if (ck::IsValid(VentCycle))
        { VentCycle.BindTo_OnRunningChanged(FMars_Delegate_Cycle_OnRunningChanged(this, n"OnVentCycleChanged")); }

        auto Dials = Bellkeeper.Get_Dials();
        for (int32 Index = 0; Index < Dials.Num(); ++Index)
        {
            auto Dial = Dials[Index];
            auto& Link = Dial.AddOrGet_Fragment(FMars_Fragment_Bellkeeper_DialLink);
            Link.Lock = Bellkeeper;
            Dial.BindTo_OnIndexChanged(FMars_Delegate_Dial_OnIndexChanged(this, n"OnDialIndexChanged"));
        }

        Bellkeeper.Request_TryRemove(FMars_Tag_Bellkeeper_NeedsSetup);
    }

    // An expected absence, not a defect: a notify can land on a lock already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_Bellkeeper() == false)
        { return; }

        auto Bellkeeper = InHandle.As_Bellkeeper();
        if (Bellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper_Mirror).InitialState == EMars_Net_InitialState::Awaited)
        {
            Bellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper_Mirror).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Bellkeeper, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Reconcile(Bellkeeper, EMars_Net_Reconcile::AsItArrives);
    }

    // The authority's order: the verdict's level, then each failure counted since, then the solve. Several changes
    // between two replications broadcast as one diff.
    private void Reconcile(FCk_Handle_Bellkeeper& InBellkeeper, EMars_Net_Reconcile InHow)
    {
        const auto Ledger = InBellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper_Net);
        auto& Mirror = InBellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper_Mirror);
        auto Last = Mirror.Last;
        Mirror.Last = Ledger;

        const auto LevelChanged = Ledger.FailedCommits != Last.FailedCommits || Ledger.Lock != Last.Lock;

        // As it stands, every failure the ledger counts and its solve came before this copy took its state.
        if (InHow == EMars_Net_Reconcile::AsItStands)
        {
            Last.FailedCommits = Ledger.FailedCommits;
            Last.Lock = Ledger.Lock;
        }

        const auto Solved = Ledger.Lock == EMars_Bellkeeper_Lock::Solved;
        auto& State = InBellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper);
        State.FailedCommits = Ledger.FailedCommits;
        State.Solved = Solved;

        auto Dials = InBellkeeper.Get_Dials();
        if (Ledger.DialIndices.Num() > 0 && ck::EnsureIfNot(Ledger.DialIndices.Num() == Dials.Num(),
            f"[Bellkeeper] [{InBellkeeper.ToString()}] ledger names [{Ledger.DialIndices.Num()}] dials for its [{Dials.Num()}]; its dials stay where they are"))
        { return; }

        // A standing place is put; an arriving one is stepped to, clicking the detents it passes.
        const auto Arrival = InHow == EMars_Net_Reconcile::AsItStands ? EMars_Dial_Arrival::Placed : EMars_Dial_Arrival::Stepped;
        for (int32 Index = 0; Index < Dials.Num(); ++Index)
        {
            auto Dial = Dials[Index];
            if (Ledger.DialIndices.IsValidIndex(Index) && Dial.Get_Index() != Ledger.DialIndices[Index])
            { Dial.Request_SetIndex(FMars_Request_Dial_SetIndex(Ledger.DialIndices[Index], Arrival)); }

            if (Dial.Get_IsLocked() != Solved)
            { Dial.Request_SetLocked(FMars_Request_Dial_SetLocked(Solved)); }
        }

        if (InBellkeeper.Has_Fragment(FMars_Fragment_Bellkeeper_Signals) == false)
        { return; }

        // Handlers play the bell's strokes and repaint its lights: scope the script world to the lock's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InBellkeeper));

        if (LevelChanged)
        { InBellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper_Signals).OnStateChanged.Broadcast(InBellkeeper); }

        const auto RewardCount = InBellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper_Params).Rewards.Num();
        for (int32 Failures = Last.FailedCommits + 1; Failures <= Ledger.FailedCommits; ++Failures)
        {
            const auto Remaining = utils_bellkeeper::Get_RemainingAfter(Failures, RewardCount);
            InBellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper_Signals).OnCommitFailed.Broadcast(InBellkeeper, Remaining);
        }

        if (Last.Lock == EMars_Bellkeeper_Lock::Sealed && Solved)
        { InBellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper_Signals).OnSolved.Broadcast(InBellkeeper); }
    }

    UFUNCTION()
    private void OnSinkInputRose(FCk_Handle_MechanismSink InSink, FGameplayTag InChannel)
    {
        auto Bellkeeper = InSink.As_Bellkeeper();
        Bellkeeper.Request_Commit(FMars_Request_Bellkeeper_Commit());
    }

    // A dial whose lock is ending has nothing to publish.
    UFUNCTION()
    private void OnDialIndexChanged(FCk_Handle_Dial InDial, int32 InIndex)
    {
        if (ck::EnsureIfNot(InDial.Has_Fragment(FMars_Fragment_Bellkeeper_DialLink),
            f"[Bellkeeper] dial [{InDial.ToString()}] changed its index with no link to its lock"))
        { return; }

        auto Lock = InDial.Get_Fragment(FMars_Fragment_Bellkeeper_DialLink).Lock;
        if (ck::IsValid(Lock) && utils_entity_lifetime::Get_IsPendingDestroy(Lock, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        if (ck::EnsureIfNot(ck::IsValid(Lock), f"[Bellkeeper] dial [{InDial.ToString()}] links to no lock; its index is not published"))
        { return; }

        Lock.Request_DialMoved(FMars_Request_Bellkeeper_DialMoved());
    }

    UFUNCTION()
    private void OnVentCycleChanged(FCk_Handle_Cycle InCycle, EMars_Cycle_RunState InRunState)
    {
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InCycle);
        if (ck::Is_NOT_Valid(Owner))
        { return; }

        auto Bellkeeper = Owner.As_Bellkeeper(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Bellkeeper) || Bellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper_Params).VentCycle != InCycle)
        { return; }

        Bellkeeper.Request_VentCycleChanged(FMars_Request_Bellkeeper_VentCycleChanged(InCycle, InRunState));
    }
}
